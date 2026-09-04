# Code craft: writing style, names, and indirection

Read this before writing code in any language — it is not a per-language module and does not compete with them: it governs how code is written at all, and applies on top of whichever language module is open, in any project.

## The style

- Code is straight-line, top-to-bottom prose: the reader starts at the top of a block and reaches the end of it without leaving.
- Structure is introduced only where the code genuinely has structure — real reuse, or a name that carries meaning the body cannot — never to organise, tidy, decorate, or signal effort.
- Fewer names is better code: fewer functions, fewer variables, fewer layers, fewer files. Each one added is something the next reader must hold in their head, and a place a defect can hide.
- In doubt, write it where it is used.
- A path, filename, or other location is written literally at the site that uses it — never assembled through a chain of names the reader has to walk backwards to resolve.
- A number is written only where its reader needs it in order to act. In code that falls on a tally beside the list enumerating its own items, a message stating a set's size instead of naming what it read, a comment recording how many call sites something has, and how many exit codes a table carries — the reader needs the things themselves, named. Where a number is genuinely needed it is computed at the point it is printed, never typed in by hand; the second test, for whatever survives the first, is whether this site would have to change as the thing it counts grows, and a site that would while not computing the number itself does not carry it.
- A standing rule of the human-owner's: say it only if it is relevant to the reader or genuinely a fun fact. Stated in full in `magic-team/magic-team.shared.md`'s own human-owner standing rules.
- A scratch file is a name too, and the costliest kind: on top of everything a variable costs it carries a path to construct, a cleanup, and a failure branch for each. A value that fits in a variable goes in a variable — `shell.md` states the shell mechanics and the two cases that genuinely earn a file.
- A declaration and its assignment are one line. The split form earns its place for one reason only — in shell, a plain assignment reports the command substitution's own status, while any declaring keyword in front of it (`local`, `export`, `readonly`) reports its own instead, so a status that is actually tested is captured on a line of its own. Where nothing tests the status, the split doubles the line count and names nothing the single line did not.
- Banned outright: a function called from one place; a function that wraps a couple of lines; a variable holding a value used once; a variable trivially derived from another; a global used as an out-parameter; a wrapper that only renames an existing call.
- A name that earns its place is at least two words in camelCase — `doClose`, `needsClose`, `openChar`, `nestDepth`, `fieldCount`. Never a bare `close`, `depth`, `key`, `value`, `data`, `i`, `n`. Applies to every language and to every kind of name: parameter, local, field, function.
- The rule is mechanical, not aesthetic. A bare word is the one shape that collides with a language's own vocabulary, and the diagnostic rarely says so: `close`, `index`, `length`, `split`, `sub` and `system` are AWK built-ins, and a parameter named after one is a parse error rather than a shadowing warning — `function f(s, i, open, close)` reports "4 missing }'s" and points at an unrelated construct, so the real cause is invisible in the message. Two words cannot collide. The same holds for a shell variable one `readonly` or one sourced file away from a clash it will never announce.

## The human-owner's standing words on this

His own wording, held as the standard this file states:

> "Why you create so many temp files?
> Why you create extra variables, extra functions?
> Why you make it more complicated than it needs to be compliant to requirements and efficient?
> FOR JUST ONE: LOTS OF FILES COULD BE LOCAL VARS - WITH NO CLEANUP PROBLEM
> I DONT WANT YOU TO MAKE CRAZY FRAGILE UNREADABLE COMPLICATED CODE FOR STRAIGHTFORWARD TASK
> EVEN MORE: for `bash` scripts - bash 3.2 is the base - you may use this version's supported bash-isms since you already said that this script required bash
> bash 3.2 - crossplatform baseline version of Darwin, FreeBSD and Linux - this is baseline for `bash` scripts. Of course, in some other projects we need all three OS emulated `sh` support - then we do the other standard and don't use any bashisms even if it would work on Linux
> NO mapfile! I said bash 3.2 on 3 OS!
> But there are nice redirections, expansions and arrays - BUT ONLY USE THEM WHEN THEY MAKE RESULT BETTER IN ALL:
> - faster (executionally, less CPU time, less total time)
> - readable (understandable, traversable by eye)
> - simpler (logically, algorithmically solution-wise)"

Three things follow:

- **One fault, three shapes: an unnecessary temp file, an unnecessary variable, an unnecessary function.** Each is a unit created to hold a step that did not need holding, and each adds something to create, name, track and clean up. A helper called from one place, wrapping what its single caller could have stated directly, is the function-shaped version of materialising one dataset three times. The same principle read from the other side: a stub written for one call site takes mandatory arguments and does its mechanical steps itself, rather than distributing them to its caller as options.
- **Simplicity is a requirement, not a preference.** A straightforward task gets straightforward code. Complication is a defect in its own right, before any question of whether the code works.
- **A shell file's standard is settled by what that file requires**, and an available construct still has to earn its place on all three of faster, readable and simpler at once. `shell.md` states the standards and the test.

## Comments: quantity and content are two separate checks

- The limits are the team's existing ones, not a second set: `magic-team/magic-team.armed.md`'s "A comment is short, or it is not a comment" — an internal comment is one line, a header comment a few at most, and anything longer is documentation belonging in the package's own `MAGIC.md`. Where a package carries a `MAGIC.md`, it states the same limits for its own code.
- **Quantity is checkable, and it is the half that gets failed.** The reviewer's question is asked of one comment at a time, against the limits above: a comment past its own limit is over it whatever those lines say.
- **Content is the other check** — the Narration-vs-fact discipline in `magic-team/magic-team.armed.md`: a durable fact or convention, never a narration of a past action or an explanation of what changed. The two checks are independent: a comment can be entirely factual and still be forty lines that belong in `MAGIC.md`.
- Volume regenerates in new code even where an existing tree has been brought within the limit. The standard holds where it is enforced, which is why this is a review step and not a one-off sweep.

## A requirement is a property of the result, not a structure in the code

- A long list of caveats invites a mechanism per caveat — its own variable, its own file, its own trap, its own branch. That reflex builds the shape of the briefing instead of the shape of the problem.
- Constraints are things that must be true of the finished result. They are checked against it, never mirrored inside it.
- Where a requirement appears to need something convoluted, that is a finding about the requirement. It goes to the human-owner, not into the code.

## The habit this exists to break

- Agents over-structure by default — wrapping, naming, extracting and layering because it looks professional rather than because the code needed it — and the result reads as scaffolding around a small idea.
- That single habit produced every distinct defect found in one package's review: a capture bug hidden behind a helper, a scratch path no reader could resolve from the code, a convention imported from the wrong project and concealed behind a variable name, a 200-line heredoc inlined where every sibling package sources a dedicated include, a wrapper that re-sourced its own file to reach a function in it.
- Subprocess inheritance, pipe semantics and the rest are symptoms, not the rule: write less structure and they do not arise.

## The three costs of a needless name

**Readability.** Straight-line logic scattered into named fragments cannot be followed in one pass, and a basic question — where does this file live — becomes a reverse-walk through four names that ends in giving up rather than in an answer. Code nobody will read is code nobody reviews, and unreviewable code is rejected.

**Performance.** Every needless name is real work at runtime: a wrapper that forks — a command substitution, a pipeline, a subshell — costs a process where an inline expansion costs nothing, and a variable built from a command substitution forks to produce a value used once. Chained derivations repeat that at every call site, and in a loop or a per-request server path it multiplies. Inline straight-line code does the minimum work by construction.

**Hidden problems.** Indirection conceals both the construct in use and the place it acts on, and review then passes over defects that would have been visible written out:
- A helper is not inherited by a spawned subprocess, so code that works inline breaks silently the moment the same path is forked or exec'd.
- An MCP server's capture bug survived review because the `$( ... )` was buried behind a helper and a variable chain: nobody could see that the server was waiting on a pipe's writers rather than on the command, and the defect was invisible precisely because it was named.
- A location hidden behind a chain hides its own wrongness with it — an imported `mktemp -d "${TMPDIR:-/tmp}/..."`, matching nothing in any sibling project of the family it was added to, sat unnoticed behind one variable name.

## The counter-rule

- A genuinely reused block stays a function, and so does one whose name carries real meaning its body does not — the test is reuse or comprehension, never tidiness.
- Inlining is not a licence to repeat a real algorithm at three sites: the ban is on names that carry nothing, not on abstraction that earns its place.
- A convention the sibling packages of the family already follow outranks both: where they source a dedicated include, that is the structure the code genuinely has.

## What already works is not rewritten

- Working code is never rewritten for consistency alone — a difference in style, ordering, or phrasing between two correct pieces of code is not a defect, and is not fixed.
- Only a behaviour-changing defect, or something the human-owner has explicitly asked for, justifies touching code that already works; reading differently from its neighbours is neither.
- The cost of a consistency rewrite is paid in full whether or not it was needed — review effort spent, regressions introduced into code that was working, real fixes drowned in the diff — against no behavioural gain at all.
- A mass cosmetic pass buries real defects: a diff of hundreds of mechanical edits cannot be reviewed, so a genuine bug inside it goes unseen. Behavioural fixes and cosmetic passes stay separate, separately-approvable pieces of work.
- This is the sibling of the structure rule above, and it binds harder: structure is introduced only where the code genuinely has structure, and code that already runs correctly is left where it stands.
