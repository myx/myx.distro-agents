#!/usr/bin/env bash
## Behavioural check that the manager screen (sh-lib/manager/AgentsManagerScreen.py) ENDS WHEN ITS TERMINAL IS GONE, and that the driver of
## the screen's tests leaves no process behind when it ends a run, run rather than read. Held: a screen on a terminal that stays is
## alive and drawn (the control); the same screen, once the master of its pseudo-terminal is closed, as when the program that held
## it ended, is gone within two seconds, by an exit status of its own, 129 as a hangup is; and a run that the driver ends at its
## timeout is ended whole, the process it started and everything that process started, never the first alone.
## Before this, a screen whose terminal went away read nothing, at once, for ever, and used a whole processor until killed.
## Offline: the only thing the real screen calls here is the stand-in for the dispatcher (check-fixtures/manager-screen.tools.stub.sh).
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigScreen="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsManagerScreen.py"
rigFixtures="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures"
rigDriver="$rigFixtures/manager-screen.driver.py"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigScreen" ] || rigRefuse "the screen is not at the origin: $rigScreen"
[ -f "$rigDriver" ] || rigRefuse "the driver of the screen tests is missing: $rigDriver"
rigPython="$( command -v python3 )" || rigRefuse "no python3 on PATH"
"$rigPython" -I -c 'import curses' 2> /dev/null || rigRefuse "the python3 on PATH has no curses module, so the real screen cannot be started here: $rigPython"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerScreenTerminalLossCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/rig" "$rigTmp/ws-rig"
printf '#!/bin/sh\nexec bash "%s" "$@"\n' "$rigFixtures/manager-screen.tools.stub.sh" > "$rigTmp/tools"
chmod +x "$rigTmp/tools"
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigPtyOut=""
rigPty(){ ## seconds to the timeout, then the command -- what the driver says of the run is kept in rigPtyOut
	local ptySeconds="$1" ; shift
	rigPtyOut="$( "$rigPython" -I -B "$rigDriver" "$rigScreen" pty 100 30 "Magic-Team (Agents)" - "$ptySeconds" -- "$@" 2>&1 )"
}
rigPtyVal(){ ## name
	printf '%s\n' "$rigPtyOut" | LC_ALL=C sed -n "s/^pty\.$1=//p" | head -1
}
rigRealScreen=( env -i HOME="$rigTmp" PATH=/usr/bin:/bin TERM=xterm MANAGER_SCREEN_RIG="$rigTmp/rig" "$rigPython" -I -B "$rigScreen" --workspace "$rigTmp/ws-rig" --tools "$rigTmp/tools" )

echo "-- the screen on a terminal that stays: drawn, and alive --"
rigPty 4 "${rigRealScreen[@]}"
rigAssert "the screen comes up and is still there when the driver ends the run at its timeout: it ends for no quiet of the terminal" "$( rigPtyVal frame ) $( rigPtyVal rc )" "yes timeout"

echo "-- the terminal goes away: the master of its pseudo-terminal is closed --"
MANAGER_SCREEN_PTY_HANGUP=3 rigPty 20 "${rigRealScreen[@]}"
rigAssert "the screen was drawn, and once its terminal is gone it is gone itself" "$( rigPtyVal frame ) $( rigPtyVal hangup )" "yes ended"
rigAssert "within two seconds, by the exit status of a hangup, 129" "$( rigPtyVal hangupWithin2 ) $( rigPtyVal rc )" "yes 129"

echo "-- the driver ends a run whole at its timeout --"
## the process the run starts is one that ends by itself in twenty seconds, so a driver that leaves it leaves it for that long and no signal of this check is needed
rigPty 2 bash -c 'sleep 20 & echo $! > "$0" ; wait' "$rigTmp/child.pid"
sleep 0.5
rigPid="$( cat "$rigTmp/child.pid" 2> /dev/null )"
rigAssert "the run is ended at its timeout, and the process that process started with it" "$( rigPtyVal rc ) $( [ -n "$rigPid" ] && kill -0 "$rigPid" 2> /dev/null && echo alive || echo gone )" "timeout gone"

if [ "$rigFailCount" -gt 0 ] ; then
	printf '⛔ MANAGER SCREEN TERMINAL LOSS CHECK FAILED: %d of %d assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))"
	exit 1
fi
printf 'MANAGER_SCREEN_TERMINAL_LOSS: OK (%d assertions, offline, the real screen on pseudo-terminals)\n' "$rigPassCount"
