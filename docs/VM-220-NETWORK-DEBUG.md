# VM 220 Network Connectivity Troubleshooting Guide

## Overview

VM 220 is part of the hybrid stack (VMID range 220-229) and should be running a complete homelab stack including MCP, iDRAC, Time-Shift, and monitoring services. This guide helps diagnose and fix network connectivity issues.

## Quick Diagnostic Commands

Run these commands on your ProxMox host:

```bash
# 1. Check if VM is running
qm list | grep 220

# 2. Check VM status
qm status 220

# 3. If VM is not running, start it
qm start 220

# 4. Check VM configuration
qm config 220

# 5. Check network bridges
ip a | grep vmbr
brctl show

# 6. Try to get VM IP via guest agent
qm agent 220 network-get-interfaces

# 7. Check guest agent status
qm agent 220 ping
```

## Common Issues and Solutions

### Issue 1: VM Not Running

**Symptoms:**
- `qm list` doesn't show VM 220 or shows it as stopped
- Cannot ping or SSH to VM

**Solution:**
```bash
# Start the VM
qm start 220

# Wait 30 seconds for boot
sleep 30

# Check status again
qm status 220
```

### Issue 2: No Network Interface Configured

**Symptoms:**
- `qm config 220` shows no net0 interface
- VM has no network connectivity

**Solution:**
```bash
# Add network interface
qm set 220 --net0 virtio,bridge=vmbr0

# Restart VM
qm shutdown 220 && sleep 10 && qm start 220
```

### Issue 3: QEMU Guest Agent Not Responding

**Symptoms:**
- `qm agent 220 ping` fails
- Cannot detect VM IP address

**Solution:**
1. Access VM console:
   ```bash
   qm terminal 220
   ```

2. Inside the VM, install and enable guest agent:
   ```bash
   apt-get update
   apt-get install -y qemu-guest-agent
   systemctl enable --now qemu-guest-agent
   ```

3. Exit console (Ctrl+] or Ctrl+A X)

### Issue 4: Network Not Configured Inside VM

**Symptoms:**
- VM is running but has no IP
- Cannot reach external networks

**Solution:**
1. Access VM console:
   ```bash
   qm terminal 220
   ```

2. Check network interfaces:
   ```bash
   ip addr show
   ```

3. If no IP on eth0/ens18, request DHCP:
   ```bash
   dhclient -v
   ```

4. Or configure static IP:
   ```bash
   # Edit network config
   nano /etc/network/interfaces
   
   # Add:
   auto eth0
   iface eth0 inet static
       address 192.168.1.220
       netmask 255.255.255.0
       gateway 192.168.1.1
   
   # Restart networking
   systemctl restart networking
   ```

### Issue 5: Bridge Configuration Issues

**Symptoms:**
- Bridge vmbr0 doesn't exist
- Bridge has no IP or wrong configuration

**Solution:**
1. Check ProxMox network config:
   ```bash
   cat /etc/network/interfaces
   ```

2. Ensure vmbr0 is configured properly:
   ```
   auto vmbr0
   iface vmbr0 inet static
       address 192.168.1.X/24
       gateway 192.168.1.1
       bridge-ports eno1
       bridge-stp off
       bridge-fd 0
   ```

3. Restart networking:
   ```bash
   systemctl restart networking
   ```

## Using the Troubleshooting Script

A comprehensive troubleshooting script is available:

```bash
# On ProxMox host
cd /opt/homelab/scripts
./troubleshoot-vm-network.sh --vmid 220

# To attempt automatic fixes
./troubleshoot-vm-network.sh --vmid 220 --fix
```

## Manual Network Reset

If all else fails, perform a complete network reset:

```bash
# 1. Stop VM
qm stop 220

# 2. Remove old network config
qm set 220 --delete net0

# 3. Add fresh network config
qm set 220 --net0 virtio,bridge=vmbr0,firewall=0

# 4. Start VM
qm start 220

# 5. Wait for boot
sleep 60

# 6. Check for IP
qm agent 220 network-get-interfaces
```

## Alternative IP Detection Methods

If guest agent is not working:

```bash
# 1. Get VM MAC address
MAC=$(qm config 220 | grep -oP 'net0:.*mac=\K[^,]+')
echo "VM MAC: $MAC"

# 2. Check DHCP leases
grep -i "$MAC" /var/lib/misc/dnsmasq.leases

# 3. Check ARP table
arp -n | grep -i "$MAC"

# 4. Scan network for VM
nmap -sn 192.168.1.0/24 | grep -B 2 -i "$MAC"
```

## Verifying Connectivity

Once you have the VM IP:

```bash
# Assuming VM IP is 192.168.1.220
VM_IP="192.168.1.220"

# 1. Ping test
ping -c 3 $VM_IP

# 2. SSH test
ssh root@$VM_IP

# 3. Service checks
curl http://$VM_IP:7001/health  # MCP Context7
curl http://$VM_IP:8080/        # iDRAC Dashboard
curl http://$VM_IP:9010/        # Unified Dashboard
```

## Deployment After Network Fix

Once network is working:

```bash
# Deploy the hybrid stack
cd /opt/homelab
./deploy/deploy-stack.sh --vmid 220 --profile full

# Monitor deployment
./deploy/service-discovery.sh --vmid 220 --watch
```

## Prevention Tips

1. Always ensure QEMU Guest Agent is installed in VMs
2. Use static IPs for production VMs
3. Document network configuration
4. Regular health checks using service-discovery.sh
5. Keep VM info files updated in /tmp/vm-*-info.json

## Support Information

- VM Type: Hybrid Stack
- Expected Services: MCP, iDRAC, Time-Shift, Monitoring
- Port Ranges: 7001-7010, 8080-8090, 8090-8099, 9000-9010
- Default Network: Bridge vmbr0, DHCP from 192.168.1.0/24