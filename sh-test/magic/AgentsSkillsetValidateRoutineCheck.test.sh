#!/usr/bin/env bash
## Behavioural check on the routine validator's operation (F7.6 of the refactorings epic, and the rejection F6.7
## requires): `DistroAgentsTesting.fn.sh --skillset-validate-routine <routine-file|--from-stdin>` checks frontmatter
## and required headers and reports what is missing or wrong; `DistroAgentsTools.fn.sh
## --tester-skillset-validate-routine` is its stub. The validator rejects, not warns, a routine missing
## requires-session-kind: (F6.7), the one mandatory key of F6.1. `tracking-item:`, `operations:` and `start-context:`
## are flat, optional keys, a key left out meaning `any`; there is no `requires:` line.
## Held:
##   1. a routine complete by the contract (F5.4's keys and sections) passes, exit 0, through the stub and through the
##      Testing file alike
##   2. it rejects, exit non-zero, naming what is missing: no requires-session-kind:; no `# Opening steps`; no
##      `# Closure steps`; and a routine missing the key and a heading has both named
##   2b. the optional keys: a routine that leaves out tracking-item:, operations: and start-context: is complete
##   2c. input-scan-def: one repeatable line for each scan, `<scan> [--option value ...]`, or `none` alone; a line naming no scan,
##       an option with no value, a macro of no common option, none beside a scan, or the old operation form is refused
##   2d. runs-at: `<days> <HH:MM>` or `none`, runs-after: one routine; others refused
##   3. --from-stdin gives the same verdicts for the same text
##   4. magic-tester's session may call it, as the console may
##   5. it is read-only: the routine file is unchanged
## Red before F7.6: neither operation exists (every case fails).
## Offline: rig files only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigScripts="$rigOrigin/myx/myx.distro-agents/sh-scripts"
rigTool="$rigScripts/DistroAgentsTools.fn.sh"
rigTesting="$rigScripts/DistroAgentsTesting.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the dispatcher is not at the origin this workspace resolves: $rigTool"
rigTmp="$( mkdir -p "${MMDAPP:?⛔ ERROR: MMDAPP is not set}/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsSkillsetValidateRoutineCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/agents" "$rigTmp/home" "$rigTmp/skills/magic-tester" "$rigTmp/routines"
printf 'rig\n' > "$rigTmp/skills/magic-tester/magic-tester.basic.md" ; printf 'rig\n' > "$rigTmp/skills/magic-tester/magic-tester.armed.md"
## Reconciled for F7.5: a `runs-after:` must name a routine that exists (epic 1751), so the routine section 2d names stands in the rig's skillset.
mkdir -p "$rigTmp/skills/magic-coordinator" ; printf 'rig\n' > "$rigTmp/skills/magic-coordinator/magic-coordinator.basic.md"
printf -- '---\ntype: routine\n---\n# Steps\n' > "$rigTmp/skills/magic-coordinator/magic-coordinator.daily.routine.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## A routine complete by the contract, less what the arguments name: the key (`requires-session-kind`) and headings
## (`opening`, `closure`). It carries none of the optional keys.
rigRoutine(){ ## name, what to leave out...
	local routineName="$1" routineOut="" routineKind=yes routineOpen=yes routineClose=yes
	shift
	for routineOut in "$@" ; do
		case "$routineOut" in
			requires-session-kind) routineKind="" ;;
			opening) routineOpen="" ;;
			closure) routineClose="" ;;
		esac
	done
	{
		printf -- '---\ntype: routine\nexecutors: magic-tester\nmaintainers: magic-tester\ninvitees: magic-coordinator\n'
		[ -z "$routineKind" ] || printf 'requires-session-kind: coworking\n'
		printf -- '---\n# magic-tester.%s.routine — the actual procedure\n\n# Summary\n\nA rig routine.\n\n' "$routineName"
		[ -z "$routineOpen" ] || printf '# Opening steps\n\n1. **open**: open.\n\n'
		printf '# Steps\n\n1. **work**: work.\n\n'
		[ -z "$routineClose" ] || printf '# Closure steps\n\n1. **close**: close.\n\n'
		printf "# Routine's local procedures\n\nNone.\n\n# Routine's local rules\n\nNone.\n\n# Routine-specific tooling\n\nNone.\n\n# Maintainer Notes\n\nNone.\n"
	} > "$rigTmp/routines/magic-tester.$routineName.routine.md"
}
rigCaller=()
rigRun(){ ## stub|testing, then the words after the operation -- one call; rc in rigRc, both streams in $rigTmp/said
	local runWhich="$1" ; shift
	local runScript="$rigTool" runOp="--tester-skillset-validate-routine"
	[ "$runWhich" = stub ] || { runScript="$rigTesting" ; runOp="--skillset-validate-routine" ; }
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigTmp/home" USER=rigacct PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" ${rigCaller[@]+"${rigCaller[@]}"} bash "$runScript" "$runOp" "$@" ) > "$rigTmp/said" 2>&1 < "${rigStdin:-/dev/null}" || rigRc=$?
}
rigVerdict(){ ## fixed strings the answer must name... -- `0` where it passed, else `refused` and each string named or not
	local verdictText verdictName
	if [ "$rigRc" -eq 0 ] ; then printf '0' ; return ; fi
	verdictText="refused"
	for verdictName in "$@" ; do
		if LC_ALL=C grep -q -F -- "$verdictName" "$rigTmp/said" ; then verdictText="$verdictText $verdictName" ; else verdictText="$verdictText (not-named:$verdictName)" ; fi
	done
	printf '%s' "$verdictText"
}
rigRoutine complete
rigRoutine no-kind requires-session-kind
rigRoutine no-opening opening
rigRoutine no-closure closure
rigRoutine no-two requires-session-kind opening
rigFile(){ printf '%s' "$rigTmp/routines/magic-tester.$1.routine.md" ; }

echo "-- 1. a complete routine passes --"
rigRun stub "$( rigFile complete )"
rigAssert "through the stub, exit 0"                            "$rigRc" "0"
rigRun testing "$( rigFile complete )"
rigAssert "through the Testing file, exit 0"                    "$rigRc" "0"

echo "-- 2. it rejects, naming what is missing --"
rigRun stub "$( rigFile no-kind )"
rigAssert "no requires-session-kind:"                           "$( rigVerdict requires-session-kind )" "refused requires-session-kind"
rigRun stub "$( rigFile no-opening )"
rigAssert "no # Opening steps"                                  "$( rigVerdict 'Opening steps' )" "refused Opening steps"
rigRun stub "$( rigFile no-closure )"
rigAssert "no # Closure steps"                                  "$( rigVerdict 'Closure steps' )" "refused Closure steps"
rigRun stub "$( rigFile no-two )"
rigAssert "the key and a heading missing: both named"           "$( rigVerdict requires-session-kind 'Opening steps' )" "refused requires-session-kind Opening steps"

echo "-- 2b. the optional keys may be left out --"
rigAssert "the complete routine carries none of tracking-item:, operations:, start-context:, nor requires:, and passes" \
	"$( LC_ALL=C grep -c -E '^(tracking-item|operations|start-context|requires):' "$( rigFile complete )" ):$( rigRun stub "$( rigFile complete )" ; printf '%s' "$rigRc" )" "0:0"

## The complete routine with extra frontmatter lines (a line a key, `\n` between them), as a routine of the given name.
rigWith(){ ## name, frontmatter lines
	EXTRA="$2" LC_ALL=C awk '{ print } $0 == "requires-session-kind: coworking" { printf "%s\n", ENVIRON["EXTRA"] }' "$( rigFile complete )" > "$rigTmp/routines/magic-tester.$1.routine.md"
}
rigWithRun(){ ## name, frontmatter lines -- one stub run of it
	rigWith "$1" "$2" ; rigRun stub "$( rigFile "$1" )"
}

echo "-- 2c. input-scan-def: one repeatable line a scan, or none alone --"
rigWithRun scan-one 'input-scan-def: grooming'
rigAssert "a scan of the tooling passes"                        "$rigRc" "0"
rigWithRun scan-opt 'input-scan-def: sweep --comms-since-utime {{session-id}}'
rigAssert "an option with a macro value passes"                 "$rigRc" "0"
rigWithRun scan-two 'input-scan-def: grooming
input-scan-def: sweep'
rigAssert "several lines pass"                                  "$rigRc" "0"
rigWithRun scan-none 'input-scan-def: none'
rigAssert "none alone passes"                                   "$rigRc" "0"
rigWithRun scan-unknown 'input-scan-def: nosuch-scan'
rigAssert "a scan the tooling has not: refused, the line named" "$( rigVerdict input-scan-def 'nosuch-scan' )" "refused input-scan-def nosuch-scan"
rigWithRun scan-novalue 'input-scan-def: grooming --option'
rigAssert "an option with no value: refused"                    "$( rigVerdict input-scan-def 'has no value' )" "refused input-scan-def has no value"
rigWithRun scan-macro 'input-scan-def: grooming --option {{nope}}'
rigAssert "a macro of no common option: refused, named"         "$( rigVerdict input-scan-def 'none of team-member' )" "refused input-scan-def none of team-member"
rigWithRun scan-mixed 'input-scan-def: none
input-scan-def: grooming'
rigAssert "none beside a scan: refused"                         "$( rigVerdict input-scan-def 'stands alone' )" "refused input-scan-def stands alone"
rigWithRun scan-advance 'input-scan-def: advance'
rigAssert "the advance scan, retired (F7.12), is no scan the line may name: refused" "$( rigVerdict input-scan-def "'advance' does not start with a scan of the tooling" )" "refused input-scan-def 'advance' does not start with a scan of the tooling"
rigWithRun scan-old 'input-scan-def: --intern-op-advance-input-scan {{team-member}}'
rigAssert "the old operation form: refused"                     "$( rigVerdict input-scan-def )" "refused input-scan-def"
rigWithRun scan-wait 'input-scan-def: work-duty --session-id {{session-id}} --wait 300'
rigAssert "--wait <seconds>, the spawner's own option beside the scan's: passes" "$rigRc" "0"
rigWithRun scan-wait-only 'input-scan-def: grooming --wait 5'
rigAssert "--wait alone on a scan passes"                       "$rigRc" "0"
rigWithRun scan-wait-novalue 'input-scan-def: grooming --wait'
rigAssert "--wait with no value: refused"                       "$( rigVerdict input-scan-def 'has no value' )" "refused input-scan-def has no value"
for rigWaitBad in 0 -1 abc 05 1.5 ; do
	rigWithRun scan-wait-bad "input-scan-def: grooming --wait $rigWaitBad"
	rigAssert "--wait $rigWaitBad is not whole seconds, 1 or more: refused" "$( rigVerdict input-scan-def '--wait takes whole seconds' )" "refused input-scan-def --wait takes whole seconds"
done
rigWithRun scan-wait-twice 'input-scan-def: grooming --wait 5 --wait 6'
rigAssert "--wait twice on a line: refused"                     "$( rigVerdict input-scan-def 'given twice' )" "refused input-scan-def given twice"

echo "-- 2d. runs-at: <days> <HH:MM> or none; runs-after: one routine --"
for rigAt in 'workdays 09:30' 'weekend 00:00' 'daily 23:59' 'mon,thu 18:00' 'none' ; do
	rigWithRun runs-ok "runs-at: $rigAt"
	rigAssert "runs-at: $rigAt passes"                              "$rigRc" "0"
done
for rigAt in 'workdays 25:00' 'sometimes 10:00' 'workdays' 'mon,xyz 10:00' 'daily 9:30' 'daily 09:30 extra' ; do
	rigWithRun runs-bad "runs-at: $rigAt"
	rigAssert "runs-at: $rigAt: refused, named"                     "$( rigVerdict runs-at )" "refused runs-at"
done
rigWithRun after-ok 'runs-after: magic-coordinator.daily.routine'
rigAssert "runs-after: one routine passes"                      "$rigRc" "0"
rigWithRun after-bad 'runs-after: magic-coordinator.daily.routine, magic-team.grooming.routine'
rigAssert "runs-after: two: refused, named"                     "$( rigVerdict runs-after )" "refused runs-after"

echo "-- 2e. cache-prefix: armed or routine (F10.7) --"
for rigCache in armed routine ; do
	rigWithRun cache-ok "cache-prefix: $rigCache"
	rigAssert "cache-prefix: $rigCache passes"                      "$rigRc" "0"
done
rigWithRun cache-bad 'cache-prefix: always'
rigAssert "cache-prefix: always: refused, named"                "$( rigVerdict cache-prefix 'is not armed or routine' )" "refused cache-prefix is not armed or routine"
rigAssert "a routine that leaves it out passes (armed)"         "$( rigRun stub "$( rigFile complete )" ; printf '%s' "$rigRc" )" "0"

echo "-- 3. --from-stdin gives the same verdicts --"
rigStdin="$( rigFile complete )" rigRun stub --from-stdin
rigAssert "the complete routine on standard input passes"       "$rigRc" "0"
rigStdin="$( rigFile no-kind )" rigRun stub --from-stdin
rigAssert "one missing requires-session-kind: on standard input is refused, named" "$( rigVerdict requires-session-kind )" "refused requires-session-kind"

echo "-- 4. magic-tester's session may call it --"
rigCaller=( MDAT_SPAWN_AGENT=magic-tester MDAT_SPAWN_SESSION_ID=rig-run-tester )
rigRun stub "$( rigFile complete )"
rigCaller=()
rigAssert "the complete routine passes for magic-tester"        "$rigRc" "0"

echo "-- 5. read-only --"
( cd "$rigTmp/routines" && cksum ./* ) > "$rigTmp/before"
rigRun stub "$( rigFile no-two )"
rigRun testing "$( rigFile complete )"
( cd "$rigTmp/routines" && cksum ./* ) > "$rigTmp/after"
rigAssert "the routine files are unchanged, and the operation ran" "$( cmp -s "$rigTmp/before" "$rigTmp/after" && echo unchanged || echo changed ) $rigRc" "unchanged 0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SKILLSET VALIDATE ROUTINE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SKILLSET_VALIDATE_ROUTINE: OK (%d assertions, offline)\n' "$rigPassCount"
