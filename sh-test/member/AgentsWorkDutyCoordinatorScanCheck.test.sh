#!/usr/bin/env bash
## Behavioural check on what only magic-coordinator's work-duty scan carries (F7.12; --intern-op-work-duty-input-scan, and
## AgentsTools.ExternalOwnerItems.include): the items of the human-owner and of the external contacts that are due, and the open permission asks,
## found by script, with no agent. Held, run and not read, in a rig of this check's own:
##   1. THE SECTIONS stand in the scan of magic-coordinator and in no other member's: the external owners' items that are due, and the permission asks.
##   2. WHICH ITEMS: those of the coordinator's incoming/ and of the board's active states whose owner is the human-owner (an identity record) or a name
##      that is no member of the roster; not an item of a member, of the coordinator itself or of a state that is done (processed).
##   3. WHEN DUE: an item whose recheck-date has passed, or one that changed since the duty of the coordinator last started (the marker the schedule
##      keeps); one that waits for its owner, untouched and with a recheck-date ahead, is not due again.
##   4. NO MARKER (no duty has started yet): every such item is due. And a scan twice in a row reads the same (the wait of the duty watches it).
##   5. THE BOARD, for the rules of magic-coordinator.advance.routine, in the coordinator's scan and in no other member's: the items of the active states, the
##      review items, the registries, the items whose recheck-date has arrived (and not the ones ahead), and the dependencies as the tooling last computed them.
## Offline: a Slack-shaped fake curl first on PATH.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigTest="$rigOrigin/myx/myx.distro-agents/sh-test"
rigTool="$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWorkDutyCoordinatorScanCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigData="$rigTmp/data"
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigWs/.local/.agents" "$rigWs/.local/agents/sessions/rig-session" "$rigWs/.local/agents/schedule/duty" "$rigTmp/skills/magic-coordinator" "$rigTmp/skills/keeper-rig" "$rigTmp/skills/human-owner"
for rigMember in magic-coordinator keeper-rig ; do printf 'rig\n' > "$rigTmp/skills/$rigMember/$rigMember.basic.md" ; printf 'rig\n' > "$rigTmp/skills/$rigMember/$rigMember.armed.md" ; done
printf -- '---\nstatus: reference-only\n---\n# human-owner\n' > "$rigTmp/skills/human-owner/SKILL.md"
printf 'rig\n' > "$rigTmp/skills/human-owner/human-owner.basic.md"
cp "$rigTest/check-fixtures/work-duty.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nWAIT_COLLECT_SECONDS=1\n' > "$rigWs/.local/.agents/magic-team.agent.env"
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
rigHasRow(){ ## rows, item, owner, recheck, why -- how many lines are exactly that row
	printf '%s\n' "$1" | LC_ALL=C grep -c -x -F "$( printf '%s\t%s\t%s\t%s' "$2" "$3" "$4" "$5" )" || :
}
rigItem(){ ## folder below the data root, name, owner, recheck-date (may be empty), age: old|new
	mkdir -p "$rigData/$1"
	printf -- '---\ntype: task\nowner: %s\n%s---\n\n# rig\n' "$3" "${4:+recheck-date: $4$'\n'}" > "$rigData/$1/$2"
	[ "$5" != old ] || touch -t 202610010000 "$rigData/$1/$2"
}
rigScan(){ ## member -- the scan of that member
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_WAIT_REMIND=off MDAT_WAIT_POLL_SECONDS=1 perl -e 'alarm 120 ; exec @ARGV' bash "$rigTool" --intern-op-work-duty-input-scan "$1" --session-id rig-session 2> /dev/null < /dev/null )
}
rigSection(){ ## text -- the lines of the external owners' section
	printf '%s\n' "$1" | LC_ALL=C awk '/^## External owners/ { on = 1 ; next } /^## / { on = 0 } on && NF'
}
rigItem inboxes/magic-coordinator/incoming note-20261019T0100Z-rig-own.md magic-coordinator "" new
rigItem inboxes/magic-coordinator/incoming note-20261019T0101Z-rig-ext-new.md "human-owner" "" new
rigItem board/backlog task-20261019T0102Z-rig-ext-old.md human-owner "" old
rigItem board/backlog task-20261019T0103Z-rig-ext-recheck.md human-owner "2020-01-01 00:00 +0000" old
rigItem board/blocked approval-20261019T0104Z-rig-ext-future.md human-owner "2099-01-01 00:00 +0000" old
rigItem board/pending task-20261019T0105Z-rig-contact.md "contact:ndm-pm" "" new
rigItem board/running task-20261019T0106Z-rig-member.md keeper-rig "" new
rigItem board/processed task-20261019T0107Z-rig-done.md human-owner "" new
: > "$rigWs/.local/agents/schedule/duty/magic-coordinator"
touch -t 202610150000 "$rigWs/.local/agents/schedule/duty/magic-coordinator"
touch -t 202610010000 "$rigData/board/backlog/task-20261019T0102Z-rig-ext-old.md" "$rigData/board/backlog/task-20261019T0103Z-rig-ext-recheck.md" "$rigData/board/blocked/approval-20261019T0104Z-rig-ext-future.md"

echo "-- 1. the sections are the coordinator's --"
rigCoord="$( rigScan magic-coordinator )"
rigKeeper="$( rigScan keeper-rig )"
rigAssert "the coordinator's scan has the external owners' section and the permission asks" "$( printf '%s\n' "$rigCoord" | LC_ALL=C grep -c -e '^## External owners' -e '^## permission asks addressed to permission-escalation.routine' )" 2
rigAssert "a keeper's scan has neither" "$( printf '%s\n' "$rigKeeper" | LC_ALL=C grep -c -e '^## External owners' -e '^## permission asks' || : )" 0

echo "-- 2 and 3. which items, and when they are due --"
rigRows="$( rigSection "$rigCoord" )"
rigAssert "a new item of the human-owner in the coordinator's incoming/ is due, as changed" "$( rigHasRow "$rigRows" incoming/note-20261019T0101Z-rig-ext-new.md human-owner - changed )" 1
rigAssert "a board item of the human-owner whose recheck-date passed is due, as recheck-passed" "$( rigHasRow "$rigRows" backlog/task-20261019T0103Z-rig-ext-recheck.md human-owner '2020-01-01 00:00 +0000' recheck-passed )" 1
rigAssert "an item of an external contact that changed since the duty started is due" "$( rigHasRow "$rigRows" pending/task-20261019T0105Z-rig-contact.md contact:ndm-pm - changed )" 1
rigAssert "an old item that waits for its owner, with no recheck-date, is not due" "$( printf '%s\n' "$rigRows" | LC_ALL=C grep -c 'rig-ext-old' || : )" 0
rigAssert "one with a recheck-date ahead, untouched, is not due" "$( printf '%s\n' "$rigRows" | LC_ALL=C grep -c 'rig-ext-future' || : )" 0
rigAssert "an item of a member, one of the coordinator's own and one that is done are none of them listed" "$( printf '%s\n' "$rigRows" | LC_ALL=C grep -c -e 'rig-member' -e 'rig-own' -e 'rig-done' || : )" 0
rigAssert "three rows in all" "$( printf '%s\n' "$rigRows" | LC_ALL=C awk -F'\t' 'NF == 4' | wc -l | tr -d ' ' )" 3

echo "-- 4. no marker, and a scan twice --"
rm -f "$rigWs/.local/agents/schedule/duty/magic-coordinator"
rigAll="$( rigSection "$( rigScan magic-coordinator )" | LC_ALL=C awk -F'\t' 'NF == 4' | wc -l | tr -d ' ' )"
rigAssert "with no duty started yet, every such item is due: the five" "$rigAll" 5
rigAssert "a scan twice in a row reads the same (the external owners' and the asks' sections)" "$( rigScan magic-coordinator | LC_ALL=C awk '/^## External owners/ { on = 1 } /^## Slack/ { on = 0 } on' | cksum ):" "$( rigScan magic-coordinator | LC_ALL=C awk '/^## External owners/ { on = 1 } /^## Slack/ { on = 0 } on' | cksum ):"

echo "-- 5. the board sections --"
rigItem board/pending task-20261019T0108Z-rig-due.md keeper-rig "2020-01-01 00:00 +0000" old
rigCoord="$( rigScan magic-coordinator )"
rigKeeper="$( rigScan keeper-rig )"
rigAssert "the coordinator's scan has the board digest, the review items, the rechecks due and the dependencies" "$( printf '%s\n' "$rigCoord" | LC_ALL=C grep -c -x -e '## board digest' -e '## review items addressed to advance.routine' -e '## recheck dates due' -e '## board dependencies' -e '(none recomputed yet)' )" 5
rigAssert "a keeper's scan has none of them" "$( printf '%s\n' "$rigKeeper" | LC_ALL=C grep -c -e '^## board digest' -e '^## recheck dates due' -e '^## board dependencies' || : )" 0
rigDue="$( printf '%s\n' "$rigCoord" | LC_ALL=C awk '/^## recheck dates due/ { on = 1 ; next } /^## / { on = 0 } on && NF' )"
rigAssert "the recheck-date that has arrived is listed with its date, and the one ahead is not" "$( printf '%s\n' "$rigDue" | LC_ALL=C grep -c -x -F -e '- pending/task-20261019T0108Z-rig-due.md recheck-date 2020-01-01 00:00 +0000' ):$( printf '%s\n' "$rigDue" | LC_ALL=C grep -c -F 'rig-ext-future' || : )" "1:0"
rigAssert "the items of the active states are in the digest" "$( printf '%s\n' "$rigCoord" | LC_ALL=C grep -c -x -e '## running/task-20261019T0106Z-rig-member.md' -e '## pending/task-20261019T0105Z-rig-contact.md' -e '## blocked/approval-20261019T0104Z-rig-ext-future.md' )" 3
rm -f "$rigWs/.local/agents/board-dependencies.last"
printf '## board dependencies (recomputed 2026-10-20T10:00:00Z)\n\ncycles: none\n' > "$rigWs/.local/agents/board-dependencies.last"
rigAssert "the dependencies section is the report the tooling kept" "$( rigScan magic-coordinator | LC_ALL=C grep -c -x -F -e '## board dependencies (recomputed 2026-10-20T10:00:00Z)' )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WORK DUTY COORDINATOR SCAN CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WORK_DUTY_COORDINATOR_SCAN: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
