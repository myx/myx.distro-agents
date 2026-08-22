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

## Comments in scripts

- Internal comment: one short line. Header comment: several lines at most.
- Anything longer belongs in this file, never in the script. Code is expected to be self-explanatory.
- Large comment blocks carry a noticeable performance penalty.

## This package is its own git repo

- `myx.distro-agents` is a git repository in its own right: `git rev-parse` from the package root resolves, and `sh-lib/` content is tracked. A destructive-looking edit here has a real `git checkout -- <path>` restore.
- The enclosing `source/` tree is not a repo. Probing from there returns "not a git repository" — a true answer to the wrong question, and not evidence that a file is untracked. Probe from the package root.

## Registering this workspace's MCP servers

- `--owner-install-vscode-integrations` registers this workspace's tooling into this workspace's own config. It never resolves another workspace's origin and never writes into another workspace's config. To register elsewhere, run the tool from there.
- Two workspace targets, one entry per server in each: `.vscode/mcp.json` under `servers` for VS Code/Copilot-Chat, `.mcp.json` under `mcpServers` for Claude Code project scope and Copilot CLI. Claude Code does not read `.vscode/mcp.json`.
- `~/.claude.json`'s `projects["<cwd>"].mcpServers` is keyed by exact directory with no upward walk, so a session opened at a different depth than the registered one sees no server.
- A registration change takes effect only once the MCP host restarts. A `.mcp.json` entry additionally waits on the human's own trust prompt.
- A host launches its server once per session and every tool call inherits that one process's environment. Workspace variables arrive unset, and the working directory is the agent host's project directory rather than the workspace root. A server resolves its own environment at its own entry; an `env` object in a registration fixes the value at install time and goes stale silently when the workspace's settings change.
- A registered command whose path carries a `myx.common` directory component is pruned as a duplicate by the myx.common writers. Any other server's binary stays outside that component.

## `sh-lib/AgentsMcpServerJsonUpsert.awk`

- Upserts one MCP server entry into a JSON config, by entry key. Reads the whole file as one record (`RS='\0'` under `LC_ALL=C`), prints the new document on stdout, and never opens the target — the caller installs the output.
- Params via `ENVIRON`, never `-v`, because `-v` decodes backslashes and corrupts paths: `MYX_MCPUPSERT_TOPKEY` (`servers` or `mcpServers`), `MYX_MCPUPSERT_ENTRYKEY`, `MYX_MCPUPSERT_COMMAND` (raw, escaped internally), plus optional `MYX_MCPUPSERT_ARGS` (JSON array) and `MYX_MCPUPSERT_ENV` (JSON object).
- Splices rather than re-serialising, so every key it was not asked to write survives byte for byte and the file keeps the layout it already had.
- Prunes nothing. The `.py` sibling drops entries launching from its own product tree, which is safe only for the single key that sibling owns; once the key is a parameter, deleting anything the caller did not name is a defect.
- Fails closed: any error exits 1 with a one-word reason on stderr and zero bytes on stdout, so a failed run cannot be installed.
- The `.py` sibling remains the writer for its own entry. It hardcodes that key and cannot express a second one.

## Installing a generated config over its target

- The writer emits, the caller installs: `mktemp` in the target's own directory, `chmod` the temp, then `mv` it over the target.
- Same directory, so the rename is a same-filesystem `rename(2)` and therefore atomic. A temp under `/tmp` trades atomicity for a cross-device copy.
- `mktemp`, never a fixed `<file>.tmp`: a predictable name beside the target can be pre-planted as a symlink, and both the `chmod` and the rename would follow it. `mktemp` creates exclusively, under a name nothing can guess.
- Mode is asserted, not inherited. A temp takes the ambient umask, so the same config lands 0644 under `umask 022` and 0600 under `umask 077`. These files carry a path and a flag, no secret, and every client of the workspace has to read them.
- Assert the entry landed, separately from the exit status of the command that wrote it. Re-running an idempotent writer over the installed file and comparing proves it, and needs neither a temp file nor a second tool.

## Writing new code here

- Prefer `awk` or POSIX shell for anything new in `sh-lib/`. Reach for Python only when the job genuinely needs it, and say why at the call site.
- `myx.distro-.local/sh-lib/LocalTools.Make.include` generates a wrapper function named `Distro<ITEM>Tools` per subsystem, which for `Agents` is literally `DistroAgentsTools` — the same name as this package's own unrelated tool. The generated wrapper is install-time and subshell-scoped, and never coexists at runtime with the real tool.

## Environment init in `DistroAgentsTools.fn.sh`

- `${MDLT_ORIGIN:=$MMDAPP/.local}` at file load is a default, not an init — it only fills a blank. The real init is `DistroAgentsContext --run-from-detect` in the tail guard, which reads `MDLT_CONSOLE_ORIGIN` and resolves the configured origin. `DistroSourceTools.fn.sh` and `DistroDeployTools.fn.sh` carry the same pair.
- Only some tools in the family default `MDLT_ORIGIN` at file load. `DistroSourceTools.fn.sh` and `DistroDeployTools.fn.sh` do not, so their tail-guard test on `[ -z "$MDLT_ORIGIN" ]` is live and does real work. This tool does default it, which is what makes the same test dead here.
- It belongs in the tail guard's executed-only `case "$0"` arm, above the help branch so `--help` also resolves its own help file. A sourced caller must never trigger it, which is what the guard is for.
- An operation arm cannot do this work. The file-load bootstrap and the `MDAT_DATA_ROOT` preamble at the top of the function both run before the dispatcher `case`, so by the time any arm executes the environment is already established, right or wrong.
- `MDLT_ORIGIN` being set proves nothing, because the file-load default sets it unconditionally. `MDLT_OPTION` is the only witness that a resolution actually ran, and `AgentsContext.include`'s idempotence guard tests it alongside `MDLT_ORIGIN` so re-init is a no-op inside a console. A guard written on `MDLT_ORIGIN` alone is dead code after the default.
- A command executed through one of this tool's operations inherits the resolved environment. That is the reason to host an MCP execute operation here: `myx.common`'s MCP path performs no environment init, so anything it runs starts bare.

## Inherited precondition: a caller must not export both origin variables

- A caller exporting both `MDLT_ORIGIN` and `MDLT_OPTION` short-circuits `AgentsContext.include`'s idempotence guard. No resolution runs, the configured origin is never consulted, and the exported value is taken as given and never validated.
- This is why the `myx.distro` registration writes no `env` object. An `env` that pinned both would disable the resolution the front door exists to perform.
- Consequence depends on the arm. The 37 include-sourcing arms fail if the pinned tree lacks the include: exit 1, nothing on stdout, and a bare file-not-found naming a path — no protocol frames, which an MCP host cannot explain. The inline arms source nothing and are unaffected, so `--purge-cleanup` and `--verify-permissions` still succeed under a wrong pinned origin and are not witnesses for this.
- The worse case is quiet. Where the pinned tree does hold the include, the stale copy runs and returns a confident answer. Identical output today is a property of the two copies currently matching, not a guarantee.
- Pre-existing, not introduced by the MCP work. It is reachable at a new front door, which is what makes it worth stating.

## `set -e` containment around an executed script

- `--intern-mcp-execute` runs its script as `( set -e ; eval "$( cat )" )`. Three parts, all required: the subshell's own `set -e` so the script stops at its first failure; `|| execStatus=$?` so the function's `set -e` treats the subshell as tested rather than aborting; `set +e` before returning non-zero so the caller's `set -e` does not trip on the return.
- Dropping the middle part kills the process on any failing script. In a long-running server that is a client waiting for a response that can never arrive.

## `myx.common` commands that look reusable here and are not

- `setup/agentMcp` and `remove/agentMcp` are the obvious candidates and both are wrong for this package: they act on the `myx.common` registration, and `remove/agentMcp` would delete the registration it was asked to install.
- Public `bin/` commands are callable. `include/data/*` is `myx.common`'s internal surface — copy the idiom rather than reach across, as `AgentsMcpServerJsonUpsert.py`'s own header records for its own sibling.

## A bracket range is never used in a `case` pattern

- Measured on this platform: under `en_US.UTF-8`, `case "A" in [a-z])` **matches**; under `LC_ALL=C` it does not. Bracket ranges are collation-dependent, so a range-based whitelist is not a whitelist at all.
- Every accepted character is enumerated explicitly instead — in the bare-name gate and in the bare-conversation-id grammar alike. Never `[a-z]`, `[A-Z]` or `[0-9]`.

## The bare-name gate

- One shared assertion validates every member name, item filename, document name, and board/vault/audit item name across this package. A new operation of that shape calls it and never re-inlines a `case "$x" in */*|.|..)` copy.
- Those copies are what it replaced, and they were strictly weaker: each caught `/`, `.` and `..` while silently accepting spaces, `:` and a leading `-`.
- It reports and returns 1, never exits, so a caller owns its own `set -e` state and handles failure with `|| { set +e ; return 1 ; }`.
- No count of call sites is recorded anywhere. A hard number is exactly the thing that goes stale and misleads.

## Slack target grammar

- One resolver owns the grammar for every operation taking a target. A widened copy pasted into a single operation is how two copies drift into a disambiguation bug.
- A bare conversation id names a whole conversation, so a send against it is a new top-level message, never a threaded reply. It resolves to the id with an empty thread ts, and that emptiness is what makes the send post at top level.
- It exists because a reply was always possible via `<channel>:<ts>` while starting a conversation required an alias — leaving a workspace whose channels carry no alias reachable for replies and unreachable for a first message.
- Accepted: at least 9 characters, every one an uppercase letter or a digit, the first a letter. Uppercase-only rather than a `C`/`D`/`G` prefix test, because every alias is lowercase-with-hyphen — so the disambiguation survives the alias list growing, which a prefix test does not, and an unfamiliar future id shape still resolves instead of silently becoming an unrecognised target.
- Its position is load-bearing and stays after the `*:*` arm: anything carrying a `:` was already consumed as `<channel>:<ts>`, so a token reaching this arm carries none and can never be read as one. The two grammars are disjoint by construction, not by inspection.
- The id passes through verbatim — no trim, no substitution, no extraction. A message posted into an unintended conversation cannot be recalled, so the arm either accepts the caller's exact token or refuses it outright; it never repairs one.

## Comms routes are globs, and only conditionally safe

- `--member-comms-<service>-*` routes one glob per platform, so a new operation of that shape costs no dispatcher line. `comms` is a namespace under the member prefix rather than a prefix of its own, because every such operation takes `<team-member>` first and that member is the acting identity.
- The globs are safe only because every such operation now lives in its own platform include. Two once did not, and any glob would have silently stolen them from the code implementing them. Moving one back out breaks its route silently, not loudly.
- The comms routes precede the `--member-*` route. Without that position the broader glob takes every operation they match.
- `--intern-op-slack-check` is deliberately not routed there: it carries an internal prefix and sits with its internal siblings. Pinning one exact name onto a comms glob is the by-name coupling these routes exist to retire.

## One operation invoking another

- Self-recursion into `DistroAgentsTools` itself, never a private helper — matching `DistroLocalTools.fn.sh`'s own `--upgrade-installed-tools` precedent.

## Console channel dirs hold plumbing, never secrets

- A channel dir carries fifo, log, pid and meta only. `--console-stop` does `rm -rf` on it — one `mktemp`-generated dir, never a fixed or shared path — so anything staged there dies with the session.
- Credentials that ever come under this tool's management are sourced directly into the console's own environment, never staged as a file inside a channel dir.

## No file-drop queue here, deliberately

- The FIFO plus a sentinel in the log already is the queue for the single-producer case this tool serves: commands arrive in order, and a sentinel marks completion.
- No 3-stage queue/working/finished directory protocol exists anywhere in `myx.distro-*` or `myx.common`, so building one here invents a convention rather than following one.
- Revisit only if multiple independent producers ever need to submit into one shared console out of band.

## Permission checks are regression guards, not re-fixes

- `--verify-permissions` walks `.local/.agents/*` and flags anything not 700 for dirs, 600 for files. It guards one specific bug class: an upsert once landed a file at 644 by chmod-ing the touched file instead of the temp that `mv` replaces it with. That root cause is already fixed; this is the standing guard.
- `--self-test` exercises that chain under a deliberately permissive `umask 022` rather than the caller's ambient umask, because a coincidentally restrictive ambient umask hides a chmod regression — confirmed once against the real secrets migration. It uses a disposable probe key, never a real credential, and cleans the probe up pass or fail.

## Deprecated operation names

- A superseded name stays as a working shim: removed from help output, kept in the dispatcher, indefinitely. Any existing caller keeps working unchanged unless a real removal is separately proposed and approved.
