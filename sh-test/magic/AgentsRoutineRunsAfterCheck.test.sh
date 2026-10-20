#!/usr/bin/env bash
## Behavioural check on the `runs-after:` rules of the routine validator (F7.5 of the refactorings epic, epic 1749-1751): two failure
## modes of the autorun declaration are default-open if left out, and both are decidable from the files, so the validator rejects them at
## save time. Held, run and not read, through the one validator (--intern-doc-validate routine), by the stub of the Testing file:
##   1. A `runs-after:` naming a routine that exists, once, passes: a chain of three, and a routine that follows one that declares none.
##   2. It names no routine: refused, a row of the rule runs-after saying so. As is a name that matches more than one routine file.
##   3. A cycle is refused: a routine that follows itself, two that follow each other (a row in each, naming the cycle), and a routine
##      that follows a cycle it is not itself part of.
##   4. The same verdicts for a routine given on standard input (--from-stdin), which has no name of its own to cycle through.
##   5. It is read-only: no routine file is changed.
## A routine is named as `--routine` names one: a file name or part of one, exactly one file, found in the skillset root.
## Offline: rig files only.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigTesting="$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTesting.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTesting" ] || rigRefuse "the Testing file is not at the origin this workspace resolves: $rigTesting"
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRoutineRunsAfterCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigSkills="$rigTmp/skills" rigDir="$rigTmp/skills/rig-member"
mkdir -p "$rigWs/.local/agents" "$rigTmp/home" "$rigDir"
printf 'rig\n' > "$rigDir/rig-member.basic.md" ; printf 'rig\n' > "$rigDir/rig-member.armed.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigRoutine(){ ## name, the runs-after value ("" for none) -- a routine complete by the contract, in the skillset root
	{
		printf -- '---\ntype: routine\nexecutors: rig-member\nmaintainers: rig-member\nrequires-session-kind: standalone\nruns-at: workdays 09:00\n'
		[ -z "${2:-}" ] || printf 'runs-after: %s\n' "$2"
		printf -- '---\n# rig-member.%s.routine — the actual procedure\n\n# Summary\n\nA rig routine.\n\n# Opening steps\n\n1. **open**: open.\n\n# Steps\n\n1. **work**: work.\n\n# Closure steps\n\n1. **close**: close.\n\n' "$1"
		printf "# Routine's local procedures\n\nNone.\n\n# Routine's local rules\n\nNone.\n\n# Routine-specific tooling\n\nNone.\n\n# Maintainer Notes\n\nNone.\n"
	} > "$rigDir/rig-member.$1.routine.md"
}
rigRc=0 rigSaid=""
rigRun(){ ## the words after the operation -- one call of the stub of the Testing file; rc in rigRc, both streams in rigSaid
	rigRc=0
	rigSaid="$( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigSkills" bash "$rigTesting" --skillset-validate-routine "$@" 2>&1 < "${rigStdin:-/dev/null}" )" || rigRc=$?
}
rigRows(){ ## rule -- the rows of that rule the last call printed
	printf '%s\n' "$rigSaid" | LC_ALL=C grep -c -F -- ": $1: " || :
}
rigFile(){ printf '%s' "$rigDir/rig-member.$1.routine.md" ; }

rigRoutine alpha ""
rigRoutine beta "rig-member.alpha"
rigRoutine gamma "rig-member.beta"
rigRoutine orphan "rig-member.nosuch"
rigRoutine twin-one ""
rigRoutine twin-two ""
rigRoutine ambig "rig-member.twin"
rigRoutine self "rig-member.self"
rigRoutine loop-a "rig-member.loop-b"
rigRoutine loop-b "rig-member.loop-a"
rigRoutine tail "rig-member.loop-a"
rigBefore="$( cd "$rigDir" && cat ./*.routine.md | cksum )"

echo "-- 1. a routine named once passes --"
rigRun "$( rigFile beta )"
rigAssert "beta follows alpha: rc 0, no row of the rule" "$rigRc:$( rigRows runs-after )" "0:0"
rigRun "$( rigFile gamma )"
rigAssert "gamma follows beta, which follows alpha: rc 0" "$rigRc:$( rigRows runs-after )" "0:0"
rigRun "$( rigFile alpha )"
rigAssert "alpha follows none: rc 0" "$rigRc" "0"

echo "-- 2. a name that is no routine, or is several --"
rigRun "$( rigFile orphan )"
rigAssert "a routine that names no routine: refused, a row of runs-after, said so" "$( [ "$rigRc" != 0 ] && echo refused ):$( rigRows runs-after ):$( printf '%s\n' "$rigSaid" | LC_ALL=C grep -c -F 'runs-after: rig-member.nosuch names no routine' )" "refused:1:1"
rigRun "$( rigFile ambig )"
rigAssert "a name that matches two routine files: refused, said so" "$( [ "$rigRc" != 0 ] && echo refused ):$( rigRows runs-after ):$( printf '%s\n' "$rigSaid" | LC_ALL=C grep -c -F 'runs-after: rig-member.twin names more than one routine' )" "refused:1:1"

echo "-- 3. cycles --"
rigRun "$( rigFile self )"
rigAssert "a routine that follows itself: refused, a cycle" "$( [ "$rigRc" != 0 ] && echo refused ):$( rigRows runs-after ):$( printf '%s\n' "$rigSaid" | LC_ALL=C grep -c -F -e 'a cycle' )" "refused:1:1"
rigRun "$( rigFile loop-a )"
rigAssert "two that follow each other: a row in the first, naming the cycle" "$( [ "$rigRc" != 0 ] && echo refused ):$( rigRows runs-after ):$( printf '%s\n' "$rigSaid" | LC_ALL=C grep -c -F 'a cycle: rig-member.loop-a.routine.md -> rig-member.loop-b.routine.md -> rig-member.loop-a.routine.md' )" "refused:1:1"
rigRun "$( rigFile loop-b )"
rigAssert "and in the second" "$( [ "$rigRc" != 0 ] && echo refused ):$( rigRows runs-after ):$( printf '%s\n' "$rigSaid" | LC_ALL=C grep -c -F 'a cycle: rig-member.loop-b.routine.md -> rig-member.loop-a.routine.md -> rig-member.loop-b.routine.md' )" "refused:1:1"
rigRun "$( rigFile tail )"
rigAssert "a routine that follows a cycle it is not part of never runs either: refused, a cycle" "$( [ "$rigRc" != 0 ] && echo refused ):$( rigRows runs-after ):$( printf '%s\n' "$rigSaid" | LC_ALL=C grep -c -F -e 'a cycle' )" "refused:1:1"

echo "-- 4. standard input --"
rigStdin="$rigTmp/stdin.md"
cp "$( rigFile beta )" "$rigStdin"
rigRun --from-stdin
rigAssert "a routine on stdin that follows alpha: rc 0" "$rigRc:$( rigRows runs-after )" "0:0"
cp "$( rigFile orphan )" "$rigStdin"
rigRun --from-stdin
rigAssert "on stdin, a name that is no routine: refused" "$( [ "$rigRc" != 0 ] && echo refused ):$( rigRows runs-after )" "refused:1"
cp "$( rigFile tail )" "$rigStdin"
rigRun --from-stdin
rigAssert "on stdin, a routine that follows a cycle: refused" "$( [ "$rigRc" != 0 ] && echo refused ):$( rigRows runs-after )" "refused:1"
rigStdin=""

echo "-- 5. read-only --"
rigAssert "no routine file changed" "$( cd "$rigDir" && cat ./*.routine.md | cksum )" "$rigBefore"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROUTINE RUNS-AFTER CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ROUTINE_RUNS_AFTER: OK (%d assertions, offline)\n' "$rigPassCount"
