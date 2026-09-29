#!/usr/bin/env bash
## Behavioural check on --member-inbox-item-retain: an item in the member's own inbox is
## moved whole to board/retained/, a stub under the inbox's processed/ names where it
## went, and the inbox no longer holds it; a missing item, a path-like name, a non-.md
## name, a stray argument and an item already retained are each refused with nothing
## moved. Offline: a temp data store with no .git, so the commit step is a no-op here.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigTool="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
rigTmp="$( mktemp -d "${TMPDIR:-/tmp}/AgentsMemberInboxItemRetainCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws/.local" "$rigTmp/home" "$rigTmp/skills/magic-tester" "$rigTmp/data/inboxes/magic-tester" "$rigTmp/data/board"
printf -- '---\ntype: interview\n---\n\nkeep me whole\n' > "$rigTmp/data/inboxes/magic-tester/interview-20260929T1000Z-rig.md"
printf 'second\n' > "$rigTmp/data/inboxes/magic-tester/note-20260929T1000Z-second.md"
printf 'not md\n' > "$rigTmp/data/inboxes/magic-tester/note-20260929T1000Z-plain.txt"

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
	LC_ALL=C grep -q -F -- "$2" "$1" 2>/dev/null && printf yes || printf no
}
rigIs(){ ## path
	[ -f "$1" ] && printf yes || printf no
}
rigRetain(){ ## arguments after the member
	rigRc=0
	( cd "$rigTmp/ws" && env HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_DATA_ROOT="$rigTmp/data" \
		bash "$rigTool" --member-inbox-item-retain magic-tester "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" || rigRc=$?
}
rigInbox="$rigTmp/data/inboxes/magic-tester"
rigRetained="$rigTmp/data/board/retained"

echo "-- an item in the member's own inbox --"
rigRetain interview-20260929T1000Z-rig.md
rigAssert "it is retained, rc 0"                     "$rigRc" 0
rigAssert "it prints where it went"                  "$( rigHolds "$rigTmp/out" 'RETAINED board://retained/interview-20260929T1000Z-rig.md' )" yes
rigAssert "board/retained/ holds it"                 "$( rigIs "$rigRetained/interview-20260929T1000Z-rig.md" )" yes
rigAssert "whole: its body is there"                 "$( rigHolds "$rigRetained/interview-20260929T1000Z-rig.md" 'keep me whole' )" yes
rigAssert "the inbox no longer holds it"             "$( rigIs "$rigInbox/interview-20260929T1000Z-rig.md" )" no
rigAssert "a stub is left in processed/"             "$( rigIs "$rigInbox/processed/interview-20260929T1000Z-rig.md" )" yes
rigAssert "the stub names the board path"            "$( rigHolds "$rigInbox/processed/interview-20260929T1000Z-rig.md" 'retained-to: board://retained/interview-20260929T1000Z-rig.md' )" yes
rigAssert "the stub does not carry the body"         "$( rigHolds "$rigInbox/processed/interview-20260929T1000Z-rig.md" 'keep me whole' )" no

echo "-- refusals, nothing moved --"
rigRetain interview-20260929T1000Z-rig.md
rigAssert "an item already retained fails"           "$( [ "$rigRc" -ne 0 ] && echo non-zero || echo 0 )" non-zero
rigRetain note-20260929T1000Z-missing.md
rigAssert "a missing item fails"                     "$( [ "$rigRc" -ne 0 ] && echo non-zero || echo 0 )" non-zero
rigAssert "naming it"                                "$( rigHolds "$rigTmp/err" 'note-20260929T1000Z-missing.md' )" yes
rigRetain ../magic-tester/note-20260929T1000Z-second.md
rigAssert "a path-like name fails"                   "$( [ "$rigRc" -ne 0 ] && echo non-zero || echo 0 )" non-zero
rigAssert "and the item stays"                       "$( rigIs "$rigInbox/note-20260929T1000Z-second.md" )" yes
rigRetain note-20260929T1000Z-plain.txt
rigAssert "a non-.md name fails"                     "$( [ "$rigRc" -ne 0 ] && echo non-zero || echo 0 )" non-zero
rigAssert "and the file stays"                       "$( rigIs "$rigInbox/note-20260929T1000Z-plain.txt" )" yes
rigRetain note-20260929T1000Z-second.md extra
rigAssert "a stray argument fails"                   "$( [ "$rigRc" -ne 0 ] && echo non-zero || echo 0 )" non-zero
rigAssert "and the item stays"                       "$( rigIs "$rigInbox/note-20260929T1000Z-second.md" )" yes
rigAssert "and nothing reached board/retained/"      "$( rigIs "$rigRetained/note-20260929T1000Z-second.md" )" no

echo "-- --member-board-retained-list enumerates board-retained --"
rigList(){ ## the member
	rigRc=0
	( cd "$rigTmp/ws" && env HOME="$rigTmp/home" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_DATA_ROOT="$rigTmp/data" \
		bash "$rigTool" --member-board-retained-list "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" || rigRc=$?
}
printf -- '---\ntype: task\nrecheck-date: 2026-10-01\n---\n\nbody not listed\n' > "$rigRetained/task-20260929T1000Z-kept.md"
rigList magic-tester
rigAssert "it lists, rc 0"                           "$rigRc" 0
rigAssert "the retained item is named"               "$( rigHolds "$rigTmp/out" '- interview-20260929T1000Z-rig.md' )" yes
rigAssert "with its type header"                     "$( rigHolds "$rigTmp/out" '    type: interview' )" yes
rigAssert "a second item is named"                   "$( rigHolds "$rigTmp/out" '- task-20260929T1000Z-kept.md' )" yes
rigAssert "with its recheck-date"                    "$( rigHolds "$rigTmp/out" '    recheck-date: 2026-10-01' )" yes
rigAssert "bodies are not printed"                   "$( rigHolds "$rigTmp/out" 'body not listed' )" no
rigAssert "the count is 2"                           "$( rigHolds "$rigTmp/out" '2 item(s) in board-retained' )" yes
rigList magic-nobody
rigAssert "an unknown member fails"                  "$( [ "$rigRc" -ne 0 ] && echo non-zero || echo 0 )" non-zero

echo "-- $rigPassCount passed, $rigFailCount failed --"
[ "$rigFailCount" -eq 0 ]
