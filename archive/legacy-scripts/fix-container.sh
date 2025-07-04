#\!/bin/bash
# Fix container services

echo "=== Fixing Container Services ==="

# Check if container is running
if \! docker ps | grep -q idrac-manager; then
    echo "Container not running. Starting..."
    docker start idrac-manager
fi

# Check what's running inside the container
echo ""
echo "1. Checking processes inside container..."
docker exec idrac-manager ps aux

# Check if supervisor is installed
echo ""
echo "2. Checking supervisor installation..."
docker exec idrac-manager which supervisord || echo "Supervisor not found\!"

# Try to start supervisor manually
echo ""
echo "3. Starting supervisor manually..."
docker exec idrac-manager /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf &

# Wait a moment
sleep 5

# Check supervisor status again
echo ""
echo "4. Checking supervisor status..."
docker exec idrac-manager supervisorctl status 2>/dev/null || echo "Supervisor still not running"

# Check if services are listening
echo ""
echo "5. Checking listening ports..."
docker exec idrac-manager netstat -tlnp 2>/dev/null || docker exec idrac-manager ss -tlnp

# Try to start services manually if supervisor failed
echo ""
echo "6. If supervisor failed, starting services manually..."
docker exec -d idrac-manager nginx
docker exec -d idrac-manager python3 /app/src/idrac-container-api.py
docker exec -d idrac-manager python3 /app/src/network-scanner.py

# Check logs
echo ""
echo "7. Checking container logs..."
docker logs --tail 20 idrac-manager

echo ""
echo "=== Done ==="
echo "Wait 10 seconds then try accessing http://localhost:8080"
