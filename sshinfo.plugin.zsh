# Oh My Zsh sshinfo plugin
#
# A plugin that displays SSH connection information before connecting.

# Check if the function exists to avoid re-definition
if ! command -v sshinfo >/dev/null 2>&1; then
    sshinfo() {
        # Ensure there is a target to connect to
        if [ -z "$1" ]; then
            echo "Usage: ssh <hostname>"
            return 1
        fi

        local target="$1"
        local -A params
        local -a locals

        # Define colors for output, use tput for compatibility
        local GREEN BLUE YELLOW RED RESET
        if [[ -n "$TERM" && "$TERM" != "dumb" ]]; then
            GREEN="$(tput setaf 2)"
            BLUE="$(tput setaf 4)"
            YELLOW="$(tput setaf 3)"
            RED="$(tput setaf 1)"
            RESET="$(tput sgr0)"
        fi

        # Use ssh -G to get the computed configuration.
        # Redirect stderr to /dev/null to suppress errors if the host is not found.
        local ssh_output
        if ! ssh_output=$(ssh -G "$target" 2>/dev/null) || [ -z "$ssh_output" ]; then
            echo "${RED}❌ Host '$target' not found or error in SSH configuration.${RESET}"
            # Fallback to regular ssh command to let it handle the error message
            command ssh "$@"
            return
        fi

        # Populate the associative array with parameters.
        while IFS= read -r line; do
            # Use parameter expansion for robustness
            local keyword="${line%% *}"
            local value="${line#* }"
            # Make keyword lowercase to standardize
            keyword="${keyword:l}"

            if [[ "$keyword" == "localforward" ]]; then
                locals+=("$value")
            else
                params[$keyword]="$value"
            fi
        done <<< "$ssh_output"

        # Define the order and display names for parameters
        local -A display_names=(
            [hostname]="HostName" [port]="Port" [user]="User"
            [proxyjump]="ProxyJump" [proxycommand]="ProxyCommand" [dynamicforward]="DynamicForward"
        )
        local display_order=("hostname" "port" "user" "proxyjump" "proxycommand" "dynamicforward")

        echo "${GREEN}✅ Connecting to: $target${RESET}"
        for key in "${display_order[@]}"; do
            if [[ -n "${params[$key]}" ]]; then
                printf "  ${BLUE}↪ %-15s:${RESET} %s\n" "${display_names[$key]}" "${params[$key]}"
            fi
        done

        if [[ ${#locals[@]} -gt 0 ]]; then
            printf "  ${BLUE}↪ %-15s:${RESET}\n" "LocalForwards"
            for lf in "${locals[@]}"; do
                # Nicer formatting for local forwards
                printf "      ${YELLOW}- %s${RESET}\n" "$lf"
            done
        fi

        echo
        # Use `command ssh` to call the original ssh command, not the alias itself.
        command ssh "$@"
    }
fi

# Define aliases if they don't already exist
if ! command -v s >/dev/null 2>&1; then
    alias s='sshinfo'
fi
if ! command -v connect >/dev/null 2>&1; then
    alias connect='sshinfo'
fi
# This is the main alias. It should be defined last to ensure it overrides any other alias.
alias ssh='sshinfo'
