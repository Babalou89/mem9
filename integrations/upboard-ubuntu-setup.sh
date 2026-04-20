#!/usr/bin/env bash
# upboard-ubuntu-setup.sh — Bootstrap an UP Board SBC running Ubuntu as an
# LLM robot controller for CNC router + Anchor M5 3D printer via mem9.
# Run once as root (or with sudo) after a fresh Ubuntu Server install.
# Usage: sudo bash upboard-ubuntu-setup.sh [path-to-mem9-repo]
set -euo pipefail

MEM9_REPO="${1:-$HOME/mem9}"
CLAUDE_DIR="$HOME/.claude"

# ── User-editable config ──────────────────────────────────────────────────────
ETH_IFACE="enp2s0"          # ethernet interface (check: ip link show)
ETH_IP="10.0.2.2/24"        # static IP — babalou enp6s0 is 10.0.2.1
ETH_GATEWAY=""               # no gateway on this LAN; babalou routes for us
ETH_DNS="8.8.8.8,1.1.1.1"

WIFI_IFACE="wlp3s0"         # WiFi interface (check: ip link show)
WIFI_SSID=""                 # set to route internet through WiFi instead of babalou
WIFI_PASSWORD=""

MEM9_API_URL="https://api.mem9.ai"
MEM9_TENANT_ID="c1a5fed9-4ae0-4338-8879-d1d786deee67"

OLLAMA_MODEL="llama3.2:3b"  # lightweight model for robot command generation
# ─────────────────────────────────────────────────────────────────────────────

ROBOT_USER="${SUDO_USER:-$(whoami)}"

log() { echo "==> $*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

[[ "$(id -u)" -eq 0 ]] || die "Run with sudo"

log "UP Board Ubuntu robot setup — user: $ROBOT_USER"

# ── 1. Network (netplan) ──────────────────────────────────────────────────────
log "Configuring network via netplan..."

NETPLAN_FILE="/etc/netplan/01-upboard.yaml"

cat > "$NETPLAN_FILE" <<NETPLAN
network:
  version: 2
  renderer: networkd
  ethernets:
    ${ETH_IFACE}:
      addresses:
        - ${ETH_IP}
      nameservers:
        addresses: [${ETH_DNS}]
      dhcp4: false
NETPLAN

# Only add default route if a gateway is specified
if [[ -n "$ETH_GATEWAY" ]]; then
  python3 - <<PY
import sys, re
txt = open("$NETPLAN_FILE").read()
insert = f"      routes:\\n        - to: default\\n          via: ${ETH_GATEWAY}\\n"
txt = re.sub(r'(      nameservers:)', insert + r'\1', txt)
open("$NETPLAN_FILE","w").write(txt)
PY
fi

if [[ -n "$WIFI_SSID" ]]; then
  cat >> "$NETPLAN_FILE" <<NETPLAN_WIFI
  wifis:
    ${WIFI_IFACE}:
      dhcp4: true
      access-points:
        "${WIFI_SSID}":
          password: "${WIFI_PASSWORD}"
NETPLAN_WIFI
fi

chmod 600 "$NETPLAN_FILE"
netplan apply
log "Network configured — static IP ${ETH_IP} on ${ETH_IFACE}"

# ── 2. System dependencies ────────────────────────────────────────────────────
log "Installing system dependencies..."
apt-get update -qq
apt-get install -y --no-install-recommends \
  curl git python3 python3-pip \
  minicom screen \
  build-essential

# Node.js 20 LTS via NodeSource
if ! command -v node >/dev/null 2>&1 || [[ "$(node -e 'process.stdout.write(process.versions.node.split(".")[0])')" -lt 18 ]]; then
  log "Installing Node.js 20 LTS..."
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
fi

log "Node $(node --version), npm $(npm --version)"

# ── 3. Serial port access ─────────────────────────────────────────────────────
log "Adding $ROBOT_USER to dialout group (serial ports)..."
usermod -aG dialout "$ROBOT_USER"
log "Serial ports /dev/ttyUSB* and /dev/ttyACM* accessible after re-login"

# ── 4. Ollama ─────────────────────────────────────────────────────────────────
log "Installing Ollama..."
if ! command -v ollama >/dev/null 2>&1; then
  curl -fsSL https://ollama.ai/install.sh | sh
fi

systemctl enable ollama
systemctl start ollama
sleep 3

log "Pulling model $OLLAMA_MODEL (this may take a while)..."
sudo -u "$ROBOT_USER" ollama pull "$OLLAMA_MODEL" || \
  log "WARNING: model pull failed — run 'ollama pull $OLLAMA_MODEL' manually"

# ── 5. Claude Code ────────────────────────────────────────────────────────────
log "Installing Claude Code..."
npm install -g @anthropic-ai/claude-code

# ── 6. mem9 hooks ─────────────────────────────────────────────────────────────
log "Configuring mem9 hooks for $ROBOT_USER..."

HOOK_BASE="$MEM9_REPO/claude-plugin/hooks"
[[ -d "$HOOK_BASE" ]] || die "mem9 repo not found at $MEM9_REPO — clone it first"

chmod +x "$HOOK_BASE/"*.sh

ROBOT_HOME=$(eval echo "~$ROBOT_USER")
ROBOT_CLAUDE_DIR="$ROBOT_HOME/.claude"
mkdir -p "$ROBOT_CLAUDE_DIR"

cat > "$ROBOT_CLAUDE_DIR/settings.json" <<EOF
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

chown -R "$ROBOT_USER:$ROBOT_USER" "$ROBOT_CLAUDE_DIR"

# ── 7. mem9 agent systemd service ─────────────────────────────────────────────
log "Installing mem9 agent systemd service..."

cat > /etc/systemd/system/mem9-agent.service <<SYSTEMD
[Unit]
Description=mem9 MCP memory agent
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${ROBOT_USER}
ExecStart=/usr/bin/python3 ${MEM9_REPO}/integrations/mem9-mcp-server.py
Restart=on-failure
RestartSec=10
Environment=MEM9_API_URL=${MEM9_API_URL}
Environment=MEM9_TENANT_ID=${MEM9_TENANT_ID}

[Install]
WantedBy=multi-user.target
SYSTEMD

systemctl daemon-reload
systemctl enable mem9-agent
systemctl start mem9-agent

# ── Done ──────────────────────────────────────────────────────────────────────
log ""
log "Setup complete. Summary:"
log "  Static IP : ${ETH_IP} on ${ETH_IFACE}"
log "  Ollama    : $(ollama --version 2>/dev/null || echo 'installed')"
log "  Node      : $(node --version)"
log "  Claude    : $(claude --version 2>/dev/null || echo 'installed')"
log "  mem9 svc  : $(systemctl is-active mem9-agent)"
log ""
log "Next steps:"
log "  1. Re-login as $ROBOT_USER (dialout group takes effect)"
log "  2. Run 'claude' to start a session — mem9 memories will load automatically"
log "  3. CNC serial: minicom -D /dev/ttyUSB0 -b 115200"
log "  4. 3D printer: minicom -D /dev/ttyACM0 -b 250000"
