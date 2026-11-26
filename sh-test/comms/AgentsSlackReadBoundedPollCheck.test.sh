#!/usr/bin/env bash
## Behavioural check on the polling bound of a bounded Slack read (AgentsToolsSlackReadBounded, sh-lib/slack/AgentsTools.CommsSlack.include).
## The read runs in the background and its caller looks at it once a second. A look at the caller's own parent costs a process, a pipe and a
## capture, so one a second for every live read is the poll's whole cost. Held:
##   1. a read that takes three seconds looks at its caller's parent no more than the one time it starts
##   2. the control: a read whose caller has gone is still ended before its own end, rc 1, so 1 is no guard taken away
## The look is counted by a stand-in for ps that counts its calls and runs the real one. Offline: the read is a sleep.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigInclude="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/slack/AgentsTools.CommsSlack.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the Slack comms include is not in the package: $rigInclude"
## The function from its own `Name(){` line to the first line that is a lone `}`.
rigLift="$( LC_ALL=C awk '
	/^AgentsToolsSlackReadBounded\(\)\{/ { inFn = 1 ; }
	inFn { print ; }
	inFn && /^\}$/ { inFn = 0 ; seen++ ; }
	END { if ( seen != 1 ) exit 1 ; }
' "$rigInclude" )" || rigRefuse "AgentsToolsSlackReadBounded was not found in $rigInclude"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSlackReadBoundedPollCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
eval "$rigLift"
rigCount="$rigTmp/ps.count"
ps(){ printf 'x' >> "$rigCount" ; command ps "$@" ; }

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

echo "-- 1. a read of three seconds --"
: > "$rigCount"
AgentsToolsSlackReadBounded "$rigTmp/out" "$rigTmp/err" sleep 3 ; rigRc=$?
rigAssert "the read ended well" "$rigRc" "0"
rigLooks=""
IFS= read -r -d '' rigLooks < "$rigCount" 2> /dev/null || :
rigAssert "its caller's parent was looked at once, as the read started" "${#rigLooks}" "1"

echo "-- 2. the control: the caller of a read goes while it runs --"
rigScript='eval "$RIG_FN" ; AgentsToolsSlackReadBounded "$RIG_OUT" "$RIG_ERR" sleep 40 ; printf "rc=%s\n" "$?" > "$RIG_RESULT"'
RIG_FN="$rigLift" RIG_OUT="$rigTmp/gone.out" RIG_ERR="$rigTmp/gone.err" RIG_RESULT="$rigTmp/gone.result" \
	bash -c 'bash -c "$1" rig-read 2> /dev/null & sleep 2 ; exit 0' rig-caller "$rigScript"
rigWaited=0
while [ ! -s "$rigTmp/gone.result" ] && [ "$rigWaited" -lt 20 ] ; do sleep 1 ; rigWaited=$(( rigWaited + 1 )) ; done
rigAssert "the read was ended within twenty seconds of its caller going, before its own forty" "$( LC_ALL=C sed -n 1p "$rigTmp/gone.result" 2> /dev/null )" "rc=1"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SLACK READ BOUNDED POLL CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'SLACK_READ_BOUNDED_POLL: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
