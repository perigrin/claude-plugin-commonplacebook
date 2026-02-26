# Journal Module

The `/journal` command interviews the user about their day and creates a journal entry.

## Context Sources

The journal command gathers context from multiple sources (when available):

- **Git activity** - scans local repositories for recent commits
- **Calendar events** - if icalBuddy is installed (macOS)
- **Reminders** - if macOS Reminders.app is accessible
- **Recent photos** - if macOS Photos.app is accessible
- **Claude conversation history** - if episodic-memory plugin is available

All macOS-specific features are conditional and will be skipped gracefully if unavailable.

## Journal Format

Journal entries are saved to `journals/YYYY-MM-DD.md` in the notebook with:
- Title and date
- Context about what activity was detected
- Summary of the user's day
- Key notes and insights
- Connections to related notes in the knowledge base

After creating a journal entry, the command:
1. Re-indexes the notebook with `zk index --force`
2. Creates a git commit
3. Offers to create backlinks or stub pages for new concepts mentioned
