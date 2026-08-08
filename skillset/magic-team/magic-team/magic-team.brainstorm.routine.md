---
executors: magic-team
maintainers: magic-coordinator, magic-librarian, magic-architect
---
# routine-brainstorm — the actual procedure

# Summary

Routine-brainstorm is a lower-stakes space for generating ideas, including "crazy" ones, without pressure to converge or capture one settled vision.

## Goals

Give the team a genuinely lighter-weight, lower-stakes place to throw out ideas — deliberately including "crazy" ones — for everyone to assess a bit, without the pressure of either reaching a real decision (`routine-discuss`) or precisely capturing one party's settled vision (`routine-interview`). This exists because idea generation and decision-making are different modes with different failure risks: forcing convergence during brainstorming kills the "crazy idea that turns out good" case; treating a brainstorm's output as already-decided risks building something nobody actually agreed to. Naming history: an earlier draft used "discuss" for this idea-generation shape before the human-owner reinstated a separate, real `routine-discuss` for convergence and renamed this one `routine-brainstorm`.

## Scope

Does: idea generation and assessment, deliberately including "crazy" ideas. Run by any member (`magic-team`) — internal, low-stakes, no special credential/mandate dependency.
Doesn't do: reach a decision (`routine-discuss`'s job), capture one party's settled vision (`routine-interview`'s job), deep feasibility review (light assessment only).

# Steps

Exact instructions. Execute in order, every step, literally as written — not less, not more. If a step cannot execute as written: escalate, or fail loud.

0a. **process-own-inbox**: run `routine-process-inbox <executor>` — inline execution (own identity). `idea-*`/`note-*` notes parked there from earlier sessions, so this brainstorm generates from them rather than re-inventing them. Not automatic just because this routine spawned — this explicit call is what actually guarantees it happens.
1. **set-topic-loosely**: state the area being brainstormed, but keep it open — a brainstorm with an overly narrow framing risks just being a discussion in disguise. **Any example given when the topic is set is a floor, not a ceiling** — a starting minimum to extend from, never a closed boundary on what counts, unless an explicit ceiling was stated (a hard number, an explicit "no more than X").
2. **generate-without-filtering**: throw out ideas, including ones that sound impractical or unlikely — the point is coverage and provocation, not immediate quality control. Explicitly welcome "crazy" ideas; don't let the first reasonable-sounding idea anchor and shut down further generation.
3. **assess-lightly**: after ideas are out, everyone gives each a quick, light read (promising / interesting-but-needs-work / probably not, and why) — not a full feasibility analysis. This is "assess a bit," deliberately not the deep investigation a real proposal would get.
4. **allow-no-winner**: a brainstorm session can end with several live candidate ideas and no chosen winner — that's a normal, valid outcome, not an incomplete session. If something does clearly stand out, that's a bonus, not the goal.
5. **hand-off-promising-ideas**: anything that got a genuinely promising light-assessment gets filed (an `idea-*`/`note-*` board item, or folded into an existing inquiry/task it relates to) for later real evaluation — via `routine-discuss` (if it needs a real decision) or the normal staged task-creation lifecycle (if it's heading toward being built) — not decided or built directly out of the brainstorm itself.
6. **gate-filing-on-confirmation**: filing follows the same gate as dispatch — propose the item (piece, type, goal) and wait for confirmation before writing it, unless the human-owner explicitly asked for that specific filing.

# Closure steps

This routine has no distinct closing phase of its own — it ends once step 6's filing gate is satisfied; not a coworking-like session per `routine-session-start`'s taxonomy, so no `routine-close-session` call applies.

# Routine's local procedures

Named procedure blocks, called by name from `# Steps`. Not separate routines — not visible outside this file.

None currently defined.

# Routine's local rules

All statements apply at the same time, always. These rules override a participant's own general `.armed.md` rules while working in this routine.

- Whichever `magic-team` member executes this routine is permitted and obliged to execute every step exactly as written, in order.
- Every participant follows this routine's own rules over their normal `.armed.md` rules while this routine is active.
- Conversation mechanics (message shape, reaction meaning, confirming corrections before acting) always apply, in any context.
- Manual only — anyone asks to "brainstorm" a topic. No autonomous or scheduled trigger.
- Never treated as a decision by itself. A promising idea still needs `routine-discuss` (or the staged task-creation lifecycle) before it becomes real work — no matter how good it sounded in the moment.
- Not a substitute for `routine-interview` when the actual goal is precisely capturing one party's already-formed vision — brainstorming is generative, not a collection exercise.
- Light assessment only (step 3) — resist turning a brainstorm into a deep feasibility review mid-session.
- An idea sounds clearly bad early on: let it stand without heavy pushback during generation — filtering happens at the light-assessment step, not during generation itself.
- One idea starts dominating the conversation and steering it toward a decision: gently redirect back to generation if there's more ground to cover, or explicitly name that the session has organically shifted into `routine-discuss` territory.
- Nothing from the session looks genuinely promising: a legitimate, valid outcome — never manufacture a forced "winner" just to have something to file.
- Unsure whether a promising idea needs `routine-discuss` or can go straight into the task-creation lifecycle: default to `routine-discuss` first if there's genuine ambiguity or tradeoffs; skip straight to task-creation only if the idea is already clear-cut enough that a discussion would just rubber-stamp it.
- Goal-directedness: when a goal is set for this session, actively work toward it (genuinely covering the loosely-set topic, not drifting off it entirely); non-goal-directed items that surface mid-session get quickly recorded, not acted on now.
- When `magic-coordinator` is the executor/convener, it is obligated to keep `slack-event-track` activity tracking current as the brainstorm actually runs — not only via whatever gets filed at step 5.
- Changes to this routine's own definition need `quorum-all-agree` (`magic-coordinator`, `magic-librarian`, `magic-architect`) — no single maintainer may edit it alone.
- `# Steps`/`# Closure steps` sequencing follows `magic-team.shared.md`'s own rule — see there for the full statement.

# Routine-specific tooling

Every `magic-tooling` operation this routine uses. Full syntax and behavior here. Steps use its name only.

## DistroAgentsTools magic-tooling operations

- `--member-slack-send-message <team-member> <target> [text...]` (Slack activity-tracking obligation, per `Routine's local rules`)

## `--member-slack-send-message` operation reference

`DistroAgentsTools.fn.sh --member-slack-send-message <team-member> <magic-team|human-owner|event-track|event-alert|<channel>:<ts>> [text...]` — posts a message to Slack via `chat.postMessage`, attributed to `<team-member>` (a bare directory name that must already exist as a real team member).

# Maintainer Notes

Used to check this files own definitions against its own goals when this file's update is being updated, assessed, or tested. **IMPORTANT**: not applied during normal work!

## Verbatim-goals (intents)

- This routine gives the team a lower-stakes place to throw out ideas, including "crazy" ones, without the pressure of reaching a decision or precisely capturing one party's settled vision.

## Verbatim-tests (benchmarks)

- A brainstorm session ending with several live candidate ideas and no chosen winner is a normal, valid outcome, not an incomplete session.

## Librarian Comments

### Reference

- `routine-discuss` — convergence/decision-oriented follow-on for a promising idea.
- `routine-interview` — precise collection, distinct purpose from this routine's generative one.
- `routine-process-inbox` — own-inbox processing.
- `magic-team/magic-team.armed.md`'s "Team-Member's (-specific) tooling" section — Keep-Alive Workspace Console Session mechanics, calling convention, sole-sanctioned Slack-posting mechanism.
- `magic-team/magic-team.basic.md` — the propose-and-wait-for-confirmation filing gate step 6 reuses.
- `magic-team/magic-team.conversations.md` — conversation mechanics (message shape, reaction meaning, confirming corrections before acting) this routine's Local rules point to.

### Conventions

None currently known beyond this file's own Local rules.
