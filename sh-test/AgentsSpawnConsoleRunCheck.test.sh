#!/usr/bin/env bash
## Behavioural check on the async spawn's one console run (AgentsToolsSpawnProxyConsoleRun,
## AgentsTools.InternOpAgentSpawnProxy.include), run rather than read, against a stand-in console: no real CLI is
## started. A NEW PROCESS gets the full brief. A NATIVE RESUME, a review return's restart, gets the old session to
## resume and the corrections alone, under this spawn's own session, thread, conversations and CLI arguments, and is
## recorded on the item as resumed, once, when its first event arrives. One that ends non-zero before its first event
## falls back, once, to a new process on the full brief, recorded with why. One that fails after its first event is
## that run's own failure: its status is returned and nothing is run again. One that marks its first event and ends
## between the watcher's two looks is still recorded as resumed. Every run starts the console of the workspace the
## spawn runs in, with that workspace's member set root. Offline and self-contained: the workspace is a fixture that
## holds only the stand-in console, the item's record is a stand-in that writes one line, and nothing of the team's
## is reached. What the stand-in cannot show: a real CLI resuming a real session.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigSpawnInclude="$rigHere/AgentsTools.InternOpAgentSpawnProxy.include"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigSpawnInclude" ] || rigRefuse "the spawn proxy is not at the origin this workspace resolves: $rigSpawnInclude"
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSpawnConsoleRunCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## A loop in the code under test must end the check rather than hang it: nothing here legitimately runs long.
rigProcNote $$
( sleep 300 ; rigProcSignal TERM $$ ) > /dev/null 2>&1 &
rigDog=$! ; rigProcNote "$rigDog"
trap 'rigProcSignalWithChildren TERM "$rigDog" ; wait "$rigDog" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/temp"
## The stand-in console: one line per start with what it was given, then what its mode says of a resume.
cat > "$rigWs/DistroAgentsConsole.sh" << 'RIGEOF'
#!/usr/bin/env bash
rigIn="$( cat )"
printf 'workspace=%s root=%s session=%s thread=%s conversations=%s resume-from=%s args=[%s] prompt=[%s]\n' \
	"${MMDAPP:-}" "${MDAT_SKILLSET_ROOT:-}" "${MDAT_SESSION_ID:-}" "${MDAT_SESSION_THREAD:-}" "${MDAT_CONVERSATION_THREADS:-}" "${MDAT_SPAWN_RESUME_FROM:-}" "$*" "$rigIn" >> "$RIG_CONSOLE_LOG"
[ -n "${MDAT_SPAWN_RESUME_FROM:-}" ] || exit 0
case "$RIG_CONSOLE_MODE" in
	resumes) : > "$MDAT_SPAWN_RESUME_EVENT_MARKER" ; exit 0 ;;
	ends-early) exit 7 ;;
	fails-late) : > "$MDAT_SPAWN_RESUME_EVENT_MARKER" ; exit 5 ;;
	marks-then-ends) sleep 1 ; : > "$MDAT_SPAWN_RESUME_EVENT_MARKER" ; exit 0 ;;
esac
exit 0
RIGEOF
chmod +x "$rigWs/DistroAgentsConsole.sh"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigConsoleRun(){ ## the console's mode, the session to resume (may be empty), "late" for a watcher whose look at the run comes after the run ended -- one console run in the fixture workspace; rc in rigRc
	local runMode="$1" runFrom="${2:-}" runLate="${3:-}"
	: > "$rigTmp/console.log" ; : > "$rigTmp/records"
	rm -f "$rigWs/.local/temp/rig.launch.resume-event"
	rigRc=0
	(
		set +u
		export MMDAPP="$rigWs" MDSC_CMD=rig RIG_CONSOLE_MODE="$runMode" RIG_CONSOLE_LOG="$rigTmp/console.log" MDAT_SPAWN_SESSION_ID=rig-new MDAT_SPAWN_LAUNCH_MARKER="$rigWs/.local/temp/rig.launch"
		set -- --rig-none
		. "$rigSpawnInclude" 2> /dev/null
		AgentsReviewRecord(){ printf '%s %s %s: %s [%s %s]\n' "$1" "$2" "$3" "$4" "$5" "$6" >> "$rigTmp/records" ; }
		AgentsToolsWorkspaceSkillsetRoot(){ printf '%s/.local/agents/members' "$1" ; }
		## The process of a start is kept on the spawn's record, which this fixture has none of.
		AgentsToolsSpawnProxyRunRecord(){ : ; }
		## The watcher looks for the mark of the first event, then at the run. This stand-in for its
		## look at the run answers only once the run has ended: a run that marked its first event
		## and ended between the two looks.
		[ -z "$runLate" ] || kill(){
			if [ "${1:-}" = "-0" ] ; then
				while builtin kill -0 "$2" 2> /dev/null ; do sleep 0.2 ; done
				return 1
			fi
			builtin kill "$@"
		}
		AgentsToolsSpawnProxyConsoleRun rig-session "C1:2.3" "C9:8.7" RIG-FULL-BRIEF "$runFrom" RIG-CORRECTIONS magic-tester rig-item.md --cli rig-cli --tier rig
	) > "$rigTmp/out" 2> "$rigTmp/err" || rigRc=$?
}
rigStarts(){ ## -- how many times the console was started in the last run
	LC_ALL=C awk 'END { print NR + 0 }' "$rigTmp/console.log"
}
rigStart(){ ## which -- that start of the last run, as the console recorded it
	LC_ALL=C sed -n "${1}p" "$rigTmp/console.log"
}
rigGiven(){ ## the session to resume (may be empty), the prompt -- the line a start is recorded as, when it was given this spawn's own workspace, root, session, thread, conversations and CLI arguments
	printf 'workspace=%s root=%s/.local/agents/members session=rig-session thread=C1:2.3 conversations=C9:8.7 resume-from=%s args=[--cli rig-cli --tier rig --non-interactive] prompt=[%s]' "$rigWs" "$rigWs" "$1" "$2"
}
rigRecords(){ ## -- what the last run recorded on the item, its lines joined by " # "
	LC_ALL=C awk '{ printf "%s%s", ( NR > 1 ? " # " : "" ), $0 }' "$rigTmp/records"
}
rigResumed='magic-tester rig-item.md review: restart: resumed (from rig-old-session) [RESTART rig-new]'

rigConsoleRun resumes ""
[ "$( rigStarts )" = 1 ] || rigRefuse "the console run did not start the stand-in console of the fixture workspace, so no row below would be measured: rc=$rigRc $( head -3 "$rigTmp/err" | tr '\n' ' ' )"

echo "-- 1. a new process: the full brief, under this spawn's own session, thread, conversations and CLI arguments --"
rigAssert "the console of the workspace the spawn runs in is started once, with that workspace's member set root, and given the full brief and no session to resume" "$rigRc $( rigStarts ) $( rigStart 1 )" "0 1 $( rigGiven '' RIG-FULL-BRIEF )"
rigAssert "nothing is recorded on the item: a first start is no restart" "[$( rigRecords )]" "[]"

echo "-- 2. a native resume: the old session and the corrections alone, recorded once when its first event arrives --"
rigConsoleRun resumes rig-old-session
rigAssert "the console is started once, told which session to resume, and given the corrections, not the brief" "$rigRc $( rigStarts ) $( rigStart 1 )" "0 1 $( rigGiven rig-old-session RIG-CORRECTIONS )"
rigAssert "the item's record says it was resumed, and from which session, once" "$( rigRecords )" "$rigResumed"
rigAssert "the mark of the first event is taken away when the run ends" "$( [ -e "$rigWs/.local/temp/rig.launch.resume-event" ] && printf left || printf gone )" gone

echo "-- 3. a resume that ends before its first event falls back, once, to a new process on the full brief --"
rigConsoleRun ends-early rig-old-session
rigAssert "the console is started twice: the resume, then a new process with the full brief and no session to resume" "$rigRc $( rigStarts ) $( rigStart 1 ) | $( rigStart 2 )" "0 2 $( rigGiven rig-old-session RIG-CORRECTIONS ) | $( rigGiven '' RIG-FULL-BRIEF )"
rigAssert "the item's record says a new process was started, and why, once" "$( rigRecords )" 'magic-tester rig-item.md review: restart: new-process (the resume of rig-old-session exited 7 before its first event) [RESTART rig-new]'
rigAssert "and the run says so itself" "$( LC_ALL=C grep -c -F 'the resume of rig-old-session exited 7 before its first event -- starting a new process instead' "$rigTmp/err" || : )" 1

echo "-- 4. a resume that fails after its first event is that run's own failure: nothing is run again --"
rigConsoleRun fails-late rig-old-session
rigAssert "the console is started once and its status is the run's" "$rigRc $( rigStarts ) $( rigStart 1 )" "5 1 $( rigGiven rig-old-session RIG-CORRECTIONS )"
rigAssert "the item's record says it was resumed, once, and names no new process" "$( rigRecords )" "$rigResumed"

echo "-- 5. a resume that marks its first event and ends between the watcher's two looks is still recorded --"
rigConsoleRun marks-then-ends rig-old-session late
rigAssert "the console is started once and ended well" "$rigRc $( rigStarts )" "0 1"
rigAssert "the item's record says it was resumed, once: neither lost between the two looks nor written twice" "$( rigRecords )" "$rigResumed"
if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SPAWN CONSOLE RUN CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_CONSOLE_RUN: OK (%d assertions, offline)\n' "$rigPasses"
