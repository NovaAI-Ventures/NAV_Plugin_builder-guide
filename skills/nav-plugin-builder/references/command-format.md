# Command Format Reference

Slash commands give users quick access to plugin functionality via `/command-name`.

## File Location

Commands are stored in the `commands/` directory referenced from plugin.json:

```json
{
  "commands": "./commands/"
}
```

Each `.md` file in that directory becomes a slash command. The filename (without `.md`) is the command name:
- `commands/devenv.md` -> `/devenv`
- `commands/deploy.md` -> `/deploy`
- `commands/generate.md` -> `/generate`

## Command File Format

```markdown
---
description: Short description shown in command palette
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
argument-hint: [arg1|arg2|arg3]
---

# Command Title

[Full instructions for Claude to follow when this command is invoked]
```

## YAML Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `description` | Yes | Short text shown in the command picker/palette. Keep under 80 characters. |
| `allowed-tools` | Yes | List of Claude Code tools the command is allowed to use. |
| `argument-hint` | No | Hint shown to user for expected arguments. Use `[arg1\|arg2]` format. |

### allowed-tools Values

Available tools to grant:

| Tool | Purpose |
|------|---------|
| `Bash` | Run shell commands |
| `Read` | Read files |
| `Write` | Create/overwrite files |
| `Edit` | Edit existing files |
| `Glob` | Find files by pattern |
| `Grep` | Search file contents |
| `WebFetch` | Fetch web content |
| `WebSearch` | Search the web |
| `Task` | Launch subagents |

Only include the tools the command actually needs. Fewer tools = safer execution.

### argument-hint Format

```yaml
# Single argument
argument-hint: [name]

# Multiple options
argument-hint: [up|down|list|status|init]

# Optional argument
argument-hint: [file-path]

# No arguments
# (omit the field entirely)
```

## Command Body

The body after the frontmatter is the full instruction set for Claude. When a user types `/command-name arg`, Claude receives:
1. The command body as instructions
2. The user's argument (if any)

Structure the body as a complete workflow:

```markdown
---
description: Deploy the application
allowed-tools:
  - Bash
  - Read
  - Glob
argument-hint: [staging|production]
---

# Deploy

## Available Arguments

| Argument | Description |
|----------|-------------|
| `staging` | Deploy to staging environment |
| `production` | Deploy to production (requires confirmation) |

## Workflow

### 1. Read Configuration
Read `deploy.config.json` from project root.

### 2. Validate
- Check that Docker is running
- Verify environment variables are set

### 3. Execute
- Build Docker image
- Push to registry
- Update deployment

### 4. Verify
- Check deployment status
- Run health check
```

## Complete Example (devenv)

```markdown
---
description: Local Docker environments via Traefik without port conflicts
allowed-tools:
  - Bash
  - Read
  - Write
  - Glob
  - Grep
argument-hint: [up|down|list|status|init]
---

# DevEnv - Local Docker Environments with Traefik

## First Steps

1. Install Traefik (once): `/devenv init`
2. Go to project directory with `docker-compose.yml`
3. Start project: `/devenv up`
4. Open in browser: `http://{folder-name}.127.0.0.1.nip.io`

## Available Commands

| Command | Description |
|---------|-------------|
| `/devenv` or `/devenv up` | Start project from current docker-compose.yml |
| `/devenv down` | Stop project |
| `/devenv list` | Show all running services with URLs |
| `/devenv status` | Show Traefik and service status |
| `/devenv init` | Initialize Traefik (first time setup) |
```

## Best Practices

1. **Keep descriptions concise** — they appear in the command palette
2. **Minimize allowed-tools** — only grant what's needed
3. **Structure the body as a workflow** — numbered steps Claude can follow
4. **Include argument documentation** — table of what each arg does
5. **Add validation steps** — check prerequisites before executing
6. **Handle errors gracefully** — tell Claude what to do when things fail
