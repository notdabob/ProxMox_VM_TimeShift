# ProxMox Homelab Unified Stack - Deployment Guide

This guide provides step-by-step instructions for deploying the unified homelab stack, migrating from legacy deployments, and managing your services.

## 🚀 Quick Deployment (New Installation)

### Prerequisites
- ProxMox VE 7.0 or later
- Root access to ProxMox host
- At least 8GB RAM and 40GB storage available
- Network connectivity for VM creation

### Step 1: Clone Repository
```bash
# SSH to your ProxMox host
ssh root@your-proxmox-host

# Clone the unified stack
git clone https://github.com/notdabob/time-shift-proxmox.git
cd time-shift-proxmox
```

### Step 2: Create Unified VM
```bash
# Create a hybrid VM (recommended for most users)
./scripts/unified-vm-create.sh --type hybrid

# Or specify custom resources
./scripts/unified-vm-create.sh --type hybrid --cores 6 --memory 12288 --vmid 220
```

### Step 3: Deploy Services
```bash
# Deploy full stack (recommended)
./deploy-unified-stack.sh --vmid 220 --profile full

# Or deploy specific services only
./deploy-unified-stack.sh --vmid 220 --profile mcp
```

### Step 4: Access Dashboard
```bash
# Get VM IP from the deployment output or:
qm guest cmd 220 network-get-interfaces

# Access unified dashboard
# http://VM_IP:9010
```

## 🔄 Migration from Legacy Deployments

### Step 1: Scan for Legacy Deployments
```bash
# Scan your ProxMox environment for existing deployments
./scripts/migrate-legacy.sh --scan
```

### Step 2: Validate Migration Readiness
```bash
# Check if a specific VM is ready for migration
./scripts/migrate-legacy.sh --validate --source-vmid 205
```

### Step 3: Backup Legacy Deployment
```bash
# Create backup before migration (recommended)
./scripts/migrate-legacy.sh --backup --source-vmid 205
```

### Step 4: Perform Migration
```bash
# Migrate to unified stack
./scripts/migrate-legacy.sh --migrate --source-vmid 205 --target-type hybrid

# Or specify target VMID
./scripts/migrate-legacy.sh --migrate --source-vmid 205 --target-vmid 225 --target-type hybrid
```

### Step 5: Verify and Cleanup
```bash
# Test new deployment
curl http://NEW_VM_IP:9010

# Stop old VM (after verification)
qm stop 205

# Remove old VM (after extended verification period)
qm destroy 205
```

## 📊 Service Management

### Health Monitoring
```bash
# Register services for monitoring
./scripts/service-discovery.sh --register --vmid 220

# Perform health checks
./scripts/service-discovery.sh --health-check --vmid 220

# Continuous monitoring
./scripts/service-discovery.sh --watch --vmid 220 --interval 30
```

### Service Control
```bash
# Restart all services
./deploy-unified-stack.sh --vmid 220 --profile full --force

# Deploy specific profile
./deploy-unified-stack.sh --vmid 220 --profile mcp

# Rollback to previous deployment
./deploy-unified-stack.sh --vmid 220 --rollback
```

### Log Management
```bash
# View service logs
ssh root@VM_IP "cd /opt/homelab && docker-compose logs -f"

# View specific service logs
ssh root@VM_IP "docker logs idrac-manager"

# View deployment logs
cat deployment.log
```

## 🔧 Advanced Configuration

### Custom Service Profiles

Edit `config/homelab-config.yaml` to create custom profiles:

```yaml
profiles:
  development:
    description: "Development Environment"
    services:
      - "context7-mcp"
      - "filesystem-mcp"
      - "health-monitor"
    dependencies: []
```

Deploy with custom profile:
```bash
./deploy-unified-stack.sh --vmid 220 --profile development
```

### Resource Scaling

For high-demand environments:
```bash
# Create VM with more resources
./scripts/unified-vm-create.sh --type hybrid --cores 8 --memory 16384 --disk 80

# Update existing VM resources
qm set 220 --cores 8 --memory 16384
qm resize 220 scsi0 +40G
```

### Network Configuration

Configure custom networking in `config/homelab-config.yaml`:
```yaml
vm_standards:
  network:
    bridge: "vmbr1"
    subnet: "10.0.0.0/24"
    gateway: "10.0.0.1"
```

### SSL/TLS Configuration

Enable SSL termination:
```yaml
security:
  ssl:
    enabled: true
    cert_path: "/opt/homelab/certs"
    auto_generate: true
```

## 🚨 Troubleshooting

### VM Creation Issues

**Problem**: VM creation fails with storage error
```bash
# Check available storage
pvesm status

# Use different storage
./scripts/unified-vm-create.sh --type hybrid --storage local-zfs
```

**Problem**: VMID already exists
```bash
# Check VM status
qm status 220

# Use different VMID or force creation
./scripts/unified-vm-create.sh --type hybrid --vmid 225
```

### Deployment Issues

**Problem**: Docker not available on VM
```bash
# Check Docker status
ssh root@VM_IP "systemctl status docker"

# Install Docker manually
ssh root@VM_IP "curl -fsSL https://get.docker.com | sh"
```

**Problem**: Service deployment fails
```bash
# Check deployment logs
./deploy-unified-stack.sh --vmid 220 --profile full --dry-run

# Force rebuild
ssh root@VM_IP "cd /opt/homelab && docker-compose down && docker-compose up -d --build"
```

### Service Issues

**Problem**: Services not responding
```bash
# Check service status
./scripts/service-discovery.sh --health-check --vmid 220

# Restart specific service
ssh root@VM_IP "docker restart idrac-manager"

# Check service logs
ssh root@VM_IP "docker logs idrac-manager"
```

**Problem**: Port conflicts
```bash
# Check port usage
ssh root@VM_IP "netstat -tulpn | grep :8080"

# Update port configuration in docker-compose-unified.yaml
```

### Network Issues

**Problem**: Cannot access services from external network
```bash
# Check VM firewall
ssh root@VM_IP "iptables -L"

# Check ProxMox firewall
pve-firewall status

# Open required ports
ssh root@VM_IP "ufw allow 7001:7003/tcp"
ssh root@VM_IP "ufw allow 8080,8765,8090/tcp"
ssh root@VM_IP "ufw allow 9000:9010/tcp"
```

## 📈 Performance Optimization

### Resource Monitoring
```bash
# Monitor VM resources
qm monitor 220

# Check container resources
ssh root@VM_IP "docker stats"

# Monitor disk usage
ssh root@VM_IP "df -h"
```

### Performance Tuning
```bash
# Optimize VM settings
qm set 220 --cpu cputype=host
qm set 220 --numa 1

# Optimize Docker
ssh root@VM_IP "echo 'vm.max_map_count=262144' >> /etc/sysctl.conf"
ssh root@VM_IP "sysctl -p"
```

### Backup and Recovery

#### Automated Backups
```bash
# Enable automated backups in config
# Edit config/homelab-config.yaml:
backup:
  enabled: true
  retention_days: 30
  schedule: "0 2 * * *"  # Daily at 2 AM
```

#### Manual Backup
```bash
# Create VM snapshot
qm snapshot 220 "before-update-$(date +%Y%m%d)"

# Backup service data
ssh root@VM_IP "cd /opt/homelab && docker-compose down"
ssh root@VM_IP "tar -czf /tmp/homelab-backup.tar.gz /opt/homelab/volumes"
scp root@VM_IP:/tmp/homelab-backup.tar.gz ./backups/
```

#### Recovery
```bash
# Restore from snapshot
qm rollback 220 before-update-20241204

# Restore service data
scp ./backups/homelab-backup.tar.gz root@VM_IP:/tmp/
ssh root@VM_IP "cd / && tar -xzf /tmp/homelab-backup.tar.gz"
ssh root@VM_IP "cd /opt/homelab && docker-compose up -d"
```

## 🔒 Security Hardening

### Basic Security
```bash
# Update VM
ssh root@VM_IP "apt update && apt upgrade -y"

# Configure firewall
ssh root@VM_IP "ufw enable"
ssh root@VM_IP "ufw default deny incoming"
ssh root@VM_IP "ufw allow ssh"
ssh root@VM_IP "ufw allow 7001:7003/tcp"
ssh root@VM_IP "ufw allow 8080,8765,8090/tcp"
ssh root@VM_IP "ufw allow 9000:9010/tcp"
```

### Advanced Security
```bash
# Enable fail2ban
ssh root@VM_IP "apt install fail2ban -y"

# Configure SSH key authentication
ssh-copy-id root@VM_IP
ssh root@VM_IP "sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config"
ssh root@VM_IP "systemctl restart ssh"

# Enable audit logging
ssh root@VM_IP "apt install auditd -y"
```

## 📚 Additional Resources

### Configuration Files
- `config/homelab-config.yaml` - Main configuration
- `docker-compose-unified.yaml` - Service definitions
- `config/nginx-unified.conf` - Reverse proxy configuration

### Log Locations
- `deployment.log` - Deployment logs
- `service-registry.json` - Service registry
- `health-status.json` - Health monitoring data
- `/tmp/vm-VMID-info.json` - VM information

### Useful Commands
```bash
# Quick status check
./scripts/service-discovery.sh --status --vmid 220

# Emergency stop all services
ssh root@VM_IP "cd /opt/homelab && docker-compose down"

# Emergency restart
./deploy-unified-stack.sh --vmid 220 --profile full --force

# View all containers
ssh root@VM_IP "docker ps -a"

# Clean up unused resources
ssh root@VM_IP "docker system prune -f"
```

## 🆘 Getting Help

### Community Support
- GitHub Issues: Report bugs and request features
- GitHub Discussions: Ask questions and share experiences
- Wiki: Additional documentation and examples

### Professional Support
For enterprise deployments or custom configurations, consider professional support options.

---

**Remember**: Always test deployments in a non-production environment first, and maintain regular backups of your critical data.