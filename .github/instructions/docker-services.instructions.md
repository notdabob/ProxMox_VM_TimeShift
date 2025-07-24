---
applyTo: 
  - "docker/**"
  - "**/Dockerfile"
  - "**/docker-compose*.yaml"
  - "**/docker-compose*.yml"
---

# Docker & Container Development Instructions

## Container Security Standards

### Mandatory Security Settings
```yaml
security_opt:
  - no-new-privileges:true
cap_drop:
  - ALL
cap_add:
  - NET_BIND_SERVICE  # Only if binding to privileged ports
read_only: true      # Prefer read-only root filesystem
tmpfs:
  - /tmp:noexec,nosuid,size=100m
  - /var/tmp:noexec,nosuid,size=50m
```

### Resource Management
- Always include CPU and memory limits
- Set appropriate reservations for critical services
- Use the standardized resource limit templates

### Health Checks
Every service MUST include a health check:
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:PORT/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

## Service Configuration Patterns

### Environment Variables
- Use descriptive names: `SERVICE_PARAMETER_NAME`
- Provide sensible defaults: `${PARAMETER:-default_value}`
- Group related variables using anchors

### Networking
- All services MUST use the `homelab-network`
- Use consistent internal port mapping
- Document external port exposure clearly

### Volume Management
- Use named volumes for persistent data
- Prefer bind mounts for configuration files
- Document volume purposes and data retention

## Port Allocation (CRITICAL)
Never deviate from the established port ranges:
- 7001-7010: MCP Services
- 8080-8090: iDRAC Services
- 8090-8099: Time-Shift Services  
- 9000-9010: Monitoring Services

## Container Naming
- Use lowercase with hyphens: `service-name`
- Include functional category: `mcp-context7`, `idrac-manager`
- Maintain consistency with existing services

## Image Standards
- Prefer official base images
- Use specific version tags, avoid `latest`
- Document any custom image requirements
- Include multi-architecture support where possible

## Development Workflow
1. Test locally with docker-compose up
2. Validate security settings
3. Test health check endpoints
4. Verify log output and formats
5. Test container restart scenarios