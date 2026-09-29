#!/usr/bin/env bash
## 536: the per-send Slack log is best-effort. When its line cannot be appended the send
## says so once on stderr and its own result is unchanged -- a posted message still
## returns 0, a refused one still returns non-zero. The append is made to fail by
## putting a directory where the log file goes. Temp workspace only, the credential
## exposure rig's fake curl first on PATH, under one `env -i` guard.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
rigTmp="$( mktemp -d -t AgentsSlackSendLogAppendCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigTmp/bin" "$rigTmp/home" "$rigTmp/skills/magic-team" "$rigTmp/scenario"
cp "$rigHere/check-fixtures/credential-exposure-check.curl.test.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
rigSentinel="rig-sentinel-$$-TOKEN"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=%s\n' "$rigSentinel" > "$rigWs/.local/.agents/magic-team.agent.env"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigSend(){ ## mode (ok|fail), result file
	env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" TMPDIR="$rigWs/.local/temp" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		RIG_SCENARIO="$rigTmp/scenario" RIG_WS="$rigWs" RIG_MODE="$1" RIG_SENTINEL="$rigSentinel" RIG_SENTINEL_B64=none RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$( command -v curl )" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --member-comms-slack-send-message magic-team magic-team --identity-bot rig-body
		' > "$2" 2>&1
	printf '%s' "$?" > "$2.rc"
}
rigWarned(){ ## result file
	LC_ALL=C grep -c 'could not append this send.s outcome to' "$1" || :
}

echo "-- control: the log is writable --"
rigSend ok "$rigTmp/c"
LC_ALL=C grep -q 'chat.postMessage' "$rigTmp/scenario/argv.log" 2>/dev/null || rigRefuse "no send reached the fake curl: $( tail -3 "$rigTmp/c" )"
rigAssert "a send succeeds, rc 0"                      "$( cat "$rigTmp/c.rc" )" 0
rigAssert "with no append warning"                     "$( rigWarned "$rigTmp/c" )" 0
rigAssert "and its line is in the log"                 "$( LC_ALL=C awk 'END { print NR ; }' "$rigWs/.local/agents/comms-slack-send.log" )" 1

echo "-- the log cannot be appended --"
rm -f "$rigWs/.local/agents/comms-slack-send.log"
mkdir -p "$rigWs/.local/agents/comms-slack-send.log"
rigSend ok "$rigTmp/a"
rigAssert "a posted send still returns 0"              "$( cat "$rigTmp/a.rc" )" 0
rigAssert "and says once that its line was not kept"   "$( rigWarned "$rigTmp/a" )" 1
rigSend fail "$rigTmp/b"
rigAssert "a refused send still returns non-zero"      "$( [ "$( cat "$rigTmp/b.rc" )" != 0 ] && printf non-zero || printf zero )" non-zero
rigAssert "and says once that its line was not kept"   "$( rigWarned "$rigTmp/b" )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SLACK SEND LOG APPEND CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SLACK_SEND_LOG_APPEND: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
