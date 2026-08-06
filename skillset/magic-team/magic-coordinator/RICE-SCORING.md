# RICE-style scoring

A shared scoring convention for ranking backlog/todo/proposal items — used by `routine-grooming`'s cross-member reprioritization step, and by any member (`magic-architect`, `magic-coordinator`, or others) scoring an item on their own. Human-owner's own framing, stated directly: "RICE scores to be adjusted in each grooming for all pending, planned and active tasks and projects... All marks to be normalised among tasks we have - from 0 to 1 - profit, cost, time, dependencies."

## Four normalized dimensions, not one opaque ratio

Every scored item carries four numbers, each **0 to 1, normalized against the current full set of pending/planned/active tasks and projects** — not an absolute/arbitrary unit, and not fixed once and forgotten: the same item's numbers can shift across groomings purely because the *backlog around it* changed, even if nothing about the item itself did.

- **Profit** (0 = least valuable item in the current backlog, 1 = most valuable) — direct positive effect, how much it improves the current shape of things, confidence it won't introduce regressions.
- **Cost** (0 = cheapest item to actually implement, 1 = most costly) — complexity (systems/patterns touched, not just lines of code), the real amount of implementation+testing work.
- **Time** (0 = fastest to complete, 1 = longest) — deliberately distinct from Cost: something can be low-effort but calendar-slow (waiting on an external party, a long test cycle), or high-effort but fast (a big but mechanical batch edit). Conflating the two loses real signal.
- **Dependencies** (0 = fully ready, nothing blocking it, 1 = heavily blocked/many prerequisites) — a numeric companion to the item's actual board state (`board-blocked`/`board-parked`/etc.), not a replacement for it; two `board-blocked` items aren't equally blocked, this is what expresses the difference.

**Normalization is relative, done together, not per-item in isolation**: when re-scoring at grooming, rank the current backlog on each dimension and space the 0-1 values across that ranking (min-max or percentile, either is fine — consistency across one grooming pass matters more than the exact method), not each item scored against an imagined absolute scale that drifts session to session.

## Combining into one priority number (optional, for sorting convenience)

```
Priority = Profit / (Cost + Time + Dependencies)
```

Value over effort, built from the four normalized components above. This number is a sorting convenience, not the primary artifact — the four dimensions themselves are what actually gets recorded and discussed; per "Scores inform, they don't decide alone" below, a single collapsed number is even more prone to hiding the real tradeoff than the four-dimension breakdown is.

## Multiple scores per item, not one

An item can carry more than one score at once:
- **Official scores** — from `magic-architect` (architecture-level judgment: complexity, blast radius, systems touched) and `magic-coordinator` (cross-team view: sequencing, dependencies, whether it's actually ready).
- **Personal/local scores** — any other team member can attach their own view of an item that concerns their domain, without it needing to become "official." Disagreement between a personal score and the official one is itself useful signal for grooming to discuss, not something to silently average away.

Record scores directly on the item's own file under the board (whichever state folder it currently sits in), tagged by who gave the score — the board is the live backlog, and is where scores actually get recorded.

## When scores get set or updated

- **At `routine-grooming`**, for **every** pending/planned/active task and project, not just newly-triaged items — since normalization is relative to the whole current backlog, a re-score pass has to cover the whole current backlog each time, not just what's new since last time; an item nobody touched can still have moved on the 0-1 scale purely because other items shifted around it. See `routine-grooming`'s own step 3 (full-backlog RICE re-score) for the mechanics. Sorting by score isn't the whole of reprioritization, though — `routine-grooming`'s own step 4 (the coordinator's important-vs-eager distinction) and blocker/dependency surfacing still apply on top; a high score doesn't jump a queue if something else blocks it.
- **By `magic-architect`, as its `grooming-scores-review` idle-activity** (`idle-tasks/grooming-scores.idle.md`) — reviewing backlog items and updating/refining scores thoughtfully, consulting other skills and current context, since a score set weeks ago may no longer reflect what's actually true now. This is a *scoring* pass, not a full grooming triage — it doesn't reassign, split, or drop items, it only refines the numbers grooming will act on next.
- **Ad hoc**, by any member, whenever they have an informed view worth attaching — doesn't need to wait for a scheduled grooming.

## Scores inform, they don't decide alone

Per the team's own "no unilateral epics" guardrail (`magic-coordinator.heartbeat.routine.md`, `magic-coordinator.communication-sweep.routine.md`) and `routine-grooming`'s own step 5 ("Review with the user"): the reprioritized, scored backlog is still reviewed *with the user* before anything is considered final. A score is an input to that conversation, not a substitute for it.