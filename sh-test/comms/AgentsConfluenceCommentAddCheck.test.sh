#!/usr/bin/env bash
## Offline check on `--intern-op-atlassian-confluence-comment-add`: a reply takes its parent's own
## leg, so a footer parent is answered at /wiki/api/v2/footer-comments and an inline parent at
## /wiki/api/v2/inline-comments, each naming its parent; a top-level comment still goes to the
## footer leg with its page. The fixture is a fake `curl` that records the method, the path and
## the JSON body per call, and answers from files the rig sets per run. No socket is opened.
## Red recipe: before the leg came from the parent, an inline parent was looked up as a footer
## comment, so the run ended at 8 with nothing posted and every assertion about the reply failed,
## while the footer control passed both before and after.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigInc="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/atlassian/AgentsTools.InternOpAtlassianCall.include"
rigField="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessJsonField.awk"
for rigNeed in "$rigInc" "$rigField" ; do
	[ -f "$rigNeed" ] || { echo "⛔ ERROR: no $rigNeed" >&2 ; exit 1 ; }
done
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsConfluenceCommentAddCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigCalls="$rigTmp/calls" ; rigBody="$rigTmp/body"
rigPageId="7000000001" ; rigOtherPageId="7000000002"
rigFooterParent="9000000001" ; rigInlineParent="8000000011" ; rigNoParent="9999999999"

rigPass=0 rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

## The gates around the transport are not what is under test: they pass without touching a scope,
## and the three CONFLUENCE_* keys in the environment answer the credential whole.
DistroAgentsTools(){ echo "scope-read reached" >&2 ; return 1 ; }
AgentsToolsAssertBareName(){ return 0 ; }
AgentsToolsCommsOwnSideCheck(){ return 0 ; }
AgentsToolsCommsOwnSettingsApply(){ return 0 ; }
## The fake curl records the method, the path and the body file of each call, then answers the
## status and body the rig set for that leg, the way the real one does under `-w '\n%{http_code}'`.
curl(){
	local curlArg curlMethod=GET curlPath="" curlBodyFile="" curlAnswerStatus=598 curlAnswerBody='{"message":"no fixture"}'
	while [ $# -gt 0 ] ; do
		case "$1" in
			-X) curlMethod="$2" ; shift 2 ;;
			--data-binary) curlBodyFile="${2#@}" ; shift 2 ;;
			https://*) curlPath="${1#https://}" ; curlPath="/${curlPath#*/}" ; shift ;;
			@-) cat > /dev/null ; shift ;;
			*) shift ;;
		esac
	done
	printf '%s %s\n' "$curlMethod" "$curlPath" >> "$rigCalls"
	[ -z "$curlBodyFile" ] || cp "$curlBodyFile" "$rigBody" 2> /dev/null || :
	case "$curlMethod $curlPath" in
		"GET /wiki/api/v2/footer-comments/"*) curlAnswerStatus="$( cat "$rigTmp/footer.status" )" ; curlAnswerBody="$( cat "$rigTmp/footer.body" )" ; ;;
		"GET /wiki/api/v2/inline-comments/"*) curlAnswerStatus="$( cat "$rigTmp/inline.status" )" ; curlAnswerBody="$( cat "$rigTmp/inline.body" )" ; ;;
		"POST /wiki/api/v2/footer-comments"|"POST /wiki/api/v2/inline-comments") curlAnswerStatus="$( cat "$rigTmp/post.status" )" ; curlAnswerBody="$( cat "$rigTmp/post.body" )" ; ;;
	esac
	printf '\n%s\n%s' "$curlAnswerBody" "$curlAnswerStatus"
	return 0
}
## What each leg answers for the next run: leg status body.
rigAnswer(){ printf '%s' "$3" > "$rigTmp/$1.body" ; printf '%s' "$2" > "$rigTmp/$1.status" ; }
## One run of the operation, from the include's own dispatcher: rc in rigRc, stdout in rigOut,
## stderr in rigErr.
rigRun(){
	: > "$rigCalls" ; : > "$rigBody"
	rigRc=0 rigOut="" rigErr=""
	rigErr="$( (
		set -- "$@" ;
		. "$rigInc"
	) 2>&1 > "$rigTmp/out" )" || rigRc=$?
	rigOut="$( cat "$rigTmp/out" )"
}
## The recorded calls, one per line, in the order they were made.
rigCallList(){ cat "$rigCalls" ; }
## One field of the JSON body the last POST carried.
rigBodyField(){ printf '%s' "$( cat "$rigBody" )" | LC_ALL=C awk -v path="$1" -v optional=1 -v dialect=atlassian -f "$rigField" 2>/dev/null ; }
## The calls named, counted: how many a pattern matched.
rigCallCount(){ LC_ALL=C grep -c -- "$1" "$rigCalls" || : ; }

## A page's own footer comment and the reply under it, as the v2 API answers.
rigFooterParentBody="{\"id\":\"$rigFooterParent\",\"pageId\":\"$rigPageId\",\"status\":\"current\",\"body\":{\"representation\":\"storage\",\"value\":\"<p>the footer one</p>\"}}"
rigInlineParentBody="{\"id\":\"$rigInlineParent\",\"pageId\":\"$rigPageId\",\"status\":\"current\",\"resolutionStatus\":\"open\",\"body\":{\"representation\":\"storage\",\"value\":\"<p>the inline one</p>\"}}"
rigPosted="{\"id\":\"9000000009\",\"pageId\":\"$rigPageId\",\"status\":\"current\"}"
export CONFLUENCE_SITE="rig-comment.atlassian.invalid" CONFLUENCE_USER="us@rig.invalid" CONFLUENCE_API_TOKEN="rig-token"
MDSC_CMD='DistroAgentsTools'

echo '-- 1. control: a reply under a footer comment, as it was --'
rigAnswer footer 200 "$rigFooterParentBody"
rigAnswer inline 200 "$rigInlineParentBody"
rigAnswer post 201 "$rigPosted"
rigRun --intern-op-atlassian-confluence-comment-add --member routine-comment --page-id "$rigPageId" \
	--body-storage '<p>the reply</p>' --parent-comment-id "$rigFooterParent"
rigAssert 'the run succeeds' "$rigRc" 0
rigAssert 'the parent is looked up on the footer leg' "$( LC_ALL=C sed -n 1p "$rigCalls" )" "GET /wiki/api/v2/footer-comments/$rigFooterParent"
rigAssert 'and the reply is posted to the footer leg' "$( LC_ALL=C sed -n 2p "$rigCalls" )" 'POST /wiki/api/v2/footer-comments'
rigAssert 'the footer reply names its parent' "$( rigBodyField parentCommentId )" "$rigFooterParent"
rigAssert 'and carries no page, which the parent already names' "[$( rigBodyField pageId )]" '[]'

echo '-- 2. an inline comment is answered on its own leg --'
rigAnswer footer 404 "{\"message\":\"footer comment with id: [$rigInlineParent] not found\"}"
rigAnswer inline 200 "$rigInlineParentBody"
rigRun --intern-op-atlassian-confluence-comment-add --member routine-comment --page-id "$rigPageId" \
	--body-storage '<p>the reply</p>' --parent-comment-id "$rigInlineParent"
rigAssert 'the run succeeds' "$rigRc" 0
rigAssert 'the footer leg is asked first' "$( LC_ALL=C sed -n 1p "$rigCalls" )" "GET /wiki/api/v2/footer-comments/$rigInlineParent"
rigAssert 'the inline leg answers it' "$( LC_ALL=C sed -n 2p "$rigCalls" )" "GET /wiki/api/v2/inline-comments/$rigInlineParent"
rigAssert 'and the reply is posted to the inline leg' "$( LC_ALL=C sed -n 3p "$rigCalls" )" 'POST /wiki/api/v2/inline-comments'
rigAssert 'and nothing is posted to the footer leg' "$( rigCallCount '^POST /wiki/api/v2/footer-comments$' )" 0
rigAssert 'the inline reply names its parent' "$( rigBodyField parentCommentId )" "$rigInlineParent"
rigAssert 'and its body is the storage the caller gave' "$( rigBodyField body.value )" '<p>the reply</p>'

echo '-- 3. a comment id on neither leg is refused, and nothing is posted --'
rigAnswer footer 404 "{\"message\":\"footer comment with id: [$rigNoParent] not found\"}"
rigAnswer inline 404 "{\"message\":\"inline comment with id: [$rigNoParent] not found\"}"
rigRun --intern-op-atlassian-confluence-comment-add --member routine-comment --page-id "$rigPageId" \
	--body-storage '<p>the reply</p>' --parent-comment-id "$rigNoParent"
rigAssert 'the run is refused in the not-found class, rc 8' "$rigRc" 8
rigAssert 'and neither leg is posted to' "$( rigCallCount '^POST ' )" 0
rigAssert 'and only the two lookups were made' "$( rigCallCount '' )" 2
case "$rigErr" in
	*"no footer comment and no inline comment with id $rigNoParent"*) rigAssert 'the refusal names both legs' yes yes ; ;;
	*) rigAssert 'the refusal names both legs' "$rigErr" 'a line naming both legs' ; ;;
esac
case "$rigErr" in
	*'reply was NOT posted'*) rigAssert 'and says nothing was posted' yes yes ; ;;
	*) rigAssert 'and says nothing was posted' "$rigErr" 'a line saying nothing was posted' ; ;;
esac

echo '-- 4. a parent on another page is refused, and nothing is posted --'
rigAnswer footer 200 "{\"id\":\"$rigFooterParent\",\"pageId\":\"$rigOtherPageId\"}"
rigRun --intern-op-atlassian-confluence-comment-add --member routine-comment --page-id "$rigPageId" \
	--body-storage '<p>the reply</p>' --parent-comment-id "$rigFooterParent"
rigAssert 'the run is refused as a contract error, rc 1' "$rigRc" 1
rigAssert 'and nothing is posted' "$( rigCallCount '^POST ' )" 0
case "$rigErr" in
	*"$rigOtherPageId"*"$rigPageId"*) rigAssert 'and the refusal names both pages' yes yes ; ;;
	*) rigAssert 'and the refusal names both pages' "$rigErr" 'a line naming both pages' ; ;;
esac

echo '-- 5. a top-level comment still goes to the footer leg with its page --'
rigAnswer post 201 "$rigPosted"
rigRun --intern-op-atlassian-confluence-comment-add --member routine-comment --page-id "$rigPageId" --body-storage '<p>a new one</p>'
rigAssert 'the run succeeds' "$rigRc" 0
rigAssert 'in one call, to the footer leg' "$( rigCallList )" 'POST /wiki/api/v2/footer-comments'
rigAssert 'with the page it belongs to' "$( rigBodyField pageId )" "$rigPageId"
rigAssert 'and no parent' "[$( rigBodyField parentCommentId )]" '[]'

echo '-- 6. refused before anything is sent --'
rigRun --intern-op-atlassian-confluence-comment-add --member routine-comment --page-id "$rigPageId" \
	--body-storage '<p>the reply</p>' --parent-comment-id "80x11"
rigAssert 'a parent id that is not a number is refused' "$rigRc" 1
rigAssert 'and nothing is sent' "$( rigCallList )" ''
rigRun --intern-op-atlassian-confluence-comment-add --member routine-comment --page-id "$rigPageId" --parent-comment-id "$rigFooterParent"
rigAssert 'a call with no body is refused' "$rigRc" 1
rigAssert 'and nothing is sent for it' "$( rigCallList )" ''

if [ "$rigFail" = 0 ] ; then printf 'CONFLUENCE_COMMENT_ADD: OK (%s assertions, offline)\n' "$rigPass" ; exit 0 ; fi
printf '⛔ CONFLUENCE COMMENT ADD CHECK FAILED: %s of %s assertion(s)\n' "$rigFail" "$(( rigPass + rigFail ))" ; exit 1
