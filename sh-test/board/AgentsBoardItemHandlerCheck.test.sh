#!/usr/bin/env bash
## Behavioural check on which routine runs a board item's next iteration (sh-lib/board/AgentsTools.BoardItemHandler.include): the table "Next iteration by
## document type" of magic-team.advance.routine is the one source, and the item's key `handler-routine:` chooses where its type's default would run the wrong
## iteration, and never overrides a gate. Held:
##   1. the table is read: a row for each type, its routine as a file name, `-` where the iteration is an action, and the gate column
##   2. no handler: the type's default; a proposal that carries a communication channel is the `proposal-root` row
##   3. a handler that the table lists for the type, or whose own Summary says `Handles:` the type, is the routine, by file name or as `<name>.routine`
##   4. a handler that is no routine, one that does not handle the type, and one that would replace a gate row, FLAG the item, rc 3, and name no routine
##   5. an approval and a proposal root are always at their gate; a task or a project is, when the caller says so (--at-gate)
##   6. a type with no row and no handler is flagged for grooming; an item with no type cannot be decided (rc 2)
## Offline: a skillset root of this rig, items of this rig; every call through `env -i`.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigInclude="$rigPackage/sh-lib/board/AgentsTools.BoardItemHandler.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the handler include is not in the package: $rigInclude"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsBoardItemHandlerCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigSkills="$rigTmp/skills" rigWs="$rigTmp/ws" rigD="$rigTmp/items"
mkdir -p "$rigSkills/magic-team" "$rigWs/.local/agents" "$rigTmp/home" "$rigD"
rigPassCount=0 rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## The skillset of the rig: the advance routine with its table, and routines with their Summary.
{
	printf -- '---\ntype: routine\nexecutors: rig\nmaintainers: rig\nrequires-session-kind: standalone\n---\n# magic-team.advance.routine — the actual procedure\n\n# Summary\n\nThe rig advance.\n\n'
	printf '# Next iteration by document type\n\n| type | routine | gate |\n|---|---|---|\n'
	printf '| approval | - | yes |\n| proposal-root | magic-team.proposal.routine | yes |\n| proposal | magic-team.discuss.routine | no |\n| task | magic-team.verify.routine | yes |\n'
	printf '| project | magic-team.verify.routine | yes |\n| interview | magic-team.interview.routine | no |\n| dispatch | - | no |\n| change | - | no |\n| warning | - | no |\n\nProse after the table.\n'
} > "$rigSkills/magic-team/magic-team.advance.routine.md"
rigRoutine(){ ## short name, the Handles line (may be empty)
	printf -- '---\ntype: routine\nexecutors: rig\nmaintainers: rig\nrequires-session-kind: standalone\n---\n# magic-team.%s.routine — the actual procedure\n\n# Summary\n\nA rig routine.\n%s\n# Steps\n\n1. **work**: work.\n' "$1" "${2:+$'\n'$2$'\n'}" > "$rigSkills/magic-team/magic-team.$1.routine.md"
}
rigRoutine verify 'Handles: task, project'
rigRoutine investigate 'Handles: task, project'
rigRoutine discuss 'Handles: proposal'
rigRoutine proposal 'Handles: proposal, proposal-root'
rigRoutine interview 'Handles: interview'
rigRoutine grooming ''
rigItem(){ ## file name, type, extra lines...
	local itemName="$1" itemType="$2" ; shift 2
	printf '%s\n' '---' "type: $itemType" 'from: keeper-rig' 'owner: keeper-rig' "$@" '---' "# $itemType: a matter" > "$rigD/$itemName"
}
rigAsk(){ ## fn and arguments -- the output and rc, one line: rc and the output with tabs as `|`
	local askOut askRc=0
	askOut="$( env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.BoardItemHandler.include" ; "$@"' rig "$@" 2> /dev/null )" || askRc=$?
	printf '%s:%s' "$askRc" "$( printf '%s' "$askOut" | LC_ALL=C tr '\t\n' '| ' | LC_ALL=C sed 's/ *$//' )"
}

echo "-- 1. the table --"
rigAssert "nine rows, the routine as a file name, - for an action, the gate" "$( rigAsk AgentsToolsBoardTypeTable | LC_ALL=C sed 's/ /\n/g' | LC_ALL=C sed -n '1p;2p;4p;7p' | LC_ALL=C tr '\n' ' ' )" "0:approval|-|yes proposal-root|magic-team.proposal.routine.md|yes task|magic-team.verify.routine.md|yes dispatch|-|no "
rigAssert "the rows count" "$( env -i PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.BoardItemHandler.include" ; AgentsToolsBoardTypeTable | wc -l' | tr -d ' ' )" "9"

echo "-- 2. the default --"
rigItem t1.md task
rigAssert "a task not at its gate: the type's default" "$( rigAsk AgentsToolsBoardItemHandler "$rigD/t1.md" )" "0:routine|magic-team.verify.routine.md|default"
rigItem c1.md change
rigAssert "a change: an action, no routine" "$( rigAsk AgentsToolsBoardItemHandler "$rigD/c1.md" )" "0:routine|-|default"
rigItem p1.md proposal 'communication-channel-id: slack:CRIG:1.1'
rigAssert "a proposal with a communication channel is the root row, at its gate" "$( rigAsk AgentsToolsBoardItemHandler "$rigD/p1.md" )" "0:routine|magic-team.proposal.routine.md|gate"
rigItem p2.md proposal
rigAssert "a proposal with none is the proposal row" "$( rigAsk AgentsToolsBoardItemHandler "$rigD/p2.md" )" "0:routine|magic-team.discuss.routine.md|default"

echo "-- 3. a handler that handles the type --"
rigItem t2.md task 'handler-routine: magic-team.investigate.routine.md'
rigAssert "by file name: the handler is the routine" "$( rigAsk AgentsToolsBoardItemHandler "$rigD/t2.md" )" "0:routine|magic-team.investigate.routine.md|handler"
rigItem t3.md task 'handler-routine: investigate.routine'
rigAssert "as <name>.routine too" "$( rigAsk AgentsToolsBoardItemHandler "$rigD/t3.md" )" "0:routine|magic-team.investigate.routine.md|handler"

echo "-- 4. a flagged item names no routine, and nothing runs --"
rigItem t4.md task 'handler-routine: magic-team.nosuch.routine.md'
rigAssert "a handler that is no routine" "$( rigAsk AgentsToolsBoardItemHandler "$rigD/t4.md" | LC_ALL=C sed 's/|handler-routine:.*//' )" "3:flag|unknown-routine"
rigItem i1.md interview 'handler-routine: magic-team.investigate.routine.md'
rigAssert "a handler that does not handle the type" "$( rigAsk AgentsToolsBoardItemHandler "$rigD/i1.md" | LC_ALL=C sed 's/|handler-routine:.*//' )" "3:flag|type-mismatch"
rigItem t5.md task 'handler-routine: magic-team.grooming.routine.md'
rigAssert "a routine with no Handles line handles nothing" "$( rigAsk AgentsToolsBoardItemHandler "$rigD/t5.md" | LC_ALL=C sed 's/|handler-routine:.*//' )" "3:flag|type-mismatch"

echo "-- 5. a handler never overrides a gate --"
rigAssert "a task at its gate with a handler that is not the gate row" "$( rigAsk AgentsToolsBoardItemHandler "$rigD/t2.md" --at-gate | LC_ALL=C sed 's/|handler-routine:.*//' )" "3:flag|gate-override"
rigAssert "the same task at its gate with no handler runs the gate row" "$( rigAsk AgentsToolsBoardItemHandler "$rigD/t1.md" --at-gate )" "0:routine|magic-team.verify.routine.md|gate"
rigItem a1.md approval
rigAssert "an approval is always at its gate, and its row is an action" "$( rigAsk AgentsToolsBoardItemHandler "$rigD/a1.md" )" "0:routine|-|gate"
rigItem a2.md approval 'handler-routine: magic-team.investigate.routine.md'
rigAssert "an approval with a handler is flagged (it does not handle the type, and it would override the gate)" "$( rigAsk AgentsToolsBoardItemHandler "$rigD/a2.md" | LC_ALL=C grep -o -e '^3' -e 'type-mismatch' -e 'gate-override' | LC_ALL=C tr '\n' ' ' )" "3 type-mismatch gate-override "

echo "-- 6. no row, no type --"
rigItem w1.md idea
rigAssert "a type with no row and no handler is flagged for grooming" "$( rigAsk AgentsToolsBoardItemHandler "$rigD/w1.md" | LC_ALL=C sed 's/|the table has.*//' )" "3:flag|no-row"
printf '%s\n' '---' 'from: keeper-rig' '---' '# no type' > "$rigD/n1.md"
rigAssert "an item with no type cannot be decided" "$( rigAsk AgentsToolsBoardItemHandler "$rigD/n1.md" )" "2:"

echo "-- 7. the board digest prints the routine that runs each item next --"
rigStore="$rigTmp/store" rigFn="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
mkdir -p "$rigStore/board/pending" "$rigStore/inboxes/magic-coordinator/incoming"
printf '%s\n' '---' 'type: proposal' 'owner: keeper-rig' '---' '# a proposal' > "$rigStore/board/pending/proposal-20261028T0100Z-rig-plain.md"
printf '%s\n' '---' 'type: task' 'owner: keeper-rig' 'handler-routine: investigate.routine' '---' '# a task' > "$rigStore/board/pending/task-20261028T0101Z-rig-chosen.md"
printf '%s\n' '---' 'type: task' 'owner: keeper-rig' 'handler-routine: magic-team.nowhere.routine' '---' '# a task' > "$rigStore/board/pending/task-20261028T0102Z-rig-bad.md"
rigDigest(){ ## -- the digest of the rig board, with the rig skillset
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigStore" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" bash "$rigFn" --intern-op-session-context-scan magic-coordinator --state pending --all-types --context rig 2> /dev/null < /dev/null || :
}
rigOut="$( rigDigest )"
rigLineOf(){ ## item name -- the resolved line under the item's heading
	printf '%s\n' "$rigOut" | LC_ALL=C awk -v want="$1" 'index($0, "## pending/" want) == 1 { on = 1 ; next } /^## / { on = 0 } on && /^handler-routine \(resolved\):/ { print ; exit }'
}
rigAssert "an item with no handler: the default of its type, as the default" "$( rigLineOf proposal-20261028T0100Z-rig-plain.md )" "handler-routine (resolved): magic-team.discuss.routine.md (default)"
rigAssert "an item with a handler of its own: that routine, as the handler"  "$( rigLineOf task-20261028T0101Z-rig-chosen.md )" "handler-routine (resolved): magic-team.investigate.routine.md (handler)"
rigAssert "an item whose handler is no routine: flagged, and says nothing runs" "$( rigLineOf task-20261028T0102Z-rig-bad.md )" "handler-routine (resolved): FLAGGED unknown-routine -- nothing runs"

echo "-- 8. who may set handler-routine, and who may run a round --"
rigSpawned="$rigWs/.local/agents/spawned/rig" ; mkdir -p "$rigSpawned"
rigRecord(){ ## spawn id, member, routine file or -, live|ended -- a spawn record of this rig
	printf '%s\n' '---' "session-id: $1" "spawn-id: $1" "owner: $2" "status: spawn-started" ${3:+"routine: $3"} '---' > "$rigSpawned/$1.spawn.md"
	[ "$4" = live ] || printf 'exit-code: 0\n' | LC_ALL=C sed -i.bak '/^status: spawn-started$/r /dev/stdin' "$rigSpawned/$1.spawn.md" && rm -f "$rigSpawned/$1.spawn.md.bak"
}
rigRecord rig-sess-owner keeper-rig - live
rigRecord rig-sess-coord magic-coordinator - live
rigRecord rig-sess-groom keeper-other magic-team.grooming.routine.md live
rigRecord rig-sess-other keeper-other - live
rigSetAs(){ ## session id or - , item -- an edit of handler-routine as that caller; the rc and whether the item holds the value
	local setSess="$1" setItem="$2" setRc=0
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigStore" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		${setSess:+MDAT_SPAWN_SESSION_ID="$setSess"} MDLT_OPTION="--run-from-path $MDLT_ORIGIN" bash "$rigFn" --intern-op-board-upsert-move-edit pending "$setItem" --from-state:pending \
		--header:upsert:handler-routine:discuss.routine --context rig > /dev/null 2>&1 < /dev/null || setRc=$?
	printf '%s:%s' "$setRc" "$( LC_ALL=C grep -c '^handler-routine: discuss.routine$' "$rigStore/board/pending/$setItem" || : )"
}
rigSetItem(){ ## name -- a fresh proposal item
	printf '%s\n' '---' 'type: proposal' 'owner: keeper-rig' '---' '# a proposal' '' '## Decisions' '<!-- decisions-of: x -->' > "$rigStore/board/pending/$1"
}
rigSetItem proposal-20261028T0110Z-rig-a.md ; rigSetItem proposal-20261028T0111Z-rig-b.md ; rigSetItem proposal-20261028T0112Z-rig-c.md ; rigSetItem proposal-20261028T0113Z-rig-d.md
rigAssert "a member that is neither the coordinator nor a grooming run cannot set it: refused, the item unchanged" "$( rigSetAs rig-sess-other proposal-20261028T0110Z-rig-a.md )" "1:0"
rigAssert "the owner's own run cannot either" "$( rigSetAs rig-sess-owner proposal-20261028T0110Z-rig-a.md )" "1:0"
rigAssert "magic-coordinator sets it" "$( rigSetAs rig-sess-coord proposal-20261028T0111Z-rig-b.md )" "0:1"
rigAssert "and the item's Decisions record the change" "$( LC_ALL=C grep -c 'handler: handler-routine: - -> discuss.routine' "$rigStore/board/pending/proposal-20261028T0111Z-rig-b.md" || : )" "1"
rigAssert "a run of a grooming routine sets it" "$( rigSetAs rig-sess-groom proposal-20261028T0112Z-rig-c.md )" "0:1"
rigAssert "a call from no spawned session (a human at the console) sets it" "$( rigSetAs - proposal-20261028T0113Z-rig-d.md )" "0:1"
rigAssert "writing the value the item already holds is no change: any caller" "$( rigSetAs rig-sess-other proposal-20261028T0112Z-rig-c.md )" "0:1"
rigRoundAs(){ ## session id, item -- the round check as that caller, rc and the flag kind
	local roundOut roundRc=0
	roundOut="$( env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SPAWN_SESSION_ID="$1" \
		bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.BoardItemHandler.include" ; AgentsToolsBoardItemHandler "$@"' rig "$2" --for-round 2> /dev/null )" || roundRc=$?
	printf '%s:%s' "$roundRc" "$( printf '%s' "$roundOut" | LC_ALL=C awk -F'\t' '{ printf "%s%s", sep, $1 ":" $2 ; sep = "," }' )"
}
printf '%s\n' '---' 'type: proposal' 'owner: keeper-rig' '---' '# held' > "$rigStore/board/pending/proposal-20261028T0120Z-rig-held.md"
rigAssert "a live owner run is the writer: its round runs" "$( rigRoundAs rig-sess-owner "$rigStore/board/pending/proposal-20261028T0120Z-rig-held.md" )" "0:routine:magic-team.discuss.routine.md"
rigAssert "the coordinator is refused while a live run holds the item" "$( rigRoundAs rig-sess-coord "$rigStore/board/pending/proposal-20261028T0120Z-rig-held.md" )" "3:flag:held"
rigAssert "so is another member" "$( rigRoundAs rig-sess-other "$rigStore/board/pending/proposal-20261028T0120Z-rig-held.md" )" "3:flag:held"
rigAssert "the refusal names the holder" "$( env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SPAWN_SESSION_ID=rig-sess-coord bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.BoardItemHandler.include" ; AgentsToolsBoardItemHandler "$1" --for-round' rig "$rigStore/board/pending/proposal-20261028T0120Z-rig-held.md" 2> /dev/null | LC_ALL=C grep -c 'keeper-rig (rig-sess-owner)' || : )" "1"
rigRecord rig-sess-owner keeper-rig - ended
rigAssert "with no live holder the coordinator runs the round" "$( rigRoundAs rig-sess-coord "$rigStore/board/pending/proposal-20261028T0120Z-rig-held.md" )" "0:routine:magic-team.discuss.routine.md"
rigAssert "and another member does not" "$( rigRoundAs rig-sess-other "$rigStore/board/pending/proposal-20261028T0120Z-rig-held.md" )" "3:flag:held"

echo "-- 9. the table of the package's own advance routine --"
rigReal(){ ## fn and arguments -- the function against the package skillset alone (no rig skillset)
	env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.BoardItemHandler.include" ; "$@"' rig "$@" 2> /dev/null | LC_ALL=C tr '\t\n' '| '
}
rigAssert "the real table lists every running board type, each with a gate column" "$( rigReal AgentsToolsBoardTypeTable | LC_ALL=C tr ' ' '\n' | LC_ALL=C awk -F'|' 'NF == 3 && ($3 == "yes" || $3 == "no") { n++ } END { print (n >= 9) ? "ok" : "short:" n + 0 }' )" "ok"
printf '%s\n' '---' 'type: task' 'owner: keeper-rig' '---' '# a task' > "$rigStore/board/pending/task-20261028T0130Z-rig-real.md"
rigAssert "a task of the real package runs the verify routine at its default" "$( rigReal AgentsToolsBoardItemHandler "$rigStore/board/pending/task-20261028T0130Z-rig-real.md" )" "routine|magic-team.verify.routine.md|default "
rigAssert "the real skillset knows the routines of the table" "$( for rigName in magic-team.verify.routine magic-team.discuss.routine magic-team.proposal.routine magic-team.interview.routine ; do rigReal AgentsToolsRoutineFileOf "$rigName" ; done | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c 'skillset/magic-team/magic-team/magic-team\.' )" "4"

echo "-- 10. the digest shows who holds an item, beside its handler line --"
rigRecord rig-sess-owner keeper-rig - live
printf '%s\n' '---' 'type: proposal' 'owner: keeper-free' '---' '# free' > "$rigStore/board/pending/proposal-20261028T0121Z-rig-free.md"
rigDigestAs(){ ## session id -- the digest of the rig board, as that caller
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigStore" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SPAWN_SESSION_ID="$1" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" bash "$rigFn" --intern-op-session-context-scan magic-coordinator --state pending --all-types --context rig 2> /dev/null < /dev/null || :
}
rigHeldLine(){ ## digest text, item name -- the `held` line under the item's heading
	printf '%s\n' "$1" | LC_ALL=C awk -v want="$2" 'index($0, "## pending/" want) == 1 { on = 1 ; next } /^## / { on = 0 } on && /^held / { print ; exit }'
}
rigOut="$( rigDigestAs rig-sess-coord )"
rigAssert "an item a live run holds shows the holder, for the coordinator" "$( rigHeldLine "$rigOut" proposal-20261028T0120Z-rig-held.md )" "held (by keeper-rig (rig-sess-owner))"
rigAssert "an item nobody holds shows none, where the caller may run it (the coordinator)" "$( rigHeldLine "$rigOut" proposal-20261028T0121Z-rig-free.md )" ""
rigOut="$( rigDigestAs rig-sess-owner )"
rigAssert "the holder itself sees no hold on its own item" "$( rigHeldLine "$rigOut" proposal-20261028T0120Z-rig-held.md )" ""
rigOut="$( rigDigestAs rig-sess-other )"
rigAssert "an item nobody holds shows that only the coordinator runs it, for another member" "$( rigHeldLine "$rigOut" proposal-20261028T0121Z-rig-free.md )" "held (no live holder: only magic-coordinator runs it)"

echo "-- 11. the board writer takes an investigation --"
rigInvName=investigation-20261028T0830Z-rig-new.md
env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigStore" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
	bash "$rigFn" --intern-op-board-upsert-move-edit pending "$rigInvName" --create --upsert-from-stdin --context rig > /dev/null 2>&1 <<< "$( printf '%s\n' '---' 'type: investigation' 'owner: keeper-rig' '---' '# an investigation' )" || :
rigAssert "a created investigation is on the board with its type and contract" "$( LC_ALL=C grep -c -e '^type: investigation$' -e '^document-contract: board-item.investigation$' "$rigStore/board/pending/$rigInvName" 2> /dev/null || : )" "2"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ BOARD ITEM HANDLER CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'BOARD_ITEM_HANDLER: OK (%d assertions, offline)\n' "$rigPassCount"
