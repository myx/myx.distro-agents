# Code craft: writing style, names, and indirection

Read this before writing code in any language — it is not a per-language module and does not compete with them: it governs how code is written at all, and applies on top of whichever language module is open, in any project.

## The style

- Code is straight-line, top-to-bottom prose: the reader starts at the top of a block and reaches the end of it without leaving.
- Structure is introduced only where the code genuinely has structure — real reuse, or a name that carries meaning the body cannot — never to organise, tidy, decorate, or signal effort.
- Fewer names is better code: fewer functions, fewer variables, fewer layers, fewer files. Each one added is something the next reader must hold in their head, and a place a defect can hide.
- In doubt, write it where it is used.
- A path, filename, or other location is written literally at the site that uses it — never assembled through a chain of names the reader has to walk backwards to resolve.
- Banned outright: a function called from one place; a function that wraps a couple of lines; a variable holding a value used once; a variable trivially derived from another; a global used as an out-parameter; a wrapper that only renames an existing call.
- A name that earns its place is at least two words in camelCase — `doClose`, `needsClose`, `openChar`, `nestDepth`, `fieldCount`. Never a bare `close`, `depth`, `key`, `value`, `data`, `i`, `n`. Applies to every language and to every kind of name: parameter, local, field, function.
- The rule is mechanical, not aesthetic. A bare word is the one shape that collides with a language's own vocabulary, and the diagnostic rarely says so: `close`, `index`, `length`, `split`, `sub` and `system` are AWK built-ins, and a parameter named after one is a parse error rather than a shadowing warning — `function f(s, i, open, close)` reports "4 missing }'s" and points at an unrelated construct, so the real cause is invisible in the message. Two words cannot collide. The same holds for a shell variable one `readonly` or one sourced file away from a clash it will never announce.

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
