#!/usr/bin/env bash
## The slice-1 checks of the document-contract guard: `*.routine.md` registered as refusing, checked
## against its contract through the one validator, at the two harness doors and through the native hook.
## Held, each shown red before the code landed:
##   1. the registry names `routine` for `*.routine.md`, state `refusing`, with its contract file present;
##   2. a Write that turns a sound routine into one missing a required key is refused, the file unchanged;
##   3. an Edit whose edits introduce one refusing fault is refused whole, nothing written;
##   4. an Edit of a routine file that already carries a legacy fault, touching only a body line, goes on:
##      the untouched fault is not charged to the write;
##   5. the same fixture gives the same verdict through the in-tool door and through the hook;
##   6. a registry row in `refusing` whose contract file is missing refuses, and names the missing file;
##   7. the guard is called from the two harness doors and the hook, and from no team writer;
##   8. the vault kinds are registered by the type word that opens the name (S12.30): the four with a contract report, the
##      planning and tracking kinds are absent and allowed, a vault file of no registered kind is no document type, and a
##      Write of a vault epic-blueprint goes on under its reporting row.
## Offline: MMDAPP and HOME are this rig's own; the guard reads only its own files and the contract.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigRegistry="$rigHere/team-data/AgentsDocContract.registry"
rigGuard="$rigHere/team-data/AgentsTools.DocGuard.include"
rigHook="$rigHere/client-hooks/document-contract-guard.sh"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigContract="$MDLT_ORIGIN/myx/myx.distro-agents/skillset/magic-team/magic-team/contracts/routine.contract.format.md"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigRegistry" "$rigGuard" "$rigHook" "$rigHarness" "$rigTool" "$rigContract" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDocContractGuardSlice1Check )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

rigDir="$rigTmp/.local/temp/team"
mkdir -p "$rigDir"

## A routine file that meets its contract; its member names are the ones the validator skips.
rigGood(){ cat <<'ROUTINE'
---
type: routine
executors: magic-team
maintainers: magic-team
invitees: magic-team
requires-session-kind: coworking
runs-at: none
---
# keeper-myx.test.routine — the actual procedure

# Summary

One short sentence.

## Goals

- A goal.

## Scope

- Does:
  - A thing.
- Doesn't:
  - Another thing.

# Opening steps

1. **open**: Do the open.

# Steps

1. **step**: Do the step.

# Closure steps

1. **close**: Do the close.

# Routine's local procedures

None.

# Routine's local rules

- A rule.

# Routine-specific tooling

None.

# Maintainer Notes

None.
ROUTINE
}

rigGood > "$rigDir/good.routine.md"
rigBroken="$( rigGood | LC_ALL=C sed '/^requires-session-kind: coworking$/d' )"

## A document text, JSON-escaped: every real newline becomes the two characters \n.
rigJson(){ ## text
	printf '%s' "$1" | LC_ALL=C awk '{ if (NR>1) printf "\\n" ; gsub(/\\/,"\\\\") ; gsub(/"/,"\\\"") ; printf "%s", $0 }'
}

rigServer(){ ## id -- run the payload on stdin through the served harness
	( cd "$rigTmp" && MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" HOME="$rigTmp/home" \
		bash "$rigTool" --intern-mcp-server --run ) > "$rigTmp/wire.$1" 2> "$rigTmp/err.$1" || :
}
rigRequest(){ ## id, tool, arguments object
	printf '{"jsonrpc":"2.0","id":%s,"method":"tools/call","params":{"name":"%s","arguments":%s}}\n' "$1" "$2" "$3"
}
rigWriteArgs(){ ## path, text
	printf '{"path":"%s","content":"%s"}' "$1" "$( rigJson "$2" )"
}
rigEditArgs(){ ## path, old, new
	printf '{"path":"%s","old_string":"%s","new_string":"%s"}' "$1" "$2" "$3"
}

echo "-- 1. the registry names routine, refusing, with its contract present --"
rigAssert "registry row" "$( LC_ALL=C awk -F'\t' '$1 == "routine" && $3 == "refusing" { print $2 ":" $4 }' "$rigRegistry" )" ".routine.md:routine.contract.format.md"
rigAssert "contract file present" "$( [ -f "$rigContract" ] && printf yes || printf no )" yes

echo "-- 2. a Write that introduces a required-key fault is refused, the file unchanged --"
printf '%s\n' "$( rigGood )" > "$rigDir/w.routine.md"
rigBefore="$( cat "$rigDir/w.routine.md" )"
rigRequest 2 Write "$( rigWriteArgs "$rigDir/w.routine.md" "$rigBroken" )" | rigServer 2
rigAssert "the broken write refused" "$( LC_ALL=C grep -c 'the document-contract guard refuses:' "$rigTmp/err.2" )" 1
rigAssert "the file is unchanged" "$( cat "$rigDir/w.routine.md" )" "$rigBefore"

echo "-- 3. an Edit that introduces a refusing fault is refused whole --"
printf '%s\n' "$( rigGood )" > "$rigDir/e.routine.md"
rigBefore="$( cat "$rigDir/e.routine.md" )"
rigRequest 3 Edit "$( rigEditArgs "$rigDir/e.routine.md" 'requires-session-kind: coworking' 'requires-session-kind:')" | rigServer 3
rigAssert "the edit refused" "$( LC_ALL=C grep -c 'the document-contract guard refuses:' "$rigTmp/err.3" )" 1
rigAssert "nothing written" "$( cat "$rigDir/e.routine.md" )" "$rigBefore"

echo "-- 4. an Edit touching only a body line goes on, the untouched fault not charged --"
printf '%s\n' "$rigBroken" > "$rigDir/legacy.routine.md"
rigRequest 4 Edit "$( rigEditArgs "$rigDir/legacy.routine.md" 'One short sentence.' 'One edited sentence.' )" | rigServer 4
rigAssert "the body edit landed" "$( LC_ALL=C grep -q 'One edited sentence.' "$rigDir/legacy.routine.md" && printf yes || printf no )" yes
rigAssert "the legacy fault still stands" "$( LC_ALL=C grep -c 'requires-session-kind: coworking' "$rigDir/legacy.routine.md" )" 0

echo "-- 5. the same fixture gives the same verdict through the door and through the hook --"
printf '%s\n' "$( rigGood )" > "$rigDir/both.routine.md"
rigRequest 5 Write "$( rigWriteArgs "$rigDir/both.routine.md" "$rigBroken" )" | rigServer 5
rigDoorVerdict="$( LC_ALL=C grep -c 'the document-contract guard refuses:' "$rigTmp/err.5" )"
rigHookPayload='{"session_id":"s-rig","cwd":"'"$rigTmp"'","hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"'"$rigDir"'/both.routine.md","content":"'"$( rigJson "$rigBroken" )"'"}}'
rigHookOut="$( printf '%s' "$rigHookPayload" | env -i HOME="$rigTmp/home" PATH=/usr/bin:/bin MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" bash "$rigHook" 2> "$rigTmp/hook.err" )"
rigHookVerdict="$( printf '%s' "$rigHookOut" | LC_ALL=C grep -c '"permissionDecision": "deny"' )"
rigAssert "door refuses, hook denies, the same fixture" "$rigDoorVerdict:$rigHookVerdict" "1:1"

echo "-- 6. a refusing row whose contract file is missing refuses and names it --"
rigScratch="$rigTmp/origin"
mkdir -p "$rigScratch/myx/myx.distro-agents/sh-lib/team-data"
cp -- "$rigGuard" "$rigScratch/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.DocGuard.include"
printf 'routine\t.routine.md\trefusing\troutine.contract.format.md\n' > "$rigScratch/myx/myx.distro-agents/sh-lib/team-data/AgentsDocContract.registry"
rigDecision="$( env -i PATH=/usr/bin:/bin MDLT_ORIGIN="$rigScratch" MMDAPP="$rigTmp" MDAT_SKILLSET_ROOT="$rigTmp/nonesuch" HOME="$rigTmp/home" bash -c '
	. "'"$rigScratch"'/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.DocGuard.include"
	AgentsToolsDocGuardDecide "$1" "" "$( cat "$2" )" harness 2> "$3"
	printf "%s" "$?"
' _ "$rigDir/good.routine.md" "$rigDir/good.routine.md" "$rigTmp/missing.err" )"
rigAssert "missing contract refused" "$rigDecision" "1"
rigAssert "the message names the missing contract" "$( LC_ALL=C grep -c 'routine.contract.format.md' "$rigTmp/missing.err" )" 1

echo "-- 7. the guard is called from the two harness doors and the hook, and from no team writer --"
rigAssert "two door calls, one hook call" \
	"$( LC_ALL=C grep -c 'AgentsToolsDocGuardDecide \"' "$rigHere/harness/AgentsHarnessToolsFile.include" ):$( LC_ALL=C grep -c 'AgentsToolsDocGuardDecide \"' "$rigHere/client-hooks/document-contract-guard.sh" )" "2:1"
rigAssert "no team writer calls the guard" "$( LC_ALL=C grep -rc 'AgentsToolsDocGuardDecide' "$rigHere/board" "$rigHere/inbox" 2>/dev/null | LC_ALL=C grep -v ':0' | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "0"

echo "-- 8. the vault kinds, by the type word that opens the name --"
rigVaultRow(){ ## path -> "<match rc>:<row or ->"
	( . "$rigGuard" ; if AgentsToolsDocGuardMatch "$1" ; then printf '0:' ; AgentsToolsDocGuardRow "$1" || printf -- '-' ; else printf '1:-' ; fi ) 2> /dev/null | LC_ALL=C tr '\t' ' ' | LC_ALL=C tr -d '\n'
}
rigAssert "an epic-blueprint reports against its contract, under the kind the validator knows" "$( rigVaultRow /rig/vault/epic-blueprint-20261102-refactorings.md )" "0:vault-item.epic-blueprint reporting vault-item.epic-blueprint.contract.format.md"
rigAssert "an investigation, an adr and a verbatim record the same" "$( rigVaultRow /rig/vault/investigation-20261101T1509Z-model.md | LC_ALL=C cut -d ' ' -f 2 ):$( rigVaultRow /rig/vault/adr-20261101T1509Z-x.md | LC_ALL=C cut -d ' ' -f 2 ):$( rigVaultRow /rig/vault/verbatim-record-20261101T1509Z-x.md | LC_ALL=C cut -d ' ' -f 2 )" "reporting:reporting:reporting"
rigAssert "planning and tracking are declared, absent"     "$( rigVaultRow /rig/vault/planning-20261109-sprint.md ):$( rigVaultRow /rig/vault/tracking-20261102-refactorings.md )" "0:planning absent -:0:tracking absent -"
rigAssert "a vault file of no registered kind is no document type" "$( rigVaultRow /rig/vault/product-card-ae3.md )" "1:-"
rigAssert "a routine is still matched by its ending"       "$( rigVaultRow /rig/team/x.routine.md | LC_ALL=C cut -d ' ' -f 1-2 )" "0:routine refusing"
mkdir -p "$rigDir/vault"
rigEpic="$( printf -- '---\ntype: epic-blueprint\ndocument-contract: vault-item.epic-blueprint\nfrom: user-rig\ndate: 2026-11-08 14:37 +0200\n---\n\n# A rig epic\n\nOne goal.\n' )"
rigRequest 8 Write "$( rigWriteArgs "$rigDir/vault/epic-blueprint-20261108-rig.md" "$rigEpic" )" | rigServer 8
rigAssert "a Write of a vault epic-blueprint goes on under its reporting row" "$( [ -f "$rigDir/vault/epic-blueprint-20261108-rig.md" ] && printf landed || printf none ):$( LC_ALL=C grep -c 'the document-contract guard refuses:' "$rigTmp/err.8" )" "landed:0"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ DOC CONTRACT GUARD SLICE 1 CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'DOC_CONTRACT_GUARD_SLICE1: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
