# magic-developer — Maintainer Notes

The body of this member's armed `# Maintainer Notes`. Read it when that file is updated, assessed or tested.

## Contents

- Verbatim-goals (intents)
- Verbatim-tests (benchmarks)
- Librarian Comments
  - Reference
  - Conventions

## Verbatim-goals (intents)

- A domain skill knows where code lives and why it's structured that way; `magic-developer` knows how to
  write the language itself correctly, regardless of which repo you're in.
- Code is written straight-line and top-to-bottom, and a function or variable is introduced only where the
  code genuinely has structure — real reuse, or a name carrying meaning its body cannot.
- New tooling code takes bash 3.2+ where it is efficient, else `awk`, else Python only where `awk` won't do,
  and never Perl — with no new dependency, chosen for the file it will grow into after the first MVP
  (complications and improvements included), and without
  converting working code that is not clearly a laggard or a blocker.
- Prefer the least-latency, most-portable tool actually suited to a scripting task's shape, in order to
  keep tool choice consistent across every shell-scripting decision.
- A shell file is held to exactly one standard, settled by what that file itself requires: bash 3.2 where
  it declares a bash requirement, POSIX `sh` carrying no bash-ism at all otherwise.
- An available construct is not thereby a justified one: a bash 3.2 construct is used only where the
  result is better on faster, readable and simpler together.
- Simplicity is a requirement of the result, not a preference weighed against other requirements.
- An unnecessary temp file, variable and function are one fault in three shapes: a unit created to hold a
  step that did not need holding.

## Verbatim-tests (benchmarks)

- A language-level axiom surfaced while a `keeper-*` does daily Java file-comment archaeology gets fed into
  `reference/java.md`, not left buried in that `keeper-*`'s own file.
- A helper called from exactly one place is inlined rather than kept, in any language, even where the
  surrounding file is full of such helpers and the extraction would read as tidier.
- Asked to write a small text-transform/filter script for a shell operation, the member uses bash builtins
  where they are efficient, and `awk` where bash would fork per line. It turns to Python only when `awk`
  won't do or would be utterly inefficient, trying `jq` first when the task is JSON-shaped.
- A working Python helper is touched for an unrelated fix. The member keeps it in Python: it is neither a
  laggard nor a blocker, and the tool order is not a reason to convert it.
- A member believes Perl fits a task better. It writes no Perl file: it sends the human-owner the proof that
  Perl is universally better, on his direct channel, and Python stays until he rules.
- Given a choice between two tools where either could do the job, the one with lower startup cost and
  narrower/more portable scope is chosen, unless the task genuinely needs the other tool's specific
  capability.
- A file already declares a bash requirement. Rewriting one of its constructs into a POSIX-only form, to
  satisfy a portability constraint that is actually about `sed` and `grep`, fails review.
- A construct is faster and reads clearly while adding a stage the plain form did not have. It fails the
  three-part test on `simpler`, and the plain form stands.
- A scratch file holds a value used once and is removed by a trap on every return path. It becomes a
  variable, and the path, the trap and the removal sites go with it.
- A file declares `#!/bin/sh`, and the mechanism that runs it evaluates its body inside a bash script.
  It is held to the bash standard: the shebang is inert text, and the mechanism is what settles it.
- A comment is accurate, durable and forty lines long. It fails the quantity check and moves to the
  package's own `MAGIC.md`, its content never having been the problem.

## Librarian Comments

### Reference

- `reference/*.md` — the modules indexed above.
- `magic-architect` — the peer design-level review role.
- `magic-frontender` — owns CSS and browser-facing craft.

### Conventions

- The language-craft/project-convention split is this member's organising principle.
- `reference/code-craft.md` is not a per-language module; language-specific instances of it live in the language modules.
- The bash exclusion list is derived from the 3.2 baseline, never kept as a flat list beside it.
- Comment limits are pointed at, never restated: one wording in `magic-team/magic-team.armed.md`.
