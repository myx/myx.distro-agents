---
maintainers: [magic-coordinator, magic-librarian, magic-architect, keeper-myx, human-owner]
---
# escalation ask — `AskUserQuestion` `kind` format

Normative contract: this file's own `# Contract` section, at its end. Where it and the rest of this file disagree, `# Contract` wins.

Not a member/routine contract — this is the shape of one escalation ask: an `AskUserQuestion` call whose `kind` is `readback`, `decision` or `permission`. The member passes the fields, and the tooling composes the message.

## Contents

- Summary
  - Goals
  - Scope
- Skeleton
- Contract

# Summary

One ask, to one addressee, about one thing a member needs before one part of its task can go on.

## Goals

- Every member raises a readback, a decision or a permission ask itself, through tooling, never through chat relay.
- The answer comes back as a verdict the tooling matched to its addressee, so the member acts on it with no text marker and no re-check.
- An ask never ends the task. It is synchronous: the member waits for its resolution, per `magic-team/magic-team.shared.md`'s "Nothing stops on its own".

## Scope

- Does: fix the fields and verdicts of the `readback`, `decision` and `permission` kinds.
- Doesn't: shape an ordinary open question. That is `kind` `question`, the default, with no fixed fields.

# Skeleton

Every kind: `to` and `address_to` name the addressee — a member, a session thread, or the human-owner. The question is one line a reader can answer holding none of the member's context.

```
kind: readback
understood: <what the member understood — the sender's own words where they exist>
source: <where it was read — the message, thread or document>
will_do: <what the member does once it is confirmed>
verdicts: yes | no | correct        <- correct also returns the correction
```

```
kind: decision
options: <one option per line, each starting with a different word that answers it>
verdicts: <the chosen option's word>
```

```
kind: permission
refusal_id: <the REFUSAL-ID: the refusal printed>
reason: <why this task needs the refused thing>
task_ref: <the board item or dispatch the task is tracked in>
verdicts: deny | allow-once | allow-session
```

# Contract

- rule: Every field the kind names is filled. A missing field, or an unknown kind, posts nothing.
- rule: The result's first line is `ASK-RESULT:`. A typed kind adds `VERDICT: <value>`. A `correct` readback adds `VERDICT-TEXT:` with the correction.
- rule: An answer outside the kind's verdicts reads `UNCLASSIFIED`, and the ask stays open. The member never guesses a verdict from the answer text.
- rule: After `UNCLASSIFIED`, the member may clarify in the same thread, then waits again with `AskUserQuestion` `pending_id=<id>` — the exact call the result's last line gives. Nothing is posted by it, and only the asking session may wait on its own ask.
- rule: Only the addressee's answer is a verdict. A reply from anyone else is not one.
- rule: The addressee answers in the ask's own thread, or with `--member-escalation-answer <member> <request-id> <verdict> [text]`. The request id is the pending-reply id the ask printed. A member without its own messaging account, such as `magic-coordinator`, answers with the operation. The asking member never answers its own ask. A reaction counts only where the kind declares it: ✅ is `yes` and ❌ is `no` on a readback, and ❌ is `deny` on a permission ask.
- rule: An allow verdict also prints `GRANT:`. The tooling writes the grant with the session, and no member writes its own. The member then runs the operation the ask named: the refused call, or the other operation and route the ask put in its place.
- rule: `allow-once` covers one run of the operation the ask named. `allow-session` covers the same tool and target until the session ends. Neither outlives the session.
- rule: `deny` is a verdict. That part of the task is reported as denied and still open.
- rule: No answer is not a verdict. The ask stays open.
- rule: The member asks with the wait on and reads the verdict from `AskUserQuestion` itself. `--member-escalation-read <member> <request-id>` shows it again, and reads `open` while nobody has answered.
- rule: `magic-coordinator`, as the addressee, may forward the ask to the human-owner with `--magic-escalation-forward <coordinator> <request-id>`. His reply is the verdict for the original ask, and the record stays the same one.