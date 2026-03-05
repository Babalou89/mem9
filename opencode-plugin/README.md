# OpenCode Plugin for mnemos

Persistent memory for [OpenCode](https://opencode.ai) — injects memories into system prompt automatically, captures session context on idle, with 5 memory tools.

## 🚀 Quick Start (30 seconds with TiDB Cloud Zero)

**Zero signup. Zero config. Instant database.**

```bash
# 1. Get a free database instantly (no account needed)
curl -s -X POST https://zero.tidbapi.com/v1alpha1/instances \
  -H "Content-Type: application/json" \
  -d '{"tag":"mnemos-opencode"}' | tee /tmp/tidb-zero.json | jq .

# 2. Set environment variables from the response
export MNEMO_DB_HOST=$(jq -r '.instance.connection.host' /tmp/tidb-zero.json)
export MNEMO_DB_USER=$(jq -r '.instance.connection.username' /tmp/tidb-zero.json)
export MNEMO_DB_PASS=$(jq -r '.instance.connection.password' /tmp/tidb-zero.json)
export MNEMO_DB_NAME="test"

# 3. Add plugin to opencode.json
echo '{"plugin": ["mnemo-opencode"]}' > opencode.json

# 4. Start OpenCode - plugin auto-installs from npm
opencode
```

**That's it!** Your agent now has persistent cloud memory.

> ⏰ **Note**: TiDB Cloud Zero instances expire in 30 days. To keep your data permanently, visit the `claimUrl` in the response to convert to a free TiDB Starter account.

---

## How It Works

```
System Prompt Transform → Inject recent memories (cached 5min)
          ↓
    Agent works normally, can use memory_* tools anytime
          ↓
Session Idle Event → Auto-capture session marker
```

| Hook / Tool | Trigger | What it does |
|---|---|---|
| `system.transform` | Every chat turn | Injects recent memories into system prompt (5-min TTL cache) |
| `session.idle` event | Session goes idle | Auto-saves a session-end marker as memory |
| `memory_store` tool | Agent decides | Store a new memory (with optional key for upsert) |
| `memory_search` tool | Agent decides | Hybrid vector + keyword search (or keyword-only) |
| `memory_get` tool | Agent decides | Retrieve a single memory by ID |
| `memory_update` tool | Agent decides | Update an existing memory |
| `memory_delete` tool | Agent decides | Delete a memory by ID |

## Prerequisites

- [OpenCode](https://opencode.ai) installed
- **One** of the following backends:
  - A [TiDB Starter](https://tidbcloud.com) cluster (free tier) — **Direct mode** (default, recommended)
  - [TiDB Cloud Zero](https://zero.tidbcloud.com) — instant database, no signup (see Quick Start above)
  - A running [mnemo-server](../server/) instance — **Server mode** (for teams / multi-agent setups)

## Installation

### Method A: npm plugin (Recommended)

The simplest way — OpenCode auto-installs npm plugins at startup.

Add to your `opencode.json`:

```json
{
  "plugin": ["mnemo-opencode"]
}
```

That's it. OpenCode will install `mnemo-opencode` from npm automatically on next startup.

### Method B: From source

```bash
git clone https://github.com/qiffang/mnemos.git
cd mnemos/opencode-plugin
npm install
```

Then register in `opencode.json`:

```json
{
  "plugins": {
    "mnemo": {
      "path": "/absolute/path/to/mnemos/opencode-plugin"
    }
  }
}
```

### Set environment variables

#### Option A: Direct Mode (default — TiDB Starter)

Connect directly to TiDB Cloud. No server deployment needed.

```bash
export MNEMO_DB_HOST="gateway01.us-east-1.prod.aws.tidbcloud.com"
export MNEMO_DB_USER="xxx.root"
export MNEMO_DB_PASS="xxx"
export MNEMO_DB_NAME="mnemos"        # default: mnemos

# Optional: enable hybrid vector search
export MNEMO_EMBED_API_KEY="sk-..."
export MNEMO_EMBED_BASE_URL=""        # default: OpenAI
export MNEMO_EMBED_MODEL=""           # default: text-embedding-3-small
export MNEMO_EMBED_DIMS=""            # default: 1536
```

#### Option B: Server Mode (mnemo-server)

Connect to a self-hosted mnemo-server. Supports multi-agent collaboration with space isolation.

```bash
export MNEMO_API_URL="http://your-server:8080"
export MNEMO_API_TOKEN="mnemo_your_token_here"
```

The plugin auto-detects the mode:
- `MNEMO_DB_HOST` set → **Direct mode**
- `MNEMO_API_URL` set → **Server mode**

### Verify

Start OpenCode in your project. You should see one of these log lines:

```
[mnemo] Direct mode (TiDB Starter HTTP Data API)
[mnemo] Server mode (mnemo-server REST API)
```

If you see `[mnemo] No mode configured...`, check your env vars.

## Environment Variables Reference

| Variable | Required | Default | Description |
|---|---|---|---|
| `MNEMO_DB_HOST` | Yes (direct) | — | TiDB Starter host |
| `MNEMO_DB_USER` | Yes (direct) | — | TiDB username |
| `MNEMO_DB_PASS` | Yes (direct) | — | TiDB password |
| `MNEMO_DB_NAME` | No | `mnemos` | Database name |
| `MNEMO_API_URL` | Yes (server) | — | mnemo-server base URL |
| `MNEMO_API_TOKEN` | Yes (server) | — | API token for server mode |
| `MNEMO_EMBED_API_KEY` | No | — | Embedding API key (enables hybrid search) |
| `MNEMO_EMBED_BASE_URL` | No | OpenAI | Custom embedding endpoint |
| `MNEMO_EMBED_MODEL` | No | `text-embedding-3-small` | Embedding model name |
| `MNEMO_EMBED_DIMS` | No | `1536` | Vector dimensions |

## File Structure

```
opencode-plugin/
├── README.md              # This file
├── package.json           # npm package config
├── tsconfig.json          # TypeScript config
└── src/
    ├── index.ts           # Plugin entry point (mode detection, wiring)
    ├── types.ts           # Config loading, Memory types
    ├── backend.ts         # MemoryBackend interface
    ├── direct-backend.ts  # Direct mode: TiDB HTTP Data API
    ├── server-backend.ts  # Server mode: mnemo-server REST API
    ├── tools.ts           # 5 memory tools (store/search/get/update/delete)
    └── hooks.ts           # system.transform + session.idle hooks
```

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| `No mode configured` | Missing env vars | Set `MNEMO_DB_HOST` (direct) or `MNEMO_API_URL` (server) |
| `Direct mode requires...` | Missing DB credentials | Set `MNEMO_DB_USER` and `MNEMO_DB_PASS` |
| `Server mode requires...` | Missing API token | Set `MNEMO_API_TOKEN` |
| Plugin not loading | Not registered in OpenCode config | Add to `opencode.json` plugins section |
| Keyword-only search | No embedding key | Set `MNEMO_EMBED_API_KEY` for hybrid search |
