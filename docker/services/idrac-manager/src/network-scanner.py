#!/usr/bin/env python3
"""
Multi-Server Network Scanner
Discovers iDRAC, Proxmox, Linux, and Windows servers on the network
"""

import os
import json
import socket
import subprocess
import requests
import threading
import ipaddress
from datetime import datetime, timezone
import time
import paramiko
import ssl
import urllib3

# Disable SSL warnings for self-signed certificates
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# Configuration
DATA_DIR = '/app/www/data'
SERVERS_FILE = os.path.join(DATA_DIR, 'discovered_servers.json')
CUSTOM_RANGES_FILE = os.path.join(DATA_DIR, 'custom_ranges.json')
SCAN_TIMEOUT = 3
MAX_WORKERS = 50

# Ensure data directory exists
os.makedirs(DATA_DIR, exist_ok=True)

# Server type definitions with ports and identifiers
SERVER_TYPES = {
    'idrac': {
        'ports': [443, 80],
        'identifiers': ['idrac', 'dell', 'integrated dell remote access'],
        'default_credentials': {'username': 'root', 'password': 'calvin'},
        'description': 'Dell iDRAC Server Management'
    },
    'proxmox': {
        'ports': [8006],
        'identifiers': ['proxmox', 'pve', 'proxmox virtual environment'],
        'default_credentials': {'username': 'root', 'password': ''},
        'description': 'Proxmox Virtual Environment'
    },
    'linux': {
        'ports': [22],
        'identifiers': ['ssh', 'openssh'],
        'default_credentials': {'username': 'root', 'password': ''},
        'description': 'Linux/Unix Server (SSH)'
    },
    'windows': {
        'ports': [3389, 5985],  # RDP and WinRM
        'identifiers': ['rdp', 'terminal server', 'windows'],
        'default_credentials': {'username': 'Administrator', 'password': ''},
        'description': 'Windows Server'
    },
    'vnc': {
        'ports': [5900, 5901],
        'identifiers': ['rfb', 'vnc'],
        'default_credentials': {'username': '', 'password': ''},
        'description': 'VNC Remote Desktop'
    }
}

def log_message(message):
    """Log message with timestamp"""
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    print(f"[SCANNER] [{timestamp}] {message}")

def get_network_ranges():
    """Get network ranges to scan (default + custom)"""
    ranges = []
    
    # Get default network range
    try:
        result = subprocess.run(['ip', 'addr', 'show'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            for line in result.stdout.split('\n'):
                if 'inet ' in line and '127.0.0.1' not in line and 'docker0' not in line:
                    ip_info = line.strip().split()[1]
                    if not ip_info.split('/')[0].startswith('172.'):
                        ranges.append(ip_info)
                        log_message(f"Detected network range: {ip_info}")
    except Exception as e:
        log_message(f"Failed to detect network: {e}")
    
    # Add fallback if no ranges detected
    if not ranges:
        ranges.append("192.168.1.0/24")
        log_message("Using fallback network range: 192.168.1.0/24")
    
    # Load custom ranges
    if os.path.exists(CUSTOM_RANGES_FILE):
        try:
            with open(CUSTOM_RANGES_FILE, 'r') as f:
                custom_data = json.load(f)
                custom_ranges = custom_data.get('ranges', [])
                ranges.extend(custom_ranges)
                log_message(f"Added {len(custom_ranges)} custom ranges")
        except Exception as e:
            log_message(f"Failed to load custom ranges: {e}")
    
    return ranges

def scan_port(ip, port):
    """Scan a single IP and port"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(SCAN_TIMEOUT)
        result = sock.connect_ex((ip, port))
        sock.close()
        return result == 0
    except:
        return False

def check_ssh_server(ip, port=22):
    """Check if SSH server and try to get banner"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(SCAN_TIMEOUT)
        sock.connect((ip, port))
        
        # Try to get SSH banner
        banner = sock.recv(1024).decode('utf-8', errors='ignore')
        sock.close()
        
        if 'SSH' in banner:
            return True, banner.strip()
    except:
        pass
    
    return False, None

def check_rdp_server(ip, port=3389):
    """Check if RDP server is running"""
    # RDP uses a specific handshake, just check if port is open
    return scan_port(ip, port)

def check_vnc_server(ip, port=5900):
    """Check if VNC server is running"""
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(SCAN_TIMEOUT)
        sock.connect((ip, port))
        
        # VNC servers send RFB protocol version
        data = sock.recv(12)
        sock.close()
        
        if data.startswith(b'RFB'):
            return True
    except:
        pass
    
    return False

def check_https_service(ip, port, server_type):
    """Check HTTPS service and identify server type"""
    protocols = ['https'] if port == 443 or port == 8006 else ['http']
    
    for protocol in protocols:
        try:
            url = f"{protocol}://{ip}:{port}" if port not in [80, 443] else f"{protocol}://{ip}"
            
            # Custom SSL context for self-signed certificates
            session = requests.Session()
            if protocol == 'https':
                session.verify = False
            
            response = session.get(url, timeout=5, allow_redirects=False)
            
            content = response.text.lower()
            headers = str(response.headers).lower()
            
            # Check for server type identifiers
            identifiers = SERVER_TYPES[server_type]['identifiers']
            if any(identifier in content or identifier in headers for identifier in identifiers):
                
                # Extract title
                title = SERVER_TYPES[server_type]['description']
                if '<title>' in content:
                    start = content.find('<title>') + 7
                    end = content.find('</title>', start)
                    if end > start:
                        title = response.text[start:end].strip()
                
                return {
                    'type': server_type,
                    'url': url,
                    'protocol': protocol.upper(),
                    'title': title,
                    'port': port
                }
                
        except:
            continue
    
    return None

def identify_server(ip):
    """Identify what type of server is running on the IP"""
    server_info = {
        'ip': ip,
        'services': [],
        'type': 'unknown',
        'title': 'Unknown Server',
        'url': f"http://{ip}",
        'ports': {}
    }
    
    # Check each server type
    for server_type, config in SERVER_TYPES.items():
        for port in config['ports']:
            if scan_port(ip, port):
                log_message(f"Found open port {port} on {ip}")
                server_info['ports'][str(port)] = True
                
                # Special handling for different services
                if server_type == 'linux' and port == 22:
                    is_ssh, banner = check_ssh_server(ip, port)
                    if is_ssh:
                        server_info['services'].append({
                            'type': 'ssh',
                            'port': port,
                            'banner': banner
                        })
                        if server_info['type'] == 'unknown':
                            server_info['type'] = 'linux'
                            server_info['title'] = f"Linux/Unix Server ({ip})"
                            server_info['url'] = f"ssh://root@{ip}"
                
                elif server_type == 'windows' and port == 3389:
                    if check_rdp_server(ip, port):
                        server_info['services'].append({
                            'type': 'rdp',
                            'port': port
                        })
                        if server_info['type'] == 'unknown':
                            server_info['type'] = 'windows'
                            server_info['title'] = f"Windows Server ({ip})"
                            server_info['url'] = f"rdp://{ip}"
                
                elif server_type == 'vnc' and port in [5900, 5901]:
                    if check_vnc_server(ip, port):
                        server_info['services'].append({
                            'type': 'vnc',
                            'port': port
                        })
                        if server_info['type'] == 'unknown':
                            server_info['type'] = 'vnc'
                            server_info['title'] = f"VNC Server ({ip})"
                            server_info['url'] = f"vnc://{ip}:{port}"
                
                elif server_type in ['idrac', 'proxmox']:
                    # Check HTTPS/HTTP services
                    service_info = check_https_service(ip, port, server_type)
                    if service_info:
                        server_info['services'].append(service_info)
                        server_info['type'] = service_info['type']
                        server_info['title'] = service_info['title']
                        server_info['url'] = service_info['url']
                        break  # Found primary service
    
    # If we found any services, return the server info
    if server_info['services'] or server_info['ports']:
        return server_info
    
    return None

def scan_ip_range(ip_range):
    """Scan an IP range for all server types"""
    discovered = []
    
    try:
        network = ipaddress.ip_network(ip_range, strict=False)
        for ip in network.hosts():
            ip_str = str(ip)
            server_info = identify_server(ip_str)
            
            if server_info:
                discovered.append(server_info)
                log_message(f"Identified {server_info['type']}: {server_info['title']} at {server_info['url']}")
    
    except Exception as e:
        log_message(f"Error scanning range {ip_range}: {e}")
    
    return discovered

def load_existing_servers():
    """Load existing server list"""
    if os.path.exists(SERVERS_FILE):
        try:
            with open(SERVERS_FILE, 'r') as f:
                return json.load(f)
        except Exception as e:
            log_message(f"Error loading servers file: {e}")
    
    # Return default structure
    return {
        'servers': [],
        'last_scan': '',
        'scan_count': 0,
        'server_types': list(SERVER_TYPES.keys())
    }

def save_servers(data):
    """Save server list to file"""
    os.makedirs(DATA_DIR, exist_ok=True)
    try:
        with open(SERVERS_FILE, 'w') as f:
            json.dump(data, f, indent=2)
        log_message(f"Saved {len(data.get('servers', []))} servers to {SERVERS_FILE}")
        
        # Also maintain backward compatibility with old file
        idrac_only = {
            'servers': [s for s in data['servers'] if s.get('type') == 'idrac'],
            'last_scan': data['last_scan'],
            'scan_count': data['scan_count']
        }
        with open(os.path.join(DATA_DIR, 'discovered_idracs.json'), 'w') as f:
            json.dump(idrac_only, f, indent=2)
    except Exception as e:
        log_message(f"Error saving servers: {e}")

def update_server_status(servers_data, discovered_servers):
    """Update server status based on scan results"""
    current_time = datetime.now(timezone.utc).isoformat()
    
    # Create lookup by IP
    discovered_by_ip = {server['ip']: server for server in discovered_servers}
    existing_by_ip = {server.get('ip', server['url'].split('//')[-1].split(':')[0]): server 
                      for server in servers_data['servers']}
    
    # Update existing servers
    for ip, server in existing_by_ip.items():
        if ip in discovered_by_ip:
            # Update with new info
            discovered = discovered_by_ip[ip]
            server['status'] = 'online'
            server['last_seen'] = current_time
            server['services'] = discovered.get('services', [])
            server['ports'] = discovered.get('ports', {})
            server['type'] = discovered.get('type', server.get('type', 'unknown'))
        else:
            server['status'] = 'offline'
    
    # Add new servers
    for ip, discovered in discovered_by_ip.items():
        if ip not in existing_by_ip:
            new_server = {
                'ip': ip,
                'url': discovered['url'],
                'type': discovered['type'],
                'title': discovered['title'],
                'services': discovered.get('services', []),
                'ports': discovered.get('ports', {}),
                'first_discovered': current_time,
                'last_seen': current_time,
                'status': 'online',
                'credentials': SERVER_TYPES.get(discovered['type'], {}).get('default_credentials', {})
            }
            servers_data['servers'].append(new_server)
    
    # Update scan metadata
    servers_data['last_scan'] = current_time
    servers_data['scan_count'] = servers_data.get('scan_count', 0) + 1
    servers_data['server_types'] = list(SERVER_TYPES.keys())
    
    return servers_data

def perform_scan(custom_ranges=None):
    """Perform complete network scan"""
    log_message("Starting multi-server network scan...")
    
    # Get network ranges to scan
    if custom_ranges:
        ranges = custom_ranges
    else:
        ranges = get_network_ranges()
    
    log_message(f"Scanning {len(ranges)} network ranges")
    
    # Thread pool for scanning
    discovered_servers = []
    threads = []
    lock = threading.Lock()
    
    def scan_range_thread(ip_range):
        results = scan_ip_range(ip_range)
        with lock:
            discovered_servers.extend(results)
    
    # Create threads for each range
    for ip_range in ranges:
        thread = threading.Thread(target=scan_range_thread, args=(ip_range,))
        threads.append(thread)
        thread.start()
        
        # Limit concurrent threads
        if len(threads) >= MAX_WORKERS:
            for t in threads:
                t.join()
            threads = []
    
    # Wait for remaining threads
    for thread in threads:
        thread.join()
    
    log_message(f"Scan complete. Found {len(discovered_servers)} servers")
    
    # Count by type
    type_counts = {}
    for server in discovered_servers:
        server_type = server.get('type', 'unknown')
        type_counts[server_type] = type_counts.get(server_type, 0) + 1
    
    for server_type, count in type_counts.items():
        log_message(f"  - {server_type}: {count} servers")
    
    # Update server database
    servers_data = load_existing_servers()
    updated_data = update_server_status(servers_data, discovered_servers)
    save_servers(updated_data)
    
    # Log results
    online_count = len([s for s in updated_data['servers'] if s['status'] == 'online'])
    total_count = len(updated_data['servers'])
    log_message(f"Database updated: {online_count} online, {total_count} total servers")

def main():
    """Main entry point"""
    log_message("Multi-Server Network Scanner starting...")
    
    # Ensure data directory exists
    os.makedirs(DATA_DIR, exist_ok=True)
    
    # Perform initial scan
    try:
        perform_scan()
    except Exception as e:
        log_message(f"Initial scan failed: {e}")
        import traceback
        traceback.print_exc()
    
    # Continue scanning every 5 minutes
    log_message("Starting continuous scanning (every 5 minutes)...")
    while True:
        time.sleep(300)  # 5 minutes
        try:
            log_message("Starting scheduled network scan...")
            perform_scan()
        except Exception as e:
            log_message(f"Scheduled scan failed: {e}")
            import traceback
            traceback.print_exc()
    
    return 0

if __name__ == '__main__':
    exit(main())