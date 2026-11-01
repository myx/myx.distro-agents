#!/usr/bin/env bash
## Behavioural check on the two duty fixes the owner asked for.
##
## 1. A started duty's record names its agent-log-thread and no session-thread.
##    Run against a record: `AgentsDutyThreadAndTagCheck.test.sh record <spawn record>`.
## 2. A tag posted to the team channel by another run of the same member is news for the duty,
##    and a same-member post with no tag is not. The Slack read is a stub function, so the real
##    scheduler code runs and nothing opens a socket.
set -u
: "${MMDAPP:?MMDAPP is not set}"
checkHere="${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
[ -f "$checkHere/session/AgentsTools.DispatcherSchedule.include" ] || { echo "⛔ ERROR: the scheduler include is not at the origin this workspace resolves" >&2 ; exit 1 ; }

checkPass=0
checkFail=0
checkAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then
		checkPass=$(( checkPass + 1 ))
	else
		checkFail=$(( checkFail + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}

## --- 1. a record's thread shape -------------------------------------------------
checkRecord(){ ## spawn record
	local recordLog recordSession
	[ -f "$1" ] || { echo "⛔ ERROR: no record at $1, so this check would report on nothing" >&2 ; return 1 ; }
	recordLog="$( LC_ALL=C sed -n 's/^agent-log-thread: //p' "$1" | head -1 )"
	recordSession="$( LC_ALL=C sed -n 's/^session-thread: //p' "$1" | head -1 )"
	printf '  record: %s\n' "${1##*/}"
	printf '    agent-log-thread: %s\n' "${recordLog:-<none>}"
	printf '    session-thread:   %s\n' "${recordSession:-<none>}"
	checkAssert "the record names an agent-log-thread" "$([ -n "$recordLog" ] && printf yes || printf no)" yes
	checkAssert "the record names no session-thread"   "$([ -z "$recordSession" ] && printf yes || printf no)" yes
}

if [ "${1:-}" = "record" ] ; then
	checkRecord "${2:-}"
	[ "$checkFail" -ne 0 ] || { printf 'DUTY_THREAD: OK (%d assertions)\n' "$checkPass" ; exit 0 ; }
	echo "⛔ DUTY THREAD CHECK FAILED: $checkFail of $(( checkPass + checkFail )) assertion(s)" >&2
	exit 1
fi

## --- 2. the team-channel tag, through the real scheduler ------------------------
checkRoot="$( mktemp -d "${TMPDIR:-/tmp}/duty-tag-check.XXXXXX" )" || exit 1
trap 'rm -rf -- "$checkRoot"' EXIT
mkdir -p "$checkRoot/.local/agents/schedule/tags"
export MMDAPP="$checkRoot"
. "$checkHere/session/AgentsTools.DispatcherSchedule.include" > /dev/null 2>&1 || { echo "⛔ ERROR: the dispatcher include would not load" >&2 ; exit 1 ; }

## The read the scheduler makes, answered from $CHECK_CANNED. Declared before the call, so the
## scheduler's own `type DistroAgentsTools` guard leaves it alone.
DistroAgentsTools(){ ## the operations the dispatcher uses
	case "$1" in
		--intern-op-comms-slack-read) printf '%s\n' "$CHECK_CANNED" ;;
	esac
	return 0
}

checkTag(){ ## canned lines, what the check calls it
	checkTick=$(( checkTick + 1 ))
	CHECK_CANNED="$( printf '%s' "$1" | LC_ALL=C sed "s/^CHECKSTAMP/$(( checkBase + checkTick ))/" )"
	: > "$checkRoot/.local/agents/schedule/tags/magic-coordinator"
	AgentsToolsScheduleTeamTags magic-coordinator yes > /dev/null 2>&1
	checkHit="$( LC_ALL=C sed -n '1p' "$checkRoot/.local/agents/schedule/tags/magic-coordinator" 2> /dev/null )"
	printf '  %s -> tag %s\n' "$2" "${checkHit:-<none>}"
}

## The message time is above the read's own floor, which is now, and each case is later than the
## one before it: a fixture below the floor is skipped for its age, and one not newer than the
## last is skipped by the pointer, and either would prove nothing about the filter.
checkBase="$(( $( date +%s ) + 10 ))"
checkTick=0

checkTag 'CHECKSTAMP.000000 | U1 | [sender: magic-coordinator] @magic-coordinator look at this' 'a same-member tag, another run'
checkAssert "a tag from another run of the same member is news" "$([ -n "$checkHit" ] && printf yes || printf no)" yes
checkTag 'CHECKSTAMP.000000 | U1 | [sender: magic-coordinator] a round note, no mention in it' 'a same-member post with no tag'
checkAssert "a same-member post with no tag wakes nothing" "$checkHit" ""
checkTag 'CHECKSTAMP.000000 | U1 | [sender: magic-librarian] @magic-coordinator hello' 'another member tag'
checkAssert "another member's tag is news" "$([ -n "$checkHit" ] && printf yes || printf no)" yes

if [ "$checkFail" -ne 0 ] ; then
	echo "⛔ DUTY TAG CHECK FAILED: $checkFail of $(( checkPass + checkFail )) assertion(s)" >&2
	exit 1
fi
printf 'DUTY_TAG: OK (%d assertions)\n' "$checkPass"
