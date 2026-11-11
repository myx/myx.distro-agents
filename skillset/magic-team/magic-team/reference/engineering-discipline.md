# Engineering and operating discipline: further rules

Rules of "Engineering & operating discipline" that a member needs only on occasion.

## Contents

- Git, scope and finishing
- Evidence
- Dispatch, relay and produce
- Call paths and walks

Git, scope and finishing:
- The floor: the team tools and its session sandbox (read `input/`, write `output/`). Under `source/` it adds reading every `MAGIC.md`, `README.md` and `docs/**.md`, and writing `MAGIC.md`. Anything else under `source/` needs a grant. A member's own file may hold a wider standing grant tied to a place. magic-librarian's `.md`-edit of a team-member skill under `.skillset-shared` or `.skillset-.local` is one (`magic-librarian.armed.md`). Nobody approves what it does not hold: tooling routes that ask up, to a holder in the session or task, then to the human-owner. A holder may pass a permission on (`--pass-permission`) to a participant or a member it spawned for the work. It is never wider or longer than its own.
- A routine may grant or refuse its participants permissions for its run (`access-control:` in its frontmatter, rows such as `participants:allow-tool:<tool>`).

Evidence:
- A check you would act on is shown able to fail: its positive control runs in the same call. A count states its unit. A published number carries the instrument that produced it and any exclusion.
- A count is not a listing: print the matches and read them. A partial search is reported as partial.
- A null answers about the instrument, never the world. Check that the instrument had the rights to see the thing.
- A check that shares the subject's own logic proves consistency, not correctness.
- A clean exit proves what ran, not that it was the target. A fallback that fires is a defect to trace. A rejected tool call may still have started a process.
- Tell competing readings apart: find the observation they disagree on. Answer per state where the question is per state.
- Coverage is the union of what the team can reach. Name the member who can reach a target instead of calling it untestable.
- Evidence written for an external reader names which system it describes. Two installations that share a product name are two subjects, never one.

Dispatch and relay:
- The dispatching session checks a dispatched write against the conventions before it reports it done. The report is a direct message to whoever asked, in that member's own words.
- A public-release scrub of a member covers its `.basic.md` and `SKILL.md` description as well as its `.armed.md`.

Call paths and walks:
- A call path is a schedule pass, a Wait round, a permission gate, an ask or a start. It runs on every call, so what it reads costs every call.
- A walk is a `grep`, an `awk`, a `find` or a `for` over every file of a store: `spawned/*/*.spawn.md`, `board/<state>/*.md`, `sessions/*/<file>` or `inboxes/*/incoming/*`. A working workspace holds thousands of such files.
- A call path reads a kept list (`AgentsTools.StartedRecords.include`), the spawned-sessions registry as it stands, or the children lists.
- A new walk goes on the list of `AgentsHotPathWalksCheck` (`sh-test/session`) with its reason, or it does not land. The check reads the code and fails a walk that is not listed. Its debt line names what is still on a call path.
- A shared reader gains a line only behind a switch.
