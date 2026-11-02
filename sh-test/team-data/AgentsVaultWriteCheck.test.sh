#!/usr/bin/env bash
## Behavioural check of the vault write operation: --upsert-vault-item puts a whole document
## into the team-data vault, and the vault read returns what it wrote. Temp stores only, in a
## temp workspace, and every op goes through one `env -i` whose child refuses to run outside it.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsItems.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "items dispatcher not found: $rigFn"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsVaultWriteCheck )" || exit 1
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
rigDir="" ; rigStore=""
rigScenario(){ ## name
	rigDir="$rigTmp/$1" ; rigStore="$rigDir/store"
	mkdir -p "$rigDir/ws/.local" "$rigDir/home/skills/magic-coordinator" "$rigDir/home/skills/user-myx"
	for rigMember in magic-coordinator user-myx ; do printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigDir/home/skills/$rigMember/$rigMember.basic.md" ; done
}
## One op, guarded; stdin is the caller's. The store is $rigStore.
rigOp(){ ## result file, op and its arguments...
	local rigResult="$1" ; shift
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigDir/home" PATH="/usr/bin:/bin" MMDAPP="$rigDir/ws" MDAT_DATA_ROOT="$rigStore" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigDir/home/skills" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac
			case "${MDAT_DATA_ROOT:-$RIG_TMP/}" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MDAT_DATA_ROOT outside the rig tree" >&2 ; exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$rigResult" 2> "$rigResult.err"
	printf '%s' "$?" > "$rigResult.rc"
}

echo "-- a vault document written whole --"
rigScenario write
printf -- '---\ntype: decision-record\n---\n\n# Decision: rig the vault\n\nTake the second option.\n' \
	| rigOp "$rigDir/w" --upsert-vault-item decision-record-20261101T1958Z-rig.md --upsert-from-stdin
rigAssert "the vault write succeeds"                        "$( cat "$rigDir/w.rc" )" 0
rigAssert "the document is in the vault"                    "$( [ -f "$rigStore/vault/decision-record-20261101T1958Z-rig.md" ] && printf made || printf none )" made
rigAssert "the body it was given is stored"                 "$( LC_ALL=C grep -c '^Take the second option\.$' "$rigStore/vault/decision-record-20261101T1958Z-rig.md" 2>/dev/null )" 1

echo "-- the vault read returns what the write put there --"
rigOp "$rigDir/r" --get-vault-item decision-record-20261101T1958Z-rig.md
rigAssert "the vault read succeeds"                         "$( cat "$rigDir/r.rc" )" 0
rigAssert "and carries the written body"                    "$( LC_ALL=C grep -c '^Take the second option\.$' "$rigDir/r" 2>/dev/null )" 1

echo "-- the same document written again is updated in place --"
rigScenario again
printf -- '---\ntype: decision-record\n---\n\n# Decision: rig the vault\n\nTake the second option.\n' \
	| rigOp "$rigDir/w" --upsert-vault-item decision-record-20261101T1959Z-rig.md --upsert-from-stdin
printf -- '---\ntype: decision-record\n---\n\n# Decision: rig the vault\n\nTake the first option instead.\n' \
	| rigOp "$rigDir/w2" --upsert-vault-item decision-record-20261101T1959Z-rig.md --upsert-from-stdin
rigAssert "the second write succeeds"                       "$( cat "$rigDir/w2.rc" )" 0
rigAssert "the new text is stored"                          "$( LC_ALL=C grep -c '^Take the first option instead\.$' "$rigStore/vault/decision-record-20261101T1959Z-rig.md" 2>/dev/null )" 1
rigAssert "the old text is gone"                            "$( LC_ALL=C grep -c '^Take the second option\.$' "$rigStore/vault/decision-record-20261101T1959Z-rig.md" 2>/dev/null )" 0

echo "-- a name with a path separator is refused --"
rigScenario badname
printf -- 'x\n' | rigOp "$rigDir/b" --upsert-vault-item ../escape.md --upsert-from-stdin
rigAssert "a path in the name is refused"                   "$( cat "$rigDir/b.rc" )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ VAULT WRITE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'VAULT_WRITE: OK (%d assertions, offline, temp stores only)\n' "$rigPassCount"
