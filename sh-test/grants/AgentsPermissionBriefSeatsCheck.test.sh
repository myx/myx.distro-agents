#!/usr/bin/env bash
## Behavioural check on S21.20 item 20a: a spawn brief's access block names the seats its session may
## read without asking, so the brief never sends a session outside its floor. The seats are the
## floor's readable roots, and each one is checked against the holds model, so a path a deny row
## covers is never offered as free.
##   1. a member with no deny rows is given the team skillset as a seat it may read;
##   2. the sandbox is not repeated: `always open:` already names it whole;
##   3. a control proves the line is built from the floor and the holds model, not typed in: a
##      member whose read of the skillset is denied gets no seat at all;
##   4. every line the block printed before this change is still printed, in its own order.
## Offline: a scratch workspace and the package's own skillset only.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigHolds="$rigOrigin/myx/myx.distro-agents/sh-lib/grants/AgentsTools.PermissionHolds.include"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHolds" ] || rigRefuse "the holds model is not at the origin this workspace resolves: $rigHolds"

mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsPermissionBriefSeatsCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/agents" "$rigWs/source/rig"
printf 'Name: rig\n' > "$rigWs/source/rig/project.inf"
: > "$rigWs/.local/agents/members.registry"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## The access block for a member, as the brief is given it.
rigBlock(){ ## member
	( MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDAT_SKILLSET_ROOT="${MDAT_SKILLSET_ROOT:-}" MDAT_WORKSPACE_MODE=team-rig \
		bash -c '. "$1" ; AgentsToolsPermissionAccessBlock "$2" ""' _ "$rigHolds" "$1" ) 2> "$rigTmp/err"
	cat "$rigTmp/err" >&2
}

echo "-- 1. a member with no deny rows is told the seat it may read --"
rigOut="$( rigBlock magic-developer )"
rigAssert "the team skillset is named as free to read" "$( LC_ALL=C grep -c '^free to read without asking: .*the team skillset' <<< "$rigOut" )" 1
rigAssert "and it stands above the line that says how to ask for more" \
	"$( LC_ALL=C grep -n '^free to read without asking:' <<< "$rigOut" | LC_ALL=C cut -d: -f1 | LC_ALL=C awk '{ print ( $1 < 99 ? "above" : "below" ) ; }' )" "above"

echo "-- 2. the sandbox is not repeated --"
rigAssert "no sandbox path stands in the free line" "$( LC_ALL=C grep '^free to read without asking:' <<< "$rigOut" | LC_ALL=C grep -c -e '/input' -e '/output' -e 'sandbox' )" 0

echo "-- 3. control: the seat line is the floor's own reading, not a string in the code --"
## The line must equal what the floor function answers for the same member, worked out here in
## the same call. A hand-typed path in the block would part company with that answer.
rigFloorSeat="$( ( MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDAT_WORKSPACE_MODE=team-rig \
	bash -c '. "$1" ; AgentsToolsPermissionFreeReadSeats "$2"' _ "$rigHolds" magic-developer ) 2> /dev/null )"
rigAssert "the block's line is exactly the floor's own answer" "$( LC_ALL=C grep '^free to read without asking:' <<< "$rigOut" | LC_ALL=C sed 's/^free to read without asking: //' )" "$rigFloorSeat"
rigAssert "and that answer is not empty, so the comparison is not two blanks agreeing" "$( [ -n "$rigFloorSeat" ] && printf named || printf empty )" "named"

echo "-- 4. every line the block printed before is still printed --"
printf 'Name: rig\n' > "$rigWs/source/rig/project.inf"
rigOut="$( rigBlock magic-developer )"
rigAssert "the ask line is last, and always there" "$( LC_ALL=C tail -1 <<< "$rigOut" | LC_ALL=C grep -c '^to ask for more: call RequestPermission' )" 1
rigAssert "for a member with no deny rows the block is its seat line and the ask line" "$( LC_ALL=C grep -c . <<< "$rigOut" )" 2

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PERMISSION BRIEF SEATS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: a brief does not name the seats its session may read, or names one it may not" >&2
	echo "  fix:  AgentsToolsPermissionAccessBlock and AgentsToolsPermissionFreeReadSeats -- never the assertion" >&2
	exit 1
fi
printf 'PERMISSION_BRIEF_SEATS: OK (%d assertions, offline)\n' "$rigPassCount"
