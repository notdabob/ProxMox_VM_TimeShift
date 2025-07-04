#!/bin/bash
# Debug script for network scanner issues

echo "=== Network Scanner Debug ==="
echo ""

# Check if container is running
echo "1. Checking container status..."
if docker ps | grep -q idrac-manager; then
    echo "✓ Container is running"
else
    echo "✗ Container is not running"
    exit 1
fi

# Check supervisor status
echo ""
echo "2. Checking supervisor services..."
docker exec idrac-manager supervisorctl status

# Check scanner logs
echo ""
echo "3. Last 20 lines of scanner logs..."
docker exec idrac-manager tail -20 /var/log/supervisor/scanner_error.log 2>/dev/null || echo "No error logs"
echo "---"
docker exec idrac-manager tail -20 /var/log/supervisor/scanner.log 2>/dev/null || echo "No output logs"

# Check if data files exist
echo ""
echo "4. Checking data files..."
docker exec idrac-manager ls -la /app/www/data/

# Test network detection
echo ""
echo "5. Testing network detection..."
docker exec idrac-manager python3 -c "
import subprocess
result = subprocess.run(['ip', 'addr', 'show'], capture_output=True, text=True)
print('IP command output:')
for line in result.stdout.split('\n'):
    if 'inet ' in line:
        print(f'  {line.strip()}')
"

# Test Python imports
echo ""
echo "6. Testing Python imports..."
docker exec idrac-manager python3 -c "
try:
    import ipaddress
    print('✓ ipaddress module: OK')
except ImportError as e:
    print('✗ ipaddress module:', e)

try:
    import socket
    print('✓ socket module: OK')
except ImportError as e:
    print('✗ socket module:', e)

try:
    import json
    print('✓ json module: OK')
except ImportError as e:
    print('✗ json module:', e)
"

# Test API
echo ""
echo "7. Testing API..."
curl -s http://localhost:8765/status | jq '.' 2>/dev/null || echo "API not responding"

# Check nginx
echo ""
echo "8. Testing nginx..."
curl -s -o /dev/null -w "Dashboard HTTP status: %{http_code}\n" http://localhost:8080

echo ""
echo "=== Debug complete ==="