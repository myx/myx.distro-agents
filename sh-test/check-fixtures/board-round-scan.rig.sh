#!/usr/bin/env bash
## The board sections of a scan, run on their own, for the checks of the board's states (AgentsAdvanceInputScanStatesCheck and its kin): what the coordinator's
## work-duty scan prints of the board (sh-lib/board/AgentsTools.BoardRoundScan.include, AgentsToolsBoardRoundSections), without the Slack collect and the inbox
## around it. The advance scan that used to carry them alone is retired (F7.12); no tool operation prints these sections alone, so the check runs the function the
## scan runs, in the tooling's own shell (--intern-mcp-execute), in the environment it is called in.
## Usage: bash board-round-scan.rig.sh <DistroAgentsTools.fn.sh> <team-member>   -- the sections on stdout, what the shell said on stderr, its exit code
set -u
rigTool="${1:?usage: board-round-scan.rig.sh <DistroAgentsTools.fn.sh> <team-member>}"
rigMember="${2:?usage: board-round-scan.rig.sh <DistroAgentsTools.fn.sh> <team-member>}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
printf '%s\n' \
	". \"$rigLib/team-data/AgentsTools.Registries.include\"" \
	". \"$rigLib/session/AgentsTools.SpawnSandbox.include\"" \
	". \"$rigLib/board/AgentsTools.RecheckDate.include\"" \
	". \"$rigLib/board/AgentsTools.BoardRoundScan.include\"" \
	"AgentsToolsBoardRoundSections $rigMember board-round-scan-rig" \
	| bash "$rigTool" --intern-mcp-execute
