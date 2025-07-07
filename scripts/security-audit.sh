#!/bin/bash
# Security Audit Script
# Identifies and fixes security issues across the codebase

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

# Function to check for sensitive information
check_sensitive_info() {
    print_status "Checking for sensitive information..."
    
    local issues=0
    
    # Check for potential passwords, keys, tokens
    local sensitive_patterns=(
        "password.*="
        "passwd.*="
        "secret.*="
        "token.*="
        "key.*="
        "api_key.*="
        "private.*key"
    )
    
    for pattern in "${sensitive_patterns[@]}"; do
        local matches=$(grep -r -i "$pattern" "$PROJECT_ROOT" --exclude-dir=.git --exclude-dir=archive 2>/dev/null | grep -v ".md:" | grep -v "template" | grep -v "example" || true)
        if [[ -n "$matches" ]]; then
            print_warning "Found potential sensitive information pattern: $pattern"
            echo "$matches"
            issues=$((issues + 1))
        fi
    done
    
    if [[ $issues -eq 0 ]]; then
        print_success "No obvious sensitive information found"
    else
        print_warning "Found $issues potential sensitive information patterns"
    fi
    
    return $issues
}

# Function to check file permissions
check_file_permissions() {
    print_status "Checking file permissions..."
    
    local issues=0
    
    # Check for overly permissive files
    local world_writable=$(find "$PROJECT_ROOT" -type f -perm -002 2>/dev/null | grep -v ".git" || true)
    if [[ -n "$world_writable" ]]; then
        print_warning "Found world-writable files:"
        echo "$world_writable"
        issues=$((issues + 1))
    fi
    
    # Check for executable files that shouldn't be
    local suspicious_exec=$(find "$PROJECT_ROOT" -name "*.json" -o -name "*.yaml" -o -name "*.yml" -o -name "*.md" | xargs ls -l | grep "^-rwxr" || true)
    if [[ -n "$suspicious_exec" ]]; then
        print_warning "Found executable non-script files:"
        echo "$suspicious_exec"
        issues=$((issues + 1))
    fi
    
    if [[ $issues -eq 0 ]]; then
        print_success "File permissions look good"
    fi
    
    return $issues
}

# Function to check for insecure network configurations
check_network_security() {
    print_status "Checking network security configurations..."
    
    local issues=0
    
    # Check for wildcard CORS
    local wildcard_cors=$(grep -r "allowed_origins.*\*\|cors.*\*" "$PROJECT_ROOT" --exclude-dir=.git 2>/dev/null || true)
    if [[ -n "$wildcard_cors" ]]; then
        print_warning "Found wildcard CORS configurations:"
        echo "$wildcard_cors"
        issues=$((issues + 1))
    fi
    
    # Check for insecure bind addresses in production
    local insecure_bind=$(grep -r "0\.0\.0\.0" "$PROJECT_ROOT/docker" 2>/dev/null | grep -v "comment\|#" || true)
    if [[ -n "$insecure_bind" ]]; then
        print_warning "Found 0.0.0.0 bind addresses (review for production use):"
        echo "$insecure_bind"
    fi
    
    if [[ $issues -eq 0 ]]; then
        print_success "Network security configurations look good"
    fi
    
    return $issues
}

# Function to check for command injection vulnerabilities
check_command_injection() {
    print_status "Checking for potential command injection vulnerabilities..."
    
    local issues=0
    
    # Check for unquoted variables in shell commands
    local shell_files=$(find "$PROJECT_ROOT" -name "*.sh" -type f | grep -v archive)
    
    for file in $shell_files; do
        # Look for potentially dangerous patterns
        local dangerous=$(grep -n '\$[A-Za-z_][A-Za-z0-9_]*[^"]' "$file" | grep -E '(eval|exec|system|`|\$\()' || true)
        if [[ -n "$dangerous" ]]; then
            print_warning "Potential command injection in $file:"
            echo "$dangerous"
            issues=$((issues + 1))
        fi
    done
    
    if [[ $issues -eq 0 ]]; then
        print_success "No obvious command injection vulnerabilities found"
    fi
    
    return $issues
}

# Function to fix common security issues
fix_security_issues() {
    print_status "Applying security fixes..."
    
    # Fix file permissions
    print_status "Fixing file permissions..."
    
    # Remove execute permissions from non-script files
    find "$PROJECT_ROOT" -name "*.json" -o -name "*.yaml" -o -name "*.yml" -o -name "*.md" | xargs chmod -x 2>/dev/null || true
    
    # Ensure scripts are executable
    find "$PROJECT_ROOT" -name "*.sh" -type f | xargs chmod +x 2>/dev/null || true
    
    # Fix world-writable files
    find "$PROJECT_ROOT" -type f -perm -002 -exec chmod o-w {} \; 2>/dev/null || true
    
    print_success "Fixed file permissions"
    
    # Create security configuration
    create_security_config
}

# Function to create security configuration
create_security_config() {
    local security_config="$PROJECT_ROOT/config/security-config.yaml"
    
    print_status "Creating security configuration..."
    
    cat > "$security_config" << 'EOF'
# Security Configuration for ProxMox Homelab Stack
security:
  # Authentication settings
  authentication:
    enabled: false
    type: "none"  # none, basic, oauth, ldap
    session_timeout: 3600
    
  # Authorization settings
  authorization:
    enabled: false
    default_role: "user"
    admin_users: []
    
  # Network security
  network:
    # Allowed source networks (CIDR notation)
    allowed_networks:
      - "192.168.1.0/24"
      - "127.0.0.1/32"
    
    # Rate limiting
    rate_limiting:
      enabled: true
      requests_per_minute: 60
      burst_size: 10
    
    # CORS settings
    cors:
      strict_mode: true
      max_age: 3600
      
  # SSL/TLS settings
  tls:
    enabled: false
    min_version: "1.2"
    cert_path: "/opt/homelab/certs"
    auto_generate_certs: true
    
  # Input validation
  input_validation:
    max_request_size: "1MB"
    allowed_file_types: [".json", ".yaml", ".yml", ".txt"]
    sanitize_inputs: true
    
  # Logging and monitoring
  logging:
    security_events: true
    failed_auth_attempts: true
    suspicious_activity: true
    log_retention_days: 30
    
  # Command execution security
  command_execution:
    timeout_seconds: 30
    allowed_commands: []  # Empty means all allowed
    sanitize_arguments: true
    
# Environment-specific overrides
environments:
  development:
    security:
      authentication:
        enabled: false
      network:
        allowed_networks: ["192.168.1.0/24"]
      cors:
        strict_mode: false
        
  production:
    security:
      authentication:
        enabled: true
      network:
        allowed_networks: ["192.168.1.0/24"]
      cors:
        strict_mode: true
      tls:
        enabled: true
EOF

    print_success "Created security configuration: $security_config"
}

# Function to generate security report
generate_security_report() {
    local report_file="$PROJECT_ROOT/security-audit-report.txt"
    
    print_status "Generating security audit report..."
    
    {
        echo "ProxMox Homelab Security Audit Report"
        echo "Generated: $(date)"
        echo "========================================"
        echo ""
        
        echo "1. Sensitive Information Check:"
        check_sensitive_info 2>&1 | grep -v "^\[" || echo "No issues found"
        echo ""
        
        echo "2. File Permissions Check:"
        check_file_permissions 2>&1 | grep -v "^\[" || echo "No issues found"
        echo ""
        
        echo "3. Network Security Check:"
        check_network_security 2>&1 | grep -v "^\[" || echo "No issues found"
        echo ""
        
        echo "4. Command Injection Check:"
        check_command_injection 2>&1 | grep -v "^\[" || echo "No issues found"
        echo ""
        
        echo "5. Recommendations:"
        echo "- Enable authentication in production environments"
        echo "- Use HTTPS/TLS for all external communications"
        echo "- Regularly update dependencies and base images"
        echo "- Implement network segmentation"
        echo "- Monitor logs for suspicious activity"
        echo "- Regular security audits and penetration testing"
        
    } > "$report_file"
    
    print_success "Security audit report generated: $report_file"
}

# Main execution
main() {
    print_status "Starting security audit..."
    
    local total_issues=0
    
    check_sensitive_info
    total_issues=$((total_issues + $?))
    
    check_file_permissions
    total_issues=$((total_issues + $?))
    
    check_network_security
    total_issues=$((total_issues + $?))
    
    check_command_injection
    total_issues=$((total_issues + $?))
    
    fix_security_issues
    generate_security_report
    
    if [[ $total_issues -eq 0 ]]; then
        print_success "Security audit completed with no critical issues found"
    else
        print_warning "Security audit completed with $total_issues issues found"
        print_status "Review the security audit report for details"
    fi
    
    print_status "Security audit complete!"
}

# Run main function
main "$@"