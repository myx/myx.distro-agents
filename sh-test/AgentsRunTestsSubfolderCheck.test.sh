#!/usr/bin/env bash
## Behavioural check on where a test stands, run rather than read, on a fixture machine built here: a HOME, a
## workspace, and in its temp one copy of the package whose sh-test holds the runner under test, a test in sh-test
## itself and a test in a subfolder of it, one level down, and a fixture in check-fixtures/. Held: the runner lists
## (`--passed`) and runs both tests, by name and in a run with no names, and nothing of check-fixtures/; the retest
## queue takes the test in the subfolder by its name, and by its path given as a changed file, and its drain runs it.
## And over the package itself: nothing but a check ends in `.test.sh` (no fixture of check-fixtures/ does, each is
## named by its type), and no two checks of sh-test and its subfolders share a name, since a test is run by its name.
## Red before the subfolders were read: the runner and the queue found no test below sh-test itself.
## Offline, a rig tree only: every call goes through one `env -i` whose child refuses to start unless MMDAPP sits
## under this rig's mktemp tree; nothing here reaches Slack or any endpoint.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRunner="$rigPackage/sh-test/AgentsRunTests.sh"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigRunner" ] || rigRefuse "the runner is not at the origin this workspace resolves: $rigRunner"
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "${MYXROOT:-/usr/local/share/myx.common}/bin/lib/parallel.Common" ] || rigRefuse "myx.common lib/parallel, which the runner runs its tests with, is not at ${MYXROOT:-/usr/local/share/myx.common}"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRunTestsSubfolderCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigHome="$rigTmp/home" ; rigWs="$rigTmp/ws"
rigCopy="$rigWs/.local/temp/rig-copy/source"
rigTests="$rigCopy/myx/myx.distro-agents/sh-test"
rigQueue="$rigHome/.agents/magic-team/retest-queue"
mkdir -p "$rigHome" "$rigWs/.local/.agents" "$rigTmp/members/rig-member" "$rigTmp/data" "$rigTests/session" "$rigTests/check-fixtures" || exit 1
printf 'rig member\n' > "$rigTmp/members/rig-member/rig-member.basic.md"
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
## The copy: the package's own code by link, and its sh-test this rig's own: the runner under test, two tiny tests
## that each write down that they ran, and a fixture that would say so too, were it ever run.
for rigPart in sh-lib sh-scripts project.inf ; do
	ln -s "$rigPackage/$rigPart" "$rigCopy/myx/myx.distro-agents/$rigPart" || rigRefuse "the copy could not link $rigPart"
done
cp "$rigRunner" "$rigTests/AgentsRunTests.sh" || rigRefuse "the runner could not be copied into the rig"
mkdir -p "$rigTests/check-fixtures" && cp "$(dirname "$rigRunner")/check-fixtures"/runner-*.py "$rigTests/check-fixtures"/
rigTiny(){ ## file
	printf '#!/usr/bin/env bash\nprintf "RAN %%s\\n" "${0##*/}" >> "$RIG_SHARED/log"\necho "RIG_TINY: OK"\n' > "$1"
}
rigTiny "$rigTests/RigTop.test.sh"
rigTiny "$rigTests/session/RigSub.test.sh"
rigTiny "$rigTests/check-fixtures/rig-thing.stub.sh"

rigCall(){ ## result prefix, command... -- one call from the workspace, rc in rigRc
	local callOut="$1" ; shift
	rigRc=0
	( cd "$rigWs" && exec env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MYXROOT="${MYXROOT:-}" \
		MDAT_SKILLSET_ROOT="$rigTmp/members" MDAT_DATA_ROOT="$rigTmp/data" RIG_TMP="$rigTmp" RIG_SHARED="$rigTmp" \
		bash -c 'case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; exec "$@"' rig "$@" ) > "$callOut.out" 2> "$callOut.err" < /dev/null || rigRc=$?
}
rigRun(){ ## result prefix, runner arguments... -- the copy's runner on the copy
	local runOut="$1" ; shift
	rigCall "$runOut" env MDLT_ORIGIN="$rigCopy" MDLT_OPTION="--run-from-path $rigCopy" bash "$rigTests/AgentsRunTests.sh" "$@"
}
rigRan(){ ## test file name -- how many times it ran, by the shared log
	LC_ALL=C grep -c -x -F -- "RAN $1" "$rigTmp/log" || :
}

echo "-- 1. the runner finds a test in a subfolder of sh-test, and nothing of check-fixtures/ --"
rigRun "$rigTmp/p1" --passed
rigAssert "asked what has passed, it lists the test in sh-test and the one in session/, and no fixture" \
	"$rigRc [$( LC_ALL=C cut -d' ' -f1 "$rigTmp/p1.out" | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )]" "0 [RigSub RigTop ]"
: > "$rigTmp/log"
rigRun "$rigTmp/r1" RigSub
rigAssert "the test in the subfolder is run by its name, and passes" "$rigRc $( LC_ALL=C grep -c '^PASS  RigSub ' "$rigTmp/r1.out" ) $( rigRan RigSub.test.sh )" "0 1 1"
: > "$rigTmp/log"
rigRun "$rigTmp/r2"
rigAssert "a run with no names runs both tests, each once, and never the fixture" \
	"$rigRc $( LC_ALL=C grep -c '^PASS  ' "$rigTmp/r2.out" ) $( rigRan RigTop.test.sh ) $( rigRan RigSub.test.sh ) $( rigRan rig-thing.stub.sh )" "0 2 1 1 0"

echo "-- 2. the retest queue takes the test in the subfolder, and its drain runs it --"
rigCall "$rigTmp/q1" bash "$rigTool" --retest-queue --about rig-copy --by rig-builder --why 'a test in a subfolder, by its name' RigSub
rigId1="$( LC_ALL=C sed -n 1p "$rigTmp/q1.out" )"
rigAssert "by its name: taken, as that test" "$rigRc [$( LC_ALL=C grep -e '^test: ' -e '^file: ' "$rigQueue/waiting/$rigId1.request" 2> /dev/null | LC_ALL=C tr '\n' '|' )]" "0 [test: RigSub|]"
rigCall "$rigTmp/q2" bash "$rigTool" --retest-queue --about rig-copy --by rig-builder --why 'a test in a subfolder, as a changed file' --file sh-test/session/RigSub.test.sh
rigId2="$( LC_ALL=C sed -n 1p "$rigTmp/q2.out" )"
rigAssert "by its path as a changed file: taken as that test, and no file is kept" "$rigRc [$( LC_ALL=C grep -e '^test: ' -e '^file: ' "$rigQueue/waiting/$rigId2.request" 2> /dev/null | LC_ALL=C tr '\n' '|' )]" "0 [test: RigSub|]"
rigCall "$rigTmp/q3" bash "$rigTool" --retest-queue --about rig-copy --by rig-builder --why 'a fixture, as a changed file' --file sh-test/check-fixtures/rig-thing.stub.sh
rigId3="$( LC_ALL=C sed -n 1p "$rigTmp/q3.out" )"
rigAssert "control: a fixture given as a changed file is a file, not a test" "$rigRc [$( LC_ALL=C grep -e '^test: ' -e '^file: ' "$rigQueue/waiting/$rigId3.request" 2> /dev/null | LC_ALL=C tr '\n' '|' )]" "0 [file: sh-test/check-fixtures/rig-thing.stub.sh|]"
: > "$rigTmp/log"
rigCall "$rigTmp/d1" bash "$rigTool" --retest-drain
rigAssert "the drain runs the test in the subfolder for the requests that named it, and never the fixture" \
	"$rigRc $( rigRan RigSub.test.sh ) $( rigRan rig-thing.stub.sh ) $( LC_ALL=C grep -c -F -- "RETEST $rigId2 PASS " "$rigTmp/d1.out" )" "0 1 0 1"

echo "-- 3. the package: nothing but a check ends in .test.sh, and every check has a name of its own --"
rigAssert "no fixture of check-fixtures/ ends in .test.sh: each is named by its type" \
	"$( cd "$rigPackage/sh-test/check-fixtures" && ls | LC_ALL=C grep '\.test\.sh$' | LC_ALL=C tr '\n' ' ' )" ""
rigAssert "control: check-fixtures/ is read, and holds fixtures" "$( ls "$rigPackage/sh-test/check-fixtures" | LC_ALL=C awk 'END { print ( NR >= 10 ) ? "fixtures" : NR }' )" "fixtures"
rigAssert "no two checks of sh-test and its subfolders share a name" \
	"$( cd "$rigPackage/sh-test" && ls *.test.sh */*.test.sh 2> /dev/null | LC_ALL=C sed 's|.*/||' | LC_ALL=C sort | LC_ALL=C uniq -d | LC_ALL=C tr '\n' ' ' )" ""

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ RUN TESTS SUBFOLDER CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'RUN_TESTS_SUBFOLDER: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
