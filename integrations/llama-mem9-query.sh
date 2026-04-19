#!/usr/bin/env bash
# llama-mem9-query.sh — Send a chat query to a running llama-server with mem9 memories
#                        injected as the system message.
#
# Requires: llama-server already running (default: http://localhost:8080)
# Usage: llama-mem9-query.sh "your question here"
#        LLAMA_URL=http://localhost:8081 llama-mem9-query.sh "question"

set -euo pipefail

MEM9_API_URL="${MEM9_API_URL:-https://api.mem9.ai}"
MEM9_TENANT_ID="${MEM9_TENANT_ID:-c1a5fed9-4ae0-4338-8879-d1d786deee67}"
LLAMA_URL="${LLAMA_URL:-http://localhost:8080}"
USER_MSG="${1:-}"

if [[ -z "$USER_MSG" ]]; then
  echo "Usage: llama-mem9-query.sh \"your question\""
  exit 1
fi

MEMORIES=$(curl -sf --max-time 8 \
  "${MEM9_API_URL}/v1alpha1/mem9s/${MEM9_TENANT_ID}/memories?limit=20" \
  | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    mems = data.get('memories', [])
    lines = []
    for m in mems:
        age = m.get('relative_age','')
        content = m.get('content','')[:400]
        prefix = f'({age}) ' if age else ''
        lines.append(f'- {prefix}{content}')
    print('\n'.join(lines))
except Exception:
    pass
" 2>/dev/null || echo "")

SYSTEM_MSG="You are a helpful AI assistant."
if [[ -n "$MEMORIES" ]]; then
  SYSTEM_MSG="${SYSTEM_MSG}

[mem9] Shared team memories:
${MEMORIES}"
fi

python3 - <<PYEOF
import json, urllib.request, sys

url = "${LLAMA_URL}/v1/chat/completions"
system_msg = """${SYSTEM_MSG}"""
user_msg = """${USER_MSG}"""

payload = {
    "model": "local",
    "messages": [
        {"role": "system", "content": system_msg},
        {"role": "user",   "content": user_msg}
    ],
    "stream": False
}

req = urllib.request.Request(
    url,
    data=json.dumps(payload).encode(),
    headers={"Content-Type": "application/json"}
)
try:
    with urllib.request.urlopen(req, timeout=120) as resp:
        data = json.load(resp)
        print(data["choices"][0]["message"]["content"])
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
