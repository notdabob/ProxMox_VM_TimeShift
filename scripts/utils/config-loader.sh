#!/bin/bash
# Configuration Loader Utility
# Loads and processes configuration files for the homelab stack

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Configuration file paths
HOMELAB_CONFIG="$PROJECT_ROOT/config/homelab-config.yaml"
NETWORK_CONFIG="$PROJECT_ROOT/config/network-config.yaml"

# Global configuration variables
declare -A CONFIG
declare -A NETWORK_CONFIG_VARS

# Function to load YAML configuration (simplified parser)
load_yaml_config() {
    local config_file="$1"
    local prefix="$2"
    
    if [[ ! -f "$config_file" ]]; then
        echo "Warning: Configuration file not found: $config_file" >&2
        return 1
    fi
    
    # Simple YAML parser for basic key-value pairs
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # Extract key-value pairs (simplified)
        if [[ "$line" =~ ^[[:space:]]*([^:]+):[[:space:]]*(.*)$ ]]; then
            local key="${BASH_REMATCH[1]// /}"
            local value="${BASH_REMATCH[2]}"
            
            # Remove quotes from value
            value="${value#\"}"
            value="${value%\"}"
            value="${value#\'}"
            value="${value%\'}"
            
            if [[ -n "$prefix" ]]; then
                CONFIG["${prefix}_${key}"]="$value"
            else
                CONFIG["$key"]="$value"
            fi
        fi
    done < "$config_file"
}

# Function to get configuration value with default
get_config() {
    local key="$1"
    local default="$2"
    
    if [[ -n "${CONFIG[$key]}" ]]; then
        echo "${CONFIG[$key]}"
    else
        echo "$default"
    fi
}

# Function to detect and set network configuration
detect_network_config() {
    local vm_ip="$1"
    
    # Set default network configuration
    NETWORK_CONFIG_VARS["DEFAULT_SUBNET"]=$(get_config "network_default_subnet" "192.168.1.0/24")
    NETWORK_CONFIG_VARS["DEFAULT_GATEWAY"]=$(get_config "network_default_gateway" "192.168.1.1")
    NETWORK_CONFIG_VARS["BIND_ADDRESS"]=$(get_config "network_bind_address" "0.0.0.0")
    
    # If VM IP is provided, derive network settings
    if [[ -n "$vm_ip" ]]; then
        # Extract network from IP (simple /24 assumption)
        local network_base="${vm_ip%.*}.0/24"
        local gateway="${vm_ip%.*}.1"
        
        NETWORK_CONFIG_VARS["DETECTED_SUBNET"]="$network_base"
        NETWORK_CONFIG_VARS["DETECTED_GATEWAY"]="$gateway"
        NETWORK_CONFIG_VARS["VM_IP"]="$vm_ip"
    fi
}

# Function to generate dynamic CORS origins
generate_cors_origins() {
    local vm_ip="$1"
    local origins=()
    
    # Default origins
    origins+=("http://localhost:8080")
    origins+=("http://127.0.0.1:8080")
    origins+=("http://localhost:3000")
    origins+=("http://127.0.0.1:3000")
    
    # Add VM IP based origins if available
    if [[ -n "$vm_ip" ]]; then
        origins+=("http://$vm_ip:8080")
        origins+=("http://$vm_ip:3000")
        origins+=("http://$vm_ip:9010")
    fi
    
    # Return as JSON array
    printf '%s\n' "${origins[@]}" | jq -R . | jq -s .
}

# Function to export environment variables from config
export_config_vars() {
    export HOMELAB_DEFAULT_SUBNET="${NETWORK_CONFIG_VARS[DEFAULT_SUBNET]}"
    export HOMELAB_DEFAULT_GATEWAY="${NETWORK_CONFIG_VARS[DEFAULT_GATEWAY]}"
    export HOMELAB_BIND_ADDRESS="${NETWORK_CONFIG_VARS[BIND_ADDRESS]}"
    export HOMELAB_VM_IP="${NETWORK_CONFIG_VARS[VM_IP]}"
    
    # Export common configuration
    export HOMELAB_PROJECT_ROOT="$PROJECT_ROOT"
    export HOMELAB_COMPOSE_FILE="$PROJECT_ROOT/docker/docker-compose.yaml"
}

# Function to validate configuration
validate_config() {
    local errors=0
    
    # Check required files
    if [[ ! -f "$HOMELAB_CONFIG" ]]; then
        echo "Error: Homelab configuration file not found: $HOMELAB_CONFIG" >&2
        errors=$((errors + 1))
    fi
    
    # Check Docker Compose file
    if [[ ! -f "${CONFIG[compose_file]:-$PROJECT_ROOT/docker/docker-compose.yaml}" ]]; then
        echo "Error: Docker Compose file not found" >&2
        errors=$((errors + 1))
    fi
    
    return $errors
}

# Initialize configuration if script is sourced
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Script is being sourced
    load_yaml_config "$HOMELAB_CONFIG" "homelab"
    load_yaml_config "$NETWORK_CONFIG" "network"
fi