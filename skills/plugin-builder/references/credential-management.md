# Credential Management Reference

How credentials flow through the NovaAI plugin ecosystem.

## Architecture Overview

```
  .env.local (project root)          management.nova-labs.ai
  +-------------------------+        +------------------------------+
  | GMAIL_MCP_API_KEY=abc   |        | Vault (AES-256-GCM)         |
  | AHREFS_MCP_API_KEY=xyz  |        |   gmail: client_id, secret  |
  +------------+------------+        |   ahrefs: api_key            |
               |                     +-------------+----------------+
               |                                   |
   credential-loader                               |
   (SessionStart hook)                             |
               |                                   |
               v                                   v
         Claude Code session              llm.nova-labs.ai proxy
               |                                   |
               | x-api-key: abc                    | retrieves vault creds
               v                                   v
         *.mcp.nova-labs.ai  --------->  External API
```

## Two Credential Layers

### Layer 1: Gateway Keys (User's .env.local)

These authenticate the user's Claude Code session to the MCP proxy.

| Pattern | Example | Stored In |
|---------|---------|-----------|
| `{PLUGIN}_MCP_API_KEY` | `GMAIL_MCP_API_KEY` | `.env.local` in project root |

The `credential-loader` plugin loads these at `SessionStart` and makes them available as `${VAR}` in plugin.json.

### Layer 2: Upstream API Keys (management.nova-labs.ai Vault)

These are the actual API keys for external services (Gmail OAuth tokens, Ahrefs API key, etc.).

| Stored In | Encryption | Access |
|-----------|------------|--------|
| management.nova-labs.ai/tools/vault | AES-256-GCM | Proxy retrieves at request time |

The proxy (`llm.nova-labs.ai`) reads these from the Vault when forwarding requests to external APIs.

## Credential Flow — Step by Step

### 1. Developer stores upstream credentials in Vault

```
Developer --> management.nova-labs.ai/tools
  1. Find or create the tool entry
  2. Click "Add to Vault"
  3. Enter credential (API key, OAuth tokens, etc.)
  4. Vault encrypts with AES-256-GCM
```

### 2. Developer gets gateway key

The gateway key (`*_MCP_API_KEY`) is generated when the tool is registered. Add it to `.env.local`:

```bash
# .env.local (project root, gitignored)
GMAIL_MCP_API_KEY=your-gateway-key-here
```

### 3. credential-loader loads env vars at session start

The `credential-loader` plugin:
1. Reads `.env` then `.env.local` from project root
2. Writes vars to `$CLAUDE_ENV_FILE`
3. Claude Code resolves `${VAR}` patterns in plugin.json

### 4. Plugin sends request through proxy

```
Claude Code MCP request
  --> *.mcp.nova-labs.ai (with x-api-key header)
    --> proxy validates gateway key
    --> proxy retrieves upstream creds from Vault
    --> proxy calls external API with real credentials
    --> response flows back to Claude Code
```

## .env.local File Format

```bash
# Gateway keys (one per MCP HTTP plugin)
GMAIL_MCP_API_KEY=your-gmail-gateway-key
AHREFS_MCP_API_KEY=your-ahrefs-gateway-key
FIRECRAWL_MCP_API_KEY=your-firecrawl-gateway-key

# Some plugins pass upstream creds as headers too
GMAIL_CLIENT_ID=your-google-oauth-client-id
GMAIL_CLIENT_SECRET=your-google-oauth-client-secret
GMAIL_REFRESH_TOKEN=your-gmail-refresh-token
```

**Important:** `.env.local` must be in the project root (where Claude Code session starts), not in the plugin directory.

## .env.example Template

Every plugin that needs credentials must have a `.env.example`:

```bash
# === plugin-name ===
PLUGIN_MCP_API_KEY=your-plugin-mcp-api-key
SERVICE_API_KEY=your-service-api-key
```

This file IS committed to git. It serves as documentation for what credentials are needed.

## Env Var Naming Convention

| Type | Pattern | Example |
|------|---------|---------|
| MCP gateway key | `{PLUGIN}_MCP_API_KEY` | `GMAIL_MCP_API_KEY` |
| Upstream API key | `{SERVICE}_API_KEY` | `AHREFS_API_KEY` |
| OAuth client ID | `{SERVICE}_CLIENT_ID` | `GMAIL_CLIENT_ID` |
| OAuth secret | `{SERVICE}_CLIENT_SECRET` | `GMAIL_CLIENT_SECRET` |
| OAuth token | `{SERVICE}_REFRESH_TOKEN` | `GMAIL_REFRESH_TOKEN` |
| Base64 credentials | `{SERVICE}_CREDENTIALS` | `GA_GOOGLE_CREDENTIALS` |
| Service URL | `{SERVICE}_URL` | `HA_URL` (Home Assistant) |
| Access token | `{SERVICE}_TOKEN` | `APIFY_TOKEN` |

Always SCREAMING_SNAKE_CASE. Hyphens in plugin names become underscores.

## Vault Storage

### Credential Types

| Type | Use Case | Example |
|------|----------|---------|
| API Key | Simple key authentication | Ahrefs, Firecrawl |
| OAuth Client | OAuth 2.0 flows | Gmail, Google Analytics |
| Service Account | GCP/AWS service accounts | Google Search Console |
| Access Token | Bearer token auth | Home Assistant |

### Storing Credentials

1. Go to `management.nova-labs.ai/tools`
2. Find the tool (registered in Step 12 of the build workflow)
3. Click "Add to Vault"
4. Select credential type
5. Enter value(s)
6. Vault encrypts with AES-256-GCM before storage

### Vault is Single Source of Truth

- **DO** store upstream API credentials in the Vault
- **DO** store gateway keys in `.env.local`
- **DO NOT** store upstream credentials in `.env.local` (unless plugin requires header passthrough)
- **DO NOT** hardcode credentials in plugin.json
- **DO NOT** store credentials in `~/.zshrc` or shell profiles

## credential-loader Plugin

The `credential-loader` plugin (`NAV_Plugin_credential-loader`) handles env var loading:

### What It Does

1. **SessionStart hook** fires every time Claude Code starts
2. Reads `.env` then `.env.local` from project root
3. Writes key=value pairs to `$CLAUDE_ENV_FILE`
4. Scans all installed plugins for required `${VAR}` patterns
5. Reports any missing credentials as a system message

### How It Detects Required Variables

It reads every installed plugin's `plugin.json`, extracts all `${VAR}` patterns from `mcpServers` config, excludes system variables (`CLAUDE_PLUGIN_ROOT`, `CLAUDE_ENV_FILE`, `CLAUDE_PROJECT_DIR`), and checks which are missing.

### Missing Credential Warning

If credentials are missing, Claude sees:

```
Missing credentials detected:
  gmail: GMAIL_MCP_API_KEY, GMAIL_CLIENT_ID
  ahrefs: AHREFS_MCP_API_KEY
Add these to .env.local in your project root.
```

This helps users identify which plugins need configuration.
