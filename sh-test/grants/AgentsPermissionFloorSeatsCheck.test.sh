#!/usr/bin/env bash
## Behavioural check on S21.20 item 20n: the team's tool floor is declared in two seats, and a check
## says so the moment they disagree. The code seat is the list `agentsPermissionFloorTools`; the
## origin seat is the `--magic-team:permissions:workspace:*:allow-tool:*:<tool>` rows of the tooling
## origin's own project.inf, read by AgentsToolsPermissionOriginFloorTools.
##   1. the two seats name the same tools on this machine's origin, so the switch is one decision
##      later and never a surprise;
##   2. control: an origin whose declares drop one tool is reported, by name;
##   3. control: an origin whose declares add one tool is reported, by name;
##   4. the seat the code reads is the origin's project.inf, never a `.local` copy of the package.
## Offline: every origin here is a folder of this rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigHoldsInclude="$rigOrigin/myx/myx.distro-agents/sh-lib/grants/AgentsTools.PermissionHolds.include"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHoldsInclude" ] || rigRefuse "the holds model is not at the origin this workspace resolves: $rigHoldsInclude"

mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsPermissionFloorSeatsCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

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
## The origin seat as the code reads it, for a given origin root, one tool a line, sorted.
rigOriginSeat(){ ## origin root
	MDLT_ORIGIN="$1" bash -c '. "$1/myx/myx.distro-agents/sh-lib/grants/AgentsTools.PermissionHolds.include" ; AgentsToolsPermissionOriginFloorTools ; printf "%s" "$agentsPermissionOriginFloorTools"' _ "$1" 2>/dev/null \
		| LC_ALL=C tr -s ' ' '\n' | LC_ALL=C grep . | LC_ALL=C sort -u
}
## What one seat names that the other does not: two lines, "<in the origin, not the code>" then
## "<in the code, not the origin>", each a space-separated list or empty.
rigDisagreement(){ ## origin root
	local originsSeat
	originsSeat="$( rigOriginSeat "$1" )"
	printf '%s\n%s\n' \
		"$( LC_ALL=C comm -23 <( printf '%s\n' "$originsSeat" ) <( rigCodeSeat ) | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ *$//' )" \
		"$( LC_ALL=C comm -13 <( printf '%s\n' "$originsSeat" ) <( rigCodeSeat ) | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ *$//' )"
}
## A scratch origin carrying the two files the seat is read from, with its declares as this check
## says: the package's project.inf, and the holds model that reads it.
rigScratchOrigin(){ ## case name, an awk program editing the star tool rows
	local scratch="$rigTmp/$1"
	mkdir -p "$scratch/myx/myx.distro-agents/sh-lib/grants"
	cp -p "$rigHoldsInclude" "$scratch/myx/myx.distro-agents/sh-lib/grants/AgentsTools.PermissionHolds.include" || rigRefuse "the holds model could not be copied into $scratch"
	LC_ALL=C awk "$2" "$rigOrigin/myx/myx.distro-agents/project.inf" > "$scratch/myx/myx.distro-agents/project.inf" || rigRefuse "the declares of case $1 could not be built"
	printf '%s' "$scratch"
}

echo "-- 1. the two seats name the same tools --"
rigAssert "nothing the origin names is missing from the code" "$( rigDisagreement "$rigOrigin" | head -1 )" ""
rigAssert "and nothing the code names is missing from the origin" "$( rigDisagreement "$rigOrigin" | tail -1 )" ""
rigAssert "control: the instrument sees a full seat, not two empty ones" "$( rigCodeSeat | LC_ALL=C grep -c . ):$( rigOriginSeat "$rigOrigin" | LC_ALL=C grep -c . )" "20:20"

echo "-- 2. control: an origin whose declares drop a tool is reported by name --"
rigDropped="$( rigScratchOrigin dropped '/:Wait \\$/ { next } { print }' )"
rigAssert "the tool the origin no longer names is reported" "$( rigDisagreement "$rigDropped" | head -1 )" ""
rigAssert "and it is the one that was dropped" "$( rigDisagreement "$rigDropped" | tail -1 )" "Wait"

echo "-- 3. control: an origin whose declares add a tool is reported by name --"
rigAdded="$( rigScratchOrigin added '{ print } END { print "\t--magic-team:permissions:workspace:*:allow-tool:*:RigExtraFloorTool \\" }' )"
rigAssert "a tool the origin names and the code does not is reported" "$( rigDisagreement "$rigAdded" | head -1 )" "RigExtraFloorTool"
rigAssert "and nothing is reported the other way" "$( rigDisagreement "$rigAdded" | tail -1 )" ""

echo "-- 4. the seat read is the origin's project.inf, never a .local copy --"
rigLocalCopy="$( rigScratchOrigin localcopy '{ print }' )"
mkdir -p "$rigLocalCopy/myx/myx.distro-agents/.local"
printf '\t--magic-team:permissions:workspace:*:allow-tool:*:RigLocalOnlyTool \\\n' >> "$rigLocalCopy/myx/myx.distro-agents/.local/project.inf"
rigAssert "a row only a .local copy holds is not a floor tool" "$( rigOriginSeat "$rigLocalCopy" | LC_ALL=C grep -c 'RigLocalOnlyTool' )" "0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PERMISSION FLOOR SEATS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: the tool floor's two seats disagree, so the switch cannot be made safely" >&2
	echo "  fix:  the declares of the origin's project.inf, or agentsPermissionFloorTools -- never the assertion" >&2
	exit 1
fi
printf 'PERMISSION_FLOOR_SEATS: OK (%d assertions, offline)\n' "$rigPassCount"
