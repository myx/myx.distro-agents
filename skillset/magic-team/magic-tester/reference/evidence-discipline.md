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

The three diverge routinely, one divergence per pair: emoji
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
**some infra** (whatever those need to exist and run). `magic-tester` runs one
with the owning `keeper-*` in the domain that has such a suite. The
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

Where the change is an addition to a shared index rather than a transformation of
an input, the same three steps hold with the "before" manufactured rather than
found: hold the new thing out, ingest, and snapshot every existing entry; put it
back, ingest again, snapshot again; diff the two snapshots. A single snapshot
taken after the fact cannot answer "did anything else change" — it has nothing to
be compared against, and the question it appears to answer is a different one.

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

The shape of the failure: a coverage figure quoted for a
message class, where the counter's unit is threads rather than conversations —
two populations that merely look interchangeable. The check is one step: find
where the number is produced, read the unit off the code, and restate the claim
in that unit.

A negative that comes back identical for every subject is the same question
asked of the instrument. A probe that enumerates a config directory's
subdirectories, where the configuration is held in files inside it, finds
nothing and concludes no member holds the key — while every member with real
configuration holds one. **A uniform "none anywhere" — none configured, none matching, none
present — is a finding about the instrument until one subject with a known
positive answer has been put through the same probe.** That positive control is
the cheap half: a single known-yes case through the identical command shape,
before the sweep's result is offered as a result.
`magic-developer/reference/shell.md` carries the shell-side form of this under
its Principles, for recursive searches whose empty output looks the same either
way.

## A system's enforcement path and its reporting path are different surfaces

Neither one's silence describes the other. Reading the code that enforces a rule
establishes what that code does when the rule is broken. It establishes nothing
about whether the system reports that condition somewhere else, through a listing
command, a query option, a log line or a help entry.

The gap is easy to miss because the first reading is genuinely correct. A resolver
that accepts a malformed state without complaint is a true finding about the
resolver; "the tooling has no diagnostic for that state" is a claim about every
surface the tooling has, resting on a search that was never run. The second is
what a reader plans around.

So name the surface that was actually read, in the sentence stating the result,
and check the reporting surfaces before generalising to the system. Where a
pre-flight check does exist, it is usually cheaper than the failure it prevents.

## A refusal for want of privilege reads exactly like an empty result

An instrument answering under insufficient rights reports absence in the words of
a genuine negative, and nothing that counts rows can tell the two apart. `vm list`
under a non-root identity answers that virtual machines can only be managed by
root; recorded as "no guests, vmm not loaded", every conclusion drawn downstream
was wrong.

This is the authorisation case of the positive-control family above, and it takes
the same instrument: one known-positive subject, through the identical command
shape, under the identical identity. Establish that the identity used actually had
the rights to see the thing before reporting that the thing is absent — the output
alone never carries that difference.

## A probe answers its own predicate, not the question it was asked

A check that runs cleanly reports on the condition it actually evaluates, and
the distance between that condition and the claim it gets quoted for is where a
false positive lives. Two shapes it takes, each producing a wrong
report to the owner:

- **Existence is not configuration.** `[ -f ]` passes on a zero-byte file. Where
  most `.agent.env` files in a workspace are empty, a `[ -f ]` probe reports
  every one of them as configured, and a member whose files are all 0 bytes reads
  the same as a fully configured one. The
  discriminator is `[ -s ]`, or parsing the file for the key the claim is about.
  Where a layer creates the file on first access, existence carries no
  information at all by construction; `myx.distro-agents`' `MAGIC.md` records
  that as a contract of `--agents-config-option`.
- **A pipeline's exit status is the last command's.** `op | tail -2 ; echo
  "rc=$?"` reports `tail`'s status, so a rejected call reads back as `rc=0` —
  which is how "the op accepted it" gets reported for a call the op refused.
  Capture the status of the command whose success is the claim, ahead of any
  pipe or substitution. `magic-developer/reference/shell.md` carries the
  adjacent `cmd ; rc=$?` under `set -e` case in "Shell constructs that fail
  quietly": a different cause with the same result, a status that reads clean
  for something else.
- **A clean exit and an empty answer share one exit status.** A project that was
  never indexed resolves as exit 0 with an empty sequence, shaped exactly like a
  successful resolution of a project that genuinely requires nothing. A console
  can mask the other half: the failing call prints `exited with error status (1)`
  on stderr while the pipeline still returns 0. Assert the exit status *and* a
  non-empty result — neither alone separates the two, and a baseline captured
  before an ingest is worth nothing whichever it was.

So state the claim, read the predicate the probe evaluates, and check the two
are the same sentence. Where they differ, the fix is the stronger probe rather
than a caveat attached to the report.

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

## Establish which way a check errs before deciding whether it needs a fallback

A pre-check wrong in one direction only is adoptable on its own; one that can be
wrong in either direction needs something behind it. Which of the two it is gets
measured before the design is settled, not assumed from how accurate it feels.

Worked case — workspace resolution: the members table can answer
"don't know" where the true answer is yes, and cannot answer "stay" where the
true answer is a different workspace. A member carrying one row while operating
correctly from three workspaces is exactly that false
"don't know". The costs sit the same way round: a false "don't know" spends an
unnecessary workspace switch, a false "stay" would aim work at the wrong target,
and it is unreachable. That one-directional failure mode is what makes the
table-check adoptable with no fallback path behind it.

So enumerate a proposed check's wrong answers and price each one before arguing
about its hit rate. Errors that all land on the expensive-but-safe side need no
fallback; a check that can be confidently wrong in the costly direction needs
one however rarely it is.

## An oracle settles what opinions divide

Where the question is conformance to a specification — a markup dialect, a date
format, an escaping rule, a protocol frame — and a reference implementation
exists, run the input through it and read the answer off the output. `pandoc`
settles a GitHub-Flavored-Markdown question that reading the spec alone leaves
two members answering differently.

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

## A sanitised environment manufactures the failure it then reports

`env -i` strips `PATH` and `HOME` along with everything else, so a probe run
under it reports a tool as absent and a home-rooted path as missing whatever the
real state is. The verdict looks decisive — "CLI NOT INSTALLED" — and it conceals
the blocker that actually exists. Nothing is learned about the subject; the
measurement describes the harness.

Sanitise named variables, never the whole environment, and where a clean
environment is genuinely the point, put a known-positive subject through the same
sanitised shape first. The general form is the positive control above: an
instrument that answers "absent" for every subject is answering about itself.

The mirror failure costs as much: an environment variable **inherited** and not
noticed. A shell channel carrying its own `MMDAPP`, `KUBECONFIG`, `AWS_PROFILE` or
`GIT_DIR` points every command that honours it at a subject the operator did not
choose, and a `cd` does not change it. Two commands compared side by side can then
be reading two different systems while the transcript shows one directory. So
before an A/B run, print the variables that select the subject, and state the
subject in the finding rather than the directory the command was typed in.

## Absence of a notification is not evidence of progress

A spawned session can end its turn without any completion notification firing —
finished, silent, and indistinguishable on the notification channel from one still
working. Waiting longer produces the same nothing.

So a session's state is established by asking something that answers either way:
the roster, the tracking document it was told to write, a direct ping. Never treat
"I have not heard back" as "it is still running", and never report progress that
rests on it. This is the reporting-surface rule applied to sessions — the channel
that would have carried the news is not the channel that holds the state.

## Read `git status` before measuring a package under concurrent edit

A working tree that another session is editing is not one state, it is two: what
is committed and what is not. A measurement that does not separate them reports
in-progress lines as settled fact, cites line numbers that have already moved, and
produces findings that will not reproduce for whoever reads them next.

So the first command of any code measurement is `git status --porcelain` over the
package, and every finding names which of the two it holds in — HEAD, working
tree, or both. Untracked files are the sharpest case: a file that exists only in
the working tree makes the code around it read as finished work. Where a cited
line number does not carry what a report said it carried, treat that as the
coordinates having moved under an active edit, and re-measure by content rather
than by line — not as the finding being false.
