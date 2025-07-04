"""
Core AI Key Manager functionality
"""

import os
import json
import keyring
import subprocess
from pathlib import Path
from datetime import datetime, timedelta
from typing import Dict, Any, Optional, List, Tuple
import logging

try:
    from dotenv import load_dotenv, dotenv_values
except ImportError:
    load_dotenv = None
    dotenv_values = None

from validators import validate_key_format, validate_key_online
from utils import run_command, format_key_for_display, validate_env_file, get_cron_schedule


class AIKeyManager:
    """Main class for managing AI API keys."""
    
    def __init__(self, config: Optional[Dict[str, Any]] = None, logger: Optional[logging.Logger] = None):
        """Initialize the key manager."""
        if config is None:
            from config import load_config
            config = load_config()
        
        self.config = config
        self.logger = logger or logging.getLogger(__name__)
        self.keychain_service = config.get("keychain", {}).get("service_name", "ai-key-manager")
        
        # Ensure log directory exists
        log_dir = Path(config.get("logging", {}).get("log_dir", "~/Library/Logs/ai-key-manager")).expanduser()
        log_dir.mkdir(parents=True, exist_ok=True)
    
    def import_from_env(self, env_file_path: str, force: bool = False, validate: bool = True) -> int:
        """Import API keys from a .env file."""
        self.logger.info(f"Importing keys from {env_file_path}")
        
        # Validate env file
        valid, message = validate_env_file(env_file_path)
        if not valid:
            self.logger.error(f"Invalid env file: {message}")
            return 0
        
        if dotenv_values is None:
            self.logger.error("python-dotenv not available. Install with: pip install python-dotenv")
            return 0
        
        # Load environment variables
        env_vars = dotenv_values(env_file_path)
        if not env_vars:
            self.logger.warning("No variables found in env file")
            return 0
        
        # Find API key variables
        api_key_vars = {}
        for key, value in env_vars.items():
            if not value:
                continue
            
            key_lower = key.lower()
            if any(provider in key_lower for provider in ['openai', 'anthropic', 'gemini', 'perplexity', 'groq']):
                if 'api_key' in key_lower or 'key' in key_lower:
                    # Determine provider
                    provider = self._determine_provider_from_key_name(key)
                    if provider:
                        api_key_vars[provider] = value
        
        if not api_key_vars:
            self.logger.warning("No API key variables found in env file")
            return 0
        
        imported_count = 0
        for provider, api_key in api_key_vars.items():
            try:
                # Check if key already exists
                if not force and self._key_exists(provider):
                    self.logger.warning(f"Key for {provider} already exists (use --force to overwrite)")
                    continue
                
                # Validate format
                if validate:
                    format_valid, format_message = validate_key_format(provider, api_key, self.config)
                    if not format_valid:
                        self.logger.error(f"Invalid format for {provider}: {format_message}")
                        continue
                    
                    # Validate online if configured
                    if self.config.get("security", {}).get("require_validation", True):
                        online_valid, online_message, _ = validate_key_online(provider, api_key, self.config)
                        if not online_valid:
                            self.logger.error(f"Online validation failed for {provider}: {online_message}")
                            continue
                
                # Store in keychain
                if self._store_key(provider, api_key):
                    self.logger.info(f"Imported key for {provider}")
                    imported_count += 1
                else:
                    self.logger.error(f"Failed to store key for {provider}")
            
            except Exception as e:
                self.logger.error(f"Error importing key for {provider}: {e}")
        
        return imported_count
    
    def _determine_provider_from_key_name(self, key_name: str) -> Optional[str]:
        """Determine provider from environment variable name."""
        key_lower = key_name.lower()
        
        if 'openai' in key_lower:
            return 'openai'
        elif 'anthropic' in key_lower or 'claude' in key_lower:
            return 'anthropic'
        elif 'gemini' in key_lower or 'google' in key_lower:
            return 'gemini'
        elif 'perplexity' in key_lower:
            return 'perplexity'
        elif 'groq' in key_lower:
            return 'groq'
        
        return None
    
    def _key_exists(self, provider: str) -> bool:
        """Check if a key exists for the provider."""
        try:
            key = keyring.get_password(self.keychain_service, provider)
            return key is not None
        except Exception:
            return False
    
    def _store_key(self, provider: str, api_key: str) -> bool:
        """Store API key in keychain."""
        try:
            keyring.set_password(self.keychain_service, provider, api_key)
            
            # Store metadata
            metadata = {
                "provider": provider,
                "created_at": datetime.now().isoformat(),
                "last_validated": None,
                "validation_status": "unknown"
            }
            keyring.set_password(f"{self.keychain_service}-meta", provider, json.dumps(metadata))
            
            return True
        except Exception as e:
            self.logger.error(f"Failed to store key for {provider}: {e}")
            return False
    
    def list_keys(self, details: bool = False, provider: Optional[str] = None) -> List[str]:
        """List all stored API keys."""
        keys = []
        providers = [provider] if provider else self.config.get("providers", {}).keys()
        
        for prov in providers:
            if self._key_exists(prov):
                if details:
                    metadata = self._get_key_metadata(prov)
                    key_info = f"{prov}: {metadata.get('validation_status', 'unknown')}"
                    if metadata.get('last_validated'):
                        key_info += f" (last validated: {metadata['last_validated']})"
                    keys.append(key_info)
                else:
                    keys.append(prov)
        
        return keys
    
    def _get_key_metadata(self, provider: str) -> Dict[str, Any]:
        """Get metadata for a stored key."""
        try:
            metadata_str = keyring.get_password(f"{self.keychain_service}-meta", provider)
            if metadata_str:
                return json.loads(metadata_str)
        except Exception:
            pass
        
        return {}
    
    def _update_key_metadata(self, provider: str, metadata: Dict[str, Any]) -> bool:
        """Update metadata for a stored key."""
        try:
            keyring.set_password(f"{self.keychain_service}-meta", provider, json.dumps(metadata))
            return True
        except Exception as e:
            self.logger.error(f"Failed to update metadata for {provider}: {e}")
            return False
    
    def validate_keys(self, provider: Optional[str] = None, fix_issues: bool = False) -> Dict[str, Dict[str, Any]]:
        """Validate all stored keys."""
        results = {}
        providers = [provider] if provider else self.list_keys()
        
        for prov in providers:
            try:
                api_key = keyring.get_password(self.keychain_service, prov)
                if not api_key:
                    results[prov] = {"valid": False, "message": "Key not found"}
                    continue
                
                # Format validation
                format_valid, format_message = validate_key_format(prov, api_key, self.config)
                if not format_valid:
                    results[prov] = {"valid": False, "message": f"Format error: {format_message}"}
                    continue
                
                # Online validation
                online_valid, online_message, details = validate_key_online(prov, api_key, self.config)
                results[prov] = {
                    "valid": online_valid,
                    "message": online_message,
                    "details": details
                }
                
                # Update metadata
                metadata = self._get_key_metadata(prov)
                metadata["last_validated"] = datetime.now().isoformat()
                metadata["validation_status"] = "valid" if online_valid else "invalid"
                self._update_key_metadata(prov, metadata)
                
            except Exception as e:
                results[prov] = {"valid": False, "message": f"Validation error: {e}"}
        
        return results
    
    def show_key(self, provider: str, reveal_key: bool = False) -> Optional[str]:
        """Show details for a specific key."""
        api_key = keyring.get_password(self.keychain_service, provider)
        if not api_key:
            return None
        
        metadata = self._get_key_metadata(provider)
        
        info = [
            f"Provider: {provider}",
            f"Key: {format_key_for_display(api_key, reveal_key)}",
            f"Created: {metadata.get('created_at', 'Unknown')}",
            f"Last Validated: {metadata.get('last_validated', 'Never')}",
            f"Status: {metadata.get('validation_status', 'Unknown')}"
        ]
        
        return "\n".join(info)
    
    def remove_key(self, provider: str) -> bool:
        """Remove a stored key."""
        try:
            keyring.delete_password(self.keychain_service, provider)
            # Also remove metadata
            try:
                keyring.delete_password(f"{self.keychain_service}-meta", provider)
            except Exception:
                pass  # Metadata might not exist
            
            self.logger.info(f"Removed key for {provider}")
            return True
        except Exception as e:
            self.logger.error(f"Failed to remove key for {provider}: {e}")
            return False
    
    def update_key(self, provider: str, api_key: str, validate: bool = True) -> bool:
        """Update a specific key."""
        if validate:
            format_valid, format_message = validate_key_format(provider, api_key, self.config)
            if not format_valid:
                self.logger.error(f"Invalid format: {format_message}")
                return False
            
            if self.config.get("security", {}).get("require_validation", True):
                online_valid, online_message, _ = validate_key_online(provider, api_key, self.config)
                if not online_valid:
                    self.logger.error(f"Online validation failed: {online_message}")
                    return False
        
        return self._store_key(provider, api_key)
    
    def setup_cron(self, interval: str = "daily") -> bool:
        """Setup cron job for periodic validation."""
        cron_schedule = get_cron_schedule(interval)
        script_path = Path(__file__).parent.parent / "ai-key-manager"
        log_file = Path(self.config.get("logging", {}).get("log_dir", "~/Library/Logs/ai-key-manager")).expanduser() / "cron.log"
        
        cron_command = f"{cron_schedule} {script_path} validate >> {log_file} 2>&1"
        
        try:
            # Get current crontab
            success, current_cron, _ = run_command(["crontab", "-l"])
            if not success:
                current_cron = ""
            
            # Remove existing ai-key-manager cron jobs
            lines = [line for line in current_cron.split('\n') if 'ai-key-manager' not in line]
            
            # Add new cron job
            lines.append(cron_command)
            
            # Install new crontab
            new_cron = '\n'.join(line for line in lines if line.strip())
            process = subprocess.Popen(['crontab', '-'], stdin=subprocess.PIPE, text=True)
            process.communicate(input=new_cron)
            
            if process.returncode == 0:
                self.logger.info(f"Cron job setup for {interval} validation")
                return True
            else:
                self.logger.error("Failed to install crontab")
                return False
        
        except Exception as e:
            self.logger.error(f"Failed to setup cron: {e}")
            return False
    
    def disable_cron(self) -> bool:
        """Disable cron job."""
        try:
            success, current_cron, _ = run_command(["crontab", "-l"])
            if not success:
                return True  # No crontab exists
            
            # Remove ai-key-manager cron jobs
            lines = [line for line in current_cron.split('\n') if 'ai-key-manager' not in line]
            new_cron = '\n'.join(line for line in lines if line.strip())
            
            if new_cron:
                process = subprocess.Popen(['crontab', '-'], stdin=subprocess.PIPE, text=True)
                process.communicate(input=new_cron)
            else:
                # Remove crontab entirely if empty
                run_command(["crontab", "-r"])
            
            self.logger.info("Cron job disabled")
            return True
        
        except Exception as e:
            self.logger.error(f"Failed to disable cron: {e}")
            return False
    
    def get_status(self) -> str:
        """Get system status and statistics."""
        keys = self.list_keys()
        status_lines = [
            f"AI Key Manager Status",
            f"=====================",
            f"Total keys: {len(keys)}",
            f"Keychain service: {self.keychain_service}",
            f"Config file: {self.config.get('_config_path', 'default')}",
            ""
        ]
        
        if keys:
            status_lines.append("Stored keys:")
            for key in keys:
                metadata = self._get_key_metadata(key)
                status = metadata.get('validation_status', 'unknown')
                last_validated = metadata.get('last_validated', 'never')
                status_lines.append(f"  {key}: {status} (last validated: {last_validated})")
        else:
            status_lines.append("No keys stored")
        
        return "\n".join(status_lines)
    
    def backup_metadata(self, output_file: str) -> bool:
        """Backup key metadata (not the keys themselves)."""
        try:
            keys = self.list_keys()
            backup_data = {
                "timestamp": datetime.now().isoformat(),
                "version": "1.0",
                "keys": {}
            }
            
            for key in keys:
                metadata = self._get_key_metadata(key)
                backup_data["keys"][key] = metadata
            
            with open(output_file, 'w') as f:
                json.dump(backup_data, f, indent=2)
            
            self.logger.info(f"Metadata backup saved to {output_file}")
            return True
        
        except Exception as e:
            self.logger.error(f"Failed to backup metadata: {e}")
            return False
    
    def restore_metadata(self, backup_file: str) -> bool:
        """Restore key metadata from backup."""
        try:
            with open(backup_file, 'r') as f:
                backup_data = json.load(f)
            
            keys_data = backup_data.get("keys", {})
            restored_count = 0
            
            for provider, metadata in keys_data.items():
                if self._key_exists(provider):
                    if self._update_key_metadata(provider, metadata):
                        restored_count += 1
            
            self.logger.info(f"Restored metadata for {restored_count} keys")
            return restored_count > 0
        
        except Exception as e:
            self.logger.error(f"Failed to restore metadata: {e}")
            return False
