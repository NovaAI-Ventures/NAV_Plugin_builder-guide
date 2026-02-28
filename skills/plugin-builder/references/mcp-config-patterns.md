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
