#!/bin/bash
# Test script for multi-server discovery features

echo "Testing Multi-Server Discovery Features"
echo "======================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test if container is running
echo -e "\n${YELLOW}1. Checking if container is running...${NC}"
if docker ps | grep -q idrac-manager; then
    echo -e "${GREEN}✓ Container is running${NC}"
else
    echo -e "${RED}✗ Container is not running${NC}"
    echo "Please run: ./deploy-proxmox.sh deploy"
    exit 1
fi

# Test API status
echo -e "\n${YELLOW}2. Testing API status...${NC}"
API_STATUS=$(curl -s http://localhost:8765/status | jq -r '.status' 2>/dev/null)
if [ "$API_STATUS" = "running" ]; then
    echo -e "${GREEN}✓ API is running${NC}"
    curl -s http://localhost:8765/status | jq '.'
else
    echo -e "${RED}✗ API is not responding${NC}"
fi

# Test network scanner
echo -e "\n${YELLOW}3. Checking network scanner...${NC}"
docker exec idrac-manager supervisorctl status network-scanner

# Test custom range scanning
echo -e "\n${YELLOW}4. Testing custom range scanning...${NC}"
echo "Sending custom scan request for 192.168.1.0/24..."
curl -X POST http://localhost:8765/scan/custom \
    -H "Content-Type: application/json" \
    -d '{"ranges": ["192.168.1.0/24"]}' \
    -s | jq '.'

# Check discovered servers
echo -e "\n${YELLOW}5. Checking discovered servers...${NC}"
if [ -f "$(docker exec idrac-manager find /app/www/data -name 'discovered_servers.json' 2>/dev/null | head -1)" ]; then
    echo -e "${GREEN}✓ Multi-server discovery file exists${NC}"
    docker exec idrac-manager cat /app/www/data/discovered_servers.json | jq '.servers | length' | xargs -I {} echo "Found {} servers"
else
    echo -e "${YELLOW}! No servers discovered yet${NC}"
fi

# Test RDM export endpoints
echo -e "\n${YELLOW}6. Testing RDM export endpoints...${NC}"
echo "Testing JSON export..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/export/rdm/json | xargs -I {} echo "JSON export endpoint: {}"
echo "Testing XML export..."
curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/api/export/rdm/rdm | xargs -I {} echo "XML export endpoint: {}"

# Check dashboard
echo -e "\n${YELLOW}7. Testing dashboard...${NC}"
DASHBOARD_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080)
if [ "$DASHBOARD_STATUS" = "200" ]; then
    echo -e "${GREEN}✓ Dashboard is accessible at http://localhost:8080${NC}"
else
    echo -e "${RED}✗ Dashboard returned status: $DASHBOARD_STATUS${NC}"
fi

# Summary
echo -e "\n${YELLOW}Summary:${NC}"
echo "- Dashboard: http://localhost:8080"
echo "- API Status: http://localhost:8765/status"
echo "- Custom scan endpoint: POST http://localhost:8765/scan/custom"
echo "- RDM export: http://localhost:8080/api/export/rdm/{json|rdm}"
echo ""
echo "The scanner will automatically discover:"
echo "  - iDRAC servers (ports 80, 443)"
echo "  - Proxmox servers (port 8006)"
echo "  - Linux/SSH servers (port 22)"
echo "  - Windows servers (ports 3389, 5985)"
echo "  - VNC servers (ports 5900, 5901)"