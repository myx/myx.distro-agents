# Session delivery vocabulary

[Back to the README](../README.md) · [The architecture page](session-delivery.md)

The words this tooling uses about sessions, runs and delivery, one sentence each, with the code that defines each. Read this before the source headers, not after.

## The actors

- **member** — a name with a path in this workspace, built from `.local/agents/members.registry`, which the skillset-symlink installer writes. `sh-lib/team-data/AgentsTools.RegistryTeamMembers.include:13` to `:18`.
- **session** — one continued routine instance, its state and its record, held in `.local/agents/sessions/<session>`. `sh-lib/session/AgentsTools.SessionStore.include`.
- **run** — one process of a member in a session, named by a spawn id. `sh-lib/team-data/AgentsTools.Registries.include`.
- **executor** — the member whose routine the session runs. `sh-lib/session/AgentsTools.CheckListSeed.include:4`.
- **participant** — a member brought into a session that is not its own, with a seat there. `sh-lib/session/AgentsTools.SessionChat.include:531` to `:533`.
- **seat** — the file `<session>/seats/<member>` holding the spawn id of the one run of that member that reads and posts in the session. A run finding the seat held by a live run is refused outright. `sh-lib/board/AgentsTools.ItemReviewer.include:60` to `:70`.

## The delivery path

- **floor** — the sources a wait watches whether or not the caller named any: a member's DMs, its mentions, its wake marker and the replies to its own posts. `sh-lib/wait/AgentsTools.MemberWaitSources.include:220` to `:236`.
- **immediate source** — a source a work-duty reads at its poll tick of 15 seconds, where every other source waits for its own longer gap. The kinds are `dms`, `mentions` and `tagged`. `sh-lib/wait/AgentsTools.MemberWaitCore.include:107` to `:114`.
- **notice** — a background message recorded on the session's channel that the floor never delivers. The next foreground call's digest surfaces it, one line, once. `sh-lib/session/AgentsTools.SessionChat.include:54` to `:55`.
- **FYI row** — a mention in the run's own session thread, returned as knowledge and marked so no duty acts on it. `sh-lib/wait/AgentsTools.MemberWaitMentions.include:374` to `:376`.
- **poke** — one newline written into a waiting run's nap fifo, so the wait wakes on the arrival rather than on its next costly look. `sh-lib/wait/AgentsTools.WakeMarker.include:95`.
- **wake marker** — one small file per member, written the moment a message addressed to that member is posted, and watched as a local source. `sh-lib/wait/AgentsTools.WakeMarker.include:5` to `:10`.
- **thread signal** — the session chat file, watched as `chat:<session>` and added to the floor whenever the session has a chat. `sh-lib/wait/AgentsTools.MemberWaitSources.include:206` to `:210`.
- **universal id** — one value naming one message across the cache, a block, an item and a reply: `<driver>:<container>:<message-id>`. `sh-lib/comms/AgentsTools.CommsChannel.include:59`.

## The record

- **chat file** — `<session>/session.chat`, one block per message, and the session's only message record. `sh-lib/session/AgentsTools.SessionChat.include:65`.
- **index** — `session.chat.index`, a tab-separated line per block: number, ts, conversation and thread, origin, header line, seen mark. `AgentsTools.SessionChat.include:23`.
- **pointers** — `session.chat.pointers`, `<reader><TAB><value>`, the one place a session keeps where a reader has got to. `AgentsTools.SessionChat.include:39`.
- **input scan** — the file a routine's `input-scan-def:` produces at a session's start, holding its inbox, board and Slack state at that instant. `sh-lib/member/AgentsTools.InternOpWorkDuty.include:6` to `:7`.
- **registry** — the spawned-sessions table, a row per spawn with its session, parent, host, state and thread. `sh-lib/session/AgentsTools.RegistrySpawnedSessions.include:9` to `:35`.

## The lifecycle

- **duty** — a run started by the schedule to work one member's own queue, rather than by another member. `sh-lib/member/AgentsTools.InternOpWorkDuty.include:6`.
- **idle-wait** — the call a finished run makes to wait for whatever arrives next, rather than ending. `sh-lib/harness/AgentsHarnessCheckpoint.include:172`.
- **checkpoint** — a name for the conversation as it stands at a turn boundary, never inside a round. `sh-lib/harness/AgentsHarnessCheckpoint.include:7` to `:11`.
- **rewind** — a return to a checkpoint, so the next turn is read from the cached prefix. `AgentsHarnessCheckpoint.include:167`.
- **keepalive** — the quiet round an idle wait returns at, a little before the model's prompt cache expires, which rewinds to the checkpoint and keeps the cache alive. `AgentsHarnessCheckpoint.include:176` to `:182`.
- **poke, wake marker, thread signal** — the three signals that end a sleeping wait, defined above.

## The Wait modes

One mode per call, and they are mutually exclusive. `sh-lib/wait/AgentsTools.MemberWait.include:453`.

- **default** — waits on the sources named, or on the stored wait's, and returns whatever arrives.
- **continue** — repeats the stored sources and filters, returning everything since the last call. `sh-lib/wait/AgentsTools.MemberWaitRun.include:86`.
- **close** — ends the stored wait, removes its state folder, and returns at once. `sh-lib/wait/AgentsTools.MemberWaitSources.include:616` to `:621`.
- **add** — puts sources into the stored wait and returns `WAIT-RESULT: ADDED`, waiting on nothing. `AgentsTools.MemberWaitSources.include:500` to `:513`.
- **drop** — removes one source from the stored wait and returns `WAIT-RESULT: DROPPED`, waiting on nothing. `--unwait` is its shorthand. `AgentsTools.MemberWaitSources.include:463` to `:476`.

The served Wait tool adds a **once** mode of its own, which reads one named source once and returns without waiting. Its home is that tool's own help, not this package.
