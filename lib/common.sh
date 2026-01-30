#!/bin/bash

# =============================================================================
# lib/common.sh
# Common utility functions for bash scripts
# =============================================================================

# Source guard - prevent multiple sourcing
[[ -n "${_COMMON_SH_LOADED:-}" ]] && return
readonly _COMMON_SH_LOADED=1

# --- Color codes for output ---
readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_RESET='\033[0m'

# --- Logging Functions ---

log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*" >&2
}

log_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*" >&2
}

log_warn() {
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*" >&2
}

log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
}

log_debug() {
    if [ "${DEBUG:-false}" == "true" ]; then
        echo -e "${COLOR_YELLOW}[DEBUG]${COLOR_RESET} $*" >&2
    fi
}

# --- Error Handling ---

die() {
    log_error "$*"
    exit 1
}

require_command() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        die "Required command not found: $cmd"
    fi
}

require_file() {
    local file="$1"
    if [ ! -f "$file" ]; then
        die "Required file not found: $file"
    fi
}

require_env() {
    local var_name="$1"
    if [ -z "${!var_name:-}" ]; then
        die "Required environment variable not set: $var_name"
    fi
}

# --- File Validation ---

validate_video_file() {
    local file="$1"
    require_file "$file"

    local mime_type
    mime_type=$(file -b --mime-type "$file")

    if [[ ! "$mime_type" =~ ^video/ ]]; then
        die "File is not a video file: $file (type: $mime_type)"
    fi
}

# --- Path Utilities ---

get_absolute_path() {
    local path="$1"
    if [[ "$path" = /* ]]; then
        echo "$path"
    else
        echo "$(pwd)/$path"
    fi
}

get_filename_without_ext() {
    local filepath="$1"
    local filename
    filename=$(basename "$filepath")
    echo "${filename%.*}"
}

get_file_extension() {
    local filepath="$1"
    local filename
    filename=$(basename "$filepath")
    echo "${filename##*.}"
}

# --- String Utilities ---

trim() {
    local str="$1"
    # Remove leading and trailing whitespace
    str="${str#"${str%%[![:space:]]*}"}"
    str="${str%"${str##*[![:space:]]}"}"
    echo "$str"
}

# --- Temporary File Handling ---

create_temp_file() {
    mktemp "${TMPDIR:-/tmp}/vreely.XXXXXXXXXX"
}

create_temp_dir() {
    mktemp -d "${TMPDIR:-/tmp}/vreely.XXXXXXXXXX"
}
