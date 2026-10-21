#!/usr/bin/env bash
## Behavioural check on the runs and stats store of the Dispatcher (F7.11 of the refactorings epic): DistroAgentsDispatcher.fn.sh --rebuild-stats,
## --stats-check, --run-stats, --routine-stats and --token-stats, run rather than read, in a rig: a workspace whose .local/agents holds run records
## (spawned/<session>/<run>.md) and token files (sessions/<run>/tokens). The store (.local/agents/stats: runs.index, routines.index, tokens.index) is an
## index derived from them and never a source. Held:
##   1. THE ROWS. A run row carries its member, routine, status, times, day, workspaces, the preset and the credential (its name) and its tokens (zeros where
##      the run kept none); a record with no routine is `-`; a coworking run (its session is another) is a run of its own.
##   2. THE ROUTINE IS AN ENTITY WITH RUNS ATTACHED: its runs, how many succeeded, failed and run now, when it last ran, how that run ended, and when it last
##      SUCCEEDED -- a routine failing every night still has a recent run -- its tokens and its members.
##   3. THE TOKENS by day, member, routine, preset and credential, summed by the one key asked for, within --since and --until and the other keys.
##   4. DERIVED AND REBUILDABLE: deleted, the store is rebuilt equal; --stats-check says the same, and says what differs after a hand edit of an index, or a
##      record removed (which only a rebuild drops).
##   5. UP TO DATE ON READ: a record or a token file changed after the index is read again, the rows of the others stay as they were; a new run appears.
##   6. REFUSED: a date that is none, an option it does not know, a missing --by, a routine with no run (rc 1); a read of an empty workspace is empty and ends 0.
## Offline, rig tree only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsDispatcher.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDispatcherStatsCheck )" || exit 1
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
rigWs="$rigTmp/ws" rigHome="$rigTmp/home" rigAgents="$rigTmp/ws/.local/agents" rigStats="$rigTmp/ws/.local/agents/stats"
mkdir -p "$rigWs/.local/temp" "$rigAgents/spawned" "$rigAgents/sessions" "$rigHome"
rigRun(){ ## result prefix, words... -- one call of DistroAgentsDispatcher.fn.sh; rc in rigRc
	local runOut="$1" ; shift
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" \
		bash -c 'case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; exec bash "$0" "$@"' "$rigTool" "$@" ) > "$runOut.out" 2> "$runOut.err" < /dev/null
	rigRc=$?
}
rigHas(){ ## fixed text, file -- how many lines of the file hold it
	LC_ALL=C grep -c -F -- "$1" "$2" || :
}
## A run record, in the folder of its session; and the token file of a run.
rigRecord(){ ## session, run, member, routine (or -), status, started, preset (or -), credential (or -), executing workspace
	mkdir -p "$rigAgents/spawned/$1"
	{
		printf -- '---\nsession-id: %s\nspawn-id: %s\nstart-context: spawned\nworkspace: ws-rig\nexecuting-workspace: %s\npaying-workspace: ws-rig\nowner: %s\n' "$1" "$2" "${9:-ws-rig}" "$3"
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
rigBegin=$( date +%s )

echo "-- 6. an empty workspace --"
rigRun "$rigTmp/e1" --rebuild-stats
rigRun "$rigTmp/e2" --run-stats
rigRun "$rigTmp/e3" --routine-stats
rigAssert "nothing recorded: rebuilt 0, and the readers print nothing and end 0" "$( LC_ALL=C sed -n 1p "$rigTmp/e1.out" ) | $rigRc $( LC_ALL=C grep -c . "$rigTmp/e2.out" ) $( LC_ALL=C grep -c . "$rigTmp/e3.out" )" "STATS: rebuilt 0 run(s), 0 routine(s), 0 token row(s) | 0 0 0"
rm -rf "$rigStats"

echo "-- 1. the rows --"
rigRecord run-a1 run-a1 magic-tester ra.routine.md spawn-succeeded "2026-10-18 09:00" p1 key-a ; rigTokens run-a1 100 50 10 20
rigRecord run-a2 run-a2 magic-tester ra.routine.md spawn-failed "2026-10-19 09:00" p1 key-a ; rigTokens run-a2 10 0 0 5
rigRecord run-a3 run-a3 magic-tester ra.routine.md spawn-failed "2026-10-20 09:00" p1 key-a ; rigTokens run-a3 1 2 3 4
rigRecord run-b1 run-b1 magic-coordinator rb.routine.md spawn-succeeded "2026-10-20 10:00" p2 key-b ; rigTokens run-b1 1000 900 100 200
rigRecord run-x1 run-x1 keeper-x - spawn-started "2026-10-20 11:00" - -
rigRecord cow-1 run-c1 keeper-x ra.routine.md spawn-succeeded "2026-10-20 12:00" p2 key-a ws-other ; rigTokens run-c1 5 5 5 5
rigRun "$rigTmp/b1" --rebuild-stats
rigAssert "rebuilt: six runs, three routines (the one with none as -), the token rows" "$rigRc $( LC_ALL=C sed -n 1p "$rigTmp/b1.out" )" "0 STATS: rebuilt 6 run(s), 3 routine(s), 6 token row(s)"
rigAssert "the three files stand under stats/, each under its header line, and nothing else is left there" "$( ls "$rigStats" | LC_ALL=C tr '\n' ' ' ) $( LC_ALL=C sed -n 1p "$rigStats/runs.index" ) | $( LC_ALL=C sed -n 1p "$rigStats/routines.index" ) | $( LC_ALL=C sed -n 1p "$rigStats/tokens.index" )" "routines.index runs.index tokens.index  myx.distro stats runs 1 | myx.distro stats routines 1 | myx.distro stats tokens 1"
rigRun "$rigTmp/r1" --run-stats
rigAssert "a run row: member, routine, status, the times, the day, the workspaces, the preset, the credential's name, the tokens, the exit code" "$( LC_ALL=C grep '^run	run-a1	' "$rigTmp/r1.out" | LC_ALL=C cut -f2- )" "$(printf 'run-a1\trun-a1\tmagic-tester\tra.routine.md\tspawn-succeeded\t2026-10-18 09:00 +0300\t2026-10-18 09:00 +0300\t2026-10-18\tws-rig\tws-rig\tws-rig\tp1\tkey-a\t100\t50\t10\t20\t0')"
rigAssert "the rows are oldest first; a run with no tokens kept has zeros, one with no routine, preset or credential has -; a coworking run is a run of its own with the workspace it executed in" "$( LC_ALL=C cut -f2 "$rigTmp/r1.out" | LC_ALL=C tr '\n' ' ' ) | $( LC_ALL=C grep '^run	run-x1	' "$rigTmp/r1.out" | LC_ALL=C cut -f5,6,13,14,15,16,17,18,19 | LC_ALL=C tr '\t' ' ' ) | $( LC_ALL=C grep '^run	run-c1	' "$rigTmp/r1.out" | LC_ALL=C cut -f3,11 | LC_ALL=C tr '\t' ' ' )" "run-a1 run-a2 run-a3 run-b1 run-x1 run-c1  | - spawn-started - - 0 0 0 0 - | cow-1 ws-other"
rigAssert "the credential is its name and no value is read from anywhere: the column holds only what the record's credential: line says" "$( LC_ALL=C cut -f14 "$rigTmp/r1.out" | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' ' )" "- key-a key-b "

rigRun "$rigTmp/h1" --run-history
rigRun "$rigTmp/h2" --run-history --member magic-tester --limit 2
rigRun "$rigTmp/h3" --run-history --routine ra.routine.md --since 2026-10-19
rigAssert "the history view: the same rows, newest first; --limit keeps the newest; --member, --routine and --since filter" "$( LC_ALL=C cut -f2 "$rigTmp/h1.out" | LC_ALL=C tr '\n' ' ' )| $( LC_ALL=C cut -f2 "$rigTmp/h2.out" | LC_ALL=C tr '\n' ' ' )| $( LC_ALL=C cut -f2 "$rigTmp/h3.out" | LC_ALL=C tr '\n' ' ' )" "run-c1 run-x1 run-b1 run-a3 run-a2 run-a1 | run-a3 run-a2 | run-c1 run-a3 run-a2 "
rigRun "$rigTmp/h4" --run-history --limit 0
rigRun "$rigTmp/h5" --run-history --limit many
rigAssert "a limit that is not a whole number above 0: refused" "$( rigHas 'a whole number above 0: 0' "$rigTmp/h4.err" ) $( rigHas 'a whole number above 0: many' "$rigTmp/h5.err" )" "1 1"

echo "-- 2. the routine is an entity --"
rigRun "$rigTmp/o1" --routine-stats ra.routine.md
rigAssert "ra: four runs, two succeeded, two failed; it last ran at noon of the 20th and that run succeeded, which is also when it last succeeded" "$( LC_ALL=C cut -f2-14 "$rigTmp/o1.out" | LC_ALL=C tr '\t' ' ' )" "ra.routine.md 4 2 2 0 2026-10-20 12:00 spawn-succeeded 2026-10-20 12:00 116 57 18 34 magic-tester,keeper-x"
rigRecord cow-1 run-c1 keeper-x ra.routine.md spawn-failed "2026-10-20 12:00" p2 key-a ws-other
rigRun "$rigTmp/o2" --routine-stats ra.routine.md
rigAssert "a routine failing every night still has a recent run: it last ran on the 20th, and last succeeded on the 18th" "$( LC_ALL=C cut -f7,8,9 "$rigTmp/o2.out" | LC_ALL=C tr '\t' ' ' )" "2026-10-20 12:00 spawn-failed 2026-10-18 09:00"
rigRun "$rigTmp/o3" --routine-stats
rigAssert "every routine, by name; the runs with none are under -, and one still running counts as running" "$( LC_ALL=C cut -f2,3,4,5,6 "$rigTmp/o3.out" | LC_ALL=C tr '\t' ' ' | LC_ALL=C tr '\n' '|' )" "- 1 0 0 1|ra.routine.md 4 1 3 0|rb.routine.md 1 1 0 0|"
rigRun "$rigTmp/o4" --routine-stats nothing.routine.md
rigAssert "a routine with no run: rc 1, nothing on stdout, said" "$rigRc $( LC_ALL=C grep -c . "$rigTmp/o4.out" ) $( rigHas 'no run of the routine nothing.routine.md is recorded' "$rigTmp/o4.err" )" "1 0 1"

echo "-- 3. the tokens --"
rigTok(){ ## result prefix, words... -- the rows as `key runs in cr cw out`
	rigRun "$1" --token-stats "${@:2}"
	LC_ALL=C cut -f2- "$1.out" | LC_ALL=C tr '\t' ' ' | LC_ALL=C tr '\n' '|'
}
rigAssert "by day" "$( rigTok "$rigTmp/t1" --by day )" "2026-10-18 1 100 50 10 20|2026-10-19 1 10 0 0 5|2026-10-20 4 1006 907 108 209|"
rigAssert "by member, by routine" "$( rigTok "$rigTmp/t2" --by member ) $( rigTok "$rigTmp/t3" --by routine )" "keeper-x 2 5 5 5 5|magic-coordinator 1 1000 900 100 200|magic-tester 3 111 52 13 29| - 1 0 0 0 0|ra.routine.md 4 116 57 18 34|rb.routine.md 1 1000 900 100 200|"
rigAssert "by preset, by credential: the runs with none under -" "$( rigTok "$rigTmp/t4" --by preset ) $( rigTok "$rigTmp/t5" --by credential )" "- 1 0 0 0 0|p1 3 111 52 13 29|p2 2 1005 905 105 205| - 1 0 0 0 0|key-a 4 116 57 18 34|key-b 1 1000 900 100 200|"
rigAssert "within --since and --until, and the other keys" "$( rigTok "$rigTmp/t6" --by member --since 2026-10-19 --until 2026-10-19 ) $( rigTok "$rigTmp/t7" --by day --member magic-tester --routine ra.routine.md --preset p1 --credential key-a ) $( rigTok "$rigTmp/t8" --by routine --since 2026-10-20 )" "magic-tester 1 10 0 0 5| 2026-10-18 1 100 50 10 20|2026-10-19 1 10 0 0 5|2026-10-20 1 1 2 3 4| - 1 0 0 0 0|ra.routine.md 2 6 7 8 9|rb.routine.md 1 1000 900 100 200|"

echo "-- 5. up to date on read --"
sleep 1
cp "$rigStats/runs.index" "$rigTmp/runs.before"
rigRecord run-a3 run-a3 magic-tester ra.routine.md spawn-succeeded "2026-10-20 09:00" p1 key-a
rigRun "$rigTmp/u1" --routine-stats ra.routine.md
rigAssert "a record changed after the index: read again on the next read -- ra last succeeded on the 20th now" "$( LC_ALL=C cut -f4,5,9 "$rigTmp/u1.out" | LC_ALL=C tr '\t' ' ' )" "2 2 2026-10-20 09:00"
sleep 1
rigTokens run-b1 2000 900 100 200
rigRun "$rigTmp/u2" --token-stats --by member
rigAssert "a token file changed: read again; the rows of the other runs are as they were" "$( LC_ALL=C grep '^tokens	magic-coordinator	' "$rigTmp/u2.out" | LC_ALL=C cut -f2-7 | LC_ALL=C tr '\t' ' ' ) | $( LC_ALL=C diff "$rigTmp/runs.before" "$rigStats/runs.index" | LC_ALL=C grep -c '^[<>]' )" "magic-coordinator 1 2000 900 100 200 | 4"
sleep 1
rigRecord run-n1 run-n1 keeper-y rc.routine.md spawn-succeeded "2026-10-21 08:00" p3 key-c ; rigTokens run-n1 7 8 9 10
rigRun "$rigTmp/u3" --routine-stats rc.routine.md
rigAssert "a new run appears on the next read" "$( LC_ALL=C cut -f2-5 "$rigTmp/u3.out" | LC_ALL=C tr '\t' ' ' ) $( LC_ALL=C sed -n 2,100p "$rigStats/runs.index" | LC_ALL=C grep -c . )" "rc.routine.md 1 1 0 7"

echo "-- 4. derived and rebuildable --"
rigRun "$rigTmp/c1" --stats-check
rigAssert "the store, up to date, is what a rebuild gives: same" "$rigRc $( LC_ALL=C cat "$rigTmp/c1.out" )" "0 STATS-CHECK: same (7 run(s))"
cp -R "$rigStats" "$rigTmp/stats.kept"
rm -rf "$rigStats"
rigRun "$rigTmp/c2" --rebuild-stats
rigAssert "deleted and rebuilt from the run records: every index is equal to what it was (the free test)" "$( for rigI in runs routines tokens ; do cmp -s "$rigStats/$rigI.index" "$rigTmp/stats.kept/$rigI.index" && printf 'same ' || printf 'DIFF ' ; done)" "same same same "
LC_ALL=C awk -F'\t' -v OFS='\t' '$1 == "run-a1" { $14 = 999 } { print }' "$rigStats/runs.index" > "$rigTmp/runs.edited" && cp "$rigTmp/runs.edited" "$rigStats/runs.index"
rigRun "$rigTmp/c3" --stats-check
rigAssert "a hand edit of an index: rc 1, the file named, the rows that differ shown" "$rigRc $( rigHas 'STATS-CHECK: runs.index differs from the rebuild' "$rigTmp/c3.out" ) $( LC_ALL=C grep -c '^< run-a1' "$rigTmp/c3.out" )" "1 1 1"
rigRun "$rigTmp/c4" --rebuild-stats
rm -f "$rigAgents/spawned/run-n1/run-n1.spawn.md"
sleep 1
rigRun "$rigTmp/c5" --routine-stats rc.routine.md
rigAssert "a record removed is dropped only by a rebuild: the next read still shows its row" "$rigRc $( LC_ALL=C cut -f3 "$rigTmp/c5.out" )" "0 1"
rigRun "$rigTmp/c6" --stats-check
rigAssert "and the check says the store holds a run no record has" "$rigRc $( rigHas 'STATS-CHECK: runs.index differs' "$rigTmp/c6.out" )" "1 1"
rigRun "$rigTmp/c7" --rebuild-stats
rigRun "$rigTmp/c8" --routine-stats rc.routine.md
rigAssert "the rebuild drops it" "$rigRc $( LC_ALL=C grep -c . "$rigTmp/c8.out" )" "1 0"

echo "-- 6. what is refused --"
rigRun "$rigTmp/x1" --run-stats --since 20261020
rigRun "$rigTmp/x2" --token-stats --by nothing
rigRun "$rigTmp/x3" --token-stats
rigRun "$rigTmp/x4" --token-stats --by day --soon
rigRun "$rigTmp/x5" --rebuild-stats now
rigRun "$rigTmp/x6" --run-stats --member
rigAssert "a date that is none, a key that is none, no key, an option it does not know, a word after --rebuild-stats, an option with no value: each refused with its reason" "$( rigHas 'a date is YYYY-MM-DD: 20261020' "$rigTmp/x1.err" ) $( rigHas '--by is day, member, routine, preset or credential: nothing' "$rigTmp/x2.err" ) $( rigHas '--by is day, member, routine, preset or credential: <nothing>' "$rigTmp/x3.err" ) $( rigHas 'unknown option: --soon' "$rigTmp/x4.err" ) $( rigHas 'takes no option: now' "$rigTmp/x5.err" ) $( rigHas '--member takes a value' "$rigTmp/x6.err" )" "1 1 1 1 1 1"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ DISPATCHER STATS CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'DISPATCHER_STATS: OK (%d assertions, offline, rig tree only, %d seconds)\n' "$rigPasses" "$(( $( date +%s ) - rigBegin ))"
