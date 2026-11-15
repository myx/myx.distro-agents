#!/usr/bin/env bash
## rig-harness-text.include.sh: the universal harness as text, for the checks that read its code rather than run it. The code stands in the
## entry script and in the parts the entry sources (AgentsHarness<Part>.include of sh-lib/harness), so a check lifts a function from both.
## rigHarnessCat prints the entry and then each of those parts, in the order the entry sources them.
rigHarnessCat(){ ## origin (default: MDLT_ORIGIN)
	local catDir="${1:-${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}}/myx/myx.distro-agents/sh-lib/harness" catPart catQueue catSeen=" "
	cat "$catDir/AgentsUniversalHarness.sh" || return 1
	## A part sourced at the top (`. "..."` alone on its line), lazily (a stub function, or a load guard on the same line), or by
	## another part (the Ask parts, by AgentsHarnessAsk.include): each part is taken once, in the order its sourcing is met.
	catQueue="$( rigHarnessParts "$catDir/AgentsUniversalHarness.sh" )"
	while [ -n "$catQueue" ] ; do
		catPart="${catQueue%%$'\n'*}"
		if [ "$catPart" = "$catQueue" ] ; then catQueue="" ; else catQueue="${catQueue#*$'\n'}" ; fi
		[ -n "$catPart" ] || continue
		case "$catSeen" in *" $catPart "*) continue ;; esac
		catSeen="$catSeen$catPart "
		cat "$catDir/$catPart" || return 1
		catQueue="$catQueue${catQueue:+$'\n'}$( rigHarnessParts "$catDir/$catPart" )"
	done
}
## The harness parts one file sources, by name, in order.
rigHarnessParts(){ ## file
	LC_ALL=C sed -n -E 's#.*\. "\$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/(AgentsHarness(Display|Access|ToolsFile|ToolsBash|Search|Messages|Wait|Batch|Spawn|Reports|Ask[A-Za-z]*|McpResources|Skills|Run)\.include)".*#\1#p' "$1" \
		| LC_ALL=C awk '! seen[$0]++'
}
