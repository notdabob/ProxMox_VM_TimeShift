#!/bin/bash
# Comprehensive Validation Script
# Validates all fixes and improvements across the codebase

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() { echo -e "${CYAN}=== $1 ===${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Validation results
declare -A VALIDATION_RESULTS

# Function to validate file structure
validate_file_structure() {
    print_header "Validating File Structure"
    
    local required_files=(
        "README.md"
        "docker/docker-compose.yaml"
        "deploy/deploy-stack.sh"
        "deploy/create-vm.sh"
        "config/homelab-config.yaml"
        "config/network-config.yaml"
        "scripts/utils/vm-network-utils.sh"
        "scripts/utils/config-loader.sh"
    )
    
    local missing_files=0
    
    for file in "${required_files[@]}"; do
        if [[ -f "$PROJECT_ROOT/$file" ]]; then
            print_success "✓ $file exists"
        else
            print_error "✗ $file missing"
            missing_files=$((missing_files + 1))
        fi
    done
    
    VALIDATION_RESULTS["file_structure"]=$missing_files
    
    if [[ $missing_files -eq 0 ]]; then
        print_success "All required files present"
    else
        print_error "$missing_files required files missing"
    fi
}

# Function to validate script syntax
validate_script_syntax() {
    print_header "Validating Script Syntax"
    
    local syntax_errors=0
    
    find "$PROJECT_ROOT" -name "*.sh" -type f | while read -r script; do
        if bash -n "$script" 2>/dev/null; then
            echo "✓ $(basename "$script")"
        else
            print_error "✗ Syntax error in $script"
            syntax_errors=$((syntax_errors + 1))
        fi
    done
    
    VALIDATION_RESULTS["script_syntax"]=$syntax_errors
    
    if [[ $syntax_errors -eq 0 ]]; then
        print_success "All scripts have valid syntax"
    fi
}

# Function to validate Python syntax
validate_python_syntax() {
    print_header "Validating Python Syntax"
    
    local python_errors=0
    
    find "$PROJECT_ROOT" -name "*.py" -type f | while read -r script; do
        if python3 -m py_compile "$script" 2>/dev/null; then
            echo "✓ $(basename "$script")"
        else
            print_error "✗ Syntax error in $script"
            python_errors=$((python_errors + 1))
        fi
    done
    
    VALIDATION_RESULTS["python_syntax"]=$python_errors
    
    if [[ $python_errors -eq 0 ]]; then
        print_success "All Python scripts have valid syntax"
    fi
}

# Function to validate configuration files
validate_configurations() {
    print_header "Validating Configuration Files"
    
    local config_errors=0
    
    # Validate YAML files
    find "$PROJECT_ROOT/config" -name "*.yaml" -o -name "*.yml" 2>/dev/null | while read -r yaml_file; do
        if python3 -c "import yaml; yaml.safe_load(open('$yaml_file'))" 2>/dev/null; then
            echo "✓ $(basename "$yaml_file")"
        else
            print_error "✗ Invalid YAML: $yaml_file"
            config_errors=$((config_errors + 1))
        fi
    done
    
    # Validate JSON files
    find "$PROJECT_ROOT" -name "*.json" -type f | while read -r json_file; do
        if python3 -c "import json; json.load(open('$json_file'))" 2>/dev/null; then
            echo "✓ $(basename "$json_file")"
        else
            print_error "✗ Invalid JSON: $json_file"
            config_errors=$((config_errors + 1))
        fi
    done
    
    VALIDATION_RESULTS["configurations"]=$config_errors
    
    if [[ $config_errors -eq 0 ]]; then
        print_success "All configuration files are valid"
    fi
}

# Function to validate Docker Compose
validate_docker_compose() {
    print_header "Validating Docker Compose"
    
    local compose_file="$PROJECT_ROOT/docker/docker-compose.yaml"
    
    if [[ -f "$compose_file" ]]; then
        if command -v docker-compose >/dev/null 2>&1; then
            if docker-compose -f "$compose_file" config >/dev/null 2>&1; then
                print_success "Docker Compose configuration is valid"
                VALIDATION_RESULTS["docker_compose"]=0
            else
                print_error "Docker Compose configuration has errors"
                VALIDATION_RESULTS["docker_compose"]=1
            fi
        else
            print_warning "docker-compose not available, skipping validation"
            VALIDATION_RESULTS["docker_compose"]=0
        fi
    else
        print_error "Docker Compose file not found"
        VALIDATION_RESULTS["docker_compose"]=1
    fi
}

# Function to check for hardcoded values
validate_no_hardcoded_values() {
    print_header "Checking for Hardcoded Values"
    
    local hardcoded_issues=0
    
    # Check for hardcoded IPs in critical files
    local critical_files=(
        "deploy/deploy-stack.sh"
        "deploy/create-vm.sh"
        "docker/docker-compose.yaml"
        "docker/services/idrac-manager/src/idrac-api-server.py"
    )
    
    for file in "${critical_files[@]}"; do
        if [[ -f "$PROJECT_ROOT/$file" ]]; then
            local hardcoded=$(grep -n "192\.168\.1\.[0-9]\+\|10\.0\.0\.[0-9]\+" "$PROJECT_ROOT/$file" | grep -v "example\|comment\|#" || true)
            if [[ -n "$hardcoded" ]]; then
                print_warning "Hardcoded IPs found in $file:"
                echo "$hardcoded"
                hardcoded_issues=$((hardcoded_issues + 1))
            else
                echo "✓ $file - no hardcoded IPs"
            fi
        fi
    done
    
    VALIDATION_RESULTS["hardcoded_values"]=$hardcoded_issues
    
    if [[ $hardcoded_issues -eq 0 ]]; then
        print_success "No critical hardcoded values found"
    fi
}

# Function to validate security improvements
validate_security_improvements() {
    print_header "Validating Security Improvements"
    
    local security_issues=0
    
    # Check for wildcard CORS
    local wildcard_cors=$(grep -r "allowed_origins.*\*" "$PROJECT_ROOT" --exclude-dir=archive 2>/dev/null || true)
    if [[ -n "$wildcard_cors" ]]; then
        print_warning "Wildcard CORS found (review for production):"
        echo "$wildcard_cors"
        security_issues=$((security_issues + 1))
    else
        print_success "No wildcard CORS configurations found"
    fi
    
    # Check for dynamic CORS configuration
    if grep -q "dynamic_origins.*true" "$PROJECT_ROOT/docker/services/idrac-manager/config/api-config.json" 2>/dev/null; then
        print_success "Dynamic CORS configuration enabled"
    else
        print_warning "Dynamic CORS configuration not found"
        security_issues=$((security_issues + 1))
    fi
    
    VALIDATION_RESULTS["security"]=$security_issues
}

# Function to validate shared utilities integration
validate_shared_utilities() {
    print_header "Validating Shared Utilities Integration"
    
    local integration_issues=0
    
    # Check if scripts source shared utilities
    local scripts_using_utils=$(grep -l "vm-network-utils.sh\|config-loader.sh" "$PROJECT_ROOT/deploy"/*.sh "$PROJECT_ROOT/scripts"/*.sh 2>/dev/null | wc -l)
    
    if [[ $scripts_using_utils -gt 0 ]]; then
        print_success "$scripts_using_utils scripts use shared utilities"
    else
        print_warning "No scripts found using shared utilities"
        integration_issues=$((integration_issues + 1))
    fi
    
    # Check if utility functions are available
    if [[ -f "$PROJECT_ROOT/scripts/utils/vm-network-utils.sh" ]]; then
        local util_functions=$(grep -c "^util_" "$PROJECT_ROOT/scripts/utils/vm-network-utils.sh" || echo "0")
        if [[ $util_functions -gt 0 ]]; then
            print_success "$util_functions utility functions available"
        else
            print_warning "No utility functions found"
            integration_issues=$((integration_issues + 1))
        fi
    fi
    
    VALIDATION_RESULTS["shared_utilities"]=$integration_issues
}

# Function to generate validation report
generate_validation_report() {
    print_header "Validation Summary"
    
    local total_issues=0
    local categories=0
    
    for category in "${!VALIDATION_RESULTS[@]}"; do
        local issues=${VALIDATION_RESULTS[$category]}
        total_issues=$((total_issues + issues))
        categories=$((categories + 1))
        
        if [[ $issues -eq 0 ]]; then
            print_success "$category: PASS"
        else
            print_warning "$category: $issues issues"
        fi
    done
    
    echo ""
    echo "Overall Results:"
    echo "Categories checked: $categories"
    echo "Total issues found: $total_issues"
    
    if [[ $total_issues -eq 0 ]]; then
        print_success "🎉 All validations passed! Codebase is ready for deployment."
    elif [[ $total_issues -lt 5 ]]; then
        print_warning "⚠️  Minor issues found. Review and fix before production deployment."
    else
        print_error "❌ Significant issues found. Address these before proceeding."
    fi
    
    # Create detailed report file
    local report_file="$PROJECT_ROOT/validation-report.txt"
    {
        echo "ProxMox Homelab Comprehensive Validation Report"
        echo "Generated: $(date)"
        echo "=============================================="
        echo ""
        
        for category in "${!VALIDATION_RESULTS[@]}"; do
            echo "$category: ${VALIDATION_RESULTS[$category]} issues"
        done
        
        echo ""
        echo "Total issues: $total_issues"
        echo "Status: $(if [[ $total_issues -eq 0 ]]; then echo "PASS"; else echo "NEEDS ATTENTION"; fi)"
        
    } > "$report_file"
    
    print_status "Detailed report saved to: $report_file"
}

# Main execution
main() {
    print_header "ProxMox Homelab Comprehensive Validation"
    print_status "Starting comprehensive validation of all fixes and improvements..."
    echo ""
    
    validate_file_structure
    echo ""
    
    validate_script_syntax
    echo ""
    
    validate_python_syntax
    echo ""
    
    validate_configurations
    echo ""
    
    validate_docker_compose
    echo ""
    
    validate_no_hardcoded_values
    echo ""
    
    validate_security_improvements
    echo ""
    
    validate_shared_utilities
    echo ""
    
    generate_validation_report
}

# Run main function
main "$@"