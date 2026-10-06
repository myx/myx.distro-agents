# Team Organization Vision — magic-coordinator

How the magic-* team is organised: execution model, operating rhythm, work pacing, when the human-owner is needed, and partner posture.

## Contents

- Execution model: the UI instance relays, spawned instances work
- Operating rhythm: seven days a week, one continuous loop
- Work-lifecycle pacing: staged by default
- When the human-owner is actually needed
- Partner posture and the proposal pipeline

## Execution model: the UI instance relays, spawned instances work

- The instance a human talks to never executes an activity's real work itself.
- Every activity — daily, grooming, retro, one-on-one, a member's own work — runs in a spawned instance of its responsible member. No activity is an exception.
- The UI instance stays present for the whole activity and relays between the human and the spawned instance.
- Spawned work does not depend on the human or the UI session being present. Input it needs travels the chain of command; real-time back-and-forth gets its own spawned interactive session.
- Open, not yet designed: a per-activity briefing the documentation steward prepares in advance.

## Operating rhythm: seven days a week, one continuous loop

- The team runs a continuous rhythm while the host loop runs: comms checked promptly, inboxes processed, the backlog groomed once a day, the daily work session held.
- Each pass depends on stored state, the day of the week and today's progress.
- Weekends: communication and light reactive admin, only in answer to an actual request. No proactive dispatch.
- Work is organised as small, short projects with their own context, goal, states and decisions. Triaged work joins an open project. A project grows by a new task, never by widening a task in progress.
- Activity traces post to the team's channel throughout.
- One logical pass never runs twice at once, whatever started it.

## Work-lifecycle pacing: staged by default

- Work moves through stages, not necessarily all, not strictly in order: triage, assignment, investigation and planning, small approved tasks, single-member implementation, testing by a different member.
- Real pause points sit between stages.
- Marathon execution, straight through without pauses, is granted explicitly per case. It is never the default.

## When the human-owner is actually needed

- His approval: work plans, goals, scope changes — what the team commits to.
- Not his involvement: routine triage — declining, backlogging, or opening an investigation into a member-raised issue or a broken pipeline. The coordination and architecture layer decides and records this.
- Questions addressed to him are tracked as board items, never left to disappear.
- Each step is one bounded assess-then-record unit. The next step starts from the recorded state, later or by another member.

## Partner posture and the proposal pipeline

- Partner members are present but non-reporting by default: roll call only, no automatic work session, unless a case is raised for a one-on-one.
- Idle-day findings go through a proposal pipeline. The member that found one never acts on it directly.
- A small, obviously safe finding is dispatched back to the proposing member.
- A finding involving cross-subsystem change, large refactoring or another member's domain goes to a joint review with everyone implicated, before design assessment.
- Assessment weighs risk, profit and effort with normalised scores, re-scored for the whole backlog at every grooming. Scores inform priority; they never decide it alone.
- Outcomes compact into a hierarchical, cross-referenced form, never a growing flat list.
- Open, not yet built: partner members becoming more active, with their own log, where a shared project with another team is live.
- Open, not yet decided: the documentation steward proposing validated changes into other members' definitions, not only their docs.
