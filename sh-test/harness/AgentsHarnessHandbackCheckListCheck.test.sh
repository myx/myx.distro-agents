#!/usr/bin/env bash
## Behavioural check on what a handback does with the caller's own CheckList (owner 2026-10-31: members write a `Handback` step into
## the list, and the tool must neither break on it nor spend a round asking about it). Through the real SubagentHandback tool, a
## Slack-shaped fake curl that opens no socket, and the list the CheckList tool keeps. Held:
##   1. an item that names the handback is that step: it never refuses, and a delivered handback closes it
##   2. other open items, against a declared count that is not theirs, refuse and post nothing
##   3. the same call declaring that count passes and carries them as unfinished
##   4. a session that kept no list passes, and its handback says so
##   5. a delivered handback leaves the mark the idle Wait reads
## Holds 2 and 3 were the once-only refusal, replaced by the declared pending count (S22.1); the other three are unchanged.
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
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsHarnessHandbackCheckListCheck.XXXXXX" )" || exit 1
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
	LC_ALL=C awk -v path=text -v optional=1 -f "$rigHere/harness/AgentsHarnessJsonField.awk" < "$rigScenarioDir/post.${1:-1}" 2>/dev/null
}

echo "-- 1. an item naming the handback is that step, and a delivered handback closes it --"
rigScene handback-item
printf -- '- [x] Read the plan\n- [ ] Handback to the caller\n' > "$rigList"
rigCall
rigAssert "the handback is not refused" "$( LC_ALL=C grep -c '^REFUSED: ' "$rigScenarioDir/tool.out" )" "0"
rigAssert "and it is posted" "$( rigPosts )" "1"
rigAssert "the item is closed by the send" "$( LC_ALL=C grep -c '^- \[x\] Handback to the caller$' "$rigList" )" "1"
rigAssert "the mark the idle Wait reads is left" "$( [ -s "$rigScenarioDir/ws/.local/agents/spawned/child-folder/handback.given" ] && printf yes || printf no )" "yes"

echo "-- 2. other open items, against a declared count that is not theirs, refuse and post nothing --"
rigScene other-items
printf -- '- [ ] Fix the index\n- [ ] Run the suite\n' > "$rigList"
rigCall
rigAssert "the call is refused" "$( LC_ALL=C sed -n '1s/:.*//p' "$rigScenarioDir/tool.out" )" "REFUSED"
rigAssert "with the items it names" "$( LC_ALL=C grep -c '^- \[ \] ' "$rigScenarioDir/tool.out" )" "2"
rigAssert "and nothing was posted" "$( rigPosts )" "0"

echo "-- 3. the same call declaring that count passes, and carries them as unfinished --"
rigCall ',"checklist_pending_count":2'
rigAssert "the declared call is not refused" "$( LC_ALL=C grep -c '^REFUSED: ' "$rigScenarioDir/tool.out" )" "0"
rigAssert "and it is posted" "$( rigPosts )" "1"
rigAssert "the handback carries them" "$( rigPostText | LC_ALL=C grep -c -e '^- \[ \] Fix the index$' -e '^- \[ \] Run the suite$' )" "2"

echo "-- 4. a session that kept no list passes, and says so --"
rigScene no-list
rigCall
rigAssert "it is not refused" "$( LC_ALL=C grep -c '^REFUSED: ' "$rigScenarioDir/tool.out" )" "0"
rigAssert "and it is posted" "$( rigPosts )" "1"
rigAssert "the handback says no list was kept" "$( rigPostText | LC_ALL=C grep -c 'No CheckList was kept in this session.' )" "1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ HARNESS HANDBACK CHECKLIST CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_HANDBACK_CHECKLIST: OK (%d assertions, offline)\n' "$rigPassCount"
