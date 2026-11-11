#!/usr/bin/env bash
## Behavioural check on the console's leg lookup, `DagcLegFileFor` of sh-lib/manager/AgentsConsoleShellScript.template.sh (board task
## 20261106T1930Z, the CLI spellings): the leg table names a leg by its file lowercased, `standardv1`, while the CLI services list and
## `--spawn-cli-service` say `standard-v1`, the service's own name, which a preset names as its service. Held, with the function taken from
## the template as it is and a table of this check's own:
##   1. the file's own spelling finds the leg.
##   2. the service's spelling, with the hyphen, finds the same leg.
##   3. a name that is no leg finds nothing, and a vendor CLI's name is refused ahead of the table.
##   4. a hyphen never makes two legs one: `claude` does not find a leg named `cla-ude`'s neighbour by accident, since both sides lose their hyphens alike.
## Red before the change: row 2 fails, the lookup compared the names as written.
## Offline: no console is generated and nothing is started.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigTemplate="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsConsoleShellScript.template.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTemplate" ] || rigRefuse "the console template is not at the origin: $rigTemplate"
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## The function as the template holds it, and nothing else of the template.
rigFunction="$( LC_ALL=C sed -n '/^DagcLegFileFor(){/,/^}/p' "$rigTemplate" )"
[ -n "$rigFunction" ] || rigRefuse "DagcLegFileFor is not in the template"
eval "$rigFunction"
DAGC_VENDOR_CLIS="copilot-native claude-native grok-native"
DAGC_LEG_TABLE="claude
/rig/legs/AgentsClaudeHarness.sh
standardv1
/rig/legs/AgentsStandardV1Harness.sh
deepseek
/rig/legs/AgentsDeepseekHarness.sh
"
rigFound(){ DagcLegFileFor "$1" 2> /dev/null || printf 'none' ; }

echo "-- 1. the file's spelling --"
rigAssert "standardv1 finds its leg" "$( rigFound standardv1 )" "/rig/legs/AgentsStandardV1Harness.sh"
echo "-- 2. the service's spelling --"
rigAssert "standard-v1 finds the same leg" "$( rigFound standard-v1 )" "/rig/legs/AgentsStandardV1Harness.sh"
echo "-- 3. no leg, and a vendor name --"
rigAssert "a name that is no leg finds nothing" "$( rigFound gemini )" "none"
rigAssert "a vendor CLI's name is refused ahead of the table" "$( rigFound claude-native )" "none"
echo "-- 4. a plain name still finds its own leg alone --"
rigAssert "claude finds the claude leg" "$( rigFound claude )" "/rig/legs/AgentsClaudeHarness.sh"
rigAssert "deep-seek finds the deepseek leg, the same rule" "$( rigFound deep-seek )" "/rig/legs/AgentsDeepseekHarness.sh"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ CONSOLE LEG SPELLING CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	exit 1
fi
echo "CONSOLE_LEG_SPELLING: OK ($rigPassCount assertions, offline)"
