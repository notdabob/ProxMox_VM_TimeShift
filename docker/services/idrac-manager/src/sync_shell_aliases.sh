#!/bin/bash

# Add aliases and PATH to ~/.bashrc and ~/.zshrc if not already present
BASHRC="$HOME/.bashrc"
ZSHRC="$HOME/.zshrc"
POWERSHELL_PROFILE="$HOME/.config/powershell/Microsoft.PowerShell_profile.ps1"

# Ensure files exist
touch "$BASHRC"
touch "$ZSHRC"
mkdir -p "$(dirname "$POWERSHELL_PROFILE")"
touch "$POWERSHELL_PROFILE"

# Common PATH lines
PATH_LINES=(
'export PATH="$HOME/bin:$PATH"'
'export PATH="$PATH:$HOME/.local/bin"'
'export PATH="$PATH:/Applications/Visual Studio Code.app/Contents/Resources/app/bin"'
)

# Bash aliases
BASH_ALIASES=(
'alias ls="ls --color=auto"'
'alias activate_whisper='\''source "$HOME/activate_whisper.sh"'\'''
'alias pip="pip3"'
'alias code="code-insiders"'
'alias claude="$HOME/.claude/local/claude"'
)

# Zsh aliases (ls -G is preferred for zsh)
ZSH_ALIASES=(
'alias ls="ls -G"'
'alias activate_whisper='\''source "$HOME/activate_whisper.sh"'\'''
'alias pip="pip3"'
'alias code="code-insiders"'
'alias claude="$HOME/.claude/local/claude"'
)

# For .bashrc
for line in "${PATH_LINES[@]}"; do
  grep -qxF "$line" "$BASHRC" || echo "$line" >> "$BASHRC"
done
for line in "${BASH_ALIASES[@]}"; do
  grep -qxF "$line" "$BASHRC" || echo "$line" >> "$BASHRC"
done

# For .zshrc
for line in "${PATH_LINES[@]}"; do
  grep -qxF "$line" "$ZSHRC" || echo "$line" >> "$ZSHRC"
done
for line in "${ZSH_ALIASES[@]}"; do
  grep -qxF "$line" "$ZSHRC" || echo "$line" >> "$ZSHRC"
done

# For PowerShell profile
POWERSHELL_LINES=(
'$env:PATH += ":$HOME/.local/bin"'
'$env:PATH = "$HOME/bin:" + $env:PATH'
'$env:PATH += ":/Applications/Visual Studio Code.app/Contents/Resources/app/bin"'
'Set-Alias ls "ls"'
'Set-Alias activate_whisper "$HOME/activate_whisper.sh"'
'Set-Alias pip "pip3"'
'Set-Alias code "code-insiders"'
'Set-Alias claude "$HOME/.claude/local/claude"'
)
for line in "${POWERSHELL_LINES[@]}"; do
  grep -qxF "$line" "$POWERSHELL_PROFILE" || echo "$line" >> "$POWERSHELL_PROFILE"
done

echo "Aliases and PATH updates applied to ~/.bashrc, ~/.zshrc, and PowerShell profile."