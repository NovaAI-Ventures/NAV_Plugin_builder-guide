#!/usr/bin/env bash
# Setup hook — adds MCP server to .mcp.json and checks credentials

PLUGIN_NAME="PLUGIN_NAME"
MCP_JSON=".mcp.json"

# --- Phase 1: Ensure MCP server entry exists in .mcp.json ---
if [ -f "$MCP_JSON" ]; then
  HAS_ENTRY=$(python3 -c "
import json
try:
    with open('$MCP_JSON') as f:
        data = json.load(f)
    print('yes' if '$PLUGIN_NAME' in data.get('mcpServers', {}) else 'no')
except Exception:
    print('no')
" 2>/dev/null)
else
  HAS_ENTRY="no"
fi

if [ "$HAS_ENTRY" = "no" ]; then
  python3 -c "
import json
from pathlib import Path

mcp_file = Path('$MCP_JSON')
if mcp_file.exists():
    with open(mcp_file) as f:
        data = json.load(f)
else:
    data = {'mcpServers': {}}

data.setdefault('mcpServers', {})['$PLUGIN_NAME'] = {
    'type': 'http',
    'url': 'https://PLUGIN_NAME.mcp.nova-labs.ai/',
    'headers': {
        'x-api-key': '\${PLUGIN_NAME_UPPER_MCP_API_KEY}'
    }
}

with open(mcp_file, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
" 2>/dev/null
fi

# --- Phase 1.5: Load credentials into this shell ---
# Hooks run in separate processes, so vars written to $CLAUDE_ENV_FILE
# by credential-loader aren't in our environment yet. Source them.
for _envfile in .env.local .env; do
  if [ -f "$_envfile" ]; then
    while IFS= read -r _line; do
      case "$_line" in '#'*|'') continue;; esac
      case "$_line" in *=*) ;; *) continue;; esac
      _key="${_line%%=*}"
      case "$_key" in *[!A-Za-z0-9_]*) continue;; esac
      [ -z "$_key" ] && continue
      export "$_line"
    done < "$_envfile"
  fi
done

# --- Phase 2: Check required credentials and report status ---
# CUSTOMISE: Replace with your plugin's required env vars
_ALL_VARS=("PLUGIN_NAME_UPPER_MCP_API_KEY")
_MISSING=()
_SET=()
for _var in "${_ALL_VARS[@]}"; do
  _val="${!_var}"
  if [ -z "$_val" ]; then
    _MISSING+=("$_var")
  else
    _SET+=("$_var")
  fi
done

# CUSTOMISE: Replace PLUGIN_TITLE with spaced-out plugin name
MSG="\\n"
MSG="${MSG}  ╭──────────────────────────────────────────────╮\\n"
MSG="${MSG}  │         P L U G I N   T I T L E              │\\n"
MSG="${MSG}  ╰──────────────────────────────────────────────╯\\n"
MSG="${MSG}\\n"
MSG="${MSG}    ✔  MCP server configured\\n"

for _var in "${_SET[@]}"; do
  MSG="${MSG}    ✔  ${_var}\\n"
done
for _var in "${_MISSING[@]}"; do
  MSG="${MSG}    ✗  ${_var}  ← missing\\n"
done

if [ ${#_MISSING[@]} -gt 0 ]; then
  MSG="${MSG}\\n"
  MSG="${MSG}  ┄┄ Setup ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄\\n"
  MSG="${MSG}\\n"
  # CUSTOMISE: Replace with your plugin's setup steps
  MSG="${MSG}    1. Get MCP API key from your MCP proxy admin\\n"
  MSG="${MSG}    2. Add to .env.local in project root:\\n"
  for _var in "${_MISSING[@]}"; do
    MSG="${MSG}         ${_var}=your_value_here\\n"
  done
  MSG="${MSG}    3. Restart Claude Code\\n"
fi

echo "{\"status\":\"success\",\"systemMessage\":\"${MSG}\"}"
