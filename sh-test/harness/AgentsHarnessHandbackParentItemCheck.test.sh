#!/usr/bin/env bash
## Behavioural check on a hand back over a mandatory CheckList item: one a parent gave the run (`parent`, S6.27) is
## still open, so its work is not done, and the hand back is refused rather than sent. Through the real SubagentHandback
## tool, a Slack-shaped fake curl that opens no socket, and the list the CheckList tool keeps. Held:
##   1. the seed marks its item `parent`, and the item is open
##   2. a hand back declaring that item's count is refused, and the refusal names the item
##   3. nothing is posted: a refusal leaves no message behind
##   4. the parent's item closed, the same call is sent -- the open parent item is the whole of the refusal
##   5. control: an open item of the member's own, declared, is not refused: the gate is the parent's item alone
## Red before the fix: 2 and 3 fail. The hand back refuses today on a declared count that is not the list's
## (`sh-lib/harness/AgentsHarnessReports.include`, the one count comparison), so a call that declares the parent
## item's count is sent with that work listed as unfinished and the refusal never names a `parent` item.
## Offline: a rig workspace, a fake curl, and a skillset of this rig's own; no network is reached.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPkg="${rigHere%/sh-lib}"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigSeed="$rigHere/session/AgentsTools.CheckListSeed.include"
rigTest="$rigPkg/sh-test"
rigMember="rig-helper"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigHarness" "$rigSeed" "$rigTest/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTest/check-fixtures/rig-temp.include.sh" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
## A call of this rig starts the workspace's own on-demand threads (the event-id thread of the comms cache), and a
## thread outlives the check that started it, so every one of them is ended before the tree is removed (T1905Z).
. "$rigTest/check-fixtures/rig-control-threads.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessHandbackParentItemCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigSkills="$rigTmp/skills"
rigScen="$rigTmp/scenario"
rigWs="$rigScen/ws"
rigThread="CSESS001:1700000002.000202"
mkdir -p "$rigSkills/$rigMember" "$rigSkills/magic-coordinator" "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned/child-folder" "$rigTmp/bin" "$rigTmp/home" || exit 1
printf '%s\n' "$rigMember" > "$rigSkills/$rigMember/$rigMember.basic.md"
printf 'magic-coordinator\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' \
	> "$rigWs/.local/.agents/magic-team.agent.env"
## The names registry the send reads: a handback that is not refused is posted, and a post to a member needs the
## member's row here (AgentsToolsCommsSlackPresentation).
printf '%s\n' 'magic-coordinator 🐭 Magic Vane dispatchr' "$rigMember 🔬 Vera Sharpe bugsniff" > "$rigWs/.local/agents/team-members-names.registry"
cp "$rigTest/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
## A `timeout` of the rig's own: with none on PATH the harness takes its watchdog branch, which leaves a `sleep`
## behind the check. With this one every hook is bounded and the check leaves nothing running.
printf '#!/bin/sh\nshift\nexec "$@"\n' > "$rigTmp/bin/timeout"
chmod +x "$rigTmp/bin/timeout"
PATH="$rigTmp/bin:/usr/bin:/bin"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"
## The fake curl's own log of the requests it answered, so no request of this rig leaves the machine unrecorded.
RIG_CURL_LOG="$rigScen/curl.log"
export RIG_CURL_LOG
: > "$RIG_CURL_LOG"
## The session's own record: its list is kept in the folder that holds it (AgentsHarnessCheckListPlace).
printf -- '---\nspawn-id: rig-child-id\nparent-spawn-id: none\nsession-thread: %s\nowner: %s\nreports-to: none\n---\n' "$rigThread" "$rigMember" \
	> "$rigWs/.local/agents/spawned/child-folder/rig-child-id.spawn.md"
rigList="$rigWs/.local/agents/spawned/child-folder/$rigMember.checklist.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## The seed the spawn runs before the run's first turn, so the marks on this list are the tooling's own.
rigSeedList(){ ## the item texts, one a line on standard input
	( cd "$rigWs" && env -u MDAT_DATA_ROOT -u MDAT_SESSION_ID HOME="$rigTmp/home" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash -c '. "$1" || exit 1 ; AgentsToolsCheckListSeed rig-child-id "$2" ""' rig "$rigSeed" "$rigMember" > /dev/null 2>&1 )
}
## One hand back as the run makes it: the other JSON fields, each leading with its own comma.
rigCall(){ ## the extra JSON fields
	: > "$rigScen/posts" 2>/dev/null || :
	rm -f "$rigScen"/post.* 2>/dev/null || :
	( cd "$rigWs" && printf '{"outcome":"the work is done"%s}' "${1:-}" | \
		env -u MDAT_DATA_ROOT -u MDAT_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		RIG_SCENARIO="$rigScen" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SESSION_THREAD="$rigThread" \
		MDAT_SPAWN_SESSION_ID=rig-child-id MDAT_SPAWN_AGENT="$rigMember" MDAT_SKILLSET_ROOT="$rigSkills" HOME="$rigTmp/home" \
		bash "$rigHarness" --intern-tool SubagentHandback > "$rigScen/tool.out" 2> "$rigScen/tool.err" )
}
rigOut(){ cat "$rigScen/tool.out" 2>/dev/null ; }
## How many lines of the answer are the tool's own refusal. A refusal is one line beginning `REFUSED: `.
rigRefused(){ LC_ALL=C grep -c '^REFUSED: ' "$rigScen/tool.out" 2>/dev/null ; }
## What the refusal says, from its first line on: the refusal names the items it refuses over.
rigRefusal(){ LC_ALL=C sed -n '/^REFUSED: /,$p' "$rigScen/tool.out" 2>/dev/null ; }
rigPosts(){ LC_ALL=C ls "$rigScen"/post.* 2>/dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ; }
rigItem(){ ## a text -- the list's line for it, or nothing
	[ -f "$rigList" ] || { printf 'no-list' ; return 0 ; }
	LC_ALL=C awk -v want="$1" 'index( $0, want ) { print ; exit ; }' "$rigList"
}

echo "-- 1. the seeded item is the parent's, and it is open --"
printf 'RIG-SEEDED-TASK\n' | rigSeedList
rigAssert "the seeded item is on the list, open"          "$( rigItem RIG-SEEDED-TASK )" "- [ ] RIG-SEEDED-TASK"
rigAssert "the seed marked it the parent's"               "$( LC_ALL=C grep -c -x -F -- "parent	RIG-SEEDED-TASK" "${rigList%.checklist.md}.checklist-sources.md" 2>/dev/null )" 1

echo "-- 2. the gate the fix must widen is here: the count alone is refused, nothing else is asked --"
## THE CONTROL FOR THE REFUSAL THAT FOLLOWS. The hand back refuses today on the declared count alone, so this call --
## declaring the one open item's count -- is refused for that reason and for no other. It proves the refusal surface
## works, so the next section's red is about the parent's item and not about a call that never reaches the tool.
rigCall ''
rigAssert "a count that is not the list's is refused"      "$( rigRefused )" "1"
rigAssert "and that refusal names the item it counted"     "$( rigRefusal | LC_ALL=C grep -c -F -- 'RIG-SEEDED-TASK' )" "1"
rigAssert "and nothing was posted"                         "$( rigPosts )" "0"

## THE MARKER IS NOT THIS CHECK'S TO CHOOSE. The refusal has to say that the item is the parent's, and the wording the
## fix picks is the architect's, so any of the words such a refusal carries is taken.
rigSaysParent(){ LC_ALL=C grep -c -i -E -e 'parent|mandatory|not yours to close' "$1" 2>/dev/null ; }

echo "-- 3 and 4. a hand back over that item is refused, names it, and posts nothing --"
rigCall ',"checklist_pending_count":1'
rigAssert "the call is refused"                            "$( rigRefused )" "1"
rigAssert "the refusal names the item it refuses over"     "$( rigRefusal | LC_ALL=C grep -c -F -- 'RIG-SEEDED-TASK' )" "1"
rigAssert "and says the item is the parent's, and so is not the run's to close" "$( rigRefusal | LC_ALL=C grep -c -i -E -e 'parent|mandatory|not yours to close' )" "1"
rigAssert "and nothing was posted"                         "$( rigPosts )" "0"

echo "-- 4. the parent's item closed, the same call is sent --"
printf -- '- [x] RIG-SEEDED-TASK\n' > "$rigList"
rigCall ',"checklist_pending_count":0'
rigAssert "the call is not refused"                        "$( rigRefused )" "0"
rigAssert "and it is posted"                               "$( rigPosts )" "1"

echo "-- 5. control: an open item of the member's own is not refused --"
printf -- '- [ ] RIG-OWN-ITEM\n' > "$rigList"
: > "${rigList%.checklist.md}.checklist-sources.md"
rigCall ',"checklist_pending_count":1'
rigAssert "the member's own open item is not a refusal"     "$( rigRefused )" "0"
rigAssert "so the call is posted, carrying it as unfinished" "$( rigPosts )" "1"
rigAssert "with no word of a parent item above it"          "$( rigSaysParent "$rigScen/tool.out" )" "0"


if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ HARNESS HANDBACK PARENT ITEM CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_HANDBACK_PARENT_ITEM: OK (%d assertions, offline)\n' "$rigPassCount"
