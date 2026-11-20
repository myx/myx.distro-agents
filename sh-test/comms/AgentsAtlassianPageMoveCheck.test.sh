#!/usr/bin/env bash
## Offline check on `--intern-op-atlassian-confluence-page-move`: one page's parent set by
## PUT /wiki/rest/api/content/<id>/move/append/<parent>, the move carrying no body, and the
## page read back through v2 afterwards so that what is printed is where the page really is.
## The fixture is a fake `curl` that records the method, the path and whether a body was sent,
## and answers a canned body and status per method. No socket is opened.
## Red recipe: before this arm exists the include refuses the name as an invalid option, so
## every assertion about the request fails and nothing is sent.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigInc="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/atlassian/AgentsTools.InternOpAtlassianCall.include"
rigField="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessJsonField.awk"
for rigNeed in "$rigInc" "$rigField" ; do
	[ -f "$rigNeed" ] || { echo "⛔ ERROR: no $rigNeed" >&2 ; exit 1 ; }
done
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsAtlassianPageMoveCheck )" || exit 1
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

## The gates around the transport are not what is under test: they pass without touching
## a scope, and the three CONFLUENCE_* keys in the environment answer the credential whole.
DistroAgentsTools(){ echo "scope-read reached" >&2 ; return 1 ; }
AgentsToolsAssertBareName(){ return 0 ; }
AgentsToolsCommsOwnSideCheck(){ return 0 ; }
AgentsToolsCommsOwnSettingsApply(){ return 0 ; }
## The fake curl records the method, the path and whether a body travelled, then answers
## the canned body and status of its own method, the way the real one does under `-w '\n%{http_code}'`.
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

export CONFLUENCE_SITE="rig-move.atlassian.invalid" CONFLUENCE_USER="us@rig.invalid" CONFLUENCE_API_TOKEN="rig-token"
MDSC_CMD='DistroAgentsTools'
rigPage="4861231112"
rigParent="4919263234"
rigMovedPage="{\"id\":\"$rigPage\",\"parentId\":\"$rigParent\",\"title\":\"RMM2 the plan\",\"status\":\"current\",\"version\":{\"number\":16}}"

## The move answers 204 with no content, which is a real answer and exits 0.
rigAnswer PUT 204 ""
rigAnswer GET 200 "$rigMovedPage"
rigRun --intern-op-atlassian-confluence-page-move --member routine-move --page-id "$rigPage" --parent-id "$rigParent"
rigAssert "the arm runs at all" "$rigRc" "0"
rigAssert "the move is the v1 append route, and the read-back is v2" "$( LC_ALL=C sed -n 1p "$rigCalls" )/$( LC_ALL=C sed -n 2p "$rigCalls" )" \
	"PUT /wiki/rest/api/content/$rigPage/move/append/$rigParent none/GET /wiki/api/v2/pages/$rigPage none"
rigAssert "the printed row is the read-back's own answer" "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 2p )" \
	"$rigPage	RMM2 the plan	$rigParent"
rigAssert "and its header names the three columns" "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 1p )" "PAGE_ID	TITLE	PARENT_ID"

## The read-back is what decides success: a move the answer claims and the page denies is UNKNOWN.
rigAnswer GET 200 "{\"id\":\"$rigPage\",\"parentId\":\"4799889413\",\"title\":\"RMM2 the plan\"}"
rigRun --intern-op-atlassian-confluence-page-move --member routine-move --page-id "$rigPage" --parent-id "$rigParent"
rigAssert "a page still under another parent is UNKNOWN, rc 3" "$rigRc" "3"
case "$rigErr" in
	*4799889413*) rigAssert "and the parent it reads back under is named" yes yes ;;
	*) rigAssert "and the parent it reads back under is named" "$rigErr" "the parent it read back under" ;;
esac

## A read-back that cannot be made says nothing about where the page is, and says so.
rigAnswer PUT 204 ""
rigAnswer GET 500 '{"message":"throttled"}'
rigRun --intern-op-atlassian-confluence-page-move --member routine-move --page-id "$rigPage" --parent-id "$rigParent"
rigAssert "a failed read-back is UNKNOWN, rc 3, never a success" "$rigRc" "3"

## A refused move stops there: no read-back is made for it.
rigAnswer PUT 404 '{"message":"no such page"}'
rigAnswer GET 200 "$rigMovedPage"
rigRun --intern-op-atlassian-confluence-page-move --member routine-move --page-id "$rigPage" --parent-id "$rigParent"
rigAssert "a 404 is the missing class, rc 8" "$rigRc" "8"
rigAssert "and nothing is read back" "$( LC_ALL=C wc -l < "$rigCalls" | LC_ALL=C tr -d ' ' )" "1"

## Refused before anything is sent: the instrument's own control that a refusal leaves no call.
rigRun --intern-op-atlassian-confluence-page-move --member routine-move --page-id "$rigPage"
rigAssert "a call with no --parent-id is refused" "$rigRc" "1"
rigAssert "and nothing is sent" "$( cat "$rigCalls" )" ""
rigRun --intern-op-atlassian-confluence-page-move --member routine-move --page-id "48x" --parent-id "$rigParent"
rigAssert "a page id that is not a number is refused" "$rigRc" "1"
rigAssert "and nothing is sent for it either" "$( cat "$rigCalls" )" ""

if [ "$rigFail" = 0 ] ; then printf 'ATLASSIAN_PAGE_MOVE: OK (%s assertions, offline)\n' "$rigPass" ; exit 0 ; fi
printf '⛔ ATLASSIAN PAGE MOVE CHECK FAILED: %s of %s assertion(s)\n' "$rigFail" "$(( rigPass + rigFail ))" ; exit 1
