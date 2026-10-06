---
maintainers: magic-librarian, magic-coordinator, magic-architect, human-owner
---
# Negotiation mechanics

Managing several open topics across a multi-round exchange. The shared base for interview-like and convergence routines; `magic-team.conversations.md` governs single messages. A consuming routine states that it inherits this file and names any override (for example, next-question mode only).

## Contents

- Topics and questions
- Topic surfacing
- Gap surfacing
- Queue and ordering
- Presentation modes
- Topic persistence and closure
- Check-restart procedure

## Topics and questions

- A **topic** is a queued unit of work, from one question to a long multi-round rework. It carries priority.
- A **question** is the one single-topic ask put to the other party now: the topic itself, or one open piece of it. Several options for one decision may go together; distinct asks never do.

## Topic surfacing

A topic outside the current scope is never silently absorbed or dropped. Ask the human-owner: extend the scope, or file it as its own item.

## Gap surfacing

Any gap in understanding, of any size, becomes a question asked before any edit or dispatch. Investigate facts; ask about intent, which investigation cannot answer. A request to reformulate leaves the substance open until it is asked.

## Queue and ordering

Open topics form a queue, re-sorted each round: quick-to-close and urgent topics first. A topic is presented as a short, understandable gist, never a bare label.

## Presentation modes

- **Next-question mode** — show only the next question.
- **Topics-to-choose mode** — show the sorted open topics and let the other party pick one by number.

## Topic persistence and closure

- A topic stays current across rounds until resolved; applied output alone does not close it.
- A partly settled topic records its settled parts and is restated as the remaining gaps.
- When a question closes, reassess the topic for gaps, state them or "none", and ask whether to keep it open, close it, or switch to another queued topic.
- Work on negotiated data happens at the next step, in the current context.

## Check-restart procedure

After inactivity or interruption, resume per `magic-team.conversations.md`'s **dormancy-nudge-once-then-escalate**, measured from the other party's last activity. It ends in exactly one state: `running`, `finished` or `blocked`.
