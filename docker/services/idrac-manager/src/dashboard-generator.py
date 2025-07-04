#!/usr/bin/env python3
"""
Multi-Server Dashboard Generator
Creates web-based management interface for all server types
"""

import os
import json
from datetime import datetime

# Configuration
WWW_DIR = '/app/www'
DATA_DIR = '/app/www/data'
TEMPLATE_FILE = os.path.join(WWW_DIR, 'index.html')

def generate_dashboard():
    """Generate the main dashboard HTML"""
    
    dashboard_html = '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Homelab Server Management Dashboard</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            color: #333;
        }
        
        .header {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            padding: 20px;
            text-align: center;
            box-shadow: 0 2px 20px rgba(0, 0, 0, 0.1);
        }
        
        .header h1 {
            color: #2c3e50;
            margin-bottom: 10px;
            font-size: 2.5em;
        }
        
        .container-badge {
            background: #27ae60;
            color: white;
            padding: 8px 16px;
            border-radius: 20px;
            display: inline-block;
            font-weight: bold;
            margin-top: 10px;
        }
        
        .container {
            max-width: 1400px;
            margin: 40px auto;
            padding: 0 20px;
        }
        
        .status-panel {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            padding: 20px;
            margin-bottom: 30px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
        }
        
        .server-type-tabs {
            display: flex;
            gap: 10px;
            margin-bottom: 20px;
            flex-wrap: wrap;
        }
        
        .tab-button {
            padding: 10px 20px;
            border: none;
            background: #e0e0e0;
            border-radius: 8px;
            cursor: pointer;
            font-weight: 500;
            transition: all 0.3s ease;
        }
        
        .tab-button.active {
            background: #667eea;
            color: white;
        }
        
        .tab-button:hover {
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
        }
        
        .management-tools, .ssh-management, .network-scan {
            background: rgba(255, 255, 255, 0.95);
            backdrop-filter: blur(10px);
            border-radius: 15px;
            padding: 20px;
            margin-bottom: 30px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
        }
        
        .management-tools h3, .ssh-management h3, .network-scan h3 {
            margin-bottom: 15px;
            color: #2c3e50;
        }
        
        .custom-scan-form {
            display: flex;
            gap: 10px;
            align-items: center;
            margin-bottom: 15px;
        }
        
        .network-input {
            flex: 1;
            padding: 10px;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            font-size: 14px;
        }
        
        .ssh-form {
            display: flex;
            gap: 15px;
            align-items: center;
            flex-wrap: wrap;
            margin-bottom: 15px;
        }
        
        .email-input {
            flex: 1;
            padding: 12px;
            border: 2px solid #e0e0e0;
            border-radius: 8px;
            font-size: 16px;
            transition: border-color 0.3s ease;
        }
        
        .email-input:focus {
            outline: none;
            border-color: #667eea;
        }
        
        .tool-button {
            padding: 12px 24px;
            border: none;
            border-radius: 8px;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.3s ease;
            display: inline-flex;
            align-items: center;
            gap: 8px;
        }
        
        .primary-button {
            background: #667eea;
            color: white;
        }
        
        .primary-button:hover {
            background: #5a67d8;
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(102, 126, 234, 0.4);
        }
        
        .secondary-button {
            background: #3498db;
            color: white;
        }
        
        .secondary-button:hover {
            background: #2980b9;
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(52, 152, 219, 0.4);
        }
        
        .success-button {
            background: #27ae60;
            color: white;
        }
        
        .success-button:hover {
            background: #219a52;
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(39, 174, 96, 0.4);
        }
        
        .export-button {
            background: #f39c12;
            color: white;
        }
        
        .export-button:hover {
            background: #e67e22;
            transform: translateY(-2px);
            box-shadow: 0 4px 12px rgba(243, 156, 18, 0.4);
        }
        
        .server-grid {
            display: grid;
            grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
            gap: 20px;
            margin-top: 20px;
        }
        
        .server-card {
            background: white;
            border-radius: 12px;
            padding: 20px;
            box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
            transition: all 0.3s ease;
            border: 2px solid transparent;
        }
        
        .server-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 8px 30px rgba(0, 0, 0, 0.12);
            border-color: #667eea;
        }
        
        .server-type-icon {
            width: 40px;
            height: 40px;
            border-radius: 8px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            font-size: 24px;
            margin-bottom: 10px;
        }
        
        .type-idrac { background: #e74c3c; color: white; }
        .type-proxmox { background: #f39c12; color: white; }
        .type-linux { background: #2ecc71; color: white; }
        .type-windows { background: #3498db; color: white; }
        .type-vnc { background: #9b59b6; color: white; }
        .type-unknown { background: #95a5a6; color: white; }
        
        .server-header {
            display: flex;
            justify-content: space-between;
            align-items: start;
            margin-bottom: 15px;
        }
        
        .server-title {
            font-size: 18px;
            font-weight: 600;
            color: #2c3e50;
            margin-bottom: 5px;
        }
        
        .server-url {
            color: #7f8c8d;
            font-size: 14px;
            word-break: break-all;
        }
        
        .server-status {
            display: flex;
            align-items: center;
            gap: 8px;
            padding: 6px 12px;
            border-radius: 20px;
            font-size: 14px;
            font-weight: 500;
        }
        
        .status-online {
            background: #d4edda;
            color: #155724;
        }
        
        .status-offline {
            background: #f8d7da;
            color: #721c24;
        }
        
        .server-details {
            margin-top: 15px;
            padding-top: 15px;
            border-top: 1px solid #e0e0e0;
        }
        
        .detail-row {
            display: flex;
            justify-content: space-between;
            margin-bottom: 8px;
            font-size: 14px;
        }
        
        .detail-label {
            color: #7f8c8d;
        }
        
        .detail-value {
            color: #2c3e50;
            font-weight: 500;
        }
        
        .server-actions {
            margin-top: 15px;
            display: flex;
            gap: 10px;
            flex-wrap: wrap;
        }
        
        .action-button {
            padding: 8px 16px;
            border: none;
            border-radius: 6px;
            font-size: 14px;
            font-weight: 500;
            cursor: pointer;
            transition: all 0.3s ease;
        }
        
        .connect-button {
            background: #667eea;
            color: white;
        }
        
        .connect-button:hover {
            background: #5a67d8;
        }
        
        .remove-button {
            background: #e74c3c;
            color: white;
        }
        
        .remove-button:hover {
            background: #c0392b;
        }
        
        .info-message {
            background: #d1ecf1;
            color: #0c5460;
            padding: 12px;
            border-radius: 8px;
            margin-bottom: 15px;
            border-left: 4px solid #0c5460;
        }
        
        .success-message {
            background: #d4edda;
            color: #155724;
            padding: 12px;
            border-radius: 8px;
            margin-bottom: 15px;
            border-left: 4px solid #155724;
        }
        
        .error-message {
            background: #f8d7da;
            color: #721c24;
            padding: 12px;
            border-radius: 8px;
            margin-bottom: 15px;
            border-left: 4px solid #721c24;
        }
        
        .loading {
            display: inline-block;
            width: 20px;
            height: 20px;
            border: 3px solid #f3f3f3;
            border-top: 3px solid #667eea;
            border-radius: 50%;
            animation: spin 1s linear infinite;
            margin-left: 10px;
        }
        
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        
        .empty-state {
            text-align: center;
            padding: 60px 20px;
            color: #7f8c8d;
        }
        
        .empty-state-icon {
            font-size: 64px;
            margin-bottom: 20px;
            opacity: 0.5;
        }
        
        .footer {
            text-align: center;
            padding: 40px 20px;
            color: white;
            font-size: 14px;
        }
        
        .footer a {
            color: white;
            text-decoration: underline;
        }
        
        @media (max-width: 768px) {
            .server-grid {
                grid-template-columns: 1fr;
            }
            
            .header h1 {
                font-size: 1.8em;
            }
            
            .ssh-form {
                flex-direction: column;
            }
            
            .email-input {
                width: 100%;
            }
        }
    </style>
</head>
<body>
    <div class="header">
        <h1>🖥️ Homelab Server Management</h1>
        <div class="container-badge">🐳 Container Edition - Multi-Server Discovery</div>
    </div>
    
    <div class="container">
        <div class="status-panel">
            <h2>📊 System Status</h2>
            <div id="status-info">
                <p class="info-message">Loading system status...</p>
            </div>
        </div>
        
        <div class="network-scan">
            <h3>🔍 Network Discovery</h3>
            <div class="custom-scan-form">
                <input type="text" 
                       id="custom-ranges" 
                       class="network-input" 
                       placeholder="Enter custom ranges (e.g., 192.168.1.0/24, 10.0.0.0/24)"
                       value="">
                <button class="tool-button primary-button" onclick="scanCustomRanges()">
                    🔍 Scan Custom Ranges
                </button>
                <button class="tool-button secondary-button" onclick="rescanNetwork()">
                    🔄 Rescan Default Network
                </button>
            </div>
            <div id="scan-status"></div>
        </div>
        
        <div class="management-tools">
            <h3>🛠️ Management Tools</h3>
            <div style="display: flex; gap: 10px; flex-wrap: wrap;">
                <button class="tool-button export-button" onclick="exportToRDM('json')">
                    📤 Export to RDM (JSON)
                </button>
                <button class="tool-button export-button" onclick="exportToRDM('rdm')">
                    📤 Export to RDM (XML)
                </button>
                <button class="tool-button success-button" onclick="deploySSHKeys()">
                    🔑 Deploy SSH Keys to All
                </button>
            </div>
        </div>
        
        <div class="ssh-management">
            <h3>🔐 SSH Key Management</h3>
            <div id="ssh-status"></div>
            <div class="ssh-form">
                <input type="email" 
                       id="admin-email" 
                       class="email-input" 
                       placeholder="Enter your email address"
                       required>
                <button class="tool-button primary-button" onclick="generateSSHKey()">
                    🔑 Generate SSH Key
                </button>
            </div>
        </div>
        
        <div class="status-panel">
            <h2>🖥️ Discovered Servers</h2>
            <div class="server-type-tabs" id="server-tabs">
                <button class="tab-button active" onclick="filterServers('all')">All Servers</button>
                <button class="tab-button" onclick="filterServers('idrac')">iDRAC</button>
                <button class="tab-button" onclick="filterServers('proxmox')">Proxmox</button>
                <button class="tab-button" onclick="filterServers('linux')">Linux/SSH</button>
                <button class="tab-button" onclick="filterServers('windows')">Windows</button>
                <button class="tab-button" onclick="filterServers('vnc')">VNC</button>
            </div>
            <div id="servers-container">
                <div class="server-grid" id="server-list">
                    <p class="info-message">Loading servers...</p>
                </div>
            </div>
        </div>
    </div>
    
    <div class="footer">
        <p>Homelab Server Management Dashboard - Container Edition</p>
        <p>Auto-discovery enabled for iDRAC, Proxmox, Linux, Windows, and VNC servers</p>
    </div>
    
    <script>
        let allServers = [];
        let currentFilter = 'all';
        
        // Load server data
        async function loadServers() {
            try {
                // Try new multi-server file first
                let response = await fetch('/data/discovered_servers.json');
                if (!response.ok) {
                    // Fallback to legacy file
                    response = await fetch('/data/discovered_idracs.json');
                    if (!response.ok) {
                        // No data files exist yet
                        allServers = [];
                        updateStatusPanel({ servers: [], last_scan: '', scan_count: 0 });
                        renderServers();
                        return;
                    }
                }
                
                const data = await response.json();
                allServers = data.servers || [];
                
                updateStatusPanel(data);
                renderServers();
                
                // Update tabs based on available server types
                updateServerTabs();
            } catch (error) {
                console.error('Failed to load servers:', error);
                document.getElementById('server-list').innerHTML = 
                    '<p class="error-message">Failed to load server data. Please check the network scanner.</p>';
            }
        }
        
        // Update server type tabs
        function updateServerTabs() {
            const serverTypes = new Set(allServers.map(s => s.type || 'unknown'));
            // Tabs are already in HTML, just show/hide based on available types
        }
        
        // Filter servers by type
        function filterServers(type) {
            currentFilter = type;
            
            // Update tab styles
            document.querySelectorAll('.tab-button').forEach(btn => {
                btn.classList.remove('active');
            });
            event.target.classList.add('active');
            
            renderServers();
        }
        
        // Get server type icon
        function getServerIcon(type) {
            const icons = {
                'idrac': '🖥️',
                'proxmox': '🗄️',
                'linux': '🐧',
                'windows': '🪟',
                'vnc': '🖼️',
                'unknown': '❓'
            };
            return icons[type] || icons['unknown'];
        }
        
        // Update status panel
        function updateStatusPanel(data) {
            const statusInfo = document.getElementById('status-info');
            const lastScan = data.last_scan ? new Date(data.last_scan).toLocaleString() : 'Never';
            const scanCount = data.scan_count || 0;
            const onlineCount = allServers.filter(s => s.status === 'online').length;
            const totalCount = allServers.length;
            
            // Count by type
            const typeCounts = {};
            allServers.forEach(server => {
                const type = server.type || 'unknown';
                typeCounts[type] = (typeCounts[type] || 0) + 1;
            });
            
            let typeBreakdown = Object.entries(typeCounts)
                .map(([type, count]) => `${getServerIcon(type)} ${type}: ${count}`)
                .join(' | ');
            
            statusInfo.innerHTML = `
                <div class="detail-row">
                    <span class="detail-label">Last Scan:</span>
                    <span class="detail-value">${lastScan}</span>
                </div>
                <div class="detail-row">
                    <span class="detail-label">Total Scans:</span>
                    <span class="detail-value">${scanCount}</span>
                </div>
                <div class="detail-row">
                    <span class="detail-label">Servers Online:</span>
                    <span class="detail-value">${onlineCount} / ${totalCount}</span>
                </div>
                <div class="detail-row">
                    <span class="detail-label">Server Types:</span>
                    <span class="detail-value">${typeBreakdown || 'None'}</span>
                </div>
            `;
        }
        
        // Render server cards
        function renderServers() {
            const serverList = document.getElementById('server-list');
            
            // Filter servers based on current filter
            const filteredServers = currentFilter === 'all' 
                ? allServers 
                : allServers.filter(s => (s.type || 'unknown') === currentFilter);
            
            if (filteredServers.length === 0) {
                serverList.innerHTML = `
                    <div class="empty-state">
                        <div class="empty-state-icon">📡</div>
                        <h3>No ${currentFilter === 'all' ? '' : currentFilter} servers found</h3>
                        <p>The network scanner will automatically discover servers every 5 minutes.</p>
                        <button class="tool-button primary-button" onclick="rescanNetwork()">
                            🔄 Scan Network Now
                        </button>
                    </div>
                `;
                return;
            }
            
            serverList.innerHTML = filteredServers.map(server => {
                const isOnline = server.status === 'online';
                const statusClass = isOnline ? 'status-online' : 'status-offline';
                const statusText = isOnline ? '🟢 Online' : '🔴 Offline';
                const serverType = server.type || 'unknown';
                const typeIcon = getServerIcon(serverType);
                
                // Extract IP from URL or use IP field
                const ip = server.ip || server.url.replace(/^https?:\\/\\//, '').split(/[\\/\\:]/)[0];
                
                return `
                    <div class="server-card">
                        <div class="server-type-icon type-${serverType}">
                            ${typeIcon}
                        </div>
                        <div class="server-header">
                            <div>
                                <div class="server-title">${server.title || 'Unknown Server'}</div>
                                <div class="server-url">${server.url}</div>
                            </div>
                            <div class="server-status ${statusClass}">
                                ${statusText}
                            </div>
                        </div>
                        <div class="server-details">
                            <div class="detail-row">
                                <span class="detail-label">Type:</span>
                                <span class="detail-value">${serverType.toUpperCase()}</span>
                            </div>
                            <div class="detail-row">
                                <span class="detail-label">IP Address:</span>
                                <span class="detail-value">${ip}</span>
                            </div>
                            ${server.protocol ? `
                            <div class="detail-row">
                                <span class="detail-label">Protocol:</span>
                                <span class="detail-value">${server.protocol}</span>
                            </div>
                            ` : ''}
                            ${server.services && server.services.length > 0 ? `
                            <div class="detail-row">
                                <span class="detail-label">Services:</span>
                                <span class="detail-value">${server.services.map(s => s.type).join(', ')}</span>
                            </div>
                            ` : ''}
                        </div>
                        <div class="server-actions">
                            ${isOnline ? `
                                <button class="action-button connect-button" 
                                        onclick="connectToServer('${ip}')">
                                    🚀 Connect
                                </button>
                            ` : ''}
                            <button class="action-button remove-button" 
                                    onclick="removeServer('${server.url}')">
                                🗑️ Remove
                            </button>
                        </div>
                    </div>
                `;
            }).join('');
        }
        
        // Connect to server
        async function connectToServer(ip) {
            try {
                const response = await fetch('/api/execute', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        command: 'launch_virtual_console',
                        params: { ip }
                    })
                });
                
                const result = await response.json();
                
                if (result.status === 'success') {
                    // Download the connection script
                    const link = document.createElement('a');
                    link.href = `/downloads/${result.download_script}`;
                    link.download = result.download_script;
                    link.click();
                    
                    showMessage('success', `Connection prepared for ${result.server_type} server at ${ip}. Check your downloads.`);
                } else {
                    showMessage('error', result.error || 'Failed to prepare connection');
                }
            } catch (error) {
                showMessage('error', 'Failed to connect: ' + error.message);
            }
        }
        
        // Remove server
        async function removeServer(url) {
            if (!confirm('Are you sure you want to remove this server?')) {
                return;
            }
            
            try {
                const response = await fetch('/api/execute', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        command: 'remove_server',
                        params: { url }
                    })
                });
                
                const result = await response.json();
                
                if (result.status === 'success') {
                    showMessage('success', 'Server removed successfully');
                    loadServers(); // Reload the list
                } else {
                    showMessage('error', result.error || 'Failed to remove server');
                }
            } catch (error) {
                showMessage('error', 'Failed to remove server: ' + error.message);
            }
        }
        
        // Rescan network
        async function rescanNetwork() {
            const scanStatus = document.getElementById('scan-status');
            scanStatus.innerHTML = '<p class="info-message">Scanning network... <span class="loading"></span></p>';
            
            try {
                const response = await fetch('/api/execute', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ command: 'rescan_network' })
                });
                
                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }
                
                const result = await response.json();
                
                if (result.status === 'success') {
                    scanStatus.innerHTML = '<p class="success-message">Network scan started. Results will appear in 30-60 seconds.</p>';
                    
                    // Reload after delay
                    setTimeout(() => {
                        loadServers();
                        scanStatus.innerHTML = '';
                    }, 30000);
                } else {
                    scanStatus.innerHTML = `<p class="error-message">Scan failed: ${result.error}</p>`;
                }
            } catch (error) {
                scanStatus.innerHTML = `<p class="error-message">Failed to start scan: ${error.message}</p>`;
            }
        }
        
        // Scan custom ranges
        async function scanCustomRanges() {
            const rangesInput = document.getElementById('custom-ranges').value.trim();
            if (!rangesInput) {
                showMessage('error', 'Please enter network ranges to scan');
                return;
            }
            
            const ranges = rangesInput.split(',').map(r => r.trim()).filter(r => r);
            const scanStatus = document.getElementById('scan-status');
            scanStatus.innerHTML = `<p class="info-message">Scanning ${ranges.length} custom ranges... <span class="loading"></span></p>`;
            
            try {
                const response = await fetch('/api/scan/custom', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ ranges })
                });
                
                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }
                
                const contentType = response.headers.get('content-type');
                if (!contentType || !contentType.includes('application/json')) {
                    throw new Error('Response is not JSON');
                }
                
                const result = await response.json();
                
                if (result.status === 'success') {
                    scanStatus.innerHTML = '<p class="success-message">Custom scan started. Results will appear in 30-60 seconds.</p>';
                    
                    // Reload after delay
                    setTimeout(() => {
                        loadServers();
                        scanStatus.innerHTML = '';
                    }, 30000);
                } else {
                    scanStatus.innerHTML = `<p class="error-message">Scan failed: ${result.error}</p>`;
                }
            } catch (error) {
                scanStatus.innerHTML = `<p class="error-message">Failed to start scan: ${error.message}</p>`;
            }
        }
        
        // Export to RDM
        async function exportToRDM(format) {
            try {
                window.location.href = `/api/export/rdm/${format}`;
                showMessage('success', `Exporting servers to RDM ${format.toUpperCase()} format...`);
            } catch (error) {
                showMessage('error', 'Failed to export: ' + error.message);
            }
        }
        
        // SSH Key Management
        async function checkSSHStatus() {
            try {
                const response = await fetch('/data/admin_config.json');
                if (response.ok) {
                    const config = await response.json();
                    const sshStatus = document.getElementById('ssh-status');
                    
                    if (config.ssh_key_generated) {
                        sshStatus.innerHTML = `
                            <div class="success-message">
                                ✅ SSH key generated for: ${config.admin_email}
                                <br>
                                <small>Last updated: ${new Date(config.last_updated).toLocaleString()}</small>
                            </div>
                        `;
                        document.getElementById('admin-email').value = config.admin_email;
                    }
                }
            } catch (error) {
                console.log('No SSH configuration found');
            }
        }
        
        // Generate SSH key
        async function generateSSHKey() {
            const email = document.getElementById('admin-email').value.trim();
            if (!email) {
                showMessage('error', 'Please enter your email address');
                return;
            }
            
            const sshStatus = document.getElementById('ssh-status');
            sshStatus.innerHTML = '<p class="info-message">Generating SSH key... <span class="loading"></span></p>';
            
            try {
                const response = await fetch('/api/execute', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        command: 'generate_ssh_key',
                        params: { email }
                    })
                });
                
                const result = await response.json();
                
                if (result.status === 'success') {
                    sshStatus.innerHTML = `
                        <div class="success-message">
                            ✅ SSH key generated successfully!
                            <br>
                            <small>You can now deploy keys to servers.</small>
                        </div>
                    `;
                } else {
                    sshStatus.innerHTML = `<p class="error-message">Failed: ${result.error}</p>`;
                }
            } catch (error) {
                sshStatus.innerHTML = `<p class="error-message">Error: ${error.message}</p>`;
            }
        }
        
        // Deploy SSH keys
        async function deploySSHKeys() {
            if (!confirm('Deploy SSH keys to all online servers with SSH support?')) {
                return;
            }
            
            const sshStatus = document.getElementById('ssh-status');
            sshStatus.innerHTML = '<p class="info-message">Deploying SSH keys... <span class="loading"></span></p>';
            
            try {
                const response = await fetch('/api/execute', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ command: 'deploy_ssh_keys' })
                });
                
                const result = await response.json();
                
                if (result.status === 'success') {
                    const successCount = result.results.filter(r => r.success).length;
                    const totalCount = result.results.length;
                    
                    let details = result.results.map(r => 
                        `${r.ip} (${r.type}): ${r.success ? '✅ Success' : '❌ ' + r.message}`
                    ).join('<br>');
                    
                    sshStatus.innerHTML = `
                        <div class="${successCount > 0 ? 'success' : 'error'}-message">
                            SSH deployment complete: ${successCount}/${totalCount} successful
                            <br><br>
                            <details>
                                <summary>View Details</summary>
                                <div style="margin-top: 10px; font-size: 12px;">
                                    ${details}
                                </div>
                            </details>
                        </div>
                    `;
                } else {
                    sshStatus.innerHTML = `<p class="error-message">Failed: ${result.error}</p>`;
                }
            } catch (error) {
                sshStatus.innerHTML = `<p class="error-message">Error: ${error.message}</p>`;
            }
        }
        
        // Show message
        function showMessage(type, message) {
            const messageDiv = document.createElement('div');
            messageDiv.className = `${type}-message`;
            messageDiv.textContent = message;
            messageDiv.style.position = 'fixed';
            messageDiv.style.top = '20px';
            messageDiv.style.right = '20px';
            messageDiv.style.zIndex = '1000';
            messageDiv.style.maxWidth = '400px';
            
            document.body.appendChild(messageDiv);
            
            setTimeout(() => {
                messageDiv.remove();
            }, 5000);
        }
        
        // Initialize
        document.addEventListener('DOMContentLoaded', () => {
            loadServers();
            checkSSHStatus();
            
            // Auto-refresh every 60 seconds
            setInterval(loadServers, 60000);
        });
    </script>
</body>
</html>'''
    
    # Write the dashboard file
    with open(TEMPLATE_FILE, 'w') as f:
        f.write(dashboard_html)
    
    print(f"Dashboard generated at {TEMPLATE_FILE}")

def main():
    """Main entry point"""
    # Ensure directories exist
    os.makedirs(WWW_DIR, exist_ok=True)
    os.makedirs(DATA_DIR, exist_ok=True)
    
    # Generate dashboard
    generate_dashboard()
    
    return 0

if __name__ == '__main__':
    exit(main())