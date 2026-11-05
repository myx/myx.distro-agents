#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on the comms source ingest for one Slack source (S1.12 stage 2, §2, §3 and §4): one pass writes the
## events its read holds that the store does not, appends them to YYYYMM/events.txt, and moves the ingest pointer to the
## last id it wrote. Held:
##   1. a first pass writes the message, its mark, its thread summary, its reply author and its reply as events
##   2. every event has its own id, and the file's order is its ids' order
##   3. the pointer is the last id in the file, and is the EventIdentifier form
##   3b. the ids come from the on-demand thread, which reads its origin once for its whole life
##   3c. two batches inside one second sort as time: the later one's ids all follow the earlier one's, and its sequence
##       carries on rather than restarting at nought. This is the row the thread exists for.
##   3d. the Slack floor steps back by one read's bound, so a message created while a pass ran is re-read, not lost
##   4. a second pass with nothing new writes not one line
##   5. a mark the store holds and the read no longer carries is one `rx-` event, once
##   6. a pass costs one history call and one replies call, and a quiet pass one history call and no replies call
##   7. a failed read leaves the pointer where it was
##   8. a text over the threshold keeps a short head inline and its whole body in the file its last column names
## Offline: a Slack-shaped fake curl first on PATH, which counts every call it answers.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
## A RIG INHERITS ITS RUNNER'S SESSION, and this check must read none of it.
for rigDrop in ${!MDAT_SPAWN_@} MDAT_SESSION_ID MDAT_SESSION_THREAD MDAT_CONVERSATION_THREADS MDAT_WAIT_REMIND harnessSessionId harnessAgent CLAUDE_CODE_SESSION_ID ; do
	unset "$rigDrop" 2> /dev/null || :
done
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigTools="$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
[ -f "$rigTools" ] || { echo "⛔ ERROR: the tool is not at the origin this workspace resolves: $rigTools" >&2 ; exit 1 ; }
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
## The one way a check signals a process it did not start itself: the id thread is one.
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsCommsIngestCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## THE RIG ENDS WHAT IT STARTED: the id thread the ingest starts is a process of its own, and a rig that left one
## running would leave it behind on the machine. Its lock names its pid, and TERM is how it ends.
## THE THREAD THE RIG STARTS IS THE RIG'S TO END. Its idle bound is short, so it goes by itself; one still there is noted
## and signalled the one safe way sh-test signals a process it did not start.
rigThreadPids(){
	LC_ALL=C awk '/the thread runs as pid/ { for (i = 1 ; i < NF ; i++) if ($i == "pid") { print $(i + 1) } }' \
		"$rigWs/.local/cache/comms/.event-id/thread.log" 2> /dev/null | LC_ALL=C tr -d ':,' | LC_ALL=C awk '/^[0-9]+$/'
}
rigEndThreads(){
	local rigWaited=0 rigAlive=1 rigPid
	while [ "$rigWaited" -lt 25 ] ; do
		rigAlive=0
		for rigPid in $( rigThreadPids ) ; do
			LC_ALL=C ps -o pid= -p "$rigPid" 2> /dev/null | LC_ALL=C grep -q . && rigAlive=1
		done
		[ "$rigAlive" = 1 ] || break
		sleep 1 ; rigWaited=$(( rigWaited + 1 ))
	done
	[ "$rigAlive" = 1 ] || return 0
	rigProcNote $( rigThreadPids )
	rigProcSignalWithChildren KILL $( rigThreadPids )
}
trap 'rigEndThreads ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigScn="$rigTmp/scn"
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigWs/.local/.agents" "$rigScn" "$rigTmp/skills/keeper-rig"
printf 'keeper-rig\n' > "$rigTmp/skills/keeper-rig/keeper-rig.basic.md"
printf 'SLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-RIG\n' > "$rigWs/.local/.agents/keeper-rig.agent.env"
printf '0\n' > "$rigScn/pass"
## A 5,000-byte text, made once: over the 2,000-byte threshold, and with no TAB and no backslash in it, so the escapes of
## the form play no part in this check's answer.
LC_ALL=C awk 'BEGIN { for (i = 0 ; i < 5000 ; i++) printf "x" ; printf "\n" }' > "$rigScn/longtext"

## A Slack-shaped fake curl of this check's own: what it answers is $rigScn/pass, so the only difference between two passes
## is the one this check is making. `gone` is the same read with its mark taken away, and `long` is one message over the cap.
cat > "$rigTmp/bin/curl" <<'FAKE'
#!/usr/bin/env bash
rigMethod=""
for rigArg in "$@" ; do
	case "$rigArg" in
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ; rigMethod="${rigMethod%%\?*}" ;;
	esac
done
printf '%s\n' "$rigMethod" >> "$RIG_SCN/calls"
rigRead="$( cat "$RIG_SCN/pass" 2> /dev/null )"
case "$rigMethod" in
	auth.test) printf '{"ok":true,"user_id":"URIGSELF1","bot_id":"BRIGBOT1"}\n' ;;
	conversations.info) printf '{"ok":true,"channel":{"id":"CRIG00001","is_im":false,"is_mpim":false}}\n' ;;
	conversations.history)
		if [ "$rigRead" = "fail" ] ; then printf '{"ok":false,"error":"rig_refused"}\n' ; exit 0 ; fi
		if [ "$rigRead" = "long" ] ; then
			printf '{"ok":true,"messages":[{"ts":"1793600000.000009","user":"URIGOTHER","text":"'
			LC_ALL=C tr -d '\n' < "$RIG_SCN/longtext"
			printf '"}],"has_more":false,"response_metadata":{"next_cursor":""}}\n'
			exit 0
		fi
		printf '{"ok":true,"messages":[{"ts":"1793600000.000001","user":"URIGOTHER","text":"RIG-FIRST","reply_count":1,"latest_reply":"1793600000.000002","reply_users":["URIGOTHER"],'
		if [ "$rigRead" != "gone" ] ; then printf '"reactions":[{"name":"eyes","count":1,"users":["URIGSELF1"]}],' ; fi
		printf '"x":0},'
		if [ "$rigRead" = "again" ] ; then printf '{"ts":"1793600009.000001","user":"URIGOTHER","text":"RIG-SECOND"},' ; fi
		printf '{"ts":"1793600000.000002","user":"URIGBOT","bot_id":"BRIGBOT1","text":"RIG-REPLY","thread_ts":"1793600000.000001"}],"has_more":false,"response_metadata":{"next_cursor":""}}\n'
	;;
	conversations.replies)
		printf '{"ok":true,"messages":[{"ts":"1793600000.000001","user":"URIGOTHER","text":"RIG-FIRST",'
		if [ "$rigRead" != "gone" ] ; then printf '"reactions":[{"name":"eyes","count":1,"users":["URIGSELF1"]}],' ; fi
		printf '"x":0},{"ts":"1793600000.000002","user":"URIGBOT","bot_id":"BRIGBOT1","text":"RIG-REPLY","thread_ts":"1793600000.000001"}],"has_more":false}\n'
	;;
	conversations.list) printf '{"ok":true,"channels":[],"response_metadata":{"next_cursor":""}}\n' ;;
	*) printf '{"ok":false,"error":"rig_unhandled"}\n' ;;
esac
FAKE
chmod +x "$rigTmp/bin/curl"

## THE SUBJECT HAS TO BE THERE. A check whose include is absent would report rows about nothing: the empty store, the
## pointer that was never written and the read that never happened all look alike from here.
rigInclude="$rigOrigin/myx/myx.distro-agents/sh-lib/comms/AgentsTools.CommsIngest.include"
[ -f "$rigInclude" ] || { echo "⛔ ERROR: the comms ingest is not at the origin this workspace resolves: $rigInclude" >&2 ; exit 1 ; }

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigCalls(){ LC_ALL=C wc -l < "$rigScn/calls" 2> /dev/null | LC_ALL=C tr -d ' ' ; }
rigCallsOf(){ LC_ALL=C grep -c -x -F -e "$1" "$rigScn/calls" 2> /dev/null | LC_ALL=C tr -d ' ' ; }
rigCacheDir="$rigWs/.local/cache/comms/slack/slack-CRIG00001"

## One pass of the ingest, its own workspace and its own fake Slack: the include sourced where the rig's workspace is, and
## its one function called. The pass runs in a subshell of this shell, so nothing of it outlives the rig.
rigIngest(){ ## the output files of the pass -- the ingest's rc
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		"MMDAPP=$rigWs" "MDLT_ORIGIN=$rigOrigin" "MDLT_OPTION=--run-from-path $rigOrigin" "MDAT_SKILLSET_ROOT=$rigTmp/skills" \
		"MDAT_DATA_ROOT=$rigScn/data" "RIG_SCN=$rigScn" "MDAT_SPAWN_AGENT=keeper-rig" "MDAT_COMMS_EVENT_ID_IDLE_SECONDS=3" \
		bash -c '. "$1" ; AgentsCommsIngestSlack keeper-rig CRIG00001' _ "$rigInclude" ) > "$rigScn/ingest.out" 2> "$rigScn/ingest.err"
}
rigEvents(){ LC_ALL=C cat "$1"/[0-9][0-9][0-9][0-9][0-9][0-9]/events.txt 2> /dev/null ; }
rigEventCount(){ rigEvents "$rigCacheDir" | LC_ALL=C awk 'NF' | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ; }
rigKinds(){ rigEvents "$rigCacheDir" | LC_ALL=C awk -F'\t' '{ print $2 }' | LC_ALL=C sort | LC_ALL=C uniq | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' ; }

echo "-- 1. a first pass writes the events its read holds --"
printf 'first\n' > "$rigScn/pass"
: > "$rigScn/calls"
rigIngest
rigAssert "the pass ran" "$?" 0
rigAssert "the message, its mark, its thread, its reply author and its reply, as one of each" "$( rigKinds )" "msg rx thr thru"
rigAssert "the store holds five events" "$( rigEventCount )" 5

echo "-- 2. every event has its own id, and the file's order is its ids' order --"
rigIds="$( rigEvents "$rigCacheDir" | LC_ALL=C cut -f1 )"
rigAssert "every id is 29 characters" "$( printf '%s\n' "$rigIds" | LC_ALL=C awk 'length($0) != 29 { n++ } END { print n + 0 }' )" 0
rigAssert "no two ids are the same" "$( printf '%s\n' "$rigIds" | LC_ALL=C sort -u | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 5
rigAssert "the file's order is plain string order of its ids" "$( printf '%s\n' "$rigIds" | LC_ALL=C sort | cmp -s - <( printf '%s\n' "$rigIds" ) && printf sorted || printf unsorted )" sorted
rigAssert "every id carries the EventIdentifier date-time part" "$( printf '%s\n' "$rigIds" | LC_ALL=C awk '$0 !~ /^[0-9]{8}T[0-9]{9}Z-[0-9]{6}[0-9A-F]{3}$/ { n++ } END { print n + 0 }' )" 0

echo "-- 3. the pointer is the last id in the file --"
rigAssert "the pointer names the file's last event" "$( LC_ALL=C cat "$rigCacheDir/.ingest.txt" 2> /dev/null )" "$( printf '%s\n' "$rigIds" | LC_ALL=C tail -1 )"

echo "-- 3b. the ids come from the thread, one origin for its whole life --"
rigAssert "the thread ran for the passes above" "$( LC_ALL=C grep -c -F -e "the thread runs as pid" "$rigWs/.local/cache/comms/.event-id/thread.log" 2> /dev/null | LC_ALL=C tr -d ' ' )" 1
rigAssert "and reports no error of its own" "$( LC_ALL=C grep -c -F -e "command not found" -e "⛔ ERROR" "$rigWs/.local/cache/comms/.event-id/thread.log" 2> /dev/null | LC_ALL=C tr -d ' ' )" 0
rigAssert "every id of a batch carries the thread's one origin" "$( rigEvents "$rigCacheDir" | LC_ALL=C cut -f1 | LC_ALL=C cut -c27-29 | LC_ALL=C sort -u | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 1

echo "-- 3c. two batches inside one second: the later batch's ids all sort after the earlier batch's, no id repeats --"
rigEarlier="$( rigEvents "$rigCacheDir" | LC_ALL=C cut -f1 )"
printf 'again\n' > "$rigScn/pass"
rigIngest
rigAssert "the second pass ran" "$?" 0
rigLater="$( rigEvents "$rigCacheDir" | LC_ALL=C awk -F'\t' '$3 == "1793600009.000001" { print $1 }' )"
rigAssert "the second pass wrote its one new message" "$( printf '%s\n' "$rigLater" | LC_ALL=C awk 'NF' | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 1
## THE ORDER COMES FROM THE THREAD, ONE WAY OR THE OTHER: inside one millisecond the sequence carries on past what the
## earlier batch used, and a thread whose clock has turned starts again at nought under a later millisecond.
rigAssert "and the later id either carries the sequence on or takes a later millisecond" "$( rigEvents "$rigCacheDir" | LC_ALL=C awk -F'\t' -v second="$rigLater" '
	$1 == second { newMs = substr($1, 1, 19) ; newSeq = substr($1, 21, 6) + 0 ; next }
	{ thisMs = substr($1, 1, 19) ; if (thisMs > lastMs) lastMs = thisMs ; lastSeq = substr($1, 21, 6) + 0 }
	END {
		if (newMs == "" || lastMs == "") { print "broken" ; exit }
		if (newMs == lastMs) { print (newSeq == lastSeq + 1 ? "ordered" : "broken") ; exit }
		print (newMs > lastMs && newSeq == 0 ? "ordered" : "broken")
	}' )" ordered
rigAssert "every id of the later pass is greater than every id of the earlier one" "$( printf '%s\n' "$rigLater" | LC_ALL=C awk -v floor="$( printf '%s\n' "$rigEarlier" | LC_ALL=C sort | LC_ALL=C tail -1 )" '{ if (!($0 > floor)) bad = 1 } END { print (bad ? "no" : "yes") }' )" yes
rigAssert "and no id of the two passes repeats" "$( rigEvents "$rigCacheDir" | LC_ALL=C cut -f1 | LC_ALL=C sort | LC_ALL=C uniq -d | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 0

echo "-- 3d. the Slack floor steps back by one read's bound, so a straddling message is re-read --"
rigFloorId="20261104T120000500Z-00000000A"
rigFloorPlain="$( ( cd "$rigWs" && env -i MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" "MDAT_SKILLSET_ROOT=$rigTmp/skills" HOME="$rigTmp/home" \
	PATH="/usr/bin:/bin:/usr/sbin:/sbin" bash -c '. "$1" ; AgentsCommsIngestSlackTs "$2"' _ "$rigInclude" "$rigFloorId" ) 2> /dev/null )"
rigFloorStepped="$( ( cd "$rigWs" && env -i MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" "MDAT_SKILLSET_ROOT=$rigTmp/skills" HOME="$rigTmp/home" \
	MDAT_SLACK_READ_BOUND_SECONDS=120 PATH="/usr/bin:/bin:/usr/sbin:/sbin" bash -c '. "$1" ; AgentsCommsIngestSlackTs "$2"' _ "$rigInclude" "$rigFloorId" ) 2> /dev/null )"
rigFloorZero="$( ( cd "$rigWs" && env -i MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" "MDAT_SKILLSET_ROOT=$rigTmp/skills" HOME="$rigTmp/home" \
	MDAT_SLACK_READ_BOUND_SECONDS=0 PATH="/usr/bin:/bin:/usr/sbin:/sbin" bash -c '. "$1" ; AgentsCommsIngestSlackTs "$2"' _ "$rigInclude" "$rigFloorId" ) 2> /dev/null )"
rigAssert "the control: with the bound at nought the floor is the id's own second" "$( printf '%s' "$rigFloorZero" | LC_ALL=C cut -d. -f1 )" 1793793600
rigAssert "with the bound at 120 the floor is 120 seconds earlier, so the window is re-read" "$( printf '%s' "$rigFloorStepped" | LC_ALL=C cut -d. -f1 )" 1793793480
rigAssert "and unset, the floor takes the read's own default of 120" "$( printf '%s' "$rigFloorPlain" | LC_ALL=C cut -d. -f1 )" 1793793480

echo "-- 4. a second pass with nothing new writes not one line --"
printf 'quiet\n' > "$rigScn/pass"
rigIngest
rigAssert "the quiet pass ran" "$?" 0
rigAssert "the store still holds the events it held" "$( rigEventCount )" 6

echo "-- 5. a mark the read no longer carries is one rx- event --"
printf 'gone\n' > "$rigScn/pass"
rigIngest
rigAssert "the store gained the removal, and nothing else" "$( rigKinds )" "msg rx rx- thr thru"
rigAssert "and it is one event" "$( rigEventCount )" 7

echo "-- 6. what a pass costs, against today's 72 calls over 19 conversations --"
printf 'first\n' > "$rigScn/pass"
rm -rf "$rigWs/.local/cache/comms"
: > "$rigScn/calls"
rigIngest
rigAssert "a first pass reads the history once" "$( rigCallsOf conversations.history )" 1
rigAssert "and the one thread its history named, once" "$( rigCallsOf conversations.replies )" 1
rigAssert "and makes no other call" "$( rigCalls )" 2
printf 'quiet\n' > "$rigScn/pass"
: > "$rigScn/calls"
rigIngest
rigAssert "a pass with nothing new reads the history once" "$( rigCallsOf conversations.history )" 1
rigAssert "and reads no thread at all" "$( rigCallsOf conversations.replies )" 0
rigAssert "so a quiet pass costs one call, not 72" "$( rigCalls )" 1

echo "-- 7. a failed read leaves the pointer where it was --"
rigPointerBefore="$( LC_ALL=C cat "$rigCacheDir/.ingest.txt" 2> /dev/null )"
rigCountBefore="$( rigEventCount )"
printf 'fail\n' > "$rigScn/pass"
rigIngest
rigAssert "the failed pass says so" "$?" 1
rigAssert "the pointer did not move" "$( LC_ALL=C cat "$rigCacheDir/.ingest.txt" 2> /dev/null )" "$rigPointerBefore"
rigAssert "and nothing was written" "$( rigEventCount )" "$rigCountBefore"

echo "-- 8. a text over the threshold is cut to a head, and its body is the file the last column names --"
printf 'long\n' > "$rigScn/pass"
rm -rf "$rigWs/.local/cache/comms"
rigIngest
rigLongRow="$( rigEvents "$rigCacheDir" | LC_ALL=C awk -F'\t' '$2 == "msg" { print ; exit }' )"
rigBodyName="$( printf '%s' "$rigLongRow" | LC_ALL=C awk -F'\t' '{ print $16 }' )"
rigHead="$( printf '%s' "$rigLongRow" | LC_ALL=C awk -F'\t' '{ print $7 }' )"
rigBodyFile="$( LC_ALL=C find "$rigCacheDir" -name "$rigBodyName" 2> /dev/null | LC_ALL=C head -1 )"
rigAssert "the line names a body file" "$( [ -n "$rigBodyName" ] && printf named || printf none )" named
rigAssert "the body file is there, in the same month folder" "$( [ -n "$rigBodyFile" ] && printf there || printf absent )" there
rigAssert "the head kept is 400 bytes" "${#rigHead}" 400
rigAssert "the body holds the whole text" "$( [ -n "$rigBodyFile" ] && LC_ALL=C wc -c < "$rigBodyFile" 2> /dev/null | LC_ALL=C tr -d ' ' || printf absent )" 5001

printf '\n  %s passed, %s failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" -eq 0 ] || exit 1
printf 'COMMS_INGEST: OK\n'
