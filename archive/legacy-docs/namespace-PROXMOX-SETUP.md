# Proxmox iDRAC Management Container Setup

This guide shows how to deploy a containerized iDRAC management solution on your Proxmox server, eliminating all macOS quarantine issues and providing centralized network access.

## Overview

The container solution provides:

- 🌐 **Web-based dashboard** accessible from any device
- 🔍 **Automatic network scanning** for iDRAC servers
- 🔑 **SSH key management** for passwordless access
- 🖥️ **One-click Virtual Console** access
- 🐳 **Zero macOS issues** - everything runs in the container

## Quick Start

### 1. Clone Repository to Proxmox

Clone the repository directly on your Proxmox host:

```bash
# SSH to Proxmox
ssh root@your-proxmox-host

# Clone from GitHub
git clone https://github.com/notdabob/namespace-timeshift-browser-container.git
cd namespace-timeshift-browser-container
```

### 2. Deploy Container

Run the deployment script:

```bash
# Make executable and deploy
chmod +x deploy-proxmox.sh
./deploy-proxmox.sh deploy
```

### 3. Access Dashboard

Open your browser and navigate to:

```
http://YOUR-PROXMOX-IP:8080
```

## Detailed Setup

### Prerequisites

- Proxmox VE 7.0 or later
- Root access to Proxmox host
- Network connectivity to iDRAC servers

### Deployment Commands

```bash
# Deploy (installs Docker if needed)
./deploy-proxmox.sh deploy

# Check status
./deploy-proxmox.sh status

# View logs
./deploy-proxmox.sh logs

# Update container
./deploy-proxmox.sh update

# Remove everything
./deploy-proxmox.sh cleanup
```

### Container Architecture

```
┌─────────────────────────────────────┐
│ Proxmox Host                        │
│ ┌─────────────────────────────────┐ │
│ │ iDRAC Manager Container         │ │
│ │ ┌─────────────┐ ┌─────────────┐ │ │
│ │ │ Web Server  │ │ API Server  │ │ │
│ │ │ (nginx:80)  │ │ (Python)    │ │ │
│ │ └─────────────┘ └─────────────┘ │ │
│ │ ┌─────────────┐ ┌─────────────┐ │ │
│ │ │ Dashboard   │ │ Network     │ │ │
│ │ │ Generator   │ │ Scanner     │ │ │
│ │ └─────────────┘ └─────────────┘ │ │
│ └─────────────────────────────────┘ │
└─────────────────────────────────────┘
           │ Port 8080 │ Port 8765
           ▼           ▼
    [Your Browser] [API Calls]
```

### Network Requirements

The container needs network access to:

- iDRAC servers on ports 80/443
- SSH access to iDRAC servers on port 22 (for key deployment)

## Features

### Web Dashboard

Access the dashboard at `http://proxmox-ip:8080`:

- **Server Discovery**: Automatic scanning every 5 minutes
- **Status Monitoring**: Online/offline status for all servers
- **SSH Management**: Generate and deploy SSH keys
- **One-Click Access**: Direct links to iDRAC interfaces

### SSH Key Management

1. **Generate SSH Key**:

   - Enter admin email address
   - Click "Generate SSH Key"
   - Key stored in container at `/root/.ssh/idrac_rsa`

2. **Deploy to Servers**:

   - Click "Deploy to All Servers"
   - Updates SSH config automatically
   - Enables passwordless access

3. **SSH Access**:

   ```bash
   # From Proxmox host
   docker exec -it idrac-manager ssh idrac-192-168-1-23
   ```

### Virtual Console Access

- **Web Interface**: Click "Access iDRAC" → Navigate to Console
- **Direct Console**: Click "Virtual Console" for direct console access
- **No Time Shifting**: Works with current certificates

## Management

### Container Management

```bash
# View container status
docker ps | grep idrac-manager

# View logs
docker logs idrac-manager

# Restart container
docker restart idrac-manager

# Enter container shell
docker exec -it idrac-manager bash

# Update container
./deploy-proxmox.sh update
```

### Data Persistence

- **Server Database**: `/app/data/discovered_idracs.json`
- **SSH Keys**: `/root/.ssh/idrac_rsa*`
- **Admin Config**: `/app/data/admin_config.json`

Data persists across container restarts via Docker volume.

### Backup and Restore

```bash
# Backup data volume
docker run --rm -v idrac-data:/data -v $(pwd):/backup ubuntu tar czf /backup/idrac-backup.tar.gz -C /data .

# Restore data volume
docker run --rm -v idrac-data:/data -v $(pwd):/backup ubuntu tar xzf /backup/idrac-backup.tar.gz -C /data
```

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker logs idrac-manager

# Check system resources
docker system df
df -h

# Restart Docker service
systemctl restart docker
```

### Network Scanning Issues

```bash
# Test from container
docker exec -it idrac-manager nmap -p 80,443 192.168.1.1-254

# Check container network
docker exec -it idrac-manager ip route show
```

### SSH Key Deployment Fails

```bash
# Test SSH connection
docker exec -it idrac-manager ssh -o ConnectTimeout=10 root@idrac-ip

# Check iDRAC SSH settings
# Enable SSH in iDRAC web interface: iDRAC Settings → Network → Services
```

### Dashboard Not Loading

```bash
# Check nginx status
docker exec -it idrac-manager nginx -t

# Check API server
curl http://localhost:8765/status

# Restart services
docker restart idrac-manager
```

## Security Considerations

- **Network Isolation**: Container uses host networking for iDRAC discovery
- **SSH Keys**: Stored securely within container
- **Default Credentials**: Change default iDRAC passwords after deployment
- **API Access**: API server only accessible from Proxmox host

## Advanced Configuration

### Custom Network Range

Edit `/app/src/network-scanner.py` in container:

```bash
docker exec -it idrac-manager vi /app/src/network-scanner.py
# Modify get_network_range() function
docker restart idrac-manager
```

### Custom Ports

Modify deployment script port mappings:

```bash
# Edit deploy-proxmox.sh
HTTP_PORT="8080"    # Change to desired port
API_PORT="8765"     # Change to desired port
```

### Monitoring Integration

Prometheus metrics endpoint available at:

```html
http://proxmox-ip:8765/metrics
```

## Support

For issues and questions:

1. Check container logs: `docker logs idrac-manager`
2. Verify network connectivity to iDRAC servers
3. Ensure Proxmox has sufficient resources
4. Check iDRAC SSH/web interface settings

## Migration from macOS Solution

If migrating from the macOS time-shifting solution:

1. **Export Server List**: Copy `discovered_idracs.json` to container data volume
2. **SSH Keys**: Transfer existing SSH keys to container
3. **Configuration**: Update any custom settings in container

The container solution eliminates time-shifting entirely, working with current SSL certificates through direct web access.
