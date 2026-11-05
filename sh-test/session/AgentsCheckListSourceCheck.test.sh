#!/usr/bin/env bash
## Behavioural check on where a CheckList item came from (S6.27, the smallest first slice): an item that is the step of a
## routine, one a parent added and one its owner wrote are told apart, and a `--replace` swaps the replaced routine's
## steps for the new routine's while every other item stays. Held:
##   1. the seed keeps the source of what it seeds: `parent` for the brief's item, `step` for the routine's duty
##   2. the read shows a source that is not the owner's own, ` [step]` and ` [parent]`, and nothing for `own`
##   3. an item the owner writes itself carries no source and is shown with none
##   4. a parent's add is kept as `parent`, and shown so
##   5. a replace drops the replaced routine's step items, adds the new routine's steps before the kept
##      items, and keeps a parent's item and the owner's own
##   6. control: a replace on a list holding no step item adds the new steps, drops nothing and keeps every item
##   7. the source of an item that stays stays, and no ` [step]` of the replaced routine is left
##   8. a mark whose item has left the list is gone, so a member's own item that reuses a dropped step's text
##      survives the next replace (R1)
##   9. a member that writes its own read back keeps its items' sources, and its text carries no suffix (R2)
## Red before the source was built: 1 to 9 fail (no source is kept, shown or acted on), and only the launch holds.
## Red before the stale mark was pruned: 8 fails. Red before the echoed suffix was read: 9 fails.
## Red before a replace added the new routine's steps: 5 and 6 fail, and 8 goes red with them.
## Offline: a fake console and a fake curl answer the spawn, every tree is this rig's own.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigHere="$rigPackage/sh-lib"
rigTest="$rigPackage/sh-test"
rigFixtures="$rigTest/check-fixtures"
rigSessionFn="$rigPackage/sh-scripts/DistroAgentsSession.fn.sh"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigSessionFn" "$rigTool" "$rigHarness" "$rigFixtures/session-chat.curl.stub.sh" "$rigFixtures/rig-temp.include.sh" "$rigFixtures/rig-exec.py" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsCheckListSourceCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSkills="$rigTmp/skills"
rigData="$rigTmp/data"
rigMember="rig-member"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigTmp/bin" "$rigTmp/home" "$rigData/board/running" "$rigData/inboxes/$rigMember" \
	"$rigSkills/magic-team" "$rigSkills/$rigMember" || exit 1
printf 'rig member\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_WORKSPACE_DOMAIN=rig.slack.com\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-RIG\n' > "$rigWs/.local/.agents/$rigMember.agent.env"
cp "$rigFixtures/session-chat.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"
## The console stand-in: it records the dispatch it is started with and launches nothing.
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records the context.' \
	'[ -s "$RIG_SCENARIO/brief" ] && { cat > /dev/null ; exit 0 ; }' \
	'rigContext="$( cat )"' \
	'case "$rigContext" in "Your previous run on this task ended without calling SubagentHandback."*) exit 0 ;; esac' \
	'printf "%s\n" "$rigContext" > "$RIG_SCENARIO/brief"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"

## The routines of the rig: the kind routine every session runs, and the two a replace moves between, each with two duties.
printf -- '---\nexecutors: %s\nmaintainers: rig\ninvitees: none\nrequires-session-kind: standalone\n---\n# rig kind routine\n' "$rigMember" \
	> "$rigSkills/magic-team/magic-team.standalone.routine.md"
rigRoutine(){ ## file name -- a routine of two steps, the first named rig-a-one or rig-b-one
	local rigName="$1"
	{
		printf -- '---\ntype: routine\nexecutors: %s\nmaintainers: rig\ninvitees: none\nrequires-session-kind: standalone\n---\n' "$rigMember"
		printf '# %s\n\n# Steps\n\n1. **%s-one**: do the first thing.\n2. **%s-two**: do the second thing.\n' "$rigName" "${rigName%%.*}" "${rigName%%.*}"
	} > "$rigSkills/magic-team/$rigName"
}
rigRoutine rig-a.routine.md
rigRoutine rig-b.routine.md

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

rigRecord="" rigList="" rigSession="" rigSpawn=""
## The one scene: a real spawn of rig-member that opens a session with rig-a, its brief's formal task and one argument.
rigScene(){
	rm -rf "$rigWs/.local/agents" "$rigTmp/brief" "$rigData/board/running"/*.md 2> /dev/null
	mkdir -p "$rigWs/.local/agents/spawned" "$rigWs/.local/agents/sessions"
	: > "$rigTmp/brief"
	rigSpawnOut="$( cd "$rigWs" && printf 'RIG-SEED-BRIEF\n\n## Formal task\n\n- RIG-BRIEF-STEP\n' | \
		env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash "$rigTool" --intern-op-agent-spawn-proxy "$rigMember" --dispatch-doc:none --wait --context rig-checklist-source \
			--routine rig-a.routine.md --session-new --checklist-item RIG-ARG-STEP 2>&1 )"
	rigRecord="$( find "$rigWs/.local/agents/spawned" -name '*.spawn.md' 2> /dev/null | LC_ALL=C head -1 )"
	[ -n "$rigRecord" ] || rigRefuse "the spawn made no record, so nothing was seeded: $( printf '%s\n' "$rigSpawnOut" | LC_ALL=C grep -m1 -e ERROR -e WARNING )"
	rigSpawn="$( LC_ALL=C sed -n 's/^spawn-id: //p' "$rigRecord" | LC_ALL=C head -1 )"
	rigSession="$( LC_ALL=C sed -n 's/^session-id: //p' "$rigRecord" | LC_ALL=C head -1 )"
	[ -n "$rigSpawn" ] && [ -n "$rigSession" ] || rigRefuse "the spawn record names no session: $rigRecord"
	rigList="${rigRecord%/*}/$rigMember.checklist.md"
	## THE PARENT OF THE RUN: the append below is the parent's own, so the record names one; the tooling wrote the record
	## and a rig may add the line its own scenario needs (another check's record is written whole by the same reading).
	LC_ALL=C awk '$0 == "---" { if ( ++dashes == 2 ) { print "parent-session-id: rig-parent" } } { print }' "$rigRecord" > "$rigRecord.new" \
		&& mv -f "$rigRecord.new" "$rigRecord"
	printf -- '---\nspawn-id: rig-parent\nsession-id: rig-parent\nowner: %s\nparent-session-id: none\n---\n' "$rigMember" \
		> "$rigWs/.local/agents/spawned/rig-parent.spawn.md"
}
## The CheckList tool's answer in one of the rig's environments: a caller of the session the spawn opened, or the parent.
rigCall(){ ## the caller (run|parent), the JSON arguments
	local rigWho="$1" rigArgs="$2" rigRole=0
	case "$rigWho" in
		run) rigRole=0 ;;
		parent) rigRole=1 ;;
		*) rigRefuse "$rigWho is no caller of this rig" ;;
	esac
	( cd "$rigWs" && printf '%s' "$rigArgs" | \
		env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_SPAWN_AGENT="$rigMember" MDAT_SPAWN_SESSION_ID="$rigSpawn" MDAT_SESSION_ID="$rigSession" \
		bash -c 'if [ "$1" = 1 ] ; then export MDAT_SESSION_ID=rig-parent MDAT_SPAWN_SESSION_ID=rig-parent ; fi ; shift ; exec bash "$@"' \
		rig "$rigRole" "$rigHarness" --intern-tool CheckList 2> /dev/null )
}
rigItems(){ ## the items of the read, as the read shows them, one a line
	LC_ALL=C grep -e '^- \[ \] ' -e '^- \[x\] ' -e '^- \[~\] ' <<< "$1"
}
rigOut="" rigErr="" rigRc=""
## ONE MOVE, THEN ITS DRAIN WAITED OUT: a move posts into the session's event-track thread, and that post outlives the call.
rigMove(){ ## name, then the operation's arguments
	local moveName="$1" moveRc=0 moveLeft=90
	shift
	rigOut="$rigTmp/$moveName.out" rigErr="$rigTmp/$moveName.err"
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" "PATH=$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		"MMDAPP=$rigWs" "MDLT_ORIGIN=$rigOrigin" "MDLT_OPTION=--run-from-path $rigOrigin" "MDAT_SKILLSET_ROOT=$rigSkills" \
		"MDAT_DATA_ROOT=$rigData" "MDAT_WAIT_REMIND=off" "MDAT_COMMS_READER=off" "MDAT_COLLECT_THREAD=off" "MDAT_TEAM_DATA_COMMIT_THREAD=off" \
		"RIG_SCENARIO=$rigTmp" "MDAT_SESSION_ID=$rigSession" "MDAT_SPAWN_SESSION_ID=$rigSpawn" "MDAT_SPAWN_AGENT=$rigMember" \
		python3 -I -B "$rigFixtures/rig-exec.py" --alarm 120 -- bash "$rigSessionFn" "$@" ) > "$rigOut" 2> "$rigErr" < /dev/null || moveRc=$?
	rigRc="$moveRc"
	while [ "$moveLeft" -gt 0 ] ; do
		[ -n "$( ls -d "$rigWs"/.local/agents/event-track-send/*/[0-9]* "$rigWs"/.local/agents/locks/event-track-send-* 2> /dev/null )" ] || return 0
		sleep 1 ; moveLeft=$(( moveLeft - 1 ))
	done
	return 0
}

echo "-- 1 and 2. the seed keeps each item's source, and the read shows it --"
rigScene
rigAssert "the spawn opened the session and seeded its list" "$( [ -f "$rigList" ] && printf yes || printf no )" yes
rigRead="$( rigCall run '{}' )"
rigAssert "the brief's item is the parent's, and shown so" "$( rigItems "$rigRead" | LC_ALL=C grep -c -x -F -- '- [ ] RIG-BRIEF-STEP [parent]' )" 1
rigAssert "the argument's item is the parent's too"        "$( rigItems "$rigRead" | LC_ALL=C grep -c -x -F -- '- [ ] RIG-ARG-STEP [parent]' )" 1
rigAssert "the routine's duties are the step's, and shown so" "$( rigItems "$rigRead" | LC_ALL=C grep -c -e '- \[ \] rig-a-one \[step\]' -e '- \[ \] rig-a-two \[step\]' )" 2
rigAssert "and nothing else stands beside them"            "$( rigItems "$rigRead" | LC_ALL=C grep -c '\[step\]\|\[parent\]' )" 4

echo "-- 3. an item the owner writes itself carries no source --"
rigCall run '{"todos":[{"content":"RIG-BRIEF-STEP","status":"pending","activeForm":"A"},{"content":"rig-a-one","status":"pending","activeForm":"B"},{"content":"rig-a-two","status":"pending","activeForm":"C"},{"content":"RIG-ARG-STEP","status":"pending","activeForm":"D"},{"content":"RIG-OWN-ITEM","status":"pending","activeForm":"Doing the owner item"}]}' > /dev/null
rigRead="$( rigCall run '{}' )"
rigAssert "the owner's item is shown with no source"       "$( rigItems "$rigRead" | LC_ALL=C grep -c -x -F -- '- [ ] RIG-OWN-ITEM' )" 1
rigAssert "and the seeded items keep theirs"               "$( rigItems "$rigRead" | LC_ALL=C grep -c -e '- \[ \] rig-a-one \[step\]' -e '- \[ \] RIG-BRIEF-STEP \[parent\]' )" 2

echo "-- 4. a parent's add is kept as the parent's --"
rigCall parent '{"append":["RIG-ADDED-ITEM"],"member":"'"$rigMember"'","session":"'"$rigSession"'"}' > /dev/null
rigRead="$( rigCall run '{}' )"
rigAssert "the added item is shown as the parent's"        "$( rigItems "$rigRead" | LC_ALL=C grep -c -x -F -- '- [ ] RIG-ADDED-ITEM [parent]' )" 1

echo "-- 5 and 7. a replace drops the replaced routine's steps, adds the new ones, and keeps every other --"
rigMove m-1 --routine-stack --replace rig-b.routine.md --reason "the plan is not needed after all"
rigAssert "the replace is made: rc 0 and an OK line"       "$rigRc:$( LC_ALL=C grep -c -F 'OK: --routine-stack replace' "$rigOut" )" "0:1"
rigAssert "the replaced routine's step items are gone"     "$( LC_ALL=C grep -c -e '^- \[ \] rig-a-one' -e '^- \[ \] rig-a-two' "$rigList" )" 0
rigAssert "the new routine's steps are on the list, pending" "$( LC_ALL=C grep -c -e '^- \[ \] rig-b-one' -e '^- \[ \] rig-b-two' "$rigList" )" 2
rigAssert "they stand before everything that was kept, in the routine's order" \
	"$( LC_ALL=C grep -e '^- \[ \] ' -e '^- \[x\] ' -e '^- \[~\] ' "$rigList" | LC_ALL=C awk 'BEGIN { ORS = "" } { sub( /^- \[[ x~]\] /, "", $0 ) ; printf "%s%s", ( NR > 1 ? "|" : "" ), $0 }' )" \
	"rig-b-one|rig-b-two|RIG-BRIEF-STEP|RIG-ARG-STEP|RIG-OWN-ITEM|RIG-ADDED-ITEM"
rigAssert "the parent's item stays, with its source"       "$( LC_ALL=C grep -c -x -F -- '- [ ] RIG-BRIEF-STEP' "$rigList" )" 1
rigAssert "the parent's add stays too"                     "$( LC_ALL=C grep -c -x -F -- '- [ ] RIG-ADDED-ITEM' "$rigList" )" 1
rigAssert "and the owner's own item stays"                 "$( LC_ALL=C grep -c -x -F -- '- [ ] RIG-OWN-ITEM' "$rigList" )" 1
rigAssert "what stayed is still shown with its own source"  "$( rigItems "$( rigCall run '{}' )" | LC_ALL=C grep -c -x -F -- '- [ ] RIG-BRIEF-STEP [parent]' )" 1
rigAssert "and no step source is left of the replaced routine" "$( rigItems "$( rigCall run '{}' )" | LC_ALL=C grep -c -x -F -- '- [ ] rig-a-one [step]' )" 0
rigAssert "the list holds the two steps and the four that stayed" "$( LC_ALL=C grep -c -e '^- \[ \] ' -e '^- \[x\] ' -e '^- \[~\] ' "$rigList" )" 6
rigAssert "and says how many it dropped and added"          "$( LC_ALL=C grep -c -F 'checklist:' "$rigOut" )" 1

echo "-- 6. control: a replace on a list holding no step item adds the new steps and drops nothing --"
rigCall run '{"todos":[{"content":"RIG-BRIEF-STEP","status":"pending","activeForm":"A"},{"content":"RIG-ADDED-ITEM","status":"pending","activeForm":"B"},{"content":"RIG-OWN-ITEM","status":"pending","activeForm":"C"}]}' > /dev/null
rigAssert "the member holds its three items and no step item" "$( LC_ALL=C grep -c -e 'rig-b-one' -e 'rig-b-two' "$rigList" )" 0
rigMove m-2 --routine-stack --replace rig-b.routine.md --reason "control: nothing of that routine is on the list"
rigAssert "the replace is made"                            "$rigRc:$( LC_ALL=C grep -c -F 'OK: --routine-stack replace' "$rigOut" )" "0:1"
rigAssert "it dropped nothing, and added the two steps"   "$( LC_ALL=C grep -c -F 'checklist: 0 item(s) dropped, 2 added, 3 kept' "$rigOut" )" 1
rigAssert "and the two steps are on the list all the same"  "$( LC_ALL=C grep -c -e '^- \[ \] rig-b-one' -e '^- \[ \] rig-b-two' "$rigList" )" 2
rigAssert "every item that was there is still there"        "$( LC_ALL=C grep -c -e '^- \[ \] ' -e '^- \[x\] ' -e '^- \[~\] ' "$rigList" )" 5

echo "-- 8. a mark whose item has left the list is gone, so a reused text survives --"
## THE MEMBER WRITES AN ITEM WHOSE TEXT A DROPPED STEP HAD. Only the store's own prune can keep that mark from naming
## this item, and the next replace would then delete the member's own work.
rigCall run '{"todos":[{"content":"RIG-BRIEF-STEP","status":"pending","activeForm":"A"},{"content":"RIG-ADDED-ITEM","status":"pending","activeForm":"B"},{"content":"RIG-OWN-ITEM","status":"pending","activeForm":"C"},{"content":"rig-a-one","status":"pending","activeForm":"D"}]}' > /dev/null
rigAssert "the member holds an item whose text a step had"  "$( LC_ALL=C grep -c -x -F -- '- [ ] rig-a-one' "$rigList" )" 1
rigMove m-3 --routine-stack --replace rig-a.routine.md --reason "the first routine again, after the item was reused"
rigAssert "the replace is made"                            "$rigRc:$( LC_ALL=C grep -c -F 'OK: --routine-stack replace' "$rigOut" )" "0:1"
rigAssert "the member's own item is not deleted as a step that left" "$( LC_ALL=C grep -c -x -F -- '- [ ] rig-a-one' "$rigList" )" 1
rigAssert "and the routine's own step stands beside it"     "$( LC_ALL=C grep -c -x -F -- '- [ ] rig-a-two' "$rigList" )" 1

echo "-- 9. a member that writes its own read back keeps its items' sources --"
rigRead="$( rigCall run '{}' )"
rigAssert "the read shows the parent's item with its source" "$( rigItems "$rigRead" | LC_ALL=C grep -c -x -F -- '- [ ] RIG-BRIEF-STEP [parent]' )" 1
rigEcho="$( printf '%s\n' "$rigRead" | LC_ALL=C awk '/^- \[[ x~]\] / { line = $0 ; sub( /^- \[[ x~]\] /, "", line ) ; printf "{\"content\":\"%s\",\"status\":\"pending\",\"activeForm\":\"Echo\"},", line }' )"
rigCall run "{\"todos\":[${rigEcho%,}]}" > /dev/null
rigAssert "an echoed read writes no suffix into an item's text" "$( LC_ALL=C grep -c '\[step\]\|\[parent\]' "$rigList" )" 0
rigAssert "and the items' sources are still what they were"  "$( rigItems "$( rigCall run '{}' )" | LC_ALL=C grep -c -x -F -- '- [ ] RIG-BRIEF-STEP [parent]' )" 1

## THE RIG'S OWN PROCESSES ARE BACK BEFORE THIS CHECK ENDS: a move's event-track post is drained by a process started
## apart, which outlives the call by a few seconds, so the check waits them out, bounded, and asserts that it did.
rigSettle(){
	local settleLeft=90
	while [ "$settleLeft" -gt 0 ] ; do
		[ "$( ps -A -ww -o args= 2>/dev/null | LC_ALL=C awk -v rig="$rigTmp" 'index( $0, rig ) && !/awk/ { n++ } END { print n + 0 }' )" != "0" ] || return 0
		sleep 1 ; settleLeft=$(( settleLeft - 1 ))
	done
	return 1
}
if rigSettle ; then rigSettled="clean" ; else rigSettled="left-running" ; fi
rigAssert "no process of this check is left running when it ends" "$rigSettled" clean

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ CHECKLIST SOURCE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	printf 'CHECKLIST_SOURCE: FAILED (%d compared, %d assertion(s))\n' "$(( rigPassCount + rigFailCount ))" "$rigFailCount"
	exit 1
fi
printf 'CHECKLIST_SOURCE: OK (%d assertions, offline)\n' "$rigPassCount"
