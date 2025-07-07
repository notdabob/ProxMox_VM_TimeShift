#!/bin/bash
# Unified Deployment Script for ProxMox Homelab Stack
# Supports MCP, iDRAC, Time-Shift, and Hybrid deployments with rollback capabilities

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
print_step() { echo -e "${PURPLE}[STEP]${NC} $1"; }

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
COMPOSE_FILE="$PROJECT_ROOT/docker/docker-compose.yaml"
BACKUP_DIR="$PROJECT_ROOT/backups"
LOG_FILE="$PROJECT_ROOT/deployment.log"

# Default values
VMID=""
VM_IP=""
TYPE=""
PROFILE="full"
DRY_RUN="false"
FORCE="false"
ROLLBACK="false"
BACKUP_BEFORE_DEPLOY="true"

# Deployment profiles
PROFILES=(
    "mcp:MCP Server Stack Only"
    "idrac:iDRAC Management Only"
    "timeshift:Time-Shift Proxy Only"
    "monitoring:Monitoring Services Only"
    "full:Complete Homelab Stack"
)

show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Deployment Options:"
    echo "  --vmid VMID          Target VM ID (required for remote deployment)"
    echo "  --vm-ip IP           Target VM IP (auto-detected if not specified)"
    echo "  --type TYPE          Deployment type (mcp|idrac|timeshift|hybrid)"
    echo "  --profile PROFILE    Service profile to deploy (default: full)"
    echo "  --local              Deploy locally (current host)"
    echo "  --dry-run            Show what would be deployed without deploying"
    echo "  --force              Force deployment even if services are running"
    echo "  --no-backup          Skip backup before deployment"
    echo "  --rollback           Rollback to previous deployment"
    echo "  --help               Show this help"
    echo ""
    echo "Available Profiles:"
        for profile in "${PROFILES[@]}"; do
            IFS=':' read -r name desc <<< "$profile"
            printf "  %-12s %s\n" "$name" "$desc"
        done
        echo ""
        echo "Examples:"
        echo "  $0 --vmid 205 --profile mcp"
        echo "  $0 --vm-ip 192.168.1.100 --type idrac"
        echo "  $0 --local --profile full"
        echo "  $0 --rollback --vmid 205"
}

log_message() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $message" >> "$LOG_FILE"
    echo "$message"
}

create_backup() {
    local backup_name="backup-$(date '+%Y%m%d-%H%M%S')"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    print_step "Creating backup: $backup_name"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY RUN: Would create backup at $backup_path"
        return 0
    fi
    
    mkdir -p "$backup_path"
    
    # Backup current docker-compose state
    if command -v docker-compose &>/dev/null || command -v docker &>/dev/null; then
        if [[ -n "$VM_IP" ]]; then
            # Remote backup
            ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 root@"$VM_IP" "
                mkdir -p /tmp/backup-$backup_name
                cd /opt/homelab 2>/dev/null || cd /root
                docker-compose ps --format json > /tmp/backup-$backup_name/services.json 2>/dev/null || true
                docker volume ls --format json > /tmp/backup-$backup_name/volumes.json 2>/dev/null || true
                tar -czf /tmp/backup-$backup_name.tar.gz -C /tmp backup-$backup_name
            "
            scp -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 root@"$VM_IP":/tmp/backup-$backup_name.tar.gz "$backup_path/"
        else
            # Local backup
            docker-compose -f "$COMPOSE_FILE" ps --format json > "$backup_path/services.json" 2>/dev/null || true
            docker volume ls --format json > "$backup_path/volumes.json" 2>/dev/null || true
        fi
    fi
    
    # Backup configuration files
    cp "$COMPOSE_FILE" "$backup_path/" 2>/dev/null || true
    
    # Create backup manifest
    cat > "$backup_path/manifest.json" << EOF
{
    "backup_name": "$backup_name",
    "timestamp": "$(date -Iseconds)",
    "vmid": "$VMID",
    "vm_ip": "$VM_IP",
    "profile": "$PROFILE",
    "type": "$TYPE"
}
EOF
    
    print_success "Backup created: $backup_path"
    echo "$backup_path" > "$BACKUP_DIR/latest"
}

rollback_deployment() {
    local backup_path
    
    if [[ -f "$BACKUP_DIR/latest" ]]; then
        backup_path=$(cat "$BACKUP_DIR/latest")
    else
        print_error "No backup found for rollback"
        exit 1
    fi
    
    if [[ ! -d "$backup_path" ]]; then
        print_error "Backup directory not found: $backup_path"
        exit 1
    fi
    
    print_header "Rolling back deployment"
    print_status "Using backup: $(basename "$backup_path")"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY RUN: Would rollback using $backup_path"
        return 0
    fi
    
    # Stop current services
    stop_services
    
    # Restore from backup
    if [[ -f "$backup_path/docker-compose.yaml" ]]; then
        cp "$backup_path/docker-compose.yaml" "$COMPOSE_FILE"
        print_success "Configuration restored"
    fi
    
    # Restart services
    deploy_services
    
    print_success "Rollback completed"
}

detect_vm_ip() {
    local vmid="$1"
    
    if [[ -z "$vmid" ]]; then
        print_error "VMID required for IP detection"
        return 1
    fi
    
    print_status "Detecting IP for VM $vmid..."
    
    # Check if VM info file exists
    if [[ -f "/tmp/vm-${vmid}-info.json" ]]; then
        VM_IP=$(jq -r '.ip' "/tmp/vm-${vmid}-info.json" 2>/dev/null)
        if [[ -n "$VM_IP" && "$VM_IP" != "null" ]]; then
            print_success "IP detected from VM info: $VM_IP"
            return 0
        fi
    fi
    
    # Source shared utilities if not already loaded
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local utils_dir="$(dirname "$script_dir")/scripts/utils"
    
    # Load configuration first
    if [[ -f "$utils_dir/config-loader.sh" ]]; then
        source "$utils_dir/config-loader.sh"
        detect_network_config
        export_config_vars
    fi
    
    if [[ -f "$utils_dir/vm-network-utils.sh" ]]; then
        source "$utils_dir/vm-network-utils.sh"
        
        # Use shared utility function
        if VM_IP=$(util_detect_vm_ip "$vmid" 5 15); then
            return 0
        else
            print_warning "Primary detection failed, trying alternative methods..."
            if VM_IP=$(util_detect_vm_ip_alternative "$vmid"); then
                return 0
            else
                print_error "Could not detect VM IP using any method"
                return 1
            fi
        fi
    else
        # Fallback to original method if utilities not available
        for i in {1..5}; do
            VM_IP=$(qm guest cmd "$vmid" network-get-interfaces 2>/dev/null | \
                grep -Eo '"ip-address": "([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)"' | \
                grep -v '127.0.0.1' | head -n1 | cut -d'"' -f4)
            
            if [[ -n "$VM_IP" ]]; then
                print_success "IP detected: $VM_IP"
                return 0
            fi
            
            print_status "Waiting for network configuration... (attempt $i/5)"
            sleep 5
        done
        
        print_error "Could not detect VM IP"
        return 1
    fi
}

prepare_remote_deployment() {
    local vm_ip="$1"
    
    print_step "Preparing remote deployment to $vm_ip"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY RUN: Would prepare remote deployment"
        return 0
    fi
    
    # Test SSH connectivity
    if ! ssh -o ConnectTimeout=10 -o StrictHostKeyChecking=no root@"$vm_ip" "echo 'SSH connection successful'" >/dev/null 2>&1; then
        print_error "Cannot connect to VM via SSH: $vm_ip"
        print_error "Ensure VM is running and SSH is accessible"
        exit 1
    fi
    
    # Create deployment directory
    ssh -o StrictHostKeyChecking=no root@"$vm_ip" "mkdir -p /opt/homelab"
    
    # Copy compose file and configurations
    scp -o StrictHostKeyChecking=no "$COMPOSE_FILE" root@"$vm_ip":/opt/homelab/
    
    # Copy any additional configuration files
    if [[ -d "$PROJECT_ROOT/config" ]]; then
        scp -r -o StrictHostKeyChecking=no "$PROJECT_ROOT/config" root@"$vm_ip":/opt/homelab/
    fi
    
    # Copy source directories for builds
    for dir in namespace-timeshift-browser-container time-shift-proxmox; do
        if [[ -d "$PROJECT_ROOT/$dir" ]]; then
            scp -r -o StrictHostKeyChecking=no "$PROJECT_ROOT/$dir" root@"$vm_ip":/opt/homelab/
        fi
    done
    
    print_success "Remote deployment prepared"
}

stop_services() {
    print_step "Stopping existing services"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY RUN: Would stop services"
        return 0
    fi
    
    local compose_cmd="docker-compose -f $COMPOSE_FILE"
    
    if [[ -n "$VM_IP" ]]; then
        # Remote stop
        ssh -o StrictHostKeyChecking=no root@"$VM_IP" "
            cd /opt/homelab
            docker-compose -f docker-compose.yaml down --remove-orphans 2>/dev/null || true
        "
    else
        # Local stop
        cd "$PROJECT_ROOT"
        docker-compose -f "$COMPOSE_FILE" down --remove-orphans 2>/dev/null || true
    fi
    
    print_success "Services stopped"
}

deploy_services() {
    print_step "Deploying services with profile: $PROFILE"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY RUN: Would deploy services with profile $PROFILE"
        return 0
    fi
    
    local compose_cmd="docker-compose -f $COMPOSE_FILE --profile $PROFILE"
    
    if [[ -n "$VM_IP" ]]; then
        # Remote deployment
        ssh -o StrictHostKeyChecking=no root@"$VM_IP" "
            cd /opt/homelab
            docker-compose -f docker-compose.yaml --profile $PROFILE pull
            docker-compose -f docker-compose.yaml --profile $PROFILE up -d --build
        "
    else
        # Local deployment
        cd "$PROJECT_ROOT"
        docker-compose -f "$COMPOSE_FILE" --profile "$PROFILE" pull
        docker-compose -f "$COMPOSE_FILE" --profile "$PROFILE" up -d --build
    fi
    
    print_success "Services deployed"
}

wait_for_services() {
    print_step "Waiting for services to become healthy"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY RUN: Would wait for services"
        return 0
    fi
    
    local max_wait=300  # 5 minutes
    local wait_time=0
    local check_interval=15
    
    while [[ $wait_time -lt $max_wait ]]; do
        local healthy_count=0
        local total_count=0
        
        if [[ -n "$VM_IP" ]]; then
            # Remote health check
            local health_output=$(ssh -o StrictHostKeyChecking=no root@"$VM_IP" "
                cd /opt/homelab
                docker-compose -f docker-compose.yaml --profile $PROFILE ps --format json
            " 2>/dev/null || echo "[]")
        else
            # Local health check
            local health_output=$(docker-compose -f "$COMPOSE_FILE" --profile "$PROFILE" ps --format json 2>/dev/null || echo "[]")
        fi
        
        # Count healthy services (simplified check)
        if [[ "$health_output" != "[]" ]]; then
            total_count=$(echo "$health_output" | jq -r '. | length' 2>/dev/null || echo "0")
            healthy_count=$(echo "$health_output" | jq -r '.[] | select(.State == "running") | .Name' 2>/dev/null | wc -l || echo "0")
        fi
        
        if [[ $total_count -gt 0 && $healthy_count -eq $total_count ]]; then
            print_success "All services are healthy ($healthy_count/$total_count)"
            return 0
        fi
        
        print_status "Waiting for services... ($healthy_count/$total_count healthy)"
        sleep $check_interval
        wait_time=$((wait_time + check_interval))
    done
    
    print_warning "Timeout waiting for all services to become healthy"
    return 1
}

show_deployment_status() {
    print_header "Deployment Status"
    
    local target_info=""
    if [[ -n "$VM_IP" ]]; then
        target_info="VM $VMID ($VM_IP)"
    else
        target_info="Local Host"
    fi
    
    print_status "Target: $target_info"
    print_status "Profile: $PROFILE"
    print_status "Type: $TYPE"
    
    # Show service URLs
    print_header "Service URLs"
    local base_url="http://${VM_IP:-localhost}"
    
    case "$PROFILE" in
        "mcp"|"full")
            echo "  Context7 MCP:        ${base_url}:7001"
            echo "  Desktop Commander:   ${base_url}:7002"
            echo "  Filesystem MCP:      ${base_url}:7003"
            ;;
    esac
    
    case "$PROFILE" in
        "idrac"|"full")
            echo "  iDRAC Dashboard:     ${base_url}:8080"
            echo "  iDRAC API:           ${base_url}:8765"
            ;;
    esac
    
    case "$PROFILE" in
        "timeshift"|"full")
            echo "  Time-Shift Proxy:    ${base_url}:8090"
            ;;
    esac
    
    case "$PROFILE" in
        "monitoring"|"full")
            echo "  Service Discovery:   ${base_url}:9000"
            echo "  Health Monitor:      ${base_url}:9001"
            echo "  Unified Dashboard:   ${base_url}:9010"
            ;;
    esac
    
    print_header "Management Commands"
    if [[ -n "$VM_IP" ]]; then
        echo "  View logs:    ssh root@$VM_IP 'cd /opt/homelab && docker-compose logs -f'"
        echo "  Stop stack:   ssh root@$VM_IP 'cd /opt/homelab && docker-compose down'"
        echo "  Restart:      $0 --vmid $VMID --profile $PROFILE"
    else
        echo "  View logs:    docker-compose -f $COMPOSE_FILE logs -f"
        echo "  Stop stack:   docker-compose -f $COMPOSE_FILE down"
        echo "  Restart:      $0 --local --profile $PROFILE"
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --vmid)
            VMID="$2"
            shift 2
            ;;
        --vm-ip)
            VM_IP="$2"
            shift 2
            ;;
        --type)
            TYPE="$2"
            shift 2
            ;;
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        --local)
            VMID=""
            VM_IP=""
            shift
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --force)
            FORCE="true"
            shift
            ;;
        --no-backup)
            BACKUP_BEFORE_DEPLOY="false"
            shift
            ;;
        --rollback)
            ROLLBACK="true"
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

# Validate profile
valid_profiles=()
for profile in "${PROFILES[@]}"; do
    IFS=':' read -r name desc <<< "$profile"
    valid_profiles+=("$name")
done

if [[ ! " ${valid_profiles[*]} " =~ " ${PROFILE} " ]]; then
    print_error "Invalid profile: $PROFILE"
    print_error "Valid profiles: ${valid_profiles[*]}"
    exit 1
fi

# Auto-detect type from profile if not specified
if [[ -z "$TYPE" ]]; then
    case "$PROFILE" in
        "mcp") TYPE="mcp" ;;
        "idrac") TYPE="idrac" ;;
        "timeshift") TYPE="timeshift" ;;
        "monitoring") TYPE="monitoring" ;;
        "full") TYPE="hybrid" ;;
    esac
fi

# Create necessary directories
mkdir -p "$BACKUP_DIR"
touch "$LOG_FILE"

# Main execution
print_header "Unified Homelab Stack Deployment"

# Handle rollback
if [[ "$ROLLBACK" == "true" ]]; then
    if [[ -n "$VMID" && -z "$VM_IP" ]]; then
        detect_vm_ip "$VMID"
    fi
    rollback_deployment
    exit 0
fi

# Detect VM IP if VMID provided but no IP
if [[ -n "$VMID" && -z "$VM_IP" ]]; then
    detect_vm_ip "$VMID"
fi

# Prepare deployment
if [[ -n "$VM_IP" ]]; then
    prepare_remote_deployment "$VM_IP"
fi

# Create backup if requested
if [[ "$BACKUP_BEFORE_DEPLOY" == "true" ]]; then
    create_backup
fi

# Deploy services
if [[ "$FORCE" == "true" ]]; then
    stop_services
fi

deploy_services
wait_for_services
show_deployment_status

print_header "Deployment Complete"
print_success "Homelab stack deployed successfully!"

log_message "Deployment completed successfully - Profile: $PROFILE, Target: ${VM_IP:-localhost}"