#!/usr/bin/env bash
## Behavioural check on the apply-report gate at the handback (task-20261117T2241Z): a handback whose own words say a
## file was applied is refused unless it gives that file's absolute path and its read-back, and nothing is posted.
## Through the real SubagentHandback tool, with a Slack-shaped fake curl that opens no socket. Held:
##   1. control: a handback claiming no apply is posted
##   2. a handback naming a bare file and a line number is refused, names both faults, and posts nothing
##   3. a handback naming the absolute path with no read-back is refused, and names only that fault
##   4. a handback naming the path and its read-back is posted
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
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsApplyReportHandbackCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigTmp/skills/$rigMember"
printf '%s\n' "$rigMember" > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
cp "$rigTest/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
## A `timeout` of the rig's own: the harness takes its watchdog branch where none is on PATH, and that branch keeps a
## `sleep` behind. With this one the plain branch is taken, every hook is bounded, and the check leaves nothing running.
printf '#!/bin/sh\nshift\nexec "$@"\n' > "$rigTmp/bin/timeout"
chmod +x "$rigTmp/bin/timeout"
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
rigScenarioDir=""
rigScene(){ ## scenario directory name
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir/ws/.local/.agents" "$rigScenarioDir/ws/.local/agents/spawned/child-folder" "$rigScenarioDir/data" "$rigScenarioDir/scenario"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	RIG_CURL_LOG="$rigScenarioDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
	printf -- '---\nspawn-id: rig-child-id\nparent-spawn-id: none\nsession-thread: %s\nowner: %s\nreports-to: none\n---\n' "$rigCurrent" "$rigMember" \
		> "$rigScenarioDir/ws/.local/agents/spawned/child-folder/rig-child-id.spawn.md"
}
rigCall(){ ## the outcome, as the caller's own words
	( cd "$rigScenarioDir/ws" && RIG_OUTCOME="$1" && printf '{"outcome":"%s"}' "$RIG_OUTCOME" | \
		env -u MDAT_DATA_ROOT -u MDAT_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		-u MDAT_SKILLSET_ROOT RIG_SCENARIO="$rigScenarioDir/scenario" MMDAPP="$rigScenarioDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_DATA_ROOT="$rigScenarioDir/data" MDAT_SESSION_THREAD="$rigCurrent" MDAT_SPAWN_SESSION_ID=rig-child-id \
		MDAT_SPAWN_AGENT="$rigMember" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_CALLER_WAITS=true \
		bash "$rigHarness" --intern-tool SubagentHandback > "$rigScenarioDir/tool.out" 2> "$rigScenarioDir/tool.err" )
}
rigPosts(){ ls "$rigScenarioDir"/scenario/post.* 2>/dev/null | wc -l | tr -d ' ' ; }

echo "-- 1. control: a handback that claims no apply is posted --"
rigScene no-apply
rigCall "The checks pass and the notes are written."
rigAssert "not refused, and posted" "$( LC_ALL=C grep -c '^REFUSED: ' "$rigScenarioDir/tool.out" ):$( rigPosts )" "0:1"

echo "-- 2. a handback naming a bare file and a line number is refused --"
rigScene bare-name
rigCall "Applied the Show Detail fix in style.css.tpl:1314 and the checks pass."
rigAssert "refused and nothing posted" "$( LC_ALL=C sed -n '1s/:.*//p' "$rigScenarioDir/tool.out" ):$( rigPosts )" "REFUSED:0"
rigAssert "and it names both faults" \
	"$( LC_ALL=C grep -c -e '^applied-without-absolute-path: ' -e '^applied-without-read-back: ' "$rigScenarioDir/tool.out" )" "2"

echo "-- 3. the absolute path with no read-back is refused, and only that fault is named --"
rigScene no-readback
rigCall "Applied /Users/myx/Workspaces/ws-myx.ae3-devel/source/myx/style.css.tpl and the checks pass."
rigAssert "refused, one read-back fault, nothing posted" \
	"$( LC_ALL=C sed -n '1s/:.*//p' "$rigScenarioDir/tool.out" ):$( LC_ALL=C grep -c '^applied-without-absolute-path: ' "$rigScenarioDir/tool.out" ):$( LC_ALL=C grep -c '^applied-without-read-back: ' "$rigScenarioDir/tool.out" ):$( rigPosts )" "REFUSED:0:1:0"

echo "-- 4. the path and its read-back are posted --"
rigScene named
rigCall "Applied /Users/myx/Workspaces/ws-myx.ae3-devel/source/myx/style.css.tpl, cmp clean against the staged file."
rigAssert "not refused, and posted" "$( LC_ALL=C grep -c '^REFUSED: ' "$rigScenarioDir/tool.out" ):$( rigPosts )" "0:1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ APPLY REPORT HANDBACK CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'APPLY_REPORT_HANDBACK: OK (%d assertions, offline)\n' "$rigPassCount"
