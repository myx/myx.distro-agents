#!/usr/bin/env bash
## A served AskUserQuestion: the same return bound and progress heartbeat as a served Wait
## (AgentsMcpWaitProgressCheck.test.sh), since it blocks on the answer through the same
## served wait bound. Drives a real `--intern-mcp-server --run` over stdio, offline: the call
## is a re-wait (pending_id) on a rig pending-reply record, so nothing is posted, and its
## thread is never readable, so every wait runs to its bound. Bounds and the beat interval
## are shrunk through their own knobs so the rig takes seconds.
##   - no progressToken: no frame at all, and the wait returns by MDAT_MCP_WAIT_BOUND;
##   - a progressToken: notifications/progress frames carrying it, progress strictly rising,
##     each one whole JSON-RPC line, none after the result, and the wait returns by
##     MDAT_MCP_WAIT_BOUND_PROGRESS instead;
##   - the client gone mid-wait: the next frame fails, and the call is ended.
## Red recipe, run: drop AskUserQuestion from the Wait test in the tools/call harness path
## of AgentsTools.InternMcpRequest.include.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigTool="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
[ -f "$rigTool" ] || { echo "⛔ ERROR: not found at the origin this workspace resolves: $rigTool -- refusing to report a result" >&2 ; exit 1 ; }

rigTmp="$( mktemp -d -t AgentsMcpAskProgressCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigTmp="$( cd "$rigTmp" && pwd -P )"
mkdir -p "$rigTmp/ws/.local/temp" "$rigTmp/ws/.local/agents/pending" "$rigTmp/home" "$rigTmp/skills/magic-coordinator"
printf 'rig\n' > "$rigTmp/skills/magic-coordinator/magic-coordinator.basic.md"
## An open question with a thread and an addressee, so the re-wait waits rather than refusing.
printf -- '---\nstatus: reply-pending\nkind: question\ncommunication-channel-id: slack:C0RIG\nchannel: C0RIG\nquestion-ts: 1.000001\nthread-ts: 1.000001\naddressees: U0RIGOWNER\nasking-accounts: U0RIGSELF\n---\n# rig\n' \
	> "$rigTmp/ws/.local/agents/pending/rig-ask-1.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

rigRequests(){ ## _meta JSON or empty
	local rigMeta=""
	[ -z "$1" ] || rigMeta=",\"_meta\":$1"
	printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
	printf '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"AskUserQuestion","arguments":{"pending_id":"rig-ask-1"}%s}}\n' "$rigMeta"
}
## One server life: initialize, then one AskUserQuestion re-wait (id 2).
rigServe(){ ## scenario name, _meta JSON or empty
	rigRequests "$2" | (
		unset MDAT_MCP_SERVED_MARKER MDAT_SPAWN_AGENT MDAT_HARNESS_WAIT_TIMEOUT MDAT_SPAWN_SESSION_ID
		cd "$rigTmp/ws" && HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
			MDAT_MCP_WAIT_BOUND=2 MDAT_MCP_WAIT_BOUND_PROGRESS=5 MDAT_MCP_PROGRESS_SECONDS=1 MDAT_WAIT_POLL_SECONDS=1 \
			bash "$rigTool" --intern-mcp-server --run > "$rigTmp/$1.wire" 2> "$rigTmp/$1.err"
	) || :
	LC_ALL=C grep -q '"id":2,' "$rigTmp/$1.wire" 2>/dev/null || {
		sed 's/^/    /' "$rigTmp/$1.err" >&2
		echo "⛔ ERROR: the server gave no reply to the AskUserQuestion in scenario $1 -- refusing to report a result" >&2 ; exit 1
	}
	## The rig only means something if the call really waited, rather than refusing early.
	LC_ALL=C grep '"id":2,' "$rigTmp/$1.wire" | LC_ALL=C grep -q 'waited: [0-9]*s of [0-9]*s bound' || {
		LC_ALL=C grep '"id":2,' "$rigTmp/$1.wire" | cut -c1-400 >&2
		echo "⛔ ERROR: the AskUserQuestion in scenario $1 never waited, so no bound or heartbeat was exercised -- refusing to report a result" >&2 ; exit 1
	}
}
rigFrames(){ ## scenario name -- how many progress frames
	LC_ALL=C grep -c '"method":"notifications/progress"' "$rigTmp/$1.wire" | tr -d ' '
}
rigBound(){ ## scenario name -- the bound the wait inside the call ran to
	LC_ALL=C grep '"id":2,' "$rigTmp/$1.wire" | LC_ALL=C sed -n 's/.*waited: [0-9]*s of \([0-9]*\)s bound.*/\1/p'
}
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
rigAssert "no progress frame is sent"                           "$( rigFrames none )" 0
rigAssert "its wait ran to MDAT_MCP_WAIT_BOUND (2s)"            "$( rigBound none )" 2

echo "-- a progressToken: frames, the raised bound --"
rigServe str '{"progressToken":"rig-ask-tok"}'
rigAssert "progress frames are sent while it waits"             "$( [ "$( rigFrames str )" -ge 3 ] && printf yes || printf no )" yes
rigAssert "each carries the token as sent"                      "$( LC_ALL=C grep -c '"params":{"progressToken":"rig-ask-tok","progress":' "$rigTmp/str.wire" | tr -d ' ' )" "$( rigFrames str )"
rigAssert "whole lines, rising progress, none after the result" "$( rigWireShape str )" whole
rigAssert "its wait ran to MDAT_MCP_WAIT_BOUND_PROGRESS (5s)"   "$( rigBound str )" 5

echo "-- the client goes away mid-wait: the next frame fails, and the call is ended --"
rigGoneStart="$( date +%s )"
rigRequests '{"progressToken":"rig-ask-gone"}' | (
	unset MDAT_MCP_SERVED_MARKER MDAT_SPAWN_AGENT MDAT_HARNESS_WAIT_TIMEOUT MDAT_SPAWN_SESSION_ID
	cd "$rigTmp/ws" && HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		MDAT_MCP_WAIT_BOUND_PROGRESS=30 MDAT_MCP_PROGRESS_SECONDS=1 MDAT_WAIT_POLL_SECONDS=1 \
		bash "$rigTool" --intern-mcp-server --run 2> "$rigTmp/gone.err"
) | head -n 3 > "$rigTmp/gone.wire"
rigGoneElapsed=$(( $( date +%s ) - rigGoneStart ))
rigAssert "the first frame did reach the client"                "$( LC_ALL=C grep -c '"progressToken":"rig-ask-gone"' "$rigTmp/gone.wire" | tr -d ' ' )" 1
rigAssert "the call ended well before its 30s bound"            "$( [ "$rigGoneElapsed" -lt 15 ] && printf yes || printf "no-${rigGoneElapsed}s" )" yes

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MCP ASK PROGRESS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MCP_ASK_PROGRESS: OK (%d assertions, offline)\n' "$rigPassCount"
