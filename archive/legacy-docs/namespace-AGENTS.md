# AGENTS.md - Development Guide for AI Coding Agents

## Build/Test Commands
- **Container Build**: `docker build -t idrac-manager:latest .`
- **Deploy**: `./deploy-proxmox.sh deploy`
- **Test Python Syntax**: `python3 -m py_compile src/*.py`
- **Integration Testing**: `./test-multi-server.sh` (comprehensive multi-service test)
- **Run Single Test**: `python3 src/idrac-api-server.py` (test individual service)
- **Container Logs**: `docker logs idrac-manager` or `./deploy-proxmox.sh logs`
- **Service Status**: `docker exec -it idrac-manager supervisorctl status`
- **API Testing**: `curl http://localhost:8765/status` (check API health)
- **Dashboard Testing**: `curl -s -o /dev/null -w "%{http_code}" http://localhost:8080`

## Code Style Guidelines
- **Language**: Python 3.11+ with Flask/HTTP server frameworks
- **Imports**: Standard library first, third-party (requests, paramiko), then local
- **Functions**: Use triple-quote docstrings for all functions and classes
- **Variables**: snake_case for variables/functions, UPPER_CASE for constants
- **Error Handling**: Use try/except with specific exception types, log errors
- **File Paths**: Use `os.path.join()` and `os.makedirs(exist_ok=True)`
- **JSON**: Use `json.dump(data, f, indent=2)` for readable output
- **HTTP**: Use `requests` with `verify=False` for self-signed certs
- **Threading**: Use `threading.Lock()` for shared data, `MAX_WORKERS` constants
- **Configuration**: Store paths as constants at module top (DATA_DIR, etc.)
- **SSL/TLS**: Disable warnings with `urllib3.disable_warnings()`
- **CORS**: Include proper CORS headers for browser compatibility
- **No Type Hints**: This codebase doesn't use type annotations
- **Testing**: Use integration testing via `test-multi-server.sh` not unit tests