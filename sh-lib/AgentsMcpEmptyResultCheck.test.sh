#!/usr/bin/env bash
## The MCP server never reports a harness tool that printed nothing as a quiet success.
## Drives a real `--intern-mcp-server --run` over stdio against a copied origin, with the
## harness intact, cut before its dispatch (exits 2), and cut but marked clean (exits 0
## with nothing on stdout, the case the server's own empty-result rule exists for).
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigSource="${MDLT_ORIGIN:=$MMDAPP/.local}"
[ -d "$rigSource/myx/myx.distro-agents/sh-lib" ] || { echo "⛔ ERROR: no myx.distro-agents at $rigSource -- refusing to report a result" >&2 ; exit 1 ; }

rigTmp="$( mktemp -d -t AgentsMcpEmptyResultCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigTmp="$( cd "$rigTmp" && pwd -P )"
## The target sits in the server's default write set, since a served call takes no root flags.
mkdir -p "$rigTmp/origin/myx" "$rigTmp/ws/.local/temp/team"
for rigEntry in "$rigSource"/* ; do
	[ "${rigEntry##*/}" = myx ] || ln -s "$rigEntry" "$rigTmp/origin/${rigEntry##*/}"
done
for rigEntry in "$rigSource"/myx/* ; do
	[ "${rigEntry##*/}" = myx.distro-agents ] || ln -s "$rigEntry" "$rigTmp/origin/myx/${rigEntry##*/}"
done
cp -R "$rigSource/myx/myx.distro-agents" "$rigTmp/origin/myx/myx.distro-agents"
rigHarness="$rigTmp/origin/myx/myx.distro-agents/sh-lib/AgentsUniversalHarness.sh"
cp "$rigHarness" "$rigTmp/harness.intact"
rigCut="$( LC_ALL=C grep -n '^## --intern-tool ends here' "$rigTmp/harness.intact" | head -1 | cut -d: -f1 )"
[ -n "$rigCut" ] || { echo "⛔ ERROR: the dispatch marker is not in the harness -- refusing to report a result" >&2 ; exit 1 ; }

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## One Edit through the server; the reply to request 2 lands in the file named.
rigServe(){ ## reply file
	printf 'rig-orig\n' > "$rigTmp/ws/.local/temp/team/t"
	{ printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"rig","version":"1"}}}' \
		'{"jsonrpc":"2.0","method":"notifications/initialized"}'
	  printf '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"Edit","arguments":{"path":"%s","old_text":"rig-orig","new_text":"rig-new"}}}\n' "$rigTmp/ws/.local/temp/team/t"
	  sleep 8 ; } \
		| ( cd "$rigTmp/ws" && env -u MDAT_SPAWN_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$rigTmp/origin" \
			bash "$rigTmp/origin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-mcp-server --run 2> "$1.err" ) \
		| LC_ALL=C grep '"id":2' > "$1" || :
	[ -s "$1" ] || { echo "⛔ ERROR: the server gave no reply to the tool call -- refusing to report a result" >&2 ; exit 1 ; }
}
rigIsError(){ ## reply file
	LC_ALL=C sed -n 's/.*"isError":\([a-z]*\).*/\1/p' "$1" | head -1
}
rigHolds(){ ## file, fixed text
	LC_ALL=C grep -q -F -- "$2" "$1" && printf yes || printf no
}

echo "-- control: the intact harness --"
rigServe "$rigTmp/r.intact"
rigAssert "the edit is reported"                       "$( rigHolds "$rigTmp/r.intact" 'OK: replaced one occurrence' )" yes
rigAssert "as a success"                               "$( rigIsError "$rigTmp/r.intact" )" false

echo "-- a harness cut before its dispatch --"
head -n $(( rigCut - 1 )) "$rigTmp/harness.intact" > "$rigHarness"
rigServe "$rigTmp/r.cut"
rigAssert "it is an error, never (no output)"          "$( rigIsError "$rigTmp/r.cut" )" true
rigAssert "naming that nothing came back"              "$( rigHolds "$rigTmp/r.cut" 'Edit produced no output and exited 2' )" yes
rigAssert "and the file is unchanged"                  "$( cat "$rigTmp/ws/.local/temp/team/t" )" rig-orig

echo "-- a harness that returns nothing with a clean exit --"
{ head -n $(( rigCut - 1 )) "$rigTmp/harness.intact" ; printf 'harnessExitClean=1\n' ; } > "$rigHarness"
rigServe "$rigTmp/r.empty"
rigAssert "it is an error, never (no output)"          "$( rigIsError "$rigTmp/r.empty" )" true
rigAssert "saying whether it ran is unknown"           "$( rigHolds "$rigTmp/r.empty" 'ERROR: Edit returned nothing and exited 0, so whether it ran, and what it changed, is unknown.' )" yes
rigAssert "and never the old quiet (no output)"        "$( rigHolds "$rigTmp/r.empty" '"text":"(no output)"' )" no

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MCP EMPTY RESULT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MCP_EMPTY_RESULT: OK (%d assertions, offline)\n' "$rigPassCount"
