#!/bin/bash

# =============================================================================
# render-credits.sh
# This script generates a standalone credits video based on an input video's
# properties (resolution, frame rate) and predefined text/style settings.
# Usage: ./render-credits.sh <original-input-video> <credits-output-file>
# =============================================================================

# Load environment variables from .env file
source .env

# --- Argument Handling ---
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <original-input-video> <credits-output-file>"
    exit 1
fi

INPUT_VIDEO="$1"
OUTPUT_VIDEO="$2"

# Temporary directory
TMP_DIR="./tmp"
mkdir -p "$TMP_DIR"

# --- Validate Inputs ---
if [ ! -f "$INPUT_VIDEO" ]; then
    echo "Error: Input video file for parameter matching not found: '$INPUT_VIDEO'"
    exit 1
fi

if [ ! -f "$FONT_ROBOTO_MONO" ]; then
    echo "Error: Font file not found: '$FONT_ROBOTO_MONO'"
    echo "Please update the FONT_ROBOTO_MONO variable in .env."
    exit 1
fi

if ! command -v "$FFMPEG_BIN" &> /dev/null; then
    echo "Error: $FFMPEG_BIN command not found. Please install FFmpeg."
    exit 1
fi

if ! command -v "$FFPROBE_BIN" &> /dev/null; then
    echo "Error: $FFPROBE_BIN command not found. Please install FFmpeg (ffprobe is usually included)."
    exit 1
fi

# Function to escape text for FFmpeg drawtext filter
escape_ffmpeg_drawtext_text() {
    local text="$1"
    # Escape backslashes first
    text="${text//\\/\\\\}"
    # Escape single quotes
    text="${text//'/\'}"
    # Escape colons
    text="${text//:/\:}"
    # Escape percent signs
    text="${text//%/%%}"
    echo "$text"
}

# --- Query Main Video Parameters for compatibility ---
VIDEO_SIZE=$("$FFPROBE_BIN" -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$INPUT_VIDEO" 2>&1)
VIDEO_FPS=$("$FFPROBE_BIN" -v error -select_streams v:0 -show_entries stream=r_frame_rate -of csv=p=0 "$INPUT_VIDEO" 2>&1)
VIDEO_PIX_FMT=$("$FFPROBE_BIN" -v error -select_streams v:0 -show_entries stream=pix_fmt -of csv=p=0 "$INPUT_VIDEO" 2>&1)
AUDIO_CODEC=$("$FFPROBE_BIN" -v error -select_streams a:0 -show_entries stream=codec_name -of csv=p=0 "$INPUT_VIDEO" 2>&1)
AUDIO_SAMPLE_RATE=$("$FFPROBE_BIN" -v error -select_streams a:0 -show_entries stream=sample_rate -of csv=p=0 "$INPUT_VIDEO" 2>&1)
AUDIO_CH_LAYOUT=$("$FFPROBE_BIN" -v error -select_streams a:0 -show_entries stream=channel_layout -of csv=p=0 "$INPUT_VIDEO" 2>&1)

if [ $? -ne 0 ] || [ -z "$VIDEO_SIZE" ] || [ -z "$VIDEO_FPS" ] || [ -z "$VIDEO_PIX_FMT" ]; then
    echo "Error querying video parameters using ffprobe."
    exit 1
fi

FFMPEG_SIZE=$(echo "$VIDEO_SIZE" | sed 's/,/x/')

# --- Create the Credits Video ---
echo "Creating credits video ('$OUTPUT_VIDEO')..."

# Escape the text for FFmpeg drawtext filter
ESCAPED_CREDITS_LINE1=$(escape_ffmpeg_drawtext_text "$CREDITS_LINE1")
ESCAPED_CREDITS_LINE2=$(escape_ffmpeg_drawtext_text "$CREDITS_LINE2")
ESCAPED_CREDITS_LINE3=$(escape_ffmpeg_drawtext_text "$CREDITS_LINE3")
ESCAPED_CREDITS_LINE4=$(escape_ffmpeg_drawtext_text "$CREDITS_LINE4")

# Calculate y positions for each line
VIDEO_HEIGHT=$(echo "$FFMPEG_SIZE" | cut -d'x' -f2)
Y1=$(echo "($VIDEO_HEIGHT / 2) - (1.5 * $LINE_SPACING) - ($CREDITS_FONT_SIZE_LINE1 / 2)" | bc)
Y2=$(echo "($VIDEO_HEIGHT / 2) - (0.5 * $LINE_SPACING) - ($CREDITS_FONT_SIZE_LINE2 / 2)" | bc)
Y3=$(echo "($VIDEO_HEIGHT / 2) + (0.5 * $LINE_SPACING) - ($CREDITS_FONT_SIZE_LINE3 / 2)" | bc)
Y4=$(echo "($VIDEO_HEIGHT / 2) + (1.8 * $LINE_SPACING) - ($CREDITS_FONT_SIZE_LINE4 / 2)" | bc)

# Construct the drawtext filter string for four lines.
DRAWTEXT_FILTER="drawtext=text='$ESCAPED_CREDITS_LINE1':fontcolor=$CREDITS_FONT_COLOR_LINE1:fontsize=$CREDITS_FONT_SIZE_LINE1:x=(w-tw)/2:y=$Y1:fontfile='$FONT_ROBOTO_MONO', drawtext=text='$ESCAPED_CREDITS_LINE2':fontcolor=$CREDITS_FONT_COLOR_LINE2:fontsize=$CREDITS_FONT_SIZE_LINE2:x=(w-tw)/2:y=$Y2:fontfile='$FONT_ROBOTO_MONO', drawtext=text='$ESCAPED_CREDITS_LINE3':fontcolor=$CREDITS_FONT_COLOR_LINE3:fontsize=$CREDITS_FONT_SIZE_LINE3:x=(w-tw)/2:y=$Y3:fontfile='$FONT_ROBOTO_MONO', drawtext=text='$ESCAPED_CREDITS_LINE4':fontcolor=$CREDITS_FONT_COLOR_LINE4:fontsize=$CREDITS_FONT_SIZE_LINE4:x=(w-tw)/2:y=$Y4:fontfile='$FONT_ROBOTO_MONO'"

# Prepare silent audio input to match the source video
AUDIO_INPUT=""
AUDIO_OUTPUT_CODEC=""
if [ -n "$AUDIO_CODEC" ]; then
    AUDIO_INPUT="-f lavfi -i anullsrc=channel_layout=$AUDIO_CH_LAYOUT:sample_rate=$AUDIO_SAMPLE_RATE"
    AUDIO_OUTPUT_CODEC="-c:a $AUDIO_CODEC"
fi

"$FFMPEG_BIN" -y \
              -f lavfi -i "color=size=$FFMPEG_SIZE:c=$BACKGROUND_COLOR:duration=$CREDITS_DURATION_SEC:rate=$VIDEO_FPS" \
              $AUDIO_INPUT \
              -vf "$DRAWTEXT_FILTER" \
              -c:v libx264 -b:v $YOUTUBE_VIDEO_BITRATE \
              $AUDIO_OUTPUT_CODEC -b:a $YOUTUBE_AUDIO_BITRATE -ar $AUDIO_SAMPLE_RATE \
              -pix_fmt "$VIDEO_PIX_FMT" \
              -r $VIDEO_FPS \
              -t "$CREDITS_DURATION_SEC" \
              -shortest \
              "$OUTPUT_VIDEO"

if [ $? -ne 0 ]; then
    echo "Error creating credits video. FFmpeg command failed."
    exit 1
fi

echo "Credits video created successfully: '$OUTPUT_VIDEO'"