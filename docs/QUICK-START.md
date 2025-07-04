# 🚀 ProxMox Homelab Quick Start Guide

## Copy-Paste Commands for ProxMox Console

### Step 1: Prerequisites Check
```bash
# Verify ProxMox environment
cat /etc/pve/.version
pvesm status
free -h
df -h
```

### Step 2: Navigate to Project
```bash
# Change to project directory
cd /root/time-shift-proxmox
# OR: cd /path/to/your/time-shift-proxmox
```

### Step 3: Make Scripts Executable
```bash
chmod +x scripts/*.sh
chmod +x deploy-unified-stack.sh
```

### Step 4: Create VM
```bash
# Create hybrid VM (recommended)
./scripts/unified-vm-create.sh --type hybrid

# Note the VMID output (e.g., "Auto-assigned VMID: 220")
```

### Step 5: Deploy Services
```bash
# Replace 220 with your actual VMID from step 4
VMID=220
./deploy-unified-stack.sh --vmid $VMID --profile full
```

### Step 6: Verify Deployment
```bash
# Check service health
./scripts/service-discovery.sh --register --vmid $VMID
./scripts/service-discovery.sh --health-check --vmid $VMID
```

### Step 7: Get Access URLs
```bash
# Get VM IP and show service URLs
VM_IP=$(qm guest cmd $VMID network-get-interfaces | grep -Eo '"ip-address": "([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)"' | grep -v '127.0.0.1' | head -n1 | cut -d'"' -f4)

echo "=== Your Homelab Services ==="
echo "Unified Dashboard:    http://$VM_IP:9010"
echo "Context7 MCP:         http://$VM_IP:7001"
echo "Desktop Commander:    http://$VM_IP:7002"
echo "Filesystem MCP:       http://$VM_IP:7003"
echo "iDRAC Dashboard:      http://$VM_IP:8080"
echo "iDRAC API:            http://$VM_IP:8765"
echo "Time-Shift Proxy:     http://$VM_IP:8090"
echo "Service Discovery:    http://$VM_IP:9000"
echo "Health Monitor:       http://$VM_IP:9001"
```

## 🔧 Management Commands

### Monitor Services
```bash
# Continuous monitoring
./scripts/service-discovery.sh --watch --vmid $VMID

# One-time status check
./scripts/service-discovery.sh --status --vmid $VMID
```

### Restart Services
```bash
# Force restart all services
./deploy-unified-stack.sh --vmid $VMID --profile full --force
```

### View Logs
```bash
# View all service logs
ssh root@$VM_IP "cd /opt/homelab && docker-compose logs -f"

# View specific service logs
ssh root@$VM_IP "docker logs idrac-manager"
```

### Rollback
```bash
# Rollback to previous deployment
./deploy-unified-stack.sh --vmid $VMID --rollback
```

## 🔄 Migration (If You Have Existing Deployments)

### Scan for Legacy Deployments
```bash
./scripts/migrate-legacy.sh --scan
```

### Migrate Existing VM
```bash
# Replace OLD_VMID with your existing VM ID
./scripts/migrate-legacy.sh --migrate --source-vmid OLD_VMID --target-type hybrid
```

## 🧹 Cleanup (After Successful Deployment)

### Backup Legacy Files
```bash
mkdir -p /root/legacy-backup
cp -r proxmox_ve-scripts /root/legacy-backup/
cp namespace-timeshift-browser-container/deploy-proxmox.sh /root/legacy-backup/
```

### Remove Deprecated Files
```bash
# ONLY run after successful deployment and testing
rm -f proxmox_ve-scripts/scripts/create_mcp_docker_vm.sh
rm -f proxmox_ve-scripts/scripts/deploy_mcp_to_docker_vm.sh
rm -f proxmox_ve-scripts/scripts/one-liner-deploy.sh
rm -f proxmox_ve-scripts/docker-compose.yaml
rm -f namespace-timeshift-browser-container/deploy-proxmox.sh
rm -f namespace-timeshift-browser-container/container-rebuild.sh
```

## 🚨 Troubleshooting

### VM Creation Issues
```bash
# Check available VMIDs
qm list

# Check storage
pvesm status

# Use specific VMID
./scripts/unified-vm-create.sh --type hybrid --vmid 225
```

### Service Issues
```bash
# Check VM status
qm status $VMID

# Check Docker on VM
ssh root@$VM_IP "systemctl status docker"

# Restart Docker if needed
ssh root@$VM_IP "systemctl restart docker"
```

### Network Issues
```bash
# Check VM network
qm guest cmd $VMID network-get-interfaces

# Check firewall
ssh root@$VM_IP "ufw status"
```

## 📊 Service Profiles

- **`full`** - Complete homelab stack (recommended)
- **`mcp`** - MCP services only (7001-7003)
- **`idrac`** - iDRAC management only (8080, 8765)
- **`timeshift`** - Time-shift proxy only (8090)
- **`monitoring`** - Monitoring services only (9000-9001)

## 🎯 Quick Commands Reference

```bash
# Create VM
./scripts/unified-vm-create.sh --type hybrid

# Deploy services
./deploy-unified-stack.sh --vmid VMID --profile full

# Check health
./scripts/service-discovery.sh --health-check --vmid VMID

# Monitor
./scripts/service-discovery.sh --watch --vmid VMID

# Emergency restart
./deploy-unified-stack.sh --vmid VMID --profile full --force
```

---

**🎉 That's it! Your unified homelab stack should now be running!**

Access the unified dashboard at `http://VM_IP:9010` to manage all your services from one place.