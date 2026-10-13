#!/usr/bin/env bash
## Behavioural check on the signals of a console session (sh-lib/AgentsTools.ConsoleSession.include), each run
## rather than read: --console-stop ends the console and the holder of a channel, and --console-start ends what
## is left of a channel it finds stale. Both know those processes by the pid files of the channel, and a pid is a
## number the system gives again: a channel folder stays for as long as nobody stops it, and its files may be of
## any age.
## Drives the real operations on workspaces of the rig whose console is a stand-in that says what it is sent,
## with the rig's own process list for the one reading a process is kept by (its pid, its state, when it began).
## Held here:
##   1. A SESSION AS BEFORE. A start prints its two pids as numbers, a second start reuses the channel, the list
##      says both alive, a command sent reaches the console, and a stop ends both and removes the channel. A
##      console that ignores `exit` and the polite end is ended by the hard one a second later.
##   2. THE PID FILES. console.pid and holder.pid each hold one line, `<pid> <start>`, as the tooling keeps a
##      process.
##   3. THE NUMBER TAKEN BY ANOTHER PROCESS IS NOT SIGNALLED, by a stop or by a start over a stale channel: where
##      the process list says that the pid began at another time than the file says, nothing is signalled, and the
##      process that has the number lives on (in the rig it is the channel's own process, so that an operation
##      that did signal it ends nothing of anyone's). The channel is removed, or made anew, all the same.
##   4. A PID FILE WITH NO START, as channels were kept before: nothing is signalled by the number alone, and the
##      caller is told which process was left, by its pid.
##   5. A start over a stale channel still ends what is left of it where that is still the process the file names.
## Red: with the operations as they were (`kill`, `kill -9` of the pid a file holds, on a probe of the number or
## on none), 2 fails, and 3 and 4 fail: the processes that have the numbers are ended.
## Offline: one mktemp tree, consoles and holders of the rig alone, all ended at its end; nothing is requested.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigFn="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigInclude="$rigPackage/sh-lib/AgentsTools.ConsoleSession.include"
rigHelper="$rigPackage/sh-test/check-fixtures/rig-processes.include.test.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigFn" "$rigInclude" "$rigHelper" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
. "$rigHelper" || rigRefuse "the rig's process helper could not be read: $rigHelper"
rigRealPs="$( command -v ps )" || rigRefuse "no ps on PATH to hand the other calls to"
rigTmp="$( mktemp -d -t AgentsConsoleSessionSignalsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## Every console and holder the rig started, and what each had started, is ended at the end, only while it is
## still the process that was noted as it started.
rigEnd(){
	rigProcNoteFrom "$rigTmp"/*/notes
	rigProcSignalWithChildren KILL $( cat "$rigTmp"/*/notes 2> /dev/null | LC_ALL=C awk '{ print $1 ; }' )
	rm -rf -- "$rigTmp"
}
trap rigEnd EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigTmp/skills"

## THE STAND-IN FOR A CONSOLE: it says each line it is sent, and `exit` ends it. With rig.deaf in its workspace it
## ignores the polite end and `exit`, and stays when its commands end.
cat > "$rigTmp/console" <<'RIGCONSOLE'
#!/usr/bin/env bash
rigDeaf="" ; [ ! -e "$MMDAPP/rig.deaf" ] || rigDeaf=1
[ -z "$rigDeaf" ] || trap '' TERM
while IFS= read -r rigLine ; do
	printf 'RIG-CONSOLE-GOT: %s\n' "$rigLine"
	[ "$rigLine" != exit ] || [ -n "$rigDeaf" ] || exit 0
done
[ -z "$rigDeaf" ] || sleep 300
RIGCONSOLE
## THE RIG'S OWN PROCESS LIST, for the one reading a process is kept by: from the moment the scenario's folder
## holds ps.lie, every such reading says that the same pid began at another time, as it reads once the number has
## been given to another process. Every other call is the host's ps.
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case "$*" in
	*lstart=*)
		if [ -e "$RIG_DIR/ps.lie" ] ; then
			"$RIG_REAL_PS" "$@" | sed 's/[0-9][0-9][0-9][0-9] *$/2001/'
			exit 0
		fi
	;;
esac
exec "$RIG_REAL_PS" "$@"
RIGPS
chmod +x "$rigTmp/bin/ps" "$rigTmp/console"

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigCode(){ LC_ALL=C grep -v '^[[:space:]]*#' "$1" ; } ## file -- its lines that are no comment
rigScene(){ ## scenario, deaf or empty -- its workspace, with the stand-in for its console
	mkdir -p "$rigTmp/$1/ws/.local/temp" || rigRefuse "could not create the rig"
	cp "$rigTmp/console" "$rigTmp/$1/ws/DistroSourceConsole.sh" && chmod +x "$rigTmp/$1/ws/DistroSourceConsole.sh"
	[ -z "${2:-}" ] || : > "$rigTmp/$1/ws/rig.deaf"
}
rigTool(){ ## scenario, the operation and its arguments
	local toolDir="$rigTmp/$1" ; shift
	( cd "$toolDir/ws" && env -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT PATH="$rigTmp/bin:$PATH" HOME="$rigTmp/home" MMDAPP="$toolDir/ws" MDAT_SKILLSET_ROOT="$rigTmp/skills" RIG_DIR="$toolDir" RIG_REAL_PS="$rigRealPs" bash "$rigFn" "$@" )
}
rigValue(){ ## scenario, label of a start, key -- the value the start printed for it
	LC_ALL=C sed -n "s/^$3=//p" "$rigTmp/$1/$2.out" 2> /dev/null | head -1
}
## One start. Its two processes are noted as they are now, and what the holder has started with them, for the
## questions of this check and for its end.
rigStart(){ ## scenario, label
	local startHolder startKid="" startTurns=15
	rigTool "$1" --console-start --ttl 90 > "$rigTmp/$1/$2.out" 2> "$rigTmp/$1/$2.err" ; echo "$?" > "$rigTmp/$1/$2.rc"
	startHolder="$( rigValue "$1" "$2" HOLDER_PID )"
	rigProcNoteFile "$rigTmp/$1/notes" $( rigValue "$1" "$2" CONSOLE_PID ) $startHolder
	while [ -n "$startHolder" ] && [ -z "$startKid" ] && [ "$startTurns" -gt 0 ] ; do
		startKid="$( "$rigRealPs" -A -o pid=,ppid= 2> /dev/null | LC_ALL=C awk -v holderPid="$startHolder" '$2 == holderPid { print $1 ; }' )"
		[ -n "$startKid" ] || { sleep 0.2 ; startTurns=$(( startTurns - 1 )) ; }
	done
	[ -z "$startKid" ] || rigProcNoteFile "$rigTmp/$1/notes" $startKid
}
rigStop(){ ## scenario
	rigTool "$1" --console-stop "$( rigValue "$1" s1 CHANNEL )" > "$rigTmp/$1/stop.out" 2> "$rigTmp/$1/stop.err" ; echo "$?" > "$rigTmp/$1/stop.rc"
}
rigBare(){ ## scenario, console or holder -- its pid file made to hold the pid alone, as channels were kept before
	local bareFile ; bareFile="$( rigValue "$1" s1 CHANNEL_DIR )/$2.pid"
	LC_ALL=C sed 's/ .*//' "$bareFile" > "$bareFile.rig" && mv "$bareFile.rig" "$bareFile"
}
## The console of a scenario ended hard, as one that died would be: the channel is then stale, its holder left.
rigConsoleDies(){ ## scenario
	local diesPid diesTurns=25
	diesPid="$( rigValue "$1" s1 CONSOLE_PID )"
	rigProcNoteFrom "$rigTmp/$1/notes"
	rigProcSignal KILL "$diesPid"
	while kill -0 "$diesPid" 2> /dev/null && [ "$diesTurns" -gt 0 ] ; do sleep 0.2 ; diesTurns=$(( diesTurns - 1 )) ; done
}

## THE SCENARIOS, each on a workspace and a channel of its own, side by side.
rigPlain(){
	rigScene plain ; rigStart plain s1
	cp "$( rigValue plain s1 CHANNEL_DIR )/console.pid" "$rigTmp/plain/console.pid.kept" ; cp "$( rigValue plain s1 CHANNEL_DIR )/holder.pid" "$rigTmp/plain/holder.pid.kept"
	rigStart plain s2
	rigTool plain --console-list > "$rigTmp/plain/list.out" 2> "$rigTmp/plain/list.err"
	rigTool plain --console-send "$( rigValue plain s1 CHANNEL )" -- hello rig > "$rigTmp/plain/send.out" 2> "$rigTmp/plain/send.err"
	sleep 1 ; cp "$( rigValue plain s1 LOG )" "$rigTmp/plain/log.kept"
	rigStop plain
}
rigDeaf(){ rigScene deaf deaf ; rigStart deaf s1 ; rigStop deaf ; }
rigTaken(){ rigScene taken deaf ; rigStart taken s1 ; : > "$rigTmp/taken/ps.lie" ; rigStop taken ; }
rigLegacy(){ rigScene bare deaf ; rigStart bare s1 ; rigBare bare console ; rigBare bare holder ; rigStop bare ; }
rigStale(){ rigScene stale ; rigStart stale s1 ; rigConsoleDies stale ; rigStart stale s2 ; }
rigStaleTaken(){ rigScene stale-taken ; rigStart stale-taken s1 ; rigConsoleDies stale-taken ; : > "$rigTmp/stale-taken/ps.lie" ; rigStart stale-taken s2 ; }
rigStaleLegacy(){ rigScene stale-bare ; rigStart stale-bare s1 ; rigConsoleDies stale-bare ; rigBare stale-bare holder ; rigStart stale-bare s2 ; }
rigPlain & rigDeaf & rigTaken & rigLegacy & rigStale & rigStaleTaken & rigStaleLegacy &
wait
rigProcNoteFrom "$rigTmp"/*/notes
rigLive(){ ## scenario, label of a start -- which of its two processes are still the processes that were noted: console, holder
	local liveSaid=""
	[ -z "$( rigProcStill "$( rigValue "$1" "$2" CONSOLE_PID )" )" ] || liveSaid="console"
	[ -z "$( rigProcStill "$( rigValue "$1" "$2" HOLDER_PID )" )" ] || liveSaid="$liveSaid${liveSaid:+ }holder"
	printf '%s' "${liveSaid:-none}"
}
rigSaid(){ ## file, fixed text -- how many lines of the file hold it
	LC_ALL=C grep -c -F -- "$2" "$1" 2> /dev/null || :
}
rigKeptForm='^[0-9]+ [A-Z][a-z]{2}_[A-Z][a-z]{2}_[0-9]{1,2}_[0-9:]{8}_[0-9]{4}$'

echo "-- 1. a session as before: start, reuse, list, send, stop --"
rigAssert "a start prints its two pids as numbers, and the channel" \
	"$( cat "$rigTmp/plain/s1.rc" ) $( LC_ALL=C grep -c -E -e '^CONSOLE_PID=[0-9]+$' -e '^HOLDER_PID=[0-9]+$' "$rigTmp/plain/s1.out" ) $( LC_ALL=C grep -c -E '^CHANNEL=myx\.distro-agent-console\.[0-9]+\.source$' "$rigTmp/plain/s1.out" )" "0 2 1"
rigAssert "a second start reuses the channel: it says so, and prints the same two pids, as numbers" \
	"$( rigSaid "$rigTmp/plain/s2.err" 'reusing already-active channel' ) $( rigSaid "$rigTmp/plain/s2.out" "CONSOLE_PID=$( rigValue plain s1 CONSOLE_PID )" ) $( rigSaid "$rigTmp/plain/s2.out" "HOLDER_PID=$( rigValue plain s1 HOLDER_PID )" ) $( LC_ALL=C grep -c -E -e '^CONSOLE_PID=[0-9]+$' -e '^HOLDER_PID=[0-9]+$' "$rigTmp/plain/s2.out" )" "1 1 1 2"
rigAssert "the list says the console and the holder alive" "$( rigSaid "$rigTmp/plain/list.out" 'console=alive holder=alive' )" 1
rigAssert "a command sent reaches the console" "$( rigSaid "$rigTmp/plain/log.kept" 'RIG-CONSOLE-GOT: hello rig' )" 1
rigAssert "a stop ends the console and the holder, says so, removes the channel, and warns of nothing" \
	"$( rigLive plain s1 ) $( rigSaid "$rigTmp/plain/stop.out" "STOPPED=$( rigValue plain s1 CHANNEL )" ) $( [ -e "$( rigValue plain s1 CHANNEL_DIR )" ] && echo left || echo removed ) $( rigSaid "$rigTmp/plain/stop.err" 'WARNING' )" "none 1 removed 0"
rigAssert "a console that ignores exit and the polite end is ended by the hard one, and its holder with it" \
	"$( rigLive deaf s1 ) $( rigSaid "$rigTmp/deaf/stop.out" 'STOPPED=' )" "none 1"

echo "-- 2. the pid files hold the pid and when the process began --"
rigAssert "console.pid and holder.pid each hold one line, the pid the start printed and when it began, as the tooling keeps a process" \
	"$( LC_ALL=C grep -c -E "$rigKeptForm" "$rigTmp/plain/console.pid.kept" 2> /dev/null || : ) $( LC_ALL=C grep -c "^$( rigValue plain s1 CONSOLE_PID ) " "$rigTmp/plain/console.pid.kept" 2> /dev/null || : ) $( LC_ALL=C grep -c -E "$rigKeptForm" "$rigTmp/plain/holder.pid.kept" 2> /dev/null || : ) $( LC_ALL=C grep -c "^$( rigValue plain s1 HOLDER_PID ) " "$rigTmp/plain/holder.pid.kept" 2> /dev/null || : ) $( cat "$rigTmp/plain/console.pid.kept" "$rigTmp/plain/holder.pid.kept" 2> /dev/null | wc -l | LC_ALL=C tr -d ' ' )" "1 1 1 1 2"

echo "-- 3. a stop: the number another process has taken is not signalled; a pid file with no start is not signalled by the number alone --"
rigAssert "the process list says that both pids began at another time than their files say: neither is signalled and both live on, nothing is warned of, and the channel is removed all the same" \
	"$( rigLive taken s1 ) $( rigSaid "$rigTmp/taken/stop.out" 'STOPPED=' ) $( [ -e "$( rigValue taken s1 CHANNEL_DIR )" ] && echo left || echo removed ) $( rigSaid "$rigTmp/taken/stop.err" 'WARNING' )" "console holder 1 removed 0"
rigAssert "pid files with no start, as channels were kept before: neither process is signalled by the number alone, both live on, and the caller is told of each, by its pid" \
	"$( rigLive bare s1 ) $( rigSaid "$rigTmp/bare/stop.out" 'STOPPED=' ) $( rigSaid "$rigTmp/bare/stop.err" "--console-stop: the console process of this channel was NOT signalled" ) $( rigSaid "$rigTmp/bare/stop.err" "console.pid names pid $( rigValue bare s1 CONSOLE_PID ) with no start time" ) $( rigSaid "$rigTmp/bare/stop.err" "--console-stop: the holder process of this channel was NOT signalled" ) $( rigSaid "$rigTmp/bare/stop.err" "holder.pid names pid $( rigValue bare s1 HOLDER_PID ) with no start time" )" "console holder 1 1 1 1 1"

echo "-- 4. a start over a stale channel: what is left of it is ended only while it is still the process its file names --"
rigAssert "control: each of the three channels was stale, its console gone and its holder left, and was made anew" \
	"$( cat "$rigTmp/stale/s2.err" "$rigTmp/stale-taken/s2.err" "$rigTmp/stale-bare/s2.err" 2> /dev/null | LC_ALL=C grep -c -F 'stale channel found (no live processes), recreating' ) $( cat "$rigTmp/stale/s2.rc" "$rigTmp/stale-taken/s2.rc" "$rigTmp/stale-bare/s2.rc" 2> /dev/null | LC_ALL=C tr '\n' ' ' )" "3 0 0 0 "
rigAssert "the holder left of a stale channel, still the process its file names, is ended, and the new channel has a console and a holder of its own" \
	"$( rigLive stale s1 ) / $( rigLive stale s2 ) / $( [ "$( rigValue stale s1 HOLDER_PID )" != "$( rigValue stale s2 HOLDER_PID )" ] && echo another-holder )" "none / console holder / another-holder"
rigAssert "its number taken by another process, the holder a file names is not signalled and lives on, and nothing is warned of" \
	"$( rigLive stale-taken s1 ) $( rigSaid "$rigTmp/stale-taken/s2.err" 'WARNING' )" "holder 0"
rigAssert "a holder file with no start: nothing is signalled by the number alone, the process lives on, and the caller is told of it, by its pid" \
	"$( rigLive stale-bare s1 ) $( rigSaid "$rigTmp/stale-bare/s2.err" "--console-start: the holder process of this channel was NOT signalled" ) $( rigSaid "$rigTmp/stale-bare/s2.err" "holder.pid names pid $( rigValue stale-bare s1 HOLDER_PID ) with no start time" )" "holder 1 1"

echo "-- a session keeps its processes by the one reading the tooling keeps a process by --"
rigAssert "the include signals the pid of a file with the comparison of when it began, keeps and reads that through AgentsToolsRegistryProcessesBegan, and ends no pid by the old names" \
	"$( rigCode "$rigInclude" | LC_ALL=C grep -c -F '= "$signalLine" ] && kill "-$1" "$signalPid"' ) $( rigCode "$rigInclude" | LC_ALL=C grep -c -F '| AgentsToolsRegistryProcessesBegan' ) $( rigCode "$rigInclude" | LC_ALL=C grep -c -e '-9 "\$' )" "1 2 0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ CONSOLE SESSION SIGNALS CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'CONSOLE_SESSION_SIGNALS: OK (%d assertions, offline)\n' "$rigPasses"
