#!/usr/bin/env bash
# Extract content from any URL using Defuddle CLI.
# Usage: extract-defuddle.sh <url>
# Env: SAVE_CTX - output directory (default: .context)
# Output: $SAVE_CTX/extracted.txt, $SAVE_CTX/meta.json
# Exit codes: 0=success, 1=failure, 2=content too short (<200 chars)
set -euo pipefail

URL="$1"
OUT="${SAVE_CTX:-.context}"
mkdir -p "$OUT"

# Fetch with defuddle CLI (globally installed via npm)
JSON=$(defuddle parse "$URL" --json --md 2>/dev/null) || {
  echo "Error: defuddle parse failed for $URL" >&2
  exit 1
}

# Extract fields
DOMAIN=$(echo "$JSON" | jq -r '.domain // ""')
TITLE=$(echo "$JSON" | jq -r '.title // ""')
AUTHOR=$(echo "$JSON" | jq -r '.author // ""')
PUBLISHED=$(echo "$JSON" | jq -r '.published // ""')
LANGUAGE=$(echo "$JSON" | jq -r '.variables.language // .language // "unknown"')
TRANSCRIPT=$(echo "$JSON" | jq -r '.variables.transcript // empty' 2>/dev/null || true)

# Detect type
if echo "$DOMAIN" | grep -qE 'youtube\.com|youtu\.be'; then
  TYPE="youtube"
elif echo "$DOMAIN" | grep -qE 'x\.com|twitter\.com'; then
  if echo "$URL" | grep -q '/article/'; then
    TYPE="x-article"
  else
    TYPE="x-post"
  fi
elif [ -n "$TRANSCRIPT" ]; then
  TYPE="youtube"
else
  TYPE="webpage"
fi

# Select content
if [ "$TYPE" = "youtube" ] && [ -n "$TRANSCRIPT" ]; then
  CONTENT="$TRANSCRIPT"
else
  CONTENT=$(echo "$JSON" | jq -r '.content // ""')
fi

# Write extracted content
echo "$CONTENT" > "$OUT/extracted.txt"

# Compute stats
CONTENT_LINES=$(echo "$CONTENT" | wc -l | tr -d ' ')
CONTENT_CHARS=$(echo "$CONTENT" | wc -c | tr -d ' ')

# Build meta.json
META=$(jq -n \
  --arg type "$TYPE" \
  --arg title "$TITLE" \
  --arg url "$URL" \
  --arg language "$LANGUAGE" \
  --argjson content_lines "$CONTENT_LINES" \
  --argjson content_chars "$CONTENT_CHARS" \
  '{type: $type, title: $title, url: $url, language: $language, content_lines: $content_lines, content_chars: $content_chars}')

# Type-specific fields
if [ "$TYPE" = "youtube" ]; then
  CHANNEL="${AUTHOR}"
  META=$(echo "$META" | jq --arg channel "$CHANNEL" '. + {channel: $channel, duration: 0}')
fi

if [ "$TYPE" = "x-post" ] || [ "$TYPE" = "x-article" ]; then
  META=$(echo "$META" | jq --arg author "$AUTHOR" --arg timestamp "$PUBLISHED" '. + {author: $author, timestamp: $timestamp}')
  if [ "$TYPE" = "x-post" ] && [ -n "$AUTHOR" ]; then
    PREVIEW=$(echo "$CONTENT" | head -c 60 | tr '\n' ' ')
    COMPOSED_TITLE="${AUTHOR}: ${TITLE:-$PREVIEW}"
    META=$(echo "$META" | jq --arg title "$COMPOSED_TITLE" '.title = $title')
  fi
fi

echo "$META" | jq '.' > "$OUT/meta.json"

# Check content length for fallback signal
if [ "$CONTENT_CHARS" -lt 200 ]; then
  echo "Content too short (${CONTENT_CHARS} chars), fallback recommended" >&2
  exit 2
fi

echo "Extracted ${TYPE} to ${OUT}/extracted.txt (${CONTENT_LINES} lines, ${CONTENT_CHARS} chars)" >&2
exit 0
