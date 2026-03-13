#!/usr/bin/env bash
# Extract YouTube video transcript and metadata using Defuddle.
# Usage: extract-yt.sh <url>
# Env: SAVE_CTX - output directory (default: .context)
# Output: $SAVE_CTX/extracted.txt, $SAVE_CTX/meta.json
set -euo pipefail

URL="$1"
OUT="${SAVE_CTX:-.context}"
REPO_ROOT="$(git rev-parse --show-toplevel)"

SAVE_CTX="$OUT" bun "$REPO_ROOT/.claude/skills/save/scripts/defuddle.ts" "$URL"
