# 🚨 Setup Instructions - Repository Mismatch Fix

## ❌ **Issue Identified**

The GitHub repository `https://github.com/notdabob/time-shift-proxmox.git` contains the **original time-shift project**, but **NOT** the unified homelab stack we just created.

## ✅ **Solution Options**

### **Option 1: Use Local Files (Recommended)**

Since you already have the project locally at `/Users/lordsomer/Desktop/ProxMox_VM_TimeShift/`, copy the unified files to your ProxMox host:

```bash
# On your local machine (where you have the unified files)
cd /Users/lordsomer/Desktop/ProxMox_VM_TimeShift/

# Copy the unified stack to your ProxMox host
scp -r scripts/ root@your-proxmox-host:/root/projects/time-shift-proxmox/
scp deploy-unified-stack.sh root@your-proxmox-host:/root/projects/time-shift-proxmox/
scp docker-compose-unified.yaml root@your-proxmox-host:/root/projects/time-shift-proxmox/
scp -r config/ root@your-proxmox-host:/root/projects/time-shift-proxmox/
scp QUICK-START.md root@your-proxmox-host:/root/projects/time-shift-proxmox/
scp README-UNIFIED.md root@your-proxmox-host:/root/projects/time-shift-proxmox/
scp DEPLOYMENT-GUIDE.md root@your-proxmox-host:/root/projects/time-shift-proxmox/

# Then on ProxMox host
ssh root@your-proxmox-host
cd /root/projects/time-shift-proxmox
chmod +x scripts/*.sh deploy-unified-stack.sh
```

### **Option 2: Create Files Directly on ProxMox**

I'll create a setup script that generates all the unified files directly on your ProxMox host.

### **Option 3: Fork and Update Repository**

Fork the repository and add the unified stack files to it.

## 🎯 **Immediate Fix for ProxMox Host**

Run these commands on your ProxMox host to create the missing files:

```bash
cd /root/projects/time-shift-proxmox

# Create scripts directory
mkdir -p scripts config/dashboard

# Create the unified VM creation script
cat > scripts/unified-vm-create.sh << 'EOF'
#!/bin/bash
# Unified VM Creation Script for ProxMox Homelab Stack
# This is a simplified version - full script follows

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() { echo -e "${CYAN}=== $1 ===${NC}"; }

# Default configuration
DEFAULT_CORES=4
DEFAULT_MEMORY=8192
DEFAULT_DISK=40

# VMID ranges
get_next_vmid() {
    local type="$1"
    case "$type" in
        "hybrid") start_range=220; end_range=229 ;;
        "mcp") start_range=200; end_range=209 ;;
        "idrac") start_range=210; end_range=219 ;;
        *) start_range=220; end_range=229 ;;
    esac
    
    for ((vmid=start_range; vmid<=end_range; vmid++)); do
        if ! qm status "$vmid" &>/dev/null; then
            echo "$vmid"
            return 0
        fi
    done
    
    print_error "No available VMID in range $start_range-$end_range"
    exit 1
}

# Parse arguments
TYPE="hybrid"
VMID=""
HOSTNAME=""
CORES="$DEFAULT_CORES"
MEMORY="$DEFAULT_MEMORY"
DISK="$DEFAULT_DISK"

while [[ $# -gt 0 ]]; do
    case $1 in
        --type) TYPE="$2"; shift 2 ;;
        --vmid) VMID="$2"; shift 2 ;;
        --hostname) HOSTNAME="$2"; shift 2 ;;
        --cores) CORES="$2"; shift 2 ;;
        --memory) MEMORY="$2"; shift 2 ;;
        --disk) DISK="$2"; shift 2 ;;
        --help)
            echo "Usage: $0 --type <type> [options]"
            echo "Types: hybrid, mcp, idrac, timeshift"
            echo "Options: --vmid, --hostname, --cores, --memory, --disk"
            exit 0
            ;;
        *) print_error "Unknown option: $1"; exit 1 ;;
    esac
done

# Auto-assign VMID if not specified
if [[ -z "$VMID" ]]; then
    VMID=$(get_next_vmid "$TYPE")
    print_status "Auto-assigned VMID: $VMID"
fi

# Auto-generate hostname if not specified
if [[ -z "$HOSTNAME" ]]; then
    HOSTNAME="${TYPE}-${VMID}"
    print_status "Auto-generated hostname: $HOSTNAME"
fi

print_header "Creating VM $VMID ($HOSTNAME) for $TYPE deployment"
print_status "Cores: $CORES, Memory: ${MEMORY}MB, Disk: ${DISK}GB"

# Use ProxmoxVE Community Script
print_status "Creating VM using ProxmoxVE Community Script..."
VMID="$VMID" HOSTNAME="$HOSTNAME" CORE="$CORES" MEMORY="$MEMORY" DISK="$DISK" \
bash -c "$(wget -qLO - https://github.com/community-scripts/ProxmoxVE/raw/main/vm/docker-vm.sh)"

print_success "VM $VMID created successfully"

# Wait for VM to boot and get IP
print_status "Waiting for VM to boot..."
sleep 30

# Get VM IP
for i in {1..10}; do
    VM_IP=$(qm guest cmd "$VMID" network-get-interfaces 2>/dev/null | \
        grep -Eo '"ip-address": "([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)"' | \
        grep -v '127.0.0.1' | head -n1 | cut -d'"' -f4)
    
    if [[ -n "$VM_IP" ]]; then
        break
    fi
    print_status "Waiting for network configuration... (attempt $i/10)"
    sleep 10
done

if [[ -n "$VM_IP" ]]; then
    print_success "VM IP detected: $VM_IP"
    
    # Store VM info
    cat > "/tmp/vm-${VMID}-info.json" << EOJ
{
    "vmid": "$VMID",
    "hostname": "$HOSTNAME",
    "type": "$TYPE",
    "ip": "$VM_IP",
    "created": "$(date -Iseconds)",
    "status": "ready"
}
EOJ
    
    print_success "VM configuration completed"
    print_status "Next steps:"
    print_status "1. Deploy services: ./deploy-unified-stack.sh --vmid $VMID --type $TYPE"
    print_status "2. Access dashboard: http://$VM_IP:9010 (after deployment)"
else
    print_error "Could not detect VM IP address"
    exit 1
fi
EOF

# Make script executable
chmod +x scripts/unified-vm-create.sh

echo "✅ Created scripts/unified-vm-create.sh"
```

Continue with the next part...

## 🔧 **Next Steps**

1. **Run the immediate fix above** to create the missing script
2. **I'll create the remaining files** in the next response
3. **Test the deployment** with the newly created files

Would you like me to continue creating the remaining files (deploy-unified-stack.sh, docker-compose-unified.yaml, etc.) directly on your ProxMox host?