# MAGIC.md — myx.distro-agents

Team-owned notes for the magic-* team.

## Which help a reader needs

- A member is authorised for the operations its own armed file declares, not for the tool's whole surface. `DistroAgentsTools.fn.sh --member-help <team-member>` reports that member's declared operations together with their syntax — that is what a member reads to decide what it may call.
- `sh-lib/help/Help.DistroAgentsTools.help.md` is the complete call contract for every operation. Read it when developing or updating the tool itself. It is not the reference for what a given member may call.

## Sending commands into a console channel

- Send one command per line. A `;`-joined line drops its leading command silently — a leading `echo` produces no output and no error.
- A non-zero exit status aborts the remainder of a sent batch. Put anything that can legitimately return non-zero in its own send.
- Two sessions sharing one console channel interleave their output into a single log. Capture by line offset to separate them.

## Console channels have no per-caller isolation

- The channel id is composed from a fixed prefix, the workspace slug and the console short name. It carries no caller component.
- Two concurrent callers against the same workspace and console therefore resolve to the same channel and can tear down each other's session.
- A `channel_not_found`, or a console dying mid-use while another session is active, is this condition.

## Configuration lives under the workspace's own `.local`

- `--agents-config-option` resolves configuration under `$MMDAPP/.local/.agents/`, one file per key.
- `.local` is the installed release, not a tree a session maintains. It can lag `source` after a source-side rename, and a lookup against a lagging release returns empty rather than failing — an empty result is not evidence that the configuration is missing.
- Closing that gap is a release step. A session does not sync, copy or hand-edit anything under `.local`.

## Writing new code here

- Prefer `awk` or POSIX shell for anything new in `sh-lib/`. Reach for Python only when the job genuinely needs it, and say why at the call site.
- `myx.distro-.local/sh-lib/LocalTools.Make.include` generates a wrapper function named `Distro<ITEM>Tools` per subsystem, which for `Agents` is literally `DistroAgentsTools` — the same name as this package's own unrelated tool. The generated wrapper is install-time and subshell-scoped, and never coexists at runtime with the real tool.
