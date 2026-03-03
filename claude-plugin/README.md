# Claude Plugin for mnemos

Persistent memory for Claude Code — auto-loads memories on session start, auto-saves on stop, with on-demand store/recall skills.

## How It Works

```
Session Start → Load recent memories into context
     ↓
User Prompt  → Hint: memory-store / memory-recall available
     ↓
Session Stop → Capture last response → save to database
```

Three lifecycle hooks + two skills:

| Component | Trigger | What it does |
|---|---|---|
| `session-start.sh` | Session begins | Loads recent memories into `additionalContext` |
| `user-prompt-submit.sh` | Each prompt | Injects system hint about available memory skills |
| `stop.sh` | Session ends | Saves last assistant response as a new memory |
| `memory-store` skill | On demand | User says "remember this" → saves explicitly |
| `memory-recall` skill | On demand | User says "what do we know about X" → searches memories |

## Prerequisites

- Claude Code installed
- **One** of the following backends:
  - A [TiDB Cloud Serverless](https://tidbcloud.com) cluster (free tier) — **Direct mode** (default, recommended)
  - A running [mnemo-server](../server/) instance — **Server mode** (for teams / multi-agent setups)

## Installation

### 1. Clone this repo

```bash
git clone https://github.com/qiffang/mnemos.git
cd mnemos
```

Note the absolute path to `claude-plugin/`:
```bash
PLUGIN_DIR="$(pwd)/claude-plugin"
```

### 2. Make hooks executable

```bash
chmod +x "$PLUGIN_DIR"/hooks/*.sh
```

### 3. Copy skills to Claude

```bash
mkdir -p ~/.claude/skills
cp -r "$PLUGIN_DIR/skills/memory-recall" ~/.claude/skills/memory-recall
cp -r "$PLUGIN_DIR/skills/memory-store" ~/.claude/skills/memory-store
```

### 4. Configure `~/.claude/settings.json`

Add the `env` and `hooks` sections (merge with existing config if needed).

#### Option A: Direct Mode (default — TiDB Serverless)

Connect directly to TiDB Cloud. No server deployment needed.

```json
{
  "env": {
    "MNEMO_DB_HOST": "<your-tidb-host>",
    "MNEMO_DB_USER": "<your-tidb-username>",
    "MNEMO_DB_PASS": "<your-tidb-password>",
    "MNEMO_DB_NAME": "mnemos",
    "MNEMO_DB_PORT": "4000"
  },
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "<PLUGIN_DIR>/hooks/session-start.sh"
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "<PLUGIN_DIR>/hooks/user-prompt-submit.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "<PLUGIN_DIR>/hooks/stop.sh",
            "timeout": 120
          }
        ]
      }
    ]
  }
}
```

#### Option B: Server Mode (mnemo-server)

Connect to a self-hosted mnemo-server. Supports multi-agent collaboration with space isolation.

```json
{
  "env": {
    "MNEMO_API_URL": "http://your-server:8080",
    "MNEMO_API_TOKEN": "mnemo_your_token_here"
  },
  "hooks": { ... }
}
```

The `hooks` section is identical — only the `env` variables differ. The plugin auto-detects the mode:
- `MNEMO_DB_HOST` set → **Direct mode**
- `MNEMO_API_URL` set → **Server mode**

Replace `<PLUGIN_DIR>` with the actual absolute path (e.g. `/home/you/mnemos/claude-plugin`).

> **Important**: Do NOT use `enabledPlugins` or modify `known_marketplaces.json`. Hooks go directly in `settings.json`.

### 5. Create the database (Direct mode only)

The hooks auto-create the table on first run, but you can also do it manually:

```bash
curl -sf --max-time 10 \
  -u "<USER>:<PASS>" \
  -H "Content-Type: application/json" \
  -d '{"database":"test","query":"CREATE DATABASE IF NOT EXISTS mnemos"}' \
  "https://http-<HOST>/v1beta/sql"
```

> **Note**: The TiDB Serverless HTTP API ignores the `database` field. All SQL in the hooks uses fully-qualified table names (`mnemos.memories`) to work around this.

For **Server mode**, the mnemo-server handles database setup — skip this step.

### 6. Verify

```bash
# Test that Claude Code starts normally
claude -p "say hi"
```

Should respond within 15 seconds. If it hangs, double-check that the hook paths are correct absolute paths.

## Usage

Once installed, memory works automatically:

- **Auto-save**: Every session's last response is saved when the session ends
- **Auto-load**: Recent memories are loaded into context when a new session starts
- **Manual save**: Tell Claude "remember that the deploy key is on server X" → triggers `/memory-store`
- **Manual search**: Ask Claude "what do we know about the auth flow?" → triggers `/memory-recall`

## File Structure

```
claude-plugin/
├── README.md                    # This file
├── .claude-plugin/
│   └── plugin.json              # Plugin metadata
├── hooks/
│   ├── common.sh                # Shared helpers (SQL, HTTP, mode detection)
│   ├── hooks.json               # Hook definitions
│   ├── session-start.sh         # Load memories on start
│   ├── stop.sh                  # Save memory on stop
│   └── user-prompt-submit.sh    # Inject memory hints
└── skills/
    ├── memory-recall/SKILL.md   # On-demand search skill
    └── memory-store/SKILL.md    # On-demand save skill
```

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| Claude hangs on startup | Hook script path wrong or not executable | Check absolute paths in `settings.json`, run `chmod +x` |
| Memories not saving | Stop hook only fires on normal session end | Use `/memory-store` for on-demand saves |
| `database` field ignored | TiDB Serverless HTTP API limitation | Already handled — hooks use `mnemos.memories` (fully-qualified) |
| Plugin system error | Using `enabledPlugins` or marketplace config | Remove those — use `settings.json` hooks only |
