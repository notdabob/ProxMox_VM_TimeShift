"""
Utility functions for AI Key Manager
"""

import os
import logging
import subprocess
from pathlib import Path
from typing import Optional, Dict, Any
from logging.handlers import RotatingFileHandler


def setup_logging(verbose: bool = False, config: Optional[Dict[str, Any]] = None) -> logging.Logger:
    """Setup logging configuration."""
    if config is None:
        from config import load_config
        config = load_config()
    
    log_config = config.get("logging", {})
    log_level = log_config.get("level", "INFO")
    log_dir = Path(log_config.get("log_dir", "~/Library/Logs/ai-key-manager")).expanduser()
    max_log_files = log_config.get("max_log_files", 10)
    max_log_size_mb = log_config.get("max_log_size_mb", 50)
    
    # Create log directory
    log_dir.mkdir(parents=True, exist_ok=True)
    
    # Setup logger
    logger = logging.getLogger("ai-key-manager")
    logger.setLevel(getattr(logging, log_level))
    
    # Clear existing handlers
    logger.handlers.clear()
    
    # File handler with rotation
    log_file = log_dir / "ai-key-manager.log"
    file_handler = RotatingFileHandler(
        log_file,
        maxBytes=max_log_size_mb * 1024 * 1024,
        backupCount=max_log_files
    )
    file_formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    file_handler.setFormatter(file_formatter)
    logger.addHandler(file_handler)
    
    # Console handler
    if verbose:
        console_handler = logging.StreamHandler()
        console_formatter = logging.Formatter('%(levelname)s: %(message)s')
        console_handler.setFormatter(console_formatter)
        logger.addHandler(console_handler)
    
    return logger


def load_config(config_path: Optional[str] = None) -> Dict[str, Any]:
    """Load configuration (wrapper for config module)."""
    from config import load_config as _load_config
    return _load_config(config_path)


def run_command(command: list[str], capture_output: bool = True, timeout: int = 30) -> tuple[bool, str, str]:
    """Run a shell command and return success status, stdout, and stderr."""
    try:
        result = subprocess.run(
            command,
            capture_output=capture_output,
            text=True,
            timeout=timeout,
            check=False
        )
        return result.returncode == 0, result.stdout, result.stderr
    except subprocess.TimeoutExpired:
        return False, "", "Command timed out"
    except Exception as e:
        return False, "", str(e)


def check_macos_version() -> tuple[bool, str]:
    """Check if running on supported macOS version."""
    try:
        success, stdout, stderr = run_command(["sw_vers", "-productVersion"])
        if not success:
            return False, "Could not determine macOS version"
        
        version = stdout.strip()
        # Parse version (e.g., "10.15.7" or "11.6.1")
        major, minor = map(int, version.split('.')[:2])
        
        if major >= 11 or (major == 10 and minor >= 15):
            return True, version
        else:
            return False, f"macOS {version} is not supported (requires 10.15 or later)"
    except Exception as e:
        return False, f"Error checking macOS version: {e}"


def check_dependencies() -> Dict[str, bool]:
    """Check if required dependencies are available."""
    dependencies = {}
    
    # Check Python version
    import sys
    python_version = sys.version_info
    dependencies["python"] = python_version >= (3, 8)
    
    # Check required Python modules
    required_modules = ["keyring", "requests", "python-dotenv"]
    for module in required_modules:
        try:
            __import__(module.replace("-", "_"))
            dependencies[module] = True
        except ImportError:
            dependencies[module] = False
    
    # Check system tools
    system_tools = ["security", "crontab"]
    for tool in system_tools:
        success, _, _ = run_command(["which", tool])
        dependencies[tool] = success
    
    return dependencies


def format_key_for_display(key: str, reveal: bool = False) -> str:
    """Format API key for display (masked or revealed)."""
    if reveal:
        return key
    
    if len(key) <= 8:
        return "****"
    
    # Show first 4 and last 4 characters
    return f"{key[:4]}...{key[-4:]}"


def validate_env_file(env_file_path: str) -> tuple[bool, str]:
    """Validate that the .env file exists and is readable."""
    env_path = Path(env_file_path)
    
    if not env_path.exists():
        return False, f"File does not exist: {env_file_path}"
    
    if not env_path.is_file():
        return False, f"Path is not a file: {env_file_path}"
    
    if not os.access(env_path, os.R_OK):
        return False, f"File is not readable: {env_file_path}"
    
    try:
        with open(env_path, 'r') as f:
            content = f.read()
        if not content.strip():
            return False, "File is empty"
    except Exception as e:
        return False, f"Error reading file: {e}"
    
    return True, "Valid"


def get_cron_schedule(interval: str) -> str:
    """Get cron schedule string for the given interval."""
    schedules = {
        "hourly": "0 * * * *",
        "daily": "0 2 * * *",  # 2 AM daily
        "weekly": "0 2 * * 0"  # 2 AM on Sundays
    }
    return schedules.get(interval, schedules["daily"])


def sanitize_filename(filename: str) -> str:
    """Sanitize filename for safe filesystem use."""
    import re
    # Remove or replace invalid characters
    sanitized = re.sub(r'[<>:"/\\|?*]', '_', filename)
    # Remove leading/trailing spaces and dots
    sanitized = sanitized.strip(' .')
    # Limit length
    return sanitized[:255]


def format_datetime(dt) -> str:
    """Format datetime for display."""
    return dt.strftime("%Y-%m-%d %H:%M:%S")


def bytes_to_human_readable(size_bytes: int) -> str:
    """Convert bytes to human readable format."""
    if size_bytes == 0:
        return "0 B"
    
    size_names = ["B", "KB", "MB", "GB"]
    i = 0
    while size_bytes >= 1024 and i < len(size_names) - 1:
        size_bytes /= 1024.0
        i += 1
    
    return f"{size_bytes:.1f} {size_names[i]}"


def ensure_directory_exists(directory_path: str) -> bool:
    """Ensure directory exists, creating if necessary."""
    try:
        Path(directory_path).mkdir(parents=True, exist_ok=True)
        return True
    except Exception:
        return False
