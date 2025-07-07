#!/bin/bash
# Unified VM Creation Script for ProxMox Homelab Stack
# Supports MCP, iDRAC, and Hybrid deployments with standardized configuration

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

# Default configuration - standardized across all deployments
DEFAULT_CORES=4
DEFAULT_MEMORY=8192
DEFAULT_DISK=40
DEFAULT_STORAGE="local-lvm"

# VMID ranges for different project types
VMID_RANGES=(
    "mcp:200-209:MCP Server Stack"
    "idrac:210-219:iDRAC Management"
    "hybrid:220-229:Hybrid Stack"
    "timeshift:230-239:Time-Shift Proxy"
)

show_usage() {
    echo "Usage: $0 --type <project_type> [options]"
    echo ""
    echo "Project Types:"
    for range in "${VMID_RANGES[@]}"; do
        IFS=':' read -r type vmids desc <<< "$range"
        printf "  %-12s %s (VMID %s)\n" "$type" "$desc" "$vmids"
    done
    echo ""
    echo "Options:"
    echo "  --type TYPE          Project type (required)"
    echo "  --vmid VMID          Specific VM ID (auto-assigned if not specified)"
    echo "  --hostname NAME      VM hostname (auto-generated if not specified)"
    echo "  --cores N            CPU cores (default: $DEFAULT_CORES)"
    echo "  --memory MB          Memory in MB (default: $DEFAULT_MEMORY)"
    echo "  --disk GB            Disk size in GB (default: $DEFAULT_DISK)"
    echo "  --storage STORAGE    Storage backend (default: $DEFAULT_STORAGE)"
    echo "  --dry-run            Show what would be created without creating"
    echo "  --force              Force creation even if VMID exists"
    echo "  --help               Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 --type mcp"
    echo "  $0 --type idrac --vmid 215 --hostname idrac-mgmt"
    echo "  $0 --type hybrid --cores 6 --memory 12288"
}

get_next_vmid() {
    local type="$1"
    local start_range end_range
    
    for range in "${VMID_RANGES[@]}"; do
        IFS=':' read -r range_type vmids desc <<< "$range"
        if [[ "$range_type" == "$type" ]]; then
            IFS='-' read -r start_range end_range <<< "$vmids"
            break
        fi
    done
    
    if [[ -z "$start_range" ]]; then
        print_error "Invalid project type: $type"
        exit 1
    fi
    
    for ((vmid=start_range; vmid<=end_range; vmid++)); do
        if ! qm status "$vmid" &>/dev/null; then
            echo "$vmid"
            return 0
        fi
    done
    
    print_error "No available VMID in range $start_range-$end_range for type $type"
    exit 1
}

validate_vmid() {
    local vmid="$1"
    local type="$2"
    
    for range in "${VMID_RANGES[@]}"; do
        IFS=':' read -r range_type vmids desc <<< "$range"
        if [[ "$range_type" == "$type" ]]; then
            IFS='-' read -r start_range end_range <<< "$vmids"
            if [[ "$vmid" -ge "$start_range" && "$vmid" -le "$end_range" ]]; then
                return 0
            fi
            print_error "VMID $vmid is outside valid range $start_range-$end_range for type $type"
            exit 1
        fi
    done
}

check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if running on Proxmox
    if [[ ! -f /etc/pve/.version ]]; then
        print_error "This script must be run on a Proxmox VE host"
        exit 1
    fi
    
    # Check required commands
    local required_commands=("qm" "pvesm" "wget")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            print_error "Required command not found: $cmd"
            exit 1
        fi
    done
    
    print_success "Prerequisites check passed"
}

create_vm_config() {
    local type="$1"
    local vmid="$2"
    local hostname="$3"
    local cores="$4"
    local memory="$5"
    local disk="$6"
    local storage="$7"
    
    print_header "Creating VM Configuration"
    print_status "Type: $type"
    print_status "VMID: $vmid"
    print_status "Hostname: $hostname"
    print_status "Cores: $cores"
    print_status "Memory: ${memory}MB"
    print_status "Disk: ${disk}GB"
    print_status "Storage: $storage"
    
    # Create VM using ProxmoxVE Community Script approach
    print_status "Creating VM using ProxmoxVE Community Script..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY RUN: Would create VM with above configuration"
        return 0
    fi
    
    # Use the proven community script approach
    VMID="$vmid" HOSTNAME="$hostname" CORE="$cores" MEMORY="$memory" DISK="$disk" \
    bash -c "$(wget -qLO - https://github.com/community-scripts/ProxmoxVE/raw/main/vm/docker-vm.sh)"
    
    print_success "VM $vmid created successfully"
}

configure_vm_for_type() {
    local type="$1"
    local vmid="$2"
    local hostname="$3"
    
    print_header "Configuring VM for $type deployment"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY RUN: Would configure VM for $type"
        return 0
    fi
    
    # Wait for VM to be ready
    print_status "Waiting for VM to boot..."
    sleep 30
    
    # Get VM IP
    local vm_ip
    for i in {1..10}; do
        # Source shared utilities for IP detection
        local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        local utils_dir="$(dirname "$script_dir")/scripts/utils"
        
        if [[ -f "$utils_dir/vm-network-utils.sh" ]]; then
            source "$utils_dir/vm-network-utils.sh"
            vm_ip=$(detect_vm_ip "$vmid" 3 10)
        else
            # Fallback to original method
            vm_ip=$(qm guest cmd "$vmid" network-get-interfaces 2>/dev/null | \
                grep -Eo '"ip-address": "([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)"' | \
                grep -v '127.0.0.1' | head -n1 | cut -d'"' -f4)
        fi
        
        if [[ -n "$vm_ip" ]]; then
            break
        fi
        print_status "Waiting for network configuration... (attempt $i/10)"
        sleep 10
    done
    
    if [[ -z "$vm_ip" ]]; then
        print_error "Could not detect VM IP address"
        exit 1
    fi
    
    print_success "VM IP detected: $vm_ip"
    
    # Configure based on type
    case "$type" in
        "mcp")
            configure_mcp_vm "$vmid" "$vm_ip"
            ;;
        "idrac")
            configure_idrac_vm "$vmid" "$vm_ip"
            ;;
        "hybrid")
            configure_hybrid_vm "$vmid" "$vm_ip"
            ;;
        "timeshift")
            configure_timeshift_vm "$vmid" "$vm_ip"
            ;;
    esac
    
    # Store VM info for later use
    cat > "/tmp/vm-${vmid}-info.json" << EOF
{
    "vmid": "$vmid",
    "hostname": "$hostname",
    "type": "$type",
    "ip": "$vm_ip",
    "created": "$(date -Iseconds)",
    "status": "ready"
}
EOF
    
    print_success "VM configuration completed"
    print_success "VM Info saved to: /tmp/vm-${vmid}-info.json"
}

configure_mcp_vm() {
    local vmid="$1"
    local vm_ip="$2"
    
    print_status "Configuring MCP services..."
    
    # Install additional packages for MCP
    ssh -o StrictHostKeyChecking=no root@"$vm_ip" \
        "DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y curl jq"
    
    print_success "MCP VM configured - ready for MCP stack deployment"
}

configure_idrac_vm() {
    local vmid="$1"
    local vm_ip="$2"
    
    print_status "Configuring iDRAC management services..."
    
    # Install additional packages for iDRAC management
    ssh -o StrictHostKeyChecking=no root@"$vm_ip" \
        "DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y nmap iputils-ping net-tools"
    
    print_success "iDRAC VM configured - ready for iDRAC container deployment"
}

configure_hybrid_vm() {
    local vmid="$1"
    local vm_ip="$2"
    
    print_status "Configuring hybrid stack services..."
    
    # Install packages for both MCP and iDRAC
    ssh -o StrictHostKeyChecking=no root@"$vm_ip" \
        "DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y curl jq nmap iputils-ping net-tools"
    
    print_success "Hybrid VM configured - ready for full stack deployment"
}

configure_timeshift_vm() {
    local vmid="$1"
    local vm_ip="$2"
    
    print_status "Configuring time-shift proxy services..."
    
    # Install packages for time manipulation and SSL handling
    ssh -o StrictHostKeyChecking=no root@"$vm_ip" \
        "DEBIAN_FRONTEND=noninteractive apt-get update && apt-get install -y ntpdate openssl ca-certificates"
    
    print_success "Time-shift VM configured - ready for time-shift proxy deployment"
}

# Parse command line arguments
TYPE=""
VMID=""
HOSTNAME=""
CORES="$DEFAULT_CORES"
MEMORY="$DEFAULT_MEMORY"
DISK="$DEFAULT_DISK"
STORAGE="$DEFAULT_STORAGE"
DRY_RUN="false"
FORCE="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        --type)
            TYPE="$2"
            shift 2
            ;;
        --vmid)
            VMID="$2"
            shift 2
            ;;
        --hostname)
            HOSTNAME="$2"
            shift 2
            ;;
        --cores)
            CORES="$2"
            shift 2
            ;;
        --memory)
            MEMORY="$2"
            shift 2
            ;;
        --disk)
            DISK="$2"
            shift 2
            ;;
        --storage)
            STORAGE="$2"
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
        --help)
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
if [[ -z "$TYPE" ]]; then
    print_error "Project type is required"
    show_usage
    exit 1
fi

# Validate type
valid_types=()
for range in "${VMID_RANGES[@]}"; do
    IFS=':' read -r type vmids desc <<< "$range"
    valid_types+=("$type")
done

if [[ ! " ${valid_types[*]} " =~ " ${TYPE} " ]]; then
    print_error "Invalid project type: $TYPE"
    print_error "Valid types: ${valid_types[*]}"
    exit 1
fi

# Auto-assign VMID if not specified
if [[ -z "$VMID" ]]; then
    VMID=$(get_next_vmid "$TYPE")
    print_status "Auto-assigned VMID: $VMID"
else
    validate_vmid "$VMID" "$TYPE"
    
    # Check if VMID already exists
    if qm status "$VMID" &>/dev/null && [[ "$FORCE" != "true" ]]; then
        print_error "VMID $VMID already exists. Use --force to override or choose a different VMID"
        exit 1
    fi
fi

# Auto-generate hostname if not specified
if [[ -z "$HOSTNAME" ]]; then
    HOSTNAME="${TYPE}-${VMID}"
    print_status "Auto-generated hostname: $HOSTNAME"
fi

# Main execution
print_header "Unified VM Creation for ProxMox Homelab Stack"

check_prerequisites
create_vm_config "$TYPE" "$VMID" "$HOSTNAME" "$CORES" "$MEMORY" "$DISK" "$STORAGE"
configure_vm_for_type "$TYPE" "$VMID" "$HOSTNAME"

print_header "VM Creation Complete"
print_success "VM $VMID ($HOSTNAME) created and configured for $TYPE deployment"
print_status "Next steps:"
print_status "1. Deploy services: ./deploy-unified-stack.sh --vmid $VMID --type $TYPE"
print_status "2. Monitor services: ./scripts/service-discovery.sh --vmid $VMID"
print_status "3. Access dashboard: Check VM IP in /tmp/vm-${VMID}-info.json"