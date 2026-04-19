#!/usr/bin/env bash
# linux-claude-setup.sh — One-time setup for Claude Code on Linux (Omen).
# Run once after cloning the mem9 repo on Linux.
# Usage: bash linux-claude-setup.sh [path-to-mem9-repo]
set -euo pipefail

MEM9_REPO="${1:-$HOME/gitrepo/mem9}"
CLAUDE_DIR="$HOME/.claude"
SKILLS_DIR="$CLAUDE_DIR/skills"

MEM9_API_URL="https://api.mem9.ai"
MEM9_TENANT_ID="c1a5fed9-4ae0-4338-8879-d1d786deee67"

echo "==> Setting up Claude Code mem9 integration on Linux"
echo "    Repo: $MEM9_REPO"

if [[ ! -d "$MEM9_REPO/claude-plugin/hooks" ]]; then
  echo "ERROR: hooks not found at $MEM9_REPO/claude-plugin/hooks"
  echo "       Clone the repo first: git clone <mem9-url> $MEM9_REPO"
  exit 1
fi

chmod +x "$MEM9_REPO/claude-plugin/hooks/"*.sh

mkdir -p "$SKILLS_DIR"

echo "==> Copying skills..."
for skill_dir in "$MEM9_REPO/skills"/*/; do
  skill_name=$(basename "$skill_dir")
  mkdir -p "$SKILLS_DIR/$skill_name"
  cp -r "$skill_dir"* "$SKILLS_DIR/$skill_name/"
  echo "    copied: $skill_name"
done

# Copy graphify skill if it exists separately in claude-plugin
if [[ -d "$MEM9_REPO/claude-plugin/skills" ]]; then
  for skill_dir in "$MEM9_REPO/claude-plugin/skills"/*/; do
    skill_name=$(basename "$skill_dir")
    mkdir -p "$SKILLS_DIR/$skill_name"
    cp -r "$skill_dir"* "$SKILLS_DIR/$skill_name/"
    echo "    copied: $skill_name"
  done
fi

HOOK_BASE="$MEM9_REPO/claude-plugin/hooks"

echo "==> Writing ~/.claude/settings.json..."
cat > "$CLAUDE_DIR/settings.json" <<EOF
{
  "env": {
    "MEM9_API_URL": "$MEM9_API_URL",
    "MEM9_TENANT_ID": "$MEM9_TENANT_ID"
  },
  "permissions": {
    "defaultMode": "bypassPermissions"
  },
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$HOOK_BASE/session-start.sh"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$HOOK_BASE/user-prompt-submit.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "$HOOK_BASE/stop.sh",
            "timeout": 120
          }
        ]
      }
    ]
  },
  "autoUpdatesChannel": "latest",
  "skipDangerousModePermissionPrompt": true
}
EOF

echo ""
echo "==> Done. Verify with: claude --version"
echo "    Memories will auto-load on next 'claude' session start."
