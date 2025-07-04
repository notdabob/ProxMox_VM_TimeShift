#!/bin/bash
# VM Network Troubleshooting Script
# Helps diagnose and fix network connectivity issues for ProxMox VMs

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
        if qm agent "$vmid" ping &>/dev/null; then
            print_success "Guest agent is responding"
        else
            print_warning "Guest agent is not responding"
            if [[ "$FIX_ISSUES" == "true" ]]; then
                print_status "Guest agent may not be installed in the VM"
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
    
    # Try to get VM IP using guest agent
    print_status "Attempting to get VM IP address..."
    
    local vm_ip=""
    local attempts=0
    local max_attempts=5
    
    while [[ $attempts -lt $max_attempts ]]; do
        if qm agent "$vmid" ping &>/dev/null; then
            vm_ip=$(qm guest cmd "$vmid" network-get-interfaces 2>/dev/null | \
                grep -Eo '"ip-address": "([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)"' | \
                grep -v '127.0.0.1' | head -n1 | cut -d'"' -f4)
            
            if [[ -n "$vm_ip" ]]; then
                print_success "VM IP detected: $vm_ip"
                break
            fi
        fi
        
        attempts=$((attempts + 1))
        if [[ $attempts -lt $max_attempts ]]; then
            print_status "Waiting for network... (attempt $attempts/$max_attempts)"
            sleep 5
        fi
    done
    
    if [[ -z "$vm_ip" ]]; then
        print_error "Could not detect VM IP address"
        print_warning "Possible causes:"
        print_warning "  - VM network is not configured"
        print_warning "  - QEMU Guest Agent is not installed"
        print_warning "  - VM is still booting"
        print_warning "  - DHCP server is not responding"
        
        if [[ "$FIX_ISSUES" == "true" ]]; then
            print_status "Attempting alternative detection methods..."
            
            # Try to get MAC address and check DHCP leases
            local mac=$(qm config "$vmid" | grep -oP 'net0:.*mac=\K[^,]+')
            if [[ -n "$mac" ]]; then
                print_status "VM MAC address: $mac"
                
                # Check if dnsmasq is running
                if systemctl is-active dnsmasq &>/dev/null; then
                    local lease_ip=$(grep -i "$mac" /var/lib/misc/dnsmasq.leases | awk '{print $3}')
                    if [[ -n "$lease_ip" ]]; then
                        print_success "Found DHCP lease: $lease_ip"
                        vm_ip="$lease_ip"
                    fi
                fi
            fi
        fi
    fi
    
    # If we have an IP, test connectivity
    if [[ -n "$vm_ip" ]]; then
        print_status "Testing connectivity to VM..."
        
        if ping -c 3 -W 2 "$vm_ip" &>/dev/null; then
            print_success "VM is reachable via ping"
            
            # Test SSH
            if nc -z -w 2 "$vm_ip" 22 &>/dev/null; then
                print_success "SSH port (22) is open"
            else
                print_warning "SSH port (22) is not responding"
            fi
        else
            print_error "VM is not reachable via ping"
            
            if [[ "$FIX_ISSUES" == "true" ]]; then
                print_status "Checking ARP table..."
                arp -n | grep "$vm_ip" || print_warning "VM IP not in ARP table"
            fi
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