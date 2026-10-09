# MAGIC.md — myx.distro-agents

Maintainer notes for this package. Each entry is something that matters when you change the code and
that the code and docs do not readily tell you.

- How to install, configure and use the package: [README](README.md) and its [docs/](docs/) pages.
- Call contracts of public operations: `sh-lib/help/Help.DistroAgentsTools.help.md` (`--help`),
  `--member-help <member>`, and `--help-setup-<domain>`.
- Internal operations (`--intern-*`) have no help. Their essentials are kept below, in the section of
  the subsystem they belong to.
- Team-wide rules (git, evidence, controls, wording) are in `magic-team/magic-team.armed.md`, not here.

## Contents

1. Dispatcher and code layout
2. Environment and context resolution
3. Shell and awk gotchas
4. Writing code here
5. Configuration and local state
6. Our data, and the files we generate for others
7. The `--owner-setup-*` family
8. Installation and integrations
9. Hooks and workspace restrictions
10. The agents console
11. Spawning and sessions
12. The main loop and the root harness
13. The `myx.distro` MCP server
14. The universal harness
15. Harness tools
16. Team data, board and inbox
17. Routines: locks, scans, day rhythm
18. Slack
19. Email, Trello, Atlassian
20. Questions, decisions and review
21. Permission refusals and grants
22. Test instruments

---

## 1. Dispatcher and code layout

- **One dispatcher.** `DistroAgentsTools.fn.sh` has exactly one top-level function and one `case`, like
  every sibling `Distro*Tools`. New operations go inline in that `case`. Never a separate
  `DistroAgentsTools<OpName>` function per operation.
- **A helper shared by one family lives in that family's include**, not at file scope.
  `AgentsToolsAssertBareName` (in `AgentsContext.UseAgentsTools.include`) is the bar for "general";
  it is not licence to add more file-scope helpers.
- **One arm per group of operations.** A family arm sources one include, or several when one gets too
  big. Size is the only reason to split. A family arm works only because every stub of that family
  lives in the include it sources. A stub placed in another file is not routed, and nothing reports it.
- **Order matters.** The comms routes come before the `--member-*` route, or the broader glob takes
  them. An arm that claims a prefix (`--intern-op-slack-*`, `--intern-op-item-*`) must have any
  differently-routed op of that prefix above it.
- **Family routes.** `--magic-comms-*` → `AgentsTools.MagicComms.include`. `--client-comms-*` →
  `AgentsTools.ClientComms.include`. `--member-comms-<service>-*` and `--intern-op-comms-<service>-*`
  share one arm per platform. `--intern-op-atlassian-*` → `AgentsTools.InternOpAtlassianCall.include`.
  `--magic-<routine>-*` → `AgentsTools.Magic<Routine>.include`, one explicit arm per op even where
  two arms are identical today.
- **All non-member Slack code is in `sh-lib/AgentsTools.CommsSlack.include`**: the shared helpers and
  `--intern-op-slack-call`, `-check` and `-check-scopes`. The dispatcher holds no Slack code. Any
  include may source that file just for its helpers: its `case` ends in a branch that runs nothing for
  a name that is not its own. An unimplemented `--intern-op-slack-*` name is still refused there.
- **One operation calling another** recurses into `DistroAgentsTools` itself, never a private helper
  (the `DistroLocalTools --upgrade-installed-tools` precedent).
- **An external caller runs a script; an internal caller sources the include in a subshell.** A script
  also sets up the execution context, which is why the MCP daemon execs the tooling. Re-entering the
  whole script makes an internal caller pay for option parsing twice.
- **`--intern-` is a namespace, and the next segment is the kind.** `--intern-op-*` is operations,
  `--intern-tool` is tools (the harness arm that runs one tool and exits). `--intern-mcp-*` and
  `--intern-main-loop` follow the same shape. A new kind needs the human-owner's approval.
- **Prefix rule for a new operation**: `--intern-*` when tooling uses it,
  even if member stubs call it too; `--intern-op-*` only when member stubs alone use it; `--member-*`
  for any member, the tooling checking access on its arguments; `--magic-*` for the coordinator only;
  `--owner-*` for the human. About 25 older `--intern-op-*` ops used by tooling break it, and are
  renamed later in one approved sweep.
- **`--intern-*` is left out of the help.** Out of `Help.DistroAgentsTools.include` syntax lines and out
  of the help.md reference and examples. A public entry that must contrast itself with an internal op
  says so in behavioural terms, without naming the internal op.
- **A superseded operation name stays as a working shim**: gone from help, kept in the dispatcher,
  until a removal is approved.
- **A process that loaded the dispatcher before a routing change keeps its old arm table.** A bare-name
  call there can route to an include that no longer exists. A call by full script path is not affected.
  The process must restart.
- **Comments**: one short line inside code, a few lines at most in a header. Anything longer belongs
  here. Large comment blocks cost load time.
- **The console launcher has no help pair of its own.** `DistroAgentsConsole.sh` is generated like the
  four sibling `Distro*Console.sh` launchers, and none of them implement `--help`.

## 2. Environment and context resolution

- **`AgentsContext.include` is a parallel kernel, not a subset of `SystemContext.include`.** It defines
  `Require`, `Agents` and `DistroAgentsContext` only. Inside `DistroAgentsTools` and on the MCP
  `execute` surface, `Distro`, `Action` and `DistroSystemContext` are undefined until bootstrapped, and
  `PATH` has no `sh-scripts` directory.
- **The bootstrap guard `[ -z "$MDLT_ORIGIN" ] || ! type DistroSystemContext` is what makes a later
  `Distro <Tool>` resolve.** Never remove it as redundant. A new site that needs those functions needs
  the same two lines.
- **`Require <Tool> || :` comes before `Distro <Tool>`.** `Require` resolves by file through
  `$MDLT_ORIGIN`; `Distro` tries `type`, then `PATH`. The `|| :` leaves the verdict to `Distro`'s exit.
  Sourcing `SystemContext.include` alone is not enough: `Distro` still fails, because only a console
  session has `sh-scripts` on `PATH`.
- **This context keeps origin resolution local** and delegates the rest, because it must serve
  remote-only and deploy-only workspaces. Its `SetInputSpec` is the parent's with the tier half removed;
  it sets no `MDSC_*`. Making it an alias of the system context breaks `.local`-only workspaces.
- **An index read always goes through the system dispatcher.** `ListDistroProjects` and
  `ListDistroDeclares` call `DistroSystemContext` inside their own bodies.
- **Environment init in `DistroAgentsTools.fn.sh`.** `: "${MDLT_ORIGIN:=$MMDAPP/.local}"` at file load is
  only a default. The real init is in the tail guard (the executed-only `case "$0"` arm, above the help
  branch): `DistroAgentsContext --run-from-detect`, then `DistroAgentsContext --distro-path-auto`.
  `--run-from-detect` enters `AgentsContext.include`'s idempotence guard (`--init-variables|--run-from-detect`),
  which sources `AgentsContext.SetInputSpec.include` when `MDLT_ORIGIN` or `MDLT_OPTION` is empty.
  `--distro-path-auto` has no arm there; it falls to the `*)` delegation and reaches
  `SystemContext.SetInputSpec.include`, which reads `MDLT_CONSOLE_ORIGIN` and re-exports `MDLT_ORIGIN`.
  An operation arm cannot do this work: the bootstrap and the `MDAT_DATA_ROOT` preamble run before the
  `case`. A sourced caller must never trigger it.
- **`MDLT_OPTION` is the only witness that resolution ran.** The file-load default always sets
  `MDLT_ORIGIN`, so a guard on `MDLT_ORIGIN` alone is dead code here. `DistroSourceTools.fn.sh` and
  `DistroDeployTools.fn.sh` do not default it, so the same test is live there.
- **A caller must not export both `MDLT_ORIGIN` and `MDLT_OPTION`.** That skips resolution and takes the
  pinned origin unchecked. An arm sourcing an include missing from the pinned tree exits 1 with a bare
  file-not-found (an MCP host cannot explain it); where the include exists, a stale copy answers
  confidently. This is why the `myx.distro` MCP registration writes no `env` object.
- **A command run through an operation inherits the resolved environment.** That is why the MCP
  `execute` lives here: `myx.common`'s MCP path does no environment init.
- **Reaching a `List*` tool.** `Require <Tool> || :`, then `var="$( Distro <Tool> … )" || status=$?`,
  which keeps `ListDistroDeclares`' own `set -e` inside the subshell. Never spawn
  `ListDistroProjects.fn.sh` by path: a new process rebuilds every index (see `myx.distro-system`
  MAGIC.md).
- **An `MMDAPP=` prefix on such a call is checked before it is dropped.** It is a no-op where the arm
  resolves through the distro context, and load-bearing where the arm reads `$MMDAPP/...` directly
  (`DistroSourceTools --list-namespace-roots`).
- **`myx.distro-.local` generates a wrapper named `DistroAgentsTools`** (`Distro<ITEM>Tools`). It is
  install-time and subshell-scoped and never meets this package's tool at runtime.
- **`myx.common`'s `setup/agentMcp` and `remove/agentMcp` are not for this package.** They act on the
  `myx.common` registration; `remove/agentMcp` would delete it. Call `myx.common` public commands only;
  copy an internal idiom rather than reach into it.

## 3. Shell and awk gotchas

- **An `EXIT` trap set inside an op replaces the caller's.** Every op is an arm of one function in one
  process, and `trap - EXIT` then clears the caller's too, silently. An op reached through `$( )` runs
  in a subshell and cannot do this; a plain call can. Explicit cleanup on every return path misses
  `set -e` aborts and signals. The form with neither defect is a trap inside a `( … )` subshell, armed
  before the file is created (examples: `--owner-workspace-forget`, `LocalTools.Config.include`).
  `--intern-op-slack-call` installs and clears its own trap, so callers of it install none.
- **`$( … )` returns when the pipe has no writers, not when the command exits.** Never capture an
  arbitrary or caller-supplied command that way: a background child holds the pipe open forever. Write
  to a file and read it back; `wait "$pid"` where needed. `$( )` is fine for our own self-contained
  commands. A `$( )` capture also truncates bytes at the first NUL.
- **`set -e` containment around executed code**: `( set -e ; eval "$( cat )" ) || execStatus=$?`, then
  `set +e` before returning non-zero. Dropping the `||` kills a long-running server on any failing
  script.
- **A bracket range in a `case` pattern is collation-dependent.** Under `en_US.UTF-8`, `[a-z]` matches
  `A`. Enumerate every accepted character instead. Use named classes like `[[:cntrl:]]` only as a gate.
- **awk built-in names (`close`, `index`, `length`, `split`, `sub`, `system`) as parameter names are a
  parse error** with a misleading message. Two-word camelCase names cannot collide
  (`magic-developer/reference/code-craft.md`).
- **Never `RS='\0'` to slurp a file.** It becomes the empty string, which is paragraph mode: everything
  after the first blank line is dropped. Use `RS="\004"` or rejoin records.
- **Pass text to awk through `ENVIRON`, never `-v`.** `-v` decodes backslashes: paths break and a literal
  `\t` becomes a tab.
- **An awk function that is not loaded fails at call time, not load time** (exit 2 in gawk and
  one-true-awk). A stream whose first records do not reach the call runs fine, then dies.
- **`mv -n` returns 0 when it refuses to overwrite** (Darwin). Test `[ -e ]` before the move.
- **`mv` keeps mtime.** A file moved somewhere that starts a clock needs `touch`.
- **`stat(1)` differs by platform.** Probe the flavour once against `/`. A `bsd || gnu` retry
  concatenates partial output. For ordering, `ls -tr` avoids `stat` entirely.
- **`date(1)` arithmetic is not portable** (`-v+30M` vs `-d '+30 min'`). Use `date +%s` and shell
  arithmetic.
- **`uuidgen` prints upper case**; a `--session-id` must be lowercased.
- **bash 3.2**: no `lastpipe`, so a `| while read` loop's variables are lost (use files). `wait` returns
  early when a trapped signal arrives; re-wait with `while kill -0 "$pid"; do wait; done`. Under
  `set -e`, an `EXIT` trap sees `$?=0` after a syntax error. A failed redirection on a special builtin
  ends a POSIX shell (FreeBSD `sh`).
- **After `curl … | while read`, test `${PIPESTATUS[0]}`**, captured on the next line, not `$?`.
- **`mkdir` is the lock primitive.** `flock` is not on bare FreeBSD or Darwin.
- **A spin loop whose counter resets after each sleep is not bounded.**
- **`kill` a job's process group, not its pid.** Fork under `set -m` and put the whole pipeline in the
  backgrounded subshell, or `$!` names the last process while the group id is the first.
- **`nohup` sets `SIGHUP` to ignored in the child.** Use `SIGUSR1` to signal a holder.
- **`myx.common lib/catMarkdown` drops `_` everywhere**, backticks included (`ANTHROPIC_API_KEY` prints
  as `ANTHROPICAPIKEY`); only fenced blocks survive. This already affects `--help`. The fix belongs to
  `myx.common`.

## 4. Writing code here

- **Conventions come from `myx.distro-source` and `myx.distro-deploy`.** This package is the drifted
  one. A pattern found here is not precedent until a daily-used sibling confirms it. A count of sites
  in this package proves nothing.
- **Prefer awk or POSIX shell in `sh-lib/`.** Use Python only when needed, and say why at the call site.
  `python3` is a real runtime dependency of comms and session-context paths, but not of a bare
  `--owner-setup-*` run.
- **A parser already exists for every shape we read** (frontmatter, board headers, Slack JSON,
  markdown, RFC822). Extend one; do not write another. JSON field readers are copies of one engine
  (`AgentsSlackJsonField.awk` and its lineage, `AgentsHarnessJsonField.awk`).
- **Tests and fixtures live in `sh-test/` and `sh-test/check-fixtures/`.** Anything production code
  calls stays in `sh-lib/`. A check keeps `rigHere` at `sh-lib` and uses
  `rigTest="${rigHere%/sh-lib}/sh-test"`.
- **Generated content has two shapes only**: a body file at zero indentation (the caller indents), or
  one `printf`. No heredoc, no stack of `printf` lines, no `eval`-expanded template. A runnable artefact
  is a real script installed by copying. A refusal message lives in the file that says it.
- **Installing a generated file over its target**: the writer emits, the caller installs, through a temp
  beside the target and a same-directory rename. Several temp spellings exist (`<t>.$$` in a trapped
  subshell, `<t>.$$.tmp`, `mktemp <t>.XXXXXX`, `<t>.tmp.$$` in `AgentsTools.Install.include`). Do not
  convert one to another; a new site uses its file's form. Never under `/tmp` (no atomic rename, symlink
  planting). Set a mode on the temp, never the target. Check the entry landed by re-running the
  idempotent writer and comparing.
- **Scratch paths**: `mktemp -d -t "<prefix>-XXXXXXXX"`, or `$MMDAPP/.local/temp/<name>.$$` spelled out at
  each use. `${TMPDIR:-/tmp}` is only for code that runs where no workspace exists. Concurrent scans
  share one `$$`, so they use `mktemp`.
- **Severity marks**: `⛔ ERROR` for a fault, `🙋 WARNING` for a designed refusal. Keep the asymmetry. A
  warning inside a composed operation is lost in scrollback, so the closing summary repeats it.
- **The bare-name gate** (`AgentsToolsAssertBareName`) validates every member, item and document name.
  Never inline a `case "$x" in */*|.|..)` copy: it accepts spaces, `:` and a leading `-`. It returns 1
  and never exits.
- **A number is refused, never coerced** (`AgentsToolsAtlassianAssertNumber`). A value that reaches a
  query string unchecked can add parameters of its own.
- **Syntax lines**: `|` is exactly one of; `{a|b}` is at least one of; `[ ]` is optional; a set that is
  all required is joined with `/` (`JIRA_SITE/JIRA_USER/JIRA_API_TOKEN missing`).
- **Decide on structure, not message text**: an exit code, a field's presence, a status. Where text is
  all there is, match it exactly and anchored. A change whose scope was picked by a phrase silently
  misses sites that do not use the phrase.
- **`AgentsToolsClientToolPolicyFormatVersion` has no reader** and versions a record format that is gone.
  It stays until the human-owner says whether it is residue or intent.

## 5. Configuration and local state

User-facing behaviour is in [docs/configuration.md](docs/configuration.md).

- **Config lives in `$MMDAPP/.local/.agents/<entity>.agent.env`**, one scope per file, read through
  `--agents-config-option` at the moment a call needs it. Nothing is baked in at install time.
- **A read never creates a scope; a write does.** `LocalTools.Config.include` answers an absent scope
  directly. A typo'd or missing sub-command falls through to creation and then errors, leaving a
  phantom scope that looks like a configured member.
- **A new scope file is empty, mode 660 under a 770 directory.** Existence tells nothing; test `[ -s ]`
  or parse for the key. Any op that takes a member name checks
  `[ -d "$HOME/.claude/skills/<member>" ]` (or the member index) before its first config access.
- **Credential store guards.** `--owner-credential-store-verify` flags any `*.agent.env` not 660 and the
  directory not 770; it guards against chmod-ing the target instead of the temp. `-self-test` runs the
  chain under `umask 022` with a probe key. `-harden` fixes the two cases that never heal: a scope never
  written again, and a directory where no new scope is added.
- **`--owner-cleanup-purge` empties `$MMDAPP/.local/.cleanup` only, and takes no argument.** It exists
  because a blanket `rm` deny in the permission engine cannot be carved out by a narrower allow. It is
  not a general `rm` wrapper.
- **`.local/agents` is durable and nothing sweeps it.** The purge empties one folder; the team-data GC
  scans team-data locations only, plus `spawned/` folders linked to items it deletes. A new per-run
  directory under `.local/agents` needs its own named removal, decided before it is first written.
- **A console channel dir holds fifo, log, pid and meta only.** `--console-stop` removes it whole. A
  credential is sourced into the console environment, never staged there.
- **There is no file-drop queue**, by design. The FIFO plus a log sentinel is the queue for one producer.
  No queue/working/finished protocol exists in the family to follow.

## 6. Our data, and the files we generate for others

- **The rule: our harness and tools read only our own data and indices.** They never read back a file
  we produced for another product. The flow is one way: primary data → our index → derivative files.
- **Derivative, never input**: `.claude/settings.json`, `.claude/hooks/*`, `.local/agents/mcp.servers.json`,
  `.mcp.json`, `.vscode/mcp.json`, `~/.claude.json`, `.claude/copilot-add-dir.fragment`, and the member
  symlinks in the vendor link folders (`~/.claude/skills`, `~/.agents/skills`, `~/.copilot/skills`,
  `<ws>/.claude/skills`, `<ws>/.agents/skills`). A hook or server added by hand there reaches that
  external tool only. Reading one to verify it was written right is fine (`AgentsClaudeSettingsVerify.awk`,
  `AgentsMcpServerJsonVerify.awk`, the setup checks).
- **The harness `Skill` tool still serves a real folder** a user or vendor put in `~/.claude/skills`. A
  link there is ours and is skipped.
- **Primary sources and our indices** (in `.local/agents`):
  - hooks: `AgentsToolsClientToolPolicyHookRecords` (`AgentsTools.ClientToolPolicy.include`) →
    `harness.hooks.index`, valid while its version and the `cksum` of the policy and
    `AgentsHarnessHooksLoad.include` match;
  - MCP servers: `AgentsHarnessMcpServersPrimary` (`AgentsHarnessMcpConfig.include`) → `mcp.servers.index`;
  - access roots: `AgentsTools.ClientAccessRoots.include` → `harness.roots.index`.
  An index that does not vouch for this run is ignored, and the same producer code computes the answer.
  A stale index only costs time.
- **`harness.roots.index`** is written by `--make-harness-indices` with `MDLT_ORIGIN` empty, so one index
  serves every origin. Its fingerprint covers workspace, `HOME`, `MDAT_SKILLSET_ROOT`, the names under
  both member-link directories, and the `cksum` of the include, the index code, the grants registries,
  the two place registries and `grants.index`. Origin-derived roots and a member's own scratch
  roots are merged at run time. It cannot see a link retargeted outside those directories, or one
  retargeted in the same second the index was written.
- **Where team data lives: two places.** A workspace's own data (`members.registry`,
  `permissions.registry`, `permissions-tags.registry`, `grants.index`, indices) is in `$MMDAPP/.local/agents`.
  `$HOME/.agents/magic-team/` holds only what exists and where to look: `members.registry` (member,
  workspace root, link kind, path, member dir, TAB-separated), `directories.registry` (pointers: place
  name, workspace root), `member-homes.registry` (member, home workspace root), and
  `permissions.registry` (pointers to workspaces that publish grants; needed machine-wide because
  `~/.claude/settings.json` is machine-wide). Defined in `AgentsTools.TeamRegistry.include`.
- **Places** (`AgentsTools.Places.include`). A place is a `workspace` (always read-write) or a
  `directory` (`read-only` or `read-write`); registering one grants nothing. A workspace's own
  `.local/agents/directories.registry` holds its places for this host (name, kind, ceiling, path,
  declared-by), its own row first, from its `magic-team:directory:` and `magic-team:workspace:`
  declares (host glob last, as for `team-member`), and the owner rows of `--owner-workspace-upsert`.
  `--intern-directory-register` rewrites it on every update, and its pointers, each under its lock; an
  unread project selection keeps the declared rows. The merged list (`--owner-workspace-list`) reads
  every workspace's file through the pointers. The same name and path is one place; the same name with
  another path: the local row wins, else one warning and `name@workspace`. `--intern-directory-resolve`
  and `--intern-directory-of` (`name:relative`) resolve through it; members read it by name only
  (`--member-directory-list`, `--member-directory-path`), and the projects by `--member-namespace-list`,
  all three routed with the place ops and never switched to a member workspace. The workspace roots the member
  resolver and the `*` grant expansion walk are its `workspace` rows plus every pointer root.
  `known-workspaces.registry`, the earlier list, is never written: it is read as owner rows until the
  first registration or owner op imports it, then its `.imported` marker ends its reading.
- **Member homes** (`AgentsTools.MemberHomes.include`). `--intern-member-home-register` registers the
  members a registered workspace without agents declares, by the member scan, as `source-declared` rows
  under that workspace's root (a `.` in their grants unrolls to it; nothing is installed there; their
  operations run where they are asked). It then picks each multi-workspace member's home: a copy a
  workspace with agents registered, then the most `magic-team:` lines naming it, then a source link,
  then the first row; one warning when the copies differ. The machine `members.registry` keeps every row.
- **The member index** `$MMDAPP/.local/agents/members.index` and its `members/` view hold this
  workspace's own members only. Built by `--install-skillset-symlinks` and `--make-agents-indices`; a
  rewrite drops any link to another workspace's member. A member of another workspace is never
  materialised here: a reader that names one (routing, a spawn, the client sweeps) finds it through
  the machine-wide registry (`AgentsToolsTeamMemberDirectory`, the row holding its source preferred),
  and its operations run in its own workspace (`AgentsToolsMemberWorkspaceResolve`).
  `MDAT_SKILLSET_ROOT` defaults to `members/`; consumers read the variable and never spell the path.
  No fallback to a vendor link folder.
- **Sites that stay `$HOME` on purpose**: the `--scope user-home` fan targets, `~/.claude/settings.json`,
  `~/.claude.json`, and `~/.agents/magic-team/`.
- **`--install-claude-permissions` writes the machine-global `~/.claude/settings.json`** from the member
  index of the workspace it runs for, plus every workspace's grants. It reads the permissions
  registries and writes none; what it projected is kept in `claude-permissions.projected`, for the next
  run's drop of what no registry claims any more.
- **The workspace set is a publication list, not team membership.** A member absent from the current
  workspace is not an error.
- **The access-root set is defined once, in `AgentsTools.ClientAccessRoots.include`.**
  `AgentsUniversalHarness.sh` uses it whenever no `--access-root` is given. The copilot fragment is a
  consumer, never a source. Where the include is missing, the harness refuses; it never falls back.
- **The workspace root is not in the access set, and `MAGIC.md` is why.** Every `MAGIC.md` sits in a
  git-tracked project tree under `$MMDAPP/source`, which is granted. The workspace root holds nothing
  worth reading. Installed copies under `.local/myx/` are deliberately unreachable. Do not widen the
  include.
- **A root flag replaces the whole default set**, and `--access-write-root` narrows writes to the roots
  it names. Adding one write root to grant a work directory revokes every other write, and the call
  still succeeds. The include keeps reads and writes apart; a verb-less flag like `--add-dir` cannot,
  so there a read root is also a write root. Writes are the work directories plus the roots a declared
  `Edit` grant names.
- **A grant's cost is two numbers.** What the glob matches for claude, and what it widens to for copilot,
  whose `--add-dir` takes no glob and grants the containing directory. `namespace:` declares carry no
  glob and grant the whole tree; use `project:` or `workspace:` for a narrow grant.
- **Workspace paths are machine data.** `--owner-workspace-*` keeps them in the places registries
  above, never in a skill folder. A skill folder is a symlink into a repository's
  working tree, so data must never be written there. `.gitignore` keeps
  `skillset/magic-team/human-owner/human-owner.workspaces.md` out of the package.

## 7. The `--owner-setup-*` family

User grammar is in [docs/commands.md](docs/commands.md); per-domain manuals are `--help-setup-<domain>`.

- **A domain declares; `--intern-op-owner-setup` carries out.** Option handling lives in that one
  primitive, so a shared option is applied once. An option is accepted only by a domain that declares
  it; a flag accepted and then ignored is the failure this prevents. The engine's mode words
  (`--render-full`, `--render-missing`) are internal.
- **A setting is judged by its value at its use site.** Unset or empty is FAIL. A config file existing is
  never the check. An installation artefact (console script, access fragment) is judged by presence.
- **Settings and preconditions are separate lists.** A setting is a value the engine stores; a
  precondition is a state of the installation. `--apply` carries out both. For `claude`: settings are
  the workspace root and service selection; trust, console freshness and access grants are preconditions.
- **Workspace trust** is a boolean in `~/.claude.json`, not one of our options. `--apply` sets it first,
  because claude discards `permissions.allow` of an untrusted workspace. Writer
  `AgentsClaudeProjectTrustUpsert.awk`, reader `AgentsClaudeSettingsVerify.awk`; the replacement keeps
  the file's mode. An absent, symlinked or unparsable state file stops the run.
- **`--apply` sequence**: trust; the engine call (subject and settings); workspace integrations for a
  domain declaring `SPAWN_CLI_SERVICE`, only if
  the diagnosis fails first; then the diagnosis, whose status becomes the op's. Each step runs in its own
  subshell and is tested, so a step that aborts (bash 3.2 suspends `set -e` in tested subshells) does not
  skip the handler that names it.
- **A bare call names one command: `--apply`**, plus `--set-as-default` where a selection must be
  repointed. It lists required-and-unset options only. An optional option shown beside a required one
  reads as a blocker. A step is printed beside `--apply` only where nothing can carry it out.
- **A `--service-key <KEY>` value is neither required nor optional.** `SPAWN_CLI_SERVICE` is declared
  `--allow`, because `--apply` writes it from `--service-value` and a `--require` would refuse the call
  that supplies it.
- **Every blocking finding is either carried out by `--apply` or yields a prose setup step.** The one
  `claude` finding nothing carries out: a member link pointing at a second copy, because
  `--install-skillset-symlinks` never moves an existing link.
- **A diagnosis answers about the current `$MMDAPP`.** `--all-workspaces` is opt-in and reads roots from
  the machine-wide `members.registry`.
- **`--install-command` is declared only where `myx.common` carries an installer.** With a probe and no
  command, the engine reports "is not installed and this domain declares no way to install it". A new
  CLI domain gets no install command until one exists.
- **Removing a setting has two spellings, and a fix covers both**: `KEY=` on stdin and `--<option> ""`.
  The front end tests a missing value by argument count, never `-z "$2"`. The engine refuses to remove a
  `--require`d key.
- **Removing works only where absence has a meaning.** Unset `TEAM_DATA_DIRECTORY` means the
  workspace's own store, `$MMDAPP/.local/agents/team-data-root`, resolved in
  `AgentsContext.UseAgentsTools.include`. Every reader follows that one answer; a check demanding the key
  reintroduces the refusal.
- **`--print-apply-command` renders placeholders single-quoted everywhere.** Bare `<` and `>` are
  redirections. A secret renders as a stdin-fed form (`KEY='<placeholder>'` lines into
  `--values-from-stdin --apply`). A value to store is refused here.
- **Per-domain manuals** are `sh-lib/help/Help.DistroAgentsTools-setup-<domain>.help.md`, routed by glob
  from `--help-setup-<domain>`, printed with `cat`, never `catMarkdown`. Their option blocks use the
  `--member-help` grammar (`##  Heading:`, two-tab flag line, three-tab prose), so the same awk can cut
  them. An option's `how-to-obtain` line in `AgentsToolsOwnerSetupOptionSpec` and its manual block are
  written separately; a new option gets both.
- **Help depths are separated in `Help.DistroAgentsTools.include`.** Every `echo` line there stays flush
  left, inside `case` arms too: `--member-help` cuts the file with a `^echo "` anchor, and an indented line
  is printed with its `echo "` prefix.
- **The copilot access fragment has no user-facing op.** `--install-copilot-access-fragment` is an
  internal step of `--install-workspace-integrations`; printed lines and remedies name
  `--make-workspace-integrations` instead.
- **`--owner-setup-scaleway`'s install probe is a file test**, appended after the shared
  `command -v` probe; the engine takes the last occurrence. No install command: the leg ships with the
  release.
- **`--owner-setup-scaleway --check` runs the harness instruments** (section 22), gated on `--check` so
  `--apply` neither pays for them nor fails on a diagnostic.

## 8. Installation and integrations

User steps are in [docs/installation.md](docs/installation.md).

- **`--make-workspace-integrations`** runs `--intern-directory-register`, `--make-agents-indices` (its
  grants are unrolled over the places just registered), `--make-console-command`, `--install-workspace-integrations`, `--intern-member-home-register`, then
  `--install-workspace-restrictions` only when `.claude/hooks/deny-native-tool-reroute.sh` exists, then
  `--make-harness-indices` last. Workspace registration is this step's, never a member install's.
- **`--install-workspace-integrations`** calls `--install-vscode-integrations`,
  `--install-skillset-symlinks`, `--install-claude-workspace-trust`, `--install-claude-permissions` and
  `--install-copilot-access-fragment`. With `--install-workspace-restrictions` it is one of the two root
  install methods in the default syntax.
- **MCP registration targets this workspace only.** Never another workspace's origin or config. A host
  starts its server once per session with workspace variables unset and its own project directory as
  cwd, so a server resolves its environment at its own entry. An `env` object freezes values at install
  time and goes stale silently.
- **A command path holding a `myx.common` directory component is pruned as a duplicate** by the
  myx.common writers. Keep other servers' binaries outside such a component. The `myx.common` entry
  points at `.local/myx/myx.common/`, never `$MYXROOT`.
- **`sh-lib/AgentsMcpServerJsonUpsert.awk`** upserts one entry by key, reads the whole file itself
  (default `RS`, `LC_ALL=C`), prints the new document, and never opens the target. Params through
  `ENVIRON`: `MYX_MCPUPSERT_TOPKEY`, `_ENTRYKEY`, `_COMMAND`, optional `_ARGS` (JSON array) and `_ENV`
  (JSON object). It splices, so other keys survive byte for byte. It prunes nothing. It fails closed:
  exit 1, one-word reason, empty stdout. `.vscode/mcp.json` is pruned earlier by `myx.common`'s writer.
- **An installer-owned MCP file that cannot be read or parsed, or whose top level is not an object, is
  removed** before re-registration. A valid file with a bad entry is repaired in place.
- **VS Code folder links.** The workspace root is never a VS Code folder. `AgentsToolsVscodeFolderLinks`
  links each authoritative path into every listed folder as `<folder>/<slot>`. A slot that already
  reaches the target (by any link) is kept; that check comes first, so a parent link cannot delete the
  original. A dangling link is reclaimed. Other installer output in a slot is replaced. A real folder
  holding the target itself is an error. A slot outside the workspace is left alone with a warning.
  Linked: `.agents/skills`, `.claude/skills`, `.vscode/mcp.json`, the panel.
- **The Magic-Team panel** is one unpacked copy in `.local/agents/vscode-magic-team-panel/` (rewritten
  when its `.payload-sum` changes, by two renames), linked as `.vscode/extensions/magic-team-panel` into
  every folder and the workspace root, and as `$HOME/.vscode/extensions/magic-team-panel`. Real content
  in `$HOME` is warned about, never removed. `extension.js` picks the installed layout when
  `magic-team.basic.md` sits beside it, else the development layout through
  `../../skillset/magic-team/magic-team/`.
- **VS Code skill discovery** (read from the installed build; re-read before relying on it):
  - one directory level, a literal `SKILL.md`; built-in locations are `.agents/skills`, `.github/skills`,
    `.claude/skills` per folder and the same three under `~`;
  - `chat.agentSkillsLocations` is additive; relative keys resolve against every folder; `~/` keys once;
    absolute paths and glob characters are rejected and dropped with a log line;
  - the setting is `restricted`: an untrusted workspace shows no members;
  - a member is skipped for a missing or mismatched `name`, missing `description`, parse error, or a
    duplicate `name` in a higher-priority location (workspace, user, plugin, extension). None of this is
    visible on disk; read what discovery decided.
  So workspace-root members reach VS Code by the home fan and by folder links. The emitted key
  `$MMDAPP/.agents/skills` adds no discovery; it exists because `AgentsTools.Install.include` checks the
  setting's name is present.
- **`.claude` is the primary of the three install names.** Rules and hooks live there; `.agents` and
  `.github` carry members only.
- **`--install-skillset-symlinks` has two flags.** `scanDiscoveryTrusted` (may an absence be acted on;
  drives removal) and `scanDiscoveryError` (did something fail; drives the exit). An empty project
  selection exits 0 but never removes, because a namespace without `repository.inf` is never scanned and
  looks the same. A real discovery failure exits 1. An empty selection is never passed to
  `ListDistroDeclares --select-from-env`.
- **`$workspace` is `${workspaceArg:-$MMDAPP}`** in the permissions and symlinks ops.
- **`--make-agents-indices`** (`AgentsTools.Make.include`) rebuilds `team-members.registry` and
  `team-members-names.registry` from the list in `AgentsToolsRegistryAgentsIndicesBuild`
  (`AgentsTools.Registries.include`); a new registry is one line there plus `Rows`/`Rebuild` functions.
  Rows exist only for members with a path in this workspace. Names come from the member's `basic.md`
  (`- **Name**:` as plain words, split at the first space; alias and mark via
  `AgentsToolsCommsSlackMemberMarks`), overridden by scope keys `FIRST_NAME`, `FAMILY_NAME`, `ALIAS`.
  Invalid values store `-`; a stored space is `_`. Every `client-*` row takes the persona member's values
  (`registryPersonaMember`). Missing fields warn on stderr, never fail. It also runs as the source-prepare
  builder `1201-agents-indices.sh` (parallel with `1201-increment.sh`).
- **It also builds the grants** (`AgentsTools.Grants.include`): `permissions.registry` and its tags from
  the declares of this workspace and of every registered tooling workspace without agents (`.` there is
  that workspace; `namespace` applies in every tooling workspace; `workspace:<pattern>` such as `*-testbed`
  is every workspace place whose name matches, tagged `wildcard`, none matching no error and no row;
  `directory:<name>` resolves through the places and is capped to read on a read-only one; an unknown
  name is an `unresolved` row, warned), plus
  each acting member's own directory and magic-librarian's read of `source/**`; then `grants.index`,
  every workspace's registry fully unrolled per member, with the floor (`.local/temp/**` write in every
  tooling workspace; where agents are installed, read `source/**/{MAGIC.md,README.md}` and
  `source/**/docs/**.md`, write `source/**/MAGIC.md`; the readable member directories and reference
  roots) and the places' ceilings, deepest first. Never edited at runtime; a reader finding it stale
  (older than any registry it is made from) or missing rebuilds it the sibling way: the generator in a
  tested subshell into `<file>.$$.tmp`, then `mv -f`, the old file kept on a failure, in memory where
  `.local/agents` is not writable. `source/**` is in no floor: other members read it by namespace grants.

## 9. Hooks and workspace restrictions

User view: [docs/installation.md](docs/installation.md#workspace-restrictions-optional).

- **Restrictions are a manual opt-in.** `--install-workspace-restrictions` writes the hooks, the
  `settings.json` entries and `autoMemoryEnabled: false`. Nothing installs them behind the user's back.
  Once installed (the reroute hook is present), `--make-workspace-integrations` keeps them current.
  `--install-workspace-integrations` passes an empty hooks list.
- **A hook binds every agent on the machine.** Wiring one is the user's decision. An op that silently
  wires a hook is a defect.
- **Each hook is one real script in `sh-lib/client-hooks/`, installed by copying.** Nothing is templated
  into it. The harness runs the package's script, never the `.claude/hooks` copy.
- **A deny hook uses shell builtins only.** A missing external binary yields empty stdout and exit 0,
  which reads as allow. Fail closed on anything unparsed.
- **Two kinds of hook.** A REROUTE drains stdin unread, denies every call alike, and names the MCP method
  to use instead; it applies to `*-native` clients only. A CONDITIONAL guard reads the payload, matches
  one thing, allows the rest, and applies everywhere, our harness included. Do not mix them. A reroute is
  a router, not a security wall.
- **`AgentsTools.ClientToolPolicy.include` is the single source** of the reroute set, hook paths, every
  hook record with its class, and entry keys. The refusal wording lives in the hook script. The script's
  last arm denies loudly, since no decision reads as allow.
- **The reroute set carries only tools whose native-call test passes** in
  `sh-test/AgentsHarnessNativeCallCheck.test.sh`, because the twin becomes the only path. `AskUserQuestion`
  and `PushNotification` are off it (different argument shapes). `Bash` is on it with twin `execute`;
  native `timeout` (ms) and `run_in_background` differ from `execute`'s `timeout` (s) and `background`,
  awaiting a ruling. Removing a tool stops new installs writing it; an existing entry stays, so the
  script keeps its arm.
- **A tool needs a matcher and a `tool_input` arm to be routed.** `Skill` has neither today, and presents
  `name`/`file`/`list`, not `file_path`. Whether it should be routed is open.
- **Retiring a hook takes the file and its `PreToolUse` entry.** An entry running a missing file exits
  127: a native client reads that as allow, the harness refuses every matched call.
  `AgentsToolsClientToolPolicyRetiredHookNames` drives both; files are deleted after `settings.json` is
  rewritten. `AgentsToolsClientToolPolicyRetiredDenyEntries` lists old static denies to drop by exact
  match. Those are the merge's only removal paths.
- **A registered hook script that is missing or not executable fails the install and the
  `WORKSPACE_HOOK_SCRIPTS` check**, foreign hooks included.
- **Memory guards.** The client's machine-local memory (`~/.claude/projects/*/memory/`, `MEMORY.md`) is not
  team knowledge. `deny-memory-md-read.sh` refuses `Read`, and `Glob`/`Grep` reaching into the store;
  `protect-memory-md.sh` refuses `Edit`/`Write`. They decide by spelling, resolved location and `-ef`.
  Class `all`. They do not see shell commands or a store moved by `autoMemoryDirectory`. They answer
  with where team knowledge lives (MAGIC.md, reflection, inbox note, escalation).
- **Copilot memory**: every `copilot-native` launch passes `--excluded-tools=` from
  `AgentsToolsClientToolPolicyCopilotExcludedTools` as one comma-joined token (the variadic form swallows
  later arguments).
- **A hand-wired entry is recognised by its key** and adopted as the policy's own, with its script
  replaced.

## 10. The agents console

User view: [docs/use.md](docs/use.md#running-the-agents-console).

- **It starts an agent CLI, not a shell dispatcher.** A piped line is a prompt. A read-only tooling call
  through it costs a full model round trip. Run `DistroAgentsTools.fn.sh` directly for reads. Whether a
  write is equally safe by the direct path is not established (the console may supply identity or locking).
- **Known names** (`DAGC_KNOWN_CLIS`, also the `--cli-auto` ranking): `copilot copilot-native claude
  claude-native grok grok-native scaleway`. `AgentsTools.Owner.include` mirrors it.
- **A leg is a file.** Any `sh-lib/Agents<Name>Harness.sh` declaring `HARNESS_PROVIDER_NAME=` is leg
  `<name>` (lower-cased): today `claude`, `copilot`, `grok`, `scaleway`. `AgentsUniversalHarness.sh` and
  `AgentsAnthropicStub.sh` are not legs. A new leg is one new file; it joins the auto-scan and the
  non-interactive set at the tail.
- **`DagcLegFileFor` resolves a name to its leg file** from a table built once at the top, so presence,
  exec, flags and credentials all use the same path. `DAGC_VENDOR_CLIS` (`copilot-native claude-native
  grok-native`) wins over leg resolution, so a leg can never shadow a vendor name.
- **`DAGC_CLI_EXEC`**: a leg execs its file; `claude-native`, `copilot-native` and `grok-native` exec
  the vendor binaries `claude`, `copilot`, `grok`; any other name execs itself. `$DAGC_CLI` stays the
  logical name everywhere else (`DISTRO_CONSOLE_EXEC=`, flags, warnings).
- **`DAGC_NONINTERACTIVE_CLIS`** is `copilot copilot-native claude claude-native grok scaleway`, plus any
  discovered leg. `grok-native` is not in it (a real interactive binary not proven non-interactive). A
  leg has no interactive shape; `--cli <leg>` without `--non-interactive` is refused with a stated reason.
- **`MDAT_<NAME>_HARNESS` points one leg at another file**: a bare filename in `sh-lib`, or an absolute
  path; a relative path with `/` is refused (it would resolve against `$MMDAPP`). It must exist and be
  executable. Install probes and `AgentsToolsSpawnCliPresent` test the default file, not the override.
- **The console passes no flag to the CLI.** After `--non-interactive` the rest of argv is the prompt.
  Anything the CLI must be told travels as an exported variable.
- **A generated console is a snapshot** of `AgentsConsoleShellScript.template.sh`, rewritten only by
  `--make-console-command`. It resolves awk paths at run time but bakes in its own invocation, so
  changing a `-f` list does not reach a console until it is regenerated. Staleness is normal; design
  changes to work with old consoles.
- **claude-native streaming.** `DagcRunClaudeStreaming` runs claude with
  `--verbose --output-format stream-json`, backgrounded, and pipes it through
  `awk -f AgentsProgressLineSafe.awk [-f AgentsClaudeStreamJsonTranscript.awk] -f AgentsClaudeStreamJsonFormat.awk`
  under `LC_ALL=C`. Progress goes to stderr; the final `result` text to stdout; exit from `is_error`.
  Other CLIs are `exec`'d directly.
- **Ctrl-C stops a run only if the trap chain is unbroken**: the console traps TERM/INT onto claude's pid
  right after capturing it; the spawn proxy's `--wait` traps onto the console; the main loop traps onto
  its pass and sends `kill -TERM -- "-$pid"` to the process group (the real proxy is one pipe deeper).
  Each layer re-waits after `wait` returns early.
- **Claude sign-in (claude-native).** The console asks `claude auth status`. Signed in: nothing is
  exported, even with a key configured, because Claude Code prefers a key and would move spawns onto API
  billing. Signed out, `--non-interactive` only: it exports the first configured `ANTHROPIC_API_KEY` or
  `CLAUDE_CODE_OAUTH_TOKEN` from magic-team scope and says which. rc 6 is signed out with no key;
  the proxy reports `SETUP_STATUS=cli-not-authenticated`. An interactive console is only warned.
  Unknown output never gates. Spaces are stripped before matching.
- **Console channels have no per-caller isolation.** The channel id is a fixed prefix, the workspace
  slug and the console name. Two callers on one workspace and console share one channel and can tear
  down each other's session (`channel_not_found`, a console dying mid-use).

## 11. Spawning and sessions

- **The spawn proxy does not run a CLI.** It pipes its context into
  `DistroAgentsConsole.sh --cli-configured --non-interactive`. Both its waiting and background branches
  inherit the exports.
- **Spawn environment**: `MDAT_SPAWN_AGENT` (acting member), `MDAT_SPAWN_LAUNCH_MARKER`,
  `MDAT_SPAWN_SESSION_ID`, `MDAT_SPAWN_SANDBOX_ROOT(_REAL)`, and once a coworking session exists
  `MDAT_SESSION_ID`/`MDAT_SESSION_THREAD`, which nested spawns inherit, so a child joins its parent's
  session.
- **`MDAT_SPAWN_SESSION_ID` is a uuid minted by the proxy** and written to the dispatch item's
  `session-id`; it is the only join between the dispatch record and hook reports. Lowercase it.
  No uuid, no spawn. The caller's previous value, else `CLAUDE_CODE_SESSION_ID`, becomes
  `parent-session-id`. `receiptId` is a different id (the audit log, `RECEIPT_ID=`).
- **`MDAT_SPAWN_AGENT`.** For claude-native the console builds an inline `--agents` document and selects
  it with `--agent`, so hooks report the member as `agent_type`. The name is checked against a bare-token
  set before it enters JSON. No standing agent file: a member must not exist twice. Legs take both
  variables. A CLI that cannot honour one reports it as dropped. `--help` exits 0 before `--agents` is
  validated, so it proves nothing.
- **A harness session that never armed is recorded as failed**, whatever its exit code
  (`AgentsToolsSpawnProxyOutcome`): a `<session>.harness` marker and no `<session>.armed`. Native
  sessions keep the exit-code rule.
- **Arm before acting.** In a spawned harness loop, Write, Edit, Bash, SendMessage, AskUserQuestion, Agent
  and any `mcp__*__execute` are redirected until the session has read its own `<member>.armed.md` to the
  end through Skill (no truncation footer; a ranged read must reach the last line). Read-only tools,
  served `--intern-tool` calls and non-spawned sessions are never gated. The first redirect posts once to
  event-track. The close records `armed: yes|no|unknown` (`unknown` where no harness loop ran, i.e.
  native CLIs).
- **A document reaches a spawn by grant and pointer, not copy.** Member skill dirs and the source tree are
  granted roots. `held-context:` is conversation context, not documents. A spawn takes its brief from one
  source.
- **Sandbox `input/`** (`AgentsTools.SpawnSandbox.include`): `dispatch.md`; a copy of the board item;
  `MAGIC.<package>.md` copies of the nearest MAGIC.md above every named path (never above `source/`);
  `pointers.md` naming skillset files to read through Skill (a routine is never copied: the live file is
  read); `conversation.md` for a spawn continuing a thread (newest 50 per thread,
  `MDAT_CONVERSATION_HISTORY_MAX`). It is made read-only by file mode, because a verb-less access flag
  grants it for writing. Credentials are never copied. Emptied on every close path.
- **Sandbox sweep**: each main-loop iteration and heartbeat close empties `input/` of sandboxes on this
  host with no live process. Never touched: another host, a running session, no record, or a record
  under 10 minutes old.
- **The session record** `<sandbox>/<spawn-id>.md` sits outside `input/` and `output/`, so the session
  cannot forge it. Its frontmatter rebuilds the spawned-sessions registry. Fields: `session-id`,
  `spawn-id`, `parent-session-id`, `tracking-name`, `host`, `workspace` (basename, never a path),
  `owner`, `status`, `started-at`, `execution-receipt`, `output-file`, `agent-log-thread`,
  `session-thread`, `spawns`/`spawned-by`. Beside it: `event-track.thread` and `session.thread`
  (`<channel>:<ts>`). A coworking session shares one sandbox named by the session id.
- **Children lists.** The spawn op appends the child's record path to `.local/agents/children/<parent>`.
  The main loop rebuilds all lists each iteration (`AgentsTools.ChildrenIndex.include`) and marks
  `children/.indexed`. Without the mark, a harness scans every record. Not under `sessions/`: a file
  there counts as session activity for the advance pass.
- **`ListAgents` reads the spawned-sessions registry**, rebuilt from sandboxes on each call. Eleven
  stored columns (the first seven unchanged for position readers), plus `live` (checked during the call,
  this host only) and `state` (`running`/`waiting`/`finished`/`unclosed`/`unknown-foreign`), matched on spawn id.
  `waiting` reads the pending-replies registry. Rows are one awk pass
  (`AgentsRegistryHeaderRows.awk`), never a fork per file; `live` and `state` are derived without a fork
  per row. Filters (`view`, `session_id`, `state`) are in the tool description.
- **A `--dispatch-doc:none` spawn writes nothing under `$MDAT_DATA_ROOT`.** Under `--wait` its output
  goes to the caller's stderr. Async, it goes to `$MMDAPP/.local/agents/sessions/<spawn-id>/session.log`,
  never to a returned caller's stderr (a `2>&1` capture would hang). The launch marker separates a real
  failure from a silent no-op.
- **Routine resolution** (`AgentsTools.SpawnRoutine.include`, function-only): a selector matches by
  substring against `*.routine.md` filenames under member folders; zero or several matches are refused
  with candidates named. `--routine-default` picks the one routine whose `default-for-session-kind:` is
  `coworking`. A routine needs a frontmatter block and non-empty `executors`/`maintainers`; missing
  `invitees` reads `none`. `--intern-op-spawn-prepare-brief` needs exactly one of the two options; the
  spawn proxy takes neither or one.
- **What every spawn gets.** The harness `Agent` tool prepends the spawn-prepare-brief block itself
  (unless the prompt already starts `SPAWN-PREPARE-BRIEF: `); if it cannot be built, the spawn still
  starts with a `NOTE:`. The proxy appends `## Staying on the task`: a spawn hands back, keeps
  `Wait`ing, and ends only on `DISMISSED`. A `--wait` spawn is the exception (its caller is blocked), so
  the proxy exports `MDAT_SPAWN_CALLER_WAITS=true`.
- **`DISMISSED` is recognised by its tag, never by the posting account** (spawner and child may share a
  bot): the send header's addressees, or a typed `DISMISSED <member>`. One addressed to someone else or
  `@here` dismisses no one. One function, `dismissalOf` in `AgentsDismissalMatch.awk`, also used by
  `AgentsSlackThreadAnswers.awk` so the own-post skip never drops it. `TaskStop` is the last resort.
- **`--magic-spawn-session`** resolves the routine once, spawns the executors (or explicit members) async
  with `--dispatch-doc:create`, the first starting the session and the rest joining by its `SESSION_ID=`.
  A wildcard or prose `executors` value is refused. Invitees are never spawned here.
- **Member ops run in the member's workspace.** `AgentsToolsMemberWorkspaceResolve` (in
  `AgentsTools.MemberWorkspace.include`, sourced at entry) picks the current workspace if the member is
  there, else the tracked workspace where it is a source link, else the first tracked one with it. A
  switch re-runs the whole call in a subshell with `AgentsToolsWorkspaceSwitch`. No switch for
  `magic-team`/`human-owner`, an untracked current workspace, the spawn ops, `--intern-mcp-execute`,
  `--intern-op-decisions-append` and `--intern-op-review-*`. The spawner starts the member's session in
  the member's workspace but keeps records and board in its own.
- **Who may call.** `AgentsToolsActingMember`: `MDAT_SPAWN_AGENT`, else the harness agent, else the owner
  of the spawn record. No such session means the console, which passes every check. `--member-*` ops
  whose member is a credential or identity refuse a session naming another member
  (`AgentsToolsActingMemberCheck`). `--magic-*` refuses any session acting as another member
  (`AgentsToolsMagicCallerCheck`), with no exemption: `--magic-*` is `magic-coordinator`'s alone. Tooling
  acting for another member calls the `--intern-op-*` form directly.

## 12. The main loop and the root harness

`--intern-main-loop` and `--intern-root-harness` have no help; their contracts are here.

- **`--intern-main-loop (--run|--one)`**, no member argument. Anything else prints syntax and exits 1, so
  a bare call never hangs. `--one` runs the iteration body once, without sleep or backoff state; it is
  how to exercise the readiness gate by hand.
- **Readiness is checked once, before the loop.** `--intern-op-check-configs` probes (all `--optional`)
  `SLACK_CHANNEL_MAGIC_TEAM`, `SLACK_CHANNEL_HUMAN_OWNER`, `SLACK_CHANNEL_EVENT_TRACK`,
  `SLACK_CHANNEL_EVENT_ALERT`, `SPAWN_CLI_SERVICE` in magic-team scope; the arm adds
  `TEAM_DATA_DIRECTORY: OK` from the resolved root. `AgentsMainLoopReadinessReport.awk`'s exit
  (`PIPESTATUS[1]`) is the gate. The floor is team data, basic comms and `SPAWN_CLI_SERVICE`. A floor item
  probed but missing from the awk's `addItem` list lets the loop start and fail every iteration.
- **`SPAWN_CLI_AUTHENTICATED` is a diagnosed item that never gates**: `claude auth status` (`loggedIn`),
  stdin closed. Any case it cannot read is `SKIP`. A new CLI's probe is a branch in the arm's `case`.
- **Everything the loop says goes to stderr**, the readiness report included.
- **Each iteration**: team-data sync (when `TEAM_DATA_GIT_REMOTE` is set), children index rebuild,
  pending-reply collect and remind, then one `--intern-root-harness --routine heartbeat
  --non-interactive --wait`. Backoff starts at `MAIN_LOOP_RESTART_DELAY_SECONDS` (default 29), doubles on
  failure, caps at `MAIN_LOOP_RESTART_DELAY_MAX_SECONDS` (default 1200), resets on success. A permanent
  misconfiguration therefore shows as failures then silence, not a loud exit.
- **A pass is watched.** After one minute it is reported every restart-delay seconds.
  `MAIN_LOOP_PASS_TIMEOUT_SECONDS` (default 0 = no bound) ends it with TERM then KILL to its process
  group, records `MAIN_LOOP_LAST_OUTCOME=timed-out`, and posts to event-track. The lock is left for the
  next pass's stale-lock recheck.
- **A team-data store with content but no `.git` is adopted** by `myx.common git/cloneSync` into an empty
  remote only; `clonePull` never makes it a clone. `TEAM_DATA_BRANCH` travels as `init.defaultBranch` via
  `GIT_CONFIG_*`, or the push fails and `clonePull` then deletes the checkout. A remote with history plus
  local content is reported, to merge by hand.
- **`--intern-root-harness [--routine <selector>] [--non-interactive] [--wait]`**, no member argument.
  It spawns `--magic-heartbeat-spawn-proxy magic-coordinator`. Interactive (default) loops in its own
  thread in `magic-team`; `--non-interactive` runs one loop and posts to `event-track`, and needs
  `--routine`. The brief is the static `root-harness-session-start.prompt-packet.verbatim.md` with an
  `INTERACTION-MODE:` line (and a `ROUTINE:` line) prepended; no templating inside it.
- **The `🤖 AI service used:` line** is the spawn proxy's, read from the child's `DISTRO_CONSOLE_EXEC=`.

## 13. The `myx.distro` MCP server

`--intern-mcp-server` and `--intern-mcp-execute` have no help; their contracts are here.

- **`--intern-mcp-server --run`**; without `--run` it prints syntax. Registered with args
  `["--intern-mcp-server","--run"]` and no `env`.
- **stdout is the JSON-RPC wire only.** Diagnostics go to stderr. Responses are written by the `printf`
  builtin, one physical line each; escaping is done into a variable before the lock.
- **The server is a launcher.** `AgentsTools.InternMcpServer.include` reads one message at a time and
  starts `--intern-mcp-request <server pid> <seq>` in a fresh background process.
  `AgentsTools.InternMcpRequest.include` reads the tool floor, identity, roots and context per call, so
  edits apply on the next call. Only a launcher change needs a host restart.
- **Before each request, values the server derived at start are unset** (`MDAT_DATA_ROOT`, `MYXROOT`,
  `MDSC_*`). `MDAT_SKILLSET_ROOT` is kept.
- **The wire is fd 3 in a request; the request's stdout is stderr.** Children get fd 3 closed, so a left
  job cannot hold the host's pipe. Each request parses into its own `req.<seq>/`.
- **Responses are serialised by a `mkdir` lock on `wire.lock`**, held for one `printf`. The fork is before
  the lock. A lock timeout drops or writes that one response; the server never exits on it.
- **A message with no id is a notification** and is never answered.
- **The floor is rendered on every `tools/list` and `tools/call`.** `initialize` declares
  `tools.listChanged`; a call whose floor checksum differs from `floor.sum` sends
  `notifications/tools/list_changed` first.
- **A trailing `wait` drains in-flight handlers** before the scratch root
  (`$MMDAPP/.local/temp/agent-mcp.$$/`) is removed.
- **`execute`**: `command` starts, `job` addresses an existing job (read first), so `required` is empty.
  Foreground `timeout` defaults to 600 s, capped at 3600; a bad value takes the default. On expiry the
  partial output is kept at a named path. `background:true` returns job id, pid and log; `job` polls by
  byte cursor; `action:"kill"` signals the process group. `rc` is written by the job; no `rc` means
  stopped, never an exit code.
- **`workspace`** re-runs the call in a fresh process with `MMDAPP` moved and `MDLT_ORIGIN`,
  `MDLT_OPTION`, `MDLC_INMODE` unset, so that workspace resolves its own origin. Per-request isolation is
  a boundary: in-process it would poison the server's `MMDAPP`.
- **fd 4 is the daemon stream.** Each launch site opens fd 4 as a copy of stderr before merging.
  `AgentsToolsDaemonLine` writes `( printf '%s\n' "$*" ) 2>/dev/null >&4 || printf '%s\n' "$*" >&2`; a line
  may appear twice, never be lost. `merge_stderr:false` sends a script's stderr to fd 4. Linux `/bin/sh`
  is unchecked.
- **`--intern-mcp-execute`** takes the script on stdin and nothing else; stdout carries only the
  script's output; status is the script's. Never call it from a shell, routine or board item.
- **A bare apostrophe in trailing argv breaks the outer `eval`** before any op parses it. There is nothing
  to fix inside the Slack includes. Callers send message bodies with `--from-stdin`.
- **A harness tool joins the served floor by default.** `mcpUnservedToolNames` is the only subtraction.
  A tool that takes a command, or returns a handle only its own process can resolve, belongs there.
  `Bash` is unserved (callers use `execute`; native `Bash` is rerouted). The harness `Monitor` is
  unserved because a `tools/call` runs in a fresh process and its job store dies with the call.
  Unserved means absent from `tools/list`; `tools/call` still names the alternative.
- **The served `Monitor` is this server's own pull twin**, declared beside `execute`, never in
  `harnessToolsJson`. It is `execute`'s job store with the watch contract: stdout to `out`, stderr to
  `err`, whole lines per poll, `timeout_ms` default 300000, cap 1800000, watchdog inside the job's group
  (TERM, KILL after 5 s). Pull only. Through another server only `execute` is served.
- **The containment check reads the served set from the real `tools/list`** and also finds tools whose
  function runs `eval` or `bash -c` on a caller string, so renaming `command` does not evade it. The
  process-local-handle half is not instrumented.
- **A registration that freezes a path plus an env value validates only the path.** A stale value
  surfaces later as an unrelated error.

## 14. The universal harness

- **Three layers.** A value that changes per vendor is a specific and lives in a stub (endpoint, host,
  credential names, tier models, self-name). Behaviour that stays the same is logic in the core (round
  cap, access roots, tools, retries, result caps). Anything whose shape the endpoint fixes is wire, in an
  adapter.
- **`AgentsUniversalHarness.sh` is the core and is never run directly.** A stub sets `HARNESS_*` and
  `exec`s it, so `$0` is the core's directory for its `.awk` siblings. It is standalone (own `set -e`),
  reads credentials from its environment, never resolves config itself.
- **Stubs**: `AgentsScalewayHarness.sh`, `AgentsGrokHarness.sh`, `AgentsCopilotHarness.sh`,
  `AgentsClaudeHarness.sh` (the live Anthropic leg). `AgentsAnthropicStub.sh` is a non-working design
  record kept by the human-owner's decision; its constraints block lists the `AgentsWire*` roster an
  adapter must define (re-derive it from the core's call sites; an omitted function fails at call time).
  A stub must not grow into a selector.
- **`HARNESS_WIRE` names `sh-lib/Agents<Wire>Wire.sh`** (`OpenAiChat`, `AnthropicMessages`).
  `HARNESS_TOKEN_EXCHANGE` names an optional `Agents<Name>Exchange.sh` (none ship); with one, an
  auth-class error body drops the bearer and re-exchanges within the retry bound.
  `HARNESS_EXTRA_HEADERS` are whole lines, checked at startup, sent on the `-H @-` stdin channel.
- **Provenance of declared values stays beside them**: the Scaleway tier table ("THESE MODEL NAMES ARE
  OBSERVED, NOT DOCUMENTED") and the Copilot model ids live in their stubs. Grok models and context come
  from xAI's `/v1/models`; Scaleway publishes none, so its stub declares 256000.
- **Copilot leg**: complete declarations, never exercised against the endpoint; blocked by
  `COPILOT_GITHUB_TOKEN`. Whether a token exchange is needed is open; one real round decides it. No
  context budget is set. That Copilot speaks OpenAI chat-completions is documented, not confirmed.
- **Scaleway facts**: OpenAI Chat-Completions with SSE, `tools`, `tool_choice`; no Responses API (so Codex
  CLI cannot target it). Never sent: `frequency_penalty`, `n`, `top_logprobs`, `logit_bias`, `user`. Ids
  are bare. A key is scoped by Project and policy, not model, so `SCALEWAY_DEEPSEEK`/`SCALEWAY_GEMMA` are
  preferences with mutual fallback. Tiers: `light` → `gemma-4-26b-a4b-it` (small active MoE), `normal` →
  `deepseek-v4-flash-0731`, `heavy` → the same with `reasoning_effort:"high"`. Its error body is flat
  `{"status","error","message"}` with no `ok` key, which is why `AgentsHarnessJsonField.awk` drops the
  Slack reader's `ok` gate and adds `<path>.__count` leaves.
- **xAI facts**: `POST https://api.x.ai/v1/chat/completions`, `XAI_API_KEY`, no exchange. A refusal is
  `{"code","error"}` with no final newline; the chat wire keeps an unterminated last line. No output
  maximum is declared.
- **Field names in an adapter are observed, never documented.** DeepSeek documents
  `prompt_cache_hit_tokens`; Scaleway-hosted DeepSeek emits `prompt_tokens_details.cached_tokens`.
- **Required response fields** (`id`, `name`, `arguments`) are read through `AgentsWireResponseField`, a
  stated exit 1 on absence. `function.arguments` is a JSON string, parsed by running the same reader
  twice. Every value rebuilt into outgoing JSON goes through `AgentsMcpJsonEscape.awk`.
- **Rounds.** No round cap by default (`MDAT_HARNESS_MAX_ROUNDS`); cost is the real unit. Reaching a cap
  makes one closing request with `tool_choice` off (never removing `tools`, which some wires validate and
  which is in the cache prefix), prints the model's account, and exits 3. The closing round itself is
  unprotected.
- **Context.** At `MDAT_HARNESS_CONTEXT_TOKENS` (default 64000, a policy value; 0 = off), or a stub's
  per-tier window less `max_tokens`, the model writes its own handover and a fresh leg starts from the
  original task plus that summary (`AgentsWireInitMessages` from unchanged `$harnessSystemText` and
  `$harnessPrompt`). The signal is one round's `total_tokens`, not the running sum. An empty summary ends
  at exit 1. `MDAT_HARNESS_MAX_RESTARTS` bounds restarts; a spent budget closes at exit 3. With no usage
  reported, round 1 warns once. One round can still overshoot. The Messages wire requires `max_tokens`;
  the chat wire omits it where undeclared.
- **Streaming.** `curl -N` SSE; one awk per round consumes the stream (`AgentsOpenAiChatStream.awk`,
  `AgentsAnthropicMessagesStream.awk`, loading the JSON field and slice libraries) and writes
  `stream.*` files; the shell only shows live output. Wait for `data: [DONE]`, not `finish_reason`: a
  usage chunk can follow. A mid-stream disconnect retries the whole round, max 3
  (`harnessStreamMaxAttempts`), never counted against a round cap. Stall bound
  `--speed-limit 1 --speed-time 45`; no `--max-time`.
- **Prompt caching is a byte-prefix match.** The tools literal is rendered once; the request appends in a
  fixed order. A re-serialised array stays valid and silently loses the cache; on the Anthropic wire a
  changed set mid-leg is a 400 at replay. `stream_options.include_usage` is sent; spend is recorded, not
  enforced.
- **`AgentsAnthropicMessagesWire.sh` replays the assistant turn byte for byte**, thinking block and
  signature included, in stream order (GAP-2 in the Anthropic stub's record).
- **Progress lines.** `AgentsHarnessAnnounceTool` prints before each call. Every value (tool name too)
  goes through `progressLineSafe` in `AgentsProgressLineSafe.awk`: one line, C0 and DEL folded to space,
  cut at 120 bytes on a UTF-8 boundary, keeping a path's end. This stops injected values forging the
  display. Our own ANSI is deliberate; any escape from untrusted data is neutralised. Check a display
  change against this first. Colour needs `[ -t 2 ]`, no `NO_COLOR`, ≥ 8 colours.
- **`progressLineSafe` is its own file.** `-v progressLineCap=<bytes>` makes it render stdin standalone;
  loaded with `-f` ahead of a formatter, it is a library. A formatter loaded without it dies at the first
  call.
- **`Bash` tool**: output to a scratch file, never `$( )`; containment
  `( cd … && set -e && eval … ) || status=$?`; only its cwd is bounded to the roots. Its watchdog
  `sleep` must redirect `>/dev/null`, or it holds the capture pipe for the whole timeout. Bound only
  where `MDAT_HARNESS_RUN_TIMEOUT` or the call's `timeout` sets one; Darwin has no `timeout` binary, so
  the shell watchdog is the live path.
- **Wait bounds**: `MDAT_HARNESS_WAIT_TIMEOUT` caps a harness `Wait` (unset: wait until something
  arrives). A served call returns by `MDAT_MCP_WAIT_BOUND` (1700, under the native 1800 s idle cutoff),
  or `MDAT_MCP_WAIT_BOUND_PROGRESS` (14400) with progress notifications every
  `MDAT_MCP_PROGRESS_SECONDS` (60).
- **Access roots** are rendered by the console into each client's flag (`--add-dir`, `--access-root`).
  `own`/`explicit` lines are trusted; `wildcard` and untagged lines are existence-checked. The harness's
  own fragment read is only a fallback for consoles generated before `--access-root`; it keeps the text
  after the last tab if absolute. No roots is a refusal.
- **`--agent <name>`** reads `$MDAT_SKILLSET_ROOT/<name>/<name>.basic.md` as the system identity and tells
  the model to `Read` its `.armed.md`. A missing `.basic.md` is exit 1. `--session-id` is announced as
  `🔗 session <id>`.
- **The symlinked access-root case is unconfirmed live.** `AgentsHarnessContainmentCheck.test.sh` holds
  it offline.
- **Per-call costs.** Arguments are parsed once (`AgentsHarnessArgParse`, `AgentsHarnessArgTable.awk`)
  into `harnessArgV_<key>`. A round's tool calls are read once from the stream files
  (`AgentsHarnessToolCallsRead`). A served call sources only what it uses; model-only code is in
  `AgentsHarnessModelRound.include`, past the `--intern-tool` exit.
- **`AgentsHarnessJsonField.awk`** holds input in 256-byte chunks (awk string ops cost the whole string).
  `jfLibrary = 1` in a later file's BEGIN makes it a library (`jfParseText`, `jfLeaf`, `jfLeafSeen`).
  `AgentsHarnessJsonSlice.awk` returns raw values (`mode=raw`) and key names (`mode=keys`) undecoded;
  `jsLibrary = 1` likewise. rc: 0 found, 3 absent, 1 not JSON, 2 usage. `LC_ALL=C` required.
- **`context.jsonl`** (`AgentsHarnessContext.include`) is the exact message array a harness spawn sends,
  kept in its sandbox; not for `--wait` or native spawns, or with `MDAT_HARNESS_CONTEXT=off`. Transcript
  rounds are rendered from it at milestones.
- **Resume on review return** (`AgentsTools.HarnessResume.include`): same cli, non-native leg, same host,
  a parseable kept `context.jsonl`. `MDAT_HARNESS_RESUME_CONTEXT` checks model, service, host and wire,
  loads the array and appends the corrections, keeping the old request as a byte-exact prefix. rc 7
  (refused before any request) falls back once to a new process.
- **Hook payload** is built from values already parsed; `session_id` and `cwd` are escaped once at source
  time. Decision and reason come from one read through `AgentsHarnessHookDecision.awk`. Hooks are
  fail-closed: unreadable config, a hook that does not finish, or an unreadable answer refuses.
- **MCP client** (`AgentsHarnessMcpClient.sh`). With no `--mcp-server`, the set is the keys of
  `mcp.servers.json` minus `myx.distro` (enumerating itself recurses). A run with no server opens no file;
  the offline checks depend on that guard. One process per enumeration: `initialize`,
  `notifications/initialized`, `tools/list` are written first, and stdin is held open until the awaited
  id appears (closing it first leaves `myx.common`'s background answer unsent). Answers are read from a
  file. Enumeration is bounded by `MDAT_HARNESS_MCP_ENUM_TIMEOUT` (30); calls by the run bound. Names
  outside `[A-Za-z0-9_.-]` are dropped; `.` becomes `_` in `mcp__<server>__<tool>` (the wire rejects dots).
  Credentials go via `env`, so `command` must be absolute. A degrade is stated on stderr and in the
  system text.
- **Re-enumeration** happens only when `AgentsHarnessMcpStale` says so: `mcp.servers.json` changed, a
  server was unavailable, or a call failed or named an unknown tool (`mcp.call.fault`). Servers launch
  from `mcp.servers.index` while the JSON is byte-identical to what it carries.
- **MCP tools on the wire** are declared one per tool by `AgentsWireToolDeclaration`, spliced into the
  literal at one place. One `mcp__*` arm in dispatch and announce, after every static arm.
  `AgentsHarnessMcpCall` is outside the `AgentsHarnessTool*` family on purpose. Every failure is an
  `ERROR:` tool result, never an exit. A hook's `*)` arm receives the real arguments under `tool_input`;
  `{}` there would fail open.
- **Exit status**: the `EXIT` trap keeps 0 only when the run reached one of its two clean exits
  (`harnessExitClean`).

## 15. Harness tools

- **The set** (`harnessToolsJson` in `AgentsOpenAiChatWire.sh`): `Read`, `Write`, `Glob`, `Edit`, `Grep`,
  `Bash`, `WebSearch`, `WebFetch`, `SendMessage`, `ListAgents`, `Wait`, `SubagentHandback`,
  `ReportFindings`, `PushNotification`, `Artifact`, `AskUserQuestion`, `ListMcpResourcesTool`,
  `ReadMcpResourceTool`, `ReadMcpResourceDirTool`, `Skill`, `Agent`, `TaskStop`, `TaskOutput`,
  `ToolSearch`, `SessionTranscriptAppend`, `Monitor`. Each has four sites: the declaration, and in the
  core the announce arm, the dispatch arm and the function.
- **The tools literal is one bash single-quoted string.** An English possessive closes it
  (`HARNESS_PARSES` catches this; the site check does not). A missing comma between declarations passes
  `bash -n` and the site check and fails only at the endpoint as a 400; `HARNESS_TOOLS_JSON` catches it by
  comparing text and parsed counts. Run it after any declaration change.
- **Addressing.** `SendMessage`, `SubagentHandback`, `PushNotification`, `ReportFindings`, `Artifact` and
  `AskUserQuestion` share one `to` resolver: named conversations, a bare id, `<channel>:<ts>`,
  `session-parent` (the parent sandbox's `session.thread`; no parent is an error, never another thread),
  or a member name (its DM via `AgentsToolsCommsSlackMentionUserId`; no Slack account means an
  `inquiry-*` in its inbox, which `AskUserQuestion` refuses). An empty `to` is the session thread
  (`AgentsToolsSessionThreadFind`), resolved inside `--member-comms-slack-send-message` so MCP gets it
  too; `SubagentHandback` defaults to `session-parent`.
- **Identity on a served call**: `MDAT_SPAWN_AGENT`, else `magic-coordinator` for a root session, kept only
  if that `.basic.md` is readable; otherwise sending tools refuse. A model run without `--agent` refuses
  to send. Text goes on stdin; no credential in argv.
- **`NEXT:` lines.** A result the model must act on ends with one `NEXT:` line naming the call, added after
  the existing lines, in the core only (`Wait` stateful TIMEOUT/RECEIVED/DISMISSED, `SendMessage`
  posted, `SubagentHandback` from a non-blocked spawn, `AskUserQuestion` left open with `WAIT-ID:`).
- **`Wait` tool** calls `--member-wait-for-input` and adds only: `mode` (`default`/`continue`/`close`),
  reaction id sets, `slack:session-parent` rewriting, and `DISMISSED` detection
  (`AgentsHarnessWaitDismissed.awk`). Session id from `AgentsHarnessSessionKey`. A call with six or fewer
  arguments stays stateless. A send records `sessions/<id>/last-own-post` for the floor fallback.
- **`ToolSearch`** reads the catalogue rendered by `AgentsHarnessMcpMirror.sh` (cached in
  `toolsearch.floor`, since the call runs in `$( )`) plus `$harnessMcpToolsJson`; `AgentsHarnessToolSearch.awk`
  reads all three envelopes. Query through the environment; terms matched with `index()`.
- **Read cap** (`AgentsHarnessReadCap.include`): 200000 bytes for a hosted model, 48000 for an MCP client
  (`MDAT_READ_CAP_BYTES` overrides the mirror). Descriptions carry `{{READ_CAP_BYTES}}`, filled per
  renderer.
- **`Skill` reaches the whole skillset, deliberately outside the access roots**, because member folders
  are symlinks into their source trees. Containment is lexical (gated charset, no `..`, no leading `/`).
  A symlink planted inside a member tree or the skillset root pointing outside the skillset is followed
  (`-f`, `cat`, `find -L` all follow). Today no such link exists; the first one reverses this
  acceptance. The fitting guard, if needed: resolve after the lexical gate and require the result under
  the resolved member folder (a resolved skillset-root prefix admits only one member). `Skill` shares
  `offset`/`limit` with `Read` via `AgentsHarnessReadRange`; without `limit` it reads to the end within the
  byte cap.
- **`Skill skill=`** loads a skill like the native tool: bare name, `anthropic-skills:<name>`
  (`~/.claude/skills/synced`), `<plugin>:<name>` (synced plugins), `<dir>:<name>`. Frontmatter removed,
  `Base directory for this skill:` prepended, `$ARGUMENTS` placeholders filled,
  `disable-model-invocation: true` refused.
- **`Edit`** replaces an exact literal that occurs exactly once, counted with the same `index()` that
  substitutes (never `grep -c`). Text through `ENVIRON`; output with `printf "%s"` so no newline is
  added. **Write and Edit replace by rename under a per-target lock** (a symlink in
  `.local/agents/locks/<cksum>` naming the pid; dead holders broken; 30 busy polls then error). Known
  limits: hard links break; a kill mid-way leaves `.<name>.mdat-write.<pid>`; ownership changes to the
  writer; two breakers can both win; a pid reuse keeps a lock looking held.
- **`Grep`** runs `grep -E` with `\d \s \w` (and negations) translated; a negated escape inside `[...]` and
  `multiline` are refused. `type` uses `AgentsHarnessGrepTypeGlobs`. **A search with no hits says so in
  words** (`No matches found`, `No files found`); the MCP server treats empty output as an error.
- **`Glob`** tests its root first, so a missing directory differs from no match; `long` lists details.
- **`WebFetch`** never applies its `prompt` on a served call and says `PROMPT WAS NOT APPLIED`. It fetches
  only under allowed prefixes (built-in `https://wikipedia.org/`, `https://freebsd.org/`; magic-team
  `WEB_ALLOW_PREFIXES`, `WEB_DENY_PREFIXES` with deny winning). No cross-host redirects.
- **`WebSearch`** uses the keyless DuckDuckGo Instant Answer API, which answers named things and returns
  nothing for ordinary multi-word questions. Whether that is acceptable is open.
- **`SessionTranscriptAppend`** appends one NOTE line to the current session's transcript through
  `--member-append-session-transcript` with no `--transcript-name`.

## 16. Team data, board and inbox

- **Every tooling writer commits** the paths it wrote through `AgentsToolsTeamDataCommitPaths`
  (`AgentsTools.TeamDataCommit.include`). A close point (spawn close, heartbeat close, main-loop pass)
  pushes through `AgentsToolsTeamDataPushIfAhead` under the `team-data-push` lock: fetch,
  `merge-base --is-ancestor`, merge with `pull.rebase=false`, read back. `AgentsToolsTeamDataDirtyWarning`
  states an uncommitted or ahead store. The store is cloned at dispatch once per process tree
  (`MDAT_TEAM_DATA_CLONE_TRIED`), never into a nested repository.
- **`--intern-op-item-upsert`: the commit gate is `.git`, the push gate is `TEAM_DATA_GIT_REMOTE`.** No repo:
  write. Repo, no remote: write and commit. Both: write, commit, push, resync, read back. `--no-push` has
  its own message. Without a remote a lock is local and unverified.
- **`--intern-op-board-upsert-move-edit` is the one board move primitive.** It commits both ends (gated on
  `.git`, never pushing); an untracked source is left out of the pathspec. Subject
  `* board-upsert-move-edit: <item> <from> -> <to>, <context>`. A move deletes the old copy; it never
  writes to `trash/`. It accepts `review` as a state.
- **Every logical move stamps its target state's date field** in that primitive: `processed` →
  `processed-at`, `running` → `started-at`. Suppressed when the caller names the field in any `--header:`
  op (`:remove:` too), on a same-state edit, when there is no complete frontmatter, and for
  `processed-at` when already present. `--create` stamps. Presence is checked with
  `AgentsBoardItemFrontmatterFieldProbe.awk`, never a match anywhere in the body.
- **Creation headers are the tooling's.** Board create and inbox create fill `type`, `date`, `from` (and
  `owner` for inbox) as `default` header ops: set only when neither the body nor a `--header:` names
  them. Updates are never stamped. The name is the caller's; `AgentsToolsItemNameShapeCheck` only warns.
- **`--recheck-in <minutes>[±<jitter>]`** on board ops is resolved once in the primitive into a UTC
  `recheck-date`, by `AgentsToolsRecheckDate` (`AgentsTools.RecheckDate.include`). Do not inline the
  arithmetic.
- **List-shaped headers** (`blocks`, `blocked-by`, `supersedes`, `superseded-by`, `spawns`, `spawned-by`)
  are `a, b, c`, no brackets (`AgentsBoardItemHeaderOpsApply.awk`). There is no `references` field.
  `participants`/`restart-session` are space-separated, a separate convention.
- **`--magic-board-to-blocked` and `--magic-grooming-to-blocked` stamp `execution-receipt: blocked:<ts>`**
  unless the caller supplies one; the check is a scan of that call's passthrough, in each arm. This
  header is written by several paths and is not yet in the armed file's header list.
- **A state move belongs to the routine that makes it.** `--magic-grooming-to-parked`,
  `--magic-advance-to-parked`, `--magic-board-to-parked` stay separate stubs; each stamps its own
  provenance. Grooming stamps `owner`, `groomed-at`, `groomed-from`, `track`; a create stamps no
  `groomed-from`. `--magic-grooming-to-backlog` clears `approved-by`/`approved-at`. `processed-at`, not
  `groomed-at`, answers how long an item has been processed.
- **`board-review` is entered only by the spawn proxy** (`AgentsToolsSpawnProxyCloseDispatch` create mode
  passes `review`, with `review-by` from `parentSessionId` when non-empty). There is no to-review stub. A
  reviewer's accept moves review → processed; reject moves it to running with comments.
- **The approval cascade** (`AgentsToolsApprovalCascade`, `AgentsTools.ApprovalCascade.include`) fires
  when an `approval-*` arrives in `board-processed` carrying `approved-by` and `approved-at`. Each `blocks`
  item takes those values as `default` ops; a stamped `board-blocked` item whose every `blocked-by` is
  processed, archived or retained moves to pending. Bad entries are reported and skipped; never fatal;
  idempotent. Paths join the approval's commit.
- **`--intern-op-board-trash`** is the one implementation behind `--magic-heartbeat-board-item-trash`,
  `--librarian-inbox-item-trash` and `--member-inbox-item-trash` (wrappers pass `--context`). Subject
  `- <invoked op>, <member>`. Without `.git` it creates `trash/`, tests `[ -e ]` before `mv`, and
  `touch`es the item so its trash clock starts now. With `.git` it deletes and commits.
- **`--intern-team-data-final-gc-deletion`** retention is keyed on document type (`warning-*`,
  `reflection-*`: 1 day; others 7), the same in inbox roots, legacy `inboxes/*/processed/`,
  `board/processed/` and `trash/`.
  - In an inbox root only items with `processed-at` are candidates, clocked by that stamp; a bad stamp
    keeps the item with a warning.
  - Elsewhere the clock is the latest commit for the path, else mtime (a checkout resets mtime). One
    `git log --name-only` per directory, never per item.
  - `trash/` is collected at once when `TEAM_DATA_GIT_REMOTE` is set; otherwise it follows the table.
    An absent `trash/` is not reported.
  - Ask git what the index holds and what HEAD holds before `rm`; an item staged but never committed must
    not reach the commit pathspec.
  - Diversions: `archive: true` → `board/archived/` first; else an item named by a live item's
    `blocked-by`/`spawned-by` → `board/retained/`. Live is backlog, pending, running, blocked, parked,
    archived. Markers are read only when an item is due, bounded to frontmatter, in shell. Diversions are
    board items only, go through the move primitive (which commits), and create their state directory.
  - `rc` is 2 when nothing was deleted (a divert-only pass included), 0 otherwise; a diversion sentence is
    added. The `.git`-gated commit with message `- team-data-final-gc-deletion` is required by the
    specification; do not remove it.
  - A deleted processed or trashed item takes its spawn sandbox folders (`spawn-id`, `spawns`/`spawned-by`)
    unless a record is still `spawn-started`, has no status, or another item links the folder. Unlinked
    sandboxes are never removed; synced copies may return.
- **The GC and the trash op are separate mechanisms**: one deletes on a clock, the other relocates one
  named item.
- **Inbox items are marked processed in place.** `--intern-op-inbox-to-processed` stamps `processed-at`
  as a `default` op, rewrites through a sibling dotfile and a rename, and commits alone. Re-marking is a
  no-op; an edit keeps the original stamp (it is the GC clock). Readers use
  `AgentsInboxProcessedAtList.awk`, bounded to a frontmatter block starting on line 1. The legacy
  `processed/` folder is read-only and drains. A mark does not wake a wait.
- **Vault and audit reads**: `--member-vault-item-read` and `--member-audit-item-read` check the caller;
  `--intern-op-vault-item-read` and `--intern-op-audit-item-read` (`AgentsTools.InternOpVaultAudit.include`)
  resolve and read, so a new back end changes only there. There is no vault write op until a skillset
  step names one.

## 17. Routines: locks, scans, day rhythm

- **A routine locks its own fixed note**, named in its stub, never by caller argument. The lock check is
  its own op, before the input scan.
- **`--magic-<routine>-state-and-lock-upsert` puts `state` before the caller's headers and
  `recheck-date` after.** Repeat upserts are last-wins, so a close can set the state but a caller cannot
  pin the lock open. Keep the order.
- **`-close-state-and-unlock`** writes closing content, finished state and unlock in one
  `--intern-op-item-upsert` call. Unlock order: GC, lock write, one push, resync.
- **Advance lock paths** run `myx.common git/cloneSync --no-push` when a remote is set. Acquire: state
  check, resync, state check, head comparison against `FETCH_HEAD:<path>` (never `origin/<branch>`), then
  write. `LOCK_CONFLICT` (merge, marker, local edit), `LOCK_STALE` (local commit is not head),
  `LOCK_UNCHECKABLE` (could not answer, or no named branch) all refuse. A push or resync failure at unlock
  warns and still closes. The other routine groups still use the plain stubs.
- **Heartbeat state and lock share one note.** `--magic-heartbeat-state-upsert` takes a whole-record body
  and splices in seven lock-owned fields read from the target (`type`, `from`, `date`, `owner`, `state`,
  `recheck-date`, `session-id`), excluding them from the caller's body. It strips `\r`, treats a
  fence-less body as all body, refuses when both extracted parts are empty from non-empty input, and
  strips the body's leading blank lines so the separator stays one line. While the state is
  `heartbeat-running` each write refreshes `recheck-date` to now + 15 min. It stamps
  `last-iteration-date`/`-timestamp` and keeps `last-test-email-sent`. Only the heartbeat pass writes it,
  so the read-then-write gap races only itself.
- **The day rhythm is computed by the tooling.** `--magic-heartbeat-input-scan` opens with `branch:`,
  `today-stage:`, `grooming-today:`. Dates are local (the workday is the human-owner's); lock dates stay
  UTC; never compare the two. `last-close-date` is stamped by grooming and daily closes. The test report
  is built from the same functions the scan prints with. The scan lists board item names only, plus
  `## board counts` computed at scan time.
- **The `--*-input-scan` wrappers stay separate**, even when two pass the same arguments. The op name is
  the routine's interface; each wrapper is fixed and exposes no override. A caller wanting another shape
  calls `--intern-op-session-context-scan`.
- **`--magic-morning-review-input-scan`** reads board headers only (`AgentsMorningReviewStateShape.awk`),
  capped per section, cut off at `last_reviewed_ts`, advanced only at close.
- **`--magic-sweep-input-scan`** sweeps the team and each `client-*` concurrently and prints the team first.
  `lib/parallel` runs in a nested subshell because it installs an `EXIT` trap. This is safe because
  `--intern-op-slack-call` waits out rate limits (`ratelimited`/429, `Retry-After`, up to 5 attempts,
  `AgentsToolsSlackRateLimitWait`).
- **`--magic-advance-input-scan` closes dead spawns first**, as housekeeping that writes nothing to the
  scan output (`AgentsToolsHousekeepingReport` posts to the caller's event-track thread). Dead on this
  host: no live process, no open ask, nothing changed under its sandbox or `sessions/<id>/` for 15 min.
  Elsewhere: no open ask and nothing changed for 24 h. A dead spawn's created dispatch item moves running
  → review. A review item whose `review-by` session has ended gets `review-by: magic-coordinator`. The
  scan never accepts an item.

### `--intern-op-session-context-scan` (no help; essentials)

The document format is the skillset's `session-context.document.format.md`. The flags are parsed in the
op's own option arm.

- **Call shape**: `<team-member> (--all-types|--type-prefix:<v>...)`, then section flags. `--do-*` requests a
  section, `--no-*` declines it (no heading at all), neither prints the heading with
  `**NOTE:** not requested`. A wrapper passes both halves. A breadth pair (`-active|-all`) is exclusive;
  `--do-x` with `--no-x` is refused. Exit: 0 all sources scanned (or none), 3 some, 4 none, 1 failed.
- **A wrapper passes its own cut-off.** With none, IM falls back to a recent window. `--comms-since-utime 0`
  means "trim nothing"; history is read unpaginated, one page deep. The value used is stated in each
  section's `instrument:` line.
- **`--do-board-related-*` owns the state set and owner filter.** A `--state` list beside it must
  byte-match, order included. A different `--filter-owner` beside it is refused.
- **Relatedness is `owner:` only.** `participants:` and `restart-session:` are not matched, and the empty
  NOTE says so. Free-text `status:` is never parsed; `-active`/`-all` reads only tool-stamped markers.
- **An unconfigured comms source is not a failed source**; the scan reads that scope's keys first, and
  the section names the unset keys.
- **Every section carries a `scope:` line**; the board one whenever it has content. An empty section's
  NOTE has a denominator and a filter.
- **Inbox**: four sections (inquiry, reflections, notes, other), the last catching every other prefix.
  Capped at 64, oldest first by mtime; the board is never capped. Each block carries the whole item
  framed by `body-lines: <N>` (always the last key), because bodies may contain `## ` lines. One awk
  per section (`AgentsInboxItemBlockPrint.awk`, `RS="\004"`). Per-item byte cap 8192 marks
  `body-truncated:` inside its framing, cutting whole lines. A fence-less item is all body.
- **A marked item's bytes and mtime are the mark's**: the rewrite sets mtime and ends with one newline.
- **`--item-include-inbox`** extends named-item lookup to the acting member's own inbox only. A named
  item is included once, exempt from the cap; a missing one gets its own line. It applies to the display
  call only, never to a discovery phase, whose line-anchored harvesters would read body text as headers.
- **Email** blocks are rendered by `AgentsSessionContextEmailItem.py` (headers only, no body; RFC2047
  decoding needs Python). The sweep fetch is one IMAP session (`AgentsImapSweepFetch.py`,
  `BODY.PEEK[]`, nothing marked seen).
- **Slack reads**: a roster widened to channels keeps only channels the identity is in (`is_member`); a
  thread whose `latest_reply` is at or before the cut-off is not read but still counted; the IM section
  shows at most 128 conversations and reads threads newest first, stopping below the cap with a
  `**NOTE:** capped` line. Each `## slack-message` block carries `author:` and `addressees:`, parsed from
  the team send header only when it is the text's first line.
- **Rejection messages name what was actually wrong** (`--client-sweep-input-scan` and
  `--client-sweep-config-check` are client-only).

## 18. Slack

- **Target grammar has one resolver** (`DistroAgentsToolsResolveTarget`). A bare conversation id (≥ 9
  chars, uppercase letters and digits, first a letter) posts at top level. Its arm comes after `*:*`, so
  the two grammars are disjoint. The id is never trimmed or repaired.
- **Identity selection is in `--intern-op-slack-call`, once.** No `--identity`: a member with
  `SLACK_USER_TOKEN` acts as itself, otherwise the bot; a `routine-*` author is always the bot. Passing
  `--identity user` turns the fallback into a hard error; use it only where acting as the bot is
  unacceptable (profile ops).
- **Bot token**: the member's own `SLACK_BOT_TOKEN`, then `magic-team`'s (`AgentsToolsResolveSlackBotToken`,
  prints `member-bot-token|shared-bot-token <token>`). Never keep the team's token in a member's scope.
  `magic-team` is an identifier; read `magic-team.shared.md` "Identifier and identity" before renaming.
- **Workspace domain** for `X-Request-Detail`: the member's own `SLACK_WORKSPACE_DOMAIN`, then
  `magic-team`'s (`AgentsToolsResolveSlackWorkspaceDomain`). It is persisted by
  `--intern-op-check-configs <scope> --resolve-slack-workspace-into SLACK_WORKSPACE_DOMAIN` (user token
  first) on that scope's config-check pass (`--magic-heartbeat-config-check`,
  `--client-sweep-config-check`). A member without its own pass gets the team's domain, which is wrong if
  its token is in another workspace: add a pass, never a per-call `auth.test`.
- **`X-Request-Detail: slack-workspace=<v>; client-member=<v>; channel-id=<v>`** goes on stderr ahead of
  `KEY=value` fields, at every attributable call site. Text only. `client-member` means the acting member,
  not a `client-*`. Unresolved values are `<lookup-failed>` or `<none>`. Scope polls and the domain
  resolve carry none. `channel-id` is read at emit time.
- **Form values go in the POST body, never `-G`.** A long message in the query string hit a 414.
- **`ok:false` requires a Slack verdict.** A body `AgentsSlackJsonField.awk` cannot read is a transport
  failure (`RESPONSE_BODY_STATE=none`).
- **Upload mode** (`--upload-file <name>=<path>`): multipart, curl sets the boundary, not combinable with
  `--json-body` or `--fetch-url`. Reports `UPLOAD_HTTP_STATUS=` and `UPLOAD_BYTES=` (bytes sent;
  `not-reported` when curl wrote nothing). No content type field: the JSON verdict suffices. The body goes
  to its own file with `-o`.
- **`--intern-op-url-post-bytes --url <url> --body-file <path> [--context <op>]`** POSTs raw bytes with no
  credential. Its name avoids the `--intern-op-slack-*` glob so credential resolvers are not even defined
  in its shell. The URL is a bearer capability: never in diagnostics, curl stderr discarded, body printed
  only on 2xx. `POST_HTTP_STATUS=`, `POST_BYTES=` (sent). Transport failure writes `000 0`. https only. No
  `EXIT` trap. The URL stays in argv by decision (single-use, short-lived).
- **`--intern-op-slack-check`** reads one target (`magic-team`, `human-owner`, `event-track`, `event-alert`,
  a bare id, or `<channel>:<ts>`). `human-owner` merges both DMs: exit 0 both, 3 one, 4 neither, 1 failed
  early. Pretty `ts | user | text` by default; `--raw` for JSON. `--sweep-read-incoming-comms` also
  defaults to pretty via `AgentsSlackMessagesFormat.awk`.
- **`--intern-op-check-configs` carries no Slack call** except the domain resolve, sourced in that branch
  only.
- **Send header.** `--member-comms-slack-send-message` always prepends the sender's mark, bold name and
  `@alias` before `→`. A member addressee becomes a real `<@U…>` mention via
  `AgentsToolsCommsSlackMentionUserId`: a member by `auth.test` on its own user token, the human-owner by
  `SLACK_CHANNEL_HUMAN_OWNER` (a user id). Anything else degrades to `@alias` text. `users.list` resolves
  nobody.
- **Mention cache** `.local/.agents/slack-mention-ids.cache`, keyed by `cksum` of the advance and
  heartbeat lock notes (so it resets each lock cycle). Rows `member=id=handle=real=display=domain`; the
  id stays field 2; `-` for none. Writes are `|| true`. `AgentsToolsCommsSlackMentionFindByName` searches it.
- **The send reads presentation from `team-members-names.registry` only**
  (`AgentsToolsCommsSlackMemberPresentation`). An external `client-*` send (own user token, or own bot
  token) shows the persona row's names and refuses if they are missing. Other gaps degrade quietly.
  External sends carry no default `magic_sender` metadata; client addressees stay plain text (their ids
  are in another workspace); the bot swap after `channel_not_found` is skipped unless the bot is the
  member's own. Email shows only the address.
- **`AgentsSlackBlocksBuild.awk`** (markdown → Block Kit):
  - backslash escapes run before every other branch, including code spans; the punctuation set is spelled
    out there, not taken from `isPunctCh()`, which drops backtick and quotes on purpose;
  - only `"# "` makes a `header` block; deeper headings become bold lines;
  - `[label](url)` is consumed in one step, after code spans; `(` nests in the url, `]` does not nest in the
    label; whitespace in the url means prose;
  - bare `http(s)://` becomes a `link`; a bare address becomes bold text (Slack auto-links display text
    anyway);
  - tables are recognised at the delimiter row by looking back; rows pad to the widest row; cells are
    `rich_text` with a space element when empty; `\|` is unescaped by the splitter;
  - empty nodes are what Slack rejects as `invalid_blocks`; empty fence lines, headings and bullets emit
    nothing; `appendElem` keeps commas right.
- **`AgentsBlockKitValidate.py`** walks the payload actually sent (after splices) and holds the three
  table maxima. `TOPLEVELTYPES` is top-level blocks only: a new block type must be listed there; a new
  rich_text element need not. Not caught: 50 blocks, 150-char header, caller payload fields.
  `AgentsSlackBlocksTextVersion.py` has no `table` arm; a hand-written table gets `[table]` text.
- **`invalid_blocks` is a verdict, not a transport fault**: no retry, no "stuck" email. The exhausted-retry
  arm returns 1 whatever the notification email did.
- **Profile ops** (`AgentsTools.MemberCommsSlackProfile.include`, routed inside the member Slack include):
  persona identity only, three layers (`--identity-bot` refused, `--identity user` always, `routine-*`
  refused). An empty string is a value. Up to four calls; all fields validated before the first; each
  facet reported `applied|failed|not-requested`; no rollback. The avatar is always its own
  `users.setPhoto` upload (upload wins at the transport and would drop JSON fields) and its path may not
  contain `;` or `,`. `profile-get` exits 0/3/4/1 by facets read. Not in the heartbeat scope poll list.
- **Slack profile facts**: a profile is per workspace. Which of `display_name`/`real_name` renders is a
  viewer preference. `display_name` is the `@handle`; never change it to fix rendering. `title` is a
  workspace custom field; where it is not writable, `users.profile.set` answers ok and discards it (test
  with a plain field like `phone` first). Custom field ids differ per workspace (`team.profile.get`).
  `status_text` and `status_emoji` must travel together; the error fires only when one travels alone and
  empty.
- **Presence** (`--member-comms-slack-presence-*`, no help pair): held by a websocket, never set
  (`users.setPresence` has no `active`). User token only (`rtm.connect` refuses bots). Keyed by
  `<team_id>:<user_id>`, one holder per account, found by argv match, start under a `mkdir` lock,
  extended with `SIGUSR1`, TTL 300 s default.
- **Socket mode** (`--member-comms-slack-socket-*`, no help pair): `SLACK_APP_TOKEN` (member, then team);
  keyed by the token's scope, since Slack delivers each event to one connection. The token reaches the
  holder (URLs expire and refresh); envelopes are acknowledged on arrival; continuation frames are
  reassembled. Only `app_mention` is consumed, filed as an `inquiry-*` in `magic-coordinator`'s inbox
  with `communication-channel-id`. No TTL. No log of its own: rows go to the workspace Slack log,
  `comms-slack-send.YYYY-MM.log`, in its eight columns (target `socket`, column 6 the event kind
  `connected|reconnect|received|error|stopped`, reason never a body or token, session `-`); `--status` reads
  them from there. Its framing is separate from the presence holder's on purpose.
- **File share**: three calls (get upload URL, raw POST via `--intern-op-url-post-bytes`, complete).
  `files.upload` is retired. Target resolved before step 1; `SLACK_CHANNEL_HUMAN_OWNER` is a user id and
  must be opened as a DM. `thread_ts` must be the parent ts (normalised via `conversations.replies`).
  `blocks` is ignored beside `initial_comment`, so `--comment` is a separate message after the share.
  Length is bytes (`wc -c`, `LC_ALL=C`). `is_public:false`, `file_access:visible`. No `EXIT` trap.
- **A member needs no user token to post under its own name**: the app has `chat:write.customize`
  (`username`, `icon_url`). No op uses it yet. A user token is for what a bot cannot do, like presence.
- **`--intern-op-contact-digest-send <member> <origin> (--resolved|--needs-ruling) <text...>`**: stub over
  the send. The origin is any member, carried in `--address-to`. `--needs-ruling` goes to the human-owner's
  DM under the user identity; `--resolved` to the bot's conversation with him (`--identity-bot`). Public
  wrappers: `--magic-contact-digest-send` (origin given) and `--member-contact-digest-send` (origin is the
  caller). See `non-owner-contact-tiers-and-escalation` in `magic-team.conversations.md`.

## 19. Email, Trello, Atlassian

- **Email send** is `multipart/alternative`, plain first, UTF-8. `AgentsEmailHtmlBuild.awk` escapes HTML
  once, in `wrapStyle`. Bare URLs link; bare addresses are bold blue with no `mailto:`.
  `AGENTS_EMAIL_SEND_BUILD_ONLY=true` builds without sending.
- **Email reads** fetch in a subshell redirected to a file (a `$( )` loses NULs and leaks `set +e`).
- **`--member-git-repo-history`** runs `git log` only, with `GIT_OPTIONAL_LOCKS=0`, no pager. Containment
  is on the resolved path against the workspace plus `AgentsToolsClientAccessRoots read`; symlinks and
  `..` are refused; empty root lines are skipped (an empty root matches everything). "outside the
  readable roots" is fixed in the machine access-roots config.
- **Atlassian layout.** All logic is in one internal op per call in
  `AgentsTools.InternOpAtlassianCall.include`, over `AgentsToolsAtlassianCall`, behind one arm. Public
  `--member-`, `--magic-` and `--client-comms-jira-*|confluence-*` are stubs. A product-specific internal
  op names its product; `-call` and `-check` take `--product`.
- **A stub is a fixed mapping.** It admits exactly its shape and refuses anything else before a call:
  "<name> missing", "--flag value missing", "unexpected: <word>", or "not accepted: <arguments>". No
  explanation, no syntax tail. It forwards `--member` and `--context`; the internal layer refuses a second
  of either. Diagnostics use the stub's context. A stub prints nothing itself and never calls another stub.
- **Keys**: `JIRA_SITE/JIRA_USER/JIRA_API_TOKEN` and `CONFLUENCE_SITE/CONFLUENCE_USER/CONFLUENCE_API_TOKEN`,
  from the acting member's scope, no fallback, never crossed: separate sets let one be rotated alone.
- **Exit codes** (Atlassian transport only). Faults ⛔: 1 contract error before any call; 3 no usable
  answer (transport, unreadable body, 3xx, 5xx); 4 credential rejected (401). Designed refusals 🙋: 5
  conflict (409); 6 not configured; 7 forbidden (403, not yet seen live); 8 not found or invisible (404);
  9 any other 4xx (400, 410, 422, 429). One branch sets mark and code together. `page-update` compares rc
  to `5`; rc 5 elsewhere in the package means "no CLI selected", which is why "not configured" is 6.
  `AgentsAtlassianJsonObjectMerge.py` exit 3 means a forbidden key, a different producer.
- **A failure is one stderr line**: mark, op name, status, and the site's body verbatim.
- **Jira gotchas**: `/rest/api/3/search` is retired (410); use `/search/jql`, which refuses an
  unrestricted query (400), pages by `nextPageToken`/`isLast`, has no total. An unresolvable JQL returns
  200 with no rows, so an empty result says nothing beyond that query. A bad token gives 401 on
  `/myself` but 404 on a private issue (anonymous); `--intern-op-atlassian-check --product jira` is the
  credential check. A null description is a real answer. Default format `adf` (writable back);
  `rendered` is offered.
- **Jira writes**: `issue-create` never calls createmeta; extra fields via `--fields-json`, merged by
  `AgentsAtlassianJsonObjectMerge.py` (no text splicing). Never auto-retry a create with an unknown
  outcome (no idempotency key). `issue-update` takes `--fields-json` (full replace per field) and/or
  `--update-json` (add/remove/set); `status` is refused locally; `notifyUsers` defaults to false.
  `issue-transition` always looks up transitions and matches `to.name` exactly; zero or several matches
  fail before the POST. `comment-add` has no `visibility`.
- **Jira lists**: paging values are whole numbers, refused when wrong. Every list states
  `more: no|yes|unknown`. `sprint-list` checks the board type and the `SPRINTS` feature first (kanban and
  disabled simple boards print an empty list with `more: no`); it never matches localised error text.
  Agile reads return the site's JSON; Confluence listings render TSV.
- **Confluence gotchas**: REST v2 has no rendered form (`storage` or `atlas_doc_format`). `page-search`
  and `comment-read` have no completeness signal (`more: unknown`); `space-list`
  (`/wiki/api/v2/spaces`) terminates via `_links.next`, and its cursor passes through verbatim.
  `page-create` needs the numeric space id (`--space <key>` looks it up, refusing 0 or many matches).
  `page-update` is version-gated: the caller passes `--version <n>`, the op sends `n+1`, never re-reads
  (that would defeat the lock); it is a full `PUT`, so `--title` and `--status` are required; on 409
  re-read, never resubmit. `comment-add` is storage only; a reply's parent on another page is refused.
  Write bodies are assembled by hand with `AgentsMcpJsonEscape.awk`; every field has its own flag.
  `page-update`'s all-required refusal still uses `/` for an alternation and should move to `|`.

## 20. Questions, decisions and review

- **The `AskUserQuestion` wait** takes only the addressee's replies and judges every reply since
  `question-ts`. A typed verdict is the reply's first word, or a declared reaction
  (`AgentsEscalationVerdict.awk`); no negation parsing. An unclassified reply returns
  `VERDICT: UNCLASSIFIED` with `WAIT-ID:` and `NEXT:`; re-waiting is the agent's choice; `pending_id`
  re-waits without posting, for the asking session only.
- **The ask's wait is the session's `Wait`**: the item `ask:<pending-id>` joins the stored wait
  (`--wait-add`) and is resolved by `AgentsHarnessAskResolve`, called by both `AskUserQuestion` and
  `Wait`.
- **One person, one running thread** (`AgentsTools.AskThread.include`). Questions are numbered `Q<n>` per
  addressee under the ask lock. An identical open question returns `ALREADY-OPEN` and posts nothing. A
  leading `Q<n>` in the question text is removed. In a shared thread: a reply starting `Q<n>` answers
  that one; an unnumbered reply answers the latest question above it while open, and none after it is
  closed (`resolved-epoch`). `AgentsToolsAskThreadOthers` feeds the others to `AgentsSlackThreadAnswers.awk`.
- **Collect** (`--intern-op-pending-reply-collect`, `AgentsTools.PendingReplyCollect.include`), no model:
  reads each open plain question once with a zero-bound wait. Readbacks, decisions and permissions are
  never collected by default. Runs at `SubagentHandback`, at spawn close (marking `collect: ended`) and in
  the main loop (`--ended`, answers go to the asker's inbox). The `--ended` pass also takes asks older
  than `MDAT_PENDING_COLLECT_STALE_MINUTES` (120), up to `MDAT_PENDING_COLLECT_STALE_MAX` (40), applies
  typed verdicts, and closes asks of still-running sessions quietly (`MDAT_PENDING_CLOSE_QUIET=1`).
  Results in `.local/agents/pending-collect.last`.
- **Remind** (`--intern-op-pending-reply-remind`, `AgentsTools.PendingReplyRemind.include`), tooling only,
  every main-loop iteration: at 30 min, 2 h, and daily after 09:00 local for asks 4 h+ old
  (`.local/agents/pending-remind.daily`). More than 10 due for one person: one DM digest; otherwise a reply
  in each thread. Sent as the ask's owner under `ask-identity`. A failed send stamps nothing.
- **A pending record never expires by age**, and a reminder never closes one. Every close holds the
  record's lock; `--if-open` makes a second closer get `ALREADY-CLOSED`. A resolved question gets
  reactions (`:eyes:` on the answer, `:white_check_mark:` or `:ballot_box_with_check:` on the question);
  a failed reaction never undoes a close.
- **Decisions** (`AgentsTools.ItemDecisions.include`): a pending record links its item (`task_ref`, else the
  session's `spawns:` item). Every close appends one line to the item's `## Decisions` (marked
  `<!-- decisions-of: <item> -->`) via `--intern-op-decisions-append` under a per-item lock; a dispatch
  item's line also goes to its `tracks:` task. A received answer clears matching `blocked-on`/`condition`.
  `--intern-op-pending-reply-earlier` stops asking the same thing twice (`NOT ASKED AGAIN`). Decisions are
  shown first (30 lines) in briefs, `conversation.md` and scans.
- **Review** (`AgentsTools.ReviewFlow.include`): only a `running` item enters `review` (handback, child
  ended without handback, `--wait` pass ended, `--member-review-request`). The review limit
  (`REVIEW_WAIT_LIMIT`, default 3600 s) is enforced by `Wait` itself, returning `DISMISSED`, so it needs
  no main loop. Verdicts `--member-review-accept|return|reject|follow-up` (`--intern-op-review-*`); a
  return restarts the session through the proxy's join path. Endings (`archived`, `trashed`,
  `shutdown`, `taskstop`, `review-wait-expired`) are recorded as `dismissed:` lines. A parent with no
  thread gets `parent-thread:` written on the child's record.
- **Session transcripts** (`AgentsTools.SessionTranscript.include`): one per spawn in
  `audit/YYYY-MM/session-<startUTC>-<member>-<sid8>.log`, rolled at 8 MB (`MDAT_TRANSCRIPT_ROLL_BYTES`),
  named before the dispatch item exists, located via `.local/agents/sessions/<spawn-id>/transcript`. No
  pointer, no writes. One formatter, `AgentsSessionTranscriptFormat.awk`. Never file content. A native
  claude spawn is written from its stream (`AgentsClaudeStreamJsonTranscript.awk`, marks
  `transcript.stream`). Commits at milestones only. `sessions/<sid>/tokens` becomes the item's `tokens:`
  header; rollups are summed when shown, never written up the chain.
- **The event-track thread is the session's debug feed** (`AgentsTools.EventTrackFeed.include`): one open
  post, sent 5 s after its first line or right after an error, refusal or session event joins it, the feed
  polled every 4 s (under 10 s from a line to its send; fixed in code, no knobs), cut at 4000 characters
  (Slack's `text` limit); blocks by subject, one templated line per operation, never a raw line. Its root,
  the spawn's `start` post, is posted once, after the CLI and the rest it names are resolved; no post is
  ever edited, and a later fact (a different CLI launched, the end) is a reply in its thread.

## 21. Permission refusals and grants

- **A refusal is a recorded fact.** A harness Write/Edit refused by the write-root check or the unattended
  team-store rule, and a Read/Grep/Glob refused by the read-root check (`AgentsHarnessReadGate`: read
  roots, else `AgentsHarnessGranted`, the same grant-read the write gate and the native hook ask),
  writes `.local/agents/sessions/<id>/refusal-<uuid>.md` first
  (`--intern-op-permission-refusal-log`), then posts to event-track. The result adds `REFUSAL-ID:`
  (`none` without a session or record).
- **Grants are keyed by session, member, tool and target** (resolved path, or exact command bytes), taken
  from the record, never the ask's text. Allow-once is spent by one `mkdir consumed/<id>` when the gate
  admits the call, and an unused one lapses `MDAT_PERMISSION_ONCE_TTL` seconds (default 300) after its
  grants-line stamp, reads and writes alike (`AgentsToolsPermissionOnceLive`). Planned allows come from the session's dispatch item (matched by `session-id:` or
  `spawn-id:`) and its `tracks:` item, `session` or `task` entries, never signed by the session's own
  member nor by one who does not hold the entry.
- **What a member holds is one computation** (`AgentsTools.PermissionHolds.include`,
  `--intern-op-permission-holds <member> <tool> <target>`, `HOLDS <layer>` or `NOT-HOLDS`): human-owner
  (his name or `SLACK_CHANNEL_HUMAN_OWNER`), `floor` (the team tools, the member's floor rows of
  `grants.index`, and its session's own sandbox), `standing` (its own rows of `grants.index`, every `*`
  row unrolled there: a `write` row, from `allow-write`, is every file tool on its glob; a `read` row,
  from `allow-read`, is Read/Grep/Glob only; `tool` rows `<tool>[:<target>]`, from the `allow-tool`
  declare verb, never projected into Claude settings), then `set`/`passed`/`granted` session or task
  grants. No write tool is held in a read-only place, through any layer. `cred` and `spend` skip floor and
  standing. Grant-read admits floor and standing as `GRANT: standing`.
- **No approving what you don't hold.** `grant-open` returns rc 3 with `NOT-HOLDS:` and `HOLDERS:`;
  the escalation verdict path checks first and re-addresses the ask to a holder participant
  (`--intern-op-permission-holders`), else forwards it to the human-owner; it stays open.
- **Kind `task`** lives while its item is in an open board state (`<refusal>.task` sidecar or the
  record's `task:`). Passed (`pass-<uuid>.md`) and set (`set-<uuid>.md`) grants are records like a
  refusal's, `owner:` the receiver, kept in the coworking session's store; a session reads its own, its
  coworking session's and its parent's store, its own grants only. A passed or set target may be a
  `<path>/**` or a `<url-prefix>*` pattern; a refusal's grant is exact.
- **Harness read and write roots are per member**: a named member's declared grants are its own rows
  and every row declared for `*` (every member), so it reads the read floor plus those `Edit` and
  `Read` rows, and never the harness index's
  union. A served call with no `MDAT_SPAWN_AGENT` (the human-owner's own session under the default
  identity) and the native clients' settings keep every member's rows.
- **A named member's file tools are decided by its session permission index** when the harness is given
  no root flags: `sessions/<id>/permissions.<member>.index`, the member's rows of `grants.index` joined
  with the session's own grants (session, task, once; its own, coworking and parent stores). Every check
  is builtins only: two `-nt` tests (it must be strictly newer than `grants.index` and every joined
  store's `grants`), then a loop of `[[ ]]` over rows whose globs were translated into bash patterns at
  the rebuild (one awk). The ceiling first: a write in a read-only place is refused, not recorded, naming
  the session sandbox `output/` or "find another suitable location". A once row's expiry and use, and a
  task row's open item, are checked only on the row that matches. Opening, using up and revoking a
  grant touches the store's `grants`. Children's folders and the member's own directory are
  admitted at run time; the routine and planned layers are asked only on the way to a refusal.
- **A session grant ends with the session whose store holds it**: its spawn record
  (`spawned/*/<store id>.md`) closed with a `spawn-*` status other than `spawn-started`
  (`AgentsToolsGrantsSessionEnded`, builtins only). Checked on read (`AgentsToolsPermissionGrantScan`,
  and the matching session row of the session index, since a joined store's end touches nothing);
  the rebuild drops them. A session with no spawn record (the human-owner's own) never ends this way,
  and a coworking store ends with the spawn whose id it carries.
- **Revoke** (`--magic-permission-revoke <ref>`, implemented as `--intern-op-permission-revoke`):
  `<store>/revoked/<ref>`, a file (awk tests it by `getline`, which cannot tell a directory), then
  `AgentsToolsGrantsStoreTouch`. Every reader skips it. A task grant's entries (its `task:` grants
  lines without the trailing ref, the form set-apply writes) also leave its item's `allows:` through
  the board edit primitive, and a `verdict` line goes on the item's Decisions; best effort.
- **An ask addressed to a routine** (`to: <name>.routine`, typed kinds only) posts nothing: the
  harness records it with `address-to` the routine and waits on the record, as for a member with no
  Slack account. `AgentsToolsRoutineFile` (TeamRegistry) is the one routine lookup;
  `AgentsToolsRoutineIsExecutor` (ItemDecisions) admits its executors to the answer and the forward,
  and a reroute forwards as the executor answering. `AgentsPendingAsksForRoutine` (ReviewFlow) lists
  one workspace's open asks per routine, oldest first; `--intern-op-permission-escalation-input-scan`
  (stub `--magic-permission-escalation-input-scan`) reads every known workspace's, reading each ask
  against its own (`MMDAPP` set in a subshell). The record also keeps `task-ref:` and `reason:`.
- **Place names at request time.** `--magic-permission-set-request` takes `<tool>:@<name>[:<glob>]`,
  resolved by `--intern-directory-resolve` and `pwd -P` to the path it is asked for; an absolute path
  stays allowed. A write in a read-only place is refused there and in `grant-open`, before the holds
  check (the human-owner holds everything, and the harness would refuse the grant anyway), naming the
  route. The `name:relative` hint (`--intern-directory-of`) is printed as `PLACE:` and recorded as
  `<ref>.places` (natural target, TAB, hint) beside the grant's record, the way `.task` is.
- **Session pass** (`--member-permission-session-pass`, implemented as `--intern-op-permission-session-pass`):
  `--entry <tool>:<target>` entries resolved as a set request's (`AgentsToolsPermissionEntryPlace`: `@name`,
  ceiling, `PLACE:`, `<ref>.places`), all checked before anything is written: `AgentsToolsPermissionHolds`
  in that session, never a task-held one; passer and receiver both in `AgentsToolsPermissionParticipants`
  of the session (no task). Each entry is its own `pass-<uuid>` `session` grant, signed by the passer, in
  `AgentsToolsPermissionShareStore`'s store, then `AgentsToolsGrantsStoreTouch`; it ends with that
  store's session and is revoked by its ref. `--member-permission-pass` (once/session/task, a plain
  target, no store touch) stands beside it unchanged.
- **`--magic-permission-list` / `--member-permission-list`** (`--intern-op-permission-list`) are
  `AgentsGrantsSessionIndex.awk` in `mode=list`: the same filters as the index, plus a once grant's
  use and TTL and a task's item, read in the awk.
- **`allow-read` is `allow-write` without the write**: same `<scope>:<selector>:allow-read:<member>:<glob>`
  layout and the same selector resolution; its rows carry `Read(...)`, so they join that member's read
  roots and the Claude settings as `Read(...)`, and never a write set or `Edit`.
- **Escalation kinds** readback, decision and permission always wait. `AgentsTools.MemberEscalation.include`
  applies a verdict once, under a `mkdir` lock.
- **Attended only for an interactive Claude Code client**: `CLAUDE_CODE_ENTRYPOINT` `cli` or
  `claude-vscode`, no `MDAT_SESSION_UNATTENDED=true`, no spawn id. To admit a new surface, add it to the
  `case` in `AgentsHarnessUnattended` and in `client-hooks/permission-request-escalation.sh`. An
  unattended session never Writes/Edits the team store or session store.
- **The boundary is honest agents with an audit trail.** All of this is plain local state; `execute` can
  write any of it.
- **Targets are stored natural.** The record escapes `%`, newline, CR and edge whitespace only
  (`AgentsToolsPermissionEscapeRecord`); the grants file also escapes `,` and `:`
  (`AgentsToolsPermissionRecordToGrantField`). `AgentsHarnessRefusedTargetDecode` is the exact inverse,
  `%` last.

## 22. Test instruments

Each instrument states what it proves and its red recipe in its own header. What a maintainer must know:

- **Wired into `--owner-setup-scaleway --check`**: `HARNESS_PARSES`, `AgentsHarnessSelfCheck.test.awk`
  (four sites per tool; text match, so it misses syntax and JSON breaks), `AgentsHarnessToolsJsonCheck`
  (parsed vs text counts; reads through `AgentsHarnessJsonSlice.awk`, not the consuming reader),
  `AgentsHarnessAccessRootsCheck` (no-flag roots come from the include), `AgentsHarnessServedFloorCheck`
  (served set and `Monitor` twin; a planted copy must be named as `MDLT_ORIGIN`), the leg checks
  (`AgentsHarnessCopilotLegCheck`, `AgentsHarnessGrokLegCheck`: endpoint, host, credential pinned; models
  read from the leaf), `AgentsHarnessAnthropicWireCheck`, `AgentsHarnessRestartCheck`,
  `AgentsHarnessMcpCheck`, `AgentsHarnessWaitCheck`, `AgentsHarnessAwkAxiom.test.awk` (a statement and its
  closing brace on one line need `;`, for awks not on a dev box), `AgentsOwnerSetupCheck`.
- **`AgentsHarnessContainmentCheck.test.sh` is wired into nothing** and runs only by hand. It tests
  `AgentsHarnessResolveDir` and `AgentsHarnessPathAllowed` together, in both polarities.
- **Diff checks hold a rewrite to its previous implementation**, kept only as fixtures in
  `sh-test/check-fixtures/*.legacy.*`: `AgentsWireStreamDiffCheck`, `AgentsHarnessJsonFieldDiffCheck`,
  `AgentsHarnessHooksDiffCheck`, `AgentsRegistryRowsDiffCheck` (also `--live-copy-from <workspace>`).
- **Reaching a gated harness path offline**: set the dummy `HARNESS_*` a stub sets, put a fake `curl` first
  on `PATH`, use a `.invalid` host. The resolved roots travel in the system prompt, so the recorded request
  body is the observation. `--intern-tool` reaches no endpoint, so the tool gate itself is observable.
- **Three ways a probe passes and proves nothing**: a control that runs a different command shape
  (`find -L -type l` reports only dangling links); a rig that lifts functions and silently misses a
  dependency (exit 127, empty output, success); a fixture under `$TMPDIR` that the access roots refuse,
  stubbed past. A rig must relocate the gate onto its fixture (`MMDAPP="$rigTmp"`, or pass the fixture as
  the allowed root), or use the granted work directories `$MMDAPP/.local/temp/team`,
  `.../member/<member>`, `.../task/<member>`.
- **Other offline checks**: `AgentsSlackBlocksLinkifyCheck`, `AgentsSlackBareUrlLinkCheck` (through a real
  send with `check-fixtures/slack-send-identity-check.curl.test.sh`), `AgentsEmailHtmlPartCheck`
  (build-only), `AgentsSessionContextReadsCheck` (fake Slack and fake `imaplib`), `AgentsSlackRateLimitCheck`,
  `AgentsHeartbeatDayRhythmCheck`, `AgentsBoardRecheckInCheck`, `AgentsApprovalCascadeCheck`,
  `AgentsGroomingToBacklogApprovalClearCheck`, `AgentsVscodePanelInstallCheck`,
  `AgentsHarnessSkillRangeCheck`, `AgentsHarnessSkillReadCheck`, `AgentsRefusedTargetDecodeCheck`,
  `AgentsHarnessMcpIndexCheck`, `AgentsHarnessSetupIndexCheck`, `AgentsHarnessToolCallsReadCheck`,
  `AgentsHarnessArgTableCheck`, and the ask, pending-reply, decisions and review checks.
- **`sh-test/AgentsSweepTimingInstrument.sh` asserts nothing** and is kept off `.test.sh` so no sweep runs
  it: `MMDAPP=<ws> sh-test/AgentsSweepTimingInstrument.sh [<latency> [<dms> [<clients>]]]`, `INST_KEEP=<dir>`
  keeps output.
