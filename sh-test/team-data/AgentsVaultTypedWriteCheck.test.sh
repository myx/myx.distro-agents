#!/usr/bin/env bash
## Behavioural check of the typed vault writes (S24 item 9): --upsert-vault-investigation-report, --upsert-vault-decision-record
## and --upsert-vault-verbatim each fix their contract and validate against it, and the generic --upsert-vault-item refuses a
## name that carries a contract's type word. Temp stores only, in a temp workspace, every op through one `env -i` whose child
## refuses to run outside it. The control of each refusal is a write of the same op that must go through.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsItems.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "items dispatcher not found: $rigFn"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsVaultTypedWriteCheck )" || exit 1
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
rigHas(){ ## item name -- made or none
	[ -f "$rigStore/vault/$1" ] && printf made || printf none
}
rigCount(){ ## item name, fixed line -- how many lines of the stored item are exactly that
	LC_ALL=C grep -c -x -F -- "$2" "$rigStore/vault/$1" 2> /dev/null || :
}

rigInvestigation='---
from: magic-coordinator
date: 2026-11-01 15:09 +0200
status: final
---

# Question

What is the rig question?

# Answer

The rig answer.

# Findings

- shown: the rig finding, checked by the rig.

# Assumptions checked

- the rig assumption held.

# Open

none

# Next legs

none'
rigName=investigation-20261101T1509Z-rig.md

echo "-- the generic write refuses a name that carries a contract's type word --"
rigScenario generic
printf '%s\n' "$rigInvestigation" | rigOp "$rigDir/g1" --upsert-vault-item "$rigName" --upsert-from-stdin
rigAssert "an investigation name is refused"                "$( cat "$rigDir/g1.rc" )" 1
rigAssert "and nothing is stored"                           "$( rigHas "$rigName" )" none
rigAssert "the refusal names the typed operation"           "$( LC_ALL=C grep -c -F -e '--upsert-vault-investigation-report' "$rigDir/g1.err" )" 1
printf -- 'x\n' | rigOp "$rigDir/g2" --upsert-vault-item adr-20261101T1509Z-rig.md --upsert-from-stdin
rigAssert "an adr name is refused"                          "$( cat "$rigDir/g2.rc" )" 1
printf -- 'x\n' | rigOp "$rigDir/g3" --upsert-vault-item verbatim-20261101T1509Z-rig.md --upsert-from-stdin
rigAssert "a verbatim name is refused"                      "$( cat "$rigDir/g3.rc" )" 1
printf -- 'x\n' | rigOp "$rigDir/g4" --upsert-vault-item artefact-20261101T1509Z-rig.md --upsert-from-stdin
rigAssert "control: an artefact name is still written"      "$( cat "$rigDir/g4.rc" )$( rigHas artefact-20261101T1509Z-rig.md )" 0made

echo "-- the typed investigation write stamps and keeps its contract --"
rigScenario typed
printf '%s\n' "$rigInvestigation" | rigOp "$rigDir/t1" --upsert-vault-investigation-report "$rigName" --upsert-from-stdin
rigAssert "a valid investigation report is written"         "$( cat "$rigDir/t1.rc" )$( rigHas "$rigName" )" 0made
rigAssert "its type word is investigation"                  "$( rigCount "$rigName" 'type: investigation' )" 1
rigAssert "it names its contract"                           "$( rigCount "$rigName" 'document-contract: vault-item.investigation-report' )" 1
rigAssert "the given status is kept"                        "$( rigCount "$rigName" 'status: final' )" 1
rigOp "$rigDir/t2" --get-vault-item "$rigName"
rigAssert "the vault read returns the stored body"          "$( LC_ALL=C grep -c -x -F 'The rig answer.' "$rigDir/t2" )" 1
printf '%s\n' "$rigInvestigation" | sed 's/^status: final$/status: superseded/' | rigOp "$rigDir/t3" --upsert-vault-investigation-report "$rigName" --upsert-from-stdin
rigAssert "the same report written again is updated"        "$( cat "$rigDir/t3.rc" )$( rigCount "$rigName" 'status: superseded' )" 01

echo "-- the typed write refuses what breaks the contract or the name --"
rigScenario refused
printf '%s\n' "$rigInvestigation" | sed '/^status: final$/d' | rigOp "$rigDir/r1" --upsert-vault-investigation-report "$rigName" --upsert-from-stdin
rigAssert "a report with no status is refused"              "$( cat "$rigDir/r1.rc" )$( rigHas "$rigName" )" 1none
printf '%s\n' "$rigInvestigation" | LC_ALL=C awk '{ print ; } /^from:/ { print "type: ivr" ; }' | rigOp "$rigDir/r2" --upsert-vault-investigation-report "$rigName" --upsert-from-stdin
rigAssert "the old type word ivr is refused"                "$( cat "$rigDir/r2.rc" )$( rigHas "$rigName" )" 1none
printf '%s\n' "$rigInvestigation" | rigOp "$rigDir/r3" --upsert-vault-investigation-report adr-20261101T1509Z-rig.md --upsert-from-stdin
rigAssert "an adr name is refused by the investigation op"  "$( cat "$rigDir/r3.rc" )$( rigHas adr-20261101T1509Z-rig.md )" 1none
printf '%s\n' "$rigInvestigation" | rigOp "$rigDir/r4" --upsert-vault-investigation-report artefact-20261101T1509Z-rig.md --upsert-from-stdin
rigAssert "a name with no type word is refused"             "$( cat "$rigDir/r4.rc" )$( rigHas artefact-20261101T1509Z-rig.md )" 1none
for rigRefused in r1 r2 r3 r4 ; do
	rigAssert "$rigRefused is refused for its content or name, never for an unknown operation" "$( LC_ALL=C grep -c 'invalid option' "$rigDir/$rigRefused.err" )" 0
done
rigAssert "the status refusal says the key is missing"       "$( LC_ALL=C grep -c 'status' "$rigDir/r1.err" | LC_ALL=C awk '{ print ( $1 > 0 ) ; }' )" 1

echo "-- the decision record and the verbatim write --"
rigScenario siblings
printf -- '---\nfrom: magic-coordinator\ndate: 2026-11-01 15:09 +0200\nstatus: proposed\n---\n\n# Question\n\nq\n' \
	| rigOp "$rigDir/s1" --upsert-vault-decision-record adr-20261101T1509Z-rig.md --upsert-from-stdin
rigAssert "a decision record is written"                    "$( cat "$rigDir/s1.rc" )$( rigHas adr-20261101T1509Z-rig.md )" 0made
rigAssert "it names the decision record contract"           "$( rigCount adr-20261101T1509Z-rig.md 'document-contract: vault-item.decision-record' )" 1
printf -- 'The words, word for word.\n' | rigOp "$rigDir/s2" --upsert-vault-verbatim verbatim-20261101T1509Z-rig.md --upsert-from-stdin
rigAssert "a verbatim is written with its keys stamped"     "$( cat "$rigDir/s2.rc" )$( rigHas verbatim-20261101T1509Z-rig.md )$( rigCount verbatim-20261101T1509Z-rig.md 'document-contract: vault-item.verbatim' )" 0made1
printf -- 'x\n' | rigOp "$rigDir/s3" --upsert-vault-verbatim adr-20261101T1509Z-other.md --upsert-from-stdin
rigAssert "a verbatim op refuses an adr name"               "$( cat "$rigDir/s3.rc" )$( rigHas adr-20261101T1509Z-other.md )" 1none
rigAssert "and not for an unknown operation"                "$( LC_ALL=C grep -c 'invalid option' "$rigDir/s3.err" )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ VAULT TYPED WRITE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'VAULT_TYPED_WRITE: OK (%d assertions, offline, temp stores only)\n' "$rigPassCount"
