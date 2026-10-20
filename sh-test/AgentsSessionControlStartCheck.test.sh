#!/usr/bin/env bash
## Behavioural check on how the control thread of a session is started again from the console,
## --manager-session-control-start (--session-id <id>|--all), and on the one function every starter of a thread
## calls (AgentsToolsSessionControlStart, sh-lib/session/AgentsTools.SessionControlStart.include), run rather than read,
## against a rig workspace built here: spawn records, session stores and a process list of the rig's own. A ps
## first on PATH lists the rig's runs only, stand-in processes under their own pids, never a real CLI; a curl
## beside it only logs, and nothing may call it.
## Held:
##   1. ONE SESSION BY NAME. A session with a live run whose thread is dead gets its thread again: one `control`
##      row, `started` with the process, and that process is the thread, shown in the process list by its
##      operation and its session, in a process group of its own, a hangup ignored. The lock a dead thread left
##      is taken over. A thread that lives is left alone: `alive` with its process, nothing started, status 0.
##   2. THE CHECK NOW, --all: a row for each session that needed a thread and had none alive, and for no other.
##      A session needs one while it is not finished: a run of it alive on this host, or the record of a run of
##      this host still open. Not a finished one, not one of another host alone, not one whose open record names
##      no run, which nothing can measure, and not one that a start its caller waits on opened (told by the START
##      line of the transcript of its run, `wait=true`).
##   3. NO STORM. The check leaves a session alone for five minutes after the last line of the log of its thread:
##      a thread that has just ended is not started again at once; once the log is older, it is. A start by name
##      is made at once.
##   4. BY NAME, A SESSION THAT GETS NONE: a finished one and a waited one are `not-needed`, status 0, and keep nothing of a thread that died: its pid file and its lock are removed, never those of a thread that lives; one of
##      another host alone, and one whose open record names no run, are said so, status 1; an id no record
##      carries is one error line, status 1. The own id of a run names its session.
##   5. TWO CALLS AT ONCE leave one thread: one is `started`, the other is told `alive`.
##   6. A THREAD THAT CANNOT BE STARTED is `not-started` with the reason: a log that cannot be written, said
##      before any process is started; and a start the thread itself refuses, whose reason is read from its log.
##   7. THE ONE FUNCTION, on a stand-in for the tooling script: it answers at once and waits for nothing; what it
##      starts has the operation and the session as its arguments, a process group of its own, a hangup ignored,
##      its input /dev/null, its output in control/log, no descriptor of its starter and no name of a member's
##      session in its environment. `alive` where a thread lives; `failed` for an id that names nothing, and no
##      folder is made for it.
##   8. The caller rule of the family, the syntax, the help pair, and the form of every row.
##   9. THE GUARD OVER sh-test. A thread is a detached process that outlives the check, and one whose rig is
##      removed never ends by itself. So every check that names an operation which starts control threads, the
##      advance input scan, the main loop, this one or one of the spawner's, ends the threads of its rig in its EXIT trap, through
##      sh-test/check-fixtures/rig-control-threads.include.sh, which this check holds too: a new check that
##      names one and does not fails here.
## Red before the operation existed: every assertion but the controls. Offline: only the rig's own tree is read or
## written, and every thread and stand-in this check starts is ended by it, through the rig's process helper.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigOp="--manager-session-control-start"
rigSyntax="(--session-id <id>|--all)"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
## And the control threads the tooling starts in this rig are ended by it, each only while it is still the process that was started.
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionControlStartCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## The ids of this run's sessions carry the name mktemp gave it, so that a copy of this check that runs beside it never counts this one's threads.
rigTag="${rigTmp##*.}" ; rigTag="$( printf '%s' "$rigTag" | LC_ALL=C tr -c -d 'A-Za-z0-9' )"
[ -n "$rigTag" ] || rigRefuse "the rig has no name of its own to tell its sessions by"
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data"
rigAgents="$rigWs/.local/agents"
rigSp="$rigAgents/spawned" ; rigStores="$rigAgents/sessions"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigSp" "$rigStores" "$rigHome" "$rigSkills" "$rigData/board/running" "$rigData/audit"
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

## THE RIG'S OWN PROCESS LIST, as AgentsSessionControlStateCheck keeps it: the ps first on PATH answers the
## whole-host listing from the rig's own list, one `<pid> <command line>` line a process, each listed only while it
## lives, and hands every other call to the real ps.
ln -s "$( command -v ps )" "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
: > "$rigTmp/ps.list"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*)
		case "$*" in *ppid=*) exec "${0%/*}/ps.real" "$@" ;; esac
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
		&& mv -f "$rigSp/$( rigId "$1" )/$( rigId "$2" ).md.rig" "$rigSp/$( rigId "$1" )/$( rigId "$2" ).md"
}
rigClosed='resolved-at: 2026-10-13 09:30 +0300
'
## A stand-in process under its own pid that only waits; with a name given it stands in the rig's process list as
## the run of that spawn, by its own --session-id word. Sets rigStandPid.
rigStandPid=""
rigStand(){ ## short name of the run (may be empty)
	sleep 600 > /dev/null 2>&1 < /dev/null &
	rigStandPid=$!
	rigProcNote "$rigStandPid" ; rigStarted="$rigStarted $rigStandPid"
	disown "$rigStandPid" 2> /dev/null || :
	[ -z "${1:-}" ] || printf '%s claude --verbose --session-id %s --agent rig-member the brief\n' "$rigStandPid" "$( rigId "$1" )" >> "$rigTmp/ps.list"
}
## The transcript of a run as the spawner opens one: its first line, START, says whether its caller waits on it.
rigTranscript(){ ## short name of the run, true or false
	mkdir -p "$rigStores/$( rigId "$1" )"
	printf '2026-10-13T06:00:00Z START session=%s member=keeper-rig service=configured parent=none item=none coworking=%s tracking=%s wait=%s\n' \
		"$( rigId "$1" )" "$( rigId "$1" )" "$( rigId "$1" )" "$2" > "$rigData/audit/session-$( rigId "$1" ).log"
	printf '%s\n' "$rigData/audit/session-$( rigId "$1" ).log" > "$rigStores/$( rigId "$1" )/transcript"
}
rigRc=0 rigPre=() rigKept=0
rigRun(){ ## tool arguments... -- one dispatcher call in the rig workspace; rc in rigRc, stdout in out, stderr in err
	rigRc=0
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		${rigPre[@]+"${rigPre[@]}"} bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
	## Every output of the operation is kept, for the check of its rows against the form its help entry gives.
	rigKept=$(( rigKept + 1 ))
	[ "${1:-}" != "$rigOp" ] || cp "$rigTmp/out" "$rigTmp/out.kept.$rigKept"
}
rigOut(){ ## -- the last stdout, TAB written as `|`
	LC_ALL=C tr '\t' '|' < "$rigTmp/out"
}
rigRows(){ ## -- how many lines the last stdout holds
	wc -l < "$rigTmp/out" | LC_ALL=C tr -d ' '
}
rigRowOf(){ ## short name of a session -- its row of the last stdout, TAB written as `|`
	LC_ALL=C awk -F'\t' -v wantId="$( rigId "$1" )" '$1 == "control" && $2 == wantId { gsub( /\t/, "|" ) ; print ; }' "$rigTmp/out"
}
rigField(){ ## short name of a session, field number -- that field of its row
	LC_ALL=C awk -F'\t' -v wantId="$( rigId "$1" )" -v wantField="$2" '$1 == "control" && $2 == wantId { print $wantField ; }' "$rigTmp/out"
}
rigTroubles(){ ## -- how many lines of the last stderr are an error or a warning, but for the one every rig of this package gets
	LC_ALL=C grep -E -- 'ERROR|WARNING' "$rigTmp/err" | LC_ALL=C grep -c -v -F -- 'SystemContext.SetInputSpec' || :
}
rigSaid(){ ## fixed text -- how many lines of the last stderr hold it
	LC_ALL=C grep -c -F -- "$1" "$rigTmp/err" || :
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
	## A subshell of the thread shows the thread's own command line while it lives, and under load one often stands
	## beside it: a thread is counted once, by the process of that command line whose parent has another one.
	## The command line looked for is handed in the environment, so this reader's own never holds it.
	"$rigTmp/bin/ps.real" -A -ww -o pid=,ppid=,args= 2> /dev/null | RIG_THREAD_ARGS="DistroAgentsTools.fn.sh --intern-session-control --run --session-id $( rigId "$1" )" LC_ALL=C awk '
		BEGIN { want = ENVIRON["RIG_THREAD_ARGS"] }
		{ line = $0 ; sub( /^[ \t]*[0-9]+[ \t]+[0-9]+[ \t]+/, "", line ) ; at = length( line ) - length( want ) + 1 }
		at >= 1 && substr( line, at ) == want && ( at == 1 || substr( line, at - 1, 1 ) ~ /[ \/]/ ) { parent[$1] = $2 }
		END { n = 0 ; for ( p in parent ) if ( !( parent[p] in parent ) ) n++ ; print n }'
}
rigArgs(){ ## pid -- its command line
	"$rigTmp/bin/ps.real" -ww -o args= -p "$1" 2> /dev/null
}
rigGroup(){ ## pid -- the process group it is in
	"$rigTmp/bin/ps.real" -o pgid= -p "$1" 2> /dev/null | LC_ALL=C tr -d ' '
}
rigMade(){ ## short name of a session -- how many starts the log of its thread holds
	[ -f "$rigStores/$( rigId "$1" )/control/log" ] || { printf '0\n' ; return 0 ; }
	LC_ALL=C grep -c -E -- "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z a start of the control thread of session $( rigId "$1" ) is made: pid [0-9]+, begun [^ ]+\$" "$rigStores/$( rigId "$1" )/control/log" 2> /dev/null || :
}
rigLogHas(){ ## short name of a session, fixed text -- how many lines of its log hold it
	LC_ALL=C grep -c -F -- "$2" "$rigStores/$( rigId "$1" )/control/log" 2> /dev/null || :
}
rigState(){ ## short name of a session -- the word of its state file
	LC_ALL=C sed -n 's/^state: //p' "$rigStores/$( rigId "$1" )/control/state" 2> /dev/null | LC_ALL=C sed -n '1p'
}
rigStateIs(){ ## short name of a session, word
	[ "$( rigState "$1" )" = "$2" ]
}
rigEndThread(){ ## short name of a session -- its thread is ended the hard way, as a thread that died
	local endPid
	endPid="$( rigHolder "$1" )"
	[ -n "$endPid" ] || return 0
	rigProcNoteFrom "$rigStores/$( rigId "$1" )/control/pid"
	rigProcSignalWithChildren KILL "$endPid"
	rigWaitFor 10 rigEnded "$endPid"
}
rigOld(){ ## file -- its time is set ten minutes back
	touch -t "$( date -v-10M +%Y%m%d%H%M.%S 2> /dev/null || date -d '10 minutes ago' +%Y%m%d%H%M.%S )" "$1"
}

echo "-- 1. one session by name: a live run and a dead thread --"
rigRec a a a "$rigHost" spawn-started ''
rigRec a a2 a "$rigHost" spawn-started ''
rigStand a ; rigStand a2
## What a thread that was ended the hard way leaves: its pid file and its lock, naming a process that is gone.
rigStand '' ; rigGonePid="$rigStandPid" ; rigGone="$( rigProcBegan "$rigGonePid" )"
rigProcSignal KILL "$rigGonePid" ; rigWaitFor 10 rigEnded "$rigGonePid"
mkdir -p "$rigStores/$( rigId a )/control"
printf '%s\n' "$rigGone" > "$rigStores/$( rigId a )/control/pid"
ln -s "$rigGone" "$rigStores/$( rigId a )/control/lock"
rigAssert "control: the pid file of that session names a process that is gone, and no thread shows for it" "$( rigHolder a ):$( rigThreads a )" ":0"
rigRun "$rigOp" --session-id "$( rigId a )"
rigA="$( rigField a 4 )"
rigAssert "a session with a live run and a dead thread: one control row, started, with the process, and status 0" \
	"$rigRc:$( rigTroubles ):$( rigRows ):$( rigOut | LC_ALL=C sed 's/|[0-9][0-9]*|/|PID|/' )" "0:0:1:control|$( rigId a )|started|PID|-"
rigAssert "that process is the thread: the pid file of the session names it, and one process shows as the thread of that session" "$( rigHolder a ):$( rigThreads a )" "$rigA:1"
rigAssert "it shows in the process list by the tooling script, its operation and its session" \
	"$( rigArgs "$rigA" | LC_ALL=C grep -c -F -- "$rigTool --intern-session-control --run --session-id $( rigId a )" )" "1"
rigAssert "it is in a process group of its own, not the one this check runs in" "$( [ -n "$rigA" ] && [ "$( rigGroup "$rigA" )" = "$rigA" ] && echo own || echo "[$( rigGroup "${rigA:-0}" )]" ):$( [ -n "$rigA" ] && [ "$( rigGroup "$rigA" )" != "$( rigGroup "$$" )" ] && echo apart || echo shared )" "own:apart"
rigAssert "the lock the dead thread left is taken over, and the log of the thread says whose it was" \
	"$( readlink "$rigStores/$( rigId a )/control/lock" | LC_ALL=C awk '{ print $1 }' ):$( rigLogHas a "took over the lock of pid $rigGonePid, which is gone" )" "$rigA:1"
rigAssert "the log holds the one start, with the process it made and when that process began" "$( rigMade a ):$( rigLogHas a "is made: pid $rigA, begun $( rigProcBegan "$rigA" | LC_ALL=C awk '{ print $2 }' )" )" "1:1"
rigWaitFor 10 rigStateIs a running
rigAssert "the thread watches: the state of the session reads running" "$( rigState a )" "running"
rigProcNoteFrom "$rigStores/$( rigId a )/control/pid"
rigProcSignal HUP "$rigA" ; sleep 1
rigAssert "a hangup does not end it" "thread:$( rigHolder a )" "${rigA:+thread}:$rigA"

echo "-- 2. a thread that lives is left alone --"
rigPidPrint="$( ls -i "$rigStores/$( rigId a )/control/pid" | LC_ALL=C awk '{ print $1 }' ):$( cat "$rigStores/$( rigId a )/control/pid" )"
rigRun "$rigOp" --session-id "$( rigId a )"
rigAssert "a session whose thread is alive: alive with its process, status 0, no error" "$rigRc:$( rigTroubles ):$( rigRows ):$( rigOut )" "0:0:1:control|$( rigId a )|alive|$rigA|-"
rigAssert "nothing was started: the pid file is as it was, one thread shows, and the log holds its one start" \
	"$( ls -i "$rigStores/$( rigId a )/control/pid" | LC_ALL=C awk '{ print $1 }' ):$( cat "$rigStores/$( rigId a )/control/pid" ) $( rigThreads a ) $( rigMade a )" "$rigPidPrint 1 1"
rigRun "$rigOp" --session-id "$( rigId a2 )"
rigAssert "the own id of a run that joined a session names that session" "$rigRc:$( rigOut )" "0:control|$( rigId a )|alive|$rigA|-"

echo "-- 3. the check now: --all --"
## b: a live run and no thread. c: ended. d: no run alive and a record of this host still open. e: open records of
## another host only. f: a live run, opened by a start its caller waits on. u: an open record that names no run, as
## one written before a run had an id of its own.
rigRec b b b "$rigHost" spawn-started '' ; rigStand b
rigRec c c c "$rigHost" spawn-succeeded "$rigClosed"
rigRec c c2 c "$rigHost" spawn-failed "$rigClosed"
rigRec d d d "$rigHost" spawn-started ''
rigRec d d2 d "$rigHost" spawn-succeeded "$rigClosed"
rigRec e e e elsewhere spawn-started ''
rigRec f f f "$rigHost" spawn-started '' ; rigStand f ; rigTranscript f true
rigTranscript b false
mkdir -p "$rigSp/$( rigId u )"
printf -- '---\nsession-id: %s\nhost: %s\nworkspace: rigws\nowner: keeper-rig\nstatus: spawn-started\nstarted-at: 2026-09-30 10:00 +0300\n---\n\n# Spawn session: %s\n' "$( rigId u )" "$rigHost" "$( rigId u )" > "$rigSp/$( rigId u )/$( rigId u ).md"
rigRun "$rigOp" --all
rigAssert "--all prints a row for each session that needed a thread and had none alive, started, and for no other: not the one whose thread lives, the ended one, the one of another host, the one a waited start opened, the one whose open record names no run" \
	"$rigRc:$( rigTroubles ):$( rigOut | LC_ALL=C sed 's/|[0-9][0-9]*|/|PID|/' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "0:0:control|$( rigId b )|started|PID|- control|$( rigId d )|started|PID|- "
rigAssert "a thread runs for each of the two, and each row names it" "$( rigThreads b ):$( rigThreads d ):$( [ "$( rigHolder b )" = "$( rigField b 4 )" ] && echo named ):$( [ "$( rigHolder d )" = "$( rigField d 4 )" ] && echo named )" "1:1:named:named"
rigAssert "and no thread for the others, nor a control folder: one thread for the first still, none for the four" \
	"$( rigThreads a ):$( rigThreads c ):$( rigThreads e ):$( rigThreads f ):$( rigThreads u ):$( ls -d "$rigStores/$( rigId c )/control" "$rigStores/$( rigId e )/control" "$rigStores/$( rigId f )/control" "$rigStores/$( rigId u )/control" 2> /dev/null | LC_ALL=C grep -c . )" "1:0:0:0:0:0"
rigWaitFor 10 rigStateIs b running
rigAssert "the thread of the session with no run alive and an open record stays, and that of the live one reads running" "$( rigHolder d | LC_ALL=C grep -c . ):$( rigState b )" "1:running"
rigRun "$rigOp" --all
rigAssert "a second check finds nothing to start: no row, a note, status 0" "$rigRc:$( rigRows ):$( rigTroubles ):$( rigSaid 'no session of this workspace needs its control thread started, so nothing was started' )" "0:0:0:1"

echo "-- 4. no storm: a thread that has just ended is not started again at once --"
rigBefore="$( rigHolder b )"
rigEndThread b
rigRun "$rigOp" --all
rigAssert "the thread of a session ends, and a check right after leaves the session alone: not-started, with the reason, status 0, and no process" \
	"$rigRc:$( rigTroubles ):$( rigRows ):$( rigOut | LC_ALL=C sed 's/written [0-9]* seconds ago/written N seconds ago/' ):$( rigThreads b ):$( rigMade b )" \
	"0:0:1:control|$( rigId b )|not-started|-|the log of its thread was written N seconds ago, and a check starts the thread of one session once in 300 seconds at most: a thread that has just ended is not started again at once:0:1"
rigRun "$rigOp" --all ; rigRun "$rigOp" --all
rigAssert "nor do two more checks: still one start in its log, and no thread" "$( rigMade b ):$( rigThreads b )" "1:0"
rigOld "$rigStores/$( rigId b )/control/log"
rigRun "$rigOp" --all
rigAssert "once the last line of its log is older than five minutes, the check starts it again" \
	"$rigRc:$( rigOut | LC_ALL=C sed 's/|[0-9][0-9]*|/|PID|/' ):$( rigThreads b ):$( rigMade b ):$( [ -n "$( rigHolder b )" ] && [ "$( rigHolder b )" != "$rigBefore" ] && echo another-process )" "0:control|$( rigId b )|started|PID|-:1:2:another-process"
rigEndThread d
rigRun "$rigOp" --session-id "$( rigId d )"
rigAssert "a start by name is made at once, whatever the time of the log" "$rigRc:$( rigOut | LC_ALL=C sed 's/|[0-9][0-9]*|/|PID|/' ):$( rigThreads d ):$( rigMade d )" "0:control|$( rigId d )|started|PID|-:1:2"

echo "-- 5. by name, a session that gets none --"
rigRun "$rigOp" --session-id "$( rigId c )"
rigAssert "a finished session needs none: not-needed, status 0, no folder made and no process" \
	"$rigRc:$( rigTroubles ):$( rigOut ):$( rigThreads c ):$( [ -e "$rigStores/$( rigId c )" ] && echo folder || echo none )" "0:0:control|$( rigId c )|not-needed|-|every run of it has closed its record, and a finished session needs no thread:0:none"
## WHAT A THREAD THAT DIED LEFT IN A SESSION THAT HAS FINISHED: its pid file and its lock, each naming a process
## that is gone, beside the log of the thread and the state it kept. The list shows such a session as one whose
## thread is gone, for good: nothing starts a thread there again that would take them over. So the start that
## answers that the session needs none removes those two, and nothing else.
rigListed(){ ## short name of a session -- the word the list of sessions shows for its control thread
	rigRun --manager-session-list
	LC_ALL=C awk -F'\t' -v wantId="$( rigId "$1" )" '$1 == "session" && $2 == wantId { print $11 }' "$rigTmp/out"
}
rigStand '' ; rigLeftPid="$rigStandPid" ; rigLeft="$( rigProcBegan "$rigLeftPid" )"
rigProcSignal KILL "$rigLeftPid" ; rigWaitFor 10 rigEnded "$rigLeftPid"
rigLeftDir="$rigStores/$( rigId c )/control"
mkdir -p "$rigLeftDir"
printf '%s\n' "$rigLeft" > "$rigLeftDir/pid" ; ln -s "$rigLeft" "$rigLeftDir/lock"
printf 'the log of the thread that died\n' > "$rigLeftDir/log" ; printf 'finished\n' > "$rigLeftDir/state"
rigAssert "control: a finished session whose thread died reads gone in the list of sessions, by the pid file and the lock it left" "$( rigListed c )" "gone"
rigRun "$rigOp" --session-id "$( rigId c )"
rigAssert "a finished session whose thread died: not-needed as before, and the pid file and the lock, which name a process that is gone, are removed" \
	"$rigRc:$( rigTroubles ):$( rigOut ):$( [ -e "$rigLeftDir/pid" ] && echo pid || echo no-pid ):$( [ -L "$rigLeftDir/lock" ] && echo lock || echo no-lock )" "0:0:control|$( rigId c )|not-needed|-|every run of it has closed its record, and a finished session needs no thread:no-pid:no-lock"
rigAssert "nothing else of its control folder is touched, and nothing was started: the log and the state stand as they were" \
	"$( cat "$rigLeftDir/log" 2> /dev/null ):$( cat "$rigLeftDir/state" 2> /dev/null ):$( ls "$rigLeftDir" 2> /dev/null | LC_ALL=C tr '\n' ' ' ):$( rigThreads c )" "the log of the thread that died:finished:log state :0"
rigAssert "the session then reads none in the list of sessions" "$( rigListed c )" "none"
## The files of a thread that lives are never touched: a finished session whose pid file and lock name a live process
## has a thread, and is told alive; and so it is where only its lock names that process, and its pid file one that is gone.
rigRec g g g "$rigHost" spawn-succeeded "$rigClosed"
rigStand '' ; rigLivePid="$rigStandPid" ; rigLive="$( rigProcBegan "$rigLivePid" )"
rigLiveDir="$rigStores/$( rigId g )/control"
mkdir -p "$rigLiveDir"
printf '%s\n' "$rigLive" > "$rigLiveDir/pid" ; ln -s "$rigLive" "$rigLiveDir/lock"
rigRun "$rigOp" --session-id "$( rigId g )"
rigAssert "a finished session whose pid file and lock name a process that lives: alive, and both stand as they were" \
	"$rigRc:$( rigOut ):$( cat "$rigLiveDir/pid" 2> /dev/null ):$( readlink "$rigLiveDir/lock" 2> /dev/null )" "0:control|$( rigId g )|alive|$rigLivePid|-:$rigLive:$rigLive"
printf '%s\n' "$rigLeft" > "$rigLiveDir/pid"
rigRun "$rigOp" --session-id "$( rigId g )"
rigAssert "nor is either removed where the lock alone names the process that lives, and the pid file one that is gone" \
	"$rigRc:$( rigOut ):$( cat "$rigLiveDir/pid" 2> /dev/null ):$( readlink "$rigLiveDir/lock" 2> /dev/null )" "0:control|$( rigId g )|alive|$rigLivePid|-:$rigLeft:$rigLive"
rigRun "$rigOp" --session-id "$( rigId f )"
rigAssert "nor does one that a start its caller waits on opened, though its run is alive" \
	"$rigRc:$( rigTroubles ):$( rigOut ):$( rigThreads f )" "0:0:control|$( rigId f )|not-needed|-|the start that opened it is one its caller waits on, and that caller watches it:0"
mkdir -p "$rigStores/$( rigId f )/control"
printf '%s\n' "$rigLeft" > "$rigStores/$( rigId f )/control/pid" ; ln -s "$rigLeft" "$rigStores/$( rigId f )/control/lock"
rigRun "$rigOp" --session-id "$( rigId f )"
rigAssert "a session its starter waits on needs none either, and keeps nothing of a thread that died: not-needed, and both are removed" \
	"$rigRc:$( rigOut | LC_ALL=C cut -d '|' -f 3 ):$( [ -e "$rigStores/$( rigId f )/control/pid" ] && echo pid || echo no-pid ):$( [ -L "$rigStores/$( rigId f )/control/lock" ] && echo lock || echo no-lock ):$( rigThreads f )" "0:not-needed:no-pid:no-lock:0"
rigRun "$rigOp" --session-id "$( rigId e )"
rigAssert "a session of another host alone gets none: its row says whose its runs are, status 1, nothing started" \
	"$rigRc:$( rigOut ):$( rigSaid '1 control thread(s) could not be started' ):$( rigThreads e ):$( [ -e "$rigStores/$( rigId e )" ] && echo folder || echo none )" "1:control|$( rigId e )|not-started|-|its open records are runs of another host (elsewhere), which cannot be watched from here:1:0:none"
rigRun "$rigOp" --session-id "$( rigId u )"
rigAssert "nor does one whose open record names no run, which nothing can tell alive or gone: said so, status 1, nothing started" \
	"$rigRc:$( rigOut ):$( rigThreads u ):$( [ -e "$rigStores/$( rigId u )" ] && echo folder || echo none )" "1:control|$( rigId u )|not-started|-|its open records name no host or no run, so that no run of it can be told alive or gone from here:0:none"
rigRun "$rigOp" --session-id "$( rigId nobody )"
rigAssert "an id no record carries: one error line, nothing printed, nothing started, status 1" \
	"$rigRc:$( rigRows ):$( rigTroubles ):$( rigSaid "no record of this workspace carries '$( rigId nobody )' as the id of a session or the own id of a run -- nothing was started" ):$( [ -e "$rigStores/$( rigId nobody )" ] && echo folder || echo none )" "1:0:1:1:none"

echo "-- 6. two calls at once leave one thread --"
rigRec h h h "$rigHost" spawn-started '' ; rigStand h
for rigCall in 1 2 ; do
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash "$rigTool" "$rigOp" --session-id "$( rigId h )" ) > "$rigTmp/twice.$rigCall.out" 2> "$rigTmp/twice.$rigCall.err" < /dev/null &
done
wait
cat "$rigTmp/twice.1.out" "$rigTmp/twice.2.out" > "$rigTmp/out" ; cp "$rigTmp/out" "$rigTmp/out.kept.twice"
rigAssert "two calls at the same moment for one session with no thread: one thread runs, one call started it and the other is told it is alive, both naming that process" \
	"$( rigThreads h ):$( LC_ALL=C awk -F'\t' '{ print $3 }' "$rigTmp/out" | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' ):$( LC_ALL=C awk -F'\t' '{ print $4 }' "$rigTmp/out" | LC_ALL=C sort -u | LC_ALL=C grep -c . ):$( [ "$( rigHolder h )" = "$( LC_ALL=C awk -F'\t' 'NR == 1 { print $4 }' "$rigTmp/out" )" ] && echo holder )" "1:alive started :1:holder"

echo "-- 7. a thread that cannot be started says why --"
rigRec i i i "$rigHost" spawn-started '' ; rigStand i
mkdir -p "$rigStores/$( rigId i )/control" ; chmod a-w "$rigStores/$( rigId i )/control"
rigRun "$rigOp" --session-id "$( rigId i )"
rigAssert "a log that cannot be written: not-started with the reason, status 1, and no process was started for it" \
	"$rigRc:$( rigOut ):$( rigSaid '1 control thread(s) could not be started -- see the not-started row(s)' ):$( rigThreads i )" "1:control|$( rigId i )|not-started|-|the log of the thread could not be written: $rigStores/$( rigId i )/control/log:1:0"
rigRun "$rigOp" --all
rigAssert "the check says the same of it in its row, status 1, and starts nothing else" "$rigRc:$( rigRows ):$( rigRowOf i | LC_ALL=C cut -d '|' -f 3-4 ):$( rigThreads i )" "1:1:not-started|-:0"
chmod u+w "$rigStores/$( rigId i )/control" ; rm -rf "$rigStores/$( rigId i )" ; rm -rf "$rigSp/$( rigId i )"
## A start the thread itself refuses: a folder stands where its lock is made.
rigRec j j j "$rigHost" spawn-started '' ; rigStand j
mkdir -p "$rigStores/$( rigId j )/control/lock"
rigRun "$rigOp" --session-id "$( rigId j )"
rigAssert "a start the thread refuses: not-started, the reason the thread gave in its log, status 1, and no process is left" \
	"$rigRc:$( rigOut ):$( rigThreads j ):$( rigMade j )" "1:control|$( rigId j )|not-started|-|DistroAgentsTools --intern-session-control: could not take the lock of session $( rigId j ) at $rigStores/$( rigId j )/control/lock -- nothing was started:0:1"
rigRun "$rigOp" --all
rigAssert "and a check right after does not start it a second time: the session is left alone, one start in its log" "$rigRc:$( rigRowOf j | LC_ALL=C cut -d '|' -f 3-4 ):$( rigMade j ):$( rigThreads j )" "0:not-started|-:1:0"
rm -rf "$rigStores/$( rigId j )" "$rigSp/$( rigId j )"

echo "-- 8. the one function, on a stand-in for the tooling script --"
## What a starter that is no console calls: the spawner when it opens a session. The stand-in says what it was
## started with, and then only waits.
rigFake="$rigTmp/fake-origin" ; mkdir -p "$rigFake/myx/myx.distro-agents/sh-scripts"
cat > "$rigFake/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" <<'RIGTOOL'
#!/bin/sh
rigSay="$RIG_TMP/stand-in.$$"
{
	printf 'args: %s\n' "$*"
	env | LC_ALL=C grep -E '^(MDAT_SPAWN_[A-Z_]*|MDAT_SESSION_ID|MDAT_SESSION_THREAD|MDAT_CONVERSATION_THREADS|harnessSessionId|harnessAgent|CLAUDE_CODE_SESSION_ID)=' | LC_ALL=C sed 's/^/env: /'
	env | LC_ALL=C grep -E '^(MMDAPP|RIG_KEPT)=' | LC_ALL=C sed 's/=.*$//' | LC_ALL=C sed 's/^/kept: /'
	for rigFd in 5 9 ; do ( : >&"$rigFd" ) 2> /dev/null && printf 'descriptor %s: open\n' "$rigFd" || printf 'descriptor %s: closed\n' "$rigFd" ; done
	[ /dev/fd/0 -ef /dev/null ] && printf 'input: /dev/null\n' || printf 'input: other\n'
} > "$rigSay"
echo "the stand-in $$ speaks on its output"
echo "the stand-in $$ speaks on its errors" >&2
exec sleep 600
RIGTOOL
chmod +x "$rigFake/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigCall(){ ## short name of a session -- the function alone, called as a starter inside a member's session calls it; its answer in fn.out
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_FAKE="$rigFake" RIG_KEPT=yes \
		MDAT_SPAWN_SESSION_ID=rig-spawn MDAT_SPAWN_AGENT=keeper-rig MDAT_SPAWN_SANDBOX_ROOT=/rig/sandbox MDAT_SESSION_ID=rig-session MDAT_SESSION_THREAD=CRIG:1.2 MDAT_CONVERSATION_THREADS=CRIG:3.4 \
		harnessSessionId=rig-harness harnessAgent=keeper-rig CLAUDE_CODE_SESSION_ID=rig-client \
		bash -c '
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.Registries.include" || exit 90
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionControlStart.include" || exit 91
			MDLT_ORIGIN="$RIG_FAKE"
			exec 5> "$RIG_TMP/fn.fd5" 9> "$RIG_TMP/fn.fd9"
			fnFrom="$SECONDS"
			AgentsToolsSessionControlStart "$1" ; fnRc=$?
			printf "rc %s seconds %s monitor %s\n" "$fnRc" "$(( SECONDS - fnFrom ))" "$( case "$-" in (*m*) echo on ;; (*) echo off ;; esac )"
		' rig-fn "$( rigId "$1" )" ) > "$rigTmp/fn.out" 2> "$rigTmp/fn.err" < /dev/null
}
rigRec k k k "$rigHost" spawn-started ''
mkdir -p "$rigStores/$( rigId k )"
rigCall k
rigK="$( LC_ALL=C sed -n '1s/^started //p' "$rigTmp/fn.out" )"
rigAssert "it answers started with the process, status 0, and at once, though what it started goes on for minutes; the job control of its caller is as it was" \
	"$( LC_ALL=C sed -n '1s/ [0-9][0-9]*$/ PID/p' "$rigTmp/fn.out" ):$( LC_ALL=C sed -n '2p' "$rigTmp/fn.out" | LC_ALL=C awk '{ print $1, $2, ( $4 <= 3 ? "at-once" : $4 ), $5, $6 }' )" "started PID:rc 0 at-once monitor off"
rigWaitFor 10 test -f "$rigTmp/stand-in.$rigK"
rigProcNoteFrom <( rigControlThreadNotes "$rigTmp" )
rigAssert "what it started is the tooling script with the operation and the session as its arguments, alive, in a process group of its own" \
	"$( LC_ALL=C sed -n 's/^args: //p' "$rigTmp/stand-in.$rigK" 2> /dev/null ):$( rigEnded "$rigK" && echo ended || echo alive ):$( [ "$( rigGroup "$rigK" )" = "$rigK" ] && echo own || echo "$( rigGroup "$rigK" )" )" "--intern-session-control --run --session-id $( rigId k ):alive:own"
rigAssert "no name of a member's session is in its environment, and the workspace and what else its starter had are" \
	"$( LC_ALL=C grep -c '^env: ' "$rigTmp/stand-in.$rigK" 2> /dev/null ):$( LC_ALL=C sed -n 's/^kept: //p' "$rigTmp/stand-in.$rigK" 2> /dev/null | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "0:MMDAPP RIG_KEPT "
rigAssert "no descriptor of its starter is open in it, and its input is /dev/null" \
	"$( LC_ALL=C grep -E '^(descriptor|input)' "$rigTmp/stand-in.$rigK" 2> /dev/null | LC_ALL=C tr '\n' ';' )" "descriptor 5: closed;descriptor 9: closed;input: /dev/null;"
rigAssert "its output and its errors are the log of the thread, beside the line of the start" \
	"$( rigLogHas k "the stand-in $rigK speaks on its output" ):$( rigLogHas k "the stand-in $rigK speaks on its errors" ):$( rigMade k )" "1:1:1"
rigProcSignal HUP "$rigK" ; sleep 1
rigAssert "a hangup does not end what it started" "$( rigEnded "$rigK" && echo ended || echo alive )" "alive"
## A thread that lives: the pid file of the session names a live process, begun when the file says.
rigProcBegan "$rigK" > "$rigStores/$( rigId k )/control/pid"
rigCall k
rigAssert "while a thread lives it starts nothing and answers alive, which is no error" \
	"$( LC_ALL=C sed -n '1p' "$rigTmp/fn.out" ):$( LC_ALL=C sed -n '2p' "$rigTmp/fn.out" | LC_ALL=C awk '{ print $1, $2 }' ):$( ls "$rigTmp"/stand-in.* 2> /dev/null | LC_ALL=C grep -c . ):$( rigMade k )" "alive $rigK:rc 0:1:1"
rigCall nothing
rigAssert "an id that names nothing is refused, no process is started, and no folder is made for it" \
	"$( LC_ALL=C sed -n '1p' "$rigTmp/fn.out" ):$( LC_ALL=C sed -n '2p' "$rigTmp/fn.out" | LC_ALL=C awk '{ print $1, $2 }' ):$( ls "$rigTmp"/stand-in.* 2> /dev/null | LC_ALL=C grep -c . ):$( [ -e "$rigStores/$( rigId nothing )" ] && echo folder || echo none )" \
	"failed - '$( rigId nothing )' names no session of this workspace: no folder of a session has that name, and no record carries it as its session-id:rc 1:1:none"
## A session a client founded: no folder under its id yet, and a record of a member carries it.
rigRec m m1 m "$rigHost" spawn-started ''
rigCall m
rigM="$( LC_ALL=C sed -n '1s/^started //p' "$rigTmp/fn.out" )"
rigAssert "a session with no folder yet, whose id a record carries, gets its folder and its start" \
	"$( LC_ALL=C sed -n '1s/ [0-9][0-9]*$/ PID/p' "$rigTmp/fn.out" ):$( rigMade m ):$( [ -n "$rigM" ] && ! rigEnded "$rigM" && echo alive )" "started PID:1:alive"
rigThreadsEnd
rm -rf "$rigStores/$( rigId k )" "$rigStores/$( rigId m )" "$rigSp/$( rigId k )" "$rigSp/$( rigId m )"

echo "-- 9. the caller rule of the family, the syntax, and the help pair --"
rigRec n n n "$rigHost" spawn-started '' ; rigStand n
rigPre=( "MDAT_SPAWN_AGENT=magic-coordinator" )
rigRun "$rigOp" --session-id "$( rigId n )"
rigPre=()
rigAssert "from inside a member's session, magic-coordinator's among them, it is refused in the family's one line, and nothing is started" \
	"$rigRc $( rigRows ) $( LC_ALL=C grep -c -x -F -- "DistroAgentsTools: ${rigOp#--}: ⛔ ERROR: this session acts as magic-coordinator, and a --manager-* operation is the console's own, never run from inside a member's session -- nothing was done" "$rigTmp/err" ) $( rigThreads n )" "1 0 1 0"
rigRun "$rigOp"
rigAssert "with neither a session nor --all: the syntax, status 1, nothing started" "$rigRc $( rigRows ) $( rigSaid "syntax is $rigSyntax: one session by its id, or --all, and not both" ) $( rigThreads n )" "1 0 1 0"
rigRun "$rigOp" --all --session-id "$( rigId n )"
rigAssert "with both: the syntax, status 1, nothing started" "$rigRc $( rigRows ) $( rigSaid "syntax is $rigSyntax: one session by its id, or --all, and not both" ) $( rigThreads n )" "1 0 1 0"
rigRun "$rigOp" --session-id
rigAssert "an id that is missing, and a word that is no option: the syntax, status 1" "$rigRc $( rigSaid "--session-id needs an id -- syntax is $rigSyntax" ) $( rigRun "$rigOp" --every ; printf '%s %s' "$rigRc" "$( rigSaid "syntax is $rigSyntax, got: --every" )" ) $( rigThreads n )" "1 1 1 1 0"
rigHelpInclude="$rigHere/help/Help.DistroAgentsTools.include"
rigHelpMd="$rigHere/help/Help.DistroAgentsTools.help.md"
rigSyntaxLine="📘 syntax: DistroAgentsTools.fn.sh $rigOp $rigSyntax"
rigEntry(){ ## -- the operation's entry in the help.md, from under its heading to the next operation's
	LC_ALL=C awk -v head="$( printf '\t\t%s %s' "$rigOp" "$rigSyntax" )" '$0 == head { on = 1 ; next } on && /^\t\t--/ { exit } on { print }' "$rigHelpMd"
}
rigAssert "the operation has its syntax echo, its syntax line and its entry, once each, and in no other form" "$( LC_ALL=C grep -c -x -F -- "echo \"$rigSyntaxLine\" >&2" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -x -F -- "$rigSyntaxLine" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -x -F -- "$( printf '\t\t%s %s' "$rigOp" "$rigSyntax" )" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -F -- "syntax: DistroAgentsTools.fn.sh $rigOp" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -F -- "syntax: DistroAgentsTools.fn.sh $rigOp" "$rigHelpMd" || : )" "1 1 1 1 1"
rigForm="$( rigEntry | LC_ALL=C sed -n -e 's/^[[:space:]]*`\(control <.*>\)`$/\1/p' )"
rigAssert "its entry gives the form of a row" "$rigForm" "control <session-id> <outcome> <pid> <reason>"
rigAssert "and every row this check was given has exactly the fields its form names, the first of them control" "$( cat "$rigTmp"/out.kept.* 2> /dev/null | LC_ALL=C awk -F'\t' -v wantFields="$( printf '%s\n' "$rigForm" | LC_ALL=C awk '{ print NF }' )" '{ rows++ ; if ( $1 != "control" || NF != wantFields ) bad++ ; } END { printf "%s:%s", ( rows > 0 ? "rows" : "none" ), bad + 0 }' )" "rows:0"
rigAssert "the entry names each outcome, the log of a thread, and the two other callers of the check" "$( for rigWord in started alive not-needed not-started control/log --all --session-id ; do rigEntry | LC_ALL=C grep -c -F -- "\`$rigWord\`" | LC_ALL=C awk '{ printf "%s", ( $1 > 0 ) ? "y" : "n" }' ; done ) $( rigEntry | LC_ALL=C tr '\n\t' '  ' | LC_ALL=C tr -s ' ' | LC_ALL=C grep -c -F -e 'The advance lock take and each iteration of the main loop make that same check.' )" "yyyyyyy 1"
rigRun --help-syntax
rigAssert "--help-syntax prints its line, once" "$rigRc $( LC_ALL=C grep -c -x -F -- "$rigSyntaxLine" "$rigTmp/err" || : )" "0 1"
rigCode(){ ## file -- its lines that are no comment
	LC_ALL=C grep -v '^[[:space:]]*#' "$1"
}
rigAssert "one function starts a thread, and the console, the advance lock take and the main loop reach it through the one check" \
	"$( cat "$rigHere"/*/*.include "$rigHere"/*/*.sh | LC_ALL=C grep -c -E '^AgentsToolsSessionControlStart\(\)\{' || : ) $( cat "$rigHere"/*/*.include "$rigHere"/*/*.sh | LC_ALL=C grep -v '^[[:space:]]*#' | LC_ALL=C grep -c -F -e '--intern-session-control --run --session-id "$startSession"' || : ) $( rigCode "$rigHere/manager/AgentsTools.ManagerSession.include" | LC_ALL=C grep -c -e 'AgentsToolsSessionControlCheckWorkspace' -e 'AgentsToolsSessionControlStart "' || : ) $( rigCode "$rigHere/magic/AgentsTools.MagicAdvance.include" | LC_ALL=C grep -c -e '| AgentsToolsSessionControlCheck ' || : ) $( rigCode "$rigHere/magic/AgentsTools.InternMainLoop.include" | LC_ALL=C grep -c -e 'AgentsToolsSessionControlCheckWorkspace' || : )" "1 1 2 1 1"

echo "-- 10. the guard: every check of sh-test that names an operation which starts control threads ends them --"
## THE OPERATIONS that start the control thread of a session of the workspace they are called for: the advance
## lock take and the main loop, for every session that is not finished, and the console's start. A check that
## names one of them, outside a comment, sources the fixture (sh-test/check-fixtures/rig-control-threads.include.sh)
## and ends the threads of its rig in its EXIT trap, before its tree is removed: a thread whose rig is gone never
## ends by itself. A new check that names one and does not end them fails here. And the spawner, by each of its
## operations: the supervising shell of a start that is not waited for starts the thread of its session, so a check
## that names the spawn proxy, the heartbeat's own, the start of a session or the console's start of a member ends
## them too, whether its own starts wait or not: the guard reads names. So does one that names the return of a
## review, which starts an ended run again, or the harness's own tool that brings a member in.
rigGuardOps='--magic-advance-lock-acquire|--intern-main-loop|--manager-session-control-start|--intern-op-agent-spawn-proxy|--magic-heartbeat-spawn-proxy|--magic-spawn-session|--manager-spawn-member|--member-review-return|--intern-op-review-return|--intern-tool +"?Agent'
## THE CHECKS THAT NAME A SPAWN OPERATION AND START NO THREAD, with the reason, by file name. A start its caller waits on (--wait) gets no control
## thread (AgentsToolsSessionControlWaited: its transcript says wait=true; the spawner starts the thread, and the communications reader beside it,
## in the supervising shell of a start that is not waited for), so a check whose every such line carries --wait has nothing to end. It stays on this
## list only while that holds: one line of it that names an operation without --wait puts it back under the guard.
##   AgentsThisSessionCheck.test.sh   its one spawn (section 8, the brief of a start with no routine) is --intern-op-agent-spawn-proxy ... --wait
rigGuardWaived=' AgentsThisSessionCheck.test.sh '
rigGuard(){ ## folder of checks -- `NOT ENDED: <file>` for each check that names one of the operations and does not end the threads of its rig, then how many name one
	local guardFile guardNamed=0
	for guardFile in "$1"/*.test.sh "$1"/*/*.test.sh ; do
		[ -f "$guardFile" ] || continue
		LC_ALL=C grep -v '^[[:space:]]*#' "$guardFile" | LC_ALL=C grep -q -E -e "$rigGuardOps" || continue
		guardNamed=$(( guardNamed + 1 ))
		case "$rigGuardWaived" in
			*" ${guardFile##*/} "*) [ -n "$( LC_ALL=C grep -v '^[[:space:]]*#' "$guardFile" | LC_ALL=C grep -E -e "$rigGuardOps" | LC_ALL=C grep -v -e ' --wait' )" ] || continue ;;
		esac
		LC_ALL=C grep -q -E -e '^\. "[^"]*check-fixtures/rig-control-threads\.include\.sh" ' "$guardFile" \
			&& LC_ALL=C grep -q -E -e "^trap '.*rigControlThreadsEnd \"\\\$rig[A-Za-z]+\" .*' EXIT\$" "$guardFile" \
			|| printf 'NOT ENDED: %s\n' "${guardFile##*/}"
	done
	printf 'named: %s\n' "$guardNamed"
}
rigGuarded="$( rigGuard "$rigPackage/sh-test" )"
rigAssert "every check of the package that names one of those operations sources the fixture and ends the threads of its rig in its EXIT trap" \
	"$( printf '%s\n' "$rigGuarded" | LC_ALL=C grep -c '^NOT ENDED: ' ):$( printf '%s\n' "$rigGuarded" | LC_ALL=C grep '^NOT ENDED: ' | LC_ALL=C tr '\n' ' ' )" "0:"
rigAssert "control: the guard read the checks, and found those that name one: ten or more, this one, the advance lock's, the main loop's and three of the spawner's among them" \
	"$( printf '%s\n' "$rigGuarded" | LC_ALL=C sed -n 's/^named: //p' | LC_ALL=C awk '{ print ( $1 >= 10 ) ? "ten-or-more" : $1 }' ):$( for rigName in AgentsSessionControlStartCheck AgentsSessionControlScanCheck AgentsSessionControlMainLoopCheck AgentsAdvanceInputScanStatesCheck AgentsMainLoopConfigCheck AgentsSpawnDetachCheck AgentsMagicSpawnSessionCheck AgentsManagerSpawnMemberCheck ; do LC_ALL=C grep -v '^[[:space:]]*#' "$rigPackage/sh-test/$rigName.test.sh" | LC_ALL=C grep -q -E -e "$rigGuardOps" && printf y || printf n ; done )" "ten-or-more:yyyyyyyy"
## Made to fail: a check that takes the advance lock and ends nothing, one that sources the fixture and never calls it,
## and beside them one that does both, one that names the operation in a comment alone, and one that names none;
## and one in a subfolder, where the runner finds tests too, that takes the advance lock and ends nothing.
mkdir -p "$rigTmp/probe/sub"
printf '%s\n' '#!/usr/bin/env bash' 'rigTmp="$( mktemp -d "$MMDAPP/.local/agents/scratch/sh-test/probe.XXXXXXXX" )"' "trap 'rm -rf -- \"\$rigTmp\"' EXIT" 'bash "$rigTool" --magic-advance-lock-acquire magic-coordinator rig-pass' > "$rigTmp/probe/Bare.test.sh"
printf '%s\n' '#!/usr/bin/env bash' '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || exit 1' 'rigTmp="$( mktemp -d "$MMDAPP/.local/agents/scratch/sh-test/probe.XXXXXXXX" )"' "trap 'rm -rf -- \"\$rigTmp\"' EXIT" 'bash "$rigTool" --intern-main-loop --one' > "$rigTmp/probe/Sourced.test.sh"
printf '%s\n' '#!/usr/bin/env bash' '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || exit 1' 'rigTmp="$( mktemp -d "$MMDAPP/.local/agents/scratch/sh-test/probe.XXXXXXXX" )"' "trap 'rigControlThreadsEnd \"\$rigTmp\" ; rm -rf -- \"\$rigTmp\"' EXIT" 'bash "$rigTool" --manager-session-control-start --all' > "$rigTmp/probe/Ended.test.sh"
printf '%s\n' '#!/usr/bin/env bash' '## this check never calls --magic-advance-lock-acquire' 'echo nothing' > "$rigTmp/probe/Comment.test.sh"
printf '%s\n' '#!/usr/bin/env bash' 'echo nothing' > "$rigTmp/probe/None.test.sh"
printf '%s\n' '#!/usr/bin/env bash' 'rigTmp="$( mktemp -d "$MMDAPP/.local/agents/scratch/sh-test/probe.XXXXXXXX" )"' "trap 'rm -rf -- \"\$rigTmp\"' EXIT" 'bash "$rigTool" --magic-spawn-session rig-member < /dev/null' > "$rigTmp/probe/Spawned.test.sh"
printf '%s\n' '#!/usr/bin/env bash' 'rigTmp="$( mktemp -d "$MMDAPP/.local/agents/scratch/sh-test/probe.XXXXXXXX" )"' "trap 'rm -rf -- \"\$rigTmp\"' EXIT" 'bash "$rigTool" --magic-advance-lock-acquire magic-coordinator rig-pass' > "$rigTmp/probe/sub/Nested.test.sh"
rigAssert "the guard fails a check that names one of the operations and does not end the threads of its rig, one that only sources the fixture, one that starts a session through the spawner and ends nothing, and one in a subfolder that ends nothing; not one that ends them, nor one that names the operation in a comment alone" \
	"$( rigGuard "$rigTmp/probe" | LC_ALL=C tr '\n' ' ' )" "NOT ENDED: Bare.test.sh NOT ENDED: Sourced.test.sh NOT ENDED: Spawned.test.sh NOT ENDED: Nested.test.sh named: 5 "
## The check that is listed as starting no thread (rigGuardWaived), made to fail and to hold: of the same name, one whose only spawn is waited
## for is let be; one that also names a spawn that is not waited for is put back under the guard, and so is one of another name that is waited for.
mkdir -p "$rigTmp/probe-waited" "$rigTmp/probe-unwaited" "$rigTmp/probe-other"
printf '%s\n' '#!/usr/bin/env bash' 'bash "$rigTool" --intern-op-agent-spawn-proxy rig-member --dispatch-doc:create --wait' '## --intern-op-agent-spawn-proxy rig-member in a comment' > "$rigTmp/probe-waited/AgentsThisSessionCheck.test.sh"
printf '%s\n' '#!/usr/bin/env bash' 'bash "$rigTool" --intern-op-agent-spawn-proxy rig-member --dispatch-doc:create --wait' 'bash "$rigTool" --intern-op-agent-spawn-proxy rig-member --dispatch-doc:create' > "$rigTmp/probe-unwaited/AgentsThisSessionCheck.test.sh"
printf '%s\n' '#!/usr/bin/env bash' 'bash "$rigTool" --intern-op-agent-spawn-proxy rig-member --dispatch-doc:create --wait' > "$rigTmp/probe-other/AgentsSomeOtherCheck.test.sh"
rigAssert "a check listed as starting no thread is let be while every spawn it names is waited for, goes back under the guard when one is not, and the listing is by its name alone" \
	"$( rigGuard "$rigTmp/probe-waited" | LC_ALL=C tr '\n' ' ' )/$( rigGuard "$rigTmp/probe-unwaited" | LC_ALL=C tr '\n' ' ' )/$( rigGuard "$rigTmp/probe-other" | LC_ALL=C tr '\n' ' ' )" \
	"named: 1 /NOT ENDED: AgentsThisSessionCheck.test.sh named: 1 /NOT ENDED: AgentsSomeOtherCheck.test.sh named: 1 "
rigAssert "control: the check that is listed is in the package, and every line of it that names a guarded operation is waited for" \
	"$( [ -f "$rigPackage/sh-test/session/AgentsThisSessionCheck.test.sh" ] && printf present ):$( LC_ALL=C grep -v '^[[:space:]]*#' "$rigPackage/sh-test/session/AgentsThisSessionCheck.test.sh" | LC_ALL=C grep -E -e "$rigGuardOps" | LC_ALL=C grep -c -v -e ' --wait' )" "present:0"

echo "-- 11. nothing is left running, and nothing was asked of the network --"
rigThreadsEnd
rigProcSignalWithChildren KILL $rigStarted
sleep 1
rigAssert "every thread this check started is ended: no process of this host shows as a thread of one of its sessions" \
	"$( "$rigTmp/bin/ps.real" -A -ww -o args= 2> /dev/null | LC_ALL=C grep -c -E -- "--intern-session-control --run --session-id [a-z0-9]+-$rigTag\$" || : )" "0"
rigAssert "and every process a start of it made, with every stand-in" "$( rigLives(){ local livesCount=0 livesPid ; for livesPid in "$@" ; do rigEnded "$livesPid" || livesCount=$(( livesCount + 1 )) ; done ; printf '%s' "$livesCount" ; } ; rigLives $( LC_ALL=C awk 'NF == 2 { print $1 }' "$rigTmp/threads.notes" 2> /dev/null ) $rigStarted )" "0"
rigAssert "no request was made" "$( [ -e "$rigTmp/curl.calls" ] && echo called || echo none )" "none"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SESSION CONTROL START CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_CONTROL_START: OK (%d assertions, offline)\n' "$rigPasses"
