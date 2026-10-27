#!/usr/bin/env bash
## rig-harness-text.include.sh: the universal harness as text, for the checks that read its code rather than run it. The code stands in the
## entry script and in the parts the entry sources (AgentsHarness<Part>.include of sh-lib/harness), so a check lifts a function from both.
## rigHarnessCat prints the entry and then each of those parts, in the order the entry sources them.
rigHarnessCat(){ ## origin (default: MDLT_ORIGIN)
	local catDir="${1:-${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}}/myx/myx.distro-agents/sh-lib/harness" catPart
	cat "$catDir/AgentsUniversalHarness.sh" || return 1
	LC_ALL=C sed -n -E 's#^\. "\$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/(AgentsHarness(Display|Access|ToolsFile|ToolsBash|Search|Messages|Wait|Batch|Spawn|Reports|Ask|McpResources|Skills|Run)\.include)"$#\1#p' "$catDir/AgentsUniversalHarness.sh" \
		| while IFS= read -r catPart ; do cat "$catDir/$catPart" || exit 1 ; done
}
