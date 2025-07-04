"""
API key validation functions for AI Key Manager
"""

import re
import requests
import time
from typing import Dict, Any, Optional, Tuple
from datetime import datetime, timedelta


def validate_key_format(provider: str, key: str, config: Optional[Dict[str, Any]] = None) -> Tuple[bool, str]:
    """Validate API key format for a specific provider."""
    if config is None:
        from config import get_provider_config
        provider_config = get_provider_config(provider)
    else:
        provider_config = config.get("providers", {}).get(provider.lower())
    
    if not provider_config:
        return False, f"Unknown provider: {provider}"
    
    key_prefix = provider_config.get("key_prefix", "")
    
    # Basic format validation
    if not key:
        return False, "Key is empty"
    
    if key_prefix and not key.startswith(key_prefix):
        return False, f"Key must start with '{key_prefix}'"
    
    # Provider-specific format validation
    if provider.lower() == "openai":
        return _validate_openai_format(key)
    elif provider.lower() == "anthropic":
        return _validate_anthropic_format(key)
    elif provider.lower() == "gemini":
        return _validate_gemini_format(key)
    elif provider.lower() == "perplexity":
        return _validate_perplexity_format(key)
    elif provider.lower() == "groq":
        return _validate_groq_format(key)
    else:
        return _validate_generic_format(key, key_prefix)


def _validate_openai_format(key: str) -> Tuple[bool, str]:
    """Validate OpenAI API key format."""
    # OpenAI keys: sk-[48-51 chars]
    pattern = r'^sk-[A-Za-z0-9]{48,51}$'
    if re.match(pattern, key):
        return True, "Valid format"
    return False, "Invalid OpenAI key format (should be sk-[48-51 alphanumeric chars])"


def _validate_anthropic_format(key: str) -> Tuple[bool, str]:
    """Validate Anthropic API key format."""
    # Anthropic keys: sk-ant-[additional chars]
    pattern = r'^sk-ant-[A-Za-z0-9\-_]{50,}$'
    if re.match(pattern, key):
        return True, "Valid format"
    return False, "Invalid Anthropic key format (should be sk-ant-[50+ chars])"


def _validate_gemini_format(key: str) -> Tuple[bool, str]:
    """Validate Google Gemini API key format."""
    # Gemini keys: AIza[39 chars]
    pattern = r'^AIza[A-Za-z0-9\-_]{35,39}$'
    if re.match(pattern, key):
        return True, "Valid format"
    return False, "Invalid Gemini key format (should be AIza[35-39 chars])"


def _validate_perplexity_format(key: str) -> Tuple[bool, str]:
    """Validate Perplexity API key format."""
    # Perplexity keys: pplx-[additional chars]
    pattern = r'^pplx-[A-Za-z0-9]{32,}$'
    if re.match(pattern, key):
        return True, "Valid format"
    return False, "Invalid Perplexity key format (should be pplx-[32+ alphanumeric chars])"


def _validate_groq_format(key: str) -> Tuple[bool, str]:
    """Validate Groq API key format."""
    # Groq keys: gsk_[additional chars]
    pattern = r'^gsk_[A-Za-z0-9]{50,}$'
    if re.match(pattern, key):
        return True, "Valid format"
    return False, "Invalid Groq key format (should be gsk_[50+ alphanumeric chars])"


def _validate_generic_format(key: str, prefix: str) -> Tuple[bool, str]:
    """Validate generic API key format."""
    if len(key) < 20:
        return False, "Key appears too short (minimum 20 characters)"
    
    if len(key) > 200:
        return False, "Key appears too long (maximum 200 characters)"
    
    # Check for reasonable character set
    if not re.match(r'^[A-Za-z0-9\-_.]+$', key):
        return False, "Key contains invalid characters"
    
    return True, "Valid format"


def validate_key_online(provider: str, key: str, config: Optional[Dict[str, Any]] = None) -> Tuple[bool, str, Optional[Dict[str, Any]]]:
    """Validate API key by making an actual API call."""
    if config is None:
        from config import get_provider_config
        provider_config = get_provider_config(provider)
    else:
        provider_config = config.get("providers", {}).get(provider.lower())
    
    if not provider_config:
        return False, f"Unknown provider: {provider}", None
    
    validation_config = config.get("validation", {}) if config else {}
    timeout = validation_config.get("timeout", 30)
    retry_attempts = validation_config.get("retry_attempts", 3)
    retry_delay = validation_config.get("retry_delay", 1)
    
    for attempt in range(retry_attempts):
        try:
            if provider.lower() == "openai":
                success, message, details = _validate_openai_online(key, provider_config, timeout)
            elif provider.lower() == "anthropic":
                success, message, details = _validate_anthropic_online(key, provider_config, timeout)
            elif provider.lower() == "gemini":
                success, message, details = _validate_gemini_online(key, provider_config, timeout)
            elif provider.lower() == "perplexity":
                success, message, details = _validate_perplexity_online(key, provider_config, timeout)
            elif provider.lower() == "groq":
                success, message, details = _validate_groq_online(key, provider_config, timeout)
            else:
                return False, f"Online validation not implemented for {provider}", None
            
            if success or attempt == retry_attempts - 1:
                return success, message, details
            
            time.sleep(retry_delay)
        
        except Exception as e:
            if attempt == retry_attempts - 1:
                return False, f"Validation error: {str(e)}", None
            time.sleep(retry_delay)
    
    return False, "Validation failed after retries", None


def _validate_openai_online(key: str, config: Dict[str, Any], timeout: int) -> Tuple[bool, str, Optional[Dict[str, Any]]]:
    """Validate OpenAI API key online."""
    headers = {"Authorization": f"Bearer {key}"}
    url = config.get("api_url", "https://api.openai.com/v1/models")
    
    response = requests.get(url, headers=headers, timeout=timeout)
    
    if response.status_code == 200:
        data = response.json()
        models = data.get("data", [])
        return True, f"Valid - {len(models)} models available", {"models": len(models)}
    elif response.status_code == 401:
        return False, "Invalid API key", None
    else:
        return False, f"API error: {response.status_code}", None


def _validate_anthropic_online(key: str, config: Dict[str, Any], timeout: int) -> Tuple[bool, str, Optional[Dict[str, Any]]]:
    """Validate Anthropic API key online."""
    headers = {
        "x-api-key": key,
        "anthropic-version": "2023-06-01",
        "content-type": "application/json"
    }
    
    # Use a minimal request to test the key
    data = {
        "model": config.get("validation_model", "claude-3-sonnet-20240229"),
        "max_tokens": 1,
        "messages": [{"role": "user", "content": "Hi"}]
    }
    
    url = config.get("api_url", "https://api.anthropic.com/v1/messages")
    response = requests.post(url, headers=headers, json=data, timeout=timeout)
    
    if response.status_code == 200:
        return True, "Valid API key", None
    elif response.status_code == 401:
        return False, "Invalid API key", None
    elif response.status_code == 429:
        return True, "Valid but rate limited", None
    else:
        return False, f"API error: {response.status_code}", None


def _validate_gemini_online(key: str, config: Dict[str, Any], timeout: int) -> Tuple[bool, str, Optional[Dict[str, Any]]]:
    """Validate Google Gemini API key online."""
    url = f"{config.get('api_url', 'https://generativelanguage.googleapis.com/v1/models')}?key={key}"
    
    response = requests.get(url, timeout=timeout)
    
    if response.status_code == 200:
        data = response.json()
        models = data.get("models", [])
        return True, f"Valid - {len(models)} models available", {"models": len(models)}
    elif response.status_code == 400:
        error_data = response.json()
        if "API_KEY_INVALID" in str(error_data):
            return False, "Invalid API key", None
    elif response.status_code == 403:
        return False, "API key lacks permissions", None
    
    return False, f"API error: {response.status_code}", None


def _validate_perplexity_online(key: str, config: Dict[str, Any], timeout: int) -> Tuple[bool, str, Optional[Dict[str, Any]]]:
    """Validate Perplexity API key online."""
    headers = {
        "Authorization": f"Bearer {key}",
        "Content-Type": "application/json"
    }
    
    # Use a minimal request to test the key
    data = {
        "model": config.get("validation_model", "llama-3.1-sonar-small-128k-online"),
        "messages": [{"role": "user", "content": "Hi"}],
        "max_tokens": 1
    }
    
    url = config.get("api_url", "https://api.perplexity.ai/chat/completions")
    response = requests.post(url, headers=headers, json=data, timeout=timeout)
    
    if response.status_code == 200:
        return True, "Valid API key", None
    elif response.status_code == 401:
        return False, "Invalid API key", None
    elif response.status_code == 429:
        return True, "Valid but rate limited", None
    else:
        return False, f"API error: {response.status_code}", None


def _validate_groq_online(key: str, config: Dict[str, Any], timeout: int) -> Tuple[bool, str, Optional[Dict[str, Any]]]:
    """Validate Groq API key online."""
    headers = {"Authorization": f"Bearer {key}"}
    url = config.get("api_url", "https://api.groq.com/openai/v1/models")
    
    response = requests.get(url, headers=headers, timeout=timeout)
    
    if response.status_code == 200:
        data = response.json()
        models = data.get("data", [])
        return True, f"Valid - {len(models)} models available", {"models": len(models)}
    elif response.status_code == 401:
        return False, "Invalid API key", None
    else:
        return False, f"API error: {response.status_code}", None


def get_key_expiry_info(provider: str, key: str, config: Optional[Dict[str, Any]] = None) -> Optional[datetime]:
    """Get key expiry information if available."""
    # Most API keys don't have expiry info available through API
    # This is a placeholder for future implementation
    return None


def estimate_key_age(key: str) -> Optional[str]:
    """Estimate key age based on format patterns (heuristic)."""
    # This is a very rough heuristic and may not be accurate
    # Most providers don't encode timestamp in keys
    return None
