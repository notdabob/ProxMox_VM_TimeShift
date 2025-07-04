#!/bin/bash
# Quick fix - restart container and check services

echo "=== Restarting Container ==="

# Stop and remove the old container
echo "1. Stopping old container..."
docker stop idrac-manager
docker rm idrac-manager

# Rebuild and start fresh
echo ""
echo "2. Rebuilding container..."
cd "$(dirname "$0")"
./deploy-proxmox.sh deploy

# Wait for services to start
echo ""
echo "3. Waiting for services to start (30 seconds)..."
sleep 30

# Check status
echo ""
echo "4. Checking services..."
docker exec idrac-manager supervisorctl status || echo "Supervisor check failed"

echo ""
echo "5. Checking API..."
curl -s http://localhost:8765/status | jq '.' || echo "API not ready yet"

echo ""
echo "6. Checking dashboard..."
curl -s -o /dev/null -w "Dashboard HTTP status: %{http_code}\n" http://localhost:8080

echo ""
echo "7. Checking data files..."
docker exec idrac-manager ls -la /app/www/data/

echo ""
echo "=== Complete ==="
echo "Dashboard should be available at http://$(hostname -I | awk '{print $1}'):8080"