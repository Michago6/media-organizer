#!/bin/bash
#
# Organize by Modified Time and Update Metadata
# ==============================================
# Purpose: Organize media files by last modified date and sync EXIF metadata
#
# This script:
#   - Scans a directory recursively for media files
#   - Extracts the last modified time (mtime) for each file
#   - Creates YYYY/MM folder structure based on modified date
#   - MOVES files from their current location to organized YYYY/MM folders
#   - Updates EXIF metadata (CreateDate and FileModifyDate) to match file's mtime
#   - Overwrites existing EXIF dates with the file's last modified date
#   - Original directory structure is emptied as files are moved
#
# Supported media types:
#   Images: jpg, jpeg, png, gif, bmp, webp, svg, tiff, heic, heif
#   Videos: mp4, avi, mov, mkv, flv, wmv, webm, m4v, mpg, mpeg, 3gp, m2ts
#
# Dependencies: exiftool
#
# Usage:
#   ./organize-by-mtime.sh
#   - Prompts for source directory (containing media files to organize)
#   - Creates YYYY/MM folder structure in the same directory
#   - Moves files into YYYY/MM folders based on last modified date
#   - Updates EXIF metadata for each file to match its modified date
#   - Generates summary report of processed files
#
# ⚠️  ATTENTION: IRREVERSIBLE CHANGES WILL BE MADE
#   - Files WILL BE MOVED from their current locations to YYYY/MM folders
#   - EXIF metadata WILL BE OVERWRITTEN with file's last modified date
#   - Original file locations will be emptied
#   - Ensure you have backups if needed before running
#
# TLDR - Before you run:
#   1. Source directory: where your unsorted media files currently live
#   2. Files WILL BE MOVED to YYYY/MM folders based on last modified date
#   3. EXIF metadata (CreateDate, FileModifyDate) will be overwritten
#   4. Original directory structure will be emptied
#   5. Requires exiftool to be installed

set -uo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if exiftool is installed
if ! command -v exiftool &> /dev/null; then
    log_error "exiftool is not installed. Please install it with: sudo apt-get install libimage-exiftool-perl"
    exit 1
fi

log_success "exiftool found"

# Ask for source directory
read -p "Enter the source directory for media files to organize: " SOURCE_DIR

if [ ! -d "$SOURCE_DIR" ]; then
    log_error "Source directory does not exist: $SOURCE_DIR"
    exit 1
fi

log_success "Source directory: $SOURCE_DIR"

# Image and video extensions (case-insensitive)
IMAGE_EXTENSIONS="jpg|jpeg|png|gif|bmp|webp|svg|tiff|heic|heif"
VIDEO_EXTENSIONS="mp4|avi|mov|mkv|flv|wmv|webm|m4v|mpg|mpeg|3gp|m2ts"

# Function to check if file is an image or video
is_media_file() {
    local file="$1"
    local extension="${file##*.}"
    extension="${extension,,}"  # Convert to lowercase

    if [[ $extension =~ ^($IMAGE_EXTENSIONS|$VIDEO_EXTENSIONS)$ ]]; then
        return 0
    fi
    return 1
}

# Function to get file modified time in YYYY/MM format
get_mtime_date() {
    local file="$1"
    local mtime=$(stat -c %Y "$file")
    date -d "@$mtime" +%Y/%m
}

# Function to get file modified time in YYYY:MM:DD HH:MM:SS format for EXIF
get_mtime_exif_format() {
    local file="$1"
    local mtime=$(stat -c %Y "$file")
    date -d "@$mtime" +"%Y:%m:%d %H:%M:%S"
}

# Function to get file modified time for touch command (YYYYMMDDhhmm format)
get_mtime_touch_format() {
    local file="$1"
    local mtime=$(stat -c %Y "$file")
    date -d "@$mtime" +"%Y%m%d%H%M"
}

# Counter for statistics
total_files=0
processed_files=0
skipped_files=0

log_info "Starting to process files..."

# Process all files recursively, excluding hidden files
while IFS= read -r -d '' file; do
    ((total_files++))

    # Skip hidden files
    if [[ $(basename "$file") == .* ]]; then
        ((skipped_files++))
        continue
    fi

    # Check if it's a media file
    if ! is_media_file "$file"; then
        ((skipped_files++))
        continue
    fi

    filename=$(basename "$file")

    # Get modified date and create target directory
    date_path=$(get_mtime_date "$file")
    target_dir="$SOURCE_DIR/$date_path"
    mkdir -p "$target_dir"

    # Get modified time in EXIF format
    mtime_exif=$(get_mtime_exif_format "$file")
    mtime_touch=$(get_mtime_touch_format "$file")

    # Move file to target directory
    mv "$file" "$target_dir/$filename"

    # Update EXIF metadata (overwrite existing dates)
    exiftool -overwrite_original -CreateDate="$mtime_exif" -FileModifyDate="$mtime_exif" -MediaCreateDate="$mtime_exif" -MediaModifyDate="$mtime_exif" "$target_dir/$filename" > /dev/null 2>&1

    # Update file modification time to match
    touch -t "$mtime_touch" "$target_dir/$filename"

    log_info "Moved and updated: $filename → $date_path/ [metadata: $mtime_exif]"
    ((processed_files++))

done < <(find "$SOURCE_DIR" -type f -print0)

log_success "Processing complete!"
echo ""
echo "========== SUMMARY =========="
echo "Total files found: $total_files"
echo "Files processed: $processed_files"
echo "Files skipped: $skipped_files"
echo "Source directory: $SOURCE_DIR"
echo "==========================="
