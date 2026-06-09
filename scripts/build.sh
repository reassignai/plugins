#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SKILL="$ROOT/skills/reassign-scheduling/SKILL.md"
echo "→ Validating canonical SKILL.md"
test -f "$SKILL" || { echo "missing $SKILL"; exit 1; }
head -1 "$SKILL" | grep -q '^---$' || { echo "SKILL.md missing frontmatter"; exit 1; }
lines=$(wc -l < "$SKILL"); [ "$lines" -le 600 ] || echo "  warn: SKILL.md is $lines lines (>500 target)"
echo "→ Regenerating client deep links from .mcp.json"
node "$ROOT/scripts/gen-deeplinks.js"
echo "✓ Build complete. Plugin + standalone skill consume skills/ in place; nothing to copy."
