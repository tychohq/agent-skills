---
name: caddy
description: Add, manage, and troubleshoot Caddy reverse proxy routes for local apps on YOUR_DOMAIN.
---

# Caddy — Add, Manage, and Troubleshoot Apps on Mac Mini

Routes `*.YOUR_DOMAIN` subdomains to local services over HTTPS via Caddy reverse proxy. Only accessible on the Tailscale network.

## Add a New App

1. **Create a LaunchAgent** — see `reference.md` for the plist template
2. **Add to Caddyfile** (`~/.config/caddy/Caddyfile`):
   ```caddy
   appname.YOUR_DOMAIN {
       import vercel_tls
       reverse_proxy localhost:31XX
   }
   ```
   Also add a `<li>` entry in the dashboard HTML block at the top.
3. **Reload Caddy:**
   ```bash
   ~/.local/bin/caddy reload --config ~/.config/caddy/Caddyfile --address localhost:2019
   ```
   TLS cert provisioning takes 30–60 seconds (DNS-01 challenge).
4. **If it connects to OpenClaw Gateway** — add its origin to `allowedOrigins` in `~/.openclaw/openclaw.json`, then restart gateway.

## Quick Dev Servers

Companion skill: [dev-serve](https://clawhub.com/skills/dev-serve) — one-command dev server + Caddy routing.

```bash
dev-serve up ~/projects/myapp        # → https://myapp.YOUR_DOMAIN
dev-serve down myapp
dev-serve ls
```

## Reload / Restart

```bash
# Reload config (no restart, no sudo)
~/.local/bin/caddy reload --config ~/.config/caddy/Caddyfile --address localhost:2019

# Full restart (needs sudo)
sudo launchctl unload /Library/LaunchDaemons/com.caddyserver.caddy.plist
sudo launchctl load /Library/LaunchDaemons/com.caddyserver.caddy.plist
```

## Rebuild Caddy Binary

```bash
cd ~/projects/caddy-vercel-patched
xcaddy build --with github.com/caddy-dns/vercel=./vercel-patched
cp caddy ~/.local/bin/caddy
```

## Troubleshoot

- **Cert not issuing:** `tail -50 /var/log/caddy-error.log | grep -i error` — likely expired Vercel API token
- **DNS not resolving:** `dig +short appname.YOUR_DOMAIN` — should be `100.108.127.85`
- **TLS error (curl exit 35):** Cert hasn't provisioned yet, wait 30-60s
- **Gateway "origin not allowed":** Add origin to `gateway.controlUi.allowedOrigins`
- **Gateway "secure context" error:** Set `gateway.controlUi.allowInsecureAuth: true`

For full reference (apps table, key files, gateway config, Studio specifics): see `reference.md` in this folder.
