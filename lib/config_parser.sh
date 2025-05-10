#!/bin/bash 

# -------------------------------------------------------------------
# Functions
# -------------------------------------------------------------------

# -------------------------------------------------------------------
# read_config_file
# Parses a configuration file, categorising lines into:
#   - Global lines under the "all" section
#   - Host-specific lines under a section matching the current host
#
# Arguments:
#   $1 - Path to the configuration file
#   $2 - Current host name
#   $3 - Name reference to an array for global lines ("all" section)
#   $4 - Name reference to an array for host-specific lines
# -------------------------------------------------------------------
read_config_file() {
    local config_file="$1"        # Path to the configuration file
    local current_host_name="$2"  # Hostname for host-specific filtering
    local -n _all_lines="$3"      # Name reference: array for "all" section lines
    local -n _host_lines="$4"     # Name reference: array for host-specific lines
    local current_section=""

    # Check that the file exists and is readable
    if [[ ! -r "$config_file" ]]; then
        handle_error "Config file '$config_file' not found or not readable"
    fi

    while IFS= read -r line; do
        line="$(trim "$line")"                          # Trim whitespace
        [[ -z "$line" || "$line" == \#* ]] && continue  # Skip empty lines and comments

        # Match section headers like "all:" or "hostname:"
        if [[ "$line" =~ ^([a-zA-Z0-9_-]+):$ ]]; then
            current_section="${BASH_REMATCH[1]}"
            continue
        fi

        # Append line to the appropriate array based on current section
        if [[ "$current_section" == "all" ]]; then
            _all_lines+=("$line")
        elif [[ "$current_section" == "$current_host_name" ]]; then
            _host_lines+=("$line")
        fi
    done < "$config_file"

}

# -------------------------------------------------------------------
# parse_config_lines
# Parses the configuration lines, categorizing them into VF and PF 
# configurations. It validates the input and updates the provided 
# associative arrays.
# Arguments:
#   $1 - Name reference to an associative array (string keys) for VF configuration
#   $2 - name reference to an associative array (string keys) for PF configuration
# -------------------------------------------------------------------
parse_config_lines() {
    local -n _vf_config="$1"     # Name reference: associative array for VF configuration
    local -n _pf_config="$2"     # Name reference: associative array for PF configuration

    # Inner function to parse a single line of config
    parse_line() {
        local line="$1"
        local tokens=()
        read -ra tokens <<< "$line"  # Split line into tokens by whitespace

        # Handle VF config lines: "vf <dev> <vf_idx> <vlan> <activate> <rename> <driver> [# comment]"
        if [[ "${tokens[0]}" == "vf" && "${#tokens[@]}" -ge 7 ]]; then
            local dev="${tokens[1]}"
            local vf_idx="${tokens[2]}"
            local vlan="${tokens[3]}"
            local activate="${tokens[4]}"
            local rename="${tokens[5]}"
            local driver="${tokens[6]}"
            local comment="${tokens[*]:7}"  # Capture everything after the 7th token as a comment

            # Validate each field and exit on error using handle_error
            if ! is_word "$dev"; then handle_error "Invalid VF device: $dev in line: $line"; fi
            if ! is_integer "$vf_idx"; then handle_error "Invalid VF index: $vf_idx in line: $line"; fi
            if ! is_integer "$vlan"; then handle_error "Invalid VLAN: $vlan in line: $line"; fi
            if ! is_bool "$activate"; then handle_error "Invalid activate flag: $activate in line: $line"; fi
            if ! is_bool "$rename"; then handle_error "Invalid rename flag: $rename in line: $line"; fi
            if ! is_word "$driver"; then handle_error "Invalid driver: $driver in line: $line"; fi

            local key="${dev}vf${vf_idx}"  # Use device and VF index as the key
            _vf_config["$key"]="$dev $vf_idx $vlan $activate $rename $driver $comment"

        # Handle PF config lines: "pf <dev> <num_vfs> <mac_prefix> [# comment]"
        elif [[ "${tokens[0]}" == "pf" && "${#tokens[@]}" -ge 4 ]]; then
            local dev="${tokens[1]}"
            local num_vfs="${tokens[2]}"
            local mac_prefix="${tokens[3]}"
            local comment="${tokens[*]:4}"  # Capture everything after the 4th token as a comment

            # Validate each field and exit on error using handle_error
            if ! is_word "$dev"; then handle_error "Invalid PF device: $dev in line: $line"; fi
            if ! is_integer "$num_vfs"; then handle_error "Invalid VF count: $num_vfs in line: $line"; fi
            if ! is_mac "$mac_prefix"; then handle_error "Invalid MAC prefix: $mac_prefix in line: $line"; fi

            _pf_config["$dev"]="$dev $num_vfs $mac_prefix $comment"

        else
            handle_error "Invalid config line: $line"  # Line doesn't match expected VF or PF format
        fi
    }

    # Parse all global lines first (from 'all:' section)
    for line in "${all_lines[@]}"; do
        parse_line "$line"
    done

    # Parse host-specific lines next (from '<hostname>:' section)
    for line in "${host_lines[@]}"; do
        parse_line "$line"
    done

}