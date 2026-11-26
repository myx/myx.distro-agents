#!/usr/bin/env bash
## Behavioural check on the kept-duty decision (AgentsToolsScheduleDutyKeptHeld): a duty session whose own record carries a kill mark
## is dropped; one whose run merely ended without a handback is kept, so the next start resumes it in place (the sketch's resume rule).
## Offline: a store of its own is built here, two records and their kept lists, and nothing of the real workspace is read.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
heldInclude="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/schedule/AgentsTools.DispatcherSchedule.include"
[ -f "$heldInclude" ] || { echo "⛔ ERROR: the schedule include is not at the origin: $heldInclude" >&2 ; exit 1 ; }
heldTmp="$( mktemp -d "${TMPDIR:-/tmp}/AgentsScheduleDutyKeptHeldCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$heldTmp"' EXIT
heldRecord(){ ## session, extra front-matter line
	mkdir -p "$heldTmp/.local/agents/spawned/$1" "$heldTmp/.local/agents/sessions/$1"
	{
		printf -- '---\n'
		printf 'owner: magic-devops\n'
		printf 'session-id: %s\n' "$1"
		printf 'status: spawn-ended-without-close\n'
		[ -z "${2:-}" ] || printf '%s\n' "$2"
		printf -- '---\n'
	} > "$heldTmp/.local/agents/spawned/$1/$1.spawn.md"
	printf 'stamp:1\nown\t%s\n' "$heldTmp/.local/agents/spawned/$1/$1.spawn.md" > "$heldTmp/.local/agents/sessions/$1/records.kept"
}
heldRecord aaaaaaaa-0000-0000-0000-000000000001 ""
heldRecord bbbbbbbb-0000-0000-0000-000000000002 "killed-at: 2026-11-26 19:00 +0200"
heldPasses=0 heldFails=0
heldAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; heldPasses=$(( heldPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; heldFails=$(( heldFails + 1 )) ; fi
}
MMDAPP="$heldTmp" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '
	. "'"$MDLT_ORIGIN"'/myx/myx.distro-agents/sh-lib/common/AgentsTools.FrontmatterKey.include" 2> /dev/null
	. "'"$MDLT_ORIGIN"'/myx/myx.distro-agents/sh-lib/session/AgentsTools.StartedRecords.include" 2> /dev/null
	. "'"$heldInclude"'" 2> /dev/null
	printf "kept=%s\n" "$( AgentsToolsScheduleDutyKeptHeld aaaaaaaa-0000-0000-0000-000000000001 )"
	printf "killed=%s\n" "$( AgentsToolsScheduleDutyKeptHeld bbbbbbbb-0000-0000-0000-000000000002 )"
' > "$heldTmp/out" 2> "$heldTmp/err"
heldAssert "a run that ended without a handback leaves the session kept" "$( LC_ALL=C sed -n 's/^kept=//p' "$heldTmp/out" )" "no"
heldAssert "an owner's kill mark drops it" "$( LC_ALL=C sed -n 's/^killed=//p' "$heldTmp/out" )" "yes"
if [ "$heldFails" -ne 0 ] ; then
	echo "⛔ SCHEDULE DUTY KEPT CHECK FAILED: $heldFails of $(( heldPasses + heldFails )) assertion(s)" >&2
	cat "$heldTmp/err" >&2 ; exit 1
fi
echo "SCHEDULE_DUTY_KEPT: OK ($heldPasses assertions, offline)"
