#!/usr/bin/env bash
## Behavioural check on three watchdogs of the tooling, each run rather than read: the Bash tool's
## (sh-lib/harness/AgentsUniversalHarness.sh, AgentsHarnessToolBash), the MCP client's (sh-lib/harness/AgentsHarnessMcpClient.sh,
## AgentsHarnessMcpRun), both where the host has no `timeout` command, and the one of the handback retry
## (sh-lib/session/AgentsTools.InternOpAgentSpawnProxy.include, AgentsToolsSpawnProxyHandbackWarn). Each starts a process,
## and beside it a watchdog that ends that process at its bound, so a command, a call or a retry that hangs does
## not hold its caller. Each watchdog knows its process by its pid, and a pid is a number the system gives again:
## at the bound it may name another process. The hook's watchdog is AgentsHarnessHookWatchdogCheck's.
## Held here for each of the three, with the rig's own process list for the one reading a process is kept by (its
## pid, its state, when it began), and for the retry the rig's own clock (its 180 seconds pass in two):
##   - what hangs is ended at its bound, and its caller is told as before: what the watchdog is for; a retry that
##     ignores the polite end is ended by the hard one five seconds later;
##   - THE NUMBER TAKEN BY ANOTHER PROCESS IS NOT SIGNALLED: where the process list says, at the bound, that the pid
##     began at another time than the process the watchdog was started for, nothing is signalled, the process that
##     has the number runs to its own end, and nothing is said of a timeout that did not happen (in the rig it is
##     the watched process itself, so that a watchdog that did signal it ends nothing of anyone's); the same for
##     the retry's hard end, where the number is taken between its two ends;
##   - what comes back before its bound is answered as before.
## Each function is the one of the file at the origin: the first two lifted out of their files, as the hooks diff
## check lifts the argument table, with stand-ins only for what they resolve a path or a server by; the third in
## its own file, sourced as AgentsSpawnConsoleRunCheck sources it.
## Red: with a watchdog as it was, `( sleep <bound> ; kill -TERM <pid> ) &`, the second point fails for each of
## the three: the process that has the number is ended, and a timeout is said.
## Offline: one mktemp tree, the watched processes lines of shell that wait, no endpoint and no console started.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-harness-text.include.sh" || exit 1
rigMcpClient="$rigHere/harness/AgentsHarnessMcpClient.sh"
rigSpawnInclude="$rigHere/session/AgentsTools.InternOpAgentSpawnProxy.include"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigHarness" "$rigMcpClient" "$rigSpawnInclude" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.Registries.include" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
rigRealSleep="$( command -v sleep )" || rigRefuse "no sleep on PATH to hand the other waits to"
rigRealPs="$( command -v ps )" || rigRefuse "no ps on PATH to hand the other calls to"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsToolingWatchdogsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/ws/.local/temp"

## One function out of a file of the tooling, whole, from its opening line to its closing brace.
rigLift(){ ## file, function name
	LC_ALL=C awk -v wantName="$2" '
		index( $0, wantName "(){" ) == 1 { inFn = 1 ; }
		inFn { print ; }
		inFn && /^\}$/ { inFn = 0 ; seen++ ; }
		END { if ( seen != 1 ) exit 1 ; }
	' "$1"
}
rigLiftBash="$( rigLift <( rigHarnessCat ) AgentsHarnessToolBash )" || rigRefuse "AgentsHarnessToolBash was not found in $rigHarness"
rigLiftNumber="$( rigLift <( rigHarnessCat ) AgentsHarnessWholeNumber )" || rigRefuse "AgentsHarnessWholeNumber was not found in $rigHarness"
rigLiftMcpRun="$( rigLift "$rigMcpClient" AgentsHarnessMcpRun )" || rigRefuse "AgentsHarnessMcpRun was not found in $rigMcpClient"

## THE RIG'S CLOCK, for the retry alone: its 180 seconds pass in RIG_WATCH_SECONDS; every other wait is the host's.
cat > "$rigTmp/bin/sleep" <<'RIGSLEEP'
#!/bin/sh
[ "${1:-}" != 180 ] || exec "$RIG_REAL_SLEEP" "$RIG_WATCH_SECONDS"
exec "$RIG_REAL_SLEEP" "$@"
RIGSLEEP
## THE RIG'S OWN PROCESS LIST, for the one reading a process is kept by. Each such reading of a scenario is counted.
## RIG_PS=taken: the first is the host's own, and every later one says that the same pid began at another time, as
## it reads once the number has been given to another process; RIG_PS=taken-late: the first two are the host's own.
## Every other call, and every reading with RIG_PS=host, is the host's ps.
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case "$*" in
	*lstart=*)
		echo reading >> "$RIG_DIR/ps.readings"
		case "${RIG_PS:-host}" in taken) rigOwn=1 ;; taken-late) rigOwn=2 ;; *) rigOwn="" ;; esac
		if [ -n "$rigOwn" ] && [ "$( grep -c . "$RIG_DIR/ps.readings" )" -gt "$rigOwn" ] ; then
			"$RIG_REAL_PS" "$@" | sed 's/[0-9][0-9][0-9][0-9] *$/2001/'
			exit 0
		fi
	;;
esac
exec "$RIG_REAL_PS" "$@"
RIGPS
## The watched process of the retry: the console of the workspace, as the retry starts it. It says it began, takes
## the polite end or not as the scenario says, stays for the seconds given, and says it came to its own end.
cat > "$rigTmp/ws/DistroAgentsConsole.sh" <<'RIGCONSOLE'
#!/usr/bin/env bash
cat > /dev/null
[ -z "${RIG_DEAF:-}" ] || trap '' TERM
: > "$RIG_DIR/watched.began"
sleep "$RIG_STAYS"
: > "$RIG_DIR/watched.ended"
RIGCONSOLE
## The watched process of the MCP client: a server that never answers. The same marks, the same stay.
cat > "$rigTmp/bin/rigserver" <<'RIGSERVER'
#!/usr/bin/env bash
: > "$RIG_DIR/watched.began"
sleep "$RIG_STAYS"
: > "$RIG_DIR/watched.ended"
RIGSERVER
chmod +x "$rigTmp/bin/sleep" "$rigTmp/bin/ps" "$rigTmp/bin/rigserver" "$rigTmp/ws/DistroAgentsConsole.sh"

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigDir=""
rigScene(){ ## scenario -- its folder, empty
	rigDir="$rigTmp/$1" ; rm -rf "$rigDir" ; mkdir -p "$rigDir"
}
rigWatched(){ ## -- what became of the watched process: it began or not, and came to its own end or not
	printf '%s %s' "$( [ -e "$rigDir/watched.began" ] && echo began || echo never-began )" "$( [ -e "$rigDir/watched.ended" ] && echo ended-by-itself || echo not-ended-by-itself )"
}
rigSaid(){ ## fixed text, file -- how many lines of the file hold it
	LC_ALL=C grep -c -F -- "$1" "$2" 2> /dev/null || :
}
rigReadings(){ ## -- how many times the process list was asked when a process began
	LC_ALL=C grep -c . "$rigDir/ps.readings" 2> /dev/null || :
}
rigCode(){ LC_ALL=C grep -v '^[[:space:]]*#' "$1" ; } ## file -- its lines that are no comment

## ---- 1. the Bash tool ----
## One call of the tool's own function, on a host with no `timeout` command: its output, and its last lines, in out.
rigBash(){ ## scenario, bound in seconds, seconds the command stays, what the rig's process list says (host or taken)
	rigScene "$1"
	(
		set +u
		cd "$rigTmp/ws" || exit 1
		PATH="$rigTmp/bin:$PATH"
		harnessScratch="$rigDir" harnessRunTimeout=0
		## no `timeout` command, whatever the host of this check has: the watchdog is what is measured
		harnessTimeoutCmd=""
		export RIG_DIR="$rigDir" RIG_PS="$4" RIG_STAYS="$3" RIG_REAL_SLEEP="$rigRealSleep" RIG_REAL_PS="$rigRealPs" RIG_WATCH_SECONDS=2
		eval "$rigLiftNumber" ; eval "$rigLiftBash"
		## the one stand-in: the working directory of the call is the rig's own, and allowed
		AgentsHarnessPathAllowed(){ harnessResolvedPath="$1" ; return 0 ; }
		AgentsHarnessToolBash "$rigTmp/ws" ': > "$RIG_DIR/watched.began" ; sleep "$RIG_STAYS" ; : > "$RIG_DIR/watched.ended" ; echo RIG-COMMAND-OUTPUT' "$2" > "$rigDir/out" 2> "$rigDir/err"
	)
}
echo "-- 1. the Bash tool: a command that hangs is ended at its bound, the number another process has taken is not --"
rigBash bash-hangs 2 6 host
rigAssert "a command that does not come back is ended at its bound, and the result says that it timed out and with which status" \
	"$( rigWatched ) $( rigSaid '... TIMED OUT after 2 seconds ...' "$rigDir/out" ) $( rigSaid '(exit status 143)' "$rigDir/out" )" "began not-ended-by-itself 1 1"
rigBash bash-taken 2 6 taken
rigAssert "control: the watchdog asked the process list when that pid began, as it started and at its bound" "$( rigReadings )" 2
rigAssert "at the bound the pid began at another time than the command did: nothing is signalled, the process that has the number runs to its own end, and no timeout is said" \
	"$( rigWatched ) $( rigSaid 'TIMED OUT' "$rigDir/out" ) $( rigSaid 'RIG-COMMAND-OUTPUT' "$rigDir/out" ) $( rigSaid '(exit status 0)' "$rigDir/out" ) $( [ -e "$rigDir/run.timedout" ] && echo flagged || echo not-flagged )" "began ended-by-itself 0 1 1 not-flagged"
rigBash bash-quick 5 0 host
rigAssert "a command that comes back before its bound is answered as before, and the records of its processes are gone" \
	"$( rigWatched ) $( rigSaid 'RIG-COMMAND-OUTPUT' "$rigDir/out" ) $( rigSaid '(exit status 0)' "$rigDir/out" ) $( rigSaid 'TIMED OUT' "$rigDir/out" ) $( ls "$rigDir" | LC_ALL=C grep -c '\.pid$' )" "began ended-by-itself 1 1 0 0"

## ---- 2. the MCP client ----
## One exchange with a server that never answers, by the client's own function, on a host with no `timeout` command:
## its return code and the fault it names in result.
rigMcp(){ ## scenario, bound in seconds, seconds the server stays, what the rig's process list says (host or taken)
	rigScene "$1"
	(
		set +u
		cd "$rigTmp/ws" || exit 1
		PATH="$rigTmp/bin:$PATH"
		harnessHere="$rigHere" harnessScratch="$rigDir" harnessSelfName=rig harnessMcpConfigFault="" harnessMcpFrom="the rig"
		harnessDim='' harnessTool='' harnessValue='' harnessWarn='' harnessBad='' harnessOff=''
		harnessTimeoutCmd=""
		export RIG_DIR="$rigDir" RIG_PS="$4" RIG_STAYS="$3" RIG_REAL_SLEEP="$rigRealSleep" RIG_REAL_PS="$rigRealPs" RIG_WATCH_SECONDS=2
		eval "$rigLiftMcpRun"
		## the stand-ins: the name is a server's, its registration is the rig's one server, and no answer ever comes
		AgentsHarnessMcpNameOk(){ return 0 ; }
		AgentsHarnessMcpResolve(){ harnessMcpResCmd="$rigTmp/bin/rigserver" ; harnessMcpResCmdRc=0 ; harnessMcpResArgs=() ; harnessMcpResArgsRc=3 ; harnessMcpResEnvKeys=() ; harnessMcpResEnvVals=() ; harnessMcpResEnvRc=3 ; }
		AgentsHarnessMcpReply(){ return 1 ; }
		printf '%s\n' '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"rig","arguments":{}}}' > "$rigDir/mcp.req"
		mcpRc=0 ; AgentsHarnessMcpRun rigmcp "$2" 3 > "$rigDir/out" 2> "$rigDir/err" || mcpRc=$?
		printf '%s [%s]\n' "$mcpRc" "$harnessMcpFault" > "$rigDir/result"
	)
}
echo "-- 2. the MCP client: a server that hangs is ended at its bound, the number another process has taken is not --"
rigMcp mcp-hangs 2 6 host
rigAssert "a server that does not answer is ended at its bound, and the exchange fails, saying that it did not answer and was killed" \
	"$( rigWatched ) $( cat "$rigDir/result" 2> /dev/null )" "began not-ended-by-itself 1 [it did not answer within 2 seconds and was killed]"
rigMcp mcp-taken 2 6 taken
rigAssert "control: the watchdog asked the process list when that pid began, as it started and at its bound" "$( rigReadings )" 2
rigAssert "at the bound the pid began at another time than the server did: nothing is signalled, the process that has the number runs to its own end, and nothing is said of a kill" \
	"$( rigWatched ) $( cat "$rigDir/result" 2> /dev/null ) $( [ -e "$rigDir/mcp.timedout" ] && echo flagged || echo not-flagged )" "began ended-by-itself 0 [] not-flagged"
rigMcp mcp-quick 5 0 host
rigAssert "a server that ends before its bound is no timeout" "$( rigWatched ) $( cat "$rigDir/result" 2> /dev/null )" "began ended-by-itself 0 []"

## ---- 3. the handback retry of the spawn proxy ----
## One call of the retry's own function, in its own file, for a run whose output holds no handback: the console of
## the rig is the retry, and what the function then tells the session is kept in notices.
rigRetry(){ ## scenario, seconds the retry stays, what the rig's process list says (host, taken or taken-late), deaf to the polite end or empty
	rigScene "$1"
	: > "$rigDir/run.log"
	(
		set +u
		export MMDAPP="$rigTmp/ws" MDSC_CMD=rig MDAT_SPAWN_SESSION_ID=rig-spawn MDAT_SPAWN_SANDBOX_ROOT=""
		export RIG_DIR="$rigDir" RIG_PS="$3" RIG_STAYS="$2" RIG_DEAF="${4:-}" RIG_REAL_SLEEP="$rigRealSleep" RIG_REAL_PS="$rigRealPs" RIG_WATCH_SECONDS=2
		PATH="$rigTmp/bin:$PATH"
		set -- --rig-none
		. "$rigSpawnInclude" 2> "$rigDir/source.err"
		## the stand-ins: the session is open, its record and its posts are not this check's
		AgentsToolsSpawnProxyRetryClosed(){ : ; }
		AgentsToolsWorkspaceSkillsetRoot(){ printf '%s/.local/agents/members' "$1" ; }
		AgentsToolsSpawnProxyRunRecord(){ : ; }
		AgentsToolsSpawnProxySessionNotice(){ printf '%s\n' "$4" >> "$RIG_DIR/notices" ; }
		DistroAgentsTools(){ : ; }
		AgentsToolsSpawnProxyHandbackWarn "CRIG:1.1" rig-member "$rigDir/run.log" rig-session "" "" --cli rig-cli > "$rigDir/out" 2> "$rigDir/err"
	)
}
echo "-- 3. the handback retry: a retry that hangs is ended at its bound, the number another process has taken is not --"
rigRetry retry-hangs 6 host
rigAssert "a retry that does not come back is ended at its bound, and the session is told that no handback came" \
	"$( rigWatched ) $( rigSaid handback-missing "$rigDir/notices" )" "began not-ended-by-itself 1"
rigRetry retry-deaf 12 host deaf
rigAssert "a retry that ignores the polite end is ended by the hard one five seconds later" "$( rigWatched ) $( rigSaid handback-missing "$rigDir/notices" )" "began not-ended-by-itself 1"
rigRetry retry-taken 6 taken
rigAssert "control: the watchdog asked the process list when that pid began, as it started and at its bound" "$( rigReadings )" 2
rigAssert "at the bound the pid began at another time than the retry did: neither end is sent, and the process that has the number runs to its own end" \
	"$( rigWatched )" "began ended-by-itself"
rigRetry retry-taken-late 10 taken-late deaf
rigAssert "control: before the hard end the watchdog asked once more" "$( rigReadings )" 3
rigAssert "the number taken between the two ends: the hard one is not sent, and the process that has the number runs to its own end" \
	"$( rigWatched )" "began ended-by-itself"

echo "-- each watchdog keeps its process by the one reading the tooling keeps a process by --"
## The harness holds two such watchdogs, each reading twice: the Bash tool's and the one behind WorkspaceContextExecute.
rigAssert "none of the three files signals a pid after a wait by the number alone, and each reads when its process began through AgentsToolsRegistryProcessesBegan" \
	"$( rigCode <( rigHarnessCat ) | LC_ALL=C grep -c -e 'sleep "\$toolTimeout" ; kill' ) $( rigCode "$rigMcpClient" | LC_ALL=C grep -c -e 'sleep "\$runBound" ; kill' ) $( rigCode "$rigSpawnInclude" | LC_ALL=C grep -c -e 'sleep 180 ; kill' ) $( rigCode <( rigHarnessCat ) | LC_ALL=C grep -c -F '"$harnessRunPid" | AgentsToolsRegistryProcessesBegan' ) $( rigCode "$rigMcpClient" | LC_ALL=C grep -c -F '"$runPid" | AgentsToolsRegistryProcessesBegan' ) $( rigCode "$rigSpawnInclude" | LC_ALL=C grep -c -F '"$warnRetryPid" | AgentsToolsRegistryProcessesBegan' )" "0 0 0 4 2 3"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ TOOLING WATCHDOGS CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'TOOLING_WATCHDOGS: OK (%d assertions, offline)\n' "$rigPasses"
