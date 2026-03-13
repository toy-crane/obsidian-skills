# Obsidian Skills for Claude Code

A collection of [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skills for managing an [Obsidian](https://obsidian.md/) vault. Save content from anywhere, create diagrams, and more -- all through natural language.

## Skills

### `/save`

Save any content to your Obsidian vault with auto-generated frontmatter (tags, aliases, description).

Supported sources:
- **YouTube** -- extracts transcript, restructures by core arguments
- **Web pages** -- clean extraction via [Defuddle](https://github.com/kepano/defuddle)
- **X (Twitter) posts** -- thread-aware extraction
- **Documents** -- PDF, DOCX, and other file formats
- **Raw text** -- paste any text directly
- **Conversations** -- capture the current Claude Code session as a note

```bash
/save https://www.youtube.com/watch?v=...
/save https://example.com/article
/save --orig https://example.com/article   # keep original language (skip translation)
```

### `/batch-save`

Save multiple URLs in parallel. Each URL runs the full `/save` workflow in its own isolated context. Fire-and-forget.

```bash
/batch-save https://url1.com https://url2.com https://url3.com
```

### `/excalidraw`

Create and edit [Excalidraw](https://excalidraw.com/) diagram JSON files with a focus on visual argumentation -- diagrams that argue, not just display.

- Free-form spatial layouts with custom positioning
- Customizable color palette via `references/color-palette.md`
- Built-in rendering pipeline (JSON to PNG export)

```bash
/excalidraw create a diagram showing the PARA method workflow
/excalidraw fix alignment in attachments/my-diagram.excalidraw
```

## Agents

| Agent | Used by | Description |
|-------|---------|-------------|
| `korean-reviewer` | `save` | Reviews Korean text for natural phrasing, unnecessary English, and incorrect word choices before saving |

## Installation

### Marketplace

```bash
/plugin marketplace add toy-crane/obsidian-skills
/plugin install obsidian-save@obsidian-plugins
/plugin install obsidian-excalidraw@obsidian-plugins
```

### npx skills

```bash
npx skills add git@github.com:toy-crane/obsidian-skills.git
```

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) CLI
- [Defuddle](https://github.com/kepano/defuddle) CLI (`npm install -g defuddle`) -- for web page extraction
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) -- for YouTube transcript extraction
- [uv](https://github.com/astral-sh/uv) -- for Excalidraw rendering (Python)
- [Bun](https://bun.sh/) -- for running TypeScript scripts

## License

MIT
