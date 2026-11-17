---
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
---
# Code review: the checks a changed line must pass

Read this when reviewing code, whoever wrote it. Each section is one rule of
`magic-developer/reference/code-craft.md` or `shell.md` turned into what the
reviewer looks for and what counts as a finding. The reasoning and the worked
cases stay in those two files. This one is the checklist a reviewer runs against
every changed line. Companion to `evidence-discipline.md`, which covers what
makes a check able to fail, and to `live-side-effect-verification.md`, which
covers a run with real consequences.

A review reads the change, not the whole file. A shape that already stood before
the change is not this review's finding, per `code-craft.md`'s "What already
works is not rewritten".

## Contents

- An unnecessary function
- A variable derived from another
- A store path behind a name
- A store read past its owner
- A store path the caller builds
- A name without its prefix
- An operation in a file of many operations
- A load that serves a path the file never takes
- A file outside its subsystem's folder
- A family of operations written as copies
- A write to the system temp folder
- A check run outside the test runner
- A check that names its subject by its folder
- A check that writes a store file by hand
- An analytical SOLID scan left unrun
- A guarded load whose name or file is wrong
- A refactor review that skips the breach scan counts
- A stage landed by copying whole files
- A subshell or process on a call path
- A review that reads only what the diff adds

## An unnecessary function

Rule: `code-craft.md`, "The style", its banned list and the three reasons a
function stays.

Look for:

- a function called from one place.
- a function wrapping a couple of lines, where its caller could state them.
- a wrapper that only renames an existing call.

A finding is a new function that meets none of the three reasons it stays. Those
are: a trap or a similar shell mechanism needs one, an API needs a function
whatever its content, or it carries non-obvious knowledge that needs its gotcha
comments. An API needs the function called by name from another file, through a
variable, from a dispatch table, or stubbed by a check. A function whose only
claim is that a fragment is easier to name is a finding. The finding names the
lines that belong at the call site.

## A variable derived from another

Rule: `code-craft.md`, "The style", the derived-variable bullet.

Look for:

- a name assigned text built from another name, such as `VARN="${VARX}text"`.
- a chain of two or more such assignments.

A finding is a derived variable read further away than the same few lines of one
block. The reader then resolves two names for one value, and a second place a
wrong value can enter. The two readings that are not findings: it is set and used
within the same few lines of one block, where the reader sees both, or the
algorithm needs it there. The finding states which of the two the change fails,
and quotes both lines.

## A store path behind a name

Rule: `code-craft.md`, "The style", the literal-convention bullet.

Look for:

- a function or a variable wrapping a store path, such as
  `"$MMDAPP/.local/agents/sessions"`, `"$MDAT_DATA_ROOT/board"` or
  `"$MDLT_ORIGIN/..."`.

A finding is any indirection between a system-wide convention and the site that
uses it. The convention is written literally where it is used. The finding quotes
the wrapped path and the wrapper, and states the literal form the site takes.

## A store read past its owner

Rule: `code-craft.md`, "Loads and contracts", the three bullets on an include of
another concern, an internal data file, and the breach scan.

Look for:

- a file naming a store its own concern does not own: `.local/agents/sessions/<id>/...`,
  `.local/agents/spawned/...`, the board, the inboxes, the vault.
- a path the owning concern hands out, for a caller to build on.

A finding is any read or write of another concern's store, and any path passed
out to be built on. A store no concern in the package owns belongs to the distro
tooling, and it takes the same finding. Not a finding: an include of another
concern, `sh-lib/<concern>/*.include` or a shared awk file, loaded to call its
functions. That include is the concern's contract. The finding names the store,
its owner, and the function that returns the data instead.

## A store path the caller builds

Rule: `code-craft.md`, "Loads and contracts", the owner-function bullet.

Look for:

- a call passing a path into another concern's function.
- a caller assembling a store path from an id before the call.

A finding is a caller that builds the path to another concern's part, where the
callee could take the id. The path belongs in the owner's own function. Not a
finding: the owner's include, loaded to call its functions, which is its
contract. The finding names the call, the part it reaches, and the id the
owner takes instead.

## A name without its prefix

Rule: `code-craft.md`, "The style", the prefix bullet.

Look for:

- a new global, and the prefix the file's other globals share. `harnessX` in the
  harness, `agentsX` elsewhere.
- a new local, and the prefix the function's other locals share. In a function
  holding `actPath` and `actRound`, a new local is `actX`.

A finding is a new name carrying neither prefix, such as `sessionsDir`,
`boardTree` or `tmp`. A finding is also a new local taking a bare generic word,
even where its neighbours are prefixed. The finding names the sibling name the
new one should have followed.

## An operation in a file of many operations

Rule: `code-craft.md`, "Each call runs only its own path", the bullet on one
operation and one file.

Look for:

- a file serving two or more operations, and what its branch does for each one.
- an operation's body reached as a function called once.

A finding is an operation whose body sits in the dispatcher rather than in its
own file. A finding is also a per-operation file whose whole content is one
function called once, where the file is the operation's body instead. A branch of
a few lines stays inline, and that is not a finding. The finding names the
operation, its own file, and the lines the branch keeps.

## A load that serves a path the file never takes

Rule: `code-craft.md`, "Each call runs only its own path", the load-before-use
bullet.

Look for:

- a load at the top of a file, of another file only some of its paths need.
- a served call that parses text belonging to a path it is not on.

A finding is a load that runs on a call which never uses what it loaded. The
function loads what it calls right before it needs it: `type F || . file`, a
builtin test with no fork. The finding names the load, the calls that pay for it
and need none of it, and where the load belongs.

## A file outside its subsystem's folder

Rule: `code-craft.md`, "Each call runs only its own path", the subsystem-folder
bullet. The folders under `sh-lib/` include `spawn/`, `schedule/`, `supervise/`,
`undo/`, `routine/`, `event-track/`, `wait/`, `slack/`, `email/`, `google/`,
`trello/`, `atlassian/`, `knowledge/`, `contacts/`, `grants/`, `board/` and
`inbox/`.

Look for:

- a new file, and the subsystem whose work it does.
- a file standing in a folder next to its subsystem rather than inside it.

A finding is a file living outside the folder of the subsystem it serves. The
finding names the folder the file belongs in, and every load site the move
touches.

## A family of operations written as copies

Rule: `code-craft.md`, "Each call runs only its own path", the copy-paste-family
bullet.

Look for:

- two or more branches whose text differs in a few places.
- several operations of one shape, added one after another.

A finding is a copy-paste family where one branch with a pattern and a table of
the differences would serve. The finding names the operations, the places they
differ, and the table that replaces the copies. A family of two or three that
share nothing but a name is three operations, not a finding.

## A write to the system temp folder

Rule: `shell.md`, "A scratch file is the most expensive name in a shell script",
the no-system-temp bullet.

Look for:

- a `mktemp` template under `/tmp`, or a hand-written path under it.
- a scratch path the code assembles from a fixed directory and a name it chose.

A finding is any write whose template sits outside `"$MMDAPP/.local/temp/"` and
outside the session's own folder. A hand-written path under `/tmp` is a finding
on its own, whatever the surrounding style. The finding quotes the line and the
template the site takes.

## A check run outside the test runner

Rule: `code-craft.md`, "A check is code, and it is proven by its red", the
runner bullet.

Look for:

- a new driver, wrapper or loop that runs its own subjects.
- a run that does not clear the caller's environment.

A finding is a check run any way but `sh-test/AgentsRunTests.sh` with
`MDAT_SKILLSET_ROOT` set to the workspace's members. A driver of the change's own
is a finding even where it produces the same output. A driver that does not clear
the caller's environment lets a rig run as the caller, and that is the fault the
rule exists for. The finding names the command the check is run with instead.

## A check that names its subject by its folder

Rule: `code-craft.md`, "A check is code, and it is proven by its red", the
subject-by-name bullet.

Look for:

- a check reading code by file name, or by a fixed folder.
- a population derived from a folder the check itself lives in.

A finding is a check that breaks on a move rather than on a defect. It finds its
subject by function name or by a glob over `sh-lib/*/`, never by a fixed folder.
The finding names the selector, the move that breaks it, and the selector that
survives.

## A check that writes a store file by hand

Rule: `code-craft.md`, "A check is code, and it is proven by its red", the
fixture bullet.

Look for:

- a check writing a board, inbox or session file with its own heredoc.
- a fixture made by copying a store file into place.

A finding is a fixture built anywhere but through the store owner's writer,
`sh-test/check-fixtures/rig-owner-writes.include.sh`. The check then asserts its
own guess at the format, not the format the owner writes. The finding names the
owner's writer for that store.

## An analytical SOLID scan left unrun

Rule: the SOLID scan of the change's tree. Run
`sh-test/solid/AgentsSolidBreachScan.sh` (`--summary` for counts) on the tree
the change touched.

A finding is a new row the scan prints, P0 first. Its P0 classes come from
`sh-test/solid/AgentsSolidContracts.py`: `unreached`, `silent-load`,
`optional-call`, `dual-use`, `undefined-call`; `P6` is dead.

## A guarded load whose name or file is wrong

Rule: `code-craft.md`, "Loads and contracts", the guarded-load bullets.

Look for:

- a guard whose named function its file does not define.
- a guard whose named function the code it guards does not call.
- a load pointing at a file that only pulls the function in as a side effect.

A finding is a guard read by its name and its file. The named function is
defined in that file, and the guarded code calls it. The code ends at the end
of its function, or of its case arm (`;;`). The load's file is the file that
defines the called function.

## A refactor review that skips the breach scan counts

Rule: the SOLID scan's class counts. Run
`sh-test/solid/AgentsSolidBreachScan.sh` with its root given, and quote the
class counts on the result.

A finding is a review of a refactor that quotes no class counts from a scan run
with its root given. A default run reads live, not the copy.

## A stage landed by copying whole files

Rule: `code-craft.md`, "Batch changes".

Look for:

- a landing that copies a file whole from an older copy.
- a removed line that was a live call from another landing.
- a diff file nothing proved to apply.

A finding is any of the three. The stage merges three ways against its base.
Each removed line is read for a live owner call. A diff file is proved to apply
before it is relied on. The finding names the file, the line, and the check the
landing runs.

## A subshell or process on a call path

Rule: `code-craft.md`, "Each call runs only its own path", the call-path bullets.

Look for:

- a `$( )`, a pipeline or a background job on a schedule pass, a Wait round, a
  tool call or a spawn start.
- an array filled through a command substitution where a builtin serves.
- a value written as `var=$( printf … )` where `printf -v var` serves.

A finding is a subshell or a process started where a builtin does the same work.
The finding names the call path, the line, and the builtin form the site takes.

## A review that reads only what the diff adds

Rule: `code-craft.md`, "What already works is not rewritten", and a diff is
what it removes as much as what it adds.

A finding is a removed line that is not this change's own kind: a revert of
another's work. Before trusting a green check, show it was able to fail: run a
constructed known-positive case first.
