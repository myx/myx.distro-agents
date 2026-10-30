#!/usr/bin/env bash
## Behavioural check on the board-write identity gate (ban #2 of the librarian's ban sweep, sketch 3.1):
## magic-coordinator is the board's only writer, and the three board-write ops refuse any other resolved
## team member, before any board read or write. Held, run and not read:
##   1. A resolved OTHER team member (AgentsToolsTeamMember) is refused by each of the three ops, with a
##      refusal that names the owner and how to ask, and nothing is written.
##   2. magic-coordinator itself is not refused.
##   3. No identity at all, and a human console account (user-<account>), are not refused either: today's
##      existing bare-call convention, and a live session the human-owner confirms, both keep working.
## Run rather than read: a real team-rig workspace, through the real tool. Offline: no Slack, no network.
set -u
: "${MDAT_WORKSPACE_MODE:=team-rig}" ; export MDAT_WORKSPACE_MODE
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the team tooling is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsBoardWriteIdentityGateCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data" rigWs="$rigTmp/ws"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigScene(){ ## scenario name
	rm -rf "$rigWs" "$rigData"
	mkdir -p "$rigWs/.local/.agents" "$rigData/board/backlog" "$rigData/board/processed" "$rigData/inboxes/rig-member/incoming"
	printf -- '---\ndocument-contract: board-item.task\ntype: task\nfrom: rig-member\nowner: rig-member\ndate: 2026-10-20 04:00 +0300\n---\n\n# task: the thing\n\nbody of it\n' > "$rigData/board/backlog/task-20261020T0100Z-rig-old.md"
	printf 'RIG-INBOX-BODY' > "$rigData/inboxes/rig-member/incoming/note-20261020T0100Z-rig.md"
}
rigGate(){ ## team-member (empty for none), op...
	( env -u MDAT_TEAM_MEMBER -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u MDAT_SESSION_ID \
		${1:+MDAT_TEAM_MEMBER="$1"} MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		"$rigTool" "${@:2}" ) 2>&1
}
rigRefused(){ ## output -- yes when the gate's own refusal is in it
	case "$1" in *"magic-coordinator is the board"*"only writer"*) printf yes ;; *) printf no ;; esac
}

echo "-- 1. an agent-facing stub refuses a resolved other team member, names how to ask, writes nothing --"
rigScene stubs
rigAssert "move-to-processed: refused" "$( rigRefused "$( rigGate magic-librarian --move-to-processed task-20261020T0100Z-rig-old.md --from-state:backlog )" )" yes
rigAssert "grooming-to-pending: refused" "$( rigRefused "$( rigGate magic-architect --grooming-to-pending task-20261020T0100Z-rig-old.md --from-state:backlog )" )" yes
rigAssert "grooming-create-backlog: refused" "$( rigRefused "$( printf x | rigGate magic-librarian --grooming-create-backlog task-20261020T0100Z-rig-new.md )" )" yes
rigAssert "and nothing moved or made" "$( [ -f "$rigData/board/backlog/task-20261020T0100Z-rig-old.md" ] && [ ! -f "$rigData/board/processed/task-20261020T0100Z-rig-old.md" ] && [ ! -f "$rigData/board/backlog/task-20261020T0100Z-rig-new.md" ] && printf unchanged )" unchanged
rigAssert "and names how to ask" "$( rigGate magic-librarian --move-to-processed task-20261020T0100Z-rig-old.md --from-state:backlog | LC_ALL=C grep -c -F 'post-inquiry' )" 1

echo "-- 2. the internal operation decides no grant: the tooling's own write under a member's identity goes through --"
rigScene internal
rigAssert "intern-op-board-rename as a member: not refused" "$( rigRefused "$( rigGate magic-librarian --intern-op-board-rename task-20261020T0100Z-rig-old.md task-20261020T0100Z-rig-new.md )" )" no
rigAssert "and the rename went through" "$( [ -f "$rigData/board/backlog/task-20261020T0100Z-rig-new.md" ] && printf renamed )" renamed

echo "-- 3. magic-coordinator, no identity at all, and a human console account are not refused by a stub --"
for rigWho in magic-coordinator '' user-myx ; do
	rigScene "who-$rigWho"
	rigAssert "move-to-processed as '$rigWho': not refused" "$( rigRefused "$( rigGate "$rigWho" --move-to-processed task-20261020T0100Z-rig-old.md --from-state:backlog )" )" no
done

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ BOARD WRITE IDENTITY GATE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: a member other than magic-coordinator can still write the board, or a legitimate bare or console call is now refused" >&2
	echo "  fix:  repair the gate in the stubs, sh-lib/magic/AgentsTools.Magic{Board,Grooming}.include -- never the assertion" >&2
	exit 1
fi
printf 'BOARD_WRITE_IDENTITY_GATE: OK (%d assertions, offline)\n' "$rigPassCount"
