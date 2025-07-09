#!/bin/bash

# =============================================================================
# preroll-first-frame.sh
# This script takes the first frame of an input video, creates a still frame
# video from it, and prepends it to the original video.
# Usage: ./preroll-first-frame.sh <input-video-file> <output-video-file> <preroll-duration-seconds>
# =============================================================================

# Load environment variables from .env file
source .env

# --- Argument Handling ---
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <input-video-file> <output-video-file> <preroll-duration-seconds>"
    exit 1
fi

INPUT_VIDEO="$1"
OUTPUT_VIDEO="$2"
PREROLL_DURATION_SEC="$3"

# --- Validate Binaries ---
if ! command -v "$FFMPEG_BIN" &> /dev/null; then
    echo "Error: $FFMPEG_BIN command not found. Please install FFmpeg."
    exit 1
fi

if ! command -v "$FFPROBE_BIN" &> /dev/null; then
    echo "Error: $FFPROBE_BIN command not found. Please install FFmpeg (ffprobe is usually included)."
    exit 1
fi

# --- Validate Input Video ---
if [ ! -f "$INPUT_VIDEO" ]; then
    echo "Error: Input video file not found: '$INPUT_VIDEO'"
    exit 1
fi

echo "--- Creating Preroll with First Frame ---"

# --- Query Video and Audio Parameters ---
echo "Querying parameters from '$INPUT_VIDEO'..."

VIDEO_SIZE=$("$FFPROBE_BIN" -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$INPUT_VIDEO" 2>&1)
VIDEO_FPS=$("$FFPROBE_BIN" -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$INPUT_VIDEO" 2>&1)
VIDEO_PIX_FMT=$("$FFPROBE_BIN" -v error -select_streams v:0 -show_entries stream=pix_fmt -of csv=p=0 "$INPUT_VIDEO" 2>&1)
AUDIO_CH_LAYOUT=$("$FFPROBE_BIN" -v error -select_streams a:0 -show_entries stream=channel_layout -of csv=p=0 "$INPUT_VIDEO" 2>&1)
AUDIO_SAMPLE_RATE=$("$FFPROBE_BIN" -v error -select_streams a:0 -show_entries stream=sample_rate -of csv=p=0 "$INPUT_VIDEO" 2>&1)

if [ $? -ne 0 ] || [ -z "$VIDEO_SIZE" ] || [ -z "$VIDEO_FPS" ] || [ -z "$VIDEO_PIX_FMT" ]; then
    echo "Error querying video parameters using ffprobe."
    exit 1
fi

FFMPEG_SIZE=$(echo "$VIDEO_SIZE" | sed 's/,/x/')

# Temporary files
TEMP_FIRST_FRAME_PNG="temp_first_frame_${RANDOM}.png"
TEMP_PREROLL_VIDEO="temp_preroll_video_${RANDOM}.mp4"
CONCAT_LIST_FILE="temp_concat_list_${RANDOM}.txt"

# --- Extract First Frame ---
echo "Extracting first frame to '$TEMP_FIRST_FRAME_PNG'..."
"$FFMPEG_BIN" -y -ss 0 -i "$INPUT_VIDEO" -frames:v 1 "$TEMP_FIRST_FRAME_PNG"

if [ $? -ne 0 ]; then
    echo "Error: Failed to extract first frame. FFmpeg command exited with an error."
    rm -f "$TEMP_FIRST_FRAME_PNG"
    exit 1
fi

# --- Create Preroll Video from First Frame ---
echo "Creating preroll video ('$TEMP_PREROLL_VIDEO') from first frame for ${PREROLL_DURATION_SEC} seconds..."

PREROLL_AUDIO_OPTIONS=""
if [ -n "$AUDIO_CH_LAYOUT" ]; then
    PREROLL_AUDIO_OPTIONS="-f lavfi -i anullsrc=channel_layout=$AUDIO_CH_LAYOUT:sample_rate=$AUDIO_SAMPLE_RATE -c:a aac -b:a ${YOUTUBE_AUDIO_BITRATE} -ar ${AUDIO_SAMPLE_RATE}"
fi

"$FFMPEG_BIN" -y \
              -loop 1 -i "$TEMP_FIRST_FRAME_PNG" \
              ${PREROLL_AUDIO_OPTIONS} \
              -c:v libx264 -b:v ${YOUTUBE_VIDEO_BITRATE} \
              -t "$PREROLL_DURATION_SEC" \
              -pix_fmt "$VIDEO_PIX_FMT" \
              -r $VIDEO_FPS \
              -shortest \
              "$TEMP_PREROLL_VIDEO"

if [ $? -ne 0 ]; then
    echo "Error: Failed to create preroll video. FFmpeg command exited with an error."
    rm -f "$TEMP_FIRST_FRAME_PNG" "$TEMP_PREROLL_VIDEO"
    exit 1
fi

# --- Create Concatenation List ---
echo "Creating concatenation list file ('$CONCAT_LIST_FILE')..."
echo "file '$TEMP_PREROLL_VIDEO'" > "$CONCAT_LIST_FILE"
echo "file '$INPUT_VIDEO'" >> "$CONCAT_LIST_FILE"

if [ $? -ne 0 ]; then
    echo "Error creating concatenation list file."
    rm -f "$TEMP_FIRST_FRAME_PNG" "$TEMP_PREROLL_VIDEO" "$CONCAT_LIST_FILE"
    exit 1
fi

# --- Concatenate Videos ---
echo "Concatenating preroll and original video into '$OUTPUT_VIDEO'..."

FINAL_AUDIO_OPTIONS=""
if [ -n "$AUDIO_CH_LAYOUT" ]; then
    FINAL_AUDIO_OPTIONS="-c:a aac -b:a ${YOUTUBE_AUDIO_BITRATE} -ar ${AUDIO_SAMPLE_RATE}"
fi

"$FFMPEG_BIN" -y \
              -f concat \
              -safe 0 \
              -i "$CONCAT_LIST_FILE" \
              -c:v libx264 -preset medium -crf 23 \
              ${FINAL_AUDIO_OPTIONS} \
              "$OUTPUT_VIDEO"

if [ $? -ne 0 ]; then
    echo "Error: Video concatenation failed. FFmpeg command exited with an error."
    rm -f "$TEMP_FIRST_FRAME_PNG" "$TEMP_PREROLL_VIDEO" "$CONCAT_LIST_FILE"
    exit 1
fi

# --- Clean Up Temporary Files ---
echo "Cleaning up temporary files..."
rm -f "$TEMP_FIRST_FRAME_PNG" "$TEMP_PREROLL_VIDEO" "$CONCAT_LIST_FILE"

echo "✅ Preroll added successfully. Output saved to '$OUTPUT_VIDEO'"