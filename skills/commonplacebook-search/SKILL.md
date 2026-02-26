---
name: commonplacebook-search
description: Search the knowledge base for relevant notes, past decisions, and project history
---

Use this skill to search the knowledge base before answering questions about past projects, decisions, patterns, or notes.

## When to Use

- User asks about past projects or decisions
- User references something that might be documented
- You need context about preferences or patterns
- Looking for related notes on a topic

## Commands

### Semantic Search (Recommended)

Find conceptually related notes even without exact word matches:

```bash
zk search "your query here"
```

Example:
```bash
zk search "perl testing patterns"
zk search "how to structure MCP servers"
```

### Keyword Search

Fast exact-match search using FTS5:

```bash
zk ksearch "exact term"
```

Example:
```bash
zk ksearch "Test::More"
zk ksearch "Mojolicious"
```

### Find Related Notes

Find notes similar to a specific note:

```bash
zk related "path/to/note.md"
```

Example:
```bash
zk related pages/perl-validation-server-design-doc.md
```

## Options

All commands support:

- `--limit N` - Maximum results (default: 10)
- `--json` - Output as JSON for parsing

## Tips

1. **Start with semantic search** - it finds conceptually related content
2. **Use keyword search for specific terms** - function names, module names
3. **Check related notes** - when you find a relevant note, find its siblings
4. **Read the full note** - use `Read` tool on the path returned
