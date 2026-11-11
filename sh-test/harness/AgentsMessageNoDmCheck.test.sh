#!/usr/bin/env bash
## AgentsMessageNoDmCheck -- a member's message to another member never goes to a DM, which is the human-owner's own channel with that persona
## (a supervision handback to magic-coordinator landed in his personal conversation). With no live session of the target to reach, SendMessage
## puts the message in the target's inbox and makes no Slack call. A question that waits for its answer (no-inbox) keeps the DM. Held, run and
## not read: the tool function is sourced in a rig whose dispatcher is a stub that only records its arguments, so nothing can reach Slack.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents"
rigMessages="$rigPackage/sh-lib/harness/AgentsHarnessMessages.include"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigMessages" ] || rigRefuse "the harness messages file is not in the package: $rigMessages"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsMessageNoDmCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 )) ; else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
## A rig origin whose dispatcher records its arguments, and answers a send as a member with no DM would not be refused: ok.
mkdir -p "$rigTmp/origin/myx/myx.distro-agents/sh-scripts" "$rigTmp/ws/.local/agents" "$rigTmp/scratch" "$rigTmp/home"
cat > "$rigTmp/origin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$RIG_CALLS"
cat > /dev/null
exit 0
STUB
chmod +x "$rigTmp/origin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
## The messages include sources the session-pause include from the origin at load, so the stub origin carries a copy of it.
mkdir -p "$rigTmp/origin/myx/myx.distro-agents/sh-lib/session" || exit 1
cp "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionPause.include" "$rigTmp/origin/myx/myx.distro-agents/sh-lib/session/" || exit 1
rigSend(){ ## no-inbox (true or empty), result name
	: > "$rigTmp/calls"
	env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$rigTmp/origin" RIG_CALLS="$rigTmp/calls" RIG_SRC="$rigMessages" RIG_NOINBOX="$1" RIG_SCRATCH="$rigTmp/scratch" \
		bash -c '
			harnessAgent=keeper-rig harnessScratch="$RIG_SCRATCH" harnessCurrentName="" harnessParentName=""
			. "$RIG_SRC" 2> /dev/null
			AgentsHarnessToolSendMessageRun keeper-nobody "a note" "" "" "" "$RIG_NOINBOX" ""
		' > "$rigTmp/$2.out" 2>&1
}
rigSend "" inbox
rigAssert "a member to a member with no live session: no Slack send" "$( LC_ALL=C grep -c -e '--slack-send-message' "$rigTmp/calls" || : )" 0
rigAssert "it goes to the target's inbox" "$( LC_ALL=C grep -c -e '--upsert-inbox-inquiry keeper-nobody' "$rigTmp/calls" || : )" 1
rigAssert "and says why, naming the human-owner's DM as his" "$( LC_ALL=C grep -c "own channel of the human-owner" "$rigTmp/inbox.out" || : )" 1
rigSend true wait
rigAssert "a question that waits keeps the DM: one Slack send" "$( LC_ALL=C grep -c -e '--slack-send-message' "$rigTmp/calls" || : )" 1
if [ "$rigFail" -ne 0 ] ; then echo "⛔ MESSAGE NO DM CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1 ; fi
printf 'MESSAGE_NO_DM: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
