#!/usr/bin/env bash
## Behavioural check on WHO a call served by the myx.distro MCP server acts as. SendMessage,
## Wait, Agent and AskUserQuestion refuse without a team identity, and the server is the
## only thing that can hand the harness one: a spawned session's MDAT_SPAWN_AGENT, else the
## root session's magic-coordinator. Without it every ask from a native client failed, while
## the deny hook sent that client to exactly this server to ask.
##
## Read off the real server: its witness line names the identity, and a SendMessage with an
## empty message shows whether the call got past the identity gate, which comes first. The
## empty message is refused before any send, so nothing is posted and no credential is read.
## The control is a spawned member missing from the skillset: identity dropped, SendMessage
## refused for it, and Read still served, so a bad identity never takes the other tools down.
##
## Offline, and self-contained in its scratch: MMDAPP, HOME and the skillset are fixtures.
## Red recipe, run: drop `${mcpAgent:+--agent "$mcpAgent"}` from the tools/call arm of
## sh-lib/AgentsTools.InternMcpServer.include, or point MDLT_ORIGIN at a tree without it.
## The options body is red when its case patterns in AgentsHarnessToolAskUserQuestion lose
## their leading parenthesis, which bash 3.2 needs inside a command substitution.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"

rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

[ -f "$rigTool" ] || rigRefuse "not found at the origin this workspace resolves: $rigTool"
[ -f "$rigHere/AgentsUniversalHarness.sh" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHere/AgentsUniversalHarness.sh"

rigTmp="$( mktemp -d -t "AgentsHarnessServedIdentityCheck-XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

mkdir -p "$rigTmp/ws/.local" "$rigTmp/ws/source" "$rigTmp/home" \
	"$rigTmp/skills/magic-coordinator" "$rigTmp/skills/keeper-myx"
printf 'rig-coordinator\n' > "$rigTmp/skills/magic-coordinator/magic-coordinator.basic.md"
printf 'rig-keeper\n' > "$rigTmp/skills/keeper-myx/keeper-myx.basic.md"
printf 'rig-readable\n' > "$rigTmp/ws/source/probe.txt"

## One server life per scenario. The spawn variable is the only thing that differs, and
## the recursion marker is cleared because this rig IS the directly registered server.
rigServe(){ ## scenario name, MDAT_SPAWN_AGENT value or empty for unset
	{
		printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
		printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"SendMessage","arguments":{"to":"human-owner","message":""}}}'
		printf '%s\n' "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"Read\",\"arguments\":{\"path\":\"$rigTmp/ws/source/probe.txt\"}}}"
		printf '%s\n' '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"AskUserQuestion","arguments":{"to":"human-owner","question":"rig","options":"one\n- two","wait":false}}}'
	} | (
		unset MDAT_MCP_SERVED_MARKER MDAT_SPAWN_AGENT
		[ -z "$2" ] || export MDAT_SPAWN_AGENT="$2"
		HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
			bash "$rigTool" --intern-mcp-server --run > "$rigTmp/$1.wire" 2> "$rigTmp/$1.err"
	) || :
	LC_ALL=C grep -q '"id":1,' "$rigTmp/$1.wire" 2>/dev/null || {
		sed 's/^/    /' "$rigTmp/$1.err" >&2
		rigRefuse "the server did not answer initialize in scenario $1, so nothing was served"
	}
}

rigWitness(){ ## scenario name -- the identity the server says it serves under
	LC_ALL=C sed -n 's/^# myx.distro agentMcp: .* agent=\([^ ]*\) .*/\1/p' "$rigTmp/$1.err" | head -1
}

rigSend(){ ## scenario name -- how the served SendMessage came back
	case "$( LC_ALL=C grep '"id":2,' "$rigTmp/$1.wire" 2>/dev/null )" in
		'')                                     printf 'no-answer' ;;
		*'no team identity'*)                   printf 'refused-no-identity' ;;
		*'both to and message are required'*)   printf 'past-identity' ;;
		*)                                      printf 'other' ;;
	esac
}

rigRead(){ ## scenario name -- whether the served Read still worked
	case "$( LC_ALL=C grep '"id":3,' "$rigTmp/$1.wire" 2>/dev/null )" in
		'')               printf 'no-answer' ;;
		*rig-readable*)   printf 'read' ;;
		*)                printf 'other' ;;
	esac
}

## The body AskUserQuestion builds for a question with options. The rig holds no Slack
## config, so the send is refused offline; what is read is whether the body built at all.
rigAskBody(){ ## scenario name
	LC_ALL=C grep -q '"id":4,' "$rigTmp/$1.wire" 2>/dev/null || { printf 'no-answer' ; return 0 ; }
	if LC_ALL=C grep -q 'command substitution' "$rigTmp/$1.err" ; then printf 'body-broken' ; else printf 'body-built' ; fi
}

rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1"
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
		rigFails=$(( rigFails + 1 ))
	fi
}

rigServe root ""
rigServe spawned keeper-myx
rigServe absent rig-absent-member

echo "-- the root session: no MDAT_SPAWN_AGENT --"
rigAssert "the server serves as magic-coordinator" "$( rigWitness root )" "magic-coordinator"
rigAssert "a served SendMessage gets past the identity gate" "$( rigSend root )" "past-identity"
rigAssert "a served AskUserQuestion with options builds its body" "$( rigAskBody root )" "body-built"

echo "-- a spawned session: MDAT_SPAWN_AGENT names its member --"
rigAssert "the server serves as that member" "$( rigWitness spawned )" "keeper-myx"
rigAssert "a served SendMessage gets past the identity gate" "$( rigSend spawned )" "past-identity"

echo "-- control: the spawned member is not in the skillset --"
rigAssert "the server serves with no identity" "$( rigWitness absent )" "<none>"
rigAssert "a served SendMessage is refused for want of one" "$( rigSend absent )" "refused-no-identity"
rigAssert "a served Read still works" "$( rigRead absent )" "read"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SERVED IDENTITY CHECK FAILED: $rigFails assertion(s)" >&2
	echo "  warn: a call served over MCP carries no team identity, so AskUserQuestion," >&2
	echo "        SendMessage, Wait and Agent refuse in every native-client session" >&2
	echo "  fix:  repair the identity resolution in" >&2
	echo "        sh-lib/AgentsTools.InternMcpServer.include -- never the assertion" >&2
	exit 1
fi
echo "HARNESS_SERVED_IDENTITY: OK (root as magic-coordinator, spawned as its member, missing member dropped with other tools served, ask body with options built, offline)"