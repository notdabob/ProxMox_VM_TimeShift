#!/bin/bash

# Proxmox iDRAC Management Container Deployment Script
# This script deploys a containerized iDRAC management solution on Proxmox

set -e

# Configuration
CONTAINER_NAME="idrac-manager"
CONTAINER_IMAGE="idrac-manager:latest"
# Note: Using host networking mode, so these ports are not remapped
HTTP_PORT="80"     # Dashboard port (nginx)
API_PORT="8765"    # API server port
DATA_VOLUME="idrac-data"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Function to check if running on Proxmox
check_proxmox() {
    if [ ! -f /etc/pve/.version ]; then
        print_error "This script is designed to run on Proxmox VE hosts"
        print_error "If you're running on a different system, you can still use the Docker commands manually"
        exit 1
    fi
    
    # The .version file contains JSON data, so let's just check for pvesh command instead
    if command -v pvesh &> /dev/null; then
        print_success "Proxmox VE detected"
    else
        print_warning "Proxmox VE version file found but pvesh command not available"
    fi
}

# Function to install Docker if not present
install_docker() {
    if command -v docker &> /dev/null; then
        print_success "Docker is already installed"
        return 0
    fi
    
    print_status "Installing Docker..."
    
    # Update package lists
    apt-get update
    
    # Install required packages
    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    # Add Docker GPG key
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Update package lists again
    apt-get update
    
    # Install Docker
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Start and enable Docker
    systemctl start docker
    systemctl enable docker
    
    print_success "Docker installed and started"
}

# Function to build the container image
build_container() {
    print_status "Building iDRAC management container..."
    
    # Check if Dockerfile exists
    if [ ! -f "Dockerfile" ]; then
        print_error "Dockerfile not found in current directory"
        print_error "Please run this script from the project root directory"
        exit 1
    fi
    
    # Build the Docker image
    docker build -t "$CONTAINER_IMAGE" .
    
    print_success "Container image built: $CONTAINER_IMAGE"
}

# Function to create data volume
create_volume() {
    print_status "Creating data volume..."
    
    # Create named volume for persistent data
    if docker volume inspect "$DATA_VOLUME" &> /dev/null; then
        print_warning "Volume $DATA_VOLUME already exists, using existing volume"
    else
        docker volume create "$DATA_VOLUME"
        print_success "Created data volume: $DATA_VOLUME"
    fi
}

# Function to stop existing container
stop_existing_container() {
    if docker ps -a --format "table {{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
        print_status "Stopping existing container..."
        docker stop "$CONTAINER_NAME" || true
        docker rm "$CONTAINER_NAME" || true
        print_success "Existing container removed"
    fi
}

# Function to deploy the container
deploy_container() {
    print_status "Deploying iDRAC management container..."
    
    # Get the host IP for display purposes
    HOST_IP=$(hostname -I | awk '{print $1}')
    
    # Run the container with host networking for proper network access
    docker run -d \
        --name "$CONTAINER_NAME" \
        --restart unless-stopped \
        --network host \
        -v "$DATA_VOLUME:/app/data" \
        --cap-add=NET_ADMIN \
        --cap-add=NET_RAW \
        "$CONTAINER_IMAGE"
    
    print_success "Container deployed successfully!"
    
    # Wait a moment for the container to start
    sleep 5
    
    # Check if container is running
    if docker ps --format "table {{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
        print_success "Container is running and healthy"
        echo ""
        echo "╔══════════════════════════════════════════════════════════════════════════════════╗"
        echo "║                  🚀 iDRAC Management Dashboard DEPLOYED! 🚀                     ║"
        echo "╠══════════════════════════════════════════════════════════════════════════════════╣"
        echo "║                                                                                  ║"
        echo "║  🌐 CLICK TO ACCESS YOUR DASHBOARD:                                              ║"
        echo "║                                                                                  ║"
        echo -e "║     ${GREEN}${BLUE}http://$HOST_IP${NC} (or http://$HOST_IP:80)                                        ║"
        echo "║                                                                                  ║"
        echo "║  📋 Copy and paste this URL into any web browser on your network                ║"
        echo "║  📱 Works on computers, phones, tablets - anywhere!                             ║"
        echo "║                                                                                  ║"
        echo "╠══════════════════════════════════════════════════════════════════════════════════╣"
        echo "║  ✅ Your container is now running with these features:                           ║"
        echo "║     • 🔍 Auto-discovering iDRAC servers on your network                         ║"
        echo "║     • 🖥️  Professional web management interface                                  ║"
        echo "║     • 🔑 One-click SSH key generation and deployment                             ║"
        echo "║     • 🚀 Direct Virtual Console access (no downloads!)                          ║"
        echo "║     • 🚫 Zero macOS quarantine issues                                           ║"
        echo "║                                                                                  ║"
        echo "║  🔐 Default iDRAC Credentials (change after first login):                       ║"
        echo "║     Username: root                                                               ║"
        echo "║     Password: calvin                                                             ║"
        echo "║                                                                                  ║"
        echo "║  🛠️  Container Management Commands:                                              ║"
        echo "║     • View logs:    docker logs $CONTAINER_NAME                        ║"
        echo "║     • Restart:      docker restart $CONTAINER_NAME                     ║"
        echo "║     • Stop:         docker stop $CONTAINER_NAME                        ║"
        echo "║     • Update:       ./deploy-proxmox.sh update                                  ║"
        echo "║                                                                                  ║"
        echo "╚══════════════════════════════════════════════════════════════════════════════════╝"
        echo ""
        echo -e "${GREEN}${BLUE}🎯 QUICK START: Open your browser and go to http://$HOST_IP${NC}"
        echo -e "${YELLOW}💡 TIP: Bookmark this URL for easy access from any device!${NC}"
    else
        print_error "Container failed to start. Check logs with: docker logs $CONTAINER_NAME"
        exit 1
    fi
}

# Function to show container logs
show_logs() {
    print_status "Showing container logs..."
    docker logs --tail 50 -f "$CONTAINER_NAME"
}

# Function to check container status
check_status() {
    print_status "Checking container status..."
    
    if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -q "^$CONTAINER_NAME"; then
        print_success "Container is running:"
        docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep "^$CONTAINER_NAME"
        
        # Test API endpoint
        local host_ip=$(hostname -I | awk '{print $1}')
        if curl -s "http://localhost:$API_PORT/status" > /dev/null; then
            print_success "API endpoint is responding"
        else
            print_warning "API endpoint not responding yet (container may still be starting)"
        fi
        
        echo ""
        echo "╔═══════════════════════════════════════════════════╗"
        echo "║  🌐 DASHBOARD ACCESS URL:                         ║"
        echo "║                                                   ║"
        echo -e "║     ${GREEN}${BLUE}http://$host_ip:$HTTP_PORT${NC}                        ║"
        echo "║                                                   ║"
        echo "║  📋 Copy this URL to your browser                 ║"
        echo "╚═══════════════════════════════════════════════════╝"
    else
        print_warning "Container is not running"
        
        if docker ps -a --format "table {{.Names}}" | grep -q "^$CONTAINER_NAME$"; then
            print_status "Container exists but is stopped. Recent logs:"
            docker logs --tail 20 "$CONTAINER_NAME"
        else
            print_warning "Container does not exist"
        fi
    fi
}

# Function to remove everything
cleanup() {
    print_status "Removing iDRAC management container and data..."
    
    # Stop and remove container
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    
    # Remove image
    docker rmi "$CONTAINER_IMAGE" 2>/dev/null || true
    
    # Remove volume (ask for confirmation)
    if docker volume inspect "$DATA_VOLUME" &> /dev/null; then
        echo ""
        read -p "Remove data volume '$DATA_VOLUME'? This will delete all server data. (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker volume rm "$DATA_VOLUME"
            print_success "Data volume removed"
        else
            print_warning "Data volume preserved"
        fi
    fi
    
    print_success "Cleanup completed"
}

# Function to update container
update_container() {
    print_status "Updating iDRAC management container..."
    
    # Stop existing container
    stop_existing_container
    
    # Rebuild image
    build_container
    
    # Deploy new container
    deploy_container
}

# Function to show help
show_help() {
    echo "Proxmox iDRAC Management Container Deployment"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  deploy    Deploy the container (default)"
    echo "  status    Check container status"
    echo "  logs      Show container logs"
    echo "  update    Update the container"
    echo "  cleanup   Remove container and data"
    echo "  help      Show this help"
    echo ""
    echo "Examples:"
    echo "  $0                # Deploy container"
    echo "  $0 deploy         # Deploy container"
    echo "  $0 status         # Check status"
    echo "  $0 logs           # View logs"
    echo "  $0 update         # Update container"
}

# Main function
main() {
    local command="${1:-deploy}"
    
    echo "🖥️  Proxmox iDRAC Management Container"
    echo "====================================="
    echo ""
    
    case "$command" in
        deploy)
            check_proxmox
            install_docker
            stop_existing_container
            build_container
            create_volume
            deploy_container
            ;;
        status)
            check_status
            ;;
        logs)
            show_logs
            ;;
        update)
            check_proxmox
            update_container
            ;;
        cleanup)
            cleanup
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            print_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   print_error "This script must be run as root (use sudo)"
   exit 1
fi

# Run main function
main "$@"