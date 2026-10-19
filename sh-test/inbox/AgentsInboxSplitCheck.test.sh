#!/usr/bin/env bash
## Behavioural check on the split inbox (F4.3 of the refactorings epic): an inbox has two folders, `incoming/` and
## `processed/`, and an item's processed stamp (`processed-at`) decides its folder. --member-inbox-to-processed moves an
## item from incoming/ to processed/; scans and Wait list only incoming/; readers never see the folders: an operation
## names an item and finds it in either; the processed stamp stays the retention clock, and the garbage collector
## behaves exactly as before.
## Held, against a scratch team data store:
##   1. a note upserted with no processed stamp lands in incoming/; one upserted with it, in processed/
##   2. --member-inbox-to-processed moves the item to processed/, stamped, and nothing of it stays in incoming/
##   3. a second mark is a no-op: the stamp and the folder are as they were
##   4. a named read finds an item in incoming/; without --include-processed it sees only incoming/, so a processed
##      item is not found
##   5. the member's scan lists the incoming item and no processed one
##   6. a Wait on the inbox is woken by a new item in incoming/, and not by one in processed/
##   7. the GC, by the stamp's age: an old processed item goes, a young one stays, an old unprocessed one stays
##   8. a list takes --include-processed, as every inbox operation but the trash does: the console's list of a
##      member's inbox (--manager-team-data-read inboxes <member>) holds no processed item by default, and holds them
##      with the option
##   9. a read takes it too: a named read with --include-processed reads an item of either folder
##  10. --member-inbox-item-trash takes just an item's name and trashes it from either folder, with no state change
##      first; with --exclude-incoming it trashes only a processed item and leaves an incoming one; a name in neither
##      folder answers not found, with a non-zero exit
##  11. a routine's standing state and lock note lives in incoming/ of a split inbox: taken and read there
## Red before F4.3: the inbox is flat, and every operation reads its root only (1-6 fail but the GC guard).
## NOTE for the builder: AgentsInboxToProcessedCheck holds the flat form today ("never a processed/ folder") and is
## to be reconciled in the same feature.
## Offline: scratch stores under one mktemp tree, every call through one `env -i` whose child refuses to run outside
## it; no remote.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsInboxSplitCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data"
rigSkills="$rigTmp/skills"
rigInbox="$rigData/inboxes/rig-member"
## A store already moved to the split form: while the flat mode stands (until every store is moved once), an inbox
## with no incoming/ folder is read and written flat, as before, so the rig makes the folder the move makes.
mkdir -p "$rigTmp/ws/.local" "$rigTmp/home" "$rigSkills/rig-member" "$rigSkills/magic-coordinator" "$rigInbox/incoming" || rigRefuse "could not create the scratch team data store"
printf 'rig\n' > "$rigSkills/rig-member/rig-member.basic.md"
printf 'rig\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHolds(){ ## file, fixed text
	LC_ALL=C grep -q -F -- "$2" "$1" 2> /dev/null && printf yes || printf no
}
rigField(){ ## file, field
	LC_ALL=C awk -v f="$2" '$0 == "---" { d++ ; if (d >= 2) exit ; next ; } d == 1 && index($0, f ": ") == 1 { print substr($0, length(f) + 3) ; exit ; }' "$1" 2> /dev/null
}
## Where an item is: incoming, processed, root (the flat form), or none.
rigWhere(){ ## item filename
	if [ -f "$rigInbox/incoming/$1" ] ; then printf incoming
	elif [ -f "$rigInbox/processed/$1" ] ; then printf processed
	elif [ -f "$rigInbox/$1" ] ; then printf root
	else printf none
	fi
}
rigOp(){ ## result file, op and arguments... -- one team op, guarded; rc into <result>.rc
	local opOut="$1" ; shift
	env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_WAIT_REMIND=off RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$opOut" 2>&1 < /dev/null
	printf '%s' "$?" > "$opOut.rc"
}
rigDaysAgo(){ ## days -- that many days ago, as a processed stamp
	printf '%s\n' "$(( $( date +%s ) - $1 * 86400 ))" | LC_ALL=C awk -f "$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/output/AgentsEpochToIsoDate.awk"
}
rigStampAgo(){ ## days -- a touch -t stamp
	local stampEpoch=$(( $( date +%s ) - $1 * 86400 ))
	date -r "$stampEpoch" +%Y%m%d%H%M 2> /dev/null || date -d "@$stampEpoch" +%Y%m%d%H%M
}

echo "-- 1. an upserted note lands in the folder its stamp says --"
printf -- '---\ntype: note\n---\n\nRIG-OPEN-NOTE\n' > "$rigTmp/open.md"
rigOp "$rigTmp/u1" --member-inbox-note-upsert rig-member note-20261018T0900Z-open.md --from-file "$rigTmp/open.md"
rigAssert "the op succeeds"                                   "$( cat "$rigTmp/u1.rc" )" 0
rigAssert "with no processed stamp: in incoming/"             "$( rigWhere note-20261018T0900Z-open.md )" incoming
printf -- '---\ntype: note\nprocessed-at: %s\n---\n\nRIG-DONE-NOTE\n' "$( rigDaysAgo 1 )" > "$rigTmp/done.md"
rigOp "$rigTmp/u2" --member-inbox-note-upsert rig-member note-20261018T0901Z-done.md --from-file "$rigTmp/done.md"
rigAssert "with its processed stamp: in processed/"           "$( rigWhere note-20261018T0901Z-done.md )" processed

echo "-- 2. --member-inbox-to-processed moves the item, stamped --"
rigOp "$rigTmp/p1" --member-inbox-to-processed rig-member note-20261018T0900Z-open.md
rigAssert "the mark succeeds"                                 "$( cat "$rigTmp/p1.rc" )" 0
rigAssert "the item is in processed/, nothing of it in incoming/" "$( rigWhere note-20261018T0900Z-open.md ):$( [ -e "$rigInbox/incoming/note-20261018T0900Z-open.md" ] && printf left || printf gone )" "processed:gone"
rigStamp="$( rigField "$rigInbox/processed/note-20261018T0900Z-open.md" processed-at )"
rigAssert "it carries its processed stamp"                    "$( [ -n "$rigStamp" ] && printf stamped || printf unstamped )" stamped

echo "-- 3. a second mark is a no-op --"
rigOp "$rigTmp/p2" --member-inbox-to-processed rig-member note-20261018T0900Z-open.md
rigAssert "the stamp and the folder are as they were"         "$( cat "$rigTmp/p2.rc" ):$( rigWhere note-20261018T0900Z-open.md ):$( rigField "$rigInbox/processed/note-20261018T0900Z-open.md" processed-at )" "0:processed:$rigStamp"

echo "-- 4. a named read finds an item in either folder --"
mkdir -p "$rigInbox/incoming" "$rigInbox/processed"
printf -- '---\ntype: note\n---\n\nRIG-INCOMING-READ\n' > "$rigInbox/incoming/note-20261018T0902Z-in.md"
rigOp "$rigTmp/r1" --member-inbox-item-read rig-member note-20261018T0902Z-in.md
rigAssert "an item in incoming/ is read by its name"          "$( cat "$rigTmp/r1.rc" ):$( rigHolds "$rigTmp/r1" RIG-INCOMING-READ )" "0:yes"
rigOp "$rigTmp/r2" --member-inbox-item-read rig-member note-20261018T0900Z-open.md
rigAssert "without --include-processed an operation sees only incoming/: a processed item is not found" "$( [ "$( cat "$rigTmp/r2.rc" )" -ne 0 ] && printf non-zero || printf 0 ):$( rigHolds "$rigTmp/r2" RIG-OPEN-NOTE ):$( rigHolds "$rigTmp/r2" 'not found' )" "non-zero:no:yes"

echo "-- 5. the member's scan lists the incoming item, and no processed one --"
rigOp "$rigTmp/s1" --intern-op-member-work-session-input-scan rig-member
rigAssert "the incoming item is listed"                       "$( rigHolds "$rigTmp/s1" note-20261018T0902Z-in.md )" yes
rigAssert "no processed item is listed"                       "$( rigHolds "$rigTmp/s1" note-20261018T0900Z-open.md ):$( rigHolds "$rigTmp/s1" note-20261018T0901Z-done.md )" "no:no"

echo "-- 6. a Wait on the inbox wakes for incoming/, not for processed/ --"
## The floor counts what came at or after it, by the second: the incoming items of the cases above lie a second before it.
sleep 1
rigWaitSince="$( date +%s )"
sleep 1
printf -- '---\ntype: note\nprocessed-at: %s\n---\n\nRIG-QUIET\n' "$( rigDaysAgo 0 )" > "$rigInbox/processed/note-20261018T0903Z-quiet.md"
rigOp "$rigTmp/w1" --member-wait-for-input rig-member --wait-source inbox:rig-member --wait-session-id rig-inbox-split --wait-since-utime "$rigWaitSince" --wait-timeout 2 --wait-poll-interval 1
rigAssert "an item in processed/ wakes no Wait"               "$( LC_ALL=C grep -m1 '^WAIT-RESULT: ' "$rigTmp/w1" | LC_ALL=C cut -c1-20 )" "WAIT-RESULT: TIMEOUT"
printf -- '---\ntype: note\n---\n\nRIG-WAKE\n' > "$rigInbox/incoming/note-20261018T0904Z-wake.md"
rigOp "$rigTmp/w2" --member-wait-for-input rig-member --wait-source inbox:rig-member --wait-session-id rig-inbox-split-2 --wait-since-utime "$rigWaitSince" --wait-timeout 4 --wait-poll-interval 1
rigAssert "an item in incoming/ does, and is named"           "$( LC_ALL=C grep -m1 '^WAIT-RESULT: ' "$rigTmp/w2" | LC_ALL=C cut -c1-21 ):$( rigHolds "$rigTmp/w2" note-20261018T0904Z-wake.md )" "WAIT-RESULT: RECEIVED:yes"

echo "-- 7. the GC, by the stamp's age, as before --"
printf -- '---\ntype: note\nprocessed-at: %s\n---\n\nold processed\n' "$( rigDaysAgo 30 )" > "$rigInbox/processed/note-20260918T0000Z-old.md"
printf -- '---\ntype: note\nprocessed-at: %s\n---\n\nyoung processed\n' "$( rigDaysAgo 1 )" > "$rigInbox/processed/note-20261017T0000Z-young.md"
printf -- '---\ntype: note\n---\n\nold unprocessed\n' > "$rigInbox/incoming/note-20260918T0000Z-open-old.md"
for rigAged in "$rigInbox/processed/note-20260918T0000Z-old.md" "$rigInbox/incoming/note-20260918T0000Z-open-old.md" ; do touch -t "$( rigStampAgo 30 )" "$rigAged" ; done
rigOp "$rigTmp/g1" --intern-team-data-final-gc-deletion magic-coordinator
rigAssert "the old processed item goes, the young one stays, the old unprocessed one stays" \
	"$( rigWhere note-20260918T0000Z-old.md ):$( rigWhere note-20261017T0000Z-young.md ):$( rigWhere note-20260918T0000Z-open-old.md )" "none:processed:incoming"

echo "-- 8. a list takes --include-processed; by default it holds nothing processed --"
rigOp "$rigTmp/l1" --manager-team-data-read inboxes rig-member
rigAssert "by default: the incoming items, and no processed one" "$( cat "$rigTmp/l1.rc" ):$( rigHolds "$rigTmp/l1" note-20261018T0902Z-in.md ):$( rigHolds "$rigTmp/l1" note-20261018T0900Z-open.md )" "0:yes:no"
rigOp "$rigTmp/l2" --manager-team-data-read inboxes rig-member --include-processed
rigAssert "with --include-processed: the processed ones too"  "$( cat "$rigTmp/l2.rc" ):$( rigHolds "$rigTmp/l2" note-20261018T0902Z-in.md ):$( rigHolds "$rigTmp/l2" note-20261018T0900Z-open.md )" "0:yes:yes"

echo "-- 9. a read takes --include-processed too --"
rigOp "$rigTmp/r3" --member-inbox-item-read rig-member note-20261018T0900Z-open.md --include-processed
rigAssert "a processed item, read with the option"           "$( cat "$rigTmp/r3.rc" ):$( rigHolds "$rigTmp/r3" RIG-OPEN-NOTE )" "0:yes"
rigOp "$rigTmp/r4" --member-inbox-item-read rig-member note-20261018T0902Z-in.md --include-processed
rigAssert "an incoming item, read with the option"           "$( cat "$rigTmp/r4.rc" ):$( rigHolds "$rigTmp/r4" RIG-INCOMING-READ )" "0:yes"

echo "-- 10. the trash: by name, from either folder; --exclude-incoming; a name in neither --"
rigTrashed(){ ## item filename -- trashed where it is in neither inbox folder and lies under the store's trash/, else where it is
	local trashedAt
	trashedAt="$( rigWhere "$1" )"
	[ "$trashedAt" = none ] || { printf '%s' "$trashedAt" ; return 0 ; }
	[ -n "$( find "$rigData/trash" -name "$1*" 2> /dev/null | head -1 )" ] && printf trashed || printf vanished
}
printf -- '---\ntype: note\n---\n\nRIG-TRASH-IN\n' > "$rigInbox/incoming/note-20261018T0910Z-trash-in.md"
printf -- '---\ntype: note\nprocessed-at: %s\n---\n\nRIG-TRASH-DONE\n' "$( rigDaysAgo 1 )" > "$rigInbox/processed/note-20261018T0911Z-trash-done.md"
printf -- '---\ntype: note\n---\n\nRIG-KEEP-IN\n' > "$rigInbox/incoming/note-20261018T0912Z-keep-in.md"
printf -- '---\ntype: note\nprocessed-at: %s\n---\n\nRIG-TRASH-DONE-2\n' "$( rigDaysAgo 1 )" > "$rigInbox/processed/note-20261018T0913Z-trash-done-2.md"
rigOp "$rigTmp/t1" --member-inbox-item-trash rig-member note-20261018T0910Z-trash-in.md
rigAssert "an incoming item, by its name alone: trashed"     "$( cat "$rigTmp/t1.rc" ):$( rigTrashed note-20261018T0910Z-trash-in.md )" "0:trashed"
rigOp "$rigTmp/t2" --member-inbox-item-trash rig-member note-20261018T0911Z-trash-done.md
rigAssert "a processed item, by its name alone: trashed"     "$( cat "$rigTmp/t2.rc" ):$( rigTrashed note-20261018T0911Z-trash-done.md )" "0:trashed"
rigOp "$rigTmp/t3" --member-inbox-item-trash rig-member note-20261018T0912Z-keep-in.md --exclude-incoming
rigAssert "with --exclude-incoming an incoming item is not trashed" "$( [ "$( cat "$rigTmp/t3.rc" )" -ne 0 ] && printf refused || printf accepted ):$( rigTrashed note-20261018T0912Z-keep-in.md )" "refused:incoming"
rigOp "$rigTmp/t4" --member-inbox-item-trash rig-member note-20261018T0913Z-trash-done-2.md --exclude-incoming
rigAssert "with --exclude-incoming a processed item is trashed" "$( cat "$rigTmp/t4.rc" ):$( rigTrashed note-20261018T0913Z-trash-done-2.md )" "0:trashed"
rigOp "$rigTmp/t5" --member-inbox-item-trash rig-member note-20261018T0999Z-nowhere.md
rigAssert "a name in neither folder: not found, non-zero, naming it" "$( [ "$( cat "$rigTmp/t5.rc" )" -ne 0 ] && printf non-zero || printf 0 ):$( rigHolds "$rigTmp/t5" 'not found' ):$( rigHolds "$rigTmp/t5" note-20261018T0999Z-nowhere.md )" "non-zero:yes:yes"

echo "-- 11. a routine's standing state and lock note lives in incoming/ of a split inbox --"
mkdir -p "$rigData/inboxes/magic-coordinator/incoming"
rigLockNote=note-20260809T155000Z-heartbeat-state-and-lock.md
rigOp "$rigTmp/k1" --magic-heartbeat-lock-acquire magic-coordinator rig-inbox-split
rigAssert "the lock is taken"                                 "$( cat "$rigTmp/k1.rc" ):$( rigHolds "$rigTmp/k1" ACQUIRED )" "0:yes"
rigAssert "its note is written in incoming/, and nothing of it at the inbox root" \
	"$( [ -f "$rigData/inboxes/magic-coordinator/incoming/$rigLockNote" ] && printf incoming || printf missing ):$( [ -e "$rigData/inboxes/magic-coordinator/$rigLockNote" ] && printf root || printf none )" "incoming:none"
rigOp "$rigTmp/k2" --magic-heartbeat-lock-status magic-coordinator
rigAssert "and it is read from there: the lock is held"       "$( LC_ALL=C grep -c '^ACTIVE:' "$rigTmp/k2" )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ INBOX SPLIT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'INBOX_SPLIT: OK (%d assertions, offline)\n' "$rigPassCount"
