#!/bin/bash 

# -------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------
BASE_DIR="$(dirname "${BASH_SOURCE[0]}")"
CONFIG_DIR="$BASE_DIR/config"
UTILS_DIR="$BASE_DIR/utils"
LIB_DIR="$BASE_DIR/lib"
CONFIG_FILE="$CONFIG_DIR/sriov-net.config"

LOG_TIMESTAMP=false
LOG_DEBUG=false

DRY_RUN=false
SPECIFIC_VF=""
CONFIG_REPORT=false

# -------------------------------------------------------------------
# Load modules
# -------------------------------------------------------------------
source "$UTILS_DIR/common.sh"
source "$LIB_DIR/config_parser.sh"
source "$LIB_DIR/setup_pf.sh"
source "$LIB_DIR/setup_vf.sh"

# -------------------------------------------------------------------
# Globals
# -------------------------------------------------------------------
declare -a all_lines
declare -a host_lines

declare -A vf_config
declare -A pf_config

host_name="$(hostname -s)"
commit_hash=$(git -C "$BASE_DIR" rev-parse --short HEAD)

# -------------------------------------------------------------------
# Functions
# -------------------------------------------------------------------

# ------------------------------------------------------------------------------
# parse_args
#
# This function parses the command-line arguments for the script. It handles 
# options such as specifying a config file, setting the VF device and index, 
# overriding the hostname, enabling verbose mode, enabling dry-run mode, and 
# displaying a help message.
#
# Arguments:
#   $1... - The command-line arguments passed to the script.
#
# Sets global variables:
#   - CONFIG_FILE: Path to the configuration file (optional - defaults to sriov-net-vfs.config)
#   - SPECIFIC_VF: The device and VF index for specific VF configuration.
#   - host_name: The hostname for override.
#   - LOG_DEBUG: Enables or disables debug output based on --verbose flag.
#   - DRY_RUN: Enables or disables dry-run mode based on --dry-run flag.
#   - CONFIG_REPORT: Enables or disables the configuration report based on --config-report flag.
#
# Usage:
#   parse_args "$@"
# ------------------------------------------------------------------------------
parse_args() {
    while [[ "$1" != "" ]]; do
        case $1 in
            --config)
                if [[ -z "$2" ]]; then
                    handle_error "$1 requires a file path argument"
                fi
                CONFIG_FILE="$2"
                shift 2
                ;;

            --vf)
                if [[ -z "$2" || -z "$3" ]]; then
                    log ERROR "--vf requires two arguments (device and VF index)"
                    exit 1
                fi
                SPECIFIC_VF="$2 $3"
                shift 3
                ;;

            --host)
                if [[ -z "$2" ]]; then
                    handle_error "$1 requires a hostname argument"
                fi
                host_name="$2"
                shift 2
                ;;

            --verbose)
                LOG_DEBUG=true
                shift
                ;;

            --dry-run)
                DRY_RUN=true
                shift
                ;;

            --config-report)
                CONFIG_REPORT=true
                shift
                ;;

            --help)
                echo "SR-IOV Net Configurator $commit_hash"
                echo "Usage: $0 [--config <file>] [--vf <dev> <vf>] [--host <hostname>] [--verbose] [--dry-run] [--help]"
                echo ""
                echo "All parameters are optional:"
                echo "  --config <file>   : Path to the config file (e.g., --config sriov-net.config)"
                echo "  --vf <dev> <vf>   : Configure a specific VF (e.g., --vf enlan3 21)"
                echo "  --host <hostname> : Override the hostname (e.g., --host myhost)"
                echo "  --verbose         : Enable debug output"
                echo "  --dry-run         : Run in dry-run mode (no changes will be made)"
                echo "  --config-report   : Show detailed configuration report"
                echo "  --help            : Show this help message"
                exit 0
                ;;

            *)
                handle_error "Invalid option $1, try --help for usage"
                ;;
        esac
    done

}

# -------------------------------------------------------------------
# detailed_config_breakdown_report
#
# Logs a detailed breakdown of the parsed VF and PF configuration.
# This is useful for diagnostics and validating config input.
# -------------------------------------------------------------------
detailed_config_breakdown_report() {
    log INFO "=== VF Configuration Entries ==="
    for key in "${!vf_config[@]}"; do
        IFS=' ' read -r dev vf_idx vlan activate rename driver comment <<< "${vf_config[$key]}"
        
        log INFO "Key:         $key"
        log INFO "  Device:    $dev"
        log INFO "  VF Index:  $vf_idx"
        log INFO "  VLAN:      $vlan"
        log INFO "  Activate:  $activate"
        log INFO "  Rename:    $rename"
        log INFO "  Driver:    $driver"
        [[ -n "$comment" ]] && log INFO "  Comment:   $comment"
        log INFO
    done

    log INFO "=== PF Configuration Entries ==="
    for key in "${!pf_config[@]}"; do
        IFS=' ' read -r dev num_vfs mac_prefix comment <<< "${pf_config[$key]}"
        
        log INFO "Key:         $key"
        log INFO "  Device:    $dev"
        log INFO "  Num VFs:   $num_vfs"
        log INFO "  MAC Prefix:$mac_prefix"
        [[ -n "$comment" ]] && log INFO "  Comment:   $comment"
        log INFO
    done
}

# -------------------------------------------------------------------
# Main
# -------------------------------------------------------------------

# Parse all arguments
parse_args "$@"

log DEBUG  "=== Core ==="
log DEBUG "Bash version: $BASH_VERSION"
log DEBUG "Hostname: $host_name"
log DEBUG "Dry run: $DRY_RUN"
log DEBUG "Config report: $CONFIG_REPORT"
log DEBUG "Git commit hash: $commit_hash"
log DEBUG ""

log DEBUG  "=== Directories & Files ==="
log DEBUG "Working directory: $(pwd)"
log DEBUG "Base directory: $BASE_DIR"
log DEBUG "Config directory: $CONFIG_DIR"
log DEBUG "Lib directory: $LIB_DIR"
log DEBUG "Util directory: $UTILS_DIR"
log DEBUG "Config file: $CONFIG_FILE"
log DEBUG ""

# Use the functions to read and parse config
read_config_file "$CONFIG_FILE" "$host_name" all_lines host_lines
parse_config_lines vf_config pf_config

# Debug: show parsed results
log DEBUG  "=== VF Config ==="
for key in "${!vf_config[@]}"; do
    log DEBUG  "$key => ${vf_config[$key]}"
done
log DEBUG ""

log DEBUG "=== PF Config ==="
for key in "${!pf_config[@]}"; do
    log DEBUG "$key => ${pf_config[$key]}"
done
log DEBUG ""

log INFO "Starting SR-IOV configuration"

if [[ "$CONFIG_REPORT" == "true" ]]; then
    # If CONFIG_REPORT is not set, show the detailed configuration breakdown
    detailed_config_breakdown_report

elif [[ -z "$SPECIFIC_VF" ]]; then
    # If no specific VF is provided, set up all PFs and VFs
    setup_pf pf_config "$DRY_RUN"
    setup_vf vf_config "$DRY_RUN"

else
    # Parse the specific VF definition into device and index
    IFS=' ' read -r dev vf_idx <<< "$SPECIFIC_VF"
    # Use the global VF_LABEL
    make_vf_label "$dev" "$vf_idx" VF_LABEL

    # Check if the specified VF exists in the configuration
    if [[ -z "${vf_config[$VF_LABEL]}" ]]; then
        handle_error "VF $VF_LABEL does not exist in the configuration"
    else
        log DEBUG "VF $VF_LABEL found in the configuration, processing it"
        
        # Process the configuration for the specific VF
        process_vf_config_line "${vf_config[$VF_LABEL]}" "$DRY_RUN"
    fi

    # Clean up local variable after use
    unset VF_LABEL
fi

log INFO "All done! SR-IOV configuration completed successfully"
