#!/usr/bin/env bash
## Behavioural check on the gate under the page writes and the Trello comment. The owner ruled that the librarian
## writes the pages and their comments, and the caller check carries that ruling; this drives the tool files
## themselves, so the gate a real call passes after that check is read too. Held:
##   1. magic-librarian reaches the operation on all five: page create, page update, page move, the page comment
##      and the Trello comment, each with its own call on the fake site
##   2. another member calling a page write is still refused, and the site is asked nothing
##   3. CONTROLS: magic-librarian is still refused the stub operations outside the ruling, the coordinator still
##      reaches a page write, and the site answers, so a quiet run is not a run against nothing
## Red recipe: before the comms gate carried the ruling, arm 1's four page calls ended at
## `runs only as magic-coordinator, and magic-librarian is not it`, reached no site, and every site assertion failed,
## while arms 2 and 3 passed before and after. Offline: a fake curl stands for both sites, and answers only the
## Confluence site this rig names and the Trello address the include writes itself.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigAtlassian="$rigPackage/sh-scripts/DistroAgentsAtlassian.fn.sh"
rigTrello="$rigPackage/sh-scripts/DistroAgentsTrello.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigAtlassian" ] || rigRefuse "the Atlassian tool is not at the origin: $rigAtlassian"
[ -f "$rigTrello" ] || rigRefuse "the Trello tool is not at the origin: $rigTrello"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsLibrarianPageWriteGateCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

rigWs="$rigTmp/ws" rigHome="$rigTmp/home" rigData="$rigTmp/data" rigSkills="$rigTmp/skills" rigState="$rigTmp/site" rigBin="$rigTmp/bin"
mkdir -p "$rigWs/.local/temp" "$rigWs/.local/.agents" "$rigHome" "$rigData" "$rigState" "$rigBin"
for rigName in magic-coordinator magic-librarian keeper-myx ; do
	mkdir -p "$rigSkills/$rigName"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigName/$rigName.basic.md"
	printf -- '---\nmaintainers: rig\n---\nrig\n' > "$rigSkills/$rigName/$rigName.armed.md"
done

## THE FAKE SITES: one stand-in for Confluence and Trello, on the arguments the request layer builds, answering as
## `curl -w '\n%{http_code}'` does. It logs method, host and path, and answers only the Confluence site this rig
## names and the Trello address the include writes itself; no socket is opened, so any other host is a fault.
cat > "$rigBin/curl" <<'RIGCURL'
#!/bin/sh
rigMethod=GET
rigUrl=""
while [ $# -gt 0 ] ; do
	case "$1" in
		-X) rigMethod="$2" ; shift 2 ;;
		--data-binary|--data-urlencode|-H|-w|--connect-timeout|--max-time|-K) shift 2 ;;
		https://*) rigUrl="$1" ; shift ;;
		*) shift ;;
	esac
done
cat > /dev/null
rigRest="${rigUrl#https://}"
rigHost="${rigRest%%/*}"
rigPath="/${rigRest#*/}"
printf '%s %s %s\n' "$rigMethod" "$rigHost" "$rigPath" >> "$RIG_STATE/calls"
case "$rigHost" in
	*.invalid|api.trello.com) ;;
	*)
		printf '{"message":"rig: %s is not the fake site"}\n599' "$rigHost"
		exit 0
	;;
esac
rigBody='{"message":"rig: no fixture"}'
rigStatus=404
case "$rigMethod $rigPath" in
	"PUT /wiki/api/v2/pages/7000000001") rigBody='{"id":"7000000001","version":{"number":8}}' ; rigStatus=200 ;;
	"POST /wiki/api/v2/pages") rigBody='{"id":"7000000009"}' ; rigStatus=200 ;;
	"PUT /wiki/rest/api/content/7000000001/move/append/7000000002") rigBody='{}' ; rigStatus=200 ;;
	"GET /wiki/api/v2/pages/7000000001") rigBody='{"id":"7000000001","title":"Rig page","parentId":"7000000002"}' ; rigStatus=200 ;;
	"POST /wiki/api/v2/footer-comments") rigBody='{"id":"9000000009"}' ; rigStatus=201 ;;
	"POST /1/cards/RIGCARD0001/actions/comments") rigBody='{"id":"6000000001"}' ; rigStatus=200 ;;
esac
printf '\n%s\n%s' "$rigBody" "$rigStatus"
RIGCURL
chmod +x "$rigBin/curl" || rigRefuse "the fake site could not be written"
printf '#!/bin/sh\nexec bash "%s" "$@"\n' "$rigAtlassian" > "$rigBin/rig-atlassian" || rigRefuse "the Atlassian stand-in could not be written"
printf '#!/bin/sh\nexec bash "%s" "$@"\n' "$rigTrello" > "$rigBin/rig-trello" || rigRefuse "the Trello stand-in could not be written"
chmod +x "$rigBin/rig-atlassian" "$rigBin/rig-trello" || rigRefuse "a tool stand-in could not be made executable"

rigPageId="7000000001" rigParentId="7000000002" rigCardId="RIGCARD0001"
rigRc=0
rigCall(){ ## member, tool, words... -- one call through the tool file, rc in rigRc
	local callMember="$1" callTool="$2" ; shift 2
	: > "$rigState/calls"
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$rigBin:/usr/bin:/bin" MMDAPP="$rigWs" \
		MDAT_WORKSPACE_MODE=team-rig MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SPAWN_AGENT="$callMember" RIG_STATE="$rigState" RIG_TOOL="$callTool" \
		CONFLUENCE_SITE=rig-confluence.invalid CONFLUENCE_USER=us@rig.invalid CONFLUENCE_API_TOKEN=rig-token \
		JIRA_SITE=rig-jira.invalid JIRA_USER=us@rig.invalid JIRA_API_TOKEN=rig-token \
		TRELLO_KEY=rig-key TRELLO_TOKEN=rig-token \
		bash -c 'exec bash "$RIG_TOOL" "$@"' rig "$@" ) \
		> "$rigTmp/out" 2> "$rigTmp/err" < /dev/null
	rigRc=$?
}
rigCalls(){ ## -- what the fake site was asked, one call a line
	LC_ALL=C cat "$rigState/calls" 2> /dev/null || :
}
rigErrHas(){ ## text -- how many lines of the last call's stderr carry it
	LC_ALL=C grep -c -F -- "$1" "$rigTmp/err" 2> /dev/null || :
}

echo '-- 1. magic-librarian reaches the operation on all five --'
rigCall magic-librarian "$rigBin/rig-atlassian" --confluence-page-update --team-member magic-librarian "$rigPageId" \
	--version 7 --title "Rig page" --status current --body-storage '<p>the new body</p>'
rigAssert "a page update by magic-librarian runs" "$rigRc" 0
rigAssert "and the page is written on the fake site" "$( rigCalls )" "PUT rig-confluence.invalid /wiki/api/v2/pages/$rigPageId"
rigCall magic-librarian "$rigBin/rig-atlassian" --confluence-page-create --team-member magic-librarian --space-id 5001 \
	--title "Rig page" --body-storage '<p>a new page</p>'
rigAssert "a page create by magic-librarian runs" "$rigRc" 0
rigAssert "and the page is created on the fake site" "$( rigCalls )" "POST rig-confluence.invalid /wiki/api/v2/pages"
rigCall magic-librarian "$rigBin/rig-atlassian" --confluence-page-move --team-member magic-librarian "$rigPageId" --parent-id "$rigParentId"
rigAssert "a page move by magic-librarian runs" "$rigRc" 0
rigAssert "and the move and its read-back both reach the fake site" "$( rigCalls | LC_ALL=C tr '\n' '|' )" \
	"PUT rig-confluence.invalid /wiki/rest/api/content/$rigPageId/move/append/$rigParentId|GET rig-confluence.invalid /wiki/api/v2/pages/$rigPageId|"
rigCall magic-librarian "$rigBin/rig-atlassian" --confluence-comment-add --team-member magic-librarian "$rigPageId" \
	--body-storage '<p>a reply</p>'
rigAssert "a page comment by magic-librarian runs" "$rigRc" 0
rigAssert "and the comment is posted on the fake site" "$( rigCalls )" "POST rig-confluence.invalid /wiki/api/v2/footer-comments"
rigCall magic-librarian "$rigBin/rig-trello" --trello-post-comment --team-member magic-librarian "$rigCardId" 'a rig comment'
rigAssert "a Trello comment by magic-librarian runs" "$rigRc" 0
rigAssert "and the comment is posted on the fake site" "$( rigCalls )" "POST api.trello.com /1/cards/$rigCardId/actions/comments"

echo '-- 2. another member is still refused a page write, and nothing is sent --'
rigCall keeper-myx "$rigBin/rig-atlassian" --confluence-page-update --team-member keeper-myx "$rigPageId" \
	--version 7 --title "Rig page" --status current --body-storage '<p>a body</p>'
rigAssert "a page update by another member is refused" "$rigRc" 1
rigAssert "and the refusal names that member" "$( rigErrHas 'keeper-myx' )" 1
rigAssert "and the site is asked nothing" "$( rigCalls )" ''

echo '-- 3. controls: the stub operations outside the ruling stay the coordinator'"'"'s --'
rigCall magic-librarian "$rigBin/rig-atlassian" --confluence-space-create --team-member magic-librarian --key RIGSPACE --name "Rig space"
rigAssert "magic-librarian is still refused a space create" "$rigRc" 1
rigAssert "and the site is asked nothing for it" "$( rigCalls )" ''
rigCall magic-librarian "$rigBin/rig-atlassian" --jira-issue-create --team-member magic-librarian --project RIG --issuetype Task --summary "rig ticket"
rigAssert "magic-librarian is still refused a Jira issue create" "$rigRc" 1
rigAssert "and the site is asked nothing for it" "$( rigCalls )" ''
rigCall magic-coordinator "$rigBin/rig-atlassian" --confluence-page-update --team-member magic-coordinator "$rigPageId" \
	--version 7 --title "Rig page" --status current --body-storage '<p>a body</p>'
rigAssert "control: the coordinator still reaches a page write" "$rigRc" 0
rigAssert "control: and the fake site answered it" "$( rigCalls )" "PUT rig-confluence.invalid /wiki/api/v2/pages/$rigPageId"

if [ "$rigFail" = 0 ] ; then printf 'LIBRARIAN PAGE WRITE GATE: OK (%s assertions, offline)\n' "$rigPass" ; exit 0 ; fi
printf '⛔ LIBRARIAN PAGE WRITE GATE CHECK FAILED: %s of %s assertion(s)\n' "$rigFail" "$(( rigPass + rigFail ))" ; exit 1
