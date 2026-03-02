# MCP Configuration Patterns

How MCP (Model Context Protocol) servers are configured in NovaAI plugins.

## Transport Types

NovaAI plugins use two MCP transport types:

### 1. HTTP Transport (Recommended for External APIs)

All external API integrations go through the `llm.nova-labs.ai` proxy, exposed as HTTP MCP servers at `*.mcp.nova-labs.ai`.

```json
{
  "mcpServers": {
    "service-name": {
      "type": "http",
      "url": "https://service-name.mcp.nova-labs.ai/",
      "headers": {
        "x-api-key": "${SERVICE_NAME_MCP_API_KEY}"
      }
    }
  }
}
```

**How the proxy works:**

```
Claude Code
    |
    | MCP request (with x-api-key header)
    v
*.mcp.nova-labs.ai (MCP HTTP endpoint)
    |
    | Validates x-api-key against management vault
    | Retrieves upstream credentials from vault
    v
llm.nova-labs.ai (proxy layer)
    |
    | Forwards request with real API credentials
    v
External API (Gmail, VEO, Ahrefs, etc.)
```

### 2. Subprocess Transport (For Local Tools)

For tools that run as local processes (no external API):

```json
{
  "mcpServers": {
    "tool-name": {
      "command": "npx",
      "args": ["-y", "@package/mcp-server"],
      "env": {
        "SOME_VAR": "${SOME_VAR}"
      }
    }
  }
}
```

Common commands:
| Command | Use Case | Example |
|---------|----------|---------|
| `npx` | npm packages with MCP server | `npx -y @modelcontextprotocol/server-sequential-thinking` |
| `node` | Custom compiled MCP server | `node ${CLAUDE_PLUGIN_ROOT}/dist/index.js` |
| `mcp-proxy` | SSE-to-stdio bridge | `mcp-proxy --sse-url https://...` |
| `python3` | Python MCP server | `python3 ${CLAUDE_PLUGIN_ROOT}/server.py` |

## Variable Substitution

All `${VAR}` patterns in plugin.json are resolved at runtime.

### System Variables (Always Available)

| Variable | Value |
|----------|-------|
| `${CLAUDE_PLUGIN_ROOT}` | Absolute path to installed plugin directory |
| `${CLAUDE_ENV_FILE}` | Path to Claude's environment injection file |
| `${CLAUDE_PROJECT_DIR}` | Path to current working project |

### User Variables (From .env.local)

Loaded by the `credential-loader` plugin at session start:

```bash
# .env.local (in project root)
GMAIL_MCP_API_KEY=abc123
GMAIL_CLIENT_ID=xyz789
```

These become available as `${GMAIL_MCP_API_KEY}` and `${GMAIL_CLIENT_ID}` in plugin.json.

## Header Patterns

### Gateway Authentication Only

Most plugins need just the MCP gateway key:

```json
"headers": {
  "x-api-key": "${SERVICE_MCP_API_KEY}"
}
```

The proxy retrieves upstream credentials from the Vault automatically.

### Gateway + Upstream Credentials

Some plugins pass upstream credentials as additional headers (when the proxy needs them per-request):

```json
"headers": {
  "x-api-key": "${GMAIL_MCP_API_KEY}",
  "x-gmail-client-id": "${GMAIL_CLIENT_ID}",
  "x-gmail-client-secret": "${GMAIL_CLIENT_SECRET}",
  "x-gmail-refresh-token": "${GMAIL_REFRESH_TOKEN}"
}
```

### Custom Header Naming

Custom headers follow the pattern `x-{service}-{credential-type}`:

| Header | Example |
|--------|---------|
| `x-api-key` | Gateway authentication (always present) |
| `x-{service}-api-key` | Upstream service API key |
| `x-{service}-client-id` | OAuth client ID |
| `x-{service}-client-secret` | OAuth client secret |
| `x-{service}-refresh-token` | OAuth refresh token |

## URL Patterns

| Type | Pattern | Example |
|------|---------|---------|
| MCP endpoint | `https://{name}.mcp.nova-labs.ai/` | `https://gmail.mcp.nova-labs.ai/` |
| Proxy base | `https://llm.nova-labs.ai/` | `https://llm.nova-labs.ai/` |
| Management | `https://management.nova-labs.ai/` | `https://management.nova-labs.ai/tools` |

**Important:** Always include the trailing slash in MCP URLs.

## Multiple MCP Servers

A plugin can expose multiple MCP servers:

```json
{
  "mcpServers": {
    "service-read": {
      "type": "http",
      "url": "https://service-read.mcp.nova-labs.ai/",
      "headers": { "x-api-key": "${SERVICE_MCP_API_KEY}" }
    },
    "service-write": {
      "type": "http",
      "url": "https://service-write.mcp.nova-labs.ai/",
      "headers": { "x-api-key": "${SERVICE_MCP_API_KEY}" }
    }
  }
}
```

This is rare — most plugins expose a single MCP server.

## Full Examples by Plugin Type

### SEO Tool (ahrefs)

```json
{
  "mcpServers": {
    "ahrefs": {
      "type": "http",
      "url": "https://ahrefs.mcp.nova-labs.ai/",
      "headers": {
        "x-api-key": "${AHREFS_MCP_API_KEY}",
        "x-ahrefs-api-key": "${AHREFS_API_KEY}"
      }
    }
  }
}
```

Two keys: gateway + upstream Ahrefs API key.

### Web Scraper (firecrawl)

```json
{
  "mcpServers": {
    "firecrawl": {
      "type": "http",
      "url": "https://firecrawl.mcp.nova-labs.ai/",
      "headers": {
        "x-api-key": "${FIRECRAWL_MCP_API_KEY}",
        "x-firecrawl-api-key": "${FIRECRAWL_API_KEY}"
      }
    }
  }
}
```

### Browser Automation (playwright)

```json
{
  "mcpServers": {
    "playwright": {
      "type": "http",
      "url": "https://playwright.mcp.nova-labs.ai/",
      "headers": {
        "x-api-key": "${PLAYWRIGHT_MCP_API_KEY}"
      }
    }
  }
}
```

Single gateway key — Playwright runs on the proxy server, no upstream API.

### Local Process (sequential-thinking)

```json
{
  "mcpServers": {
    "sequential-thinking": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-sequential-thinking"]
    }
  }
}
```

No credentials, no proxy — runs entirely locally.

## Third-Party Plugins

Third-party plugins (repos outside NovaAI-Ventures) can be added to the marketplace and will work automatically thanks to credential-loader Phase 3 auto-registration.

### Requirements

1. **`plugin.json` must declare `mcpServers`** — the plugin must have a `.claude-plugin/plugin.json` with an `mcpServers` block
2. **Marketplace `name` is canonical** — the marketplace entry name is used for identification, not the name inside plugin.json
3. **Version should be semver** — some upstream repos use non-semver (e.g. `"latest"`); the marketplace entry controls the version shown to users

### How Auto-Registration Works

When a 3rd-party plugin is installed:
1. Claude Code clones the repo into `~/.claude/plugins/cache/{marketplace}/{name}/{version}/`
2. At session start, credential-loader Phase 3 reads its `plugin.json`
3. Any `mcpServers` entries not already in `.mcp.json` are added automatically
4. No setup.sh or hooks.json needed from the 3rd-party repo

### Example: chrome-devtools

Upstream repo (`ChromeDevTools/chrome-devtools-mcp`) has:
```json
{
  "name": "chrome-devtools-mcp",
  "version": "latest",
  "mcpServers": {
    "chrome-devtools": {
      "command": "npx",
      "args": ["chrome-devtools-mcp@latest"]
    }
  }
}
```

Marketplace entry:
```json
{
  "name": "chrome-devtools",
  "version": "1.0.0",
  "source": { "source": "github", "repo": "ChromeDevTools/chrome-devtools-mcp" }
}
```

At session start, credential-loader adds to `.mcp.json`:
```json
"chrome-devtools": {
  "command": "npx",
  "args": ["chrome-devtools-mcp@latest"]
}
```

### No Wrapper Repos Needed

Previously, 3rd-party plugins required a NAV wrapper repo with setup.sh to write `.mcp.json`. With Phase 3 auto-registration, the marketplace can point directly to upstream repos. This avoids:
- Maintenance burden of keeping wrappers in sync
- Stale versions when upstream updates
- Duplicate repos for every 3rd-party tool
