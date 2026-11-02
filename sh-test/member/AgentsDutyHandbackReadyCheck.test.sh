#!/usr/bin/env bash
## Behavioural check on S23.5: a pending handback addressed to the duty is a ready input. The work-duty scan lists the review items addressed to the member's duty
## (`review-by: <member>.work-duty.routine`) under `## Handbacks ready for the duty`, with `# ready: <N>`, and a Wait on `scan:work-duty` returns at once while a
## ready one is left: the duty takes its ready inputs, and a Wait that finds the report as it last gave it still returns where one stands (AgentsWaitProbeScan).
## Held, in steps through the real Wait and the real scan:
##   1. the first wait reads the report: RECEIVED, with no ready handback in it (`# ready: 0`)
##   2. read again, nothing changed: TIMEOUT (the control: a wait on an unchanged report must be able to idle)
##   3. a review item addressed to the duty appears: RECEIVED, with the item listed and `# ready: 1`
##   4. NOT TAKEN, the next wait returns at once again, with the same item: RECEIVED
##   5. an item addressed to another member's duty is no input of this one: the report is as before, and a wait on it idles once the ready one is taken
##   6. TAKEN (moved out of review): the report changes once (RECEIVED, `# ready: 0`), and the wait after it idles: TIMEOUT
## Offline: a Slack-shaped fake curl logs and answers any call; every tree is this rig's own; the collect window of the scan is one second.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="${rigHere%/sh-lib}/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigTest/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDutyHandbackReadyCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigW="$rigTmp/ws" rigD="$rigTmp/data" rigH="$rigTmp/home"
mkdir -p "$rigW/.local/.agents" "$rigW/.local/agents/spawned" "$rigW/.local/agents/members/magic-coordinator" "$rigD/inboxes/magic-coordinator/incoming" "$rigH"
rigCopyTree "${rigHere%/myx/myx.distro-agents/sh-lib}" "$rigW/source" || rigRefuse "the rig's source copy could not be made"
printf '# magic-coordinator\n' > "$rigW/.local/agents/members/magic-coordinator/SKILL.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nWAIT_COLLECT_SECONDS=1\n' > "$rigW/.local/.agents/magic-team.agent.env"
for rigState in pending running blocked parked review ; do
	mkdir -p "$rigD/board/$rigState"
done
rigReview(){ ## item stem, review-by -- a handback in review
	printf -- '---\ntype: dispatch\nowner: keeper-rig\nstatus: dispatch-review\nreview-by: %s\nreview-since-epoch: %s\n---\n\n# Rig handback\n' "$2" "$( date +%s )" > "$rigD/board/review/$1.md"
}
rigSession="rig-handback-ready-session" rigRun="rig-handback-ready-run"
rigWait(){ ## result name -- one Wait on the scan source, timeout 0, as a run of the team session
	local waitRc=0
	( cd "$rigW" && env -u MDAT_SKILLSET_ROOT -u CLAUDE_CODE_SESSION_ID HOME="$rigH" MMDAPP="$rigW" MDLT_ORIGIN="$rigW/source" MDAT_DATA_ROOT="$rigD" RIG_SCENARIO="$rigTmp" \
		MDAT_SESSION_ID="$rigSession" MDAT_SPAWN_SESSION_ID="$rigRun" MDAT_SPAWN_AGENT=magic-coordinator MDAT_WAIT_REMIND=off \
		python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 120 -- bash "$rigW/source/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --wait-for-input magic-coordinator --wait-source scan:work-duty --wait-timeout 0 ) > "$rigTmp/$1.out" 2> "$rigTmp/$1.err" < /dev/null 4> /dev/null || waitRc=$?
	printf '%s' "$waitRc" > "$rigTmp/$1.rc"
}
rigResult(){ ## result name -- the outcome word of its WAIT-RESULT line, or none
	local resultWord
	resultWord="$( LC_ALL=C sed -n 's/^WAIT-RESULT: \([A-Z]*\).*/\1/p' "$rigTmp/$1.out" | head -1 )"
	printf '%s' "${resultWord:-none}"
}
rigHolds(){ ## result name, text -- yes or no
	LC_ALL=C grep -q -F -e "$2" "$rigTmp/$1.out" && printf yes || printf no
}

rigSection(){ ## result name -- the lines of the report's `Handbacks ready for the duty` section (the board digest of a coordinator names every review item, so only that section tells whose they are)
	LC_ALL=C awk '/^## Handbacks ready for the duty/ { on = 1 ; next } on && /^## / { exit } on { print }' "$rigTmp/$1.out"
}

echo "-- 1. the first wait reads the report --"
rigWait w1
rigAssert "RECEIVED, with no ready handback" "$( rigResult w1 ):$( rigHolds w1 '# ready: 0' )" "RECEIVED:yes"
echo "-- 2. nothing changed: TIMEOUT --"
rigWait w2
rigAssert "the second read finds the report as it was" "$( rigResult w2 )" "TIMEOUT"
echo "-- 3. a handback addressed to the duty appears --"
rigReview dispatch-rig-ready magic-coordinator.work-duty.routine
rigWait w3
rigAssert "RECEIVED, with the item listed and one ready" "$( rigResult w3 ):$( rigHolds w3 'dispatch-rig-ready' ):$( rigHolds w3 '# ready: 1' )" "RECEIVED:yes:yes"
echo "-- 4. not taken: the next wait returns at once --"
rigWait w4
rigAssert "RECEIVED again, with the same item" "$( rigResult w4 ):$( rigHolds w4 'dispatch-rig-ready' )" "RECEIVED:yes"
echo "-- 5. another member's handback is no input of this duty --"
rigReview dispatch-rig-other keeper-other.work-duty.routine
rigWait w5
rigAssert "the section lists this duty's item and not the other's, with one ready" "$( rigSection w5 | LC_ALL=C grep -c 'dispatch-rig-ready' || : ):$( rigSection w5 | LC_ALL=C grep -c 'dispatch-rig-other' || : ):$( rigSection w5 | LC_ALL=C grep -c '# ready: 1' || : )" "1:0:1"
echo "-- 6. taken: the report changes once, then the wait idles --"
rm -f "$rigD/board/review/dispatch-rig-ready.md"
rigWait w6
rigAssert "RECEIVED once, with nothing ready" "$( rigResult w6 ):$( rigHolds w6 '# ready: 0' )" "RECEIVED:yes"
rigWait w7
rigAssert "and the wait after it idles" "$( rigResult w7 )" "TIMEOUT"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ DUTY HANDBACK READY CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'DUTY_HANDBACK_READY: OK (%d assertions, offline)\n' "$rigPassCount"
