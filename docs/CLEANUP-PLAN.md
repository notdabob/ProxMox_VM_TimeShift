# Codebase Cleanup and Restructuring Plan

## Overview

This plan provides a step-by-step approach to clean up and restructure the ProxMox_VM_TimeShift codebase, which currently contains multiple nested variations of related projects.

## Phase 1: Backup and Preparation (Day 1)

### 1.1 Create Full Backup
```bash
# Create backup with timestamp
tar -czf proxmox-vm-timeshift-backup-$(date +%Y%m%d-%H%M%S).tar.gz .
```

### 1.2 Create Working Branch
```bash
git checkout -b cleanup-restructure
git add .
git commit -m "Pre-cleanup snapshot"
```

### 1.3 Document Current State
- Take screenshots of working deployments
- Document which scripts are currently in use
- Note any custom configurations

## Phase 2: Identify and Separate Components (Day 2-3)

### 2.1 Core Components to Preserve

#### Unified Stack (KEEP - Primary)
- `deploy-unified-stack.sh`
- `docker-compose-unified.yaml`
- `scripts/unified-vm-create.sh`
- `scripts/service-discovery.sh`
- `scripts/migrate-legacy.sh`
- `config/homelab-config.yaml`
- `config/nginx-unified.conf`

#### Namespace TimeShift Browser Container (KEEP - As Service)
- `namespace-timeshift-browser-container/Dockerfile`
- `namespace-timeshift-browser-container/src/`
- `namespace-timeshift-browser-container/requirements.txt`
- `namespace-timeshift-browser-container/docker/`

### 2.2 Components to Archive

#### Legacy ProxMox Scripts
```bash
mkdir -p archive/legacy-proxmox-scripts
mv proxmox_ve-scripts/* archive/legacy-proxmox-scripts/
```

#### Legacy Time-Shift VM
```bash
mkdir -p archive/legacy-time-shift-vm
mv time-shift-proxmox/* archive/legacy-time-shift-vm/
```

#### Redundant Deployment Scripts
```bash
mkdir -p archive/legacy-scripts
mv namespace-timeshift-browser-container/deploy-proxmox.sh archive/legacy-scripts/
mv namespace-timeshift-browser-container/container-rebuild.sh archive/legacy-scripts/
mv namespace-timeshift-browser-container/emergency-fix.sh archive/legacy-scripts/
mv namespace-timeshift-browser-container/fix-container.sh archive/legacy-scripts/
mv namespace-timeshift-browser-container/restart-fix.sh archive/legacy-scripts/
```

### 2.3 Components to Remove

#### Unrelated Projects
```bash
mkdir -p separate-projects
mv ai-key-manager separate-projects/
```

#### Redundant/Outdated Files
- `deployment-execution.sh` (appears to be documentation)
- `install-complete-mcp-solution.sh` (macOS specific)
- `install-servemyapi.sh` (macOS specific)
- Various fix scripts at root level

## Phase 3: Restructure Directory Layout (Day 4)

### 3.1 New Structure
```
ProxMox_VM_TimeShift/
├── README.md                    # Main documentation
├── CHANGELOG.md                 # Project changelog
├── LICENSE
├── .gitignore
│
├── deploy/                      # Deployment scripts
│   ├── deploy-stack.sh         # Main deployment (renamed)
│   ├── create-vm.sh            # VM creation (renamed)
│   └── service-discovery.sh    # Service monitoring
│
├── config/                      # Configuration files
│   ├── homelab-config.yaml
│   ├── nginx-unified.conf
│   └── dashboard/
│
├── docker/                      # Docker configurations
│   ├── docker-compose.yaml     # Main compose file (renamed)
│   └── services/               # Service-specific Dockerfiles
│       └── idrac-manager/
│           ├── Dockerfile
│           ├── requirements.txt
│           └── src/
│
├── scripts/                     # Utility scripts
│   └── migrate-legacy.sh
│
├── docs/                        # Documentation
│   ├── ARCHITECTURE.md
│   ├── DEPLOYMENT.md
│   ├── MIGRATION.md
│   └── images/
│
├── tests/                       # Test scripts
│   └── test-deployment.sh
│
└── archive/                     # Legacy code (temporary)
    ├── README-ARCHIVE.md
    └── ... (legacy components)
```

### 3.2 Rename for Clarity
```bash
# Rename main scripts
mv deploy-unified-stack.sh deploy/deploy-stack.sh
mv scripts/unified-vm-create.sh deploy/create-vm.sh
mv docker-compose-unified.yaml docker/docker-compose.yaml

# Move service components
mkdir -p docker/services/idrac-manager
mv namespace-timeshift-browser-container/src docker/services/idrac-manager/
mv namespace-timeshift-browser-container/Dockerfile docker/services/idrac-manager/
mv namespace-timeshift-browser-container/requirements.txt docker/services/idrac-manager/
```

## Phase 4: Update References (Day 5)

### 4.1 Update Script Paths
- Update all scripts to reference new paths
- Update docker-compose.yaml build contexts
- Update deployment scripts

### 4.2 Update Documentation
- Create new README.md focusing on unified approach
- Archive old documentation
- Update CLAUDE.md with new structure

### 4.3 Update Configuration
- Consolidate configuration files
- Remove duplicate configs
- Update paths in configs

## Phase 5: Testing and Validation (Day 6)

### 5.1 Test Deployment
```bash
# Test VM creation
./deploy/create-vm.sh --type hybrid --dry-run

# Test service deployment
./deploy/deploy-stack.sh --local --profile full --dry-run

# Test service discovery
./scripts/service-discovery.sh --status
```

### 5.2 Validate Services
- Check all services start correctly
- Verify port accessibility
- Test health checks
- Validate dashboard access

## Phase 6: Finalization (Day 7)

### 6.1 Remove Archive (Optional)
After confirming everything works:
```bash
# Create final archive backup
tar -czf archive-backup.tar.gz archive/

# Remove archive directory
rm -rf archive/
```

### 6.2 Update Repository
```bash
# Commit changes
git add .
git commit -m "Major restructure: Consolidated unified deployment approach"

# Create tag for new version
git tag -a v2.0.0 -m "Unified deployment structure"
```

### 6.3 Create Migration Guide
Document how users can migrate from old structure to new structure.

## Quick Wins (Can Do Immediately)

1. **Remove obviously unrelated components**:
   ```bash
   mkdir separate-projects
   mv ai-key-manager separate-projects/
   ```

2. **Archive clear duplicates**:
   ```bash
   mkdir -p archive/duplicate-scripts
   mv proxmox_ve-scripts/scripts/*.sh archive/duplicate-scripts/
   ```

3. **Consolidate documentation**:
   ```bash
   mkdir -p docs/archive
   mv CLONE-INSTRUCTIONS.md docs/archive/
   mv DEPLOYMENT-GUIDE.md docs/
   mv QUICK-START.md docs/
   mv SETUP-INSTRUCTIONS.md docs/archive/
   ```

## Risk Mitigation

1. **Always test in a non-production environment first**
2. **Keep full backups at each phase**
3. **Document any custom modifications discovered**
4. **Maintain ability to rollback at each phase**
5. **Consider keeping archive directory for 30 days**

## Success Criteria

- [ ] Single, clear deployment path
- [ ] No duplicate scripts or configurations
- [ ] Clear separation of concerns
- [ ] All services deploy successfully
- [ ] Documentation reflects new structure
- [ ] Legacy code properly archived
- [ ] Unrelated projects separated