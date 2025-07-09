#!/bin/bash

# =============================================================================
# freeze-frame.sh
# This script takes the last non-black frame of an input video, creates a
# still frame video from it, and appends it to the original video (trimmed
# to remove any trailing black frames).
# Usage: ./freeze-frame.sh <input-video-file> <output-video-file> <freeze-frame-duration-seconds>
# =============================================================================

# Load environment variables from .env file
source .env

# --- Argument Handling ---
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <input-video-file> <output-video-file> <freeze-frame-duration-seconds>"
    exit 1
fi

INPUT_VIDEO="$1"
OUTPUT_VIDEO="$2"
FREEZE_FRAME_DURATION_SEC="$3"

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

echo "--- Creating Freeze Frame at End of Video (Last Non-Black Frame) ---"

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
TEMP_TRIMMED_INPUT_VIDEO="temp_trimmed_input_${RANDOM}.mp4"
TEMP_LAST_CONTENT_FRAME_PNG="temp_last_content_frame_${RANDOM}.png"
TEMP_FREEZE_FRAME_VIDEO="temp_freeze_frame_video_${RANDOM}.mp4"
CONCAT_LIST_FILE="temp_concat_list_${RANDOM}.txt"

# --- Detect Trailing Black and Trim Video ---
echo "Detecting trailing black frames and trimming video..."

DURATION=$("$FFPROBE_BIN" -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$INPUT_VIDEO")

BLACK_DETECT_OUTPUT=$("$FFMPEG_BIN" -i "$INPUT_VIDEO" -vf "blackdetect=d=0.1:pix_th=0.20" -an -f null - 2>&1 | grep 'black_start')

LAST_CONTENT_END_TIME="$DURATION"
if [ -n "$BLACK_DETECT_OUTPUT" ]; then
    # Get the start time of the last detected black segment
    LAST_BLACK_START=$(echo "$BLACK_DETECT_OUTPUT" | tail -n1 | sed -n 's/.*black_start:\([0-9.]*\).*/\1/p')
    if [ -n "$LAST_BLACK_START" ]; then
        LAST_CONTENT_END_TIME="$LAST_BLACK_START"
    fi
fi

echo "Original video content ends at: ${LAST_CONTENT_END_TIME}s"

# Trim the input video to the last non-black frame
"$FFMPEG_BIN" -y \
              -i "$INPUT_VIDEO" \
              -t "$LAST_CONTENT_END_TIME" \
              -c:v libx264 -preset medium -crf 23 \
              -c:a aac -b:a ${YOUTUBE_AUDIO_BITRATE} -ar ${AUDIO_SAMPLE_RATE} \
              "$TEMP_TRIMMED_INPUT_VIDEO"

if [ $? -ne 0 ]; then
    echo "Error: Failed to trim input video. FFmpeg command exited with an error."
    rm -f "$TEMP_TRIMMED_INPUT_VIDEO"
    exit 1
fi

# --- Extract Last Content Frame ---
echo "Extracting last content frame to '$TEMP_LAST_CONTENT_FRAME_PNG'..."
# Seek to 0.1 seconds before the detected LAST_CONTENT_END_TIME from the original video
SEEK_TIME=$(echo "$LAST_CONTENT_END_TIME - 0.1" | bc)
if (( $(echo "$SEEK_TIME < 0" | bc -l) )); then
    SEEK_TIME=0
fi

"$FFMPEG_BIN" -y -ss "$SEEK_TIME" -i "$INPUT_VIDEO" -frames:v 1 "$TEMP_LAST_CONTENT_FRAME_PNG"

if [ $? -ne 0 ]; then
    echo "Error: Failed to extract last content frame. FFmpeg command exited with an error."
    rm -f "$TEMP_TRIMMED_INPUT_VIDEO" "$TEMP_LAST_CONTENT_FRAME_PNG"
    exit 1
fi

# --- Create Freeze Frame Video from Last Content Frame ---
echo "Creating freeze frame video ('$TEMP_FREEZE_FRAME_VIDEO') from last content frame for ${FREEZE_FRAME_DURATION_SEC} seconds..."

FREEZE_FRAME_AUDIO_OPTIONS=""
if [ -n "$AUDIO_CH_LAYOUT" ]; then
    FREEZE_FRAME_AUDIO_OPTIONS="-f lavfi -i anullsrc=channel_layout=$AUDIO_CH_LAYOUT:sample_rate=$AUDIO_SAMPLE_RATE -c:a aac -b:a ${YOUTUBE_AUDIO_BITRATE} -ar ${AUDIO_SAMPLE_RATE}"
fi

"$FFMPEG_BIN" -y \
              -loop 1 -i "$TEMP_LAST_CONTENT_FRAME_PNG" \
              ${FREEZE_FRAME_AUDIO_OPTIONS} \
              -c:v libx264 -b:v ${YOUTUBE_VIDEO_BITRATE} \
              -t "$FREEZE_FRAME_DURATION_SEC" \
              -pix_fmt "$VIDEO_PIX_FMT" \
              -r $VIDEO_FPS \
              -shortest \
              "$TEMP_FREEZE_FRAME_VIDEO"

if [ $? -ne 0 ]; then
    echo "Error: Failed to create freeze frame video. FFmpeg command exited with an error."
    rm -f "$TEMP_TRIMMED_INPUT_VIDEO" "$TEMP_LAST_CONTENT_FRAME_PNG" "$TEMP_FREEZE_FRAME_VIDEO"
    exit 1
fi

# --- Create Concatenation List ---
echo "Creating concatenation list file ('$CONCAT_LIST_FILE')..."
echo "file '$TEMP_TRIMMED_INPUT_VIDEO'" > "$CONCAT_LIST_FILE"
echo "file '$TEMP_FREEZE_FRAME_VIDEO'" >> "$CONCAT_LIST_FILE"

if [ $? -ne 0 ]; then
    echo "Error creating concatenation list file."
    rm -f "$TEMP_TRIMMED_INPUT_VIDEO" "$TEMP_LAST_CONTENT_FRAME_PNG" "$TEMP_FREEZE_FRAME_VIDEO" "$CONCAT_LIST_FILE"
    exit 1
fi

# --- Concatenate Videos ---
echo "Concatenating trimmed original video and freeze frame into '$OUTPUT_VIDEO'..."

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
    rm -f "$TEMP_TRIMMED_INPUT_VIDEO" "$TEMP_LAST_CONTENT_FRAME_PNG" "$TEMP_FREEZE_FRAME_VIDEO" "$CONCAT_LIST_FILE"
    exit 1
fi

# --- Clean Up Temporary Files ---
echo "Cleaning up temporary files..."
rm -f "$TEMP_TRIMMED_INPUT_VIDEO" "$TEMP_LAST_CONTENT_FRAME_PNG" "$TEMP_FREEZE_FRAME_VIDEO" "$CONCAT_LIST_FILE"

echo "✅ Freeze frame added successfully. Output saved to '$OUTPUT_VIDEO'"