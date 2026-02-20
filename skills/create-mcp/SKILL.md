---
name: create-mcp
description: Create a new MCP server from API documentation. Sets up project structure, secrets, and Claude config.
---

# Create MCP Server

Create a Model Context Protocol (MCP) server following our established patterns.

## Input

User provides a **top-level URL** for the service (e.g., `hunter.io`, `twilio.com`).

## Step 1: Find API Documentation

Use `WebSearch` to find the API documentation:
- Search for "[service name] API documentation"
- Look for developer docs, API reference, or REST API pages

Only use `AskUserQuestion` if you genuinely cannot find the API docs after searching.

## Step 2: Understand the API

Use `WebFetch` to read the API documentation and extract:
- **All available endpoints** - List what the API can do
- **Authentication method** - API key, OAuth, bearer token, etc.
- **Base URL** - The API's base endpoint
- **Response formats** - What data comes back

## Step 3: Select Tools to Implement

Present the user with the available API endpoints and ask which ones to expose as MCP tools.

Use `AskUserQuestion` with options like:
- List the main endpoint categories/capabilities
- Let user select which ones to implement
- Ask about response format preference (minimal vs full)

**Important:** We typically don't want ALL endpoints - just the most useful ones.

## Project Structure

Create in `~/projects/[name]-mcp/`:

```
[name]-mcp/
├── src/
│   └── index.ts      # Single-file implementation
├── package.json
├── tsconfig.json
├── biome.jsonc
└── README.md
```

## Step 4: Create Project Files

### package.json

```json
{
  "name": "[name]-mcp",
  "version": "1.0.0",
  "description": "MCP server for [Service Name]",
  "type": "module",
  "main": "src/index.ts",
  "bin": {
    "[name]-mcp": "src/index.ts"
  },
  "scripts": {
    "start": "tsx src/index.ts",
    "typecheck": "tsc --noEmit"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^1.0.0",
    "dotenv": "^17.2.3",
    "zod": "^3.24.0"
  },
  "devDependencies": {
    "@biomejs/biome": "^1.9.4",
    "@types/node": "^22.10.2",
    "tsx": "^4.0.0",
    "typescript": "^5.7.2"
  }
}
```

### tsconfig.json

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "NodeNext",
    "moduleResolution": "NodeNext",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "noEmit": true
  },
  "include": ["src"]
}
```

### biome.jsonc

```json
{
  "$schema": "https://biomejs.dev/schemas/1.9.4/schema.json",
  "organizeImports": { "enabled": true },
  "linter": { "enabled": true, "rules": { "recommended": true } },
  "formatter": { "enabled": true, "indentStyle": "tab" },
  "javascript": { "formatter": { "semicolons": "asNeeded" } }
}
```

### src/index.ts Template

```typescript
#!/usr/bin/env npx tsx
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js"
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js"
import { config as loadEnv } from "dotenv"
import os from "node:os"
import path from "node:path"
import { z } from "zod"

// Load credentials from ~/.claude/secrets/[name]/.env
const envPath = path.join(os.homedir(), ".claude", "secrets", "[name]", ".env")
loadEnv({ path: envPath })

const apiKey = process.env.[ENV_VAR_NAME] || ""

if (!apiKey) {
	console.error(`Missing API key. Create ${envPath} with:`)
	console.error("[ENV_VAR_NAME]=your_api_key")
	process.exit(1)
}

const BASE_URL = "[API_BASE_URL]"

// Define response types
interface SomeResponse {
	data: {
		// fields...
	}
}

const server = new McpServer({
	name: "[name]-mcp",
	version: "1.0.0",
})

// Define tools using server.registerTool()
server.registerTool(
	"tool_name",
	{
		title: "Tool Title",
		description: "Tool description",
		inputSchema: {
			param1: z.string().describe("Parameter description"),
			param2: z.number().optional().describe("Optional parameter"),
		},
	},
	async ({ param1, param2 }) => {
		try {
			const params = new URLSearchParams({
				param1,
				api_key: apiKey,
			})

			const response = await fetch(`${BASE_URL}/endpoint?${params}`)
			const json = (await response.json()) as SomeResponse

			if (!response.ok) {
				return {
					content: [{ type: "text" as const, text: `Error: ${JSON.stringify(json)}` }],
					isError: true,
				}
			}

			// Return minimal response
			const result = {
				// extract only needed fields
			}

			return {
				content: [{ type: "text" as const, text: JSON.stringify(result) }],
			}
		} catch (error) {
			return {
				content: [{
					type: "text" as const,
					text: `Error: ${error instanceof Error ? error.message : String(error)}`,
				}],
				isError: true,
			}
		}
	},
)

async function main() {
	const transport = new StdioServerTransport()
	await server.connect(transport)
}

main().catch(console.error)
```

## Step 5: Set Up Secrets

Create the secrets directory and placeholder file:

```bash
mkdir -p ~/.claude/secrets/[name]
echo "[ENV_VAR_NAME]=your_key_here" > ~/.claude/secrets/[name]/.env
```

Tell the user to replace the placeholder with their actual API key.

## Step 6: Install Dependencies

```bash
cd ~/projects/[name]-mcp && pnpm install
```

## Step 7: Run Typecheck

```bash
pnpm typecheck
```

Fix any type errors before proceeding.

## Step 8: Initialize Git

```bash
git init
echo "node_modules" > .gitignore
```

## Step 9: Verify No Secrets & Push to GitHub

**Before pushing, verify no secrets are in the code:**

1. Search the codebase for hardcoded secrets:
   ```bash
   grep -r "api_key\|apikey\|secret\|token\|password" src/ --include="*.ts" | grep -v "process.env"
   ```

2. Confirm all credentials are loaded from `~/.claude/secrets/[name]/.env` via `process.env`

3. Check `.gitignore` includes `node_modules` and any local env files

**Push to GitHub as a public repo:**

```bash
gh repo create [name]-mcp --public --source=. --push
```

## Step 10: Add to Claude Config

Add the MCP to `~/.claude.json` under `mcpServers`:

```json
"[name]": {
  "type": "stdio",
  "command": "npx",
  "args": [
    "tsx",
    "~/projects/[name]-mcp/src/index.ts"
  ]
}
```

## Step 11: Create README

Include:
- What the MCP does
- Setup instructions (secrets location, Claude config)
- Available tools with parameters and return values

## Completion Checklist

- [ ] Project created in `~/projects/[name]-mcp/`
- [ ] All files written (package.json, tsconfig, biome, src/index.ts, README)
- [ ] Dependencies installed (`pnpm install`)
- [ ] Typecheck passes (`pnpm typecheck`)
- [ ] Git initialized with .gitignore
- [ ] **No secrets in code** - all credentials via `process.env`
- [ ] Pushed to GitHub as public repo
- [ ] Secrets directory created at `~/.claude/secrets/[name]/`
- [ ] MCP added to `~/.claude.json`
- [ ] User informed to add API key and restart Claude Code

## Reference Examples

See these MCPs for patterns:
- `~/projects/hunter-mcp/` - Simple API with fetch
- `~/projects/twilio-mcp/` - Using an SDK client
- `~/projects/anylist-mcp/` - Async client initialization
