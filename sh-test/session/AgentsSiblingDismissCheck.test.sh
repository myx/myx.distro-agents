#!/usr/bin/env bash
## Behavioural check on S27.8: a DISMISSED reaches its run within the Wait's check interval, also when
## the dismisser is another run of the same member.
## Red before S27.8: `dismissalOf` ignored every dismissal whose author was the waiting member, and
## nothing recorded which run wrote one, so a sibling run's dismissal read as the member's own.
## Offline: the inputs are hand-built lines in this rig's own folder. No socket, no Slack.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPkg="${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}/myx/myx.distro-agents"
rigMatch="$rigPkg/sh-lib/questions/AgentsDismissalMatch.awk"
rigWaitDismissed="$rigPkg/sh-lib/harness/AgentsHarnessWaitDismissed.awk"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigMatch" ] || rigRefuse "the dismissal matcher is not at the origin: $rigMatch"
mkdir -p "$MMDAPP/.local/temp"
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsSiblingDismissCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
rigVerdict(){ ## one rendered message -- 1 or 0 for magic-developer
	RIGMSG="$1" LC_ALL=C awk -f "$rigMatch" -f "$rigTmp/verdict.awk" /dev/null
}
cat > "$rigTmp/verdict.awk" <<'RIGAWK'
BEGIN { print dismissalOf( ENVIRON["RIGMSG"], "magic-developer" ) ; }
RIGAWK

echo "-- 1. the two runs decide the author's own case, and a run never dismisses itself (S27.8) --"
rigSibling="1793000000.000100 | U0BOT | [author-run: run-a] [addressee-run: run-b] [sender: magic-developer] *_magic-developer_* @lexr → *_magic-developer_* @lexr. DISMISSED"
rigSelf="1793000000.000100 | U0BOT | [author-run: run-a] [addressee-run: run-a] [sender: magic-developer] *_magic-developer_* @lexr → *_magic-developer_* @lexr. DISMISSED"
rigOther="1793000000.000100 | U0BOT | [sender: magic-tester] *_magic-tester_* @tst → *_magic-developer_* @lexr. DISMISSED"
rigPlain="1793000000.000100 | U0BOT | [sender: magic-developer] *_magic-developer_* @lexr → *_magic-developer_* @lexr. DISMISSED"
rigAssert "a sibling run's dismissal counts"              "$( rigVerdict "$rigSibling" )" 1
rigAssert "a run's own dismissal does not count"          "$( rigVerdict "$rigSelf" )" 0
rigAssert "another member's dismissal still counts"       "$( rigVerdict "$rigOther" )" 1
rigAssert "a same-member dismissal with no run ids is unchanged" "$( rigVerdict "$rigPlain" )" 0

echo "-- 2. the chat entry the tooling writes carries both runs (S27.8) --"
rigChat="2026-11-02T03:30:00Z magic-developer [author-run=run-a] -> magic-developer [addressee-run=run-b]:
DISMISSED"
rigChatSelf="2026-11-02T03:30:00Z magic-developer [author-run=run-a] -> magic-developer [addressee-run=run-a]:
DISMISSED"
rigAssert "the chat route reads a sibling run's dismissal" "$( printf '%s\n' "$rigChat" | dismissalMember=magic-developer LC_ALL=C awk -f "$rigMatch" -f "$rigWaitDismissed" | wc -l | tr -d ' ' )" 1
rigAssert "and not the run's own"                          "$( printf '%s\n' "$rigChatSelf" | dismissalMember=magic-developer LC_ALL=C awk -f "$rigMatch" -f "$rigWaitDismissed" | wc -l | tr -d ' ' )" 0

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SIBLING DISMISS CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'SIBLING_DISMISS: OK (%d assertions, offline)\n' "$rigPass"
