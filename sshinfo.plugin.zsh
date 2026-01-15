# Oh My Zsh sshinfo plugin
# Displays resolved SSH connection information before connecting.

if ! command -v sshinfo >/dev/null 2>&1; then
    sshinfo() {
        local target=""
        for arg in "$@"; do
            [[ "$arg" != -* ]] && target="$arg"
        done

        if [ -z "$target" ]; then
            command ssh "$@"
            return
        fi

        local GREEN BLUE YELLOW RED RESET
        if [[ -n "$TERM" && "$TERM" != "dumb" ]]; then
            GREEN="$(tput setaf 2)"
            BLUE="$(tput setaf 4)"
            YELLOW="$(tput setaf 3)"
            RED="$(tput setaf 1)"
            RESET="$(tput sgr0)"
        fi

        local ssh_output
        if ! ssh_output=$(command ssh -G "$target" 2>/dev/null) || [ -z "$ssh_output" ]; then
            echo "${RED}❌ Host '$target' not found or error in SSH configuration.${RESET}"
            command ssh "$@"
            return $?
        fi

        local -A config
        local -a identity_files local_forwards remote_forwards
        local whitelist=("user" "hostname" "port" "proxyjump" "proxycommand" "dynamicforward")

        while IFS= read -r line; do
            local key="${line%% *}" value="${line#* }"
            key="${key:l}"

            if [[ " ${whitelist[*]} " =~ " ${key} " ]]; then
                config[$key]=$value
            elif [[ "$key" == "identityfile" ]]; then
                identity_files+=("$value")
            elif [[ "$key" == "localforward" ]]; then
                local_forwards+=("$value")
            elif [[ "$key" == "remoteforward" ]]; then
                remote_forwards+=("$value")
            fi
        done <<< "$ssh_output"

        # Resolve full ProxyJump/ProxyCommand chain.
        if [[ -n "${config[proxyjump]}" || -n "${config[proxycommand]}" ]]; then
            local current_hop="" full_chain=""
            if [[ -n "${config[proxyjump]}" ]]; then
                current_hop="${config[proxyjump]%%,*}"
                full_chain="${config[proxyjump]}"
            else
                local -a args=(${(z)config[proxycommand]})
                if [[ "${args[1]}" == "ssh" ]]; then
                    for arg in "${args[@]:1}"; do
                        [[ "$arg" != -* && "$arg" != *%* ]] && current_hop="$arg"
                    done
                    [[ -n "$current_hop" ]] && full_chain="ssh($current_hop)"
                fi
            fi

            if [[ -n "$current_hop" ]]; then
                local -A seen_hops
                seen_hops[$target]=1
                local depth=0
                while (( depth++ < 5 )); do
                    [[ -z "$current_hop" || -n "${seen_hops[$current_hop]}" ]] && break
                    seen_hops[$current_hop]=1
                    local hop_output
                    hop_output=$(command ssh -G "$current_hop" 2>/dev/null) || break
                    local next_jump="" next_cmd=""
                    while IFS= read -r hop_line; do
                        local key="${hop_line%% *}" val="${hop_line#* }"
                        [[ "${key:l}" == "proxyjump" ]] && next_jump="$val" && break
                        [[ "${key:l}" == "proxycommand" ]] && next_cmd="$val" && break
                    done <<< "$hop_output"
                    if [[ -n "$next_jump" ]]; then
                        full_chain="${next_jump} ➜ ${full_chain}"
                        current_hop="${next_jump%%,*}"
                    elif [[ -n "$next_cmd" ]]; then
                        local next_hop=""
                        local -a hop_args=(${(z)next_cmd})
                        if [[ "${hop_args[1]}" == "ssh" ]]; then
                            for arg in "${hop_args[@]:1}"; do
                                [[ "$arg" != -* && "$arg" != *%* ]] && next_hop="$arg"
                            done
                        fi
                        [[ -z "$next_hop" ]] && break
                        full_chain="ssh(${next_hop}) ➜ ${full_chain}"
                        current_hop="$next_hop"
                    else
                        break
                    fi
                done
                config[proxyjump]="$full_chain"
                [[ -n "$full_chain" ]] && config[proxycommand]=""
            fi
        fi

        echo "${GREEN}✅ Connecting to: $target${RESET}"
        
        local has_connection_info=0
        local has_auth_info=0
        local has_proxy_info=0

        [[ -n "${config[user]}" || -n "${config[hostname]}" || -n "${config[port]}" ]] && has_connection_info=1
        (( ${#identity_files[@]} > 0 )) && has_auth_info=1
        [[ -n "${config[proxyjump]}" || -n "${config[proxycommand]}" || -n "${config[dynamicforward]}" || ${#local_forwards[@]} -gt 0 || ${#remote_forwards[@]} -gt 0 ]] && has_proxy_info=1
        
        local total_sections=$((has_connection_info + has_auth_info + has_proxy_info))
        local current_section=0

        if (( has_connection_info )); then
            current_section=$((current_section + 1))
            local box_char_top="┌" box_char_mid="│"
            (( current_section < total_sections )) && box_char_top="├"
            
            echo
            echo "  ${BLUE}${box_char_top}─[ Connection ]${RESET}"
            [[ -n "${config[user]}" ]]     && printf "  ${BLUE}${box_char_mid}${RESET}  👤 User:           %s\n" "${config[user]}"
            [[ -n "${config[hostname]}" ]] && printf "  ${BLUE}${box_char_mid}${RESET}  🌐 HostName:       %s\n" "${config[hostname]}"
            [[ -n "${config[port]}" ]]     && printf "  ${BLUE}${box_char_mid}${RESET}  🔌 Port:           %s\n" "${config[port]}"
        fi

        if (( has_auth_info )); then
            current_section=$((current_section + 1))
            local box_char_top="┌" box_char_mid="│"
            if (( current_section > 1 && current_section < total_sections )); then
                box_char_top="├"
            elif (( current_section > 1 )); then
                 box_char_top="└"
            fi
            
            echo
            echo "  ${BLUE}${box_char_top}─[ Authentication ]${RESET}"
            if (( ${#identity_files[@]} > 1 )); then
                printf "  ${BLUE}${box_char_mid}${RESET}  🔑 IdentityFile:  %s\n" "Default (~/.ssh/id_*)"
            else
                printf "  ${BLUE}${box_char_mid}${RESET}  🔑 IdentityFile:  %s\n" "${identity_files[1]}"
            fi
        fi

        if (( has_proxy_info )); then
            current_section=$((current_section + 1))
            local box_char_top="┌" box_char_mid="│"
            (( current_section > 1 )) && box_char_top="└"

            echo
            echo "  ${BLUE}${box_char_top}─[ Tunnels & Proxies ]${RESET}"
            [[ -n "${config[proxyjump]}" ]]      && printf "  ${BLUE}${box_char_mid}${RESET}  ↪ ProxyJump:      %s\n" "${config[proxyjump]}"
            [[ -n "${config[proxycommand]}" ]]   && printf "  ${BLUE}${box_char_mid}${RESET}  ↪ ProxyCommand:   %s\n" "${config[proxycommand]}"
            [[ -n "${config[dynamicforward]}" ]] && printf "  ${BLUE}${box_char_mid}${RESET}  ↪ DynamicForward: %s\n" "${config[dynamicforward]}"
            for lf in "${local_forwards[@]}";  do printf "  ${BLUE}${box_char_mid}${RESET}  ↪ LocalForward:   %s\n" "$lf"; done
            for rf in "${remote_forwards[@]}"; do printf "  ${BLUE}${box_char_mid}${RESET}  ↪ RemoteForward:  %s\n" "$rf"; done
        fi

        echo
        command ssh "$@"
    }
fi

if ! command -v s >/dev/null 2>&1; then alias s='sshinfo'; fi
if ! command -v connect >/dev/null 2>&1; then alias connect='sshinfo'; fi

# Optional: alias ssh='sshinfo'

_sshinfo_find_all_config_files() {
    local -a queue
    [[ -f "$HOME/.ssh/config" ]] && queue=("$HOME/.ssh/config")
    local -a seen=("${queue[@]}")
    local i=1
    while (( i <= ${#queue} )); do
        local file="${queue[i++]}"
        local config_dir="${file:h}"
        local line
        while IFS= read -r line; do
            if [[ ${line:l} =~ '^[[:space:]]*include[[:space:]]' ]]; then
                local patterns_str=${line#*[iI][nN][cC][lL][uU][dD][eE] }
                local -a patterns=("${(z)patterns_str}")
                for pattern in "${patterns[@]}"; do
                    local full_pattern
                    if [[ "$pattern" != /* && "$pattern" != ~* ]]; then
                        full_pattern="$config_dir/$pattern"
                    else
                        full_pattern="${pattern/#	/$HOME}"
                    fi
                    local -a found_files=(${~full_pattern}(N))
                    for f in "${found_files[@]}"; do
                        local found=0
                        for seen_file in "${seen[@]}"; do [[ "$seen_file" == "$f" ]] && found=1 && break; done
                        if [[ -f "$f" && $found -eq 0 ]]; then
                            seen+=("$f")
                            queue+=("$f")
                        fi
                    done
                done
            fi
        done < "$file"
    done
    echo "${seen[@]}"
}

_sshinfo_parse_hosts_from_files() {
    awk '
        /^[[:space:]]*($|#)/{next} 
        tolower($1)=="host"{
            for(i=2;i<=NF;i++){
                if(substr($i,1,1)=="#")break;
                if($i!~/[*?]/&&$i!~/^!/)print $i
            }
        }' "$@" 2>/dev/null
}

_sshinfo_complete() {
    local -a hosts config_files
    config_files=($(_sshinfo_find_all_config_files))
    (( ${#config_files[@]} > 0 )) && hosts+=($(_sshinfo_parse_hosts_from_files "${config_files[@]}"))
    [[ -r "${HOME}/.ssh/known_hosts" ]] && hosts+=($(awk '!/^(#|\|)/{print $1}' "${HOME}/.ssh/known_hosts" | tr ',' '\n'))
    local -a unique_hosts=("${(@u)hosts}")
    unique_hosts=("${(@)unique_hosts:#line=''}")
    compadd -a unique_hosts
}

compdef _sshinfo_complete sshinfo s connect