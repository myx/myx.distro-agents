#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on the cache-to-inbox transfer (S1.12 stage 2, item 12 and standing ruling 14): one pass per reader hands the
## actionable messages the comms cache holds into that reader's own inbox, once each, and moves that reader's own pointer.
## Held:
##   0. the control: the rig's store holds the events this check wrote, and every id is the EventIdentifier form
##   1. a reader with no pointer gets one cursor a source, each seeded to that source's newest ingested id, and hands over nothing
##   2. a pass hands over the message in the reader's own direct conversation, one item named from the message's own id
##   3. that item's `communication-channel-id` is the full pointer
##   4. a tag in a channel thread hands its message over, and the message beside it with no tag does not
##   5. a message the reader itself wrote, and another member's conversation, are not handed over
##   6. an `edit` about a message already handed over delivers it once, not twice
##   7. a quiet pass writes no item and moves no pointer
##   8. a source whose events file cannot be read leaves every cursor where it was, and the pass reports the failure
##   9. a reader with no `.user-id` file hands over its direct conversation, nothing by tag, and says so once
##  10. a message in a slower source, whose own id sorts before the reader's mark, is still handed over: the row a single
##      member-wide pointer fails
##  11. the pointer file is `pointer <id>` and one `source <key> <id>` a source, and its moment is this pass's
## Offline: no service is reached, and the store is the check's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
## A RIG INHERITS ITS RUNNER'S SESSION, and this check must read none of it.
for rigDrop in ${!MDAT_SPAWN_@} MDAT_SESSION_ID MDAT_SESSION_THREAD MDAT_CONVERSATION_THREADS MDAT_WAIT_REMIND harnessSessionId harnessAgent CLAUDE_CODE_SESSION_ID ; do
	unset "$rigDrop" 2> /dev/null || :
done
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsCommsTransferCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX "$rigTmp" 2> /dev/null || : ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigScn="$rigTmp/scn" rigStore="$rigTmp/ws/.local/cache/comms/slack"
rigData="$rigScn/data" rigPointerDir="$rigWs/.local/cache/comms/.transfer"
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigTmp/skills/keeper-rig" "$rigTmp/skills/unread-rig" "$rigScn" \
	"$rigStore" "$rigData/inboxes/keeper-rig/incoming" "$rigData/inboxes/unread-rig/incoming"
## The pointer folder is not made here: the transfer makes its own on a fresh workspace, which is the case the collect thread meets.
printf 'keeper-rig\n' > "$rigTmp/skills/keeper-rig/keeper-rig.basic.md"
printf 'unread-rig\n' > "$rigTmp/skills/unread-rig/unread-rig.basic.md"
rigReader="keeper-rig" rigReaderId="URIGME01" rigOther="unread-rig" rigOtherId="URIGOTHER1"

## THE SUBJECT HAS TO BE THERE. A check whose include is absent would report rows about nothing: an empty store, a pointer never
## written and a pass that never ran all look alike from here.
rigInclude="$rigOrigin/myx/myx.distro-agents/sh-lib/comms/AgentsTools.CommsTransfer.include"
[ -f "$rigInclude" ] || { echo "⛔ ERROR: the transfer is not at the origin this workspace resolves: $rigInclude" >&2 ; exit 1 ; }

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## ONE SOURCE of the rig's store: its `.state.txt` pulling line, its own folder, and the month folder the events go in.
rigSource(){ ## the folder name, the target, the member
	mkdir -p "$rigStore/$1/202611"
	printf '1793600000 %s 0\n\nslack-thread %s %s false\n' "$2" "$2" "$3" > "$rigStore/$1/.state.txt"
	printf '%s\n' "$rigStore/$1/202611"
}
## ONE EVENT: `id`, kind, message id, author, text. Sixteen columns, the store's own form, a TAB between each.
rigEvent(){ ## the month folder, the id, the kind, the message id, the author, the text
	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
		"$2" "$3" "$4" "$5" "$4" "" "$6" "" "" "" "" "" "" "" "" "" >> "$1/events.txt"
}

## The reader's own direct conversation: someone else's message, a second one that is edited later, then the reader's own message.
rigDmName="slack-URIGME01-D0RIGDM01"
rigDmMonth="$( rigSource "$rigDmName" D0RIGDM01:1793600000.000001 "$rigReader" )"
rigEvent "$rigDmMonth" 20261110T100000000Z-000001A01 msg 1793600000.000001 "$rigOtherId" RIG-DM-ONE
rigEvent "$rigDmMonth" 20261110T100100000Z-000002A01 msg 1793600000.000002 "$rigOtherId" RIG-DM-TWO
rigEvent "$rigDmMonth" 20261110T100200000Z-000003A01 edit 1793600000.000002 "$rigOtherId" RIG-DM-TWO-EDITED
rigEvent "$rigDmMonth" 20261110T100300000Z-000004A01 msg 1793600000.000003 "$rigReaderId" RIG-DM-OWN
printf '20261110T100300000Z-000004A01\n' > "$rigStore/$rigDmName/.ingest.txt"
## A channel thread: one message tagging the reader, one naming nobody.
rigChName="slack-CRIGCH00001-1793600000.000010"
rigChMonth="$( rigSource "$rigChName" CRIGCH00001:1793600000.000010 "$rigReader" )"
rigEvent "$rigChMonth" 20261110T100400000Z-000005A01 msg 1793600000.000011 "$rigOtherId" "RIG-TAGGED-<@$rigReaderId>"
rigEvent "$rigChMonth" 20261110T100500000Z-000006A01 msg 1793600000.000012 "$rigOtherId" RIG-UNTAGGED
printf '20261110T100500000Z-000006A01\n' > "$rigStore/$rigChName/.ingest.txt"
## Another member's own direct conversation: never this reader's to see.
rigOtName="slack-URIGOTHER1-D0RIGOT001"
rigOtMonth="$( rigSource "$rigOtName" D0RIGOT001:1793600000.000020 "$rigOther" )"
rigEvent "$rigOtMonth" 20261110T100600000Z-000007A01 msg 1793600000.000021 "$rigReaderId" RIG-OTHER-DM
printf '20261110T100600000Z-000007A01\n' > "$rigStore/$rigOtName/.ingest.txt"
## The readers' own Slack ids, the files the cache keeps: `<epoch> <U-id>`.
printf '1793600000 %s\n' "$rigReaderId" > "$rigStore/.user-id-$rigReader.txt"
printf '1793600000 %s\n' "$rigOtherId" > "$rigStore/.user-id-$rigOther.txt"

rigStoreEvents(){ for rigFile in "$rigStore"/*/[0-9][0-9][0-9][0-9][0-9][0-9]/events.txt ; do [ -f "$rigFile" ] && LC_ALL=C cat "$rigFile" ; done ; }
rigPointerFile(){ printf '%s\n' "$rigPointerDir/$1.txt" ; }
rigMark(){ LC_ALL=C awk '$1 == "pointer" { print $2 ; exit }' "$( rigPointerFile "$1" )" 2> /dev/null ; }
rigCursors(){ LC_ALL=C awk '$1 == "source" { print $2 }' "$( rigPointerFile "$1" )" 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ; }
rigCursorOf(){ ## member, the source folder's own name
	LC_ALL=C awk -v key="$2" '$1 == "source" && $2 == key { print $3 ; exit }' "$( rigPointerFile "$1" )" 2> /dev/null
}
rigItems(){ ls -1 "$rigData/inboxes/$1/incoming" 2> /dev/null ; }
rigItemCount(){ rigItems "$1" | LC_ALL=C awk 'NF' | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ; }
rigItemField(){ LC_ALL=C sed -n "s/^$3: //p" "$rigData/inboxes/$1/incoming/$2" 2> /dev/null | head -1 ; }
rigHas(){ rigItems "$1" | LC_ALL=C grep -c -F -e "$2" ; }

## ONE PASS of the transfer for a member: the include sourced where the rig's workspace is, its one function called. The pass runs
## in a subshell of this shell, so nothing of it outlives the rig.
rigPass(){ ## member -- the pass's rc
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		"MMDAPP=$rigWs" "MDLT_ORIGIN=$rigOrigin" "MDLT_OPTION=--run-from-path $rigOrigin" "MDAT_SKILLSET_ROOT=$rigTmp/skills" \
		"MDAT_DATA_ROOT=$rigData" "MDAT_SPAWN_AGENT=$1" "MDAT_WORKSPACE_MODE=team-rig" \
		bash -c '. "$1" ; AgentsCommsTransferSlack "$2"' _ "$rigInclude" "$1" ) > "$rigScn/pass.out" 2> "$rigScn/pass.err"
}

echo "-- 0. the control: the rig's store holds the events this check wrote --"
rigAssert "the store holds 7 events" "$( rigStoreEvents | LC_ALL=C awk 'NF' | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 7
rigAssert "and every id is the EventIdentifier form" "$( rigStoreEvents | LC_ALL=C cut -f1 | LC_ALL=C awk '$0 ~ /^[0-9]{8}T[0-9]{9}Z-[0-9]{6}[0-9A-F]{3}$/ { n++ } END { print n + 0 }' )" 7

echo "-- 1. a reader with no pointer gets one cursor a source, each its newest ingested id, and hands over nothing --"
rigPass "$rigReader"
rigAssert "the pass ran" "$?" 0
rigAssert "no item was written" "$( rigItemCount "$rigReader" )" 0
rigAssert "one cursor a source of the reader's own two" "$( rigCursors "$rigReader" )" 2
rigAssert "the direct conversation's cursor is its own newest" "$( rigCursorOf "$rigReader" "$rigDmName" )" 20261110T100300000Z-000004A01
rigAssert "and the reader's mark is the newer of the two" "$( rigMark "$rigReader" )" 20261110T100500000Z-000006A01

echo "-- 2. a pass hands over the message in the reader's own direct conversation --"
{
	printf 'pointer %s\n' 20261110T100500000Z-000006A01
	printf 'source %s %s\n' "$rigChName" 20261110T100000000Z-000001A01
	printf 'source %s %s\n' "$rigDmName" 20261110T100000000Z-000001A01
} > "$( rigPointerFile "$rigReader" )"
sleep 1 ; touch "$rigStore/$rigDmName/.ingest.txt" "$rigStore/$rigChName/.ingest.txt"
rigPass "$rigReader"
rigAssert "the pass ran" "$?" 0
rigAssert "two items are written, the edited message named once" "$( rigItemCount "$rigReader" )" 2
rigAssert "and the edited one is named from that message's own id" "$( rigHas "$rigReader" 'note-20261102T0613Z-slack-1793600000.000002.md' )" 1

echo "-- 3. its communication-channel-id is the full pointer --"
rigAssert "the item carries the channel and its ts" \
	"$( rigItemField "$rigReader" note-20261102T0613Z-slack-1793600000.000002.md communication-channel-id )" \
	"slack:D0RIGDM01:1793600000.000002"

echo "-- 4. a tag in a channel thread hands its message over, and an untagged one does not --"
rigAssert "the tagged message is handed over" "$( rigHas "$rigReader" '-slack-1793600000.000011.md' )" 1
rigAssert "the untagged message is not" "$( rigHas "$rigReader" '-slack-1793600000.000012.md' )" 0

echo "-- 5. the reader's own message, and another member's conversation, are not handed over --"
rigAssert "the reader's own message is not" "$( rigHas "$rigReader" '-slack-1793600000.000003.md' )" 0
rigAssert "and two items stand, none from the other conversation" "$( rigItemCount "$rigReader" )" 2

echo "-- 6. an edit about a message already handed over delivers it once --"
rigPass "$rigReader"
rigAssert "the pass ran" "$?" 0
rigAssert "the edited message still has one item" "$( rigHas "$rigReader" '-slack-1793600000.000002.md' )" 1
rigAssert "and no item is named after an event id" "$( rigItems "$rigReader" | LC_ALL=C grep -c -- 'note-20261110T10' )" 0

echo "-- 7. a quiet pass writes no item and moves no pointer --"
rigMarkBefore="$( rigMark "$rigReader" )"
rigCursorBefore="$( rigCursorOf "$rigReader" "$rigDmName" )"
rigPass "$rigReader"
rigAssert "the quiet pass ran" "$?" 0
rigAssert "the inbox holds what it held" "$( rigItemCount "$rigReader" )" 2
rigAssert "and the reader's mark did not move" "$( rigMark "$rigReader" )" "$rigMarkBefore"
rigAssert "and neither did the direct conversation's cursor" "$( rigCursorOf "$rigReader" "$rigDmName" )" "$rigCursorBefore"

echo "-- 8. a source whose events file cannot be read leaves every cursor where it was --"
chmod 000 "$rigStore/$rigChName/202611/events.txt"
sleep 1 ; touch "$rigStore/$rigChName/.ingest.txt"
rigPass "$rigReader"
rigAssert "the pass reports the failure" "$?" 1
rigAssert "naming the file it could not read" "$( LC_ALL=C grep -c 'could not read' "$rigScn/pass.err" )" 1
rigAssert "and the reader's mark is where it was" "$( rigMark "$rigReader" )" "$rigMarkBefore"
rigAssert "and the direct conversation's cursor too" "$( rigCursorOf "$rigReader" "$rigDmName" )" "$rigCursorBefore"
chmod 644 "$rigStore/$rigChName/202611/events.txt"

echo "-- 9. a reader with no .user-id hands over its direct conversation and nothing by tag --"
rm -f "$rigStore/.user-id-$rigOther.txt"
rigOt2Name="slack-URIGOTHER1-D0RIGOT002"
rigOt2Month="$( rigSource "$rigOt2Name" D0RIGOT002:1793600000.000030 "$rigOther" )"
rigEvent "$rigOt2Month" 20261110T100700000Z-000008A01 msg 1793600000.000031 "$rigReaderId" RIG-OTHER-DM-TWO
printf '20261110T100700000Z-000008A01\n' > "$rigStore/$rigOt2Name/.ingest.txt"
rigCh2Name="slack-CRIGCH00001-1793600000.000040"
rigCh2Month="$( rigSource "$rigCh2Name" CRIGCH00001:1793600000.000040 "$rigOther" )"
rigEvent "$rigCh2Month" 20261110T100800000Z-000009A01 msg 1793600000.000032 "$rigReaderId" "RIG-TAG-<@$rigOtherId>"
printf '20261110T100800000Z-000009A01\n' > "$rigStore/$rigCh2Name/.ingest.txt"
rigPass "$rigOther"
rigAssert "the pass ran" "$?" 0
## THE FIRST PASS SEEDS EACH SOURCE TO ITS OWN NEWEST, so it hands nothing over by design. A message that arrives after
## that seed is the one this row asks about, and its id sorts after the seed because the store mints ids in time order.
rigEvent "$rigOt2Month" 20261110T100900000Z-00000BA01 msg 1793600000.000033 "$rigReaderId" RIG-OTHER-DM-THREE
sleep 1 ; printf '20261110T100900000Z-00000BA01\n' > "$rigStore/$rigOt2Name/.ingest.txt"
printf '20261110T100900000Z-00000BA01\n' > "$rigStore/$rigCh2Name/.ingest.txt"
rigPass "$rigOther"
rigAssert "the pass ran" "$?" 0
rigAssert "the direct conversation is handed over" "$( rigHas "$rigOther" '-slack-1793600000.000033.md' )" 1
rigAssert "and the tag reaches nothing" "$( rigHas "$rigOther" '-slack-1793600000.000032.md' )" 0
rigAssert "and the pass says why it reads no tag" "$( LC_ALL=C grep -c 'no .user-id file names' "$rigScn/pass.err" )" 1

echo "-- 10. a message in a slower source, its own id before the reader's mark, is still handed over --"
rigSlowId="20261110T100450000Z-000001A01"
rigEvent "$rigDmMonth" "$rigSlowId" msg 1793600000.000004 "$rigOtherId" RIG-SLOW-SOURCE
sleep 1 ; printf '%s\n' "$rigSlowId" > "$rigStore/$rigDmName/.ingest.txt"
rigAssert "the slow message's id sorts before the reader's mark" \
	"$( [ "$rigSlowId" \< "$( rigMark "$rigReader" )" ] && printf yes || printf no )" yes
rigPass "$rigReader"
rigAssert "the pass ran" "$?" 0
rigAssert "and the slow message is handed over" "$( rigHas "$rigReader" '-slack-1793600000.000004.md' )" 1
rigAssert "the direct conversation's cursor moved to it" "$( rigCursorOf "$rigReader" "$rigDmName" )" "$rigSlowId"
rigAssert "while the reader's mark stayed on the newer id" "$( rigMark "$rigReader" )" 20261110T100500000Z-000006A01

echo "-- 11. the pointer file is \`pointer <id>\` and one \`source <key> <id>\` a source --"
rigAssert "its first line is the reader's mark" "$( head -1 "$( rigPointerFile "$rigReader" )" | LC_ALL=C awk '$1 == "pointer" { print "yes" ; exit }' )" yes
rigAssert "its other lines are cursors, one a source" "$( rigCursors "$rigReader" )" 2
rigAssert "every id in it is the EventIdentifier form" \
	"$( LC_ALL=C awk '{ id = ( $1 == "pointer" ) ? $2 : $3 ; n++ ; if (id ~ /^[0-9]{8}T[0-9]{9}Z-[0-9]{6}[0-9A-F]{3}$/) ok++ } END { print ( n == ok ) ? "all" : n - ok }' "$( rigPointerFile "$rigReader" )" )" all
rigAssert "and its moment is this pass's" \
	"$( [ -n "$( find "$( rigPointerFile "$rigReader" )" -newer "$rigStore/$rigDmName/.ingest.txt" 2> /dev/null )" ] && printf newer || printf older )" newer

printf '\n  %s passed, %s failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" -eq 0 ] || exit 1
printf 'COMMS_TRANSFER: OK\n'
