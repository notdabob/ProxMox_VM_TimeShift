#!/bin/bash
# Legacy Deployment Migration Script
# Migrates existing fragmented deployments to unified homelab stack

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

# Source shared utilities
UTILS_DIR="$SCRIPT_DIR/utils"
if [[ -f "$UTILS_DIR/vm-network-utils.sh" ]]; then
    source "$UTILS_DIR/vm-network-utils.sh"
    USE_SHARED_UTILS=true
else
    USE_SHARED_UTILS=false
fi

MIGRATION_DIR="$PROJECT_ROOT/migration"
BACKUP_DIR="$PROJECT_ROOT/migration/backups"

# Default values
ACTION="scan"
SOURCE_VMID=""
TARGET_VMID=""
TARGET_TYPE="hybrid"
DRY_RUN="false"
FORCE="false"
BACKUP_ONLY="false"

show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Actions:"
    echo "  --scan               Scan for legacy deployments (default)"
    echo "  --migrate            Migrate specific deployment"
    echo "  --backup             Backup legacy deployment only"
    echo "  --validate           Validate migration readiness"
    echo ""
    echo "Options:"
    echo "  --source-vmid VMID   Source VM ID to migrate"
    echo "  --target-vmid VMID   Target VM ID (auto-assigned if not specified)"
    echo "  --target-type TYPE   Target deployment type (hybrid|mcp|idrac|timeshift)"
    echo "  --dry-run            Show what would be migrated without migrating"
    echo "  --force              Force migration even if target exists"
    echo "  --backup-only        Only create backup, don't migrate"
    echo "  --help               Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 --scan"
    echo "  $0 --migrate --source-vmid 205 --target-type hybrid"
    echo "  $0 --backup --source-vmid 210"
    echo "  $0 --validate --source-vmid 205"
}

detect_legacy_deployments() {
    print_header "Scanning for Legacy Deployments"
    
    local legacy_deployments=()
    
    # Scan VM range for potential legacy deployments
    for vmid in {200..250}; do
        if qm status "$vmid" &>/dev/null; then
            local vm_config=$(qm config "$vmid" 2>/dev/null || echo "")
            local vm_name=$(echo "$vm_config" | grep "^name:" | cut -d' ' -f2- || echo "")
            
            # Try to detect VM IP
            local vm_ip=""
            if [[ "$USE_SHARED_UTILS" == "true" ]]; then
                vm_ip=$(util_detect_vm_ip "$vmid" 2 5)
            else
                vm_ip=$(qm guest cmd "$vmid" network-get-interfaces 2>/dev/null | \
                    grep -Eo '"ip-address": "([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)"' | \
                    grep -v '127.0.0.1' | head -n1 | cut -d'"' -f4 || echo "")
            fi
            
            if [[ -n "$vm_ip" ]]; then
                # Check for legacy services
                local services=$(ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new root@"$vm_ip" \
                    "docker ps --format '{{.Names}}\t{{.Ports}}' 2>/dev/null || echo ''" 2>/dev/null || echo "")
                
                if [[ -n "$services" ]]; then
                    local legacy_type="unknown"
                    local service_count=0
                    
                    # Analyze services to determine type
                    if echo "$services" | grep -q "idrac-manager"; then
                        legacy_type="idrac"
                        ((service_count++))
                    fi
                    
                    if echo "$services" | grep -q -E "(context7|desktop-commander|filesystem)"; then
                        if [[ "$legacy_type" == "idrac" ]]; then
                            legacy_type="hybrid"
                        else
                            legacy_type="mcp"
                        fi
                        ((service_count++))
                    fi
                    
                    if echo "$services" | grep -q "time-shift"; then
                        if [[ "$legacy_type" != "unknown" ]]; then
                            legacy_type="hybrid"
                        else
                            legacy_type="timeshift"
                        fi
                        ((service_count++))
                    fi
                    
                    # Create legacy deployment entry
                    local deployment_info=$(jq -n \
                        --arg vmid "$vmid" \
                        --arg name "$vm_name" \
                        --arg ip "$vm_ip" \
                        --arg type "$legacy_type" \
                        --arg services "$services" \
                        --arg service_count "$service_count" \
                        --arg timestamp "$(date -Iseconds)" \
                        '{
                            vmid: $vmid,
                            name: $name,
                            ip: $ip,
                            type: $type,
                            services: $services,
                            service_count: ($service_count | tonumber),
                            timestamp: $timestamp,
                            migration_ready: true
                        }')
                    
                    legacy_deployments+=("$deployment_info")
                fi
            fi
        fi
    done
    
    # Save scan results
    mkdir -p "$MIGRATION_DIR"
    local scan_results=$(printf '%s\n' "${legacy_deployments[@]}" | jq -s '.')
    echo "$scan_results" > "$MIGRATION_DIR/legacy-scan.json"
    
    # Display results
    local deployment_count=$(echo "$scan_results" | jq '. | length')
    print_success "Found $deployment_count legacy deployments"
    
    if [[ "$deployment_count" -gt 0 ]]; then
        echo ""
        printf "%-6s %-15s %-15s %-10s %-8s %s\n" "VMID" "NAME" "IP" "TYPE" "SERVICES" "STATUS"
        printf "%-6s %-15s %-15s %-10s %-8s %s\n" "$(printf '%.0s-' {1..6})" "$(printf '%.0s-' {1..15})" "$(printf '%.0s-' {1..15})" "$(printf '%.0s-' {1..10})" "$(printf '%.0s-' {1..8})" "$(printf '%.0s-' {1..10})"
        
        echo "$scan_results" | jq -r '.[] | [.vmid, .name, .ip, .type, .service_count, "Ready"] | @tsv' | \
        while IFS=$'\t' read -r vmid name ip type service_count status; do
            printf "%-6s %-15s %-15s %-10s %-8s %s\n" \
                "${vmid:0:5}" \
                "${name:0:14}" \
                "${ip:0:14}" \
                "${type:0:9}" \
                "${service_count:0:7}" \
                "${status:0:9}"
        done
    fi
    
    echo ""
    print_status "Scan results saved to: $MIGRATION_DIR/legacy-scan.json"
}

backup_legacy_deployment() {
    local source_vmid="$1"
    local backup_name="legacy-backup-${source_vmid}-$(date '+%Y%m%d-%H%M%S')"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    print_step "Creating backup for VM $source_vmid"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY RUN: Would create backup at $backup_path"
        return 0
    fi
    
    # Get VM IP
    local vm_ip=""
    if [[ "$USE_SHARED_UTILS" == "true" ]]; then
        vm_ip=$(util_detect_vm_ip "$source_vmid" 3 10)
    else
        vm_ip=$(qm guest cmd "$source_vmid" network-get-interfaces 2>/dev/null | \
            grep -Eo '"ip-address": "([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)"' | \
            grep -v '127.0.0.1' | head -n1 | cut -d'"' -f4)
    fi
    
    if [[ -z "$vm_ip" ]]; then
        print_error "Could not detect IP for VM $source_vmid"
        return 1
    fi
    
    mkdir -p "$backup_path"
    
    # Backup VM configuration
    qm config "$source_vmid" > "$backup_path/vm-config.conf"
    
    # Backup Docker services
    ssh -o StrictHostKeyChecking=no root@"$vm_ip" "
        # Create backup directory on VM
        mkdir -p /tmp/migration-backup
        
        # Export Docker containers
        docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}' > /tmp/migration-backup/containers.txt
        
        # Export Docker volumes
        docker volume ls --format 'table {{.Driver}}\t{{.Name}}' > /tmp/migration-backup/volumes.txt
        
        # Export Docker networks
        docker network ls --format 'table {{.ID}}\t{{.Name}}\t{{.Driver}}' > /tmp/migration-backup/networks.txt
        
        # Backup docker-compose files
        find / -name 'docker-compose*.y*ml' -type f 2>/dev/null | head -10 | while read file; do
            cp \"\$file\" /tmp/migration-backup/ 2>/dev/null || true
        done
        
        # Backup service data (if accessible)
        for volume in \$(docker volume ls -q); do
            if docker run --rm -v \"\$volume\":/data alpine test -d /data 2>/dev/null; then
                docker run --rm -v \"\$volume\":/data -v /tmp/migration-backup:/backup alpine tar -czf /backup/volume-\$volume.tar.gz -C /data . 2>/dev/null || true
            fi
        done
        
        # Create backup archive
        tar -czf /tmp/migration-backup.tar.gz -C /tmp migration-backup
    "
    
    # Download backup
    scp -o StrictHostKeyChecking=no root@"$vm_ip":/tmp/migration-backup.tar.gz "$backup_path/"
    
    # Create backup manifest
    cat > "$backup_path/manifest.json" << EOF
{
    "backup_name": "$backup_name",
    "source_vmid": "$source_vmid",
    "source_ip": "$vm_ip",
    "timestamp": "$(date -Iseconds)",
    "backup_type": "legacy_migration",
    "files": [
        "vm-config.conf",
        "migration-backup.tar.gz"
    ]
}
EOF
    
    print_success "Backup created: $backup_path"
    echo "$backup_path" > "$BACKUP_DIR/latest-$source_vmid"
}

validate_migration() {
    local source_vmid="$1"
    
    print_header "Validating Migration Readiness for VM $source_vmid"
    
    local validation_results=()
    local overall_status="ready"
    
    # Check if VM exists and is running
    if ! qm status "$source_vmid" &>/dev/null; then
        validation_results+=("❌ VM $source_vmid does not exist")
        overall_status="failed"
    elif ! qm status "$source_vmid" | grep -q "running"; then
        validation_results+=("⚠️  VM $source_vmid is not running")
        overall_status="warning"
    else
        validation_results+=("✅ VM $source_vmid exists and is running")
    fi
    
    # Check network connectivity
    local vm_ip=""
    if [[ "$USE_SHARED_UTILS" == "true" ]]; then
        vm_ip=$(util_detect_vm_ip "$source_vmid" 3 10)
    else
        vm_ip=$(qm guest cmd "$source_vmid" network-get-interfaces 2>/dev/null | \
            grep -Eo '"ip-address": "([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)"' | \
            grep -v '127.0.0.1' | head -n1 | cut -d'"' -f4)
    fi
    
    if [[ -z "$vm_ip" ]]; then
        validation_results+=("❌ Could not detect VM IP address")
        overall_status="failed"
    else
        validation_results+=("✅ VM IP detected: $vm_ip")
        
        # Check SSH connectivity
        if ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no root@"$vm_ip" "echo 'SSH OK'" &>/dev/null; then
            validation_results+=("✅ SSH connectivity confirmed")
        else
            validation_results+=("❌ SSH connectivity failed")
            overall_status="failed"
        fi
        
        # Check Docker availability
        if ssh -o StrictHostKeyChecking=no root@"$vm_ip" "command -v docker" &>/dev/null; then
            validation_results+=("✅ Docker is available")
            
            # Check running services
            local services=$(ssh -o StrictHostKeyChecking=no root@"$vm_ip" "docker ps --format '{{.Names}}'" 2>/dev/null || echo "")
            local service_count=$(echo "$services" | grep -v '^$' | wc -l)
            
            if [[ "$service_count" -gt 0 ]]; then
                validation_results+=("✅ Found $service_count running services")
            else
                validation_results+=("⚠️  No running Docker services found")
                overall_status="warning"
            fi
        else
            validation_results+=("❌ Docker is not available")
            overall_status="failed"
        fi
    fi
    
    # Check target VMID availability
    if [[ -n "$TARGET_VMID" ]]; then
        if qm status "$TARGET_VMID" &>/dev/null; then
            validation_results+=("❌ Target VMID $TARGET_VMID already exists")
            overall_status="failed"
        else
            validation_results+=("✅ Target VMID $TARGET_VMID is available")
        fi
    fi
    
    # Display validation results
    for result in "${validation_results[@]}"; do
        echo "  $result"
    done
    
    echo ""
    case "$overall_status" in
        "ready")
            print_success "Migration validation passed - ready to migrate"
            return 0
            ;;
        "warning")
            print_warning "Migration validation passed with warnings - proceed with caution"
            return 0
            ;;
        "failed")
            print_error "Migration validation failed - resolve issues before migrating"
            return 1
            ;;
    esac
}

perform_migration() {
    local source_vmid="$1"
    local target_vmid="$2"
    local target_type="$3"
    
    print_header "Migrating VM $source_vmid to Unified Stack"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        print_warning "DRY RUN: Would migrate VM $source_vmid to $target_vmid ($target_type)"
        return 0
    fi
    
    # Validate migration first
    if ! validate_migration "$source_vmid"; then
        print_error "Migration validation failed"
        return 1
    fi
    
    # Create backup
    backup_legacy_deployment "$source_vmid"
    
    # Create new unified VM
    print_step "Creating new unified VM"
    if [[ -z "$target_vmid" ]]; then
        target_vmid=$("$PROJECT_ROOT/deploy/create-vm.sh" --type "$target_type" --dry-run | grep "Auto-assigned VMID:" | cut -d' ' -f3)
    fi
    
    "$PROJECT_ROOT/deploy/create-vm.sh" --type "$target_type" --vmid "$target_vmid"
    
    # Wait for new VM to be ready
    print_step "Waiting for new VM to be ready"
    sleep 30
    
    # Get new VM IP
    local target_ip=""
    if [[ "$USE_SHARED_UTILS" == "true" ]]; then
        target_ip=$(util_detect_vm_ip "$target_vmid" 3 10)
    else
        target_ip=$(qm guest cmd "$target_vmid" network-get-interfaces 2>/dev/null | \
            grep -Eo '"ip-address": "([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)"' | \
            grep -v '127.0.0.1' | head -n1 | cut -d'"' -f4)
    fi
    
    if [[ -z "$target_ip" ]]; then
        print_error "Could not detect new VM IP"
        return 1
    fi
    
    # Deploy unified stack
    print_step "Deploying unified stack to new VM"
    "$PROJECT_ROOT/deploy/deploy-stack.sh" --vmid "$target_vmid" --profile full
    
    # Migrate data (if possible)
    print_step "Migrating service data"
    migrate_service_data "$source_vmid" "$target_vmid"
    
    # Create migration report
    create_migration_report "$source_vmid" "$target_vmid" "$target_type"
    
    print_success "Migration completed successfully"
    print_status "Old VM: $source_vmid (preserved)"
    print_status "New VM: $target_vmid ($target_ip)"
    print_status "Next steps:"
    print_status "1. Test new deployment: http://$target_ip:9010"
    print_status "2. Update DNS/networking to point to new VM"
    print_status "3. Stop old VM: qm stop $source_vmid"
    print_status "4. Remove old VM: qm destroy $source_vmid (after verification)"
}

migrate_service_data() {
    local source_vmid="$1"
    local target_vmid="$2"
    
    print_step "Migrating service data between VMs"
    
    # Get VM IPs
    local source_ip=""
    local target_ip=""
    
    if [[ "$USE_SHARED_UTILS" == "true" ]]; then
        source_ip=$(util_detect_vm_ip "$source_vmid" 3 10)
        target_ip=$(util_detect_vm_ip "$target_vmid" 3 10)
    else
        source_ip=$(qm guest cmd "$source_vmid" network-get-interfaces 2>/dev/null | \
            grep -Eo '"ip-address": "([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)"' | \
            grep -v '127.0.0.1' | head -n1 | cut -d'"' -f4)
        
        target_ip=$(qm guest cmd "$target_vmid" network-get-interfaces 2>/dev/null | \
            grep -Eo '"ip-address": "([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)"' | \
            grep -v '127.0.0.1' | head -n1 | cut -d'"' -f4)
    fi
    
    if [[ -z "$source_ip" || -z "$target_ip" ]]; then
        print_warning "Could not detect VM IPs for data migration"
        return 1
    fi
    
    # Stop services on both VMs
    ssh -o StrictHostKeyChecking=no root@"$source_ip" "docker-compose down 2>/dev/null || docker stop \$(docker ps -q) 2>/dev/null || true"
    ssh -o StrictHostKeyChecking=no root@"$target_ip" "cd /opt/homelab && docker-compose down 2>/dev/null || true"
    
    # Migrate volume data
    local volumes=$(ssh -o StrictHostKeyChecking=no root@"$source_ip" "docker volume ls -q" 2>/dev/null || echo "")
    
    for volume in $volumes; do
        if [[ -n "$volume" ]]; then
            print_status "Migrating volume: $volume"
            
            # Create volume backup on source
            ssh -o StrictHostKeyChecking=no root@"$source_ip" "
                docker run --rm -v $volume:/data -v /tmp:/backup alpine tar -czf /backup/$volume.tar.gz -C /data . 2>/dev/null || true
            "
            
            # Transfer to target
            scp -o StrictHostKeyChecking=no root@"$source_ip":/tmp/$volume.tar.gz /tmp/
            scp -o StrictHostKeyChecking=no /tmp/$volume.tar.gz root@"$target_ip":/tmp/
            
            # Restore on target (if volume exists)
            ssh -o StrictHostKeyChecking=no root@"$target_ip" "
                if docker volume ls | grep -q $volume; then
                    docker run --rm -v $volume:/data -v /tmp:/backup alpine tar -xzf /backup/$volume.tar.gz -C /data 2>/dev/null || true
                fi
            "
            
            # Cleanup
            rm -f /tmp/$volume.tar.gz
            ssh -o StrictHostKeyChecking=no root@"$source_ip" "rm -f /tmp/$volume.tar.gz"
            ssh -o StrictHostKeyChecking=no root@"$target_ip" "rm -f /tmp/$volume.tar.gz"
        fi
    done
    
    # Restart services on target
    ssh -o StrictHostKeyChecking=no root@"$target_ip" "cd /opt/homelab && docker-compose up -d"
    
    print_success "Service data migration completed"
}

create_migration_report() {
    local source_vmid="$1"
    local target_vmid="$2"
    local target_type="$3"
    
    local report_file="$MIGRATION_DIR/migration-report-${source_vmid}-to-${target_vmid}.json"
    
    cat > "$report_file" << EOF
{
    "migration_id": "$(uuidgen 2>/dev/null || echo "migration-$(date +%s)")",
    "timestamp": "$(date -Iseconds)",
    "source": {
        "vmid": "$source_vmid",
        "type": "legacy"
    },
    "target": {
        "vmid": "$target_vmid",
        "type": "$target_type"
    },
    "status": "completed",
    "backup_location": "$(cat "$BACKUP_DIR/latest-$source_vmid" 2>/dev/null || echo "unknown")",
    "next_steps": [
        "Test new deployment functionality",
        "Update DNS/networking configuration",
        "Verify all services are working",
        "Stop old VM when satisfied",
        "Remove old VM after verification period"
    ]
}
EOF
    
    print_success "Migration report created: $report_file"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --scan)
            ACTION="scan"
            shift
            ;;
        --migrate)
            ACTION="migrate"
            shift
            ;;
        --backup)
            ACTION="backup"
            shift
            ;;
        --validate)
            ACTION="validate"
            shift
            ;;
        --source-vmid)
            SOURCE_VMID="$2"
            shift 2
            ;;
        --target-vmid)
            TARGET_VMID="$2"
            shift 2
            ;;
        --target-type)
            TARGET_TYPE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --force)
            FORCE="true"
            shift
            ;;
        --backup-only)
            BACKUP_ONLY="true"
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

# Create necessary directories
mkdir -p "$MIGRATION_DIR" "$BACKUP_DIR"

# Execute action
case "$ACTION" in
    "scan")
        detect_legacy_deployments
        ;;
    "backup")
        if [[ -z "$SOURCE_VMID" ]]; then
            print_error "Source VMID required for backup"
            exit 1
        fi
        backup_legacy_deployment "$SOURCE_VMID"
        ;;
    "validate")
        if [[ -z "$SOURCE_VMID" ]]; then
            print_error "Source VMID required for validation"
            exit 1
        fi
        validate_migration "$SOURCE_VMID"
        ;;
    "migrate")
        if [[ -z "$SOURCE_VMID" ]]; then
            print_error "Source VMID required for migration"
            exit 1
        fi
        perform_migration "$SOURCE_VMID" "$TARGET_VMID" "$TARGET_TYPE"
        ;;
    *)
        print_error "Unknown action: $ACTION"
        show_usage
        exit 1
        ;;
esac