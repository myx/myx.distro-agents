#!/usr/bin/env bash
## Behavioural check on the thread root a transfer item carries (sh-lib/comms/AgentsTools.CommsTransfer.include and AgentsCommsTransferEvents.awk).
## A pass runs against a small events store, as AgentsCommsTransferCheck does, and the written items are read back. Held:
##   1. A REPLY INSIDE A THREAD: the item's `communication-channel-id` names the thread root, `slack:<channel>:<root ts>`, and the item keeps the reply's own ts in its name.
##   2. A TOP-LEVEL MESSAGE and the root of a thread (its own thread_ts equal to its ts) carry their own ts.
##   3. A TAB IN THE TEXT, kept escaped in the store, does not shift the root or the author, and is restored in the body.
##   4. AN EDIT with no thread_ts of its own takes the root of its message from the `msg` row of the same file.
##   5. A TAGGED REPLY in a channel thread carries the root of that thread.
##   6. THE AUTHOR is a body line `author: <Slack id>`, and a row with no author writes none.
## Red before the change: every header carries the message's own ts and no body line names an author.
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
rigTmp="$( rigTempDir AgentsTransferThreadRootCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX "$rigTmp" 2> /dev/null || : ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigScn="$rigTmp/scn" rigStore="$rigTmp/ws/.local/cache/comms/slack"
rigData="$rigScn/data" rigPointerDir="$rigWs/.local/cache/comms/.transfer"
mkdir -p "$rigTmp/bin" "$rigTmp/home" "$rigTmp/skills/keeper-rig" "$rigScn" "$rigStore" "$rigData/inboxes/keeper-rig/incoming"
printf 'keeper-rig\n' > "$rigTmp/skills/keeper-rig/keeper-rig.basic.md"
rigReader="keeper-rig" rigReaderId="URIGME01" rigOtherId="URIGOTHER1"
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
rigSource(){ ## the folder name, the target, the member
	mkdir -p "$rigStore/$1/202611"
	printf '1793600000 %s 0\n\nslack-thread %s %s false\n' "$2" "$2" "$3" > "$rigStore/$1/.state.txt"
	printf '%s\n' "$rigStore/$1/202611"
}
## ONE EVENT of sixteen TAB columns, the store's own form: id, kind, message id, author, message id, none, text, none, none, thread_ts, then six none.
rigEvent(){ ## the month folder, the id, the kind, the message id, the author, the text, the thread_ts
	printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
		"$2" "$3" "$4" "$5" "$4" "" "$6" "" "" "${7:-}" "" "" "" "" "" "" >> "$1/events.txt"
}
rigItems(){ ls -1 "$rigData/inboxes/$1/incoming" 2> /dev/null ; }
rigItemFor(){ ## member, the message's own ts -- the item's file name
	rigItems "$1" | LC_ALL=C grep -F -e "-slack-$2.md" | head -1
}
rigHeader(){ ## member, the message's own ts -- the item's communication-channel-id
	LC_ALL=C sed -n 's/^communication-channel-id: //p' "$rigData/inboxes/$1/incoming/$( rigItemFor "$1" "$2" )" 2> /dev/null | head -1
}
rigBodyLine(){ ## member, the message's own ts, the key -- that body line's value
	LC_ALL=C sed -n "s/^$3: //p" "$rigData/inboxes/$1/incoming/$( rigItemFor "$1" "$2" )" 2> /dev/null | tail -1
}
rigPass(){ ## member -- the pass's rc
	( cd "$rigWs" && env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		"MMDAPP=$rigWs" "MDLT_ORIGIN=$rigOrigin" "MDLT_OPTION=--run-from-path $rigOrigin" "MDAT_SKILLSET_ROOT=$rigTmp/skills" \
		"MDAT_DATA_ROOT=$rigData" "MDAT_SPAWN_AGENT=$1" "MDAT_WORKSPACE_MODE=team-rig" \
		bash -c '. "$1" ; AgentsCommsTransferSlack "$2"' _ "$rigInclude" "$1" ) > "$rigScn/pass.out" 2> "$rigScn/pass.err"
}

## The reader's own direct conversation. The first row sorts before the pointer, so the pass hands over only the rows after it.
rigDmName="slack-URIGME01-D0RIGDM01"
rigDmMonth="$( rigSource "$rigDmName" D0RIGDM01:1793600000.000001 "$rigReader" )"
rigEvent "$rigDmMonth" 20261110T100000000Z-000001A01 msg 1793600000.000001 "$rigOtherId" RIG-SEED-ROW ""
rigEvent "$rigDmMonth" 20261110T100100000Z-000002A01 msg 1793600000.000010 "$rigOtherId" RIG-ROOT-ROW 1793600000.000010
rigEvent "$rigDmMonth" 20261110T100200000Z-000003A01 msg 1793600000.000011 "$rigOtherId" RIG-REPLY-ROW 1793600000.000010
rigEvent "$rigDmMonth" 20261110T100300000Z-000004A01 msg 1793600000.000020 "$rigOtherId" RIG-TOP-ROW ""
rigEvent "$rigDmMonth" 20261110T100400000Z-000005A01 msg 1793600000.000030 "$rigOtherId" 'RIG-TAB\036INSIDE the reply' 1793600000.000010
rigEvent "$rigDmMonth" 20261110T100500000Z-000006A01 msg 1793600000.000040 "" RIG-NO-AUTHOR-ROW 1793600000.000010
## An edit of a message whose msg row sorts before the pointer: only the edit is handed over, and it carries no thread_ts of its own.
rigEvent "$rigDmMonth" 20261110T100050000Z-000001B01 msg 1793600000.000050 "$rigOtherId" RIG-EDITED-ORIGINAL 1793600000.000010
rigEvent "$rigDmMonth" 20261110T100600000Z-000007A01 edit 1793600000.000050 "$rigOtherId" RIG-EDITED-TEXT ""
printf '20261110T100600000Z-000007A01\n' > "$rigStore/$rigDmName/.ingest.txt"
## A channel thread: a tagged reply inside the thread of the root 1793600000.000100.
rigChName="slack-CRIGCH00001-1793600000.000100"
rigChMonth="$( rigSource "$rigChName" CRIGCH00001:1793600000.000100 "$rigReader" )"
rigEvent "$rigChMonth" 20261110T100700000Z-000008A01 msg 1793600000.000101 "$rigOtherId" "RIG-TAGGED-<@$rigReaderId>" 1793600000.000100
printf '20261110T100700000Z-000008A01\n' > "$rigStore/$rigChName/.ingest.txt"
printf '1793600000 %s\n' "$rigReaderId" > "$rigStore/.user-id-$rigReader.txt"
## The pointer sits before every row to hand over, so the pass reads them at once. The edit's msg row (id ...1B01) sorts before it.
mkdir -p "$rigPointerDir"
{
	printf 'pointer %s\n' 20261110T100000000Z-000001A01
	printf 'source %s %s\n' "$rigChName" 20261110T100000000Z-000001A01
	printf 'source %s %s\n' "$rigDmName" 20261110T100060000Z-000001B01
} > "$rigPointerDir/$rigReader.txt"
sleep 1 ; touch "$rigStore/$rigDmName/.ingest.txt" "$rigStore/$rigChName/.ingest.txt"

rigPass "$rigReader"
rigPassRc="$?"
echo "-- 0. the control: the pass ran and handed over its rows --"
rigAssert "the pass ran" "$rigPassRc" 0
rigAssert "and wrote seven items, one for each row to hand over" "$( rigItems "$rigReader" | LC_ALL=C awk 'NF' | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 7

echo "-- 1. a reply inside a thread carries the thread root --"
rigAssert "the reply's header names the root" "$( rigHeader "$rigReader" 1793600000.000011 )" "slack:D0RIGDM01:1793600000.000010"
rigAssert "and its name stays keyed on the reply's own ts" "$( rigItemFor "$rigReader" 1793600000.000011 | LC_ALL=C grep -c -- '-slack-1793600000.000011.md$' )" 1

echo "-- 2. a top-level message and the root itself carry their own ts --"
rigAssert "the top-level message" "$( rigHeader "$rigReader" 1793600000.000020 )" "slack:D0RIGDM01:1793600000.000020"
rigAssert "the root of a thread, its thread_ts equal to its ts" "$( rigHeader "$rigReader" 1793600000.000010 )" "slack:D0RIGDM01:1793600000.000010"

echo "-- 3. a tab in the text shifts no field --"
rigAssert "the header of the reply with the escaped tab" "$( rigHeader "$rigReader" 1793600000.000030 )" "slack:D0RIGDM01:1793600000.000010"
rigAssert "the body has the tab back" "$( LC_ALL=C grep -c "RIG-TAB$( printf '\t' )INSIDE the reply" "$rigData/inboxes/$rigReader/incoming/$( rigItemFor "$rigReader" 1793600000.000030 )" )" 1
rigAssert "the author of that row is still the author" "$( rigBodyLine "$rigReader" 1793600000.000030 author )" "$rigOtherId"

echo "-- 4. an edit takes the root of its message from the msg row --"
rigAssert "the edit's header names the root, not its own ts" "$( rigHeader "$rigReader" 1793600000.000050 )" "slack:D0RIGDM01:1793600000.000010"

echo "-- 5. a tagged reply in a channel thread carries the thread root --"
rigAssert "the tagged reply" "$( rigHeader "$rigReader" 1793600000.000101 )" "slack:CRIGCH00001:1793600000.000100"

echo "-- 6. the author is a body line, and no author writes none --"
rigAssert "the author line of the reply" "$( rigBodyLine "$rigReader" 1793600000.000011 author )" "$rigOtherId"
rigAssert "a row with no author writes no author line" "$( LC_ALL=C grep -c '^author: ' "$rigData/inboxes/$rigReader/incoming/$( rigItemFor "$rigReader" 1793600000.000040 )" )" 0
rigAssert "and its header still names the root" "$( rigHeader "$rigReader" 1793600000.000040 )" "slack:D0RIGDM01:1793600000.000010"

printf '\n  %s passed, %s failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" -eq 0 ] || exit 1
printf 'TRANSFER_THREAD_ROOT: OK\n'
