# Agent Skills by Brenner Spear

A curated collection of agent skills — tested, maintained, and ready to use.

These skills follow the open [Agent Skills](https://agentskills.io) standard (`SKILL.md` format) and work with Claude Code, Codex, Cursor, Copilot, Cline, Windsurf, OpenClaw, and 18+ other agent platforms.

## Repo Structure

```
skills/              ← Platform-agnostic skills (discovered by skills.sh)
openclaw-skills/     ← OpenClaw-specific skills (ClawHub only)
```

**`skills/`** — Works with any agent. Installed via `npx skills add` or `clawhub install`.

**`openclaw-skills/`** — Depends on OpenClaw's session system, workspace layout, or cron infrastructure. Published to [ClawHub](https://clawhub.com) only. Not discovered by skills.sh.

## Install

### Via [skills.sh](https://skills.sh) (cross-agent)
```bash
# Install all portable skills
npx skills add brennerspear/agent-skills

# Install a specific skill
npx skills add brennerspear/agent-skills --skill commit
```

### Via [ClawHub](https://clawhub.com) (OpenClaw)
```bash
# Portable skills
clawhub install brennerspear/<skill-name>

# OpenClaw-specific skills
clawhub install brennerspear/<skill-name>  # from openclaw-skills/
```

### Manual
Copy any skill folder into your agent's skills directory.

## Skills

### Developer Tools
| Skill | Description |
|---|---|
| **[commit](skills/commit/)** | Create git commits with contextual messages and push |
| **[deslop](skills/deslop/)** | Remove AI-style code slop from a branch |
| **[diagrams](skills/diagrams/)** | Generate flow diagrams, architecture diagrams, system maps (ELK → SVG/PNG) |
| **[architecture-research](skills/architecture-research/)** | Research and diagram codebase architecture |
| **[tmux](skills/tmux/)** | Remote-control tmux sessions for interactive CLIs |
| **[domain-check](skills/domain-check/)** | Check domain availability and manage domains via Vercel |
| **[vercel](skills/vercel/)** | Deploy and manage Vercel projects |
| **[vercel-speed-audit](skills/vercel-speed-audit/)** | Audit and optimize Vercel build and deploy speed |

### Research & Productivity
| Skill | Description |
|---|---|
| **[research](skills/research/)** | Conduct deep research with interactive + deep research modes |
| **[flights](skills/flights/)** | Search flights via Google Flights |

### Infrastructure
| Skill | Description |
|---|---|
| **[caddy](skills/caddy/)** | Manage Caddy reverse proxy routes |
| **[dev-serve](skills/dev-serve/)** | Start and manage tmux-backed dev servers exposed via Caddy |

### Integrations
| Skill | Description |
|---|---|
| **[amazon](skills/amazon/)** | Buy and return items on Amazon via browser automation |

### OpenClaw-Specific (`openclaw-skills/`)
| Skill | Description |
|---|---|
| **[cron-setup](openclaw-skills/cron-setup/)** | Create and manage OpenClaw cron jobs |
| **[self-reflection](openclaw-skills/self-reflection/)** | Periodic self-reflection on recent sessions |
| **[system-watchdog](openclaw-skills/system-watchdog/)** | Monitor system health with OpenClaw cron integration |

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
