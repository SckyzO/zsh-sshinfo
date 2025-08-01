# Oh My Zsh sshinfo plugin
#
# A plugin that displays resolved SSH connection information before connecting.

# The main `sshinfo` function that wraps the original `ssh` command.
# It parses the command line to find the target host, then uses `ssh -G`
# to get the resolved configuration for that host and displays it before connecting.
if ! command -v sshinfo >/dev/null 2>&1; then
    sshinfo() {
        local target=""
        # Find the last non-option argument, which should be the hostname.
        for arg in "$@"; do
            if [[ "$arg" != -* ]]; then
                target="$arg"
            fi
        done

        # If no target is found (e.g., `ssh -V`), just run the original command.
        if [ -z "$target" ]; then
            command ssh "$@"
            return
        fi

        # Setup colors for the output, if the terminal supports it.
        local GREEN BLUE YELLOW RED RESET
        if [[ -n "$TERM" && "$TERM" != "dumb" ]]; then
            GREEN="$(tput setaf 2)"
            BLUE="$(tput setaf 4)"
            YELLOW="$(tput setaf 3)"
            RED="$(tput setaf 1)"
            RESET="$(tput sgr0)"
        fi

        # Use `ssh -G` to get the configuration for the target host.
        # This is the most reliable way to see what settings will be used.
        local ssh_output
        if ! ssh_output=$(command ssh -G "$target" 2>/dev/null) || [ -z "$ssh_output" ]; then
            echo "${RED}❌ Host '$target' not found or error in SSH configuration.${RESET}"
            command ssh "$@"
            return $?
        fi

        # Parse the output of `ssh -G` into key-value pairs.
        local -A config
        local -a identity_files local_forwards remote_forwards
        
        # Whitelist of config keys to display directly.
        local whitelist=("user" "hostname" "port" "proxyjump" "proxycommand" "dynamicforward")

        while IFS= read -r line; do
            local key="${line%% *}"
            local value="${line#* }"
            key="${key:l}" # a to lower

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

        # --- Display the connection information ---
        echo "${GREEN}✅ Connecting to: $target${RESET}"
        
        local has_connection_info=0
        local has_auth_info=0
        local has_proxy_info=0

        [[ -n "${config[user]}" || -n "${config[hostname]}" || -n "${config[port]}" ]] && has_connection_info=1
        (( ${#identity_files[@]} > 0 )) && has_auth_info=1
        [[ -n "${config[proxyjump]}" || -n "${config[proxycommand]}" || -n "${config[dynamicforward]}" || ${#local_forwards[@]} -gt 0 || ${#remote_forwards[@]} -gt 0 ]] && has_proxy_info=1
        
        local total_sections=$((has_connection_info + has_auth_info + has_proxy_info))
        local current_section=0

        # Display Connection block
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

        # Display Authentication block
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
            # If multiple identity files are listed, it's likely the default set.
            # If only one is listed, it was probably specified explicitly in the config.
            if (( ${#identity_files[@]} > 1 )); then
                printf "  ${BLUE}${box_char_mid}${RESET}  🔑 IdentityFile:  %s\n" "Default (~/.ssh/id_*)"
            else
                printf "  ${BLUE}${box_char_mid}${RESET}  🔑 IdentityFile:  %s\n" "${identity_files[1]}"
            fi
        fi

        # Display Tunnels & Proxies block
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
        # Finally, execute the actual ssh command.
        command ssh "$@"
    }
fi

# Create aliases for convenience.
if ! command -v s >/dev/null 2>&1; then
    alias s='sshinfo'
fi
if ! command -v connect >/dev/null 2>&1; then
    alias connect='sshinfo'
fi

# The plugin can optionally override the `ssh` command itself.
# This is commented out by default to be non-invasive.
alias ssh='sshinfo'

# --- Autocompletion ---

# Helper function to find all SSH config files by recursively following `Include` directives.
# This is the core of the host discovery mechanism.
_sshinfo_find_all_config_files() {
    local -a queue
    # Start with the user's main config file, if it exists.
    [[ -f "$HOME/.ssh/config" ]] && queue=("$HOME/.ssh/config")
    local -a seen=("${queue[@]}")
    local i=1
    # Use a queue to perform a breadth-first search of all included files.
    while (( i <= ${#queue} )); do
        local file="${queue[i++]}"
        local config_dir="${file:h}" # Get the directory of the current file.

        # Read the file line by line to find "Include" directives.
        local line
        while IFS= read -r line; do
            # Match "Include" case-insensitively at the start of a line.
            if [[ ${line:l} =~ '^[[:space:]]*include[[:space:]]' ]]; then
                # Extract the path/pattern after "Include".
                local patterns_str=${line#*[iI][nN][cC][lL][uU][dD][eE] }
                # Use Zsh's `(z)` flag to handle quoted paths correctly.
                local -a patterns=("${(z)patterns_str}")
                for pattern in "${patterns[@]}"; do
                    local full_pattern
                    # Prepend the parent directory path if the pattern is relative.
                    [[ "$pattern" != /* && "$pattern" != ~* ]] && full_pattern="$config_dir/$pattern" || full_pattern="$pattern"
                    # Expand tilde and globs to find all matching files.
                    local -a found_files=(${~full_pattern}(N))
                    for f in "${found_files[@]}"; do
                        # Check if the file is a real file and hasn't been seen before.
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

# Helper function to extract non-wildcard host aliases from a list of config files.
_sshinfo_parse_hosts_from_files() {
    # Use awk for efficient parsing of multiple files.
    awk '
        # Skip comments and empty lines.
        /^[[:space:]]*($|#)/{next} 
        # For lines starting with "Host", iterate through the host aliases.
        tolower($1)=="host"{
            for(i=2;i<=NF;i++){
                # Stop if a comment starts mid-line.
                if(substr($i,1,1)=="#")break;
                # Ignore wildcard hosts and negated hosts.
                if($i!~/[*?]/&&$i!~/^!/)print $i
            }
        }' "$@" 2>/dev/null
}

# Main completion function that orchestrates the process.
# This function is called by Zsh when the user presses Tab after a registered command.
_sshinfo_complete() {
    local -a hosts

    # 1. Get hosts from all config files (`~/.ssh/config` and all included files).
    local -a config_files
    config_files=($(_sshinfo_find_all_config_files))
    if (( ${#config_files[@]} > 0 )); then
        hosts+=($(_sshinfo_parse_hosts_from_files "${config_files[@]}"))
    fi

    # 2. Get hosts from `known_hosts` file for completeness, filtering out hashed entries.
    if [[ -r "${HOME}/.ssh/known_hosts" ]]; then
        # Ignore comments and hashed hosts (lines starting with '|').
        # Split comma-separated hosts onto new lines for individual completion.
        hosts+=($(awk '!/^(#|\|)/{print $1}' "${HOME}/.ssh/known_hosts" | tr ',' '\n'))
    fi

    # 3. Create a unique list of hosts using Zsh parameter expansion.
    local -a unique_hosts
    unique_hosts=("${(@u)hosts}")
    
    # 4. Final cleanup: remove a strange 'line=''' artifact that can sometimes appear.
    unique_hosts=("${(@)unique_hosts:#line=''}")

    # 5. Provide the clean list to Zsh's completion system.
    compadd -a unique_hosts
}

# Explicitly bind the completion function to the `sshinfo` command and its aliases.
# This ensures our completion takes precedence over any default ssh completions.
compdef _sshinfo_complete sshinfo s connect
