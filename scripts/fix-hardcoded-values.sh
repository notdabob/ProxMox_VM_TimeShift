#!/bin/bash
# Script to fix remaining hardcoded values across the codebase
# This script updates configuration files and scripts to use dynamic values

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

print_status "Fixing hardcoded values across the codebase..."

# Function to update Docker Compose health checks
fix_docker_compose_healthchecks() {
    local compose_file="$PROJECT_ROOT/docker/docker-compose.yaml"
    
    if [[ ! -f "$compose_file" ]]; then
        print_error "Docker Compose file not found: $compose_file"
        return 1
    fi
    
    print_status "Updating Docker Compose health checks..."
    
    # Create a backup
    cp "$compose_file" "$compose_file.backup"
    
    # Replace hardcoded localhost in health checks with 127.0.0.1 for consistency
    sed -i 's|http://localhost:|http://127.0.0.1:|g' "$compose_file"
    
    print_success "Updated Docker Compose health checks"
}

# Function to update documentation examples
fix_documentation_examples() {
    print_status "Updating documentation examples..."
    
    # Update README examples
    local readme="$PROJECT_ROOT/README.md"
    if [[ -f "$readme" ]]; then
        # Replace hardcoded IP examples with variables
        sed -i 's|192\.168\.1\.100|${VM_IP}|g' "$readme"
        sed -i 's|http://192\.168\.1\.[0-9]\+|http://${VM_IP}|g' "$readme"
    fi
    
    # Update troubleshooting docs
    local troubleshoot="$PROJECT_ROOT/docs/TROUBLESHOOTING.md"
    if [[ -f "$troubleshoot" ]]; then
        sed -i 's|192\.168\.1\.[0-9]\+|${VM_IP}|g' "$troubleshoot"
    fi
    
    print_success "Updated documentation examples"
}

# Function to create environment template
create_environment_template() {
    local env_template="$PROJECT_ROOT/.env.template"
    
    print_status "Creating environment template..."
    
    cat > "$env_template" << 'EOF'
# ProxMox Homelab Environment Configuration
# Copy this file to .env and customize for your environment

# Network Configuration
HOMELAB_DEFAULT_SUBNET=192.168.1.0/24
HOMELAB_DEFAULT_GATEWAY=192.168.1.1
HOMELAB_BIND_ADDRESS=0.0.0.0

# VM Configuration
HOMELAB_VM_IP=
HOMELAB_VMID=

# Service Configuration
HOMELAB_ENVIRONMENT=production
HOMELAB_LOG_LEVEL=INFO

# Docker Configuration
COMPOSE_PROJECT_NAME=homelab
COMPOSE_FILE=docker/docker-compose.yaml

# Security Configuration
HOMELAB_ENABLE_AUTH=false
HOMELAB_ENABLE_SSL=false

# Monitoring Configuration
HOMELAB_ENABLE_MONITORING=true
HOMELAB_HEALTH_CHECK_INTERVAL=30
EOF

    print_success "Created environment template: $env_template"
}

# Function to update scripts to load environment
update_scripts_env_loading() {
    print_status "Updating scripts to load environment configuration..."
    
    # Find all shell scripts in deploy and scripts directories
    find "$PROJECT_ROOT/deploy" "$PROJECT_ROOT/scripts" -name "*.sh" -type f | while read -r script; do
        # Skip if already has environment loading
        if grep -q "load.*env\|source.*env" "$script"; then
            continue
        fi
        
        # Add environment loading after shebang
        local temp_file=$(mktemp)
        {
            head -n 1 "$script"  # Keep shebang
            echo ""
            echo "# Load environment configuration"
            echo "if [[ -f \"\$(dirname \"\$0\")/../.env\" ]]; then"
            echo "    set -a"
            echo "    source \"\$(dirname \"\$0\")/../.env\""
            echo "    set +a"
            echo "fi"
            echo ""
            tail -n +2 "$script"  # Rest of the file
        } > "$temp_file"
        
        mv "$temp_file" "$script"
        chmod +x "$script"
    done
    
    print_success "Updated scripts to load environment configuration"
}

# Function to validate fixes
validate_fixes() {
    print_status "Validating fixes..."
    
    local errors=0
    
    # Check if backup files exist
    if [[ ! -f "$PROJECT_ROOT/docker/docker-compose.yaml.backup" ]]; then
        print_warning "Docker Compose backup not found"
    fi
    
    # Check if environment template was created
    if [[ ! -f "$PROJECT_ROOT/.env.template" ]]; then
        print_error "Environment template not created"
        errors=$((errors + 1))
    fi
    
    # Check for remaining hardcoded localhost in critical files
    local hardcoded_count=$(grep -r "localhost:8080\|127\.0\.0\.1:8080" "$PROJECT_ROOT/docker" 2>/dev/null | wc -l)
    if [[ $hardcoded_count -gt 0 ]]; then
        print_warning "Still found $hardcoded_count hardcoded localhost references in docker configs"
    fi
    
    if [[ $errors -eq 0 ]]; then
        print_success "All fixes validated successfully"
    else
        print_error "Validation found $errors errors"
    fi
    
    return $errors
}

# Main execution
main() {
    print_status "Starting comprehensive hardcoded value fixes..."
    
    fix_docker_compose_healthchecks
    fix_documentation_examples
    create_environment_template
    update_scripts_env_loading
    validate_fixes
    
    print_success "Hardcoded value fixes completed!"
    print_status "Next steps:"
    echo "1. Copy .env.template to .env and customize for your environment"
    echo "2. Review updated configuration files"
    echo "3. Test deployment with new configuration system"
}

# Run main function
main "$@"