#!/bin/bash
#
# Fix Wrongly Dated Media Files
# =============================
# Purpose: Find media files with EXIF dates that don't match their folder location
#
# This script:
#   - Scans a target directory with YYYY/MM folder structure
#   - Checks EXIF DateTimeOriginal/CreateDate for each media file
#   - If EXIF date doesn't match the YYYY/MM folder, creates a copy in YYYY/MM/WRONGLY-DATED/
#   - Updates the EXIF metadata of the copy to 1st of the month matching the folder location
#   - Files without EXIF data are also copied to WRONGLY-DATED
#   - Original files remain unchanged
#
# Usage:
#   ./fix-wrongly-dated.sh
#   - Prompts for target directory with YYYY/MM folder structure
#   - Scans all media files in each YYYY/MM subfolder
#   - Creates WRONGLY-DATED folder for mismatched/no-exif files
#   - Updates EXIF date of copies to: YYYY-MM-01 (1st of the folder's month)
#   - Generates summary report showing stats
#
# Supported media types:
#   Images: jpg, jpeg, png, gif, webp, heic, heif
#   Videos: mp4, mov, avi, mkv, flv, wmv, webm, m4v, mpg, mpeg, 3gp, m2ts
#
# Dependencies: exiftool
#
# ⚠️  ATTENTION: REVERSIBLE CHANGES ONLY
#   - Original files are NEVER modified or moved
#   - Only COPIES are created in WRONGLY-DATED folder
#   - EXIF metadata is only changed on the copies
#   - Original files remain in their original locations unchanged
#
# TLDR - Before you run:
#   1. Target directory: path containing your YYYY/MM folder structure
#   2. Files are NOT moved or deleted - only copied to WRONGLY-DATED subfolders
#   3. Copies will have EXIF date updated to 1st of folder's month/year
#   4. Missing EXIF data? Files are still copied to WRONGLY-DATED
#   5. Original files are always preserved - completely safe to run
#   6. Requires exiftool to be installed

set -uo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Ask for target directory
read -p "Enter the target directory containing YYYY/MM folder structure: " TARGET_DIR

if [ ! -d "$TARGET_DIR" ]; then
    log_error "Target directory does not exist: $TARGET_DIR"
    exit 1
fi

log_success "Target directory: $TARGET_DIR"

# Media extensions (case-insensitive)
MEDIA_EXTENSIONS="jpg|jpeg|png|gif|webp|heic|heif|mp4|mov|avi|mkv|flv|wmv|webm|m4v|mpg|mpeg|3gp|m2ts"

# Counter for statistics
total_files=0
wrongly_dated_files=0
no_exif_files=0
correctly_dated_files=0

log_info "Starting to scan files..."

# Find all YYYY/MM directories
while IFS= read -r -d '' yyyy_mm_dir; do
    # Extract YYYY and MM from path
    folder_name=$(basename "$yyyy_mm_dir")

    # Check if folder matches YYYY/MM pattern
    if [[ ! $folder_name =~ ^[0-9]{2}$ ]]; then
        continue
    fi

    yyyy_dir=$(basename "$(dirname "$yyyy_mm_dir")")
    if [[ ! $yyyy_dir =~ ^[0-9]{4}$ ]]; then
        continue
    fi

    mm=$folder_name
    yyyy=$yyyy_dir

    log_info "Processing folder: $yyyy/$mm"

    # Process all files in this YYYY/MM folder (non-recursive)
    while IFS= read -r -d '' file; do
        ((total_files++))

        filename=$(basename "$file")
        extension="${filename##*.}"
        extension="${extension,,}"

        # Check if it's a media file
        if ! [[ $extension =~ ^($MEDIA_EXTENSIONS)$ ]]; then
            continue
        fi

        # Create WRONGLY-DATED directory
        wrongly_dated_dir="$yyyy_mm_dir/WRONGLY-DATED"

        # Try to extract DateTimeOriginal or CreateDate from EXIF
        exif_date=$(exiftool -DateTimeOriginal -b "$file" 2>/dev/null || echo "")

        if [ -z "$exif_date" ]; then
            exif_date=$(exiftool -CreateDate -b "$file" 2>/dev/null || echo "")
        fi

        # If no EXIF date, try File Modification Date as fallback
        source_date="$exif_date"
        date_source="EXIF"

        if [ -z "$source_date" ]; then
            source_date=$(exiftool -FileModifyDate -b "$file" 2>/dev/null || echo "")
            date_source="FileModifyDate"
        fi

        # If still no date found, copy to WRONGLY-DATED
        if [ -z "$source_date" ]; then
            mkdir -p "$wrongly_dated_dir"
            cp -p "$file" "$wrongly_dated_dir/$filename"

            # Update metadata to folder's month/year, 1st day
            new_date="$yyyy:$mm:01 00:00:00"
            exiftool -overwrite_original -DateTimeOriginal="$new_date" -CreateDate="$new_date" -FileModifyDate="$new_date" "$wrongly_dated_dir/$filename" > /dev/null 2>&1
            touch -t "${yyyy}${mm}010000" "$wrongly_dated_dir/$filename"

            log_warning "No date metadata found: $filename → $yyyy/$mm/WRONGLY-DATED/ [metadata set to $yyyy-$mm-01]"
            ((no_exif_files++))
            continue
        fi

        # Parse date (format: YYYY:MM:DD HH:MM:SS)
        if [[ $source_date =~ ^([0-9]{4}):([0-9]{2}): ]]; then
            source_yyyy="${BASH_REMATCH[1]}"
            source_mm="${BASH_REMATCH[2]}"
        else
            log_warning "Could not parse date for: $filename"
            continue
        fi

        # Check if date matches folder location
        if [ "$source_yyyy" != "$yyyy" ] || [ "$source_mm" != "$mm" ]; then
            # Date mismatch - copy to WRONGLY-DATED and update metadata
            mkdir -p "$wrongly_dated_dir"
            cp -p "$file" "$wrongly_dated_dir/$filename"

            # Update all metadata to 1st of the month of the folder
            new_date="$yyyy:$mm:01 00:00:00"
            exiftool -overwrite_original -DateTimeOriginal="$new_date" -CreateDate="$new_date" -FileModifyDate="$new_date" "$wrongly_dated_dir/$filename" > /dev/null 2>&1
            touch -t "${yyyy}${mm}010000" "$wrongly_dated_dir/$filename"

            log_warning "Wrongly dated ($date_source: $source_yyyy-$source_mm, Folder: $yyyy-$mm): $filename → $yyyy/$mm/WRONGLY-DATED/ [metadata updated to $yyyy-$mm-01]"
            ((wrongly_dated_files++))
        else
            # Date matches folder location
            ((correctly_dated_files++))
        fi

    done < <(find "$yyyy_mm_dir" -maxdepth 1 -type f -print0)

done < <(find "$TARGET_DIR" -type d -print0)

log_success "Processing complete!"
echo ""
echo "========== SUMMARY =========="
echo "Total files scanned: $total_files"
echo "Correctly dated files: $correctly_dated_files"
echo "Wrongly dated files: $wrongly_dated_files"
echo "Files without EXIF data: $no_exif_files"
echo "==========================="
