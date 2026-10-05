#!/usr/bin/env bash
## A wait source read at least once and then failing is reported as read-then-failed,
## never as never-read, and never as clean. A source unreadable from the start is the
## control that must say never-read. Offline: file sources under this rig's temp tree.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigTool="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigTool" ] || rigRefuse "team tooling not found: $rigTool"
rigTmp="$( mktemp -d -t AgentsHarnessWaitReadFailCheck )" || exit 1
trap 'chmod -R u+rw "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
rigTmp="$( cd "$rigTmp" && pwd -P )"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHolds(){ ## file, fixed string
	LC_ALL=C grep -q -F -- "$2" "$1" && printf yes || printf no
}

## Unreadable from the start: the rig's own user cannot read a mode-000 file.
printf 'rig\n' > "$rigTmp/never"
chmod 000 "$rigTmp/never"
cat "$rigTmp/never" > /dev/null 2>&1 && rigRefuse "a mode-000 file is readable here (running as root?), so no source can be made unreadable"

echo "-- a source read once and then failing --"
printf 'rig\n' > "$rigTmp/src"
( sleep 2 ; chmod 000 "$rigTmp/src" ) &
rigRc=0
"$rigTool" --member-wait-for-input magic-tester --wait-source "file:$rigTmp/src" --wait-timeout 5 --wait-poll-interval 1 > "$rigTmp/rf.out" 2> "$rigTmp/rf.err" || rigRc=$?
wait
rigAssert "the wait completes as TIMEOUT"             "$( head -1 "$rigTmp/rf.out" )" "WAIT-RESULT: TIMEOUT"
rigAssert "it returns 0"                              "$rigRc" 0
rigAssert "the source is named as having failed probes" "$( rigHolds "$rigTmp/rf.out" "could not run this wait" )" yes
rigAssert "it says some reads failed after it was read" "$( rigHolds "$rigTmp/rf.out" 'some reads of the sources listed above failed' )" yes
rigAssert "it is not reported as never-read"          "$( rigHolds "$rigTmp/rf.out" 'WAIT-NEVER-READ:' )" no

echo "-- control: a source unreadable from the start --"
rigRc=0
"$rigTool" --member-wait-for-input magic-tester --wait-source "file:$rigTmp/never" --wait-timeout 2 --wait-poll-interval 1 > "$rigTmp/nr.out" 2> "$rigTmp/nr.err" || rigRc=$?
rigAssert "control: it is reported as never-read"     "$( rigHolds "$rigTmp/nr.out" "WAIT-NEVER-READ: [file:$rigTmp/never]" )" yes
rigAssert "control: and claims no successful wait"    "$( rigHolds "$rigTmp/nr.out" 'COMPLETE, SUCCESSFUL' )" no

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WAIT READ-FAIL CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_WAIT_READ_FAIL: OK (%d assertions, offline)\n' "$rigPassCount"
