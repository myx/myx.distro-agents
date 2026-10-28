#!/usr/bin/env bash
## Behavioural check on the work-duty routines and the mix-in of another routine's sections (F7.12): a routine can take sections of another in whole,
## by `includes: <routine file>: <section>, ...`, and the tooling puts them into the text where the routine is read, so the rules stand in one place and in no
## copy. The duty routines carry no `includes:` now (the advance round is `magic-team.advance.routine`, which the duty runs as a step), so the engine is held
## on a rig copy that carries one. Held, against the real routine files of the package, run and not read:
##   1. NO DUTY ROUTINE INCLUDES: the coordinator's duty and the team's duty have no `includes:` line, and read mixed with the routine of their kind with none of
##      the steps of the advance routine in them
##   2. THE ADVANCE ROUTINE (magic-team.advance.routine) says `runs-at: none`: nothing starts it by itself
##   3. THE VALIDATOR takes the duty routines and the advance routine with no row, and, on a rig copy of the duty with an `includes:` line, refuses an `includes:`
##      that names no routine, a section that cannot be taken, a section the routine does not hold, and a `wait-sources:` word that is none of
##      inbox:{{team-member}}, tagged:{{team-member}}, mentions:{{team-member}} and board:<state>
##   4. THE FILES a routine includes are known to the checksum of a cached text (AgentsToolsSpawnRoutineIncludePaths): none for a duty, the advance routine's
##      for the rig copy
##   5. THE DUTY WAITS on its own inbox and what is tagged to it or mentions it (a mention, a DM) for every member, and for the coordinator also on the active
##      states of the board (`wait-sources:`), `mentions:{{team-member}}` in both
## Offline: a skillset root of this rig, with the real folders of the package linked in; every call through `env -i`.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigSession="$rigPackage/sh-scripts/DistroAgentsSession.fn.sh"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigTeamDir="$rigPackage/skillset/magic-team"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigSession" ] && [ -f "$rigTool" ] && [ -f "$rigTeamDir/magic-coordinator/magic-coordinator.work-duty.routine.md" ] || rigRefuse "the package is not as this check expects"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRoutineIncludesCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigSkills="$rigTmp/skills" rigWs="$rigTmp/ws"
mkdir -p "$rigSkills" "$rigWs/.local/.agents" "$rigTmp/home" "$rigSkills/rig-member"
for rigMember in magic-coordinator magic-team magic-librarian magic-architect ; do ln -s "$rigTeamDir/$rigMember" "$rigSkills/$rigMember" ; done

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigEnv(){ ## the script, then its arguments... -- one call in a clean environment
	local envScript="$1" ; shift
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" \
		bash -c 'case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; cd "$MMDAPP" && exec bash "$@"' rig "$envScript" "$@" 2> /dev/null
}
rigText(){ ## selector -- the text of a routine as its run reads it
	rigEnv "$rigSession" --get-routine-text "$1"
}
rigValidate(){ ## file -- the rows the validator prints
	rigEnv "$rigTool" --intern-doc-validate routine "$1" | LC_ALL=C grep -v -e 'Working in' -e 'SetInputSpec' -e '^$' || :
}
rigDuty="$rigTeamDir/magic-coordinator/magic-coordinator.work-duty.routine.md"
rigAdvance="$rigTeamDir/magic-team/magic-team.advance.routine.md"
rigTeamDuty="$rigTeamDir/magic-team/magic-team.work-duty.routine.md"

echo "-- 1. no duty routine includes: both read mixed with their kind's, with none of the advance steps in them --"
rigText magic-coordinator.work-duty > "$rigTmp/duty.text"
rigText magic-team.work-duty > "$rigTmp/team.text"
rigAssert "neither duty file has an includes: line" "$( LC_ALL=C grep -c '^includes: ' "$rigDuty" "$rigTeamDuty" | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's#[^ ]*/##g' )" "magic-coordinator.work-duty.routine.md:0 magic-team.work-duty.routine.md:0 "
rigAssert "the coordinator's duty is read with its own steps and the kind's, and with no advance steps mixed in" \
	"$( LC_ALL=C grep -c -x '# Steps of magic-coordinator.work-duty.routine' "$rigTmp/duty.text" ):$( LC_ALL=C grep -c -e '# Steps of magic-team.advance.routine' -e 'of magic-coordinator.advance.routine' "$rigTmp/duty.text" || : )" "1:0"
rigAssert "the team's duty routine is read with none of them" "$( LC_ALL=C grep -c -e 'advance-reconcile-sessions' -e 'of magic-team.advance.routine' "$rigTmp/team.text" || : )" 0

echo "-- 2. the advance routine starts by hand only --"
rigAssert "runs-at: none" "$( LC_ALL=C grep -c -x 'runs-at: none' "$rigAdvance" )" 1

echo "-- 3. the validator --"
rigAssert "the coordinator's duty routine, the advance routine and the team's duty routine: no row" "[$( rigValidate "$rigDuty" )][$( rigValidate "$rigAdvance" )][$( rigValidate "$rigTeamDuty" )]" "[][][]"
rigBad(){ ## a replacement for the includes line, or "" and a replacement for the wait-sources line -- the rows for a copy of the duty routine
	local badFile="$rigSkills/rig-member/rig-member.bad.routine.md"
	LC_ALL=C sed -e "s/^wait-sources: .*$/wait-sources: $2\\
includes: $1/" -e 's/^executors: .*$/executors: rig-member/' -e 's/^# magic-coordinator.work-duty.routine/# rig-member.bad.routine/' "$rigDuty" > "$badFile"
	rigValidate "$badFile"
}
rigGoodIncludes="magic-team.advance.routine.md: Steps"
rigGoodWait="inbox:{{team-member}} mentions:{{team-member}} board:running"
rigAssert "a copy with good keys has no row" "[$( rigBad "$rigGoodIncludes" "$rigGoodWait" )]" "[]"
rigAssert "an includes: naming no routine is refused" "$( rigBad "magic-nonesuch.routine.md: Steps" "$rigGoodWait" | LC_ALL=C grep -c -F 'includes: magic-nonesuch.routine.md names no one routine' )" 1
rigAssert "a section that cannot be taken is refused" "$( rigBad "magic-team.advance.routine.md: Closure steps" "$rigGoodWait" | LC_ALL=C grep -c -F 'includes: Closure steps is none of' )" 1
printf -- '---\ntype: routine\nexecutors: rig-member\nmaintainers: rig-member\nrequires-session-kind: standalone\n---\n# rig-member.bare.routine — the actual procedure\n\n# Summary\n\nA rig routine.\n\n# Steps\n\n1. **work**: work.\n' > "$rigSkills/rig-member/rig-member.bare.routine.md"
rigAssert "a section the routine does not hold is refused" "$( rigBad "rig-member.bare.routine.md: Routine's local procedures" "$rigGoodWait" | LC_ALL=C grep -c -F 'has no section' )" 1
rigAssert "a wait-sources: word that is no source of the wait is refused" "$( rigBad "$rigGoodIncludes" "inbox:{{team-member}} slack:magic-team" | LC_ALL=C grep -c -F 'wait-sources: slack:magic-team is none of' )" 1

echo "-- 4. the files a routine includes --"
rigIncludePaths(){ ## file -- the names of the files the routine includes
	env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SpawnRoutine.include" ; AgentsToolsSpawnRoutineIncludePaths "$1"' rig "$1" 2> /dev/null | LC_ALL=C sed 's#^.*/##'
}
rigBad "$rigGoodIncludes" "$rigGoodWait" > /dev/null
rigAssert "the checksum of a cached text knows the file the rig copy includes, and a duty includes none" "[$( rigIncludePaths "$rigSkills/rig-member/rig-member.bad.routine.md" )][$( rigIncludePaths "$rigDuty" )]" "[magic-team.advance.routine.md][]"

echo "-- 5. the duty waits on its inbox, and the coordinator's on the board too --"
rigAssert "the team's duty: its own inbox and its tags" "$( LC_ALL=C sed -n 's/^wait-sources: //p' "$rigTeamDuty" )" "inbox:{{team-member}} tagged:{{team-member}} mentions:{{team-member}}"
rigAssert "the coordinator's: its own inbox, its tags and mentions and the six active states of the board" "$( LC_ALL=C sed -n 's/^wait-sources: //p' "$rigDuty" )" "inbox:{{team-member}} tagged:{{team-member}} mentions:{{team-member}} board:backlog board:pending board:running board:review board:blocked board:parked"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROUTINE INCLUDES CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ROUTINE_INCLUDES: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
