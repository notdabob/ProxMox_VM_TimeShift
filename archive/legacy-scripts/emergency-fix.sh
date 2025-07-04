#!/bin/bash
# Emergency fix for broken container services

echo "=== Emergency Container Fix ==="
echo ""

# First, let's see what's actually running in the container
echo "1. Checking what's running inside container..."
docker exec idrac-manager ps aux | grep -E "(nginx|python|supervisor)" || echo "No services found"

# Check if the start script ran
echo ""
echo "2. Checking if start.sh executed..."
docker exec idrac-manager cat /app/start.sh 2>/dev/null || echo "Start script not found"

# Check the supervisor config location
echo ""
echo "3. Checking supervisor configuration..."
docker exec idrac-manager ls -la /etc/supervisor/conf.d/ 2>/dev/null || echo "No supervisor conf.d"
docker exec idrac-manager ls -la /etc/supervisor/supervisord.conf 2>/dev/null || echo "No main supervisord.conf"

# Try to manually run the start script
echo ""
echo "4. Manually running start script..."
docker exec -it idrac-manager /bin/bash -c "/app/start.sh" &

# Wait a bit
sleep 10

# If that doesn't work, start services individually
echo ""
echo "5. Starting services manually..."

# Start nginx
echo "Starting nginx..."
docker exec -d idrac-manager nginx -g "daemon off;" || echo "Nginx failed to start"

# Start API
echo "Starting API server..."
docker exec -d idrac-manager python3 /app/src/idrac-container-api.py || echo "API failed to start"

# Start scanner
echo "Starting network scanner..."
docker exec -d idrac-manager python3 /app/src/network-scanner.py || echo "Scanner failed to start"

# Check if anything is listening now
echo ""
echo "6. Checking listening ports..."
docker exec idrac-manager netstat -tlnp 2>/dev/null || docker exec idrac-manager ss -tlnp 2>/dev/null || echo "No netstat/ss available"

# Final check
sleep 5
echo ""
echo "7. Final status check..."
curl -s -o /dev/null -w "Dashboard: %{http_code}\n" http://localhost:8080
curl -s -o /dev/null -w "API: %{http_code}\n" http://localhost:8765

echo ""
echo "=== Fix attempt complete ==="
echo ""
echo "If services still aren't running, the container needs to be rebuilt:"
echo "  docker stop idrac-manager"
echo "  docker rm idrac-manager"
echo "  docker rmi idrac-manager:latest"
echo "  ./deploy-proxmox.sh deploy"