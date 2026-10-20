#!/usr/bin/env bash
## Behavioural check on the validator's rule for the checkpoint operations in a routine's `allows:` (F10.5 of the refactorings epic):
## `DistroAgentsTesting.fn.sh --skillset-validate-routine <routine-file>` (the stub of the one validator, --intern-doc-validate routine).
## The routine's frontmatter allows --executor-checkpoint-push, --executor-checkpoint-rewind and --executor-checkpoint-exit, as `<who>:<operation>`,
## only to a single-participant session -- a standalone one, of one executor and no invitee -- since a rewind returns one member's conversation.
## Held:
##   1. a standalone routine of one executor and no invitee passes, with the operations allowed to executors, to participants and by name
##   2. the rule refuses, on the `allows` row, a routine whose kind is not standalone, whose executors are not one member (two members, the
##      team, or none) and that has invitees; and an operation of the --executor- family that is not one of the three
##   3. the rule touches nothing else: other entries in allows:, and a routine with no allows:, pass as they did
##   4. the two kind routines of the package, which carry the mandated Opening step and the tooling line, pass
## Offline: rig files only; the validator is read-only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigScripts="$rigOrigin/myx/myx.distro-agents/sh-scripts"
rigTesting="$rigScripts/DistroAgentsTesting.fn.sh"
rigKinds="$rigOrigin/myx/myx.distro-agents/skillset/magic-team/magic-team"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTesting" ] || rigRefuse "the testing file is not at the origin this workspace resolves: $rigTesting"
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRoutineCheckpointAllowsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/agents" "$rigTmp/home" "$rigTmp/skills/magic-team" "$rigTmp/skills/rig-a" "$rigTmp/skills/rig-b"
cp "$rigKinds/magic-team.standalone.routine.md" "$rigKinds/magic-team.coworking.routine.md" "$rigTmp/skills/magic-team/" || rigRefuse "the kind routines could not be copied into the rig"
for rigMember in rig-a rig-b ; do printf 'rig\n' > "$rigTmp/skills/$rigMember/$rigMember.basic.md" ; printf 'rig\n' > "$rigTmp/skills/$rigMember/$rigMember.armed.md" ; done

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## A routine of the rig: its kind, executors, invitees (empty: no line) and allows (empty: no line).
rigRoutine(){ ## name, kind, executors, invitees, allows
	{
		printf -- '---\ntype: routine\nexecutors: %s\nmaintainers: magic-coordinator\n' "$3"
		[ -z "$4" ] || printf 'invitees: %s\n' "$4"
		printf 'requires-session-kind: %s\n' "$2"
		[ -z "$5" ] || printf 'allows: %s\n' "$5"
		printf -- '---\n# magic-team.%s.routine — the actual procedure\n\n# Summary\n\nA rig routine.\n\n# Opening steps\n\n1. **open**: open.\n\n# Steps\n\n1. **work**: work.\n\n# Closure steps\n\n1. **close**: close.\n\n' "$1"
		printf "# Routine's local procedures\n\nNone.\n\n# Routine's local rules\n\nNone.\n\n# Routine-specific tooling\n\nNone.\n\n# Maintainer Notes\n\nNone.\n"
	} > "$rigTmp/skills/magic-team/magic-team.$1.routine.md"
}
rigValidate(){ ## routine file -- one call; rc in rigRc, both streams in $rigTmp/said
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigTmp/home" USER=rigacct PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" bash "$rigTesting" --skillset-validate-routine "$1" ) > "$rigTmp/said" 2>&1 < /dev/null || rigRc=$?
}
rigVerdict(){ ## fixed string the answer must name... -- `0` where it passed, else `refused` and each string named or not
	local verdictText verdictName
	if [ "$rigRc" -eq 0 ] ; then printf '0' ; return ; fi
	verdictText="refused"
	for verdictName in "$@" ; do
		if LC_ALL=C grep -q -F -- "$verdictName" "$rigTmp/said" ; then verdictText="$verdictText $verdictName" ; else verdictText="$verdictText (not-named:$verdictName)" ; fi
	done
	printf '%s' "$verdictText"
}
rigFile(){ printf '%s' "$rigTmp/skills/magic-team/magic-team.$1.routine.md" ; }
rigAllThree='executors:--executor-checkpoint-push,executors:--executor-checkpoint-rewind,executors:--executor-checkpoint-exit'

echo "-- 1. a single-participant routine passes --"
rigRoutine solo standalone rig-a "" "$rigAllThree" ; rigValidate "$( rigFile solo )"
rigAssert "standalone, one executor, no invitees line, the three allowed to executors"  "$rigRc" 0
rigRoutine solonone standalone rig-a none "$rigAllThree" ; rigValidate "$( rigFile solonone )"
rigAssert "with invitees: none said"                                                    "$rigRc" 0
rigRoutine soloparts standalone rig-a "" 'participants:--executor-checkpoint-push,participants:--executor-checkpoint-exit' ; rigValidate "$( rigFile soloparts )"
rigAssert "allowed to participants"                                                     "$rigRc" 0
rigRoutine soloname standalone rig-a "" 'rig-a:--executor-checkpoint-rewind' ; rigValidate "$( rigFile soloname )"
rigAssert "allowed to the member by name"                                               "$rigRc" 0

echo "-- 2. what it refuses, on the allows row --"
rigRoutine cow coworking rig-a "" "$rigAllThree" ; rigValidate "$( rigFile cow )"
rigAssert "a coworking routine"                                                         "$( rigVerdict ': allows:' 'kind is not standalone' )" "refused : allows: kind is not standalone"
rigRoutine two standalone 'rig-a, rig-b' "" "$rigAllThree" ; rigValidate "$( rigFile two )"
rigAssert "two executors"                                                               "$( rigVerdict ': allows:' 'executors are not one member' )" "refused : allows: executors are not one member"
rigRoutine team standalone magic-team "" "$rigAllThree" ; rigValidate "$( rigFile team )"
rigAssert "the team as executor"                                                        "$( rigVerdict 'executors are not one member (magic-team)' )" "refused executors are not one member (magic-team)"
rigRoutine inv standalone rig-a rig-b "$rigAllThree" ; rigValidate "$( rigFile inv )"
rigAssert "an invitee"                                                                  "$( rigVerdict ': allows:' 'has invitees (rig-b)' )" "refused : allows: has invitees (rig-b)"
rigRoutine both coworking 'rig-a, rig-b' rig-b "$rigAllThree" ; rigValidate "$( rigFile both )"
rigAssert "all three faults are said, one row each"                                     "$( LC_ALL=C grep -c ': allows: ' "$rigTmp/said" )" 3
rigRoutine other standalone rig-a "" 'executors:--executor-checkpoint-pause' ; rigValidate "$( rigFile other )"
rigAssert "an operation of the --executor- family that is not one of the three"         "$( rigVerdict '--executor-checkpoint-pause is no operation of the --executor- family' '--executor-checkpoint-push' )" "refused --executor-checkpoint-pause is no operation of the --executor- family --executor-checkpoint-push"
rigAssert "and it names the line of allows:, the sixth of the file"                     "$( LC_ALL=C grep -c "magic-team.other.routine.md:[0-9]*: allows: " "$rigTmp/said" ):$( LC_ALL=C sed -n 's/.*routine.md:\([0-9]*\): allows: .*/\1/p' "$rigTmp/said" | head -1 )" "1:6"

echo "-- 3. it touches nothing else --"
rigRoutine plain coworking 'rig-a, rig-b' rig-b 'executors:Read:/some/where,rig-b:Write:/other' ; rigValidate "$( rigFile plain )"
rigAssert "a coworking routine with other entries in allows:"                           "$rigRc" 0
rigRoutine none coworking 'rig-a, rig-b' rig-b "" ; rigValidate "$( rigFile none )"
rigAssert "a routine with no allows:"                                                   "$rigRc" 0
rigRoutine pushy coworking rig-a "" 'executors:--executor-checkpoint-pushy' ; rigValidate "$( rigFile pushy )"
rigAssert "an operation whose name only begins like one of the three is the family's other"  "$( rigVerdict 'is no operation of the --executor- family' )" "refused is no operation of the --executor- family"

echo "-- 4. the two kind routines of the package --"
rigValidate "$rigKinds/magic-team.standalone.routine.md"
rigAssert "the standalone routine, with its Opening step and its tooling line"          "$rigRc" 0
rigValidate "$rigKinds/magic-team.coworking.routine.md"
rigAssert "the coworking routine"                                                       "$rigRc" 0
rigAssert "each ends its Opening steps with the mandated call"                          "$( LC_ALL=C awk '/^# Opening steps$/ { on = 1 ; next } /^# / { on = 0 } on && /^[0-9]+\. \*\*/ { last = $0 } END { sub( /^[0-9]+\. \*\*/, "", last ) ; sub( /\*\*.*$/, "", last ) ; print last }' "$rigKinds/magic-team.standalone.routine.md" ):$( LC_ALL=C awk '/^# Opening steps$/ { on = 1 ; next } /^# / { on = 0 } on && /^[0-9]+\. \*\*/ { last = $0 } END { sub( /^[0-9]+\. \*\*/, "", last ) ; sub( /\*\*.*$/, "", last ) ; print last }' "$rigKinds/magic-team.coworking.routine.md" )" "opening-checkpoint:opening-checkpoint"
rigAssert "and the step runs --executor-checkpoint-push opening"                        "$( LC_ALL=C grep -c -F -e 'DistroAgentsSession.fn.sh --executor-checkpoint-push opening' "$rigKinds/magic-team.standalone.routine.md" "$rigKinds/magic-team.coworking.routine.md" | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/[^ ]*://g' )" "1 1 "

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROUTINE CHECKPOINT ALLOWS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ROUTINE_CHECKPOINT_ALLOWS: OK (%d assertions, offline)\n' "$rigPassCount"
