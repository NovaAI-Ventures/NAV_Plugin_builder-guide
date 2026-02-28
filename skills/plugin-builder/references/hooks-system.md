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

## Standard Setup Script Template

This is the pattern used by all MCP HTTP plugins:

```bash
#!/usr/bin/env bash
# Setup hook — checks required environment variables

PLUGIN_NAME="your-plugin"
MISSING=()

# Check each required env var
[ -z "${VAR_ONE:-}" ] && MISSING+=("VAR_ONE")
[ -z "${VAR_TWO:-}" ] && MISSING+=("VAR_TWO")

if [ ${#MISSING[@]} -gt 0 ]; then
  VARS_LIST=""
  for v in "${MISSING[@]}"; do
    VARS_LIST="${VARS_LIST}  ${v}=your_value_here\n"
  done
  echo "{\"status\":\"success\",\"systemMessage\":\"[$PLUGIN_NAME] needs these env vars in .env.local:\\n${VARS_LIST}See .env.example for details.\"}"
else
  echo "{\"status\":\"success\",\"systemMessage\":\"[$PLUGIN_NAME]: All credentials configured.\"}"
fi
```

**Critical details:**
- Use `${VAR:-}` (with `:-`) to avoid unbound variable errors
- Always output JSON, even on error — never output plain text
- The script must be executable: `chmod +x scripts/setup.sh`
- Use `${CLAUDE_PLUGIN_ROOT}` in hooks.json, not relative paths

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
