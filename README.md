# Agent Skills by Brenner Spear

A curated collection of agent skills — tested, maintained, and ready to use.

These skills follow the open [Agent Skills](https://agentskills.io) standard (`SKILL.md` format) and work with Claude Code, Codex, Cursor, Copilot, Cline, Windsurf, OpenClaw, and 18+ other agent platforms.

## Install

### Via [skills.sh](https://skills.sh) (cross-agent)
```bash
npx skills add brennerspear/agent-skills
```

### Via [ClawHub](https://clawhub.com) (OpenClaw)
```bash
clawhub install brennerspear/<skill-name>
```

### Manual
Copy any skill folder into your agent's skills directory.

## Skills

### Developer Tools
| Skill | Description |
|---|---|
| **[commit](skills/commit/)** | Create git commits with contextual messages and push |
| **[deslop](skills/deslop/)** | Remove AI-style code slop from a branch |
| **[merge-upstream](skills/merge-upstream/)** | Intelligently merge upstream changes from a fork |
| **[create-mcp](skills/create-mcp/)** | Create MCP servers from API documentation |
| **[diagrams](skills/diagrams/)** | Generate flow diagrams, architecture diagrams, system maps (ELK → SVG/PNG) |
| **[architecture-research](skills/architecture-research/)** | Research and diagram codebase architecture |
| **[tmux](skills/tmux/)** | Remote-control tmux sessions for interactive CLIs |
| **[domain-check](skills/domain-check/)** | Check domain availability and manage domains via Vercel |
| **[vercel](skills/vercel/)** | Deploy and manage Vercel projects |
| **[vercel-speed](skills/vercel-speed/)** | Optimize Vercel build and deploy speed |

### Research & Productivity
| Skill | Description |
|---|---|
| **[research](skills/research/)** | Conduct deep research with interactive + deep research modes |
| **[flights](skills/flights/)** | Search flights via Google Flights |
| **[cron-setup](skills/cron-setup/)** | Create and manage scheduled tasks |
| **[self-reflection](skills/self-reflection/)** | Periodic self-reflection on recent sessions |

### Infrastructure
| Skill | Description |
|---|---|
| **[caddy](skills/caddy/)** | Manage Caddy reverse proxy routes |
| **[system-watchdog](skills/system-watchdog/)** | Monitor system health and resource usage |

### Integrations
| Skill | Description |
|---|---|
| **[agentmail](skills/agentmail/)** | AI-native email — create inboxes, send/receive programmatically |
| **[amazon](skills/amazon/)** | Buy and return items on Amazon via browser automation |

## Requirements

Each skill documents its own requirements in the `SKILL.md` file. Common requirements include:
- **CLI tools:** `git`, `gh`, `ffmpeg`, `jq`, `caddy`, etc.
- **API keys:** Set via environment variables (never hardcoded)
- **Browser automation:** `agent-browser` + Chrome with CDP for web-based skills

## Updates

```bash
# skills.sh
npx skills check    # check for updates
npx skills update   # pull updates

# ClawHub
clawhub update --all
```

## Contributing

Found a bug or have an improvement? Open an issue or PR.

## License

MIT
