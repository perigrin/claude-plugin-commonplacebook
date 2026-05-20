---
title: Vault Map
tags: ["meta", "documentation"]
description: Operational manual for any AI working in this notebook — how to navigate it and how to create notes in it on the owner's behalf. The navigation half of the "how to <name>" identity file.
---

# Vault Map

This is your manual for navigating and working inside this notebook. Pair it with [[how-to-<name>]] (who I am and how to work with me); this file is the *where things are and how to act* half. It is tool-agnostic by intent — the folders, conventions, and note types here hold no matter which AI or app is reading them; only the specific commands below are tool-specific.

## Navigate by searching first

This notebook has many notes. Do not scan directories — search, isolate the relevant notes, skip the rest. Always search before answering a question about its contents or before creating a new note (to avoid duplicates).

```bash
zk search <query>      # semantic search (embeddings) — conceptually related notes
zk keyword <term>      # full-text / FTS — exact words and phrases
zk related <file>      # notes similar to a given note
zk list --format="{{filename}} - {{metadata.description}}"   # quick index of a directory
```

<Note which folders carry a `description` field, and where the semantic-search wrapper lives.>

## The territory

**Knowledge — search here, and write here when asked:**

| Folder | What lives here | Filename convention |
|--------|-----------------|---------------------|
| `<folder>` | <purpose> | <convention> |

**Infrastructure — not knowledge, mostly leave alone:**

- <build/tooling/archive folders, and which are excluded from the zk index>

## Creating notes on my behalf

- **Pick the right folder** by note type; <state the default for a new note>.
- **Naming:** <kebab-case / date formats per folder>.
- **Frontmatter:** <required fields — tags array, description, provenance tags, any site/build frontmatter>.
- **Link generously** with `[[wiki-style]]` links; <hashtag convention>.
- **When a topic grows**, create or update a map-of-content note that links the cluster.
- **Prefer linking into an existing note over a near-duplicate.** Search first.

## Privacy and provenance

- <What the AI should NOT touch (e.g. journals), if anything.>
- <How AI-generated content is marked, if at all.>
- <Backup expectations.>

## After writing

Re-index so search and embeddings include the change:

```bash
zk index
```

<Note the embedding-sync step / plugin command, and that stale embeddings hide new notes from semantic search.>

## The bigger picture

This notebook is the durable, model-agnostic layer of a larger system: the knowledge plus two manuals — [[how-to-<name>]] (identity) and this Vault Map (navigation) — sitting above whatever AI tools rotate through. The tools are replaceable; these files are not.
