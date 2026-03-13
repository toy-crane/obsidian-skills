# Obsidian Skills for Claude Code

A collection of [Claude Code](https://docs.anthropic.com/en/docs/claude-code) skills for managing an Obsidian vault.

## Skills

| Skill | Description |
|-------|-------------|
| `save` | Save any content (YouTube, web page, X post, document, text, or conversation) to Obsidian |
| `batch-save` | Save multiple URLs in parallel to Obsidian |
| `excalidraw` | Create and edit Excalidraw diagram JSON files |

## Installation

```bash
# Clone the repo
git clone https://github.com/toy-crane/obsidian-skills.git ~/obsidian-skills

# Symlink individual skills into your project's .claude/skills/
ln -sf ~/obsidian-skills/skills/save .claude/skills/save
ln -sf ~/obsidian-skills/skills/batch-save .claude/skills/batch-save
ln -sf ~/obsidian-skills/skills/excalidraw .claude/skills/excalidraw
```

## License

MIT
