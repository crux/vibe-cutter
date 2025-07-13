#!/bin/bash

# =============================================================================
# transcode-for.sh
# This script transcodes a video file using FFmpeg with parameters loaded from
# a specified .env file.
# Usage: ./transcode-for.sh <config-env-file> <input-video> <output-video>
# Example: ./transcode-for.sh jellyfin.env input.mkv output.mkv
# =============================================================================

# Load environment variables from .env file (for FFMPEG_BIN, FFPROBE_BIN, YOUTUBE_AUDIO_BITRATE)
source .env

# --- Argument Handling ---
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <config-env-file> <input-video> <output-video>"
    echo "Example: $0 jellyfin.env input.mkv output.mkv"
    exit 1
fi

CONFIG_ENV_FILE="$1"
INPUT_VIDEO="$2"
OUTPUT_VIDEO="$3"

# Load transcoding parameters from the specified config .env file
if [ ! -f "$CONFIG_ENV_FILE" ]; then
    echo "Error: Config environment file not found: '$CONFIG_ENV_FILE'"
    exit 1
fi
source "$CONFIG_ENV_FILE"

# --- Validate Binaries ---
if ! command -v "$FFMPEG_BIN" &> /dev/null; then
    echo "Error: $FFMPEG_BIN command not found. Please install FFmpeg."
    exit 1
fi

# --- Validate Input Video ---
if [ ! -f "$INPUT_VIDEO" ]; then
    echo "Error: Input video file not found: '$INPUT_VIDEO'"
    exit 1
fi

echo "--- Transcoding using parameters from $CONFIG_ENV_FILE ---"

VIDEO_FILTER_OPTIONS=""
if [ -n "$TARGET_RESOLUTION" ]; then
    # Extract width and height from TARGET_RESOLUTION
    TARGET_WIDTH=$(echo "$TARGET_RESOLUTION" | cut -d'x' -f1)
    TARGET_HEIGHT=$(echo "$TARGET_RESOLUTION" | cut -d'x' -f2)
    VIDEO_FILTER_OPTIONS="-vf scale='min(iw,${TARGET_WIDTH})':'min(ih,${TARGET_HEIGHT})':force_original_aspect_ratio=decrease,scale=trunc(iw/2)*2:trunc(ih/2)*2"
fi

# Construct audio options
AUDIO_OPTIONS=""
if [ "$AUDIO_CODEC" == "copy" ]; then
    AUDIO_OPTIONS="-c:a copy"
elif [ "$AUDIO_CODEC" == "aac" ]; then
    # Probe audio sample rate from input video if re-encoding to aac
    AUDIO_SAMPLE_RATE=$("$FFPROBE_BIN" -v error -select_streams a:0 -show_entries stream=sample_rate -of default=noprint_wrappers=1:nokey=1 "$INPUT_VIDEO" 2>&1)
    if [ -z "$AUDIO_SAMPLE_RATE" ]; then
        echo "Warning: Could not determine audio sample rate for AAC encoding. Using default 44100."
        AUDIO_SAMPLE_RATE=44100
    fi
    AUDIO_OPTIONS="-c:a aac -b:a ${YOUTUBE_AUDIO_BITRATE} -ar ${AUDIO_SAMPLE_RATE}"
else
    echo "Error: Unsupported audio codec specified in $CONFIG_ENV_FILE: $AUDIO_CODEC. Use 'copy' or 'aac'."
    exit 1
fi

# FFmpeg command
"$FFMPEG_BIN" -y \
              -i "$INPUT_VIDEO" \
              -c:v libx264 -b:v "$VIDEO_BITRATE" -maxrate "$MAXRATE" -bufsize "$BUFSIZE" -preset "$PRESET" -crf "$CRF" \
              ${VIDEO_FILTER_OPTIONS} \
              ${AUDIO_OPTIONS} \
              "$OUTPUT_VIDEO"

if [ $? -ne 0 ]; then
    echo "Error: FFmpeg transcoding failed. Exit code $?."
    exit 1
fi

echo "✅ Transcoding complete. Output saved to '$OUTPUT_VIDEO'"