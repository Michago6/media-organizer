#!/bin/bash
#
# Check Duplicates by Folder Script
# ==================================
# Purpose: Compare files in a small directory against a main photo directory
#
# This script:
#   - Scans files in a small directory (source for changes)
#   - Compares against files in a main photo directory (reference only)
#   - Matches by filename and/or MD5 checksum
#   - Moves duplicate files from small directory to categorized folders:
#     * DUPLICATE_NAME/ - files with matching names
#     * DUPLICATE_CHECKSUM/ - files with matching checksums (renamed to match original)
#     * DUPLICATE_NAME_AND_CHECKSUM/ - files with both matching (renamed to match original)
#   - Files in main directory are NEVER modified
#   - When checksums match, files are renamed to match the original filename
#
# Usage:
#   ./check-duplicates-by-folder.sh
#   - Prompts for small directory (will be modified)
#   - Prompts for main directory (will NOT be modified, reference only)
#   - Creates duplicate folders inside small directory
#   - Duplicates are moved and categorized by match type
#
# ⚠️  ATTENTION: IRREVERSIBLE CHANGES WILL BE MADE
#   - Files in small directory WILL BE MOVED to DUPLICATE_* folders
#   - Files with checksum matches will be RENAMED to match original filename
#   - Main photo directory will NEVER be altered
#
# TLDR - Before you run:
#   1. Small directory: directory with potentially duplicate files (WILL BE MODIFIED)
#   2. Main directory: master photo collection (read-only reference, WILL NOT BE CHANGED)
#   3. Duplicates will be sorted into folders inside small directory
#   4. Ensure you have backups of small directory if needed before running

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

# Ask for small directory (will be modified)
read -p "Enter the small directory to check for duplicates (FILES WILL BE MOVED): " SMALL_DIR

if [ ! -d "$SMALL_DIR" ]; then
    log_error "Small directory does not exist: $SMALL_DIR"
    exit 1
fi

log_success "Small directory: $SMALL_DIR"

# Ask for main directory (read-only reference)
read -p "Enter the main photo directory (THIS DIRECTORY WILL NOT BE CHANGED): " MAIN_DIR

if [ ! -d "$MAIN_DIR" ]; then
    log_error "Main directory does not exist: $MAIN_DIR"
    exit 1
fi

log_success "Main directory: $MAIN_DIR"
log_warning "Main directory will remain untouched - it is used as reference only"

# Create duplicate tracking directories inside small directory
DUPLICATE_NAME_DIR="$SMALL_DIR/DUPLICATE_NAME"
DUPLICATE_CHECKSUM_DIR="$SMALL_DIR/DUPLICATE_CHECKSUM"
DUPLICATE_BOTH_DIR="$SMALL_DIR/DUPLICATE_NAME_AND_CHECKSUM"
mkdir -p "$DUPLICATE_NAME_DIR" "$DUPLICATE_CHECKSUM_DIR" "$DUPLICATE_BOTH_DIR"

# Temporary files for tracking
SMALL_FILES_DATA=$(mktemp)
MAIN_FILES_DATA=$(mktemp)
trap "rm -f $SMALL_FILES_DATA $MAIN_FILES_DATA" EXIT

# Counters for statistics
total_small_files=0
files_by_name=0
files_by_checksum=0
files_by_both=0
unique_files=0

log_info "Scanning main directory (pass 1/2: collecting reference data)..."

# Pass 1: Collect all files from main directory with checksums
# Format: checksum|filename
while IFS= read -r -d '' file; do
    # Skip hidden files
    if [[ $(basename "$file") == .* ]]; then
        continue
    fi

    # Calculate checksum
    checksum=$(md5sum "$file" | awk '{print $1}')
    filename=$(basename "$file")

    # Store: checksum|filename
    echo "$checksum|$filename" >> "$MAIN_FILES_DATA"

done < <(find "$MAIN_DIR" -type f -print0)

log_success "Main directory scanned"

log_info "Scanning small directory (pass 2/2: comparing and moving files)..."

# Pass 2: Process files from small directory
while IFS= read -r -d '' file; do
    # Skip the duplicate directories we created
    if [[ "$file" == *"/DUPLICATE_NAME/"* ]] || \
       [[ "$file" == *"/DUPLICATE_CHECKSUM/"* ]] || \
       [[ "$file" == *"/DUPLICATE_NAME_AND_CHECKSUM/"* ]]; then
        continue
    fi

    # Skip hidden files
    if [[ $(basename "$file") == .* ]]; then
        continue
    fi

    ((total_small_files++))

    filename=$(basename "$file")
    checksum=$(md5sum "$file" | awk '{print $1}')

    # Check if name matches anything in main dir
    name_match=$(grep "^[^|]*|$filename$" "$MAIN_FILES_DATA" | head -1)

    # Check if checksum matches anything in main dir
    checksum_match=$(grep "^$checksum|" "$MAIN_FILES_DATA" | head -1)

    if [ -n "$checksum_match" ] && [ -n "$name_match" ]; then
        # Both match - extract original filename from main dir
        original_filename=$(echo "$checksum_match" | cut -d'|' -f2-)
        new_file="$DUPLICATE_BOTH_DIR/$original_filename"

        mv "$file" "$new_file"
        log_warning "DUPLICATE (name+checksum): $filename → renamed to $original_filename → DUPLICATE_NAME_AND_CHECKSUM/"
        ((files_by_both++))

    elif [ -n "$checksum_match" ]; then
        # Checksum matches - extract original filename from main dir and rename
        original_filename=$(echo "$checksum_match" | cut -d'|' -f2-)
        new_file="$DUPLICATE_CHECKSUM_DIR/$original_filename"

        mv "$file" "$new_file"
        log_warning "DUPLICATE (checksum): $filename → renamed to $original_filename → DUPLICATE_CHECKSUM/"
        ((files_by_checksum++))

    elif [ -n "$name_match" ]; then
        # Name matches only
        new_file="$DUPLICATE_NAME_DIR/$filename"

        mv "$file" "$new_file"
        log_warning "DUPLICATE (name): $filename → DUPLICATE_NAME/"
        ((files_by_name++))

    else
        # No match found
        log_info "Unique file: $filename"
        ((unique_files++))
    fi

done < <(find "$SMALL_DIR" -type f -print0)

log_success "Processing complete!"
echo ""
echo "========== SUMMARY =========="
echo "Total files in small directory: $total_small_files"
echo "Unique files (no match): $unique_files"
echo "Duplicates by name only: $files_by_name"
echo "Duplicates by checksum: $files_by_checksum"
echo "Duplicates by both: $files_by_both"
echo ""
echo "Small directory: $SMALL_DIR"
echo "Main directory: $MAIN_DIR (untouched)"
echo "==========================="
