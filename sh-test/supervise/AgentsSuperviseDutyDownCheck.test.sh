#!/usr/bin/env bash
## Behavioural check on the supervision scan's `duty-down` and `duty-detached` kinds, run rather than read, against a rig workspace
## built here: a kept duty session for some members, and a record table of the scan's own shape.
## Held, one case per statement:
##   1. control: a member with no kept duty session is never named, whatever its records say
##   2. a kept duty session with only a failed duty record older than the bound is `duty-down`, naming the newest record's status
##   3. the same member with its newest duty record inside the bound is not named
##   4. a duty open in the kept session is not named
##   5. a duty open in another session than the kept one is `duty-detached`, naming both sessions
##   6. a record of a routine that is no duty is neither an open duty nor a newest one
##   7. a member that holds no duty (a partner) is never named
## Red before the kinds: every case fails with the function absent.
## Offline: it writes only its own rig, and reads the package at the origin.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -d "$rigPackage" ] || rigRefuse "the package is not at the origin this run resolves: $rigPackage"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSuperviseDutyDownCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents/schedule/duty-session" || rigRefuse "cannot make the rig workspace"
export MMDAPP="$rigWs"

rigPass=0 ; rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
rigNow=1795507000
## The scan's table: `<sandbox> <name> <written> <spawn-id> <session-id> <owner> <status> <run-process> <parent> <agent-less> <routine>`.
rigRow(){ ## written, session, owner, status, routine
	printf 'sandbox\tname\t%s\tspawn\t%s\t%s\t%s\t-\t-\t\t%s\n' "$1" "$2" "$3" "$4" "$5"
}
rigKeep(){ ## member, session
	printf '%s\n' "$2" > "$rigWs/.local/agents/schedule/duty-session/$1"
}
rigOut=""
rigScan(){ ## the table
	rigOut="$( ( . "$rigPackage/sh-lib/supervise/AgentsTools.SuperviseDutyDown.include" ; AgentsToolsSuperviseDutyDown "$rigWs" "$rigNow" "$1" ) 2> /dev/null )"
	rigOut="${rigOut//$'\n'/;}"
}
rigDuty="magic-coordinator.work-duty.routine.md"

echo "-- 1. control: no kept duty session, no name --"
rigScan "$( rigRow $(( rigNow - 90000 )) sess-a magic-nobody spawn-failed "$rigDuty" )"
rigAssert "a member with no kept session is not named" "$rigOut" ""

echo "-- 2. a kept session with a long-failed duty is down --"
rigKeep magic-coordinator sess-kept
rigScan "$( rigRow $(( rigNow - 6000 )) sess-kept magic-coordinator spawn-failed "$rigDuty" )"
rigAssert "the down duty is named with its newest status and age" "$rigOut" "duty-down ws magic-coordinator newest=spawn-failed age=100m"

echo "-- 3. a newest duty record inside the bound is not down --"
rigScan "$( rigRow $(( rigNow - 300 )) sess-kept magic-coordinator spawn-failed "$rigDuty" )"
rigAssert "a record five minutes old is within the bound" "$rigOut" ""

echo "-- 4. a duty open in the kept session is not named --"
rigScan "$( rigRow $(( rigNow - 6000 )) sess-kept magic-coordinator spawn-failed "$rigDuty" ; rigRow $(( rigNow - 60 )) sess-kept magic-coordinator spawn-started "$rigDuty" )"
rigAssert "an open duty in the kept session is not named" "$rigOut" ""

echo "-- 5. a duty open in another session is detached --"
rigScan "$( rigRow $(( rigNow - 60 )) sess-other-1234 magic-coordinator spawn-started "$rigDuty" )"
rigAssert "the open duty in another session is named with both sessions" "$rigOut" "duty-detached ws magic-coordinator kept=sess-kep live=sess-oth"

echo "-- 6. a routine that is no duty counts for nothing --"
rigScan "$( rigRow $(( rigNow - 60 )) sess-kept magic-coordinator spawn-started magic-team.grooming.routine.md ; rigRow $(( rigNow - 6000 )) sess-kept magic-coordinator spawn-failed "$rigDuty" )"
rigAssert "an open grooming run does not hide a down duty" "$rigOut" "duty-down ws magic-coordinator newest=spawn-failed age=100m"

echo "-- 7. a member that holds no duty is never named, with a kept session and a long-failed duty --"
rigKeep partner-ndm-infra sess-partner
rigScan "$( rigRow $(( rigNow - 90000 )) sess-partner partner-ndm-infra spawn-failed "$rigDuty" )"
rigAssert "a partner member is not a duty that is down" "$rigOut" ""

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SUPERVISE DUTY DOWN CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	echo "  fix:  AgentsToolsSuperviseDutyDown in sh-lib/supervise/ -- never the assertion" >&2
	exit 1
fi
printf 'SUPERVISE_DUTY_DOWN: OK (%d assertions, offline)\n' "$rigPass"
