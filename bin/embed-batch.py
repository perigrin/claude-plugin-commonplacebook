#!/usr/bin/env -S uv run
# /// script
# dependencies = [
#   "sentence-transformers",
# ]
# ///
# ABOUTME: Batch embedding helper using sentence-transformers
# ABOUTME: Reads JSONL from stdin, outputs JSONL embeddings to stdout

import sys
import json
from sentence_transformers import SentenceTransformer

def main():
    model_name = sys.argv[1] if len(sys.argv) > 1 else 'all-MiniLM-L6-v2'

    # Load model once
    model = SentenceTransformer(model_name)

    # Read all texts from stdin (one JSON array per line)
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue

        try:
            texts = json.loads(line)
            if not isinstance(texts, list):
                texts = [texts]

            # Batch encode all texts at once
            embeddings = model.encode(texts, convert_to_numpy=True)

            # Output as JSON array of arrays
            result = [emb.tolist() for emb in embeddings]
            print(json.dumps(result), flush=True)
        except Exception as e:
            print(json.dumps({"error": str(e)}), file=sys.stderr, flush=True)
            print(json.dumps([]), flush=True)

if __name__ == '__main__':
    main()
