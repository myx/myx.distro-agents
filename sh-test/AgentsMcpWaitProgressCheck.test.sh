#!/usr/bin/env bash
## A served Wait: the return bound and the progress heartbeat of the myx.distro MCP server.
## Drives a real `--intern-mcp-server --run` over stdio, offline: the only source is a
## file path that never appears, so every wait runs to its bound. Bounds and the beat
## interval are shrunk through their own knobs (MDAT_MCP_WAIT_BOUND,
## MDAT_MCP_WAIT_BOUND_PROGRESS, MDAT_MCP_PROGRESS_SECONDS) so the rig takes seconds.
##   - no progressToken: no frame at all, and the Wait returns by MDAT_MCP_WAIT_BOUND;
##   - a string or a numeric token: notifications/progress frames carrying that token,
##     progress strictly increasing, each one whole JSON-RPC line, none after the result,
##     and the Wait returns by MDAT_MCP_WAIT_BOUND_PROGRESS instead;
##   - the TIMEOUT result is three lines: `WAIT-RESULT: TIMEOUT (<s>s)`, the reply layer's `current-date:`
##     line, and `NEXT: Wait mode=continue` (F2.3 of the refactorings epic splits the one line there).
## Which bound a Wait returned by is read off the whole seconds that line names. A wait runs its
## bound, then the rest of the clock second it began in and the work of its last round, so the
## seconds it reports are the bound or a little more, the more the busier the host: read as
## equal to the bound they failed under load (a 2s bound came back as 3s, a 5s one as 6s). The
## two bounds here are 3s apart, so a reading from one bound up to the other is that bound's.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigTool="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
[ -f "$rigTool" ] || { echo "⛔ ERROR: not found at the origin this workspace resolves: $rigTool -- refusing to report a result" >&2 ; exit 1 ; }

. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsMcpWaitProgressCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigTmp="$( cd "$rigTmp" && pwd -P )"
mkdir -p "$rigTmp/ws/.local/temp" "$rigTmp/home" "$rigTmp/skills/magic-coordinator"
printf 'rig\n' > "$rigTmp/skills/magic-coordinator/magic-coordinator.basic.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## The two bounds of this rig, in seconds: with no progress token, and with one.
rigBoundSafe=2
rigBoundRaised=5

## One server life: initialize, then one Wait (id 2) whose _meta is the second argument.
rigServe(){ ## scenario name, _meta JSON or empty
	local rigMeta=""
	[ -z "$2" ] || rigMeta=",\"_meta\":$2"
	{
		printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
		printf '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"Wait","arguments":{"sources":"file:%s"}%s}}\n' "$rigTmp/never-there" "$rigMeta"
	} | (
		unset MDAT_MCP_SERVED_MARKER MDAT_SPAWN_AGENT MDAT_HARNESS_WAIT_TIMEOUT MDAT_SPAWN_SESSION_ID
		cd "$rigTmp/ws" && HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
			MDAT_MCP_WAIT_BOUND="$rigBoundSafe" MDAT_MCP_WAIT_BOUND_PROGRESS="$rigBoundRaised" MDAT_MCP_PROGRESS_SECONDS=1 MDAT_WAIT_POLL_SECONDS=1 \
			bash "$rigTool" --intern-mcp-server --run > "$rigTmp/$1.wire" 2> "$rigTmp/$1.err"
	) || :
	LC_ALL=C grep -q '"id":2,' "$rigTmp/$1.wire" 2>/dev/null || {
		sed 's/^/    /' "$rigTmp/$1.err" >&2
		echo "⛔ ERROR: the server gave no reply to the Wait in scenario $1 -- refusing to report a result" >&2 ; exit 1
	}
}
rigFrames(){ ## scenario name -- how many progress frames
	LC_ALL=C grep -c '"method":"notifications/progress"' "$rigTmp/$1.wire" | tr -d ' '
}
rigTimeoutLine(){ ## scenario name -- the result text, its three lines joined by ` | `, its seconds and its date masked
	LC_ALL=C grep '"id":2,' "$rigTmp/$1.wire" | LC_ALL=C sed -n 's/.*"text":"\(WAIT-RESULT: TIMEOUT ([0-9]*s)\)\\ncurrent-date: [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9] [+-][0-9][0-9][0-9][0-9]\\n\(NEXT: Wait mode=continue\)\(\\n\)*".*/\1 | current-date | \2/p' | LC_ALL=C sed 's/([0-9]*s)/(Ns)/'
}
rigWaited(){ ## scenario name -- the seconds the TIMEOUT line names
	LC_ALL=C grep '"id":2,' "$rigTmp/$1.wire" | LC_ALL=C sed -n 's/.*WAIT-RESULT: TIMEOUT (\([0-9]*\)s).*/\1/p'
}
## The bound a Wait returned by: `safe` for a reading from MDAT_MCP_WAIT_BOUND up to the raised
## bound, `raised` for one from MDAT_MCP_WAIT_BOUND_PROGRESS up to as far above it again, and the
## reading itself where it is neither, so a wait that kept no bound, or the other one, is told.
rigBoundOf(){ ## scenario name
	local boundWaited
	boundWaited="$( rigWaited "$1" )"
	case "$boundWaited" in ''|*[!0123456789]*) printf 'unread:%s' "$boundWaited" ; return 0 ;; esac
	if [ "$boundWaited" -ge "$rigBoundSafe" ] && [ "$boundWaited" -lt "$rigBoundRaised" ] ; then
		printf 'safe'
	elif [ "$boundWaited" -ge "$rigBoundRaised" ] && [ "$boundWaited" -lt $(( rigBoundRaised + rigBoundRaised - rigBoundSafe )) ] ; then
		printf 'raised'
	else
		printf '%ss' "$boundWaited"
	fi
}
## Every frame on the wire is one whole JSON-RPC line, the progress values strictly rise,
## and nothing follows the result.
rigWireShape(){ ## scenario name
	LC_ALL=C awk '
		!/^\{"jsonrpc":"2\.0",.*\}$/ { bad = 1 }
		/"id":2,/ { done = 1 ; next }
		/notifications\/progress/ {
			if ( done ) { bad = 1 }
			v = $0 ; sub(/.*"progress":/, "", v) ; sub(/[^0-9].*/, "", v)
			if ( v + 0 <= last ) { bad = 1 } ; last = v + 0
		}
		END { print ( bad ? "broken" : "whole" ) }' "$rigTmp/$1.wire"
}

echo "-- no progressToken: no frame, the safe bound --"
rigServe none ""
rigAssert "no progress frame is sent"                         "$( rigFrames none )" 0
rigAssert "the TIMEOUT result: its outcome, the date, the call" "$( rigTimeoutLine none )" "WAIT-RESULT: TIMEOUT (Ns) | current-date | NEXT: Wait mode=continue"
rigAssert "it returned by MDAT_MCP_WAIT_BOUND (2s)"           "$( rigBoundOf none )" safe
rigAssert "and says nothing of a successful wait in prose"    "$( LC_ALL=C grep -c 'COMPLETE, SUCCESSFUL' "$rigTmp/none.wire" | tr -d ' ' )" 0

echo "-- a string progressToken: frames, the raised bound --"
rigServe str '{"progressToken":"rig-tok"}'
rigAssert "progress frames are sent while it waits"           "$( [ "$( rigFrames str )" -ge 3 ] && printf yes || printf no )" yes
rigAssert "each carries the token as sent"                    "$( LC_ALL=C grep -c '"params":{"progressToken":"rig-tok","progress":' "$rigTmp/str.wire" | tr -d ' ' )" "$( rigFrames str )"
rigAssert "whole lines, rising progress, none after the result" "$( rigWireShape str )" whole
rigAssert "it returned by MDAT_MCP_WAIT_BOUND_PROGRESS (5s)"  "$( rigBoundOf str )" raised

echo "-- a numeric progressToken --"
rigServe num '{"progressToken":7}'
rigAssert "frames carry the number unquoted"                  "$( [ "$( LC_ALL=C grep -c '"progressToken":7,"progress":' "$rigTmp/num.wire" | tr -d ' ' )" -ge 1 ] && printf yes || printf no )" yes
rigAssert "whole lines, rising progress, none after the result" "$( rigWireShape num )" whole

echo "-- a token that is not a JSON string or integer: treated as none --"
rigServe obj '{"progressToken":{"x":1}}'
rigAssert "no progress frame is sent"                         "$( rigFrames obj )" 0
rigAssert "and the safe bound holds"                          "$( rigBoundOf obj )" safe

echo "-- the client goes away mid-wait: the next frame fails, and the call is ended --"
## The wire is closed after three lines (initialize, list_changed, the first frame). With a
## progress bound of 30s, a call that outlived its client would hold the server that long.
rigGoneStart="$( date +%s )"
{
	printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
	printf '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"Wait","arguments":{"sources":"file:%s"},"_meta":{"progressToken":"rig-gone"}}}\n' "$rigTmp/never-there"
} | (
	unset MDAT_MCP_SERVED_MARKER MDAT_SPAWN_AGENT MDAT_HARNESS_WAIT_TIMEOUT MDAT_SPAWN_SESSION_ID
	cd "$rigTmp/ws" && HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		MDAT_MCP_WAIT_BOUND_PROGRESS=30 MDAT_MCP_PROGRESS_SECONDS=1 MDAT_WAIT_POLL_SECONDS=1 \
		bash "$rigTool" --intern-mcp-server --run 2> "$rigTmp/gone.err"
) | head -n 3 > "$rigTmp/gone.wire"
rigGoneElapsed=$(( $( date +%s ) - rigGoneStart ))
rigAssert "the first frame did reach the client"              "$( LC_ALL=C grep -c '"progressToken":"rig-gone"' "$rigTmp/gone.wire" | tr -d ' ' )" 1
rigAssert "the call ended well before its 30s bound"          "$( [ "$rigGoneElapsed" -lt 15 ] && printf yes || printf "no-${rigGoneElapsed}s" )" yes

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MCP WAIT PROGRESS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MCP_WAIT_PROGRESS: OK (%d assertions, offline)\n' "$rigPassCount"
