# The AI-OS Model ("File over AI")

Conceptual background for the `bootstrap-ai-os` skill. Source: Nick Milo, "The 3-File AI System That Works With ANY MODEL" (YouTube, https://youtu.be/jbHB-rzKBAs), part of his "Linking Your Thinking" / Obsidian work. Adapted for zk/commonplace-book notebooks.

## The core thesis: file over app → file over AI

Obsidian's philosophy is "file over app": notes are plain markdown in folders, so the knowledge survives any app. Milo extends this to AI as **"file over AI"**: the *processes and identity* an AI needs to work with you should also live in plain files you own — not locked inside whatever model is current this week. When the next paradigm shift happens, the system still stands. Build once, switch models anytime.

## The three layers

1. **Ideaverse (the knowledge base).** All the notes, ideas, and connections — the experiences and thinking available to no one but the owner. The more it holds, the smarter any AI becomes when working with it. Milo organizes his as **ACE**: Atlas (knowledge), Calendar (time-based notes), Efforts (projects). A given notebook may use a different folder scheme; the layer is what matters, not the letters.

2. **Maps & Manuals (the connective tissue).** A small set of plain files that sit between the ideaverse and any AI tool, making the knowledge navigable. This is the layer that matters most. It is the "3 files":
   - **Identity file (`me.md` / `how-to-<name>.md`).** "Who I am, how I think, how I want you to work with me." Modeled on Rands' "How to Rands" (https://randsinrepose.com/archives/how-to-rands/). Roughly 50–80 lines. Changes rarely. The portable replacement for a tool-specific config file.
   - **Vault map.** "What is this notebook and how do you move through it?" A master table of contents + manual: what each folder holds and why, note types and where they go, naming/frontmatter conventions, and how to create notes on the owner's behalf. Changes more often than the identity file.
   - **Skills index.** An index of markdown files, each teaching one repeatable process ("when I ask for X, here's how I want it done"). Milo's key claim: skills are *just portable markdown documentation of a process*, not tool features — so they should travel to any AI, not be locked in one app's skill system.

3. **Tools (the apps and models).** Obsidian/zk, Claude, Codex, Gemini, NotebookLM, etc. The **most replaceable layer**. Models update, apps get discontinued, new tools appear — fine, because the ideaverse and maps stay central.

## Why the middle layer matters

Point an AI at a vault of 20,000 interconnected notes and it struggles — slow, token-hungry, scans everything. Give it a *map* and it can navigate: figure out which notes are relevant, isolate them, skip the rest. Fast context building is what effective AI needs, and maps provide the same structure a human needs to navigate large context. Semantic search (embeddings) is one way to provide this; hand-authored maps-of-content (MOCs) are another, and they additionally encode the owner's judgment about what matters.

## The shim

The tool-specific config file (e.g. `CLAUDE.md`) becomes a thin pointer: in Milo's setup it effectively says "go immediately to `me.md`." That keeps the portable files central and the tool config subordinate.

## Practices from the video

- **Think like a gardener.** Every few weeks, review the identity file and vault map: "Does this need adjustment? Is it getting bloated?" Add, relate, prune, archive — a rhythm, like tending the ideaverse itself.
- **Privacy and provenance.** Be intentional about what the AI can touch; consider keeping deeply personal areas (e.g. journals) outside what AI reads. Always keep backups. Mark AI-generated content (an emoji, tag, or dedicated folder) so it's always clear what's the owner's vs. AI-assisted.
- **Local/open future.** Building portable, file-based, and not tool-locked means being ready to switch to local/open-source models the moment they're good enough.
- **Connecting ideaverses (forward-looking).** Because the maps act as a translation layer, one ideaverse can selectively share with another (team, family) while keeping private knowledge private.

## Mapping to a zk / commonplace-book notebook

- **Ideaverse** → the notebook repo (`pages/`, `references/`, `journals/`, `projects/`, etc.).
- **Maps & Manuals** → an identity file and a vault map kept as notes (e.g. in `pages/`), plus an optional skills index.
- **Tools** → zk, the commonplacebook plugin, embeddings, and whatever AI/editor is in front of the notebook.
- Semantic search via embeddings already provides machine-built navigation; the vault map adds the human-authored, intent-bearing layer on top.

## Troubleshooting: reindex / embedding sync

The commonplacebook plugin's index and embed-sync tools are Perl and require `DBI` and `DBD::SQLite`. If they fail with "Can't locate DBI.pm", the Perl selected for the project (e.g. via a plenv `.perl-version`) lacks those modules. Either install them into that Perl (`cpanm DBI DBD::SQLite`) or point the project at a Perl that has them (often system Perl) by setting `.perl-version` accordingly. Verify with `perl -MDBI -MDBD::SQLite -e1` under the selected interpreter.
