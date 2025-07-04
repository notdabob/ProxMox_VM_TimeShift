# Repository Clone Instructions

## 🔗 Correct GitHub Repository

**Repository URL**: https://github.com/notdabob/time-shift-proxmox

## 📥 Clone Commands

### For ProxMox Host Deployment
```bash
# SSH to your ProxMox host
ssh root@your-proxmox-host

# Clone the repository
git clone https://github.com/notdabob/time-shift-proxmox.git
cd time-shift-proxmox

# Make scripts executable
chmod +x scripts/*.sh
chmod +x deploy-unified-stack.sh

# Start deployment
./scripts/unified-vm-create.sh --type hybrid
```

### For Local Development
```bash
# Clone to local machine
git clone https://github.com/notdabob/time-shift-proxmox.git
cd time-shift-proxmox

# Review and modify configurations as needed
# Then copy to ProxMox host for deployment
```

## 📂 Expected Directory Structure After Clone

```
time-shift-proxmox/
├── scripts/
│   ├── unified-vm-create.sh          # ✅ VM creation
│   ├── service-discovery.sh          # ✅ Monitoring
│   └── migrate-legacy.sh             # ✅ Migration
├── deploy-unified-stack.sh           # ✅ Main deployment
├── docker-compose-unified.yaml       # ✅ Service definitions
├── config/
│   ├── homelab-config.yaml          # ✅ Configuration
│   ├── nginx-unified.conf            # ✅ Reverse proxy
│   └── dashboard/index.html          # ✅ Web dashboard
├── QUICK-START.md                    # ✅ Copy-paste commands
├── DEPLOYMENT-GUIDE.md               # ✅ Detailed guide
└── README-UNIFIED.md                 # ✅ Complete overview
```

## 🚀 Quick Start After Clone

1. **Navigate to directory**: `cd time-shift-proxmox`
2. **Make executable**: `chmod +x scripts/*.sh deploy-unified-stack.sh`
3. **Create VM**: `./scripts/unified-vm-create.sh --type hybrid`
4. **Deploy services**: `./deploy-unified-stack.sh --vmid VMID --profile full`
5. **Access dashboard**: `http://VM_IP:9010`

## 🔄 Update Existing Clone

If you already have the repository cloned:

```bash
cd time-shift-proxmox
git pull origin main
chmod +x scripts/*.sh deploy-unified-stack.sh
```

## 📋 Repository Information

- **Repository**: https://github.com/notdabob/time-shift-proxmox
- **Primary Branch**: main
- **License**: MIT (check repository for current license)
- **Issues**: https://github.com/notdabob/time-shift-proxmox/issues
- **Discussions**: https://github.com/notdabob/time-shift-proxmox/discussions

---

**All documentation has been updated to reference the correct GitHub repository URL.**