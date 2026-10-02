---
maintainers: [magic-coordinator, magic-librarian, magic-architect, keeper-myx, human-owner]
---
# spawn brief — the mechanical part of a `spawn-prepare-brief`

Normative contract: this file's own `# Contract` section, at its end. Where it and the rest of this file disagree, `# Contract` wins.

Not a member/routine contract — this is the fixed text the tooling fills and emits as the mechanical half of a spawn brief. The spawning session still supplies the judgement half: which warnings are relevant, the held context, and what it checked.

# Summary

The part of every spawn brief that tooling produces the same way each time: the target member, the tool routing, the read-and-obey line naming the member's duty file and the session's routine, the routine's executors and invitees, and the open warnings.

## Goals

- A brief's mechanical parts come from a real, readable file, never from a hidden marker or text built inside code.
- Changing the wording is an edit to this file, not to the operation that fills it.

## Scope

- Does: fix the text and the slots of the brief's mechanical block.
- Doesn't: carry the judgement parts. `magic-coordinator.armed.md`'s `spawn-prepare-brief` step states those.

# Skeleton

```
SPAWN-PREPARE-BRIEF: {{member}}
tool-routing: use the tools and MCP this session was given, in the ways your instructions prescribe. Read --member-help {{member}} when unsure how a tool works. Follow what a refused call says: the tool to use instead, or the REFUSAL-ID to escalate by. Report a blockage the prescribed way, so the tooling can be polished. Never hack around it. Do not research source code unless it is the task.
scratchpad: your own files go in the output/ folder this dispatch's own "## Your sandbox" section names
read-and-obey: read {{member}}.armed.md and {{routine}}, through the skillset reader, carefully and in full, before acting, and obey them.
executors: {{executors}}
invitees: {{invitees}}
## open warning-* items
{{open-warnings}}
```

# Contract

- rule: `{{member}}` is the target member's bare name.
- rule: `{{routine}}` is the resolved routine's own filename.
- rule: `{{executors}}` is the resolved routine's own `executors` frontmatter value.
- rule: `{{invitees}}` is the resolved routine's own `invitees` frontmatter value, or `none` where that field is absent or empty.
- rule: `{{open-warnings}}` is one `- <warning-item-filename> [<state>]` line per open `warning-*` board item, across `backlog`, `pending`, `running`, `blocked` and `parked`, or `(none open)` where there is none.
- rule: every line outside the slots is emitted exactly as written here.
