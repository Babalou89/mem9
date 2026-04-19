#!/usr/bin/env python3
"""
mem9-mcp-server.py — Minimal MCP stdio server exposing mem9 memory tools.
Used by Kimi Code CLI (and any other MCP-compatible agent) via --mcp-config-file.

Tools exposed:
  get_memories(limit)        — fetch recent shared memories
  save_memory(content, tags) — store a memory in the shared pool
  search_memories(query)     — search memories by keyword/semantic
"""
import json
import os
import sys
import urllib.request
import urllib.parse

MEM9_API_URL   = os.environ.get("MEM9_API_URL", "https://api.mem9.ai")
MEM9_TENANT_ID = os.environ.get("MEM9_TENANT_ID", "")
BASE_URL       = f"{MEM9_API_URL}/v1alpha1/mem9s/{MEM9_TENANT_ID}"

TOOLS = [
    {
        "name": "get_memories",
        "description": "Fetch recent shared team memories from mem9. Call this at the start of a session to load context.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "limit": {"type": "integer", "description": "Max memories to fetch (default 20)", "default": 20}
            }
        }
    },
    {
        "name": "save_memory",
        "description": "Save something important to the shared mem9 memory pool so all agents on all machines can access it.",
        "inputSchema": {
            "type": "object",
            "required": ["content"],
            "properties": {
                "content": {"type": "string", "description": "The memory content to save"},
                "tags":    {"type": "array", "items": {"type": "string"}, "description": "Optional tags"}
            }
        }
    },
    {
        "name": "search_memories",
        "description": "Search shared team memories by keyword or semantic query.",
        "inputSchema": {
            "type": "object",
            "required": ["query"],
            "properties": {
                "query": {"type": "string", "description": "Search query"},
                "limit": {"type": "integer", "description": "Max results (default 10)", "default": 10}
            }
        }
    }
]


def http_get(path):
    url = f"{BASE_URL}{path}"
    req = urllib.request.Request(url, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.load(r)


def http_post(path, body):
    url = f"{BASE_URL}{path}"
    data = json.dumps(body).encode()
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=10) as r:
        return json.load(r)


def format_memories(memories):
    if not memories:
        return "No memories found."
    lines = []
    for m in memories:
        age     = m.get("relative_age", "")
        content = m.get("content", "")[:500]
        tags    = ", ".join(m.get("tags") or [])
        prefix  = f"({age}) " if age else ""
        tag_str = f" [{tags}]" if tags else ""
        lines.append(f"- {prefix}{content}{tag_str}")
    return "\n".join(lines)


def handle_tool(name, args):
    if not MEM9_TENANT_ID:
        return {"error": "MEM9_TENANT_ID not set"}

    if name == "get_memories":
        limit = args.get("limit", 20)
        data  = http_get(f"/memories?limit={limit}")
        text  = format_memories(data.get("memories", []))
        return {"content": [{"type": "text", "text": text}]}

    elif name == "save_memory":
        content = args.get("content", "")
        tags    = args.get("tags", ["kimi", "babalou"])
        if "kimi" not in tags:
            tags = ["kimi"] + tags
        http_post("/memories", {"content": content, "tags": tags})
        return {"content": [{"type": "text", "text": "Memory saved to shared pool."}]}

    elif name == "search_memories":
        query  = urllib.parse.quote(args.get("query", ""))
        limit  = args.get("limit", 10)
        data   = http_get(f"/memories?q={query}&limit={limit}")
        text   = format_memories(data.get("memories", []))
        return {"content": [{"type": "text", "text": text}]}

    else:
        return {"error": f"Unknown tool: {name}"}


def send(obj):
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


def main():
    for raw_line in sys.stdin:
        raw_line = raw_line.strip()
        if not raw_line:
            continue
        try:
            msg = json.loads(raw_line)
        except json.JSONDecodeError:
            continue

        method = msg.get("method", "")
        msg_id = msg.get("id")
        params = msg.get("params", {})

        if method == "initialize":
            send({"jsonrpc": "2.0", "id": msg_id, "result": {
                "protocolVersion": "2024-11-05",
                "serverInfo": {"name": "mem9", "version": "1.0.0"},
                "capabilities": {"tools": {}}
            }})

        elif method == "tools/list":
            send({"jsonrpc": "2.0", "id": msg_id, "result": {"tools": TOOLS}})

        elif method == "tools/call":
            tool_name = params.get("name", "")
            tool_args = params.get("arguments", {})
            try:
                result = handle_tool(tool_name, tool_args)
            except Exception as e:
                result = {"content": [{"type": "text", "text": f"Error: {e}"}], "isError": True}
            send({"jsonrpc": "2.0", "id": msg_id, "result": result})

        elif method == "notifications/initialized":
            pass  # no response needed

        else:
            if msg_id is not None:
                send({"jsonrpc": "2.0", "id": msg_id, "error": {"code": -32601, "message": "Method not found"}})


if __name__ == "__main__":
    main()
