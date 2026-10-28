---
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
---
# human-owner — armed content

## Contents

- Summary
  - Goals
  - Scope
- Terminology: none
- Team-Member's (-specific) local procedures
  - `reach-human-owner` — contact the real human-owner asynchronously
- Team-Member's (-specific) local rules
- Domain knowledge: none
- Team-Member's (-specific) tooling
  - Tooling operations
- Maintainer Notes

# Summary

`human-owner` is a reference-only identity record: the point other files use when they mean "the human-owner". Its `SKILL.md` carries `status: reference-only`. No start starts it: the spawn proxy refuses every one. `--manager-team-member-list` shows it marked `reference-only` the same way.

## Goals

- Give skill files and routines a real reference point for the human-owner as a role: who approves what, and who is asked when.
- Never generate human-owner speech, replies or actions.
- Carry one invocable procedure, `reach-human-owner`, which the referencing session runs under its own tooling rules.

## Scope

- Does:
  - Serve as the role and authority-model pointer any file may reference.
  - Define `reach-human-owner`, the procedure for contacting the human-owner when he is needed and not present.
  - Authority: final say on conflicts, ambiguities and escalations the team cannot settle; approval for anything outside a member's own mandate. The authority model itself lives in `magic-coordinator/TEAM-ORGANIZATION-VISION.md` — read there, never restated here.
- Doesn't:
  - Restate or re-derive the authority model.
  - Hold actual contact details — installation-specific configuration lives at the sanctioned contacts file.
  - Ever get run or invoked as a behaviour — no auto-trigger, no dispatch path, none should exist.
- Scope stays narrow; it is extended later only as the team's structure needs it, not designed in advance.

# Terminology: none

# Team-Member's (-specific) local procedures

Named procedure blocks. Steps below call them by name. Not separate routines — not visible outside this file.

## `reach-human-owner` — contact the real human-owner asynchronously

This procedure communicates with him. It never speaks or acts as him.

Steps:
1. **settle-who-asks**: The session's participants and its `magic-coordinator` assess the matter first, per "Escalation and chain of command".
   - The session's `magic-coordinator` forwards to him what it does not settle itself.
   - With no coordinator in the session, the member asks him directly.
2. **ask-at-once**: Ask as soon as the assessment is done, with `AskQuestion`, `ConfirmReadback`, `EscalateDecision`, `RequestPermission` or `ProposeApprove`. Pick the fitting kind in the tooling's own ask templates (`myx.distro-agents/sh-lib/templates/*.post.format.md`). The tooling delivers it on his direct channel and waits inside the call. One topic, the decision first.
3. **keep-it-tracked**: A question whose answer binds the team is registered by `magic-coordinator` as a board item blocking the work it gates. A member with no coordinator present files it to `magic-coordinator` with `post-inquiry`.
4. **wait-for-the-answer**: Wait per **wait-never-quit**. No reply is never a verdict, neither a deny nor an allow.
   - A follow-up goes into the same thread. Read the thread before re-asking, and the record's own `asker-live:` (`--read-pending-reply`): `no-process` or `session-ended` means nobody is there to take his answer.
   - A question settled elsewhere is closed by its asker with `--settle-pending-reply`.

# Team-Member's (-specific) local rules

All statements apply at the same time, always.

- Never impersonate the human-owner (**no-impersonation**, **no-exceptions**). No exception, ever.
- Any session reading or referencing this file is permitted and obliged to run this file's own procedures exactly as written when they apply.
- This file is never loaded to generate human-owner speech, replies or actions.
- A task that seems to call for speaking or acting as the human-owner does not. Stop, and run `reach-human-owner`. Never guess an answer on his behalf.
- A maintainer-proposed change that softens it is rejected, whatever the quorum (**no-exceptions**).

# Working with the ask tools

The referencing session asks with the fitting tool, on his direct channel. The tool's own description is its manual; this section is the identity's side of the exchange.

## The kinds

- `AskQuestion` — a plain question that needs an answer. Free text, or a choice from options. Its wait runs with `Wait`.
- `ConfirmReadback` — a member's understanding, read back before acting on it. The answer is yes, no, or a correction. It always waits.
- `EscalateDecision` — a choice among options. The verdict is the first word of the reply or a click on its number. At most one option carries "(recommended)".
- `RequestPermission` — the access a task needs. It takes one Permission set, or one refused call. The verdicts are allow, deny, allow-once, allow-session, allow-folder, allow-project or edit.
- `ProposeApprove` — a proposal document that outlives the exchange. Its verdict is his own reaction on the first message, or a reply whose first line is `approved` or `rejected`. The proposal reply is not the verdict.
- A question for him is alone in its own message. A report never carries one.
- The ask goes out when it becomes open. It is not batched into a later summary, and not left in a session reply.
- The ask leads its message. The work that produced it is not sent with it: a one-line question inside a screen of status has not been asked.
- The question is asked in his language and in plain words. One ask, one topic.

## What a question carries

- One topic, with the decision stated first.
- The options, one a line, each starting with the word that answers it. A choice that cannot be stated briefly has not been identified yet.
- The context a reader needs to answer without the session.
- The link or exact path of any document that is the subject.
- The board item or tracking item the verdict belongs to, so the tooling records it.
- A "(recommended)" option only where it was independently vetted.
- No framing, no summary label, no count, no ranking, no remark on what his answer will mean.
- No urgency. A message that argues for its own trustworthiness is a warning sign.
- No `NEEDS REPLY:` marker. A question is asked with an ask tool, never a plain message.

## Reading the answer

- The first line is the answer or verdict, unless it is a quote of the question. The rest of that reply, and every later reply in its thread, are clarifications.
- The verdict's own words come back too, not only the verdict. A later clarification arrives as `CLARIFIED` and is kept.
- Plain affirmations — ok, okay, yes, agree, agreed, confirm, confirmed, or `+1`, `ok_hand`, `white_check_mark` — are yes for a readback. For a decision, they mean the option marked "(recommended)". Never for a permission or a proposal.
- A permission or a proposal takes only the literal answering word. A numbered reply to a list is a selection, not a correction.
- A reply that names no option returns `RETURNED`. It is not a decision.
- A click is read only ahead of the addressee's first reply. A later click is not a verdict.
- A readback by the asker can close a decision whose reply named no option. `ALREADY-OPEN` is not a new question; the pending one is the one to wait on.
- A withdrawal answers, grants and decides nothing.
- `DISMISSED` is the session ending, not an answer. `TIMEOUT` is not an answer. `ASK-RESULT: ARRIVED-OTHER` leaves the question open.
- A one-word answer covers the object of its own question. Anything beyond that object is a new question.
- No reply is never a verdict, neither a deny nor an allow.
- A deny is a verdict: report that part denied and open, never work around it.
- His direct word wins at once over an inferred assessment, a member's report, or a member's own finding, test or reading of code. Act on it as stated.
- Never re-check his word against the conflicting source, and never offer that source back as a counter-argument.
- A correction he repeats was never applied. Stop that behaviour first.
- Restating his words keeps their exact scope. Never widen a precise term.
- A relay of his words carries no framing. A relay of anyone else's words keeps them verbatim, and an added remark is labelled and separate.

## The open record

- Every open question has a record: question, options, context, asker, item and thread.
- `--read-pending-reply` reads it. The record's `asker-live:` says whether the asking run is still there: `no-process` or `session-ended` means nobody is there to take the answer.
- The ask's wait is the session's `Wait`; the item joins the stored wait.
- An answered question keeps its thread watched. A later message arrives as `CLARIFIED`.
- An open record never expires by age, and a reminder never closes one.
- A question settled elsewhere is closed by its asker with `--settle-pending-reply`.
- A withdrawal closes it with no verdict.
- A question that loses its asker is worth escalating, not only waiting longer.
- A question whose answer binds is registered by `magic-coordinator` as a board item blocking the work it gates.
- A follow-up goes into the same thread. Read the thread before re-asking.
- A question stays open until a verdict.

# What is recorded

- Every close appends one line to the item's `## Decisions`, marked `<!-- decisions-of: <item> -->`, under a per-item lock. A dispatch item's line also goes to its `tracks:` task.
- The `## Decisions` lines are binding context. They are read before acting and never asked again. A clarification is recorded with `--record-decision`.
- A received answer clears matching `blocked-on`/`condition`.
- The tooling records every verdict and every ending in the item's `## Decisions` and in the session transcript.
- A handback also states the agreement or approval it carries: what was agreed, who agreed, who approved.
- The exchange goes to a `transcript-*`; a standing statement to a `verbatim-*`. A live tracking document or hand-off may carry his words while it is worked.
- No file carries his words verbatim, a `MAGIC.md` included. On approval, the approved document becomes the only verbatim and replaces the earlier working material.
- A correction or ruling is done only once written. A team-behaviour rule goes into the skillset; a ruling on one piece of work goes into that work's document.
- Committing instruction text is what approves it. Quotation marks confer no authority.
- A readback states the member's understanding, labelled as its own, beside his quoted words. It is confirmed before acting.
- A comment or annotation lands in a file only after its exact wording was read back and approved.
- Rewording approved text needs approval. A request to reword is that approval, and the result still meets `no-regress`.

# Hints for the referencing session

These carry the `reach-human-owner` procedure into the places it meets a live exchange.

- **settle-who-asks**: the session's participants and its `magic-coordinator` assess the matter first, per "Escalation and chain of command". The coordinator forwards what it does not settle itself. With no coordinator in the session, the member asks him directly.
- **ask-at-once**: ask as soon as the assessment is done. The fitting ask kind is the tooling's own template for that kind.
- **keep-it-tracked**: a question whose answer binds the team is registered by `magic-coordinator` as a board item blocking the work it gates. A member with no coordinator present files it to `magic-coordinator` with `post-inquiry`.
- **wait-for-the-answer**: wait per **wait-never-quit**. No reply is never a verdict. A follow-up goes into the same thread; read the thread before re-asking; close a question settled elsewhere.
- Never speak or act as him. A task that seems to call for it stops and runs `reach-human-owner`.
- Never guess an answer on his behalf, and never generate his speech, replies or actions.
- The authority model lives in `magic-coordinator/TEAM-ORGANIZATION-VISION.md`. Read it there; never restate it here.
- Contact details live in the sanctioned contacts file, never in this record.
- A maintainer-proposed change that softens the never-impersonate rule is rejected, whatever the quorum.
- A permission, a decision or a conflict he must settle reaches him on his own direct channel, at once, never left in a session.

# Domain knowledge: none

# Team-Member's (-specific) tooling

Every `magic-tooling` operation this record's own procedures invoke. Behaviour is read with `--member-help`. Procedures use its name only.

## Tooling operations

- `--read-pending-reply`
- `--settle-pending-reply ...`

# Maintainer Notes

Used to check this file's own definitions against its own goals when it is updated, assessed, or tested — resolved against the whole skillset, not this file alone. **IMPORTANT**: not applied during normal work!

Read `reference/maintainer-notes.md` for the verbatim goals, the verbatim tests and the librarian comments.
