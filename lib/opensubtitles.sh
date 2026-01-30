#!/bin/bash

# =============================================================================
# lib/opensubtitles.sh
# OpenSubtitles.com API client library
# Documentation: https://opensubtitles.stoplight.io/docs/opensubtitles-api
# =============================================================================

# Source common utilities
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_LIB_DIR/common.sh"

readonly OPENSUBTITLES_API_URL="https://api.opensubtitles.com/api/v1"
readonly OPENSUBTITLES_USER_AGENT="vreely v1.0"

# Global variable to store auth token
_OPENSUBTITLES_TOKEN=""

# --- Authentication ---

# Login to OpenSubtitles and get JWT token
# Sets _OPENSUBTITLES_TOKEN on success
opensubtitles_login() {
    require_env "OPENSUBTITLES_USERNAME"
    require_env "OPENSUBTITLES_PASSWORD"

    log_info "Authenticating with OpenSubtitles..."

    local response
    response=$(curl -s -L -X POST \
        "${OPENSUBTITLES_API_URL}/login" \
        -H "Content-Type: application/json" \
        -H "User-Agent: ${OPENSUBTITLES_USER_AGENT}" \
        -H "Api-Key: ${OPENSUBTITLES_API_KEY}" \
        -d "{\"username\":\"${OPENSUBTITLES_USERNAME}\",\"password\":\"${OPENSUBTITLES_PASSWORD}\"}")

    log_debug "Login response: $response"

    # Parse token from JSON response
    _OPENSUBTITLES_TOKEN=$(echo "$response" | jq -r '.token // empty')

    if [ -z "$_OPENSUBTITLES_TOKEN" ]; then
        local error_msg
        error_msg=$(echo "$response" | jq -r '.message // "Unknown error"')
        die "OpenSubtitles login failed: $error_msg"
    fi

    log_success "Authenticated successfully"
}

# --- Search Subtitles ---

# Search for subtitles by file hash and metadata
# Usage: opensubtitles_search <movie_hash> <file_size> [language_codes]
# Returns: JSON array of subtitle results
opensubtitles_search() {
    local movie_hash="$1"
    local file_size="$2"
    local languages="${3:-en}"  # Default to English

    if [ -z "$_OPENSUBTITLES_TOKEN" ]; then
        die "Not authenticated. Call opensubtitles_login first."
    fi

    log_info "Searching for subtitles (hash: $movie_hash, size: $file_size, languages: $languages)..."

    local url="${OPENSUBTITLES_API_URL}/subtitles?moviehash=${movie_hash}&moviebytesize=${file_size}&languages=${languages}"

    log_debug "Search URL: $url"

    local response
    local http_code
    local temp_file
    temp_file=$(create_temp_file)

    http_code=$(curl -s -L -w "%{http_code}" -o "$temp_file" -X GET \
        "$url" \
        -H "User-Agent: ${OPENSUBTITLES_USER_AGENT}" \
        -H "Api-Key: ${OPENSUBTITLES_API_KEY}" \
        -H "Authorization: Bearer ${_OPENSUBTITLES_TOKEN}")

    response=$(cat "$temp_file")
    rm -f "$temp_file"

    log_debug "HTTP Status: $http_code"
    log_debug "Search response: $response"

    # Check if response is valid JSON
    if ! echo "$response" | jq empty 2>/dev/null; then
        log_error "Invalid JSON response from API:"
        log_error "$response"
        echo "[]"
        return 1
    fi

    # Check for errors
    local error_msg
    error_msg=$(echo "$response" | jq -r '.message // empty')
    if [ -n "$error_msg" ]; then
        log_error "Search failed: $error_msg"
        echo "[]"
        return 1
    fi

    # Return the data array
    local data_array
    data_array=$(echo "$response" | jq -c '.data // []')
    log_debug "Returning data array: $data_array"
    echo "$data_array"
}

# --- Download Subtitles ---

# Request a download link for a subtitle file
# Usage: opensubtitles_get_download_link <file_id>
# Returns: Download URL
opensubtitles_get_download_link() {
    local file_id="$1"

    if [ -z "$_OPENSUBTITLES_TOKEN" ]; then
        die "Not authenticated. Call opensubtitles_login first."
    fi

    log_info "Requesting download link for file ID: $file_id..."

    local response
    response=$(curl -s -L -X POST \
        "${OPENSUBTITLES_API_URL}/download" \
        -H "Content-Type: application/json" \
        -H "User-Agent: ${OPENSUBTITLES_USER_AGENT}" \
        -H "Api-Key: ${OPENSUBTITLES_API_KEY}" \
        -H "Authorization: Bearer ${_OPENSUBTITLES_TOKEN}" \
        -d "{\"file_id\":${file_id}}")

    log_debug "Download link response: $response"

    # Parse download link
    local download_link
    download_link=$(echo "$response" | jq -r '.link // empty')

    if [ -z "$download_link" ]; then
        local error_msg
        error_msg=$(echo "$response" | jq -r '.message // "Unknown error"')
        die "Failed to get download link: $error_msg"
    fi

    echo "$download_link"
}

# Download subtitle file to specified path
# Usage: opensubtitles_download_file <download_url> <output_path>
opensubtitles_download_file() {
    local download_url="$1"
    local output_path="$2"

    log_info "Downloading subtitle to: $output_path..."

    if ! curl -s -L -o "$output_path" "$download_url"; then
        die "Failed to download subtitle file"
    fi

    log_success "Downloaded: $output_path"
}

# --- Utility Functions ---

# Calculate OpenSubtitles hash for a video file
# This is a specific hash algorithm required by OpenSubtitles API
# Usage: opensubtitles_hash <video_file>
opensubtitles_hash() {
    local filepath="$1"
    require_file "$filepath"

    # OpenSubtitles hash is 64-bit hash:
    # - First 64KB of file
    # - Last 64KB of file
    # - File size
    # All combined with XOR operations

    # For now, use a Python one-liner if available, otherwise fail gracefully
    if command -v python3 &> /dev/null; then
        python3 -c "
import struct
import sys

def opensubtitles_hash(filepath):
    longlongformat = 'q'  # long long
    bytesize = struct.calcsize(longlongformat)
    filesize = sys.maxsize
    hash_value = 0

    with open(filepath, 'rb') as f:
        filesize = f.seek(0, 2)  # Seek to end
        f.seek(0, 0)  # Seek to start

        hash_value = filesize

        if filesize < 65536 * 2:
            return 0

        # First 64KB
        for _ in range(65536 // bytesize):
            buffer = f.read(bytesize)
            (l_value,) = struct.unpack(longlongformat, buffer)
            hash_value = (hash_value + l_value) & 0xFFFFFFFFFFFFFFFF

        # Last 64KB
        f.seek(-65536, 2)
        for _ in range(65536 // bytesize):
            buffer = f.read(bytesize)
            (l_value,) = struct.unpack(longlongformat, buffer)
            hash_value = (hash_value + l_value) & 0xFFFFFFFFFFFFFFFF

    return '%016x' % hash_value

print(opensubtitles_hash('$filepath'))
" 2>/dev/null
    else
        die "Python3 is required to calculate OpenSubtitles hash"
    fi
}

# Get file size in bytes
opensubtitles_get_filesize() {
    local filepath="$1"
    require_file "$filepath"

    if [[ "$OSTYPE" == "darwin"* ]]; then
        stat -f%z "$filepath"
    else
        stat -c%s "$filepath"
    fi
}
