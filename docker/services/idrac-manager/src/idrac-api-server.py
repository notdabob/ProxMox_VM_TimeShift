#!/usr/bin/env python3
"""
iDRAC Local API Server
Provides browser-based command execution without file downloads
"""

import os
import sys
import json
import subprocess
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
import time

class iDRACCommandHandler(BaseHTTPRequestHandler):
    def do_OPTIONS(self):
        """Handle CORS preflight requests"""
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def do_GET(self):
        """Handle GET requests for status and info"""
        if self.path == '/status':
            self.send_json_response({'status': 'running', 'server': 'iDRAC API'})
        elif self.path == '/commands':
            self.send_json_response({
                'available_commands': [
                    'launch_virtual_console',
                    'generate_ssh_key', 
                    'deploy_ssh_keys',
                    'rescan_network'
                ]
            })
        else:
            self.send_error(404)

    def do_POST(self):
        """Handle POST requests for command execution"""
        try:
            content_length = int(self.headers['Content-Length'])
            post_data = self.rfile.read(content_length)
            data = json.loads(post_data.decode('utf-8'))
            
            command = data.get('command')
            params = data.get('params', {})
            
            if self.path == '/' or self.path == '/execute':
                if command == 'launch_virtual_console':
                    self.execute_virtual_console(params.get('ip'))
                elif command == 'generate_ssh_key':
                    self.execute_ssh_key_generation(params.get('email'))
                elif command == 'deploy_ssh_keys':
                    self.execute_ssh_key_deployment()
                elif command == 'rescan_network':
                    self.execute_network_rescan()
                else:
                    self.send_error(400, f"Unknown command: {command}")
            else:
                self.send_error(404, "Endpoint not found")
                
        except Exception as e:
            self.send_error(500, str(e))

    def execute_virtual_console(self, ip):
        """Execute Virtual Console launcher"""
        if not ip:
            self.send_error(400, "IP address required")
            return
            
        script_path = os.path.join(os.path.dirname(__file__), 'launch-virtual-console.sh')
        
        try:
            # Execute in background to avoid blocking browser
            def run_command():
                subprocess.run([script_path, ip], check=True)
            
            thread = threading.Thread(target=run_command)
            thread.daemon = True
            thread.start()
            
            self.send_json_response({
                'status': 'success',
                'message': f'Launching Virtual Console for {ip}',
                'action': 'virtual_console_started'
            })
            
        except Exception as e:
            self.send_error(500, f"Failed to launch Virtual Console: {str(e)}")

    def execute_ssh_key_generation(self, email):
        """Execute SSH key generation"""
        if not email:
            self.send_error(400, "Email address required")
            return
            
        try:
            # Generate SSH key directly
            ssh_dir = os.path.expanduser('~/.ssh')
            key_path = os.path.join(ssh_dir, 'idrac_rsa')
            
            # Create .ssh directory if it doesn't exist
            os.makedirs(ssh_dir, exist_ok=True)
            
            # Generate SSH key
            cmd = [
                'ssh-keygen', '-t', 'rsa', '-b', '4096', 
                '-C', email, '-f', key_path, '-N', ''
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True)
            
            if result.returncode == 0:
                # Read public key content
                with open(f"{key_path}.pub", 'r') as f:
                    public_key = f.read().strip()
                
                self.send_json_response({
                    'status': 'success',
                    'message': f'SSH key generated successfully for {email}',
                    'key_path': key_path,
                    'public_key': public_key
                })
            else:
                self.send_error(500, f"SSH key generation failed: {result.stderr}")
                
        except Exception as e:
            self.send_error(500, f"Failed to generate SSH key: {str(e)}")

    def execute_ssh_key_deployment(self):
        """Execute SSH key deployment to all servers"""
        try:
            # Read server list from JSON
            project_dir = os.path.dirname(os.path.dirname(__file__))
            servers_file = os.path.join(project_dir, 'output/www/data/discovered_idracs.json')
            
            if not os.path.exists(servers_file):
                self.send_error(400, "No discovered servers found")
                return
                
            with open(servers_file, 'r') as f:
                data = json.load(f)
            
            online_servers = [s for s in data.get('servers', []) if s.get('status') == 'online']
            
            if not online_servers:
                self.send_error(400, "No online servers found")
                return
            
            # Deploy keys to each server
            results = []
            key_path = os.path.expanduser('~/.ssh/idrac_rsa.pub')
            
            for server in online_servers:
                ip = server['url'].replace('https://', '').replace('http://', '')
                try:
                    # Use ssh-copy-id to deploy key
                    cmd = ['ssh-copy-id', '-i', key_path, f'root@{ip}']
                    result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
                    
                    results.append({
                        'ip': ip,
                        'success': result.returncode == 0,
                        'message': result.stdout if result.returncode == 0 else result.stderr
                    })
                except subprocess.TimeoutExpired:
                    results.append({
                        'ip': ip,
                        'success': False,
                        'message': 'Connection timeout'
                    })
                except Exception as e:
                    results.append({
                        'ip': ip,
                        'success': False,
                        'message': str(e)
                    })
            
            successful = len([r for r in results if r['success']])
            
            self.send_json_response({
                'status': 'success',
                'message': f'SSH key deployment complete: {successful}/{len(results)} servers',
                'results': results
            })
            
        except Exception as e:
            self.send_error(500, f"Failed to deploy SSH keys: {str(e)}")

    def execute_network_rescan(self):
        """Execute network rescan"""
        try:
            script_path = os.path.join(os.path.dirname(__file__), 'launch-idrac.sh')
            
            # Run with --test flag to only scan and generate dashboard
            def run_scan():
                subprocess.run([script_path, '--test'], check=True)
            
            thread = threading.Thread(target=run_scan)
            thread.daemon = True
            thread.start()
            
            self.send_json_response({
                'status': 'success',
                'message': 'Network rescan started',
                'action': 'refresh_in_5_seconds'
            })
            
        except Exception as e:
            self.send_error(500, f"Failed to start network rescan: {str(e)}")

    def send_json_response(self, data):
        """Send JSON response with CORS headers"""
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(json.dumps(data).encode('utf-8'))

def run_server(port=8765):
    """Run the iDRAC API server"""
    server_address = ('localhost', port)
    httpd = HTTPServer(server_address, iDRACCommandHandler)
    
    print(f"🚀 iDRAC API Server running on http://localhost:{port}")
    print(f"📊 Dashboard can now execute commands directly")
    print(f"🛑 Press Ctrl+C to stop")
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print(f"\n🛑 iDRAC API Server stopped")

if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    run_server(port)