#!/bin/bash 

# -------------------------------------------------------------------
# Functions
# -------------------------------------------------------------------

# -------------------------------------------------------------------
# setup_pf
# Configures SR-IOV for a physical function (PF) by disabling and 
# deleting existing virtual functions (VFs), creating the specified 
# number of VFs, and assigning MAC addresses to them based on a MAC 
# prefix. The last byte of the prefix is incremented for each VF.
# Arguments:
#   $1 - Reference to an associative array containing PF configuration details.
#        Each entry should have the following format:
#        dev num_vfs mac_prefix comment
#   $2 - Optional dry-run flag (true/false) to simulate changes without applying them.
# -------------------------------------------------------------------
setup_pf () {
    local -n _pf_config=$1
    local dry_run=$2
    declare -i config_entries_cnt
    local start_vf=0
    
    config_entries_cnt=$(count_entries _pf_config)

    if (( config_entries_cnt < 1 )); then
        handle_error "No PF configuration entries found"
    fi

    log DEBUG "=== PF Setup ==="
    log DEBUG "There are $config_entries_cnt PF configuration items"
    log DEBUG ""

    # Loop through all PF configurations
    for key in "${!_pf_config[@]}"; do
        # Read values from configuration
        IFS=' ' read -r dev num_vfs mac_prefix comment <<< "${_pf_config[$key]}"

        log INFO "Disabling SR-IOV autoprobe (auto driver binding) on $dev"
        [[ $dry_run != "true" ]] && echo 0 > /sys/class/net/$dev/device/sriov_drivers_autoprobe

        log INFO "Deleting existing Virtual Functions (VFs) on $dev"
        [[ $dry_run != "true" ]] && echo 0 > /sys/class/net/$dev/device/sriov_numvfs

        log INFO "Creating $num_vfs Virtual Functions on $dev"
        [[ $dry_run != "true" ]] && echo $num_vfs > /sys/class/net/$dev/device/sriov_numvfs

        log INFO "Re-enabling SR-IOV autoprobe (auto driver binding) on $dev"
        [[ $dry_run != "true" ]] && echo 1 > /sys/class/net/$dev/device/sriov_drivers_autoprobe

        # Split MAC prefix into bytes
        IFS=':' read -r -a prefix_bytes <<< "$mac_prefix"

        # Start incrementing from the least significant byte (last byte in the prefix)
        local suffix_start=$((16#${prefix_bytes[5]}))  # Convert last byte to decimal

        # Check for overflow in MAC address suffix
        if (( (suffix_start + num_vfs - 1) > 255 )); then
            local overage=$(( (suffix_start + num_vfs - 1) - 255 ))
            handle_error "LSB in MAC prefix for $dev needs to be reduced by $overage to prevent overflow"
        fi

        # Assign MAC addresses to each VF
        for ((i = 0; i < num_vfs; i++)); do
            local vf=$((start_vf + i))                    # Calculate VF index
            local suffix=$((suffix_start + i))            # Increment the suffix byte

            # Generate the MAC address by replacing the last byte
            prefix_bytes[5]=$(printf "%02x" $suffix)      # Modify the last byte (index 5)

            # Combine the prefix and suffix to form the full 6-byte MAC address
            local mac="${prefix_bytes[0]}:${prefix_bytes[1]}:${prefix_bytes[2]}:${prefix_bytes[3]}:${prefix_bytes[4]}:${prefix_bytes[5]}"

            log INFO "Assigning MAC $mac to $dev VF $vf"
            [[ $dry_run != "true" ]] && ip link set "$dev" vf "$vf" mac "$mac"
        done

    done
}
