#!/usr/bin/env python3
"""
Multi-Server Container API
Provides container-based management for iDRAC, Proxmox, Linux, and Windows servers
"""

import os
import json
import subprocess
import threading
import time
import xml.etree.ElementTree as ET
from datetime import datetime
from flask import Flask, request, jsonify, send_from_directory, send_file, Response
import paramiko
import uuid
import base64

app = Flask(__name__)

# Configuration
DATA_DIR = '/app/www/data'
DOWNLOADS_DIR = '/app/www/downloads'
LOGS_DIR = '/app/logs'

def log_message(message):
    """Log message with timestamp"""
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    print(f"[{timestamp}] {message}")

@app.route('/health')
def health_check():
    """Health check endpoint"""
    return jsonify({'status': 'healthy', 'service': 'Multi-Server API'})

@app.route('/status')
def api_status():
    """API status endpoint"""
    return jsonify({
        'status': 'running',
        'server': 'Multi-Server Container API',
        'version': '4.0.0',
        'capabilities': [
            'ssh_key_generation',
            'ssh_key_deployment', 
            'virtual_console_access',
            'network_scanning',
            'server_management',
            'rdm_export',
            'custom_network_ranges',
            'multi_server_types'
        ]
    })

@app.route('/', methods=['POST'])
@app.route('/execute', methods=['POST'])
def execute_command():
    """Execute server management commands"""
    try:
        data = request.get_json()
        command = data.get('command')
        params = data.get('params', {})
        
        log_message(f"Executing command: {command} with params: {params}")
        
        if command == 'generate_ssh_key':
            return generate_ssh_key(params.get('email'))
        elif command == 'deploy_ssh_keys':
            return deploy_ssh_keys()
        elif command == 'launch_virtual_console':
            return launch_virtual_console(params.get('ip'))
        elif command == 'rescan_network':
            return rescan_network()
        elif command == 'remove_server':
            return remove_server(params.get('url'))
        elif command == 'scan_custom_range':
            return scan_custom_range(params.get('ranges'))
        elif command == 'export_rdm':
            return export_rdm(params.get('format', 'json'))
        else:
            return jsonify({'error': f'Unknown command: {command}'}), 400
            
    except Exception as e:
        log_message(f"Error executing command: {str(e)}")
        return jsonify({'error': str(e)}), 500

def generate_ssh_key(email):
    """Generate SSH key for server access"""
    if not email:
        return jsonify({'error': 'Email address required'}), 400
    
    try:
        # Generate SSH key
        key_path = '/root/.ssh/server_rsa'
        cmd = [
            'ssh-keygen', '-t', 'rsa', '-b', '4096',
            '-C', email, '-f', key_path, '-N', ''
        ]
        
        # Remove existing key if present
        for ext in ['', '.pub']:
            if os.path.exists(f"{key_path}{ext}"):
                os.remove(f"{key_path}{ext}")
        
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            # Read public key
            with open(f"{key_path}.pub", 'r') as f:
                public_key = f.read().strip()
            
            # Update admin config
            config_file = os.path.join(DATA_DIR, 'admin_config.json')
            config = {
                'admin_email': email,
                'ssh_key_generated': True,
                'ssh_key_path': key_path,
                'public_key': public_key,
                'last_updated': datetime.now().isoformat()
            }
            
            with open(config_file, 'w') as f:
                json.dump(config, f, indent=2)
            
            log_message(f"SSH key generated for {email}")
            
            return jsonify({
                'status': 'success',
                'message': f'SSH key generated for {email}',
                'key_path': key_path,
                'public_key': public_key
            })
        else:
            return jsonify({'error': f'SSH key generation failed: {result.stderr}'}), 500
            
    except Exception as e:
        return jsonify({'error': f'Failed to generate SSH key: {str(e)}'}), 500

def deploy_ssh_keys():
    """Deploy SSH keys to all discovered servers with SSH support"""
    try:
        # Read server list
        servers_file = os.path.join(DATA_DIR, 'discovered_servers.json')
        if not os.path.exists(servers_file):
            # Try legacy file
            servers_file = os.path.join(DATA_DIR, 'discovered_idracs.json')
            if not os.path.exists(servers_file):
                return jsonify({'error': 'No discovered servers found'}), 400
        
        with open(servers_file, 'r') as f:
            data = json.load(f)
        
        # Filter servers with SSH capability
        ssh_servers = []
        for server in data.get('servers', []):
            if server.get('status') == 'online':
                # Check if server has SSH port open
                if '22' in server.get('ports', {}) or server.get('type') in ['idrac', 'linux']:
                    ssh_servers.append(server)
        
        if not ssh_servers:
            return jsonify({'error': 'No online servers with SSH found'}), 400
        
        # Check if SSH key exists
        key_path = '/root/.ssh/server_rsa'
        pub_key_path = f"{key_path}.pub"
        
        if not os.path.exists(pub_key_path):
            return jsonify({'error': 'SSH public key not found. Generate key first.'}), 400
        
        results = []
        
        for server in ssh_servers:
            ip = server.get('ip', server['url'].replace('https://', '').replace('http://', '').split('/')[0])
            
            try:
                # Use ssh-copy-id to deploy key
                cmd = ['ssh-copy-id', '-i', pub_key_path, '-o', 'StrictHostKeyChecking=no', 
                       '-o', 'ConnectTimeout=10', f'root@{ip}']
                
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
                
                success = result.returncode == 0
                results.append({
                    'ip': ip,
                    'type': server.get('type', 'unknown'),
                    'success': success,
                    'message': result.stdout if success else result.stderr
                })
                
                # Update SSH config
                if success:
                    update_ssh_config(ip, server.get('type', 'server'))
                
            except subprocess.TimeoutExpired:
                results.append({
                    'ip': ip,
                    'type': server.get('type', 'unknown'),
                    'success': False,
                    'message': 'Connection timeout'
                })
            except Exception as e:
                results.append({
                    'ip': ip,
                    'type': server.get('type', 'unknown'),
                    'success': False,
                    'message': str(e)
                })
        
        successful = len([r for r in results if r['success']])
        
        log_message(f"SSH deployment complete: {successful}/{len(results)} servers")
        
        return jsonify({
            'status': 'success',
            'message': f'SSH deployment complete: {successful}/{len(results)} servers',
            'results': results
        })
        
    except Exception as e:
        return jsonify({'error': f'Failed to deploy SSH keys: {str(e)}'}), 500

def update_ssh_config(ip, server_type='server'):
    """Update SSH config with server entry"""
    ssh_config_path = '/root/.ssh/config'
    alias = f"{server_type}-{ip.replace('.', '-')}"
    
    # Check if entry already exists
    if os.path.exists(ssh_config_path):
        with open(ssh_config_path, 'r') as f:
            if f"Host {alias}" in f.read():
                return  # Already exists
    
    # Add new entry
    config_entry = f"""
Host {alias}
    HostName {ip}
    User root
    Port 22
    IdentityFile /root/.ssh/server_rsa
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
"""
    
    with open(ssh_config_path, 'a') as f:
        f.write(config_entry)

def launch_virtual_console(ip):
    """Launch Virtual Console for server"""
    if not ip:
        return jsonify({'error': 'IP address required'}), 400
    
    try:
        # Check if server is accessible
        cmd = ['ping', '-c', '1', '-W', '3', ip]
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            # Determine server type from database
            servers_file = os.path.join(DATA_DIR, 'discovered_servers.json')
            server_type = 'unknown'
            server_info = None
            
            if os.path.exists(servers_file):
                with open(servers_file, 'r') as f:
                    data = json.load(f)
                    for server in data.get('servers', []):
                        if server.get('ip') == ip:
                            server_type = server.get('type', 'unknown')
                            server_info = server
                            break
            
            # Generate appropriate connection info based on server type
            if server_type == 'idrac':
                console_url = f"https://{ip}/console"
                instructions = "Use Dell iDRAC Virtual Console"
            elif server_type == 'proxmox':
                console_url = f"https://{ip}:8006"
                instructions = "Access Proxmox VE web interface"
            elif server_type == 'windows':
                console_url = f"rdp://{ip}"
                instructions = "Use Remote Desktop Connection"
            elif server_type == 'linux':
                console_url = f"ssh://root@{ip}"
                instructions = "Use SSH terminal"
            elif server_type == 'vnc':
                port = server_info.get('ports', {}).get('5900', '5900')
                console_url = f"vnc://{ip}:{port}"
                instructions = "Use VNC viewer"
            else:
                console_url = f"http://{ip}"
                instructions = "Access via web browser"
            
            # Generate download script for users
            script_content = f"""#!/bin/bash
# Connection Launcher for {ip} ({server_type})
# Run this on your local machine

echo "Connecting to {server_type} server at {ip}..."
echo "Connection URL: {console_url}"

# Try to open appropriate application
"""
            
            if server_type == 'windows':
                script_content += f"""
if command -v mstsc >/dev/null; then
    mstsc /v:{ip}  # Windows
elif command -v rdesktop >/dev/null; then
    rdesktop {ip}  # Linux with rdesktop
elif command -v xfreerdp >/dev/null; then
    xfreerdp /v:{ip}  # Linux with xfreerdp
else
    echo "Please connect manually using Remote Desktop to: {ip}"
fi
"""
            elif server_type == 'linux':
                script_content += f"""
if command -v ssh >/dev/null; then
    ssh root@{ip}
else
    echo "SSH client not found. Please install SSH."
fi
"""
            else:
                script_content += f"""
if command -v open >/dev/null; then
    open "{console_url}"  # macOS
elif command -v xdg-open >/dev/null; then
    xdg-open "{console_url}"  # Linux
elif command -v start >/dev/null; then
    start "{console_url}"  # Windows
else
    echo "Please open this URL manually: {console_url}"
fi
"""
            
            script_content += f"""
echo ""
echo "Connection details:"
echo "Type: {server_type}"
echo "Instructions: {instructions}"
"""
            
            # Save script to downloads
            script_file = os.path.join(DOWNLOADS_DIR, f"connect-{server_type}-{ip}.sh")
            with open(script_file, 'w') as f:
                f.write(script_content)
            os.chmod(script_file, 0o755)
            
            log_message(f"Connection prepared for {server_type} server at {ip}")
            
            return jsonify({
                'status': 'success',
                'message': f'Connection prepared for {server_type} server at {ip}',
                'console_url': console_url,
                'download_script': f"connect-{server_type}-{ip}.sh",
                'instructions': instructions,
                'server_type': server_type
            })
        else:
            return jsonify({'error': f'Server {ip} is not accessible'}), 400
            
    except Exception as e:
        return jsonify({'error': f'Failed to prepare connection: {str(e)}'}), 500

def rescan_network():
    """Trigger network rescan"""
    try:
        # Trigger the network scanner
        subprocess.Popen(['python3', '/app/src/network-scanner.py'])
        
        return jsonify({
            'status': 'success',
            'message': 'Network rescan started',
            'action': 'refresh_in_30_seconds'
        })
        
    except Exception as e:
        return jsonify({'error': f'Failed to start network rescan: {str(e)}'}), 500

def scan_custom_range(ranges):
    """Scan custom network ranges"""
    try:
        if not ranges or not isinstance(ranges, list):
            return jsonify({'error': 'Invalid ranges format. Expected list of CIDR ranges.'}), 400
        
        # Save custom ranges
        custom_ranges_file = os.path.join(DATA_DIR, 'custom_ranges.json')
        with open(custom_ranges_file, 'w') as f:
            json.dump({'ranges': ranges, 'last_updated': datetime.now().isoformat()}, f, indent=2)
        
        # Trigger scan with custom ranges
        cmd = ['python3', '/app/src/network-scanner.py']
        subprocess.Popen(cmd)
        
        log_message(f"Custom network scan started for ranges: {ranges}")
        
        return jsonify({
            'status': 'success',
            'message': f'Custom scan started for {len(ranges)} ranges',
            'ranges': ranges,
            'action': 'refresh_in_30_seconds'
        })
        
    except Exception as e:
        return jsonify({'error': f'Failed to start custom scan: {str(e)}'}), 500

def remove_server(url):
    """Remove server from discovered list"""
    try:
        servers_file = os.path.join(DATA_DIR, 'discovered_servers.json')
        
        if not os.path.exists(servers_file):
            # Try legacy file
            servers_file = os.path.join(DATA_DIR, 'discovered_idracs.json')
            if not os.path.exists(servers_file):
                return jsonify({'error': 'No servers file found'}), 400
        
        with open(servers_file, 'r') as f:
            data = json.load(f)
        
        # Remove server from list
        data['servers'] = [s for s in data['servers'] if s['url'] != url]
        
        with open(servers_file, 'w') as f:
            json.dump(data, f, indent=2)
        
        log_message(f"Removed server: {url}")
        
        return jsonify({
            'status': 'success',
            'message': f'Server removed: {url}'
        })
        
    except Exception as e:
        return jsonify({'error': f'Failed to remove server: {str(e)}'}), 500

def export_rdm(format='json'):
    """Export servers to Remote Desktop Manager format"""
    try:
        # Read server list
        servers_file = os.path.join(DATA_DIR, 'discovered_servers.json')
        if not os.path.exists(servers_file):
            servers_file = os.path.join(DATA_DIR, 'discovered_idracs.json')
            if not os.path.exists(servers_file):
                return jsonify({'error': 'No discovered servers found'}), 400
        
        with open(servers_file, 'r') as f:
            data = json.load(f)
        
        servers = data.get('servers', [])
        if not servers:
            return jsonify({'error': 'No servers to export'}), 400
        
        if format == 'json':
            return export_rdm_json(servers)
        elif format == 'rdm':
            return export_rdm_xml(servers)
        else:
            return jsonify({'error': f'Unsupported format: {format}'}), 400
            
    except Exception as e:
        return jsonify({'error': f'Failed to export: {str(e)}'}), 500

def export_rdm_json(servers):
    """Export servers as RDM JSON format"""
    rdm_entries = []
    
    for server in servers:
        ip = server.get('ip', server['url'].replace('https://', '').replace('http://', '').split('/')[0])
        server_type = server.get('type', 'unknown')
        
        # Base entry
        entry = {
            'ID': str(uuid.uuid4()),
            'Name': server.get('title', f'{server_type} - {ip}'),
            'Group': 'Homelab Servers',
            'Host': ip,
            'Description': f"Auto-discovered {server_type} server",
            'Tags': ['auto-discovered', server_type, 'homelab']
        }
        
        # Type-specific configurations
        if server_type == 'idrac':
            entry.update({
                'ConnectionType': 'WebBrowser',
                'ConnectionSubType': 'GoogleChrome',
                'Url': server.get('url', f'https://{ip}'),
                'Username': 'root',
                'Domain': '',
                'UseDefaultCredentials': False
            })
        elif server_type == 'proxmox':
            entry.update({
                'ConnectionType': 'WebBrowser',
                'ConnectionSubType': 'GoogleChrome',
                'Url': f'https://{ip}:8006',
                'Username': 'root@pam',
                'Domain': '',
                'UseDefaultCredentials': False
            })
        elif server_type == 'linux':
            entry.update({
                'ConnectionType': 'SSH',
                'ConnectionSubType': 'SSHShell',
                'Port': 22,
                'Username': 'root',
                'UsePrivateKey': True,
                'PrivateKeyPath': '/root/.ssh/server_rsa'
            })
        elif server_type == 'windows':
            entry.update({
                'ConnectionType': 'RDPConfigured',
                'Port': 3389,
                'Username': 'Administrator',
                'Domain': '',
                'UseDefaultCredentials': False,
                'ScreenColor': '32',
                'ScreenSize': 'FullScreen'
            })
        elif server_type == 'vnc':
            port = list(server.get('ports', {}).keys())[0] if server.get('ports') else '5900'
            entry.update({
                'ConnectionType': 'VNC',
                'Port': int(port),
                'Username': '',
                'VNCEncoding': 'Auto',
                'ColorDepth': 'Depth32Bit'
            })
        
        rdm_entries.append(entry)
    
    # Create RDM JSON structure
    rdm_data = {
        'Connections': rdm_entries,
        'ExportVersion': '2.0',
        'ExportDate': datetime.now().isoformat(),
        'Source': 'Homelab Multi-Server Scanner'
    }
    
    # Save to file
    filename = f"rdm_export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    filepath = os.path.join(DOWNLOADS_DIR, filename)
    
    with open(filepath, 'w') as f:
        json.dump(rdm_data, f, indent=2)
    
    log_message(f"Exported {len(servers)} servers to RDM JSON format")
    
    return send_file(filepath, as_attachment=True, download_name=filename, mimetype='application/json')

def export_rdm_xml(servers):
    """Export servers as RDM XML format"""
    # Create root element
    root = ET.Element('RDM')
    root.set('Version', '2.0')
    
    # Create connections group
    connections = ET.SubElement(root, 'Connections')
    group = ET.SubElement(connections, 'Group')
    group.set('Name', 'Homelab Servers')
    
    for server in servers:
        ip = server.get('ip', server['url'].replace('https://', '').replace('http://', '').split('/')[0])
        server_type = server.get('type', 'unknown')
        
        # Create connection element
        conn = ET.SubElement(group, 'Connection')
        conn.set('ID', str(uuid.uuid4()))
        conn.set('Name', server.get('title', f'{server_type} - {ip}'))
        
        # Add common properties
        ET.SubElement(conn, 'Host').text = ip
        ET.SubElement(conn, 'Description').text = f"Auto-discovered {server_type} server"
        
        # Type-specific configurations
        if server_type == 'idrac':
            conn.set('Type', 'WebBrowser')
            ET.SubElement(conn, 'Url').text = server.get('url', f'https://{ip}')
            ET.SubElement(conn, 'Username').text = 'root'
        elif server_type == 'proxmox':
            conn.set('Type', 'WebBrowser')
            ET.SubElement(conn, 'Url').text = f'https://{ip}:8006'
            ET.SubElement(conn, 'Username').text = 'root@pam'
        elif server_type == 'linux':
            conn.set('Type', 'SSHShell')
            ET.SubElement(conn, 'Port').text = '22'
            ET.SubElement(conn, 'Username').text = 'root'
            ET.SubElement(conn, 'UsePrivateKey').text = 'true'
        elif server_type == 'windows':
            conn.set('Type', 'RDPConfigured')
            ET.SubElement(conn, 'Port').text = '3389'
            ET.SubElement(conn, 'Username').text = 'Administrator'
            ET.SubElement(conn, 'ScreenColor').text = '32'
        elif server_type == 'vnc':
            conn.set('Type', 'VNC')
            port = list(server.get('ports', {}).keys())[0] if server.get('ports') else '5900'
            ET.SubElement(conn, 'Port').text = port
    
    # Convert to string
    xml_str = ET.tostring(root, encoding='unicode', method='xml')
    
    # Pretty print
    import xml.dom.minidom
    dom = xml.dom.minidom.parseString(xml_str)
    pretty_xml = dom.toprettyxml(indent='  ')
    
    # Save to file
    filename = f"rdm_export_{datetime.now().strftime('%Y%m%d_%H%M%S')}.rdm"
    filepath = os.path.join(DOWNLOADS_DIR, filename)
    
    with open(filepath, 'w') as f:
        f.write(pretty_xml)
    
    log_message(f"Exported {len(servers)} servers to RDM XML format")
    
    return send_file(filepath, as_attachment=True, download_name=filename, mimetype='application/xml')

@app.route('/api/export/rdm/<format>')
def api_export_rdm(format):
    """API endpoint for RDM export"""
    return export_rdm(format)

@app.route('/api/scan/custom', methods=['POST'])
def api_scan_custom():
    """API endpoint for custom network scanning"""
    data = request.get_json()
    ranges = data.get('ranges', [])
    return scan_custom_range(ranges)

if __name__ == '__main__':
    log_message("Starting Multi-Server Container API...")
    
    # Ensure directories exist
    os.makedirs(DATA_DIR, exist_ok=True)
    os.makedirs(DOWNLOADS_DIR, exist_ok=True)
    os.makedirs(LOGS_DIR, exist_ok=True)
    
    # Run Flask app
    app.run(host='0.0.0.0', port=8765, debug=False)