#!/usr/bin/env bash
## Behavioural check on the signal reset of the death call of the session control thread (sh-lib/session/AgentsSignalReset.py,
## started from AgentsToolsSessionControlDeathStart): a process started with signals ignored, as a thread's child is, runs the
## helper, and the command it execs finds each of them at its default. The control is the same start WITHOUT the helper, where the
## ignored signals stay ignored. The code that starts the call names the helper and no other interpreter.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHelper="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsSignalReset.py"
rigInclude="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.InternSessionControl.include"
[ -f "$rigHelper" ] || { echo "⛔ ERROR: the helper is not at the origin this workspace resolves: $rigHelper -- refusing to report a result" >&2 ; exit 1 ; }
command -v python3 > /dev/null 2>&1 || { echo "⛔ ERROR: no python3 on PATH -- refusing to report a result" >&2 ; exit 1 ; }
rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
## What the command that is started finds: each signal sent to a child shell of it, and the names of those the child survived (they were ignored).
## A shell is the probe because python3 itself sets handlers for SIGINT and SIGPIPE at start.
rigProbe='for s in HUP INT QUIT ALRM PIPE USR1 USR2 TERM ; do sh -c '"'"'kill -s "$0" $$ ; echo "$0"'"'"' "$s" ; done 2> /dev/null | LC_ALL=C tr "\n" " "'
rigAll=""
## A subshell that ignores them all, as the thread does, starts the command (with or without the helper).
rigStart(){ ## command and arguments
	( trap '' HUP INT QUIT ALRM PIPE USR1 USR2 TERM ; exec "$@" ) 2> /dev/null
}
echo "-- the helper gives the signals back --"
rigAssert "control: started without the helper, the command finds the signals it was started with ignored" "$( rigStart bash -c "$rigProbe" )" "HUP INT QUIT ALRM PIPE USR1 USR2 TERM "
rigAssert "through the helper, the command finds none of them ignored" "[$( rigStart python3 -I -B "$rigHelper" bash -c "$rigProbe" )]" "[$rigAll]"
rigAssert "the command is exec'd in the same process: the pid before the helper is the pid of the command" "$( rigStart sh -c 'echo $$ ; exec python3 -I -B "$1" sh -c "echo \$\$"' rig "$rigHelper" | LC_ALL=C sort -u | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 1
rigAssert "no command: ends 127" "$( rigStart python3 -I -B "$rigHelper" ; echo $? )" 127
rigAssert "a command that does not exist: ends 127" "$( rigStart python3 -I -B "$rigHelper" no-such-command-rig ; echo $? )" 127
echo "-- the call is started through the helper --"
rigAssert "the death start names the helper and the include names no other interpreter" "$( LC_ALL=C grep -c 'AgentsSignalReset.py' "$rigInclude" ) $( LC_ALL=C grep -c -w 'pe[r]l' "$rigInclude" || : )" "1 0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SIGNAL RESET CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SIGNAL_RESET: OK (%d assertions, offline)\n' "$rigPasses"
