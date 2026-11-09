---
name: modal
description: Modal.com deployment helpers and common commands.
---

### Modal

**App naming:** All files in a project should use the same `modal.App("app-name")`. Different app names create separate deployments.

**Commands:**

- `uvx modal deploy app.py` - Deploy persistently (production)
- `uvx modal serve app.py` - Dev mode with hot reload
- `uvx modal run script.py` - One-off execution (ephemeral, auto-stops)

**Secrets:**

```bash
uvx modal secret create <secret-name> KEY_NAME='value'
```

**Logs:**

```bash
uvx modal app logs <app-name>            # stream logs
uvx modal app logs <app-name> --timestamps
```

**Cleanup:**

```bash
uvx modal app list                       # see all apps
uvx modal app stop <app-name>            # stop a deployed app
```
