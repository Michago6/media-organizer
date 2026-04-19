#!/bin/bash

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
read -p "Enter the source directory for images and videos: " SOURCE_DIR

if [ ! -d "$SOURCE_DIR" ]; then
    log_error "Source directory does not exist: $SOURCE_DIR"
    exit 1
fi

log_success "Source directory: $SOURCE_DIR"

# Ask for output directory
read -p "Enter the output directory (YYYY/MM folders will be created directly here): " OUTPUT_DIR

if [ ! -d "$OUTPUT_DIR" ]; then
    log_error "Output directory does not exist: $OUTPUT_DIR"
    exit 1
fi

log_success "Output directory: $OUTPUT_DIR"

# Use output directory directly for organized files
ORGANIZED_DIR="$OUTPUT_DIR"
log_info "Files will be organized directly in: $ORGANIZED_DIR"

# Create tracking directories
UNDATED_DIR="$ORGANIZED_DIR/UNDATED"
DUPLICATES_DIR="$ORGANIZED_DIR/DUPLICATES"
mkdir -p "$UNDATED_DIR" "$DUPLICATES_DIR"

# Temporary files for tracking processed checksums and their locations
CHECKSUMS_FILE=$(mktemp)
trap "rm -f $CHECKSUMS_FILE" EXIT

# Image and video extensions (case-insensitive)
IMAGE_EXTENSIONS="jpg|jpeg|png|gif|bmp|webp|svg|tiff|heic|heif"
VIDEO_EXTENSIONS="mp4|avi|mov|mkv|flv|wmv|webm|m4v|mpg|mpeg|3gp|m2ts"

# Function to extract year and month from date string
extract_date() {
    local date_string="$1"

    # Try to parse DateTimeOriginal format: YYYY:MM:DD HH:MM:SS
    if [[ $date_string =~ ^([0-9]{4}):([0-9]{2}) ]]; then
        echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
        return 0
    fi

    return 1
}

# Function to get file modification time in YYYY/MM format
get_mtime_date() {
    local file="$1"
    local mtime=$(stat -c %Y "$file")
    date -d "@$mtime" +%Y/%m
}

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

# Function to calculate file checksum
get_checksum() {
    md5sum "$1" | awk '{print $1}'
}

# Function to check if file is a duplicate
is_duplicate() {
    local checksum="$1"
    if grep -q "^$checksum" "$CHECKSUMS_FILE"; then
        return 0  # Is a duplicate
    fi
    return 1  # Not a duplicate
}

# Function to record checksum
record_checksum() {
    local checksum="$1"
    local destination="$2"
    echo "$checksum:$destination" >> "$CHECKSUMS_FILE"
}

# Counter for statistics
total_files=0
processed_files=0
undated_files=0
duplicate_files=0

log_info "Starting to process files..."

# Process all files recursively, excluding hidden files
while IFS= read -r -d '' file; do
    ((total_files++))

    # Skip hidden files
    if [[ $(basename "$file") == .* ]]; then
        continue
    fi

    # Check if it's a media file
    if ! is_media_file "$file"; then
        continue
    fi

    filename=$(basename "$file")

    # Try to extract DateTimeOriginal from EXIF data
    exif_date=$(exiftool -DateTimeOriginal -b "$file" 2>/dev/null || echo "")

    # Determine the year/month directory
    if [ -n "$exif_date" ]; then
        date_path=$(extract_date "$exif_date")
        if [ $? -eq 0 ]; then
            target_dir="$ORGANIZED_DIR/$date_path"
        else
            # Failed to parse EXIF date, use modification time
            date_path=$(get_mtime_date "$file")
            target_dir="$ORGANIZED_DIR/$date_path"
        fi
    else
        # No EXIF data, use modification time
        date_path=$(get_mtime_date "$file")
        target_dir="$ORGANIZED_DIR/$date_path"
    fi

    # Check for duplicates
    checksum=$(get_checksum "$file")

    if is_duplicate "$checksum"; then
        # File is a duplicate
        mkdir -p "$DUPLICATES_DIR"
        cp -p "$file" "$DUPLICATES_DIR/$filename"
        log_warning "Duplicate found (checksum: $checksum): $filename → $DUPLICATES_DIR/"
        ((duplicate_files++))
        record_checksum "$checksum" "$DUPLICATES_DIR/$filename"
    else
        # Not a duplicate, copy to organized directory
        mkdir -p "$target_dir"
        mv "$file" "$target_dir/$filename"
        log_info "Moved: $filename → $date_path/"
        ((processed_files++))
        record_checksum "$checksum" "$target_dir/$filename"
    fi

done < <(find "$SOURCE_DIR" -type f -print0)

log_success "Processing complete!"
echo ""
echo "========== SUMMARY =========="
echo "Total files found: $total_files"
echo "Files processed: $processed_files"
echo "Duplicate files: $duplicate_files"
echo "Output directory: $ORGANIZED_DIR"
echo "==========================="
