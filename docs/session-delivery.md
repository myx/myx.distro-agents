# Session delivery

[Back to the README](../README.md)

How a message, a wake and a tool call reach a session of this tooling, and where each is recorded. Every statement names the file and function that owns it, so one read settles one question without the source open.

This page is a map, not a copy. Where a mechanism needs its detail, the owning file is the authority.

## Where a session's message is stored, and what reads it

A session records its messages in one file, `<session>/session.chat`, under `.local/agents/sessions/`. The name is the constant `agentsSessionChatName` in `sh-lib/session/AgentsTools.SessionChat.include:65`.

Three files sit beside it, and each has one job.

- `session.chat.index` carries one line per block: the block number, its Slack ts or `-`, its `<conversation>:<thread>` or `-`, its origin, the line of its header, and its seen mark. `AgentsTools.SessionChat.include:23`.
- `session.chat.pointers` carries `<reader><TAB><value>`, the one place a session keeps where a reader has got to. `AgentsTools.SessionChat.include:39`.
- `session.chat.resolved` is written aside and moved into place, so a reader never sees a half-written resolution. `AgentsTools.SessionChat.include:374` to `:378`.

A message is one block: a header line `<iso-time> <from> -> <to>:`, then its body, then a blank line. `AgentsTools.SessionChat.include:16`.

The single reader is `AgentsSessionChatRead.awk`. It reads the file and no network. `AgentsTools.SessionChat.include:45`.

Two rules keep that reader honest.

- A block with no ts yet is a post that is not yet. It holds the reader's floor back for `agentsSessionChatPendingSeconds`, 300 seconds. `AgentsTools.SessionChat.include:66` to `:67`.
- A `notice` block is no message of the floor's. The next foreground call's digest surfaces it, one line, and marks it so it shows once. `AgentsTools.SessionChat.include:54` to `:55`.

One writer holds the session's local lock for the length of one append, one stamp, one import or one pointer. So a block's number and its header's line are what they say, however many runs write at once. `AgentsTools.SessionChat.include:57`.

## What a message for a member whose run has ended meets

Three records decide it, and none of them is the chat file.

- The wake marker is one small file per member, written the moment a message addressed to that member is posted. `sh-lib/wait/AgentsTools.WakeMarker.include:5` to `:10`.
- The control state file says whether the session still runs, in one word. `sh-lib/session/AgentsTools.InternSessionControl.include:24` to `:43`.
- The spawned-sessions registry lists the session by its tracking name, and an empty sandbox is a listed session rather than a missing one. `sh-lib/session/AgentsTools.RegistrySpawnedSessions.include:32` to `:33`.

So the message is kept, and it is kept findable. A waiting run of that member wakes on the marker. A member with no live run gets the message when its next run reads the same sources, and the registry is how a reader finds that the session exists at all.

## What watches a session's runs, and what it does at a death

One shell process watches a session, and no agent runs in it. It is the control thread: a controller and a monitor. `sh-lib/session/AgentsTools.InternSessionControl.include:6` to `:9`.

What it keeps is in the session's own `control/` folder. `AgentsTools.InternSessionControl.include:13` to `:37`.

- `lock` holds `<pid> <start>` for the whole life of the thread, and refuses a second thread of the same session at once.
- `pid` says what a reader asks to learn whether the thread lives.
- `state` holds three `key: value` lines: `state`, `state-at` and `reason`.
- `log` records an event, never a tick, and it is bounded.
- `dead`, `gone` and `post.<run id>` hold what the thread keeps of a run's death and of what was posted about it.

The state is one of three words. `running` means a run of the session is alive on this host. `finished` means none is and every record is closed. `member-dead` means a run died and what is done about it is not settled. `AgentsTools.InternSessionControl.include:38` to `:43`.

A tick reads the session's records, the host's process list and the state file, and nothing else. `AgentsTools.InternSessionControl.include:45` to `:46`.

The state file is written only when the word changes. A file changed on every tick would keep the advance pass from ever closing a dead run. `AgentsTools.InternSessionControl.include:26` to `:29`.

### What a death is, and what the thread does about it

A death is judged at the tick, and four things must hold: the run's process is gone, its supervising shell is gone, its record is still open, and its record carries no word that it was killed. `sh-lib/session/AgentsTools.SessionControlDeath.include:11` to `:13`.

The thread keeps a `dead` file with one line per death, written whole by one rename. `AgentsTools.SessionControlDeath.include:17` to `:19`.

- `told=` records the note of its death, or the question, as posted.
- `asked=` records the pending-reply id of the question put about it.
- `answer=` records what the reviewer answered.
- `not=` records an answer that could not be carried out, so the death stays unsettled and the reviewer is asked again.
- `settled=` says nothing more is done about it, with `how=told` or `how=closed-elsewhere`.

`AgentsTools.SessionControlDeath.include:20` to `:39`.

So a death is neither silent nor automatic. It is told, it is asked about, and it is settled by a word written back to the same line.

## Whether a tool call can return before it finishes

Yes, and the dispatch that decides it is `AgentsHarnessRun`. `sh-lib/harness/AgentsHarnessRun.include:757` to `:800`.

Six tools run at once and have no window of their own: `Wait`, `ThisSession`, `TaskOutput`, `TaskStop`, `SubagentHandback` and `BatchTools`. `AgentsHarnessRun.include:757` to `:761`.

Every other tool is a task, with a `sync`, an `async` and a window.

- `sync` true runs the call to its own end here, with no window and no early return. `AgentsHarnessRun.include:784` to `:790`.
- `async` true marks it background. `AgentsHarnessRun.include:792`.
- A background call returns its handle before the tool runs, so a working directory the tool would refuse is refused here. `AgentsHarnessRun.include:793` to `:800`.

### How a background result is collected

The handle is `process-<N>`. `sh-lib/harness/AgentsHarnessToolsBash.include:23`.

Reading that handle reads the same process's own output, through the Bash read of the handle. `sh-lib/harness/AgentsHarnessSpawn.include:447` to `:448`.

Stopping it stops the same process, through the Bash stop of the handle. `AgentsHarnessSpawn.include:614` to `:615`.

So a caller's three moves are one handle each: read it with `TaskOutput`, watch it with `Wait sources=process:<N>`, and end it with `TaskStop`.

## The one address a message carries

One value names a channel on one comms service: `<service>:<address>[:<ts>]`. `sh-lib/comms/AgentsTools.CommsChannel.include:10`.

- `slack:<channel>` is a Slack conversation, and `slack:<channel>:<ts>` is one message in it.
- `email:<address>` is an email address.
- `telegram:<chat-id>` is a Telegram chat.
- `printback:<session>` is that session's root-native printback channel, with no network at all.

The same value reaches a board item, an inbox item and the chat file unchanged. A message's own id is `<service>:<container>:<message-id>`, which is what a reply targets.

## Which sources a wait watches

Every wait of a run holds its floor, and the floor adds its own sources. `sh-lib/wait/AgentsTools.MemberWaitSources.include:220` to `:236`.

- A member's floor adds `dms:<member>`, `mentions:<member>` and `wake:<member>`.
- A client member is given no `mentions:` source. `AgentsTools.MemberWaitSources.include:230`.
- `replies:<session>` is added first, so a reply to the run's own post is always watched. `AgentsTools.MemberWaitSources.include:215` to `:218`.
- A duty's floor adds `tagged:<member>` and `inbox:<member>`, so every wait of a duty reads its inbox. `AgentsTools.MemberWaitSources.include:225` to `:227`.

The scans come last, because a scan takes minutes and a source after it would wait for it. `AgentsTools.MemberWaitSources.include:239`.

A mention in the run's own session thread is knowledge, not work. Every such row is marked FYI, and no duty acts on it. `sh-lib/wait/AgentsTools.MemberWaitMentions.include:374` to `:376`.

## Which session owns a thread

Two files answer it, and they answer different halves.

- `session.thread` in the session's folder holds the thread a session is bound to. `AgentsToolsSessionThread` in `sh-lib/session/AgentsTools.SessionStore.include` reads it, and falls back to the session's own spawn record.
- The spawned-sessions registry lists every session, its runs, its host and its state, with a thread column. `sh-lib/session/AgentsTools.RegistrySpawnedSessions.include:9` to `:35`.

So the thread column of the registry answers "which session owns this thread", and `session.thread` answers "which thread does this session own". Read the registry first, then the session folder it names.

## A session wake, and a duty rewind

They are different mechanisms, and only one of them is about the conversation.

A wake is a signal that makes a sleeping wait look.

- A poke is one newline into a nap fifo, so a waiter wakes on the arrival rather than on its next costly look. `sh-lib/wait/AgentsTools.WakeMarker.include:95`.
- The wake marker is the file per member a writer touches, watched as a local source. `AgentsTools.WakeMarker.include:5` to `:10`.

A rewind is a return to an earlier point of the conversation.

- A snapshot is a name for the conversation at a turn boundary, never inside a round. `sh-lib/harness/AgentsHarnessCheckpoint.include:7` to `:11`.
- The `--idle-wait` wait is made at `AgentsHarnessCheckpoint.include:172`. When it returns quiet at the keepalive round, the conversation returns to its checkpoint, `opening` where held, else `armed`. `AgentsHarnessCheckpoint.include:176` to `:182`.

So a wake changes what the run looks at, and a rewind changes how much conversation it pays for.

## Where to read next

- The chat file and its index: `sh-lib/session/AgentsTools.SessionChat.include`.
- The control thread and its state words: `sh-lib/session/AgentsTools.InternSessionControl.include`.
- The death protocol: `sh-lib/session/AgentsTools.SessionControlDeath.include`.
- The registry and its columns: `sh-lib/session/AgentsTools.RegistrySpawnedSessions.include`.
- The tool dispatch: `sh-lib/harness/AgentsHarnessRun.include`.
- The checkpoint and the idle wait: `sh-lib/harness/AgentsHarnessCheckpoint.include`.
- The wait sources: `sh-lib/wait/AgentsTools.MemberWaitSources.include`.
- The wake marker: `sh-lib/wait/AgentsTools.WakeMarker.include`.
- The channel id: `sh-lib/comms/AgentsTools.CommsChannel.include`.
- The vocabulary page: [Session delivery vocabulary](session-delivery-vocabulary.md).

## The drift check that holds this page

`sh-test/magic/AgentsSessionDeliveryDocsCheck.test.sh` reads every source path, line number and function name cited here and in the vocabulary page. A path that is gone, a line past its file, or a function no longer in the tree turns it red.
