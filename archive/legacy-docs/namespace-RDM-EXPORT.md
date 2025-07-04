# Remote Desktop Manager Export Feature

The Homelab Server Management Dashboard now includes full support for exporting discovered servers to Remote Desktop Manager (RDM).

## Features

### Export Formats

- **JSON Format** - Modern RDM JSON format for easy import
- **XML/RDM Format** - Classic RDM XML format for compatibility

### Automatic Configuration

Each server type is automatically configured with appropriate connection settings:

#### iDRAC Servers
- Connection Type: Web Browser (Chrome)
- URL: HTTPS connection to iDRAC interface
- Default Username: root

#### Proxmox VE Servers
- Connection Type: Web Browser (Chrome)  
- URL: HTTPS connection on port 8006
- Default Username: root@pam

#### Linux/SSH Servers
- Connection Type: SSH Shell
- Port: 22
- Default Username: root
- SSH Key support included

#### Windows Servers
- Connection Type: RDP
- Port: 3389
- Default Username: Administrator
- Full screen mode enabled

#### VNC Servers
- Connection Type: VNC
- Auto-detected port (5900/5901)
- Automatic encoding settings

## Usage

### From the Dashboard

1. Click the "Export to RDM (JSON)" or "Export to RDM (XML)" button
2. The file will download automatically
3. Import the file into Remote Desktop Manager

### Via API

```bash
# Export as JSON
curl -O http://your-proxmox:8080/api/export/rdm/json

# Export as XML/RDM
curl -O http://your-proxmox:8080/api/export/rdm/rdm
```

## Import Instructions

### For JSON Format

1. Open Remote Desktop Manager
2. File → Import → Import from JSON
3. Select the downloaded file
4. Choose import options
5. Click Import

### For XML/RDM Format

1. Open Remote Desktop Manager
2. File → Import → Import from RDM
3. Select the downloaded file
4. Review the connections
5. Click Import

## Organization

All imported servers will be organized under a "Homelab Servers" group for easy management.

## Custom Network Scanning

To discover servers on additional networks:

1. Enter network ranges in CIDR format (e.g., 192.168.1.0/24, 10.0.0.0/24)
2. Click "Scan Custom Ranges"
3. Wait for discovery to complete
4. Export the updated server list

## Benefits

- **One-click import** of all discovered servers
- **Pre-configured** connection settings
- **Organized structure** for easy navigation
- **Credential templates** ready for your passwords
- **Multi-platform support** for diverse homelab environments