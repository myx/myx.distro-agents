#!/bin/sh
## Stand-in for the store's own Python (`.local/knowledge-store/venv/bin/python`), for the knowledge store checks: it
## runs the real python3 over the script it is handed, with the lancedb stand-in module on PYTHONPATH, so
## AgentsKnowledgeStore.py imports that and nothing live. RIG_LANCEDB_STUB names the folder whose `lancedb/` is the
## stand-in. Any argument is forwarded unchanged.
PYTHONPATH="${RIG_LANCEDB_STUB:?RIG_LANCEDB_STUB is not set}" exec python3 "$@"
