#!/usr/bin/env bash
## Behavioural check on a contact's tier within one project scope (S6.50, task-20261109T1436Z-per-project-contact-tier): a record carries a tier
## per scope, and `--contacted-by` answers two different questions with them -- the tier of the project scope it is given, and the Slack
## workspace its value is looked up in. A project scope is no Slack workspace, so each question keeps its own word. Run rather than read, in a
## rig: a workspace with its team data root, a HOME, the real tooling, and a Slack-shaped fake curl first on PATH. Held:
##   1. THE PROJECT SCOPE, WITH A SLACK VALUE. A record whose Slack coordinate is in one member's workspace, read for the project scope `rmm2`,
##      is found, and stands at that scope's tier -- with the Slack team named and with it left out.
##   2. THE RECORD'S OWN TIER, where no scope is named.
##   3. THE SLACK TEAM STILL FILTERS. The same value read within another workspace finds nobody, so the filter is wired and not dropped.
##   4. THE SYNTAX SAYS BOTH. `--team <scope>` names the scope, `--slack-team <team>` the workspace.
## Red before this build: one value was passed to both questions, so a Slack id read for a project scope found nobody at all, and the syntax
## named one flag for the two.
## Offline: the fake curl answers every request, so nothing here reaches Slack or any endpoint.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsContacts.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigPackage/sh-test/check-fixtures/harness-ask-check.curl.stub.sh" ] || rigRefuse "the fake curl fixture is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsContactsProjectTierCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigWs="$rigTmp/ws" rigHome="$rigTmp/home" rigData="$rigTmp/data" rigBin="$rigTmp/bin"
mkdir -p "$rigWs/.local/temp" "$rigWs/.local/.agents" "$rigHome" "$rigData" "$rigBin"
cp "$rigPackage/sh-test/check-fixtures/harness-ask-check.curl.stub.sh" "$rigBin/curl" && chmod +x "$rigBin/curl" || rigRefuse "the fake curl could not be put in the rig"
## The account at the console that is the human-owner: the record's tier and its scope tiers are his to set.
rigAcct="$( id -un 2> /dev/null )" || rigAcct="unknown"
rigAcct="$( printf '%s' "$rigAcct" | LC_ALL=C tr -s ' \t\r\n' '_' )"
printf 'HUMAN_OWNER_CONSOLE_ACCOUNT=%s\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' "$rigAcct" > "$rigWs/.local/.agents/magic-team.agent.env"
## The members the rig's calls act as: a send names one, and its skill folder must stand.
for rigMember in keeper-x client-ndm magic-coordinator human-owner ; do
	mkdir -p "$rigWs/.local/agents/members/$rigMember"
	printf -- '---\nname: %s\ndescription: rig member\n---\n' "$rigMember" > "$rigWs/.local/agents/members/$rigMember/SKILL.md"
	printf 'rig\n' > "$rigWs/.local/agents/members/$rigMember/$rigMember.basic.md"
done
RIG_CURL_LOG="$rigTmp/curl.log" RIG_SCENARIO="$rigTmp"
export RIG_CURL_LOG RIG_SCENARIO
: > "$RIG_CURL_LOG"
rigRun(){ ## result prefix, the tool's words... -- rc in rigRc
	local runOut="$1" ; shift
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigBin:$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_DATA_ROOT="$rigData" RIG_TMP="$rigTmp" RIG_CURL_LOG="$RIG_CURL_LOG" RIG_SCENARIO="$RIG_SCENARIO" \
		bash "$rigTool" "$@" ) > "$runOut.out" 2> "$runOut.err" < /dev/null
	rigRc=$?
}
rigHas(){ ## fixed text, file -- how many lines of the file hold it
	LC_ALL=C grep -c -F -- "$1" "$2" 2> /dev/null || :
}
## One contact, the human-owner's: its own tier, and a tier for each of two project scopes.
rigRun "$rigTmp/c1" --collect-contact --id bob-one --name "Bob One" --tier tier-contact \
	--scope-tier ndmp=tier-admin --scope-tier rmm2=tier-client --slack keeper-x:U111ABC --reached-by keeper-x
rigAssert "the rig's contact is recorded with its own tier and two scope tiers" \
	"$rigRc $( rigHas 'tier: tier-contact' "$rigData/contacts/persons/bob-one.md" ) $( rigHas 'scope-tiers: ndmp=tier-admin,rmm2=tier-client' "$rigData/contacts/persons/bob-one.md" )" "0 1 1"

echo "-- 1. the project scope, read with a Slack value --"
## THE DEFECT: the scope named here is not a Slack workspace, so it must not narrow the lookup of the Slack value.
rigRun "$rigTmp/a1" --contacted-by keeper-x:U111ABC --team rmm2
rigAssert "a Slack value read for the project scope rmm2 is found, and stands at that scope's tier" \
	"$rigRc $( rigHas 'This contact is a client.' "$rigTmp/a1.out" )" "0 1"
rigRun "$rigTmp/a2" --contacted-by U111ABC --team rmm2
rigAssert "the same, the value given as the bare Slack id" \
	"$rigRc $( rigHas 'This contact is a client.' "$rigTmp/a2.out" )" "0 1"
rigRun "$rigTmp/a3" --contacted-by U111ABC --slack-team keeper-x --team rmm2
rigAssert "the same, with the Slack workspace named beside the scope" \
	"$rigRc $( rigHas 'This contact is a client.' "$rigTmp/a3.out" )" "0 1"
rigRun "$rigTmp/a4" --contacted-by bob-one --team ndmp
rigAssert "the other scope reads back its own tier, the record found by its id" \
	"$rigRc $( rigHas 'This contact is an admin.' "$rigTmp/a4.out" )" "0 1"

echo "-- 2. the record's own tier, where no scope is named --"
rigRun "$rigTmp/b1" --contacted-by U111ABC
rigAssert "no scope named: the record's own tier, and no scope's" \
	"$rigRc $( rigHas 'This contact stands at Contact.' "$rigTmp/b1.out" ) $( rigHas 'This contact is a client.' "$rigTmp/b1.out" )" "0 1 0"

echo "-- 3. the Slack workspace still filters --"
rigRun "$rigTmp/o1" --contacted-by U111ABC --slack-team other-team
rigAssert "the same value read within another Slack workspace finds nobody" \
	"$rigRc $( rigHas 'No contact is recorded for U111ABC.' "$rigTmp/o1.out" )" "1 1"

echo "-- 4. the syntax says both --"
rigRun "$rigTmp/s1" --help-syntax --contacted-by
rigAssert "the syntax line names the scope and the Slack workspace, each by its own word" \
	"$( rigHas '[--team <scope>]' "$rigTmp/s1.err" ) $( rigHas '[--slack-team <team>]' "$rigTmp/s1.err" )" "1 1"
rigRun "$rigTmp/s2" --contacted-by bob-one --team rmm2 --no-such-option
rigAssert "a refused option prints the same syntax" \
	"$( rigHas 'syntax is <value> [--team <scope>] [--slack-team <team>]' "$rigTmp/s2.err" )" 1

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ CONTACTS PROJECT TIER CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'CONTACTS_PROJECT_TIER: OK (%d assertions, offline, rig tree only)\n' "$rigPasses"
