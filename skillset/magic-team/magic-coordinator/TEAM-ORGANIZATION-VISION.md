# Team Organization Vision — magic-coordinator

How the magic-* team is organizationally structured: execution model, operating rhythm, work
pacing, human-owner involvement, and partner posture.

## Execution model: UI/relay instance vs. spawned work instances

- The instance a human is actually talking to (the UI/chat instance) never executes an activity's
  real work itself.
- Every activity — main-loop, daily, grooming, retro, one-on-one, any member's own work-rounds —
  runs in a dedicated spawned instance: its own background `Agent`, that member's own `Skill` as
  first action.
- The UI/chat instance stays present for the whole activity, relaying between the human and the
  spawned instance verbatim, no re-phrasing.
- No per-activity exception — a one-on-one spawns a dedicated instance the same as every other
  activity, never a direct in-conversation handoff.
- Spawned work is not gated on the human/UI session staying present — comms and iterations keep
  advancing regardless of live presence.
- When a spawned activity needs human input it can't decide or defer on its own, it routes through
  an async channel (a team-channel post, a tracked-board record) rather than blocking on live
  presence. Something needing genuine real-time back-and-forth gets its own freshly spawned
  interactive session instead.
- Open, not yet designed: a per-activity briefing, prepared by the documentation steward in
  advance, that a spawned instance would coordinate against.

## Operating rhythm: seven days a week, one continuous loop

- The team runs a continuous operating rhythm, not a per-request wake-up: comms checked promptly,
  inboxes processed, backlog groomed once a day, the daily work-session fan-out actually happens.
- Triggered only by explicit instruction — never started implicitly.
- Each iteration's behavior depends on persistent state, day of week, and today's own progress so
  far: a first-today iteration may run a small grooming pass while context gets refreshed, then a
  daily meeting that watches for planned work-sessions.
- Comms/messaging sweeps are one recurring element inside the loop, not the whole thing.
- Weekends: communications and light reactive admin (reorganizing todos, updating records) only in
  response to an actual incoming request — no proactive work dispatch.
- Work is organized as projects: a top-level container with its own context, goal, states, and
  decisions. Anything triaged is assigned to an open project rather than left floating. Projects
  stay small and short — extended with a new task rather than growing an in-progress task's own
  scope.
- Activity traces post to the team's shared channel throughout, not just at close-out.
- Single-instance protection prevents the same logical iteration running twice concurrently,
  regardless of which entry point triggered it.
- A spawned iterator is not reliably addressable directly by name — reachability runs back through
  the chain that spawned it.

## Work-lifecycle pacing: staged as default, marathon as exception

- Work normally moves through stages, not necessarily all of them, not necessarily in strict
  order: triage/backlog, assignment to an activity, investigation/discussion/planning, small
  approved tasks, single-member implementation, then a different member testing/validating it.
- Real pause points sit between stages by default.
- Marathon execution — continuing straight through without pausing between stages — is a
  situational exception, granted explicitly for a specific case. It is never the default posture.

## Human-owner involvement: approval vs. routine triage

- Needs human-owner approval: work plans, goals, scope changes — decisions about what the team
  commits to.
- Does not need human-owner involvement: routine triage — declining, backlogging, or opening an
  investigation on a member-raised issue or a broken pipeline. The coordination/architecture layer
  decides and records this itself.
- Each step is sized as one bounded assess-then-record unit, not chained into further action in
  the same pass — the next step picks up from the recorded state, by a different member, or the
  same member at a later, separate activity time.

## Partner-* activity posture, and the proposal pipeline

- Partner members default to present-but-non-reporting: roll call only, no automatic work-session
  dispatch, unless a specific case is raised for a direct one-on-one.
- Idle-day findings go through a proposal pipeline, not direct action — a finding is raised, never
  acted on directly by the member that found it.
- Small, obviously-safe findings get dispatched straight back to the proposing member.
- Findings involving cross-subsystem changes, large-scale refactoring, or overlap with another
  member's domain escalate to a joint review with everyone actually implicated, before any design
  assessment happens.
- Assessment weighs risk, profit, and effort — normalized scoring across profit, cost, time, and
  dependencies, re-scored for the whole current backlog at every grooming pass, informing
  prioritization without deciding it alone.
- Outcomes compact into a hierarchical, cross-referenced form rather than an ever-growing flat
  list.
- Open, not yet built: partner members becoming workspace-dependent in activity level — more
  active, with their own persistent log, specifically where a shared project with another team is
  genuinely live.
- Open, not yet decided: the documentation steward proposing adoption of validated changes into
  other members' own definitions, not just their docs.