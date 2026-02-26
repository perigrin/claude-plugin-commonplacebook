---
name: index
description: Re-index notes and regenerate embeddings
---

Re-index the zk notebook and sync embeddings.

## Steps

1. Run zk index to update the notes database:
   ```bash
   zk index --force
   ```

2. Run embed-sync to generate embeddings for new/modified notes:
   ```bash
   $CLAUDE_PLUGIN_ROOT/bin/embed-sync.pl --verbose
   ```

3. Report the results to the user.
