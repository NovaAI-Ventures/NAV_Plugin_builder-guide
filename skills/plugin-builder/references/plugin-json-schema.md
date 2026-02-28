# plugin.json Schema Reference

Every NovaAI plugin has a `.claude-plugin/plugin.json` manifest. This is the complete field reference.

## Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Plugin identifier. Kebab-case, lowercase, no spaces. Must be unique across all NovaAI plugins. |
| `description` | string | One-line description. Shows in plugin list and marketplace. |
| `version` | string | Semver format: `MAJOR.MINOR.PATCH` (e.g., `1.0.0`). |
| `author` | object | `{ "name": "NovaAI-Ventures" }` for all org plugins. |

## Optional Fields

| Field | Type | Description |
|-------|------|-------------|
| `mcpServers` | object | MCP server configurations. One or more named servers. |
| `hooks` | string | Path to hooks JSON file, relative to plugin root. Typically `"./hooks/hooks.json"`. |
| `skills` | string | Path to skills directory, relative to plugin root. Typically `"./skills/"`. |
| `commands` | string | Path to commands directory, relative to plugin root. Typically `"./commands/"`. |
| `homepage` | string | URL to project homepage (rarely used). |
| `repository` | string | URL to GitHub repository (rarely used). |
| `license` | string | SPDX license identifier (rarely used). |
| `keywords` | array | String array of keywords (rarely used). |

## MCP Server Configuration

### HTTP Transport (proxy through nova-labs.ai)

```json
{
  "mcpServers": {
    "server-name": {
      "type": "http",
      "url": "https://server-name.mcp.nova-labs.ai/",
      "headers": {
        "x-api-key": "${SERVER_NAME_MCP_API_KEY}",
        "x-service-api-key": "${SERVICE_API_KEY}"
      }
    }
  }
}
```

| Field | Description |
|-------|-------------|
| `type` | Must be `"http"` for HTTP MCP servers. |
| `url` | Full URL to the MCP endpoint. Always `https://*.mcp.nova-labs.ai/`. |
| `headers` | HTTP headers sent with every request. Use `${VAR}` for env var substitution. |

### Subprocess Transport (local process)

```json
{
  "mcpServers": {
    "server-name": {
      "command": "npx",
      "args": ["-y", "@package/mcp-server"],
      "env": {
        "API_KEY": "${API_KEY}"
      }
    }
  }
}
```

| Field | Description |
|-------|-------------|
| `command` | Executable to run: `npx`, `node`, `mcp-proxy`, `python3`, etc. |
| `args` | Array of command arguments. Can use `${CLAUDE_PLUGIN_ROOT}`. |
| `env` | Environment variables passed to the process. Use `${VAR}` for substitution. |

## Variable Substitution

Variables in `${VAR}` syntax are resolved at runtime:

| Variable | Source | Description |
|----------|--------|-------------|
| `${CLAUDE_PLUGIN_ROOT}` | System | Absolute path to the installed plugin directory. |
| `${CLAUDE_ENV_FILE}` | System | Path to Claude's env injection file. |
| `${CLAUDE_PROJECT_DIR}` | System | Path to the current project directory. |
| `${ANY_OTHER_VAR}` | .env.local | Loaded from project .env.local via credential-loader. |

## Complete Examples

### Pure Skill (build-and-prove)

```json
{
  "name": "build-and-prove",
  "description": "Delivery verification protocol — prove every deliverable with screenshot evidence, console checks, and escalation with ASCII diagrams",
  "version": "1.0.0",
  "author": { "name": "NovaAI-Ventures" }
}
```

No `mcpServers`, no `hooks`, no `skills` key needed — the framework auto-discovers `skills/` directory.

### Skill + Commands (infra)

```json
{
  "name": "infra",
  "version": "1.0.0",
  "description": "Kubernetes infrastructure management: ArgoCD, Envoy Gateway, monitoring, cert-manager, SealedSecrets, and local Docker environments with Traefik",
  "author": { "name": "NovaAI-Ventures" },
  "commands": "./commands/",
  "skills": "./skills/"
}
```

Both `commands` and `skills` paths are explicit.

### MCP HTTP (gmail)

```json
{
  "name": "gmail",
  "description": "Gmail — search, read, send, draft, label, and filter emails",
  "version": "1.0.0",
  "author": { "name": "NovaAI-Ventures" },
  "mcpServers": {
    "gmail": {
      "type": "http",
      "url": "https://gmail.mcp.nova-labs.ai/",
      "headers": {
        "x-api-key": "${GMAIL_MCP_API_KEY}",
        "x-gmail-client-id": "${GMAIL_CLIENT_ID}",
        "x-gmail-client-secret": "${GMAIL_CLIENT_SECRET}",
        "x-gmail-refresh-token": "${GMAIL_REFRESH_TOKEN}"
      }
    }
  },
  "hooks": "./hooks/hooks.json"
}
```

Multiple credentials passed as custom headers. The proxy (`llm.nova-labs.ai`) forwards these to the upstream Gmail API.

### MCP HTTP — Minimal (context7)

```json
{
  "name": "context7",
  "description": "Context7 — up-to-date library documentation and code examples from official sources",
  "version": "1.0.0",
  "author": { "name": "NovaAI-Ventures" },
  "mcpServers": {
    "context7": {
      "type": "http",
      "url": "https://context7.mcp.nova-labs.ai/",
      "headers": {
        "x-api-key": "${CONTEXT7_MCP_API_KEY}"
      }
    }
  }
}
```

Single gateway key, no hooks (credentials are simple enough to not need validation).

## SKILL.md Format

Skills use YAML frontmatter:

```markdown
---
name: skill-name
description: >
  Multi-line description. This text determines when the skill activates.
  Include key trigger phrases in the description.
---

# Skill Title

[Workflow instructions for Claude]
```

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Kebab-case skill identifier. |
| `description` | Yes | Multi-line description. Use `>` block scalar for readability. |

## Naming Conventions

| Entity | Pattern | Example |
|--------|---------|---------|
| Plugin name | kebab-case | `video-generator` |
| Repo name | `NAV_Plugin_{name}` | `NAV_Plugin_video-generator` |
| MCP server key | same as plugin name | `"video-generator": { ... }` |
| MCP subdomain | `{name}.mcp.nova-labs.ai` | `video-generator.mcp.nova-labs.ai` |
| Gateway env var | `{NAME}_MCP_API_KEY` | `VIDEO_GENERATOR_MCP_API_KEY` |
| Service env var | `{SERVICE}_API_KEY` | `VEO_API_KEY` |
| Skill directory | `skills/{name}/` | `skills/video-generator/` |
| Command file | `commands/{cmd}.md` | `commands/generate.md` |
