#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on the cut-off the ingest gives its history read (task-20261124T1845Z-comms-reader-page-cap-never-drains).
## Held:
##   1. A FOLDER THAT HOLDS NO POINTER IS READ FROM ITS OWN NEWEST CACHED MESSAGE, not from the beginning. A cache folder's
##      `.state.txt` names the newest message it holds. When `.ingest.txt` is absent -- the state a folder reaches when no read
##      has ever completed -- the ingest takes that ts as its floor. A whole-history read is what walks into the page cap and
##      fails the whole sweep, so that floor is the cut-off which keeps the read short.
##   2. A FOLDER THAT HOLDS A POINTER IS READ FROM THE POINTER. The pointer is the ingest's own and outranks the state.
##   3. THE CONTROL: a folder holding neither still reads from the beginning, so a first ever read is not silently skipped.
## Red before the fix: arm 1's read carries no `oldest` form at all.
## Offline: a Slack-shaped fake curl of this check's own, first on PATH. It reads each form file the call names, so the floor the
## read asked for is read from the call itself and never from the reader's own words.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
## A RIG INHERITS ITS RUNNER'S SESSION, and this check must read none of it.
for rigDrop in ${!MDAT_SPAWN_@} MDAT_SESSION_ID MDAT_SESSION_THREAD MDAT_CONVERSATION_THREADS MDAT_WAIT_REMIND harnessSessionId harnessAgent CLAUDE_CODE_SESSION_ID ; do
	unset "$rigDrop" 2> /dev/null || :
done
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsCommsIngestCutoffCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigScn="$rigTmp/scn"
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigWs/.local/.agents" "$rigScn" "$rigTmp/skills/keeper-rig"
printf 'keeper-rig\n' > "$rigTmp/skills/keeper-rig/keeper-rig.basic.md"
printf 'SLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-RIG\n' > "$rigWs/.local/.agents/keeper-rig.agent.env"
printf 'first\n' > "$rigScn/pass"
## A Slack-shaped fake curl of this check's own. Each form travels as `name@<file>`, the file holding the value, so the floor the
## read asked for is read from the call it made. Every floor is logged against the method and the channel it was asked for.
cat > "$rigTmp/bin/curl" <<'FAKE'
#!/usr/bin/env bash
rigMethod="" rigChannel="" rigOldest=""
for rigArg in "$@" ; do
	case "$rigArg" in
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ; rigMethod="${rigMethod%%\?*}" ;;
	esac
done
for rigArg in "$@" ; do
	case "$rigArg" in
		*@*) rigForm="${rigArg%%@*}" rigFile="${rigArg#*@}"
			[ ! -f "$rigFile" ] || rigValue="$( LC_ALL=C sed -n '1p' "$rigFile" 2> /dev/null )"
			case "$rigForm" in
				oldest) rigOldest="$rigValue" ;;
				channel) rigChannel="$rigValue" ;;
			esac
		;;
	esac
done
printf '%s %s %s\n' "$rigMethod" "${rigChannel:--}" "${rigOldest:--}" >> "$RIG_SCN/floors"
cat > /dev/null
case "$rigMethod" in
	auth.test) printf '{"ok":true,"user_id":"URIGSELF1","bot_id":"BRIGBOT1"}\n' ;;
	conversations.info) printf '{"ok":true,"channel":{"id":"CRIG00001","is_im":false,"is_mpim":false}}\n' ;;
	conversations.history)
		printf '{"ok":true,"messages":[{"ts":"1793600009.000001","user":"URIGOTHER","text":"RIG-AFTER-FLOOR"}],"has_more":false,"response_metadata":{"next_cursor":""}}\n'
	;;
	conversations.replies) printf '{"ok":true,"messages":[],"has_more":false}\n' ;;
	conversations.list) printf '{"ok":true,"channels":[],"response_metadata":{"next_cursor":""}}\n' ;;
	*) printf '{"ok":false,"error":"rig_unhandled"}\n' ;;
esac
FAKE
chmod +x "$rigTmp/bin/curl"
[ "$( PATH="$rigTmp/bin:$PATH" command -v curl )" = "$rigTmp/bin/curl" ] || { echo "⛔ ERROR: the fake curl is not first on its PATH, so this check would issue real requests" >&2 ; exit 1 ; }
## THE SUBJECT HAS TO BE THERE. A check whose include is absent would report rows about nothing.
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
rigCacheDir="$rigWs/.local/cache/comms/slack/slack-CRIG00001"
## One pass of the ingest, its own workspace and its own fake Slack. It hands the ingest no folder: the ingest resolves the one
## folder of that channel itself, as the pass does, and the folder the rig planted is the one it must read from.
rigIngest(){
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		"MMDAPP=$rigWs" "MDLT_ORIGIN=$rigOrigin" "MDLT_OPTION=--run-from-path $rigOrigin" "MDAT_SKILLSET_ROOT=$rigTmp/skills" \
		"MDAT_DATA_ROOT=$rigScn/data" "RIG_SCN=$rigScn" "MDAT_SPAWN_AGENT=keeper-rig" "MDAT_COMMS_EVENT_ID_IDLE_SECONDS=3" \
		bash -c '. "$1" ; AgentsCommsIngestSlack keeper-rig CRIG00001' _ "$rigInclude" ) > "$rigScn/ingest.out" 2> "$rigScn/ingest.err"
}
## The floor the history read asked for, as the fake curl took it: the `oldest` value, or `none` where no floor was asked.
rigFloor(){
	LC_ALL=C awk '$1 == "conversations.history" { if ($3 != "-") { print $3 ; found = 1 ; } } END { if (!found) print "none" ; }' "$rigScn/floors" 2> /dev/null
}
rigReset(){ ## one cache folder, made fresh for an arm, holding the cached message the state will name
	rm -rf "$rigCacheDir" ; mkdir -p "$rigCacheDir/202611" || return 1
	: > "$rigScn/floors"
	printf 'RIG-CACHED\n' > "$rigCacheDir/202611/messages.txt"
}
rigState(){ ## the newest cached ts the folder claims
	printf '1795535905 0 1795535905.335679\n## target=CRIG00001 channel=CRIG00001\nslack-conversation CRIG00001 keeper-rig false\n' > "$rigCacheDir/.state.txt"
}

echo "-- 1. a folder that holds no pointer is read from its own newest cached message --"
rigReset ; rigState
rigIngest ; rigRc=$?
rigAssert "the pass ran" "$rigRc" 0
rigAssert "control: it reached the conversation at all" "$( LC_ALL=C awk '$1 == "conversations.history" { n++ } END { print n + 0 ; }' "$rigScn/floors" 2> /dev/null )" 1
rigAssert "and its read asked for a floor: the newest message the folder holds, not the beginning" "$( rigFloor )" "1795535905.335679"

echo "-- 2. a folder that holds a pointer is read from the pointer --"
rigReset ; rigState
printf '20261124T120000000Z-000000A01\n' > "$rigCacheDir/.ingest.txt"
rigIngest
## The pointer names an event id, and `AgentsCommsIngestSlackTs` steps it back by one read's bound so a message made while a pass
## ran is read again rather than lost. That is the rule, and the expectation is taken from it rather than typed in.
rigPointerFloor="$( MDLT_ORIGIN="$rigOrigin" bash -c '. "'"$rigInclude"'" ; AgentsCommsIngestSlackTs 20261124T120000000Z-000000A01' )"
rigAssert "the pointer's own moment is the floor, and it outranks the state" "$( rigFloor )" "$rigPointerFloor"

echo "-- 3. control: a folder holding neither still reads from the beginning --"
rigReset
rigIngest
rigAssert "no floor is asked for a first ever read" "$( rigFloor )" "none"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ COMMS INGEST CUTOFF CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'COMMS_INGEST_CUTOFF: OK (%d assertions, offline)\n' "$rigPassCount"
