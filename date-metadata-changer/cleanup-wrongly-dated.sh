#!/bin/bash
#
# Cleanup Wrongly Dated Folders
# =============================
# Purpose: Remove all WRONGLY-DATED folders created by fix-wrongly-dated.sh
#
# This script:
#   - Scans a target directory with YYYY/MM folder structure
#   - Finds and deletes all WRONGLY-DATED subfolders
#   - Reverses the effects of running fix-wrongly-dated.sh
#
# Usage:
#   ./cleanup-wrongly-dated.sh
#   - Prompts for target directory with YYYY/MM folder structure
#   - Finds all YYYY/MM/WRONGLY-DATED folders
#   - Deletes them (can be re-created by running fix-wrongly-dated.sh again)
#
# Dependencies: none (uses standard bash commands)
#
# ⚠️  ATTENTION: REVERSIBLE CHANGES ONLY
#   - Only deletes WRONGLY-DATED folders (which contain only copies)
#   - Original files in YYYY/MM folders are never touched
#   - If needed, you can re-run fix-wrongly-dated.sh to recreate these folders
#   - No irreparable damage is possible
#
# TLDR - Before you run:
#   1. Target directory: path containing your YYYY/MM folder structure
#   2. This script ONLY deletes WRONGLY-DATED subfolders
#   3. Original files in YYYY/MM folders remain completely untouched
#   4. If you delete them by mistake, just re-run fix-wrongly-dated.sh
#   5. Completely safe and reversible
#

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

# Ask for target directory
read -p "Enter the target directory containing YYYY/MM folder structure: " TARGET_DIR

if [ ! -d "$TARGET_DIR" ]; then
    log_error "Target directory does not exist: $TARGET_DIR"
    exit 1
fi

log_success "Target directory: $TARGET_DIR"

# Counter for statistics
folders_found=0
folders_deleted=0

log_info "Scanning for WRONGLY-DATED folders..."

# Find all WRONGLY-DATED folders and delete them
while IFS= read -r -d '' wrongly_dated_folder; do
    ((folders_found++))

    folder_path=$(dirname "$wrongly_dated_folder")
    folder_name=$(basename "$folder_path")
    parent_name=$(basename "$(dirname "$folder_path")")

    log_info "Found: $parent_name/$folder_name/WRONGLY-DATED"

done < <(find "$TARGET_DIR" -type d -name "WRONGLY-DATED" -print0)

if [ $folders_found -eq 0 ]; then
    log_success "No WRONGLY-DATED folders found. Nothing to clean up."
    exit 0
fi

echo ""
echo "Found $folders_found WRONGLY-DATED folder(s) to delete."
read -p "Continue with deletion? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    log_warning "Cleanup cancelled."
    exit 0
fi

# Now delete the folders
while IFS= read -r -d '' wrongly_dated_folder; do
    rm -rf "$wrongly_dated_folder"
    ((folders_deleted++))

    folder_path=$(dirname "$wrongly_dated_folder")
    folder_name=$(basename "$folder_path")
    parent_name=$(basename "$(dirname "$folder_path")")

    log_success "Deleted: $parent_name/$folder_name/WRONGLY-DATED"

done < <(find "$TARGET_DIR" -type d -name "WRONGLY-DATED" -print0)

log_success "Cleanup complete!"
echo ""
echo "========== SUMMARY =========="
echo "WRONGLY-DATED folders deleted: $folders_deleted"
echo "==========================="
