#!/usr/bin/env bash
## Behavioural check on the settings fallback where it meets the two sides of a client-* member, run rather than read,
## against a fixture machine built here in the form of AgentsClientSystemsCheck: one HOME, ws-here where everything is
## run from, ws-there where client-ndm is set up and holds its settings of all six systems. THE FALLBACK: a member's
## own settings of a system that the workspace we run from holds none of are read from the workspace the member is
## set up in, each system whole and from one workspace, and the tooling says so in one line. THE SIDES: a client-*
## member's own settings are the other organisation's, read where its operation reaches that organisation and never
## for our own side. Held together here: a --client-* operation of a system this workspace holds none of reads it
## from the workspace the client is set up in; one this workspace holds is read here, nothing borrowed; one setting
## of a system held here, and that system is read here alone, so no credential is put together from two workspaces;
## the team's own settings are never borrowed and never stand in for the client's; a --member-* operation of the
## client is our own side, with nothing of the client's borrowed for it; and the client's own sweep reads the borrowed
## systems and writes none of their settings here, which would cut the rest off; and where a person writes one here,
## the tooling says in one line which system is read here alone from then on and which settings of it, held in the
## other workspace, are no longer read, by their names and never a value; and where a person deletes the last
## setting of a system held here, the mirror of that line says the system is read from the other workspace again.
## Offline: the fake `curl` and
## `python3` of AgentsClientSystemsCheck, first on PATH, log each call with whose settings it carried. Every value of
## the fixture says whose it is: NDMTHERE the client's in the workspace it is set up in, NDMHERE the client's in this
## one, TEAMHERE and TEAMTHERE the two workspaces' own teams. What the stubs cannot show: a real answer of any system.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
rigRealPython="$( command -v python3 )" || rigRefuse "no python3 on PATH to hand every other script to"
rigTmp="$( mktemp -d -t AgentsClientSettingsFallbackCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## A loop in the code under test must end the check rather than hang it: nothing here legitimately runs long.
( sleep 900 ; kill -TERM $$ 2> /dev/null ) > /dev/null 2>&1 &
rigDog=$!
trap 'rigDogSleep="$( pgrep -P "$rigDog" 2> /dev/null )" ; kill "$rigDog" 2> /dev/null ; [ -z "$rigDogSleep" ] || kill $rigDogSleep 2> /dev/null ; wait "$rigDog" 2> /dev/null ; chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWork="$rigTmp/work" ; rigHome="$rigTmp/home"
rigIndexFile="$rigHome/.agents/magic-team/members.registry"
rigListFile="$rigHome/.agents/magic-team/known-workspaces.registry"
mkdir -p "$rigTmp/bin"
for rigFake in curl python3 ; do
	cp "$rigTest/check-fixtures/client-systems-check.$rigFake.test.sh" "$rigTmp/bin/$rigFake" \
		|| rigRefuse "the fake $rigFake fixture is missing from the package: $rigTest/check-fixtures/client-systems-check.$rigFake.test.sh"
	chmod +x "$rigTmp/bin/$rigFake"
done
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] && [ "$( command -v python3 )" = "$rigTmp/bin/python3" ] \
	|| rigRefuse "the fake curl and python3 are not first on PATH, so this check would issue real requests"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

rigMemberFiles(){ ## directory, member, where -- a member directory with the files a help or an operation reads
	mkdir -p "$1"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$1/$2.basic.md"
	printf '# rig armed\n' > "$1/$2.armed.md"
	printf -- '---\nname: %s\n---\n\n# %s, set up in %s\n' "$2" "$2" "$3" > "$1/SKILL.md"
}
rigView(){ ## workspace -- its member set view, which holds its own members only
	printf '%s\n' "$rigWork/$1/.local/agents/members"
}
rigMemberAt(){ ## workspace, member -- that member set up in that workspace, linked into its view, and on the machine's index
	local atHome="$rigWork/$1/source/myx/pkg/skillset/$2"
	rigMemberFiles "$atHome" "$2" "$1"
	mkdir -p "$( rigView "$1" )"
	ln -sfn "$atHome" "$( rigView "$1" )/$2"
	printf '%s\t%s\tsource-symlink\tmyx/pkg/skillset/%s\t%s\n' "$2" "$rigWork/$1" "$2" "$atHome" >> "$rigIndexFile"
}
rigSettings(){ ## whose, system... -- the settings of those systems, each value named after whose it is
	local setWhose="$1" setLow setSystem ; shift
	setLow="$( printf '%s' "$setWhose" | LC_ALL=C tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz' )"
	for setSystem in "$@" ; do
		case "$setSystem" in
			SLACK) printf '%s\n' "SLACK_USER_TOKEN=rig-user-token-$setWhose" "SLACK_WORKSPACE_DOMAIN=$setLow.slack.invalid" 'SLACK_CONVERSATIONS=CNDM00001' ;;
			SLACKTEAM) printf '%s\n' "SLACK_BOT_TOKEN=rig-bot-token-$setWhose" "SLACK_WORKSPACE_DOMAIN=$setLow.slack.invalid" 'SLACK_CHANNEL_MAGIC_TEAM=CTEAM0001' 'SLACK_CHANNEL_HUMAN_OWNER=UTEAMOWNER' 'SLACK_CHANNEL_EVENT_TRACK=CTEAMTRCK' 'SLACK_CHANNEL_EVENT_ALERT=CTEAMALRT' ;;
			EMAIL) printf '%s\n' "EMAIL_IMAP_HOST=imap-$setLow.invalid" "EMAIL_SMTP_HOST=smtp-$setLow.invalid" 'EMAIL_SMTP_PORT=587' "EMAIL_USER=us@$setLow.invalid" "EMAIL_APP_PASSWORD=rig-mail-secret-$setWhose" ;;
			TRELLO) printf '%s\n' "TRELLO_KEY=rig-trello-key-$setWhose" "TRELLO_TOKEN=rig-trello-secret-$setWhose" ;;
			GOOGLE) printf '%s\n' "GOOGLE_CLIENT_ID=rig-google-client-$setWhose" "GOOGLE_CLIENT_SECRET=rig-google-secret-$setWhose" "GOOGLE_REFRESH_TOKEN=rig-google-refresh-$setWhose" ;;
			JIRA) printf '%s\n' "JIRA_SITE=jira-$setLow.invalid" "JIRA_USER=us@$setLow.invalid" "JIRA_API_TOKEN=rig-jira-secret-$setWhose" ;;
			CONFLUENCE) printf '%s\n' "CONFLUENCE_SITE=confluence-$setLow.invalid" "CONFLUENCE_USER=us@$setLow.invalid" "CONFLUENCE_API_TOKEN=rig-confluence-secret-$setWhose" ;;
		esac
	done
}
rigScopeOf(){ ## workspace, member -- that member's scope file in that workspace, its lines on stdin
	mkdir -p "$rigWork/$1/.local/.agents"
	cat > "$rigWork/$1/.local/.agents/$2.agent.env"
}
rigWorld(){ ## -- a fresh machine: this workspace holds nothing for the client
	rm -rf "$rigWork" "$rigHome"
	mkdir -p "${rigIndexFile%/*}" ; : > "$rigIndexFile"
	local wsName memberName
	for wsName in ws-here ws-there ; do mkdir -p "$rigWork/$wsName/.local/.agents" "$rigWork/$wsName/.local/agents/members" ; done
	for memberName in magic-team human-owner magic-coordinator keeper-here ; do rigMemberAt ws-here "$memberName" ; done
	for memberName in magic-team client-ndm keeper-there ; do rigMemberAt ws-there "$memberName" ; done
	printf '%s\n' "$rigWork/ws-here" "$rigWork/ws-there" > "$rigListFile"
	rigSettings TEAMHERE SLACKTEAM EMAIL TRELLO GOOGLE JIRA CONFLUENCE | rigScopeOf ws-here magic-team
	rigSettings TEAMTHERE SLACKTEAM EMAIL TRELLO GOOGLE JIRA CONFLUENCE | rigScopeOf ws-there magic-team
	rigSettings NDMTHERE SLACK EMAIL TRELLO GOOGLE JIRA CONFLUENCE | rigScopeOf ws-there client-ndm
	## a member that is no client, set up in the other workspace too: the fallback is any invited member's
	rigSettings KTHERE SLACK | rigScopeOf ws-there keeper-there
	rm -f "$rigWork/ws-here/.local/.agents/client-ndm.agent.env" "$rigWork/ws-here/.local/.agents/keeper-there.agent.env"
	rigClean
}
rigClean(){ ## -- the logs of the calls made so far, emptied
	: > "$rigTmp/calls" ; : > "$rigTmp/envs"
}
rigPre=()
rigRun(){ ## args... -- one dispatcher call from ws-here; stdout in out, stderr in err, rc in rigRc
	rigClean
	rigRc=0
	( cd "$rigWork/ws-here" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/ws-here" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_REAL_PYTHON3="$rigRealPython" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigRunWith(){ ## the text for stdin, args... -- as rigRun, with that text on the call's stdin
	local withText="$1" ; shift
	rigClean
	rigRc=0
	( cd "$rigWork/ws-here" && printf '%s' "$withText" | env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/ws-here" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_REAL_PYTHON3="$rigRealPython" \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" || rigRc=$?
}
rigN(){ ## file, fixed text -- how many lines hold it
	LC_ALL=C grep -c -F -- "$2" "$1" 2> /dev/null || :
}
rigLines(){ ## file -- how many lines it has
	LC_ALL=C awk 'END { print NR + 0 }' "$1" 2> /dev/null
}
rigCalls(){ ## -- the calls of the last run, in their order, joined by "; "
	LC_ALL=C awk '{ printf "%s%s", ( NR > 1 ? "; " : "" ), $0 }' "$rigTmp/calls"
}
rigFrom(){ ## whose -- how many calls of the last run carried a setting of that owner
	LC_ALL=C grep -c -i -F -- "$1" "$rigTmp/calls" || :
}

rigTreeSum(){ ## workspace -- one checksum over every file under its .local
	( cd "$rigWork/$1" && find .local -type f | LC_ALL=C sort | while IFS= read -r sumFile ; do cksum "$sumFile" ; done | cksum )
}
rigHeldHere(){ ## -- how many settings of the six systems this workspace's scope of the client holds
	local heldFile="$rigWork/ws-here/.local/.agents/client-ndm.agent.env"
	[ -f "$heldFile" ] || { echo 0 ; return 0 ; }
	LC_ALL=C grep -c -E '^(SLACK|EMAIL|JIRA|CONFLUENCE|TRELLO|GOOGLE)_' "$heldFile" || :
}
rigSaid(){ ## -- how many lines of the last run say a member's own settings are read from another workspace
	rigN "$rigTmp/err" "holds no settings of its own in"
}
rigSaidFor(){ ## operation, the systems named -- how many lines of the last run are the one line of the fallback, whole, for a client: the systems, both workspaces, and the side that reads them
	rigN "$rigTmp/err" "# DistroAgentsTools $1: member 'client-ndm' holds no settings of its own in $rigWork/ws-here for $2 -- each is read from $rigWork/ws-there, the workspace it is set up in, and only where the operation reaches the other organisation"
}
rigEnded(){ ## -- how many lines of the last run say a system is read here alone from now on
	rigN "$rigTmp/err" "settings are read here alone from now on"
}
rigEndedFor(){ ## member, the key written, its system's prefix, the names no longer read -- how many lines of the last run are the one line of a write that ends a borrowing, whole
	rigN "$rigTmp/err" "# DistroAgentsTools --agents-config-option: member '$1' now holds $2 in $rigWork/ws-here, so its $3* settings are read here alone from now on -- no longer read from $rigWork/ws-there, the workspace it is set up in: $4"
}
rigBegun(){ ## -- how many lines of the last run say a system is read from the other workspace from now on
	rigN "$rigTmp/err" "settings are read from $rigWork/ws-there, the workspace it is set up in, from now on"
}
rigBegunFor(){ ## member, the key deleted, its system's prefix, the side said for a client (may be empty), the names read from now on -- how many lines of the last run are the one line of a delete that begins a borrowing, whole
	rigN "$rigTmp/err" "# DistroAgentsTools --agents-config-option: member '$1' holds no $3* setting in $rigWork/ws-here now that $2 is deleted, so its $3* settings are read from $rigWork/ws-there, the workspace it is set up in, from now on$4: $5"
}
rigKeyHere(){ ## member, key -- how many lines of that member's scope in this workspace set that key
	LC_ALL=C grep -c -e "^$2=" "$rigWork/ws-here/.local/.agents/$1.agent.env" 2> /dev/null || :
}
rigTeams(){ ## -- how many calls of the last run carried a setting of either workspace's own team
	LC_ALL=C grep -c -i -E 'TEAMHERE|TEAMTHERE' "$rigTmp/calls" || :
}
## One --client-* operation of each system, and the call it makes for an owner of the settings: <operation and arguments>|<the calls, with WHOSE and whose where the owner's name stands>
rigOps=(
	'--client-comms-slack-read client-ndm CNDM00001|slack conversations.history rig-user-token-WHOSE'
	'--client-comms-email-check client-ndm|imap imap-whose.invalid us@whose.invalid STATUS INBOX (UNSEEN); imap imap-whose.invalid us@whose.invalid UID SEARCH UNSEEN'
	'--client-comms-jira-board-list client-ndm|http jira-whose.invalid us@whose.invalid'
	'--client-comms-confluence-space-list client-ndm|http confluence-whose.invalid us@whose.invalid'
	'--client-comms-trello-whoami client-ndm|trello members/me rig-trello-key-WHOSE'
	'--client-comms-google-whoami client-ndm|google whoami rig-google-client-WHOSE'
)
rigAll='SLACK_*, EMAIL_*, JIRA_*, CONFLUENCE_*, TRELLO_*, GOOGLE_*'
rigWant(){ ## an entry of rigOps, the owner in capitals -- the calls that entry makes with that owner's settings
	local wantText="${1#*|}" wantLow
	wantLow="$( printf '%s' "$2" | LC_ALL=C tr 'ABCDEFGHIJKLMNOPQRSTUVWXYZ' 'abcdefghijklmnopqrstuvwxyz' )"
	wantText="${wantText//WHOSE/$2}"
	printf '%s' "${wantText//whose/$wantLow}"
}

rigWorld
rigRun --agents-config-option client-ndm --select TRELLO_KEY
[ "$rigRc" = 0 ] && [ "$( cat "$rigTmp/out" )" = "rig-trello-key-NDMTHERE" ] || rigRefuse "the baseline read of a setting this workspace holds none of did not answer from the workspace the client is set up in, so no row below would be measured: rc=$rigRc [$( cat "$rigTmp/out" )] $( LC_ALL=C grep -m1 -E 'ERROR|WARNING' "$rigTmp/err" )"
[ -d "$( rigView ws-there )/client-ndm" ] && [ ! -e "$( rigView ws-here )/client-ndm" ] && [ "$( rigHeldHere )" = 0 ] || rigRefuse "the fixture does not hold client-ndm, and its settings, in the other workspace only, so no row below would show a borrowed setting"

echo "-- 1. this workspace holds none of a system for the client: its --client-* operation reads that system from the workspace the client is set up in --"
rigSumThere="$( rigTreeSum ws-there )"
for rigOp in "${rigOps[@]}" ; do
	rigRun ${rigOp%%|*}
	rigAssert "${rigOp%% *} reaches the other organisation with the settings the client holds where it is set up" "$rigRc $( rigCalls )" "0 $( rigWant "$rigOp" NDMTHERE )"
	rigAssert "and says so in the one line, once: each system by its key prefix, both workspaces, and the side that reads them" "$( rigSaid ) $( rigSaidFor "${rigOp%% *}" "$rigAll" )" "1 1"
	rigAssert "no call carried a setting of either workspace's own team" "$( rigTeams )" 0
done
rigRun --client-comms-trello-whoami client-ndm
rigAssert "the call itself is made from the workspace everything is run from: only the settings are read from the other" "$( LC_ALL=C awk '{ print $2 ; exit }' "$rigTmp/envs" )" "MMDAPP=$rigWork/ws-here"
rigAssert "the workspace the client is set up in is only read: nothing is written under its .local" "$( rigTreeSum ws-there )" "$rigSumThere"
rigAssert "and nothing of those systems is written into this workspace's scope of the client" "$( rigHeldHere )" 0

echo "-- 2. this workspace holds the system: it is read here, and nothing is borrowed --"
rigSettings NDMHERE SLACK EMAIL TRELLO GOOGLE JIRA CONFLUENCE | rigScopeOf ws-here client-ndm
for rigOp in "${rigOps[@]}" ; do
	rigRun ${rigOp%%|*}
	rigAssert "${rigOp%% *} with the system held here uses what this workspace holds, and nothing is said of another" "$rigRc $( rigCalls ) $( rigSaid ) $( rigFrom NDMTHERE )" "0 $( rigWant "$rigOp" NDMHERE ) 0 0"
done
rigSettings NDMHERE SLACK EMAIL | rigScopeOf ws-here client-ndm
rigRun --client-comms-email-check client-ndm
rigAssert "system by system: mail held here is read here, and the line names only the systems this workspace holds none of" "$rigRc $( rigFrom NDMHERE ) $( rigFrom NDMTHERE ) $( rigSaidFor --client-comms-email-check 'JIRA_*, CONFLUENCE_*, TRELLO_*, GOOGLE_*' )" "0 2 0 1"
rigRun --client-comms-trello-whoami client-ndm
rigAssert "while Trello, of which this workspace holds none, is still read from the workspace the client is set up in" "$rigRc $( rigCalls )" "0 trello members/me rig-trello-key-NDMTHERE"

echo "-- 3. one setting of a system held here, and that system is read here alone: no credential is put together from two workspaces --"
printf '%s\n' 'SLACK_WORKSPACE_DOMAIN=ndmhere.slack.invalid' 'EMAIL_USER=us@ndmhere.invalid' 'JIRA_SITE=jira-ndmhere.invalid' 'CONFLUENCE_SITE=confluence-ndmhere.invalid' 'TRELLO_KEY=rig-trello-key-NDMHERE' 'GOOGLE_CLIENT_ID=rig-google-client-NDMHERE' | rigScopeOf ws-here client-ndm
for rigOp in "${rigOps[@]}" ; do
	rigRun ${rigOp%%|*}
	rigAssert "${rigOp%% *} with one setting of its system held here makes no call: the rest is not taken from the other workspace, nor from a team" "$( [ "$rigRc" != 0 ] && printf refused || printf ran ) $( rigLines "$rigTmp/calls" ) $( rigSaid )" "refused 0 0"
done
rigRun --client-comms-email-check client-ndm
rigAssert "mail says which settings this scope lacks, as for any member" "$rigRc $( rigN "$rigTmp/err" "EMAIL_IMAP_HOST/EMAIL_USER/EMAIL_APP_PASSWORD not fully set in client-ndm's own scope" )" "1 1"
rigRun --client-comms-jira-board-list client-ndm
rigAssert "and Jira names the two it lacks here, though the other workspace holds them" "$rigRc $( rigN "$rigTmp/err" 'JIRA_USER/JIRA_API_TOKEN missing' )" "6 1"

echo "-- 4. the team's own settings are never borrowed, and never stand in for the client's --"
rigWorld
rigSettings NDMTHERE TRELLO GOOGLE JIRA CONFLUENCE | rigScopeOf ws-there client-ndm
rigRun --client-comms-slack-read client-ndm CNDM00001
rigAssert "a client that holds no Slack settings in either workspace reads nothing: neither team's bot stands in on the side of the other organisation" "$( [ "$rigRc" != 0 ] && printf refused || printf ran ) $( rigLines "$rigTmp/calls" ) $( rigN "$rigTmp/err" "where only the settings client-ndm itself holds are read, never the team's" )" "refused 0 1"
rigRun --client-comms-email-check client-ndm
rigAssert "nor a mailbox: neither team's is read in place of the one the client lacks" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigN "$rigTmp/err" "not fully set in client-ndm's own scope" )" "1 0 1"
rigWorld
rigSettings TEAMHERE SLACKTEAM EMAIL TRELLO GOOGLE JIRA CONFLUENCE | LC_ALL=C grep -v '^SLACK_BOT_TOKEN=' | rigScopeOf ws-here magic-team
rigRun --member-comms-slack-read client-ndm magic-team
rigAssert "our own side without our team's bot here is refused: the other workspace's team is not borrowed, and the client's own token is not used for our side" "$( [ "$rigRc" != 0 ] && printf refused || printf ran ) $( rigLines "$rigTmp/calls" )" "refused 0"
rigRun --member-comms-slack-read keeper-here magic-team
rigAssert "control: the same for a member of our own team" "$( [ "$rigRc" != 0 ] && printf refused || printf ran ) $( rigLines "$rigTmp/calls" )" "refused 0"
rigRun --agents-config-option magic-team --select SLACK_BOT_TOKEN
rigAssert "control: the team's scope here answers none for it, and nothing is said of another workspace" "$rigRc [$( cat "$rigTmp/out" )] $( rigSaid )" "0 [] 0"

echo "-- 5. a --member-* operation of the client is our own side: nothing of the client's is borrowed for it --"
rigWorld
for rigOp in '--member-comms-email-check client-ndm|mail|1' '--member-comms-trello-whoami client-ndm|Trello|1' '--member-comms-google-whoami client-ndm|Google|1' '--member-comms-jira-board-list client-ndm|Jira|6' '--member-comms-confluence-space-list client-ndm|Confluence|6' ; do
	rigName="${rigOp%% *}" ; rigWord="${rigOp#*|}" ; rigWord="${rigWord%|*}"
	rigRun ${rigOp%%|*}
	rigAssert "$rigName makes no call and says the client holds no $rigWord settings on our side, though the workspace it is set up in holds them" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigN "$rigTmp/err" "$rigName: client-ndm has no $rigWord settings on our own organisation's side: what it holds is the other organisation's. For the other organisation use --client-${rigName#--member-}." )" "${rigOp##*|} 0 1"
	rigAssert "and the line of the fallback, said before the side is known, does not say they are read for it: only where the operation reaches the other organisation" "$( rigSaid ) $( rigSaidFor "$rigName" "$rigAll" )" "1 1"
done
rigRun --member-comms-slack-read client-ndm magic-team
rigAssert "its Slack read of our team's conversation is our team's bot, held here: the token the client holds where it is set up is not used" "$rigRc $( rigCalls )" "0 slack conversations.history rig-bot-token-TEAMHERE"
rigRun --member-comms-slack-read client-ndm client:CNDM00001
rigAssert "control: the same operation with a client: address reaches the other organisation, and there the borrowed token is the one read" "$rigRc $( rigCalls )" "0 slack conversations.history rig-user-token-NDMTHERE"
rigRun --member-comms-email-check keeper-here
rigAssert "control: a member of our own team that holds no mailbox is told its scope is not set: nothing is borrowed and nothing said for a member set up here" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigN "$rigTmp/err" "not fully set in keeper-here's own scope" ) $( rigSaid )" "1 0 1 0"
rigAssert "across this whole section nothing of those systems was written into this workspace's scope of the client" "$( rigHeldHere )" 0

echo "-- 6. the client's own sweep, and the coordinator acting as the client, read the borrowed systems whole and leave this workspace's scope as it was --"
rigWorld
rigSumThere="$( rigTreeSum ws-there )"
for rigPass in first second ; do
	rigRun --client-sweep-input-scan client-ndm
	rigAssert "the $rigPass sweep reads Slack as the account of the borrowed token, the mailbox and the Trello account the client holds where it is set up" "$( rigN "$rigTmp/out" 'identity: slack URIGNDMTHERE (config: client-ndm)' ) $( rigN "$rigTmp/out" 'holds no Slack credentials of its own' ) $( rigN "$rigTmp/calls" 'imap-sweep imap-ndmthere.invalid us@ndmthere.invalid' ) $( rigN "$rigTmp/calls" 'trello members/me/notifications rig-trello-key-NDMTHERE' ) $( rigTeams )" "1 0 1 1 0"
	rigAssert "its check of the settings resolves the Slack workspace and says it is not persisted here, where the system is read from the other workspace" "$( rigN "$rigTmp/out" "SLACK_WORKSPACE_DOMAIN: OK (resolved rig.invalid, not persisted here: this scope's settings of that system are read from $rigWork/ws-there, the workspace client-ndm is set up in)" )" 1
	rigAssert "so nothing of those systems is written into this workspace's scope of the client, which one setting would cut off from the rest" "$( rigHeldHere )" 0
done
rigAssert "and the workspace the client is set up in is only read by both" "$( rigTreeSum ws-there )" "$rigSumThere"
rigRun --client-comms-slack-read client-ndm CNDM00001
rigAssert "after the sweeps the client's Slack is still read from the workspace it is set up in" "$rigRc $( rigCalls )" "0 slack conversations.history rig-user-token-NDMTHERE"
rigRun --magic-client-operation-run magic-coordinator --client-comms-email-mark-seen client-ndm 41
rigAssert "magic-coordinator's own operation, run as the client, marks a message in the mailbox the client holds where it is set up, and says once which settings are read from there" "$rigRc $( LC_ALL=C awk '{ print $1, $2, $3, $4, $5 }' "$rigTmp/calls" ) $( rigN "$rigTmp/err" "holds no settings of its own in" )" "0 imap imap-ndmthere.invalid us@ndmthere.invalid UID STORE 1"
rigSettings NDMHERE SLACK EMAIL TRELLO | rigScopeOf ws-here client-ndm
rigRun --client-sweep-input-scan client-ndm
rigAssert "control: where this workspace holds the client's Slack settings, the sweep reads them and persists the workspace it resolved here, as before" "$( rigN "$rigTmp/out" 'identity: slack URIGNDMHERE (config: client-ndm)' ) $( rigN "$rigTmp/out" 'SLACK_WORKSPACE_DOMAIN: OK (resolved rig.invalid)' ) $( rigN "$rigWork/ws-here/.local/.agents/client-ndm.agent.env" 'SLACK_WORKSPACE_DOMAIN=rig.invalid' ) $( rigFrom NDMTHERE )" "1 1 1 0"

echo "-- 7. a setting a person writes here ends the borrowing of its system, and the tooling says so in one line, by names only --"
rigWorld
rigSumThere="$( rigTreeSum ws-there )"
rigRun --agents-config-option client-ndm --upsert SLACK_WORKSPACE_DOMAIN ndmhere.slack.invalid
rigAssert "the write is made as it always was: here, and nothing under the workspace the client is set up in" "$rigRc $( rigKeyHere client-ndm SLACK_WORKSPACE_DOMAIN ) $( [ "$( rigTreeSum ws-there )" = "$rigSumThere" ] && printf untouched || printf written )" "0 1 untouched"
rigAssert "and the tooling says in one line that Slack is read here alone from now on, and which settings of it, held in the other workspace, are no longer read" "$( rigEnded ) $( rigEndedFor client-ndm SLACK_WORKSPACE_DOMAIN SLACK_ 'SLACK_USER_TOKEN, SLACK_CONVERSATIONS' )" "1 1"
rigAssert "by their names only: no value of the other workspace's is in anything the write said" "$( cat "$rigTmp/err" "$rigTmp/out" | LC_ALL=C grep -c -e 'rig-user-token-NDMTHERE' -e 'CNDM00001' -e 'ndmthere' || : )" 0
rigRun --client-comms-slack-read client-ndm CNDM00001
rigAssert "what the line says holds: the client's Slack read from here finds no token now, and the other workspace's is not used" "$( [ "$rigRc" != 0 ] && printf refused || printf ran ) $( rigLines "$rigTmp/calls" )" "refused 0"
rigRun --agents-config-option client-ndm --upsert SLACK_CONVERSATIONS CHERE0009
rigAssert "a further setting of a system already held here says nothing: nothing changes hands" "$rigRc $( rigKeyHere client-ndm SLACK_CONVERSATIONS ) $( rigEnded )" "0 1 0"
rigRunWith 'rig-mail-secret-NDMHERE' --agents-config-option client-ndm --upsert-from-stdin EMAIL_APP_PASSWORD
rigAssert "a setting written from stdin is the same: mail is read here alone from now on, the other workspace's mail settings named, and neither value shown" "$rigRc $( rigKeyHere client-ndm EMAIL_APP_PASSWORD ) $( rigEndedFor client-ndm EMAIL_APP_PASSWORD EMAIL_ 'EMAIL_IMAP_HOST, EMAIL_SMTP_HOST, EMAIL_SMTP_PORT, EMAIL_USER' ) $( cat "$rigTmp/err" "$rigTmp/out" | LC_ALL=C grep -c -e 'rig-mail-secret' -e 'ndmthere' || : )" "0 1 1 0"
rigRun --agents-config-option client-ndm --upsert-if TRELLO_KEY rig-trello-key-NDMHERE rig-not-the-value-held
rigAssert "a conditional write that writes nothing ends no borrowing and says nothing" "$rigRc $( rigKeyHere client-ndm TRELLO_KEY ) $( rigEnded )" "0 0 0"
rigRun --agents-config-option client-ndm --select TRELLO_KEY
rigAssert "so Trello is still read from the workspace the client is set up in" "$rigRc [$( cat "$rigTmp/out" )]" "0 [rig-trello-key-NDMTHERE]"
rigRun --agents-config-option client-ndm --upsert RIG_NOTE kept-here
rigAssert "a key that is no system's is written here and says nothing: it was never read from there" "$rigRc $( rigKeyHere client-ndm RIG_NOTE ) $( rigEnded )" "0 1 0"
printf '%s\n' 'GOOGLE_CLIENT_ID=rig-google-client-NDMTHERE' >> "$rigWork/ws-there/.local/.agents/client-ndm.agent.env.new" ; LC_ALL=C grep -v '^GOOGLE_' "$rigWork/ws-there/.local/.agents/client-ndm.agent.env" >> "$rigWork/ws-there/.local/.agents/client-ndm.agent.env.new" ; mv -f "$rigWork/ws-there/.local/.agents/client-ndm.agent.env.new" "$rigWork/ws-there/.local/.agents/client-ndm.agent.env"
rigRun --agents-config-option client-ndm --upsert GOOGLE_CLIENT_ID rig-google-client-NDMHERE
rigAssert "where the other workspace holds no other setting of that system, the write replaces all there was to read, and nothing is said" "$rigRc $( rigKeyHere client-ndm GOOGLE_CLIENT_ID ) $( rigEnded )" "0 1 0"
rigRun --agents-config-option keeper-there --upsert SLACK_WORKSPACE_DOMAIN khere.slack.invalid
rigAssert "it is any invited member's line, not a client's alone" "$rigRc $( rigEnded ) $( rigEndedFor keeper-there SLACK_WORKSPACE_DOMAIN SLACK_ 'SLACK_USER_TOKEN, SLACK_CONVERSATIONS' )" "0 1 1"
rigRun --agents-config-option keeper-here --upsert SLACK_USER_TOKEN rig-user-token-KHERE
rigAssert "control: a member set up here borrows nothing, so its first setting of a system says nothing" "$rigRc $( rigKeyHere keeper-here SLACK_USER_TOKEN ) $( rigEnded )" "0 1 0"
rigRun --agents-config-option magic-team --upsert JIRA_SITE jira-teamhere-new.invalid
rigAssert "control: nor does a write to the team's own scope" "$rigRc $( rigEnded )" "0 0"

echo "-- 8. deleting the last setting of a system held here begins its borrowing again, and the mirror of that line says so, by names only --"
rigWorld
rigSettings NDMHERE SLACK | rigScopeOf ws-here client-ndm
rigSumThere="$( rigTreeSum ws-there )"
rigSlackNames='SLACK_USER_TOKEN, SLACK_WORKSPACE_DOMAIN, SLACK_CONVERSATIONS'
rigRun --agents-config-option client-ndm --delete SLACK_CONVERSATIONS
rigAssert "a setting deleted while others of its system stay here says nothing: the system is still this workspace's" "$rigRc $( rigKeyHere client-ndm SLACK_CONVERSATIONS ) $( rigBegun )" "0 0 0"
rigRun --agents-config-option client-ndm --delete-if SLACK_WORKSPACE_DOMAIN rig-not-the-value-held
rigAssert "a conditional delete that deletes nothing says nothing" "$rigRc $( rigKeyHere client-ndm SLACK_WORKSPACE_DOMAIN ) $( rigBegun )" "0 1 0"
rigRun --agents-config-option client-ndm --delete SLACK_WORKSPACE_DOMAIN
rigAssert "nor the next to last" "$rigRc $( rigHeldHere ) $( rigBegun )" "0 1 0"
rigRun --agents-config-option client-ndm --delete-if SLACK_USER_TOKEN rig-user-token-NDMHERE
rigAssert "the delete of the last one is made as it always was: here, and nothing under the workspace the client is set up in" "$rigRc $( rigHeldHere ) $( [ "$( rigTreeSum ws-there )" = "$rigSumThere" ] && printf untouched || printf written )" "0 0 untouched"
rigAssert "and the tooling says in one line that Slack is read from the other workspace from now on, on which side for a client, and which settings those are" "$( rigBegun ) $( rigBegunFor client-ndm SLACK_USER_TOKEN SLACK_ ', and only where the operation reaches the other organisation' "$rigSlackNames" )" "1 1"
rigAssert "by their names only: no value of either workspace's is in anything the delete said" "$( cat "$rigTmp/err" "$rigTmp/out" | LC_ALL=C grep -c -i -e 'rig-user-token' -e 'CNDM00001' -e 'slack.invalid' || : )" 0
rigRun --client-comms-slack-read client-ndm CNDM00001
rigAssert "what the line says holds: the client's Slack read from here uses the token held where it is set up again" "$rigRc $( rigCalls )" "0 slack conversations.history rig-user-token-NDMTHERE"
printf '%s\n' 'SLACK_WORKSPACE_DOMAIN=khere.slack.invalid' | rigScopeOf ws-here keeper-there
rigRun --agents-config-option keeper-there --delete SLACK_WORKSPACE_DOMAIN
rigAssert "it is any invited member's line: one that is no client gets it with no side in it" "$rigRc $( rigBegun ) $( rigBegunFor keeper-there SLACK_WORKSPACE_DOMAIN SLACK_ '' "$rigSlackNames" )" "0 1 1"
printf '%s\n' 'GOOGLE_CLIENT_ID=rig-google-client-NDMHERE' 'RIG_NOTE=kept-here' | rigScopeOf ws-here client-ndm
LC_ALL=C grep -v '^GOOGLE_' "$rigWork/ws-there/.local/.agents/client-ndm.agent.env" > "$rigWork/ws-there/.local/.agents/client-ndm.agent.env.new" ; mv -f "$rigWork/ws-there/.local/.agents/client-ndm.agent.env.new" "$rigWork/ws-there/.local/.agents/client-ndm.agent.env"
rigRun --agents-config-option client-ndm --delete GOOGLE_CLIENT_ID
rigAssert "where the other workspace holds nothing of that system, there is nothing to read from it, and nothing is said" "$rigRc $( rigKeyHere client-ndm GOOGLE_CLIENT_ID ) $( rigBegun )" "0 0 0"
rigRun --agents-config-option client-ndm --delete RIG_NOTE
rigAssert "a key that is no system's is deleted and says nothing" "$rigRc $( rigKeyHere client-ndm RIG_NOTE ) $( rigBegun )" "0 0 0"
printf '%s\n' 'SLACK_USER_TOKEN=rig-user-token-KHERE' | rigScopeOf ws-here keeper-here
rigRun --agents-config-option keeper-here --delete SLACK_USER_TOKEN
rigAssert "control: a member set up here has nowhere else to read from, so its last setting of a system deleted says nothing" "$rigRc $( rigKeyHere keeper-here SLACK_USER_TOKEN ) $( rigBegun )" "0 0 0"
printf '%s\n' 'JIRA_SITE=jira-teamhere.invalid' | rigScopeOf ws-here magic-team
rigRun --agents-config-option magic-team --delete JIRA_SITE
rigAssert "control: nor does a delete in the team's own scope, which is never read from another workspace" "$rigRc $( rigBegun )" "0 0"

echo "-- 9. static --"
rigAssert "the line of a delete is said where a setting is deleted, after the delete, which is the sibling package's own, unchanged" "$( LC_ALL=C awk '/--delete\|--delete-if\)/ { on = 1 } on && /LocalTools.Config.include/ && ! deleted { deleted = NR } on && /AgentsToolsMemberSettingsBorrowBegunSay "\$optionScope" "\$optionKey" "\$agentsConfigOptionElsewhere"/ && ! said { said = NR } END { print ( deleted && said && deleted < said ) ? "deleted-then-said" : "not" }' "$rigTool" )" deleted-then-said
rigAssert "the line of a write is said where a setting is written, after the write, and the write is the sibling package's own, unchanged" "$( LC_ALL=C awk '/--upsert\|--upsert-from-stdin\|--upsert-if\)/ { on = 1 } on && /LocalTools.Config.include/ && ! wrote { wrote = NR } on && /AgentsToolsMemberSettingsBorrowEndedSay "\$optionScope" "\$optionKey" "\$optionThere"/ && ! said { said = NR } END { print ( wrote && said && wrote < said ) ? "written-then-said" : "not" }' "$rigTool" )" written-then-said
rigAssert "the one place the tooling persists a setting it resolved asks first whether that scope's system is read from elsewhere" "$( LC_ALL=C awk '/AgentsToolsConfigOptionElsewhere "\$callingMember" "\$resolveWorkspaceKey"/ && ! asked { asked = NR } /--agents-config-option "\$callingMember" --upsert "\$resolveWorkspaceKey"/ && ! wrote { wrote = NR } END { print ( asked && wrote && asked < wrote ) ? "asked-first" : "not" }' "$rigHere/AgentsTools.InternOpCheckConfigs.include" )" asked-first
rigAssert "and it is the only place the tooling writes a setting of a scope by a name it was handed" "$( cat "$rigHere"/*.include | LC_ALL=C grep -v '^[[:space:]]*#' | LC_ALL=C grep -c -E -e 'DistroAgentsTools --agents-config-option "\$[A-Za-z]+" --upsert "\$' || : )" 1
if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ CLIENT SETTINGS FALLBACK CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'CLIENT_SETTINGS_FALLBACK: OK (%d assertions, offline)\n' "$rigPasses"
