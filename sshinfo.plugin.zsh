# Oh My Zsh sshinfo plugin
#
# A plugin that displays resolved SSH connection information before connecting.

if ! command -v sshinfo >/dev/null 2>&1; then
    sshinfo() {
        # --- Argument Parsing: Find the hostname ---
        local target=""
        for arg in "$@"; do
            if [[ "$arg" != -* ]]; then
                target="$arg"
            fi
        done

        if [ -z "$target" ]; then
            command ssh "$@"
            return
        fi

        # --- Color Definitions ---
        local GREEN BLUE YELLOW RED RESET
        if [[ -n "$TERM" && "$TERM" != "dumb" ]]; then
            GREEN="$(tput setaf 2)"
            BLUE="$(tput setaf 4)"
            YELLOW="$(tput setaf 3)"
            RED="$(tput setaf 1)"
            RESET="$(tput sgr0)"
        fi

        # --- SSH Configuration Fetching ---
        local ssh_output
        if ! ssh_output=$(command ssh -G "$target" 2>/dev/null) || [ -z "$ssh_output" ]; then
            echo "${RED}❌ Host '$target' not found or error in SSH configuration.${RESET}"
            command ssh "$@"
            return $?
        fi

        # --- Whitelist & Data Extraction ---
        local -A config
        local -a identity_files local_forwards remote_forwards
        
        local whitelist=("user" "hostname" "port" "proxyjump" "proxycommand" "dynamicforward")

        while IFS= read -r line; do
            local key="${line%% *}"
            local value="${line#* }"
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

        # --- Pretty Display ---
        echo "${GREEN}✅ Connecting to: $target${RESET}"
        
        local has_connection_info=0
        local has_auth_info=0
        local has_proxy_info=0

        # Check which sections have content
        [[ -n "${config[user]}" || -n "${config[hostname]}" || -n "${config[port]}" ]] && has_connection_info=1
        (( ${#identity_files[@]} > 0 )) && has_auth_info=1
        [[ -n "${config[proxyjump]}" || -n "${config[proxycommand]}" || -n "${config[dynamicforward]}" || ${#local_forwards[@]} -gt 0 || ${#remote_forwards[@]} -gt 0 ]] && has_proxy_info=1
        
        local total_sections=$((has_connection_info + has_auth_info + has_proxy_info))
        local current_section=0

        # --- Connection Section ---
        if (( has_connection_info )); then
            current_section=$((current_section + 1))
            local box_char_top="┌"
            local box_char_mid="│"
            if (( current_section < total_sections )); then
                box_char_top="├"
            fi
            
            echo
            echo "  ${BLUE}${box_char_top}─[ Connection ]${RESET}"
            [[ -n "${config[user]}" ]]     && printf "  ${BLUE}${box_char_mid}${RESET}  👤 User:          %s\n" "${config[user]}"
            [[ -n "${config[hostname]}" ]] && printf "  ${BLUE}${box_char_mid}${RESET}  🌐 HostName:       %s\n" "${config[hostname]}"
            [[ -n "${config[port]}" ]]     && printf "  ${BLUE}${box_char_mid}${RESET}  🔌 Port:           %s\n" "${config[port]}"
        fi

        # --- Authentication Section ---
        if (( has_auth_info )); then
            current_section=$((current_section + 1))
            local box_char_top="┌"
            local box_char_mid="│"
            if (( current_section > 1 && current_section < total_sections )); then
                box_char_top="├"
            elif (( current_section > 1 )); then
                 box_char_top="└"
            fi
            
            echo
            echo "  ${BLUE}${box_char_top}─[ Authentication ]${RESET}"
            if (( ${#identity_files[@]} > 1 )); then
                # Multiple identity files usually means it's the default list
                printf "  ${BLUE}${box_char_mid}${RESET}  🔑 IdentityFile:  %s\n" "Default (~/.ssh/id_*)"
            else
                # A single identity file means it was likely specified in the config
                printf "  ${BLUE}${box_char_mid}${RESET}  🔑 IdentityFile:  %s\n" "${identity_files[1]}"
            fi
        fi

        # --- Tunnels & Proxies Section ---
        if (( has_proxy_info )); then
            current_section=$((current_section + 1))
            local box_char_top="┌"
            local box_char_mid="│"
            if (( current_section > 1 )); then
                box_char_top="└"
            fi

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

# --- Alias Definitions ---
if ! command -v s >/dev/null 2>&1; then alias s='sshinfo'; fi
if ! command -v connect >/dev/null 2>&1; then alias connect='sshinfo'; fi
alias ssh='sshinfo'
