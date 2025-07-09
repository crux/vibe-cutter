#!/bin/bash

# =============================================================================
# concat-videos.sh
# This script concatenates a variable number of video files into a single
# output video using FFmpeg's concat demuxer.
# Usage: ./concat-videos.sh <input-video-1> [input-video-2 ...] <output-video>
# The last argument is always treated as the output video file.
# =============================================================================

# Load environment variables from .env file
source .env

# --- Argument Handling ---
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <input-video-1> [input-video-2 ...] <output-video>"
    echo "At least one input video and one output video must be provided."
    exit 1
fi

# The last argument is the output video
OUTPUT_VIDEO="${!#}" # Bash indirect expansion to get the last argument

# All arguments except the last one are input videos
INPUT_VIDEOS=("${@:1:$#-1}")

# --- Query Video and Audio Parameters from the first input video ---
echo "Querying parameters from '${INPUT_VIDEOS[0]}' for re-encoding..."

VIDEO_SIZE=$("$FFPROBE_BIN" -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "${INPUT_VIDEOS[0]}" 2>&1)
VIDEO_FPS=$("$FFPROBE_BIN" -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "${INPUT_VIDEOS[0]}" 2>&1)
VIDEO_PIX_FMT=$("$FFPROBE_BIN" -v error -select_streams v:0 -show_entries stream=pix_fmt -of csv=p=0 "${INPUT_VIDEOS[0]}" 2>&1)
AUDIO_CH_LAYOUT=$("$FFPROBE_BIN" -v error -select_streams a:0 -show_entries stream=channel=layout -of csv=p=0 "${INPUT_VIDEOS[0]}" 2>&1)
AUDIO_SAMPLE_RATE=$("$FFPROBE_BIN" -v error -select_streams a:0 -show_entries stream=sample_rate -of csv=p=0 "${INPUT_VIDEOS[0]}" 2>&1)

if [ $? -ne 0 ] || [ -z "$VIDEO_SIZE" ] || [ -z "$VIDEO_FPS" ] || [ -z "$VIDEO_PIX_FMT" ]; then
    echo "Error querying video parameters from '${INPUT_VIDEOS[0]}' using ffprobe. Aborting."
    exit 1
fi

# --- Validate Binaries ---
if ! command -v "$FFMPEG_BIN" &> /dev/null; then
    echo "Error: $FFMPEG_BIN command not found. Please install FFmpeg."
    exit 1
fi

# Temporary directory
TMP_DIR="./tmp"
mkdir -p "$TMP_DIR"

# Temporary file for concatenation list
CONCAT_LIST_FILE="${TMP_DIR}/temp_concat_list_${RANDOM}.txt"

# --- Create Concatenation List File ---
echo "Creating concatenation list file ('$CONCAT_LIST_FILE')..."
> "$CONCAT_LIST_FILE" # Clear the file if it exists

for video in "${INPUT_VIDEOS[@]}"; do
    if [ ! -f "$video" ]; then
        echo "Error: Input video file not found: '$video'"
        rm -f "$CONCAT_LIST_FILE"
        exit 1
    fi
    echo "file '$video'" >> "$CONCAT_LIST_FILE"
done

if [ $? -ne 0 ]; then
    echo "Error creating concatenation list file."
    rm -f "$CONCAT_LIST_FILE"
    exit 1
fi

echo "Concatenation list file created with ${#INPUT_VIDEOS[@]} videos."

# --- Concatenate Videos ---
echo "Concatenating videos into '$OUTPUT_VIDEO' (re-encoding to ensure compatibility)..."

VIDEO_ENCODING_OPTIONS="-c:v libx264 -preset medium -crf 23 -b:v ${YOUTUBE_VIDEO_BITRATE} -pix_fmt ${VIDEO_PIX_FMT} -r ${VIDEO_FPS}"
AUDIO_ENCODING_OPTIONS=""
if [ -n "$AUDIO_CH_LAYOUT" ]; then
    AUDIO_ENCODING_OPTIONS="-c:a aac -b:a ${YOUTUBE_AUDIO_BITRATE} -ar ${AUDIO_SAMPLE_RATE}"
fi

"$FFMPEG_BIN" -y \
              -f concat \
              -safe 0 \
              -i "$CONCAT_LIST_FILE" \
              ${VIDEO_ENCODING_OPTIONS} \
              ${AUDIO_ENCODING_OPTIONS} \
              "$OUTPUT_VIDEO"

if [ $? -ne 0 ]; then
    echo "Error: Video concatenation failed (exit code $?)."
    echo "Re-encoding failed. Check FFmpeg output for details."
    rm -f "$CONCAT_LIST_FILE"
    exit 1
fi

echo "Videos concatenated successfully: '$OUTPUT_VIDEO'"

# --- Clean Up Temporary Files ---
echo "Cleaning up temporary files..."
rm -f "$CONCAT_LIST_FILE"
echo "Temporary files removed."
