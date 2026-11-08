#!/usr/bin/env bash
## Behavioural check on AgentsToolsScheduleDutyRestartDue: when a duty that ended is started again.
## The records are fixtures with mtimes set by hand, so the 300 seconds is exercised at its edge
## and not by waiting three hundred seconds.
set -u
: "${MMDAPP:?MMDAPP is not set}"
dueHere="${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
[ -f "$dueHere/session/AgentsTools.DispatcherSchedule.include" ] || { echo "⛔ ERROR: the dispatcher include is not at the origin this workspace resolves" >&2 ; exit 1 ; }

: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
## The rig lives in the workspace's own scratch, never in the system temp folder.
mkdir -p "$MMDAPP/.local/agents/scratch/sh-test" || exit 1
dueRoot="$( mktemp -d "$MMDAPP/.local/agents/scratch/sh-test/AgentsDutyRestartCheck.XXXXXXXX" )" || exit 1
trap 'chmod -R u+w -- "$dueRoot" 2> /dev/null ; rm -rf -- "$dueRoot"' EXIT
export MMDAPP="$dueRoot"
mkdir -p "$dueRoot/.local/agents/spawned/cow-one" "$dueRoot/.local/agents/schedule/dismissed"

dueRecord(){ ## file, spawn id, owner, status, minutes ago
	printf -- '---\nspawn-id: %s\nsession-id: cow-one\nowner: %s\nstatus: %s\nroutine: magic-coordinator.work-duty.routine.md\n---\n' "$2" "$3" "$4" > "$1"
	dueWhen="$( date -v-"$5"M '+%Y%m%d%H%M' 2> /dev/null )" || dueWhen="$( date -d "-$5 minutes" '+%Y%m%d%H%M' )"
	touch -t "$dueWhen" "$1"
}

cd "$dueRoot" || exit 1
## The duty records are kept for MDAT_DUTY_RECORDS_SECONDS in the product, and this check makes records between its asks, so it reads them fresh.
export MDAT_DUTY_RECORDS_SECONDS=0 MDAT_STARTED_RECORDS_SECONDS=0
set +u
MDSC_CMD=check . "$dueHere/session/AgentsTools.DispatcherSchedule.include" > /dev/null 2>&1 || { echo "⛔ ERROR: the dispatcher include would not load" >&2 ; exit 1 ; }

duePass=0
dueFail=0
dueAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then
		duePass=$(( duePass + 1 ))
	else
		dueFail=$(( dueFail + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}

## Ten minutes after the end: due.
dueRecord "$dueRoot/.local/agents/spawned/cow-one/aaa.spawn.md" aaa magic-librarian spawn-failed 10
dueAssert "a duty that ended ten minutes ago is due" \
	"$( AgentsToolsScheduleDutyRestartDue magic-librarian > /dev/null && printf due || printf held )" due

## One minute after the end: held, because the fixed wait has not passed. The control for the line above.
touch -t "$( date '+%Y%m%d%H%M' )" "$dueRoot/.local/agents/spawned/cow-one/aaa.spawn.md"
dueAssert "a duty that ended a moment ago is held" \
	"$( AgentsToolsScheduleDutyRestartDue magic-librarian > /dev/null && printf due || printf held )" held

## A dismissal is the member's last word on the matter, and it keeps the duty down.
dueRecord "$dueRoot/.local/agents/spawned/cow-one/aaa.spawn.md" aaa magic-librarian spawn-failed 10
: > "$dueRoot/.local/agents/schedule/dismissed/aaa"
dueAssert "a dismissed duty is held" \
	"$( AgentsToolsScheduleDutyRestartDue magic-librarian > /dev/null && printf due || printf held )" held
rm -f "$dueRoot/.local/agents/schedule/dismissed/aaa"

## Another member's record is not this member's restart.
dueAssert "another member's ended duty is not this member's" \
	"$( AgentsToolsScheduleDutyRestartDue magic-coordinator > /dev/null && printf due || printf held )" held

## The newest record decides: an older one at twenty minutes does not outrank a fresh one.
dueRecord "$dueRoot/.local/agents/spawned/cow-one/aaa.spawn.md" aaa magic-librarian spawn-failed 20
dueRecord "$dueRoot/.local/agents/spawned/cow-one/bbb.spawn.md" bbb magic-librarian spawn-succeeded 1
dueAssert "the newest ended duty decides, not the oldest" \
	"$( AgentsToolsScheduleDutyRestartDue magic-librarian > /dev/null && printf due || printf held )" held

## An open record is no end at all. Nothing else of this member's is left, so only the open one is judged.
rm -f "$dueRoot/.local/agents/spawned/cow-one/bbb.spawn.md" "$dueRoot/.local/agents/spawned/cow-one/aaa.spawn.md"
dueRecord "$dueRoot/.local/agents/spawned/cow-one/ccc.spawn.md" ccc magic-librarian spawn-started 30
dueAssert "an open record is no end and is not restarted" \
	"$( AgentsToolsScheduleDutyRestartDue magic-librarian > /dev/null && printf due || printf held )" held

if [ "$dueFail" -ne 0 ] ; then
	echo "⛔ DUTY RESTART CHECK FAILED: $dueFail of $(( duePass + dueFail )) assertion(s)" >&2
	exit 1
fi
printf 'DUTY_RESTART: OK (%d assertions)\n' "$duePass"
