#!/usr/bin/env bash
## Offline check on `--intern-op-atlassian-confluence-page-delete`: a DELETE that answers 404 is
## read back once, so its answer names whether the page is missing or is one this identity may not
## delete. The fixture is a fake `curl` that records the method, the path and whether a body
## travelled, and answers a canned body and status per method. No socket is opened.
## Red recipe: before the read-back arm, a 404 prints the shared not-found line and returns 8 for a
## page this identity may not delete exactly as for a page that is not there. Both readings cannot
## be told apart, and no read is recorded.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigInc="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/atlassian/AgentsTools.InternOpAtlassianCall.include"
[ -f "$rigInc" ] || { echo "⛔ ERROR: no $rigInc" >&2 ; exit 1 ; }
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsAtlassianPageDeleteCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigCalls="$rigTmp/calls"

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
## The fake curl records the method, the path and whether a body travelled, then answers the canned
## body and status of its own method, the way the real one does under `-w '\n%{http_code}'`.
curl(){
	local curlArg curlMethod=GET curlPath="" curlBodyFile="" curlBodySaid="none"
	while [ $# -gt 0 ] ; do
		case "$1" in
			-X) curlMethod="$2" ; shift 2 ;;
			--data-binary) curlBodyFile="${2#@}" ; curlBodySaid="body" ; shift 2 ;;
			https://*) curlPath="${1#https://}" ; curlPath="/${curlPath#*/}" ; shift ;;
			@-) cat > /dev/null ; shift ;;
			*) shift ;;
		esac
	done
	printf '%s %s %s\n' "$curlMethod" "$curlPath" "$curlBodySaid" >> "$rigCalls"
	[ -z "$curlBodyFile" ] || cp "$curlBodyFile" "$rigTmp/call.body" 2> /dev/null || :
	printf '\n%s\n%s' "$( cat "$rigTmp/answer.$curlMethod.body" 2> /dev/null )" "$( cat "$rigTmp/answer.$curlMethod.status" 2> /dev/null )"
	return 0
}
rigAnswer(){ ## method, status, body
	printf '%s' "$3" > "$rigTmp/answer.$1.body" ; printf '%s' "$2" > "$rigTmp/answer.$1.status"
}
## One run of the arm, from the include's own dispatcher: rc in rigRc, stdout in rigOut,
## stderr in rigErr.
rigRun(){
	: > "$rigCalls"
	rigRc=0 rigOut="" rigErr=""
	rigErr="$( (
		set -- "$@" ;
		. "$rigInc"
	) 2>&1 > "$rigTmp/out" )" || rigRc=$?
	rigOut="$( cat "$rigTmp/out" )"
}

export CONFLUENCE_SITE="rig-delete.atlassian.invalid" CONFLUENCE_USER="us@rig.invalid" CONFLUENCE_API_TOKEN="rig-token"
MDSC_CMD='DistroAgentsTools'
rigPage="4930174978"
rigPageBody="{\"id\":\"$rigPage\",\"title\":\"probe\",\"version\":{\"number\":3},\"spaceId\":\"2251915754\",\"body\":{\"storage\":{\"value\":\"<p>probe</p>\"}}}"

## The delete answers 204 with no content, which is a real answer and exits 0.
rigAnswer DELETE 204 ""
rigAnswer GET 200 "$rigPageBody"
rigRun --intern-op-atlassian-confluence-page-delete --member routine-delete --page-id "$rigPage"
rigAssert "the arm runs at all" "$rigRc" "0"
rigAssert "the delete is the v2 page route, carrying no body" "$( cat "$rigCalls" )" "DELETE /wiki/api/v2/pages/$rigPage none"
rigAssert "and a delete that lands makes no read-back" "$( LC_ALL=C wc -l < "$rigCalls" | LC_ALL=C tr -d ' ' )" "1"

## A 404 on a page that still reads back is a refusal, not an absence.
rigAnswer DELETE 404 '{"message":"no such page"}'
rigErrPageThere=""
rigRun --intern-op-atlassian-confluence-page-delete --member routine-delete --page-id "$rigPage"
rigErrPageThere="$rigErr"
rigAssert "a refused delete is still the missing class, rc 8" "$rigRc" "8"
rigAssert "and the page is read back before the answer is given" "$( LC_ALL=C sed -n 2p "$rigCalls" )" "GET /wiki/api/v2/pages/$rigPage?body-format=storage none"
case "$rigErrPageThere" in
	*may\ not\ delete*) rigAssert "the answer names the identity's own refusal" yes yes ;;
	*) rigAssert "the answer names the identity's own refusal" "$rigErrPageThere" "a line saying this identity may not delete the page" ;;
esac

## A 404 that the read-back repeats is the absence reading, and it is a different sentence.
rigAnswer GET 404 '{"message":"no such page"}'
rigErrPageGone=""
rigRun --intern-op-atlassian-confluence-page-delete --member routine-delete --page-id "$rigPage"
rigErrPageGone="$rigErr"
rigAssert "a page absent on the read-back too is rc 8" "$rigRc" "8"
case "$rigErrPageGone" in
	*does\ not\ read\ back\ either*) rigAssert "and the answer names the absence reading" yes yes ;;
	*) rigAssert "and the answer names the absence reading" "$rigErrPageGone" "a line saying the page does not read back either" ;;
esac
case "$rigErrPageGone" in
	*may\ not\ delete*) rigAssert "and the absence reading is not the refusal sentence" refusal absence ;;
	*) rigAssert "and the absence reading is not the refusal sentence" absence absence ;;
esac

## A read-back that fails for another reason decides nothing, and the answer says so.
rigAnswer GET 403 '{"message":"forbidden"}'
rigRun --intern-op-atlassian-confluence-page-delete --member routine-delete --page-id "$rigPage"
rigAssert "a read-back refused is still rc 8" "$rigRc" "8"
case "$rigErr" in
	*UNKNOWN*) rigAssert "and whether the page is there is called UNKNOWN" yes yes ;;
	*) rigAssert "and whether the page is there is called UNKNOWN" "$rigErr" "a line calling it UNKNOWN" ;;
esac

## Refused before anything is sent: the instrument's own control that a refusal leaves no call.
rigRun --intern-op-atlassian-confluence-page-delete --member routine-delete
rigAssert "a call with no --page-id is refused" "$rigRc" "1"
rigAssert "and nothing is sent" "$( cat "$rigCalls" )" ""
rigRun --intern-op-atlassian-confluence-page-delete --member routine-delete --page-id "49x"
rigAssert "a page id that is not a number is refused" "$rigRc" "1"
rigAssert "and nothing is sent for it either" "$( cat "$rigCalls" )" ""

if [ "$rigFail" = 0 ] ; then printf 'ATLASSIAN_PAGE_DELETE: OK (%s assertions, offline)\n' "$rigPass" ; exit 0 ; fi
printf '⛔ ATLASSIAN PAGE DELETE CHECK FAILED: %s of %s assertion(s)\n' "$rigFail" "$(( rigPass + rigFail ))" ; exit 1
