#!/usr/bin/env bash
## Behavioural check on the `checklist:` source of a Wait (epic S13.9): the caller's own CheckList named as a source, so
## an item another session appended, or an item past its due time, wakes the run. Run against the real operation,
## offline: a fake curl refuses every request, and every source is a local file or the rig's own list.
## Held:
##   1. the kind is registered, listed by --wait-list-sources, and its probe is defined in the source
##   2. the control, both directions: a list that does not change times out, and the same wait returns on a line
##      appended to the list while it waits
##   3. an item past its due time is rendered first, so it arrives on its own line and before the rest
##   4. another member's list is refused, naming the rule
##   5. a session the tooling knows no place for is never-read, not silently empty
## NO FIXED SLEEP ANYWHERE, AND THE BASELINE IS THE STORED ONE. A first look at a non-empty-baseline source is its own
## baseline, so an append raced against a running call may land inside it: measured at 1 s it was inside and read as
## TIMEOUT, at 2 s it arrived. Each arrival row therefore stores the baseline with `--wait-default`, returns, appends, and
## reads with `--wait-continue`, which resumes from that stored baseline whatever the machine's speed.
## Red before S13.9: `checklist` is no kind the build registers. The listing omits it, and a session with no place for a
## list reads as a source that read fine rather than one that could not run. Measured 2 of 16 red on a tree whose kind
## list was cut back to the kinds before this item: the listing row and the never-read row.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigMdltOrigin="$MDLT_ORIGIN"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigOp="$rigPkg/sh-scripts/DistroAgentsSession.fn.sh"
rigInclude="$rigPkg/sh-lib/member/AgentsTools.MemberWait.include"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigOp" ] || rigRefuse "the wait operation is not at the origin: $rigOp"
[ -f "$rigInclude" ] || rigRefuse "the wait include is not at the origin: $rigInclude"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWaitChecklistSourceCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigMember="magic-developer"
rigSession="rig-cl-source"
rigFolder="$rigWs/.local/agents/sessions/$rigSession"
rigList="$rigFolder/$rigMember.checklist.md"
rigQuiet="$rigWs/quiet.txt"
mkdir -p "$rigFolder" "$rigWs/.local/.agents" "$rigWs/bin" || rigRefuse "the rig could not be made: $rigTmp"
printf 'SLACK_BOT_TOKEN=rig-bot-token\n' > "$rigWs/.local/.agents/magic-team.agent.env"
: > "$rigQuiet"
## A curl that fails at once: nothing this check does can reach a host.
printf '#!/bin/sh\nexit 22\n' > "$rigWs/bin/curl"
chmod +x "$rigWs/bin/curl"

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
rigHolds(){ ## text, a string -- yes where it holds it
	case "$1" in *"$2"*) printf yes ;; *) printf no ;; esac
}
## NO SESSION OF THE RUNNER'S OWN CROSSES, and no `MDAT_SESSION_ID` either: the wait reads the session it is told, and the
## probe places the list by that same session (`reflection-20261104T0427Z-rig-inherits-the-runners-session`).
## The operation's own answer is its STDOUT, and the marker has to open it; its diagnostics are stderr. The bootstrap
## line `SystemContext: ...` is neither, so it is dropped wherever the two are read together.
rigWait(){ ## the bound in seconds, then the operation's own arguments
	local waitBound="$1"
	shift
	( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SESSION_ID -u MDAT_SESSION_THREAD \
		-u MDAT_SPAWN_SANDBOX_ROOT -u MDAT_SPAWN_SANDBOX_ROOT_REAL MMDAPP="$rigWs" MDLT_ORIGIN="$rigMdltOrigin" \
		MDAT_WORKSPACE_MODE=just-agents MDAT_SPAWN_SESSION_ID="$rigSession" MDAT_WAIT_REMIND=off \
		PATH="$rigWs/bin:$PATH" bash "$rigOp" --wait-for-input --team-member "$rigMember" \
		--wait-session-id "$rigSession" --wait-timeout "$waitBound" --wait-poll-interval 1 "$@" 2> "$rigTmp/err" ) \
		| LC_ALL=C grep -v '^SystemContext: '
	LC_ALL=C grep -v '^SystemContext: ' "$rigTmp/err" 2> /dev/null || :
}

echo "-- 1. the kind is registered --"
rigOut="$( rigWait 1 --wait-list-sources )"
rigAssert "the listing offers the checklist kind" "$( rigHolds "$rigOut" 'checklist	AgentsWaitProbeChecklist' )" "yes"
rigAssert "and the probe it names is defined in the source" \
	"$( LC_ALL=C grep -c '^AgentsWaitProbeChecklist(){' "$rigPkg/sh-lib/member/AgentsTools.MemberWaitLocal.include" 2> /dev/null | LC_ALL=C tr -d ' ' )" "1"

## THE BASELINE IS THE STORED WAIT, NEVER THE CLOCK. A first look at a source with a non-empty baseline takes that look as
## the baseline and returns nothing, so an append made while a call is running races that first look: measured, an append
## at 1 s was inside the baseline and returned TIMEOUT, and one at 2 s arrived. So no row here sleeps between a write and a
## call. The `--wait-default` call STORES the baseline, the append happens after it has returned, and `--wait-continue`
## reads from that stored baseline. The quiet `--wait-continue` before each append is the control that the store landed.
echo "-- 2. the control, both directions --"
printf -- '- [ ] First\n' > "$rigList"
rigOut="$( rigWait 2 --wait-default --wait-source "checklist:$rigMember" )"
rigAssert "a first look only stores the baseline" "$( LC_ALL=C head -1 <<< "$rigOut" | LC_ALL=C sed 's/ (.*//' )" "WAIT-RESULT: TIMEOUT"
rigOut="$( rigWait 2 --wait-continue )"
rigAssert "and a list that does not change is a TIMEOUT" "$( LC_ALL=C head -1 <<< "$rigOut" | LC_ALL=C sed 's/ (.*//' )" "WAIT-RESULT: TIMEOUT"
printf -- '- [ ] Second\n' >> "$rigList"
rigOut="$( rigWait 5 --wait-continue )"
rigAssert "a line appended after the store is an arrival" "$( LC_ALL=C head -1 <<< "$rigOut" )" "WAIT-RESULT: RECEIVED"
rigAssert "and it names the source that fired" "$( rigHolds "$rigOut" 'arrived on: checklist:' )" "yes"
rigAssert "and carries the list as it now stands" \
	"$( LC_ALL=C grep -c -e 'First' -e 'Second' <<< "$rigOut" )" "2"
rigAssert "each open item on a line of its own kind" \
	"$( LC_ALL=C grep -c -e '^open	' <<< "$rigOut" )" "2"

echo "-- 3. an item past its due time is rendered first --"
printf -- '- [ ] Later still\n- [ ] Overdue (due: 2020-01-01 00:00 +0000)\n' > "$rigList"
rigOut="$( rigWait 2 --wait-default --wait-source "checklist:$rigMember" )"
rigAssert "a new list is an arrival on the stored baseline" "$( LC_ALL=C head -1 <<< "$rigOut" )" "WAIT-RESULT: RECEIVED"
rigOut="$( rigWait 2 --wait-continue )"
rigAssert "and the baseline has moved on, so a quiet continue waits" \
	"$( LC_ALL=C head -1 <<< "$rigOut" | LC_ALL=C sed 's/ (.*//' )" "WAIT-RESULT: TIMEOUT"
printf -- '- [ ] One more\n' >> "$rigList"
rigOut="$( rigWait 5 --wait-continue )"
rigAssert "the arrival carries the due item's line before the rest" \
	"$( LC_ALL=C awk '/^due\t/ { print "due-first" ; exit }' <<< "$rigOut" )" "due-first"
rigAssert "and the overdue item is in that line" \
	"$( LC_ALL=C grep -c -F -e 'due	- [ ] Overdue (due: 2020-01-01 00:00 +0000)' <<< "$rigOut" )" "1"
rigAssert "with the other open items after it" \
	"$( LC_ALL=C grep -c -e '^open	' <<< "$rigOut" )" "3"

echo "-- 4. another member's list is refused --"
rigOut="$( rigWait 1 --wait-source "checklist:magic-tester" )"
rigAssert "the call is refused at once, naming the rule" \
	"$( LC_ALL=C head -1 <<< "$rigOut" ) $( rigHolds "$rigOut" 'checklist:<own member name> is the own list only' )" "WAIT-RESULT: ERROR yes"

echo "-- 5. a session with no place for a list is never read, not read as empty --"
rigOut="$( env -u MDAT_SESSION_ID -u MDAT_SPAWN_SESSION_ID MMDAPP="$rigWs" MDLT_ORIGIN="$rigMdltOrigin" \
	MDAT_WORKSPACE_MODE=just-agents MDAT_WAIT_REMIND=off PATH="$rigWs/bin:$PATH" \
	bash "$rigOp" --wait-for-input --team-member "$rigMember" --wait-source "checklist:$rigMember" \
	--wait-timeout 3 --wait-poll-interval 1 2>&1 | LC_ALL=C grep -v '^SystemContext: ' )"
rigAssert "the wait names the source never read" "$( rigHolds "$rigOut" 'WAIT-NEVER-READ: [checklist:' )" "yes"
rigAssert "and says the probe could not run" "$( rigHolds "$rigOut" 'probes that could not run this wait' )" "yes"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ WAIT CHECKLIST SOURCE CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_CHECKLIST_SOURCE: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
