#!/usr/bin/env bash
## Behavioural check on each routine's input-scan scope, per the owner's "grooming reads
## backlog+inquiries+notes, advance does not": the advance scan returns pending, running,
## blocked and parked rows and no backlog; of the acting member's own inbox it returns notes
## only (the pending-slack-reaction and pending-trello-update records its comms step acts
## on), never inquiries or reflections, and no client-* inbox. The grooming scan returns
## backlog, the acting inbox's inquiries, reflections and notes, and each client-* inbox as
## an Additional Inbox group. The heartbeat scan returns no board rows. Offline: a temp data
## store, skillset root and workspace.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigTool="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
rigTmp="$( mktemp -d "${TMPDIR:-/tmp}/AgentsInputScanRoutineScopeCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigSkills="$rigTmp/home/.claude/skills"
mkdir -p "$rigTmp/ws" "$rigSkills/magic-coordinator" "$rigSkills/client-rig" \
	"$rigTmp/data/inboxes/magic-coordinator" "$rigTmp/data/inboxes/client-rig"
printf '# magic-coordinator\n' > "$rigSkills/magic-coordinator/SKILL.md"
printf '# client-rig\n' > "$rigSkills/client-rig/SKILL.md"
for rigState in backlog pending running blocked parked ; do
	mkdir -p "$rigTmp/data/board/$rigState"
	printf -- '---\ntype: task\nowner: magic-coordinator\n---\n\n# Rig item in %s\n' "$rigState" > "$rigTmp/data/board/$rigState/task-rig-$rigState.md"
done
rigInbox="$rigTmp/data/inboxes/magic-coordinator"
printf -- '---\ntype: note\n---\n\npending-slack-reaction rig record\n' > "$rigInbox/note-20260929T1000Z-pending-slack-reaction-rig.md"
printf -- '---\ntype: inquiry\nstatus: open\n---\n\nrig own inquiry\n' > "$rigInbox/inquiry-20260929T1000Z-rig-own.md"
printf -- '---\ntype: reflection\n---\n\nrig own reflection\n' > "$rigInbox/reflection-20260929T1000Z-rig-own.md"
printf -- '---\ntype: inquiry\nstatus: open\n---\n\nrig client inquiry\n' > "$rigTmp/data/inboxes/client-rig/inquiry-20260929T1000Z-rig-client.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigScan(){ ## op
	( cd "$rigTmp/ws" && env HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_DATA_ROOT="$rigTmp/data" \
		bash "$rigTool" "$1" magic-coordinator ) > "$rigTmp/out" 2> "$rigTmp/err" \
		|| rigRefuse "$1 failed: $( grep -v SetInputSpec "$rigTmp/err" | grep -m1 ERROR )"
}
rigHas(){ ## fixed string
	LC_ALL=C grep -q -F -- "$1" "$rigTmp/out" && printf yes || printf no
}
rigRow(){ ## state
	LC_ALL=C grep -q -x -- "## $1/task-rig-$1.md" "$rigTmp/out" && printf yes || printf no
}

echo "-- advance --"
rigScan --magic-advance-input-scan
[ "$( rigRow running )" = yes ] || rigRefuse "the running row, which every revision scans, is missing, so nothing below is measured"
for rigState in pending running blocked parked ; do
	rigAssert "the $rigState row is returned"            "$( rigRow $rigState )" yes
done
rigAssert "no backlog row"                               "$( rigRow backlog )" no
rigAssert "its own pending-slack-reaction note is returned" "$( rigHas 'pending-slack-reaction rig record' )" yes
rigAssert "no own inquiry"                               "$( rigHas 'rig own inquiry' )" no
rigAssert "no own reflection"                            "$( rigHas 'rig own reflection' )" no
rigAssert "no client-* inbox"                            "$( rigHas 'rig client inquiry' )" no

echo "-- grooming --"
rigScan --magic-grooming-input-scan
rigAssert "the backlog row is returned"                  "$( rigRow backlog )" yes
rigAssert "its own inquiry is returned"                  "$( rigHas 'rig own inquiry' )" yes
rigAssert "its own reflection is returned"               "$( rigHas 'rig own reflection' )" yes
rigAssert "its own note is returned"                     "$( rigHas 'pending-slack-reaction rig record' )" yes
rigAssert "the client-* inbox is an Additional Inbox"    "$( rigHas '## Additional Inbox -- client-rig' )" yes
rigAssert "with its inquiry"                             "$( rigHas 'rig client inquiry' )" yes

echo "-- heartbeat --"
rigScan --magic-heartbeat-input-scan
rigAssert "no board row"                                 "$( LC_ALL=C grep -c -E '^## (backlog|pending|running|blocked|parked)/' "$rigTmp/out" )" 0

echo "-- $rigPassCount passed, $rigFailCount failed --"
[ "$rigFailCount" -eq 0 ]
