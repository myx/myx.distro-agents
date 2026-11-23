#!/usr/bin/env bash
## Behavioural check on a yield by a run that went on detached (sh-test/AgentsRunTests.sh, NOBODY SITS ON A WAIT and A RUN GIVES ITS
## LANES UP), on a fixture machine of its own with one lane. A detached run keeps its own lines in runner.log in its run folder, beside
## the logs of its checks. Held:
##   1. the detached run, at the boundary between its two checks with a run behind it and no lane free, gives its lane up, and the
##      run behind it begins its check within a minute
##   2. it takes its lane back and runs its second check, and every run ends whole, in the order: its first check, the run behind, its second
##   3. nothing is left in the line
## Red before the fix: the yield waited for every *.log of the run folder to get a receipt, runner.log never does, so the run kept its
## lane and its mark for ever and the run behind it never began.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigRunner="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-test/AgentsRunTests.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigRunner" ] || rigRefuse "the runner is not at the origin this workspace resolves: $rigRunner"
[ -f "${MYXROOT:-/usr/local/share/myx.common}/bin/lib/parallel.Common" ] || rigRefuse "myx.common lib/parallel, which the runner runs its tests with, is not at ${MYXROOT:-/usr/local/share/myx.common}"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRunTestsYieldDetachedCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
trap 'rigProcSignalWithChildren KILL $rigStarted ; rm -rf -- "$rigTmp"' EXIT
rigHome="$rigTmp/home" ; rigWs="$rigTmp/ws"
rigQueue="$rigHome/.agents/magic-team/suite-queue"
rigLanes="$rigHome/.agents/magic-team/suite-lanes"
mkdir -p "$rigWs/.local/temp" "$rigLanes" || rigRefuse "the rig could not be made: $rigTmp"
printf '1\n' > "$rigLanes/max" && printf '1\n' > "$rigLanes/count" || rigRefuse "the rig's lane count could not be set"
: > "$rigTmp/log"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigRoot(){ ## session -- the source root of that session's copy of the package
	printf '%s\n' "$rigWs/.local/temp/rig-scratch-$1/source"
}
## Each copy: the runner under test, its keepers, and its tiny tests, each logging its begin and end; held (RIG_HOLD), a test ends only
## once the rig lets it. One test is named by its session, each of two <session>.<n>.
rigPackage(){ ## session, how many tests
	local packageTests packageIndex ; packageTests="$( rigRoot "$1" )/myx/myx.distro-agents/sh-test"
	mkdir -p "$packageTests/check-fixtures" || rigRefuse "the copy could not be made: $1"
	cp "$rigRunner" "$packageTests/AgentsRunTests.sh" && cp "$( dirname "$rigRunner" )/check-fixtures"/runner-*.py "$packageTests/check-fixtures"/ || rigRefuse "the runner could not be copied: $1"
	## THE RUNNER IS A ROUTER: its parts travel with it, or the rig copy finds none and runs nothing.
	mkdir -p "$packageTests/runner" && cp "$( dirname "$rigRunner" )"/runner/*.sh "$packageTests/runner"/ || rigRefuse "the runner parts could not be copied into the rig"
	cat > "$packageTests/RigTiny.test.sh" <<'RIGTINY'
#!/usr/bin/env bash
rigTinyId="${0##*/RigTiny}" ; rigTinyId="${rigTinyId%.test.sh}"
RIG_SUITE="$RIG_SUITE${rigTinyId:+.$rigTinyId}"
printf 'BEGIN %s\n' "$RIG_SUITE" >> "$RIG_SHARED/log"
rigHeldFor=600
while [ -n "${RIG_HOLD:-}" ] && [ ! -e "$RIG_SHARED/let.$RIG_SUITE" ] && [ "$rigHeldFor" -gt 0 ] ; do sleep 0.2 ; rigHeldFor=$(( rigHeldFor - 1 )) ; done
printf 'END %s\n' "$RIG_SUITE" >> "$RIG_SHARED/log"
echo "RIG_TINY: OK"
RIGTINY
	[ "$2" = 1 ] && return 0
	for (( packageIndex = 1 ; packageIndex <= $2 ; packageIndex++ )) ; do cp "$packageTests/RigTiny.test.sh" "$packageTests/RigTiny$packageIndex.test.sh" ; done
	rm -f "$packageTests/RigTiny.test.sh"
}
rigPackage a 1 ; rigPackage b 2 ; rigPackage c 1
rigRun(){ ## session, held (non-empty|empty), runner args... -- that session's runner from its own copy, in the background; its output in <session>.out, its pid in rigLast
	( cd "$rigWs" && exec env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$( rigRoot "$1" )" MYXROOT="${MYXROOT:-}" RIG_SHARED="$rigTmp" RIG_SUITE="$1" RIG_HOLD="$2" \
		MDAT_SPAWN_SESSION_ID="rig-session-$1" \
		bash "$( rigRoot "$1" )/myx/myx.distro-agents/sh-test/AgentsRunTests.sh" "${@:3}" ) > "$rigTmp/$1.out" 2>&1 &
	rigLast=$!
	rigStarted="$rigStarted $rigLast" ; rigProcNote "$rigLast"
}
rigUntil(){ ## fixed text, file, tenths of a second -- waits for a line of the file to hold the text; rc 1 when it never does
	local untilLeft="$3"
	while ! LC_ALL=C grep -q -F -- "$1" "$2" 2> /dev/null ; do
		[ "$untilLeft" -gt 0 ] || return 1
		sleep 0.2 ; untilLeft=$(( untilLeft - 2 ))
	done
}
rigLet(){ : > "$rigTmp/let.$1" ; }

## The lane held by a; b queues with no --wait, so it goes on detached and keeps runner.log in its run folder.
rigRun a yes --wait ; rigPidA="$rigLast"
rigUntil 'BEGIN a' "$rigTmp/log" 1200 || rigRefuse "the run holding the lane never began its test: $( cat "$rigTmp/a.out" )"
rigRun b yes ; rigPidB="$rigLast"
rigUntil 'queued and not waited on' "$rigTmp/b.out" 1200 || rigRefuse "the run with no --wait never went on detached: $( cat "$rigTmp/b.out" )"
rigChild="$( LC_ALL=C sed -n 's/^.* as pid \([0-9]*\), on ticket .*/\1/p' "$rigTmp/b.out" )"
rigFolder="$( LC_ALL=C sed -n 's|^# AgentsRunTests.sh: read it later: \(.*\)/progress.txt as its checks end, .*|\1|p' "$rigTmp/b.out" )"
[ -n "$rigChild" ] && [ -n "$rigFolder" ] || rigRefuse "the detached run named no pid or no run folder: $( cat "$rigTmp/b.out" )"
rigStarted="$rigStarted $rigChild" ; rigProcNote "$rigChild"
## b takes the lane, begins its first check, and c, given --wait, stands behind it with no lane free.
rigLet a
rigUntil 'BEGIN b.1' "$rigTmp/log" 1200 || rigRefuse "the detached run never began its first check"
[ -f "$rigFolder/runner.log" ] || rigRefuse "the detached run keeps no runner.log in its run folder, so this is not the case measured"
rigRun c "" --wait ; rigPidC="$rigLast"
rigUntil 'waits its turn behind' "$rigTmp/c.out" 1200 || rigRefuse "the run behind never said it waits"

## 1. The boundary: b's first check let go, and the run behind it begins within a minute.
rigLet b.1
rigUntil 'BEGIN c' "$rigTmp/log" 600 ; rigBeganC=$?
rigAssert "the detached run gave its lane up at its boundary, and the run behind it began its check within a minute" "$rigBeganC $( LC_ALL=C grep -c -F -- 'gave its lane(s)' "$rigFolder/runner.log" || : )" "0 1"
## A run behind that never began is the deadlock itself: nothing after it would end, so the check ends here, and its trap ends what it started.
[ "$rigBeganC" = 0 ] || { printf 'RUN_TESTS_YIELD_DETACHED: FAIL (%d of %d assertions) -- the run behind it never began\n' "$rigFails" "$(( rigPasses + rigFails ))" ; exit 1 ; }

## 2. b takes its lane back and runs its second check; every run ends whole, in that order.
rigLet b.2
wait "$rigPidA" 2> /dev/null || :
rigRcC=0 ; wait "$rigPidC" 2> /dev/null || rigRcC=$?
rigUntil 'b.2' "$rigTmp/log" 600 || :
rigUntil 'TOTAL' "$rigFolder/summary.txt" 600 || :
rigAssert "the run behind it passed, and the detached run took its lane back and passed both its checks" "$rigRcC $( LC_ALL=C grep -c '^PASS ' "$rigFolder/summary.txt" 2> /dev/null || : )" "0 2"
rigAssert "in the order: its first check, the run behind it, its second check" "$( LC_ALL=C grep -e '^BEGIN [bc]' -e '^END [bc]' "$rigTmp/log" | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )" "BEGIN b.1 END b.1 BEGIN c END c BEGIN b.2 END b.2"

## 3. Nothing left in the line once the detached run has ended.
rigLeft=300
while [ "$rigLeft" -gt 0 ] && kill -0 "$rigChild" 2> /dev/null ; do sleep 0.2 ; rigLeft=$(( rigLeft - 1 )) ; done
rigAssert "the line is empty once every run has ended" "$( ls "$rigQueue" 2> /dev/null | LC_ALL=C grep -c '\.ticket$' || : )" "0"

[ "$rigFails" = 0 ] || { printf 'RUN_TESTS_YIELD_DETACHED: FAIL (%d of %d assertions)\n' "$rigFails" "$(( rigPasses + rigFails ))" ; exit 1 ; }
printf 'RUN_TESTS_YIELD_DETACHED: OK (%d assertions, offline, rig machine only)\n' "$rigPasses"
