#!/usr/bin/env bash
# sanitize.sh — Check for PII patterns in skill files before publishing.
# Usage: ./scripts/sanitize.sh [path-to-scan]
# Defaults to ./skills/ if no path given.

set -euo pipefail

TARGET="${1:-./skills}"
FOUND=0

# Patterns to flag (case-insensitive where appropriate)
PATTERNS=(
  # Personal identifiers
  "brenner"
  "blspear"
  "BrennerSpear"

  # Addresses / locations
  "11211"          # ZIP code
  "williamsburg"
  "150 South First"
  "Brooklyn, NY"

  # Hardcoded home paths
  "/Users/brenner"
  "/home/brenner"

  # Domains
  "mini\.brennerspear\.com"
  "brennerspear\.com"

  # Credit card / payment
  "1340"           # card last 4
  "Prime Visa"

  # SSH / machine names
  "Brenners-Mac"
  "nuc"

  # Tokens / keys (generic patterns)
  "sk-[a-zA-Z0-9]"
  "token.*=.*['\"]"

  # Service-specific IDs that shouldn't be hardcoded
  "team_[a-zA-Z0-9]\{20,\}"   # Vercel team IDs
  "metagame-xyz"

  # Discord / Telegram IDs that look personal
  "213168100038803456"
)

echo "🔍 Scanning $TARGET for PII patterns..."
echo ""

for pattern in "${PATTERNS[@]}"; do
  matches=$(grep -rn "$pattern" "$TARGET" 2>/dev/null || true)
  if [ -n "$matches" ]; then
    echo "⚠️  Pattern: $pattern"
    echo "$matches" | head -10
    echo ""
    FOUND=$((FOUND + 1))
  fi
done

if [ "$FOUND" -eq 0 ]; then
  echo "✅ No PII patterns found. Clean to publish."
  exit 0
else
  echo "❌ Found $FOUND PII pattern(s). Review and fix before publishing."
  exit 1
fi
