# Save Conversation

Save conversation content as a note, outputting to `.context/` for the orchestrator to process.

## Input

`user_requirements` (required): User's instructions for what kind of note to write from the conversation.

## Workflow

### Step 1: Trace the Conversation Flow

Read the full conversation and identify the **sequence of topics** as they unfolded:
- What question or topic started the conversation?
- How did each question lead to the next?
- Where did understanding deepen or shift?
- What analogies, examples, or explanations landed?

If the user's questioning order was nonlinear or jumped around, **reorder into a logical narrative flow** while preserving every topic discussed.

### Step 2: Write the Note Body

The user's instructions dictate the note's format, scope, and structure. The conversation is **source material**, not the output shape.

Rules:
1. **Follow the user's requested format**: guide, tutorial, reference, cheatsheet, summary -- whatever they asked for. Do NOT use Q&A dialogue format.
2. **Scope to what was asked**: Extract only the relevant content from the conversation. Don't include everything discussed -- focus on what the user specified.
3. **Use appropriate structure**: If the user asked for a "guide", use headings, steps, code blocks. If they asked for a "summary", write concise prose. Match the intent.
4. **Preserve concrete details**: Commands, code blocks, configuration examples, and specific numbers from the conversation should be included when relevant.
5. **Match conversation language**: Write in the same language the conversation was conducted in.

Write the note body to `.context/extracted.txt` using the Write tool.

### Step 3: Write Metadata

Write `.context/meta.json` using the Write tool:
```json
{
  "type": "conversation"
}
```

### Step 4: Report

Tell the orchestrator that extraction is complete. The orchestrator handles filename, frontmatter, and saving.

## Important Rules

- **Preserve examples**: Concrete examples, numbers, and analogies are the most valuable parts of a conversation - never omit them
- **Match language**: Write the body in the same language as the conversation
- **No sensitive data**: Don't include API keys, passwords, or personal information
- **NO FILE SAVING**: Only write to `.context/extracted.txt` and `.context/meta.json` -- the orchestrator handles the final save
