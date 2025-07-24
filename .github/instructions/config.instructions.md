---
applyTo:
  - "config/**"
  - "**/*config*.yaml"
  - "**/*config*.yml"
  - "**/.env*"
---

# Configuration Management Instructions

## Configuration File Standards

### YAML Structure
Use consistent formatting across all configuration files:
```yaml
# Use 2-space indentation
homelab:
  services:
    mcp:
      enabled: true
      port_range: "7001-7010"
```

### Environment Variables
Follow the naming convention:
```bash
# Format: SERVICE_CATEGORY_PARAMETER
MCP_CONTEXT7_DATABASE_PATH=/data/context7.db
IDRAC_MANAGER_API_PORT=8080
TIMESHIFT_PROXY_SSL_PORT=8090
MONITORING_DASHBOARD_PORT=9010
```

### Configuration Validation
All configuration changes must be validated:
```bash
# Use the provided validation script
python scripts/validate-config.py --config config/homelab-config.yaml
```

## Service Configuration Patterns

### Port Allocation
Maintain strict adherence to port ranges:
```yaml
port_allocations:
  mcp_services: "7001-7010"
  idrac_services: "8080-8090" 
  timeshift_services: "8090-8099"
  monitoring_services: "9000-9010"
```

### Network Configuration
Define network segments clearly:
```yaml
networks:
  homelab:
    external: false
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/16
```

### Resource Limits
Standardize resource allocation:
```yaml
resource_defaults:
  cpu_limit: "0.5"
  memory_limit: "512M"
  cpu_reservation: "0.25" 
  memory_reservation: "256M"
```

## Security Configuration

### Sensitive Data Handling
- Never commit credentials in configuration files
- Use environment variables for secrets
- Implement configuration encryption where needed
- Regular security audits of configuration files

### Access Control
```yaml
security:
  network_policies:
    mcp_isolation: true
    idrac_isolation: true
    monitoring_access: "restricted"
```

## Service Discovery Configuration

### Registration Format
Services must register with standardized metadata:
```yaml
service_registry:
  - name: "context7-mcp"
    category: "mcp"
    port: 7001
    health_endpoint: "/health"
    description: "SQLite context management service"
```

### Health Check Configuration
Define comprehensive health checks:
```yaml
health_checks:
  interval: 30
  timeout: 10
  retries: 3
  start_period: 40
```

## Environment-Specific Configuration

### Development Environment
```yaml
environment: development
logging:
  level: DEBUG
  output: console
resource_limits:
  enabled: false
```

### Production Environment  
```yaml
environment: production
logging:
  level: INFO
  output: file
  rotation: daily
security:
  hardened: true
  audit_enabled: true
```

## Configuration Templates

### Service Template
```yaml
services:
  service-name:
    image: "organization/service:version"
    environment:
      - SERVICE_CONFIG_PARAM=${SERVICE_CONFIG_PARAM:-default}
    ports:
      - "${SERVICE_PORT:-8080}:8080"
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
    networks:
      - homelab
```

### Volume Configuration
```yaml
volumes:
  service_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /opt/homelab/data/service
```

## Configuration Backup and Recovery

### Backup Strategy
- Automatic configuration backups before changes
- Version control for all configuration files
- Regular backup verification
- Point-in-time recovery capabilities

### Recovery Procedures
```bash
# Restore configuration from backup
restore_configuration() {
    local backup_timestamp=$1
    print_status "Restoring configuration from $backup_timestamp"
    cp "$BACKUP_DIR/config-$backup_timestamp.tar.gz" .
    tar -xzf "config-$backup_timestamp.tar.gz"
}
```

## Monitoring Configuration

### Metrics Collection
```yaml
monitoring:
  metrics:
    enabled: true
    interval: 30
    retention: "7d"
  alerts:
    enabled: true
    channels: ["email", "webhook"]
```

### Log Management
```yaml
logging:
  driver: "json-file"
  options:
    max-size: "10m"
    max-file: "3"
  centralized: true
  aggregation_endpoint: "http://log-aggregator:9020"
```

## Configuration Validation Rules

### Required Fields
- All services must define health check endpoints
- Port allocations must fall within approved ranges
- Resource limits must be specified for production
- Network configuration must include security policies

### Validation Checks
- YAML syntax validation
- Port conflict detection
- Resource constraint verification
- Network connectivity validation
- Security policy compliance

## Best Practices

### Documentation
- Comment complex configuration sections
- Provide examples for each configuration option
- Document dependencies between services
- Maintain configuration change logs

### Version Control
- Use meaningful commit messages for configuration changes
- Tag configuration versions with releases
- Maintain configuration documentation
- Review configuration changes through pull requests

### Testing
- Test configuration changes in development first
- Validate against multiple environment types
- Use automated configuration testing where possible
- Verify service integration after configuration changes