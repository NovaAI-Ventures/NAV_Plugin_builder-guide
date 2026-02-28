---
name: plugin-builder
description: >
  Interactive guide for building NovaAI plugins. Walks through the full lifecycle:
  choose type, scaffold files, register on management.nova-labs.ai, store credentials
  in Vault, configure proxy, push to GitHub, and publish to marketplace. Supports all
  three plugin types: Pure Skill, Skill + Commands, and MCP HTTP. Activates when the
  user says "build a plugin", "create a new plugin", "scaffold a plugin", or similar.
---

# Plugin Builder Guide

Build a NovaAI plugin from scratch. This skill walks you through every step — from choosing a type to publishing on the marketplace.

## Architecture

```
                    management.nova-labs.ai
                    +------------------------------+
                    |  /tools    -> Tool registry   |
                    |  /tools/vault -> Credential   |
                    |               vault (AES-256) |
                    |  /MCP     -> MCP server config|
                    +-------------+----------------+
                                  |
                                  | credentials
                                  v
Claude Code --> Plugin --> llm.nova-labs.ai (proxy) --> External API
                           *.mcp.nova-labs.ai              (VEO, Gmail,
                                                            Notion, etc.)
```

**Key rules:**
- ALL external API calls go through `llm.nova-labs.ai` as a proxy
- Credentials are stored in management.nova-labs.ai Vault (AES-256-GCM)
- MCP HTTP servers live at `*.mcp.nova-labs.ai` (not `*.mcp.majewscy.tech`)
- Each plugin repo is named `NAV_Plugin_{kebab-case-name}`

---

## Decision Guide

Before starting, help the user choose the right plugin type:

| Need | Type | Example Plugins |
|------|------|-----------------|
| Methodology / workflow / AI generation | **Pure Skill** | build-and-prove, veo-video, copywriter |
| Repeatable CLI tasks with slash commands | **Skill + Commands** | infra (/devenv) |
| Claude needs tools for an external API | **MCP HTTP** | gmail, notion, google-analytics |

**Quick decision tree:**

```
Does the plugin give Claude access to an external API?
  YES --> MCP HTTP (Type 3)
  NO  --> Does it need slash commands for repeatable CLI tasks?
            YES --> Skill + Commands (Type 2)
            NO  --> Pure Skill (Type 1)
```

---

## Interactive Workflow

### Step 1: Choose Plugin Type

Ask the user:

> What kind of plugin are you building?
> 1. **Pure Skill** — methodology, workflow, AI generation (no external APIs)
> 2. **Skill + Commands** — skill with repeatable slash commands
> 3. **MCP HTTP** — Claude tools backed by an external API

Store the choice as `PLUGIN_TYPE` (one of: `pure-skill`, `skill-commands`, `mcp-http`).

---

### Step 2: Gather Plugin Details

Ask the user for:

| Field | Example | Required |
|-------|---------|----------|
| Plugin name | `video-generator` | Yes |
| Description (one line) | "Generate videos using Google VEO API" | Yes |
| External API name | "Google VEO" | Only for MCP HTTP |
| External API base URL | `https://generativelanguage.googleapis.com` | Only for MCP HTTP |
| Required credentials | API key, OAuth tokens, etc. | Only for MCP HTTP |
| Slash command name | `/deploy` | Only for Skill + Commands |

Store as variables:
- `PLUGIN_NAME` — the short name (kebab-case, no prefix)
- `PLUGIN_DESCRIPTION` — one-line description
- `REPO_NAME` — `NAV_Plugin_${PLUGIN_NAME}`
- `EXT_API_NAME` — external API name (MCP HTTP only)
- `EXT_API_URL` — external API base URL (MCP HTTP only)
- `CREDENTIALS` — list of required env var names (MCP HTTP only)
- `COMMAND_NAME` — slash command name (Skill + Commands only)

---

### Step 3: Validate Naming

Check naming conventions:

```
Plugin name:  kebab-case, lowercase, no spaces
              GOOD: video-generator, landing-page-copywriter
              BAD:  VideoGenerator, landing page, video_generator

Repo name:    NAV_Plugin_{plugin-name}
              GOOD: NAV_Plugin_video-generator
              BAD:  nav-plugin-video-generator, NAV_video-generator

MCP subdomain: {plugin-name}.mcp.nova-labs.ai
              GOOD: gmail.mcp.nova-labs.ai
              BAD:  GMAIL.mcp.nova-labs.ai

Env vars:     SCREAMING_SNAKE_CASE
              Pattern: {PLUGIN}_MCP_API_KEY for gateway key
              Pattern: {PLUGIN}_API_KEY for upstream service key
              GOOD: GMAIL_MCP_API_KEY, VEO_API_KEY
              BAD:  gmail-api-key, veoApiKey
```

If any validation fails, ask the user to correct it before proceeding.

---

### Step 4: Create Plugin Directory

```bash
PLUGIN_DIR="/path/to/Plugins/${REPO_NAME}"
mkdir -p "${PLUGIN_DIR}/.claude-plugin"
```

Confirm the path with the user. Default location:
`~/Documents/Repositories/ThisSystem_and_Cloud/Claude/Plugins/${REPO_NAME}/`

---

### Step 5: Generate plugin.json

**For Pure Skill:**
```json
{
  "name": "${PLUGIN_NAME}",
  "description": "${PLUGIN_DESCRIPTION}",
  "version": "1.0.0",
  "author": { "name": "NovaAI-Ventures" }
}
```

**For Skill + Commands:**
```json
{
  "name": "${PLUGIN_NAME}",
  "description": "${PLUGIN_DESCRIPTION}",
  "version": "1.0.0",
  "author": { "name": "NovaAI-Ventures" },
  "commands": "./commands/",
  "skills": "./skills/"
}
```

**For MCP HTTP:**
```json
{
  "name": "${PLUGIN_NAME}",
  "description": "${PLUGIN_DESCRIPTION}",
  "version": "1.0.0",
  "author": { "name": "NovaAI-Ventures" },
  "mcpServers": {
    "${PLUGIN_NAME}": {
      "type": "http",
      "url": "https://${PLUGIN_NAME}.mcp.nova-labs.ai/",
      "headers": {
        "x-api-key": "${${PLUGIN_NAME_UPPER}_MCP_API_KEY}"
      }
    }
  },
  "hooks": "./hooks/hooks.json"
}
```

If the external API requires additional credentials passed as headers, add them:
```json
"headers": {
  "x-api-key": "${PLUGIN_MCP_API_KEY}",
  "x-service-api-key": "${SERVICE_API_KEY}"
}
```

Write to `${PLUGIN_DIR}/.claude-plugin/plugin.json`.

See `references/plugin-json-schema.md` for full field reference.

---

### Step 6: Generate .gitignore

```
# Credentials
*.json
!.claude-plugin/plugin.json
!.claude-plugin/marketplace.json
!hooks/hooks.json
.env
.env.local
env.local

# OS
.DS_Store

# Editor
.vscode/
.idea/
```

For MCP HTTP, also add:
```
# Node
node_modules/
```

Write to `${PLUGIN_DIR}/.gitignore`.

---

### Step 7: Generate .env.example

**For Pure Skill (no credentials):**
```bash
# === ${PLUGIN_NAME} ===
# No credentials required — this is a pure skill plugin.
```

**For Skill + Commands (may have credentials):**
```bash
# === ${PLUGIN_NAME} ===
# Add any required credentials below.
# Copy this file to .env.local in your project root.
```

**For MCP HTTP:**
```bash
# === ${PLUGIN_NAME} ===
${PLUGIN_NAME_UPPER}_MCP_API_KEY=your-${PLUGIN_NAME}-mcp-api-key
${SERVICE_KEY_NAME}=your-${SERVICE_NAME}-api-key
```

List every env var that appears in plugin.json `mcpServers.*.headers` as `${VAR}`.

Write to `${PLUGIN_DIR}/.env.example`.

---

### Step 8: Generate README.md

Use this template:

```markdown
# ${REPO_NAME}

${PLUGIN_DESCRIPTION}

## Installation

\`\`\`bash
/plugins install ${PLUGIN_NAME}
\`\`\`

## Usage

[Describe how to use the plugin — triggers, slash commands, or MCP tools]

## Architecture

[For MCP HTTP: explain the proxy flow]
[For Skills: explain the workflow]

## Credentials

[For MCP HTTP: list required env vars and where to get them]
[For Pure Skill: "No credentials required"]
```

Write to `${PLUGIN_DIR}/README.md`.

---

### Step 9: Generate SKILL.md (Type 1 and Type 2)

**Skip this step for MCP HTTP (Type 3) unless the plugin also has a skill component.**

Create `${PLUGIN_DIR}/skills/${PLUGIN_NAME}/SKILL.md`:

```markdown
---
name: ${PLUGIN_NAME}
description: >
  ${PLUGIN_DESCRIPTION}
  [Add activation triggers: when should this skill activate?]
---

# ${PLUGIN_NAME} Skill

## When to Activate

This skill activates when the user says:
- [trigger phrase 1]
- [trigger phrase 2]
- [trigger phrase 3]

## Workflow

[Step-by-step instructions for Claude to follow]

## Hard Rules

| # | Rule |
|---|---|
| 1 | [Rule 1] |
| 2 | [Rule 2] |
```

Ask the user to provide:
1. Activation trigger phrases
2. The workflow steps
3. Any hard rules or constraints

Also create a `references/` directory inside the skill if reference docs are needed.

See `references/plugin-json-schema.md` for SKILL.md format details.

---

### Step 10: Generate Command File (Type 2 Only)

**Skip this step unless PLUGIN_TYPE is `skill-commands`.**

Create `${PLUGIN_DIR}/commands/${COMMAND_NAME}.md`:

```markdown
---
description: [Short description shown in command palette]
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
argument-hint: [arg1|arg2|arg3]
---

# ${COMMAND_NAME}

## Available Arguments

| Argument | Description |
|----------|-------------|
| `arg1` | [What arg1 does] |
| `arg2` | [What arg2 does] |

## Workflow

[Full instructions for Claude to follow when this command is invoked]
```

Ask the user:
1. What arguments should the command accept?
2. Which Claude Code tools does the command need?
3. What workflow should the command follow?

See `references/command-format.md` for full format reference.

---

### Step 11: Generate Hooks and Setup Script (Type 3 Only)

**Skip this step unless PLUGIN_TYPE is `mcp-http`.**

Create `${PLUGIN_DIR}/hooks/hooks.json`:
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

Create `${PLUGIN_DIR}/scripts/setup.sh`:
```bash
#!/usr/bin/env bash
# Setup hook — checks required environment variables

PLUGIN_NAME="${PLUGIN_NAME}"
MISSING=()
```

For each credential env var, add:
```bash
[ -z "${VAR_NAME:-}" ] && MISSING+=("VAR_NAME")
```

Then add the standard check/output block:
```bash
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

Make executable:
```bash
chmod +x "${PLUGIN_DIR}/scripts/setup.sh"
```

See `references/hooks-system.md` for hook types and JSON format.

---

### Step 12: Register Tool on management.nova-labs.ai

**This step registers the plugin as a tool in the central management system.**

Use the Management MCP server's `create` tool:

```
Tool: management MCP create
Entity: "tool"
Data:
  name: "${EXT_API_NAME}" (or plugin display name)
  slug: "${PLUGIN_NAME}"
  categoryId: [ask user or look up from existing categories]
  description: "${PLUGIN_DESCRIPTION}"
  toolType: "MCP_PLUGIN"
  websiteUrl: "https://github.com/NovaAI-Ventures/${REPO_NAME}"
  inOurStack: true
  stackStatus: "ACTIVE"
```

If the Management MCP server is not available, tell the user:
> Register the tool manually at management.nova-labs.ai/tools:
> 1. Go to management.nova-labs.ai/tools
> 2. Click "Add Tool"
> 3. Fill in: name, slug, category, description
> 4. Set toolType to "MCP_PLUGIN"
> 5. Set inOurStack to true, stackStatus to "ACTIVE"

---

### Step 13: Store Credentials in Vault

**Skip this step if the plugin has no external API credentials.**

Guide the user to store credentials in the management.nova-labs.ai Vault:

```
Credential Storage Flow:
  1. Go to management.nova-labs.ai/tools
  2. Find the tool registered in Step 12
  3. Click "Add to Vault"
  4. Select credential type:
     - API Key (most common)
     - OAuth Client (for OAuth flows)
     - Service Account (for GCP/AWS)
  5. Enter the credential value
  6. The vault encrypts with AES-256-GCM before storage
```

**Credential flow after storage:**

```
Developer                    management.nova-labs.ai
    |                              |
    |  1. Store API key in Vault   |
    |----------------------------->| /tools/vault (AES-256-GCM)
    |                              |
    |                              |         llm.nova-labs.ai
    |                              |              |
    |                              |  2. Proxy    |
    |                              |  retrieves   |
    |                              |  vault creds |
    |                              |------------->|
    |                              |              |
Claude Code                        |              |     External API
    |                              |              |          |
    |  3. Plugin calls proxy       |              |          |
    |--------------------------------------------->          |
    |     (x-api-key header)       |              |          |
    |                              |              |  4. Proxy|
    |                              |              |  forwards|
    |                              |              |--------->|
    |                              |              |          |
    |  5. Response                 |              |          |
    |<-----------------------------------------------------|
```

**Important:** The Vault is the single source of truth for credentials. The `.env.local` file in the user's project only holds the MCP gateway API key (`*_MCP_API_KEY`), not the upstream service key.

See `references/credential-management.md` for full details.

---

### Step 14: Initialize Git and Push to GitHub

```bash
cd "${PLUGIN_DIR}"
git init
git add .
git commit -m "Initial scaffold: ${PLUGIN_NAME} plugin

Type: ${PLUGIN_TYPE}
Description: ${PLUGIN_DESCRIPTION}"

# Create GitHub repo and push
gh repo create "NovaAI-Ventures/${REPO_NAME}" --public --source=. --push
```

If `gh` is not authenticated for the NovaAI-Ventures org, guide the user:
```bash
gh auth login
gh repo create "NovaAI-Ventures/${REPO_NAME}" --public --source=. --push
```

---

### Step 15: Add Marketplace Entry

Add the plugin to the marketplace registry. Create the entry JSON:

**For Pure Skill / Skill + Commands:**
```json
{
  "name": "${PLUGIN_NAME}",
  "source": {
    "source": "github",
    "repo": "NovaAI-Ventures/${REPO_NAME}"
  },
  "description": "${PLUGIN_DESCRIPTION}",
  "version": "1.0.0"
}
```

**For MCP HTTP:**
```json
{
  "name": "${PLUGIN_NAME}",
  "source": {
    "source": "github",
    "repo": "NovaAI-Ventures/${REPO_NAME}"
  },
  "description": "${PLUGIN_DESCRIPTION}",
  "version": "1.0.0",
  "mcpServer": "${PLUGIN_NAME}.mcp.nova-labs.ai"
}
```

Tell the user to add this entry to the `plugins` array in the marketplace.json file at `llm.nova-labs.ai`.

See `references/marketplace-admin.md` for full marketplace structure.

---

### Step 16: Test Installation

```bash
# Install the plugin
/plugins install ${PLUGIN_NAME}

# Verify it appears
/plugins list
```

**Verification checklist:**
- [ ] Plugin appears in `/plugins list`
- [ ] For MCP HTTP: setup hook runs and reports credential status
- [ ] For Skills: skill activates on trigger phrases
- [ ] For Commands: slash command appears in command palette
- [ ] Tool appears at management.nova-labs.ai/tools

---

## Summary Output

After all 16 steps, present a summary:

```
Plugin Created Successfully!

  Name:       ${PLUGIN_NAME}
  Type:       ${PLUGIN_TYPE}
  Repo:       NovaAI-Ventures/${REPO_NAME}
  GitHub:     https://github.com/NovaAI-Ventures/${REPO_NAME}

  Files created:
    .claude-plugin/plugin.json
    .gitignore
    .env.example
    README.md
    [type-specific files]

  Registered:
    management.nova-labs.ai/tools  [YES/NO]
    Vault credentials              [YES/NO/N/A]
    Marketplace entry              [YES/NO]

  Next steps:
    1. /plugins install ${PLUGIN_NAME}
    2. Test the plugin
    3. Iterate on SKILL.md / commands / MCP tools
```

---

## File Structure Reference

### Type 1: Pure Skill
```
${REPO_NAME}/
  .claude-plugin/
    plugin.json
  skills/
    ${PLUGIN_NAME}/
      SKILL.md
      references/          (optional)
      scripts/             (optional)
  .env.example
  .gitignore
  README.md
```

### Type 2: Skill + Commands
```
${REPO_NAME}/
  .claude-plugin/
    plugin.json
  skills/
    ${PLUGIN_NAME}/
      SKILL.md
      references/          (optional)
  commands/
    ${COMMAND_NAME}.md
  .env.example
  .gitignore
  README.md
```

### Type 3: MCP HTTP
```
${REPO_NAME}/
  .claude-plugin/
    plugin.json
  hooks/
    hooks.json
  scripts/
    setup.sh
  .env.example
  .gitignore
  README.md
```

---

## Hard Rules

| # | Rule |
|---|---|
| 1 | ALL external API calls go through llm.nova-labs.ai proxy — never call APIs directly |
| 2 | Credentials stored in management.nova-labs.ai Vault — .env.local only holds gateway keys |
| 3 | Repo name format: `NAV_Plugin_{kebab-case}` — no exceptions |
| 4 | MCP HTTP servers at `*.mcp.nova-labs.ai` — not *.mcp.majewscy.tech |
| 5 | Every MCP HTTP plugin MUST have a Setup hook that validates env vars |
| 6 | Setup hook output MUST be valid JSON: `{"status":"success","systemMessage":"..."}` |
| 7 | plugin.json MUST have: name, description, version, author |
| 8 | Env var naming: `SCREAMING_SNAKE_CASE` — gateway key suffix `_MCP_API_KEY` |
| 9 | Register tool on management.nova-labs.ai before publishing |
| 10 | Every plugin gets a marketplace entry — no orphan repos |
