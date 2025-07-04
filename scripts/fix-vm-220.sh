#!/bin/bash
# Fix script for VM 220 network and installation issues

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

VMID=220

echo -e "${BLUE}=== Fixing VM 220 Network and Installation Issues ===${NC}"

# Step 1: Check if VM exists and is running
echo -e "${YELLOW}[1/7]${NC} Checking VM status..."
if ! qm status $VMID &>/dev/null; then
    echo -e "${RED}VM $VMID does not exist${NC}"
    exit 1
fi

VM_STATUS=$(qm status $VMID | grep -oP 'status: \K\w+')
echo "VM Status: $VM_STATUS"

if [[ "$VM_STATUS" != "running" ]]; then
    echo -e "${YELLOW}Starting VM $VMID...${NC}"
    qm start $VMID
    sleep 10
fi

# Step 2: Get VM MAC address and bridge
echo -e "${YELLOW}[2/7]${NC} Getting VM network configuration..."
VM_CONFIG=$(qm config $VMID)
MAC_ADDR=$(echo "$VM_CONFIG" | grep -oP 'net0:.*mac=\K[^,]+' || echo "")
BRIDGE=$(echo "$VM_CONFIG" | grep -oP 'net0:.*bridge=\K[^,]+' || echo "vmbr0")

echo "MAC Address: $MAC_ADDR"
echo "Bridge: $BRIDGE"

# Step 3: Try to get IP from DHCP leases
echo -e "${YELLOW}[3/7]${NC} Checking DHCP leases..."
if [[ -n "$MAC_ADDR" ]]; then
    # Check dnsmasq leases
    if [[ -f /var/lib/misc/dnsmasq.leases ]]; then
        IP=$(grep -i "$MAC_ADDR" /var/lib/misc/dnsmasq.leases | awk '{print $3}' | head -n1)
    fi
    
    # Check dhcp leases
    if [[ -z "$IP" && -f /var/lib/dhcp/dhcpd.leases ]]; then
        IP=$(grep -A 10 -i "$MAC_ADDR" /var/lib/dhcp/dhcpd.leases | grep -oP 'lease \K[0-9.]+' | head -n1)
    fi
fi

# Step 4: Try ARP table
if [[ -z "$IP" ]]; then
    echo -e "${YELLOW}[4/7]${NC} Checking ARP table..."
    IP=$(arp -n | grep -i "$MAC_ADDR" | awk '{print $1}' | head -n1)
fi

# Step 5: Access VM console to fix networking
if [[ -z "$IP" ]]; then
    echo -e "${YELLOW}[5/7]${NC} No IP detected. Attempting console access fix..."
    
    # Create a script to run inside the VM
    cat > /tmp/fix-vm-network.sh << 'EOF'
#!/bin/bash
# Fix network inside VM

# Configure DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 1.1.1.1" >> /etc/resolv.conf

# Bring up network interface
ip link set eth0 up 2>/dev/null || ip link set ens18 up 2>/dev/null || true

# Request DHCP
dhclient -v eth0 2>/dev/null || dhclient -v ens18 2>/dev/null || true

# Update package lists with working mirrors
cat > /etc/apt/sources.list << 'APT_EOF'
deb http://deb.debian.org/debian/ bookworm main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security bookworm-security main contrib non-free non-free-firmware
deb http://deb.debian.org/debian/ bookworm-updates main contrib non-free non-free-firmware
APT_EOF

# Try updating with timeout
timeout 30 apt-get update || true

# Install essential packages
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    qemu-guest-agent \
    curl \
    ca-certificates \
    gnupg \
    lsb-release \
    docker.io \
    docker-compose || true

# Enable and start guest agent
systemctl enable qemu-guest-agent
systemctl start qemu-guest-agent

# Print IP
ip addr show
EOF

    echo -e "${BLUE}Manual intervention required:${NC}"
    echo "1. Run: qm terminal $VMID"
    echo "2. Login as root"
    echo "3. Run: bash < /tmp/fix-vm-network.sh"
    echo "4. Exit console with Ctrl+]"
    echo ""
    read -p "Press Enter after completing the above steps..."
fi

# Step 6: Try to detect IP again
echo -e "${YELLOW}[6/7]${NC} Attempting to detect IP address again..."
for i in {1..10}; do
    VM_IP=$(qm guest cmd $VMID network-get-interfaces 2>/dev/null | \
        grep -Eo '"ip-address": "([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)"' | \
        grep -v '127.0.0.1' | head -n1 | cut -d'"' -f4)
    
    if [[ -n "$VM_IP" ]]; then
        echo -e "${GREEN}IP detected: $VM_IP${NC}"
        break
    fi
    
    echo "Waiting for network... (attempt $i/10)"
    sleep 3
done

# Step 7: Save VM info
if [[ -n "$VM_IP" ]]; then
    echo -e "${YELLOW}[7/7]${NC} Saving VM information..."
    cat > /tmp/vm-${VMID}-info.json << EOF
{
    "vmid": "$VMID",
    "ip": "$VM_IP",
    "mac": "$MAC_ADDR",
    "bridge": "$BRIDGE",
    "timestamp": "$(date -Iseconds)"
}
EOF
    echo -e "${GREEN}VM information saved to /tmp/vm-${VMID}-info.json${NC}"
    echo -e "${GREEN}✓ VM $VMID is now accessible at $VM_IP${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Clone the repository on the VM:"
    echo "   ssh root@$VM_IP"
    echo "   git clone https://github.com/notdabob/ProxMox_VM_TimeShift.git"
    echo "   cd ProxMox_VM_TimeShift"
    echo "   chmod +x deploy/*.sh"
    echo "   ./deploy/deploy-stack.sh --vmid $VMID --profile full --local"
else
    echo -e "${RED}Could not detect VM IP address${NC}"
    echo "Please check VM console and ensure networking is configured"
fi