---
maintainers: [magic-coordinator, magic-librarian, magic-architect, keeper-myx, human-owner]
---
# session-thread root — the first post of a coworking session's thread

Not a member/routine contract — this is the fixed text of the one post the tooling seeds a coworking session's thread with, in the team's own conversation (`magic-team`). The thread under it is the participants' own: everything else in it is a member's message. The tooling fills it (`AgentsSessionThreadRootFill.awk`) and posts it as the bot (`AgentsToolsSpawnProxySessionRootPost`).

## Contents

- Summary
  - Goals
  - Scope
- Skeleton
  - root

# Summary

One short line that says a session started, which one, and who started it.

## Goals

- The root reads as the session's own, never as one participant's: it names no member as its owner, and carries no author line and no addressee.
- It is short: one line, with no id block, no host and no time. That detail is the tracking thread's.

## Scope

- Does: fix the text of the root post of a session thread.
- Doesn't: shape anything else in that thread. What follows the root is the participants' own.
- Doesn't: shape a tracking post. Those are another thread's, for the tooling (`event-track.post.format.md`).

# Skeleton

`{{session-name}}` is the session's name or comment, else its id. `{{started-by}}` is the member whose session brings the others in; its part is left out where that is not known.

## root

```
🧵 Session *{{session-name}}*[[, started by {{started-by}}]]
```
