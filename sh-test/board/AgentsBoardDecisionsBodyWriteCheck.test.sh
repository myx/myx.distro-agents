#!/usr/bin/env bash
## Behavioural check on a board item's recorded `## Decisions` across a body write (board task
## 2026-11-09T1400Z): two writers on one item, one recording a decision and the other writing the
## body. Held: the recorded block is kept whole on every whole-body mode; a body that brings
## decision lines of its own merges them and never replaces the block; a write derived from the
## item that would drop a recorded line is refused, that line named, and nothing written; a patch
## and a script of ordinary body text still work; a whole-body write over an existing item says so
## and names the patch form. The item's Change calls `--from-file` a body mode, and this operator
## serves no such option, which the last case pins. Offline: a temp data root and a temp workspace
## of the check's own, never the live store.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigToolsFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigQuestFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsQuestions.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigToolsFn" ] || rigRefuse "dispatcher not found: $rigToolsFn"
[ -f "$rigQuestFn" ] || rigRefuse "questions dispatcher not found: $rigQuestFn"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigOut="$( rigTempDir AgentsBoardDecisionsBodyWriteCheck )" || exit 1
rigOut="$( cd "$rigOut" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigOut"' EXIT
rigStore="$rigOut/data"
rigWs="$rigOut/ws"
for rigState in backlog pending running review blocked parked processed archived retained ; do
	mkdir -p "$rigStore/board/$rigState" || rigRefuse "could not create the rig's board"
done
mkdir -p "$rigWs/.local" "$rigOut/home/skills/magic-coordinator" "$rigOut/home/skills/magic-developer" || rigRefuse "could not create the rig"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigOut/home/skills/magic-coordinator/magic-coordinator.basic.md"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigOut/home/skills/magic-developer/magic-developer.basic.md"

rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
## One op through a named dispatcher. The status lands in rigRc.
rigRun(){ ## dispatcher-fn, outname, args...
	local rigFn="$1" opOut="$2" ; shift 2
	rigRc=0
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig \
		HOME="$rigOut/home" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigStore" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigOut/home/skills" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" LC_ALL=C \
		bash "$rigFn" "$@" ) > "$rigOut/$opOut.out" 2> "$rigOut/$opOut.err" || rigRc=$?
}
rigDecisions(){ ## item file -> its Decisions section lines, in file order
	LC_ALL=C awk '/^## Decisions[ \t]*$/ { on = 1 ; next } on && /^##? / { on = 0 } on && /^- / { print }' "$1" 2>/dev/null
}
## The whole document writer B hands over, with real newlines. A second argument
## appends a Decisions block the writer built itself.
rigDoc(){ ## body text, [decisions-block text]
	printf '%s\n' '---' 'type: task' 'document-contract: board-item.task' 'from: keeper-myx' \
		'owner: magic-developer' 'date: 2026-11-01 09:50 +0000' '---' '' '# Task: rig body write' '' "$1"
	[ -z "${2:-}" ] || printf '\n## Decisions\n<!-- decisions-of: %s -->\n\n%s\n' "$rigItem" "$2"
}
rigItemPath(){ printf '%s/board/running/%s.md' "$rigStore" "$rigItem" ; }
## A fresh item carrying one recorded decision.
rigSeeded(){ ## item stamp, decision text
	rigItem="task-20261101T${1}Z-rig"
	rigRun "$rigToolsFn" "seed-$1" --intern-op-board-upsert-move-edit running "$rigItem.md" --create --upsert-from-stdin --context rig <<< "$( rigDoc "Body of $rigItem." )"
	[ "$rigRc" = 0 ] || rigRefuse "the seed create of $rigItem failed: $( cat "$rigOut/seed-$1.err" )"
	rigRun "$rigQuestFn" "seedrec-$1" --record-decision --team-member magic-coordinator "$rigItem" --kind clarification --text "$2"
	[ "$rigRc" = 0 ] || rigRefuse "the seed decision on $rigItem failed: $( cat "$rigOut/seedrec-$1.err" )"
	[ "$( rigDecisions "$( rigItemPath )" | LC_ALL=C grep -c -F -- "$2" )" = 1 ] \
		|| rigRefuse "the seed decision of $rigItem cannot be read back -- the rig cannot see its own subject"
}

echo "== 1. whole body as one argument, no Decisions in it =="
rigSeeded 1000 "RIG-DECISION-A must stand."
rigRun "$rigToolsFn" b1 --intern-op-board-upsert-move-edit running "$rigItem.md" --from-state:running --upsert-body:"$( rigDoc "The widget keeps its second line." )" --context rig
rigAssert "the body write is accepted"              "$rigRc" 0
rigAssert "the new body text is stored"             "$( LC_ALL=C grep -c '^The widget keeps its second line\.$' "$( rigItemPath )" )" 1
rigAssert "CLAIM 1: the decision stands"            "$( rigDecisions "$( rigItemPath )" | LC_ALL=C grep -c 'RIG-DECISION-A must stand\.' )" 1
rigAssert "CLAIM 2: stderr says the item existed"   "$( LC_ALL=C grep -ci 'exist' "$rigOut/b1.err" )" 1
rigAssert "CLAIM 3: stderr names the patch form"    "$( LC_ALL=C grep -c -F -- '--edit-patch-from-stdin' "$rigOut/b1.err" )" 1

echo "== 2. whole body through stdin, decision left out =="
rigSeeded 1001 "RIG-DECISION-C must stand."
rigRun "$rigToolsFn" b2 --intern-op-board-upsert-move-edit running "$rigItem.md" --from-state:running --upsert-from-stdin --context rig <<< "$( rigDoc "A third body with no decisions." )"
rigAssert "the body write is accepted"              "$rigRc" 0
rigAssert "the new body text is stored"             "$( LC_ALL=C grep -c '^A third body with no decisions\.$' "$( rigItemPath )" )" 1
rigAssert "CLAIM 4: the decision stands"            "$( rigDecisions "$( rigItemPath )" | LC_ALL=C grep -c 'RIG-DECISION-C must stand\.' )" 1
rigAssert "one Decisions section only"              "$( LC_ALL=C grep -c '^## Decisions' "$( rigItemPath )" )" 1

echo "== 3. whole body that carries its own decision line =="
rigSeeded 1002 "RIG-DECISION-D must stand."
rigRun "$rigToolsFn" b3 --intern-op-board-upsert-move-edit running "$rigItem.md" --from-state:running --upsert-body:"$( rigDoc "A fourth body." "- 2026-11-01T11:00Z magic-developer clarification: RIG-DECISION-E new line." )" --context rig
rigAssert "CLAIM 5: the carrying body is accepted"  "$rigRc" 0
rigAssert "CLAIM 6: the carried line is stored"     "$( rigDecisions "$( rigItemPath )" | LC_ALL=C grep -c 'RIG-DECISION-E new line\.' )" 1
rigAssert "CLAIM 7: merging keeps D"                "$( rigDecisions "$( rigItemPath )" | LC_ALL=C grep -c 'RIG-DECISION-D must stand\.' )" 1
rigAssert "one Decisions section only"              "$( LC_ALL=C grep -c '^## Decisions' "$( rigItemPath )" )" 1

echo "== 4. a patch that rewrites a decision line =="
rigSeeded 1003 "RIG-DECISION-F must stand."
rigRun "$rigToolsFn" b4 --intern-op-board-upsert-move-edit running "$rigItem.md" --from-state:running --edit-patch-from-stdin --context rig \
	<<< '[{"old":"RIG-DECISION-F must stand.","new":"RIG-DECISION-F was reworded."}]'
rigAssert "CLAIM 8: the patch is refused"           "$( [ "$rigRc" -ne 0 ] && printf refused || printf taken )" refused
rigAssert "CLAIM 9: the refusal names the line"     "$( LC_ALL=C grep -c 'RIG-DECISION-F must stand\.' "$rigOut/b4.err" )" 1
rigAssert "the original line still stands"          "$( rigDecisions "$( rigItemPath )" | LC_ALL=C grep -c 'RIG-DECISION-F must stand\.' )" 1
rigAssert "and the rewording was not written"       "$( LC_ALL=C grep -c 'RIG-DECISION-F was reworded\.' "$( rigItemPath )" )" 0

echo "== 5. CONTROL DIRECTION: a patch of ordinary body text =="
rigSeeded 1004 "RIG-DECISION-G must stand."
rigRun "$rigToolsFn" b5 --intern-op-board-upsert-move-edit running "$rigItem.md" --from-state:running --edit-patch-from-stdin --context rig \
	<<< '[{"old":"Body of task-20261101T1004Z-rig.","new":"A patched body line."}]'
rigAssert "a body patch is accepted"                "$rigRc" 0
rigAssert "the patched line is stored"              "$( LC_ALL=C grep -c '^A patched body line\.$' "$( rigItemPath )" )" 1
rigAssert "and the decision survives that patch"    "$( rigDecisions "$( rigItemPath )" | LC_ALL=C grep -c 'RIG-DECISION-G must stand\.' )" 1

echo "== 6. a script that cuts the Decisions section off =="
rigSeeded 1005 "RIG-DECISION-H must stand."
rigRun "$rigToolsFn" b6 --intern-op-board-upsert-move-edit running "$rigItem.md" --from-state:running --edit-script-from-stdin:awk --context rig <<< '/^## Decisions/ { exit } { print }'
rigAssert "CLAIM 10: the script write is refused"   "$( [ "$rigRc" -ne 0 ] && printf refused || printf taken )" refused
rigAssert "CLAIM 11: the refusal names the line"    "$( LC_ALL=C grep -c 'RIG-DECISION-H must stand\.' "$rigOut/b6.err" )" 1
rigAssert "the decision survives untouched"         "$( rigDecisions "$( rigItemPath )" | LC_ALL=C grep -c 'RIG-DECISION-H must stand\.' )" 1

echo "== 7. CONTROL DIRECTION: a script that appends a section =="
rigSeeded 1006 "RIG-DECISION-I must stand."
rigRun "$rigToolsFn" b7 --intern-op-board-upsert-move-edit running "$rigItem.md" --from-state:running --edit-script-from-stdin:awk --context rig <<< '{ print } END { print "" ; print "## Notes" ; print "" ; print "A later section." }'
rigAssert "a section-appending script is accepted"  "$rigRc" 0
rigAssert "its section is stored"                   "$( LC_ALL=C grep -c '^A later section\.$' "$( rigItemPath )" )" 1
rigAssert "and the decision survives it"            "$( rigDecisions "$( rigItemPath )" | LC_ALL=C grep -c 'RIG-DECISION-I must stand\.' )" 1

echo "== 8. the option the item's Change calls --from-file =="
rigSeeded 1007 "RIG-DECISION-J must stand."
rigRun "$rigToolsFn" b8 --intern-op-board-upsert-move-edit running "$rigItem.md" --from-state:running --from-file "$rigOut/b8.body" --context rig
rigAssert "this operator serves no --from-file body mode" "$( [ "$rigRc" -ne 0 ] && printf refused || printf taken )" refused
rigAssert "and the refusal names the option"        "$( LC_ALL=C grep -c -F -- '--from-file' "$rigOut/b8.err" )" 1
rigAssert "the item is untouched"                   "$( rigDecisions "$( rigItemPath )" | LC_ALL=C grep -c 'RIG-DECISION-J must stand\.' )" 1

printf '\n'
if [ "$rigFail" -ne 0 ] ; then
	echo "BOARD-DECISIONS-BODY-WRITE: FAILED, $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	exit 1
fi
echo "BOARD-DECISIONS-BODY-WRITE: OK ($rigPass assertions)"
