#!/usr/bin/env bash
## Behavioural check on --member-vault-item-read and --member-audit-item-read, the member
## stubs over --intern-op-vault-item-read and --intern-op-audit-item-read: an item under
## vault/ is read whole and by line range, a missing item is refused naming it, a
## path-like name is refused, and a name that exists only under audit/ is not found by the
## vault read (the control that the lookup is vault/ and nothing wider); an audit
## transcript is read from its month folder; an unknown member is refused by the stub;
## and the old --member-read-* names are gone. Offline: a temp data store, skillset root
## and workspace.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigTool="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
rigTmp="$( mktemp -d "${TMPDIR:-/tmp}/AgentsMemberVaultItemReadCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws/.local" "$rigTmp/home" "$rigTmp/skills/magic-tester" "$rigTmp/data/vault" "$rigTmp/data/audit"
printf 'line one\nline two\nline three\nline four\n' > "$rigTmp/data/vault/verbatim-20260929T1000Z-rig.md"
printf 'audit only\n' > "$rigTmp/data/audit/verbatim-20260929T1000Z-audit-only.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHolds(){ ## file, fixed string
	LC_ALL=C grep -q -F -- "$2" "$1" && printf yes || printf no
}
rigRead(){ ## read arguments after the member
	rigRc=0
	( cd "$rigTmp/ws" && env HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_DATA_ROOT="$rigTmp/data" \
		bash "$rigTool" --member-vault-item-read magic-tester "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" || rigRc=$?
}

echo "-- an item under vault/ --"
rigRead verbatim-20260929T1000Z-rig.md
rigHolds "$rigTmp/out" 'line one' | grep -q yes || rigRefuse "the vault item was never read: $( grep -v SetInputSpec "$rigTmp/err" | grep -m1 ERROR )"
rigAssert "it is read, rc 0"                         "$rigRc" 0
rigAssert "whole: its last line is there"            "$( rigHolds "$rigTmp/out" 'line four' )" yes

echo "-- a line range --"
rigRead verbatim-20260929T1000Z-rig.md --start-line 2 --end-line 3
rigAssert "the range holds line two"                 "$( rigHolds "$rigTmp/out" 'line two' )" yes
rigAssert "and line three"                           "$( rigHolds "$rigTmp/out" 'line three' )" yes
rigAssert "and not line one"                         "$( rigHolds "$rigTmp/out" 'line one' )" no
rigAssert "nor line four"                            "$( rigHolds "$rigTmp/out" 'line four' )" no
rigRead verbatim-20260929T1000Z-rig.md --start-line 2
rigAssert "half a range is refused"                  "$( rigHolds "$rigTmp/err" 'must be provided together' )" yes

echo "-- refusals --"
rigRead verbatim-20260929T1000Z-missing.md
rigAssert "a missing item fails"                     "$( [ "$rigRc" -ne 0 ] && echo non-zero || echo 0 )" non-zero
rigAssert "naming it"                                "$( rigHolds "$rigTmp/err" 'verbatim-20260929T1000Z-missing.md' )" yes
rigRead ../audit/verbatim-20260929T1000Z-audit-only.md
rigAssert "a path-like name fails"                   "$( [ "$rigRc" -ne 0 ] && echo non-zero || echo 0 )" non-zero
rigAssert "and reads nothing"                        "$( rigHolds "$rigTmp/out" 'audit only' )" no

echo "-- a range flag given no value --"
rigRead verbatim-20260929T1000Z-rig.md --start-line
rigAssert "vault: --start-line alone fails"          "$( [ "$rigRc" -ne 0 ] && echo non-zero || echo 0 )" non-zero
rigAssert "vault: with the flag named"               "$( rigHolds "$rigTmp/err" '--start-line requires a value' )" yes
rigRc=0
( cd "$rigTmp/ws" && env HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" \
	MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_DATA_ROOT="$rigTmp/data" \
	bash "$rigTool" --member-audit-item-read magic-tester transcript-2026-09-29-rig.md --end-line ) > "$rigTmp/out" 2> "$rigTmp/err" || rigRc=$?
rigAssert "audit: --end-line alone fails"            "$( [ "$rigRc" -ne 0 ] && echo non-zero || echo 0 )" non-zero
rigAssert "audit: with the flag named"               "$( rigHolds "$rigTmp/err" '--end-line requires a value' )" yes

echo "-- control: an item only under audit/ --"
rigRead verbatim-20260929T1000Z-audit-only.md
rigAssert "control: it is not found by the vault read" "$( [ "$rigRc" -ne 0 ] && echo non-zero || echo 0 )" non-zero
rigAssert "control: and nothing of it is printed"    "$( rigHolds "$rigTmp/out" 'audit only' )" no

rigOp(){ ## op, arguments...
	rigRc=0
	( cd "$rigTmp/ws" && env HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_DATA_ROOT="$rigTmp/data" \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" || rigRc=$?
}

echo "-- an audit transcript, from its month folder --"
mkdir -p "$rigTmp/data/audit/2026-09"
printf 'transcript line\n' > "$rigTmp/data/audit/2026-09/transcript-2026-09-29-rig.md"
rigOp --member-audit-item-read magic-tester transcript-2026-09-29-rig.md
rigAssert "it is read, rc 0"                         "$rigRc" 0
rigAssert "with its content"                         "$( rigHolds "$rigTmp/out" 'transcript line' )" yes
rigOp --member-audit-item-read magic-tester verbatim-20260929T1000Z-audit-only.md
rigAssert "a non-transcript name is refused"         "$( rigHolds "$rigTmp/err" 'only transcript-* documents are allowed' )" yes

echo "-- the stubs check who is asking --"
rigOp --member-vault-item-read no-such-member verbatim-20260929T1000Z-rig.md
rigAssert "an unknown member is refused"             "$( rigHolds "$rigTmp/err" 'no such member skill directory' )" yes
rigAssert "and nothing is read"                      "$( rigHolds "$rigTmp/out" 'line one' )" no

echo "-- the old names are gone, with no alias --"
rigOp --member-read-vault-item magic-tester verbatim-20260929T1000Z-rig.md
rigAssert "--member-read-vault-item is not an op"    "$( [ "$rigRc" -ne 0 ] && rigHolds "$rigTmp/out" 'line one' | grep -q no && echo refused || echo served )" refused
rigOp --member-read-audit-item magic-tester transcript-2026-09-29-rig.md
rigAssert "--member-read-audit-item is not an op"    "$( [ "$rigRc" -ne 0 ] && rigHolds "$rigTmp/out" 'transcript line' | grep -q no && echo refused || echo served )" refused

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MEMBER VAULT ITEM READ CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'MEMBER_VAULT_ITEM_READ: OK (%d assertions, offline)\n' "$rigPassCount"
