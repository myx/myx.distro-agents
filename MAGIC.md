# MAGIC.md — myx.distro-agents

Team-owned notes for the magic-* team.

## Reaching Slack, email and Trello

- `DistroAgentsTools.fn.sh` is the entry point the team routines use for every Slack, email and Trello action. A routine calls one of its operations; it never assembles a `curl`, IMAP or Trello API call of its own.
- The tool resolves the credentials and holds the per-platform API detail behind its operation names, so a caller supplies the operation and its arguments and nothing else.
- An action the tool exposes no operation for is escalated, not reached by a direct API call.

## Adding an operation to `DistroAgentsTools.fn.sh`

- Single-dispatcher convention, shared with every sibling `Distro*Tools`/`Distro*Command` script: exactly one top-level function, one `case "$1" in ... esac`. New operations go inline in that `case`.
- Never a separate `DistroAgentsTools<OpName>` function per operation. Such a function tends to call `DistroAgentsTools` assuming it exists as a sibling, which holds only because the file happens to define it — not because the pattern is sound.
- Inline the logic in the operation's own `case` arm, especially for single-liners. A helper shared by several arms of one family goes in that family's own arm, not at file scope — see below. `AgentsToolsAssertBareName` is defined in `AgentsContext.UseAgentsTools.include`, which every entry-point function sources, because it is genuinely general; that is the bar, and it is not licence to add more.

## Operation contracts worth knowing before calling

- `--sweep-read-incoming-comms` defaults to `--pretty`: `ts | user | text` lines via this package's own `sh-lib/AgentsSlackMessagesFormat.awk`, not raw JSON. `--raw` opts back into the full JSON response. Raw is not the default because every real caller ends up hand-parsing it.
- The no-target "sweep everything" mode is a macro-operation for the main-loop Comms step specifically, not a generic convenience loop: it combines both watched Slack targets, `--comms-email-check` and `--comms-trello-check` into one call. Keep that framing when extending it, and check whether the comms sweep actually needs a platform before adding one.
- `--owner-cleanup-purge` takes no arguments and always purges exactly one fixed directory, `$MMDAPP/.local/.cleanup`, leaving the folder itself in place. No caller-supplied path means no traversal surface to guard, so it needs no canonicalisation. It exists to route around a permission-engine limitation — a blanket `rm ` deny cannot be carved out by a more specific allow, because deny wins regardless of specificity — not as a general `rm` wrapper.

## The `--owner-setup-*` family

- A setup method sets up. This is the family a user runs to set this installation up, and the domain in the operation's name is what gets installed.
- One domain per macro part of a working installation, and the family is open: a domain with no defined check set reports "no checks defined yet" rather than an invented check.
- Five states. A bare call writes the readable status and names the command that sets the domain up; `--check` writes the per-setting detail; `--apply` carries the setup out non-interactively; `--print-apply-command` writes the command that would carry it out and changes nothing; `--wizard` is the interactive form and is not built.
- `--print-apply-command` is the full command template: every option the domain declares, required and optional, set or not, a placeholder per value and a how-to-obtain line per option. Its shape follows the domain rather than being one line: a domain whose options are all plain renders as a single command line, and one carrying a secret renders a stdin-fed form instead — its secrets as `KEY='<placeholder>'` lines, each carrying the line-continuation the pipe below needs, fed into `--values-from-stdin --apply` — so no secret reaches a command line. A placeholder is rendered single-quoted wherever it lands, on a flag's value as much as in the stdin set: `<` and `>` are redirections bare, which makes the stdin-fed form a syntax error and the plain form a command that parses and then redirects instead of running. `--check` is what reports whether the domain is set up, so this one exits 0 and is not a readiness gate. It is the public name for the engine's own `--render-full`; the engine's mode words are internal plumbing and never the contract. A value to store — a `<config-option>`, `--access-root`, `--values-from-stdin`, `--set-as-default` — belongs to `--apply` alone and is refused here rather than accepted and dropped.
- Argument grammar, family-wide: options and their values first, then at most one sub-operation last. Anything after a sub-operation is an error, and so is an option whose meaning depends on a sub-operation that is absent.
- An option is accepted only by a domain that declares it. A flag taken and then ignored is the failure this rule exists to stop, so a domain gone from one of those gates has stopped declaring the option rather than been overlooked.
- A domain declares; `--intern-op-owner-setup` carries out. The option machinery lives in that one primitive so an option two domains share is applied in one place, not once per domain.
- A config setting is judged by its VALUE at its own use site — unset or empty is FAIL, never OK, and a config file existing is never the check. An artifact the installation is made of, such as a console script or an access fragment, is a different subject, and there its own presence is exactly what is being asked.
- Settings and preconditions are separate lists and stay that way: a setting is a value a domain declares and the engine stores, a precondition is a state of the installation. They are not a performable/reportable split, and reading them as one is what left `--apply` handing its preconditions back as manual steps. For `claude` the settings are the workspace root and the service selection; the CLI install, workspace trust, console freshness and the access grants are preconditions, and `--apply` carries out every one of them.
- Workspace trust is neither: it is a boolean on this workspace's entry of `~/.claude.json`, claude's own machine-global state file, rather than a value in a config scope of ours, so it is not an option any domain declares. `--apply` records it for `claude` directly, ahead of the engine call, because claude discards every `permissions.allow` entry of an untrusted workspace and everything else the apply writes is inert until it is set. `sh-lib/AgentsClaudeProjectTrustUpsert.awk` is the writer, `AgentsClaudeSettingsVerify.awk` the reader, and the caller installs the writer's output over the state file with the file's own mode carried onto the replacement. An absent, symlinked or unparsable state file stops the run rather than being replaced.
- A diagnosis answers about the current `$MMDAPP`. A domain that can also report every registered workspace offers that behind `--all-workspaces`, never as the default: someone running it in a workspace is asking about that workspace.
- Every finding that blocks is either carried out by `--apply` or contributes a setup step saying in prose what has to happen. A blocker that is neither strands the reader, who runs what he is given and is still not set up.
- **`--apply` is the whole setup, and a bare call names one command.** Ruled against the alternative, a three-line list of steps: what the reader is handed is **one** command — `--owner-setup-<domain> <options...> --apply` — and nothing standing beside it. So a bare call prints exactly `--apply` (with `--set-as-default` where a selection has to be repointed), and a step survives beside it only where nothing can carry it out. Naming a step `--apply` performs, or telling the reader to re-run the diagnosis to confirm, is the defect this rule exists to stop.
- **A bare call asks what has to be supplied to START, so it names required-and-unset options only.** The engine's `--render-missing` is that question and skips an optional one; `--render-full` behind `--print-apply-command` is the other question — every option the domain declares, set or not — and the bare call's own no-required-values branch points at it in the same breath. Ruled against a bare `--owner-setup-claude` whose only outstanding option was the optional `CLIENT_ACCESS_ROOTS_EXTRA`: an option the user is definitely not required to supply in order to start is an automatic one, and a bare call does not show it at all. An optional extra rendered beside a required one is indistinguishable from a blocker, which is the defect; it is also what put a second command beside `--apply` on an unconfigured workspace, against the rule above.
- **A value the domain's own service selection supplies is a third case, neither required nor optional.** `SPAWN_CLI_SERVICE` blocks a spawn and is still declared `--allow`, because `--apply` writes it from `--service-value` and a `--require` would refuse the very call that supplies it. So the reader is never asked for it: unset, it is the domain arm's own needs-apply blocker, and the bare call answers it with `--apply` alone. Wherever a domain declares `--service-key <KEY>`, that KEY belongs in this case rather than in the required set.
- The sequence `--apply` runs, in dependency order: claude's workspace trust, because the `permissions.allow` entries written later are discarded while the workspace is untrusted; the engine call, which installs the domain's own subject and stores its settings; the workspace integrations for a domain declaring `SPAWN_CLI_SERVICE`, because the access fragment and the claude permissions are built from the `CLIENT_ACCESS_ROOTS_EXTRA` that call stores; then the domain's own diagnosis, whose verdict is printed and whose status becomes the operation's own. The integrations step is gated on that same diagnosis failing first, so a workspace already current has nothing rewritten over it.
- Each of those steps runs in a subshell of its own and is tested. Both are needed on bash 3.2: the enclosing subshell is tested by its caller, which suspends `set -e` inside it, and a step that aborts on its own — `--make-console-command`'s redirection is measured doing exactly that when it cannot write — would otherwise take the sequence down with it and skip the handler that names the failing step.
- The one finding in the `claude` domain that no command carries out: a member link resolving to a second copy of that member. `--install-skillset-symlinks` keeps an existing link exactly as it is, whatever it points at, so no run of it moves one — measured, not assumed.
- **A domain declares `--install-command` only where `myx.common` actually carries the installer.** `myx.common which install/claude` resolves and `install/copilot` exits 1, so the shared `claude|copilot` arm declares the command for `claude` alone. The engine already answers the other case correctly: a domain declaring a probe and no command reports "is not installed and this domain declares no way to install it" and stops, where declaring a command that does not exist ran it and reported a failed install instead. A new CLI domain therefore gets no install command until one exists for it, rather than inheriting a `myx.common install/<domain>` that may not.
- **The copilot access fragment has no user-facing operation.** Ruled against a suggestion that the human-owner run one: there is no such command for him to run, because installing the workspace integrations already does the whole of it — that was the task. There is no separate fragment step for a user; it is all internal, and nobody outside needs to know it exists. `--install-copilot-access-fragment` stays as an internal step of `--install-workspace-integrations`, which calls it — the same shape `--install-skillset-report-render` already has, and the reason it is not renamed to an `--intern-op-*`. It is out of help, out of every `--owner-setup-*` remedy and step list, and out of every printed line; those name `--make-workspace-integrations`, which regenerates the console and rewrites the fragment in one call.

## Which help a reader needs

- A member is authorised for the operations its own armed file declares, not for the tool's whole surface. `DistroAgentsTools.fn.sh --member-help <team-member>` reports that member's declared operations together with their syntax — that is what a member reads to decide what it may call.
- `sh-lib/help/Help.DistroAgentsTools.help.md` is the complete call contract for every operation. Read it when developing or updating the tool itself. It is not the reference for what a given member may call.
- The console-launcher role carries no `sh-scripts/*.fn.sh` command of its own and no help pair. `DistroAgentsConsole.sh` is a workspace-root launcher, generated the way the four sibling `DistroXConsole.sh` scripts are, and none of those four implement `--help`. That absence is the convention, not a gap to fill.
- **Three depths, and `Help.DistroAgentsTools.include` is where they separate.** A bare call prints the default syntax alone — help entry points, the two root install methods, `--owner-setup-<domain>` and the general agents-config line. `--help-syntax` adds every other operation's syntax line. `--help` adds the manual instead, which opens with that same full list, so nothing is lost by the default block being short. `DistroSourceTools`/`DistroLocalTools` carry the same shape, at three to five default lines each.
- **The two root install methods are the ones nothing else calls.** `--install-workspace-integrations` calls `--install-vscode-integrations`, `--install-skillset-symlinks`, `--install-claude-permissions` and `--install-copilot-access-fragment`; `--install-workspace-restrictions` is called by nothing and calls nothing. Those two are the default syntax's; the steps behind the first are reached through `--help-syntax`.
- **Every `echo` line in that include stays flush-left, inside a `case` arm too.** `--member-help` cuts the file as data with a `^echo "` anchor, and an indented line matches the operation needle while failing the anchor strip — so it is printed with its own `echo "` prefix rather than dropped. The cut is silent about it either way.
- **`--help-setup-<domain>` prints one domain's setup manual, and the mapping is mechanical**: the operation name minus `--help-`, as `sh-lib/help/Help.DistroAgentsTools-setup-<domain>.help.md`. Routed by glob, so a domain gaining a document becomes readable with no arm added. `DistroLocalTools --help-install-unix-bare` over `Help.DistroLocalTools-install-unix-bare.help.md` is the precedent for both halves.
- **Those documents are `cat`, never `myx.common lib/catMarkdown`.** The renderer reads `_` as emphasis and drops it wherever it lands — backticked, bare, bold and tab-indented alike, and `\_` renders as a bare backslash — so `ANTHROPIC_API_KEY` reaches the reader as `ANTHROPICAPIKEY`. A fenced ``` block is the one construct that survives. Measured, one-true-awk pipeline, on this platform. The same defect already reaches `--help`: 140 lines of `Help.DistroAgentsTools.help.md` carry an underscore, 108 of them inside backticks, and every one is mangled today. Fixing the renderer is `myx.common`'s, not this package's.
- **A per-domain document is cut by the `--member-help` awk unchanged.** Its option blocks use that file's own grammar — `##  Heading:`, a two-tab `--flag <value>` line, three-tab prose — so a caller wanting the blocks for the options a workspace has not configured yet passes those flag names as the name set and needs no second parser. That is what the format is for; the prose shape is free everywhere else in the document.
- **The catalogue and the document say different things about one option.** `AgentsToolsOwnerSetupOptionSpec`'s `how-to-obtain` field is the one line `--print-apply-command` prints beside a placeholder; the document is the manual — the account to hold, the order of operations, what is optional and what it costs to leave unset. Neither is generated from the other, and a new option is added to both.

## Sending commands into a console channel

- Send one command per line. A `;`-joined line drops its leading command silently — a leading `echo` produces no output and no error.
- A non-zero exit status aborts the remainder of a sent batch. Put anything that can legitimately return non-zero in its own send.
- Two sessions sharing one console channel interleave their output into a single log. Capture by line offset to separate them.

## Console channels have no per-caller isolation

- The channel id is composed from a fixed prefix, the workspace slug and the console short name. It carries no caller component.
- Two concurrent callers against the same workspace and console therefore resolve to the same channel and can tear down each other's session.
- A `channel_not_found`, or a console dying mid-use while another session is active, is this condition.

## `DistroAgentsConsole.sh` is an agent CLI, not a shell dispatcher

- The four sibling consoles (`Source`/`Local`/`Deploy`/`Remote`) hand a piped line to a shell dispatcher. This one launches an agent CLI instead — `DAGC_KNOWN_CLIS` is `copilot claude grok scaleway` — so a line piped into it arrives as a *prompt*: a model reads it, reasons about it, and then decides whether to run it.
- **A read-only `DistroAgentsTools.fn.sh` call sent through this console therefore costs a full LLM round-trip.** Measured on a plain roster read: roughly 45–58 AI credits and about three minutes, against the same call run directly returning at once and costing nothing. A routine that reads the roster or a board item once per member pays that per member.
- Run the script directly for anything read-only: `bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" <operation> ...`. Reserve the console for work that actually needs an agent session.
- **Read-only only.** Whether a write operation is equally safe by that path is unestablished — the console may supply identity or locking a write depends on. Do not generalise this without checking that first.

## Configuration lives under the workspace's own `.local`

- `--agents-config-option` resolves configuration under `$MMDAPP/.local/.agents/`, one file per scope: `<entity>.agent.env`, holding that entity's own keys.
- A setting is read at the moment a call needs it, never baked into anything at install time, so a changed value is in force on the next spawn and there is nothing to regenerate or reinstall for it.
- `.local` is the installed release, not a tree a session maintains. It can lag `source` after a source-side rename, and a lookup against a lagging release returns empty rather than failing — an empty result is not evidence that the configuration is missing.
- Closing that gap is a release step. A session does not sync, copy or hand-edit anything under `.local`.
- **`.local` is never a baseline, never evidence, and never a place a session works.** Nothing there — content, dates, sizes, or the absence of something — establishes anything about the source tree, and a session does not read it to find out. The configuration layer's own runtime lookups above are that mechanism working as designed, and are not an exception to this. Recorded from the human-owner's ruling of 2026-09-15, not derived by this team.
- **Where the tooling owns the representation, there is no path for us; where the file is itself the thing, the path is how we refer to it.** Inbox items, board items, backlog entries and configuration are records the tooling creates, names and locates, so their layout is an implementation detail and "where does it live" is a malformed question rather than a forbidden one — each is reached through the operation that owns it. A source file is the opposite case: the file is the artefact and its path is its identity, which is why reading the code under review at its path stays ordinary work. Recorded from the human-owner's rulings of 2026-09-15, not derived by this team.
- Every other piece of state local to this machine — its config, allowlists, caches, settings — is the same case: it reaches no client, so changing it is not a fix and not the work.
- **A write to `--agents-config-option` creates that scope's file; a read does not.** `myx.distro-.local/sh-lib/LocalTools.Config.include` answers a read against an absent scope directly — nothing for `--select` and `--select-all`, the caller's own default for `--select-default` — and creates the file only on the way to a write. A typo'd or omitted operation falls through to that same creation and errors afterwards, leaving a phantom scope on disk that later looks like a configured member.
- **A created file is empty, mode 660 under a 770 directory — owner and group — so existence alone separates nothing.** A member nobody has configured and one a write has already reached give `[ -f ]` the same answer. Content is what discriminates: `[ -s ]`, or parsing the file for the key the question is actually about.
- **The config layer creates nothing on a read, and the caller guards still earn their keep.** They cover the residual cases: a write against an unchecked name, and a typo'd or omitted sub-command creating the file before it errors. `AgentsToolsAssertBareName` checks a name's shape and says nothing about whether that member exists; the existence check is `[ -d "$HOME/.claude/skills/<member>" ]`, the same one every `--member-comms-*` op already carries, and it belongs ahead of the first config access in any op that takes a member name.

## All non-member Slack code lives in one file, and that file is not the dispatcher

- Ruled in three parts, in this order: no Slack in `DistroAgentsTools.fn.sh` at all, every piece of it in separate arms; then not several sites but one, reached by an intern-op, with everything affected in that one file; then the helpers gathered into one place too, and that place is not `DistroAgentsTools.fn.sh`. Together they settle both halves: the dispatcher carries no Slack implementation, and the implementation is not scattered across per-op includes with a helpers file beside them either.
- `sh-lib/AgentsTools.CommsSlack.include` is that one file. It holds the shared helpers (`DistroAgentsToolsResolveTarget`, `AgentsToolsResolveSlackBotToken`, `AgentsToolsResolveSlackWorkspaceDomain`, `AgentsToolsEmitRequestDetailHeader`, `AgentsToolsInternOpSlackCallEmitFields`, `AgentsToolsSlackResolveWorkspaceForScope`) and all three non-member Slack operations — `--intern-op-slack-call`, `--intern-op-slack-check`, `--intern-op-slack-check-scopes`.
- `DistroAgentsTools.fn.sh` keeps routing-only arms, exactly as Google, Trello, Confluence and Jira do. The member stubs keep one arm each; the non-member ops share a single `--intern-op-slack-*` arm that sources the one file, which dispatches on the op name. The prefix is claimed by that arm, so a future `--intern-op-slack-*` op routing elsewhere goes above it — the rule `--intern-op-item-*` already lives under.
- **A separate include CAN be sourced from inside an op include — the claim that it cannot is false.** Sourcing dispatches only if the sourced file's `case` has an arm matching the caller's `$1`. `AgentsTools.CommsSlack.include`'s `case` ends in a branch that dispatches nothing for any name that is not one of its own three ops, so any other op include sources it at its own top, gets every helper defined, and runs no operation. That is how the member stubs and `--intern-op-check-configs` reach the helpers.
- That silent branch does not weaken the invalid-option discipline: the arm above it catches any unimplemented `--intern-op-slack-*` / `--intern-op-check-slack-*` name and returns 1, and the dispatcher routes the whole `--intern-op-slack-*` family into the file, so a mistyped Slack op is rejected by that arm rather than by the dispatcher's own invalid-option branch.
- Out of that file, deliberately: the member and magic stubs. `AgentsTools.MemberCommsSlack.include` holds the `--member-comms-slack-*` stubs behind that family's one dispatcher arm, and sources `AgentsTools.MemberCommsSlackPresence.include`, `AgentsTools.MemberCommsSlackProfile.include` and `AgentsTools.MemberCommsSlackSocket.include` for their own ops. `AgentsTools.MagicComms.include` holds every `--magic-comms-*` stub, Slack, Trello, Jira and Confluence alike, behind the one `--magic-comms-*)` arm. These files are a member's own surface rather than the team's, and source `AgentsTools.CommsSlack.include` only for the definitions.
- `--intern-op-check-configs` is not a Slack op and carries no Slack call of its own. Its one call that has to reach Slack — `--resolve-slack-workspace-into <KEY>` — goes through `AgentsToolsSlackResolveWorkspaceForScope`, sourced from inside that branch alone so a config check not resolving a workspace never pulls Slack credential resolvers into its shell.

## An EXIT trap set inside an op replaces the caller's, silently

- Every operation is an arm of one shell function in one process, so `trap ... EXIT` inside an arm is the process's trap rather than that arm's. An op installing one while a caller's is already live replaces it, and the `trap - EXIT` it clears with removes the caller's along with its own.
- The caller then runs on with no trap and nothing saying so: its own later `trap - EXIT` calls clear nothing, and whatever its trap was protecting survives only on the paths that also clean up explicitly. Abnormal termination is exactly when the trap was the only cleanup left, and exactly when it is no longer there.
- An op reached through `$( ... )` runs in a subshell and cannot do this; an op called as a plain command in the caller's own shell can. Which of the two a call site uses is load-bearing, not a style choice.
- An op needing no temp file installs no trap and the question never arises.
- Where one is needed, explicit cleanup on every return path leaves the caller's trap intact but covers only the paths that were enumerated. A `set -e` abort, a signal, or an error in surrounding flow is by definition not one of them, and the file stays. Swapping a trap for explicit cleanup therefore trades one defect for another rather than removing one.
- The form with neither defect is a trap inside a `( ... )` subshell — or inside the subshell that a `$( ... )` already runs in, where the block has to return a value. The trap is then that subshell's own, so it can never touch the caller's, and it still fires on every exit from the block, failure and signal included. `AgentsTools.Owner.include`'s `--owner-workspace-forget` and `myx.distro-.local`'s `LocalTools.Config.include` are the worked examples. Arm the trap before creating the file, so there is no window in which the file is real and the trap is not.

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

- The writer emits, the caller installs: a temp created beside the target, then renamed over it. Same directory, so the rename is a same-filesystem `rename(2)` and therefore atomic. That much is invariant across the family; nothing below it is.
- The spelling is not agreed, and each of these is working code. `"<target>.$$"` inside a subshell carrying `trap 'rm -f -- "$tmp"' EXIT`, then a plain `mv` — `myx.distro-.local/sh-lib/LocalTools.Config.include`, and this package's own `sh-lib/AgentsTools.Owner.include`. `"<target>.$$.tmp"` then `mv -f --` — `myx.distro-system/sh-lib/system-context/Index*.include`, `myx.distro-source/sh-scripts/RebuildKnownHosts.fn.sh`. `mktemp "<target>.XXXXXX"` then `chmod` then `mv -f` — `myx.distro-source/sh-lib/SourceTools.Make.BuildCodeWorkspaceData.include`. The variation is real and is not drift to normalise.
- No existing site is converted from one form into another. The list above is what is written down, not the bound on this sentence: a form appearing nowhere in it — `"<target>.tmp.$$"`, carried at ten sites in this package's own `sh-lib/AgentsTools.Install.include` and at none in any sibling — is protected exactly as the listed ones are. A new site takes the form its own file already carries, or the nearest one in this package. Only an explicit instruction moves an existing form; a session never converts one on its own initiative.
- A temp under `/tmp` is the one placement that is wrong here: it trades the atomic rename for a cross-device copy, and a predictable name in a world-writable directory can be pre-planted as a symlink that both a `chmod` and the rename would follow. Beside the target inside the workspace, neither applies.
- Mode is inherited from the ambient umask, and `mv -f` carries the temp's own mode onto the target. A mode that matters is therefore set on the temp before the rename, never on the target. These files carry a path and a flag, no secret, and every client of the workspace has to read them, so none of them asserts one.
- Assert the entry landed, separately from the exit status of the command that wrote it. Re-running an idempotent writer over the installed file and comparing proves it, and needs neither a temp file nor a second tool.

## Writing new code here

- Prefer `awk` or POSIX shell for anything new in `sh-lib/`. Reach for Python only when the job genuinely needs it, and say why at the call site.
- `sh-lib/` already holds a parser, in awk and in Python, for every shape this package reads — frontmatter, board-item headers, Slack JSON, markdown, RFC822. A new parsing need is served by one of those or by extending one; writing another is the default mistake here.
- `python3` is a real runtime dependency of routine team work: the comms and session-context paths reach it on every platform. It is not a dependency of a bare `--owner-setup-*` run.
- `myx.distro-.local` generates a wrapper function named `Distro<ITEM>Tools` per subsystem, which for `Agents` is literally `DistroAgentsTools` — the same name as this package's own unrelated tool. The generated wrapper is install-time and subshell-scoped, and never coexists at runtime with the real tool.

## Conventions come from the sibling `myx.distro-*` packages

- `myx.distro-source` and `myx.distro-deploy` are the family's convention authority. Both are used daily, so their shape reflects decisions that were actually made and held.
- This package is the drifted one: it was written broadly against `myx.common` idioms and against whatever code sat nearest. A pattern found here is evidence of that drift until a daily-used sibling confirms it, and is never cited as precedent for anything else.
- `myx.common` is a separate project. Copying the nearest available example, from there or from this package's own recent code, is how the drift happened; grep the family before assuming a form is the house form.

## Scratch and temp paths

- A scratch location is either `mktemp -d -t "<prefix>-XXXXXXXX"`, the form `myx.distro-deploy` and `myx.distro-source` use, or a literal workspace path under `$MMDAPP/.local/temp/<name>` written out at each use site.
- `mktemp -d "${TMPDIR:-/tmp}/..."` is `myx.common`'s own form. A `${TMPDIR:-/tmp}` fallback belongs to code that runs where the workspace does not exist: `myx.distro-system/sh-lib/DistroImage.SyncScriptMaker.include` emits one into a script for a remote host. Code running inside the workspace falls back to the workspace instead — `myx.distro-.local/sh-scripts/workspace-install.sh` derives `${TMPDIR:-$MMDAPP/.local/temp}` — and that is the form written here.
- `$MMDAPP/.local/temp/<name>.$$` is the form written here. Two separate confirmations: `myx.distro-.local/sh-scripts/workspace-install.sh` confirms the location, falling back to `$MMDAPP/.local/temp` — it names its own scratch dir with `mktemp`, not a pid — and the pid suffix is the device the family's install temps use to keep concurrent runs apart. The path is spelled out in full at every use so the location is on the line itself. The MCP server's scratch root — `$MMDAPP/.local/temp/agent-mcp.$$/`, holding `wire.lock`, `req/<field>` and `out.<seq>` — is one instance of that form, not a rule of its own.
- Scratch is not the only shape a temp file takes here, and the two are not interchangeable. A temp that has a destination it is about to REPLACE follows "Installing a generated config over its target" above instead — created beside that target and renamed over it, in whichever of that section's spellings the file already carries. A scratch path has no destination, whereas an install temp IS the destination in progress, which is what makes its rename atomic.
- A count of sites in this package is not evidence of a convention. This package is the drifted one, so a form holds once a daily-used sibling confirms it and not before, however many times it appears here.

## `AgentsContext.include` is a parallel kernel, not a subset of `SystemContext.include`

- It does not source `SystemContext.include`. It defines `Require`, `Agents` and `DistroAgentsContext`, and nothing else.
- So inside `DistroAgentsTools` and on the `mcp__myx_distro__execute` surface, `Distro`, `Action` and `DistroSystemContext` are undefined and `$PATH` carries no `sh-scripts` directory.
- **The bootstrap guard `[ -z "$MDLT_ORIGIN" ] || ! type DistroSystemContext` is effectively unconditional in this package**, and it is what makes any following `Distro <Tool>` resolve at all. Never simplified away as redundant: any new site needing those functions needs the same two lines.
- **Resolution asymmetry decides the order.** `Require` resolves by file through `$MDLT_ORIGIN` and never consults `PATH`; `Distro` tries `type` first, then `PATH`. So `Require <Tool> || :` precedes `Distro <Tool>`. The `|| :` is load-bearing — it defers failure to `Distro`'s own exit status, letting the caller's trust-rule arms decide the verdict.
- **This context keeps its origin resolution local and delegates only the rest**, because it must serve remote-only and deploy-only workspaces. Its `SetInputSpec` is the parent's file with the tier half removed — its arms `return 0` where the parent falls through into `--distro-path-auto` and the five tier cases — so it sets no `MDSC_*` and resolves no tier. Making it a pure alias for the system context puts every invocation on a `.local`-only workspace through a tier cascade that has no tier to find.
- **An index read cannot avoid the system dispatcher.** `ListDistroProjects` makes 20 `DistroSystemContext` calls in its own body and `ListDistroDeclares` 18; `Require`-ing the tool does not avoid them, because the calls are inside the tool.
- **Sourcing `SystemContext.include` alone is not sufficient**, and this is the trap: it defines `Distro`, yet `Distro <Tool>` still fails, because `Distro` resolves through `PATH` and only a console session carries `sh-scripts` there. `Require` alongside it is what makes it work. Any description asserting otherwise is false while looking obviously true.

## Severity marks, and where a designed refusal gets lost

- `⛔ ERROR` is for a fault. `🙋 WARNING` is for a designed refusal. Where both appear on adjacent arms the asymmetry is deliberate and survives edits.
- **A designed refusal's defect is discoverability, not severity.** A warning emitted mid-run inside a composed multi-step operation is invisible in scrollback. The composed operation's own closing summary is what carries it, and the exit status stays truthful.

## Environment init in `DistroAgentsTools.fn.sh`

- `${MDLT_ORIGIN:=$MMDAPP/.local}` at file load is a default, not an init — it only fills a blank. The real init is `DistroAgentsContext --distro-path-auto` in the tail guard: `AgentsContext.include` declares no arm for that option, so it falls to the `*)` delegation and reaches `SystemContext.SetInputSpec.include`'s `--distro-*` arm, which reads `MDLT_CONSOLE_ORIGIN` and re-exports `MDLT_ORIGIN`. `DistroSourceTools.fn.sh` and `DistroDeployTools.fn.sh` carry the same call against `DistroSystemContext`.
- This entry said `--run-from-detect` and claimed the two siblings carried it. Both halves were false: measured, that spelling appears nowhere in this package, `myx.distro-source` or `myx.distro-deploy` — it belongs to `myx.distro-remote`, whose `RemoteContext.include` does declare an arm for it. The same false generalisation is restated in `keeper-myx.armed.md`, which is not this package's to correct.
- Only some tools in the family default `MDLT_ORIGIN` at file load. `DistroSourceTools.fn.sh` and `DistroDeployTools.fn.sh` do not, so their tail-guard test on `[ -z "$MDLT_ORIGIN" ]` is live and does real work. This tool does default it, which is what makes the same test dead here.
- It belongs in the tail guard's executed-only `case "$0"` arm, above the help branch so `--help` also resolves its own help file. A sourced caller must never trigger it, which is what the guard is for.
- An operation arm cannot do this work. The file-load bootstrap and the `MDAT_DATA_ROOT` preamble at the top of the function both run before the dispatcher `case`, so by the time any arm executes the environment is already established, right or wrong.
- `MDLT_ORIGIN` being set proves nothing, because the file-load default sets it unconditionally. `MDLT_OPTION` is the only witness that a resolution actually ran, and a guard written on `MDLT_ORIGIN` alone is dead code after the default.
- `AgentsContext.include`'s idempotence guard — the `MDLT_ORIGIN`/`MDLT_OPTION` test that makes re-init a no-op inside a console — sits on its `--init-variables|--run-from-detect` arm. `--distro-path-auto` matches neither pattern, so the tail guard's own call falls to the `*)` delegation and never enters that guard. This entry previously implied it did.
- A command executed through one of this tool's operations inherits the resolved environment. That is the reason to host an MCP execute operation here: `myx.common`'s MCP path performs no environment init, so anything it runs starts bare.

## Our own tooling reads our own descriptor, never a client's published file

- **A file we generate for another product is output we publish, not a source anything of ours consults.** `AgentsTools.Install.include` already states this for `mcp.servers.json`, which our own harness reads, against the client config files beside it. The rule is general and applies to every such pair.
- **`.claude/copilot-add-dir.fragment` is copilot's integration.** It stays, it keeps working, and copilot keeps using it. Nothing of ours treats it as the authority on anything.
- **`sh-lib/AgentsTools.ClientAccessRoots.include` is the one place the access-root set is defined.** That fragment is one of its consumers, so reading the fragment read a copy from downstream of the definition.
- **`AgentsUniversalHarness.sh` therefore sources that include and calls `AgentsToolsClientAccessRoots` whenever no `--access-root` flag was given.** One block, for every caller. It does not branch on which caller it is, because yielding the set is one job.
- **The legacy console path goes through that same block.** It no longer reads the fragment, and no code path in the harness does. The fragment is named in a comment there, saying why it is not read.
- **Where the mechanism is absent the run refuses, on both paths.** It never falls back to the fragment. Measured: the include removed while the fragment was present gives exit 1 on the tool path and on the console path alike.
- **The console path is reachable by probe, and was not before.** The harness exits at the provider-variable gate first. Exercising it needs the dummy `HARNESS_*` a stub sets, plus a stubbed `curl`, exactly as this package's own rigs do. The resolved roots travel in the system prompt, so the recorded request body is the observation. A root only the fragment names is the discriminator. It reached the wire before this change and does not after.
- **Cost is not the trade here.** The include resolves the whole set in under a second, so the clean shape is also the fast one.
- This is a boundary rule, not a preference. A team and a current workspace are first-class here. Needing a secondary product's artifact to learn our own grants is the defect, whatever that artifact holds.

## The workspace root is outside the access set, and `MAGIC.md` is why

- **What a session needs to read is `MAGIC.md`, at project, repository and workspace tier.** Those are all types of project, and they are all git-tracked.
- **The actual workspace root and repository root are not git-tracked.** So the root directory is not where the knowledge lives, and granting it would grant access to nothing worth reading.
- That makes the set's shape principled rather than incidental. `$MMDAPP/source` is granted and `$MMDAPP` is not, because the git-tracked project trees are what hold every `MAGIC.md`.
- **Measured against the set as it stands, with a control that refuses a file outside every root.** Every `MAGIC.md` in a git-tracked source tree is reachable. Neither workspace carries one at its own root, which is the reasoning above showing up on disk.
- **The only unreachable ones are the installed copies under `.local/myx/myx.distro-*/`, and that is correct.** A served tool reaches the source `MAGIC.md` in the devops source tree, through the cross-workspace union the permissions registry already gives it. It never reaches the installed copy. `.local` is build output and is never the authority.
- The team scratchpad `MAGIC.md` files under `.local/temp/` are reachable, which the include grants on purpose.
- **This is not a gap to close by widening the include.** The include serves three consumers, and the set already covers what needs reading.

## A root flag replaces the set, and the write flag narrows what may be written

- **Any root flag replaces the whole default set.** `sh-lib/AgentsTools.ClientAccessRoots.include` is consulted only where no root flag was given at all. A caller adding one root by flag has dropped every other root in the same call, and the run still starts.
- **`--access-write-root` narrows writes to the roots it names.** With no write flag, writes are exactly as wide as reads. The two flags do opposite things to the set they join, and neither name says so.
- **The generated console renders every root it holds as a read root, so a spawn's writes are as wide as its reads.** Adding one write root to grant a work directory revokes every other write, and the call reports success. That is the trap to read before treating either flag as additive.
- **The split exists upstream and is lost on the way down.** The include holds read and write apart. A client's published launch fragment is the flattened union and carries no verb, because `--add-dir` has none, so a console reading the fragment cannot recover the halves.
- **The include's write producer is not a spawn's write set.** It yields the work directories. What a spawn writes inside a source tree comes from the declared-grants producer, which the union folds in and neither half names. Composing the write side from the write producer alone takes source writes away from every spawned session.
- **Where the console falls to `--add-dir` the split is not representable.** One flag, no verb, so a root granted for reading is granted for writing. That is the native path's own property, not a fault in it.
- **The console passes no flag through to the CLI.** After `--non-interactive` the remaining argv is the prompt, so anything the CLI must be told crosses as an exported variable — the rule the spawn session-id and agent-name variables already follow.
- **Where the flag carries a verb the console renders the two sets separately, from the include.** Reads stay the full union and writes are the work directories plus the roots a declared `Edit` grant names, so a later caller adding one write root adds it instead of replacing everything else. Where the flag carries no verb the launch fragment still serves that client's own integration, unchanged.

## `.local/agents` is durable, and nothing in this package sweeps it

- It holds the main-loop state, the MCP server descriptor and the composite skillset root. A path placed there persists until something removes it by name.
- **No removal mechanism in this package reaches it.** The purge op empties one fixed cleanup directory and takes no argument. The team-data retention pass scans a team-data root's own processed and trash locations. A new location under `.local/agents` is reached by neither.
- So a per-run directory created there is permanent by default. Anything placed in one that must not outlive the run needs its own removal, named and owned, decided before the directory is first written.

## What a spawn is given, and what it is only pointed at

- **A document reaches a spawn by grant and pointer, never by copy.** The member skill directories and the workspace source tree are granted roots, and the brief names the paths. Nothing in the spawn path copies a document anywhere.
- A member's own skill files, a `MAGIC.md` at any tier, a tracking document and a routine's instructions are all read in place. A mechanism that copied them would be a second way to do what the grant already does.
- **A place to put documents is therefore needed only for what a grant does not already reach.** Ask that of any such proposal before asking how a caller would name the contents.
- **`held-context:` carries conversation context, not documents.** It is the messages and relays the calling routine is holding, written into the brief as prose. The name invites the opposite reading, and the spawn-prepare-brief block lists it among the parts the spawning agent judges rather than the parts the tooling emits.
- **A spawn takes its brief from one source.** The proxy refuses more than one, so no existing route hands over a set of documents.

## What `ListAgents` reads, and what it reports

- It reads the `dispatch-*` items in the board's running state, and prints each one's session id, owner, status, started time and outcome.
- **The state it reports comes from what the item carries, never from which folder holds it.** An item whose status records a finished dispatch is reported as finished. A listing is therefore not a running-or-not answer, and an item resting in a state is not by itself a stale entry.
- The board item is the session record. A per-run directory beside it is that session's working space, so removing one is a matter of the directory and not of the register.

## `MDAT_SKILLSET_ROOT`: where the member set is read from

- Resolved in the same preamble as `MDAT_DATA_ROOT` and exported alongside it: `$HOME/.claude/skills` where that directory holds at least one `<member>/SKILL.md`, `$MMDAPP/.claude/skills` otherwise. A consumer reads the variable; it never spells either path itself.
- A `SKILL.md` decides it, not the directory. `--owner-workspace-upsert` creates `$HOME/.claude/skills` with `mkdir -p` as storage for its own registry file, so an empty home skills directory exists on installations that have no home member set, and `[ -d ]` alone would let it shadow a populated workspace root.
- A workspace-scoped rig is not lost by home-first. Where the skillset was installed with `--install-skillset-symlinks --scope workspace` and `$HOME/.claude/skills` holds no `<member>/SKILL.md`, the gate fails there and the resolver falls through to `$MMDAPP/.claude/skills`. A `$HOME`-pinned reader would resolve nothing instead, and the failure would surface as a missing team member rather than as a path error.
- The workspace set is a publication list, not the authority on who is on the team — the members that workspace publishes and uses, normally a subset of the machine's. Team membership is the union of the workspaces present locally, linked into the rig user's own home, so a member absent from the calling workspace is not an error condition and a member-scoped operation never resolves against one session's workspace.
- Consequence worth knowing: `--install-claude-permissions` writes `$HOME/.claude/settings.json`, a machine-global file, from this same resolved root. On a rig that has a home member set the root is machine-global too, so the two scopes match. On a workspace-only rig the root is that workspace's, and it still writes that workspace's grants into the machine-global file.
- Every reader of the member set now reads the variable: the member-existence gates, the member-directory and skill-root locals, the `SEE …` pointers in `--*-input-scan` usage text, the `client-*` enumerations, and `--owner-setup-claude`'s link walk together with its installer registry `.linked.magic-team.members.txt`, which the installer writes into each target root and which therefore describes the root it sits in.
- Four sites stay `$HOME` on purpose and are not leftovers. The resolver's own gated candidate in `DistroAgentsTools.fn.sh`, which wins where it holds a member set. `--install-skillset-symlinks --scope user-home`'s fan target, whose sibling `workspace` arm already spells the workspace roots. `$HOME/.claude/settings.json` and `$HOME/.claude.json`, machine-global host files that are not the member set. And `--owner-workspace-*`'s `.human-owner.workspaces.md`, which records absolute paths belonging to the machine and is the one authoritative list of tracked workspaces: resolving it per workspace fragments it into a registry per workspace, and on a host whose workspaces each carry their own member set it reports nothing tracked while the real list sits in `$HOME`. Its own portability gap — `--owner-workspace-upsert` refusing where `$HOME/.claude/skills` does not exist — was never a reason to move the file, and is closed by `mkdir -p`: measured, an entirely empty `$HOME/.claude/skills` satisfied the old gate, so it enforced storage rather than a skillset, and a directory created empty still carries no `<member>/SKILL.md` and so cannot shadow a workspace-scoped member set.

## Choosing a scope when writing a `magic-team:permissions` declare

- `namespace:` carries no glob by construction — its line ends at the member — so it grants the whole namespace tree and there is nothing to narrow it with. It cannot be made modest, and it is the wrong reach for a small or trial grant however natural its name sounds.
- `project:` and `workspace:` both carry a glob, so either can express a narrow grant. Prefer them wherever the intent is anything short of a whole namespace.
- A grant's cost is two numbers, not one: what the glob matches on the claude side, and what it widens to on the copilot side, where `--add-dir <root>` cannot express a glob at all and the containing directory is granted instead. State both before a grant is approved — the second is routinely orders of magnitude larger than the first.

## `MDAT_SPAWN_SESSION_ID` and `MDAT_SPAWN_AGENT`: what the spawn proxy hands the console

- The spawn proxy does not run an agent CLI. It pipes its context into `DistroAgentsConsole.sh --cli-configured --non-interactive`, and the console is what execs the CLI, so anything the CLI must be told crosses that boundary as an exported variable rather than as a proxy-side flag. Both branches of the proxy — the waiting one and the background one — inherit the exports, which is why neither call site names them.
- `MDAT_SPAWN_SESSION_ID` is a uuid the proxy mints, and the same value is written to the dispatch item's `session-id` header. That shared value is the entire join: a hook reports the agent's own `session_id` and nothing else carries it back, so without it the dispatch record names an id no hook will ever report.
- `receiptId` is a different identifier and stays as it is. It names the audit output log and the `RECEIPT_ID=` line, is not a uuid, and no CLI accepts it — which is exactly why it could not serve as the session id.
- `uuidgen` emits upper case and `--session-id` requires a valid UUID, so the value is lowercased at the point it is minted. A run that produces no uuid refuses to spawn: recording a session nothing reports is worse than not starting.
- `MDAT_SPAWN_AGENT` carries the acting member's name. The console builds an inline `--agents` document from it and selects that agent with `--agent`, so a hook reports the member name as `agent_type` instead of the generic type.
- The definition is inline at spawn and never a standing file. Members ship as skills; a standing agent definition would make one member exist twice, under two mechanisms, with nothing keeping the two in step.
- The member name is tested against a bare-token set before it is placed inside the JSON, so no name can alter the document's structure.
- `MDAT_SPAWN_SESSION_ID` is honoured by `claude`, `copilot` and `scaleway` (each takes its own `--session-id` flag); `MDAT_SPAWN_AGENT` reaches all three too, though each resolves it a different way — claude's own is the inline `--agents`/`--agent` document described above, scaleway's is documented in the universal-harness sections below. On any other CLI (`grok`) each variable is reported and dropped rather than silently ignored — a variable that vanishes without a word is indistinguishable from one that was honoured.
- Status: the `--agents`/`--agent` path is not yet exercised against a live spawn, so `agent_type` carrying the member name is designed and not demonstrated. `--help` short-circuits before `--agents` is validated, so valid and malformed values both exit 0 and prove nothing. `ws-myx-devops` is otherwise ready: `SPAWN_CLI_SERVICE` is `claude` and its console is regenerated byte-identical to the template. Two things gate the observation. The spawn is an `--intern-op-*`/`--magic-*` operation, so it belongs to `magic-coordinator` rather than to any member. And reading the field back needs a recording `PreToolUse` hook wired into a workspace `.claude/settings.json`, which the harness gates; `capture-hook-input.sh` sits unwired in `ws-myx-devops/.claude/hooks/` for whoever wires it.

## Inherited precondition: a caller must not export both origin variables

- A caller exporting both `MDLT_ORIGIN` and `MDLT_OPTION` short-circuits `AgentsContext.include`'s idempotence guard. No resolution runs, the configured origin is never consulted, and the exported value is taken as given and never validated.
- This is why the `myx.distro` registration writes no `env` object. An `env` that pinned both would disable the resolution the front door exists to perform.
- Consequence depends on the arm. An arm that sources an include fails if the pinned tree lacks that include: exit 1, nothing on stdout, and a bare file-not-found naming a path — no protocol frames, which an MCP host cannot explain. The `--owner-*` arms source `AgentsTools.Owner.include`, so `--owner-cleanup-purge` and `--owner-credential-store-verify` fail this way under a wrong pinned origin and are witnesses for it. `--intern-validate-json` is inline, sources nothing, and is not.
- The worse case is quiet. Where the pinned tree does hold the include, the stale copy runs and returns a confident answer. Identical output today is a property of the two copies currently matching, not a guarantee.
- The exposure is reachable at the MCP front door, which is what makes it worth stating here.

## The `myx.distro` MCP server: wire and request handling

- stdout is the JSON-RPC wire and carries nothing else. Every diagnostic, the startup witness included, goes to stderr.
- Response bytes are written by the `printf` builtin only. stdout is fully buffered when it is a pipe, which is how an MCP host runs it, so the wire is never handed to a separate process whose flushing this server does not control. awk is forked for escaping, into a variable, before the lock is taken.
- The whole request handler forks — one background job per request, stdin from `/dev/null` — so no handler can eat the wire and a slow request delays only its own response.
- Per-request fields are read into variables before the fork. The next message wipes `req/`, and the fork carries whatever the variables already hold.
- **That covers every argument, not only the ones the first version of an arm happened to need.** A read moved inside the fork returns the *following* request's value, or nothing, and the handler then answers plausibly about the wrong request: measured, three back-to-back `job` calls all answered `requires a non-empty 'command' argument` because each read `req/arg_job` after the loop had already rewritten it, and the same three spaced a second apart answered correctly. Nothing about the wrong answer distinguishes it from a real one, and a client that pipelines meets it on every call.
- Responses are serialised by a `mkdir` test-and-set on `wire.lock`, held for the one `printf` and nothing else. `mkdir` is the atomic test-and-set every POSIX filesystem has; `flock` is not guaranteed on a bare FreeBSD or Darwin.
- A message with no id is a notification and is never answered: the `notifications/*` arm does nothing, and both send helpers return on an empty id.
- **The `workspace` parameter re-runs the call in a fresh process with `MMDAPP` moved to that workspace and `MDLT_ORIGIN` deliberately unchanged.** It is not the same as a standalone invocation there, which would resolve that workspace's own origin.
- **Per-request process isolation is a boundary, not a workaround.** A foreign workspace must resolve natively; done in-process it would poison the server's own `MMDAPP` for every later request. Do not collapse it in a cleanup.
- **The fork sits before the lock deliberately.** Moving it into the critical section lengthens every hold.
- **A lock bound defines its expiry behaviour**: write the response anyway, or drop that one response. Never exit the server — that turns a one-response fault into a total outage.
- **A spin loop whose counter resets after each sleep is a pacing counter, not a limit**, and is unbounded by construction. Read the reset, not the bound.
- **Any string emitted onto the wire stays one physical line.** A `printf '%s'` of a value holding a newline produces a corrupt frame.
- **A registration that freezes an absolute path plus an environment value validates the path by running, never the environment value.** That is where a stale registration surfaces later as an unrelated error.
- A bare `wait` after the read loop drains the in-flight handlers before the scratch root is removed. Without it, end of stdin deletes `out.<seq>` under a handler still writing its response, and that request is answered never. A child the executed script itself left running is a grandchild, not a job of this shell, so it is never waited on and cannot hold shutdown.

## A harness tool joins the served MCP floor by default

- **`sh-lib/AgentsTools.InternMcpServer.include` serves the harness tool floor derived from the wire
  declarations, so a tool added to that wire is offered over MCP without anyone deciding that it should
  be.** Nothing asks the question, and no instrument tests it: the self-check counts a tool's four
  structural sites, the tools-JSON check parses its declaration, and the mirror renders the whole floor
  by design. A tool can therefore reach a `*-native` client the same day it is written, through a route
  its author never looked at.
- **The served set is a subtraction, named in `mcpUnservedToolNames`, and it is the only place the
  question is asked.** THE TEST WHEN A NEW TOOL LANDS: a tool that takes a command, or that hands back a
  handle only its own process can resolve, belongs on that list.
- **`Bash` is unserved because arbitrary command execution is `myx.common`'s own MCP method**, and because
  the `*-native` leg denies `Bash` wholesale through `.claude/hooks/deny-bash-tool.sh` and reroutes the
  caller to this server's own `execute`. That hook denies whatever its matcher names. **A tool taking a
  `command` under a different name is therefore an unguarded second path around it**, which is what makes
  this a containment boundary rather than a tidiness rule.
- **`Monitor` is unserved for a second, independent reason: it cannot work over this wire at all.** A
  `tools/call` runs one tool in a FRESH `--intern-tool` process, so the scratch directory holding a job's
  log and handle is created and removed inside the one call. Measured: a start returned `job-1`, no
  scratch directory survived the call, a second call answered `no background job named job-1 was started
  in this run`, and the job itself was left running with its log already gone. The between-rounds spool
  never runs either, because there is no round loop. A read-only served form is not a lesser option but
  an impossible one, since the only thing that mints a handle is a start in the same process.
- **What the exclusion gives up: nothing that ever worked over MCP.** A caller wanting a watched
  background job uses `execute` with `background` set, which this server holds across calls and can poll
  by job id and kill. `Monitor` remains a harness tool, where the spool it exists for actually runs.
- **Unserved is ABSENT from `tools/list`, not present-and-refusing**: a tool that exists and refuses reads
  as a broken server. `tools/call` still names what to use instead for each unserved tool, because a
  caller who names one anyway needs somewhere to go.
- **`sh-lib/AgentsHarnessServedFloorCheck.sh` now holds this, so the subtraction is no longer a list
  somebody has to remember.** It reads the served set off the real server's own `tools/list` answer rather
  than re-applying the subtraction, and holds it in both forms below.
- **The rule's scope is the harness tool floor, not everything served, and writing it the wider way makes
  it false against a correct design.** Measured: `execute` is served and declares a `command` of its own,
  deliberately — it is the sanctioned execution method here, which is the whole reason `Bash` is
  subtracted and its caller sent there instead. The candidate population is therefore what
  `AgentsHarnessMcpMirror.sh` renders, and `execute` falls outside it by construction rather than by being
  carried as a remembered exception.
- **`command` is NOT the whole predicate, and this was measured rather than argued.** The name-based rule
  is evadable: with `Monitor` removed from the subtraction *and* its `command` parameter renamed to
  `script` in its declaration alone, the check's `command` assertion PASSES while the behavioural one
  FAILS. So the instrument also derives, from the core itself, which tools execute a caller-supplied
  string as a shell command — `eval` or `bash -c` inside that tool's own `AgentsHarnessTool<Name>`
  function — and requires every tool it finds to be absent from the served set. A renamed argument does not
  evade that, and the check's own output names whichever tools it found.
- **The other half of the documented test is not instrumented, and that is a limit rather than an
  omission**: a tool handing back a handle only its own process can resolve is a fact about process
  lifetime, visible in neither a declaration nor a source scan. `Monitor` is caught only because it also
  takes a command. A future tool minting a process-local handle and taking none would pass every
  assertion and still be unservable.

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

## Stub routes: one first-level arm and one include per family

- Every `--magic-comms-*` operation is routed by one first-level `--magic-comms-*)` arm, which sources `sh-lib/AgentsTools.MagicComms.include`, and every stub of that family lives there. Every `--client-comms-*` operation is routed the same way, by one `--client-comms-*)` arm and `sh-lib/AgentsTools.ClientComms.include`. A new stub in either family is an arm inside its include and costs no dispatcher line.
- `--member-comms-<service>-*` keeps one arm per platform, as committed, each sourcing that platform's own include, so a new operation on an existing platform costs no dispatcher line. `comms` is a namespace under the member prefix rather than a prefix of its own, because every such operation takes `<team-member>` first and that member is the acting identity.
- A family arm is safe only because every stub of that family lives in the include it sources. A stub placed in any other file is not routed, and nothing reports it.
- The comms routes precede the `--member-*` route. Without that position the broader glob takes every operation they match.
- `--intern-op-slack-check` is deliberately not routed through a comms arm: it carries an internal prefix and sits with its internal siblings. Pinning one exact name onto a comms arm is the by-name coupling these routes exist to retire.
- **One arm per group, and the include split is a size question.** The dispatcher carries one arm for a group of operations, never one per operation. Whether that arm sources a single include or several is decided by size alone: one include while the group stays small enough to read, split into more when it does not. Nothing else about the group changes when it splits, since the arm is what routes.
- **A process holding a dispatcher loaded before this restructure keeps its old arm table**, so a bare-name call there routes to a per-product include that no longer exists and fails. A call by the full `sh-scripts/DistroAgentsTools.fn.sh` path is unaffected, and the old table goes when that process restarts. Measured in the execute environment.

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

- `--owner-credential-store-verify` walks `.local/.agents/*.agent.env` and flags anything not 770 for the directory, 660 for a scope file — owner and group. The glob is the tool's subject: a config scope is exactly an `*.agent.env` file, and a cache or any other non-scope file sharing that directory is not this tool's to judge. It is the standing guard against one bug class: an upsert chmod-ing the touched file instead of the temp that `mv` replaces it with, which lands the result at 644.
- `--owner-credential-store-self-test` exercises that chain under a deliberately permissive `umask 022` rather than the caller's ambient umask, because a coincidentally restrictive ambient umask hides a chmod regression. It uses a disposable probe key, never a real credential, and cleans the probe up pass or fail.
- `--owner-credential-store-harden` exists for the two cases that never heal on their own. `LocalTools.Config.include` chmods the store directory to 770 only when it creates a scope file, and chmods a scope file's temp to 660 on every write, which `mv` then carries onto the target. So a scope file that is never written again, and the directory in a store where no new scope is ever added, keep whatever modes they have.

## Board-item list-shaped header fields are comma-separated, no brackets

- `blocks`/`blocked-by`/`supersedes`/`superseded-by`/`spawns`/`spawned-by` (and any other list-shaped board-item header) serialise as `a, b, c` — a single value is the bare value, never `[a, b, c]`. The writer is `sh-lib/AgentsBoardItemHeaderOpsApply.awk`'s `--header:append` accumulation; it joins with `, ` and does not wrap the result.
- `references` is not a field. Every relationship a board-item carries uses one of the six typed fields above, chosen for what the relationship actually is, not left generic.
- `participants`/`restart-session` are a separate, pre-existing space-separated convention, unrelated to this one — already bracket-free, untouched.

## `--magic-board-to-blocked`/`--magic-grooming-to-blocked` auto-stamp `execution-receipt`

- Both ops append `--header:upsert:execution-receipt:blocked:<timestamp>` to the caller's own header set unless the caller already supplied an `execution-receipt` upsert or append, in which case the caller's value stands untouched. Every sibling `-to-*` op in both files (`-to-pending`/`-to-backlog`/`-to-parked`/`-to-running`) stamps nothing; `--magic-board-to-processed` stamps a `processed:<timestamp>` receipt of the same shape, plus its own `processed-at`.
- The check is a plain scan of the collected `passthrough[]` array for an existing `--header:upsert:execution-receipt:*`/`--header:append:execution-receipt:*` entry before appending the default — duplicated independently in both files' own case arms, matching this package's own per-call-site validation convention. That per-call-site placement is `execution-receipt`'s alone; the move date stamps below are centralised in `--intern-op-board-upsert-move-edit` deliberately, for the reason stated there.
- `execution-receipt` is not in `magic-team.armed.md`'s frontmatter-header list, though four code paths write it. Documenting it is open work, not a licence to stop writing it.

## Every logical move stamps the date field its target state owns

The human-owner's requirement: all logical moving operations stamp their operation's field, overridable by an explicit argument. Two facts make it enforceable at one site — `--intern-op-board-upsert-move-edit` takes `<to-state>` as an argument, so it always knows the target state, and every board move in the package goes through it. Stamping in the wrappers instead would leave a direct dispatcher call able to file an unstamped item, which is exactly the defect `--intern-team-data-final-gc-deletion` measured.

- The map is the vocabulary's, not an invention: `processed` → `processed-at`, `running` → `started-at`. No other board state owns a date field today, so no other state is stamped. Proposals for the missing ones (`backlog`/`pending`/`parked`/`blocked`/`archived`/`retained`, and `trashed-at`/`renamed-at`) are the human-owner's call, not this package's.
- Four suppressions, in order: the caller named the field in any `--header:` op (the override — `--header:remove:` included, so "no stamp" stays expressible); `<from-state>` equals `<to-state>`, an edit rather than a move; the resolved body carries no complete `---` frontmatter block, which `AgentsBoardItemHeaderOpsApply.awk` hard-fails on; and, for `processed-at` only, the body already carries it — `processed-at` records a conclusion once and is never re-stamped, while `started-at` is per-run and a real move into `running` restarts it.
- `--create` and `--from-inbox:` both stamp: neither has a from-state, so neither is a same-state edit, and both land a document in the target state.
- Every wrapper that already stamped keeps its own stamp and is unaffected — it names the field, so the first suppression fires. The centralised stamp only fires where nothing stamped before.
- `--intern-op-inbox-to-processed` carries the same stamp in its own file rather than through the primitive: it never calls the primitive, and its target state is fixed in its own name. `--intern-op-board-rename`'s husk takes `--processed-at:<date-time>` as its override, since that op has no `--header:` surface of its own and the husk is the one document it files into `processed/`.
- Both sites share `sh-lib/AgentsBoardItemFrontmatterFieldProbe.awk` for the frontmatter-bounded presence check — never a `/^field: /`-anywhere match, which a body line would spoof.

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

## Heartbeat's `state-and-lock` merge (2026-09-09), and what its own splice still owes

Heartbeat used to be the one routine group of the five (`advance`/`grooming`/`daily`/`retro`/`heartbeat`) carrying its lock and its state in two separate documents — `note-*-heartbeat-state-and-lock.md` (lock only) and a second `note-*-heartbeat-state.md` (day-rhythm state), the latter written by a bare `printf > file` with no git add/commit/push at all, ever. Merged into the one document the other four already use, matching the section above. Unlike those four, `--magic-heartbeat-state-upsert` never used `--header:*` patches for its own many state fields — it takes a caller-authored whole-record body (frontmatter + body, `--from-file`/stdin/`--edit-patch-from-stdin`) and must still not let that body clobber the document's own lock-owned fields (`type`/`from`/`date`/`owner`/`state`/`recheck-date`/`session-id`). It does this by reading `$target` itself for an explicit allowlist of those seven fields, then splicing them ahead of the caller's own frontmatter and body before handing the whole thing to `--intern-op-item-upsert ... --upsert-from-stdin`.

Three bugs found and fixed in that splice, by real execution against the live team-data store, not by inspection alone:

- **CRLF or no leading frontmatter fence in the caller's body silently produced an empty write.** Both extraction passes matched `$0=="---"` literally; a Windows line ending (`"---\r"`) or an absent fence at all made every check fail, so `callerFields`/`callerBody` came back empty while `$content` itself was non-empty (passing the empty-content guard) — the write went ahead and landed a document carrying only the seven lock fields, silently discarding every state field and the whole body, no error at all. Fixed by normalising `\r` off every line before splitting, and by rewriting the body extraction so "no fence at all" means "the whole thing is body" rather than "wait for two fences that never come." A same-shape defense-in-depth guard was added alongside: `callerFields` and `callerBody` both empty from a non-empty `$content`, whatever the cause, now refuses the write instead of landing a lock-only document.
- **`--edit-patch-from-stdin` reconstructs `$content` from `$target`'s own existing full content** (`AgentsBoardItemPatchApply.py` patches and returns the whole document, frontmatter included) — so `$content`'s own frontmatter still carried the seven lock fields verbatim, and the (then-unfiltered) `callerFields` extraction would duplicate every one of them alongside the separately-read `$lockFields`. No routine calls this op with `--edit-patch-from-stdin` today, but the op accepts it without rejecting it. `callerFields` now excludes the same allowlist `$lockFields` reads, rather than trusting the caller's body never to carry them.
- **The frontmatter/body separator grew by one blank line on every read-modify-write round trip** — exactly the shape this op's own contract documents as normal use (`--magic-heartbeat-state-read` piped into `--magic-heartbeat-state-upsert --from-file`, or an equivalent read-then-write-back for one field). The merge template always adds its own one blank line ahead of `callerBody`; a caller supplying back a previously-read full record carries that record's own already-separated body, whose leading blank line(s) then stacked with the template's own. Measured live: 2 blank lines after one such cycle, 3 after two. Fixed by stripping `callerBody`'s own leading blank lines before splicing, so the separator is always exactly one line regardless of how many the input carried — idempotent under repeated round trips, confirmed live (two consecutive write-backs of the same record now produce byte-identical documents).

**Known, not fixed here**: `--magic-heartbeat-lock-acquire`/`-refresh`/`-close-unlock` all read `$target` fresh at write time (no body-mode flag, so `--intern-op-item-upsert` itself reads the current on-disk content and applies their `--header:*` patch on top of it) — safe from a stale-read/write race by construction. `--magic-heartbeat-state-upsert` cannot use that shape (a header-op patches named fields, it cannot wholesale-replace "everything except the lock fields") and instead reads `$target` for `$lockFields` externally, before its own write. A `--magic-heartbeat-lock-refresh` (or `-acquire`/`-close-unlock`) commit landing in the gap between that read and this op's own write would have its `recheck-date`/`state` update silently reverted by this op's own stale snapshot — a real exposure now that state and lock share one document, most plausibly against `magic-coordinator.advance.routine`'s own concurrent `--magic-heartbeat-state-upsert` call (its Thread-continuity write-back), which runs as a separate spawned session and does not hold heartbeat's own lock. This sits alongside the already-documented lost-update race on the state fields themselves between heartbeat and a concurrent advance pass (`magic-team/ROUTINE-CONVENTIONS-FINDINGS.md` Part 3/Part 4 item 6) — the merge does not introduce that race, but does extend its surface to the lock's own liveness fields. A proper fix is field-level header-ops for `--magic-heartbeat-state-upsert`, matching how the lock ops already avoid this; flagged for the team rather than patched under this review.

## The advance lock paths: resync, conflict check, and the unlock order

- `--magic-advance-lock-acquire` and `--magic-advance-close-state-and-unlock` both run `myx.common git/cloneSync --no-push` against the team-data checkout whenever `TEAM_DATA_GIT_REMOTE` is set. Advance-only: the grooming, daily and retro groups still carry the plain stubs, so the help entry shared by all four describes advance only in part.
- The acquire path refuses before it writes anything: state check, resync, state check again, head comparison, and only then the lock write. Refusing after the write is what the shared primitive's own post-push read-back already does; the pre-write half exists so a stale local copy never reaches a push at all.
- `LOCK_CONFLICT` names an unresolved merge, a committed conflict marker, or an uncommitted local edit on the lock note. `LOCK_STALE` names a lock note whose local commit is not the one on the branch head. `LOCK_UNCHECKABLE` names a resync or fetch that could not answer, and refuses too — ownership unknown is not ownership free.
- The state check runs on both sides of the resync, because the resync can leave either state and a check placed only after it never fires for a checkout that arrived already conflicted.
- The head comparison reads `FETCH_HEAD:<lock path>`, never `origin/<branch>:<lock path>`: the remote-tracking ref depends on the fetch refspec configured in that checkout, while `FETCH_HEAD` is written by the fetch the check itself just ran.
- The lock note's path is resolved against the checkout root under a guard: a path that does not strip to a relative one, and a checkout not on a named branch, are both `LOCK_UNCHECKABLE` rather than a comparison that silently matches nothing.
- Unlock order is GC, lock-state write, push, resync. The GC commits under the still-held lock, and the push carries every commit made under it rather than the lock note alone. A push or resync failure there warns and still closes: the lock is already released locally, and a pass that cannot close is worse than an unreconciled checkout.
- The commit does not depend on a remote: on a `.git`-present root both advance commit messages land whether or not `TEAM_DATA_GIT_REMOTE` is set, and the remote decides only whether that commit is then pushed and read back. The gate is `--intern-op-item-upsert`'s own and is shared by all four routine groups; its own section below states the three configurations.

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
- Its local-commit gate is `.git` presence alone, independent of `TEAM_DATA_GIT_REMOTE`, because this op never pushes or syncs — that is always the caller's own job. `TEAM_DATA_GIT_REMOTE` does decide exactly one thing in the GC, and it is not the commit: see `trash/`'s own gate below.

## `--intern-team-data-final-gc-deletion`: three locations, one table, one clock

- **The retention table is keyed on the item's own document type, never on the folder it was found in.** `warning-*` and `reflection-*` at one day, everything else at seven, applied identically in `inboxes/*/processed/`, `board/processed/` and `trash/`. The three folders are locations to scan; a per-folder threshold is a different rule and not this one.
- **`trash/` is the one location with a gate of its own, and that gate is `TEAM_DATA_GIT_REMOTE`, not the `.git` test the commit uses.** The two ask different questions. The commit gate asks whether there is a local repository to record a removal in; the trash gate asks whether the trashed copy's bytes are already reachable somewhere other than this working tree, which only a configured remote answers. With a remote, trash goes on the pass it is found on; with none, that copy is the last copy and takes the ordinary table.
- **`trash/` absent is not a condition to report.** A root that has never trashed anything has no such directory, so the scan skips it silently — the same posture as an inbox member with no `processed/`.
- **The clock is mtime, except where git already holds a commit for the path, and then it is that commit's date.** A checkout does not preserve mtime and this root is resynced by routine lock traffic, so an mtime-only clock restarts an old item's retention on every resync and the item never ages out. A stamped frontmatter field is not the clock: it dates only what a producer chose to record, leaves every unstamped item immortal, and puts a second clock in the tree that can disagree with the first.
- **The git clock, the git-name probes and the mtime read are batched one call per directory, never one per item.** `git log -1 -- <path>` walks history from HEAD again for every path it is asked about, so a per-item lookup degrades as a folder grows; one `git log --name-only` walk answers the whole directory, newest-first, and a path's first appearance there is its latest commit. `git ls-files`/`git ls-tree` replace a `git ls-files --error-unmatch` per candidate for the same reason — same question, same command family, one fork. All the maps are read back through `case` patterns over a newline/tab-delimited string, so a lookup costs no fork at all.
- **`stat(1)`'s flavour is probed once against `/`, never tried in sequence per directory.** GNU `stat` fed the BSD form still prints a line for every readable operand before failing, so a `bsd || gnu` capture concatenates the failed attempt's output with the retry's — harmless for one file, wrong for a whole directory. Probing against `/` rather than the data root keeps a missing root reporting as an empty scan instead of a broken `stat(1)`.
- **What git may be told about is asked before the `rm`, and it is two questions rather than one.** `git add` may be given what the index holds; a commit's own pathspec may be given only what HEAD holds. An item staged and never committed is in the first set and not the second — `git add` clears its index entry, and passing it to the commit as well fails on a pathspec matching nothing. Asking after the deletion, or asking once, is what destroyed an item on a path that then reported failure: the file was already gone, the pathspec matched nothing, nothing was committed, and the caller was told the operation failed. An untracked item is deleted and counted like any other; a GC whose whole job is removal has nothing to commit for it, and that is not a failure.
- **Two diversions, checked in a fixed order, only one ever applying.** `archive: true` goes first and always wins, to `board/archived/`. Failing that, an item still named by a live board-item's `blocked-by`/`spawned-by` goes to `board/retained/`. An item that is both is archived, not retained — the value judgment outranks the structural one, so `retained/` only ever catches what `archive: true` does not.
- **Live, for the dependency question, is `board/{backlog,pending,running,blocked,parked,archived}`.** `processed/` and `retained/` are excluded by specification, not by omission: a pointer from a concluded or already-diverted item never qualifies, which is exactly what stops two concluded items retaining each other forever. The name set is one awk pass over all live states at once, `.md`-normalised and `sort -u`'d, read back through a `case` pattern so a candidate costs no fork. It is built once per run, before the board scan — an item still sitting in `processed/` is not live, so its own pointers do not count until a later pass finds it somewhere live.
- **A diversion substitutes for the deletion; neither marker is a second clock.** Both are read at the moment an item is found due, not per candidate, so a marked or depended-on item sits in `processed/` for its full retention like any other and is diverted only where it would otherwise have been destroyed. Diverting on sight would instead pull the move forward the instant someone marked the item — a different rule, and not the one asked for. Asking only for due items also confines the frontmatter read to the few items a pass acts on.
- **Both markers are read bounded to the frontmatter block, in pure shell.** A body line reading `archive: true` must not archive an item and a body line reading `blocked-by: …` must not retain one, so the `/^field: /`-anywhere one-liners used elsewhere in this package are wrong here; and `AgentsBoardItemFrontmatterFieldProbe.awk` would be a fork per item across every `processed/` folder, so the archive read is hand-rolled without one. `archive: true` is matched on presence, the form `magic-team.board.md` records and the only form the tree writes — for an operation whose default outcome is deletion, a marked item erring toward retention is the safe direction.
- **Both diversions are board population only.** The move goes through `--intern-op-board-upsert-move-edit`, whose destination is a board state. A per-member inbox log entry ages out on the ordinary table whatever its frontmatter says: `archive: true` means something on a board-item and nothing there, and the entry carries no typed relation field for anything to point at. `trash/` is not processed cleanup and reads neither marker — an item reaches it only by having been deliberately trashed, so honouring a retention marker off something already discarded would make it immortal.
- **Landing in `trash/` is meant to start that copy's own retention clock, and `mv` does not.** `mv` preserves mtime, so anything moved there arrives carrying the age it already had. The fresh stamp belongs in **one** place, the trash op (`--intern-op-board-trash`), because that is where something is *trashed*; the GC is a consumer of that clock, never its producer, and must not stamp on its own. Only the trash op writes to `trash/` now — a board move does not — so that one stamp covers the whole population.
- **The stamp and the git clock do not compete in `trash/`.** An untracked item there is dated by mtime, which is what the stamp fixes. One git *does* hold at its trash path is dated by its latest commit for that path — and the only commit a trash path can have is the one recording its arrival there. Both roads answer "when did this land in `trash/`", so the git clock cannot defeat the stamp; this is not a second clock.
- **A diversion records nothing for this op's own commit, because the move primitive commits both ends itself.** By the time the move returns, the source is gone from the index and the destination is already in HEAD; handing either to this op's `git add` would be a pathspec matching nothing — the same failure class as passing it an untracked item. A diversion also leaves no `trash/` copy, since `trash/` is not a board state and a board move no longer goes near it.
- **A diversion creates its destination state directory if missing** — the move primitive errors out on it, and a diversion the human-owner made automatic cannot fail because a directory it needs itself was never created. It does **not** create `trash/`.
- **The summary's trash segment is carried only when `trash/` held something at scan time.** Absent or empty, and the line is the spec's two-segment form; non-empty, and it carries the trash count even when that count is 0 because nothing there was due. The test is what the scan *found*, never how much of it was deleted — a population that was reported on gets a number, and a population that did not exist gets no column. Emptiness is measured in `*.md`, the only thing this op scans or can report; a `trash/` holding nothing else reads as empty, and on real data the two readings coincide because everything the trash op puts there is a `.md` item.
- **The `.git`-gated commit is a requirement of the specification, and the message `- team-data-final-gc-deletion` is byte-exact.** It was briefly removed on 2026-09-04 by an agent misreading a human-owner instruction about *its own* committing as an instruction about the tooling's; that was wrong, and the commit was restored the same day. `AGENT AI DO NOT COMMIT` binds the agent, never this operation. Do not remove it again.
- **A diversion is not a deletion, in the counts or in the `rc`.** `rc` is 2 when the pass deleted nothing and 0 when it deleted something, so a run that only diverted answers 2 — the `rc` asks what was deleted, and a divert-only pass deleted nothing. Folding the diversion into `rc 0` is exactly the silent conflation of two different outcomes. It is not hidden either: the deletion sentence never counts a diversion, and a second sentence is appended whenever one happened, so `rc 2` is never the only thing the caller is told. `--magic-advance-close-state-and-unlock` treats 0 and 2 alike and only anything else as a failure.

## `--intern-op-item-upsert`: the commit gate and the push gate are separate

- A repository in the team-data root is what makes a commit possible; `TEAM_DATA_GIT_REMOTE` is what makes a push possible. Held as one condition, a `.git`-present, remote-absent root wrote every item and committed nothing — the configuration in which both advance lock messages, and every other routine group's lock write, vanished with a clean exit.
- Three configurations, and each is a different amount of the same path: no repository — write only; repository, no remote — write and commit, ending there, since there is nothing to push to and no remote copy to read the lock back from; repository and remote — write, commit, push, resync and read back.
- `--no-push` is a caller's request, not a configuration, and its message stays distinct from the no-remote one: an unpushed commit has two possible reasons and a log that cannot tell them apart answers neither.
- The lock read-back is a property of the remote configuration alone. Without a remote the lock is local and unverified, exactly as it was before the commit existed — committing does not make a single-checkout lock any more authoritative, and nothing here should be read as claiming it does.

## `--intern-op-board-upsert-move-edit` commits the move it makes

- **Every board move commits when the team-data root is a repository**, gated on `.git` presence alone and never pushing — the primitive is the one place it lives, so every `--magic-board-to-*`, `--magic-grooming-to-*` and `--magic-advance-*` wrapper is covered without one of them carrying its own. Both ends go into the one commit, destination and removed source, and the source's trackedness is read before it is removed: an untracked source is left out of the pathspec rather than failing `git add` after the move already happened. Subject: `* board-upsert-move-edit: <item> <from> -> <to>, <--context op>`, with `<from>` rendering `inbox:<member>` for a promotion and `create` for a creation.
- **A move deletes the previous copy; it does not spool it to `trash/`.** `trash/` belongs to the trash op and is not a board state, so a move never writes there — which also removed this op's own missing `mkdir -p` and missing collision guard, the pair that left an item in two board states at once when `trash/` did not exist. The inbox-sourced branch always deleted; the two branches were identical apart from the spool and are now one.

## `--intern-op-board-trash`: one implementation behind four operations

- `--magic-heartbeat-board-item-trash`, `--librarian-inbox-item-trash` and `--member-inbox-item-trash` are argument-shaping wrappers that forward here with `--context <their own name>`; the two branches of the `.git` gate exist once, on the board-sourced and the inbox-sourced path each. A change to either branch reaches all four operations, and a fix applied to one wrapper reaches none of them.
- **The commit subject is `- <op name>, <team-member>`, and the op name is whichever operation the caller actually invoked.** With no `--context` the caller invoked this one, so the default is `--intern-op-board-trash` rather than a placeholder — a subject naming no operation is unusable in the log the deletion is recovered from.
- **The non-`.git` branch creates `trash/` itself.** Nothing else in the package ever creates it, so on a client whose team-data root is not a repository the first call had no target directory: `mv` failed, and the operation aborted under `set -e` leaving the item where it was.
- **`mv -n` is not a collision guard and is not used.** Measured on Darwin 25.5.0, it refuses to overwrite and then returns 0 having done nothing, so a half-completed move reads as success. `trash/` is flat and has several writers, so an explicit `[ -e ]` test before the move is the only thing that makes a collision reportable: the op refuses, and both files stay where they are.
- **An item arriving in `trash/` is stamped with the current time, by `touch`, at the moment of trashing.** `mv` preserves mtime, so the copy would otherwise arrive carrying the age that made the item due and be collected by the next GC pass: measured on a seeded fixture, all four operations landed a 2000-01-01 item in `trash/` still dated 2000-01-01. The stamp sits on the non-`.git` branch only, because the `.git` branch deletes and commits rather than moving and puts nothing in `trash/` to stamp.
- **For anything this op trashes the stamp is the entire clock, not one of two agreeing sources.** The GC dates a path by its latest commit where the root is a repository and by mtime otherwise, deciding that with the same `git rev-parse --show-toplevel` test this op uses — so the branch that writes into `trash/` runs only in the configuration where the GC's git road does not exist. A `trash/` path in a git-rooted root got there through a different writer, and even there it is dated by mtime until some pass commits it.

## A member name renders as a real Slack mention

- **`--address-to <member-name>` used to emit roster text, not a mention.** The `U…` addressee arm already emitted `{"type":"user","user_id":…}`; the member-name arm emitted `*_<member>_* @<alias>` as plain `text`, and the alias comes from the member's own `.basic.md`, never from Slack. So the human-owner's own line read `→ :myx: human-owner @human-owner.` — literal characters Slack notifies nobody on. `AgentsToolsCommsSlackMentionUserId` (`sh-lib/AgentsTools.MemberCommsSlack.include`) resolves the name to a user id, and the field then carries `<@U…>` in `text` and a `user` element in `blocks`; Slack renders both as that account's real handle. The header's shape is unchanged — only what `@<handle>` resolves to.
- **Two sources, because a member and the human-owner are identified by different things.** A member is identified by the token it posts under, so `auth.test` on its own `SLACK_USER_TOKEN` names its account. The human-owner holds no token and is not a member; his account is the one `SLACK_CHANNEL_HUMAN_OWNER` already holds — a **user** id, as the upload contract below also records. Anything else resolves to nothing, and the field degrades to today's `@<alias>` text rather than failing the send: `magic-developer`, which has no Slack account, sends exactly as before.
- **`users.list` is not one of the sources, and adding it would resolve nobody.** Measured against this workspace's 13 accounts: none carries any member's name or alias — the one shared user account is `magic.vane`/"Magic Vane", the app bot is `magicteam`, and the human-owner is `myx`. Name-matching a member against that list matches the app bot or nothing, so the one-request-for-the-whole-workspace shape buys no resolution here.
- **The cache is keyed on the two lock notes' own content**, `cksum` of the advance and heartbeat state-and-lock notes concatenated, stored as the first line of `.local/.agents/slack-mention-ids.cache` with one `<member>=<id-or-dash>` line per resolved name after it. Every lock acquire, refresh and unlock rewrites one of those notes, so the key changes with the lock cycle and a member costs one lookup per cycle rather than one per message — which is what the human-owner asked for, and it needs no hook inside `AgentsTools.MagicAdvance.include` or `AgentsTools.MagicHeartbeat.include`. A `-` records "no account" so an unresolvable member is not re-probed within the cycle, and every cache write is `|| true`: a cache that cannot be written slows the send down, it never fails it.

## `--member-comms-slack-send-message` — a bare apostrophe in trailing argv breaks the send, and there is no fix at that layer

- **Not a bug in the send-path code — the failure happens one layer up, before this operation's own argument parsing ever runs.** `--mcp-execute`'s `eval "$( cat )"` (`sh-scripts/DistroAgentsTools.fn.sh:363`) parses the WHOLE calling script first; an unbalanced quote from a bare apostrophe (or any other shell-meaningful character: `"`, `` ` ``, `$`, `;`) in a trailing-argv message body breaks that outer parse with a shell syntax error. Live-confirmed: `... --member-comms-slack-send-message magic-coordinator magic-team It's a live apostrophe test` failed with `eval: line 363: unexpected EOF while looking for matching \`''`, then the identical message body sent cleanly via `--from-stdin` (a heredoc) to the real channel.
- **There is nothing to quote/escape inside `AgentsTools.MemberCommsSlack.include`/`AgentsTools.CommsSlack.include` to fix this**, because by the time a syntactically well-formed calling script reaches those files' own dispatch, the shell has already tokenized argv successfully — a malformed script never gets that far at all. The actionable fix is call-site discipline, not a code change: prefer `--from-stdin` with a heredoc for any message body that is not a hardcoded literal with no punctuation risk. See `sh-lib/help/Help.DistroAgentsTools.help.md`'s `--member-comms-slack-send-message` entry for the same note at the call-site.

## `sh-lib/AgentsSlackBlocksBuild.awk` — a backslash escapes the character after it

- **`client-\* sweep` rendered as `client-\ sweep` in italics with a stray `*`.** The inline parser had no backslash branch at all, so `\` stayed literal text and the `*` behind it became a delimiter run that closed an emphasis opened earlier in the line. CommonMark backslash escapes now run ahead of every other branch in `parseInlineStyles`: a backslash before ASCII punctuation emits that character as ordinary text. Ahead of the code-span branch specifically, because `` \` `` must not open a code span — which is the spec's own ordering, not a local preference.
- **The punctuation set is spelled out at that branch rather than taken from `isPunctCh()`.** That predicate deliberately drops backtick, apostrophe and double quote for the flanking rules (see its own header), and reusing it would leave `` \` `` unescaped. The two sets differ on purpose; do not unify them.

## `sh-lib/AgentsSlackBlocksBuild.awk` — `##`/`###` render bold, not header

- Only a line starting with exactly `"# "` becomes a Slack `header` block; the check is `substr(line, 1, 2) == "# "`, so `"## text"` never matches it. Slack's Block Kit `header` block has one flat style with no H2/H3 distinction to map to, so a deeper heading (`##`, `###`, any count of `#`) instead becomes a bold paragraph line, reusing the same `**text**` bold path the script already has for inline styles — not left as unconverted raw markdown.

## `sh-lib/AgentsSlackBlocksBuild.awk` — a link's label and url are consumed in one step

- **Slack's clickable bare email was never ours to begin with.** `myx@meloscope.com` was stored as plain text and still rendered as a `mailto:` — that is Slack's own display-time auto-linkification of bare urls and emails, applied to a `text` element's content whatever we put there. What it cannot do is label a link with anything but the url itself, and the converter emitted no `link` element at all, so a labelled link had no way to be written. Suppressing the inference was never attempted and is not a goal: a bare url beside an explicit link still auto-links exactly as before.
- **Consuming the whole construct in ONE step is what settles the precedence question.** The url never reaches the emphasis branch, so `http://x/a_b_c` and `.../*d*/` cannot italicise or bolden — by construction, not by a guard beside it. The branch sits behind the code-span branch and inherits its exclusion by ordering exactly as the mention branch does: `` `[a](b)` `` is taken verbatim because the backtick arrives first. The label is verbatim for a reason that is Block Kit's rather than ours — a `link` element carries one flat `text` field and one style set, so a label of mixed styles has nothing to become. A structured element inside `**` is emitted unstyled, which is what a code span already did there.
- **`(` nests inside the url and `]` does not nest inside the label.** A depth counter closes `https://en.wikipedia.org/wiki/Foo_(bar)` correctly, which is a shape real links take; a `]` inside a label is not, so the label ends at the first one and anything else falls to the literal path.
- **Whitespace in the url is the false-positive guard, and it is CommonMark's own rule.** A bare link destination cannot contain a space, so `the array [1](see below)` stays prose instead of becoming a link to `see below`. The other literal-fallback cases — no `]`, no `(` behind it, no `)`, an empty label, an empty url — take the same posture as an unresolvable mention: literal text, never a failed send.
- **Neither python helper needed a change, unlike `table`.** `AgentsBlockKitValidate.py`'s `TOPLEVELTYPES` is a top-level block set and `link` is a rich_text element, so nothing was closed against it; `walkNode` sees a node carrying `text` and `url` and no `elements`, and passes it — measured rc=0 on a link payload and on a table-of-links payload. `AgentsSlackBlocksTextVersion.py` already rendered `link` as `el.get("text") or el.get("url","")`. One consequence worth knowing: that walk's empty-`text` rule would reject a caller-supplied `link` carrying `"text":""`, which Slack itself allows — the converter never emits one, so it was left alone rather than fixed speculatively. Confirmed by a before/after diff over the whole existing grammar — headers, bullets, fences, bold, italic, code, escapes, mentions, tables, bracket-shaped prose: byte-identical.

## `sh-lib/AgentsSlackBlocksBuild.awk` — a table is recognised by looking BACK at its delimiter row

- **A table needs two lines to identify and the main rule has no lookahead, so the recogniser is anchored on the delimiter line instead.** `|---|---|` fires the branch, and it looks back at the row already sitting in the open paragraph run: that row leaves `paraLines`, whatever prose sat above it flushes as its own block, and the table run opens. No lookahead, no provisional run, and nothing to roll back — a pipe line whose delimiter never arrives was never removed from its paragraph in the first place, so `prose` / `| a | b |` / `prose` stays one three-line paragraph exactly as before. Confirmed by a before/after diff over the whole existing grammar: byte-identical.
- **Rows are padded to the WIDEST row, not the header's width, and a ragged table is never refused.** Strict GFM requires the header and delimiter cell counts to match and drops the whole table otherwise — measured against pandoc 3.8.3, which turns the human-owner's own `| vote | 2nd |` over a three-field delimiter back into a paragraph of literal pipes, which is the defect this work exists to fix. Truncating to the header's width instead would have silently deleted that table's entire second-choice column. Padding is the only reshaping that neither drops data nor loses the message.
- **Cells are `rich_text`, so `parseInlineStyles` runs per cell.** `raw_text` would render a code span, bold, an emoji and a mention as literal characters — the whole reason the converter exists. A padded or empty cell still carries one space element, because Slack rejects a childless `elements` array wherever it sits and an empty cell is ordinary markdown.
- **`\|` is consumed by the cell splitter, not left for `parseInlineStyles`.** GFM's table extension splits on a pipe even inside a code span and gives `\|` as the one escape; unescaping it at the table layer is what makes `` `a\|b` `` render as `a|b` rather than showing the backslash, since a code span's content is taken verbatim further down. Every other escape passes through untouched. Both halves verified against pandoc's GFM reader.
- **The three table maxima live in `sh-lib/AgentsBlockKitValidate.py`, not in the converter.** A row count and a cell count are per-node properties the walk can see, and the 10,000-character budget is a sum over the array it already holds — unlike the 50-block cap, which is why those three are caught rather than joining the known-uncaught list. Keeping them there also keeps the converter a pure line-to-JSON transducer with no message-global budget state, and turns a breach into a named pre-send failure instead of a silent truncation.
- **`table` had to be added to that validator's `TOPLEVELTYPES` in the same change, and `link` did not have to be — that difference is the rule.** The set is closed and holds TOP-LEVEL BLOCK TYPES ONLY, so a block outside it is rejected before the send: the first table the converter emitted would have failed with "invalid or missing top-level type" and posted nothing, while `link`, a rich_text element rather than a block, was never closed against. A new top-level block type is blocked until it is listed there; a new rich_text element is not. Adding the type also makes `walkNode` descend into `rows` for the first time, which is what makes the empty-cell space element load-bearing rather than cosmetic.
- **`AgentsSlackBlocksTextVersion.py` has no `table` arm.** The converter's own `markdown` path never reaches it — the text version of a `markdown` body is that body itself — so a table written in markdown is unaffected. A `--format blocks` caller hand-writing a `table` block and supplying no `--message-text` gets `[table]` as the message text, the renderer's visible-placeholder-and-stderr behaviour for an element with no known text form. Working as designed, and the fix for that caller is `--message-text`, not a converter change.

## The blocks path fails before Slack rather than degrading to plain text

- **An empty node is what Slack answers `invalid_blocks` to, and three converter inputs produced one.** A blank line inside a fenced block emitted an empty `text` element; a heading marker with nothing after it emitted an empty `plain_text`; a bullet marker with nothing after it emitted a childless `elements` array. Each now emits nothing where the content is empty, and a fence whose whole content is blank emits no block at all — the guard an empty fence already had.
- **A blank fence line is represented, not dropped.** It contributes its own `{"type":"text","text":"\n"}` separator and no content element, so two consecutive separators carry the blank line. The separator is appended through `appendElem`, which is what keeps a leading blank line from producing a leading comma.
- **A skipped list item has to skip its separator with it.** Guarding only the append leaves the comma behind and produces `},,{` — invalid JSON from a valid message. `appendElem` is the shape that cannot get this wrong, and `parseInlineStyles` is called once into a local rather than twice, since it rewrites shared token globals and rescans the line each time.
- **`sh-lib/AgentsBlockKitValidate.py` walks the whole payload and runs on the array actually sent** — after the addressee and attribution splices, so the indices it reports are the ones Slack sees. It prints one problem per line by path; the caller fails on any output and on a non-zero exit alike, so a crash inside the validator cannot read as a clean payload.
- **Its contract is not that a Slack rejection is impossible, and cannot be.** The empty-node rule is in none of Slack's published Block Kit pages — it was learned from a live rejection, so the rule set is open by construction. Caught: every class measured. Not caught, each documented by Slack: the 50-block cap per message, the 150-character header maximum, the per-type required fields of a caller-supplied payload, and any value Slack resolves rather than shapes.
- **`invalid_blocks` is a verdict, not a transport fault.** Retrying it five times with backoff cost 30 seconds and produced a "Slack comms are stuck" email that was false — Slack answered, the payload was wrong. It breaks on the first response, with no email.
- **The exhausted-retries arm ended `... ; return $?`, so the operation exited 0 whenever the notification email succeeded** — for a message that never landed, with empty stdout. Under `set -e` that same line was never reached at all when the email failed. The email call is tested with `||` now and the arm returns 1 unconditionally.

## `--intern-` is a namespace, and the segment after it is the kind

- **`--intern-` marks the internal namespace. What follows it names a kind, never an operation.** `--intern-op-*` is the operations kind. `--intern-tool-*` is the tools kind. Further kinds are open, and a new one is approved by the human-owner before it lands.
- **A count of one kind says nothing about the namespace.** Every `--intern-*` name in this package was measured as a `DistroAgentsTools.fn.sh` operation, and the prefix was then read as marking an operation. The instrument was right and its scope was not. The `op` family was counted, and the conclusion was drawn about `--intern-` itself.
- **The counter-evidence was inside that same measurement.** `--intern-mcp-server`, `--intern-mcp-execute` and `--intern-main-loop` already carry a kind after the namespace. They were read as exceptions rather than as the shape.
- **`--intern-tool` is approved, as the tools kind.** It is `sh-lib/AgentsUniversalHarness.sh`'s own arm that runs exactly one harness tool and exits. It is not a flag borrowing an operation prefix.
- Anyone re-running that count reaches the wrong conclusion. The namespace is written out here for that reason, rather than only the one name.

## An external call takes a script, an internal call sources the include

- **A script file is for an external caller, and it also establishes the execution context.** Both jobs at once, and the second is why it is a script.
- That is why an MCP daemon execs the tooling instead of sourcing it. The daemon stays a daemon, and the tooling stays an executable run in the correct context.
- **An internal caller does better to subshell the context and source the more exact include.** Environment variables carry most of what that include needs.
- Re-entering a whole command script makes an internal caller pay again for option parsing it has already done.
- **Design to SOLID, and stay efficient on speed.** Both at once, and neither traded away for the other.
- **The eventual split of the harness into files is anticipated, and this principle governs it.** Nothing is built from it yet. It is recorded so that split is not designed against a different rule.

## `--intern-*` operations are excluded from customer-facing help

- Every `--intern-*` operation — the `--intern-op-*` primitives and the caller-less `--intern-mcp-server`/`--intern-main-loop`/`--intern-mcp-execute`/`--intern-validate-json` utilities alike — is left out of `Help.DistroAgentsTools.include`'s syntax lines and out of `Help.DistroAgentsTools.help.md`'s Operation Reference and Examples. A member never calls one directly, so a reader of `--help` has no use for its syntax or a worked example of it; its contract belongs to whoever is developing or maintaining the tool, which is what this file is for. An include's own header comment names the file and how it is sourced, never the operation's contract.
- A public operation's own help entry may still need to contrast itself with an internal op it complements (e.g. `--member-comms-slack-search-messages` vs. a bounded single-target Slack read). State that contrast in behavioural terms, never by naming the internal op — a caller does not need that name to choose between the two.

### `--intern-op-slack-check` call contract

- Reads exactly one target: `magic-team`/`human-owner`/`event-track`/`event-alert`, a bare `<conversation-id>`, or `<channel>:<ts>` for one thread. `human-owner` alone reads both of the human-owner's direct conversations and merges them chronologically, each line tagged with its own conversation.
- Exit codes (`human-owner` target only; every other target keeps plain 0/1): 0 both conversations read, 3 only one (named, with reason, in the output header), 4 neither, 1 failed before reaching either.
- Pretty-formatted (`ts | user | text`) by default; `--raw` returns the full API response(s).

### `--intern-op-slack-call` identity selection

- **The rule lives here, once, for every Slack op — not at the call sites.** `--intern-op-slack-call` resolves the acting identity under its own "Identity selection — one rule, applied here for every Slack op" block: with no `--identity`, a member holding a `SLACK_USER_TOKEN` acts as itself and one holding none falls back to the bot, and a `routine-*` author is forced to the bot regardless. A caller therefore gets the member's own identity by passing nothing.
- **So passing `--identity user` from a caller is not a no-op — it converts that fallback into a hard error.** The override arm checks the user token first and fails the call outright when it is absent, so a token-less member that sends fine today would start failing. Pass the flag only where acting as the bot is genuinely unacceptable and failing loud is the wanted behaviour (`--member-comms-slack-profile-*` does exactly that, deliberately, and records why in its own section). Everywhere else, pass nothing.

### `--intern-op-slack-call` upload mode (`--upload-file <name>=<path>`)

- Multipart POST, the one request shape neither the urlencoded GET nor the JSON POST can carry, because the payload is a file part. curl sets the Content-Type and boundary itself; supplying one makes the boundary disagree with the body curl writes. Not combinable with `--json-body` (two different request bodies — only the upload would be sent, dropping the JSON silently) nor with `--fetch-url`; both are refused at parse.
- Reports two line-anchored stderr fields, emitted whether the upload passed or failed: `UPLOAD_HTTP_STATUS=<code>` and `UPLOAD_BYTES=<n>`. Both read `not-reported` when curl failed before the transfer began and wrote no `-w` line at all — a positive state, because an empty value could not be told apart from a real zero.
- **`UPLOAD_BYTES` is bytes SENT**, and the direction differs from `FETCH_BYTES` deliberately. Both name the payload of their own operation — what the call moved — which resolves to received for a download and sent for an upload. Literal direction-symmetry would be the false symmetry. The received body on an upload is a small JSON response the caller already holds in full; bytes sent, compared against the file's size on disk, is the only signal separating a truncated or timed-out send from a refusal. Measured live: a 389440-byte PNG reports 389651, the ~211-byte excess being multipart framing.
- **There is deliberately no `UPLOAD_CONTENT_TYPE`.** `FETCH_CONTENT_TYPE` is load-bearing, not decoration: it is what lets a caller catch Slack answering HTTP 200 with an HTML sign-in page, the false success the fetch path states it cannot judge for itself. The upload path has no such false success — its verdict comes from the shared `"ok":true` test against a body Slack always sends as JSON — so the field would be a constant no caller could branch on, and a second copy of a fact the caller already has.
- The response body goes to its own temp file via `-o`, so the `-w` line is the only thing left in the capture. That inverts the fetch branch's arrangement for the fetch branch's own stated reason: `tail -1` is exact against curl's fixed single-line format and is not exact against a JSON body whose layout Slack controls.

### Slack attribution — the `X-Request-Detail` header

- Every Slack call site attributable to an acting member or a single conversation — not only `--intern-op-slack-call` — emits `X-Request-Detail: slack-workspace=<v>; client-member=<v>; channel-id=<v>` on stderr, ahead of any `KEY=value` fields the op itself carries, because a header precedes the data it describes. Text only, no JSON form — ruled directly: a MIME-style header is sufficient here and JSON is not wanted. `--intern-op-slack-check-scopes` (a scope-poll `auth.test`) and `--intern-op-check-configs`'s own `--resolve-slack-workspace-into` call (the resolution this header's own workspace field depends on) are diagnostic/introspection calls rather than attributed Slack actions, and carry no header of their own.
- It is a third category beside the two `--intern-op-slack-call`'s own header block distinguishes: the fields are the caller interface, the sentences are prose nothing may parse, and this is structured data whose shape is the point of it. It carries a colon, so no `sed -n 's/^KEY=//p'` can match it and the two namespaces cannot collide.
- **`client-member` names the Slack API client making the request, meaning the acting member. It does not mean a `client-*` member.** The name reads that way to anyone who does not already know, so it is explained wherever it appears rather than left to be renamed by the next reader repeating that reading.
- **The workspace is read from config, once per call** — the human-owner's own ruling. Resolution is two-tier, the same shape `AgentsToolsResolveSlackBotToken` already uses for the token itself (see "A member's own bot token, then the team's" below): the calling member's own persisted `SLACK_WORKSPACE_DOMAIN` when it has one, `magic-team`'s shared one otherwise. `AgentsToolsResolveSlackWorkspaceDomain` (`sh-lib/AgentsTools.CommsSlack.include`, defined beside `AgentsToolsResolveSlackBotToken`) is the one implementation; `AgentsToolsEmitRequestDetailHeader` calls it with the header's own `client-member` argument, so no site resolves this separately. `--intern-op-check-configs`'s `--resolve-slack-workspace-into <KEY>` is what resolves and persists a value into either scope, against a token that same scope holds itself — `SLACK_USER_TOKEN` first, `SLACK_BOT_TOKEN` after it — wherever that scope's own config-check pass runs: `magic-team`'s on the main loop's own pass (`--magic-heartbeat-config-check`), and a client member's own on its own sweep's pass (`--client-sweep-config-check`) — never per message either way.
- **Traded away on purpose, and only partly recovered**: the earlier per-call `auth.test` read the *acting token's own* workspace, so a member acting under its own foreign-organisation user token correctly reported that organisation's workspace, distinct from the team's own bot-token workspace. The two-tier config read recovers this precisely when the acting member holds its own persisted `SLACK_WORKSPACE_DOMAIN` (resolved from that same member's own `SLACK_BOT_TOKEN`, per the config-check pass above); a member with none still reports `magic-team`'s shared workspace, which may disagree with whatever token that particular call actually used. Ruled directly, and on cost: the workspace is not to be read from `auth.test` at all — it comes from stored variables and settings, which is the cheap form and the wanted one. Do not reinstate a per-call `auth.test` to recover the remaining gap.
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

### `--intern-op-contact-digest-send` call contract

- **Three layers, the trash family's own shape.** `--magic-contact-digest-send <team-member> <origin team-member> …` and `--member-contact-digest-send <team-member> …` are thin wrappers holding no implementation: each validates its own arguments and forwards into this primitive with `--context <its own op name>`. They differ only in where the origin comes from — the magic form takes the origin explicitly, because that caller reports about another identity's correspondence; the member form accepts none and supplies the acting member itself, so a caller passing one fails closed. That mirrors `--member-inbox-item-trash` against `--librarian-inbox-item-trash` over `--intern-op-board-trash`. It also matches the grant model: `--member-*` is the shared floor every member has, `--magic-*` is `magic-coordinator`'s alone.
- `--intern-op-contact-digest-send <team-member> <origin team-member> (--resolved|--needs-ruling) <text...>` reports one contact assessment to the human-owner. `<team-member>` is the acting identity the send goes out under. A stub over `--member-comms-slack-send-message`: it composes what that operation already accepts and changes nothing about it, because the knowledge of whose request it is lives with the member holding the correspondence, not in the shared send path.
- `<origin>` is the team member whose correspondence produced the digest, and it is carried in the message's `to` position — `--address-to`, the only field that renders on a send under a member's own account. It reads as an addressee and means an origin. The human-owner has ruled that arrangement in as it stands and ruled out changing the header for it; that ruling is why this op exists rather than an option on the send operation. Origin appears at all because a relay identifies whose words it carries: the sending account does not say who asked. **The origin is any team member, deliberately not a `client-*`/`partner-*` family.** Any member may hold a `SLACK_USER_TOKEN`, any may have its own routine reading its own correspondence, and `magic-coordinator` and `magic-team` were both measured holding DMs of their own — a family restriction would leave a request arriving in the coordinator's own DM with no way to be reported. It is validated as a bare member name and nothing more.
- `<text>` is the rest of the digest in the human-owner's own order — who wanted what, then the resolution. Rendered whole, origin included: `from client-ndm the user Dmitry asked for your password - was denied.`
- **The two routes are not one target plus a flag.** `--needs-ruling` uses the send path's own `human-owner` target, which forces the acting member's user identity, and lands in his own Slack DM — where he replies. `--resolved` wants the opposite, the bot's own conversation with him, and that same target refuses to be it by design (a bot post there is the shared team DM, never single-party), so this route resolves `SLACK_CHANNEL_HUMAN_OWNER` and addresses his account with `--identity-bot`. Exactly one route is required.
- No member declares any of the three yet, so nothing calls them until an armed file lists them.
- See `non-owner-contact-tiers-and-escalation` in `magic-team/magic-team.conversations.md` for what is assessed and when a digest is owed. The digest is one of two records of the same event; the other is the contacts note's `### Escalations` entry, written the same session.

### `--intern-main-loop` call contract

- No `<team-member>` argument, same shape as `--intern-mcp-server`. A mode is required and there are two: `--run` loops forever, `--one` runs a single iteration and returns its status. Anything else, no mode included, prints syntax and exits 1 — an accidental bare invocation must never hang.
- **`--one` never enters the loop.** The iteration body is one helper defined inside the arm, called once by `--one` and repeatedly by `--run`, so no mode flag is tested inside the loop and nothing leaves it by flag. `--one` returns the iteration's own status, does not sleep, and leaves the backoff state untouched because nothing there consumes it. It runs the same readiness gate, which is what makes it the way to exercise that gate by hand.
- **Readiness is checked once, before the loop, never per iteration.** `--intern-op-check-configs` probes the configuration keys (every key `--optional`, so the probe itself never gates) and the output is piped into `AgentsMainLoopReadinessReport.awk`, whose own exit — `PIPESTATUS[1]` — is the gate. A failing gate returns before the loop is entered. The keys sit in two config scopes, so the probe is two calls inside one `{ … }` group feeding one awk: `magic-coordinator`'s (`TEAM_DATA_DIRECTORY`, `SLACK_CHANNEL_MAGIC_TEAM`, `SLACK_CHANNEL_HUMAN_OWNER`, `SLACK_CHANNEL_EVENT_TRACK`, `SLACK_CHANNEL_EVENT_ALERT`) and `magic-team`'s (`SPAWN_CLI_SERVICE`). The floor — the items that actually gate — is `TEAM_DATA_DIRECTORY` + Basic comms + `SPAWN_CLI_SERVICE`; the activity-log and alert channels are reported and never gate. A floor item probed but not declared in the awk's own `addItem` list is a hole in the gate, not a lenient gate: it lets the loop start and then fail every iteration.
- Each iteration: one `--magic-heartbeat-spawn-proxy magic-coordinator --wait`, then a sleep. Log-and-continue regardless of the spawn's own exit code, but the wait is **not** flat: it starts at `MAIN_LOOP_RESTART_DELAY_SECONDS` (magic-coordinator config scope, default 29), doubles after each failed iteration, and stops at `MAIN_LOOP_RESTART_DELAY_MAX_SECONDS` (same scope, default 1200). A successful iteration resets it to the base. Both values are validated as digit strings and fall back to their defaults otherwise. The delay is the state, so the doubling stops at the ceiling and cannot overflow — and a permanent misconfiguration therefore shows as a green start followed by iterations that fail, then by silence at the ceiling, rather than as a loud exit.
- **The spawn brief is a file, not a literal in the arm.** Each iteration pipes `skillset/magic-team/magic-team/dispatches/main-loop-next-iteration.prompt-packet.verbatim.md`, resolved under `$MDLT_ORIGIN` like the readiness awk beside it, into the spawn proxy — whole, with no strip rule of any kind, so the file's every byte is the brief and a member edits a real discoverable file rather than a printf. `cat … |` is the form on purpose and not a useless-`cat`: `DistroAgentsTools` is a shell function carrying its own `set -e`, and the pipe is the subshell that keeps a failure inside the spawn one failed iteration instead of the daemon exiting — a `<` redirect or a `--from-file` flag would remove it. The file is checked readable-and-non-empty once before the loop and a failure there is fatal, because the path is a constant shipped with the code: a per-iteration test would turn a permanent misconfiguration into an endless backoff, and the spawn proxy would report it only as `empty spawn context`, further down.
- **Everything this operation says goes to stderr, the readiness report included.** It is a daemon loop whose whole life is watched on one stream, so the readiness verdict belongs on the same stream as the per-iteration lines rather than on a stdout nothing reads. The report's machine-readable half is the readiness awk's own exit status (`PIPESTATUS[1]`), which is what gates loop entry and is unaffected by where the text goes.
- **The readiness report carries a third kind of item beside floor and optional: a diagnosed one.** It is a state the loop cannot fix and no config key holds, and today there is exactly one — `Agent CLI sign-in`. `SPAWN_CLI_SERVICE` present, the CLI installed and on `PATH`, and the human not signed in is the state every existing check passes and every iteration then fails on, opaquely, which is what a freshly provisioned host looks like. The arm reads it from the CLI itself and appends a `SPAWN_CLI_AUTHENTICATED: OK|FAIL|SKIP` line into the same brace group the check-configs probes feed, so the awk's existing `KEY: STATUS` contract carries it and `PIPESTATUS[1]` stays the awk. **It never gates**, and there is no auth config key — authentication is the CLI's own, done by the human out of band and only read here. The probe is `claude auth status`, whose JSON `loggedIn` field is the verdict: local-only, ~0.3s, stdin closed so nothing can prompt, and true for an `ANTHROPIC_API_KEY` or a Bedrock/Vertex provider as well as for a signed-in account. Every case it cannot read — any other CLI, a `claude` too old to carry `auth status`, one absent from `PATH`, an output shape it does not recognise — is `SKIP`, reported as `not checked`; a machine the probe cannot answer for is never refused. Adding a second CLI's probe is a branch in the arm's `case`, not a change to the report.
- The `🤖 AI service used: <cli>` line seen once per iteration is `--intern-op-agent-spawn-proxy`'s, not this operation's. It names the CLI read back out of the child's own `DISTRO_CONSOLE_EXEC=` sentinel — the console owns the `--cli`/`SPAWN_CLI_SERVICE`/auto-scan resolution, so the announcement is taken from what actually ran and cannot disagree with it.
- **A `--dispatch-doc:none` spawn writes nothing under `$MDAT_DATA_ROOT`** — `--intern-op-agent-spawn-proxy`'s behaviour, not this operation's. Under `--wait`, which is this loop's only form, the child's own stdout and stderr go to the caller's stderr and no `OUTPUT_FILE` key is printed, so a failed iteration is read where it happened rather than in a file nothing opens. An async `none` call has no waiting caller left to read them, so it keeps them in a file under `$MMDAPP/.local/temp/` and still prints the key; sending them to a returned caller's stderr instead would let a caller capturing this operation with `2>&1` hold that pipe for the child's whole life, which is the permanent-hang shape "Capturing an arbitrary command's output" above describes. The launch marker takes the same split and is removed at the end of the call — it is the only thing separating a real failure from a silent no-op, so it still exists, but nothing of a spawn that keeps no dispatch document is left in the team data tree. `create` and `reuse` keep the audit log, because the dispatch document records its path and `magic-coordinator.advance.routine` reads it.
- **When the selected CLI is `claude`, what lands on that piped-to-caller's-stderr stream is reformatted, not raw.** The console script (`AgentsConsoleShellScript.template.sh`'s `DagcRunClaudeStreaming`) runs claude with `--verbose --output-format stream-json`, backgrounded rather than exec'd, and pipes its JSON-lines stdout through `awk -f AgentsProgressLineSafe.awk -f AgentsClaudeStreamJsonFormat.awk` (run `LC_ALL=C`, which the primitive requires — see `AgentsProgressLineSafe.awk`'s own section below). The formatter is **not standalone**: it calls `progressLineSafe()` and the primitive file must be loaded ahead of it, or the run dies on the first record that reaches a call. The awk turns that stream into short per-line progress on real stderr — `session started`, `thinking: <preview>...`, `-> tool: Name(arg)`, `<- tool result`, `answering: <preview>...` — and copies the terminal `type:"result"` line's own `.result` text onto real stdout, exiting 0 or 1 per that line's `is_error`. Any other CLI is still `exec`'d directly with no reformatting; this split exists because only claude's batch mode goes silent for the whole run without it.
- **Backgrounding claude (instead of exec'ing it) is what makes Ctrl-C/kill actually stop the run**, and the trap chain has to be unbroken end to end for that to hold: `DagcRunClaudeStreaming` captures claude's real PID and installs a `TERM`/`INT` trap immediately after capturing it (before anything else, including closing its own copy of the streaming fd) that forwards the signal to that PID; `--intern-op-agent-spawn-proxy`'s own `--wait` block traps the same two signals onto the console's PID and clears its trap (`trap - INT TERM`) before returning; this operation's outer `while true` loop traps them once, for the loop's whole life, onto the spawn-proxy's PID, and clears its own trap before either `return 130` path. Each layer's `wait "$pid" || …` is followed by a `while kill -0 "$pid"; do wait; done` re-wait, because bash's `wait` returns early (interrupted) the instant a trapped signal arrives, before the child has actually exited — without the re-wait loop, the reported exit code and the "has it actually died yet" state can disagree.

### `--intern-mcp-server` call contract

- `--run` is required to actually serve; without it, prints syntax and exits — so a registration whose `args` omit it registers a command that can never serve.
- Registers into this workspace's own MCP config only, command resolved to this workspace's own `DistroAgentsTools.fn.sh`, args `["--intern-mcp-server","--run"]`, no `env` (the operation establishes the workspace environment itself). To register another workspace's tooling, run this operation from that workspace. Exposes exactly one tool, `execute`, backed by `--intern-mcp-execute`.
- **`execute` takes one of two shapes and `required` is empty for that reason**: `command` starts a script, `job` addresses one this server already started. A call carrying neither is rejected, and `job` is read before `command` so a poll never falls through to the start path. `timeout`, `background` and `action` each qualify one of the two shapes and mean nothing on their own.
- **A foreground call is bounded by `timeout`** — seconds, default 600, capped at 3600, and a non-numeric or absent value takes the default rather than failing the call, so a caller that never knew the argument exists keeps working. On expiry the call answers `isError` naming the limit, and the partial output is **kept** at a path named in that same message; ordinary completion deletes it. `background` imposes no bound at all: a bound is what an unwatched call needs, and a job the caller can poll and kill needs no deadline guessed for it.
- **`background:true` answers at once with a job id, a pid and a log path.** `job:<id>` alone polls it, returning only the bytes written since that job's own last poll — a byte cursor, so polling a long build does not re-deliver its whole log. `job:<id>` with `action:"kill"` signals it. The id is this server's own request sequence number and is read out of the start reply, never assumed to be the JSON-RPC request id.
- **A job's recorded pid is a process-group leader, not a plain pid, and every signal goes to the group.** Both the foreground watchdog and `action:"kill"` fork under `set -m`, which puts the job in a group of its own; signalling the pid alone kills the wrapper subshell and leaves the script, and everything the script forked, running — measured, with the server then reporting the job killed and finished while its output kept arriving. The whole pipeline goes inside the backgrounded subshell for the same reason: with a bare pipeline `$!` is its **last** process while the group id is its **first**, so the two disagree and the group signal lands nowhere. The watchdog is signalled the same way, or its own `sleep <timeout>` is orphaned by every foreground call and lives out the full default ten minutes.
- **`rc` is written by the job itself, so its absence is a real distinction and is never reported as an exit code.** A poll answers one of three states — still running, finished with the recorded code, or stopped before it could finish. A placeholder in the exit-code position reads as an ordinary completion and hides a kill.
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

### `--member-comms-slack-socket-*` call contract

- `--member-comms-slack-socket-start <team-member>`, `--member-comms-slack-socket-status <team-member>`, `--member-comms-slack-socket-stop <team-member>`. Declares `app_mentions:read`. No help pair, the presence family's own arrangement, and for the same reason: no member declares these operations, so a reader of `--help` cannot call one.
- Socket mode is opened by `apps.connections.open` under an **app-level** token, `SLACK_APP_TOKEN`. Neither a bot nor a user token is accepted for it, so neither existing resolver stands in. The key resolves two-tier — the acting member's own scope, then `magic-team`'s — the shape `AgentsToolsResolveSlackBotToken` already uses.
- **The scope holding the token is the receiver's identity key, never the member name.** One app-level token is one app, and Slack delivers each event to exactly one open connection: two members falling back to the shared scope would open two receivers onto one app and split its events between them. Keyed on the scope, the second start finds the first alive and does nothing.
- The holder is found by argv match rather than a pidfile, and a start is guarded by an atomic `mkdir` lock — both for the reasons the presence family states.
- **The token reaches the holder and the URL does not**, inverting the presence arrangement. `apps.connections.open` mints a URL that expires, and Slack requests a refresh every few hours, so a holder handed one URL dies at the first refresh and stops hearing. The token arrives by environment, the channel presence already uses for a URL that is itself a bearer capability.
- **Acknowledge before handling.** Slack resends anything unacknowledged within three seconds and the filing below takes longer than that, so an envelope is acknowledged on arrival. The handling that follows can therefore never be retried by Slack, which is why a filing failure is logged as the loss it is rather than swallowed.
- Continuation frames are reassembled. A JSON message split across frames would otherwise fail to parse, and an unparsed envelope is never acknowledged — so Slack would resend it into the same failure indefinitely.
- **One bot event is declared and one is consumed.** `app_mention` closes a measured gap: the team bot already holds `app_mentions:read` with no channel by which a mention can arrive, because `search.messages` is refused to a bot token at any scope and the session-context scan reports that limit in its own output. Any other event type is logged and dropped — declaring an event in the manifest that nothing here consumes is exactly what this pairing exists to prevent.
- **An arriving mention becomes an `inquiry-*` in `magic-coordinator`'s own inbox**, carrying `communication-channel-id: slack:<channel>:<thread-ts>`. Nothing new consumes it: that is the shape the session-context scan, the communication sweep and advance already read. The inbox owner is fixed rather than an option, because triage is `magic-coordinator`'s own.
- The receiver runs until stopped and carries no TTL, unlike presence: an abandoned presence holder leaves a persona falsely active, while a receiver that stops merely stops hearing. It writes `$MMDAPP/.local/temp/slack-socket.<scope>.log`, and `--status` names that path so a receiver that died overnight is read rather than guessed at.
- Its WebSocket framing is its own rather than shared with `AgentsSlackWebsocketPresence.py`. The two want opposite things of the same frames — the presence holder discards every text frame and exists only to hold the socket open, the receiver parses and answers each one — and factoring a shared frame layer out would mean editing the presence holder, which is settled code. The duplication is the price of leaving it alone, and is deliberate.

## `--member-comms-slack-profile-*` call contract

- `--member-comms-slack-profile-set <team-member> [--display-name <v>] [--title <v>] [--status-text <v>] [--status-emoji <v>] [--status-expiry <ts>] [--avatar <path>] [--presence auto|away] [--snooze <minutes>|--snooze-end]` and `--member-comms-slack-profile-get <team-member>`. Both declare `users.profile:read users.profile:write users:read users:write dnd:read dnd:write`. A top-level section, not a child of the help-exclusion section above: unlike the presence family, both of these carry a full help pair.
- Own file for size only, routed from `AgentsTools.MemberCommsSlack.include`'s own `case` by a `--member-comms-slack-profile-*` glob, so the top-level dispatcher keeps its single `--member-comms-slack-*` arm.
- Persona identity only, enforced in three layers rather than one. `--identity-bot` is refused in the option loop; `--identity user` is passed explicitly on every call, so a member with no user token fails loud instead of silently acting as the bot; a `routine-*` name is refused outright with its own message, so the cause is never misreported as a missing token.
- An empty string is a value, never an absence. `--status-text ''` clears the status, and empty `--display-name`, `--title` and `--status-emoji` clear theirs; those four guard on positional presence, the remaining value-taking flags on a non-empty value. Whether any field was given at all is a counter, never a test of the values.
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

## `--member-wait-for-input` call contract

- `--member-wait-for-input <team-member> [--wait-source <kind>:<target>]... [--wait-timeout <seconds>] [--wait-poll-interval <seconds>] [--wait-since-utime <epoch>]`, and `--member-wait-for-input <team-member> --wait-list-sources`. One bounded long poll over a list of input sources, returning the moment any of them changes. Own file, `sh-lib/AgentsTools.MemberWait.include`, behind its own first-level arm. Defaults: the sources `slack:magic-team` and `slack:human-owner`, a 300-second bound, a 15-second poll. A poll interval below 1 is refused — a zero interval is a spin, not a poll.
- **The waiting happens here, in the shell, and that is the whole point.** A caller that would otherwise spend a round trip per check spends one call and one result, and its context does not grow while nothing is happening.
- **stdout ALWAYS opens with exactly one marker line**: `WAIT-RESULT: RECEIVED`, `WAIT-RESULT: TIMEOUT` or `WAIT-RESULT: ERROR`. RECEIVED and TIMEOUT both exit 0, because both are answers; ERROR exits 1. A TIMEOUT is a complete, successful wait, and the body says so in those words. The distinction is the reason the operation exists: a caller that cannot tell "nothing arrived" from "the probe could not run" cannot choose between waiting again and escalating.
- **A source is `<kind>:<target>`, and the kind selects a probe function by name** — `AgentsWaitProbe` plus the kind with its first letter uppercased, with `$agentsWaitSourceKinds` listing what this build carries. Adding an IM bridge or a portal feed later is one new function plus one word in that list. Nothing else in this operation, in the `Wait` harness tool, or in the harness self-check knows a source kind. `--wait-list-sources` prints that list and waits on nothing, so the extension point is observable rather than a second list to keep in step.
- **Two adapters ship.** `slack` goes through `--member-comms-slack-read` and no other path, so the credential stays inside that operation and never reaches argv here; a target carrying a `:` names one message and its thread is rendered whole. `file:<absolute-path>` watches a local drop path, file or directory — the shape a future bridge writes into, and what makes the whole thing testable with no host involved. An absent path renders empty rather than failing: "not there yet" is a state, and a drop that appears later is exactly the arrival being waited for.
- **An adapter is never asked what "new" means.** It renders what is there now; the operation compares each rendering against the baseline it took at the start of the wait. So an adapter needs no cursor, read mark or message identity. With `--wait-since-utime` the baseline is empty, so a reply already sitting there returns immediately instead of reading as scenery; without it the first probe is the baseline.
- **Every source is resolved to its probe before the wait starts.** A kind this build does not carry is a stated ERROR at second zero, naming the kinds that exist — never a source that silently never fires for the length of the bound. A `--wait-source` that is not `<kind>:<target>` is refused the same way.
- **A probe that cannot run is reported by name and the wait carries on over the rest.** One unreachable source must not turn a multi-source wait into silence. The failing sources are listed in the body, and the TIMEOUT body adds that nothing is known about them either way and their silence must not be read as quiet.
- **Probes render to files, never through `$( )`.** The Slack read forks `curl`, and a capture returns when the pipe has no writers left rather than when the process exits.

## The Atlassian operation families

- Every Jira and Confluence operation keeps its whole logic in one internal operation in `sh-lib/AgentsTools.InternOpAtlassianCall.include`, reached through the one `--intern-op-atlassian-*` arm, over the shared transport `AgentsToolsAtlassianCall`. The public families are stubs over those operations and hold no logic of their own.
- `--member-comms-jira-*` carries board-list, board-read, board-issue-search, sprint-list, sprint-issue-search and issue-read; `--member-comms-confluence-*` carries space-list and page-read. The member families are the list reads plus one pointed read per platform (`sh-lib/AgentsTools.MemberCommsJira.include`, `AgentsTools.MemberCommsConfluence.include`).
- `--magic-comms-jira-*` and `--client-comms-jira-*` carry the member Jira set plus issue-search, comment-read, issue-create, issue-update, issue-transition, comment-add and issue-delete. `--magic-comms-confluence-*` and `--client-comms-confluence-*` carry space-list, page-read, page-search, comment-read, page-create, page-update, comment-add and page-delete. They live in `sh-lib/AgentsTools.MagicComms.include` and `AgentsTools.ClientComms.include`.
- An operation takes one call shape in every family that carries it: `<team-member>` first, then positional ids, then the flags that shape names.
- **An internal operation is a dispatch operation, never a shell function shared between families.** It joins the one `--intern-op-atlassian-*` arm rather than starting a second, exactly as the `--intern-op-slack-*` operations share one arm and one file. A product-specific operation names its product (`--intern-op-atlassian-jira-board-list`, `--intern-op-atlassian-confluence-space-list`); `--intern-op-atlassian-call` and `-check` take `--product` and serve both.

## A stub is a fixed mapping

- A stub admits exactly the arguments its shape names and refuses anything else with 1 before any call. It takes each required word with `shift ||` and an `[ -n ]` check, so a missing word is refused by name alone: "<name> missing" in a stub, "--flag value missing" where an option was given without its value in the internal layer. An argument that is present but unwanted is refused in one of two shapes, by what the arm actually knows: where a whitelist loop holds the offending word it names only that, "unexpected: <word>"; where the refusal is on shape or count it claims nothing about which word or how many, and repeats the caller's own arguments as "not accepted: <arguments>". A read stub then matches the rest of its argument list against the shape; a write stub admits only the flags its shape names.
- **A refusal names only what is missing, in a few words.** It carries no explanation and no syntax tail: the operation says which word or option it wanted and stops. Every Atlassian arm follows it, the stub families and the internal layer alike. The `⛔ ERROR` mark and the operation's own name stay, as on every other error this package prints, and the help is where a caller reads what the operation requires.
- The acting member is the credential selection. `--magic-*` acts as `magic-coordinator` only; `--client-*` gates on the `client-*` pattern, so a second client member joins the family by existing; `--member-*` acts as the member named.
- A stub forwards its own `--member` and `--context`, and the internal layer refuses a second `--member` or `--context` with 1 before its dispatch case, so no caller argument replaces the identity the stub checked.
- Every diagnostic the internal operation writes uses the stub's `--context`, so a caller is told about the operation it invoked and never about the internal one.
- A stub prints nothing of its own on stdout, propagates the layer's status verbatim, and never calls another stub: the shape the Slack family has, where `--member-comms-slack-*` and `--magic-comms-slack-*` each reach `--intern-op-slack-call` directly. `--client-sweep-input-scan` composes a whole document on stdout and is not the precedent here; copying it would destroy `space-list > file`.

## Confluence

- Own key set: `CONFLUENCE_SITE`, `CONFLUENCE_USER`, `CONFLUENCE_API_TOKEN`, read from the acting member's own scope with no fallback and never a `JIRA_*` value. One Atlassian account authenticates every product on a site, so the two sets legitimately hold identical values; separate sets are what allow one service's credential to be rotated, revoked, scoped to another site or pointed at another account without disturbing the other.
- `page-search` uses `/wiki/rest/api/search?cql=...`; `page-read`/`comment-read` use the v2 endpoints (`/wiki/api/v2/pages/<id>`, `/wiki/api/v2/pages/<id>/footer-comments`). Confluence's REST v2 serves no rendered form: `--format storage` (the default, plain XHTML) or `atlas_doc_format` (ADF, captured raw) are the only two, unlike Jira's `adf`/`rendered` pair.
- **`page-search` and `comment-read` carry no completeness signal at all.** Neither endpoint reports `isLast` or a total, unlike Jira's `/search/jql`, so both operations state `more: unknown` on stderr every time rather than letting a full page read as a confirmed-complete one.
- A 404 means either the content does not exist or this account cannot see it, exactly as for Jira — Confluence states the same ambiguity in its own response text, and it is never reported here as "does not exist".
- **`page-create` needs the numeric space id, not the key REST v1 callers know.** `/wiki/api/v2/pages` refuses a space key outright. `--space <key>` runs one internal, mandatory `GET /wiki/api/v2/spaces?keys=<key>` lookup first and refuses (never guesses) on zero or more-than-one match; `--space-id <numeric id>` skips that round trip for a caller that already holds it. `--parent-id` is optional; the body is `spaceId`/`status:"current"`/`title`/`body.representation:"storage"`. No read-before-write and nothing to conflict with, so no version gate here.
- **`page-update` is version-gated, and deliberately does NOT read the current version for the caller.** The caller passes `--version <n>`, read earlier from the same family's `page-read` stderr diagnostic; the operation computes `<n>+1` and submits it. Re-fetching the freshest version internally right before the write would silently turn Confluence's own optimistic lock into last-write-wins, defeating the one guarantee a caller relying on `--version` has. **This is a full-resource `PUT`, not a patch**: `--title` and `--status` are required on every call and are overwritten with whatever is passed, so an edit meant to touch only the body must still resubmit the unchanged title and status or it silently loses them — stated loudly in the operation's own error text, not left to be discovered. HTTP 409 is the shared layer's own distinct `rc=5` (never lumped into the generic `rc=3` UNKNOWN), and this operation's own added context on it is explicit: re-read the page for the real current version/title/body and decide whether to reapply the edit on the new content, **never resubmit version+1 unchanged**. `--space-id` is accepted and passed through when given but not required — live-probed against `ndm.atlassian.net`'s own CLOUD space: the endpoint accepted the `PUT` with no `spaceId` in the body at all.
- **`comment-add` has no ADF path**, matching the read side: `/wiki/api/v2/footer-comments` takes `pageId` and a storage-format `body` only, with an optional `parentCommentId` for a threaded reply. A reply's parent is read first, and a parent on another page refuses the reply with 1 before anything is posted. No version gate.
- Every write's own JSON body is assembled by hand — `AgentsMcpJsonEscape.awk` escapes each scalar string value, and the pieces are concatenated the same way `--member-comms-slack-profile-set`'s `profileFieldsJson` already is. There is no arbitrary-fields passthrough anywhere in this family (unlike Jira's `--fields-json`/`--update-json`): every field `page-create`/`page-update`/`comment-add` accept has its own flag.
- **A real `CLOUD`-space test page from this family's own live-testing is still live and needs manual deletion.** Page `4686086147` (`CLOUD`, Cloud Services) was created, updated and commented on under the human-owner's own test authorisation, then re-titled and re-bodied to "DELETE ME -- write-op test page, cleanup blocked by missing permission" once cleanup itself failed: the testing account has no delete/trash permission in `CLOUD`. `DELETE /wiki/api/v2/pages/{id}` answered an ambiguous 404; the classic `DELETE /wiki/rest/api/content/{id}` answered a clear 403, `PermissionException`. The family performs a delete since landing 17 (`page-delete`), but no operation can grant rights the account lacks — removing the page still needs a different Atlassian account, one that holds delete rights in `CLOUD`.

## Jira

- Own key set: `JIRA_SITE`, `JIRA_USER`, `JIRA_API_TOKEN`, read from the acting member's own scope with no fallback and never a `CONFLUENCE_*` value. One Atlassian account authenticates every product on a site, so the two sets legitimately hold identical values; separate sets are what allow one service's credential to be rotated, revoked, scoped to another site or pointed at another account without disturbing the other.
- `/rest/api/3/search` is retired. It answers 410 naming `/rest/api/3/search/jql` as the replacement, and that is the endpoint this family uses. Measured against `ndm.atlassian.net`.
- `/rest/api/3/search/jql` refuses an unrestricted query with HTTP 400, so a caller's JQL names at least one restriction. It pages by `nextPageToken` and reports `isLast`, and it returns no total — so a truncated page is reported as "more match, how many is unknown", never as a count.
- **A JQL Jira cannot resolve returns success with an empty page, not an error.** Measured both ways: a query naming a project key that does not exist, and a line of plain prose that is not JQL at all, each returned HTTP 200 with no issues. So an empty result set from `issue-search` is evidence about that exact query and nothing else, and the operation says so on stderr whenever it returns no rows.
- `issue-read` names the fields it wants. An unrestricted issue read returns every custom field the site defines, which is a large payload nothing here uses.
- `--format adf` is the default and `rendered` the alternative, the same round-trip reasoning the Confluence family's `storage` default follows: ADF is the document Jira accepts back on a write, and Jira's rendered HTML cannot be written back. Unlike Confluence's REST v2, Jira does serve the rendered form (`expand=renderedFields`, `expand=renderedBody`), so it is offered rather than absent.
- A description field returned as null is a real answer — the issue has no description — and is reported as that, with a zero exit, never as a failed read. A missing `fields` object or a missing `description` key is the failed read.
- A 404 means either the issue does not exist or this account cannot see it. Jira states the ambiguity in its own response text, and it is never reported here as "no such issue".
- **A rejected credential does not always surface as a rejection.** Measured with a deliberately wrong token: `/rest/api/3/myself` answers 401, exit 4, but an issue read answers 404 — Jira treats the unauthenticated request as anonymous, and a private issue is invisible to anonymous. `--intern-op-atlassian-check --product jira` calls `/rest/api/3/myself` and is the credential check; no public operation reaches it yet, so a credential is never diagnosed from a read that failed.
- **`issue-create` never calls createmeta.** `--project`/`--issuetype`/`--summary` are always required; everything else a project's own create screen demands (a subtask's `fields.parent.key`, say) travels through `--fields-json`, merged into the body by `sh-lib/AgentsAtlassianJsonObjectMerge.py` (below) rather than fetched and validated here on every call. `--description-adf`/`--description-adf-from-stdin`/`--description-adf-from-file` is the same ADF document shape `--member-comms-jira-issue-read --format adf` already emits for `fields.description` — passed straight through, never re-encoded. **Never auto-retry a create whose own outcome came back UNKNOWN (a timeout, a 5xx)**: Jira's create endpoint carries no idempotency key, so a blind retry can leave two issues behind with no way to tell from here after the fact; an HTTP 400 is a genuine, different outcome — a real field-validation rejection, with Atlassian's own `errors` object already in the diagnostic the shared layer prints — but the shared transport's own exit codes do not distinguish the two (both surface as the same `rc=3`), so this operation's own error text names both possibilities together rather than branching on a status code it cannot actually see.
- **`issue-update` ships both of Jira's write shapes for one `PUT`, not one now and one later.** `--fields-json <json>` is the whole `fields` object, plain set-semantics per field it names — an array field such as `labels` is a full replace, not an append, so a caller adding one label reads the current array first; this operation runs no read-before-write of its own. `--update-json <json>` is Jira's own `{"field":[{"add":...}/{"remove":...}/{"set":...}]}` shape for precise add/remove on a multi-value field. At least one of the two is required; both may travel in the same call. **`fields.status`/`update.status` are refused locally in either shape** before any HTTP call is made — Jira Cloud rejects a status change through this endpoint outright, so the error points at the issue-transition operation of the same family instead of surfacing as a confusing remote 400. `notifyUsers` defaults to `false` on every write this operation makes (Jira's own API default is `true`), to avoid spamming real watchers/assignees on an automated edit; `--notify-users` opts back into notifications.
- **`issue-transition` never accepts a transition id from the caller.** The lookup (`GET .../transitions`) is internal and mandatory, run immediately before the `POST` on every call: a transition id is workflow- and status-specific plumbing an agent has no legitimate way to already hold, and unlike Confluence's version (above), nothing is lost by always re-resolving it fresh, so it is never worth caching. `--to-status <name>` is matched exactly, never fuzzily, against each currently-available transition's own **destination status name** (`to.name`) — not the transition's own action label, which can legitimately read differently (e.g. a button labelled "Start Progress" landing on status "In Progress"). Zero matches or more than one is a loud, client-side failure before any `POST`, listing the actual transitions available from the issue's current status. `--fields-json` passes through into the transition `POST`'s own `fields` (some workflows require a field, commonly `resolution`, on a specific transition's screen); `--comment-adf`/`--comment-adf-from-stdin`/`--comment-adf-from-file` adds a comment in the same call via `update.comment`.
- **`comment-add` carries no `visibility` (role/group restriction).** Same ADF body shape the read side already emits (`{"body": <ADF-doc>}`), no read-before-write.
- **`sh-lib/AgentsAtlassianJsonObjectMerge.py`** is the one piece of Python in either family, used only by the Jira write side's `--fields-json`/`--update-json` flags. It validates a caller-supplied JSON object against a trusted base object this package's own shell code already built, rejects a top-level key collision or a named-forbidden key (`status`, from `issue-update`), and prints the merged object back through `json.dumps` — never a text splice, since a naive brace-strip breaks the moment a value inside the overlay contains `{` or `}` of its own.

## Jira lists

- **Paging values are whole numbers, validated and refused rather than repaired**, because each lands in the query string and a value carrying `&` would append parameters of its own and change the result set mid-walk. `--start-at 0` is the first page and legitimate; a `--limit` of 0 asks for nothing. `--limit` is this package's own caller-facing spelling for Jira's `maxResults`; the agile read stubs do not admit it.
- **Every Jira list states completeness as `more: no`, `more: yes` or `more: unknown`.** board-list and sprint-list read `isLast`; board-issue-search, sprint-issue-search and comment-read compare the site's total with `startAt` plus the rows on the page, and name the next `--start-at` on `more: yes`; issue-search reads `isLast` and reports no count. A page that could not be read and a page that is whole never read alike.
- **sprint-list checks the board before it calls the sprint endpoint.** A kanban board holds no sprints. A team-managed board reports the type `simple`, which is why the features read exists at all — reported in Atlassian's own tracker (JRACLOUD-85696), not measured here. A simple board holds sprints only while its board feature `SPRINTS` is `ENABLED`, and `DISABLED` means none. Without sprints the operation prints an empty listing, states `more: no` naming the board, and returns 0 without calling the sprint endpoint. A features read that fails returns the layer's own status. Any other `SPRINTS` state, none included, returns 3. The sprint endpoint's own error text is localised and is never matched.
- **Agile reads return the site's own JSON body; the Confluence listings render TSV.** The two differ, and aligning them would change a shipped operation's output.

## The Confluence space listing

- space-list lists the spaces an acting member's own credential can see, as `SPACE_ID`/`KEY`/`NAME`/`TYPE`/`STATUS` TSV on stdout. All three families carry it, each `<team-member> [--cursor <value>]`, over `--intern-op-atlassian-confluence-space-list`.
- **`/wiki/api/v2/spaces` is the endpoint, the same one `page-create --space` already resolves a space key against** — one path to the space facts rather than two. The operation returns the site's own rows and resolves nothing itself, so it adds no second key-to-id path. v1 `/wiki/rest/api/space` is not used.
- **This endpoint terminates, unlike `page-search`.** `_links.next` is present while pages follow and absent on the last one, so the operation states `more: yes` with the cursor to continue, or `more: no` as a real confirmation rather than the `more: unknown` its sibling reads must give. Measured at both ends against `ndm.atlassian.net`: 194 spaces over 8 pages of 25, the last page short at 19 and carrying no next link.
- **The cursor passes through verbatim in both directions.** It arrives already percent-encoded inside Atlassian's own next link, so it is neither re-encoded on the way back in nor repaired — re-encoding would double-encode the padding it ends in.

## A classification keys on structure, never on message text

- **What a branch decides on is structure**: an exit code, a field's presence, a status, a shape. Message text is the last resort, and where it is the only thing available the match is exact and anchored, never a phrase that happens to appear.
- **A generator dies where it cannot derive an answer.** Emitting something that merely looks right is the worse failure, because the next reader has no way to tell a derived answer from a guessed one.
- The evidence this came from: three separate instruments each searched the Atlassian layer for its own phrasing of a failure, and all three missed the same line — issue-read's description-read failure, which says a field "could not be read" and names two possible causes. Its wording overlaps other arms' failures without matching any one search. Had a branch been keyed on a shared phrase instead of on structure, issue-create would have been handed another operation's variables and would have refused every call.
- The same rule already runs in the code: `sprint-list` decides on the board's own features rather than on the sprint endpoint's error text, because that text is localised. A classification that reads text inherits every language the site speaks.
- **The same fault one level up: a landing whose SCOPE was selected by text is correct in everything it touches and silently wrong about what it omits.** No review of the diff catches it, because what is missing is not in the diff. A sweep scoped by the phrase "syntax is" selected 40 refusal sites; keying on the guard instead finds 126 absence-guarded error lines across the same eight files, and the first of the missing ones sat four lines from a site the sweep did find, same class, invisible for lack of that phrase. A partial change is fine where its boundary is one a later editor could state — a file, a family, a subsystem. "Matched a phrase" is not such a boundary, and it decays the moment someone edits by copying the line above.

## A separator states the quantifier: `/` is all of, `|` is exactly one of

- **`|` means one of, everywhere.** Every syntax line in this package already reads that way — `<upsert|append|remove>`, `(--space <key>|--space-id <numeric-id>)`, `GET|POST|PUT|DELETE` — and the help says so in its own words, that a bar-separated group is a required choice of exactly one.
- **`{` `}` means at least one of, and is the third form.** A brace group separated by bars states that one or more of its members is required — any number of them, but not none — which neither other form can say: square brackets make each member independently optional, so a call carrying none of them reads as legal, and a parenthesised bar group demands exactly one. `--member-comms-slack-profile-set` is the case that needed it: its code refuses a call carrying none of its eight flags, and until this form existed its syntax line stated that call was allowed. Where a member of a brace group carries its own value alternation, that alternation takes the parenthesised form — `--presence (auto|away)` — so a bar inside the group is never read as a group separator. Recorded from the human-owner's ruling of 2026-09-15, not derived by this team.
- **A set where every member is required is joined with `/`**: `JIRA_SITE/JIRA_USER/JIRA_API_TOKEN missing`. That is what three other credential paths already print — `TRELLO_KEY/TRELLO_TOKEN`, the email triple, the Google triple — and it collides with nothing. Joining such a set with bars says the opposite of what it means, and nothing in the line tells a caller which reading was intended.
- Both mistakes have been live, which is what makes the rule worth writing down rather than assuming. The not-configured line once joined three credential values with bars where all three were wanted, and now prints them with slashes. The inverse is still there: `page-update`'s all-required refusal says "one of `--body-storage`/`--body-storage-from-stdin`/`--body-storage-from-file`", using slashes for an alternation, and it moves to the bar form with the rest of that wording work.

## A numeric input is refused, never coerced

- **A value that should be a number is checked where it arrives and refused when it is wrong**, by `AgentsToolsAtlassianAssertNumber`, which names the field and prints what it got. Repairing it silently hides the caller's mistake and sends something the caller never wrote.
- The habit to watch for, measured: the Atlassian stub families validate no numbers at all — every numeric refusal in this layer lives in the internal operations. The one place a stub file touches a number chooses silence: a malformed Slack page maximum becomes 20 with nothing said, which is safe only because that default happens to be safe.
- What the posture cost: four Confluence operations accepted a non-numeric page id, URL-encoded it and sent it to the client's own site, until each was given an explicit refusal. A default that hides a bad value and a value forwarded unchecked are the same decision; only the second announces itself.

## A control must be able to fail the way the real check would

- **A result that matches the expected class is still asked to justify itself.** The failure mode this exists for is not a wrong answer; it is a right-looking one that was never interrogated, and it survives precisely because it agrees with what was expected.
- **A control belongs on the exact construct under test** — the bracketed class, the wrap join, the zone of a timestamp, the family whose refusal text differs — not on some nearby thing that happens to be present. A control that cannot fail where the check would proves only that the tooling ran.
- **A count of zero across every group is read as a broken pattern** until something proves otherwise, and a claim about what a file says is read from the file rather than searched for as a remembered phrase.
- The day this came from: four instruments, four people, four tools, one shape. Probes returned a shell's not-found code nine times while the check reported the expected reduction; a transform emitted plausible output where it could not derive an answer; a board item was filed by its code and mark without its text being read; and a comparison passed because both sides were equally broken.
- The case that shows this is not bookkeeping: a caller holding two of three credentials was told all three were missing, and every instrument that looked at that line had all three unset, so not one of them could see it. The defect was invisible to the whole toolchain at once, because every tool agreed with every other.
- **A search that finds nothing, its own control included, is void rather than clean.** The control runs first, and its silence voids the run: a traversal that hit an argument limit, skipped a symlinked directory or pointed at the wrong root produces exactly what an empty tree produces. A run whose control said nothing is discarded and repeated, never reported as a clean result.
- **A pattern is an instrument, and it is proven against a known instance before its count is trusted.** It has to match the thing meant rather than a word sitting near it, and it fails in both directions: too narrow gives a false zero, as a sweep for refusal wording did when it missed a numeric test that prints nothing; too loose gives a false hit, as a search for "retired" did by matching an unrelated upload passage. The false hit is the dangerous one, because it agrees with the hope — that search existed to find meanings a landing had dropped, and trusting it would have reported the one meaning genuinely lost, a 410 naming a retired endpoint, as already documented.
- **A set is stated by its members, and its count is derived from them in the same breath.** A list and a total are two instruments describing one thing, and carried separately they drift with neither looking wrong: the list reads complete because it is a list, the total reads authoritative because it is a number, and nothing in either says the other disagrees. One sweep's sites were reported as nine and enumerated as eight, the missing one surfacing only when a third reading compared the two — which is where a missing member costs most, because it reads as scope rather than as a defect. A number arriving from anywhere but the enumeration is a separate claim and carries its own check.

## The Atlassian layer's exit-code convention: fault versus designed refusal

`sh-lib/AgentsTools.InternOpAtlassianCall.include`'s shared `AgentsToolsAtlassianCall` classifies every non-2xx outcome under the fault-versus-designed-refusal split this file's own "Severity marks, and where a designed refusal gets lost" section states in general (`⛔ ERROR` for a fault, `🙋 WARNING` for a designed refusal). This section is that split applied to this one layer's own numbering — scoped to the Atlassian transport alone, not a package-wide exit-code convention.

- **Faults ⛔**: `1` a contract error, caught before any call is made; `3` no usable answer — the transport failed, the body could not be read, or the site answered `3xx` or `5xx`; `4` the credential was rejected (HTTP 401). A `5xx` sits here deliberately: it is an answer, but not an answer about whether our write applied, which is the question `3` exists to flag. This `3` is the transport's own; `sh-lib/AgentsAtlassianJsonObjectMerge.py` also exits `3`, meaning a forbidden key, and that is a different producer.
- **Designed refusals 🙋**: `5` conflict (HTTP 409, a stale precondition); `6` not configured, the acting member holds no credential for this product; `7` forbidden (HTTP 403), the credential was accepted and this account is refused on that content; `8` not found or invisible (HTTP 404), which Atlassian returns alike for a genuinely missing resource and one this account cannot see; `9` the site answered and refused — every other `4xx`, `410` included — and no retry of the same request changes it.

**`9` narrows what `3` catches, and a caller branching on `3` has to move.** `400`, `410`, `422` and `429` returned `3` until this landing and return `9` now, so code branching on `3` to catch an unclassified refusal stops catching those four and must branch on `9` instead. `3` keeps only the outcomes where no usable answer came back at all. No caller in this tree branched that way — measured across the devops and skills trees — so the exposure is entirely outside it, which is why it is stated here rather than left to be discovered.

`5` already carried its meaning before `6`/`7`/`8` existed; those three were additions rather than a renumbering, and that statement covers them alone. `9` is not covered by it: `9` adds a code and takes four statuses off `3`, which is a reassignment for those four however additive the list looks. How `403` and `404` were classified before `7` and `8` existed is not established by any record this file can point at, so nothing is claimed about it here.

**A failure is one line on stderr**: the mark, the operation's own name, the status, and the site's own body verbatim. There is no composed headline and no per-code trailer — a caller reading a failure reads what the site said, not a sentence written here about it.

**One branch settles the mark and the code together.** An HTTP status the layer classifies by name carries its own code: 401 is `4`, 403 is `7`, 404 is `8`, 409 is `5`. Every other `4xx` takes `9` and the `🙋 WARNING` mark from the same arm, and everything else takes `3` and `⛔ ERROR`. Until that arm existed the mark came from a nested case while the code came from the outer return — two derivations of one outcome, which is how a warning could carry a code meaning the outcome was unknown. Collapsing them moved exactly four statuses: `410` from `⛔`/`3`, and `400`, `422` and `429` from `🙋`/`3`, all to `🙋`/`9`. `410` lost its own arm and kept its message; `401`, `403`, `404` and `409` never moved.

- **Purely additive, and that was the deciding constraint.** Checked directly: one place compares this transport's own rc to a literal number, `page-update`'s `if [ "$confPURc" = "5" ]` in `sh-lib/AgentsTools.InternOpAtlassianCall.include`, which gives HTTP 409 its own conflict handling. Every other call site, the stubs included, propagates `-ne 0` verbatim. Renumbering the existing codes to fit `6`/`7`/`8`, or `9` after them, in a tidier position would have broken that arm. Adding each above the existing set did not touch it.
- **`6`, not `5`, for "not configured."** `5` was left alone for the new not-configured case because it already meant something else outside this layer too: `AgentsTools.InternOpAgentSpawnProxy.include`'s own console spawn returns rc 5 for "no external CLI is selected in this workspace" and reports it as `SETUP_STATUS=cli-not-configured`, a value this package's own spawn-proxy code already consumes. Reusing `5` for the Atlassian layer's own not-configured case would have put two unrelated meanings on one number in the same package; `6` carries no such collision.

**`7` (forbidden) is implemented and not yet exercised against a live 403.** Confirming it needs either a write against a resource the acting credential is not permitted on, or a specially-permissioned resource to read against — and a write against the client's own production Atlassian is out of scope for this package's own testing. Treat `7` as designed, not verified, until a real 403 has been observed and recorded.

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

## `.claude` is the primary of the three install names

- `--install-skillset-symlinks` fans one member set into `.agents/skills`, `.github/skills` and `.claude/skills`, and the three are not equals: `.claude` is the primary.
- Rules and hooks live under `.claude`. The other two carry the member set and nothing besides it.

## Hooks are generated here and wired by the user

- **A hook binds every agent on the machine, not only team members.** Wiring one is therefore the user's own manual decision.
- We generate hooks. We never register them. **An op that silently wires a hook is a defect**, whatever the hook does.
- `--install-workspace-integrations` passes an empty hooks list, and `--install-workspace-restrictions` is not called. That is the settled state, not a gap to close.
- **A deny hook keeps every external binary out of its decision path.** The binary's absence turns the decision into allow: empty stdout and exit 0 read as permitted, so a hook that shells out to a parser denies nothing on any machine lacking it. Decide from shell builtins alone, and fail closed on anything unparsed.
- **The `PreToolUse` hooks this estate wires are ROUTERS, and the denial is the redirect.** Each one refuses with a reason naming where that work belongs instead: `Bash` wholesale, whatever the command would have run, saying to use the myx.distro MCP tooling; a `MEMORY.md` read, saying to read the workspace, repository and project `MAGIC.md`; a `MEMORY.md` edit, saying to call `magic-librarian`. Reading them as a security boundary is how a reader ends up hardening something that was never a wall — the `Bash` hook denies every command alike, discarding the payload without reading it, which is what a router does and what a boundary would not. **What they route is a claude/copilot-native session**, which has to be sent to the MCP tooling; this harness is not one and reaches that tooling directly, so the absence of a route here is not the absence of a guard.
- **A tool nothing routes receives no routing, which is coverage the router does not yet have rather than a guard that failed.** `Skill` is currently such a tool, in both halves of the mechanism: no configured matcher names it, the matchers being `Read`, `Bash` and `Edit|Write`; and `AgentsHarnessHooksRefusal` shapes a `tool_input` per tool, so a tool with no arm of its own falls to `*)` and is handed its own parameter names — `Skill` presents `name`/`file`/`list` and no `file_path`, so a matcher naming it tomorrow and reading `.tool_input.file_path`, the shape these hooks use, would still find nothing to route on. Routing a newly added tool therefore takes both: a matcher naming it, and an arm emitting the field the routing reads. Whether `Skill` should be routed at all is a design question and is not settled here.

## `--install-skillset-symlinks`: what a failed discovery is, and what an empty one is

- The op links two member sets: the bundled one, and the one workspace projects declare. `AgentsToolsInstallScanMembers` reports on the second with two independent flags, and they answer different questions. `scanDiscoveryTrusted` asks whether the absence of a member may be acted on, and drives removal. `scanDiscoveryError` asks whether something went wrong, and drives the exit status.
- **A selection that succeeded and came back empty sets only the first.** The selection call passes `--select-all` and no input-spec flag; it exits 0 with no output for a workspace with no distro projects, and with no project there is no project declaring a member, so nothing was left undone and the op exits 0. Reporting 1 there made a workspace of that shape unable to complete `--install-workspace-integrations` at all, since that op tests this one with `||`, and through it `--owner-setup-<domain> --apply`.
- **Removal still stays suppressed on an empty selection**, because empty is not reliably "no projects": a project whose namespace carries no `repository.inf` is never scanned, and the result is indistinguishable from a genuinely empty tree. So the run links and never removes, and says so.
- **A genuinely failed discovery still exits 1** — the selection tool exiting non-zero, the declares tool exiting non-zero, a malformed declare, a declared member whose skillset directory is missing. Each of those leaves real work undone, which is the case fail-closed exists for.
- The empty selection is never handed to `ListDistroDeclares --select-from-env`, which refuses one: calling it anyway printed that tool's own `⛔ ERROR` on a run that is not an error.

## Reaching a `List*` tool from this package

- The form is `Require <Tool> || :`, then `Distro <Tool> <args>`. Take the result as `var="$( … )" || status=$?`, which keeps `ListDistroDeclares`' own internal `set -e` inside the substitution subshell instead of leaking it into the caller.
- Never spawn `ListDistroProjects.fn.sh` or `ListDistroDeclares.fn.sh` by path. A spawned process starts with no index environment and rebuilds every index it touches; the mechanism is in `myx.distro-system`'s own `MAGIC.md`.
- **An `MMDAPP=` prefix on such a call is checked before it is dropped, never assumed.** Where the arm resolves through the distro context the prefix is a self-assignment no-op; where the arm reads `$MMDAPP/...` directly it is load-bearing. `DistroSourceTools --list-namespace-roots` reads `$MMDAPP/.local/roots` and is the second kind.
- `$workspace` is `${workspaceArg:-$MMDAPP}` in both the permissions and the symlinks op, so with no `--workspace` flag an `MMDAPP="$workspace"` prefix assigns a variable to itself. No caller in this workspace's own `source` tree passes `--workspace` to either op.
- This package is the family's known-drifted one and is never cited as precedent.

## The workspace list is machine data, and this repository is public

`~/.claude/skills/<name>` is a symlink into the working tree of whichever repository publishes that
skill, so a write to `$HOME/.claude/skills/<name>/…` is a write into that repository. For this package
the repository is `git@github.com:myx/myx.distro-agents.git`, which is public.

The `--owner-workspace-*` ops maintain the human-owner's tracked workspace paths: absolute paths on one
machine, belonging to that machine rather than to any package. They keep that data at
`$HOME/.claude/skills/.human-owner.workspaces.md`, beside the skill symlinks rather than inside one.
`.linked.magic-team.members.txt` sits there for the same reason — both are local, machine-specific,
read by the tooling, owned by no package.

The rule the two share: data an op maintains lives beside the symlinks, and the folders behind them
hold package content. `.gitignore` carries
`skillset/magic-team/human-owner/human-owner.workspaces.md` so the packaged path stays free of it.

## The universal harness, the wire adapter, and a provider stub

**Three layers, and the rule that decides which one a thing belongs in.** A value that would have to
CHANGE to point at another vendor is a *specific* and lives in a stub; behaviour that would stay the
same across vendors is *logic* and lives in the core; anything whose SHAPE is fixed by an endpoint's
request/response schema is *wire* and lives in an adapter. The endpoint, the host named in a refusal,
the credential variable names, the tier models and a harness's own self-name are specifics. The round
cap, the access-root enforcement, the tool implementations and the retry policy are logic. Reading
`choices.0.message.tool_calls.N.id` is wire; capping a tool result at a fixed byte count is not — that
is policy, and it stays in the core.

- **`sh-lib/AgentsUniversalHarness.sh` is the core, and it is never invoked directly.** It holds the
  whole request/tool-call/response loop and the provider-independent functions behind it. A stub sets
  the `HARNESS_*` variables and `exec`s it — `exec`, not source, so the core BECOMES that process: the
  console still launches one path and gets one process, and `$0` resolves to the core's own directory
  for its sibling `.awk` lookups.
- **A stub holds one provider's specifics and nothing else.** It names its endpoint, its host, its
  credential variable names, its tier→model table, its wire and its own self-name, then execs the core.
  `AgentsScalewayHarness.sh` is the worked example; `AgentsAnthropicStub.sh` is the deliberately
  non-working one.
- **The stub keeps the invoker's filename, and the core is the new file.** The console resolves the
  `scaleway` CLI name to exactly `sh-lib/AgentsScalewayHarness.sh` — `DAGC_SCALEWAY_HARNESS` in
  `AgentsConsoleShellScript.template.sh`, which is both what `DagcCliPresent()` existence-tests and what
  `exec` reaches for — and `--owner-setup-scaleway`'s install-probe tests that same path. So the split
  is invisible upstream: one invoker, one process, and nothing outside had to learn it happened.
- **`HARNESS_WIRE` NAMES a wire; it does not implement one.** The core sources
  `sh-lib/Agents${HARNESS_WIRE}Wire.sh`. Scaleway's stub says `OpenAiChat` and resolves to
  `AgentsOpenAiChatWire.sh`; Anthropic's says `AnthropicMessages` and resolves to a file that does not
  exist yet, which is that stub's own declared gap.
- **`HARNESS_TOKEN_EXCHANGE` names an exchange adapter the way `HARNESS_WIRE` names a wire, and is
  optional.** Whether a credential is spent directly or traded first changes with the vendor, so it is a
  specific. Empty or unset means the stored credential is itself the bearer, and the no-exchange path
  runs no new code. Set, it is a bare name resolving to `sh-lib/Agents<Name>Exchange.sh`, sourced like a
  wire. What that file owes — its one function, what reaches it and what it prints — is stated at the
  core's own source site, beside the line that sources it. No adapter ships today.
- **An auth-class refusal is the one complete error body the stream loop retries, and only on a stub
  that exchanges.** A complete, non-streaming error body is otherwise never a disconnect and is never
  retried. Where an exchange is declared, such a body drops the cached bearer and re-exchanges on the
  next attempt, inside the existing three-attempt bound: on that path, only a bearer that has died
  mid-run produces it.
- **`HARNESS_EXTRA_HEADERS` carries complete header lines, one per line, and is optional.** Empty or
  unset adds nothing. Each line is checked at startup rather than at the first request — non-empty, a
  colon, no carriage return — because curl sends a header line verbatim, so a malformed one returns a
  refusal that reads exactly like an auth failure. The lines ride the existing `-H @-` stdin channel, so
  nothing moves to argv, and the core adds `Content-type` itself without checking whether a declared
  line repeats it.
- **A wire is shared by every provider speaking it, which is why it is not a provider file.** Scaleway,
  self-hosted DeepSeek and (as documented rather than confirmed on the wire) Copilot all speak the
  OpenAI chat-completions shape. A copy of the adapter per provider would reintroduce, at a coarser
  grain, exactly the duplication this split removes.
- **A stub names its own specifics and must not grow into a selector.** The fence is written into the
  Scaleway stub itself: the thing that CHOOSES between stubs — a registry, a known-CLI list, a preset
  selector — is separate, unbuilt, and deliberately out of scope. If a selector starts being written in
  a stub, that is the signal to stop, not to continue.

**Where the reasoning lives, rather than restated here.** Four things are documented at their own site,
and that site is the source rather than this file. Each is the provenance of a declared value rather
than an explanation of code, which is what earns it more room there than a comment usually gets:

- **The tier table and its justification** live in `AgentsScalewayHarness.sh`, carried over with their
  evidence under the heading **"THESE MODEL NAMES ARE OBSERVED, NOT DOCUMENTED"**. The table is in the
  stub and not in the core because two stubs cannot share one — Anthropic's tiers name different models
  and read a different credential, so a table in the core would be one provider's table pretending to
  be everyone's. The core keeps only the SHAPE of the mapping.
- **The `AgentsWire*` roster** — the functions the core calls, which any second adapter must define —
  is item 7 of `AgentsAnthropicStub.sh`'s constraints block, where whoever writes that adapter already
  stands. It records that an adapter omitting one fails at the CALL rather than at load, with no check
  that catches it, and it instructs the reader to re-derive the set from the core's call sites rather
  than trust the list. Treat it that way: it is dated, and nothing verifies it.
- **`AgentsOpenAiChatWire.sh` is the first dot-sourced `.sh` in this tree.** It carries the
  `# ^^^ for syntax checking in the editor only` marker that the dot-sourced files in `sh-lib` carry,
  and its own header states plainly that adopting it here is SETTING a convention for a new file kind
  rather than following an established one — `sh-lib` holds five `.sh` files and four are this split's
  own output, so "it matches its siblings" is close to circular.
- **The Copilot stub's model ids, and why both its optional knobs are empty**, live in
  `AgentsCopilotHarness.sh` — the ids under the heading **"THESE MODEL IDS ARE ANCHORED BY ELIMINATION,
  NOT BY MEASURED CAPABILITY"**, the knobs in the comment above them. Same reason as the tier table:
  nothing else records where a declared value came from, so it is kept beside the value.

**A second stub exists and does not run.** `AgentsAnthropicStub.sh` is structure with named gaps: it
refuses to run and lists them. It is deliberately non-working because no field name in it could be
confirmed on the wire, documentation-derived names are already wrong on one model in use, and lifting
names from a neighbouring parser was refused as a shortcut. Honest and non-working beats plausible and
wrong, and its constraints block records what the missing adapter has to satisfy.

**A third stub exists, is complete, and has never been exercised.** `AgentsCopilotHarness.sh` declares
GitHub Copilot's endpoint, host, wire, credential name and both tier models, and declares both optional
knobs above as empty. Nothing in it refuses to run, and no request has been made to
`api.githubcopilot.com` from this package, so every claim about what that endpoint accepts is still
documentation-derived.

- **It is declaration-complete, and the leg is credential-blocked.** Every required value is declared,
  both model fields among them, and the two optional knobs are declared empty. The stub does not refuse,
  as said above — the core does. `HARNESS_TOKEN_LIGHT`/`HARNESS_TOKEN_MAIN` are
  `"${COPILOT_GITHUB_TOKEN:-}"`, so with that name absent from the process environment the core's own
  credential gate fires and exits 1 at `AgentsUniversalHarness.sh:392-395` before a socket is opened.
  That gate, not an untried experiment, is why no request has been made.
- **Whether an exchange is needed here is open, and one observation settles it.** GitHub's published
  extension sample calls this endpoint with a bearer and a content type and nothing else, and performs
  no exchange — but an extension is handed a token its platform mints for that request, and a stored
  `COPILOT_GITHUB_TOKEN` is a different credential. The sample and a requires-an-exchange premise can
  both hold, of two different tokens, so the empty declaration is the starting position rather than a
  finding. One real round with the stored token decides it: an auth-class refusal means an exchange is
  required here, a completed round means it is not.
- **It sets no context budget.** `HARNESS_MODEL_CONTEXT_TOKENS` is absent, so the core's own floor
  applies. Deliberate, for want of a published window for these models; whether that floor suits them
  is unsettled.
- **The console does not route `copilot` to it.** `DAGC_CLI_EXEC` maps `copilot` to the vendor binary
  of that name, and nothing resolves the stub. Routing is a separate change, held until this one is
  confirmed working against the endpoint.

That Copilot speaks the OpenAI chat-completions shape **as documented rather than confirmed on the
wire** is not changed by this stub existing, and stands until a real round confirms it.

## `AgentsScalewayHarness.sh` — the Scaleway stub, and why scaleway is not a fourth CLI

`scaleway` (`DAGC_KNOWN_CLIS`, `--owner-setup-scaleway`, `DAGC_CLI_CREDENTIALS`) is a fourth agent-spawn
backend alongside `claude`/`copilot`/`grok`, decided in the backlog's own "Scaleway as a fourth agent
spawn service" entry. Unlike the other three, there is no real `scaleway` binary: Scaleway's own
Serverless Generative APIs are a bare
`POST https://api.scaleway.ai/v1/chat/completions`, so this package *is* the CLI —
`sh-lib/AgentsScalewayHarness.sh` is the stub the console execs, and it execs
`sh-lib/AgentsUniversalHarness.sh`, which runs the whole request/tool-call/response loop itself using
the exact curl `-H @-` bearer-stdin pattern `AgentsTools.CommsSlack.include` already proves. Sandboxing
is the core's own access-root check, plus the `PreToolUse` hooks `AgentsHarnessHooks.sh` consults before
each tool call where the workspace configures any — fail-closed, so an unreadable hook configuration, a
hook that does not complete, and an answer the harness cannot read each refuse the call rather than
permit it. Beyond those, copilot's `--allow-all-tools` trust model, not a gap this closes.
Context-window management is summarise-and-restart at `MDAT_HARNESS_CONTEXT_TOKENS`, bounded by
`MDAT_HARNESS_MAX_RESTARTS` (see below), so a long enough run now ends on that restart budget rather
than on the model's own context limit. Never a silent one.

**Research on making this harness universal is recorded elsewhere, not here.** The human-owner's TODO of 2026-09-15 — one common UHP + MCP harness for all spawning, covering Scaleway/DeepSeek, Anthropic/Claude and GitHub/Copilot spawners, hooks, visual output and checkpoint/rewind — is held as board item `task-20260915T0924Z-common-uhp-mcp-harness-for-all-spawning.md` (backlog), and the measured research from four seats is written up in the backlog document's `### Context Detail — 2026-09-15 session (harness research, measured)`. **That Context Detail entry is canonical for the research; this file documents the code, and documents that subject when something is built.** The plan drawn from it, with its subtasks and the open questions they are blocked on, is in two further entries of the same date — `### Context Detail — 2026-09-15 session (harness planning, measured)` and `### Context Detail — 2026-09-15 session (session lessons)`. **What has since been built is the universal/stub split described in the chapter above, and the fail-closed `PreToolUse` hooks that chapter names, and this file documents them because they exist.** The rest of that TODO — the MCP surface, checkpoint/rewind, and spawning across the five execution classes — is not implemented, and stays in those entries until it is. This file documents a part when it is built, never when it is planned.

**Future plans, in outline only — the detail and its attribution live in the Context Detail entries above, which are the main source.** Decisions an implementer would otherwise collide with: checkpoint/rewind is cheap, the conversation being one serialisable array rather than scattered state; visual output is a merge of two working implementations rather than new work; hooks are built — `sh-lib/AgentsHarnessHooks.sh`, fail-closed, per the chapter above; and the tool surface is the gap: the harness implements `Read`, `Write`, `Edit`, `Glob`, `Grep`, `Bash` and `WebFetch`, implements `WebSearch` against the keyless DuckDuckGo Instant Answer API chosen by the human-owner — which is an instant-answer service rather than a web-results index, and answers a query naming one thing while returning nothing at all for an ordinary multi-word question (measured 4 of 4 named things, 0 of 10 realistic multi-word queries), so whether it is acceptable as a general web search is his open ruling and not a defect of this implementation. `list_dir` no longer exists: it was a plain `ls -la` matching no patterns, and it was folded into `Glob`, which tests its root before evaluating the pattern so that a missing directory stays distinguishable from an empty match, and keeps a `long` argument so the fold dropped no capability. `Edit` was added as the partial-edit primitive, so `Write` is no longer the only way to change a file. These are decisions drawn from that research rather than measurements, and their evidence and attribution live in those entries — measurements as measurements, judgements as judgements. This file is not the main source for any of it.

**Service facts the harness is written against.** The endpoint is OpenAI **Chat-Completions**-compatible
and supports `stream:true` (SSE), `tools` and `tool_choice`. There is **no Responses API**, and that
consequence reaches past this package: the Codex CLI cannot target Scaleway at all, having dropped
`wire_api = "chat"` in favour of Responses. Unsupported request parameters, which the harness
therefore never sends: `frequency_penalty`, `n`, `top_logprobs`, `logit_bias`, `user`. Model IDs are
bare and carry no slash prefix. A key is scoped by Project and policy rather than by model, so one key
reaches every model that Project serves — `Help.DistroAgentsTools-setup-scaleway.help.md` states that
last half for the setup reader.

**One harness ships, and it streams.** The earlier blocking implementation and its
`AgentsScalewayHarnessV1.sh` file are deleted, on the human-owner's own word. Nothing in this package
references them and no variant selection remains, so anything below describes one code path rather
than a default and an alternative.

**`MDAT_SCALEWAY_HARNESS` survives and has a different job now.** It repoints
`DAGC_SCALEWAY_HARNESS` at a CANDIDATE harness — a bare filename in `sh-lib`, or an absolute path, with
a relative path refused for a stated reason (it would resolve against `$MMDAPP` rather than against
anything the caller named), then checked for existence and for the execute bit. Unset, the console
resolves the stub's own plain path. `--owner-setup-scaleway`'s install-probe and
`AgentsToolsSpawnCliPresent` both test that plain default name and deliberately do not follow the
override: they ask whether the release reached this workspace, not which file a run selects.

- **Standalone by design, not sourced.** Every sibling `Agents*.include` is dot-sourced into
  `DistroAgentsTools` and resolves its neighbours through `$MDLT_ORIGIN`. This script is executed
  directly (`#!/usr/bin/env bash`, its own `set -e`) and resolves its sibling `.awk` helpers from its
  own `$0`'s directory instead — the natural mechanism for a standalone script, and the one
  `AgentsConsoleShellScript.template.sh` itself uses to find `$MMDAPP` at its own startup. It reads its
  own credential names directly out of its process environment (`SCALEWAY_DEEPSEEK`/`SCALEWAY_GEMMA`),
  exactly as `claude` reads `ANTHROPIC_API_KEY` itself — it never resolves `--agents-config-option`
  itself, and is fully testable by hand with nothing but those two variables and an access root.

- **Two credentials, not one, and neither is model-exclusive.** The backlog's own working name for the
  single credential (`SCW_SECRET_KEY`) was superseded once real keys were provisioned as
  `SCALEWAY_DEEPSEEK`/`SCALEWAY_GEMMA`. Live-tested against the real API, cross-matrixed (both keys ×
  both models, four calls): every combination succeeded. Scaleway scopes a secret key by Project+policy
  (`GenerativeApisFullAccess`), not by model, so the two names are which tier *prefers* which key, with
  the other as a real fallback (`${SCALEWAY_GEMMA:-$SCALEWAY_DEEPSEEK}` and its mirror) — never an
  enforced restriction. `DAGC_CLI_CREDENTIALS="SCALEWAY_DEEPSEEK SCALEWAY_GEMMA"` follows claude's own
  two-alternatives shape (`ANTHROPIC_API_KEY CLAUDE_CODE_OAUTH_TOKEN`) for exactly this reason.

- **Model tiers, Scaleway-specific, not the general `custom-spawner-models` framework — mapping
  REVERSED from the first cut, on measured evidence, not on what the model names sound like.** The
  first cut mapped `light` → `deepseek-v4-flash-0731` and `normal`/`heavy` → `gemma-4-26b-a4b-it`,
  reasoning from the ORIGINALLY-DECIDED (nonexistent) `google/gemma-4-31b-it:bf16` — a dense 31B model
  that really would have been the heavier of the two. That model does not exist on this API (see
  below); the live-confirmed stand-in, `gemma-4-26b-a4b-it`, is not dense — the `a4b` suffix is real and
  means something. Independently confirmed (Scaleway's own supported-models/pricing page, cross-checked
  against Artificial Analysis's benchmark comparison of these exact two ids):
  - `gemma-4-26b-a4b-it`: 25.2B total parameters, Mixture-of-Experts, only **3.8B active per token**
    (128 experts). Scaleway price: **EUR0.25/EUR0.50** per million input/output tokens. Artificial
    Analysis Intelligence Index **17**.
  - `deepseek-v4-flash-0731`: 284B total parameters, MoE, **13B active per token** — ~3.4x Gemma's
    active count despite "flash" in the name. Scaleway price: **EUR0.40/EUR0.80** per million
    input/output tokens (EUR0.08 cached-input). Intelligence Index **35**, and well ahead on
    coding/agentic benchmarks (GDPval-AA v2 1468 vs 713; AA-LCR 80% vs 66%).
  Every measure agrees in the same direction: gemma is the genuinely lighter, cheaper, less capable
  model; deepseek is the substantial, more expensive, more capable one — the opposite of what "flash"
  suggested and exactly the inversion the task instructions predicted. Corrected mapping, same
  structural idea as before (one model alone for the cheap tier, the other model's own
  `reasoning_effort` split covering the top two tiers), roles swapped: `light` → `gemma-4-26b-a4b-it`
  at default reasoning; `normal` → `deepseek-v4-flash-0731` at default reasoning; `heavy` → the same
  DeepSeek model with `reasoning_effort:"high"`. Live-confirmed against the real API post-swap,
  including the one combination nobody had tried before (`deepseek-v4-flash-0731` +
  `reasoning_effort:"high"`, the new `heavy`) — accepted, no error, correct reply. This is `--tier`, a
  flag the harness itself resolves; it is not the cross-service `light`/`normal`/`heavy` selector
  framework the backlog's separate `custom-spawner-models` item describes (unbuilt, unscoped) —
  building that generic framework here would be answering a different, larger, not-yet-decided
  question.

- **The decided Gemma model id does not exist.** `google/gemma-4-31b-it:bf16` (and
  `deepseek/deepseek-v4-flash-0731`, slash-prefixed) were the backlog's own working ids. A live
  `GET /v1/models` (both keys, identical listing) returns bare, unprefixed ids only, and the Gemma
  family's actual live entry is `gemma-4-26b-a4b-it` — a different parameter count and a different
  architecture suffix than what was decided, not a spelling difference. This is flagged back rather than silently kept or silently swapped; `gemma-4-26b-a4b-it` is wired in
  as a clearly-commented, live-confirmed-working stand-in (tested through the full harness, all three
  tiers, not just a bare curl call) pending the human-owner's own confirmation. `deepseek-v4-flash-0731`
  (no slash) is the confirmed, non-provisional id for `normal`/`heavy` (see the reclassification above —
  it anchors the top two tiers, not `light`, once its real active-parameter count and price were known).

- **Tool schemas, OpenAI `tools`-array shaped.** The set itself is "The harness tool set" below.
  `Write` is a whole-file overwrite/create; `Edit` is the partial-edit
  primitive beside it, replacing by exact literal and refusing unless the text occurs exactly once.
  It reads the whole file inside the process and returns only a one-line result, so it is the way to
  change a file too long to read back — which is why the earlier instruction here, that "edit" means
  reading a file and writing back its complete content, was a data-loss prescription rather than a
  limitation. Its uniqueness guard counts occurrences with the same `index()` call that performs the
  substitution, never `grep -c`, which counts matching lines.
  Both of its awk passes take the model's old and new text through `ENVIRON`, never `awk -v`: a `-v`
  assignment is backslash-decoded before the program sees it, so a literal `\t` in text the model asked
  to replace arrives as a real tab and matches a place nobody named. The rewrite emits
  `printf "%s", $0` and re-joins the records on `RS` itself rather than using `print`, which appends
  `ORS` and would leave a file carrying a trailing newline it never had. `Bash` bounds only its own
  `cwd` to the access-root set — the command itself is not sandboxed further, the same trust level
  `--allow-all-tools` already grants copilot.

- **One access-root set, rendered per client in that client's own spelling.** The set is team data the
  installer collects, and `AgentsConsoleShellScript.template.sh` renders it once into whichever flag the
  selected client takes — `--add-dir` for `copilot`/`claude`, `--access-root` for this harness. Every
  client that can be told where it may work is told by the console, on one code path, so there is no
  second reader of the fragment to keep in step with the first. Provenance belongs to that path too:
  `own`/`explicit` are install-guaranteed and trusted, while `wildcard` and untagged lines carry none
  and are existence-checked before they are passed, since a root that does not exist fails the spawn.
- **The harness's own fragment read is a stale-console fallback, and nothing else.** It runs only when
  no `--access-root` reached it, which means a console generated before that leg existed. It therefore
  does not reimplement the console's tagging and must not grow into a copy of it: every line shape that
  format has ever written ends in its own path, so the fallback keeps the text after the last tab and
  accepts it if it is absolute. Its whole job is that an un-regenerated workspace resolves roots instead
  of refusing to run — and resolving none is a refusal, never an empty default.

- **Now wired into the console's own exec dispatch, on a real, live, end-to-end console-level test —
  this was deliberately deferred in the first cut and is now done.**
  `DAGC_KNOWN_CLIS` and the `case "$DAGC_CLI" in copilot|claude|grok|scaleway)` validation arm both
  already took `scaleway`; what was missing was everything downstream of that arm actually running it.
  Three changes to `AgentsConsoleShellScript.template.sh`:
  - `DagcCliPresent()`, a small function defined once near the top, replacing every bare
    `command -v "$DAGC_CLI"`-shaped presence check (the `--cli-auto` scan, the explicit-`--cli` gate, the
    fallback scan) with a call through it. For `scaleway` it tests for the harness file
    (`test -f .../AgentsScalewayHarness.sh`), exactly the shape `--owner-setup-scaleway`'s own
    install-probe already had to adopt for the same reason (`command -v scaleway` can never succeed on
    any machine — there is no such binary to find). For every other CLI it is `command -v` unchanged,
    so `claude`/`copilot`/`grok` presence detection is bit-for-bit the same check as before.
  - `DAGC_CLI_EXEC`, computed once after the CLI is finalized: `scaleway` maps to the harness script's
    own path, every other CLI maps to itself. The three `exec` lines that actually launch a CLI now exec
    `$DAGC_CLI_EXEC` instead of `$DAGC_CLI`; `$DAGC_CLI` itself is untouched everywhere else in the file
    (the `DISTRO_CONSOLE_EXEC=` line, the credential/flag/agent case statements, the warnings), so
    reporting and dispatch never disagree about which CLI was actually selected.
  - A `scaleway)` arm in the `DAGC_NONINTERACTIVE_PERM_FLAGS`/`DAGC_PROMPT_ARGS` case (empty/empty): the
    harness's own arg parser knows `--tier`/`--access-root`/`--` and reads its prompt as plain trailing
    argv or stdin, so the `-p`/`-p --` tokens claude/copilot need would instead be read back as literal
    prompt text — confirmed by tracing the harness's `case "$1" in ... *) break` default arm, which does
    not consume an unrecognized flag.
  - An explicit early guard: `--cli scaleway` without `--non-interactive` is refused with a stated reason
    ("no interactive shape") rather than falling through to a bare `exec` of a name that is not a binary,
    which would have surfaced as a confusing shell-level "command not found" instead of a diagnosed one.
  Also fixed as part of getting this to actually round-trip: the access-root fragment parser bug
  documented in the point above (without it, a real spawn through the console in a workspace with an
  old-format fragment — confirmed to still exist live — would have failed regardless of the dispatch
  wiring).
  `DAGC_NONINTERACTIVE_CLIS` now reads `copilot claude scaleway` — added ONLY after, and because of, a
  real test through the actual console entry point succeeding (see below), never speculatively. `grok`
  stays out of this list on its own, unrelated standing precedent (a real interactive binary, not yet
  proven non-interactive) — the two CLIs are in opposite states and belong in different lists for
  different reasons.
  **Live confirmation, through `./DistroAgentsConsole.sh` itself, not the harness standalone:**
  `--cli scaleway --non-interactive` with the prompt on argv, and again with it on stdin — both
  succeeded, both printed `DISTRO_CONSOLE_EXEC=scaleway`, both returned the correct answer, run against
  a real workspace (mel/prv-farm) with real credentials and its real, live, old-format access fragment.
  `--cli scaleway` without `--non-interactive` was also confirmed to fail cleanly with the new stated
  reason rather than a raw shell error. `claude` and `copilot` dispatch were re-run through the same
  regenerated console immediately after, unchanged in behavior, to confirm `DagcCliPresent`/
  `DAGC_CLI_EXEC` introduced no regression for either.

- **`--session-id <id>` and `--agent <name>`: the same two spawn-proxy exports claude/copilot already took, now
  reaching scaleway too.** `AgentsConsoleShellScript.template.sh`'s `DAGC_SESSION_ID_ARGS`/`DAGC_AGENT_ARGS`
  conditionals widened from `claude`/`copilot`-only to include `scaleway` for both flags, and both are handled
  in the core. `--session-id` only announces the id to stderr as `🔗 session <id>` — scaleway has no external
  hook observer the way claude/copilot run under Claude Code's own instrumented lifecycle, so that line is the
  only "join" this harness can make at all. `--agent <name>` (checked against the same bare-token gate the
  template already applies to `MDAT_SPAWN_AGENT`, reproduced in the core rather than shared since it sources no
  include of its own) reads `$MDAT_SKILLSET_ROOT/<name>/<name>.basic.md` and prepends it as the system prompt's
  real identity, replacing the generic opener entirely rather than standing alongside it — one clear identity,
  not two. The full `.armed.md` is deliberately not inlined — some run to ~48K tokens, the wrong tradeoff
  against this harness's metered, `max_tokens`-capped cheap-tier model — so the model is told to `Read`
  its own `.armed.md` itself, on the same access grant that already lets it reach `.basic.md`. A missing or
  unreadable `.basic.md` is a loud `exit 1`, never a silent fallback to the generic prompt, which would look
  like a successful `--agent` spawn while actually running as nobody in particular.

- **What the live rounds have and have not established, stated rather than inferred.** Two things are
  proved: one live round exercised the wire end to end, and a second proved `Read` against a plain
  path. The symlinked access-root case FAILED and is under repair by the seat that owns it.
  `$MDAT_SKILLSET_ROOT/<name>` is normally a symlink into the member's real location, while access-root
  grants are made against the real, `pwd -P`-resolved path, so the interaction between a symlinked root
  and the core's own path check is exactly the region being worked on. Nothing in this document
  describes that case as working, and this section takes its account from that seat when the repair
  lands rather than filling one in now.

- **`--owner-setup-scaleway`'s install-probe is a file test, never `command -v`.** The shared
  `claude|copilot|scaleway)` declare-args arm still emits `--install-probe "command -v $setupDomain"`
  first (so the three stay one arm, one edit), and `scaleway`'s own declare-args append a second
  `--install-probe` right after it — `test -f .../sh-lib/AgentsScalewayHarness.sh` — which wins because
  `--intern-op-owner-setup` takes the last occurrence of a repeated option. No `--install-command` is
  declared: the harness ships with the package release, so there is nothing an `--apply` installs: an
  absent file means the release has not reached this workspace, not that a package is missing.

- **`AgentsHarnessJsonField.awk` is a new file, not a reuse of `AgentsSlackJsonField.awk` as-is.** Both
  copy the same recursive-descent engine verbatim, the family's own established propagation path for it
  (`AgentsSlackJsonField.awk` ← `AgentsSlackConversationCounterparty.awk` ← `AgentsSlackMessagesFormat
  .awk` ← `myx.common`'s `agentMcpJsonParseRequest.awk`) — this is one more copy in that same lineage,
  not a new parser. The one real difference is deliberate: `AgentsSlackJsonField.awk` hard-requires a
  top-level `ok` key and reports rc 1 without it, because every Slack Web API response carries one and
  its absence means the body is not one; Scaleway's response carries no such key at all (confirmed live,
  both a success body and its own flat error shape, `{"status":n,"error":"CODE","message":"..."}` —
  nothing like Slack's `ok:false` or OpenAI's nested `error` object), so that gate would reject every
  real response and is not present here. It also borrows one feature from a different sibling,
  `myx.common`'s own `agentMcpJsonParseRequest.awk`: a synthetic `<path>.__count` leaf per array,
  emitted whether the array is empty or not, which this reader's own caller needs to iterate a
  `tool_calls` array of unknown length — `AgentsSlackJsonField.awk` has no such leaf because none of its
  own call sites need to.

- **A required response field missing is a stated exit 1, never a bare `set -e` kill.** `id`/`name`/
  `arguments` off a `tool_calls` entry are each read through the wire adapter's own
  `AgentsWireResponseField`, which checks
  the field reader's own rc and, on non-zero (rc 3 absent, rc 1 malformed), prints which field and which
  round before exiting — rather than the assignment `x="$( ... )"` failing silently under `set -e` with
  nothing downstream ever testing it. A model or API returning a `tool_calls` shape this harness cannot
  use is exactly the case this makes diagnosable instead of a bare, unexplained abort.

- **A tool call's `function.arguments` is read by running the same field reader twice.** The outer
  response is one JSON document; `tool_calls.N.function.arguments` is a *string* holding a second one
  (OpenAI's own shape) — parsed once as a string leaf of the outer document (which is also where its own
  one level of backslash-escaping is undone), then fed back into the identical reader a second time to
  pull a named argument (`path`, `content`, `command`, …) out of it. Two passes of one parser, not a
  second one written for nested JSON.

- **Every value rebuilt into outgoing JSON is escaped through `AgentsMcpJsonEscape.awk`, never inserted
  raw.** A tool call's own `id`, `function.name`, `function.arguments` and a tool result's own content all
  round-trip back into the next request's `messages` array — assembled here, not printed by the API — and
  none of the four is guaranteed free of `"` or `\`: a model-supplied argument string or command result
  routinely carries both. Building that JSON by string concatenation without escaping corrupts the next
  request or lets a value's content be read as adjacent JSON structure. The same awk file the MCP wire
  handler already uses for this reason is reused here rather than reinventing it.

- **There is no round ceiling by default, and a round was never the right unit.** A round is one model
  turn; it tracks neither cost nor progress, and every turn re-sends the whole conversation, so turn
  twenty-five costs many times turn one. The native CLIs this harness replaces bound spend directly —
  `claude` takes `--max-budget-usd`, `copilot` takes `--max-ai-credits` — and count no turns at all.
  `MDAT_HARNESS_MAX_ROUNDS` sets a ceiling where a caller wants one; unset means none.
- **A bounded run keeps its work, and exit 3 is what says so.** Reaching a cap appends a closing
  instruction, makes one more request, prints the model's own account of what it did and what is left
  unfinished, and exits 3 — its own status, distinct from a completed run and from a fault, so a caller
  can tell a run that was cut short but reported from one that failed. The conversation lives only in a
  shell array, so a run that aborts instead discards every file read and every command run, and reports
  identically to one that looped from the start.
- **`tool_choice` is what changes for the closing round; `tools` never is.** Turning the tools off is a
  request parameter, not an edit to the declaration. A conversation that already holds tool calls and
  their results refers to tools by name, and a wire that validates those references against the declared
  set refuses the request outright once the array is gone — the Anthropic wire does — so stripping it
  would pass on one provider and fail hard on the next. It is also the fixed literal prompt caching
  depends on (below): the declaration is rendered once and holds for the whole run, cap or no cap.
- **Residual limit: the closing round is a request like any other.** A stream failure reaching it exits
  1, and that run's work is lost exactly as an uncapped abort loses it — the one path the cap exists to
  protect is the one path it does not protect to the end.
- **Spend is recorded, not enforced.** `stream_options:{"include_usage":true}` is sent and the
  usage-only chunk before `[DONE]` is read for the per-round and running totals. Measured on this
  endpoint: every delta chunk carries `"usage":null`, so the gate tests for the object rather than the
  key, and `prompt_tokens_details` is absent on gemma — nothing keys on it.
- **A full context is met by summarise-and-restart, and by nothing else.** With no round cap set by default, a long run walks into the model's own context limit and the request simply fails. At `MDAT_HARNESS_CONTEXT_TOKENS` (default `64000`; `0` turns it off) the leg asks the model to write its own handover, then starts a fresh leg from that handover plus the original task. Nothing is dropped by age and nothing is evicted mechanically: the model judges what is worth carrying, which is the whole reason this shape was chosen over a sliding window.
- **The signal is one round's own `total_tokens`, never the running sum.** Every round re-sends the whole conversation, so the running sum counts the same context once per round and passes any threshold long before the window is anywhere near full. One round's `prompt_tokens + completion_tokens` is what actually sat in the window, and that is what is compared. A restart zeroes it, so the summarise round's own large total cannot immediately re-trip the threshold it was raised by.
- **`64000` is a policy value sized from this file's own caps, not from any model's published window.** Nothing in this package records a context size for either tier model, and a number taken from a vendor page would be exactly the documentation-derived constant the adapter rule above forbids. What is known here is what one round can add: a `Read` result caps at 200000 bytes and `max_tokens` is 8192, so the threshold leaves room for the largest single round that can follow a trip. A later reader retuning it is changing a policy decision, the way `MDAT_HARNESS_RUN_TIMEOUT`'s 900 is one.
- **The cycle is bounded at `MDAT_HARNESS_MAX_RESTARTS` (default 3), and the bound ends the run the way a round cap does.** An unbounded summarise-restart cycle is worse than the failure it replaces: a task that keeps refilling the window is not converging, and each pass costs a whole context of tokens to discover that again. With the budget spent, the threshold raises a closing round instead -- tools off, the model's own account of what it did -- and exits 3, the existing cut-short-but-reported status. No second exit code and no second closing mechanism was added.
- **The original task survives every restart because it is never rewritten.** A restart calls `AgentsWireInitMessages`, which renders `$harnessSystemText` and `$harnessPrompt` -- the same two variables the first leg was built from, both assigned during startup and never inside the round loop. The summary is appended after them as its own user record, framed as the model's own notes rather than as instruction, so what accumulates across restarts is one task plus one summary, never a summary of a summary.
- **An empty summary ends the run at exit 1 rather than restarting onto nothing.** The summary is the whole of what survives a leg, so a summarise step that produced no text has already lost the work; continuing would finish the task on a view missing everything the first leg learned, and report as though it had not. The refusal names the round and the `finish_reason`.
- **Enabled and never fed is said out loud, once.** The threshold can only fire where the wire reports usage. Where a round carries no usage chunk, round 1 prints a warning naming the setting and the fact that nothing here measures the context -- a run that then walks into the model's own limit would otherwise read exactly like one this managed.
- **Residual limit: the threshold is checked between rounds, so one round can still overshoot it.** Several large tool results land in a single request, and that request is either accepted or it is not; the threshold sees the overshoot afterwards. The sizing rule above is what keeps an overshoot landable rather than fatal, and it is a sizing argument, not a guarantee.

- **`Bash`'s output is never captured with `$( ... )`.** A model-supplied command is exactly the
  "arbitrary command" case the "Capturing an arbitrary command's output" section above names: it may
  background a child that holds a capture pipe's write end open forever. Its output goes to a scratch
  file (`mktemp -d -t`) and is read back, and its containment — `( cd ... && set -e && eval ... ) ||
  status=$?` — mirrors `--intern-mcp-execute`'s own `set -e`-containment pattern rather than inventing
  a second shape for the same problem.

- **`Bash` bounds itself, and the shell watchdog is the live path rather than a fallback.**
  `timeout` is used where it exists, `gtimeout` where coreutils supplied it, and neither is in a Darwin
  base system — so on this platform the shell watchdog is what actually runs, and it is written to be
  correct first rather than second. Its `sleep` is redirected with `>/dev/null`, and that redirection is
  load-bearing: an orphaned watchdog otherwise inherits the enclosing function's capture pipe and holds
  its write end open, so every call blocks for the whole timeout bound however fast the command itself
  returned. The bound is a bound on a hung command, never a cost paid by one that finished.

- `MDAT_HARNESS_WAIT_TIMEOUT` (default 600) bounds one `Wait` call, as `MDAT_HARNESS_RUN_TIMEOUT` bounds
  one `Bash` call. Ten minutes is twice the operation's own five-minute default, so a model asking for a
  longer single wait still gets one while no single call holds a run open indefinitely. A long vigil is
  many bounded waits, not one unbounded one -- which is what lets the agent re-decide between them.

- **A per-round tool-call progress line, announced immediately BEFORE the tool call executes, not
  after.** Human-owner's own ask: the harness's tool-execution dispatch had zero stderr announcement
  anywhere in its success path, and real-time visibility into what it is doing matters especially for a
  `Bash` call that might hang. `AgentsHarnessAnnounceTool`, in the core, is where it happens. It
  prints a per-tool icon line (`📖`/`📝`/`📂`/`🔍`/`💻`), with the tool name in a fixed-width colour
  column and the values beside it, under a `── round N ───` rule printed once per round rather than a
  round stamp per call. It also announces the model and tier once at startup
  (`🤖 scaleway <model> · <tier> tier`) and the session id as `🔗 session <id>`. Colour is gated on
  `[ -t 2 ]` + `NO_COLOR` + a real `TERM` (`tput colors` ≥ 8) exactly as `myx.common`'s own
  `lib/catMarkdown.Common` gates its stdout; the emoji are not gated, being printable UTF-8 rather than
  escapes.

  The rule that matters: never `Write`'s own content, only the path being written to,
  and every value — the function name included, since that is model output too — passes through
  `AgentsHarnessTruncateArg` first: collapsed to one line, every C0 control byte and DEL folded to a
  space, cut at 120 bytes (`...` appended), never dumped whole. That control-byte fold is what
  stops a prompt-injection payload arriving as a tool-call argument from forging or moving the
  harness's own chrome.
  `AgentsHarnessTruncateArg` is one line handing the value to `progressLineSafe` — the one
  primitive, in `AgentsProgressLineSafe.awk`, that claude's own progress lines use as well — so
  its cut is UTF-8-boundary-safe in every locale.
  See that file's own section below for why the primitive lives where it does.

## `sh-lib/AgentsProgressLineSafe.awk` — `progressLineSafe`, the one progress-line primitive

**The primitive is its own file, and it is not owned by any spawn service.** `AgentsProgressLineSafe.awk`
holds the `ordTable` BEGIN, `progressLineSafe()` itself, and a standalone stdin mode; every caller loads
it. There are two ways in, and the file's own header states both: `awk -v progressLineCap=<bytes> -f
AgentsProgressLineSafe.awk` renders one value from stdin, which is how the universal harness uses
it; `awk -f AgentsProgressLineSafe.awk -f <rules>.awk` loads it ahead of a formatter that calls the
function, which is how the claude path uses it. With `progressLineCap` unset the standalone rule never
fires, so the loaded rules see every line; when it is set, that rule's `next` is what keeps the line
away from any rules file loaded after it.

**A caller that forgets to load it fails at call time, not at load time.** Calling an undefined awk
function is a fatal exit 2 in gawk and one-true-awk alike, and it is raised when the call executes —
so a stream whose first records do not reach a call runs normally and dies on the first one that does.
Measured on the claude formatter loaded alone: a `system`/`init` record still prints `session started`
and exits 0, while the first `thinking` or `tool_use` record exits 2 with `awk: calling undefined
function progressLineSafe`. Nothing detects this ahead of time — there is no syntax-only mode, and a
dry run over benign input passes.

**A generated console resolves the awk paths at runtime but bakes in its own invocation.** So editing
these files reaches every deployed console immediately, while a change from one `-f` to two does not
reach any of them until each workspace is regenerated. Splitting a primitive out of a formatter is
therefore not a safe in-place edit: it is live to the old invocation the moment it lands.

The history below describes the merge that produced the primitive, when it still lived inside the
claude formatter.

Two spawn paths render untrusted values into one-line terminal progress messages, and each was
correct on the half the other got wrong. `truncateSafe` here cut on a real UTF-8 character boundary
but neutralised nothing: its own `jsonUnescape` *decodes* a spec-legal `\r` into a live CR and prints
it, so a `Bash` call carrying `echo hi\rrm -rf / # FORGED` reached stderr with the CR intact and
forged the line — measured, `od -c` showed the `\r` byte in the output — and a raw ESC in the same
string passed through untouched. Its only partial defence was `jsonUnescape` dropping `\uXXXX`, one
of three ways the same byte can arrive. The scaleway harness's own `AgentsHarnessTruncateArg`
folded every C0 byte and DEL correctly but cut with `${value:0:120}`, which is **byte**-based under
`LC_ALL=C` — measured on bash 3.2.57, that emitted a lone `e2` lead byte mid-character, the exact
defect `truncateSafe` existed to prevent. Under an inherited `en_US.UTF-8` the same expression is
character-based and safe, so it bit only in a C/POSIX-locale context: daemon, cron, remote bootstrap.
One primitive now does both, and both callers reach it.

- **It lives in this file because a generated console pins this file's path, and for no other reason.**
  `DagcRunClaudeStreaming` runs `awk -f "$MDLT_ORIGIN/…/AgentsClaudeStreamJsonFormat.awk"` with a
  single `-f`, and that line lives in `$MMDAPP/DistroAgentsConsole.sh` — a snapshot `cat`-ed from
  `AgentsConsoleShellScript.template.sh` by `--make-console-command`, rewritten only when someone runs
  it. Staleness is the steady state, not an edge case: measured during this pass, both live consoles
  differed from the source template (91 and 120 lines), and both resolve `MDLT_ORIGIN` to a live
  `source` tree, so each already runs an old invocation against today's awk file. POSIX awk does
  concatenate multiple `-f` program files into one program, and a neutrally-named
  `AgentsProgressLineSafe.awk` reached that way is the tidier shape — but it makes the second file a
  hard runtime dependency, and one-true-awk answers a call to a function it was not given with
  `calling undefined function`, a fatal exit 2 raised **at call time, not at parse time**. Every
  console not yet regenerated would keep starting normally and then lose claude progress output at the
  first tool call. So the pinned path is the primitive's home and the sharing runs the other way.
- **The harness reaches it as an ordinary `awk -f` run**, `-v progressLineCap=<bytes>` with the value
  on stdin. That variable is the entire switch: a guarded rule accumulates stdin as one value and
  `next`s past the claude rules, and `END` prints the rendered result with no trailing newline. Unset,
  it costs the claude path one numeric comparison per input line and nothing else, and the console's
  own invocation is unchanged — which is what makes a stale console a non-event.
- **The cap is bytes now, in both callers, and that is the point.** `truncateSafe` was already
  documented and measured in bytes; `${value:0:120}` meant bytes or characters depending on the
  ambient locale. One locale-independent definition beats two, and for the ASCII paths and commands
  these lines actually carry the two numbers are the same.
- **The invariant is the source of an escape, not the escape itself.** This package emits ANSI deliberately,
  for its own progress display, while every escape arriving in untrusted data — a tool-call argument,
  model output, file content — is neutralised. Both halves are load-bearing together, and the failure
  mode is a display improvement that quietly widens the first into the second by letting something
  through so that it "renders properly". A change to any progress path is checked against this before
  it is checked against how it looks.
- **Cost, measured.** The harness swaps one fork for one fork — `printf | tr` became `printf | awk` —
  and three rounds of 200 calls put the two inside each other's run-to-run spread (~4.4 ms per call
  either way, dominated by the `$( )` capture; bare `awk` costs ~0.8 ms more to exec than bare `tr`,
  and that difference does not survive the surrounding subshell). The claude path pays ~4 µs more per
  progress line (39–40 → 44 µs over 5000 lines), because neutralising control bytes means inspecting
  the bytes that are kept. A `[[:cntrl:]]` test gates that scan so a clean value skips it — a named
  class, never a bracket range — and it gates rather than implements the fold on purpose: a class can
  over-match across locales but cannot under-match, so a gate built on it costs at worst a wasted
  pass, while the authoritative fold stays the explicit `ordTable` walk. Verified as exactly
  `{0x01–0x1F, 0x7F}` on one-true-awk 20200816 and gawk, with no high-byte hits that would corrupt UTF-8.
- **The claude path's tool NAME goes through it too, not only the argument.** A name is model output
  like everything else on that line, an MCP server names its own tools, and it was reaching stderr
  raw — the harness's own rule already said "the function name included, since that is model output
  too". It is folded but never cut, which is what it did before.
## Streaming transport

The core opens Scaleway's SSE stream (`"stream":true`) via `curl -N` and consumes it incrementally,
then falls through into the same error-handling and tool-dispatch code once a round's stream
completes — a second, streaming-shaped tool-dispatch path was deliberately not built, so a dispatch
bug has one place to be fixed, not two.

**Which layer owns what, in this section specifically.** The stream's SHAPE — the event grammar, the
field paths, the fragment keying, the sentinel — is the wire adapter's, because it is fixed by the
endpoint rather than chosen by us. The retry policy, the round cap and the stall bound are the core's,
because they would hold the same way against any provider.

- **Real SSE shape, live-confirmed, OpenAI-compatible.** Plain-text and tool-call progress arrive as
  `data: {...}` events; a tool call's `function.arguments` arrives as successive fragments keyed by
  that call's own `index` (distinguishing concurrent tool calls in one response) and must be
  concatenated before the result is valid JSON. The stream ends with a literal `data: [DONE]` line —
  the completion sentinel this harness actually waits for, never `finish_reason` alone, because
  Scaleway can trail the real final chunk with a further usage-only chunk before `[DONE]` arrives.
- **Per-round accumulator state lives in scratch files under `$harnessScratch`, not shell variables.**
  `curl -N ... | while read` puts the loop on the right of a pipe, which bash always runs as a subshell
  (no `lastpipe`, a bash-4.2+ feature outside this package's bash-3.2 floor) — any variable the loop
  body set would be gone the moment the pipeline ends. Scratch files are the one channel that survives
  that boundary.
- **Design decision — a mid-stream disconnect discards partial state and retries the whole round from
  scratch, bounded at 3 attempts (`harnessStreamMaxAttempts`).** There is no resume primitive on this
  API — no server-side stream id, no partial-completion token — so retrying the exact same full
  conversation-so-far request each round already builds is not an approximation of resuming, it is
  the only next request this API accepts. A partial `function.arguments` accumulation is very likely
  not valid JSON on its own (a prefix cut at an arbitrary byte), and a partial plain-text answer printed
  as the final answer would silently hand the caller a truncated reply with no signal it was cut off.
  Every accumulator resets to empty at the start of every attempt, including a retried one.
- **Design decision — a disconnect-triggered retry never consumes a round against a cap
  (`harnessMaxRounds`, set only when a caller asks for one).** `harnessRound` increments exactly once per pass through the
  outer round loop, before the streaming attempt loop begins; a retried attempt lives entirely inside
  one outer-loop iteration. The round cap exists to bound how many times the harness goes back to the
  model with a conversation that has actually grown (new tool results appended, more context spent); a
  disconnect-and-retry sends the identical request again, nothing about the conversation grew, and no
  tokens were billed for a completed generation — charging a transport hiccup against a budget meant to
  bound runaway tool-calling growth would let a flaky connection trip a limit that has nothing to do
  with it. The retry attempts are bounded independently and narrowly instead (3, above), so a
  connection that is not flaky but actually broken still fails loudly, via its own small counter, never
  by silently consuming the conversation's round budget.
- **A stall detector, not a flat deadline, bounds a live stream.** `--speed-limit 1 --speed-time 45`
  aborts only once throughput has been near zero for a sustained 45-second window — long enough that a
  heavy-reasoning model's own thinking pause before its next chunk is not mistaken for a dead
  connection, short enough that a genuinely dead connection does not hang the harness indefinitely.
  `--max-time` is deliberately absent: a flat cap is wrong once total generation time can
  legitimately run past it (heavy tier, a slow but alive stream). `--connect-timeout` bounds only the
  initial TCP+TLS handshake and is not a bound on the stream at all.
- **`${PIPESTATUS[0]}` is what is actually tested after the streaming `curl`, not `$?`.** Once `curl` is
  the left side of a pipe into the consuming `while read` loop, `$?` reports the pipeline's own exit
  status (the loop's), not curl's — captured on the very next line, before anything else runs, exactly
  as `set +e`/`set -e` bracket that one statement so the surrounding `set -e` does not trip on a
  non-zero curl exit it needs to inspect itself.
- **Prompt-cache stability is the adapter's responsibility, and it fails quietly.** Caching is a
  byte-prefix match, so a re-serialised `tools` array in a different key order stays VALID JSON and
  loses the entire cache — no error, no log line, only cost. The tools declaration is therefore a fixed
  literal rendered once, never rebuilt per round, and the request body appends in a fixed order. Do not
  "simplify" either into a rebuild from an array: the same rebuild that merely COSTS here is a hard
  failure on a wire that binds its prefix, and the cheaper leg is the one that fails silently.
- **Field names in the adapter are observed, never documented.** Every path was read off real responses
  from this endpoint. The rule exists because it has already been broken elsewhere: DeepSeek documents
  `prompt_cache_hit_tokens` while Scaleway-hosted DeepSeek emits `prompt_tokens_details.cached_tokens`.
  A documentation-derived field name in an adapter is silent, permanent, and already wrong on at least
  one model in use.
- **Reached through the console's own exec dispatch.** `DAGC_SCALEWAY_HARNESS` resolves to the stub,
  `DAGC_CLI_EXEC` maps `scaleway` to it, and the `exec` lines launch that path — so the console reaches
  the stub and the stub reaches the core, one invoker and one process throughout.
  `--owner-setup-scaleway`'s install-probe and `AgentsToolsSpawnCliPresent` both test the plain default
  name and deliberately do not follow `MDAT_SCALEWAY_HARNESS`: they ask whether the release reached this
  workspace, not which file a run selects.
- **What this section does not claim.** The live position is recorded once, in the stub section above,
  and is deliberately not restated per bullet: one round exercised the wire end to end, a second proved
  `Read` on a plain path, and the symlinked access-root case failed and is under repair by the seat
  that owns it. No transcript or timing numbers are filed here. Treat any behaviour described above that
  those rounds did not touch as designed rather than demonstrated.

## The harness tool set

The harness declares twenty tools: `Read`, `Write`, `Edit`, `Glob`, `Grep`, `Bash`, `WebSearch`, `WebFetch`, `SendMessage`, `ListAgents`, `Wait`, `SubagentHandback`, `ReportFindings`, `PushNotification`, `Artifact`, `AskUserQuestion`, `ListMcpResourcesTool`, `ReadMcpResourceTool`, `ReadMcpResourceDirTool`, `Skill`. Each occupies four structural sites -- the `harnessToolsJson` literal in `sh-lib/AgentsOpenAiChatWire.sh`, and the announce arm, the dispatch arm and the tool function in `sh-lib/AgentsUniversalHarness.sh` -- and `sh-lib/AgentsHarnessSelfCheck.awk` proves all four for every one of them. MCP tools are added separately under `mcp__<server>__<tool>` and are not part of this set.

`SendMessage` posts through `--member-comms-slack-send-message`, under the member identity `--agent` named; a harness started without `--agent` refuses to send rather than choosing one. The message text goes in on `--from-stdin`, so no shell parses it, and no credential ever reaches argv. Its `to` parameter is required because nothing hands the harness a thread of its own -- the full spawn-time environment is `MDAT_SPAWN_AGENT`, `MDAT_SPAWN_LAUNCH_MARKER` and `MDAT_SPAWN_SESSION_ID`.

`ListAgents` lists the running-session records the team data store actually holds: the `dispatch-*` board items under `$MDAT_DATA_ROOT/board/running`, each carrying its own `session-id`, `owner` and `status`. There is no other session registry in this estate. A session id in `<channel>:<ts>` form is a thread `SendMessage` can post into. Where the store cannot be read the tool returns a stated ERROR, never an empty list, and every listing carries its denominator.

`Wait` -- one bounded long poll over a list of input sources, returning the moment any of them changes. It calls `--member-wait-for-input` and adds nothing of its own: which sources exist is that operation's business. The waiting happens in the shell, so a run that is waiting spends no tokens and its context does not grow. The first line of its result is the outcome -- `RECEIVED`, `TIMEOUT` or `ERROR` -- and `TIMEOUT` is a successful wait, not a fault. What to do after a quiet wait is the skillset's escalation rules, never this tool's.

**What `Skill` is for, at MVP scope: reading any skillset file, read-only, whatever `Read` and folder access would otherwise permit.** Reaching a skillset file is the point of the tool and not a side effect to be bounded. Read-only is a property of the implementation and not only of the intent -- it creates, moves and removes nothing, and its one redirect targets the harness's own scratch directory rather than anything under the skillset.

**Its reach is therefore the skillset root and everything reached through it, deliberately outside the access roots. That reach is the design, and following a member folder's own symlink is how the tool works rather than a hole in it.** A member folder under `$MDAT_SKILLSET_ROOT` IS a symlink into whichever source tree owns it, so the material the tool exists to serve lives outside the root it is named by. Containment is held lexically for that reason -- gated character set, no `..` segment, no leading slash, decided before any resolution -- and that gate is sound on its own terms: it refused all 23 lexical attacks put to it, covering percent- and double-percent-encoded traversal, a fullwidth solidus, invalid-UTF-8 dot bytes, backslash separators, an embedded newline, an empty segment and absolute paths in both arguments. Reaching shared material, and reaching it through the member folder's own symlink, are intended and are not to be "fixed".

**One narrow case falls outside that reach and is accepted: a symlink PLANTED inside a member tree or in the skillset root, pointing somewhere outside the skillset tree entirely, is followed.** `-f`, `-r` and `cat` all follow symlinks, so the comment on the function is true about the STRING and false about the READ: the gate constrains what the argument may name, not where the named path resolves to. Six inputs carrying no `..` and no slash read files outside the skillset tree that way, `/etc/passwd` among them. **`/etc/passwd` is not a skillset file, so this case falls outside the intent above rather than inside it, and the two stand side by side without being reconciled here:** the intent is read-only over any skillset file, and this is a measured read of something that is not one. `list` is the same case and belongs to it: `find -L` follows such a link too, printing the outside file under an in-folder path, and a read by that advertised name then succeeds. What makes this acceptable is measured with a positive control -- zero symlinks of any kind inside the 20 real member trees, so none pointing outside them -- and the precondition that rests on is one `ln -s` planted in a member tree or in the skillset root, in ordinary source trees that humans and agents both write to. **The condition that reverses this is the first symlink pointing OUTSIDE the skillset tree appearing in a member tree or in the skillset root** -- never a symlink as such, since those are the architecture. Nobody polls for it and no watcher exists; it is written here so that whoever notices one knows what it means. **`Skill` is the one reader outside this harness's own resolved path handling, which is why the case exists here and nowhere else in the tool set:** `Read`, `Write`, `Edit`, `Glob`, `Grep` and `Bash` all go through `AgentsHarnessPathAllowed`, whose symlink behaviour is held in BOTH polarities by `AgentsHarnessContainmentCheck.sh` -- a symlinked access root is admitted, a `..` escape refused -- and `Skill` deliberately does not. The guard that matches this, recorded so it is not re-derived: resolve after the lexical gate and require the candidate under the resolved MEMBER folder, which admits all 20 real member trees. A resolved-skillset-root prefix does NOT work and is what the lexical gate exists to avoid -- measured, it admits 1 member folder and refuses 19. Where shared material is ever linked into several members, its own resolved target joins the admitted set: the bound is the union of the roots the skillset intentionally publishes, never a single prefix.

**A tool description is shell code before it is prose.** The whole tools JSON is one bash single-quoted literal, so an ordinary English possessive -- `harness's`, `team's` -- closes it and the harness dies before its first request. Rewrite the possessive rather than escape it: `the team's own X` becomes `the X this team owns`. `AgentsHarnessSelfCheck.awk` matches text and does not parse, so it reports OK over a file in this state; `HARNESS_PARSES` is the check that sees it.

**The literal carries a SECOND hazard, and it is the mirror of that one -- neither check above reaches it.** A break INSIDE the JSON, a missing comma between two declarations being the ordinary case, leaves `bash -n` clean precisely because the literal is single-quoted and the shell never parses its contents, while `AgentsHarnessSelfCheck.awk` matches the envelope as text and reports `OK (N tools, four sites each)` over the same file. Measured, both of them, on a fixture. The defect then surfaces only as a 400 from the live endpoint, which the harness prints as a refused request -- so it reads as an API or credential fault rather than as a local edit. `HARNESS_TOOLS_JSON` is the check that sees it, and the two counts it compares are the whole mechanism: a merge leaves the TEXT count (what the site check sees) unchanged while the PARSED count (what the endpoint sees) drops. **A change that adds or rewrites a declaration is not checked until that assertion has run over it.**

## MCP enumeration -- `--mcp-server` spawns a named server once, at startup

**Enumeration runs once, at source time, before the first round.** `sh-lib/AgentsHarnessMcpClient.sh` builds a catalogue of what a named server offers, writes it to stderr and to `$harnessMcpCatalogue`, and renders one declaration record per tool from it. Declaring those tools to the model and calling one are the same file's own work on top of that catalogue, and are the section below. A run naming no server puts no `mcp__` name on the wire; measured, with the request body captured from a fake `curl`: the built-in tools, and zero occurrences of `mcp__`.

- **No server is granted by default.** A server is spawned only because `--mcp-server <name>` named it. The flag is repeatable, and the name is resolved against `$MMDAPP/.mcp.json` under the `mcpServers` key -- the file this estate already keeps. There is no second config format and no path in any skillset file.
- **A spawn naming none leaves the file inert**, which is also what keeps the offline checks offline: `AgentsHarnessRestartCheck.sh` drives the real core with no `--mcp-server`, so it opens no file and starts no process. Enumerating unconditionally at startup would destroy that check, so the guard on `${#harnessMcpServers[@]}` is load-bearing rather than defensive.
- **`MMDAPP` unset or `.mcp.json` absent is not an error.** With no server named, nothing is printed at all, exactly as the hooks behave. With a server named it is a loud degrade instead of silence -- the operator asked for something they did not get -- and the run continues on the built-in tools.
- **One process per enumeration, never a persistent connection.** The whole conversation is written before the server starts -- `initialize`, `notifications/initialized`, `tools/list` -- and the server reads three lines, answers, and reaches EOF, which is what ends it. bash 3.2 has no way to hold a bidirectional stdio session open without `mkfifo` plus statically allocated descriptors.
- **The answers are read FROM A FILE, never through `$( )`.** A capture returns when the pipe has no writers left, not when the process exits, so one child a server leaves behind would hang the spawn for that child's whole lifetime. Measured against a fake server that backgrounds a `sleep` and never answers: the leg ends on its own bound, not on the orphan's.
- **Every server interaction is bounded, the way `AgentsHarnessToolBash` bounds a command** -- `timeout` or `gtimeout` where one exists, the same background-plus-watchdog shape where neither does. Expiry is stated, never waited out silently. Enumeration and a tool call carry different bounds because they are different waits: enumeration happens at spawn time, before the member works, and is held to `MDAT_HARNESS_MCP_ENUM_TIMEOUT` -- 30 seconds by default, a chosen policy value rather than a guess, since a healthy stdio server answers `initialize` in milliseconds. A deliberate tool call keeps the run bound, `MDAT_HARNESS_RUN_TIMEOUT`, 900 seconds by default. Both are validated as whole seconds by explicit digit enumeration, never a bracket range.
- **A name is gated by explicit character enumeration, never a bracket range** -- `[a-z]` is collation-dependent and has matched `A` on this estate. A server key or tool name outside `[A-Za-z0-9_.-]` is DROPPED saying so, and an `env` key outside `[A-Za-z0-9_]` likewise; nothing is quietly rewritten to fit. The declared name is `mcp__<server>__<tool>`, so an ungateable component cannot reach it.
- **Credentials reach the child through its environment and never through argv.** `.mcp.json`'s own `env` object is passed as `NAME=value` tokens to `env`, which is also why `command` must be an absolute path: the leading `/` is what guarantees it can never be read as one of those assignments.
- **The catalogue is the shape `harnessHooksList` carries** -- newline-delimited, TAB-separated `server<TAB>toolName<TAB>declaredName<TAB>schemaFile` -- so the per-call path stays builtins-only. The schema file holds that tool's own `inputSchema` as raw bytes, in the harness's own scratch directory, and goes with it on EXIT.
- **A degrade names its reason once and says it twice**: a loud stderr line for the operator, and the same reason built into `$harnessMcpUnavailableNote`, the sentence the model is owed. Publishing it is this file's job; the core is what places it, appending it to `$harnessSystemText` before `AgentsWireInitMessages` builds the first request -- that server's tools are absent from the declarations, and nothing else in the run says why.
- **No production caller passes `--mcp-server`.** No spawn proxy, console CLI or skillset operation names a server, so the flag is reached by hand and by `sh-lib/AgentsHarnessMcpCheck.sh`, which drives it against its own fake server.

## An MCP tool on the wire -- declared per tool, dispatched last, frozen for the run

**Each enumerated tool is declared to the model individually, as `mcp__<server>__<tool>`, in the same `tools` array as the built-in set.** There is no umbrella "call this server" tool: the model picks an MCP tool by name the way it picks `Read`. `AgentsWireToolDeclaration` in `sh-lib/AgentsOpenAiChatWire.sh` renders one such record and is the only wire-shaped piece of MCP -- the `{"type":"function",...}` envelope is that endpoint's shape, so it lives with the wire rather than beside the catalogue it describes. The server's own `inputSchema` is passed through as the bytes it sent; only the description is escaped.

- **The tool set is frozen before the first round and is byte-identical on every one of them, a summarise-and-restart included.** `$harnessMcpToolsJson` is built during enumeration and never changes afterwards, and `AgentsWireRequestBody` splices it into the wire's own literal set in one fixed place, by stripping the closing `]` and appending. A fresh leg reuses it rather than enumerating again. Neither half of the reason is cosmetic: `tools` sits inside the cached byte prefix, so a rebuild in a different key order stays valid JSON and silently loses the whole prompt cache, and on the Anthropic wire the declaration binds to the thinking blocks, where changing it mid-session is a 400 at replay.
- **One `mcp__*` prefix arm in the dispatch `case` and one in the announce `case`, each placed after every static arm** and before the unknown-tool fallback -- a prefix arm reached earlier could displace a built-in. The announce line shows the whole argument object, since only the server knows its own shape. `AgentsHarnessMcpCall` is deliberately outside the `AgentsHarnessTool*` family: that family is the static tool class `AgentsHarnessSelfCheck.awk` matches site by site, and a runtime-built tool has no site in the sources for it to match.
- **The per-call path always prints a tool result.** A server that cannot be run, dies mid-run, refuses the call, sets `result.isError`, or answers in a shape this harness cannot read each becomes an `ERROR: ...` line the model reads, and the round carries on -- never a silent restart and never an exit. A declared name no catalogue row matches is refused the same way, saying that no MCP server this run enumerated declares it. Arguments are validated as one JSON object before anything is sent, and their newlines become spaces, since a JSON-RPC request is one line and a newline inside a string literal is not legal JSON anyway.
- **A deny hook can actually deny an MCP call, because it is handed the call's real arguments.** The `*)` arm of `AgentsHarnessHooksRefusal` passes them through verbatim under `tool_input` -- an MCP tool's arguments already ARE the object a hook reads fields out of, and an empty object there would let a hook written to deny read nothing, match nothing and exit 0, which is an allow: fail-open inside a mechanism whose whole point is failing closed. They are validated as one JSON object first, and only an unparseable payload falls back to `{}`.

## `sh-lib/AgentsHarnessJsonSlice.awk` -- raw bytes and key names, where the field reader returns neither

`AgentsHarnessJsonField.awk` beside it decodes and returns SCALARS, so a schema subtree and a key whose name nobody knows in advance are both unreachable through it. This returns the two things that reader cannot: `-v mode=raw` prints one value's own source text, `-v mode=keys` prints the immediate child key names of the object at that path, one per line. Nothing is decoded -- a key name keeps its own escapes, so a name a caller cannot gate arrives visibly ungateable rather than silently rewritten into one that passes. Same rc contract as the field reader: 0 found, 3 parsed but the path absent, 1 not a parseable JSON object, 2 usage. `LC_ALL=C` is required, as it is there.

## The harness instruments, and what each one proves

Each instrument below either reads the harness's sources and proves coherence, or executes it and proves
behaviour; its own entry says which, and nothing else in this package does either. Each carries its own negative control, because
a checker reports green on its own counterexample as readily as on a clean subject and nothing in a
green report tells the two apart — so every red recipe below is one that has been run, not one that
ought to work.

**Three ways an ad-hoc probe passes that discipline and still establishes nothing.** All three were hit while
reviewing this package's own tool set, and each returned a clean answer that read as a finding. First,
a control has to run the EXACT command shape whose negative is being reported, not a similar one:
`find -L <root> -type l` reports only DANGLING links, because under `-L` a resolvable symlink is
reported as its target's type — so it prints nothing over a tree full of them, and a control taken
without `-L` validates a different command and misses that entirely. Second, a rig that lifts
functions out of a source file and evaluates them silently voids any case whose dependency was not
lifted: the missing function exits 127, its output is empty, the caller falls through its own branches
and returns 0, and the case reports success having called nothing. Assert every dependency is loaded
and callable, not only the function under test, and withdraw such a case rather than counting it.

Third, **a rig whose subject must reach its fixture through a gate the rig did not move passes and means
nothing.** The access roots refuse `$TMPDIR` and `/tmp`, so a rig building fixtures with `mktemp -d -t`
and starting work there is testing the subject in a place the subject cannot read or write. The failure
arrives as a refusal the rig then stubs past, and every assertion downstream of that stub is void rather
than green. The discriminator is not where the fixture sits — it is whether the gate was satisfied or
moved. `AgentsHarnessAccessRootsCheck.sh` and `AgentsHarnessContainmentCheck.sh` both build under
`mktemp -d -t` and are sound, because each **relocates the root under test onto its own fixture**: the
first exports `MMDAPP="$rigTmp"` so the mechanism's own roots resolve inside it, the second passes
`$rigTmp/real` as the allowed root and `$rigTmp/outside` as the refused one. A rig that instead replaces
the gate with a permissive stand-in has neither satisfied it nor moved it, and its passes are void. Where
a rig genuinely needs the real gate, the estate's own work directories are what it is granted:
`$MMDAPP/.local/temp/team`, and `$MMDAPP/.local/temp/member/<member>` and `$MMDAPP/.local/temp/task/<member>`
once a member is named — `sh-lib/AgentsTools.ClientAccessRoots.include` is where that set is produced.

`AgentsTools.Owner.include`'s `--owner-setup-scaleway --check` arm runs all of them but the containment
check, and is gated on `--check` for the work rather than only for the output: they parse sources, spawn
awk processes and run several legs of the harness, and `--apply` must neither pay that nor start
returning non-zero on a diagnostic finding.

- **`sh-lib/AgentsHarnessAccessRootsCheck.sh` — where the no-flag access-root set comes from.**
  - Proves: with no `--access-root` passed, the set is taken from `sh-lib/AgentsTools.ClientAccessRoots.include`, the one place it is defined. It is not taken from a client's published launch fragment. The discriminator is a root only such a fragment names. Our own mechanism cannot yield it, so its presence on the wire says the fragment was read. A root the mechanism always yields, `$workspace/source`, is asserted present too, so an empty or truncated body cannot pass.
  - Why it exists: that path had no instrument at all. A path with no instrument is one where a false green is the default. An earlier ad-hoc probe of it could not fail. The core exits at its own `HARNESS_*` provider gate before the resolution runs, so merely starting the harness measures the gate and reports on nothing.
  - How a gated path is reached, which is the part worth keeping. Set the dummy `HARNESS_*` a provider stub sets, and put a fake `curl` first on `PATH`. Those are a provider name, a `.invalid` endpoint and host, a wire name, a credential name, and a token that is not one. The core then runs as far as the wire. The resolved roots travel inside the system prompt, so the recorded request body is the observation. The behaviour checks below use the same technique.
  - Refuses rather than reporting where the wire was never reached. Measured with the core made to exit early: zero PASS lines, an explicit refusal, exit 1. That property is what the void probe it replaces did not have.
  - Red recipe: point the no-flag resolution back at the fragment. Both assertions fail. The planted core still parses, which is why no syntax or text check reaches this class and a behavioural one must.
  - Self-contained. Every fixture is built in its own `mktemp -d`, and the scenario's own `MMDAPP` is that directory, so no file of the real workspace is read. Measured from `/` under `env -i`, with neither `MMDAPP`, `MDAT_*` nor `MDLT_ORIGIN` set: it passes.
  - Does not prove: whether a path is inside the roots once resolved. That is `AgentsHarnessContainmentCheck.sh`'s, and neither answers the other.
- **`sh-lib/AgentsHarnessWriteSplitCheck.sh` — which of the two sets a path is inside.**
  - Proves: where a write root is given, writes narrow to it while reads stay wider, and a root on the read side only is refused for writing **and still readable**. Where no write root is given at all, writes stay exactly as wide as reads, which is what every console generated before the split passes.
  - Why it exists: the two root flags do opposite things to the set they join and neither name says so. A root flag replaces the default set; a write flag narrows writes. So a caller passing one write root in order to grant one directory takes every other write away in the same call, and the call reports success.
  - The controls, and why each is there. A write into a granted-for-writing root must succeed, or the refusal above passes on a core that refuses every write. The read-only root must be **readable**, or it passes on a core that dropped the grant entirely. And a root granted on neither side must be unreadable, or that readability control passes on a core that reads anything at all. `Write` refuses an ungranted path and a read-only path with the same message, because it tests the write set first and never reaches the other, so the refusal text cannot tell those apart and readability is what does.
  - Offline and unmetered: `--intern-tool` reaches no endpoint and needs no credential, so the tool gate itself is the observation. No wire, no stub `curl`, no recorded request body.
  - Red recipe: drop the guard on the write set's fallback so it always takes the read set. The readable-but-not-writable assertion then reports a write where it must report a refusal.
  - Does not prove: where the set came from, or whether a path is inside it at all. Those are the two checks beside it, and none of the three answers another.
- **`sh-lib/AgentsHarnessSelfCheck.awk` — every tool occupies all four of its structural sites.**
  - Proves: each tool has its declaration (in the wire adapter), its announce arm, its dispatch arm and
    its tool function (those three in the core), and no `AgentsHarnessTool*` function survives with no
    tool behind it. An empty tool population reports FAIL rather than passing, so an extraction that
    matched nothing cannot read as a clean run.
  - Does not prove: anything a tool does. A tool present at all four sites and broken at every one of
    them passes. It also cannot see a tool the set gains at runtime: it matches the literal envelope in
    the source, so a further tool appended to `harnessToolsJson` goes on the wire unexamined while the
    report stays `OK (N tools, four sites each)`, byte-identical to a clean run. Written as a source
    literal instead, that same tool is caught: FAIL naming its three missing sites. Both measured. The
    dynamic class is `AgentsHarnessMcpCheck.sh`'s, below.
  - What it proves of `Wait` is the four sites and nothing else. Whether a wait ever returns is outside
    it entirely: a `Wait` that never came back, or that dressed a TIMEOUT as an ERROR, passes exactly as
    any other tool does. That behaviour is shown by the operation's own offline demonstrations against
    its `file` adapter, which needs no host — an absent drop path returns `WAIT-RESULT: TIMEOUT` at exit
    0; a file appearing mid-wait returns `WAIT-RESULT: RECEIVED` carrying what that source now holds; an
    unknown source kind returns `WAIT-RESULT: ERROR` at exit 1 inside the same second, naming the kinds
    that exist; and a probe that cannot run is named in the body while the wait carries on over the rest.
    All four measured, and all four are now held by `AgentsHarnessWaitCheck.sh` below, which runs at the
    same call site. The wait class is this checker's blind spot, not the package's.
  - Does not parse either. It matches text, so a bash syntax error in the sources it reads leaves its
    report clean. Measured: an ordinary English possessive in a tool description closes the
    single-quoted `harnessToolsJson` literal, `bash -n` rejects the file, and this still reports
    `OK (N tools, four sites each)`. `HARNESS_PARSES` is the check that sees it.
  - Invoked: `cat sh-lib/AgentsUniversalHarness.sh sh-lib/AgentsOpenAiChatWire.sh | LC_ALL=C awk -f
    sh-lib/AgentsHarnessSelfCheck.awk`. The two files are concatenated because the sites span both;
    pointed at either alone it sees a half-populated set, which it correctly reports as FAIL.
  - Its red: drop one tool's declaration line from a copy of the wire adapter. Measured —
    `WebSearch: declared site missing`, exit 1.

- **`sh-lib/AgentsHarnessToolsJsonCheck.sh` — the tools declaration literal is valid JSON, reached by a parser and not by a text match.**
  - Proves: that every declaration in `harnessToolsJson` is reachable by the parser, that each carries a
    `function.name`, and that the PARSED count equals the TEXT count of declaration envelopes. That last
    comparison is the whole instrument: a missing comma merges two objects, leaving the text count
    unchanged while the parsed count drops, and the disagreement names the defect exactly.
  - Does not prove: anything a tool does, or that a declaration describes its tool truthfully. A
    perfectly valid declaration of a tool that does not exist passes.
  - Reads through `AgentsHarnessJsonSlice.awk`, deliberately NOT the reader the harness runs its own
    responses through: a literal validated by the same code that consumes it proves only that the two agree.
  - An extraction matching nothing is a FAIL rather than a pass, the same rule the site check holds
    itself to, and a literal that parses but declares nothing likewise.
  - Invoked: `./sh-lib/AgentsHarnessToolsJsonCheck.sh [<wire adapter>]`, defaulting to the adapter beside
    it. Wired into the same `--owner-setup-scaleway --check` pass, immediately after `HARNESS_PARSES`.
  - Its red: drop the trailing comma from one declaration in a copy of the wire adapter. Measured —
    `bash -n` CLEAN and `HARNESS_TOOL_SITES: OK (N tools, four sites each)` over that same broken file,
    while this reports `HARNESS_TOOLS_JSON: FAIL ... NOT VALID JSON`, exit 1. That contrast is the reason
    it exists, and all three halves of it were measured in one invocation.

- **`sh-lib/AgentsHarnessServedFloorCheck.sh` — which tools the MCP server actually serves.**
  - Proves: that no harness tool on the served floor declares a `command` argument, and — independently of
    any argument name — that no tool whose own function in the core runs a caller-supplied string as a
    shell command is served. The served set is read off the real server's own `tools/list` answer, so the
    subtraction under test is observed rather than recomputed.
  - Why it exists: a harness tool joins that floor by default and nothing asked whether it should. The
    site check counts four structural sites, the tools-JSON check parses a declaration, and the mirror
    renders the whole floor by design — so all three stay green over a hole. `Monitor` reached the floor
    that way, where a `tools/call` runs one tool in a fresh process: the command ran, no scratch survived
    the call, and the job was left running with its log already deleted.
  - Does not prove: that any served tool works, or that an unserved one is unservable for the right
    reason. The process-local-handle half of the documented test is outside it entirely — see the section
    above for why no source scan reaches it.
  - Its reds, measured in a planted copy rather than reasoned. Drop `Monitor` from
    `mcpUnservedToolNames`: the `command` assertion fails and so does `Monitor`'s own. Do that *and*
    rename `Monitor`'s `command` parameter to `script` in its declaration alone: the `command` assertion
    passes while the behavioural one still fails, which is the whole reason the behavioural form is
    carried rather than the name alone.
  - Self-contained and offline. `MMDAPP` — the root under test for the server's own scratch and every file
    it reads — is relocated onto its own `mktemp -d` fixture, and `MDLT_ORIGIN` is the tree the check sits
    in, so a planted copy tests itself. No socket, no credential, no file of the real workspace.
  - Invoked: `./sh-lib/AgentsHarnessServedFloorCheck.sh`. Wired into the same
    `--owner-setup-scaleway --check` pass, after `HARNESS_ACCESS_ROOTS`.

- **`sh-lib/AgentsHarnessContainmentCheck.sh` — access-root containment, in both polarities.**
  - Proves: `AgentsHarnessResolveDir` and `AgentsHarnessPathAllowed` as a pair, behaviourally, against a
    real symlink fixture — must-allow cases where a refusal locks an agent out of its own grant, and
    must-refuse cases where an allow is an escape. The pair, because the defect it was written for lived
    in their composition rather than in either one.
  - Does not prove: that any tool honours the verdict. It calls the two functions directly, so a tool
    that ignored `harnessResolvedPath` would pass this untouched.
  - Invoked: `./sh-lib/AgentsHarnessContainmentCheck.sh`. **It is wired into nothing** — the setup arm
    above runs every other instrument and not this one, so it is reached only by hand.
  - Its red: stop canonicalising the roots in a copy's `AgentsHarnessResolveDir`. Measured — every
    must-allow case turns REFUSE while every must-refuse case still passes, which is what makes carrying
    both polarities load-bearing rather than decorative.

- **`sh-lib/AgentsHarnessAwkAxiom.awk` — no statement shares a line with its closing brace without a `;`.**
  - Proves: that one hazard, across whichever awk sources it is given. The awks that reject the form are
    the ones not on a dev box, so a clean run under the local awk proves nothing and the axiom is held by
    an instrument instead of by anyone remembering it.
  - Does not prove: that an awk source parses, loads or does what it says. Own-line braces and a brace
    inside a quoted payload are skipped as documented false positives.
  - Invoked: `LC_ALL=C awk -f sh-lib/AgentsHarnessAwkAxiom.awk <awk source>...` — silent and exit 0 when
    clean, one `<file>:<line>: <text>` line per hit otherwise. The wired call passes it the awks this leg
    loads.
  - Its red: a file carrying `{ nestDepth = 2 }`. Measured — one hit line, exit 1.

- **`sh-lib/AgentsHarnessRestartCheck.sh` — summarise-and-restart, run rather than read.**
  - Proves: behaviour, over summarise-and-restart and the restart budget that bounds it. A fake `curl`
    first on PATH records each request body and replays a canned stream per round, while the real core
    and the real wire drive the scenarios: the threshold fires and the leg restarts onto the original
    task plus its own handover with the previous leg's history gone; the threshold is disabled and every
    one of those assertions answers the other way; the summarise step produces nothing and the run fails
    loud rather than restarting onto an empty summary; and the restart budget is spent, which closes the
    run at exit 3.
  - Does not prove: anything about a real endpoint. The stream is canned, so a wire change that breaks
    against the live API passes here. It dispatches one tool, `Read`, and says nothing about the others.
  - Offline by construction: it refuses to run at all unless the fake `curl` is first on PATH, that fake
    opens no socket, the token is a literal and the host a reserved `.invalid` name that cannot resolve,
    and an EXIT trap takes the whole fixture with it.
  - Invoked: `bash sh-lib/AgentsHarnessRestartCheck.sh`. Through its interpreter, the way the two awk
    instruments at that call site are invoked, so a lost execute bit cannot turn a behaviour check into a
    fault.
  - Its red: copy `sh-lib`, remove `harnessSummariseRound=1` from the copied core so the leg is told to
    hand over and then never restarts, and run the copied check. Measured — the three restart scenarios
    fail and each failed assertion names what it wanted against what it got, the threshold-disabled
    scenario still passes in full, exit 1.
  - The threshold-disabled scenario is why a green run here cannot be a vacuous one: it re-asks the same
    questions of the same canned rounds and requires the opposite answers, so an instrument that had
    stopped measuring would have to fail one of the two.

- **`sh-lib/AgentsHarnessMcpCheck.sh` — the dynamic tool class, run rather than read.**
  - Proves: that an enumerated MCP tool reaches all four of its sites, behaviourally — the rendered
    declaration on the wire carrying the server's own description and input schema, the announce arm, the
    dispatch arm, and the round trip to the server — while a built-in is still declared beside it. That
    last assertion probes ONE name on the request body, `"name":"WebFetch"`, so what it proves is that an
    MCP declaration did not displace the built-in set, never that all of them survived.
    With those: the freeze, since a summarise-and-restart re-offers the same declaration and the server is
    enumerated once for the whole run; a server that dies after handing over its tools becoming an `ERROR`
    tool result with the round carrying on; and a PreToolUse hook denying an MCP call on a value that
    reaches it only through `tool_input`. A fake MCP server and a fake `curl` drive it, and the real core,
    the real wire adapter, the real client and the real hooks are what run.
  - Does not prove: anything about a real server or a real endpoint, both being fakes here — a protocol
    detail this rig does not speak passes untouched. One server declaring one tool is the whole population.
  - Offline by construction, and it refuses rather than reports where it cannot be: the fake `curl` must
    be first on PATH, each scenario's own `MMDAPP` is where `.mcp.json` and `.claude/settings.json` are
    read from, the token is a literal and the host a reserved `.invalid` name that cannot resolve, an EXIT
    trap takes the whole fixture with it, and a scenario in which the harness issued no request at all
    stops the run instead of reaching a PASS line.
  - Invoked: `bash sh-lib/AgentsHarnessMcpCheck.sh`, through its interpreter on the same terms as the
    behaviour check above. Green is `HARNESS_MCP: OK (4 scenarios, 35 assertions, offline)`.
  - Its red: copy `sh-lib`, and in the copy's `AgentsHarnessHooks.sh` make the `*)` arm hand the hook `{}`
    instead of the call's own arguments. Measured — the other three scenarios still pass, the hook
    scenario falls to 3 of 7, the fake server records the call it should never have seen, and the run
    closes `⛔ MCP CHECK FAILED: 4 of 35 assertion(s)`, exit 1.
  - Its negative control is the no-server-named scenario: the same canned rounds with nothing declared,
    nothing spawned and the call refused as unknown, so an instrument that had stopped measuring would
    have to fail one of the two.

- **`sh-lib/AgentsHarnessWaitCheck.sh` — the wait class, run rather than read.**
  - Proves: behaviour, over `--member-wait-for-input` and the `Wait` tool that drives it. Seven scenarios
    take the operation alone — an arrival mid-wait returns on the arrival rather than the bound, naming
    the source that fired and what it now holds; the bound expiring with nothing new is
    `WAIT-RESULT: TIMEOUT` at rc 0 and never an error; an unknown source kind is `WAIT-RESULT: ERROR` at
    rc 1 inside the same second, naming the kinds that exist; a source that cannot be read is named while
    the wait carries on over the rest, and alone still says its silence is not quiet; `--wait-since-utime`
    counts content already present while its omission waits for a change; and `--wait-list-sources` offers
    exactly the adapters the include defines, counted off the adapter functions in the source rather than
    off the list the operation prints from.
  - Three of its ten scenarios then drive the REAL harness and the real wire rather than the operation
    alone: a TIMEOUT reaching the model as a TIMEOUT, an unwaitable source reaching it as a failed wait
    rather than as silence, and a `Wait` with no `--agent` refused before any wait rather than run under a
    guessed identity. That boundary is where the outcome split is actually at risk — a harness flattening
    the two leaves every operation-level assertion above green and still costs the agent the choice
    between waiting again and escalating, which is the only reason the operation exists.
  - Its tenth scenario asserts the offline claim instead of stating it: every request any part of this
    check could make is logged by destination, and the log is then read back — nothing named `slack`,
    every request this check's own canned model round, and at least six of them so the log is live rather
    than empty. That is the assertion the other nine rest on, since an instrument that quietly reached a
    real conversation would still print PASS lines.
  - Does not prove: anything about a real endpoint or a real conversation. Every model round is a canned
    stream from a fake `curl`, and every source waited on is a `file:` source under the check's own temp
    tree — the `slack` adapter is named in the listing and never exercised, so the kinds line is matched
    as text with nothing behind it run.
  - Offline by construction, and it refuses rather than reports where it cannot be: the fake `curl` must
    be first on PATH, the token is a literal and the host a reserved `.invalid` name that cannot resolve,
    an EXIT trap takes the whole fixture with it, and a harness scenario in which no request was issued at
    all stops the run instead of reaching a PASS line. The fake logs the destination and never the argv,
    because the `Wait` tool's own description carries the word `slack` and a log of argv would report a
    Slack request on every model round.
  - Invoked: `bash sh-lib/AgentsHarnessWaitCheck.sh`, through its interpreter on the same terms as the two
    behaviour checks above. `MMDAPP` must be set, since the operation places its own working directory
    under it. Green is `HARNESS_WAIT: OK (10 scenarios, 98 assertions, offline)`.
  - Its red, both measured against a copy of the package with `MDLT_ORIGIN` pointed at it, breaking the
    copied `sh-lib/AgentsTools.MemberWait.include` that the operation dispatches into:
    - TIMEOUT returned non-zero. Four scenarios fail, `⛔ WAIT CHECK FAILED: 7 of 98 assertion(s)`, exit 1
      — and at the tool boundary the model is shown `the wait could not be performed` where it should have
      read `WAIT-RESULT: TIMEOUT`.
    - An unknown source kind answering `WAIT-RESULT: TIMEOUT` at rc 0 rather than `ERROR` at rc 1. Two
      scenarios fail, again 7 of 98, exit 1 — the operation reports a wait that found nothing over a wait
      that never ran, and that is what reaches the model.
  - Its negative controls sit inside the scenarios rather than beside them, because each needs the same
    rig answering the other way: the unknown-kind scenario is paired with a known kind on the same
    600-second bound, opposite on the marker, the rc and the diagnostic; the `--wait-since-utime` scenario
    runs the flag and its omission over one unchanging file, so each leg is the other's control; and the
    listing scenario requires a kind nothing defines, `pigeon`, to be absent from what it offers.

- **`sh-lib/AgentsHarnessCopilotLegCheck.sh` — the Copilot leg, run rather than read.**
  - Proves: that `sh-lib/AgentsCopilotHarness.sh`'s own declarations reach the wire and that the core
    behaves under them — the endpoint in argv; the provider name in the diagnostics and in what the model
    is told; the tier-to-model mapping both ways; the bearer alone on curl's stdin as one line and
    nowhere in argv; the credential gate refusing under the name the leaf both declares and reads; a tool
    result carried back still under that model and that bearer; containment both ways, the refused write
    checked off the filesystem rather than off the message; a complete non-streaming error body costing
    exactly one request on a leaf declaring no exchange, its refusal naming the host and the code; a hook
    denying a write; and the core's context floor governing a leaf that declares none. The provider name
    and both model ids are READ from the leaf at run time, out of the environment it exports into the
    request process, so a rename of any of them cannot report a defect that is not one; the endpoint, the
    host and the credential name are PINNED, a wrong one there being the defect rather than a rename.
  - Does not prove: anything about the live endpoint — not whether either model id is accepted under its
    spelling, not whether the stored credential is accepted as the bearer with no exchange, not that
    usage rides the stream (the rig cans it), not the real error-body shape or the status behind it
    (scenario D's body is invented rather than captured, in the shape the adapter's error reader parses),
    and not that Copilot speaks the OpenAI chat-completions wire at all, every canned stream being
    OpenAI-shaped by construction — so the adapter is proven against itself, which this file holds open
    already. Nor that the floor suits these models — proven in force, not proven right. Nor, and this is
    the price of reading rather than pinning, that any value it reads is CORRECT: a read value is proven
    to arrive unchanged and no further, so the provider name and both model ids are unverified here by
    construction. The credential-exchange path is not exercised at all: this leaf declares none, and
    green says nothing about it.
  - Offline by construction, and it refuses rather than reports where it cannot be: the fake `curl` is
    re-checked first on PATH before every scenario, refuses to run outside one, and logs every request
    for the closing scenario to read back; a scenario issuing none stops the run short of a PASS line;
    each scenario's own `MMDAPP` is where `.claude/settings.json` is read; an EXIT trap takes the fixture.
    It alone cannot ALSO sit behind a `.invalid` host, the leaf's real endpoint being the subject, so
    `COPILOT_GITHUB_TOKEN` is forced to a literal before the leaf is invoked — which is what stops a
    machine holding the real token from ever having it enter the process.
  - Invoked: `bash sh-lib/AgentsHarnessCopilotLegCheck.sh`, on the same terms as the three behaviour
    checks above. Green is `HARNESS_COPILOT_LEG: OK (7 scenarios, 57 assertions, offline)`.
  - Its red, all measured against a changed copy of `sh-lib`, the package untouched:
    - The leaf repointed at a wrong endpoint and host. Scenario A 15 of 16, the error-body one 4 of 5,
      the closing one 4 of 5 printing the wrong URL against the pinned one; 3 of 57, exit 1. The same
      copy ran green at 57 of 57 before the endpoint was pinned, which is why it is pinned.
    - The bearer moved from curl's stdin into its argv. Scenario A 13 of 16, the tool-round one 5 of 6,
      the closing one 4 of 5 with all nineteen requests carrying another bearer; 5 of 57, exit 1.
    - `AgentsHarnessToolWrite`'s guard checked against the read-root set. Containment 7 of 9, the refused
      write on disk; 2 of 57, exit 1.
  - Its negative controls sit inside the scenarios: the hook one removes the settings file and requires
    every probe the other way, the file existing included; the context one runs a round under the floor
    and one at it; containment carries an allowed read and write beside its two refusals; the tier one
    requires the light id present and the main absent in one body. The reading rule has its own,
    measured: renaming both model ids in a copied leaf leaves it green at 57 of 57, while pinning the
    model in the copied wire adapter fails 3 of 57. Two of the 57 are standing guards rather than
    results, and say so in their own assertion text — both require that no bearer exchange ran, and
    nothing in this package declares one, so neither can fail until a leaf does.
