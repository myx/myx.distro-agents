# Code craft: writing style, names, and indirection

Read this before writing code in any language. It is not a per-language module, and does not compete with them. It governs how code is written at all, and applies on top of whichever language module is open, in any project.

## Contents

- The style
- Simplicity is a requirement
- A check is code, and it is proven by its red
- Bounds, reserves, and the guard that repairs
- Comments: quantity and content are two separate checks
- A requirement is a property of the result, not a structure in the code
- The habit this exists to break
- The three costs of needless work
- The counter-rule
- What already works is not rewritten

## The style

- Code is straight-line, top-to-bottom prose: the reader starts at the top of a block and reaches the end of it without leaving.
- Structure is introduced only where the code genuinely has structure: real reuse, or a name that carries meaning the body cannot. It is never introduced to organise, tidy, decorate, or signal effort.
- Fewer names is better code: fewer functions, fewer variables, fewer layers, fewer files. Each one added is something the next reader must hold in their head, and a place a defect can hide.
- In doubt, write it where it is used.
- A path, filename, or other location is written literally at the site that uses it. It is never assembled through a chain of names the reader has to walk backwards to resolve.
- A file with two readers has two grammars, and only one of them is visible in the file. Where a tool parses a source file as data, its layout is not free, and an edit that looks cosmetic breaks it silently. Read the parser's anchor before reformatting anything, and prove the check can fail by feeding it the broken form. Where the constraint is invisible from the file, one short line records it at the point an editor would break it.
- A number is written only where its reader needs it in order to act. In code that rule falls on several things:
  - a tally beside the list enumerating its own items.
  - a message stating a set's size instead of naming what it read.
  - a comment recording how many call sites something has.
  - how many exit codes a table carries.

  The reader needs the things themselves, named. Where a number is genuinely needed it is computed at the point it is printed, never typed in by hand. The second test, for whatever survives the first: would this site have to change as the thing it counts grows? A site that would, and does not compute the number itself, does not carry it.
- A standing rule of the human-owner's: say it only if it is relevant to the reader or genuinely a fun fact. Stated in full in own human-owner standing rules.
- A scratch file is a name too, and the costliest kind. On top of everything a variable costs, it carries a path to construct, a cleanup, and a failure branch for each. A value that fits in a variable goes in a variable. `shell.md` states the
  shell mechanics, and the two cases that genuinely earn a file.
- Tooling is written in bash 3.2+ where bash is efficient for the task, else awk, else Python only where awk won't do. Perl is not used: Python is the chosen one of the two, for now, and switching needs proof that the other is universally better. No choice adds a dependency. The tool fits the file it will grow into after the first MVP, complications and improvements included. Working code is kept until it is clearly a laggard or a blocker. It is never converted to follow the order by itself. `shell.md`'s "Which language a piece of tooling is written in" states it in full.
- A failing step ends the run, so nothing that must happen is written after something that can fail. Code is written as though abort-on-first-failure is in force, whether or not the file switches it on: `set -e` in shell, a propagating exception elsewhere. A cleanup placed below the failure is skipped on exactly the runs that needed it. Work owed on the failing run belongs to the scope's own exit, a trap or a `finally`. Switching the mode off does not rescue the trailing line: it only makes the failure quiet.
- Work the result does not need is a defect in its own right, not an optimisation to revisit later. Two operations doing what one does is the needless-name fault with the name removed. An example is `shift` then `commandName=$1 ; shift`, where `commandName=$2 ; shift 2` consumes both at once. The code reads correctly, and the run still pays for it. It binds hardest on a path taken constantly, where the cost is paid on every pass.
- A variable holding a value used once, or trivially derived from another, produces bad, low-quality, unreadable code that hides errors. The value it holds is already available where it is needed. So the name adds a second place the reader must resolve, and a second place a wrong value can enter unnoticed. The defect is concealed behind a plausible name, instead of sitting in view at the site that uses it. Banned outright below. This is why.
- A declaration and its assignment are one line. The split form earns its place for one reason only. In shell, a plain assignment reports the command substitution's own status. Any declaring keyword in front of it (`local`, `export`, `readonly`) reports its own instead. So a status that is actually tested is captured on a line of its own. Where nothing tests the status, the split doubles the line count and names nothing the single line did not.
- Banned outright:
  - a function called from one place.
  - a function that wraps a couple of lines.
  - a variable holding a value used once.
  - a variable trivially derived from another.
  - a global used as an out-parameter.
  - a wrapper that only renames an existing call.
- A name that earns its place is at least two words in camelCase — `doClose`, `needsClose`, `openChar`, `nestDepth`, `fieldCount`. Never a bare `close`, `depth`, `key`, `value`, `data`, `i`, `n`. Applies to every language and to every kind of name: parameter, local, field, function.
- The rule is mechanical, not aesthetic. A bare word is the one shape that collides with a language's own vocabulary, and the diagnostic rarely says so. `close`, `index`, `length`, `split`, `sub` and `system` are AWK built-ins. A parameter named after one is a parse error, not a shadowing warning. `function f(s, i, open, close)` reports "4 missing }'s" and points at an unrelated construct, so the real cause is invisible in the message. Two words cannot collide. The same holds for a shell variable one `readonly` or one sourced file away from a clash it will never announce.
- The same rule holds for every token a search must find: a record key, a pointer kind, a marker, a file stem. Make it a compound of at least two words, such as `mentions-checked:` or `work-duty`, never a bare word such as `dms:`, `read:` or `scan:`. A bare word also matches the prose, the comments and the unrelated code around it, so a search for it returns everything but the token.

## Simplicity is a requirement

Standing rules from the human-owner:

- A straightforward task gets straightforward code. Complication is a defect before any question of whether the code works.
- A value that fits in a local variable never becomes a temp file: a variable has no cleanup problem.
- No extra variables, functions or files beyond what the requirements and efficiency need.
- A `bash` script is written to bash 3.2, the crossplatform baseline of Darwin, FreeBSD and Linux. A project needing all three platforms' `sh` takes the POSIX standard instead, with no bash-ism even where it works on Linux.
- No bash 4 feature (`mapfile` among them) in a bash 3.2 file.
- A bash 3.2 redirection, expansion or array is used only where it makes the result better on all three of faster, readable and simpler.

What follows from them:

- **One fault, three shapes: an unnecessary temp file, an unnecessary variable, an unnecessary function.** Each is a unit created to hold a step that did not need holding, and each adds something to create, name, track and clean up. A helper called from one place, wrapping what its single caller could have stated directly, is the function-shaped version of materialising one dataset three times. The same principle, read from the other side: a stub written for one call site takes mandatory arguments and does its mechanical steps itself. It does not distribute them to its caller as options.
- **A shell file's standard is settled by what that file requires.** An available construct still has to earn its place on all three of faster, readable and simpler at once. `shell.md` states the standards and the test.

## A check is code, and it is proven by its red

A checker reports green on its own counterexample as readily as on a clean subject, and nothing in a green report tells the two apart. What settles it is the red.

- **An instrument is finished once it has been watched to fail**, against a case that violates the very assertion it makes. Reasoning that it would fail is not the demonstration, and a green first run over a clean subject establishes nothing about the instrument.
- **A stage that cannot reach its subject fails loudly. It never passes.** A rig that fails to extract the thing under test and then prints its PASS lines is reporting on nothing. Those lines read exactly like a result. Every step that loads, extracts or selects the subject is a failure branch, not a best effort.
- **A checker's failure text is written about the subject, so a rig that never started reports exactly like a subject that broke.** Measured: a check copied into an origin holding one package reported 13 of 17 assertions failed, every word of them about the subject. Its sends had never left the rig, and its own `*.out` held two missing includes. With its siblings beside it, the same check on the same tree failed 1 of 17. So a batch of failures arriving together is read in the rig's own output before any of them is believed. Build the rig with every sibling the run sources, not the package under test alone. A workspace setting is missing the same way, and it reads the same way. Measured on a two-assertion stand-in check: without `SLACK_CHANNEL_MAGIC_TEAM` in the environment it reported both assertions failed, and with the variable set both passed. So the rig also needs the environment files the real run has, not only its siblings.
- **A control is a control only once its two directions return different values.** Run it both ways before the measurement it qualifies is trusted: one case that must pass, one that must fail. Where both come back the same, the instrument is broken, not the subject clean. The measurement is withdrawn, never reported with a caveat. **The control goes in the first run, not the second.** A zero that arrived before its control came back has established nothing. Where the probe's answer decides what another member is told, the control belongs in the same call. Measured case: a hyphen count run through BSD `sed` with `\|` returned 0, and a rewrite using four `case` arms printed 4.
- **A measurement taken by someone else answers the question it was taken with, and no wider one.** Measured case: another member's table showed a here-string backed by a regular file, with a pipe as its control. That settled only that a file exists. Three further questions had no measurement: whether the file outlives the call, where bash puts it, and whether `TMPDIR` moves it. One answer changed the sentence. So name what the rule will assert, and give each part its own measurement. A part with no measurement is either taken now or left out.
- **A shared directory is not a stable baseline, so take the count twice with nothing between.** Measured on this estate's Darwin box: `/private/var/tmp` held 276 entries on one read and 275 on the next, with nothing run between them. Two hundred here-strings then moved it by nothing at all. Control: an owned directory holding one file read 1 on ten consecutive reads, and a planted second file read 2, so the instrument sees a change of one. So a count taken against a population that moves on its own cannot separate its subject's effect from the drift.
- **A tool that prints a hard error and still exits 0 makes every caller's status check dead code.** The message is written for a person reading a terminal. The status is the only thing a caller reads. Where the two disagree, the caller is told the operation succeeded. A diagnostic is not a failure signal. Whatever prints the error exits non-zero on that same path, and every layer between it and the caller passes the status on. The caller's check is worth writing only once that chain holds. `shell.md` states the shell mechanics each layer drops it through.
- **An axiom that keeps being violated in new code is not under-stated, it is unenforced.** Where the wording is already sound, what changes is the mechanism. The rule becomes an executable check wired into a pass that already runs, so it is met without anyone choosing to look. A stronger sentence in the same place the last violation walked past is not a fix.
- **A check that reads the same stateful subject twice clears the subject's whole store, not only its answer cache.** A reader that records when it last read a source skips it on a second call a moment later, so the row never reads and asserts on nothing. The skip is the reader behaving correctly, so the check is what resets it. Drop the store beside the cache, with one line saying why.
- **A check that runs over an explicitly listed population cannot prove a claim about every member of a class.** The OK line states completeness, the list states which files were read, and only the second is true. Where the message says "every", the population is derived rather than listed. Where a list is unavoidable, the message says what it covers instead of claiming the whole class. `AgentsTools.Owner.include:1452` to `:1462` is that list, and the OK line it feeds is at `:1465`. I did not establish that this leg loads an awk from outside its own hand-kept list, which is what the bullet rests on.
- **A statement of present state carries the date it was taken, and the gate re-takes it before acting.** Measured case: a plan's table said no code existed for an operation its own documentation describes. Re-taken three days later, the documentation half still held. That half is what kept the line alive. So a line naming a mechanism is checked in its two halves, the prose and the code. Measured on one tree at one moment: 1 line of `MAGIC.md` documents `--intern-comms-ingest`, and 0 files of `sh-lib/` name it. The same search names `slack-read` in 30 files of 352.
- **A verdict table needs its refusing rows, or a widened arm passes on every row that is left.** Measured on a four-row table, against the same table with its kind test dropped. Only one row differed, and it was the row that must be refused. The three positive rows read the same either way. Where a rule gates a class, the check carries one row per class that must be turned away.
- **A digest mismatch is a finding about the convention, not the subject, until the convention is named.** A hash answers only for the exact byte string it was given. Where the writer publishes no convention, a mismatch reports the reader's guess instead. Name the convention that reproduces, or say no convention reproduced. The digest convention is the instrument's definition, so this is "read the instrument before trusting the measurement" applied to a hash.
- **A report of absence built by subtracting one list from another is a fact about the two lists, never about the thing that is absent.** Where every path that touches a subject fills the first list except one, that one path is reported as a failure. A deliberate skip and a source that could not be read then print the same words, and no reader can tell the two apart. So a skip path marks its subject in the list its neighbours mark, or the report gives a skipped subject a word of its own. Before a name in such a report is quoted as a fact about its subject, read the code that built the list. The `WAIT-NEVER-READ` line is that fault, against the skip the wait takes.
- **A bound spent inside a walk over peers starves every peer after the first one that can absorb it.** A bound that keeps one pass short belongs to each member of the walk, not to the walk. Shared, it is spent on whichever peer has the most waiting, and the peers after it are never reached at all. The fault hides because each peer's own bound looks correct in isolation, and only the caller's arithmetic is wrong. Where a pass has a total budget as well, the walk carries two numbers: one per peer, one for the walk. The second one either rotates the starting point or divides the first.

## Bounds, reserves, and the guard that repairs

- **A repair is admitted by a wider limit than the one that triggers it, or it is refused exactly where it is needed.** The shape is a bound, a reserve of headroom held free, and an admission test of `size + incoming <= bound - reserve`. The repair fires at the first `size` where that test fails. Judged by that same test, the repair's own write is refused at every size that triggers it and above. The refusal region begins at the trigger itself. Measured with `bound=100`, `reserve=10`, `incoming=5`, `repairCost=5`: the first trigger is size 86, and the same test refuses the repair from 86 upward. Judged against `bound` itself, that same repair is admitted from 86 through 95 and refused at 96, which is the honest answer. So the repair write is measured against the bound, never against the reduced threshold the trigger uses.
- **The reserve that keeps a repair possible is computed, not chosen.** The first firing size is `bound - reserve - incoming + 1`. The repair fits there exactly when `reserve + incoming > repairCost`. Measured with `bound=100`: `reserve=10, incoming=5, repairCost=5` fits, `reserve=1, incoming=1, repairCost=5` does not, and `reserve=10, incoming=1, repairCost=30` does not. A reserve smaller than one repair makes the guard a dead branch on every run that needs it.
- **A guard whose trigger and whose admission test are the same number cannot be told from a guard that never fires.** Both read as working code, and both leave the failure in place. Name the number each side is measured against, at the site, so the next reader sees whether they are one number or two.

## Comments: quantity and content are two separate checks

- The limits are the team's existing ones, not a second set: "A comment is short, or it is not a comment". An internal comment is one line, and a header comment a few at most. Anything longer is documentation belonging in the package's own `MAGIC.md`. Where a package carries a `MAGIC.md`, it states the same limits for its own code.
- **Quantity is checkable, and it is the half that gets failed.** The reviewer's question is asked of one comment at a time, against the limits above. A comment past its own limit is over it, whatever those lines say.
- **Content is the other check**, per "Rule/instruction/definition/description conventions": state a durable fact, never narrate a past action. A comment holds a durable fact or convention, never a narration of a past action or an explanation of what changed. The two checks are independent: a comment can be entirely factual and still be forty lines that belong in `MAGIC.md`.
- **Volume is a runtime cost too, not only a reading cost.** A file the shell reads often is lexed in full on every pass, comments included. So comment count is paid per source on a constantly-taken path. A file can sit within the per-comment limits above and still carry the cost through sheer number. This is a separate argument from the readability limits and does not replace them. `shell.md` states the measured per-source cost on bash 3.2 and dash.
- **A rename that makes a comment false, rather than merely stale, is reworded in the same change.** The two are different defects. A stale comment describes an older state a reader can still map onto the code. A false one asserts something the code now contradicts. Most often it is a contrast between two names that the rename has just collapsed into one. The comment then draws a distinction that no longer exists. Renaming is what produces this. So every comment naming either side of the old distinction is read as part of the rename. It is not left to a later pass that has no reason to look there.
- Volume regenerates in new code even where an existing tree has been brought within the limit. The standard holds where it is enforced, which is why this is a review step and not a one-off sweep.

## A requirement is a property of the result, not a structure in the code

- A long list of caveats invites a mechanism per caveat — its own variable, its own file, its own trap, its own branch. That reflex builds the shape of the briefing instead of the shape of the problem.
- Constraints are things that must be true of the finished result. They are checked against it, never mirrored inside it.
- Where a requirement appears to need something convoluted, that is a finding about the requirement. It goes to the human-owner, not into the code.

## The habit this exists to break

- Agents over-structure by default: wrapping, naming, extracting and layering because it looks professional, not because the code needed it. The result reads as scaffolding around a small idea.
- That single habit is what a whole class of defect comes out of:
  - a capture bug hidden behind a helper.
  - a scratch path no reader can resolve from the code.
  - a convention imported from the wrong project and concealed behind a variable name.
  - a 200-line heredoc inlined where every sibling package sources a dedicated include.
  - a wrapper that re-sources its own file to reach a function in it.
- Subprocess inheritance, pipe semantics and the rest are symptoms, not the rule: write less structure and they do not arise.

## Each call runs only its own path

- A call parses and runs what its own path needs, on a small shared setup. Nothing goes upfront to serve a minority of calls.
- No trivial variable and no trivial function goes in a common place. Repeat a few lines at each site, twenty times if that is faster for the call paths.
- A large repeat, or a complicated gotcha, becomes an include. It is sourced only on the paths that use it, at each of them.
- A chain of five or more small includes of about 1 kB each, loaded on the path, is better than one 3000-line file loaded once and then run again in many calls inside it.
- A file is split per source, per feature or per operation. Never into trivial tiny pieces.
- A router, or any file of distinct parts for separate operations, stays compact. The parser never reads a 1000-line file for a 2-line operation.
- One long algorithm may be a large file by itself, when it is one piece with the most common path threading through it. It may still be split.
- A command script is for an external call. An internal step sources the exact include it needs, never re-enters a whole command script.
- Inside tooling code, a tool is reached through its loaded functions: `Require ListDistroProjects ; Distro ListDistroProjects --select-all`. This is how tooling is written, never how it is operated. An operator, and a member at work, calls the command, `<Tool>.fn.sh --<operation>`, as `magic-team.armed.md`, 'Execution mechanisms', states.
- A call path takes a kept measure or an index, never a walk of a store. A call path is a schedule pass, a Wait round, a permission gate, an ask or a start. It reads a kept list or the registry as it stands. A new walk is listed in `AgentsHotPathWalksCheck` with its reason, or it does not land. See `magic-team/reference/engineering-discipline.md`, "Call paths and walks".
- An include the MCP server sources on every request, such as `sh-lib/mcp/AgentsTools.InternMcpRequest.include`, holds its tool list in one single-quoted string. No apostrophe goes into that string. An edit to such an include is followed by `bash -n` before the next tool call.
- A review requires all of this. Code that breaks it is sent back, whatever else it fixes.

## The three costs of needless work

**Readability.** Straight-line logic scattered into named fragments cannot be followed in one pass. A basic question, where does this file live, becomes a reverse-walk through four names that ends in giving up, not in an answer. Code nobody will read is code nobody reviews, and unreviewable code is rejected.

**Performance.** Every needless name, and every needless operation, is real work at runtime. A wrapper that forks (a command substitution, a pipeline, a subshell) costs a process where an inline expansion costs nothing. A variable built from a command substitution forks to produce a value used once. Chained derivations repeat that at every call site, and in a loop or a per-request server path it multiplies. Inline straight-line code does the minimum work by construction.

**Hidden problems.** Indirection conceals both the construct in use and the place it acts on. Review then passes over defects that would have been visible written out:
- A helper is not inherited by a spawned subprocess. So code that works inline breaks silently the moment the same path is forked or exec'd.
- A capture bug survives review when the `$( ... )` sits behind a helper and a variable chain. That a server waits on a pipe's writers, not on the command, is unreadable from the call site. The defect is invisible precisely because it is named.
- A location hidden behind a chain hides its own wrongness with it. An imported `mktemp -d "${TMPDIR:-/tmp}/..."` matching nothing in any sibling project of its family passes unnoticed behind one variable name.

## The counter-rule

- A genuinely reused block stays a function, and so does one whose name carries real meaning its body does not. The test is reuse or comprehension, never tidiness.
- Inlining is not a licence to repeat a large algorithm. A large repeat goes to an include, per "Each call runs only its own path". The ban is on names that carry nothing, not on abstraction that earns its place.
- A convention the sibling packages of the family already follow outranks both. Where they source a dedicated include, that is the structure the code genuinely has.

## What already works is not rewritten

- Working code is never rewritten for consistency alone. A difference in style, ordering, or phrasing between two correct pieces of code is not a defect, and is not fixed.
- Only a behaviour-changing defect, or something the human-owner has explicitly asked for, justifies touching code that already works. Reading differently from its neighbours is neither.
- The cost of a consistency rewrite is paid in full whether or not it was needed, against no behavioural gain at all. It is review effort spent, regressions introduced into code that was working, and real fixes drowned in the diff.
- A mass cosmetic pass buries real defects. A diff of hundreds of mechanical edits cannot be reviewed, so a genuine bug inside it goes unseen. Behavioural fixes and cosmetic passes stay separate, separately-approvable pieces of work.
- This is the sibling of the structure rule above, and it binds harder. Structure is introduced only where the code genuinely has structure. Code that already runs correctly is left where it stands.
