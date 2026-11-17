#!/usr/bin/env bash
## Behavioural check on S21.20 item 20n: the team's tool floor is declared in two seats, and a check
## says so the moment they disagree. The code seat is the list `agentsPermissionFloorTools`; the
## origin seat is the `--magic-team:permissions:workspace:*:allow-tool:*:<tool>` rows of the declares
## of the workspace holding the tooling origin, read through the distro door by
## AgentsToolsPermissionOriginFloorTools.
##   1. the two seats name the same tools on this machine's origin, so the switch is one decision
##      later and never a surprise;
##   2. control: a workspace whose declares drop one tool is reported, by name;
##   3. control: a workspace whose declares add one tool is reported, by name;
##   4. the seat is read from the workspace's own source project, never from an installed copy of the
##      package under its `.local`. What it no longer covers: a `.local` package's declares are not
##      read at all, so an install whose declares differ from the source's is outside this check.
## Offline: every workspace here is a folder of this rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigHoldsInclude="$rigOrigin/myx/myx.distro-agents/sh-lib/grants/AgentsTools.PermissionHolds.include"
rigOriginInf="$rigOrigin/myx/myx.distro-agents/project.inf"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHoldsInclude" ] || rigRefuse "the holds model is not at the origin this workspace resolves: $rigHoldsInclude"
[ -f "$rigOriginInf" ] || rigRefuse "the origin package declares no project.inf: $rigOriginInf"

. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-distro-workspace.include.sh" || exit 1

mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsPermissionFloorSeatsCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
## The distro's own commands are reached through myx.common, as every rig of sh-test offers them.
PATH="$( rigDistroPath )" || rigRefuse "no myx.common on PATH, which the distro declares read needs" ; export PATH

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## The code seat, one tool a line, sorted.
rigCodeSeat(){
	LC_ALL=C sed -n 's/^agentsPermissionFloorTools=" *\(.*[^ ]\) *"$/\1/p' "$rigHoldsInclude" | LC_ALL=C tr -s ' ' '\n' | LC_ALL=C sort -u
}
## The origin seat as the code reads it, for a given workspace, one tool a line, sorted.
rigOriginSeat(){ ## workspace holding the tooling origin
	( export MMDAPP="$1"
	  bash -c '. "$1/myx/myx.distro-agents/sh-lib/grants/AgentsTools.PermissionHolds.include" ; AgentsToolsPermissionOriginFloorTools "$2" ; printf "%s" "$agentsPermissionOriginFloorTools"' _ "$rigOrigin" "$1" 2>/dev/null ) \
		| LC_ALL=C tr -s ' ' '\n' | LC_ALL=C grep . | LC_ALL=C sort -u
}
## What one seat names that the other does not: two lines, "<in the origin, not the code>" then
## "<in the code, not the origin>", each a space-separated list or empty.
rigDisagreement(){ ## workspace holding the tooling origin
	local originsSeat
	originsSeat="$( rigOriginSeat "$1" )"
	printf '%s\n%s\n' \
		"$( LC_ALL=C comm -23 <( printf '%s\n' "$originsSeat" ) <( rigCodeSeat ) | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ *$//' )" \
		"$( LC_ALL=C comm -13 <( printf '%s\n' "$originsSeat" ) <( rigCodeSeat ) | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ *$//' )"
}
## The Declares block of a project.inf, as a project of the rig carries it.
rigDeclares(){ ## project.inf path
	LC_ALL=C awk '/^Declares:/ { inBlock = 1 } inBlock && !/^Declares:/ && /^[A-Za-z]+:/ { exit } inBlock { print }' "$1"
}
## A workspace of this rig whose one source project is the tooling package, over the declares given:
## what the distro door reads, and nothing else of the workspace. Nothing is installed under its
## `.local`, so a row there is the case 4 subject alone.
rigWorkspace(){ ## case name, declares block
	local rigWs="$rigTmp/$1"
	mkdir -p "$rigWs/source/myx/myx.distro-agents" || return 1
	printf 'Name: myx\n' > "$rigWs/source/myx/repository.inf" || return 1
	printf 'Name: myx.distro-agents\n%s\n' "$2" > "$rigWs/source/myx/myx.distro-agents/project.inf" || return 1
	printf '%s' "$rigWs"
}

echo "-- 1. the two seats name the same tools --"
rigOriginWs="$( rigWorkspace origin "$( rigDeclares "$rigOriginInf" )" )" || rigRefuse "the origin's workspace could not be made"
rigAssert "nothing the origin names is missing from the code" "$( rigDisagreement "$rigOriginWs" | head -1 )" ""
rigAssert "and nothing the code names is missing from the origin" "$( rigDisagreement "$rigOriginWs" | tail -1 )" ""
rigAssert "control: the instrument sees a full seat, not two empty ones" "$( rigCodeSeat | LC_ALL=C grep -c . ):$( rigOriginSeat "$rigOriginWs" | LC_ALL=C grep -c . )" "20:20"

echo "-- 2. control: a workspace whose declares drop a tool is reported by name --"
rigDropped="$( rigWorkspace dropped "$( rigDeclares "$rigOriginInf" | LC_ALL=C awk '!/:Wait \\$/ { print }' )" )" || rigRefuse "the dropped tool's workspace could not be made"
rigAssert "the tool the origin no longer names is reported" "$( rigDisagreement "$rigDropped" | head -1 )" ""
rigAssert "and it is the one that was dropped" "$( rigDisagreement "$rigDropped" | tail -1 )" "Wait"

echo "-- 3. control: a workspace whose declares add a tool is reported by name --"
rigAdded="$( rigWorkspace added "$( rigDeclares "$rigOriginInf" | LC_ALL=C awk '{ print } /allow-tool:[*]:Skill \\$/ { print "\t--magic-team:permissions:workspace:*:allow-tool:*:RigExtraFloorTool \\" }' )" )" || rigRefuse "the added tool's workspace could not be made"
rigAssert "a tool the origin names and the code does not is reported" "$( rigDisagreement "$rigAdded" | head -1 )" "RigExtraFloorTool"
rigAssert "and nothing is reported the other way" "$( rigDisagreement "$rigAdded" | tail -1 )" ""

echo "-- 4. the seat is the workspace's own source project, never an installed copy under its .local --"
mkdir -p "$rigOriginWs/.local/myx/myx.distro-agents" || rigRefuse "the installed copy's folder could not be made"
printf 'Name: myx.distro-agents\n%s\n' "$( rigDeclares "$rigOriginInf" | LC_ALL=C awk '{ print } /allow-tool:[*]:Skill \\$/ { print "\t--magic-team:permissions:workspace:*:allow-tool:*:RigLocalOnlyTool \\" }' )" > "$rigOriginWs/.local/myx/myx.distro-agents/project.inf" || rigRefuse "the installed copy could not be written"
rigAssert "a row only an installed copy holds is not a floor tool" "$( rigOriginSeat "$rigOriginWs" | LC_ALL=C grep -c 'RigLocalOnlyTool' )" "0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PERMISSION FLOOR SEATS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: the tool floor's two seats disagree, so the switch cannot be made safely" >&2
	echo "  fix:  the declares of the origin's project.inf, or agentsPermissionFloorTools -- never the assertion" >&2
	exit 1
fi
printf 'PERMISSION_FLOOR_SEATS: OK (%d assertions, offline)\n' "$rigPassCount"
