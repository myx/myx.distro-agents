---
maintainers: magic-librarian, magic-coordinator, human-owner
---
# board-item.dispatch document — the shape of one dispatch

Normative contract: `board-item.dispatch.contract.format.md` (the skillset). Where it and this skeleton disagree, the contract wins. This file carries the skeleton the spawner writes, and states the slots. Not written by hand: the spawner fills it when it starts the session.

# Summary

The brief given to one spawned session, carried exactly, with a dated log of its reports. Written by the spawner when it starts the session.

# Skeleton

## document
```
# Spawn-proxy dispatch: {{caller}}

## Brief

{{brief}}

## Result

status: {{status}}
exit-code: {{exit-code}}
output-file: {{output-file}}
completed-at: {{completed-at}}
```

# Slots

- `caller` — the member the session is run as.
- `brief` — the spawn request, carried exactly.
- `status` — the run's final state, written when the session ends.
- `exit-code` — the session's exit code.
- `output-file` — the session's output log path, or `-`.
- `completed-at` — the iso-utc time the session ended.
