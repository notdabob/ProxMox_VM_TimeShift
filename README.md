# ProxMox VM TimeShift

A unified deployment solution for homelab services on ProxMox VE, providing standardized management for MCP servers, iDRAC interfaces, time-shift proxies, and monitoring services.

## 🚀 Quick Start

```bash
# Clone the repository
git clone https://github.com/notdabob/ProxMox_VM_TimeShift.git
cd ProxMox_VM_TimeShift

# Create a hybrid VM (recommended)
./deploy/create-vm.sh --type hybrid

# Deploy the full stack
./deploy/deploy-stack.sh --vmid 220 --profile full
```

## 📋 Features

- **Unified Deployment**: Single command deployment for all homelab services
- **Service Profiles**: Choose between mcp, idrac, timeshift, monitoring, or full stack
- **Auto-Discovery**: Automatic detection of servers on your network
- **Web Dashboard**: Browser-based management interface
- **Health Monitoring**: Real-time service health checks
- **Standardized Architecture**: Consistent port allocation and VMID ranges

## 🏗️ Architecture

### Service Components

1. **MCP Services** (Ports 7001-7003)
   - Context7 MCP: SQLite context management
   - Desktop Commander: System control capabilities
   - Filesystem MCP: File system access

2. **iDRAC Manager** (Ports 8080, 8765)
   - Web dashboard for server management
   - Support for Dell iDRAC, ProxMox, Linux, Windows, and VNC
   - SSH key management and RDM export

3. **Time-Shift Proxy** (Port 8090)
   - SSL certificate time manipulation
   - Access systems with expired certificates

4. **Monitoring Stack** (Ports 9000-9010)
   - Service discovery and registration
   - Health monitoring
   - Unified dashboard

### Standardized Configuration

- **VMID Ranges**: 200-249 (organized by service type)
- **Port Allocation**: Organized by service category
- **Docker Networks**: Isolated homelab-network
- **Persistent Storage**: Docker volumes for data persistence

## 📦 Installation

### Prerequisites

- ProxMox VE 7.0 or higher
- SSH access to ProxMox host
- Sufficient resources (4 cores, 8GB RAM recommended)

### Step 1: Create VM

```bash
# Create a hybrid VM with default resources
./deploy/create-vm.sh --type hybrid

# Or customize resources
./deploy/create-vm.sh --type hybrid --cores 6 --memory 12288 --disk 60
```

### Step 2: Deploy Services

```bash
# Deploy full stack (recommended)
./deploy/deploy-stack.sh --vmid 220 --profile full

# Or deploy specific services
./deploy/deploy-stack.sh --vmid 220 --profile mcp
./deploy/deploy-stack.sh --vmid 220 --profile idrac
```

### Step 3: Access Services

After deployment, access services at:
- **Unified Dashboard**: `http://<VM_IP>:9010`
- **iDRAC Manager**: `http://<VM_IP>:8080`
- **MCP Services**: `http://<VM_IP>:7001-7003`

## 🔧 Management

### Service Control

```bash
# Check service status
./deploy/service-discovery.sh --status --vmid 220

# Monitor services continuously
./deploy/service-discovery.sh --watch --vmid 220 --interval 30

# Restart services
./deploy/deploy-stack.sh --vmid 220 --profile full --force
```

### Updates and Rollbacks

```bash
# Update services
cd ProxMox_VM_TimeShift
git pull
./deploy/deploy-stack.sh --vmid 220 --profile full

# Rollback if needed
./deploy/deploy-stack.sh --vmid 220 --rollback
```

## 📁 Project Structure

```
ProxMox_VM_TimeShift/
├── deploy/                 # Deployment scripts
│   ├── create-vm.sh       # VM creation
│   ├── deploy-stack.sh    # Service deployment
│   └── service-discovery.sh # Monitoring
├── docker/                 # Docker configurations
│   ├── docker-compose.yaml
│   └── services/          # Service-specific files
├── config/                 # Configuration files
├── scripts/               # Utility scripts
├── docs/                  # Documentation
└── archive/               # Legacy code (reference only)
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 Documentation

- [Architecture Overview](docs/UNIFIED-ARCHITECTURE.md)
- [Deployment Guide](docs/DEPLOYMENT-GUIDE.md)
- [Quick Start Guide](docs/QUICK-START.md)
- [Local Deployment Guide](DEPLOY-LOCAL.md)
- [Comprehensive Troubleshooting Guide](docs/TROUBLESHOOTING.md)
- [VM Network Troubleshooting](docs/VM-220-NETWORK-DEBUG.md)
- [Quick Fix Guide](docs/QUICK-FIX-VM-220.md)
- [Cleanup Plan](docs/CLEANUP-PLAN.md)

## 🔧 Troubleshooting

If you encounter network issues with your VMs:

```bash
# Run the network troubleshooting script
./scripts/troubleshoot-vm-network.sh --vmid 220

# Attempt automatic fixes
./scripts/troubleshoot-vm-network.sh --vmid 220 --fix

# Quick fix for VM 220 specifically
./scripts/fix-vm-220.sh
```

## ⚠️ Important Notes

- The `archive/` directory contains legacy code for reference only
- Use the unified deployment approach for all new installations
- Regular backups are recommended before updates

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.