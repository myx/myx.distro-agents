#!/usr/bin/env bash
## Behavioural check on the instruction line delivered with a member's unprocessed inbox items (S18.3): wherever the tooling hands
## a member its unprocessed items -- an inbox section of the session-context scan, and a Wait result for its own inbox -- the block
## ends with one line saying what the reading run does with each item. Held:
##   1. the scan: a section holding an unprocessed item ends with the line
##   2. the scan: a section holding no item carries no line, and says so in its NOTE as before
##   3. the scan: the read-only widened inbox of another member carries none -- its items are not the acting member's to mark
##   4. the Wait: the arrived block ends with the line, after the item it delivers
##   5. the Wait: an empty inbox is no arrival -- the line alone never makes one, so the wait says TIMEOUT
##   6. a NAMED unprocessed item, whose block is printed on its own (--item --item-include-inbox with every section declined), ends
##      with the line too: it delivers an unprocessed item as a section does, so it says what to do with it
##   7. the named read of an item ALREADY processed carries none: it is not an unprocessed item, so nothing is owed on it
## Red before the change: no such line is delivered anywhere, and the scan's sections pass straight from the last item to the next heading.
## Offline: no comms source is read or configured; every tree is this rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPkg="$rigOrigin/myx/myx.distro-agents"
rigTool="$rigPkg/sh-scripts/DistroAgentsTools.fn.sh"
rigInstruction='inbox items: handle each item, then trash it with --trash-inbox-item, or --mark-inbox-processed where the record must stay, or keep it with a stated reason.'
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsInboxInstructionLineCheck )" || exit 1
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
## The whole rig, made fresh: a workspace, a team data root, a skillset with three members in it.
rigScene(){ ## name
	rigDir="$rigTmp/$1" ; rigWs="$rigDir/ws" ; rigData="$rigDir/data" ; rigSkills="$rigDir/skills" ; rigHome="$rigDir/home"
	rm -rf "$rigDir"
	mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigHome" \
		"$rigData/inboxes/rig-member/incoming" "$rigData/inboxes/rig-other/incoming" "$rigData/board" \
		"$rigSkills/rig-member" "$rigSkills/rig-other"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/rig-member/rig-member.basic.md"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/rig-other/rig-other.basic.md"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
}
rigItem(){ ## member, item name, title
	printf -- '---\ntype: %s\nfrom: rig-other\n---\n\n# %s\n\nA rig body.\n' "${2%%-*}" "$3" > "$rigData/inboxes/$1/incoming/$2"
}
## One call of the tool, in the rig's own workspace and team data, guarded to stay inside the rig.
rigCall(){ ## result name, the operation's words...
	local callName="$1" callRc=0
	shift
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" \
		MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" MDAT_WAIT_REMIND=off RIG_TMP="$rigTmp" RIG_TOOL="$rigTool" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MDAT_DATA_ROOT outside the rig tree" >&2 ; exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_TOOL" "$@"
		' rig "$@" > "$rigDir/$callName.out" 2> "$rigDir/$callName.err" < /dev/null || callRc=$?
	printf '%s' "$callRc" > "$rigDir/$callName.rc"
}
## Whether a section of the scan ends with the instruction line: 1 where its last non-blank line is that line, else 0.
## A section runs from its own heading to the next inbox-section heading.
rigSectionEnds(){ ## file, section heading
	LC_ALL=C awk -v sec="$2" -v want="$rigInstruction" '
		$0 == sec { inside = 1 ; last = "" ; seen = 1 ; next }
		inside && /^## (Active Inbox Inquiry Items|Current Inbox Reflections|Current Inbox Notes|Other Inbox Items|Additional Inbox)/ { inside = 0 ; next }
		inside && /^$/ { next }
		inside { last = $0 }
		END { if ( !seen ) { print "nosection" ; exit } ; print ( last == want ) ? 1 : 0 }
	' "$rigDir/$1.out"
}
## Whether a result's last non-blank line is the instruction: 1 where it is, else 0.
rigLastLineIs(){ ## result name
	LC_ALL=C awk -v want="$rigInstruction" 'NF { last = $0 } END { print ( last == want ) ? 1 : 0 }' "$rigDir/$1.out" 2> /dev/null
}
## How many times the instruction line stands anywhere in a result.
rigInstructionCount(){ ## result name
	LC_ALL=C grep -c -x -F -- "$rigInstruction" "$rigDir/$1.out" 2> /dev/null || :
}
rigResult(){ ## result name -- the outcome word of its WAIT-RESULT line
	local resultWord
	resultWord="$( LC_ALL=C sed -n 's/^WAIT-RESULT: \([A-Z]*\).*/\1/p' "$rigDir/$1.out" | head -1 )"
	printf '%s' "${resultWord:-none}"
}

echo "-- 1. the scan: a section holding an unprocessed item ends with the line --"
rigScene scan
rigItem rig-member inquiry-20261101T0100Z-rig-one.md "Inquiry: one"
rigItem rig-member note-20261101T0101Z-rig-two.md "Note: two"
rigCall scan1 --intern-op-session-context-scan rig-member --all-types --no-slack --no-email --no-trello --no-board-related \
	--do-inbox-inquiry-active --do-inbox-notes --do-inbox-reflections --do-inbox-other --context rig
rigAssert "the scan ran"                                          "$( cat "$rigDir/scan1.rc" )" 0
rigAssert "the inquiry section ends with the instruction"          "$( rigSectionEnds scan1 '## Active Inbox Inquiry Items' )" 1
rigAssert "the notes section ends with the instruction"            "$( rigSectionEnds scan1 '## Current Inbox Notes' )" 1

echo "-- 2. the scan: a section holding no item carries no line --"
rigAssert "the reflections section has no item, so no instruction" "$( rigSectionEnds scan1 '## Current Inbox Reflections' )" 0
rigAssert "and it says so in its NOTE as before"                   "$( LC_ALL=C grep -c '^\*\*NOTE:\*\* no new Current Inbox Reflections' "$rigDir/scan1.out" )" 1
rigAssert "the line stands once per section holding items, and nowhere else" "$( rigInstructionCount scan1 )" 2

echo "-- 3. the scan: the widened read-only inbox of another member carries none --"
rigItem rig-other inquiry-20261101T0102Z-rig-three.md "Inquiry: three"
rigCall scan2 --intern-op-session-context-scan rig-member --all-types --no-slack --no-email --no-trello --no-board-related \
	--do-inbox-inquiry-active --do-inbox-also-member rig-other --context rig
rigAssert "the widened inbox is shown"                             "$( LC_ALL=C grep -c -x '## Active Inbox Inquiry Items -- rig-other' "$rigDir/scan2.out" )" 1
rigAssert "the acting member's own section still ends with the line" "$( rigSectionEnds scan2 '## Active Inbox Inquiry Items' )" 1
rigAssert "the widened section ends with no instruction"           "$( rigSectionEnds scan2 '## Active Inbox Inquiry Items -- rig-other' )" 0

echo "-- 4. the Wait: the arrived block ends with the line, after the item --"
rigScene wait
rigItem rig-member note-20261101T0101Z-rig-two.md "Note: two"
rigCall wait1 --wait-for-input --team-member rig-member --wait-source inbox:rig-member --wait-timeout 5 --wait-poll-interval 1 --wait-since-utime 1
rigAssert "the wait returned on the item"                          "$( rigResult wait1 ):$( cat "$rigDir/wait1.rc" )" "RECEIVED:0"
rigAssert "the item is delivered"                                  "$( LC_ALL=C grep -c -x 'note-20261101T0101Z-rig-two.md' "$rigDir/wait1.out" )" 1
rigAssert "the block ends with the instruction"                    "$( LC_ALL=C awk -v want="$rigInstruction" '
	/^# --- end ---$/ { if ( inside ) { print ( last == want ) ? 1 : 0 ; done = 1 ; exit } }
	/^$/ { next }
	/^# / { next }
	{ last = $0 ; inside = 1 }
	END { if ( !done ) { print "noend" } }' "$rigDir/wait1.out" )" 1

echo "-- 5. the Wait: an empty inbox is no arrival --"
rm -f "$rigData/inboxes/rig-member/incoming"/*.md
rigCall wait2 --wait-for-input --team-member rig-member --wait-source inbox:rig-member --wait-timeout 2 --wait-poll-interval 1 --wait-since-utime 1
rigAssert "a quiet bound, not an arrival the line alone made"      "$( rigResult wait2 ):$( cat "$rigDir/wait2.rc" )" "TIMEOUT:0"
rigAssert "and no instruction is delivered with nothing to handle" "$( rigInstructionCount wait2 )" 0

echo "-- 6. a named unprocessed item's own block ends with the line --"
## The named block is the other block that delivers an unprocessed item: --item names it, --item-include-inbox prints it, and
## every section is declined here so the named print is the only one that can carry the line.
rigScene named
rigItem rig-member inquiry-20261101T0100Z-rig-named.md "Inquiry: named one"
rigCall named1 --intern-op-session-context-scan rig-member --state backlog --item inquiry-20261101T0100Z-rig-named.md --item-include-inbox \
	--all-types --no-slack --no-email --no-trello --no-board-related --no-inbox-inquiry --no-inbox-reflections --no-inbox-notes --no-inbox-other --context rig
rigAssert "the named scan ran"                                     "$( cat "$rigDir/named1.rc" )" 0
rigAssert "control: it delivered the named item as its own block"   "$( LC_ALL=C grep -c -x '## inbox/inquiry-20261101T0100Z-rig-named.md' "$rigDir/named1.out" )" 1
rigAssert "the named item's block ends with the instruction"        "$( rigLastLineIs named1 )" 1

movedOne="inquiry-20261001T0100Z-rig-done.md"
mkdir -p "$rigData/inboxes/rig-member/processed"
printf -- '---\ntype: inquiry\nfrom: rig-other\nprocessed-at: 2026-10-01 10:00 +0200\n---\n\nA rig body.\n' > "$rigData/inboxes/rig-member/processed/$movedOne"
rigCall named2 --intern-op-session-context-scan rig-member --state backlog --item "$movedOne" --item-include-inbox --include-processed \
	--all-types --no-slack --no-email --no-trello --no-board-related --no-inbox-inquiry --no-inbox-reflections --no-inbox-notes --no-inbox-other --context rig
rigAssert "control: the already-processed named item was delivered"  "$( LC_ALL=C grep -c -x "## inbox/$movedOne" "$rigDir/named2.out" )" 1
rigAssert "an already-processed item carries no instruction"        "$( rigInstructionCount named2 )" 0

echo "-- 7. the wording reaches the reader character for character, a backslash included --"
## The line is the librarian's and may one day carry a backslash. `awk -v` decodes one out of its value before the program sees
## it, and `ENVIRON` does not (reference/shell.md), so the line travels in the environment. Read here through the real program,
## a manifest naming one inbox source, and the wording this block was given.
printf '1\tinbox:rig-member\t%s\n' "$rigTmp/line6.body" > "$rigTmp/line6.manifest"
printf 'note-rig-6.md\n' > "$rigTmp/line6.body"
rigLine6='keep it where the record says C:\path and stays'
rigAssert "a wording carrying a backslash is printed as it was written" \
	"$( INBOX_LINE="$rigLine6" LC_ALL=C awk -v manifest="$rigTmp/line6.manifest" -f "$rigPkg/sh-lib/member/AgentsWaitArrivalsOrder.awk" < /dev/null | LC_ALL=C grep -c -x -F -- "$rigLine6" )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ INBOX INSTRUCTION LINE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'INBOX_INSTRUCTION_LINE: OK (%d assertions, offline)\n' "$rigPassCount"
