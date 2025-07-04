#!/usr/bin/env python3
"""
fix_vscode_insiders.py - Corrects VS Code Insiders installation for native macOS architecture
Location: /usr/local/bin/fix-vscode-insiders
"""

import subprocess
import os
import platform
import shutil
import tempfile
import sys

def get_architecture():
    """Determine macOS architecture with fallback to Universal"""
    arch = platform.machine()
    if arch == "arm64":
        return "arm64"
    elif arch == "x86_64":
        return "x64"
    print(f"⚠️  Unrecognized architecture: {arch}. Using Universal build.")
    return "universal"

def download_and_install():
    """Download and install correct VS Code Insiders build"""
    arch = get_architecture()
    print(f"🔧 Detected architecture: {arch}")

    # Define download URLs
    base_url = "https://update.code.visualstudio.com/latest/darwin"
    url = f"{base_url}/{arch}/insider"

    print(f"📥 Downloading VS Code Insiders for {arch}...")
    print(f"🔗 Source: {url}")

    # Create temp directory
    temp_dir = tempfile.mkdtemp()
    zip_path = os.path.join(temp_dir, "vscode-insiders.zip")

    try:
        # Download using curl
        subprocess.run([
            "curl", "-L", "-o", zip_path, url
        ], check=True)

        # Remove existing installation
        app_path = "/Applications/Visual Studio Code - Insiders.app"
        if os.path.exists(app_path):
            print(f"🗑️  Removing existing installation: {app_path}")
            shutil.rmtree(app_path)

        # Unzip to Applications
        print("📦 Extracting...")
        subprocess.run([
            "unzip", "-q", "-o", zip_path, "-d", "/Applications"
        ], check=True)

        print("✅ Installation complete!")
        print(f"🚀 Launch from: {app_path}")

    except subprocess.CalledProcessError as e:
        print(f"❌ Error: {e}")
        sys.exit(1)
    finally:
        # Clean up
        shutil.rmtree(temp_dir)

def main():
    print("🛠️  Starting VS Code Insiders architecture fix...")
    download_and_install()
    print("✨ Done! Try launching VS Code Insiders now.")

if __name__ == "__main__":
    main()
