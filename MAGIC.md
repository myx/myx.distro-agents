# MAGIC.md — myx.distro-agents

Maintainer notes for this package. Each entry is something that matters when you change the code and
that the code and docs do not readily tell you.

- How to install, configure and use the package: [README](README.md) and its [docs/](docs/) pages.
- Call contracts of public operations: `sh-lib/help/Help.DistroAgentsTools.help.md` (`--help`),
  `--member-help <member>`, `--help-setup-<domain>`, and the syntax of one operation, `--help-syntax [<op>]`.
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
23. Owner resolutions, 2026-10-30 and 2026-10-31

---

## 1. Dispatcher and code layout


- **One dispatcher.** `DistroAgentsTools.fn.sh` has exactly one top-level function and one `case`, like
  every sibling `Distro*Tools`. New operations go inline in that `case`. Never a separate
  `DistroAgentsTools<OpName>` function per operation.
- **A helper shared by one family lives in that family's include**, not at file scope.
  `AgentsToolsAssertBareName` (in `AgentsTools.BareName.include`) is the bar for "general";
  it is not licence to add more file-scope helpers. The harness's `AgentsHarnessBareName` asks the
  same gate.
- **A source stays at the top only if every hot path of that file uses it.** Every entry script and
  shared include loads, before its `case`, only what each of its operations reaches: the context, the
  front door, the one family include. Anything else is sourced in the branch or function that needs it,
  in the form `type <Fn> > /dev/null 2>&1 || . "<path>"`, and repeated where two branches need it. A

  static list, or a value one branch reads, is written in that branch, never at file scope.
- **One arm per group of operations.** A family arm sources one include, or several when one gets too
  big. Size is the only reason to split. A family arm works only because every stub of that family
  lives in the include it sources. A stub placed in another file is not routed, and nothing reports it.
- **One include per operation, one per kind of source (S28.1).** A call reads only its own path.
  - The Slack router `AgentsTools.MemberCommsSlack.include` holds the stubs and one arm per operation. Each arm sources `AgentsTools.InternOpCommsSlack<Operation>.include`.
  - File-info has its own include, which `--slack-file-info` and file-fetch both load. Send carries the mention and presentation helpers.
  - A Wait runs `AgentsTools.MemberWait.include`, then `MemberWaitSources`, `MemberWaitRun` and `MemberWaitResult`. Each ends by sourcing the next.
  - `MemberWaitCore` holds the helpers the probes share. One piece per kind of source is read only when the wait holds a source of that kind: `Slack`, `Replies`, `Ask`, `Mentions` (mentions and tagged), `Dms`, `Chat` (chat and scan), `Local` (file, process, inbox, board, wake).
- **Order matters.** The comms routes come before the `--member-*` route, or the broader glob takes
  them. An arm that claims a prefix (`--intern-op-slack-*`, `--intern-op-permission-*`) must have any
  differently-routed op of that prefix above it.
- **Family routes.**
  - the coordinator's own comms operations → `AgentsTools.MagicComms.include`.
  - `--client-comms-*` → `AgentsTools.ClientComms.include`.
  - `--<service>-*` (the tool file of the platform) and
      `--intern-op-comms-<service>-*` share one arm per platform.
  - `--intern-op-atlassian-*` → `AgentsTools.InternOpAtlassianCall.include`.
  - `--magic-<routine>-*` → `AgentsTools.Magic<Routine>.include`, one explicit
      arm per op even where two arms are identical today.
  - `--manager-*` → `sh-lib/manager/AgentsTools.Manager.include`, one further
      include per subject, `AgentsTools.Manager<Subject>.include`.
    Its subjects are `Session`, `Routine`, `Schedule`, `Spawn`, `Config`,
      `TeamMember`, `TeamData`, `PendingReply`, `Dashboard`, `Place`,
      `Console`, `Check`, `Keys`, `Command`, `Feature`, `Help`, `Manual`.
- **One team, two organisations.** A call reaches our own organisation unless it is on the client
  side: a `--client-*` operation, or a `client:` address, of a `client-*` member
  (`AgentsTools.CommsSide.include`). A `client-*` member's own settings for an outside system are the other
  organisation's. They are read on the client side only, with nothing of the
  team's read in their place.
  The prefix and the address select the side, never a credential the member happens to hold.
- **All non-member Slack code is in `sh-lib/slack/AgentsTools.CommsSlack.include`**: the shared helpers, the
  in-context helper `AgentsToolsSlackCheck`, and `--intern-op-slack-call` and `-check-scopes` (whose
  `--scope-source` may name an `AgentsTools*` helper). The dispatcher holds no Slack code. Any include may source that file just for its helpers. It is a library: sourcing it defines its functions and runs nothing, and its two operations run through `AgentsToolsCommsSlackRun`. An unimplemented `--intern-op-slack-*` name is still refused there.
- **One operation calling another** recurses into `DistroAgentsTools` itself (the
  `DistroLocalTools --upgrade-installed-tools` precedent) when it needs what
  the dispatcher does on entry. Either the call is a root entry, or it names a
  member whose workspace can differ from the caller's. That is the
  member-workspace switch. Code already running in a set-up context, acting for its own member or for
  none, calls an in-context helper instead. That helper is an
  `AgentsTools<Area><Thing>` function in its family's include, sourced without
  running that include's `case`, with no `--` operation of its own.
- **An external caller runs a script; an internal caller sources the include in a subshell.** A script
  also sets up the execution context, which is why the MCP daemon execs the tooling. Re-entering the
  whole script makes an internal caller pay for option parsing twice.
- **An include is spelled `$MDLT_ORIGIN/myx/<package>/sh-lib/<folder>/<file>`**, whole, or after a
  `${MDLT_ORIGIN:-<default>}` default, `<folder>` being the file's folder under `sh-lib/`. No resolver and no map stand between the spelling and the file. A move of a
  file is one plain replace of the paths that name it.
  `AgentsOriginPathsExistCheck` (`sh-test/common/`) does the checking. It fails on a statement `. <target>` or `source <target>` that names such a
  file in another form, listing it as `<file>:<line>`. Those forms are a path
  built from a variable, or one relative to the script. It also fails on any
  `$MDLT_ORIGIN/myx/...` path the packages spell that names no file. A path that goes on into a variable, a glob or a brace is a pattern, and is not asked about.
- **`--intern-` is a namespace, and the next segment is the kind.** `--intern-op-*` is operations,
  `--intern-tool` is tools (the harness arm that runs one tool and exits). `--intern-mcp-*` and
  `--intern-main-loop` follow the same shape. A new kind needs the human-owner's approval.
  `--intern-artifact-*` is one, approved for the Artifact publish (`AgentsTools.InternArtifact.include`).
  `--intern-session-control` is another, approved for the control thread of a session
  (`AgentsTools.InternSessionControl.include`). `--intern-merge-md-files` is a third, approved for the
  markdown merge (section 4). The console's manager screen starts by `--manager`, which has help and
  is no `--intern-` kind.
- **Prefix rule for a new operation**: name it by who may call it. Older `--intern-op-*` ops used by tooling break it.
  - `--intern-*` when tooling uses it, even if member stubs call it too.
  - `--intern-op-*` only when member stubs alone use it.
  - `--member-*` for any member, the tooling checking access on its arguments.
  - `--magic-*` for the coordinator only.
  - `--owner-*` for the human.
  - `--manager-*` for the console itself, a member of nobody, taking no member as
    its second word. It is refused from inside any member's session, the
    coordinator's included (`AgentsToolsManagerCallerCheck`, asked once where
    the family is dispatched).
  - Those called only from a set-up context are now in-context helpers with no
      operation:
    - `--intern-op-slack-check` → `AgentsToolsSlackCheck`
    - `-url-post-bytes` → `AgentsToolsUrlPostBytes`
    - `-comms-slack-file-info` → `AgentsToolsCommsSlackFileInfo`
    - `-comms-slack-resolve-ids` → `AgentsToolsCommsSlackResolveIds`
    - `-comms-slack-conversations-roster` →
        `AgentsToolsCommsSlackConversationsRoster`
    - `-comms-email-mark-seen` → `AgentsToolsCommsEmailMarkSeen`
    - `-comms-trello-check` and `-whoami` → `AgentsToolsCommsTrelloCheck` and
        `AgentsToolsCommsTrelloWhoami`
    - `-atlassian-jira-issue-read` → `AgentsToolsAtlassianJiraIssueRead`
    - `-atlassian-confluence-page-read` →
        `AgentsToolsAtlassianConfluencePageRead`
    - `-contact-assert-known` → `AgentsToolsContactAssertKnown`
    - `-data-read` → `AgentsToolsDataRead`
    - `-item-read` and `-item-upsert` → `AgentsToolsItemRead` and
        `AgentsToolsItemUpsert`
    - `-board-to-processed` → `AgentsToolsBoardToProcessed`
    - `-pending-reply-remind` → `AgentsToolsPendingReplyRemindRun`
    - `-permission-holders` → `AgentsToolsPermissionHoldersPrint`
    - `-permission-set-apply` → `AgentsToolsPermissionSetApply`.
  - The rest cross a process boundary or need the member-workspace switch:
      they stay operations, renamed later in one approved sweep.
- **`--intern-*` is left out of the help.** Out of `Help.DistroAgentsTools.include` syntax lines and out
  of the help.md reference and examples. A public entry that must contrast itself with an internal op
  says so in behavioural terms, without naming the internal op.
- **`--help-syntax [<op>]` is the syntax lines, filtered** (`Help.DistroAgentsTools.include`). With no word it prints those of every operation. With an operation, it prints
  that one's. With a word ending in `-`, it prints those of every operation it
  begins (a family, `--magic-`). A word that names none is refused. Without it the syntax block is the
  entry points a reader starts from: every other operation's syntax sits behind `--help-syntax`, and the manual
  behind `--help`. The lines are the manual's own syntax lines, which the include's match one for one.
- **A tool file of the front table answers the three forms itself** (`AgentsToolsFrontSyntaxLines`, `AgentsToolsFrontHelp`).
  A bare call prints the syntax line of each of its operations, its first form
  where one has several. `--help-syntax` prints every form of every one of
  them, and `--help` renders its own manual. The syntax lines are read from that file's own manual, `Help.<file>.help.md`,
  and the shared include only where no manual is there to read. So one
  operation's forms cannot drift apart in two places. The manual's `##  Options:` says what each operation does, which is also what the tool
  index prints for it.
- **`--mdat-output-format json`, before the operation word,** wraps one of the
  operations that implement a harness or an MCP tool as one JSON object. That
  is `agentsToolOperations`, and it ends with that status. Those are the list
  `DistroAgentsTools.fn.sh` at the top of `execute`: those the harness's tools
  run, and the one behind `{"operation":<word>,"status":<rc>,"result":<its
  output>}`. Every other operation runs as without it, and a word but `json`
  is refused. `AgentsBatchToolsCheck` holds the list to the words the harness
  runs.
- **An operation renamed or retired is deleted, with no alias**: its name is not kept as a shim in the dispatcher. Its callers
  and the skillset are swept in the same change. A call by an old name is refused with the new name in the message
  (`AgentsToolsFrontRetired`, `sh-lib/harness/AgentsContext.FrontTable.include`), and does nothing else.
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
- **`Require <Tool> ||:` comes before `Distro <Tool>`.** `Require` resolves by file through
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
- **The workspace-root guard does not stop the script by itself.** At the head of `DistroAgentsTools.fn.sh`, a
  missing `$MMDAPP/.local` is refused by an `exit 1` inside a subshell. What ends the script is the `set -e`
  on the line above it. Remove or reorder that line and the guard becomes a message the run walks past.
- **`MDLT_OPTION` is the only witness that resolution ran.** The file-load default always sets
  `MDLT_ORIGIN`, so a guard on `MDLT_ORIGIN` alone is dead code here. `DistroSourceTools.fn.sh` and
  `DistroDeployTools.fn.sh` do not default it, so the same test is live there.
- **A caller must not export both `MDLT_ORIGIN` and `MDLT_OPTION`.** That skips resolution and takes the
  pinned origin unchecked. An arm sourcing an include missing from the pinned tree exits 1 with a bare
  file-not-found, which an MCP host cannot explain. Where the include exists,
  a stale copy answers confidently. This is why the `myx.distro` MCP registration writes no `env` object.
- **A command run through an operation inherits the resolved environment.** That is why the MCP
  `execute` lives here: `myx.common`'s MCP path does no environment init.
- **Reaching a `List*` tool.** `Require <Tool> ||:`, then `var="$(Distro <Tool> …)" || status=$?`,
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

- **`MDLT_ORIGIN` is the folder whose child is `myx/`.** So `$MDLT_ORIGIN/myx/<package>/...` resolves: `$MMDAPP/source` for a source tree, `$MMDAPP/.local` for an install. Point it at the package root, and every include resolves under a doubled `myx/myx/`. The run then refuses at once with `No such file or directory`.

## 3. Shell and awk gotchas

- **An `EXIT` trap set inside an op replaces the caller's.** Every op is an arm of one function in one
  process, and `trap - EXIT` then clears the caller's too, silently. An op reached through `$( )` runs

  in a subshell and cannot do this; a plain call can. Explicit cleanup on every return path misses
  `set -e` aborts and signals. The form with neither defect is a trap inside a `( … )` subshell, armed

  before the file is created (examples: `--owner-workspace-forget`, `LocalTools.Config.include`).
  `--intern-op-slack-call` installs and clears its own trap, so callers of it install none.
- **`$(…)` returns when the pipe has no writers, not when the command exits.** Never capture an
  arbitrary or caller-supplied command that way: a background child holds the pipe open forever. Write
  to a file and read it back; `wait "$pid"` where needed. `$( )` is fine for our own self-contained
  commands. A `$( )` capture also truncates bytes at the first NUL.
- **`set -e` containment around executed code**: `(set -e; eval "$(cat)") || execStatus=$?`, then
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
- **`kill` a job's process group, not its pid**, and only while its leader is
  still the process that was kept as it was started
  (`AgentsToolsRunGroupBegan`). Once the leader has ended, what is left
  is ended one pid at a time (`AgentsToolsRunGroupLeft`). It never ends
  the group by a number that is no longer its own. Fork under `set -m` and put the whole pipeline in the
  backgrounded subshell, or `$!` names the last process while the group id is the first.
- **`nohup` sets `SIGHUP` to ignored in the child.** Use `SIGUSR1` to signal a holder.
- **`myx.common lib/catMarkdown` is the one Markdown renderer.** An `_` inside a word and in code stays,
  and its plain output keeps the backticks of code. Its `--spans` output (`--width <cells>` or `--no-wrap`, `--ascii`) gives each
  line as its text, a TAB and its spans. That serves a program that draws the
  text itself. The manager screen draws only that. A table in the text is laid out by that one renderer to the width given, or
  the terminal's. It fits the columns, wraps the cells, marks the header, and
  rules only a row that wraps. With no width the output is as it was. It is plain POSIX awk.
- **A `DistroAgents*.fn.sh` sourced with an argument defines functions and runs nothing.** Its dispatcher
  sits at the foot behind a `BASH_SOURCE` test, so an argument reaches no operation. Measured 2026-11-06:
  sourced with `--help-syntax` it printed only the 64-byte `SystemContext: init:` line, and run as a
  command the same call printed 53459 bytes of syntax. The sourced form's exit status is 0, and the
  silence of a write that never ran reads exactly like success.
- **An empty name probe is not an absent capability.** `command -v <name>` answers what a shell finds by a
  name, and says nothing about a known path. macOS ships `jsc` at
  `/System/Library/Frameworks/JavaScriptCore.framework/Versions/Current/Helpers/jsc`, and
  `sh-test/check-fixtures/vscode-panel-check.node.stub.sh` runs a script on it. Before reporting a
  capability absent, read the tree's own mechanism for it, and put one known positive through the probe.

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
- **`--intern-merge-md-files [--do-index] [--section-prefix <N>] [--section-limit <N>] [--mixin
  [--section-exclude <glob>]... [--section-include <glob>]... <file-name> "<result-section-name>"]...`
  has no help; its contract is here.** Its name is the human-owner's own, approved as an `--intern-`
  kind in the refactorings epic. It merges markdown files into one document on stdout, in one awk
  process (`LocalMergeMdFiles.awk`). `AgentsToolsMergeMdFiles` is the same merge for a caller in the
  same process. Every file comes in by a `--mixin`, which names the section it becomes. A plain file
  argument is refused. A mixin's section is at level `--section-prefix` (default 1, `#`), and
  `--section-limit` levels (default 3) are kept from there. A file's own heading levels are reworked
  to their place under its mixin. A section deeper than the limit is replaced by one line naming its
  heading and its file. `--do-index` puts a `Contents` section first. A mixin's `--section-exclude`
  leaves out each section whose caption matches the glob. Its `--section-include` keeps only the
  matching sections, with the headings above them. A `#` inside a code fence is no heading, and a
  leading front matter is left out. Anything refused is status 1 and one error line, with nothing
  merged. `AgentsMergeMdFilesCheck` is its test.
- **Tests and fixtures live in `sh-test/` and `sh-test/check-fixtures/`.** Anything production code
  calls stays in `sh-lib/`. A check is `sh-test/Agents<Subject>Check.test.sh`, in `sh-test/` or in a
  subfolder of it one level down. Its name is its own in the whole of
  `sh-test/`. Nothing but a check ends in `.test.sh`. A fixture is named by its type:
  `<name>.<command>.stub.sh` or `.stub.py` for a stand-in of a command or a
  module. `<name>.include.sh` marks a rig part a check sources,
  `<name>.driver.py` a driver, and `<name>.legacy.<ext>` a kept previous
  implementation. A data fixture is named by its own extension.
  `AgentsRunTestsSubfolderCheck` holds both. A check keeps `rigHere` at `sh-lib` and uses
  `rigTest="${rigHere%/sh-lib}/sh-test"`.
- **Generated content has two shapes only**: a body file at zero indentation (the caller indents), or
  one `printf`. No heredoc, no stack of `printf` lines, no `eval`-expanded template. A runnable artefact
  is a real script installed by copying. A refusal message lives in the file that says it.
- **Installing a generated file over its target**: the writer emits, the caller installs, through a temp
  beside the target and a same-directory rename. Several temp spellings exist (`<t>.$$` in a trapped
  subshell, `<t>.$$.tmp`, `mktemp <t>.XXXXXX`, `<t>.tmp.$$` in `AgentsTools.Install.include`). Do not convert one to another. A new site uses its file's form. The exception
  is a new `$$` name, which is never that form: `mktemp <name>.XXXXXX` is the
  one correct idiom now. Never under `/tmp` (no atomic rename, symlink
  planting). Set a mode on the temp, never the target. Check the entry landed by re-running the
  idempotent writer and comparing.
- **Scratch paths**: a tool's own scratch goes in the calling session's `output` folder where there is one, and in
  the workspace's `.local/temp` otherwise. The rule is two lines at each site, and no include: he does not want an
  include, a function or a variable for something this small (`AgentsTempNamesCheck` section 7 holds the sites).
  Below that folder a scratch dir is `mktemp -d "<base>/<name>-XXXXXXXX"` and a scratch file
  `mktemp "<base>/<name>.XXXXXX"`. Never `/tmp` or
  `TMPDIR`, so never `mktemp -d -t` or a `mktemp` with no template, which create there. The tooling
  uses neither: with no workspace, a call fails with a clear error. The harness's scratch is the
  spawn's sandbox `tmp/`, else `$MMDAPP/.local/agents/scratch/`. A name spelled with the shell's own process id (`<name>.$$`) is shared by
  every subshell of that one shell. So two writers of one call can collide on
  it. Such a name stands only where `AgentsTempNamesCheck` already lists it,
  with its reason. A new site that makes one fails that test.
- **A bash script of the package starts `#!/usr/bin/env bash`**, and the tooling
  starts one as `"$BASH" <script>`. That is the bash it runs in, never the
  script's path alone nor a fixed path to bash.
  Where `command -v bash` finds none, the tool, the harness and the generated console put the directory
  of the running bash at the end of `PATH`. The tool's entry exports `MDAT_BASH`, the running bash, which
  the Python starters (`LocalManagerScreen.py` of `myx.distro-.local`, `AgentsSlackSocketMode.py` here) start the tool with.
  `AgentsBashPathGuardCheck` lists the places left, each with its reason; `AgentsBashPathProofCheck`
  runs them on a `PATH` whose bash is a recording stand-in.
- **Severity marks**: `⛔ ERROR` for a fault, `🙋 WARNING` for a designed refusal. Keep the asymmetry. A
  warning inside a composed operation is lost in scrollback, so the closing summary repeats it.
- **The bare-name gate** (`AgentsToolsAssertBareName`) validates every member, item and document name.
  Never inline a `case "$x" in */*|.|..)` copy: it accepts spaces, `:` and a leading `-`. It returns 1
  and never exits.
- **A number is refused, never coerced** (`AgentsToolsAtlassianAssertNumber`). A value that reaches a
  query string unchecked can add parameters of its own.
- **Syntax lines**: `|` is exactly one of; `{a|b}` is at least one of; `[ ]` is
  optional. A set that is all required is joined with `/`
  (`JIRA_SITE/JIRA_USER/JIRA_API_TOKEN missing`).
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
  credential is sourced into the console environment, never staged there. `console.pid` and `holder.pid` each hold one line, `<pid> <start>`, written
  with one rename as the process starts. `--console-stop` and a start over a
  stale channel signal a process only while its pid is still that process. A
  file with no start is not signalled, and the operation warns and names the
  pid.
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
  `AgentsMcpServerJsonVerify.awk`, the setup checks). The grants index builder is the one exception. It reads the HOME skills
  folder's own entries. Those tell a real skill folder from a link, and which
  workspace's source tree a link reaches (see "Places", below).
- **The harness `Skill` tool still serves a real folder** a user or vendor put in `~/.claude/skills`. A
  link there is ours and is skipped.
- **The comms cache** is the machine's own copy of every channel a member reads, one folder a channel:
  `$MMDAPP/.local/cache/comms/<service>/<channel id>/` (`AgentsTools.CommsCache.include`). The service is
  the partition, then the whole id as one filename-safe name, the service first: `slack/slack-<channel>`,
  `slack/slack-<channel>-<thread ts>`, and a direct conversation `slack-<user id>-<dm id>`, the user id
  the reading account's. A read through a `client-*` account carries that account first. Email keeps
  the same form, `email/email-<account>-<mailbox>`, a message keyed on its UID and its month the mail's
  own date (`AgentsTools.CommsEmail.include`).
  `.state.txt` is the head line of the read and how it is pulled, rewritten whole by the puller;
  `.pulling.txt` is the one-pull lock, made only where absent. The messages of a UTC month stand
  in its `YYYYMM` folder, one a line in `messages.txt`; a long body is its own file, and a file a
  message carried is fetched once, on demand. `.local/cache/comms/.interest/<service>-<id>` is the
  channel's last read. A read stops refreshing a mark once it is 48 hours old, and the hourly
  clean deletes one at 36 hours. Each reader keeps its own floor.
- **Primary sources and our indices** (in `.local/agents`):
  - hooks: `AgentsToolsClientToolPolicyHookRecords` (`AgentsTools.ClientToolPolicy.include`) →
    `harness.hooks.index`, valid while its version and the `cksum` of the policy and
    `AgentsHarnessHooksLoad.include` match;
  - MCP servers: `AgentsHarnessMcpServersPrimary` (`AgentsHarnessMcpConfig.include`) → `mcp.servers.index`;
  - access roots: `AgentsTools.ClientAccessRoots.include` → `harness.roots.index`.
  An index that does not vouch for this run is ignored, and the same producer code computes the answer.
  A stale index only costs time.
- **`harness.roots.index`** is written by `--make-harness-indices` with `MDLT_ORIGIN` empty, so one index
  serves every origin. Its fingerprint covers workspace, `HOME`, `MDAT_SKILLSET_ROOT`, the names
  under both member-link directories. It also covers the `cksum` of the
  include, the index code, the grants registries, the two place registries and
  `grants.index`. Origin-derived roots and a member's own scratch
  roots are merged at run time. It cannot see a link retargeted outside those directories, or one
  retargeted in the same second the index was written.
- **Where team data lives: two places.** A workspace's own data (`members.registry`,
  `permissions.registry`, `permissions-tags.registry`, `grants.index`, indices) is in `$MMDAPP/.local/agents`.
  `$HOME/.agents/magic-team/` holds only what exists and where to look. That is
  `members.registry` (member, workspace root, link kind, path, member dir,
  TAB-separated), `directories.registry` (pointers: place name, workspace
  root), `member-homes.registry` (member, home workspace root). Last comes
  `permissions.registry` (pointers to workspaces that publish grants, whose
  rows every `grants.index` joins). Defined in `AgentsTools.TeamRegistry.include`.
- **Places** (`LocalTools.Places.include (myx.distro-.local)`). A place is a `workspace` (always read-write) or a
  `directory` (`read-only` or `read-write`); registering one grants nothing. A workspace's own `.local/agents/directories.registry` holds its places for
  this host (name, kind, ceiling, path, declared-by), its own row first, from
  its `magic-team:directory:` and `magic-team:workspace:` declares. Host glob
  comes last, as for `team-member`. It also holds the owner rows of
  `--owner-workspace-upsert`.
  `--intern-directory-register` rewrites it on every update, and its pointers, each under its lock; an
  unread project selection keeps the declared rows. The merged list (`--owner-workspace-list`) reads
  every workspace's file through the pointers. The same name and path is one place; the same name with
  another path: the local row wins, else one warning and `name@workspace`. `--intern-directory-resolve` and `--intern-directory-of` (`name:relative`)
  resolve through it. Members read it by name only (`--list-places`,
  `--get-place-path`), and the projects by `--list-namespaces`. All three are
  routed with the place ops, and never switched to a member workspace. The workspace roots the member
  resolver and the `*` grant expansion walk are its `workspace` rows plus every pointer root.
  `known-workspaces.registry`, the earlier list, is never written. It is read as
  owner rows until the first registration or owner op imports it. Then its
  `.imported` marker ends its reading. Two names
  are built in, needing no registration: `.skillset-shared` is the machine's HOME skills folder;
  `.skillset-.local` is the workspace's own local skillset. Use either in a task, a document or a
  dispatch in place of a path. A custom place name may not start with a dot.
- **Member homes** (`AgentsTools.MemberHomes.include`). `--intern-member-home-register` registers the members a registered workspace
  without agents declares, by the member scan, as `source-declared` rows under
  that workspace's root. A `.` in their grants unrolls to it. Nothing is
  installed there, and their operations run where they are asked. It then picks each multi-workspace member's home. The order is a copy in a
  workspace with agents registered, then the most `magic-team:` lines naming
  it. After that comes a source link, then the first row. A member with no
  source copy, whose copies are all under a workspace's `.local`, has the
  newest of them as its home instead. That holds whatever their content.
  Nothing is warned. A warning prints only for two or more source copies, or for a copy of neither
  kind. One source copy with any number of `.local` copies says nothing. The machine `members.registry` keeps every row.
- **The member index** `$MMDAPP/.local/agents/members.index` and its `members/` view hold this
  workspace's own members only. Built by `--install-skillset-symlinks` and `--make-harness-indices`; a
  rewrite drops any link to another workspace's member. A member of another workspace is never materialised here. A reader that names
  one (routing, a spawn, the client sweeps) finds it through the machine-wide
  registry (`AgentsToolsTeamMemberDirectory`, the row holding its source
  preferred). Its operations run in its own workspace
  (`AgentsToolsMemberWorkspaceResolve`).
  `MDAT_SKILLSET_ROOT` defaults to `members/`; consumers read the variable and never spell the path.
  No fallback to a vendor link folder.
- **Sites that stay `$HOME` on purpose**: the `--scope user-home` fan targets, `~/.claude/settings.json`,
  `~/.claude.json`, and `~/.agents/magic-team/`.
- **`--install-claude-permissions` writes the machine-global `~/.claude/settings.json`** with the fixed
  grants only, and no file grant (`Read`, `Edit`, `Write`): the `PreToolUse` hooks decide. It drops the ones earlier runs wrote: what `claude-permissions.projected`
  records, board grants and acting members' `Edit`/`Write` grants. With no
  record, it drops what the permissions registries claim now. The record
  is then left empty.
- **The workspace set is a publication list, not team membership.** A member absent from the current
  workspace is not an error.
- **The access-root set is defined once, in `AgentsTools.ClientAccessRoots.include`.**
  `AgentsUniversalHarness.sh` uses it whenever no `--access-root` is given. The copilot fragment is a
  consumer, never a source. Where the include is missing, the harness refuses; it never falls back.
- **The workspace root is not in the access set.** Every `MAGIC.md` sits under `$MMDAPP/source`, which
  the unnamed set grants whole and a member reads by the floor's `source/**/MAGIC.md`. The workspace
  root holds nothing worth reading. Installed copies under `.local/myx/` are reachable only by a grant
  (magic-tester's). Do not widen the include.
- **A root flag replaces the whole default set**, and `--access-write-root` narrows writes to the roots
  it names. Adding one write root to grant a work directory revokes every other write, and the call
  still succeeds. The include keeps reads and writes apart; a verb-less flag like `--add-dir` cannot,
  so there a read root is also a write root. Writes are the work directories plus the roots a declared
  `Edit` grant names.
- **A grant's glob is decided per call** (the harness gate, the native hook). Only a `<dir>/**` row
  becomes an `--add-dir` root; the fallback fragment widens a glob to its literal base. A `namespace:`
  grant with no glob covers the whole namespace tree; give a glob, or use `project:` or `workspace:`,
  for a narrow grant.
- **Workspace paths are machine data.** `--owner-workspace-*` keeps them in the places registries
  above, never in a skill folder. A skill folder is a symlink into a repository's
  working tree, so data must never be written there. `.gitignore` keeps
  `skillset/magic-team/human-owner/human-owner.workspaces.md` out of the package.

## The comms event stream (S1.12)

- **The store is a stream of events, and nothing in it is ever rewritten.** A channel's folder holds
  `YYYYMM/events.txt`, one event a line, appended in arrival order. The month is a partition by the event's
  own arrival time, closed once the month has passed. A late event about an old message lands in the current
  month and names the older message in its `msg` column.
- **Sixteen TAB columns, always, in this order**: `id`, `e`, `msg`, `u`, `v1`, `v2`, `x`, `bot`, `sub`, `par`,
  `sender`, `track`, `sess`, `arun`, `adrun`, `body`. An empty column is the absence itself, so no reader
  counts fields to learn what it holds. Two escapes, applied to every column: `\037` for a newline, `\036` for
  a TAB, and `\r` dropped.
- **The kinds**, each with the columns it fills: `msg` (a message arrived, `v1` its own id), `rx` and `rx-`
  (a reaction appeared, and was taken away: `u` the reactor, `x` the name), `thr` (a thread's reply count in
  `v1` and its latest reply in `v2`), `thru` (a reply author, `u`), `fl` (a file: `v1` its id, `v2` its size
  and type, `x` its name), `att` (an unfurl: `v1` the target message, `x` its words), `edit` (`x` the new
  body), `post` (one of our own posts changed state).
- **`id` is when the event was seen, and it orders everything.** It is the `EventIdentifier` long form,
  `yyyyMMddTHHmmssSSSZ-` and six decimal sequence digits and three hex origin characters, 29 characters, so
  plain string order is time order. `--intern-comms-event-id` mints it: one thread a workspace, holding the
  last millisecond and the last sequence in memory, started on demand, answering through its request fifo and
  dying on idle. A thread and never a file, because a millisecond and a sequence cannot be kept by rewriting
  one, and because two passes inside one second must sort as time. The origin is the workspace's own number,
  read once for the thread's whole life.
- **A pointer is the last `id` seen, and it is exact.** `msg` keeps the message's own id, so an event about an
  old message takes a new id and reaches a reader that has already passed that message. The ingest's pointer is
  `.ingest.txt`, one line, and the ingest is its only writer: it never moves by itself, and a failed read leaves
  it where it was.
- **A removal is only observable by comparison.** Slack's read returns current state, so the ingest folds what
  the store already holds and emits `rx-` for a mark the store holds and the read no longer carries. A mark
  added and removed between two reads leaves nothing.
- **The threshold is 2,000 bytes, and it counts the text alone.** A longer text keeps a 400-byte head in `x`
  and its whole self in `<msg>.body.txt` beside the month's file, named by the `body` column. Annotations are
  their own events here, so they spend no part of that allowance.
- **The ingest is one operation, one source**: `--intern-comms-ingest --run <member> <channel id>`. It reads the
  history from its pointer's floor, reads each thread whose latest reply is newer than that floor, writes the
  events the store does not hold, and moves the pointer. Nothing about what is actionable lives here; that is
  the transfer's (§3 of the design).

## 7. The `--owner-setup-*` family

User grammar is in [docs/commands.md](docs/commands.md); per-domain manuals are `--help-setup-<domain>`.

- **A domain declares; `--intern-op-owner-setup` carries out.** Option handling lives in that one
  primitive, so a shared option is applied once. An option is accepted only by a domain that declares
  it; a flag accepted and then ignored is the failure this prevents. The engine's mode words
  (`--render-full`, `--render-missing`) are internal, with one exception: `reflection` takes
  `--render-missing` as its own sub-operation, because that read is its step 2 and a reader needs it
  before the domain will write anything. Every other domain still refuses it.
- **A setting is judged by its value at its use site.** Unset or empty is FAIL. A config file existing is
  never the check. An installation artefact (console script, access fragment) is judged by presence.
  The fragment, a fallback, only warns when missing or stale; it fails only where grants.index cannot
  give the roots either.
- **Settings and preconditions are separate lists.** A setting is a value the engine stores; a
  precondition is a state of the installation. `--apply` carries out both. For `claude`: settings are
  the workspace root and service selection; trust, console freshness and access grants are preconditions.
- **Workspace trust** is a boolean in `~/.claude.json`, not one of our options. `--apply` sets it first,
  because claude discards `permissions.allow` of an untrusted workspace. Writer
  `AgentsClaudeProjectTrustUpsert.awk`, reader `AgentsClaudeSettingsVerify.awk`; the replacement keeps
  the file's mode. An absent, symlinked or unparsable state file stops the run.
- **`--apply` sequence**: trust, then the engine call (subject and settings), then
  workspace integrations for a domain declaring `SPAWN_CLI_SERVICE`, only if
  the diagnosis fails first. The diagnosis comes last, and its status becomes
  the op's. Each step runs in its own subshell and is tested. So a step that aborts, as
  bash 3.2 suspends `set -e` in tested subshells, does not skip the handler
  that names it.
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
- **Help depths are separated in `Help.DistroAgentsTools.include`.** Every `echo` line there stays flush left, inside `case` arms too.
  `--member-help` cuts the file with a `^echo "` anchor, and an indented line
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

- **`--make-workspace-integrations`** runs seven steps, in order. Workspace registration is this step's, never a
  member install's.
  - `--intern-directory-register` (the places).
  - `--make-console-command`.
  - the first part of `--install-workspace-integrations`.
  - `--intern-member-home-register`.
  - `--make-harness-indices`, once, with no name, so every index is built (its grants are unrolled over the places just registered).
  - the second part of `--install-workspace-integrations`.
  - `--install-workspace-restrictions`, only when `.claude/hooks/deny-native-tool-reroute.sh` exists.
- **`--install-workspace-integrations` runs in two parts, around the indices build.** The first part is the MCP registration and the member links
  (`--install-vscode-integrations`, `--install-skillset-symlinks`). The
  second, after the build, is the trust, the Claude permissions, the settings
  and the Copilot access (`--install-claude-workspace-trust`,
  `--install-claude-permissions`, `--install-copilot-access-fragment`). The Copilot access step writes `harness.roots.index` again, by
  its name, when it made a root. With `--install-workspace-restrictions` it is one of the two root
  install methods in the default syntax.
- **MCP registration targets this workspace only.** Never another workspace's origin or config. A host starts its server once per session with workspace variables unset, and
  its own project directory as cwd. So a server resolves its environment at
  its own entry. An `env` object freezes values at install
  time and goes stale silently.
- **A command path holding a `myx.common` directory component is pruned as a duplicate** by the
  myx.common writers. Keep other servers' binaries outside such a component. The `myx.common` entry
  points at `.local/myx/myx.common/`, never `$MYXROOT`.
- **`sh-lib/mcp/AgentsMcpServerJsonUpsert.awk`** upserts one entry by key, reads the whole file itself
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
- **The Magic-Team panel** is one unpacked copy in
  `.local/agents/vscode-magic-team-panel/`, rewritten when its `.payload-sum`
  changes, by two renames. It is linked as
  `.vscode/extensions/magic-team-panel` into every folder and the workspace
  root, and as `$HOME/.vscode/extensions/magic-team-panel`. Real content
  in `$HOME` is warned about, never removed. `extension.js` is a loader only. It loads `panel.js`, which picks the
  installed layout when `magic-team.basic.md` sits beside it, else the
  development layout through `../../skillset/magic-team/magic-team/`. It is
  read again from disk whenever it has changed.
  A panel change needs the install and a click on `Reload` in the panel; nothing is restarted.
- **The panel's webview gets its CSP as a `<meta>` tag, and that is the only path it has.** A webview is
  handed a string, not an HTTP response, so the team's header rule has no premise here. `panel.js` carries
  one meta with `default-src 'none'` and no `script-src`, and sets `enableScripts: false` beside it
  (`panel.js:122` and `:42`). Both keep the surface script-free; a header rewrite would drop the only
  policy it holds. The meta form cannot carry `frame-ancestors`, `sandbox` or a report target, and the
  host supplies those.
- **The panel's identity block is read from the skillset on every draw.** `draw` rebuilds it from
  `magic-team.basic.md`'s `## Public Information` section, at the installed copy beside `panel.js` or at
  the development layout through `../../skillset/magic-team/magic-team/` (`panel.js:38` to `:58`). To
  change what the panel says about the team, edit that skillset section: the next redraw shows it, with
  no extension change and no reload.
- **VS Code skill discovery** (read from the installed build; re-read before relying on it):
  - one directory level, a literal `SKILL.md`; built-in locations are `.agents/skills`, `.github/skills`,
    `.claude/skills` per folder and the same three under `~`;
  - `chat.agentSkillsLocations` is additive; relative keys resolve against every folder; `~/` keys once;
    absolute paths and glob characters are rejected and dropped with a log line;
  - the setting is `restricted`: an untrusted workspace shows no members;
  - a member is skipped for a missing or mismatched `name`, missing `description`,
    or a parse error. A duplicate `name` in a higher-priority location
    (workspace, user, plugin, extension) is skipped too. None of this is
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
- **`--make-harness-indices [<name>...]`** (`AgentsTools.Make.include`) is the one operation that makes
  every index of the tooling. With no name it builds all eleven. With names, it builds only those, in their
  own order. A name that is none of them refuses the call before anything is
  built. The eleven are the stems `team-members`, `team-members-names`, `spawned-sessions`, `pending-replies`,
  `members`, `permissions`, `grants`, `tool-index`, `mcp.servers`, `harness.roots` and `harness.hooks`.
  `tool-index` comes after `grants`, which it reads to know who holds a tool (see "Harness tools"). `--make-agents-indices` is this same
  operation's earlier name and still works. The integrations run and the build call it once, with no
  name, so every index is built; no caller names a list. `--manager-team-member-list` and
  `--manager-team-member-read` read the `team-members`/`team-members-names` registries this builds, the
  same ones `ListAgents`-style readers use.
  The four registries below -- `team-members.registry`,
  `team-members-names.registry`, `spawned-sessions.registry` and
  `pending-replies.registry` -- are each rebuilt by its own rebuild function.
  Each is built from the one list in `AgentsToolsRegistryAgentsIndicesBuild`
  (`AgentsTools.Registries.include`). A new registry is one line there plus
  `Rows`/`Rebuild` functions. Where a workspace has no session
  store, the last two are written with no rows, with a plain note and no error. A registry or index
  writer that holds no lock makes its temp file with `mktemp`, sets its mode, and renames it into place.
  Rows exist only for members with a path in this workspace. Names come from the member's `basic.md` (`- **Name**:` as plain words, split
  at the first space; alias and mark via `AgentsToolsCommsSlackMemberMarks`).
  The scope keys `FIRST_NAME`, `FAMILY_NAME` and `ALIAS` override them.
  Invalid values store `-`; a stored space is `_`. Every `client-*` row takes the persona member's values
  (`registryPersonaMember`). Missing fields warn on stderr, never fail. One source-prepare builder makes
  every index now, `1201-agents-indices.sh` (parallel with `1201-increment.sh`). The builder
  `1202-harness-indices.sh` stays in place and builds nothing; it says in one line where the build is.
- **It also builds the grants**: `AgentsTools.Grants.include` -- `permissions.registry` and its tags from the
  declares of this workspace and of every registered tooling workspace without agents. A declare takes
  these forms:
  - `.` there is that workspace.
  - `namespace` applies in every tooling workspace.
  - `workspace:<pattern>`, such as `*-testbed`, is every workspace place whose name matches, tagged
    `wildcard`. Where none matches, there is no error and no row.
  - `directory:<name>` resolves through the places, then is capped to read on a read-only one.
  - An unknown name is an `unresolved` row, warned.

  The registry also holds each acting member's own directory. It holds magic-librarian's read of
  `source/**` and its write of the `.md` files of a team-member skill. Such a skill is a real folder in
  the HOME skills folder, or a link there into this workspace's own source tree. A skill linked in
  from another workspace is still asked as today.

  The `magic-team:permissions:workspace:` lines of its project.inf are read through the distro door: off the source project.inf as it stands,
  or from the installed distro where the workspace has no source, like the other `magic-team:` ones. They are the floor directives of the members this package carries. They
  name magic-architect's WebFetch and WebSearch, and magic-tester's read of
  `source/**/{sh-test,test,tests}/**` and `.local/myx/**` in every tooling workspace. They name its
  write of `**` in `*-testbed` ones too. The same lines are read off the `project.inf` of each package
  installed under the workspace's `.local/myx/`, so a rig with no `source/` holds them too. A workspace
  with neither holds them only through the registry of one that has them; `--make-agents-indices`
  says so.

  The lines of member `*` in this package's project.inf are the team floor, and no registry row. Its
  `allow-tool` ones are the floor's tools. `AgentsToolsPermissionOriginFloorTools` reads them from the
  declares of the workspace `MDLT_ORIGIN` belongs to, through that door and nowhere else: no list of them is kept in
  code. A floor that reads empty is refused, said, and no decision treats it as a floor naming no tool.
  A member `*` row of any other package is a standing row of every member. Then comes `grants.index`, every workspace's registry fully unrolled
  per member, with the places' ceilings, deepest first. It carries the floor:
  - a write of `.local/temp/**` in every workspace an index is built for, a rig's own included;
  - where agents are installed, a read of `source/**/{MAGIC.md,README.md}` and `source/**/docs/**.md`,
    and a write of `source/**/MAGIC.md`;
  - the readable member directories and reference roots.

  `grants.index` is never edited at runtime. A reader finding it stale (older than any registry it is
  made from) or missing rebuilds it the sibling way. The generator runs in a tested subshell into
  `<file>.$$.tmp`, then `mv -f`. The old file is kept on a failure, in memory where `.local/agents` is
  not writable. `source/**` is in no floor: other members read it by namespace grants.

### DeepSeek Harness

The integrations step installs this workspace's MCP server into the DeepSeek
Harness app and changes nothing else in the app. No preset is chosen and there
is no default preset. The app's own profile is not edited.

- **`AgentsToolsInstallDshHomePatch`** is a step of `--install-vscode-integrations`; that command runs
  in `--install-workspace-integrations`'s first part, which `--make-workspace-integrations` runs. It writes one `- insert:` row to the DeepSeek Harness home's
  `cordis.patch.yml`, the home-level patch DSH applies over every profile.
  Every chat of the app then gets this workspace's tools. The row sets id
  `myx-distro-mcp`, `name: '@deepseek-ai/dsh-mcp-client'`, `serverName:
  myx-distro`, transport `stdio`, command the workspace's
  `.local/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh`, args
  `--intern-mcp-server --run`, env `MMDAPP` only, `failOnStartupError: false`.
- **One managed block keeps the write idempotent.** Begin and end marker comments bound the row. An unchanged run leaves the file byte for byte and says it is current. Changed
  values replace the block whole. A markerless row the hand install left with
  our id is adopted, not duplicated. Other rows,
  comments and file content are kept. It runs no YAML reader: the row is plain block YAML, values single-quoted. A
  symlink, a non-regular file, a mapping or a non-empty flow list is refused
  with its reason and left unchanged. An empty flow list (`[]`) alone is
  replaced by the row.
- **A machine with no DeepSeek Harness home is reported and skipped, never
  failed**. The rest of the integrations run completes and no file is created.
- **Removing it is the row or the file.** Delete the row's managed block from `cordis.patch.yml` to
  stop the app mounting this workspace's server; delete the file to drop the whole home patch. This is
  the only thing the package writes into the harness home, and the next integrations run installs it
  again.

## 9. Hooks and workspace restrictions

User view: [docs/installation.md](docs/installation.md#workspace-restrictions-optional).

- **Restrictions are a manual opt-in.** `--install-workspace-restrictions` writes the hooks, the
  `settings.json` entries and `autoMemoryEnabled: false`. Nothing installs them behind the user's back.
  Once installed (the reroute hook is present), `--make-workspace-integrations` keeps them current.
  `--install-workspace-integrations` passes an empty hooks list.
- **A hook binds every agent on the machine.** Wiring one is the user's decision. An op that silently
  wires a hook is a defect.
- **Each hook is one real script in `sh-lib/client-hooks/`, installed by copying.** Nothing is templated
  into it. The harness runs the package's script, never the `.claude/hooks` copy, with
  the bash it runs in (`"$BASH" <script>`). A hook starts `#!/usr/bin/env
  bash` for the clients that run the copy by its path.
- **A deny hook uses shell builtins only.** A missing external binary yields empty stdout and exit 0,
  which reads as allow. Fail closed on anything unparsed.
- **Two kinds of deny hook.** A REROUTE drains stdin unread, denies every call alike, and names the MCP method
  to use instead; it applies to `*-native` clients only. A CONDITIONAL guard reads the payload, matches
  one thing, allows the rest, and applies everywhere, our harness included. Do not mix them. A reroute is
  a router, not a security wall.
- **The grant hook**: `allow-granted-native-tool.sh` (class `native`: the harness makes the same decision
  itself) answers only in a spawned member session. It reads its session permission index. Its answers:
  - a write in a read-only place: `deny` first;
  - a granted native file call: `allow` (an allow-once used up through the tooling first);
  - anything else: no answer, left to the client rules and the `PermissionRequest` hook.

  Another hook's deny wins over its allow.
- **The root-session hooks** `root-session-end.sh end` (`SessionEnd`) and `resume`
  (`SessionStart`, matcher `resume`), class `native`, act only for a session
  with no spawn record and no `MDAT_SPAWN_SESSION_ID`. The end arm writes
  `sessions/<id>/ended` and touches the store. Then, detached, it runs
  `--mark-ended` and the transcript END. A resume removes the marker. Nothing on stdout (a `SessionStart` hook's stdout joins the context).
- **`AgentsTools.ClientToolPolicy.include` is the single source** of the reroute set, hook paths, every
  hook record with its class, and entry keys. The refusal wording lives in the hook script. The script's
  last arm denies loudly, since no decision reads as allow.
- **The reroute set carries only tools whose native-call test passes** in
  `sh-test/harness/AgentsHarnessNativeCallCheck.test.sh`, because the twin becomes the only path. `AskUserQuestion`
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

- **The DeepSeek Harness app is covered by a bridge plugin, which this op installs.** The app has no per-tool hook seam of its own, so `sh-lib/harness/AgentsHarnessDshHooks.include` installs `@deepseek-ai/dsh-hooks-claude-code` into the desktop profile with pnpm.
  It then writes one managed row in the home patch naming this workspace's `.claude/settings.json` as the bridge's `configPath`. The app reaches every hook above through that row.
  Where the PATH holds no pnpm the step uses the copy the app ships in its own runtime, and fails where neither is there. The plugin version is pinned to the app's own.

## 10. The agents console

User view: [docs/use.md](docs/use.md#running-the-agents-console).

- **It starts an agent CLI, not a shell dispatcher.** A piped line is a prompt. A read-only tooling call
  through it costs a full model round trip. Run `DistroAgentsTools.fn.sh` directly for reads. Whether a
  write is equally safe by the direct path is not established (the console may supply identity or locking).
- **Known names** (`DAGC_KNOWN_CLIS`, also the `--cli-auto` ranking): `copilot copilot-native claude
  claude-native grok grok-native scaleway`. `AgentsTools.Owner.include` mirrors it.
- **A leg is a file.** Any `sh-lib/harness/Agents<Name>Harness.sh` declaring `HARNESS_PROVIDER_NAME=` is leg
  `<name>` (lower-cased): today `claude`, `copilot`, `grok`, `scaleway`. `AgentsUniversalHarness.sh` and
  `AgentsAnthropicStub.sh` are not legs. A new leg is one new file; it joins the auto-scan and the
  non-interactive set at the tail.
- **`DagcLegFileFor` resolves a name to its leg file** from a table built once at
  the top. Presence, exec, flags and credentials all use the same path. `DAGC_VENDOR_CLIS` (`copilot-native claude-native
  grok-native`) wins over leg resolution, so a leg can never shadow a vendor name.
- **`DAGC_CLI_EXEC`**: a leg execs its file; `claude-native`, `copilot-native` and `grok-native` exec
  the vendor binaries `claude`, `copilot`, `grok`; any other name execs itself. `$DAGC_CLI` stays the
  logical name everywhere else (`DISTRO_CONSOLE_EXEC=`, flags, warnings).
- **`DAGC_NONINTERACTIVE_CLIS`** is `copilot copilot-native claude claude-native grok scaleway`, plus any
  discovered leg. `grok-native` is not in it (a real interactive binary not proven non-interactive). A
  leg has no interactive shape; `--cli <leg>` without `--non-interactive` is refused with a stated reason.
- **A start on a terminal that names no CLI starts the manager screen**, whatever
  service is configured, a native one included. `--cli-auto` and
  `--cli-configured` name none. A vendor's own
  console starts only where it is named: `--cli claude-native`. With no terminal, and with
  `--non-interactive`, a start is what it always was. A console generated before this keeps its old
  default until it is made again (`--make-console-command`).
- **`--manager` starts the console's manager screen in place of a CLI**, whatever service is configured.
  It takes nothing after it, and is refused together with `--non-interactive`.
- **`DistroAgentsTools.fn.sh --manager [--style <name>]`** is what the console's `--manager` runs, and
  has help. It is no `--manager-*` operation: its own arm of the caller check admits every caller. It
  runs `sh-lib/manager/LocalManagerScreen.py` of `myx.distro-.local` with Python. The style is, in this order: `--style`, the environment's `MDLT_MANAGER_STYLE`, the
  user's saved `MDLT_MANAGER_STYLE` (`<workspace>/.local/home/<user>/MDLT.settings.env`), the screen's
  default. It ends with status 1 and one plain line where Python, its `curses` module, or
  a terminal is missing. It ends with status 0 on Ctrl-X (or Alt-X). `AgentsManagerStartStyleCheck` is its test.
  The interface settings are `.local`'s own. Their declaration, the style with
  the mouse and the spacers, stands in its
  `sh-lib/manager/LocalTools.ManagerInterface.include`, which the digest below
  expands into its `interface` subject.
- **A console screen's roots are a plugin's `mount`.** `.local`'s features plugin, `LocalManagerScreen.Features.py`,
  carries no `mount`, so `Optional Features` is a root of the screen's `setup` group, beside `Configuration` and
  `This Machine`. It stood under `Configuration -> Installed Subsystems` until 2026-10-31, three levels down, where
  nobody found a way to install or uninstall a feature. A feature moves in the list by changing that one word, and
  the paths its declarations write follow it. A test that walks a level moves with it: a row leaving a level shifts
  both a pane line number and a key step, and a blanket shift of the key steps breaks the step taken after landing
  on a row. `AgentsManagerScreenFeaturesCheck` and `AgentsManagerScreenSubsystemsCheck` are the two that moved.
- **An unmounted plugin takes its whole level with it, and a dropped place leaves no note.** `pluginsOrdered`
  (`AgentsManagerScreen.Plugins.py:191`) takes a plugin only where its `mount` is absent or names a plugin
  already built, and returns the rest as `PLUGIN_UNMOUNTED` (`:205`). Only the ordered plugins are walked into
  the build (`:217`), so an unmounted one contributes no root, row, command or registry at all: its level is
  absent rather than empty, and no row survives to press on. A place in a command's `on` that names a level of
  an unregistered plugin expands to `None` (`pluginPlaceOf`, `:170`) and is filtered out at `:298` with no
  entry in `PLUGIN_NOTES`. Those notes fire on two cases only, a read naming an unregistered plugin (`:265`)
  and an `integrates` registry no plugin offers (`:283`), so the place drop is silent by construction.
  Compare a command's place count across two apps before reading a difference as a mount fault: a plugin's
  own `apps` declaration moves that count too.
- **`--manager-session-list [--active]`** is the `--manager-*` family's first operation: it lists the
  coworking sessions with their runs, ending with one row of counters. It is the only one of the three
  session operations that rebuilds the `spawned-sessions` and `pending-replies` registries at every
  call. Each `session` row ends `<session-state> <session-state-at> <control-thread>
  <tokens>`. It holds the stored state beside the one derived at this call.
  The thread is `alive`, `gone` or `none`, measured at the call and stored
  nowhere. It ends with the tokens of the session (`sessions/<spawn
  id>/tokens`, summed by `AgentsManagerSessionTokens.awk`). The last field of a `session` row is its phase, `active`, `ended` or
  `closed`: the one rule of an active session, which `--active` and the console's lists both take as it is
  (`AgentsManagerSessionRows.awk`). An `unknown-foreign` session, another host's, is `closed` at both doors, a live one too:
  nothing can be done with it from this host. The last field of the `counters` row is the full name of the host, asked once
  and kept in `$HOME/.agents/magic-team/host-full-name`. Every other host
  field of the tooling stays the short name.
- **`--manager-session-read --session-id <id> [--run]`** shows one session, or with `--run` one run of
  it: its rows, its dispatch, each run's record headers and store. After `dispatch` it prints
  `control <session-id> <session-state> <session-state-at> <control-thread> <control-pid>`, then the
  session's `tokens` row; the stored state is read from the session's own folder at every call.
- **`--manager-session-transcript-read --session-id <id> [--run] [--tail <lines>]
  [--log]`** gives the messages and tool use of a session's members as feed
  rows, newest last. The tracking post's own renderer makes them, in a rows
  form that writes no post.
- **The two session reads take a registry as it lies only while it still matches
  the store**. They compare its names and counts against the store's own,
  never a time. What a record itself says is read
  from the record fresh at every call. The sessions include now has four awk files, the newest
  `AgentsManagerSessionScope.awk`. `AgentsManagerSessionReadCheck` and
  `AgentsManagerSessionTranscriptReadCheck` are the two reads' own tests.
- **`--manager-routine-list`** lists every routine file the members carry, one row
  each. It says whether it is startable, with the reason in words where it is
  not. A routine is startable where its file names its executors as a plain
  list of existing members. No registry or index holds the
  routines: it reads the files at each call. The spawner's own rule for a start with no member named is the same one
  function now, `AgentsToolsSpawnRoutineExecutorsRoster`. The spawner and this
  list both ask it. A row's tenth and last field, `<needs>`, reads `members` where the routine is
  `not-startable` for one cause alone. That cause is executors that are any
  member (`magic-team` or `*`). It reads `-` on every other row, such a
  routine started by `--spawn-session --routine <selector> <team-member>...`. Its code
  is `sh-lib/manager/AgentsTools.ManagerRoutine.include`; `AgentsManagerRoutineListCheck` is
  its test.
- **`--manager-spawn-agent [--cli-service <cli>]`** starts a bare agent: a prompt,
  on stdin, a file or `--goal`, to a CLI service with the tools of the
  workspace. It has no team member, no session and no record (sketch 5.1,
  "logged the fact only"). The record is one start line and one end line in
  `.local/agents/bare-spawn.log`. It starts the console (`DistroAgentsConsole.sh --non-interactive`), the layer
  below the spawn proxy, by the one function that starts the console for every
  spawn, `AgentsToolsSpawnConsoleLaunch`
  (`sh-lib/spawn/AgentsTools.SpawnConsoleLaunch.include`). The proxy, its
  retry and both resumes use that function too. It passes
  `MDAT_SPAWN_BARE=true` and an empty `MDAT_SPAWN_AGENT`. The console's
  template skips the coordinator default and the roots of a member for it. Its code is `sh-lib/manager/AgentsTools.ManagerSpawnAgent.include`;
  `AgentsManagerSpawnAgentCheck` is its test. The Launchpad's Free Prompt calls it where no member is chosen.
- **`--manager-spawn-member <team-member>`** starts one member with a prompt, in a new coworking session
  of its own, and does not wait. The prompt comes on stdin or from a file, never as an argument. It
  brings no member itself: the spawn proxy brings it, and asks of it the same check every start asks.
  Its code is `sh-lib/manager/AgentsTools.ManagerSpawn.include`; `AgentsManagerSpawnMemberCheck` is its test.
  The kinds of start the console's Launchpad offers are options of this one operation, not operations of their
  own. They are:
  - `--kind coworking` (the default; `--also a,b` joins more members to the session);
  - `standalone` (the standalone routine);
  - `work-duty` (the member's duty routine, refused while that member's duty runs, by the scheduler's own
    `AgentsToolsScheduleWorkDutyRecord`);
  - `free` (a prompt and no routine).

  `--goal <text>` gives the prompt as an option. Every member is asked before the first is started. A start
  with no member at all is not offered: the spawn proxy starts no agent without one.
- **`--manager-feature-*`** are the optional features of `mdci-packages-myx`
  (`setup.feature-*`), as the console's `Optional Features` (in `Installed
  Subsystems`) and `Local AI` (in `This Machine`) work them.
  `myx.distro-.local`'s `LocalManagerScreen.Features.py` draws them
  (`sh-lib/manager/AgentsTools.ManagerFeature.include`;
  `AgentsManagerFeatureCheck` is its test, `AgentsLocalAiCheckParse` the test
  of the `key: value` forms of local AI). `-list` reads each feature's own check fragment (`MDCI_CHECK_PARSE=1` asks
  local AI for its `key: value` report). It prints a row for each feature and
  each part, with state, bytes on disk and in memory, and running. Its row
  names the install, update and uninstall commands that apply. `-part` prints a part's plan first (needs, space, memory). It does the work
  only with `--yes`, by the feature's own fragment, never by work of its own.
  `-ask`, `-stt-test` and `-preset` use what local AI installed (the preset is
  made by `--manager-preset-new` and the setting reader). The preset names no endpoint: the `local` CLI service
  defaults to `http://127.0.0.1:8181/v1`, where local AI serves its chat models (`AgentsLocalHarness.sh`).
  `PRESET_ENDPOINT_URL` is an https URL, and http only for `127.0.0.1`, `[::1]` and `localhost`
  (`AgentsTools.Preset.include`).
- **`AgentLibrarianTools.fn.sh --skillset-size [<team-member>...]` is the
  instrument for the size of the skillset**
  (`AgentsTools.LibrarianSkillsetSize.include`). It prints a `file` row for
  each file of each registered member (lines, bytes; lines `-` for a file with
  a NUL). It prints a `member` row for each member and one `total`. Dot names are no part of it. It
  reads only. `AgentsLibrarianSkillsetSizeCheck` holds it.
- **`--manager-feature-models [--profile P] [--all] [--yes]` installs the agreed
  set of open models by one command** (the console's Configuration). It
  installs the speech model, the profile's default chat model (`--all`: every
  chat model of `models.tsv`) and the LanceDB embedding model. The profile is the option, else the host's own
  (`host.profile` of the local AI check). It plans first (`set`, `model`, `total` rows). It does the work only with
  `--yes`, by `--manager-feature-part install` (`update` for a broken part),
  one part at a time. A failed part does not stop the rest (`result`, `end`
  rows). `AgentsManagerFeatureCheck` holds it.
- **A member's send into the event-track channel keeps the channel's outbox
  rules** (`AgentsTools.InternOpCommsSlackSend.include`, before its POST). What is
  queued for the channel is drained first, then the 7 s window since its last
  message is waited out. The moment of the post is noted. The post is the member's own, not a tracking post, and is not
  collected with others. `AgentsEventTrackMemberSendCheck` holds it. The spawn proxy's root post stays direct.
- **`--token-stats` and `--manager-stats-tokens` take `--average` and `--share`**.
  They give the average of a run. They also give the share of the `in` tokens
  of a key, in the total and in the largest key. The tooling computes both
  (`AgentsToolsStatsTokens`, `AgentsTools.DispatcherStats.include`); the
  console draws and computes none.
- **No start starts an identity record.** A member whose `SKILL.md` says `status: reference-only` is
  never started, by any start: the spawn proxy refuses it before anything is made
  (`AgentsToolsTeamMemberStartCheck`). `--spawn-session` asks this check of every member before
  its first spawn. `--manager-routine-list` says `not-startable` for a routine whose `executors` names
  such a member. `AgentsSpawnReferenceOnlyCheck` is the rule's own test.
- **`--manager-config-digest [--full] [<subject>...]`** prints the settings as they are, by subject; every
  row ends with its `<label>`, from the one declaration `sh-lib/manager/AgentsManagerConfigLabels.awk`. Without
  `--full` the rows keep their earlier fields, on purpose: a screen of before reads the label as the last
  field. A credential reads `secret-set` or `secret-missing` and is printed in one form only (**A credential
  is printed in one form**, below). Its code is `sh-lib/manager/AgentsTools.ManagerConfig.include`;
  `AgentsManagerConfigDigestCheck` is its test.
- **`--manager-config-set <key> <value>`** saves one setting that can be changed, in its own scope, and
  prints `saved <key> <value> <scope> <where>`: the one operation of `AgentsTools.ManagerConfig.include`
  that writes. A user-scope setting goes through the local tools' `--custom-config-option`.
  `AgentsManagerConfigSetCheck` is its test.
- **A credential is printed in one form, and
  `sh-lib/config/AgentsTools.CredentialDisplay.include` is the only place that
  defines it**. The form is the first quarter of the value, rounded down, not
  less than 4 and not more than 20 characters. A `*` then stands for every
  character after them, even for a long key. A value of fewer than 4
  characters is all `*`. A password inside a URL (`scheme://user:password@host`) is masked
  alone, the rest of the URL as it stands. Whatever prints a credential, in a row, a message or a file, asks that file
  for the form and makes none of its own. Which key is a credential is each
  console plugin's to enumerate (`AgentsToolsManagerConfigKeySecret`). The URL mask is in full only: `--manager-config-digest --full` and
  `--manager-team-member-read --full`, which the screen's reads pass. A read
  without `--full` shows a URL whole under a key that is no credential. The mask is no security
  boundary: a shell read of the value (`--agents-config-option <scope> --select <key>`) shows it.
  `AgentsCredentialExposureCheck` is the guard.
- **`--manager-session-kill --session-id <id> [--run]`** ends runs the hard way: no closure of a
  routine runs, and no agent is asked anything. A session's id ends every live run of it; `--run` ends
  the founder alone. The ending is recorded first, under the name the console's user has in the
  operating system: the record carries `killed-by` and `killed-at`, reason
  `manager-kill`. Then a polite end goes to the run's own processes, and the
  hard kill to what is still there two seconds later. Who carries it out: the session's control thread, where one lives, by
  `control/request` and a `USR1` wake, its own `control/outcome` read back.
  Else the call itself, directly, each ending printed on stderr. A request the thread has not taken within `SESSION_CONTROL_REQUEST_SECONDS`
  (5) is taken back by one rename and carried out by the call. The thread's
  own call ends its work at `SESSION_CONTROL_KILL_SECONDS` (30). The thread sends no signal itself. The handback retry never
  resumes a record that carries `killed-at`. Its own bound ends with its
  own sleep, and the lines of a missing handback are said only after the record is closed
  (`AgentsToolsSpawnProxyHandbackNotice`). A killed run is told as killed, by `killed-by` and at `killed-at`, in the
  thread of the session that requested it. That notice takes the place of the
  line of a missing handback, and comes also where it had handed back
  (`AgentsToolsSpawnProxyEndNotice`, block `run-killed`).
  `AgentsManagerSessionKillCheck` is its test.
- **`--manager-session-control-start (--session-id <id>|--all)`** starts the control thread of a
  session where it does not live; `--all` is the check now, run for every session that needs one. Rows
  are `control <session-id> <outcome> <pid> <reason>`, outcome one of `started`, `alive`, `not-needed`
  or `not-started`. Where it answers `not-needed` it removes the pid file and the lock a dead
  thread left in `control/`. Neither names a thread that lives
  (`AgentsToolsSessionControlLeftovers`), so the session reads `none`. Code is in the arm of `AgentsTools.ManagerSession.include` and in
  `sh-lib/session/AgentsTools.SessionControlStart.include`; `AgentsSessionControlStartCheck` is its test.
- **A kill and `TaskStop` find a run's processes by one walk**,
  `AgentsToolsRunProcesses`: the run's own processes and every process
  they started, to any depth. It never finds a process group, the run's own
  supervising shell, or a run of another spawn. A process that left the run's tree before the kill
  is not found. What a stop signalled and found still there is kept in the run's store, the
  file `stop.left`. The next `TaskStop` or `--manager-session-kill` of that
  run ends what the file names. An entry counts only while its pid is still
  the process that began then. The file is removed when nothing of it is left. `TaskStop` with force now ends a started process that ignores the polite end.
  Neither a stop nor a kill ever reaches a session's control thread. It is no
  child of a run, and walking from a run's own processes never finds it. `AgentsSessionControlStopKillCheck` is the test. A
  `--manager-session-kill` asking the thread to carry out a kill is the thread acting, by request, never
  a signal sent to it.
- **`--manager-team-member-list` and `--manager-team-member-read [--full]
  <team-member>`**: the list has one row per member. A row gives its mark,
  names, alias, kind, workspace, where it is set up, its status, and whether a
  run of it is alive. A member set up only in another workspace of this
  machine is included. Then come its icon, the one the installer's own member
  table shows (`AgentsToolsTeamMemberKindIcon`). Last come its folder, and its
  link followed to where its skillset lies. The read adds its description, its
  sessions, its grants and its settings, a credential setting in the form of a
  credential. Their code is `sh-lib/manager/AgentsTools.ManagerTeamMember.include`;
  `AgentsManagerTeamMemberCheck` is their test.
- **The other `--manager-*` reads**, each in its own include,
  rows as its help entry gives them, and each the screen's alone.
  Each operation follows as one item, with its test:
  - `--manager-dashboard-read` (`AgentsManagerDashboardCheck`)
  - `--manager-team-data-read <store> [<folder> [<item>]]`
    (`AgentsManagerBrowseCheck`)
  - `--manager-team-member-files <team-member> [<file>]`
  - `--manager-pending-reply-read`, `-answer` and `-dismiss`
    (`AgentsManagerPendingReplyCheck`)
  - `--manager-place-list` and `--manager-place-read <place>`
    (`AgentsManagerPlaceCheck`)
  - `--manager-place-command-list` and `--manager-place-command-run`
    (`AgentsManagerPlaceCommandCheck`)
  - `--manager-console-list` (`AgentsManagerConsoleListCheck`)
  - `--manager-check-run` (`AgentsManagerCheckRunCheck`)
  - `--manager-keys-list` and `--manager-keys-read <key>` (`AgentsManagerKeysCheck`).
    The deploy key of the account is looked for under the current user's HOME.
    The names there are `deploy-keys/<account>`, `.ssh/id_ed25519` and
    `.mdci-source-repos.txt`. The code uses no `MDCI_HOME` and no fixed
    `/usr/local/mdci`. On mdci, HOME is `/usr/local/mdci`.
  - `--manager-command-list` (`<Name>.fn.sh`, a TAB, the file it resolves to;
    `AgentsManagerCommandListCheck`)
  - `--manager-help-read [<Name>.fn.sh]`: the help of that command,
    read, never run.
    - With no argument it feeds Member Help's chapters alone,
      the read `list:help`.
    - No root lists its operations. Test `AgentsManagerHelpReadCheck`.
  - `--manager-manual-read <user|maintainer> [<project>]`
    (`AgentsManagerManualReadCheck`). `user` lists the projects with a README.md,
    `maintainer` those with a MAGIC.md, in the order
    `ListDistroProjects --select-all` gives. A row is `<project> TAB <file>`.
    With a project, it lists that file.
- **The manager screen is the entry `sh-lib/manager/LocalManagerScreen.py` of `myx.distro-.local` plus its parts**, the files
  `AgentsManagerScreen.<Part>.py` here beside this package's own list. The entry holds the start, the list of parts each package
  declares in its `sh-lib/config/screen-parts.list`, and `loadParts()`. The entry runs each part in its own namespace, so

  the screen stays one module whatever its files are. A declaration names a
  function by its name (`globals()[name]`), and a test replaces a function of

  the screen by assigning it to the module. A part is plain text of the screen and is
  never run by itself. The declarations come first (`Looks`, `Roots`, `Styles`, `Windows`, `State`).
  Then come the engine and the kinds of view, then the root sections of the
  list, then what every one of them uses. Declared as data are its styles (`STYLES`), windows (`WINDOWS`), menus
  (`MENUS`), commands with their keys (`COMMANDS`), reads (`READS`), calls
  (`CALLS`), summaries (`SUMMARIES`) and dialogs (`DIALOGS`). A new root, key
  or dialog is a declaration. Its roots are Dashboard (Monitor), Pending Questions, Magic-Team (Agents),
  Locations (Places), Consoles, Workspace (System) (with This Machine),
  Settings, Configuration and Manuals (Help). The number keys follow the list
  as it stands. The screen starts on Manuals (Help) (`START_ROOT`). It holds User Manuals (the
  README.md of each project), Tooling Commands and Maintainer Manuals (the
  MAGIC.md of each), the projects in the build order. Tooling Commands moved
  from Configuration. In the two manual lists the key `a` shows them by name
  and back in the build order (`ALPHABETICAL`). The active filter has no `a`
  there, `COMMANDS` "except". Every fact is a row of a
  `--manager-*` read or another operation, every action one.
- **Spacers** part the groups of rows of a list: one blank line each. The cursor,
  the number keys and every count of rows pass by it. At the root they part Dashboard and Pending Questions, Magic-Team,
  Locations, Consoles and Workspace, Settings and Configuration, and Manuals (`SECTION_GROUPS`). Inside a folder one stands
  between its commands and its listed rows, so a folder with only one of the two has none. None
  stands above the first row shown. `MDLT_MANAGER_SPACERS=disable` turns them all off, and they are on
  by default. It is a console setting of `.local`, the user's own, beside
  `MDLT_CONSOLE_HISTORY`, and no agents setting. `--manager` hands the saved
  one to the screen where the environment names none.
- **The mouse** is reported to the screen unless `MDLT_MANAGER_MOUSE=disable` leaves it to the terminal,
  whose own selection then copies text. It is read as the spacers are: a console setting of `.local`, the user's own,
  beside `MDLT_MANAGER_SPACERS` and no agents setting. `--manager` hands it to
  the screen where the environment names none (`MOUSE_VARIABLE`,
  `AgentsManagerScreen.Terminal.py`).
- **Its reads**: a folder is read while its row is selected, after a rest of a
  third of a second. A read may be `once`, on `demand` alone (its command asks
  for it), read `also` beside another list, and take `{parent}`. That last is
  the id of the level above. The dashboard is read only while its root is selected or
  opened.
- **Its actions**, each an operation:
  - `k` kills (`--manager-session-kill`, its plan read first with `--plan`, the word `yes` typed);
  - `s` stops the soft way (`--manager-session-stop`, no confirmation): the runs are dismissed by the tooling's
    own mark and a DISMISSED block in the session's chat, and each ends itself at its next Wait; `p` and `r`
    pause and resume (`--manager-session-pause`, `--manager-session-resume`, no confirmation); `R` restarts
    (`--manager-session-restart`, no confirmation): a start again of what has stopped or finished, through the
    return of a review, in the same session, sandbox and board item; a run that still lives is left alone;
  - `c` starts a control thread (`--manager-session-control-start`, no confirmation);
  - `Launchpad` starts work by hand: its five start forms (coworking, standalone, work-duty, routine,
    free prompt), in that order. All but the routine form call `--manager-spawn-member --kind <kind>`. The
    routine form chooses a routine and goes on to its start, and Enter on a routine row starts it the same
    way (`--spawn-session --routine <selector>`);
  - `n` starts a member (`--manager-spawn-member`, the prompt on standard input).

  An action the screen began is not ended with the screen. Pending Questions is read by
  `--read-pending-reply magic-coordinator --any-owner`.
  No pane shows a `keys:` line: the status line shows the keys.
- **Paging.** In the content pane Space, PgDn, PgUp, Home and End page and jump.
  In the list, PgUp and PgDn page. Left pages up as PgUp does and, on the
  list's first row, climbs one level, and at the root does nothing. So it
  never leaves the pane. Right pages down (`COMMANDS` `page-left`, `climb`,
  `page-right`). A table that is all of the left window is read with no row highlighted. Enter
  puts a row cursor on a row, Up and Down move it, Enter on a row opens it
  whole in the information dialog. Esc leaves the cursor, back to reading
  (`rowCursorEnter`, `AgentsManagerScreen.ViewTable.py`).
- **A run in a `Wait` says for how long.** In the summary mode of the left window (`b`), its `waits on` line reads
  `<what> for <age>`, counted from its last milestone, `wait going idle`.
  Every Wait stores that milestone as it starts.
- **One table drawer** draws every table of the left pane (`paneTable`, in
  `AgentsManagerScreen.ViewTable.py`; the Permissions of a member and the
  Locations use it too). Wrapped, a table spans the pane and wraps its cells.
  Cut, it is as wide as its words. Its columns stand two cells apart where the room left holds that for every
  gap, else one. Wrapped, the widths are tried against every cell. Room moves from one wrapping
  column to another while the table takes fewer lines for it. So a row takes
  the fewest lines the width gives. In the full
  view, where the table fits both ways with it, one empty line stands between every two rows. Every row shows,
  nothing above it, and the count of rows stands once at the bottom right of the window's frame.
- **Panels have no cut mode**. A view drawn by `blocksView` (the dashboard, a
  block of it or of Team Data) is always set out wrapped, at the pane's own
  width. There `w` is greyed and refused, and the title says `[wrap]`.
- **The table colour rule.** Each colour set of a style names a ground for every other row of a table,
  close to a row's own (`ROW_ALT`), or names none. Every other row differs only in that ground, never in
  its text, colour or look: the text carries content meaning alone. Under a set that names none the
  ground never changes. Wrapped, the last line of each row is then underlined across the table where
  the terminal underlines. In a rule-drawing style (`STYLES` "rowRule", the
  Magic styles, on a UTF-8 terminal) a light line of its own stands under the
  header instead. It stands under each row that wraps too, as wide as the
  table. Cut, nothing marks the rows. A cell that is a state keeps its colour on its row's ground and, on a row's
  underlined last line, the underline. A ground that is the meaning of a look
  (the red of a bad state) stays. A terminal of eight colours has not the shades the two grounds are told apart by: there
  the colours of every style name none.
- **Settings show values, not descriptions.** What a setting is saved as, the raw
  value, is what its table shows in the VALUE column, a path in its place
  form. The description of a choice belongs to the detail of the setting,
  after the value. The form that changes a setting offers the choices by their
  descriptions and saves the raw value (`AgentsManagerScreen.Settings.py`).
- **Markdown and the help are drawn by `lib/catMarkdown --spans`** of myx.common,
  once for each text, width and mode, never on a tick. The help is drawn as
  `--help` prints it. Where no catMarkdown with `--spans` is
  found, the text shows as it is. The screen holds no renderer of its own.
- **Magic keeps an empty line under the top of each window** (`STYLES`
  "bodyLower", where it draws its edges of blocks). It is the line its scroll
  bar already starts under ("barLower").
- **Every dialog keeps margins inside its frame**, a modal one, a popup and the
  big window of an operation's output alike. It does where the terminal has
  room. It keeps three blank cells at each side, and two empty lines under its
  top. One line goes under the shadow of its buttons (`DIALOG_SIDE`,
  `DIALOG_LEAD`, `DIALOG_TAIL`).
- **Consoles is the one thing the screen starts itself**: a row from
  `--manager-console-list` starts with the whole terminal, no shell, the words
  as printed. The screen leaves its mode and takes it back however the child
  ended.
- **Team Data** holds Operations (its cleanups and the sync, each run in a big output dialog) and the
  stores Board, Audit and Vault. **A member is a folder**: Permissions, Skillset Files, Sessions and
  Member Help. **Pending Questions** answers (Enter, `y`), rejects (`j`) and dismisses (`d`) an ask.
- **The answer dialog of a pending question takes its form from the question** (the answers of
  `--manager-pending-reply-read`, `AgentsToolsManagerPendingAnswers`). A single choice lists its answers, each
  with what it does, and a comment box goes with the one picked. A plain question, one with no answer form, has
  no list: it takes the words that are its answer, refused while they are empty. A question of the form `many` opens `answer-many`, its options as boxes. The
  answer is the numbers of the boxes checked, in their order, as one reply
  names them.
- **The form of a credential** (`AgentsManagerScreen.Settings.py`): Enter on a
  line whose state is that of a secret runs the command `credential`, ahead of
  `setting`. That opens the dialog `setting-credential`, a short text holding
  the value in the form of a credential. Its button Reveal, which Ctrl-R presses, reads the value whole by
  `--agents-config-option <scope> --select <key>` (the pseudo-read
  `full:credential`, on `demand`; the scope from `CREDENTIAL_SCOPE`). It puts
  the value in the field for as long as the form is open.
  A line not changed from here has Close and Reveal, a changeable one OK, Reveal and Cancel; the value
  whole is held nowhere else. Ctrl-R is the dialog's one key beside those of its controls. It comes as
  `DIALOG_KEYS`: the dialog's name, the word the status line gives the key,
  and what it does.
- **`MDAT_<NAME>_HARNESS` points one leg at another file**: a bare filename in
  `sh-lib`, or an absolute path. A relative path with `/` is refused, since it
  would resolve against `$MMDAPP`. It must exist and be
  executable. Install probes and `AgentsToolsSpawnCliPresent` test the default file, not the override.
- **The console passes no flag to the CLI.** After `--non-interactive` the rest of argv is the prompt.
  Anything the CLI must be told travels as an exported variable.
- **A generated console is a snapshot** of `AgentsConsoleShellScript.template.sh`, rewritten only by
  `--make-console-command`. It resolves awk paths at run time but bakes in its own invocation. So changing
  a `-f` list does not reach a console until it is regenerated. Staleness is normal; design
  changes to work with old consoles.
- **claude-native streaming.** `DagcRunClaudeStreaming` runs claude with
  `--verbose --output-format stream-json`, backgrounded, and pipes it through
  `awk -f AgentsProgressLineSafe.awk [-f AgentsClaudeStreamJsonTranscript.awk] -f AgentsClaudeStreamJsonFormat.awk`
  under `LC_ALL=C`. Progress goes to stderr; the final `result` text to stdout; exit from `is_error`.
  Other CLIs are `exec`'d directly.
- **Ctrl-C stops a run only if the trap chain is unbroken**. The console traps
  TERM/INT onto claude's pid right after capturing it. The spawn proxy's
  `--wait` traps onto the console, and the main loop traps onto its pass. That
  loop sends `kill -TERM -- "-$pid"` to the process group (the real proxy is
  one pipe deeper).
  Each layer re-waits after `wait` returns early. The console's own trap names claude's pid only until
  claude has been waited for; the variable is emptied then, and a later TERM signals nobody.
- **Claude sign-in (claude-native).** The console asks `claude auth status`, and the answer never refuses a launch.
  A login that expired, or one the probe cannot read, is the CLI's own to
  report, and its error is what a caller sees. Signed in: nothing is exported, even with a key configured, because Claude Code
  prefers a key and would move spawns onto API billing. Signed out, `--non-interactive` only: it exports the
  first configured `ANTHROPIC_API_KEY` or `CLAUDE_CODE_OAUTH_TOKEN` from magic-team scope and says which.
  An interactive console is warned, and no path exits 6 for a sign-in reading. Unknown output never gates.
  Spaces are stripped before matching.
- **Console channels have no per-caller isolation.** The channel id is a fixed prefix, the workspace
  slug and the console name. Two callers on one workspace and console share one channel and can tear
  down each other's session (`channel_not_found`, a console dying mid-use).

## 11. Spawning and sessions

- **The spawn proxy does not run a CLI.** It pipes its context into
  `DistroAgentsConsole.sh --cli-configured --non-interactive`. Both its waiting and background branches
  inherit the exports.
- **Every start that does not wait is detached, whatever its caller**. A caller
  with no session id is included. Such a start gets its own process group,
  hangup ignored, its output in its session log. Only a `--wait` start
  with no parent session stays in the group of its caller. Its shell also holds a polite end, an interrupt and a quit until its close is
  done (`AgentsToolsSpawnProxyHeld`). That hold covers a signal sent to it and
  one sent to the group it leads. Each one is said in the run's log. The hold
  comes off once the record, the item and the posts are done.
- **A detached spawn closes every descriptor it inherited**: `4>&-` on each
  backgrounded launch, its output tail and its event-track feed loop. One
  descriptor stays open in the caller, to learn when a whole process tree has
  exited. A child meant to outlive that caller never leaves it open. So a
  review reading for that close gets its verdict back at once. It no longer
  waits on a descriptor nothing will ever close. Its standard input is `/dev/null`.
- **Spawn environment**: `MDAT_SPAWN_AGENT` (acting member),
  `MDAT_SPAWN_LAUNCH_MARKER`, `MDAT_SPAWN_SESSION_ID`,
  `MDAT_SPAWN_SANDBOX_ROOT(_REAL)`. Once a coworking session exists, it also
  holds `MDAT_SESSION_ID`/`MDAT_SESSION_THREAD`. Nested spawns inherit all of
  them, so a child joins its parent's session.
- **`MDAT_SPAWN_SESSION_ID` is a uuid minted by the proxy**, which writes it to
  the dispatch item's `session-id`. It is the only join between the dispatch
  record and hook reports. Lowercase it.
  No uuid, no spawn. The caller's previous value, else `CLAUDE_CODE_SESSION_ID`, becomes
  `parent-spawn-id`. `receiptId` is a different id (the audit log, `RECEIPT_ID=`), named
  `spawn-proxy-<UTC stamp>-<pid>-<first eight of the spawn id>`; its dispatch item is
  `dispatch-<UTC stamp>-spawn-proxy-<pid>-<first eight>.md`. Older names end at the pid.
- **`--description`** (agent-spawn-proxy, `--spawn-session`, `--spawn-prompt`): the
  spawner's own words for what the spawn is for, redacted and bounded (`AgentsToolsTaskTextKept`). On agent-spawn-proxy, it is kept as `description:` on both the dispatch item
  it creates and its own spawn record, only when given.
  `--session-name-or-comment` is kept the same way, as `session-comment:` on
  both. Shown on the first line of the start post (`AgentsToolsTaskTextLine`).
- **`MDAT_SPAWN_AGENT`.** For claude-native the console builds an inline `--agents` document and selects
  it with `--agent`, so hooks report the member as `agent_type`. The name is checked against a bare-token
  set before it enters JSON. No standing agent file: a member must not exist twice. Legs take both
  variables. A CLI that cannot honour one reports it as dropped. `--help` exits 0 before `--agents` is
  validated, so it proves nothing.
- **A harness session that never armed is recorded as failed**, whatever its exit code
  (`AgentsToolsSpawnProxyOutcome`): a `<session>.harness` marker and no `<session>.armed`. Native
  sessions keep the exit-code rule.
- **Arm before acting.** In a spawned harness loop, the tools below are redirected until the session
  has read its own `mcp__*__execute` to the end through Skill. They are Write,
  Edit, Bash, SendMessage, AskQuestion, ConfirmReadback, EscalateDecision,
  RequestPermission, ProposeApprove, Agent and any `<member>.armed.md`. That
  read is by `name` and `file`, or by a whole `skill=` read of its own skill
  with the armed file merged in. A ranged read carries no truncation footer
  and must together reach the last line. A partial
  `skill=` read never arms it. Read-only tools,
  served `--intern-tool` calls and non-spawned sessions are never gated. The first redirect posts once to
  event-track. The close records `armed: yes|no|unknown` (`unknown` where no harness loop ran, i.e.
  native CLIs).
- **A document reaches a spawn by grant and pointer, not copy.** Member skill dirs are granted roots;
  under `source/` a member reads the docs floor and what its own grants name. `held-context:` is
  conversation context, not documents. A spawn takes its brief from one
  source.
- **Sandbox `input/`** is a container, and `input/<spawn-id>/` is the one run's own folder
  (`AgentsTools.SpawnSandbox.include`). Co-spawns of one session share the sandbox, its `output/` and
  its records, never an input folder: a spawn fills and empties only its own. That folder holds `dispatch.md`
  and a copy of the board item. It also holds `MAGIC.<package>.md` copies of
  the nearest MAGIC.md above every named path, never above `source/`, and
  `pointers.md` naming skillset files to read through Skill. A routine is
  never copied: the live file is read. Last comes `conversation.md` for a
  spawn continuing a thread, newest 50 per thread,
  `MDAT_CONVERSATION_HISTORY_MAX`. It is made read-only by file mode, because a verb-less access flag
  grants it for writing. Credentials are never copied. A run's own close empties its own folder.
- **Sandbox sweep**: each main-loop iteration empties the `input/` container of sandboxes on
  this host with no live process. It asks the one alive-by-one-rule check
  every reader now shares (see "A run is alive by one rule only" below). Never touched: another host, a running session, no record,
  or a record under 10 minutes old.
- **The session record** `<sandbox>/<spawn-id>.md` sits outside `input/` and `output/`, so the session
  cannot forge it. Its frontmatter rebuilds the spawned-sessions registry. Fields, in the order they are written:
  - `session-id`, `spawn-id`, `parent-spawn-id`: the parent run, the one that made the spawn
    call. A native caller's client session id stands as its spawn id.
  - `parent-session-id`: the parent session, the one that started this one, where there is one.
  - `start-context`: `spawned`, `inline` or `joined`. `inline` is a member brought into its
    caller's own session.
  - `reports-to`: optional, `<session>[:<member>]`, a member, `user-<account>`, `human-owner` or
    `none`. See "Where a run reports to", below.
  - `tracking-name`, `host`, `workspace`: basename, never a path, the one this record is kept in.
  - `executing-workspace`, `paying-workspace`, `member-workspace`: the three workspaces of this
    run, always, which executes it, which pays for it, which is the member's.
  - `owner`, `parent-member`: the member whose own call made this spawn.
  - `status`, `started-at`, `execution-receipt`, `output-file`, `agent-log-thread`,
    `cli-asked`: the service this one spawn was started on, where one was named for it.
  - `restarted-from`: a restart's own, the spawn id of the run it replaces.
  - `session-thread`, `spawns`/`spawned-by`. Then `run-process`: `<pid> <start>`, the process the
    launch started, replaced by each later launch.
  - `supervisor-process`: `<pid> <start>`, the shell that supervises the run and closes this
    record. The process the proxy starts for a run that is not waited for, the process the call
    runs in for a waited one. The handback retry leaves it as it was, and it is kept on the
    closed record.
  Which shell supervises is read before the launch (`AgentsToolsSpawnProxyShellNote`), not looked up
  again after it. Beside it: `event-track.thread` and `session.thread`
  (`<channel>:<ts>`). A coworking session shares one sandbox named by the session id. The start post
  names `paying-workspace` and `member-workspace` only where either differs from the workspace the
  session runs from.
- **The routine stack** (`AgentsTools.RoutineStack.include`, S6.27): `routine-stack:` lines on the session
  record, one a frame, the bottom first, `<routine file>:<state>`. The start writes the starting frames only:
  the chain `--routine-chain` declares, else the routine's own `routine-chain:`, else the one routine in
  force, the first frame `current` and the rest `pending`. A run joining a session keeps the frames its
  record already holds. The same frames go in the session thread's root post as its `Routines:` line, so a
  reader sees the path at the session's head.
  Four moves change them (`--routine-stack`, ThisSession): `push` and `replace` put a routine on top, the
  frame in force becoming `open` and `skipped`; `rewind` leaves every frame and runs the routine again;
  `return` goes one frame up and `return-to` to the frame it names, every frame above ending `done`. Each
  move appends one line of its own, `routine-stack-push:` and its three siblings, holding the routine,
  `by:` and the reason, and posts that line into the session's event-track thread. Those four keys are
  never frames: the reader of the frames takes `routine-stack:` alone. A move writes no CheckList, and its
  result names the steps of the routine in force and the step the run starts at.
- **Where a run reports to** (`AgentsToolsRunRoute`, `AgentsTools.SpawnSandbox.include`): its record's
  `reports-to`. Its handback goes there. So do its asks and escalations that name no target, and the
  notices of its end and its death. Unset, it is the initiator: the member that brought the run in
  (`parent-member`). That means it reports in the session `parent-session-id`
  names, where that member has a live run there. Else that session's executor, where it is live. Else a live `magic-coordinator` run, in that
  session or in this run's own, never this run itself. Else the human-owner. A member is named, never
  a run, so any live run of it takes the matter. `reports-to: none` is a run that reports to no one.
  It may send a handback as its final report, then it closes without waiting for dismissal. Its end
  is told to no one, and an ask of its own with no target goes where an unset `reports-to` would.
- **Who holds the authority over a run** (`AgentsToolsAuthorityHolds`, `AgentsTools.Authority.include`): the
  caller that an address of the holder names, or one a grant in the session names. The root
  `magic-coordinator` holds throughout, as the human-owner's representative. Where the run's parent session
  has ended, the ladder: the owners role (`HUMAN_OWNER_MEMBERS`) and the console mapped to the human-owner
  (`HUMAN_OWNER_CONSOLE_ACCOUNT`). Any other caller is gated (`AgentsToolsAuthorityGate`): the owner's
  console confirms with him in his own channel, and another console or member is refused, or asks the
  holder with `--escalate-wait` or `--escalate-enqueue`. A person at the console holds nothing by being
  there.
- **Children lists.** The spawn op appends the child's record path to `.local/agents/children/<parent>`.
  The main loop rebuilds all lists each iteration (`AgentsTools.ChildrenIndex.include`) and marks
  `children/.indexed`. Without the mark, a harness scans every record. Not under `sessions/`: a file
  there counts as session activity for the advance pass. `sessions/<id>/control/` falls under this
  too: a start of its control thread and a change of its `state` are such activity, a tick is none. A
  start now writes one line into `control/log` before the thread's own. `dead`, `gone` and the post files (`post.<run id>`, `post.<run id>.result`)
  are writes under `control/` too. So are `takes` (a start of the thread),
  `request`, `request.taken` and `outcome` (a kill through the thread).
- **`ListAgents` reads the spawned-sessions registry**, rebuilt from sandboxes on each call, the same
  rebuild `--make-harness-indices` also runs. Sixteen stored columns now, and the first seven are unchanged for position
  readers. `started-at`, `resolved-at` and `session-comment` were the three
  before these two: `session-state` and `session-state-at`. They are the word
  and the date the session's own control thread wrote in
  `sessions/<id>/control/state`. Both read `-` where a session has none or the
  file names no state. The two are the same on every row of a session. A caller gets them only by asking for sixteen (`registryColumns=16`, the
  fourth word `16` of `AgentsToolsRegistryMeasureRows`). One that asks for
  fourteen or none still gets what it knows. Whether the thread is alive is no column, since a registry may store the date
  a session started and the date a state was recorded. Liveness itself is
  still measured live, never stored. Beside them are `live` (checked during
  the call, this host only) and `state`
  (`thinking`/`tool`/`waiting`/`idling` for a run with a process here, else `parked`/`finished`/`failed`/`unclosed`). `ListAgents`
  itself still prints exactly what it printed before. `live` is
  told by the spawn id. `waiting` reads the pending-replies registry instead, told by the session. An
  ask counts for the session of the run that asked it, not necessarily the
  current spawn's own id. Rows are one awk pass (`AgentsRegistryHeaderRows.awk`), the same pass reading
  each session's state file too, named to it by the shell as a `T` entry. The
  awk is never given a path the shell did not find to be a file, and never
  forks per file. `live` and `state` are derived without a fork per row. Filters (`view`, `session_id`, `state`) are in the tool description.
- **A run is alive by one rule only, and every reader asks it.** A process of this host runs as a spawn when the value of its own
  `--session-id` or `--resume` argument is that spawn's id, matched whole. The
  first of the two on its line is the one that counts. An id standing anywhere
  else on the line is no run. Neither is a command line of the tooling itself
  (`DistroAgentsTools.fn.sh`, the command or its interpreter's script). The
  exception is a line with an option of the interpreter before the script,
  which still reads as a run. The control thread's own line, carrying `--session-id <session>`, is none, so it is never
  mistaken for the run it watches. A run is alive by its own word this way, or else by the process its
  record names, while that is still the same process. `TaskOutput`, the sandbox sweep and the ending of
  a dismissed run all ask this one rule now; no reader keeps a match of its own. A line that only
  carries a run's id holds no sandbox.
- **`AgentsToolsRunRecordedSupervisor <record>`**
  (`AgentsTools.Registries.include`) says whether a record's
  `supervisor-process` still lives: `alive`, `gone` or `unknown`, rc 0 for
  each. A record with no such header, of another host, or cut short reads
  `unknown`, never `gone`. The advance pass
  asks it now, to tell the end of a dead run only where its supervising shell is not alive. The control
  thread of a session asks it too, at every read in full, for each run of its own that is gone.
  `AgentsSpawnSupervisorRecordCheck` is its test.
- **The close of a run, in order**: handback retry, record, item, tokens, launch
  notice, the box of a missing handback and how the run ended. That box is
  told to the session that requested it. Then come the end post and finish
  flag, and the asks collected. The record is put in place by one rename
  and its close is tried twice (`AgentsToolsSpawnProxyCloseSandbox` over
  `AgentsToolsSpawnProxyCloseSandboxOnce`), a failure said on stderr. A waiting shell holds `INT` and
  `TERM` and ignores a broken pipe from the end of its run to the end of its close. A return that
  resumes a harness context records its restart in a subshell of its own. `AgentsSpawnSupervisorHoldsCheck`
  is the test. Whether a run handed back is one reading (`AgentsToolsSpawnProxyHandbacks`,
  `AgentsTools.SpawnSandbox.include`). It is used for the retry and for the
  note of its end. The `HANDBACK` events of the run's transcript come first.
  The announce line in its output counts only where the transcript holds none. A native CLI's handbacks count now.
- **The end of a run is told** (`AgentsToolsSpawnProxyEndNotice`,
  `AgentsTools.SpawnSandbox.include`; `AgentsToolsSpawnProxySessionNotice`
  stands there too). It is posted by the route (see "Where a run reports to"),
  in the thread of the session the run reports to. There it is addressed to
  its member, unless that thread already shows the member's own handback. One of six lines: `handback-missing`, `run-ended`, `run-killed` (by
  `killed-by`), `run-stopped` (by whoever ran `TaskStop`), `run-bound` (ended
  by the tooling's own bound), or `run-died`. The last is told by the control
  thread of the session, where its process is gone and nothing closed its
  record. A run no
  session requested is told once, to the human-owner, with an added sentence naming its session. The shell tells it at its own close, or else the advance pass does, never
  both. For a death, the control thread of its session tells it. That thread
  then holds the run from the advance pass while it lives. A record that
  carries `death-told` is told by no other closer. `AgentsSpawnEndNoticeCheck` is
  its test. Once a death is answered, six more lines of the same template say what was
  carried out: `death-resumed`, `death-fresh`, `death-new-process`,
  `death-closed`, `death-killed`, `death-failed`. The control thread's own
  call posts them, in the thread of the question and in the thread of the
  session that requested the run. `death-failed` names the item put back in review, if any. It also says the
  reviewer is asked again what to do. Nothing is tried a second time by
  itself.
- **A `--dispatch-doc:none` spawn writes nothing under `$MDAT_DATA_ROOT`.** Under `--wait` its output
  goes to the caller's stderr. Async, it goes to `$MMDAPP/.local/agents/sessions/<spawn-id>/session.log`,
  never to a returned caller's stderr (a `2>&1` capture would hang). The launch marker separates a real
  failure from a silent no-op.
- **Routine resolution** (`AgentsTools.SpawnRoutine.include`, function-only): a selector matches by
  substring against `*.routine.md` filenames under member folders; zero or several matches are refused
  with candidates named. `--routine-default` picks the routine of the `coworking` kind. The kinds are one list the tooling owns (`AgentsToolsSpawnRoutineKinds`):
  `coworking` and `standalone`. Each is defined by a bundled routine
  (`magic-team.coworking.routine`, `magic-team.standalone.routine`) that holds
  its rules, steps and default settings, `executors:` among them. A kind nobody ships is a kind nothing can run, so no routine claims a kind
  (`default-for-session-kind:` is gone). A routine names its own in
  `requires-session-kind:`, mandatory, and is never started without it. A routine run inline inherits from
  `magic-team.inline.routine` in place of its kind's. A routine needs a frontmatter block and non-empty
  `executors`/`maintainers`, the kind routine's defaults counted; missing `invitees` reads `none`.
  `--intern-op-spawn-prepare-brief` needs exactly one of the two options; the spawn proxy takes neither or
  one.
- **What every spawn gets.** The harness `Agent` tool prepends the spawn-prepare-brief block itself, unless
  the prompt already starts `SPAWN-PREPARE-BRIEF: `. If it cannot be built,
  the spawn still starts with a `NOTE:`. The proxy appends `## Staying on the task`: a spawn hands back, keeps
  `Wait`ing, and ends only on `DISMISSED`. A `--wait` spawn is the exception (its caller is blocked), so
  the proxy exports `MDAT_SPAWN_CALLER_WAITS=true`.
- **`DISMISSED` is recognised by its tag, never by the posting account** (spawner
  and child may share a bot). The addressees come from the send header: from
  the send's own `address_to`, or a typed `DISMISSED <member>`.
  One addressed to someone else, to nobody (`@here`), or sent with no `address_to`, dismisses no one. One function, `dismissalOf` in `AgentsDismissalMatch.awk`, also used by
  `AgentsSlackThreadAnswers.awk` so the own-post skip never drops it. `TaskStop` is the last resort for a run that keeps responding.
  `--manager-session-kill` is the console's own hard ending, outside the
  routine and reasoning paths entirely (see "The agents console").
- **A member holds one seat in a session** (`AgentsTools.SpawnSandbox.include`): the file
  `sessions/<S>/seats/<member>`, naming the run that holds it. A run takes it at its first read of the session or post to it (the served
  `Wait` and `SendMessage`). A start by the spawn proxy takes it at once. The first run to take it holds it; start times play no part. A holder that no longer runs holds
  nothing, and a run's close gives its seat up. A second start of a member whose seat a live run holds is
  refused by the proxy, naming the holder and `<S>:<member>`. A restart takes the seat over from the run
  it replaces, by `restarted-from:` on its record, and the replaced run is dismissed by the tooling.
  **There is no seatless run.** A run that finds its member's seat held by a live run is refused outright
  (`AgentsHarnessSeatRefuse`). It meets this at its first read of the session
  or post to it. The call answers with a refusal naming the holder and
  `<S>:<member>`. Nothing of the session is read or posted. The run then ends
  the one way a run is ended, a dismissed mark with its handback marked. The
  harness acts on that once the call is over.
- **No dismissal comes early.** A session's executor, the run that founded it, is not dismissed while
  another participant of its session runs, whatever dismisses it. No run is dismissed while a live run
  names it in `reports-to` or in the `review-by` of its item. A dismissal held so is kept in
  `sessions/<spawn-id>/dismiss-held` and given at the run's first `Wait` once those runs have ended.
  The review-wait limit dismisses no run while another participant of its session runs. A run without
  its seat is no running participant.
- **`--spawn-session`** resolves the routine once and spawns the executors, or the
  explicit members, async with `--dispatch-doc:create`. The first starts the
  session, and the rest join by its `SESSION_ID=`.
  A coworking routine's session always holds a `magic-coordinator` instance as
  its executor. Where the members started do not name it, it is seated first; in
  a partitioned run each child seats its own once its member started it; a join
  adds none.
  A `<type>-*` in the routine's executors or the caller's also partitions the
  run, as do two or more members the caller names. That gives one session per
  member under an agent-less parent, whose id is the `SESSION_ID=`. The parent carries `reports-to:` the caller's `<session>:<member>`, else
  `user-<account>`. Each child carries `reports-to:` the parent's session.
  `AgentsToolsRunRoute` takes it one hop on, to where the parent reports,
  never a second hop. So handbacks, escalations and the answers to them pass by the route, and review
  stays with the caller. The parent's `sessions/<id>/session.thread` is the caller's thread. At most
  `--workers <n>` children are open at once (default 4, as lib/parallel); the rest wait as `pending:`.
  `--partition-scope <text>`, repeatable, partitions by scope too. It gives one
  child per member and scope, deduped by routine × member × scope. Its brief
  starts with `scope: <text>`, and its record says `scope:`. The tooling never resolves a caller's `<type>-?`, from the caller or a routine
  header, even with one member. The start is refused and lists the candidates,
  one a line (`AgentsToolsSpawnRoutineEntryMembers`, the one rule of both
  sides). The parent's record is written before the first child. It names the children
  started, and `start-failed:` where a start failed. A failed start does not
  stop the rest, and the error names the children started. It names
  `session-comment: non-agent parent of <routine> (<short id>): <what the session is>` for the rosters, and every child of it carries that same short id. The files
  beside it keep what each start is given. Its watcher runs detached in a process group of its own and names its
  `run-process:` and `host:`. From then it is the record's one writer. It
  rebuilds `children:` from the records whose `parent-session-id:` is the
  parent. It closes a dead child by the death path, unless a control thread
  holds that death. It starts the queue while the caller is there, and holds
  the queue once the caller is gone, saying so once. It marks each post in
  `posted:`, so a watcher started again never posts twice. Housekeeping starts a gone watcher again
  (`AgentsToolsSpawnSessionParentRevive`), or closes the parent once nothing
  is open or queued (`AgentsToolsSpawnSessionParentClose`). The handback then
  lands in the caller's thread, naming each child and its outcome. Scans that take an open magic-coordinator-owned record as a coordinator run
  skip `agent-less: true`. A `reports-to:` whose caller no longer runs falls
  back as the route's own steps do.
  A wildcard or prose `executors` value is refused. The one function behind
  this, `AgentsToolsSpawnRoutineExecutorsRoster`, is also what
  `--manager-routine-list` asks to say whether a routine is startable. Every member of the call is asked three things before the first is started: a
  plain name, a member at all, and no identity record. A call with one wrong
  name starts nobody.
  Invitees are never spawned here. It takes
  `--spawn-settings-workspace <name>` and `--spawn-cli-service <name>`, the same as the Agent tool's own
  `settings_workspace` field beside `cli_service`.
- **The paying workspace is a spawn setting, not a workspace switch.** The CLI service, the harness tier and the credentials a member is spawned with
  are `magic-team`-scope settings. They are read from the workspace the
  session runs from, unless another workspace known on this machine is named
  to pay. One spawn names it with `--spawn-settings-workspace`; failing that it
  inherits the payer its own session was spawned with; failing that, the same
  key in one member's own scope (`SPAWN_SETTINGS_WORKSPACE=<name>`), and last
  `SPAWN_SETTINGS_WORKSPACE=<name>` in the `magic-team` scope for every spawn here. A review return's restart reads it
  from the record of the run it replaces, so it is paid from the same workspace. The spawn operation
  settles this once into `MDAT_SPAWN_SETTINGS_WORKSPACE` for that spawn
  (`AgentsToolsSpawnSettingsSettle`), and writes it there only when it names
  another workspace than the one spawning, so a child that spawns into another
  workspace stops paying from the one it left. Only these settings move. The board, the team data, the records and the comms
  stay those of the workspace the session runs from. The workspace named this
  way is read itself, never one it names in turn.
- **Member ops run in the member's workspace.** `AgentsToolsMemberWorkspaceResolve` (in `AgentsTools.MemberWorkspace.include`,
  sourced at entry) picks the current workspace if the member is there.
  Failing that, it picks the tracked workspace where it is a source link, else
  the first tracked one with it. A
  switch re-runs the whole call in a subshell with `AgentsToolsWorkspaceSwitch`. No switch for
  `magic-team`/`human-owner`, an untracked current workspace, the spawn ops, `--intern-mcp-execute`,
  `--intern-op-decisions-append` and `--intern-op-review-*`. The spawner starts the member's session in
  the member's workspace but keeps records and board in its own. A member's own settings for a system neither workspace holds any of are read
  from the workspace it is set up in instead (`AgentsToolsScopeHoldsKeys`).
  That is reported once on stderr (`AgentsToolsMemberSettingsBorrowedSay`). A
  team-wide setting is never borrowed this way.
- **Who may call.** `AgentsToolsActingMember`: `MDAT_SPAWN_AGENT`, else the harness agent, else the owner
  of the spawn record. No such session means the console, which passes every check. `--member-*` ops
  whose member is a credential or identity refuse a session naming another member
  (`AgentsToolsActingMemberCheck`). `--magic-*` refuses any session acting as another member
  (`AgentsToolsMagicCallerCheck`), with no exemption: `--magic-*` is `magic-coordinator`'s alone. Its refusal
  names that owner and says to ask the session's `magic-coordinator`, as the `--client-*` refusal names its way. `--client-*` naming a client runs only for that client in its own session.
  Nobody else gets it, and there is no exemption for `magic-coordinator`. It
  is checked once where the operation is dispatched. `--manager-*` is the console's
  own, nobody's member: refused from inside any member's session, the coordinator's included
  (`AgentsToolsManagerCallerCheck`, asked once where the family is dispatched). Tooling
  acting for another member calls the `--intern-op-*` form directly. The caller-check layer is one
  side-effect-free file, `sh-lib/member/AgentsTools.CallerCheck.include`: the acting-member helpers
  (`AgentsToolsActingMember`, `AgentsToolsActingSession`, `AgentsToolsActingMemberCheck`) and the three checks
  above. `AgentsContext.UseAgentsTools.include` sources it, and so may any `.fn.sh` that asks them alone;
  `AgentsCallerCheckSharedCheck` is its test.
- **`--client-operation-run <team-member> --client-<operation> [<argument>...]`**: `magic-coordinator`'s
  own way to a client's operation. The named team member is the client, dispatched in its own session as the
  named `--client-<operation>` itself would be. `magic-coordinator` never runs
  a `--client-*` operation directly. A coordinator's comms operation stays our own side, whatever member runs it.
  It no longer reaches the other organisation for a client. The communication
  sweep reaches each `client-*` member through this operation instead.

## 12. The main loop and the root harness

`--intern-main-loop`, `--intern-root-harness` and `--intern-session-control` have no help; their
contracts are here.

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
- **Each iteration** runs these in order: team-data sync (when
  `TEAM_DATA_GIT_REMOTE` is set), children index rebuild, the board's
  housekeeping (below), and pending-reply collect and remind. Then comes the
  check of the control threads. It writes one stderr line when it started any,
  logged in `AgentsToolsSessionControlCheckWorkspace` and never fatal. Last
  come the source collector, the configuration check and, when it passed, the
  schedule's steps (autorun, work duty, learning). The loop starts no agent of its own: what the schedule
  declares is started through the spawner. Nothing starts `magic-coordinator.advance.routine` by itself
  (`runs-at: none`): a console starts it by hand, and the coordinator's work duty takes its rules.
- **The board's housekeeping is the loop's, by script** (F3.1, F7.12), at each
  iteration and before the duty reads the board. It closes what a dead spawn
  left open (`AgentsToolsAdvanceSpawnHousekeeping`,
  `AgentsTools.SpawnHousekeeping.include`). That covers a started record whose
  session is dead, and the dispatch item it links. It also covers a running
  dispatch item whose record ended, and a review item whose reviewer ended.
  Both ends of every `blocks`/`blocked-by` edge are made whole, the cycles
  found and the dependencies reported (`AgentsToolsBoardDependencies`,
  `AgentsTools.BoardDependencies.include`). That runs once for each change of
  the board, and for none otherwise. It writes only items of the active states; what stays to judgement is
  named in `process-board-checks.md`'s **board-dependencies**. `--intern-op-routine-lock-take advance` still calls the
  first, for a manual start of the routine.
- **The coordinator's work duty is `magic-coordinator.work-duty.routine`**, which
  declares `includes: magic-coordinator.advance.routine.md: Steps, Routine's
  local procedures, Routine's local rules, Routine-specific tooling`. The
  mix-in engine puts those sections after its own (`--get-routine-text`, the
  brief and the cached prefix read the same bytes,
  `AgentsToolsSpawnRoutineMixIncluded`). The file named is part of the
  checksum of a cached text. The rules stand in the advance routine alone. The duty's scan carries the board for them
  (`AgentsTools.BoardRoundScan.include`: the digest, the review items, the
  registries, the rechecks due, the dependencies). Its `wait-sources:`
  (`inbox:{{team-member}}` for every member's duty, the five active states of
  the board for the coordinator's) are read at every pass of its wait. So an
  arrival wakes it within seconds. A recheck-date that falls due changes the
  scan, read at its TTL. It is started (`AgentsToolsScheduleDemand`) for an inbox item that is no
  standing state-and-lock note. For the coordinator it also starts on board
  news. That news is an item of an active state (not a `dispatch-*` item)
  written since its duty last ended. A recheck-date that fell due since counts
  too. Backoff starts at `MAIN_LOOP_RESTART_DELAY_SECONDS` (default 29),
  doubles on failure, caps at `MAIN_LOOP_RESTART_DELAY_MAX_SECONDS` (default 1200), resets on success. A
  permanent misconfiguration therefore shows as failures then silence, not a loud exit.
- **The configuration check is a script, no agent**: `--config-check`, run by the iteration
  after the housekeeping. It runs at most once in 30 minutes while it passes. In every iteration while
  its last result is a failure, it runs too
  (`.local/agents/main-loop.config-check.last`: the answer, then the epoch).
  A FAIL line is said on stderr with its reason. A failed check fails the
  iteration, and the backoff applies. The schedule's starts are skipped in it,
  the housekeeping having run.
- **A team-data store with content but no `.git` is adopted** by `myx.common git/cloneSync` into an empty
  remote only; `clonePull` never makes it a clone. `TEAM_DATA_BRANCH` travels as `init.defaultBranch` via
  `GIT_CONFIG_*`, or the push fails and `clonePull` then deletes the checkout. A remote with history plus
  local content is reported, to merge by hand.
- **`--commit-pending` commits, then syncs by `myx.common git/cloneSync`**, with
  `pull.rebase=false`: it pulls by a merge and pushes, with no push loop of its own. A real conflict
  leaves the merge in the store (`MERGE_HEAD`) and the call ends with status 1. A store that has no
  `README.md` gets an empty one from `cloneSync`, once. The store's branch must track its origin.
  `AgentsTeamDataCommitPendingCheck` is its test.
- **`--intern-root-harness [--routine <selector>] [--non-interactive] [--wait]`**, no member argument.
  The console no longer runs it; its caller is a person by hand.
  It spawns `--spawn-prompt magic-coordinator`. Interactive (default) loops in its own thread in `magic-team` and always
  waits, as the foreground job of its terminal. Ctrl+C reaches the proxy,
  which stops the session and closes it. `--non-interactive` runs one loop and
  posts to `event-track`, and needs `--routine`. The brief is the static `root-harness-session-start.prompt-packet.verbatim.md` with an
  `INTERACTION-MODE:` line (and a `ROUTINE:` line) prepended; no templating inside it.
- **The `🤖 AI service used:` line** is the spawn proxy's, read from the child's `DISTRO_CONSOLE_EXEC=`.
- **`--intern-session-control (--run|--one) --session-id <id>`** is a plain monitor, one per live
  session: no agent, no run. It keeps `control/` inside the session's folder: `lock` (a symlink naming
  `<pid> <start>`), `pid`, `state` and `log`. `state` holds `state:` (`running` or `finished`), then
  `state-at:` and `reason:`. A second start for the same session is refused while the first lives; a
  dead thread's lock is taken over by the next start. `TERM` is its only ordered end. It also ends by itself, with status 1, at the
  first tick that finds the folder of its session gone. That folder may be
  gone alone, or with the store above it. It then makes nothing again and
  writes one line on its standard error. A `control/` folder removed while the
  session's folder stands is still made again. `AgentsSessionControlRemovedCheck` is
  the test. A `put-back`
  re-execs the same thread in place when its own shell would otherwise die under it. The tick interval
  is `SESSION_CONTROL_TICK_SECONDS` (default 5). Who reads `control/`: the sessions registry stores its `state` at each
  rebuild. The list and the read of a session measure the thread itself by its
  `pid` and `lock` (`AgentsToolsManagerSessionControls`). Who starts it: the one function `AgentsToolsSessionControlStart`, detached.
  The console starts it by name, and so does the one check
  (`AgentsToolsSessionControlCheck`) for `--all`, the advance lock take and
  the main loop. Which sessions need one is judged from the rows. A session is
  left alone for five minutes after the last write of `control/log`, and a
  start writes one line there first. The spawner calls it too, in the shell that supervises a start that is not
  waited for, once the record of the run exists. It calls it with the first
  member of a session, a lone run too, and again by any member that joins
  while none lives. It never calls it for a start its caller waits on, nor for
  a member that joins a session such a start opened. Nor does it call it while
  a start is in flight (`AgentsToolsSessionControlStarting`, ten seconds). A failure is one warning line in the
  run's log, and the spawn prints what it printed. `AgentsSpawnControlThreadCheck` is its test.
  A third mode, `--death --session-id <id> --spawn-id <run id>`, is the thread's own call, apart from
  its tick. `control/` also holds `dead`, `gone`, `post.<run id>` and `post.<run id>.result`. `state:`
  is `running`, `member-dead` or `finished`. Two more settings: `SESSION_CONTROL_CLOSING_SECONDS` (300)
  and `SESSION_CONTROL_POST_SECONDS` (120). A run of the session is a death only where all five conditions hold. No
  process runs as it. Its record still says `spawn-started`. It carries no
  `killed-by`/`killed-at`. Its supervising shell reads `gone`, or `unknown`
  for at least the closing seconds. A second look agrees. Each death is then
  told and asked apart from the tick.
  `AgentsSessionControlDeathCheck` is the test. The `--death` call also does what is due about one death already told and
  asked, one thing a call. It reads the thread of its question, every
  `SESSION_CONTROL_ANSWER_READ_SECONDS` (default 60). Once an answer comes, it
  carries it out, started with the signals the thread ignores at their
  defaults. A shell cannot give back a signal it inherited ignored, so the
  call starts through `python3 sh-lib/run/AgentsSignalReset.py`, which
  resets them and execs it (`AgentsSignalResetCheck`). With no `python3` it
  starts as it is. `control/` also holds `post.<run id>.sent`. A line of `control/dead` is a
  history, and gains `answer=<option> answered=<moment>`, and
  `settled=<moment> how=resume|fresh|close|kill|withdrawn`. `asked=` and
  `answer=` may each stand more than once, read as they stand last. An answer that could not be carried out gains `not=<answer>,<moment>,<item put
  back in review, or ->,<why>` instead of settling. The same reviewer is asked
  again, once for each failure, by the same place and under a new question key
  (`death:<run id>:<number>`). No try is made without a new answer. An item a failed restart left in
  running with no run is put back in review. A question is recorded with
  `question-key: death:<run id>` and is asked once, whatever ends the post that asks it.
  `AgentsSessionControlDeathAnswerCheck` and `AgentsSessionControlStopKillCheck` are its tests.
  A fourth mode, `--request`, is the thread's own second call apart from its
  tick. It takes a kill request the console placed, carries it out, and
  answers. `control/` also keeps `takes` (what kind of request the thread is open to,
  written as it starts, emptied before a put-back), `request`, `request.taken`
  and `outcome`. `AgentsTools.SessionControlRequest.include` says what each
  holds. Two
  more settings: `SESSION_CONTROL_REQUEST_SECONDS` (5, how long the thread has to take a request) and
  `SESSION_CONTROL_KILL_SECONDS` (30, the bound of the call's own work). The state's `finished` reason
  names a kill of the whole session and who asked it, where that is how the session ended.

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
  `tools.listChanged` false, and no `notifications/tools/list_changed` is sent: the list is fixed for the
  run.
- **A trailing `wait` drains in-flight handlers** before the scratch root
  (`agent-mcp.<pid>` in the calling session's output folder, else `$MMDAPP/.local/temp/agent-mcp.$$/`) is removed.
- **`execute`**: `command` starts, `job` addresses an existing job (read first), so `required` is empty.
  Foreground `timeout` defaults to 600 s, capped at 3600; a bad value takes the default. On expiry the answer goes out at once. It says the call was asked to end, and
  that whatever of it is left is killed five seconds after. The partial output is kept at a named path. The call's process group is ended
  by `AgentsMcpCallWatch`, only while its leader is still the process that
  began when the watchdog started. The handler ends its watchdog, and waits for it, only while it has not fired.
  One that has already fired is neither signalled nor waited for, and finishes
  by itself. The same holds for a
  served harness tool at its own bound.
  `background:true` returns job id, pid and log. `job` polls by byte cursor.
  `action:"kill"` signals the job's group only while its leader is still the
  process `jobs/<id>/pid` names (`<pid> <start>`). For a file with no start it
  answers `NOT signalled`, as an error. `rc` is written by the job; no `rc` means
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
- **`RootSession`** is this server's own tool, beside `execute` and off the harness floor: the one
  root-harness session a server instance carries. It serves `operation=mint`, `adopt` and `info`.
  `mint` returns `SESSION: <id>` and `TOKEN: <token>`. `adopt` takes an id and
  the token mint printed, and refuses an id without its token or one this
  workspace does not hold. `info` returns the session the server carries. Every result also carries `USE:`, where to use the id, named as this server's
  session, and never a filesystem path. A refusal is fixed text and never
  repeats the operation, id or token a caller sent. The id is a bare lowercased UUID, the spawner's own form. The session is
  registered in the session store every session of this workspace keeps
  (`AgentsToolsSessionChatDir`), its token kept mode 600 there. So a later
  process adopts it. The server's scratch root (`root-session`) holds the one it carries. So a
  second `mint` in the same server returns the same id and token and creates
  nothing. The mint also records
  the session's channel kind there, `root-session.kind`, from this workspace's
  `ROOT_HARNESS_VERBOSITY` (F3.1, section 18); `adopt` reads it and never rewrites it. It writes no
  transcript pointer, no Slack message, no board item and no team channel. Reached through another server (`MDAT_MCP_SERVED_MARKER`), the WHOLE floor is
  withheld and only `execute` is served. `RootSession` is absent there, and so
  are `CheckList`, every harness tool and the secondary tools. Its contract lives in `sh-lib/mcp/AgentsTools.RootSession.include`.
- **A served call carries the root session the server holds** (F1.2). Each `--intern-mcp-request` reads the server's `root-session` store. Where it
  holds one, the request exports `MDAT_SPAWN_SESSION_ID` with its id, which is
  what `AgentsHarnessSessionKey` reads ahead of the client's
  `CLAUDE_CODE_SESSION_ID`. So `Wait`, `CheckList`, `Skill`, `execute` and every other served call run as
  that session's member (`MDAT_SPAWN_AGENT`, else the root session's
  `magic-coordinator`). They have no console, no spawn record and no session
  thread behind them. An `execute` script inherits `MDAT_SPAWN_SESSION_ID`. With no store the
  variable is unset there too, nothing else is set, and every served call
  executes exactly as it did. `MDAT_SESSION_ID`,
  the coworking session, is never set here.
- **The served floor is static.** The same tool block is listed from the server's first `tools/list` to its
  last, for the input cache the host keeps on it. A mint adds no tool and
  sends no `list_changed`. `CheckList` is our basic tool. It is listed on the served floor, declared in
  the model path and found by `ToolSearch` in every session. It refuses at
  execution where the harness knows no member or no place for its list. Then a
  hint names the way out (`RootSession operation=mint`, or `operation=adopt`
  for a session that already exists). It never claims the tool is absent, and
  never leaves the silence of a search that omitted it. The old conditional listing, its `checklist.offered` cache, the model-path
  filter and the `CheckList` decline are removed. That filter dropped
  `ToolSearch` from the declarations when no place was known. `mcpUnservedToolNames` names the two tools only the harness serves, `Bash` and
  `WorkspaceContextExecute`.
- **A harness tool joins the served floor by default.** `mcpUnservedToolNames` is the only subtraction.
  A tool that takes a command, or returns a handle only its own process can resolve, belongs there.
  `Bash` is unserved (callers use `execute`; native `Bash` is rerouted).
  `WorkspaceContextExecute` is unserved beside `Bash` for the same reason: it runs a caller-supplied
  script, and this server serves its own `execute` as the twin.
  Unserved means listed, with a description that says where the tool runs, and refused on call, where
  `tools/call` names the alternative. The harness and the MCP server list the same tools: a tool only one
  side serves is listed on the other the same way (`AgentsHarnessUnserved.include`).
- **The secondary tools are one tool per tool file that reaches outside the team's own process-flow.**
  `agentsFrontSecondary` (`AgentsContext.FrontTable.include`) names the files,
  and `AgentsMcpSecondaryMirror.sh` renders them from the same front table
  that routes their operations, so the catalogue stays short. The operation is
  an argument, `operation`, with the operation's own positional arguments in
  `args`. The whole call runs through `DistroAgentsTools <operation> <args…>`
  under its own watchdog. The board, inbox, dispatcher, questions, grants, session and testing files, and
  `Knowledge` (whose own entry is a query engine), are never served. Through another server they are
  withheld with the harness tools.
- **The containment check reads the served set from the real `tools/list`**. It
  also finds tools whose function runs `eval` or `bash -c` on a caller string,
  so renaming `command` does not evade it. The
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
  `AgentsClaudeHarness.sh` (the live Anthropic leg). `AgentsAnthropicStub.sh` is a non-working design record kept by the
  human-owner's decision. Its constraints block lists the `AgentsWire*` roster
  an adapter must define. Re-derive it from the core's call sites; an omitted
  function fails at call time.
  A stub must not grow into a selector.
- **`HARNESS_WIRE` names `sh-lib/harness/Agents<Wire>Wire.sh`** (`OpenAiChat`, `AnthropicMessages`).
  `HARNESS_TOKEN_EXCHANGE` names an optional `Agents<Name>Exchange.sh` (none ship); with one, an
  auth-class error body drops the bearer and re-exchanges within the retry bound.
  `HARNESS_EXTRA_HEADERS` are whole lines, checked at startup, sent on the `-H @-` stdin channel.
- **Provenance of declared values stays beside them**. The Scaleway tier table
  ("THESE MODEL NAMES ARE OBSERVED, NOT DOCUMENTED") and the Copilot model ids
  live in their stubs. Grok models and context come
  from xAI's `/v1/models`; Scaleway publishes none, so its stub declares 256000.
- **Copilot leg**: complete declarations, never exercised against the endpoint; blocked by
  `COPILOT_GITHUB_TOKEN`. Whether a token exchange is needed is open; one real round decides it. It
  declares the service's 128000-token context and 16384-token output ceiling, so the restart threshold
  is 111616 rather than the core's 400000 fallback. That Copilot speaks OpenAI chat-completions is
  documented, not confirmed.
- **Scaleway facts**: OpenAI Chat-Completions with SSE, `tools`, `tool_choice`; no Responses API (so Codex
  CLI cannot target it). Never sent: `frequency_penalty`, `n`, `top_logprobs`, `logit_bias`, `user`. Ids
  are bare. Scaleway is a hosting provider, not a model. A key is scoped by Project and
  policy, never by model, so there is one credential, `SCALEWAY_API_KEY`. The
  model is the preset's `PRESET_MODEL_OR_MACRO`. The stub names one model of its own, `deepseek-v4-flash-0731`, for both tiers --
  a default, never a roster -- and `heavy` adds `reasoning_effort:"high"`. Its error body is flat
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
- **Rounds.** A run stops itself at 2000 rounds by default (`MDAT_HARNESS_MAX_ROUNDS`; 0 = off). Reaching a cap makes one closing request with `tool_choice` off, never
  removing `tools`, which some wires validate and which is in the cache
  prefix. It then prints the model's account, and exits 3. The closing round itself is
  unprotected.
- **Context.** The threshold is the preset's `PRESET_CONTEXT_MAX_SIZE` (exported by the console) or the
  operator's `MDAT_HARNESS_CONTEXT_TOKENS` (0 = off), else a stub's per-tier window less `max_tokens`.
  At it the model writes its own handover, and a fresh leg starts from the
  original task plus that summary. That summary is `AgentsWireInitMessages`
  from unchanged `$harnessSystemText` and `$harnessPrompt`. A threshold less
  than half that window is warned of at start, since it restarts the run
  early. The signal is one round's `total_tokens`, not the running sum. An empty summary ends
  at exit 1. `MDAT_HARNESS_MAX_RESTARTS` bounds restarts, 12 by default and 0 for off. With no usage
  reported, round 1 warns once. One round can still overshoot. The Messages wire requires `max_tokens`;
  the chat wire omits it where undeclared.
- **Streaming.** `curl -N` SSE. One awk per round consumes the stream
  (`AgentsOpenAiChatStream.awk`, `AgentsAnthropicMessagesStream.awk`, loading
  the JSON field and slice libraries) and writes `stream.*` files. The shell
  only shows live output. Wait for `data: [DONE]`, not `finish_reason`: a
  usage chunk can follow. A mid-stream disconnect retries the whole round, max 3
  (`harnessStreamMaxAttempts`), never counted against a round cap. Stall bound
  `--speed-limit 1 --speed-time 45`; no `--max-time`.
- **Prompt caching is a byte-prefix match.** The tools literal is rendered once; the request appends in a
  fixed order. A re-serialised array stays valid and silently loses the cache; on the Anthropic wire a
  changed set mid-leg is a 400 at replay. `stream_options.include_usage` is sent, and every bound states the spend it stopped.
- **Every bound states the spend it stopped.** `AgentsHarnessSpendSay` prints one `SPEND:` line at each bound that closes the run with tools off: the round ceiling and the restart ceiling. The line carries the rounds, the figures `in cache-read cache-write out`, their total and the bound that fired, summed from `stream.usage.detail` across the leg. The same line is appended beside the run record as `<session>.spend`, where the `.restarts` and `.refused` markers already sit. The start line states both ceilings, so a default nobody chose is visible before it stops anything.
- **A quiet run stops idling.** Twenty idle-wait keepalive rounds in a row, with nothing arriving, end a duty's idling: `harnessQuietRounds` stays 0 until a keepalive comes back with no arrival. The run then reaches its plain-reply end, which gives the handback and the CheckList gate.
- **`AgentsAnthropicMessagesWire.sh` replays the assistant turn byte for byte**, thinking block and
  signature included, in stream order (GAP-2 in the Anthropic stub's record). The one exception is a
  `tool_use` name the provider broke with its own markup: the API matches it against the declared tools,
  so that block alone is built again under the name the core cut it back to, and every other block still
  goes back as streamed. A round with no such call takes the untouched path, so the prefix and the cache
  are unchanged.
- **A busy or empty provider pauses the run, not the round (S6.18).** `HARNESS_BUSY_BUDGET` seconds is one
  budget for the whole run: it stands outside the round loop, a busy answer and an empty stop spend the
  same one, and a value that is not a whole number of seconds is 21600. A status line is read as its
  number, with the transport's `\r` taken off, so a bare `HTTP/1.1 503` is still 503.
- **Progress lines.** `AgentsHarnessAnnounceTool` prints before each call. Every value (tool name too) goes through `progressLineSafe` in
  `AgentsProgressLineSafe.awk`. It is one line, C0 and DEL folded to space,
  cut at 120 bytes on a UTF-8 boundary, keeping a path's end. This stops injected values forging the
  display. Our own ANSI is deliberate; any escape from untrusted data is neutralised. Check a display
  change against this first. Colour needs `[ -t 2 ]`, no `NO_COLOR`, ≥ 8 colours.
- **`progressLineSafe` is its own file.** `-v progressLineCap=<bytes>` makes it render stdin standalone;
  loaded with `-f` ahead of a formatter, it is a library. A formatter loaded without it dies at the first
  call.
- **`Bash` tool**: output to a scratch file, never `$`; containment
  `( cd … && set -e && eval … ) || status=0`; only its cwd is bounded to the roots. Its watchdog
  `sleep` must redirect `>/dev/null`, or it holds the capture pipe for the whole timeout. Bound only
  where `MDAT_HARNESS_RUN_TIMEOUT` or the call's `timeout` sets one; Darwin has no `timeout` binary, so
  the shell watchdog is the live path.
- **A harness path is absolute and already normalised, and its refusal does not say so.** `Bash`'s
  `cwd`, and the paths `Read`, `Glob`, `Grep`, `Edit` and `Write` take, pass `AgentsHarnessPathAllowed`
  first (`sh-lib/harness/AgentsHarnessAccess.include:67-73`): a relative path, a `.` or `..` segment,
  and a bare name are refused before the access roots are read. The refusal quotes the path as typed,
  so a dotted path under a granted root reads exactly like a genuine miss.
- **`WorkspaceContextExecute` tool**: the harness's own analog of the MCP
  `execute`, a foreground run of one shell script. The myx.distro workspace
  context is established (`Distro`, `Require`, `Action`, `DistroSystemContext`
  defined, `MMDAPP`/`MDLT_ORIGIN` set). It runs `DistroAgentsTools --intern-mcp-execute` in a fresh process, output to
  a file and the pid waited on, never `$( )`. Its watchdog ends the process

  group, as `execute` ends its own. The MCP server serves its own `execute` instead, so this tool is in
  `mcpUnservedToolNames` beside `Bash`.
- **Wait bounds**: `MDAT_HARNESS_WAIT_TIMEOUT` caps a harness `Wait` (unset: wait until something
  arrives). A served call returns by `MDAT_MCP_WAIT_BOUND` (1700, under the native 1800 s idle cutoff),
  or `MDAT_MCP_WAIT_BOUND_PROGRESS` (14400) with progress notifications every
  `MDAT_MCP_PROGRESS_SECONDS` (60).
- **A session's `Wait` returns after one round when nothing arrived**, rather than
  holding the whole bound. A round is a little shorter than the calling CLI's
  own cache lifetime, set per CLI service. `WAIT_ROUND_SECONDS` overrides it. The empty result is one plain line naming the call to go on with.
  A `Wait` of interest to the session also wakes an ask tool's own inner wait.
  That wait then returns `ASK-RESULT: ARRIVED-OTHER`, its own question still
  open, with the exact next call on its last line.
  An answer, once it comes, is taken once and confirmed once in its own thread.
- **Access roots** are rendered by the console into each client's flag (`--add-dir`, `--access-root`).
  They are the roots the spawned member is granted, off the grants index
  (`AgentsToolsClientAccessMemberRoots`). Its rows name a whole `<dir>/**`,
  never all of `source/` unless granted. A globbed row (the source docs floor)
  is decided per call. A leg gets the read and write sets apart. claude-native and copilot-native get
  one `--add-dir` set, every root the member may read or write, a read-only
  place included. With no index, they fall back to the install fragment.
  `own`/`explicit` lines are trusted; `wildcard` and untagged lines are existence-checked. The harness's
  own fragment read is only a fallback for consoles generated before `--access-root`; it keeps the text
  after the last tab if absolute. No roots is a refusal.
- **`--agent <name>`** reads `$MDAT_SKILLSET_ROOT/<name>/<name>.basic.md` as the system identity and tells
  the model to read its `.armed.md` with the `Skill` tool. A missing `.basic.md` is exit 1. `--session-id` is announced as
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
  (refused before any request) falls back once to a new process. **Every kept record is scanned for a call
  with no result** (S6.16), not the last alone: a death after a result leaves that result last, and both
  the chat wire's `tool_calls` and the Messages wire's `tool_use` blocks are read, with `tool_call_id` and
  `tool_use_id` taken as the answers.
- **Hook payload** is built from values already parsed; `session_id` and `cwd` are escaped once at source
  time. Decision and reason come from one read through `AgentsHarnessHookDecision.awk`. Hooks are
  fail-closed: unreadable config, a hook that does not finish, or an unreadable answer refuses.
- **MCP client** (`AgentsHarnessMcpClient.sh`). With no `--mcp-server`, the set is the keys of
  `mcp.servers.json` minus `myx.distro` (enumerating itself recurses). A run with no server opens no file;
  the offline checks depend on that guard. One process per enumeration: `initialize`, `notifications/initialized`,
  `tools/list` are written first. Stdin is held open until the awaited id
  appears. Closing it first leaves `myx.common`'s background answer unsent. Answers are read from a
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

- **The set** (`harnessToolsJson` in `AgentsOpenAiChatWire.sh`) holds these tools:
  - `Read`, `Write`, `Glob`, `Edit`
  - `Grep`, `Bash`, `WorkspaceContextExecute`, `WebSearch`
  - `WebFetch`, `SendMessage`, `ListAgents`, `Wait`
  - `SubagentHandback`, `ReportFindings`, `PushNotification`, `Artifact`
  - `AskQuestion`, `ConfirmReadback`, `EscalateDecision`, `RequestPermission`
  - `ProposeApprove`, `ListMcpResourcesTool`, `ReadMcpResourceTool`, `ReadMcpResourceDirTool`
  - `Skill`, `Agent`, `TaskStop`, `TaskOutput`
  - `ToolSearch`, `SessionTranscriptAppend`, `CheckList`, `BatchTools`, `ThisSession`.
   33 tools. Each has four sites: the
  declaration, and in the core the announce arm, the dispatch arm and the function.
- **The tools literal is one bash single-quoted string.** An English possessive closes it
  (`HARNESS_PARSES` catches this; the site check does not). A missing comma between declarations passes `bash -n` and the site check, and
  fails only at the endpoint as a 400. `HARNESS_TOOLS_JSON` catches it by
  comparing text and parsed counts. Run it after any declaration change.
- **A parameter the dispatcher reads must be declared in `harnessToolsJson`, or every call carrying it is refused.** `AgentsHarnessRunTool` refuses a
  top-level key the tool's `parameters.properties` does not name, before anything runs. The names are cached in
  `$MMDAPP/.local/temp/mdat-harness-tool-args`, built again when the wire or its two readers are newer. An `mcp__*` tool is its server's to check.
- **Addressing.** `SendMessage`, `SubagentHandback`, `PushNotification`, `ReportFindings`, `Artifact`,
  `AskQuestion`, `ConfirmReadback`, `EscalateDecision` and `RequestPermission` share one `to`
  resolver, which reads one of these forms:
  - named conversations, a bare id, or `<channel>:<ts>`;
  - `session-parent`: the thread of the session the run reports to, by the route, see "Where a run
    reports to", section 11. None is an error, never another thread.
  - `session-current`: the session thread of the coworking session the member works in now. Both
    names resolve in the one resolver, for every operation that takes them, not only these.
  - `client:<conversation-id>`, `client:<channel>:<ts>` or `client:<user-id>`, a `client-*` member's
    own addresses into the other organisation. Refused on every other member, and refused back
    onto our own named conversations and session addresses, each with the one line naming the side.
  - or a member name, its DM via `AgentsToolsCommsSlackMentionUserId`. An ask naming a member instead
    replies in the session thread, addressed to that member, the thread itself unnamed. No Slack
    account means an `inquiry-*` in its inbox, which `AskQuestion` refuses.
  
   An empty `to` is the session thread (`AgentsToolsSessionThreadFind`), resolved
  inside `--slack-send-message` so MCP gets it too. The same holds in a native
  session that is itself the coworking session. The ask tools follow the same
  rule. `SubagentHandback` defaults to `session-parent`. `ProposeApprove` keeps its own `to`: the
  human-owner by default, or a named conversation -- never a thread, since its first message opens one.
  The bodies of `SendMessage`, `SubagentHandback`, `ReportFindings` and
  `PushNotification` are template blocks now, and so are the joined, readback,
  withdrawn, reminder, forward and holder lines. The five ask tools below are
  the same. A handback, a findings report, a notification and a document each render the
  same way. First a title with its own icon, then the task in plain words,
  then labelled fields. A
  notification's title is its severity: `Notice`, `Warning` or `Alert`.
- **`address_to` names who a post is for, apart from `to`'s target.** `SendMessage`, `SubagentHandback`,
  `ReportFindings`, `PushNotification` and `Artifact` take it, as the ask tools already did (`--address-to`
  at the CLI). The tool tags the real mention itself (see "Send header"); nothing is typed into the body.
  A thread post with none is headed `@here`, read as for nobody. `SendMessage` to a session thread with
  `address_to` naming a member and the body `DISMISSED` dismisses it; with no `address_to` it dismisses
  no one. A `SubagentHandback` naming nobody is addressed to the member the run reports to, by the
  route (`AgentsToolsSessionParentMember`; see "Where a run reports to", section 11).
- **The five ask tools** (`AskQuestion`, `ConfirmReadback`, `EscalateDecision`, `RequestPermission`,
  `ProposeApprove`) each render by their own template (`sh-lib/templates/<tool-kebab-name>.post.format.md`).
  `select` gives the answer form: `text` (the default, no `select` given),
  `yes-no`, `one` or `many`. Of those, `one`/`many` need `options`, and
  `yes-no` takes none. `options` given with no `select` returns a correction,
  posting nothing. `revise` re-asks a question still open, changed, in
  that question's own thread, by the pending id the first ask returned. `ProposeApprove` alone takes `question`, `proposal`, `document` (an absolute
  link, required) and `task_ref` in place of a plain question and `select`. It
  posts `question` once as the root, with no tooling emoji under it, and
  `proposal` as the reply under it. The owner's own reaction on the root is the verdict. A reply whose first word
  is `approved` or `rejected` is the same verdict. Any other reply is
  `VERDICT: RETURNED`, kept as a comment. `revise` there deletes the live proposal reply and posts the changed one under
  the same root. Only magic-coordinator may call it, and only while the root
  carries no verdict yet.
- **Identity on a served call**: `MDAT_SPAWN_AGENT`, else `magic-coordinator` for a root session, kept only
  if that `.basic.md` is readable; otherwise sending tools refuse. The session it acts in is
  `MDAT_SPAWN_SESSION_ID`, which a request sets from the server's `root-session` store when it
  holds one (section 13). A model run without `--agent` refuses
  to send. Text goes on stdin; no credential in argv.
- **`NEXT:` lines.** A result the model must act on ends with one `NEXT:` line naming the call,
  added after the existing lines, in the core only. That line carries `Wait`
  stateful TIMEOUT/RECEIVED/DISMISSED, `SendMessage` posted,
  `SubagentHandback` from a non-blocked spawn, and `AskQuestion` left open
  with `WAIT-ID:`. It stays the last line of the result. The date is never a line before it, for
  it is no part of a tool's output (next bullet). A `Wait` TIMEOUT is its one line, the `NEXT:` part last.
- **One reply layer serves every tool result** (`AgentsTranscriptReplyFinish`,
  `AgentsTools.SessionTranscript.include`). That covers a served call, the MCP
  server's own tools, and each result the harness's model loop hands its
  model. Every reply carries the host's local time, `current-date: YYYY-MM-DD HH:MM
  +ZZZZ`, as a content part of its own beside the result. It is added where
  the reply is encoded, and never as a line or a member inside a tool's
  output. In MCP it is the text item right after the result, the second item
  of `content`. The head part of a path tool goes first, which makes it the
  third. In the model loop it is a separate part of the tool message. A served call (`--intern-tool`) prints no date at all. A result
  over 8192 bytes is kept whole in
  `.local/agents/sessions/<key>/results/`. The reply then opens with a preview, the whole lines that
  fit in 2 KB or the first 20, never over 7 KB. It names the file, its size in bytes and lines, and a
  by-range `Read` for the rest. The result's closing lines close the reply too. Skill, ToolSearch and a Read of a kept file are never kept, nor is a Read
  given `offset` or `limit`. Such a Read returns its lines whole within Read's
  own byte cap, which cuts at a whole line and names the offset to continue. A Read with neither is kept like any result. Its hint names the original file
  and the next offset to read by range, not the kept copy. With no session, or a file that cannot be written, the result comes back
  whole. `AgentsReplyCurrentDateCheck` and `AgentsReplyLongResultCheck` are the tests.
- **`BatchTools` is one call that calls several tools and returns their results in
  call order**, to save rounds. The harness makes each call a served call of
  its own, and the MCP server a request of its own
  (`AgentsTools.BatchTools.include`). Its arguments are `mode`, `calls` (a list of `{"tool":..,"arguments":{..}}`),
  `workers` and `format`. The five modes are these. The first, `sequence-stop-on-error`, skips the calls
  after an error. Then `sequence-all-through` and `parallel-concurrent`, the
  second of which runs at most `workers` at once, default 4. Then
  `parallel-all-any-match`, which returns at the first ok and cancels the
  rest, and `parallel-all-through`, which runs every call at once. The result is one `BATCH-ENTRY: <n> <tool> <ok|error|skipped|cancelled>` line
  for each call, in call order, each followed by that call's result, and a
  last line `BATCH-RESULT: <mode> <ok>/<total>`. With `format: "json"` it is
  one object, `{"mode":..,"entries":[{"tool":..,"status":..,"result":..}]}`. Each call runs exactly as it would on its own, through the same code of that
  server. It gets a process and a group of its own, with its own timeout, as
  the batch has none. A cancelled call is ended as `TaskStop` ends a job. A call
  is any tool the server serves, so batches nest. An unknown mode, `format` or tool, or a `workers` that is no whole number
  above nought, is refused with nothing run. Every call is checked before any
  starts. An entry keeps the reply layer's rules except the date. Over 8192 bytes it is
  a file reference, and the batch's one reply carries the one date
  (`MDAT_REPLY_IN_BATCH`). `AgentsBatchToolsCheck` is the test.
- **`Wait` tool** calls `--wait-for-input`, which takes `slack:session-current`
  and `slack:session-parent` itself, the same as the other four built-in
  aliases and their `:<ts>` form. It adds only three things: `mode`
  (`default`/`continue`/`close`), reaction id sets, and `DISMISSED` detection.
  That detection is `AgentsHarnessWaitDismissed.awk`, its member through
  `ENVIRON["dismissalMember"]`, matched by `AgentsDismissalMatch.awk`'s one
  shared rule. A body that is exactly `DISMISSED` counts. So does one
  addressed to this member by the team send header naming it, or typed plain
  as `DISMISSED <member>` with no header. It is recognised by that tag, never
  by the Slack account, since several members post under one team bot. It is
  never a dismissal of its own author. Session id from
  `AgentsHarnessSessionKey`. A call with six or fewer
  arguments stays stateless. A send records every post in `sessions/<id>/last-own-post`, one line each,
  latest first, its first line what it was before.
- **A session's `Wait` always carries `replies:<session>` first, the floor**
  (`--wait-default` or `--wait-continue` with `--wait-session-id`;
  `AgentsWaitProbeReplies`, `AgentsTools.MemberWaitReplies.include`). That floor is
  the replies to the run's own posts, whatever tool posted them, read from
  `last-own-post`. A named set is the Wait's own (sketch 3.2: "either OWN set / either adding OWN implicit floor to
  current set"). The sources a call names replace the defaults: the session thread, or the team
  channel and the owner DM. Those defaults stand only where none is named. The floor is added
  either way. It is every way a person may reach the member:
  - the replies;
  - the session chat (`chat:`);
  - the DMs (`dms:`);
  - the mentions (`mentions:`, not for a client-* member);
  - the wake marker (`wake:`).
   The sources the caller names are added to the floor, never put in its place. A
  post whose thread or conversation another source of the same wait reads is
  left to that source, so a message is returned once. Three limits keep the watch bounded. A post is looked at when its TTL has passed: 5 seconds, and 1
  more for every 20 it has been quiet. So a quiet thread is looked at ever more rarely, and never
  dropped by time alone. A post at the top of a conversation has the messages after it watched only
  until ten have followed it. After that, only a mention of the run is watched. Reactions to a post
  and mentions of the run are always watched.
   A bare conversation source (`slack:<id>`) returns its arrivals: its read is already formatted,
  and the JSON formatter is applied to a thread's read only.
- **`mentions:<member>` is one `search.messages` call**
  (`AgentsWaitProbeMentions`, `AgentsTools.MemberWaitMentions.include`). It asks for
  the member's mentions in any conversation, thread replies included, from the
  session's pointer `mentions:<member>`. Its TTL is 60 seconds, and the
  session keeps it across Waits (`mentions-checked:<member>`). So a Wait start
  inside it makes no call. A member with a Slack account is searched by `<@id>`, one with
  none by the text `"@<member>"`. The member's own user token searches; where it may not, the team identity
  `WAIT_MENTIONS_SEARCHER` names (default `magic-coordinator`). Where neither may, that is an error in the Wait header (`WAIT-SOURCE-ERROR:`),
  apart from the sources never read. A source denied for want of a permission
  is known to be denied, so it does not hold back a keepalive. LIMIT: the text search is for the handle alone, not its aliases, until an OR
  of Slack search is confirmed live. One call cannot ask for several texts.
- **A dismissal ends the run.** The session keeps its own dismissed mark, so every later `Wait` on it
  returns `DISMISSED` at once with no further read. The tooling ends the session once its handback is
  given, or at once if it had already handed back.
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
  acceptance. The fitting guard, if needed, resolves after the lexical gate. It then
  requires the result under the resolved member folder (a resolved
  skillset-root prefix admits only one member). `Skill` shares
  `offset`/`limit` with `Read` via `AgentsHarnessReadRange`; without `limit` it reads to the end within the
  byte cap.
- **`Skill skill=`** loads a skill like the native tool: bare name, `anthropic-skills:<name>`
  (`~/.claude/skills/synced`), `<plugin>:<name>` (synced plugins), `<dir>:<name>`. Frontmatter removed,
  `Base directory for this skill:` prepended, `$ARGUMENTS` placeholders filled,
  `disable-model-invocation: true` refused. **A team member's default load is a bundle, in place of its `SKILL.md`**, which
  stays the boot file of a native client. That file puts nothing in the read.
  The bundle is the member's `.basic.md` and `.armed.md`, then the team's
  (`magic-team` reads its own once). Each is a section of its own by file name
  (`AgentsToolsMergeMdFiles`, section limit 6, every level kept), where both
  of a pair exist. A member reading its own skill gets, below them, its section of the tool index
  as `# Tool index`, rebuilt first where it is missing or stale. With no index
  the read goes on without it. The `SKILL.md` is read first only for
  its refusal: an `ERROR` there is the read, served alone, and its `$ARGUMENTS` fill nothing of the bundle. A
  `SKILL.md` with `status: reference-only` is served as is, its own file. A merge that fails is one
  `ERROR: Skill:` line.
- **The tool index** (`--intern-op-tool-index [--ensure]`, no help;
  `AgentsTools.InternOpToolIndex.include`) is `.local/agents/tool-index.md`,
  one section per team member. It is generated and never written by hand, from
  the template `sh-lib/templates/tool-index.document.format.md` filled by
  `AgentsToolIndexFill.awk`. Who may use what is read there, never written. For the three families the
  dispatcher asks a caller check for (`--magic-`, `--client-`, `--manager-`),
  that check itself is asked. It is asked for each member and for a call from
  no member's session. For the tools, it is the tool rows of the grants index,
  which carry what the projects declare in `project.inf`, the `magic-team:`
  floor directives of named members included. A family no check is asked for, and a tool no row names, is
  everyone's, gated per call. The same inputs give the same bytes: no date or time, members and files in byte
  order, operations in their help's order. It is rebuilt the way the grants index is. With no argument the op writes it, whatever it held, through a temp beside it
  and a rename. `--ensure` makes the grants index current. It rebuilds the
  tool index only where it is missing, in another format or older than what it
  is made from. It then prints its path, which is what the `Skill` read asks.
  A rebuild that fails keeps the old index, read as it stood.
  `--make-harness-indices tool-index` builds it too.
- **`Edit`** replaces an exact literal that occurs exactly once, counted with the same `index` that
  substitutes (never `grep -c`). One call carries one edit, or a list of them in `edits`. Each is read as the
  top level is and applied in order, each to the text the edit before it left.
  Uniqueness is required per edit, unless that edit's own `replace_all` lifts
  it. All or nothing: every edit in the list applies to a scratch text before
  anything reaches the file. A failing edit is named by its position (`edit N
  of M failed, none was applied`). Text through `ENVIRON`; output with
  `printf "%s"` so no newline is added. **Write and Edit replace by rename under a per-target lock** (a symlink in
  `.local/agents/locks/<cksum>` naming the pid; dead holders broken; 30 busy
  polls then error). The lock is taken once for the whole call, list or
  single. Known limits: hard links break. A kill mid-way leaves
  `.<name>.mdat-write.<pid>`/`.<name>.mdat-edit.<pid>`. Ownership changes to
  the writer. Two breakers can both win. A pid reuse keeps a lock looking
  held. A second kind of lock exists beside this one: `sessions/<id>/control/lock`, a
  symlink naming `<pid> <start>`, held for a control thread's whole life and
  never waited for. It guards a session id against a second thread, not a
  critical section. It tells its holder by pid and start together, never by
  pid alone.
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
  `--append-transcript` with no `--transcript-name`.
- **`ThisSession`** is the session's own channel as one tool, the operation its
  argument, like the subsystem tools. `post` sends `message` to the session
  thread and nowhere else, `address_to` naming who it is for. The message is
  recorded in the session chat file first and posted after.
  `routine-run-inline` runs a routine of this session. A session with no thread is refused with `ERROR`, and nothing is
  posted. It has no read: every `Wait` already brings the thread's replies.
- **`Artifact`** announces a `url` as it always did, ungated. With `file` (and `files`) it publishes first. `AgentsHarnessArtifactPublish`
  checks `AgentsHarnessGranted Artifact publish` (not on the floor: a standing
  `allow-tool` row or a task or session grant), and runs the read gate on
  every file. It then calls `--intern-artifact-publish` and posts what it
  printed (`ARTIFACT_URL`, `ARTIFACT_TITLE`, `ARTIFACT_KIND`). A publish that fails after the document exists says its URL and posts nothing.
  The publish never goes through the `--magic-`/`--client-` page-create stubs: it is the caller
  acting with its own credentials, gated by the permission alone ().


### The Wait includes: the notes their comments held

The shell lexes every comment of a file it sources, on every Wait. So `AgentsTools.MemberWait.include`, `AgentsTools.MemberWaitRun.include` and `AgentsTools.MemberWaitSources.include` keep one line a comment (S28.7).
The longer text of each comment is kept below as it was written, under the code line it stood above. Code lines are quoted as they were when the notes moved.

#### `AgentsTools.MemberWait.include`

- The head of the file

~~~text

AgentsTools.MemberWait.include -- --wait-for-input: one bounded long
poll over a list of input sources, returning the moment any of them changes.

The waiting happens HERE, in the shell, which is the whole point: a caller
that would otherwise burn a round trip per check spends one call and one
result, and its context does not grow while nothing is happening.

A TIMEOUT IS NOT A FAILURE. "Nothing arrived within N seconds" is a normal,
successful outcome, and a caller must be able to tell it apart from "the
probe could not run" without guessing -- otherwise it cannot choose between
waiting again and escalating, which is the only reason this operation exists.
So stdout ALWAYS opens with exactly one marker line:

    WAIT-RESULT: RECEIVED   -- something arrived; the detail follows
    WAIT-RESULT: TIMEOUT    -- the bound expired with nothing new; normal. No --wait-timeout
                               is no bound, so then only an unreadable first round returns it
    WAIT-RESULT: ERROR      -- the wait could not be performed; see stderr
    WAIT-RESULT: CLOSED     -- --wait-close ended the stored wait; nothing was waited on

RECEIVED, TIMEOUT, CLOSED, ADDED and DROPPED all return 0, because all are answers. ERROR returns 1.

    WAIT-RESULT: ADDED      -- --wait-add put its sources into the stored wait; nothing was waited on
    WAIT-RESULT: DROPPED    -- --wait-drop took its sources out of it; nothing was waited on

MODES, mutually exclusive, each needing --wait-session-id: --wait-default waits on the
sources and filters it is given (or the default ones), --wait-continue repeats the stored
sources and filters, --wait-close removes the state. With none of them the call keeps no state.

LOSSLESS BY DESIGN. Neither --wait-default nor --wait-continue drops a stored per-source
floor: a Slack source the session already waited on resumes after the last message a
wait returned on it, so a post that landed while the caller was busy between two calls
is returned by the next one, whichever mode it names. Only an explicit
--wait-since-utime replaces those floors, and only --wait-close (or --wait-drop) removes
them. A tag, a direct message and a mention keep a floor the same way (`floor
tagged:<member>`, `floor dms:<member>`, `floor mentions:<member>`), so a message posted
into any of them between two calls is not lost either. A :conversation thread with no stored floor starts at the session's own last post

in that thread (sessions/<id>/last-own-post, written by the harness send), else at the
spawn's launch (the mtime of $MDAT_SPAWN_LAUNCH_MARKER), whichever applies and is older
than the wait; every other source with none starts at the wait's start. A floor only ever advances to the newest
message a result actually carried. On an arrival from a Slack source the wait settles
for $MDAT_WAIT_SETTLE_SECONDS (default 3) and re-reads, up to
$MDAT_WAIT_SETTLE_ROUNDS (default 3) times while more keeps arriving, so a burst
returns together, oldest first.
--wait-add appends sources to the stored wait, creating it when there is none, and
--wait-drop removes them, removing the wait once none is left: this is how an asked
question's wait item (ask:<pending-id>) joins the session's wait and leaves it once
answered. Neither takes a thread source, since, addressee or include-own: those are
shared by the whole stored wait, which a source joining it must not change.
Message ids named in --wait-react-seen|note|done|wait are reacted to before anything else.

--unwait <kind>:<target> is a named shorthand for --wait-drop --wait-source <kind>:<target>:
nothing more than that, and returns the same WAIT-RESULT: DROPPED. Dropping a source from
the stored wait is never blocking it: a later call naming the same source explicitly,
whatever mode it uses, reaches it exactly as if it had never been dropped.

A source never read once during the wait is named on the line right after it:

    WAIT-NEVER-READ: [<kind>:<target>] ...


absent when every source was read at least once. It changes neither the outcome
nor the return code; a caller watching one thread reads it to tell a quiet
thread from one it could not see at all.

A NAMED SET REPLACES THE STORED SET, THE FLOOR IS ALWAYS ADDED, A CLOSED ASK LEAVES (; sketch 3.2: "either OWN

set / either adding OWN implicit floor to current set"). A --wait-default call that names sources watches those in place of the defaults
(the session thread, or the team channel and the owner DM), which it watches where it names none; the floor -- the replies to its posts,
its session chat, its DMs and tags, its mentions and its wake marker -- is added either way, and what the stored wait holds comes beside
it only where the call names no source of its own: a named set replaces the stored one, which is how a stale thread leaves it. An open
ask:<pending-id> is carried either way, its answer having no other watcher. A floor lives for a
source of the stored set alone and advances at every wait that watches it; the floor of a source that left the set is
dropped at the next write, and a source that comes back starts at the wait's start: what came in the gap is not replayed.
A closed ask leaves the stored wait: an answered one is carried by the one call that shows its closed note, then stored no more, and a
later reply in its thread reaches the asker as the session floor's (replies:, chat:), never as a CLARIFIED of the question.
The header says which session thread is on record for the session (`# session thread:`), or that none is.

RECEIVED on a thread source (slack:<channel>:<ts>, or its :conversation form)

also names the newest message it just printed:

    WAIT-LAST-TS: <ts>

Pass that ts back as the next call's --wait-since-utime to keep reading
forward without re-parsing the body for it. Absent on a bare conversation or
file source: neither prints one message per line, so neither has a single
ts this line could name.

SOURCE ADAPTERS -- the extension point.

A source is named `<kind>:<target>`. The kind selects a probe function by
name, `AgentsWaitProbe` + the kind with its first letter uppercased, and
$agentsWaitSourceKinds lists the kinds this build carries. Adding an input
source -- an IM bridge, a portal interaction feed, anything later -- is one
new function plus one word in that list. Nothing else in this operation, in
the Wait harness tool, or in the harness self-check knows a source kind.

The adapter contract is deliberately narrow:

    AgentsWaitProbe<Kind> <team-member> <target> <since-epoch> <render-file> <addressee>
        rc 0 -- <render-file> now holds this source's current state for
                <target>. An empty rendering is a legitimate state.
        rc 2 -- the probe could not run. <render-file> is not a rendering
                and is not compared against anything.

An adapter is never asked what "new" means: this operation decides that
generically, by comparing each rendering against the baseline it took at the
start of the wait. So an adapter needs no notion of cursors, read marks or
message identity -- only "render what is there now".

The third argument is a READ FLOOR, not that decision. It defaults to the wait's
own start time, and an adapter that can narrow server-side should render only
from it -- otherwise every poll re-renders a whole conversation to discover
nothing changed. An adapter that cannot narrow ignores it and renders the lot;
the baseline comparison above is unaffected either way.

The fifth argument is WHOSE ANSWER COUNTS -- the Slack accounts of the party a
question was addressed to, exactly as the send operation resolved and reported
them, so the send and the wait read one value rather than each deciding for
itself. An adapter that cannot tell one author from another ignores it. The slack
adapter does not ignore it: on a thread it is what makes a reply an answer,
together with our own message being the floor it must come after.

The sixth argument is INCLUDE OWN POSTS -- true on a :conversation thread source

lifts this operation's own default skip of the caller's own posts there. An
adapter with no such skip ignores it, same as an adapter that cannot tell one
author from another ignores the fifth.

Any number of sources and threads may share one wait. A plain thread source, the
question-and-answer form, takes the one --wait-since-utime and --wait-addressee the
call carries, so several of them share those values; the own-post skip and the
addressee keep the sending session's own post from coming back.

ITERATION DIVIDERS. $agentsWaitKindEvery says a kind is probed on every Nth poll
round (the first round always probes all), so a costly kind, a repository check later,
can be read less often than a session thread. 1 is every round.

THE TICK AND THE SLOW LOOK -- THE WAKE LATENCY. A duty session's routine promises it wakes "within seconds of an item
arriving in its inbox", and a poll cannot keep that promise with one interval for every source: an inbox is a
listing of a directory and costs nothing to read every second, a Slack conversation is a request out of a budget of
about fifty a minute for the whole app, so it cannot be. The wait therefore runs a ONE-SECOND TICK over the kinds it
reads out of files ($agentsWaitKindLocal: file, inbox, board, process, the session chat file, the replies, and the
own wake marker) and reads the costly kinds (slack, tagged, ask) on THE SLOW GAP instead -- the interval this
operation used to poll at, which still grows with the idle time of the sources (AgentsWaitBackoffNap), so no Slack
request is made more often than before. A scan keeps its own TTL of the table, and a wake marker brings its next
run forward (THE WAKE MARKER, and THE SCAN IS WOKEN AND NOT ON ITS TTL, below).

THE WAKE MARKER closes the one gap a tick cannot: a message one of our own members sends. The send operation
writes the recipient's marker the moment the message is posted (AgentsTools.WakeMarker.include) and the wait
reads it on its tick, so the arrival wakes the wait in about a second rather than at the next slow look of the
Slack source. The marker is no arrival of its own: the round that finds it changed takes it as read and reads
every source again at once, costly ones included, and returns what those find.

THE SCAN IS WOKEN AND NOT ON ITS TTL. A scan is the one source a duty's own arrivals are read from -- the inbox,
the tags, the board, in one report -- so a scan-only watcher that is left to the table's TTL of five minutes (or,
in a session, to the end of the wait round that precedes the next call's first look) is exactly the duty that
"reacts in five minutes or so". The marker brings the scan's next run forward with every other costly source, so
the item a message announces is in the report returned within about a second. The TTL stays what it is for: an
unchanged scan is still left alone for it, and the TTL is no floor on noticing a message.

WHY THAT DOES NOT MAKE A SCAN RUN EVERY SECOND. A scan is minutes of work (an inbox, the board, a Slack collect
window), and nothing here runs one on a tick: the marker is written by a send alone, one line per message, and
the round that finds it changed takes it as read -- its rendering becomes the baseline -- so one message buys at
most one extra run. Ten messages in an hour are ten scans, where a one-second tick would be three thousand six
hundred. A quiet wait runs no scan at all once its TTL has passed, exactly as before.

Not built, one probe away: repo:<name>, returning that repository HEAD through the
team git tooling. inbox:<member> is the own inbox only, board:<state> one board state.

THE FLOOR. A --wait-default or --wait-continue call, in a session, always waits on
replies:<session id>: the replies to the run's own posts, ahead of its other sources (AgentsWaitProbeReplies),
and, where the session has a folder, on chat:<session>: the messages of its session thread that are for the run,
read from the session chat file by the member's pointer (AgentsWaitProbeChat, AgentsTools.SessionChat.include).
A caller never names a channel, a thread or an addressee to get a reply, and the sources it names are
added to the floor, never put in its place. What a return carries is the floor first, then the messages of all
the other sources together in one group sorted by time, each behind the source it came from
(AgentsWaitArrivalsOrder.awk). The same floor goes with every tool return, from the same file and no network
(AgentsTranscriptReplyFloor), so a message is delivered once, by whichever reaches the member first.

ALSO CARRIED, for the tooling's own use and for the work-duty scan: scan:<scan> (a scan's report, run afresh past its TTL,
and at once on the round a wake marker announces a message -- THE SCAN IS WOKEN AND NOT ON ITS TTL),
tagged:<member> (what is for the member by name), wake:<member> (the marker a message to that member writes, read on the
tick, never returned -- see THE WAKE MARKER), and --wait-collect <seconds> (a window that returns, ahead of
its end, on an arrival of the tags). Their TTLs are AgentsWaitTtlOf's.

REMINDERS. A wait also reminds: the asks it stands for, still waiting on a person, on
their schedule (AgentsWaitRemind below, AgentsTools.PendingReplyRemind.include). It changes
nothing a wait returns, and what it did is said on stderr only.

~~~

- Above `agentsWaitSourceKinds="slack file inbox board ask replies chat scan tagged dms mentions process wake"`

~~~text
The kinds this build carries. One word per adapter, in the order they are
offered to a caller that asks.
~~~

- Above `agentsWaitKindLocal="file inbox board process chat replies wake"`

~~~text
THE TICK AND THE SLOW LOOK. A wait reads a source out of a file every second -- an inbox listing, a board
state, the session chat file, the own wake marker -- and that is what makes it wake within a second of an
arrival in one of them. A source that costs a request must not be read that often (about fifty a minute for
the app, shared by every host and session of it), so the kinds watched over the network are read on the slow
gap instead: the gap this operation used to poll at, five seconds growing by one for every twenty idle up to
five minutes, counted from the newest activity on the watched sources (AgentsWaitBackoffNap). A wait whose
caller names an interval (--wait-poll-interval, else MDAT_WAIT_POLL_SECONDS) keeps that one interval for
every source, as it always did: that is how a check drives it.
~~~

- Above `agentsWaitKindUnbounded="file inbox board process wake"`

~~~text
The same local kinds, minus chat and replies (S21.15): those two still make a real Slack network call on their own
TTL, so a probe past the caller's deadline needs the bound wrapper exactly as a true network kind does. Used only
by the bound-wrapper exemption below; the backoff-skip exemption above keeps agentsWaitKindLocal unchanged.
~~~

- Above `agentsWaitKindEmptyBaseline="ask replies chat scan tagged dms mentions"`

~~~text
Kinds whose rendering holds arrivals only, never a standing state, so a source of one with no
stored baseline starts from an empty one: an arrival already there returns at once, as a
--wait-since-utime does for a thread. Every other kind takes its first probe as the baseline.
~~~

- Above `agentsWaitKindArrivalsOnly="inbox"`

~~~text
Kinds whose rendering is a list of arrivals from a floor, so only a line the baseline lacks
is an arrival: an item taken away (an inbox item marked handled, moved out of incoming/) is none.
~~~

- Above `agentsWaitFloorAhead=300`

~~~text
How far a floor (--wait-since-utime) may lead this host's clock, in seconds. The ts of a
message just posted is another clock's "now", so a floor that close ahead is still a
moment that has passed; one further ahead is not, and is refused before anything is waited on.
~~~

- Above `AgentsWaitProbedFlush{`

~~~text
THE STATE OF A WAIT, stored: its sources, addressee, include-own, modes and floors (the newest ts returned for a slack source), the baselines of the rest. Run in the wait's own
scope (its locals are the caller's) once BEFORE the result is said, so a result that was emitted has its floors committed whatever becomes of the caller after it (a client that
moves the call to the background or interrupts it), and again at the end. rc 1 where the state cannot be written.
Writes the check times of this wait's costly sources to the session's `probed`, one line a source, where any changed since the last
write. Run in the wait's own scope.
~~~

- Above `AgentsWaitActivityIdle{ ## the sources of the wait, as they stand after the floor is added`

~~~text
A WAIT ON ITS FLOOR ALONE IS IDLE (S27.4). The harness marks a Wait call `tool Wait`, which the registry reads as `waiting`. Where every source of
the wait is the floor (replies, chat, dms, mentions, wake, the scans, the session's own threads, or the two team conversations of a run with no
thread), the run is idle: the mark is rewritten, in the round it holds, as `idle`, which the registry reads as `idling`. A mark that is not
`tool Wait`, and a run with no mark (a native client's), is left alone. The harness writes `thinking` again when the run's next round begins.
~~~

- Above `local waitKeepList waitKeepAt waitKeepCount=0 storeIndex=0 storeAsk="" storeSource`

~~~text
WHAT IS STORED IS WHAT IS STILL OPEN. A closed ask leaves the stored wait (): its record is closed, so

nothing it watches can still answer it. The one call that shows its closed note carries it (AgentsWaitProbeAsk), and this write
is that call's own, so it is stored no more. A kept source keeps its base and floor files at the place it takes in the STORED
list, which is the place the next call reads them by, so the place it had in this call's round is kept beside it (waitKeepAt).
~~~

- Above `case " $waitNamedSources " in *" $storeSource "*);; *) continue;; esac`

~~~text
A closed ask the caller NAMED is stored with its own base, so a later call naming it again stays quiet
(AgentsWaitAskBaselineCarryCheck); one carried out of the stored set leaves the list here.
~~~

- Above `AgentsWaitAddressConv{ ## member, source`

~~~text
The conversation a message's reply address is built in (AgentsWaitReplyAddress.awk), for a source whose own name is
not one: a bare channel id, or an alias such as `magic-team` resolved to its channel. Empty where the source names
none -- a file, a process, a board -- and the address pass then invents nothing.
~~~

- Above `AgentsWaitSeenIds{ ## member, source, the rendering file, the member's own Slack id`

~~~text
The ids (`<conversation>:<ts>`) of the messages a person wrote in the rendering of one source that a wait returned: the conversation is the one the source names, or the
one the rendering names before its messages (`# in <conversation>`, `# replies to your post <conversation>:<ts>`); a source that names a team channel or the owner by
name is resolved. The member's own and anything that is not a user id are left out.
~~~

- Above `AgentsWaitTtlOwn{ ## source`

~~~text
THE FORM OF A SOURCE THE CALLER ADDS (F3.3, Settled). Short or full is the caller's choice when it adds the source, written after it,
`slack:magic-team#short` or `slack:magic-team#full`. SHORT returns each message cut to a short form with its own reference, <source>:<ts>,
and, once in the return, the line that says how to read one in full (--slack-read <member> <source>:<ts> --thread, the
operation the agent has); it keeps only that short form, so a large message is copied nowhere. FULL returns every message whole; a single message too long for the return, over F2.4's threshold,
is kept as a file of its own in the session's folder and the return carries a preview and a reference (the preview of F2.4), and no file is
made for any other. Either way the source's index cache file, sessions/<session>/sources/<source>.md, keeps a line for each message once,
the short form, the whole message's first words, or the preview with its file. A source with neither is returned whole, as it always was. The
form is kept in the stored wait (`mode <source> <form>`) and goes with the source. A long return follows F2.4 as every result does.
Prints the form of a source, nothing for none.
The TTL a caller gave a source (#ttl=<seconds>, --wait-source-ttl), nothing for none: the table's then holds (AgentsWaitTtlOf).
~~~

- Above `AgentsWaitProbeFunctionName{`

~~~text
`slack` -> `AgentsWaitProbeSlack`, without ${var^} -- bash 3.2 has no such
expansion, and this package targets it.
The probe function of a source kind, by a case: the cut and tr it replaces cost three
processes a call, and this is read once per source per tick. A kind the list does not
name keeps the generic form, which is right for one this file never met.
~~~

- Above `AgentsWaitSameFile{ ## a, b`

~~~text
Two renderings hold the same bytes -- rc 0 when they do. A builtin read either side, in
place of a cmp process a tick.
~~~

- Above `AgentsWaitCopy{ ## from, to`

~~~text
A file copied only where the copy differs from it, and an empty one made only where it is not empty already: a quiet call
writes no baseline. rc as cp's.
~~~

- Above `AgentsWaitNewestActivity{ ## call start (epoch), session id, sources, floors used ("<source>=<ts>...")`

~~~text
THE BACKOFF IS MEASURED FROM THE NEWEST ACTIVITY on what a wait watches, never from
when the call started alone: in a long call, a question asked an hour in must still be
watched closely. The newest of: the call start; the floor of each Slack source (the last
message a wait returned there, or the since given); each watched question's own ts and
follow floor; and the session's own latest post (last-own-post), where a watched source
would carry its reply -- that thread, an ask's thread, or a whole conversation. Prints
"<epoch seconds>\t<what>", <what> one of start, floor, question, own-post.
~~~

- Above `AgentsWaitBackoffNap{ ## now (epoch), newest activity (epoch)`

~~~text
One nap of the default backoff, in seconds: 5, plus 1 for every 20 since the newest
activity, capped at 300 -- the formula and cap as ever, only its base is the activity.
~~~

- Above `AgentsWaitRemind{ ## session id (may be empty), sources, the wait's working directory`

~~~text
THE REMINDERS OF A WAIT. An ask still waiting on a person is reminded on its schedule
(30 minutes, 2 hours, then daily: AgentsTools.PendingReplyRemind.include) by the wait that
stands for it, so it is reminded while a member waits and no main loop runs: the asks the
wait watches (its ask:<pending-id> sources) and every open ask of its coworking session,
whoever of that session asked it. The record's own stamps make a repeat send nothing, so
this and the main loop's run send one reminder for a stage. A wait that reads a thread
for a reminder run (agentsPendingReplyRemindRunning, set by that run) starts none itself.
In a subshell, and it fails nothing here: what a run did is said on stderr, each line once
a call, and a run that could not start is said there too. MDAT_WAIT_REMIND=off switches
it off for a call: the test runner sets it for every test (sh-test/AgentsRunTests.sh).
~~~

- Above `` AgentsWaitFolderSweep{ ## member -- keeps this shell's own `<pid> <start>` for the record (agentsWaitFolderShell) ``

~~~text
THE WORKING DIRECTORY OF A WAIT, AND WHOSE IT IS. Every wait makes one of its own (mktemp,
below) and removes it as it ends, and nothing else removes it while that wait lives. A wait
that was killed leaves its directory behind, so the next wait of that member sweeps on its
way in: by whose a directory is, never by how old it looks. A directory holds `owner`, the
host and the process its wait runs in with when that process began, as the one reading of
that gives it (AgentsToolsRunProcessesBegan), and it goes only once that process is no
process of this host any more; the same pid begun at another time is another process. So a
wait that stands for days keeps its directory, and so do several waits of one member at
once, in as many sessions. A directory another host made is never touched, and none is
while the process list cannot be read: this shell is a process, and a reading that does not
hold it read nothing. One with no whole record was made before records were kept, or is
being made this instant: it goes once it stood a day untouched, its age taken from its own
modification time and compared here, never by a -mtime of find, which one find rounds up
to whole days and another down.
A directory its wait kept for whoever looks into it (`kept`, AgentsWaitLost below) stands that
same day, whoever owned it.
~~~

- Above `AgentsWaitFolderEnd{`

~~~text
The record the sweep reads, written by the wait into the directory it just made. A shell the
process list did not give keeps no process there: its directory is then one with no whole record.
The end of a Wait's folder: a kept one only lets its hold go, one of its own under .local/temp goes whole. Run in the wait's scope.

~~~

- Above `:`

~~~text
A probe detached at the bound (S20, S21.11) still writes into this directory: it
outlives this call, and is the detached task's own problem to clean up once it ends.
~~~

- Above `--wait-for-input|--intern-op-wait-for-input)`

~~~text
The member stub and its implementation, one arm. A wait reads and reacts under the named member's own credentials, so
a spawned session names only itself; tooling calls --intern-op-wait-for-input directly.
~~~

- Above `if [ -n "${MDAT_SPAWN_SESSION_ID:-}" ] && LC_ALL=C grep -q -s '^routine-lock: ' "${MMDAPP%/}"/.local/agents/spawned/*/"$MDAT_SPAWN_SESSION_ID.spawn.md" 2> /dev/null; then`

~~~text
A run that holds the lock of its routine keeps it held while it waits (AgentsToolsRoutineLockRefreshOwn): the record of the run is looked at first,
and the lock code loaded only for a run that holds one.
~~~

- Above `--unwait)`

~~~text
One flag, its source inline -- the named shorthand for --wait-drop --wait-source
<source>, nothing more. Dropping from the stored set is not blocking it: naming
the same source again, explicitly, on a later call is unaffected by this.
~~~

- Above `local sourceSpec="$2" sourceTail sourceTtl="$waitTtlNext" sourceMode=""`

~~~text
A source the caller adds may end in #short or #full, chosen when it is added (F3.3, AgentsWaitSourceModeApply), and in
#ttl=<seconds>, its own TTL (); --wait-source-ttl before it gives the same. Either, both or neither.

~~~

- Above `waitAddressee="$waitAddressee$2 "`

~~~text
Resolved ids only, never a name: the send resolves a name once and reports
what it resolved, and a second resolution here could disagree with the
party the message was actually addressed to.
~~~

- Above `--wait-collect)`

~~~text
A COLLECT (F4.1): a wait of a window of seconds that returns, ahead of it, on an immediate arrival -- the tags
(tagged:<member>) are immediate, every other source collects until the window ends. See AgentsWaitCollectFloors.
~~~

#### `AgentsTools.MemberWaitRun.include`

- The head of the file

~~~text

AgentsTools.MemberWaitRun.include -- the wait itself: its directory, its floors, the rounds of probes.
The next part of the --wait-for-input arm of AgentsTools.MemberWait.include, dot-sourced inside that arm: it shares
its locals and its arguments, and ends by dot-sourcing the next part and returning its status.

~~~

- Above `local waitDir waitDirWhy="" agentsWaitLost=""`

~~~text
mktemp, never `$$`: this operation is a shell function inside a long-lived
process, so every call in that process shares one PID. Two concurrent waits
by one member then share a directory, and the first to finish removes the
other's state mid-poll -- which surfaces as a missing base file, not as the
collision it is. Coworking makes concurrent waits the normal case.
~~~

- Above `AgentsWaitFolderSweep "$memberName"`

~~~text
A unique name per call means an interrupted wait no longer has its directory
overwritten by the next one, so they accumulate instead. An EXIT trap cannot
clean up here -- this is a shell function inside a long-lived process, and its
trap would silently replace the caller's -- so stale ones are swept on the way
in. This member's own, and only those whose wait is proven gone (AgentsWaitFolderSweep).
~~~

- Above `local waitDirKept="" waitSeenBefore=""`

~~~text
What mktemp says of a failure is kept and said: the wait then ends on one line, never on a
name that is no directory. A directory its record cannot be written into holds no rendering either.
ONE WORKING FOLDER A MEMBER KEEPS IN ITS SESSION, across its Waits (): sessions/<id>/wait/work.<member>,

held by one Wait at a time (.held, its owner a live process). A quiet first round then finds its files as the last Wait
left them, and the keys of what it read in seen.txt, so it writes nothing. A Wait with no session, or one that finds the
folder held, takes one of its own under .local/temp, as before.

~~~

- Above `local waitBaselineMode="first-probe"`

~~~text
With a cut-off named, the caller is waiting on something at or after a
moment it already knows -- so the first probe is EVALUATED against an
empty baseline, and a reply already sitting there returns immediately.
With no cut-off, "new" can only mean "different from now", so the first
probe is the baseline and the wait starts from it.
~~~

- Above `waitSecs0=$SECONDS`

~~~text
The one clock of this wait: every later round reads the shell's own second count from
here, so a quiet tick costs no date process at all.
~~~

- Above `local waitReadFloor="${waitSince:-$waitStart}"`

~~~text
What a probe READS from, which is not what the baseline is taken against.
With no cut-off named, a source that can narrow reads from this wait's own
start: measured at 142s per round otherwise -- 40s for one channel and 102s
for a DM -- because each round re-renders the whole conversation only to
diff it and find nothing. At that cost a 15s interval means nothing and a
reply lands a minute or more late. A probe that cannot narrow ignores this,
so the file adapter keeps comparing whole renderings and a file already
sitting there still does not count as an arrival.
~~~

- Above `local waitFloorOf= waitFloorNew= waitFloorsUsed="" floorIndex=0 floorStored floorStoredIndex floorStoredSource`

~~~text
One floor per source. LOSSLESS: a stored floor is never dropped. Without an explicit
since it is the floor; with one, a plain question thread takes the since (its own
question is the root an answer must follow), and any other Slack source takes the
OLDER of the two, so a since newer than the stored floor -- the ts of a reply the
caller posted after the last wait returned -- cannot skip what landed in between.
With neither, a :conversation thread starts at the session's own last post in

that thread, else at the spawn's launch, and every other source at the wait's start.
Every Slack source's baseline is empty: its rendering holds only what is after its
floor, so whatever is there is new, including a post made before the first read.
A continued wait, and a default one over a source the stored wait already had,
also start a non-Slack source from its stored baseline.
~~~

- Above `local collectKey="" collectStored`

~~~text
A COLLECT resumes each Slack source and the tags from the pointer the session kept for it, the last message of
it a collect returned (AgentsToolsSessionChatPointer, `collect:<member>:<source>`): it has no stored wait to keep
floors in. A source with none starts at the wait's start, as every source does.
~~~

- Above `local convFloorCandidate=""`

~~~text
THE OLDER OF THE TWO IS THE FLOOR: a message that landed before the member's own last post
still has to arrive, so the spawn's launch is taken where it is older than that post.
~~~

- Above `case "$checkSource" in`

~~~text
An inbox renders from its floor (AgentsWaitProbeInbox): continued, from when the
stored wait ended, so what came between the two calls is rendered, and is new.
~~~

- Above `floorStoredIndex=0`

~~~text
since_utime is a Slack-source floor (AgentsWaitTsNewer, above); it names no
opinion about a non-Slack source's own stored content baseline, so carrying
a held source's baseline forward here does not wait on it being empty. A
default wait naming since_utime must still start an ask:/file:/inbox:/board:
source already in waitStoredSources from what it last held, or the same
unchanging content -- an ask: record's own closed-line among it -- reads as
arriving fresh on every call that also names a since_utime.
~~~

- Above `local waitProbedFile="" probedSource probedAt probedIndex=0`

~~~text
THE TTL HOLDS ACROSS WAITS (sketch 3.2, sources of different frequencies): a source with a TTL is checked at a round, the first
included, only once its TTL has passed since its last check by any Wait of the session (`probed` beside the stored wait).
~~~

- Above `local waitRoundFn= waitRoundIndex=0 waitRoundSource`

~~~text
The probe function of each source, resolved once: it cannot change while this wait
runs, and reading it per tick cost a subshell and three processes a source.
~~~

- Above `local waitCacheTtl=1`

~~~text
THE AGE A SLACK LOOK IS SERVED AT (: Slack is read through the comms cache, so a Wait never

re-reads Slack itself). A thread the cache holds is served; one second past its newest pull it brings in only what
came after and merges that in, so a round asks Slack for nothing an earlier pull already covers. Reading the thread
whole instead cannot end inside a bound its caller gives: a 258-message thread renders in 145 s here, so the round is
detached at the bound and the source falls into WAIT-NEVER-READ (AgentsWaitThreadCacheCheck). A caller that turned the
cache off, with 0, keeps the read it asked for. The burst settle is the same look, after the return.
~~~

- Above `case "$waitCallerPid" in`

~~~text
A CALLER THAT IS GONE TAKES ITS WAIT WITH IT. Signal 0 asks whether the process that
started this shell is still there: a builtin, so the check starts nothing. A pid of 1
is that process already gone. Neither spins nor forks, so it is read every round.
~~~

- Above `case "$roundKind" in`

~~~text
THE TTL of the source (AgentsWaitTtlOf): while its previous check, by this Wait or an earlier one of the session, is
inside it, the source is skipped on this pass, the first included. A source skipped so was checked within its TTL:
it is not one never read.
~~~

- Above `if [ "$waitBackoff" = "true" ]; then`

~~~text
THE TICK AND THE SLOW LOOK: a local source is read every tick, a costly one only once the slow gap has
passed -- the gap that was the wait's own poll before, from the same activity, so the requests the
team's Slack budget pays for are no more than they were. Read once, and only when a costly source is
actually due, so a quiet tick over local files spends nothing on the activity reading either.
Round 1 included: a costly source the last Wait of the session read within its gap is not read again (sketch 3.2).
~~~

- Above `if [ "$roundKind" = "slack" ]; then`

~~~text
A named Slack source has its own TTL floor too (AgentsTools.SourceTtl.include), the same
round-1-included skip as tagged, mentions and dms above, kept inside this backoff-only
branch: a caller naming its own --wait-poll-interval still reads every round.
~~~

- Above `roundQuietFrom="${waitFloorOf[$roundIndex]%%.*}"`

~~~text
BACKED OFF while the source brings nothing (): from its TTL to twenty times it, reached after two

hundred times the TTL since its floor -- the newest it returned, or its since -- kept by the session across Waits.
~~~

- Above `if [ $((roundNow - ${waitProbedAt[$roundIndex]:-0})) -lt "$roundSlowGap" ]; then`

~~~text
A source skipped so was read within its own slow gap, by this Wait or an earlier one of the session: it is not
one never read, as the TTL skips above say of their own.
~~~

- Above `if [ "$roundKind" = "scan" ] && { [ "$waitOutcome" = "RECEIVED" ] || { [ -n "$waitDeadline" ] && [ "$roundNow" -lt "$waitDeadline" ] && [ $((waitStart + SECONDS - waitSecs0)) -ge "$waitDeadline" ]; }; }; then`

~~~text
A ROUND READS EVERY SOURCE IT HOLDS (). An arrival already in hand is returned once the round has

read the rest of them, and a probe that cannot finish inside the bound is handed to the task wrapper as it always is
(roundProbeTimeout). A source the round could not read -- a probe that failed, or a scan not begun -- shows in WAIT-NEVER-READ.
A scan takes minutes, so one that has not begun is not begun once something has arrived in this round (the arrival wakes
the caller, and the scan is read at the next wait, its report being compared with the one last given), nor once the
bound has passed in it. It then shows in WAIT-NEVER-READ.
~~~

- Above `if [ -n "$waitProbedFile" ]; then`

~~~text
Its check is kept for the next Wait of the session: written with the others at most every 30 s, and when the wait
stores its state (AgentsWaitProbedFlush), so a probe writes no file of its own.
~~~

- Above `roundStaleOk=""`

~~~text
A ROUND TAKES THE CACHE'S LOOK, which pulls what arrived since its newest pull (waitCacheTtl above).
A round with under two seconds left, too little for the probe wrapper to do anything, is served what
the cache holds at once, and the comms thread fills it (MDAT_COMMS_CACHE_STALE_OK,
AgentsTools.CommsCache.include).
~~~

- Above `roundProbeTimeout=""`

~~~text
A PROBE PAST THE BOUND IS NEVER CUT SHORT, BUT IT NO LONGER HOLDS THE CALL (S20, S21.11): a costly probe,
with the caller's own deadline in sight, is handed to the task wrapper on the deadline's own remaining
seconds (AgentsTools.ToolTask.include). One still running at it returns early as a task, the rest of
this wait ending on it, never silently past the bound it was given. A local probe never stalls on the
network, so it keeps running here, unwrapped, as it always did.
~~~

- Above `case " $agentsWaitKindUnbounded " in`

~~~text
chat and replies are excluded here (S21.15, agentsWaitKindUnbounded above): each makes a real Slack
call on its own TTL and must not be exempt from the bound wrapper the way a genuinely local kind is.
~~~

- Above `*) [ -z "$waitDeadline" ] || [ "${waitTimeout:-0}" = "0" ] || roundProbeTimeout=$((waitDeadline - roundNow));;`

~~~text
A ZERO BOUND IS ONE PASS AND NO WAIT: the round is the whole call, so the probe is read in line and
finishes. Wrapped on the bound's own remaining seconds it gets one second, overruns, and the call
ends on a detached probe with nothing to return.
~~~

- Above `case "$roundProbeTimeout" in`

~~~text
A WRAPPER IS NEVER GIVEN THE LAST SECOND (: a round reads every source it

holds). Its own start -- a process, its includes and its files -- costs about a second, so a probe
wrapped on less has no time to read, detaches, and its arrival is lost: the call says TIMEOUT and
names a source never read for a message already there (AgentsWaitSourceModeCheck, section 4).
Below two seconds the wrapper is worth nothing, and the round reads that source in line instead.
~~~

- Above `MDAT_COMMS_CACHE_STALE_OK="$roundStaleOk" MDAT_SLACK_THREAD_CACHE_SECONDS="$waitCacheTtl" \`

~~~text
AgentsToolsTaskCall keeps its own processes under a SESSION it reads from
harnessSessionId/MDAT_SPAWN_SESSION_ID/CLAUDE_CODE_SESSION_ID (a harness's own run) --
none of which a plain --wait-for-input call sets. With none of them, it runs the probe
in-line with no bound at all (S21.11, load incident: Waits measured overshooting by
158-483s). This wait's own session id, already known here, fills that gap: a harness's
own id, where this runs inside one, is never overridden.
~~~

- Above `waitDetachedTask="$agentsTaskHandle ($roundSource)"`

~~~text
A DETACHED PROBE ENDS NO ROUND (S21.6, settled 2026-10-31 and again 2026-11-02). The probe itself is named,
as the earlier ruling says: one past the bound is a source this round did not read. The round then goes
on to its remaining sources, as S21.6 says, instead of naming every one of them unread with it.
~~~

- Above `if [ "$roundRc" = "4" ]; then`

~~~text
A source that cannot be read for want of a permission is an error of its own, said in the header, and no source never
read: what the member is denied is known, so it never stands for an unknown (rc 4, its reason in the rendering's .permission).

~~~

- Above `case "$waitProbeFailures" in`

~~~text
A probe that cannot run is reported, and the wait carries on
over the sources that can: one unreachable source must not
turn a multi-source wait into silence.
~~~

- Above `if [ "$roundKind" = "wake" ]; then`

~~~text
THE WAKE MARKER IS NO ARRIVAL OF ITS OWN (AgentsTools.WakeMarker.include). One of our own members
posted a message to this one, and what the marker says is not what a member is to read. So it is
taken as read -- its rendering becomes its baseline -- and every source is read again at once,
the costly kinds included, so that the message itself is returned by this call in about a second
instead of at the next slow look. The marker is read at every tick, so this costs no request.
~~~

- Above `if ! AgentsWaitSameFile "$waitDir/base.$roundIndex" "$waitDir/now.$roundIndex" \`

~~~text
Every source is scanned, and every one that changed is returned, not the first.
A kind whose rendering holds arrivals only has nothing to return while that rendering
is empty: what stood there was taken -- an answer its asker read moves the floor of
its thread past it -- or taken back, and neither is an arrival.
A Slack source that renders empty has nothing to return either: its floor moved past what stood there.
The run's own posts arrive on a rendered message or a reaction, never on the heading alone.
~~~

- Above `[ -n "$waitDeadline" ] || [ -n "$waitReadSources" ] || break`

~~~text
Unbounded, a first round that could read no source at all returns at once rather
than wait forever on sources nothing is known about: TIMEOUT with WAIT-NEVER-READ.
~~~

- Above `if [ -n "$waitWakeSeen" ]; then`

~~~text
THE MARKER WAS WRITTEN: read every source again now, the costly kinds included, and do not sleep
first -- that immediate re-read is the whole point of the marker. THE SCANS COME FORWARD WITH THE
REST: a scan is where a duty's own arrivals are read from, and without this a message waits for the
table's 300s (or for the end of the session's wait round, whichever comes first) -- the five minutes
the owner reported. THE COST IS BOUNDED BY THE MESSAGES, NOT BY THE TICK: the marker is written by a
send alone, one line per message, and the round that reads it takes it as read (its rendering becomes
its baseline), so a message buys at most one extra run -- a scan of minutes, once per message, where
a tick would run it sixty times a minute. An unchanged scan is still left to its TTL, which is what
the TTL is for.
~~~

- Above `if [ "$waitNow" -ge "$waitRemindNext" ]; then`

~~~text
The asks this wait stands for are reminded from here (AgentsWaitRemind): after a
round that brought nothing, and at most once a minute.
~~~

- Above `waitNap="$waitPoll"`

~~~text
THE NAP IS THE TICK. A local source was read this round and is read again in a second; a costly one
waits for its own slow gap, which the round gate above holds it to, so no read of the team's Slack
budget is made more often than before. A caller's own interval (waitBackoff false) is the nap, as it
always was.
THE NAP STARTS NO PROCESS (S12.7). It is `read -t` on a fifo the wait holds both ends of, descriptor 6,
and not a `sleep`: a sleep a tick is a fork a tick, and an idle run waits for hours. Measured on this
estate, one file source, 15 further poll rounds: 1.00 processes a round before, 0.00 after; the whole
21-second call spent 0.51 s of CPU before and 0.35 s after. The fifo is made in the wait's own folder
and the descriptor is closed before the result is written. A wait that cannot make the fifo falls back
to `sleep`, so a read-only temp folder costs the old one fork a round and nothing more. The read
returns 1 when it waited out its time, as `sleep` returns 0: the guard `|| :` carries that, or `set -e`

ends the wait at its first quiet second. A read of 300 seconds is woken by TERM as promptly as a sleep
is (measured on bash 3.2.57), so a wait is still ended the way it was.
~~~

#### `AgentsTools.MemberWaitSources.include`

- The head of the file

~~~text

AgentsTools.MemberWaitSources.include -- the sources of a wait: what it can wait on, the stored wait, the defaults, the checks, and the modes that wait on nothing.
The next part of the --wait-for-input arm of AgentsTools.MemberWait.include, dot-sourced inside that arm: it shares
its locals and its arguments, and ends by dot-sourcing the next part and returning its status.

~~~

- Above `if [ "$waitListOnly" = "true" ]; then`

~~~text
Asked what it can wait on, it answers and waits on nothing. This is the
extension point made observable: whatever this prints is what a caller
may name, with no second list to keep in step.
~~~

- Above `local sessionSource sessionSources="" sessionResolved="" sessionRc=0 sessionAddress="" sessionForm="" sessionOriginal=""`

~~~text
slack:session-current and slack:session-parent each name that session's thread, as the Wait tool
takes them: the one address resolver gives the thread, and it is waited on as its :conversation

source, before anything below checks or stores a source. With :<ts> the name is one message in

that thread's conversation, and the source is the thread of that message: plain for an answer
to it, with :conversation for any new post there. A name that names nowhere is refused by the

resolver's own line.
~~~

- Above `if [ -n "${MDAT_SPAWN_LAUNCH_MARKER:-}" ] && [ -f "$MDAT_SPAWN_LAUNCH_MARKER" ]; then`

~~~text
When this spawn launched: the launcher's own marker file, written once at launch.
The floor of a session or conversation thread with no stored floor and no own post.
~~~

- Above `if [ -z "$waitSources" ]; then`

~~~text
Defaults. A caller inside a coworking session defaults to that session's
own thread, any post but its own -- the common "tell me when this session
moves" case. One shared by every entry point that reaches this operation,
harness and MCP twin alike, since the default lives here and not above it.
Absent a session thread, the two team conversations every member already
watches: the common "tell me when anyone says anything to me" case.
A NAMED SET IS THE WAIT'S OWN SET (sketch 3.2: "either OWN set / either adding OWN implicit floor to current set"): the sources a
call names replace the defaults, and the floor below is added to them whatever is named. The defaults stand only where nothing is.
~~~

- Above `else`

~~~text
A thread source needs a floor. With no explicit one it is the floor
stored for this source, else the session's own last post there, else
the wait's start -- set per source below, never a fresh "now" that
would skip what arrived since the last wait.
~~~

- Above `local defaultOwnThread=""`

~~~text
A session that is itself the coworking session -- a native client session, never
spawned -- has no thread of a spawn, so it watches these two as it always has, and
beside them its own session thread once that is on record, as any new post there
but its own (AgentsToolsSessionCurrentThreadFind). With no record, these two alone.
~~~

- Above `if [ "$waitMode" = "default" ] && [ -n "$waitStoredSources" ]; then`

~~~text
An asked question's wait item (ask:<pending-id>) is carried while its record is OPEN, a named set included: its answer has no
other watcher. A CLOSED one leaves the stored wait at the next write (AgentsWaitStateStore), which is the write of the one call
that shows its closed note (). A later reply in that thread reaches the asker as the session floor's,

replies: or chat:, never as a CLARIFIED of the question.
The rest of the stored set is carried by a call that names NO source of its own: a named set REPLACES the stored one (owner
ruling 2026-10-31), which is how a stale thread leaves the wait it was stored in.
~~~

- Above `[ ! -f "${carryRecord%.md}.closed-delivered" ] || continue`

~~~text
Closed for good once its note has been shown once (S21.6): the record
itself is retained forever (T9), so its mere existence carries this
forward with no end otherwise.
~~~

- Above `if [ -n "$waitSessionId" ] && { [ "$waitMode" = "default" ] || [ "$waitMode" = "continue" ]; }; then`

~~~text
THE FLOOR (sketch 12.1). A session's wait -- a default or a continued one -- holds its one session thread, read from the
session chat file (chat:), ahead of the rest: an agent never chooses a channel or a thread to get a reply, and the sources
it names are added to the floor, never put in its place. The per-post replies (AgentsWaitProbeReplies) stand in only for a
run with no session folder, so no chat file. What a named source reads is left to that source (AgentsWaitCoveredSet).
~~~

- Above `local floorOwnElsewhere="" floorOwnLine floorOwnThread=""`

~~~text
THE CHAT FILE IS NO SUBSTITUTE FOR THE REPLIES (ruling, 2026-10-31): the chat file is the session thread
alone, so a reply in the thread of one of the run's own posts ELSEWHERE is the replies source's. A run
with no such post keeps the chat file alone, which is one read instead of two.
~~~

- Above `local floorWays="dms:$memberName" floorWay`

~~~text
And every other way a person may reach the member, never dropped by what a call names (sketch 3.2): its DMs (dms:, the user's
and the bot's), its mentions anywhere (mentions:, not for a client-* member, whose account is the other organisation's) and its
wake marker (wake:), each on its own TTL. Read after what the call names (and before the scans, which go last), so a costly
check of them never holds back the read of a named source in a round.
~~~

- Above `if [ -n "$waitSessionId" ] && { [ "$waitMode" = "default" ] || [ "$waitMode" = "continue" ]; }; then`

~~~text
THE SCANS ARE READ LAST. A scan is the one source whose read takes minutes (the work-duty scan runs the inbox, the owner's
items, the board and a collect window), so a source that follows it in a round is read when the scan has ended. Every other
source keeps its order. This is an order within the call: a stored wait read back by `continue` is ordered the same way.
~~~

- Above `local waitBackoff="false" waitActivity="" waitWakeSeen=""`

~~~text
THE RETURN BOUND. No --wait-timeout is no bound: the wait returns on an arrival and on
nothing else, so an idle caller spends no round per quiet interval. A caller that must
return by a deadline (an MCP client cutoff, a zero-bound read) names one.
A round reads every source it holds, whatever the bound: the bound decides when the wait returns, never which sources it reads.
THE POLL CADENCE is separate and only decides how soon an arrival is noticed. IT IS A TICK AND A
SLOW LOOK (see agentsWaitKindLocal above): a source read out of a file is read every second, so an
item arriving in an inbox, a board state, the session chat file or the own wake marker wakes the
caller within about a second, and a source read over the network is read on the slow gap -- five
seconds growing by one for every twenty idle, capped at five minutes, counted from the newest
activity on the watched sources (AgentsWaitNewestActivity) rather than from the call start alone.
A given interval (--wait-poll-interval, else MDAT_WAIT_POLL_SECONDS) stays fixed for every source,
as it always did.
~~~

- Above `if [ -n "$waitSessionId" ]; then`

~~~text
THE ROUND OF A SESSION'S WAIT. A wait that belongs to a session -- a mode, with its
session id -- comes back, when nothing arrived, a little sooner than the prompt cache
of the CLI service that session runs on expires, so the turn that goes on waiting
reads the session's history from that cache. Its bound is at most that service's round
(AgentsTools.CliService.include), whatever bound the call names, and that round where
it names none. A wait of no session keeps the bound it was given, or none.
~~~

- Above `''|.*|*.|*[!0-9.]*|*.*.*)`

~~~text
A Slack message ts is epoch seconds with microseconds, and is the value a
caller passes when it is waiting on what follows a message it posted -- the
same <epoch>[.<micros>] shape --oldest already takes on the read side.
~~~

- Above `local waitSinceNow`

~~~text
A FLOOR IS A MOMENT THAT HAS PASSED. Nothing at or before it counts, so a wait from
a floor ahead of the present returns on nothing until that moment comes, whatever
arrives meanwhile: for the length of its bound, and through every --wait-continue
after it, which resumes from the floor stored. Refused at second zero, like a kind
this build does not carry, with both moments named.
~~~

- Above `local checkSource checkKind checkTarget checkFn`

~~~text
Every source is resolved to its probe BEFORE the wait starts. A kind
this build does not carry is a stated error at second zero, never a
source that silently never fires for the length of the bound.
~~~

- Above `process:*)`

~~~text
A detached process is one this session started with Bash detach true; the handle
is a bare name, and its output is read from this session's own processes folder.
~~~

- Above `ask:*)`

~~~text
An asked question's record must exist, and only the session that asked may wait on it,
the rule AskQuestion's own pending_id re-wait keeps. Not checked on a drop, which
must still take out an item whose record was since removed. A permission set is
asked once for all its participants, so each of them may wait on its answer too,
whichever session asked: the members its own record names (`<id>.set`, participants).
~~~

- Above `checkAskRecord="$MMDAPP/.local/agents/pending/$checkTarget.md"`

~~~text
A record closed since it was asked is retired to pending/closed/ (retention, T9),
its sidecars with it: resolved there too, as AgentsWaitProbeAsk does, so the
session that asked can still wait on the question it asked.
~~~

- Above `if [ "$waitMode" = "add" ] || [ "$waitMode" = "drop" ]; then`

~~~text
--wait-add and --wait-drop change the stored wait's source list and wait on nothing. A
source keeps its floor line and its base.<position> file, renumbered when one before
it is dropped; an added source starts with no base, so its first wait reads it afresh.
~~~

- Above `local checkThreads=0 checkConversation=0 checkUnfloored=0`

~~~text
Settled before the wait starts and not discovered in its result. A thread source
is a question waiting on its own answer, and an answer is qualified by the
message it came after and the party it came from. A thread source missing
either of those is refused here rather than waited on.
`slack:<channel>:<ts>:conversation` is the "any new post" thread mode:
no addressee, sibling to today's named `slack:magic-team` etc. targets.
~~~

- Above `if [ "$checkUnfloored" -gt 0 ] && [ -z "$waitSince" ] && [ "$waitMode" != "continue" ] && [ "$waitMode" != "close" ]; then`

~~~text
A continued or closed wait has its floors stored, so no since is asked for. A
:conversation thread with no since takes its stored floor, the session's own last
post there, or the wait's start (below), any of which is a floor.
~~~

- Above `if [ "$waitIncludeOwn" = "true" ] && [ "$checkConversation" = "0" ]; then`

~~~text
--wait-include-own only changes anything on a:conversation thread source,
the one place this operation skips the caller's own posts by default (see
AgentsSlackThreadAnswers.awk). Everywhere else already includes them, so the
flag would be a silent no-op there -- refused instead, same shape as the
--wait-addressee mismatch checks above.
~~~

## 16. Team data, board and inbox

- **A session in a just-agents workspace files team data with `MMDAPP` at its team rig.** The gate
  (`AgentsTools.TeamDataGate.include`) asks the mode of the workspace the call runs in, while the store is
  the one `MDAT_DATA_ROOT` names: run the item operation with `MMDAPP` at the team rig, and unset
  `MDAT_DATA_ROOT` so the rig's `TEAM_DATA_DIRECTORY` is resolved. The Meloscope team rig is
  `ws-myx.prv-farm`. A rig stores the team data in the folder its settings name in `TEAM_DATA_DIRECTORY`.
  For `ws-myx.prv-farm` that folder is `ws-myx-devops/source/myx/todo-sketchpad/magic-team-deployed`.
  `ws-myx-devops` is just-agents and stays so.
- **`--get-inbox-item` is given the item alone, and its own name before it is dropped.** The branch at
  `sh-lib/member/AgentsTools.Member.include:471-476` takes the first positional as the member and the
  second as the item. The front door inserts the calling member there
  (`sh-lib/harness/AgentsContext.FrontDoor.include:76-78`), and drops a name the caller spelled first
  only where it is that same member. So the item alone reads, and so does the caller's own name before
  it. Any other name stays the first positional and is read as the item, which the bare-name gate
  refuses, naming that name as the item. Reading another member's inbox takes `--team-member <member>`
  ahead of the item. Every flag comes after the item: a flag in the item's place is refused as a name.
  Measured 2026-11-06 on both forms, with `<other-member> <item>` as the known negative.
- **Every tooling writer commits** the paths it wrote through `AgentsToolsTeamDataCommitPaths`
  (`AgentsTools.TeamDataCommit.include`). A close point (spawn close, main-loop iteration)
  pushes through `AgentsToolsTeamDataPushIfAhead` under the `team-data-push` lock: fetch,
  `merge-base --is-ancestor`, merge with `pull.rebase=false`, read back. `AgentsToolsTeamDataDirtyWarning`
  states an uncommitted or ahead store. The store is cloned at dispatch once per process tree
  (`MDAT_TEAM_DATA_CLONE_TRIED`), never into a nested repository.
- **`AgentsToolsItemUpsert`: the commit gate is `.git`, the push gate is `TEAM_DATA_GIT_REMOTE`.** No repo:
  write. Repo, no remote: write and commit. Both: write, commit, push, resync, read back. `--no-push` has
  its own message. Without a remote a lock is local and unverified.
- **`--intern-op-board-upsert-move-edit` is the one board move primitive.** It commits both ends (gated on
  `.git`, never pushing); an untracked source is left out of the pathspec. Subject
  `* board-upsert-move-edit: <item> <from> -> <to>, <context>`. A move deletes the old copy; it never
  writes to `trash/`. It accepts `review` as a state.
- **Every logical move stamps its target state's date field** in that primitive: `processed` →
  `processed-at`, `running` → `started-at`. Suppressed when the caller names the field in any `--header:` op (`:remove:`
  too). Also suppressed on a same-state edit, when there is no complete
  frontmatter, and for `processed-at` when already present. `--create` stamps. Presence is checked with
  `AgentsBoardItemFrontmatterFieldProbe.awk`, never a match anywhere in the body.
- **Creation headers are the tooling's.** Board create and inbox create fill `type`, `date`, `from` (and `owner` for
  inbox) as `default` header ops. These are set only when neither the body nor
  a `--header:` names them. Updates are never stamped. The name is the caller's; `AgentsToolsItemNameShapeCheck` only warns.
- **`--recheck-in <minutes>[±<jitter>]`** on board ops is resolved once in the primitive into a UTC
  `recheck-date`, by `AgentsToolsRecheckDate` (`AgentsTools.RecheckDate.include`). Do not inline the
  arithmetic.
- **List-shaped headers** (`blocks`, `blocked-by`, `supersedes`, `superseded-by`, `spawns`, `spawned-by`)
  are `a, b, c`, no brackets (`AgentsBoardItemHeaderOpsApply.awk`). There is no `references` field.
  `participants`/`restart-session` are space-separated, a separate convention.
- **`--move-to-blocked` and `--grooming-to-blocked` stamp `execution-receipt: blocked:<ts>`**
  unless the caller supplies one; the check is a scan of that call's passthrough, in each arm. This
  header is written by several paths and is not yet in the armed file's header list.
- **A state move belongs to the routine that makes it.** `--grooming-to-parked`,
  `--advance-to-parked`, `--move-to-parked` stay separate stubs; each stamps its own
  provenance. Grooming stamps `owner`, `groomed-at`, `groomed-from`, `track`; a create stamps no
  `groomed-from`. `--grooming-to-backlog` clears `approved-by`/`approved-at`. `processed-at`, not
  `groomed-at`, answers how long an item has been processed.
- **`board-review` is entered only by the spawn proxy** (`AgentsToolsSpawnProxyCloseDispatch` create mode
  passes `review`, with `review-by` only from an explicit `--review-by`), and by a dead run's `resume` or
  `fresh` on an item in `processed`, which moves it back to `review` with its reason first. An item's reviewer is its
  `review-by`. Unset, it is its run's `reports-to` (`AgentsToolsItemReviewer`). A reviewer of `none`,
  given or by default, means no review: the item closes straight to `processed`, with `review: none`
  in its Decisions. Entering review, where the reviewer is `human-owner` or `user-<account>`,
  posts that person one review prompt, kind `review`: 👍 accepts, ↩️ returns, ❌
  rejects. A reply starting `accept`, `return` or `reject` does the same. A review settled another way closes the
  open prompt; every other reviewer gets none. A reviewer's accept moves review → processed. A return moves it to running,
  the same session, with comments. A reject moves it to pending, for a fresh
  session. A dead run's own control thread asks its item's `review-by` a decision
  instead, kind `decision`, options `resume`, `fresh`, `close` and `kill`.
  Where no reviewer is set there is no question, and the record is simply
  closed. The answer is carried out by the review's own operations:
  - `resume` and `fresh` by `--intern-op-review-return` (`AgentsReviewRestart`; `fresh` sets
    `MDAT_REVIEW_RESTART_FRESH` to start a new process on purpose, taken out of the environment
    there);
  - `close` by `--intern-op-review-accept`;
  - `kill` by `--manager-session-kill`.
  Nothing is started while a process still runs as the run it would replace.
- **The approval cascade** (`AgentsToolsApprovalCascade`, `AgentsTools.ApprovalCascade.include`) fires
  when an `approval-*` arrives in `board-processed` carrying `approved-by` and `approved-at`. Each `blocks`
  item takes those values as `default` ops; a stamped `board-blocked` item whose every `blocked-by` is
  processed, archived or retained moves to pending. Bad entries are reported and skipped; never fatal;
  idempotent. Paths join the approval's commit.
- **`--intern-op-board-trash`** is the one implementation behind
  `--librarian-inbox-item-trash` and `--trash-inbox-item` (wrappers pass `--context`). Subject
  `- <invoked op>, <member>`. Without `.git` it creates `trash/`, tests `[ -e ]` before `mv`, and
  `touch`es the item so its trash clock starts now. With `.git` it deletes and commits.
- **`--intern-team-data-final-gc-deletion`** retention is keyed on document type (`warning-*`,
  `reflection-*`: 1 day; others 7), the same in each inbox's `processed/`, `board/processed/` and
  `trash/`.
  - In an inbox only `processed/` is collected, and `incoming/` never, whatever it holds. An item of
    `processed/` with `processed-at` is clocked by that stamp; a bad stamp keeps the item with a warning.
    One with no stamp is clocked as elsewhere, below.
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
  - A deleted processed or trashed item takes its spawn sandbox folders
    (`spawn-id`, `spawns`/`spawned-by`). It keeps them when a record is still
    `spawn-started`, has no status, or another item links the folder. Unlinked
    sandboxes are never removed; synced copies may return.
- **`--intern-team-data-reflection-sweep <member> [--days N]`** is the safety net
  for reflections nobody handled, tooling retention like the final GC. It acts
  on every inbox under the caller's name, and moves only reflections. A
  `reflection-*.md` in an inbox's `incoming/` dated more than 35 days ago (by
  default) is moved to that inbox's `processed/` as discarded. It is appended
  at the end of its frontmatter exactly as the mark op appends
  (`processed-at`, `disposition: discarded`, `discarded-by:
  reflection-sweep-<N>d`). The final GC takes it a day later. The date is the `date:` header's, else the NAME's
  (`reflection-<YYYYMMDD>T<HHMM>Z-…` or the old `reflection-<YYYY-MM-DD>-…`). A name date before the cutoff is compared as a string in the shell, with
  nothing opened. Only those, and the few names with no date, are opened, all
  by one awk (`AgentsReflectionSweep.awk`). A date is healed lazily and logged. A file with no `date:` header is given
  one, the date of its name. A file with neither is given the day of the
  sweep, and kept. One warning for each, never again. The stamp is `<YYYY-MM-DD> 00:00 +0000` UTC, the same
  all day, so two rigs sweeping one shared store write the same bytes. One commit for the run, by
  `AgentsToolsTeamDataCommitPaths`. A line for each inbox and one for the run; `rc` 2 when nothing was swept.
- **Retention is run by the main loop**, at most once an hour. The clock is
  `AgentsToolsRetentionRun`, `AgentsTools.Retention.include`, the time of the
  last run in `.local/agents/retention.stamp`, written before the run.
  `MDAT_RETENTION_INTERVAL` seconds overrides the hour. The sweep runs first,
  then the final GC. Each
  step is tried whatever the other did; a failure is a line, never fatal. The GC is otherwise run only at
  the close of a routine lock and from the console menu.
- **`--upsert-inbox-inquiry … --from-reflection <reflection-file>`** is a
  reflection's exit at filing. The reflection of the filing member's own
  `incoming/` is checked before anything is written. It is marked processed
  after the inquiry is written, in the same call (`disposition:
  filed-as-inquiry`, `filed-as: <inquiry>`). A name that is no reflection there, or is another member's, refuses the call whole.
- **Every delivered inbox block closes with the inbox instruction** (`AgentsToolsInboxInstruction`,
  `AgentsTools.InboxPlace.include`): what the reading run does with each unprocessed item. Its places are
  the input scan's own inbox sections, the acting member's alone (a widened read-only inbox carries none,
  its items being nobody else's to mark), and the `Wait` result's `# arrived on: inbox:<member>` block,
  printed by `AgentsWaitArrivalsOrder.awk` from `-v inboxLine`. The wording is `magic-librarian`'s: it
  changes in that one function and nowhere else. `sh-test/inbox/AgentsInboxInstructionLineCheck.test.sh`
  is its test.
- **The GC and the trash op are separate mechanisms**: one deletes on a clock, the other relocates one
  named item.
- **Inbox items live in `incoming/` and `processed/`** (`AgentsTools.InboxPlace.include`, the one answer to
  where an item is: `AgentsToolsInboxDir`, `-DirFor`, `-Folders`, `-ItemFind`, `-ItemProcessed`, `-NotePath`).
  An inbox is two folders, and an item's `processed-at` stamp decides its folder: no stamp, `incoming/`; the
  stamp, `processed/`. The stamp stays the GC clock. Every store is split since F4.3's one-time move: no inbox is read or written
  at its root. A folder that is not there yet is made by the first write into
  it, git keeping no empty folder. Readers never see the folders. An operation names an item, never its folder,
  and sees `incoming/` alone unless it is given `--include-processed`. The
  trash takes `--exclude-incoming` instead, for a processed item only. The input scan lists `incoming/`, and the processed items only in its wider
  inbox breadth. `Wait` lists `incoming/` alone. An item in `processed/` wakes
  nothing. Marking an item handled, which moves it out of `incoming/`, is the
  waiting member's own act and never an arrival. A standing note, a routine's state and lock among them, carries no
  stamp and lives in `incoming/`.
  `--intern-op-inbox-to-processed` finds the item in `incoming/` (in
  `processed/` too with `--include-processed`), and stamps `processed-at` as a
  `default` op. It writes it in `processed/` through a sibling dotfile and a
  rename. Only then does it take the item out of `incoming/`, so it is never
  in neither. It commits alone.
  Re-marking is a no-op; an edit keeps the original stamp. An upsert puts an item where its stamp says, and
  moves one whose stamp changes its folder. Readers of the stamp use `AgentsInboxProcessedAtList.awk`, bounded
  to a frontmatter block starting on line 1. `AgentsInboxSplitCheck` is the test.
- **Published documents** (`--intern-artifact-publish`, `AgentsTools.InternArtifact.include`):
  - The type table is `AgentsToolsArtifactTypes`, one `<code> TAB <name>` row per
    numbered type. A kind matching a code or name (any case) is numbered.
    Anything else is free text with no number.
  - The team place is Confluence when `CONFLUENCE_SPACE` is set, else Google. A
    Confluence key reads the caller's own scope first, one member such as a
    `client-*` member beside a Google team. Then `magic-team`, a general team
    key. With no key, Artifact names the human-owner. The caller's own credentials for that place are
    required, and their absence is rc 6 naming the keys. The Google team root is listed, never
    configured: the one folder named `magic-team` the caller sees (none or several is rc 6).
    Inside, the structure is the tooling's. Each type has one Confluence index
    page `<`Documents index`> index` (`<`Documents`>` untyped), and the
    document is its child and listed on it. Each type has one Drive folder
    CODE (CODE). Found by title, made on first use.
  - Markdown goes through `LocalMarkdownHtmlDocument.awk`. HTML references are
    rewritten by `AgentsArtifactHtml.py`. Confluence gets XHTML, with given
    files as attachments. Google gets images inline as `data:` URIs, and other
    files uploaded beside the document as `<number or title> - <name>`. Any
    other file is published as it is. Every refusal comes before the first write.
  - One audit item per document, `audit/artifact-<date>-<number or title slug>.md`, its frontmatter
    number, kind, title, url, member, session, date and state (`reserved`, then `published`).
  - The number is the highest `number:` there plus one, `%03d` (four digits after
    999). It is secured before anything is published
    (`AgentsToolsArtifactClaim`). The reserved record is committed and pushed,
    under the `team-data-push` lock, which orders writers sharing one
    checkout.
    The push is the race between hosts. A host rejected because origin moved drops
    its own commit, resyncs with `cloneSync --no-push` and claims the next
    number, up to five times. An unreachable origin secures nothing and
    publishes nothing. The record is completed after the publish, or
    deleted when nothing was published, then pushed with `AgentsToolsTeamDataPushIfAhead`.
- **Vault and audit reads**: `--get-vault-item` and `--get-audit-item` check the caller;
  `--intern-op-vault-item-read` and `--intern-op-audit-item-read` (`AgentsTools.InternOpVaultAudit.include`)
  resolve and read, so a new back end changes only there. The writes are `--upsert-vault-item` and the
  typed `--upsert-vault-<kind>` ops (`--intern-op-vault-item-write`, the same include), whole or by patch.
  A vault item is a file with an extension, since the vault holds many kinds of file: a name given with
  none is the Markdown document of that name, `.md`, on the read and on every write
  (inline at each reader, in `AgentsTools.InternOpVaultAudit.include`).

## 17. Routines: locks, scans, day rhythm

- **A routine locks its own fixed note**, named in its `routine-lock-document:` (`inbox:<member>:<note>.md`,
  a comma-separated list where it runs another routine inline), never by caller argument. The spawner takes it while it starts the routine, or the start fails
  (`AgentsToolsRoutineLockAcquire`, `AgentsTools.RoutineLock.include`), before
  the input scan. It gives it back once the last run of the session has ended
  (`AgentsToolsRoutineLockRelease`, called where a run's record closes). A
  receipt goes in the document first. A participant never locks or unlocks. A lock reads as held for 120 minutes
  (`AgentsToolsRoutineLockMinutes`) without a state write. The four standing notes of
  advance, daily, grooming and retro must exist; any other locking document is made by the
  routine's first start. An inline run (`--routine-run-inline`) takes no lock.
- **`--update-routine-state` (ThisSession) is the one write of a locked document**
  (`AgentsToolsRoutineSessionStateUpdate`, `AgentsToolsRoutineStateWrite`).
  Any participant of the locked session calls it, with no routine name or path
  (`--document <note>` only where the session locked several). The lock-owned fields (`type`, `from`, `date`, `owner`, `state`,
  `recheck-date`, `session-id`) stay as the document has them, whatever the
  content says. So a caller cannot pin the lock open or give it back. While
  `state` is `<routine>-running`, each write refreshes `recheck-date`. Each is committed, and
  pushed where a remote is set, before it returns. The per-routine `--magic-<routine>-state-and-lock-upsert`
  are retired under the shim rule: gone from help and from the skillset, kept in the dispatcher.
- **A whole-record state write carries only the headers its body names.** `--update-routine-state
  --from-file <body>` rebuilds the frontmatter from the seven lock-owned fields plus the body's own
  non-lock headers (`AgentsToolsRoutineStateWrite`). A header the body leaves out is gone, silently,
  `phase` and `last-round` included. Copy the stored header block into any body you send, and use
  `--header:upsert:<name>:<value>` alone for a header change, since `--from-file` and `--header:` are
  refused together.
- **`--magic-<routine>-close-state-and-unlock`** writes closing content, finished state and unlock in one
  `AgentsToolsItemUpsert` call. Unlock order: GC, lock write, one push, resync. No routine calls it any more: the spawner's unlock does, for the five standing
  notes (`AgentsToolsRoutineLockOwnWord`), so what it does under the lock
  still happens. Any other locking document is closed by the spawner with a
  `last-receipt` and `<routine>-finished`.
- **Advance lock paths** run `myx.common git/cloneSync --no-push` when a remote is set, for every lock the
  spawner takes. Acquire runs: state check, resync, state check, head comparison against
  `FETCH_HEAD:<path>` (never `origin/<branch>`), then write. Then a fetch that
  must read this session in the published note (`LOCK_NOT_PUBLISHED`). `LOCK_CONFLICT` (merge, marker, local edit), `LOCK_STALE` (local commit is not
  head), `LOCK_UNCHECKABLE` (could not answer, or no named branch) all refuse. A push or resync failure at
  unlock warns and still closes.
- **The state note and its lock share one note.** The coordinator's state note (the file name keeps "heartbeat-state-and-lock";
  it holds the standing directives, F7.9) is taken with
  `--state-note-lock-acquire`. It is written through
  `--intern-op-state-note-upsert`, which takes a whole-record body and splices
  in seven lock-owned fields read from the target. Those seven (`type`,
  `from`, `date`, `owner`, `state`, `recheck-date`, `session-id`) are excluded
  from the caller's body. It strips `\r`, and treats a fence-less body as all body. It refuses when both
  extracted parts are empty from non-empty input. It strips the body's leading
  blank lines, so the separator stays one line. While the state is
  `heartbeat-running` (the stored value of a held lock) each write refreshes `recheck-date` to now + 15
  min. It stamps `last-iteration-date`/`-timestamp` (the date of the write) and keeps
  `last-test-email-sent`. No routine locks this note: only the directive writes of the coordinator's
  surface and the test report write it. So the read-then-write gap races only
  itself.
- **`last-close-date`** is stamped by the grooming and daily closes. Dates are local (the workday is the
  human-owner's); lock dates stay UTC; never compare the two. The test report (`--send-report`, by hand or from a console, never scheduled)
  is built from the board's counts and active items (`AgentsToolsBoardCounts`,
  `AgentsToolsBoardActiveItems`). Those list item names only.
- **No input scan is an agent's call.** A scan is the operation `--intern-op-<scan>-input-scan`, named by a routine's
  repeatable `input-scan-def: <scan> [--option value ...]` line (`none` alone

  for no scan). The spawner runs it at start, after the lock, in the order
  written, for the member of the start. The results are saved to
  `input/<spawn-id>/input-scan.md`, in the run's own input folder, and named in the brief. One parser reads the
  line for the validator and the spawner (`AgentsToolsInputScanDefWords`, `AgentsTools.InputScanDef.include`;
  `AgentsToolsInputScanNames` is the list of scans). A value that exists only at session time is a macro: `{{<option-name>}}` over
  the five names of the common option set. It is written only where the
  operation cannot take it from its context. The `--magic-*-input-scan` and `--member-*-input-scan` wrappers are deleted,
  no alias left. A caller wanting another shape calls `--intern-op-session-context-scan`.
- **`--intern-op-morning-review-input-scan`** reads board headers only
  (`AgentsMorningReviewStateShape.awk`), capped per section, cut off at
  `last_reviewed_ts` of the routine's locked state, advanced only at close.
  The scan prints the `--update-routine-state
  --header:upsert:last_reviewed_ts:<next>` that does it.
- **`--intern-op-sweep-input-scan`** sweeps the team and each `client-*` concurrently and prints the team first.
  `lib/parallel` runs in a nested subshell because it installs an `EXIT` trap. This is safe because
  `--intern-op-slack-call` waits out rate limits (`ratelimited`/429, `Retry-After`, up to 5 attempts,
  `AgentsToolsSlackRateLimitWait`).
- **`--intern-op-routine-lock-take advance` closes dead spawns** after a successful take, and only then, as
  housekeeping the tooling does itself. Its lines go to the daemon line and the caller's event-track
  thread (`AgentsToolsHousekeepingReport`), none to its output. Dead on this
  host: no live process, no open ask, nothing changed under its sandbox or `sessions/<id>/` for 15 min.
  Elsewhere: no open ask and nothing changed for 24 h. It then starts the control thread of each session that is not finished and has
  none alive. It prints one housekeeping line when it started any, and a
  failure as one warning on the daemon line. A dead spawn's created dispatch item moves running
  → review. A review item whose `review-by` session has ended gets `review-by: magic-coordinator`.
  The board sections of the coordinator's work-duty scan
  (`--intern-op-work-duty-input-scan`, which the work-duty, the advance
  routine's manual start and the daily declare) are a pure read. They change
  nothing, post nothing, and never accept an item. The advance scan (`--intern-op-advance-input-scan`) is retired.
- **The input-scan cache is deleted (T2).** The predecessor (`AgentsTools.InputScanCache.include`,
  `AgentsToolsInputScanCached`, the rewind's `AgentsHarnessScanCacheDrop`, the
  300 s TTL text) had no scan wired through it since the advance scan's
  retirement. It was tested only directly. It is removed, never left unused,
  and the rewind no longer drops a scan report. A member's own incoming is cached by source instead: see the incoming-sync bullet below.
- **A work-duty is one session with one thread (S4.6).** The schedule starts a member's duty again after a cache-keep, on demand or on a tag
  (`AgentsToolsScheduleSpawn`, key `work-duty.<member>`). The first start keeps its session id in `schedule/duty-session/<member>`, and every
  later start brings the member into that session with `--spawn-session --join-session <session-id>`. The duty's session thread is in the owner's
  conversation, opened by its own start post, and its tooling thread stays in event-track (S23.4). The
  thread says once that the member joined, not at each start. A join the proxy refuses ("refusing to
  join") drops the kept id, and the next start opens a session again. `AgentsWorkDutySingleThreadCheck` holds it.
  The kept id ends with worktime: out of its flags, with no duty running, the member's id goes, and its next worktime opens a session.
  A duty is also never ended to be started again. The schedule no longer
  restarts an ended duty to keep its cache warm. The cache is kept inside the
  running session by the keepalive of `--idle-wait`. And a work-duty's
  plain-text reply no longer ends a harness run. The harness makes the
  idle-wait itself, and asks the model again. Only a dismissal ends it. `AgentsHarnessDutyNoQuitCheck` and `AgentsDutyCacheKeepCheck` hold it.
  After each working loop the duty's wait returns the conversation to the held checkpoint, also when the run bounds its waits (sketch 7.3).
  The spawn proxy keeps one duty per member: the session id is recorded under `work-duty-session-<member>`'s lock, and a start racing another's is refused.
  An executor of any routine (a member spawned or joined into a session) is not
  dismissed unless it is the last one running (sketch 5.3). Its plain reply
  makes the idle-wait while another run of its session is going
  (`AgentsHarnessOthersRunning`), and the quiet round asks again.
  The Member+ layer of a work-duty (sketch 8: "`Memeber+ layer` - `-extended`
  (for work-duty sessions) - more preloaded member static skill/knowledge") is
  real. It is built from the skillset's existing text. The member's
  `reference/*.md` are taken in the order of their names, merged by
  `--intern-merge-md-files` with `--section-limit 3` (a file reference for
  what lies deeper). It sits right after the member's armed content and before
  the session layer (`AgentsHarnessMemberPlusText`). A routine asks for it with `cache-prefix: extended`, the sibling of `armed`
  (the default) and `routine`. Both work-duty routines declare it, and the
  harness reads the key and no file name. The dispatch then carries the routine alone, and the member's reference
  has one copy. The Team+ layer is as it was (the optional file `magic-team/magic-team.armed-extended.md`, empty).
  The size of each member's Member+ text, in bytes, is what the skillset-size
  instrument (S7.2) tracks. Measured 2026-10-27: human-owner 2,198,
  magic-architect 2,081, magic-frontender 5,276, magic-coordinator 11,288,
  magic-team 33,163, magic-tester 37,693, magic-librarian 42,355, magic-devops
  54,882 and magic-developer 68,597. The text grows with the reference files; a member whose figure passes the owner's bound is told to the owner.
- **The floor after a compaction.** Our harness keeps its layers. The team layer is the system message of every
  request. A summarise-and-restart builds the first message again
  (`AgentsWireInitMessages`) with the member layer, the prefetch and the task,
  the summary after them. A restart comes near the service's real window: the threshold is the window
  less the output limit (`AgentsUniversalHarness.sh`). A threshold under half
  the window is warned of. A native client's compaction
  replaces the history with a summary, so the floor a spawned member loaded may be gone. `sh-lib/client-hooks/floor-after-compact.sh` tells it to load the floor again:
  - Claude Code: a SessionStart hook with the matcher `compact` prints a pointer
    on stdout. It is a native record of the client tool policy, installed with
    the others.
  - Grok Build: PostCompact has no output, so `mark` keeps a marker in the session's store, and the next PreToolUse (`grok`) answers once with `additionalContext`.
  - Copilot CLI: preCompact marks, and the next postToolUse (`copilot`) answers once with `additionalContext`.
  - The hook files for the last two are printed by `floor-after-compact.sh config grok|copilot`, for the owner to put in `~/.grok/hooks/` or `~/.copilot/hooks/`; nothing writes them.
  - DeepSeek and Scaleway have no native client: they run in our harness. `AgentsFloorAfterCompactCheck` holds the hook, `AgentsClaudeSettingsHooksCheck` its wiring.
- **A member's own incoming is cached locally and refilled on a call when stale
  (T2)**. That is personal mail, tags and mentions, DMs, and the session chat,
  each by its own TTL of the one table (`AgentsTools.SourceTtl.include`). The
  session chat is short (`chat:*` 15). The mail is five minutes out of
  worktime and ten in it (`mail:*` 300, the 5–10 minute band;
  `AgentsToolsCollectTtlOf` stretches it by worktime,
  `AgentsToolsScheduleWorktimeNow`). The tags and mentions are one to five
  minutes: `tagged:*` stays the 15 s live Wait floor. The schedule re-reads
  the team channel that feeds the tags at 60 s
  (`AgentsToolsScheduleTeamTags`). The DMs are at 60 s within the flags and
  300 s out. There is no proactive pull where no main loop runs: the one background thread (`AgentsTools.CollectThread.include`)
  is wanted by the main loop or a scan. A per-member command syncs at once. `--intern-op-member-incoming-sync
  <team-member>` refills the member's mailbox and Trello now, and force-reads
  its tags and its DMs through the schedule's readers
  (`AgentsToolsScheduleTeamTags`, `AgentsToolsScheduleDmTags`). It force-reads
  its session chat through the communications reader
  (`AgentsToolsSessionCommsRead`). It prints one line a source
  (`AgentsTools.Incoming.include`, `AgentsToolsIncomingSync`). The chat line
  of a member in no live run says `no session`, never a count. A sync follows a member's start. The spawner runs the sync's `start` scope
  before its input scans: the personal mail alone. The tags, the DMs and the
  chat are read by the schedule, the work-duty scan and the member's Wait,
  F4.2.
  Each source keeps its own pointer per session and per member (the collect state, the schedule files, the session chat pointers).
- **`--routine-run-inline <routine>` is a routine run in the calling session**
  (ThisSession, `AgentsTools.RoutineRunInline.include`). It hands back the
  routine's Steps, without its frontmatter and Maintainer Notes. The Opening
  steps, Closure steps, local rules and tooling of `magic-team.inline.routine`
  are mixed in, in place of those of its kind's. It takes no lock. The routine's own `input-scan-def:` scans run now, by the runner the spawner
  uses, for the calling member. They are saved to
  `input/input-scan.<routine>.md` of the caller's sandbox, named in a line
  ahead of the steps; from no sandbox the result follows the steps. A scan
  that fails stops nothing, and the file says so. A call from no member's
  session for a routine that declares a scan is refused.
- **A routine's keys are read by the tooling, and `magic-team/contracts/routine.contract.format.md` is the one list of
  them.** The validator is `--intern-doc-validate routine`, which `DistroAgentsTesting.fn.sh
  --skillset-validate-routine` stubs. `requires-session-kind:` (mandatory, no default) names a kind of the list the
  tooling owns. With it the routine inherits from the kind's routine: one
  level, and never a chain. The kind's Opening steps come first, then the
  routine's own. The routine's Closure steps come first, then the kind's. The
  kind's local rules and tooling block apply. Any key the routine leaves out
  (`AgentsToolsSpawnRoutineMixText`, `AgentsRoutineMix.awk`).
  `skips-inherited:` names the kind's steps that do not run; prose in the local rules stands in for none
  of it. `tracking-item:`, `operations:` and `start-context:` are decided by one
  evaluator, `AgentsTools.RoutineRequirements.include`, at three sites (save,
  spawn, start) and in the order validate, automate, help, reject. A key left
  out means any, and `operations:` is reported, never enforced.
  `review-by:` is `inherit` (the review follows the run's `reports-to`), `none` or a reviewer.
  `runs-at:` and `runs-after:` are the autorun keys, checked on save and read by nothing yet.

### `--intern-op-session-context-scan` (no help; essentials)

The document format is `sh-lib/templates/session-context.document.format.md`. The flags are parsed in the
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
  Capped at 64, NEWEST kept in full and shown oldest first by mtime; the board is never capped. The
  older items are one `older: inbox/<name>` line each, the next 64 by name, then one
  `older: (+N more, not listed)` line. Reflections are capped at the newest 5, each cut at 1024 bytes,
  and the older ones are a count in the `truncated` NOTE, no names. Each block carries the whole item
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
- **Slack reads**: a roster widened to channels keeps only channels the identity
  is in (`is_member`). A thread whose `latest_reply` is at or before the
  cut-off is not read, but still counted. The IM section shows at most 128
  conversations, and reads threads newest first, stopping below the cap with a
  `**NOTE:** capped` line. Each `## slack-message` block carries `author:` and `addressees:`, parsed from
  the team send header only when it is the text's first line.
- **Rejection messages name what was actually wrong** (`--intern-op-client-sweep-input-scan` and
  `--client-sweep-config-check` are client-only).

## 18. Slack

- **Target grammar has one resolver** (`DistroAgentsToolsResolveTarget`). A bare conversation id (≥ 9
  chars, uppercase letters and digits, first a letter) posts at top level. Its arm comes after `*:*`, so
  the two grammars are disjoint. The id is never trimmed or repaired. An addressee word is read as a Slack id only by that whole shape. A word that
  is neither a known member name nor one fails the send with one plain line,
  never a guess.
- **The root-native printback kind is a channel-id, `printback:<session>`** (F2.2). A send operation takes it ahead of any Slack grammar, so nothing of Slack
  stands behind it. The message is printed to the operation's own output, and
  that output is its external copy. It is recorded in that session's one chat
  file, with the channel-id as the block's conversation and `printback` as its
  origin. No Slack
  call, no thread, no send log and no outbox. A member reads it through `Wait`'s `chat:<session>` source, like every block
  of the session (a DISMISSED addressed to it dismisses through it). A served
  call prints the new block beside its result. The driver is
  `sh-lib/comms/AgentsTools.CommsPrintback.include`; the kind is a service of the channel-id abstraction
  (`AgentsToolsCommsChannelDrivers`), so a project may declare a channel on it.
- **A background notice is recorded, then surfaced one line at a time (F3.3).** The spawn proxy's notices about a run are not messages. Those are a member
  joined, a run ended with no handback or with its own question still open,
  and how a run ended. A `none` session has no thread to carry them. They are recorded in its one chat file as blocks whose origin is `notice` and
  whose conversation is `printback:<session>`
  (`AgentsToolsCommsPrintbackNoticeRecord`). Nothing is printed by the proxy,
  and nothing is posted. The next foreground call of that session carries the digest
  `AgentsToolsCommsPrintbackNoticeDigest` as a content part beside its result.
  It holds one line per notice, the block's body joined to one line. Each notice the digest prints is marked in the chat index as delivered to the
  member, before the line is printed. So it is never surfaced twice. The mark
  is in the one chat file, not a buffer. The chat reader never delivers a `notice` block itself
  (`AgentsSessionChatRead.awk`), so the digest is its only surface. `track` and `full` are unchanged: a
  helper's join and a run's end are told as they were, and no notice block is written.
- **Six built-in aliases name a place without a channel id**: `session-current`, `session-parent`,
  `magic-team`, `human-owner`, `event-track`, `event-alert`. Send, read, react, edit, delete, file-share,
  the four ask tools, the five posting tools and `Wait` sources all take any of them. `<alias>:<ts>` names the message with that ts in the conversation the alias
  names. A send or an ask to it is a reply in that message's thread. An alias naming nowhere, or a conversation alias with no setting, fails with one
  plain line. Refused where it cannot make sense. A search needs one thread or one message.
  A react, edit or delete needs more than a bare conversation alias. An ask to
  `event-track` or `event-alert` needs `address_to`.
- **A `client:` marker resolves on the other organisation's side.** The resolver strips it, and resolves the rest by the same grammar. It keeps
  the marker on the result's `CHANNEL=`, so whatever reads it next stays on
  that side. `client:client:*` is refused, rc 2. The marker on a call no `client-*` member is running is refused, rc 3. It
  names the operation and its `--member-*`/`--client-*` twin in one line
  (`AgentsToolsSlackOneWayLine`). The same holds for a client-side call naming
  one of our own aliases. A `--client-comms-slack-*` operation reaches the other organisation this way:
  send, read, search, react, edit, delete, file-info, file-fetch, file-share,
  profile. `--slack-*` reaches our own team instead, posted as the team bot,
  whichever member is acting. The credential never makes this
  choice: the operation's own prefix and the address do.
- **`session-current` and `session-parent` resolve in the same function**, each
  one thread, with no `:<ts>` of its own. A `:<ts>` suffix on either is
  refused, rc 3, naming itself and that it takes none.
  `session-current` names the session thread of the coworking session the member
  works in (`AgentsToolsSessionCurrentThreadFind`). `session-parent` names the
  thread of the session the run reports to, by the route
  (`AgentsToolsSessionParentThreadFind`), and also resolves a parent session
  id. A name that resolves to no recorded `<channel>:<ts>` is refused the same way,
  rc 3. It names why in one line, and that `<channel>:<ts>` is the way around
  it. On success both print `CHANNEL=` and `THREAD_TS=`;
  `session-parent` adds a third line, `PARENT_SESSION_ID=`, when it has one.
- **A session's channel kind is its record's to say (F2.3, F3.1).** A root-harness session minted by `RootSession` records its kind at mint, from
  this workspace's `ROOT_HARNESS_VERBOSITY`, in
  `sessions/<session>/root-session.kind` beside the token. The kind is `none`,
  `track` or `full`. It is one line, set by
  `AgentsTools.RootHarnessKind.include`: `--manager-config-set
  ROOT_HARNESS_VERBOSITY <value>`, a magic-team setting of the workspace shown
  by the digest. `none` applies where nothing sets it. A value that names no
  kind is read as `none`. The kind is a channel, never a level, and it is read once, at mint;
  adopting a session never rewrites it.
  - `none`: the session's external side is the root-native printback channel,
    `printback:<session>`, with no thread and no Slack call. Both session
    addresses resolve to it (`AgentsToolsCommsPrintbackSessionInUse`):
    `CHANNEL=printback:<session>` with an empty `THREAD_TS=`, and no `:<ts>`
    taken. The kind holds one conversation, rc 3 with the line saying so. A send to either goes by the printback driver, like a send naming the
    channel-id. A Wait of that session's default sources is `chat:<session>`
    alone (`AgentsToolsWaitDefaultSources`, which decides the kind BEFORE any
    thread or conversation is looked for).
  - `track`: the external side is the session's tooling thread, the event-track thread every tracking
    post already goes to (`sessions/<session>/event-track.thread`). No session thread is opened, and no session root post is made. Both session
    addresses resolve to that thread (`AgentsToolsCommsPrintbackTrackThread`),
    so the copy of a message the session sends is posted there. That copy is a
    helper's handback, or the root's DISMISSED, and its one chat file still
    records it. A tracking
    thread is never a session thread; here it is the session's external channel. The channel is read back from the record, not from Slack. A bare Wait's only
    default source is `chat:<session>` (`AgentsToolsWaitDefaultSources`,
    decided by the recorded kind before any thread or conversation, as for
    printback). The floor counts a block whose conversation is the tooling
    thread as the session's own (`AgentsToolsSessionChatFloor`). So a report
    posted there reaches the root, and a dismissal reaches the helper.
  - `full`: a session thread in the team channel, opened as for any session that brings a member in.
  - A session with no kind record, one minted before this feature, is inferred by
    F2.3's mark. The token in its folder and no session thread on record is
    the printback kind. An explicit kind always
    decides over that inference, in either direction.
  - The dispatch handed to a helper states the kind and the channel it is named by in its
    `## Your session thread` section (`--intern-op-agent-spawn-proxy`). A message that names no address goes on the session's own channel, by the same
    kind. `none` prints and records it on `printback:<session>`. `track` posts
    it into the tooling thread and records it. `full` posts it into the
    session thread and records it. The one rule
    `AgentsToolsCommsPrintbackSessionOwnTarget` applies to the served
    `SendMessage` and to the send operation's own default alike. So the
    message is in the session's one chat file, and never only in the model's
    context (F3.2). A message that names an address is never gated by the setting. It goes to that
    address whatever the kind is: a thread, a member's DM, a conversation or
    `printback:<session>`. The record's conversation and origin say which way
    it went. A session on a recorded thread resolves as it always has; the printback channel is its
    own beside it (F2.2).
- **`<channel>:<ts>` needs a real Slack channel id and a real timestamp.** A malformed value is refused
  the same way as an unresolved name. A Slack error on a post is final, except a rate limit, which is
  retried (`AgentsToolsSlackRateLimitWait`).
- **Identity selection is in `--intern-op-slack-call`, once.** No `--identity`: a member with
  `SLACK_USER_TOKEN` acts as itself, otherwise the bot; a `routine-*` author is always the bot. Passing
  `--identity user` turns the fallback into a hard error; use it only where acting as the bot is
  unacceptable (profile ops). A read takes the same fallback. `--slack-read` under the user identity that
  Slack answers `channel_not_found` or `not_in_channel` is read once more
  under the bot. So what a send posted under the bot is read back
  (`MDAT_SLACK_READ_FALLBACK_DONE` stops a second try). `--identity-bot`
  asked is final.
- **Bot token**: the member's own `SLACK_BOT_TOKEN`, then `magic-team`'s (`AgentsToolsResolveSlackBotToken`,
  prints `member-bot-token|shared-bot-token <token>`). Never keep the team's token in a member's scope.
  `magic-team` is an identifier; read `magic-team/reference/skill-folder-model.md` "Identifier and identity" before renaming.
- **Workspace domain** for `X-Request-Detail`: the member's own `SLACK_WORKSPACE_DOMAIN`, then
  `magic-team`'s (`AgentsToolsResolveSlackWorkspaceDomain`). It is persisted by
  `--intern-op-check-configs <scope> --resolve-slack-workspace-into SLACK_WORKSPACE_DOMAIN` (user token
  first) on that scope's config-check pass (`--config-check`,
  `--client-sweep-config-check`). A member without its own pass gets the team's domain, which is wrong if its
  token is in another workspace. Add a pass, never a per-call `auth.test`. The resolved name is not persisted into a scope whose Slack settings are
  themselves read from another workspace (`AgentsToolsConfigOptionElsewhere`).
  It is reported, not written, so that workspace keeps the token. This one
  does not start claiming the system as its own.
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
- **`AgentsToolsUrlPostBytes --url <url> --body-file <path> [--context <op>]`** POSTs raw bytes with no
  credential. Its own include never sources `AgentsTools.CommsSlack.include`, and its name stays out of
  the Slack family, so nothing credential-bearing is defined by loading it. The URL is a bearer capability: never in diagnostics, curl stderr discarded, body printed
  only on 2xx. `POST_HTTP_STATUS=`, `POST_BYTES=` (sent). Transport failure writes `000 0`. https only. No
  `EXIT` trap. The URL stays in argv by decision (single-use, short-lived).
- **A reaction is read as a verdict only from before the addressee's first reply in the thread.** Once a
  reply stands, a later click is never read, even where the ask's kind declares that reaction a verdict
  (see "20. Questions, decisions and review").
- **`AgentsToolsSlackCheck`** reads one target (`magic-team`, `human-owner`, `event-track`, `event-alert`,
  a bare id, or `<channel>:<ts>`). `human-owner` merges both DMs: exit 0 both, 3 one, 4 neither, 1 failed
  early. Pretty `ts | user | text` by default; `--raw` for JSON. `--sweep-read-incoming-comms` also
  defaults to pretty via `AgentsSlackMessagesFormat.awk`.
- **`--intern-op-check-configs` carries no Slack call** except the domain resolve, sourced in that branch
  only.
- **Send header.** `--slack-send-message` always prepends the sender's mark, bold name and
  `@alias` before `→`, naming the addressees its call's `address_to` (or `--address-to`) gave it. A member addressee becomes a real `<@U…>` mention via
  `AgentsToolsCommsSlackMentionUserId`. A member is named by `auth.test` on
  its own user token, and the human-owner by `SLACK_CHANNEL_HUMAN_OWNER` (a
  user id). Anything
  else degrades to `@alias` text. `users.list` resolves nobody. A member with no Slack account of its own posts as the team bot. The same
  header lets its own reply be read as its own answer, with no Slack identity
  of its own needed.
- **`--update-ts <ts>`** edits that message in place (`chat.update`) instead of
  posting a new one. It sends the same text, blocks and author line this send
  would post, under the same floor. It carries none of `thread_ts`,
  `reply_broadcast` or `metadata`, which only a new post takes. Slack's answer to an edit is a verdict, not a transport outcome. Only a rate
  limit is retried, and every other refusal is final: no bot-join, no identity
  swap. Those recover a post, never an edit.
- **The output-style floor holds a message back, never refuses it.** A text over a limit this caller gates on is not sent. The outcome starts with
  the fixed word `CORRECTION`, rc 6, one line naming each fault. Then a
  `NEXT:` line tells the sender to rewrite and resend. It is never worded as a
  refusal or a denial, and has no cap on attempts
  (`AgentsTools.OutputStyle.include`). Only the member's own Slack send (and only when `MDAT_SEND_FLOOR=hold`) and
  the member's own email gate on anything. Every other caller passes gating
  predicates of `none`: measured and recorded, never holding a send back.
  Those callers are the tooling's own sends, a board/inbox write, a spawn
  brief and a Trello comment. Also among them are the team roster, the state
  note and the sweep state.
- **The checker measures only the writer's own prose**
  (`AgentsOutputStyleCheck.awk`). A fenced code block, an inline code span and
  a quoted line (`>`/`&gt;`) are left out. So is a list item that is one bare
  path, name or identifier with no space in it. Nothing in them can be
  rewritten by the sender.
- **Mention cache** `.local/.agents/slack-mention-ids.cache`, keyed by `cksum` of the advance lock note
  and the state note (so it resets each lock cycle). Rows `member=id=handle=real=display=domain`; the
  id stays field 2; `-` for none. Writes are `|| true`. `AgentsToolsCommsSlackMentionFindByName` searches it.
- **The send reads presentation from `team-members-names.registry` only**
  (`AgentsToolsCommsSlackMemberPresentation`). An external `client-*` send (own user token, or own bot
  token) shows the persona row's names and refuses if they are missing. Other gaps degrade quietly.
  External sends carry no default `magic_sender` metadata, and client addressees
  stay plain text, since their ids are in another workspace. The bot swap
  after `channel_not_found` is skipped unless the bot is the member's own. Email shows only the address. An invited member is shown with the mark and alias of the
  workspace it is set up in, not the running session's own. A member's alias inside the team can be its own member name, for a `client-*`
  member's team-side presentation. The header then shows that name once rather
  than doubling it. A person tags the member by that same name.
- **`AgentsSlackDate.awk` is the one helper for every date or time the tooling writes into Slack
  text** (`AgentsToolsSlackDateToken`, `AgentsTools.SlackDate.include`). `sldToken` renders a fixed style (`time`, `time-secs`, `date-time`,
  `date-time-secs`, `date`). `sldTokenAs` takes any caller-given token string
  instead (`{date_short_pretty} at {time}`, `{ago}`), and is refused when it
  holds `|`, `^`, `<` or `>`. The fallback is always the same moment as plain UTC text, which `sldFallbacks`
  restores when a sent message is read back. `sldKeep` re-escapes everything
  except a token of this exact shape. Already used by the main loop, pending-reply remind, the spawn proxy and the
  event-track post contract (`sh-lib/templates/event-track.post.format.md`). A
  new site writing a date into Slack text goes through it, never a literal
  string.
- **`AgentsSlackBlocksBuild.awk`** (markdown → Block Kit):
  - Backslash escapes run before every other branch, including code spans. The
    punctuation set is spelled out there, not taken from `isPunctCh()`, which

    drops backtick and quotes on purpose.
  - only `"# "` makes a `header` block; deeper headings become bold lines;
  - `[label](url)` is consumed in one step, after code spans. `(` nests in the
    url. `]` does not nest in the label. Whitespace in the url means prose.
  - bare `http(s)://` becomes a `link`; a bare address becomes bold text (Slack auto-links display text
    anyway);
  - Tables are recognised at the delimiter row by looking back. Rows pad to the
    widest row. Cells are `rich_text` with a space element when empty. `\|` is
    unescaped by the splitter.
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
  facet reported `applied|failed|not-requested`; no rollback. The avatar is always its own `users.setPhoto` upload: upload wins at the
  transport and would drop JSON fields. Its path may not contain `;` or `,`. `profile-get` exits 0/3/4/1 by facets read. Not in the configuration check's scope list.
- **Slack profile facts**: a profile is per workspace. Which of `display_name`/`real_name` renders is a
  viewer preference. `display_name` is the `@handle`; never change it to fix rendering. `title` is a
  workspace custom field; where it is not writable, `users.profile.set` answers ok and discards it (test
  with a plain field like `phone` first). Custom field ids differ per workspace (`team.profile.get`).
  `status_text` and `status_emoji` must travel together; the error fires only when one travels alone and
  empty.
- **Presence** (`--slack-presence-*`, no help pair): held by a websocket, never set
  (`users.setPresence` has no `active`). User token only (`rtm.connect` refuses bots). Keyed by
  `<team_id>:<user_id>`, one holder per account, found by argv match, start under a `mkdir` lock,
  extended with `SIGUSR1`, TTL 300 s default. Its client-side twin, `--client-comms-slack-presence-keep`,
  `-status` and `-stop`, now has its own help entries.
- **Socket mode** (`--slack-socket-*`, no help pair): `SLACK_APP_TOKEN` (member, then team);
  keyed by the token's scope, since Slack delivers each event to one connection. The token reaches the
  holder (URLs expire and refresh); envelopes are acknowledged on arrival; continuation frames are
  reassembled. Only `app_mention` is consumed, filed as an `inquiry-*` in `magic-coordinator`'s inbox
  with `communication-channel-id`. No TTL. No log of its own: rows go to the workspace Slack log,
  `comms-slack-send.YYYY-MM.log`, in its eight columns. These are target
  `socket`, column 6 the event kind
  `connected|reconnect|received|error|stopped`, reason never a body or token,
  session `-`. `--status` reads them from there. Its framing is separate from the presence holder's on purpose. Its client-side twin,
  `--client-comms-slack-socket-start`, `-status` and `-stop`, now has its own help entries too.
- **File share**: three calls (get upload URL, raw POST via `AgentsToolsUrlPostBytes`, complete).
  `files.upload` is retired. Target resolved before step 1; `SLACK_CHANNEL_HUMAN_OWNER` is a user id and
  must be opened as a DM. `thread_ts` must be the parent ts (normalised via `conversations.replies`).
  `blocks` is ignored beside `initial_comment`, so `--comment` is a separate message after the share.
  Length is bytes (`wc -c`, `LC_ALL=C`). `is_public:false`, `file_access:visible`. No `EXIT` trap.
- **A member needs no user token to post under its own name**: the app has `chat:write.customize`
  (`username`, `icon_url`). No op uses it yet. A user token is for what a bot cannot do, like presence.
- **`--intern-op-contact-digest-send <member> <origin> (--resolved|--needs-ruling) <text...>`**: stub over
  the send. The origin is any member, carried in `--address-to`. `--needs-ruling` goes to the human-owner's
  DM under the user identity; `--resolved` to the bot's conversation with him (`--identity-bot`). Public
  wrappers: `--send-contact-digest` (origin given) and `--send-contact-digest` (origin is the
  caller). See the floor rule `non-owner-contact-tiers-and-escalation`.
- **The session comms reader is bounded on every pass, and takes the console first**
  (`AgentsTools.SessionComms.include`, `AgentsTools.InternSessionComms.include`). A pass takes every session's `chat.inbox`
  before any session's turn, so a console message waits one pass. Its cache push is `agentsSessionCommsPostsPerPass`, a
  running total over the channels. Its session turns stop at `agentsSessionCommsPassSeconds`. Its watched-channel pull is
  every 30 s and `agentsSessionCommsPullsPerPass` channels. The log is bound on every pass. These numbers exist because an
  unbounded push drained a backlog of thousands of event-track feed posts in one pass, and no console message or thread
  read happened for the length of it. Raise one only with a measurement of the pass it makes.

## 19. Email, Trello, Atlassian

- **Email send** is `multipart/alternative`, plain first, UTF-8. `markdown` mode renders both parts:
  the plain one through `myx.common lib/catMarkdown` (the console's own renderer), the HTML one through
  `myx.distro-.local`'s `LocalMarkdownHtmlDocument.awk`. `text` mode keeps the body in the plain part and
  escapes-and-linkifies it with `AgentsEmailHtmlBuild.awk`, which escapes HTML once, in `wrapStyle`;
  bare URLs link, bare addresses are bold blue with no `mailto:`. `AGENTS_EMAIL_SEND_BUILD_ONLY=true`
  builds without sending.
- **Email reads** fetch in a subshell redirected to a file (a `$` loses NULs and leaks `set +e`).
- **`--get-path-history`** runs `git log` only, with `GIT_OPTIONAL_LOCKS=0`, no pager. Containment is on the resolved path against the workspace plus
  `AgentsToolsClientAccessRoots read`. Symlinks and `..` are refused. Empty
  root lines are skipped, since an empty root matches everything. "outside the
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
  read in one order and never crossed: the environment, then the acting member's own scope in this
  workspace, then this workspace's `magic-team` scope. A set is taken whole from one rung, so a
  borrowed key never outranks a team key and a client-side call takes no team rung. Separate sets let
  one be rotated alone.
- **Exit codes** (Atlassian transport only). Faults ⛔: 1 contract error before any call; 3 no usable
  answer (transport, unreadable body, 3xx, 5xx); 4 credential rejected (401). Designed refusals 🙋: 5 conflict (409), 6 not configured, 7 forbidden (403, not
  yet seen live). Then 8 not found or invisible (404), and 9 any other 4xx
  (400, 410, 422, 429). One branch sets mark and code together. `page-update` compares rc
  to `5`; rc 5 elsewhere in the package means "no CLI selected", which is why "not configured" is 6.
  `AgentsAtlassianJsonObjectMerge.py` exit 3 means a forbidden key, a different producer.
- **A failure is one stderr line**: mark, op name, status, and the site's body verbatim.
- **Jira gotchas**: `/rest/api/3/search` is retired (410); use `/search/jql`, which refuses an
  unrestricted query (400), pages by `nextPageToken`/`isLast`, has no total. An unresolvable JQL returns
  200 with no rows, so an empty result says nothing beyond that query. A bad token gives 401 on `/myself` but 404 on a private issue (anonymous).
  `--intern-op-atlassian-check --product jira` is the credential check. For a
  `client-*` member run on our own side it answers the own-side line instead
  (`AgentsToolsCommsOwnSideCheck`/`AgentsToolsCommsOwnSideLine`), naming the
  `--client-*` twin to use. A
  null description is a real answer. Default format `adf` (writable back);
  `rendered` is offered.
- **Jira project delete prints before it deletes.** `project-delete` reads
  `/rest/api/3/project/<key>` first, prints the project's own `KEY` and `NAME`, and only then sends the
  `DELETE`. The printed row is the whole confirmation the operation gets, so nothing else asks. A
  print-back that cannot be written is refused with 1 and the delete is never sent, and a read
  answering without both is UNKNOWN with 3, never a delete. The `DELETE` carries `?enableUndo=false`:
  a deleted project is restorable from Jira's own recycle bin only while that window is on, so the
  operation turns it off and says so in its help. Coordinator-only, with no client twin, as
  `space-create` is, because a project is the site's own top-level container.
- **Jira writes**: `issue-create` never calls createmeta; extra fields via `--fields-json`, merged by
  `AgentsAtlassianJsonObjectMerge.py` (no text splicing). Never auto-retry a create with an unknown
  outcome (no idempotency key). `issue-update` takes `--fields-json` (full replace per field) and/or
  `--update-json` (add/remove/set); `status` is refused locally; `notifyUsers` defaults to false.
  `issue-transition` always looks up transitions and matches `to.name` exactly; zero or several matches
  fail before the POST. `comment-add` has no `visibility`.
- **Jira labels are set membership.** `project = MAGIC AND labels = "<value>"` matches every issue
  carrying that value, never one issue alone. Measured 2026-11-21 09:52 to 09:56 +0200: an item-key
  label matched two issues, and a state label matched 41. A value no issue carries matched none.
  Every answer reported `isLast=true`, so each set was complete. The match ignores case: the
  upper-case spelling of the state label returned the identical 41 issues. Two write behaviours,
  measured by `magic-coordinator` at 2026-11-20 18:36 +0200. A whole-label write through
  `--fields-json` replaces the list. An add/remove pair through that path answers 204 while
  writing nothing.
- **Jira lists**: paging values are whole numbers, refused when wrong. Every list states
  `more: no|yes|unknown`. `sprint-list` checks the board type and the `SPRINTS` feature first: kanban
  and disabled simple boards print an empty list with `more: no`. It never
  matches localised error text.
  Agile reads return the site's JSON; Confluence listings render TSV.
- **Confluence gotchas**: REST v2 has no rendered form (`storage` or `atlas_doc_format`). `page-search`
  and `comment-read` have no completeness signal (`more: unknown`); `space-list`
  (`/wiki/api/v2/spaces`) terminates via `_links.next`, and its cursor passes through verbatim.
  `space-create` is that endpoint's `POST`, coordinator-only and with no client twin: its documented
  404 is the account lacking permission to create spaces, so it is a refusal and never a missing
  space. Its `--key` is the space's own address, so a key outside letters, digits, `-` and `_` is
  refused before anything is sent.
  `page-create` needs the numeric space id (`--space <key>` looks it up, refusing 0 or many matches).
  `page-update` is version-gated: the caller passes `--version <n>`, the op
  sends `n+1`, and never re-reads, since that would defeat the lock. It is a
  full `PUT`, so `--title` and `--status` are required. On 409, re-read, never
  resubmit. `comment-add` is storage only; a reply's parent on another page is refused.
  Write bodies are assembled by hand with `AgentsMcpJsonEscape.awk`; every field has its own flag.
  An attachment is `AgentsToolsAtlassianCall`'s seventh argument: one file,
  multipart under its base name with `X-Atlassian-Token: no-check`, never with
  a JSON body. A path holding `;` `,` or `"` is refused (curl `-F` syntax). The v1 `/wiki/rest/api/content/<id>/child/attachment` takes it.
- **Google publish ops** (`folder-find`, `folder-create`, `file-upload`,
  `doc-import`, `file-trash` in `AgentsGoogleApiCall.py`) have no stub.
  Tooling calls them in context through `AgentsToolsGoogleCall`
  (`--intern-artifact-publish` the first four), which is why
  `AgentsTools.MemberCommsGoogle.include` is dual-use like the Atlassian one. `file-trash` is `files.update` with `trashed=true`, restorable;
  the worker has no `files.delete` and none is to be added. `permission-domain` makes one `type=domain`, `role=reader` permission for the
  caller's own account domain, from `about.get`, never configured, and never
  `type=anyone`. It sends no `sendNotificationEmail`, which Drive documents as
  for users and groups only. The publish applies it to every folder it makes and every file it publishes,
  not trusting inheritance alone. A published document left unshared is rc 3,
  and is not announced.
  The team root is made by people, so sharing it is theirs (or a one-off call of this op). Uploads are one
  multipart request, at most 5 MB. A folder search spans every drive the account sees (`allDrives`).
  Whether stored refresh tokens may create Drive files is not confirmed live.
  `page-update`'s all-required refusal still uses `/` for an alternation and should move to `|`.

## 20. Questions, decisions and review

- **`--read-pending-reply`'s list first rebuilds the pending-replies registry**,
  by the same rebuild `--make-harness-indices pending-replies` makes, so the
  file is current after any list. A read by one `<pending-id>` rebuilds
  nothing. Each open record also prints `asker-live:` before `question:`, whether the run
  that asked it is alive, measured as the read is made and stored nowhere.
  That is `running` (a process of this host runs as it), `no-process` or
  `session-ended` (nobody is there to take the answer). Or `no-spawn-record`,
  `other-host`, `host-unrecorded`, `no-session-id`, or `not-measured` (this
  read measured nothing, as when the registry could not be rebuilt). The record's `session-id` is the id of the run that asked, never of the
  coworking session that run joined. The asker is matched by it.
  The read itself acts on nothing: it closes, withdraws and re-asks nothing. Read by one `<member> <id>`, it prints those same lines, then
  `PENDING-REPLY-STORED: <id>` and what the stores hold of the ask. That is
  the whole question as posted, its options, its context, and a permission
  set's own entries.
- **The `AskQuestion` wait** takes only the addressee's replies and judges every reply since
  `question-ts`. Its own outcome, `ASK-RESULT:`, is one of `RECEIVED`, `TIMEOUT`, `DISMISSED`,
  `CLOSED` or `ERROR`. It is never `UNCLASSIFIED`, which is only ever an
  internal placeholder. Where a verdict read still carries it, it is folded
  into `RETURNED` before anything is printed. A typed verdict is the reply's first word when that word stands alone on the
  first line. It is also the verdict when a punctuation mark follows it and
  then the comment (`allow-once, only this file`; `deny. The path is wrong`).
  A word followed by more words with no mark is not a verdict. It may also be a declared reaction
  (`AgentsEscalationVerdict.awk`); no negation parsing. A numbered `decision` option keeps its own, more
  lenient match: `2 please` still answers option 2. A reply that names none of the answers returns `VERDICT: RETURNED` with
  `WAIT-ID:` and `NEXT:`. Re-waiting is the agent's choice. `pending_id`
  re-waits without posting, for the asking session only.
- **A member answering for someone else writes the word, a mark, and who decided**
  (`allow-once. The owner decided it`). A member with no Slack account of its own may answer with a plain reply in the
  session thread. The tooling knows who answered by the sender its post
  recorded, never by a Slack account.
- **The ask's wait is the session's `Wait`**: the item `ask:<pending-id>` joins
  the stored wait (`--wait-add`). It is resolved by `AgentsHarnessAskResolve`,
  called by both `AskQuestion` and `Wait`. Because of this, anything else of interest to the session can return the ask
  call first, as `ASK-RESULT: ARRIVED-OTHER` (see "Wait bounds"). The ask's
  own question stays open. **An answered question keeps its thread watched**: every close that answers it
  (the harness, collect, the escalation read, an escalation answer, a
  readback) sets `follow-floor`. That is the newest message of its own thread
  already read and kept, else the question. Its item stays in the Wait set
  until the session ends (or it expires, below). `AgentsWaitProbeAsk` then reads only what follows the
  floor, so a later message arrives as `ASK-RESULT: CLARIFIED` and is kept with the answer. **This "no
  closed line" is true of a thread-answered question only.** One answered by the team operation (`answered-session` set) gets its closed
  line every poll regardless of `follow-floor`. Nothing a person wrote ever
  announces that close, so the line is the one signal of it. Emitting it once
  is the content-diff layer's job below, not this probe's.
  The floor stays where the close set it. The Wait's own stored per-source
  BASELINE, not the floor itself, tells a new rendering from one already
  shown. It does so by comparing it to the last one returned. The clarify op
  keeps each message once. That baseline must carry forward from call to call for this to hold. It does
  for `--wait-continue`. It also does for a `--wait-default` call over a
  source the stored wait already had, *whatever `--wait-since-utime` that call
  also names*. `since_utime` is a Slack-source floor and has no bearing on a
  non-Slack source's own baseline. Gating the carry-forward on it too
  breaks that baseline: the unchanging closed line of a by-operation close then reads as new on every
  such call. Settled, withdrawn and Decisions-closed questions set no floor and leave the Wait set.
  **Two more ways an `ask:` item leaves a stored wait, besides the session
  ending**: `--unwait <kind>:<target>` (shorthand for `--wait-drop
  --wait-source <kind>:<target>`) drops it on demand. `--wait-drop` naming it
  does the same. An answered one is never dropped by age: however long it is quiet,
  a later reply in its thread still arrives. Dropping never blocks naming the same source again,
  explicitly, on a later call.
- **One question, one thread of its own** (`AgentsTools.AskThread.include`). To a person or a conversation the question itself is one new top-level
  message, with no opener, in the member's DM or the bot's (`as_bot`). Its
  thread is that question's whole conversation, and is never joined by another
  question. Only `to=<channel>:<ts>`, or any built-in alias with `:<ts>`, posts inside an
  existing thread. Only such a question is numbered, `Q<n>` per addressee
  under the ask lock. A top-level question carries no number, and its record
  has no `question-tag`. An identical open question returns `ALREADY-OPEN`
  and posts nothing. The same question asked again once closed (`SAME`; another session, since the
  asking session gets `NOT ASKED AGAIN`) goes into that question's own thread.
  It carries that question's number and the identity it was asked with. That
  is offered only where the asker can post again: asked as the bot, or by this
  member. A question asked with `to=<channel>:<ts>` naming the thread a question opened for itself is a
  follow-up on it and takes no new number (`AgentsToolsAskThreadRootTag`). A leading `Q<n>` in the question text is removed. A reply starting with a question's own number takes that form even where it is
  alone in its thread. The number and a following mark are stripped before
  what is read as the answer. A question posted as one top-level message of a **direct** conversation is
  answered where its person types there too. The messages after it in the
  conversation, by the account it was addressed to, are read as its answer.
  That holds when its own thread holds none
  (`AgentsToolsEscalationAskDirect`). A click under the post or a reply in its thread answers first, as it always
  did. A conversation several questions share is never read that way. An
  unnumbered reply there belongs to no question it cannot be told from. A thread several questions share is one the asker named. There a reply
  starting another `Q<n>` answers that one. An unnumbered reply answers a
  question only where no other stood open in the thread when it came, posted
  above it and not yet closed (`resolved-epoch`). Where several did, no question
  takes it: the escalation reader gets its head marked `AMBIGUOUS-REPLY`, and
  `AgentsToolsEscalationWhichAsk` posts one line in the thread, once a reply,
  asking its author which ask it answers. A reply naming one, or a click on that
  ask's own post, settles it. The human-owner's account always answers, after any
  member addressee (`AgentsToolsAskAnsweringAccountsInto`), and the account that
  posted a question never answers it.
  `AgentsToolsAskThreadOthers` feeds the others to `AgentsSlackThreadAnswers.awk`.
- **`AgentsSlackThreadAnswers.awk`** skips a member's own send header first
  (`memberSendHeaderLength`, `AgentsDismissalMatch.awk`). It does so on the
  head line, or on the first non-empty line under it where the header fills
  the head line. Without it, the header's own mark read as the reply's
  first word made every numbered reply from a member read as unnumbered.
- **`AgentsPendingReplyOwnWords.awk` runs the same header strip ahead of the
  answer-text and clarifications readers**
  (`AgentsPendingReplyAnswerText.awk`,
  `AgentsPendingReplyClarifications.awk`). So a member's own send header is
  never itself recorded as the answer. Nor is the answer under it recorded as
  a clarification. The rendering it reads keeps the header, for `Wait` and `DISMISSED` to
  read, so the strip runs only on the way into these two readers.
- **First line, then clarifications.** A reply's first line is its answer or verdict -- its first line
  that is no quote of the question. A ``` fenced block and lines starting with `>` or `&gt;`
  heading the reply are skipped (`firstUnquoted`, the same in the verdict, answer-text and
  clarification readers). The rest of that reply and every later reply from the person in the
  question's thread are kept as clarifications
  (`AgentsPendingReplyClarifications.awk`, `--intern-op-pending-reply-clarify`). They land under the
  record's own `## Clarifications`, and as `clarification` lines on its item's `## Decisions`,
  once each by ts. The
  harness, collect and the escalation read all keep them when they close a question.
- **A verdict-bearing reply's own words are returned too, never only the verdict.** Words in the same
  reply, beyond the verdict itself, print as `VERDICT-TEXT:`; a later reply in the same thread prints as
  `CLARIFICATION:`. A line of that text may read like one of the reader's own markers (`VERDICT:`,
  `WAIT-ID:`, `NEXT:`, `ASK-RESULT:` and the like). It is printed one space
  indented, so it is never taken for a real one.
- **A search of a thread shows each reply's own verdict mark ahead of its text**.
  So a scan finds the answered ones without opening each reply in turn.
- **A reply is its head and every line under it, up to the next head** (`AgentsSlackThreadAnswersSince.awk`'s
  rule). Every line is judged by the reply it belongs to, never by what the line itself starts with.
  A later message, kept as a clarification, is recorded whole.
- **Plain affirmations** (`AgentsEscalationVerdict.awk`) are a first word ok,
  okay, yes, agree, agreed, confirm or confirmed (also after "I", any case).
  They are also a +1, ok_hand or white_check_mark reaction. That is yes for a
  readback and, for a decision, the option whose line holds `(recommended)`.
  At most one may hold it, refused at ask time otherwise; with none marked it
  is RETURNED. Never for a permission or a proposal. There only the literal answering word is
  a verdict: alone on the first line, or followed by a mark and the comment.
  That word is `approved`/`rejected` for a proposal, and anything else is
  `RETURNED`.
- **The verdict reader skips the member send header**
  (`AgentsEscalationVerdict.awk`'s `sendHeaderLength`). A member's own reply
  starts with the team send's own header line, no part of the reply. So the
  first word judged is the first one after it. A `many` selection is sent by clicking its numbers then the `ok` mark, never
  the check mark. `white_check_mark` is the mark the tooling puts on a
  question once it is answered. So it is not also read as the mark that sends
  one. A question posted before this rule, naming the check mark in its own
  text, still takes it as the send mark. That holds for that one case only. A permission set answers as a permission does. `x` denies and `unlock` allows
  the set, both by click, deny first where both are held. `edit` carries its
  change in words and is never a click. A single permission ask offers one more click, `file_folder` (`allow-folder`),
  only for a file tool on a real path with no `..` segment. It grants that
  tool on every file in the refused file's own folder, until the session ends.
  It is never offered for a write in a read-only place, nor for a folder that
  is a whole workspace or HOME. A second click, `building_construction` (`allow-project`), is read the same
  way. It is offered only beside `file_folder` and only where the refused
  file's project is wider than its folder. That project is the nearest folder
  at or above it, in the source tree of a workspace, holding a `project.inf`.
  It grants the tool on every file of that project, the `project.inf`
  included. Either grant it writes is
  a set of that one entry, beside a record that stays of kind `permission`.
- **A click is read only ahead of the addressee's first reply.** Once a reply stands in the thread, a later click is never read as a verdict.
  That holds even where the kind declares that reaction a verdict (see "18. Slack").
- **The asker's readback** (`--readback-escalation`, EscalateDecision `pending_id`
  + `readback`) applies once a decision's reply names no option. Then its
  asker may post, in the question's thread under the ask's identity, which
  option it takes the reply to mean. The record closes with that verdict, `closed-by:
  readback` (on its Decisions line too) and `follow-floor: <readback ts>`; the replies are kept as
  clarifications. As for any answered question, a later objection arrives as `ASK-RESULT: CLARIFIED`
  and is kept. The asker only, never a permission, never before a reply, never over a reply that names
  an option.
- **Withdraw** (`--settle-pending-reply --withdraw`, AskQuestion `pending_id` + `withdraw`): the
  asker discards its own open question of any kind. Status `withdrawn` is a close status of its own, with `withdrawn-by` and
  `withdraw-reason`, never a verdict. So it answers, grants and decides
  nothing. Reminders stop, its Decisions line is `dismissed`, and a note goes
  into its thread. Its `ask:` item leaves the Wait set. The escalation read reports it `closed withdrawn`. The same question asked again
  after a withdraw is a new top-level post, never that thread's own reask. **A run that ends settles what it still has open**, at the close of its record
  and through this one operation (`AgentsToolsSpawnProxyWithdrawAsks`,
  `AgentsTools.SpawnSandbox.include`). AN ANSWER ALREADY GIVEN OUTLIVES THE RUN THAT ASKED (S6.33): each
  of the run's open records is read once by the collect's own reader
  (`AgentsToolsPendingReplyCollectOne`) before anything is taken away. An answer standing in its
  thread closes the record `reply-received` with that answer, and goes to the asker's inbox as the
  note of an answer that arrived after its session ended
  (`AgentsToolsPendingReplyAnsweredNote`), where whoever runs as that member next -- its duty --
  finds it. The question is never withdrawn over an answer nobody read, and nobody is told no answer
  is needed. A READBACK, DECISION OR PERMISSION IS READ THE SAME WAY, by the escalation read that
  applies a verdict (`--intern-op-escalation-read`), with the reader's typed switch on: at the close
  of the run that asked, no other run is left to read it, and the read takes a verdict only from an
  account that may give one. Its answer closes the record and goes to the inbox by the same note.
  Nobody is
  left to hear the answer of the rest, so
  the asker's own questions close as withdrawn by the member that asked. The
  reason is the note template's `Reasons/asker-ended`. A question the tooling
  asked *about* the run (a review prompt, kind `review`) is not the run's and
  stays open. A finished session therefore leaves no
  `reply-pending` ask behind, and the session state counts any ask that still waits as waiting.
- **Collect** (`--intern-op-pending-reply-collect`, `AgentsTools.PendingReplyCollect.include`), no model:
  reads each open plain question once with a zero-bound wait. Readbacks, decisions and permissions are
  never collected by default. Runs at `SubagentHandback`, at spawn close (marking `collect: ended`) and in
  the main loop (`--ended`, answers go to the asker's inbox). The `--ended` pass also takes asks older than
  `MDAT_PENDING_COLLECT_STALE_MINUTES` (120), up to
  `MDAT_PENDING_COLLECT_STALE_MAX` (40), and applies typed verdicts. It closes
  asks of still-running sessions quietly (`MDAT_PENDING_CLOSE_QUIET=1`). Quiet
  applies only to an asker that is itself alive, told by
  `AgentsToolsRegistryAskersLive`. That is a member that joined a session by
  its own id, or a root session by that same function.
  Results in `.local/agents/pending-collect.last`.
- **Remind** (`AgentsToolsPendingReplyRemindRun`, `AgentsTools.PendingReplyRemind.include`), tooling only,
  every main-loop iteration: at 30 min, 2 h, and daily after 09:00 local for asks 4 h+ old
  (`.local/agents/pending-remind.daily`). Always a reply in each ask's own thread, never a top-level
  message (`digests=` stays 0 in its summary line). Sent as the ask's owner under `ask-identity`. A failed
  send stamps nothing.
- **A pending record never expires by age**, and a reminder never closes one. Every close holds the
  record's lock; `--if-open` makes a second closer get `ALREADY-CLOSED`. A resolved question gets
  reactions (`:eyes:` on the answer, `:white_check_mark:` or `:ballot_box_with_check:` on the question);
  a failed reaction never undoes a close. `ProposeApprove` is the exception: it puts no tooling mark on its root at all,
  in open or resolved state. The owner's own reaction there is the verdict
  itself, not a mark read back from one the tooling placed.
- **Decisions** (`AgentsTools.ItemDecisions.include`): a pending record links its item (`task_ref`, else the
  session's `spawns:` item). Every close appends one line to the item's `## Decisions` (marked `<!--
  decisions-of: <item> -->`) via `--intern-op-decisions-append` under a
  per-item lock. A dispatch item's line also goes to its `tracks:` task. A received answer clears matching `blocked-on`/`condition`.
  `--intern-op-pending-reply-earlier` stops asking the same thing twice (`NOT ASKED AGAIN`). Decisions are
  shown first (30 lines) in briefs, `conversation.md` and scans.
- **Review** (`AgentsTools.ReviewFlow.include`): only a `running` item enters `review` of itself (handback,
  child ended without handback, `--wait` pass ended, `--request-review`). A verdict that starts its run again,
  a dead run's answer or a review return, first puts the item into `review` from whatever state it stands in
  (`AgentsReviewPutIntoReview`). The review limit
  (`REVIEW_WAIT_LIMIT`, default 3600 s) is enforced by `Wait` itself, returning `DISMISSED`, so it needs
  no main loop. It dismisses no run while another participant of its session runs (section 11). It does not run while a question about the death of a run stands open in the
  waiting run's session (`AgentsReviewWaitLeft` asks
  `AgentsToolsSessionControlDeathQuestion`). It counts again from that
  question's close. Verdicts `--accept-review|return|reject|follow-up` (`--intern-op-review-*`); a
  return restarts the session through the proxy's join path. Endings (`archived`, `trashed`,
  `shutdown`, `taskstop`, `review-wait-expired`) are recorded as `dismissed:` lines. A parent with no
  thread gets `parent-thread:` written on the child's record. The end of a run is told to the session that requested it (see "The end of a
  run is told", section 11). The note decides nothing: the item's review does.
- **Session transcripts** (`AgentsTools.SessionTranscript.include`): one per spawn in
  `audit/YYYY-MM/session-<startUTC>-<member>-<sid8>.log`, rolled at 8 MB (`MDAT_TRANSCRIPT_ROLL_BYTES`),
  named before the dispatch item exists, located via `.local/agents/sessions/<spawn-id>/transcript`. No
  pointer, no writes. One formatter, `AgentsSessionTranscriptFormat.awk`. Never file content. A native
  claude spawn is written from its stream (`AgentsClaudeStreamJsonTranscript.awk`, marks
  `transcript.stream`). Commits at milestones only. `sessions/<sid>/tokens` becomes the item's `tokens:`
  header; rollups are summed when shown, never written up the chain.
- **The event-track thread is the session's debug feed**
  (`AgentsTools.EventTrackFeed.include`). It is one open post, sent 7 s after
  its first line and sent early by no line. An error, a refusal or a session
  event waits with the rest. The feed is polled every 4 s, under 12 s from a
  line to its send; fixed in code, with no knobs. It is rendered as Slack
  `container` blocks by subject. A subject carries a title and a subtitle with
  the time of its first line. Its lines go in section children, and secondary
  details in a context child. Every operation is one templated line, never a
  raw line. A section is capped at 3000 characters, a box at 10 children, and
  a post at 50 blocks. A post whose blocks Slack
  refuses goes once more as plain text, cut at 4000 characters (Slack's `text` limit), with a warning. Its root, the spawn's `start` post, is posted once, after the CLI and the rest
  it names are resolved. No post is ever edited. A later fact, such as a
  different CLI launched or the end, is a reply in its thread.
- **One outbox paces every post into the event-track channel**
  (`AgentsTools.EventTrackSend.include`). Each post is queued under the
  channel's own append lock, numbered in the order it was made, and drained by
  one sender at a time. That covers the feed's collected lines, a start or end
  post, a refusal, a grant, a denial, a notice, and a handback. It also covers
  the activity lines of a batch. The oldest goes first, and never two messages closer than 7 s (fixed in code).
  Its window opens at the later of the last message into the channel and the lead record's own
  arrival, so a post that finds the channel quiet waits its own 7 s and collects the burst it
  leads. A `feed` record is exempt, its poster having collected its lines already, so two
  participants' feed lines never share a post. What queued during that window is collected into
  the same post. That needs the records to agree in member, kind, session, target, channel and thread,
  and to carry no fields. So only lines are joined. A post over Slack's limit is still cut by the post op into ordered follow-ups,
  each paced the same way. Nothing is lost, nothing is reordered, and no
  immediate post jumps the queue.
- **One event-track thread per coworking session, one record**:
  `sessions/<session-id>/event-track.thread`
  (`AgentsTools.EventTrackThread.include`). That module is the only reader or
  writer of it. The first post to open it wins, and the first record stands. A poster resolves the thread for the id it was given, a spawn's own or a
  session's. It takes its own store's thread where that store already holds
  one by itself, kept from before this rule. Otherwise it takes the session's
  record, found through that spawn's own record (`spawned/<sandbox>/<id>.md`,
  its `session-id`). A spawn that had no feed before this rule takes its own
  spawn record's `agent-log-thread` alone. The sandbox pointer this replaces, `spawned/<sandbox>/event-track.thread`, no
  longer exists: housekeeping reads the one session record instead.
- **The feed is one poster per participant**, with its own buffer `sessions/<own
  id>/feed` and switch `sessions/<own id>/feed.open`. Only what starts a
  poster switches the feed on. So a thread recorded for a session with no
  poster buffers nothing. It posts into the session's thread, never one of its own. A detached run's own feed poster goes on through a hangup, as the run does. It
  traps a hangup only where one is not already ignored where it starts. Its
  proxy ends it when the run ends, and only while its pid is still the process
  the proxy started (`AgentsToolsSpawnProxyHelperBegan`,
  `AgentsToolsSpawnProxyHelperEnd`). The poller of the launch and the reader
  of a waited run's log are the same. One not signalled is not waited for.
- **Event-track subjects are `session` and `run`.** The thread's root post is the session's start, and the starting spawn's own
  run start sits inside it. A spawn that joins an already-running session
  posts its own start as a reply, never a root. A run's end is that one
  participant's own end, never the session's.
- **Task text has one reader, `AgentsTools.TaskText.include`** (`AgentsTaskText.awk`): a board item's
  title and a few-sentence text, cut at a sentence end, both redacted. The event-track start post and the
  Permission set post each fill their own text through it, never their own reading of the item.
- **A session alone has a tracking thread only, in `event-track`; it has no session thread.** The first
  member it brings in opens the session thread, in `magic-team`, addressed to that member. A thread of
  the `event-track` conversation is never a session thread and never a parent thread. The notices `handback missing` and `question open` go to the tracking thread.
  The session thread instead gets a message addressed to the member that
  brought the run in.

## 21. Permission refusals and grants

- **A refusal is a recorded fact.** A harness Write/Edit is refused by the write-root check or the unattended
  team-store rule. A Read/Grep/Glob is refused by the read-root check
  (`AgentsHarnessReadGate`: read roots, else `AgentsHarnessGranted`, the same
  grant-read the write gate and the native hook ask). It writes
  `.local/agents/sessions/<id>/refusal-<uuid>.md` first
  (`--intern-op-permission-refusal-log`), then posts to event-track. The result adds `REFUSAL-ID:`
  (`none` without a session or record).
- **A skill linked in from another workspace still needs an ask.** magic-librarian's standing `.md`-edit
  grant covers only a real skill folder in the HOME skills folder, or one linked there into this
  workspace's own source tree. From this workspace that excludes the `client-*` members, every
  `keeper-*` but `keeper-myx`, and the partner members, linked in from elsewhere.
- **Grant and denial posts exist in event-track, beside the refusal post.** Whichever way an escalation's answer came, a `grant` where an allow is written
  and a `denial` where a deny is applied post once each. Both go into the same
  session thread the refusal opened.
- **A permission post shows its target as `<place>:<relative path>`** where it
  lies in a registered place
  (`AgentsToolsPermissionPlaceHint`/`AgentsToolsPermissionShownTarget`).
  Otherwise it shows the target as given, never the absolute path beside it. One resolver serves every permission post, the Permission set post included
  (`sh-lib/templates/permission-set.post.format.md`, which groups its asks by
  place). It takes an optional `--purpose` per place. The record behind the post always keeps the exact, absolute target:
  only what is posted is shortened. `.skillset-shared` and `.skillset-.local` are two such places, built
  in, needing no registration (see "Places", section 6). The post leads with a line the tooling writes from the refused call. It names
  the tool, the place and the member. The member's own words say only why.
- **Grants are keyed by session, member, tool and target** (resolved path, or exact command bytes), taken
  from the record, never the ask's text. Allow-once is spent by one `mkdir consumed/<id>` when the gate admits the
  call. An unused one lapses `MDAT_PERMISSION_ONCE_TTL` seconds (default 300)
  after its grants-line stamp. That holds for reads and writes alike
  (`AgentsToolsPermissionOnceLive`). Planned allows come from the session's dispatch item (matched by `session-id:`
  or `spawn-id:`) and its `tracks:` item, `session` or `task` entries. They
  are never signed by the session's own member, nor by one who does not hold
  the entry.
- **What a member holds is one computation**
  (`AgentsTools.PermissionHolds.include`, `--intern-op-permission-holds
  <member> <tool> <target>`, `HOLDS <layer>` or `NOT-HOLDS`). The first layer
  is human-owner: his name or `SLACK_CHANNEL_HUMAN_OWNER`. Then the `floor`
  layer: the team tools, the member's floor rows of `grants.index`, and its
  session's own sandbox. Then the `standing` layer: its own rows of
  `grants.index`, with every `*` row unrolled there. A `write` row, from
  `allow-write`, is every file tool on its glob. A `read` row, from
  `allow-read`, is Read/Grep/Glob only. `tool` rows `<tool>[:<target>]`, from
  the `allow-tool` declare verb, are never projected into Claude settings. A
  permission is decided on the real file, and a link and its target get the
  same answer. Then come `set`/`passed`/`granted` session or task grants. No write tool is held in a read-only place, through any layer. `cred` and `spend` skip floor and
  standing. Grant-read admits floor and standing as `GRANT: standing`.
- **No approving what you don't hold.** `grant-open` returns rc 3 with `NOT-HOLDS:` and `HOLDERS:`. The escalation
  verdict path checks first whether the named addressee holds the call and can
  be reached. If not, it re-addresses the ask to a holder running in this
  coworking session (`AgentsToolsPermissionHoldersPrint`). Failing that, it
  forwards the ask to the human-owner. The ask stays open. Each
  re-address adds one `NOTE:` line telling the asker who it went to and why.
- **A grant can say `approve`.** An `Edit` or `Write` it covers is neither refused nor applied: it is
  held. The call returns `HELD` at once with a `WAIT-ID:`; nothing is written, and a `Read` still shows
  the file as it stood. The team bot posts "Change for approval" to the human-owner, with the diff; he
  answers `approve` or `reject`, by click or by word. On `Wait` the member gets his verdict, with his own words. It also says
  whether the change was applied, dropped, or could not be applied because the
  file changed meanwhile. In that last case the member makes the change again. One `Edit` call, its `edits`
  list included, is one change and one held prompt. A grant given for one task, one session or one call
  comes ahead of the `approve` kind: under it, an `Edit` writes at once.
- **Kind `task`** lives while its item is in an open board state (`<refusal>.task` sidecar or the
  record's `task:`). Passed (`pass-<uuid>.md`) and set (`set-<uuid>.md`) grants are records like a
  refusal's, `owner:` the receiver. They are kept in the coworking session's
  store. A session reads its own, its coworking session's and its parent's
  store, its own grants only. A passed or set target may be a
  `<path>/**` or a `<url-prefix>*` pattern; a refusal's grant is exact.
- **Harness read and write roots are per member**. A named member's declared
  grants are its own rows and every row declared for `*`, that is every
  member. So it reads the read floor plus those `Edit` and `Read` rows, and
  never the harness index's union. A served call with no `MDAT_SPAWN_AGENT` keeps every member's rows: the
  human-owner's own session, under the default identity. A native client gets
  its member's roots (section 14).
- **A named member's file tools are decided by its session permission index** when
  the harness is given no root flags. That index is
  `sessions/<id>/permissions.<member>.index`: the member's rows of
  `grants.index`, joined with the session's own grants. Those are the session,
  task and once grants, from its own, coworking and parent stores. It is built the same way for a member that joined a session as for the one it
  was spawned for. The header, the sandbox folders, the origin and the stores
  reach the one awk in the environment. They never arrive as arguments.
  Every check is builtins only. There are two `-nt` tests: the index must be
  strictly newer than `grants.index` and every joined store's `grants`. Then a
  loop of `[[ ]]` runs over rows whose globs were translated into bash
  patterns at the rebuild (one awk). The ceiling first: a write in a read-only place is refused, not recorded, naming
  the session sandbox `output/` or "find another suitable location". A once row's expiry and use, and a
  task row's open item, are checked only on the row that matches. Opening, using up and revoking a
  grant touches the store's `grants`. Children's folders and the member's own directory are admitted at run time.
  The routine and planned layers are asked only on the way to a refusal.
- **A session grant ends with the session whose store holds it**. That is its
  spawn record (`spawned/*/<store id>.md`) closed with a `spawn-*` status
  other than `spawn-started` (`AgentsToolsGrantsSessionEnded`, builtins only). Checked on read (`AgentsToolsPermissionGrantScan`,
  and the matching session row of the session index, since a joined store's end touches nothing);
  the rebuild drops them. A session with no spawn record ends by its client's `SessionEnd` hook
  (`sh-lib/client-hooks/root-session-end.sh`, class `native`). That is a root
  session: the human-owner's own, or an interactive native console. The hook
  writes `sessions/<id>/ended` plus a store touch, marks its open asks
  `--mark-ended`, and puts END in its transcript. A `SessionStart` resume
  removes the marker. A coworking store ends with the spawn whose id it carries.
- **A restart on the same board item keeps its session and task grants.** A session grant given to a member's run on a board item holds for its other
  runs on that item too. Those are the runs a review return or a resume starts
  under a new id, in the same coworking session. It holds until the item is
  closed or that session ends (`AgentsToolsGrantsItemRuns`). The call checks a
  `runs` row of the index, the item and that session. A task grant given to that run holds the same way, while the item it names stays
  open: a `task` row like any other. A run started since the index was built is found on the way to a
  refusal (`--intern-op-permission-grant-read`).
- **A write grant reads too.** A session, `runs` or `task` row for Edit, Write or Execute admits a Read,
  Grep or Glob of the same target as well (`AgentsToolsGrantsToolCovers`). It never works the other way
  round.
  rc 1 when no row admits the call. magic-librarian's own standing `write` row for a team-member skill's
  `.md` files admits the same Read, Grep and Glob of it, the same way.
- **Revoke** (`--revoke-permission <ref>`, implemented as `--intern-op-permission-revoke`):
  `<store>/revoked/<ref>`, a file (awk tests it by `getline`, which cannot tell a directory), then
  `AgentsToolsGrantsStoreTouch`. Every reader skips it. A task grant's entries also leave its item's `task:` through the board edit
  primitive. Those are its `allows:` grants lines without the trailing ref,
  the form set-apply writes. A `verdict` line goes on the item's Decisions,
  best effort.
- **A request rerouted up the chain gives no verdict in its own thread.** Reading it prints `VERDICT: RETURNED` with a reason naming why it was
  re-addressed and who it is addressed to now. So a reader never mistakes
  "nobody has answered yet" for "the reply named none of the answers."
- **An ask addressed to a routine** (`to: <name>.routine`, typed kinds only) posts
  nothing. The harness records it with `address-to` the routine, and waits on
  the record. That is as for a member with no Slack account. `AgentsToolsRoutineFile` (TeamRegistry) is the one routine lookup.
  `AgentsToolsRoutineIsExecutor` (ItemDecisions) admits its executors to the
  answer and the forward. A reroute forwards as the executor answering. `AgentsPendingAsksForRoutine` (ReviewFlow) lists one workspace's open asks per
  routine, oldest first. `--intern-op-permission-escalation-input-scan` reads
  every known workspace's, each ask read against its own (`MMDAPP` set in a
  subshell). The record also keeps `task-ref:` and `reason:`.
- **The coordinator's work-duty scan lists the open asks addressed to magic-coordinator**, of any kind and any owner, under
  `## open asks addressed to magic-coordinator`. It reads the kept `pending-replies` registry: the ask rows with status `reply-pending` and
  blocked-on `reply_from_magic-coordinator`. It never walks the store. An ask's open and its close rebuild that registry
  (`AgentsToolsRegistryRebuild pending-replies`), so a new ask is listed at once and the duty's wait wakes on it.
  `AgentsWorkDutyCoordinatorScanCheck` holds it.
- **`RequestPermission` itself takes `entries`** (`Tool,Tool:<place or
  folder>/**`, one `purpose:` line covering the entries above it). So it
  becomes one Permission set for the asking member's own task. No `to` is
  needed, and one answer grants all of it. A second single-call ask from the same session for the same task returns a
  correction. It orders a set instead, once the owner has answered the first
  ask.
- **A member's own set does not ask again for what is held** (`--intern-op-permission-set-ask`). An entry the
  asking member holds now, through the session's grants among others, is not asked: the answer is
  `PERMISSION-SET: held`, nothing posted, no permission edited. Every entry it holds, its own floor row and
  standing row included, leaves the ask itself, so a mixed set asks only the rest and the post's
  `Already held` group names a participant that passes the entry on, never the asker's own grant. An entry another participant with a live run in the session holds returns a
  correction naming that participant. Ask them, or have them pass it on. A request sent again is
  no override: the same correction comes back. The call says `--escalate`, or `escalate: true`,
  when the member needs the access itself, and it is asked as it stands.
- **One call asked alone keeps that rule** (`AgentsHarnessAsk`). A call a participant running in
  the session holds is not put to the human-owner: the asker gets a correction naming the holder.
  `escalate: true` asks it as it stands. A call the asker holds now is not asked either; the
  member is told to make the call again. A routing to a named member is unchanged: only the
  human-owner named is refused this way.
  `AgentsPermissionHoldsCheck` holds it.
- **A further refused call joins a session's already-open permission question**
  instead of asking anew (`--intern-op-escalation-permission-add`). That turns
  the open prompt into one Permission set. An answer already given to it is
  not widened by a later join. An entry's tool is any name the gate can decide,
  an `mcp__` tool name included; an unknown name returns a correction, posting nothing.
- **Place names at request time.** `--request-permission-set` takes `<tool>:@<name>[:<glob>]`,
  resolved by `--intern-directory-resolve` and `pwd -P` to the path it is asked for; an absolute path
  stays allowed. A write in a read-only place is refused there and in `grant-open`, before the
  holds check. The human-owner holds everything, and the harness would refuse
  the grant anyway. The refusal names the route. The `name:relative` hint (`--intern-directory-of`) is printed as `PLACE:` and recorded as
  `<ref>.places` (natural target, TAB, hint) beside the grant's record, the way `.task` is.
- **Pass** (`--pass-permission`, implemented as `--intern-op-permission-pass`;
  `--kind once|session|task`): its `--target` goes through
  `AgentsToolsPermissionEntryPlace` first. That resolves `@name`, refuses the
  ceiling with its route, and writes `PLACE:` and `<ref>.places`. Then come
  the holds, lifetime and participant limits. `--kind session` also needs the
  passer in `AgentsToolsPermissionParticipants` of the session. One `pass-<uuid>` grant, signed by the passer, lands in
  `AgentsToolsPermissionShareStore`'s store, then
  `AgentsToolsGrantsStoreTouch` runs. A session pass ends with that store's
  session, and every pass is revoked by its ref.
- **`--list-permissions` / `--list-permissions`** (`--intern-op-permission-list`)
  are `AgentsGrantsSessionIndex.awk` in `mode=list`. They take the same
  filters as the index, plus a once grant's use and TTL and a task's item,
  read in the awk.
- **`allow-read` is `allow-write` without the write**. It has the same
  `<scope>:<selector>:allow-read:<member>:<glob>` layout and the same selector
  resolution. Its rows carry `Read(...)`, so they join that member's read
  roots, and never a write set or `Edit`. No grant is written into the Claude settings.
- **Escalation kinds** readback, decision, permission and proposal always wait. `AgentsTools.MemberEscalation.include` applies a verdict once, under a claim.
  That claim is `<record>.answered/holder.<n>`, a symlink naming the process
  that applies it as `<host>:<pid>:<start>`. The holder in charge is the one
  of the highest `<n>`. A holder found gone is taken over by the next number while the record is still
  open. Gone means no such process on this host, or one that started at
  another time. A holder still alive is respected, and so is one on another
  host, which cannot be seen from here. `mkdir`-ing the claim directory only marks who made it first; the real
  arbitration is the holder chain.
- **Asking the human-owner.** A member with no Slack account of its own has every ask posted by the team
  bot: question, readback, decision, permission. A plain message goes the same
  way. It lands in the bot's own conversation with him, with the answer emoji
  placed on an ask. No relay through a session's
  `magic-coordinator` stands between: each member reaches him this way directly. A `RequestPermission` goes there the same way whatever the asking
  member holds. A resolved question's own marks are placed under the identity its record names, not
  necessarily the asking member's own. A refusal that one open ask would already answer names it instead of inviting
  a second one. Those are the `OPEN-ASK:` lines of the grant read. Wait on
  that ask's id and retry the call.
- **An answer applies in a fixed order**. The verdict is noted, the grant an allow
  carries is written, then the record closes. It carries the verdict and who
  gave it (`AgentsToolsEscalationApply`/`AgentsToolsEscalationApplyFinish`). A read that finds an apply stopped partway completes it from
  where it stands, rather than redoing it. An allow whose grant cannot be written is not applied at all. The note and the
  claim are given back, and the request stays open, read as `VERDICT:
  RETURNED` with the reason.
- **Attended only for an interactive Claude Code client**: `CLAUDE_CODE_ENTRYPOINT` `cli` or
  `claude-vscode`, no `MDAT_SESSION_UNATTENDED=true`, no spawn id. To admit a new surface, add it to the
  `case` in `AgentsHarnessUnattended` and in `sh-lib/client-hooks/permission-request-escalation.sh`. An
  unattended session never Writes/Edits the team store or session store.
- **The boundary is honest agents with an audit trail.** All of this is plain local state; `execute` can
  write any of it.
- **Targets are stored natural.** The record escapes `%`, newline, CR and edge whitespace only
  (`AgentsToolsPermissionEscapeRecord`); the grants file also escapes `,` and `:`
  (`AgentsToolsPermissionRecordToGrantField`). `AgentsHarnessRefusedTargetDecode` is the exact inverse,
  `%` last.

## 22. Test instruments

Each instrument states what it proves and its red recipe in its own header. What a maintainer must know:

- **The suite line is more than one lane, and the lane count comes from the pace a tool call finds.** Every run, of
  the whole suite or of named tests, waits its turn machine-wide, in arrival order (`AgentsRunQueueTurn`, ticket
  files under `$HOME/.agents/magic-team/suite-queue`, never under the package). A run then takes a lane, of as many
  as `$HOME/.agents/magic-team/suite-lanes` allows, and gives it back when it ends. The count is the machine's own
  ceiling (`suite-lanes/max`, 3 unless it holds a number) times `pace-floor` over `pace-now`: the floor is the fastest
  pace this machine has shown, a slower pace never raises it, and it is read afresh once it is a day old.
  `AgentsRunPaceMs` times one fixed piece of the shell's own work, no fork, best of three. Load average is never the
  measure: at load 19.8 measured at 04:16Z on 2026-11-04 the pace had already returned to its fastest. A test whose
  header carries `## lane: alone` measures its own timing, so its run takes every lane (`AgentsRunAloneWanted`).
  A run has one worker unless `-w` is given. The line is said once per wait, naming who it waits behind. The hand
  rule this replaces is `mkdir $MMDAPP/.local/temp/suite-run.lock` around a run, and it is kept on both sides: a lock
  taken by hand shuts every lane, and so does the lock of a runner from before the lanes, which writes no
  `lanes: yes`. `AgentsRunTestsQueueCheck` section 9 and `AgentsRunTestsLeakCheck` section 8 hold all of it.
- **A lane is given back once its own record names a run folder holding a receipt for every check it took the lane to run**, whatever its holder's process does then. That holds on lane 1 and on every numbered lane alike.
- **The lane's record carries `checks=` and `rundir=`**, written when the lane is taken and again when the run list settles.
- **Freeing a lane also takes that run's ticket out of the machine's line**, so no waiter stands behind a turn that never comes.
- **A lane read stays free of folder walks.** `AgentsRunLaneFree` runs on every wait pass, so the folder and the count come from the lane's own record. Its `tests.list` is read only where the record names a folder and no count.
- **`sh-test/common/AgentsRunTestsLaneReleaseCheck.test.sh` holds that surface**, over a lane whose holder lives while its work is done, on lane 1 and the numbered lanes, with its kept-lane controls.
- **Nobody sits on a wait.** A run that must wait for its turn, and was not given `--wait`, starts a run of itself
  detached, which takes its very ticket over, so the line keeps its order. The call then names the ticket and the run
  folder, and returns 75 with no result yet: `progress.txt` there fills as checks end, `summary.txt` comes once the run
  has ended, and `runner.log` holds its own lines. A caller that needs the verdict in the same call, as the retest drain
  does, passes `--wait`. `AgentsRunTestsNoWaitCheck` holds it.
- **The retest queue is machine-wide too**, beside the suite queue at
  `$HOME/.agents/magic-team/retest-queue` (`AgentsTools.MemberRetest.include`), shared by the live tree
  and every scratch copy. A session that changed something asks for what to retest and goes on:
  `--retest-queue` waits for no test. The tester takes everything that waits as one batch
  (`--retest-drain`), each test once however many requests named it, and who asked reads the outcome by
  its id (`--retest-result`). A request is `<field>: <value>` lines, put in place whole by one rename,
  and it stands in `waiting/`, then `running/`, then `done/` for seven days. The rename into `running/`
  is what makes it part of that batch and of no other. A changed test is covered by itself; of any other
  file the tooling keeps the file, and the batch runs every test of the copy that has not passed in the
  state it is in then. Nothing of the queue posts anywhere: the tester's session reports.
- **The tester family is one thin stub per testing operation.** `DistroAgentsTools --tester-<operation>` is
  `DistroAgentsTesting.fn.sh --<operation>` and nothing else, for the 13 operations of the one list in
  `DistroAgentsTools.fn.sh` (`agentsTesterOperations`). A name outside it is refused with the list.
  `sh-test/member/AgentsTesterFamilyCheck.test.sh` holds the family to the testing tool's own help.
- **A test is a session of its own.** `AgentsRunTests.sh` hands a test nothing of the session it was started in.
  Every `MDAT_SPAWN_*` and `MDAT_SESSION_*` variable and
  `MDAT_CONVERSATION_THREADS` are taken out, and its session id is
  `rig-run-<test>-test-only`. So the suite gives the same result from
  a spawned member's session as from any other. `AgentsRunTestsIdentityCheck` is the test for this.
- **The runner hands the parallel driver its workers, never the tests** (`AgentsRunWorker`); a worker
  takes the next test by making that test's log file. So a run cannot stand still on the driver's own
  helper, as the old one could.
- **A run that stands still is ended with status 124.** The window is the test timeout, plus
  `--stall-margin` (120 seconds by default), plus the yield's whole budget of three 120-second
  phases. A run counts as standing still once nothing changes in its run folder for longer than
  that window. The yield is why: a run that gave its lanes up leaves its run folder unchanged while
  it waits. `summary.txt` then gets a `STALLED` line, and `stalled.txt` in the run folder names what
  never ran and what never ended. `AgentsRunTestsStallCheck` is the test for both.
- **`AgentsMcpCallWatchdogCheck`** is the test of the watchdog of a served call
  and of `execute`. It also tests the kill action of a job and the two group
  functions. `AgentsConsoleSessionSignalsCheck` is the test of the pid files
  and signals of a console channel. `AgentsConsoleStreamTrapCheck` is the test
  of the console's trap. The
  tooling list of `AgentsTestSignalsCheck` names no place left by the number alone outside the spawn
  proxy.
- **A check that calls the advance lock take, the main loop or the console's
  control-thread start ends the control threads of its own rig**. It does so
  through `sh-test/check-fixtures/rig-control-threads.include.sh`
  (`rigControlThreadNotes`, `rigControlThreadsEnd`, called in its `EXIT`
  trap). The guard for this is in `AgentsSessionControlStartCheck`, which
  fails a check of `sh-test` that names any of these outside a comment. The
  names are `--intern-op-routine-lock-take advance`, `--intern-main-loop`,
  `--manager-session-control-start`, `--intern-op-agent-spawn-proxy`,
  `--spawn-prompt`, `--spawn-session`, `--manager-spawn-member`,
  `--return-review`, `--intern-op-review-return` or `--intern-tool Agent`. A
  check that names one and does not do so fails. 35 checks carry the fixture. A thread whose rig is removed now ends at its own next tick. The fixture still
  matters, for the time until that tick and for a thread that runs older code.
- **A stand-in blocks on a pipe, never spins.** A rig process that waits with
  `while : ; do sleep 1 ; done` burns a wake-up a second for as long as it

  lives, and it lives past its check whenever the check is killed. It blocks on
  a read of a pipe instead, with the check holding the writing end
  (`sh-test/check-fixtures/rig-blocking-stand-in.include.sh`, `rigBlockingStandIn`): the
  kernel closes that end when the check's process ends, however it ends, and
  the stand-in exits by itself. No trap is relied on for it.
- **Four rig traps make a check lie.** A stand-in session needs `--session-id <id>` on its own command
  line, because the registry finds a session by it, and `bash -c 'sleep N'` alone execs the sleep and
  loses the flag: `bash -c 'sleep 600; :' <id> --session-id <id>` keeps bash in place

  (`sh-test/check-fixtures/manager-screen.live-rig.include.sh`). A liveness answer is served from
  `.local/agents/liveness/` for `AGENTS_LIVENESS_TTL` seconds, 30 by default, so a check that starts a
  stand-in and reads at once fails by timing: settle first, or read again. A scratch origin holds only the
  levelled packages, so a test that reads another package fails for no reason of the change: compare each
  failure against a run on live from the same hour. A new empty
  `.local/agents/spawned/.housekeeping.txt` breaks every "nothing else was written" assertion: treat it as
  baseline, or assert on content rather than on the file set.
- **A check run by hand stands in the machine's line of test runs.**
  `rigTempDir` (`sh-test/check-fixtures/rig-temp.include.sh`) takes a ticket in
  `$HOME/.agents/magic-team/suite-queue` before it makes its folder, the same
  line `AgentsRunTests.sh` stands in, so one check runs at a time however it was
  started. Six sessions running `bash <check>.test.sh` at once, around the
  queue, took this machine to load 133 on 2026-11-03. A ticket of the waiter's
  own session is no ticket ahead, which is why a check may start a suite and its
  own tests need no shared variable. **There is no switch to keep
  a check out of the line**: one existed for an evening (`RIG_NO_QUEUE`) and was
  used to bypass the line for real work. The check of the line runs against a
  rig with its own `HOME`, which is another line.
- **A place in the line is its run's, never a process's, and a place is given up rather than held by the gone.** A
  ticket carries `session=<session-id>`, the run's own id, and a `since=` second. Pids are never written on it: a number
  is given to another process, so a ticket naming one reads alive when its owner has long ended. A ticket standing ahead
  is given up, and taken out, when the workspace's records say its run has ended -- a spawn record settled, or a session
  store with the end marker -- and when it has held the line past `MDAT_SUITE_QUEUE_HOLD_SECONDS`, 21600 by default,
  however alive its run looks. A ticket that names no session at all was never written whole, and holds nobody's place.
  One naming `none`, a run the tooling gave no id, is judged by its age and beat alone, since no record of it exists to
  read. A run that waits writes a `beat` line each pass, and a beat that has stood still past
  `MDAT_SUITE_QUEUE_STALL_SECONDS`, 3600 by default, gives up its place: that bounds a holder that stopped working. A run
  holding a lane is running, not waiting, and neither bound judges it. The line says who holds it, from which copy, and
  for how long, and says so again when a place is given up. Measured on 2026-11-05: a full suite left by an ended run
  held the head of the line for almost 27 hours. `AgentsRunTestsQueueCheck` sections 4, 5b and 9 hold it.
- **A run refuses rather than waits for ever in the line.** It waits
  `MDAT_SUITE_QUEUE_LIMIT` seconds, 900 by default, then says in one line whom it
  waited behind, runs nothing, and gives its own ticket back. Two runs waited half
  an hour on 2026-11-03 before a person ended them.
- **The runner fails a test that leaves a process behind, and names it.** The
  slot keeper reads the test's tree and process group just before it ends what
  is left, and writes `leak-pids: <pid>...` and a `leak-pid: <pid> <command
  line>` for each, then exits 1. A rig that outlived its check therefore reports
  red and says what it leaked, instead of passing green.
  `AgentsRunTestsLeakCheck` holds it.
- **The runner's keepers run on the python this machine has, not the one on
  PATH.** `/usr/bin/python3` here is 3.9.6 and a rig may reach it first: its `os`
  has no `waitid`, and `os.waitpid` refuses `WNOWAIT` on Darwin. The slot keeper
  therefore reads an ended and unreaped leader from the process table (`ps -o
  stat=`), which works on 3.9 and on 3.14, on Darwin, FreeBSD and Linux. When it
  raised AttributeError, every test failed while its own log said OK — a green
  suite reporting red. `AgentsRunTestsLeakCheck` section 7 holds it, with the old
  python named as its control.
- **A test signals a process it kept only through one helper**,  `sh-test/check-fixtures/rig-processes.include.sh`. The helper notes a
  process with when it began, and signals it later only while its pid is still
  that same process. Process ids come round within about a minute here while
  tests run, so a kept number can belong to a stranger by then. `AgentsTestSignalsCheck` holds the helper. It is also the guard that fails on
  a new `kill`, `pkill` or `killall` in the tests that is not on its list. Its
  list holds `sh-test/member/AgentsWaitOwnPostRepliesCheck.test.sh` (`@probed`,
  `@own-watch`) as it holds `AgentsHarnessWaitCheck`.
- **Wired into `--owner-setup-scaleway --check`**: `HARNESS_PARSES`,
  `AgentsHarnessSelfCheck.test.awk` (four sites per tool; text match, so it
  misses syntax and JSON breaks). `AgentsHarnessToolsJsonCheck` (parsed vs
  text counts; reads through `AgentsHarnessJsonSlice.awk`, not the consuming
  reader). `AgentsHarnessAccessRootsCheck` (no-flag roots come from the
  include), `AgentsHarnessServedFloorCheck` (served set; a planted copy must
  be named as `MDLT_ORIGIN`). The leg checks `AgentsHarnessCopilotLegCheck`,
  `AgentsHarnessGrokLegCheck`: endpoint, host, credential pinned; models read
  from the leaf. `AgentsHarnessAnthropicWireCheck`,
  `AgentsHarnessRestartCheck`, `AgentsHarnessMcpCheck`,
  `AgentsHarnessWaitCheck`, `AgentsHarnessAwkAxiom.test.awk` (a statement and
  its closing brace on one line need `;`, for awks not on a dev box),
  `AgentsOwnerSetupCheck`.
- **`AgentsHarnessContainmentCheck.test.sh` is wired into nothing** and runs only by hand. It tests
  `AgentsHarnessResolveDir` and `AgentsHarnessPathAllowed` together, in both polarities.
- **The manager screen's tests** here are every `sh-test/AgentsManagerScreen*Check.test.sh`, 31 of them, all
  through the driver `sh-test/check-fixtures/manager-screen.driver.py` and the stand-in dispatcher
  `sh-test/check-fixtures/manager-screen.tools.stub.sh`.
  `AgentsManagerSessionListCheck`, `AgentsManagerSessionReadCheck`
  and `AgentsManagerSessionTranscriptReadCheck` are the three session operations' own.
  `AgentsManagerRoutineListCheck`, `AgentsManagerSpawnMemberCheck` and `AgentsManagerConfigDigestCheck`
  are the routine, spawn and config operations' own. `AgentsManagerSessionKillCheck` and
  `AgentsManagerTeamMemberCheck` are the kill and team-member operations' own. The tests of the other
  `--manager-*` reads are named with them in section 10.
  `AgentsSpawnReferenceOnlyCheck` is the no-start-for-a-reference-only-member rule's own. The screen
  starts on Manuals (Help), so a screen check that needs the first root selected says `root dashboard`.
  `sh-test/check-fixtures/rig-distro-workspace.include.sh` builds the distro workspace a check needs for
  `ListDistroProjects`; `AgentsManagerManualReadCheck` is its first user.
- **A screen check passes against the stand-in dispatcher, so a dummy passes too.** Nothing in those 31
  checks calls a real operation, so they prove the screen's own drawing and nothing downstream. A real
  run is what finds a dummy: a clean `env -i` scratch workspace as
  `sh-test/check-fixtures/rig-retest-machine.include.sh` builds, a real pseudo-terminal, and a logging
  wrapper between the screen and `DistroAgentsTools.fn.sh`.
- **Diff checks hold a rewrite to its previous implementation**, kept only as fixtures in
  `sh-test/check-fixtures/*.legacy.*`: `AgentsWireStreamDiffCheck`, `AgentsHarnessJsonFieldDiffCheck`,
  `AgentsHarnessHooksDiffCheck`, `AgentsRegistryRowsDiffCheck` (also `--live-copy-from <workspace>`).
- **Reaching a gated harness path offline**: set the dummy `HARNESS_*` a stub sets, put a fake `curl` first
  on `PATH`, use a `.invalid` host. The resolved roots travel in the system prompt, so the recorded request
  body is the observation. `--intern-tool` reaches no endpoint, so the tool gate itself is observable.
- **Three ways a probe passes and proves nothing**. First, a control that runs a
  different command shape (`find -L -type l` reports only dangling links).
  Second, a rig that lifts functions and silently misses a dependency (exit
  127, empty output, success). Third, a fixture under `$TMPDIR` that the
  access roots refuse, stubbed past. A rig must relocate the gate onto its fixture (`MMDAPP="$rigTmp"`, or pass the
  fixture as the allowed root). Or it must use the granted work directories
  `$MMDAPP/.local/temp/team`, `.../member/<member>`, `.../task/<member>`.
- **Other offline checks** are `AgentsSlackBlocksLinkifyCheck`,
  `AgentsSlackBareUrlLinkCheck` (through a real send with
  `sh-test/check-fixtures/slack-send-identity-check.curl.stub.sh`),
  `AgentsEmailHtmlPartCheck` (build-only), `AgentsSessionContextReadsCheck`
  (fake Slack and fake `imaplib`). Also offline are
  `AgentsSlackRateLimitCheck`, `AgentsCoordinatorStateNoteCheck`,
  `AgentsBoardRecheckInCheck`, `AgentsApprovalCascadeCheck`,
  `AgentsGroomingToBacklogApprovalClearCheck`,
  `AgentsVscodePanelInstallCheck`, `AgentsHarnessSkillRangeCheck`,
  `AgentsHarnessSkillReadCheck`, `AgentsRefusedTargetDecodeCheck`,
  `AgentsHarnessMcpIndexCheck`, `AgentsHarnessSetupIndexCheck`,
  `AgentsHarnessToolCallsReadCheck` and `AgentsHarnessArgTableCheck`, and the
  ask, pending-reply, decisions and review checks.
  `AgentsArtifactPublishCheck` reaches Google offline by a `sitecustomize.py` on `PYTHONPATH` that
  replaces `urllib.request.urlopen`, since the Google worker never calls curl.
- **`sh-test/AgentsSweepTimingInstrument.sh` asserts nothing** and is kept off `.test.sh` so no sweep runs
  it: `MMDAPP=<ws> sh-test/AgentsSweepTimingInstrument.sh [<latency> [<dms> [<clients>]]]`, `INST_KEEP=<dir>`
  keeps output.

- **A `.fn.sh` run by its relative path exits 0 and does nothing.** The file ends with a `case "$0"` guard
  that matches `*/myx/<package>/sh-scripts/<Tool>.fn.sh` and no other spelling, so a call made as
  `bash sh-scripts/<Tool>.fn.sh` from inside the package defines the functions, matches no arm, and exits 0.
  Measured at 10:23 on 2026-11-11: 0 lines on both streams that way, 230 lines by absolute path. Call the
  bare function, or the absolute path, and read the output rather than the status.
- **A failing command inside a probe ends the probe, so guard it in place.** The harness shell runs bash under
  `-e`, so an unguarded `false` stops the run there and every section written after it is absent. An absent
  section reads as "nothing to report". Measured at 10:23 on 2026-11-11, both directions: the unguarded line
  after `false` never ran, and the line after `false || true` did. Write `cmd || rc=$?` and read `$rc`, and
  read the output for the headings the probe promised, never for the ones that arrived.
- **`mark` refuses a scratch copy that is not live's text, so the recovery is a one-step window.**
  `DistroAgentsTestingApplyMark` refuses when the scratch file differs from live
  (`DistroAgentsTesting.fn.sh:244-246`). Dropping the path's line from `changed-files.txt` and marking it again
  works only while the scratch still holds live's text: one edit after that recovery brings the refusal back,
  and the path then sits in neither list. The precondition is the instruction: recover, then level and mark
  before editing again.
- **`level` has four behaviours, and only one of them is silent.** Measured on 2026-11-10, over the four file
  states: a marked file live moved under is `CONFLICT`, rc 1, the edit kept (`:277-281`); an unmarked file that
  no longer matches its `levelled.sums` row is `EDITED UNMARKED`, rc 1, the edit kept (`:285-288`); an unmarked
  file with no `levelled.sums` row is overwritten from live and the level still ends `LEVEL: OK` (`:290-293`);
  a file live does not hold and no level put there is `new, unmarked`, and kept (`:312-314`). Only the third is
  silent, so `LEVEL: OK` is no evidence that no edit was lost. The guard's predicate is the `levelled.sums`
  row, so a file no level wrote is outside the guard.
- **`plan` refuses an apply order that is not the changed list, and `mark` writes only the changed list.**
  `DistroAgentsTestingApplyPlan` returns 2 when `apply-order.txt` and `changed-files.txt` differ as sets
  (`DistroAgentsTesting.fn.sh:371-372`), and `mark` appends only to `changed-files.txt` (`:253`). A scratch
  carrying a marked file and no apply order therefore stops plan, and the two lines have to be made equal by
  hand before the next step.

**The three corrections these come from**

The three reflections that corrected an earlier claim of mine, so the bullet states the corrected form and
never the first one.

- The recovery in `changed-files.txt` was first filed as a general recovery. It works from one state only, the
  first bullet above carries the precondition, and it is `reflection-20261110T1254Z`.
- `level` was first filed as overwriting every unmarked scratch file. It overwrites one of four states, the
  fourth bullet above carries the four, and it is `reflection-20261110T1342Z`.
- The `case "$0"` silence was first filed as an arm that prints nothing. It was the caller's relative path,
  the first bullet above carries both readings, and it is `reflection-20261110T1154Z`.

## 23. Owner resolutions, 2026-10-30 and 2026-10-31

Standing decisions of the human-owner. Each holds until he changes it.

**Grants and places**
- A grant is declared as a directory, a workspace or a namespace. The index resolves every form to absolute paths internally.
- An ask is written and shown in place form, `<place>:<relative>/**`, named by the asking member's own grant. A name is never guessed back from a path.
- Declarations come only from the authoritative copy of a repository. A stray copy in another workspace never feeds grants.
- Every `keeper-*` holds standing write on its own workspaces and namespaces.
- The Bash working directory follows the live grant decision, the same as the file tools.

**Comms and Wait**
- A reply to a member's own post is always read. `replies:` stays beside `chat:`.
- The communication id of any message is its full pointer, `<driver>:<container>:<message-id>`, never the container alone. Slack is `slack:<conversation>:<ts>`, and email is `email:<account>:<message-id>`. The comms cache's `communication-channel-id`, Wait output, feeds, records and reply targets all use that one form.
- A read of a bot-started DM thread falls back to the bot on `thread_not_found`.
- A member posts under its own user token. The bot posts only for a member with none.
- A child's escalation reaches its caller through the parent's `owner:`.
- A session whose own chat, roster or log is newer than its spawn record is not ended.

**Asks and work**
- Members never sit idle waiting on the human-owner. His open questions stay open, and other work goes on.
- An answered ask is closed with `AskQuestion` readback or withdraw, never with a plain message. A reminder is sent only after reading the thread.
- A name the sketch or the epic gives is approved. A new name needs his approval.
- Long work runs async: `background: true`, or the tool's own queue.
- A document extension names its format. A file that does not follow the format does not take the extension.

**Changing the tooling**
- An include, a function or a variable is made only where it brings a gain, names a non-obvious gotcha that needs its comment, or holds real substance. One or two trivial basic lines, such as a path like `$MMDAPP/...`, are written inline wherever they are used. A wrapper around them costs speed, readability and maintainability, and adds coupling.
- A member's scratch goes in its session's `output/` folder, the only writable one. `.local/temp` is for temporary files, never a work folder.
- No member, tool or test ever creates a symlink. A delete or a copy that follows a link acts on the real tree behind it. A test that needs a tree copies it into its session's `output/` folder.
- The one approved exception is the ssh short-path link in `myx.distro-system/sh-lib/DistroImage.SyncScriptMaker.include`. That package's MAGIC.md says why it stays.
- Every tool except `DistroLocalTools.fn.sh` follows `myx.distro-system/sh-scripts/ListDistroDeclares.fn.sh`. That means the six-line validator testing `.local` at the top, and the context block only in the `.fn.sh` arm. `DistroLocalTools.fn.sh` is the installer and runs bare, so it is the one exception.
- A tool that calls its own family's context, such as `DistroDeployContext`, loads that context both in its function and in its `.fn.sh` arm. Any console can call the function, and the arm sets it at the root. One comment line in the arm marks it as special. A generic tool needs only SystemContext, which every console has.
- A change that replaces working code names what the old code does, what the new code does, and why, before it lands.
- A change goes through a sandbox and `DistroAgentsTesting.fn.sh --apply-tool`. A file a running session reads is never rewritten in place.
- **`--apply-tool` without `--repository` prints `LEVEL: OK` and levels nothing.** The default repository is
  `$MMDAPP`, which holds no `source/` in a workspace without the packages. `level` skips every package it
  cannot find live (`DistroAgentsTestingApplyLevel`) and still ends at `OK`. Pass `--repository` with the
  root that holds `source/`, and read the returned state rather than its success word.
- `DistroAgentsTools.fn.sh` loads its context at file scope. It is called as `Distro DistroAgentsTools`, by name, or by full path.

**Organisations**
- The reflection design and its implementation are Meloscope's, and stay off a client Confluence. A client's own coordinator publishes only the reflections produced in its workspace.
- The MDV workspace works only MAGIC-* and NDM items. The refactorings epic lives only on Meloscope's board.

## Member installs are links, made only by the installer (2026-11-01)

- Each member under `.local/agents/members/` is a link into its skillset, made by `--install-skillset-symlinks`. These are installation links, not sandboxes.
- A sweep that removes every link under `.local/agents` removes every member install with it. No member can then be started in that workspace.
- Put them back with the installer, never by hand: `Distro DistroAgentsTools --install-skillset-symlinks --workspace <workspace>`. That was verified on 2026-11-01 in all four workspaces.

## The CheckList gate (S22 items 3, 4 and 7)

- **A spawn seeds its executor's CheckList.** The spawn proxy writes the list once, after it fills the sandbox and before the member's first turn. The items, in this order, are: the `- ` lines under `## Formal task` in the text the spawner gave (the brief, or the tracked item); the numbered items of the one epic feature that text names, by an epic file it names and the feature id after the word `feature` (S24.19), which seeds nothing when either is absent; the duties of its routine, one for each step of its Opening steps, Steps and Closure steps in the order the routine is read (a numbered `**name**` line, or the deepest heading of a group); and one for each `--checklist-item <text>` argument. A work-duty's routine gives none, because a duty is a loop that no list can finish. Every item is pending. The seed adds an item whose text the list does not hold. It never closes, rewords or moves a line it finds, so a second spawn in the session adds nothing. `sh-lib/session/AgentsTools.CheckListSeed.include` holds it. The heading and the `--checklist-item` argument are names the owner has not yet approved. A tracking document's own contract section joins when a contract declares one.
- **A dismissal wins over the list.** A dismissed session ends on its plain reply, whatever its CheckList holds. The quit nudge is for a session that is not dismissed. The items stay beside the session as its state, for the reviewer.
- **A list that stops moving gets one message.** A run whose own list has not changed for 30 minutes, with at least 15 tool calls other than Wait since, is given one plain message as its next chat message. It is given at most once per 30 minutes, and a list write resets both the count and the clock. The clock is the list's own modification time, and the half hour is kept in `checklist.nudge` beside it. `AgentsHarnessCheckListNudgeWanted` in `sh-lib/harness/AgentsUniversalHarness.sh` holds it, and `sh-test/harness/AgentsHarnessCheckListNudgeCheck.test.sh` is its test.
- **A long tool returns a handle at its own window.** The table is `sh-lib/harness/AgentsHarnessToolWindow.include`. `sync` and `async` override it. A tool that blocks by design carries no row.

## The queue, the liveness and the duty's inputs (S23, S4)

- **The CheckList is also the queue.** With `SPAWN_LIMIT` of the team scope above 0, or `MDAT_SPAWN_LIMIT`, a `--spawn-session` that finds that many runs of this host alive makes no spawn. `AgentsToolsSpawnQueue` files the request as an inquiry in magic-coordinator's inbox and adds an item naming it to the CheckList of the coordinator's running work-duty. The call prints `SPAWN_QUEUED=true`, `SPAWN_QUEUE_ITEM` and `SPAWN_QUEUE_CHECKLIST`, and exits 0. A work-duty's own start and a start that joins a session are never queued. Unset or 0 is no limit.
- **A parent adds to its executor's CheckList.** The CheckList tool takes `append` (item texts), `member` and `session`. The caller's session must be the `parent-session-id` of the named session, and `member` its executor. With no `session` the items go to the caller's own list. They are written pending, under a lock, to the end of `<member>.checklist.md`, and noted in `<member>.checklist.md.added`. The owner's next whole-list write keeps any of them it was not shown, and its next read clears the note.
- **Liveness is a cached reading.** `AgentsToolsLivenessOf <spawn id> [<record>]` prints `alive`, `gone` or `unknown`, rc 2 for unknown. `alive` and `gone` are kept in `.local/agents/liveness/<spawn id>` for `AGENTS_LIVENESS_TTL` seconds (30). Unknown is never read as gone, so nothing closes or restarts on it, and never as alive. The duty scan, the stale close of a duty record and the board item holders ask it. A holder whose run is gone holds nothing. The loop's work-duty step closes a duty record whose run and supervising shell are both gone, so the restart rule reads an end.
- **A handback addressed to the duty is a ready input.** The work-duty scan lists the review items with `review-by: <member>.work-duty.routine` under `## Handbacks ready for the duty` and a `# ready: <N>` line. A Wait on `scan:work-duty` returns with the report again while N is above 0, until the duty takes the item out of review.
- **A context refusal withholds tool results.** The harness records each tool result of a leg. A refusal for length withholds the results of the round that overflowed, and a refused summarise round is asked again once with every result withheld. A withheld result is a notice that the call ran.
- **A duty's start does not wait for Slack news.** The spawner marks its real run of a scan `MDAT_SCAN_AT_START=1`, and the duty scan then reads Slack once with a one-second window. A Wait's own scan keeps `WAIT_COLLECT_SECONDS`.
- **An epic is a vault item, and any member reads it.** `vault-item.epic-blueprint` is the vault's type for an epic, written by `--upsert-vault-epic-blueprint` as `epic-blueprint-<date>-<matter>.md`, and `epic` keeps its shape. `AgentDispatcherTools --epic-read <epic-file|epic-item> [--feature <id>]` and `--epic-list [<folder>]` serve any member: a vault epic blueprint's bare name, or a path under a `todo-sketchpad` folder with no `..` part. `--epic-update` stays magic-coordinator's, and writes a vault item through `--upsert-vault-epic-blueprint`, so its contract check and its commit happen at that one write.
- **A run's words are one word each (S27.4).** The `live` column reads `running`, `gone`, `remote` (the record names another host) or `unknown` (it names no host or no run). The `state` column reads `thinking`, `tool`, `waiting`, `idling`, `parked`, `finished`, `failed` or `unclosed`, plus `starting` for a run its start has not yet shown. A run on another host with an open record reads `unclosed`. `AgentsToolsRegistryMeasureRows` derives both, and `AgentsToolsRunDeriveState`, `AgentsToolsRunDeriveStateFromSet` and the legacy fixture of the diff check must give the same words. `idling` is a Wait whose sources are all the floor: `AgentsWaitActivityIdle` rewrites the run's `tool Wait` mark as `idle`, and the harness's idle-wait writes `idle`. A session's own state words (`running`, `waiting`, `awaiting-review`, `unknown-foreign`) are the console's and stay. The `ListAgents` filter `running` keeps every row whose `live` is `running`, and the `waiting` ones.

## A session's root message shows its end (S6.37)

- **The marks go on the session's root post, never on a tracking post.** The root is the one `sessions/<session>/session.thread` names, and a thread of the event-track conversation is refused by `AgentsToolsSpawnProxyRootMarkTarget`. The event-track end post keeps its own `checkered_flag` and is a different fact.
- **One close places them, and a second adds nothing.** `AgentsToolsSpawnProxyRootMarks` is called from `AgentsToolsSpawnProxyCloseSandbox` after the first close that succeeds. The settled guard at the head of that function is what makes a reopen-and-close react to nothing.
- **`checkered_flag` when no run of the session is left, and the tick or the stop sign by its outcome.** `white_check_mark` where every record of the session closed `spawn-succeeded`, else `octagonal_sign`. A run still open withholds both.
- **What Slack took is `root.end`; what it refused is `root.want`.** A reaction that fails leaves the want whole, and `AgentsToolsSpawnProxyRootMarkRetry` places it again from the advance pass over dead records. The session's control thread asks it at every tick, so a rate limit costs the mark a tick and never loses it.
- **A restart or a resume clears them.** `AgentsToolsSpawnProxyRootMarkClear` runs on a start that names `restarted-from` or a resume, taking both marks off and cancelling a want nobody placed.
- **A pause is separate state and its own reaction.** `double_vertical_bar` while `sessions/<session>/paused` stands, asked at every tick of the session's control thread, and removed once that file is gone. `root.pause` says what the message currently carries.
- **A mark is never an arrival, and no member spends a round on one.** The root post carries `[tracking: session-root]`, so `AgentsTrackingDrop.awk` drops it whole and its marks with it, `AgentsSessionChatImport.awk` records it as `history` for every floor, and `AgentsWaitOwnPostReplies.awk` reports a reaction set only for a post the member itself made. `sh-test/session/AgentsSessionRootMarkReadsCheck.test.sh` pins the three, with controls that show each reading able to see the root when the mark is not there.

## A wait's first look reads from the run's beginning (S6.39)

- **A post never looked at starts at the run's own beginning.** A record line's thread and conversation floors are `-` until a first look, and that look read from the post's own ts. What stood after the post but before the run began was handed over as new and took a seen `eyes`: 373 of 373 claims written on MDV on 3 November were for messages over six hours old, and 684 of 813 on MEL. `AgentsWaitRepliesStart` (`sh-lib/wait/AgentsTools.MemberWaitReplies.include`) reads the launch marker once a wait, and the look starts there where the post is older. A run launched through no marker keeps the floor its line carries.
- **History is dropped, work is not.** A message after the run began is still returned and still marked, and a later look returns what arrived while the run worked. `sh-test/member/AgentsWaitRepliesFirstLookCheck.test.sh` holds both directions, and the react log below.
- **The seen path logs one line an attempt**, `comms-slack-react.YYYY-MM.log` beside the send log: `<stamp> <member> <target> <identity>:<account> <ok|failed> <reason>`. A mark that fails leaves no claim, so this log is the only record of it.
- **The second identity is spent only where it can help.** `AgentsToolsSeenHopeless` lists the reasons no identity of ours can change, `already_reacted` among them; the react path stops after the first failure for one of those instead of calling again as the bot.

## A session or a run is paused (S19)

- **The flag is one file, and its folder is what it holds.** `sessions/<id>/paused`, one line of `<when> <by>`, written by `--manager-session-pause` and removed by `--manager-session-resume`. A session's own id in that folder holds every run of it, and a run's own id holds that run alone. `sh-lib/session/AgentsTools.SessionPause.include` is its one home: `AgentsToolsSessionPauseHeld`, `AgentsToolsSessionPauseOwn`, `AgentsToolsSessionPauseWait`, and the set and clear.
- **Every point asks the run and its session, and there is one loop.** `AgentsToolsSessionPauseOwn` asks the harness's own run id and the coworking session it joined, so no point restates the chain; `AgentsToolsSessionPauseWait` is the 5-second look, shared by all of them.
- **The start of a call and its exit are different pauses.** Read and Wait hold at their START, so a paused run reads nothing while it holds. SendMessage, SubagentHandback, Bash, WorkspaceContextExecute, Write and Edit hold at their EXIT, so the work is done and its result waits. `execute` (`--intern-mcp-execute`) is checked at its start and then REFUSED with PAUSED, exit 75, so nothing ran and the run calls it again.
- **`paused` is a state word of the registry, never a busy one.** `AgentsToolsRunDeriveState`, `AgentsToolsRunDeriveStateFromSet` and the one awk pass in `AgentsToolsRegistryMeasureRows` all read it before the activity mark, for a live run only, at the same two ids the park mark is read at. A held run is therefore never `stuck`, `dead` or `idling`, and the console counts it apart: `sessions-paused` and the session's own `paused` state.
- **Nothing ends a held run.** `AgentsToolsSessionControlRelease` turns away from a run a pause holds and drops its release mark, so the closing time counts again from the resume. The control thread's own judging keeps the session `running`, so no thread calls it finished.
- **Two marks wait on it, and both are wired to this file.** S6.37's `double_vertical_bar` (`AgentsToolsSpawnProxyRootPauseMarks`) and S13.18's `paused=yes` with its `waiting` verdict (`AgentsSuperviseScan`) ask the same flag, and neither keeps a copy of its path.
- **A pause is said where its members read it.** The operation writes one block into the session's chat file as `console`, and the work-duty scan prints one `PAUSED:` line naming the session.
- **The checks.** `sh-test/session/AgentsSessionPauseStateCheck.test.sh` holds the state and its readers, `sh-test/harness/AgentsHarnessPausePointsCheck.test.sh` holds the seven points and the refusal, and `sh-test/session/AgentsSessionPauseReadersCheck.test.sh` holds the three readers and the two marks against a real flag.

## One team-data committer, runs that nobody ends, one audit log (S12.4, S5.6, S12.5)

- **A writer of the team data runs no git.** `AgentsToolsTeamDataCommitPaths <context> <path>...` leaves one entry file in `team-data-commit/` of the store's git directory. It starts the thread where none lives, and asks it through the store's `request.fifo` (the shared on-demand thread, below). The thread takes the entries oldest first, commits each as its own commit, and pushes once. A lock another writer holds can no longer fail a write. A thread that cannot be started leaves no entry unseen: the writer commits in its own process.
- **A close that cannot be recorded drops its own commit, never another writer's (S12.10).** `item-upsert` stays outside the thread, so it commits in its caller and discards that commit when the close then fails. That discard was `git reset --soft HEAD~1` with no test of what HEAD was, so a commit another writer made in between was the one dropped. `AgentsToolsItemUnlockKeep` and the sync-failure arm now read HEAD's subject first, and reset only where it is this call's own commit message. Measured in the live store on 2026-11-04: `board/review/.unseen-dispatch-20261103T225226Z-spawn-proxy-68534-637d5076.md` was committed at 04:30:28 and dropped by such a reset one second later, and reached no commit for the next 50 minutes. `sh-test/team-data/AgentsCloseKeepsOtherCommitCheck.test.sh` holds it. Not fixed here: the close's own commit stays on the branch below the other writer's, so the history keeps a close whose note was put back.
- **The thread is one a store.** Its lock is `thread.lock`, holding `<pid> <start>` (`AgentsTools.ThreadLock.include`, which the three older threads do not use yet). It ends by itself once no request came for `MDAT_TEAM_DATA_COMMIT_IDLE_SECONDS` (60), and it gives the lock back first. A request left in that moment starts it again. `thread.log` is cut back to 64 KiB when it passes 128 KiB. `--intern-team-data-commit --one` makes one pass, for a check.
- **A failed commit stays owed.** `AgentsToolsTeamDataCommitPathsNow` keeps the paths in `.local/agents/team-data-commit.owed`. The thread runs the same pass once a second with no request, so the debt is tried again every 30 seconds, and it does not keep the thread alive. A path that is gone and that git never knew is left out of a commit, since it fails the whole add, and so is a path that changed nothing.
- **A resync settles the writers before it moves the tree (S12.4).** The store's checkout is also its writers' work tree, so a writer's file waiting for its commit is an uncommitted change to it. Git refuses to move a tree that holds such a change to a file origin changed too, which is how a duty start met `LOCK_UNCHECKABLE` and a retry a minute later passed. `AgentsToolsAdvanceCloneSync` calls `AgentsToolsTeamDataSettle` first: it asks the thread to commit what waits and holds for its answer, then commits anything still waiting itself. A store with nothing waiting costs one `git status`. A sync that still fails is a merge to settle, as the close push settles one, and the sync runs a second time. `sh-test/team-data/AgentsTeamDataResyncRaceCheck.test.sh` holds it. A head that moved under the pull, where a writer's commit landed between the sync's fetch and its merge and git says "fetch updated the current branch head", is a writer's transient of the same kind: the sync runs again, up to five times two seconds apart, before the failure is reported.
- **The store's own `.local` is no team data.** A data folder with no repository of its own, inside another repository's work tree, is not that repository's: `AgentsToolsTeamDataCommitPathsNow` commits nothing where `MDAT_DATA_ROOT` is no repository root. A path under the store's `.local` is refused too, unless git already tracks it, so an existing stray leaves through the same step and no hand git is needed. A check rig lives under `$MMDAPP/.local/agents/scratch`, and `rigTempDir` refuses a `MMDAPP` that is the team-data store or inside it.
- **`MDAT_TEAM_DATA_COMMIT_THREAD=off` commits in the writer's own process.** `AgentsRunTests.sh` sets it, so no check starts a thread. The check of the thread unsets it. `MDAT_TEAM_DATA_COMMIT_WAIT=yes` before the call holds the writer until the thread has answered its request, for at most 30 seconds, and past that the commit is made in the writer. `board-trash` uses it, since the history of a file must be made before the file goes.

## The on-demand thread (S12.11)

- **One thread a task, started on demand and ended on idle.** `AgentsTools.OnDemandThread.include` holds four functions and knows no owner: `AgentsToolsOnDemandThreadStart <folder> <operation>...`, `AgentsToolsOnDemandThreadAsk <folder> <bound|-> <field>...`, `AgentsToolsOnDemandThreadRequest <folder> <bound> <operation>... -- <field>...`, and `AgentsToolsOnDemandThreadServe <folder> <idle> <handler> <tick|-> <once|no>`. The owner supplies the handler (one request's work) and the tick (a second's work with no request). The team-data committer is the first use; the write-up for a later one is `s12-11-on-demand-thread.form.md` in session 61538551's sandbox.
- **A caller asks through `Request`, and the restart is that one function's.** It asks, starts a thread where none answered, and asks once more: a caller keeps no retry loop and no reply fifo of its own. It prints the answer, rc 0, and prints nothing with the reason on stderr where no thread answered, rc 1. The operation to start stands after the bound and before `--`, and the request's fields after it, so a field and an operation word never stand in each other's place.
- **A request is one line of tab-separated fields, and the caller's own reply fifo is its last field.** A field of `-` asks for the work and no answer. The start holds `request.fifo` open read-write before it forks, and hands that descriptor to the thread, so the fifo is never without a holder and a request written the moment a thread is born waits for it. A reply fifo is opened read-write by its caller, so a caller whose thread died cannot hang either.
- **The loop reads one second at a time, because bash 3.2 refuses a shorter read.** `read -t 0.3` is `invalid timeout specification` on 3.2, and a TERM trap fires inside a one-second read but not inside a read of a minute. So `Serve` reads `read -t 1` in a loop and tests the idle bound and its lock every thirtieth pass.
- **Descriptor 3 is always open, at `/dev/null` except while one request's answer is served.** A handler writes its answer to `>&3` and never tests whether anyone is there. That is why a fire-and-forget request needs no second branch in the owner's code.
- **A request the thread cannot answer costs the caller its wait, never its work.** A caller that wanted an answer falls back to doing the work itself when none arrives in its bound. The team-data writer commits the entry in its own process, and the thread's own tick is its own pass, so the entry would commit within the second anyway.
- **An answer ends with the terminator line `.`, and the thread writes it.** A caller reads lines until it, so an answer of several lines arrives whole. The terminator alone is a served-and-empty answer: rc 0, nothing printed. A caller that reads neither is told nobody answered in its bound, rc 1 with a line on stderr, so the three outcomes separate. The terminator belongs to the thread, never to a handler, so a handler that says nothing still ends its answer. A request field holding a tab or a newline is refused, because a request is one tab-separated line.
- **The idle bound belongs to the thread's folder.** `Serve` writes the bound in force to `thread.idle`, and a start over a living thread reads it and reports it: `alive <pid> bound <n>s in force, this start discarded its own`. A start can no longer claim a bound its own call would have set.
- **The four older threads are self-pipes, so they do not move here.** Each holds a pipe of its own that nothing writes, so a long read is woken without a process. There is no request, no owner handler and no second caller. The assessment the epic asks for is recorded: the pattern does not apply to those four. A caller and its thread on different hosts are not supported either, and a use that needs it is a new piece of work.

- **The writers that stopped running git** are the board ops that committed in their callers: upsert, move and edit, `member-inbox-upsert`, `inbox-to-processed`, `board-rename`, `board-trash`, `item-rename` and the final GC. Three groups still run git in the caller, and the owner rules on them. `item-upsert` stays, since its commit, its push and its read back are one lock protocol: it runs its `add` and `commit` again for ten seconds while another writer's `index.lock` stands. `--commit-pending` and the pushes of the closes, the main loop, the collector and the set-up stay as they were: they serialise on the push lock.
- **A run its item no longer wants is ended by the control thread of its session.** A tick that reads in full asks `AgentsToolsSessionControlRelease` (`AgentsTools.SessionControlRelease.include`) about each live run. A run whose dispatch item is in processed or archived, or waits in review past `REVIEW_WAIT_LIMIT`, is ended once `SESSION_CONTROL_CLOSING_SECONDS` have passed since the thread first saw it so. A run that another run needs is not ended. The thread starts `--intern-session-control --release` apart from the tick, which kills the run as the console does, under the name `session-control`.
- **A killed run's open record is closed by the thread.** A record with `killed-by` is no death and asks nobody. A supervising shell that lives past the closing seconds without closing the record counts as none: the run is a death then, as one with no shell is. The thread closes that record itself as an ordered end, and asks nothing about it.
## Three run-lifecycle rules (S5.2, S5.4, S5.5)

- **A closed session's leftover processes are closed by the advance pass.** A detached command a run started is kept in
  its session's `processes/`, and nothing ended it when the session did. `AgentsToolsAdvanceSpawnHousekeeping` walks the
  folder of each session whose rows say nothing is alive, and signals each process only while its pid is still the one
  whose start is kept beside it, its group first and then the pid. A `.closed` mark with the two byte counts keeps the
  next pass from signalling a number again. `sh-test/session/AgentsClosedSessionProcessesCheck.test.sh` holds it.
- **An addressee with no live run is said where the message is sent.** `AgentsToolsCommsSlackUnreachableReport`, called by
  both send paths, prints `SENT_MESSAGE_UNREACHABLE_MEMBERS=<member>...` for every addressee whose records show no live
  run. It names no sender and changes nothing about the post: the message stands, and that member reads it at its next
  start. `sh-test/comms/AgentsSendUnreachableCheck.test.sh` holds it.
- **A start's read of the member's incoming is bounded.** `AgentsToolsIncomingSyncBounded` gives the read
  `SPAWN_INCOMING_SYNC_SECONDS` (20 by default, 0 for none) as the leader of a group of its own, and the spawn goes on
  without it once that has passed, saying so. Its notes are read at that member's next scan. Measured over 342 spawns on
  one workspace: 0s for 80, 1-3s for 24, worst 96s. `sh-test/member/AgentsIncomingSyncBoundCheck.test.sh` holds it.

- **Every harness writes one audit log.** A harness that keeps its context writes the lines of each new record as the record is kept (`AgentsHarnessContextFeed`), to the transcript and to the event-track feed, from the one reader `AgentsHarnessContextTranscript.awk`. Its milestones only commit. A tool line names the tool without its `mcp__<server>__` prefix, for both writers.

## The schedule as a service thread (S12.12)

- **The schedule runs in a process of its own, on the shared on-demand thread.** `--intern-schedule --run` serves `AgentsToolsScheduleThreadPass` (`sh-lib/schedule/AgentsTools.ScheduleThread.include`), the schedule's steps (`AgentsToolsScheduleLoop`) and the board's dependencies (`AgentsToolsBoardDependencies`), on the one thread `AgentsTools.OnDemandThread.include` gives. `--one` makes one pass and ends, for a check by hand. Its files are in `.local/agents/schedule-thread/`: `request.fifo`, `thread.lock`, `thread.log`, `thread.wanted` and `thread.asked`.
- **The passes are minutes apart, and the includes are parsed once.** A pass runs when `MDAT_SCHEDULE_PASS_SECONDS` (180) have passed since the last one, so with a morning review at 09:00 and grooming at 09:00 a rig's schedule is checked within a few minutes of its time, and the cost of a rig that does nothing is one pass every three minutes. The includes a pass needs are read once, at the thread's first pass, and the variables survive between passes: that is the profit over the main loop's iteration, which parses them at each turn.
- **One ask starts it, and the ask is throttled.** `AgentsToolsScheduleThreadAsk` is the only way it is started or put back. It reads `thread.lock`, answers `alive <pid>` where the process it names still lives, and otherwise starts the thread. It looks at the lock no more than once in `MDAT_SCHEDULE_ASK_SECONDS` (300), so a place that asks often spends one file test. It says one line: `off`, `waiting`, `alive <pid>`, `started <pid>` or `failed - <why>`.
- **Three places ask, and none is a watcher of its own.** A session's control thread asks at its read in full, which comes once a minute at most. That is S12.12's "logically cheap place", as that same thread and the spawn path start the communications reader.
- The spawn proxy asks at a start, so a rig where nothing else runs still starts its schedule at its first spawn.
- The main loop asks at each iteration whose configuration check passed, and runs no schedule step of its own.
- So a live session keeps the schedule running, an ended duty is put back by the next ask, and a rig with no session and no main loop runs no process of it.
- **It ends on idleness and is put back by the next ask.** No pass asks for itself, so the shared thread's own bound ends it once no ask came for `MDAT_SCHEDULE_IDLE_SECONDS` (600), and the next ask starts it again. A pass that starts a routine through the spawner is unaffected by that end: the start is a detached spawn of its own.
- **`MDAT_SCHEDULE_THREAD=off` leaves the steps in the main loop.** With it off, `--intern-main-loop` runs `AgentsToolsScheduleLoop` in its own process at each iteration, as it did before. `AgentsRunTests.sh` sets it, so no check starts the thread, and `sh-test/check-fixtures/rig-schedule-loop.include.sh` sets it in its own rig. The check of the thread unsets it, and ends what it starts.
- **What rides with it, and what does not.** The board's housekeeping and the source collector already have a caller outside the loop: `AgentsToolsRegistryHousekeepingDue` starts the advance housekeeping and the pending-reply collect from any registry read, and `AgentsToolsCollectThreadCheck` starts the collector from any scan. So they do not stand still with no loop, and the schedule's thread carries neither. The steps that only the loop ran, and so stood still with it, are the schedule's own, and those are what the thread now runs. `sh-test/session/AgentsScheduleThreadCheck.test.sh` holds the operation, the pass, the ask, the kill and put-back, the interval, the off switch and the loop's two modes.

## A tool's context is loaded in both its function and its arm

- **A console sources the context file and calls the function, so the `.fn.sh` arm never runs there.** That is why a family context is loaded in two places: the function serves any console that calls it, and the arm sets it at the root of a tool run bare. `DistroDeployContext` is the shape. One comment line in the arm marks it as special. A generic tool needs only `SystemContext`, which every console has.

## The typed vault write and the plain-document contracts

- **The typed vault write stamps a frontmatter block that two contracts forbid.** `--intern-op-vault-item-write` writes `type`, `document-contract`, `from` and `date` through its header ops (`AgentsTools.InternOpVaultAudit.include:142-143`) on every typed create. `vault-item.planning` and `vault-item.tracking` each state at their own line 30 that the document "carries no `---` block, and names no `document-contract`". So a `planning-*` or `tracking-*` item written through its typed op lands with four `contract-unknown-key` rows and one `contract-frontmatter` row, and no write path satisfies the contract. Measured 2026-11-12 in a copy of this tree: the two ops answer rc 0 and the name stores, so the fault is the stamped block, not the operation. A new vault kind whose contract wants a plain document needs a per-kind stamping list, or a frontmatter block in the contract.

## The team-data pull: settled writers, and no refusal over a file it did not write (S12.4, task-20261113T1619Z)

- **A pull settles every writer before it moves the tree.** `AgentsToolsTeamDataPrepareSync` asks the one commit thread to commit what waits, then commits anything still waiting itself, so a path any member's run left uncommitted is a commit and not a refusal. It then reads what origin moved and carries every one of those paths this store still holds uncommitted, untracked ones included, as this store's own commit. A path this store's own rules will not commit is named in one line, and nothing is moved over it.
- **A pull that stopped on a conflict is settled and run again.** `AgentsToolsTeamDataMergeAgain` takes origin's branch and settles the conflict inside the file, as the close push already does, and the pull runs once more. One item both sides changed no longer leaves the store behind its origin.
- **The audit log family is out of the tracked set.** A live session appends to `audit/<month>/*.log` for its whole run, so a tracked one is dirty whenever any session runs and the set rotates each pass. `AgentsToolsTeamDataAuditUntrack` commits whatever those logs hold, takes them out of the index with `git rm --cached`, and writes `audit/**/*.log` into the store's own `.gitignore`: the files stay on disk, their history stays in the branch, and no pull moves them. A store that tracks no log is left untouched.
- **The removal lands after the merge, never before.** A log both sides appended is merged line by line first, so the crossing loses no line, and only then does the family leave the index. A removal done first turns the two sides into a modify/delete conflict the merge settle cannot work, and origin's copy wins over the local one.
- **Every caller pulls through one function.** `AgentsToolsTeamDataSyncWithRemote` wraps myx.common's `git/cloneSync`: the settle and carry first, cloneSync's own pull and push, the settle-again and the untrack after a pull that landed. The board resync in `AgentsToolsAdvanceCloneSync` and the read-back sync of `item-upsert` both come through it, so one rule holds at every caller.
- **A landed write is never reported as a failure.** The read-back sync of `item-upsert` runs through the same wrapper, so another member's uncommitted path, or a session's own append to a log, no longer makes a write that stands on origin read as `LOCK_UNCHECKABLE`.
- **The checks.** `sh-test/team-data/AgentsTeamDataLiveLogSyncCheck.test.sh` holds the live log appended on both sides, the family leaving the index and the ignore rule reaching origin, a foreign writer's path, a path the store will not commit, one item both sides changed, and both control directions. It reads 10 of 22 red on the tree before this change and 22 of 22 green after.

## For magic-developer

- **A rig that copies this package alone fails every send, and the failure names a settings variable.** The copy's own siblings are invisible from that error, so the list below is the one thing a rig needs and cannot learn from the message. The general rule is `magic-developer/reference/code-craft.md:116`.
- **The packages this tree names, counted 2026-11-17 15:21 +0200.** Population: every file under `sh-lib` and `sh-scripts`, 878, walked with `find -L … -exec grep -lF`. The `sh-test` column is the same token over that folder's 975 files.

| token | `sh-lib` + `sh-scripts` | `sh-test` |
|---|---|---|
| `myx.distro-.local` | 107 | 133 |
| `myx.common` | 60 | 61 |
| `myx.distro-system` | 4 | 24 |
| `myx.distro-source` | 6 | 14 |
| `myx.distro-deploy` | 3 | 9 |
| `myx.distro-remote` | 2 | 5 |
| `repository.inf` | 0 | 8 |

- **The controls.** A made-up token reads 0 in both folders, and the walk reads 878 and 975.
- **What the counts do not answer.** Which of the six code packages a send specifically needs: they count files that name a package, never the send path. Nothing off this host either, so FreeBSD and Linux are unread.
- **The count moves with the tree, so quote it with its date.** An earlier set read 873 files and agreed on twelve of these fourteen cells; the tree gained five files between the two.
- **A cache folder of a direct conversation resolves through `AgentsToolsCommsCacheSlackDir`, and `AgentsToolsCommsCacheDir` names another folder there.** The generic call drops the reading account, so a DM resolves to `slack-<dm id>`. The real folder carries that account first: `slack-bot-<dm id>` as the bot, and `slack-<account user id>-<dm id>` as a member account. A rig that seeds the generic path seeds a folder no reader opens, which is why `rigOwnerCommsState` seeds through the slack-aware call. Measured 2026-11-23 01:35 +0200, at `sh-lib/comms/AgentsTools.CommsCache.include:24` and `:35`: a channel agrees under both calls, and both DM forms differ.

## A retest by name, and the `--project` that widens it

- **`--retest-queue --project <p>` adds every test registered for that project.** A test named on the command line is queued beside them, never instead.
- **The request takes them from the testbed, not from the argument.** `AgentsToolsTestbedProjectTests` is read at `sh-lib/member/AgentsTools.RetestQueue.include:88`, and each name it prints is appended to the request.
- **The help does not say so.** `DistroAgentsTesting.fn.sh --help-syntax` prints `[--project <p>]` after `--why`, in the shape of an option that narrows.
- **A retest of named tests therefore carries no `--project`.** Name the tests and stop. The tester's next batch runs everything the request holds, so the project is paid for there.
- **A project with no registered test refuses the whole request.** Named tests are refused with it, and nothing is queued.

## A state note's patch is matched against its body, not a read-back

- **A patch anchor is matched against the stored body, so a count taken over a read-back capture answers about the capture.** `--get-inbox-item` writes `SystemContext:` lines ahead of the document, then its frontmatter. A line number, a length or an `old` count over that output is not one over the body the patch is applied to. Measured on `note-20261020T000000Z-work-duty-state-and-lock.md`, 2026-11-18: an anchor asserted unique over the capture was refused as `old text not found`, then as `matches 3 times` once shortened.
- **Anchor on one line, then read the body back.** The one-line anchor landed first time. The multi-line forms built from the capture did not. `--edit-patch-from-stdin` takes a JSON array of `{"old", "new", "replace_all"}` and applies each in order, so a multi-step repair is one call.
- **`--header:` and `--edit-patch-from-stdin` are mutually exclusive.** So are `--from-file`, `--upsert-from-stdin` and the patch mode. A call naming two is refused before anything is written.

## The P4 duplicate class compares invocation text, so a copied `.awk` file is invisible

- **What the class reads.** `sh-test/solid/AgentsSolidBreachScan.sh:203` selects `awk … '…'`, an invocation with its program quoted inline. The reducer at `:204` keys on that quoted text.
- **So it reports one thing: the same invocation written in two `.include` or `.sh` files.** A `.awk` file holds a program, never an invocation, so this class has nothing to match in one.
- **Widening its `--include` list reaches a call site planted in a `.awk` file.** Measured 2026-11-18 on planted trees: that site reports 1 row with `--include='*.awk'` and 0 without.
- **That widening changes no output on the live tree today.** Measured 2026-11-18 01:32 +0200: 152 selected rows either way, and 0 duplicate rows either way. The two tracked libraries `sh-lib/core/AgentsProgressLineSafe.awk` and `sh-lib/session/AgentsProgressLineSafe.awk`, byte-identical at `d76e52f0`, go unreported.
- **Two more axes, each with its control in the same run.** A program under 80 characters repeated on one line reports 0, against 1 for the same shape at 100 characters. A 100-character program split over three physical lines reports 0, against 1 on one line.
- **Nothing else in the scan compares whole files.** `AgentsSolidTrivials.py:51` selects `.include` and `.sh` only. Over `shasum|sha256|md5`, `sh-test/solid` names a digest in 0 files and `sh-lib` in 2. Adding `hashlib` to the pattern reads 4.
- **A whole-file class over `*.awk` finds two pairs.** Population: 151 files, `sh-lib` 142, `sh-test` 9, `sh-scripts` 0, read 2026-11-18 01:16 +0200. The three folders hold no symlink, and a `-L` walk returns the same counts.
- **The pairs are the progress library above, and the JSON slice reader with its kept fixture.** The second is `sh-lib/harness/AgentsHarnessJsonSlice.awk` with `sh-test/check-fixtures/AgentsHarnessJsonSlice.legacy.awk`, at `1d449840bc9d`.
- **That instrument's control, in the same run.** A planted third copy reports its group, and removing it reports none. Two files differing by one appended line report nothing.
- **The second pair is a fixture that has never diverged.** The live file first exists at commit `42a80b8a`, already byte-identical to the fixture kept since `5ff3f2b5`. Neither has changed since.
- **So that class needs its allowance named, not a folder pattern.** A written store path is already allowed at `:97` by `allowedFabricatedSites`. A kept fixture needs the same, or the class reports a file correct by design. Filed as `inquiry-20261118T0128Z`.
- **The `session/` copy of the progress library is dead, and one file names it.** Population: the 19 files under the three folders that name `AgentsProgressLineSafe`, read 2026-11-18 01:25 +0200. Twelve spell `core/…`, one spells `session/…`, and six name neither path.
- **That spelling is in a file nothing runs.** `sh-lib/harness/AgentsOpenAiChatWire.sh.keep:397` spells it, and no file sources a `*.sh.keep`. The live file beside it, `AgentsOpenAiChatWire.sh:408`, spells `core/…`.
- **The family already treats a `.keep` as no code.** Two checks exclude `*.keep` from their own scans, `AgentsBashPathGuardCheck.test.sh:162` and `AgentsOriginPathsExistCheck.test.sh:34`.

## The P5 fabricated class reads a literal store path

- **The P5 `fabricated` class reads a literal store path, so a path built in a variable is never a row.** `sh-test/solid/AgentsSolidBreachScan.sh:210` selects `>` or `mkdir -p` followed by `system-index`, `/board/`, `/inboxes/`, `/vault/`, `distro-declares` or `distro-projects`. A check that writes `rigBoard="$rigTmp/data/board"` and then `> "$rigBoard/running/x.md"` prints nothing. The pattern also names no session or spawn store.
- **Measured 2026-11-17 on the live tree: 40 store-root `mkdir`s over 35 checks, and 56 session-store writes over 16 checks.** Every one was invisible to the class. A green P5 of 0 is therefore no evidence that no check fabricates its store.
- **The store rule exempts a word ending `sh-lib`.** `word !~ /sh-lib$/` at `:176` is what keeps a load of board code out of the `foreign-store` rows. `sh-test/solid/AgentsSolidBoardLoadCheck.test.sh` holds it, and its red arm removes that exemption.

## A load covers a call only in its own branch

- **A load covers a call only where it sits before the call and in the call's own branch or an enclosing one.** A load inside an `if` block, a `case` arm or an `else` reaches that branch's calls alone. It never reaches a call after its `fi`, or a call in a sibling branch.
- **A file that defines a function runs its file-scope `if` block at load, so there its load covers the whole file.** A fragment defines no function, is sourced inside a function, and its blocks are branches.
- **`sh-test/solid/AgentsSolidUndefinedCall.test.sh` holds the class, seven assertions.** Its red rows are a call after the `fi`, a call in the `else`, and a call to a name no file defines.

## One frontmatter headers reader for the whole package

- **One frontmatter headers reader serves the whole package.** `sh-lib/core/AgentsFrontmatterHeaderValues.awk` prints the first line of each named key of a file's first frontmatter block. It prints one value a line, and an empty line for a key the block lacks. `-v keys=` takes the keys, space separated, under `LC_ALL=C`.
- **`AgentsSessionRunHeadersInto` and `AgentsToolsBoardItemHeadersInto` both run it with `-f`, and neither carries a program of its own.** A third reader of a frontmatter key runs this file too, never a copy.
- **The board item lookup takes its order from the board's own two lists.** `AgentsToolsBoardItemInto` searches `$agentsBoardActiveStates` and then `$agentsBoardStates`, both of `sh-lib/board/AgentsTools.BoardStates.include`. So the five live states answer before the backlog.
- **It carried a literal copy of that order until task-20261115T1024Z, so a state added to the one list was never searched.** `sh-test/board/AgentsFrontmatterHeadersCheck.test.sh` holds both facts, and its failing case is a state appended to the one list.

## The ask tools run as tasks, the rest bypass the wrapper

- **The five ask tools run as tasks: `AskQuestion`, `ConfirmReadback`, `EscalateDecision`, `RequestPermission` and `ProposeApprove`.** Each takes `background`, `sync`, `async` and `timeout_action`. Its own `timeout` still means its seconds per waiting round. `sh-lib/harness/AgentsHarnessRun.include` carries that arm.
- **`Wait`, `ThisSession`, `TaskOutput`, `TaskStop`, `SubagentHandback` and `BatchTools` still bypass the wrapper.** Their names stand in two lists that move together: the dispatcher arm, and the skip list of `sh-lib/harness/AgentsHarnessTaskArgsFill.awk`.

## A tool call's streams are named on the command that runs it

- **A tool call's streams are named on the command that runs it, never set by a subshell around it.** The Bash tool runs `< in > out 2> err bash -c 'cd "$1" && set -e && eval "$2"'` as the harness's own child. An `(exec < in > out; exec <cmd>)` wrapper costs one process a call for nothing. Measured on one call with `timeout: 0`: 9 harness-argv ancestors before, 8 after.
- **The command's `cd` and `set -e` stay inside its own `bash -c`.** Run them in the harness's shell and the change of directory outlives the call.
- **The output mode is a branch at each site, not a helper that redirects the caller's shell:** `2>&1` for merged, `2> err` for prefixed. `AgentsHarnessToolStreams` is the old form and is now unused. A second call site adds the branch, not the helper.

## The session chat's ts and conversation are stamped beside the index

- **A post's ts and its conversation go into `session.chat.stamps`, one appended line a block:** `<block>	<ts>	<conversation:thread>	<seen>`. `session.chat.index` keeps the `-` it was written with.
- **A reader of a record's ts or conversation reads the resolved index, `AgentsToolsSessionChatResolve`, never the index file alone.** A check that reads the index file directly sees `-` for both fields. Measured 2026-11-17 in a rig: the index line read `1 - - own 1 -`, where the stamps line read `1	1760000001.000002	CRIG00001:1760000001.000001	-`.
- **A send is counted by the log rows that name it.** A whole-log total moves by rows the tooling appends itself, such as the event-track notice, so a before-and-after total is no measure of one send.

## Close refusals, the owner-ruling guard and the decision strike

- **The board writer refuses a close while the item's `condition:` stands, and a close of an item in `board-parked`.** The three closing states are processed, archived and retained. The refusal reads the item as the write would leave it, so a close that clears the condition in the same write still lands. A move out of `processed`, which housekeeping makes into archived or retained, is no close of a live item.
- **`--record-decision` records a line only through a confirmed readback on the same item.** A line that tells a decision by the human-owner also needs the message or the ask's verdict it came from. That goes in `--source`, or a readback he confirmed carries it.
- **`--record-decision --strike <exact line> --reason <text> --readback <id>` marks a recorded line struck in place.** It appends one `dismissed` line naming what was struck and why.

## The epic go is read live from the blueprint

- **The go of an approved epic is read live from its blueprint, never copied onto a child.** `AgentsToolsBoardItemEpicGo` (`sh-lib/board/AgentsTools.BoardItemHandler.include`) prints the blueprint's `approved-by`, and `AgentsToolsVaultItemKey` (`sh-lib/vault/AgentsTools.VaultPlace.include`) is the vault's own frontmatter reader.
- **A board item names its epic in `epic:`, a bare vault item name in `item-names` form.** Two readers take the go from it: the start gate in `sh-lib/schedule/AgentsTools.DispatcherSchedule.include`, and the recall refusal in `sh-lib/board/AgentsTools.InternOpBoardUpsertMoveEdit.include`.
- **A recall to `board-backlog` is refused where the item names an epic whose blueprint carries `approved-by`.** `--grooming-to-backlog` and `--move-to-backlog` both reach that one point.

## The knowledge index is built on a schedule and kept fresh

- **`AgentsTools.KnowledgeIndexPlace.include` is the one place the index root and its two stamps are spelled.** `AgentsToolsKnowledgeIndexRoot` and `AgentsToolsKnowledgeIndexStamp` live there, and every caller loads it on its own path.
- **`AgentsToolsKnowledgeWantedMark` touches `wanted`.** `AgentsToolsItemUpsert` calls it for the board, the vault and the audit, and the member inbox upsert calls it for every inbox. `AgentsToolsKnowledgeIndexBuild` writes `built` only after a build that finished, so a refused build leaves the next pass to try again.
- **`AgentsToolsScheduleThreadKnowledgeKeep` runs once in each schedule pass.** It rebuilds when `wanted` is newer than `built`, or when `built` is older than `MDAT_SCHEDULE_KNOWLEDGE_INDEX_SECONDS` (900, and 0 turns it off). The 900 s bound catches a hand edit to a project `MAGIC.md`, which no writer marks.
- **A write and a build inside one second cannot be ordered by mtime, so the pass rebuilds unless `built` is strictly newer than `wanted`.** That costs at most one extra build an hour.
- **The query names its source on stderr, beside the dropped-sections count:** `answered from the index`, or `answered from the text alone` with the reason. The answer text is unchanged by that line. `AgentsKnowledgeIndexKeepCheck` (`sh-test/team-data`) holds all of it, 13 assertions offline.
- **`AgentsKnowledgeStore.py query` takes `--sources <file>`, the refs the caller may read, one a line**, and filters rows on them before `--limit`. A row outside them is filtered before the limit rather than dropped after it, so it never spends the answer.
- **The index groups are coarser than a caller's own files.** The index holds every project's docs and every member's inbox, where a call reads the projects it selected and its own inbox.
- **A ref is the path below the root it stands under, as `AgentsKnowledgeScan.awk` writes it.** `AgentsTools.Knowledge.include` builds that file from its own list, stripping `MDAT_DATA_ROOT` first and `MMDAPP` second, and passes it for `--add-source-docs` and `--add-inbox-items` only. `AgentsToolsKnowledgeFiles` prints absolute paths, so the strip is what turns them into refs. A source under neither root contributes no ref, and an empty list answers nothing.
- **The filter makes a query faster, because the index scans fewer rows.** Measured at 2026-11-21 22:04 +0200 over 1210 inbox refs on a store of 101281 rows: 5.19 s, 5.62 s and 5.38 s with the predicate, against 15.40 s without it.
- **The lancedb stand-in applies the predicate its search is given** (`sh-test/check-fixtures/knowledge-store-lancedb.stub`). Its `_matches` strips the backticks round a column name, because the store writes the group predicate as `` `group` IN (...) ``. A stand-in that ignores `where` answers every group, so an index check that passes no predicate measures nothing.
- **`AgentsKnowledgeStubMatchCheck` (`sh-test/team-data`) is the check of that surface**, naming every predicate form the engine writes, the one grouped call and the full-text reader. `AgentsKnowledgeLookupAdvertisedCheck` (`sh-test/help`) holds the lookup's presence in the served list and in the help page.

## The rigs list and the scan's every-rig default

- **`--supervise-rigs` (`AgentDispatcherTools`) prints the rigs the team runs, one line a rig:** the workspace root, a TAB, and its owner account or `-`. It is read only.
- **A rig is a workspace whose own settings make it a team rig and run the team duties.** That is `MDAT_WORKSPACE_MODE=team-rig` of its `magic-team` scope, read through `AgentsToolsWorkspaceMode`. A workspace naming an owner account but running no schedule is no rig.
- **The roots come from the places list's workspace rows, this workspace first.** A workspace the machine does not know is never a rig, and the mode test keeps a run's sandbox and a check's rig out.
- **`--supervise-scan` with no `--workspace` scans every rig that list names.** With no rig found it prints one `error` line and fails, rather than printing nothing. A `--workspace` that is no rig is refused in one line naming it, and the call fails.
- **Each rig's owner account is the rig list's answer, and the scan passes it to the `owner-owed` reading.** That reading reads the rig's own conversation with its owner. A rig naming none is still scanned, with no `owner-owed` line.
- **The implementation is `sh-lib/supervise/AgentsTools.SuperviseRigs.include`, and its check is `sh-test/session/AgentsSuperviseRigsCheck.test.sh`.**

## The supervisor reads owner-owed from the comms cache

- **The supervisor reads `owner-owed` from the comms cache, never by a Slack call of its own.** `--supervise-scan` carries the line for each message of the human-owner that no other account answered in its own thread. The cache is `$MMDAPP/.local/cache/comms/slack/<service>-<id>/YYYYMM/messages.txt`.
- **A cache folder's conversation and thread come from its own `.state.txt` pulling line** (`slack-conversation <target>`, `slack-thread <channel>:<thread ts>`), never from its folder name. The store owns that fact, as the cache-to-inbox transfer reads it.
- **A conversation counts for `owner-owed` when its target is the team channel (`SLACK_CHANNEL_MAGIC_TEAM`) or a direct one (`D…`).** Another channel holds no conversation of his, and the mentions and search partitions hold none at all.

## An include file's header names only the functions it defines

- **An include file's header names only the functions that file defines.** `sh-lib/session/AgentsTools.SessionStore.include` named `AgentsSessionDeathFile`, which no file defines. Its header now names `AgentsSessionStoreDirInto` and `AgentsSpawnedStoreDirInto`, the two forms the file does define. `sh-test/session/AgentsSessionStoreHeaderCheck.test.sh` holds it.

## The review wait limit counts from an answer to the run

- **The review wait limit counts from the later of two moments.** One is the item's `review-since-epoch`. The other is the newest answer to an ask of the run's session.
- **That answer is read from `.local/agents/pending/answers/<session>.epoch`.** The ask store's own close writes it, and never lowers it. So a run that has its verdict and is applying is never ended mid-apply.
- **`AgentsToolsPendingReplyAnswersSeed` writes those files once, from every answered record.** That covers the answers closed before the measure existed. It is a one-off at the change, never a schedule step. A session with no file reads as no answer, so its limit counts from review entry as before.
- **A record's frontmatter field is read with `AgentsToolsFrontmatterKey`, never an inline awk.** Two inline copies of the session-id read stood in this package, and the SOLID gate reported them as a P4 duplicate. `AgentsTools.Grants.include` and `AgentsTools.InternOpPendingReplyClose.include` both call it now.

## The scan prints the live SOLID gate's kept reading as `solid-delta`

- **`--supervise-scan` reads the live SOLID gate's kept reading, and prints it as one `solid-delta` line a workspace.**
- **The marker is `<workspace>/.local/agents/solid-gate.last`, four lines: `total`, `at`, `zero-at` and `package`.** It sits under `.local/agents`, beside the tooling's other `.last` measures.
- **One writer and one reader carry it.** `AgentsToolsSolidGateMarkerWrite` writes the marker and `AgentsToolsSuperviseSolidDelta` reads it, both in `sh-lib/supervise/AgentsTools.SuperviseSolidDelta.include`.
- **A later run that reads rows leaves `zero-at` standing.** The delta then spans every file the tree has moved since it last read 0.
- **The gate keeps the reading only under `--record <workspace>`.** `sh-test/solid/AgentsSolidBreachScan.sh` then writes the marker, and exits 1 where it cannot.
- **A scan never runs the gate.** It reads four lines and runs one `find`; the gate itself costs about 30 s over the package.
- **A workspace with no marker prints no line at all.** An absent `solid-delta` is a gate that never kept a reading, never a clean tree.
- **A tree that never read 0 prints `zero=none files=0`**, rather than naming every file it holds.
- **A marker naming a folder this host cannot read prints its age with `-unread` after it.** That is never a zero, which would read as a clean tree.

## A voice clip is read only where the local AI feature is installed

- **A voice clip is read into text only where the local AI feature is installed on the machine.**
- **The reader is `sh-lib/comms/AgentsTools.VoiceTranscript.include`.** It tests `${MDCI_FILES_PATH:-/usr/local/mdci-files}/local-ai/mdci-local-ai` with `-x`, at `:36-37`.
- **The deploy puts that command at the tested path.** `setup.feature-local-ai` syncs `data/local-ai` to `/usr/local/mdci-files/local-ai`. Its `1.install` and `2.check` fragments read the same expression.
- **The source tree holds the very file the deploy would place.** That is `mdci-packages-myx/setup.feature-local-ai/data/local-ai/mdci-local-ai`. A probe of it answers about the tree that holds it, never about a machine.
- **Where the command is absent, the annotation reads `[voice: untranscribed]`.** One line on stderr names the feature.
- **The untranscribed state is kept beside the clip.** It is at `.local/agents/schedule/voice/<member>/<file-id>`, so no later poll looks it up again.
- **One clip is transcribed once.** Its words live in that same file, as the seen reactions live in `schedule/seen`.

## A workspace's own namespaces (`--list-places`)

- `DistroAgentsKnowledge --list-places` prints a fourth tab-separated column for a workspace place: its own namespaces, by the mdci convention. A place with none prints its three columns, as before, so readers of three columns keep working.
- First choice: the namespaces whose `util.repository-<namespace>` project the workspace's `source` holds. That project is the namespace's whole maintainer.
- Second guess, marked `~`: the namespace folders of its `util.workspace-*` projects, such as `~myx` for `myx/util.workspace-myx.devops`.
- A workspace may hold several namespaces. ws-2017 (myx-work) holds ten while it is split.
- A declared maintainer directive, read before both conventions, is planned in grooming: `inquiry-20261118T1749Z-grooming-namespace-maintainer-directive`.
- Another namespace's tree is read in its own workspace, through `--get-place-path <workspace>/<relative>`. A copy of it in your own workspace is not its tree.

## Stage origins for a check


- A check runs on an origin made of real copies: `myx.distro-agents` plus its six sibling packages, `myx.distro-.local`, `myx.distro-system`, `myx.distro-source`, `myx.distro-deploy`, `myx.distro-remote` and `myx.common`, each by `rigCopyTree`. It syncs each into a lane of its own with `rsync -rtLO --delete --exclude=.git`, sending only what changed, and clones the lane into the rig. That is about 108 MB.
- A package-only origin gives false results: a check that reaches a sibling fails on `No such file`, and with no config there is no remote.
- A copy of the whole `source/myx` tree is 1.6 GB, and 49 such copies filled scratch to 62.9 GB. Never copy it whole.
- An origin holds no link into a source tree. Check with `find <origin> -type l` before the run, and remove the origin once its run is read.
- A pair runs red then green in one job, so it holds one ticket of the machine's test line at a time.

## An ended run's next step goes by `--return-review`

- A run that handed back has ended. Its next step, a gate verdict included, reaches it only by `--return-review <item> --message <step>`, which restarts it in its own conversation.
- A message to the ended run's session thread is stored and read by nobody, whatever the send reports.
- Before writing to a run, read its state: `--supervise-read <run>` shows `END outcome=...` once it has ended.

## The spawned/ store's stamp

For developers of this package. Every list kept against the spawned/ store keys on one stamp, so no reader walks the store to learn whether it changed.

- **The stamp is spawned/ itself: its mtime.** `AgentsSpawnedStoreStampInto` (`sh-lib/session/AgentsTools.StartedRecords.include`) reads it with one stat and no walk. No other file holds it.
- **Two store functions move it, and nothing else writes a record.** Both live in `sh-lib/session/AgentsTools.SessionStore.include`, and each touches spawned/ only after its rename or `rm` succeeded.
  - `AgentsSpawnRecordWrite <run|record path> [folder] [text]`: every create, rewrite and close, the record's whole text on stdin, in one rename, mode 644. A run id writes `spawned/<folder, else the run>/<run>.spawn.md`. A path must lie in a spawned/ store. Given a text, the record is replaced only while it still holds that text.
  - `AgentsSpawnRecordRemove <folder>`: every removal of a folder of spawned/, with its records.
- **What the stamp means.** It changes after the tooling creates, rewrites, closes or removes any record.
  - A reader holding an equal stamp may conclude that no tooling write happened since it took its key, and nothing more.
  - False positives are allowed: a moved stamp may mean nothing this reader cares about changed.
- **How a reader keeps a key.**
  - Compare by inequality only, never by order or `-nt`.
  - An empty or unreadable stamp means walk.
  - Read the clock first, then the stamp, and keep the key only where the stamp is older than that clock. Mtime has a 1 s resolution, so a write later in the stamp's own second leaves it as it was.
- **The readers.**
  - `AgentsToolsSpawnedSessionRecords`: `records.kept` of the session, first line `stamp:<stamp>`.
  - `AgentsToolsSpawnedStartedRecords`: `schedule/started.records`, its TTL as well.
  - `AgentsToolsCommsActivityPass`: a variable of the comms thread, for its idle shortcut.
  - The spawned-sessions registry: `AgentsToolsRegistrySpawnedSessionsRebuild` sets its mtime to the stamp it was built against, in UTC. A stamp not kept dates it one second earlier, which no later stamp equals. `AgentsToolsSpawnedRegistryFile` rebuilds it where the two differ.
- **The safety net.** `AgentsToolsAdvanceSpawnHousekeeping` checks every record in its pass over the store. A record newer than the stamp is reported as a missed write, and the stamp is then touched.
- **The checks.** `sh-test/session/AgentsSpawnedStoreStampCheck.test.sh` fails on any `>`, `>>`, `mv`, `cp` or `rm` onto a record or a folder of spawned/ outside the two functions, and rigs the readers. `AgentsHotPathWalksCheck` lists no stamp walk.
- **Gotcha: the static check knows a record parameter only by its function's comment.** Name such a parameter a spawn record, run record, parent record or tracking file in the `## ` comment of the function line.

## A live team-data thread shows parent 1, and the store lock is held only for a pass

- **A `--intern-team-data-commit --run` process has parent 1 by construction.** `AgentsToolsOnDemandThreadStart` forks the thread in a background subshell and returns without waiting (`sh-lib/common/AgentsTools.OnDemandThread.include:117`). The thread then takes `/dev/null` as its input and a log of its own (`sh-lib/team-data/AgentsTools.InternTeamDataCommit.include:80`). The shell that started it ends, so the thread is reparented to 1.
- **`thread.lock` and `store.lock` answer different questions.** `thread.lock` holds `<pid> <start>` of the living thread for its whole life, so one held for half an hour is normal. `store.lock` is the git lock, taken for one commit pass and given back at its end (`sh-lib/team-data/AgentsTools.TeamDataCommit.include:85`, `:90`, `:134`, `:139`).
- **Two parent-1 threads are not a wedge, and one store gets one thread.** Each thread holds its own store's `request.fifo` and `thread.log` open, so its descriptors name the store it serves. Read them with `lsof -a -p <pid> | grep team-data-commit` before calling two threads a conflict: they are usually two stores.
- **A long-lived parent-1 thread is not a wedge on its own.** The thread ends by itself once no request came for `MDAT_TEAM_DATA_COMMIT_IDLE_SECONDS` (60), so one alive for many minutes is serving requests or is stuck. `ps` alone cannot tell the two apart. Read `store.lock` beside `ps`.
- **The fault is a `store.lock` whose holder still answers `ps` after minutes and is never seen absent.** A healthy pair leaves the lock absent between passes.
- **Measured 2026-11-19, 15:42 to 15:53.** Two parent-1 threads were alive, started 15:03 and 15:12. `lsof` showed one serving this workspace's store and the other another workspace's. On this workspace's store, `store.lock` existed at 15:42 with mtime 15:42, and its holder was not read then. It was absent at six samples five seconds apart from 15:43. At 15:46 it held the 95028 thread at three samples four seconds apart. `thread.lock` held 95028 without a break throughout.

# sh-test/AgentsRunTests.sh — the test runner

AgentsRunTests.sh -- runs sh-test/*.test.sh and sh-test/*/*.test.sh in parallel (myx.common lib/parallel) and keeps
one log and one receipt per test in a run folder, in the folder the run was started from: the
session's own output folder where a session runs it, the workspace's .local/temp otherwise:
  <that folder>/mdat-tests/<UTC-stamp>/<test>.log      the test's whole output
    (<UTC-stamp>-<pid> for a run started in the same second as another)
  <that folder>/mdat-tests/<UTC-stamp>/<test>.receipt  rc, seconds, last line
  <that folder>/mdat-tests/<UTC-stamp>/summary.txt     PASS / FAIL per test, each failure with its owner and reason, totals
and points <that folder>/mdat-tests/latest at it.

Usage: AgentsRunTests.sh [--wait] [-w <workers>] [-t <timeout-seconds>] [--stall-margin <seconds>] [<name-substring>...]
       AgentsRunTests.sh --passed [<name-substring>...]
       AgentsRunTests.sh --sweep-rigs-list [<hours>]
       AgentsRunTests.sh --sweep-rigs [<hours>]
  --sweep-rigs-list runs nothing: for each rig folder under $MMDAPP/.local/agents/scratch/sh-test older
  than <hours> (24 unless given) that no process names, it prints one line, `sweep: would remove <rig>`;
  a rig a process still names, and a rig holding a link that reaches a source tree, are printed as kept
  with the reason. --sweep-rigs removes those same rigs, immutable flags and read-only modes cleared first,
  and prints one line each and a summary; the kept ones stay. A check ended by KILL runs no trap, so its
  rig stays until this sweep (board task 20261107T1905Z).
  no substrings: every *.test.sh of sh-test and of its subfolders, one level down (a test is
  known by its name, so no two share one); otherwise the tests whose name contains any of them.
  --passed runs nothing: for each of those tests it prints one line, `<test> <when>`, the
  time it passed on the very state it would run on now, or `<test> -` where no such pass
  is on record (the pass record, below).
  Workers: one unless -w is given.
  Each line of the run list is `<test> <timeout-seconds>`; -t sets the timeout written
  into each line (default 900).
  Status: 0 every test passed, 1 a test did not or the run was refused, 124 the run stood
  still and was ended (A RUN THAT STANDS STILL, below), 75 the run was queued and goes on detached, with no result yet.
  --wait: a run whose turn has not come waits for it in this call. Without it, the run never holds its caller: it
  goes on detached in its place in the line, and this call names where its result will be (NOBODY SITS ON A WAIT, below).
  A run left detached waits up to 3600 s for its turn unless the machine sets MDAT_SUITE_QUEUE_LIMIT, since nobody waits on it.
  Known failures: every failure of the suite has an owner and a reason, kept beside this runner in
  `known-failures.txt`, one row a test, TAB between its three fields: the test, its owner, and why it is
  red. A FAIL line carries them, a test of the list that passes is printed FIXED, and the last line counts
  the failures that have an owner and those that do not. A list that is not three filled fields a row is
  refused before any test runs (THE FAILURES HAVE OWNERS, below).

Each test gets a test-only session identity, so no test can write into a live session store.
And nothing of the session its runner was started in. A member's session that a spawn started
holds more than its id and its member: its coworking session and that session's thread, the
conversations it continues, its sandbox, its launch marker, whether its caller waits. Every
MDAT_SPAWN_* and MDAT_SESSION_* variable is taken out, and MDAT_CONVERSATION_THREADS: a rig
that found them was no session of its own. Its spawn joined that session and took its thread,
its question to a member went there, its harness kept its scratch in that member's sandbox.
And each test is handed the member folder of the workspace the run is in, never the one the
session that started the run serves: a test that read that one would act as a member of another workspace.
And its waits remind no ask (MDAT_WAIT_REMIND=off, AgentsTools.MemberWait.include): the asks of
a rig carry the ts its fake Slack gives, years old, so every wait that brings nothing would
remind them, one more post than a scenario counts. A test of the reminders unsets it.
And no test starts the communications reader (MDAT_COMMS_READER=off, AgentsTools.SessionComms.include):
a detached process of the tooling that a rig's spawn would leave running after the rig is gone. The
check of the reader unsets it, and ends what it starts.
And none starts the thread that updates the sources a scan reads (MDAT_COLLECT_THREAD=off, AgentsTools.CollectThread.include): the same
kind of process, left running after its rig is gone. The check of the thread unsets it, and ends what it starts.
And none starts the thread that commits and pushes the team data (MDAT_TEAM_DATA_COMMIT_THREAD=off, AgentsTools.TeamDataThread.include): with it off
a writer commits in its own process, as before the thread. The check of the thread unsets it, and ends what it starts.
And none starts the schedule's service thread (MDAT_SCHEDULE_THREAD=off, AgentsTools.ScheduleThread.include): with it off the main loop runs
the schedule's steps in its own process, as it always did. The check of the thread unsets it, and ends what it starts.
And a rig that sets no workspace mode is a team rig (MDAT_WORKSPACE_MODE=team-rig, AgentsTools.TeamDataGate.include): its mode is the
default the one reader of the mode gives, which a setting of the rig stands ahead of. Unset, a rig is just agents and keeps no team
data (F13.1). The checks of the gate and of the digest set or unset it themselves.

WAITING IN THE LINE, IN ARRIVAL ORDER, AND MORE THAN ONE LANE. Every run, of every test (no name
given) or of named tests, waits its turn in arrival order and says in one line that it waits and
behind whom, across every builder of the machine. The line is one folder on the machine,
$HOME/.agents/magic-team/suite-queue, never a folder of the package: a runner started from any copy
of the package (MDLT_ORIGIN) stands in the same line. A ticket is a file named by its arrival time, holding
the session of its run -- `session=<session-id>` -- and one whose run has ended is taken out by whoever waits
behind it, so no turn is held by the dead. A ticket that has held the line past MDAT_SUITE_QUEUE_HOLD_SECONDS
gives it up too, however alive its run looks, and so does one whose waiting holder stopped beating past
### MDAT_SUITE_QUEUE_STALL_SECONDS.

HOW MANY RUNS STAND BESIDE EACH OTHER, AND WHAT DECIDES IT. The line became the team's throttle, and the pace line
the schedule keeps is its only measure: the median machinery time of a tool call of the live runs over
MDAT_TOOL_PACE_WINDOW_SECONDS (300 s), held against MDAT_TOOL_PACE_MS (4000 ms). Neither load average nor a probe of
this shell's own speed is read. The runner never takes that measure, which walks the whole `spawned/` tree: it reads the
file each rig keeps it in, `<rig>/.local/agents/schedule/pace.measure`, of the rigs AgentsToolsSuperviseRigs names, and the
freshest one decides. Lanes are laneMax, the machine's own count (suite-lanes/max, else MDAT_SUITE_LANES, else 3), while
that measure reads under the gate, rests on fewer than 3 calls, is older than MDAT_TOOL_PACE_CACHE_SECONDS (60 s) or is on
no rig: a duty start is allowed on the same readings. Over the gate it is one lane. A count set by hand in suite-lanes/count
wins, up to laneMax. The count is read when a run joins the line and again every 15 passes of its wait.

A LANE IS WHAT A RUN HOLDS, AND THE QUEUE IS STILL IN ARRIVAL ORDER. A run takes one lane at its turn
and gives it back when it ends, so two runs stand beside each other exactly as many lanes allow. A
ticket ahead of this run that holds no lane is the head of the queue and is waited for, so a run that
arrived first starts first. A run with a test that measures its own timing takes EVERY lane and says
so: a test declares that with `## lane: alone` in its header, and such a test never runs beside
another test or another run.
The hand rule this replaces, `mkdir $MMDAPP/.local/temp/suite-run.lock` around a run,
is kept, so a session on the hand rule and a queued run never run at once: while another session
holds that lock every lane is shut and each run waits, naming it. A lock taken by hand is no turn:
one whose note names the folder this run's source root is in, under $MMDAPP/.local/temp, is the
caller's own, and the run starts under it only when its own turn in the line has come, leaving it for
the caller to remove; with any run ahead of it in the line the run is refused, saying so. A lock left
by a runner that no longer exists is removed; one taken by hand never is. A lock a run left behind,
whose folder holds a receipt for every check it took the lane to run, is past all its checks: lane 1 goes
back, the place that run still holds in the line goes with it, and the line says which session left it.
The count is the run's own, written on the lock as `checks=`; a lock naming a folder and no count is judged
by the checks its `tests.list` names.

A RUN GIVES ITS LANES UP BETWEEN ITS CHECKS WHILE ANOTHER WAITS FOR THEM. At each boundary between two of its checks a
run that holds lanes reads the line: a check started by hand behind it, or a run behind it with no lane free, waits for
it. Its workers stop at their boundaries, its lanes go back, and `<ticket>.yield` tells every waiter to pass it by. Once
each ticket it yielded to holds a lane, has won its turn or is gone, the mark goes and it takes free lanes again; it never
waits for such a run to end, and waits 120 s at most in all. It runs a check between two yields, so it is
never starved, and its order, logs, receipts and summary are as they were. At its turn a run writes `rundir=` on its
ticket, so a waiter says of it how many of its checks are done.

NOTHING RUNS AROUND THE LINE. A run that cannot be given a lane says so and refuses; a test started by
a run carries that run's ticket (MDAT_SUITE_QUEUE_TURN) and stands in no line of its own, and a ticket
that is no file of the line buys no run anything.

ONE BUDGET OF TEST WORKERS FOR THE WHOLE MACHINE, shared by every runner, of a full suite
or of named tests, from any copy of the package: a test takes a worker slot before it
starts and gives it back when it ends, so the tests running at once on the machine never
pass the budget, whatever each runner's own number of workers. The budget is half the
machine's cores unless $HOME/.agents/magic-team/suite-workers/budget holds a number. Slots
are asked for in arrival order, across runners, so a run of named tests is not starved by
a full suite; the runner says in one line when a test of its waits, and how many slots
are in use. A slot is held by the test's own process: one whose process no longer exists
is given back by whoever asks next. Tests run at a lowered priority (nice 10, or the
runner's own where that is lower still), so a person's own work on the machine comes first.
The hand rule the budget replaces, `mkdir $MMDAPP/.local/temp/one-test-run.lock` with a
file `owner` naming the session's scratch folder around any test run, is honoured for as
long as any session still holds it: no test takes a slot while another session holds that
lock, and the runner says whose it is. A run can tell whose it is only by the folder its
own source root is in, under $MMDAPP/.local/temp: a lock naming that folder is its
caller's own, and so is any such lock to a run from a tree that is no scratch folder.

THE DRIVER IS HANDED ITS WORKERS, NEVER THE TESTS. lib/parallel starts a job for each line
it reads and, once as many run as it has workers, waits to be told that one has ended
before it reads on. It is told through a helper process of its own, and a driver whose
helper is gone is never told: it waits for ever with no test running, and no job is left
to wake it (2026-10-13: 192 named tests, 56 run, then more than an hour of standing
still; the helper of that run was gone, and nothing of the driver looks after it). So the
driver reads one line for each worker and no more: it starts them all at once and has
nothing to wait for but their end. Each worker takes the tests of the run list one after
another, each time the first that no worker has taken, until none is left. A test is
taken by whoever makes its log, which is made whole or not at all, so no test is run
twice and none is left out. What runs at once, and the order in which the tests start
and ask for their slots, are as they were: as many tests as workers, in the order of the
list.

A RUN THAT STANDS STILL IS ENDED, AND SAYS SO. Every start and every end of a test is
written in the run folder, and so are each line a test prints and the note, made again
each minute, that a test waits for a slot. A watch beside the run looks at the folder.
Once nothing in it has changed for longer than a test may take (-t) and a margin more
(--stall-margin, default 120 seconds), no test of the run is running and none waits, so
the run is ended: the driver is stopped with what is left under it, the summary is written
with what did end, the tests that never ran and those that started and never ended are
named, in the output and in <run folder>/stalled.txt, and the status is 124. The watch
counts the time as it goes and never reads it off the clock, so a machine that slept is
not taken for a run that stood still. A margin under 61 seconds is for a rig alone: a
test that waits for a slot is seen to wait once a minute. A run whose tests have no time
limit (-t 0, or no number) has no watch: there is no time by which a test must have ended.

A PASS IS KEPT BY THE CONTENT IT WAS EARNED ON. After a test passes, the pass goes on
record under a key made from the content of everything the test can read: every file of
the copy of the package this runner is in (its tests and their fixtures, sh-lib,
sh-scripts, the skillset, the docs, project.inf, this runner), every file of the tooling's
other packages under the same source root (myx.distro-*, myx.common), of myx.common as it
is installed (MYXROOT), and of the member folder of the workspace the run is in, which this
runner resolves for its tests, with the shell and the system the tests run under. Paths below
those roots and content only, never where a root lies: a copy that is byte for byte another
shares its passes. The key is made before the test starts and again once it has passed, and the
pass is kept only where the two agree, so a pass on a tree that moved under the test is
kept for no state. Only a pass is kept: a failure is no record, whatever made the test
fail. Not in the key: the workspace's own data and the machine's state, which the rigs of
the tests stand in for. The record is one folder on the machine,
$HOME/.agents/magic-team/suite-results, a folder for each test and in it a file named by
the key; a pass is believed for seven days, and every run removes the ones older than
that, of every test. A run reads none of it and runs what it is told: `--passed` is the
one reader, for whoever decides what is left to run, as the retest queue does
(sh-lib/member/AgentsTools.MemberRetest.include).



## sh-lib/team-data/AgentsTools.TeamDataGate.include


AgentsTools.TeamDataGate.include -- THE MODE OF THE WORKSPACE (F13.1) and THE GATE it carries: which workspaces keep team data, and the
writers that refuse where one does not. Sourced, never run. Functions and declarations only, and nothing runs at the sourcing.

THE MODE OF THE WORKSPACE, the owner's: what this workspace is to the team, one of three, set by the installer of the workspace in the
settings of the team, where the tooling keeps the workspace's own settings (the magic-team scope), and read by AgentsToolsWorkspaceMode
alone, for the digest of the console and for the gate alike. `just-agents`: not a team with infrastructure here. The team's members and
their skills are here and nothing else of the team: it works inline and starts sessions with the native consoles of this computer. Slack
and the other outside systems still work where they are set up. `rig-client`: it will start sessions on a remote rig or dispatch
documents to it; declared and not built, it acts as `just-agents`. `team-rig`: it is a rig itself, which uses and maintains the team
data here, with a shared persistence for it or none; no server setup makes one so, its installer does. Where nothing sets one of them
it is `just-agents`: nothing is inferred. A rig that sets no mode is given the mode MDAT_WORKSPACE_MODE names as its default, which
only the test runner exports (AgentsRunTests.sh gives `team-rig`), and which a setting of the workspace stands ahead of. A FULL TEAM RIG
is a `team-rig` whose team data has a shared persistence configured, today a git remote: only a full team rig checks the main loop and
judges it. Only a team rig has a main loop at all.

WHAT `just-agents` MUST NOT DO. It keeps no local team data, so it never creates or changes:
  - a board item, in any state: not by a board op, not by a grooming, advance, sweep, daily or retro pass, nor by the
    review of a run (the primitives are the gate's list, below);
  - an inbox item: a note, an inquiry, a reflection, a routine's lock note, a reply left for a member;
  - an audit item: the transcript of a session, the record of a published artifact;
  - a vault item, a contact or an organisation, a trash entry, or the README of a store;
  and it never clones, initialises, commits or pushes a team-data store (TEAM_DATA_GIT_REMOTE is not read), and runs no main loop.
A session it starts keeps no tracking item and no transcript in the team data: the spawn runs as `--dispatch-doc:none`, which the spawn
proxy already has, and a start that asks to reuse a tracking item is refused, since that item would be of a store that is not here.
It still keeps what a session needs to run and be found, which is no team data: the session records and stores under .local/agents.

THE GATE. One list, agentsTeamDataGateOps, of the operations that create or change team data, asked in one place, where the tooling
dispatches an operation (DistroAgentsTools.fn.sh, after the caller checks, and the front door of each tool file, AgentsContext.FrontDoor.include): a workspace that is no team rig refuses them there, before
the operation makes a folder or says a word. The list holds the primitives every item passes (so an op that reaches an item by way of
them is refused at the first of them, whatever its name) and the families that are the board's own machinery. Three writers have no
primitive to pass, and ask the gate where they write: the contacts store (AgentsToolsContactsWriteFile), the clone of a team-data store
(AgentsToolsTeamDataEnsureClone), and the spawn proxy, which degrades as said above. A reader is never refused: a store that is not
there reads as empty.

## sh-lib/harness/AgentsContext.FrontTable.include


AgentsContext.FrontTable.include -- the tool files and the operations each of them owns (F1.4 of the refactorings epic). Sourced, never run.
Declarations and functions only.

agentsFrontTable is one line a name: the entry function of the tool file that owns it (the file is sh-scripts/<function>.fn.sh), the name, and who
may call it, `member` (any member) or `coordinator` (magic-coordinator's only, as the --magic-* operations were). A tool file asks AgentsToolsFrontKnows
first; DistroAgentsTools.fn.sh has one rule for the names of the table, AgentsToolsFrontRoute, and no arm for any of them.
The names the operations had, and the refusal of one, are in AgentsContext.FrontTable.Retired.include: only a call of a
name this table does not hold, under a --member-* or --magic-* prefix, reads it.

# Call paths: what one call parses

Measured 2026-11-22, on this tree, in a rig of its own (`env -i`, a fresh `MMDAPP`, `bash -x`, the `+ .` lines summed by the file's
bytes). One call each, refusing for its missing arguments, so nothing but the load and the refusal ran. The number is what the call
sources before it does any work; the entry script's own bytes are read by bash as it goes and are not counted here.

| path | call | live workspace | fresh rig |
|---|---|---|---|
| front door, error-only | `DistroAgentsTools.fn.sh --intern-no-such-operation` | 62,817 | 62,817 |
| permission gate | `--intern-op-permission-grant-consume` | 118,448 | 161,747 |
| ask | `--intern-op-pending-reply-collect` | 93,474 | 136,773 |
| start / spawn | `--intern-op-agent-spawn-proxy` | 475,005 | 518,304 |
| Wait round | `DistroAgentsSession.fn.sh --wait-for-input` | 161,526 | 204,825 |
| schedule operation | `DistroAgentsDispatcher.fn.sh --spawn-prompt` | 106,459 | 154,064 |

The fresh-rig column is larger because a rig has no store: a call there takes the branch that builds and commits team data, which a working
workspace takes only when the store is missing. A budget is set on the environment it was measured in, and the rig is the repeatable one.

The largest files on those paths, by bytes: `sh-lib/spawn/AgentsTools.InternOpAgentSpawnProxy.include` 148,016; `sh-lib/grants/AgentsTools.Grants.include`
77,426; `sh-lib/team-data/AgentsTools.TeamDataCommit.include` 59,764 (on the ask, Wait and schedule paths alike); `sh-lib/session/AgentsTools.SessionStore.include`
49,873; `sh-lib/member/AgentsTools.MemberWorkspace.include` 26,704; `sh-lib/common/AgentsTools.CommonOptions.include` 23,322;
`myx.distro-system/sh-lib/SystemContext.include` 14,978; `sh-lib/harness/AgentsContext.FrontTable.include` 11,607.

A call path starts no process of its own either: the check counts every `awk`, `grep`, `sed`, `tr`, `date` and `ps` a call runs, and holds each path
to the number it measured (front door, permission gate and ask: none; start/spawn: the one `date` it stamps with; Wait and schedule: two, the
resolve's awk and the name's `tr`). Re-measure: a path's budget is the number above plus a margin, and the check that holds all five paths is `sh-test/harness/AgentsCallPathIsolationCheck.test.sh` (budgets in its own rig: front door 80,000, permission 190,000, ask 150,000, start/spawn 575,000, Wait 285,000).
A load added at a file's top on one of these paths moves its number, which is the regression this table detects.

## sh-lib/spawn/AgentsTools.InternOpAgentSpawnProxy.include


AgentsTools.InternOpAgentSpawnProxy.include -- internal spawn-proxy
primitive for agent/routine wrappers. No --help entry.

WE RUN FROM HERE: the member's session starts in this workspace, with this workspace's
settings, skillset and access rules for it, as its records, dispatch items and board
are this one's. A member set up only in another workspace on this machine is
invited: it reads its own skillset from there (AgentsToolsMemberSkillsetBring), and
the spawn stops only when that part cannot be brought, with the message that names
what is missing and where it was looked for. A client-* member is invited like any other.
THE THREE WORKSPACES OF THIS RUN, each kept on its records and said in its start post,
below: which EXECUTES it, where its console starts and its operations run; which PAYS
for it, whose CLI service and credentials it is started with; and the MEMBER'S, where
the member is set up and its skillset is read from.
The tracking name: identified BEFORE any tracking document exists, which is
why it is a caller-facing value and not derived from one. An existing spawn,
effort or interview is continued by passing its own name here, and a new one
is named by leaving this empty -- the session uuid is then the name, because
the uuid IS the tracking name, the session name and the spawn id.
The conversation threads this spawn continues, `<channel>:<ts>` space-separated:
a replacement for a session that was talking with someone keeps listening there.
Recorded as `conversation-threads:`, passed as MDAT_CONVERSATION_THREADS, and
their recent history lands in input/conversation.md.
Whether the session this spawn starts opens its session thread at once. magic-team,
the default, runs the ordinary session-starting/joining logic below. event-track is
an explicit override for a session that starts alone -- a non-interactive start of the
root harness uses it, so a solitary session never opens a coworking thread it has no other
member to share: it has its tracking thread only, and no session thread until it
brings a member in, whose spawn opens one in magic-team. A tracking thread is never
a session thread.
--calling-member: the member this spawn call is made as, said by a caller that knows
it where the calling session's own environment names none. The harness Agent tool
says it: a session never spawned carries no member, and each call it makes is served
as one.
--parent-session, --start-context and --reports-to: said only by a restart
(AgentsReviewRestart), off the record of the run it replaces, which this one continues:
the session that started that run, how it was started, and where it reports to. Recorded
as said, in place of what this call's own caller would give.
--parent-none, the restart's too: the run it replaces had no parent session and named no
address, and so has this one, whoever restarts it.
Which routine's own spawn-prepare-brief block is prepended ahead of the
spawn context, below -- a selector (full routine filename or part of one)
or the standing default. Never both; neither is the default behaviour of
every caller before these options existed.
The parent routine of an ad-hoc child: the child inherits that routine's
cache-prefix and its name goes on the record as `prefix-routine:`, so the
child's cacheable prefix matches its parent's (a token-cache hit, F10.7).
Not a routine the child runs: no requirement, allow or lock of it binds here.
The spelling this package already uses for the same thing: the
owner-setup option that writes SPAWN_TIER_NORMAL is spelled
--spawn-cli-service, so a per-spawn override of that same setting
is not given a second name.
PAYS. The CLI this spawn starts on and the credentials it is started with are spawn
settings, read from the workspace its console runs in unless another workspace known
on this machine is named to pay (AgentsTools.MemberWorkspace.include, SPAWN SETTINGS):
for this one spawn by --spawn-settings-workspace, else by the payer the session this
spawn is made from inherited, else for this member by SPAWN_SETTINGS_WORKSPACE in its
own scope, else for every spawn by the same key in the magic-team scope, which the
option reader follows by itself. Settled here, before anything is created, and
exported for the rest of this spawn, so its brief, its start post, its console and its
handback retry all read one workspace's.
THE PRESET CHOSEN FOR THIS SPAWN (F10.2), settled here after the workspace that pays and exported for the rest of
this spawn as that workspace is: `<preset>[:<effort>]` from the tier settings, the member's ahead of the team's
(AgentsToolsPresetChosen); nothing where none is set, and `-<service>` where the caller named a CLI service of its own, which
is not a preset's spawn. Never taken over from the session this spawn is made from. Every read of a spawn setting
then comes from that preset (AgentsToolsPresetOverlay). The models a leg exports for its own run are not handed on
to this one: the console gives its leg the model of its tier, and a stub takes an exported one ahead of its own.
Resolved before anything else runs, so a bad --session-id fails before any
dispatch item, sandbox or post is created -- never a silent new session.
Looked up in a command-substitution subshell, the same scoping
AgentsHarnessToolListAgents already uses for this same registry: the
functions AgentsTools.Registries.include defines, and the rebuilt
registry file it writes, stay behind that one fork and never touch a
caller running this op as a sourced function in its own long-lived shell.
A WORK-DUTY IS ONE INSTANCE PER MEMBER, IN ONE SESSION (sketch 14.5: "can only start one instance of such session per member"; 7.3). The
session a member's duty keeps (schedule/duty-session/<member>) is joined by every later start of its duty, from whichever caller
makes it, the schedule's or a console's; a kept id no record knows is dropped. The first start records its session under a lock,
below, where its session is settled.
A row for the session is enough to join it: it hands its thread down where it
has one, and none where it has not -- the joined-session branch below opens the
thread then. Only an id that no row carries refuses, never a session started
without a thread.
Measured, never refused: a dispatch brief a session cannot start
from is worse than one the floor would have flagged. A brief is written
for another agent, so it is reported only and never held back. Only the
spawner's own words are measured: the block the tooling puts ahead of a
brief is nobody's to rewrite, and a report naming its lines helps nobody.
The brief for the resolved routine, built ahead of the spawn context in
every source mode -- this is what makes the brief automatic rather than a
caller's own hand-carried text. Refusing here (a bad selector, a routine
file that fails its own contract) refuses the whole spawn, the same as any
other malformed input this far in.
A conversation thread that is a known session's own thread names the session
being replaced: joined, the same as --session-id, rather than a new one started
beside it. Only with no explicit --session-id, never for event-track, and only
when exactly one session matches.
A console carrying --cli-configured but no --cli) arm would fall out of
its own option loop on this flag, run its hardcoded default
interactively and STILL print the success sentinel -- the same failure
the vintage guard above exists to refuse, reached by a different door.
So the arm this spawn is about to use is checked, not assumed from the
other one being present.
Configured-only: an agent-initiated spawn starts the CLI named by
the preset's CLI service or it starts none. A console without the --cli-configured
arm cannot answer that -- it breaks out of its own option loop, runs its
hardcoded default interactively and still prints the success sentinel -- so
it is refused here rather than invoked.
STILL GREPPED FOR, and deliberately, even when this spawn names its own
service and will pass --cli instead: this string is what establishes the
console's VINTAGE, not what selects the mode. Dropping it because the
command line changed would retire the guard silently, which is the shape
of breakage nothing reports.
The session this spawn was started from, read before the export below
replaces it: a spawning session inherited its own id from its console.
Empty when the caller is no spawned session. Used by the event-track thread, and
to detach a spawn made from inside a session.
Falls back to CLAUDE_CODE_SESSION_ID for a caller at the top of its own
tree -- reached via the Agent tool directly, never itself spawned
through this proxy, so MDAT_SPAWN_SESSION_ID was never exported into
it. Same fallback AgentsTools.MemberEscalation.include:226 and
AgentsUniversalHarness.sh:745 already use.
The coworking session this spawn joins, read the same way and for the same
reason as parentSessionId above: captured before this spawn mints its own
values, so a caller already inside a session hands both down to its child.
Empty means this spawn starts a session rather than joining one -- spawn-id
and session-id then end up equal, the same "uuid is the session name" shape
a lone spawn already had before session-id and spawn-id were split apart.
The member the calling session acts as, read before the export below names the
spawned one: who starts a session that is the caller's own. Empty for a caller that
is no member's session. A root session, never minted through a spawn, names itself
through its own MDAT_TEAM_MEMBER, the same as every other caller (S21.21): read with
AgentsToolsTeamMember, never the narrower AgentsToolsActingMember alone, so a handback
of the child it spawns still finds a parent-member to address (load incident: a root
console session's spawn carried no parent-member at all, so its handback fell through
to the human-owner instead of the session's own thread).
The session the agent will actually run under, minted HERE so the same
value reaches both the CLI and the dispatch record below -- that shared
value is the whole join, since a hook reports the agent's own session_id
and nothing else carries it back. Exported rather than passed at each
console call, so both the waiting and the background branch inherit it.
Lowercased: uuidgen yields upper case and the flag wants a valid UUID.
The receipt, and the dispatch item named after it below: the stamp, this shell's pid,
and the first part of the spawn's own id. The stamp and the pid alone are one for two
spawns that one call makes inside one second (--spawn-session spawns its members
from one shell, one right after the other), and the second then took the first one's
dispatch item for its own. The id is what tells such spawns apart.
The coworking session's own id, settled here -- before the dispatch item
below, which needs it too -- rather than only later beside where its own
thread gets opened. THE SESSION THAT SPAWNS IS THE COWORKING SESSION, and the
tooling decides which that is, never the caller's memory of an id:
- an explicit --session-id joins that session;
- --session-new starts one of this spawn's own, and so does
  --session-thread:event-track, the main loop's own solitary pass: its session-id
  is its own spawn-id, the shape a lone spawn always had;
- an inherited id means the caller is inside a session, and this spawn joins it;
- a caller with a session of its own and no coworking session to hand down -- a
  native client session, never spawned through this proxy -- IS the coworking
  session: its own session id names it, the first member it brings in opens its
  thread, and every later one joins that thread (sessionOfCaller);
- a caller with no session id at all, a bare command line, starts one as before.
HOW THIS RUN IS STARTED, WHICH SESSION STARTED IT, and WHERE IT REPORTS TO, kept on its
record from its first write (`start-context:`, `parent-session-id:`, `reports-to:`), read
off the decision above: `joined` where it joins a session (by id, by a conversation, or
the one its caller is in), `inline` where it is brought into its caller's own session,
`spawned` where it starts a session. Its parent session is the session its caller works
in: the one the caller was handed, else the one the caller's own record names, else a
caller never spawned, whose own id names its session. It reports to that session, which
needs no field of its own (AgentsToolsRunRoute); where there is none, to the member that
made the call, else to the person whose account started it at a console, as
`user-<account>`. A restart says all three instead, for the run it continues.
WHAT THE ROUTINE REQUIRES OF THIS START, asked of the one evaluator (AgentsToolsRoutineRequirement) now
that the start's context is settled and before anything is made: a refusal leaves no record, no item and
no brief handed to a console, and names the start to use. The tracking item is attached where the
dispatch is created or reused; `required` with none attached is supplied here, as the dispatch the
spawn creates, and `forbidden` with one attached is refused.
ONE SEAT FOR A MEMBER IN A SESSION (F6.9): a member whose seat in this session a live run
holds (AgentsToolsSessionSeatHolder) is not started there a second time, and is asked
there instead; nor is the member a native client session runs as, in that session. A
restart of the run that holds the seat (--restarted-from) takes it over. Asked of every start, whatever its context:
a new session has no holder, and a start said `spawned` into a session that has one is a second run all the same.
THE ROUTINE'S LOCK (F6.2): a routine that names a locking document (`routine-lock-document:`, its own or its kind
routine's) is locked for this session while it starts, or the start fails, before anything below is made. A
member joining the session that holds it passes. It is given back where the last run of the session closes
(AgentsToolsRoutineLockRelease, from the record's `routine-lock:`), and here at once if this start fails later.
A SYNC FOLLOWS A MEMBER'S START (T2): the member's own incoming -- the personal mail of its `start` scope -- is refilled at
once, into its inbox, so the input scans below read fresh incoming. The sync is the tooling's own and best-effort: a member
with no mailbox or a failed source is no fault of the start, and nothing it says stops the spawn. It runs only where this
workspace keeps team data (the inbox it refills), and never for a start with no member. The `start` scope is the personal mail
alone: the tags and mentions are read by the schedule and the work-duty scan (F4.2: a source is read once for all).
A sync that cannot run is one warning on stderr, never silence: a missing function or a broken include is what made a
start with no sync at all, and neither the include's own error nor the sync's is thrown away here.
The spawn's own output is its session log, one per session and one name whatever
the dispatch mode: sessions/<spawn-id>/session.log, beside the session's other
state and never in the team data, where its transcript is the record. No dispatch
document with --wait: the waiting caller reads the child's streams on its own stderr.
Every writer opens it to append: the handback retry writes into it while the close
steps still hold it, and a writer at its own offset would overwrite that retry.
A session's name carries its short id, so two sessions sharing a name, or two of one member,
tell apart in a list of them. A name that already carries one keeps it as it is: a child of a
partitioned spawn carries its parent's, so the parent and its members read as one session.
A run that gave its session no name of its own keeps none: the suffix belongs to a name, and
a bare `(<short id>)` is a title nothing asked for (a run that only joins its caller's session).
The three workspaces of this run as its records keep them: each by its basename, never
a path, the convention of the record's own `workspace`. ALWAYS written, also where all
three are one: a record then answers each question by itself, a reader needs no rule
for what a missing line means, and a record written before they were kept reads as
not recorded, never as "the same". The start post, read by people at the moment, says
the member's and the paying one only where they are not the one we run from.
A REUSED tracking document is marked at the START, not only closed at the
end. Before this, --dispatch-doc:reuse read the named item as its brief and
then wrote nothing back to it ever -- no session id, no status, no result --
so the document named a spawn that was running and carried nothing saying
so. That is the whole of what made the tracking document a record in name
and not in fact, and it is why nothing downstream could consult it.
HEADERS ONLY: the caller's own body is never rewritten here. The state of the item it
reuses is settled in trackedItemState by the branch below.
This spawn's own sandbox, named by the tracking name -- which is the session
uuid unless the caller named an existing spawn, effort or interview to
continue. One identity under three words, and the primary key everywhere,
so naming the folder is not a second decision after identifying the spawn.
A tracking document's name is deliberately NOT consulted: the name is
identified before any such document exists, and a spawn may have none.
A member brought into its caller's own session keeps a sandbox of its own, named by
its spawn id: the session and its thread are shared, a run's input and output are
not. A spawn that joins a session by its id, or by inheritance, shares that
session's sandbox, as it always did.
An existing sandbox is joined, never refused -- continuing an existing
effort is what a caller-supplied tracking name is for. Said out loud,
because joining means this spawn shares one `output/` with whatever ran
under that name before it.
Created even when nothing fills them: the directory's own presence is this
spawn's registry entry, so an empty sandbox is a listed session rather than
a missing one. The run's own input folder stands beside the session's input/,
which stays as the folder every reader names and this run's is made under.
workspaceName is a basename, never a path -- the same convention the
team-members registry's own workspace column already uses. Computed once,
here, because both the event-track post below and the sandbox tracking
file further down want it.
The coworking session this spawn belongs to: session-id and session-thread,
distinct from this spawn's own spawn-id and agent-log-thread below. Settled
before the event-track start post, which names it.
--session-thread:event-track is an explicit, still-supported override (a
non-interactive start of the root harness uses it): the session starts with its
tracking thread only, and nothing is opened in magic-team for it here.
Otherwise: an inherited session-id, or an explicit --session-id, means
this spawn JOINS that session and opens no thread, only a reply; none means this spawn
STARTS one, session-id becomes its own spawn-id, and its own opening
post goes to magic-team, titled by --session-name-or-comment or else
the session id.
sessionId itself is already settled, above, before the dispatch item was
created -- only its thread is decided here.
A TRACKING THREAD IS NEVER A SESSION THREAD (AgentsToolsEventTrackThreadIs): a session started before
that rule may still hand its tracking thread down as its session thread, or carry it on its records:
here that names no session thread, and the session's own is looked for, and opened, as for any
session joined that has none. A session whose own record names the `track` kind (F3.1) keeps its
external side on that tooling thread instead of a session thread; the session still has no session
thread, and the copies of its messages go there.
THE CHANNEL KIND IN USE (F2.3): a session whose external side is its own root-native printback
channel opens no thread -- no root post, no joined line, no Slack call -- and its dispatch names
that channel instead of a thread. The kind is the session's own record's to say
(AgentsToolsCommsPrintbackSessionInUse), never a caller's opinion of it.
THE TOOLING-THREAD KIND (F3.1): a session whose external side is the tooling thread -- the `track` kind
of a root-harness session -- opens no session thread either: no root post, no joined line, no Slack
call for a session thread. The tooling thread its copies go to is the event-track thread the start
post below opens, and the dispatch names it. The kind is the session's own record's to say
(AgentsToolsRootHarnessKindRead), never a caller's opinion of it.
A session joined that hands no thread down: the caller's own, a native client's; one
that started alone; one whose opening post failed. Its thread is the one the first
member brought in opened. Looked for, and opened below where there is none, in one
step under the session's own lock, so two members brought in at once still share one
thread. Its record first (sessions/<session-id>/session.thread, written by the opener
at once), then the spawn records of the members already in the session.
THE PROXY PROCESS IS ITS OWN SHELL, NOT A RUN OF THIS SESSION (S12.15): every send it makes is a
session's own tooling post, so the proxy carries the session's id and thread in its environment for
the sends it makes, and a send into the session's own thread is seen as that session's own, never
copied back as `delivered`. Nested sends inherit them, so the not-yet-seen ones are covered too.
A member brought into a session says so in its thread, as a reply, with what it was
brought in for: every spawn but the one whose own session the thread is. The result
is never assigned to sessionThread. Its text is the note template's
(sh-lib/templates/tooling-note.post.format.md, `# Session`, joined). A session whose
external side is its tooling thread says nothing (F3.1). A session whose external side
is its printback channel has no thread either, and what it says is RECORDED there as a
notice, not posted: the next foreground call of that session surfaces the line (F3.3).
A work-duty's opening start opened its session's thread itself, so it is the opener: it
posts its root and no joined line, as any session's first run does.
The CLI this spawn starts, resolved before the start post that names it, by the
one function the session record and a later resume compare (AgentsReviewCliResolved,
which the console's own --cli-configured arm calls too): the service the caller
named, else the CLI service of the preset its tier names (AgentsToolsPresetSpawnCli,
in the workspace that pays for it). With it,
whether it runs in this package's harness or natively, and the harness tier that
workspace asks for (SPAWN_HARNESS_TIER, which the console passes as --tier).
COWORKING SESSION, which every participant posts into (AgentsTools.EventTrackThread.include).
This spawn's `start` post (sh-lib/templates/event-track.post.format.md) is its own
start entry, posted once, here, when everything it names is settled, and never edited:
the thread's first post where this spawn starts the session, a reply in the session's
thread where it joins. What is learned later is a reply there too
(AgentsToolsSpawnProxyEventTrackLaunched, the feed, AgentsToolsSpawnProxyEventTrackClose). Only when SLACK_CHANNEL_EVENT_TRACK
is set and a bot token resolves -- otherwise skipped silently, and the
spawn is unaffected either way. Nothing reaches this op's stdout: callers
parse it. Holds `<channel>:<ts>`, or is empty. Computed before the
sandbox tracking file below so that file can carry it from the start.
What is the session's -- its id, who started it, its session thread -- is said by the
spawn that starts it, and by no other: one that joins says the session it joined.
A session that is its caller's own has no spawn that starts it: the member whose
start post opens its tracking-thread says what is the session's, and who started it
is the calling session's member, else that session by its id.
ONE THREAD PER COWORKING SESSION, in one record, keyed by the session's id
(AgentsTools.EventTrackThread.include). Where the session has a thread -- this spawn
joins it, a refusal opened it before any start post, or it was started before --
this start post is a reply there. Only where it has none is the thread opened here,
and recorded at once as the session's, so whatever posts next finds it. Reading,
posting and recording are one step under the session's lock, so two spawns starting
in one session at once still share one thread.
The session tracking file, in the ROOT and never in input/ or output/: the root
is granted to nothing, so this is the one record of the spawn the spawned
session cannot reach and therefore cannot forge -- the same reasoning the launch
marker already follows. Its frontmatter IS the state, which is what lets a
rescan rebuild the registry by reading headers rather than bodies. Not team
data: this is the session's own record, so no board rule reaches it and
team-data retention never sweeps it.
Named by the session uuid, not by a fixed filename: a joined sandbox holds
one record per spawn that ran under that tracking name, and a fixed name
would have the second spawn overwrite the first one's record.
A spawn with no routine of its own -- an ad-hoc helper the handling decides to prepare, record and spawn (the Agent
tool's case) -- made from a session whose routine declares `cache-prefix: routine` reuses the parent's routine prefix
and the routine that prefix mixes, so its first round is a cache hit on the parent's prefix. A spawn that carries a
routine of its own keeps that routine's own policy, whatever the parent's. A work-duty is `cache-prefix: armed` now,
so its subtasks start on the bare armed floor.
`session-id` is the coworking session's own shared identifier now,
never this spawn's own -- that is `spawn-id`. A lone, session-starting
spawn has the two equal, the same "uuid is the session name" shape a
solitary spawn already had before the two were split apart.
`execution-receipt` already carries its timestamp inside its value
rather than in a date field of its own. `outcome` is deliberately NOT
used: its values are defined for what an advance pass did to a running
board item, so a spawn's exit result would be an undefined value in a
defined set.
The machine this spawn ran on, because a sandbox tree is synced between
machines and a record found here did not necessarily run here. Without
it, a reader cannot tell a session that ended from one that belongs to
another host, and those two must never read alike. `hostname -s` is the
estate's own machine identity -- the same value a team-member declare's
host glob is matched against.
A one-line pointer file, plain text, for a reader that wants the session thread
and nothing else -- no frontmatter to parse. In the sandbox root, same as the
tracking file above and for the same reason. The event-track thread has no pointer
here: it is the coworking session's, in its one record
(AgentsTools.EventTrackThread.include), and a sandbox may be shared.
The parent session's own list of its children, so the harness a parent runs reads
one file instead of every spawn record there is. One line per child, this record's
path under spawned/, written by one append (atomic at this size); a reader
de-duplicates, and still checks each record, which stays the authority. Kept out
of .local/agents/sessions/: a file landing there reads as that session's activity.
THE VARIABLES OF A WORK-DUTY RUN, LAST IN ITS DISPATCH (F10.7): session id, spawn id, started-at and the scan's
result. Everything above them -- the routine, the member's static guidance and the mechanical brief -- is the same
bytes on every work-duty run of the member, so it caches after the first; the sandbox block before them is this run's
own roots and opens the variable tail.
THE EXECUTOR'S CHECKLIST IS SEEDED HERE, once, before its first turn (S22.4), as pending items of the member this spawn runs, mixed from every source
the spawn has: the steps of the spawner's text under `## Formal task`, the open work of the epic feature that text names (S24.19), the duties of its
routine (never a work-duty's, a loop that no list can finish), then the items its arguments gave. The executor never seeds its own list.
The duties are kept as `step` and everything else as `parent` (S6.27), so a later `replace` knows which items were the replaced routine's.
THE PRESET'S EXTRA SPAWN LINE (F10.1): the one line the human-owner wrote in the preset the spawner chose for this
spawn, put into the dispatch here, as it is crafted, after the standing text and under no heading: no member is told
where it came from. MDAT_SPAWN_PRESET is `<preset>[:<effort>]`, as the spawner set it for this spawn. It is read in
the workspace that pays (MDAT_SPAWN_SETTINGS_WORKSPACE, settled above), and it is not in the sandbox's input/.
Handed over in the brief as `<channel>:<ts>`, same field name as before
the session/agent-log split, so an existing reader of this line keeps
working unchanged. A failed post is one stderr warning above, the spawn
goes on, and the brief says no thread was opened. A session that starts
alone has none by its own rule, and its brief says that instead.
THE CHANNEL KIND IN USE (F2.3, F3.1): a session on its root-native printback channel, or on its
tooling thread, has no session thread, and the dispatch states the kind and the channel it is named
by, so the run knows where its report, its waits and its dismissal travel -- the same section the
Slack kind states its thread in.
Detached whatever started it (backlog :229), close steps and all: its own process
group, HUP ignored, so ending the caller's pass leaves it running, and a hangup sent
to its caller does not reach it. A caller with no session id, a bare console, starts
it exactly as a caller inside a session does: dispatch is the same from anywhere.
The caller's own job control is left as it was found: on only in a shell of its own
that had it on. A subshell carries that flag from the shell it came from, with job
control off, and there it is off again after the start.
Handed off whole: nothing its caller had open stays open here. A caller that runs
this op as a function under a redirect of its own -- a review return did, and so
never came back -- has the stream it redirected saved in its shell, in a descriptor
from 10 up; this subshell stays a shell, so it would keep that open and the
caller's reader would wait for this child's end. Its own three streams are set on
the subshell itself, below. No redirect on this loop: one would be saved in the range
being closed.
THE CONTROL THREAD OF THE SESSION (--intern-session-control) is started here, with
the first member of a session and again by any member that joins while none lives,
by the one function every starter of a thread calls (AgentsToolsSessionControlStart,
AgentsTools.SessionControlStart.include). Here, in the shell that supervises the
run, and not in the call that started it: the folder of the session and the record
of this run exist, so the thread finds something to watch at its first tick, and its
start can neither hold, fail nor delay the spawn, whose call has printed its lines
and returned. A lone run gets one too. A thread that lives is left alone: the
function answers `alive`, which is no error. THIS BRANCH IS NEVER A START ITS CALLER
WAITS ON, which gets none; and a member that joins a session that such a start
opened starts none either (AgentsToolsSessionControlWaited), as no other starter
does. Nor is one started while a start of it is in flight, made a moment ago by the
member that was started just before this one (AgentsToolsSessionControlStarting):
the members of one session are started one after the other, and its thread once.
The thread is the tooling's own process and no run: detached by the function,
nothing of this member in its environment, and nothing on this run's record names
it. A start that fails is one warning in this run's log, and the run goes on.
THE COMMUNICATIONS READER of the workspace (--intern-session-comms, AgentsTools.SessionComms.include) is started beside
the control thread, for a session that has a thread: one for the workspace on the host, so a start while one lives
answers `alive` and is no error, and none where MDAT_COMMS_READER is `off`. It is the tooling's own process and no run,
detached by the function. A start that fails is one warning in this run's log, and the run goes on: a wait reads the
thread itself where the reader is late or not there.
A start is an agent CLI launched, so the receipt waits for it, while the run is alive. A run too
quick for this poll says which in its own exit status, and one that never launches is the error it
is. Nothing else bounds the wait: a console that hangs before a launch holds the answer, as its run
holds its own. The launch marker is the fast path; the status is what settles a race with it.

## sh-lib/session/AgentsTools.SessionStore.include


AgentsTools.SessionStore.include -- where a workspace keeps its sessions and its spawn records: the one answer, so no other part
builds the path. Sourced, never run. A session's folder is `<sessions store>/<session id>`, a spawn's `<spawned store>/<spawn id>`.
The files inside a session's folder are the session subsystem's own; another part asks for what it needs rather than reading them.

Every path here is built by printf -v, never by a command substitution, so a call in a hot path forks no process; each printing
query has an `...Into <variable>` form for a caller that wants the path without a fork.

AgentsSessionStoreDirInto <variable> <workspace>   the sessions store of that workspace, into the variable
AgentsSpawnedStoreDirInto <variable> <workspace>   the spawn records of that workspace, into the variable
AgentsSessionThread <session>       the session's Slack thread `<channel>:<ts>`, as its folder records it, else as its founding
                                     run's record names it (then kept in the folder); nothing where it has none
AgentsSessionThreadSet <session> <channel:ts>   records the session's thread in its folder
AgentsSpawnedThreadOfRecord <spawn record>       the thread the folder of a spawn record keeps; nothing for none
AgentsSessionHasDeathRecord <session>             rc 0 where the session records a death
AgentsSessionRunDead <session> <run>              rc 0 where the session's record of deaths names the run
AgentsSessionDeathSessions                         the sessions with a death recorded, one a line
AgentsSessionDeathLines <session>                  the lines of the session's record of deaths
AgentsSessionMarkerFile <id> <marker>             a run's or a session's lifecycle marker: paused, parked, dismissed, stop.left, control/closed,
                                                   and the root message's marks root.want, root.end, root.pause (...Into)
AgentsSessionMarked <id> <marker>                  rc 0 where that marker is set
AgentsSessionsMarked <marker>                      the sessions with that marker set, one a line
AgentsSessionChangedWithin <minutes> <session>...  rc 0 where a file in one of those sessions' folders changed within that many minutes
AgentsSessionRunOwnRecordInto <var> <run> [ws]     the record a run keeps in its own folder, rc 1 where it has none there
AgentsSpawnedFolderRecords <folder>               the records one folder of the spawned store holds, one a line
AgentsSessionRunClosed <session> <run>             rc 0 where the session's control/closed names the run (`-`: the session itself)
AgentsSessionCloseRun <session> <run> <who> <when> names the run in the session's control/closed, once
AgentsSessionPartInto <var> <ws> <session> <part>   one file of a session's folder, by its part name (`chapter`, `session.thread`)
AgentsSpawnPartInto <var> <ws> <folder> <part>    one file of a spawn's folder, by its part name (`session.thread`)
AgentsSpawnRecordFindInto <var> <ws> <run>        the record of a run, wherever in the store its folder stands; rc 1 for none
AgentsSpawnPartitionFileInto <var> <ws> <parent> <part>  one file an agent-less parent keeps for its starts (`args`, `task`, `scopes`)
AgentsSessionFolderFilesInto <array> <ws> <session> <suffix>   the files of a session's folder whose name ends in that suffix
AgentsSessionStoreTreeIs <path>                   rc 0 where that path lies in a sessions or spawn store
AgentsSessionParentLogInto <var> <ws> <parent>        the launcher's log of an agent-less parent, at the store's root
The session-store values the harness reads and writes, returned as data, so no other part builds
or reads a path into the store: the session log append, the launch word, the live background jobs,
the stored wait's sources line, the held dismissal, and whether a session has a spawn record.
A value that must not fork on a hot path has an `...Into <variable>` form, which the caller reads
without a subshell.
The record of a run into the named variable, as the store's walks hand a record (AgentsToolsSpawnedSessionRecords).
THE RECORD FILE OF A RUN, found the one way: a file named <spawn-id>.spawn.md in whatever folder of spawned/ holds it --
spawned/<run>/ first, else a session's folder (spawned/<session>/<run>.spawn.md). The folder's own name is NOT the id: a
relocated or renamed sandbox keeps its record's name. A file whose own `spawn-id:` names another run is not its record.
Read with the shell's own `read`, so a lookup on a Wait round starts no process. rc 1, the variable empty, where the run
has no record. The record is a handle for a reader of a record (AgentsToolsRunRoute and its kin), never a path to build
on. The workspace is this one (MMDAPP) unless one is named.
Whether a live run sits inside a call waiting on a person, into the named variable: `waiting` when the last line of its milestones is
`wait going idle`, which a Wait writes as it starts, and its wait/state, which a wait writes as it ends, is older than that line or
was never written; or when the last line is `ask going idle`, an ask that writes that as it starts and ends the block with a line of its
own; `working` otherwise, a run with no milestones among them. Working is one thing here: no file of a run's store says a tool call
from thinking. Asked of a live run only. A run of another workspace is a run here has no store, which reads working.
THE SESSIONS AND THEIR RUNS, into the named array, one element a row: the registry's measured rows, as the store measured them. A row
carries its run's id, its session's id, its owner, whether it is live and the state derived for it, and its dates, so a reader joins a
session to its runs on the session field and asks no file again. The registries are rebuilt for this workspace alone; another workspace
is read as it lies. rc 1 where they could not be rebuilt, and the array is then empty.
Writes a spawn record, its whole text on stdin, in one rename, then moves the store's stamp: a reader sees the old record or the new
one, never a part. The record is named by its run, in the run's own folder or the folder given, or by its path in a spawned/ store.
With the text the record must still hold, it is written only where it still holds that text. rc 1 where it was not written, the
record then left as it was. A record named outside a spawned/ store, `<workspace>/.local/agents/spawned/<folder>/<run>.spawn.md`, where
every reader looks and the stamp is, is refused, and the refusal says so on stderr.
The store's facts of the ids read on standard input, one id a line, read by one awk that opens each id's files once:
`<id> TAB <fact> TAB <value>` a row, the rest of the row the value, which may be empty. The facts asked for by name:
  tokens, usage-limit, chapter, model   the first line of that file
  milestone                             the last line of `milestones` that is not empty
  wait                                  what the stored wait's `sources:` line says
  log, transcript                       the file itself, where it is there; the transcript's pointer read first
  mark                                  every marker of dismissed, dismissed.handback, ended and review-expired the store
                                        holds, one row each as `mark:<marker>`, its first line the value
Nothing is printed for a fact the store keeps none of.
The headers of the record of each run read on standard input, one run a line, each record found the one way
(AgentsSessionRunRecordInto) and read once: `<run> TAB <n> TAB <name> TAB <value>` a row, in the record's own order.
A header is a line of the record's first frontmatter block with a `:` past its first character, its value trimmed.
Nothing is printed for a run whose record is not there.

## sh-lib/team-data/AgentsTools.TeamDataCommit.include


AgentsTools.TeamDataCommit.include -- the commit step of every writer into the team-data
store, and the push. Sourced, never run. Functions only.

A writer leaves an entry, and the one team-data thread commits it and pushes
(AgentsToolsTeamDataCommitPaths, AgentsTools.TeamDataThread.include). The gate is a
git directory under $MDAT_DATA_ROOT, independent of TEAM_DATA_GIT_REMOTE. A failed
commit warns on stderr and never fails the write that came before it: the write has
happened, and the dirty-store warning at a spawn close names what is left. The closes,
the main loop and the set-up push through AgentsToolsTeamDataPushIfAhead as before.

With TEAM_DATA_GIT_REMOTE set, the store's step of the set-up and the close push call
myx.common's git/cloneSync for a store that has a remote, as the main loop's pass does,
and a store with no origin, or another one, is given the remote first.

THE STORE'S WRITERS ARE SETTLED BEFORE ANYTHING MOVES ITS TREE (S12.4). The store's checkout is also its writers' working tree, so a
writer's file that waits for its commit is an uncommitted change to that tree. Git refuses to move a tree whose file origin changed
holds such a change, which is how a duty start met LOCK_UNCHECKABLE and a retry a minute later passed. So a caller about to move the
tree settles what waits first. A store with nothing waiting costs one git status and no process.
rc 0 where nothing waited, or everything did and is committed; rc 1 where a writer was still uncommitted at the bound.
With the thread off, as the checks have it, the writers are committed here: there is no thread to ask. A thread's own pass
asks nobody either: it runs the same commit path a request to it would, so every writer keeps the context it left. And a
caller that HOLDS THE STORE LOCK commits here too: the thread takes that same lock for itself, so asking it from inside a
hold is a process waiting on a lock its own caller holds (AgentsTools.TeamDataStoreLock.include).
THE AUDIT LOG FAMILY IS NO TEAM DATA A PULL MAY MOVE (task-20261113T1619Z). A live session appends to audit/<month>/*.log for its whole
run, so a tracked one is dirty whenever any session runs, the set rotates each pass, and every other member's pull is refused over it.
The family leaves the store's index and enters the store's own .gitignore: the files stay, and no pull moves them.
NOTHING IS LOST IN THE CROSSING. A tracked log whose last lines are uncommitted is committed first, so the lines a session appended
exist in the branch before the index stops carrying the file, and a merge that takes origin's copy of it loses no line that was
recorded. A store that tracks no log is left untouched: no commit, and no rule written for a file it never carried.
The store's one lock held for the whole untrack, which writes .gitignore, stages and commits (AgentsTools.TeamDataStoreLock.include).
A PULL MOVES A TREE, AND NEVER OVER A PATH IT DID NOT WRITE (task-20261113T1619Z). Every caller that pulls the store comes through
AgentsToolsTeamDataSyncWithRemote below, so one rule holds at all of them: the writers are settled first, so a path any member's run left
uncommitted is a commit rather than a refusal, and a path origin also moves that is still uncommitted here is carried as this store's own
commit, untracked ones included. A path this store's own rules will not commit is named in one line a caller can act on, and nothing is
moved over it.
The store's one lock held for the whole prepare, which settles the writers, fetches and commits what origin also moved.
ONE PULL OF THE STORE, AND EVERY CALLER'S. myx.common's git/cloneSync does the pull and the push, as before; this adds the three steps
the store needs around them, in the only order that loses nothing. The writers are settled first, so no member's uncommitted path refuses
it. A pull that stopped on a conflict is taken again by the tooling's own merge and settled inside the file (AgentsToolsTeamDataMergeAgain),
as the close push settles one, and the pull runs once more: a store whose two sides both changed one item still comes level. The audit log
family leaves the tracked set only after that: a log both sides appended is merged line by line first, so the crossing loses no line.
Flags go before the three paths, as cloneSync takes them.
The store's one lock held for the whole sync: the prepare, the pull, the settle of a conflict and the audit untrack are one span.
A write into the team data that is to be committed and pushed. The writer runs no git: the paths and what to say of them are left as
one entry file in the thread's folder (AgentsToolsTeamDataThreadDir), and the one thread that commits and pushes (--intern-team-data-commit,
AgentsTools.InternTeamDataCommit.include) is started where none lives and asked to commit. A lock another writer holds can no longer
fail the write, and the thread commits one entry after another. Never fails its caller.
The context is the subject of the commit, `* ` before it unless it starts with `+ `, `- ` or `* `. MDAT_TEAM_DATA_COMMIT_WAIT=yes in front
of the call keeps it until the thread has committed the entry, for a writer that deletes what it has just written: the history of a
file is made before the file goes. With MDAT_TEAM_DATA_COMMIT_THREAD=off the commit is made here, in the caller, as the rigs and the
checks have it.
A COMMIT THAT COULD NOT BE MADE IS OWED, LIKE A PUSH. This system runs unattended: a lock,
a full disk or a concurrent writer must not leave a write that "warned" and never landed. The
paths are recorded here, and the NEXT commit call of any kind picks them up and commits them
with this one, so the store heals itself on the next run instead of waiting for a person to
read a warning. A path is dropped from the debt only once a commit has actually carried it.
A STALE index.lock IS NOT A FAILED WRITE, IT IS A LOCK NOBODY HOLDS. An index upsert that
was killed leaves one behind, and every commit after it fails "Unable to create .git/index.lock"
-- the write lands on disk and NEVER reaches the branch, which is how items sat uncommitted
for days while each tool run reported a warning nobody could act on. So when the add fails
and the lock is there, ask whether a live git holds it: if none does, the lock is stale, it is
removed and the add is tried ONCE more. A live holder is never touched.
A merge the sync left unfinished -- origin and the local commits changed one file -- is settled here, inside the file itself, with no
person and no extra file: a conflict is never committed, no line of either side is lost, and the local commits can go out.
The conflicting blocks of a file (git merge-file, the 3-way merge) are resolved by what the block is:
  - line records, every line of the block starting with a timestamp (logs, registries): the lines of both sides, each once, in time order;
  - the header of a document: a key both sides changed ends with one line, the value of the side whose own last-change stamp is later
    (AgentsToolsTeamDataChangeStamp), origin's where neither has one; a key only one side holds stays;
  - the body of a document: origin's block, then the lines of the local block it does not already hold -- both versions in the one file,
    with no marker.
A file that one side deleted and the other changed keeps the changed one. The merge is then committed. rc 0 where no merge was in
progress or it was settled; rc 1, the merge left as it was and one warning, where it could not be.
THE MERGE TAKEN AGAIN, where the sync gave up on a conflict: cloneSync aborts a merge it cannot settle and leaves no MERGE_HEAD behind,
so origin's branch is merged here by the tooling's own merge, which the settling engine (AgentsToolsTeamDataMergeSettle) can work, and a
merge left with no conflict is committed. One step for every caller that integrates origin: the close push and the checkout repair.
rc 0 where the merge is committed and nothing is open; rc 1 where a conflict stays, the merge aborted and the checkout as before.
The store's one lock held for the whole re-taken merge: the fetch, the merge, the settle and its commit.
Pushes the store's branch when it is ahead of origin, at a close point, never per
write: one push carries everything committed since. A conflict between origin and the local commits is settled and
committed first (AgentsToolsTeamDataMergeSettle), so the commits always go out and none is committed with a marker in it. The primitive is item-upsert's:
push origin HEAD; when the remote moved, integrate with myx.common git/cloneSync
--no-push and push once more; then read origin back and require it to equal HEAD.
Never a reset or a force, and local commits are never discarded: a failure is a
stated warning naming the reason and the ahead count, and the next close retries.
Pushes only when the store is its repository's own root; an origin that is not
TEAM_DATA_GIT_REMOTE is set to it first (AgentsToolsTeamDataRemoteAlign), where before
it returned there and said nothing. Always returns 0.
One process at a time moves the store's branch: every close can call this, async spawn
closes concurrently, and item-upsert pushes from its own process, so the body runs under
the store's one lock (AgentsTools.TeamDataStoreLock.include), keyed to the store's own
git directory. A BUSY LOCK IS A PUSH OWED, NEVER A SKIP: the holder's `git push origin
HEAD` may have resolved HEAD before this process committed, so returning quietly leaves
this process's commits local with nothing recorded to bring them out -- which is how five
commits sat local and unmerged from August to October. So a call that finds the lock busy
records the debt and goes; the NEXT push waits the holder out (a push is bounded) and
carries the debt to the remote, and the debt goes only where the store is verified not
ahead. A debt left unpaid is therefore re-attempted on every later push.
cloneSync's pull needs a reconcile mode when the two sides diverged: a merge,
which keeps both sides' commits and rewrites none. No merge was in progress
above, so one present after a failure is this call's own, and only that is aborted.
cloneSync aborts a merge it cannot settle and leaves no MERGE_HEAD behind, so the conflict is taken again
here, by our own merge of origin's branch, which the settling engine can work. A merge that came in clean is
committed too, so the push below runs on a store with nothing left open.
A store that is a repository of its own and has no origin, or another one than
TEAM_DATA_GIT_REMOTE, is given the remote as its origin, and one line says so. Such a
store was made before the remote was set: myx.common's git/clonePull and git/cloneSync
only `remote set-url origin`, which fails where there is none, and the close push skipped
a store whose origin was another. Its branch, never renamed, is told to follow its
namesake at the origin, which their `git pull` needs. Never a force; a store inside a
larger repository is never touched. rc 0 where the origin is the remote, now or already.
THE STORE'S OWN CONFIG IS THE STORE'S TREE'S: written under the one lock, as every commit and push is, so no process reads a half-written
remote (AgentsTools.TeamDataStoreLock.include). rc 0 where the origin is the remote, now or already.
When TEAM_DATA_GIT_REMOTE is set and no local board exists yet -- the store is
missing or empty -- clones it with myx.common git/clonePull, the main loop's own
primitive, on TEAM_DATA_BRANCH. A store holding content that is not a clone is left
alone and said: adopting it is the main loop's decision, never a writer's. Returns 0.
The store step of --owner-setup-storage --apply. MDAT_DATA_ROOT is an explicit input: the set-up
front resolves it (AgentsContext.UseAgentsTools.include), which also clones a missing or empty store
when a remote is set. With no remote the store is initialised. With a remote set, a store holding
content that is not a clone is handed to myx.common git/cloneSync, as the main loop's pass hands it; a
store that is a repository is given the remote as its origin where it has none or another
(AgentsToolsTeamDataRemoteAlign) and pushed (AgentsToolsTeamDataPushIfAhead, which integrates a remote
that moved with git/cloneSync). The configured author identity is written into the store repository's
own config. The board is made ready by the set-up front after this returns, never here. Non-zero only
on a failure.

## sh-lib/member/AgentsTools.MemberWorkspace.include


AgentsTools.MemberWorkspace.include -- the workspace a team-member operation runs in.
Functions only; sourced at the entry of DistroAgentsTools, before its context is resolved.

...and the input tier derived again now, from the new root, the way the front door
(DistroAgentsTools.fn.sh's tail) derived it for the previous one -- so a reader of
the distro index finds the same tier selected as a direct run in that workspace.
Quiet and non-fatal: a root with no detectable input still switches, and a reader
that needs an index then names the failure itself.
THE THREE WORKSPACES OF A RUN. EXECUTES: the workspace an operation is run from -- its
team data and board, its temp, its sessions and sandboxes, its comms settings. PAYS: the
same one, unless another is named to pay (SPAWN SETTINGS, below) -- the CLI services and
their credentials a member is spawned with. THE MEMBER'S:
the workspace the member is set up in, which it brings two things from, its skillset
folder and its default access, the standing access that is its own there. So no
operation is carried to another workspace as a whole: a member set up only elsewhere on
this machine is invited here, and only its skillset source follows it, and those of its
own settings this workspace holds none of (SETTINGS FALLBACK, below). A client-* member
is invited like any other: which organisation its operation reaches is said by the
operation's prefix and its address (AgentsTools.CommsSlack.include), never by a workspace.
The member's part of one operation: prints `<skillset root><TAB><member's workspace>` for
a member set up only in another workspace on this machine, and nothing for one set up
here, or unknown to the machine's members index, whose operation reads this workspace's
as it always has. rc 1, with one message naming the member, the workspace we run from,
what is missing and where it was looked for, only when the member's part cannot be
brought: its workspace is not on this machine, or its skillset cannot be read. The
invited member works from the member set view of the workspace it is set up in, whole,
so that view must hold the team's own folder (magic-team) too: checked here, once, so no
later reader of the team's files meets a half view and goes on with an empty result.
The view is resolved here, per call, from the member registries' answer for where the
member is set up: a member set root a caller carries is never read for it, so no caller
decides which folder an invited member's skillset is read from.
THE INBOX WRITES READ NO SKILLSET OF THE MEMBER THEY NAME. --upsert-inbox-inquiry names the
member whose inbox it files INTO, and the note and reflection name the writer: each writes into
the team data of the workspace the call runs from, and reads not one file of that member. A
bring here would gate the write on a skillset it never opens, and refuse it for a member set up
in a workspace the caller's own view does not cover. Nothing is brought, and the call runs on.
The intern op is named too: it is the operation these three reach the writer under, at both the
tool file's door and the dispatcher's.
The workspace an invited member is set up in, as a path, for a reader of that member's
own facts there: its mark and alias, which are its row of that workspace's names registry
(AgentsToolsCommsSlackMemberPresentation). Nothing printed, rc 1, for a member that is
not invited. Silent, as AgentsToolsMemberInvited is.
The workspace a member is set up in, from the machine-wide member directory, the
member homes and the workspaces this machine knows, all in $HOME/.agents/magic-team
(AgentsTools.TeamRegistry.include, AgentsTools.MemberHomes.include, LocalTools.Places.include).
Order: the current workspace when the member is there, else the member's home, else the
known workspace where the member is a source link, else the first known workspace that
has it. A member registered only from a workspace without agents (source-declared) runs
where it was asked. Prints the path to switch to, and nothing when no switch is needed:
the member is in the current workspace, is not in the directory (its operation refuses
as it always has), or the current workspace is not in it. Refuses, naming the cause, when
the member is in no known workspace or the chosen workspace is not on this machine.
A workspace known on this machine, by its name: the root, among those this machine knows
(LocalToolsPlacesWorkspaceRoots, from $HOME/.agents/magic-team), whose last segment is
that name; the name of the workspace we run from is that workspace. Prints its path.
rc 1 where the name names none, the reason printed in the path's place: no bare name, no
known workspace of that name, several of them, or a path not on this machine.
SPAWN SETTINGS, the workspace that PAYS. The CLI service a member is spawned on, the
harness tier asked of it and the credentials that CLI is started with are settings of
the magic-team scope, read from the workspace we run from unless another workspace known
on this machine is named to pay: for every spawn here, by SPAWN_SETTINGS_WORKSPACE=<name>
in this workspace's own magic-team scope; for one member, by the same key in that
member's scope here; for one task, by --spawn-settings-workspace <name> on its spawn,
which every way of spawning a task carries to it: the Agent tool (settings_workspace),
--spawn-session, and a review return's restart, which reads it from the record of
the run it replaces. The spawn operation settles the last two
(AgentsToolsSpawnSettingsSettle) and exports the path as MDAT_SPAWN_SETTINGS_WORKSPACE
for that one spawn (AgentsTools.InternOpAgentSpawnProxy.include).
Only these settings move: the board, the team data, the records and the comms stay those
of the workspace we run from, and the workspace named is read itself, never the one it
may name in turn.
Whether a key of the magic-team scope is a spawn setting: the CLI service, the harness
tier, the model of the light or main tier (F10.2), the endpoint a preset names for its service
(HARNESS_ENDPOINT_URL, read of its PRESET_ENDPOINT_URL), the restart threshold a preset names
(PRESET_CONTEXT_MAX_SIZE), the lifetime of the input cache, or a credential a harness leg declares for itself (HARNESS_CREDENTIAL_NAMES, the
names the console exports, which are the vendor CLI's own two as well).
The workspace spawn settings are read from, where it is not the one we run from: the path
the spawn operation exported for its spawn, else the workspace this one's own magic-team
scope names for every spawn. Prints its path, and nothing where this workspace pays for
itself. rc 1, with one message, where the workspace named for every spawn names none.
SETTINGS FALLBACK. A setting is read from the workspace we run from. One exception: a
member's OWN settings of a system, where this workspace holds none of that system for
it, are read from the workspace the member is set up in on this machine. System by
system, and each whole: one setting of a system held here, and that system is read here
alone, what it lacks here too, so no credential is ever put together from two
workspaces. A system is one comms family of the dispatcher (--<system>-*),
and its settings are the keys that begin with its name. Never borrowed: the team's own
settings (the magic-team scope), a key that is no system's, and anything of a member
that is set up here. The tooling says so in one line, where the member is invited
(AgentsToolsMemberSettingsBorrowedSay).
For a line that says a member's own settings are read from the workspace it is set up in:
a client-* member's own settings are the other organisation's, read on the client side
alone (AgentsTools.CommsSide.include), and such a line is said before the side of the
operation is known, so for such a member it says which side reads them. Nothing for any
other member.
The workspace named to pay for one spawn of a member, as a path: the name given for
this one spawn, else the payer the calling session inherited, else the member's own
setting. Nothing printed where none of them names one: the workspace's own naming, if
it has one, then decides. One function for the spawn and for the brief built ahead of
it, so both settle the same payer. rc 1, with one message under the caller's label,
where a name names no workspace this machine knows.
An inherited payer is a path already, settled by the spawn this one is made from:
it holds for every spawn below that one until one of them names its own. Checked as
a name is, because every other rung refuses a payer it cannot resolve: a path that
is no directory would otherwise pay this spawn from the caller's own default.
The line of a write that ends a borrowing. A setting of a system written here for an
invited member, whose settings of that system were read from the workspace it is set up
in until then, makes the system this workspace's: it is read here alone from then on, and
what that workspace holds of it is no longer read. Said once the write is made, on
stderr, by key names only, never a value. Nothing where the write left this workspace
without the system, or where that workspace holds no other setting of it.
Its mirror, the line of a delete that begins a borrowing. The last setting of a system
this workspace held for an invited member is deleted here, and the workspace the member
is set up in holds settings of that system: they are read from there from then on. Said
once the delete is made, on stderr, by key names only, never a value. Nothing where this
workspace still holds a setting of the system, or where that workspace holds none of it.
Where one option is read from when it is not this workspace's own scope, in
agentsConfigOptionElsewhere (a path, or empty: the option is this workspace's): a spawn
setting or a team tier setting, from the workspace that pays; a member's own setting of a
system this workspace holds none of, from the workspace the member is set up in (both above).
rc 1 where the workspace that pays names none.

## sh-lib/questions/AgentsTools.PendingReplyCollect.include


AgentsTools.PendingReplyCollect.include -- collects the answers to AskQuestion
questions nobody is waiting on. Definitions only, sourced by the
--intern-op-pending-reply-collect arm (AgentsTools.InternOpPendingReply.include).

Each open record is read once and never waited on: one --wait-for-input round
with a zero bound, over the question's own thread, since the question -- the same
probe and the same answer rules a live wait uses. A plain question its item's Decisions
already answer is closed from there. A readback, decision or permission is read only by
the main loop's pass over ended and stale records, through the escalation op that reads
and applies every verdict; a session's own collect never reads, closes or grants one.

Pure tooling, run by the tooling itself: no model is called anywhere here.

One line per record examined, first word the outcome:
  ANSWERED <id> <tag> | <question first line> | <answer>   -- closed as received
  UNMATCHED <id> <tag> | <question first line>              -- a reply seen and not taken
  OPEN <id> <tag> | <question first line>                   -- nothing yet
  UNREADABLE <id> <tag> | <why>                             -- nothing is known; stays open
  ALREADY-CLOSED <id> <status>                              -- closed by another closer first
  DROPPED <id> <tag> | <question first line>                -- a held change, at its session's end
then `COLLECT: answered=<n> unmatched=<n> open=<n> unreadable=<n>`.

The sessions not known to have ended, as ` <id> <id> ... `: every session-id with a
spawned-sessions row whose process is running (alive on this host) or remote with an open
record (another host's, not closed, unmeasurable from here) -- the same render
and states the review hand-over reads. And every asker that is itself alive, said by the
one function that says it of an asker (AgentsToolsRegistryAskersLive, by the one rule a
run is recognised by): an ask carries the id of the run that asked, which is a session's
id only for a lone spawn and the founder of a coworking session, so a member that joined
a session and lives is listed by its own id, and one whose run has ended is not, whoever
else of its session lives. A session with no spawn record and a store of its own (a root
session) that asked is listed until that store says it ended (the marker its SessionEnd
hook writes, which that function reads), never by the age of its ask; one with neither
record nor store is listed only while a process runs as it.
A readback, decision or permission is read only for a session that is gone (collectTyped,
set by the main loop's pass): its verdict is read and applied by the escalation op, the one
place that does it, exactly as the asking session's own wait would have.
A plain question with an answer form (select) takes its verdict by the same op, in any
collect: it is a question, read whenever one is.

## sh-lib/grants/AgentsTools.Grants.include

AgentsTools.Grants.include -- the grants: declared, unrolled, and per session.

Three files, each built from the one before, never edited at runtime:
  $MMDAPP/.local/agents/permissions.registry   this workspace's declared grants, one row
      `member:workspace:kind:grant` each, written by --make-agents-indices from project.inf
      (AgentsToolsGrantsRegistryWrite). The rows of the registered workspaces without agents
      are written here too, `.` unrolled to their own root. The machine-wide set is every
      workspace's own file, through the pointers in $HOME/.agents/magic-team.
  $MMDAPP/.local/agents/grants.index   every member's rows, fully unrolled: `*` one row per
      member, the floor, ceilings, unresolved names kept as rows that admit nothing
      (AgentsGrantsIndexBuild.awk). A grant written `approve:Edit(/glob)` is a write BY
      APPROVAL, a read row and an `approve` row: the member reads those files, and its Edit
      or Write of one is neither refused nor applied but HELD, shown to the human-owner and
      applied when he approves (AgentsTools.InternOpChange.include) -- unless a grant given
      for its task, its session or the one call allows it. What the member holds standing,
      or by the floor, never comes ahead of the approval.
      Built by --make-agents-indices; a reader finding it stale or missing rebuilds it
      (AgentsToolsGrantsIndexEnsure).
  $MMDAPP/.local/agents/sessions/<id>/permissions.<member>.index   one session's own:
      the member's rows joined with the session's grants (AgentsGrantsSessionIndex.awk),
      what the harness decides a file tool by, with builtins only: admitted, refused, or
      held for approval. A revoked grant (a
      marker in its store's revoked/) and a session grant whose session has ended are out.
      A session grant given to the member's run on a board item holds for its other runs on
      that item in the same coworking session too, the runs a review return or a resume
      starts under a new id, until the item is closed or that session ends
      (AgentsToolsGrantsItemRuns): a `runs` row of the index, the item and that session
      checked at the call. A task grant given to that run holds for those runs too, while
      the item it names is open: a `task` row like any other. A run started since the index
      was built is found on the way to a refusal (--intern-op-permission-grant-read).

The workspace floor, every member's (section 3 of the plan), in two questions:
  the workspace built for       write .local/temp/**   its own, wherever that folder sits
  a workspace of the machine    write .local/temp/**   from the machine's list alone
    where agents are installed  read source/**/MAGIC.md, source/**/README.md, source/**/docs/**.md
                                read source/**/*.epic.md (S6.41: every member reads an epic)
                                write source/**/MAGIC.md
  the session's own sandbox     read input/, write output/ (per session)
  the run's own review          read the session record of a run it reviews (AgentsToolsGrantsRunSeats)
The temp floor is a property of any workspace an index is built for, so a rig or a run
sandbox carries it too. The source rows are a property of a workspace of the machine, and
the list drops every root holding /.local/agents/spawned/ or /.local/agents/scratch/
(LocalToolsPlacesWorkspaceRoots): neither reaches a source of its own.
and, as before, the readable member directories and the reference read roots. All of
source/** is no floor's: magic-librarian holds a standing read of it, every other member
the namespace grants declared for it. The members this package carries hold their standing
grants as `magic-team:` directives of its project.inf (AgentsToolsGrantsDeclaredText).
magic-librarian's other one is a standing write by approval of the .md files of the team
members' skills this machine holds, where they are its to change
(AgentsToolsGrantsMemberSkills): it is never asked for the access, and each change of one
waits for the human-owner's approval.

Dot-sourced; functions only.

Whether the index is current, by builtins only: its header is this run's, and it is newer
than everything it is made from -- every workspace's grants and places this machine
points at, the member registries and index, the member set root, the machine's skills
folder in HOME, and this code.
The team members' skills that are the machine's own and this workspace's to change, one
resolved folder per line, each once: the entries of the machine's skillset in HOME, a
built-in place (LocalToolsPlacesHomeSkills), that hold a member's own <name>.basic.md and
are no reference-only identity record, which is nobody's to write. A real folder there is
a skill that lives on this machine only. A link there counts where its target really lies
under this workspace's source/; one to anywhere else, another workspace's source tree or a
folder here that is itself a link out, never does. Resolved here, by the index builder,
once: a call is checked against the rows this gives, on its real file, whatever link it
came by.
The standing write of magic-librarian on the team members' skills this machine holds
(AgentsToolsGrantsMemberSkills): their .md files, and nothing else in them, BY APPROVAL
(`approve:`): each change is held for the human-owner and applied when he approves. Rows
of this workspace's own index only, never of a registry, which every workspace reads.
Their kind is `skillset`, and they come before every other grant: a call on such a file
is decided by its row here, whatever else would admit it too (AgentsToolsGrantsCheckSkillset).
Rebuilds the index the way the sibling myx.distro-* indices are rebuilt
(IndexCacheMissDistro.include): the generator in a tested subshell into a temp file
beside it, then mv -f. The temp is this write's own, by mktemp and never by $$, with
its mode set on it (AgentsToolsRegistryWrite, AgentsTools.Registries.include). On a
failure the old index stays, rc 1.
One slice per member, the `*` rows then that member's own, in the index's own row order:
the rows AgentsToolsGrantsCommonCheckRows keeps. Two awk passes over the index -- the
first collects the member names, the second writes the rows -- never a bash loop. The
new folder is swapped into place before the index is renamed, so a slice is never newer
than its index.
Whether a grant of one tool speaks for a call of another: the same tool, or a grant to Edit
or Write a path, which reads what it may change -- Read, Grep and Glob, in the same scope and
for as long as that grant holds. Never the other way: a grant to read changes nothing. THE
ONE PLACE this is decided, for every session, task, planned and routine grant a call is
checked against. An Allow once is one call of its own tool, and a standing write row is
every file tool already.
THE TESTING DIRECTIVE, `magic-team:testing:<project-glob>:<sh-test-path>:<host-glob>` in the Declares of a
project, and its one reader. It names the sh-test folders of the projects of the declaring workspace whose
name (the last segment of the id) the glob matches, and it is read for two ends alike: magic-tester's write over
them (AgentsToolsGrantsDeclaredText) and the folders eligible for the testing system (AgentsToolsTestingFolders).
The host glob is the last field and works as a place directive's does, so a path keeps its own colons. A line for
another host gives nothing; a malformed line, and a path that leaves its project, are skipped with a warning; a
glob no project matches gives no row.
The rows of the projects selected (their ids, one a line): `<project id><TAB><sh-test-path>`. rc of the declares
read where it failed.
One declaring workspace's grants, read off its project.inf as it stands, and the floor
directives of the packages installed under its .local/myx, on stdout:
  row <TAB> member:workspace:kind:grant      for the permissions registry
  tag <TAB> member:workspace:tag:root        for the provenance tags
The selectors, `<scope>:<selector>:<verb>:<member>[:<glob>]`:
  namespace:<ns|.|*>     that namespace's source in every tooling workspace, `.` the
                         declaring project's, `*` every namespace the declaring one selects
  workspace:<name|.|*>   a workspace place, `.` the declaring workspace, `*` every one;
                         a pattern (`*-testbed`) every workspace place whose name matches
  directory:<name>       a registered place of any kind, capped at its ceiling
  project:<selector>     the estate's project resolver, in the declaring workspace
The testing directive (AgentsToolsTestingDirectiveRows) is the permissions one for
magic-tester alone: its write over the sh-test path it names, a `project` row.
A name no place carries becomes an `unresolved` row, with a warning; a pattern no place
matches gives no row and no warning. Reads the places from
agentsGrantsPlaces and the tooling workspaces from agentsGrantsRoots.
rc 0 trusted; 2 not trusted, said on stderr, and no row may be dropped on its strength;
3 no project selected there, said as a note, the same.
`<verb>:<member>[:<glob>]`, cut on the first colon each time so a glob keeps its own.
allow-write and allow-read are one path grant, Edit(...) or Read(...); allow-tool a
member's standing tool permission, its glob being <tool>[:<target>]. Any other verb is
refused, never read as an allow.
`.` the declaring workspace, `*` every tooling workspace, a name a
workspace place, a pattern every workspace place whose name matches.
Tagged for the copilot access fragment: own (the declaring workspace),
explicit (named), wildcard (only swept by `*` or a pattern).
--make-agents-indices's grants step: this workspace's permissions registry and its tags,
rewritten whole, from what this workspace declares and what every registered tooling
workspace without agents declares (`.` there is that workspace). Plus the member rows --
each acting member of this workspace writes its own directory -- magic-librarian's standing
read of this workspace's source. A scan that is not trusted keeps the registry as
it stood (rc 0, said); another workspace's that is not keeps that workspace's rows.
Then the pointer in $HOME/.agents/magic-team. rc 1 on a failure to write.
The run seats of one run (S6.41): the session store of every run it reviews, one absolute
path a line. A run reviews the runs it spawned, and the runs of the peers its own dispatch
item cites in `references:` -- a dispatch names the peer it sends its run to review. Each
seat is that run's whole session record: its session chat, its log and its results, and the
output/ folder its sandbox kept. So a reviewer reads what it was sent to review with no ask.
rc 1, nothing printed, when the session has no record of its own or works no dispatch item.
Whether a session has ended, by builtins only: its spawn record
(spawned/*/<id>.spawn.md) closed with a spawn-* status other than spawn-started. A session with
no spawn record (a root session: the human-owner's own, an interactive native console) ends
by its client's SessionEnd hook instead (client-hooks/root-session-end.sh): an `ended`
marker in its own store, which a resume removes. rc 0 ended, 1 not.
It takes the session id and builds the store's folder itself: no caller builds a path into the session store.
A session grant is given to one run, and a review return or a resume starts that run again
under a new id. So it holds for every run of the same member on the same board item in the
same coworking session, until the item is closed or that session ends, and never for another
member, another item or another session. What one run shares that way, read off the spawn
records with one awk (AgentsGrantsItemRuns.awk): agentsGrantsItemRunsItem, the item it works;
agentsGrantsItemRunsSession, the store of the coworking session whose end ends it, empty
where one of these runs started that session, which then lasts while the item is open; and
agentsGrantsItemRunsStores, the stores of the member's other runs there, one directory per
line. rc 1, with all three empty, when the run has no record, is another member's, works no
item, or is the only one.
A task grant given to one run is read from those same stores, and lives as ever while the
item it names is open, whatever became of that session.
The lines AgentsGrantsSessionIndex.awk reads those stores by (ENVIRON
agentsGrantsItemRuns), from what AgentsToolsGrantsItemRuns set: one `<store><TAB><item><TAB>
<coworking session store, or -><TAB><only, task, or empty>` line each, `only` for a store that
is none of the session's own, listed one per line in the first argument. With `task` as the
second, what those runs share for the session has ended: such a store is marked `task`, to be
read for its task grants alone, and a store of the session's own gets no line.
The session index on stdout, with one awk, from the current grants index, and for a session
with a spawn record one more over the spawn records first: the stores of the member's other
runs on the same board item are joined too, for the session and task grants those runs share
(AgentsToolsGrantsItemRuns). The header, the sandbox folders, the origin and the stores go
to the awk in the environment: they are text, and -v decodes a backslash in a value and
takes no newline in every awk. The sandbox folders come resolved; this origin's skillset is
resolved here, at the rebuild only.
The two files of a check, by name. A file that exists is used as it is: its writers keep it
current, so nothing here tests whether it is. A missing one is written once: the grants
index by its builder, the session file by AgentsToolsGrantsSessionWrite. Where that cannot
be written, or there is no session, the session rows are held in agentsGrantsSessionText.
rc 1 where there is no grants index to read.
One file-tool call decided by the session index rows on stdin, by builtins only. The
ceiling first: a write tool in a read-only place is refused, rc 3, agentsGrantsCheckPlace
its name. Then the rows in order: rc 0 admitted, agentsGrantsCheckLayer saying by what; for
a floor or standing row agentsGrantsCheckFrom its origin in the grants index, `floor` or
<workspace>:<kind>; for an Allow once agentsGrantsCheckOnce its refusal id, for its caller
to use up. A once row's expiry, its use, a task row's open item, a session row's end, and a
runs row's open item and coworking session are checked only on the row that matches; the
expiry with one `date`. A session, runs or task row of Edit or Write admits a read of its
path too (AgentsToolsGrantsToolCovers). rc 1 when no row admits the call.
An approve row stands ahead of the allow rows. A call one covers is admitted by no floor or
standing row after it: only by a session, runs, task or once row, a grant given for that
work. With none, rc 4: held for approval, agentsGrantsCheckLayer `approve <standing>` and
agentsGrantsCheckFrom the origin of that row, for its caller to keep the change and show
it, never to apply it (AgentsHarnessFileGate, AgentsUniversalHarness.sh).
One file-tool call decided by the grants index on stdin, by builtins only: the ceiling, then
the member's standing rows. rc 3 refused by a read-only ceiling, rc 0 admitted, rc 1 not
admitted here. An approve row covering the call stands over every allow, and is left in
agentsGrantsCommonApprove for the session rows, which alone may admit such a call.
--intern-op-permission-list's rows (AgentsGrantsSessionIndex.awk, mode list): the member's
floor and standing rows of the grants index, then its live grants in every session store,
or in one session's own, coworking and parent stores. Each store's end and used-up once
grants are read here, for the awk. So are the session grants that hold for the member's
other runs on the same board item, while they are live (AgentsToolsGrantsItemRuns): with a
session, those of its other runs, and those runs' task grants, live or not; with none, those
of every ended run of the member.

## sh-lib/member/AgentsTools.MemberWorkspace.Settings.include


AgentsTools.MemberWorkspace.Settings.include -- the settings a spawn reads from the workspace a member is set up in, and the record of
what was read: split from AgentsTools.MemberWorkspace.include, because the member-first paths bring a member and never settle a spawn's
settings, and this half is parsed only by the spawns that do.

Whether a key of the magic-team scope is a spawn setting: the CLI service, the harness
tier, the model of the light or main tier (F10.2), the endpoint a preset names for its service
(HARNESS_ENDPOINT_URL, read of its PRESET_ENDPOINT_URL), the restart threshold a preset names
(PRESET_CONTEXT_MAX_SIZE), the lifetime of the input cache, or a credential a harness leg declares for itself (HARNESS_CREDENTIAL_NAMES, the
names the console exports, which are the vendor CLI's own two as well).
The workspace spawn settings are read from, where it is not the one we run from: the path
the spawn operation exported for its spawn, else the workspace this one's own magic-team
scope names for every spawn. Prints its path, and nothing where this workspace pays for
itself. rc 1, with one message, where the workspace named for every spawn names none.
The workspace spawn settings are read from, where it is not the one we run from: the path
the spawn operation exported for its spawn, else the workspace this one's own magic-team
scope names for every spawn. Prints its path, and nothing where this workspace pays for
itself. rc 1, with one message, where the workspace named for every spawn names none.
SETTINGS FALLBACK. A setting is read from the workspace we run from. One exception: a
member's OWN settings of a system, where this workspace holds none of that system for
it, are read from the workspace the member is set up in on this machine. System by
system, and each whole: one setting of a system held here, and that system is read here
alone, what it lacks here too, so no credential is ever put together from two
workspaces. A system is one comms family of the dispatcher (--<system>-*),
and its settings are the keys that begin with its name. Never borrowed: the team's own
settings (the magic-team scope), a key that is no system's, and anything of a member
that is set up here. The tooling says so in one line, where the member is invited
(AgentsToolsMemberSettingsBorrowedSay).
For a line that says a member's own settings are read from the workspace it is set up in:
a client-* member's own settings are the other organisation's, read on the client side
alone (AgentsTools.CommsSide.include), and such a line is said before the side of the
operation is known, so for such a member it says which side reads them. Nothing for any
other member.
For a line that says a member's own settings are read from the workspace it is set up in:
a client-* member's own settings are the other organisation's, read on the client side
alone (AgentsTools.CommsSide.include), and such a line is said before the side of the
operation is known, so for such a member it says which side reads them. Nothing for any
other member.
The workspace named to pay for one spawn of a member, as a path: the name given for
this one spawn, else the payer the calling session inherited, else the member's own
setting. Nothing printed where none of them names one: the workspace's own naming, if
it has one, then decides. One function for the spawn and for the brief built ahead of
it, so both settle the same payer. rc 1, with one message under the caller's label,
where a name names no workspace this machine knows.
The workspace named to pay for one spawn of a member, as a path: the name given for
this one spawn, else the payer the calling session inherited, else the member's own
setting. Nothing printed where none of them names one: the workspace's own naming, if
it has one, then decides. One function for the spawn and for the brief built ahead of
it, so both settle the same payer. rc 1, with one message under the caller's label,
where a name names no workspace this machine knows.
An inherited payer is a path already, settled by the spawn this one is made from:
it holds for every spawn below that one until one of them names its own. Checked as
a name is, because every other rung refuses a payer it cannot resolve: a path that
is no directory would otherwise pay this spawn from the caller's own default.
The line of a write that ends a borrowing. A setting of a system written here for an
invited member, whose settings of that system were read from the workspace it is set up
in until then, makes the system this workspace's: it is read here alone from then on, and
what that workspace holds of it is no longer read. Said once the write is made, on
stderr, by key names only, never a value. Nothing where the write left this workspace
without the system, or where that workspace holds no other setting of it.
The line of a write that ends a borrowing. A setting of a system written here for an
invited member, whose settings of that system were read from the workspace it is set up
in until then, makes the system this workspace's: it is read here alone from then on, and
what that workspace holds of it is no longer read. Said once the write is made, on
stderr, by key names only, never a value. Nothing where the write left this workspace
without the system, or where that workspace holds no other setting of it.
Its mirror, the line of a delete that begins a borrowing. The last setting of a system
this workspace held for an invited member is deleted here, and the workspace the member
is set up in holds settings of that system: they are read from there from then on. Said
once the delete is made, on stderr, by key names only, never a value. Nothing where this
workspace still holds a setting of the system, or where that workspace holds none of it.
Its mirror, the line of a delete that begins a borrowing. The last setting of a system
this workspace held for an invited member is deleted here, and the workspace the member
is set up in holds settings of that system: they are read from there from then on. Said
once the delete is made, on stderr, by key names only, never a value. Nothing where this
workspace still holds a setting of the system, or where that workspace holds none of it.
Where one option is read from when it is not this workspace's own scope, in
agentsConfigOptionElsewhere (a path, or empty: the option is this workspace's): a spawn
setting or a team tier setting, from the workspace that pays; a member's own setting of a
system this workspace holds none of, from the workspace the member is set up in (both above).
rc 1 where the workspace that pays names none.

## sh-lib/slack/AgentsTools.InternOpCommsSlackSend.include


AgentsTools.InternOpCommsSlackSend.include -- --slack-send-message, with the mention and presentation helpers only it uses.
Sourced lazily from AgentsTools.MemberCommsSlack.include by its own arm, and only by it; relies on being
dot-sourced for $1/$@/$MDSC_CMD. Rationale and mechanism: myx.distro-agents/MAGIC.md.

No target named: the session's own channel, by the kind it recorded (F3.2). One rule for every
entry point that reaches this operation, harness and MCP twin alike: `full` the session thread,
`track` the tooling thread, `none` the root-native printback channel -- and, for a session with
no kind recorded, the session thread where one is on record, else F2.3's printback mark
(AgentsToolsCommsPrintbackSessionOwnTarget). An ad-hoc/solo spawn holding no channel of its own
keeps today's explicit-target requirement exactly -- the error just below fires as it always has.
The session's own channel is our own organisation's, so it is no default on the client side.
THE ROOT-NATIVE PRINTBACK KIND (F2.2): `printback:<session>` is a channel-id of the printback
service (AgentsTools.CommsPrintback.include), never a Slack address. Its message is printed to
this operation's output -- that output is its external copy -- and recorded in that session's
one chat file; no Slack setting or identity is read, no Slack call is made and no thread is
opened. Taken here, ahead of every Slack grammar, so nothing of Slack stands behind it.
EVERY MEMBER POSTS IN ITS SESSION'S THREAD, NEVER AT THE ROOT OF THE TEAM CHANNEL (his design: the team channel is open, and a
report, findings or handback is internal): a magic-team target from any member, in any session, is delivered to its own session thread, else its
parent session's thread, else the coordinator's duty-session thread, else the human-owner's conversation with the bot, addressed to magic-coordinator unless it names someone.
Only a step told to post in the channel passes: --told in argv, or a work-duty's day-first greeting (its record carries
`day-first: yes`, and its first post to magic-team this month is that greeting).
THE ROOT-NATIVE PRINTBACK KIND THROUGH A SESSION ADDRESS (F2.3): where a session's
external side is its printback channel, session-current and session-parent resolve to
`printback:<session>` and the message goes by that driver, exactly as one naming the
channel-id itself does (above): no Slack grammar, setting, identity or call stands
behind it. The send's own arguments are the driver's to read.
A PERSON OUTSIDE THE TEAM IS ANSWERED IN THEIR OWN THREAD (the contact rule; 2026-11-10 09:31, three replies to two people went to the wrong
person, under a name read nowhere, with an internal cause and promises): a direct conversation that is not the human-owner's takes a message
only as the answer to one of that person's messages, the thread named and its author no account of ours. A post at the top of their
conversation, or under our own post, is refused: it is how one person's note was answered to another. client-* members, whose role
is that conversation, are exempt. Checked here, before any body, token or identity work: a refused send reads nothing else.
The other party is read from the conversation itself (conversations.info, the one counterparty reader), never from the
addressee the caller names. The human-owner's own conversation and a team account's pass; a person is also a known contact,
asked of the contact store with no team filter, since the store keys a Slack id by its workspace and the acting member is none.
A PERSON OUTSIDE THE TEAM IS ANSWERED IN THE THREAD OF THEIR OWN MESSAGE, AND ONLY A KNOWN PERSON IS WRITTEN TO (the team
rules, Channels and threads): a top-level send into their conversation goes into the thread of the newest message they
asked this member in, the one the Wait handed it (schedule/owed/<member>); with nothing asked, it opens a new subject as
named. The contact store must know the person, else the send is refused (AgentsToolsContactAssertKnown, the one gate).
The human-owner's conversation and a team account's are not this case.
Slack's own chat.postMessage `metadata` object. Every send carries
one identifying its own acting member, read back by
AgentsSlackMessagesFormat.awk's `[sender: X]` annotation -- this is
what tells one member's post from another's under the one shared
bot account. An explicit --metadata below replaces it outright;
bareness of $memberName is already asserted above, so it never
needs JSON-escaping here.
What the tooling sends itself is marked `tracking: tooling` (a member's own send, MDAT_SEND_FLOOR=hold, set by its stub, is not): the readers that
decide whether something is input leave a tooling post that is not addressed to the reader out (AgentsTools.TrackingDrop.include).
THE ORIGIN OF THE POST (epic S6, "a post outside its own session thread states its origin routine and its real sender
member"): the routine of the run that sends, read once from its own spawn record, short (`work-duty`,
`supervision-session`); `console` for a send from no run. Three coordinator runs, a duty, a supervision and a console,
post under one name and one alias, and the owner could not tell which spoke. The origin travels in the metadata here
and in the author line below, as `@alias/origin`, a form `memberSendHeaderLength` accepts (`@[^ ]+`) and the mention
converter skips (a slash is outside a member name).
The sender a message carries is its acting member, whatever metadata the send is
given: a reader tells whose answer a post is by it (AgentsSlackThreadAnswers.awk).
No backslash escape is taken, so a key cannot be written another way, and every
`sender` in it names the acting member.
HIS CONVERSATION IS THE BOT'S, NEVER A PERSONA'S: a post under a member's user identity to his account, or into a direct
conversation whose other party is he, is refused; the same message under --identity-bot reaches his conversation with the team bot.
The send takes the bot itself, so no caller has to know: the line below says what was done. A REPLY IS NOT THIS CASE: a reply goes
into the thread of the message it answers (the team rule), under the identity that is in that conversation, so a send naming a
thread keeps its identity; switching it would leave the thread unreachable and the answer at the top of another conversation.
TO THE HUMAN-OWNER the rule is the same as to anyone: a member with a Slack account of its
own posts under it, and a member with none posts as the team bot, in the bot's own
conversation with the owner, as its question to the owner does (AgentsHarnessAsk).
Nothing is relayed under another member's account.
A client presents under the names of its own team-members-names row in a workspace that is not ours:
its own user token posts there, and so does its own bot token, and both are
read on the client side only. The shared bot token is our workspace, which
keeps the internal identifier.
Decided here, before the header is built; the bot token is resolved once
and carried to the send below.
The member's own row, and nothing else: the build gives every client the persona's values.
An invited client, set up only in another workspace, has its row in that workspace's
registry, since this one holds this workspace's own members; where it has none there
either, its row is the persona member's own, which is what the build would have given
it (AgentsTools.Registries.include).
In-body "@name" mentions, through the same resolver and the same
per-lock-cycle cache the header's addressee field uses. Only names
this body carries are resolved; one absent from the map stays
literal text, and never fails the send.
The same "@"-to-next-space run the converter itself
takes: a shorter one keys the map on a name it never
looks up. Code spans and fences are excluded by the
converter itself, so an over-wide scan converts nothing.
The one-line header: [<from> ]→ <to>. <body>. Slack collapses a
caller's text to one line whenever blocks travel with it, so a
header that is already one line reads the same in both versions.
Both its markers are ASCII and store literally, so a reader parses
the header out of the flattened text without matching a shortcode.
Nothing named, and the conversation is a DM or a group DM: its own
participants are the addressees, minus the sender. Keyed on the
conversation's type, never on who the counterpart is.

THE TYPE COMES FROM SLACK, NOT FROM THE ID. Only the `U…` shortcut
below is sound -- that target IS the party, so it can never be
anything else. Every other prefix is an assumption Slack does not
honour: a modern mpim is issued a `C…` id, so the arm that used to
read `C…` as "a channel, never a DM" and skip the lookup made the
mpim branch UNREACHABLE -- measured live on two real mpims, both
`C…`, both rendering "@here". `conversations.info` is asked instead
and its own `is_im`/`is_mpim` answer routes the rest.

The cost is one `conversations.info` per send that names no
addressee, a real channel included -- there is no cheaper test that
is also correct, because the id prefix is precisely the thing that
turned out not to carry the type. Worth paying: the fallback it
replaces is "@here", which in an mpim pings every participant in a
live client conversation on behalf of a message addressed to nobody.
That is the harm this lookup buys off, not merely a vaguer header.
A lookup that answers nothing still leaves "@here" rather than
failing a send over a header field.
Whether the addressees are ids the send read itself, below, and not words of its caller.
The reply goes to its author, set here from what it answers: the caller's addressees do not replace it. A person who is not the
human-owner is written to only as a known contact (AgentsToolsContactAssertKnown, the one gate), in a channel as in a direct
conversation; an unknown author is refused with the escalation the gate writes.
A post whose caller names someone is never re-addressed to the human-owner: he is tagged only by a message for him.
The sender is not addressed to itself, in ANY conversation type.
Compared against the account this send actually posts under --
auth.test on the identity the send itself uses, the same identity
selection the two calls above make -- never the member's roster
id, which is a different account whenever the posting one is not
the member's own: under --identity bot, and for a member holding
no user token at all, which falls back to the bot with no flag
involved and whose roster id reads back empty, so the old test
matched nobody and the sender addressed itself. In a one-to-one
DM the counterpart is the other party by construction and this is
a no-op, which is why it is written once for every shape rather
than once per shape.
A DIRECT MESSAGE HAS ONE OTHER PARTY (a reply to one person went out headed for another): in a
one-to-one conversation an account the caller names as the addressee is re-addressed to that other party, and the send says whose
conversation it is. A word that is no account (a team member's name) is not judged here. In the human-owner's conversation nobody is
re-addressed to him: he is tagged only by a message for him.
Every addressee that resolved to a real Slack account, which is the value a
wait qualifies an answer against. A roster alias with no account of its own
adds nothing here: it can be addressed, and it cannot be recognised as an
author, so a caller is told the list is empty rather than given a name that
would never match.
What the word is. An account or a conversation only by the whole shape of a Slack
id: upper-case letters and digits and nothing else, nine characters or more, as
the one address resolver holds a bare id (DistroAgentsToolsResolveTarget), a U
first for an account and a C, D or G for a conversation. Never by its first letters
alone: a word that only began like an id reached the header and the blocks as it
was given. An id the send read itself, the other party of a direct message, keeps
the length it came with, and is held to the letters and digits all the same.
AN ID A CALLER NAMES IS ONE THE TOOLING HOLDS: a run tags a person only where it read that
account, so the same gate a reply's author and a member's name pass is asked of it here. The
conversation this send resolved to, and an id it inferred, are its own reads and are not
asked. An `<@U...>` the caller only quotes, in the body, is never looked up at all.
The handle half of the field, in the two forms the same
field takes. Where the member has a Slack account, both
are that account and Slack renders its real handle; where
it has none, both stay the roster alias as plain text.
A client is the exception: its only Slack account is in
another workspace, where a foreign id renders wrongly, so
it keeps the plain alias; the one id used is the sender's
own in an external send, the account it posts as. In an
external send a client addressee reads under the names of
its own row, or of the sender's external presentation when
its row lacks one, and never under its identifier.
No named addressee: the message is for whoever the conversation holds -- EXCEPT IN A
THREAD. A thread reply already reaches the people in that thread and nobody else, so an
"@here" there is at best noise and at worst a channel-wide ping from a message that was
only ever meant for a handful: on 2026-10-27 ninety-seven thread replies carried
"→ @here" into a client's channel because this default applied to them. A reply says who
it is for in its own words, or names them, and gets no default addressee.
@HERE ONLY WHERE THE CALLER MEANT IT (--address-to @here). A reply is addressed to the author of the message it answers (above).
A bare message naming nobody heads itself to "this conversation" in plain text, which pings nobody.
The newline is deliberate: Slack flattens it to one space, which is
exactly the ". " seam, and where no blocks travel and nothing
flattens, the body still starts on its own line.
A BARE ACCOUNT ID IN A BODY IS SAID AS A PERSON (his complaint, 2026-11-10 11:45: "from U04RSR5LKPV", whom nobody could place):
an account id written plain, not inside a mention, becomes what the contact store says of it, "<name>, <organisation>", or
"an account with no record"; never a mention, which would ping an outside person, and never the bare id. A default, not a refusal.
The sender goes INTO the header just built, never above it as a
second line -- blocksJson starts with headerOpen by construction,
so stripping that prefix is what opens the slot. Always shown, no
exception for a member's own "user" identity: a coworking-session
reviewer must not have to know which member happens to hold a
real Slack account. The identity swap below changes the token
alone and sends this same payload again.
Outbound-to-unlisted-people gate: scoped to a send actually
presenting into an external/client workspace ($presentExternal,
set above) -- every internal team conversation (magic-team,
event-track, a member's own DM, the human-owner's own channel)
never sets it, so this never touches the team's own traffic.
The team's plain-language floor, on the body exactly as the caller gave
it -- nothing has altered sourceText since it was read. It sits after
the token because the shared-identity rule needs the account this posts
under, which nothing earlier knows. A blocks payload is JSON, not prose.
A member's own message (MDAT_SEND_FLOOR=hold, set by the member stub) is held back
when it is over a limit: not sent, and returned as a CORRECTION for its sender to
make and send again, rc 6, with no limit on attempts and no way through on a later
one. The limits it is held on are those of the edit and the email; sentence-cap
stays an instrument everywhere -- see MAGIC.md. A send of the tooling's own is
measured and reported only, as the spawn brief is: nobody can rewrite it.
Only the sender's own words are measured. A tool that builds the message around
them names them in MDAT_SEND_PROSE_FILE, and they are measured in place of the
whole body, whose other lines are the tool's.
Held back the same way, and first: a member's own message that carries the retired
marker of a question, `NEEDS REPLY`. A question is asked with a tool that asks,
alone in its own message (AgentsToolsOutputStyleRetiredMarker). Only the marker is
looked for, and a send of the tooling's own is not looked at.
A RELAY THAT SAYS A FILE WAS APPLIED NAMES ITS TREE AND READS IT BACK (task-20261117T2241Z): a send declaring the
relay group that says applied, landed or fixed carries the file's absolute path and its read-back, else it is refused
here. A declared relay is the only carrier looked at, so ordinary status talk is untouched. It stands outside the
prose-only block above, because a blocks payload carries the same claim.
A REPEATED MESSAGE IS A LOOP, NOT A CORRECTION (his ruling): the same body to the same place within the half hour is refused unless
--again says the repeat is meant. It is judged after the floor, so a body the floor holds back comes back as its CORRECTION, never as
a repeat; and on the whole body, not its first line, so two asks under one caption are two messages. The last fifty sends of the
run are kept by the session store (AgentsSessionSentRecentAdd) as `<epoch>\t<place>\t<cksum of the body>`.
One line per send outcome in a durable local log, as console.log is for a
console: a session that did not send can still read what happened. Outside
the team-data store, so a send adds no commit. Target, identity and outcome
only -- never the body, never a token, never Slack's raw response.
Rolled over monthly, like audit/: comms-slack-send.YYYY-MM.log, the UTC
month of the line's own time. Columns: time, member, target, channel,
identity, ok|failed, reason, session id (last, so positional readers of
the first seven keep working; '-' when no session is known). The session
is resolved by the same rule as AgentsHarnessSessionKey.
A message recorded before its post (F9.1) whose post failed stays in the chat file. A `retry` goes into
the cache outbox of its channel (S21.13, AgentsTools.CommsCache.include): one queue per channel, pushed
by the communications reader, posting the very payload that failed. `unknown` where it may have been
reached (never posted again), `refused` where Slack answered and said no (never posted again), stay
verdict records of the session. Quiet, and the send fails as it did.
THE BLOCK IS THE SESSION'S FROM NOW, WHETHER SLACK ANSWERS OR NOT: its conversation is the thread already, its ts is set by the
writer when it has posted. A reader's floor passes a block with a conversation, so a slow or failing Slack holds nothing back and
the order of the file is the order everyone reads (AgentsSessionChatRead.awk). The copies of it in another session's file keep
their rows for the writer, which sets the same ts on them.
WHAT WAS POSTED, AND TO WHOM, as named fields a caller reads rather than a
response body it has to parse. The pair this feeds is a question and its
answer: the answer arrives in the thread of THIS message, after THIS ts,
from the party named here -- so all three are reported by the side that
already resolved them, and the wait reads the same values instead of
resolving them a second time and possibly differently.

On stderr, beside the other diagnostic fields this operation family emits:
stdout stays the response body byte for byte, which is what every existing
caller already reads.
THE ARRIVAL IS WRITTEN WHERE THE WAIT WATCHES IT (AgentsTools.WakeMarker.include): a message to a member
wakes that member's waiting session in about a second, on a source it reads out of a file, instead of it
waiting for the wait's next look at the costly Slack source. A post into a thread, addressed to a member
there, wakes it the same way: `address_to` names who it is for, exactly as a DM does. An edit is no
arrival, and a post naming no member at all has none to wake. Quiet and best effort: the message is
posted, and the marker only shortens the wait for it.

## sh-lib/wait/AgentsTools.MemberWait.include

a process or an ask, which no writer pokes. The chat file and the wake marker end the nap at once, so only a writer that does not poke waits this long.
The inbox is among them: an item standing in incoming/ when a wait begins is input not yet handled, so it arrives at once rather
than being taken as the baseline of a fresh wait (a member busy while four items came found nothing on its idle wait).
participants' reports waits on the floor too. The list is found as --idle-wait finds it, and its recurring
wait-for-more item is no open work, by the same words.

## sh-lib/wait/AgentsTools.MemberWaitRun.include

the floors, the baselines and the probe functions below, which are kept by position: sorted after them, a source read the floor
and the baseline of the one that had stood at its new index, and the session thread's new message was dropped as older than a
floor that was never its own.
The order is made by the shell (call-path audit row 58): each source is put after the last one whose interval is not longer,
and two of one interval stand in the byte order of their names, as `sort -n` over `<interval> <source>` lines placed them.
post's copies, its newest, its stamps) are numbered by its place in the list, so a source held from the stored wait at another
place takes them along. In two steps through a staging folder, so two sources that trade places never write over each other;
the place a moved source lands on drops what another source left there. Dropping them all instead made every moved source
read all of it again live (a 10 s Wait ran 978 s).
that was not stored at this index is read first-probe, and is never compared to another source's old rendering,
which read as an arrival with an empty block. A held source takes its stored baseline back below.
another source would be compared as this one's and returned as its arrival, a line of another source with no header.
It starts empty; a held source takes its stored baseline back as its rendering below, so an unread probe is no change.
another source left at this index made it skip its first read. It stays only where the same source held this same index.
The other side files (a DM's or a post's copies) are kept: dropping them made every moved source read all of it again live.
hours, so that fork rather than any probe is what an idle estate cost the machine. A fifo this wait holds both
ends of, waited on by the shell's own `read -t`, blocks for the nap and starts nothing. Measured on bash 3.2.57:
a read of 300 seconds is woken by TERM as promptly as a sleep is, so a wait is still ended the way it was.
life of this shell: on the exec itself, `2> /dev/null` would silence every line the wait still owes.
marker written for that wait woke nothing. Each waiting run names its nap fifo in one small file beside its member's waits.
read, bounded by MDAT_SLACK_READ_BOUND_SECONDS, 120 s where the caller set none, held here once. A source not yet read in this call
gets that whole bound, so the bound decides when the wait returns, never which sources it reads: the
deadline is overrun by at most one read bound per source, and only while that source is unread. A source read once gets what is
left of the deadline, or that bound where it is shorter.
Wait pick their own out of it, the last line of a source winning as the awk before took it. No process per source.
of their own only when called outside a round.
messages of the other sources together. A scan alone stays unbegun once something has arrived (below).
The bound is looked at before each source: one slow source read past it held the whole call past it.
A timeout of 0 reads every source once and returns after the round (below): its bound is spent at the start, and a check here would read none.
The first round reads every source whatever the bound says: a wait whose start-up spent its bound would otherwise end having read nothing, and say WAIT-NEVER-READ of every source.
after the first round: the first round reads every source whatever the bound says (above), so a start-up that spent the bound
never leaves the scan unread and named in WAIT-NEVER-READ.
left of the Wait's deadline, or that bound where shorter. A source that overruns it is named never read in this round,
WAIT-NEVER-READ: a full read's time did not complete. The round goes on to its other sources.
nobody fills and every source stands never-read (AgentsWaitOwnPostRepliesCheck, 24 of 24). MDAT_WAIT_CACHE_ONLY given wins; else the
lock of the comms thread decides, once a call.
a probe read in line is cheap and a round never pays a Retry-After. A costly probe past the bound is handed to the task wrapper.
A CACHE-ONLY PROBE IS READ IN LINE: its only wait is the folder's fifo, bounded below to end inside the round's own bound. Under the
wrapper, a probe that waited its fifo budget crossed the wrapper's window, was detached, and the source stood never-read with the
cache already served beside it (AgentsWaitRepliesFirstLookCheck, 11 of 19).
A probe is a read of what reaches the member, so a chat message does not detach it (MDAT_TOOL_TASK_NO_MESSAGE): it is what the probe reads.
outlives the Wait's bound by the seconds times the folders (the ask probe over three asks held a 300 s Wait for 500).
as the design says. It is no failure and no read: the source stands in WAIT-NEVER-READ until a round finds it served.
An unserved probe was no probe: its TTL clock is not started, so the next round asks the cache again instead of reading nothing
inside the TTL and counting the source as read.
takes ONE more read, the arrival it announces, and no more: a member whose marker every post addressed to it touches would
otherwise never reach its deadline, and a wake that ended the wait unread would lose the very arrival it woke for.
wait sleeps up to the first source that comes due, so a costly source is not re-read on every tick.
A read that waited out its whole time reports 1, as `sleep` reports 0: the guard carries that, or `set -e` ends the wait.

## sh-lib/wait/AgentsTools.MemberWaitSources.include

directories below are: a walk over every session's folder on every Wait call is a hot-path fault (call-path audit row 59).
the run named, so an item left there for the duty is never left unread by a Wait that named others.

# sh-lib's folder list, and the check that names it

`sh-test/common/AgentsShLibFoldersCheck.test.sh` names fifteen folders plus `templates/`, `help/`, `client-hooks/` and
`vscode-fragments/`. The tree holds these, outside that list, each with real content:

- `atlassian/`
- `chat/`
- `contacts/`
- `core/`
- `distro/`
- `email/`
- `event-track/`
- `google/`
- `items/`
- `knowledge/`
- `monitoring/`
- `routine/`
- `run/`
- `schedule/`
- `settings/`
- `slack/`
- `spawn/`
- `supervise/`
- `transcript/`
- `trello/`

Its `common/` rule is a default list too, and these files stand outside it: `AgentsCommonSyntax.include` and
`AgentsCommonSyntaxIndex.awk` (the common option set's own syntax reader and index builder, added with the call-path work),
`AgentsTools.Emergency.include`, `AgentsTools.LocalLock.include`, `AgentsTools.CommandsList.include`, `AgentsTools.Hook.include`.

Both lists are the check's own stated defaults for the maintainers to review; widening either is a ruling, not an agent's edit.
The check stands at 2 of 7 (the root of `sh-lib` holds folders only, which it did not before).

## sh-lib/common/AgentsTools.CommonOptions.include


AgentsTools.CommonOptions.include -- the common option set of the commands of myx.distro-agents (F2.2 of the refactorings epic), and the operation that
shows the context they resolve (--intern-context-show). Sourced for its functions only.

THE FIVE OPTIONS, given as a run directly after the operation word, never later (the value of another option can be spelled the same):
  --team-member <team-member>                      implied from MDAT_SPAWN_AGENT; at the console user-<account> (USER); with no account, nothing, and the call is refused
  --session-id <session-id>                        implied from MDAT_SESSION_ID
  --spawn-id <spawn-id>                            implied from MDAT_SPAWN_SESSION_ID, or `shell-console` for the shell CLI (the record's `spawn-id`; not the session id)
  --select-workspace <place-name|absolute-path>    implied by MMDAPP, resolved to an absolute path on input
  --tooling-origin <spec|absolute-path>            implied by MDLT_ORIGIN, resolved to an absolute path on input; the spec is `source` or `.local` of the workspace
Each entry point of the tooling takes them at the head of its main function (AgentsToolsCommonRun); the operation never sees them.

THE MEMBER POSITIONAL IS RETIRED, FOR GOOD (S21.3, the owner's ruling). An operation whose help syntax says `<team-member>`
(or `<member>`) first (the one list, the 📘 syntax index of Help.DistroAgentsTools.help.md) gets the resolved team member
placed in that place always, from --team-member or the environment, so no operation body changes and its own checks
(AgentsToolsActingMemberCheck, AgentsToolsClientCallerCheck, the caller-check layer) see the very value they saw. A caller
still naming the member positionally gives the operation one argument too many, which that operation's own check refuses.

WHAT A MEMBER SESSION MAY NOT DO. A spawned session acts as one member (AgentsToolsActingMember): for an operation that takes no member positional, a
--team-member naming another is refused as AgentsToolsActingMemberCheck refuses it, and the console may name only its own default, user-<account>, never
another member (F6.10: a console answers as user-<account>); --session-id and --spawn-id may only restate its own; --tooling-origin may
name only the origin (`source` or `.local`) of a workspace this machine knows, as a gate run from a tree the member controls would bypass every gate; and
--select-workspace may name only the workspace it is in or the one the member-workspace resolution (AgentsTools.MemberWorkspace.include) gives the member.
The console, a call from no member's session, is unrestricted in these; for the member it answers as user-<account>.

Whether an operation REQUIRES a common option where the context does not hold it: its help syntax writes the option unbracketed with its common placeholder
(`--session-id <session-id>`), where the bracketed `[--session-id <session-id>]` is implied from its variable and may be left out.
ONE pass answers all three, into agentsCommonNeeds: the caller asks once for each option, and a pass each read the 487 KB help file three times
on every tool call. agentsCommonNeeds is space-padded, so a membership test is `case " $agentsCommonNeeds " in *" $opt "*)`.
THE OLD POSITIONAL IS RETIRED, FOR EVERY SERVED FRONT TOOL (S21.3, the owner's ruling): the member is always
resolved here, from --team-member or the environment, and placed ahead of whatever real arguments remain.
A caller still naming it positionally now gives the operation one argument too many, which that operation's
own check refuses. `--print-required-scopes` is the operation's own declaration of the Slack scopes it
needs, which no member is the subject of: no member is placed before it.
THE INVITED MEMBER, WHEREVER THE NAME CAME FROM (S21.3): a member set up only in another workspace on this machine is
invited here, as it was for a name given first -- its skillset is read from there, and the settings this workspace
holds none of. Resolved here because this is where every member-first call takes its member, --team-member and the
implied one alike; the front door's own block only ever saw a name standing first.

# The ladder, and what a call path may read

A call path takes a kept measure or an index, never a walk of a store. The ladder, from the cheapest rung:

1. **The live list**, `.local/agents/live-sessions`: one line per session whose control thread holds it, written where the thread takes
   the session and removed where it leaves. Eleven lines on a store that has held thousands.
2. **The session's own prepared files**, `.local/agents/sessions/<id>/control/`: `state`, `pid`, `lock`, and `live.rows` -- the session's
   rows as the registry renders them, written where its state is written.
3. **The registry**, `.local/agents/spawned-sessions.registry`: the stable, conservative rows -- tracking name, session, parent, host,
   owner, status, exit, spawn, agent-log, session-thread, workspace. Built by a walk once, then kept current by its writers: a record
   written puts that run's rows in by a read and a rename (`AgentsTools.RegistrySpawnedSessions.Refresh.include`, called from
   `AgentsSpawnRecordWrite`). No reader walks for what a file already says.
4. **Unprepared session data**, read only where the rungs above do not answer.

Presentation data -- a title, a chapter, a comment, a tally -- is not a registry column: a tool call never reads it, and the readers that
show it take it from rung 2.

## What the pass reads, and what it cost

The advance pass asks the registry render for `live` and gets the live list's rows from their prepared files: no registry read, no
rebuild, no measure. Measured on this workspace's store (187 sandboxes, 326 records): the registry render's cold reading was 24,830 ms
and its kept copy is 19 ms; the pass's `live` reading touches neither. A control thread's start costs 318,124 bytes of source and 24 ms,
down from 577,680 and 69 ms. `--current-flags` reads another workspace's pace from its kept measure: 30,470 ms to 665 ms. The all-records
array builds from the registry: 14,343 ms to 4,130 ms on a rig of 1,857 records.

## States a session shows

`running`, `busy`, `starting`, `waiting`, `paused`, `awaiting-review` are active; a session that ended within **ten minutes** stays in
the active list with its own `finished` or `failed` state, read from the minute its last run closed, and leaves after that. Dead history
is asked for by name (`--all-sessions`), and `AgentsSpawnedRetentionPrune` removes a dead run's folder once nothing has written it for **14 days**, twenty a pass.

## The console app's own screens, and what their checks stand at

The screen's checks drive the real plugin offline (`sh-test/manager/AgentsManagerScreen*Check`), a stand-in terminal and a stand-in
dispatcher, so they measure the page and not the store. On 2026-11-22, **64 of 78 pass**. The ones this round brought to green, with
their sizes: `Activity` 53, `Pane` 63, `List` 63, `Table` 62, `Members` 50, `Control` 47, `TeamData` 40, `RowCursor` 13, `States` 8,
`TeamDataStart` 7, `Linger` 5.

Two causes were found under that family, and both were in the page rather than in the checks:

- **a session row printed before the phase column existed was taken as closed.** `parseSessionRows` now reads the phase from the
  row's own state when the row carries none (`running`, `busy`, `starting`, `waiting`, `paused`, `awaiting-review`, and
  `unknown-foreign`, which is another host's and not this console's to close). That one change took `Control` from 35 of 47 red to
  green and `Pane` from 21 of 63 red to green.
- **another host's session is active, and closed excludes it**: `Active Sessions` keeps `unknown-foreign` although its own row says
  closed, because nothing on this host can have seen it end; `Closed Sessions` never holds it, and its tail keeps its own state
  rather than a false "ended just now". `ActivityCheck` holds this at 53 of 53.

The red ones split in two, and the split is a fact about the machine this was measured on, not a licence for the code. **A screen whose
case starts a stand-in live session or drives a real terminal cannot run in this sandbox**: `/bin/sh: /bin/ps: Operation not permitted`,
and `pty.openpty` raising `OSError: out of pty devices`. That covers `Configuration`, `Leftovers`, `Frame`, `Mouse`, `Chrome`,
`TerminalLoss`, `KillLive`, `Dialog`, `Redraw` and `EmojiWidth`. `Sessions` (52) and `Linger` (5) used to fail on drawings written before the session rows gained their control-thread, token and
phase columns, and both are fixed: their fixtures now build the sixteen fields the operation prints, rather than appending fields to a
row the parser reads by position. `ListCost`'s two-screens case asserts a read scheduling that lives in the screen of
`myx.distro-.local`, so it is a defect of the screen, not of this package.

## Open: the Activity root still reads the session list

The shape that removes that read is built and measured: the root reads one prepared line (`--manager-session-summary`, a file, no store walk) and the six
sections stand on one list read of their own. With it the root makes **0** list calls and `Activity` passes 53/53, twice measured. What blocks it is the
count the other checks make: the shared list is started **once per level** that shows it, so a case visiting two lists counts two calls, and the list is
re-read where the tree has one read for all. A shared cache key -- one key several levels stand on, read once and held by its `period` -- is what settles it.

## What one look of the screen costs, measured

The list the screen reads, `--manager-session-list`, is prepared once and kept five minutes beside its target, per question: the build is
**39-50 ms** with the copy standing, against about **600 ms** without it, and `AgentsManagerListKeptCheck` holds that (a first look writes the
copy, a second inside the five minutes neither rewrites it nor answers anything else). The schedule ask that runs beside the list was
throttled by a counter in its own process, so every look — each a process of its own — paid the whole **2.4 s** walk; the minute it last ran
is kept in `schedule-thread/ask-due.stamp` now, and the three looks measured end to end were **2,789 ms**, then **90 ms**, then **101 ms**.
`AgentsManagerListKeptCheck` holds both halves: a look inside the thirty seconds neither rebuilds the copy nor answers anything else, and the ask
keeps its minute in the store, with no per-process counter deciding it.

## The screen's reads, and what a look costs

The manager rows are built once and kept thirty seconds, written aside and put in place by one rename: `--all-sessions` on this
store is **632 ms** cold and **39 ms** from the kept copy, so the first page a person opens is no longer the page that collects the
store. The selection rest before the left pane reads an item is **250 ms** (`REST_SECONDS = 0.25`), so a selection running down the
menu reads nothing for the rows it passes and only the item it stops on. An operation the screen asks for at its root is replaced
with what the screen already holds where one exists; `list:activity` stays the session list, and the six sections of `Activity` are
its rows.
