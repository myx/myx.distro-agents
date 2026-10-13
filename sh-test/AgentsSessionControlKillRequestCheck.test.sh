#!/usr/bin/env bash
## Behavioural check: the kill of a session from the console goes through the control thread of that session
## (--manager-session-kill, --intern-session-control, sh-lib/AgentsTools.SessionControlRequest.include). Run rather
## than read, in a rig workspace built here: sessions with stand-in runs and REAL control threads, whose own
## command lines stand in the rig's process list beside the stand-ins of the runs.
## Held:
##   1. With a live thread the kill is carried out by the thread: the console writes its request into control/ of
##      the session and wakes the thread, the thread takes the request, ends the runs by the one walk of step one,
##      and writes the outcome, whose rows the console prints, the rows of step one. The tick of that thread is an
##      hour, so only the wake brings it. The thread itself lives on.
##   2. USR1 makes the thread tick at once; without it a request waits. A request of a kind that is not taken is
##      answered as refused, with the reason, and nothing is done; so is a request that was left behind, asked
##      longer ago than its console waited.
##   3. With no thread the operation kills as before, writes no request, and says so in one line. A pid file whose
##      number another process has, or that names a process which is no thread, is never signalled.
##   4. A thread that does not take the request (stopped) does not hold the kill: after its bound the console
##      takes its request back and kills by itself; the thread, once it goes on, kills nothing again.
##   5. The runs of a kill are no deaths, and the state of a session killed whole names the kill and by whom; a
##      session started again after that, which ends by itself, reads the ordinary reason.
##   6. The kill of one run leaves the other runs and the thread, and is recorded under the name of the console's
##      user, as its request gives it, not the thread's.
##   7. Two kills of one session at the same moment: the request of the first is not overwritten, every run is
##      ended by one of them only, both end with status 0, and each finds its own outcome.
##   8. A thread that says nothing of what it takes, as one of the step before this one, is asked nothing, and the
##      kill is carried out directly at once.
##   9. A thread that is put back in place takes nothing until it is in place again, then takes a kill as before.
##  10. A kill the thread's call does not finish within its bound is ended there and answered as failed, and the
##      console then carries the kill out itself. A request that was taken, and whose call is gone with no outcome,
##      is answered as failed by the thread and cleared, and nothing is done for it.
## Red without the change: every kill is carried out by the console itself, no request and no outcome is written,
## and nothing says which it was. Offline: a curl first on PATH only logs and nothing may call it; every thread and
## stand-in of this check is ended by it, through the rig's helpers, and every signal it sends goes through them.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigOp="--manager-session-kill"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.test.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.test.sh"
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.test.sh" || rigRefuse "the rig's helper for control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.test.sh"
rigTmp="$( mktemp -d -t AgentsSessionControlKillRequestCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data"
rigSp="$rigWs/.local/agents/spawned" ; rigStores="$rigWs/.local/agents/sessions"
mkdir -p "$rigTmp/bin" "$rigTmp/bin2" "$rigWs/.local/.agents" "$rigSp" "$rigStores" "$rigHome" "$rigSkills" "$rigData/board/running" "$rigData/board/review"
rigHost="$( hostname -s 2> /dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"
rigStarted=""
trap 'rigControlThreadsEnd "$rigTmp" ; rigProcSignalWithChildren KILL $rigStarted ; chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM

ln -s "$( command -v ps )" "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
ln -s "$( command -v id )" "$rigTmp/bin/id.real" || rigRefuse "no id on PATH to hand the other calls to"
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
printf '#!/bin/sh\n[ "$*" != "-un" ] || { echo rig ; exit 0 ; }\nexec "%s/bin/id.real" "$@"\n' "$rigTmp" > "$rigTmp/bin/id"
printf '#!/bin/sh\n[ "$*" != "-un" ] || { echo console-user ; exit 0 ; }\nexec "%s/bin/id.real" "$@"\n' "$rigTmp" > "$rigTmp/bin2/id"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/curl.calls"\nexit 7\n' "$rigTmp" > "$rigTmp/bin/curl"
chmod +x "$rigTmp/bin/ps" "$rigTmp/bin/id" "$rigTmp/bin2/id" "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v ps )" = "$rigTmp/bin/ps" ] && [ "$( command -v curl )" = "$rigTmp/bin/curl" ] \
	|| rigRefuse "the rig's own ps and curl are not first on PATH, so this check would read the host's process list or issue a real request"
## The settings of the rig: the period of a tick, and for how long a console waits for its request to be taken.
## A thread reads the first as it starts, a console the second at each call.
rigSettings(){ ## tick seconds, request seconds, the bound of a kill in seconds (the default where not given)
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSESSION_CONTROL_TICK_SECONDS=%s\nSESSION_CONTROL_REQUEST_SECONDS=%s\nSESSION_CONTROL_CLOSING_SECONDS=1\n' "$1" "$2" > "$rigWs/.local/.agents/magic-team.agent.env"
	[ -z "${3:-}" ] || printf 'SESSION_CONTROL_KILL_SECONDS=%s\n' "$3" >> "$rigWs/.local/.agents/magic-team.agent.env"
}
rigSettings 1 2
for rigMember in keeper-rig keeper-myx magic-coordinator ; do
	mkdir -p "$rigSkills/$rigMember"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
	printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
done

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigRec(){ ## run id, which is its sandbox too; session id; member
	mkdir -p "$rigSp/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nworkspace: rigws\nowner: %s\nstatus: spawn-started\nstarted-at: 2026-10-13 09:00 +0300\nspawns: dispatch-%s\n---\n\n# Spawn session: %s\n' \
		"$2" "$1" "$rigHost" "$3" "$1" "$2" > "$rigSp/$1/$1.md"
	printf -- '---\ntype: dispatch\nowner: %s\nstatus: dispatch-started\nspawn-id: %s\nsession-id: %s\n---\n\n# rig dispatch\n' "$3" "$1" "$2" > "$rigData/board/running/dispatch-$1.md"
}
## What the supervising shell of a run does once the run has ended: its record is closed.
rigClose(){ ## run id
	LC_ALL=C sed 's/^status: spawn-started$/status: spawn-failed/' "$rigSp/$1/$1.md" > "$rigSp/$1/$1.closing" && mv -f "$rigSp/$1/$1.closing" "$rigSp/$1/$1.md"
}
rigHeader(){ ## run id, header
	LC_ALL=C sed -n "s/^$2: //p" "$rigSp/$1/$1.md" 2> /dev/null | head -1
}
## A stand-in process that only waits, in the rig's process list as the run of that id, by its own --session-id word.
rigStandPid=""
rigStand(){ ## run id
	sleep 600 > /dev/null 2>&1 < /dev/null &
	rigStandPid=$!
	rigProcNote "$rigStandPid" ; rigStarted="$rigStarted $rigStandPid"
	disown "$rigStandPid" 2> /dev/null || :
	printf '%s claude --verbose --session-id %s --agent rig-member the brief\n' "$rigStandPid" "$1" >> "$rigTmp/ps.list"
}
## The same, and one the polite end does not end: it takes the hard one, two seconds later.
rigStandHard(){ ## run id
	( trap '' TERM ; exec sleep 600 ) > /dev/null 2>&1 < /dev/null &
	rigStandPid=$!
	rigProcNote "$rigStandPid" ; rigStarted="$rigStarted $rigStandPid"
	disown "$rigStandPid" 2> /dev/null || :
	printf '%s claude --verbose --session-id %s --agent rig-member the brief\n' "$rigStandPid" "$1" >> "$rigTmp/ps.list"
}
## A process of the rig that is no run and no thread: it stands in no process list of the rig.
rigBystander(){
	sleep 600 > /dev/null 2>&1 < /dev/null &
	rigStandPid=$!
	rigProcNote "$rigStandPid" ; rigStarted="$rigStarted $rigStandPid"
	disown "$rigStandPid" 2> /dev/null || :
}
rigEnded(){ ## pid -- it is no process any more, collected by its starter or not
	case "$( "$rigTmp/bin/ps.real" -o stat= -p "$1" 2> /dev/null )" in ''|*Z*) return 0 ;; esac
	return 1
}
rigLives(){ ## pid...
	local livesPid livesSaid=""
	for livesPid in "$@" ; do
		if rigEnded "$livesPid" ; then livesSaid="$livesSaid${livesSaid:+ }ended" ; else livesSaid="$livesSaid${livesSaid:+ }runs" ; fi
	done
	printf '%s' "$livesSaid"
}
rigWaitFor(){ ## seconds, test command...
	local waitLeft=$(( $1 * 5 )) ; shift
	while ! "$@" && [ "$waitLeft" -gt 0 ] ; do sleep 0.2 ; waitLeft=$(( waitLeft - 1 )) ; done
	"$@"
}
rigCall(){ ## NAME=value words, then a command -- in the rig workspace, as a bare console
	local callWords=()
	while [ $# -gt 0 ] ; do
		case "$1" in *=*) callWords[${#callWords[@]}]="$1" ; shift ;; *) break ;; esac
	done
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		${callWords[@]+"${callWords[@]}"} "$@" ) < /dev/null
}
## One call of the operation: what it printed, what it said and its status, each kept under the label.
rigAsk(){ ## label, NAME=value words, then the words of the operation
	local askLabel="$1" askWords=() ; shift
	while [ $# -gt 0 ] ; do
		case "$1" in *=*) askWords[${#askWords[@]}]="$1" ; shift ;; *) break ;; esac
	done
	rigCall ${askWords[@]+"${askWords[@]}"} bash "$rigTool" "$rigOp" "$@" > "$rigTmp/$askLabel.out" 2> "$rigTmp/$askLabel.err"
	printf '%s\n' "$?" > "$rigTmp/$askLabel.rc"
}
rigRc(){ cat "$rigTmp/$1.rc" 2> /dev/null ; }
## The rows a call printed, without their first word, their pids and their item: session, run, member, outcome, status.
rigRows(){ ## label...
	local rowsLabel
	for rowsLabel in "$@" ; do cat "$rigTmp/$rowsLabel.out" 2> /dev/null ; done \
		| LC_ALL=C awk -F'\t' '$1 == "kill" && NF == 8 { print $2 "," $3 "," $4 "," $5 "," $6 }' | LC_ALL=C sort | LC_ALL=C tr '\n' ' '
}
rigSaid(){ ## label, a whole line of what the call said -- how often it stands there
	LC_ALL=C grep -c -x -F -- "$2" "$rigTmp/$1.err" 2> /dev/null || :
}
rigSays(){ ## label, a part of a line
	LC_ALL=C grep -c -F -- "$2" "$rigTmp/$1.err" 2> /dev/null || :
}
## The real thread of a session, listed in the rig's process list under its own command line. Sets rigThreadPid.
rigThreadPid=""
rigThread(){ ## session id
	( cd "$rigWs" && exec env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash "$rigTool" --intern-session-control --run --session-id "$1" ) >> "$rigTmp/thread.$1.out" 2>> "$rigTmp/thread.$1.err" < /dev/null &
	rigThreadPid=$!
	rigProcNote "$rigThreadPid" ; rigStarted="$rigStarted $rigThreadPid"
	disown "$rigThreadPid" 2> /dev/null || :
	rigWaitFor 20 rigHolds "$1" "$rigThreadPid" || rigRefuse "the thread of $1 did not start, so nothing below would be measured: $( LC_ALL=C tr '\n' ' ' < "$rigTmp/thread.$1.err" | cut -c1-600 )"
	printf '%s %s\n' "$rigThreadPid" "$( LC_ALL=C "$rigTmp/bin/ps.real" -ww -o args= -p "$rigThreadPid" )" >> "$rigTmp/ps.list"
}
rigHolds(){ ## session id, pid -- the pid file of the session names that pid
	local holdsLine=""
	{ IFS= read -r holdsLine < "$rigStores/$1/control/pid" ; } 2> /dev/null
	[ -n "$holdsLine" ] && [ "${holdsLine%% *}" = "$2" ]
}
rigThreadIs(){ ## session id, pid -- alive, holding its session, and its log knows no end
	printf '%s:%s:%s' "$( rigEnded "$2" && echo ended || echo alive )" "$( rigHolds "$1" "$2" && echo holds || echo lost )" "$( LC_ALL=C grep -c -F -- ', ends: ' "$rigStores/$1/control/log" 2> /dev/null )"
}
rigTakes(){ ## session id -- what its thread says it takes, on one line
	LC_ALL=C tr '\n' ' ' < "$rigStores/$1/control/takes" 2> /dev/null | LC_ALL=C sed 's/ $//'
}
rigState(){ ## session id, key
	LC_ALL=C sed -n "s/^$2: //p" "$rigStores/$1/control/state" 2> /dev/null | head -1
}
rigStateIs(){ ## session id, word
	[ "$( rigState "$1" state )" = "$2" ]
}
rigLogHas(){ ## session id, text
	LC_ALL=C grep -c -F -- "$2" "$rigStores/$1/control/log" 2> /dev/null || :
}
rigOutcome(){ ## session id, a whole line -- how often the outcome file holds it
	LC_ALL=C grep -c -x -F -- "$2" "$rigStores/$1/control/outcome" 2> /dev/null || :
}
rigOutcomeOf(){ ## session id, request id, key -- the value of that key in the outcome of that request
	LC_ALL=C awk -v wantId="$2" -v wantKey="$3" 'index( $0, "request: " ) == 1 { blockIn = ( $0 == "request: " wantId ) ; next ; } blockIn && index( $0, wantKey ": " ) == 1 { print substr( $0, length( wantKey ) + 3 ) ; exit ; }' "$rigStores/$1/control/outcome" 2> /dev/null
}
rigAnswered(){ ## session id, request id
	[ -n "$( rigOutcomeOf "$1" "$2" result )" ]
}
rigGone(){ ## file...
	local goneFile
	for goneFile in "$@" ; do [ ! -e "$goneFile" ] || return 1 ; done
	return 0
}
## A request written by hand into the folder of a thread, whole, as a console puts one there.
rigRequest(){ ## session id, request id, kind, for, asked (seconds since 1970), wait
	printf 'request: %s\nkind: %s\nfor: %s\nsession: %s\nby: rig-hand\nat: 2026-10-13 09:00 +0300\nasked: %s\nwait: %s\n' "$2" "$3" "$4" "$1" "$5" "$6" > "$rigStores/$1/control/request.rig.aside" \
		&& mv -f "$rigStores/$1/control/request.rig.aside" "$rigStores/$1/control/request"
}
rigDirect(){ ## session id, why -- the one line a call says when it carried the kill out itself
	printf '# DistroAgentsTools %s: %s, so the kill is carried out directly' "$rigOp" "$2"
}

echo "-- 1. with a live thread the kill is carried out by the thread, which only the wake brings --"
rigSettings 3600 2
rigRec ka-run ka-run keeper-rig ; rigStand ka-run ; rigKa1="$rigStandPid"
rigRec ka-two ka-run keeper-myx ; rigStand ka-two ; rigKa2="$rigStandPid"
rigRec ka-three ka-run magic-coordinator ; rigStand ka-three ; rigKa3="$rigStandPid"
rigThread ka-run ; rigThreadA="$rigThreadPid"
rigWaitFor 10 rigStateIs ka-run running
rigAssert "control: the thread runs with a tick of an hour, reads its session as running, and says what it takes" \
	"$( LC_ALL=C grep -c -F -- 'a tick every 3600s' "$rigStores/ka-run/control/log" ):$( rigState ka-run state ):$( rigTakes ka-run )" "1:running:kill"
rigAsk ka --session-id ka-run
rigAssert "the id of the session: status 0, and the rows of step one, one for each of its three runs" "$( rigRc ka ) $( rigRows ka )" \
	"0 ka-run,ka-run,keeper-rig,ended,spawn-started ka-run,ka-three,magic-coordinator,ended,spawn-started ka-run,ka-two,keeper-myx,ended,spawn-started "
rigAssert "each row names the process that was signalled, and the three processes are gone" \
	"$( LC_ALL=C awk -F'\t' '$1 == "kill" { print $7 }' "$rigTmp/ka.out" | LC_ALL=C sort -n | LC_ALL=C tr '\n' ' ' ):$( rigLives "$rigKa1" "$rigKa2" "$rigKa3" )" \
	"$( printf '%s\n' "$rigKa1" "$rigKa2" "$rigKa3" | LC_ALL=C sort -n | LC_ALL=C tr '\n' ' ' ):ended ended ended"
rigAssert "the call says in one line that the thread carried it out, and not that it did so itself" \
	"$( rigSaid ka "# DistroAgentsTools $rigOp: carried out by the control thread of session ka-run, pid $rigThreadA" ):$( rigSays ka 'carried out directly' )" "1:0"
rigAssert "the request was taken by the thread: none waits and none is in work, and its log says who carried it out and what became of it" \
	"$( rigGone "$rigStores/ka-run/control/request" "$rigStores/ka-run/control/request.taken" && echo taken || echo left ):$( rigLogHas ka-run 'a request of the console stands, and is carried out by pid ' ):$( rigLogHas ka-run ', asked by rig: done, with status 0' )" "taken:1:1"
rigAssert "the outcome names the kind, the session, who asked and when, and holds the rows the call printed" \
	"$( rigOutcome ka-run 'kind: kill' ):$( rigOutcome ka-run 'for: session' ):$( rigOutcome ka-run 'session: ka-run' ):$( rigOutcome ka-run 'by: rig' ):$( LC_ALL=C grep -c -E '^at: [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2} [+-][0-9]{4}$' "$rigStores/ka-run/control/outcome" 2> /dev/null ):$( rigOutcome ka-run 'result: done' ):$( rigOutcome ka-run 'status: 0' ):$( LC_ALL=C sed -n 's/^row: //p' "$rigStores/ka-run/control/outcome" 2> /dev/null | LC_ALL=C cmp -s - <( LC_ALL=C awk -F'\t' '$1 == "kill"' "$rigTmp/ka.out" ) && echo same-rows || echo other-rows )" \
	"1:1:1:1:1:1:1:same-rows"
rigAssert "the ending of each run is on its record, under the name of the console's user" \
	"$( rigHeader ka-run killed-by ) $( rigHeader ka-two killed-by ) $( rigHeader ka-three killed-by )" "rig rig rig"
rigAssert "the thread is not ended by the kill of its session: it lives, holds its session, and its log knows no end" "$( rigThreadIs ka-run "$rigThreadA" )" "alive:holds:0"

echo "-- 2. USR1 makes the thread tick at once; a kind that is not taken, and a request left behind, are refused --"
rigRec ka-four ka-run keeper-rig ; rigStand ka-four ; rigKa4="$rigStandPid"
rigRequest ka-run hand-pause pause session "$( date +%s )" 600
sleep 3
rigAssert "control: with a tick of an hour and no wake, a request waits where it was put" \
	"$( [ -e "$rigStores/ka-run/control/request" ] && echo waits || echo taken ):$( rigAnswered ka-run hand-pause && echo answered || echo open )" "waits:open"
rigFrom="$( date +%s )"
rigProcSignal USR1 "$rigThreadA"
rigWaitFor 20 rigAnswered ka-run hand-pause
rigAssert "USR1 is sent: the thread ticks at once, takes the request and answers it, within seconds of an hour's tick" \
	"$( rigAnswered ka-run hand-pause && echo answered || echo open ):$( [ "$(( $( date +%s ) - rigFrom ))" -le 25 ] && echo at-once || echo late ):$( rigGone "$rigStores/ka-run/control/request" "$rigStores/ka-run/control/request.taken" && echo taken || echo left )" "answered:at-once:taken"
rigAssert "a kind that is not taken is answered as refused, with the reason, and nothing is done: the run lives, and no row is written" \
	"$( rigOutcomeOf ka-run hand-pause kind ):$( rigOutcomeOf ka-run hand-pause result ):$( rigOutcomeOf ka-run hand-pause reason | LC_ALL=C grep -c -F -- "the kind 'pause' is not taken" ):$( rigLives "$rigKa4" ):$( LC_ALL=C awk '$0 == "request: hand-pause" { blockIn = 1 ; next ; } /^request: / { blockIn = 0 ; } blockIn && /^row: / { rowsIn++ ; } END { print rowsIn + 0 ; }' "$rigStores/ka-run/control/outcome" )" \
	"pause:refused:1:runs:0"
rigAssert "the outcome of the kill before it stands in the file still, for the console that asked it" "$( rigOutcome ka-run 'result: done' ):$( LC_ALL=C grep -c '^request: ' "$rigStores/ka-run/control/outcome" )" "1:2"
rigRequest ka-run hand-late kill session "$(( $( date +%s ) - 100 ))" 2
rigProcSignal USR1 "$rigThreadA"
rigWaitFor 20 rigAnswered ka-run hand-late
rigAssert "a request left behind, asked longer ago than its console waited, is refused and nothing is ended: no thread that comes later carries it out" \
	"$( rigOutcomeOf ka-run hand-late result ):$( rigOutcomeOf ka-run hand-late reason | LC_ALL=C grep -c -F -- 'a request left behind is not carried out' ):$( rigLives "$rigKa4" ):$( rigHeader ka-four killed-by )" "refused:1:runs:"
rigAssert "the thread lives through all of it" "$( rigThreadIs ka-run "$rigThreadA" )" "alive:holds:0"

echo "-- 3. with no thread the operation kills as before, and never signals a process that is not shown to be the thread --"
rigSettings 1 2
rigRec kb-run kb-run keeper-rig ; rigStand kb-run ; rigKb1="$rigStandPid"
rigRec kb-two kb-run keeper-myx ; rigStand kb-two ; rigKb2="$rigStandPid"
rigAsk kb --session-id kb-run
rigAssert "a session with live runs and no control thread: status 0, the rows of step one, the processes gone, the ending on the records" \
	"$( rigRc kb ) $( rigRows kb ):$( rigLives "$rigKb1" "$rigKb2" ):$( rigHeader kb-run killed-by ) $( rigHeader kb-two killed-by )" \
	"0 kb-run,kb-run,keeper-rig,ended,spawn-started kb-run,kb-two,keeper-myx,ended,spawn-started :ended ended:rig rig"
rigAssert "it writes no request, and says in one line that it carried the kill out itself and why" \
	"$( [ -e "$rigStores/kb-run/control" ] && echo control-made || echo none ):$( rigSaid kb "$( rigDirect kb-run 'session kb-run has no control thread alive' )" ):$( rigSays kb 'by the control thread' )" "none:1:0"
rigRec kh-run kh-run keeper-rig ; rigStand kh-run ; rigKh1="$rigStandPid"
rigRec kh-two kh-run keeper-myx ; rigStand kh-two ; rigKh2="$rigStandPid"
rigBystander ; rigBy="$rigStandPid"
mkdir -p "$rigStores/kh-run/control"
printf 'kill\n' > "$rigStores/kh-run/control/takes"
printf '%s Thu_Jan__1_00:00:00_1970\n' "$rigBy" > "$rigStores/kh-run/control/pid"
rigAsk kh2 --session-id kh-two --run
rigAssert "a pid file whose number another process has, begun at another time: that process is not signalled, and the kill is carried out directly" \
	"$( rigRc kh2 ) $( rigRows kh2 ):$( rigLives "$rigBy" "$rigKh2" "$rigKh1" ):$( rigSaid kh2 "$( rigDirect kh-run 'session kh-run has no control thread alive' )" ):$( rigGone "$rigStores/kh-run/control/request" && echo no-request || echo request )" \
	"0 kh-run,kh-two,keeper-myx,ended,spawn-started :runs ended runs:1:no-request"
rigProcBegan "$rigBy" > "$rigStores/kh-run/control/pid"
rigAsk kh1 --session-id kh-run
rigAssert "a pid file that names a live process which is no control thread: that process is not signalled either, and the kill is carried out directly" \
	"$( rigRc kh1 ) $( rigRows kh1 | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c -F -- ',kh-run,keeper-rig,ended,' ):$( rigLives "$rigBy" "$rigKh1" ):$( rigSaid kh1 "$( rigDirect kh-run "pid $rigBy holds session kh-run and is no control thread that runs" )" ):$( rigGone "$rigStores/kh-run/control/request" && echo no-request || echo request )" \
	"0 1:runs ended:1:no-request"

echo "-- 4. a thread that does not take the request does not hold the kill, and kills nothing later --"
rigRec kc-run kc-run keeper-rig ; rigStand kc-run ; rigKc1="$rigStandPid"
rigRec kc-two kc-run keeper-myx ; rigStand kc-two ; rigKc2="$rigStandPid"
rigThread kc-run ; rigThreadC="$rigThreadPid"
rigWaitFor 10 rigStateIs kc-run running
rigProcSignal STOP "$rigThreadC"
rigFrom="$( date +%s )"
rigAsk kc --session-id kc-run
rigTook=$(( $( date +%s ) - rigFrom ))
rigAssert "its thread is stopped and takes no request: after the bound of two seconds the call kills by itself, status 0, the rows of step one, the processes gone" \
	"$( rigRc kc ) $( rigRows kc ):$( rigLives "$rigKc1" "$rigKc2" ):$( [ "$rigTook" -ge 2 ] && [ "$rigTook" -le 30 ] && echo after-its-bound || echo "after ${rigTook}s" )" \
	"0 kc-run,kc-run,keeper-rig,ended,spawn-started kc-run,kc-two,keeper-myx,ended,spawn-started :ended ended:after-its-bound"
rigAssert "it says so in one line, and has taken its request back: none waits, none is in work" \
	"$( rigSaid kc "$( rigDirect kc-run "the control thread of session kc-run, pid $rigThreadC, did not take the request within 2s and the request is taken back" )" ):$( rigGone "$rigStores/kc-run/control/request" "$rigStores/kc-run/control/request.taken" && echo taken-back || echo left ):$( ls "$rigStores/kc-run/control" | LC_ALL=C grep -c -e 'aside' -e 'back' )" "1:taken-back:0"
rigRec kc-new kc-run keeper-rig ; rigStand kc-new ; rigKc3="$rigStandPid"
rigProcSignal CONT "$rigThreadC"
sleep 4
rigAssert "the thread goes on, and a run that joined the session since lives: the kill is not carried out a second time, and no outcome was written" \
	"$( rigThreadIs kc-run "$rigThreadC" ):$( rigLives "$rigKc3" ):$( rigHeader kc-new killed-by ):$( [ -e "$rigStores/kc-run/control/outcome" ] && echo outcome || echo none )" "alive:holds:0:runs::none"

echo "-- 5. the runs of a kill are no deaths, and the state of a killed session names the kill --"
rigSettings 1 20
rigRec kd-run kd-run keeper-rig ; rigStand kd-run ; rigKd1="$rigStandPid"
rigRec kd-two kd-run keeper-myx ; rigStand kd-two ; rigKd2="$rigStandPid"
rigThread kd-run ; rigThreadD="$rigThreadPid"
rigWaitFor 10 rigStateIs kd-run running
rigAsk kd --session-id kd-run
rigAssert "control: the session is killed through its thread" "$( rigRc kd ) $( rigSays kd 'carried out by the control thread of session kd-run' ):$( rigLives "$rigKd1" "$rigKd2" )" "0 1:ended ended"
sleep 4
rigAssert "the runs of the kill are no deaths, also once the closing time of a record has passed: no line is kept of one, and nothing is asked; their records, which no supervising shell is left to close, were closed by the kill, so the session is finished and its thread has ended by itself" \
	"$( [ -s "$rigStores/kd-run/control/dead" ] && echo dead-kept || echo none ):$( ls "$rigWs/.local/agents/pending" 2> /dev/null | LC_ALL=C grep -c . ):$( rigState kd-run state ):$( rigThreadIs kd-run "$rigThreadD" ):$( rigHeader kd-run status ) $( rigHeader kd-two status )" "none:0:finished:ended:lost:1:spawn-ended-without-close spawn-ended-without-close"
rigClose kd-run ; rigClose kd-two
rigWaitFor 20 rigStateIs kd-run finished
rigWaitFor 20 rigEnded "$rigThreadD"
rigAssert "the supervising shell of each run closes its record: the state is finished, its reason names the kill and who asked it, and the thread ends by itself" \
	"$( rigState kd-run state ):$( rigState kd-run reason | LC_ALL=C grep -c -E '^the session was killed by rig, asked [0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2} [+-][0-9]{4}: no run of the session is alive and every record of it is closed$' ):$( rigEnded "$rigThreadD" && echo ended || echo alive ):$( rigLogHas kd-run ', ends: its session is finished' )" \
	"finished:1:ended:1"
sleep 1
rigRec kd-new kd-run keeper-rig ; rigStand kd-new ; rigKd3="$rigStandPid"
rigThread kd-run ; rigThreadD2="$rigThreadPid"
rigWaitFor 10 rigStateIs kd-run running
rigRunning="$( rigState kd-run state )"
rigClose kd-new
rigProcSignal KILL "$rigKd3"
rigWaitFor 20 rigStateIs kd-run finished
rigAssert "the session is started again and ends by itself: its state reads the ordinary reason, though the outcome of the old kill stands in its folder" \
	"$rigRunning:$( rigState kd-run state ):$( rigState kd-run reason ):$( rigOutcome kd-run 'result: done' )" \
	"running:finished:no run of the session is alive and every record of it is closed:1"

echo "-- 6. the kill of one run leaves the other runs and the thread, under the name its request gives --"
rigRec kf-run kf-run keeper-rig ; rigStand kf-run ; rigKf1="$rigStandPid"
rigRec kf-two kf-run keeper-myx ; rigStand kf-two ; rigKf2="$rigStandPid"
rigThread kf-run ; rigThreadF="$rigThreadPid"
rigWaitFor 10 rigStateIs kf-run running
rigAsk kf "PATH=$rigTmp/bin2:$PATH" --session-id kf-two --run
sleep 2
rigAssert "the own id of one run with --run: that run is ended, the founder lives, and the thread stays with the state running" \
	"$( rigRc kf ) $( rigRows kf ):$( rigLives "$rigKf2" "$rigKf1" ):$( rigSays kf "carried out by the control thread of session kf-run, pid $rigThreadF" ):$( rigThreadIs kf-run "$rigThreadF" ):$( rigState kf-run state )" \
	"0 kf-run,kf-two,keeper-myx,ended,spawn-started :ended runs:1:alive:holds:0:running"
rigAssert "the request named the run and the user of the console, and the ending is recorded under that name, not the thread's" \
	"$( rigOutcome kf-run 'for: run kf-two' ):$( rigOutcome kf-run 'by: console-user' ):$( rigHeader kf-two killed-by ):$( rigHeader kf-run killed-by )" "1:1:console-user:"
rigAsk kfx "agentsSessionControlCarried=kf-run no-such-request" --session-id kf-run
rigAssert "a call that says it carries out a request of a thread, where no such request stands taken, is refused: status 1, one error line, nothing printed, the run lives" \
	"$( rigRc kfx ) $( wc -c < "$rigTmp/kfx.out" | LC_ALL=C tr -d ' ' ) $( rigSays kfx 'no such request stands taken for session kf-run -- nothing was signalled' ):$( rigLives "$rigKf1" )" "1 0 1:runs"

echo "-- 7. two kills of one session at the same moment --"
rigRec kg-run kg-run keeper-rig ; rigStand kg-run ; rigKg1="$rigStandPid"
rigRec kg-two kg-run keeper-myx ; rigStand kg-two ; rigKg2="$rigStandPid"
rigRec kg-three kg-run magic-coordinator ; rigStand kg-three ; rigKg3="$rigStandPid"
rigThread kg-run ; rigThreadG="$rigThreadPid"
rigWaitFor 10 rigStateIs kg-run running
rigAsk kg1 --session-id kg-run &
rigJobOne=$!
rigAsk kg2 --session-id kg-run &
rigJobTwo=$!
wait "$rigJobOne" "$rigJobTwo"
rigAssert "both calls end with status 0, and each was answered by the thread" \
	"$( rigRc kg1 ) $( rigRc kg2 ):$( rigSays kg1 'carried out by the control thread of session kg-run' ) $( rigSays kg2 'carried out by the control thread of session kg-run' )" "0 0:1 1"
rigAssert "every run is ended by one of them only: three rows say ended over both, and the other three say that no process was there" \
	"$( rigRows kg1 kg2 | LC_ALL=C tr ' ' '\n' | LC_ALL=C awk -F, 'NF == 5 { said[$2 " " $4]++ ; } END { for ( run in said ) print run "=" said[run] ; }' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' ):$( rigLives "$rigKg1" "$rigKg2" "$rigKg3" )" \
	"kg-run ended=1 kg-run no-process=1 kg-three ended=1 kg-three no-process=1 kg-two ended=1 kg-two no-process=1 :ended ended ended"
rigAssert "the request of the first is not overwritten: the outcome file holds both, each done, and each call printed the rows of its own" \
	"$( LC_ALL=C grep -c '^request: ' "$rigStores/kg-run/control/outcome" ):$( rigOutcome kg-run 'result: done' ):$( LC_ALL=C sed -n 's/^row: //p' "$rigStores/kg-run/control/outcome" | LC_ALL=C sort | LC_ALL=C cmp -s - <( cat "$rigTmp/kg1.out" "$rigTmp/kg2.out" | LC_ALL=C awk -F'\t' '$1 == "kill"' | LC_ALL=C sort ) && echo same-rows || echo other-rows )" "2:2:same-rows"
rigAssert "and the ending of each run is recorded once" \
	"$( cat "$rigData"/board/*/dispatch-kg-run.md "$rigData"/board/*/dispatch-kg-two.md "$rigData"/board/*/dispatch-kg-three.md 2> /dev/null | LC_ALL=C grep -c -F -- 'manager-kill' )" "3"

echo "-- 8. a thread that says nothing of what it takes is asked nothing --"
rigSettings 3600 20
rigRec ki-run ki-run keeper-rig ; rigStand ki-run ; rigKi1="$rigStandPid"
rigThread ki-run ; rigThreadI="$rigThreadPid"
rigWaitFor 10 rigStateIs ki-run running
rm -f "$rigStores/ki-run/control/takes"
rigFrom="$( date +%s )"
rigAsk ki --session-id ki-run
rigTook=$(( $( date +%s ) - rigFrom ))
rigAssert "a live thread that keeps no word of what it takes, as one of the step before: the kill is carried out directly, at once and not after the bound of twenty seconds, and no request is written" \
	"$( rigRc ki ) $( rigRows ki ):$( rigLives "$rigKi1" ):$( rigSaid ki "$( rigDirect ki-run "the control thread of session ki-run, pid $rigThreadI, takes no kill request" )" ):$( [ "$rigTook" -lt 15 ] && echo at-once || echo "after ${rigTook}s" ):$( rigGone "$rigStores/ki-run/control/request" "$rigStores/ki-run/control/outcome" && echo no-request || echo request )" \
	"0 ki-run,ki-run,keeper-rig,ended,spawn-started :ended:1:at-once:no-request"

echo "-- 9. a thread that is put back in place takes nothing until it is in place again --"
rigSettings 3600 5
rigRec kj-run kj-run keeper-rig ; rigStand kj-run ; rigKj1="$rigStandPid"
rigThread kj-run ; rigThreadJ="$rigThreadPid"
rigWaitFor 10 rigStateIs kj-run running
rigBefore="$( rigTakes kj-run )"
rigSeen="never" ; rigFrom="$SECONDS"
rigProcSignal XCPU "$rigThreadJ"
while [ "$(( SECONDS - rigFrom ))" -lt 15 ] ; do
	rigLine="-"
	{ IFS= read -r rigLine < "$rigStores/kj-run/control/takes" ; } 2> /dev/null
	[ -n "$rigLine" ] || { rigSeen="empty" ; break ; }
done
rigTakesKill(){ [ "$( rigTakes "$1" )" = "kill" ] ; }
rigWaitFor 20 rigTakesKill kj-run
rigAssert "the shell of a thread ends without its doing: while it is put back it takes nothing, and once it is in place, the same process, it says again what it takes" \
	"$rigBefore:$rigSeen:$( rigTakes kj-run ):$( rigLogHas kj-run "is put back in place, pid $rigThreadJ as before" ):$( rigThreadIs kj-run "$rigThreadJ" )" "kill:empty:kill:1:alive:holds:0"
rigAsk kj --session-id kj-run
rigAssert "and it takes a kill as before: the wake reaches the thread that was put back, which carries the kill out" \
	"$( rigRc kj ) $( rigRows kj ):$( rigLives "$rigKj1" ):$( rigSays kj "carried out by the control thread of session kj-run, pid $rigThreadJ" ):$( rigThreadIs kj-run "$rigThreadJ" )" \
	"0 kj-run,kj-run,keeper-rig,ended,spawn-started :ended:1:alive:holds:0"

echo "-- 10. a kill that is not finished within its bound, and a request whose call is gone --"
rigSettings 1 20 1
rigRec kk-run kk-run keeper-rig ; rigStandHard kk-run ; rigKk1="$rigStandPid"
rigThread kk-run ; rigThreadK="$rigThreadPid"
rigWaitFor 10 rigStateIs kk-run running
rigAsk kk --session-id kk-run
rigAssert "a run the polite end does not end, and a bound of one second for the kill: the call of the thread is ended at its bound and answers failed, and the console carries the kill out itself, to its end" \
	"$( rigRc kk ) $( rigRows kk ):$( rigLives "$rigKk1" ):$( rigOutcome kk-run 'result: failed' ):$( LC_ALL=C grep -c -F -- 'reason: it did not end within its bound of 1 seconds, and was ended' "$rigStores/kk-run/control/outcome" 2> /dev/null ):$( rigSays kk "the control thread of session kk-run, pid $rigThreadK, did not carry the request out (failed: it did not end within its bound of 1 seconds, and was ended" ):$( rigSays kk ', so the kill is carried out directly' ):$( LC_ALL=C awk -F'\t' '$1 == "finish" { print $3, $6 }' "$rigTmp/kk.out" )" \
	"0 kk-run,kk-run,keeper-rig,killed,spawn-started :ended:1:1:1:1:1 finished"
rigRec kl-run kl-run keeper-rig ; rigStand kl-run ; rigKl1="$rigStandPid"
rigThread kl-run ; rigThreadL="$rigThreadPid"
rigWaitFor 10 rigStateIs kl-run running
printf 'request: hand-lost\nkind: kill\nfor: session\nsession: kl-run\nby: rig-hand\nat: 2026-10-13 09:00 +0300\nasked: %s\nwait: 20\n' "$( date +%s )" > "$rigStores/kl-run/control/request.rig.aside" \
	&& mv -f "$rigStores/kl-run/control/request.rig.aside" "$rigStores/kl-run/control/request.taken"
rigWaitFor 20 rigAnswered kl-run hand-lost
rigAssert "a request that stands taken, with no process at work on it and no outcome: after the bound of a kill the thread answers it as failed and clears it, says so, and ends nothing" \
	"$( rigOutcomeOf kl-run hand-lost result ):$( rigOutcomeOf kl-run hand-lost reason | LC_ALL=C grep -c -F -- 'the process that took it ended and left no outcome' ):$( rigGone "$rigStores/kl-run/control/request.taken" && echo cleared || echo left ):$( rigLogHas kl-run 'the request hand-lost was taken, and the process that took it ended with no outcome' ):$( rigLives "$rigKl1" ):$( rigHeader kl-run killed-by ):$( rigThreadIs kl-run "$rigThreadL" )" \
	"failed:1:cleared:1:runs::alive:holds:0"

rigAssert "no request over the network was made" "$( [ -e "$rigTmp/curl.calls" ] && echo called || echo none )" "none"

echo ""
if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SESSION CONTROL KILL REQUEST CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2
	echo "  warn: a kill of a session does not go through its control thread as it should, or depends on it" >&2
	echo "  fix:  the request and its outcome (sh-lib/AgentsTools.SessionControlRequest.include), the thread's look at a tick and its call apart (sh-lib/AgentsTools.InternSessionControl.include), the operation (sh-lib/AgentsTools.ManagerSession.include) -- never the assertion" >&2
	exit 1
fi
printf 'SESSION_CONTROL_KILL_REQUEST: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
