#!/usr/bin/env bash
## Behavioural check on the runner's net under what a test leaves running (sh-test/AgentsRunTests.sh and its slot keeper),
## run rather than read, on a fixture machine built here: a HOME with its own line and worker budget, a workspace, and one
## copy of the package holding the runner under test and tiny tests. Held:
##   1. CONTROL. A test that starts nothing, and one that starts a process and ends it before it ends, both PASS, nothing
##      is named as a leak, and the run's own status is 0. A runner that failed every test is caught here.
##   2. A test that ends leaving a process running FAILS, and the run's own status is a failure.
##   3. It NAMES that process: a `leak-pids:` line holds its pid, and a `leak-pid:` line of its own holds the command line
##      read of that very process. A name is checkable; a count of processes is not.
##   4. The process it left is ended with the test, so a FAIL costs no orphan.
##   5. A test ended at its time limit leaves nothing running either, and the status it is given is the limit's own.
##   6. The guard: no file of sh-test spins a stand-in round a sleep, in a loop that never ends by itself.
##   7. The keeper runs on the python this machine has. It called os.waitid, which /usr/bin/python3 3.9.6 does not have,
##      so every test raised AttributeError and the runner reported FAIL while the test's log said OK.
## Red recipe: before the keeper named what it ended and failed the test for it, sections 2 and 3 report PASS and name
## nothing; with waitid back in the keeper, section 7 reports FAIL where the test's own log says OK.
## Offline: every tree is the rig's own, the line and the budget are under the rig's HOME, and every process this check
## starts is ended by it.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigRunner="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-test/AgentsRunTests.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigRunner" ] || rigRefuse "the runner is not at the origin this workspace resolves: $rigRunner"
[ -f "${MYXROOT:-/usr/local/share/myx.common}/bin/lib/parallel.Common" ] || rigRefuse "myx.common lib/parallel, which the runner runs its tests with, is not at ${MYXROOT:-/usr/local/share/myx.common}"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-blocking-stand-in.include.sh" || rigRefuse "the rig's stand-in helper is missing from the package"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRunTestsLeakCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigHome="$rigTmp/home" rigWs="$rigTmp/ws"
rigPkg="$rigWs/.local/temp/rig-lane/source/myx/myx.distro-agents"
rigLaneDir="$rigHome/.agents/magic-team/suite-lanes"
mkdir -p "$rigHome" "$rigWs/.local/temp" "$rigPkg/sh-test/check-fixtures"
cp "$rigRunner" "$rigPkg/sh-test/AgentsRunTests.sh" || rigRefuse "the runner under test could not be copied into the rig"
cp "$( dirname "$rigRunner" )/check-fixtures"/runner-*.py "$rigPkg/sh-test/check-fixtures/" || rigRefuse "the runner's keepers could not be copied into the rig"

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
## The machine's lanes as this rig's own: a lane count it fixes, and a pace floor so fast that the count is that number
## on any host (the count is the floor over the pace now, capped by the count). Lane 1 is the hand rule's lock, and
## lane.<n> a folder of its own (sh-test/AgentsRunTests.sh, WAITING IN THE LINE).
rigLanes(){ ## number -- how many lanes this rig's machine allows: fixed by the rig, so the count is that number on any host
	mkdir -p "$rigLaneDir" && printf '%s\n' "$1" > "$rigLaneDir/max" && printf '%s\n' "$1" > "$rigLaneDir/count"
}
rigLaneHeld(){ ## -- the pids holding any lane now, whether as lane.<n> or as the hand rule's lock, sorted, on one line
	{ for rigLaneFile in "$rigLaneDir"/lane.*/pid ; do [ -f "$rigLaneFile" ] && LC_ALL=C sed -n 's/^pid=//p' "$rigLaneFile" | LC_ALL=C sed -n 1p ; done
	  LC_ALL=C sed -n 's/^runner-pid: //p' "$rigWs/.local/temp/suite-run.lock/holder.txt" 2> /dev/null | LC_ALL=C sed -n 1p ; } | LC_ALL=C sort | LC_ALL=C tr '\n' ' '
}

## The leaked stand-in: a process in a subshell of its own, so the test's own process ends while it runs, blocked on a
## pipe nobody writes. It costs no wake-up a second, and nothing of the test ends it.
cat > "$rigPkg/sh-test/RigLeaker.test.sh" <<'RIGLEAKER'
#!/usr/bin/env bash
mkfifo "$RIG_SHARED/leak.$RIG_MARK.fifo" 2> /dev/null
( bash -c 'exec 0<"$1" ; IFS= read -r rigLeakLine' "rig-leak-$RIG_MARK" "$RIG_SHARED/leak.$RIG_MARK.fifo" > /dev/null 2>&1 < /dev/null & )
[ -z "${RIG_HOLD:-}" ] || sleep 30
echo "RIG_LEAKER: OK"
RIGLEAKER
## A test that starts one and ends it before it ends: the control, so a runner that failed every test would be caught.
## Its stand-in is let go by a write to the pipe it reads, so this test signals no pid at all.
cat > "$rigPkg/sh-test/RigTidy.test.sh" <<'RIGTIDY'
#!/usr/bin/env bash
mkfifo "$RIG_SHARED/tidy.$RIG_MARK.fifo" 2> /dev/null
bash -c 'exec 0<"$1" ; IFS= read -r rigTidyLine' "rig-tidy-$RIG_MARK" "$RIG_SHARED/tidy.$RIG_MARK.fifo" > /dev/null 2>&1 < /dev/null &
rigTidyPid=$!
exec 9> "$RIG_SHARED/tidy.$RIG_MARK.fifo"
printf 'go\n' >&9
exec 9>&-
wait "$rigTidyPid" 2> /dev/null
echo "RIG_TIDY: OK"
RIGTIDY
## A test that starts nothing at all: the other control.
cat > "$rigPkg/sh-test/RigQuiet.test.sh" <<'RIGQUIET'
#!/usr/bin/env bash
echo "RIG_QUIET: OK"
RIGQUIET
chmod +x "$rigPkg/sh-test"/Rig*.test.sh

rigMark="m$$x$( date +%s )"
rigRc="" rigOut="" rigFolder=""
rigRun(){ ## the runner's own options, then the test names -- its output in rigOut, its status in rigRc, its run folder in rigFolder
	rigRc=0
	rigOut="$( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$rigWs/.local/temp/rig-lane/source" MYXROOT="${MYXROOT:-}" \
		RIG_SHARED="$rigTmp" RIG_MARK="$rigMark" RIG_HOLD="${rigHold:-}" bash "$rigPkg/sh-test/AgentsRunTests.sh" -w 1 "$@" 2>&1 )" || rigRc=$?
	rigFolder="$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^# AgentsRunTests\.sh: .* run folder: //p' | LC_ALL=C sed -n 1p )"
}
rigVerdict(){ ## test name -- PASS or FAIL, the word its summary line starts with
	[ -n "$rigFolder" ] || return 0
	LC_ALL=C awk -v want="$1" '$1 == "PASS" || $1 == "FAIL" { if ( $2 == want ) { print $1 ; exit } }' "$rigFolder/summary.txt" 2> /dev/null
}
rigReceipt(){ ## test name -- the rc its receipt holds
	LC_ALL=C sed -n 's/^rc=//p' "$rigFolder/$1.receipt" 2> /dev/null | LC_ALL=C sed -n 1p
}
rigPidWord(){ ## value -- `pid` where it is a process id, `no-pid` otherwise
	case "$1" in ''|*[!0123456789]*) printf 'no-pid' ;; *) printf 'pid' ;; esac
}
rigNamedPid(){ ## test name -- the first pid on a `leak-pids:` line of its log
	LC_ALL=C sed -n 's/^leak-pids: *//p' "$rigFolder/$1.log" 2> /dev/null | LC_ALL=C awk 'NF { print $1 ; exit }'
}
rigNamedLines(){ ## test name, text -- how many lines of its log hold that text
	LC_ALL=C grep -c -F -e "$2" "$rigFolder/$1.log" 2> /dev/null || :
}
rigAlive(){ ## pid -- `alive` or `gone`; a value that is no pid is `no-pid`
	case "$1" in ''|*[!0123456789]*) printf 'no-pid' ; return 0 ;; esac
	kill -0 "$1" 2> /dev/null && printf alive || printf gone
}
rigLeft(){ ## mark -- the pids of the processes with that mark in their command line, read at this moment, on one line
	ps -A -o pid= -o command= 2> /dev/null | LC_ALL=C awk -v leakMark="$1" 'index( $0, leakMark ) && !index( $0, "awk" ) { printf "%s ", $1 }'
}
rigEndMarked(){ ## mark -- ends what is left of that mark, read at this very moment, and only while it is that same process
	rigBlockingStandInEnd $( rigLeft "$1" )
	return 0
}

echo "-- 1. control: a test that starts nothing, and one that ends what it starts --"
rigHold=""
rigRun -t 60 RigQuiet RigTidy
rigAssert "the quiet test passes" "$( rigVerdict RigQuiet )" PASS
rigAssert "the tidy test passes, and the run's own status is 0 with it" "$( rigVerdict RigTidy ):$rigRc" "PASS:0"
rigAssert "and neither is named as a leak" "$( rigNamedLines RigQuiet 'leak-pid' )$( rigNamedLines RigTidy 'leak-pid' )" "00"

echo "-- 2. a test that ends leaving a process running fails --"
rigRun -t 60 RigLeaker
rigAssert "the leaker fails" "$( rigVerdict RigLeaker )" FAIL
rigAssert "and the run's own status is a failure" "$rigRc" 1
rigAssert "its receipt carries a status that is no pass" "$( rigReceipt RigLeaker )" 1
rigAssert "control: the test itself said it was well, so the FAIL is the leak and nothing else" "$( rigNamedLines RigLeaker 'RIG_LEAKER: OK' )" 1

echo "-- 3. and the run names the process it left: its pid, and the command line of that very process --"
rigLeakPid="$( rigNamedPid RigLeaker )"
rigAssert "a leak-pids line names a pid" "$( rigPidWord "$rigLeakPid" )" pid
rigAssert "a leak-pid line holds that pid's own command line, the marker included" \
	"$( LC_ALL=C grep -c -E "^leak-pid: $rigLeakPid .*rig-leak-$rigMark" "$rigFolder/RigLeaker.log" 2> /dev/null || : )" 1

echo "-- 4. what it left is ended with the test: a FAIL costs no orphan --"
rigAssert "the pid the run named is gone" "$( rigAlive "$rigLeakPid" )" gone
rigAssert "and no process of that mark is left running" "$( rigLeft "rig-leak-$rigMark" )" ""

echo "-- 5. a test ended at its time limit: it fails for the limit, and leaves nothing running either --"
rigHold=1
rigRun -t 3 RigLeaker
rigAssert "the timed-out leaker fails" "$( rigVerdict RigLeaker )" FAIL
rigAssert "with the status a time limit gives, not the one a leak gives" "$( rigReceipt RigLeaker )" 142
rigAssert "and no process of that mark is left running" "$( rigLeft "rig-leak-$rigMark" )" ""
rigHold=""
rigEndMarked "rig-leak-$rigMark" ; rigEndMarked "rig-tidy-$rigMark"

echo "-- 6. the guard: no file of sh-test spins a stand-in round a sleep, in a loop that never ends by itself --"
## A stand-in that waits by polling a bare loop costs a wake-up a second for as long as it lives, and it lives past its
## check whenever the check is killed. It blocks on a pipe instead (check-fixtures/rig-blocking-stand-in.include.sh). This
## is the guard over that: the four checks that forked 32 such spinners, some 18 hours old, read `while : ; do sleep 1 ; done`.
## A bounded poll, `while [ ... ] && [ "$left" -gt 0 ] ; do sleep ...`, is no stand-in and is not what this reads.
## IT READS THE LOOP'S WHOLE BODY (S12.8). The pattern this replaces read the opening line alone, and so saw only a loop
## whose `do` and its `sleep` share that line. A spinner written the way anyone writes one -- `while : ; do`, then
## `:` or a bare wait, then `sleep 1`, then `done` -- is the same spinner and went unseen. A loop is flagged when its
## body holds nothing but waits: every line of it is blank, a comment, a bare `:`, a `sleep` or a nested `do`/`done`.
rigSpinAwk='
	{ line[NR] = $0 }
	END {
		for ( n = 1 ; n <= NR ; n++ ) {
			if ( line[n] ~ /^[[:space:]]*#/ ) continue
			if ( !match( line[n], /^[[:space:]]*(while[[:space:]]*(:[[:space:]]*;|true[[:space:]]*;)|until[[:space:]]+false[[:space:]]*;)[[:space:]]*do/ ) ) continue
			closed = 0 ; body = substr( line[n], RLENGTH + 1 )
			if ( match( body, /done[[:space:]]*;?[[:space:]]*$/ ) ) {
				body = substr( body, 1, RSTART - 1 ) ; closed = n
			} else {
				depth = 1
				for ( m = n + 1 ; m <= NR ; m++ ) {
					if ( line[m] ~ /^[[:space:]]*#/ ) continue
					if ( line[m] ~ /(^|[[:space:]])(while|until)[[:space:]]/ && line[m] ~ /do[[:space:]]*;?[[:space:]]*$/ ) depth++
					if ( line[m] ~ /^[[:space:]]*done([[:space:]]|;|$)/ ) { depth-- ; if ( depth == 0 ) { closed = m ; break ; } ; continue }
					body = body line[m] "\n"
				}
			}
			if ( !closed ) continue
			waitsOnly = 1
			nbody = split( body, rows, /[;\n]/ )
			for ( i = 1 ; i <= nbody ; i++ ) {
				one = rows[i]
				if ( one ~ /^[[:space:]]*$/ ) continue
				if ( one ~ /^[[:space:]]*#/ ) continue
				if ( one ~ /^[[:space:]]*:[[:space:]]*$/ ) continue
				if ( one ~ /^[[:space:]]*sleep[[:space:]]/ ) continue
				waitsOnly = 0 ; break
			}
			if ( waitsOnly ) printf "%d\t%s\n", n, line[n]
		}
	}'
rigSpin(){ ## -- each unbounded spinning loop of sh-test, in code and not in a comment, as <file>:<line>, on one line
	( cd "$rigShTest" && find . -type f -name '*.sh' | LC_ALL=C sort ) | while IFS= read -r rigOne ; do
		[ "$rigOne" != "./common/AgentsRunTestsLeakCheck.test.sh" ] || continue
		LC_ALL=C awk "$rigSpinAwk" "$rigShTest/$rigOne" 2> /dev/null | LC_ALL=C sed "s|^|${rigOne#./}:|"
	done
}
rigShTest="$( cd "$( dirname "$rigRunner" )" && pwd -P )"
rigAssert "no file of sh-test waits in a spinning loop: a stand-in blocks on a pipe, which costs nothing and ends with its check" \
	"$( rigSpin | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )" ""
## Both directions: a loop whose body is only waits is flagged, however it is laid out, and a bounded poll is not.
printf '%s\n' \
	'while : ; do sleep 1 ; done' \
	'while : ; do' \
	'sleep 1' \
	'done' \
	'while true ; do' \
	': ' \
	'sleep 1' \
	'done' \
	'while [ "$left" -gt 0 ] ; do' \
	'sleep 1' \
	'left=$(( left - 1 ))' \
	'done' \
	'while : ; do' \
	'rigPoll=$( rigProbe )' \
	'sleep 1' \
	'done' \
	'## a comment: while : ; do sleep 1 ; done' \
	> "$rigTmp/spin.sh"
rigAssert "control: the guard flags a bare-wait loop in either layout, and neither a bounded poll nor a polling loop nor a comment" \
	"$( LC_ALL=C awk "$rigSpinAwk" "$rigTmp/spin.sh" | LC_ALL=C awk -F'\t' '{ printf "%s ", $1 }' | LC_ALL=C sed 's/ $//' )" "1 2 5"

echo "-- 7. the keeper runs on the python this machine has, not only on the one on PATH --"
## The fault this pins, 2026-11-03: the keeper called os.waitid, which the machine's /usr/bin/python3 (3.9.6) does not have.
## Every test then raised AttributeError, and the runner reported FAIL while the test's own log said OK. The keeper now
## reads an ended and unreaped leader from the process table, which needs no waitid, no WNOWAIT and no python 3.10.
rigPyOldly=""
for rigPy in /usr/bin/python3 /usr/local/bin/python3 ; do
	[ -x "$rigPy" ] || continue
	"$rigPy" -c 'import sys ; sys.exit( 0 if sys.version_info < (3, 10) else 1 )' 2> /dev/null && { rigPyOldly="$rigPy" ; break ; }
done
rigAssert "control: this machine has a python older than 3.10, so the portability below is measured and not assumed" \
	"$([ -n "$rigPyOldly" ] && printf found || printf none)" found
rigAssert "the keeper calls no waitid, and no WNOWAIT either: neither is on every python this estate runs" \
	"$( LC_ALL=C grep -v '^[[:space:]]*#' "$rigPkg/sh-test/check-fixtures/runner-slot-keeper.py" | LC_ALL=C grep -c -e 'os\.waitid' -e 'WNOWAIT' )" 0
rigPyPath="$rigPyOldly:/usr/bin:/bin:/usr/sbin:/sbin"
rigPyRc=0
rigPyOut="$( cd "$rigWs" && env -i HOME="$rigHome" PATH="$rigPyPath" MMDAPP="$rigWs" MDLT_ORIGIN="$rigWs/.local/temp/rig-lane/source" MYXROOT="${MYXROOT:-}" \
	RIG_SHARED="$rigTmp" RIG_MARK="$rigMark" bash "$rigPkg/sh-test/AgentsRunTests.sh" -w 1 -t 60 RigQuiet 2>&1 )" || rigPyRc=$?
rigPyFolder="$( printf '%s\n' "$rigPyOut" | LC_ALL=C sed -n 's/^# AgentsRunTests\.sh: .* run folder: //p' | LC_ALL=C sed -n 1p )"
rigAssert "a passing test reports PASS under that python, with the run's own status 0" \
	"$( printf '%s\n' "$rigPyOut" | LC_ALL=C awk '$1 == "PASS" && $2 == "RigQuiet" { n++ } END { print n + 0 }' ):$rigPyRc" "1:0"
rigAssert "and no traceback of the keeper is in its log" \
	"$( LC_ALL=C grep -c 'Traceback' "${rigPyFolder:-/nonexistent}/RigQuiet.log" 2> /dev/null || : )" 0

echo "-- 8. a lane is given back when the run ends, however the run ends --"
## The lanes put more than one run's tests on the machine at once, so a lane left held is a run that can never start.
## An ended run's lane is given back by itself; a run killed outright leaves its lane file, and the next run to ask
## takes it, exactly as a worker slot or a ticket of the line is taken back.
rigLanes 2
rigHold=""
rigRun -t 60 RigQuiet
rigAssert "a run that ends by itself leaves no lane held, and no lane folder behind" "$rigRc $( rigLaneHeld )|$( ls "$rigLaneDir" 2> /dev/null | LC_ALL=C grep -c '^lane\.' )" "0 |0"
## A lane whose holder is gone is given back by whoever asks for a lane next, so a run killed outright holds nothing.
mkdir -p "$rigLaneDir/lane.2"
rigDeadPid="$( ( exit 0 ) & printf '%s' "$!" ; wait 2> /dev/null )"
printf 'pid=%s\nrunner-pid: %s\n' "$rigDeadPid" "$rigDeadPid" > "$rigLaneDir/lane.2/pid"
rigRun -t 60 RigQuiet
rigAssert "a lane listed for a process that no longer exists: the run takes a lane at once, says nothing of waiting, and runs" \
	"$rigRc $( LC_ALL=C grep -c 'waits its turn' <<< "$rigOut" || : ) $( rigVerdict RigQuiet )" "0 0 PASS"
rigAssert "and the stale lane is gone: a dead run holds no lane" "$( ls "$rigLaneDir" 2> /dev/null | LC_ALL=C grep -c '^lane\.' )" 0
## A test that measures its own timing takes every lane, so nothing of another run is busy beside it. Declared in its
## header alone, and the run of it leaves every lane free again. Lane 1 is the hand rule's lock, so what it found held
## for it is that lock plus every `lane.<n>` folder beside it.
cat > "$rigPkg/sh-test/RigTimed.test.sh" <<'RIGTIMED'
#!/usr/bin/env bash
## lane: alone
rigTimedFirst=0
LC_ALL=C grep -q '^runner-pid: ' "$MMDAPP/.local/temp/suite-run.lock/holder.txt" 2> /dev/null && rigTimedFirst=1
rigTimedRest="$( ls "$HOME/.agents/magic-team/suite-lanes" 2> /dev/null | LC_ALL=C grep -c '^lane\.' )"
case "$rigTimedRest" in ''|*[!0123456789]*) rigTimedRest=0 ;; esac
printf 'TIMED_LANES %s\n' "$(( rigTimedFirst + rigTimedRest ))" >> "$RIG_SHARED/timed"
echo "RIG_TIMED: OK"
RIGTIMED
chmod +x "$rigPkg/sh-test/RigTimed.test.sh"
rigLanes 3
: > "$rigTmp/timed"
rigRun -t 60 RigTimed
rigAssert "a test whose header says it measures its own timing takes every one of the machine's lanes" \
	"$( LC_ALL=C sed -n 's/^TIMED_LANES //p' "$rigTmp/timed" 2> /dev/null | LC_ALL=C sed -n 1p ) $( rigVerdict RigTimed )" "3 PASS"
rigAssert "and every lane is given back when it ends" "$( rigLaneHeld )" ""
rigLanes 1
: > "$rigTmp/timed"
rigRun -t 60 RigTimed
rigAssert "with one lane the machine is as it was: the alone test takes that one lane, and runs" \
	"$( LC_ALL=C sed -n 's/^TIMED_LANES //p' "$rigTmp/timed" 2> /dev/null | LC_ALL=C sed -n 1p ) $( rigVerdict RigTimed )" "1 PASS"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ RUN TESTS LEAK CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'RUN_TESTS_LEAK: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
