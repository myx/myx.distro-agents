#!/usr/bin/env bash
## Behavioural check on the REQUEST THREAD of a duty start (`AgentsToolsScheduleWorkDuty` in AgentsTools.DispatcherSchedule.include), run rather than read: a duty
## started for a person's message opens its thread under that message. The request is the thread the header of the newest Slack message in the member's inbox
## names, so a message written in a thread of the team channel, a direct message and a mention all carry it. The roster, the flags, the pace and the spawner are
## stand-ins, and the spawner records its argument list, so what is measured is the start itself and never the roster. Every row is an assertion. Held:
##   1. The newest Slack message of the inbox gives `--conversation <channel>:<thread root>`, ahead of the member.
##   2. A message the team posted itself (a `[sender: ` line), an email one and one already handled are passed over for the next older person's.
##   3. A start with no Slack message in the inbox passes no flag: the arguments are the old ones, byte for byte.
##   4. A header that names no thread passes no flag and says so on stderr.
##   5. A message older than three owed periods, or not newer than the tag pointer, passes no flag and says so. The start is still made.
## Offline: no clock is faked, no workspace is read, and the spawner is a recorder.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-lib/schedule/AgentsTools.DispatcherSchedule.include" ] || rigRefuse "the schedule's include is not in the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsTagAddressCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigData="$rigTmp/data" rigMembers="$rigTmp/members" rigSpawned="$rigTmp/spawned"
## The owner's writers read these: the workspace is the rig's own root, which the stand-in pass below takes as its MMDAPP too.
rigWs="$rigTmp" rigHome="$rigTmp/home"
## The mark runs as the member and finds its folder in the rig's skillset root: the two things it refuses without.
rigSkills="$rigMembers" rigAs=keeper-rig-one
mkdir -p "$rigMembers/keeper-rig-one" "$rigSpawned" "$rigTmp/home" || exit 1
printf "status: active\n" > "$rigMembers/keeper-rig-one/SKILL.md" ; printf '# armed\n' > "$rigMembers/keeper-rig-one/keeper-rig-one.armed.md"
rigBoardStates "$rigData" pending || exit 1
rigInboxReady "$rigData" keeper-rig-one || exit 1

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 )) ; printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}
rigNote(){ ## item name, header lines (may be empty), body text -- one inbox item, written by the inbox's own writer
	{ printf -- '---\ntype: note\n' ; [ -z "$2" ] || printf '%s\n' "$2" ; printf -- '---\n\n%s\n' "$3" ; } | rigStoreItem "$rigData" inbox keeper-rig-one "$1"
}
rigClear(){ rm -f "$rigData/inboxes/keeper-rig-one/incoming"/*.md "$rigData/inboxes/keeper-rig-one/processed"/*.md 2> /dev/null ; }
rigRun(){ ## -- the spawner's argument list of the one start the pass made, or `none`; stderr in $rigTmp/stderr
	: > "$rigTmp/calls" ; : > "$rigTmp/stderr"
	env -i PATH="/usr/bin:/bin:/usr/sbin:/sbin" MDLT_ORIGIN="$MDLT_ORIGIN" RIG_POINTER="${rigPointer:-0}" RIG_CALLS="$rigTmp/calls" RIG_MEMBERS="$rigMembers" RIG_DATA="$rigData" RIG_SPAWNED="$rigSpawned" \
		bash -c '
			MMDAPP="${RIG_DATA%/data}" ; export MMDAPP
			MDAT_DATA_ROOT="$RIG_DATA" ; export MDAT_DATA_ROOT
			MDAT_WORKSPACE_MODE=team-rig ; export MDAT_WORKSPACE_MODE
			set +e +u
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/schedule/AgentsTools.DispatcherSchedule.include" > /dev/null 2>&1
			AgentsToolsScheduleCurrentFlags(){ printf "worktime: yes\nweekend: no\nholidays: no\nemergency: no\novertime: no\nlearning: no\nsupervised: no\n" ; return 0 ; }
			AgentsToolsSchedulePaceText(){ printf "pace: 1 of 9 calls in 30 minutes -- under 7000, a duty start is allowed\n" ; return 0 ; }
			AgentsToolsSchedulePaceAllows(){ return 0 ; }
			AgentsToolsScheduleDutyStaleClose(){ return 0 ; }
			AgentsToolsScheduleTeamTags(){ return 0 ; }
			AgentsToolsScheduleDmTags(){ return 0 ; }
			AgentsToolsScheduleTagNews(){ return 1 ; }
			AgentsToolsScheduleTagPointer(){ printf "%s\n" "$RIG_POINTER" ; }
			AgentsToolsTeamMemberDirectoryText(){ printf "keeper-rig-one\t%s/keeper-rig-one\n" "$RIG_MEMBERS" ; }
			AgentsToolsScheduleSpawn(){ printf "%s\n" "$*" >> "$RIG_CALLS" ; return 0 ; }
			AgentsToolsScheduleTagCarry(){ return 0 ; }
			AgentsToolsScheduleDemand(){ return 0 ; }
			AgentsToolsScheduleDutyRestartDue(){ return 1 ; }
			AgentsToolsScheduleWorkDutyRecord(){ return 1 ; }
			AgentsToolsScheduleDutyLifetime(){ return 0 ; }
			AgentsToolsScheduleWorkDuty
		' > /dev/null 2>> "$rigTmp/stderr"
	if [ -s "$rigTmp/calls" ] ; then head -1 "$rigTmp/calls" ; else printf 'none' ; fi
}
rigThread(){ ## the argument list -- the word after --conversation, or `-`
	printf '%s\n' "$1" | LC_ALL=C awk '{ for ( i = 1 ; i < NF ; i++ ) if ( $i == "--conversation" ) { print $( i + 1 ) ; found = 1 ; exit ; } } END { if ( ! found ) print "-" ; }'
}
rigBefore(){ ## the argument list -- the two words just before the member
	printf '%s\n' "$1" | LC_ALL=C awk '{ print $(NF-2), $(NF-1), $NF ; }'
}
rigOld="work-duty.keeper-rig-one --session-thread:event-track --routine"
rigNowEpoch="$( date +%s )" ; rigEA="$(( rigNowEpoch - 300 ))" ; rigEB="$(( rigNowEpoch - 200 ))" ; rigPointer=0

echo "-- 1. the newest Slack message gives the request --"
rigClear
rigNote "note-20261124T0800Z-slack-$rigEA.000100.md" 'communication-channel-id: slack:CRIGREQ01:1700000000.000100' "an older question"
rigNote "note-20261124T0900Z-slack-$rigEB.000200.md" 'communication-channel-id: slack:CRIGREQ02:1700000000.000050' "a reply in a thread of the team channel"
rigLine="$( rigRun )"
rigAssert "the start is made, and the newest message's thread root is passed, ahead of the member" "$( rigThread "$rigLine" ):$( rigBefore "$rigLine" )" "CRIGREQ02:1700000000.000050:--conversation CRIGREQ02:1700000000.000050 keeper-rig-one"
rigAssert "the start is of the duty, in the event-track mode, as it always was" "$( printf '%s\n' "$rigLine" | LC_ALL=C cut -c1-${#rigOld} )" "$rigOld"

echo "-- 2. what is not a person's Slack message is passed over --"
rigClear
rigNote "note-20261124T0800Z-slack-$rigEA.000100.md" 'communication-channel-id: slack:CRIGREQ01:1700000000.000100' "a person's question"
rigNote "note-20261124T0900Z-slack-$rigEB.000200.md" 'communication-channel-id: slack:CRIGREQ02:1700000000.000200' "[sender: keeper-rig-two] the team's own post"
rigLine="$( rigRun )"
rigAssert "a message the team posted itself is passed over for the person's older one" "$( rigThread "$rigLine" )" "CRIGREQ01:1700000000.000100"
rigClear
rigNote "note-20261124T0800Z-slack-$rigEA.000100.md" 'communication-channel-id: slack:CRIGREQ01:1700000000.000100' "a person's question"
rigNote "note-20261124T0900Z-slack-$rigEB.000200.md" 'communication-channel-id: email:rig@example.invalid' "an email one"
rigLine="$( rigRun )"
rigAssert "an email one is passed over as well" "$( rigThread "$rigLine" )" "CRIGREQ01:1700000000.000100"
rigClear
rigNote "note-20261124T0800Z-slack-$rigEA.000100.md" 'communication-channel-id: slack:CRIGREQ01:1700000000.000100' "a person's question"
printf -- '---\ntype: note\ncommunication-channel-id: slack:CRIGREQ02:1700000000.000200\n---\n\nhandled\n' | rigOwnerInboxPutHandled keeper-rig-one "note-20261124T0900Z-slack-$rigEB.000200.md" 20261124T0910Z
rigAssert "the handled item stands in processed and not in incoming" "$( [ -f "$rigData/inboxes/keeper-rig-one/processed/note-20261124T0900Z-slack-$rigEB.000200.md" ] && [ ! -f "$rigData/inboxes/keeper-rig-one/incoming/note-20261124T0900Z-slack-$rigEB.000200.md" ] && printf yes || printf no )" "yes"
rigLine="$( rigRun )"
rigAssert "a message already handled is not read" "$( rigThread "$rigLine" )" "CRIGREQ01:1700000000.000100"

echo "-- 3. no Slack message: the old arguments --"
rigClear
rigNote note-20261124T0800Z-rig-work.md '' "plain work"
rigLine="$( rigRun )"
rigAssert "the start passes no conversation" "$( rigThread "$rigLine" )" "-"
rigAssert "and its words are the old ones: the key, the thread mode, the routine, the routine's name and the member" "$( printf '%s\n' "$rigLine" | LC_ALL=C awk '{ print NF, $1, $2, $3, $NF ; }' )" "5 work-duty.keeper-rig-one --session-thread:event-track --routine keeper-rig-one"
rigAssert "and says nothing on stderr about a request" "$( LC_ALL=C grep -c 'conversation' "$rigTmp/stderr" || : )" "0"

echo "-- 4. a header with no thread --"
rigClear
rigNote "note-20261124T0900Z-slack-$rigEB.000200.md" 'communication-channel-id: slack:CRIGREQ01' "a message with no thread"
rigLine="$( rigRun )"
rigAssert "no conversation is passed" "$( rigThread "$rigLine" )" "-"
rigAssert "and the start says so, naming the member and the place" "$( LC_ALL=C grep -c 'the newest Slack message of keeper-rig-one names CRIGREQ01, which is no <channel>:<thread ts>' "$rigTmp/stderr" || : )" "1"

echo "-- 5. a message too old, or already handed, gives no request --"
rigClear
rigEOld="$(( rigNowEpoch - 90000 ))"
rigNote "note-20261123T0100Z-slack-$rigEOld.000100.md" 'communication-channel-id: slack:CRIGREQ01:1700000000.000100' "a question from a day ago"
rigLine="$( rigRun )"
rigAssert "an item older than three owed periods: the start is made with no conversation, and says why" \
	"$( rigThread "$rigLine" ):$( [ "$rigLine" != none ] && printf started || printf none ):$( LC_ALL=C grep -c 'is not newer than the tag pointer or is older than' "$rigTmp/stderr" || : )" "-:started:1"
rigClear
rigNote "note-20261124T0800Z-slack-$rigEA.000100.md" 'communication-channel-id: slack:CRIGREQ01:1700000000.000100' "a question the tag pointer has passed"
rigPointer="$rigEA"
rigLine="$( rigRun )"
rigAssert "an item not newer than the tag pointer: the start is made with no conversation, and says why" \
	"$( rigThread "$rigLine" ):$( [ "$rigLine" != none ] && printf started || printf none ):$( LC_ALL=C grep -c 'is not newer than the tag pointer or is older than' "$rigTmp/stderr" || : )" "-:started:1"
rigPointer=0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ TAG ADDRESS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'TAG_ADDRESS: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
