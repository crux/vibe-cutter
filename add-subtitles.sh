#!/bin/bash

# This script adds subtitle tracks from external files to a video file.
# The output file's video and audio tracks are copied, not re-encoded.
#
# Usage: ./add-subtitles.sh <input-video> <output-video> <subtitle-file> [<language>] [<title>] [<subtitle-file-2> [<language-2>] [<title-2>]] ...
#
# Examples:
#   # Add single subtitle file
#   ./add-subtitles.sh input.mkv output.mkv subtitles.srt eng "English"
#
#   # Add multiple subtitle files
#   ./add-subtitles.sh input.mkv output.mkv subs-en.srt eng "English" subs-es.srt spa "Spanish"
#
#   # Add subtitle without language/title metadata
#   ./add-subtitles.sh input.mkv output.mkv subtitles.srt
#
# Note: Each subtitle entry needs 1-3 arguments: subtitle-file [language] [title]
#       If you provide a language, you can optionally provide a title.

set -euo pipefail

# --- Configuration ---
# Load environment variables from .env file if it exists
if [ -f ".env" ]; then
    source ".env"
fi

FFMPEG_BIN="${FFMPEG_BIN:-ffmpeg}"

# --- Input Validation ---
if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <input-video> <output-video> <subtitle-file> [<language>] [<title>] [<subtitle-file-2> [<language-2>] [<title-2>]] ..."
    echo ""
    echo "Examples:"
    echo "  $0 input.mkv output.mkv subtitles.srt eng \"English\""
    echo "  $0 input.mkv output.mkv subs-en.srt eng \"English\" subs-es.srt spa \"Spanish\""
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_FILE="$2"
shift 2

if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file not found: $INPUT_FILE"
    exit 1
fi

# --- Parse Subtitle Arguments ---
SUBTITLE_FILES=()
SUBTITLE_LANGUAGES=()
SUBTITLE_TITLES=()

while [ "$#" -gt 0 ]; do
    subtitle_file="$1"
    shift

    if [ ! -f "$subtitle_file" ]; then
        echo "Error: Subtitle file not found: $subtitle_file"
        exit 1
    fi

    SUBTITLE_FILES+=("$subtitle_file")

    # Check if next argument is a language code (not a file)
    if [ "$#" -gt 0 ] && [ ! -f "$1" ]; then
        language="$1"
        shift
        SUBTITLE_LANGUAGES+=("$language")

        # Check if next argument is a title (not a file)
        if [ "$#" -gt 0 ] && [ ! -f "$1" ]; then
            title="$1"
            shift
            SUBTITLE_TITLES+=("$title")
        else
            SUBTITLE_TITLES+=("")
        fi
    else
        SUBTITLE_LANGUAGES+=("")
        SUBTITLE_TITLES+=("")
    fi
done

if [ ${#SUBTITLE_FILES[@]} -eq 0 ]; then
    echo "Error: No subtitle files provided"
    exit 1
fi

# --- FFmpeg Command Construction ---
INPUT_OPTIONS=("-i" "$INPUT_FILE")
MAP_OPTIONS=("-map" "0:v" "-map" "0:a" "-map" "0:s?")
METADATA_OPTIONS=()

# Add subtitle files as inputs and create mappings
for i in "${!SUBTITLE_FILES[@]}"; do
    subtitle_file="${SUBTITLE_FILES[$i]}"
    language="${SUBTITLE_LANGUAGES[$i]}"
    title="${SUBTITLE_TITLES[$i]}"

    input_index=$((i + 1))

    INPUT_OPTIONS+=("-i" "$subtitle_file")
    MAP_OPTIONS+=("-map" "$input_index:s")

    # Add metadata if provided
    if [ -n "$language" ]; then
        METADATA_OPTIONS+=("-metadata:s:s:$i" "language=$language")
    fi

    if [ -n "$title" ]; then
        METADATA_OPTIONS+=("-metadata:s:s:$i" "title=$title")
    fi
done

# --- Execution ---
echo "Processing '$INPUT_FILE'"
echo "Adding ${#SUBTITLE_FILES[@]} subtitle track(s):"
for i in "${!SUBTITLE_FILES[@]}"; do
    echo "  - ${SUBTITLE_FILES[$i]}"
    if [ -n "${SUBTITLE_LANGUAGES[$i]}" ]; then
        echo "    Language: ${SUBTITLE_LANGUAGES[$i]}"
    fi
    if [ -n "${SUBTITLE_TITLES[$i]}" ]; then
        echo "    Title: ${SUBTITLE_TITLES[$i]}"
    fi
done

"$FFMPEG_BIN" \
    "${INPUT_OPTIONS[@]}" \
    -c:v copy \
    -c:a copy \
    -c:s copy \
    "${MAP_OPTIONS[@]}" \
    "${METADATA_OPTIONS[@]}" \
    -y "$OUTPUT_FILE"

echo "Output written to '$OUTPUT_FILE'"
