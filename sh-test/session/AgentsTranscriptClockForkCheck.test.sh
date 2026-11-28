#!/usr/bin/env bash
## Behavioural check of the transcript's clock on the call path (code-craft: no process per call; a measure is kept, never
## redone). AgentsTools.SessionTranscript.include run in a rig of its own, with date counted wherever it is called:
##   1. a hundred tool calls (AgentsTranscriptToolStart, AgentsTranscriptToolDone) and ten event lines start date once at most
##   2. and a load of the include again keeps the clock the process took
##   3. the tool line still carries the UTC moment it was written
##   4. and the call's duration, from the start's clock
##   5. an epoch is written as UTC by the civil-from-days rule, equal to date's, in both forms, leap days and centuries included
## Red before the change: each tool call starts date three times, each event line once, and there is no UTC writer.
## Offline: no session, so nothing is written but the tool line on stderr; nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsTranscriptClockForkCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigForks="$rigTmp/forks"
rigRun(){ ## script: run with the include loaded, date counted into the forks file, and no session
	: > "$rigForks"
	env -u harnessSessionId -u MDAT_SPAWN_SESSION_ID -u CLAUDE_CODE_SESSION_ID rigForks="$rigForks" rigPkg="$rigPkg" bash -c '
		. "$rigPkg/sh-lib/session/AgentsTools.SessionTranscript.include" || exit 1
		date(){ printf "date\n" >> "$rigForks" ; command date "$@" ; }
		'"$1"
}
rigDates(){ LC_ALL=C grep -cx date "$rigForks" ; }
rigUtc(){ ## epoch, format: date's own UTC writing of it
	command date -u -r "$1" "$2" 2> /dev/null || command date -u -d "@$1" "$2"
}

echo "-- 1. a hundred tool calls and ten event lines: date once at most --"
rigRun 'i=0 ; while [ $i -lt 100 ] ; do AgentsTranscriptToolStart Read ; AgentsTranscriptToolDone Read "{}" "ok" mcp 2> /dev/null ; i=$(( i + 1 )) ; done
	i=0 ; while [ $i -lt 10 ] ; do AgentsTranscriptEventLine NOTE what rig > /dev/null ; i=$(( i + 1 )) ; done'
rigAssert "date started by a hundred calls and ten events" "$( [ "$( rigDates )" -le 1 ] && echo at-most-once || echo "$( rigDates ) times" )" at-most-once

echo "-- 2. a load again keeps the clock --"
rigRun 'AgentsTranscriptToolStart Read ; . "$rigPkg/sh-lib/session/AgentsTools.SessionTranscript.include" ; AgentsTranscriptToolStart Read ; AgentsTranscriptToolDone Read "{}" "ok" mcp 2> /dev/null'
rigAssert "date started across a load" "$( [ "$( rigDates )" -le 1 ] && echo at-most-once || echo "$( rigDates ) times" )" at-most-once

echo "-- 3. the tool line carries its UTC moment --"
rigBefore="$( date -u +%Y-%m-%dT%H:%M:%SZ )"
rigLine="$( rigRun 'AgentsTranscriptToolStart Read ; AgentsTranscriptToolDone Read "{}" "ok" mcp 2>&1 > /dev/null' )"
rigAfter="$( date -u +%Y-%m-%dT%H:%M:%SZ )"
rigStamp="${rigLine%% *}"
rigAssert "the stamp is between the moments before and after" "$( [[ ! "$rigStamp" < "$rigBefore" ]] && [[ ! "$rigStamp" > "$rigAfter" ]] && echo within || echo "$rigStamp not in $rigBefore..$rigAfter" )" within
rigAssert "and it is a tool line" "$( case "$rigLine" in (*' TOOL Read '*) echo tool ;; (*) echo "other: $rigLine" ;; esac )" tool

echo "-- 4. the duration is the start's clock --"
rigLine="$( rigRun 'AgentsTranscriptToolStart Read ; sleep 2 ; AgentsTranscriptToolDone Read "{}" "ok" mcp 2>&1 > /dev/null' )"
rigAssert "a two-second call reads two or three seconds" "$( case "$rigLine" in (*' 2.0s'*|*' 3.0s'*) echo seconds ;; (*) echo "other: $rigLine" ;; esac )" seconds

echo "-- 5. UTC by the civil-from-days rule, equal to date's --"
rigBad=""
for rigEpoch in 0 59 86399 951782400 951868799 1709164800 1735689599 1795801541 4102444800 4107542399 ; do
	rigGot="$( rigRun "AgentsTranscriptUtcInto v $rigEpoch && printf '%s ' \"\$v\" && AgentsTranscriptUtcInto v $rigEpoch compact && printf '%s' \"\$v\"" 2> /dev/null )"
	rigWant="$( rigUtc "$rigEpoch" +%Y-%m-%dT%H:%M:%SZ ) $( rigUtc "$rigEpoch" +%Y%m%dT%H%M%SZ )"
	[ "$rigGot" = "$rigWant" ] || rigBad="$rigBad $rigEpoch:[$rigGot]!=[$rigWant]"
done
rigAssert "ten epochs, both forms" "${rigBad:-equal}" equal
rigAssert "and the writer starts no date" "$( rigRun 'AgentsTranscriptUtcInto v 1795801541' 2> /dev/null ; rigDates )" 0

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ TRANSCRIPT CLOCK FORK CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'TRANSCRIPT_CLOCK_FORK: OK (%d assertions, offline, no session)\n' "$rigPass"
