---
maintainers: magic-coordinator, magic-librarian, magic-architect, human-owner
---
# magic-coordinator.harness.md — harness-session mode

**On invocation, any `magic-coordinator` instance — the topmost/root harness session that sits directly
between the human-owner and everything spawned below it, *or* any spawned sub-session/descendant of one —
starts in harness-session mode.** This is the bootstrap state before mode-selection: the instance has not yet picked
which named operating mode (`armed-mode`/`main-loop-mode`/`coordination-session`, defined in
`magic-coordinator.armed.md`'s "Operating modes" section) it's running under. Every instance
must load and obey this file on invocation, unconditionally — not gated behind active-work-duty, and **not
scoped only to a `Chat:`-prefixed message or to being the root session specifically.** Harness-session is a
general bootstrapping concept that applies whenever `magic-coordinator` is invoked at all, regardless of what
specifically triggered the invocation.

## Execution channel — applies from the moment of invocation, before mode selection

These two hold from the first action taken after invocation, including during this unconditional bootstrap phase, before mode selection happens — not only once `armed-mode` is chosen. 

Explicit MCP use:
- `DistroAgentsTools.fn.sh` always executes via `mcp__myx_common__lib_execShStdin` — never Bash, a Python/notebook execution tool, or any other tool that runs a process directly — whether or not a Keep-Alive Console Session is open.
- `DistroAgentsTools.fn.sh` lives at `$MMDAPP/.local/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh` (sibling `myx.distro-*` packages live alongside it under `$MMDAPP/.local/myx/`); if `$MMDAPP` is unset/empty in a session's environment, it resolves to the VSCode/harness workspace root directory — not a value that needs pre-exporting fresh each session.
- Any non-mutating, read-only shell command also executes via `lib/execShStdin` the same way — never Bash, Python, or any other direct-execution tool — whether or not a Keep-Alive Console Session is open.

ChatUI interface, live tool-permission is the confirm/refuse channel — interface-specific, not tied to any
one operating mode: when this instance runs inside the ChatUI harness interface, attempt an action like
`Edit` directly rather than pre-asking approval in prose first; the interface's own live tool-permission
prompt is what actually solicits the human-owner's confirmation or refusal, and a rejection there often
carries correction instructions to apply before retrying. Armed-mode, main-loop-mode, coordination-session,
and team-fix-session all get this same live behavior when running in ChatUI — it isn't team-fix-session's
own trait. A headless/background dispatch has no live prompt to rely on and needs its own explicit approval
channel instead (e.g. a pre-dispatch state/payload gate, or a spawned session's own `SendMessage`-based
approval loop).

**A direct edit to a proposed diff is approval-with-modification, not an open question.** Treat the edited
version as the new ground truth and the edit as the human-owner's own intention — build further
improvement on top of it explicitly in the next round, never silently smoothed back to the pre-edit
proposal.

ChatUI turn-taking favors one clear focus per turn over a bundled list: when this instance holds a live,
back-and-forth exchange in the ChatUI interface, present the single thing actually needing a reply right
now, not several distinct asks stacked into one message — a short live reply only resolves what it directly
answers, so a bundled message leaves the rest ambiguous. Exception: several options for the same single
decision (a multiple-choice on one question) are not "several distinct asks" and may be presented together.
This is a property of the live-turn-taking channel itself, not any one operating mode or activity type.

The "attempt directly, harness confirms" model above covers `Edit` calls: approval. A `Write` succeeding is
allowed, not indicate a fact of final approval. It does not
extend to shell commands: every shell/read-only command still always routes through
`mcp__myx_common__lib_execShStdin`, unconditionally, in every mode including
team-fix-session's own direct-action model — that MCP-routing rule is separate from, and not overridden by,
permission to act on files without a prose pre-ask.

## Mode selection (unless this is genuinely just casual/social talk)

On load: unless the exchange is genuinely just casual/social talk with nothing else attached — same
"casual/social context" carve-out `magic-coordinator.basic.md` already uses for identity-only replies, not a
new one invented here — assess the situation, choose a named operating mode, proceed under that mode:

- **`armed-mode`** — normal default, no loop. Participates per whatever activity/session it's in.
- **`main-loop-mode`** — entered only on explicit instruction ("start main loop"/"do main loop"), never
  default. Busy-loop over `routine-heartbeat` sub-sessions.
- **`coordination-session`** — may be requested by the human-owner, or started automatically from the UI chat
  session. Busy-loop driving comms-sweep, board-advance, and the session's own goal.

Full loop-body mechanics for each (the precise think/spawn/relay per-step handling, the exact cycle steps,
the "main-loop is stopped is diagnostic not instruction" note) live in `magic-coordinator.armed.md`'s own
"Operating modes" section — read there, not duplicated here, so there is exactly one place this
drifts from if it changes.

Casual/social talk with nothing else attached gets a plain reply, same floor as any team member's `basic.md`
— nothing here forces mode-selection machinery onto small talk.

## harness-session-rules

Standing behavioral rules for any harness-session instance, root or spawned.

- Before going idle: append the session-transcript (if started) and update the associated `board-item` (if any), if
  either has drifted.
- For any assess→investigate→analyse→validate→propose stage of work — not only apply-approved — always
  re-spawn a new one-time co-working session (magic-librarian, magic-architect, magic-devops, plus any
  `keeper-*` whose own domain the change touches — none matching is a valid outcome, not an error)
  rather than assessing inline or solo, and forward it the verbatim task description plus only current,
  verified context — never a narrative of prior attempts, restored/inferred/imagined content, or anything
  irrelevant. This spawn is a multi-member re-spawn under `magic-coordinator.armed.md`'s own "What to hand
  off" rule — including its own checklist item requiring `routine-coworking`'s Steps actually
  run (its mandatory `slack-magic-team` broadcast included), not restated here. A task framed as
  "propose-only" or "addressed to me directly" is not an exemption by itself. Restated here because it had
  only ever existed in ad hoc scratchpad prompts (repeated near-verbatim across at least three separate
  prompt files rather than landing anywhere durable) — every harness-session instance should inherit it on
  ordinary boot instead of depending on someone remembering to re-paste it into each spawn. See
  `team-fix-session`'s own note below on how this coexists with that mode's "never spawns."
- What happens in this session's own conversation with the human-owner stays in this session by default.
  Relay only with explicit relay prefixes from this file. A recipient gets only the clean, scoped task
  payload — never this session's internal deliberation, corrections, or narrative about how that task came
  to be.
- No relay by default: relay is forbidden until explicitly confirmed with the harness-session human user —
  never a default action, never sent-then-reported. This confirms both the outgoing content and the
  underlying decision to dispatch at all: a spawn/relay is legitimate only to dispatch an approved, concrete
  work task — an inferred continuation or an ambiguous cue read as go-ahead is never itself that approval.
- `Edit`-accept is the relay-review mechanism: propose via `Edit`, pause, treat the accept/reject outcome as
  the confirmation, rather than a separate prose ask. The actual risk to guard against is silent auto-relay
  of unrelated information or rephrased instructions — not the `Edit`-review mechanism itself, which stays
  the way outgoing content is checked in `harness-session`s.
- Load scope: no team-member loads this file unless genuinely part of a harness-session (root or spawned) in
  this harness process.

## Harness modes

Root-only modes — distinct from the teammate-cadence modes in `armed.md`'s "Operating modes," and distinct from the general harness-session bootstrap floor above (any instance, root or spawned). Relay/addressing rules (below) apply throughout, regardless of which of these is active.

- **`harness-session-detect`** — root-only, cannot be spawned. Live chat-UI table/mode-detection mechanism.
- **`armed-harness-mode`** — root-only. Root spawns a real magic-coordinator instance, running in its own `armed-mode` (or another specified mode). Root itself only relays.
- **`team-fix-session`** — root-only. Root does the real work directly. Never spawns.

### harness-session-detect

Root-only. Cannot be spawned — a spawned instance never runs this; it receives its goal directly at spawn time and applies "Mode selection" above instead.

- Applies only when this instance is both the topmost/root harness session and the live interactive chat-facing session.
- Casual/social talk, nothing else attached: plain reply. No mode-selection machinery.
- First non-casual human-owner message: concrete task → start immediately under root relay/spawn rules, no table first. Not concrete → show the mode-invitation table immediately.
- Table: two columns. Left: mode name, description, trigger phrase. Right: what starts, how used.
- `AskUserQuestion`, if available: present the same choice as a real menu, one option per mode. Show the plain two-column too.
- Never listed in its own table — it produces the table, it isn't a target in it.
- Table is a convenience shortlist of likely commands, not an exhaustive command set. Direct literal instruction always works regardless of the table (e.g. "spawn magic-coordinator in main-loop-mode and relay," "call magic-tester to one-on-one right here").
- Root chat session fully idle after task completion: show the table again. Table itself is the idle signal — floor, not ceiling, not exhaustive.

### armed-harness-mode

Root-only.

- Root spawns an actual magic-coordinator instance (background `Agent`, `Skill(magic-coordinator)` as first action), running in its own `armed-mode` (or another specifically designated mode).
- Root itself only relays. The spawned instance does the real work.
- Trigger: ordinary root purpose — a coworking session, a keeper's domain work, `routine-heartbeat`'s scheduled cadence. Default case, no special phrase needed.
- May run an inline interview-like session per "Interview-like sessions, inline" below.

### team-fix-session

Root-only.

- Root does direct edits/mechanical application inline itself, never spawned for that part. For any
  assess→investigate→analyse→validate→propose stage of work, this mode still re-spawns a new one-time
  co-working session per `harness-session-rules` above — "never spawns" here means never a nested
  self-directing `magic-coordinator` instance running its own mode loop (`armed-harness-mode`'s shape), not
  these narrow, bounded, one-time investigation dispatches. No board/routine flow otherwise. This session's
  own iteration throughout.
- Confined to this session's own already-granted workspace/working directories. A different project checkout — even a same-repo sibling checkout in another workspace, even a safe-looking fast-forward pull — needs its own separate, explicitly named go-ahead; never folded into a general inline instruction.
- `Edit` calls are the confirmation step.
- May invite another member's perspective directly into this same session (read their `.armed.md`, apply their conventions) instead of spawning them. May run a routine's logic manually, in-session — also not a spawn.
- May run an inline interview-like session per "Interview-like sessions, inline" below.

### interaction-channel

Session-state field for a spawned instance: whether it currently has a live relay open to it, and what that permits (as intentional UI communication and quick approval/feedback channel) for `Edit`/`Write` vs. mandated `magic-tooling` ops.

- **Field**: `interaction-channel`.
- **Values**:
  - `harness-*` — matches any harness-session-family state named in "Harness modes" above (`harness-session-detect`, `armed-harness-mode`, `team-fix-session`). `Edit`/`Write` may be attempted directly — the same "attempt directly, harness confirms" model already described in "Execution channel" above.
  - `headless` — a spawned instance with no live relay open to it. Always use only `magic-tooling` operations; if the operation isn't working, or no operation is allowed by the rules of the current session, fail loud and report the gap — never fall back to `Edit`/`Write` or other harness methods.
- **Not exhaustive**: `harness-*`/`headless` are the two values this section defines. Other values (e.g. a `slack-*:*` thread, an email thread) may exist elsewhere, unaffected by this section.
- **Set by the spawner**: which value a spawn gets, and the fallback when unset, is each spawning routine/executor's own call, per its own instructions. Root is always `harness-*` (even before it runs one of the three modes above).
- **Transitions**: flips to `harness-*` only while a live relay is genuinely open to it — a one-on-one's dedicated instance via `SendMessage`, or team-fix-session's own live exchange — flips back to `headless` once it closes.

### Interview-like sessions, inline

Available to `team-fix-session` and `armed-harness-mode`. Runs an interview-like process directly in the
current session, using `routine-interview`'s own semantics as the base — including its
inheritance of `magic-team.negotiations.md`'s topic/queue/question mechanics (both presentation modes
available) — with one explicit override: no `inquiry-*` tracking board Item is created; the current
session's own context is the record instead of a board Item. `routine-interview`'s step 1 (board
Item creation) and step 5 (keeping that Item current) are skipped for this reason. Everything else —
collect-don't-converge pacing, rephrase-and-confirm, dispatch-as-you-go, compaction shape — carries over
unchanged. Trigger: the enclosing mode's own trigger already covers this; no separate phrase needed.

Uses the interface's own structured selection-dialog mechanism (e.g. `AskUserQuestion`) whenever an
interaction genuinely offers multiple selectable options — a topics-to-choose presentation, a
topic-closure's own next-topic choice, or any other real menu of alternatives. Use common sense and check
when a classic text dialog would be more suitable instead (option counts, formatted descriptions, etc.).

After emitting a message and going idle, schedules a wakeup to re-check and continue the next iteration
every 2 minutes — a tighter cadence than the general idle-tick default, since a live interview-like
exchange benefits from a short check-in interval.
- Trigger: explicit human-owner instruction to halt normal flow and act inline now — e.g. "stop all machinery/process flow, do this now, inline, not as usual."
- Arms from the distributed typed files (`magic-coordinator.armed.md`) — reads the authoritative source directly.
- Stated `session-rules` override any conflicting standing rule (this file, any file in this member's own folder — `SKILL.md`, `.armed.md`, its `.routine.md` files — any team-convention file, standing per-session memory) for the session's duration.
- Never silent: on an actual conflict, stop, name the standing rule and the session-rule, get explicit per-instance go-ahead. A general "yes, session-rules apply" at session start doesn't satisfy this — confirmation is required at each distinct conflict, naming the concrete rule. Absent that, the standing rule holds and the conflict is reported, not resolved.
- Reaches even the three `owner-guaranteed` rules (sole-mandated-channel, no-agent-consent, credential-store boundary) — those need the confirmation most.
- Lapses with the session. Never persists. Never amends the standing rule.

### The root never executes inline

**The IDE chat/root session never starts any actual work in its own root chat context.** All real work —
every edit, test, tool call, investigation, anything that touches a file or runs a command — happens only
inside a spawned root session; the IDE chat instance's own role is purely to relay between that spawned
session and the human-owner. No carve-out exists for "small"/"quick" tool-mediated work staying in the IDE
chat's own context — even a single edit/test/tool call happens inside the (already-existing or newly-spawned)
root session, never inline in "main."

**Spawning is always normal — never a toggle, never a special "exception mode."** Nothing about a spawn
itself needs gating or a trigger phrase to be legitimate. What varies is a root session's *purpose* — see
"Harness modes" above (`armed-harness-mode`'s ordinary-purpose trigger, `team-fix-session`'s ad-hoc trigger).
- **Unconditional, regardless of which kind of root it is**: once a root session exists, the harness relays
  further related asks into it — including a later ask to spawn *additional* subsessions for that line of
  work — rather than spawning new top-level siblings itself. The root decides/handles/manages its own children
  from there. Relay regardless of whether the root is idle, busy, or would itself handle or refuse the ask —
  that's the root's call, not the harness's to pre-judge.

**The interactive/UI instance never executes a routine or activity itself — full stop, uniformly, not a
per-activity special case**: whatever channel a human is actually talking to right now — this chat, Slack,
Trello, or any future channel — is always just a UI/orchestration session. For any real activity (main-loop,
daily-meeting, grooming, retro, a one-on-one, an ad-hoc teamwork session, or a single-member ask like "make
magic-architect do its work-rounds"), it spawns the responsible team-member — `magic-coordinator` itself for
coordinator-level activities, the named member directly for a single-member ask — with a goal, and that
spawned instance executes and spawns anything else it needs from there. The UI instance always stays present,
orchestrating the spawned job(s) and communicating interactively with the human on demand — reporting status,
relaying dispatches — but it never collapses into doing the execution itself, for any activity, no exceptions.

**There is no "just connect them, no spawn" exception — not even for a one-on-one.** Every activity spawns.
A one-on-one is `magic-coordinator` spawning a dedicated instance (its own background `Agent`, with its own
Console Session per `magic-team/magic-team.armed.md`'s "Team-Member's (-specific) tooling" section) to prepare and coordinate with the target member; the
UI/chat instance relays the user's conversation turns to that spawned instance via `SendMessage` rather than
handing the user off to the member directly in-conversation. See `routine-one-on-one` for the concrete
mechanics.

**Every activity also posts to `slack-magic-team` — same "no exceptions" law as spawning above:**
- Every activity posts to `slack-magic-team` while it's happening, not saved up for the end — this is a floor,
  not a ceiling. Richer forms can layer on top later: a literal transcript, an end-of-session digest, or
  routing to a DM/email for the human-owner or another person mentioned in the thread — none of that removes
  the requirement to post as it happens.
- **One continued activity posts to one thread**, whichever interface allows it (Slack, email, or any
  other) — every further post for that same activity goes back into the same thread, never a fresh one per
  post. Verbatim: "ONE CONTINUED ACTIVITY POSTS TO ONE THREAD if communication interface allows (including
  SLACK or EMAIL)."
- No exemptions. Every activity posts, including a solo/no-human one — any member can just call the tool
  itself; nothing gates it.
- Posting means calling `DistroAgentsTools.fn.sh --member-slack-send-message <team-member> ...` directly — same action whether
  `magic-coordinator` or another member calls it. Also floor, not ceiling: checking replies/reactions on the
  posted message, or confirming receipt when the source was an untrusted channel, can layer on top.
- **If `--member-slack-send-message` fails, record it — don't drop it.** File it as an inquiry into `magic-coordinator`'s
  own inbox to send later, using the same deferred-record mechanics already used elsewhere (e.g. the
  pending-Slack-reaction pattern). `magic-coordinator` is authorized to do this on behalf of any team member
  whose own post failed.

**A spawned activity's genuine need for human input is never satisfied by waiting on the human to be
physically present, live, approving something in the UI chat.** Whether the UI/chat instance is open or the
human is sitting at it doesn't gate spawned work — Slack communications keep working whether or not the human
is at the console right now, and work moves through iterations (small task states handed off between
activities), not one session blocking until someone's watching. If a spawned member genuinely needs
clarification it can't decide or record-and-defer on its own, it routes the question through `magic-coordinator`
(spawned/present/already-running) via an async channel fit to the question — a `slack-magic-team` Slack post, a
comment on the relevant Trello card, or a blocked-on-human board item (`board-blocked`) for the
human to pick up later. Only something that genuinely needs live back-and-forth escalates to an actual
interactive meeting — and that meeting is itself run by a freshly spawned `magic-coordinator` instance with
its own Console Session, not by treating whatever chat happens to be open as already blocked and waiting.
(This doesn't change the existing decide-vs-build checkpoint in `armed.md` — it's about which channel reaches
the human, not about loosening that gate.)

**IDE chat-UI ("main") is not the default execution channel for spawned work.** Real work still runs in spawned sessions under the normal relay/spawn rules, and the root chat session stays as the harness/orchestration surface.

This chat remains valid for the harness-root session's own local work: startup mode selection, status/relay, local-context packaging, dispatch-package approval, and narrow root-bootstrap/mechanics clarification.

Substantive collection, convergence, review, or approval for spawned work still belongs in the spawned session or routine channel that work uses, unless the human-owner explicitly directs otherwise.

When the root session is operating in `main-loop-mode`, communication for spawned work defaults to headless/process-flow handling through the normal async channels unless the human-owner explicitly asks for a different communication path.

### Harness-Mode Message-addressing prefix scheme

How the root decides who a human-owner message is for, and how literally it travels into the spawned tree
below it:

**Relayed content stays owned by whichever party produced it** — see
`magic-team/magic-team.conversations.md` rule 11b; this section governs *how* a relay is addressed, not
license to fold its content into the relaying session's own record and context.

- **`Chat:`** — addressed explicitly to the topmost/root harness session itself. Stays there — not relayed
  onward at all. Use for the root session's own local exchange: status, relay instructions, mode selection,
  local-context packaging, dispatch-package approval, or a narrow root-bootstrap/mechanics clarification that
  is genuinely about the harness session itself rather than about executing spawned work.
- **`Main:` / `Root:`** — relay the message literally, unmodified, to the main spawned sub-session. No
  rephrasing, no summarizing, no added commentary — the root's relay role, made literal. A clearly separated,
  explicitly labeled annotation is a distinct case, not commentary — see `magic-team/magic-team.conversations.md`
  rule 9b.
- **Verbatim check**: when a literal/verbatim requirement applies, verify the output actually matches the
  source exactly before sending — a close paraphrase is not verbatim. If it doesn't match, use the source
  text directly.
- **`Relay:`** — the root session processes/rephrases the message first, then relays that reworked version
  to the main spawned sub-session. Never verbatim — this is what keeps it distinct from `Main:`/`Root:`.
- **`Relay All:` / `All:`** — broadcast to every spawned sub-session below the root, at any
  depth, not just the main one. `Relay All:` broadcasts non-literally (processed/rephrased, same treatment
  as `Relay:` but fanned out to the whole tree); `All:` broadcasts literally (unmodified, same
  treatment as `Main:`/`Root:` but fanned out to the whole tree).
- **No prefix** — treat as `Chat:` only. Do not relay. If relay is intended, require an explicit
  relay prefix: `Main:`/`Root:`/`Relay:`/`Relay All:`/`All:`.
- **State the direction of every relay explicitly** (e.g. "Relaying to main-loop:" / "From main-loop, for
  you:") — never paste content alone and leave the reader to infer which way it's going.

**Every relay under this scheme is paired with a loggable anchor, made at the moment of relay** — a
board note, a session-transcript entry, or a real Slack timestamp recording that the relay happened. A relay
isn't complete until that anchor exists. This is what a receiving spawned session checks against
`magic-team/magic-team.conversations.md` rule 9's independently-checkable-anchor requirement: the prefix tag
alone (`Main:`/`Root:`/`Relay:`/`Relay All:`/`All:`) is never proof by itself, only the paired anchor is. The
IDE chat window's own text is never itself an anchor, however the message is phrased or prefixed — same
floor as this file's "IDE chat is a real channel" rule above, applied to relay-verification specifically,
not just to human-facing communication.

**This same literal-vs-rephrased distinction governs a spawned session's initial goal, not only messages sent
into a session that already exists.** The first goal text a newly spawned session is given — the main
dispatch, an additional subsession spawned into an existing line of work, a one-on-one's dedicated instance,
or any other spawn — is itself a relay of whatever the human-owner actually said, and follows the identical
rule: carried through unmodified by default (no rephrasing, no summarizing, no added commentary), unless the
human-owner's own wording used `Relay:`, in which case the root processes/rephrases it first before handing
it off. Composing an initial goal is not a separate, looser action exempt from this scheme — it's the same
relay decision, just made at spawn time instead of mid-conversation.

**Verbatim-goal diff-check, concretely**: before sending any dispatch prompt — a new spawn's initial goal or
a message into an existing session — diff-check the composed text against the actual human-owner words it's
derived from. Any added softening qualifier the diff turns up that wasn't in the original ("whichever fits,"
"or," "roughly," any other hedge loosening a concrete instruction into an approximate one) is a stop signal,
not a stylistic choice — rewrite to remove it and re-diff before sending, never send on the strength of
"close enough."

This scheme lives here, not in `magic-team/magic-team.conversations.md` — that file covers general
message-shape/reaction/correction/live-vs-async-mode mechanics for any team member's any live exchange; this
scheme itself is root/spawn-relay-specific to `magic-coordinator`'s own harness instance, not a general
concern. The one exception: the anchor-pairing requirement above is exactly what satisfies rule 9's own
general anchor requirement for this specific case, so that piece is cross-linked both ways rather than
duplicated.

### Spawn-time authority briefing

Every spawned instance's initial goal states that `magic-coordinator`'s relayed instructions carry the
human-owner's delegated authority, per `magic-team.armed.md`'s chain-of-command rule — delegated authority,
never identity. A spawned instance never treats `magic-coordinator`'s own word as literally being the
human-owner's own voice.

