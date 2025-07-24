# ProxMox VM TimeShift - GitHub Copilot Instructions

## Project Overview

ProxMox_VM_TimeShift is a comprehensive homelab automation solution for ProxMox VE that provides unified deployment and management of multiple services. The project emphasizes standardization, security, and operational efficiency through containerized microservices architecture.

## Core Architecture Principles

### Service Organization
- **Microservices Architecture**: Each service runs as an isolated Docker container
- **Standardized Port Allocation**: Services organized by functional category
- **VMID Management**: Structured ranges for different deployment types
- **Network Isolation**: Services communicate through dedicated Docker networks
- **Security Hardening**: Containers run with minimal privileges and resource constraints

### Port Allocation Standards (CRITICAL - Always Follow)
```
7001-7010: MCP Services (Context7, Desktop Commander, Filesystem)
8080-8090: iDRAC Management Services (Web Dashboard, WebSocket)
8090-8099: Time-Shift Proxy Services (SSL Certificate Manipulation)
9000-9010: Monitoring Services (Discovery, Health Checks, Dashboard)
```

### VMID Ranges (ProxMox VE)
```
200-209: MCP Server Stack
210-219: iDRAC Management
220-229: Hybrid Stack (RECOMMENDED for most deployments)
230-239: Time-Shift Proxy
240-249: Monitoring Services
```

## Development Standards

### Docker & Containerization
- Use the standardized Docker Compose template with security hardening
- Include resource limits, security options, and health checks
- Follow the common variable patterns (x-common-variables, x-security-settings)
- Maintain read-only root filesystems where possible
- Use multi-stage builds for efficiency

### Configuration Management
- Use environment variables for all configurable parameters
- Store configuration in `config/homelab-config.yaml`
- Validate configurations using the provided Python validation script
- Follow the naming convention: SERVICE_PARAMETER format

### Deployment Scripts
- Use bash with `set -e` for error handling
- Include colored output functions (print_status, print_success, etc.)
- Implement comprehensive logging to deployment.log
- Provide rollback capabilities for all deployments
- Support dry-run mode for testing

### Security Requirements
- Never commit credentials or API keys
- Use Docker secrets or environment variables for sensitive data
- Implement principle of least privilege in container configurations
- Regular security audits using the provided security-audit.sh script
- Network isolation between service categories

## Code Style Guidelines

### Bash Scripts
- Use descriptive function names with snake_case
- Include comprehensive error handling and validation
- Provide usage instructions and examples
- Use the established color scheme for output
- Log all significant operations

### Python Code
- Follow PEP 8 style guidelines
- Use type hints for function parameters and return values
- Include comprehensive error handling
- Validate all input parameters
- Use logging instead of print statements

### YAML Configuration
- Use 2-space indentation consistently
- Include comments for complex configurations
- Group related services logically
- Use anchors and aliases to reduce duplication
- Validate with yamllint before committing

## File Organization

### Directory Structure
```
deploy/          # Deployment automation scripts
docker/          # Docker Compose and service definitions
config/          # Configuration files and templates
scripts/         # Utility and maintenance scripts
docs/           # Documentation (avoid docs/archive for new content)
```

### Naming Conventions
- Scripts: kebab-case with .sh extension
- Configs: descriptive names with appropriate extensions
- Services: lowercase with hyphens in Docker Compose
- Functions: snake_case for bash, camelCase for Python

## Testing and Validation

### Required Checks
- Run comprehensive-validation.sh before major deployments
- Test health checks for all services
- Validate YAML syntax with yamllint
- Perform security audits for new containers
- Test rollback functionality

### Integration Testing
- Use integration-check.sh for full stack validation
- Test network connectivity between services
- Verify service discovery mechanisms
- Validate monitoring and alerting

## Documentation Standards

### Code Documentation
- Include clear function descriptions and parameters
- Provide usage examples for scripts and tools
- Document configuration options and defaults
- Maintain up-to-date README files for each service

### Operational Documentation
- Update DEPLOYMENT-GUIDE.md for deployment changes
- Maintain TROUBLESHOOTING.md for common issues
- Document configuration changes in appropriate guides
- Keep CHANGELOG.md current with version updates

## Common Tasks and Patterns

### Adding New Services
1. Follow the port allocation standards
2. Use the Docker Compose security template
3. Add health checks and monitoring
4. Update service discovery configuration
5. Document the service thoroughly

### Configuration Changes
1. Update homelab-config.yaml template
2. Add environment variable validation
3. Test with comprehensive-validation.sh
4. Document changes in appropriate guides

### Script Development
1. Use the established script template
2. Include comprehensive error handling
3. Add logging and dry-run capabilities
4. Test with various input scenarios

## Integration Points

### Service Discovery
- Register all services with the discovery mechanism
- Implement health check endpoints
- Use standardized service metadata format
- Support dynamic configuration updates

### Monitoring Integration
- Expose metrics endpoints where applicable
- Use consistent logging formats
- Implement proper alerting thresholds
- Support central log aggregation

### Network Configuration
- Use the homelab-network for service communication
- Implement proper firewall rules
- Support both internal and external access patterns
- Document network dependencies clearly

## Anti-Patterns to Avoid

- Hardcoding IP addresses or hostnames
- Using non-standard port ranges
- Skipping security hardening in containers
- Committing sensitive configuration data
- Bypassing the established deployment workflows
- Creating services without health checks
- Ignoring the VMID allocation standards
- Using deprecated archive documentation as reference

## Version Control Practices

- Use meaningful commit messages describing the impact
- Update documentation with code changes
- Test deployment scripts before committing
- Use feature branches for significant changes
- Tag releases appropriately

Remember: This project prioritizes operational reliability and security. Always follow established patterns and validate changes thoroughly before deployment.