#!/usr/bin/env bash
## Behavioural check on epic S20.8, every Jira ticket has an assignee, run against a fake Jira site: the assignee is taken
## from the contacts database, never typed as an account id. Held:
##   1. a create with no --assignee assigns the acting identity's own account, asked of the site
##   2. a create with --assignee <contact> assigns the account whose address that contact's record holds
##   3. a contact with no recorded address, or one the site knows no assignable account for, refuses the create and
##      writes nothing, said in one line that names the contact
##   4. an update with --assignee joins the assignee to the caller's own fields, and an update with --assignee but no
##      --project is refused before the site is reached
##   5. control: the site is reached at all, so a clean run is not a run against nothing
## Offline: the fake site answers every request, and refuses any host that does not end `.invalid`.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigAtlassian="$rigPackage/sh-scripts/DistroAgentsAtlassian.fn.sh"
rigContacts="$rigPackage/sh-scripts/DistroAgentsContacts.fn.sh"
rigTools="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigStub="$rigPackage/sh-test/check-fixtures/jira-assignee.curl.stub.py"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigAtlassian" ] || rigRefuse "the Atlassian tool is not at the origin this workspace resolves: $rigAtlassian"
[ -f "$rigContacts" ] || rigRefuse "the contacts tool is not at the origin this workspace resolves: $rigContacts"
[ -f "$rigTools" ] || rigRefuse "the tools front door is not at the origin this workspace resolves: $rigTools"
[ -f "$rigStub" ] || rigRefuse "the fake site fixture is missing: $rigStub"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsJiraAssigneeCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigWs="$rigTmp/ws" rigHome="$rigTmp/home" rigData="$rigTmp/data" rigSkills="$rigTmp/skills" rigState="$rigTmp/site" rigBin="$rigTmp/bin"
mkdir -p "$rigWs/.local/temp" "$rigWs/.local/.agents" "$rigHome" "$rigData" "$rigSkills/magic-coordinator" "$rigSkills/human-owner" "$rigState" "$rigBin"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"
printf -- '---\nmaintainers: rig\n---\nrig owner\n' > "$rigSkills/human-owner/human-owner.basic.md"
## THE RIG'S CURL: the fake site for every Jira call, and a Slack answer for the one permission ask the learning gate posts,
## so the ask reaches its own record and opens no socket. Anything that is neither is the fake site's, which refuses it.
## The thread read answers from $RIG_STATE/replies.json, so the human-owner's answer to an ask can be planted there.
cat > "$rigBin/curl" <<'RIGCURL'
#!/bin/sh
case "$*" in
	*slack.com/api/*)
		cat > /dev/null
		case "$*" in
			*chat.postMessage*)
				## One ts per posted message, so two asks are two threads and an answer to one answers only it.
				rigPosted=$(( $( cat "$RIG_STATE/posts" 2> /dev/null || printf 0 ) + 1 ))
				printf '%s' "$rigPosted" > "$RIG_STATE/posts"
				printf '{"ok":true,"channel":"CRIG00001","ts":"1700000001.00010%s","message":{"ts":"1700000001.00010%s","user":"URIGBOT01"}}\n' "$rigPosted" "$rigPosted"
			;;
			*conversations.replies*)
				if [ -f "$RIG_STATE/replies.json" ] ; then cat "$RIG_STATE/replies.json" ; else printf '{"ok":true,"messages":[],"has_more":false}\n' ; fi
			;;
			*) printf '{"ok":true}\n' ;;
		esac
		exit 0
	;;
esac
exec python3 "$RIG_STUB" "$@"
RIGCURL
chmod +x "$rigBin/curl" || rigRefuse "the rig's curl could not be written"
printf '#!/bin/sh\nexec bash "%s" "$@"\n' "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" > "$rigBin/DistroAgentsTools"
chmod +x "$rigBin/DistroAgentsTools"
export PATH="$rigBin:/usr/bin:/bin"
[ "$( command -v curl )" = "$rigBin/curl" ] || rigRefuse "the fake site is not first on PATH, so this check would reach a real site"
rigIdentities=( JIRA_SITE=jira-rig.invalid JIRA_USER=us@rig.invalid JIRA_API_TOKEN=rig-jira-token RIG_STUB="$rigStub" )
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
## The account at the console that is the human-owner, as AgentsContactsTierWordCheck sets it: the run that reads his answer
## is the console's, and this is what makes it his.
rigAcct="$( id -un 2> /dev/null )" || rigAcct="unknown"
rigAcct="$( printf '%s' "$rigAcct" | LC_ALL=C tr -s ' \t\r\n' '_' )"
printf 'HUMAN_OWNER_CONSOLE_ACCOUNT=%s\n' "$rigAcct" >> "$rigWs/.local/.agents/magic-team.agent.env"
rigRc=0
rigCall(){ ## result prefix, tool file, words... -- rc in rigRc
	local callOut="$1" callTool="$2" ; shift 2
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SPAWN_AGENT=magic-coordinator RIG_TMP="$rigTmp" RIG_STATE="$rigState" RIG_TOOL="$callTool" \
		"${rigIdentities[@]}" \
		bash -c 'case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; exec bash "$RIG_TOOL" "$@"' rig "$@" ) \
		> "$callOut.out" 2> "$callOut.err" < /dev/null
	rigRc=$?
}
rigCreate(){ ## result prefix, the assignee and other words... -- a Jira create as the coordinator
	local createOut="$1" ; shift
	rigCall "$createOut" "$rigAtlassian" --jira-issue-create --team-member magic-coordinator --project RIG --issuetype Task --summary "rig ticket" "$@"
}
rigCreated(){ ## -- the fields of every issue the site was asked to create, one JSON object a line
	LC_ALL=C awk '1' "$rigState/posts.json" 2> /dev/null || :
}
rigAssigneeOf(){ ## -- the assignee id of the last issue written, or nothing
	LC_ALL=C python3 - "$rigState/posts.json" <<'PY' 2> /dev/null || :
import json, sys
try:
    posts = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
last = posts[-1]
fields = last.get("fields", last)
print(fields.get("assignee", {}).get("id", ""))
PY
}
rigCalls(){ ## -- the calls the fake site logged, one a line, or none
	LC_ALL=C cat "$rigState/calls" 2> /dev/null || :
}
rigCreates(){ ## -- how many creates the fake site was asked to make
	rigCalls | LC_ALL=C grep -c 'POST /rest/api/3/issue' || :
}
rigForeign(){ ## -- how many logged calls went to a host that does not end `.invalid`
	rigCalls | LC_ALL=C awk '$1 !~ /\.invalid$/ { n++ } END { print n + 0 }'
}
rigContactsRecord(){ ## id, the words of --collect-contact after it
	local recordId="$1" ; shift
	rigCall "$rigTmp/contact-$recordId" "$rigContacts" --collect-contact --team-member magic-coordinator --id "$recordId" "$@"
}

echo "-- 1. a create with no --assignee assigns the acting identity --"
rigCreate "$rigTmp/c1"
rigAssert "the create ran"                        "$rigRc" 0
rigAssert "the ticket names the acting account"   "$( rigAssigneeOf )" "RIGME"
rigAssert "and the site was asked who the acting identity is" "$( LC_ALL=C grep -c '/rest/api/3/myself' "$rigState/calls" )" 1
rigAssert "no call left the fake site"            "$( rigForeign )" 0

echo "-- 2. a create with --assignee <contact> assigns that contact's account --"
rigContactsRecord alice --name "Alice" --email alice@rig.invalid
rigAssert "the contact was recorded"              "$rigRc" 0
rigCreate "$rigTmp/c2" --assignee alice
rigAssert "the create ran"                        "$rigRc" 0
rigAssert "the ticket names the account of that address" "$( rigAssigneeOf )" "RIGALICE"
rigAssert "and the site was asked for an assignable account of that address" \
	"$( LC_ALL=C grep -c 'assignable/search' "$rigState/calls" )" 1

echo "-- 3. an assignee that cannot be resolved refuses the create and writes nothing --"
rigContactsRecord bob --name "Bob"
rigCreate "$rigTmp/c3" --assignee bob
rigAssert "a contact with no address is refused, rc 1, naming the contact" \
	"$rigRc:$( LC_ALL=C grep -c 'the contact bob holds no single e-mail address' "$rigTmp/c3.err" )" "1:1"
rigCreate "$rigTmp/c4" --assignee nobody-recorded
rigAssert "an unrecorded contact is refused, naming it" \
	"$rigRc:$( LC_ALL=C grep -c 'no contact nobody-recorded is recorded' "$rigTmp/c4.err" )" "1:1"
rigContactsRecord carol --name "Carol" --email carol@rig.invalid
rigCreate "$rigTmp/c5" --assignee carol
rigAssert "an address the site knows no assignable account for is refused, naming the contact" \
	"$rigRc:$( LC_ALL=C grep -c 'no account assignable in RIG for the contact carol' "$rigTmp/c5.err" )" "1:1"
rigAssert "none of the three was written: still the two created tickets" "$( rigCreated | LC_ALL=C grep -c '{' )" 1

echo "-- 4. an update takes --assignee, and needs the project to check it in --"
rigCall "$rigTmp/u1" "$rigAtlassian" --jira-issue-update --team-member magic-coordinator RIG-1 --assignee alice
rigAssert "an update with no --project is refused before any site call" \
	"$rigRc:$( LC_ALL=C grep -c -- '--assignee needs --project' "$rigTmp/u1.err" )" "1:1"
rigCall "$rigTmp/u2" "$rigAtlassian" --jira-issue-update --team-member magic-coordinator RIG-1 --assignee alice --project RIG --fields-json '{"summary":"rig ticket"}'
rigAssert "an update with both ran"                "$rigRc" 0
rigAssert "and wrote both fields in one PUT"       "$( rigAssigneeOf )" "RIGALICE"

echo "-- 5. control: the site answered, and the coordinator path passed --assignee through --"
rigAssert "the site logged a create per resolved create" "$( rigCalls | LC_ALL=C grep -c 'POST /rest/api/3/issue' )" 2
rigAssert "every call stayed on the fake site"           "$( rigForeign )" 0

echo "-- 6. a human assignee below partner, while learning is on, asks the human-owner once per assignment (S20.8) --"
## A person of the other side, with no tier of its own: nobody may be assigned it while learning is on without his word.
rigContactsRecord dave --name "Dave" --email alice@rig.invalid
rigAssert "the contact was recorded"             "$rigRc" 0
rigPendings(){ ## -- how many asks are kept open in the rig's own questions store
	LC_ALL=C grep -l -x 'status: reply-pending' "$rigWs"/.local/questions/*.md 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' '
}
rigCreate "$rigTmp/l1" --assignee dave
rigAssert "with learning off the low-tier assignee goes through, as the epic says" \
	"$rigRc:$( rigAssigneeOf ):$( rigPendings )" "0:RIGALICE:0"
printf 'MDAT_SCHEDULE_LEARNING=on\n' >> "$rigWs/.local/.agents/magic-team.agent.env"
rigCreate "$rigTmp/l2" --assignee dave
rigAssert "with learning on it is put to him, and the create is refused" \
	"$rigRc:$( LC_ALL=C grep -c 'is the human-owner.s own permission' "$rigTmp/l2.err" )" "1:1"
rigAssert "and nothing was written for it"        "$( rigCreated | LC_ALL=C grep -c '{' )" 1
rigAssert "and one ask stands open, to him"       "$( rigPendings )" 1
rigAssert "the ask is posted in his own conversation, names the contact and the project, and asks once" \
	"$( LC_ALL=C awk '$0 == "address-to: human-owner" { addressee = 1 } $0 == "request-of: dave" { of = 1 } index( $0, "request-what: the Jira assignment of RIG to the contact dave" ) == 1 { what = 1 } END { printf "%d:%d", addressee + 0, of + what }' "$rigWs"/.local/questions/*.md 2> /dev/null )" "1:2"
rigCreate "$rigTmp/l3" --assignee dave
rigAssert "asking again the same assignment joins the one ask, and asks him nothing new" \
	"$rigRc:$( rigPendings )" "1:1"
## A PARTNER, ITS TIER SET AS THE HUMAN-OWNER SETS IT: his act is the record's own `tier:` line, and this check stands in
## for it by writing that line, since no other account may set a tier.
rigContactsRecord erin --name "Erin" --email alice@rig.invalid
LC_ALL=C awk '{ print ; if ( $0 == "display-name: Erin" ) { print "tier: partner" } }' "$rigData/contacts/persons/erin.md" > "$rigData/contacts/persons/erin.md.new" \
	&& mv -f "$rigData/contacts/persons/erin.md.new" "$rigData/contacts/persons/erin.md" || rigRefuse "the partner tier line could not be written"
rigCreate "$rigTmp/l5" --assignee erin
rigAssert "a partner goes through, whatever learning says, and asks him nothing" \
	"$rigRc:$( rigAssigneeOf ):$( rigPendings )" "0:RIGALICE:1"
rigCreate "$rigTmp/l4" --assignee alice
rigAssert "and a contact below partner beside it still asks, joining no other ask" \
	"$rigRc:$( rigPendings )" "1:2"

## 6b. HIS ANSWER PERFORMS THE CREATE, ONCE (S20.8, the defect keeper-myx's review found). The ask keeps the refused call
## as its action, so the answer runs that call: the ticket is created, with that contact as its assignee, and the same answer
## run a second time creates nothing more. Before this, the action was empty and the create could never happen.
echo "-- 6b. his answer to the learning ask runs the create, and only once --"
rigAskId="$( LC_ALL=C grep -l -x 'request-of: dave' "$rigWs"/.local/questions/*.md 2> /dev/null | LC_ALL=C sed -n 1p )"
rigAskId="$( basename "${rigAskId:-none}" .md )"
rigAskTs="$( LC_ALL=C sed -n 's/^question-ts: //p' "$rigWs/.local/questions/$rigAskId.md" 2> /dev/null )"
rigAssert "the open ask is found in the rig's own store, and names a posted message" \
	"$( printf '%s' "$rigAskId" | LC_ALL=C grep -c -E '^[0-9a-f-]+$' ):$( printf '%s' "$rigAskTs" | LC_ALL=C grep -c -E '^[0-9]+\.[0-9]+$' )" "1:1"
rigCreatedBefore="$( rigCreates )"
printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGBOT01","text":"asked"},{"ts":"1700000500.000001","user":"URIGOWNER","text":"yes","thread_ts":"%s"}],"has_more":false}\n' "$rigAskTs" "$rigAskTs" > "$rigState/replies.json"
rigCall "$rigTmp/l6" "$rigTools" --intern-op-pending-reply-collect --ended
rigAssert "his answer is read and acted on"            "$rigRc" 0
rigAssert "the ticket the ask held is created, and assigned to that contact" \
	"$( rigCreates ):$( rigAssigneeOf )" "$(( rigCreatedBefore + 1 )):RIGALICE"
rigAssert "the answer is stamped as used, so it can create nothing a second time" \
	"$( LC_ALL=C grep -c '^acted-at: ' "$rigWs/.local/questions/$rigAskId.md" 2> /dev/null )" 1
rigCall "$rigTmp/l7" "$rigTools" --intern-op-pending-reply-collect --ended
rigAssert "a sweep that finds nothing new creates nothing more" "$( rigCreates )" "$(( rigCreatedBefore + 1 ))"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ JIRA ASSIGNEE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'JIRA_ASSIGNEE: OK (%d assertions, offline, a fake site)\n' "$rigPassCount"
