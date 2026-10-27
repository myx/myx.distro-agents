#!/usr/bin/env bash
## Check that a vendor's own tool names appear only in that vendor harness's hooks, rejections and redirections (sketch 3.1): our harness, its tool
## descriptions and the tools that ask name only our own. Held, each as a count that must be 0:
##   1. the harness serves no call under the vendor's ask name: AskUserQuestion is an unknown tool to it, with nothing posted;
##   2. the code of the harness (comments aside) names no vendor tool: AskUserQuestion, TodoWrite;
##   3. the CheckList description in the wire declares no vendor tool;
##   4. the table of the tools that ask (AgentsTools.AskPost.include) holds no row of the vendor's name.
## Offline: one harness call with no session, a temp workspace, no Slack.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPack="$MDLT_ORIGIN/myx/myx.distro-agents"
rigHarness="$rigPack/sh-lib/harness/AgentsUniversalHarness.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigHarness" ] || rigRefuse "the harness is not at $rigHarness"
. "$rigPack/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessVendorNamesCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws/.local"
rigPass=0 rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigCode(){ ## file -- its lines that are no comment
	LC_ALL=C awk '$0 !~ /^[[:space:]]*#/' "$1"
}

echo "-- 1. the harness serves no call under the vendor's ask name --"
( cd "$rigTmp/ws" && printf '{"to":"human-owner","question":"x","wait":false}' | env -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID \
	MMDAPP="$rigTmp/ws" MDAT_SPAWN_AGENT=magic-tester MDAT_WORKSPACE_MODE=team-rig bash "$rigHarness" --intern-tool AskUserQuestion ) > "$rigTmp/out" 2> "$rigTmp/err"
rigAssert "the call is an unknown tool" "$( LC_ALL=C grep -c -F 'ERROR: unknown tool: AskUserQuestion' "$rigTmp/out" || : )" "1"
rigAssert "...and nothing was asked: no ask result, no pending record" "$( LC_ALL=C grep -c -E '^ASK-RESULT' "$rigTmp/out" || : ):$( ls "$rigTmp/ws/.local/agents/pending" 2> /dev/null | wc -l | tr -d ' ' )" "0:0"

echo "-- 2. the code of the harness names no vendor tool --"
for rigFile in sh-lib/harness/AgentsHarnessRun.include sh-lib/harness/AgentsHarnessBatch.include sh-lib/harness/AgentsHarnessAsk.include sh-lib/harness/AgentsUniversalHarness.sh ; do
	rigAssert "$rigFile: no AskUserQuestion, no TodoWrite" "$( rigCode "$rigPack/$rigFile" | LC_ALL=C grep -c -E 'AskUserQuestion|TodoWrite' || : )" "0"
done

echo "-- 3. the tool descriptions --"
rigAssert "the CheckList description names no vendor tool and no vendor" "$( LC_ALL=C grep -F '"name":"CheckList"' "$rigPack/sh-lib/harness/AgentsOpenAiChatWire.sh" | LC_ALL=C grep -c -E 'TodoWrite|Claude Code|AskUserQuestion' || : )" "0"
rigAssert "no description of a served tool names AskUserQuestion" "$( LC_ALL=C grep -c 'AskUserQuestion' "$rigPack/sh-lib/harness/AgentsOpenAiChatWire.sh" || : )" "0"

echo "-- 4. the tools that ask --"
rigAssert "the table of them holds no row of the vendor's name" "$( rigCode "$rigPack/sh-lib/questions/AgentsTools.AskPost.include" | LC_ALL=C grep -c -E '^AskUserQuestion\|' || : )" "0"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ HARNESS VENDOR NAMES CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_VENDOR_NAMES: OK (%d assertions, offline)\n' "$rigPass"
