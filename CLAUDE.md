# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ProxMox_VM_TimeShift is a comprehensive homelab solution for ProxMox VE that provides unified deployment and management of multiple services including MCP servers, iDRAC management, time-shift proxies, and monitoring services. The project focuses on eliminating deployment inconsistencies through standardized configurations and automation.

## Core Components

1. **Unified Stack Deployment** - Central orchestration using Docker Compose
2. **Namespace TimeShift Browser Container** - Web-based iDRAC management with auto-discovery
3. **ProxMox VE Scripts** - Automated VM creation and deployment
4. **Time-Shift Proxmox** - SSL certificate manipulation for expired certificates

## Common Development Commands

### Building and Deployment

```bash
# Deploy full stack to a VM
./deploy/deploy-stack.sh --vmid 220 --profile full

# Deploy specific service profile
./deploy/deploy-stack.sh --vmid 220 --profile mcp|idrac|timeshift|monitoring

# Local deployment
./deploy/deploy-stack.sh --local --profile full

# Force deployment (restart services)
./deploy/deploy-stack.sh --vmid 220 --profile full --force

# Rollback deployment
./deploy/deploy-stack.sh --vmid 220 --rollback
```

### VM Management

```bash
# Create VMs with specific types
./deploy/create-vm.sh --type mcp|idrac|timeshift|hybrid

# Create hybrid VM with custom resources
./deploy/create-vm.sh --type hybrid --cores 6 --memory 12288
```

### Service Discovery and Monitoring

```bash
# Register services
./deploy/service-discovery.sh --register --vmid 220

# Health checks
./deploy/service-discovery.sh --health-check --vmid 220

# Continuous monitoring
./deploy/service-discovery.sh --watch --vmid 220 --interval 30

# View service status
./deploy/service-discovery.sh --status --vmid 220
```

### Docker Operations

```bash
# View running services
docker-compose ps

# View logs
docker-compose logs -f [service-name]

# Restart specific service
docker-compose restart [service-name]

# Rebuild and update
docker-compose build && docker-compose up -d
```

### Python Development (iDRAC Manager)

```bash
# Install dependencies
cd docker/services/idrac-manager
pip install -r requirements.txt

# Run tests (if available)
python -m pytest

# Start development server
python src/idrac-api-server.py
```

## Architecture and Structure

### Service Architecture
- **Microservices**: Each component runs as an isolated Docker container
- **Port Standardization**: 
  - 7001-7010: MCP Services
  - 8080-8090: iDRAC Services  
  - 8090-8099: Time-Shift Services
  - 9000-9010: Monitoring Services
- **Docker Networks**: Service isolation via homelab-network
- **Volume Management**: Persistent data with Docker volumes

### VMID Ranges
- 200-209: MCP Server Stack
- 210-219: iDRAC Management
- 220-229: Hybrid Stack (Recommended)
- 230-239: Time-Shift Proxy
- 240-249: Monitoring Services

### Key Configuration Files
- `docker/docker-compose.yaml`: Service orchestration
- `config/homelab-config.yaml`: Central configuration
- `docker/services/idrac-manager/Dockerfile`: iDRAC container definition
- Individual service requirements.txt files

## Development Guidelines

### Code Changes
- Always test deployment after code changes using `./deploy/deploy-stack.sh --dry-run`
- Follow existing patterns in Docker Compose files
- Maintain consistent port allocation as defined in architecture
- Update health checks when modifying services

### Documentation Updates
- Update `docs/CHANGELOG.md` for version changes
- Keep `docs/file-structure.md` current with project structure
- Update service-specific README files when functionality changes

### Testing
- Verify service health checks pass after changes
- Test rollback functionality after major updates
- Validate network connectivity between services
- Check log output for errors

### Security Considerations
- Never commit credentials or API keys
- Use environment variables for sensitive configuration
- Maintain network isolation between services
- Regular security updates for base images

## Claude Project Commands

Custom Claude commands for this project live in the `.claude/commands/` directory.

- **To create a new command:**  
  Add a markdown file to `.claude/commands/` (e.g., `optimize.md`). The filename (without .md) becomes the command name.

- **To use a command in Claude Code CLI:**  
  Run `/project:<command_name>` (e.g., `/project:optimize`).

- **Command template example:**  
  ```markdown
  # .claude/commands/optimize.md
  Analyze this code for performance issues and suggest optimizations:
  ```