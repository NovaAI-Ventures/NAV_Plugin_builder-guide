# Marketplace Administration Reference

How plugins are listed in the NovaAI marketplace.

## marketplace.json Structure

The marketplace is a JSON registry that lists available plugins. It lives at `llm.nova-labs.ai` and can also be stored locally in `.claude-plugin/marketplace.json`.

```json
{
  "name": "novaai-ventures-plugin",
  "owner": {
    "name": "NovaAI-Ventures"
  },
  "repository": "https://github.com/NovaAI-Ventures/plugin",
  "metadata": {
    "description": "NovaAI-Ventures plugin collection: infrastructure, AI agents, and developer tools"
  },
  "plugins": [
    {
      "name": "plugin-name",
      "source": {
        "source": "github",
        "repo": "NovaAI-Ventures/NAV_Plugin_plugin-name"
      },
      "description": "One-line description of the plugin",
      "version": "1.0.0"
    }
  ]
}
```

## Top-Level Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Registry identifier. Use `"novaai-ventures-plugin"`. |
| `owner` | object | `{ "name": "NovaAI-Ventures" }` |
| `repository` | string | URL to the registry repo. |
| `metadata.description` | string | Description of the plugin collection. |
| `plugins` | array | Array of plugin entries. |

## Plugin Entry Fields

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Plugin identifier (matches plugin.json `name`). |
| `source` | object/string | Where to find the plugin. |
| `description` | string | One-line description. |
| `version` | string | Semver version. |

### Source Types

**GitHub source (most common):**
```json
{
  "source": {
    "source": "github",
    "repo": "NovaAI-Ventures/NAV_Plugin_plugin-name"
  }
}
```

**Local source (for plugins in the same repo):**
```json
{
  "source": "./"
}
```

## Adding a New Plugin

### Step 1: Prepare the Entry

**For a Pure Skill or Skill + Commands plugin:**
```json
{
  "name": "my-plugin",
  "source": {
    "source": "github",
    "repo": "NovaAI-Ventures/NAV_Plugin_my-plugin"
  },
  "description": "What the plugin does in one line",
  "version": "1.0.0"
}
```

**For an MCP HTTP plugin:**
```json
{
  "name": "my-plugin",
  "source": {
    "source": "github",
    "repo": "NovaAI-Ventures/NAV_Plugin_my-plugin"
  },
  "description": "What the plugin does in one line",
  "version": "1.0.0"
}
```

The entry format is the same for all types. The plugin type is determined by the plugin.json inside the repo, not the marketplace entry.

### Step 2: Add to the Plugins Array

Add the entry to the `plugins` array in marketplace.json. Keep entries alphabetically sorted by name for maintainability.

### Step 3: Verify

After adding, verify:
- [ ] `name` matches the plugin.json `name` field exactly
- [ ] `repo` matches the actual GitHub repository name
- [ ] `description` is concise and accurate
- [ ] `version` matches the plugin.json `version` field

## Categories

Plugins are informally categorized by their function:

| Category | Example Plugins |
|----------|-----------------|
| Infrastructure | infra, cloudflare, local-dev-environment |
| Communication | gmail, home-assistant |
| SEO & Analytics | ahrefs, google-analytics, google-search-console |
| Development | build-and-prove, visual-testing, sequential-thinking |
| Content | landing-page-copywriter, landing-page-guide |
| AI & Automation | manus-mcp, apify, firecrawl |
| Browser | playwright, context7 |
| CMS | wordpress |

## Existing Marketplace Entries

Reference these existing entries when creating new ones:

```json
{
  "name": "build-and-prove",
  "source": {
    "source": "github",
    "repo": "NovaAI-Ventures/NAV_Plugin_build-and-prove"
  },
  "description": "Delivery verification protocol - screenshot evidence, console checks, and escalation for every deliverable",
  "version": "1.0.0"
}
```

```json
{
  "name": "manus-mcp",
  "source": {
    "source": "github",
    "repo": "NovaAI-Ventures/NAV_Plugin_manus-mcp"
  },
  "description": "Manus AI agent - create tasks, manage webhooks, run Manus workflows",
  "version": "1.0.0"
}
```

## Versioning

- Start at `1.0.0` for new plugins
- Bump `PATCH` (1.0.1) for bug fixes
- Bump `MINOR` (1.1.0) for new features
- Bump `MAJOR` (2.0.0) for breaking changes
- Update both `plugin.json` and the marketplace entry when versioning
