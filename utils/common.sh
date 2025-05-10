#!/bin/bash 

# -------------------------------------------------------------------
# Functions
# -------------------------------------------------------------------

# -------------------------------------------------------------------
# log
# Logs messages at different levels (INFO, WARN, ERROR, DEBUG)
# Arguments: 
#   $1 - Log level
#   $2... - Message(s)
# --------------------------------------------------------------------
log() {
    local level="$1"
    shift
    local timestamp=""

    if [ "$LOG_TIMESTAMP" = "true" ]; then
        timestamp="[$(date "+%Y-%m-%d %H:%M:%S")] "
    fi

    case "$level" in
        INFO) printf "%sℹ️  Info: %s\n" "$timestamp" "$*" ;;
        WARN) printf "%s⚠️  Warning: %s\n" "$timestamp" "$*" ;;
        ERROR) printf "%s❌  Error: %s\n" "$timestamp" "$*" >&2 ;;
        DEBUG) [ "$LOG_DEBUG" = "true" ] && printf "%s🐛  Debug: %s\n" "$timestamp" "$*" ;;
        *) printf "%s%s\n" "$timestamp" "$*" ;;
    esac

}

# -------------------------------------------------------------------
# handle_error
# Centralised function for error handling: logs error and exits
# Arguments:
#   $1 - Error message
# -------------------------------------------------------------------
handle_error() {
    log ERROR "$1"  # Log the error message
    log DEBUG "Exiting script due to error"  # Optionally log before exit
    exit 1  # Exit the script with status code 1

}

# -------------------------------------------------------------------
# count_entries
# Returns the number of key-value pairs in a given associative array
# Arguments:
#   $1 - Name of the associative array (not a reference!)
# Usage:
#   count=$(count_entries my_assoc_array)
# -------------------------------------------------------------------
count_entries() {
    local array_name="$1"
    local count

    # Use indirect expansion to count elements
    count=$(eval "echo \${#${array_name}[@]}")
    echo "$count"

}

# -------------------------------------------------------------------
# Function to trim leading and trailing whitespace
# -------------------------------------------------------------------
trim() {
    local var="$1"
    shopt -s extglob
    var="${var##+([[:space:]])}"  # Remove leading space
    var="${var%%+([[:space:]])}"  # Remove trailing space
    echo "$var"
    shopt -u extglob

}

# -------------------------------------------------------------------
# Function to check if the string is a valid MAC address (e.g., 01:23:45:67:89:ab)
# -------------------------------------------------------------------
is_mac() {
    [[ "$1" =~ ^([[:xdigit:]]{2}(:[[:xdigit:]]{2}){5})$ ]]

}

# -------------------------------------------------------------------
# Function to check if the string is a positive integer (e.g., 0, 1, 42)
# -------------------------------------------------------------------
is_integer() {
    [[ "$1" =~ ^[0-9]+$ ]]

}

# -------------------------------------------------------------------
# Function to check if the string is a boolean: 'true' or 'false'
# -------------------------------------------------------------------
is_bool() {
    [[ "$1" == "true" || "$1" == "false" ]]

}

# -------------------------------------------------------------------
# Function to check if the string is a valid word: letters, numbers, underscores, or dashes
# -------------------------------------------------------------------
is_word() {
    [[ "$1" =~ ^[a-zA-Z0-9_-]+$ ]]
    
}
