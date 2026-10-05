#!/usr/bin/env bash
## Every team-tooling op the skillset tells a member to call has an exact-name dispatch arm
## in this package. PARTIAL by nature: it proves an arm exists, not that the arm is reached
## or does what the prose says. Family mentions (a name ending in -* or -<x>) are not ops.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -d "$rigPackage/skillset" ] || rigRefuse "no skillset under $rigPackage"

## Ops only, by namespace: prose also names options such as --from-file, which are not ops.
rigNamed="$( find -L "$rigPackage/skillset" -type f -name '*.md' -exec grep -o -h -E -- '--(member|magic|intern-op|librarian|client|agents)-[a-z0-9<>*-]*' {} + \
	| LC_ALL=C grep -v -E -- '[*<>]|-$' | LC_ALL=C sort -u )"
## Exact-name arms only, both `a|b)` and `(a|b)`; a glob arm routes but is no op's own arm.
rigArms="$( grep -h -E -- '^[[:space:]]*\(?--[a-z0-9|-]+\)' "$rigPackage"/sh-lib/*.include "$rigPackage"/sh-scripts/*.sh \
	| sed -E 's/^[[:space:]]*\(?//; s/\).*$//' | tr '|' '\n' | LC_ALL=C sort -u )"

rigFails=0
## Walk control: a name carried only by one member's own file must be seen.
case $'\n'"$rigNamed"$'\n' in
	*$'\n--magic-escalation-forward\n'*) echo "  PASS  the walk reached a member's own file" ;;
	*) echo "  FAIL  the walk did not reach magic-coordinator's own file" ; rigFails=$(( rigFails + 1 )) ;;
esac
## Matching controls, both directions.
rigMissing="$( printf '%s\n' --member-inbox-reflection-upsert --member-rig-not-an-op | LC_ALL=C comm -23 - <( printf '%s\n' "$rigArms" ) )"
if [ "$rigMissing" = "--member-rig-not-an-op" ] ; then
	echo "  PASS  control: an alternation arm is found and a made-up op is not"
else
	echo "  FAIL  control: expected only --member-rig-not-an-op missing, got: $rigMissing" ; rigFails=$(( rigFails + 1 ))
fi

rigMissing="$( printf '%s\n' "$rigNamed" | LC_ALL=C comm -23 - <( printf '%s\n' "$rigArms" ) )"
if [ -n "$rigMissing" ] ; then
	echo "  FAIL  ops the skillset names with no exact dispatch arm:"
	printf '        %s\n' $rigMissing
	rigFails=$(( rigFails + 1 ))
else
	echo "  PASS  every op the skillset names has an exact dispatch arm"
fi

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SKILLSET OP DISPATCH CHECK FAILED" >&2 ; exit 1
fi
printf 'SKILLSET_OP_DISPATCH: OK (%s ops named, each with an arm; arm existence only, not reachability)\n' "$( printf '%s\n' "$rigNamed" | LC_ALL=C awk 'NF { opCount++ ; } END { print opCount + 0 ; }' )"
