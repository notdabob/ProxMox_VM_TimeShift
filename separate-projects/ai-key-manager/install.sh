#!/bin/bash

# AI Key Manager Installation Script
# This script installs the AI Key Manager tool on macOS

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
INSTALL_DIR="/usr/local/bin"
COMPLETION_DIR="/usr/local/etc/bash_completion.d"
SCRIPT_NAME="ai-key-manager"
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${BLUE}AI Key Manager Installation${NC}"
echo "==============================="

# Function to print colored output
print_status() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Check if running on macOS
if [[ "$(uname)" != "Darwin" ]]; then
    print_error "This script is designed for macOS only"
    exit 1
fi

# Check macOS version
macos_version=$(sw_vers -productVersion)
macos_major=$(echo "$macos_version" | cut -d. -f1)
macos_minor=$(echo "$macos_version" | cut -d. -f2)

if [[ "$macos_major" -lt 10 ]] || [[ "$macos_major" -eq 10 && "$macos_minor" -lt 15 ]]; then
    print_error "macOS 10.15 (Catalina) or later is required. Found: $macos_version"
    exit 1
fi

print_status "macOS version check passed: $macos_version"

# Check Python version
if ! command -v python3 &> /dev/null; then
    print_error "Python 3 is required but not found"
    exit 1
fi

python_version=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
python_major=$(echo "$python_version" | cut -d. -f1)
python_minor=$(echo "$python_version" | cut -d. -f2)

if [[ "$python_major" -lt 3 ]] || [[ "$python_major" -eq 3 && "$python_minor" -lt 8 ]]; then
    print_error "Python 3.8 or later is required. Found: $python_version"
    exit 1
fi

print_status "Python version check passed: $python_version"

# Check for pip
if ! command -v pip3 &> /dev/null; then
    print_error "pip3 is required but not found"
    exit 1
fi

# Install Python dependencies
echo
echo "Installing Python dependencies..."
if pip3 install -r "$CURRENT_DIR/requirements.txt" --user; then
    print_status "Python dependencies installed"
else
    print_error "Failed to install Python dependencies"
    exit 1
fi

# Check if install directory exists and is writable
if [[ ! -d "$INSTALL_DIR" ]]; then
    print_warning "Creating install directory: $INSTALL_DIR"
    sudo mkdir -p "$INSTALL_DIR"
fi

if [[ ! -w "$INSTALL_DIR" ]]; then
    print_warning "Need sudo access to install to $INSTALL_DIR"
    NEEDS_SUDO=true
else
    NEEDS_SUDO=false
fi

# Install main script
echo
echo "Installing AI Key Manager..."

if [[ "$NEEDS_SUDO" == "true" ]]; then
    sudo cp "$CURRENT_DIR/$SCRIPT_NAME" "$INSTALL_DIR/"
    sudo chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
else
    cp "$CURRENT_DIR/$SCRIPT_NAME" "$INSTALL_DIR/"
    chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
fi

print_status "AI Key Manager installed to $INSTALL_DIR/$SCRIPT_NAME"

# Create bash completion
echo
echo "Setting up bash completion..."

# Create completion script
cat > "/tmp/ai-key-manager-completion" << 'EOF'
# AI Key Manager bash completion

_ai_key_manager_completions() {
    local cur prev opts
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    # Main commands
    if [[ ${COMP_CWORD} == 1 ]]; then
        opts="import list validate show remove setup-cron update status backup restore --help --version"
        COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
        return 0
    fi

    # Command-specific completions
    case "${COMP_WORDS[1]}" in
        show|remove|update)
            # Complete with provider names
            opts="openai anthropic gemini perplexity groq"
            COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            ;;
        import|backup|restore)
            # Complete with file paths
            COMPREPLY=( $(compgen -f -- ${cur}) )
            ;;
        setup-cron)
            if [[ ${prev} == "--interval" ]]; then
                opts="hourly daily weekly"
                COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            else
                opts="--interval --disable"
                COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            fi
            ;;
        validate)
            if [[ ${prev} == "--provider" ]]; then
                opts="openai anthropic gemini perplexity groq"
                COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            else
                opts="--provider --fix"
                COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            fi
            ;;
        list)
            opts="--details --provider"
            COMPREPLY=( $(compgen -W "${opts}" -- ${cur}) )
            ;;
    esac
}

complete -F _ai_key_manager_completions ai-key-manager
EOF

# Install completion script
if [[ ! -d "$COMPLETION_DIR" ]]; then
    print_warning "Creating bash completion directory: $COMPLETION_DIR"
    sudo mkdir -p "$COMPLETION_DIR"
fi

sudo mv "/tmp/ai-key-manager-completion" "$COMPLETION_DIR/ai-key-manager"
print_status "Bash completion installed"

# Create config directory
config_dir="$HOME/.config/ai-key-manager"
if [[ ! -d "$config_dir" ]]; then
    mkdir -p "$config_dir"
    print_status "Created config directory: $config_dir"
fi

# Create log directory
log_dir="$HOME/Library/Logs/ai-key-manager"
if [[ ! -d "$log_dir" ]]; then
    mkdir -p "$log_dir"
    print_status "Created log directory: $log_dir"
fi

# Verify installation
echo
echo "Verifying installation..."

if command -v ai-key-manager &> /dev/null; then
    print_status "AI Key Manager is installed and available in PATH"
    
    # Test the installation
    if ai-key-manager --version &> /dev/null; then
        print_status "Installation verification passed"
    else
        print_warning "Installation may have issues - basic test failed"
    fi
else
    print_error "Installation failed - ai-key-manager not found in PATH"
    echo "Make sure $INSTALL_DIR is in your PATH"
    exit 1
fi

echo
echo -e "${GREEN}Installation completed successfully!${NC}"
echo
echo "Usage examples:"
echo "  ai-key-manager --help                    # Show help"
echo "  ai-key-manager import /path/to/.env      # Import keys from .env file"
echo "  ai-key-manager list                      # List stored keys"
echo "  ai-key-manager validate                  # Validate all keys"
echo "  ai-key-manager setup-cron               # Setup periodic validation"
echo
echo "For bash completion to work in your current session, run:"
echo "  source $COMPLETION_DIR/ai-key-manager"
echo
echo "Or add this to your ~/.bashrc or ~/.bash_profile:"
echo "  [[ -f $COMPLETION_DIR/ai-key-manager ]] && source $COMPLETION_DIR/ai-key-manager"
echo
echo "Configuration file: $config_dir/config.json"
echo "Log files: $log_dir/"
