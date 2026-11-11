#!/usr/bin/env bash
## Behavioural check on the harness's own record of a DISMISSED (AgentsHarnessDismissalChatRecord, sh-lib/harness/AgentsHarnessRun.include):
## one run of a member dismissing another run of that member, in one session, written into the session's chat file before it is posted.
## Held:
##   1. the record is a message delivered into the session: its conversation the session thread, origin `delivered`, both runs on its header
##   2. the addressed run's floor delivers it, and the Wait's dismissal match takes it as a dismissal of that run
##   3. the run that wrote it is not dismissed by it
##   4. in a session with no thread, the record goes on the session's printback channel, and the addressed run's floor delivers it too
## Red recipe: write the record under conversation `chat` and origin `own`, as before, and rows 2 and 4 fail: no floor delivers it.
## Offline: a rig workspace under this check's temp tree, no Slack.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPkg/sh-lib/harness/AgentsHarnessRun.include" ] || rigRefuse "the harness run include is not in the package"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessDismissalRecordCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigMember="magic-coordinator" rigAuthor="rig-run-author" rigTarget="rig-run-target"
rigPass=0 rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
## A rig workspace with one session, its two runs of the member recorded, and a thread or none.
rigScene(){ ## name, session thread (empty: none)
	rigWs="$rigTmp/$1/ws" rigSession="rig-session-$1"
	mkdir -p "$rigWs/.local/agents/sessions/$rigSession" "$rigWs/.local/agents/spawned/$rigTarget" "$rigWs/.local/temp"
	[ -z "$2" ] || printf '%s\n' "$2" > "$rigWs/.local/agents/sessions/$rigSession/session.thread"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nowner: %s\nstatus: spawn-started\n---\n' "$rigSession" "$rigTarget" "$rigMember" > "$rigWs/.local/agents/spawned/$rigTarget/$rigTarget.spawn.md"
}
## The record, written as the harness writes it when its member's run sends DISMISSED to its own member.
rigRecord(){
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SESSION_ID="$rigSession" MDAT_SPAWN_SESSION_ID="$rigAuthor" bash -c '
			harnessAgent="$1" harnessArgV_address_to="$1"
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SpawnSandbox.include" 2> /dev/null
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessRun.include"
			AgentsHarnessDismissalChatRecord' rig "$rigMember" ) > /dev/null 2>&1
}
## What the floor of one run of the member delivers, and whether the Wait's match takes it as that run's dismissal.
rigFloorOf(){ ## run
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SESSION_ID="$rigSession" MDAT_SPAWN_SESSION_ID="$1" bash -c '
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionChat.include"
			AgentsToolsSessionChatPointerSet "$2" "read:$3" 0 > /dev/null 2>&1
			AgentsToolsSessionChatFloor "$2" "$3" ""' rig "$1" "$rigSession" "$rigMember" ) 2> /dev/null
}
rigDismisses(){ ## run, floor text -> yes|no
	printf '%s\n' "$2" | dismissalMember="$rigMember" dismissalRun="$1" LC_ALL=C awk -f "$rigPkg/sh-lib/questions/AgentsDismissalMatch.awk" -f "$rigPkg/sh-lib/harness/AgentsHarnessWaitDismissed.awk" > /dev/null 2>&1 && echo yes || echo no
}
rigIndex(){ cat "$rigWs/.local/agents/sessions/$rigSession/session.chat.index" 2> /dev/null ; }

echo "-- 1. the record is a message delivered into the session --"
rigScene thread CRIGSES01:1000.000001
rigRecord
rigAssert "one block, its conversation the session thread and its origin delivered" "$( rigIndex | LC_ALL=C awk -F'\t' '{ print NR ":" $3 ":" $4 }' )" "1:CRIGSES01:1000.000001:delivered"
rigAssert "its header names both runs" "$( LC_ALL=C grep -c -F -e "[author-run=$rigAuthor]" "$rigWs/.local/agents/sessions/$rigSession/session.chat" ):$( LC_ALL=C grep -c -F -e "[addressee-run=$rigTarget]" "$rigWs/.local/agents/sessions/$rigSession/session.chat" )" "1:1"

echo "-- 2. the addressed run's floor delivers it, and it dismisses that run --"
rigFloor="$( rigFloorOf "$rigTarget" )"
rigAssert "the floor of the addressed run holds the DISMISSED" "$( printf '%s\n' "$rigFloor" | LC_ALL=C grep -c -x 'DISMISSED' )" "1"
rigAssert "and the Wait's match takes it as that run's dismissal" "$( rigDismisses "$rigTarget" "$rigFloor" )" "yes"

echo "-- 3. the run that wrote it is not dismissed by it --"
rigAssert "the author's own run is not dismissed" "$( rigDismisses "$rigAuthor" "$( rigFloorOf "$rigAuthor" )" )" "no"

echo "-- 4. a session with no thread: the printback channel --"
rigScene nothread ""
rigRecord
rigAssert "the record is on the session's printback channel" "$( rigIndex | LC_ALL=C awk -F'\t' '{ print $3 ":" $4 }' )" "printback:$rigSession:delivered"
rigFloor="$( rigFloorOf "$rigTarget" )"
rigAssert "and the addressed run's floor delivers it, as a dismissal" "$( printf '%s\n' "$rigFloor" | LC_ALL=C grep -c -x 'DISMISSED' ):$( rigDismisses "$rigTarget" "$rigFloor" )" "1:yes"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ HARNESS DISMISSAL RECORD CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_DISMISSAL_RECORD: OK (%d assertions, offline)\n' "$rigPass"
