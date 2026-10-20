---
maintainers: [magic-librarian, magic-coordinator, human-owner]
---
# board-item.dispatch document — the shape of one dispatch

Normative contract: `board-item.dispatch.contract.format.md`. Where it and this skeleton disagree, the contract wins. This file carries the skeleton only.

## Contents

- Summary
- Skeleton

# Summary

The brief given to one spawned session, carried exactly, with a dated log of its reports. Written by the spawner when it starts the session.

The skeleton is shown for reading and for tests; this document is not written by hand.

# Skeleton

The required keys, and an optional key only where it is the usual case, marked optional. The other optional keys and the keys the tooling stamps are in the contract's Keys table.

```
---
document-contract: board-item.dispatch
type: dispatch
from: <member>
date: <date-time>
owner: <the caller member>
status: dispatch-started
session-id: <session-id>
spawn-id: <session-id>
executing-workspace: <workspace-name>
paying-workspace: <workspace-name>
member-workspace: <workspace-name>
---
# Spawn-proxy dispatch: <caller member>

## Brief

<the spawn request, carried exactly>

## Result

status: <final status>
exit-code: <code>
output-file: <path, or ->
completed-at: <iso-utc>
```
