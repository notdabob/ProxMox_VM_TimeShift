#!/bin/bash

# CREATE-MISSING-FILES.sh
# Creates all unified stack files for ProxMox homelab deployment
# Run this script in your /root/projects/time-shift-proxmox directory

set -e

echo "🚀 Creating ProxMox Unified Stack Files..."

# Create directories
mkdir -p scripts config config/dashboard docs

echo "📁 Creating unified VM creation script..."
cat > scripts/unified-vm-create.sh << 'EOF'
#!/bin/bash

# Unified VM Creation Script for ProxMox Homelab
# Supports: MCP, iDRAC, Hybrid, Monitoring, Time-Shift profiles

set -e

# Configuration
TEMPLATE_ID=9000
STORAGE="local-lvm"
BRIDGE="vmbr0"
MEMORY=2048
CORES=2
DISK_SIZE="20G"

# VMID Ranges
declare -A VMID_RANGES=(
    ["mcp"]="200-209"
    ["idrac"]="210-219" 
    ["hybrid"]="220-229"
    ["monitoring"]="230-239"
    ["timeshift"]="240-249"
)

# Port Ranges
declare -A PORT_RANGES=(
    ["mcp"]="7001-7010"
    ["idrac"]="8080-8090"
    ["hybrid"]="9000-9010"
    ["monitoring"]="3000-3010"
    ["timeshift"]="8000-8010"
)

usage() {
    echo "Usage: $0 --type <profile> [options]"
    echo "Profiles: mcp, idrac, hybrid, monitoring, timeshift"
    echo "Options:"
    echo "  --vmid <id>     Specific VMID (optional)"
    echo "  --memory <mb>   RAM in MB (default: 2048)"
    echo "  --cores <n>     CPU cores (default: 2)"
    echo "  --storage <s>   Storage pool (default: local-lvm)"
    exit 1
}

get_next_vmid() {
    local profile=$1
    local range=${VMID_RANGES[$profile]}
    local start=$(echo $range | cut -d'-' -f1)
    local end=$(echo $range | cut -d'-' -f2)
    
    for vmid in $(seq $start $end); do
        if ! qm status $vmid >/dev/null 2>&1; then
            echo $vmid
            return
        fi
    done
    
    echo "ERROR: No available VMID in range $range" >&2
    exit 1
}

create_vm() {
    local vmid=$1
    local profile=$2
    
    echo "🔧 Creating VM $vmid with profile: $profile"
    
    # Clone from template
    qm clone $TEMPLATE_ID $vmid --name "${profile}-${vmid}" --full
    
    # Configure VM
    qm set $vmid \
        --memory $MEMORY \
        --cores $CORES \
        --net0 virtio,bridge=$BRIDGE \
        --onboot 1 \
        --description "ProxMox Unified Stack - $profile profile"
    
    # Resize disk if needed
    qm resize $vmid scsi0 $DISK_SIZE
    
    echo "✅ VM $vmid created successfully"
    echo "📝 Profile: $profile"
    echo "🔗 Port range: ${PORT_RANGES[$profile]}"
    
    # Start VM
    echo "🚀 Starting VM $vmid..."
    qm start $vmid
    
    # Wait for VM to be ready
    echo "⏳ Waiting for VM to boot..."
    sleep 30
    
    # Get VM IP
    local vm_ip=$(qm guest cmd $vmid network-get-interfaces | jq -r '.[] | select(.name=="eth0") | .["ip-addresses"][] | select(.["ip-address-type"]=="ipv4") | .["ip-address"]' 2>/dev/null || echo "IP_NOT_FOUND")
    
    if [ "$vm_ip" != "IP_NOT_FOUND" ]; then
        echo "🌐 VM IP: $vm_ip"
        echo "🎯 Dashboard will be available at: http://$vm_ip:9010"
    else
        echo "⚠️  Could not determine VM IP. Check ProxMox console."
    fi
    
    echo "VM_ID=$vmid" > /tmp/last-vm-created
    echo "VM_IP=$vm_ip" >> /tmp/last-vm-created
    echo "PROFILE=$profile" >> /tmp/last-vm-created
}

# Parse arguments
PROFILE=""
VMID=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --type)
            PROFILE="$2"
            shift 2
            ;;
        --vmid)
            VMID="$2"
            shift 2
            ;;
        --memory)
            MEMORY="$2"
            shift 2
            ;;
        --cores)
            CORES="$2"
            shift 2
            ;;
        --storage)
            STORAGE="$2"
            shift 2
            ;;
        *)
            usage
            ;;
    esac
done

# Validate profile
if [[ -z "$PROFILE" ]] || [[ ! "${VMID_RANGES[$PROFILE]}" ]]; then
    echo "ERROR: Invalid or missing profile"
    usage
fi

# Get VMID
if [[ -z "$VMID" ]]; then
    VMID=$(get_next_vmid $PROFILE)
fi

# Validate template exists
if ! qm status $TEMPLATE_ID >/dev/null 2>&1; then
    echo "ERROR: Template VM $TEMPLATE_ID not found"
    echo "Please create a template VM first"
    exit 1
fi

# Create VM
create_vm $VMID $PROFILE

echo "🎉 VM creation completed!"
echo "Next step: Run ./deploy-unified-stack.sh --vmid $VMID"
EOF

chmod +x scripts/unified-vm-create.sh

echo "📁 Creating unified deployment script..."
cat > deploy-unified-stack.sh << 'EOF'
#!/bin/bash

# Unified Stack Deployment Script
# Deploys services to created VMs based on profile

set -e

usage() {
    echo "Usage: $0 --vmid <vmid> [options]"
    echo "Options:"
    echo "  --profile <p>   Override profile detection"
    echo "  --skip-docker   Skip Docker installation"
    exit 1
}

deploy_to_vm() {
    local vmid=$1
    local profile=$2
    
    echo "🚀 Deploying unified stack to VM $vmid (profile: $profile)"
    
    # Get VM IP
    local vm_ip=$(qm guest cmd $vmid network-get-interfaces | jq -r '.[] | select(.name=="eth0") | .["ip-addresses"][] | select(.["ip-address-type"]=="ipv4") | .["ip-address"]' 2>/dev/null || echo "")
    
    if [[ -z "$vm_ip" ]]; then
        echo "ERROR: Could not get VM IP for VMID $vmid"
        exit 1
    fi
    
    echo "🌐 Deploying to VM IP: $vm_ip"
    
    # Copy deployment files to VM
    echo "📦 Copying files to VM..."
    scp -o StrictHostKeyChecking=no docker-compose-unified.yaml root@$vm_ip:/root/
    scp -o StrictHostKeyChecking=no -r config/ root@$vm_ip:/root/
    
    # Install Docker if needed
    if [[ "$SKIP_DOCKER" != "true" ]]; then
        echo "🐳 Installing Docker..."
        ssh -o StrictHostKeyChecking=no root@$vm_ip << 'DOCKER_INSTALL'
            if ! command -v docker &> /dev/null; then
                curl -fsSL https://get.docker.com -o get-docker.sh
                sh get-docker.sh
                systemctl enable docker
                systemctl start docker
            fi
            
            if ! command -v docker-compose &> /dev/null; then
                curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
                chmod +x /usr/local/bin/docker-compose
            fi
DOCKER_INSTALL
    fi
    
    # Deploy services
    echo "🎯 Starting services..."
    ssh -o StrictHostKeyChecking=no root@$vm_ip << 'DEPLOY_SERVICES'
        cd /root
        export PROFILE_TYPE="'$profile'"
        export VM_IP="'$vm_ip'"
        docker-compose -f docker-compose-unified.yaml up -d
        
        echo "✅ Services deployed successfully"
        echo "🎯 Dashboard: http://'$vm_ip':9010"
        echo "📊 Services status:"
        docker-compose -f docker-compose-unified.yaml ps
DEPLOY_SERVICES
    
    echo "🎉 Deployment completed!"
    echo "🌐 Access dashboard at: http://$vm_ip:9010"
}

# Parse arguments
VMID=""
PROFILE=""
SKIP_DOCKER="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        --vmid)
            VMID="$2"
            shift 2
            ;;
        --profile)
            PROFILE="$2"
            shift 2
            ;;
        --skip-docker)
            SKIP_DOCKER="true"
            shift
            ;;
        *)
            usage
            ;;
    esac
done

if [[ -z "$VMID" ]]; then
    echo "ERROR: VMID required"
    usage
fi

# Auto-detect profile if not specified
if [[ -z "$PROFILE" ]] && [[ -f "/tmp/last-vm-created" ]]; then
    source /tmp/last-vm-created
    if [[ "$VM_ID" == "$VMID" ]]; then
        PROFILE="$PROFILE"
    fi
fi

if [[ -z "$PROFILE" ]]; then
    echo "ERROR: Could not determine profile. Use --profile option"
    exit 1
fi

deploy_to_vm $VMID $PROFILE
EOF

chmod +x deploy-unified-stack.sh

echo "📁 Creating Docker Compose configuration..."
cat > docker-compose-unified.yaml << 'EOF'
version: '3.8'

services:
  # Nginx Reverse Proxy
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "9010:9010"
    volumes:
      - ./config/nginx-unified.conf:/etc/nginx/nginx.conf:ro
      - ./config/dashboard:/usr/share/nginx/html/dashboard:ro
    restart: unless-stopped
    networks:
      - unified-net

  # Time-Shift Proxy Service
  timeshift-proxy:
    image: node:18-alpine
    working_dir: /app
    volumes:
      - ./config/timeshift:/app
    command: sh -c "npm install express http-proxy-middleware && node server.js"
    ports:
      - "8000:8000"
    environment:
      - NODE_ENV=production
      - PROXY_PORT=8000
    restart: unless-stopped
    networks:
      - unified-net

  # MCP Server (if profile supports)
  mcp-server:
    image: node:18-alpine
    working_dir: /app
    volumes:
      - ./config/mcp:/app
    command: sh -c "npm install @modelcontextprotocol/server && node mcp-server.js"
    ports:
      - "7001:7001"
    environment:
      - MCP_PORT=7001
      - PROFILE_TYPE=${PROFILE_TYPE:-hybrid}
    restart: unless-stopped
    networks:
      - unified-net
    profiles:
      - mcp
      - hybrid

  # iDRAC Management Interface
  idrac-interface:
    image: nginx:alpine
    ports:
      - "8080:80"
    volumes:
      - ./config/idrac:/usr/share/nginx/html:ro
    restart: unless-stopped
    networks:
      - unified-net
    profiles:
      - idrac
      - hybrid

  # Monitoring Stack
  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./config/prometheus.yml:/etc/prometheus/prometheus.yml:ro
    restart: unless-stopped
    networks:
      - unified-net
    profiles:
      - monitoring
      - hybrid

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana-data:/var/lib/grafana
    restart: unless-stopped
    networks:
      - unified-net
    profiles:
      - monitoring
      - hybrid

networks:
  unified-net:
    driver: bridge

volumes:
  grafana-data:
EOF

echo "📁 Creating Nginx configuration..."
cat > config/nginx-unified.conf << 'EOF'
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Dashboard Server
    server {
        listen 9010;
        server_name _;
        
        location / {
            root /usr/share/nginx/html/dashboard;
            index index.html;
            try_files $uri $uri/ /index.html;
        }
        
        # API Proxy endpoints
        location /api/timeshift/ {
            proxy_pass http://timeshift-proxy:8000/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
        
        location /api/mcp/ {
            proxy_pass http://mcp-server:7001/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
        
        location /api/idrac/ {
            proxy_pass http://idrac-interface:80/;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }

    # Main HTTP Server
    server {
        listen 80;
        server_name _;
        
        location / {
            return 301 http://$host:9010;
        }
    }
}
EOF

echo "📁 Creating dashboard..."
cat > config/dashboard/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ProxMox Unified Stack Dashboard</title>
    <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background: #1a1a1a; color: #fff; }
        .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
        .header { text-align: center; margin-bottom: 40px; }
        .header h1 { color: #00d4aa; font-size: 2.5em; margin-bottom: 10px; }
        .header p { color: #888; font-size: 1.1em; }
        .services-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; margin-bottom: 40px; }
        .service-card { background: #2a2a2a; border-radius: 10px; padding: 20px; border-left: 4px solid #00d4aa; }
        .service-card h3 { color: #00d4aa; margin-bottom: 10px; }
        .service-card p { color: #ccc; margin-bottom: 15px; }
        .service-links a { display: inline-block; background: #00d4aa; color: #000; padding: 8px 16px; border-radius: 5px; text-decoration: none; margin-right: 10px; margin-bottom: 10px; font-weight: bold; }
        .service-links a:hover { background: #00b894; }
        .status-indicator { display: inline-block; width: 10px; height: 10px; border-radius: 50%; margin-right: 8px; }
        .status-online { background: #00d4aa; }
        .status-offline { background: #ff6b6b; }
        .system-info { background: #2a2a2a; border-radius: 10px; padding: 20px; }
        .system-info h3 { color: #00d4aa; margin-bottom: 15px; }
        .info-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 15px; }
        .info-item { background: #333; padding: 15px; border-radius: 5px; }
        .info-item strong { color: #00d4aa; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🚀 ProxMox Unified Stack</h1>
            <p>Centralized management dashboard for your homelab services</p>
        </div>

        <div class="services-grid">
            <div class="service-card">
                <h3><span class="status-indicator status-online"></span>Time-Shift Proxy</h3>
                <p>Intelligent proxy service for time-based request routing and caching</p>
                <div class="service-links">
                    <a href="http://VM_IP:8000" target="_blank">Access Service</a>
                    <a href="/api/timeshift/status" target="_blank">API Status</a>
                </div>
            </div>

            <div class="service-card">
                <h3><span class="status-indicator status-online"></span>MCP Server</h3>
                <p>Model Context Protocol server for AI model integration</p>
                <div class="service-links">
                    <a href="http://VM_IP:7001" target="_blank">MCP Interface</a>
                    <a href="/api/mcp/health" target="_blank">Health Check</a>
                </div>
            </div>

            <div class="service-card">
                <h3><span class="status-indicator status-online"></span>iDRAC Management</h3>
                <p>Dell iDRAC integration and management interface</p>
                <div class="service-links">
                    <a href="http://VM_IP:8080" target="_blank">iDRAC Console</a>
                    <a href="/api/idrac/status" target="_blank">System Status</a>
                </div>
            </div>

            <div class="service-card">
                <h3><span class="status-indicator status-online"></span>Monitoring Stack</h3>
                <p>Prometheus metrics collection and Grafana visualization</p>
                <div class="service-links">
                    <a href="http://VM_IP:3000" target="_blank">Grafana</a>
                    <a href="http://VM_IP:9090" target="_blank">Prometheus</a>
                </div>
            </div>
        </div>

        <div class="system-info">
            <h3>📊 System Information</h3>
            <div class="info-grid">
                <div class="info-item">
                    <strong>VM ID:</strong><br>
                    <span id="vm-id">Loading...</span>
                </div>
                <div class="info-item">
                    <strong>Profile:</strong><br>
                    <span id="profile">Loading...</span>
                </div>
                <div class="info-item">
                    <strong>IP Address:</strong><br>
                    <span id="ip-address">Loading...</span>
                </div>
                <div class="info-item">
                    <strong>Uptime:</strong><br>
                    <span id="uptime">Loading...</span>
                </div>
                <div class="info-item">
                    <strong>Services:</strong><br>
                    <span id="service-count">Loading...</span>
                </div>
                <div class="info-item">
                    <strong>Last Updated:</strong><br>
                    <span id="last-updated">Loading...</span>
                </div>
            </div>
        </div>
    </div>

    <script>
        // Update system information
        function updateSystemInfo() {
            const vmIp = window.location.hostname;
            document.getElementById('ip-address').textContent = vmIp;
            document.getElementById('last-updated').textContent = new Date().toLocaleString();
            
            // Replace VM_IP placeholders in links
            document.querySelectorAll('a[href*="VM_IP"]').forEach(link => {
                link.href = link.href.replace('VM_IP', vmIp);
            });
        }

        // Check service status
        async function checkServiceStatus() {
            const services = ['timeshift-proxy:8000', 'mcp-server:7001', 'idrac-interface:8080'];
            let onlineCount = 0;
            
            for (const service of services) {
                try {
                    const response = await fetch(`http://${window.location.hostname}:${service.split(':')[1]}/health`, {
                        method: 'GET',
                        mode: 'no-cors'
                    });
                    onlineCount++;
                } catch (e) {
                    // Service might be offline
                }
            }
            
            document.getElementById('service-count').textContent = `${onlineCount}/${services.length} Online`;
        }

        // Initialize dashboard
        updateSystemInfo();
        checkServiceStatus();
        
        // Update every 30 seconds
        setInterval(() => {
            updateSystemInfo();
            checkServiceStatus();
        }, 30000);
    </script>
</body>
</html>
EOF

echo "📁 Creating configuration files..."
mkdir -p config/timeshift config/mcp config/idrac

cat > config/timeshift/server.js << 'EOF'
const express = require('express');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();
const PORT = process.env.PROXY_PORT || 8000;

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ status: 'healthy', service: 'timeshift-proxy', timestamp: new Date().toISOString() });
});

// Time-shift proxy logic
app.use('/proxy', createProxyMiddleware({
    target: 'http://localhost:3000',
    changeOrigin: true,
    pathRewrite: { '^/proxy': '' }
}));

app.listen(PORT, () => {
    console.log(`Time-Shift Proxy running on port ${PORT}`);
});
EOF

cat > config/mcp/mcp-server.js << 'EOF'
const express = require('express');
const app = express();
const PORT = process.env.MCP_PORT || 7001;

app.use(express.json());

// Health check
app.get('/health', (req, res) => {
    res.json({ status: 'healthy', service: 'mcp-server', timestamp: new Date().toISOString() });
});

// MCP endpoints
app.get('/capabilities', (req, res) => {
    res.json({
        capabilities: ['text-generation', 'context-management', 'tool-integration'],
        version: '1.0.0'
    });
});

app.listen(PORT, () => {
    console.log(`MCP Server running on port ${PORT}`);
});
EOF

cat > config/idrac/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>iDRAC Management Interface</title>
    <style>
        body { font-family: Arial, sans-serif; background: #f0f0f0; padding: 20px; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; }
        h1 { color: #0066cc; }
    </style>
</head>
<body>
    <div class="container">
        <h1>iDRAC Management Interface</h1>
        <p>Dell iDRAC integration placeholder</p>
        <p>Status: <span style="color: green;">Online</span></p>
    </div>
</body>
</html>
EOF

cat > config/prometheus.yml << 'EOF'
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  
  - job_name: 'unified-stack'
    static_configs:
      - targets: ['nginx:9010', 'timeshift-proxy:8000', 'mcp-server:7001']
EOF

echo "📁 Creating documentation..."
cat > QUICK-START.md << 'EOF'
# ProxMox Unified Stack - Quick Start

## 🚀 Copy-Paste Commands for ProxMox Console

### 1. Create VM (Choose one profile)
```bash
# Hybrid profile (recommended - includes all services)
./scripts/unified-vm-create.sh --type hybrid

# MCP only
./scripts/unified-vm-create.sh --type mcp

# Time-shift only  
./scripts/unified-vm-create.sh --type timeshift
```

### 2. Deploy Services
```bash
# Use VMID from previous step
./deploy-unified-stack.sh --vmid <VMID>
```

### 3. Access Dashboard
```bash
# Dashboard will be available at:
http://<VM_IP>:9010
```

## 🔧 Troubleshooting

### Check VM Status
```bash
qm status <VMID>
```

### Get VM IP
```bash
qm guest cmd <VMID> network-get-interfaces
```

### Check Services
```bash
ssh root@<VM_IP> "docker-compose -f docker-compose-unified.yaml ps"
```

## 📊 Service Ports
- Dashboard: 9010
- Time-Shift Proxy: 8000  
- MCP Server: 7001
- iDRAC Interface: 8080
- Grafana: 3000
- Prometheus: 9090
EOF

echo "📁 Creating deployment guide..."
cat > DEPLOYMENT-GUIDE.md << 'EOF'
# ProxMox Unified Stack - Deployment Guide

## 🎯 Overview
This unified stack eliminates the complexity of multiple deployment approaches by providing a single, standardized system for managing ProxMox VMs and services.

## 🏗️ Architecture

### VMID Allocation
- **200-209**: MCP Servers
- **210-219**: iDRAC Management  
- **220-229**: Hybrid (All services)
- **230-239**: Monitoring Stack
- **240-249**: Time-Shift Services

### Port Allocation
- **7001-7010**: MCP Services
- **8000-8010**: Time-Shift Services
- **8080-8090**: iDRAC Interfaces
- **9000-9010**: Unified Dashboards
- **3000-3010**: Monitoring (Grafana)

## 🚀 Deployment Process

### Prerequisites
1. ProxMox VE host with template VM (ID: 9000)
2. Template should have Ubuntu/Debian with SSH enabled
3. Network bridge configured (default: vmbr0)

### Step 1: VM Creation
```bash
./scripts/unified-vm-create.sh --type <profile>
```

**Profiles Available:**
- `hybrid`: All services (recommended)
- `mcp`: MCP server only
- `idrac`: iDRAC management only  
- `monitoring`: Prometheus + Grafana
- `timeshift`: Time-shift proxy only

### Step 2: Service Deployment
```bash
./deploy-unified-stack.sh --vmid <VMID>
```

This will:
1. Install Docker on the VM
2. Copy configuration files
3. Start all services via Docker Compose
4. Configure reverse proxy

### Step 3: Verification
Access the unified dashboard at: `http://<VM_IP>:9010`

## 🔧 Configuration

### Custom VM Settings
```bash
./scripts/unified-vm-create.sh --type hybrid --memory 4096 --cores 4 --storage local-zfs
```

### Skip Docker Installation
```bash
./deploy-unified-stack.sh --vmid 220 --skip-docker
```

## 📊 Monitoring

### Service Health Checks
All services expose `/health` endpoints:
- Time-Shift: `http://<VM_IP>:8000/health`
- MCP: `http://<VM_IP>:7001/health`

### Docker Status
```bash
ssh root@<VM_IP> "docker-compose -f docker-compose-unified.yaml ps"
```

## 🛠️ Troubleshooting

### VM Won't Start
```bash
qm status <VMID>
qm start <VMID>
```

### Services Not Accessible
```bash
# Check if services are running
ssh root@<VM_IP> "docker ps"

# Check logs
ssh root@<VM_IP> "docker-compose -f docker-compose-unified.yaml logs"
```

### Network Issues
```bash
# Verify VM network
qm config <VMID> | grep net

# Check VM IP
qm guest cmd <VMID> network-get-interfaces
```

## 🔄 Updates and Maintenance

### Update Services
```bash
ssh root@<VM_IP> "docker-compose -f docker-compose-unified.yaml pull && docker-compose -f docker-compose-unified.yaml up -d"
```

### Backup Configuration
```bash
# Backup VM
vzdump <VMID> --storage local

# Backup configs
scp -r root@<VM_IP>:/root/config/ ./backup/
```

## 🎯 Next Steps
1. Configure monitoring alerts in Grafana
2. Set up SSL certificates for HTTPS
3. Integrate with external authentication
4. Scale services across multiple VMs
EOF

echo "✅ All unified stack files created successfully!"
echo ""
echo "🎯 Next Steps:"
echo "1. Run: chmod +x scripts/unified-vm-create.sh deploy-unified-stack.sh"
echo "2. Create a VM: ./scripts/unified-vm-create.sh --type hybrid"
echo "3. Deploy services: ./deploy-unified-stack.sh --vmid <VMID>"
echo "4. Access dashboard at: http://<VM_IP>:9010"
echo ""
echo "📚 Documentation created:"
echo "- QUICK-START.md (copy-paste commands)"
echo "- DEPLOYMENT-GUIDE.md (detailed instructions)"
echo ""
echo "🚀 Ready to deploy your ProxMox Unified Stack!"