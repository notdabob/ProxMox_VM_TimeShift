#!/bin/bash
# Codebase Reorganization Script for ProxMox_VM_TimeShift
# This script helps clean up and restructure the codebase
# Run with --dry-run first to see what would happen

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
DRY_RUN=false
BACKUP=true
ARCHIVE_DIR="archive"
SEPARATE_PROJECTS_DIR="separate-projects"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --no-backup)
            BACKUP=false
            shift
            ;;
        --help)
            echo "Usage: $0 [--dry-run] [--no-backup]"
            echo "  --dry-run    Show what would be done without making changes"
            echo "  --no-backup  Skip creating backup (not recommended)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

execute_cmd() {
    local cmd="$1"
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would execute: $cmd"
    else
        echo -e "${BLUE}[EXEC]${NC} $cmd"
        eval "$cmd"
    fi
}

create_dir() {
    local dir="$1"
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} Would create directory: $dir"
    else
        mkdir -p "$dir"
        echo -e "${GREEN}[CREATED]${NC} Directory: $dir"
    fi
}

move_file() {
    local src="$1"
    local dst="$2"
    if [[ -e "$src" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            echo -e "${YELLOW}[DRY-RUN]${NC} Would move: $src → $dst"
        else
            mkdir -p "$(dirname "$dst")"
            mv "$src" "$dst"
            echo -e "${GREEN}[MOVED]${NC} $src → $dst"
        fi
    else
        echo -e "${YELLOW}[SKIP]${NC} Not found: $src"
    fi
}

# Main script
log_info "Starting ProxMox_VM_TimeShift codebase reorganization"

if [[ "$DRY_RUN" == true ]]; then
    log_warning "Running in DRY-RUN mode - no changes will be made"
fi

# Step 1: Create backup
if [[ "$BACKUP" == true ]]; then
    log_info "Creating backup..."
    if [[ "$DRY_RUN" == false ]]; then
        tar -czf "proxmox-vm-timeshift-backup-${TIMESTAMP}.tar.gz" \
            --exclude='*.tar.gz' \
            --exclude='.git' \
            --exclude='node_modules' \
            --exclude='__pycache__' \
            .
        log_success "Backup created: proxmox-vm-timeshift-backup-${TIMESTAMP}.tar.gz"
    else
        log_warning "Would create backup: proxmox-vm-timeshift-backup-${TIMESTAMP}.tar.gz"
    fi
else
    log_warning "Skipping backup (not recommended!)"
fi

# Step 2: Create new directory structure
log_info "Creating new directory structure..."
create_dir "deploy"
create_dir "config/dashboard"
create_dir "docker/services/idrac-manager/src"
create_dir "docker/services/idrac-manager/docker"
create_dir "scripts"
create_dir "docs/images"
create_dir "docs/archive"
create_dir "tests"
create_dir "${ARCHIVE_DIR}/legacy-proxmox-scripts"
create_dir "${ARCHIVE_DIR}/legacy-time-shift-vm"
create_dir "${ARCHIVE_DIR}/legacy-scripts"
create_dir "${ARCHIVE_DIR}/legacy-deployment"
create_dir "${SEPARATE_PROJECTS_DIR}"

# Step 3: Move unrelated projects
log_info "Separating unrelated projects..."
move_file "ai-key-manager" "${SEPARATE_PROJECTS_DIR}/ai-key-manager"

# Step 4: Archive legacy components
log_info "Archiving legacy components..."

# Archive ProxMox VE scripts
if [[ -d "proxmox_ve-scripts" ]]; then
    move_file "proxmox_ve-scripts" "${ARCHIVE_DIR}/legacy-proxmox-scripts/"
fi

# Archive time-shift-proxmox
if [[ -d "time-shift-proxmox" ]]; then
    move_file "time-shift-proxmox" "${ARCHIVE_DIR}/legacy-time-shift-vm/"
fi

# Archive redundant scripts from namespace-timeshift-browser-container
move_file "namespace-timeshift-browser-container/deploy-proxmox.sh" "${ARCHIVE_DIR}/legacy-scripts/"
move_file "namespace-timeshift-browser-container/container-rebuild.sh" "${ARCHIVE_DIR}/legacy-scripts/"
move_file "namespace-timeshift-browser-container/emergency-fix.sh" "${ARCHIVE_DIR}/legacy-scripts/"
move_file "namespace-timeshift-browser-container/fix-container.sh" "${ARCHIVE_DIR}/legacy-scripts/"
move_file "namespace-timeshift-browser-container/restart-fix.sh" "${ARCHIVE_DIR}/legacy-scripts/"
move_file "namespace-timeshift-browser-container/test-multi-server.sh" "${ARCHIVE_DIR}/legacy-scripts/"

# Archive legacy deployment scripts
move_file "deployment-execution.sh" "${ARCHIVE_DIR}/legacy-deployment/"
move_file "install-complete-mcp-solution.sh" "${ARCHIVE_DIR}/legacy-deployment/"
move_file "install-servemyapi.sh" "${ARCHIVE_DIR}/legacy-deployment/"
move_file "CREATE-MISSING-FILES.sh" "${ARCHIVE_DIR}/legacy-deployment/"

# Archive various fix scripts
move_file "fix_dropbox_permissions.sh" "${ARCHIVE_DIR}/legacy-scripts/"
move_file "fix_vscode_insiders.py" "${ARCHIVE_DIR}/legacy-scripts/"
move_file "vscode-insiders-migration.sh" "${ARCHIVE_DIR}/legacy-scripts/"
move_file "vscode_insiders_installer.sh" "${ARCHIVE_DIR}/legacy-scripts/"

# Step 5: Reorganize main components
log_info "Reorganizing main components..."

# Move deployment scripts
move_file "deploy-unified-stack.sh" "deploy/deploy-stack.sh"
move_file "scripts/unified-vm-create.sh" "deploy/create-vm.sh"
move_file "scripts/service-discovery.sh" "deploy/service-discovery.sh"
move_file "scripts/migrate-legacy.sh" "scripts/migrate-legacy.sh"

# Move Docker files
move_file "docker-compose-unified.yaml" "docker/docker-compose.yaml"

# Move iDRAC manager components
move_file "namespace-timeshift-browser-container/Dockerfile" "docker/services/idrac-manager/Dockerfile"
move_file "namespace-timeshift-browser-container/requirements.txt" "docker/services/idrac-manager/requirements.txt"
move_file "namespace-timeshift-browser-container/src" "docker/services/idrac-manager/src"
move_file "namespace-timeshift-browser-container/docker" "docker/services/idrac-manager/docker"

# Move configuration files (already in correct location)
log_info "Configuration files already in correct location (config/)"

# Step 6: Move documentation
log_info "Reorganizing documentation..."
move_file "CLONE-INSTRUCTIONS.md" "docs/archive/CLONE-INSTRUCTIONS.md"
move_file "SETUP-INSTRUCTIONS.md" "docs/archive/SETUP-INSTRUCTIONS.md"
move_file "DEPLOYMENT-GUIDE.md" "docs/DEPLOYMENT-GUIDE.md"
move_file "QUICK-START.md" "docs/QUICK-START.md"
move_file "EXECUTION-LOG.md" "docs/archive/EXECUTION-LOG.md"
move_file "CODEBASE-ANALYSIS.md" "docs/CODEBASE-ANALYSIS.md"
move_file "CLEANUP-PLAN.md" "docs/CLEANUP-PLAN.md"

# Archive namespace-specific docs
move_file "namespace-timeshift-browser-container/AGENTS.md" "${ARCHIVE_DIR}/legacy-docs/namespace-AGENTS.md"
move_file "namespace-timeshift-browser-container/DEPLOYMENT-SUMMARY.md" "${ARCHIVE_DIR}/legacy-docs/namespace-DEPLOYMENT-SUMMARY.md"
move_file "namespace-timeshift-browser-container/PROXMOX-SETUP.md" "${ARCHIVE_DIR}/legacy-docs/namespace-PROXMOX-SETUP.md"
move_file "namespace-timeshift-browser-container/RDM-EXPORT.md" "${ARCHIVE_DIR}/legacy-docs/namespace-RDM-EXPORT.md"
move_file "namespace-timeshift-browser-container/SCANNER-FX.md" "${ARCHIVE_DIR}/legacy-docs/namespace-SCANNER-FIX.md"
move_file "namespace-timeshift-browser-container/debug-scanner.sh" "${ARCHIVE_DIR}/legacy-scripts/"

# Step 7: Clean up empty directories
log_info "Cleaning up empty directories..."
if [[ "$DRY_RUN" == false ]]; then
    find . -type d -empty -delete 2>/dev/null || true
fi

# Step 8: Create marker files
log_info "Creating marker files..."
if [[ "$DRY_RUN" == false ]]; then
    echo "# Archive Directory" > "${ARCHIVE_DIR}/README.md"
    echo "This directory contains legacy and deprecated code from the restructuring on ${TIMESTAMP}" >> "${ARCHIVE_DIR}/README.md"
    echo "" >> "${ARCHIVE_DIR}/README.md"
    echo "These files are kept for reference but should not be used in production." >> "${ARCHIVE_DIR}/README.md"
    
    echo "# Separate Projects" > "${SEPARATE_PROJECTS_DIR}/README.md"
    echo "This directory contains projects that were incorrectly included in the main repository." >> "${SEPARATE_PROJECTS_DIR}/README.md"
    echo "These should be moved to their own repositories." >> "${SEPARATE_PROJECTS_DIR}/README.md"
fi

# Step 9: Update file references
log_info "File references need to be updated manually:"
echo "  1. Update paths in deploy/deploy-stack.sh"
echo "  2. Update build contexts in docker/docker-compose.yaml"
echo "  3. Update import paths in Python scripts"
echo "  4. Update documentation links"

# Summary
log_info "Reorganization complete!"
echo ""
echo "Next steps:"
echo "1. Review the changes (especially if run with --dry-run)"
echo "2. Update file references as noted above"
echo "3. Test deployment with new structure"
echo "4. Commit changes to git"
echo "5. Consider removing ${ARCHIVE_DIR} after confirming everything works"
echo ""

if [[ "$DRY_RUN" == true ]]; then
    log_warning "This was a DRY RUN - no actual changes were made"
    log_info "Run without --dry-run to apply changes"
fi