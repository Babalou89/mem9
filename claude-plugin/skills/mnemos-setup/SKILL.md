---
name: mnemos-setup
description: "Setup mnemos persistent memory with TiDB Cloud Zero (instant, no signup) or your own database. Triggers: set up mnemos, install mnemo, configure memory."
context: fork
allowed-tools: Bash
---

# mnemos Setup for Claude Code

**Persistent memory for Claude Code.** This skill helps you set up mnemos.

## 🚀 Quick Start — TiDB Cloud Zero (Recommended)

**Zero signup. Zero config. Instant database.**

### Step 1: Provision database

Run this command:

```bash
curl -s -X POST https://zero.tidbapi.com/v1alpha1/instances \
  -H "Content-Type: application/json" \
  -d '{"tag":"mnemos-claude"}' | tee /tmp/tidb-zero.json | jq .
```

### Step 2: Extract and display credentials

```bash
MNEMO_DB_HOST=$(jq -r '.instance.connection.host' /tmp/tidb-zero.json)
MNEMO_DB_USER=$(jq -r '.instance.connection.username' /tmp/tidb-zero.json)
MNEMO_DB_PASS=$(jq -r '.instance.connection.password' /tmp/tidb-zero.json)
CLAIM_URL=$(jq -r '.instance.claimInfo.claimUrl' /tmp/tidb-zero.json)

cat << EOF

✅ Database provisioned! Add this to ~/.claude/settings.json:

{
  "env": {
    "MNEMO_DB_HOST": "$MNEMO_DB_HOST",
    "MNEMO_DB_USER": "$MNEMO_DB_USER",
    "MNEMO_DB_PASS": "$MNEMO_DB_PASS",
    "MNEMO_DB_NAME": "test"
  }
}

⏰ Instance expires in 30 days.
   To keep your data permanently, visit: $CLAIM_URL

EOF
```

### Step 3: Install plugin

Tell the user to run in Claude Code:
```
/plugin marketplace add qiffang/mnemos
/plugin install mnemo-memory@mnemos
```

### Step 4: Restart Claude Code

Tell the user to restart Claude Code to activate the plugin.

## Alternative: User's Own Database

If the user already has a TiDB or MySQL database:

1. Ask for their connection credentials (host, username, password)
2. Help them add the `env` block to `~/.claude/settings.json`
3. Install the plugin via marketplace

## Verification

After setup, suggest testing:
1. "Remember that this project uses React 18"
2. Start a new session
3. "What UI framework does this project use?"

The agent should recall from memory.
