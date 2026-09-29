#!/usr/bin/env bash
## Behavioural check on --magic-advance-input-scan, run rather than read, against a
## scenario board built here. Holds: one item placed in each active board state comes
## back as its own `## <state>/<item-filename>` row, except backlog, which is grooming's
## (the owner's "grooming reads backlog+inquiries+notes, advance does not"). Offline by construction.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigTool="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

## Refusing to report is this function's whole job: a rig that could not reach its
## subject must never reach its PASS lines, which read exactly like a result.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"

rigTmp="$( mktemp -d -t "AgentsAdvanceInputScanStatesCheck-XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws" "$rigTmp/home/.claude/skills/magic-coordinator" "$rigTmp/data/inboxes/magic-coordinator"
printf '# magic-coordinator\n' > "$rigTmp/home/.claude/skills/magic-coordinator/SKILL.md"
for rigState in backlog pending running blocked parked ; do
	mkdir -p "$rigTmp/data/board/$rigState"
	printf -- '---\ntype: task\nowner: magic-coordinator\n---\n\n# Rig item in %s\n' "$rigState" > "$rigTmp/data/board/$rigState/task-rig-$rigState.md"
done

rigOut="$( cd "$rigTmp/ws" && env -u MDAT_SKILLSET_ROOT HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigTmp/data" \
	bash "$rigTool" --magic-advance-input-scan magic-coordinator 2>/dev/null )" || rigRefuse "--magic-advance-input-scan magic-coordinator failed"

## The subject has to be reachable before anything is asserted about it.
printf '%s\n' "$rigOut" | grep -q '^## running/task-rig-running\.md$' || rigRefuse "the running item, which every revision scans, came back missing, so no state below would be measured"

rigFails=0 rigPasses=0
if printf '%s\n' "$rigOut" | grep -q '^## backlog/task-rig-backlog\.md$' ; then
	printf '  FAIL  the backlog item is in the scan, and backlog is grooming'"'"'s\n'
	rigFails=$(( rigFails + 1 ))
else
	printf '  PASS  the backlog item is not in the scan\n'
	rigPasses=$(( rigPasses + 1 ))
fi
for rigState in pending running blocked parked ; do
	if printf '%s\n' "$rigOut" | grep -q "^## $rigState/task-rig-$rigState\\.md\$" ; then
		printf '  PASS  the %s item comes back as a %s/ row\n' "$rigState" "$rigState"
		rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  the %s item is missing from the scan\n' "$rigState"
		rigFails=$(( rigFails + 1 ))
	fi
done

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ ADVANCE INPUT SCAN STATES CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) state(s)" >&2 ; exit 1
fi
printf 'ADVANCE_INPUT_SCAN_STATES: OK (%d states, offline)\n' "$rigPasses"