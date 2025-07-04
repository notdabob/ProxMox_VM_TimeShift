#!/bin/bash

# Fix Dropbox access permissions on macOS
# File: fix_dropbox_permissions.sh

set -e

echo "🔧 Fixing Dropbox access permissions on macOS..."

# Function to check if Terminal has Full Disk Access
check_full_disk_access() {
    echo "📋 Checking Full Disk Access permissions..."
    
    # Try to access a system directory that requires Full Disk Access
    if ls ~/Library/Mail &>/dev/null; then
        echo "✅ Terminal has Full Disk Access"
        return 0
    else
        echo "❌ Terminal needs Full Disk Access"
        return 1
    fi
}

# Function to grant Full Disk Access instructions
grant_full_disk_access() {
    echo ""
    echo "🔐 Terminal needs Full Disk Access to fix Dropbox permissions"
    echo "📝 Please follow these steps:"
    echo ""
    echo "1. Open System Settings (System Preferences on older macOS)"
    echo "2. Go to Privacy & Security → Full Disk Access"
    echo "3. Click the lock icon and enter your password"
    echo "4. Click the '+' button"
    echo "5. Navigate to Applications → Utilities → Terminal"
    echo "6. Select Terminal and click 'Open'"
    echo "7. Make sure Terminal is checked/enabled"
    echo "8. Restart Terminal and run this script again"
    echo ""
    echo "Press Enter after completing these steps..."
    read -r
}

# Function to fix Dropbox permissions
fix_dropbox_permissions() {
    local dropbox_path="$HOME/Dropbox"
    
    if [[ ! -d "$dropbox_path" ]]; then
        echo "❌ Dropbox folder not found at $dropbox_path"
        echo "💡 Please ensure Dropbox is installed and synced"
        exit 1
    fi
    
    echo "📁 Found Dropbox at: $dropbox_path"
    
    # Reset permissions on Dropbox folder
    echo "🔧 Resetting Dropbox folder permissions..."
    sudo chown -R "$USER:staff" "$dropbox_path"
    sudo chmod -R 755 "$dropbox_path"
    
    # Fix extended attributes that might cause issues
    echo "🧹 Clearing problematic extended attributes..."
    sudo xattr -rc "$dropbox_path" 2>/dev/null || true
    
    # Reset ACLs (Access Control Lists)
    echo "🔐 Resetting Access Control Lists..."
    sudo chmod -R -N "$dropbox_path" 2>/dev/null || true
    
    echo "✅ Dropbox permissions fixed!"
}

# Function to restart Dropbox
restart_dropbox() {
    echo "🔄 Restarting Dropbox..."
    
    # Kill Dropbox process
    pkill -f "Dropbox" 2>/dev/null || true
    sleep 2
    
    # Start Dropbox again
    if [[ -f "/Applications/Dropbox.app/Contents/MacOS/Dropbox" ]]; then
        open -a Dropbox
        echo "✅ Dropbox restarted"
    else
        echo "⚠️  Dropbox app not found - please start it manually"
    fi
}

# Function to check and fix SIP (System Integrity Protection) related issues
check_sip_status() {
    echo "🛡️  Checking System Integrity Protection status..."
    sip_status=$(csrutil status 2>/dev/null || echo "unknown")
    echo "SIP Status: $sip_status"
    
    if [[ "$sip_status" == *"enabled"* ]]; then
        echo "✅ SIP is enabled (recommended)"
    else
        echo "⚠️  SIP status unclear - this might affect permissions"
    fi
}

# Main execution
echo "🚀 Starting Dropbox permission fix..."
echo "👤 Current user: $USER"
echo "🏠 Home directory: $HOME"
echo ""

# Check if running with sudo (we don't want that initially)
if [[ $EUID -eq 0 ]]; then
    echo "❌ Don't run this script with sudo initially"
    echo "💡 The script will request sudo when needed"
    exit 1
fi

# Check Full Disk Access
if ! check_full_disk_access; then
    grant_full_disk_access
    
    # Recheck after user says they've granted access
    if ! check_full_disk_access; then
        echo "❌ Full Disk Access still not granted. Please try again."
        exit 1
    fi
fi

# Check SIP status
check_sip_status
echo ""

# Fix Dropbox permissions
fix_dropbox_permissions
echo ""

# Restart Dropbox
restart_dropbox
echo ""

# Final verification
echo "🔍 Verifying fix..."
if ls "$HOME/Dropbox" &>/dev/null; then
    echo "✅ Dropbox access restored!"
    echo "📁 You should now be able to access: $HOME/Dropbox"
else
    echo "❌ Issue persists. You may need to:"
    echo "   1. Restart your Mac"
    echo "   2. Reinstall Dropbox"
    echo "   3. Check System Settings → Privacy & Security → Files and Folders"
fi

echo ""
echo "🎉 Script completed!"
echo "💡 If issues persist, try running: ls -la ~/Dropbox"