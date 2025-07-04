#!/bin/bash
# Complete container rebuild script

echo "=== Complete Container Rebuild ==="
echo ""

# Stop and remove existing container
echo "1. Cleaning up old container..."
docker stop idrac-manager 2>/dev/null
docker rm idrac-manager 2>/dev/null

# Remove old image to force rebuild
echo "2. Removing old image..."
docker rmi idrac-manager:latest 2>/dev/null

# Install jq if missing (for Proxmox)
echo "3. Installing dependencies..."
which jq >/dev/null || apt-get update && apt-get install -y jq

# Rebuild from scratch
echo "4. Building new container..."
docker build -t idrac-manager:latest . || {
    echo "Build failed! Check Dockerfile"
    exit 1
}

# Run with explicit command to debug
echo "5. Starting container with debug output..."
docker run -d \
    --name idrac-manager \
    --restart unless-stopped \
    -p 8080:80 \
    -p 8765:8765 \
    --network bridge \
    idrac-manager:latest

# Wait for container to start
echo "6. Waiting for container startup (20 seconds)..."
sleep 20

# Check what's running
echo "7. Checking container processes..."
docker exec idrac-manager ps aux

# Check logs
echo ""
echo "8. Container logs:"
docker logs --tail 50 idrac-manager

# Test services
echo ""
echo "9. Testing services..."
echo -n "API Status: "
curl -s http://localhost:8765/status 2>/dev/null | jq -r '.status' 2>/dev/null || echo "Not responding"

echo -n "Dashboard: "
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8080

# Show access URL
echo ""
echo "=== Rebuild Complete ==="
PROXMOX_IP=$(hostname -I | awk '{print $1}')
echo "Dashboard URL: http://${PROXMOX_IP}:8080"
echo ""
echo "If services still aren't working, check:"
echo "  docker logs idrac-manager"
echo "  docker exec -it idrac-manager /bin/bash"