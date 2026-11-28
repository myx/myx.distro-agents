#!/usr/bin/env bash
## Behavioural check of the pace record's cost on the call path (code-craft: no process per call; a load or a measure is
## kept, never redone). AgentsMcpPaceRecord, read out of AgentsTools.InternMcpRequest.include, run in a rig of its own,
## with date, mkdir, wc, tr and tail counted wherever they are called:
##   1. a hundred calls of one request epoch start no date and no mkdir, and count the file's lines at most once
##   2. and every one of them still writes its line, `<epoch> <ms> <tool>`, at the request's own epoch
##   3. a file past two thousand lines is still cut to its last thousand, on the call that counts it
##   4. control: with no request epoch the record still writes a right line, from date
##   5. control: a missing schedule folder is still made
## Red before the change: each call runs date, mkdir, wc and tr, a hundred of each for a hundred calls.
## Offline: a rig workspace of this check's own; nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsMcpPaceRecordForkCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigFn="$rigTmp/pace-record.fn"
LC_ALL=C awk '/^AgentsMcpPaceRecord\(\)\{/ { on = 1 } on { print } on && /^}$/ { exit }' "$rigPkg/sh-lib/mcp/AgentsTools.InternMcpRequest.include" > "$rigFn"
rigAssert "the record is read out of the request include" "$( LC_ALL=C grep -c '^AgentsMcpPaceRecord(){' "$rigFn" )" 1
rigWs="$rigTmp/ws"
rigPace="$rigWs/.local/agents/schedule/pace.mcp"
rigForks="$rigTmp/forks"
rigRun(){ ## first seq, calls, request epoch or empty: runs the record that many times in one shell
	: > "$rigForks"
	bash -c '
		. "$1" || exit 1
		for c in date mkdir wc tr tail ; do eval "$c(){ printf \"%s\\n\" $c >> \"\$rigForks\" ; command $c \"\$@\" ; }" ; done
		rigForks="$2" ; MMDAPP="$3"
		[ -z "$6" ] || { mcpRequestEpoch="$6" ; mcpRequestSeconds="$SECONDS" ; }
		seq="$4" ; last=$(( $4 + $5 ))
		while [ "$seq" -lt "$last" ] ; do AGENTS_MCP_REQ_SEQ="$seq" ; AgentsMcpPaceRecord Read "${6:-$( command date +%s )}" ; seq=$(( seq + 1 )) ; done
	' rig "$rigFn" "$rigForks" "$rigWs" "$1" "$2" "${3:-}" 2> /dev/null
}
rigCount(){ LC_ALL=C grep -cx "$1" "$rigForks" ; }

echo "-- 1. a hundred calls of one request: no date, no mkdir, one count at most --"
mkdir -p "${rigPace%/*}" || exit 1
rigEpoch="$( date +%s )"
rigRun 2 100 "$rigEpoch"
rigAssert "date started by a hundred calls" "$( rigCount date )" 0
rigAssert "mkdir started by a hundred calls" "$( rigCount mkdir )" 0
rigAssert "the file's lines counted at most once" "$( [ "$( rigCount wc )" -le 1 ] && echo at-most-once || echo "$( rigCount wc ) times" )" at-most-once

echo "-- 2. every call still writes its line --"
rigAssert "lines written" "$( LC_ALL=C wc -l < "$rigPace" | tr -d ' ' )" 100
rigAssert "every line is <epoch> <ms> Read, at the request epoch or its next seconds" \
	"$( LC_ALL=C awk -v e="$rigEpoch" '!( $1 >= e && $1 <= e + 5 && $2 ~ /^[0-9]+$/ && $2 % 1000 == 0 && $3 == "Read" && NF == 3 ) { bad++ } END { print bad + 0 }' "$rigPace" )" 0

echo "-- 3. a long file is still cut, on the call that counts it --"
LC_ALL=C awk -v e="$rigEpoch" 'BEGIN { for ( i = 0 ; i < 2100 ; i++ ) print e, 0, "Old" }' > "$rigPace"
rigRun 1 1 "$rigEpoch"
rigAssert "cut to its last thousand" "$( LC_ALL=C wc -l < "$rigPace" | tr -d ' ' )" 1000
rigAssert "and the new line is the last" "$( tail -n 1 "$rigPace" | cut -d' ' -f3 )" Read

echo "-- 4. control: no request epoch, the record takes date --"
rm -f "$rigPace"
rigRun 2 1 ""
rigAssert "one line written" "$( LC_ALL=C wc -l < "$rigPace" | tr -d ' ' )" 1
rigAssert "from date" "$( [ "$( rigCount date )" -ge 1 ] && echo date || echo none )" date

echo "-- 5. control: a missing schedule folder is made --"
rm -rf "${rigPace%/*}"
rigRun 2 1 "$rigEpoch"
rigAssert "the line is written into a new folder" "$( LC_ALL=C wc -l < "$rigPace" 2> /dev/null | tr -d ' ' )" 1

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ MCP PACE RECORD FORK CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'MCP_PACE_RECORD_FORK: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
