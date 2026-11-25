#!/usr/bin/env bash
## Behavioural check on `--upsert-inbox-inquiry ... --from-comment <service>:<page>:<comment-id>`: one inquiry
## filed per comment, the comment recorded as filed, and a repeat pass filing nothing. Held against a temp store:
##   1. a first pass over the two real pages files 4 inquiries
##   2. the reply under its parent is refused, and files nothing
##   3. a second pass over the same pages files 0, the watermark note holding all four
##   4. the three comments whose body is identical file as three items, their titles carrying the id
##   5. nothing is half done: a title without the id, a comment not on its page, a two-part value and a service with
##      no comment read are each refused before anything is written
##   6. control: the watermark note lands at the state-and-lock path, out of every inbox scan's reach
## The Atlassian read is stubbed with the rows the built read printed at 02:45 +0200 on 2026-11-25, and the inquiry
## writer with a recorder, so this operation's own logic is what is measured. The write path itself is held by
## AgentsInquiryFromReflectionCheck, which drives the real dispatcher.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigOp="$rigPkg/sh-lib/inbox/AgentsTools.OpUpsertInboxInquiry.include"
rigPlace="$rigPkg/sh-lib/inbox/AgentsTools.InboxPlace.include"
for rigNeed in "$rigOp" "$rigPlace" ; do
	[ -f "$rigNeed" ] || { echo "⛔ ERROR: no $rigNeed" >&2 ; exit 1 ; }
done
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsInquiryFromCommentCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
MDSC_CMD='DistroAgentsTools'
MDAT_DATA_ROOT="$rigTmp/data"
MDAT_SPAWN_AGENT=rig-member
mkdir -p "$MDAT_DATA_ROOT/inboxes/rig-member/incoming" "$MDAT_DATA_ROOT/inboxes/magic-coordinator/incoming"

rigNote=note-20261008T000000Z-doc-comments-state-and-lock.md
rigFiled="$rigTmp/filed.log"
: > "$rigFiled"

## The read, as it printed at 02:45 +0200: eight columns, the last the parent's id, empty where there is none.
DistroAgentsAtlassian(){ ## the read's own arguments
	printf 'COMMENT_ID\tVERSION_AUTHOR_ID\tCREATED\tBODY\tPAGE_ID\tSTATUS\tRESOLUTION_STATUS\tPARENT_COMMENT_ID\n'
	case "$4" in
		4919689217)
			printf '4922703874\ta\t2026-11-23T07:09:58.769Z\t<p>Fix date format (make consistent with the above human-readables)</p>\t4919689217\tcurrent\topen\t\n'
			printf '4922376200\ta\t2026-11-23T07:10:08.255Z\t<p>Fix date format (make consistent with the above human-readables)</p>\t4919689217\tcurrent\topen\t\n'
			printf '4918509717\ta\t2026-11-23T07:10:14.079Z\t<p>Fix date format (make consistent with the above human-readables)</p>\t4919689217\tcurrent\topen\t\n'
		;;
		4919263234)
			printf '4922671108\ta\t2026-11-23T07:25:44.083Z\t<p>Redundant. Remove</p>\t4919263234\tcurrent\topen\t\n'
			printf '4921294971\ta\t2026-11-23T07:26:42.014Z\t<p>Agreed, it can go.</p>\t4919263234\tcurrent\topen\t4922671108\n'
		;;
	esac
	return 0
}
## The inquiry writer records the item name it was given, and writes nothing else. Its syntax is
## `<member> <item-filename>`, so the item is the third word, after the operation's own name.
DistroAgentsTools(){
	case "$*" in
		*--upsert-inbox-inquiry*) printf '%s\n' "$3" >> "$rigFiled" ; return 0 ;;
	esac
	printf '%s\n' "⛔ ERROR: unstubbed writer call: $*" >&2
	return 1
}
AgentsToolsActingMemberCheck(){ return 0 ; }
AgentsToolsActingMember(){ printf 'rig-member\n' ; }
AgentsToolsEmergencyHolds(){ return 1 ; }
AgentsToolsAssertBareName(){ return 0 ; }
## The member directory is not what this check measures: the routing of a name to a place is held by
## AgentsInquiryFromReflectionCheck, through the real dispatcher and a rig skillset root.
AgentsToolsTeamMemberDirectory(){ return 0 ; }
. "$rigPlace"

## One run of the operation, its own arguments, the inquiry's body on stdin.
rigCall(){ ## body, arguments...
	rigRc=0 rigOut=""
	rigOut="$( printf '%s\n' "$1" | rigDispatch "${@:2}" 2>&1 )" || rigRc=$?
}
rigDispatch(){ ## the operation's own arguments
	set -- --upsert-inbox-inquiry "$@"
	. "$rigOp"
}

rigPass=0 rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
rigFiledCount(){ LC_ALL=C awk 'NF { n++ ; } END { print n + 0 ; }' "$rigFiled" ; }
rigFiledRow(){ LC_ALL=C awk -v row="$1" 'NF && n++ == row - 1 { print ; exit ; }' "$rigFiled" ; }
rigNotePath(){ AgentsToolsInboxNotePath rig-member "$rigNote" ; }
## The inquiry as the caller writes it: a title carrying the comment id, then its body.
rigBody(){ printf '# Fix date format %s\n\nThe body.\n' "$1" ; }

echo '-- 1. a first pass files four --'
for rigId in 4922703874 4922376200 4918509717 ; do
	rigCall "$( rigBody "$rigId" )" rig-member "inquiry-20261125T000100Z-date-format-$rigId.md" --from-comment "confluence:4919689217:$rigId"
	rigAssert "the filing of $rigId succeeds" "$rigRc" 0
done
rigCall "$( rigBody 4922671108 )" rig-member inquiry-20261125T000100Z-redundant-4922671108.md --from-comment confluence:4919263234:4922671108
rigAssert 'the filing of 4922671108 succeeds' "$rigRc" 0
rigAssert 'four inquiries are filed' "$( rigFiledCount )" 4
rigAssert 'the third identical body is its own item' "$( rigFiledRow 3 )" 'inquiry-20261125T000100Z-date-format-4918509717.md'

echo '-- 2. a reply is refused, and files nothing --'
rigCall "$( rigBody 4921294971 )" rig-member inquiry-20261125T000100Z-reply-4921294971.md --from-comment confluence:4919263234:4921294971
rigAssert 'the reply is refused' "$rigRc:$( rigFiledCount )" '1:4'
case "$rigOut" in
	*'answers another comment'*) rigAssert 'and the refusal says it answers another comment' yes yes ; ;;
	*) rigAssert 'and the refusal says it answers another comment' "$rigOut" 'a line saying it answers another comment' ; ;;
esac

echo '-- 3. a second pass files nothing --'
for rigId in 4922703874 4922376200 4918509717 ; do
	rigCall "$( rigBody "$rigId" )" rig-member "inquiry-20261125T000200Z-date-format-$rigId.md" --from-comment "confluence:4919689217:$rigId"
done
rigCall "$( rigBody 4922671108 )" rig-member inquiry-20261125T000200Z-redundant-4922671108.md --from-comment confluence:4919263234:4922671108
rigAssert 'the second pass files nothing' "$( rigFiledCount )" 4
rigAssert 'and every one of its calls still succeeds' "$rigRc" 0

echo '-- 4. nothing is half done --'
rigCall "$( printf '# Fix date format\n\nThe body.\n' )" rig-member inquiry-20261125T000300Z-no-id.md --from-comment confluence:4919689217:4918509717
rigAssert 'a title without the id is refused' "$rigRc:$( rigFiledCount )" '1:4'
case "$rigOut" in
	*'must carry the comment id'*) rigAssert 'and the refusal names the comment id' yes yes ; ;;
	*) rigAssert 'and the refusal names the comment id' "$rigOut" 'a line naming the comment id' ; ;;
esac
rigCall "$( rigBody 4929999999 )" rig-member inquiry-20261125T000300Z-absent.md --from-comment confluence:4919689217:4929999999
rigAssert 'a comment not on that page is refused' "$rigRc:$( rigFiledCount )" '1:4'
rigCall "$( rigBody 4922703874 )" rig-member inquiry-20261125T000300Z-shape.md --from-comment confluence:4919689217
rigAssert 'a two-part value is refused' "$rigRc:$( rigFiledCount )" '1:4'
rigCall "$( rigBody 4922703874 )" rig-member inquiry-20261125T000300Z-drive.md --from-comment drive:abcdef:4922703874
rigAssert 'a service with no comment read is refused' "$rigRc:$( rigFiledCount )" '1:4'

echo '-- 5. control: the watermark lands out of every scan’s reach --'
rigAssert 'the note is at the state-and-lock path' "$( [ -f "$( rigNotePath )" ] && printf found || printf missing ):$( [ "$( rigNotePath )" = "$MDAT_DATA_ROOT/inboxes/rig-member/processed/$rigNote" ] && printf processed || printf elsewhere )" 'found:processed'
rigAssert 'and it records the four filed comments, one a line' "$( LC_ALL=C grep -c -x -F -e 'confluence:4919689217:4922703874' -e 'confluence:4919689217:4922376200' -e 'confluence:4919689217:4918509717' -e 'confluence:4919263234:4922671108' "$( rigNotePath )" || : )" 4
rigAssert 'and nothing of it is in incoming/' "$( [ -f "$MDAT_DATA_ROOT/inboxes/rig-member/incoming/$rigNote" ] && printf present || printf absent )" absent

if [ "$rigFail" = 0 ] ; then printf 'INQUIRY_FROM_COMMENT: OK (%s assertions, offline, temp store only)\n' "$rigPass" ; exit 0 ; fi
printf '⛔ INQUIRY FROM COMMENT CHECK FAILED: %s of %s assertion(s)\n' "$rigFail" "$(( rigPass + rigFail ))" ; exit 1
