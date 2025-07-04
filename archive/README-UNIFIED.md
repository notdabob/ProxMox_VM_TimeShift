# ProxMox Homelab Unified Stack

A comprehensive, standardized solution for deploying and managing multiple homelab services on ProxMox VE. This unified stack eliminates deployment inconsistencies and provides a cohesive management experience across MCP servers, iDRAC management, time-shift proxies, and monitoring services.

## 🚀 Quick Start

### One-Command Deployment

```bash
# Clone the repository
git clone https://github.com/notdabob/time-shift-proxmox.git
cd time-shift-proxmox

# Create and deploy a complete homelab stack
./scripts/unified-vm-create.sh --type hybrid
./deploy-unified-stack.sh --vmid 220 --profile full
```

### Service Access

After deployment, access your services through the unified dashboard:

- **Unified Dashboard**: `http://VM_IP:9010`
- **MCP Services**: `http://VM_IP:7001-7003`
- **iDRAC Management**: `http://VM_IP:8080`
- **Time-Shift Proxy**: `http://VM_IP:8090`
- **Monitoring**: `http://VM_IP:9000-9001`

## 📋 Architecture Overview

### Standardized VMID Ranges
- **200-209**: MCP Server Stack
- **210-219**: iDRAC Management
- **220-229**: Hybrid Stack (Recommended)
- **230-239**: Time-Shift Proxy
- **240-249**: Monitoring Services

### Port Allocation
- **7001-7010**: MCP Services
- **8080-8090**: iDRAC Services
- **8090-8099**: Time-Shift Services
- **9000-9010**: Monitoring & Discovery

### Service Profiles
- **`mcp`**: MCP Server Stack Only
- **`idrac`**: iDRAC Management Only
- **`timeshift`**: Time-Shift Proxy Only
- **`monitoring`**: Monitoring Services Only
- **`full`**: Complete Homelab Stack (Recommended)

## 🛠️ Components

### 1. Unified VM Creation (`scripts/unified-vm-create.sh`)

Creates standardized VMs with project-type specific configurations:

```bash
# Create MCP-only VM
./scripts/unified-vm-create.sh --type mcp

# Create hybrid VM with custom resources
./scripts/unified-vm-create.sh --type hybrid --cores 6 --memory 12288

# Create iDRAC management VM
./scripts/unified-vm-create.sh --type idrac --vmid 215
```

**Features:**
- Automatic VMID assignment within type ranges
- Standardized resource allocation (4 cores, 8GB RAM, 40GB disk)
- Project-specific package installation
- Network auto-detection and configuration

### 2. Unified Deployment (`deploy-unified-stack.sh`)

Deploys services using Docker Compose with profile support:

```bash
# Deploy full stack to specific VM
./deploy-unified-stack.sh --vmid 220 --profile full

# Deploy only MCP services
./deploy-unified-stack.sh --vm-ip 192.168.1.100 --profile mcp

# Local deployment
./deploy-unified-stack.sh --local --profile monitoring
```

**Features:**
- Profile-based service deployment
- Automatic backup before deployment
- Rollback capabilities
- Health monitoring integration
- Remote and local deployment support

### 3. Service Discovery (`scripts/service-discovery.sh`)

Provides centralized service registry and health monitoring:

```bash
# Register all services
./scripts/service-discovery.sh --register --vmid 220

# Perform health checks
./scripts/service-discovery.sh --health-check --vm-ip 192.168.1.100

# Continuous monitoring
./scripts/service-discovery.sh --watch --local --interval 15
```

**Features:**
- Automatic service discovery
- Real-time health monitoring
- Service registry with metadata
- Multiple output formats (table, JSON, YAML)

### 4. Unified Configuration (`config/homelab-config.yaml`)

Central configuration management for all services:

- VM standards and resource allocation
- Port assignments and networking
- Service profiles and dependencies
- Health check configurations
- Security and monitoring settings

## 📊 Service Stack

### MCP Services (7001-7010)
- **Context7 MCP** (7001): SQLite context management
- **Desktop Commander** (7002): System control capabilities
- **Filesystem MCP** (7003): File system access

### iDRAC Management (8080-8090)
- **iDRAC Dashboard** (8080): Web-based server management
- **iDRAC API** (8765): REST API for automation

### Time-Shift Services (8090-8099)
- **Time-Shift Proxy** (8090): SSL certificate time manipulation

### Monitoring Services (9000-9010)
- **Service Discovery** (9000): Service registry and discovery
- **Health Monitor** (9001): Real-time health monitoring
- **Unified Dashboard** (9010): Central management interface

## 🔧 Management Commands

### VM Management
```bash
# Create VM
./scripts/unified-vm-create.sh --type hybrid --vmid 220

# Deploy services
./deploy-unified-stack.sh --vmid 220 --profile full

# Monitor services
./scripts/service-discovery.sh --watch --vmid 220
```

### Service Management
```bash
# View service status
./scripts/service-discovery.sh --status --vmid 220

# Restart services
./deploy-unified-stack.sh --vmid 220 --profile full --force

# Rollback deployment
./deploy-unified-stack.sh --vmid 220 --rollback
```

### Health Monitoring
```bash
# Check service health
./scripts/service-discovery.sh --health-check --vmid 220

# Continuous monitoring
./scripts/service-discovery.sh --watch --vmid 220 --interval 30
```

## 🔄 Migration from Legacy Deployments

### Automated Migration
```bash
# Create migration script for existing deployments
./scripts/migrate-legacy.sh --scan --backup

# Migrate specific VM
./scripts/migrate-legacy.sh --vmid 205 --target-type hybrid
```

### Manual Migration Steps
1. **Backup existing services**: `docker-compose down && tar -czf backup.tar.gz volumes/`
2. **Create new unified VM**: `./scripts/unified-vm-create.sh --type hybrid`
3. **Deploy unified stack**: `./deploy-unified-stack.sh --vmid NEW_VMID --profile full`
4. **Restore data**: Copy volumes to new deployment
5. **Update DNS/networking**: Point to new VM IP

## 📈 Monitoring and Alerting

### Built-in Monitoring
- **Service Discovery**: Automatic service registration and discovery
- **Health Checks**: Real-time health monitoring with alerting
- **Performance Metrics**: Resource usage and response time tracking
- **Log Aggregation**: Centralized logging for all services

### Dashboard Features
- **Unified Interface**: Single dashboard for all services
- **Real-time Status**: Live service health and performance data
- **Service Management**: Start, stop, restart services from web interface
- **Configuration Management**: Update service configurations

## 🔒 Security Features

### Network Security
- **Isolated Networks**: Docker bridge networks for service isolation
- **Firewall Integration**: Automatic firewall rule management
- **SSL/TLS Support**: Optional SSL termination and certificate management

### Access Control
- **Service Authentication**: Optional authentication for sensitive services
- **Network Restrictions**: IP-based access control
- **Audit Logging**: Comprehensive access and change logging

## 🚨 Troubleshooting

### Common Issues

**VM Creation Fails**
```bash
# Check Proxmox connectivity
pvesh get /version

# Verify VMID availability
qm status VMID

# Check storage availability
pvesm status
```

**Service Deployment Fails**
```bash
# Check Docker status
ssh root@VM_IP "systemctl status docker"

# View deployment logs
./deploy-unified-stack.sh --vmid VMID --dry-run

# Check service logs
ssh root@VM_IP "cd /opt/homelab && docker-compose logs"
```

**Health Checks Fail**
```bash
# Manual health check
./scripts/service-discovery.sh --health-check --vmid VMID

# Check service connectivity
curl -f http://VM_IP:PORT/health

# View service status
ssh root@VM_IP "docker ps"
```

### Log Locations
- **Deployment Logs**: `./deployment.log`
- **Service Registry**: `./service-registry.json`
- **Health Status**: `./health-status.json`
- **VM Info**: `/tmp/vm-VMID-info.json`

## 📚 Advanced Configuration

### Custom Service Profiles
Edit `config/homelab-config.yaml` to create custom deployment profiles:

```yaml
profiles:
  custom:
    description: "Custom Service Mix"
    services:
      - "context7-mcp"
      - "idrac-manager"
      - "health-monitor"
    dependencies: []
```

### Resource Scaling
Modify VM resources for high-demand deployments:

```bash
./scripts/unified-vm-create.sh --type hybrid --cores 8 --memory 16384 --disk 80
```

### Network Customization
Configure custom networking in `config/homelab-config.yaml`:

```yaml
vm_standards:
  network:
    bridge: "vmbr1"
    subnet: "10.0.0.0/24"
    gateway: "10.0.0.1"
```

## 🤝 Contributing

1. **Fork the repository**: [https://github.com/notdabob/time-shift-proxmox](https://github.com/notdabob/time-shift-proxmox)
2. **Create feature branch**: `git checkout -b feature/new-service`
3. **Follow coding standards**: Use existing script patterns and documentation
4. **Test thoroughly**: Verify on clean Proxmox environment
5. **Submit pull request**: Include detailed description and testing results

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Issues**: [GitHub Issues](https://github.com/notdabob/time-shift-proxmox/issues)
- **Discussions**: [GitHub Discussions](https://github.com/notdabob/time-shift-proxmox/discussions)
- **Documentation**: [Wiki](https://github.com/notdabob/time-shift-proxmox/wiki)

---

**Built with ❤️ for the homelab community**