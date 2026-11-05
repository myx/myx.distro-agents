#!/usr/bin/env bash
## Behavioural check on S12.14: the suite line reclaims a holder that is alive and stopped.
## The fault, measured on 2026-11-04: a runner in a scratch copy held the machine's one lane for over an hour with its process alive, no CPU
## progress and no file touched. Every waiter stood behind it, and the ticket was never taken out, because liveness is decided by `kill -0`
## alone (sh-test/check-fixtures/rig-temp.include.sh:58, sh-test/AgentsRunTests.sh:300).
## Held:
##   1. A CHECK TICKET WHOSE HOLDER IS GONE IS TAKEN OUT, as it is today.
##   2. A CHECK TICKET WHOSE HOLDER LIVES BUT HAS MADE NO PROGRESS FOR LONGER THAN THE BOUND IS TAKEN OUT TOO, and one whose holder is working is kept.
##   3. A TICKET YOUNGER THAN THE BOUND IS KEPT, however idle its holder looks: a holder that has only just arrived is not stalled.
## Offline: a rig of its own, with its own queue under its own HOME, and holder processes of the check's own.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" ] || rigRefuse "the rig-temp fixture is not in the package"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing"
## The fixture is sourced for its queue functions alone: a private HOME gives this check a line of its own, which is how the check of the line itself
## keeps out of the machine's one.
rigTmp="$( mktemp -d "${TMPDIR:-/tmp}/agent-queue-stall.XXXXXX" )" || exit 1
trap 'rigProcSignalWithChildren TERM $rigStarted 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigStarted=""
HOME="$rigTmp/home" ; export HOME
mkdir -p "$HOME" "$rigTmp/ws/.local/agents" || exit 1
MMDAPP="$rigTmp/ws" ; export MMDAPP
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || rigRefuse "the rig-temp fixture would not load"
rigQueue="$HOME/.agents/magic-team/suite-queue"
mkdir -p "$rigQueue" || exit 1
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
## A holder that works: a loop of shell arithmetic, so its CPU time keeps moving. A holder that stalls: `sleep`, so its CPU time stands still.
sleep 900 & rigStalled=$! ; rigStarted="$rigStarted $rigStalled"
( while : ; do : ; done ) & rigWorking=$! ; rigStarted="$rigStarted $rigWorking"
sleep 1
rigTicket(){ ## name, pid, an age
	printf 'pid=%s\norigin=%s\nkind=check\nsince=%s\n' "$2" "${MDLT_ORIGIN:-}" "$3" > "$rigQueue/000000000$1.000000.$2.ticket"
}

echo "-- 1. a holder that is gone --"
rigTicket 1 999999 2026-01-01T00:00:00Z
rigAssert "a ticket whose holder is gone is taken out of the line" "$( rigQueueTicketState "$rigQueue/0000000001.000000.999999.ticket" "$$" )" "gone"

echo "-- 2. a holder that is alive and stopped --"
rigTicket 2 "$rigStalled" "$( date -u -v-2H '+%Y-%m-%dT%H:%M:%SZ' 2> /dev/null || date -u -d '2 hours ago' '+%Y-%m-%dT%H:%M:%SZ' )"
rigAssert "a ticket two hours old whose holder lives but has made no progress is stale" \
	"$( rigQueueTicketState "$rigQueue/0000000002.000000.$rigStalled.ticket" "$$" )" "stale"
rigTicket 3 "$rigWorking" "$( date -u -v-2H '+%Y-%m-%dT%H:%M:%SZ' 2> /dev/null || date -u -d '2 hours ago' '+%Y-%m-%dT%H:%M:%SZ' )"
rigAssert "a ticket two hours old whose holder is working is kept" \
	"$( rigQueueTicketState "$rigQueue/0000000003.000000.$rigWorking.ticket" "$$" )" "alive"

echo "-- 3. a holder that has only just arrived --"
rigTicket 4 "$rigStalled" "$( date -u '+%Y-%m-%dT%H:%M:%SZ' )"
rigAssert "a ticket younger than the bound is kept, however idle its holder looks" \
	"$( rigQueueTicketState "$rigQueue/0000000004.000000.$rigStalled.ticket" "$$" )" "alive"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SUITE QUEUE STALL CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'SUITE_QUEUE_STALL: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
