#!/bin/bash 

# -------------------------------------------------------------------
# Functions
# -------------------------------------------------------------------

# -------------------------------------------------------------------
# make_vf_label
# Constructs a consistent label for a Virtual Function.
#
# Arguments:
#   $1 - PF device name (e.g., enlan3)
#   $2 - VF index (e.g., 31)
#   $3 - Reference to variable to store the label
# -------------------------------------------------------------------
make_vf_label() {
    local dev="$1"
    local vf_idx="$2"
    local _resultvar="$3"

    if [[ -z "$dev" || -z "$vf_idx" || -z "$_resultvar" ]]; then
        handle_error "make_vf_label requires three arguments: <dev> <vf_idx> <result var>"
    fi

    printf -v "$_resultvar" "%s" "${dev}vf${vf_idx}"
}

# ------------------------------------------------------------------------------
# get_net_pcie_slot_name
#
# Retrieves the PCI slot name for a given network device or its virtual function.
#
# Arguments:
#   $1 - Network device name (e.g., eth0, enp1s0)
#   $2 - (Optional) Virtual function number (e.g., 0, 1, 2...). If omitted, uses PF.
#   $3 - Name of variable to store the result (pass-by-reference)
#
# Sets:
#   The variable named in $3 will contain the PCI slot name.
# ------------------------------------------------------------------------------
get_net_pcie_slot_name() {
    local dev="$1"
    local vf_num="$2"
    local _resultvar="$3"
    local uevent_path

    if [[ -z "$dev" ]]; then
        handle_error "get_net_pcie_slot_name: missing device argument"
    fi

    if [[ -z "$_resultvar" ]]; then
        handle_error "get_net_pcie_slot_name: missing reference variable name"
    fi

    if [[ -n "$vf_num" ]]; then
        uevent_path="/sys/class/net/$dev/device/virtfn${vf_num}/uevent"
    else
        uevent_path="/sys/class/net/$dev/device/uevent"
    fi

    if [[ ! -f "$uevent_path" ]]; then
        handle_error "get_net_pcie_slot_name: uevent file not found at $uevent_path"
    fi

    local slot_name
    slot_name=$(grep '^PCI_SLOT_NAME=' "$uevent_path" | cut -d= -f2)

    if [[ -z "$slot_name" ]]; then
        handle_error "get_net_pcie_slot_name: PCI_SLOT_NAME not found in $uevent_path"
    fi

    # Use indirect reference to set the variable
    printf -v "$_resultvar" "%s" "$slot_name"

}

# ------------------------------------------------------------------------------
# set_net_vf_name <PF_NAME> <VF_INDEX> <VF_TARGET_NAME>
#
# Renames the network interface of a specific Virtual Function (VF) to a
# predictable format: <VF_TARGET_NAME>.
#
# Arguments:
#   $1 - PF (Physical Function) network device name (e.g. enlan3)
#   $2 - VF index number (e.g. 31)
#   $3 - Desired new name for the VF network device (e.g. enlan3v31)
#
# Notes:
# - The VF must already have a network interface bound (driver loaded).
# - Waits up to 10 seconds for the VF's network device to appear.
# - Exits with error code 1 on timeout or failure.
# ------------------------------------------------------------------------------
function set_net_vf_name() {
  local pf_name="$1"
  local vf_index="$2"
  local vf_target_name="$3"
  local timeout=10
  local vf_dev_path="/sys/class/net/$pf_name/device/virtfn$vf_index/net"
  local vf_dev_name=""

  if [[ -z "$pf_name" || -z "$vf_index" || -z "$vf_target_name" ]]; then
    handle_error "Usage: set_net_vf_name <PF_NAME> <VF_INDEX> <VF_TARGET_NAME>"
  fi

  # Wait up to $timeout seconds for the VF's network device to appear
  for ((i = 0; i < timeout; i++)); do
    local vf_dev_file
    vf_dev_file=$(readlink -f "$vf_dev_path"/* 2>/dev/null)

    if [[ -n "$vf_dev_file" ]]; then
      vf_dev_name=$(basename "$vf_dev_file")
      break
    fi

    sleep 1
  done

  if [[ -z "$vf_dev_name" ]]; then
    handle_error "Timeout after $timeout seconds — VF network device not found for PF '$pf_name' VF index $vf_index"
  fi

  log INFO "Renaming PF device $pf_name VF $vf_index to $vf_target_name"
  ip link set dev "$vf_dev_name" name "$vf_target_name"

}

# ---------------------------------------------------------------------------
# process_vf_config_line
#
# Applies VF configuration from a single config line.
#
# Arguments:
#   $1 - Config line string (e.g. "enlan3 3 100 true true iavf # comment")
#   $2 - Dry-run flag (e.g. "true" to skip actual changes)
#
# Behavior:
#   - Sets the VLAN for the specified VF.
#   - Optionally activates the VF by binding it to a driver.
#   - Optionally renames the VF interface to a predictable format.
#
# Notes:
#   - Assumes config line is space-separated and well-formed.
# ---------------------------------------------------------------------------
process_vf_config_line() {
    local config_line="$1"
    local dry_run="$2"

    # Parse configuration line into components
    IFS=' ' read -r dev vf_idx vlan activate rename driver comment <<< "$config_line"

    # Generate VF label
    local vf_label
    make_vf_label "$dev" "$vf_idx" vf_label

    log INFO "Setting $vf_label to VLAN $vlan"
    [[ "$dry_run" != "true" ]] && ip link set dev "$dev" vf "$vf_idx" vlan "$vlan"

    if [[ "$activate" == "true" ]]; then
        local pci_slot_name
        get_net_pcie_slot_name "$dev" "$vf_idx" pci_slot_name

        log INFO "Activating VF $vf_label (PCI $pci_slot_name) with driver $driver"

        # Unbind the current driver if it's already bound (only if dry_run is not set)
        if [[ "$dry_run" != "true" ]]; then
            driver_path="/sys/class/net/$vf_label/device/driver"
            if [[ -e "$driver_path" ]]; then
                driver_name=$(basename "$(readlink -f "$driver_path")")
                echo "$pci_slot_name" > "/sys/bus/pci/drivers/$driver_name/unbind"
                log DEBUG "Unbound VF $vf_label (PCI $pci_slot_name) from driver $driver_name"
            else
                log DEBUG "No driver bound for VF $vf_label (PCI $pci_slot_name)"
            fi
        else
            log DEBUG "Dry-run mode: Skipping unbind for VF $vf_label (PCI $pci_slot_name)"
        fi

        # Bind to the desired driver
        [[ "$dry_run" != "true" ]] && echo "$pci_slot_name" > "/sys/bus/pci/drivers/$driver/bind"
    fi

    if [[ "$rename" == "true" ]]; then
        log INFO "Renaming $vf_label"
        [[ "$dry_run" != "true" ]] && set_net_vf_name "$dev" "$vf_idx" "$vf_label"
    fi

}

# -------------------------------------------------------------------
# setup_vf
#
# Configures SR-IOV Virtual Functions (VFs) based on provided configuration.
#
# Arguments:
#   $1 - Name of associative array (pass by reference) containing VF configs.
#        Each value should follow this format:
#        dev vf_idx vlan activate rename driver comment
#   $2 - Optional: "true" to simulate actions without applying changes.
#
# Notes:
#   - Uses 'process_vf_config_line' to apply each VF configuration.
#   - Exits with an error if no VF entries are found.
# -------------------------------------------------------------------
setup_vf() {
    local -n _vf_config=$1   # Reference to associative array
    local dry_run=$2
    local config_entries_cnt

    config_entries_cnt=$(count_entries _vf_config)

    if (( config_entries_cnt < 1 )); then
        handle_error "setup_vf: no VF configuration entries found"
    fi

    log DEBUG "=== VF Setup ==="
    log DEBUG "Found $config_entries_cnt VF configuration item(s)"
    log DEBUG ""

    for key in "${!_vf_config[@]}"; do
        process_vf_config_line "${_vf_config[$key]}" "$dry_run"
    done
    
}
