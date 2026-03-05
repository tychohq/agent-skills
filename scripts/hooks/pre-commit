#!/usr/bin/env bash
# pre-commit hook: require version bump in SKILL.md when skill content changes.
# Install: ln -sf ../../scripts/pre-commit-version-check.sh .git/hooks/pre-commit

set -euo pipefail

failed=0

for skill_dir in skills/*/ openclaw-skills/*/; do
  [ -d "$skill_dir" ] || continue
  [ -f "$skill_dir/SKILL.md" ] || continue

  skill_name=$(basename "$skill_dir")

  # Check if any files in this skill are staged for commit
  staged_files=$(git diff --cached --name-only -- "$skill_dir")
  [ -z "$staged_files" ] && continue

  # Check if SKILL.md version field changed in this commit
  version_changed=$(git diff --cached -- "$skill_dir/SKILL.md" | grep -E '^\+version:' || true)

  if [ -z "$version_changed" ]; then
    echo "❌ $skill_name: files changed but version not bumped in SKILL.md"
    echo "   Changed files:"
    echo "$staged_files" | sed 's/^/     /'
    echo "   → Bump the version: field in $skill_dir/SKILL.md"
    echo ""
    failed=$((failed + 1))
  fi
done

if [ "$failed" -gt 0 ]; then
  echo "Commit blocked: $failed skill(s) have changes without version bumps."
  echo "Bypass with: git commit --no-verify"
  exit 1
fi
