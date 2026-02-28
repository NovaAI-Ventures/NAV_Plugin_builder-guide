# NAV_Plugin_builder-guide

Interactive Claude Code skill that walks you through the full plugin lifecycle: scaffold, register in management, configure proxy, publish to marketplace.

## Installation

```bash
/plugins install plugin-builder-guide
```

## Usage

Say any of:
- "Build a plugin"
- "Create a new plugin"
- "Scaffold a plugin"
- "I want to build a plugin"

The skill will guide you through a 16-step interactive workflow.

## Three Plugin Types

| Type | Use When | Example Plugins |
|------|----------|-----------------|
| **Pure Skill** | AI methodology / workflow / generation | build-and-prove, veo-video, copywriter |
| **Skill + Commands** | Repeatable CLI tasks with slash commands | infra (/devenv) |
| **MCP HTTP** | Claude needs tools for an external API | gmail, notion, google-analytics |

## Architecture

All external API calls route through `llm.nova-labs.ai` as a proxy. Credentials are stored centrally in the management.nova-labs.ai Vault (AES-256-GCM encrypted).

```
Claude Code --> Plugin --> llm.nova-labs.ai (proxy) --> External API
                          *.mcp.nova-labs.ai
```

## What the Guide Does

1. Scaffolds plugin files locally (plugin.json, SKILL.md, hooks, etc.)
2. Registers the tool on management.nova-labs.ai/tools (via Management MCP)
3. Stores API credentials in the Vault
4. Configures the proxy route on llm.nova-labs.ai
5. Pushes to GitHub
6. Adds to marketplace.json

## Reference Documentation

- `references/plugin-json-schema.md` — plugin.json field reference
- `references/mcp-config-patterns.md` — HTTP MCP server configuration
- `references/hooks-system.md` — Hook types and JSON format
- `references/credential-management.md` — Vault + credential-loader
- `references/marketplace-admin.md` — marketplace.json structure
- `references/command-format.md` — Slash command YAML frontmatter
- `references/mcp-server-guide.md` — Building MCP HTTP backends (optional)
