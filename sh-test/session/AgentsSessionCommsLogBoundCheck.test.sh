#!/usr/bin/env bash
## Behavioural check of the comms thread's log bound (a log is bounded whoever writes it). The thread's own says are counted by the
## writer, and the clients it starts write their errors into the same log, uncounted. AgentsToolsSessionCommsLogBound in a rig:
##   1. a log grown past the bound by an uncounted writer is cut, once the minute since the size was read has passed
##   2. control: within that minute the bound reads the file's size once, whatever the passes
##   3. control: a log grown past the bound by the thread's own says is cut at once
## Red before the change: the size was read once per process, so a log grown by its clients was never cut.
## Offline: a rig workspace of this check's own; nothing is requested.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionCommsLogBoundCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigLog="$rigTmp/ws/.local/agents/comms/log"
mkdir -p "${rigLog%/*}" || exit 1
rigFill(){ ## kibibytes: appended to the log as whole lines, as a client's errors are
	LC_ALL=C awk -v k="$1" 'BEGIN { for ( i = 0 ; i < k * 16 ; i++ ) printf "%063d\n", i }' >> "$rigLog"
}
rigShell(){ ## script: run with the comms include loaded, wc counted, in the rig workspace
	MMDAPP="$rigTmp/ws" rigPkg="$rigPkg" rigTmp="$rigTmp" bash -c '
		. "$rigPkg/sh-lib/session/AgentsTools.SessionComms.include" || exit 1
		wc(){ printf "wc\n" >> "$rigTmp/forks" ; command wc "$@" ; }
		'"$1" 2> /dev/null
}
rigSize(){ LC_ALL=C wc -c < "$rigLog" | tr -d ' ' ; }

echo "-- 1. an uncounted writer's growth is cut once the minute has passed --"
: > "$rigLog" ; rigFill 100
rigShell 'AgentsToolsSessionCommsLogBound
	LC_ALL=C awk "BEGIN { for ( i = 0 ; i < 200 * 16 ; i++ ) printf \"%063d\\n\", i }" >> "$MMDAPP/.local/agents/comms/log"
	agentsCommsLogReadAt=$(( SECONDS - 61 ))
	AgentsToolsSessionCommsLogBound'
rigAssert "a 300 KiB log is cut to its last 64 KiB, with the line the bound says after it" "$( [ "$( rigSize )" -le 66560 ] && echo cut || echo "$( rigSize ) bytes" )" cut

echo "-- 2. control: one size read within the minute --"
: > "$rigLog" ; rigFill 10 ; : > "$rigTmp/forks"
rigShell 'i=0 ; while [ $i -lt 50 ] ; do AgentsToolsSessionCommsLogBound ; i=$(( i + 1 )) ; done'
rigAssert "fifty passes read the size once" "$( LC_ALL=C grep -cx wc "$rigTmp/forks" )" 1

echo "-- 3. control: the thread's own says past the bound are cut at once --"
: > "$rigLog" ; rigFill 100
rigShell 'AgentsToolsSessionCommsLogBound
	i=0 ; while [ $i -lt 400 ] ; do AgentsToolsSessionCommsSay "$( printf "%0100d" $i )" ; i=$(( i + 1 )) ; done
	AgentsToolsSessionCommsLogBound'
rigAssert "a log the says grew past 128 KiB is cut" "$( [ "$( rigSize )" -le 131072 ] && echo cut || echo "$( rigSize ) bytes" )" cut

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SESSION COMMS LOG BOUND CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_COMMS_LOG_BOUND: OK (%d assertions, offline, rig workspace only)\n' "$rigPass"
