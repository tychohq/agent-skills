---
name: supabase
description: Supabase helper commands for creating projects, fetching keys, and linking local projects.
---

### Supabase

Create a new project:

```bash
supabase orgs list  # get org-id
supabase projects create <project-name> \
  --org-id <org-id> \
  --db-password "$(openssl rand -base64 24 | tr -d '/+=')" \
  --region us-east-1
```

Get API keys:

```bash
supabase projects api-keys --project-ref <project-ref> -o json
```

Get JWT secret (for backend token verification):

```bash
curl -s -H "Authorization: Bearer $(cat ~/.config/supabase/access-token)" \
  "https://api.supabase.com/v1/projects/<project-ref>/postgrest" \
  | jq -r '.jwt_secret'
```

Link local project:

```bash
supabase link --project-ref <project-ref>
```
