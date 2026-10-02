---
executors: magic-coordinator
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
invitees: human-owner
---
# magic-coordinator.coordination-session.routine — the actual procedure

# Summary

Routine-coordination-session is the operating cycle for a `coordination-session` instance: any
`magic-coordinator` instance, root or spawned, running the busy-loop that drives comms-sweep,
board-advance, and the session's own goal.

## Goals

- Give any `magic-coordinator` instance, root or spawned, one routine to execute once it is in
  `coordination-session` mode.
- Keep the cycle driving comms-sweep, board-advance, and the session's own goal, with a shared loop-body
  rule that applies before every step.

## Scope

- Does:
  - Execute on any `magic-coordinator` instance, root or spawned — not root-only.
  - May run with explicitly reduced scope (set by the human-owner, or proposed by `magic-coordinator` and
    agreed) — routines still consider all jobs but only execute ones within the session's scope.
- Doesn't:
  - Select the operating mode itself. `magic-coordinator.root-harness.routine`'s own
    **select-operating-mode** step, or an equivalent mode-selection step in whatever routine spawned this
    session, makes that choice and then executes this routine.
  - Cover `armed-mode`. `armed-mode` has no cycle — it stays defined where the spawning routine's own
    mode-selection step defines it.

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step
cannot execute as written: escalate it, and never skip it silently.

1. **sweep-comms**: run `magic-coordinator.communication-sweep.routine`
2. **advance-on-update**: new update found → run `magic-coordinator.advance.routine` now
3. **drive-session-goal**: keep driving the session's own goal (dispatch, follow-through, real file
   changes)
4. **narrow-goal-gap**: ask small, minimal-assumption questions to narrow the goal gap — when resuming a
   tracked interview, this is `magic-team.interview.routine`'s own **resume-review**, run as part of this
   step
5. **pause-between-cycles**: `sleep 5`
6. **repeat-from-sweep**: repeat from **sweep-comms**
7. **conclude-or-ask-input**: goal gap empty → say so, ask for new input, or close by executing
   `magic-team.coworking.routine`'s Closure Steps

# Closure steps

Step 7 (**conclude-or-ask-input**) is this routine's own closing step: it closes by executing
`magic-team.coworking.routine`'s Closure Steps once the goal gap is empty. No separate closure steps of
this routine's own.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this
file.

None currently defined.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md`
rules while this routine is active.

- This routine's own executor is permitted and obliged to execute every step exactly as written.
- Participants obey this routine's own rules over their normal `.armed.md` rules while participating.
- "The heartbeat loop is not an operating mode. The host loop runs it, one
  `magic-coordinator.heartbeat.routine` `next-iteration` per cycle. No member calls it, and no session
  starts, relays into, or stops it. Whether a pass is live is read with `--magic-heartbeat-lock-status`."
- rule: "Shared loop-body rule for `coordination-session`: before **every** step of the cycle — not only
  once per iteration, not only bracketing the sleep — check for incoming console/Slack messages and
  messages from sub-spawned sessions; for each one found: **think** (assess what it needs), **spawn**
  (dispatch a sub-session for any real work identified), **relay** (pass the sub-session's result, or a
  direct status/question, back to the human). Ending your own turn to wait for a notification is always
  fatal — nothing is left alive to receive it. The only real wait is a blocking call that keeps the turn
  open."
- rule: "`coordination-session` never does substantive work inline in the root loop — every real
  edit/investigation/fix is dispatched to a sub-spawned session, which relays its result back to the root,
  which relays outward to the human."
- rule: "**Default-to-spawn-out for already-approved work**: once `magic-coordinator` (harness-session or
  `coordination-session`) deems a task already approved/confirmed/explicitly-allowed, it defaults to
  spawning it out as a separate co-working session (long- or short-lived, with `magic-coordinator` and/or
  other members, its own goal) rather than executing it inline in its own continuing context. This is the
  concrete default-first move, not a fallback reached only after inline execution was already attempted."
- rule: "**Reload trigger for `coordination-session`**: every 20 completed cycles, or immediately once any
  of this session's own loaded skill files (`magic-coordinator.armed.md`,
  `magic-coordinator.coordination-session.routine`, `magic-team/magic-team.armed.md`, and any
  `.routine.md` file this cycle is about to execute) shows a newer mtime than when this session last
  loaded it, whichever comes first, re-run `Skill(magic-coordinator)` fresh. Reload happens at the top of
  the next **sweep-comms** step, never mid-step. Track both the cycle counter and each watched file's
  last-loaded mtime as session-local state, reset both the moment a reload completes."
- "The reload itself is a fresh `Skill(magic-coordinator)` re-invocation, never a partial re-read of
  individual files — a partial re-read would leave a stale mix of refreshed and carried-over sections."
- rule: "**This does not generalize to plain one-shot `armed-mode`.** It has no cycle to count against. A
  one-shot session running long enough to need drift-correction should have been split into a fresh
  session instead of given its own reload cadence — see `magic-team/magic-team.armed.md`'s 'one spawned
  session holds one line of work' rule and `magic-coordinator.armed.md`'s own 'reuse an already-open
  member session' rule."
- "A `coordination-session` instance already holds its own independent Slack channel to the human-owner
  (via `DistroAgentsTools.fn.sh`) — when an unverifiable relayed message needs resolving, it uses that
  channel directly; it does not spawn or invite a separate armed `magic-coordinator` instance to do so on
  its behalf."
- "'Main-loop is stopped' — the host loop not running — is a diagnostic fact useful for
  explaining/detecting why nothing is auto-advancing — it is not itself the operating instruction. The
  real instruction for how to operate is `coordination-session`'s own cycle above."
- "A visibly-stalled spawned session: re-pinging it, or restarting it when there's real reason to believe
  prior work is safely preserved and the restart won't redo/duplicate/lose anything, is routine
  coordinator judgment — not something to ask permission for. Escalate only if the stall itself reveals
  something genuinely ambiguous (trustworthiness of prior output, real duplicated-side-effect risk)."

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Full syntax and behavior here. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--magic-heartbeat-lock-status` (heartbeat-is-not-a-mode note, Local rules)

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested —
resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- `coordination-session` never does substantive work inline — every real edit, investigation, or fix is
  dispatched to a sub-spawned session.
- The reload trigger keeps a long-running `coordination-session` instance's loaded skill files from
  silently drifting from what is actually on disk.

## Verbatim-tests (benchmarks)

- A `coordination-session` instance ends its own turn to wait for a notification with nothing left alive
  to receive it. That is always fatal, never a valid wait.
- One of this session's own watched skill files shows a newer mtime mid-cycle. The reload waits for the
  next **sweep-comms** step rather than firing mid-step.

## Librarian Comments

### Reference

- `magic-coordinator.root-harness.routine` — Step 3 (**select-operating-mode**) chooses
  `coordination-session`, then Step 13 there executes this routine. This routine does not select its own
  mode.
- `magic-coordinator.armed.md`'s former "Operating modes" section — the source this routine's content is
  moved from, per the human-owner's Q59 ruling.
- `magic-coordinator.heartbeat.routine` — the separate host-loop pass the heartbeat-is-not-a-mode note
  distinguishes this cycle from.

### Conventions

- Built under the rule "move text, never redefine it."
- One wording fix made for the same reason as the reload trigger's own watched-file list above: "this
  file's own 'reuse an already-open member session' rule" became "`magic-coordinator.armed.md`'s own
  'reuse an already-open member session' rule," since that rule still lives in armed.md, a different file
  from this one now.
- One residual term not changed: "`coordination-session` never does substantive work inline in the root
  loop" still says "the root loop," unchanged from its source, even though this routine now also executes
  on a spawned instance. Flagged in the Phase 2 report, not fixed here, since the instruction was wording
  unchanged.
