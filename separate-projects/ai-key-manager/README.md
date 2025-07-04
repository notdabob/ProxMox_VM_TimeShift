# AI Key Manager

A comprehensive macOS solution for securely managing AI API keys with Keychain integration.

## Features

- Import and validate AI API keys from .env files
- Secure storage in macOS Keychain
- Automated validation and expiry checking
- Support for multiple AI providers (OpenAI, Anthropic, Gemini, Perplexity, Groq)
- Bash completion for CLI commands
- Automated periodic validation via cron
- Comprehensive logging and error handling

## Installation

```bash
./install.sh
```

## Usage

```bash
# Import keys from .env file
ai-key-manager import /path/to/.env

# List all stored keys
ai-key-manager list

# Validate all keys
ai-key-manager validate

# Remove a specific key
ai-key-manager remove openai

# Show key details
ai-key-manager show anthropic

# Setup periodic validation
ai-key-manager setup-cron

# Display help
ai-key-manager --help
```

## Supported Providers

- OpenAI (GPT models)
- Anthropic (Claude models)
- Google Gemini
- Perplexity AI
- Groq

## Security Features

- Keys stored securely in macOS Keychain
- No plaintext storage of sensitive data
- Comprehensive validation before storage
- Automated expiry checking
- Secure key rotation support

## Requirements

- macOS 10.15 or later
- Python 3.8+
- Required Python packages (installed automatically)

## Configuration

Configuration file: `~/.config/ai-key-manager/config.json`

## Logs

Logs are stored in: `~/Library/Logs/ai-key-manager/`
