#!/usr/bin/env bash
## Offline check on `--intern-op-atlassian-confluence-page-create`: the warning that the page it is
## about to make cannot be removed afterwards is printed before the page is made, and the create
## still happens. The fixture is a fake `curl` that records the method, the path and whether a body
## travelled, and answers a canned body and status per method. No socket is opened.
## Red recipe: before the warning arm, stderr holds no `🙋 WARNING:` line at all and the page is
## created unnamed -- a probe page left in a space, with nothing said at the moment it was made.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigInc="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/atlassian/AgentsTools.InternOpAtlassianCall.include"
[ -f "$rigInc" ] || { echo "⛔ ERROR: no $rigInc" >&2 ; exit 1 ; }
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsAtlassianPageCreateWarnCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigSent="$rigTmp/sent"

rigPass=0 rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

DistroAgentsTools(){ echo "scope-read reached" >&2 ; return 1 ; }
AgentsToolsAssertBareName(){ return 0 ; }
AgentsToolsCommsOwnSideCheck(){ return 0 ; }
AgentsToolsCommsOwnSettingsApply(){ return 0 ; }
## The fake curl records the request on stderr as well as in the file, so a merged run shows where
## the warning stands against the request that made the page.
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
	printf '%s %s %s\n' "$curlMethod" "$curlPath" "$curlBodySaid" >> "$rigSent"
	printf '%s %s\n' "$curlMethod" "$curlPath" >&2
	[ -z "$curlBodyFile" ] || cp "$curlBodyFile" "$rigTmp/call.body" 2> /dev/null || :
	printf '\n%s\n%s' "$( cat "$rigTmp/answer.$curlMethod.body" 2> /dev/null )" "$( cat "$rigTmp/answer.$curlMethod.status" 2> /dev/null )"
	return 0
}
rigAnswer(){ ## method, status, body
	printf '%s' "$3" > "$rigTmp/answer.$1.body" ; printf '%s' "$2" > "$rigTmp/answer.$1.status"
}
## One run of the arm, both streams merged into one file in the order they were written, so the
## warning's place against the request is read off the file: rc in rigRc, the merged text in rigMerged.
rigRunMerged(){
	: > "$rigSent" ; : > "$rigTmp/merged"
	rigRc=0
	( set -- "$@" ; . "$rigInc" ) > "$rigTmp/merged" 2>&1 || rigRc=$?
	rigMerged="$( cat "$rigTmp/merged" )"
}

export CONFLUENCE_SITE="rig-create.atlassian.invalid" CONFLUENCE_USER="us@rig.invalid" CONFLUENCE_API_TOKEN="rig-token"
MDSC_CMD='DistroAgentsTools'

rigAnswer POST 200 '{"id":"4930174978","title":"probe","version":{"number":1},"spaceId":"2251915754"}'
rigRunMerged --intern-op-atlassian-confluence-page-create --member routine-create --space-id 2251915754 --title probe --body-storage '<p>probe</p>'
rigAssert "the create runs at all" "$rigRc" "0"
rigAssert "and the page is made, one POST, carrying a body" "$( cat "$rigSent" )" "POST /wiki/api/v2/pages body"

rigWarnLine="$( printf '%s\n' "$rigMerged" | LC_ALL=C grep -n '🙋 WARNING:.*page created here cannot be removed afterwards' | LC_ALL=C sed -n 's/^\([0-9][0-9]*\):.*/\1/p' )"
rigPostLine="$( printf '%s\n' "$rigMerged" | LC_ALL=C grep -n '^POST /wiki/api/v2/pages$' | LC_ALL=C sed -n 's/^\([0-9][0-9]*\):.*/\1/p' )"
rigAssert "the warning that the page cannot be removed is printed" "$([ -n "$rigWarnLine" ] && echo printed || echo absent)" "printed"
rigAssert "and it stands above the request that makes the page" \
	"$([ -n "$rigWarnLine" ] && [ -n "$rigPostLine" ] && [ "$rigWarnLine" -lt "$rigPostLine" ] && echo before || echo not-before)" "before"
case "$rigMerged" in
	*⛔*) rigAssert "the warning is a warning and not a refusal" refused warned ;;
	*) rigAssert "the warning is a warning and not a refusal" warned warned ;;
esac

## A create refused before anything is sent carries its own words and no warning about a page that was never made.
rigRunMerged --intern-op-atlassian-confluence-page-create --member routine-create --space-id 2251915754 --title probe
rigAssert "a create with no body is refused" "$rigRc" "1"
rigAssert "and nothing is sent" "$( cat "$rigSent" )" ""

if [ "$rigFail" = 0 ] ; then printf 'ATLASSIAN PAGE CREATE WARN: OK (%s assertions, offline)\n' "$rigPass" ; exit 0 ; fi
printf '⛔ ATLASSIAN PAGE CREATE WARN CHECK FAILED: %s of %s assertion(s)\n' "$rigFail" "$(( rigPass + rigFail ))" ; exit 1
