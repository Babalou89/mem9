#!/usr/bin/env bash
# llama-mem9.sh — llama.cpp wrapper with mem9 memory injection.
#
# Supports two modes:
#   cli    — wraps llama-cli with --system-prompt containing memories
#   server — starts llama-server; use llama-mem9-query.sh for API calls
#
# Usage:
#   llama-mem9.sh cli   -m /path/to/model.gguf [extra llama-cli args]
#   llama-mem9.sh server -m /path/to/model.gguf [extra llama-server args]
#   llama-mem9.sh fetch  — just print the current mem9 context block

set -euo pipefail

MEM9_API_URL="${MEM9_API_URL:-https://api.mem9.ai}"
MEM9_TENANT_ID="${MEM9_TENANT_ID:-c1a5fed9-4ae0-4338-8879-d1d786deee67}"
MEM9_LIMIT="${MEM9_LIMIT:-20}"

fetch_memories() {
  curl -sf --max-time 8 \
    -H "Content-Type: application/json" \
    "${MEM9_API_URL}/v1alpha1/mem9s/${MEM9_TENANT_ID}/memories?limit=${MEM9_LIMIT}" \
  | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    mems = data.get('memories', [])
    if not mems:
        sys.exit(0)
    lines = ['[mem9] Shared team memories:','']
    for m in mems:
        age = m.get('relative_age','')
        content = m.get('content','')[:400]
        tags = ', '.join(m.get('tags') or [])
        prefix = f'({age}) ' if age else ''
        lines.append(f'- {prefix}{content}')
    print('\n'.join(lines))
except Exception:
    pass
" 2>/dev/null || echo ""
}

save_memory() {
  local content="$1"
  local project
  project=$(basename "$(pwd)")
  local body
  body=$(python3 -c "
import json, sys
payload = {'content': sys.argv[1], 'tags': ['auto-captured', sys.argv[2]]}
print(json.dumps(payload))
" "$content" "$project" 2>/dev/null)
  curl -sf --max-time 8 \
    -H "Content-Type: application/json" \
    -d "$body" \
    "${MEM9_API_URL}/v1alpha1/mem9s/${MEM9_TENANT_ID}/memories" >/dev/null 2>&1 || true
}

MODE="${1:-}"
shift || true

case "$MODE" in
  fetch)
    fetch_memories
    ;;

  cli)
    MEMORIES=$(fetch_memories)
    BASE_PROMPT="You are a helpful AI assistant."
    if [[ -n "$MEMORIES" ]]; then
      SYSTEM_PROMPT="${BASE_PROMPT}

${MEMORIES}"
    else
      SYSTEM_PROMPT="$BASE_PROMPT"
    fi
    exec llama-cli --system-prompt "$SYSTEM_PROMPT" "$@"
    ;;

  server)
    echo "==> Fetching mem9 memories for system prompt..."
    MEMORIES=$(fetch_memories)
    BASE_PROMPT="You are a helpful AI assistant."
    if [[ -n "$MEMORIES" ]]; then
      SYSTEM_PROMPT="${BASE_PROMPT}

${MEMORIES}"
      echo "==> Injected $(echo "$MEMORIES" | wc -l) lines of memory context."
    else
      SYSTEM_PROMPT="$BASE_PROMPT"
      echo "==> No memories found, starting with base prompt."
    fi
    # Write system prompt to temp file for llama-server
    TMPFILE=$(mktemp /tmp/llama-sys-XXXXXX.txt)
    echo "$SYSTEM_PROMPT" > "$TMPFILE"
    trap 'rm -f $TMPFILE' EXIT
    exec llama-server --system-prompt-file "$TMPFILE" "$@"
    ;;

  save)
    # Save a memory manually: llama-mem9.sh save "content to remember"
    CONTENT="${1:-}"
    if [[ -z "$CONTENT" ]]; then
      echo "Usage: llama-mem9.sh save \"content to remember\""
      exit 1
    fi
    save_memory "$CONTENT"
    echo "==> Saved to mem9."
    ;;

  *)
    echo "Usage: llama-mem9.sh <fetch|cli|server|save> [args...]"
    echo ""
    echo "  fetch              — print current mem9 memories"
    echo "  cli   -m model.gguf [args] — run llama-cli with memory injection"
    echo "  server -m model.gguf [args] — run llama-server with memory injection"
    echo "  save \"text\"        — save a memory manually"
    echo ""
    echo "Env vars: MEM9_TENANT_ID, MEM9_API_URL, MEM9_LIMIT"
    exit 1
    ;;
esac
