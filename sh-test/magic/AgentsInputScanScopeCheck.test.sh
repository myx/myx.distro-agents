#!/usr/bin/env bash
## The scoped board sections emit no section unrelated to their routine: no comms, IM, Email, Trello or Other-Inbox heading,
## and no "not requested" line. They are the board digest, the review items and the registries that the rules of
## magic-team.advance.routine read (AgentsToolsBoardRoundSections, AgentsTools.BoardRoundScan.include). The advance scan is
## retired, and the work-duty scan prints these sections beside the inbox and Slack it reads by design, so the sections are run alone.
## The same scan op run with nothing declined is the control that emits them.
## Offline: a temp board, data root and HOME; no comms source is configured.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigTool="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsInputScanScopeCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws" "$rigTmp/home/.claude/skills/magic-coordinator" "$rigTmp/data/inboxes/magic-coordinator" "$rigTmp/data/board/running"
printf '# magic-coordinator\n' > "$rigTmp/home/.claude/skills/magic-coordinator/SKILL.md"
printf -- '---\ntype: task\nowner: magic-coordinator\n---\n\n# Rig item\n' > "$rigTmp/data/board/running/task-rig.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigRun(){ ## output file, op and its arguments
	local runOut="$1" ; shift
	( cd "$rigTmp/ws" && env -u MDAT_SKILLSET_ROOT HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigTmp/data" \
		bash "$rigTool" "$@" ) > "$runOut" 2>/dev/null
}
## Unrelated headings found, by line, and "not requested" lines.
rigUnrelated(){ ## output file
	LC_ALL=C grep -c -E '^(# New Incoming Communications|## Incoming IM Updates|## Incoming Email Updates|## Incoming Trello Updates|## Other Inbox Items)$' "$1" || :
}
rigNotRequested(){ ## output file
	LC_ALL=C grep -c -F '**NOTE:** not requested' "$1" || :
}

echo "-- the board sections of the work-duty scan --"
( cd "$rigTmp/ws" && env -u MDAT_SKILLSET_ROOT HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigTmp/data" bash -c '
	DistroAgentsTools(){ bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" "$@" ; }
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.Registries.include" || exit 1
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.BoardRoundScan.include" || exit 1
	AgentsToolsBoardRoundSections magic-coordinator --intern-op-work-duty-input-scan
' ) > "$rigTmp/board" 2> /dev/null
rigReach='## board digest'
LC_ALL=C grep -q -x -F -- "$rigReach" "$rigTmp/board" || rigRefuse "the board sections printed no '$rigReach', so their output was never reached"
LC_ALL=C grep -q -x -F -- '## running/task-rig.md' "$rigTmp/board" || rigRefuse "the board sections did not list the rig's running item, so the board was never read"
rigAssert "they emit no unrelated section heading"   "$( rigUnrelated "$rigTmp/board" )" 0
rigAssert "and no \"not requested\" line"            "$( rigNotRequested "$rigTmp/board" )" 0

echo "-- control: the scan op with nothing declined --"
rigRun "$rigTmp/control" --intern-op-session-context-scan magic-coordinator --all-types --do-inbox-notes
rigAssert "control: it emits all five unrelated headings" "$( rigUnrelated "$rigTmp/control" )" 5
rigAssert "control: and states them not requested"      "$( [ "$( rigNotRequested "$rigTmp/control" )" -gt 0 ] && printf yes || printf no )" yes

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ INPUT SCAN SCOPE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'INPUT_SCAN_SCOPE: OK (%d assertions, offline)\n' "$rigPassCount"
