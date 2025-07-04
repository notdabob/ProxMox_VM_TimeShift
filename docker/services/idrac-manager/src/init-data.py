#!/usr/bin/env python3
"""
Initialize data files for the multi-server scanner
"""

import os
import json
from datetime import datetime, timezone

DATA_DIR = '/app/www/data'

def create_initial_data():
    """Create initial data files if they don't exist"""
    os.makedirs(DATA_DIR, exist_ok=True)
    
    # Create initial discovered_servers.json
    servers_file = os.path.join(DATA_DIR, 'discovered_servers.json')
    if not os.path.exists(servers_file):
        initial_data = {
            'servers': [],
            'last_scan': '',
            'scan_count': 0,
            'server_types': ['idrac', 'proxmox', 'linux', 'windows', 'vnc']
        }
        with open(servers_file, 'w') as f:
            json.dump(initial_data, f, indent=2)
        print(f"Created initial {servers_file}")
    
    # Also create legacy file for compatibility
    legacy_file = os.path.join(DATA_DIR, 'discovered_idracs.json')
    if not os.path.exists(legacy_file):
        legacy_data = {
            'servers': [],
            'last_scan': '',
            'scan_count': 0
        }
        with open(legacy_file, 'w') as f:
            json.dump(legacy_data, f, indent=2)
        print(f"Created legacy {legacy_file}")

if __name__ == '__main__':
    create_initial_data()