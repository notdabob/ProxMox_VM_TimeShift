# Local Deployment Guide

Since your project is not yet on GitHub, here are the steps to deploy from your local machine to ProxMox:

## Option 1: Direct Copy to ProxMox Host

```bash
# From your local machine (where the code is)
cd /path/to/your/ProxMox_VM_TimeShift

# Copy the entire project to your ProxMox host
scp -r . root@YOUR_PROXMOX_HOST:~/ProxMox_VM_TimeShift/

# SSH into your ProxMox host
ssh root@YOUR_PROXMOX_HOST

# Navigate to the project
cd ~/ProxMox_VM_TimeShift

# Make scripts executable
chmod +x deploy/*.sh
chmod +x scripts/*.sh

# Create a VM (if needed)
./deploy/create-vm.sh --type hybrid

# Deploy the stack
./deploy/deploy-stack.sh --vmid 220 --profile full
```

## Option 2: Deploy Directly on ProxMox Host

If you're already on the ProxMox host:

```bash
# Create project directory
mkdir -p ~/ProxMox_VM_TimeShift
cd ~/ProxMox_VM_TimeShift

# You'll need to copy the files manually or use git init locally
# Then proceed with deployment
./deploy/deploy-stack.sh --vmid 220 --profile full
```

## Option 3: Push to GitHub First (Recommended)

1. Create a new repository on GitHub (without README)
2. From your local machine:

```bash
cd /path/to/your/ProxMox_VM_TimeShift

# Add GitHub remote (replace with your actual repo URL)
git remote add origin https://github.com/notdabob/ProxMox_VM_TimeShift.git

# Push to GitHub
git push -u origin main

# Then on ProxMox host, clone with your credentials
git clone https://github.com/notdabob/ProxMox_VM_TimeShift.git
```

## Quick Start Without GitHub

For immediate deployment without GitHub:

```bash
# On ProxMox host, create a temporary transfer
ssh root@YOUR_PROXMOX_HOST "mkdir -p ~/projects/ProxMox_VM_TimeShift"

# From your local machine
cd /path/to/your/ProxMox_VM_TimeShift
tar czf - . | ssh root@YOUR_PROXMOX_HOST "cd ~/projects/ProxMox_VM_TimeShift && tar xzf -"

# On ProxMox host
ssh root@YOUR_PROXMOX_HOST
cd ~/projects/ProxMox_VM_TimeShift
chmod +x deploy/*.sh
./deploy/deploy-stack.sh --vmid 220 --profile full
```
