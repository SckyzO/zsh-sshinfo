# Oh My Zsh sshinfo plugin
# Displays resolved SSH connection information before connecting.

if ! command -v sshinfo >/dev/null 2>&1; then
    sshinfo() {
        local __target="" __style="${ZSH_SSHINFO_STYLE:-staircase}"
        local -a __ssh_args
        
        for arg in "$@"; do
            if [[ "$arg" == "--inline" ]]; then
                __style="inline"
            elif [[ "$arg" == "--staircase" ]]; then
                __style="staircase"
            else
                [[ "$arg" != -* ]] && __target="$arg"
                __ssh_args+=("$arg")
            fi
        done

        if [ -z "$__target" ]; then
            command ssh "$@"
            return
        fi

        set -- "${__ssh_args[@]}"

        local GREEN BLUE YELLOW RED RESET
        if [[ -n "$TERM" && "$TERM" != "dumb" ]]; then
            GREEN="$(tput setaf 2)"
            BLUE="$(tput setaf 4)"
            YELLOW="$(tput setaf 3)"
            RED="$(tput setaf 1)"
            RESET="$(tput sgr0)"
        fi

        local __ssh_output
        __ssh_output=$(command ssh -G "$__target" 2>/dev/null)
        if [[ -z "$__ssh_output" ]]; then
            echo "${RED}❌ Host '$__target' not found or error in SSH configuration.${RESET}"
            command ssh "$@"
            return $?
        fi

        local -A __config
        local -a __identity_files __local_forwards __remote_forwards
        local __whitelist=("user" "hostname" "port" "proxyjump" "proxycommand" "dynamicforward")

        while IFS= read -r line; do
            local key="${line%% *}" value="${line#* }"
            key="${key:l}"
            if [[ " ${__whitelist[*]} " =~ " ${key} " ]]; then
                __config[$key]=$value
            elif [[ "$key" == "identityfile" ]]; then
                __identity_files+=("$value")
            elif [[ "$key" == "localforward" ]]; then
                __local_forwards+=("$value")
            elif [[ "$key" == "remoteforward" ]]; then
                __remote_forwards+=("$value")
            fi
        done <<< "$__ssh_output"

        local C_BOLD="\e[1m" C_DIM="\e[2m" C_GRAY="\e[38;5;242m" C_CYAN="\e[38;5;45m" C_PURPLE="\e[38;5;141m"
        
        local __target_ip=""
        local __conf_host="${__config[hostname]}"
        if [[ -n "$__conf_host" ]]; then
             __target_ip=$(getent hosts "$__conf_host" 2>/dev/null | awk '{print $1}' | head -n1)
             [[ -z "$__target_ip" ]] && __target_ip=$(dig +short "$__conf_host" 2>/dev/null | head -n1)
        fi

        local -a __hop_nodes
        local __target_real="${__conf_host:-$__target}"
        __hop_nodes=("${C_BOLD}${__target}${RESET}${C_DIM} [${__target_real}]${RESET}")

        local __current_hop=""
        local __pj="${__config[proxyjump]}"
        local __pc="${__config[proxycommand]}"
        if [[ -n "$__pj" ]]; then
            __current_hop="${__pj%%,*}"
        elif [[ -n "$__pc" ]]; then
            local -a __args
            __args=(${(z)$__pc})
            if [[ "${__args[1]}" == "ssh" ]]; then
                for arg in "${__args[@]:1}"; do
                    [[ "$arg" == -* || "$arg" == *%* || "$arg" == "nc" || "$arg" == "proxyconnect" ]] && continue
                    __current_hop="$arg"
                    break
                done
            fi
        fi

        if [[ -n "$__current_hop" ]]; then
            local -A __seen_hops
            __seen_hops[$__target]=1
            local __depth=0
            while (( __depth++ < 5 )); do
                [[ -z "$__current_hop" || -n "${__seen_hops[$__current_hop]}" ]] && break
                __seen_hops[$__current_hop]=1
                local __h_output
                __h_output=$(command ssh -G "$__current_hop" 2>/dev/null) || break
                local __h_real="" __next_jump="" __next_cmd=""
                while IFS= read -r __h_line; do
                    local __h_key="${__h_line%% *}" __h_val="${__h_line#* }"
                    [[ "${__h_key:l}" == "hostname" ]] && __h_real="$__h_val"
                    [[ "${__h_key:l}" == "proxyjump" ]] && __next_jump="$__h_val"
                    [[ "${__h_key:l}" == "proxycommand" ]] && __next_cmd="$__h_val"
                done <<< "$__h_output"
                __hop_nodes=("${C_CYAN}${__current_hop}${RESET}${C_DIM} [${__h_real:-?}]${RESET}" "${__hop_nodes[@]}")
                local __next_hop=""
                if [[ -n "$__next_jump" ]]; then
                    __next_hop="${__next_jump%%,*}"
                elif [[ -n "$__next_cmd" ]]; then
                    local -a __h_args
                    __h_args=(${(z)__next_cmd})
                    if [[ "${__h_args[1]}" == "ssh" ]]; then
                        for h_arg in "${__h_args[@]:1}"; do
                            [[ "$h_arg" == -* || "$h_arg" == *%* || "$h_arg" == "nc" || "$h_arg" == "proxyconnect" ]] && continue
                            __next_hop="$h_arg"
                            break
                        done
                    fi
                fi
                [[ -z "$__next_hop" ]] && break
                __current_hop="$__next_hop"
            done
        fi

        echo "\n ${GREEN}🟢${RESET} ${C_BOLD}SSH Connection to ${C_CYAN}${__target}${RESET}"
        
        local __has_conn=0 __has_auth=0 __has_proxy_info=0
        [[ -n "${__config[user]}" || -n "${__config[hostname]}" || -n "${__config[port]}" ]] && __has_conn=1
        (( ${#__identity_files[@]} > 0 )) && __has_auth=1
        [[ -n "${__config[proxyjump]}" || -n "${__config[proxycommand]}" || -n "${__config[dynamicforward]}" || ${#__local_forwards[@]} -gt 0 || ${#__remote_forwards[@]} -gt 0 ]] && __has_proxy_info=1
        
        local __total_sec=$((__has_conn + __has_auth + __has_proxy_info))
        local __cur_sec=0

        if (( __has_conn )); then
            __cur_sec=$((__cur_sec + 1))
            echo " ${C_GRAY}╭──${RESET} ${C_PURPLE}${C_BOLD}CONNECTION${RESET}"
            [[ -n "${__config[user]}" ]]     && printf " ${C_GRAY}│${RESET}  ${C_GRAY}👤${RESET} User     : ${C_BOLD}%s${RESET}\n" "${__config[user]}"
            [[ -n "${__config[hostname]}" ]] && printf " ${C_GRAY}│${RESET}  ${C_GRAY}🌐${RESET} Host     : ${C_BOLD}%s${RESET}${C_DIM}${__target_ip:+( $__target_ip)}${RESET}\n" "${__config[hostname]}"
            [[ -n "${__config[port]}" ]]     && printf " ${C_GRAY}│${RESET}  ${C_GRAY}🔌${RESET} Port     : %s\n" "${__config[port]}"
            echo " ${C_GRAY}│${RESET}"
        fi

        if (( __has_auth )); then
            __cur_sec=$((__cur_sec + 1))
            local __l_top="├──"
            (( __cur_sec == 1 )) && __l_top="╭──"
            echo " ${C_GRAY}${__l_top}${RESET} ${C_PURPLE}${C_BOLD}SECURITY${RESET}"
            if (( ${#__identity_files[@]} > 1 )); then
                printf " ${C_GRAY}│${RESET}  ${C_GRAY}🔑${RESET} Key      : %s\n" "Default (~/.ssh/id_*)"
            else
                local __k_path="${__identity_files[1]}"
                __k_path="${__k_path/#$HOME/~}"
                printf " ${C_GRAY}│${RESET}  ${C_GRAY}🔑${RESET} Key      : %s\n" "$__k_path"
            fi
            echo " ${C_GRAY}│${RESET}"
        fi

        if (( __has_proxy_info )); then
            __cur_sec=$((__cur_sec + 1))
            local __l_top="├──"
            (( __cur_sec == 1 )) && __l_top="╭──"
            echo " ${C_GRAY}${__l_top}${RESET} ${C_PURPLE}${C_BOLD}NETWORK PATH${RESET}"
            
            if [[ "$__style" == "staircase" ]]; then
                printf " ${C_GRAY}│${RESET}  ${C_GRAY}🛤️${RESET} Route    : %b\n" "${__hop_nodes[1]}"
                for (( i=2; i <= ${#__hop_nodes[@]}; i++ )); do
                    local __ind=$(( 15 + (i-2)*6 ))
                    printf " ${C_GRAY}│${RESET}%*s ${C_GRAY}╰─>${RESET} %b\n" $__ind "" "${__hop_nodes[i]}"
                done
            else
                local __inline=""
                for (( i=1; i <= ${#__hop_nodes[@]}; i++ )); do
                    __inline+="${__hop_nodes[i]}"
                    (( i < ${#__hop_nodes[@]} )) && __inline+=" ${C_GRAY}➜${RESET}  "
                done
                printf " ${C_GRAY}│${RESET}  ${C_GRAY}🛤️${RESET} Route    : %b\n" "$__inline"
            fi

            [[ -n "${__config[dynamicforward]}" ]] && printf " ${C_GRAY}│${RESET}  ${C_GRAY}📡${RESET} Forward  : %s\n" "${__config[dynamicforward]}"
            for lf in "${__local_forwards[@]}";  do printf " ${C_GRAY}│${RESET}  ${C_GRAY}↪${RESET} LocalFwd : %s\n" "$lf"; done
            for rf in "${__remote_forwards[@]}"; do printf " ${C_GRAY}│${RESET}  ${C_GRAY}↪${RESET} RemoteFwd: %s\n" "$rf"; done
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
                local -a patterns
                patterns=("${(z)patterns_str}")
                for pattern in "${patterns[@]}"; do
                    local full_pattern
                    [[ "$pattern" != /* && "$pattern" != ~* ]] && full_pattern="$config_dir/$pattern" || full_pattern="${pattern/#	/$HOME}"
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
    awk '/^[[:space:]]*($|#)/{next} tolower($1)=="host"{for(i=2;i<=NF;i++){if(substr($i,1,1)=="#")break;if($i!~/[*?]/&&$i!~/^!/)print $i}}' "$@" 2>/dev/null
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