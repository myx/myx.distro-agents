#!/usr/bin/env bash
## Behavioural check on the two virtual session addresses, session-current and
## session-parent, run rather than read. Both resolve in the one address resolver
## (DistroAgentsToolsResolveTarget): session-current is the session thread of the coworking
## session the caller works in, session-parent the thread of the session that started it.
## Holds: the resolver's own answers and refusals; the Slack send, read and react
## operations, the send tools, the ask tools and Wait all take both names and reach the
## same thread; a name that names nowhere is refused with one line saying why and what to
## pass instead, and nothing is posted; every other operation that resolves a target
## refuses it by the same line; <alias>:<ts> names one message in the conversation an alias
## names, for each of the six built-in aliases and every operation and tool that acts on one
## message; a conversation alias whose setting is not there is refused by the resolver's one
## line; where an alias cannot make sense the refusal says why; the wait operation takes
## both names as sources, as the Wait
## tool does; a session that is itself the coworking session -- a native client session,
## never spawned -- finds its thread in its own record, by the name and by a send or an ask
## with no target alike, and its bare Wait watches that thread beside the two team
## conversations it always watched; the
## harness resolves neither name itself; and the help of each operation and tool that takes
## an address lists both names. Offline: the
## Slack-shaped fake curl is first on PATH, model CLIs on PATH only log, and each scenario
## has its own workspace under the workspace's .local/temp.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
## The name of the address field, read where it is held, so a rename is one line there.
rigReportsTo="$( LC_ALL=C sed -n 's/^agentsRunRouteField="\(.*\)"$/\1/p' "$rigHere/AgentsTools.SpawnSandbox.include" )"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to send under"
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsSessionAddressCheck.XXXXXX" )" || exit 1
## The parent's run, alive by the one rule a run is alive by: a stand-in whose own --session-id is
## the parent's id, ended with the rig, through the one way a check signals what it kept
## (sh-test/check-fixtures/rig-processes.include.sh). A route to a session goes to a member that runs there.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
bash -c 'sleep 1800 ; :' rig-run --session-id rig-parent-id > /dev/null 2>&1 < /dev/null &
rigParentPid=$! ; rigProcNote "$rigParentPid"
disown "$rigParentPid" 2> /dev/null || :
trap 'rigProcSignalWithChildren TERM "$rigParentPid" ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/tmp"
cp "$rigTest/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
## A model call anywhere would reach one of these first, and it only logs.
for rigModel in claude codex ; do
	printf '#!/bin/sh\necho "%s $*" >> "%s/model-calls"\nexit 1\n' "$rigModel" "$rigTmp" > "$rigTmp/bin/$rigModel"
done
chmod +x "$rigTmp/bin/"*
PATH="$rigTmp/bin:/usr/bin:/bin"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHolds(){ ## file, fixed string
	LC_ALL=C grep -q -F -- "$2" "$1" 2>/dev/null && printf yes || printf no
}

## The two threads of every scenario, and why a name names nowhere, as the resolver words it.
rigCurrent="CSESS001:1700000002.000202"
rigParent="CPARENT1:1700000001.000101"
rigPass="Pass the thread as <channel>:<ts> instead."
rigNoCurrent="this session has no session thread, so session-current names nowhere. $rigPass"
rigNoParent="this session has no recorded parent session, so session-parent names nowhere. $rigPass"
rigNoParentThread="the parent session rig-parent-id has no recorded thread, so session-parent names nowhere. $rigPass"

rigScenarioDir=""
rigStart(){ ## scenario directory name
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir/ws/.local/.agents" "$rigScenarioDir/ws/.local/agents/pending" "$rigScenarioDir/data"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigScenarioDir/ws/.local/.agents/$rigMember.agent.env"
	RIG_CURL_LOG="$rigScenarioDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
	## Each thread answers a read with its own opening message.
	printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGSELF1","text":"RIG-CURRENT-OPENER"}],"has_more":false}\n' "${rigCurrent#*:}" > "$rigScenarioDir/replies.${rigCurrent#*:}.json"
	printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGSELF1","text":"RIG-PARENT-OPENER"}],"has_more":false}\n' "${rigParent#*:}" > "$rigScenarioDir/replies.${rigParent#*:}.json"
}
## The session's spawn records. The child's record sits in a folder named for neither id,
## so only a lookup by record name can find it. The parent's id names its run and its session
## alike, as a founding run's own id names the session it founded.
rigRecords(){ ## parent id for the child record (none for no parent), the parent's thread (empty for none), a thread the spawn settled in the child's own record (optional)
	local spawnDir="$rigScenarioDir/ws/.local/agents/spawned"
	mkdir -p "$spawnDir/child-folder" "$spawnDir/parent-folder" "$spawnDir/prefix-folder"
	local childLines=""
	[ "$1" = none ] || childLines="parent-session-id: $1"$'\n'
	printf -- '---\nspawn-id: rig-child-id\nparent-spawn-id: %s\n%s%s---\n' "$1" "${3:+parent-thread: $3
}" "$childLines" > "$spawnDir/child-folder/rig-child-id.md"
	printf -- '---\nsession-id: rig-parent-id\nspawn-id: rig-parent-id\nparent-spawn-id: none\nowner: magic-coordinator\nstatus: spawn-started\n%s---\n' "${2:+session-thread: $2
}" > "$spawnDir/parent-folder/rig-parent-id.md"
	printf -- '---\nspawn-id: rig-parent-id-extra\nparent-spawn-id: none\nsession-thread: CWRONG01:1.1\n---\n' > "$spawnDir/prefix-folder/rig-parent-id-extra.md"
}
## One scenario with the usual records: a parent that has a thread.
rigScene(){ ## scenario directory name
	rigStart "$1"
	rigRecords rig-parent-id "$rigParent"
}
rigEnv(){ ## command... -- run under the scenario's workspace, with no model key
	( cd "$rigScenarioDir/ws" && env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u ANTHROPIC_API_KEY -u OPENAI_API_KEY \
		TMPDIR="$rigTmp/tmp" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_DATA_ROOT="$rigScenarioDir/data" "$@" )
}
## The calling session: spawn rig-child-id, with the session thread given or with none.
## Given `native` instead, it is a native client session, rig-native-id, never spawned: it
## has no spawn id, no session it joined and no thread passed to it.
rigAs(){ ## session thread (empty for none; native for the native client session), command...
	local asThread="$1" ; shift
	if [ "$asThread" = "native" ] ; then
		rigEnv env -u MDAT_SESSION_THREAD -u MDAT_SESSION_ID -u MDAT_SPAWN_SESSION_ID CLAUDE_CODE_SESSION_ID=rig-native-id MDAT_SPAWN_AGENT="$rigMember" MDAT_SKILLSET_ROOT="$MDAT_SKILLSET_ROOT" "$@"
		return
	fi
	rigEnv env -u MDAT_SESSION_THREAD -u MDAT_SESSION_ID ${asThread:+MDAT_SESSION_THREAD="$asThread"} MDAT_SPAWN_SESSION_ID=rig-child-id MDAT_SPAWN_AGENT="$rigMember" MDAT_SKILLSET_ROOT="$MDAT_SKILLSET_ROOT" "$@"
}
## The thread recorded for a session that is itself the coworking session, as the spawn
## proxy records it when the first member is brought in.
rigNativeThread="CNATIVE1:1700000005.000505"
rigSessionRecord(){ ## session id, thread
	mkdir -p "$rigScenarioDir/ws/.local/agents/sessions/$1"
	printf '%s\n' "$2" > "$rigScenarioDir/ws/.local/agents/sessions/$1/session.thread"
}
rigPosts(){
	ls "$rigScenarioDir"/post.* 2>/dev/null | wc -l | tr -d ' '
}
rigPostedTo(){ ## thread as <channel>:<ts> -- the one post went into it
	[ "$( rigHolds "$rigScenarioDir/post.1" "\"channel\":\"${1%%:*}\"" )" = yes ] && [ "$( rigHolds "$rigScenarioDir/post.1" "\"thread_ts\":\"${1#*:}\"" )" = yes ] && printf yes || printf no
}

## The resolver itself, sourced the way an operation's include sources it.
rigResolve(){ ## session thread (empty for none), target, who calls (default: the spawn; native: the native client session; joined: the spawn, brought into that session) -- "rc=<n> " then what it printed, its lines joined by |
	(
		set +u
		unset MDAT_SESSION_THREAD MDAT_SESSION_ID MDAT_SPAWN_SESSION_ID CLAUDE_CODE_SESSION_ID
		[ -z "$1" ] || export MDAT_SESSION_THREAD="$1"
		export MMDAPP="$rigScenarioDir/ws"
		case "${3:-}" in
			native) export CLAUDE_CODE_SESSION_ID=rig-native-id ;;
			joined) export MDAT_SPAWN_SESSION_ID=rig-child-id MDAT_SESSION_ID=rig-native-id ;;
			*) export MDAT_SPAWN_SESSION_ID=rig-child-id ;;
		esac
		. "$rigHere/AgentsTools.CommsSlack.include" definitions-only
		resolveRc=0
		resolveOut="$( DistroAgentsToolsResolveTarget "$2" )" || resolveRc=$?
		printf 'rc=%s %s' "$resolveRc" "$( printf '%s' "$resolveOut" | tr '\n' '|' )"
	)
}

echo "-- the resolver: session-current is the session thread of the caller's coworking session --"
rigScene resolveCurrent
rigAssert "from the session's own thread, as the spawn passes it" "$( rigResolve "$rigCurrent" session-current )" "rc=0 CHANNEL=CSESS001|THREAD_TS=1700000002.000202"
mkdir -p "$rigScenarioDir/ws/.local/agents/spawned/rig-child-id"
printf '%s\n' 'CFILE001:1700000004.000404' > "$rigScenarioDir/ws/.local/agents/spawned/rig-child-id/session.thread"
rigAssert "else from the pointer in the session's sandbox"        "$( rigResolve "" session-current )" "rc=0 CHANNEL=CFILE001|THREAD_TS=1700000004.000404"
rigAssert "the passed thread wins over the pointer"               "$( rigResolve "$rigCurrent" session-current )" "rc=0 CHANNEL=CSESS001|THREAD_TS=1700000002.000202"
rigScene resolveNoCurrent
rigAssert "no session thread: refused, why and what to pass"      "$( rigResolve "" session-current )" "rc=3 $rigNoCurrent"
rigAssert "a value that is no thread names nowhere either"        "$( rigResolve "not-a-thread" session-current )" "rc=3 $rigNoCurrent"
rigAssert "it never falls back to the parent's thread"            "$( rigResolve "" session-current | LC_ALL=C grep -c CPARENT1 )" 0

echo "-- the resolver: a session that is itself the coworking session reads its own record --"
rigScene resolveNative
rigAssert "no record yet: refused, as any session with no thread" "$( rigResolve "" session-current native )" "rc=3 $rigNoCurrent"
rigSessionRecord rig-native-id "$rigNativeThread"
rigAssert "session-current is the thread recorded for that session" "$( rigResolve "" session-current native )" "rc=0 CHANNEL=CNATIVE1|THREAD_TS=1700000005.000505"
rigAssert "a member brought in finds it by the session it joined" "$( rigResolve "" session-current joined )" "rc=0 CHANNEL=CNATIVE1|THREAD_TS=1700000005.000505"
rigAssert "the thread passed to a spawn still comes first"        "$( rigResolve "$rigCurrent" session-current joined )" "rc=0 CHANNEL=CSESS001|THREAD_TS=1700000002.000202"
rigAssert "the record of another session is not this caller's"    "$( rigResolve "" session-current )" "rc=3 $rigNoCurrent"
rigAssert "such a session has no parent"                          "$( rigResolve "" session-parent native )" "rc=3 $rigNoParent"
printf '%s\n' 'not-a-thread' > "$rigScenarioDir/ws/.local/agents/sessions/rig-native-id/session.thread"
rigAssert "a record that holds no thread names nowhere"           "$( rigResolve "" session-current native )" "rc=3 $rigNoCurrent"

echo "-- the resolver: session-parent is the thread of the session that started the caller --"
rigScene resolveParent
rigAssert "the parent's own thread, and the parent named"         "$( rigResolve "$rigCurrent" session-parent )" "rc=0 CHANNEL=CPARENT1|THREAD_TS=1700000001.000101|PARENT_SESSION_ID=rig-parent-id"
rigAssert "the same with no session thread of the caller's own"   "$( rigResolve "" session-parent )" "rc=0 CHANNEL=CPARENT1|THREAD_TS=1700000001.000101|PARENT_SESSION_ID=rig-parent-id"
rigStart resolveSettled
rigRecords rig-parent-id "$rigParent" CSETTLED:1700000003.000303
rigAssert "a thread the spawn kept as parent-thread is read no more: the parent session's own" "$( rigResolve "" session-parent )" "rc=0 CHANNEL=CPARENT1|THREAD_TS=1700000001.000101|PARENT_SESSION_ID=rig-parent-id"
rigStart resolveNoParent
rigRecords none "$rigParent"
rigAssert "no recorded parent: refused, why and what to pass"     "$( rigResolve "$rigCurrent" session-parent )" "rc=3 $rigNoParent"
rigStart resolveNoThread
rigRecords rig-parent-id ""
rigAssert "a parent with no thread: refused, the parent named"    "$( rigResolve "$rigCurrent" session-parent )" "rc=3 $rigNoParentThread"
rigStart resolveNoRecord
rigAssert "no record at all: refused"                             "$( rigResolve "$rigCurrent" session-parent )" "rc=3 $rigNoParent"

echo "-- the resolver: the parent session the start recorded (parent-session-id) names the parent --"
rigScene resolveStartParent
rigChild(){ ## parent-spawn-id, start-context, parent-session-id, the address it reports to (may be empty), the member that brought it in (may be empty) -- the child's record, as a start writes it now
	printf -- '---\nspawn-id: rig-child-id\nparent-spawn-id: %s\nstart-context: %s\nparent-session-id: %s\n%s%s---\n' "$1" "$2" "$3" "${4:+$rigReportsTo: $4
}" "${5:+parent-member: $5
}" > "$rigScenarioDir/ws/.local/agents/spawned/child-folder/rig-child-id.md"
}
rigChild none joined rig-parent-id
rigAssert "a start whose caller had no run id: the recorded parent session still names the parent" "$( rigResolve "$rigCurrent" session-parent )" "rc=0 CHANNEL=CPARENT1|THREAD_TS=1700000001.000101|PARENT_SESSION_ID=rig-parent-id"
rigChild rig-run-elsewhere spawned rig-parent-id
rigAssert "the recorded parent session wins over the run id beside it" "$( rigResolve "" session-parent )" "rc=0 CHANNEL=CPARENT1|THREAD_TS=1700000001.000101|PARENT_SESSION_ID=rig-parent-id"
rigChild none inline rig-native-id "" magic-tester
rigSessionRecord rig-native-id "$rigNativeThread"
rigAssert "a parent that is a native session, with no record of its own: the thread recorded for that session" "$( rigResolve "" session-parent )" "rc=0 CHANNEL=CNATIVE1|THREAD_TS=1700000005.000505|PARENT_SESSION_ID=rig-native-id"
rigChild none joined rig-silent-id "" magic-tester
rigAssert "a recorded parent session with no thread: the thread of a magic-coordinator that runs, as for every parent with none" "$( rigResolve "$rigCurrent" session-parent )" "rc=0 CHANNEL=CPARENT1|THREAD_TS=1700000001.000101|PARENT_SESSION_ID=rig-silent-id"
echo "-- the resolver: an address the run reports to names the parent session it is in --"
rigChild none joined rig-silent-id rig-parent-id:magic-tester
rigAssert "reports-to a session: that session's thread, whatever the parent session says" "$( rigResolve "$rigCurrent" session-parent )" "rc=0 CHANNEL=CPARENT1|THREAD_TS=1700000001.000101|PARENT_SESSION_ID=rig-parent-id"
rigChild none joined rig-parent-id magic-coordinator
rigAssert "reports-to a member: no session to name" "$( rigResolve "$rigCurrent" session-parent )" "rc=3 $rigNoParent"
rigChild none spawned "" user-rig
rigAssert "reports-to a person: no session to name" "$( rigResolve "$rigCurrent" session-parent )" "rc=3 $rigNoParent"

echo "-- the resolver: the other targets are as they were --"
rigScene resolveOther
rigAssert "control: a thread by its own id"                       "$( rigResolve "$rigCurrent" CEXPL0001:1700000009.000009 )" "rc=0 CHANNEL=CEXPL0001|THREAD_TS=1700000009.000009"
rigAssert "control: a bare conversation id"                       "$( rigResolve "$rigCurrent" CEXPL0001 )" "rc=0 CHANNEL=CEXPL0001|THREAD_TS="
rigAssert "control: another session-like word is no address"      "$( rigResolve "$rigCurrent" session-other )" "rc=2 "

## One operation, as the calling session's own member.
rigOpRc=0
rigOp(){ ## session thread (empty for none), operation and its arguments after the member
	local opThread="$1" opName="$2" ; shift 2
	rigOpRc=0
	rigAs "$opThread" bash "$rigTool" "$opName" "$rigMember" "$@" < /dev/null > "$rigScenarioDir/op.out" 2> "$rigScenarioDir/op.err" || rigOpRc=$?
}
## The operation's own error lines, whole: a refusal is one line.
rigOpErrors(){
	LC_ALL=C grep -F -- '⛔ ERROR: DistroAgentsTools --member-' "$rigScenarioDir/op.err" 2>/dev/null
}
rigReacted(){ ## "<ts> <name>" -- how many times that reaction was asked for
	LC_ALL=C grep -c -x -F -- "$1" "$rigScenarioDir/reactions" 2>/dev/null || :
}

echo "-- the send operation takes both names --"
rigScene opSendCurrent
rigOp "$rigCurrent" --member-comms-slack-send-message session-current RIG-BODY
rigHolds "$rigScenarioDir/op.err" 'SENT_MESSAGE_TS=' | grep -q yes || rigRefuse "no send reached the fake curl at all: $( grep -m1 ERROR "$rigScenarioDir/op.err" )"
rigAssert "session-current: one post, in the session thread"      "$rigOpRc:$( rigPosts ):$( rigPostedTo "$rigCurrent" )" "0:1:yes"
rigScene opSendParent
rigOp "$rigCurrent" --member-comms-slack-send-message session-parent RIG-BODY
rigAssert "session-parent: one post, in the parent's thread"      "$rigOpRc:$( rigPosts ):$( rigPostedTo "$rigParent" )" "0:1:yes"
rigAssert "and not in the caller's own"                           "$( rigHolds "$rigScenarioDir/post.1" 'CSESS001' )" no
rigScene opSendNoCurrent
rigOp "" --member-comms-slack-send-message session-current RIG-BODY
rigAssert "no session thread: refused, nothing posted"            "$rigOpRc:$( rigPosts )" "1:0"
rigAssert "by one line: why, and what to pass instead"            "$( rigOpErrors )" "⛔ ERROR: DistroAgentsTools --member-comms-slack-send-message: $rigNoCurrent Nothing was sent."
rigStart opSendNoParent
rigRecords none "$rigParent"
rigOp "$rigCurrent" --member-comms-slack-send-message session-parent RIG-BODY
rigAssert "no parent: refused, nothing posted"                    "$rigOpRc:$( rigPosts )" "1:0"
rigAssert "by one line: why, and what to pass instead"            "$( rigOpErrors )" "⛔ ERROR: DistroAgentsTools --member-comms-slack-send-message: $rigNoParent Nothing was sent."
rigAssert "never the caller's own thread instead"                 "$( rigHolds "$rigScenarioDir/op.err" 'CSESS001' )" no

echo "-- the read operation takes both names --"
rigScene opRead
rigOp "$rigCurrent" --member-comms-slack-read session-current --thread
rigAssert "session-current --thread: the session thread is read"  "$rigOpRc:$( rigHolds "$rigScenarioDir/op.err" 'GET conversations.replies channel=CSESS001 ts=1700000002.000202 (full thread' )" "0:yes"
rigAssert "and what it holds is returned"                         "$( rigHolds "$rigScenarioDir/op.out" 'RIG-CURRENT-OPENER' )" yes
rigOp "$rigCurrent" --member-comms-slack-read session-parent
rigAssert "session-parent: the parent thread's opening message"   "$rigOpRc:$( rigHolds "$rigScenarioDir/op.err" 'GET conversations.replies channel=CPARENT1 ts=1700000001.000101 (single message' )" "0:yes"
rigAssert "and what it holds is returned"                         "$( rigHolds "$rigScenarioDir/op.out" 'RIG-PARENT-OPENER' )" yes
: > "$RIG_CURL_LOG"
rigOp "" --member-comms-slack-read session-current --thread
rigAssert "no session thread: refused by the one line"            "$rigOpRc:$( rigOpErrors )" "1:⛔ ERROR: DistroAgentsTools --member-comms-slack-read: $rigNoCurrent"
rigAssert "and nothing was read"                                  "$( LC_ALL=C grep -c -x 'conversations.replies' "$RIG_CURL_LOG" )" 0

echo "-- the react operation takes both names --"
rigScene opReact
rigOp "$rigCurrent" --member-comms-slack-react session-current eyes
rigAssert "session-current: on the session thread's opening message" "$rigOpRc:$( rigReacted '1700000002.000202 eyes' ):$( rigHolds "$rigScenarioDir/op.err" 'POST reactions.add channel=CSESS001 timestamp=1700000002.000202 name=eyes' )" "0:1:yes"
rigOp "$rigCurrent" --member-comms-slack-react session-parent eyes
rigAssert "session-parent: on the parent thread's opening message"   "$rigOpRc:$( rigReacted '1700000001.000101 eyes' ):$( rigHolds "$rigScenarioDir/op.err" 'POST reactions.add channel=CPARENT1 timestamp=1700000001.000101 name=eyes' )" "0:1:yes"
rigOp "" --member-comms-slack-react session-current eyes
rigAssert "no session thread: refused by the one line"            "$rigOpRc:$( rigOpErrors )" "1:⛔ ERROR: DistroAgentsTools --member-comms-slack-react: $rigNoCurrent"
rigAssert "only the two reactions asked for were placed"          "$( wc -l < "$rigScenarioDir/reactions" | tr -d ' ' )" 2

echo "-- every other operation that resolves a target refuses the name by the same line --"
rigStart opOthers
rigRecords none ""
printf 'rig\n' > "$rigScenarioDir/share.txt"
: > "$RIG_CURL_LOG"
rigOp "" --member-comms-slack-edit-message session-parent RIG-BODY
rigAssert "edit-message"                                          "$rigOpRc:$( rigOpErrors )" "1:⛔ ERROR: DistroAgentsTools --member-comms-slack-edit-message: $rigNoParent"
rigOp "" --member-comms-slack-search-messages session-parent --comms-since-utime 1700000000
rigAssert "search-messages"                                       "$rigOpRc:$( rigOpErrors )" "1:⛔ ERROR: DistroAgentsTools --member-comms-slack-search-messages: $rigNoParent"
rigOp "" --member-comms-slack-file-share session-parent --from-file "$rigScenarioDir/share.txt"
rigAssert "file-share, before anything is uploaded"               "$rigOpRc:$( rigOpErrors )" "1:⛔ ERROR: DistroAgentsTools --member-comms-slack-file-share: $rigNoParent Nothing was uploaded."
rigOp "" --member-comms-slack-delete-message session-parent
rigAssert "delete-message, for that one target"                   "$rigOpRc:$( rigOpErrors | head -1 )" "1:⛔ ERROR: DistroAgentsTools --member-comms-slack-delete-message: $rigNoParent Nothing was deleted for this target; the remaining targets are still attempted."
rigAssert "and its state is the unresolvable one"                 "$( LC_ALL=C grep -c -x -e 'DELETE_TARGET=session-parent' -e 'DELETE_STATE=unresolvable-target' "$rigScenarioDir/op.out" )" 2
rigAssert "none of them called Slack to post, edit, delete or upload" "$( LC_ALL=C grep -c -v -x -e 'auth.test' -e 'conversations.info' "$RIG_CURL_LOG" )" 0

## One served call of a harness tool, as the calling session's own member.
rigCall(){ ## session thread (empty for none), tool name, arguments JSON
	printf '%s' "$3" | rigAs "$1" bash "$rigHarness" --intern-tool "$2" > "$rigScenarioDir/tool.out" 2> "$rigScenarioDir/tool.err"
}
rigFirst(){
	LC_ALL=C sed -n '1p' "$rigScenarioDir/tool.out"
}
rigRow(){ ## scenario name, session thread (empty for none), tool, arguments JSON
	rigScene "$1"
	rigCall "$2" "$3" "$4"
}

echo "-- the send tools take both names, and say which thread it was --"
rigRow toolSendCurrent "$rigCurrent" SendMessage '{"to":"session-current","message":"m"}'
rigAssert "SendMessage to session-current: the session thread"    "$( rigPosts )$( rigPostedTo "$rigCurrent" )" 1yes
rigAssert "and the first line names the route"                    "$( rigFirst )" "Sent to $rigCurrent (the thread of this session) as $rigMember. What the operation reported follows:"
rigRow toolSendParent "$rigCurrent" SendMessage '{"to":"session-parent","message":"m"}'
rigAssert "SendMessage to session-parent: the parent's thread"    "$( rigPosts )$( rigPostedTo "$rigParent" )" 1yes
rigAssert "and the first line names the route"                    "$( rigFirst )" "Sent to $rigParent (the thread of parent session rig-parent-id) as $rigMember. What the operation reported follows:"
for rigPair in 'SubagentHandback={"to":"session-current","outcome":"x"}' 'ReportFindings={"to":"session-current","subject":"s","findings":"f"}' 'PushNotification={"to":"session-current","severity":"info","headline":"h"}' 'Artifact={"to":"session-current","url":"https://x/y"}' ; do
	rigRow "toolCurrent${rigPair%%=*}" "$rigCurrent" "${rigPair%%=*}" "${rigPair#*=}"
	rigAssert "${rigPair%%=*} to session-current: the session thread" "$( rigPosts )$( rigPostedTo "$rigCurrent" )" 1yes
done
for rigPair in 'SendMessage={"to":"session-current","message":"m"}' 'SubagentHandback={"to":"session-current","outcome":"x"}' 'ReportFindings={"to":"session-current","subject":"s","findings":"f"}' 'PushNotification={"to":"session-current","severity":"info","headline":"h"}' 'Artifact={"to":"session-current","url":"https://x/y"}' ; do
	rigRow "toolNone${rigPair%%=*}" "" "${rigPair%%=*}" "${rigPair#*=}"
	rigAssert "${rigPair%%=*} with no session thread: the one line, nothing posted" "$( rigPosts ):$( rigFirst )" "0:ERROR: $rigNoCurrent Nothing was sent."
done

## One served call of a tool that always waits for its answer. Nobody answers here, so the
## call is ended once its question is posted, or by the guard: what is asserted is where
## the question went, never a result of the wait.
rigAskCall(){ ## session thread (empty for none), tool name, arguments JSON
	local askPid askLeft=120
	set -m
	( printf '%s' "$3" | rigAs "$1" env MDAT_HARNESS_WAIT_TIMEOUT=1 bash "$rigHarness" --intern-tool "$2" > "$rigScenarioDir/tool.out" 2> "$rigScenarioDir/tool.err" ) &
	askPid=$!
	set +m
	while kill -0 "$askPid" 2>/dev/null && [ "$askLeft" -gt 0 ] && [ "$( rigPosts )" = 0 ] ; do
		sleep 1
		askLeft=$(( askLeft - 1 ))
	done
	if kill -0 "$askPid" 2>/dev/null ; then
		{ kill -TERM -- "-$askPid" ; sleep 1 ; kill -KILL -- "-$askPid" ; wait "$askPid" ; } 2>/dev/null
	fi
	wait "$askPid" 2>/dev/null || :
}

echo "-- the ask tools take both names --"
rigRow askCurrentAskQuestion "$rigCurrent" AskQuestion '{"to":"session-current","address_to":"human-owner","question":"May the rig go on?","wait":false}'
rigAssert "AskQuestion to session-current: asked in the session thread" "$( rigPosts )$( rigPostedTo "$rigCurrent" ):$( rigFirst )" "1yes:ASK-RESULT: POSTED"
rigRow askParentAskQuestion "$rigCurrent" AskQuestion '{"to":"session-parent","address_to":"human-owner","question":"May the rig go on?","wait":false}'
rigAssert "AskQuestion to session-parent: asked in the parent's thread" "$( rigPosts )$( rigPostedTo "$rigParent" ):$( rigFirst )" "1yes:ASK-RESULT: POSTED"
for rigPair in 'ConfirmReadback="question":"Did the rig read it right?","understood":"u","source":"s","will_do":"w"' 'EscalateDecision="question":"Which check first?","options":"alpha -- the unit checks\nbeta -- the lint"' ; do
	rigScene "askCurrent${rigPair%%=*}"
	rigAskCall "$rigCurrent" "${rigPair%%=*}" "{\"to\":\"session-current\",\"address_to\":\"human-owner\",${rigPair#*=}}"
	rigAssert "${rigPair%%=*} to session-current: asked in the session thread" "$( rigPosts )$( rigPostedTo "$rigCurrent" )" 1yes
	rigScene "askParent${rigPair%%=*}"
	rigAskCall "$rigCurrent" "${rigPair%%=*}" "{\"to\":\"session-parent\",\"address_to\":\"human-owner\",${rigPair#*=}}"
	rigAssert "${rigPair%%=*} to session-parent: asked in the parent's thread" "$( rigPosts )$( rigPostedTo "$rigParent" )" 1yes
done
rigRow askCurrentBare "$rigCurrent" AskQuestion '{"to":"session-current","question":"May the rig go on?","wait":false}'
rigAssert "session-current needs address_to, as any thread does"  "$( rigPosts ):$( rigFirst | LC_ALL=C grep -c '^ERROR: AskQuestion: .*address_to is required' )" "0:1"
for rigPair in 'AskQuestion="question":"May the rig go on?"' 'ConfirmReadback="question":"Did the rig read it right?","understood":"u","source":"s","will_do":"w"' 'EscalateDecision="question":"Which check first?","options":"alpha -- the unit checks\nbeta -- the lint"' 'RequestPermission="question":"May the rig write this file?","refusal_id":"refusal-0","reason":"the rig needs it","task_ref":"dispatch-rig"' ; do
	rigRow "askNone${rigPair%%=*}" "" "${rigPair%%=*}" "{\"to\":\"session-current\",\"address_to\":\"human-owner\",${rigPair#*=}}"
	rigAssert "${rigPair%%=*} with no session thread: the one line, nothing posted" "$( rigPosts ):$( rigFirst )" "0:ERROR: ${rigPair%%=*}: $rigNoCurrent Nothing was sent."
done
rigStart askNoParent
rigRecords none "$rigParent"
rigCall "$rigCurrent" RequestPermission '{"to":"session-parent","address_to":"human-owner","question":"May the rig write this file?","refusal_id":"refusal-0","reason":"the rig needs it","task_ref":"dispatch-rig"}'
rigAssert "RequestPermission with no parent: the one line, nothing posted" "$( rigPosts ):$( rigFirst )" "0:ERROR: RequestPermission: $rigNoParent Nothing was sent."

## What the session's stored wait holds as its sources, as the wait operation recorded them.
rigWaited(){ ## session id (default: the spawn's)
	LC_ALL=C sed -n 's/^sources: //p' "$rigScenarioDir/ws/.local/agents/sessions/${1:-rig-child-id}/wait/state" 2>/dev/null | LC_ALL=C tr -s ' ' | LC_ALL=C sed 's/ $//'
}
rigWaitEnded(){ ## how the wait ended: the first word after WAIT-RESULT:
	rigFirst | LC_ALL=C sed -n 's/^WAIT-RESULT: \([A-Z]*\).*/\1/p'
}

## The floor given is later than every message of the rig, so each wait ends by its bound.
echo "-- Wait takes both names as sources --"
rigRow waitCurrent "$rigCurrent" Wait '{"sources":"slack:session-current","timeout":1,"since_utime":"1700000100"}'
rigAssert "slack:session-current: the session thread was waited on" "$( rigWaitEnded ):$( rigWaited )" "TIMEOUT:slack:$rigCurrent:conversation"
rigRow waitParent "$rigCurrent" Wait '{"sources":"slack:session-parent","timeout":1,"since_utime":"1700000100"}'
rigAssert "slack:session-parent: the parent's thread was waited on" "$( rigWaitEnded ):$( rigWaited )" "TIMEOUT:slack:$rigParent:conversation"
rigRow waitMixed "$rigCurrent" Wait "{\"sources\":\"file:$rigTmp/waitMixed/drop slack:session-parent slack:session-current\",\"timeout\":1,\"since_utime\":\"1700000100\"}"
rigAssert "beside other sources: each name its own thread, the rest as given" "$( rigWaitEnded ):$( rigWaited )" "TIMEOUT:file:$rigTmp/waitMixed/drop slack:$rigParent:conversation slack:$rigCurrent:conversation"
rigRow waitNoCurrent "" Wait '{"sources":"slack:session-current","timeout":1}'
rigAssert "no session thread: the one line, nothing waited on"    "$( rigFirst )" "ERROR: $rigNoCurrent Nothing was waited on."
rigStart waitNoParent
rigRecords none "$rigParent"
rigCall "$rigCurrent" Wait '{"sources":"slack:session-parent","timeout":1}'
rigAssert "no parent: the one line, nothing waited on"            "$( rigFirst )" "ERROR: $rigNoParent Nothing was waited on."

echo "-- the wait operation takes both names as sources, as the Wait tool does --"
rigOpSources(){ ## the sources the wait operation says it waited on
	LC_ALL=C sed -n 's/^# sources: //p' "$rigScenarioDir/op.out" | LC_ALL=C tr -s ' ' | LC_ALL=C sed 's/ $//'
}
rigScene opWaitCurrent
rigOp "$rigCurrent" --member-wait-for-input --wait-source slack:session-current --wait-timeout 1 --wait-since-utime 1700000100
rigAssert "slack:session-current: the session thread was waited on" "$rigOpRc:$( LC_ALL=C sed -n '1p' "$rigScenarioDir/op.out" ):$( rigOpSources )" "0:WAIT-RESULT: TIMEOUT:slack:$rigCurrent:conversation"
rigScene opWaitParent
rigOp "$rigCurrent" --member-wait-for-input --wait-source slack:session-parent --wait-timeout 1 --wait-since-utime 1700000100
rigAssert "slack:session-parent: the parent's thread was waited on" "$rigOpRc:$( LC_ALL=C sed -n '1p' "$rigScenarioDir/op.out" ):$( rigOpSources )" "0:WAIT-RESULT: TIMEOUT:slack:$rigParent:conversation"
rigScene opWaitStored
rigOp "$rigCurrent" --member-wait-for-input --wait-default --wait-session-id rig-child-id --wait-source "file:$rigTmp/opWaitStored/drop" --wait-source slack:session-parent --wait-source slack:session-current --wait-timeout 1 --wait-since-utime 1700000100
rigAssert "a stored wait keeps each name as its thread, the rest as given" "$rigOpRc:$( rigWaited )" "0:file:$rigTmp/opWaitStored/drop slack:$rigParent:conversation slack:$rigCurrent:conversation"
rigScene opWaitNoCurrent
: > "$RIG_CURL_LOG"
rigOp "" --member-wait-for-input --wait-source slack:session-current --wait-timeout 1
rigAssert "no session thread: refused before the wait starts"     "$rigOpRc:$( LC_ALL=C sed -n '1p' "$rigScenarioDir/op.out" )" "1:WAIT-RESULT: ERROR"
rigAssert "by the one line, the same as the Wait tool gives"      "$( rigOpErrors )" "⛔ ERROR: DistroAgentsTools --member-wait-for-input: $rigNoCurrent Nothing was waited on."
rigAssert "and nothing was read"                                  "$( LC_ALL=C grep -c . "$RIG_CURL_LOG" )" 0
rigStart opWaitNoParent
rigRecords none "$rigParent"
rigOp "$rigCurrent" --member-wait-for-input --wait-source slack:session-parent --wait-timeout 1
rigAssert "no parent: refused by the one line"                    "$rigOpRc:$( rigOpErrors )" "1:⛔ ERROR: DistroAgentsTools --member-wait-for-input: $rigNoParent Nothing was waited on."

echo "-- a session that is itself the coworking session: the name and the default are one thing --"
rigScene nativeSendName
rigSessionRecord rig-native-id "$rigNativeThread"
rigOp native --member-comms-slack-send-message session-current RIG-BODY
rigAssert "the send operation to session-current: its recorded thread" "$rigOpRc:$( rigPosts ):$( rigPostedTo "$rigNativeThread" )" "0:1:yes"
rigScene nativeSendDefault
rigSessionRecord rig-native-id "$rigNativeThread"
rigOp native --member-comms-slack-send-message "" RIG-BODY
rigAssert "the send operation with no target: the same thread"    "$rigOpRc:$( rigPosts ):$( rigPostedTo "$rigNativeThread" )" "0:1:yes"
rigScene nativeSendDefaultNone
rigOp native --member-comms-slack-send-message "" RIG-BODY
rigAssert "with no thread recorded it is refused as before"       "$rigOpRc:$( rigPosts ):$( rigOpErrors )" "1:0:⛔ ERROR: DistroAgentsTools --member-comms-slack-send-message: <target> missing"
rigScene spawnSendDefault
rigOp "$rigCurrent" --member-comms-slack-send-message "" RIG-BODY
rigAssert "control: a spawn's send with no target, its session thread" "$rigOpRc:$( rigPosts ):$( rigPostedTo "$rigCurrent" )" "0:1:yes"
rigScene nativeToolName
rigSessionRecord rig-native-id "$rigNativeThread"
rigCall native SendMessage '{"to":"session-current","message":"m"}'
rigAssert "SendMessage to session-current: its recorded thread"   "$( rigPosts )$( rigPostedTo "$rigNativeThread" ):$( rigFirst )" "1yes:Sent to $rigNativeThread (the thread of this session) as $rigMember. What the operation reported follows:"
rigScene nativeToolDefault
rigSessionRecord rig-native-id "$rigNativeThread"
rigCall native SendMessage '{"message":"m"}'
rigAssert "SendMessage with no to: the same thread"               "$( rigPosts )$( rigPostedTo "$rigNativeThread" ):$( rigFirst )" "1yes:Sent to $rigNativeThread as $rigMember. What the operation reported follows:"
rigScene nativeToolDefaultNone
rigCall native SendMessage '{"message":"m"}'
rigAssert "with no thread recorded it is refused as before"       "$( rigPosts ):$( rigFirst )" "0:ERROR: both to and message are required, and one of them was empty. Nothing was sent."
rigScene nativeAskDefault
rigSessionRecord rig-native-id "$rigNativeThread"
rigCall native AskQuestion '{"address_to":"human-owner","question":"May the rig go on?","wait":false}'
rigAssert "AskQuestion with no to: asked in the same thread"      "$( rigPosts )$( rigPostedTo "$rigNativeThread" ):$( rigFirst )" "1yes:ASK-RESULT: POSTED"
rigScene nativeAskDefaultNone
rigCall native AskQuestion '{"address_to":"human-owner","question":"May the rig go on?","wait":false}'
rigAssert "with no thread recorded it is refused as before"       "$( rigPosts ):$( rigFirst )" "0:ERROR: AskQuestion: to is required and was empty, so there is nobody to ask. Nothing was sent."
rigScene nativeWaitName
rigSessionRecord rig-native-id "$rigNativeThread"
printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGSELF1","text":"RIG-NATIVE-OPENER"}],"has_more":false}\n' "${rigNativeThread#*:}" > "$rigScenarioDir/replies.${rigNativeThread#*:}.json"
rigCall native Wait '{"sources":"slack:session-current","timeout":1,"since_utime":"1700000100"}'
rigAssert "Wait on slack:session-current: its recorded thread"    "$( rigWaitEnded ):$( rigWaited rig-native-id )" "TIMEOUT:slack:$rigNativeThread:conversation"

echo "-- a bare Wait in such a session watches its recorded thread beside the two team conversations --"
rigScene nativeWaitBare
rigSessionRecord rig-native-id "$rigNativeThread"
rigCall native Wait '{"timeout":1}'
rigAssert "the Wait tool: the two conversations, and the session thread" "$( rigWaited rig-native-id )" "slack:magic-team slack:human-owner slack:$rigNativeThread:conversation"
rigScene nativeWaitBareNone
rigCall native Wait '{"timeout":1}'
rigAssert "with no thread recorded: the two conversations alone, as before" "$( rigWaited rig-native-id )" "slack:magic-team slack:human-owner"
rigScene nativeOpWaitBare
rigSessionRecord rig-native-id "$rigNativeThread"
rigOp native --member-wait-for-input --wait-timeout 1
rigAssert "the wait operation: the same three sources"            "$rigOpRc:$( rigOpSources )" "0:slack:magic-team slack:human-owner slack:$rigNativeThread:conversation"
rigScene nativeOpWaitBareNone
rigOp native --member-wait-for-input --wait-timeout 1
rigAssert "with no thread recorded: the two conversations alone, as before" "$rigOpRc:$( rigOpSources )" "0:slack:magic-team slack:human-owner"
rigScene nativeOpWaitBareBad
rigSessionRecord rig-native-id not-a-thread
rigOp native --member-wait-for-input --wait-timeout 1
rigAssert "a record that holds no thread adds nothing"            "$rigOpRc:$( rigOpSources )" "0:slack:magic-team slack:human-owner"
rigScene spawnOpWaitBare
rigOp "$rigCurrent" --member-wait-for-input --wait-timeout 1
rigAssert "control: a spawn's bare wait is its session thread alone" "$rigOpRc:$( rigOpSources )" "0:slack:$rigCurrent:conversation"
rigScene spawnOpWaitBareNone
rigSessionRecord rig-native-id "$rigNativeThread"
rigOp "" --member-wait-for-input --wait-timeout 1
rigAssert "control: a spawn with no thread, beside another session's record: the two alone" "$rigOpRc:$( rigOpSources )" "0:slack:magic-team slack:human-owner"

## The built-in aliases beside the two session addresses, and one message of an alias's
## conversation. A scenario that names event-track or event-alert has them set.
rigAliasSettings(){ ## which of the two event conversations are set: both (default), or track
	printf 'SLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\n' >> "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	[ "${1:-both}" != "both" ] || printf 'SLACK_CHANNEL_EVENT_ALERT=CRIGALERT\n' >> "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
}
rigMessage="1700000007.000707"
rigNoAlert="the setting SLACK_CHANNEL_EVENT_ALERT is not set in this workspace, so event-alert names nowhere. Pass the conversation by its id instead."
rigAliasScene(){ ## scenario directory name, which event conversations are set
	rigScene "$1"
	rigAliasSettings "${2:-both}"
	printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGSELF1","text":"RIG-ONE-MESSAGE"}],"has_more":false}\n' "$rigMessage" > "$rigScenarioDir/replies.$rigMessage.json"
}

echo "-- <alias>:<ts> is one message in the conversation the alias names: the resolver --"
rigScene resolveMessage
rigAssert "session-current:<ts>: that message, in the session thread's conversation" "$( rigResolve "$rigCurrent" "session-current:$rigMessage" )" "rc=0 CHANNEL=CSESS001|THREAD_TS=$rigMessage"
rigAssert "session-parent:<ts>: that message, in the parent thread's conversation, the parent named" "$( rigResolve "$rigCurrent" "session-parent:$rigMessage" )" "rc=0 CHANNEL=CPARENT1|THREAD_TS=$rigMessage|PARENT_SESSION_ID=rig-parent-id"
rigAssert "with no session thread it names nowhere, by the same line" "$( rigResolve "" "session-current:$rigMessage" )" "rc=3 $rigNoCurrent"
rigSessionRecord rig-native-id "$rigNativeThread"
rigAssert "in a session that is itself the coworking session: its recorded conversation" "$( rigResolve "" "session-current:$rigMessage" native )" "rc=0 CHANNEL=CNATIVE1|THREAD_TS=$rigMessage"
rigAssert "on the client side an alias of our own side stays refused, with its message too" "$( set +u ; export MDAT_COMMS_SIDE=client MDAT_SESSION_THREAD="$rigCurrent" MMDAPP="$rigScenarioDir/ws" ; . "$rigHere/AgentsTools.CommsSlack.include" definitions-only ; DistroAgentsToolsResolveTarget "session-current:$rigMessage" client-rig > "$rigScenarioDir/client.out" ; printf 'rc=%s:%s' "$?" "$( LC_ALL=C grep -c "is refused: for 'session-current', this addressee alias is only usable in" "$rigScenarioDir/client.out" )" )" "rc=3:1"

echo "-- every operation that acts on one message takes <alias>:<ts>, for all six aliases --"
rigAliasScene opMessageRead
rigOp "$rigCurrent" --member-comms-slack-read "session-current:$rigMessage"
rigAssert "read session-current:<ts>: that one message"           "$rigOpRc:$( rigHolds "$rigScenarioDir/op.err" "GET conversations.replies channel=CSESS001 ts=$rigMessage (single message" ):$( rigHolds "$rigScenarioDir/op.out" 'RIG-ONE-MESSAGE' )" "0:yes:yes"
rigOp "$rigCurrent" --member-comms-slack-read "session-parent:$rigMessage" --thread
rigAssert "read session-parent:<ts> --thread: the thread of that message" "$rigOpRc:$( rigHolds "$rigScenarioDir/op.err" "GET conversations.replies channel=CPARENT1 ts=$rigMessage (full thread" )" "0:yes"
rigOp "$rigCurrent" --member-comms-slack-read "event-track:$rigMessage"
rigAssert "read event-track:<ts>"                                 "$rigOpRc:$( rigHolds "$rigScenarioDir/op.err" "GET conversations.replies channel=CRIGTRACK ts=$rigMessage (single message" )" "0:yes"
rigOp "$rigCurrent" --member-comms-slack-read "magic-team:$rigMessage" --thread
rigAssert "read magic-team:<ts> --thread"                         "$rigOpRc:$( rigHolds "$rigScenarioDir/op.err" "GET conversations.replies channel=CRIG00001 ts=$rigMessage (full thread" )" "0:yes"
rigAliasScene opMessageReact
rigOp "$rigCurrent" --member-comms-slack-react "session-current:$rigMessage" eyes
rigAssert "react session-current:<ts>"                            "$rigOpRc:$( rigHolds "$rigScenarioDir/op.err" "POST reactions.add channel=CSESS001 timestamp=$rigMessage name=eyes" )" "0:yes"
rigOp "$rigCurrent" --member-comms-slack-react "session-parent:$rigMessage" eyes
rigAssert "react session-parent:<ts>"                             "$rigOpRc:$( rigHolds "$rigScenarioDir/op.err" "POST reactions.add channel=CPARENT1 timestamp=$rigMessage name=eyes" )" "0:yes"
rigOp "$rigCurrent" --member-comms-slack-react "event-alert:$rigMessage" eyes
rigAssert "react event-alert:<ts>"                                "$rigOpRc:$( rigHolds "$rigScenarioDir/op.err" "POST reactions.add channel=CRIGALERT timestamp=$rigMessage name=eyes" )" "0:yes"
rigOp "$rigCurrent" --member-comms-slack-react magic-team eyes
rigAssert "react on a conversation alias alone: refused, it names no message" "$rigOpRc:$( rigOpErrors )" "1:⛔ ERROR: DistroAgentsTools --member-comms-slack-react: a specific <ts> is required -- use <channel>:<ts>, or <alias>:<ts> for a message in the conversation an alias names"
rigAssert "the three reactions asked for were placed, and no other" "$( LC_ALL=C sort "$rigScenarioDir/reactions" | tr '\n' '|' )" "$rigMessage eyes|$rigMessage eyes|$rigMessage eyes|"
rigAliasScene opMessageEdit
rigOp "$rigCurrent" --member-comms-slack-edit-message "session-current:$rigMessage" RIG-BODY
rigAssert "edit-message session-current:<ts>: that message is the one edited" "$( rigHolds "$rigScenarioDir/op.err" "chat.update channel=CSESS001 ts=$rigMessage " )" yes
rigOp "$rigCurrent" --member-comms-slack-edit-message "event-track:$rigMessage" RIG-BODY
rigAssert "edit-message event-track:<ts>"                         "$( rigHolds "$rigScenarioDir/op.err" "chat.update channel=CRIGTRACK ts=$rigMessage " )" yes
rigOp "$rigCurrent" --member-comms-slack-edit-message session-parent RIG-BODY
rigAssert "edit-message session-parent alone: the opening message of that thread" "$( rigHolds "$rigScenarioDir/op.err" "chat.update channel=CPARENT1 ts=${rigParent#*:} " )" yes
: > "$RIG_CURL_LOG"
rigOp "$rigCurrent" --member-comms-slack-edit-message event-track RIG-BODY
rigAssert "edit-message on a conversation alias alone: refused, it names no message" "$rigOpRc:$( rigOpErrors ):$( LC_ALL=C grep -c -x 'chat.update' "$RIG_CURL_LOG" )" "1:⛔ ERROR: DistroAgentsTools --member-comms-slack-edit-message: a specific <ts> is required -- use <channel>:<ts>, or <alias>:<ts> for a message in the conversation an alias names:0"
rigAliasScene opMessageDelete
rigOp "$rigCurrent" --member-comms-slack-delete-message "session-current:$rigMessage" "magic-team:$rigMessage" session-parent
rigAssert "delete-message takes each: an alias with its message, and a session address alone" "$( LC_ALL=C grep -c -e "chat.delete channel=CSESS001 ts=$rigMessage " -e "chat.delete channel=CRIG00001 ts=$rigMessage " -e "chat.delete channel=CPARENT1 ts=${rigParent#*:} " "$rigScenarioDir/op.err" )" 3
: > "$RIG_CURL_LOG"
rigOp "$rigCurrent" --member-comms-slack-delete-message human-owner
rigAssert "delete-message on a conversation alias alone: refused, it names no message" "$rigOpRc:$( rigOpErrors | head -1 ):$( LC_ALL=C grep -c -x 'chat.delete' "$RIG_CURL_LOG" )" "1:⛔ ERROR: DistroAgentsTools --member-comms-slack-delete-message: a specific <ts> is required -- use <channel>:<ts>, or <alias>:<ts> for a message in the conversation an alias names. Nothing was deleted for 'human-owner'; the remaining targets are still attempted.:0"
rigAliasScene opMessageSendCurrent
rigOp "$rigCurrent" --member-comms-slack-send-message "session-current:$rigMessage" RIG-BODY
rigAssert "send to session-current:<ts>: a reply in the thread of that message" "$rigOpRc:$( rigPosts ):$( rigPostedTo "CSESS001:$rigMessage" )" "0:1:yes"
rigAliasScene opMessageSendTrack
rigOp "$rigCurrent" --member-comms-slack-send-message "event-track:$rigMessage" RIG-BODY
rigAssert "send to event-track:<ts>"                              "$rigOpRc:$( rigPosts ):$( rigPostedTo "CRIGTRACK:$rigMessage" )" "0:1:yes"
rigAliasScene opMessageSendAlert
rigOp "$rigCurrent" --member-comms-slack-send-message event-alert RIG-BODY
rigAssert "send to event-alert alone: a new message there, in no thread" "$rigOpRc:$( rigPosts ):$( rigHolds "$rigScenarioDir/post.1" '"channel":"CRIGALERT"' ):$( rigHolds "$rigScenarioDir/post.1" '"thread_ts"' )" "0:1:yes:no"

echo "-- a conversation alias whose setting is not there names nowhere, by the resolver's one line --"
rigAliasScene opNoSetting track
printf 'rig\n' > "$rigScenarioDir/share.txt"
: > "$RIG_CURL_LOG"
rigOp "$rigCurrent" --member-comms-slack-send-message event-alert RIG-BODY
rigAssert "send"                                                  "$rigOpRc:$( rigPosts ):$( rigOpErrors )" "1:0:⛔ ERROR: DistroAgentsTools --member-comms-slack-send-message: $rigNoAlert Nothing was sent."
rigOp "$rigCurrent" --member-comms-slack-read event-alert
rigAssert "read"                                                  "$rigOpRc:$( rigOpErrors )" "1:⛔ ERROR: DistroAgentsTools --member-comms-slack-read: $rigNoAlert"
rigOp "$rigCurrent" --member-comms-slack-react "event-alert:$rigMessage" eyes
rigAssert "react"                                                 "$rigOpRc:$( rigOpErrors )" "1:⛔ ERROR: DistroAgentsTools --member-comms-slack-react: $rigNoAlert"
rigOp "$rigCurrent" --member-comms-slack-edit-message "event-alert:$rigMessage" RIG-BODY
rigAssert "edit-message"                                          "$rigOpRc:$( rigOpErrors )" "1:⛔ ERROR: DistroAgentsTools --member-comms-slack-edit-message: $rigNoAlert"
rigOp "$rigCurrent" --member-comms-slack-delete-message "event-alert:$rigMessage"
rigAssert "delete-message"                                        "$rigOpRc:$( rigOpErrors | head -1 )" "1:⛔ ERROR: DistroAgentsTools --member-comms-slack-delete-message: $rigNoAlert Nothing was deleted for this target; the remaining targets are still attempted."
rigOp "$rigCurrent" --member-comms-slack-search-messages event-alert --comms-since-utime 1700000000
rigAssert "search-messages"                                       "$rigOpRc:$( rigOpErrors )" "1:⛔ ERROR: DistroAgentsTools --member-comms-slack-search-messages: $rigNoAlert"
rigOp "$rigCurrent" --member-comms-slack-file-share event-alert --from-file "$rigScenarioDir/share.txt"
rigAssert "file-share"                                            "$rigOpRc:$( rigOpErrors )" "1:⛔ ERROR: DistroAgentsTools --member-comms-slack-file-share: $rigNoAlert Nothing was uploaded."
rigAssert "none of them called Slack"                             "$( LC_ALL=C grep -c -v -x -e 'auth.test' -e 'conversations.info' "$RIG_CURL_LOG" )" 0
rigOp "$rigCurrent" --member-comms-slack-read event-track
rigAssert "control: the one that is set still resolves"           "$( rigOpErrors | LC_ALL=C grep -c 'names nowhere' )" 0

echo "-- where an alias cannot make sense it is refused, and the line says why --"
rigAliasScene opNoSense
: > "$RIG_CURL_LOG"
rigOp "$rigCurrent" --member-comms-slack-search-messages session-current --comms-since-utime 1700000000
rigAssert "search-messages with a session address: it names one thread, the search wants a whole conversation" "$rigOpRc:$( rigOpErrors )" "1:⛔ ERROR: DistroAgentsTools --member-comms-slack-search-messages: 'session-current' names one thread, and this operation searches a whole conversation over a time window, so a session address is refused here. To read that thread, use --member-comms-slack-read <team-member> session-current --thread."
rigOp "$rigCurrent" --member-comms-slack-search-messages "magic-team:$rigMessage" --comms-since-utime 1700000000
rigAssert "search-messages with <alias>:<ts>: one message, refused as <channel>:<ts> is" "$rigOpRc:$( rigOpErrors | LC_ALL=C grep -c "names one specific message (<channel>:<ts>), and this operation searches a whole conversation" )" "1:1"
rigOp "$rigCurrent" --member-comms-slack-file-info magic-team
rigAssert "file-info: a file is named by its id, never by a place" "$rigOpRc:$( rigOpErrors | LC_ALL=C grep -c "'magic-team' is not a Slack file id" )" "1:1"
rigOp "$rigCurrent" --member-comms-slack-file-fetch session-current "$rigScenarioDir/fetched"
rigAssert "file-fetch: the same, and nothing is written"          "$rigOpRc:$( rigOpErrors | LC_ALL=C grep -c "'session-current' is not a Slack file id" ):$( [ -e "$rigScenarioDir/fetched" ] && printf written || printf none )" "1:1:none"
rigAssert "none of them called Slack"                             "$( LC_ALL=C grep -c -v -x -e 'auth.test' -e 'conversations.info' "$RIG_CURL_LOG" )" 0

echo "-- the wait operation and the tools take <alias>:<ts> too --"
rigAliasScene opWaitMessage
rigOp "$rigCurrent" --member-wait-for-input --wait-source "slack:session-current:$rigMessage" --wait-timeout 1 --wait-since-utime "$rigMessage" --wait-addressee URIGOWNER
rigAssert "slack:session-current:<ts>: the thread of that message, for its answer" "$rigOpRc:$( LC_ALL=C sed -n '1p' "$rigScenarioDir/op.out" ):$( rigOpSources )" "0:WAIT-RESULT: TIMEOUT:slack:CSESS001:$rigMessage"
rigOp "$rigCurrent" --member-wait-for-input --wait-source "slack:session-parent:$rigMessage:conversation" --wait-timeout 1 --wait-since-utime 1700000100
rigAssert "slack:session-parent:<ts>:conversation: any new post in the thread of that message" "$rigOpRc:$( rigOpSources )" "0:slack:CPARENT1:$rigMessage:conversation"
rigOp "$rigCurrent" --member-wait-for-input --wait-source slack:session-current:conversation --wait-timeout 1 --wait-since-utime 1700000100
rigAssert "slack:session-current:conversation: the session thread, as the name alone" "$rigOpRc:$( rigOpSources )" "0:slack:$rigCurrent:conversation"
rigOp "" --member-wait-for-input --wait-source "slack:session-current:$rigMessage" --wait-timeout 1 --wait-since-utime "$rigMessage" --wait-addressee URIGOWNER
rigAssert "with no session thread: the one line"                  "$rigOpRc:$( rigOpErrors )" "1:⛔ ERROR: DistroAgentsTools --member-wait-for-input: $rigNoCurrent Nothing was waited on."
rigAliasScene toolMessageSend
rigCall "$rigCurrent" SendMessage "{\"to\":\"session-parent:$rigMessage\",\"message\":\"m\"}"
rigAssert "SendMessage to session-parent:<ts>: a reply in the thread of that message" "$( rigPosts )$( rigPostedTo "CPARENT1:$rigMessage" ):$( rigFirst )" "1yes:Sent to CPARENT1:$rigMessage (a message in the conversation of the thread of parent session rig-parent-id) as $rigMember. What the operation reported follows:"
rigAliasScene toolMessageAsk
rigCall "$rigCurrent" AskQuestion "{\"to\":\"session-current:$rigMessage\",\"address_to\":\"human-owner\",\"question\":\"May the rig go on?\",\"wait\":false}"
rigAssert "AskQuestion to session-current:<ts>: asked in the thread of that message" "$( rigPosts )$( rigPostedTo "CSESS001:$rigMessage" ):$( rigFirst )" "1yes:ASK-RESULT: POSTED"
rigAliasScene toolMessageTrack
rigCall "$rigCurrent" SendMessage "{\"to\":\"event-track:$rigMessage\",\"message\":\"m\"}"
rigAssert "SendMessage to event-track:<ts>"                       "$( rigPosts )$( rigPostedTo "CRIGTRACK:$rigMessage" )" 1yes
rigAliasScene toolAskAlert
rigCall "$rigCurrent" AskQuestion '{"to":"event-alert","address_to":"human-owner","question":"May the rig go on?","wait":false}'
rigAssert "AskQuestion to event-alert: asked there, as a new message" "$( rigPosts ):$( rigHolds "$rigScenarioDir/post.1" '"channel":"CRIGALERT"' ):$( rigFirst )" "1:yes:ASK-RESULT: POSTED"
rigAliasScene toolAskTrackBare
rigCall "$rigCurrent" AskQuestion '{"to":"event-track","question":"May the rig go on?","wait":false}'
rigAssert "AskQuestion to event-track with no address_to: a place has no party, so it is asked for" "$( rigPosts ):$( rigFirst | LC_ALL=C grep -c '^ERROR: AskQuestion: .*(event-track) rather than a party, so address_to is required' )" "0:1"
rigAliasScene toolNoSetting track
rigCall "$rigCurrent" SendMessage '{"to":"event-alert","message":"m"}'
rigAssert "SendMessage to an alias whose setting is not there: the resolver's line, nothing posted" "$( rigPosts ):$( LC_ALL=C grep -c -F -- "--member-comms-slack-send-message: $rigNoAlert Nothing was sent." "$rigScenarioDir/tool.out" )" "0:1"

echo "-- the harness resolves neither name itself --"
rigAssert "each name is spelled once in the harness, where it is given its variable" "$( LC_ALL=C grep -v '^[[:space:]]*##' "$rigHarness" | LC_ALL=C grep -c -e 'session-current' -e 'session-parent' ):$( LC_ALL=C grep -c -x -e 'harnessCurrentName="session-current"' -e 'harnessParentName="session-parent"' "$rigHarness" )" "2:2"
rigAssert "and it asks the one resolver"                          "$( LC_ALL=C grep -c 'DistroAgentsToolsResolveTarget "\$1"' "$rigHarness" )" 1
rigAssert "it reads no parent thread from a spawn record"         "$( LC_ALL=C grep -c -e '\^parent-thread: ' -e 'AgentsHarnessParentThread' "$rigHarness" )" 0

echo "-- the help of each operation and tool that takes an address lists both names --"
rigWire="$rigHere/AgentsOpenAiChatWire.sh"
for rigHelpTool in SendMessage SubagentHandback ReportFindings PushNotification Artifact AskQuestion ConfirmReadback EscalateDecision RequestPermission Wait ; do
	rigAssert "the tool $rigHelpTool" "$( LC_ALL=C grep -F -- "{\"type\":\"function\",\"function\":{\"name\":\"$rigHelpTool\"," "$rigWire" | LC_ALL=C awk '{ print ( index( $0, "session-current" ) > 0 ) ( index( $0, "session-parent" ) > 0 ) ; }' )" 11
done
rigManual="$rigHere/help/Help.DistroAgentsTools.help.md"
rigSyntax="$rigHere/help/Help.DistroAgentsTools.include"
for rigHelpOp in send-message read react ; do
	rigAssert "the syntax line of --member-comms-slack-$rigHelpOp" "$( LC_ALL=C grep -- "^echo \"📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-$rigHelpOp <team-member> " "$rigSyntax" | LC_ALL=C grep -c -e 'session-current|session-parent' )" 1
	rigAssert "the manual entry of --member-comms-slack-$rigHelpOp" "$( LC_ALL=C awk -v want="--member-comms-slack-$rigHelpOp" '
		/^\t\t--/ { split( $0, word, " " ) ; inEntry = ( word[1] == want ) ; }
		inEntry && /session-current/ { current = 1 ; }
		inEntry && /session-parent/ { parent = 1 ; }
		END { print current + 0 "" parent + 0 ; }' "$rigManual" )" 11
done
for rigHelpOp in delete-message edit-message ; do
	rigAssert "the syntax lines of --member-comms-slack-$rigHelpOp, each" "$( LC_ALL=C grep -- "^echo \"📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-$rigHelpOp <team-member> " "$rigSyntax" | LC_ALL=C grep -c -v -e '<channel>:<ts>|<alias>:<ts>|session-current|session-parent ' )" 0
done
for rigHelpOp in send-message read react delete-message edit-message ; do
	rigAssert "<alias>:<ts> in the syntax line and the manual entry of --member-comms-slack-$rigHelpOp" "$( LC_ALL=C grep -- "^echo \"📘 syntax: DistroAgentsTools.fn.sh --member-comms-slack-$rigHelpOp <team-member> " "$rigSyntax" | LC_ALL=C grep -c -F -e '<alias>:<ts>' | LC_ALL=C sed 's/^[1-9][0-9]*$/yes/' ):$( LC_ALL=C awk -v want="--member-comms-slack-$rigHelpOp" '
		/^\t\t--/ { split( $0, word, " " ) ; inEntry = ( word[1] == want ) ; }
		inEntry && /<alias>:<ts>/ { said = 1 ; }
		END { print said + 0 ; }' "$rigManual" )" "yes:1"
done
for rigHelpTool in SendMessage AskQuestion Wait ; do
	rigAssert "a name with :<ts> in the tool $rigHelpTool" "$( LC_ALL=C grep -F -- "{\"type\":\"function\",\"function\":{\"name\":\"$rigHelpTool\"," "$rigWire" | LC_ALL=C grep -c -F -e 'session-current:<ts>' -e 'slack:<name>:<ts>' )" 1
done
for rigHelpOp in --member-comms-slack-delete-message --member-comms-slack-edit-message --member-comms-slack-search-messages --member-comms-slack-file-share --member-wait-for-input ; do
	rigAssert "the manual entry of $rigHelpOp" "$( LC_ALL=C awk -v want="$rigHelpOp" '
		/^\t\t--/ { split( $0, word, " " ) ; inEntry = ( word[1] == want ) ; }
		inEntry && /session-current/ { current = 1 ; }
		inEntry && /session-parent/ { parent = 1 ; }
		END { print current + 0 "" parent + 0 ; }' "$rigManual" )" 11
done

echo "-- no model was called anywhere --"
rigAssert "no claude or codex call"                               "$( cat "$rigTmp/model-calls" 2>/dev/null | wc -l | tr -d ' ' )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SESSION ADDRESS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_ADDRESS: OK (%d assertions, offline, no model)\n' "$rigPassCount"
