#!/bin/bash
#
# Find Duplicates Script
# =====================
# Purpose: Find all duplicate files (by checksum) and move them to a DUPLICATES folder
#
# This script:
#   - Recursively scans a given directory for files
#   - Calculates MD5 checksums to identify duplicates
#   - Prioritizes files with the earliest valid EXIF date as originals
#   - Moves duplicate files to a top-level DUPLICATES directory
#   - Moves duplicates to DUPLICATES folder with original names
#   - Generates a summary report of processed files
#
# Date Priority:
#   - Checks Media Create Date, then Media Modify Date, then File Modification Date/Time
#   - Dates before 2000 are considered invalid
#   - Earliest valid date is kept as original, others are marked as copies
#
# Usage:
#   ./find-duplicates.sh
#   - Prompts for source directory to scan
#   - Automatically finds and moves all duplicates
#   - Creates a DUPLICATES folder at the top level
#
# ⚠️  ATTENTION: IRREVERSIBLE CHANGES WILL BE MADE
#   - Script does NOT remove files, only moves duplicates to DUPLICATES folder
#   - Files will be MOVED from their current location to DUPLICATES
#   - The file with the earliest date is kept as original
#
# TLDR - Before you run:
#   1. Source directory: the directory to scan for duplicates
#   2. DUPLICATES folder will be created at the top level of source directory
#   3. For each duplicate set, the file with the earliest date is kept as original
#   4. Other files are moved to DUPLICATES folder with their original names
#   5. After completion, review DUPLICATES folder and delete as needed

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
    log_error "exiftool is not installed. Please install it first:"
    log_error "  Ubuntu/Debian: sudo apt-get install libimage-exiftool-perl"
    log_error "  macOS: brew install exiftool"
    exit 1
fi

log_success "exiftool is available"

# Function to get the file's date
# Returns the earliest valid date from EXIF or file modification time
get_file_date() {
    local file="$1"
    local date=""

    # Try Media Create Date
    date=$(exiftool -s -S -MediaCreateDate "$file" 2>/dev/null | grep -v "^$" | head -1)
    if [ -n "$date" ] && [ "$date" != "0000:00:00 00:00:00" ]; then
        echo "$date"
        return
    fi

    # Try Media Modify Date
    date=$(exiftool -s -S -MediaModifyDate "$file" 2>/dev/null | grep -v "^$" | head -1)
    if [ -n "$date" ] && [ "$date" != "0000:00:00 00:00:00" ]; then
        echo "$date"
        return
    fi

    # Fall back to File Modification Date/Time
    date=$(exiftool -s -S -FileModifyDate "$file" 2>/dev/null | grep -v "^$" | head -1)
    if [ -n "$date" ]; then
        echo "$date"
        return
    fi

    # If nothing found, return empty
    echo ""
}

# Function to check if date is valid (not before 2000)
is_valid_date() {
    local date="$1"
    if [ -z "$date" ]; then
        return 1
    fi

    # Extract year from date (YYYY:MM:DD HH:MM:SS format)
    local year="${date:0:4}"
    if [ "$year" -lt 2000 ]; then
        return 1
    fi
    return 0
}

# Ask for source directory
read -p "Enter the source directory to scan for duplicates: " SOURCE_DIR

if [ ! -d "$SOURCE_DIR" ]; then
    log_error "Source directory does not exist: $SOURCE_DIR"
    exit 1
fi

log_success "Source directory: $SOURCE_DIR"

# Create DUPLICATES directory at the top level
DUPLICATES_DIR="$SOURCE_DIR/DUPLICATES"
mkdir -p "$DUPLICATES_DIR"
log_info "DUPLICATES directory will be created at: $DUPLICATES_DIR"

# Temporary files for tracking
FILES_DATA=$(mktemp)
CHECKSUMS_MAP=$(mktemp)
trap "rm -f $FILES_DATA $CHECKSUMS_MAP" EXIT

# Counter for statistics
total_files=0
unique_files=0
duplicate_files=0

log_info "Starting to scan files for duplicates (pass 1/2: calculating checksums)..."

# Pass 1: Collect all files and their checksums
while IFS= read -r -d '' file; do
    # Skip the DUPLICATES directory itself
    if [[ "$file" == *"/DUPLICATES/"* ]] || [[ "$file" == "$DUPLICATES_DIR"* ]]; then
        continue
    fi

    # Skip hidden files
    if [[ $(basename "$file") == .* ]]; then
        continue
    fi

    ((total_files++))

    # Calculate checksum
    checksum=$(md5sum "$file" | awk '{print $1}')

    # Store: checksum|filepath
    echo "$checksum|$file" >> "$FILES_DATA"

done < <(find "$SOURCE_DIR" -type f -print0)

log_info "Starting to process duplicates (pass 2/2: determining originals)..."

# Pass 2: Group by checksum and determine original vs copies
while IFS= read -r line; do
    checksum=$(echo "$line" | cut -d'|' -f1)

    # Get all files with this checksum
    file_list=$(grep "^$checksum|" "$FILES_DATA" | cut -d'|' -f2-)
    file_count=$(echo "$file_list" | wc -l)

    # Skip if we've already processed this checksum
    if grep -q "^$checksum$" "$CHECKSUMS_MAP" 2>/dev/null; then
        continue
    fi

    # Mark checksum as processed
    echo "$checksum" >> "$CHECKSUMS_MAP"

    if [ "$file_count" -eq 1 ]; then
        # Unique file
        original=$(echo "$file_list" | head -1)
        filename=$(basename "$original")
        log_info "Unique file: $filename"
        ((unique_files++))
    else
        # Multiple files with same checksum - find which is original
        original=""
        earliest_date=""
        oldest_file=""

        # Get file with earliest valid date
        while IFS= read -r file; do
            date=$(get_file_date "$file")

            if is_valid_date "$date"; then
                if [ -z "$oldest_file" ] || [ "$date" \< "$earliest_date" ]; then
                    earliest_date="$date"
                    oldest_file="$file"
                fi
            fi
        done < <(echo "$file_list")

        # If we found a file with valid date, use it as original
        if [ -n "$oldest_file" ]; then
            original="$oldest_file"
        else
            # No valid dates found, keep first one as original
            original=$(echo "$file_list" | head -1)
        fi

        # Move all others to DUPLICATES with original's filename
        original_filename=$(basename "$original")
        while IFS= read -r file; do
            if [ "$file" != "$original" ]; then
                filename=$(basename "$file")

                mv "$file" "$DUPLICATES_DIR/$original_filename"
                file_date=$(get_file_date "$file")
                log_warning "Duplicate found: $filename (date: $file_date) → DUPLICATES/$original_filename"
                ((duplicate_files++))
            fi
        done < <(echo "$file_list")

        original_date=$(get_file_date "$original")
        log_success "Original kept: $original_filename (date: $original_date)"
    fi

done < <(cut -d'|' -f1 "$FILES_DATA" | sort -u)

log_success "Processing complete!"
echo ""
echo "========== SUMMARY =========="
echo "Total files scanned: $total_files"
echo "Unique files: $unique_files"
echo "Duplicate files moved: $duplicate_files"
echo "DUPLICATES location: $DUPLICATES_DIR"
echo "==========================="
echo ""
log_info "Please review the DUPLICATES folder and delete any files you no longer need."
