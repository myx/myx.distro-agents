#!/usr/bin/env bash
## Behavioural check on the retest queue (--retest-queue, --retest-drain, --retest-result:
## sh-lib/member/AgentsTools.MemberRetest.include), run rather than read, on a fixture machine built here: a HOME, whose
## .agents/magic-team/retest-queue is the machine's one queue, and a workspace whose own tree is a copy of the tooling
## as it stands at the origin, with three tiny tests and the test runner in place of the package's tests, and beside
## it a scratch copy with two. Held: queueing returns at once with an id and waits for no test; a drain takes
## everything that waits as one batch and runs each test once however many requests named it, so two requests naming
## one test give one run and two results; a test that fails fails every request that named it; a request that comes in
## while a batch runs is in the next batch, and a second drain is refused meanwhile; a request is about one copy, the
## live tree or a scratch folder, and each copy's tests are run by that copy's own runner; a changed file that is a
## test is taken as that test, and any other file as every test that has not passed on the state the copy is in; with
## nothing waiting, --rest runs only what has not passed on that state; a request left by a drain that no longer
## exists is taken by the next; a finished request is read by its id, and kept seven days. Nothing here is told by how
## long a run takes: a test that must still be running when something else is done runs until the rig lets it end.
## Offline, a rig tree only: every call goes through one `env -i` whose child refuses to start unless MMDAPP sits
## under this rig's mktemp tree, and nothing here reaches Slack or any endpoint.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigInclude="$rigPackage/sh-lib/member/AgentsTools.MemberRetest.include"
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
cp "$rigPackage/project.inf" "$rigLive/myx/myx.distro-agents/project.inf"
for rigSibling in myx.distro-.local myx.distro-system ; do rigTake "myx/$rigSibling" "myx/$rigSibling" || rigRefuse "the tooling's $rigSibling could not be copied into the rig" ; done
rigTake myx/myx.common/os-myx.common/host/tarball/share/myx.common myx/myx.common/os-myx.common/host/tarball/share/myx.common || rigRefuse "myx.common could not be copied into the rig"
rigTool="$rigLive/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
[ -f "$rigTool" ] && [ -f "$rigLive/myx/myx.distro-agents/sh-lib/member/AgentsTools.MemberRetest.include" ] || rigRefuse "the rig's copy of the tooling holds no retest queue, so nothing below would be measured"
rigRoot(){ ## copy -- its source root: `live` is the workspace's own tree, any other name a scratch folder of that name
	if [ "$1" = live ] ; then printf '%s\n' "$rigLive" ; else printf '%s\n' "$rigWs/.local/temp/$1/source" ; fi
}
rigTests(){ ## copy, test... -- that copy's tests: the runner under test and the tiny tests named. Each says in the shared log when it begins and ends and which copy it ran in; it ends only once the rig lets it where the rig holds it (hold.<test>), and fails where the rig says so (fail.<test>)
	local testsDir testsName ; testsDir="$( rigRoot "$1" )/myx/myx.distro-agents/sh-test" ; shift
	rm -rf "$testsDir" ; mkdir -p "$testsDir"
	cp "$rigPackage/sh-test/AgentsRunTests.sh" "$testsDir/AgentsRunTests.sh"
	mkdir -p "$testsDir/check-fixtures" && cp "$rigPackage/sh-test/check-fixtures"/runner-*.py "$testsDir/check-fixtures"/
	for testsName in "$@" ; do
		cat > "$testsDir/$testsName.test.sh" <<'RIGTINY'
#!/usr/bin/env bash
rigTinyName="${0##*/}" ; rigTinyName="${rigTinyName%.test.sh}"
case "$MDLT_ORIGIN" in */.local/temp/*) rigTinyCopy="${MDLT_ORIGIN##*/.local/temp/}" ; rigTinyCopy="${rigTinyCopy%%/*}" ;; *) rigTinyCopy=live ;; esac
printf 'BEGIN %s %s\n' "$rigTinyCopy" "$rigTinyName" >> "$RIG_SHARED/log"
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

rigCall(){ ## result prefix, operation, its arguments... -- one call of the tooling from the workspace, in the background; <prefix>.out .err, its pid in rigLast
	local callOut="$1" ; shift
	case "$rigWs" in "$rigTmp"/*) ;; *) rigRefuse "the workspace is outside this rig's own tree: $rigWs" ;; esac
	( cd "$rigWs" && exec env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$rigLive" MDLT_OPTION="--run-from-path $rigLive" RIG_TMP="$rigTmp" RIG_SHARED="$rigTmp" ${rigAs:+MDAT_SPAWN_AGENT="$rigAs"} \
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
rigUntil(){ ## fixed text, file -- waits for a line of the file to hold the text, however long a busy host takes, up to four minutes; rc 1 when it never does
	local untilLeft=1200
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
	rm -rf "$rigHome/.agents" ; : > "$rigTmp/log" ; rm -f "$rigTmp"/hold.* "$rigTmp"/let.* "$rigTmp"/fail.* ; rigAs=""
}
rigAs=""

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

echo "-- 4. a request that comes in while a batch runs is in the next batch --"
rigFresh
: > "$rigTmp/hold.RigOne"
rigAsk "$rigTmp/q4a" --by rig-first --why 'in the first batch' RigOne ; rigIdA="$rigId"
rigCall "$rigTmp/d4" --retest-drain ; rigPidD=$rigLast
rigUntil 'BEGIN live RigOne' "$rigTmp/log" || rigRefuse "the batch's test never began, so nothing below would be measured"
rigAsk "$rigTmp/q4b" --by rig-second --why 'asked while the batch ran' RigOne ; rigIdB="$rigId"
rigAssert "queueing waits for no test: the request is taken while the batch's test is still running" "$rigRc $( printf '%s' "$rigIdB" | LC_ALL=C grep -c '^retest-' ) $( LC_ALL=C grep -c '^END ' "$rigTmp/log" )" "0 1 0"
rigAssert "the first is said to be in the batch being run, the second to wait" "$( rigStands "$rigIdA" ) $( rigStands "$rigIdB" )" "RUNNING WAITING"
rigOp "$rigTmp/d4x" --retest-drain
rigAssert "a second drain is refused while one runs, saying so, and takes nothing" "$rigRc $( LC_ALL=C grep -c -F -- 'a batch is being run already' "$rigTmp/d4x.err" ) $( rigHolds waiting ) $( rigBegins RigOne )" "1 1 1 1"
: > "$rigTmp/let.RigOne" ; rigEnd "$rigPidD"
rigAssert "the batch ends with the first request alone, and the second still waits: it was run for nobody yet" "$rigRc $( LC_ALL=C grep -c '^RETEST ' "$rigTmp/d4.out" ) $( rigLine "$rigTmp/d4" "$rigIdA" | LC_ALL=C cut -d' ' -f1-3 ) $( rigStands "$rigIdB" ) $( rigBegins RigOne )" "0 1 RETEST <id> PASS WAITING 1"
rm -f "$rigTmp"/hold.* "$rigTmp"/let.*
rigOp "$rigTmp/d4b" --retest-drain
rigAssert "the next drain is its batch: the test is run for it, once" "$rigRc $( rigLine "$rigTmp/d4b" "$rigIdB" | LC_ALL=C cut -d' ' -f1-3 ) $( rigBegins RigOne ) $( rigHolds waiting ) $( rigHolds done )" "0 RETEST <id> PASS 2 0 2"

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

echo "-- 6. changed files: a test is taken as that test, any other file as every test not yet passed on the state the copy is in --"
rigFresh
rigAsk "$rigTmp/q6a" --by rig-first --why 'a changed test, by its path in the package and by its path in the tree' --file sh-test/RigTwo.test.sh --file "$rigLive/myx/myx.distro-agents/sh-test/RigOne.test.sh" ; rigIdA="$rigId"
rigAssert "a changed file that is a test is the test itself, however its path was given, and no file is kept" "$rigRc [$( LC_ALL=C grep -e '^test: ' -e '^file: ' "$rigQueue/waiting/$rigIdA.request" | LC_ALL=C sort | LC_ALL=C tr '\n' '|' )]" "0 [test: RigOne|test: RigTwo|]"
rigOp "$rigTmp/d6a" --retest-drain
rigAssert "the batch runs those two tests and no other" "$rigRc [$( rigBegun )] $( rigLine "$rigTmp/d6a" "$rigIdA" | LC_ALL=C cut -d' ' -f1-11 )" "0 [live:RigOne live:RigTwo] RETEST <id> PASS -- asked by rig-first about live: 2 passed"
rigAsk "$rigTmp/q6b" --by rig-second --why 'a library file was changed' --file sh-lib/member/AgentsTools.MemberWait.include ; rigIdB="$rigId"
rigAssert "any other changed file is kept as the file: no test is known to cover it" "$rigRc [$( LC_ALL=C grep -e '^test: ' -e '^file: ' "$rigQueue/waiting/$rigIdB.request" | LC_ALL=C tr '\n' '|' )] $( LC_ALL=C grep -c -F -- 'changed file(s) no test is known to cover' "$rigTmp/q6b.err" )" "0 [file: sh-lib/member/AgentsTools.MemberWait.include|] 1"
rigOp "$rigTmp/d6b" --retest-drain
rigAssert "the batch runs for it every test that has not passed on the state the copy is in: the one test left, and neither of the two that just passed on it" "$rigRc [$( rigBegun )]" "0 [live:RigOne live:RigThree live:RigTwo]"
rigAssert "its line counts every test of the copy: what ran now, and what had passed on this very state before" "$( rigLine "$rigTmp/d6b" "$rigIdB" )" "RETEST <id> PASS -- asked by rig-second about live: 1 passed, 2 passed on this very state before and not run again -- a library file was changed"
rigOp "$rigTmp/r6" --retest-result "$rigIdB"
rigAssert "and its outcome names each: the test that ran, the two that had passed, and the file" "[$( LC_ALL=C grep -e '^  passed ' -e '^  passed-before ' -e '^  file ' "$rigTmp/r6.out" | LC_ALL=C sed 's/ at [0-9TZ:-]*$/ at <when>/' | LC_ALL=C sort | LC_ALL=C tr '\n' '|' )]" "[  file sh-lib/member/AgentsTools.MemberWait.include|  passed RigThree|  passed-before RigOne at <when>|  passed-before RigTwo at <when>|]"
## A fixture of the tests is no test: it is named by its type and never ends in .test.sh, so it is a changed file
## like any other that is no test.
rigFixtures="$( rigRoot live )/myx/myx.distro-agents/sh-test/check-fixtures"
mkdir -p "$rigFixtures" && printf '#!/bin/sh\nexit 7\n' > "$rigFixtures/rig-tool.curl.stub.sh"
rigAsk "$rigTmp/q6c" --by rig-third --why 'a fixture of the tests was changed' --file sh-test/check-fixtures/rig-tool.curl.stub.sh ; rigIdC="$rigId"
rigAssert "a changed fixture below sh-test, named by its type, is kept as the file and asked for as no test" "$rigRc [$( LC_ALL=C grep -e '^test: ' -e '^file: ' "$rigQueue/waiting/$rigIdC.request" | LC_ALL=C tr '\n' '|' )] $( LC_ALL=C grep -c -F -- 'changed file(s) no test is known to cover' "$rigTmp/q6c.err" )" "0 [file: sh-test/check-fixtures/rig-tool.curl.stub.sh|] 1"
rigOp "$rigTmp/d6c" --retest-drain
rigAssert "the batch runs for it every test of the copy, whose state the changed fixture moved, each once more, and the request does not read as failed for a test that was never one" \
	"$rigRc $( rigBegins RigOne ) $( rigBegins RigTwo ) $( rigBegins RigThree ) $( rigLine "$rigTmp/d6c" "$rigIdC" )" "0 2 2 2 RETEST <id> PASS -- asked by rig-third about live: 3 passed -- a fixture of the tests was changed"
rm -f "$rigFixtures/rig-tool.curl.stub.sh"

echo "-- 7. with nothing waiting, --rest runs only what has not passed on the state the copy is in --"
rigFresh
rigAsk "$rigTmp/q7a" --by rig-first --why 'one test' RigOne
rigOp "$rigTmp/d7a" --retest-drain
rigAssert "control: a batch of one test ran that one alone, as a run of named tests, in no line for full suites" "$rigRc [$( rigBegun )] $( [ -e "$rigHome/.agents/magic-team/suite-queue" ] && printf line || printf no-line )" "0 [live:RigOne] no-line"
rigOp "$rigTmp/d7b" --retest-drain --rest
rigAssert "the queue is empty, and --rest runs the two tests that have not passed on this state, not the one that has" "$rigRc [$( rigBegun )]" "0 [live:RigOne live:RigThree live:RigTwo]"
rigAssert "it says so in one line" "$( LC_ALL=C grep '^RETEST ' "$rigTmp/d7b.out" | LC_ALL=C tr '\n' '|' )" "RETEST rest PASS -- about live: 2 passed, 1 passed on this very state before and not run again|"
rigOp "$rigTmp/d7c" --retest-drain --rest
rigAssert "asked again on the same state, it runs nothing: every test has passed on it" "$rigRc $( LC_ALL=C grep -c '^BEGIN ' "$rigTmp/log" ) $( LC_ALL=C grep '^RETEST ' "$rigTmp/d7c.out" | LC_ALL=C tr '\n' '|' )" "0 3 RETEST rest PASS -- about live: 0 passed, 3 passed on this very state before and not run again|"
printf '## the rig changed a library file\n' >> "$rigLive/myx/myx.distro-agents/sh-lib/member/AgentsTools.MemberRetest.include"
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
printf '## the rig changed it again\n' >> "$rigLive/myx/myx.distro-agents/sh-lib/member/AgentsTools.MemberRetest.include"
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

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ RETEST QUEUE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'RETEST_QUEUE: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
