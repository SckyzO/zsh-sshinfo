# Oh My Zsh sshinfo plugin
#
# A plugin that displays resolved SSH connection information before connecting.

# Check if the function exists to avoid re-definition
if ! command -v sshinfo >/dev/null 2>&1; then
    sshinfo() {
        # --- Argument Parsing: Find the hostname ---
        # The hostname is usually the last argument that doesn't start with a hyphen.
        local target=""
        for arg in "$@"; do
            if [[ "$arg" != -* ]]; then
                target="$arg"
            fi
        done

        # If no target is found, print usage and exit.
        if [ -z "$target" ]; then
            echo "Usage: ssh [options] <hostname>"
            # Use `command ssh` to let the original command handle the error.
            command ssh "$@"
            return
        fi

        # --- Color Definitions ---
        local GREEN BLUE YELLOW RED RESET
        if [[ -n "$TERM" && "$TERM" != "dumb" ]]; then
            # Use tput for better terminal compatibility
            GREEN="$(tput setaf 2)"
            BLUE="$(tput setaf 4)"
            YELLOW="$(tput setaf 3)"
            RED="$(tput setaf 1)"
            RESET="$(tput sgr0)"
        fi

        # --- SSH Configuration Fetching ---
        # Use `ssh -G` to get the computed configuration.
        # Redirect stderr to /dev/null to suppress errors if the host is not found.
        local ssh_output
        if ! ssh_output=$(ssh -G "$target" 2>/dev/null) || [ -z "$ssh_output" ]; then
            echo "${RED}❌ Host '$target' not found or error in SSH configuration.${RESET}"
            # Fallback to the regular ssh command to let it show the native error.
            command ssh "$@"
            return $?
        fi

        # --- Key-Value Parsing ---
        local -A params
        local -A multi_value_params
        
        # These keys can appear multiple times and should be grouped.
        local multi_value_keys=("localforward" "remoteforward" "certificatefile" "identityfile")

        while IFS= read -r line; do
            local keyword="${line%% *}"
            local value="${line#* }"
            keyword="${keyword:l}" # Standardize to lowercase

            # Check if the key is a multi-value key
            if [[ " ${multi_value_keys[*]} " =~ " ${keyword} " ]]; then
                multi_value_params[$keyword]+="$value\n"
            else
                params[$keyword]="$value"
            fi
        done <<< "$ssh_output"

        # --- Displaying Configuration ---
        echo "${GREEN}✅ Connecting to: $target${RESET}"

        # Get all unique keys and sort them alphabetically
        local sorted_keys
        sorted_keys=(${(k)params})
        
        for key in ${(o)sorted_keys}; do
            # Exclude keys that are not very useful for the user to see
            if [[ "$key" == "exitonforwardfailure" ]]; then
                continue
            fi
            
            # Format the key for display (e.g., "hostname" -> "HostName")
            local display_key
            display_key="$(tr '[:lower:]' '[:upper:]' <<< ${key:0:1})${key:1}"
            
            printf "  ${BLUE}↪ %-20s:${RESET} %s\n" "$display_key" "${params[$key]}"
        done

        # Display multi-value parameters
        for key in ${(k)multi_value_params}; do
            local display_key
            display_key="$(tr '[:lower:]' '[:upper:]' <<< ${key:0:1})${key:1}s" # Pluralize
            
            printf "  ${BLUE}↪ %-20s:${RESET}\n" "$display_key"
            # Trim trailing newline before printing
            printf "%s" "${multi_value_params[$key]%\\n}" | while IFS= read -r line; do
                printf "      ${YELLOW}- %s${RESET}\n" "$line"
            done
        done

        echo
        # Use `command ssh` to call the original ssh command, not the alias/function itself.
        command ssh "$@"
    }
fi

# --- Alias Definitions ---
# Define aliases only if they don't already exist to avoid conflicts.
if ! command -v s >/dev/null 2>&1; then
    alias s='sshinfo'
fi
if ! command -v connect >/dev/null 2>&1; then
    alias connect='sshinfo'
fi
# This is the main alias. It should be defined last to ensure it overrides any other alias.
alias ssh='sshinfo'