---
applyTo:
  - "deploy/**"
  - "scripts/**"
  - "**/*deploy*.sh"
  - "**/*deployment*.sh"
---

# Deployment Scripts Instructions

## Script Standards

### Error Handling
All deployment scripts MUST include:
```bash
set -e  # Exit on any error
set -u  # Exit on undefined variables
set -o pipefail  # Fail on pipe errors
```

### Logging Framework
Use the established logging functions:
```bash
print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() { echo -e "${CYAN}=== $1 ===${NC}"; }
print_step() { echo -e "${PURPLE}[STEP]${NC} $1"; }
```

### Required Features
Every deployment script must support:
- `--dry-run` mode for testing
- `--force` flag for re-deployment
- `--rollback` capability
- Comprehensive logging to deployment.log
- Input validation and help text

## Deployment Patterns

### VM Creation (create-vm.sh)
- Validate VMID ranges before creation
- Support different VM types: mcp, idrac, timeshift, hybrid
- Include resource customization options
- Verify ProxMox connectivity before proceeding

### Service Deployment (deploy-stack.sh)
- Support profile-based deployments
- Validate target environment before deployment
- Create backup points before major changes
- Test service health after deployment

### Service Discovery (service-discovery.sh)
- Automatic service registration
- Health check monitoring
- Support for watch mode with intervals
- Status reporting capabilities

## VMID Management

### Allocation Rules
- 200-209: MCP Server Stack
- 210-219: iDRAC Management  
- 220-229: Hybrid Stack (RECOMMENDED)
- 230-239: Time-Shift Proxy
- 240-249: Monitoring Services

### Validation
Always validate VMID before use:
```bash
validate_vmid() {
    local vmid=$1
    if [[ $vmid -lt 200 || $vmid -gt 249 ]]; then
        print_error "VMID $vmid outside approved range (200-249)"
        exit 1
    fi
}
```

## Configuration Validation

### Pre-deployment Checks
- Verify all required configuration files exist
- Validate YAML syntax
- Check environment variable definitions
- Confirm network connectivity requirements

### Post-deployment Verification
- Test service health endpoints
- Verify network connectivity between services
- Check log output for errors
- Validate monitoring integration

## Rollback Procedures

### Backup Strategy
- Create configuration snapshots before changes
- Store container state information
- Maintain deployment history logs
- Support point-in-time recovery

### Rollback Implementation
```bash
perform_rollback() {
    print_header "PERFORMING ROLLBACK"
    docker-compose -f "$COMPOSE_FILE" down
    restore_configuration_backup
    docker-compose -f "$COMPOSE_FILE" up -d
    verify_service_health
}
```

## Remote Deployment Support

### SSH Key Management
- Validate SSH connectivity before deployment
- Support key-based authentication
- Handle connection timeouts gracefully

### Target Environment Preparation
- Install required dependencies
- Configure firewall rules
- Set up monitoring agents
- Validate system resources

## Integration Testing

### Service Health Validation
```bash
test_service_health() {
    local service_url=$1
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -f "$service_url/health" >/dev/null 2>&1; then
            print_success "Service health check passed"
            return 0
        fi
        sleep 2
        ((attempt++))
    done
    
    print_error "Service health check failed after $max_attempts attempts"
    return 1
}
```

## Error Recovery

### Common Failure Scenarios
- Network connectivity issues
- Resource constraints
- Configuration errors
- Service startup failures

### Recovery Strategies
- Automatic retry with exponential backoff
- Graceful degradation for non-critical services
- Detailed error reporting with remediation hints
- Support for manual intervention points

## Documentation Requirements

### Script Headers
Include comprehensive documentation:
```bash
#!/bin/bash
# Script Name: Purpose and description
# Usage: ./script.sh [options]
# Examples: Specific usage examples
# Dependencies: Required tools and configurations
```

### Parameter Documentation
- Document all command-line options
- Provide usage examples
- Include default values and valid ranges
- Explain interaction with other services