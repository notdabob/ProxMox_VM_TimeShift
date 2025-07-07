#!/bin/bash
# VM Network Utilities
# Shared functions for VM IP detection and network operations

# Get script directory and load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source configuration loader if available
if [[ -f "$SCRIPT_DIR/config-loader.sh" ]]; then
    source "$SCRIPT_DIR/config-loader.sh"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration defaults (can be overridden by config files)
DEFAULT_SUBNET="${HOMELAB_DEFAULT_SUBNET:-192.168.1.0/24}"
DEFAULT_GATEWAY="${HOMELAB_DEFAULT_GATEWAY:-192.168.1.1}"
BIND_ADDRESS="${HOMELAB_BIND_ADDRESS:-0.0.0.0}"

# Function to detect VM IP address using guest agent
# Usage: util_detect_vm_ip <vmid> [max_attempts] [timeout_per_attempt]
util_detect_vm_ip() {
    local vmid="$1"
    local max_attempts="${2:-5}"
    local timeout_per_attempt="${3:-15}"
    local vm_ip=""
    local attempts=0
    
    if [[ -z "$vmid" ]]; then
        print_error "VM ID is required"
        return 1
    fi
    
    print_status "Detecting IP for VM $vmid..."
    
    while [[ $attempts -lt $max_attempts ]]; do
        attempts=$((attempts + 1))
        
        # Check if guest agent is responding
        if timeout 10 qm agent "$vmid" ping &>/dev/null; then
            local network_data
            if network_data=$(timeout "$timeout_per_attempt" qm guest cmd "$vmid" network-get-interfaces 2>/dev/null); then
                vm_ip=$(echo "$network_data" | \
                    grep -Eo '"ip-address": "([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)"' | \
                    grep -v '127.0.0.1' | head -n1 | cut -d'"' -f4)
                
                if [[ -n "$vm_ip" ]]; then
                    print_success "VM IP detected: $vm_ip"
                    echo "$vm_ip"
                    return 0
                fi
            else
                print_warning "Failed to get network interfaces from guest agent (attempt $attempts/$max_attempts)"
            fi
        else
            print_warning "Guest agent not responding (attempt $attempts/$max_attempts)"
        fi
        
        if [[ $attempts -lt $max_attempts ]]; then
            print_status "Waiting 5 seconds before retry..."
            sleep 5
        fi
    done
    
    print_error "Could not detect VM IP after $max_attempts attempts"
    return 1
}

# Function to detect VM IP using alternative methods (DHCP leases, ARP)
# Usage: util_detect_vm_ip_alternative <vmid>
util_detect_vm_ip_alternative() {
    local vmid="$1"
    local vm_ip=""
    
    if [[ -z "$vmid" ]]; then
        print_error "VM ID is required"
        return 1
    fi
    
    print_status "Attempting alternative IP detection methods for VM $vmid..."
    
    # Get MAC address from VM config
    local mac=$(qm config "$vmid" 2>/dev/null | grep -oP 'net0:.*mac=\K[^,]+')
    if [[ -z "$mac" ]]; then
        print_error "Could not get MAC address from VM config"
        return 1
    fi
    
    print_status "VM MAC address: $mac"
    
    # Check dnsmasq leases
    if [[ -f /var/lib/misc/dnsmasq.leases ]]; then
        vm_ip=$(grep -i "$mac" /var/lib/misc/dnsmasq.leases 2>/dev/null | awk '{print $3}' | head -n1)
        if [[ -n "$vm_ip" ]]; then
            print_success "Found IP in dnsmasq leases: $vm_ip"
            echo "$vm_ip"
            return 0
        fi
    fi
    
    # Check dhcp leases
    if [[ -f /var/lib/dhcp/dhcpd.leases ]]; then
        vm_ip=$(grep -A 10 -i "$mac" /var/lib/dhcp/dhcpd.leases 2>/dev/null | grep -oP 'lease \K[0-9.]+' | head -n1)
        if [[ -n "$vm_ip" ]]; then
            print_success "Found IP in DHCP leases: $vm_ip"
            echo "$vm_ip"
            return 0
        fi
    fi
    
    # Check ARP table
    vm_ip=$(arp -n 2>/dev/null | grep -i "$mac" | awk '{print $1}' | head -n1)
    if [[ -n "$vm_ip" ]]; then
        print_success "Found IP in ARP table: $vm_ip"
        echo "$vm_ip"
        return 0
    fi
    
    print_error "Could not detect VM IP using alternative methods"
    return 1
}

# Function to test VM connectivity
# Usage: util_test_vm_connectivity <ip> [ssh_port]
util_test_vm_connectivity() {
    local vm_ip="$1"
    local ssh_port="${2:-22}"
    
    if [[ -z "$vm_ip" ]]; then
        print_error "VM IP is required"
        return 1
    fi
    
    print_status "Testing connectivity to $vm_ip..."
    
    # Test ping
    if ping -c 3 -W 2 "$vm_ip" &>/dev/null; then
        print_success "VM is reachable via ping"
        
        # Test SSH
        if command -v nc &>/dev/null; then
            if nc -z -w 2 "$vm_ip" "$ssh_port" &>/dev/null; then
                print_success "SSH port ($ssh_port) is open"
                return 0
            else
                print_warning "SSH port ($ssh_port) is not responding"
                return 1
            fi
        else
            print_warning "netcat not available, skipping SSH port check"
            return 0
        fi
    else
        print_error "VM is not reachable via ping"
        return 1
    fi
}

# Function to save VM information to a JSON file
# Usage: util_save_vm_info <vmid> <ip> [mac] [bridge]
util_save_vm_info() {
    local vmid="$1"
    local vm_ip="$2"
    local mac="${3:-}"
    local bridge="${4:-}"
    local info_file="/tmp/vm-${vmid}-info.json"
    
    if [[ -z "$vmid" || -z "$vm_ip" ]]; then
        print_error "VM ID and IP are required"
        return 1
    fi
    
    # Get additional info if not provided
    if [[ -z "$mac" || -z "$bridge" ]]; then
        local vm_config=$(qm config "$vmid" 2>/dev/null)
        if [[ -n "$vm_config" ]]; then
            [[ -z "$mac" ]] && mac=$(echo "$vm_config" | grep -oP 'net0:.*mac=\K[^,]+' || echo "unknown")
            [[ -z "$bridge" ]] && bridge=$(echo "$vm_config" | grep -oP 'net0:.*bridge=\K[^,]+' || echo "unknown")
        fi
    fi
    
    cat > "$info_file" << EOF
{
    "vmid": "$vmid",
    "ip": "$vm_ip",
    "mac": "$mac",
    "bridge": "$bridge",
    "timestamp": "$(date -Iseconds)",
    "detected_by": "vm-network-utils"
}
EOF
    
    print_success "VM information saved to $info_file"
    return 0
}

# Function to load VM information from JSON file
# Usage: util_load_vm_info <vmid>
util_load_vm_info() {
    local vmid="$1"
    local info_file="/tmp/vm-${vmid}-info.json"
    
    if [[ -z "$vmid" ]]; then
        print_error "VM ID is required"
        return 1
    fi
    
    if [[ -f "$info_file" ]]; then
        cat "$info_file"
        return 0
    else
        print_error "VM info file not found: $info_file"
        return 1
    fi
}