#!/bin/bash
#
# Find Duplicates Script
# =====================
# Purpose: Find all duplicate files (by checksum) and move them to a DUPLICATES folder
#
# This script:
#   - Recursively scans a given directory for files
#   - Calculates MD5 checksums to identify duplicates
#   - Keeps the first occurrence of each file in its original location
#   - Moves duplicate files to a top-level DUPLICATES directory
#   - Renames duplicates as <originalname>_copy.<extension>
#   - Generates a summary report of processed files
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
#   - Original files (first occurrence) remain in their current locations
#
# TLDR - Before you run:
#   1. Source directory: the directory to scan for duplicates
#   2. DUPLICATES folder will be created at the top level of source directory
#   3. For each duplicate found, it will be moved and renamed as <originalname>_copy
#   4. Original files are never removed or modified, only duplicates are moved
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

# Temporary file for tracking processed checksums
CHECKSUMS_FILE=$(mktemp)
trap "rm -f $CHECKSUMS_FILE" EXIT

# Counter for statistics
total_files=0
unique_files=0
duplicate_files=0

log_info "Starting to scan files for duplicates..."

# Process all files recursively, excluding hidden files and the DUPLICATES directory
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

    # Get filename and extension
    filename=$(basename "$file")
    extension="${filename##*.}"
    if [ "$extension" = "$filename" ]; then
        # No extension
        name_without_ext="$filename"
    else
        name_without_ext="${filename%.*}"
    fi

    # Calculate checksum
    checksum=$(md5sum "$file" | awk '{print $1}')

    # Check if this checksum has been seen before
    if grep -q "^$checksum" "$CHECKSUMS_FILE"; then
        # This is a duplicate
        original_location=$(grep "^$checksum" "$CHECKSUMS_FILE" | cut -d: -f2-)

        # Create new filename with _copy suffix
        if [ "$extension" = "$filename" ]; then
            duplicate_filename="${name_without_ext}_copy"
        else
            duplicate_filename="${name_without_ext}_copy.${extension}"
        fi

        # Move the duplicate to DUPLICATES folder
        mv "$file" "$DUPLICATES_DIR/$duplicate_filename"
        log_warning "Duplicate found (checksum: $checksum): $filename → DUPLICATES/$duplicate_filename"
        ((duplicate_files++))
    else
        # This is a unique file, record it
        echo "$checksum:$file" >> "$CHECKSUMS_FILE"
        log_info "Unique file: $filename"
        ((unique_files++))
    fi

done < <(find "$SOURCE_DIR" -type f -print0)

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
