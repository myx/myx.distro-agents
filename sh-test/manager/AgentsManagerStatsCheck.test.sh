#!/usr/bin/env bash
## Behavioural check on --manager-stats-tokens and --manager-stats-routines, the console's own readers of the runs and stats store of the Dispatcher (F7.11), which the
## views of the tokens and of the routines read, run rather than read, in a rig: a workspace whose .local/agents holds run records and token files. They have no logic of
## their own. Held: each prints, byte for byte, what the Dispatcher's `--token-stats` and `--routine-stats` print for the same arguments in the same workspace, the
## tokens by each key (day, member, routine, preset, credential) and within --since, and the routines, one or every one; the status is the Dispatcher's, so a key that
## is none and a routine with no run end 1 and say so; and each has its syntax line in the help, once, and its entry. Offline, rig tree only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTools="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigDispatcher="$rigPackage/sh-scripts/DistroAgentsDispatcher.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTools" ] && [ -f "$rigDispatcher" ] || rigRefuse "the tools are not at the origin this workspace resolves: $rigPackage/sh-scripts"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerStatsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigWs="$rigTmp/ws" rigHome="$rigTmp/home" rigAgents="$rigTmp/ws/.local/agents"
mkdir -p "$rigWs/.local/temp" "$rigWs/.local/.agents" "$rigAgents/spawned" "$rigAgents/sessions" "$rigHome"
rigRun(){ ## script, result prefix, words... -- one call from the rig workspace; rc in rigRc
	local runScript="$1" runOut="$2" ; shift 2
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_WORKSPACE_MODE=team-rig \
		bash "$runScript" "$@" ) > "$runOut.out" 2> "$runOut.err" < /dev/null
	rigRc=$?
}
rigRecord(){ ## session, run, member, routine (or -), status, started, preset (or -), credential (or -)
	mkdir -p "$rigAgents/spawned/$1"
	{
		printf -- '---\nsession-id: %s\nspawn-id: %s\nstart-context: spawned\nworkspace: ws-rig\nexecuting-workspace: ws-rig\npaying-workspace: ws-rig\nowner: %s\n' "$1" "$2" "$3"
		[ "$4" = "-" ] || printf 'routine: %s\n' "$4"
		printf 'status: %s\nstarted-at: %s +0300\n' "$5" "$6"
		[ "$7" = "-" ] || printf 'preset: %s\n' "$7"
		[ "$8" = "-" ] || printf 'credential: %s\n' "$8"
		[ "$5" = "spawn-started" ] || printf 'resolved-at: %s +0300\nexit-code: 0\n' "$6"
		printf -- '---\n\n# Spawn session: %s\n' "$2"
	} > "$rigAgents/spawned/$1/$2.spawn.md"
}
rigTokens(){ ## run, in, cache-read, cache-write, out
	mkdir -p "$rigAgents/sessions/$1" ; printf '%s %s %s %s\n' "$2" "$3" "$4" "$5" > "$rigAgents/sessions/$1/tokens"
}
rigRecord run-a1 run-a1 magic-tester ra.routine.md spawn-succeeded "2026-10-18 09:00" p1 key-a ; rigTokens run-a1 100 50 10 20
rigRecord run-a2 run-a2 magic-tester ra.routine.md spawn-failed "2026-10-19 09:00" p1 key-a ; rigTokens run-a2 10 0 0 5
rigRecord run-b1 run-b1 magic-coordinator rb.routine.md spawn-succeeded "2026-10-20 10:00" p2 key-b ; rigTokens run-b1 1000 900 100 200
rigRecord run-x1 run-x1 keeper-x - spawn-started "2026-10-20 11:00" - -
rigSame(){ ## label, the words after the operation of each -- the output and the status of the manager operation and of the Dispatcher's, compared
	local sameManager="$1" sameDispatcher="$2" ; shift 2
	rigRun "$rigTools" "$rigTmp/m" "$sameManager" "$@"
	local managerRc="$rigRc"
	rigRun "$rigDispatcher" "$rigTmp/d" "$sameDispatcher" "$@"
	printf '%s %s %s %s' "$managerRc" "$rigRc" "$( cmp -s "$rigTmp/m.out" "$rigTmp/d.out" && echo same || echo DIFFER )" "$( LC_ALL=C grep -c . "$rigTmp/m.out" || : )"
}

echo "-- the tokens, by each key --"
for rigBy in day member routine preset credential ; do
	rigAssert "tokens by $rigBy: the Dispatcher's rows, byte for byte, status 0" "$( rigSame --manager-stats-tokens --token-stats --by $rigBy )" "0 0 same $( rigRun "$rigDispatcher" "$rigTmp/d" --token-stats --by $rigBy ; LC_ALL=C grep -c . "$rigTmp/d.out" )"
done
rigAssert "within --since and for one member, as the Dispatcher gives it" "$( rigSame --manager-stats-tokens --token-stats --by day --since 2026-10-19 --member magic-coordinator )" "0 0 same 1"
rigRun "$rigTools" "$rigTmp/t" --manager-stats-tokens --by member
rigAssert "a row is what it was told to be: tokens, the key, the runs and the four kinds of tokens, TAB-separated" "$( LC_ALL=C grep '^tokens	magic-tester	' "$rigTmp/t.out" | LC_ALL=C tr '\t' ' ' )" "tokens magic-tester 2 110 50 10 25"
rigAssert "--average and --share go to the Dispatcher as they come, and its rows come back byte for byte" "$( rigSame --manager-stats-tokens --token-stats --by member --average --share )" "0 0 same 3"
rigRun "$rigTools" "$rigTmp/t" --manager-stats-tokens --by member --average --share
rigAssert "the average and the shares are the tooling's: tester has 2 runs, 110 in, so 55 an average; the total of the averages is 55+1000+0, so 5 and 6 percent" "$( LC_ALL=C grep '^tokens	magic-tester	' "$rigTmp/t.out" | LC_ALL=C tr '\t' ' ' )" "tokens magic-tester 2 55 25 5 12 5 6"

echo "-- the routines --"
rigAssert "every routine: the Dispatcher's rows, byte for byte" "$( rigSame --manager-stats-routines --routine-stats )" "0 0 same 3"
rigAssert "one routine: the same, its one row" "$( rigSame --manager-stats-routines --routine-stats ra.routine.md )" "0 0 same 1"

echo "-- what the Dispatcher refuses, it refuses here, with its status --"
rigAssert "a key that is none ends 1, nothing on stdout" "$( rigSame --manager-stats-tokens --token-stats --by nothing )" "1 1 same 0"
rigAssert "a routine with no run ends 1, nothing on stdout" "$( rigSame --manager-stats-routines --routine-stats nothing.routine.md )" "1 1 same 0"
rigRun "$rigTools" "$rigTmp/n" --manager-stats-tokens --by nothing
rigAssert "and the error line says what was wrong" "$( LC_ALL=C grep -c -F -- '--by is day, weekday, hour, member, routine, preset, credential or session' "$rigTmp/n.err" || : )" "1"

echo "-- the help pair --"
rigHelpInclude="$rigPackage/sh-lib/help/Help.DistroAgentsTools.include"
rigHelpMd="$rigPackage/sh-lib/help/Help.DistroAgentsTools.help.md"
for rigOp in --manager-stats-tokens --manager-stats-routines ; do
	rigAssert "$rigOp has its syntax echo once, its syntax line once, and its entry once" "$( LC_ALL=C grep -c -F -- "syntax: DistroAgentsTools.fn.sh $rigOp" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -F -- "syntax: DistroAgentsTools.fn.sh $rigOp" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -E "^		$rigOp( |\$)" "$rigHelpMd" || : )" "1 1 1"
done
rigRun "$rigTools" "$rigTmp/h" --help-syntax
rigAssert "--help-syntax prints both lines" "$( LC_ALL=C grep -c -F -e 'syntax: DistroAgentsTools.fn.sh --manager-stats-tokens' -e 'syntax: DistroAgentsTools.fn.sh --manager-stats-routines' "$rigTmp/h.err" || : )" "2"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MANAGER STATS CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_STATS: OK (%d assertions, offline)\n' "$rigPasses"
