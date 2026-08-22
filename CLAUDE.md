# myx.distro-* — AI assistant context

Applies to: myx.distro-.local, myx.distro-deploy, myx.distro-source, myx.distro-system, myx.distro-remote, myx.distro-agents.

Canonical human docs (don't restate here, read them instead):
- Each repo's `README.md` — pipeline stages, folders, variables, `project.inf` properties.
- `myx.distro-.local/sh-lib/help/Man.Project.Inf.file.help.md` — `project.inf` file-format grammar.

This file is reasoning aid + flagged issues, not a rewrite of those docs.

## Repo roles

- `myx.distro-system` — shared kernel (`Distro`/`Require`/`Action`/`DistroSystemContext` in `SystemContext.include`), used by nearly every `.fn.sh`.
- `myx.distro-source` — builds distro indices from source.
- `myx.distro-deploy` — package management/deploy tooling. Requires `myx/myx.distro-source`.
- `myx.distro-remote` — remote-host tooling.
- `myx.distro-agents` — starts a `claude`/`copilot` CLI console (`DistroAgentsConsole.sh`) instead of a bash session. No pipeline builders (console-launcher role, like `-remote`).
- `myx.distro-.local` — bootstraps a fresh workspace, installs the other subsystems. No pipeline builders (boot-only).

Only `myx.distro-source` and `myx.distro-deploy` have shell-side pipeline builders; `-system`/`-remote`/`-agents` don't (kernel/tooling roles).

## Where the mechanics live

Each package's `MAGIC.md` carries the contributor mechanics. This file does not
restate them.

- `myx.distro-system/MAGIC.md` — calling a tool and the three dispatchers, why
  `Distro <name>` fails outside a console, the help-file inconsistencies and the
  ask-before-touching rule, the dependency and index engine, and DistroImageSync
  as direction rather than spec.
- `myx.distro-source/MAGIC.md` — ingest versus build, the change-delta gate,
  builder discovery, and the stage-scoped `MDSC_SOURCE`/`MDSC_CACHED`/`MDSC_OUTPUT`
  values.
- `myx.distro-deploy/MAGIC.md` — picking the narrowest tool, `Execute*` argument
  order, and why exit status is not a deploy result.
- `myx.distro-agents/MAGIC.md` — reaching Slack, email and Trello, adding an
  operation to `DistroAgentsTools.fn.sh`, and its per-operation contracts.
- `myx.distro-remote/MAGIC.md`, `myx.distro-.local/MAGIC.md` — their own package
  notes.

## myx.distro-agents — its own notes

5th console entry point. Package boundary: owns `DistroAgentsConsole.sh` (the
workspace-root launcher, generated the same way the four sibling `DistroXConsole.sh`
scripts are), its own install/Command-Palette wiring (`sh-lib/AgentsTools.Make.include`,
`sh-lib/AgentsTools.Make.VSCodeTasksFragment.include`, `sh-lib/AgentsContext.include` +
`AgentsContext.SetInputSpec.include`), and `sh-scripts/DistroAgentsTools.fn.sh` plus its
`sh-lib/Agent*`/`AgentsTools.*` support files and `sh-lib/help/Help.DistroAgentsTools.*`
pair (magic-* team Slack/email/board/console-session automation — unrelated to the console
launcher above, see the naming-collision note below).

**Implementation language**: prefer `awk` or POSIX shell for anything new — `sh-lib/`
currently carries 15 `.awk` helpers to 8 `.py`. Those eight Python helpers stay as they
are; this is a preference for new code, not a ban and not a cleanup task. Reach for
Python only when the job genuinely needs it, and say why at the call site:
`AgentsImapFetchMessage.py` exists because `curl` cannot consume an IMAP literal at all;
`AgentsSlackBlocksFallbackText.py` because deriving fallback text from a Block Kit array
needs real JSON parsing, and `python3` was already an unconditional dependency of that
exact code branch.

**Not the same thing as `DistroAgentsConsole.sh`**: `sh-scripts/DistroAgentsTools.fn.sh`,
also owned by this package, is a separate, unrelated magic-* team automation tool
(Slack/email/board/console-session ops).

**Naming-collision note**: `myx.distro-.local/sh-lib/LocalTools.Make.include`'s install
loop mechanically builds a wrapper function named `Distro<ITEM>Tools` per subsystem; for
`ITEM="Agents"` this is literally `DistroAgentsTools` — the same name as the unrelated
tool above. Confirmed safe (subshell-scoped, install-time-only, never coexists at runtime
with the real tool) and deliberately kept rather than special-cased, per the
myx.distro-agents build session's own quorum review (magic-architect + magic-developer).
See `AgentsTools.Make.include`'s own header comment for the full reasoning.

`DistroAgentsConsole.sh` starts the selected CLI directly when `--cli` is given
explicitly, and hard-fails if that CLI is not on `PATH`. With no explicit `--cli`, it
defaults to `claude`; if that default CLI is not on `PATH`, the interactive launcher
falls back to a bash session instead of exiting immediately. `--non-interactive`
(headless-terminal) still exits with an error in that case — it has no bash-session
fallback. Remaining args in `--non-interactive` mode are joined into one prompt string
passed to the CLI's own `-p`/`--print`; with none given, that flag reads the prompt from
stdin instead. The exact `-p`/`--print` flag is verified real, documented behavior for
the Claude Code CLI; the equivalent for the standalone `copilot` CLI is a documented
assumption, not independently verified — neither binary exists on the workspace-build
host this package was authored on.