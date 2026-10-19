#!/usr/bin/env bash
## Behavioural check on the signals one request of the myx.distro MCP server sends
## (sh-lib/mcp/AgentsTools.InternMcpRequest.include), each run rather than read: the watchdog of a call that is waited
## for, a served harness tool or a script of `execute` (AgentsMcpCallWatch), and the kill action of a background
## job. Each ends a process group by its number, `kill -- -<pid>`, and a pid is a number the system gives again:
## the watchdog wakes at its bound, up to hours after it was started, and where its handler was ended hard nobody
## stops it before; the kill action reads its pid from a file of any age. As a group the number is every process
## of whoever leads a group of that number then.
## Drives a real `--intern-mcp-server --run` over stdio on a copy of the origin whose harness is a stand-in that
## stays as the scenario says, with the rig's own process list for the one reading a process is kept by (its pid,
## its state, when it began) and the rig's own clock (the 3600 seconds of a served call pass in three, the five
## between the polite end and the hard one in three). Held here:
##   1. THE GROUP OF A KEPT PROCESS (myx.distro-.local/sh-lib/registry/AgentsTools.Registries.include), on stand-in groups of this check's
##      own: AgentsToolsRegistryGroupBegan gives the members of a group only while its leader is still the process
##      that was kept, and nothing for the same number begun at another time or kept with no start;
##      AgentsToolsRegistryGroupLeft gives, once the leader has ended, the kept members that are still themselves
##      and what those started since, and nothing of a kept pid another process has taken.
##   2. THE WATCHDOG. A call that comes back is answered as before. A call that hangs is ended at its bound and its
##      caller told that it timed out, served and `execute` alike. THE NUMBER TAKEN BY ANOTHER PROCESS IS NOT
##      SIGNALLED: where the process list says at the bound that the pid began at another time than the call did,
##      nothing is signalled, no timeout is said, and the process that has the number runs to its own end (in the
##      rig it is the call itself, so that a watchdog that did signal it ends nothing of anyone's). A call that
##      ignores the polite end is ended by the hard one, as a group, while its leader is still itself. A watchdog
##      whose handler was ended hard still ends its call; a member of the group that ignored the polite end, the
##      leader gone, is ended by the hard one, by its own pid. THE GROUP'S NUMBER TAKEN BETWEEN THE TWO ENDS IS NOT
##      SIGNALLED: neither as a group nor any kept member that began at another time.
##      ONCE A WATCHDOG HAS FIRED IT IS LEFT TO FINISH, its handler alive: the handler collects the leader the
##      polite end ended and answers at once, with what is known then (the call was asked to end, and whatever of
##      it is left is killed five seconds after); a member of the group that ignored the polite end, and the
##      leader's own child that did, still run when the answer is out, and are ended by the hard one, by their own
##      pids. A WATCHDOG THAT HAS NOT FIRED IS ENDED WITH ITS CALL: when a call that came back in time is answered,
##      nothing of its watchdog is left.
##      THE QUESTION WHETHER CHECKLIST IS OFFERED, which a server asks the harness once before its floor, is
##      bounded as a call is: not answered in time, it is ended at its bound, the request is answered, and
##      CheckList is not served; nothing is kept, so the next request asks again, and an answer in time serves it.
##   3. THE KILL ACTION OF A JOB. The pid file of a job holds `<pid> <start>`. A running job is polled, and
##      killed as a group. A job whose number another process has taken reads as finished and nothing is
##      signalled. A pid file with no start, as jobs were kept before, is not signalled by the number alone: the
##      caller is told so, as an error. A Monitor job is still ended at its deadline.
## Red: with the watchdog and the kill action as they were (a probe of the number, then the group signalled), the
## taken numbers of 2 and 3 are signalled: the processes that have them are ended, and a timeout is said. With a
## handler that ends its watchdog whether that has fired or not, what ignored the polite end runs to its own end
## while its caller is told that it was killed.
## With the question whether CheckList is offered unbounded, a harness that does not answer it holds the
## request, and its late answer serves CheckList.
## Offline: one mktemp tree, the watched processes lines of shell that wait, no endpoint and no console started.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigSource="${MDLT_ORIGIN:=$MMDAPP/.local}"
rigPackage="$rigSource/myx/myx.distro-agents"
rigInclude="$rigPackage/sh-lib/mcp/AgentsTools.InternMcpRequest.include"
rigRegistries="$rigPackage/../myx.distro-.local/sh-lib/registry/AgentsTools.Registries.include"
rigHelper="$rigPackage/sh-test/check-fixtures/rig-processes.include.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigInclude" "$rigRegistries" "$rigHelper" "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
. "$rigHelper" || rigRefuse "the rig's process helper could not be read: $rigHelper"
rigRealSleep="$( command -v sleep )" || rigRefuse "no sleep on PATH to hand the other waits to"
rigRealPs="$( command -v ps )" || rigRefuse "no ps on PATH to hand the other calls to"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsMcpCallWatchdogCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## Every stand-in this check started itself is ended at its end, only while it is still itself. The stand-ins the
## servers of the rig start end by themselves, within the seconds their scenario gives them.
rigStandIns=""
trap 'rigProcSignal KILL $rigStandIns ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigTmp/skills/magic-coordinator" "$rigTmp/origin/myx/myx.distro-agents"
printf 'rig\n' > "$rigTmp/skills/magic-coordinator/magic-coordinator.basic.md"

## The origin of the rig: the one this workspace resolves, with sh-lib copied so that the harness is the rig's.
for rigEntry in "$rigSource"/* ; do
	[ "${rigEntry##*/}" = myx ] || ln -s "$rigEntry" "$rigTmp/origin/${rigEntry##*/}"
done
for rigEntry in "$rigSource"/myx/* ; do
	[ "${rigEntry##*/}" = myx.distro-agents ] || ln -s "$rigEntry" "$rigTmp/origin/myx/${rigEntry##*/}"
done
for rigEntry in "$rigPackage"/* ; do
	if [ "${rigEntry##*/}" = sh-lib ] ; then
		cp -R "$rigEntry" "$rigTmp/origin/myx/myx.distro-agents/sh-lib" || rigRefuse "sh-lib could not be copied"
	else
		ln -s "$rigEntry" "$rigTmp/origin/myx/myx.distro-agents/${rigEntry##*/}"
	fi
done
rigTool="$rigTmp/origin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

## THE STAND-IN FOR THE HARNESS: one served call. It names itself and the handler that started it (the process
## above the shell it runs under), stays for the seconds given, says that it came to its own end, and answers.
## With RIG_CALL=deaf-member it first leaves a member of its group that ignores the polite end; with
## RIG_CALL=deaf-harness it ignores the polite end itself, the leader's own child, and so does what it starts.
## The one question a server asks the harness before its floor, whether CheckList is offered there
## (--intern-checklist-place), is no served call: it is answered at once, as the harness answers where a list has
## no place, and leaves none of the scenario's marks.
## With RIG_CALL=place-hangs it stays for the seconds given first, as a harness that does not answer it, says
## that it came to its own end, and then names a place. Asked again, it names the place at once.
cat > "$rigTmp/origin/myx/myx.distro-agents/sh-lib/harness/AgentsUniversalHarness.sh" <<'RIGHARNESS'
#!/usr/bin/env bash
[ "${1:-}/${RIG_CALL:-}" != --intern-checklist-place/place-hangs ] || { [ -e "$RIG_DIR/place.pid" ] || { sleep "$RIG_STAYS" & echo "$!" > "$RIG_DIR/place.pid" ; wait "$!" ; : > "$RIG_DIR/place.ended" ; } ; echo "CHECKLIST-PLACE: $RIG_DIR" ; exit 0 ; }
[ "${1:-}" != --intern-checklist-place ] || { echo "ERROR: the rig keeps no checklist" ; exit 0 ; }
[ "${RIG_CALL:-}" != deaf-harness ] || trap '' TERM
cat > /dev/null
echo "$$" > "$RIG_DIR/harness.pid"
rigHandler="$( ps -o ppid= -p "$PPID" 2> /dev/null | tr -d ' ' )"
ps -o args= -p "$rigHandler" > "$RIG_DIR/handler.args" 2> /dev/null
printf '%s\n' "$rigHandler" > "$RIG_DIR/handler.pid.new" && mv "$RIG_DIR/handler.pid.new" "$RIG_DIR/handler.pid"
if [ "${RIG_CALL:-}" = deaf-member ] ; then
	bash -c 'trap "" TERM ; echo "$$" > "$RIG_DIR/deaf.pid" ; sleep "$RIG_STAYS" ; : > "$RIG_DIR/deaf.ended"' > /dev/null 2>&1 &
fi
sleep "$RIG_STAYS" &
echo "$!" > "$RIG_DIR/watched.pid"
wait "$!"
: > "$RIG_DIR/watched.ended"
echo "RIG-TOOL-OUTPUT"
RIGHARNESS
## THE RIG'S CLOCK: the bound of a served call passes in RIG_WATCH_SECONDS, the five seconds before a hard end in
## RIG_GRACE_SECONDS; every other wait is the host's. The two waits of a watchdog say which processes they are:
## the one for its bound (3600 seconds, or RIG_WATCH_VALUE, the timeout of the scenario's script) in watch.pid,
## the one before its hard end in grace.pid.
cat > "$rigTmp/bin/sleep" <<'RIGSLEEP'
#!/bin/sh
[ "${1:-}" != "${RIG_WATCH_VALUE:-3600}" ] || echo "$$" > "$RIG_DIR/watch.pid"
[ "${1:-}" != 5 ] || echo "$$" > "$RIG_DIR/grace.pid"
[ "${1:-}" != 3600 ] || exec "$RIG_REAL_SLEEP" "$RIG_WATCH_SECONDS"
[ "${1:-}" != 5 ] || exec "$RIG_REAL_SLEEP" "$RIG_GRACE_SECONDS"
exec "$RIG_REAL_SLEEP" "$@"
RIGSLEEP
## THE RIG'S OWN PROCESS LIST, for the one reading a process is kept by. Each such reading of a scenario is
## counted. RIG_PS=taken: the first is the host's own, and every later one says that the same pids began at
## another time, as they read once their numbers have been given to other processes; RIG_PS=taken-late: the
## first two are the host's own. The same from the moment the scenario's folder holds ps.lie. Every other call,
## and every reading with RIG_PS=host and no such file, is the host's ps.
## A reading made before the server has its answer whether CheckList is offered is that question's own
## watchdog's: the host's, and not counted. From the first reading after it, every one is counted, the server's
## scratch root gone or not (ps.counting).
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case "$*" in
	*lstart=*)
		if [ ! -e "$RIG_DIR/ps.counting" ] ; then
			for rigOffered in "$RIG_DIR"/ws/.local/temp/agent-mcp.*/checklist.offered ; do : ; done
			[ -e "$rigOffered" ] || exec "$RIG_REAL_PS" "$@"
			: > "$RIG_DIR/ps.counting"
		fi
		echo reading >> "$RIG_DIR/ps.readings"
		case "${RIG_PS:-host}" in taken) rigOwn=1 ;; taken-late) rigOwn=2 ;; *) rigOwn="" ;; esac
		if [ -e "$RIG_DIR/ps.lie" ] || { [ -n "$rigOwn" ] && [ "$( grep -c . "$RIG_DIR/ps.readings" )" -gt "$rigOwn" ] ; } ; then
			"$RIG_REAL_PS" "$@" | sed 's/[0-9][0-9][0-9][0-9] *$/2001/'
			exit 0
		fi
	;;
esac
exec "$RIG_REAL_PS" "$@"
RIGPS
chmod +x "$rigTmp/bin/sleep" "$rigTmp/bin/ps" "$rigTmp/origin/myx/myx.distro-agents/sh-lib/harness/AgentsUniversalHarness.sh"

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigCode(){ LC_ALL=C grep -v '^[[:space:]]*#' "$1" ; } ## file -- its lines that are no comment
rigWaitFile(){ ## file -- waits, ten seconds at most, for it to hold something
	local fileTurns=50
	while [ ! -s "$1" ] && [ "$fileTurns" -gt 0 ] ; do "$rigRealSleep" 0.2 ; fileTurns=$(( fileTurns - 1 )) ; done
	[ -s "$1" ]
}
## What became of a watched process of a scenario, once it is settled: it came to its own end (its mark is
## there), or it is no process any more without that mark. Waits for either, forty seconds at most.
rigBecame(){ ## scenario, name of the process (watched, deaf, job)
	local becameTurns=200 becamePid=""
	while [ "$becameTurns" -gt 0 ] ; do
		[ ! -e "$rigTmp/$1/$2.ended" ] || { printf 'ended-by-itself' ; return 0 ; }
		[ -n "$becamePid" ] || becamePid="$( cat "$rigTmp/$1/$2.pid" 2> /dev/null )"
		if [ -n "$becamePid" ] && ! kill -0 "$becamePid" 2> /dev/null ; then
			"$rigRealSleep" 0.3
			[ ! -e "$rigTmp/$1/$2.ended" ] || { printf 'ended-by-itself' ; return 0 ; }
			printf 'ended-before-its-time' ; return 0
		fi
		"$rigRealSleep" 0.2 ; becameTurns=$(( becameTurns - 1 ))
	done
	[ -n "$becamePid" ] && printf 'still-there' || printf 'never-began'
}
rigReply(){ ## scenario, request id -- the line of the wire that answers it
	LC_ALL=C grep "\"id\":$2," "$rigTmp/$1/wire" 2> /dev/null | head -1
}
rigSaid(){ ## scenario, request id, fixed text -- how many times its answer holds it
	rigReply "$1" "$2" | LC_ALL=C grep -c -F -- "$3" || :
}
rigIsError(){ ## scenario, request id
	rigReply "$1" "$2" | LC_ALL=C sed -n 's/.*"isError":\([a-z]*\).*/\1/p'
}
rigReadings(){ ## scenario -- how many times the process list was asked when a process began
	LC_ALL=C grep -c . "$rigTmp/$1/ps.readings" 2> /dev/null || :
}

echo "-- 1. the group of a kept process: its members while the leader is itself, what is left once it has ended --"
## A group of this check's own: its leader waits, one member sleeps, one waits on a pipe and starts a process of
## its own once the pipe is written to.
mkfifo "$rigTmp/group.pipe" || rigRefuse "no pipe for the stand-in group"
set -m
bash -c 'sleep 300 & bash -c "read rigLine < \"\$1\" ; sleep 300 ; :" rig-member "$1" & wait' rig-leader "$rigTmp/group.pipe" > /dev/null 2>&1 < /dev/null &
rigLead=$!
set +m
rigProcNote "$rigLead" ; rigStandIns="$rigStandIns $rigLead"
rigGroupTurns=50
while [ "$( "$rigRealPs" -A -o pid=,pgid= | LC_ALL=C awk -v wantGroup="$rigLead" '$2 == wantGroup' | wc -l | LC_ALL=C tr -d ' ' )" -lt 3 ] && [ "$rigGroupTurns" -gt 0 ] ; do "$rigRealSleep" 0.2 ; rigGroupTurns=$(( rigGroupTurns - 1 )) ; done
rigGroupNow="$( "$rigRealPs" -A -o pid=,pgid= | LC_ALL=C awk -v wantGroup="$rigLead" '$2 == wantGroup { print $1 ; }' )"
rigProcNote $rigGroupNow ; rigStandIns="$rigStandIns $rigGroupNow"
[ "$( printf '%s\n' "$rigGroupNow" | wc -l | LC_ALL=C tr -d ' ' )" = 3 ] || rigRefuse "the stand-in group did not come up with its three processes, so nothing below would be measured"
rigGroup(){ ## the tooling's function, then its arguments -- in a shell of its own, as the helper reads a start
	( set +u ; . "$rigRegistries" > /dev/null 2>&1 ; "$@" )
}
rigLeadKept="$( rigProcBegan "$rigLead" )"
rigMembers="$( rigGroup AgentsToolsRegistryGroupBegan "$rigLeadKept" )" ; rigRc=$?
rigAssert "while the leader is still the process that was kept, the members of its group are given, each with when it began: rc 0, the three of them, the leader among them" \
	"$rigRc $( printf '%s\n' "$rigMembers" | LC_ALL=C grep -c -E '^[0-9]+ [A-Z][a-z]{2}_[A-Z][a-z]{2}_[0-9]{1,2}_[0-9:]{8}_[0-9]{4}$' ) $( printf '%s\n' "$rigMembers" | LC_ALL=C grep -c -x -F -- "$rigLeadKept" )" "0 3 1"
rigTaken="$( rigGroup AgentsToolsRegistryGroupBegan "$rigLead Mon_Jan__1_00:00:00_2001" )" ; rigRc=$?
rigBare="$( rigGroup AgentsToolsRegistryGroupBegan "$rigLead" )" ; rigRcBare=$?
rigAssert "the same number kept with another start, as once another process has taken it, and one kept with no start, lead no group of the caller's: rc 1, nothing given" "$rigRc [$rigTaken] $rigRcBare [$rigBare]" "1 [] 1 []"
rigAssert "control: while the leader lives nothing is left of the group but itself: the three" "$( rigGroup AgentsToolsRegistryGroupLeft "$rigLead" "$rigMembers" | LC_ALL=C grep -c . )" 3
rigProcSignal KILL "$rigLead" ; wait "$rigLead" 2> /dev/null
rigGone="$( rigGroup AgentsToolsRegistryGroupBegan "$rigLeadKept" )" ; rigRc=$?
rigAssert "once the leader has ended the group of its number is nobody's: rc 1, nothing given" "$rigRc [$rigGone]" "1 []"
rigAssert "what is left of it is the two members that are still themselves" "$( rigGroup AgentsToolsRegistryGroupLeft "$rigLead" "$rigMembers" | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "$( printf '%s\n' "$rigMembers" | LC_ALL=C awk -v leadPid="$rigLead" '$1 != leadPid { print $1 ; }' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )"
: > "$rigTmp/group.pipe"
rigLeftTurns=50
while [ "$( rigGroup AgentsToolsRegistryGroupLeft "$rigLead" "$rigMembers" | LC_ALL=C grep -c . )" -lt 3 ] && [ "$rigLeftTurns" -gt 0 ] ; do "$rigRealSleep" 0.2 ; rigLeftTurns=$(( rigLeftTurns - 1 )) ; done
rigLeft="$( rigGroup AgentsToolsRegistryGroupLeft "$rigLead" "$rigMembers" )"
rigProcNote $rigLeft ; rigStandIns="$rigStandIns $rigLeft"
rigAssert "a process a kept member started since is left of the group too: three, one of them no kept member" \
	"$( printf '%s\n' "$rigLeft" | LC_ALL=C grep -c . ) $( { printf '%s\n' "$rigMembers" | LC_ALL=C awk '{ print $1 ; }' ; printf '=\n%s\n' "$rigLeft" ; } | LC_ALL=C awk '$0 == "=" { leftRead = 1 ; next ; } ! leftRead { wasKept[$0] = 1 ; next ; } ! ( $0 in wasKept ) { notKept++ ; } END { print notKept + 0 ; }' )" "3 1"
rigAssert "kept pids that other processes have taken, each begun at another time, are none of it, and nothing they started is" \
	"[$( rigGroup AgentsToolsRegistryGroupLeft "$rigLead" "$( printf '%s\n' "$rigMembers" | LC_ALL=C sed 's/_[0-9]*$/_2001/' )" )]" "[]"
rigProcSignal KILL $rigLeft

## ONE LIFE OF A SERVER OF THE RIG: what the feeder writes is its wire in, what it answers is kept in wire.
rigServe(){ ## scenario, process list (host, taken, taken-late), call of the stand-in harness, seconds it stays, deaf to the polite end or empty, seconds the bound of a served call passes in, the bound as the watchdog is given it (3600, or the timeout of the script), the feeder, its arguments
	local serveDir="$rigTmp/$1" servePs="$2" serveCall="$3" serveStays="$4" serveDeaf="$5" serveWatch="$6" serveValue="$7" serveFeeder="$8"
	shift 8
	mkdir -p "$serveDir/ws/.local/temp"
	"$serveFeeder" "$serveDir" "$@" | (
		unset MDAT_MCP_SERVED_MARKER MDAT_SPAWN_AGENT MDAT_SPAWN_SESSION_ID MDAT_HARNESS_WAIT_TIMEOUT CLAUDE_CODE_ENTRYPOINT
		cd "$serveDir/ws" || exit 1
		export RIG_DIR="$serveDir" RIG_PS="$servePs" RIG_CALL="$serveCall" RIG_STAYS="$serveStays" RIG_REAL_SLEEP="$rigRealSleep" RIG_REAL_PS="$rigRealPs" RIG_WATCH_SECONDS="$serveWatch" RIG_WATCH_VALUE="$serveValue" RIG_GRACE_SECONDS=3
		## deaf: the polite end is ignored by the server and by everything it starts, the call among it
		[ -z "$serveDeaf" ] || trap '' TERM
		PATH="$rigTmp/bin:$PATH" HOME="$rigTmp/home" MMDAPP="$serveDir/ws" MDLT_ORIGIN="$rigTmp/origin" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
			exec bash "$rigTool" --intern-mcp-server --run > "$serveDir/wire" 2> "$serveDir/err"
	)
}
rigInit(){
	printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
}
## The feeders. One request and no more.
rigFeedOne(){ ## scenario folder, the request
	rigInit ; printf '%s\n' "$2"
}
## One request, and at the moment its answer is on the wire, which processes of the scenario still run: the member
## that ignores the polite end, the harness, the watched process, and the two waits of the watchdog.
rigFeedAnswer(){ ## scenario folder, the request
	local answerTurns=250 answerName answerPid
	rigInit ; printf '%s\n' "$2"
	while ! LC_ALL=C grep -q '"id":2,' "$1/wire" 2> /dev/null && [ "$answerTurns" -gt 0 ] ; do "$rigRealSleep" 0.2 ; answerTurns=$(( answerTurns - 1 )) ; done
	LC_ALL=C grep -q '"id":2,' "$1/wire" 2> /dev/null || return 0
	for answerName in deaf harness watched watch grace ; do
		answerPid="$( cat "$1/$answerName.pid" 2> /dev/null )"
		if [ -z "$answerPid" ] ; then echo none ; elif kill -0 "$answerPid" 2> /dev/null ; then echo runs ; else echo gone ; fi > "$1/$answerName.at-answer"
	done
}
## One request, and its handler ended hard once the call runs: the watchdog is then alone with a number.
rigFeedOrphan(){ ## scenario folder, the request
	rigInit ; printf '%s\n' "$2"
	rigWaitFile "$1/handler.pid" || return 0
	rigProcNote "$( cat "$1/handler.pid" )" > /dev/null 2>&1
	rigProcSignal KILL "$( cat "$1/handler.pid" )" > /dev/null 2>&1 && : > "$1/handler.ended-hard"
}
## A background job started, polled, and killed; before the kill its pid file is left as it was kept, or its
## number is taken (the process list says from then that it began at another time), or the file is made to hold
## the pid alone, as jobs were kept before start times were.
rigFeedJob(){ ## scenario folder, kept or taken or bare
	local jobFile="" jobTurns=50
	rigInit
	printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"execute","arguments":{"command":": > $RIG_DIR/job.began ; sleep $RIG_STAYS & echo $! > $RIG_DIR/job.pid ; wait $! ; : > $RIG_DIR/job.ended","background":true}}}'
	rigWaitFile "$1/job.pid" || return 0
	while [ "$jobTurns" -gt 0 ] ; do
		for jobFile in "$1"/ws/.local/temp/agent-mcp.*/jobs/2/pid ; do : ; done
		[ ! -s "$jobFile" ] || break
		"$rigRealSleep" 0.2 ; jobTurns=$(( jobTurns - 1 ))
	done
	[ -s "$jobFile" ] || return 0
	cp "$jobFile" "$1/pid.kept"
	printf '%s\n' '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"execute","arguments":{"job":2}}}'
	"$rigRealSleep" 2
	case "$2" in
		taken) : > "$1/ps.lie" ;;
		bare) LC_ALL=C sed 's/ .*//' "$1/pid.kept" > "$jobFile.rig" && mv "$jobFile.rig" "$jobFile" ;;
	esac
	printf '%s\n' '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"execute","arguments":{"job":2,"action":"kill"}}}'
}
## A Monitor job with a deadline of one second, polled once the deadline and its two ends are past.
rigFeedMonitor(){ ## scenario folder
	rigInit
	printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"Monitor","arguments":{"command":": > $RIG_DIR/job.began ; sleep $RIG_STAYS & echo $! > $RIG_DIR/job.pid ; wait $! ; : > $RIG_DIR/job.ended","description":"rig watch","timeout_ms":1000}}}'
	rigWaitFile "$1/job.pid" || return 0
	"$rigRealSleep" 5
	printf '%s\n' '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"Monitor","arguments":{"job":2}}}'
}
## tools/list, and whether its answer was on the wire within twenty seconds of the request; once it is, a second.
rigFeedPlace(){ ## scenario folder
	local placeTurns=250 placeFrom
	rigInit
	placeFrom="$( date +%s )"
	printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'
	while ! LC_ALL=C grep -q '"id":2,' "$1/wire" 2> /dev/null && [ "$placeTurns" -gt 0 ] ; do "$rigRealSleep" 0.2 ; placeTurns=$(( placeTurns - 1 )) ; done
	if [ $(( $( date +%s ) - placeFrom )) -le 20 ] ; then echo in-time ; else echo late ; fi > "$1/answer.when"
	LC_ALL=C grep -q '"id":2,' "$1/wire" 2> /dev/null || return 0
	printf '%s\n' '{"jsonrpc":"2.0","id":3,"method":"tools/list","params":{}}'
}
rigServed='{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"Read","arguments":{"path":"/nonexistent/rig"}}}'
rigScript='{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"execute","arguments":{"command":"sleep $RIG_STAYS & echo $! > $RIG_DIR/watched.pid ; wait $! ; : > $RIG_DIR/watched.ended ; echo RIG-SCRIPT-OUTPUT","timeout":2}}}'
## The same script with a timeout it comes back well within, and one that ignores the polite end, with what it starts.
rigScriptInTime='{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"execute","arguments":{"command":"sleep $RIG_STAYS & echo $! > $RIG_DIR/watched.pid ; wait $! ; : > $RIG_DIR/watched.ended ; echo RIG-SCRIPT-OUTPUT","timeout":30}}}'
rigScriptDeaf='{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"execute","arguments":{"command":"trap \"\" TERM ; sleep $RIG_STAYS & echo $! > $RIG_DIR/watched.pid ; wait $! ; : > $RIG_DIR/watched.ended ; echo RIG-SCRIPT-OUTPUT","timeout":2}}}'

## Every scenario has a server of its own and they run side by side: none waits for another.
rigServe served-quick       host       plain        0  ""   3  3600 rigFeedOne "$rigServed" &
rigServe served-in-time     host       plain        2  ""   30 3600 rigFeedAnswer "$rigServed" &
rigServe served-hangs       host       plain        9  ""   3  3600 rigFeedOne "$rigServed" &
rigServe served-taken       taken      plain        7  ""   3  3600 rigFeedOne "$rigServed" &
rigServe served-deaf        host       plain        11 deaf 3  3600 rigFeedOne "$rigServed" &
rigServe served-deaf-taken  taken-late plain        11 deaf 3  3600 rigFeedOne "$rigServed" &
rigServe orphan-deaf        host       deaf-member  11 ""   3  3600 rigFeedOrphan "$rigServed" &
rigServe orphan-deaf-taken  taken-late deaf-member  11 ""   3  3600 rigFeedOrphan "$rigServed" &
rigServe live-deaf-member   host       deaf-member  11 ""   3  3600 rigFeedAnswer "$rigServed" &
rigServe live-deaf-child    host       deaf-harness 11 ""   3  3600 rigFeedAnswer "$rigServed" &
rigServe script-quick       host       plain        0  ""   3  2    rigFeedOne "$rigScript" &
rigServe script-in-time     host       plain        2  ""   3  30   rigFeedAnswer "$rigScriptInTime" &
rigServe script-hangs       host       plain        9  ""   3  2    rigFeedOne "$rigScript" &
rigServe script-taken       taken      plain        6  ""   3  2    rigFeedOne "$rigScript" &
rigServe script-deaf        host       plain        11 ""   3  2    rigFeedAnswer "$rigScriptDeaf" &
rigServe job-kept           host       plain        12 ""   3  3600 rigFeedJob kept &
rigServe job-taken          host       plain        7  ""   3  3600 rigFeedJob taken &
rigServe job-bare           host       plain        7  ""   3  3600 rigFeedJob bare &
rigServe job-monitor        host       plain        12 ""   3  3600 rigFeedMonitor &
rigServe place-hangs        host       place-hangs  25 ""   3  3600 rigFeedPlace &
wait

echo "-- 2a. a served call: answered as before, ended at its bound where it hangs, never by a number another process has taken --"
rigAssert "control: the stand-in was started by a request handler of the rig's server" "$( LC_ALL=C grep -c -e '--intern-mcp-request' "$rigTmp/served-quick/handler.args" 2> /dev/null || : )" 1
rigAssert "a served call that comes back is answered with what it printed, as no error" "$( rigBecame served-quick watched ) $( rigSaid served-quick 2 'RIG-TOOL-OUTPUT' ) $( rigIsError served-quick 2 ) $( rigSaid served-quick 2 'timed out' )" "ended-by-itself 1 false 0"
rigAssert "a served call that does not come back is ended at its bound, and its caller is told, as an error, that it timed out and was asked to end, that whatever is left of it is killed five seconds after, and where its output is kept" \
	"$( rigBecame served-hangs watched ) $( rigSaid served-hangs 2 '[Read timed out after 3600s and was asked to end; whatever of it is left is killed five seconds after that; partial output above is kept at: ' ) $( rigIsError served-hangs 2 ) $( rigSaid served-hangs 2 'and was killed' )" "ended-before-its-time 1 true 0"
rigAssert "control: the watchdog asked the process list when that pid began, as it started and at its bound" "$( rigReadings served-taken )" 2
rigAssert "at the bound the pid began at another time than the call did: nothing is signalled, the process that has the number runs to its own end, and no timeout is said" \
	"$( rigBecame served-taken watched ) $( rigSaid served-taken 2 'RIG-TOOL-OUTPUT' ) $( rigIsError served-taken 2 ) $( rigSaid served-taken 2 'timed out' )" "ended-by-itself 1 false 0"
rigAssert "a call that ignores the polite end is ended by the hard one, as a group, while its leader is still the process the watchdog was started for" \
	"$( rigBecame served-deaf watched ) $( rigSaid served-deaf 2 'timed out after 3600s and was asked to end' )" "ended-before-its-time 1"
rigAssert "control: before the hard end the watchdog asked again, of the leader and of the members it had kept" "$( rigReadings served-deaf-taken )" 4
rigAssert "the number taken between the two ends: the hard one is sent neither to the group of that number nor to a kept member, and the process that has the number runs to its own end" \
	"$( rigBecame served-deaf-taken watched )" "ended-by-itself"

echo "-- 2b. a watchdog whose handler was ended hard: it still ends its call, and what ignored the polite end, the leader gone, by its own pid --"
rigAssert "control: the handler of each of the two scenarios was ended hard while its call ran" "$( ls "$rigTmp/orphan-deaf/handler.ended-hard" "$rigTmp/orphan-deaf-taken/handler.ended-hard" 2> /dev/null | LC_ALL=C grep -c . )" 2
rigAssert "the call is ended at its bound by the watchdog alone, and the member that ignored the polite end is ended by the hard one though its leader is gone" \
	"$( rigBecame orphan-deaf watched ) $( rigBecame orphan-deaf deaf )" "ended-before-its-time ended-before-its-time"
rigAssert "control: the watchdog asked when the leader began before the hard end, found it gone, and asked of the members it had kept" "$( rigReadings orphan-deaf-taken )" 4
rigAssert "the leader gone and the kept member's number taken between the two ends: the group of that number is not signalled, nor that pid, and the process that has it runs to its own end" \
	"$( rigBecame orphan-deaf-taken watched ) $( rigBecame orphan-deaf-taken deaf )" "ended-before-its-time ended-by-itself"

echo "-- 2c. a script of execute: the same watchdog --"
rigAssert "a script that comes back is answered with what it printed, as no error" "$( rigBecame script-quick watched ) $( rigSaid script-quick 2 'RIG-SCRIPT-OUTPUT' ) $( rigIsError script-quick 2 ) $( rigSaid script-quick 2 'timed out' )" "ended-by-itself 1 false 0"
rigAssert "a script that does not come back is ended at its timeout, and its caller is told, as an error, that it timed out and was asked to end, that whatever is left of it is killed five seconds after, and where its output is kept" \
	"$( rigBecame script-hangs watched ) $( rigSaid script-hangs 2 '[timed out after 2s and was asked to end; whatever of it is left is killed five seconds after that; partial output above is kept at: ' ) $( rigIsError script-hangs 2 ) $( rigSaid script-hangs 2 'and was killed' )" "ended-before-its-time 1 true 0"
rigAssert "control: the watchdog asked the process list when that pid began, as it started and at its bound" "$( rigReadings script-taken )" 2
rigAssert "at the timeout the pid began at another time than the script did: nothing is signalled, the process that has the number runs to its own end, and no timeout is said" \
	"$( rigBecame script-taken watched ) $( rigSaid script-taken 2 'RIG-SCRIPT-OUTPUT' ) $( rigIsError script-taken 2 ) $( rigSaid script-taken 2 'timed out' )" "ended-by-itself 1 false 0"

echo "-- 2d. its handler alive: a watchdog that has fired is left to finish, one that has not is ended with its call --"
rigAt(){ ## scenario, name of a process (deaf, harness, watched, watch, grace) -- whether it ran when the answer was on the wire: runs, gone, none
	cat "$rigTmp/$1/$2.at-answer" 2> /dev/null || printf 'no-answer'
}
rigAssert "control: the watchdog of each call that came back in time had begun the wait for its bound" "$( rigAt served-in-time watch | LC_ALL=C grep -c -v -x -e none -e no-answer ) $( rigAt script-in-time watch | LC_ALL=C grep -c -v -x -e none -e no-answer )" "1 1"
rigAssert "a served call that comes back in time is answered as before, and when its answer is out nothing of its watchdog is left" \
	"$( rigBecame served-in-time watched ) $( rigSaid served-in-time 2 'RIG-TOOL-OUTPUT' ) $( rigIsError served-in-time 2 ) $( rigSaid served-in-time 2 'timed out' ) watchdog-$( rigAt served-in-time watch )" "ended-by-itself 1 false 0 watchdog-gone"
rigAssert "a script that comes back in time is answered as before, and when its answer is out nothing of its watchdog is left" \
	"$( rigBecame script-in-time watched ) $( rigSaid script-in-time 2 'RIG-SCRIPT-OUTPUT' ) $( rigIsError script-in-time 2 ) $( rigSaid script-in-time 2 'timed out' ) watchdog-$( rigAt script-in-time watch )" "ended-by-itself 1 false 0 watchdog-gone"
rigAssert "a member of the call's group ignores the polite end: the caller is answered at once, while that member and the watchdog's wait for its hard end still run, and is told what is known then" \
	"member-$( rigAt live-deaf-member deaf ) watchdog-$( rigAt live-deaf-member grace ) $( rigSaid live-deaf-member 2 '[Read timed out after 3600s and was asked to end; whatever of it is left is killed five seconds after that; partial output above is kept at: ' ) $( rigIsError live-deaf-member 2 )" "member-runs watchdog-runs 1 true"
rigAssert "and the hard end comes all the same, the leader long collected: the call and the member that ignored the polite end are both ended before their time" \
	"$( rigBecame live-deaf-member watched ) $( rigBecame live-deaf-member deaf )" "ended-before-its-time ended-before-its-time"
rigAssert "the leader's own child ignores the polite end while the leader ends at once: the caller is answered while that child still runs, and the child and what it started are ended by the hard one" \
	"child-$( rigAt live-deaf-child harness ) watchdog-$( rigAt live-deaf-child grace ) $( rigSaid live-deaf-child 2 'timed out after 3600s and was asked to end' ) $( rigBecame live-deaf-child watched )" "child-runs watchdog-runs 1 ended-before-its-time"
rigAssert "a script that ignores the polite end: the caller is answered while it still runs, told what is known then, and the script is ended by the hard one" \
	"script-$( rigAt script-deaf watched ) watchdog-$( rigAt script-deaf grace ) $( rigSaid script-deaf 2 '[timed out after 2s and was asked to end; whatever of it is left is killed five seconds after that; partial output above is kept at: ' ) $( rigBecame script-deaf watched )" "script-runs watchdog-runs 1 ended-before-its-time"

echo "-- 2e. the server's question whether CheckList is offered: bounded as a call is, no place where it is not answered in time --"
rigAssert "a harness that does not answer whether CheckList is offered is ended at the bound of that question, tools/list is answered within twenty seconds, and CheckList is not served" \
	"$( rigBecame place-hangs place ) $( cat "$rigTmp/place-hangs/answer.when" 2> /dev/null ) $( rigSaid place-hangs 2 '"name":"CheckList"' ) $( rigSaid place-hangs 2 '"name":"execute"' )" "ended-before-its-time in-time 0 1"
rigAssert "nothing is kept of a question not answered in time: the next tools/list asks again, and the answer given in time then serves CheckList" \
	"$( rigSaid place-hangs 3 '"name":"CheckList"' ) $( rigSaid place-hangs 3 '"name":"execute"' )" "1 1"

echo "-- 3. the kill action of a job: by the group, only while its leader is still the process its pid file names --"
rigJobPid="$( LC_ALL=C sed 's/ .*//' "$rigTmp/job-kept/pid.kept" 2> /dev/null )"
rigAssert "the pid file of a job holds one line, its pid and when it began, as the tooling keeps a process" "$( LC_ALL=C grep -c -E '^[0-9]+ [A-Z][a-z]{2}_[A-Z][a-z]{2}_[0-9]{1,2}_[0-9:]{8}_[0-9]{4}$' "$rigTmp/job-kept/pid.kept" 2> /dev/null || : ) $( wc -l < "$rigTmp/job-kept/pid.kept" 2> /dev/null | LC_ALL=C tr -d ' ' )" "1 1"
rigAssert "the start names the pid alone, and a poll says that the job runs, by that pid" "$( rigSaid job-kept 2 "[job 2 started, pid $rigJobPid]" ) $( rigSaid job-kept 3 "[job 2: still running, pid $rigJobPid -- poll again for more]" )" "1 1"
rigAssert "a running job is killed as a group, its leader still the process the file names: the caller is told, and the job is ended" \
	"$( rigSaid job-kept 4 "[job 2: TERM sent to process group $rigJobPid]" ) $( rigIsError job-kept 4 ) $( rigBecame job-kept job )" "1 false ended-before-its-time"
rigAssert "the number of a job taken by another process: it reads as finished, nothing is signalled, and the process that has the number runs to its own end" \
	"$( rigSaid job-taken 4 '[job 2: already finished, nothing to kill]' ) $( rigIsError job-taken 4 ) $( rigBecame job-taken job )" "1 false ended-by-itself"
rigAssert "a pid file with no start, as jobs were kept before: nothing is signalled by the number alone, the caller is told so as an error, and the process runs to its own end" \
	"$( rigSaid job-bare 4 '[job 2: NOT signalled. Its pid file names pid ' ) $( rigSaid job-bare 4 'with no start time, and a process has that number now: nothing shows that it is this job, so nothing is signalled by the number alone.' ) $( rigIsError job-bare 4 ) $( rigBecame job-bare job )" "1 1 true ended-by-itself"
rigAssert "a Monitor job is still ended at its deadline, its group read from the same file, and the poll says that it timed out" \
	"$( rigBecame job-monitor job ) $( rigSaid job-monitor 3 '[job 2 (rig watch): timed out after 1000ms and was killed]' )" "ended-before-its-time 1"

echo "-- the request keeps each process it ends by the one reading the tooling keeps a process by --"
rigAssert "the include probes no call by its number before it ends a group, both watchdogs are the one function, each handler ends its watchdog only where that has not fired, and a job is kept and read with when it began through AgentsToolsRegistryProcessesBegan" \
	"$( rigCode "$rigInclude" | LC_ALL=C grep -c -e 'kill -0 "\$mcpCmdPid"' ) $( rigCode "$rigInclude" | LC_ALL=C grep -c -e '^[[:space:]]*AgentsMcpCallWatch "\$mcp[A-Za-z]*" "\$mcpCmdPid" "\$mcpKillFile" 3>&- &$' ) $( rigCode "$rigInclude" | LC_ALL=C grep -c -x -e '[[:space:]]*if \[ ! -f "\$mcpKillFile" \] ; then' ) $( rigCode "$rigInclude" | LC_ALL=C grep -c -F '"$mcpJobPid" | AgentsToolsRegistryProcessesBegan' )" "0 2 2 2"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MCP CALL WATCHDOG CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MCP_CALL_WATCHDOG: OK (%d assertions, offline)\n' "$rigPasses"
