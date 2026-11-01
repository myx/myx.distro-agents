#!/usr/bin/env bash
## Behavioural check on the session identity an MCP server carries for the run it serves (owner 2026-10-31): a member
## idle in a plain Wait shows RUNNING because the harness's own tools are served through this server, which was told no
## session, so the served harness recorded nothing of the wait. Held: the harness names its session in the handshake it
## opens every exchange with, the server keeps that name for every later request of its own process, and a served Wait
## leaves the run's own `wait going idle` milestone in the session store the console reads. A handshake that names no
## session leaves the store untouched, so a client that knows nothing of a session is served as before. Drives a real
## `--intern-mcp-server --run` over stdio against a copied origin. Offline; the rig is a temp tree.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigSource="${MDLT_ORIGIN:=$MMDAPP/.local}"
[ -d "$rigSource/myx/myx.distro-agents/sh-lib" ] || { echo "⛔ ERROR: no myx.distro-agents at $rigSource -- refusing to report a result" >&2 ; exit 1 ; }
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsMcpServedSessionCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigTmp="$( cd "$rigTmp" && pwd -P )"
rigWs="$rigTmp/ws"
mkdir -p "$rigTmp/origin/myx" "$rigWs/.local/agents/sessions" "$rigWs/.local/temp" "$rigTmp/home"
for rigEntry in "$rigSource"/* ; do
	[ "${rigEntry##*/}" = myx ] || rigCopyTree "$rigEntry" "$rigTmp/origin/${rigEntry##*/}"
done
for rigEntry in "$rigSource"/myx/* ; do
	[ "${rigEntry##*/}" = myx.distro-agents ] || rigCopyTree "$rigEntry" "$rigTmp/origin/myx/${rigEntry##*/}"
done
cp -R "$rigSource/myx/myx.distro-agents" "$rigTmp/origin/myx/myx.distro-agents"
rigTool="$rigTmp/origin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigClient="$rigTmp/origin/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessMcpClient.sh"
rigRunId="served-run-1"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## The handshake line the harness opens an exchange with, as the client builds it, for a run whose session is set.
rigHandshake(){ ## session id, or "" for a client that knows none
	MMDAPP="$rigWs" MDLT_ORIGIN="$rigTmp/origin" MDAT_SPAWN_SESSION_ID="$1" \
		bash -c '. "$1" > /dev/null 2>&1 ; AgentsHarnessMcpHandshake' _ "$rigClient" 2> /dev/null | head -1
}

## One exchange with the server: the handshake given, then an `execute` printing the session id the served script was
## given, whose reply lands in the file named. `execute` is the server's own tool, so a rig can serve it with no member.
rigServe(){ ## handshake line, reply file
	{ printf '%s\n' "$1"
	  printf '%s\n' '{"jsonrpc":"2.0","method":"notifications/initialized"}'
	  printf '%s\n' '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"execute","arguments":{"command":"printf %s ${MDAT_SPAWN_SESSION_ID:-none}"}}}'
	  sleep 8 ; } \
		| ( cd "$rigWs" && env -i PATH="$PATH" HOME="$rigTmp/home" TMPDIR="${TMPDIR:-/tmp}" MMDAPP="$rigWs" MDLT_ORIGIN="$rigTmp/origin" \
			bash "$rigTool" --intern-mcp-server --run 2> "$2.err" ) \
		| LC_ALL=C grep '"id":2' > "$2" || :
}
rigHolds(){ ## file, fixed text
	LC_ALL=C grep -q -F -- "$2" "$1" 2> /dev/null && printf yes || printf no
}

echo "-- 1. the identity the harness names --"
rigAssert "a handshake from a run that knows its session names it" "$( rigHandshake "$rigRunId" | LC_ALL=C grep -c -F -- "\"sessionId\":\"$rigRunId\"" )" 1
rigAssert "a client that knows no session names none, and its handshake is the one it always was" "$( rigHandshake '' )" '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"AgentsUniversalHarness","version":"1"}}}'

echo "-- 2. the session a served tool is given --"
rigServe "$( rigHandshake "$rigRunId" )" "$rigTmp/reply.named"
rigAssert "the server answered the call" "$( [ -s "$rigTmp/reply.named" ] && printf yes || printf no )" yes
rigAssert "and the tool it ran was given the session the client named, so what it does is recorded in that run's store" "$( rigHolds "$rigTmp/reply.named" "$rigRunId" )" yes

echo "-- 3. a client that names no session is served as before --"
rigServe "$( rigHandshake '' )" "$rigTmp/reply.none"
rigAssert "the server answered the call" "$( [ -s "$rigTmp/reply.none" ] && printf yes || printf no )" yes
rigAssert "and its tool was given no session at all" "$( rigHolds "$rigTmp/reply.none" none )" yes

if [ "$rigFailCount" -ne 0 ] ; then
	printf '⛔ MCP SERVED SESSION CHECK FAILED: %d of %d assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))"
	exit 1
fi
printf 'MCP_SERVED_SESSION: OK (%d assertions, offline)\n' "$rigPassCount"
