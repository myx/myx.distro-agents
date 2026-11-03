#!/usr/bin/env bash
## The slice-0 checks of the document-contract guard: the registry, the decision function's default
## branch, the two harness doors and the native hook, with nothing registered yet. Slice 1 adds the
## first refusing row, so the registry shape is asserted here and its row set in the slice 1 check.
## Held, each shown red before the code landed:
##   1. the registry file exists and states its four columns;
##   2. the decision function allows a path with no registered extension: its match arm finds no row,
##      so the validator is never reached, and the write is allowed;
##   3. the harness Write door writes an unregistered `.md` and refuses nothing;
##   4. the harness Edit door writes an unregistered `.md` and refuses nothing;
##   5. the native hook answers nothing for an unregistered `.md`, so the client allows it;
##   6. the hook record is class `native`, matcher `Edit|Write|MultiEdit`, and the harness hook list
##      leaves it out with no fault.
## Offline: MMDAPP and HOME are this rig's own; the guard reads only its own files.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigRegistry="$rigHere/team-data/AgentsDocContract.registry"
rigGuard="$rigHere/team-data/AgentsTools.DocGuard.include"
rigHook="$rigHere/client-hooks/document-contract-guard.sh"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigRegistry" "$rigGuard" "$rigHook" "$rigHarness" "$rigTool" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDocContractGuardSlice0Check )" || exit 1
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

## A workspace with its own write root, as the server computes one.
rigDir="$rigTmp/.local/temp/team"
mkdir -p "$rigDir"

echo "-- 1. the registry states its four columns --"
rigAssert "the registry exists" "$( [ -f "$rigRegistry" ] && printf yes || printf no )" yes
rigAssert "its header names the four columns" "$( LC_ALL=C grep -c '^#   kind' "$rigRegistry" )" 1

echo "-- 2. the decision function allows an unregistered path, the validator never reached --"
rigDecision="$( env -i PATH=/usr/bin:/bin MDLT_ORIGIN="$MDLT_ORIGIN" MMDAPP="$rigTmp" bash -c '
	. "'"$rigGuard"'"
	AgentsToolsDocGuardMatch "$1" ; matchRc=$?
	AgentsToolsDocGuardDecide "$1" "text" harness ; decideRc=$?
	printf "%s:%s" "$matchRc" "$decideRc"
' _ "$rigDir/a.md" )"
rigAssert "no registered extension matches, the write is allowed" "$rigDecision" "1:0"

echo "-- 3 and 4. the harness doors write an unregistered .md and refuse nothing --"
rigPayload='{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"Write","arguments":{"path":"'"$rigDir"'/w.md","content":"# w\n"}}}'
printf '%s\n' "$rigPayload" | ( cd "$rigTmp" && MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" HOME="$rigTmp/home" \
	bash "$rigTool" --intern-mcp-server --run ) > "$rigTmp/wire" 2> "$rigTmp/err" || :
rigAssert "Write landed" "$( [ -f "$rigDir/w.md" ] && printf yes || printf no )" yes
rigAssert "Write refused nothing" "$( LC_ALL=C grep -c 'document-contract guard refused' "$rigTmp/err" )" 0

rigPayload='{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"Edit","arguments":{"path":"'"$rigDir"'/w.md","old_text":"# w","new_text":"# ww"}}}'
printf '%s\n' "$rigPayload" | ( cd "$rigTmp" && MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" HOME="$rigTmp/home" \
	bash "$rigTool" --intern-mcp-server --run ) > "$rigTmp/wire" 2> "$rigTmp/err" || :
rigAssert "Edit landed" "$( LC_ALL=C grep -q '# ww' "$rigDir/w.md" && printf yes || printf no )" yes
rigAssert "Edit refused nothing" "$( LC_ALL=C grep -c 'document-contract guard refused' "$rigTmp/err" )" 0

echo "-- 5. the native hook answers nothing for an unregistered path --"
rigPayload='{"session_id":"s-rig","cwd":"'"$rigTmp"'","hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"'"$rigDir"'/n.md","content":"x"}}'
rigOut="$( printf '%s' "$rigPayload" | env -i HOME="$rigTmp/home" PATH=/usr/bin:/bin MMDAPP="$rigTmp" MDLT_ORIGIN="$MDLT_ORIGIN" bash "$rigHook" 2> "$rigTmp/hook.err" )"
rigAssert "hook answers nothing (allow)" "$rigOut" ""

echo "-- 6. the hook is native-only, and the harness hook list leaves it out --"
rigAssert "policy: class native, matcher Edit|Write|MultiEdit" \
	"$( env -i PATH=/usr/bin:/bin MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "'"$rigHere"'/client/AgentsTools.ClientToolPolicy.include" ; AgentsToolsClientToolPolicyHookRecords' | LC_ALL=C awk -F'\t' '$5 == "document-contract-guard.sh" { print $1 ":" $2 ":" $4 }' )" \
	"PreToolUse:native:Edit|Write|MultiEdit"
rigAssert "harness list leaves it out, no fault" "$( env -i PATH=/usr/bin:/bin MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '
	. "'"$rigHere"'/client/AgentsTools.ClientToolPolicy.include" ; . "'"$rigHere"'/harness/AgentsHarnessHooksLoad.include"
	harnessHooksList="" harnessHooksFault="" harnessHooksSkipped=0
	AgentsHarnessHooksFromRecords "$( AgentsToolsClientToolPolicyHookRecords )"
	printf "%s:%s" "[$harnessHooksFault]" "$( printf "%s" "$harnessHooksList" | LC_ALL=C grep -c document-contract-guard )"
' )" "[]:0"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ DOC CONTRACT GUARD SLICE 0 CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'DOC_CONTRACT_GUARD_SLICE0: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
