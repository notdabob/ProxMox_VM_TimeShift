#!/bin/bash
# Auto-discover VMs with SSH, present menu, and run fix script automatically
# Usage: ./auto_fix_vm.sh [subnet]
# Example: ./auto_fix_vm.sh 192.168.1.0/24

echo "\nDiscovered SSH-enabled hosts:"
echo ""
echo "[INFO] Executing fix script on $TARGET_IP..."

set -e

SCRIPT_PATH="$(dirname "$0")/fix_vm_network_and_hostname.sh"

if [[ ! -f "$SCRIPT_PATH" ]]; then
    echo "[ERROR] fix_vm_network_and_hostname.sh not found in $(dirname "$0")"
    exit 1
fi

if ! command -v nmap &>/dev/null; then
    echo "[INFO] Installing nmap for network scanning..."
    sudo apt-get update && sudo apt-get install -y nmap
fi

SUBNET="$1"
if [[ -z "$SUBNET" ]]; then
    # Try to auto-detect local subnet
    DEFAULT_SUBNET=$(ip route | awk '/src/ {print $1; exit}')
    if [[ -n "$DEFAULT_SUBNET" ]]; then
        SUBNET="$DEFAULT_SUBNET"
    else
        echo "[ERROR] Could not auto-detect subnet. Please provide as argument."
        exit 1
    fi
fi

echo "[INFO] Scanning subnet $SUBNET for SSH-enabled hosts..."
SCAN_RESULTS=$(nmap -p 22 --open --min-rate=500 "$SUBNET" | grep 'Nmap scan report for' | awk '{print $5}')

HOSTS=()
for ip in $SCAN_RESULTS; do
    HOSTS+=("$ip")
done

if [[ ${#HOSTS[@]} -eq 0 ]]; then
    echo "[ERROR] No SSH-enabled hosts found on $SUBNET."
    exit 1
fi

TARGET_IP="${HOSTS[0]}"
echo "[INFO] Automatically selecting first discovered host: $TARGET_IP"
echo "[INFO] Copying fix script to $TARGET_IP..."
scp "$SCRIPT_PATH" root@"$TARGET_IP":/tmp/

echo "[INFO] Executing fix script on $TARGET_IP..."
ssh root@"$TARGET_IP" 'bash /tmp/fix_vm_network_and_hostname.sh'
