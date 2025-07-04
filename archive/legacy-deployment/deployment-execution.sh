#!/bin/bash
# Deployment Execution Script
# This script demonstrates the deployment steps but cannot actually execute on ProxMox from this environment

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
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() { echo -e "${CYAN}=== $1 ===${NC}"; }

print_header "ProxMox Homelab Unified Stack Deployment"
print_warning "This script shows the commands you need to run on your ProxMox host"
print_warning "Copy and paste these commands into your ProxMox console"

echo ""
print_header "Step 1: Prerequisites Check"
echo "# Run these commands on your ProxMox host:"
echo "cat /etc/pve/.version"
echo "pvesm status"
echo "free -h"
echo "df -h"

echo ""
print_header "Step 2: Navigate to Project Directory"
echo "# Change to your project directory:"
echo "cd /root/time-shift-proxmox"
echo "# OR if you cloned it elsewhere:"
echo "# cd /path/to/your/time-shift-proxmox"

echo ""
print_header "Step 3: Make Scripts Executable"
echo "# Make all scripts executable:"
echo "chmod +x scripts/*.sh"
echo "chmod +x deploy-unified-stack.sh"

echo ""
print_header "Step 4: Create Unified VM"
echo "# Create a hybrid VM (supports all services):"
echo "./scripts/unified-vm-create.sh --type hybrid"
echo ""
echo "# Alternative options:"
echo "# ./scripts/unified-vm-create.sh --type hybrid --vmid 220 --cores 6 --memory 12288"
echo "# ./scripts/unified-vm-create.sh --type mcp     # MCP services only"
echo "# ./scripts/unified-vm-create.sh --type idrac   # iDRAC management only"

echo ""
print_header "Step 5: Deploy Services"
echo "# Deploy the complete stack (replace 220 with your actual VMID):"
echo "VMID=220  # Use the VMID from step 4"
echo "./deploy-unified-stack.sh --vmid \$VMID --profile full"
echo ""
echo "# Alternative profiles:"
echo "# ./deploy-unified-stack.sh --vmid \$VMID --profile mcp      # MCP only"
echo "# ./deploy-unified-stack.sh --vmid \$VMID --profile idrac    # iDRAC only"
echo "# ./deploy-unified-stack.sh --vmid \$VMID --profile monitoring # Monitoring only"

echo ""
print_header "Step 6: Verify Deployment"
echo "# Register and check service health:"
echo "./scripts/service-discovery.sh --register --vmid \$VMID"
echo "./scripts/service-discovery.sh --health-check --vmid \$VMID"

echo ""
print_header "Step 7: Get Service URLs"
echo "# Get VM IP and display service URLs:"
echo 'VM_IP=$(qm guest cmd $VMID network-get-interfaces | grep -Eo '"'"'"ip-address": "([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)"'"'"' | grep -v '"'"'127.0.0.1'"'"' | head -n1 | cut -d'"'"''"'"' -f4)'
echo 'echo "=== Your Homelab Services ==="'
echo 'echo "Unified Dashboard:    http://$VM_IP:9010"'
echo 'echo "Context7 MCP:         http://$VM_IP:7001"'
echo 'echo "Desktop Commander:    http://$VM_IP:7002"'
echo 'echo "Filesystem MCP:       http://$VM_IP:7003"'
echo 'echo "iDRAC Dashboard:      http://$VM_IP:8080"'
echo 'echo "iDRAC API:            http://$VM_IP:8765"'
echo 'echo "Time-Shift Proxy:     http://$VM_IP:8090"'
echo 'echo "Service Discovery:    http://$VM_IP:9000"'
echo 'echo "Health Monitor:       http://$VM_IP:9001"'

echo ""
print_header "Step 8: Optional - Migrate Existing Deployment"
echo "# If you have existing deployments to migrate:"
echo "./scripts/migrate-legacy.sh --scan"
echo "# ./scripts/migrate-legacy.sh --migrate --source-vmid OLD_VMID --target-type hybrid"

echo ""
print_header "Step 9: Ongoing Management Commands"
echo "# Monitor services continuously:"
echo "./scripts/service-discovery.sh --watch --vmid \$VMID"
echo ""
echo "# Restart services if needed:"
echo "./deploy-unified-stack.sh --vmid \$VMID --profile full --force"
echo ""
echo "# Check service logs:"
echo 'ssh root@$VM_IP "cd /opt/homelab && docker-compose logs -f"'
echo ""
echo "# Rollback if needed:"
echo "./deploy-unified-stack.sh --vmid \$VMID --rollback"

echo ""
print_header "Step 10: Cleanup (After Successful Deployment)"
echo "# Create backup of legacy files:"
echo "mkdir -p /root/legacy-backup"
echo "cp -r proxmox_ve-scripts /root/legacy-backup/"
echo "cp namespace-timeshift-browser-container/deploy-proxmox.sh /root/legacy-backup/"
echo ""
echo "# Remove deprecated files (ONLY after successful deployment):"
echo "rm -f proxmox_ve-scripts/scripts/create_mcp_docker_vm.sh"
echo "rm -f proxmox_ve-scripts/scripts/deploy_mcp_to_docker_vm.sh"
echo "rm -f proxmox_ve-scripts/scripts/one-liner-deploy.sh"
echo "rm -f proxmox_ve-scripts/docker-compose.yaml"
echo "rm -f namespace-timeshift-browser-container/deploy-proxmox.sh"
echo "rm -f namespace-timeshift-browser-container/container-rebuild.sh"

echo ""
print_success "All deployment steps prepared!"
print_status "Copy and paste the commands above into your ProxMox host console"
print_status "Start with Step 1 and work through each step sequentially"