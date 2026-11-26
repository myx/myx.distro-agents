#!/usr/bin/env bash
## Behavioural check on the restart's join of a session that has no thread (sh-lib/board/AgentsTools.ReviewFlow.include,
## AgentsReviewRestart): the restart offers the session id it is asked to resume, whatever the founding record carries, so a
## session is joined by its id and not by its thread. Held, run rather than read:
##   1. NO-THREAD RECORD, THE SESSION IS STILL PASSED: the spawn args carry `--session-id <session>`.
##   2. THE CONTROL: the same call without a session id carries none, so row 1 is about the session id alone.
## RED RECIPE, measured 2026-11-25 23:40 +0200 against the pre-change flow: the no-thread branch dropped the resume and
## called the spawn with no --session-id, and the live restart of session 00569208 answered with a brand-new session
## 8b066c82 instead of joining. With the old file row 1 fails (no session id in the args).
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigInclude="$rigPackage/sh-lib/board/AgentsTools.ReviewFlow.include"
[ -f "$rigInclude" ] || { echo "⛔ ERROR: no $rigInclude" >&2 ; exit 1 ; }
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsReviewRestartJoinCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
rigSid="rig-session"
mkdir -p "$rigWs/.local/agents/spawned/$rigSid" "$rigWs/.local/agents/sessions/$rigSid" \
	"$rigData/board/running" "$rigData/vault" "$rigData/inboxes/rig-member/incoming" || exit 1
printf -- '---\nspawn-id: %s\nsession-id: %s\nowner: rig-member\nstatus: spawn-failed\n---\n' "$rigSid" "$rigSid" \
	> "$rigWs/.local/agents/spawned/$rigSid/$rigSid.spawn.md" || exit 1
printf -- '---\ntype: task\nowner: rig-member\n---\n\n# rig task\n' > "$rigData/board/running/task-rig-restart.md" || exit 1
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}
## The spawn is a recorder: the real proxy is never started, and the args it would have taken are printed.
rigRestartCall(){ ## the record to restart
	rigArgsFile="$rigTmp/args.$$"
	: > "$rigArgsFile"
	MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigData" RIG_ARGS_FILE="$rigArgsFile" bash -c '
		. "$1" || exit 9
		AgentsReviewTools(){ printf "%s\n" "$*" >> "$RIG_ARGS_FILE" ; printf "RETURN: restarted rig-member on task-rig-restart.md\n" ; }
		AgentsReviewRecord(){ return 0 ; }
		AgentsReviewRestart task-rig-restart.md "$2" "" rig-tester
	' rig-restart "$rigInclude" "$1" > /dev/null 2>&1
	cat "$rigArgsFile"
}
echo "-- 1. no-thread record, the session is still passed --"
printf -- '---\nspawn-id: %s\nsession-id: %s\nowner: rig-member\nstatus: spawn-failed\n---\n' "$rigSid" "$rigSid" \
	> "$rigWs/.local/agents/spawned/$rigSid/$rigSid.spawn.md"
rigArgs="$( rigRestartCall "$rigWs/.local/agents/spawned/$rigSid/$rigSid.spawn.md" )"
rigAssert "the spawn args carry the session id" "$( printf '%s\n' "$rigArgs" | LC_ALL=C grep -c -- "--session-id $rigSid" )" "1"
rigAssert "and the record carried no thread" "$( LC_ALL=C grep -c '^session-thread:' "$rigWs/.local/agents/spawned/$rigSid/$rigSid.spawn.md" )" "0"
echo "-- 2. the control: a record that names another session passes that one --"
rigSid2="rig-session-b"
mkdir -p "$rigWs/.local/agents/spawned/$rigSid2" "$rigWs/.local/agents/sessions/$rigSid2"
printf -- '---\nspawn-id: %s\nsession-id: %s\nowner: rig-member\nstatus: spawn-failed\n---\n' "$rigSid2" "$rigSid2" \
	> "$rigWs/.local/agents/spawned/$rigSid2/$rigSid2.spawn.md"
rigArgs2="$( rigRestartCall "$rigWs/.local/agents/spawned/$rigSid2/$rigSid2.spawn.md" )"
rigAssert "the second session is the one passed" "$( printf '%s\n' "$rigArgs2" | LC_ALL=C grep -c -- "--session-id $rigSid2" )" "1"
if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ REVIEW RESTART JOIN CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'REVIEW_RESTART_JOIN: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
