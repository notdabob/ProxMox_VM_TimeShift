---
applyTo:
  - "docs/**"
  - "README.md"
  - "**/README.md"
  - "**/*.md"
---

# Documentation Standards Instructions

## Documentation Structure

### Hierarchy and Organization
```
docs/
├── DEPLOYMENT-GUIDE.md     # Step-by-step deployment instructions
├── TROUBLESHOOTING.md      # Common issues and solutions
├── UNIFIED-ARCHITECTURE.md # System architecture overview
├── QUICK-START.md          # Getting started guide
└── (avoid docs/archive/ for new content)
```

### File Naming Convention
- Use UPPERCASE for major documentation files
- Use kebab-case for specific guides: `vm-network-troubleshooting.md`
- Include descriptive prefixes: `DEPLOYMENT-`, `TROUBLESHOOTING-`

## Content Standards

### Required Sections for Guides

#### Deployment Documentation
```markdown
# Title

## Prerequisites
- List all requirements
- Include version dependencies
- Specify resource requirements

## Step-by-Step Instructions
1. Clear, numbered steps
2. Include command examples
3. Expected output examples
4. Error handling guidance

## Validation
- How to verify successful completion
- Health check procedures
- Troubleshooting common issues

## Rollback Procedures
- How to undo changes
- Recovery options
- Emergency procedures
```

#### Service Documentation
```markdown
# Service Name

## Overview
Brief description and purpose

## Configuration
- Environment variables
- Port allocations (follow standards)
- Dependencies

## API Endpoints
- Health check: /health
- Status: /status
- Metrics: /metrics (if applicable)

## Monitoring
- Health check implementation
- Log locations
- Common error patterns

## Troubleshooting
- Common issues and solutions
- Debug procedures
- Support contacts
```

### Code Examples
Always include complete, runnable examples:
```bash
# Deploy full stack to hybrid VM
./deploy/deploy-stack.sh --vmid 220 --profile full

# Expected output:
# [INFO] Validating deployment configuration...
# [SUCCESS] Deployment completed successfully
```

### Port Documentation
Always reference the standardized port allocation:
```markdown
## Port Allocation
- **7001-7010**: MCP Services (Context7, Desktop Commander, Filesystem)
- **8080-8090**: iDRAC Management (Web Dashboard, WebSocket API)
- **8090-8099**: Time-Shift Proxy (SSL Certificate Manipulation)
- **9000-9010**: Monitoring Services (Discovery, Health, Dashboard)
```

## Markdown Standards

### Headers
Use semantic heading structure:
```markdown
# Main Title (H1) - Only one per document
## Major Sections (H2)
### Subsections (H3)
#### Details (H4) - Rarely needed
```

### Code Blocks
Always specify language for syntax highlighting:
```markdown
```bash
# Bash commands
./deploy/create-vm.sh --type hybrid
```

```yaml
# YAML configuration
services:
  context7-mcp:
    image: lordsomer/context7-mcp:latest
```

```python
# Python code
def validate_config(config_file):
    with open(config_file, 'r') as f:
        return yaml.safe_load(f)
```
```

### Links and References
- Use descriptive link text
- Link to specific sections when possible
- Maintain relative links for internal documentation
- Verify all links are functional

### Tables
Use markdown tables for structured data:
```markdown
| Service | Port Range | Purpose |
|---------|------------|---------|
| MCP | 7001-7010 | Context management |
| iDRAC | 8080-8090 | Server management |
```

## Version Control for Documentation

### Change Management
- Update documentation with code changes
- Use descriptive commit messages for doc changes
- Review documentation in pull requests
- Maintain CHANGELOG.md for major updates

### Linking Documentation to Code
- Reference specific configuration files
- Link to actual implementation files
- Include version-specific information
- Document deprecation notices

## User Experience Guidelines

### Getting Started Experience
1. README.md must provide immediate value
2. Quick start section with working examples
3. Clear next steps and navigation
4. Prerequisites clearly stated upfront

### Error Guidance
- Include common error messages
- Provide specific solutions, not generic advice
- Link to relevant troubleshooting sections
- Include "what to do next" guidance

### Visual Aids
- Use ASCII diagrams for architecture
- Include network topology diagrams
- Provide screenshot examples for UI changes
- Use mermaid diagrams for complex flows

## Content Quality Standards

### Technical Accuracy
- Test all commands and examples
- Verify version compatibility
- Update deprecated information
- Cross-reference with implementation

### Clarity and Accessibility
- Write for varied technical skill levels
- Define technical terms on first use
- Use active voice and clear language
- Provide context for recommendations

### Completeness
- Cover end-to-end workflows
- Include edge cases and limitations
- Provide troubleshooting for each major step
- Link to additional resources

## Documentation Templates

### New Service README Template
```markdown
# Service Name

## Overview
Brief description and business purpose.

## Architecture
- Port allocation (following standards)
- Dependencies
- Integration points

## Configuration
### Environment Variables
### Configuration Files
### Default Settings

## Deployment
### Prerequisites
### Installation Steps
### Verification

## Operation
### Health Monitoring
### Log Analysis
### Common Maintenance Tasks

## Troubleshooting
### Common Issues
### Debug Procedures
### Support Resources

## API Reference (if applicable)
### Endpoints
### Authentication
### Examples
```

### Troubleshooting Guide Template
```markdown
# Issue Category Troubleshooting

## Quick Diagnosis
- How to identify the issue
- Key symptoms and indicators
- Immediate health checks

## Common Scenarios

### Scenario 1: Description
**Symptoms:**
- List observable symptoms

**Diagnosis:**
```bash
# Commands to diagnose
```

**Solution:**
```bash
# Commands to resolve
```

**Prevention:**
- How to prevent recurrence
```

## Reference Documentation

### Avoid Deprecated Sources
- Do not reference docs/archive/ content
- Use current implementation as source of truth
- Verify information against latest deployment scripts
- Update references to outdated procedures

### Maintain Consistency
- Use established terminology throughout
- Follow the same formatting patterns
- Cross-reference related documentation
- Keep examples current with codebase