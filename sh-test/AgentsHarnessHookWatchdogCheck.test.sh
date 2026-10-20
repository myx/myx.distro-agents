#!/usr/bin/env bash
## Behavioural check on the watchdog of a PreToolUse hook (sh-lib/harness/AgentsHarnessHooks.sh, AgentsHarnessHooksRefusal),
## run rather than read. Where the host has no `timeout` command the harness starts the hook, and beside it a
## watchdog that ends the hook after sixty seconds, so a hook that does not come back refuses its call instead of
## holding the harness. The watchdog knows the hook by its pid, and a pid is a number the system gives again: sixty
## seconds on it may name another process. Held here, on the hooks file as it stands at the origin, with the rig's
## own clock (the sixty seconds pass in two) and the rig's own process list for the one reading a process is kept
## by (its pid, its state, when it began):
##   - a hook that does not come back is ended at the watchdog's time, and its call is refused, saying so: what the
##     watchdog is for;
##   - THE NUMBER TAKEN BY ANOTHER PROCESS IS NOT SIGNALLED: where the process list says, at the watchdog's time,
##     that the pid began at another time than the hook did, nothing is signalled, and that process runs to its own
##     end (in the rig it is the hook's own process, so that a watchdog that did signal it ends nothing of anyone's);
##   - where the list cannot say when the pid began, nothing is signalled by the number alone;
##   - a hook that comes back at once is answered as before, and no reading holds its call.
## Red: with the watchdog as it was, `( sleep 60 ; kill -TERM "$hookRunPid" )`, the second and the third fail: the
## process that has the number is ended, and nothing was read of when it began.
## Offline: one mktemp tree, the hook a line of shell that waits, no endpoint and no tool of the tooling called.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigHarness" "$rigHere/harness/AgentsHarnessHooks.sh" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.Registries.include" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
rigRealSleep="$( command -v sleep )" || rigRefuse "no sleep on PATH to hand the other waits to"
rigRealPs="$( command -v ps )" || rigRefuse "no ps on PATH to hand the other calls to"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessHookWatchdogCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/ws"

## The argument-table functions the refusal reads through, lifted out of the harness.
rigLift="$( LC_ALL=C awk '
	/^(AgentsHarnessWholeNumber|AgentsHarnessArgParse|AgentsHarnessArgFind|AgentsHarnessArgValue)\(\)\{/ { inFn = 1 ; }
	inFn { print ; }
	inFn && /^\}$/ { inFn = 0 ; seen++ ; }
	END { if ( seen != 4 ) exit 1 ; }
' "$rigHarness" )" || rigRefuse "the argument-table functions were not all found in $rigHarness"

## THE RIG'S CLOCK. The sixty seconds of the watchdog pass in RIG_WATCH_SECONDS; every other wait is the host's own.
cat > "$rigTmp/bin/sleep" <<'RIGSLEEP'
#!/bin/sh
[ "${1:-}" != 60 ] || exec "$RIG_REAL_SLEEP" "$RIG_WATCH_SECONDS"
exec "$RIG_REAL_SLEEP" "$@"
RIGSLEEP
## THE RIG'S OWN PROCESS LIST, for the one reading a process is kept by. Each such reading of a scenario is counted.
## RIG_PS=taken: the first is the host's own, and every later one says that the same pid began at another time, as
## it reads once the number has been given to another process. RIG_PS=none: such a reading finds no process at
## all. Every other call, and every reading with RIG_PS=host, is the host's ps.
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case "$*" in
	*lstart=*)
		echo reading >> "$RIG_HOOK_DIR/ps.readings"
		case "${RIG_PS:-host}" in
			none) exit 1 ;;
			taken)
				if [ "$( grep -c . "$RIG_HOOK_DIR/ps.readings" )" -gt 1 ] ; then
					"$RIG_REAL_PS" "$@" | sed 's/[0-9][0-9][0-9][0-9] *$/2001/'
					exit 0
				fi
			;;
		esac
	;;
esac
exec "$RIG_REAL_PS" "$@"
RIGPS
chmod +x "$rigTmp/bin/sleep" "$rigTmp/bin/ps"

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

## One call of the refusal, as the harness makes it before a tool runs, on a host with no `timeout` command. The one
## hook is a line of shell that the harness's own `bash -c` runs: it says it began, stays for the seconds given, and
## says it came to its own end. What the call printed is in <scenario>/refusal.
rigDir=""
rigCall(){ ## scenario, seconds the hook stays, what the rig's process list says (host, taken or none)
	rigDir="$rigTmp/$1"
	mkdir -p "$rigDir"
	(
		cd "$rigTmp/ws" || exit 1
		PATH="$rigTmp/bin:$PATH"
		MMDAPP="$rigTmp/ws" harnessHere="$rigHere" harnessScratch="$rigDir" harnessSelfName=rig harnessSessionId=rig-session
		harnessDim='' harnessTool='' harnessValue='' harnessWarn='' harnessBad='' harnessOff=''
		## no `timeout` command, whatever the host of this check has: the watchdog is what is measured
		harnessTimeoutCmd=""
		harnessArgRaw="" harnessArgParsed=0 harnessArgPaths=() harnessArgEncs=() harnessArgFound=""
		export RIG_HOOK_DIR="$rigDir" RIG_HOOK_STAYS="$2" RIG_PS="$3" RIG_WATCH_SECONDS=2 RIG_REAL_SLEEP="$rigRealSleep" RIG_REAL_PS="$rigRealPs"
		eval "$rigLift"
		. "$rigHere/harness/AgentsHarnessHooks.sh" 2> "$rigDir/source.err"
		## The harness's hooks are its own policy's; the rig's one hook is handed to the refusal as a line of that list.
		harnessHooksList="	"': > "$RIG_HOOK_DIR/hook.began" ; sleep "$RIG_HOOK_STAYS" ; : > "$RIG_HOOK_DIR/hook.ended"'$'\n'
		AgentsHarnessArgParse '{"file_path":"/rig/file"}'
		printf '%s' "$( AgentsHarnessHooksRefusal Read '{"file_path":"/rig/file"}' )" > "$rigDir/refusal"
	)
}
rigHook(){ ## -- what became of the hook's process: it began or not, and came to its own end or not
	printf '%s %s' "$( [ -e "$rigDir/hook.began" ] && echo began || echo never-began )" "$( [ -e "$rigDir/hook.ended" ] && echo ended-by-itself || echo not-ended-by-itself )"
}
rigSaid(){ ## fixed text -- how many times the refusal of the call holds it
	LC_ALL=C grep -c -F -- "$1" "$rigDir/refusal" 2> /dev/null || :
}
rigReadings(){ ## -- how many times the process list was asked when a process began
	LC_ALL=C grep -c . "$rigDir/ps.readings" 2> /dev/null || :
}

echo "-- a hook that does not come back is ended at the watchdog's time, and its call is refused --"
rigCall hangs 6 host
rigAssert "the hook is ended before its own end, and the call is refused, saying that it did not complete and with which status" \
	"$( rigHook ) $( rigSaid 'did not complete (exit status 143)' ) $( rigSaid 'ERROR: blocked before running -- the PreToolUse hook' )" "began not-ended-by-itself 1 1"

echo "-- the number another process has taken is not signalled --"
rigCall taken 6 taken
rigAssert "control: the watchdog asked the process list when that pid began, as it started and at its time" "$( rigReadings )" 2
rigAssert "at the watchdog's time the pid began at another time than the hook did: nothing is signalled, and the process that has the number runs to its own end" \
	"$( rigHook ) $( rigSaid 'did not complete' )" "began ended-by-itself 0"
rigAssert "and nothing is said of it: the call the harness waited for is answered as a hook that came back answers it" "[$( cat "$rigDir/refusal" 2> /dev/null )]" "[]"

echo "-- where the process list cannot say when the pid began, nothing is signalled by the number alone --"
rigCall unread 6 none
rigAssert "no start could be read: nothing is signalled, and the process runs to its own end" "$( rigHook ) $( rigSaid 'did not complete' ) [$( cat "$rigDir/refusal" 2> /dev/null )]" "began ended-by-itself 0 []"

echo "-- a hook that comes back at once is answered as before --"
rigCall quick 0 host
rigAssert "it ran to its end and its silence lets the call go on" "$( rigHook ) [$( cat "$rigDir/refusal" 2> /dev/null )]" "began ended-by-itself []"

echo "-- the watchdog keeps a process by the one reading the tooling keeps a process by --"
rigCode(){ LC_ALL=C grep -v '^[[:space:]]*#' "$1" ; } ## file -- its lines that are no comment
rigAssert "the hooks file signals the hook's pid in one place, and reads when it began through AgentsToolsRegistryProcessesBegan, as it starts and before it signals" \
	"$( rigCode "$rigHere/harness/AgentsHarnessHooks.sh" | LC_ALL=C grep -c -F 'kill -TERM "$hookRunPid"' ) $( rigCode "$rigHere/harness/AgentsHarnessHooks.sh" | LC_ALL=C grep -c -F '"$hookRunPid" | AgentsToolsRegistryProcessesBegan' ) $( rigCode "$rigHere/harness/AgentsHarnessHooks.sh" | LC_ALL=C grep -c -F 'sleep 60 ; kill' )" "1 2 0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ HARNESS HOOK WATCHDOG CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_HOOK_WATCHDOG: OK (%d assertions, offline)\n' "$rigPasses"
