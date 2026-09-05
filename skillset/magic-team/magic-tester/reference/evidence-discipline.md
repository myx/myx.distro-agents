# Evidence discipline: making a check able to fail, and a result mean what it says

Read this when judging whether something is actually verified — a fix, a
migration, a detector, a converter, a number quoted in a report. These are
properties of the evidence itself, independent of any one domain, language, or
test framework. Companion to `live-side-effect-verification.md`, which covers
managing blast radius when the run itself has real consequences.

## Establish the failing case before the passing one

Reinforces `magic-team/magic-team.armed.md`'s "Engineering & operating
discipline" rule — a check you would act on is not a result until it has been
shown able to fail — with the ordering that makes it operational:

1. Construct the input the defect makes fail, and watch it fail, against the code
   as it stands.
2. Apply the fix.
3. Watch that same input pass.

A pass observed only at step 3 is equally consistent with the fix working and
with the check being unable to fail at all — a filter matching nothing, a
comparison against a file that was already correct, an assertion the run does not reach.
**A clean comparison becomes a result once the same comparison has been seen to
come out dirty.** Where the defect predates the session, the failing case already
exists: check out or reconstruct the prior state and run against that. This is
the highest-value single step in a verification round; spend the time there
before spending it anywhere else.

## Verify what stores, not what sends

A write path's own success — an API's `ok: true`, the echo of the payload that
was sent, the writer's exit status — reports that the send happened. What was
stored is a second question, answered by reading it back through the independent
read path. What a reader sees is a third, answered by inspecting the rendered
surface.

The three diverge routinely. Confirmed instances of each divergence: emoji
submitted as glyphs and stored as shortcodes; line breaks submitted as newlines
and stored as spaces; a bare email address stored as plain text and rendered as a
link at display time.

So: read back through a separate path (a fetch call, a fresh open of the file, a
query against the store), and where the question concerns what a person sees,
look at the rendered form as well. An answer to one of the three leaves the other
two open.

## Byte-identical output over a full-grammar corpus, for a package that carries no test assets

**The established pattern in this estate is a distinct project holding the suite
for regression testing and development**, separate from every package under test.
Not a bucket every test must land in — a suite, and what it carries is: a
**testbed** (the environment a test runs against), a **harness** (the machinery
that drives it), **fake data** (fixtures standing in for the real thing), and
**some infra** (whatever those need to exist and run). `magic-tester` and
`keeper-ae3` run one for the AE3 domain, and it is proven in practice there. The
dependency direction is why it is a project of its own: a workspace contains it,
and it does not depend on the workspace. Test machinery placed inside a package
inverts that.

So a `myx.distro-*` or `myx.common` package carrying no test files, fixtures or
golden outputs is not itself a gap — that is the pattern holding. **The real gap
is that this family has no such suite**, and the cost is paid per session rather
than once: a scratch data root, a stub console, a throwaway remote, a before/after
driver, seeded fixtures — testbed, harness and fake data, hand-built and then
discarded. Report it that way; do not report the empty packages as the finding.

What the working example gets right transfers to any domain, Eclipse or not: every
assertion has a self-test mode running it against an input that must trip it and
one that must not; assertions read the produced output, not reachability, because
a broken route can still answer 200; each case in the battery is named and carries
a written reason it exists; fixtures are added alongside the real assets and the
originals are never edited; each run is isolated — loopback only, unprivileged
port, fresh working directories, a read-only overlay over the real artifact tree
so nothing checked in is written to; and a finding is recorded with its date and
marked stale when its premise stops holding, rather than quietly rotting. Those
are the organising principles to carry into a new test project, not the mechanics
of the toolchain around them.

Until such a suite exists — and for a change too small or too local to belong in
one even then — a differential run over the same input is the method. It is the
right instrument at that scale, and the steps below stand on their own. But note
what a differential run is: **a harness built and then discarded**, with its own
testbed and its own fake data around it. The method is not what a suite would
replace; rebuilding its scaffolding every session is.

For a transformation with no dedicated suite — a converter, formatter, generator,
template renderer — a regression net is cheap to build and reusable afterwards:

1. Assemble a corpus exercising every construct of the input grammar, including
   the combinations the implementation handles specially.
2. Run the pre-change implementation over it and keep the outputs.
3. Run the post-change implementation over the same corpus and diff byte for
   byte.

A byte-identical diff bounds the change to what it was meant to touch. The net's
strength is exactly its corpus coverage, so grow the corpus by the constructs a
change touches rather than by volume. A change designed to be purely additive is
expected to produce an identical diff over the pre-existing grammar — the net
pays for itself on the change that was supposed to be additive and turned out not
to be.

## Read the instrument before trusting the measurement

A count's name is a label someone chose; its definition is the code that produced
it. Before a number is quoted as evidence, establish what the tool actually
counted: which unit (a thread against a conversation, a file against a record, a
row against an entity), over which population, after which filters.

Confirmed shape of the failure: "137 of 139 sources" quoted as coverage of a
message class, where the counter's unit was threads rather than conversations —
two populations that merely look interchangeable. The check is one step: find
where the number is produced, read the unit off the code, and restate the claim
in that unit.

## A measurement carries its timestamp

Where several sessions edit one tree concurrently, a file read is true of a
moment rather than of the file. Two readers reaching opposite conclusions about
the same flag, line, or absent block are both reporting accurately from either
side of an edit.

So a finding about file state states when it was taken, and a finding that
contradicts another gets re-measured against current state before either is
called wrong. Where the conclusion matters, capture the evidence with its instant
— the command output plus the commit or mtime it was taken at — so a
disagreement resolves by ordering rather than by argument.

## A guard that fires is evidence; a guard that stays silent carries none

Several common mechanisms succeed by doing nothing, and that success is shaped
exactly like the work having been done:

- `mv -n` skips an existing destination and exits 0; `cp -n`, `ln` against an
  existing name, and similar refusals behave the same way;
- a limit or cap that truncates a result set without reporting the truncation
  returns a partial answer indistinguishable from a complete one;
- a conditional whose branch was taken silently, where only the other branch
  logs.

Two ways to make these observable: have the guard report when it fires (a
message, a distinct exit path, a counter in the output), and verify the
postcondition directly instead of the command's status — that the destination now
holds what was moved, that the returned count sits below the cap rather than
equal to it. A result whose size equals the cap is a signal to re-run with a
larger one before quoting it.

## An oracle settles what opinions divide

Where the question is conformance to a specification — a markup dialect, a date
format, an escaping rule, a protocol frame — and a reference implementation
exists, run the input through it and read the answer off the output. Confirmed
use: `pandoc` settling a GitHub-Flavored-Markdown question two members had
answered differently from reading alone.

The same move covers the class: a validator for a schema, a parser from the
spec's own project, the actual consuming product where rendering is the question.
Cite the tool and its version alongside the answer so the finding stays
checkable. Where no reference implementation exists, say which reading the answer
rests on.

## Test the inputs the design is silent about

A specification describes the shapes it anticipated; defects concentrate in the
shapes it did not mention, and those are enumerable up front for any input type:

- **empty** — zero rows, an empty string, an empty variable used to build a path
  or an argument list;
- **one element** — where separators, headers, and pluralization logic have
  nothing to separate;
- **ragged** — rows of differing widths, a table whose header and body disagree;
- **absent** — an unset variable, a missing file, an option with no value;
- **extreme** — one very large element, a very long line, deep nesting.

Empty earns first attention because empty tends to expand rather than fail:
an unset base path resolving a check against `/etc`, an empty argument list
leaving `find` to walk the current directory, an empty glob passed through
literally. Build these into the corpus as a transformation or path-handling
routine is written, and assert the intended behavior for each — a stronger
statement than the absence of a crash.
