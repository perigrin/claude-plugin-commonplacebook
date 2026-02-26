# Commonplace Book Plugin for Claude Code

A Claude Code plugin that adds semantic search and journaling capabilities to zk-based personal knowledge management systems.

## What It Does

This plugin enables Claude to search your zk notebook using semantic similarity, allowing it to find conceptually related notes even when exact keywords don't match. It also provides an optional `/journal` command that analyzes your daily activity (git commits, calendar events, photos) and interviews you to create structured journal entries.

## Prerequisites

- [zk](https://github.com/zk-org/zk) - Zettelkasten CLI for managing markdown notes
- Perl 5.34+ (macOS system Perl or via plenv)
- [uv](https://docs.astral.sh/uv/) - Python package manager (auto-installs sentence-transformers)
- sqlite3 command-line tool
- Perl modules: DBI, DBD::SQLite

Install missing dependencies:

```bash
# macOS
brew install zk uv sqlite3

# Perl modules (if not already installed)
cpanm DBI DBD::SQLite
```

## Installation

### Via Marketplace (Recommended)

1. Add the marketplace to Claude Code:

```
/plugin marketplace add perigrin/claude-plugins-marketplace
```

2. Install the plugin:

```
/plugin install commonplacebook@perigrin-marketplace
```

### Manual Installation

1. Clone the repository to your plugins directory:

```bash
cd ~/.claude/plugins
git clone https://github.com/perigrin/claude-plugin-commonplacebook.git commonplacebook
```

### Post-Install Setup

1. Run the setup script from your zk notebook directory:

```bash
cd ~/your-notebook
~/.claude/plugins/commonplacebook/scripts/setup.sh
```

The setup script will:
- Verify all dependencies are installed
- Create the `embeddings` table in `.zk/notebook.db` if needed
- Print a configuration snippet to add to your `.zk/config.toml`

2. Install the `zk-search` wrapper to a stable location:

```bash
~/.claude/plugins/commonplacebook/scripts/install-wrapper.sh
```

This creates a wrapper at `~/.local/bin/zk-search` that discovers the current plugin path dynamically. Override the install location with `ZK_SEARCH_BIN_DIR` or `XDG_BIN_HOME` environment variables.

3. Add the aliases to your `.zk/config.toml`:

```toml
[alias]
search = "$HOME/.local/bin/zk-search semantic"
keyword = "$HOME/.local/bin/zk-search keyword"
related = "$HOME/.local/bin/zk-search similar"
lucky = "$HOME/.local/bin/zk-search semantic --limit 1 --paths"
```

4. Generate embeddings for your existing notes:

```bash
cd ~/your-notebook
~/.claude/plugins/commonplacebook/bin/embed-sync.pl
```

This only needs to be run once initially, then periodically when you add new notes.

## Commands

- `/index` - Force re-index the notebook with `zk index --force`
- `/journal` - Create a journal entry (requires journal module enabled)

## Search Usage

From your shell (after adding zk aliases):

```bash
# Semantic search - finds conceptually related notes
zk search "how does dependency injection work"

# Keyword search - exact term matching
zk keyword "DBI"

# Find notes similar to a specific file
zk related pages/commonplacebook-system.md

# Lucky search - returns path to best match only
zk lucky "database schema"
```

Claude will automatically use these commands when searching your knowledge base during conversations.

## How It Works

1. **zk** indexes your markdown notes into a SQLite database (`.zk/notebook.db`)
2. **embed-sync.pl** generates 384-dimensional embeddings for each note using sentence-transformers
3. **zk-search** queries embeddings using cosine similarity to find semantically related content
4. Claude uses search results to answer questions with knowledge base context

The embedding model (`all-MiniLM-L6-v2`) runs locally via uv, requiring no external API calls.

## Modules

The plugin includes optional modules that can be enabled/disabled independently:

### Journal Module

Enables the `/journal` command. See `modules/journal/MODULE.md` for details.

Context sources:
- Git commits across local repositories
- Calendar events (via icalBuddy on macOS)
- Reminders (via Reminders.app on macOS)
- Recent photos (via Photos.app on macOS)
- Claude conversation history (via episodic-memory plugin)

All context sources are optional and gracefully skipped if unavailable.

### macOS Module

Provides skills for macOS applications. See `modules/macos/MODULE.md` for details.

Skills:
- `calendar` - View and manage Calendar.app
- `reminders` - View and manage Reminders.app
- `photos` - View and search Photos.app

Requires macOS and appropriate application permissions.

## Example: New Notebook Setup

```bash
# Create and initialize notebook
mkdir ~/notebook
cd ~/notebook
zk init

# Install plugin
cd ~/.claude/plugins
git clone <this-repo> commonplacebook

# Run setup
cd ~/notebook
~/.claude/plugins/commonplacebook/scripts/setup.sh

# Add aliases to .zk/config.toml (from setup output)

# Create first note
zk new --title "Test Note"

# Index and generate embeddings
zk index
~/.claude/plugins/commonplacebook/bin/embed-sync.pl

# Test semantic search
zk search "test"
```

## Automated Embedding Sync

To automatically generate embeddings when notes change, create a LaunchAgent:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.yourname.notebook-embed-sync</string>
    <key>ProgramArguments</key>
    <array>
        <string>/path/to/plugin/bin/embed-sync.pl</string>
    </array>
    <key>WatchPaths</key>
    <array>
        <string>/path/to/notebook/.zk/notebook.db</string>
    </array>
    <key>RunAtLoad</key>
    <false/>
    <key>StandardOutPath</key>
    <string>/tmp/notebook-embed-sync.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/notebook-embed-sync-error.log</string>
</dict>
</plist>
```

Save to `~/Library/LaunchAgents/com.yourname.notebook-embed-sync.plist` and load:

```bash
launchctl load ~/Library/LaunchAgents/com.yourname.notebook-embed-sync.plist
```

This runs `embed-sync.pl` automatically whenever `notebook.db` changes.

## License

MIT
