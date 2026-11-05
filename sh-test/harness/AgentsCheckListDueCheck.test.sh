#!/usr/bin/env bash
## Behavioural check on S13.9: a CheckList item may carry a due time, and a Wait returns the items past it at once.
## Run through the real harness and its own CheckList and Wait tools, offline: the wait's sources are local files and
## the harness's own runtime, and nothing reaches a host.
## Held:
##   1. an item written with a due time keeps it, on a pending item and on the one in progress, and the round trip reads
##      it back exactly
##   2. the due mark goes before the in-progress one, so it is still where a reader finds it; a completed item carries
##      none, because the mark belongs to an open item
##   3. a due time nothing can read is refused, and the list kept before stands
##   4. an item past its due time is returned at the top of a Wait at once, in one `CheckList pending:` block
##   5. the control, both directions: the same list with a due time still in the future waits as it always did
##   6. a Wait that is waiting for an ask carries none of it, since that result is the ask's
## Red before S13.9: `due` is no field the tool knows, so the time is dropped and no item is ever past due.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigMdltOrigin="$MDLT_ORIGIN"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigHarness="$rigPkg/sh-lib/harness/AgentsUniversalHarness.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "the harness is not at the origin: $rigHarness"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsCheckListDueCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigMember="magic-developer"
rigSession="rig-due-session"
rigFolder="$rigWs/.local/agents/sessions/$rigSession"
rigList="$rigFolder/$rigMember.checklist.md"
rigQuiet="$rigWs/quiet.txt"
mkdir -p "$rigFolder" "$rigTmp/skills/$rigMember" "$rigWs/bin" || rigRefuse "the rig could not be made: $rigTmp"
printf 'rig\n' > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
: > "$rigQuiet"
## A curl that fails at once, so a source this call does not name reaches no host.
printf '#!/bin/sh\nexit 22\n' > "$rigWs/bin/curl"
chmod +x "$rigWs/bin/curl"
git -C "$rigWs" init -q 2> /dev/null || :

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
## A moment the tooling reads: the far past and the far future, so the check depends on no clock of its own.
rigPast="2020-01-01 00:00 +0000"
rigLater="2099-01-01 00:00 +0000"

rigTool(){ ## tool name, the JSON arguments -- its result as the harness gives it
	## NO SESSION OF THE RUNNER'S OWN CROSSES: a rig that inherits one writes its list into that session's folder and
	## reads a live session's file (the lesson of `reflection-20261104T0427Z-rig-inherits-the-runners-session`).
	( cd "$rigWs" && printf '%s' "$2" | env -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_SESSION_ID \
		-u MDAT_SESSION_THREAD -u MDAT_SPAWN_SANDBOX_ROOT -u MDAT_SPAWN_SANDBOX_ROOT_REAL -u MDAT_SESSION_UNATTENDED \
		MDAT_SPAWN_SESSION_ID="$rigSession" MMDAPP="$rigWs" MDAT_SPAWN_AGENT="$rigMember" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_HARNESS_WAIT_TIMEOUT=2 MDAT_WAIT_REMIND=off \
		PATH="$rigWs/bin:$PATH" bash "$rigHarness" --intern-tool "$1" 2>&1 )
}
rigHolds(){ ## text, a string -- yes where it holds it
	case "$1" in *"$2"*) printf yes ;; *) printf no ;; esac
}

echo "-- 1. a due time is kept on an open item, pending or in progress --"
rigOut="$( rigTool CheckList "{\"todos\":[{\"content\":\"Refresh the rig\",\"status\":\"pending\",\"activeForm\":\"Refreshing the rig\",\"due\":\"$rigLater\"},{\"content\":\"Run the suite\",\"status\":\"in_progress\",\"activeForm\":\"Running the suite\",\"due\":\"$rigLater\"},{\"content\":\"Read the plan\",\"status\":\"completed\",\"activeForm\":\"Reading the plan\"}]}" )"
rigAssert "the write is accepted" "$( rigHolds "$rigOut" 'OK: ' )" "yes"
rigAssert "the pending item carries its due time" \
	"$( LC_ALL=C grep -c -F -- "- [ ] Refresh the rig (due: $rigLater)" "$rigList" )" "1"
rigAssert "and so does the one in progress, before its own mark" \
	"$( LC_ALL=C grep -c -F -- "- [~] Run the suite (due: $rigLater) (in progress: Running the suite)" "$rigList" )" "1"
rigAssert "the closed item carries none, and is closed" \
	"$( LC_ALL=C grep -c -F -- '- [x] Read the plan' "$rigList" )" "1"
rigOut="$( rigTool CheckList '{}' )"
rigAssert "and the round trip reads it back as it was written" \
	"$( rigHolds "$rigOut" "- [~] Run the suite (due: $rigLater) (in progress: Running the suite)" )" "yes"

echo "-- 2. closing the item in progress keeps its due time --"
rigOut="$( rigTool CheckList "{\"todos\":[{\"content\":\"Refresh the rig\",\"status\":\"pending\",\"activeForm\":\"Refreshing the rig\",\"due\":\"$rigLater\"},{\"content\":\"Run the suite\",\"status\":\"completed\",\"activeForm\":\"Running the suite\",\"due\":\"$rigLater\"}]}" )"
rigAssert "a closed item carries no due time, the mark being an open item's" \
	"$( LC_ALL=C grep -c -F -- '- [x] Run the suite' "$rigList" ) $( LC_ALL=C grep -c -F -- 'Run the suite (due:' "$rigList" )" "1 0"

echo "-- 3. a due time nothing can read is refused, and the list stands --"
printf -- '- [ ] Keep me\n' > "$rigList"
rigOut="$( rigTool CheckList '{"todos":[{"content":"Refresh the rig","status":"pending","activeForm":"Refreshing the rig","due":"next tuesday-ish"}]}' )"
rigAssert "the write is refused, naming the field and saying nothing was written" \
	"$( rigHolds "$rigOut" 'ERROR: ' ) $( rigHolds "$rigOut" 'due must be a date-time' ) $( rigHolds "$rigOut" 'Nothing was written.' )" "yes yes yes"
rigAssert "and the list before it stands" "$( cat "$rigList" )" "- [ ] Keep me"

echo "-- 4. an item past its due time is returned at the top of a Wait at once --"
rigOut="$( rigTool CheckList "{\"todos\":[{\"content\":\"Refresh the rig\",\"status\":\"pending\",\"activeForm\":\"Refreshing the rig\",\"due\":\"$rigPast\"},{\"content\":\"Report the count\",\"status\":\"pending\",\"activeForm\":\"Reporting the count\",\"due\":\"$rigLater\"}]}" )"
rigAssert "the list is written with one item past due and one not" "$( rigHolds "$rigOut" '2 item(s)' )" "yes"
rigOut="$( rigTool Wait "{\"sources\":\"file:$rigQuiet\",\"timeout\":2}" )"
rigAssert "the Wait returns at once, with the block and not a timeout" \
	"$( LC_ALL=C grep -c -F 'CheckList pending: these items of your list are past their due time, and they are yours to close before you wait again.' <<< "$rigOut" ) $( LC_ALL=C grep -c 'WAIT-RESULT' <<< "$rigOut" )" "1 0"
rigAssert "the item past its due time is carried, and the other one is not" \
	"$( LC_ALL=C grep -c -F -- "- [ ] Refresh the rig (due: $rigPast)" <<< "$rigOut" ) $( LC_ALL=C grep -c -F -- 'Report the count' <<< "$rigOut" )" "1 0"

echo "-- 5. the control: a due time still in the future waits as it always did --"
rigOut="$( rigTool CheckList "{\"todos\":[{\"content\":\"Refresh the rig\",\"status\":\"pending\",\"activeForm\":\"Refreshing the rig\",\"due\":\"$rigLater\"}]}" )"
rigAssert "the list holds only a future due time" "$( rigHolds "$rigOut" '1 item(s)' )" "yes"
rigOut="$( rigTool Wait "{\"sources\":\"file:$rigQuiet\",\"timeout\":2}" )"
rigAssert "so the Wait waits, and is a TIMEOUT" "$( LC_ALL=C grep -c 'WAIT-RESULT: TIMEOUT' <<< "$rigOut" )" "1"
rigAssert "and carries no due block" "$( rigHolds "$rigOut" 'CheckList pending:' )" "no"

echo "-- 6. the ask gate: a wait for an ask carries none of it, since that result is the ask's --"
## The gate is the one argument the Wait tool gives the block: `true` for its own wait, `false` for a call that waits on an
## ask (AgentsHarnessWait.include, `AgentsHarnessWaitCheckListDue`). Driven here through the function itself, because the
## ask's own path needs a live question and this rig posts nothing.
## NO SESSION OF THE RUNNER'S OWN CROSSES HERE EITHER: `AgentsHarnessCheckListPlace` reads MDAT_SESSION_ID before
## MDAT_SPAWN_SESSION_ID, so a rig that inherits the runner's id reads the live session's list and finds nothing
## (`reflection-20261104T0427Z-rig-inherits-the-runners-session`).
rigAskGate(){ ## the gate's argument -- the function's own output for it
	( unset MDAT_SESSION_ID MDAT_SESSION_THREAD MDAT_SPAWN_SANDBOX_ROOT MDAT_SPAWN_SANDBOX_ROOT_REAL
		MMDAPP="$rigWs" MDLT_ORIGIN="$rigMdltOrigin" MDAT_SPAWN_SESSION_ID="$rigSession"
		MDAT_SPAWN_AGENT="$rigMember" MDAT_SKILLSET_ROOT="$rigTmp/skills"
		export MMDAPP MDLT_ORIGIN MDAT_SPAWN_SESSION_ID MDAT_SPAWN_AGENT MDAT_SKILLSET_ROOT
		harnessAgent="$rigMember"
		harnessSessionId="$rigSession"
		. "$rigPkg/sh-lib/harness/AgentsHarnessAccess.include"
		. "$rigPkg/sh-lib/harness/AgentsHarnessSpawn.include"
		. "$rigPkg/sh-lib/harness/AgentsHarnessBatch.include"
		. "$rigPkg/sh-lib/harness/AgentsHarnessWait.include"
		AgentsHarnessWaitCheckListDue "$1"
	)
}
rigOut="$( rigTool CheckList "{\"todos\":[{\"content\":\"Refresh the rig\",\"status\":\"pending\",\"activeForm\":\"Refreshing the rig\",\"due\":\"$rigPast\"}]}" )"
rigAssert "the list holds one item past its due time" "$( rigHolds "$rigOut" '1 item(s)' )" "yes"
rigAssert "a wait of the tool's own carries the block" \
	"$( rigAskGate true | LC_ALL=C grep -c 'CheckList pending:' )" "1"
rigAssert "and a wait for an ask carries none of it" \
	"$( rigAskGate false | LC_ALL=C grep -c 'CheckList pending:' )" "0"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ CHECKLIST DUE CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'CHECKLIST_DUE: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
