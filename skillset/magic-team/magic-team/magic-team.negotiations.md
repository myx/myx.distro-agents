---
maintainers: magic-librarian, magic-coordinator, magic-architect
---
# Negotiation mechanics

Cross-routine mechanics for handling more than one open topic across a multi-round exchange working toward
resolution — collection, convergence, or otherwise. Distinct from `magic-team.conversations.md`, which
governs single-exchange message/reaction/correction form; this file governs topic/queue management across
many exchanges. Shared base for any interview-like or convergence-oriented routine.

Referenced from: `magic-team.interview.routine`, `magic-team.discuss.routine`, `magic-coordinator/magic-coordinator.harness.md`'s inline
interview-like mode, and any future routine handling multiple open topics.

Owner: `magic-librarian`.
Maintainers (`quorum-all-agree`): `magic-coordinator` + `magic-librarian` + `magic-architect`.

## Topics and questions

- A **topic** is a queue-level unit of work: it ranges from one simple question to a long, multi-round
  process (a refactor, a multi-file rework) with many corrections and a long approval chain. Topics carry
  priority/urgency.
- A **question** is the atomic single-topic ask actually put to the other party right now. It's either the
  current topic itself (when the topic is atomic) or one still-unresolved piece of it (when the topic is
  complex) — which applies depends on the topic's own nature and content, not a fixed rule.

## Topic surfacing

- A task/topic surfacing mid-conversation, outside the current conversation's own stated scope/goal, is
  never silently absorbed into current scope and never silently dropped — propose a choice to the
  human-owner:
  - extend the current goal/scope explicitly to include it, or
  - record it as a separate board-item (inquiry/reflection, as fits) on its own track, to be picked up
    later.
- Never assume inclusion, never silently defer.
- Distinct from `magic-team.conversations.md`'s **extending-approval-needs-confirm** (propose-confirm to stretch an *already-approved
  decision's* own reach beyond its case): here the topic itself is new, not yet part of any approved
  decision.

## Gap surfacing

- Any gap in understanding becomes a question, at any size. A small factual gap — what a term actually
  means, what a state's real defining property is — enters the queue exactly like a large design question,
  and closes the same way: by asking directly, before any edit or dispatch.
- No size threshold exempts a gap from being asked — guessing at a small point and letting a rejection
  correct it is the same failure as guessing at a large one, not a cheaper shortcut.
- If the gap is what the human-owner wants: ask. Investigation can never answer that, no matter how
  thorough. Investigate only facts (what a file says, what a command does) — never intent.
- A request to reformulate or improve something, as opposed to apply an already-specified fix, leaves the
  substance itself open: establish the actual defining facts by asking, then draft the wording.
- Distinct from Topic surfacing above: there a new topic enters the queue from outside current scope; here
  the gap sits inside the current topic and becomes a question on it.
- Distinct from `magic-team.conversations.md`'s **readback-on-suspected-assumption-gap**/**self-discovered-ambiguity-still-a-gap** (an unclear or ambiguous point, received or
  self-discovered): here nothing ambiguous exists — the fact was simply never established, and asking is
  what establishes it.

**intent:** `no gap size makes guessing cheaper than asking — understanding is established before
work, not corrected after it`.

## Queue and ordering

- Multiple topics may be open at once, held as an undifferentiated queue — never a fixed numbered list
  ("item #7"). Reassess and re-sort the queue before presenting it each round.
- Priority: a simple/short topic with a high chance of quick approval or resolution goes ahead of a long
  one; so does an important/urgent topic, or one relevant to an important/urgent topic; so does any topic
  with a real chance of closing sooner.

Presenting a topic (queued or current) must let the other party actually understand what it is, not just
recognize its label. That understanding comes from context, substance, wording, and fit to the matter
together — never satisfied by any one alone (not just length, not just a name, not just careful phrasing,
not just having recently talked about it). State it as a comprehensible gist — short, but genuinely
understandable — never a bare label, and never a full essay either.

## Presentation modes

- **Next-question mode**: show only the single next question.
- **Topics-to-choose mode**: present a sorted list of multiple open topics (optionally including the
  current unresolved question), and let the other party pick one by number to focus on next.

Which mode applies, and whether a consumer supports one or both, is stated by the consuming routine/file —
not every consumer needs both.

## Question atomicity

Keep each question single-topic — never bundle distinct asks into one message — so a bare `yes`/`go` reply
is itself sufficient and unambiguous. Exception: several options for the same single decision (a
multiple-choice on one question) are not "several distinct asks" and may be presented together.

## Topic persistence across rounds

A topic can receive applied changes across several rounds while remaining the current topic — producing
real, applied output doesn't by itself mean the topic is done. Only dispatch/compact it once genuinely
resolved.

A partially-resolved topic keeps its settled parts recorded as settled, while the topic itself persists,
reformulated to the remaining gaps only — never removed entirely while genuine work remains, and never left
overstated as fully settled when a gap exists. Reassess remainder of the topic and possible new gaps. Confirm acceptance of closure of empty topic.

## Check-restart procedure

Resume processing in an iterational conversation after a period of inactivity or an unexpected
interruption. Inherits `magic-team.conversations.md`'s **dormancy-nudge-once-then-escalate** for the actual dormancy/nudge/escalate
mechanics (measured from the other party's last real activity, not the routine's own bookkeeping). Always
concludes by returning exactly one of three states: `running` (nudged or still genuinely active),
`finished` (the topic's own goal actually concluded), or `blocked` (something external prevents
continuation).

## Topic closure

When the current question on a topic closes, the topic isn't automatically closed with it — reassess the
topic itself for remaining gaps first, even when it looks complete. State the topic's own description,
then state any gaps found, or explicitly state none found. Ask whether to add the gap to the topic (keep
it open) or close the topic — this ask may also present the other queued topics as options to switch to
next, not only the binary add/close choice.

**intent:** `work on collected/negotiated data happens at the next step, using current context — not
deferred or batched separately`.

## Inheritance

A consuming routine/file states explicitly that it inherits this file's mechanics, and names any override
distinctly (e.g. restricted to next-question mode only, or skipping team-board persistence in favor of the
current session's own context).
