---
name: save
description: Save any content (YouTube, web page, X post, document, text, or conversation) to Obsidian
argument-hint: "[--orig] <url or text content>"
user-invocable: true
---

# Content Save v2

Routes content to source-specific extraction, then applies common metadata/save pipeline. Uses an isolated `.context/<id>/` directory per invocation for file-based handoff between phases.

## Step 1: Initialize Context Directory

```bash
SAVE_CTX=".context/$(uuidgen | cut -c1-8)"
mkdir -p "$SAVE_CTX"
```

All intermediate files are written to `$SAVE_CTX/`. This ensures parallel save invocations never collide.

## Step 2: Get Input

Input is provided in `$ARGUMENTS`.

### Parse flags

- **`--orig` flag**: If `$ARGUMENTS` starts with `--orig`, set `keep_original_lang = true` and strip `--orig` (plus any leading whitespace that follows) from `$ARGUMENTS`.
- Default: `keep_original_lang = false`

### Check input

- **If empty** (after stripping): Ask the user with `AskUserQuestion`: "What kind of note should I write from this conversation? (e.g., guide, summary, reference)". Use their answer as `user_requirements` and skip to Step 5 Conversation path.

## Step 3: Detect Input Type

Check in this order:

1. **YouTube URL** - Contains `youtube.com/watch?v=`, `youtu.be/`, `youtube.com/shorts/`, `youtube.com/live/`, or `m.youtube.com/watch?v=`
2. **X/Twitter URL** - Contains `x.com/` or `twitter.com/`
3. **Web URL** - Starts with `http://` or `https://` (not YouTube, not X)
4. **Document File** - File path ending in `.pdf`, `.docx`, `.pptx`, or `.xlsx`
5. **Conversation Intent** - Contains "this conversation", "conversation", or similar phrases. Set `user_requirements = $ARGUMENTS` and route to Conversation.
6. **Raw Text** - Everything else

## Step 4: Check Duplicate (URL only)

Skip for Document File, Raw Text, and Conversation.

```bash
grep -rl "source:.*<URL>" --include="*.md" .
```

If match found:
1. Read matched file's frontmatter for title and path
2. Notify user: "Already saved: `[path]` ([title])"
3. `AskUserQuestion`: options `["Overwrite", "Skip"]`
   - **Overwrite**: `rm <path>`, continue
   - **Skip**: Abort

## Step 5: Phase 1 -- Extract (source-specific)

### YouTube

1. Run extraction:
```
Bash: .claude/skills/save/scripts/extract-yt.sh "<URL>"
```

2. **Validate** (Change #2): Check exit code AND `$SAVE_CTX/extracted.txt` non-empty. If failed, inform user and abort.

### X Post

Run extraction:
```
Bash: .claude/skills/save/scripts/extract-x.sh "<URL>"
```

**Validate** (Change #2): Check exit code AND `$SAVE_CTX/extracted.txt` non-empty. If failed, inform user and abort.

### Web Page

Run extraction:
```
Bash: .claude/skills/save/scripts/extract-web.sh "<URL>"
```

**Validate**: Check exit code AND `$SAVE_CTX/extracted.txt` non-empty. If failed, inform user and abort.

### Document File

Run extraction:
```
Bash: .claude/skills/save/scripts/extract-doc.sh "<FILE_PATH>"
```

**Validate**: Check exit code AND `$SAVE_CTX/extracted.txt` non-empty. If failed, inform user and abort.

### Raw Text

Write input directly:
1. Write `$ARGUMENTS` content to `$SAVE_CTX/extracted.txt` using Write tool
2. Write `{ "type": "text" }` to `$SAVE_CTX/meta.json` using Write tool

### Conversation

Follow `.claude/skills/save/conversation.md` guide directly (not in subagent):
1. Read `conversation.md`
2. Execute its workflow with `user_requirements`
3. Result: `$SAVE_CTX/extracted.txt` + `$SAVE_CTX/meta.json`

## Step 6: Restructure

**Skip for**: Raw Text (respect user formatting), Conversation (already markdown), Web Page (already returns structured markdown), Document File (markitdown already returns markdown).

### YouTube

1. Read `$SAVE_CTX/extracted.txt` (the raw transcript).
2. Read `.claude/skills/restructure-transcript/SKILL.md` and follow its workflow to restructure the transcript into clean prose.
3. Overwrite `$SAVE_CTX/extracted.txt` with the restructured result using the Write tool.

### X Post

1. Read `$SAVE_CTX/extracted.txt` (raw X post/article text with formatting stripped).
2. Restore markdown formatting:
   - Add heading levels (##, ###) where appropriate
   - Add paragraph breaks between logical sections
   - Format lists, quotes, and emphasis
   - Image/figure references -> italicized captions
   - Do NOT rephrase, summarize, or add content -- structure only
3. Overwrite `$SAVE_CTX/extracted.txt` with the result using the Write tool.

## Step 7: Detect Language + Translate

**Skip translation entirely if**: `keep_original_lang = true` OR content is already Korean.

Detect language per type:
- **YouTube**: Read `$SAVE_CTX/meta.json` language field.
- **X Post**: Inspect `$SAVE_CTX/extracted.txt` first few lines.
- **Web Page**: Read `$SAVE_CTX/meta.json` language field. If empty, inspect `$SAVE_CTX/extracted.txt` first few lines.
- **Document File**: Inspect `$SAVE_CTX/extracted.txt` first few lines.
- **Raw Text**: Inspect content.
- **Conversation**: Always Korean.

If Korean -> skip.
If `keep_original_lang = true` -> skip.
Otherwise -> translate automatically (no user prompt):

### YouTube

1. Read `$SAVE_CTX/extracted.txt`.
2. Read `.claude/skills/translate-content/SKILL.md` and follow its workflow to translate to Korean.
3. Write the translated result to `$SAVE_CTX/translated.txt` using the Write tool.

### Other Types (X Post, Web, Document, Raw Text)

Translate inline (content is short, Step 8 reads full file anyway -- subagent adds overhead with no benefit):

1. Read `$SAVE_CTX/extracted.txt`
2. Invoke `translate-content` skill on the content
3. Write the translated result to `$SAVE_CTX/translated.txt` using Write tool

## Step 8: Phase 2 -- Common Processing

### 8.1: Read Context Files

1. Read `$SAVE_CTX/meta.json` for type, title, author, url, etc.
2. Read `$SAVE_CTX/extracted.txt` -- **ADAPTIVE by type**:
   - **X post / Web / Document / Raw text / Conversation**: Read FULL file (typically <5K tokens)
   - **YouTube**: Read FIRST 100 LINES ONLY (title + channel from meta.json compensate; full transcript is 15K-60K tokens)

### 8.2: Read Tag Categories (Change #7)

Read `99-meta/vault-structure.md` -- specifically the **Tag Categories** section. Use these categories as the source of truth for generating hierarchical tags.

### 8.3: Generate Metadata

Generate the following:

1. **Filename**: kebab-case, English, max 50 chars
   - YouTube: translate Korean title to English if needed
   - X post: derive from content theme, not author name
   - Web: extract semantic title from page title (strip site names, noise)
   - Document: derive from document title or filename (strip extension)
   - Conversation: based on user's requested topic

2. **Tags**: Hierarchical per vault-structure.md Tag Categories
   - Use `category/subcategory` format
   - YouTube: always include `content/youtube` tag
   - 3-5 tags total

3. **Aliases**: 2-3 alternative names
   - Translation (Korean <-> English)
   - Abbreviation
   - Search variation

4. **Description**: 1-2 sentence summary in Korean

5. **Author** (YouTube/X only): Include in frontmatter
   - YouTube: channel name
   - X post: author display name

### 8.4: Write Frontmatter (Change #5)

Write frontmatter to `$SAVE_CTX/frontmatter.yml` using Write tool:

```yaml
---
title: "<title>"
date: <YYYY-MM-DD>
tags:
  - <tag1>
  - <tag2>
aliases:
  - "<alias1>"
  - "<alias2>"
description: "<Korean description>"
author: "<author>"
source: "<url>"
---

```

Note: Include trailing newline after `---`. Omit `author` if not applicable. Omit `source` for Conversation type.

### 8.5: Assemble Final File (Change #5)

```bash
BODY="$SAVE_CTX/translated.txt"
[ -f "$BODY" ] || BODY="$SAVE_CTX/extracted.txt"
cat $SAVE_CTX/frontmatter.yml "$BODY" > "01-inbox/<filename>.md"
```

This avoids loading large content into the context window.

## Step 9: Phase 3 -- Post-processing

### 9.1: Korean Review

**Skip if**: content is not Korean AND not translated to Korean.
**Always run for**: Conversation saves.

```
Task tool:
  subagent_type: korean-reviewer
  model: sonnet
  description: Review Korean text
  prompt: |
    Review the Korean text in 01-inbox/<filename>.md.
    Read the file, skip frontmatter, review body text only.
```

Handle result:
- **CLEAN**: Notify user briefly
- **HAS_SUGGESTIONS**: Apply all suggestions using Edit tool, notify user

### 9.2: Rename Git Branch

Extract filename (without `.md`), apply branch name rules:
- Lowercase
- Replace spaces/underscores with hyphens
- Remove special characters
- Truncate to 30 chars max

```bash
git branch -m "doc/<branch-name>"
```

### 9.3: Offer Next Action

**Conversation saves**: Skip Deep-dive option.

`AskUserQuestion` with options:
- **Deep-dive** -- Analyze and compile understanding (not for Conversation)
- **Delete** -- Remove the saved note

Handle:
- **Deep-dive**: Invoke `deep-dive-note` skill with saved file path
- **Delete**: `rm <saved_file_path>`, confirm deletion

### 9.4: Cleanup (Change #4)

```bash
rm -rf "$SAVE_CTX"
```
