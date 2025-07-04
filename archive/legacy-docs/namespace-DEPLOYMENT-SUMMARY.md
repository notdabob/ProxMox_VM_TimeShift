# 🚀 Proxmox iDRAC Container - One-Command Deployment

## What This Solves

✅ **Eliminates macOS quarantine issues** - No more blocked .command files  
✅ **Centralized management** - Access from any device on network  
✅ **No time-shifting needed** - Works with current SSL certificates  
✅ **Professional solution** - Container-based, enterprise-ready  

## Quick Deployment

### 1. Clone from GitHub
```bash
ssh root@your-proxmox-host
git clone https://github.com/notdabob/namespace-timeshift-browser-container.git
cd namespace-timeshift-browser-container
```

### 2. Deploy Container
```bash
chmod +x deploy-proxmox.sh
./deploy-proxmox.sh deploy
```

### 3. Access Dashboard
```
http://YOUR-PROXMOX-IP:8080
```

## What You Get

🌐 **Web Dashboard**
- Auto-discovers all iDRAC servers
- Real-time online/offline status
- One-click access to iDRAC interfaces

🔑 **SSH Key Management**
- Generate RSA 4096-bit keys
- Deploy to all servers automatically
- Passwordless SSH access

🖥️ **Virtual Console Access**
- Direct browser-based console
- No downloads, no quarantine issues
- Works from any device

## Architecture

```
┌─────────────────────────────────────┐
│ Your Network                        │
│                                     │
│ [Proxmox Host] ────────────────────┐ │
│      │                             │ │
│      ├─ Container (Port 8080) ─────┼─┼─► [Any Browser]
│      │  ├─ Web Dashboard           │ │
│      │  ├─ API Server              │ │
│      │  ├─ Network Scanner         │ │
│      │  └─ SSH Key Manager         │ │
│      │                             │ │
│      └─ Scans Network ─────────────┼─┼─► [iDRAC Servers]
│                                     │ │
└─────────────────────────────────────┘ │
                                        │
┌─── Previous macOS Solution ──────────┘
│ ❌ Download .command files
│ ❌ macOS quarantine blocks
│ ❌ Complex time-shifting setup
│ ❌ Local machine dependency
└───────────────────────────────────────

```

## Container vs macOS Solution

| Feature | macOS Solution | Container Solution |
|---------|---------------|-------------------|
| **Quarantine Issues** | ❌ Constant blocks | ✅ None - browser only |
| **Setup Complexity** | ❌ Complex time-shift | ✅ One command deploy |
| **Access Method** | ❌ Download files | ✅ Click buttons |
| **Network Access** | ❌ Single machine | ✅ Any device |
| **Maintenance** | ❌ Manual updates | ✅ Container updates |
| **Enterprise Ready** | ❌ Dev tool | ✅ Production ready |

## Default Credentials

**iDRAC Access:**
- Username: `root`
- Password: `calvin`

## Commands

```bash
# Deploy
./deploy-proxmox.sh deploy

# Check status  
./deploy-proxmox.sh status

# View logs
./deploy-proxmox.sh logs

# Update to latest from GitHub
git pull origin main
./deploy-proxmox.sh update

# Remove
./deploy-proxmox.sh cleanup
```

## Success Indicators

After deployment, you should see:

1. **Container running**: `docker ps | grep idrac-manager`
2. **Dashboard accessible**: Browse to `http://proxmox-ip:8080`
3. **Servers discovered**: Dashboard shows your iDRAC servers
4. **API responding**: Green "API Server: ✅ Online" status

## Benefits

🎯 **No More Downloads** - Everything browser-based  
🔒 **Better Security** - Centralized SSH key management  
📊 **Professional UI** - Clean web interface  
🚀 **One-Click Access** - Direct iDRAC console launching  
🌐 **Network-Wide** - Access from phones, tablets, laptops  
⚡ **Auto-Updates** - Container restarts with latest data  

## GitHub Repository

**Source**: https://github.com/notdabob/namespace-timeshift-browser-container

- **Issues**: Report bugs and request features
- **Releases**: Download stable versions  
- **Documentation**: Always up-to-date guides
- **Community**: Discussions and support

---

**This completely solves the macOS quarantine problem by moving everything to a web-based container solution!**