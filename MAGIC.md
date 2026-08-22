# MAGIC.md — myx.distro-agents

Team-owned notes for the magic-* team.

## Which help a reader needs

- A member is authorised for the operations its own armed file declares, not for the tool's whole surface. `DistroAgentsTools.fn.sh --member-help <team-member>` reports that member's declared operations together with their syntax — that is what a member reads to decide what it may call.
- `sh-lib/help/Help.DistroAgentsTools.help.md` is the complete call contract for every operation. Read it when developing or updating the tool itself. It is not the reference for what a given member may call.

## Sending commands into a console channel

- Send one command per line. A `;`-joined line drops its leading command silently — a leading `echo` produces no output and no error.
- A non-zero exit status aborts the remainder of a sent batch. Put anything that can legitimately return non-zero in its own send.
- Two sessions sharing one console channel interleave their output into a single log. Capture by line offset to separate them.
