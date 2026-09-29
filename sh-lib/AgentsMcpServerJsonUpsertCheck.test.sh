#!/usr/bin/env bash
## The MCP config upsert ends its output with exactly one newline, whatever its input
## ended with, so a second upsert is byte-identical and a re-install takes the
## unchanged path. The awk runs directly on temp files; the installer runs against a
## temp HOME and workspace under one `env -i` whose child refuses the real ones.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigAwk="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsMcpServerJsonUpsert.awk"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigLocalContext="$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/LocalContext.include"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigAwk" ] || rigRefuse "upsert awk not found: $rigAwk"
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
rigTmp="$( mktemp -d -t AgentsMcpServerJsonUpsertCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigUpsert(){ ## source file (or /dev/null), output file
	MYX_MCPUPSERT_TOPKEY=mcpServers MYX_MCPUPSERT_ENTRYKEY=rig.server MYX_MCPUPSERT_COMMAND=/rig/bin/server \
		MYX_MCPUPSERT_ARGS='["--run"]' MYX_MCPUPSERT_ENV='{"MMDAPP":"/rig/ws"}' LC_ALL=C awk -f "$rigAwk" "$1" > "$2" 2> "$2.err"
}
## The file's last two bytes, spelled: "}\n" is one final newline, "\n\n" is more.
rigTail(){ ## file
	tail -c 2 "$1" | od -An -c | tr -d ' '
}
rigSame(){ ## file, file
	cmp -s "$1" "$2" && printf same || printf differs
}

echo "-- the upsert itself --"
rigUpsert /dev/null "$rigTmp/a1"
rigUpsert "$rigTmp/a1" "$rigTmp/a2"
rigAssert "from nothing, it ends with one newline"     "$( rigTail "$rigTmp/a1" )" '}\n'
rigAssert "a second upsert is byte-identical"          "$( rigSame "$rigTmp/a1" "$rigTmp/a2" )" same
printf '%s' "$( cat "$rigTmp/a1" )" > "$rigTmp/none"
printf '%s\n\n\n' "$( cat "$rigTmp/a1" )" > "$rigTmp/three"
rigAssert "control: the none input really has no final newline" "$( tail -c 1 "$rigTmp/none" | od -An -c | tr -d ' ' )" '}'
rigAssert "control: the three input really ends in three" "$( tail -c 3 "$rigTmp/three" | od -An -c | tr -d ' ' )" '\n\n\n'
rigUpsert "$rigTmp/none" "$rigTmp/n1"
rigUpsert "$rigTmp/three" "$rigTmp/t1"
rigAssert "an input with no final newline gives the same output" "$( rigSame "$rigTmp/n1" "$rigTmp/a1" )" same
rigAssert "an input with three gives the same output" "$( rigSame "$rigTmp/t1" "$rigTmp/a1" )" same

echo "-- a re-install --"
if [ ! -f "$rigLocalContext" ] ; then
	rigRefuse "LocalContext.include not found, so no workspace can pass the installer's set-up check: $rigLocalContext"
fi
mkdir -p "$rigTmp/ws/.local/.agents" "$rigTmp/home" "$rigTmp/ws/.local/myx/myx.distro-.local/sh-lib"
ln -s "$rigLocalContext" "$rigTmp/ws/.local/myx/myx.distro-.local/sh-lib/LocalContext.include"
rigInstall(){
	env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$HOME" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --install-vscode-integrations
		' > /dev/null 2>&1
}
rigInstall
for rigConfig in .local/agents/mcp.servers.json .vscode/mcp.json .mcp.json ; do
	[ -f "$rigTmp/ws/$rigConfig" ] || rigRefuse "the first install wrote no $rigConfig"
	cp -p "$rigTmp/ws/$rigConfig" "$rigTmp/before.${rigConfig//\//_}"
done
sleep 1
rigInstall
for rigConfig in .local/agents/mcp.servers.json .vscode/mcp.json .mcp.json ; do
	rigAssert "$rigConfig keeps its bytes"             "$( rigSame "$rigTmp/before.${rigConfig//\//_}" "$rigTmp/ws/$rigConfig" )" same
done
## .vscode/mcp.json is rewritten in place by myx.common's own setup before this package's
## loop runs, so only the other two are held to an unchanged mtime.
for rigConfig in .local/agents/mcp.servers.json .mcp.json ; do
	rigAssert "$rigConfig is not rewritten (mtime kept)" "$( [ "$( ls -lT "$rigTmp/ws/$rigConfig" | awk '{ print $6, $7, $8, $9 ; }' )" = "$( ls -lT "$rigTmp/before.${rigConfig//\//_}" | awk '{ print $6, $7, $8, $9 ; }' )" ] && printf kept || printf rewritten )" kept
done

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MCP SERVER JSON UPSERT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MCP_SERVER_JSON_UPSERT: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
