#!/usr/bin/env bash
## Behavioural check of the reply's date on the call path (code-craft: no process per call; the process clock is kept). The line every
## reply carries beside its result, `current-date: YYYY-MM-DD HH:MM +ZZZZ` (AgentsTranscriptReplyDate), in a rig, date counted:
##   1. a hundred replies in one process start date once at most
##   2. the line is date's own local time and zone, in this zone and in two zones of a half hour from UTC, east and west
##   3. control: a clock a minute old is read again, so a change of the zone shows within a minute
## Red before the change: each reply started date, a hundred for a hundred replies.
## Offline: functions only; nothing is written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsTranscriptReplyDateClockCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigForks="$rigTmp/forks"
rigShell(){ ## script: run with the include loaded, date counted
	: > "$rigForks"
	env MMDAPP="$rigTmp/ws" rigPkg="$rigPkg" rigForks="$rigForks" bash -c '
		. "$rigPkg/sh-lib/session/AgentsTools.SessionTranscript.include" || exit 1
		date(){ printf "date\n" >> "$rigForks" ; command date "$@" ; }
		'"$1" 2> /dev/null
}

echo "-- 1. a hundred replies: date once at most --"
rigShell 'i=0 ; while [ $i -lt 100 ] ; do AgentsTranscriptReplyDate > /dev/null ; i=$(( i + 1 )) ; done'
rigAssert "date started by a hundred replies" "$( [ "$( LC_ALL=C grep -cx date "$rigForks" )" -le 1 ] && echo at-most-once || echo "$( LC_ALL=C grep -cx date "$rigForks" ) times" )" at-most-once

echo "-- 2. date's own local time and zone --"
for rigZone in "" Asia/Kolkata America/St_Johns ; do
	rigBefore="$( env ${rigZone:+TZ=$rigZone} date '+%Y-%m-%d %H:%M %z' )"
	rigGot="$( env ${rigZone:+TZ=$rigZone} MMDAPP="$rigTmp/ws" rigPkg="$rigPkg" bash -c '. "$rigPkg/sh-lib/session/AgentsTools.SessionTranscript.include" ; AgentsTranscriptReplyDate' 2> /dev/null )"
	rigAfter="$( env ${rigZone:+TZ=$rigZone} date '+%Y-%m-%d %H:%M %z' )"
	rigAssert "in ${rigZone:-this zone}" "$( [ "$rigGot" = "current-date: $rigBefore" ] || [ "$rigGot" = "current-date: $rigAfter" ] && echo equal || echo "[$rigGot] against [$rigBefore]" )" equal
done

echo "-- 3. control: a clock a minute old is read again --"
rigShell 'AgentsTranscriptReplyDate > /dev/null ; agentsTranscriptClockSeconds=$(( agentsTranscriptClockSeconds - 61 )) ; AgentsTranscriptReplyDate > /dev/null'
rigAssert "two readings a minute apart" "$( LC_ALL=C grep -cx date "$rigForks" )" 2

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ TRANSCRIPT REPLY DATE CLOCK CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'TRANSCRIPT_REPLY_DATE_CLOCK: OK (%d assertions, offline)\n' "$rigPass"
