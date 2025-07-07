#!/bin/bash
# VM Network Troubleshooting Script
# Helps diagnose and fix network connectivity issues for ProxMox VMs

set -e

# Get script directory and source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"

# Source shared utilities
if [[ -f "$UTILS_DIR/vm-network-utils.sh" ]]; then
    source "$UTILS_DIR/vm-network-utils.sh"
else
    echo "Error: Required utility file not found: $UTILS_DIR/vm-network-utils.sh"
    exit 1
fi

# Additional colors for this script
CYAN='\033[0;36m'
print_header() { echo -e "${CYAN}=== $1 ===${NC}"; }

# Default values
VMID=""
FIX_ISSUES="false"

show_usage() {
    echo "Usage: $0 --vmid <VMID> [options]"
    echo ""
    echo "Options:"
    echo "  --vmid VMID      VM ID to troubleshoot (required)"
    echo "  --fix            Attempt to fix detected issues"
    echo "  --help           Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 --vmid 220"
    echo "  $0 --vmid 220 --fix"
}

check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if running on Proxmox
    if [[ ! -f /etc/pve/.version ]]; then
        print_error "This script must be run on a Proxmox VE host"
        exit 1
    fi
    
    # Check required commands
    local required_commands=("qm" "pvesm" "ip" "brctl")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" &>/dev/null; then
            print_error "Required command not found: $cmd"
            exit 1
        fi
    done
    
    print_success "Prerequisites check passed"
}

check_vm_status() {
    local vmid="$1"
    
    print_header "VM Status Check"
    
    # Check if VM exists
    if ! qm list | grep -q "^\\s*$vmid\\s"; then
        print_error "VM $vmid does not exist"
        return 1
    fi
    
    # Check VM status
    local vm_status=$(qm status "$vmid" | grep -oP 'status: \K\w+')
    print_status "VM $vmid status: $vm_status"
    
    if [[ "$vm_status" != "running" ]]; then
        print_warning "VM is not running"
        if [[ "$FIX_ISSUES" == "true" ]]; then
            print_status "Attempting to start VM..."
            if qm start "$vmid"; then
                print_success "VM started successfully"
                sleep 10  # Give VM time to boot
            else
                print_error "Failed to start VM"
                return 1
            fi
        else
            print_warning "Use --fix to attempt starting the VM"
            return 1
        fi
    fi
    
    return 0
}

check_vm_config() {
    local vmid="$1"
    
    print_header "VM Configuration Check"
    
    # Get VM config
    local config=$(qm config "$vmid")
    
    # Check network interfaces
    print_status "Network interfaces:"
    echo "$config" | grep -E "^net[0-9]:" || {
        print_error "No network interfaces configured"
        return 1
    }
    
    # Check for common network configuration issues
    local net0=$(echo "$config" | grep "^net0:" | cut -d' ' -f2-)
    if [[ -n "$net0" ]]; then
        print_status "net0: $net0"
        
        # Check if bridge exists
        local bridge=$(echo "$net0" | grep -oP 'bridge=\K[^,]+')
        if [[ -n "$bridge" ]]; then
            if ! ip link show "$bridge" &>/dev/null; then
                print_error "Bridge '$bridge' does not exist"
                return 1
            else
                print_success "Bridge '$bridge' exists"
            fi
        fi
        
        # Check if firewall is enabled
        if echo "$net0" | grep -q "firewall=1"; then
            print_warning "Firewall is enabled on network interface"
        fi
    fi
    
    # Check for qemu-guest-agent
    if echo "$config" | grep -q "agent: 1"; then
        print_status "QEMU Guest Agent is enabled"
        
        # Check if guest agent is responding
        if timeout 10 qm agent "$vmid" ping &>/dev/null; then
            print_success "Guest agent is responding"
        else
            print_warning "Guest agent is not responding"
            if [[ "$FIX_ISSUES" == "true" ]]; then
                print_status "Guest agent may not be installed in the VM"
                print_status "To fix: Install qemu-guest-agent in the VM and restart"
            fi
        fi
    else
        print_warning "QEMU Guest Agent is disabled"
    fi
    
    return 0
}

check_proxmox_network() {
    print_header "ProxMox Network Check"
    
    # List all bridges
    print_status "Available bridges:"
    brctl show
    
    # Check default bridge
    if ip link show vmbr0 &>/dev/null; then
        print_success "Default bridge vmbr0 exists"
        
        # Check bridge IP
        local bridge_ip=$(ip addr show vmbr0 | grep -oP 'inet \K[\d.]+')
        if [[ -n "$bridge_ip" ]]; then
            print_status "Bridge IP: $bridge_ip"
        else
            print_warning "Bridge has no IP address"
        fi
    else
        print_error "Default bridge vmbr0 does not exist"
    fi
    
    # Check routing
    print_status "Default route:"
    ip route | grep default || print_warning "No default route configured"
    
    return 0
}

check_vm_network() {
    local vmid="$1"
    
    print_header "VM Network Connectivity Check"
    
    # Use shared utility function for IP detection
    local vm_ip
    if vm_ip=$(util_detect_vm_ip "$vmid" 5 15); then
        # Test connectivity using shared utility
        util_test_vm_connectivity "$vm_ip"
        
        # Save VM info using shared utility
        util_save_vm_info "$vmid" "$vm_ip"
    else
        print_warning "Primary IP detection failed, trying alternative methods..."
        
        if [[ "$FIX_ISSUES" == "true" ]]; then
            if vm_ip=$(util_detect_vm_ip_alternative "$vmid"); then
                print_status "Testing connectivity with alternative IP..."
                util_test_vm_connectivity "$vm_ip"
                util_save_vm_info "$vmid" "$vm_ip"
            else
                print_error "All IP detection methods failed"
                return 1
            fi
        else
            print_warning "Use --fix to attempt alternative detection methods"
            return 1
        fi
    fi
    
    return 0
}

suggest_fixes() {
    local vmid="$1"
    
    print_header "Suggested Fixes"
    
    echo "1. If VM has no network connectivity:"
    echo "   - Check VM console: qm terminal $vmid"
    echo "   - Inside VM, check network configuration:"
    echo "     - ip addr show"
    echo "     - systemctl status networking"
    echo "     - dhclient -v (to request DHCP)"
    echo ""
    echo "2. If QEMU Guest Agent is not working:"
    echo "   - Install in VM: apt-get install qemu-guest-agent"
    echo "   - Enable service: systemctl enable --now qemu-guest-agent"
    echo ""
    echo "3. If network bridge issues:"
    echo "   - Check ProxMox network config: cat /etc/network/interfaces"
    echo "   - Restart networking: systemctl restart networking"
    echo ""
    echo "4. Force VM network reset:"
    echo "   - qm stop $vmid"
    echo "   - qm set $vmid --delete net0"
    echo "   - qm set $vmid --net0 virtio,bridge=vmbr0"
    echo "   - qm start $vmid"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --vmid)
            VMID="$2"
            shift 2
            ;;
        --fix)
            FIX_ISSUES="true"
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
if [[ -z "$VMID" ]]; then
    print_error "VM ID is required"
    show_usage
    exit 1
fi

# Main execution
print_header "VM Network Troubleshooting for VM $VMID"

check_prerequisites

# Run all checks
check_vm_status "$VMID" || true
check_vm_config "$VMID" || true
check_proxmox_network || true
check_vm_network "$VMID" || true

# Show suggestions
suggest_fixes "$VMID"

print_header "Troubleshooting Complete"