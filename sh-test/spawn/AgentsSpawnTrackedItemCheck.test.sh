#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on a spawn's optional tracked item name, beside any brief source. Which item a
## run works on is a fact about the spawn; which source delivered its brief is a different fact.
## Held, against the real proxy and the real grant reader, in a rig tree:
##   1. a file brief with no tracked name: the dispatch tracks nothing, and no warning names one
##   2. a file brief with a tracked name: `tracks:` is written, and the run reads that item's rows
##   3. a tracked name that resolves to no board item: the spawn refuses, and starts nothing
##   4. an item source and a tracked name that differ: the spawn refuses; the same name proceeds
##   5. a tracked item the member takes no part in: no row is granted by it, and its owner reads it
##   6. a brief naming a board item, tracks none: one stderr line, and the spawn still starts
##   7. the wire's Agent declaration carries the argument, so a caller can pass it
## Offline: a fake console runs no model, a fake curl opens no socket, and every run is an `env -i`
## child of this rig's own trees.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigTest/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package"
. "$rigTest/check-fixtures/rig-temp.include.sh" || rigRefuse "the rig's temp fixture is missing from the package"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-owner-writes.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSpawnTrackedItemCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rigControlThreadsEnd "$rigTmp" ; rigSpawnLeftEnd ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
rigSkills="$rigTmp/skills"
[ "$rigWs" != "${MMDAPP%/}" ] || rigRefuse "the rig workspace is the real one"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigSkills/keeper-myx" "$rigSkills/magic-tester" "$rigWs/WORK"
cp "$rigTest/check-fixtures/spawn-tracking-place.curl.stub.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: sh-test/check-fixtures/spawn-tracking-place.curl.stub.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIGTEAM1\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK1\nSLACK_CHANNEL_EVENT_ALERT=CRIGALERT\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' \
	> "$rigWs/.local/.agents/magic-team.agent.env"
for rigMember in keeper-myx magic-tester ; do
	printf -- '---\nname: %s\ndescription: rig member\n---\n' "$rigMember" > "$rigSkills/$rigMember/SKILL.md"
	printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
done
## The console the proxy launches: it records the brief, hands back at once, and runs no model.
## It names --cli-configured and MDAT_SPAWN_LAUNCH_MARKER, which the proxy greps for before it
## launches anything. Its handback is what keeps the proxy's missing-handback retry, and that
## retry's own timer, out of a rig that has no run to retry.
cat > "$rigWs/DistroAgentsConsole.sh" <<'RIGCONSOLE'
#!/usr/bin/env bash
## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records the brief.
cat > "$RIG_SCENARIO/brief"
printf 'rig-cli\n' > "$MDAT_SPAWN_LAUNCH_MARKER"
printf '%s\n' "$MDAT_SPAWN_SESSION_ID" > "$RIG_SCENARIO/last-spawn"
printf '   📦 SubagentHandback rig-outcome\n'
RIGCONSOLE
chmod +x "$rigWs/DistroAgentsConsole.sh"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## A board item of this rig, in running: its owner, its `participants:` where it has any, and the row
## that admits a Write of one path. The row is signed by a holder, as an approved set's is.
rigTask(){ ## item name, owner, participants (may be empty), path the row admits
	{
		printf -- '---\ntype: task\nowner: %s\n' "$2"
		[ -z "$3" ] || printf 'participants: %s\n' "$3"
		printf 'access-control: participants:allow-write:%s:human-owner:20261015T0000Z\n' "$4"
		printf -- '---\n\n# Rig task\n'
	} | rigOwnerBoardPut running "$1.md"
}
## One spawn of this rig, waited for, with a dispatch document, so the item it writes is kept.
## Its brief is $rigBrief, and its output goes to a file, never a capture.
rigBrief="RIG-TASK-TEXT"
rigSpawn(){ ## member, extra proxy arguments...
	local spawnMember="$1"
	shift
	rm -f "$rigTmp/brief" "$rigTmp/last-spawn" "$rigTmp/spawn.out"
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" \
		bash -c '
			case "$MMDAPP" in "$RIG_SCENARIO"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_SCENARIO"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$0" --intern-op-agent-spawn-proxy "$@" --dispatch-doc:create --wait --context rig-tracked-item
		' "$rigTool" "$spawnMember" "$@" <<< "$rigBrief" > "$rigTmp/spawn.out" 2>&1 ) || :
	rigSettle
	rigOut="$( cat "$rigTmp/spawn.out" )"
	rigItem="$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^DISPATCH_ITEM=//p' | head -1 )"
}
## A spawn's close runs in a subshell of its own, behind a retry timer, and outlives the call
## that started it. Waited for here, bounded, so the check leaves nothing of its own context
## behind: a rig that is removed under a running close leaves the machine holding its work.
rigSpawnRunning(){ ## -- the pids of this check's own spawn proxies still running, one a line
	ps -A -ww -o pid=,args= 2> /dev/null | LC_ALL=C awk -v self="$$" '$1 != self && /DistroAgentsTools.fn.sh --intern-op-agent-spawn-proxy/ && /--context rig-tracked-item/ { print $1 ; }'
}
rigSettle(){
	local settleLeft=450
	while [ "$settleLeft" -gt 0 ] ; do
		if [ -z "$( rigSpawnRunning )" ] ; then return 0 ; fi
		sleep 0.2 ; settleLeft=$(( settleLeft - 1 ))
	done
	return 0
}
## What a spawn of this check left behind, ended: rigSpawnRunning names this check's own proxies
## and no other process, so a close that outlives the rig never leaves the machine holding its work.
rigSpawnLeftEnd(){
	local leftPids="$( rigSpawnRunning )"
	[ -z "$leftPids" ] || rigProcSignalWithChildren KILL $leftPids
	return 0
}
rigStarted(){ ## -- how many dispatch items the last spawn wrote: a start, and a refusal writes none
	printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^DISPATCH_ITEM=' || :
}
## The file of a board item of this rig, in whichever state holds it: a dispatch item's close
## moves it from running to review, so its own name is followed rather than its folder.
rigItemPath(){ ## item name
	local itemFound="" itemStateDir
	for itemStateDir in "$rigData"/board/* ; do
		[ -f "$itemStateDir/${1%.md}.md" ] || continue
		itemFound="$itemStateDir/${1%.md}.md"
		break
	done
	printf '%s' "$itemFound"
}
rigHeader(){ ## item path, header -- its value, or `-`
	LC_ALL=C awk -v wantField="$2" '
		NR == 1 && $0 != "---" { exit ; }
		$0 == "---" { dashes++ ; if ( dashes == 2 ) { exit ; } ; next ; }
		index( $0, wantField ": " ) == 1 { print substr( $0, length( wantField ) + 3 ) ; found = 1 ; exit ; }
		END { if ( ! found ) { print "-" ; } ; }
	' "$1"
}
rigGrantRead(){ ## member, session, tool, path -- what grants it, as the grant read says, or empty
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		bash "$rigTool" --intern-op-permission-grant-read "$1" --session-id "$2" --tool "$3" --target "$4" 2> /dev/null ) \
		| LC_ALL=C sed -n 's/^GRANT: //p' | head -1
}
rigMarker(){ ## -- how many output lines the last spawn printed about tracking no item
	LC_ALL=C grep -c 'tracks no item' "$rigTmp/spawn.out" 2> /dev/null || :
}

echo "-- 1. a file brief with no tracked name: the dispatch tracks nothing, and nothing is warned --"
rigSpawn keeper-myx
[ -n "$rigItem" ] || rigRefuse "the first spawn wrote no dispatch item, so nothing below would be measured: $( printf '%s\n' "$rigOut" | LC_ALL=C grep -i 'error' | head -1 )"
rigAssert "it started, and its dispatch tracks nothing" \
	"$( rigStarted ):$( rigHeader "$( rigItemPath "$rigItem" )" tracks )" "1:-"
rigAssert "and nothing in its output says it tracks no item" \
	"$( rigMarker )" 0

echo "-- 2. a file brief with a tracked name: tracks: is written, and the run reads that item's rows --"
rigTask task-20261015T0000Z-rig-alpha keeper-myx "" "$rigWs/WORK/alpha.txt"
printf 'rig-seed\n' > "$rigWs/WORK/alpha.txt"
rigSpawn keeper-myx --tracked-item task-20261015T0000Z-rig-alpha
rigTracked="$rigItem"
rigAssert "it started, and its dispatch tracks the item it was given" \
	"$( rigStarted ):$( rigHeader "$( rigItemPath "$rigTracked" )" tracks )" "1:task-20261015T0000Z-rig-alpha"
rigAssert "the run reads the task's row, as its owner and only participant" \
	"$( rigGrantRead keeper-myx "$( cat "$rigTmp/last-spawn" )" Write "$rigWs/WORK/alpha.txt" )" "planned $rigTracked"

echo "-- 3. a tracked name that resolves to no board item: the spawn refuses, and starts nothing --"
rigSpawn keeper-myx --tracked-item task-20261015T0000Z-rig-no-such-item
rigAssert "it refuses, names the item, and starts nothing" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'task-20261015T0000Z-rig-no-such-item' || : ):$( rigStarted )" "1:0"

echo "-- 4. an item source and a tracked name: a different one refuses, the same one proceeds --"
rigTask task-20261015T0001Z-rig-beta keeper-myx "" "$rigWs/WORK/beta.txt"
rigSpawn keeper-myx --from-board task-20261015T0000Z-rig-alpha.md --tracked-item task-20261015T0001Z-rig-beta
rigAssert "two items named: it refuses, and starts nothing" \
	"$( rigStarted )" "0"
rigSpawn keeper-myx --from-board task-20261015T0000Z-rig-alpha.md --tracked-item task-20261015T0000Z-rig-alpha
rigAssert "the same item named twice: it proceeds, and tracks it" \
	"$( rigStarted ):$( rigHeader "$( rigItemPath "$rigItem" )" tracks )" "1:task-20261015T0000Z-rig-alpha"

echo "-- 5. a tracked item the member takes no part in: no row is granted by it --"
rigTask task-20261015T0002Z-rig-gamma magic-tester "" "$rigWs/WORK/gamma.txt"
printf 'rig-seed\n' > "$rigWs/WORK/gamma.txt"
rigSpawn keeper-myx --tracked-item task-20261015T0002Z-rig-gamma
rigNotMine="$rigItem"
rigAssert "control: it started, and its dispatch tracks that item" \
	"$( rigStarted ):$( rigHeader "$( rigItemPath "$rigNotMine" )" tracks )" "1:task-20261015T0002Z-rig-gamma"
rigAssert "the member is no participant and no owner, so the item grants it no row" \
	"$( rigGrantRead keeper-myx "$( cat "$rigTmp/last-spawn" )" Write "$rigWs/WORK/gamma.txt" )" ""
rigSpawn magic-tester --tracked-item task-20261015T0002Z-rig-gamma
rigMineTester="$rigItem"
rigAssert "and its owner, spawned on the same item, does read it: one item, two answers" \
	"$( rigStarted ):$( rigGrantRead magic-tester "$( cat "$rigTmp/last-spawn" )" Write "$rigWs/WORK/gamma.txt" )" "1:planned $rigMineTester"

echo "-- 6. a brief naming a board item, tracks none: one stderr line, and the spawn still starts --"
rigBrief="Change the loader as task-20261015T0000Z-rig-alpha says, and keep the rest."
rigSpawn keeper-myx
rigAssert "it started, tracks nothing, and says one warning line about it" \
	"$( rigStarted ):$( rigHeader "$( rigItemPath "$rigItem" )" tracks ):$( rigMarker )" "1:-:1"
rigAssert "the warning names the item the brief named" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'task-20261015T0000Z-rig-alpha' || : )" 1
rigBrief="RIG-TASK-TEXT"

echo "-- 7. the wire's Agent declaration carries the argument, so a caller can pass it --"
rigDeclaration="$( LC_ALL=C awk '/\{"type":"function","function":\{"name":"Agent",/ { print ; exit ; }' "$rigHere/harness/AgentsOpenAiChatWire.sh" )"
[ -n "$rigDeclaration" ] || rigRefuse "the wire declares no Agent tool, so the served schema was not measured"
rigAssert "the Agent declaration is reached, and its arguments carry tracked_item beside session_id" \
	"$( printf '%s' "$rigDeclaration" | LC_ALL=C grep -c '"session_id"' ):$( printf '%s' "$rigDeclaration" | LC_ALL=C grep -c '"tracked_item"' )" "1:1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SPAWN TRACKED ITEM CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_TRACKED_ITEM: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
