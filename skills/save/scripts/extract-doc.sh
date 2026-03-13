#!/usr/bin/env bash
# Extract document content using markitdown.
# Supports: .pdf, .docx, .pptx, .xlsx
# Usage: extract-doc.sh <file-path>
# Env: SAVE_CTX - output directory (default: .context)
# Output: $SAVE_CTX/extracted.txt, $SAVE_CTX/meta.json
set -euo pipefail

FILE_PATH="$1"
OUT="${SAVE_CTX:-.context}"

# Validate file exists
if [ ! -f "$FILE_PATH" ]; then
  echo "Error: File not found: $FILE_PATH" >&2
  exit 1
fi

# Get file info
FILENAME=$(basename "$FILE_PATH")
EXTENSION="${FILENAME##*.}"
EXTENSION_LOWER=$(echo "$EXTENSION" | tr '[:upper:]' '[:lower:]')

# Validate supported extension
case "$EXTENSION_LOWER" in
  pdf|docx|pptx|xlsx) ;;
  *)
    echo "Error: Unsupported file type: .$EXTENSION_LOWER (supported: pdf, docx, pptx, xlsx)" >&2
    exit 1
    ;;
esac

# Extract with markitdown
echo "Extracting $FILENAME with markitdown..." >&2
uvx --from "markitdown[all]" markitdown "$FILE_PATH" > "$OUT/extracted.txt"

# Validate output
if [ ! -s "$OUT/extracted.txt" ]; then
  echo "Error: markitdown produced empty output for $FILE_PATH" >&2
  exit 1
fi

# Compute stats
LINES=$(wc -l < "$OUT/extracted.txt" | tr -d ' ')
CHARS=$(wc -c < "$OUT/extracted.txt" | tr -d ' ')

# Extract title: first non-empty line, strip markdown heading prefix
TITLE=$(grep -m1 '.' "$OUT/extracted.txt" | sed 's/^#\+ //')
if [ -z "$TITLE" ]; then
  TITLE="$FILENAME"
fi

# Write meta.json
jq -n \
  --arg type "document" \
  --arg title "$TITLE" \
  --arg file_path "$FILE_PATH" \
  --arg extension "$EXTENSION_LOWER" \
  --argjson content_lines "$LINES" \
  --argjson content_chars "$CHARS" \
  '{
    type: $type,
    title: $title,
    file_path: $file_path,
    extension: $extension,
    content_lines: $content_lines,
    content_chars: $content_chars
  }' > "$OUT/meta.json"

echo "Extracted document to $OUT/extracted.txt ($LINES lines, $CHARS chars)"
