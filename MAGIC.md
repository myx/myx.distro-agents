# MAGIC.md — myx.distro-agents

Team-owned notes for the magic-* team.

## Reaching Slack, email and Trello

- `DistroAgentsTools.fn.sh` is the entry point the team routines use for every Slack, email and Trello action. A routine calls one of its operations; it never assembles a `curl`, IMAP or Trello API call of its own.
- The tool resolves the credentials and holds the per-platform API detail behind its operation names, so a caller supplies the operation and its arguments and nothing else.
- An action the tool exposes no operation for is escalated, not reached by a direct API call.

## Adding an operation to `DistroAgentsTools.fn.sh`

- Single-dispatcher convention, shared with every sibling `Distro*Tools`/`Distro*Command` script: exactly one top-level function, one `case "$1" in ... esac`. New operations go inline in that `case`.
- Never a separate `DistroAgentsTools<OpName>` function per operation. Such a function tends to call `DistroAgentsTools` assuming it exists as a sibling, which holds only because the file happens to define it — not because the pattern is sound.
- Inline the logic in the operation's own `case` arm, especially for single-liners. The few existing helpers (`DistroAgentsToolsResolveTarget`, `DistroAgentsToolsPermOf`) are established precedent, not licence to add more.

## Operation contracts worth knowing before calling

- `--sweep-read-incoming-comms` defaults to `--pretty`: `ts | user | text` lines via this package's own `sh-lib/AgentsSlackMessagesFormat.awk`, not raw JSON. `--raw` opts back into the full JSON response. Raw is not the default because every real caller ends up hand-parsing it.
- The no-target "sweep everything" mode is a macro-operation for the main-loop Comms step specifically, not a generic convenience loop: it combines both watched Slack targets, `--comms-email-check` and `--comms-trello-check` into one call. Keep that framing when extending it, and check whether the comms sweep actually needs a platform before adding one.
- `--purge-cleanup` takes no arguments and always purges exactly one fixed directory, `$MMDAPP/.local/.cleanup`, leaving the folder itself in place. No caller-supplied path means no traversal surface to guard, so it needs no canonicalisation. It exists to route around a permission-engine limitation — a blanket `rm ` deny cannot be carved out by a more specific allow, because deny wins regardless of specificity — not as a general `rm` wrapper.

## Which help a reader needs

- A member is authorised for the operations its own armed file declares, not for the tool's whole surface. `DistroAgentsTools.fn.sh --member-help <team-member>` reports that member's declared operations together with their syntax — that is what a member reads to decide what it may call.
- `sh-lib/help/Help.DistroAgentsTools.help.md` is the complete call contract for every operation. Read it when developing or updating the tool itself. It is not the reference for what a given member may call.
- The console-launcher role carries no `sh-scripts/*.fn.sh` command of its own and no help pair. `DistroAgentsConsole.sh` is a workspace-root launcher, generated the way the four sibling `DistroXConsole.sh` scripts are, and none of those four implement `--help`. That absence is the convention, not a gap to fill.

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
