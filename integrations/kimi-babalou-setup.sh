#!/usr/bin/env bash
# kimi-babalou-setup.sh — Install Kimi Code CLI + mem9 MCP integration on Linux.
# Run on babalou after cloning the mem9 repo.
set -euo pipefail

INTEGRATIONS_DIR="$(cd "$(dirname "$0")" && pwd)"
MEM9_TENANT_ID="${MEM9_TENANT_ID:-c1a5fed9-4ae0-4338-8879-d1d786deee67}"
MEM9_API_URL="${MEM9_API_URL:-https://api.mem9.ai}"

echo "==> Installing Kimi Code CLI..."
curl -LsSf https://code.kimi.com/install.sh | bash

# Reload PATH so kimi is found immediately
export PATH="$HOME/.local/bin:$PATH"

echo ""
echo "==> Kimi version: $(kimi --version 2>/dev/null || echo 'installed, restart shell to use')"

# Create kimi config dir
KIMI_CONFIG_DIR="$HOME/.config/kimi"
mkdir -p "$KIMI_CONFIG_DIR"

echo "==> Writing mem9 MCP config for Kimi..."
cat > "$KIMI_CONFIG_DIR/mcp-mem9.json" <<EOF
{
  "mcpServers": {
    "mem9": {
      "command": "python3",
      "args": ["$INTEGRATIONS_DIR/mem9-mcp-server.py"],
      "env": {
        "MEM9_API_URL": "$MEM9_API_URL",
        "MEM9_TENANT_ID": "$MEM9_TENANT_ID"
      }
    }
  }
}
EOF

echo "==> Writing kimi-mem9 launcher to ~/bin/kimi-mem9..."
mkdir -p "$HOME/bin"
cat > "$HOME/bin/kimi-mem9" <<LAUNCHER
#!/usr/bin/env bash
export MEM9_API_URL="$MEM9_API_URL"
export MEM9_TENANT_ID="$MEM9_TENANT_ID"
export PATH="\$HOME/.local/bin:\$PATH"
exec kimi --mcp-config-file "$KIMI_CONFIG_DIR/mcp-mem9.json" "\$@"
LAUNCHER
chmod +x "$HOME/bin/kimi-mem9"

echo ""
echo "==> Done!"
echo ""
echo "Next steps:"
echo "  1. Add API key:  export MOONSHOT_API_KEY=sk-..."
echo "     (get key at https://platform.moonshot.cn/console/api-keys)"
echo "  2. Launch:       kimi-mem9"
echo "  3. First run:    /login  (inside kimi)"
echo ""
echo "mem9 tools available inside kimi-mem9:"
echo "  get_memories  — fetch shared team memories"
echo "  save_memory   — save something to the shared pool"
