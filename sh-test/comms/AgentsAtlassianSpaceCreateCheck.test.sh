#!/usr/bin/env bash
## Offline check on `--intern-op-atlassian-confluence-space-create`: one space created by
## POST /wiki/api/v2/spaces, the body built from the flags and never spliced with a
## caller's text, the created space's own URL printed, and the site's answers classified.
## The fixture is a fake `curl` that records the method, the path and the JSON body, and
## answers a canned body and status. No socket is opened, and no check prints a key value.
## Red recipe: before this arm exists the include refuses the name as an invalid option,
## so every assertion about the request fails and nothing is sent.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigInc="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.InternOpAtlassianCall.include"
rigEscape="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/mcp/AgentsMcpJsonEscape.awk"
rigField="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessJsonField.awk"
for rigNeed in "$rigInc" "$rigEscape" "$rigField" ; do
	[ -f "$rigNeed" ] || { echo "⛔ ERROR: no $rigNeed" >&2 ; exit 1 ; }
done
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsAtlassianSpaceCreateCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigArgs="$rigTmp/call.args" ; rigBody="$rigTmp/call.body"

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
## The fake curl records the method, the path and the body file, then answers the canned
## body and status the way the real one does under `-w '\n%{http_code}'`.
curl(){
	local curlArg curlMethod=GET curlPath="" curlBodyFile=""
	while [ $# -gt 0 ] ; do
		case "$1" in
			-X) curlMethod="$2" ; shift 2 ;;
			--data-binary) curlBodyFile="${2#@}" ; shift 2 ;;
			https://*) curlPath="${1#https://}" ; curlPath="/${curlPath#*/}" ; shift ;;
			@-) cat > /dev/null ; shift ;;
			*) shift ;;
		esac
	done
	printf '%s %s\n' "$curlMethod" "$curlPath" > "$rigArgs"
	if [ -n "$curlBodyFile" ] ; then cp "$curlBodyFile" "$rigBody" 2> /dev/null || : > "$rigBody" ; else : > "$rigBody" ; fi
	printf '\n%s\n%s' "$( cat "$rigTmp/answer.body" 2> /dev/null )" "$( cat "$rigTmp/answer.status" 2> /dev/null )"
	return 0
}
rigAnswer(){ ## status, body
	printf '%s' "$2" > "$rigTmp/answer.body" ; printf '%s' "$1" > "$rigTmp/answer.status"
}
## One run of the arm, from the include's own dispatcher: rc in rigRc, stdout in rigOut,
## stderr in rigErr.
rigRun(){
	: > "$rigArgs" ; : > "$rigBody"
	rigRc=0 rigOut="" rigErr=""
	rigErr="$( (
		set -- "$@" ;
		. "$rigInc"
	) 2>&1 > "$rigTmp/out" )" || rigRc=$?
	rigOut="$( cat "$rigTmp/out" )"
}

export CONFLUENCE_SITE="rig-space.atlassian.invalid" CONFLUENCE_USER="us@rig.invalid" CONFLUENCE_API_TOKEN="rig-token"
MDSC_CMD='DistroAgentsTools'
rigAnswer 201 '{"id":"42","key":"PRODUCTS","name":"Products","type":"global","status":"current","_links":{"base":"https://rig-space.atlassian.invalid/wiki","webui":"/spaces/PRODUCTS"}}'

rigRun --intern-op-atlassian-confluence-space-create --member routine-space --key PRODUCTS --name Products
rigAssert "the arm runs at all" "$rigRc" "0"
rigAssert "one space is POSTed to the v2 spaces endpoint" "$( cat "$rigArgs" )" "POST /wiki/api/v2/spaces"
rigAssert "the body carries the key and the name as the caller gave them" \
	"$( printf '%s' "$( cat "$rigBody" )" | LC_ALL=C awk -v path=key -v dialect=atlassian -f "$rigField" )/$( printf '%s' "$( cat "$rigBody" )" | LC_ALL=C awk -v path=name -v dialect=atlassian -f "$rigField" )" "PRODUCTS/Products"
rigAssert "no description is sent when none is asked for" \
	"$( printf '%s' "$( cat "$rigBody" )" | LC_ALL=C awk -v path=description -v optional=1 -v dialect=atlassian -f "$rigField" 2>/dev/null )" ""
rigAssert "the created space is printed with its own URL" "$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 2p )" \
	"42	PRODUCTS	Products	https://rig-space.atlassian.invalid/wiki/spaces/PRODUCTS"

rigAnswer 201 '{"id":"43","key":"TEAM","name":"Team","_links":{"base":"https://rig-space.atlassian.invalid/wiki","webui":"/spaces/TEAM"}}'
rigRun --intern-op-atlassian-confluence-space-create --member routine-space --key TEAM --name Team --description "The team's own space"
rigAssert "a description travels as plain text, which is the only form a create takes" \
	"$( printf '%s' "$( cat "$rigBody" )" | LC_ALL=C awk -v path=description.representation -v dialect=atlassian -f "$rigField" )/$( printf '%s' "$( cat "$rigBody" )" | LC_ALL=C awk -v path=description.value -v dialect=atlassian -f "$rigField" )" \
	"plain/The team's own space"
rigAssert "an apostrophe in the description leaves the body valid JSON" \
	"$( printf '%s' "$( cat "$rigBody" )" | python3 -c 'import json,sys ; json.load(sys.stdin) ; print("parsed")' 2>/dev/null )" "parsed"

rigAnswer 201 '{"id":"44","key":"SERVICES","name":"Services","_links":{"base":"https://rig-space.atlassian.invalid/wiki","webui":"/spaces/SERVICES"}}'
rigRun --intern-op-atlassian-confluence-space-create --member routine-space --key SERVICES --name 'A "quoted" name'
rigAssert "a double quote in the name is escaped, not spliced into the body" \
	"$( printf '%s' "$( cat "$rigBody" )" | python3 -c 'import json,sys ; print(json.load(sys.stdin)["name"])' 2>/dev/null )" 'A "quoted" name'

## The documented 404: the identity may not create spaces. The site's own body is reported,
## and the class is a refusal the caller can act on rather than a failed call.
rigAnswer 404 '{"message":"No permission to create spaces"}'
rigRun --intern-op-atlassian-confluence-space-create --member routine-space --key NOPE --name Nope
rigAssert "a 404 is the no-permission class, rc 8" "$rigRc" "8"
case "$rigErr" in
	*"No permission to create spaces"*) rigAssert "the site's own words are carried back" yes yes ;;
	*) rigAssert "the site's own words are carried back" "$rigErr" "the site's body" ;;
esac

## Refused before anything is sent: the instrument's own control that a refusal leaves no call.
rigRun --intern-op-atlassian-confluence-space-create --member routine-space --name Products
rigAssert "a call with no --key is refused" "$rigRc" "1"
rigAssert "and nothing is sent" "$( cat "$rigArgs" )" ""
rigRun --intern-op-atlassian-confluence-space-create --member routine-space --key "NOT A KEY" --name Products
rigAssert "a key outside letters, digits, '-' and '_' is refused" "$rigRc" "1"
rigAssert "and nothing is sent for it either" "$( cat "$rigArgs" )" ""

if [ "$rigFail" = 0 ] ; then printf 'ATLASSIAN_SPACE_CREATE: OK (%s assertions, offline)\n' "$rigPass" ; exit 0 ; fi
printf '⛔ ATLASSIAN SPACE CREATE CHECK FAILED: %s of %s assertion(s)\n' "$rigFail" "$(( rigPass + rigFail ))" ; exit 1
