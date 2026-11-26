#!/usr/bin/env bash
## Behavioural check on `--confluence-comment-resolve`: one inline comment on one page is resolved,
## a comment already resolved is answered and not written, and an id that page does not carry is
## refused with nothing sent. The Atlassian request is faked per method, so no socket is opened and
## no page is written. The operation is reached through the dispatcher that owns its name, so the
## wiring is under test too.
##
## Held, in this order:
##  1. an open inline comment is resolved: one PUT to its own leg, carrying the version read plus one,
##     the body read back unchanged and resolved true, and the row printed says where it left it
##  2. the same call again, with the comment reading resolved: no PUT at all, and the row still says resolved
##  3. control: the same page and leg with an id it does not carry is refused in the not-found class,
##     names the page and the id, and sends nothing -- so arm 1 is not a rig that answers yes to anything
##  4. an id on another page is a contract error naming both pages, and nothing is sent
##  5. a page that is not a number, an id that is not a number, and a call missing either, are refused
##     before anything is sent
##  6. a comment whose version is not a number is refused UNKNOWN, and nothing is sent
##  7. the manual of the tool file carries the operation's syntax line
##
## Red recipe: before the operation existed, the dispatcher answered `invalid option:
## --intern-op-atlassian-confluence-comment-resolve` at rc 1, so every assertion of arms 1, 2, 4, 5
## and 6 failed, arm 3's refusal passed only because nothing was sent at all, and arm 7 failed with
## them. A run of this file before the include landed gives the red counts of the handback.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigDispatchInclude="$rigPkg/sh-lib/atlassian/AgentsTools.InternOpAtlassianCall.include"
rigHelper="$rigPkg/sh-lib/atlassian/AgentsTools.AtlassianRequest.include"
rigField="$rigPkg/sh-lib/harness/AgentsHarnessJsonField.awk"
rigManual="$rigPkg/sh-lib/help/Help.DistroAgentsTools.help.md"
for rigNeed in "$rigDispatchInclude" "$rigHelper" "$rigField" "$rigManual" ; do
	[ -f "$rigNeed" ] || { echo "⛔ ERROR: no $rigNeed" >&2 ; exit 1 ; }
done
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsConfluenceCommentResolveCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
MDSC_CMD='DistroAgentsTools'

rigPageId="7000000001" ; rigOtherPageId="7000000002"
rigCommentId="8000000011" ; rigAbsentId="8000000099"
rigLeg="/wiki/api/v2/inline-comments/$rigCommentId"

## The helper is the live one, so its argument checks and its URL encoder are the code under test.
## The request itself is faked below it: a read answers the fixture, a write is recorded and the
## comment then reads back as the rig says it was left.
. "$rigHelper"
AgentsToolsAtlassianCall(){ ## member, product, method, path, context, body
	printf '%s %s\n' "$3" "$4" >> "$rigTmp/calls"
	case "$3" in
		GET)
			if [ -f "$rigTmp/written" ] ; then
				printf '%s' "$( cat "$rigTmp/back.body" )"
				return 0
			fi
			if [ "$( cat "$rigTmp/read.status" )" = "404" ] ; then
				printf '%s\n' "🙋 WARNING: fake request: 404" >&2
				return 8
			fi
			printf '%s' "$( cat "$rigTmp/read.body" )"
			return 0
		;;
		PUT)
			printf '%s' "$6" > "$rigTmp/sent.json"
			: > "$rigTmp/written"
			return 0
		;;
		*)
			printf '%s\n' "🙋 WARNING: fake request: unexpected method $3" >&2
			return 3
		;;
	esac
}
## One fixture file the next run answers from.
rigAnswer(){ printf '%s' "$2" > "$rigTmp/$1" ; }
## An inline comment as the v2 API answers it. Arguments: page, resolution status, version or empty.
rigComment(){
	local rigBody="{\"id\":\"$rigCommentId\",\"pageId\":\"$2\",\"status\":\"current\",\"resolutionStatus\":\"$3\""
	[ -z "$4" ] || rigBody="$rigBody,\"version\":{\"number\":$4,\"authorId\":\"author-1\"}"
	printf '%s' "$rigBody,\"body\":{\"representation\":\"storage\",\"storage\":{\"value\":\"<p>a &amp; b</p>\"}}}"
}
## One run of the operation, through the dispatcher that owns its name: rc in rigRc, stdout in
## rigOut, stderr in rigErr.
rigRun(){ ## the operation's own arguments
	rm -f "$rigTmp/written" "$rigTmp/sent.json"
	: > "$rigTmp/calls"
	rigRc=0 rigOut="" rigErr=""
	rigErr="$( (
		set -- --intern-op-atlassian-confluence-comment-resolve --member rig-member --context probe "$@" ;
		. "$rigDispatchInclude"
	) 2>&1 > "$rigTmp/out" )" || rigRc=$?
	rigOut="$( cat "$rigTmp/out" )"
}
## The calls the run made, one a line, in order.
rigCallList(){ cat "$rigTmp/calls" ; }
## How many calls of one method the run made.
rigCallCount(){ LC_ALL=C grep -c "^$1 " "$rigTmp/calls" || : ; }
## One field of the JSON body the last write carried.
rigSentField(){ LC_ALL=C awk -v path="$1" -v optional=1 -v dialect=atlassian -f "$rigField" < "$rigTmp/sent.json" 2>/dev/null || : ; }
## One column of the run's one data row, its header excluded.
rigPrinted(){ printf '%s\n' "$rigOut" | LC_ALL=C awk -F'\t' -v c="$1" 'NR == 2 { print $c ; }' ; }
rigPass=0 rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

echo '-- 1. an open inline comment is resolved --'
rigAnswer read.status "200"
rigAnswer read.body "$( rigComment "$rigCommentId" "$rigPageId" open 3 )"
rigAnswer back.body "$( rigComment "$rigCommentId" "$rigPageId" resolved 4 )"
rigRun --page-id "$rigPageId" --comment-id "$rigCommentId"
rigAssert 'the run succeeds' "$rigRc" 0
rigAssert 'the read, the write and the read-back, in that order' "$( rigCallList )" "GET $rigLeg?body-format=storage
PUT $rigLeg
GET $rigLeg?body-format=storage"
rigAssert 'the version sent is the one read plus one' "$( rigSentField version.number )" 4
rigAssert 'the flag sent resolves it' "$( rigSentField resolved )" true
rigAssert 'the body sent is the storage the read returned, in the shape a write takes' "$( rigSentField body.representation )" storage
rigAssert 'and carries the comment text unchanged' "$( rigSentField body.value )" '<p>a &amp; b</p>'
rigAssert 'and is not wrapped in the read answer own storage key' "[$( rigSentField body.storage.value )]" '[]'
rigAssert 'the row names the comment resolved' "$( rigPrinted 3 )" resolved
rigAssert 'the row says a write was made' "$( rigPrinted 4 )" yes
rigAssert 'the row names its comment' "$( rigPrinted 1 )" "$rigCommentId"
rigAssert 'the row names its page' "$( rigPrinted 2 )" "$rigPageId"

echo '-- 2. a comment already resolved is answered, and not written --'
rigAnswer read.body "$( rigComment "$rigCommentId" "$rigPageId" resolved 4 )"
rigRun --page-id "$rigPageId" --comment-id "$rigCommentId"
rigAssert 'the run succeeds' "$rigRc" 0
rigAssert 'nothing is written' "$( rigCallCount PUT )" 0
rigAssert 'the comment is read once and no more' "$( rigCallList )" "GET $rigLeg?body-format=storage"
rigAssert 'the row still names it resolved' "$( rigPrinted 3 )" resolved
rigAssert 'and says no write was made' "$( rigPrinted 4 )" no

echo '-- 3. control: an id that page does not carry is refused, and nothing is written --'
rigAnswer read.status "404"
rigRun --page-id "$rigPageId" --comment-id "$rigAbsentId"
rigAssert 'the run is refused in the not-found class' "$rigRc" 8
rigAssert 'nothing is written' "$( rigCallCount PUT )" 0
case "$rigErr" in
	*"$rigAbsentId"*"$rigPageId"*) rigAssert 'the refusal names the id and the page' yes yes ; ;;
	*) rigAssert 'the refusal names the id and the page' "$rigErr" 'a line naming both' ; ;;
esac

echo '-- 4. an id on another page is refused, and nothing is written --'
rigAnswer read.status "200"
rigAnswer read.body "$( rigComment "$rigCommentId" "$rigOtherPageId" open 3 )"
rigRun --page-id "$rigPageId" --comment-id "$rigCommentId"
rigAssert 'the run is refused as a contract error' "$rigRc" 1
rigAssert 'nothing is written' "$( rigCallCount PUT )" 0
case "$rigErr" in
	*"$rigOtherPageId"*"$rigPageId"*) rigAssert 'the refusal names both pages' yes yes ; ;;
	*) rigAssert 'the refusal names both pages' "$rigErr" 'a line naming both pages' ; ;;
esac

echo '-- 5. refused before anything is sent --'
rigRun --page-id "70x1" --comment-id "$rigCommentId"
rigAssert 'a page id that is not a number is refused' "$rigRc" 1
rigAssert 'and nothing is sent for it' "$( rigCallList )" ''
rigRun --page-id "$rigPageId" --comment-id "80x11"
rigAssert 'a comment id that is not a number is refused' "$rigRc" 1
rigAssert 'and nothing is sent for it' "$( rigCallList )" ''
rigRun --page-id "$rigPageId"
rigAssert 'a call with no comment id is refused' "$rigRc" 1
rigAssert 'and nothing is sent for it' "$( rigCallList )" ''
rigRun --comment-id "$rigCommentId"
rigAssert 'a call with no page id is refused' "$rigRc" 1
rigAssert 'and nothing is sent for it' "$( rigCallList )" ''

echo '-- 6. a comment whose version cannot be read is refused UNKNOWN --'
rigAnswer read.body "$( rigComment "$rigCommentId" "$rigPageId" open "" )"
rigRun --page-id "$rigPageId" --comment-id "$rigCommentId"
rigAssert 'the run is refused UNKNOWN' "$rigRc" 3
rigAssert 'and nothing is written' "$( rigCallCount PUT )" 0

echo '-- 7. a comment whose resolution status cannot be read is refused UNKNOWN --'
rigAnswer read.body "{\"id\":\"$rigCommentId\",\"pageId\":\"$rigPageId\",\"version\":{\"number\":3},\"body\":{\"representation\":\"storage\",\"storage\":{\"value\":\"<p>a &amp; b</p>\"}}}"
rigRun --page-id "$rigPageId" --comment-id "$rigCommentId"
rigAssert 'the run is refused UNKNOWN' "$rigRc" 3
rigAssert 'and nothing is written' "$( rigCallCount PUT )" 0

echo '-- 8. a comment reading dangling is refused, and nothing is written --'
rigAnswer read.body "$( rigComment "$rigCommentId" "$rigPageId" dangling 3 )"
rigRun --page-id "$rigPageId" --comment-id "$rigCommentId"
rigAssert 'the run is refused as refused-by-the-site' "$rigRc" 9
rigAssert 'and nothing is written' "$( rigCallCount PUT )" 0

echo '-- 9. the manual carries its syntax line --'
rigAssert 'the tool file manual names the operation once' "$( LC_ALL=C grep -c -F '📘 syntax: DistroAgentsAtlassian.fn.sh --confluence-comment-resolve ' "$rigManual" )" 1

printf '\n%s assertion(s) failed of %s\n' "$rigFail" "$(( rigPass + rigFail ))"
[ "$rigFail" -eq 0 ] || exit 1
exit 0
