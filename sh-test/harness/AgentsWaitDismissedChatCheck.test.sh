#!/usr/bin/env bash
## Behavioural check on the dismissal among the messages of a Wait (AgentsHarnessWaitDismissed.awk) for the form the session chat file gives a
## message (F3.3, F9.2): the `chat:` source of a Wait returns the messages of the session thread as blocks of the chat file, a header
## `<iso-time> <from> -> <to>:` and the body, and a DISMISSED among them dismisses a run by the rule it always did. Held, run on samples of a
## Wait's output:
##   1. a message in the Slack form, `<ts> | <user> | ...` with the team's send header, still dismisses the member it addresses
##   2. a chat block addressed to the member, whose body is DISMISSED, dismisses it; the line it prints names the time and the sender
##   3. one addressed to another member, to all, or from the member itself, dismisses no one
##   4. `DISMISSED <member>` typed in a chat block dismisses it, whoever it is addressed to; a body that only holds the word dismisses no one
##   5. the block is read to its end: the wait's own lines and the next block close it, and a later message is not part of it
## Offline: the awk alone, on files of this check's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHere/harness/AgentsHarnessWaitDismissed.awk" ] && [ -f "$rigHere/questions/AgentsDismissalMatch.awk" ] || rigRefuse "the awk files are not at the origin this workspace resolves: $rigHere"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWaitDismissedChatCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
## What the awk says of a wait's output on its standard input: the line it prints, or `none`.
rigDismissal(){ ## member -- the output on stdin
	local dismissOut dismissRc=0
	dismissOut="$( dismissalMember="$1" LC_ALL=C awk -f "$rigHere/questions/AgentsDismissalMatch.awk" -f "$rigHere/harness/AgentsHarnessWaitDismissed.awk" )" || dismissRc=$?
	if [ "$dismissRc" = "0" ] ; then printf '%s' "$dismissOut" ; else printf 'none' ; fi
}
rigWait(){ ## the blocks of a wait's output, as the lines after them
	printf '%s\n' 'WAIT-RESULT: RECEIVED' '# member: rig-member' '# sources: replies:s chat:s'
	printf '%s\n' "$@"
}
RIGSEND='1760000000.000100 | UBOT01 | [sender: rig-boss] 🔏 *_rig-boss_* → *_rig-member_* <@UMEM1>. DISMISSED'

echo "-- 1. the Slack form --"
rigAssert "a send header addressing the member, then DISMISSED"       "$( rigWait '# arrived on: slack:C1:1.1:conversation' '# --- what that source holds now follows ---' "$RIGSEND" '# --- end ---' | rigDismissal rig-member )" "1760000000.000100 | UBOT01"
rigAssert "addressed to another member: no one"                       "$( rigWait '# arrived on: slack:C1:1.1:conversation' '# --- what that source holds now follows ---' "$RIGSEND" '# --- end ---' | rigDismissal rig-other )" none

echo "-- 2. a chat block --"
rigAssert "addressed to the member, the body DISMISSED"               "$( rigWait '# arrived on: slack:C1:1.1' '# --- what that source holds now follows ---' '2026-10-19T10:00:00Z rig-boss -> rig-member:' 'DISMISSED' '' '# --- end ---' | rigDismissal rig-member )" "2026-10-19T10:00:00Z | rig-boss"
rigAssert "a full stop after the word is the word"                    "$( rigWait '# arrived on: slack:C1:1.1' '# --- what that source holds now follows ---' '2026-10-19T10:00:00Z rig-boss -> rig-other,rig-member:' 'DISMISSED.' '' '# --- end ---' | rigDismissal rig-member )" "2026-10-19T10:00:00Z | rig-boss"

echo "-- 3. who it dismisses --"
rigAssert "addressed to another member"                               "$( rigWait '# arrived on: slack:C1:1.1' '# --- what that source holds now follows ---' '2026-10-19T10:00:00Z rig-boss -> rig-other:' 'DISMISSED' '' '# --- end ---' | rigDismissal rig-member )" none
rigAssert "addressed to all"                                          "$( rigWait '# arrived on: slack:C1:1.1' '# --- what that source holds now follows ---' '2026-10-19T10:00:00Z rig-boss -> all:' 'DISMISSED' '' '# --- end ---' | rigDismissal rig-member )" none
rigAssert "from the member itself"                                    "$( rigWait '# arrived on: slack:C1:1.1' '# --- what that source holds now follows ---' '2026-10-19T10:00:00Z rig-member -> rig-member:' 'DISMISSED' '' '# --- end ---' | rigDismissal rig-member )" none

echo "-- 4. typed --"
rigAssert "DISMISSED <member> typed, to all"                          "$( rigWait '# arrived on: slack:C1:1.1' '# --- what that source holds now follows ---' '2026-10-19T10:00:00Z URIGHUM1 -> all:' 'DISMISSED rig-member' '' '# --- end ---' | rigDismissal rig-member )" "2026-10-19T10:00:00Z | URIGHUM1"
rigAssert "the word among others is no dismissal"                     "$( rigWait '# arrived on: slack:C1:1.1' '# --- what that source holds now follows ---' '2026-10-19T10:00:00Z rig-boss -> rig-member:' 'it was DISMISSED earlier' '' '# --- end ---' | rigDismissal rig-member )" none

echo "-- 5. the block is read to its end --"
rigAssert "a dismissal after another block's text is read as its own" "$( rigWait '# arrived on: slack:C1:1.1' '# --- what that source holds now follows ---' '2026-10-19T09:00:00Z rig-boss -> rig-member:' 'a plain word first' '' '2026-10-19T10:00:00Z rig-boss -> rig-member:' 'DISMISSED' '' '# --- end ---' | rigDismissal rig-member )" "2026-10-19T10:00:00Z | rig-boss"
rigAssert "a DISMISSED line after the block's end is not part of it"  "$( rigWait '# arrived on: slack:C1:1.1' '# --- what that source holds now follows ---' '2026-10-19T09:00:00Z rig-boss -> rig-member:' 'a plain word first' '' '# --- end ---' 'DISMISSED' | rigDismissal rig-member )" none

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WAIT DISMISSED CHAT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_DISMISSED_CHAT: OK (%d assertions, offline)\n' "$rigPassCount"
