---
name: human-owner
status: reference-only
invocation_mode: never
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
description: >-
  Reference-only identity record for the magic-* team's human owner (myx). Use it only as context when other skill files mention the human owner. Never invoke it as an acting skill, and never post, reply, or act under that identity.
---

# Human-owner

This file is the boot dispatcher — Claude Code's own skill-discovery mechanism requires this exact filename; real content lives in this folder's typed files.

**First, unconditionally**: read `human-owner.basic.md` — the impersonation-forbidden rule and the "not a behavior to invoke" framing. This is the one file in this folder that must be read even for the most casual reference, since it's the file that prevents an agent from ever slipping into speaking as the human-owner.

**Then, only if deeper context is genuinely needed**: read the distributed typed files directly — `human-owner.armed.md`.


**Reminder, restated at the dispatcher level too, not just in the typed files**: this skill is never invoked expecting instructions for how to "be" the human-owner. There is no such behavior to load.
