#!/usr/bin/env bash
## Behavioural check on the state the control thread of a session keeps (--intern-session-control), run rather
## than read, against a rig workspace built here: spawn records, session stores and a process list of the rig's
## own. A ps first on PATH lists the rig's runs only, stand-in processes under their own pids, never a real CLI,
## and counts what a thread asks of it: its ticks, and the whole-host listings among them; a curl beside it only
## logs, and nothing may call it.
## Held:
##   1. THE STATE FILE. control/state of the session's folder is three lines: `state`, the word; `state-at`, when
##      it was set, as a record writes a date; `reason`. A session with a live run reads `running`, whichever way
##      the run is told alive: its own word on its command line, or the process its record names while that is
##      still the same process.
##   2. WRITTEN ONLY WHEN THE WORD CHANGES. A second tick with nothing new writes no file of the session's folder:
##      the state keeps its inode, its bytes and its time. Ten ticks make no request over the network.
##   3. FINISHED, AND THE END OF THE THREAD. A session whose records were all closed is marked at the first tick,
##      and a thread started for it ends by itself. A thread that watches a live session leaves the state alone
##      while a run of it lives, and when the last record closes it writes `finished`, by one rename, ends with
##      status 0, and leaves its state and its log: no pid file, no lock, no temp file.
##   4. THE PERIOD OF THE TICK is the setting SESSION_CONTROL_TICK_SECONDS, 5 where it is not set. And a tick is
##      cheap while nothing changes: over a running session it asks whether the processes of its runs are still
##      themselves, and does not read the whole process list again.
##   5. WHAT IS NOT CALLED FINISHED, AND IS NOT WRITTEN. An open record of another host: said, no state, and the
##      thread stays. No run alive and a record of this host still open that is no death yet, one that names no
##      supervising shell, within its closing time (AgentsSessionControlDeathCheck holds what a death is): no
##      state where there was none, the old state untouched where there was one, never another word, the moment
##      its process was first seen gone noted once, and the thread stays and writes nothing at any later tick.
##      A folder of a session with no record: nothing to watch.
##   6. A SESSION THAT IS STARTED AGAIN reads `running` again; and a session a client founded, which has no record
##      under its own id, is read by the records of its members.
## Red before the operation existed: every assertion but the controls. Offline: only the rig's own tree is read or
## written, and every thread and stand-in this check starts is ended by it, through the rig's process helper.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigOp="--intern-session-control"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionControlStateCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## Every thread and every stand-in of this check: at its end each is ended, with what it started, while it is still itself.
rigStarted=""
trap 'rigProcSignalWithChildren KILL $rigStarted ; chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills"
rigAgents="$rigWs/.local/agents"
rigSp="$rigAgents/spawned" ; rigStores="$rigAgents/sessions"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigSp" "$rigStores" "$rigHome" "$rigSkills"
rigHost="$( hostname -s 2> /dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"
rigTickSet(){ ## seconds, or nothing for no setting
	if [ -n "${1:-}" ] ; then printf 'SESSION_CONTROL_TICK_SECONDS=%s\n' "$1" ; else printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\n' ; fi > "$rigWs/.local/.agents/magic-team.agent.env"
}
rigTickSet 1

## THE RIG'S OWN PROCESS LIST, as AgentsRunRuleReadersCheck keeps it: the ps first on PATH answers the whole-host
## listing from the rig's own list, one `<pid> <command line>` line a process, each listed only while it lives, and
## hands every other call to the real ps. A thread over a running session asks once at every tick whether the
## processes of its runs are still themselves (`-o pid=,stat=,lstart=`): each such call is counted, one a tick.
ln -s "$( command -v ps )" "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
: > "$rigTmp/ps.list" ; : > "$rigTmp/ps.calls" ; : > "$rigTmp/ps.lists"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case "$*" in *pid=,stat=,lstart=*) echo tick >> "${0%/*}/../ps.calls" ;; esac
case " $* " in
	*" -A "*)
		case "$*" in *ppid=*) exec "${0%/*}/ps.real" "$@" ;; esac
		echo list >> "${0%/*}/../ps.lists"
		while read -r rigPsPid rigPsLine ; do
			kill -0 "$rigPsPid" 2> /dev/null || continue
			case "$*" in
				*pid=*) printf '%s %s\n' "$rigPsPid" "$rigPsLine" ;;
				*) printf '%s\n' "$rigPsLine" ;;
			esac
		done < "${0%/*}/../ps.list"
		exit 0
	;;
esac
exec "${0%/*}/ps.real" "$@"
RIGPS
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/curl.calls"\nexit 7\n' "$rigTmp" > "$rigTmp/bin/curl"
chmod +x "$rigTmp/bin/ps" "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v ps )" = "$rigTmp/bin/ps" ] && [ "$( command -v curl )" = "$rigTmp/bin/curl" ] \
	|| rigRefuse "the rig's own ps and curl are not first on PATH, so this check would read the host's process list or issue a real request"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
## A record is put in place by one rename, as the tooling closes one: no tick of a running thread reads half of it.
rigRec(){ ## sandbox, record name, session id, spawn id, host, status, more frontmatter lines (may be empty)
	mkdir -p "$rigSp/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nworkspace: rigws\nowner: keeper-rig\nstatus: %s\nstarted-at: 2026-10-13 09:00 +0300\n%s---\n\n# Spawn session: %s\n' \
		"$3" "$4" "$5" "$6" "${7:-}" "$3" > "$rigSp/$1/$2.md.rig" && mv -f "$rigSp/$1/$2.md.rig" "$rigSp/$1/$2.spawn.md"
}
rigClosed='resolved-at: 2026-10-13 09:30 +0300
'
## A stand-in process under its own pid that only waits; with a spawn id given it stands in the rig's process list
## as the run of that spawn, by its own --session-id word. Sets rigStandPid.
rigStandPid=""
rigStand(){ ## spawn id (may be empty)
	sleep 600 > /dev/null 2>&1 < /dev/null &
	rigStandPid=$!
	rigProcNote "$rigStandPid" ; rigStarted="$rigStarted $rigStandPid"
	disown "$rigStandPid" 2> /dev/null || :
	[ -z "${1:-}" ] || printf '%s claude --verbose --session-id %s --agent rig-member the brief\n' "$rigStandPid" "$1" >> "$rigTmp/ps.list"
}
rigUnlist(){ ## spawn id -- its run ends: the stand-in that ran as it, and its line of the rig's process list
	local unlistPids
	unlistPids="$( LC_ALL=C awk -v wantId="$1" '$2 == "claude" { for ( wordAt = 3 ; wordAt < NF ; wordAt++ ) { if ( $wordAt == "--session-id" && $( wordAt + 1 ) == wantId ) { print $1 ; } } }' "$rigTmp/ps.list" )"
	[ -z "$unlistPids" ] || rigProcSignal TERM $unlistPids
	LC_ALL=C grep -v -F -- " --session-id $1 " "$rigTmp/ps.list" > "$rigTmp/ps.list.new" ; mv -f "$rigTmp/ps.list.new" "$rigTmp/ps.list"
}
rigRc=0
rigOne(){ ## session id -- one tick; rc in rigRc, stdout in out, stderr in err
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash "$rigTool" "$rigOp" --one --session-id "$1" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigThreadPid=""
rigThread(){ ## name of its output files, session id
	( cd "$rigWs" && exec env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash "$rigTool" "$rigOp" --run --session-id "$2" ) > "$rigTmp/$1.out" 2> "$rigTmp/$1.err" < /dev/null &
	rigThreadPid=$!
	rigProcNote "$rigThreadPid" ; rigStarted="$rigStarted $rigThreadPid"
}
rigWaitFor(){ ## seconds, test command...
	local waitLeft=$(( $1 * 5 )) ; shift
	while ! "$@" && [ "$waitLeft" -gt 0 ] ; do sleep 0.2 ; waitLeft=$(( waitLeft - 1 )) ; done
	"$@"
}
rigEnded(){ ## pid -- it is no process any more, collected by its starter or not
	case "$( "$rigTmp/bin/ps.real" -o stat= -p "$1" 2> /dev/null )" in ''|*Z*) return 0 ;; esac
	return 1
}
rigLives(){ ## pid... -- how many of them are processes now
	local livesCount=0 livesPid
	for livesPid in "$@" ; do rigEnded "$livesPid" || livesCount=$(( livesCount + 1 )) ; done
	printf '%s' "$livesCount"
}
rigGot=""
rigStatusOf(){ ## pid of a job of this shell -- the status it ended with into rigGot, `alive` where it has not ended in twenty seconds
	rigGot="alive"
	rigWaitFor 20 rigEnded "$1" || return 0
	{ wait "$1" ; rigGot=$? ; } 2> /dev/null
}
rigHolds(){ ## session id, pid -- the pid file of the session names that pid
	local holdsLine=""
	{ IFS= read -r holdsLine < "$rigStores/$1/control/pid" ; } 2> /dev/null
	[ -n "$holdsLine" ] && [ "${holdsLine%% *}" = "$2" ]
}
rigState(){ ## session id -- the word of its state file
	LC_ALL=C sed -n 's/^state: //p' "$rigStores/$1/control/state" 2> /dev/null | LC_ALL=C sed -n '1p'
}
rigStateIs(){ ## session id, word
	[ "$( rigState "$1" )" = "$2" ]
}
rigLogHas(){ ## session id, fixed text -- how many lines of its log hold it
	LC_ALL=C grep -c -F -- "$2" "$rigStores/$1/control/log" 2> /dev/null || :
}
rigLogSays(){ ## session id, fixed text -- at least one line of its log holds it
	[ "$( rigLogHas "$1" "$2" )" -ge 1 ]
}
rigErrorCount(){ ## -- how many ERROR lines the last stderr holds, but for the one every rig of this package gets
	LC_ALL=C grep -F -- 'ERROR' "$rigTmp/err" | LC_ALL=C grep -c -v -F -- 'SystemContext.SetInputSpec' || :
}
rigSaid(){ ## fixed text -- how many lines of the last stderr hold it
	LC_ALL=C grep -c -F -- "$1" "$rigTmp/err" || :
}
rigPrint(){ ## file -- its inode, the sum of its bytes and its time; no-file where there is none
	[ -f "$1" ] || { printf 'no-file\n' ; return 0 ; }
	printf '%s:%s:%s\n' "$( ls -i "$1" | LC_ALL=C awk '{ print $1 ; exit }' )" "$( cksum < "$1" | LC_ALL=C tr -s ' \t' '-' )" "$( ls -l -T "$1" 2> /dev/null | LC_ALL=C awk '{ print $6 $7 $8 $9 }' || ls -l --full-time "$1" | LC_ALL=C awk '{ print $6 $7 }' )"
}
rigControl(){ ## session id -- the names in its control folder, a space between them
	( cd "$rigStores/$1/control" 2> /dev/null && ls -A | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )
}
rigNewer(){ ## session id, marker file -- how many files of the session's folder were written after the marker
	find "$rigStores/$1" -type f -newer "$2" 2> /dev/null | LC_ALL=C grep -c . || :
}
rigReads(){ ## -- how many times the rig's ps was asked whether processes are still themselves, so far
	wc -l < "$rigTmp/ps.calls" | LC_ALL=C tr -d ' '
}
rigLists(){ ## -- how many whole-host listings were asked of the rig's ps so far
	wc -l < "$rigTmp/ps.lists" 2> /dev/null | LC_ALL=C tr -d ' '
}
rigNow(){ ## -- this minute, as a record writes a date
	date +"%Y-%m-%d %H:%M %z"
}

echo "-- 1. the state file: a session with a live run reads running --"
## Two records: the process of one runs, the other is closed.
rigRec s-run s-run s-run s-run "$rigHost" spawn-started ''
rigRec run-done run-done s-run run-done "$rigHost" spawn-succeeded "$rigClosed"
rigStand s-run ; rigRunPid="$rigStandPid"
rigBefore="$( rigNow )"
rigOne s-run
rigAfter="$( rigNow )"
rigStateFile="$rigStores/s-run/control/state"
rigAssert "one tick over a session with a live run and a closed record: status 0, and the state file holds running" "$rigRc:$( rigErrorCount ):$( rigState s-run )" "0:0:running"
rigAt="$( LC_ALL=C sed -n 's/^state-at: //p' "$rigStateFile" 2> /dev/null )"
rigAssert "the state file is three lines: the word, the date-time of the tick as a record writes a date, and the reason" \
	"$( wc -l < "$rigStateFile" 2> /dev/null | LC_ALL=C tr -d ' ' ):$( LC_ALL=C sed -n '1p' "$rigStateFile" 2> /dev/null ):$( [ "$rigAt" = "$rigBefore" ] || [ "$rigAt" = "$rigAfter" ] ; echo "$?" ):$( LC_ALL=C sed -n '2p' "$rigStateFile" 2> /dev/null | LC_ALL=C grep -c -E '^state-at: [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2} [+-][0-9]{4}$' ):$( LC_ALL=C sed -n '3p' "$rigStateFile" 2> /dev/null )" \
	"3:state: running:0:1:reason: a run of the session is alive on this host"
rigAssert "the tick left no pid file and no lock, and one line of the log, with its moment, for the state it set" \
	"$( rigControl s-run ):$( wc -l < "$rigStores/s-run/control/log" 2> /dev/null | LC_ALL=C tr -d ' ' ):$( LC_ALL=C grep -c -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z session s-run: running: a run of the session is alive on this host$' "$rigStores/s-run/control/log" 2> /dev/null )" "log state:1:1"
## A run that lives only by the process its record names: no line of the process list carries its word.
rigStand '' ; rigRecorded="$rigStandPid"
rigRec s-rec s-rec s-rec s-rec "$rigHost" spawn-started "run-process: $( rigProcBegan "$rigRecorded" )
"
rigOne s-rec
rigAssert "control: no line of the rig's process list carries the word of that run" "$( LC_ALL=C grep -c -F -- 's-rec' "$rigTmp/ps.list" )" "0"
rigAssert "a run that lives only by the process its record names, still the same process, counts as alive: running" "$rigRc:$( rigState s-rec )" "0:running"
rigRec s-rec2 s-rec2 s-rec2 s-rec2 "$rigHost" spawn-started "run-process: $rigRecorded Mon_Jan__1_00:00:00_2001
"
rigOne s-rec2
rigAssert "control: the same pid begun at another time than the record says is another process: no run, and no state is set" "$rigRc:[$( rigState s-rec2 )]:$( rigSaid 'no run of it is alive on this host and 1 record(s) are still open' )" "0:[]:1"

echo "-- 2. written only when the word changes; no request over the network --"
rigPrintBefore="$( rigPrint "$rigStateFile" )"
sleep 1 ; : > "$rigTmp/marker" ; sleep 1
rigOne s-run
rigAssert "a second tick that finds nothing new writes no file of the session's folder: the state has its inode, its bytes and its time, and the log its one line" \
	"$rigRc:$( rigPrint "$rigStateFile" ):$( rigNewer s-run "$rigTmp/marker" ):$( wc -l < "$rigStores/s-run/control/log" | LC_ALL=C tr -d ' ' ):$( rigControl s-run )" "0:$rigPrintBefore:0:1:log state"
rigAssert "and says so to who asked" "$( rigSaid "session s-run: running, as recorded $rigAt -- nothing is written" )" "1"
rigTen=0
while [ "$rigTen" -lt 10 ] ; do rigOne s-run ; rigTen=$(( rigTen + 1 )) ; done
rigAssert "ten more ticks over a session with a live run: no request was made, and still nothing was written" \
	"$( [ -e "$rigTmp/curl.calls" ] && echo called || echo none ):$( rigPrint "$rigStateFile" ):$( rigNewer s-run "$rigTmp/marker" )" "none:$rigPrintBefore:0"

echo "-- 3. finished, and the end of the thread --"
rigRec s-done s-done s-done s-done "$rigHost" spawn-succeeded "$rigClosed"
rigRec done-b done-b s-done done-b "$rigHost" spawn-failed "$rigClosed"
rigOne s-done
rigAssert "a session whose runs had all closed is marked at the first tick: finished, with its reason, and no pid file and no lock" \
	"$rigRc:$( rigState s-done ):$( LC_ALL=C sed -n '3p' "$rigStores/s-done/control/state" 2> /dev/null ):$( rigControl s-done )" "0:finished:reason: no run of the session is alive and every record of it is closed:log state"
rigRec s-done2 s-done2 s-done2 s-done2 "$rigHost" spawn-ended-without-close "$rigClosed"
rigThread done2 s-done2 ; rigDone2="$rigThreadPid"
rigStatusOf "$rigDone2"
rigAssert "a thread started for such a session writes finished and ends by itself: status 0, no pid file, no lock" "$rigGot:$( rigState s-done2 ):$( rigControl s-done2 )" "0:finished:log state"
rigAssert "its log holds its start, the state it set and why it ended" \
	"$( rigLogHas s-done2 "the control thread of session s-done2 runs as pid $rigDone2, a tick every 1s" ):$( rigLogHas s-done2 'session s-done2: finished: no run of the session is alive and every record of it is closed' ):$( rigLogHas s-done2 "the control thread of session s-done2, pid $rigDone2, ends: its session is finished" ):$( wc -l < "$rigStores/s-done2/control/log" | LC_ALL=C tr -d ' ' )" "1:1:1:3"
## A thread over a live session of two runs: one ends, then the other.
rigRec s-live s-live s-live s-live "$rigHost" spawn-started ''
rigRec live-b live-b s-live live-b "$rigHost" spawn-started ''
rigStand s-live ; rigStand live-b
rigThread live s-live ; rigLive="$rigThreadPid"
rigWaitFor 20 rigHolds s-live "$rigLive" || rigRefuse "the thread of s-live did not start, so nothing below would be measured: $( LC_ALL=C tr '\n' ' ' < "$rigTmp/live.err" | cut -c1-600 )"
rigWaitFor 10 rigStateIs s-live running
rigLiveState="$rigStores/s-live/control/state"
rigLivePrint="$( rigPrint "$rigLiveState" )"
rigAssert "a thread over a session of two live runs sets running, and says what it takes of the console" "$( rigLives "$rigLive" ):$( rigState s-live ):$( rigControl s-live ):$( cat "$rigStores/s-live/control/takes" 2> /dev/null )" "1:running:lock log pid state takes:kill"
rigRec live-b live-b s-live live-b "$rigHost" spawn-succeeded "$rigClosed"
rigUnlist live-b
sleep 3
rigAssert "one of the two runs closes its record: the session still reads running, and the state file is not written again" "$( rigLives "$rigLive" ):$( rigPrint "$rigLiveState" )" "1:$rigLivePrint"
rigRec s-live s-live s-live s-live "$rigHost" spawn-succeeded "$rigClosed"
rigUnlist s-live
rigStatusOf "$rigLive"
rigAssert "the last run closes its record: at the next tick the state reads finished, and the thread has ended with status 0" "$rigGot:$( rigState s-live )" "0:finished"
rigAssert "the change left the state whole, put in place by a rename, and no pid file, no lock and no temp file beside it" \
	"$( wc -l < "$rigLiveState" | LC_ALL=C tr -d ' ' ):$( [ "$( ls -i "$rigLiveState" | LC_ALL=C awk '{ print $1 ; exit }' )" != "${rigLivePrint%%:*}" ] && echo another-inode || echo same-inode ):$( rigControl s-live )" "3:another-inode:log state"

echo "-- 4. the period of the tick is the setting --"
## No other thread of this check runs now: every such question to the rig's ps is a tick of this one thread.
rigRec s-tick s-tick s-tick s-tick "$rigHost" spawn-started ''
rigStand s-tick
rigThread tick s-tick ; rigTick="$rigThreadPid"
rigWaitFor 20 rigHolds s-tick "$rigTick" || rigRefuse "the thread of s-tick did not start: $( LC_ALL=C tr '\n' ' ' < "$rigTmp/tick.err" | cut -c1-600 )"
rigWaitFor 10 rigStateIs s-tick running
rigReadsFrom="$( rigReads )" ; rigListsFrom="$( rigLists )" ; sleep 9
rigReadsOne=$(( $( rigReads ) - rigReadsFrom )) ; rigListsOne=$(( $( rigLists ) - rigListsFrom ))
rigProcSignal TERM "$rigTick" ; rigStatusOf "$rigTick"
rigAssert "control: that thread ended in order" "$rigGot" "0"
rigTickSet ''
rigThread tick5 s-tick ; rigTick5="$rigThreadPid"
rigWaitFor 20 rigHolds s-tick "$rigTick5" || rigRefuse "the second thread of s-tick did not start: $( LC_ALL=C tr '\n' ' ' < "$rigTmp/tick5.err" | cut -c1-600 )"
rigReadsFrom="$( rigReads )" ; sleep 9
rigReadsFive=$(( $( rigReads ) - rigReadsFrom ))
rigAssert "with SESSION_CONTROL_TICK_SECONDS set to 1 the thread ticks every second: at least four times in nine seconds" "$( [ "$rigReadsOne" -ge 4 ] && echo often || echo "$rigReadsOne" )" "often"
rigAssert "and a tick is cheap while nothing changes: in those nine seconds the whole process list was read at most twice, not once a tick" "$( [ "$rigListsOne" -le 2 ] && echo seldom || echo "$rigListsOne" )" "seldom"
rigAssert "with no setting it ticks every five seconds: at most three times in nine seconds, and its log says five" \
	"$( [ "$rigReadsFive" -ge 1 ] && [ "$rigReadsFive" -le 3 ] && echo seldom || echo "$rigReadsFive" ):$( rigLogHas s-tick "the control thread of session s-tick runs as pid $rigTick5, a tick every 5s" )" "seldom:1"
rigProcSignal TERM "$rigTick5" ; rigStatusOf "$rigTick5"
rigAssert "control: TERM ends a thread that waits five seconds between two ticks at once, in order" "$rigGot:$( rigControl s-tick )" "0:log state"
rigTickSet 1

echo "-- 5. what is not called finished, and is not written --"
## An open record of another host and no run of this host.
rigRec s-far s-far s-far s-far elsewhere spawn-started ''
rigRec far-b far-b s-far far-b "$rigHost" spawn-succeeded "$rigClosed"
rigOne s-far
rigAssert "an open record of another host is not called finished: one tick says whose run it is, and writes no state" \
	"$rigRc:[$( rigState s-far )]:$( rigSaid 'every record still open is a run of another host (elsewhere), which cannot be measured from here -- it is not called finished' ):$( rigControl s-far )" "0:[]:1:"
rigThread far s-far ; rigFar="$rigThreadPid"
rigWaitFor 20 rigHolds s-far "$rigFar" || rigRefuse "the thread of s-far did not start: $( LC_ALL=C tr '\n' ' ' < "$rigTmp/far.err" | cut -c1-600 )"
rigWaitFor 10 rigLogSays s-far 'is a run of another host (elsewhere)'
sleep 3
rigAssert "a thread over such a session says so once in its log, writes no state, and stays: nothing but a finished session or TERM ends it" \
	"$( rigLives "$rigFar" ):[$( rigState s-far )]:$( rigLogHas s-far 'every record still open is a run of another host (elsewhere)' ):$( rigLogHas s-far 'finished' | LC_ALL=C awk '{ print ( $1 == 1 ) ? "only-in-not-called-finished" : $1 }' )" "1:[]:1:only-in-not-called-finished"
rigRec s-far s-far s-far s-far elsewhere spawn-ended-without-close "$rigClosed"
rigStatusOf "$rigFar"
rigAssert "once that record is closed, as the advance pass closes one by its age, the thread writes finished and ends" "$rigGot:$( rigState s-far ):$( rigControl s-far )" "0:finished:log state"
## No run alive and a record of this host still open: the place of the word of a death.
rigRec s-dead s-dead s-dead s-dead "$rigHost" spawn-started ''
rigOne s-dead
rigAssert "no run alive and a record of this host still open, which names no supervising shell, with no state yet: one tick writes none, says what it found, and notes when it first saw that process gone" \
	"$rigRc:[$( rigState s-dead )]:$( rigSaid 'no run of it is alive on this host and 1 record(s) are still open -- the state is left as it is' ):$( rigControl s-dead )" "0:[]:1:gone"
rigStand s-dead ; rigDeadRun="$rigStandPid"
rigOne s-dead
rigDeadPrint="$( rigPrint "$rigStores/s-dead/control/state" )"
rigAssert "control: while its run lives that session reads running" "$( rigState s-dead )" "running"
rigProcSignal TERM "$rigDeadRun" ; rigWaitFor 10 rigEnded "$rigDeadRun"
rigOne s-dead
rigAssert "its process gone and its record still open: the state is left as it was, word and date, and no word of a death is written" \
	"$rigRc:$( rigPrint "$rigStores/s-dead/control/state" ):$( rigSaid 'the state is left as it is, running' ):$( LC_ALL=C grep -c -F -- 'member-dead' "$rigStores/s-dead/control/state" "$rigStores/s-dead/control/log" | LC_ALL=C awk -F: '{ total += $NF } END { print total + 0 }' )" "0:$rigDeadPrint:1:0"
rigThread dead s-dead ; rigDead="$rigThreadPid"
rigWaitFor 20 rigHolds s-dead "$rigDead" || rigRefuse "the thread of s-dead did not start: $( LC_ALL=C tr '\n' ' ' < "$rigTmp/dead.err" | cut -c1-600 )"
rigWaitFor 10 rigLogSays s-dead 'record(s) are still open'
sleep 1 ; : > "$rigTmp/marker.dead" ; sleep 4
rigAssert "a thread over such a session stays, and no tick of it writes a file of the session's folder" \
	"$( rigLives "$rigDead" ):$( rigNewer s-dead "$rigTmp/marker.dead" ):$( rigPrint "$rigStores/s-dead/control/state" ):$( rigLogHas s-dead 'record(s) are still open' )" "1:0:$rigDeadPrint:1"
rigProcSignal TERM "$rigDead" ; rigStatusOf "$rigDead"
rigAssert "control: that thread ended in order, the state as it was, and the note of the moment kept for the next thread" "$rigGot:$( rigPrint "$rigStores/s-dead/control/state" ):$( rigControl s-dead )" "0:$rigDeadPrint:gone log state"
## A folder of a session and no record that carries its id.
mkdir -p "$rigStores/s-empty"
rigOne s-empty
rigAssert "a folder of a session that no record carries the id of: there is nothing to watch, and no file is written" \
	"$rigRc:$( rigErrorCount ):$( rigSaid 'no record of a run carries it as its session-id, so there is nothing to watch yet -- no state is written' ):$( find "$rigStores/s-empty" -type f -o -type l | LC_ALL=C grep -c . )" "0:0:1:0"

echo "-- 6. a session that is started again; a session a client founded --"
rigRec done-c done-c s-done done-c "$rigHost" spawn-started ''
rigStand done-c ; rigDoneRun="$rigStandPid"
rigDonePrint="$( rigPrint "$rigStores/s-done/control/state" )"
rigOne s-done
rigAssert "a finished session that a run joins again reads running again: the word changed, so the state is written" \
	"$rigRc:$( rigState s-done ):$( [ "$( rigPrint "$rigStores/s-done/control/state" )" != "$rigDonePrint" ] && echo written || echo untouched )" "0:running:written"
## The founder is a client's own session, with no record of its own: the session is its members' records.
rigRec member-1 member-1 s-client member-1 "$rigHost" spawn-started 'parent-spawn-id: s-client
'
rigStand member-1
rigOne s-client
rigAssert "a session a client founded, with no record under its own id, is read by the records of its members: running" "$rigRc:$( rigErrorCount ):$( rigState s-client )" "0:0:running"
rigRec member-1 member-1 s-client member-1 "$rigHost" spawn-succeeded "$rigClosed"
rigUnlist member-1
rigOne s-client
rigAssert "and finished once its last member closed its record" "$rigRc:$( rigState s-client )" "0:finished"

echo "-- 7. nothing is left running, and nothing was asked of the network --"
rigProcSignalWithChildren KILL $rigStarted
sleep 1
rigAssert "every thread and every stand-in this check started is ended" "$( rigLives $rigStarted )" "0"
rigAssert "no request was made" "$( [ -e "$rigTmp/curl.calls" ] && echo called || echo none )" "none"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SESSION CONTROL STATE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_CONTROL_STATE: OK (%d assertions, offline)\n' "$rigPasses"
