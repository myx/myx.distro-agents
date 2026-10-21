#!/usr/bin/env bash
## Behavioural check on the advance pass starting the dead control threads of the sessions of its workspace
## (--magic-advance-lock-acquire, the housekeeping of sh-lib/magic/AgentsTools.MagicAdvance.include, through the one check
## of sh-lib/session/AgentsTools.SessionControlStart.include), run rather than read, against a rig workspace and a rig data
## root built here, with a process list of the rig's own. A ps first on PATH lists the rig's runs only, stand-in
## processes under their own pids, never a real CLI, and counts what is asked of it; a curl beside it only logs,
## and nothing may call it. A scan below is one take of the advance routine's lock, freed before each: the
## housekeeping runs there, and the input scan only reads.
## Held:
##   1. THE COST. A scan with no thread to start asks for the whole process list as often as it did before the
##      check was in it, and asks once whether the threads its sessions name are still themselves.
##   2. A scan starts the thread of a session that has a live run and none: it runs after the scan, detached. What
##      was started is one line of the housekeeping report, which names the session, and no line of the scan's
##      output or of its errors.
##   3. A scan leaves a live thread alone, and with none to start it reports nothing: its output is byte for byte
##      what it was with one to start.
##   4. WHICH SESSIONS. A session with no run alive and the record of a run of this host still open gets its
##      thread. A finished one, one of another host alone, one whose open record names no run and one that a start
##      its caller waits on opened get none. A dead record the same scan closes leaves its session finished, and it
##      gets none.
##   5. A thread that cannot be started is one warning, and the scan ends with status 0, its output whole.
##   6. NO STORM. A session whose thread ends at once is started once: the scans that follow leave it alone, in
##      silence, until the last line of the log of its thread is five minutes old.
## Red before the change: every assertion but the controls. Offline: only the rig's own tree is read or written,
## and every thread and stand-in this check starts is ended by it, through the rig's process helper.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigOp="--magic-advance-lock-acquire"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
## And the control threads the tooling starts in this rig are ended by it, each only while it is still the process that was started.
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionControlScanCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## The ids of this run's sessions carry the name mktemp gave it, so that a copy of this check that runs beside it never counts this one's threads.
rigTag="${rigTmp##*.}" ; rigTag="$( printf '%s' "$rigTag" | LC_ALL=C tr -c -d 'A-Za-z0-9' )"
[ -n "$rigTag" ] || rigRefuse "the rig has no name of its own to tell its sessions by"
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigData="$rigTmp/data"
rigAgents="$rigWs/.local/agents"
rigSp="$rigAgents/spawned" ; rigStores="$rigAgents/sessions"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigSp" "$rigStores" "$rigHome" "$rigAgents/members/magic-coordinator" \
	"$rigData/inboxes/magic-coordinator/incoming" "$rigData/board/running" "$rigData/board/review" "$rigData/board/processed" "$rigData/audit"
printf '# magic-coordinator\n' > "$rigAgents/members/magic-coordinator/SKILL.md"
rigHost="$( hostname -s 2> /dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"
printf 'SESSION_CONTROL_TICK_SECONDS=1\n' > "$rigWs/.local/.agents/magic-team.agent.env"

rigStarted=""
rigThreadsEnd(){ ## -- every thread a call of this rig started is ended, and every process a start of it made
	chmod -R u+rwX -- "$rigTmp" 2> /dev/null
	rigControlThreadNotes "$rigTmp" > "$rigTmp/threads.notes" 2> /dev/null
	rigControlThreadsEnd "$rigTmp"
	return 0
}
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rigProcSignalWithChildren KILL $rigStarted ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM

## THE RIG'S OWN PROCESS LIST: the ps first on PATH answers the whole-host listing from the rig's own list, one
## `<pid> <command line>` line a process, each listed only while it lives, and hands every other call to the real
## ps. It counts the whole-host listings, and the questions whether processes are still themselves
## (`-o pid=,stat=,lstart=`), which is how a thread named by a pid file is told alive.
ln -s "$( command -v ps )" "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
: > "$rigTmp/ps.list" ; : > "$rigTmp/ps.lists" ; : > "$rigTmp/ps.asks"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case "$*" in *pid=,stat=,lstart=*) echo ask >> "${0%/*}/../ps.asks" ;; esac
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
rigId(){ ## short name -- the id of that session or run in this run of the check
	printf '%s-%s' "$1" "$rigTag"
}
rigRec(){ ## sandbox (short), record (short), session (short), host, status, more frontmatter lines (may be empty)
	mkdir -p "$rigSp/$( rigId "$1" )"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nworkspace: rigws\nowner: keeper-rig\nstatus: %s\nstarted-at: 2026-10-13 09:00 +0300\n%s---\n\n# Spawn session: %s\n' \
		"$( rigId "$3" )" "$( rigId "$2" )" "$4" "$5" "${6:-}" "$( rigId "$3" )" > "$rigSp/$( rigId "$1" )/$( rigId "$2" ).md.rig" \
		&& mv -f "$rigSp/$( rigId "$1" )/$( rigId "$2" ).md.rig" "$rigSp/$( rigId "$1" )/$( rigId "$2" ).spawn.md"
}
rigClosed='resolved-at: 2026-10-13 09:30 +0300
'
rigStandPid=""
rigStand(){ ## short name of the run (may be empty) -- a stand-in under its own pid that only waits; named, it is the run of that spawn in the rig's process list
	sleep 600 > /dev/null 2>&1 < /dev/null &
	rigStandPid=$!
	rigProcNote "$rigStandPid" ; rigStarted="$rigStarted $rigStandPid"
	disown "$rigStandPid" 2> /dev/null || :
	[ -z "${1:-}" ] || printf '%s claude --verbose --session-id %s --agent rig-member the brief\n' "$rigStandPid" "$( rigId "$1" )" >> "$rigTmp/ps.list"
}
rigTranscript(){ ## short name of the run, true or false -- its transcript as the spawner opens one, whose START line says whether its caller waits on it
	mkdir -p "$rigStores/$( rigId "$1" )"
	printf '2026-10-13T06:00:00Z START session=%s member=keeper-rig service=configured parent=none item=none coworking=%s tracking=%s wait=%s\n' \
		"$( rigId "$1" )" "$( rigId "$1" )" "$( rigId "$1" )" "$2" > "$rigData/audit/session-$( rigId "$1" ).log"
	printf '%s\n' "$rigData/audit/session-$( rigId "$1" ).log" > "$rigStores/$( rigId "$1" )/transcript"
}
rigRc=0
rigScan(){ ## name of its output files -- one take of the lock in the rig workspace: stdout in <name>.out, stderr in <name>.err, the daemon line (descriptor 4) in <name>.fd4
	rigRc=0
	rm -f "$rigData/inboxes/magic-coordinator/incoming/note-20260809T154715Z-advance-state-and-lock.md"
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		bash "$rigTool" "$rigOp" magic-coordinator rig-advance-pass ) > "$rigTmp/$1.out" 2> "$rigTmp/$1.err" 4> "$rigTmp/$1.fd4" < /dev/null || rigRc=$?
}
rigHk(){ ## name of a scan -- the housekeeping lines of its report
	LC_ALL=C grep '^housekeeping: ' "$rigTmp/$1.fd4" 2> /dev/null || :
}
rigSays(){ ## name of a scan, fixed text -- how many lines of its output, its errors and its report hold it
	printf '%s:%s:%s' "$( LC_ALL=C grep -c -F -- "$2" "$rigTmp/$1.out" || : )" "$( LC_ALL=C grep -c -F -- "$2" "$rigTmp/$1.err" || : )" "$( LC_ALL=C grep -c -F -- "$2" "$rigTmp/$1.fd4" || : )"
}
rigTroubles(){ ## name of a scan -- how many lines of its errors are an error or a warning, but for the one every rig of this package gets
	LC_ALL=C grep -E -- 'ERROR|WARNING' "$rigTmp/$1.err" | LC_ALL=C grep -c -v -F -- 'SystemContext.SetInputSpec' || :
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
rigHolder(){ ## short name of a session -- the pid its pid file names, where that is a process that began when the file says
	local holderLine=""
	{ IFS= read -r holderLine < "$rigStores/$( rigId "$1" )/control/pid" ; } 2> /dev/null
	[ -n "$holderLine" ] && [ "$( rigProcBegan "${holderLine%% *}" )" = "$holderLine" ] || return 0
	printf '%s' "${holderLine%% *}"
}
rigHeld(){ ## short name of a session -- a live thread holds it
	[ -n "$( rigHolder "$1" )" ]
}
rigThreads(){ ## short name of a session -- how many processes of this host show as the thread of that session
	"$rigTmp/bin/ps.real" -A -ww -o args= 2> /dev/null | LC_ALL=C grep -c -E -- "DistroAgentsTools\\.fn\\.sh --intern-session-control --run --session-id $( rigId "$1" )\$" || :
}
rigGroup(){ ## pid -- the process group it is in
	"$rigTmp/bin/ps.real" -o pgid= -p "$1" 2> /dev/null | LC_ALL=C tr -d ' '
}
rigMade(){ ## short name of a session -- how many starts the log of its thread holds
	[ -f "$rigStores/$( rigId "$1" )/control/log" ] || { printf '0\n' ; return 0 ; }
	LC_ALL=C grep -c -E -- "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z a start of the control thread of session $( rigId "$1" ) is made: pid [0-9]+, begun [^ ]+\$" "$rigStores/$( rigId "$1" )/control/log" 2> /dev/null || :
}
rigCount(){ ## file -- its lines
	wc -l < "$1" 2> /dev/null | LC_ALL=C tr -d ' '
}
rigOld(){ ## file... -- their time is set twenty minutes back
	touch -t "$( date -v-20M +%Y%m%d%H%M.%S 2> /dev/null || date -d '20 minutes ago' +%Y%m%d%H%M.%S )" "$@"
}
rigStatus(){ ## sandbox (short), record (short) -- the status its record says
	LC_ALL=C sed -n 's/^status: //p' "$rigSp/$( rigId "$1" )/$( rigId "$2" ).spawn.md" 2> /dev/null | LC_ALL=C sed -n '1p'
}

echo "-- 1. the cost: a scan with no thread to start --"
## z: a live run, and a pid file that names a live process begun when it says, as a thread that lives has it: a
## stand-in here, so that nothing but the scan asks anything of the rig's ps. y: ended.
rigRec z z z "$rigHost" spawn-started '' ; rigStand z
rigStand '' ; rigZ="$rigStandPid"
mkdir -p "$rigStores/$( rigId z )/control" ; rigProcBegan "$rigZ" > "$rigStores/$( rigId z )/control/pid"
rigRec y y y "$rigHost" spawn-succeeded "$rigClosed"
rigScan cost
[ "$rigRc" = 0 ] || rigRefuse "the scan failed in the rig, so nothing below would be measured: $( tail -3 "$rigTmp/cost.err" | LC_ALL=C tr '\n' ' ' | cut -c1-500 )"
LC_ALL=C grep -q -x -F -- 'ACQUIRED' "$rigTmp/cost.out" || rigRefuse "the lock was not taken in the rig, so nothing below would be measured"
rigAssert "control: a take asks for the whole process list twice, once for each time its housekeeping measures the rows of the sessions" "$( rigCount "$rigTmp/ps.lists" )" "2"
rigAssert "the check adds no listing to that, and asks once whether the threads its sessions name are still themselves" "$( rigCount "$rigTmp/ps.lists" ):$( rigCount "$rigTmp/ps.asks" )" "2:1"
rigAssert "a session whose thread lives is left alone, and nothing is reported or warned" "$( rigMade z ):$( rigHk cost | LC_ALL=C grep -c . ):$( rigTroubles cost ):$( rigSays cost 'control thread' )" "0:0:0:0:0:0"
rm -rf "$rigStores/$( rigId z )" "$rigSp/$( rigId z )" "$rigSp/$( rigId y )"
LC_ALL=C grep -v -F -- " --session-id $( rigId z ) " "$rigTmp/ps.list" > "$rigTmp/ps.list.new" ; mv -f "$rigTmp/ps.list.new" "$rigTmp/ps.list"

echo "-- 2. a scan starts the thread of a session that has a live run and none --"
rigRec a a a "$rigHost" spawn-started '' ; rigStand a
rigScan first
rigWaitFor 20 rigHeld a
rigA="$( rigHolder a )"
rigAssert "after the scan a control thread runs for that session, one, in a process group of its own, and the scan ended with status 0" \
	"$rigRc:$( rigThreads a ):$( [ -n "$rigA" ] && [ "$( rigGroup "$rigA" )" = "$rigA" ] && echo own ):$( rigMade a )" "0:1:own:1"
rigAssert "what was started is one line of the housekeeping report, which names the session" "$( rigHk first )" "housekeeping: started the control thread of 1 session(s): $( rigId a )"
rigAssert "and no line of the scan's output or of its errors" "$( LC_ALL=C grep -c -F -e 'control thread' -e 'housekeeping' "$rigTmp/first.out" "$rigTmp/first.err" | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/[^ ]*://g' ):$( rigTroubles first )" "0 0 :0"

echo "-- 3. a scan leaves a live thread alone, and its output is as it was --"
rigPidPrint="$( ls -i "$rigStores/$( rigId a )/control/pid" | LC_ALL=C awk '{ print $1 }' ):$( cat "$rigStores/$( rigId a )/control/pid" )"
rigScan second
rigAssert "the thread of that session runs: a second scan leaves its pid file as it was, one thread, one start in its log" \
	"$rigRc:$( ls -i "$rigStores/$( rigId a )/control/pid" | LC_ALL=C awk '{ print $1 }' ):$( cat "$rigStores/$( rigId a )/control/pid" ) $( rigThreads a ) $( rigMade a )" "0:$rigPidPrint 1 1"
rigAssert "with none to start the report holds no line of it" "$( rigHk second | LC_ALL=C grep -c . )" "0"
rigAssert "what the scan prints on standard output is byte for byte the same with a thread to start and with none" "$( cmp -s "$rigTmp/first.out" "$rigTmp/second.out" && echo same || echo different ):$( [ -s "$rigTmp/first.out" ] && echo printed )" "same:printed"

echo "-- 4. which sessions get a thread --"
## d: no run alive and a record of this host still open. c: ended. e: an open record of another host only. f: a live
## run, opened by a start its caller waits on. g: a dead run whose record this same scan closes, by its age. u: an
## open record that names no run, as one written before a run had an id of its own, which no scan closes.
rigRec d d d "$rigHost" spawn-started ''
rigRec d d2 d "$rigHost" spawn-succeeded "$rigClosed"
rigRec c c c "$rigHost" spawn-succeeded "$rigClosed"
rigRec e e e elsewhere spawn-started ''
rigRec f f f "$rigHost" spawn-started '' ; rigStand f ; rigTranscript f true
rigRec g g g "$rigHost" spawn-started '' ; rigOld "$rigSp/$( rigId g )/$( rigId g ).spawn.md"
mkdir -p "$rigSp/$( rigId u )"
printf -- '---\nsession-id: %s\nhost: %s\nworkspace: rigws\nowner: keeper-rig\nstatus: spawn-started\nstarted-at: 2026-09-30 10:00 +0300\n---\n\n# Spawn session: %s\n' "$( rigId u )" "$rigHost" "$( rigId u )" > "$rigSp/$( rigId u )/$( rigId u ).spawn.md"
rigScan which
rigWaitFor 20 rigHeld d
rigAssert "a session with no run alive and a record of this host still open gets its thread, and the report names it alone" \
	"$rigRc:$( rigThreads d ):$( rigHk which | LC_ALL=C grep -F -e 'control thread' )" "0:1:housekeeping: started the control thread of 1 session(s): $( rigId d )"
rigAssert "a finished one, one of another host alone, one whose open record names no run and one that a start its caller waits on opened get none, nor a control folder" \
	"$( rigThreads c ):$( rigThreads e ):$( rigThreads f ):$( rigThreads u ):$( ls -d "$rigStores/$( rigId c )/control" "$rigStores/$( rigId e )/control" "$rigStores/$( rigId f )/control" "$rigStores/$( rigId u )/control" 2> /dev/null | LC_ALL=C grep -c . )" "0:0:0:0:0"
rigAssert "a dead run whose record the same scan closes leaves its session finished: closed first, and no thread" \
	"$( rigStatus g g ):$( rigHk which | LC_ALL=C grep -c -F -e "housekeeping: closed record $( rigId g ) $( rigId g )" ):$( rigThreads g ):$( [ -e "$rigStores/$( rigId g )" ] && echo folder || echo none )" "spawn-ended-without-close:1:0:none"

echo "-- 5. a thread that cannot be started is one warning, and the scan goes on --"
rigRec i i i "$rigHost" spawn-started '' ; rigStand i
mkdir -p "$rigStores/$( rigId i )/control" ; chmod a-w "$rigStores/$( rigId i )/control"
rigScan warned
rigAssert "the folder control/ of a session cannot be written: one warning on the daemon line, none on stderr, and the take ends with status 0" \
	"$rigRc:$( rigTroubles warned ):$( LC_ALL=C grep -c -x -F -- "⚠️ WARNING: DistroAgentsTools $rigOp: the control thread of session $( rigId i ) could not be started: the log of the thread could not be written: $rigStores/$( rigId i )/control/log" "$rigTmp/warned.fd4" )" "0:0:1"
rigAssert "no process was started for it, the report holds no line of it, and the take is whole: it says the lock was taken" \
	"$( rigThreads i ):$( rigHk warned | LC_ALL=C grep -c -F -e 'control thread' ):$( LC_ALL=C grep -c -x -F -e 'ACQUIRED' "$rigTmp/warned.out" )" "0:0:1"
chmod u+w "$rigStores/$( rigId i )/control" ; rm -rf "$rigStores/$( rigId i )" "$rigSp/$( rigId i )"

echo "-- 6. no storm: a session whose thread ends at once --"
## A folder stands where the lock of the thread is made: every thread started for that session ends at once.
rigRec j j j "$rigHost" spawn-started '' ; rigStand j
mkdir -p "$rigStores/$( rigId j )/control/lock"
rigScan storm1
rigAssert "the first scan starts it, and says so in its report" "$rigRc:$( rigMade j ):$( rigHk storm1 | LC_ALL=C grep -F -e 'control thread' )" "0:1:housekeeping: started the control thread of 1 session(s): $( rigId j )"
sleep 2
rigAssert "control: that thread has ended at once, and said why in its log" "$( rigThreads j ):$( LC_ALL=C grep -c -F -- "could not take the lock of session $( rigId j )" "$rigStores/$( rigId j )/control/log" )" "0:1"
rigScan storm2 ; rigScan storm3 ; rigScan storm4
rigAssert "three scans after it leave the session alone: one start in its log still, no thread" "$( rigMade j ):$( rigThreads j )" "1:0"
rigAssert "and in silence: no line of a report, no warning, status 0" \
	"$rigRc:$( cat "$rigTmp/storm2.fd4" "$rigTmp/storm3.fd4" "$rigTmp/storm4.fd4" | LC_ALL=C grep -c -F -e 'control thread' ):$( rigTroubles storm2 ):$( rigTroubles storm3 ):$( rigTroubles storm4 )" "0:0:0:0:0"
rigOld "$rigStores/$( rigId j )/control/log"
rigScan storm5
rigAssert "once the last line of its log is five minutes old, a scan starts it once more" "$rigRc:$( rigMade j ):$( rigHk storm5 | LC_ALL=C grep -F -e 'control thread' )" "0:2:housekeeping: started the control thread of 1 session(s): $( rigId j )"

echo "-- 7. nothing is left running, and nothing was asked of the network --"
rigThreadsEnd
rigProcSignalWithChildren KILL $rigStarted
sleep 1
rigAssert "every thread a scan of this check started is ended: no process of this host shows as a thread of one of its sessions" \
	"$( "$rigTmp/bin/ps.real" -A -ww -o args= 2> /dev/null | LC_ALL=C grep -c -E -- "--intern-session-control --run --session-id [a-z0-9]+-$rigTag\$" || : )" "0"
rigAssert "no request was made" "$( [ -e "$rigTmp/curl.calls" ] && echo called || echo none )" "none"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SESSION CONTROL SCAN CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_CONTROL_SCAN: OK (%d assertions, offline)\n' "$rigPasses"
