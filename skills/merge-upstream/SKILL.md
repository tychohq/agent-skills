---
name: merge-upstream
description: Intelligently merge upstream changes from a forked repository with safe discovery and summaries.
---

# Merge Upstream

Intelligently merge upstream changes from a forked repository. Automatically discovers the upstream remote, default branches, and sync status before merging.

## Usage

Run `/merge-upstream` to merge the latest changes from upstream into your current branch.

The skill will automatically:
1. Discover your repository structure (fork vs non-fork)
2. Identify the upstream remote (`upstream`, `source`, or `origin`)
3. Detect the default branch (`main`, `master`, etc.)
4. Show how many commits you're behind/ahead
5. Merge changes and help resolve conflicts
6. Push to your fork and optionally create a PR

## Process

### 1. Discovery Phase

Run the discovery script to analyze the repository:

```bash
SKILL_DIR="$HOME/projects/claude-code-skills/merge-upstream"
"$SKILL_DIR/merge-upstream.sh" "/tmp/merge-upstream-msg.txt" "discover"
```

This will:
- Detect all remotes (origin, upstream, etc.)
- Identify which is the "true" upstream (source repo) vs your fork
- Find the default branch for each remote
- Calculate commits behind/ahead
- Export results to `/tmp/merge-upstream-discovery.txt`

Read the discovery file and report to the user:
- Repository structure (upstream remote, fork remote, current branch)
- Sync status (X commits behind, Y commits ahead)

If already up to date (0 commits behind), stop here.

### 2. Analyze Upstream Commits

Read `/tmp/merge-upstream-commits.txt` which contains commits in format:
```
<hash>\0<subject>\0<author>\0<body>\0---
```

Analyze the commits to generate a summary:
- **Group by type**: features, fixes, refactors, docs, chores
- **Identify reverts**: Skip commits that are reverted by later commits
- **Extract key changes**: New features, bug fixes, breaking changes, dependency updates
- **Note the author(s)**: Usually one main author for upstream

### 3. Generate Commit Message

Write a commit message to `/tmp/merge-upstream-msg.txt`:

```
Merge upstream/<branch>: <brief summary>

Merges N commits from <upstream-repo>

## Features
- <list new features>

## Fixes
- <list bug fixes>

## Other Changes
- <refactors, docs, chores>

## Technical Notes
- <breaking changes, dependency updates, etc>
```

### 4. Execute Merge

```bash
SKILL_DIR="$HOME/projects/claude-code-skills/merge-upstream"
"$SKILL_DIR/merge-upstream.sh" "/tmp/merge-upstream-msg.txt" "merge"
```

Exit codes:
- `0` - Merge successful
- `2` - Conflicts need resolution
- `3` - Waiting for commit message (shouldn't happen if step 3 done)

### 5. Conflict Resolution (if needed)

When exit code is 2, conflicts are exported to `/tmp/merge-upstream-conflicts/`:
- `file-list.txt` - List of conflicted files
- `<file>.ours` - Your version (current branch)
- `<file>.theirs` - Upstream version

For each conflict:

1. **Read both versions** from the conflict directory
2. **Analyze the differences**:
   - Changes in different sections → merge both
   - Overlapping changes → evaluate which is better
3. **Resolution strategy**:
   - Default: prefer theirs (upstream) for most code changes
   - Prefer ours for: local customizations, config specific to your fork
   - Manual merge when both have valuable changes
4. **Apply resolution**:

```bash
# Use upstream version (most common)
git checkout --theirs <file>
git add <file>

# Use our version
git checkout --ours <file>
git add <file>

# Manual merge: edit the file directly, then:
git add <file>
```

5. **Complete the merge**:

```bash
git commit --no-edit
```

### 6. Post-Merge Verification

Run quality checks:

```bash
bun run lint && bun run typecheck && bun run test
```

Report results to user. Fix any issues introduced by the merge.

### 7. Push and Summarize

```bash
# Load discovery data for remote info
source /tmp/merge-upstream-discovery.txt

# Push to your fork (origin)
git push origin $CURRENT_BRANCH
```

Provide a summary to the user:
- Number of commits merged
- Key changes included
- Any conflicts that were resolved
- Current sync status (should now be 0 behind, Y ahead)

### 8. Optional: Create PR to Upstream

If the user has local commits they want to contribute back:

```bash
# Create PR to upstream repo
gh pr create \
  --repo <upstream-owner>/<repo> \
  --base <upstream-branch> \
  --head <your-username>:<current-branch> \
  --title "feat: <description of your changes>" \
  --body "$(cat <<'EOF'
## Summary
<description of what your commits add>

## Changes
<list of your local commits>

## Testing
<how you tested the changes>
EOF
)"
```

### 9. Cleanup

```bash
rm -f /tmp/merge-upstream-msg.txt
rm -f /tmp/merge-upstream-commits.txt
rm -f /tmp/merge-upstream-discovery.txt
rm -rf /tmp/merge-upstream-conflicts
```

## Fork vs Non-Fork Detection

The script automatically handles both scenarios:

**Fork scenario** (most common):
- `origin` = your fork (your-username/your-fork)
- `upstream` = source repo (gbasin/agentboard)
- Merges from `upstream/master` into your local branch
- Pushes to `origin`

**Non-fork scenario**:
- Only `origin` exists
- `origin` IS the upstream
- Merges from `origin/main` into your local branch

## Script Exit Codes

- `0` - Success
- `1` - Error (validation failed, not a git repo, etc.)
- `2` - Conflicts detected (need resolution)
- `3` - Waiting for commit message file

## Recovery

If something goes wrong:

```bash
# Abort the merge
git merge --abort

# Or reset to before the merge
git reset --hard HEAD~1
```

## Example Session

```
User: /merge-upstream

Skill: Running discovery...

Repository structure:
  Upstream remote: upstream (gbasin/agentboard)
  Upstream branch: master
  Fork remote: origin (your-username/your-fork)
  Current branch: main

Sync status:
  Behind upstream: 25 commits
  Ahead of upstream: 6 commits (your local changes)

Analyzing 25 upstream commits...

Key changes from upstream:
- feat: add structured logger with levels and JSON output
- feat: pipe-pane terminal mode for daemon/systemd
- feat: improved external session handling
- fix: iOS touch handling improvements
- fix: various stability fixes

Generating commit message...
Executing merge...

✓ Merge completed successfully!

Pushing to origin...
✓ Pushed to origin/main

Summary:
- Merged 25 commits from upstream/master
- No conflicts
- Your 6 local commits preserved
- Tests passing
```

## Files

- `merge-upstream.sh` - Bash script for git operations
- `SKILL.md` - This skill documentation
