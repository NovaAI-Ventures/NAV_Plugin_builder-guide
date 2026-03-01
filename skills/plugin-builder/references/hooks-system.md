# Hooks System Reference

Hooks run shell commands at specific plugin lifecycle events.

## Hook Events

| Event | When It Fires | Use Case |
|-------|---------------|----------|
| `Setup` | Once, when the plugin is installed or updated | Validate credentials, check dependencies |
| `SessionStart` | Every time a Claude Code session starts | Load env vars, refresh tokens |

### Setup Hook (Most Common)

Used by all MCP HTTP plugins to validate that required environment variables are configured.

```json
{
  "hooks": {
    "Setup": [
      {
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/scripts/setup.sh"
      }
    ]
  }
}
```

### SessionStart Hook

Used by the credential-loader plugin to load `.env.local` files at session start.

```json
{
  "hooks": {
    "SessionStart": [
      {
        "type": "command",
        "command": "${CLAUDE_PLUGIN_ROOT}/scripts/load-env.sh"
      }
    ]
  }
}
```

**Important:** Most plugins should use `Setup`, not `SessionStart`. Only the credential-loader plugin needs `SessionStart`.

## hooks.json Format

Location: `hooks/hooks.json` (referenced from plugin.json as `"hooks": "./hooks/hooks.json"`)

```json
{
  "hooks": {
    "EVENT_NAME": [
      {
        "type": "command",
        "command": "COMMAND_STRING"
      }
    ]
  }
}
```

| Field | Description |
|-------|-------------|
| `hooks` | Top-level wrapper object. |
| `EVENT_NAME` | One of: `Setup`, `SessionStart`. |
| `type` | Always `"command"`. |
| `command` | Shell command to execute. Use `${CLAUDE_PLUGIN_ROOT}` for plugin-relative paths. |

Multiple hooks can be registered for the same event:

```json
{
  "hooks": {
    "Setup": [
      { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/check-deps.sh" },
      { "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/scripts/validate-creds.sh" }
    ]
  }
}
```

## Hook Script Output

Hook scripts MUST output valid JSON to stdout. This is how they communicate with Claude Code.

### Success Response

```json
{"status": "success", "systemMessage": "Message shown to Claude as system context"}
```

### Output Fields

| Field | Required | Description |
|-------|----------|-------------|
| `status` | Yes | Must be `"success"`. Other values may cause the hook to be treated as failed. |
| `systemMessage` | Yes | Message injected into Claude's system context. Used to inform Claude about plugin state. |

### Newlines in systemMessage

Use `\n` for newlines in the JSON string:

```json
{"status":"success","systemMessage":"[plugin] needs these env vars:\n  VAR_ONE=value\n  VAR_TWO=value\nSee .env.example."}
```

## Phase 1.5: Self-Sourcing Credentials

**Problem:** Each Setup hook runs as a separate shell process. The credential-loader writes variables to `$CLAUDE_ENV_FILE`, but those are only loaded into Claude Code's environment *after all hooks finish*. A Setup hook that checks `${MY_VAR:-}` will see an empty value even though the key exists in `.env.local`.

**Solution:** Before checking credentials, source `.env.local` and `.env` directly in the hook script. This is called **Phase 1.5** because it sits between Phase 1 (MCP config) and Phase 2 (credential check).

### The Pattern

Add this block before any `${VAR:-}` checks:

```bash
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
```

### Why Not Just `source .env.local`?

The `source` command executes the file as a shell script, which means:
- Lines with special characters (spaces, quotes, `$`) can cause syntax errors or code execution
- Comment styles may differ from shell syntax
- It's a security risk if the file contains anything unexpected

The safe parser above only exports lines that match `KEY=VALUE` where `KEY` is a valid identifier (`[A-Za-z0-9_]`). It skips comments, blank lines, and malformed entries.

### Priority Order

The loop iterates `.env.local` first, then `.env`. Since `export` overwrites, if both files define the same key, `.env` wins. This matches the credential-loader's priority where project-wide `.env` can override skill-local values.

## Visual Status Output

Plugin setup hooks should output a visually formatted status card instead of plain text. This makes it easy to scan which credentials are set vs missing.

### The Pattern

Use bash indirect expansion (`${!_var}`) to loop over required vars and build a visual message:

```bash
# --- Phase 2: Check required credentials and report status ---
_ALL_VARS=("MY_API_KEY" "MY_SECRET")
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
  MSG="${MSG}    1. Get your API key from ...\\n"
  MSG="${MSG}    2. Add to .env.local in project root:\\n"
  for _var in "${_MISSING[@]}"; do
    MSG="${MSG}         ${_var}=your_value_here\\n"
  done
  MSG="${MSG}    3. Restart Claude Code\\n"
fi

echo "{\"status\":\"success\",\"systemMessage\":\"${MSG}\"}"
```

### Output Examples

**All credentials set:**
```
  ╭──────────────────────────────────────────────╮
  │              A P I F Y   P L U G I N         │
  ╰──────────────────────────────────────────────╯

    ✔  MCP server configured
    ✔  APIFY_MCP_API_KEY
    ✔  APIFY_TOKEN
```

**Credentials missing:**
```
  ╭──────────────────────────────────────────────╮
  │              A P I F Y   P L U G I N         │
  ╰──────────────────────────────────────────────╯

    ✔  MCP server configured
    ✗  APIFY_MCP_API_KEY  ← missing
    ✗  APIFY_TOKEN  ← missing

  ┄┄ Setup ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄

    1. Get Apify token from:
       https://console.apify.com/account/integrations
    2. Get MCP API key from your MCP proxy admin
    3. Add to .env.local in project root:
         APIFY_MCP_API_KEY=your_value_here
         APIFY_TOKEN=your_value_here
    4. Restart Claude Code
```

### Visual Elements Reference

| Character | Usage |
|-----------|-------|
| `╭╮╰╯─│` | Rounded box for plugin title banner |
| `┄` | Dotted line for section dividers |
| `✔` | Credential loaded successfully |
| `✗` | Credential missing |
| `←` | Arrow pointing to status annotation |

### Title Banner Convention

Use spaced uppercase letters for the plugin name inside the banner:
- `A P I F Y` (not `APIFY`)
- `G M A I L` (not `GMAIL`)
- `H O M E   A S S I S T A N T` (not `HOME ASSISTANT`)

This gives a distinctive "logo" feel to each plugin's output.

## Standard Setup Script (Complete Template)

This is the full pattern used by all MCP HTTP plugins. It combines all three phases:

```bash
#!/usr/bin/env bash
# Setup hook — adds MCP server to .mcp.json and checks credentials

PLUGIN_NAME="your-plugin"
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
    'url': 'https://$PLUGIN_NAME.mcp.nova-labs.ai/',
    'headers': {
        'x-api-key': '\${YOUR_MCP_API_KEY}'
    }
}

with open(mcp_file, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
" 2>/dev/null
fi

# --- Phase 1.5: Load credentials into this shell ---
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
_ALL_VARS=("YOUR_MCP_API_KEY")
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

MSG="\\n"
MSG="${MSG}  ╭──────────────────────────────────────────────╮\\n"
MSG="${MSG}  │         Y O U R   P L U G I N                │\\n"
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
  MSG="${MSG}    1. Get your API key from ...\\n"
  MSG="${MSG}    2. Get MCP API key from your MCP proxy admin\\n"
  MSG="${MSG}    3. Add to .env.local in project root:\\n"
  for _var in "${_MISSING[@]}"; do
    MSG="${MSG}         ${_var}=your_value_here\\n"
  done
  MSG="${MSG}    4. Restart Claude Code\\n"
fi

echo "{\"status\":\"success\",\"systemMessage\":\"${MSG}\"}"
```

**Critical details:**
- Use `${!_var}` (bash indirect expansion) to check variables dynamically
- Always include Phase 1.5 to source `.env.local` before checking credentials
- Use `${VAR:-}` syntax if checking variables directly (without the loop pattern)
- Always output JSON, even on error — never output plain text
- The script must be executable: `chmod +x scripts/setup.sh`
- Use `${CLAUDE_PLUGIN_ROOT}` in hooks.json, not relative paths
- Prefix internal variables with `_` (e.g., `_MISSING`, `_SET`, `_var`) to avoid conflicts

## File Structure

```
plugin-root/
  .claude-plugin/
    plugin.json          <-- "hooks": "./hooks/hooks.json"
  hooks/
    hooks.json           <-- event -> command mapping
  scripts/
    setup.sh             <-- actual script
```

The `hooks.json` references the script. The `plugin.json` references `hooks.json`. This indirection allows multiple hooks per event and keeps the manifest clean.
