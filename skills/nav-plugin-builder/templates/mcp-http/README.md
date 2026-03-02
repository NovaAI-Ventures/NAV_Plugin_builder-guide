# NAV_Plugin_PLUGIN_NAME

PLUGIN_DESCRIPTION

## Installation

```bash
/plugins install PLUGIN_NAME
```

## Credentials

Add to `.env.local` in your project root:

```bash
PLUGIN_NAME_UPPER_MCP_API_KEY=your-mcp-api-key
```

Get your gateway key from management.nova-labs.ai/tools.

## Architecture

```
Claude Code --> PLUGIN_NAME plugin --> PLUGIN_NAME.mcp.nova-labs.ai --> External API
```

All API calls go through the llm.nova-labs.ai proxy. Upstream credentials are stored in the management.nova-labs.ai Vault.

## Available Tools

| Tool | Description |
|------|-------------|
| `tool_name` | TOOL_DESCRIPTION |
