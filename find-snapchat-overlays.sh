#!/bin/bash
#
# Find Snapchat Overlays Script
# =============================
# Purpose: Find and move Snapchat overlay files to a dedicated folder
#
# This script:
#   - Recursively scans a given directory for files
#   - Identifies files ending with "-overlay" in their filename
#   - Moves all overlay files to an overlay-files directory
#   - Generates a summary report of processed files
#
# Usage:
#   ./find-snapchat-overlays.sh
#   - Prompts for source directory to scan
#   - Automatically finds and moves all overlay files
#   - Creates an overlay-files folder at the top level
#
# ⚠️  ATTENTION: IRREVERSIBLE CHANGES WILL BE MADE
#   - Script MOVES files from their current location to overlay-files folder
#   - Original directory structure is not preserved
#   - Files are not deleted, only moved
#
# TLDR - Before you run:
#   1. Source directory: the directory to scan for overlay files
#   2. overlay-files folder will be created at the top level of source directory
#   3. All files with "-overlay" in their name will be moved there
#   4. After completion, review overlay-files folder and delete as needed

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
read -p "Enter the source directory to scan for overlay files: " SOURCE_DIR

if [ ! -d "$SOURCE_DIR" ]; then
    log_error "Source directory does not exist: $SOURCE_DIR"
    exit 1
fi

log_success "Source directory: $SOURCE_DIR"

# Create overlay-files directory at the top level
OVERLAY_DIR="$SOURCE_DIR/overlay-files"
mkdir -p "$OVERLAY_DIR"
log_info "overlay-files directory will be created at: $OVERLAY_DIR"

# Counter for statistics
total_files=0
overlay_files=0

log_info "Starting to scan files for overlays..."

# Process all files recursively, excluding hidden files and the overlay-files directory
while IFS= read -r -d '' file; do
    # Skip the overlay-files directory itself
    if [[ "$file" == *"/overlay-files/"* ]] || [[ "$file" == "$OVERLAY_DIR"* ]]; then
        continue
    fi

    # Skip hidden files
    if [[ $(basename "$file") == .* ]]; then
        continue
    fi

    # Get filename
    filename=$(basename "$file")

    # Check if filename contains "-overlay"
    if [[ "$filename" == *"-overlay"* ]]; then
        ((total_files++))

        # Move the overlay file to overlay-files folder
        mv "$file" "$OVERLAY_DIR/$filename"
        log_warning "Overlay file found and moved: $filename"
        ((overlay_files++))
    fi

done < <(find "$SOURCE_DIR" -type f -print0)

log_success "Processing complete!"
echo ""
echo "========== SUMMARY =========="
echo "Overlay files moved: $overlay_files"
echo "overlay-files location: $OVERLAY_DIR"
echo "==========================="
echo ""
log_info "Please review the overlay-files folder and delete any files you no longer need."
