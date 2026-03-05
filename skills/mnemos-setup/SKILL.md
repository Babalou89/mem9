---
name: mnemos-setup
description: |
  Setup mnemos with TiDB Cloud Zero (instant, no signup) or your own database.
  Triggers: "set up mnemos", "install mnemo plugin", "configure memory plugin",
  "create mnemos database", "configure openclaw memory", "configure opencode memory",
  "configure claude code memory".
---

# mnemos Setup

**Persistent memory for AI agents.** This skill helps you set up mnemos with any agent platform.

## 🚀 Quick Start — TiDB Cloud Zero (Recommended)

**Zero signup. Zero config. Instant database.**

### Step 1: Provision database

```bash
# Get a free database instantly (no account needed)
curl -s -X POST https://zero.tidbapi.com/v1alpha1/instances \
  -H "Content-Type: application/json" \
  -d '{"tag":"mnemos"}' | tee /tmp/tidb-zero.json | jq .
```

**Save the output!** You'll need:
- `instance.connection.host` — database host
- `instance.connection.username` — username
- `instance.connection.password` — password
- `instance.claimInfo.claimUrl` — to claim permanently later

> ⏰ Instance expires in 30 days. Visit the `claimUrl` before expiration to keep your data permanently.

### Step 2: Extract credentials

```bash
export MNEMO_DB_HOST=$(jq -r '.instance.connection.host' /tmp/tidb-zero.json)
export MNEMO_DB_USER=$(jq -r '.instance.connection.username' /tmp/tidb-zero.json)
export MNEMO_DB_PASS=$(jq -r '.instance.connection.password' /tmp/tidb-zero.json)
export MNEMO_DB_NAME="test"
```

### Step 3: Configure your agent platform

Pick your platform and follow the instructions:

---

#### OpenClaw

Add to `openclaw.json`:

```json
{
  "plugins": {
    "slots": { "memory": "mnemo" },
    "entries": {
      "mnemo": {
        "enabled": true,
        "config": {
          "host": "<MNEMO_DB_HOST>",
          "username": "<MNEMO_DB_USER>",
          "password": "<MNEMO_DB_PASS>",
          "database": "test"
        }
      }
    }
  }
}
```

Replace `<MNEMO_DB_HOST>`, `<MNEMO_DB_USER>`, `<MNEMO_DB_PASS>` with actual values from Step 2.

Restart OpenClaw. You should see:
```
[mnemo] Direct mode (keyword-only)
```

---

#### OpenCode

Set environment variables (add to shell profile or `.env`):

```bash
export MNEMO_DB_HOST="<host from step 2>"
export MNEMO_DB_USER="<username from step 2>"
export MNEMO_DB_PASS="<password from step 2>"
export MNEMO_DB_NAME="test"
```

Add to `opencode.json`:
```json
{
  "plugin": ["mnemo-opencode"]
}
```

Restart OpenCode. You should see:
```
[mnemo] Direct mode (TiDB Starter HTTP Data API)
```

---

#### Claude Code

Add to `~/.claude/settings.json`:

```json
{
  "env": {
    "MNEMO_DB_HOST": "<host from step 2>",
    "MNEMO_DB_USER": "<username from step 2>",
    "MNEMO_DB_PASS": "<password from step 2>",
    "MNEMO_DB_NAME": "test"
  }
}
```

Install plugin:
```
/plugin marketplace add qiffang/mnemos
/plugin install mnemo-memory@mnemos
```

Restart Claude Code.

---

## Alternative: Use Your Own Database

If you prefer not to use TiDB Cloud Zero:

1. **Create a TiDB Starter cluster** at [tidbcloud.com](https://tidbcloud.com) (free tier available)
2. **Or use any MySQL-compatible database**
3. Get your connection credentials
4. Follow Step 3 above with your own credentials

---

## Server Mode (For Teams)

If you need multi-agent collaboration with space isolation:

### 1. Deploy mnemo-server

```bash
cd mnemos/server
MNEMO_DSN="user:pass@tcp(host:4000)/mnemos?parseTime=true" go run ./cmd/mnemo-server
```

### 2. Create a space

```bash
curl -s -X POST http://localhost:8080/api/spaces \
  -H "Content-Type: application/json" \
  -d '{"name":"my-team","agent_name":"agent-1","agent_type":"openclaw"}'
# → {"ok":true, "space_id":"...", "api_token":"mnemo_abc123"}
```

### 3. Configure plugins with server mode

**OpenClaw:**
```json
{
  "config": {
    "apiUrl": "http://localhost:8080",
    "apiToken": "mnemo_abc123"
  }
}
```

**OpenCode / Claude Code:**
```bash
export MNEMO_API_URL="http://localhost:8080"
export MNEMO_API_TOKEN="mnemo_abc123"
```

---

## Verification

After setup, test memory:

1. Ask your agent: "Remember that the project uses PostgreSQL 15"
2. Start a new session
3. Ask: "What database does this project use?"

The agent should recall the information from memory.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `No mode configured` | Set `MNEMO_DB_HOST` (direct) or `MNEMO_API_URL` (server) |
| `Direct mode requires...` | Set `MNEMO_DB_USER` and `MNEMO_DB_PASS` |
| Zero API error | Check network, retry, or use [tidbcloud.com](https://tidbcloud.com) |
| Plugin not loading | Check platform-specific config format |
