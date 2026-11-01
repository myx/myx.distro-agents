#!/usr/bin/env bash
## Behavioural check on the pending count a handback declares (S22.1): the call carries `checklist_pending_count`, and it is refused unless that
## number equals the pending items of the caller's own list, an item naming the handback not counted. Through the real SubagentHandback tool, a
## Slack-shaped fake curl that opens no socket, and the list the CheckList tool keeps. Held:
##   1. two pending and no declared count refuses, and its line names both numbers
##   2. the same call declaring 2 passes on the first attempt, and carries both as unfinished
##   3. declaring 1 against 2 refuses, naming both numbers
##   4. a list whose only pending item names the handback passes with 0, and the send closes it
##   5. a list with only an item in progress passes with 0, and the item is not carried
##   6. a session that kept no list passes, and its handback says so
##   7. a value that is not a whole number is refused as an ERROR, and nothing is posted
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigMember="rig-helper"
rigCurrent="CSESS001:1700000002.000202"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "harness not found at the origin this workspace resolves: $rigHarness"

mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsHarnessHandbackPendingCountCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/skills"
mkdir -p "$rigTmp/skills/$rigMember"
printf '%s\n' "$rigMember" > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
cp "$rigTest/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:/usr/bin:/bin"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"

rigPassCount=0 rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigScenarioDir="" rigList=""
rigScene(){ ## scenario directory name
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir/ws/.local/.agents" "$rigScenarioDir/ws/.local/agents/spawned/child-folder" "$rigScenarioDir/data"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	RIG_CURL_LOG="$rigScenarioDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
	## The session's own record: its checklist is kept in the folder that holds it (AgentsHarnessCheckListPlace).
	printf -- '---\nspawn-id: rig-child-id\nparent-spawn-id: none\nsession-thread: %s\nowner: %s\n---\n' "$rigCurrent" "$rigMember" \
		> "$rigScenarioDir/ws/.local/agents/spawned/child-folder/rig-child-id.spawn.md"
	rigList="$rigScenarioDir/ws/.local/agents/spawned/child-folder/$rigMember.checklist.md"
}
rigCall(){ ## the call's other JSON fields, each leading with its own comma
	( cd "$rigScenarioDir/ws" && printf '{"to":"session-current","outcome":"the work is done"%s}' "${1:-}" | \
		env -u MDAT_DATA_ROOT -u MDAT_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigScenarioDir/data" \
		MDAT_SESSION_THREAD="$rigCurrent" MDAT_SPAWN_SESSION_ID=rig-child-id MDAT_SPAWN_AGENT="$rigMember" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		bash "$rigHarness" --intern-tool SubagentHandback > "$rigScenarioDir/tool.out" 2> "$rigScenarioDir/tool.err" )
}
rigPosts(){ ls "$rigScenarioDir"/post.* 2>/dev/null | wc -l | tr -d ' ' ; }
rigPostText(){ ## post number
	[ -f "$rigScenarioDir/post.${1:-1}" ] || return 0
	LC_ALL=C awk -v path=text -v optional=1 -f "$rigHere/harness/AgentsHarnessJsonField.awk" < "$rigScenarioDir/post.${1:-1}" 2>/dev/null
}

echo "-- 1. two pending and no declared count refuses, naming both numbers --"
rigScene count-mismatch
printf -- '- [ ] Fix the index\n- [ ] Run the suite\n' > "$rigList"
rigCall
rigAssert "the first call is refused" "$( LC_ALL=C sed -n '1s/:.*//p' "$rigScenarioDir/tool.out" )" "REFUSED"
rigAssert "and its line names both numbers" "$( LC_ALL=C sed -n '1p' "$rigScenarioDir/tool.out" )" \
	"REFUSED: the CheckList holds 2 pending item(s), and this call declares 0. Close them with CheckList, or declare 2 as checklist_pending_count to hand back with them listed as unfinished:"
rigAssert "with the items it names" "$( LC_ALL=C grep -c '^- \[ \] ' "$rigScenarioDir/tool.out" )" "2"
rigAssert "and nothing was posted" "$( rigPosts )" "0"

echo "-- 2. the same call declaring 2 passes on the first attempt, and carries both --"
rigScene declared
printf -- '- [ ] Fix the index\n- [ ] Run the suite\n' > "$rigList"
rigCall ',"checklist_pending_count":2'
rigAssert "declaring the count is not refused" "$( LC_ALL=C grep -c '^REFUSED: ' "$rigScenarioDir/tool.out" )" "0"
rigAssert "and it is posted" "$( rigPosts )" "1"
rigAssert "the handback carries both" "$( rigPostText | LC_ALL=C grep -c -e '^- \[ \] Fix the index$' -e '^- \[ \] Run the suite$' )" "2"

echo "-- 3. declaring 1 against 2 refuses --"
rigScene declared-short
printf -- '- [ ] Fix the index\n- [ ] Run the suite\n' > "$rigList"
rigCall ',"checklist_pending_count":1'
rigAssert "the short count is refused" "$( LC_ALL=C sed -n '1p' "$rigScenarioDir/tool.out" )" \
	"REFUSED: the CheckList holds 2 pending item(s), and this call declares 1. Close them with CheckList, or declare 2 as checklist_pending_count to hand back with them listed as unfinished:"
rigAssert "and nothing was posted" "$( rigPosts )" "0"

echo "-- 4. a list whose only pending item names the handback passes with 0, and the send closes it --"
rigScene handback-item
printf -- '- [x] Read the plan\n- [ ] Handback to the caller\n' > "$rigList"
rigCall
rigAssert "it is not refused" "$( LC_ALL=C grep -c '^REFUSED: ' "$rigScenarioDir/tool.out" )" "0"
rigAssert "and it is posted" "$( rigPosts )" "1"
rigAssert "the item is closed by the send" "$( LC_ALL=C grep -c '^- \[x\] Handback to the caller$' "$rigList" )" "1"

echo "-- 5. a list with only an item in progress passes with 0, and the item is not carried --"
rigScene in-progress
printf -- '- [x] Read the plan\n- [~] Run the suite\n' > "$rigList"
rigCall
rigAssert "it is not refused" "$( LC_ALL=C grep -c '^REFUSED: ' "$rigScenarioDir/tool.out" )" "0"
rigAssert "and it is posted" "$( rigPosts )" "1"
rigAssert "an item in progress is never carried" "$( rigPostText | LC_ALL=C grep -c 'Run the suite' )" "0"

echo "-- 6. a session that kept no list passes, and says so --"
rigScene no-list
rigCall
rigAssert "it is not refused" "$( LC_ALL=C grep -c '^REFUSED: ' "$rigScenarioDir/tool.out" )" "0"
rigAssert "and it is posted" "$( rigPosts )" "1"
rigAssert "the handback says no list was kept" "$( rigPostText | LC_ALL=C grep -c 'No CheckList was kept in this session.' )" "1"

echo "-- 7. a value that is not a whole number is an ERROR, and nothing is posted --"
rigScene not-a-number
printf -- '- [ ] Fix the index\n' > "$rigList"
rigCall ',"checklist_pending_count":"two"'
rigAssert "the call is an ERROR" "$( LC_ALL=C sed -n '1s/:.*//p' "$rigScenarioDir/tool.out" )" "ERROR"
rigAssert "and nothing was posted" "$( rigPosts )" "0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ HARNESS HANDBACK PENDING COUNT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_HANDBACK_PENDING_COUNT: OK (%d assertions, offline)\n' "$rigPassCount"
