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

## Phase 1: Reading Credentials from .env.local

**Problem:** Each Setup hook runs as a separate shell process. Environment variables are not inherited from the credential-loader or other hooks. The setup.sh must read `.env.local` directly to get credential values.

**Why this matters:** `${VAR}` placeholders in `.mcp.json` HTTP headers are NOT resolved at MCP connection time. The setup.sh must read actual credential values and write them as hardcoded strings into `.mcp.json`.

### The Safe Parser Pattern

This block reads `.env.local` and `.env` safely, exporting KEY=VALUE pairs:

```bash
# --- Phase 1: Read existing credentials from .env.local ---
for _envfile in "$ENV_LOCAL" .env; do
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

The loop iterates `.env.local` first, then `.env`. Since `export` overwrites, if both files define the same key, `.env` wins.

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

This is the full 4-phase pattern used by all MCP HTTP plugins. It reads `.env.local`, writes **resolved values** (not `${VAR}` placeholders) into `.mcp.json`, creates `.env.local` placeholders for missing keys, and reports status.

**IMPORTANT:** `${VAR}` placeholders in `.mcp.json` HTTP headers are NOT resolved at MCP connection time. Headers must contain hardcoded credential values. setup.sh reads `.env.local` and writes the actual values.

```bash
#!/usr/bin/env bash
# Setup hook — writes resolved credentials to .mcp.json, ensures .env.local has placeholders

PLUGIN_NAME="your-plugin"
MCP_JSON=".mcp.json"
ENV_LOCAL=".env.local"
MCP_URL="https://your-plugin.mcp.majewscy.tech/"
BANNER_TITLE="Y O U R   P L U G I N"

# Credential variable names
_ALL_VARS=("YOUR_MCP_API_KEY" "YOUR_OTHER_KEY")

# --- Phase 1: Read existing credentials from .env.local ---
for _envfile in "$ENV_LOCAL" .env; do
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

# --- Phase 2: Write .mcp.json with resolved values ---
# Uses actual credential values from .env.local, or empty string if missing
python3 -c "
import json, os
from pathlib import Path

mcp_file = Path('$MCP_JSON')
if mcp_file.exists():
    with open(mcp_file) as f:
        data = json.load(f)
else:
    data = {'mcpServers': {}}

data.setdefault('mcpServers', {})['$PLUGIN_NAME'] = {
    'type': 'http',
    'url': '$MCP_URL',
    'headers': {
        'x-api-key': os.environ.get('YOUR_MCP_API_KEY', ''),
        'x-your-other-key': os.environ.get('YOUR_OTHER_KEY', ''),
    }
}

with open(mcp_file, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')
" 2>/dev/null

# --- Phase 3: Ensure .env.local has all required keys ---
for _var in "${_ALL_VARS[@]}"; do
  if [ ! -f "$ENV_LOCAL" ] || ! grep -q "^${_var}=" "$ENV_LOCAL" 2>/dev/null; then
    if [ ! -f "$ENV_LOCAL" ]; then
      echo "# === ${PLUGIN_NAME} ===" > "$ENV_LOCAL"
    fi
    echo "${_var}=" >> "$ENV_LOCAL"
  fi
done

# --- Phase 4: Status banner ---
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
MSG="${MSG}  │              ${BANNER_TITLE}         │\\n"
MSG="${MSG}  ╰──────────────────────────────────────────────╯\\n"
MSG="${MSG}\\n"
MSG="${MSG}    ✔  MCP server configured\\n"

for _var in "${_SET[@]}"; do
  MSG="${MSG}    ✔  ${_var}\\n"
done
for _var in "${_MISSING[@]}"; do
  MSG="${MSG}    ✗  ${_var}  ← empty\\n"
done

if [ ${#_MISSING[@]} -gt 0 ]; then
  MSG="${MSG}\\n"
  MSG="${MSG}  ┄┄ Setup ┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄\\n"
  MSG="${MSG}\\n"
  MSG="${MSG}    1. Get your API key from ...\\n"
  MSG="${MSG}    2. Get MCP API key from your MCP proxy admin\\n"
  MSG="${MSG}    Fill in .env.local in project root:\\n"
  for _var in "${_MISSING[@]}"; do
    MSG="${MSG}         ${_var}=your_value_here\\n"
  done
  MSG="${MSG}    Then restart Claude Code\\n"
fi

echo "{\"status\":\"success\",\"systemMessage\":\"${MSG}\"}"
```

**Critical details:**
- **NEVER use `${VAR}` in `.mcp.json` headers** — they are NOT resolved at MCP connection time
- Phase 2 uses `os.environ.get()` to read values exported by Phase 1, writing actual values (or `""`) into `.mcp.json`
- Phase 3 only appends missing keys to `.env.local` — never overwrites existing values
- Use `${!_var}` (bash indirect expansion) to check variables dynamically in Phase 4
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

## Automatic MCP Registration (credential-loader Phase 3)

As of credential-loader v1.0.2, **plugins no longer need setup.sh to register MCP servers**. The credential-loader automatically handles this at session start.

### How It Works

At every session start, after Phase 1 (env loading) and Phase 2 (credential checking), the credential-loader runs **Phase 3**:

1. Reads `installed_plugins.json` to find all installed plugins
2. For each plugin, reads `.claude-plugin/plugin.json`
3. If `mcpServers` is defined, checks each server name against `.mcp.json`
4. If a server is **not** already in `.mcp.json`, adds it (preserving existing entries)
5. Skips servers that are already present (idempotent)

### What This Means for Plugin Authors

**3rd-party plugins** (like `chrome-devtools` from `ChromeDevTools/chrome-devtools-mcp`):
- Just need `mcpServers` in their `plugin.json` — no setup.sh, no hooks.json needed
- Auto-registered at session start by credential-loader
- Works with both HTTP and subprocess transport types

**NAV plugins** (with setup.sh):
- setup.sh still runs first and writes its own `.mcp.json` entries
- Phase 3 sees the entry already exists and skips it — no conflict
- setup.sh is still recommended for: credential validation banners, custom setup logic

### Priority Order

```
Session Start
    │
    ├─ 1. Plugin setup.sh hooks fire (for plugins that have them)
    │     → May write MCP entries to .mcp.json
    │
    ├─ 2. credential-loader Phase 1: Load .env files
    │
    ├─ 3. credential-loader Phase 2: Check missing credentials
    │
    └─ 4. credential-loader Phase 3: Auto-register remaining mcpServers
          → Only adds entries NOT already in .mcp.json
          → Catches plugins without setup.sh
```

### When setup.sh Is Still Needed

| Use Case | setup.sh Required? |
|----------|-------------------|
| Basic MCP registration | No (Phase 3 handles it) |
| Credential validation with status banner | Yes |
| Custom dependency checks | Yes |
| Post-install configuration | Yes |
| 3rd-party plugin with no credentials | No |
