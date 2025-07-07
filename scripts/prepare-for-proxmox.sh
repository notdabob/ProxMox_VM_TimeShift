#!/bin/bash

# Prepare ProxMox Deployment Package
# Creates a clean, optimized package for ProxMox deployment

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PACKAGE_DIR="$PROJECT_ROOT/proxmox-deployment-package"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo -e "${BLUE}=== ProxMox Deployment Package Creator ===${NC}"
echo "Creating optimized deployment package for ProxMox..."
echo

# Create package directory
print_info "Creating deployment package directory..."
rm -rf "$PACKAGE_DIR"
mkdir -p "$PACKAGE_DIR"

# Copy essential files
print_info "Copying essential deployment files..."

# Core deployment scripts
mkdir -p "$PACKAGE_DIR/deploy"
cp "$PROJECT_ROOT/deploy"/*.sh "$PACKAGE_DIR/deploy/"

# Docker configuration
mkdir -p "$PACKAGE_DIR/docker/services"
cp "$PROJECT_ROOT/docker/docker-compose.yaml" "$PACKAGE_DIR/docker/"
cp -r "$PROJECT_ROOT/docker/services"/* "$PACKAGE_DIR/docker/services/" 2>/dev/null || true

# Configuration files
mkdir -p "$PACKAGE_DIR/config"
cp "$PROJECT_ROOT/config"/*.yaml "$PACKAGE_DIR/config/" 2>/dev/null || true
cp "$PROJECT_ROOT/.env" "$PACKAGE_DIR/" 2>/dev/null || cp "$PROJECT_ROOT/.env.example" "$PACKAGE_DIR/.env"

# Scripts and utilities
mkdir -p "$PACKAGE_DIR/scripts/utils"
cp "$PROJECT_ROOT/scripts"/*.sh "$PACKAGE_DIR/scripts/" 2>/dev/null || true
cp "$PROJECT_ROOT/scripts/utils"/*.sh "$PACKAGE_DIR/scripts/utils/" 2>/dev/null || true

# Documentation
mkdir -p "$PACKAGE_DIR/docs"
cp "$PROJECT_ROOT/DEPLOYMENT-READY.md" "$PACKAGE_DIR/"
cp "$PROJECT_ROOT/DEPLOYMENT-CHECKLIST.md" "$PACKAGE_DIR/"
cp "$PROJECT_ROOT/docs/TROUBLESHOOTING.md" "$PACKAGE_DIR/docs/" 2>/dev/null || true

# Create deployment info file
cat > "$PACKAGE_DIR/DEPLOYMENT-INFO.txt" << EOF
ProxMox Homelab Deployment Package
Created: $(date)
Version: Production Ready

Network Configuration:
- Docker Networks: 10.20.0.0/24, 10.21.0.0/24, 10.22.0.0/24
- VM Network: 192.168.1.0/24
- No conflicts between Docker and VM networks

Quick Start:
1. Copy this entire directory to your ProxMox host
2. Run: ./deploy/create-vm.sh --type hybrid --vmid 220
3. Run: ./deploy/deploy-stack.sh --vmid 220 --profile full
4. Access: http://VM_IP:9010

Files included:
- deploy/ - VM creation and service deployment scripts
- docker/ - Docker Compose configuration and service definitions
- config/ - Network and service configuration files
- scripts/ - Utility and troubleshooting scripts
- docs/ - Documentation and guides
EOF

# Make all scripts executable
print_info "Setting script permissions..."
find "$PACKAGE_DIR" -name "*.sh" -exec chmod +x {} \;

# Create transfer script
cat > "$PACKAGE_DIR/transfer-to-proxmox.sh" << 'EOF'
#!/bin/bash

# Transfer deployment package to ProxMox host
# Usage: ./transfer-to-proxmox.sh PROXMOX_IP

set -e

PROXMOX_IP="$1"
PACKAGE_NAME="$(basename "$(pwd)")"

if [[ -z "$PROXMOX_IP" ]]; then
    echo "Usage: $0 PROXMOX_IP"
    echo "Example: $0 192.168.1.100"
    exit 1
fi

echo "🚀 Transferring deployment package to ProxMox host: $PROXMOX_IP"
echo

# Test SSH connectivity
echo "Testing SSH connection..."
if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no root@"$PROXMOX_IP" "echo 'SSH connection successful'"; then
    echo "✅ SSH connection successful"
else
    echo "❌ Cannot connect to ProxMox host via SSH"
    echo "Please ensure:"
    echo "  - ProxMox host is accessible"
    echo "  - SSH is enabled"
    echo "  - Root access is available"
    exit 1
fi

# Transfer files
echo "📦 Transferring files..."
scp -r . root@"$PROXMOX_IP":/root/homelab-deployment/

echo "✅ Transfer complete!"
echo
echo "Next steps on ProxMox host ($PROXMOX_IP):"
echo "  ssh root@$PROXMOX_IP"
echo "  cd /root/homelab-deployment"
echo "  ./deploy/create-vm.sh --type hybrid --vmid 220"
echo "  ./deploy/deploy-stack.sh --vmid 220 --profile full"
EOF

chmod +x "$PACKAGE_DIR/transfer-to-proxmox.sh"

# Create package size info
PACKAGE_SIZE=$(du -sh "$PACKAGE_DIR" | cut -f1)
print_success "Deployment package created: $PACKAGE_SIZE"

# Create archive
print_info "Creating compressed archive..."
cd "$PROJECT_ROOT"
tar -czf "proxmox-homelab-deployment-$TIMESTAMP.tar.gz" -C "$(dirname "$PACKAGE_DIR")" "$(basename "$PACKAGE_DIR")"
ARCHIVE_SIZE=$(du -sh "proxmox-homelab-deployment-$TIMESTAMP.tar.gz" | cut -f1)

print_success "Package preparation complete!"
echo
echo "📦 Files created:"
echo "  Directory: $PACKAGE_DIR"
echo "  Archive: proxmox-homelab-deployment-$TIMESTAMP.tar.gz ($ARCHIVE_SIZE)"
echo
echo "🚀 Transfer options:"
echo "  Option 1: Use transfer script"
echo "    cd $PACKAGE_DIR"
echo "    ./transfer-to-proxmox.sh YOUR_PROXMOX_IP"
echo
echo "  Option 2: Manual SCP"
echo "    scp -r $PACKAGE_DIR root@PROXMOX_IP:/root/homelab-deployment"
echo
echo "  Option 3: Archive transfer"
echo "    scp proxmox-homelab-deployment-$TIMESTAMP.tar.gz root@PROXMOX_IP:/root/"
echo "    ssh root@PROXMOX_IP 'cd /root && tar -xzf proxmox-homelab-deployment-$TIMESTAMP.tar.gz'"