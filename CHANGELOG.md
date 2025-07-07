# Changelog

All notable changes to this project will be documented in this file.

## [v2.1.0] - 2024-01-07

### 🔧 Fixed
- **Critical**: Fixed Docker Compose path mismatch from `docker-compose-unified.yaml` to `docker/docker-compose.yaml`
- **Critical**: Resolved all deployment script file path references (8 locations updated)
- **Enhancement**: Improved path resolution in VM creation scripts with robust fallback mechanisms
- **Enhancement**: Enhanced error handling and retry logic for IP detection
- **Security**: Validated CORS configuration and sensitive data handling

### 🚀 Improved
- **Reliability**: Added better fallback mechanisms in VM creation process
- **Robustness**: Enhanced shared utility integration with proper error handling
- **Maintainability**: Standardized all compose file references to use `$COMPOSE_FILE` variable
- **Validation**: All shell scripts now pass syntax validation
- **Integration**: Comprehensive integration testing confirms all components work together

### 🛠️ Technical Changes
- Updated `deploy/deploy-stack.sh`: Fixed 8 hardcoded file path references
- Updated `deploy/create-vm.sh`: Enhanced IP detection with improved path resolution
- Validated all Python scripts syntax (network-scanner.py, idrac-api-server.py, dashboard-generator.py)
- Confirmed Docker Compose configuration validity
- Verified shared utilities integration across all scripts

### ✅ Validation Results
- File Structure: All required files and directories present
- Script Permissions: All scripts executable and syntactically correct
- Configuration Files: Valid JSON and YAML configurations
- Security: Sensitive information properly handled
- Integration: All components tested and working together

### 🎯 Impact
This release resolves all critical deployment issues and significantly improves the reliability and maintainability of the ProxMox VM TimeShift project. The codebase is now production-ready with enhanced error handling and robust path resolution.

## [Previous Versions]
See git history for previous changes.