# Oh My Zsh sshinfo plugin
# Displays resolved SSH connection information before connecting.

if ! command -v sshinfo >/dev/null 2>&1; then
    sshinfo() {
        local target="" style="${ZSH_SSHINFO_STYLE:-staircase}"
        local -a ssh_args
        
        # Parse arguments for style flags and target
        for arg in "$@"; do
            if [[ "$arg" == "--inline" ]]; then
                style="inline"
            elif [[ "$arg" == "--staircase" ]]; then
                style="staircase"
            else
                [[ "$arg" != -* ]] && target="$arg"
                ssh_args+=("$arg")
            fi
        done

        if [ -z "$target" ]; then
            command ssh "$@"
            return
        fi

        # Update arguments to remove our custom flags
        set -- "${ssh_args[@]}"

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

        # UI Styling
        local C_BOLD="\e[1m" C_DIM="\e[2m" C_GRAY="\e[38;5;242m" C_CYAN="\e[38;5;45m" C_PURPLE="\e[38;5;141m"
        
        # Resolve target IP
        local target_ip=""
        if [[ -n "${config[hostname]}" ]]; then
             target_ip=$(getent hosts "${config[hostname]}" 2>/dev/null | awk '{print $1}' | head -n1)
             [[ -z "$target_ip" ]] && target_ip=$(dig +short "${config[hostname]}" 2>/dev/null | head -n1)
        fi

        # Resolve full Proxy chain for Staircase display
        local -a hop_nodes
        local target_real="${config[hostname]:-$target}"
        hop_nodes=("${C_BOLD}${target}${RESET}${C_DIM} [${target_real}]${RESET}")

        local current_hop=""
        if [[ -n "${config[proxyjump]}" ]]; then
            current_hop="${config[proxyjump]%%,*}"
        else
            local -a args=(${(z)config[proxycommand]})
            if [[ "${args[1]}" == "ssh" ]]; then
                for arg in "${args[@]:1}"; do
                    [[ "$arg" == -* || "$arg" == *%* || "$arg" == "nc" || "$arg" == "proxyconnect" ]] && continue
                    current_hop="$arg"
                    break
                done
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
                
                local hop_real="" next_jump="" next_cmd=""
                while IFS= read -r hop_line; do
                    local key="${hop_line%% *}" val="${hop_line#* }"
                    [[ "${key:l}" == "hostname" ]] && hop_real="$val"
                    [[ "${key:l}" == "proxyjump" ]] && next_jump="$val"
                    [[ "${key:l}" == "proxycommand" ]] && next_cmd="$val"
                done <<< "$hop_output"
                
                hop_nodes=("${C_CYAN}${current_hop}${RESET}${C_DIM} [${hop_real:-?}]${RESET}" "${hop_nodes[@]}")
                
                local next_hop=""
                if [[ -n "$next_jump" ]]; then
                    next_hop="${next_jump%%,*}"
                elif [[ -n "$next_cmd" ]]; then
                    local -a hop_args=(${(z)next_cmd})
                    [[ "${hop_args[1]}" == "ssh" ]] && for h_arg in "${hop_args[@]:1}"; do
                        [[ "$h_arg" == -* || "$h_arg" == *%* || "$h_arg" == "nc" || "$h_arg" == "proxyconnect" ]] && continue
                        next_hop="$h_arg"; break
                    done
                fi
                [[ -z "$next_hop" ]] && break
                current_hop="$next_hop"
            done
        fi

        echo "\n ${GREEN}󰔶${RESET} ${C_BOLD}SSH Connection to ${C_CYAN}${target}${RESET}"
        
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
            echo " ${C_GRAY}╭──${RESET} ${C_PURPLE}${C_BOLD}CONNECTION${RESET}"
            [[ -n "${config[user]}" ]]     && printf " ${C_GRAY}│${RESET}  ${C_GRAY}👤${RESET} User     : ${C_BOLD}%s${RESET}\n" "${config[user]}"
            [[ -n "${config[hostname]}" ]] && printf " ${C_GRAY}│${RESET}  ${C_GRAY}🌐${RESET} Host     : ${C_BOLD}%s${RESET}${C_DIM}${target_ip:+( $target_ip)}${RESET}\n" "${config[hostname]}"
            [[ -n "${config[port]}" ]]     && printf " ${C_GRAY}│${RESET}  ${C_GRAY}🔌${RESET} Port     : %s\n" "${config[port]}"
            echo " ${C_GRAY}│${RESET}"
        fi

        if (( has_auth_info )); then
            current_section=$((current_section + 1))
            local label_top="├──"
            (( current_section == 1 )) && label_top="╭──"
            echo " ${C_GRAY}${label_top}${RESET} ${C_PURPLE}${C_BOLD}SECURITY${RESET}"
            if (( ${#identity_files[@]} > 1 )); then
                printf " ${C_GRAY}│${RESET}  ${C_GRAY}🔑${RESET} Key      : %s\n" "Default (~/.ssh/id_*)"
            else
                local key_path="${identity_files[1]}"
                key_path="${key_path/#$HOME/~}"
                printf " ${C_GRAY}│${RESET}  ${C_GRAY}🔑${RESET} Key      : %s\n" "$key_path"
            fi
            echo " ${C_GRAY}│${RESET}"
        fi

        if (( has_proxy_info )); then
            current_section=$((current_section + 1))
            local label_top="├──"
            (( current_section == 1 )) && label_top="╭──"
            echo " ${C_GRAY}${label_top}${RESET} ${C_PURPLE}${C_BOLD}NETWORK PATH${RESET}"
            
            # Print route based on selected style
            if [[ "$style" == "staircase" ]]; then
                printf " ${C_GRAY}│${RESET}  ${C_GRAY}🛤️${RESET} Route    : %b\n" "${hop_nodes[1]}"
                for (( i=2; i <= ${#hop_nodes[@]}; i++ )); do
                    local indent=$(( 11 + (i-2)*6 ))
                    printf " ${C_GRAY}│${RESET}%*s ${C_GRAY}╰─>${RESET} %b\n" $indent "" "${hop_nodes[i]}"
                done
            else
                local inline_route=""
                for (( i=1; i <= ${#hop_nodes[@]}; i++ )); do
                    inline_route+="${hop_nodes[i]}"
                    (( i < ${#hop_nodes[@]} )) && inline_route+=" ${C_GRAY}➜${RESET} "
                done
                printf " ${C_GRAY}│${RESET}  ${C_GRAY}🛤️${RESET} Route    : %b\n" "$inline_route"
            fi

            [[ -n "${config[proxycommand]}" && -z "${config[proxyjump]}" ]] && printf " ${C_GRAY}│${RESET}  ${C_GRAY}󱘖${RESET} ProxyCmd : %s\n" "${config[proxycommand]}"
            [[ -n "${config[dynamicforward]}" ]] && printf " ${C_GRAY}│${RESET}  ${C_GRAY}📡${RESET} Forward  : %s\n" "${config[dynamicforward]}"
            for lf in "${local_forwards[@]}";  do printf " ${C_GRAY}│${RESET}  󱘖  LocalFwd : %s\n" "$lf"; done
            for rf in "${remote_forwards[@]}"; do printf " ${C_GRAY}│${RESET}  󱘖  RemoteFwd: %s\n" "$rf"; done
        fi
        echo " ${C_GRAY}╰───────────────────────────────────────────${RESET}\n"
        command ssh "$@"
    }
fi

if ! command -v s >/dev/null 2>&1; then alias s='sshinfo'; fi
if ! command -v connect >/dev/null 2>&1; then alias connect='sshinfo'; fi

alias ssh='sshinfo'

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
    awk \
        '/^[[:space:]]*($|#)/{next} 
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
