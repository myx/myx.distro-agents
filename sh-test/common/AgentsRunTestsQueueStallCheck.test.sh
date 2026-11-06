#!/usr/bin/env bash
## Behavioural check on the suite line's ticket state (S12.14, S10.29): a place in the line is given up rather than held by
## the gone. The fault, measured on 2026-11-04: a runner in a scratch copy held the machine's line for over an hour with its
## process alive and no CPU progress, and every waiter stood behind it.
## Held, on the one reader both waiters ask (`rigQueueTicketState` in `check-fixtures/rig-temp.include.sh`):
##   1. A TICKET WITH NO SESSION LINE WAS NEVER WRITTEN WHOLE, and holds nobody's place.
##   2. A TICKET NAMING A RUN WHOSE RECORDS SAY IT ENDED IS GIVEN UP: a spawn record settled, or a session store carrying the
##      end marker of a root session.
##   3. A TICKET WHOSE WAITING HOLDER STOPPED BEATING PAST MDAT_SUITE_QUEUE_STALL_SECONDS IS GIVEN UP, and one whose beat
##      still moves is kept, as is one that has never beaten at all: no beat is no evidence that its holder stopped.
##   4. A TICKET THAT HAS HELD THE LINE PAST MDAT_SUITE_QUEUE_HOLD_SECONDS IS GIVEN UP, and one younger than that bound is
##      kept, however idle its holder looks.
## Offline: a rig of its own, with its own queue under its own HOME.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" ] || rigRefuse "the rig-temp fixture is not in the package"
## The fixture is sourced for its queue functions alone: a private HOME gives this check a line of its own, which is how the
## check of the line itself keeps out of the machine's one.
rigTmp="$( mktemp -d "${TMPDIR:-/tmp}/agent-queue-stall.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
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
rigAgo(){ ## hours -- a UTC stamp that many hours before now
	date -u -v-"$1"H '+%Y-%m-%dT%H:%M:%SZ' 2> /dev/null || date -u -d "$1 hours ago" '+%Y-%m-%dT%H:%M:%SZ'
}
rigTicket(){ ## name, session, since, beat -- a ticket, and its beat written beside it where one is given
	printf 'session=%s\norigin=%s\nkind=run\nsince=%s\n' "$2" "${MDLT_ORIGIN:-}" "$3" > "$rigQueue/000000000$1.000000.$2.ticket"
	[ -z "${4:-}" ] || printf '%s\n' "$4" > "$rigQueue/000000000$1.000000.$2.ticket.beat"
}
rigRecord(){ ## session, status -- that session's spawn record
	mkdir -p "$MMDAPP/.local/agents/spawned/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nstatus: %s\nhost: %s\n---\n\n# Spawn session: %s\n' "$1" "$1" "$2" "$( hostname -s 2> /dev/null )" "$1" > "$MMDAPP/.local/agents/spawned/$1/$1.spawn.md"
}
rigNow="$( date +%s )"
MDAT_SUITE_QUEUE_STALL_SECONDS=3600 ; export MDAT_SUITE_QUEUE_STALL_SECONDS
MDAT_SUITE_QUEUE_HOLD_SECONDS=21600 ; export MDAT_SUITE_QUEUE_HOLD_SECONDS

echo "-- 1. a ticket with no session line was never written whole --"
: > "$rigQueue/0000000001.000000.partial.ticket"
rigAssert "a ticket with no session line is given up, and holds nobody's place" \
	"$( rigQueueTicketState "$rigQueue/0000000001.000000.partial.ticket" )" "gone"

echo "-- 2. a ticket whose run's records say it ended is given up --"
rigTicket 2 rig-settled-run "$( rigAgo 0 )" "$rigNow"
rigRecord rig-settled-run spawn-succeeded
rigAssert "a ticket naming a run whose spawn record settled is given up" \
	"$( rigQueueTicketState "$rigQueue/0000000002.000000.rig-settled-run.ticket" )" "ended"
rigTicket 3 rig-marked-run "$( rigAgo 0 )" "$rigNow"
mkdir -p "$MMDAPP/.local/agents/sessions/rig-marked-run"
printf 'ended-at: 2026-01-01T00:00:00Z\nreason: clear\n' > "$MMDAPP/.local/agents/sessions/rig-marked-run/ended"
rigAssert "a ticket naming a run whose session store carries the end marker is given up" \
	"$( rigQueueTicketState "$rigQueue/0000000003.000000.rig-marked-run.ticket" )" "ended"
rigTicket 4 rig-started-run "$( rigAgo 0 )" "$rigNow"
rigRecord rig-started-run spawn-started
rigAssert "control: a ticket naming a run that is still started is kept, so the give-up above is the record's" \
	"$( rigQueueTicketState "$rigQueue/0000000004.000000.rig-started-run.ticket" )" "alive"

echo "-- 3. a waiting holder that stopped beating gives up its place --"
rigTicket 5 rig-stopped-run "$( rigAgo 0 )" "$(( rigNow - 7200 ))"
rigAssert "a beat that has stood still for two hours, past the stall bound, gives up the place" \
	"$( rigQueueTicketState "$rigQueue/0000000005.000000.rig-stopped-run.ticket" )" "stalled"
rigTicket 6 rig-beating-run "$( rigAgo 0 )" "$(( rigNow - 5 ))"
rigAssert "control: a beat five seconds old keeps the place, so the give-up above is the bound" \
	"$( rigQueueTicketState "$rigQueue/0000000006.000000.rig-beating-run.ticket" )" "alive"
rigTicket 7 rig-silent-run "$( rigAgo 0 )"
rigAssert "a ticket that has never beaten is kept by its age alone: no beat is no evidence that its holder stopped" \
	"$( rigQueueTicketState "$rigQueue/0000000007.000000.rig-silent-run.ticket" )" "alive"

echo "-- 4. a place held past the stated limit gives up, and one younger than it is kept --"
rigTicket 8 rig-old-run "$( rigAgo 7 )" "$rigNow"
rigAssert "a place held seven hours, past the six-hour limit, is given up" \
	"$( rigQueueTicketState "$rigQueue/0000000008.000000.rig-old-run.ticket" )" "held"
rigTicket 9 rig-young-run "$( rigAgo 0 )" "$rigNow"
rigAssert "control: a place a moment old is kept, however idle it looks" \
	"$( rigQueueTicketState "$rigQueue/0000000009.000000.rig-young-run.ticket" )" "alive"

echo "-- 5. a holder that has its turn is at work, and its stale beat is no evidence that it stopped --"
## TWO PLACES JUDGE A TICKET, AND THIS ROW WATCHES ONE: `rigQueueTicketState` here, and the line-taking loop
## (`rigQueueTurn`, called only from `rigTempDir`, which this check does not use) which deletes every ticket whose
## state is not `own` or `alive`. So a won turn answered with a sixth state word would be invisible to that loop:
## answer `alive`, and let the hold limit be the one thing that ends it.
rigTicket 10 rig-working-run "$( rigAgo 0 )" "$(( rigNow - 7200 ))"
printf 'turn-won=%s\n' "$rigNow" >> "$rigQueue/00000000010.000000.rig-working-run.ticket"
rigAssert "a holder that has won its turn is kept, though its beat went stale while it worked" \
	"$( rigQueueTicketState "$rigQueue/00000000010.000000.rig-working-run.ticket" )" "alive"
rigTicket 11 rig-held-turn-run "$( rigAgo 7 )" "$rigNow"
printf 'turn-won=%s\n' "$(( rigNow - 25200 ))" >> "$rigQueue/00000000011.000000.rig-held-turn-run.ticket"
rigAssert "control: the same ticket past the hold limit is still given up, so the turn it won does not make it for ever" \
	"$( rigQueueTicketState "$rigQueue/00000000011.000000.rig-held-turn-run.ticket" )" "held"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SUITE QUEUE STALL CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'SUITE_QUEUE_STALL: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
