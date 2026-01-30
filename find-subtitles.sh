#!/bin/bash

# =============================================================================
# find-subtitles.sh
# Search for and download subtitles from OpenSubtitles.com
# Usage: ./find-subtitles.sh <video-file> [language-codes] [output-dir]
# Example: ./find-subtitles.sh movie.mkv en,es ./subtitles
# =============================================================================

set -euo pipefail

# --- Load Libraries ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/opensubtitles.sh"

# --- Load Environment ---
if [ -f "$SCRIPT_DIR/.env" ]; then
    source "$SCRIPT_DIR/.env"
fi

# --- Configuration ---
require_command "curl"
require_command "jq"
require_env "OPENSUBTITLES_API_KEY"
require_env "OPENSUBTITLES_USERNAME"
require_env "OPENSUBTITLES_PASSWORD"

# --- Input Validation ---
if [ "$#" -lt 1 ]; then
    echo "Usage: $0 <video-file> [language-codes] [output-dir]"
    echo ""
    echo "Arguments:"
    echo "  video-file      Path to video file"
    echo "  language-codes  Comma-separated language codes (default: en)"
    echo "                  Examples: en, en,es, en,fr,de"
    echo "  output-dir      Directory to save subtitles (default: same as video)"
    echo ""
    echo "Examples:"
    echo "  $0 movie.mkv"
    echo "  $0 movie.mkv en,es"
    echo "  $0 movie.mkv en ./subtitles"
    exit 1
fi

VIDEO_FILE="$1"
LANGUAGES="${2:-en}"
OUTPUT_DIR="${3:-}"

validate_video_file "$VIDEO_FILE"

# Set output directory to video file's directory if not specified
if [ -z "$OUTPUT_DIR" ]; then
    OUTPUT_DIR="$(dirname "$VIDEO_FILE")"
fi

mkdir -p "$OUTPUT_DIR"

# --- Main Logic ---

log_info "Processing video: $VIDEO_FILE"
log_info "Searching for languages: $LANGUAGES"

# Calculate file hash and size
log_info "Calculating file hash..."
MOVIE_HASH=$(opensubtitles_hash "$VIDEO_FILE")
FILE_SIZE=$(opensubtitles_get_filesize "$VIDEO_FILE")

log_info "Hash: $MOVIE_HASH"
log_info "Size: $FILE_SIZE bytes"

# Authenticate
opensubtitles_login

# Search for subtitles
SEARCH_RESULTS=$(opensubtitles_search "$MOVIE_HASH" "$FILE_SIZE" "$LANGUAGES")

log_debug "SEARCH_RESULTS captured: $SEARCH_RESULTS"

# Count results
RESULT_COUNT=$(echo "$SEARCH_RESULTS" | jq 'length')

if [ "$RESULT_COUNT" -eq 0 ]; then
    log_warn "No subtitles found for this video"
    exit 0
fi

log_success "Found $RESULT_COUNT subtitle(s)"

# Display results and let user choose
echo ""
echo "Available subtitles:"
echo "$SEARCH_RESULTS" | jq -r 'to_entries[] | "\(.key + 1). [\(.value.attributes.language)] \(.value.attributes.files[0].file_name) - Downloads: \(.value.attributes.download_count)"'

echo ""
read -p "Enter subtitle numbers to download (space-separated, or 'all'): " SELECTION

# Parse selection
INDICES=()
if [ "$SELECTION" == "all" ]; then
    for i in $(seq 0 $((RESULT_COUNT - 1))); do
        INDICES+=("$i")
    done
else
    for num in $SELECTION; do
        # Convert 1-based to 0-based index
        INDICES+=($(( num - 1 )))
    done
fi

# Download selected subtitles
VIDEO_BASENAME=$(get_filename_without_ext "$VIDEO_FILE")

for idx in "${INDICES[@]}"; do
    # Get subtitle metadata
    SUBTITLE=$(echo "$SEARCH_RESULTS" | jq ".[$idx]")
    FILE_ID=$(echo "$SUBTITLE" | jq -r '.attributes.files[0].file_id')
    LANGUAGE=$(echo "$SUBTITLE" | jq -r '.attributes.language')
    ORIGINAL_FILENAME=$(echo "$SUBTITLE" | jq -r '.attributes.files[0].file_name')
    FILE_EXT="${ORIGINAL_FILENAME##*.}"

    # Construct output filename
    OUTPUT_FILENAME="${VIDEO_BASENAME}.${LANGUAGE}.${FILE_EXT}"
    OUTPUT_PATH="${OUTPUT_DIR}/${OUTPUT_FILENAME}"

    log_info "Downloading subtitle [$LANGUAGE]: $ORIGINAL_FILENAME"

    # Get download link
    DOWNLOAD_URL=$(opensubtitles_get_download_link "$FILE_ID")

    # Download file
    opensubtitles_download_file "$DOWNLOAD_URL" "$OUTPUT_PATH"

    log_success "Saved: $OUTPUT_PATH"
done

echo ""
log_success "Download complete! Downloaded ${#INDICES[@]} subtitle(s)"
