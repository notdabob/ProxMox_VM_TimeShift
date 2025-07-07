# Comprehensive Troubleshooting Guide

This guide covers common issues and their solutions for the ProxMox homelab deployment.

## Quick Diagnostic Tools

The repository includes several diagnostic tools:

- `./scripts/troubleshoot-vm-network.sh` - Comprehensive VM network diagnostics
- `./scripts/fix-vm-220.sh` - Quick fix for VM 220 specifically
- `./deploy/service-discovery.sh` - Service health monitoring

## Common Issues

### 1. VM Network Connectivity Issues

**Symptoms:**
- Cannot SSH into VM
- VM has no IP address
- Services not accessible

**Diagnosis:**
```bash
# Run comprehensive network check
./scripts/troubleshoot-vm-network.sh --vmid 220

# Check VM status
qm status 220
qm config 220
```

**Solutions:**
```bash
# Attempt automatic fixes
./scripts/troubleshoot-vm-network.sh --vmid 220 --fix

# Manual fix via console
qm terminal 220
# Inside VM:
dhclient -v
systemctl restart networking
```

### 2. Guest Agent Not Responding

**Symptoms:**
- `qm agent` commands fail
- Cannot detect VM IP automatically

**Solutions:**
```bash
# Install guest agent in VM
qm terminal 220
# Inside VM:
apt-get update
apt-get install -y qemu-guest-agent
systemctl enable --now qemu-guest-agent
```

### 3. Docker Services Not Starting

**Symptoms:**
- Services fail to start
- Port conflicts
- Permission errors

**Diagnosis:**
```bash
# Check service status
./deploy/service-discovery.sh --status --vmid 220

# Check Docker logs
docker-compose logs
```

**Solutions:**
```bash
# Restart services
./deploy/deploy-stack.sh --vmid 220 --profile full --force

# Check for port conflicts
netstat -tulpn | grep :8080
```

### 4. CORS Errors in Web Interface

**Symptoms:**
- Browser console shows CORS errors
- API requests fail

**Solutions:**
1. Check the API configuration file: `docker/services/idrac-manager/config/api-config.json`
2. Add your domain to `allowed_origins`
3. Restart the iDRAC manager service

### 5. Deployment Fails

**Symptoms:**
- Deployment script exits with errors
- Services don't start properly

**Diagnosis:**
```bash
# Check deployment logs
tail -f deployment.log

# Run in dry-run mode
./deploy/deploy-stack.sh --vmid 220 --profile full --dry-run
```

**Solutions:**
```bash
# Force clean deployment
./deploy/deploy-stack.sh --vmid 220 --profile full --force

# Rollback to previous version
./deploy/deploy-stack.sh --vmid 220 --rollback
```

## Network Configuration Issues

### Bridge Configuration

Check ProxMox network configuration:
```bash
# List bridges
brctl show

# Check bridge IP
ip addr show vmbr0

# Check routing
ip route show
```

### DHCP Issues

If VMs aren't getting IP addresses:
```bash
# Check DHCP leases
cat /var/lib/misc/dnsmasq.leases

# Restart DHCP service
systemctl restart dnsmasq
```

## Service-Specific Issues

### iDRAC Manager

**Port 8080 not accessible:**
```bash
# Check if service is running
docker ps | grep idrac
docker logs idrac-manager

# Check firewall
ufw status
iptables -L
```

### MCP Services

**Services not responding on ports 7001-7003:**
```bash
# Check service health
curl http://localhost:7001/health
curl http://localhost:7002/health
curl http://localhost:7003/health
```

### Time-Shift Proxy

**SSL certificate issues:**
```bash
# Check proxy status
curl -k https://localhost:8090/status

# Check certificate validity
openssl s_client -connect localhost:8090
```

## Performance Issues

### High CPU Usage

```bash
# Check container resource usage
docker stats

# Check system resources
htop
iostat -x 1
```

### Memory Issues

```bash
# Check memory usage
free -h
docker system df

# Clean up unused resources
docker system prune -f
```

## Recovery Procedures

### Complete System Recovery

If the entire deployment is broken:

```bash
# 1. Stop all services
docker-compose down

# 2. Clean up containers and volumes
docker system prune -a -f
docker volume prune -f

# 3. Redeploy from scratch
./deploy/deploy-stack.sh --vmid 220 --profile full --force
```

### Backup and Restore

```bash
# Create backup before making changes
./deploy/deploy-stack.sh --vmid 220 --profile full

# Restore from backup
./deploy/deploy-stack.sh --vmid 220 --rollback
```

## Getting Help

### Log Files

Important log files to check:
- `deployment.log` - Deployment activities
- `docker-compose logs` - Service logs
- `/var/log/syslog` - System logs
- `/tmp/vm-*-info.json` - VM information

### Debug Mode

Run scripts with debug output:
```bash
# Enable bash debugging
bash -x ./scripts/troubleshoot-vm-network.sh --vmid 220

# Verbose Docker output
docker-compose up --verbose
```

### Collecting Information

When reporting issues, include:
1. VM configuration: `qm config <vmid>`
2. Network configuration: `ip addr show`
3. Service status: `docker ps -a`
4. Recent logs: `tail -100 deployment.log`
5. System information: `uname -a`, `free -h`, `df -h`

## Prevention

### Regular Maintenance

```bash
# Weekly health check
./deploy/service-discovery.sh --watch --vmid 220 --interval 60

# Monthly cleanup
docker system prune -f
apt-get autoremove -y
```

### Monitoring

Set up monitoring for:
- VM resource usage
- Service health endpoints
- Network connectivity
- Disk space usage

### Backup Strategy

- Daily configuration backups
- Weekly full system backups
- Test restore procedures monthly