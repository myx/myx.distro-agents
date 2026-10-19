#!/usr/bin/env bash
## Behavioural check on the audit lookup (F5.8 of the refactorings epic): one lookup maps every name form the writer
## uses, compact and dashed, to its month folder, and to the audit root where no month applies, and all three audit
## readers use it: the reader `--member-audit-item-read`, the spawn proxy's `--from-audit`, and the item operations'
## audit lookup (AgentsToolsItemUpsert --from-audit). A session's own transcript, `session-*.log`, which a spawn record
## names in its `transcript:` field, is an audit item too. For a name with no item the reader answers `not found`,
## naming the name, and exits non-zero. Seen live on 2026-10-18: `not found` for transcript-20261010T1458Z-<topic>.md,
## which the writer had filed in audit/2026-10/, where only a dashed name was looked for.
## Held:
##   1. a transcript named by a compact stamp, in its month folder: read whole with exit 0, and by line range
##   2. written by the writer and then read by the reader, under both name forms
##   3. a session log named by a spawn record's transcript: field is read, whole and by range
##   4. the spawn proxy's --from-audit and the item operations' lookup find the same items as the reader: a compact
##      stamp of a past month, a dashed date, the session log, an item of the audit root
##   5. controls: a dashed date in its month folder, a name with no extension, an item in the audit root
##   6. three absent name forms answer `not found`, naming the name, with a non-zero exit, also through
##      --intern-mcp-execute, as a member's execute call runs it, and as an error through the MCP server's execute
##      tool and the served harness's Bash tool
## The item operations' lookup is reached through AgentsToolsItemUpsert, the one of them that writes where it found:
## an item it found is updated in place, and an item it missed is written anew into the folder it looks in first.
## Offline: a temp data store, skillset root and workspace; the spawn proxy's console is a stand-in that only records
## the brief, its Slack calls go to a fake curl first on PATH, and no git remote is set.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="${rigHere%/sh-lib}/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
## A spawn of this rig that is not waited for starts the control thread of its session: the rig ends it, before its tree is removed.
. "$rigTest/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsAuditItemReadCheck-XXXXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigAudit="$rigTmp/data/audit"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned/rig-session" "$rigTmp/home" "$rigTmp/skills/magic-tester" "$rigTmp/bin" "$rigAudit/2026-09" "$rigAudit/2026-10" "$rigTmp/data/vault"
printf 'rig\n' > "$rigTmp/skills/magic-tester/magic-tester.basic.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
## The console the spawn proxy launches: it records the brief, and runs no model.
printf '%s\n' '#!/usr/bin/env bash' '## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records the brief.' \
	'cat > "$RIG_SCENARIO/brief"' 'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"

## The items. Each holds a line of its own, so a reader that found it shows it.
printf 'compact line one\ncompact line two\ncompact line three\n' > "$rigAudit/2026-10/transcript-20261010T1458Z-rig-interview.md"
printf 'past compact line\n' > "$rigAudit/2026-09/transcript-20260915T1000Z-rig-past.md"
printf 'past dashed line\n' > "$rigAudit/2026-09/transcript-2026-09-15-rig-past-dashed.md"
printf 'dashed line\n' > "$rigAudit/2026-10/transcript-2026-10-11-rig-dashed.md"
printf 'bare line\n' > "$rigAudit/2026-10/transcript-2026-10-13-rig-bare"
printf 'root line\n' > "$rigAudit/transcript-rig-root.md"
rigLog="session-20260920T081500Z-magic-tester-1a2b3c4d.log"
printf '2026-09-20T08:15:00Z START member=magic-tester\n2026-09-20T08:15:01Z TOOL Wait -> ok\n2026-09-20T08:16:00Z END rc=0\n' > "$rigAudit/2026-09/$rigLog"
printf -- '---\nsession-id: rig-session\nspawn-id: 1a2b3c4d-0000-4000-8000-000000000001\nparent-spawn-id: none\nowner: magic-tester\nstatus: spawn-succeeded\ntranscript: audit/2026-09/%s\n---\n' \
	"$rigLog" > "$rigWs/.local/agents/spawned/rig-session/1a2b3c4d-0000-4000-8000-000000000001.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHolds(){ ## file, fixed string
	LC_ALL=C grep -q -F -- "$2" "$1" 2> /dev/null && printf yes || printf no
}
rigOp(){ ## DistroAgentsTools.fn.sh arguments... -- out, err, rc in rigRc
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_DATA_ROOT="$rigTmp/data" RIG_SCENARIO="$rigTmp" \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" || rigRc=$?
}
rigRead(){ ## name, range arguments...
	rigOp --member-audit-item-read magic-tester "$@"
}
## The spawn proxy, the item a source: whether the brief its console was handed holds the line.
rigSpawnFinds(){ ## name, line
	: > "$rigTmp/brief"
	rigOp --intern-op-agent-spawn-proxy magic-tester --from-audit "$1" --dispatch-doc:none --wait --context rig-audit-read < /dev/null
	rigHolds "$rigTmp/brief" "$2"
}
## The item operations' lookup: an upsert of the item; prints where its new text went: in-place, elsewhere, or nowhere.
rigUpsertFinds(){ ## folder of the item below audit (empty: the root), name
	local upsertAt="$rigAudit${1:+/$1}/$2" upsertNew="rig upsert of $2"
	printf '%s\n' "$upsertNew" > "$rigTmp/upsert.in"
	rigOp --intern-mcp-execute <<< ". \"$rigHere/team-data/AgentsTools.InternOpItem.include\" && AgentsToolsItemUpsert magic-tester --from-audit \"$2\" --from-file \"$rigTmp/upsert.in\" --no-push --context rig-audit-read"
	if [ "$( rigHolds "$upsertAt" "$upsertNew" )" = yes ] ; then printf in-place
	elif [ -n "$( LC_ALL=C grep -r -l -F -- "$upsertNew" "$rigAudit" 2> /dev/null )" ] ; then printf elsewhere
	else printf nowhere
	fi
}

## Reached: the reader runs, and reads a transcript the way that works today.
rigRead transcript-2026-10-11-rig-dashed.md
[ "$( rigHolds "$rigTmp/out" 'dashed line' )" = yes ] || rigRefuse "the audit reader never read a transcript, so nothing below would be measured: $( LC_ALL=C grep -m1 ERROR "$rigTmp/err" )"

echo "-- 1. a transcript named by a compact stamp, in its month folder --"
rigRead transcript-20261010T1458Z-rig-interview.md
rigAssert "it is read, exit 0"                                "$rigRc" 0
rigAssert "whole: its first and last lines"                   "$( rigHolds "$rigTmp/out" 'compact line one' ) $( rigHolds "$rigTmp/out" 'compact line three' )" "yes yes"
rigAssert "and it is not answered as not found"               "$( rigHolds "$rigTmp/err" 'not found' )" no
rigRead transcript-20261010T1458Z-rig-interview.md --start-line 2 --end-line 2
rigAssert "by line range: line two and nothing else"          "$rigRc $( rigHolds "$rigTmp/out" 'compact line two' ) $( rigHolds "$rigTmp/out" 'compact line one' ) $( rigHolds "$rigTmp/out" 'compact line three' )" "0 yes no no"

echo "-- 2. what the writer files, the reader finds, under both name forms --"
for rigName in transcript-20261018T0900Z-rig-written.md transcript-2026-10-18-rig-written.md ; do
	rigOp --member-append-session-transcript magic-tester --speaker magic-tester --timestamp 2026-10-18T09:00:00Z --message "written to $rigName" --transcript-name "$rigName" --create
	rigWriteRc="$rigRc"
	rigRead "$rigName"
	rigAssert "$rigName: written (exit $rigWriteRc), then read back" "$rigWriteRc $rigRc $( rigHolds "$rigTmp/out" "written to $rigName" )" "0 0 yes"
done

echo "-- 3. a session log, named by a spawn record's transcript: field --"
rigRead "$rigLog"
rigAssert "it is read whole, exit 0"                          "$rigRc $( rigHolds "$rigTmp/out" 'START member=magic-tester' ) $( rigHolds "$rigTmp/out" 'END rc=0' )" "0 yes yes"
rigRead "$rigLog" --start-line 2 --end-line 2
rigAssert "and by line range"                                 "$rigRc $( rigHolds "$rigTmp/out" 'TOOL Wait' ) $( rigHolds "$rigTmp/out" 'START member' )" "0 yes no"

echo "-- 4. the three readers find the same items --"
for rigCase in "2026-09|transcript-20260915T1000Z-rig-past.md|past compact line" "2026-09|transcript-2026-09-15-rig-past-dashed.md|past dashed line" \
	"2026-09|$rigLog|START member=magic-tester" "|transcript-rig-root.md|root line" ; do
	rigFolder="${rigCase%%|*}" ; rigRest="${rigCase#*|}" ; rigName="${rigRest%%|*}" ; rigLine="${rigRest#*|}"
	rigRead "$rigName"
	rigAssert "$rigName: the reader reads it"                     "$rigRc $( rigHolds "$rigTmp/out" "$rigLine" )" "0 yes"
	rigAssert "$rigName: the spawn proxy's --from-audit hands it to the brief" "$( rigSpawnFinds "$rigName" "$rigLine" )" yes
	rigAssert "$rigName: the item operations' lookup finds it, and updates it in place" "$( rigUpsertFinds "$rigFolder" "$rigName" )" in-place
done

echo "-- 5. controls: the forms read today --"
rigRead transcript-2026-10-11-rig-dashed.md
rigAssert "a dashed date in its month folder"                 "$rigRc $( rigHolds "$rigTmp/out" 'dashed line' )" "0 yes"
rigRead transcript-2026-10-13-rig-bare
rigAssert "a name with no extension"                          "$rigRc $( rigHolds "$rigTmp/out" 'bare line' )" "0 yes"
rigRead transcript-rig-root.md
rigAssert "an item in the audit root"                         "$rigRc $( rigHolds "$rigTmp/out" 'root' )" "0 yes"

echo "-- 6. an absent name answers not found, naming it, with a non-zero exit --"
for rigName in transcript-20261010T1458Z-rig-absent.md transcript-2026-10-10-rig-absent.md transcript-rig-absent.md ; do
	rigRead "$rigName"
	rigAssert "$rigName: not found, non-zero, naming it"      "$( [ "$rigRc" -ne 0 ] && printf non-zero || printf 0 ) $( rigHolds "$rigTmp/err" 'not found' ) $( rigHolds "$rigTmp/err" "$rigName" )" "non-zero yes yes"
done
rigOp --intern-mcp-execute <<< "bash \"$rigTool\" --member-audit-item-read magic-tester transcript-20261010T1458Z-rig-absent.md"
rigAssert "through --intern-mcp-execute, as a member's execute call runs it, still non-zero" "$( [ "$rigRc" -ne 0 ] && printf non-zero || printf 0 ) $( cat "$rigTmp/out" "$rigTmp/err" | LC_ALL=C grep -c 'not found' )" "non-zero 1"

## Added by the builder of F5.8: the served paths a member reads through give a not-found as an error, never as a
## success: the MCP server's execute tool, as a native client calls it, and the served harness's Bash tool.
rigAbsent="transcript-20261010T1458Z-rig-absent.md"
{ printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-06-18","capabilities":{},"clientInfo":{"name":"rig","version":"1"}}}' \
	'{"jsonrpc":"2.0","method":"notifications/initialized"}'
  printf '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"execute","arguments":{"command":"bash %s --member-audit-item-read magic-tester %s"}}}\n' "$rigTool" "$rigAbsent"
  sleep 8 ; } \
	| ( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_DATA_ROOT="$rigTmp/data" RIG_SCENARIO="$rigTmp" bash "$rigTool" --intern-mcp-server --run 2> "$rigTmp/mcp.err" ) \
	| LC_ALL=C grep '"id":2' > "$rigTmp/mcp.reply" || :
rigAssert "through the MCP server's execute tool: an error, saying not found and the exit code" \
	"$( LC_ALL=C sed -n 's/.*"isError":\([a-z]*\).*/\1/p' "$rigTmp/mcp.reply" | head -1 ) $( rigHolds "$rigTmp/mcp.reply" 'not found' ) $( LC_ALL=C grep -c -E '\[exit code: [1-9][0-9]*\]' "$rigTmp/mcp.reply" )" "true yes 1"
printf '{"command":"bash %s --member-audit-item-read magic-tester %s","cwd":"%s","timeout":60}' "$rigTool" "$rigAbsent" "$rigWs" \
	| ( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_DATA_ROOT="$rigTmp/data" MDAT_SPAWN_AGENT=magic-tester bash "$rigHere/harness/AgentsUniversalHarness.sh" --intern-tool Bash --access-root "$rigWs" ) \
	> "$rigTmp/bash.out" 2> "$rigTmp/bash.err"
rigAssert "through the served harness's Bash tool: not found, and an exit status that is no success" \
	"$( rigHolds "$rigTmp/bash.out" 'not found' ) $( LC_ALL=C grep -c -E '^\(exit status [1-9][0-9]*\)$' "$rigTmp/bash.out" )" "yes 1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ AUDIT ITEM READ CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'AUDIT_ITEM_READ: OK (%d assertions, offline)\n' "$rigPassCount"
