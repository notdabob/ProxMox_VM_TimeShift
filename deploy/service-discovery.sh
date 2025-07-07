#!/bin/bash
# Service Discovery and Health Monitoring Script
# Provides centralized service registry and health monitoring for homelab stack

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() { echo -e "${CYAN}=== $1 ===${NC}"; }

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
REGISTRY_FILE="$PROJECT_ROOT/service-registry.json"
HEALTH_FILE="$PROJECT_ROOT/health-status.json"

# Default values
VMID=""
VM_IP=""
ACTION="status"
WATCH="false"
INTERVAL=30
OUTPUT_FORMAT="table"

show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Actions:"
    echo "  --register           Register services in discovery"
    echo "  --health-check       Perform health checks on all services"
    echo "  --status             Show current service status (default)"
    echo "  --watch              Continuously monitor services"
    echo "  --list               List all discovered services"
    echo "  --cleanup            Remove stale service entries"
    echo ""
    echo "Options:"
    echo "  --vmid VMID          Target VM ID"
    echo "  --vm-ip IP           Target VM IP"
    echo "  --interval SECONDS   Monitoring interval (default: 30)"
    echo "  --format FORMAT      Output format (table|json|yaml) (default: table)"
    echo "  --local              Monitor local services"
    echo "  --help               Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 --register --vmid 205"
    echo "  $0 --health-check --vm-ip 192.168.1.100"
    echo "  $0 --watch --local --interval 15"
    echo "  $0 --status --format json"
}

# Source shared utilities if available
UTILS_DIR="$(dirname "$SCRIPT_DIR")/scripts/utils"
if [[ -f "$UTILS_DIR/vm-network-utils.sh" ]]; then
    source "$UTILS_DIR/vm-network-utils.sh"
    USE_SHARED_UTILS=true
else
    USE_SHARED_UTILS=false
fi

detect_vm_ip() {
    local vmid="$1"
    
    if [[ -z "$vmid" ]]; then
        return 1
    fi
    
    # Check if VM info file exists
    if [[ -f "/tmp/vm-${vmid}-info.json" ]]; then
        VM_IP=$(jq -r '.ip' "/tmp/vm-${vmid}-info.json" 2>/dev/null)
        if [[ -n "$VM_IP" && "$VM_IP" != "null" ]]; then
            return 0
        fi
    fi
    
    if [[ "$USE_SHARED_UTILS" == "true" ]]; then
        # Use shared utility function
        VM_IP=$(util_detect_vm_ip "$vmid" 3 10)
    else
        # Fallback to original method
        VM_IP=$(qm guest cmd "$vmid" network-get-interfaces 2>/dev/null | \
            grep -Eo '"ip-address": "([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)"' | \
            grep -v '127.0.0.1' | head -n1 | cut -d'"' -f4)
    fi
    
    [[ -n "$VM_IP" ]]
}

discover_services() {
    local target="$1"  # "local" or IP address
    local services=()
    
    print_status "Discovering services on $target..."
    
    if [[ "$target" == "local" ]]; then
        # Local service discovery
        if command -v docker &>/dev/null; then
            while IFS= read -r line; do
                services+=("$line")
            done < <(docker ps --format "{{.Names}}\t{{.Ports}}\t{{.Status}}\t{{.Labels}}" | grep -E "(homelab|mcp|idrac|timeshift)")
        fi
    else
        # Remote service discovery
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@"$target" "command -v docker" &>/dev/null; then
            while IFS= read -r line; do
                services+=("$line")
            done < <(ssh -o StrictHostKeyChecking=no root@"$target" "docker ps --format '{{.Names}}\t{{.Ports}}\t{{.Status}}\t{{.Labels}}'" | grep -E "(homelab|mcp|idrac|timeshift)")
        fi
    fi
    
    # Parse and structure service data
    local service_data="[]"
    for service_line in "${services[@]}"; do
        if [[ -n "$service_line" ]]; then
            IFS=$'\t' read -r name ports status labels <<< "$service_line"
            
            # Extract service type and description from labels
            local service_type=$(echo "$labels" | grep -o 'homelab\.service=[^,]*' | cut -d'=' -f2 || echo "unknown")
            local service_port=$(echo "$labels" | grep -o 'homelab\.port=[^,]*' | cut -d'=' -f2 || echo "")
            local description=$(echo "$labels" | grep -o 'homelab\.description=[^,]*' | cut -d'=' -f2 || echo "")
            
            # Create service entry
            local service_entry=$(jq -n \
                --arg name "$name" \
                --arg type "$service_type" \
                --arg port "$service_port" \
                --arg status "$status" \
                --arg description "$description" \
                --arg target "$target" \
                --arg timestamp "$(date -Iseconds)" \
                '{
                    name: $name,
                    type: $type,
                    port: $port,
                    status: $status,
                    description: $description,
                    target: $target,
                    timestamp: $timestamp,
                    url: (if $port != "" then "http://\($target):\($port)" else null end)
                }')
            
            service_data=$(echo "$service_data" | jq ". + [$service_entry]")
        fi
    done
    
    echo "$service_data"
}

register_services() {
    local target="${VM_IP:-local}"
    
    print_header "Registering Services"
    
    local discovered_services=$(discover_services "$target")
    local service_count=$(echo "$discovered_services" | jq '. | length')
    
    # Create or update registry
    local registry_data=$(jq -n \
        --argjson services "$discovered_services" \
        --arg target "$target" \
        --arg timestamp "$(date -Iseconds)" \
        '{
            target: $target,
            timestamp: $timestamp,
            service_count: ($services | length),
            services: $services
        }')
    
    echo "$registry_data" > "$REGISTRY_FILE"
    
    print_success "Registered $service_count services"
    
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo "$registry_data"
    elif [[ "$OUTPUT_FORMAT" == "yaml" ]]; then
        echo "$registry_data" | yq eval -P
    else
        show_services_table "$discovered_services"
    fi
}

perform_health_checks() {
    local target="${VM_IP:-local}"
    
    print_header "Performing Health Checks"
    
    if [[ ! -f "$REGISTRY_FILE" ]]; then
        print_warning "No service registry found. Running discovery first..."
        register_services
    fi
    
    local services=$(jq -r '.services[]' "$REGISTRY_FILE" 2>/dev/null || echo "[]")
    local health_results="[]"
    
    while IFS= read -r service; do
        if [[ -n "$service" && "$service" != "null" ]]; then
            local name=$(echo "$service" | jq -r '.name')
            local port=$(echo "$service" | jq -r '.port')
            local url=$(echo "$service" | jq -r '.url')
            
            print_status "Checking health of $name..."
            
            local health_status="unknown"
            local response_time=""
            local error_message=""
            
            # Check container health
            if [[ "$target" == "local" ]]; then
                if docker inspect "$name" &>/dev/null; then
                    health_status=$(docker inspect --format='{{.State.Health.Status}}' "$name" 2>/dev/null || echo "no-healthcheck")
                    if [[ "$health_status" == "no-healthcheck" ]]; then
                        # Check if container is running
                        if docker inspect --format='{{.State.Running}}' "$name" 2>/dev/null | grep -q "true"; then
                            health_status="running"
                        else
                            health_status="stopped"
                        fi
                    fi
                else
                    health_status="not-found"
                fi
            else
                health_status=$(ssh -o StrictHostKeyChecking=no root@"$target" "
                    if docker inspect '$name' &>/dev/null; then
                        docker inspect --format='{{.State.Health.Status}}' '$name' 2>/dev/null || echo 'no-healthcheck'
                    else
                        echo 'not-found'
                    fi
                ")
                if [[ "$health_status" == "no-healthcheck" ]]; then
                    local running=$(ssh -o StrictHostKeyChecking=no root@"$target" "docker inspect --format='{{.State.Running}}' '$name' 2>/dev/null || echo 'false'")
                    if [[ "$running" == "true" ]]; then
                        health_status="running"
                    else
                        health_status="stopped"
                    fi
                fi
            fi
            
            # Check HTTP endpoint if available
            if [[ -n "$url" && "$url" != "null" ]]; then
                local start_time=$(date +%s%N)
                if curl -s -f --max-time 5 "$url" >/dev/null 2>&1; then
                    local end_time=$(date +%s%N)
                    response_time=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds
                    if [[ "$health_status" == "running" ]]; then
                        health_status="healthy"
                    fi
                else
                    error_message="HTTP endpoint not responding"
                fi
            fi
            
            # Create health entry
            local health_entry=$(echo "$service" | jq \
                --arg health_status "$health_status" \
                --arg response_time "$response_time" \
                --arg error_message "$error_message" \
                --arg checked_at "$(date -Iseconds)" \
                '. + {
                    health_status: $health_status,
                    response_time: ($response_time | if . == "" then null else tonumber end),
                    error_message: ($error_message | if . == "" then null else . end),
                    checked_at: $checked_at
                }')
            
            health_results=$(echo "$health_results" | jq ". + [$health_entry]")
        fi
    done < <(jq -c '.services[]?' "$REGISTRY_FILE" 2>/dev/null)
    
    # Save health results
    local health_data=$(jq -n \
        --argjson results "$health_results" \
        --arg target "$target" \
        --arg timestamp "$(date -Iseconds)" \
        '{
            target: $target,
            timestamp: $timestamp,
            health_checks: $results
        }')
    
    echo "$health_data" > "$HEALTH_FILE"
    
    print_success "Health checks completed"
    
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        echo "$health_data"
    elif [[ "$OUTPUT_FORMAT" == "yaml" ]]; then
        echo "$health_data" | yq eval -P
    else
        show_health_table "$health_results"
    fi
}

show_services_table() {
    local services="$1"
    
    printf "%-20s %-12s %-8s %-15s %-30s\n" "SERVICE" "TYPE" "PORT" "STATUS" "DESCRIPTION"
    printf "%-20s %-12s %-8s %-15s %-30s\n" "$(printf '%.0s-' {1..20})" "$(printf '%.0s-' {1..12})" "$(printf '%.0s-' {1..8})" "$(printf '%.0s-' {1..15})" "$(printf '%.0s-' {1..30})"
    
    echo "$services" | jq -r '.[] | [.name, .type, .port, .status, .description] | @tsv' | \
    while IFS=$'\t' read -r name type port status description; do
        printf "%-20s %-12s %-8s %-15s %-30s\n" \
            "${name:0:19}" \
            "${type:0:11}" \
            "${port:0:7}" \
            "${status:0:14}" \
            "${description:0:29}"
    done
}

show_health_table() {
    local health_results="$1"
    
    printf "%-20s %-12s %-10s %-8s %-15s\n" "SERVICE" "TYPE" "HEALTH" "RESP_MS" "ERROR"
    printf "%-20s %-12s %-10s %-8s %-15s\n" "$(printf '%.0s-' {1..20})" "$(printf '%.0s-' {1..12})" "$(printf '%.0s-' {1..10})" "$(printf '%.0s-' {1..8})" "$(printf '%.0s-' {1..15})"
    
    echo "$health_results" | jq -r '.[] | [.name, .type, .health_status, (.response_time // ""), (.error_message // "")] | @tsv' | \
    while IFS=$'\t' read -r name type health resp_time error; do
        # Color code health status
        local health_colored="$health"
        case "$health" in
            "healthy") health_colored="${GREEN}$health${NC}" ;;
            "running") health_colored="${YELLOW}$health${NC}" ;;
            "stopped"|"not-found") health_colored="${RED}$health${NC}" ;;
        esac
        
        printf "%-20s %-12s %-10s %-8s %-15s\n" \
            "${name:0:19}" \
            "${type:0:11}" \
            "$health_colored" \
            "${resp_time:0:7}" \
            "${error:0:14}"
    done
}

show_status() {
    print_header "Service Status"
    
    if [[ -f "$REGISTRY_FILE" ]]; then
        local services=$(jq -r '.services' "$REGISTRY_FILE")
        show_services_table "$services"
    else
        print_warning "No service registry found. Run --register first."
    fi
    
    echo ""
    
    if [[ -f "$HEALTH_FILE" ]]; then
        print_header "Health Status"
        local health_results=$(jq -r '.health_checks' "$HEALTH_FILE")
        show_health_table "$health_results"
    else
        print_warning "No health data found. Run --health-check first."
    fi
}

watch_services() {
    print_header "Watching Services (Ctrl+C to stop)"
    
    while true; do
        clear
        echo "$(date) - Monitoring homelab services every ${INTERVAL}s"
        echo ""
        
        register_services >/dev/null 2>&1
        perform_health_checks >/dev/null 2>&1
        show_status
        
        sleep "$INTERVAL"
    done
}

cleanup_registry() {
    print_header "Cleaning Up Service Registry"
    
    if [[ -f "$REGISTRY_FILE" ]]; then
        # Remove entries older than 1 hour
        local cutoff_time=$(date -d '1 hour ago' -Iseconds)
        local cleaned_data=$(jq --arg cutoff "$cutoff_time" '
            .services = (.services | map(select(.timestamp > $cutoff)))
        ' "$REGISTRY_FILE")
        
        echo "$cleaned_data" > "$REGISTRY_FILE"
        print_success "Registry cleaned up"
    else
        print_warning "No registry file found"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --register)
            ACTION="register"
            shift
            ;;
        --health-check)
            ACTION="health-check"
            shift
            ;;
        --status)
            ACTION="status"
            shift
            ;;
        --watch)
            ACTION="watch"
            shift
            ;;
        --list)
            ACTION="list"
            shift
            ;;
        --cleanup)
            ACTION="cleanup"
            shift
            ;;
        --vmid)
            VMID="$2"
            shift 2
            ;;
        --vm-ip)
            VM_IP="$2"
            shift 2
            ;;
        --interval)
            INTERVAL="$2"
            shift 2
            ;;
        --format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        --local)
            VMID=""
            VM_IP=""
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Detect VM IP if VMID provided but no IP
if [[ -n "$VMID" && -z "$VM_IP" ]]; then
    if ! detect_vm_ip "$VMID"; then
        print_error "Could not detect IP for VM $VMID"
        exit 1
    fi
    print_status "Detected VM IP: $VM_IP"
fi

# Execute action
case "$ACTION" in
    "register")
        register_services
        ;;
    "health-check")
        perform_health_checks
        ;;
    "status")
        show_status
        ;;
    "watch")
        watch_services
        ;;
    "list")
        if [[ -f "$REGISTRY_FILE" ]]; then
            jq -r '.services[] | .name' "$REGISTRY_FILE"
        else
            print_warning "No service registry found"
        fi
        ;;
    "cleanup")
        cleanup_registry
        ;;
    *)
        print_error "Unknown action: $ACTION"
        show_usage
        exit 1
        ;;
esac