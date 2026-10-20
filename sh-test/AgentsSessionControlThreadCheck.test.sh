#!/usr/bin/env bash
## Behavioural check on --intern-session-control (--run|--one) --session-id <id>, the control thread of one
## coworking session, as an operation: run rather than read, against a rig workspace built here, with spawn
## records, session stores and a process list of the rig's own. A ps first on PATH lists the rig's runs only,
## stand-in processes under their own pids, never a real CLI; a curl beside it only logs, and nothing may call it.
## Held:
##   1. AT THE DOOR. A call with no mode prints its syntax, ends 1 and takes no lock. An id that names no session,
##      the own id of a run that joined one, and an id that is no name are each refused in one line, and nothing is
##      written. `--one` makes one tick, ends 0, and leaves no pid file and no lock.
##   2. THE THREAD. `--run` stays: its pid file holds its pid with when that process began, its lock names the
##      same, its command line holds the operation and the id of its session, and its starter is told once where
##      its log is. A second start of the same session is refused in one line that names the holder, and the first
##      goes on as it was. The threads of two sessions run side by side. TERM ends it in order: status 0, pid file
##      and lock gone.
##   3. THE THREAD IS NO RUN. With its own command line in the process list, the list of sessions shows no run of
##      its session as running, and the one rule of a live run reads nothing from that line. A start that would
##      read as a run, an option of the interpreter before the script, is refused; so is `--run` inside another
##      operation's process, where it would not show in the process list as itself.
##   4. NOTHING BUT TERM ENDS IT, and a finished session. A hangup, an interrupt, a quit, a broken pipe, USR1 and
##      USR2: after each the thread is there and its next tick is right, while a process started the same way with
##      no such care dies of the first. A starter that is closed: the thread, started as a plain background job
##      with its starter's pipe on three descriptors and in its starter's folder, lets that pipe come to its end
##      and outlives the starter and the folder. A record half written, with its run out of the process list at
##      the same moment, is not taken for a finished session. A process list that cannot be read, a state that
##      cannot be written, a pid file, a lock and a whole control folder that vanish: each such tick concludes
##      nothing or makes the file again, says so once in the log, and the next tick is right. The log is bounded.
##      Its own shell ended by a signal it cannot ignore: the thread is put back in place, the same process, and
##      goes on; a shell that ended five times in a row within seconds of its start is not put back again.
##   5. THE LOCK. A lock whose holder is gone, as KILL leaves it, is taken over, and one line says so; so is a lock
##      whose number another process has, which is never signalled; a lock whose holder lives is not. Two starts
##      at the same moment leave one thread. A thread that finds another live holder in its lock ends, touching
##      nothing of the other's.
##   6. IT RUNS AS NO MEMBER. A call from inside a member's session is not refused, and no process it starts is
##      handed that session.
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
command -v perl > /dev/null 2>&1 || rigRefuse "no perl on PATH to start a process with its signals at their defaults"
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionControlThreadCheck )" || exit 1
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
## The period of the tick, in the rig: one second.
printf 'SESSION_CONTROL_TICK_SECONDS=1\n' > "$rigWs/.local/.agents/magic-team.agent.env"

## THE RIG'S OWN PROCESS LIST, as AgentsRunRuleReadersCheck keeps it: the ps first on PATH answers the whole-host
## listing from the rig's own list, one `<pid> <command line>` line a process, each listed only while it lives, and
## hands every other call to the real ps. It keeps the environment it was last called with, and fails every call
## while the file ps.fails stands: a process list that cannot be read.
ln -s "$( command -v ps )" "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
: > "$rigTmp/ps.list"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
[ ! -e "${0%/*}/../ps.fails" ] || exit 1
env > "${0%/*}/../ps.env" 2> /dev/null
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
rigRec(){ ## sandbox, record name, session id, spawn id, host, status, more frontmatter lines (may be empty)
	mkdir -p "$rigSp/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nworkspace: rigws\nowner: keeper-rig\nstatus: %s\nstarted-at: 2026-10-13 09:00 +0300\n%s---\n\n# Spawn session: %s\n' \
		"$3" "$4" "$5" "$6" "${7:-}" "$3" > "$rigSp/$1/$2.md.rig" && mv -f "$rigSp/$1/$2.md.rig" "$rigSp/$1/$2.md"
}
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
rigEnv(){ ## more environment assignments... -- the environment every tooling call of this rig gets, and no other
	printf '%s\n' "HOME=$rigHome" "PATH=$PATH" "MMDAPP=$rigWs" "MDLT_ORIGIN=$MDLT_ORIGIN" "MDLT_OPTION=--run-from-path $MDLT_ORIGIN" "MDAT_SKILLSET_ROOT=$rigSkills" ${1+"$@"}
}
rigRc=0
rigRun(){ ## tool arguments... -- one dispatcher call in the rig workspace; rc in rigRc, stdout in out, stderr in err
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigPre=()
rigOne(){ ## session id -- one tick
	rigRun "$rigOp" --one --session-id "$1"
}
## A thread: a process of its own, started with its signals at their defaults, whatever this check itself was
## started with, so that a signal it survives is one it took care of. Its pid in rigThreadPid.
rigThreadPid=""
rigThread(){ ## name of its output files, session id
	env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" ${rigPre[@]+"${rigPre[@]}"} \
		perl -e '$SIG{$_} = "DEFAULT" for qw( HUP INT QUIT PIPE TERM USR1 USR2 ) ; chdir $ENV{MMDAPP} or exit 98 ; exec @ARGV or exit 99' \
		bash "$rigTool" "$rigOp" --run --session-id "$2" > "$rigTmp/$1.out" 2> "$rigTmp/$1.err" < /dev/null &
	rigThreadPid=$!
	rigProcNote "$rigThreadPid" ; rigStarted="$rigStarted $rigThreadPid"
}
## A process started as a thread is, with no care for any signal: the control of section 4.
rigBarePid=""
rigBare(){
	perl -e '$SIG{$_} = "DEFAULT" for qw( HUP INT QUIT PIPE TERM USR1 USR2 ) ; exec @ARGV or exit 99' sleep 600 > /dev/null 2>&1 < /dev/null &
	rigBarePid=$!
	rigProcNote "$rigBarePid" ; rigStarted="$rigStarted $rigBarePid"
	disown "$rigBarePid" 2> /dev/null || :
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
rigStatusOf(){ ## pid of a job of this shell -- the status it ended with into rigGot, `alive` where it has not ended in fifteen seconds
	rigGot="alive"
	rigWaitFor 15 rigEnded "$1" || return 0
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
rigErrors(){ ## -- the ERROR lines of the last stderr, but for the one every rig of this package gets
	LC_ALL=C grep -F -- 'ERROR' "$rigTmp/err" | LC_ALL=C grep -v -F -- 'SystemContext.SetInputSpec' || :
}
rigErrorCount(){
	rigErrors | LC_ALL=C grep -c . || :
}
rigPrint(){ ## file -- its inode and the sum of its bytes; no-file where there is none
	[ -f "$1" ] || { printf 'no-file\n' ; return 0 ; }
	printf '%s:%s\n' "$( ls -i "$1" | LC_ALL=C awk '{ print $1 ; exit }' )" "$( cksum < "$1" | LC_ALL=C tr -s ' \t' '-' )"
}
rigTree(){ ## -- every folder, file and link under the rig's .local/agents, each file with the sum of its bytes, as one sum
	( cd "$rigAgents" && find . | LC_ALL=C sort | while IFS= read -r treeName ; do
		if [ -f "$treeName" ] && [ ! -L "$treeName" ] ; then printf '%s %s\n' "$treeName" "$( cksum < "$treeName" )" ; else printf '%s\n' "$treeName" ; fi
	done ) | cksum
}
## ITS NEXT TICK IS RIGHT: the state file is taken away, and the thread, still there, sets `running` again.
rigTickRight(){ ## session id, pid of its thread
	rm -f "$rigStores/$1/control/state"
	if rigWaitFor 10 rigStateIs "$1" running && ! rigEnded "$2" ; then printf 'there, and right' ; else printf 'state [%s], thread %s' "$( rigState "$1" )" "$( rigEnded "$2" && echo ended || echo there )" ; fi
}
rigControl(){ ## session id -- the names in its control folder, a space between them
	( cd "$rigStores/$1/control" 2> /dev/null && ls -A | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )
}

echo "-- 1. at the door: syntax, an id that names no session, one tick --"
rigRec sess-a sess-a sess-a sess-a "$rigHost" spawn-started ''
rigRec run-a2 run-a2 sess-a run-a2 "$rigHost" spawn-succeeded 'resolved-at: 2026-10-13 09:30 +0300
'
rigStand sess-a ; rigRunA="$rigStandPid"
mkdir -p "$rigStores/run-a2"
rigTreeBefore="$( rigTree )"
rigRun "$rigOp"
rigAssert "a call with no mode prints its syntax, both modes with their id, and ends 1" \
	"$rigRc:$( LC_ALL=C grep -c -F -- "$rigOp --run --session-id <id>" "$rigTmp/err" ):$( LC_ALL=C grep -c -F -- "$rigOp --one --session-id <id>" "$rigTmp/err" ):$( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" "1:1:1:0"
rigRun "$rigOp" --stay --session-id sess-a
rigAssert "so does a call with a word that is no mode" "$rigRc:$( LC_ALL=C grep -c -F -- "$rigOp --run --session-id <id>" "$rigTmp/err" )" "1:1"
rigRun "$rigOp" --run
rigAssert "a mode with no --session-id is refused in one line" "$rigRc:$( rigErrorCount ):$( rigErrors | LC_ALL=C grep -c -F -- 'got no --session-id' )" "1:1:1"
rigRun "$rigOp" --one --session-id sess-a --more
rigAssert "and so is a word it does not know" "$rigRc:$( rigErrorCount ):$( rigErrors | LC_ALL=C grep -c -F -- 'got: --more' )" "1:1:1"
rigOne nothing-such
rigAssert "an id that no record carries and no folder of a session has is refused in one line, status 1" \
	"$rigRc:$( rigErrorCount ):$( rigErrors | LC_ALL=C grep -c -F -- "'nothing-such' names no session of this workspace" )" "1:1:1"
rigOne run-a2
rigAssert "the own id of a run that joined a session is refused in one line that names its session" \
	"$rigRc:$( rigErrorCount ):$( rigErrors | LC_ALL=C grep -c -F -- "'run-a2' is the own id of a run of session sess-a" )" "1:1:1"
rigOne 'sess/a'
rigAssert "an id that is no name is refused" "$rigRc:$( rigErrorCount ):$( rigErrors | LC_ALL=C grep -c -F -- 'is no id of a session' )" "1:1:1"
rigAssert "and none of these calls took a lock or wrote anything under .local/agents" "$( rigTree )" "$rigTreeBefore"
rigOne sess-a
rigAssert "--one makes one tick, ends 0, and leaves no pid file and no lock: the state and one line of the log" "$rigRc:$( rigControl sess-a ):$( rigState sess-a )" "0:log state:running"
rigAssert "control: nothing asked for the network" "$( [ -e "$rigTmp/curl.calls" ] && echo called || echo none )" "none"

echo "-- 2. the thread: its pid file, its lock, its command line; a second start; two sessions; TERM --"
rigThread a sess-a ; rigA="$rigThreadPid"
rigWaitFor 20 rigHolds sess-a "$rigA" || rigRefuse "the thread of sess-a did not start, so nothing below would be measured: $( LC_ALL=C tr '\n' ' ' < "$rigTmp/a.err" | cut -c1-600 )"
rigABegan="$( rigProcBegan "$rigA" )"
rigAssert "its pid file holds its pid with when that process began, as the tooling keeps a process" "$( cat "$rigStores/sess-a/control/pid" )" "$rigABegan"
rigAssert "its lock is a link that names the same process" "$( [ -L "$rigStores/sess-a/control/lock" ] && readlink "$rigStores/sess-a/control/lock" )" "$rigABegan"
rigALine="$( "$rigTmp/bin/ps.real" -ww -o args= -p "$rigA" 2> /dev/null )"
rigAssert "its command line holds the operation and the id of its session" "$( LC_ALL=C grep -c -F -- " $rigOp --run --session-id sess-a " <<< " $rigALine " )" "1"
rigAssert "its starter is told once which pid it is and where its log is, and nothing more" \
	"$( LC_ALL=C grep -c -F -- "the control thread of session sess-a runs as pid $rigA: its log is $rigStores/sess-a/control/log" "$rigTmp/a.err" ):$( LC_ALL=C grep -v -e 'SystemContext' -e 'SetInputSpec' "$rigTmp/a.err" | LC_ALL=C grep -c . ):$( wc -c < "$rigTmp/a.out" | LC_ALL=C tr -d ' ' )" "1:1:0"
rigAssert "and its log holds its start" "$( rigLogHas sess-a "the control thread of session sess-a runs as pid $rigA, a tick every 1s" )" "1"
rigPidBefore="$( rigPrint "$rigStores/sess-a/control/pid" )"
rigRun "$rigOp" --run --session-id sess-a
rigAssert "a second start of the same session is refused in one line that names the holder, status 1" \
	"$rigRc:$( rigErrorCount ):$( rigErrors | LC_ALL=C grep -c -F -- "the control thread of session sess-a already runs as pid $rigA, begun ${rigABegan#* } -- a second one is not started" )" "1:1:1"
rigOne sess-a
rigAssert "and so is one tick by hand while the thread lives" "$rigRc:$( rigErrorCount ):$( rigErrors | LC_ALL=C grep -c -F -- "already runs as pid $rigA" )" "1:1:1"
rigAssert "the first thread goes on, with its pid file and its lock as they were" "$( rigLives "$rigA" ):$( rigPrint "$rigStores/sess-a/control/pid" ):$( readlink "$rigStores/sess-a/control/lock" )" "1:$rigPidBefore:$rigABegan"
rigRec sess-b sess-b sess-b sess-b "$rigHost" spawn-started ''
rigStand sess-b ; rigRunB="$rigStandPid"
rigThread b sess-b ; rigB="$rigThreadPid"
rigWaitFor 20 rigHolds sess-b "$rigB" || rigRefuse "the thread of sess-b did not start: $( LC_ALL=C tr '\n' ' ' < "$rigTmp/b.err" | cut -c1-600 )"
rigAssert "the thread of another session runs beside it, each with its own pid file and its own lock" \
	"$( rigLives "$rigA" "$rigB" ):$( readlink "$rigStores/sess-b/control/lock" ):$( readlink "$rigStores/sess-a/control/lock" )" "2:$( rigProcBegan "$rigB" ):$rigABegan"
rigWaitFor 10 rigStateIs sess-b running
rigProcSignal TERM "$rigB"
rigStatusOf "$rigB"
rigAssert "TERM ends a thread in order: status 0, its pid file and its lock gone, the state it set and its log left" "$rigGot:$( rigControl sess-b ):$( rigState sess-b )" "0:log state:running"
rigAssert "its log says why it ended" "$( rigLogHas sess-b "the control thread of session sess-b, pid $rigB, ends: it was ended by TERM" )" "1"
rigAssert "and the thread of the other session is untouched" "$( rigLives "$rigA" )" "1"

echo "-- 3. the thread is no run: of its session, by the list and by the rule; a start that would read as one --"
## A session with an open record and no live run, and its thread, whose own command line stands in the rig's process list.
rigRec sess-quiet sess-quiet sess-quiet sess-quiet "$rigHost" spawn-started ''
rigThread quiet sess-quiet ; rigQ="$rigThreadPid"
rigWaitFor 20 rigHolds sess-quiet "$rigQ" || rigRefuse "the thread of sess-quiet did not start: $( LC_ALL=C tr '\n' ' ' < "$rigTmp/quiet.err" | cut -c1-600 )"
rigQLine="$( "$rigTmp/bin/ps.real" -ww -o args= -p "$rigQ" 2> /dev/null )"
printf '%s %s\n' "$rigQ" "$rigQLine" >> "$rigTmp/ps.list"
printf '%s %s\n' "$rigA" "$rigALine" >> "$rigTmp/ps.list"
rigAssert "control: the rig's process list holds the thread's own command line, with --session-id and the id of its session" "$( LC_ALL=C grep -c -F -- "$rigOp --run --session-id sess-quiet" "$rigTmp/ps.list" )" "1"
rigRun --manager-session-list
rigAssert "with its thread in the process list, the list of sessions shows no run of that session as running" \
	"$rigRc:$( LC_ALL=C awk -F'\t' '$1 == "session" && $2 == "sess-quiet" { print $4 } $1 == "run" && $2 == "sess-quiet" { print $6 }' "$rigTmp/out" | LC_ALL=C tr '\n' ' ' )" "0:unclosed no-process "
rigAssert "the one rule of a live run reads nothing from the thread's command line" \
	"$( printf '%s %s\n' "$rigQ" "$rigQLine" | ( PATH="$rigProcPath" ; . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.Registries.include" ; AgentsToolsRegistryRunWords ) | LC_ALL=C grep -c . )" "0"
sleep 3
rigAssert "and the thread, which reads that same list at every tick, sets no state for a session that has no run: it stays, and says so once" \
	"$( rigLives "$rigQ" ):[$( rigState sess-quiet )]:$( rigLogHas sess-quiet 'no run of it is alive on this host and 1 record(s) are still open' )" "1:[]:1"
rigStand '' ; rigQRun="$rigStandPid"
printf '%s claude --verbose --session-id sess-quiet --agent rig-member the brief\n' "$rigQRun" >> "$rigTmp/ps.list"
rigWaitFor 10 rigStateIs sess-quiet running
rigAssert "control: a run of that session, by its own word on its own command line, does make it read running" "$( rigState sess-quiet )" "running"
rigProcSignal TERM "$rigQ" ; rigStatusOf "$rigQ"
rigProcSignal TERM "$rigQRun" ; rigUnlist sess-quiet
rigAssert "control: that thread ended in order" "$rigGot:$( rigControl sess-quiet )" "0:log state"
## An option of the interpreter before the script: by the rule such a line is a run of the id it carries.
rigRec sess-norc sess-norc sess-norc sess-norc "$rigHost" spawn-started ''
rigAssert "control: a command line with an option of the interpreter before the script reads as a run, by the rule" \
	"$( printf '4242 bash --norc %s %s --run --session-id sess-norc\n' "$rigTool" "$rigOp" | ( PATH="$rigProcPath" ; . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.Registries.include" ; AgentsToolsRegistryRunWords ) )" "sess-norc"
rigTreeBefore="$( rigTree )"
rigRc=0
( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
	bash --norc "$rigTool" "$rigOp" --one --session-id sess-norc ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
rigAssert "a start whose own command line would read as a run is refused in one line, and nothing is written" \
	"$rigRc:$( rigErrorCount ):$( rigErrors | LC_ALL=C grep -c -F -- 'the command line of this process would read as a run of a session' ):$( [ "$( rigTree )" = "$rigTreeBefore" ] && echo untouched || echo written )" "1:1:1:untouched"
rigRc=0
printf '%s\n' "DistroAgentsTools $rigOp --run --session-id sess-norc" | ( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
	bash "$rigTool" --intern-mcp-execute ) > "$rigTmp/out" 2> "$rigTmp/err" || rigRc=$?
rigAssert "--run inside another operation's process, where it would not show in the process list as itself, is refused, and nothing is written" \
	"$rigRc:$( rigErrorCount ):$( rigErrors | LC_ALL=C grep -c -F -- '--run is a process of its own' ):$( [ "$( rigTree )" = "$rigTreeBefore" ] && echo untouched || echo written )" "1:1:1:untouched"

echo "-- 4. nothing but TERM ends it: signals, a closed starter, a broken record, an unreadable process list, vanished files, its log --"
rigBare ; rigBareHup="$rigBarePid" ; rigBare ; rigBareInt="$rigBarePid"
rigProcSignal HUP "$rigBareHup" ; rigProcSignal INT "$rigBareInt"
rigWaitFor 5 rigEnded "$rigBareHup" ; rigWaitFor 5 rigEnded "$rigBareInt"
rigAssert "control: a process started as the thread is, with no care for signals, dies of a hangup and of an interrupt" "$( rigLives "$rigBareHup" "$rigBareInt" )" "0"
rigProcSignal HUP "$rigA" ; rigRcSent=$?
sleep 2
rigAssert "a hangup: the thread is there, and its next tick is right" "$rigRcSent:$( rigLives "$rigA" ):$( rigTickRight sess-a "$rigA" )" "0:1:there, and right"
rigProcSignal INT "$rigA" ; rigRcSent=$?
sleep 2
rigAssert "an interrupt: the thread is there, and its next tick is right" "$rigRcSent:$( rigLives "$rigA" ):$( rigTickRight sess-a "$rigA" )" "0:1:there, and right"
rigProcSignal QUIT "$rigA" ; rigProcSignal PIPE "$rigA" ; rigProcSignal USR1 "$rigA" ; rigProcSignal USR2 "$rigA"
sleep 2
rigAssert "a quit, a broken pipe, USR1 and USR2: the thread is there, and its next tick is right" "$( rigLives "$rigA" ):$( rigTickRight sess-a "$rigA" )" "1:there, and right"
rigAssert "and none of them moved its pid file or its lock" "$( rigPrint "$rigStores/sess-a/control/pid" ):$( readlink "$rigStores/sess-a/control/lock" )" "$rigPidBefore:$rigABegan"

## A STARTER THAT IS CLOSED. The thread is a plain background job of its starter: not detached, the starter's own
## pipe on its descriptors 1, 2 and 5, the starter's folder as its working folder.
cat > "$rigTmp/starter.sh" <<'RIGSTARTER'
#!/usr/bin/env bash
cd "$RIG_STARTER_DIR" || exit 97
exec 5>&1
if [ "$RIG_STARTS" = "thread" ] ; then
	perl -e '$SIG{$_} = "DEFAULT" for qw( HUP INT QUIT PIPE TERM USR1 USR2 ) ; exec @ARGV or exit 99' bash "$RIG_TOOL" --intern-session-control --run --session-id "$RIG_SESSION" &
else
	sleep 600 &
fi
echo "$!" > "$RIG_TMP/starter.$RIG_STARTS"
while [ ! -e "$RIG_TMP/starter.$RIG_STARTS.release" ] ; do sleep 0.2 ; done
echo "the starter ends"
RIGSTARTER
rigStarter(){ ## thread or bare -- starts it through a pipe this rig reads; the reader's pid in rigReader, the started pid in rigStartedPid
	mkdir -p "$rigTmp/starter-dir.$1"
	env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		RIG_STARTER_DIR="$rigTmp/starter-dir.$1" RIG_STARTS="$1" RIG_TOOL="$rigTool" RIG_SESSION=sess-c RIG_TMP="$rigTmp" \
		bash "$rigTmp/starter.sh" 2>&1 < /dev/null | cat > "$rigTmp/starter.$1.read" &
	rigReader=$!
	rigProcNote "$rigReader" ; rigStarted="$rigStarted $rigReader"
	rigWaitFor 20 test -s "$rigTmp/starter.$1" || rigRefuse "the starter of a $1 did not start it, so nothing below would be measured"
	rigStartedPid="$( cat "$rigTmp/starter.$1" )"
	rigProcNote "$rigStartedPid" ; rigStarted="$rigStarted $rigStartedPid"
}
rigStarter bare ; rigBareReader="$rigReader" ; rigBareJob="$rigStartedPid"
: > "$rigTmp/starter.bare.release"
sleep 3
rigAssert "control: a job that keeps its starter's descriptors holds the starter's pipe open after the starter ended: its reader waits on" "$( rigLives "$rigBareReader" "$rigBareJob" )" "2"
rigProcSignal KILL "$rigBareJob" ; rigWaitFor 10 rigEnded "$rigBareReader"
rigAssert "control: and the reader comes to its end once that job is gone" "$( rigLives "$rigBareReader" )" "0"
rigRec sess-c sess-c sess-c sess-c "$rigHost" spawn-started ''
rigStand sess-c ; rigRunC="$rigStandPid"
rigStarter thread ; rigCReader="$rigReader" ; rigC="$rigStartedPid"
rigWaitFor 20 rigHolds sess-c "$rigC" || rigRefuse "the thread of sess-c did not start: $( LC_ALL=C tr '\n' ' ' < "$rigTmp/starter.thread.read" | cut -c1-600 )"
rigWaitFor 10 rigStateIs sess-c running
: > "$rigTmp/starter.thread.release"
rigWaitFor 10 rigEnded "$rigCReader"
rigAssert "a starter that is closed: the starter's pipe comes to its end while the thread lives, so the thread holds none of the descriptors it was handed" \
	"$( rigLives "$rigCReader" ):$( rigLives "$rigC" ):$( LC_ALL=C grep -c -F -- "the control thread of session sess-c runs as pid $rigC" "$rigTmp/starter.thread.read" ):$( LC_ALL=C grep -c -x -F -- 'the starter ends' "$rigTmp/starter.thread.read" )" "0:1:1:1"
rm -rf "$rigTmp/starter-dir.thread"
sleep 2
rigAssert "the folder it was started in is removed: the thread is there, and its next tick is right" "$( rigLives "$rigC" ):$( rigTickRight sess-c "$rigC" )" "1:there, and right"
## Its errors are its own log too, and /dev/null for as long as it waits between two ticks: read as either.
if command -v lsof > /dev/null 2>&1 ; then
	rigAssert "its working folder is /, its input is /dev/null and its output its own log, and none of its descriptors 0 to 9 is anything else" \
		"$( lsof -a -p "$rigC" -d cwd,0,1 -Fn 2> /dev/null | LC_ALL=C sed -n 's/^n//p' | LC_ALL=C tr '\n' ' ' ):$( lsof -a -p "$rigC" -d 0-9 -Fn 2> /dev/null | LC_ALL=C sed -n 's/^n//p' | LC_ALL=C grep -v -x -F -e /dev/null -e "$rigStores/sess-c/control/log" | LC_ALL=C grep -c . )" "/ /dev/null $rigStores/sess-c/control/log :0"
elif [ -d "/proc/$rigC/fd" ] ; then
	rigAssert "its working folder is /, its input is /dev/null and its output its own log, and none of its descriptors 0 to 9 is anything else" \
		"$( readlink "/proc/$rigC/cwd" ) $( readlink "/proc/$rigC/fd/0" ) $( readlink "/proc/$rigC/fd/1" ) :$( for rigFd in 0 1 2 3 4 5 6 7 8 9 ; do [ ! -e "/proc/$rigC/fd/$rigFd" ] || readlink "/proc/$rigC/fd/$rigFd" ; done | LC_ALL=C grep -v -x -F -e /dev/null -e "$rigStores/sess-c/control/log" | LC_ALL=C grep -c . )" "/ /dev/null $rigStores/sess-c/control/log :0"
else
	echo "  SKIP  its working folder and its descriptors: neither lsof nor /proc on this host to read them by"
fi
rigProcSignal TERM "$rigC" ; rigWaitFor 15 rigEnded "$rigC"
rigAssert "and TERM ends it in order, though no starter is left to collect it" "$( rigLives "$rigC" ):$( rigControl sess-c ):$( rigLogHas sess-c 'ends: it was ended by TERM' )" "0:log state:1"

## A RECORD HALF WRITTEN, at the worst moment: the one open record of the session holds a first line and no more,
## and its run has just ended. Read as it lies, every record left is closed.
rigRec sess-d sess-d sess-d sess-d "$rigHost" spawn-started ''
rigRec run-d2 run-d2 sess-d run-d2 "$rigHost" spawn-succeeded 'resolved-at: 2026-10-13 09:30 +0300
'
rigStand sess-d ; rigRunD="$rigStandPid"
rigThread d sess-d ; rigD="$rigThreadPid"
rigWaitFor 20 rigHolds sess-d "$rigD" || rigRefuse "the thread of sess-d did not start: $( LC_ALL=C tr '\n' ' ' < "$rigTmp/d.err" | cut -c1-600 )"
rigWaitFor 10 rigStateIs sess-d running
rigStateBefore="$( rigPrint "$rigStores/sess-d/control/state" )"
printf -- '---\n' > "$rigSp/sess-d/sess-d.md" ; rigUnlist sess-d
sleep 4
rigAssert "a record half written just as its run ended: the thread is there, the session is not called finished, and its state is as it was" \
	"$( rigLives "$rigD" ):$( rigState sess-d ):$( [ "$( rigPrint "$rigStores/sess-d/control/state" )" = "$rigStateBefore" ] && echo untouched || echo written )" "1:running:untouched"
rigAssert "its log says so once, with the record, and not at every tick" "$( rigLogHas sess-d "a record of it that was read before cannot be read now, half written or cut: $rigSp/sess-d/sess-d.md" )" "1"
rigRec sess-d sess-d sess-d sess-d "$rigHost" spawn-started ''
rigStand sess-d ; rigRunD="$rigStandPid"
rigAssert "the record whole again, and its run alive again: the thread is there, and its next tick is right" "$( rigLives "$rigD" ):$( rigTickRight sess-d "$rigD" )" "1:there, and right"
rigRec sess-d sess-d sess-d sess-d "$rigHost" spawn-succeeded 'resolved-at: 2026-10-13 09:50 +0300
'
rigUnlist sess-d
rigStatusOf "$rigD"
rigAssert "and once that record is truly closed and its run gone, the thread writes finished and ends by itself: status 0, pid file and lock gone" \
	"$rigGot:$( rigState sess-d ):$( rigControl sess-d ):$( rigLogHas sess-d "the control thread of session sess-d, pid $rigD, ends: its session is finished" )" "0:finished:log state:1"

## A PROCESS LIST THAT CANNOT BE READ: every call of ps fails for a while.
rm -f "$rigStores/sess-a/control/state"
: > "$rigTmp/ps.fails"
rm -f "$rigStores/sess-a/control/state"
sleep 4
rigAssert "a process list that cannot be read: the thread is there, concludes nothing and sets no state" "$( rigLives "$rigA" ):[$( rigState sess-a )]" "1:[]"
rigAssert "its log says so once, and not at every tick" "$( rigLogHas sess-a 'the process list of this host could not be read at this tick' )" "1"
rm -f "$rigTmp/ps.fails"
rigAssert "the process list readable again: the thread is there, and its next tick is right" "$( rigWaitFor 10 rigStateIs sess-a running ; rigLives "$rigA" ):$( rigState sess-a )" "1:running"

## ITS OWN FILES VANISH, and a state that cannot be written.
rm -f "$rigStores/sess-a/control/pid" "$rigStores/sess-a/control/lock"
rigWaitFor 10 rigHolds sess-a "$rigA"
rigAssert "its pid file and its lock are removed: both are made again by the next tick, in the name of the same process" \
	"$( rigLives "$rigA" ):$( cat "$rigStores/sess-a/control/pid" 2> /dev/null ):$( readlink "$rigStores/sess-a/control/lock" 2> /dev/null )" "1:$rigABegan:$rigABegan"
rm -rf "$rigStores/sess-a/control"
rigWaitFor 10 rigStateIs sess-a running
rigAssert "its whole control folder is removed: it is made again, with its pid file, its lock and the state" \
	"$( rigLives "$rigA" ):$( cat "$rigStores/sess-a/control/pid" 2> /dev/null ):$( readlink "$rigStores/sess-a/control/lock" 2> /dev/null ):$( rigState sess-a )" "1:$rigABegan:$rigABegan:running"
if [ "$( id -u )" != 0 ] ; then
	sleep 2
	rm -f "$rigStores/sess-a/control/state"
	chmod a-w "$rigStores/sess-a/control"
	sleep 4
	rigAssert "a state that cannot be written, the folder closed to writing as a full disk closes it: the thread is there, and no half state lies about" \
		"$( rigLives "$rigA" ):[$( rigState sess-a )]:$( ls -A "$rigStores/sess-a/control" | LC_ALL=C grep -c -F -- '.aside' )" "1:[]:0"
	chmod u+w "$rigStores/sess-a/control"
	rigAssert "writable again: the state is set by the next tick" "$( rigWaitFor 10 rigStateIs sess-a running ; rigLives "$rigA" ):$( rigState sess-a )" "1:running"
	rigAssert "and its log said once that the state could not be written" "$( rigLogHas sess-a 'the state running could not be written' )" "1"
else
	echo "  SKIP  a state that cannot be written: this check runs as root, which a closed folder does not stop"
fi

## ITS LOG IS BOUNDED: a log found over 128 KiB holds its last 64 KiB after the next line the thread writes.
rigRec sess-e sess-e sess-e sess-e "$rigHost" spawn-started ''
rigStand sess-e ; rigRunE="$rigStandPid"
mkdir -p "$rigStores/sess-e/control"
LC_ALL=C awk 'BEGIN { for ( lineAt = 1 ; lineAt <= 4000 ; lineAt++ ) { printf "2026-10-13T00:00:00Z old line %05d of a log that grew and grew and grew\n", lineAt ; } }' > "$rigStores/sess-e/control/log"
rigLogBefore="$( wc -c < "$rigStores/sess-e/control/log" | LC_ALL=C tr -d ' ' )"
rigThread e sess-e ; rigE="$rigThreadPid"
rigWaitFor 20 rigHolds sess-e "$rigE" || rigRefuse "the thread of sess-e did not start: $( LC_ALL=C tr '\n' ' ' < "$rigTmp/e.err" | cut -c1-600 )"
rigWaitFor 10 rigLogSays sess-e 'holds its last 64 KiB now'
rigLogAfter="$( wc -c < "$rigStores/sess-e/control/log" | LC_ALL=C tr -d ' ' )"
rigAssert "control: the log the thread found was over the bound" "$( [ "$rigLogBefore" -gt 131072 ] && echo over || echo "$rigLogBefore" )" "over"
rigAssert "a log over 128 KiB is cut back to its last 64 KiB: whole lines, the newest kept, and one line that says so" \
	"$( [ "$rigLogAfter" -le 70000 ] && [ "$rigLogAfter" -ge 60000 ] && echo cut || echo "$rigLogAfter" ):$( LC_ALL=C sed -n '1p' "$rigStores/sess-e/control/log" | LC_ALL=C grep -c -E '^2026-10-13T00:00:00Z old line [0-9]{5} of a log that grew and grew and grew$' ):$( rigLogHas sess-e 'old line 04000 ' ):$( rigLogHas sess-e 'old line 00001 ' ):$( rigLogHas sess-e 'the log had grown over 128 KiB and holds its last 64 KiB now' )" "cut:1:1:0:1"
rigAssert "and the thread goes on writing to the log that is there now: its start is in it, and its next tick is right" \
	"$( rigLogHas sess-e "the control thread of session sess-e runs as pid $rigE" ):$( rigTickRight sess-e "$rigE" ):$( rigLogHas sess-e 'session sess-e: running: a run of the session is alive on this host' | LC_ALL=C awk '{ print ( $1 >= 2 ) ? "said" : $1 }' )" "1:there, and right:said"

## ITS OWN SHELL ENDS WITHOUT ITS DOING: a signal that cannot be ignored and that it has no care for, the limit of
## processor time, as any fault that ends a shell. The thread is put back in place: the same process, by exec.
rigBare ; rigBareXcpu="$rigBarePid"
rigProcSignal XCPU "$rigBareXcpu" ; rigWaitFor 5 rigEnded "$rigBareXcpu"
rigAssert "control: a process started as the thread is, with no care for signals, dies of that signal" "$( rigLives "$rigBareXcpu" )" "0"
rigEBegan="$( rigProcBegan "$rigE" )"
rigProcSignal XCPU "$rigE" ; rigRcSent=$?
rigWaitFor 15 rigLogSays sess-e 'is put back in place'
rigAssert "the shell of a thread ends without its doing: the thread is put back in place, the same process with the same pid and the same beginning, its pid file and its lock as they were" \
	"$rigRcSent:$( rigProcBegan "$rigE" ):$( cat "$rigStores/sess-e/control/pid" 2> /dev/null ):$( readlink "$rigStores/sess-e/control/lock" 2> /dev/null ):$( rigLogHas sess-e "the control thread of session sess-e is put back in place, pid $rigE as before: its shell had ended without its doing" )" \
	"0:$rigEBegan:$rigEBegan:$rigEBegan:1"
rigAssert "and its next tick is right" "$( rigTickRight sess-e "$rigE" )" "there, and right"
rigProcSignal HUP "$rigE" ; rigProcSignal INT "$rigE" ; sleep 2
rigELives="$( rigLives "$rigE" )"
rigProcSignal TERM "$rigE" ; rigStatusOf "$rigE"
rigAssert "a thread that was put back takes a hangup and an interrupt as before, and TERM still ends it in order: status 0, pid file and lock gone" \
	"$rigELives:$rigGot:$( rigControl sess-e )" "1:0:log state"
## A fault that comes back at once is not answered for ever: a thread whose shell has ended five times in a row,
## each within seconds of its start, is not put back a sixth time. The count travels in its environment.
rigPre=( MDAT_SESSION_CONTROL_AGAIN=5 )
rigThread e5 sess-e ; rigE5="$rigThreadPid"
rigPre=()
rigWaitFor 20 rigHolds sess-e "$rigE5" || rigRefuse "the thread of sess-e did not start with its count at five: $( LC_ALL=C tr '\n' ' ' < "$rigTmp/e5.err" | cut -c1-600 )"
rigWaitFor 10 rigLogSays sess-e 'it is not put back another time'
rigProcSignal XCPU "$rigE5" ; rigStatusOf "$rigE5"
rigAssert "a thread whose shell ended five times in a row within seconds of its start says that it is not put back again, and the next such end is its last" \
	"$( rigLogHas sess-e 'the shell of this thread ended five times in a row within seconds of its start: it is not put back another time' ):$( rigLives "$rigE5" ):$( [ "$rigGot" != 0 ] && [ "$rigGot" != alive ] && echo ended-by-the-signal || echo "$rigGot" )" "1:0:ended-by-the-signal"
rm -f "$rigStores/sess-e/control/pid" "$rigStores/sess-e/control/lock"

echo "-- 5. the lock: a holder that is gone, a number another process has, a holder that lives, two starts at once --"
rigProcSignal KILL "$rigA" ; rigStatusOf "$rigA"
rigAssert "a thread ended by KILL leaves its pid file and its lock as they were" "$( cat "$rigStores/sess-a/control/pid" 2> /dev/null ):$( readlink "$rigStores/sess-a/control/lock" 2> /dev/null )" "$rigABegan:$rigABegan"
rigThread a2 sess-a ; rigA2="$rigThreadPid"
rigWaitFor 20 rigHolds sess-a "$rigA2" || rigRefuse "the second thread of sess-a did not start: $( LC_ALL=C tr '\n' ' ' < "$rigTmp/a2.err" | cut -c1-600 )"
rigAssert "the next start takes the lock over and runs: the pid file and the lock name the new thread, and one line of the log says whose lock it was" \
	"$( rigLives "$rigA2" ):$( readlink "$rigStores/sess-a/control/lock" ):$( rigLogHas sess-a "took over the lock of pid $rigA, which is gone" )" "1:$( rigProcBegan "$rigA2" ):1"
rigProcSignal TERM "$rigA2" ; rigStatusOf "$rigA2"
rigAssert "control: that thread ended in order" "$rigGot:$( rigControl sess-a )" "0:log state"
## A lock that names a pid no process has, written by hand as a thread long gone left it.
ln -s '99999999 Mon_Jan__1_00:00:00_2001' "$rigStores/sess-a/control/lock"
printf '99999999 Mon_Jan__1_00:00:00_2001\n' > "$rigStores/sess-a/control/pid"
rigOne sess-a
rigAssert "a lock that names a process id no process has is taken over, and one line says so: the tick is made, and neither the dead thread's pid file nor its lock is left" \
	"$rigRc:$( LC_ALL=C grep -c -F -- 'took over the lock of pid 99999999, which is gone' "$rigTmp/err" ):$( rigLogHas sess-a 'took over the lock of pid 99999999, which is gone' ):$( rigControl sess-a )" "0:1:1:log state"
## A lock whose number another process has: a stand-in that lives, and that began at another time than the lock says.
rigStand '' ; rigOther="$rigStandPid"
ln -s "$rigOther Mon_Jan__1_00:00:00_2001" "$rigStores/sess-a/control/lock"
rigOne sess-a
rigAssert "a lock whose process id another process has taken is taken over, and one line says so; that process is never signalled" \
	"$rigRc:$( LC_ALL=C grep -c -F -- "took over the lock of pid $rigOther: that number is another process's now" "$rigTmp/err" ):$( rigLives "$rigOther" ):$( rigControl sess-a )" "0:1:1:log state"
ln -s "$( rigProcBegan "$rigOther" )" "$rigStores/sess-a/control/lock"
rigOne sess-a
rigAssert "control: a lock whose holder lives, the same pid begun when the lock says, is not taken over: refused, and the lock left" \
	"$rigRc:$( rigErrors | LC_ALL=C grep -c -F -- "already runs as pid $rigOther" ):$( readlink "$rigStores/sess-a/control/lock" ):$( rigLives "$rigOther" )" "1:1:$( rigProcBegan "$rigOther" ):1"
rm -f "$rigStores/sess-a/control/lock"
## Two starts at the same moment.
rigRec sess-f sess-f sess-f sess-f "$rigHost" spawn-started ''
rigStand sess-f ; rigRunF="$rigStandPid"
rigThread f1 sess-f ; rigF1="$rigThreadPid"
rigThread f2 sess-f ; rigF2="$rigThreadPid"
rigOneEnded(){ rigEnded "$rigF1" || rigEnded "$rigF2" ; }
rigWaitFor 30 rigOneEnded
if rigEnded "$rigF1" ; then rigFLost="$rigF1" ; rigFWon="$rigF2" ; rigFLostName=f1 ; else rigFLost="$rigF2" ; rigFWon="$rigF1" ; rigFLostName=f2 ; fi
rigWaitFor 20 rigHolds sess-f "$rigFWon"
rigStatusOf "$rigFLost"
sleep 2
rigAssert "two starts at the same moment leave one thread: one holds the lock and ticks, the other is refused with status 1 and the line that names the holder" \
	"$( rigLives "$rigF1" "$rigF2" ):$rigGot:$( LC_ALL=C grep -c -F -- "the control thread of session sess-f already runs as pid $rigFWon" "$rigTmp/$rigFLostName.err" ):$( cat "$rigStores/sess-f/control/pid" ):$( rigState sess-f )" "1:1:1:$( rigProcBegan "$rigFWon" ):running"
## A thread that finds another live holder in its lock: the lock's own rule, never two.
## The lock first, then the pid file, as a thread that takes a lock over writes them.
ln -s "$( rigProcBegan "$rigOther" )" "$rigStores/sess-f/control/lock.rig" ; mv -f "$rigStores/sess-f/control/lock.rig" "$rigStores/sess-f/control/lock"
printf '%s\n' "$( rigProcBegan "$rigOther" )" > "$rigStores/sess-f/control/pid.rig" ; mv -f "$rigStores/sess-f/control/pid.rig" "$rigStores/sess-f/control/pid"
rigStatusOf "$rigFWon"
rigAssert "a thread that finds another live holder in its lock ends, status 1, and touches neither the lock nor the pid file of the other" \
	"$rigGot:$( readlink "$rigStores/sess-f/control/lock" ):$( cat "$rigStores/sess-f/control/pid" ):$( rigLogHas sess-f "another control thread holds the lock of its session now, pid $rigOther" ):$( rigLives "$rigOther" )" "1:$( rigProcBegan "$rigOther" ):$( rigProcBegan "$rigOther" ):1:1"

echo "-- 6. it runs as no member --"
rigRec sess-m sess-m sess-m sess-m "$rigHost" spawn-started ''
rigStand sess-m ; rigRunM="$rigStandPid"
rigPre=( MDAT_SPAWN_AGENT=keeper-rig MDAT_SPAWN_SESSION_ID=rig-member-session MDAT_SPAWN_SANDBOX_ROOT=/nonexistent/rig-sandbox harnessAgent=keeper-rig harnessSessionId=rig-member-session CLAUDE_CODE_SESSION_ID=rig-client-session )
rigRun --manager-session-list
rigAssert "control: that environment is a member's session: an operation of the console is refused in it" "$rigRc:$( rigErrors | LC_ALL=C grep -c -F -- 'this session acts as keeper-rig' )" "1:1"
rm -f "$rigTmp/ps.env"
rigOne sess-m
rigAssert "a call from inside a member's session is not refused: the tick is made as from anywhere" "$rigRc:$( rigErrorCount ):$( rigState sess-m ):$( rigControl sess-m )" "0:0:running:log state"
rigAssert "and no process it starts is handed that session: its spawn id, its member, its sandbox, the id of its client" \
	"$( [ -s "$rigTmp/ps.env" ] && echo asked || echo not-asked ):$( LC_ALL=C grep -c -E '^(MDAT_SPAWN_[A-Z_]*|harnessSessionId|harnessAgent|CLAUDE_CODE_SESSION_ID)=.' "$rigTmp/ps.env" 2> /dev/null )" "asked:0"
rigThread m sess-m ; rigM="$rigThreadPid"
rigWaitFor 20 rigHolds sess-m "$rigM" || rigRefuse "the thread of sess-m did not start from inside a member's session: $( LC_ALL=C tr '\n' ' ' < "$rigTmp/m.err" | cut -c1-600 )"
rm -f "$rigTmp/ps.env" ; rigWaitFor 10 test -s "$rigTmp/ps.env"
rigAssert "a thread started from inside a member's session runs, and hands what it starts none of it either" \
	"$( rigLives "$rigM" ):$( LC_ALL=C grep -c -E '^(MDAT_SPAWN_[A-Z_]*|harnessSessionId|harnessAgent|CLAUDE_CODE_SESSION_ID)=.' "$rigTmp/ps.env" 2> /dev/null )" "1:0"
rigPre=()
rigProcSignal TERM "$rigM" ; rigStatusOf "$rigM"
rigAssert "control: that thread ended in order" "$rigGot:$( rigControl sess-m )" "0:log state"

echo "-- 7. nothing is left running, and nothing was asked of the network --"
rigProcSignalWithChildren KILL $rigStarted
sleep 1
rigAssert "every thread and every stand-in this check started is ended" "$( rigLives $rigStarted )" "0"
rigAssert "no request was made" "$( [ -e "$rigTmp/curl.calls" ] && echo called || echo none )" "none"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SESSION CONTROL THREAD CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_CONTROL_THREAD: OK (%d assertions, offline)\n' "$rigPasses"
