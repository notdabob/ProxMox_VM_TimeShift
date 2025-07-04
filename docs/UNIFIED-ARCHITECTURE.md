# ProxMox VM TimeShift - Unified Architecture Documentation

## Overview

This document describes the unified architecture for the ProxMox VM TimeShift project after consolidation and cleanup. The unified approach provides a standardized, consistent deployment model for homelab services on ProxMox VE.

## Architecture Principles

### 1. Service Containerization
All services run as Docker containers for:
- Portability across different ProxMox nodes
- Resource isolation and management
- Easy updates and rollbacks
- Consistent deployment patterns

### 2. Standardized Port Allocation
Services are organized into logical port ranges:
```
7001-7010: MCP (Model Context Protocol) Services
8080-8090: iDRAC and Server Management Services  
8090-8099: Time-Shift and Proxy Services
9000-9010: Monitoring and Dashboard Services
```

### 3. Profile-Based Deployment
Five deployment profiles for different use cases:
- **mcp**: MCP server stack only
- **idrac**: iDRAC management only  
- **timeshift**: Time-shift proxy only
- **monitoring**: Monitoring services only
- **full**: Complete homelab stack (recommended)

### 4. Standardized VMID Ranges
```
200-209: MCP Server Stack
210-219: iDRAC Management
220-229: Hybrid Stack (Recommended)
230-239: Time-Shift Proxy
240-249: Monitoring Services
```

## Core Components

### 1. MCP Services Stack (Ports 7001-7003)

#### Context7 MCP (Port 7001)
- SQLite-based context management
- Provides persistent storage for AI/ML contexts
- Volume: `context7_data`

#### Desktop Commander (Port 7002)
- System control and automation capabilities
- Docker socket access for container management
- Volume: `desktop_commander_data`

#### Filesystem MCP (Port 7003)
- Secure file system access service
- Workspace management
- Volume: `filesystem_mcp_config`

### 2. iDRAC Management Service (Ports 8080, 8765)

#### Web Dashboard (Port 8080)
- Browser-based interface for server management
- Auto-discovery of network servers
- Support for multiple server types:
  - Dell iDRAC
  - ProxMox hosts
  - Linux servers (SSH)
  - Windows servers (RDP)
  - VNC servers

#### API Server (Port 8765)
- RESTful API for programmatic access
- SSH key management
- Remote Desktop Manager (RDM) export

### 3. Time-Shift Proxy Service (Port 8090)

- SSL certificate time manipulation proxy
- Allows access to systems with expired certificates
- Configuration-based time shifting
- Volume: `timeshift_config`

### 4. Monitoring Stack (Ports 9000-9010)

#### Service Discovery (Port 9000)
- Automatic service registration
- Health check coordination
- Service metadata management

#### Health Monitor (Port 9001)
- Real-time health monitoring
- Alert generation
- Performance metrics

#### Unified Dashboard (Port 9010)
- Central management interface
- Service status overview
- Quick access to all services

## Deployment Architecture

### VM Creation Flow
```
create-vm.sh
    ├── Debian 12 base image
    ├── Docker CE installation
    ├── Network configuration
    ├── Type-specific packages
    └── VMID assignment
```

### Service Deployment Flow
```
deploy-stack.sh
    ├── Backup existing services
    ├── Deploy docker-compose.yaml
    ├── Configure profiles
    ├── Start services
    └── Register with discovery
```

### Service Discovery Flow
```
service-discovery.sh
    ├── Scan Docker containers
    ├── Extract service metadata
    ├── Perform health checks
    ├── Update registry
    └── Generate dashboard data
```

## Network Architecture

### Docker Network
- Network name: `homelab-network`
- Type: Bridge network
- Provides container-to-container communication
- Isolates services from host network

### Service Communication
```
┌─────────────────┐     ┌──────────────────┐
│ Unified Dashboard│────▶│ Service Discovery │
└─────────────────┘     └──────────────────┘
         │                        │
         ▼                        ▼
┌─────────────────┐     ┌──────────────────┐
│  Health Monitor │────▶│   All Services   │
└─────────────────┘     └──────────────────┘
```

### External Access
- Services exposed on VM's primary network interface
- Port forwarding handled by Docker
- Optional: Nginx reverse proxy for SSL termination

## Data Management

### Persistent Volumes
Each service maintains its own data volume:
```
context7_data         - Context7 MCP data
desktop_commander_data - Desktop Commander data
filesystem_mcp_config - Filesystem MCP configuration
idrac_data           - iDRAC discovery data
idrac_logs           - iDRAC service logs
timeshift_config     - Time-shift configurations
timeshift_logs       - Time-shift logs
monitoring_data      - Service discovery registry
shared_workspace     - Shared workspace (read-only for most)
```

### Backup Strategy
1. Pre-deployment backups automatically created
2. Volume data preserved during updates
3. Rollback capability to previous deployment

## Security Considerations

### Container Security
- Non-root user execution where possible
- Read-only root filesystems
- Capability restrictions
- Network isolation

### Access Control
- Service-specific authentication
- API key management for services
- SSH key management for server access

### Network Security
- Internal services not exposed externally
- Reverse proxy for SSL termination
- Service-to-service authentication

## Operational Workflows

### Initial Deployment
```bash
# 1. Create VM
./deploy/create-vm.sh --type hybrid

# 2. Deploy services
./deploy/deploy-stack.sh --vmid 220 --profile full

# 3. Verify deployment
./deploy/service-discovery.sh --health-check --vmid 220
```

### Service Updates
```bash
# 1. Pull latest images
docker-compose pull

# 2. Redeploy with backup
./deploy/deploy-stack.sh --vmid 220 --profile full

# 3. Verify services
./deploy/service-discovery.sh --status --vmid 220
```

### Monitoring
```bash
# Continuous monitoring
./deploy/service-discovery.sh --watch --vmid 220 --interval 30

# Access unified dashboard
http://<VM_IP>:9010
```

### Troubleshooting
```bash
# View service logs
docker-compose logs -f [service-name]

# Check service health
./deploy/service-discovery.sh --health-check --vmid 220

# Rollback if needed
./deploy/deploy-stack.sh --vmid 220 --rollback
```

## Migration from Legacy

### From Separate Deployments
1. Identify existing services and their data
2. Create new unified VM
3. Deploy unified stack
4. Migrate data volumes
5. Update DNS/network references
6. Decommission old services

### From Nested Implementations
1. Run `reorganize-codebase.sh` to clean structure
2. Update configuration files
3. Test deployment with new paths
4. Archive legacy components

## Future Enhancements

### Planned Features
1. **Multi-node deployment** - Distribute services across multiple VMs
2. **External service discovery** - Support for non-containerized services
3. **Enhanced monitoring** - Prometheus/Grafana integration
4. **Automated backups** - Scheduled backup to external storage
5. **GitOps integration** - Automated deployment from Git

### Extension Points
- Custom service profiles in `homelab-config.yaml`
- Additional services in `docker-compose.yaml`
- Custom health checks in monitoring stack
- Plugin system for dashboard

## Best Practices

### Development
1. Test changes in development environment first
2. Use profile-based deployments for testing
3. Maintain backward compatibility
4. Document all configuration changes

### Operations
1. Regular backups before updates
2. Monitor service health continuously
3. Use standardized VMID ranges
4. Keep services updated

### Security
1. Regular security updates
2. Minimize exposed ports
3. Use strong authentication
4. Monitor access logs

## Conclusion

The unified architecture provides a clean, maintainable, and scalable approach to homelab service deployment on ProxMox VE. By consolidating multiple implementations into a single, well-structured system, we achieve:

- Consistent deployment patterns
- Simplified maintenance
- Better resource utilization
- Enhanced monitoring capabilities
- Clear upgrade paths

This architecture serves as the foundation for a modern, containerized homelab infrastructure.