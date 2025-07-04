#!/bin/bash

# VS Code Insiders installer for Apple Silicon Macs
# File: install_vscode_insiders.sh

set -e

echo "🚀 Installing Visual Studio Code Insiders for Apple Silicon..."

# Define variables
DOWNLOAD_URL="https://code.visualstudio.com/sha/download?build=insider&os=darwin-arm64"
TEMP_DIR="/tmp/vscode-insiders"
ZIP_FILE="$TEMP_DIR/VSCode-Insiders.zip"
APPLICATIONS_DIR="/Applications"
APP_NAME="Visual Studio Code - Insiders.app"

# Create temporary directory
mkdir -p "$TEMP_DIR"

# Download VS Code Insiders
echo "📥 Downloading VS Code Insiders..."
curl -L "$DOWNLOAD_URL" -o "$ZIP_FILE"

# Verify download
if [[ ! -f "$ZIP_FILE" ]]; then
    echo "❌ Download failed"
    exit 1
fi

echo "✅ Download completed"

# Extract the zip file
echo "📦 Extracting application..."
unzip -q "$ZIP_FILE" -d "$TEMP_DIR"

# Check if app was extracted
if [[ ! -d "$TEMP_DIR/$APP_NAME" ]]; then
    echo "❌ Extraction failed - app not found"
    exit 1
fi

# Remove existing installation if it exists
if [[ -d "$APPLICATIONS_DIR/$APP_NAME" ]]; then
    echo "🗑️  Removing existing VS Code Insiders installation..."
    rm -rf "$APPLICATIONS_DIR/$APP_NAME"
fi

# Move to Applications folder
echo "📁 Installing to Applications folder..."
mv "$TEMP_DIR/$APP_NAME" "$APPLICATIONS_DIR/"

# Set proper permissions
chmod -R 755 "$APPLICATIONS_DIR/$APP_NAME"

# Clean up temporary files
echo "🧹 Cleaning up..."
rm -rf "$TEMP_DIR"

# Verify installation
if [[ -d "$APPLICATIONS_DIR/$APP_NAME" ]]; then
    echo "✅ VS Code Insiders successfully installed!"
    echo "🎉 You can now launch it from Applications or run: open -a 'Visual Studio Code - Insiders'"
else
    echo "❌ Installation failed"
    exit 1
fi

# Optional: Add to PATH if code-insiders command doesn't exist
if ! command -v code-insiders &> /dev/null; then
    echo ""
    echo "💡 To add 'code-insiders' command to your PATH, run:"
    echo "   sudo ln -sf '$APPLICATIONS_DIR/$APP_NAME/Contents/Resources/app/bin/code' /usr/local/bin/code-insiders"
fi

echo ""
echo "🎊 Installation complete!"