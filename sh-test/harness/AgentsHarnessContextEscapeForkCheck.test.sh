#!/usr/bin/env bash
## Behavioural check of the kept context's escape and clock on the call path (code-craft: no process per call where none is needed).
## AgentsHarnessContext.include in a rig, with awk and date counted wherever they are called:
##   1. a hundred tool records (AgentsHarnessContextToolMeta) of a plain tool name and call id start no awk
##   2. fifty one-line message lines (AgentsHarnessContextLine) start date once at most, and carry a UTC stamp and a millisecond time
##   3. the escape writes every value as the escape's awk does: plain, a quote, a backslash, a tab, a newline, a valid UTF-8 letter,
##      an invalid byte, a control byte, the empty value
## Red before the change: each record ran the awk twice, and each line ran date twice.
## Offline: functions only; nothing is written but the rig's own files.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessContextEscapeForkCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigForks="$rigTmp/forks"
rigShell(){ ## script: run with the transcript and context includes loaded, awk and date counted
	: > "$rigForks"
	env -u harnessScratch -u agentsTranscriptT0 MMDAPP="$rigTmp/ws" rigPkg="$rigPkg" rigForks="$rigForks" bash -c '
		harnessHere="$rigPkg/sh-lib"
		. "$rigPkg/sh-lib/session/AgentsTools.SessionTranscript.include" || exit 1
		. "$rigPkg/sh-lib/harness/AgentsHarnessContext.include" || exit 1
		awk(){ printf "awk\n" >> "$rigForks" ; command awk "$@" ; }
		date(){ printf "date\n" >> "$rigForks" ; command date "$@" ; }
		harnessContextLeg=1 ; harnessRound=3
		'"$1"
}
rigCount(){ LC_ALL=C grep -cx "$1" "$rigForks" ; }

echo "-- 1. a hundred tool records of a plain name and id: no awk --"
rigShell 'i=0 ; while [ $i -lt 100 ] ; do AgentsHarnessContextToolMeta Read "call_$i" "ok" "" > /dev/null ; i=$(( i + 1 )) ; done' 2> /dev/null
rigAssert "awk started by a hundred records" "$( rigCount awk )" 0
rigOut="$( rigShell 'AgentsHarnessContextToolMeta Read call_7 "ERROR: REFUSAL-ID: x" ""' 2> /dev/null )"
rigAssert "a record names the tool, the id and the outcome" "$( case "$rigOut" in (*'"tool":"Read","id":"call_7"'*'"outcome":"refused"'*) echo named ;; (*) echo "other: $rigOut" ;; esac )" named

echo "-- 2. fifty one-line message lines: date once at most --"
rigShell 'i=0 ; while [ $i -lt 50 ] ; do AgentsHarnessContextLine $i tool "" "{\"role\":\"tool\"}" ; i=$(( i + 1 )) ; done' > "$rigTmp/lines" 2> /dev/null
rigAssert "date started by fifty lines" "$( [ "$( rigCount date )" -le 1 ] && echo at-most-once || echo "$( rigCount date ) times" )" at-most-once
rigAssert "every line carries a UTC stamp and a millisecond time" \
	"$( LC_ALL=C awk '!/"ts":"20[0-9][0-9]-[01][0-9]-[0-3][0-9]T[0-2][0-9]:[0-5][0-9]:[0-5][0-9]Z","ms":[0-9]+000,/ { bad++ } END { print bad + 0 "/" NR }' "$rigTmp/lines" )" "0/50"

echo "-- 3. the escape writes what the escape's awk writes --"
rigBad=""
for rigValue in 'plain value 1.2-3_x' 'a"b' 'a\b' "$( printf 'a\tb' )" "$( printf 'a\nb' )" "$( printf 'caf\303\251' )" "$( printf 'x\377y' )" "$( printf 'x\001y' )" '' ; do
	rigWant="$( printf '%s' "$rigValue" | LC_ALL=C command awk -f "$rigPkg/sh-lib/mcp/AgentsMcpJsonEscape.awk" )"
	rigGot="$( env MMDAPP="$rigTmp/ws" rigPkg="$rigPkg" bash -c 'harnessHere="$rigPkg/sh-lib" ; . "$rigPkg/sh-lib/session/AgentsTools.SessionTranscript.include" ; . "$rigPkg/sh-lib/harness/AgentsHarnessContext.include" ; AgentsHarnessContextEscapeInto v "$1" ; printf "%s" "$v"' rig "$rigValue" 2> /dev/null )"
	[ "$rigGot" = "$rigWant" ] || rigBad="$rigBad [$( printf '%s' "$rigValue" | od -An -c | tr -s ' ' )]"
done
rigAssert "nine values, each as the awk writes it" "${rigBad:-equal}" equal

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ HARNESS CONTEXT ESCAPE FORK CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_CONTEXT_ESCAPE_FORK: OK (%d assertions, offline, rig only)\n' "$rigPass"
