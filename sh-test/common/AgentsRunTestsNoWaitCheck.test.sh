#!/usr/bin/env bash
## Behavioural check on NOBODY SITS ON A WAIT (sh-test/AgentsRunTests.sh), run on a fixture machine of its own: a HOME whose
## suite-queue and suite-lanes are the machine's line and its one lane, a workspace, and three copies of a package with the
## runner under test and one tiny test each. Held:
##   1. a run not given --wait, behind a run that holds the only lane, returns within ten seconds with status 75, naming its
##      ticket and its run folder; the ticket stays in the line, held now by a detached run that is not the caller
##   2. the control, the other direction: the same kind of run given --wait is still waiting once the first has returned
##   3. the line keeps its order: once the lane is let go the three tests run one after another as they arrived, and the
##      detached run writes its test's receipt and its summary, PASS, into the run folder it named
##   4. nothing is left: the line is empty once every run has ended
##   5. the run left detached is handed a bound of 3600 s where its caller set none, since nobody waits on it; a nohup of the rig's notes it
## Red before the change: the run not given --wait waits as the control does, so 1 and 3's folder fail. Red before the detached bound: 5 finds none handed on.
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
rigTmp="$( rigTempDir AgentsRunTestsNoWaitCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
trap 'rigProcSignal TERM $rigStarted ; rm -rf -- "$rigTmp"' EXIT
rigHome="$rigTmp/home" ; rigWs="$rigTmp/ws"
rigQueue="$rigHome/.agents/magic-team/suite-queue"
rigLanes="$rigHome/.agents/magic-team/suite-lanes"
mkdir -p "$rigWs/.local/temp" "$rigLanes" || rigRefuse "the rig could not be made: $rigTmp"
## One lane on this rig's machine, whatever this host's pace: the count is held to the maximum.
printf '1\n' > "$rigLanes/max" && printf '1\n' > "$rigLanes/count" || rigRefuse "the rig's lane count could not be set"
: > "$rigTmp/log"
## The rig's nohup, first on every run's PATH: it notes the bound the detached run is handed, then is the real nohup.
mkdir -p "$rigTmp/bin" && cat > "$rigTmp/bin/nohup" <<'RIGNOHUP' && chmod +x "$rigTmp/bin/nohup" || rigRefuse "the rig's nohup could not be made"
#!/bin/sh
printf '%s\n' "${MDAT_SUITE_QUEUE_LIMIT-unset}" > "$RIG_SHARED/nohup.$RIG_SUITE"
PATH="${PATH#"$RIG_SHARED/bin:"}"
exec nohup "$@"
RIGNOHUP

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
## Each copy: the runner under test, its keepers, and one tiny test that logs its begin and end; held (RIG_HOLD), it ends only once the rig lets it.
for rigSession in a b c ; do
	rigTests="$( rigRoot "$rigSession" )/myx/myx.distro-agents/sh-test"
	mkdir -p "$rigTests/check-fixtures" || rigRefuse "the copy could not be made: $rigSession"
	cp "$rigRunner" "$rigTests/AgentsRunTests.sh" && cp "$( dirname "$rigRunner" )/check-fixtures"/runner-*.py "$rigTests/check-fixtures"/ || rigRefuse "the runner could not be copied: $rigSession"
	cat > "$rigTests/RigTiny.test.sh" <<'RIGTINY'
#!/usr/bin/env bash
printf 'BEGIN %s\n' "$RIG_SUITE" >> "$RIG_SHARED/log"
rigHeldFor=600
while [ -n "${RIG_HOLD:-}" ] && [ ! -e "$RIG_SHARED/let.$RIG_SUITE" ] && [ "$rigHeldFor" -gt 0 ] ; do sleep 0.2 ; rigHeldFor=$(( rigHeldFor - 1 )) ; done
printf 'END %s\n' "$RIG_SUITE" >> "$RIG_SHARED/log"
echo "RIG_TINY: OK"
RIGTINY
done
rigRun(){ ## session, held (non-empty|empty), runner args... -- that session's runner from its own copy, in the background; its output in <session>.out, its pid in rigLast
	( cd "$rigWs" && exec env -i HOME="$rigHome" PATH="$rigTmp/bin:$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$( rigRoot "$1" )" MYXROOT="${MYXROOT:-}" RIG_SHARED="$rigTmp" RIG_SUITE="$1" RIG_HOLD="$2" \
		MDAT_SPAWN_SESSION_ID="rig-session-$1" \
		bash "$( rigRoot "$1" )/myx/myx.distro-agents/sh-test/AgentsRunTests.sh" "${@:3}" ) > "$rigTmp/$1.out" 2>&1 &
	rigLast=$!
	rigStarted="$rigStarted $rigLast" ; rigProcNote "$rigLast"
}
rigUntil(){ ## fixed text, file -- waits for a line of the file to hold the text, up to four minutes; rc 1 when it never does
	local untilLeft=1200
	while ! LC_ALL=C grep -q -F -- "$1" "$2" 2> /dev/null ; do
		[ "$untilLeft" -gt 0 ] || return 1
		sleep 0.2 ; untilLeft=$(( untilLeft - 1 ))
	done
}
rigTickets(){ ## -- how many tickets stand in the line
	ls "$rigQueue" 2> /dev/null | LC_ALL=C grep -c '\.ticket$' || :
}

## 1. The only lane held by a, and b started with no --wait behind it.
rigRun a yes --wait
rigPidA="$rigLast"
rigUntil 'BEGIN a' "$rigTmp/log" || rigRefuse "the run holding the lane never began its test: $( cat "$rigTmp/a.out" )"
rigRun b "" 
rigPidB="$rigLast"
rigTries=50
while [ "$rigTries" -gt 0 ] && kill -0 "$rigPidB" 2> /dev/null ; do sleep 0.2 ; rigTries=$(( rigTries - 1 )) ; done
rigRcB="still waiting"
kill -0 "$rigPidB" 2> /dev/null || { rigRcB=0 ; wait "$rigPidB" 2> /dev/null || rigRcB=$? ; }
rigAssert "a run with no --wait behind the held lane returns within ten seconds, with status 75" "$rigRcB" "75"
rigTicketLine="$( LC_ALL=C sed -n 's/^# AgentsRunTests.sh: queued and not waited on: .* as pid \([0-9]*\), on ticket \(.*\)$/\1 \2/p' "$rigTmp/b.out" )"
rigChild="${rigTicketLine%% *}" ; rigTicket="${rigTicketLine#* }"
rigFolder="$( LC_ALL=C sed -n 's|^# AgentsRunTests.sh: read it later: \(.*\)/progress.txt as its checks end, .*|\1|p' "$rigTmp/b.out" )"
[ -z "$rigChild" ] || { rigStarted="$rigStarted $rigChild" ; rigProcNote "$rigChild" ; }
rigAssert "it names a ticket that still stands in the line, held by a run that is not the caller" \
	"$( [ -n "$rigChild" ] && [ "$rigChild" != "$rigPidB" ] && [ -f "$rigTicket" ] && LC_ALL=C grep -q -x "pid=$rigChild" "$rigTicket" && kill -0 "$rigChild" 2> /dev/null && echo held-detached || echo "${rigTicketLine:-no ticket named}" )" "held-detached"
rigAssert "it names a run folder that is there" "$( [ -n "$rigFolder" ] && [ -d "$rigFolder" ] && echo there || echo "${rigFolder:-none named}" )" "there"
rigAssert "the run left detached is handed a bound of 3600 s, its caller having set none" "$( cat "$rigTmp/nohup.b" 2> /dev/null || echo 'no detached start seen' )" "3600"

## 2. The control: c, given --wait, behind both, is still waiting when b has returned.
rigRun c "" --wait
rigPidC="$rigLast"
rigUntil 'waits its turn behind' "$rigTmp/c.out" || :
rigAssert "a run given --wait behind them is still waiting, its call not returned" "$( kill -0 "$rigPidC" 2> /dev/null && echo waiting || echo returned )" "waiting"

## 3. The lane let go: the three tests in arrival order, and b's result where it said it would be.
: > "$rigTmp/let.a"
rigUntil 'END c' "$rigTmp/log" || :
wait "$rigPidA" 2> /dev/null || :
wait "$rigPidC" 2> /dev/null || :
rigAssert "the three tests ran one after another, in the order they arrived" "$( LC_ALL=C grep -e '^BEGIN ' -e '^END ' "$rigTmp/log" | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )" "BEGIN a END a BEGIN b END b BEGIN c END c"
[ -z "$rigFolder" ] || rigUntil 'RigTiny' "$rigFolder/summary.txt" || :
rigAssert "the detached run wrote its test's receipt, rc 0, in the folder it named" "$( LC_ALL=C sed -n 's/^rc=//p' "${rigFolder:-/nonexistent}/RigTiny.receipt" 2> /dev/null )" "0"
rigAssert "and its summary there passes the test" "$( LC_ALL=C grep -c '^PASS .*RigTiny' "${rigFolder:-/nonexistent}/summary.txt" 2> /dev/null || : )" "1"

## 4. Nothing left in the line once the detached run has ended.
rigTries=300
while [ "$rigTries" -gt 0 ] && [ -n "$rigChild" ] && kill -0 "$rigChild" 2> /dev/null ; do sleep 0.2 ; rigTries=$(( rigTries - 1 )) ; done
rigAssert "the line is empty once every run has ended" "$( rigTickets )" "0"

[ "$rigFails" = 0 ] || { printf 'RUN_TESTS_NO_WAIT: FAIL (%d of %d assertions)\n' "$rigFails" "$(( rigPasses + rigFails ))" ; exit 1 ; }
printf 'RUN_TESTS_NO_WAIT: OK (%d assertions, offline, rig machine only)\n' "$rigPasses"
