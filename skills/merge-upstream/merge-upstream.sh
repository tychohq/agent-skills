#!/bin/bash

# merge-upstream.sh
# Deterministic script for merging upstream changes from a forked repository
# Automatically discovers upstream remote and default branches

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
COMMIT_MSG_FILE="${1:-/tmp/merge-upstream-msg.txt}"
MODE="${2:-merge}"  # "discover", "merge", or "post-merge"

# Helper functions
error() {
  echo -e "${RED}✗ $1${NC}" >&2
  exit 1
}

success() {
  echo -e "${GREEN}✓ $1${NC}"
}

warning() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

info() {
  echo -e "${BLUE}→${NC} $1"
}

# Validate we're in a git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  error "Not in a git repository"
fi

# ============================================================================
# DISCOVERY MODE: Analyze repository structure
# ============================================================================
if [[ "$MODE" == "discover" ]]; then
  info "Discovering repository structure..."

  # Get all remotes
  REMOTES=$(git remote -v | grep fetch | awk '{print $1}' | sort -u)

  if [[ -z "$REMOTES" ]]; then
    error "No remotes configured"
  fi

  # Detect upstream remote (could be 'upstream', 'source', or if no fork just 'origin')
  UPSTREAM_REMOTE=""
  ORIGIN_REMOTE=""

  for remote in $REMOTES; do
    if [[ "$remote" == "upstream" || "$remote" == "source" ]]; then
      UPSTREAM_REMOTE="$remote"
    elif [[ "$remote" == "origin" ]]; then
      ORIGIN_REMOTE="$remote"
    fi
  done

  # If no explicit upstream, origin IS the upstream
  if [[ -z "$UPSTREAM_REMOTE" ]]; then
    UPSTREAM_REMOTE="$ORIGIN_REMOTE"
    ORIGIN_REMOTE=""
    info "No upstream remote found - using origin as upstream"
  fi

  if [[ -z "$UPSTREAM_REMOTE" ]]; then
    error "Could not determine upstream remote"
  fi

  # Fetch from upstream to get latest refs
  info "Fetching from $UPSTREAM_REMOTE..."
  git fetch "$UPSTREAM_REMOTE"

  # Detect default branch for upstream
  # Try common names in order of preference
  UPSTREAM_BRANCH=""
  for branch in main master develop; do
    if git rev-parse --verify "$UPSTREAM_REMOTE/$branch" > /dev/null 2>&1; then
      UPSTREAM_BRANCH="$branch"
      break
    fi
  done

  if [[ -z "$UPSTREAM_BRANCH" ]]; then
    # Try to get from remote HEAD
    UPSTREAM_BRANCH=$(git remote show "$UPSTREAM_REMOTE" 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}')
  fi

  if [[ -z "$UPSTREAM_BRANCH" ]]; then
    error "Could not determine default branch for $UPSTREAM_REMOTE"
  fi

  # Get current branch
  CURRENT_BRANCH=$(git branch --show-current)
  if [[ -z "$CURRENT_BRANCH" ]]; then
    error "Not on a branch (detached HEAD)"
  fi

  # Get current branch's remote tracking (if any)
  TRACKING_REMOTE=$(git config --get "branch.$CURRENT_BRANCH.remote" 2>/dev/null || echo "")

  # Export discovery results
  DISCOVERY_FILE="/tmp/merge-upstream-discovery.txt"
  cat > "$DISCOVERY_FILE" << EOF
UPSTREAM_REMOTE=$UPSTREAM_REMOTE
UPSTREAM_BRANCH=$UPSTREAM_BRANCH
UPSTREAM_REF=$UPSTREAM_REMOTE/$UPSTREAM_BRANCH
ORIGIN_REMOTE=$ORIGIN_REMOTE
CURRENT_BRANCH=$CURRENT_BRANCH
TRACKING_REMOTE=$TRACKING_REMOTE
EOF

  # Also fetch origin if it exists and is different
  if [[ -n "$ORIGIN_REMOTE" && "$ORIGIN_REMOTE" != "$UPSTREAM_REMOTE" ]]; then
    info "Fetching from $ORIGIN_REMOTE..."
    git fetch "$ORIGIN_REMOTE"
  fi

  # Calculate commits
  UPSTREAM_REF="$UPSTREAM_REMOTE/$UPSTREAM_BRANCH"
  MERGE_BASE=$(git merge-base HEAD "$UPSTREAM_REF" 2>/dev/null || echo "")

  if [[ -z "$MERGE_BASE" ]]; then
    warning "No common ancestor with upstream - branches may have diverged significantly"
    BEHIND_COUNT="?"
    AHEAD_COUNT="?"
  else
    BEHIND_COUNT=$(git rev-list --count "HEAD..$UPSTREAM_REF")
    AHEAD_COUNT=$(git rev-list --count "$UPSTREAM_REF..HEAD")
  fi

  # Add counts to discovery file
  cat >> "$DISCOVERY_FILE" << EOF
MERGE_BASE=$MERGE_BASE
BEHIND_COUNT=$BEHIND_COUNT
AHEAD_COUNT=$AHEAD_COUNT
EOF

  success "Discovery complete"
  echo ""
  echo "Repository structure:"
  echo "  Upstream remote: $UPSTREAM_REMOTE"
  echo "  Upstream branch: $UPSTREAM_BRANCH"
  if [[ -n "$ORIGIN_REMOTE" && "$ORIGIN_REMOTE" != "$UPSTREAM_REMOTE" ]]; then
    echo "  Fork remote: $ORIGIN_REMOTE"
  fi
  echo "  Current branch: $CURRENT_BRANCH"
  echo ""
  echo "Sync status:"
  echo "  Behind upstream: $BEHIND_COUNT commits"
  echo "  Ahead of upstream: $AHEAD_COUNT commits"
  echo ""
  info "Discovery exported to: $DISCOVERY_FILE"

  exit 0
fi

# ============================================================================
# MERGE MODE: Perform the actual merge
# ============================================================================

# Load discovery data
DISCOVERY_FILE="/tmp/merge-upstream-discovery.txt"
if [[ ! -f "$DISCOVERY_FILE" ]]; then
  error "Discovery file not found. Run with MODE=discover first."
fi

source "$DISCOVERY_FILE"

if [[ -z "$UPSTREAM_REF" ]]; then
  error "UPSTREAM_REF not set in discovery file"
fi

info "Merging from: $UPSTREAM_REF"
info "Into: $CURRENT_BRANCH"

# Validate working directory is clean
if [[ -n $(git status --porcelain) ]]; then
  error "Working directory is not clean. Commit or stash your changes first."
fi

# Check if already up to date
if [[ "$BEHIND_COUNT" == "0" ]]; then
  success "Already up to date with upstream"
  exit 0
fi

# Export commit list for skill to analyze
COMMIT_LIST_FILE="/tmp/merge-upstream-commits.txt"
git log --format="%H%x00%s%x00%an%x00%b%x00---" "$MERGE_BASE..$UPSTREAM_REF" > "$COMMIT_LIST_FILE"
info "Commit list exported to: $COMMIT_LIST_FILE"
info "Found $BEHIND_COUNT commits to merge"

# Check if commit message file exists
if [[ ! -f "$COMMIT_MSG_FILE" ]]; then
  info "Waiting for commit message file: $COMMIT_MSG_FILE"
  exit 3  # Special exit code: need commit message
fi

# Perform the merge
info "Merging upstream changes..."
if git merge "$UPSTREAM_REF" --no-edit -m "$(cat "$COMMIT_MSG_FILE")"; then
  success "Merge completed successfully"
else
  # Check if there are conflicts
  if [[ -n $(git diff --name-only --diff-filter=U) ]]; then
    warning "Merge conflicts detected"

    # Export conflict information
    CONFLICT_DIR="/tmp/merge-upstream-conflicts"
    rm -rf "$CONFLICT_DIR"
    mkdir -p "$CONFLICT_DIR"

    CONFLICT_FILES=$(git diff --name-only --diff-filter=U)
    echo "$CONFLICT_FILES" | while read -r file; do
      if [[ -n "$file" ]]; then
        git show :2:"$file" > "$CONFLICT_DIR/$(echo "$file" | tr '/' '_').ours" 2>/dev/null || true
        git show :3:"$file" > "$CONFLICT_DIR/$(echo "$file" | tr '/' '_').theirs" 2>/dev/null || true
        echo "$file" >> "$CONFLICT_DIR/file-list.txt"
      fi
    done

    CONFLICT_COUNT=$(echo "$CONFLICT_FILES" | wc -l | tr -d ' ')
    warning "Found $CONFLICT_COUNT conflicted files"
    info "Conflict details exported to: $CONFLICT_DIR"

    exit 2  # Special exit code: conflicts need resolution
  else
    error "Merge failed for unknown reason"
  fi
fi

exit 0

# ============================================================================
# POST-MERGE MODE: Quality checks and cleanup
# ============================================================================
if [[ "$MODE" == "post-merge" ]]; then
  info "Running post-merge quality checks..."

  # Type checking
  if [[ -f "package.json" ]] && grep -q "typecheck" package.json; then
    if bun run typecheck > /dev/null 2>&1; then
      success "Type checking passed"
    else
      warning "Type checking failed - review required"
    fi
  fi

  # Linting
  if [[ -f "package.json" ]] && grep -q "lint" package.json; then
    if bun run lint > /dev/null 2>&1; then
      success "Linting passed"
    else
      warning "Linting issues detected"
    fi
  fi

  # Tests
  if [[ -f "package.json" ]] && grep -q "\"test\"" package.json; then
    if bun test > /dev/null 2>&1; then
      success "Tests passed"
    else
      warning "Tests failed - review changes"
    fi
  fi

  # Show summary
  info ""
  info "═══════════════════════════════════════"
  success "Merge completed!"
  info "═══════════════════════════════════════"

  # Show what was merged
  source "$DISCOVERY_FILE"
  echo ""
  echo "Merged $BEHIND_COUNT commits from $UPSTREAM_REF"
  echo "Your branch has $AHEAD_COUNT commits ahead of upstream"
  echo ""

  git log -1 --stat

  exit 0
fi
