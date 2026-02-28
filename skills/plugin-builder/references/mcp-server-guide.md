# Building MCP HTTP Backends (Optional)

This guide covers building the MCP HTTP server that runs at `*.mcp.nova-labs.ai`. Most plugin builders do NOT need this — the proxy/server is typically already running. This guide is for when you need to create a new MCP HTTP backend for a new external API integration.

## When You Need This

- You're integrating a **new external API** that doesn't have an MCP server yet
- The existing proxy doesn't support the API you need
- You need custom tool definitions for Claude

If the MCP server already exists (e.g., gmail.mcp.nova-labs.ai is live), you only need the plugin files (plugin.json, hooks, etc.) — skip this guide.

## Architecture

```
Claude Code
    |
    | MCP protocol (HTTP transport)
    v
*.mcp.nova-labs.ai
    |
    | Your MCP HTTP server running here
    | Receives MCP tool calls, translates to API calls
    v
External API (Gmail, VEO, Notion, etc.)
```

## MCP Server Structure

A minimal MCP HTTP server needs:

```
mcp-server/
  src/
    index.ts          # Server entry point, tool definitions
    client.ts         # API client for external service
    types.ts          # TypeScript types
  dist/
    index.js          # Compiled output
  package.json
  tsconfig.json
```

## Tool Definition Pattern

Each MCP tool maps to one or more external API operations:

```typescript
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";

const server = new McpServer({
  name: "service-name",
  version: "1.0.0",
});

// Define a tool
server.tool(
  "tool_name",
  "Description of what this tool does",
  {
    // Input schema (Zod)
    param1: z.string().describe("Description of param1"),
    param2: z.number().optional().describe("Optional param"),
  },
  async ({ param1, param2 }) => {
    // Call external API
    const result = await apiClient.doSomething(param1, param2);

    return {
      content: [
        {
          type: "text",
          text: JSON.stringify(result, null, 2),
        },
      ],
    };
  }
);
```

## HTTP Transport Setup

For HTTP transport (required for `*.mcp.nova-labs.ai`):

```typescript
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import express from "express";

const app = express();
app.use(express.json());

app.post("/mcp", async (req, res) => {
  const transport = new StreamableHTTPServerTransport({
    sessionIdGenerator: undefined,
  });
  res.on("close", () => transport.close());
  await server.connect(transport);
  await transport.handleRequest(req, res, req.body);
});

app.listen(3000);
```

## Credential Handling

The MCP server receives credentials via HTTP headers from the proxy:

```typescript
// Extract credentials from request headers
app.post("/mcp", async (req, res) => {
  const apiKey = req.headers["x-service-api-key"];
  const clientId = req.headers["x-service-client-id"];

  // Use credentials for API calls
  const client = new ApiClient({ apiKey, clientId });
  // ...
});
```

## Deployment

MCP HTTP backends are deployed to `*.mcp.nova-labs.ai`. The deployment process:

1. Build the server: `npm run build`
2. Containerize: `docker build -t service-mcp .`
3. Deploy to nova-labs.ai infrastructure
4. Configure DNS: `service-name.mcp.nova-labs.ai -> container`

Specific deployment details depend on the nova-labs.ai infrastructure setup.

## Dependencies

```json
{
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0",
    "express": "^4.18.0",
    "zod": "^3.22.0"
  },
  "devDependencies": {
    "typescript": "^5.0.0",
    "@types/express": "^4.17.0"
  }
}
```

## Testing

Test MCP tools locally before deploying:

```bash
# Start server locally
npm run dev

# Test with Claude Code (temporary local config)
# In plugin.json, temporarily change url to localhost:
{
  "mcpServers": {
    "service-name": {
      "type": "http",
      "url": "http://localhost:3000/mcp",
      "headers": {
        "x-api-key": "test-key"
      }
    }
  }
}
```

## Checklist

Before deploying a new MCP HTTP backend:

- [ ] All tools have clear descriptions
- [ ] Input schemas validate parameters properly
- [ ] Error responses are informative (not just "error occurred")
- [ ] Credentials are read from headers, not hardcoded
- [ ] Server handles graceful shutdown
- [ ] Dockerfile is production-ready
- [ ] DNS configured for `service-name.mcp.nova-labs.ai`
