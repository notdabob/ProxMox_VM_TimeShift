#!/bin/bash

# Remote ProxMox Deployment Script
# Deploys homelab stack to ProxMox host from local machine

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_header() { echo -e "${CYAN}=== $1 ===${NC}"; }

# Configuration
PROXMOX_IP=""
VMID="220"
PROFILE="full"
VM_CORES="4"
VM_MEMORY="8192"
VM_DISK="40"
DRY_RUN="false"
FORCE="false"
SKIP_TRANSFER="false"

show_usage() {
    cat << EOF
Remote ProxMox Deployment Script

Usage: $0 --proxmox-ip IP [OPTIONS]

Required:
  --proxmox-ip IP         ProxMox host IP address

Options:
  --vmid ID              VM ID to create (default: 220)
  --profile PROFILE      Deployment profile: mcp|idrac|timeshift|monitoring|full (default: full)
  --cores N              VM CPU cores (default: 4)
  --memory MB            VM memory in MB (default: 8192)
  --disk GB              VM disk size in GB (default: 40)
  --dry-run              Show what would be done without executing
  --force                Force deployment even if VM exists
  --skip-transfer        Skip file transfer (assume files already on ProxMox)
  --help                 Show this help message

Examples:
  $0 --proxmox-ip 192.168.1.100
  $0 --proxmox-ip 192.168.1.100 --vmid 225 --profile mcp
  $0 --proxmox-ip 192.168.1.100 --cores 6 --memory 12288 --dry-run
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --proxmox-ip)
            PROXMOX_IP="$2"
            shift 2
            ;;
        --vmid)
            VMID="$2"
            shift 2
            ;;
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        --cores)
            VM_CORES="$2"
            shift 2
            ;;
        --memory)
            VM_MEMORY="$2"
            shift 2
            ;;
        --disk)
            VM_DISK="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --force)
            FORCE="true"
            shift
            ;;
        --skip-transfer)
            SKIP_TRANSFER="true"
            shift
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$PROXMOX_IP" ]]; then
    print_error "ProxMox IP address is required"
    show_usage
    exit 1
fi

# Validate profile
VALID_PROFILES=("mcp" "idrac" "timeshift" "monitoring" "full")
if [[ ! " ${VALID_PROFILES[*]} " =~ " ${PROFILE} " ]]; then
    print_error "Invalid profile: $PROFILE"
    print_error "Valid profiles: ${VALID_PROFILES[*]}"
    exit 1
fi

print_header "Remote ProxMox Homelab Deployment"
echo "Target: $PROXMOX_IP"
echo "VMID: $VMID"
echo "Profile: $PROFILE"
echo "Resources: ${VM_CORES} cores, ${VM_MEMORY}MB RAM, ${VM_DISK}GB disk"
if [[ "$DRY_RUN" == "true" ]]; then
    print_warning "DRY RUN MODE - No changes will be made"
fi
echo

# Test SSH connectivity
test_ssh_connection() {
    print_info "Testing SSH connection to $PROXMOX_IP..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY RUN: Would test SSH connection"
        return 0
    fi
    
    if ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no root@"$PROXMOX_IP" "echo 'SSH connection successful'" >/dev/null 2>&1; then
        print_success "SSH connection successful"
    else
        print_error "Cannot connect to ProxMox host via SSH"
        print_error "Please ensure:"
        print_error "  - ProxMox host is accessible at $PROXMOX_IP"
        print_error "  - SSH is enabled on ProxMox"
        print_error "  - Root SSH access is configured"
        exit 1
    fi
}

# Transfer deployment files
transfer_files() {
    if [[ "$SKIP_TRANSFER" == "true" ]]; then
        print_info "Skipping file transfer (--skip-transfer specified)"
        return 0
    fi
    
    print_info "Transferring deployment files to ProxMox host..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY RUN: Would transfer files to $PROXMOX_IP:/root/homelab-deployment/"
        return 0
    fi
    
    # Create deployment directory on ProxMox
    ssh -o StrictHostKeyChecking=no root@"$PROXMOX_IP" "mkdir -p /root/homelab-deployment"
    
    # Transfer files
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
    
    # Use rsync if available, otherwise scp
    if command -v rsync >/dev/null 2>&1; then
        rsync -avz --exclude='.git' --exclude='*.log' --exclude='tmp_*' \
            "$PROJECT_ROOT/" root@"$PROXMOX_IP":/root/homelab-deployment/
    else
        scp -r -o StrictHostKeyChecking=no \
            "$PROJECT_ROOT/deploy" \
            "$PROJECT_ROOT/docker" \
            "$PROJECT_ROOT/config" \
            "$PROJECT_ROOT/scripts" \
            "$PROJECT_ROOT/.env" \
            "$PROJECT_ROOT/DEPLOYMENT-READY.md" \
            "$PROJECT_ROOT/DEPLOYMENT-CHECKLIST.md" \
            root@"$PROXMOX_IP":/root/homelab-deployment/
    fi
    
    # Make scripts executable
    ssh -o StrictHostKeyChecking=no root@"$PROXMOX_IP" \
        "find /root/homelab-deployment -name '*.sh' -exec chmod +x {} \;"
    
    print_success "Files transferred successfully"
}

# Create VM on ProxMox
create_vm() {
    print_info "Creating VM $VMID on ProxMox host..."
    
    local force_flag=""
    if [[ "$FORCE" == "true" ]]; then
        force_flag="--force"
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY RUN: Would create VM with command:"
        echo "  ./deploy/create-vm.sh --type hybrid --vmid $VMID --cores $VM_CORES --memory $VM_MEMORY --disk $VM_DISK $force_flag"
        return 0
    fi
    
    # Execute VM creation on ProxMox
    ssh -o StrictHostKeyChecking=no root@"$PROXMOX_IP" \
        "cd /root/homelab-deployment && ./deploy/create-vm.sh --type hybrid --vmid $VMID --cores $VM_CORES --memory $VM_MEMORY --disk $VM_DISK $force_flag"
    
    print_success "VM $VMID created successfully"
}

# Deploy services
deploy_services() {
    print_info "Deploying services with profile: $PROFILE..."
    
    local force_flag=""
    if [[ "$FORCE" == "true" ]]; then
        force_flag="--force"
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY RUN: Would deploy services with command:"
        echo "  ./deploy/deploy-stack.sh --vmid $VMID --profile $PROFILE $force_flag"
        return 0
    fi
    
    # Execute service deployment on ProxMox
    ssh -o StrictHostKeyChecking=no root@"$PROXMOX_IP" \
        "cd /root/homelab-deployment && ./deploy/deploy-stack.sh --vmid $VMID --profile $PROFILE $force_flag"
    
    print_success "Services deployed successfully"
}

# Get VM information
get_vm_info() {
    print_info "Retrieving VM information..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY RUN: Would retrieve VM information"
        echo "Expected VM IP: 192.168.1.$VMID (or auto-assigned)"
        return 0
    fi
    
    # Get VM info from ProxMox
    VM_INFO=$(ssh -o StrictHostKeyChecking=no root@"$PROXMOX_IP" \
        "cat /tmp/vm-${VMID}-info.json 2>/dev/null || echo '{}'")
    
    VM_IP=$(echo "$VM_INFO" | jq -r '.ip // "unknown"' 2>/dev/null || echo "unknown")
    
    if [[ "$VM_IP" != "unknown" && "$VM_IP" != "null" ]]; then
        print_success "VM IP detected: $VM_IP"
        
        echo
        print_header "Deployment Complete!"
        echo "🎉 Your homelab services are now running!"
        echo
        echo "📊 Access your services:"
        echo "  🌐 Main Dashboard:    http://$VM_IP:9010"
        echo "  🖥️  iDRAC Manager:     http://$VM_IP:8080"
        echo "  🔧 MCP Services:      http://$VM_IP:7001-7003"
        echo "  ⏰ Time-Shift Proxy:  http://$VM_IP:8765"
        echo
        echo "🔍 Monitor services:"
        echo "  ssh root@$PROXMOX_IP 'cd /root/homelab-deployment && ./deploy/service-discovery.sh --status --vmid $VMID'"
        echo
        echo "📋 View logs:"
        echo "  ssh root@$PROXMOX_IP 'cd /root/homelab-deployment && tail -f deployment.log'"
    else
        print_warning "Could not detect VM IP automatically"
        echo "Check VM status manually: ssh root@$PROXMOX_IP 'qm status $VMID'"
    fi
}

# Main execution
main() {
    test_ssh_connection
    transfer_files
    create_vm
    deploy_services
    get_vm_info
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo
        print_info "DRY RUN completed. No changes were made."
        print_info "Remove --dry-run flag to execute the actual deployment."
    fi
}

# Run main function
main