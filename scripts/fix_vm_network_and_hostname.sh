#!/bin/bash
# Automated Proxmox VM Fix Script
# This script should be run inside the target VM (e.g., VMID 220)
# It will:
#   1. Fix the hostname if it contains invalid characters
#   2. Install and enable the QEMU guest agent
#   3. Reboot the VM if needed

set -e

# 1. Fix hostname if needed
HOSTNAME=$(hostname)
if [[ ! "$HOSTNAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
    # Try to extract VMID from /etc/hostname or fallback to 'homelab-vm'
    VMID=""
    if [[ -f /etc/hostname ]]; then
        VMID=$(grep -oE '[0-9]{2,4}' /etc/hostname | head -n1)
    fi
    if [[ -z "$VMID" ]]; then
        VMID=$(echo "$HOSTNAME" | grep -oE '[0-9]{2,4}' | head -n1)
    fi
    if [[ -n "$VMID" ]]; then
        NEW_HOSTNAME="homelab-vm$VMID"
    else
        NEW_HOSTNAME="homelab-vm"
    fi
    echo "[INFO] Invalid hostname detected: $HOSTNAME"
    echo "[INFO] Setting hostname to: $NEW_HOSTNAME"
    sudo hostnamectl set-hostname "$NEW_HOSTNAME"
    sudo sed -i "s/$HOSTNAME/$NEW_HOSTNAME/g" /etc/hosts || true
    sudo sed -i "s/$HOSTNAME/$NEW_HOSTNAME/g" /etc/hostname || true
    HOSTNAME_CHANGED=1
else
    echo "[INFO] Hostname is valid: $HOSTNAME"
    HOSTNAME_CHANGED=0
fi

# 2. Install and enable QEMU guest agent
if ! pgrep -x "qemu-ga" >/dev/null 2>&1; then
    echo "[INFO] Installing QEMU guest agent..."
    sudo apt-get update
    sudo apt-get install -y qemu-guest-agent
    sudo systemctl enable --now qemu-guest-agent
    QGA_INSTALLED=1
else
    echo "[INFO] QEMU guest agent is already running."
    QGA_INSTALLED=0
fi

# 3. Reboot if hostname was changed or guest agent was just installed
if [[ $HOSTNAME_CHANGED -eq 1 || $QGA_INSTALLED -eq 1 ]]; then
    echo "[INFO] Rebooting VM to apply changes..."
    sudo reboot
else
    echo "[INFO] No reboot required."
fi
