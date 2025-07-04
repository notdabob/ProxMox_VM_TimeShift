"""
Configuration management for AI Key Manager
"""

import os
import json
from pathlib import Path
from typing import Dict, Any, Optional

# Default configuration
DEFAULT_CONFIG = {
    "keychain": {
        "service_name": "ai-key-manager",
        "access_group": None
    },
    "providers": {
        "openai": {
            "name": "OpenAI",
            "key_prefix": "sk-",
            "api_url": "https://api.openai.com/v1/models",
            "validation_model": "gpt-3.5-turbo"
        },
        "anthropic": {
            "name": "Anthropic",
            "key_prefix": "sk-ant-",
            "api_url": "https://api.anthropic.com/v1/messages",
            "validation_model": "claude-3-sonnet-20240229"
        },
        "gemini": {
            "name": "Google Gemini",
            "key_prefix": "AIza",
            "api_url": "https://generativelanguage.googleapis.com/v1/models",
            "validation_model": "gemini-pro"
        },
        "perplexity": {
            "name": "Perplexity AI",
            "key_prefix": "pplx-",
            "api_url": "https://api.perplexity.ai/chat/completions",
            "validation_model": "llama-3.1-sonar-small-128k-online"
        },
        "groq": {
            "name": "Groq",
            "key_prefix": "gsk_",
            "api_url": "https://api.groq.com/openai/v1/models",
            "validation_model": "llama3-8b-8192"
        }
    },
    "validation": {
        "timeout": 30,
        "retry_attempts": 3,
        "retry_delay": 1
    },
    "logging": {
        "level": "INFO",
        "log_dir": "~/Library/Logs/ai-key-manager",
        "max_log_files": 10,
        "max_log_size_mb": 50
    },
    "cron": {
        "default_interval": "daily",
        "log_output": True
    },
    "security": {
        "require_validation": True,
        "backup_encryption": True,
        "key_rotation_days": 90
    }
}

def get_config_path(custom_path: Optional[str] = None) -> Path:
    """Get the configuration file path."""
    if custom_path:
        return Path(custom_path).expanduser()
    
    config_dir = Path.home() / ".config" / "ai-key-manager"
    config_dir.mkdir(parents=True, exist_ok=True)
    return config_dir / "config.json"

def load_config(config_path: Optional[str] = None) -> Dict[str, Any]:
    """Load configuration from file, creating default if not exists."""
    config_file = get_config_path(config_path)
    
    if config_file.exists():
        try:
            with open(config_file, 'r') as f:
                user_config = json.load(f)
            
            # Merge with defaults (user config takes precedence)
            config = DEFAULT_CONFIG.copy()
            config.update(user_config)
            return config
        except (json.JSONDecodeError, IOError) as e:
            print(f"Warning: Could not load config from {config_file}: {e}")
            print("Using default configuration")
    
    # Create default config file
    save_config(DEFAULT_CONFIG, config_path)
    return DEFAULT_CONFIG.copy()

def save_config(config: Dict[str, Any], config_path: Optional[str] = None) -> bool:
    """Save configuration to file."""
    config_file = get_config_path(config_path)
    
    try:
        config_file.parent.mkdir(parents=True, exist_ok=True)
        with open(config_file, 'w') as f:
            json.dump(config, f, indent=2)
        return True
    except IOError as e:
        print(f"Error saving config to {config_file}: {e}")
        return False

def get_provider_config(provider: str, config: Optional[Dict[str, Any]] = None) -> Optional[Dict[str, Any]]:
    """Get configuration for a specific provider."""
    if config is None:
        config = load_config()
    
    return config.get("providers", {}).get(provider.lower())

def validate_config(config: Dict[str, Any]) -> tuple[bool, list[str]]:
    """Validate configuration structure."""
    errors = []
    
    # Check required top-level keys
    required_keys = ["keychain", "providers", "validation", "logging"]
    for key in required_keys:
        if key not in config:
            errors.append(f"Missing required config section: {key}")
    
    # Validate providers
    if "providers" in config:
        for provider_name, provider_config in config["providers"].items():
            required_provider_keys = ["name", "key_prefix", "api_url"]
            for key in required_provider_keys:
                if key not in provider_config:
                    errors.append(f"Provider {provider_name} missing required key: {key}")
    
    # Validate logging config
    if "logging" in config:
        log_config = config["logging"]
        if "level" in log_config:
            valid_levels = ["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"]
            if log_config["level"] not in valid_levels:
                errors.append(f"Invalid logging level: {log_config['level']}")
    
    return len(errors) == 0, errors

def expand_paths(config: Dict[str, Any]) -> Dict[str, Any]:
    """Expand user paths in configuration."""
    config = config.copy()
    
    if "logging" in config and "log_dir" in config["logging"]:
        config["logging"]["log_dir"] = str(Path(config["logging"]["log_dir"]).expanduser())
    
    return config
