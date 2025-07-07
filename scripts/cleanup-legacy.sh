#!/bin/bash
# Legacy Code Cleanup Script
# Removes outdated files and consolidates the codebase

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Function to create archive of legacy files
archive_legacy_files() {
    print_status "Creating archive of legacy files..."
    
    local archive_date=$(date +%Y%m%d-%H%M%S)
    local archive_file="$PROJECT_ROOT/legacy-backup-$archive_date.tar.gz"
    
    # Create archive of current archive directory
    if [[ -d "$PROJECT_ROOT/archive" ]]; then
        tar -czf "$archive_file" -C "$PROJECT_ROOT" archive/
        print_success "Legacy files archived to: $archive_file"
    else
        print_warning "No archive directory found to backup"
    fi
}

# Function to identify duplicate functionality
identify_duplicates() {
    print_status "Identifying duplicate functionality..."
    
    # Find duplicate script names
    find "$PROJECT_ROOT" -name "*.sh" -type f | while read -r file; do
        local basename=$(basename "$file")
        local count=$(find "$PROJECT_ROOT" -name "$basename" -type f | wc -l)
        if [[ $count -gt 1 ]]; then
            print_warning "Duplicate script name found: $basename"
            find "$PROJECT_ROOT" -name "$basename" -type f
            echo ""
        fi
    done
    
    # Find similar function names across scripts
    print_status "Checking for duplicate functions..."
    local temp_functions=$(mktemp)
    
    find "$PROJECT_ROOT" -name "*.sh" -type f -exec grep -H "^[[:space:]]*function\|^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*(" {} \; | \
        sed 's/.*:\s*\(function\s*\)\?\([a-zA-Z_][a-zA-Z0-9_]*\).*/\2/' | \
        sort | uniq -c | sort -nr > "$temp_functions"
    
    local duplicates=$(awk '$1 > 1 {print $2}' "$temp_functions")
    if [[ -n "$duplicates" ]]; then
        print_warning "Functions that appear in multiple files:"
        echo "$duplicates"
    fi
    
    rm -f "$temp_functions"
}

# Function to consolidate configuration files
consolidate_configs() {
    print_status "Consolidating configuration files..."
    
    # Find all YAML and JSON config files
    local config_files=$(find "$PROJECT_ROOT" -name "*.yaml" -o -name "*.yml" -o -name "*.json" | grep -v node_modules | grep -v .git)
    
    print_status "Found configuration files:"
    echo "$config_files"
    
    # Check for conflicting configurations
    local conflicts=0
    
    # Check for duplicate port definitions
    local ports=$(grep -r "port.*:" "$PROJECT_ROOT/config" 2>/dev/null | grep -o "[0-9]\{4,5\}" | sort | uniq -c | awk '$1 > 1 {print $2}')
    if [[ -n "$ports" ]]; then
        print_warning "Duplicate port configurations found: $ports"
        conflicts=$((conflicts + 1))
    fi
    
    if [[ $conflicts -eq 0 ]]; then
        print_success "No configuration conflicts found"
    fi
}

# Function to update .gitignore
update_gitignore() {
    print_status "Updating .gitignore..."
    
    local gitignore="$PROJECT_ROOT/.gitignore"
    
    # Add additional patterns if not already present
    local new_patterns=(
        "# Temporary files created by scripts"
        "tmp_rovodev_*"
        "*.backup"
        "security-audit-report.txt"
        "legacy-backup-*.tar.gz"
        ""
        "# Runtime data"
        "*.pid"
        "*.sock"
        ""
        "# Coverage and testing"
        "coverage/"
        ".coverage"
        ".pytest_cache/"
        ""
        "# Environment files"
        ".env"
        ".env.local"
        ".env.*.local"
    )
    
    for pattern in "${new_patterns[@]}"; do
        if ! grep -Fxq "$pattern" "$gitignore" 2>/dev/null; then
            echo "$pattern" >> "$gitignore"
        fi
    done
    
    print_success "Updated .gitignore with additional patterns"
}

# Function to create migration guide
create_migration_guide() {
    local migration_guide="$PROJECT_ROOT/MIGRATION-GUIDE.md"
    
    print_status "Creating migration guide..."
    
    cat > "$migration_guide" << 'EOF'
# Migration Guide: Legacy to Unified Architecture

This guide helps migrate from legacy deployment methods to the new unified architecture.

## Overview of Changes

### 1. Configuration System
- **Old**: Hardcoded values scattered across files
- **New**: Centralized configuration in `config/` directory
- **Action**: Use `.env` file and YAML configs

### 2. Network Configuration
- **Old**: Hardcoded IP addresses (192.168.1.x)
- **New**: Dynamic network detection and configuration
- **Action**: Set `HOMELAB_DEFAULT_SUBNET` in environment

### 3. Service Deployment
- **Old**: Multiple deployment scripts with different patterns
- **New**: Unified `deploy-stack.sh` with profiles
- **Action**: Use `--profile` parameter for specific deployments

### 4. VM Management
- **Old**: Manual VM creation and configuration
- **New**: Standardized `create-vm.sh` with types
- **Action**: Use `--type hybrid` for most deployments

## Migration Steps

### Step 1: Backup Current Setup
```bash
# Create backup of current configuration
tar -czf homelab-backup-$(date +%Y%m%d).tar.gz .

# Export current VM configurations
qm config <vmid> > vm-<vmid>-backup.conf
```

### Step 2: Update Configuration
```bash
# Copy environment template
cp .env.template .env

# Edit .env with your network settings
nano .env
```

### Step 3: Migrate Services
```bash
# Stop old services
docker-compose down

# Deploy with new unified stack
./deploy/deploy-stack.sh --vmid <vmid> --profile full
```

### Step 4: Verify Migration
```bash
# Check service status
./deploy/service-discovery.sh --health-check --vmid <vmid>

# Run integration tests
./scripts/integration-check.sh --vmid <vmid>
```

## Troubleshooting Migration Issues

### Network Connectivity Issues
```bash
# Run network troubleshooting
./scripts/troubleshoot-vm-network.sh --vmid <vmid> --fix
```

### Service Discovery Problems
```bash
# Check service registration
./deploy/service-discovery.sh --status --vmid <vmid>
```

### Configuration Conflicts
```bash
# Run security audit
./scripts/security-audit.sh

# Check for hardcoded values
grep -r "192.168.1" . --exclude-dir=archive
```

## Legacy File Mapping

| Legacy File | New Location | Notes |
|-------------|--------------|-------|
| `old-deploy.sh` | `deploy/deploy-stack.sh` | Use `--profile` parameter |
| `vm-create.sh` | `deploy/create-vm.sh` | Use `--type` parameter |
| `config.json` | `config/homelab-config.yaml` | YAML format |
| `network-setup.sh` | `scripts/utils/vm-network-utils.sh` | Shared utilities |

## Rollback Procedure

If migration fails, you can rollback:

```bash
# Stop new services
./deploy/deploy-stack.sh --rollback --vmid <vmid>

# Restore from backup
tar -xzf homelab-backup-<date>.tar.gz

# Restore VM configuration
qm set <vmid> --delete all
qm importovf <vmid> vm-<vmid>-backup.conf
```

## Post-Migration Cleanup

After successful migration:

```bash
# Archive legacy files
./scripts/cleanup-legacy.sh

# Remove temporary files
rm -f tmp_rovodev_*

# Update documentation
git add .
git commit -m "Migrated to unified architecture"
```

## Support

For migration issues:
1. Check the troubleshooting guide: `docs/TROUBLESHOOTING.md`
2. Run diagnostic scripts in `scripts/` directory
3. Review logs in `deployment.log`
EOF

    print_success "Created migration guide: $migration_guide"
}

# Function to create comprehensive test suite
create_test_suite() {
    local test_dir="$PROJECT_ROOT/tests"
    mkdir -p "$test_dir"
    
    print_status "Creating test suite..."
    
    # Create basic test runner
    cat > "$test_dir/run-tests.sh" << 'EOF'
#!/bin/bash
# Test Suite Runner for ProxMox Homelab Stack

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_test() { echo -e "${BLUE}[TEST]${NC} $1"; }
print_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }
print_fail() { echo -e "${RED}[FAIL]${NC} $1"; }

# Test configuration loading
test_config_loading() {
    print_test "Testing configuration loading..."
    
    if [[ -f "$PROJECT_ROOT/scripts/utils/config-loader.sh" ]]; then
        source "$PROJECT_ROOT/scripts/utils/config-loader.sh"
        if [[ ${#CONFIG[@]} -gt 0 ]]; then
            print_pass "Configuration loading works"
            return 0
        fi
    fi
    
    print_fail "Configuration loading failed"
    return 1
}

# Test script syntax
test_script_syntax() {
    print_test "Testing script syntax..."
    
    local errors=0
    find "$PROJECT_ROOT" -name "*.sh" -type f | while read -r script; do
        if ! bash -n "$script" 2>/dev/null; then
            print_fail "Syntax error in $script"
            errors=$((errors + 1))
        fi
    done
    
    if [[ $errors -eq 0 ]]; then
        print_pass "All scripts have valid syntax"
        return 0
    else
        print_fail "Found $errors scripts with syntax errors"
        return 1
    fi
}

# Test Docker Compose validity
test_docker_compose() {
    print_test "Testing Docker Compose configuration..."
    
    local compose_file="$PROJECT_ROOT/docker/docker-compose.yaml"
    if [[ -f "$compose_file" ]]; then
        if docker-compose -f "$compose_file" config >/dev/null 2>&1; then
            print_pass "Docker Compose configuration is valid"
            return 0
        fi
    fi
    
    print_fail "Docker Compose configuration is invalid"
    return 1
}

# Run all tests
main() {
    echo "Running ProxMox Homelab Test Suite..."
    echo "====================================="
    
    local total_tests=0
    local passed_tests=0
    
    for test_func in test_config_loading test_script_syntax test_docker_compose; do
        total_tests=$((total_tests + 1))
        if $test_func; then
            passed_tests=$((passed_tests + 1))
        fi
        echo ""
    done
    
    echo "====================================="
    echo "Tests passed: $passed_tests/$total_tests"
    
    if [[ $passed_tests -eq $total_tests ]]; then
        print_pass "All tests passed!"
        exit 0
    else
        print_fail "Some tests failed"
        exit 1
    fi
}

main "$@"
EOF

    chmod +x "$test_dir/run-tests.sh"
    print_success "Created test suite: $test_dir/run-tests.sh"
}

# Main execution
main() {
    print_status "Starting legacy cleanup process..."
    
    archive_legacy_files
    identify_duplicates
    consolidate_configs
    update_gitignore
    create_migration_guide
    create_test_suite
    
    print_success "Legacy cleanup completed!"
    print_status "Next steps:"
    echo "1. Review the migration guide: MIGRATION-GUIDE.md"
    echo "2. Run tests: ./tests/run-tests.sh"
    echo "3. Archive old files if everything works correctly"
    echo "4. Update documentation and commit changes"
}

# Run main function
main "$@"