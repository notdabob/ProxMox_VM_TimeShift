#!/bin/bash

# VS Code to VS Code Insiders Migration Script
# This script automates the complete switch from VS Code to VS Code Insiders

set -e  # Exit on any error

echo "🚀 Starting VS Code to VS Code Insiders Migration..."
echo "=================================================="

# Step 1: Check current VS Code installation
echo "📋 Step 1: Checking current VS Code installation..."
if command -v code &> /dev/null; then
    echo "✅ Current VS Code found at: $(which code)"
    code --version
else
    echo "⚠️  VS Code command not found in PATH"
fi

# Step 2: Download and install VS Code Insiders
echo ""
echo "⬇️  Step 2: Downloading VS Code Insiders..."
cd /tmp
curl -L "https://update.code.visualstudio.com/latest/darwin/insider" -o "VSCode-Insiders.zip"

echo "📦 Step 3: Installing VS Code Insiders..."
unzip -q VSCode-Insiders.zip
sudo mv "Visual Studio Code - Insiders.app" /Applications/
rm VSCode-Insiders.zip

# Step 4: Remove old VS Code and create symlinks
echo ""
echo "�️  Step 4: Removing standard VS Code..."
if [ -d "/Applications/Visual Studio Code.app" ]; then
    echo "📁 Backing up and removing standard VS Code..."
    sudo mv "/Applications/Visual Studio Code.app" "/Applications/Visual Studio Code.app.backup-$(date +%Y%m%d-%H%M%S)"
    echo "✅ Standard VS Code moved to backup"
fi

echo "🔗 Step 5: Creating symlink for standard VS Code name..."
sudo ln -sf "/Applications/Visual Studio Code - Insiders.app" "/Applications/Visual Studio Code.app"
echo "✅ Symlink created: 'Visual Studio Code.app' → 'Visual Studio Code - Insiders.app'"

echo "� Step 6: Setting up command line tools..."
sudo mkdir -p /usr/local/bin
sudo ln -sf "/Applications/Visual Studio Code - Insiders.app/Contents/Resources/app/bin/code" /usr/local/bin/code
sudo ln -sf "/Applications/Visual Studio Code - Insiders.app/Contents/Resources/app/bin/code" /usr/local/bin/code-insiders
echo "✅ Both 'code' and 'code-insiders' commands point to Insiders"

# Step 7: Backup and migrate settings
echo ""
echo "💾 Step 7: Backing up and migrating VS Code settings..."

# Backup current settings
VS_CODE_USER_DIR="$HOME/Library/Application Support/Code/User"
VS_CODE_INSIDERS_USER_DIR="$HOME/Library/Application Support/Code - Insiders/User"
BACKUP_DIR="$HOME/Library/Application Support/Code-Backup-$(date +%Y%m%d-%H%M%S)"

if [ -d "$VS_CODE_USER_DIR" ]; then
    echo "📁 Creating backup of current VS Code settings..."
    cp -R "$VS_CODE_USER_DIR" "$BACKUP_DIR"
    echo "✅ Backup created at: $BACKUP_DIR"
    
    echo "🔄 Migrating settings to VS Code Insiders..."
    mkdir -p "$VS_CODE_INSIDERS_USER_DIR"
    cp -R "$VS_CODE_USER_DIR/"* "$VS_CODE_INSIDERS_USER_DIR/"
    echo "✅ Settings migrated successfully"
fi

# Step 8: Migrate extensions
echo ""
echo "🧩 Step 8: Migrating extensions to VS Code Insiders..."

# Get list of installed extensions
if command -v code &> /dev/null; then
    echo "📋 Getting list of current extensions..."
    code --list-extensions > /tmp/vscode-extensions.txt
    
    echo "⬇️  Installing extensions in VS Code Insiders..."
    while read extension; do
        echo "Installing: $extension"
        code --install-extension "$extension" --force
    done < /tmp/vscode-extensions.txt
    
    rm /tmp/vscode-extensions.txt
    echo "✅ Extensions migration completed"
fi

# Step 9: Set VS Code Insiders as default editor
echo ""
echo "🎯 Step 9: Setting VS Code as default editor..."
git config --global core.editor "code --wait"
echo "✅ Git editor set to VS Code (Insiders)"

# Step 10: Create desktop integration
echo ""
echo "🖥️  Step 10: Setting up desktop integration..."
defaults write com.microsoft.VSCode CFBundleURLTypes -array-add '{
    CFBundleURLName = "VS Code URL";
    CFBundleURLSchemes = ("vscode");
}'

# Step 11: Verify installation
echo ""
echo "✅ Step 11: Verifying installation..."
echo "VS Code (Insiders) version:"
code --version

echo ""
echo "🎉 VS Code Insiders Migration Complete!"
echo "======================================"
echo ""
echo "📋 Summary:"
echo "✅ VS Code Insiders installed to /Applications/"
echo "✅ Standard VS Code.app symlinked to Insiders"
echo "✅ Single 'code' command points to Insiders"
echo "✅ Settings and extensions migrated"
echo "✅ Git editor configured"
echo "✅ Desktop integration configured"
echo ""
echo "🔄 Next steps:"
echo "1. Launch with Spotlight: 'Visual Studio Code' or 'Insiders'"
echo "2. Launch with Terminal: 'code .'"
echo "3. Verify all extensions are working"
echo ""
echo "📁 Backup locations:"
echo "   Settings: $BACKUP_DIR"
echo "   Old VS Code: /Applications/Visual Studio Code.app.backup-*"
echo ""
echo "✨ You now have a single VS Code installation running Insiders!"
echo "🗑️  To remove backups later: rm -rf '/Applications/Visual Studio Code.app.backup-*'"
