#!/usr/bin/env bash
## Behavioural check on the `<type>-*`/`<type>-?`/`all-present-members` roster tokens of the routine spawner
## (sh-lib/session/AgentsTools.SpawnRoutine.include), run rather than read: the members a type wildcard names, the
## attendance a `.basic.md` states, the members present, the entries a value expands to, and the executors and invitees
## rosters built over them. Offline: a rig member directory stands for the team; nothing reaches Slack.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"

. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsTeamMemberContractCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
export HOME="$rigTmp/home" ; mkdir -p "$HOME"
export MMDAPP="$rigTmp/ws" ; mkdir -p "$MMDAPP/.local"
export MDAT_DATA_ROOT="$rigTmp/data" ; mkdir -p "$MDAT_DATA_ROOT"
export MDAT_SKILLSET_ROOT="$rigTmp/members"
export MDSC_CMD="DistroAgentsTools"

rigPass=0 rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

## The rig team: the team itself, two magic-* members (one silent, one invited), two keeper-* members (one silent, one
## present), and one partner-* member. A member with no .basic.md says nothing of attendance.
rigMember(){ ## name, [attendance]
	mkdir -p "$MDAT_SKILLSET_ROOT/$1"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$MDAT_SKILLSET_ROOT/$1/$1.basic.md"
	if [ -n "${2:-}" ] ; then
		printf -- '---\nmaintainers: rig\nattendance: %s\n---\nrig identity\n' "$2" > "$MDAT_SKILLSET_ROOT/$1/$1.basic.md"
	fi
}
rigMember magic-team
rigMember magic-coordinator
rigMember magic-developer invited
rigMember keeper-myx
rigMember keeper-far present
rigMember partner-ndm

. "$rigHere/session/AgentsTools.SpawnRoutine.include"

echo "-- the members a type wildcard names --"
rigAssert "magic-* names the magic members, the team excepted" "$( AgentsToolsSpawnRoutineTypeMembers magic | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )" "magic-coordinator magic-developer"
rigAssert "keeper-* names the keepers" "$( AgentsToolsSpawnRoutineTypeMembers keeper | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )" "keeper-far keeper-myx"
rigAssert "a type no member carries names nobody" "$( AgentsToolsSpawnRoutineTypeMembers client )" ""

echo "-- attendance --"
rigAssert "a magic-* member that says nothing is present" "$( AgentsToolsTeamMemberPresent magic-coordinator && echo present || echo invited )" present
rigAssert "attendance: invited reads invited" "$( AgentsToolsTeamMemberPresent magic-developer && echo present || echo invited )" invited
rigAssert "a non-magic member that says nothing is invited" "$( AgentsToolsTeamMemberPresent keeper-myx && echo present || echo invited )" invited
rigAssert "attendance: present reads present" "$( AgentsToolsTeamMemberPresent keeper-far && echo present || echo invited )" present
rigAssert "the members present are the present ones, the team excepted" "$( AgentsToolsSpawnRoutinePresentMembers | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )" "keeper-far magic-coordinator"

echo "-- the entries a value expands to --"
rigAssert "a plain name stays a name" "$( AgentsToolsSpawnRoutineEntryMembers 'magic-coordinator' )" "magic-coordinator"
rigAssert "a wildcard names its members" "$( AgentsToolsSpawnRoutineEntryMembers 'magic-*' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )" "magic-coordinator magic-developer"
rigAssert "a wildcard that names no member is none-of-type" "$( AgentsToolsSpawnRoutineEntryMembers 'client-*' )" "$( printf 'none-of-type\tclient\n' )"
rigAssert "a -? wildcard is a choice to make, its candidates after it" "$( AgentsToolsSpawnRoutineEntryMembers 'magic-?' | LC_ALL=C sed -n '1p' ) $( AgentsToolsSpawnRoutineEntryMembers 'magic-?' | LC_ALL=C sed '1d' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "$( printf 'choice-required\tmagic' ) magic-coordinator magic-developer "

echo "-- the executors roster --"
rigAssert "a plain list of members is the roster" "$( AgentsToolsSpawnRoutineExecutorsRoster 'magic-coordinator, keeper-far' )" "magic-coordinator
keeper-far"
rigAssert "a wildcard expands into the roster" "$( AgentsToolsSpawnRoutineExecutorsRoster 'keeper-*' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )" "keeper-far keeper-myx"
rigAssert "a wildcard that names no member is refused" "$( AgentsToolsSpawnRoutineExecutorsRoster 'client-*' 2>&1 || : )" "$( printf 'none-of-type\tclient\n' )"
rigAssert "a -? wildcard is refused, with its candidates" "$( AgentsToolsSpawnRoutineExecutorsRoster 'magic-?' 2>&1 | LC_ALL=C sed -n '1p' ) $( AgentsToolsSpawnRoutineExecutorsRoster 'magic-?' 2>&1 | LC_ALL=C sed '1d' | LC_ALL=C grep -c . )" "$( printf 'choice-required\tmagic' ) 2"
rigAssert "all-present-members is refused in executors" "$( AgentsToolsSpawnRoutineExecutorsRoster 'all-present-members' 2>&1 || : )" "all-present-members"

echo "-- the invitees roster --"
rigAssert "an empty or none value names no invitee" "$( AgentsToolsSpawnRoutineInviteesRoster 'none' )" ""
rigAssert "all-present-members is the members present" "$( AgentsToolsSpawnRoutineInviteesRoster 'all-present-members' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )" "keeper-far magic-coordinator"
rigAssert "a wildcard expands into the invitees" "$( AgentsToolsSpawnRoutineInviteesRoster 'keeper-*' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )" "keeper-far keeper-myx"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ AGENTS TEAM MEMBER CONTRACT CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'AGENTS_TEAM_MEMBER_CONTRACT: OK (%d assertions, offline, rig member directory)\n' "$rigPass"
