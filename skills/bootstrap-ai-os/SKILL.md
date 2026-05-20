---
name: bootstrap-ai-os
description: This skill should be used when the user asks to "bootstrap my commonplace book", "set up the AI OS", "set up file over AI", "make my notebook portable / model-agnostic", "create a how-to-me / identity file", "create a vault map", or "wire CLAUDE.md to my notes". It scaffolds the portable "file over AI" layer for a zk/commonplace-book notebook — an identity manual, a vault map, and an optional skills index — and wires the tool config to them, following Nick Milo's three-layer AI-OS model.
---

# Bootstrap the AI-OS layer for a notebook

Scaffold the portable, model-agnostic layer that lets any AI work well in a zk/commonplace-book notebook. The goal is "file over AI": the assistant's *identity context and navigation knowledge* live in plain notes the owner controls, not locked inside one model or tool.

For the conceptual model and its source, read `references/ai-os-model.md`. The short version: three layers — the **knowledge base** (the notes), the **maps & manuals** (the portable files this skill creates), and the **tools** (swappable AI/apps). This skill builds the middle layer.

## Scope

Applies to a single zk/commonplace-book notebook. Use it to create or complete the portable layer; if an identity file or vault map already exists, develop it rather than starting over. Not for general note-taking or for non-zk repositories.

## Before scaffolding: survey reality

Never assume the notebook's structure — describe what actually exists.

1. Confirm it is a zk notebook (look for `.zk/`, `notebook.db`, markdown notes in folders).
2. List the real top-level directories and roughly how many notes each holds.
3. Read `.zk/config.toml` for aliases, the note template, and indexing excludes.
4. Read 2–3 sample notes per main folder to learn the actual frontmatter and naming conventions (they are often inconsistent across older notes).
5. Check for an existing identity file, vault map, or system/README note so as not to duplicate or overwrite — develop what exists rather than replacing it.

Ground everything written below in this survey, not in the templates' placeholders.

## Step 1 — Identity file ("how to <name>")

Create `pages/how-to-<name>.md` (use the owner's name). This is the slow-changing "who I am, how I think, how to work with me" file, modeled on "How to Rands".

- Start from `assets/how-to-me.template.md`.
- Fill the **working preferences** from any existing tool config (e.g. a global CLAUDE.md) — extracting those rules into a portable file is the core "file over AI" move.
- Interview the owner for the personal sections that cannot be derived. Ask **one question at a time**: mission ("what are you about?"), how they think, values, intellectual lineage. Do not invent values, lineage, or a mission — scaffold and ask.
- Mark anything inferred (e.g. influences guessed from the notes) as "(inferred — confirm)" until the owner verifies.

## Step 2 — Vault map

Create `pages/vault-map.md`: the operational manual for navigating the notebook and creating notes on the owner's behalf.

- Start from `assets/vault-map.template.md`.
- Fill the territory table, naming/frontmatter conventions, and search commands from the survey — describe the real folders, including which are infrastructure to leave alone and which are excluded from the index.
- State a clear default folder for new notes, and the reindex step.
- Include a privacy/provenance section: what the AI should not touch (e.g. journals), how AI-generated content is marked, and backup expectations.

## Step 3 — Skills index (optional third file)

If the owner has repeatable processes they want done the same way each time, create an index note listing them, each a short markdown description of one process ("when I ask for X, do it like this"). Keep these as portable markdown so they travel to any tool, rather than relying solely on a single tool's skill system. This step is intentionally freeform — there is no template; structure the index to fit the owner's processes.

## Step 4 — Wire the tool config (the shim)

Point the tool-specific config at the portable files so they load every session.

- In `CLAUDE.md`, add a short section linking to the identity file and vault map, and `@import` them:
  ```markdown
  @pages/how-to-<name>.md
  @pages/vault-map.md
  ```
- Keep the portable files central and the tool-specific config subordinate to them.
- Note for verification: a running session and its subagents use the CLAUDE.md snapshot from session start — confirm the imports load in a **fresh** session.

## Step 5 — Reindex

Make the new notes searchable: run `zk index`, then sync embeddings (the commonplacebook plugin's `index` command). Stale embeddings hide the new files from semantic search. For environment issues (e.g. a missing Perl `DBI`/`DBD::SQLite`), see the troubleshooting note in `references/ai-os-model.md`.

## Step 6 — Establish the gardener rhythm

Tell the owner to revisit the identity file and vault map every few weeks: does anything need adjustment, is it getting bloated, what should be pruned or archived. The portable layer is tended, not set-and-forget.

## Resources

- **`references/ai-os-model.md`** — the three-layer "file over AI" model, its practices (gardener rhythm, privacy/provenance, MOCs, multi-ideaverse), and the source video.
- **`assets/how-to-me.template.md`** — starting skeleton for the identity file.
- **`assets/vault-map.template.md`** — starting skeleton for the vault map.
