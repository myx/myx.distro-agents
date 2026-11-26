#!/usr/bin/env bash
## Behavioural check on the retest queue (--retest-queue, --retest-drain, --retest-result:
## sh-lib/member/AgentsTools.RetestQueue.include), run rather than read, on a fixture machine built here: a HOME, whose
## .agents/magic-team/retest-queue is the machine's one queue, and a workspace whose own tree is a copy of the tooling
## as it stands at the origin, with three tiny tests and the test runner in place of the package's tests, and beside
## it a scratch copy with two. Held: queueing returns at once with an id and waits for no test; a drain takes
## everything that waits as one batch and runs each test once however many requests named it, so two requests naming
## one test give one run and two results; a test that fails fails every request that named it; a second drain is refused
## while one runs; a request that comes in while a batch runs ends that batch at its next test boundary where it names
## fewer tests than that batch's request has left to run, and is run in that same batch; a request naming no test is the
## widest, and any request naming tests ends it so; a drain ended by a signal leaves no runner of its batch alive, or the
## next drain ends the orphan before it starts; a wide request stopped at a boundary answers YIELDED, naming a new request that
## carries who asked, why, about which copy, where that copy and the workspace are, and returned-from naming the first;
## a run the drain did not start is no batch and stops at no boundary; a request is about one copy, the
## live tree or a scratch folder, and each copy's tests are run by that copy's own runner; a changed file that is a
## test is taken as that test, and any other file as the tests that name it -- a file no test names runs nothing
## and says so; with
## nothing waiting, --rest runs only what has not passed on that state; a request left by a drain that no longer
## exists is taken by the next; a finished request is read by its id, and kept seven days. Nothing here is told by how
## long a run takes: a test that must still be running when something else is done runs until the rig lets it end.
## Offline, a rig tree only: every call goes through one `env -i` whose child refuses to start unless MMDAPP sits
## under this rig's mktemp tree, and nothing here reaches Slack or any endpoint.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigInclude="$rigPackage/sh-lib/member/AgentsTools.RetestQueue.include"
rigHelpInclude="$rigPackage/sh-lib/help/Help.DistroAgentsTools.include"
rigHelpManual="$rigPackage/sh-lib/help/Help.DistroAgentsTools.help.md"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
[ -f "$rigPackage/sh-test/AgentsRunTests.sh" ] || rigRefuse "the test runner is not at the origin this workspace resolves: $rigPackage/sh-test/AgentsRunTests.sh"
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRetestQueueCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
trap 'rigProcSignal TERM $rigStarted ; rm -rf -- "$rigTmp"' EXIT
rigHome="$rigTmp/home" ; rigWs="$rigTmp/ws" ; rigLive="$rigWs/source"
rigQueue="$rigHome/.agents/magic-team/retest-queue"
mkdir -p "$rigHome" "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigLive/myx/myx.distro-agents" "$rigLive/myx/myx.common/os-myx.common/host/tarball/share"
: > "$rigTmp/log"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

## ---- the fixture ----
## The workspace's own tree: the tooling as it stands at the origin, copied once so that nothing done there while this
## check runs moves the state under it, and in place of the package's tests the runner and three tiny ones.
rigTake(){ ## folder below the origin, folder below the rig's tree -- that folder copied whole, links followed, .git left out
	mkdir -p "$rigLive/$2" && tar -C "$MDLT_ORIGIN/$1" --exclude .git -chf - . 2> /dev/null | tar -C "$rigLive/$2" -xf - 2> /dev/null
}
rigTake myx/myx.distro-agents/sh-lib myx/myx.distro-agents/sh-lib || rigRefuse "the tooling's sh-lib could not be copied into the rig"
rigTake myx/myx.distro-agents/sh-scripts myx/myx.distro-agents/sh-scripts || rigRefuse "the tooling's sh-scripts could not be copied into the rig"
rsync -t "$rigPackage/project.inf" "$rigLive/myx/myx.distro-agents/project.inf"
for rigSibling in myx.distro-.local myx.distro-system ; do rigTake "myx/$rigSibling" "myx/$rigSibling" || rigRefuse "the tooling's $rigSibling could not be copied into the rig" ; done
rigTake myx/myx.common/os-myx.common/host/tarball/share/myx.common myx/myx.common/os-myx.common/host/tarball/share/myx.common || rigRefuse "myx.common could not be copied into the rig"
rigTool="$rigLive/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
[ -f "$rigTool" ] && [ -f "$rigLive/myx/myx.distro-agents/sh-lib/member/AgentsTools.RetestQueue.include" ] || rigRefuse "the rig's copy of the tooling holds no retest queue, so nothing below would be measured"
rigRoot(){ ## copy -- its source root: `live` is the workspace's own tree, any other name a scratch folder of that name
	if [ "$1" = live ] ; then printf '%s\n' "$rigLive" ; else printf '%s\n' "$rigWs/.local/temp/$1/source" ; fi
}
rigTests(){ ## copy, test... -- that copy's tests: the runner under test and the tiny tests named. Each says in the shared log when it begins and ends and which copy it ran in; it ends only once the rig lets it where the rig holds it (hold.<test>), and fails where the rig says so (fail.<test>)
	local testsDir testsName ; testsDir="$( rigRoot "$1" )/myx/myx.distro-agents/sh-test" ; shift
	rm -rf "$testsDir" ; mkdir -p "$testsDir"
	rsync -t "$rigPackage/sh-test/AgentsRunTests.sh" "$testsDir/AgentsRunTests.sh"
	mkdir -p "$testsDir/check-fixtures" && rsync -t "$rigPackage/sh-test/check-fixtures"/runner-*.py "$testsDir/check-fixtures"/
	mkdir -p "$testsDir/runner" && rsync -t "$rigPackage/sh-test/runner"/*.sh "$testsDir/runner"/
	for testsName in "$@" ; do
		cat > "$testsDir/$testsName.test.sh" <<'RIGTINY'
#!/usr/bin/env bash
rigTinyName="${0##*/}" ; rigTinyName="${rigTinyName%.test.sh}"
case "$MDLT_ORIGIN" in */.local/temp/*) rigTinyCopy="${MDLT_ORIGIN##*/.local/temp/}" ; rigTinyCopy="${rigTinyCopy%%/*}" ;; *) rigTinyCopy=live ;; esac
printf 'BEGIN %s %s\n' "$rigTinyCopy" "$rigTinyName" >> "$RIG_SHARED/log"
printf '%s\n' "${MDAT_SUITE_QUEUE_LIMIT-}" >> "$RIG_SHARED/limits.log"
rigHeldFor=600
while [ -e "$RIG_SHARED/hold.$rigTinyName" ] && [ ! -e "$RIG_SHARED/let.$rigTinyName" ] && [ "$rigHeldFor" -gt 0 ] ; do sleep 0.2 ; rigHeldFor=$(( rigHeldFor - 1 )) ; done
printf 'END %s %s\n' "$rigTinyCopy" "$rigTinyName" >> "$RIG_SHARED/log"
[ ! -e "$RIG_SHARED/fail.$rigTinyName" ] || { echo "RIG_TINY: FAILED" ; exit 1 ; }
echo "RIG_TINY: OK"
RIGTINY
	done
}
rigTests live RigOne RigTwo RigThree
rigTests rig-scratch-a RigOne RigTwo
## What a test exercises, it names: the covering relation a request for a changed file is expanded by (W2).
printf '# it exercises %s\n' 'sh-lib/wait/AgentsTools.MemberWait.include' >> "$rigLive/myx/myx.distro-agents/sh-test/RigThree.test.sh"

rigCall(){ ## result prefix, operation, its arguments... -- one call of the tooling from the workspace, in the background; <prefix>.out .err, its pid in rigLast
	local callOut="$1" ; shift
	case "$rigWs" in "$rigTmp"/*) ;; *) rigRefuse "the workspace is outside this rig's own tree: $rigWs" ;; esac
	( cd "$rigWs" && exec env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$rigLive" MDLT_OPTION="--run-from-path $rigLive" RIG_TMP="$rigTmp" RIG_SHARED="$rigTmp" ${rigAs:+MDAT_SPAWN_AGENT="$rigAs"} ${rigLane:+MDAT_RETEST_LANE_WAIT="$rigLane"} \
		bash -c 'case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; exec bash "$0" "$@"' "$rigTool" "$@" ) > "$callOut.out" 2> "$callOut.err" < /dev/null &
	rigLast=$!
	rigStarted="$rigStarted $rigLast" ; rigProcNote "$rigLast"
}
rigEnd(){ ## pid -- waits for that call, its rc in rigRc
	rigRc=0 ; wait "$1" 2> /dev/null || rigRc=$?
}
rigOp(){ ## result prefix, operation, its arguments... -- one call from start to end, its rc in rigRc
	rigCall "$@" ; rigEnd "$rigLast"
}
rigAsk(){ ## result prefix, arguments of the queue operation... -- one request; its id in rigId, the rc in rigRc
	local askOut="$1" ; shift
	rigOp "$askOut" --retest-queue "$@"
	rigId="$( LC_ALL=C sed -n 1p "$askOut.out" )"
}
rigUntil(){ ## fixed text, file, seconds (default 240) -- waits for a line of the file to hold the text, however long a busy host takes, up to that many seconds; rc 1 when it never does
	local untilSeconds="${3:-240}" untilLeft
	case "$untilSeconds" in ''|*[!0123456789]*) untilSeconds=240 ;; esac
	untilLeft=$(( untilSeconds * 5 ))
	while ! LC_ALL=C grep -q -F -- "$1" "$2" 2> /dev/null ; do
		[ "$untilLeft" -gt 0 ] || return 1
		sleep 0.2 ; untilLeft=$(( untilLeft - 1 ))
	done
}
rigBegins(){ ## test, copy (default: any) -- how many times that test has really begun, by the shared log
	LC_ALL=C grep -c -E "^BEGIN ${2:-[a-z-]+} $1\$" "$rigTmp/log" || :
}
rigBegun(){ ## -- every test that has begun, with its copy, in the order they began, on one line
	LC_ALL=C sed -n 's/^BEGIN //p' "$rigTmp/log" | LC_ALL=C tr ' ' ':' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//'
}
rigHolds(){ ## folder of the queue -- how many requests or results stand in it
	ls "$rigQueue/$1" 2> /dev/null | LC_ALL=C grep -c -e '\.request$' -e '\.result$' || :
}
rigLine(){ ## result prefix, request id -- the line a drain printed for that request, its id put as <id>
	LC_ALL=C grep -F -- "RETEST $2 " "$1.out" | LC_ALL=C sed "s/$2/<id>/" | LC_ALL=C tr '\n' '|' | LC_ALL=C sed 's/|$//'
}
rigStands(){ ## request id -- where the result operation says that request stands: the word after its id
	rigOp "$rigTmp/stands" --retest-result "$1"
	LC_ALL=C sed -n "1s/^RETEST $1 \([A-Z]*\) .*/\1/p" "$rigTmp/stands.out"
}
rigFresh(){ ## -- an empty queue, no pass on record, an empty log, nothing held or failing
	rm -rf "$rigHome/.agents" ; : > "$rigTmp/log" ; rm -f "$rigTmp"/hold.* "$rigTmp"/let.* "$rigTmp"/fail.* ; rigAs="" rigLane=""
}
rigRunners(){ ## -- how many test runners of this rig are alive now: those whose command line names this rig's own tree, so no other run's is counted, and never this probe itself
	ps -A -o args= 2> /dev/null | LC_ALL=C grep -F -- "$rigLive/myx/myx.distro-agents/sh-test" | LC_ALL=C grep -c -E '[A]gentsRun(Tests|Execute)\.sh' || :
}
rigRunnerPids(){ ## -- the pids of those runners now, to note before ending them
	ps -A -o pid=,args= 2> /dev/null | LC_ALL=C grep -F -- "$rigLive/myx/myx.distro-agents/sh-test" | LC_ALL=C grep -E '[A]gentsRun(Tests|Execute)\.sh' | LC_ALL=C awk '{ print $1 }'
}
rigRunFolder(){ ## result prefix -- the run folder the drain named for its batch, once its runner has started
	LC_ALL=C sed -n 's/^# AgentsRunTests\.sh: .* run folder: //p' "$1.err" 2> /dev/null | LC_ALL=C tail -n 1
}
rigBatchOrder(){ ## result prefix -- the tests of that batch, in the order the batch will run them, on one line
	LC_ALL=C awk '{ print $1 }' "$( rigRunFolder "$1" )/tests.list" 2> /dev/null | LC_ALL=C tr '\n' ' '
}
rigRunnersClear(){ ## -- ends every runner of this rig a bespoke section left behind, so the count a section reads is its own; every one is noted before it is signalled
	local clearPids clearLeft=20
	clearPids="$( rigRunnerPids )"
	[ -z "$clearPids" ] || rigProcNote $clearPids
	[ -z "$clearPids" ] || rigProcSignal TERM $clearPids
	while [ "$clearLeft" -gt 0 ] && [ "$( rigRunners )" -gt 0 ] ; do sleep 1 ; clearLeft=$(( clearLeft - 1 )) ; done
}
rigAs="" rigLane=""

echo "-- 1. queueing returns at once with an id, and waits for no test --"
rigFresh
rigAsk "$rigTmp/q1" --by rig-builder --why 'the rig changed the wait tool' RigOne
rigAssert "the request is taken: rc 0, and one line on stdout, its id" "$rigRc $( LC_ALL=C grep -c . "$rigTmp/q1.out" ) $( printf '%s' "$rigId" | LC_ALL=C grep -c -E '^retest-[0-9]{8}T[0-9]{6}Z-[0-9a-f-]+$' )" "0 1 1"
rigAssert "no test was run for it, and it waits in the queue, which is the machine's, under HOME and in no workspace" "$( LC_ALL=C grep -c . "$rigTmp/log" ) $( rigHolds waiting ) $( find "$rigWs" -name 'retest-queue' 2> /dev/null | LC_ALL=C grep -c . )" "0 1 0"
rigAssert "the request says who asks, why, which copy it is about and where that copy is, and the test" "$( LC_ALL=C grep -e '^by: ' -e '^why: ' -e '^about: ' -e '^origin: ' -e '^test: ' -e '^file: ' "$rigQueue/waiting/$rigId.request" | LC_ALL=C tr '\n' '|' )" "by: rig-builder|why: the rig changed the wait tool|about: live|origin: $rigLive|test: RigOne|"
rigAssert "asked by its id, it is said to wait" "$( rigStands "$rigId" )" "WAITING"
rigAs="magic-developer"
rigAsk "$rigTmp/q1b" --why 'a member asks' RigTwo
rigAssert "a session that acts as a member need not say who asks: it is that member" "$rigRc $( LC_ALL=C sed -n 's/^by: //p' "$rigQueue/waiting/$rigId.request" 2> /dev/null )" "0 magic-developer"
rigAs=""
rigWaiting="$( rigHolds waiting )"
rigAsk "$rigTmp/q1c" --why 'nobody says who' RigOne
rigAssert "with nobody to name, a request without --by is refused, and nothing is queued" "$rigRc $( LC_ALL=C grep -c -F -- '--by is required' "$rigTmp/q1c.err" ) $( rigHolds waiting )" "1 1 $rigWaiting"
rigAsk "$rigTmp/q1d" --by rig-builder RigOne
rigAssert "one without --why is refused" "$rigRc $( LC_ALL=C grep -c -F -- '--why is required' "$rigTmp/q1d.err" ) $( rigHolds waiting )" "1 1 $rigWaiting"
rigAsk "$rigTmp/q1e" --by rig-builder --why 'names nothing'
rigAssert "one that names nothing to retest is refused" "$rigRc $( LC_ALL=C grep -c -F -- 'nothing to retest is named' "$rigTmp/q1e.err" ) $( rigHolds waiting )" "1 1 $rigWaiting"
rigAsk "$rigTmp/q1f" --by rig-builder --why 'a test that is not there' RigNone
rigAssert "one naming a test the copy does not hold is refused, saying so" "$rigRc $( LC_ALL=C grep -c -F -- 'no test of that name in the copy the request is about: RigNone' "$rigTmp/q1f.err" ) $( rigHolds waiting )" "1 1 $rigWaiting"
rigOp "$rigTmp/r1" --retest-result retest-00000000T000000Z-none
rigAssert "an id no request has is said to be unknown, exit 1" "$rigRc $( LC_ALL=C grep -c '^RETEST retest-00000000T000000Z-none UNKNOWN ' "$rigTmp/r1.out" )" "1 1"

echo "-- 2. two requests naming the same test give one run and two results --"
rigFresh
rigAsk "$rigTmp/q2a" --by rig-first --why 'the first change' RigOne ; rigIdA="$rigId"
rigAsk "$rigTmp/q2b" --by rig-second --why 'the second change' RigOne RigTwo ; rigIdB="$rigId"
rigOp "$rigTmp/d2" --retest-drain
rigAssert "the drain takes both as one batch and runs each test once" "$rigRc [$( rigBegun )]" "0 [live:RigOne live:RigTwo]"
rigAssert "it prints one line for each request: who asked, about which copy, what passed, and why it was asked" "$( LC_ALL=C grep -c '^RETEST ' "$rigTmp/d2.out" ) $( rigLine "$rigTmp/d2" "$rigIdA" ) $( rigLine "$rigTmp/d2" "$rigIdB" )" "2 RETEST <id> PASS -- asked by rig-first about live: 1 passed -- the first change RETEST <id> PASS -- asked by rig-second about live: 2 passed -- the second change"
rigAssert "nothing waits and nothing is left in the batch, both are finished, and the drain's lock is given back" "$( rigHolds waiting ) $( rigHolds running ) $( rigHolds done ) $( [ -e "$rigQueue/drain.lock" ] && printf held || printf free )" "0 0 2 free"
rigOp "$rigTmp/r2" --retest-result "$rigIdB"
rigAssert "who asked reads the outcome by the id: the same line, then each test and the folder that holds the logs" "$rigRc $( LC_ALL=C sed -n 1p "$rigTmp/r2.out" | LC_ALL=C sed "s/$rigIdB/<id>/" ) [$( LC_ALL=C grep -e '^  passed ' -e '^  failed ' "$rigTmp/r2.out" | LC_ALL=C tr '\n' '|' )] $( [ -f "$( LC_ALL=C sed -n 's/^  run-folder //p' "$rigTmp/r2.out" )/RigTwo.log" ] && printf log-there || printf no-log )" "0 RETEST <id> PASS -- asked by rig-second about live: 2 passed -- the second change [  passed RigOne|  passed RigTwo|] log-there"
rigOp "$rigTmp/d2b" --retest-drain
rigAssert "a drain with nothing waiting runs nothing and says so" "$rigRc $( LC_ALL=C grep -c '^RETEST ' "$rigTmp/d2b.out" ) $( LC_ALL=C grep -c -F -- '# retest: nothing waits' "$rigTmp/d2b.err" ) [$( rigBegun )]" "0 0 1 [live:RigOne live:RigTwo]"

echo "-- 3. a failing test fails every request that named it --"
rigFresh
: > "$rigTmp/fail.RigOne"
rigAsk "$rigTmp/q3a" --by rig-first --why 'only the failing one' RigOne ; rigIdA="$rigId"
rigAsk "$rigTmp/q3b" --by rig-second --why 'the failing one and another' RigOne RigTwo ; rigIdB="$rigId"
rigAsk "$rigTmp/q3c" --by rig-third --why 'only the other' RigTwo ; rigIdC="$rigId"
rigOp "$rigTmp/d3" --retest-drain
rigAssert "each test is run once for the three requests" "$rigRc [$( rigBegun )]" "0 [live:RigOne live:RigTwo]"
rigAssert "the request that named only the failing test fails" "$( rigLine "$rigTmp/d3" "$rigIdA" )" "RETEST <id> FAIL -- asked by rig-first about live: 0 passed, FAILED: RigOne -- only the failing one"
rigAssert "the one that named it with another fails too, and says what passed" "$( rigLine "$rigTmp/d3" "$rigIdB" )" "RETEST <id> FAIL -- asked by rig-second about live: 1 passed, FAILED: RigOne -- the failing one and another"
rigAssert "accepted sibling: the one that did not name it passes" "$( rigLine "$rigTmp/d3" "$rigIdC" )" "RETEST <id> PASS -- asked by rig-third about live: 1 passed -- only the other"
rigOp "$rigTmp/r3" --retest-result "$rigIdA"
rigAssert "the outcome names the failed test with its rc and its log, and the log is there" "$( LC_ALL=C sed -n 's/^  failed \(RigOne rc=1\) log: .*/\1/p' "$rigTmp/r3.out" ) $( [ -f "$( LC_ALL=C sed -n 's/^  failed RigOne rc=1 log: //p' "$rigTmp/r3.out" )" ] && printf log-there || printf no-log )" "RigOne rc=1 log-there"

echo "-- 4. a request that comes in while a batch runs ends it at its next test boundary, and is run in that same batch --"
## REWRITTEN, with its reason: this section held that such a request is in the next batch, and that is the behaviour the
## yield changes. The ruled behaviour is that a batch ends at its next test boundary once a request names fewer tests than
## that batch's request has left to run, and that the waiting request is run in that same batch. So the narrow one never
## waits longer than one test of the wide one. The batch is read from the log and from the queue folders only, never from
## how a drain signals the runner it started.
rigFresh
: > "$rigTmp/hold.RigOne" ; : > "$rigTmp/hold.RigTwo" ; : > "$rigTmp/hold.RigThree"
rigAsk "$rigTmp/q4a" --by rig-first --why 'in the first batch' RigOne RigTwo RigThree ; rigIdA="$rigId"
rigCall "$rigTmp/d4" --retest-drain ; rigPidD=$rigLast
rigUntil 'BEGIN live ' "$rigTmp/log" || rigRefuse "the batch's test never began, so nothing below would be measured"
rigBatch="$( rigBatchOrder "$rigTmp/d4" )"
[ -n "$rigBatch" ] || rigRefuse "the batch named no test list, so nothing below would be measured"
rigFirst="$( printf '%s' "$rigBatch" | LC_ALL=C awk '{ print $1 }' )"
## The narrow request names the test this batch would run LAST, so that a batch which went on would run another test before it.
rigNarrow="$( printf '%s' "$rigBatch" | LC_ALL=C awk '{ print $NF }' )"
[ "$rigNarrow" != "$rigFirst" ] || rigRefuse "the batch names one test alone, so a narrow request could not be told from it"
rigAsk "$rigTmp/q4b" --by rig-second --why 'asked while the batch ran, and narrower' "$rigNarrow" ; rigIdB="$rigId"
rigAssert "queueing waits for no test: the request is taken while the batch's test is still running" "$rigRc $( printf '%s' "$rigIdB" | LC_ALL=C grep -c '^retest-' ) $( LC_ALL=C grep -c '^END ' "$rigTmp/log" )" "0 1 0"
rigAssert "the first is said to be in the batch being run, the second to wait" "$( rigStands "$rigIdA" ) $( rigStands "$rigIdB" )" "RUNNING WAITING"
rigOp "$rigTmp/d4x" --retest-drain
rigAssert "a second drain is refused while one runs, saying so, and takes nothing" "$rigRc $( LC_ALL=C grep -c -F -- 'a batch is being run already' "$rigTmp/d4x.err" ) $( rigBegins "$rigFirst" )" "1 1 1"
## The boundary: every test is held, so the second test to begin stands where it is and the log says which one it is,
## however busy the host is; then everything is let end, so that the drain can finish.
: > "$rigTmp/let.$rigFirst"
rigSecond=""
for rigWaitLeft in $( seq 1 120 ) ; do
	rigSecond="$( LC_ALL=C sed -n 's/^BEGIN live //p' "$rigTmp/log" | LC_ALL=C sed -n 2p )"
	[ -z "$rigSecond" ] || break
	sleep 0.5
done
rm -f "$rigTmp"/hold.* "$rigTmp"/let.*
for rigWaitLeft in $( seq 1 300 ) ; do
	kill -0 "$rigPidD" 2> /dev/null || break
	sleep 1
done
rigEnd "$rigPidD"
rigAssert "the batch ends at that boundary and takes the waiting request in: the test that runs next is the narrow request's, and that request is answered by the batch that was already running" \
	"$( printf '%s' "$rigSecond" )|$( rigLine "$rigTmp/d4" "$rigIdB" | LC_ALL=C cut -d' ' -f1-3 )" \
	"$rigNarrow|RETEST <id> PASS"
rm -f "$rigTmp"/hold.* "$rigTmp"/let.*

echo "-- 5. a request is about one copy, and each copy's tests are run by that copy's own runner --"
rigFresh
rigAsk "$rigTmp/q5a" --by rig-first --why 'about the scratch copy' --about rig-scratch-a RigOne ; rigIdA="$rigId"
rigAsk "$rigTmp/q5b" --by rig-second --why 'about the live tree' RigOne RigThree ; rigIdB="$rigId"
rigAssert "the request says which copy: the scratch folder, and where its source root is" "$( LC_ALL=C grep -e '^about: ' -e '^origin: ' "$rigQueue/waiting/$rigIdA.request" | LC_ALL=C tr '\n' '|' )" "about: rig-scratch-a|origin: $( rigRoot rig-scratch-a )|"
rigOp "$rigTmp/d5" --retest-drain
rigAssert "one batch, and the test both named is run once in each copy" "$rigRc [$( rigBegun )]" "0 [live:RigOne live:RigThree rig-scratch-a:RigOne]"
rigAssert "each request is answered for its own copy" "$( rigLine "$rigTmp/d5" "$rigIdA" ) $( rigLine "$rigTmp/d5" "$rigIdB" )" "RETEST <id> PASS -- asked by rig-first about rig-scratch-a: 1 passed -- about the scratch copy RETEST <id> PASS -- asked by rig-second about live: 2 passed -- about the live tree"
rigAsk "$rigTmp/q5c" --by rig-first --why 'a test only the live tree holds' --about rig-scratch-a RigThree
rigAssert "a test the copy asked about does not hold is refused, though the live tree holds it" "$rigRc $( LC_ALL=C grep -c -F -- 'no test of that name in the copy the request is about: RigThree' "$rigTmp/q5c.err" ) $( rigHolds waiting )" "1 1 0"
rigAsk "$rigTmp/q5d" --by rig-first --why 'no such copy' --about rig-scratch-none RigOne
rigAssert "a scratch folder that holds no copy of the package is refused" "$rigRc $( LC_ALL=C grep -c -F -- "no copy of the package with its test runner at $rigWs/.local/temp/rig-scratch-none/source" "$rigTmp/q5d.err" ) $( rigHolds waiting )" "1 1 0"

echo "-- 6. changed files: a test is taken as that test, any other file as the tests that name it, and no test names it as nothing --"
rigFresh
rigAsk "$rigTmp/q6a" --by rig-first --why 'a changed test, by its path in the package and by its path in the tree' --file sh-test/RigTwo.test.sh --file "$rigLive/myx/myx.distro-agents/sh-test/RigOne.test.sh" ; rigIdA="$rigId"
rigAssert "a changed file that is a test is the test itself, however its path was given, and no file is kept" "$rigRc [$( LC_ALL=C grep -e '^test: ' -e '^file: ' "$rigQueue/waiting/$rigIdA.request" | LC_ALL=C sort | LC_ALL=C tr '\n' '|' )]" "0 [test: RigOne|test: RigTwo|]"
rigOp "$rigTmp/d6a" --retest-drain
rigAssert "the batch runs those two tests and no other" "$rigRc [$( rigBegun )] $( rigLine "$rigTmp/d6a" "$rigIdA" | LC_ALL=C cut -d' ' -f1-11 )" "0 [live:RigOne live:RigTwo] RETEST <id> PASS -- asked by rig-first about live: 2 passed"
rigAsk "$rigTmp/q6b" --by rig-second --why 'a library file was changed' --file sh-lib/wait/AgentsTools.MemberWait.include ; rigIdB="$rigId"
rigAssert "a changed file is asked for as the tests that name it, and kept as the file" "$rigRc [$( LC_ALL=C grep -e '^test: ' -e '^file: ' "$rigQueue/waiting/$rigIdB.request" | LC_ALL=C sort | LC_ALL=C tr '\n' '|' )] $( LC_ALL=C grep -c -F -- 'changed file(s) that no test of the copy names' "$rigTmp/q6b.err" )" "0 [file: sh-lib/wait/AgentsTools.MemberWait.include|test: RigThree|] 0"
rigOp "$rigTmp/d6b" --retest-drain
rigAssert "the batch runs that one test alone, not every test of the copy" "$rigRc [$( rigBegun )]" "0 [live:RigOne live:RigThree live:RigTwo]"
rigAssert "its line counts what it ran: the one test that names the file" "$( rigLine "$rigTmp/d6b" "$rigIdB" )" "RETEST <id> PASS -- asked by rig-second about live: 1 passed -- a library file was changed"
rigOp "$rigTmp/r6" --retest-result "$rigIdB"
rigAssert "and its outcome names the test and the file" "[$( LC_ALL=C grep -e '^  passed ' -e '^  file ' "$rigTmp/r6.out" | LC_ALL=C sed 's/ at [0-9TZ:-]*$/ at <when>/' | LC_ALL=C sort | LC_ALL=C tr '\n' '|' )]" "[  file sh-lib/wait/AgentsTools.MemberWait.include|  passed RigThree|]"
## A fixture of the tests is no test: it is named by its type and never ends in .test.sh, so it is a changed file
## like any other that is no test.
rigFixtures="$( rigRoot live )/myx/myx.distro-agents/sh-test/check-fixtures"
mkdir -p "$rigFixtures" && printf '#!/bin/sh\nexit 7\n' > "$rigFixtures/rig-tool.curl.stub.sh"
rigAsk "$rigTmp/q6c" --by rig-third --why 'a fixture of the tests was changed' --file sh-test/check-fixtures/rig-tool.curl.stub.sh ; rigIdC="$rigId"
rigAssert "a changed fixture below sh-test, named by its type, is kept as the file and asked for as no test" "$rigRc [$( LC_ALL=C grep -e '^test: ' -e '^file: ' "$rigQueue/waiting/$rigIdC.request" | LC_ALL=C tr '\n' '|' )] $( LC_ALL=C grep -c -F -- 'changed file(s) that no test of the copy names' "$rigTmp/q6c.err" )" "0 [file: sh-test/check-fixtures/rig-tool.curl.stub.sh|] 1"
rigOp "$rigTmp/d6c" --retest-drain
rigAssert "a file no test names runs nothing: the copy's whole suite is not put in the line for it" \
	"$rigRc $( rigBegins RigOne ) $( rigBegins RigTwo ) $( rigBegins RigThree ) $( rigLine "$rigTmp/d6c" "$rigIdC" )" "0 1 1 1 RETEST <id> FAIL -- asked by rig-third about live: 0 passed, NOT RUN: sh-test/check-fixtures/rig-tool.curl.stub.sh -- a fixture of the tests was changed"
rigOp "$rigTmp/r6c" --retest-result "$rigIdC"
rigAssert "and its result says which file gave it no test" "[$( LC_ALL=C grep -e '^  not-run ' -e '^  file ' "$rigTmp/r6c.out" | LC_ALL=C tr '\n' '|' )]" "[  file sh-test/check-fixtures/rig-tool.curl.stub.sh|  not-run sh-test/check-fixtures/rig-tool.curl.stub.sh no test of the copy names it|]"
rm -f "$rigFixtures/rig-tool.curl.stub.sh"

echo "-- 7. with nothing waiting, --rest runs only what has not passed on the state the copy is in --"
rigFresh
rigAsk "$rigTmp/q7a" --by rig-first --why 'one test' RigOne
rigOp "$rigTmp/d7a" --retest-drain
rigAssert "control: a batch of one test ran that one alone, as a run of named tests, which stood in the machine's line and left it" "$rigRc [$( rigBegun )] $( ls "$rigHome/.agents/magic-team/suite-queue" 2> /dev/null | LC_ALL=C grep -c '\.ticket$' || : )" "0 [live:RigOne] 0"
rigOp "$rigTmp/d7b" --retest-drain --rest
rigAssert "the queue is empty, and --rest runs the two tests that have not passed on this state, not the one that has" "$rigRc [$( rigBegun )]" "0 [live:RigOne live:RigThree live:RigTwo]"
rigAssert "it says so in one line" "$( LC_ALL=C grep '^RETEST ' "$rigTmp/d7b.out" | LC_ALL=C tr '\n' '|' )" "RETEST rest PASS -- about live: 2 passed, 1 passed on this very state before and not run again|"
rigOp "$rigTmp/d7c" --retest-drain --rest
rigAssert "asked again on the same state, it runs nothing: every test has passed on it" "$rigRc $( LC_ALL=C grep -c '^BEGIN ' "$rigTmp/log" ) $( LC_ALL=C grep '^RETEST ' "$rigTmp/d7c.out" | LC_ALL=C tr '\n' '|' )" "0 3 RETEST rest PASS -- about live: 0 passed, 3 passed on this very state before and not run again|"
printf '## the rig changed a library file\n' >> "$rigLive/myx/myx.distro-agents/sh-lib/member/AgentsTools.RetestQueue.include"
: > "$rigTmp/fail.RigTwo"
rigOp "$rigTmp/d7d" --retest-drain --rest
rigAssert "once a file of the copy has changed, nothing has passed on the new state: every test is run, as the copy's whole suite, in the machine's line for those" "$rigRc $( LC_ALL=C grep -c '^BEGIN ' "$rigTmp/log" ) $( [ -e "$rigHome/.agents/magic-team/suite-queue" ] && printf line || printf no-line )" "0 6 line"
rigAssert "and the test that fails is named in the line" "$( LC_ALL=C grep '^RETEST ' "$rigTmp/d7d.out" | LC_ALL=C tr '\n' '|' )" "RETEST rest FAIL -- about live: 2 passed, 0 passed on this very state before and not run again, FAILED OR NOT RUN: RigTwo|"
rm -f "$rigTmp"/fail.*
rigOp "$rigTmp/d7e" --retest-drain --rest
rigAssert "a failure is no pass: the rest is then that one test, and it alone is run" "$rigRc $( rigBegins RigTwo ) $( LC_ALL=C grep -c '^BEGIN ' "$rigTmp/log" ) $( LC_ALL=C grep '^RETEST ' "$rigTmp/d7e.out" | LC_ALL=C tr '\n' '|' )" "0 3 7 RETEST rest PASS -- about live: 1 passed, 2 passed on this very state before and not run again|"
rigOp "$rigTmp/d7f" --retest-drain --rest --about rig-scratch-a
rigAssert "--about names the copy the rest is for: the scratch copy's two tests, by its own runner" "$rigRc $( rigBegins RigOne rig-scratch-a ) $( rigBegins RigTwo rig-scratch-a ) $( LC_ALL=C grep '^RETEST ' "$rigTmp/d7f.out" | LC_ALL=C tr '\n' '|' )" "0 1 1 RETEST rest PASS -- about rig-scratch-a: 2 passed, 0 passed on this very state before and not run again|"
## what waits comes first: with a request in the queue, --rest runs its batch, and the rest only once nothing waits
: > "$rigTmp/log" ; : > "$rigTmp/hold.RigOne"
printf '## the rig changed it again\n' >> "$rigLive/myx/myx.distro-agents/sh-lib/member/AgentsTools.RetestQueue.include"
rigAsk "$rigTmp/q7g" --by rig-first --why 'waits when --rest is asked' RigOne ; rigIdA="$rigId"
rigCall "$rigTmp/d7g" --retest-drain --rest ; rigPidD=$rigLast
rigUntil 'BEGIN live RigOne' "$rigTmp/log" || rigRefuse "the batch's test never began, so nothing below would be measured"
rigAsk "$rigTmp/q7h" --by rig-second --why 'came in while that batch ran' RigTwo ; rigIdB="$rigId"
: > "$rigTmp/let.RigOne" ; rigEnd "$rigPidD"
rigAssert "the batch is run first, and with a request that came in meanwhile the rest is left: only the batch's test began" "$rigRc [$( rigBegun )] $( LC_ALL=C grep -c '^RETEST rest ' "$rigTmp/d7g.out" ) $( LC_ALL=C grep -c -F -- 'came in while the batch ran, and they come first' "$rigTmp/d7g.err" ) $( rigStands "$rigIdB" )" "0 [live:RigOne] 0 1 WAITING"
rm -f "$rigTmp"/hold.* "$rigTmp"/let.*
rigOp "$rigTmp/d7i" --retest-drain --rest
rigAssert "accepted sibling: drained again, the waiting request is run, and then, nothing waiting, the rest: the test no batch ran on this state" "$rigRc [$( rigBegun )] $( rigLine "$rigTmp/d7i" "$rigIdB" | LC_ALL=C cut -d' ' -f1-3 ) $( LC_ALL=C grep '^RETEST rest ' "$rigTmp/d7i.out" | LC_ALL=C tr '\n' '|' )" "0 [live:RigOne live:RigThree live:RigTwo] RETEST <id> PASS RETEST rest PASS -- about live: 1 passed, 2 passed on this very state before and not run again|"

echo "-- 8. no request is lost: one left by a drain that no longer exists is taken by the next --"
rigFresh
rigAsk "$rigTmp/q8a" --by rig-first --why 'its drain was killed' RigTwo ; rigIdA="$rigId"
( exit 0 ) & rigDead=$! ; wait "$rigDead" 2> /dev/null
mkdir -p "$rigQueue/running" "$rigQueue/drain.lock" ; mv "$rigQueue/waiting/$rigIdA.request" "$rigQueue/running/$rigIdA.request"
printf 'pid: %s\nstarted: Thu Jan  1 00:00:00 2026\nsince: 2026-01-01T00:00:00Z\n' "$rigDead" > "$rigQueue/drain.lock/holder"
rigAssert "control: the request stands in a batch nobody runs, behind a lock nobody holds" "$( rigStands "$rigIdA" ) $( rigHolds waiting )" "RUNNING 0"
rigOp "$rigTmp/d8" --retest-drain
rigAssert "the next drain takes the lock over and the request into its own batch, runs its test once, and finishes it" "$rigRc [$( rigBegun )] $( rigLine "$rigTmp/d8" "$rigIdA" | LC_ALL=C cut -d' ' -f1-3 ) $( rigHolds running ) $( [ -e "$rigQueue/drain.lock" ] && printf held || printf free )" "0 [live:RigTwo] RETEST <id> PASS 0 free"
rigOp "$rigTmp/d8b" --retest-drain
rigAssert "and it is never run twice: a drain after that finds nothing" "$rigRc [$( rigBegun )] $( LC_ALL=C grep -c '^RETEST ' "$rigTmp/d8b.out" )" "0 [live:RigTwo] 0"
rigDone="$( ls "$rigQueue/done" | LC_ALL=C sed -n 1p )"
python3 -I -B -c 'import os, sys, time; then = time.time() - 9 * 86400; [os.utime(p, (then, then)) for p in sys.argv[1:]]' "$rigQueue/done/$rigDone" || rigRefuse "the finished request could not be aged"
rigAsk "$rigTmp/q8c" --by rig-first --why 'a later request' RigOne ; rigIdC="$rigId"
rigOp "$rigTmp/d8c" --retest-drain
rigAssert "a finished request is kept seven days: one nine days old is gone after the next drain, the one just finished is kept" "$rigRc $( rigStands "$rigIdA" ) $( rigStands "$rigIdC" )" "0 UNKNOWN PASS"

echo "-- 9. the help pair, and nothing posted --"
for rigOpName in --retest-queue --retest-drain --retest-result ; do
	rigAssert "$rigOpName: the syntax echo, the manual's syntax line and the manual's entry, once each" "$( LC_ALL=C grep -c "^echo \"📘 syntax: DistroAgentsTesting.fn.sh $rigOpName" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c "^📘 syntax: DistroAgentsTesting.fn.sh $rigOpName" "$rigHelpManual" || : ) $( LC_ALL=C grep -c -E "^[[:space:]]+$rigOpName( |\$)" "$rigHelpManual" || : )" "1 1 1"
done
rigAssert "control: the same three readers on --get-path-history give 1 1 1" "$( LC_ALL=C grep -c "^echo \"📘 syntax: DistroAgentsKnowledge.fn.sh --get-path-history" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c "^📘 syntax: DistroAgentsKnowledge.fn.sh --get-path-history" "$rigHelpManual" || : ) $( LC_ALL=C grep -c -E "^[[:space:]]+--get-path-history( |\$)" "$rigHelpManual" || : )" "1 1 1"
rigOp "$rigTmp/h9" --retest-queue --no-such-option
rigAssert "an unknown option is refused with the syntax, which is the one the help gives" "$rigRc $( LC_ALL=C grep -c -F -- "syntax is $( LC_ALL=C sed -n 's/^📘 syntax: DistroAgentsTesting.fn.sh --retest-queue //p' "$rigHelpManual" )" "$rigTmp/h9.err" )" "1 1"
rigAssert "the queue's code sends nothing anywhere: it names no Slack call, no curl and no post" "$( LC_ALL=C grep -c -i -E 'slack|curl|AgentsTools[A-Za-z]*(Post|Send)' "$rigInclude" )" "0"

echo "-- 10. a copy's requests run shortest first, and each is answered as soon as its own tests have run --"
rigFresh
: > "$rigTmp/hold.RigOne" ; : > "$rigTmp/hold.RigTwo" ; : > "$rigTmp/hold.RigThree"
rigAsk "$rigTmp/q10a" --by rig-first --why 'the two-test request, asked first' RigTwo RigThree ; rigIdA="$rigId"
rigAsk "$rigTmp/q10b" --by rig-second --why 'the one-test request, asked second' RigOne ; rigIdB="$rigId"
rigCall "$rigTmp/d10" --retest-drain ; rigPidD=$rigLast
rigUntil 'BEGIN live RigOne' "$rigTmp/log" || rigRefuse "the batch's first test never began, so nothing below would be measured"
rigAssert "the one-test request runs first, though it was asked second" "$( LC_ALL=C sed -n 's/^BEGIN live //p' "$rigTmp/log" | LC_ALL=C head -1 ) $( [ -f "$rigQueue/running/$rigIdA.request" ] && printf ahead-in-batch || printf missing ) $( [ -f "$rigQueue/running/$rigIdB.request" ] && printf in-batch || printf missing )" "RigOne ahead-in-batch in-batch"
: > "$rigTmp/let.RigOne"
for rigWaitLeft in $( seq 1 300 ) ; do
	[ ! -f "$rigQueue/done/$rigIdB.result" ] || break
	sleep 1
done
rigAssert "the shorter request is answered while the longer one still runs" "$( [ -f "$rigQueue/done/$rigIdB.result" ] && printf finished || printf waiting ) $( [ -f "$rigQueue/running/$rigIdA.request" ] && printf running || printf gone )" "finished running"
rigAssert "the finished shorter request's result names the one test it ran" "$( LC_ALL=C sed -n 's/^passed: //p' "$rigQueue/done/$rigIdB.result" 2> /dev/null | LC_ALL=C tr '\n' ' ' )" "RigOne "
: > "$rigTmp/let.RigTwo" ; : > "$rigTmp/let.RigThree" ; rigEnd "$rigPidD"
rigAssert "each test ran once, and the longer request passes with its two" "$( rigBegins RigOne ) $( rigBegins RigTwo ) $( rigBegins RigThree ) $( rigLine "$rigTmp/d10" "$rigIdA" | LC_ALL=C cut -d' ' -f1-3 )" "1 1 1 RETEST <id> PASS"
rigAssert "the longer request's own result names the two tests it ran" "$( LC_ALL=C sed -n 's/^passed: //p' "$rigQueue/done/$rigIdA.result" 2> /dev/null | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "RigThree RigTwo "
rm -f "$rigTmp"/hold.* "$rigTmp"/let.*

echo "-- 11. a drain waits the machine's line out, however long it is, so a busy machine does not answer a request NOT RUN --"
rigFresh
: > "$rigTmp/limits.log"
rigAsk "$rigTmp/q11a" --by rig-first --why 'the line is long' RigOne ; rigIdA="$rigId"
rigOp "$rigTmp/d11" --retest-drain
rigAssert "the test a drain runs is handed a lane wait well past the runner's own 900s bound" "$( LC_ALL=C sed -n '$p' "$rigTmp/limits.log" | LC_ALL=C awk '{ print ( $1 + 0 >= 3600 ) ? "long" : "short" ; }' )" "long"
rigAssert "and its request passes, never answered NOT RUN for a line it gave up on" "$( rigLine "$rigTmp/d11" "$rigIdA" | LC_ALL=C cut -d' ' -f1-3 )" "RETEST <id> PASS"
: > "$rigTmp/limits.log"
rigLane=1234
rigAsk "$rigTmp/q11b" --by rig-second --why 'a caller wants a short wait' RigOne ; rigIdB="$rigId"
rigOp "$rigTmp/d11b" --retest-drain
rigAssert "a caller's own shorter wait is the one the test is handed" "$( LC_ALL=C sed -n '$p' "$rigTmp/limits.log" )" "1234"
rigLane=""
rigFresh

echo "-- 12. the widest request is one naming every test of the copy, and a narrower request ends it at the next test boundary --"
## The widest request here names every test of the copy. With one test of it begun and
## still held, a request naming one test is narrower than the tests left to run, so that batch must stop at the boundary
## and run the narrow one's test, within one test of the widest. The narrow request names the test the widest would run LAST,
## so a widest that went on would run another test before it.
rigFresh
: > "$rigTmp/hold.RigOne" ; : > "$rigTmp/hold.RigTwo" ; : > "$rigTmp/hold.RigThree"
rigAsk "$rigTmp/q12a" --by rig-first --why 'every test of the copy, the widest request there is' RigOne RigTwo RigThree ; rigIdA="$rigId"
rigCall "$rigTmp/d12" --retest-drain ; rigPidD=$rigLast
rigUntil 'BEGIN live ' "$rigTmp/log" 180 || rigRefuse "the widest request's first test never began, so nothing below would be measured"
rigBatch="$( rigBatchOrder "$rigTmp/d12" )"
[ -n "$rigBatch" ] || rigRefuse "the widest request named no test list, so nothing below would be measured"
rigFirst="$( printf '%s' "$rigBatch" | LC_ALL=C awk '{ print $1 }' )"
rigNarrow="$( printf '%s' "$rigBatch" | LC_ALL=C awk '{ print $NF }' )"
[ "$rigNarrow" != "$rigFirst" ] || rigRefuse "the widest request names one test alone, so a narrow request could not be told from it"
rigAsk "$rigTmp/q12b" --by rig-second --why 'one test, asked while the widest ran' "$rigNarrow" ; rigIdB="$rigId"
: > "$rigTmp/let.$rigFirst"
rigSecond=""
for rigWaitLeft in $( seq 1 120 ) ; do
	rigSecond="$( LC_ALL=C sed -n 's/^BEGIN live //p' "$rigTmp/log" | LC_ALL=C sed -n 2p )"
	[ -z "$rigSecond" ] || break
	sleep 0.5
done
rm -f "$rigTmp"/hold.* "$rigTmp"/let.*
for rigWaitLeft in $( seq 1 300 ) ; do
	kill -0 "$rigPidD" 2> /dev/null || break
	sleep 1
done
rigEnd "$rigPidD"
rigAssert "any request naming tests ends the widest at the boundary, and is run in that same batch: the test that runs next is the narrow request's, whose request is answered by the batch already running" \
	"$rigRc $( printf '%s' "$rigIdB" | LC_ALL=C grep -c '^retest-' ) $( printf '%s' "$rigSecond" )|$( rigLine "$rigTmp/d12" "$rigIdB" | LC_ALL=C cut -d' ' -f1-3 )" \
	"0 1 $rigNarrow|RETEST <id> PASS"
rm -f "$rigTmp"/hold.* "$rigTmp"/let.*

echo "-- 13. a drain that dies leaves no runner of its batch alive, or the next drain ends the orphan before it starts --"
## What is read is the runner itself: how many of this rig's test runners are alive. A test of the batch is held, so a runner
## that nothing ends stands there for as long as the rig holds it. The control proves the probe can see a runner at all. Then
## a drain is ended by TERM while its test is held, its request is taken out of the queue by hand so that no later run of that
## test can be counted, the next drain takes the queue over, and the probe is read again. Every runner an earlier section
## left behind is ended first, so the count read here is this section's own.
rigFresh
rigRunnersClear
: > "$rigTmp/hold.RigThree"
rigAsk "$rigTmp/q13a" --by rig-first --why 'the control: a batch nobody ends, its test held' RigThree
rigCall "$rigTmp/d13a" --retest-drain ; rigPidC=$rigLast
rigUntil 'BEGIN live RigThree' "$rigTmp/log" || rigRefuse "the control batch's test never began, so nothing below would be measured"
rigSeen="$( rigRunners )"
rigControl="$( if [ "$rigSeen" -ge 1 ] ; then printf seen ; else printf blind ; fi )"
rm -f "$rigTmp"/let.* ; : > "$rigTmp/let.RigThree" ; rigEnd "$rigPidC"
rigCNote="$( rigRunnerPids )" ; [ -z "$rigCNote" ] || rigProcNote $rigCNote
rm -f "$rigTmp"/hold.* "$rigTmp"/let.*
rigFresh
rigRunnersClear
: > "$rigTmp/hold.RigOne"
rigAsk "$rigTmp/q13b" --by rig-second --why 'a drain ended by a signal while its test ran' RigOne
rigCall "$rigTmp/d13b" --retest-drain ; rigPidD=$rigLast
rigUntil 'BEGIN live RigOne' "$rigTmp/log" || rigRefuse "the drain's test never began, so nothing below would be measured"
rigDrainPid="$( LC_ALL=C sed -n 's/^pid: //p' "$rigQueue/drain.lock/holder" 2> /dev/null | LC_ALL=C sed -n 1p )"
[ -n "$rigDrainPid" ] || rigRefuse "the queue names no drain to end, so nothing below would be measured"
rigProcNote "$rigDrainPid" ; rigProcSignal TERM "$rigDrainPid" ; rigEnd "$rigPidD"
rm -f "$rigQueue/running"/*.request
rigOp "$rigTmp/d13c" --retest-drain ; rigNextRc=$rigRc
## A runner that has been told to end is given until it has: what is left after that is left behind.
for rigWaitLeft in $( seq 1 20 ) ; do
	[ "$( rigRunners )" -gt 0 ] || break
	sleep 1
done
rigLeft="$( rigRunners )"
rigNote="$( rigRunnerPids )" ; [ -z "$rigNote" ] || rigProcNote $rigNote
rigAssert "a drain ended by a signal leaves no runner of its batch alive, or the next drain ends the orphan before it starts: the probe sees a runner while one is held, and no runner of this rig is left once the next drain has taken the queue over" \
	"control:$( printf '%s' "$rigControl" ) left:$( printf '%s' "$rigLeft" ) next-drain:$( printf '%s' "$rigNextRc" )" \
	"control:seen left:0 next-drain:0"
[ -z "$rigNote" ] || rigProcSignal TERM $rigNote
[ -z "$rigCNote" ] || rigProcSignal TERM $rigCNote
rm -f "$rigTmp"/hold.* "$rigTmp"/let.*
rigFresh

echo "-- 14. a wide request stopped at a boundary answers YIELDED, naming a new request that carries what it was asked --"
## What a request was asked with is read from the request file the new id names, by the fields' own names, never by the
## order of a line. The id itself is read as any request id in the answer other than the one asked about, since where in
## that line a drain says it is not the rig's to choose.
rigFresh
: > "$rigTmp/hold.RigOne" ; : > "$rigTmp/hold.RigTwo" ; : > "$rigTmp/hold.RigThree"
rigAsk "$rigTmp/q14a" --by rig-first --why 'the wide one, which the narrow one stops' RigOne RigTwo RigThree ; rigIdA="$rigId"
rigCall "$rigTmp/d14" --retest-drain ; rigPidD=$rigLast
rigUntil 'BEGIN live ' "$rigTmp/log" 180 || rigRefuse "the wide request's first test never began, so nothing below would be measured"
rigBatch="$( rigBatchOrder "$rigTmp/d14" )"
[ -n "$rigBatch" ] || rigRefuse "the wide request named no test list, so nothing below would be measured"
rigFirst="$( printf '%s' "$rigBatch" | LC_ALL=C awk '{ print $1 }' )"
rigNarrow="$( printf '%s' "$rigBatch" | LC_ALL=C awk '{ print $NF }' )"
[ "$rigNarrow" != "$rigFirst" ] || rigRefuse "the wide request names one test alone, so a narrow request could not be told from it"
rigAsk "$rigTmp/q14b" --by rig-second --why 'the narrow one' "$rigNarrow" ; rigIdB="$rigId"
: > "$rigTmp/let.$rigFirst"
rm -f "$rigTmp"/hold.* "$rigTmp"/let.*
for rigWaitLeft in $( seq 1 300 ) ; do
	kill -0 "$rigPidD" 2> /dev/null || break
	sleep 1
done
rigEnd "$rigPidD"
rigYRaw="$( LC_ALL=C grep -F -- "RETEST $rigIdA " "$rigTmp/d14.out" 2> /dev/null | LC_ALL=C sed -n 1p )"
## The words are the ruling's; where in the line a drain puts them is not the rig's to choose.
rigYVerdict="$( printf '%s' "$rigYRaw" | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c -x -F -- YIELDED )"
rigYNew="$( printf '%s' "$rigYRaw" | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -E '^retest-[0-9]{8}T[0-9]{6}Z-' | LC_ALL=C grep -v -x -F -- "$rigIdA" | LC_ALL=C sed -n 1p )"
## The new request may still wait, or may have run already; a finished one keeps the request it was made from in its result.
rigYFile=""
[ -z "$rigYNew" ] || rigYFile="$( LC_ALL=C grep -l -x -F -- "id: $rigYNew" "$rigQueue"/*/*.request "$rigQueue"/*/*.result 2> /dev/null | LC_ALL=C sed -n 1p )"
rigYFields="$( [ -z "$rigYFile" ] || LC_ALL=C grep -c -e '^by: ' -e '^why: ' -e '^about: ' -e '^origin: ' -e '^workspace: ' "$rigYFile" )"
rigYFrom="$( [ -z "$rigYFile" ] || LC_ALL=C sed -n 's/^returned-from: //p' "$rigYFile" | LC_ALL=C sed -n 1p )"
rigYAbout="$( [ -z "$rigYFile" ] || LC_ALL=C sed -n 's/^about: //p' "$rigYFile" | LC_ALL=C sed -n 1p )"
rigYOrigin="$( [ -z "$rigYFile" ] || LC_ALL=C sed -n 's/^origin: //p' "$rigYFile" | LC_ALL=C sed -n 1p )"
rigAssert "a wide request stopped at a boundary answers YIELDED, naming a new request that carries who asked, why, about which copy, where that copy and the workspace are, and returned-from naming the first" \
	"yielded:$( printf '%s' "$rigYVerdict" )|$( printf '%s' "$rigYFields" )|$( [ "$rigYFrom" = "$rigIdA" ] && printf returned-from-ok || printf returned-from-wrong )|$( printf '%s' "$rigYAbout" )|$( [ "$rigYOrigin" = "$rigLive" ] && printf origin-ok || printf origin-wrong )" \
	"yielded:1|5|returned-from-ok|live|origin-ok"
rm -f "$rigTmp"/hold.* "$rigTmp"/let.*

echo "-- 15. the boundary covers only a run a drain starts: a plain run of the runner keeps today's behaviour --"
## A narrow request waits in the queue and no drain is started, so it stays waiting. The rig's own runner is then called as a
## person calls it, with one worker, so that its next test is the very same worker's next check, and its first test is held.
## That run must go on, since no drain started it and no boundary is due; it answers no request. This one holds today and
## after the change: it is the control of the boundary.
rigFresh
rigRunnersClear
: > "$rigTmp/hold.RigOne" ; : > "$rigTmp/hold.RigTwo"
rigAsk "$rigTmp/q15a" --by rig-first --why 'waits while a plain run goes on' RigThree
( cd "$rigLive/myx/myx.distro-agents" && exec env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$rigLive" MDLT_OPTION="--run-from-path $rigLive" RIG_SHARED="$rigTmp" bash sh-test/AgentsRunTests.sh --wait -w 1 RigOne RigTwo ) > "$rigTmp/p15.out" 2> "$rigTmp/p15.err" < /dev/null &
rigPidP=$!
rigStarted="$rigStarted $rigPidP" ; rigProcNote "$rigPidP"
rigUntil 'BEGIN live ' "$rigTmp/log" || rigRefuse "the plain run's first test never began, so nothing below would be measured"
rigBatch="$( rigBatchOrder "$rigTmp/p15" )"
[ -n "$rigBatch" ] || rigRefuse "the plain run named no test list, so nothing below would be measured"
rigFirst="$( printf '%s' "$rigBatch" | LC_ALL=C awk '{ print $1 }' )"
rigSecond="$( printf '%s' "$rigBatch" | LC_ALL=C awk '{ print $2 }' )"
rigRunFolderPlain="$( rigRunFolder "$rigTmp/p15" )"
[ -n "$rigRunFolderPlain" ] || rigRefuse "the plain run named no run folder, so nothing below would be measured"
: > "$rigTmp/let.$rigFirst"
## Read from the plain run's own run folder, never from the shared log: another run of this rig also writes there.
rigPlainAfter=""
for rigWaitLeft in $( seq 1 120 ) ; do
	[ ! -f "$rigRunFolderPlain/$rigSecond.begin" ] || { rigPlainAfter="began" ; break ; }
	sleep 0.5
done
rigPlainWaiting="$( rigHolds waiting )"
rm -f "$rigTmp"/hold.* "$rigTmp"/let.*
rigEnd "$rigPidP"
rigAssert "the boundary covers only a run a drain starts: with a narrow request waiting and no drain started, a plain run of the runner goes on to its next test, and that request still waits" \
	"$( printf '%s' "${rigPlainAfter:-not-begun}" )|$( printf '%s' "$rigPlainWaiting" )|$( LC_ALL=C grep -c '^RETEST ' "$rigTmp/p15.out" )" \
	"began|1|0"
rigFresh

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ RETEST QUEUE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'RETEST_QUEUE: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
