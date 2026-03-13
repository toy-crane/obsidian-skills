---
name: batch-save
description: Save multiple URLs in parallel to Obsidian. Fire-and-forget, no session switching needed. Use when user provides multiple URLs to save at once, says "batch save", "save these URLs", "여러 개 저장", "이것들 저장해줘", or pastes a list of links.
argument-hint: "[--orig] <url1> <url2> [url3] ..."
user-invocable: true
---

# Batch Save

Save multiple content URLs in parallel. Each URL runs the full `/save` workflow in its own isolated context directory. No session switching needed.

## Step 1: Parse Input

Input is provided in `$ARGUMENTS`.

### Parse flags

- **`--orig` flag**: If present, set `keep_original_lang = true` and strip from arguments.
- Default: `keep_original_lang = false`

### Extract URLs

Split remaining arguments into a list of URLs (space-separated or newline-separated).
Keep only items starting with `http://` or `https://`.

- If no valid URLs: inform user and abort.

## Step 2: Duplicate Check

For each URL, run:
```bash
grep -rl "source:.*<DOMAIN_AND_PATH>" --include="*.md" .
```

If duplicates found, present all at once:

> Found existing notes:
> 1. [url1] -> `[path]` ([title])
> 2. [url3] -> `[path]` ([title])

`AskUserQuestion` options: `["Skip duplicates, save new only", "Overwrite all duplicates", "Cancel"]`

- **Skip**: Remove duplicate URLs from batch, continue with rest.
- **Overwrite**: Delete existing files, continue with full batch.
- **Cancel**: Abort.

If no duplicates, proceed silently.

## Step 3: Preview URLs

Fetch a brief summary for each URL so the user knows what they're saving.

For each URL, detect type and fetch title:
- **YouTube**: Run `defuddle parse "<URL>" --json 2>/dev/null | jq -r '[.title, .author] | join(" ||| ")'`
- **X/Twitter**: Run `defuddle parse "<URL>" --json 2>/dev/null | jq -r '[.author, .title] | join(": ")'`
  (FxTwitter API fetches actual tweet content, unlike OG meta which is empty for regular posts)
- **Web**: Use `curl -sL "<URL>" 2>/dev/null | sed -n 's/.*<title>\([^<]*\)<\/title>.*/\1/p' | head -1`

Run all fetches **in parallel** (multiple Bash calls in a single message) since they are independent.

Present a preview table:

| # | Type | Title | URL |
|---|------|-------|-----|
| 1 | YouTube | 숏폼 중독이 무서운 진짜 이유 (9:07) | youtu.be/... |
| 2 | Web | Agency Over Intelligence - Blog | example.com/... |
| 3 | X Post | @author: First 60 chars of post... | x.com/... |

`AskUserQuestion` options: `["Save all", "Cancel"]`

- **Save all**: Proceed to Step 4.
- **Cancel**: Abort.

The user can also type specific numbers to exclude (e.g., "1, 3 only" or "skip 2").

## Step 4: Launch Parallel Saves

Process URLs in **batches of 5** to avoid system resource saturation. If 5 or fewer URLs, launch all in a single batch.

For each batch:

1. Send all Task calls for the batch **in a single message**:

```
Task tool:
  subagent_type: general-purpose
  model: sonnet
  description: Save <content_type>: <URL>
  prompt: |
    Read .claude/skills/save/SKILL.md and execute the full save workflow for this URL:
    - URL: "<URL>"
    - keep_original_lang: <true|false>
    - Skip Step 9.1 (Korean review), Step 9.2 (branch rename), and Step 9.3 (next action offer)

    After saving, respond with EXACTLY this format:
    SAVED: <filename>.md
    TITLE: <note title>
    TYPE: <youtube|x-post|x-article|webpage|text>
    PATH: 01-inbox/<filename>.md

    If save failed, respond with:
    FAILED: <URL>
    REASON: <brief error description>
```

2. Wait for all agents in the batch to complete and collect results.
3. Launch next batch. Repeat until all URLs are processed.

## Step 5: Collect Results

Parse each subagent's response. Build a results table:

| # | Type | Title | Status | Path |
|---|------|-------|--------|------|
| 1 | YouTube | ... | Saved | `01-inbox/...` |
| 2 | Web | ... | Saved | `01-inbox/...` |
| 3 | X Post | ... | Failed (reason) | - |

## Step 5.5: Korean Review

For each successfully saved file, launch korean-reviewer subagents **in parallel** (same batching as Step 4):

```
Task tool:
  subagent_type: korean-reviewer
  model: sonnet
  description: Review Korean: <filename>
  prompt: |
    Review the Korean text in 01-inbox/<filename>.md.
    Read the file, skip frontmatter, review body text only.
```

Handle results:
- **CLEAN**: No action needed.
- **HAS_SUGGESTIONS**: Apply all suggestions using Edit tool.

## Step 6: Handle Failures

If any saves failed, offer retry:

`AskUserQuestion` options: `["Retry failed items", "Skip"]`

- **Retry**: Re-launch failed URLs (same process as Step 3).
- **Skip**: Continue.

## Step 7: Rename Git Branch

```bash
git branch -m "doc/batch-$(date +%m%d)"
```

## Step 8: Present Summary

Display the final results table. Done. User decides next steps on their own.

## Step 9: Cleanup

```bash
rm -rf .context/
```
