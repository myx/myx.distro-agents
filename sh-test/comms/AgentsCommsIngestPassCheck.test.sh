#!/usr/bin/env bash
# ^^^ for syntax checking in the editor only
##
## Behavioural check on the cadence of the comms source ingest (S1.12 stage 3, item 12 and standing ruling 14): each due channel source
## the comms store covers is ingested by --intern-comms-ingest on the comms reader's own pass, and a source is read only when a pull
## brought something its ingest has not read. Held:
##   0. the control: the rig's store holds the channel sources this check wrote, and the fake records every call
##   1. a due channel source is ingested: its events are written, and its pointer is the last id it wrote in the EventIdentifier form
##   2. a source whose state has not moved since its ingest is not read again, and one pulled since it is read again
##   3. a source read as the bot is skipped, and no folder of that account is written
##   4. a source whose read failed leaves its pointer where it was and writes no event
##   5. the pass stops at its budget, and the next pass starts after the source it served last
##   6. a channel folder whose state names no recipe is skipped
## Offline: a Slack-shaped fake curl first on PATH, which records every API method it answers.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
## A RIG INHERITS ITS RUNNER'S SESSION, and this check must read none of it.
for rigDrop in ${!MDAT_SPAWN_@} MDAT_SESSION_ID MDAT_SESSION_THREAD MDAT_CONVERSATION_THREADS MDAT_WAIT_REMIND harnessSessionId harnessAgent CLAUDE_CODE_SESSION_ID ; do
	unset "$rigDrop" 2> /dev/null || :
done
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsCommsIngestPassCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" 2> /dev/null || : ; chmod -R u+rwX "$rigTmp" 2> /dev/null || : ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigScn="$rigTmp/scn" rigStore="$rigWs/.local/cache/comms/slack" rigState="$rigWs/.local/cache/comms/.ingest-pass"
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigTmp/skills/keeper-rig" "$rigScn" "$rigStore" "$rigWs/.local/.agents"
printf 'keeper-rig\n' > "$rigTmp/skills/keeper-rig/keeper-rig.basic.md"
printf 'SLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-RIG\n' > "$rigWs/.local/.agents/keeper-rig.agent.env"

## THE SUBJECT HAS TO BE THERE. A check whose include is absent would report rows about nothing: an empty store, a pointer never written
## and a pass that never ran all look alike from here.
rigInclude="$rigOrigin/myx/myx.distro-agents/sh-lib/comms/AgentsTools.CommsIngestPass.include"
[ -f "$rigInclude" ] || { echo "⛔ ERROR: the ingest pass is not at the origin this workspace resolves: $rigInclude" >&2 ; exit 1 ; }

## A SLACK-SHAPED FAKE of this check's own: one message a channel, and a channel whose read is refused. The method it answers is kept, so
## a row can count the channel reads a pass made.
cat > "$rigTmp/bin/curl" <<'FAKE'
#!/usr/bin/env bash
rigMethod="" rigChan="" rigPrev=""
for rigArg in "$@" ; do
	case "$rigArg" in
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ; rigMethod="${rigMethod%%\?*}" ;;
		channel@*) [ -f "${rigArg#channel@}" ] && rigChan="$( LC_ALL=C cat "${rigArg#channel@}" )" ;;
		channel=*) rigChan="${rigArg#channel=}" ;;
	esac
done
printf '%s %s\n' "$rigMethod" "$rigChan" >> "$RIG_SCN/calls"
case "$rigMethod" in
	auth.test) printf '{"ok":true,"user_id":"URIGSELF1"}\n' ;;
	conversations.info) printf '{"ok":true,"channel":{"id":"CRIGONE001","is_im":false,"is_mpim":false}}\n' ;;
	conversations.history)
		case "$rigChan" in
			CRIGBAD001) printf '{"ok":false,"error":"rig_refused"}\n' ;;
			CRIGTHREE01) printf '{"ok":true,"messages":[{"ts":"1793600000.000003","user":"URIGOTHER","text":"RIG-THREE"}],"has_more":false}\n' ;;
			CRIGTWO001) printf '{"ok":true,"messages":[{"ts":"1793600000.000002","user":"URIGOTHER","text":"RIG-TWO"}],"has_more":false}\n' ;;
			*) printf '{"ok":true,"messages":[{"ts":"1793600000.000001","user":"URIGOTHER","text":"RIG-ONE"}],"has_more":false}\n' ;;
		esac
	;;
	conversations.replies) printf '{"ok":true,"messages":[],"has_more":false}\n' ;;
	*) printf '{"ok":false,"error":"rig_unhandled"}\n' ;;
esac
FAKE
chmod +x "$rigTmp/bin/curl"

## ONE SOURCE of the store: a channel folder whose own state names it `slack-conversation <target> <member> <as bot>`.
rigSource(){ ## the folder name, the target, the as-bot word
	mkdir -p "$rigStore/$1"
	printf '1793600000 %s 0\n## target=%s channel=%s\nslack-conversation %s keeper-rig %s\n' "$2" "$2" "$2" "$2" "${3:-false}" > "$rigStore/$1/.state.txt"
}
rigSource slack-CRIGONE001 CRIGONE001 false
rigSource slack-CRIGTHREE01 CRIGTHREE01 false
rigSource slack-CRIGTWO001 CRIGTWO001 false

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigReads(){ [ -f "$rigScn/calls" ] || { printf '0\n' ; return 0 ; } ; LC_ALL=C awk '$1 == "conversations.history" { n++ ; } END { print n + 0 ; }' "$rigScn/calls" ; }
rigFileIn(){ ## file, needle -- yes where the file holds the needle
	case "$( LC_ALL=C cat "$1" 2> /dev/null )" in *"$2"*) printf 'yes' ;; *) printf 'no' ;; esac
}
rigEvents(){ LC_ALL=C cat "$rigStore/$1"/[0-9][0-9][0-9][0-9][0-9][0-9]/events.txt 2> /dev/null ; }
rigEventCount(){ rigEvents "$1" | LC_ALL=C awk 'NF' | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ; }
rigPointer(){ LC_ALL=C cat "$rigStore/$1/.ingest.txt" 2> /dev/null ; }
rigList(){ LC_ALL=C cat "$rigState/sources.txt" 2> /dev/null ; }
## A SOURCE PULLED SINCE ITS INGEST: its state file newer than its pointer, and its pointer long past its own TTL.
rigPulled(){ touch -t 202601010000 "$rigStore/$1/.ingest.txt" ; sleep 1 ; touch "$rigStore/$1/.state.txt" ; }

## ONE PASS of the ingest, through the include it lives in, in a subshell of this shell so nothing of it outlives the rig.
rigIngestPass(){ ## the budget
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		"MMDAPP=$rigWs" "MDLT_ORIGIN=$rigOrigin" "MDLT_OPTION=--run-from-path $rigOrigin" "MDAT_SKILLSET_ROOT=$rigTmp/skills" \
		"MDAT_DATA_ROOT=$rigScn/data" "RIG_SCN=$rigScn" "MDAT_SPAWN_AGENT=keeper-rig" "MDAT_WORKSPACE_MODE=team-rig" \
		"MDAT_COMMS_EVENT_ID_IDLE_SECONDS=3" \
		bash -c '. "$1" ; AgentsCommsIngestPass "$2"' _ "$rigInclude" "$1" ) > "$rigScn/pass.out" 2> "$rigScn/pass.err"
}

echo "-- 0. the control: the rig's store holds the channel sources this check wrote, and the fake records every call --"
rigAssert "three conversation sources" "$( LC_ALL=C awk '$1 == "slack-conversation" { n++ ; } END { print n + 0 ; }' "$rigStore"/*/.state.txt )" 3
rigAssert "and not one channel was read yet" "$( rigReads )" 0

echo "-- 1. a due channel source is ingested, and its pointer is the last id it wrote --"
rigIngestPass 1
rigAssert "the pass ran" "$?" 0
rigAssert "the list holds the three sources" "$( rigList | LC_ALL=C awk 'NF' | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 3
rigAssert "it read one channel" "$( rigReads )" 1
rigAssert "the first source of the list holds its message" "$( rigEventCount slack-CRIGONE001 )" 1
rigAssert "its pointer is that event's own id" "$( rigPointer slack-CRIGONE001 )" "$( rigEvents slack-CRIGONE001 | LC_ALL=C cut -f1 | LC_ALL=C sed -n '1p' )"
rigAssert "and it is the EventIdentifier form" \
	"$( rigPointer slack-CRIGONE001 | LC_ALL=C awk '$0 ~ /^[0-9]{8}T[0-9]{9}Z-[0-9]{6}[0-9A-F]{3}$/ { n++ ; } END { print n + 0 ; }' )" 1

echo "-- 2. a source whose state has not moved since its ingest is not read again, and one pulled since it is read again --"
rigIngestPass 0
rigAssert "the pass ran" "$?" 0
rigAssert "every source was read once, so the store is up to date" "$( rigReads )" 3
rigIngestPass 0
rigAssert "the pass ran" "$?" 0
rigAssert "and a pass over a store nothing moved read no channel" "$( rigReads )" 3
rigPulled slack-CRIGONE001
rigIngestPass 0
rigAssert "a source pulled since its ingest is read again, and only it" "$( rigReads )" 4

echo "-- 3. a source read as the bot is skipped, and no folder of that account is written --"
rigSource slack-bot-CRIGBOT001 CRIGBOT001 true
rigIngestPass 3
rigAssert "the pass ran" "$?" 0
rigAssert "the bot source is in no pass's list" "$( rigList | LC_ALL=C grep -c -F 'CRIGBOT001' )" 0
rigAssert "and holds no pointer" "$( [ -e "$rigStore/slack-bot-CRIGBOT001/.ingest.txt" ] && printf pointer || printf none )" none
rigAssert "and no event was written for it" "$( rigEventCount slack-bot-CRIGBOT001 )" 0

echo "-- 4. a source whose read failed leaves its pointer where it was and writes no event --"
rigSource slack-CRIGBAD001 CRIGBAD001 false
rigIngestPass 0 ; rigBadRc=$?
rigAssert "the pass reports the failure" "$rigBadRc" 1
rigAssert "and its error names the refused source" "$( rigFileIn "$rigScn/pass.err" 'CRIGBAD001' )" yes
rigAssert "the refused source wrote no event" "$( rigEventCount slack-CRIGBAD001 )" 0
rigAssert "and left no pointer" "$( [ -e "$rigStore/slack-CRIGBAD001/.ingest.txt" ] && printf pointer || printf none )" none

echo "-- 5. the pass stops at its budget, and the next pass starts after the source it served last --"
rm -rf "$rigStore/slack-CRIGBAD001"
rm -f "$rigState/turn"
rigPulled slack-CRIGONE001
rigPulled slack-CRIGTHREE01
rigPulled slack-CRIGTWO001
rigIngestPass 1
rigFirst="$( LC_ALL=C cat "$rigState/turn" 2> /dev/null )"
rigIngestPass 1
rigSecond="$( LC_ALL=C cat "$rigState/turn" 2> /dev/null )"
rigAssert "the first pass served one source" "$( [ -n "$rigFirst" ] && printf served || printf none )" served
rigAssert "and the next pass served another" "$( [ -n "$rigSecond" ] && [ "$rigSecond" != "$rigFirst" ] && printf another || printf "same ($rigFirst then $rigSecond)" )" another

echo "-- 6. a channel folder whose state names no recipe is skipped --"
mkdir -p "$rigStore/slack-CRIGNONE001"
printf '1793600000 0 0\n## target=CRIGNONE001 channel=CRIGNONE001\n' > "$rigStore/slack-CRIGNONE001/.state.txt"
rigIngestPass 0
rigAssert "the pass ran" "$?" 0
rigAssert "it is in no pass's list" "$( rigList | LC_ALL=C grep -c -F 'CRIGNONE001' )" 0

printf '\n  %s passed, %s failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" -eq 0 ] || exit 1
printf 'COMMS_INGEST_PASS: OK\n'
