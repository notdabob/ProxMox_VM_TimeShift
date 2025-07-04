#!/bin/bash

# claude_command_setup.sh
# Usage: ./claude_command_setup.sh "command1:Prompt for command1" "command2:Prompt for command2" ...

set -e

# Change to the directory where this script is located
cd "$(dirname "$0")"

# Now you are always in .claude, so the check is not needed

# Create commands directory inside .claude if it doesn't exist
mkdir -p commands

# Process command arguments
for arg in "$@"; do
  CMD_NAME="${arg%%:*}"
  CMD_PROMPT="${arg#*:}"
  if [ -z "$CMD_NAME" ] || [ "$CMD_NAME" = "$CMD_PROMPT" ]; then
    echo "Invalid argument: $arg. Use format: command_name:Prompt text"
    continue
  fi
  CMD_FILE="commands/${CMD_NAME}.md"
  echo "$CMD_PROMPT" > "$CMD_FILE"
  echo "Created command: /project:$CMD_NAME  (.claude/commands/${CMD_NAME}.md)"
done

# Add or update instructions in ../CLAUDE.md
CLAUDE_MD="../CLAUDE.md"
INSTRUCTION_BLOCK="## Claude Project Commands

Custom Claude commands for this project live in the \`.claude/commands/\` directory.

- **To create a new command:**  
  Add a markdown file to \`.claude/commands/\` (e.g., \`optimize.md\`). The filename (without .md) becomes the command name.

- **To use a command in Claude Code CLI:**  
  Run \`/project:<command_name>\` (e.g., \`/project:optimize\`).

- **Command template example:**  
  \`\`\`markdown
  # .claude/commands/optimize.md
  Analyze this code for performance issues and suggest optimizations:
  \`\`\`
"

if [ -f "$CLAUDE_MD" ]; then
  if grep -q "## Claude Project Commands" "$CLAUDE_MD"; then
    # Replace existing instruction block
    awk -v block="$INSTRUCTION_BLOCK" '
      BEGIN {inblock=0}
      /^## Claude Project Commands/ {print block; inblock=1; next}
      inblock && /^\s*$/ {inblock=0; next}
      !inblock {print}
    ' "$CLAUDE_MD" > "${CLAUDE_MD}.tmp" && mv "${CLAUDE_MD}.tmp" "$CLAUDE_MD"
  else
    # Append instruction block
    echo -e "\n$INSTRUCTION_BLOCK\n" >> "$CLAUDE_MD"
  fi
else
  # Create CLAUDE.md with instructions
  echo -e "$INSTRUCTION_BLOCK\n" > "$CLAUDE_MD"
fi

echo "Updated $CLAUDE_MD with Claude command instructions."
