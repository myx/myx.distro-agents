#!/usr/bin/env bash
## Behavioural check on the routine validator (`--intern-doc-validate routine`, run when a routine is saved) with a plain member name in
## `executors:` or `invitees:` that names no member on any workspace of this machine: it is refused, the row naming the nearest real member,
## as a `<type>-*` that names none is. A copy of a real routine, its executors or invitees changed, is validated against a rig skillset that
## holds one keeper and one partner, in the shell the save uses. Held: an unknown name in executors, and in invitees, is a row that names
## the name, the key and the nearest member (not a member of another type); a known name, a `<type>-?` and `none` are no fault; the row of an
## unknown name does not hide the rows of the rest. Offline; only the rig's own tree is read.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
rigSource="$rigPackage/skillset/magic-team/magic-team/magic-team.readme-gap.routine.md"
[ -f "$rigSource" ] || rigRefuse "the routine to copy is not in the skillset: $rigSource"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRoutineUnknownMemberCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigMembers="$rigTmp/members"
mkdir -p "$rigWs/.local" "$rigMembers/keeper-rig" "$rigMembers/partner-rig" "$rigMembers/magic-rig" "$rigMembers/magic-coordinator" "$rigMembers/magic-librarian" "$rigMembers/magic-architect"
for rigName in keeper-rig partner-rig magic-rig magic-coordinator magic-librarian magic-architect ; do printf 'rig\n' > "$rigMembers/$rigName/$rigName.basic.md" ; done
[ "$rigWs" != "${MMDAPP%/}" ] || rigRefuse "the rig workspace is the real one"
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigValidate(){ ## executors value, invitees value, optional maintainers value -> the validator's rows with the file name cut off, one line a row joined by |
	local copy="$rigTmp/magic-team.rig-copy.routine.md"
	LC_ALL=C awk -v ex="$1" -v inv="$2" -v mt="${3:-}" 'NR == 1 && $0 == "---" { fm = 1 ; print ; next } fm && $0 == "---" { fm = 0 } fm && index( $0, "executors: " ) == 1 { print "executors: " ex ; next } fm && index( $0, "invitees: " ) == 1 { print "invitees: " inv ; next } fm && mt != "" && index( $0, "maintainers: " ) == 1 { print "maintainers: " mt ; next } { print }' "$rigSource" > "$copy"
	( cd "$rigWs" && env -i HOME="$rigTmp" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigMembers" bash "$rigTool" --intern-doc-validate routine "$copy" 2>&1 ) \
		| LC_ALL=C grep -E '\.routine\.md:[0-9]+: ' | LC_ALL=C sed 's|^[^ ]*: ||' | LC_ALL=C tr '\n' '|'
}

rigAssert "a known member, a choice and none: no fault" "$( rigValidate 'keeper-rig, partner-?' none )" ""
rigOut="$( rigValidate 'partner-acme-nosuch' none )"
rigAssert "an executor that names no member: a row naming the name, the key and the nearest member" \
	"$( printf '%s' "$rigOut" | LC_ALL=C grep -c -e 'executors' ):$( printf '%s' "$rigOut" | LC_ALL=C grep -c -F -e 'partner-acme-nosuch' ):$( printf '%s' "$rigOut" | LC_ALL=C grep -c -F -e 'nearest member is partner-rig' )" "1:1:1"
rigOut="$( rigValidate 'keeper-rig' 'keeper-rg, magic-rig' )"
rigAssert "an invitee that names no member: the same, naming keeper-rig as the nearest" \
	"$( printf '%s' "$rigOut" | LC_ALL=C grep -c -e 'invitees' ):$( printf '%s' "$rigOut" | LC_ALL=C grep -c -F -e 'keeper-rg' ):$( printf '%s' "$rigOut" | LC_ALL=C grep -c -F -e 'nearest member is keeper-rig' )" "1:1:1"
rigAssert "maintainers that are known members, and the human-owner: no fault" "$( rigValidate 'keeper-rig' none 'magic-rig, human-owner, keeper-?' )" ""
rigOut="$( rigValidate 'keeper-rig' none 'magic-rig, magic-nosuch' )"
rigAssert "a maintainer that names no member: the same row, for the key maintainers, nearest member magic-rig" \
	"$( printf '%s' "$rigOut" | LC_ALL=C grep -c -e 'maintainers' ):$( printf '%s' "$rigOut" | LC_ALL=C grep -c -F -e 'magic-nosuch' ):$( printf '%s' "$rigOut" | LC_ALL=C grep -c -F -e 'nearest member is magic-rig' )" "1:1:1"
rigOut="$( rigValidate 'keeper-rig, partner-acme-nosuch, keeper-none' none )"
rigAssert "two unknown names in one value: a row for each" "$( printf '%s' "$rigOut" | LC_ALL=C grep -o -F -e 'partner-acme-nosuch' -e 'keeper-none' | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' ' )" "keeper-none partner-acme-nosuch "

if [ "$rigFails" -gt 0 ] ; then
	echo "⛔ ROUTINE UNKNOWN MEMBER CHECK FAILED: $rigFails of $(( rigFails + rigPasses )) assertion(s)" >&2
	exit 1
fi
echo "ROUTINE_UNKNOWN_MEMBER: OK ($rigPasses assertions, offline)"
