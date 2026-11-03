#!/usr/bin/env bash
## Behavioural check on S24.10 of the refactorings epic: A ROUTINE STEP DUPLICATES A VAULT DOCUMENT TO CONFLUENCE AND
## CREATES OR LINKS ITS JIRA TASK. Read over the package's own routine, then run: step 10 of
## `magic-team.investigate.routine.md` marks a settled investigation report, and the two Atlassian operations it
## names are driven here against a fake site. Held:
##   1. control: step 10 of the routine's Steps region is found, and it is `publish-the-report`
##   2. it names the tool `DistroAgentsAtlassian`, and the three operations it may use
##   3. it says both happen in the workspace that holds that organisation's identities
##   4. control that the reading can fail: on a copy whose step 10 names another operation, the same reading differs
##   5. the report is a typed vault document, and the page created carries that document's own body, byte for byte
##   6. the page reads back through a second path with the report's title
##   7. the Jira task is created for that report, and reads back with its summary
##   8. where the task already exists, the search the step names finds it, so the step's "found" branch has its fact
##   9. control: the write operations run only as magic-coordinator, and are refused for any other member
##  10. control: with no Confluence identity the page is refused (rc 6) and nothing reaches the site
##  11. nothing left the rig: every call the fake site logged went to a host ending `.invalid`
##  12. the step's "and a link" half: the task found links to the page, the stored link is read back through
##      `--jira-issue-link-list`, a retry leaves one link, and a write by another member, a missing address or a
##      task the site does not hold is refused
## Offline: a fake `curl` first on PATH that answers as the Atlassian site and opens no socket; the rig's own team
## data and workspace under this workspace's scratch.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigItems="$rigPackage/sh-scripts/DistroAgentsItems.fn.sh"
rigAtlassian="$rigPackage/sh-scripts/DistroAgentsAtlassian.fn.sh"
rigRoutine="$rigPackage/skillset/magic-team/magic-team/magic-team.investigate.routine.md"
rigStub="$rigPackage/sh-test/check-fixtures/investigate-publish.curl.stub.py"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigNeed in "$rigItems" "$rigAtlassian" "$rigRoutine" "$rigStub" ; do
	[ -f "$rigNeed" ] || rigRefuse "not at the origin this workspace resolves: $rigNeed"
done
command -v python3 > /dev/null 2>&1 || rigRefuse "no python3 on PATH, so the fake site cannot answer"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsInvestigatePublishCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigStepText(){ ## routine file, step number -- that numbered step of `# Steps`, its numbering removed
	LC_ALL=C awk -v wantStep="$2" '
		/^# Steps$/ { inSteps = 1 ; next }
		inSteps && /^# / { exit }
		inSteps && /^[0-9]+\. / {
			if ( taking ) { exit }
			stepNumber = $0 ; sub( /\..*/, "", stepNumber )
			if ( stepNumber + 0 == wantStep + 0 ) { taking = 1 ; print }
			next
		}
		taking { print }
	' "$1"
}

rigWs="$rigTmp/ws" rigHome="$rigTmp/home" rigData="$rigTmp/data" rigSkills="$rigTmp/skills" rigState="$rigTmp/site" rigBin="$rigTmp/bin"
mkdir -p "$rigWs/.local/temp" "$rigWs/.local/.agents" "$rigHome" "$rigData" "$rigSkills/magic-coordinator" "$rigSkills/magic-tester" "$rigState" "$rigBin"
for rigMember in magic-coordinator magic-tester ; do
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
done
cp "$rigStub" "$rigBin/curl" && chmod +x "$rigBin/curl" || rigRefuse "the fake site fixture could not be put on the rig's PATH"
## The read half of the Atlassian front calls `DistroAgentsTools` as a command, so the rig holds one that runs the
## package's own file: the same entry a member's shell reaches.
printf '#!/bin/sh\nexec bash "%s" "$@"\n' "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" > "$rigBin/DistroAgentsTools"
chmod +x "$rigBin/DistroAgentsTools"
export PATH="$rigBin:/usr/bin:/bin"
[ "$( command -v curl )" = "$rigBin/curl" ] || rigRefuse "the fake site is not first on PATH, so this check would reach a real site"

## The identities travel in the environment, which the Atlassian layer reads before any scope: a rig's own view of
## the D4 rule, and the one way this check needs no config store of its own. A call that must see no Confluence
## identity leaves them out.
rigIdentities=( CONFLUENCE_SITE=confluence-rig.invalid CONFLUENCE_USER=us@rig.invalid CONFLUENCE_API_TOKEN=rig-confluence-token
	JIRA_SITE=jira-rig.invalid JIRA_USER=us@rig.invalid JIRA_API_TOKEN=rig-jira-token )
rigRc=0
rigCall(){ ## result prefix, caller, tool file, words... -- rc in rigRc
	local callOut="$1" callAs="$2" callTool="$3" ; shift 3
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SPAWN_AGENT="$callAs" RIG_TMP="$rigTmp" RIG_STATE="$rigState" RIG_TOOL="$callTool" \
		${rigWithIdentities:+${rigIdentities[@]}} \
		bash -c 'case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; exec bash "$RIG_TOOL" "$@"' rig "$@" ) \
		> "$callOut.out" 2> "$callOut.err" < /dev/null
	rigRc=$?
}
rigItemsCall(){ ## result prefix, caller, words...
	local itemsOut="$1" itemsAs="$2" ; shift 2
	rigCall "$itemsOut" "$itemsAs" "$rigItems" "$@"
}
rigSiteCall(){ ## result prefix, caller, words...
	local siteOut="$1" siteAs="$2" ; shift 2
	rigCall "$siteOut" "$siteAs" "$rigAtlassian" "$@"
}
rigCalls(){ ## -- the calls the fake site logged, one a line, or none
	LC_ALL=C cat "$rigState/calls" 2> /dev/null || :
}
rigForeignCalls(){ ## -- how many logged calls went to a host that does not end `.invalid`
	rigCalls | LC_ALL=C awk '$1 !~ /\.invalid$/ { n++ } END { print n + 0 }'
}

rigReportItem="investigation-20261103T0700Z-rig.md" rigMarker="RIG-ANSWER-7788" rigPageTitle="Investigation report: the rig matter"

echo "-- 1. control: step 10 of the routine is found, and it is publish-the-report --"
rigStep="$( rigStepText "$rigRoutine" 10 )"
rigAssert "step 10 is named at all" "$( [ -n "$rigStep" ] && printf found || printf none )" found
rigAssert "step 10 is publish-the-report" "$( printf '%s\n' "$rigStep" | LC_ALL=C sed -n '1s/^[0-9]*\. \*\*\([a-z-]*\)\*\*.*/\1/p' )" publish-the-report

echo "-- 2. it names the tool and the three operations --"
rigAssert "it names DistroAgentsAtlassian" "$( printf '%s\n' "$rigStep" | LC_ALL=C grep -c -- 'DistroAgentsAtlassian' )" 1
rigAssert "it names --confluence-page-create" "$( printf '%s\n' "$rigStep" | LC_ALL=C grep -c -- '--confluence-page-create' )" 1
rigAssert "it names --jira-issue-create" "$( printf '%s\n' "$rigStep" | LC_ALL=C grep -c -- '--jira-issue-create' )" 1
rigAssert "it names --jira-issue-search for the task that already exists" "$( printf '%s\n' "$rigStep" | LC_ALL=C grep -c -- '--jira-issue-search' )" 1

echo "-- 3. and it says where both happen --"
rigAssert "it says both happen in the workspace holding that organisation's identities" \
	"$( printf '%s\n' "$rigStep" | LC_ALL=C grep -c -- "workspace that holds that organisation's identities" )" 1
rigAssert "and it says an absent configuration is recorded rather than retried" \
	"$( printf '%s\n' "$rigStep" | LC_ALL=C grep -c -- 'no Confluence or Jira configured, record that' )" 1

echo "-- 4. control that the reading can fail: a copy whose step 10 names another operation --"
cp -p "$rigRoutine" "$rigTmp/renamed.md" || rigRefuse "the routine could not be copied for its own control"
LC_ALL=C sed 's/--confluence-page-create/--confluence-comment-add/' "$rigRoutine" > "$rigTmp/renamed.md"
rigAssert "the same reading on the copy does not find the page create" \
	"$( rigStepText "$rigTmp/renamed.md" 10 | LC_ALL=C grep -c -- '--confluence-page-create' )" 0

echo "-- 5. the report is a typed vault document, and the page carries its own body --"
rigWithIdentities=yes
printf -- '---\ndocument-contract: vault-item.investigation-report\ntype: investigation\nfrom: magic-tester\ndate: 2026-11-03 09:00 +0200\nstatus: final\n---\n# %s\n\n# Question\n\nDoes the publish land?\n\n# Answer\n\n%s.\n' \
	"$rigPageTitle" "$rigMarker" > "$rigTmp/report.md"
rigItemsCall "$rigTmp/v1" magic-tester --upsert-vault-investigation-report "$rigReportItem" --from-file "$rigTmp/report.md"
rigAssert "the report is written as its own contract's document" "$rigRc:$( [ -f "$rigData/vault/$rigReportItem" ] && printf stored || printf missing )" "0:stored"
rigItemsCall "$rigTmp/v2" magic-tester --get-vault-item "$rigReportItem"
rigReportBody="$( LC_ALL=C awk '$0 == "---" { if ( ++fm == 2 ) taking = 1 ; next } taking { print }' "$rigData/vault/$rigReportItem" )"
printf '%s\n' "$rigReportBody" > "$rigTmp/report-body"
rigAssert "and reads back holding its answer" "$( LC_ALL=C grep -c -F -- "$rigMarker" "$rigTmp/report-body" )" 1
rigSiteCall "$rigTmp/p1" magic-coordinator --confluence-page-create --space TEAM --title "$rigPageTitle" --body-storage-from-file "$rigTmp/report-body"
rigAssert "the page is created" "$rigRc" 0
rigSiteCall "$rigTmp/p2" magic-coordinator --confluence-page-read 1001
printf '%s\n' "$( cat "$rigTmp/p2.out" )" > "$rigTmp/page-body"
## The page body travels through the tooling's own command substitution, which takes the trailing newlines off:
## both sides are read with them off, so what is compared is the document's text and not its last byte.
rigAssert "the page's body is the report document's body" \
	"$( [ "$( cat "$rigTmp/page-body" )" = "$( cat "$rigTmp/report-body" )" ] && printf same || printf differs )" same
rigAssert "control: a body with one word changed does not read as the same" \
	"$( [ "$( LC_ALL=C sed 's/RIG-ANSWER-7788/RIG-ANSWER-0000/' "$rigTmp/page-body" )" = "$( cat "$rigTmp/report-body" )" ] && printf same || printf differs )" differs

echo "-- 6. the page reads back with the report's title --"
rigAssert "its title is the report's own" "$( LC_ALL=C sed -n 's/^# page 1001: title=\(.*\) version=.*$/\1/p' "$rigTmp/p2.err" )" "$rigPageTitle"

echo "-- 7. the Jira task is created for that report, and reads back --"
rigSiteCall "$rigTmp/j1" magic-coordinator --jira-issue-create --project RIG --issuetype Task --summary "$rigPageTitle"
rigAssert "the task is created" "$rigRc:$( LC_ALL=C grep -c -F -- 'RIG-' "$rigTmp/j1.out" )" "0:1"
rigIssueKey="$( LC_ALL=C sed -n 's/.*"key": "\(RIG-[0-9]*\)".*/\1/p' "$rigTmp/j1.out" )"
rigSiteCall "$rigTmp/j2" magic-coordinator --jira-issue-read "$rigIssueKey" --format raw
rigAssert "it reads back with the report's summary" "$( LC_ALL=C grep -c -F -- "$rigPageTitle" "$rigTmp/j2.out" )" 1

echo "-- 8. where the task already exists, the search the step names finds it --"
rigSiteCall "$rigTmp/j3" magic-coordinator --jira-issue-search 'project = RIG ORDER BY updated DESC'
rigAssert "the search ran" "$rigRc" 0
rigAssert "and names the task already filed" "$( LC_ALL=C grep -c -F -- 'RIG-9' "$rigTmp/j3.out" )" 1

echo "-- 9. control: the write operations run only as the coordinator --"
rigSiteCall "$rigTmp/w1" magic-tester --confluence-page-create --space TEAM --title 'Investigation report: not mine' --body-storage '<p>x</p>'
rigAssert "a tester's page create is refused" "$( [ "$rigRc" != 0 ] && printf refused || printf allowed )" refused
rigSiteCall "$rigTmp/w2" magic-tester --jira-issue-create --project RIG --issuetype Task --summary 'not mine'
rigAssert "a tester's task create is refused" "$( [ "$rigRc" != 0 ] && printf refused || printf allowed )" refused
rigAssert "and each refusal names the member whose write it is" \
	"$( LC_ALL=C grep -c -e "is magic-coordinator's only" "$rigTmp/w1.err" "$rigTmp/w2.err" | LC_ALL=C awk -F: '{ n += $2 } END { print n + 0 }' )" 2

echo "-- 10. control: with no Confluence identity the page is refused and nothing is sent --"
rigCallsBefore="$( rigCalls | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )"
rigWithIdentities=""
rigSiteCall "$rigTmp/n1" magic-coordinator --confluence-page-create --space TEAM --title 'Investigation report: no identity' --body-storage '<p>x</p>'
rigAssert "the call is refused with the missing-setting code" "$rigRc" 6
rigAssert "and no request was made" "$( rigCalls | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "$rigCallsBefore"
rigAssert "the refusal names the three settings it needs" "$( LC_ALL=C grep -c -- 'CONFLUENCE_SITE/CONFLUENCE_USER/CONFLUENCE_API_TOKEN missing' "$rigTmp/n1.err" )" 1

echo "-- 11. nothing left the rig --"
rigAssert "every call the fake site logged stayed on a host ending .invalid" "$( rigForeignCalls )" 0
rigAssert "the fake site answered calls, so the sweep above had something to see" "$( [ "$( rigCalls | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" -ge 5 ] && printf yes || printf no )" yes

echo "-- 12. the task found links to the page, and the read operation prints that link --"
rigWithIdentities=yes
rigPageUrl="https://confluence-rig.invalid/wiki/spaces/TEAM/pages/1001"
rigLinksRc=0
rigLinks(){ ## issue key -- the rows --jira-issue-link-list prints for it, its header row left off, or nothing
	rigSiteCall "$rigTmp/links" magic-coordinator --jira-issue-link-list "$1"
	rigLinksRc="$rigRc"
	[ "$rigRc" -ne 0 ] || LC_ALL=C sed 1d "$rigTmp/links.out"
}
rigAssert "control: before the link, the read operation answers and prints no row for the task" "$( rigLinks RIG-9 ; printf '%s' "$rigLinksRc" )" "0"
rigAssert "and its answer names the three columns a link is given" "$( LC_ALL=C sed -n 1p "$rigTmp/links.out" )" "$( printf 'LINK_ID\tURL\tTITLE' )"
rigAssert "and states whether the list is complete" "$( LC_ALL=C grep -c -F -- 'more: unknown' "$rigTmp/links.err" )" 1
rigSiteCall "$rigTmp/l1" magic-coordinator --jira-issue-link-page RIG-9 --url "$rigPageUrl" --title "$rigPageTitle"
rigAssert "the link is made" "$rigRc" 0
rigAssert "the read operation prints the page's address and title on that task" "$( rigLinks RIG-9 )" "$( printf '1\t%s\t%s' "$rigPageUrl" "$rigPageTitle" )"
rigSiteCall "$rigTmp/l2" magic-coordinator --jira-issue-link-page RIG-9 --url "$rigPageUrl" --title "$rigPageTitle"
rigAssert "a retry leaves one link" "$rigRc:$( rigLinks RIG-9 | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "0:1"
rigSiteCall "$rigTmp/l3" magic-coordinator --jira-issue-link-page "$rigIssueKey" --url "$rigPageUrl" --title 'A "quoted" title'
rigAssert "a title with quotes reaches the site whole" "$rigRc:$( rigLinks "$rigIssueKey" )" "0:$( printf '2\t%s\t%s' "$rigPageUrl" 'A "quoted" title' )"
rigSiteCall "$rigTmp/l4" magic-tester --jira-issue-link-page RIG-9 --url "$rigPageUrl" --title 'not mine'
rigAssert "another member's link is refused" "$( [ "$rigRc" != 0 ] && printf refused || printf allowed )" refused
rigAssert "and names the member whose write it is" "$( LC_ALL=C grep -c -e "is magic-coordinator's only" "$rigTmp/l4.err" )" 1
rigSiteCall "$rigTmp/l4b" magic-tester --jira-issue-link-list RIG-9
rigAssert "the read itself is every member's, so a tester reads the same link" "$rigRc:$( LC_ALL=C sed 1d "$rigTmp/l4b.out" )" "0:$( printf '1\t%s\t%s' "$rigPageUrl" "$rigPageTitle" )"
rigCallsBefore="$( rigCalls | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )"
rigSiteCall "$rigTmp/l5" magic-coordinator --jira-issue-link-page RIG-9 --title 'no address'
rigAssert "a link with no address is refused, by that operation's own syntax line" "$( [ "$rigRc" != 0 ] && printf refused || printf allowed ):$( LC_ALL=C grep -c -- '--url <page-url>' "$rigTmp/l5.err" )" "refused:1"
rigSiteCall "$rigTmp/l6" magic-coordinator --jira-issue-link-page RIG-9 --url 'not-an-address' --title 'bad address'
rigAssert "an address that is not https is refused, and says so" "$( [ "$rigRc" != 0 ] && printf refused || printf allowed ):$( LC_ALL=C grep -c -- 'not an https address' "$rigTmp/l6.err" )" "refused:1"
rigAssert "and none of those three reached the site" "$( rigCalls | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "$rigCallsBefore"
rigSiteCall "$rigTmp/l7" magic-coordinator --jira-issue-link-page RIG-404 --url "$rigPageUrl" --title 'no such task'
rigAssert "a task the site does not hold is refused, and stores nothing" "$( [ "$rigRc" != 0 ] && printf refused || printf allowed )" refused
rigSiteCall "$rigTmp/l8" magic-coordinator --jira-issue-link-list RIG-404
rigAssert "and the read of that task is refused as not found, with no row" "$rigRc:$( LC_ALL=C sed 1d "$rigTmp/l8.out" )" "8:"
rigSiteCall "$rigTmp/l9" magic-coordinator --jira-issue-link-list
rigAssert "a read with no issue key is refused, by that operation's own syntax line" "$( [ "$rigRc" != 0 ] && printf refused || printf allowed ):$( LC_ALL=C grep -c -- '--jira-issue-link-list: syntax is' "$rigTmp/l9.err" )" "refused:1"
rigSiteCall "$rigTmp/l10" magic-coordinator --jira-issue-link-list RIG-ODD
rigAssert "an answer that is no array of links is UNKNOWN with 3, never an issue holding none" \
	"$rigRc:$( LC_ALL=C grep -c -F 'are UNKNOWN, not empty' "$rigTmp/l10.err" ):$( LC_ALL=C grep -c . "$rigTmp/l10.out" )" "3:1:0"
rigAssert "every call stayed on a host ending .invalid" "$( rigForeignCalls )" 0

if [ "$rigFails" -ne 0 ] ; then
	printf '⛔ INVESTIGATE PUBLISH CHECK FAILED: %s of %s assertion(s)\n' "$rigFails" "$(( rigPasses + rigFails ))" ; exit 1
fi
printf 'INVESTIGATE_PUBLISH: OK (%s assertions, offline)\n' "$rigPasses"
