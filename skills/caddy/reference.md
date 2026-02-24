# Caddy Reverse Proxy — Mac Mini

Self-hosted reverse proxy on the Mac Mini using Caddy. Routes `*.YOUR_DOMAIN` subdomains to local services over HTTPS. Only accessible on the Tailscale network.

## Quick Reference

- **Binary:** `~/.local/bin/caddy` (custom build with patched `caddy-dns/vercel` for team_id support)
- **Patched source:** `~/projects/caddy-vercel-patched/`
- **Caddyfile:** `~/.config/caddy/Caddyfile`
- **LaunchDaemon:** `/Library/LaunchDaemons/com.caddyserver.caddy.plist` (system-level, runs as root, KeepAlive)
- **Ports:** 443 (HTTPS), 80 (HTTP redirect) — runs as root via system LaunchDaemon
- **Bound to:** Tailscale IP only (`YOUR_TAILSCALE_IP`)
- **TLS:** Let's Encrypt via DNS-01 challenge (Vercel DNS API with team_id)
- **DNS:** `YOUR_DOMAIN` + `*.YOUR_DOMAIN` → A → `YOUR_TAILSCALE_IP`

**macOS port 443 note:** Non-root processes can't bind <1024 on macOS. Must use system LaunchDaemon (runs as root). The plist needs HOME/XDG_DATA_HOME/XDG_CONFIG_HOME env vars so Caddy can find cert storage.

**Rebuild if needed:** `cd ~/projects/caddy-vercel-patched && xcaddy build --with github.com/caddy-dns/vercel=./vercel-patched`

## Apps

| URL | App | Local Port | Repo / Source | LaunchAgent |
|-----|-----|------------|---------------|-------------|
| https://YOUR_DOMAIN | Dashboard | — (inline HTML in Caddyfile) | — | — |
| https://openclaw.YOUR_DOMAIN | OpenClaw Gateway | 18789 | `openclaw` npm package | `ai.openclaw.gateway` |
| https://crabwalk.YOUR_DOMAIN | Crabwalk Agent Monitor | 3100 | `~/.crabwalk/` | `com.yourusername.crabwalk` |
| https://webclaw.YOUR_DOMAIN | WebClaw Web Client | 3101 | `~/projects/webclaw/` | `com.yourusername.webclaw` |
| https://studio.YOUR_DOMAIN | OpenClaw Studio | 3102 | `~/projects/openclaw-studio/` | `com.yourusername.openclaw-studio` |
| https://openclaw-local.YOUR_DOMAIN | OpenClaw UI Dev Server | 3103 | — | — |
| https://deck.YOUR_DOMAIN | Deck (Agent Mission Control) | 5200 | `~/projects/deck/` | — (dev server) |

**Port convention:** Gateway on 18789, permanent apps in 3100 range, dev servers at 5200+.

**Vercel API Token:** Long-lived `vcp_*` token (no expiration, must be revoked if exposed). Stored in the LaunchDaemon plist env vars. If it stops working, create a new one at https://vercel.com/account/tokens (scope: Metagame team). You can push a new token to the live config without sudo via `curl -X POST http://localhost:2019/load` with the token hardcoded in the JSON config.

## Quick Dev Servers

Use `dev-serve` to spin up dev servers with automatic Caddy routing:

```bash
dev-serve up ~/projects/myapp        # → https://myapp.YOUR_DOMAIN
dev-serve down myapp              # clean up when done
dev-serve ls                      # list active dev servers
```

Companion skill: [dev-serve](https://clawhub.com/skills/dev-serve). Starts a tmux session, adds a Caddy route, reloads — one command.

## Architecture

```
Phone/Laptop (Tailscale)
  → DNS: *.YOUR_DOMAIN → YOUR_TAILSCALE_IP (Tailscale IP)
    → Caddy (port 443, HTTPS with Let's Encrypt certs via DNS-01 challenge)
      → reverse_proxy to localhost:<port>
```

## Key Files

| What | Path |
|------|------|
| **Caddyfile** | `~/.config/caddy/Caddyfile` |
| **Caddy binary** (custom build with patched Vercel DNS plugin) | `~/.local/bin/caddy` |
| **Caddy LaunchDaemon** | `/Library/LaunchDaemons/com.caddyserver.caddy.plist` |
| **Caddy patched source** (vercel DNS with team_id support) | `~/projects/caddy-vercel-patched/` |
| **Vercel API token** (for DNS-01 certs) | In the LaunchDaemon plist env vars |
| **Caddy logs** | `/var/log/caddy.log` and `/var/log/caddy-error.log` |
| **DNS records** | Vercel DNS for `YOUR_DOMAIN` |
| **Gateway config** | `~/.openclaw/openclaw.json` |
| **Studio settings** | `~/.openclaw/openclaw-studio/settings.json` |
| **Auto-updater** | `~/Library/LaunchAgents/com.yourusername.mini-apps-update.plist` (daily 5 AM) |

## How to Add a New App

### 1. Set up the app as a background process

Clone the repo, install deps, create a LaunchAgent plist. Follow the pattern in `~/Library/LaunchAgents/com.yourusername.webclaw.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.yourusername.APPNAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/bin/node</string>
        <string>server/index.js</string>
        <string>--dev</string>
    </array>
    <key>WorkingDirectory</key>
    <string>~/projects/APPNAME</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>HOME</key>
        <string>~</string>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
        <key>PORT</key>
        <string>31XX</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>~/Library/Logs/APPNAME.log</string>
    <key>StandardErrorPath</key>
    <string>~/Library/Logs/APPNAME-error.log</string>
</dict>
</plist>
```

Key points:
- **Bind to 0.0.0.0** so Caddy can proxy to it. Most frameworks need an explicit flag (Vite: `--host 0.0.0.0`, Next.js custom servers often default to 0.0.0.0).
- **Pick the next port** in the 3100 range (check the Apps table above).
- **ProgramArguments** — use the direct binary path, not shell wrappers. For Vite apps use `pnpm dev`, for Next.js use `node server/index.js --dev` or `npx next dev`.

Load it:
```bash
launchctl load ~/Library/LaunchAgents/com.yourusername.APPNAME.plist
```

### 2. Add to Caddyfile

Add a server block and a dashboard link:

```caddy
# App Name
appname.YOUR_DOMAIN {
    import vercel_tls
    reverse_proxy localhost:31XX
}
```

Also add a `<li>` entry in the dashboard HTML block at the top of the Caddyfile.

### 3. Reload Caddy

```bash
# Preferred: reload via admin API (no sudo needed)
~/.local/bin/caddy reload --config ~/.config/caddy/Caddyfile --address localhost:2019

# Alternative: if admin API isn't listening
~/.local/bin/caddy reload --config ~/.config/caddy/Caddyfile
```

TLS cert provisioning takes 30–60 seconds for new subdomains (DNS-01 challenge via Vercel API).

### 4. If the app connects to the OpenClaw Gateway

Apps that connect to the gateway (like Studio, WebClaw, openclaw-local) need gateway config:

**a) Add origin to allowedOrigins** in `~/.openclaw/openclaw.json`:
```json
"gateway": {
    "controlUi": {
        "allowedOrigins": [
            "https://APPNAME.YOUR_DOMAIN"
        ]
    }
}
```

**b) If the app needs device pairing**, run:
```bash
openclaw devices list       # see pending requests
openclaw devices approve <request-id>
```

**c) Restart the gateway** to pick up config changes:
```bash
launchctl kickstart -k gui/$(id -u)/ai.openclaw.gateway
```

## Gateway Config for Caddy Proxying

The gateway needs specific config in `~/.openclaw/openclaw.json` to work behind Caddy:

```json
"gateway": {
    "trustedProxies": ["127.0.0.1", "::1", "YOUR_TAILSCALE_IP"],
    "controlUi": {
        "allowInsecureAuth": true,
        "allowedOrigins": [
            "https://openclaw.YOUR_DOMAIN",
            "https://openclaw-local.YOUR_DOMAIN",
            "https://studio.YOUR_DOMAIN",
            "https://webclaw.YOUR_DOMAIN"
        ]
    }
}
```

### Why each setting matters

**`trustedProxies`** — Caddy connects to the gateway from loopback (`::1` / `127.0.0.1`). Without this, the gateway logs `Proxy headers detected from untrusted address` and ignores `X-Forwarded-For`/`X-Forwarded-Proto` headers, treating all connections as non-local. Include `YOUR_TAILSCALE_IP` (Tailscale IP) for any direct Tailscale connections.

**`allowInsecureAuth: true`** — The gateway normally requires device-key authentication (public key signature) for control UI clients. Server-side WebSocket proxies (like Studio's built-in proxy) don't support device auth. This setting allows token-only authentication. Without it, the gateway rejects with the misleading error `control ui requires HTTPS or localhost (secure context)`.

**`allowedOrigins`** — The gateway checks the `Origin` header on WebSocket upgrades for control UI and webchat clients. Any UI served from a different subdomain than the gateway itself needs its origin listed here. Without it: `origin not allowed`.

## OpenClaw Studio Specifics

Studio has a **built-in WebSocket proxy** (`/api/gateway/ws`). The browser connects to Studio, and Studio's server proxies to the upstream gateway. This means:

- The **upstream URL** in `~/.openclaw/openclaw-studio/settings.json` should be `wss://openclaw.YOUR_DOMAIN` (through Caddy, so the proxy's origin is HTTPS).
- The Studio auto-discovers the gateway token from `~/.openclaw/openclaw.json` — no need to set env vars.
- Direct `ws://localhost:18789` does NOT work as the upstream URL because the gateway's secure context check rejects the `http://localhost:18789` origin from the Node.js WebSocket client.
- The Studio's `npm run dev` runs a custom server (`node server/index.js --dev`), not `next dev` directly. Port is set via `PORT` env var, host defaults to `0.0.0.0`.

## Custom Caddy Build

The standard `caddy-dns/vercel` plugin doesn't support Vercel team accounts (missing `teamId` query parameter). A patched version was built that adds `team_id` support.

**To rebuild Caddy** (e.g., after updating):
```bash
cd ~/projects/caddy-vercel-patched
xcaddy build --with github.com/caddy-dns/vercel=./vercel-patched
cp caddy ~/.local/bin/caddy
```

## Service Management

Caddy runs as a system LaunchDaemon (needs root for port 443).

```bash
# Check status
sudo launchctl list | grep caddy

# View logs
tail -f /var/log/caddy-error.log

# Stop + Start (use legacy load/unload — more reliable than bootout/bootstrap)
sudo launchctl unload /Library/LaunchDaemons/com.caddyserver.caddy.plist
sudo launchctl load /Library/LaunchDaemons/com.caddyserver.caddy.plist

# Reload config (no restart needed, no sudo needed)
~/.local/bin/caddy reload --config ~/.config/caddy/Caddyfile --address localhost:2019
```

**Note:** `sudo launchctl bootstrap system /Library/LaunchDaemons/...` can fail with `Input/output error` if the service is already loaded. Use `unload`/`load` as a more reliable alternative.

## How HTTPS Works

Custom Caddy build with patched `vercel` DNS provider:
1. Requests Let's Encrypt cert per subdomain
2. Proves ownership via DNS-01 (creates `_acme-challenge` TXT via Vercel API with teamId)
3. Auto-renews before expiry

Works without public access — DNS-01 doesn't need inbound HTTP.

Vercel API token is stored in the Caddy LaunchDaemon plist env vars. If expired, certs fail with `No TXT record found at _acme-challenge...`. Regenerate at Vercel dashboard and update the plist.

## Troubleshooting

**Cert not issuing:**
```bash
tail -50 /var/log/caddy-error.log | grep -i error
# Common: expired Vercel API token → update in LaunchDaemon plist, restart Caddy
```

**DNS not resolving:**
```bash
dig +short appname.YOUR_DOMAIN  # should be YOUR_TAILSCALE_IP
# Wildcard *.YOUR_DOMAIN covers all subdomains
```

**App not loading through Caddy (curl exit 35 / TLS error):**
Cert hasn't provisioned yet. Wait 30-60 seconds. Check Caddy error log for ACME failures.

**Gateway: "Proxy headers detected from untrusted address":**
Add the proxy's source address to `gateway.trustedProxies` in openclaw.json. For Caddy on the same machine: `["127.0.0.1", "::1", "YOUR_TAILSCALE_IP"]`.

**Gateway: "control ui requires HTTPS or localhost (secure context)":**
This means device auth is required but the client doesn't support it. Set `gateway.controlUi.allowInsecureAuth: true` in openclaw.json.

**Gateway: "origin not allowed":**
Add the app's origin to `gateway.controlUi.allowedOrigins` in openclaw.json.

**Gateway: "pairing required":**
The device needs to be approved:
```bash
openclaw devices list
openclaw devices approve <request-id>
```

**Studio: "upstream closed" or 502:**
Check `~/Library/Logs/openclaw-studio-error.log`. Common causes:
- Upstream URL pointing to itself instead of the gateway
- Gateway not running
- Gateway rejecting the proxy's WebSocket connection (see errors above)

**WebClaw auto-update conflict:**
WebClaw has a local-only `allowedHosts` patch in `vite.config.ts`. The daily auto-updater stashes it on pull. If `pnpm-lock.yaml` also has local diffs, stash pop fails. The updater handles this with a sed fallback.
