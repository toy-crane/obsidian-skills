#!/usr/bin/env bash
# Extract web page content using Defuddle (fast, free) with Firecrawl fallback.
# Usage: extract-web.sh <url>
# Env: SAVE_CTX - output directory (default: .context)
# Output: $SAVE_CTX/extracted.txt, $SAVE_CTX/meta.json
set -euo pipefail

URL="$1"
OUT="${SAVE_CTX:-.context}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel)"

# Step 1: Try Defuddle first (fast, free, no API key needed)
echo "Trying Defuddle extraction..." >&2
DEFUDDLE_EXIT=0
SAVE_CTX="$OUT" bun "$REPO_ROOT/.claude/skills/save/scripts/defuddle.ts" "$URL" || DEFUDDLE_EXIT=$?

if [ "$DEFUDDLE_EXIT" -eq 0 ]; then
  echo "Defuddle extraction succeeded" >&2
  exit 0
fi

# Step 2: Fallback to Firecrawl (handles JS-rendered pages, costs API credits)
echo "Defuddle failed (exit=$DEFUDDLE_EXIT), falling back to Firecrawl..." >&2

if ! firecrawl scrape "$URL" --only-main-content -o "$OUT/extracted.txt" 2>/dev/null; then
  # Auth error -- try login and retry
  firecrawl login --browser 2>/dev/null || true
  firecrawl scrape "$URL" --only-main-content -o "$OUT/extracted.txt"
fi

# Validate Firecrawl output
if [ ! -s "$OUT/extracted.txt" ]; then
  echo "Error: Both Defuddle and Firecrawl failed to extract content" >&2
  exit 1
fi

# Write meta.json for Firecrawl result
LINES=$(wc -l < "$OUT/extracted.txt" | tr -d ' ')
CHARS=$(wc -c < "$OUT/extracted.txt" | tr -d ' ')
TITLE=$(head -1 "$OUT/extracted.txt" | sed 's/^#\+ //')

jq -n \
  --arg type "webpage" \
  --arg title "$TITLE" \
  --arg url "$URL" \
  --arg language "unknown" \
  --argjson content_lines "$LINES" \
  --argjson content_chars "$CHARS" \
  '{
    type: $type,
    title: $title,
    url: $url,
    language: $language,
    content_lines: $content_lines,
    content_chars: $content_chars
  }' > "$OUT/meta.json"

echo "Extracted web page (Firecrawl) to $OUT/extracted.txt ($LINES lines, $CHARS chars)"
