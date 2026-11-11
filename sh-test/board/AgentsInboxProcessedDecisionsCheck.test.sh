#!/usr/bin/env bash
## Behavioural check on an inbox item's recorded `## Decisions` across --mark-inbox-processed (board
## task 2026-11-09T1400Z, whose Decisions of 18:08Z name this the one unguarded call of the same
## shape as a board body write). Held: a whole-body mark keeps the recorded block; a body that
## brings decision lines of its own merges them; a patch that rewrites a decision line is refused,
## that line named, and nothing written; a patch of ordinary body text still works; and a plain
## mark, which writes no body of its own, keeps the block too. Offline: a temp data root and a temp
## workspace of the check's own, never the live store.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigItemsFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsItems.fn.sh"
rigMember="magic-developer"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigItemsFn" ] || rigRefuse "items dispatcher not found: $rigItemsFn"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigOut="$( rigTempDir AgentsInboxProcessedDecisionsCheck )" || exit 1
rigOut="$( cd "$rigOut" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigOut"' EXIT
rigStore="$rigOut/data"
rigWs="$rigOut/ws"
mkdir -p "$rigStore/inboxes/$rigMember/incoming" "$rigStore/inboxes/$rigMember/processed" \
	"$rigWs/.local" "$rigOut/home/skills/$rigMember" || rigRefuse "could not create the rig"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigOut/home/skills/$rigMember/$rigMember.basic.md"

rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
rigRun(){ ## outname, args...
	local opOut="$1" ; shift
	rigRc=0
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig MDAT_SPAWN_AGENT="$rigMember" \
		HOME="$rigOut/home" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigStore" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigOut/home/skills" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" LC_ALL=C \
		bash "$rigItemsFn" "$@" ) > "$rigOut/$opOut.out" 2> "$rigOut/$opOut.err" || rigRc=$?
}
rigWhere(){ ## prints the item's live path, incoming or processed
	if [ -f "$rigStore/inboxes/$rigMember/incoming/$rigItem" ] ; then
		printf '%s/inboxes/%s/incoming/%s' "$rigStore" "$rigMember" "$rigItem"
	else
		printf '%s/inboxes/%s/processed/%s' "$rigStore" "$rigMember" "$rigItem"
	fi
}
rigDecisions(){ ## item file -> its Decisions section lines, in file order
	LC_ALL=C awk '/^## Decisions[ \t]*$/ { on = 1 ; next } on && /^##? / { on = 0 } on && /^- / { print }' "$1" 2>/dev/null
}
## A fresh note carrying one recorded decision line.
rigSeeded(){ ## item stamp, decision text
	rigItem="note-20261101T${1}Z-rig.md"
	rigRun "seed-$1" --upsert-inbox-note "$rigItem" --from-member "$rigMember" <<< "$( printf -- '---\ntype: note\nowner: %s\n---\n\n# Note: rig\n\nBody of %s.\n\n## Decisions\n<!-- decisions-of: %s -->\n\n- 2026-11-01T12:00Z magic-developer resolved: %s\n' "$rigMember" "${rigItem%.md}" "${rigItem%.md}" "$2" )"
	[ "$rigRc" = 0 ] || rigRefuse "the seed note of $rigItem failed: $( cat "$rigOut/seed-$1.err" )"
	[ "$( rigDecisions "$( rigWhere )" | LC_ALL=C grep -c -F -- "$2" )" = 1 ] \
		|| rigRefuse "the seed decision of $rigItem cannot be read back -- the rig cannot see its own subject"
}
rigNoteDoc(){ ## body text, [decisions-block text]
	printf -- '---\ntype: note\nowner: %s\n---\n\n# Note: rig\n\n%s\n' "$rigMember" "$1"
	[ -z "${2:-}" ] || printf '\n## Decisions\n<!-- decisions-of: %s -->\n\n%s\n' "${rigItem%.md}" "$2"
}

echo "== 1. the unguarded call: --mark-inbox-processed carrying a whole new body =="
rigSeeded 1200 "RIG-NOTE-DECISION-A must stand."
rigRun m1 --mark-inbox-processed "$rigItem" --upsert-from-stdin <<< "$( rigNoteDoc "Second body line." )"
rigAssert "the mark succeeds"                        "$rigRc" 0
rigAssert "the new body line is stored"              "$( LC_ALL=C grep -c '^Second body line\.$' "$( rigWhere )" )" 1
rigAssert "CLAIM 1: the decision stands"             "$( rigDecisions "$( rigWhere )" | LC_ALL=C grep -c 'RIG-NOTE-DECISION-A must stand\.' )" 1
rigAssert "one Decisions section only"               "$( LC_ALL=C grep -c '^## Decisions' "$( rigWhere )" )" 1

echo "== 2. a body that carries a decision line of its own =="
rigSeeded 1201 "RIG-NOTE-DECISION-B must stand."
rigRun m2 --mark-inbox-processed "$rigItem" --upsert-from-stdin <<< "$( rigNoteDoc "Third body line." "- 2026-11-01T13:00Z magic-developer clarification: RIG-NOTE-DECISION-C new line." )"
rigAssert "the mark succeeds"                        "$rigRc" 0
rigAssert "CLAIM 2: the carried line is stored"      "$( rigDecisions "$( rigWhere )" | LC_ALL=C grep -c 'RIG-NOTE-DECISION-C new line\.' )" 1
rigAssert "CLAIM 3: merging keeps B"                 "$( rigDecisions "$( rigWhere )" | LC_ALL=C grep -c 'RIG-NOTE-DECISION-B must stand\.' )" 1

echo "== 3. a patch that rewrites a decision line =="
rigSeeded 1202 "RIG-NOTE-DECISION-D must stand."
rigRun m3 --mark-inbox-processed "$rigItem" --edit-patch-from-stdin <<< '[{"old":"RIG-NOTE-DECISION-D must stand.","new":"RIG-NOTE-DECISION-D was reworded."}]'
rigAssert "CLAIM 4: the patch is refused"            "$( [ "$rigRc" -ne 0 ] && printf refused || printf taken )" refused
rigAssert "CLAIM 5: the refusal names the line"      "$( LC_ALL=C grep -c 'RIG-NOTE-DECISION-D must stand\.' "$rigOut/m3.err" )" 1
rigAssert "the original line still stands"           "$( rigDecisions "$( rigWhere )" | LC_ALL=C grep -c 'RIG-NOTE-DECISION-D must stand\.' )" 1
rigAssert "and the rewording was not written"        "$( LC_ALL=C grep -c 'RIG-NOTE-DECISION-D was reworded\.' "$( rigWhere )" )" 0

echo "== 4. CONTROL DIRECTION: a patch of ordinary body text =="
rigSeeded 1203 "RIG-NOTE-DECISION-E must stand."
rigRun m4 --mark-inbox-processed "$rigItem" --edit-patch-from-stdin <<< '[{"old":"Body of note-20261101T1203Z-rig.","new":"A patched body line."}]'
rigAssert "a body patch is accepted"                 "$rigRc" 0
rigAssert "the patched line is stored"               "$( LC_ALL=C grep -c '^A patched body line\.$' "$( rigWhere )" )" 1
rigAssert "and the decision survives that patch"     "$( rigDecisions "$( rigWhere )" | LC_ALL=C grep -c 'RIG-NOTE-DECISION-E must stand\.' )" 1

echo "== 5. CONTROL DIRECTION: a plain mark, which writes no body of its own =="
rigSeeded 1204 "RIG-NOTE-DECISION-F must stand."
rigRun m5 --mark-inbox-processed "$rigItem"
rigAssert "a plain mark succeeds"                    "$rigRc" 0
rigAssert "the stamp is written"                     "$( LC_ALL=C awk 'NR == 1 { next } $0 == "---" { exit } index($0, "processed-at: ") == 1 { print 1 ; exit }' "$( rigWhere )" )" 1
rigAssert "and the decision stands"                  "$( rigDecisions "$( rigWhere )" | LC_ALL=C grep -c 'RIG-NOTE-DECISION-F must stand\.' )" 1

printf '\n'
if [ "$rigFail" -ne 0 ] ; then
	echo "INBOX-PROCESSED-DECISIONS: FAILED, $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	exit 1
fi
echo "INBOX-PROCESSED-DECISIONS: OK ($rigPass assertions)"
