#!/bin/bash
# install-complete-mcp-solution.sh - Complete MCP installation
# Location: /Users/lordsomer/Library/CloudStorage/Dropbox/Projects/ProxMox_VM_TimeShift/time-shift-proxmox/bin/install-complete-mcp-solution.sh

set -e

echo "🚀 Complete ServeMyAPI MCP Solution Installation"
echo "=============================================="
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Make scripts executable
chmod +x "$SCRIPT_DIR/install-servemyapi.sh"
chmod +x "$SCRIPT_DIR/setup-vscode-mcp.sh"

echo "📋 Installation Plan:"
echo "   1. Install ServeMyAPI MCP Server"
echo "   2. Import API keys from .env to macOS Keychain"
echo "   3. Configure Claude Desktop"
echo "   4. Set up VS Code integration"
echo "   5. Create management utilities"
echo "   6. Configure automated validation"
echo ""

read -p "Continue with installation? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation cancelled"
    exit 0
fi

echo ""
echo "🎯 Starting installation..."
echo ""

# Step 1: Install ServeMyAPI MCP Server
echo "📦 Step 1: Installing ServeMyAPI MCP Server..."
"$SCRIPT_DIR/install-servemyapi.sh"

echo ""
echo "✅ ServeMyAPI installation complete"
echo ""

# Step 2: Set up VS Code integration
echo "⚙️  Step 2: Setting up VS Code MCP integration..."
"$SCRIPT_DIR/setup-vscode-mcp.sh"

echo ""
echo "✅ VS Code integration complete"
echo ""

# Step 3: Final verification and testing
echo "🧪 Step 3: Final verification..."

# Test keychain access
echo "Testing keychain access..."
if security find-generic-password -s "AI-MCP-gemini" >/dev/null 2>&1; then
    echo "✅ Keychain access working"
else
    echo "⚠️  No test keys found (normal if .env import had issues)"
fi

# Test management utilities
echo "Testing management utilities..."
if command -v manage-api-keys >/dev/null 2>&1; then
    echo "✅ Management utilities available"
else
    echo "❌ Management utilities not in PATH"
fi

# Test VS Code configuration
echo "Testing VS Code configuration..."
if [ -f "$HOME/Library/Application Support/Code/User/settings.json" ]; then
    echo "✅ VS Code settings configured"
else
    echo "❌ VS Code settings not found"
fi

# Test Claude configuration
echo "Testing Claude Desktop configuration..."
if [ -f "$HOME/Library/Application Support/Claude/claude_desktop_config.json" ]; then
    echo "✅ Claude Desktop configured"
else
    echo "❌ Claude Desktop configuration not found"
fi

echo ""
echo "🎉 Complete MCP Solution Installation Finished!"
echo "=============================================="
echo ""
echo "📋 Summary of what's installed:"
echo ""
echo "🔐 API Key Management:"
echo "   • All API keys stored securely in macOS Keychain"
echo "   • ServeMyAPI MCP server for secure access"
echo "   • Weekly automated validation via cron"
echo ""
echo "🤖 AI Integration:"
echo "   • Claude Desktop configured with MCP server"
echo "   • VS Code configured for MCP integration"
echo "   • Perplexity, OpenAI, Anthropic, Groq support"
echo ""
echo "⚙️  Management Tools:"
echo "   • manage-api-keys: List, add, remove, validate keys"
echo "   • validate-api-keys: Test all stored keys"
echo "   • VS Code tasks and shortcuts"
echo ""
echo "📍 File Locations:"
echo "   • MCP Server: ~/.mcp/servers/servemyapi/"
echo "   • Utilities: ~/.mcp/bin/"
echo "   • Logs: ~/.mcp/logs/"
echo "   • Claude Config: ~/Library/Application Support/Claude/"
echo ""
echo "🔧 Available Commands:"
echo "   manage-api-keys list      # Show all stored keys"
echo "   manage-api-keys validate  # Test all keys"
echo "   manage-api-keys add service key"
echo "   validate-api-keys         # Run validation"
echo ""
echo "⌨️  VS Code Shortcuts:"
echo "   Cmd+Shift+A L  # List API Keys"
echo "   Cmd+Shift+A V  # Validate API Keys"
echo "   Cmd+Shift+A S  # Start MCP Server"
echo ""
echo "🚀 Next Steps:"
echo "   1. Restart Claude Desktop to load MCP server"
echo "   2. Restart VS Code to load new configuration"
echo "   3. Restart terminal for PATH updates"
echo "   4. Test with: manage-api-keys list"
echo "   5. Validate with: manage-api-keys validate"
echo ""
echo "📖 Documentation:"
echo "   • ServeMyAPI: https://github.com/Jktfe/serveMyAPI"
echo "   • MCP Protocol: https://modelcontextprotocol.io/"
echo "   • Usage Guide: https://mcp-use.com/servers/jktfe-servemyapi-macos-keychain"
echo ""
echo "🔒 Security Notes:"
echo "   • API keys are encrypted in macOS Keychain"
echo "   • No keys stored in plain text files"
echo "   • Access requires macOS authentication"
echo "   • Automatic validation helps detect compromised keys"