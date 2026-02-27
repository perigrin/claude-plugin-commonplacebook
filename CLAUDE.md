# Commonplace Book Plugin

Claude Code plugin for semantic search and journaling in zk-based personal knowledge management systems.

## Workflow

When answering questions about documented topics, past decisions, project patterns, or concepts likely to be in the knowledge base:

1. **Search first**: Use `zk search <query>` for semantic search to find conceptually related notes
2. **Fall back to keyword**: Use `zk keyword <term>` for exact term matching when semantic search doesn't surface relevant results
3. **Find similar**: Use `zk related <file>` to find notes similar to a specific file

Always surface relevant knowledge base context before responding. Notes may contain prior decisions, established patterns, or documented concepts that inform the current question.

## Search Strategy

- **Semantic search** finds conceptually related content even when exact keywords don't match
- Use semantic search first for exploratory queries, conceptual questions, or topic research
- Use keyword search for exact terms, code snippets, or specific references
- Use related notes to explore connections from a known starting point

## Commands

- `/index` - Force re-index the notebook (runs `zk index --force`)
- `/journal` - Interview about the day and create a journal entry

## Database Schema

The `.zk/notebook.db` SQLite database contains:

- `notes` - Note metadata (path, title, created, modified, checksum, metadata JSONB)
- `collections` - Tags extracted from note frontmatter
- `notes_collections` - Many-to-many relationship between notes and tags
- `embeddings` - 384-dimensional vectors for semantic search (note_id, model, embedding BLOB, created_at)

## Journal

The `/journal` command interviews the user about their day and creates a journal entry.

Context sources (all optional, gracefully skipped if unavailable):
- **Git activity** - scans local repositories for recent commits
- **Calendar events** - if icalBuddy is installed (macOS)
- **Reminders** - if macOS Reminders.app is accessible
- **Recent photos** - if macOS Photos.app is accessible
- **Claude conversation history** - if episodic-memory plugin is available

Journal entries are saved to `journals/YYYY-MM-DD.md` with title, date, activity context, summary, key notes, and connections to related notes. After creation, the command re-indexes the notebook, creates a git commit, and offers to create backlinks or stub pages for new concepts.

## macOS Skills

Skills for interacting with macOS applications via AppleScript:
- `calendar` - View and manage Calendar.app events (uses icalBuddy for reading, AppleScript for writing)
- `reminders` - View and manage Reminders.app items (priorities, due dates, notes)
- `photos` - View and search Photos.app library (albums, favorites, date ranges)

Requirements:
- macOS system
- icalBuddy (for calendar skill) - optional but recommended
- Calendar.app, Reminders.app, Photos.app must be accessible
- First-run may prompt for permissions; operations sync with iCloud if enabled

## Technical Notes

- Embeddings use `sentence-transformers/all-MiniLM-L6-v2` (384-dim, local inference)
- Search uses cosine similarity with configurable threshold (default 0.5)
- Scripts require Perl 5.34+ and uv for Python dependency management
- Zero non-essential CPAN dependencies policy
