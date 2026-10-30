#!/usr/bin/env bash
## AgentsMentionsOtherLiveSessionCheck -- sketch 7.4: a post addressed to a member in ANOTHER session's own
## thread, where that other session has its own live instance of the same member, is today returned a second
## time by this session's own `mentions:<member>` probe (AgentsWaitProbeMentions, AgentsTools.MemberWait.include).
## That probe already excludes a mention in THIS session's own thread (probeChatThread, line ~1713) and in
## any source this same wait already covers (agentsWaitCovered) -- but nothing in it knows about a SIBLING
## session of the same member, so a mention sitting in that sibling's own thread is not excluded and is
## delivered again here, on top of whatever the sibling's own chat floor already gave it.
## Held, run and not read:
##   1. THE BUG, REPRODUCED: two live sessions of one member, A (this one, probing) and B (another, with its
##      own thread). A message addressed to the member sits only in B's thread. A's own mentions probe
##      returns it -- a duplicate of what B's own chat floor already delivers to the member there.
##   2. NORMAL CASE: a mention in neither this session's own thread nor any live sibling's is returned, as
##      today.
##   3. A SECOND RECORD OF THE SAME THREAD, under a different session-id (a child spawned into the same
##      thread, a resumed run), must not make the exclusion treat that thread as "a sibling's, not mine":
##      probed as the thread's own owning session, its own mention is still kept (load incident 2026-10-30:
##      the fix in 1/2 excluded by session-id alone, and a session lost mentions in its own thread this way).
## Offline: a Slack-shaped fake curl is first on PATH, every workspace is a folder of the rig's own, and the
## only "live" thing is a stand-in `sleep`, noted through the rig's own process helper.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHere/member/AgentsTools.MemberWait.include" ] || rigRefuse "the wait include is missing"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsMentionsOtherLiveSessionCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
trap 'rigProcSignalWithChildren KILL $rigStarted ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
cat > "$rigTmp/bin/curl" <<-'CURLEOF'
	#!/usr/bin/env bash
	set -u
	cat > /dev/null
	fixUrl=""
	for fixArg in "$@" ; do case "$fixArg" in https://*) fixUrl="$fixArg" ;; esac ; done
	fixMethod="${fixUrl#https://slack.com/api/}" ; fixMethod="${fixMethod%%\?*}"
	case "$fixMethod" in
		search.messages)
			printf '{"ok":true,"messages":{"total":1,"paging":{"page":1,"pages":1,"count":100},"matches":[{"ts":"%s","user":"URIGHUM1","text":"RIG-MENTION-IN-B","permalink":"https://rig.invalid/archives/%s/p%s?thread_ts=%s&cid=%s"}]}}\n' \
				"$RIG_MATCH_TS" "$RIG_MATCH_CHANNEL" "${RIG_MATCH_TS//./}" "$RIG_ROOT_TS" "$RIG_MATCH_CHANNEL"
		;;
		*) printf '{"ok":false,"error":"fixture_unknown_method"}\n' ;;
	esac
	exit 0
CURLEOF
chmod +x "$rigTmp/bin/curl"
rigPath="$rigTmp/bin:$PATH"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigTextHas(){ ## haystack, needle
	case "$1" in *"$2"*) printf yes ;; *) printf no ;; esac
}

rigNow="$( date +%s )"
## The mention must be a REPLY inside B's thread, not the thread's own root: the exclusion this fix extends
## (like the existing probeChatThread one) matches a reply's own `[thread-reply of <root-ts>]` annotation
## against `<channel>:<root-ts>`, the same shape a session's own thread is kept in -- a message that IS the
## root carries no such annotation at all, and was never what either exclusion was built to catch.
rigRootTs="$(( rigNow - 400 )).000001"
rigMatchTs="$(( rigNow - 100 )).000001"
rigMatchChannel="CRIGSES02"
rigThreadB="$rigMatchChannel:$rigRootTs"
rigDir="$rigTmp/ws"
rm -rf "$rigDir"
mkdir -p "$rigDir/.local/agents/sessions/rig-sess-a" "$rigDir/.local/agents/sessions/rig-sess-b" "$rigDir/.local/agents/spawned/spawnA" "$rigDir/.local/agents/spawned/spawnB" "$rigDir/.local/.agents" "$rigDir/.local/temp"
printf 'SLACK_USER_TOKEN=rig-user-token-MEMBER\n' > "$rigDir/.local/.agents/rig-member.agent.env"
printf 'CRIGSES01:%s\n' "$(( rigNow - 400 )).000001" > "$rigDir/.local/agents/sessions/rig-sess-a/session.thread"
printf '%s\n' "$rigThreadB" > "$rigDir/.local/agents/sessions/rig-sess-b/session.thread"

## A real, harmless background process stands in for each session's own live run, noted through the rig's
## own process helper (never a raw pid kept past when it is still itself).
sleep 600 > /dev/null 2>&1 < /dev/null & rigPidA=$!
rigProcNote "$rigPidA" ; rigStarted="$rigStarted $rigPidA" ; disown "$rigPidA" 2> /dev/null || :
sleep 600 > /dev/null 2>&1 < /dev/null & rigPidB=$!
rigProcNote "$rigPidB" ; rigStarted="$rigStarted $rigPidB" ; disown "$rigPidB" 2> /dev/null || :
rigBegan(){ ## pid
	MMDAPP="$rigDir" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c ". '$rigHere/team-data/AgentsTools.Registries.include' ; printf '%s\n' '$1' | AgentsToolsRegistryProcessesBegan"
}
rigBeganA="$( rigBegan "$rigPidA" )"
rigBeganB="$( rigBegan "$rigPidB" )"
cat > "$rigDir/.local/agents/spawned/spawnA/spawnA.spawn.md" <<-EOF
	---
	session-id: rig-sess-a
	spawn-id: spawnA
	host: $( hostname -s )
	workspace: rigws
	owner: rig-member
	status: spawn-started
	started-at: 2026-10-30 08:00 +0200
	run-process: $rigBeganA
	session-thread: CRIGSES01:$(( rigNow - 400 )).000001
	---

	# fake live record, session A (the probing one)
	EOF
cat > "$rigDir/.local/agents/spawned/spawnB/spawnB.spawn.md" <<-EOF
	---
	session-id: rig-sess-b
	spawn-id: spawnB
	host: $( hostname -s )
	workspace: rigws
	owner: rig-member
	status: spawn-started
	started-at: 2026-10-30 08:00 +0200
	run-process: $rigBeganB
	session-thread: $rigThreadB
	---

	# fake live record, session B (the sibling, with its own thread)
	EOF

rigProbe(){ ## session id probing
	local probeFile
	probeFile="$( mktemp "$rigDir/probe.XXXXXX" )" ; rm -f "$probeFile"
	env -u MDAT_SESSION_THREAD -u MDAT_SPAWN_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u MDAT_CONVERSATION_THREADS -u MDAT_SPAWN_AGENT \
		MMDAPP="$rigDir" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SESSION_ID="$1" PATH="$rigPath" \
		RIG_MATCH_TS="$rigMatchTs" RIG_MATCH_CHANNEL="$rigMatchChannel" RIG_ROOT_TS="$rigRootTs" \
		bash -c ". '$rigHere/member/AgentsTools.MemberWait.include' ; AgentsWaitProbeMentions rig-member rig-member $(( rigNow - 300 )) '$probeFile'" > "$probeFile.log" 2>&1
	cat "$probeFile" 2> /dev/null
	rm -f "$probeFile" "$probeFile.log" "$probeFile.found" "$probeFile.err" "$probeFile.permission"
}

echo "-- 1. the bug, reproduced: a mention sitting only in sibling session B's own thread is still returned to A --"
rigOut="$( rigProbe rig-sess-a )"
rigAssert "THE FIX (not yet built): a mention in a live sibling's own thread must NOT be returned here too" \
	"$( rigTextHas "$rigOut" RIG-MENTION-IN-B )" no

echo "-- 2. same scene, probed from B's own session: its own mention, kept --"
rigOut2="$( rigProbe rig-sess-b )"
rigAssert "the session whose own thread this is still gets it (nothing here should ever suppress that)" \
	"$( rigTextHas "$rigOut2" RIG-MENTION-IN-B )" yes

echo "-- 3. a second record of B's own thread, a different session-id, does not make B lose its own mention --"
## Clears the TTL this same session's own probe just set (mentions-checked:rig-member, line 2 above), so this
## third probe searches again instead of reading its own round's own "checked within the TTL" skip as if it
## were the fix's own exclusion -- a test-rig artifact of reusing one session twice, not the code under test.
MMDAPP="$rigDir" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c ". '$rigHere/session/AgentsTools.SessionChat.include' ; AgentsToolsSessionChatPointerSet rig-sess-b mentions-checked:rig-member 0"
cat > "$rigDir/.local/agents/spawned/spawnB/spawnBChild.spawn.md" <<-EOF
	---
	session-id: rig-sess-b-child
	spawn-id: spawnBChild
	host: $( hostname -s )
	workspace: rigws
	owner: rig-member
	status: spawn-started
	started-at: 2026-10-30 08:00 +0200
	run-process: $rigBeganB
	session-thread: $rigThreadB
	---

	# fake live record, a child of session B sharing its own thread, a different session-id
	EOF
rigOut3="$( rigProbe rig-sess-b )"
rigAssert "THE FIX: B's own mention survives a second record of its own thread under another session-id" \
	"$( rigTextHas "$rigOut3" RIG-MENTION-IN-B )" yes

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MENTIONS OTHER LIVE SESSION CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MENTIONS_OTHER_LIVE_SESSION: OK (%d assertions, offline)\n' "$rigPassCount"
