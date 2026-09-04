# MAGIC.md — myx.distro-agents

Team-owned notes for the magic-* team.

## Reaching Slack, email and Trello

- `DistroAgentsTools.fn.sh` is the entry point the team routines use for every Slack, email and Trello action. A routine calls one of its operations; it never assembles a `curl`, IMAP or Trello API call of its own.
- The tool resolves the credentials and holds the per-platform API detail behind its operation names, so a caller supplies the operation and its arguments and nothing else.
- An action the tool exposes no operation for is escalated, not reached by a direct API call.

## Adding an operation to `DistroAgentsTools.fn.sh`

- Single-dispatcher convention, shared with every sibling `Distro*Tools`/`Distro*Command` script: exactly one top-level function, one `case "$1" in ... esac`. New operations go inline in that `case`.
- Never a separate `DistroAgentsTools<OpName>` function per operation. Such a function tends to call `DistroAgentsTools` assuming it exists as a sibling, which holds only because the file happens to define it — not because the pattern is sound.
- Inline the logic in the operation's own `case` arm, especially for single-liners. A helper shared by several arms of one family goes in that family's own arm, not at file scope — see below. `AgentsToolsAssertBareName` is at file scope because it is genuinely general; that is the bar, and it is not licence to add more.

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
- Every other piece of state local to this machine — its config, allowlists, caches, settings — is the same case: it reaches no client, so changing it is not a fix and not the work.
- **Reaching `--agents-config-option` at all creates that scope's file, `--select` reads included.** `myx.distro-.local/sh-lib/LocalTools.Config.include` `touch`es `$MMDAPP/.local/.agents/<name>.agent.env` before it even reads the sub-command, so a read against a name nobody has ever heard of leaves a phantom scope on disk that later looks like a configured member.
- **Guard at the caller, never by making the config layer stop touching.** `AgentsToolsAssertBareName` checks a name's shape and says nothing about whether that member exists; the existence check is `[ -d "$HOME/.claude/skills/<member>" ]`, the same one every `--member-comms-*` op already carries, and it belongs ahead of the first config read in any op that takes a member name.

## All non-member Slack code lives in one file, and that file is not the dispatcher

- The human-owner's own rulings, in the order they were given: "NO SLACK IN DistroAgentsTools.fn.sh! ALL IN SEPARATE ARMS", then "no sites - one site - intern-op for slack - all affected in one file", then "Reorganise - so these helpers somewhere in one place and this place is not DistroAgentsTools.fn.sh". Together they settle both halves: the dispatcher carries no Slack implementation, and the implementation is not scattered across per-op includes with a helpers file beside them either.
- `sh-lib/AgentsTools.CommsSlack.include` is that one file. It holds the shared helpers (`DistroAgentsToolsResolveTarget`, `AgentsToolsResolveSlackBotToken`, `AgentsToolsResolveSlackWorkspaceDomain`, `AgentsToolsEmitRequestDetailHeader`, `AgentsToolsInternOpSlackCallEmitFields`, `AgentsToolsSlackResolveWorkspaceForScope`) and all three non-member Slack operations — `--intern-op-slack-call`, `--intern-op-slack-check`, `--intern-op-slack-check-scopes`.
- `DistroAgentsTools.fn.sh` keeps routing-only arms, exactly as Google, Trello, Confluence and Jira do. The member stubs keep one arm each; the non-member ops share a single `--intern-op-slack-*` arm that sources the one file, which dispatches on the op name. The prefix is claimed by that arm, so a future `--intern-op-slack-*` op routing elsewhere goes above it — the rule `--intern-op-item-*` already lives under.
- **A separate include CAN be sourced from inside an op include — the claim that it cannot is false.** Sourcing dispatches only if the sourced file's `case` has an arm matching the caller's `$1`. `AgentsTools.CommsSlack.include`'s `case` ends in a branch that dispatches nothing for any name that is not one of its own three ops, so any other op include sources it at its own top, gets every helper defined, and runs no operation. That is how the member stubs and `--intern-op-check-configs` reach the helpers.
- That silent branch does not weaken the invalid-option discipline: the arm above it catches any unimplemented `--intern-op-slack-*` / `--intern-op-check-slack-*` name and returns 1, and the dispatcher routes the whole `--intern-op-slack-*` family into the file, so a mistyped Slack op is rejected by that arm rather than by the dispatcher's own invalid-option branch.
- Out of that file, deliberately: the member stubs. `AgentsTools.MemberCommsSlack.include`, `AgentsTools.MemberCommsSlackPresence.include`, `AgentsTools.MemberCommsSlackProfile.include` and `AgentsTools.MagicComms.include` are a member's own surface rather than the team's, keep their own dispatcher arms and their own files, and source `AgentsTools.CommsSlack.include` only for the definitions.
- `--intern-op-check-configs` is not a Slack op and carries no Slack call of its own. Its one call that has to reach Slack — `--resolve-slack-workspace-into <KEY>` — goes through `AgentsToolsSlackResolveWorkspaceForScope`, sourced from inside that branch alone so a config check not resolving a workspace never pulls Slack credential resolvers into its shell.

## An EXIT trap set inside an op replaces the caller's, silently

- Every operation is an arm of one shell function in one process, so `trap ... EXIT` inside an arm is the process's trap rather than that arm's. An op installing one while a caller's is already live replaces it, and the `trap - EXIT` it clears with removes the caller's along with its own.
- The caller then runs on with no trap and nothing saying so: its own later `trap - EXIT` calls clear nothing, and whatever its trap was protecting survives only on the paths that also clean up explicitly. Abnormal termination is exactly when the trap was the only cleanup left, and exactly when it is no longer there.
- An op reached through `$( ... )` runs in a subshell and cannot do this; an op called as a plain command in the caller's own shell can. Which of the two a call site uses is load-bearing, not a style choice.
- An op needing no temp file installs no trap and the question never arises. Where one is needed, cleaning up explicitly on every return path costs a line per path and leaves the caller's trap intact.

## Comments in scripts

- Internal comment: one short line. Header comment: several lines at most.
- Anything longer belongs in this file, never in the script. Code is expected to be self-explanatory.
- Large comment blocks carry a noticeable performance penalty.

## This package is its own git repo

- `myx.distro-agents` is a git repository in its own right: `git rev-parse` from the package root resolves, and `sh-lib/` content is tracked. A destructive-looking edit here has a real `git checkout -- <path>` restore.
- The enclosing `source/` tree is not a repo. Probing from there returns "not a git repository" — a true answer to the wrong question, and not evidence that a file is untracked. Probe from the package root.

## Registering this workspace's MCP servers

- `--install-vscode-integrations` registers this workspace's tooling into this workspace's own config. It never resolves another workspace's origin and never writes into another workspace's config. To register elsewhere, run the tool from there.
- Two workspace targets, one entry per server in each: `.vscode/mcp.json` under `servers` for VS Code/Copilot-Chat, `.mcp.json` under `mcpServers` for Claude Code project scope and Copilot CLI. Claude Code does not read `.vscode/mcp.json`.
- `~/.claude.json`'s `projects["<cwd>"].mcpServers` is keyed by exact directory with no upward walk, so a session opened at a different depth than the registered one sees no server.
- A registration change takes effect only once the MCP host restarts. A `.mcp.json` entry additionally waits on the human's own trust prompt.
- A host launches its server once per session and every tool call inherits that one process's environment. Workspace variables arrive unset, and the working directory is the agent host's project directory rather than the workspace root. A server resolves its own environment at its own entry; an `env` object in a registration fixes the value at install time and goes stale silently when the workspace's settings change.
- A registered command whose path carries a `myx.common` directory component is pruned as a duplicate by the myx.common writers. Any other server's binary stays outside that component.

## `sh-lib/AgentsMcpServerJsonUpsert.awk`

- Upserts one MCP server entry into a JSON config, by entry key. Reads the whole file itself, rejoining records under the default `RS` (caller sets only `LC_ALL=C`), prints the new document on stdout, and never opens the target — the caller installs the output.
- Never `RS='\0'` to slurp a file. awk strings are NUL-terminated, so that value collapses to the empty string, which selects paragraph mode: the document splits on any blank line and everything after the first blank line is silently dropped. Measured on one-true-awk 20200816, `awk -v RS='\0' 'BEGIN{print length(RS)}'` prints `0`.
- Params via `ENVIRON`, never `-v`, because `-v` decodes backslashes and corrupts paths: `MYX_MCPUPSERT_TOPKEY` (`servers` or `mcpServers`), `MYX_MCPUPSERT_ENTRYKEY`, `MYX_MCPUPSERT_COMMAND` (raw, escaped internally), plus optional `MYX_MCPUPSERT_ARGS` (JSON array) and `MYX_MCPUPSERT_ENV` (JSON object).
- Splices rather than re-serialising, so every key it was not asked to write survives byte for byte and the file keeps the layout it already had.
- Prunes nothing: once the key is a parameter, deleting anything the caller did not name is a defect. A stale entry under another key therefore survives registration, and removing one is a deliberate act rather than a side effect. `.vscode/mcp.json` is the exception, pruned earlier in the same pass by `myx.common`'s own writer; `.mcp.json` has no second writer.
- Fails closed: any error exits 1 with a one-word reason on stderr and zero bytes on stdout, so a failed run cannot be installed.
- It is the writer for every entry this package registers, `myx.common` and `myx.distro` alike — the key set is data it writes, never a hardcoded single key.

## Installing a generated config over its target

- The writer emits, the caller installs: `mktemp` in the target's own directory, `chmod` the temp, then `mv` it over the target.
- Same directory, so the rename is a same-filesystem `rename(2)` and therefore atomic. A temp under `/tmp` trades atomicity for a cross-device copy.
- `mktemp`, never a fixed `<file>.tmp`: a predictable name beside the target can be pre-planted as a symlink, and both the `chmod` and the rename would follow it. `mktemp` creates exclusively, under a name nothing can guess.
- Mode is asserted, not inherited. A temp takes the ambient umask, so the same config lands 0644 under `umask 022` and 0600 under `umask 077`. These files carry a path and a flag, no secret, and every client of the workspace has to read them.
- Assert the entry landed, separately from the exit status of the command that wrote it. Re-running an idempotent writer over the installed file and comparing proves it, and needs neither a temp file nor a second tool.

## Writing new code here

- Prefer `awk` or POSIX shell for anything new in `sh-lib/`. Reach for Python only when the job genuinely needs it, and say why at the call site.
- `myx.distro-.local` generates a wrapper function named `Distro<ITEM>Tools` per subsystem, which for `Agents` is literally `DistroAgentsTools` — the same name as this package's own unrelated tool. The generated wrapper is install-time and subshell-scoped, and never coexists at runtime with the real tool.

## Conventions come from the sibling `myx.distro-*` packages

- `myx.distro-source` and `myx.distro-deploy` are the family's convention authority. Both are used daily, so their shape reflects decisions that were actually made and held.
- This package is the drifted one: it was written broadly against `myx.common` idioms and against whatever code sat nearest. A pattern found here is evidence of that drift until a daily-used sibling confirms it, and is never cited as precedent for anything else.
- `myx.common` is a separate project. Copying the nearest available example, from there or from this package's own recent code, is how the drift happened; grep the family before assuming a form is the house form.

## Scratch and temp paths

- A scratch location is either `mktemp -d -t "<prefix>-XXXXXXXX"`, the form `myx.distro-deploy` and `myx.distro-source` use, or a literal workspace path under `$MMDAPP/.local/temp/<name>` written out at each use site.
- `mktemp -d "${TMPDIR:-/tmp}/..."` is `myx.common`'s own form. A hand-derived `${TMPDIR:-/tmp}` scratch path appears nowhere in this family and is not written here.
- The MCP server's scratch root is `$MMDAPP/.local/temp/agent-mcp.$$/`, holding `wire.lock`, `req/<field>` and `out.<seq>`. The pid keeps concurrent servers apart, and the path is spelled out in full at every use so the location is on the line itself.

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
- Consequence depends on the arm. An arm that sources an include fails if the pinned tree lacks that include: exit 1, nothing on stdout, and a bare file-not-found naming a path — no protocol frames, which an MCP host cannot explain. The inline arms source nothing and are unaffected, so `--purge-cleanup` and `--verify-permissions` still succeed under a wrong pinned origin and are not witnesses for this.
- The worse case is quiet. Where the pinned tree does hold the include, the stale copy runs and returns a confident answer. Identical output today is a property of the two copies currently matching, not a guarantee.
- The exposure is reachable at the MCP front door, which is what makes it worth stating here.

## The `myx.distro` MCP server: wire and request handling

- stdout is the JSON-RPC wire and carries nothing else. Every diagnostic, the startup witness included, goes to stderr.
- Response bytes are written by the `printf` builtin only. stdout is fully buffered when it is a pipe, which is how an MCP host runs it, so the wire is never handed to a separate process whose flushing this server does not control. awk is forked for escaping, into a variable, before the lock is taken.
- The whole request handler forks — one background job per request, stdin from `/dev/null` — so no handler can eat the wire and a slow request delays only its own response.
- Per-request fields are read into variables before the fork. The next message wipes `req/`, and the fork carries whatever the variables already hold.
- Responses are serialised by a `mkdir` test-and-set on `wire.lock`, held for the one `printf` and nothing else. `mkdir` is the atomic test-and-set every POSIX filesystem has; `flock` is not guaranteed on a bare FreeBSD or Darwin.
- A message with no id is a notification and is never answered: the `notifications/*` arm does nothing, and both send helpers return on an empty id.
- A bare `wait` after the read loop drains the in-flight handlers before the scratch root is removed. Without it, end of stdin deletes `out.<seq>` under a handler still writing its response, and that request is answered never. A child the executed script itself left running is a grandchild, not a job of this shell, so it is never waited on and cannot hold shutdown.

## Capturing an arbitrary command's output

- `$( ... )` returns when its capture pipe has no writers left, not when the command exits. Any background child the command leaves behind holds that pipe open and blocks the caller indefinitely.
- Never capture a caller-supplied or otherwise arbitrary command that way. Redirect its output to a file and read the file back; where the command runs in the background, `wait "$pid"` for it.
- `$( ... )` remains fine for a known, self-contained command of this package's own.

## `set -e` containment around an executed script

- `--intern-mcp-execute` runs its script as `( set -e ; eval "$( cat )" )`. Three parts, all required: the subshell's own `set -e` so the script stops at its first failure; `|| execStatus=$?` so the function's `set -e` treats the subshell as tested rather than aborting; `set +e` before returning non-zero so the caller's `set -e` does not trip on the return.
- Dropping the middle part kills the process on any failing script. In a long-running server that is a client waiting for a response that can never arrive.

## `myx.common` commands that look reusable here and are not

- `setup/agentMcp` and `remove/agentMcp` are the obvious candidates and both are wrong for this package: they act on the `myx.common` registration, and `remove/agentMcp` would delete the registration it was asked to install.
- Its public commands are callable. Its internal surface is not — copy the idiom rather than reach across.

## Variable names are two-word camelCase, never a bare word

- Every name here — shell local, awk parameter, awk local — is at least two words in camelCase: `openChar`, `nestDepth`, `fieldCount`. Never a bare `close`, `depth`, `key`, `value`, `i`, `n`.
- Mechanical, not aesthetic. `close`, `index`, `length`, `split`, `sub` and `system` are awk built-ins, and a parameter named after one is a parse error rather than a shadowing warning — measured here: `function f(s, i, open, close)` reports "4 missing }'s" and points at an unrelated construct, so the message never names the real cause. Two words cannot collide.
- General coding style, not a rule of this package: the canonical statement is `magic-developer/reference/code-craft.md`, restated here because this package is written by whoever is on duty, not only by `magic-developer`.

## A number is written only where its reader needs it

- No message, comment, help entry or program output here carries a number the reader does not need in order to act. A tally above the list enumerating its own items, how many exit codes an operation has, how many call sites one assertion has, how many facets an operation writes — the reader needs the items themselves, named. A count spelled in words is the same as one in digits.
- A number a reader genuinely needs is computed where it is emitted, never typed in. `--member-comms-slack-profile-get` counts what it read into `profileRead`/`profileFailed` and prints those.
- A standing rule of the human-owner's: say it only if it is relevant to the reader or genuinely a fun fact. The canonical statement is `magic-team/magic-team.shared.md`'s own human-owner standing rules, restated here because this package is written by whoever is on duty.

## A bracket range is never used in a `case` pattern

- Measured on this platform: under `en_US.UTF-8`, `case "A" in [a-z])` **matches**; under `LC_ALL=C` it does not. Bracket ranges are collation-dependent, so a range-based whitelist is not a whitelist at all.
- Every accepted character is enumerated explicitly instead — in the bare-name gate and in the bare-conversation-id grammar alike. Never `[a-z]`, `[A-Z]` or `[0-9]`.

## The bare-name gate

- One shared assertion validates every member name, item filename, document name, and board/vault/audit item name across this package. A new operation of that shape calls it and never re-inlines a `case "$x" in */*|.|..)` copy.
- An inlined `case "$x" in */*|.|..)` copy is strictly weaker: it catches `/`, `.` and `..` while silently accepting spaces, `:` and a leading `-`.
- It reports and returns 1, never exits, so a caller owns its own `set -e` state and handles failure with `|| { set +e ; return 1 ; }`.
- No count of call sites is recorded anywhere.

## Slack target grammar

- One resolver owns the grammar for every operation taking a target. A widened copy pasted into a single operation is how two copies drift into a disambiguation bug.
- A bare conversation id names a whole conversation, so a send against it is a new top-level message, never a threaded reply. It resolves to the id with an empty thread ts, and that emptiness is what makes the send post at top level.
- It exists because a reply was always possible via `<channel>:<ts>` while starting a conversation required an alias — leaving a workspace whose channels carry no alias reachable for replies and unreachable for a first message.
- Accepted: at least 9 characters, every one an uppercase letter or a digit, the first a letter. Uppercase-only rather than a `C`/`D`/`G` prefix test, because every alias is lowercase-with-hyphen — so the disambiguation survives the alias list growing, which a prefix test does not, and an unfamiliar future id shape still resolves instead of silently becoming an unrecognised target.
- Its position is load-bearing and stays after the `*:*` arm: anything carrying a `:` was already consumed as `<channel>:<ts>`, so a token reaching this arm carries none and can never be read as one. The two grammars are disjoint by construction, not by inspection.
- The id passes through verbatim — no trim, no substitution, no extraction. A message posted into an unintended conversation cannot be recalled, so the arm either accepts the caller's exact token or refuses it outright; it never repairs one.

## Comms routes are globs, and only conditionally safe

- `--member-comms-<service>-*` routes one glob per platform, so a new operation of that shape costs no dispatcher line. `comms` is a namespace under the member prefix rather than a prefix of its own, because every such operation takes `<team-member>` first and that member is the acting identity.
- The globs are safe only because every such operation lives in its own platform include. Moving one back out breaks its route silently, not loudly.
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

- `--verify-permissions` walks `.local/.agents/*` and flags anything not 700 for dirs, 600 for files. It is the standing guard against one bug class: an upsert chmod-ing the touched file instead of the temp that `mv` replaces it with, which lands the result at 644.
- `--self-test` exercises that chain under a deliberately permissive `umask 022` rather than the caller's ambient umask, because a coincidentally restrictive ambient umask hides a chmod regression. It uses a disposable probe key, never a real credential, and cleans the probe up pass or fail.

## Board-item list-shaped header fields are comma-separated, no brackets

- `blocks`/`blocked-by`/`supersedes`/`superseded-by`/`spawns`/`spawned-by` (and any other list-shaped board-item header) serialise as `a, b, c` — a single value is the bare value, never `[a, b, c]`. The writer is `sh-lib/AgentsBoardItemHeaderOpsApply.awk`'s `--header:append` accumulation; it joins with `, ` and does not wrap the result.
- `references` is not a field. Every relationship a board-item carries uses one of the six typed fields above, chosen for what the relationship actually is, not left generic.
- `participants`/`restart-session` are a separate, pre-existing space-separated convention, unrelated to this one — already bracket-free, untouched.

## `--magic-board-to-blocked`/`--magic-grooming-to-blocked` auto-stamp `execution-receipt`

- Both ops append `--header:upsert:execution-receipt:blocked:<timestamp>` to the caller's own header set unless the caller already supplied an `execution-receipt` upsert or append, in which case the caller's value stands untouched. Every sibling `-to-*` op in both files (`-to-pending`/`-to-backlog`/`-to-parked`/`-to-running`) stamps nothing; `--magic-board-to-processed` stamps a `processed:<timestamp>` receipt of the same shape, plus its own `processed-at`.
- The check is a plain scan of the collected `passthrough[]` array for an existing `--header:upsert:execution-receipt:*`/`--header:append:execution-receipt:*` entry before appending the default — duplicated independently in both files' own case arms, matching this package's own per-call-site validation convention rather than centralising into the shared `--intern-op-board-upsert-move-edit`.

## The `--magic-<routine>-*` groups: one file per routine, one arm per op

- Each routine's operation group lives in its own `sh-lib/AgentsTools.Magic<Routine>.include`, sourced lazily from that group's own wildcard arm. Every op is its own explicit case arm carrying its own validation, even where two arms are identical today. A shared or parameterised helper deriving the target state from an argument is not the shape here — each arm is expected to grow its own state-specific checks.
- A state move belongs to the routine that makes it, not to the state it targets. `--magic-grooming-to-parked`, `--magic-advance-to-parked` and `--magic-board-to-parked` are three deliberate stubs over one `--intern-op-board-upsert-move-edit`; each stamps its own routine's provenance, and merging them drops that record.
- `--magic-grooming-*` stamps `owner`, `groomed-at`, `groomed-from` and `track`. A create arm stamps no `groomed-from`: a created item moved from nowhere, and a sentinel there records a transition that never happened.
- `--magic-grooming-to-processed`/`-create-processed` stamp `processed-at`, which records when the item entered `board-processed`. `groomed-at` is not that fact — a same-state patch re-stamps it, so it drifts forward and cannot answer how long an item has been processed.

## A routine's own lock note, and why its header order is load-bearing

- Every routine locks against its own fixed note, whose filename is hardcoded in that routine's own stub and is never a caller argument, so no caller can point one routine's lock at another's.
- The `-lock-` and `-state-` infixes separate two concerns: a lock is not a routine's input and not its state record. The lock check is its own operation, called before the input scan; an input scan returns content and never a lock verdict.
- `--magic-<routine>-state-and-lock-upsert` passes `--header:upsert:state:*` **before** the caller's own headers and `--header:upsert:recheck-date:*` **after** them. `AgentsBoardItemHeaderOpsApply.awk` resolves repeat upserts on one field as last-wins, so that order is what lets a closing call override the state while denying a caller the ability to pin the lock open indefinitely. Do not normalise the two to one order.
- `--magic-<routine>-close-state-and-unlock` writes any closing content in the same `--intern-op-item-upsert` call that sets the finished state and releases the lock — one call, never two. Content is optional; the no-flag default preserves the existing body.
- On unlock, GC-deletion commits first, then the lock-state write, then one push covering both — never one push per commit.
- A recheck offset is computed from `date +%s` plus integer arithmetic, never `date(1)` arithmetic: BSD spells the offset `date -v+30M`, GNU spells it `date -d '+30 min'`, and POSIX specifies neither — `date(1)` is standardised only as a reader of the current time.

## The per-routine `--*-input-scan` wrappers are deliberate; do not collapse them

- `--magic-advance-input-scan`, `--magic-grooming-input-scan`, `--magic-heartbeat-input-scan`, `--magic-sweep-input-scan`, `--member-work-session-input-scan` and `--routine-coworking-session-input-scan` are thin fixed wrappers over `--intern-op-session-context-scan`. Two of them passing identical arguments is a coincidence of two routines currently needing the same view, not one operation wearing two names.
- The op name is the stable interface a routine calls and its own skillset file declares; the argument list behind it is free to change for that routine alone. Collapsing them, or rewriting one as a call to another, couples independent routines to a single argument list and makes a later divergence a breaking change for a consumer that never asked for it.
- A wrapper is fixed, not flexible: it exposes no caller-facing `--state`/`--header` override. A caller wanting a different scan shape calls `--intern-op-session-context-scan` directly.
- What each wrapper sweeps is split so two wrappers do not intersect. Content that no step of the consuming routine asked for is the defect that split exists to prevent.

## `--intern-op-session-context-scan`: what a wrapper owes the document

- **A wrapper passes its own cut-off; it never lets the scan default.** The scan falls back to a recent window when given none, which reports a never-swept relationship as empty with a clean exit. `--client-sweep-input-scan` supplies `--comms-since-utime 0` when its caller gives nothing. The value used is stated in each section's own `instrument:` line, so a defaulted window and a passed one are told apart from the document alone.
- **`--comms-since-utime 0` means "trim nothing", not "read the whole history".** The cut-off is applied client-side; Slack's own `oldest=` is deliberately not used and `conversations.history` is read unpaginated, so a conversation deeper than one page is still only seen to that page's edge. Reading a relationship in full needs cursor pagination, which does not exist here.
- **`--do-board-related-active`/`--do-board-related-all` own the state set, and a `--state` list beside one has to byte-match it, order included, or the op errors.** Passing an explicit list instead is what leaves `## Board Items` printing a bare newline where every other section states its own null: the null line is emitted only under those flags. A caller wanting the null states nothing itself and lets the flag supply the states.
- **An optional comms source nothing is configured for is not a source that failed.** Email and Trello answer "no credentials" and "the API did not answer" with the same status, so the scan tells them apart by reading that scope's own keys first, mirroring each op's own gate. An unconfigured source enters neither `sources-scanned` counter and cannot make the run partial — counting it un-scanned would make a correctly-configured member report partial for ever, and counting it scanned would assert a read that never happened. Its section says which keys are unset.
- **One email item block is rendered by `sh-lib/AgentsSessionContextEmailItem.py`, one message per call, raw RFC822 on stdin.** `AgentsSessionContextCommsItems.awk` renders Slack and Trello and never email — email is not JSON. Python rather than awk because a real `From`/`Subject` arrives folded and RFC2047-encoded, and decoding one needs base64, quoted-printable and a transcode from a declared charset; a hand-rolled base64 decoder in awk cannot even emit bytes the same way under one-true-awk and gawk.
- **The block carries headers only, no body.** `session-context.document.format.md` ratifies exactly two cut disclosures and forbids a fresh one, and neither covers a comms item body — so a body could only be carried whole. `--member-comms-email-read` is one call away for the rest.
- **Fetching a message is `--member-comms-email-read` in a subshell, redirected to a file.** A `$( )` capture truncates raw message bytes at the first NUL, and a direct call leaks the op's own `set +e` into the rest of the scan. The fetch loop stops at the section's own cap, since each read is a separate IMAP login; the truncation note then has to count UIDs rather than blocks, or it silently stops firing.

## `--intern-team-data-final-gc-deletion` and `--intern-op-board-trash` are not one mechanism

- The first permanently deletes on a retention clock; the second relocates one named item on request. Different contract, and neither is built on the other.
- Its local-commit gate is `.git` presence alone, independent of `TEAM_DATA_GIT_REMOTE`, because this op never pushes or syncs — that is always the caller's own job.

## `sh-lib/AgentsSlackBlocksBuild.awk` — `##`/`###` render bold, not header

- Only a line starting with exactly `"# "` becomes a Slack `header` block; the check is `substr(line, 1, 2) == "# "`, so `"## text"` never matches it. Slack's Block Kit `header` block has one flat style with no H2/H3 distinction to map to, so a deeper heading (`##`, `###`, any count of `#`) instead becomes a bold paragraph line, reusing the same `**text**` bold path the script already has for inline styles — not left as unconverted raw markdown.

## The blocks path fails before Slack rather than degrading to plain text

- **An empty node is what Slack answers `invalid_blocks` to, and three converter inputs produced one.** A blank line inside a fenced block emitted an empty `text` element; a heading marker with nothing after it emitted an empty `plain_text`; a bullet marker with nothing after it emitted a childless `elements` array. Each now emits nothing where the content is empty, and a fence whose whole content is blank emits no block at all — the guard an empty fence already had.
- **A blank fence line is represented, not dropped.** It contributes its own `{"type":"text","text":"\n"}` separator and no content element, so two consecutive separators carry the blank line. The separator is appended through `appendElem`, which is what keeps a leading blank line from producing a leading comma.
- **A skipped list item has to skip its separator with it.** Guarding only the append leaves the comma behind and produces `},,{` — invalid JSON from a valid message. `appendElem` is the shape that cannot get this wrong, and `parseInlineStyles` is called once into a local rather than twice, since it rewrites shared token globals and rescans the line each time.
- **`sh-lib/AgentsBlockKitValidate.py` walks the whole payload and runs on the array actually sent** — after the addressee and attribution splices, so the indices it reports are the ones Slack sees. It prints one problem per line by path; the caller fails on any output and on a non-zero exit alike, so a crash inside the validator cannot read as a clean payload.
- **Its contract is not that a Slack rejection is impossible, and cannot be.** The empty-node rule is in none of Slack's published Block Kit pages — it was learned from a live rejection, so the rule set is open by construction. Caught: every class measured. Not caught, each documented by Slack: the 50-block cap per message, the 150-character header maximum, the per-type required fields of a caller-supplied payload, and any value Slack resolves rather than shapes.
- **`invalid_blocks` is a verdict, not a transport fault.** Retrying it five times with backoff cost 30 seconds and produced a "Slack comms are stuck" email that was false — Slack answered, the payload was wrong. It breaks on the first response, with no email.
- **The exhausted-retries arm ended `... ; return $?`, so the operation exited 0 whenever the notification email succeeded** — for a message that never landed, with empty stdout. Under `set -e` that same line was never reached at all when the email failed. The email call is tested with `||` now and the arm returns 1 unconditionally.

## `--intern-*` operations are excluded from customer-facing help

- Every `--intern-*` operation — the `--intern-op-*` primitives and the caller-less `--intern-mcp-server`/`--intern-main-loop`/`--intern-mcp-execute`/`--intern-validate-json` utilities alike — is left out of `Help.DistroAgentsTools.include`'s syntax lines and out of `Help.DistroAgentsTools.help.md`'s Operation Reference and Examples. A member never calls one directly, so a reader of `--help` has no use for its syntax or a worked example of it; its contract belongs to whoever is developing or maintaining the tool, which is what this file is for. An include's own header comment names the file and how it is sourced, never the operation's contract.
- A public operation's own help entry may still need to contrast itself with an internal op it complements (e.g. `--member-comms-slack-search-messages` vs. a bounded single-target Slack read). State that contrast in behavioural terms, never by naming the internal op — a caller does not need that name to choose between the two.

### `--intern-op-slack-check` call contract

- Reads exactly one target: `magic-team`/`human-owner`/`event-track`/`event-alert`, a bare `<conversation-id>`, or `<channel>:<ts>` for one thread. `human-owner` alone reads both of the human-owner's direct conversations and merges them chronologically, each line tagged with its own conversation.
- Exit codes (`human-owner` target only; every other target keeps plain 0/1): 0 both conversations read, 3 only one (named, with reason, in the output header), 4 neither, 1 failed before reaching either.
- Pretty-formatted (`ts | user | text`) by default; `--raw` returns the full API response(s).

### `--intern-op-slack-call` upload mode (`--upload-file <name>=<path>`)

- Multipart POST, the one request shape neither the urlencoded GET nor the JSON POST can carry, because the payload is a file part. curl sets the Content-Type and boundary itself; supplying one makes the boundary disagree with the body curl writes. Not combinable with `--json-body` (two different request bodies — only the upload would be sent, dropping the JSON silently) nor with `--fetch-url`; both are refused at parse.
- Reports two line-anchored stderr fields, emitted whether the upload passed or failed: `UPLOAD_HTTP_STATUS=<code>` and `UPLOAD_BYTES=<n>`. Both read `not-reported` when curl failed before the transfer began and wrote no `-w` line at all — a positive state, because an empty value could not be told apart from a real zero.
- **`UPLOAD_BYTES` is bytes SENT**, and the direction differs from `FETCH_BYTES` deliberately. Both name the payload of their own operation — what the call moved — which resolves to received for a download and sent for an upload. Literal direction-symmetry would be the false symmetry. The received body on an upload is a small JSON response the caller already holds in full; bytes sent, compared against the file's size on disk, is the only signal separating a truncated or timed-out send from a refusal. Measured live: a 389440-byte PNG reports 389651, the ~211-byte excess being multipart framing.
- **There is deliberately no `UPLOAD_CONTENT_TYPE`.** `FETCH_CONTENT_TYPE` is load-bearing, not decoration: it is what lets a caller catch Slack answering HTTP 200 with an HTML sign-in page, the false success the fetch path states it cannot judge for itself. The upload path has no such false success — its verdict comes from the shared `"ok":true` test against a body Slack always sends as JSON — so the field would be a constant no caller could branch on, and a second copy of a fact the caller already has.
- The response body goes to its own temp file via `-o`, so the `-w` line is the only thing left in the capture. That inverts the fetch branch's arrangement for the fetch branch's own stated reason: `tail -1` is exact against curl's fixed single-line format and is not exact against a JSON body whose layout Slack controls.

### Slack attribution — the `X-Request-Detail` header

- Every Slack call site attributable to an acting member or a single conversation — not only `--intern-op-slack-call` — emits `X-Request-Detail: slack-workspace=<v>; client-member=<v>; channel-id=<v>` on stderr, ahead of any `KEY=value` fields the op itself carries, because a header precedes the data it describes. Text only, no JSON form — the human-owner's own ruling: "NO JSON - MIME IS SUFFICIENT." `--intern-op-slack-check-scopes` (a scope-poll `auth.test`) and `--intern-op-check-configs`'s own `--resolve-slack-workspace-into` call (the resolution this header's own workspace field depends on) are diagnostic/introspection calls rather than attributed Slack actions, and carry no header of their own.
- It is a third category beside the two `--intern-op-slack-call`'s own header block distinguishes: the fields are the caller interface, the sentences are prose nothing may parse, and this is structured data whose shape is the point of it. It carries a colon, so no `sed -n 's/^KEY=//p'` can match it and the two namespaces cannot collide.
- **`client-member` names the Slack API client making the request, meaning the acting member. It does not mean a `client-*` member.** The name reads that way to anyone who does not already know, so it is explained wherever it appears rather than left to be renamed by the next reader repeating that reading.
- **The workspace is read from config, once per call** — the human-owner's own ruling. Resolution is two-tier, the same shape `AgentsToolsResolveSlackBotToken` already uses for the token itself (see "A member's own bot token, then the team's" below): the calling member's own persisted `SLACK_WORKSPACE_DOMAIN` when it has one, `magic-team`'s shared one otherwise. `AgentsToolsResolveSlackWorkspaceDomain` (`sh-lib/AgentsTools.CommsSlack.include`, defined beside `AgentsToolsResolveSlackBotToken`) is the one implementation; `AgentsToolsEmitRequestDetailHeader` calls it with the header's own `client-member` argument, so no site resolves this separately. `--intern-op-check-configs`'s `--resolve-slack-workspace-into <KEY>` is what resolves and persists a value into either scope, against a token that same scope holds itself — `SLACK_USER_TOKEN` first, `SLACK_BOT_TOKEN` after it — wherever that scope's own config-check pass runs: `magic-team`'s on the main loop's own pass (`--magic-heartbeat-config-check`), and a client member's own on its own sweep's pass (`--client-sweep-config-check`) — never per message either way.
- **Traded away on purpose, and only partly recovered**: the earlier per-call `auth.test` read the *acting token's own* workspace, so a member acting under its own foreign-organisation user token correctly reported that organisation's workspace, distinct from the team's own bot-token workspace. The two-tier config read recovers this precisely when the acting member holds its own persisted `SLACK_WORKSPACE_DOMAIN` (resolved from that same member's own `SLACK_BOT_TOKEN`, per the config-check pass above); a member with none still reports `magic-team`'s shared workspace, which may disagree with whatever token that particular call actually used. The human-owner's own words: "I dont want it from auth.test... I want it from variables and settings... THAT CHEAP." Do not reinstate a per-call `auth.test` to recover the remaining gap.
- A value that could not be resolved is stated rather than omitted: `<lookup-failed>` where neither scope carries a persisted value yet (before the first successful config-check pass for either, or that pass's own resolution last failed), `<none>` where the call has no such value (no client-member, or no single conversation in play). Angle brackets cannot occur in a workspace domain or a conversation id, so a state and a real value are lexically disjoint. `--intern-op-slack-call`'s own `ACTING_IDENTITY=` field keeps its separate `not-yet-selected` state — unrelated to the header's workspace field.
- `channel-id` is the caller's own already-known value at the point the header is emitted. For `--intern-op-slack-call` it is read out of the form arguments at emission time — a channel reaches that op three ways (the caller's own `--form`, `--resolve-target`, and the DM `--resolve-dm` opens), and a copy taken at any one of them is stale at the other two. `--member-comms-slack-send-message` emits it as soon as its own `<target>` argument is captured, in that argument's own raw form, before `DistroAgentsToolsResolveTarget` resolves it to a channel (or fails to) further down — so the header reaches every exit past that point, resolution failures included. `<none>` is reserved for a call with no single conversation in play (`--magic-comms-slack-resolve-ids`, the presence-check operations).
- Every Slack call site that bypassed the header before this ruling now carries it too: `--member-comms-slack-send-message` (its own raw `chat.postMessage` `curl`), `--magic-comms-slack-resolve-ids`, and the presence-check operations (`--member-comms-slack-presence-keep`/`-status`/`-stop`).
- Cost: one local config read per op invocation, no network round trip — against the original per-call `auth.test` (roughly 320ms, versus roughly 30ms for an invocation touching no network at all).

### Form values go in the request body, never the request URI

- The urlencoded arm sends its `--data-urlencode` pairs as an ordinary `application/x-www-form-urlencoded` POST body. It must never carry `-G`, which moves them into the query string and gives every call an undeclared ceiling on its own length: a 7278-byte `chat.postMessage` came back as an Apache `414 Request-URI Too Long` page, while 2-3KB posts kept working, so nothing revealed the ceiling until a long enough message met it.
- Slack answers read methods identically either way — measured on `auth.test`, `emoji.list`, `conversations.info` and `users.info` — so the body form costs nothing.
- **An `ok:false` verdict requires a Slack response to have verdicted.** Absence of `"ok":true` covers two layers: the method answered and refused, and nothing from the method arrived at all. Reporting the second as the first announced an HTTP server's HTML page as `ok:false` and carried it in `RESPONSE_BODY=`, a field whose contract is one line and which an HTML page breaks into several. `sh-lib/AgentsSlackJsonField.awk` on path `ok` separates the two on its own rc; a body it cannot read is a transport-layer failure and keeps `RESPONSE_BODY_STATE=none`, which is already that state's documented meaning.

### `--intern-op-url-post-bytes` call contract

- `--intern-op-url-post-bytes --url <url> --body-file <path> [--context <caller-op>]`. POSTs the file's bytes as the raw request body. No credential, no form encoding, no multipart.
- A sibling of `--intern-op-slack-call` rather than a mode of it, and the separation is structural rather than a suppressing flag. The name deliberately does not match the `--intern-op-slack-*` glob, so the dispatcher never enters the arm defining the credential resolvers and they do not exist in this op's shell. A flag can be defaulted wrong or inverted in a refactor; an undefined function cannot.
- The URL is a bearer capability — possession of it is authorisation — and it is never quoted into any diagnostic here. That is why this arm's error text reads unlike every sibling arm's: the unrecognised-argument message names the accepted flags instead of the offending value, and curl's own stderr is discarded rather than reported, because curl's messages carry the URL.
- The response body is emitted on a 2xx only. Measured: a server's own error page echoes the request URL back inside the body, so printing it on a failure would publish through the payload what every diagnostic here withheld.
- `POST_HTTP_STATUS=` and `POST_BYTES=` on stderr, the same line-anchored read-back the sibling fields use. `POST_BYTES` is bytes SENT, the `UPLOAD_BYTES` direction: compared against the file's size on disk it is what separates a truncated send from a refusal.
- Measured, curl 8.7.1: a transport failure still writes the `-w` line, as `000 0`. `000` is curl's own "no HTTP status was received" and cannot collide with a real status, so the initial `not-reported` is reached only by a curl writing nothing at all.
- https only. The request body is the file's own bytes, and this op attaches nothing else that would protect them in transit.
- It installs no EXIT trap and cleans up explicitly, so a caller's own trap survives the call — see "An EXIT trap set inside an op replaces the caller's, silently".
- The request carries curl's own default Content-Type, which is what the measured flow accepts. A platform needing a specific one gets a flag when one actually does.

### `--intern-op-session-context-scan` — why the six session-context scopes are shaped the way they are

The contracts themselves live in `magic-team.shared.md`'s "Session-context document" entry and in `magic-team/templates/session-context.document.format.md`; the flag names are spelled in the operation's own option-parsing arm. What follows is the reasoning, which belongs to whoever maintains this tool.

- **The `-active`/`-all` axis is physical, never a frontmatter predicate.** For inbox scopes it is the top level of `inboxes/<member>/` versus that plus `processed/`; for board scopes it is the five active states versus all eight. The obvious alternative — reading a `status:` field — was rejected against the real corpus, not on taste: `status:` is present on a minority of inquiry items and is free text with a dozen distinct values ("open", "parked", "backlog -- not yet assessed", "resolved — false alarm, self-corrected same pass"). A filter reading that is a parser guessing at English, and it fails in the **inclusive** direction, silently dropping live work. The physical split already agrees with the semantic one: the only inquiry items carrying a terminal marker sit in `processed/`. So `status:` is never parsed by any of these six, and no new lifecycle field was introduced to make them work.
- **`processed/` is garbage-collected on a type-dependent retention threshold.** An `-all` inbox scope therefore means live plus not-yet-collected processed — never complete history. Anything written about these scopes has to say it that way, because a reader who assumes completeness reads a collection gap as an absence.
- **Each pair is mutually exclusive, and passing both is an error rather than a union.** Both members of a pair fill the same heading, so a section produced by two scopes states neither. One section, one stated scope, or a reader cannot tell which run produced it.
- **Relatedness is `owner:` alone, and the limit is stated rather than hidden.** `assignee:` does not occur in the corpus at all; `owner:` covers the large majority of items. `participants:` and `restart-session:` genuinely encode "involved but not owner" and are deliberately not matched — widening past `owner:` would invent scope beyond the recorded gap. Because that exclusion is invisible in the output, the empty-case `**NOTE:**` names `owner` explicitly in its filter text.
- **`--do-board-related-*` and `--filter-owner` are different mechanisms and must not silently blend.** The first binds relatedness to the acting `<team-member>` and supplies its own state set; the second matches a caller-named value. Passed together with disagreeing values they are refused, because an intersection would quietly return a set neither argument asked for.
- **A `scope:` line leads every requested section.** This is not a new convention: the comms sections already carry per-section metadata describing how the section was produced (`identity:`, `instrument:`, `sources-scanned:`, `cap:`, `cut-off-applied:`) while the inbox and board sections carried none. `scope:` extends that existing convention to the two families that lacked it, and it closes two real gaps — an `-all` inbox scope would otherwise fill a heading that says "Active", and the two board scopes would otherwise produce byte-identical documents with no way to tell which ran. The headings themselves stay unrenamed: a stable heading set is what makes the document parseable, so the heading names the section and `scope:` names the run.
- **An empty requested section carries the first `**NOTE:**` form, with a denominator and a filter.** "Looked, found nothing" and "could not look" must never render the same, which is the whole point of this document; and a bare "no new X" cannot distinguish an empty folder from a filter that matched nothing in a full one.
- **Inbox sections are capped at 64 and sorted oldest-first by file mtime; the board section is never capped.** The board is the work list, and silently dropping part of it is the failure this document exists to prevent. Ordering uses `ls -tr` rather than `stat(1)`, whose flags disagree across Darwin, FreeBSD and Linux.
- **Every operation in the family returns the calling member's own inbox, with bodies, via its own leading positional — and none reads another member's.** `--member-work-session-input-scan` renders the inbox through the four typed sections alone, with no hand-rolled `## inbox/<file>` walk beside them. Running both would render the same items twice, in two orders, from two sections disagreeing on membership and on whether bodies are present, which is the double-description this document exists to prevent. The typed set is complete only because of `## Other Inbox Items`, which carries exactly the items whose prefix is none of the typed three.
- **A fourth inbox section exists because the other three are a whitelist.** `## Other Inbox Items` carries every inbox item whose prefix is none of `inquiry-`/`reflection-`/`note-` — in practice `task-`, `proposal-`, `change-`, `idea-`, `warning-` and `interview-` items all turn up there. Without it "the member's own inbox" quietly means only the three whitelisted prefixes, and `interview-`/`dispatch-` — the tracking-document kinds — are unreachable. Its predicate is a negative one, so its filter is spelled out in the empty-case NOTE rather than derived from a prefix that does not exist.
- **Inbox item blocks carry the whole item, framed by a declared line count and no delimiter.** The block grammar is `^## ` anchored and a real body legally contains lines starting `## ` — measured, not hypothetical — so the heading rule alone cannot survive raw bodies. No delimiter fixes it: every fence or sentinel is a string some body may legally contain, and a rarer one only moves the collision further away. `body-lines: <N>` cannot be imitated, because nothing in the body is matched against at all; it keeps the document line-oriented so awk and grep still work; the body stays byte-exact; and it is self-checking, because after N lines a reader must find `## ` or EOF and can say the document is corrupt when it does not. `body-lines:` is always the **last** key before the body, so `body-final-newline: absent` and `body-truncated:` sit before it.
- **One awk per section, never a subprocess per item.** This runs on every session for every member, so the inbox read is on the hot path. `sh-lib/AgentsInboxItemBlockPrint.awk` renders a whole section in one invocation, reading each file exactly once and deriving the frontmatter, the framing, the byte cap and the body from that single read. It sets `RS="\004"` so each file arrives as one record — which is also the only way to see whether a stored file ends in a newline, a fact awk's normal line splitting discards and that would otherwise cost a `tail -c 1` per item. Measured on 64 real items: 50 renders in 1s for one-awk-per-section against 4s for 5 renders of the two-subprocesses-per-item shape — roughly forty times faster, and the process count stops growing with the item count.
- **Two caps, two marks, and neither stands in for the other.** The item cap (64, mtime oldest-first) cuts how many items a section carries and is marked at section level with the ratified inbox form. The per-item byte cap (8192) cuts one item's body and is marked *inside that item's own framing*, as `body-truncated:` naming the stored size so a member knows to go read the whole thing. A mid-frame cut with no mark is not a smaller document, it is a corrupt one: a reader consuming `N` lines walks straight into the next block. The cap cuts whole lines only — half a line is byte-identical to nothing and would still count as a line.
- **A processed item's stored bytes and mtime are the drain's, not the original's.** `--librarian-inbox-to-processed` reads the body, writes a new file and deletes the source, so the processed copy is stamped at drain time and ends in exactly one newline whatever the source ended in — trailing blank lines are lost, a missing final newline is supplied. Under an `-all` scope a drained item therefore sorts to the newest edge, first out of reach under the oldest-first cap, and never carries `body-final-newline: absent`.
- **A fence-less item is all body, not nothing.** `AgentsBoardItemFrontmatterPrint.awk` prints nothing for a file with no `---` at all; doing that here would silently drop the item's entire content. Real inbox items are in exactly that shape.
- **A named item is included, exactly once.** `--item-include-inbox` extends named-item resolution to the acting member's own inbox, top level and `processed/`, because a tracking document is "like dispatch or interview" and an interview is an `inquiry-*` inbox item — without it a named interview matched nothing and the caller got an empty document and exit 0, which makes not-found indistinguishable from nothing-to-say. Only the acting member's own inbox: another member's would be an unauthorised read of private content and would return far more than the named item. A named item is emitted regardless of state and is exempt from the item cap, but an item that is both named and swept is rendered once — "named means included" guarantees presence, never duplication. An asked-for item that does not exist gets its own explicit line.
- **The named-item inbox reach is on the display call only, never on a discovery phase.** `--routine-coworking-session-input-scan` and `--magic-sweep-input-scan` both run a phase-1 scan whose output is consumed by a line-anchored awk that has no notion of the body framing. A raw body may legally contain a line beginning `blocks: ` or a `communication-channel-id:`, so feeding bodies into those harvesters would let body prose forge closure edges and survivor matches. The consequence is stated rather than hidden: the coworking closure still seeds from board items only, so a named inbox item is included but its own `blocks:`/`blocked-by:` are not walked.
- **The board section's `scope:` is unconditional whenever the section has content.** It sits outside the relatedness branch: inside it, a full-state call walks every board item and declares none of them — a section that walked the board and said nothing about what it walked. The line names all three filters that produced the set, including the two a relatedness scope does not set.
- **A rejection message names what was actually wrong.** `--client-sweep-input-scan` refusing a non-client member never reports "a partner-* member is not accepted" for a member that is not a partner — the same false diagnosis the guard arms deliberately design out of the invalid-option case. `--client-sweep-config-check` is client-only for the same reason its sibling is: a group whose two operations disagree about who may call them contradicts itself, reachable by a direct call.

### `--intern-main-loop` call contract

- No `<team-member>` argument, same shape as `--intern-mcp-server`. `--run` is required to actually loop; without it, prints syntax and exits.
- Each iteration: `--magic-heartbeat-config-check` first (its real exit code propagates, so a failed config check fails the operation loud), then one `--magic-heartbeat-spawn-proxy magic-coordinator --wait`, then sleeps `MAIN_LOOP_RESTART_DELAY_SECONDS` (magic-coordinator config scope, default 29). Log-and-continue regardless of the spawn's own exit code — no retry backoff, no cap.

### `--intern-mcp-server` call contract

- `--run` is required to actually serve; without it, prints syntax and exits — so a registration whose `args` omit it registers a command that can never serve.
- Registers into this workspace's own MCP config only, command resolved to this workspace's own `DistroAgentsTools.fn.sh`, args `["--intern-mcp-server","--run"]`, no `env` (the operation establishes the workspace environment itself). To register another workspace's tooling, run this operation from that workspace. Exposes exactly one tool, `execute`, backed by `--intern-mcp-execute`.
- The `execute` tool's `command` runs against this server's own `MMDAPP` by default. Its optional `workspace` argument overrides that for one call only: the given absolute path must already be a set up `myx.distro` workspace (its own `.local` present) or the call errors before running anything. Under a `workspace` override, the script runs via a real subprocess re-exec of `DistroAgentsTools.fn.sh --intern-mcp-execute` with `MDLT_ORIGIN`/`MDLT_OPTION`/`MDLC_INMODE` unset and `MMDAPP` set to the override path, so that workspace's own origin/option are re-resolved fresh exactly as a standalone invocation there would — not the server's own resolved values forced onto a different tree. Use it to run a one-off command against a sibling workspace without standing up a second MCP server registration; leave it unset for everything else.

### `--intern-mcp-execute` call contract

- Not an operation to invoke from a shell, a routine step or a board item — call the operation actually wanted instead. Takes no arguments; the script to run arrives whole on stdin. Stdout carries only what the script itself emits (keeping the JSON-RPC wire clean); the exit status is the script's own, propagated unchanged. Runs with the workspace environment already established — `MMDAPP`, `MDLT_ORIGIN`, `MDLC_INMODE`, `MDLT_OPTION` and `MYXROOT` are all set even when the call arrives with none of them.

### `--member-comms-slack-presence-*` call contract

- `--member-comms-slack-presence-keep <team-member> [--ttl <seconds>]`, `--member-comms-slack-presence-status <team-member>`, `--member-comms-slack-presence-stop <team-member>`. Default TTL 300s. Declares `rtm:stream users:read`.
- Presence is held, never set. `users.setPresence` accepts only `auto|away` and has no `active` value; Slack marks a user active only while a client holds a connection. A clean close reads away within seconds, so the ten-minute idle transition applies to a connection left open and never to one that ended.
- User identity only. `rtm.connect` answers `not_allowed_token_type` for a bot token, so a member with no `SLACK_USER_TOKEN` errors rather than silently falling back to the shared bot.
- Keyed on `<team_id>:<user_id>` from `auth.test`, not on the member name: one Slack account can back several members (`magic-coordinator` and `client-ndm` are the same account), and one holder per account is the invariant. Per-workspace user ids keep separate workspaces on separate holders automatically.
- The holder is found by argv match, not a pidfile — no stale state to reconcile after a crash, and a reused pid cannot false-match. Argv carries the identity key alone; the socket url arrives by environment and the token never reaches the holder at all, the url carrying its own authorisation.
- `keep` is idempotent: no holder starts one, a live holder gets `SIGUSR1` and extends in place. `SIGHUP` is not used for this — `nohup` sets it to `SIG_IGN` in the child. Start is guarded by an atomic `mkdir` lock, since two callers reaching the probe together would otherwise both start and contend over one account's presence.
- TTL expiry is what stops an abandoned caller leaving a persona falsely active indefinitely.

## `--member-comms-slack-profile-*` call contract

- `--member-comms-slack-profile-set <team-member> [--display-name <v>] [--status-text <v>] [--status-emoji <v>] [--status-expiry <ts>] [--avatar <path>] [--presence auto|away] [--snooze <minutes>|--snooze-end]` and `--member-comms-slack-profile-get <team-member>`. Both declare `users.profile:read users.profile:write users:read users:write dnd:read dnd:write`. A top-level section, not a child of the help-exclusion section above: unlike the presence family, both of these carry a full help pair.
- Own file for size only, routed from `AgentsTools.MemberCommsSlack.include`'s own `case` by a `--member-comms-slack-profile-*` glob, so the top-level dispatcher keeps its single `--member-comms-slack-*` arm.
- Persona identity only, enforced in three layers rather than one. `--identity-bot` is refused in the option loop; `--identity user` is passed explicitly on every call, so a member with no user token fails loud instead of silently acting as the bot; a `routine-*` name is refused outright with its own message, so the cause is never misreported as a missing token.
- An empty string is a value, never an absence. `--status-text ''` clears the status, and empty `--display-name` and `--status-emoji` clear theirs; those three guard on positional presence, the remaining value-taking flags on a non-empty value. Whether any field was given at all is a counter, never a test of the values.
- `status_text` and `status_emoji` must travel in the same request. Slack's actual behaviour, not its error string: a request carrying BOTH keys is accepted whatever the two values are, and the refusal `must_clear_both_status_text_and_status_emoji` fires only when one of them travels alone AND is empty. The rule is about which keys are in the request, never about their values — a guard written from the error's wording rather than its behaviour refuses legitimate calls.
- `--avatar <path>` sets the photo, through `users.setPhoto` and `--intern-op-slack-call --upload-file image=<path>`. Always its own call: upload wins at that op's transport, so folding the photo into the profile facet's `--json-body` would silently discard every profile field and still answer `ok:true`. Slack has no clear-the-photo call, so a photo is replaced and never unset.
- The avatar path is validated in the arm, at parse time, rather than left to the upload call -- it must exist and be a regular file, and it must contain neither `;` nor `,`, which curl's own multipart value syntax reads as part metadata and as a multi-file separator. This is hoisting, not duplication: with four facets, a path fault caught at call time surfaces only after the profile fields have already landed. No tilde expansion, no canonicalisation, and no local image sniff -- an unreadable or non-image file is Slack's own `invalid_image`/`bad_image` to report, and there is no false-success shape here of the kind the file-fetch HTML sniff exists for.
- Up to four separate calls: `users.profile.set` through `--json-body`, which that op refuses to combine with `--form`; `users.setPhoto` through `--upload-file`; and `users.setPresence` and `dnd.setSnooze`/`dnd.endSnooze` through `--form`. Every field is validated before the first request leaves the host, because a value rejected after `users.profile.set` already landed leaves the persona half-written.
- Partial application is reported, never hidden. One `PROFILE_SET_FACET=` plus `PROFILE_SET_STATE=applied|failed|not-requested` pair per facet, exit 1 if any facet failed, and the facets reported applied really were applied. Nothing is rolled back and nothing is retried under another identity.
- `profile-get` is a multi-facet read and takes the same exit-code shape `--intern-op-slack-check` uses: 0 every facet read, 3 some read with the rest named, 4 none read though the operation ran, 1 failed before any facet was reached. A failed facet is unknown, never a report that the field is unset.
- Neither op is named in `--intern-op-slack-check-scopes`'s polled list. That list is declared by its caller in `AgentsTools.MagicHeartbeat.include`, and adding these two would make every heartbeat warn on any coordinator token that lacks the three write scopes.
- `profile-get` reports every named field `users.profile.get` returns, including `title` and the avatar. A field this op cannot see is a field a set cannot be verified against, and comparing two personas then means reaching past the tooling to raw `curl`.
- Custom profile fields (`fields.*`) are still not emitted. Their keys are workspace-defined, not a fixed path the field extractor can be pointed at, so enumerating them needs a different reader.

## A profile is per workspace, and a rendered name is not profile data

- One Slack account can back several members, and a profile belongs to one workspace: setting it in one changes nothing in another. Bringing a persona into line across workspaces is a real per-workspace operation, done through `profile-get`/`profile-set` for each, never once.
- A name that reads differently in two workspaces is not necessarily different data. Which of `display_name` and `real_name` gets rendered is a per-workspace **viewer preference** (Preferences → Messages & media → "Display people's names as"), so identical profiles show two different names and no profile write can reconcile them. Never diagnose a name difference from the rendered string alone — read both fields first.
- `display_name` IS the `@mention` handle. Do not change it to fix how a name renders: setting it to the persona's full name makes the rendered name agree and silently destroys `@handle`, which then matches nothing in the message composer. Keep `display_name` identical across workspaces as the handle, let `real_name` carry the full name, and treat the rendered difference as the viewer setting it is.
- `title` is backed by a workspace-defined custom field, so it is not writable everywhere. Where custom fields cannot be filled, `users.profile.set` answers `"ok":true` and leaves it empty — in the `{"profile":{"title":…}}` form, the `{"name":…,"value":…}` form, and the `{"profile":{"fields":{"<id>":…}}}` form alike. Silent accept-and-discard is the expected outcome there, not a defect to chase.
- Before blaming the token or the call shape for a field that will not stick, write a plain standard field such as `phone` as a control. If that persists and the custom field does not, the difference is the workspace, not the credential — measured exactly that way. Clear the control afterwards.
- Custom field ids are per workspace and carry no stable meaning: the same "Title" label is a different `Xf…` id in each. Resolve the id from `team.profile.get` for that workspace; never carry one across.
- `color` and `huddle_state` are Slack-assigned and not settable; they differ between workspaces for the same account and mean nothing. `users.info` standing fields — `is_admin`, `is_owner`, `is_restricted`, `tz` — are the ones that would signal a real difference in the account itself.

## A member's own bot token, then the team's

- `SLACK_BOT_TOKEN` resolves in two steps: the acting member's own scope first, the `magic-team` scope after it. `AgentsToolsResolveSlackBotToken`, defined in `sh-lib/AgentsTools.CommsSlack.include` (no Slack code lives in the dispatcher: each Slack op has its own routing-only arm there, and that one file holds every non-member Slack op and every helper they share), is the only implementation; every send, scope check and id resolve calls it rather than reading either scope directly.
- The two keys are different credentials, not one key in two places. A member's own token is that member's bot identity; the team's is the shared fallback for members that hold none. Keeping the *team's* token in some member's scope is forbidden: it makes the whole team's identity a property of one member's config.
- It prints `<source> <token>`, `member-bot-token` or `shared-bot-token`, so a caller reporting which identity it acted under does not resolve the question twice. `magic-team` itself is never labelled `member-bot-token`: its own scope *is* the shared scope.
- `magic-team` here is an identifier, not a name. It is load-bearing in the scope key, the channel and the bot handle, and it does not follow the team's identity — read `magic-team/magic-team.shared.md`'s own "Identifier and identity" before renaming either.
- The `@member:` attribution prefix the send op stamps on an identity swap applies under the shared token only. A member sending under its own bot is already itself on the wire.
- A member needs no user token to post under its own name. The app declares `chat:write.customize`, which overrides `username` and `icon_url` per message, so a persona can post with its own display name and avatar into any channel the bot is in, without that persona's account being a member of that channel. No operation sends those overrides today. A user token buys what the bot genuinely cannot do — holding presence is the real case — never the name on the message.

## A member's own workspace, then the team's

- `SLACK_WORKSPACE_DOMAIN` — the X-Request-Detail header's workspace field — resolves in the same two steps as `SLACK_BOT_TOKEN`: the acting member's own scope first, the `magic-team` scope after it. `AgentsToolsResolveSlackWorkspaceDomain`, defined beside `AgentsToolsResolveSlackBotToken` in `sh-lib/AgentsTools.CommsSlack.include`, is the only implementation; `AgentsToolsEmitRequestDetailHeader` is its only caller.
- A member's own value exists only where something has actually resolved and persisted it: `--intern-op-check-configs <member> --resolve-slack-workspace-into SLACK_WORKSPACE_DOMAIN`, run against a token that same member holds itself, wherever that member's own config-check pass runs. A member with no such pass, or holding neither token, never gets one persisted and falls to `magic-team`'s every time. **That fallback is a wrong answer, not a silent correct one, wherever the member's own token authenticates against a different workspace** — every call it makes is then labelled with the team's workspace while running against its own. Chase it: the fix is a config-check pass for that member, never a cross-scope read.
- **Either token kind resolves it, and a scope may legitimately hold only a user token.** `auth.test` returns the same `url` under both; `bot_id` distinguishes the kinds and nothing here consumes it. `AgentsToolsSlackResolveWorkspaceForScope` reads `SLACK_USER_TOKEN` first, then `SLACK_BOT_TOKEN` — user first because a member's own Slack traffic runs under its user token where it has one (`AgentsTools.CommsSlack.include`'s own `sendIdentity` selection), so that is the workspace its calls should be labelled with. `--client-sweep-config-check` declares both keys optional, and the resolver agrees with that config contract.
- Live today for `magic-team` (`--magic-heartbeat-config-check`, the main loop's own pass) and any `client-*` member with a token of its own (`--client-sweep-config-check`, that member's own sweep pass). A member outside those two families that later gains its own Slack identity needs its own config-check pass wired the same way before this fallback does anything for it.
- Unlike the token resolver, this one prints only the resolved domain (or nothing) — no `<source>` label — because the header emitter, its only caller, only ever needs the value itself and already carries `<lookup-failed>` for the not-found case.

## `--member-comms-slack-file-share` call contract

- `--member-comms-slack-file-share <team-member> <target> (--from-file <path>|--from-stdin) [--snippet-type <v>] [--title <v>] [--comment <text>] [--identity-bot]`. Declares `files:write chat:write im:write channels:read im:read`. Reached by the existing `--member-comms-slack-*` glob, so it costs no dispatcher line.
- Three calls, one operation to the caller: ask for an upload URL, POST the bytes with no credential, complete the upload into the conversation. `files.upload` is retired and is not used. A failure names which of the three failed; two done and the third failed is a failure, never a partial success.
- Step 2 is `--intern-op-url-post-bytes`, not `--intern-op-slack-call`: the pre-signed URL is a bearer capability and that request must carry no credential at all. That op's own contract carries why the separation is structural.
- **The conversation id comes from `--resolve-target`'s own lexical rule**, reached by calling `conversations.info` through the primitive. A party id is opened as a DM under the acting identity, a conversation id passes through, and anything else is that op's hard error with no guessing fallback. `SLACK_CHANNEL_HUMAN_OWNER` holds a **user** id while `files.completeUploadExternal` needs a conversation, so passing the resolved value straight through as `channel_id` is the exact failure the primitive's own header documents.
- **Target resolution runs before step 1**, so an unresolvable target costs no upload and never leaves a file behind.
- **`thread_ts` must be the thread's PARENT ts**, unlike `chat.postMessage` which also accepts a reply's — the same `<channel>:<ts>` target string meaning two different things across two sibling operations. A reply's ts is the value a caller most easily holds, so it is normalised to the parent through `conversations.replies`, reading `messages.0.thread_ts`; the field reader's rc 3 means that message is not in a thread and already is its own parent. The normalisation is **silent** — it gives nothing up, so it has nothing to report. Only an unreadable thread is an error.
- **The share carries no comment.** `files.completeUploadExternal` accepts `initial_comment` **or** `blocks` and silently ignores `blocks` when both are given, so it cannot render both versions of a message. `--comment` is therefore posted as its own message after the share, through `--member-comms-slack-send-message` — which is also what makes an in-body `@name` reachable, since that recognition lives on the message path. A file operation shares a file; composing a message is the message operation's job. Share first, message second: message-first announces a file that is not there, which asserts something false, where share-first is merely confusing. Two visible items in one thread is the accepted cost.
- **Bytes, never characters.** Step 1 needs the length up front, measured with `wc -c` under `LC_ALL=C`. Our bodies carry em dashes and emoji, and a character count sends a wrong length to a pre-signed upload, failing in a way that never names length.
- Sharing state is `"is_public":false` with `"file_access":"visible"` — private to the conversation and visible in it, which the help states in those words and never as "hidden".
- `--snippet-type` is one parameter and the whole snippet-versus-attachment surface: one code path, no mode. Its accepted values are **not** enumerated as a closed set anywhere — the value is passed through, and an unsupported one is refused naming what was passed.
- **The arm installs no EXIT trap and cleans up explicitly on every path**, because `--intern-op-slack-call` installs its own and clears it, which would silently take the arm's with it. See "An EXIT trap set inside an op replaces the caller's, silently".
- **Settled, and not an oversight:** the upload URL reaches step 2 as an argv value, where a Slack token would travel in a header file instead. The two differ in exposure — argv is same-user and lives only for the call, and this URL is single-use and expires, where a token is long-lived and reused. Ruled: it stays in argv, and `--url-from-file` is not added. The reason sits at the `--url` arm itself, because a reader comparing the two handlings next to each other will otherwise read the difference as a defect and "fix" it.

## The `--member-comms-jira-*` family

- `--member-comms-jira-whoami`, `--member-comms-jira-issue-search <jql>`, `--member-comms-jira-issue-read <issue-key>`, `--member-comms-jira-comment-read <issue-key>`. Read side only: nothing here creates or edits an issue, a comment or a field. Arm structure, credential resolution and error shapes mirror `AgentsTools.MemberCommsConfluence.include`; the worker is `sh-lib/AgentsJiraApiCall.py`, credentials by environment only.
- Own key set: `JIRA_SITE`, `JIRA_USER`, `JIRA_API_TOKEN`, read from the acting member's own scope with no fallback and never a `CONFLUENCE_*` value. One Atlassian account authenticates every product on a site, so the two sets legitimately hold identical values; separate sets are what allow one service's credential to be rotated, revoked, scoped to another site or pointed at another account without disturbing the other.
- `/rest/api/3/search` is retired. It answers 410 naming `/rest/api/3/search/jql` as the replacement, and that is the endpoint this family uses. Measured against `ndm.atlassian.net`.
- `/rest/api/3/search/jql` refuses an unrestricted query with HTTP 400, so a caller's JQL names at least one restriction. It pages by `nextPageToken` and reports `isLast`, and it returns no total — so a truncated page is reported as "more match, how many is unknown", never as a count.
- **A JQL Jira cannot resolve returns success with an empty page, not an error.** Measured both ways: a query naming a project key that does not exist, and a line of plain prose that is not JQL at all, each returned HTTP 200 with no issues. So an empty result set from `issue-search` is evidence about that exact query and nothing else, and the operation says so on stderr whenever it returns no rows.
- `issue-read` names the fields it wants. An unrestricted issue read returns every custom field the site defines, which is a large payload nothing here uses.
- `--format adf` is the default and `rendered` the alternative, the same round-trip reasoning the Confluence family's `storage` default follows: ADF is the document Jira accepts back on a write, and Jira's rendered HTML cannot be written back. Unlike Confluence's REST v2, Jira does serve the rendered form (`expand=renderedFields`, `expand=renderedBody`), so it is offered rather than absent.
- A description field returned as null is a real answer — the issue has no description — and is reported as that, with a zero exit, never as a failed read. A missing `fields` object or a missing `description` key is the failed read.
- A 404 means either the issue does not exist or this account cannot see it. Jira states the ambiguity in its own response text, and it is never reported here as "no such issue".
- **A rejected credential does not always surface as a rejection.** Measured with a deliberately wrong token: `/rest/api/3/myself` answers 401, so `whoami` exits 4, but an issue read answers 404 and exits 3 — Jira treats the unauthenticated request as anonymous, and a private issue is invisible to anonymous. So a 4 exit is `whoami`'s to give, and that is another reason to run it first after a token is filed rather than diagnosing a credential from a read that failed.

## Deprecated operation names

- A superseded name stays as a working shim: removed from help output, kept in the dispatcher, indefinitely. Any existing caller keeps working unchanged unless a real removal is separately proposed and approved.

## VS Code skill discovery

External product behaviour, read out of the installed build (1.134.0, `Visual Studio Code.app/Contents/Resources/app/out/vs/workbench/workbench.desktop.main.js`), so it is true of that build and is re-read there before being relied on again.

- A skill is a directory holding a literal `SKILL.md`. The scanner reads one directory level and does not recurse.
- `chat.agentSkillsLocations` is a `{"<path>": true}` map, and its value is additive: the resolver starts from the built-in defaults and drops one only where the map sets that exact path to `false`.
- Built-in defaults for skills: `.agents/skills`, `.github/skills` and `.claude/skills` per workspace folder, plus `~/.agents/skills`, `~/.copilot/skills` and `~/.claude/skills` once per machine.
- **A relative key is resolved against every listed workspace folder; there is no per-folder key.** So a key climbing out of one folder is correct at exactly one folder depth and wrong at every other, and a generated workspace listing folders at several depths cannot be served by any set of climbs.
- A `~/`-rooted key is resolved once, against the home directory, and is the only form that means the same thing from every folder.
- **Absolute paths are rejected for skill locations**, by `^(?![A-Za-z]:[\\/])(?!/)(?!~(?!/))(?!.*\\)(?!.*[*?\[\]{}]).*\S.*$`. The same pattern rejects glob characters — `*`, `?`, `[`, `]`, `{`, `}` — and a rejected key is dropped with a log line rather than failing the load. VS Code's own published guidance shows a glob example for this setting; this build does not accept one. `instructions` and `prompt` locations skip the pattern entirely and do accept globs, which is the likeliest source of the discrepancy.
- The setting is `restricted`: an untrusted workspace drops it, so a workspace that has never been trusted shows no members at all, whatever is configured.
- Reaching a location above a workspace folder is otherwise gated by `chat.useCustomizationsInParentRepositories`, off by default, and even on it climbs only to a trusted `.git` root.
- A member can be present, correctly symlinked and carrying a valid `SKILL.md`, and still not load: discovery skips an entry for a missing `name`, a missing `description`, a `name` that disagrees with its directory, a parse error, or a duplicate `name` already claimed by a higher-priority location. Priority is workspace-local, then user, then plugin, then extension. None of these is visible from the filesystem.
- **A member reachable from two locations at once is a candidate for silently not loading, and it is not a filesystem fault.** The same member is normally installed both at the workspace root and in the home skills directory, and both are discovery locations, so one entry is loaded and the other is dropped as a duplicate `name`. Every filesystem check comes back clean either way. Confirming it means reading what discovery actually decided — the skills list the chat client renders, or its own discovery log — not the directories. Recorded as a candidate; nothing here establishes it as the cause of any particular member failing to appear.
- `.agents/skills`, `.github/skills` and `.claude/skills` at the workspace root hold one member set under three names: `--install-skillset-symlinks` fans the same members into all three. Naming more than one of them in `chat.agentSkillsLocations` scans one directory repeatedly rather than adding a location.

Consequence for this package: the members installed at the workspace root cannot be named by this setting, so the generated `.code-workspace` lists the workspace root as a folder and the built-in defaults find them there. The emitted key is `$MMDAPP/.agents/skills`, one absolute path naming that one directory. It adds no discovery: the validator above rejects an absolute value, and measured with the root listed and no key at all the members are found regardless. It is emitted because `AgentsTools.Install.include` fails the install when the setting is absent, and that check greps for the key name without reading its value.
