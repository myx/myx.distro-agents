#!/usr/bin/env bash
## Behavioural check on the two gap routines of the team, magic-team.readme-gap and magic-team.file-comment-gap (S5.2): a start that names no
## member is refused, since the members who carry an Idle-Tasks entry are not something any tooling reads, so `keeper-*` and `partner-*` would
## expand to members that have none. The routines say `<type>-?` in their executors (a choice, never auto-selected): the roster the session
## spawner and the routine list both read (AgentsToolsSpawnRoutineExecutorsRoster) is then no roster, with the reason `choice-required` and
## the type. Run rather than read, over the real routine files and a rig skillset holding one keeper and one partner, in the shell the spawner uses.
## Held: for each routine, its executors line holds a `<type>-?` entry for each type it names and no `<type>-*` entry; the roster refuses it
## with `choice-required<TAB><type>`, the type the first entry names; and the routine validator accepts the routine file. Offline.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents"
rigSkills="$rigPackage/skillset/magic-team"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -d "$rigSkills" ] || rigRefuse "the skillset is not at the origin this workspace resolves: $rigSkills"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRoutineGapNamedCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigMembers="$rigTmp/members"
mkdir -p "$rigWs/.local" "$rigMembers/keeper-rig" "$rigMembers/partner-rig"
printf 'rig\n' > "$rigMembers/keeper-rig/keeper-rig.basic.md" ; printf 'rig\n' > "$rigMembers/partner-rig/partner-rig.basic.md"
[ "$rigWs" != "${MMDAPP%/}" ] || rigRefuse "the rig workspace is the real one"
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigRoster(){ ## executors value -> "<rc>:<reason with the tab as a bar>"
	( cd "$rigWs" && env -i HOME="$rigTmp" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigMembers" bash -c '
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SpawnRoutine.include"
		rosterOut="$( AgentsToolsSpawnRoutineExecutorsRoster "$1" )" ; rosterRc=$?
		printf "%s:%s" "$rosterRc" "$( printf "%s" "$rosterOut" | head -1 | tr "\t" "|" )"' rig "$1" 2> /dev/null )
}

for rigRoutine in magic-team.readme-gap magic-team.file-comment-gap ; do
	rigFile="$rigSkills/magic-team/$rigRoutine.routine.md"
	[ -f "$rigFile" ] || rigRefuse "the routine is not in the skillset: $rigFile"
	rigExecutors="$( LC_ALL=C awk 'NR == 1 && $0 == "---" { fm = 1 ; next } fm && $0 == "---" { exit } fm && index( $0, "executors: " ) == 1 { print substr( $0, 12 ) ; exit }' "$rigFile" )"
	rigTypes="$( printf '%s' "$rigExecutors" | LC_ALL=C tr ',' '\n' | LC_ALL=C sed 's/^ *//;s/ *$//' | LC_ALL=C sed -n 's/-[*?]$//p' | LC_ALL=C tr '\n' ' ' )"
	rigAssert "$rigRoutine: its executors name a choice for each type, and no wildcard (executors: $rigExecutors)" \
		"$( printf '%s' "$rigExecutors" | LC_ALL=C grep -c -e '-\*' ):$( printf '%s' "$rigExecutors" | LC_ALL=C tr ',' '\n' | LC_ALL=C grep -c -e '-?' ):$( printf '%s' "$rigTypes" | LC_ALL=C wc -w | LC_ALL=C tr -d ' ' )" \
		"0:$( printf '%s' "$rigTypes" | LC_ALL=C wc -w | LC_ALL=C tr -d ' ' ):$( printf '%s' "$rigTypes" | LC_ALL=C wc -w | LC_ALL=C tr -d ' ' )"
	rigFirstType="${rigTypes%% *}"
	rigAssert "$rigRoutine: a start that names no member is refused, as a choice of the first type" "$( rigRoster "$rigExecutors" )" "1:choice-required|$rigFirstType"
done

if [ "$rigFails" -gt 0 ] ; then
	echo "⛔ ROUTINE GAP NAMED CHECK FAILED: $rigFails of $(( rigFails + rigPasses )) assertion(s)" >&2
	exit 1
fi
echo "ROUTINE_GAP_NAMED: OK ($rigPasses assertions, offline)"
