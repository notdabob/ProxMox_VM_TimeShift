#!/bin/bash
# , - Complete ServeMyAPI MCP Server Installation
# Location: /Users/lordsomer/Library/CloudStorage/Dropbox/Projects/ProxMox_VM_TimeShift/time-shift-proxmox/bin/install-servemyapi.sh

set -e

echo "🚀 Installing ServeMyAPI MCP Server for AI Key Management"
echo "========================================================"

# Check prerequisites
echo "🔍 Checking prerequisites..."

# Check Node.js
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is required but not installed"
    echo "Installing Node.js via Homebrew..."
    if ! command -v brew &> /dev/null; then
        echo "❌ Homebrew is required. Please install it first:"
        echo "   /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
    brew install node
fi

# Check npm
if ! command -v npm &> /dev/null; then
    echo "❌ npm is required but not installed"
    exit 1
fi

echo "✅ Node.js $(node --version) and npm $(npm --version) found"

# Create MCP servers directory
MCP_DIR="$HOME/.mcp"
SERVERS_DIR="$MCP_DIR/servers"
SERVEMYAPI_DIR="$SERVERS_DIR/servemyapi"

echo "📁 Creating MCP directory structure..."
mkdir -p "$SERVERS_DIR"

# Clone or update ServeMyAPI
echo "📦 Installing ServeMyAPI MCP Server..."
if [ -d "$SERVEMYAPI_DIR" ]; then
    echo "   Updating existing installation..."
    cd "$SERVEMYAPI_DIR"
    git pull
else
    echo "   Cloning ServeMyAPI repository..."
    git clone https://github.com/Jktfe/serveMyAPI.git "$SERVEMYAPI_DIR"
    cd "$SERVEMYAPI_DIR"
fi

# Install dependencies
echo "📦 Installing Node.js dependencies..."
npm install

# Make executable
chmod +x "$SERVEMYAPI_DIR/index.js"

# Create Claude Desktop configuration
CLAUDE_CONFIG_DIR="$HOME/Library/Application Support/Claude"
CLAUDE_CONFIG_FILE="$CLAUDE_CONFIG_DIR/claude_desktop_config.json"

echo "⚙️  Configuring Claude Desktop..."
mkdir -p "$CLAUDE_CONFIG_DIR"

# Check if config exists and backup
if [ -f "$CLAUDE_CONFIG_FILE" ]; then
    echo "   Backing up existing Claude config..."
    cp "$CLAUDE_CONFIG_FILE" "$CLAUDE_CONFIG_FILE.backup.$(date +%Y%m%d-%H%M%S)"
fi

# Create or update Claude config
cat > "$CLAUDE_CONFIG_FILE" << 'EOF'
{
  "mcpServers": {
    "servemyapi": {
      "command": "node",
      "args": ["/Users/$USER/.mcp/servers/servemyapi/index.js"],
      "env": {}
    }
  }
}
EOF

# Replace $USER placeholder with actual username
sed -i '' "s/\$USER/$USER/g" "$CLAUDE_CONFIG_FILE"

echo "✅ Claude Desktop configured with ServeMyAPI MCP server"

# Import API keys from .env file
ENV_FILE="/Users/lordsomer/Library/CloudStorage/Dropbox/Projects/ProxMox_VM_TimeShift/time-shift-proxmox/.env"

if [ -f "$ENV_FILE" ]; then
    echo "🔐 Importing API keys from .env file to macOS Keychain..."
    
    # Parse .env file and add to keychain
    while IFS='=' read -r key value; do
        # Skip comments and empty lines
        [[ $key =~ ^[[:space:]]*# ]] && continue
        [[ -z $key ]] && continue
        
        # Remove leading/trailing whitespace
        key=$(echo "$key" | xargs)
        value=$(echo "$value" | xargs)
        
        # Skip if value is empty or placeholder
        [[ -z $value ]] && continue
        [[ $value == "your_"*"_here" ]] && continue
        
        # Add to keychain with AI-MCP- prefix
        if [[ $key == *"API_KEY"* ]]; then
            service_name="AI-MCP-$(echo $key | sed 's/_API_KEY//' | tr '[:upper:]' '[:lower:]')"
            
            echo "   Adding $key to keychain as $service_name..."
            
            # Create JSON description
            description="{
              \"service\": \"$(echo $key | sed 's/_API_KEY//' | tr '[:upper:]' '[:lower:]')\",
              \"imported_from\": \"$ENV_FILE\",
              \"imported_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",
              \"managed_by\": \"ServeMyAPI MCP Server\"
            }"
            
            # Add to keychain
            security add-generic-password \
                -s "$service_name" \
                -a "api_key" \
                -w "$value" \
                -j "$description" \
                -U 2>/dev/null || echo "     ⚠️  Key already exists, skipping..."
        fi
        
        # Also add model configurations
        if [[ $key == *"MODEL"* ]]; then
            service_name="AI-MCP-$(echo $key | sed 's/_MODEL//' | tr '[:upper:]' '[:lower:]')"
            
            echo "   Adding $key to keychain as $service_name..."
            
            security add-generic-password \
                -s "$service_name" \
                -a "model" \
                -w "$value" \
                -j "Model configuration for $(echo $key | sed 's/_MODEL//' | tr '[:upper:]' '[:lower:]')" \
                -U 2>/dev/null || echo "     ⚠️  Model config already exists, skipping..."
        fi
        
    done < <(grep -v '^\s*#' "$ENV_FILE" | grep -v '^\s*$')
    
    echo "✅ API keys imported to macOS Keychain"
else
    echo "⚠️  .env file not found at $ENV_FILE"
    echo "   You'll need to manually add your API keys to the keychain"
fi

# Create validation script
VALIDATION_SCRIPT="$HOME/.mcp/bin/validate-api-keys"
mkdir -p "$(dirname "$VALIDATION_SCRIPT")"

cat > "$VALIDATION_SCRIPT" << 'EOF'
#!/bin/bash
# validate-api-keys - Test all stored API keys
# Auto