# Quick Fix for VM 220 Network Issues

The VM was created but has no network connectivity. Here's how to fix it:

## Option 1: Quick Console Fix

```bash
# On ProxMox host:
qm start 220  # Make sure VM is running
qm terminal 220  # Access VM console

# Inside VM console (login as root):
# Fix DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# Get DHCP IP
dhclient -v

# Install guest agent
apt-get update
apt-get install -y qemu-guest-agent
systemctl start qemu-guest-agent

# Exit console with Ctrl+]
```

## Option 2: Recreate VM with Fixed Script

If the above doesn't work, delete and recreate:

```bash
# Delete broken VM
qm stop 220
qm destroy 220

# Create new VM with explicit network config
cd ~/ProxMox_VM_TimeShift
./deploy/create-vm.sh --type hybrid --vmid 220

# Wait for VM to get IP, then deploy
./deploy/deploy-stack.sh --vmid 220 --profile full
```

## Option 3: Manual IP Assignment

If DHCP isn't working:

```bash
# In VM console:
ip addr add 192.168.1.220/24 dev eth0
ip route add default via 192.168.1.1
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# Test connectivity
ping 8.8.8.8
```

## Common Issues and Solutions

### DNS Resolution Failing
- The VM can't resolve hostnames
- Fix: Add DNS servers to /etc/resolv.conf

### No DHCP Response  
- The VM isn't getting an IP from DHCP
- Fix: Check bridge configuration, restart networking

### Guest Agent Not Responding
- qm agent commands fail
- Fix: Install qemu-guest-agent inside VM

## After Fixing Network

Once the VM has network access:

```bash
# SSH into VM (replace with actual IP)
ssh root@192.168.1.220

# Clone and deploy
git clone https://github.com/notdabob/ProxMox_VM_TimeShift.git
cd ProxMox_VM_TimeShift
chmod +x deploy/*.sh
./deploy/deploy-stack.sh --local --profile full
```