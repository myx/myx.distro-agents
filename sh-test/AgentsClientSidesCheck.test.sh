#!/usr/bin/env bash
## Behavioural check on which organisation an operation of a client-* member reaches, run rather than read, against a
## fixture machine built here: one HOME with the machine-wide member directory and the tracked workspaces, and two
## workspaces under one rig tree. ws-here is the workspace everything is run from: it holds our own team's Slack
## settings and the settings client-ndm holds for the other organisation. ws-there is where client-ndm is set up, and
## holds a team and a client scope of its own that nothing here may read. The rule held: ONE TEAM, TWO ORGANISATIONS.
## A client-* member is invited like any other member, so its operation runs in the workspace it was called from. A
## --member-* operation of it, and a tool with no marker, reach our own team: the team's bot and conversations, never
## a token the client holds. A --client-* operation and a client:<addressee> address reach the other organisation: the
## client's own settings, held in the workspace it was called from, never the team's. The prefix and the address
## select the side, never a credential. An address that works on one side only is refused with a hint that names the
## side it works on: the team's own named conversations, the two session addresses, a team member's name and the
## session thread are our own organisation's, and a client: address is a client-* member's alone. The tools that ask reach addressees in both
## organisations, and what they record keeps the side, so the answer is read where the question was asked. Offline:
## a fake `curl` first on PATH logs each call with its token, and answers a thread only for the token the check
## planted it for. What the stubs cannot show: real Slack and Atlassian answers of either organisation, and a real
## agent session of a client.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigSlackInclude="$rigHere/comms/AgentsTools.CommsSlack.include"
rigSpawnInclude="$rigHere/session/AgentsTools.InternOpAgentSpawnProxy.include"
## The hint of a one-way address, in its three forms: in a --client- Slack operation it names that operation's --member-
## twin, under a client: marker it says the marker goes, and anywhere else it names the --member- family.
rigHint="this addressee alias is only usable in"
rigHintEnd="and connects to our own organisation"
rigHintMarked="$rigHint a --member-* operation, with no client: marker, $rigHintEnd"
rigHintPlain="$rigHint a --member-* operation $rigHintEnd"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigHarness" ] || rigRefuse "the harness is not at: $rigHarness"
[ -f "$rigSlackInclude" ] || rigRefuse "the Slack include is not at: $rigSlackInclude"
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
## A spawn of this rig that is not waited for starts the control thread of its session, a detached process that
## outlives this check: the rig ends it, before its tree is removed (the guard is in AgentsSessionControlStartCheck).
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsClientSidesCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## A loop in the code under test must end the check rather than hang it: nothing here legitimately runs long.
rigProcNote $$
( sleep 900 ; rigProcSignal TERM $$ ) > /dev/null 2>&1 &
rigDog=$! ; rigProcNote "$rigDog"
trap 'rigProcSignalWithChildren TERM "$rigDog" ; wait "$rigDog" 2> /dev/null ; chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWork="$rigTmp/work" ; rigHome="$rigTmp/home"
rigIndexFile="$rigHome/.agents/magic-team/members.registry"
rigListFile="$rigHome/.agents/magic-team/known-workspaces.registry"
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/client-sides-check.curl.stub.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigTest/check-fixtures/client-sides-check.curl.stub.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

## ---- the fixture machine ----
## Tokens say whose they are: rig-bot-token-HERE is our team's bot, rig-user-token-COORD the coordinator's own account
## in our Slack, rig-user-token-NDM what client-ndm holds for the other organisation, rig-bot-token-MELOWN the bot
## client-mel holds for its own. Everything ending THERE is the other workspace's, and must never be seen in a call.
rigMemberFiles(){ ## directory, member, where -- a member directory with the files a help, a send or a spawn reads
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
	[ "$2" != magic-team ] || printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator\ninvitees: magic-team\ndefault-for-session-kind: coworking\n---\n# rig coworking routine fixture\n' > "$atHome/magic-team.coworking.routine.md"
	mkdir -p "$( rigView "$1" )"
	ln -sfn "$atHome" "$( rigView "$1" )/$2"
	printf '%s\t%s\tsource-symlink\tmyx/pkg/skillset/%s\t%s\n' "$2" "$rigWork/$1" "$2" "$atHome" >> "$rigIndexFile"
}
rigScopeOf(){ ## workspace, member, lines... -- that member's scope file in that workspace
	local scopeWs="$1" scopeMember="$2" ; shift 2
	mkdir -p "$rigWork/$scopeWs/.local/.agents"
	printf '%s\n' "$@" > "$rigWork/$scopeWs/.local/.agents/$scopeMember.agent.env"
}
rigConsole(){ ## workspace, label -- a console that records where it was started and the member set root it was given
	printf '%s\n' '#!/usr/bin/env bash' \
		'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records where it was started.' \
		"printf '%s\\n' \"\$MMDAPP\" > \"\$RIG_SCENARIO/launched.$2\"" \
		"printf '%s=%s\\n' \"\${MDAT_SPAWN_AGENT:-none}\" \"\${MDAT_SKILLSET_ROOT:-unset}\" >> \"\$RIG_SCENARIO/roots.$2\"" \
		'cat > /dev/null' \
		'printf "📦 SubagentHandback\n"' \
		'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWork/$1/DistroAgentsConsole.sh"
	chmod +x "$rigWork/$1/DistroAgentsConsole.sh"
}
rigWorld(){ ## -- a fresh machine
	rm -rf "$rigWork" "$rigHome"
	mkdir -p "${rigIndexFile%/*}" ; : > "$rigIndexFile"
	local wsName memberName
	for wsName in ws-here ws-there ; do mkdir -p "$rigWork/$wsName/.local/.agents" "$rigWork/$wsName/.local/agents/members" ; done
	for memberName in magic-team human-owner magic-coordinator keeper-here client-mel ; do rigMemberAt ws-here "$memberName" ; done
	for memberName in magic-team client-ndm ; do rigMemberAt ws-there "$memberName" ; done
	printf '%s\n' "$rigWork/ws-here" "$rigWork/ws-there" > "$rigListFile"
	## our own team, in the workspace everything is run from
	rigScopeOf ws-here magic-team 'SLACK_CHANNEL_MAGIC_TEAM=CHERE0001' 'SLACK_CHANNEL_HUMAN_OWNER=UHEREOWNER' 'SLACK_CHANNEL_EVENT_TRACK=CHERETRCK' 'SLACK_CHANNEL_EVENT_ALERT=CHEREALRT' 'SLACK_BOT_TOKEN=rig-bot-token-HERE' 'SLACK_WORKSPACE_DOMAIN=here.slack.invalid'
	rigScopeOf ws-here magic-coordinator 'SLACK_USER_TOKEN=rig-user-token-COORD'
	rigScopeOf ws-here keeper-here 'SLACK_USER_TOKEN=rig-user-token-KHERE'
	## what each client holds for its other organisation, configured in the workspace everything is run from
	rigScopeOf ws-here client-ndm 'WHERE=ws-here' 'SLACK_USER_TOKEN=rig-user-token-NDM' 'SLACK_WORKSPACE_DOMAIN=ndm.slack.invalid' 'SLACK_CONVERSATIONS=CNDM00001' 'JIRA_SITE=jira-ndm.invalid' 'JIRA_USER=us@ndm.invalid' 'JIRA_API_TOKEN=rig-jira-token-NDM'
	rigScopeOf ws-here client-mel 'SLACK_BOT_TOKEN=rig-bot-token-MELOWN'
	## the other workspace's own team and its own settings for the client: never read from here
	rigScopeOf ws-there magic-team 'SLACK_CHANNEL_MAGIC_TEAM=CTHERE0001' 'SLACK_CHANNEL_HUMAN_OWNER=UTHEREOWNER' 'SLACK_BOT_TOKEN=rig-bot-token-THERE' 'SLACK_WORKSPACE_DOMAIN=there.slack.invalid'
	rigScopeOf ws-there client-ndm 'WHERE=ws-there' 'SLACK_USER_TOKEN=rig-user-token-NDMTHERE' 'JIRA_SITE=jira-there.invalid' 'JIRA_USER=us@there.invalid' 'JIRA_API_TOKEN=rig-jira-token-THERE'
	## this workspace's names registry holds its own members only: the persona member, the client set up here, the keeper.
	## The invited client has no row in it.
	printf '%s\n' 'magic-coordinator 🐭 Magic Vane dispatchr' 'client-mel 🐭 Magic Vane dispatchr' 'keeper-here 🔧 Hera Keeper herakeep' > "$rigWork/ws-here/.local/agents/team-members-names.registry"
	## each client's own contacts: a send into the other organisation passes the outbound contact gate
	## (AgentsToolsContactAssertKnown) only for a recipient that is a coordinate of a contact it holds
	. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-contacts.include.sh" || exit 1
	for memberName in client-ndm client-mel ; do
		rigContactSeed "$rigWork/ws-here/.local/agents/team-data-root" "$memberName" rig-ndm-team CNDM00001 -
		rigContactSeed "$rigWork/ws-here/.local/agents/team-data-root" "$memberName" rig-ndm-person UNDMPERSON -
		rigContactSeed "$rigWork/ws-here/.local/agents/team-data-root" "$memberName" rig-ndm-person-dm DNDMPERSON -
	done
	rigConsole ws-here HERE ; rigConsole ws-there THERE
	rigClean
}
rigClean(){ ## -- the logs of the calls made so far, emptied
	: > "$rigTmp/calls" ; : > "$rigTmp/envs" ; : > "$rigTmp/bodies" ; : > "$rigTmp/reactions" ; rm -f "$rigTmp/posts" "$rigTmp"/launched.* "$rigTmp"/roots.*
}

## ---- running ----
## No member set root is given to a call: each reads its own workspace's view, as a session started there does. rigPre
## adds to a call's environment, the member a spawned session acts as among them.
rigPre=()
rigRun(){ ## args... -- one dispatcher call from ws-here; stdout in out, stderr in err, rc in rigRc
	rigClean
	rigRc=0
	( cd "$rigWork/ws-here" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/ws-here" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigFn(){ ## function and arguments... -- one function of the Slack include on its own, in ws-here; stdout in fnOut, rc in fnRc
	fnRc=0
	fnOut="$( cd "$rigWork/ws-here" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/ws-here" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TOOL="$rigTool" RIG_INCLUDE="$rigSlackInclude" ${rigPre[@]+"${rigPre[@]}"} \
		bash -c '
			. "$RIG_TOOL"
			MDSC_CMD=rig
			rigArgs=( "$@" )
			set -- --rig-none ; . "$RIG_INCLUDE" > /dev/null 2>&1
			"${rigArgs[@]}"
		' rig "$@" 2> "$rigTmp/fnErr" < /dev/null )" || fnRc=$?
}
rigToolAs(){ ## agent, tool, json -- one harness tool call as that agent, in a session that runs in ws-here on the view of the workspace the agent is set up in; output in out
	local toolRoot="$( rigView ws-here )"
	[ "$1" != client-ndm ] || toolRoot="$( rigView ws-there )"
	rigClean
	rigRc=0
	( cd "$rigWork/ws-here" && printf '%s' "$3" | env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/ws-here" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$toolRoot" RIG_SCENARIO="$rigTmp" \
		MDAT_SPAWN_SESSION_ID=rig-session-client MDAT_SPAWN_AGENT="$1" MDAT_HARNESS_WAIT_TIMEOUT=1 ${rigPre[@]+"${rigPre[@]}"} bash "$rigHarness" --intern-tool "$2" ) > "$rigTmp/out" 2> "$rigTmp/err" || rigRc=$?
}
rigN(){ ## file, fixed text -- how many lines hold it
	LC_ALL=C grep -c -F -- "$2" "$1" 2> /dev/null || :
}
rigLines(){ ## file -- how many lines it has
	LC_ALL=C awk 'END { print NR + 0 }' "$1" 2> /dev/null
}
rigText(){ ## -- the text field of the first posted body, escapes as sent
	LC_ALL=C sed -n '1s/^{"channel":"[^"]*","text":"//; 1s/","blocks":.*//; 1s/"}$//; 1p' "$rigTmp/bodies"
}
rigChannel(){ ## -- the channel of the first posted body
	LC_ALL=C sed -n '1s/^{"channel":"\([^"]*\)".*/\1/p' "$rigTmp/bodies"
}
rigTokens(){ ## method... -- the distinct tokens those methods were called with, sorted, space separated; every method when none is named
	LC_ALL=C awk -v want=" $* " 'want == "  " || index( want, " " $1 " " ) { print $2 }' "$rigTmp/calls" | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' '
}
rigOurs(){ ## -- how many calls used a token of our own team: its bot, or the coordinator's own account
	LC_ALL=C grep -c -E ' rig-(bot-token-HERE|user-token-COORD|user-token-KHERE)$' "$rigTmp/calls" || :
}
rigTheirs(){ ## -- how many calls used a token a client holds for its other organisation
	LC_ALL=C grep -c -E ' rig-(user-token-NDM|bot-token-MELOWN)$' "$rigTmp/calls" || :
}
rigElsewhere(){ ## -- how many calls used anything of the other workspace
	LC_ALL=C grep -c 'THERE' "$rigTmp/calls" "$rigTmp/bodies" | LC_ALL=C awk -F: '{ n += $2 } END { print n + 0 }'
}
rigHinted(){ ## the --client- operation that was run, the address refused, its alias -- how many lines of the last call refuse that address in that operation, naming its --member- twin
	rigN "$rigTmp/err" "'$2' is refused in $1: for '${3:-$2}', $rigHint --member-${1#--client-} operation $rigHintEnd."
}
rigSent(){ ## name -- that SENT_MESSAGE_ field of the last send
	LC_ALL=C sed -n "s/^SENT_MESSAGE_$1=//p" "$rigTmp/err" "$rigTmp/out" 2> /dev/null | head -1
}
rigPendingId(){ ## -- the id of the one pending reply ws-here holds
	ls "$rigWork/ws-here/.local/agents/pending" 2> /dev/null | LC_ALL=C sed -n 's/\.md$//p' | head -1
}
rigPendingField(){ ## pending id, field
	LC_ALL=C sed -n "s/^$2: //p" "$rigWork/ws-here/.local/agents/pending/$1.md" 2> /dev/null | head -1
}
rigPendingDrop(){ ## -- every pending reply and wait state of ws-here, removed
	rm -rf "$rigWork/ws-here/.local/agents/pending" "$rigWork/ws-here/.local/agents/sessions" "$rigWork/ws-here/.local/agents/ask-counters"
}

rigWorld
rigRun --agents-config-option keeper-here --select SLACK_USER_TOKEN
[ "$rigRc" = 0 ] && [ "$( cat "$rigTmp/out" )" = "rig-user-token-KHERE" ] || rigRefuse "the baseline config select did not answer from the workspace everything is run from, so no row below would be measured: rc=$rigRc $( LC_ALL=C grep -m1 -E 'ERROR|WARNING' "$rigTmp/err" )"
rigRun --member-comms-slack-send-message keeper-here magic-team RIG-BODY
[ "$rigRc" = 0 ] && [ "$( rigTokens chat.postMessage )" = "rig-user-token-KHERE " ] || rigRefuse "the baseline send of a member set up here reached no post under its own token, so no row below would be measured: rc=$rigRc $( LC_ALL=C grep -m1 ERROR "$rigTmp/err" )"
[ -d "$( rigView ws-there )/client-ndm" ] && [ ! -e "$( rigView ws-here )/client-ndm" ] || rigRefuse "the fixture does not hold client-ndm in the other workspace's view only, so no row below would show an invited client"

echo "-- 1. a client-* member is invited like any other: its operation runs here, on the settings this workspace holds for it --"
rigRun --agents-config-option client-ndm --select WHERE
rigAssert "the settings read for a client set up in another workspace are those of the workspace it was called from" "$rigRc $( cat "$rigTmp/out" )" "0 ws-here"
rigRun --member-help client-ndm
rigAssert "its skillset is read from the view of the workspace it is set up in" "$rigRc $( rigN "$rigTmp/err" "($( rigView ws-there )/client-ndm/client-ndm.armed.md)" )" "0 1"
rigAssert "its help offers both families: the member operations and the client ones, the Slack ones among them" "$( [ "$( rigN "$rigTmp/out" 'DistroAgentsTools.fn.sh --member-comms-slack-send-message ' )" -gt 0 ] && printf member || printf none ) $( [ "$( rigN "$rigTmp/out" 'DistroAgentsTools.fn.sh --client-comms-slack-send-message ' )" -gt 0 ] && printf client || printf none ) $( [ "$( rigN "$rigTmp/out" 'DistroAgentsTools.fn.sh --client-comms-jira-board-list ' )" -gt 0 ] && printf jira || printf none )" "member client jira"
rigRun --member-help keeper-here
rigAssert "control: a member that is no client is offered no client operation" "$rigRc $( rigN "$rigTmp/out" 'DistroAgentsTools.fn.sh --client-comms-' ) $( [ "$( rigN "$rigTmp/out" 'DistroAgentsTools.fn.sh --member-comms-slack-send-message ' )" -gt 0 ] && printf member || printf none )" "0 0 member"
rigRun --client-comms-jira-board-list client-ndm
rigAssert "a --client-* Jira operation runs here: the site and the user this workspace's scope holds for the client" "$rigRc $( LC_ALL=C awk '$1 == "http" { print $2, $3 }' "$rigTmp/calls" ) $( LC_ALL=C awk '$1 == "http" { print $2 ; exit }' "$rigTmp/envs" )" "0 jira-ndm.invalid us@ndm.invalid MMDAPP=$rigWork/ws-here"

echo "-- 2. a --member-* operation of a client reaches our own team, whatever the client holds --"
rigRun --member-comms-slack-send-message client-ndm magic-team RIG-BODY
rigAssert "its send to magic-team is posted by our team's bot, into our team's conversation" "$rigRc $( rigTokens chat.postMessage )$( rigChannel )" "0 rig-bot-token-HERE CHERE0001"
rigAssert "under its member name, as an invited member with no row in a names registry: with the default icon of its prefix group, and the metadata that names the sender" "$( rigText ) $( rigN "$rigTmp/bodies" '"event_payload":{"sender":"client-ndm"}' )" '👥 *_client-ndm_* → @here.\nRIG-BODY 1'
rigAssert "no call used the token it holds for the other organisation, and none anything of the other workspace" "$( rigTheirs ) $( rigElsewhere )" "0 0"
rigAssert "what the send reports as its conversation carries no client: marker" "$( rigSent CHANNEL )" "CHERE0001"
rigRun --member-comms-slack-send-message client-ndm magic-team --identity-bot RIG-BODY
rigAssert "the same with --identity-bot: our team's bot" "$rigRc $( rigTokens chat.postMessage )" "0 rig-bot-token-HERE "
rigRun --member-comms-slack-send-message client-mel magic-team RIG-BODY
rigAssert "a client set up here, that holds a bot token of its own: still our team's bot, its own never used, with the mark of its row and its member name as its alias, never the alias of its persona" "$rigRc $( rigTokens chat.postMessage )$( rigTheirs ) $( rigText )" '0 rig-bot-token-HERE 0 🐭 *_client-mel_* → @here.\nRIG-BODY'
rigRun --member-comms-slack-read client-ndm magic-team
rigAssert "its read of magic-team is our team's bot reading our team's conversation" "$rigRc $( rigTokens conversations.history )$( rigTheirs )" "0 rig-bot-token-HERE 0"
rigRun --member-comms-slack-react client-ndm CHERE0001:1700000001.000101 eyes
rigAssert "its reaction in our conversation is our team's bot's" "$rigRc $( cat "$rigTmp/reactions" )" "0 rig-bot-token-HERE CHERE0001 1700000001.000101 eyes"
rigRun --member-comms-slack-send-message client-ndm human-owner RIG-BODY
rigAssert "to the human-owner it is our team's bot's post too, as for any member with no account in our Slack: nothing is relayed under another member's account" "$rigRc $( rigTokens chat.postMessage )$( rigChannel ) $( rigN "$rigTmp/err" "magic-coordinator's user account" ) $( rigTheirs )" "0 rig-bot-token-HERE UHEREOWNER 0 0"
rigRun --member-comms-slack-send-message keeper-here client-ndm RIG-BODY
rigAssert "addressed by name from inside our team, a client has no Slack account on our side: refused as a member with no DM, never sent to its account in the other organisation" "$rigRc $( rigN "$rigTmp/err" "NO-SLACK-DM: team member 'client-ndm' has no Slack DM channel of its own" ) $( rigLines "$rigTmp/bodies" ) $( rigTheirs )" "1 1 0 0"
rigRun --member-comms-slack-read client-ndm CNDM00001
rigAssert "a conversation of the other organisation named with no marker in a --member- operation is looked for in our own Slack, by our team's bot" "$( rigTokens conversations.history )$( rigTheirs )" "rig-bot-token-HERE 0"
rigRun --member-comms-slack-delete-message client-ndm CNDM00001:1700000001.000101
rigAssert "and where it is not found there, the error says the side the call was on, and how the other organisation is reached" "$( rigN "$rigTmp/err" "THIS CALL USED the Slack here.slack.invalid, by the settings of the workspace $rigWork/ws-here (the workspace this operation runs in) -- this call is on our own organisation's side, where client-ndm has no Slack settings of its own: what it holds is the other organisation's, read in a --client-* operation or for a client:<addressee> address" )" 1
rigRun --member-comms-slack-profile-get client-ndm
rigAssert "an operation that needs the member's own account finds none on our side, and says which side it is on" "$( [ "$rigRc" -ne 0 ] && printf refused || printf done ) $( rigN "$rigTmp/err" 'this call is on our own organisation'"'"'s side, where client-ndm has no Slack settings of its own' | LC_ALL=C awk '{ print ( $1 > 0 ) ? "said" : "silent" }' ) $( rigTheirs )" "refused said 0"

echo "-- 3. a --client-* operation reaches the other organisation, under what the client itself holds for it --"
rigRun --client-comms-slack-send-message client-ndm CNDM00001 RIG-BODY
rigAssert "its send is posted under the token the client holds, into the conversation named by its id" "$rigRc $( rigTokens chat.postMessage )$( rigChannel )" "0 rig-user-token-NDM CNDM00001"
rigAssert "under the persona member's row of this workspace, which is the invited client's row, with no client identifier and no metadata in the payload" "$( rigText ) $( rigN "$rigTmp/bodies" 'client-ndm' ) $( rigN "$rigTmp/bodies" '"metadata"' )" '🐭 *_Magic Vane_* @dispatchr → @here.\nRIG-BODY 0 0'
LC_ALL=C grep -v '^magic-coordinator ' "$rigWork/ws-here/.local/agents/team-members-names.registry" > "$rigTmp/names.kept" && mv "$rigTmp/names.kept" "$rigWork/ws-here/.local/agents/team-members-names.registry"
rigRun --client-comms-slack-send-message client-ndm CNDM00001 RIG-BODY
rigAssert "with no persona row in this workspace either, the send there is refused by name and nothing is posted: never under the client's identifier" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigN "$rigTmp/err" 'the external presentation needs the persona row in the team-members-names registry (--make-agents-indices): missing first-name, family-name, alias; nothing was sent' )" "1 0 1"
printf '%s\n' 'magic-coordinator 🐭 Magic Vane dispatchr' >> "$rigWork/ws-here/.local/agents/team-members-names.registry"
rigRun --client-comms-slack-send-message client-ndm CNDM00001 RIG-BODY
rigAssert "no call used a token of our own team, and none anything of the other workspace" "$( rigOurs ) $( rigElsewhere )" "0 0"
rigAssert "it ran in the workspace it was called from" "$( LC_ALL=C awk '$1 == "chat.postMessage" { print $2 ; exit }' "$rigTmp/envs" )" "MMDAPP=$rigWork/ws-here"
rigAssert "what the send reports as its conversation carries the client: marker, so what is given it next reaches the same side" "$( rigSent CHANNEL ) $( rigSent TS )" "client:CNDM00001 1700000001.000101"
rigRun --client-comms-slack-send-message client-ndm UNDMPERSON RIG-BODY
rigAssert "to a person of the other organisation, by id: the same token, and the person addressed" "$rigRc $( rigTokens chat.postMessage )$( rigText )" '0 rig-user-token-NDM 🐭 *_Magic Vane_* @dispatchr → <@UNDMPERSON>.\nRIG-BODY'
rigRun --client-comms-slack-send-message client-mel CNDM00001 --identity-bot RIG-BODY
rigAssert "a client that holds a bot token of its own posts under that one, never our team's bot" "$rigRc $( rigTokens chat.postMessage )$( rigOurs )" "0 rig-bot-token-MELOWN 0"
rigRun --client-comms-slack-send-message client-ndm CNDM00001 --identity-bot RIG-BODY
rigAssert "a client that holds no bot token of its own is refused the bot identity there: our team's bot does not stand in, and nothing is posted" "$rigRc $( rigLines "$rigTmp/bodies" ) $( rigOurs ) $( rigN "$rigTmp/err" 'this call is on the side of the other organisation, where only the settings client-ndm itself holds are read, never the team'"'"'s' | LC_ALL=C awk '{ print ( $1 > 0 ) ? "said" : "silent" }' )" "1 0 0 said"
rigRun --client-comms-slack-send-message client-ndm CNOTLISTD RIG-BODY
rigAssert "a recipient the client's contacts do not list is refused by the outbound contact gate, as before, and nothing is posted" "$rigRc $( rigLines "$rigTmp/bodies" )" "1 0"
rigRun --client-comms-slack-read client-ndm CNDM00001
rigAssert "its read of a conversation there is under the client's token" "$rigRc $( rigTokens conversations.history )$( rigOurs )" "0 rig-user-token-NDM 0"
rigRun --client-comms-slack-read client-ndm CNDM00001:1700000001.000101 --thread
rigAssert "and of a thread" "$rigRc $( rigTokens conversations.replies )$( rigOurs )" "0 rig-user-token-NDM 0"
rigRun --client-comms-slack-react client-ndm CNDM00001:1700000001.000101 eyes
rigAssert "its reaction there is the client's own" "$rigRc $( cat "$rigTmp/reactions" ) $( rigOurs )" "0 rig-user-token-NDM CNDM00001 1700000001.000101 eyes 0"
rigRun --client-comms-slack-profile-get client-ndm
rigAssert "the rest of the family is there too: the client's own profile is read under the client's token" "$( rigTokens )$( rigOurs )" "rig-user-token-NDM 0"
rigRun --client-comms-slack-read keeper-here CNDM00001
rigAssert "the family runs only as a client-* member: any other name is refused by name, and nothing is called" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigN "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --client-comms-slack-read: runs only as a client-* member, and keeper-here is not one" )" "1 0 1"
rigPre=( MDAT_SPAWN_AGENT=keeper-here )
rigRun --client-comms-slack-send-message client-ndm CNDM00001 RIG-BODY
rigAssert "a spawned session that acts as another member cannot post there in the client's name: a --client-* operation is the client's own session's alone" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigN "$rigTmp/err" "this session acts as keeper-here, and a --client-* operation in the name of client-ndm is for client-ndm's own session only -- nothing was done: ask the session's magic-coordinator, which can run it as client-ndm" )" "1 0 1"
rigRun --member-comms-slack-send-message client-ndm magic-team RIG-BODY
rigAssert "control: the member stub refuses that session too, in its own words" "$rigRc $( rigN "$rigTmp/err" 'this session acts as keeper-here, so it cannot act as client-ndm -- nothing was done' )" "1 1"
rigPre=( MDAT_SPAWN_AGENT=client-ndm )
rigRun --client-comms-slack-send-message client-ndm CNDM00001 RIG-BODY
rigAssert "accepted sibling: the client's own session posts there" "$rigRc $( rigTokens chat.postMessage )" "0 rig-user-token-NDM "
cp "$rigTmp/calls" "$rigTmp/calls.own" ; cp "$rigTmp/bodies" "$rigTmp/bodies.own"
rigPre=( MDAT_SPAWN_AGENT=magic-coordinator )
rigRun --magic-client-operation-run magic-coordinator --client-comms-slack-send-message client-ndm CNDM00001 RIG-BODY
rigAssert "magic-coordinator reaches the other organisation through its own operation, which runs the client's operation as that client: the client's token, its presentation there" "$rigRc $( rigTokens chat.postMessage )$( rigText ) $( rigOurs )" '0 rig-user-token-NDM 🐭 *_Magic Vane_* @dispatchr → @here.\nRIG-BODY 0'
rigAssert "every call it makes and every body it posts is what the client's own session made and posted: the same sender" "$( cmp -s "$rigTmp/calls" "$rigTmp/calls.own" && printf same-calls || printf other-calls ) $( cmp -s "$rigTmp/bodies" "$rigTmp/bodies.own" && printf same-bodies || printf other-bodies )" "same-calls same-bodies"
rigRun --client-comms-slack-send-message client-ndm CNDM00001 RIG-BODY
rigAssert "and not by the client's operation itself: its session is refused in one line that names its own operation, and nothing is posted" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigN "$rigTmp/err" "this session acts as magic-coordinator, and a --client-* operation in the name of client-ndm is for client-ndm's own session only -- nothing was done: magic-coordinator runs it with --magic-client-operation-run magic-coordinator --client-comms-slack-send-message client-ndm" )" "1 0 1"
rigRun --magic-comms-slack-read client-ndm CNDM00001
rigAssert "a --magic-comms-* operation given a client is our own side, as for any other member: the conversation is looked for in our own Slack, by our team's bot, and nothing the client holds is used" "$( rigTokens conversations.history )$( rigTheirs )" "rig-bot-token-HERE 0"
rigPre=( MDAT_COMMS_OP=--magic-comms-slack-read )
rigFn AgentsToolsSlackSideNote client-ndm
rigAssert "and where it is not found there, what the error says of the side names magic-coordinator's own way to the other organisation" "$fnOut" " -- this call is on our own organisation's side, where client-ndm has no Slack settings of its own: what it holds is the other organisation's, read in a --client-* operation, which magic-coordinator runs with --magic-client-operation-run, or for a client:<addressee> address"
rigPre=()
rigFn AgentsToolsSlackSideNote client-ndm
rigAssert "control: in every other operation it says the side as it did" "$fnOut" " -- this call is on our own organisation's side, where client-ndm has no Slack settings of its own: what it holds is the other organisation's, read in a --client-* operation or for a client:<addressee> address"
rigRun --magic-comms-slack-read keeper-here magic-team
rigAssert "control: the coordinator acting as a member that is no client stays in our own Slack" "$rigRc $( rigTokens conversations.history )" "0 rig-user-token-KHERE "
rigRun --intern-op-client-sweep-input-scan client-ndm
rigAssert "the client's own sweep reads its sources there under its own token, and never under our team's" "$( [ "$( rigN "$rigTmp/calls" ' rig-user-token-NDM' )" -gt 0 ] && printf read || printf unread ) $( rigOurs ) $( rigElsewhere )" "read 0 0"

echo "-- 4. a client: address reaches the other organisation from a --member-* operation --"
rigFn DistroAgentsToolsResolveTarget client:CNDM00001
rigAssert "the resolver keeps the marker on the conversation: an id" "$fnRc $( printf '%s' "$fnOut" | LC_ALL=C tr '\n' ' ' )" "0 CHANNEL=client:CNDM00001 THREAD_TS="
rigFn DistroAgentsToolsResolveTarget client:CNDM00001:1700000001.000101
rigAssert "an id with a ts" "$fnRc $( printf '%s' "$fnOut" | LC_ALL=C tr '\n' ' ' )" "0 CHANNEL=client:CNDM00001 THREAD_TS=1700000001.000101"
rigFn DistroAgentsToolsResolveTarget client:UNDMPERSON
rigAssert "a person's id" "$fnRc $( printf '%s' "$fnOut" | LC_ALL=C tr '\n' ' ' )" "0 CHANNEL=client:UNDMPERSON THREAD_TS="
rigFn DistroAgentsToolsResolveTarget client:magic-team
rigAssert "one of our team's own named conversations under the marker is refused: rc 3, and the one line printed is the hint" "$fnRc $( printf '%s\n' "$fnOut" | LC_ALL=C grep -c -F -- "'client:magic-team' is refused: for 'magic-team', $rigHintMarked." )" "3 1"
rigFn DistroAgentsToolsResolveTarget client:CNDM00001 keeper-here
rigAssert "the marker for a member that is no client is refused too: rc 3, and the line says that member has no other organisation" "$fnRc $( printf '%s\n' "$fnOut" | LC_ALL=C grep -c -F -- "'client:CNDM00001' is refused: a client: address connects to the other organisation of a client-* member, and keeper-here is not one" )" "3 1"
rigFn DistroAgentsToolsResolveTarget client:not-an-id
rigAssert "anything else under the marker is unrecognised: rc 2" "$fnRc [$fnOut]" "2 []"
rigFn DistroAgentsToolsResolveTarget client:client:CNDM00001
rigAssert "and so is the marker twice" "$fnRc [$fnOut]" "2 []"
rigFn DistroAgentsToolsResolveTarget magic-team:1700000001.000101
rigAssert "control: with no marker the named conversations, an id and a thread resolve as they always have" "$fnRc $( printf '%s' "$fnOut" | LC_ALL=C tr '\n' ' ' ) $( rigFn DistroAgentsToolsResolveTarget CHERE0001 ; printf '%s' "$fnOut" | LC_ALL=C tr '\n' ' ' ) $( rigFn DistroAgentsToolsResolveTarget human-owner ; printf '%s' "$fnOut" | LC_ALL=C tr '\n' ' ' )" "0 CHANNEL=CHERE0001 THREAD_TS=1700000001.000101 CHANNEL=CHERE0001 THREAD_TS= CHANNEL=UHEREOWNER THREAD_TS="
rigPre=( MDAT_COMMS_SIDE=client )
rigFn DistroAgentsToolsResolveTarget magic-team client-ndm
rigAssert "in a --client- operation, for the client it acts as, a named conversation of ours is refused the same way: rc 3, with the hint" "$fnRc $( printf '%s\n' "$fnOut" | LC_ALL=C grep -c -F -- "'magic-team' is refused: for 'magic-team', $rigHintPlain." )" "3 1"
rigFn DistroAgentsToolsResolveTarget magic-team
rigAssert "with no member named it resolves there as ever, so a post of the tooling's own from inside a --client- operation still finds our conversation" "$fnRc $( printf '%s' "$fnOut" | LC_ALL=C tr '\n' ' ' )" "0 CHANNEL=CHERE0001 THREAD_TS="
rigFn DistroAgentsToolsResolveTarget magic-team keeper-here
rigAssert "and for a member that is no client" "$fnRc $( printf '%s' "$fnOut" | LC_ALL=C tr '\n' ' ' )" "0 CHANNEL=CHERE0001 THREAD_TS="
rigFn AgentsToolsResolveSlackBotToken magic-team
rigAssert "nor does the team's own bot token go missing there for a post that is the team's" "$fnRc ${fnOut%% *}" "0 shared-bot-token"
rigPre=()
rigRun --member-comms-slack-send-message client-ndm client:CNDM00001 RIG-BODY
rigAssert "a --member- send to a client: address is posted under the client's token, into that conversation, as its presentation there" "$rigRc $( rigTokens chat.postMessage )$( rigChannel ) $( rigText ) $( rigOurs )" '0 rig-user-token-NDM CNDM00001 🐭 *_Magic Vane_* @dispatchr → @here.\nRIG-BODY 0'
rigRun --member-comms-slack-send-message client-ndm client:CNDM00001:1700000001.000101 RIG-BODY
rigAssert "into a thread there" "$rigRc $( rigTokens chat.postMessage )$( rigN "$rigTmp/bodies" '"thread_ts":"1700000001.000101"' ) $( rigSent CHANNEL )" "0 rig-user-token-NDM 1 client:CNDM00001"
rigRun --member-comms-slack-send-message client-ndm client:CNDM00001 --address-to client:UNDMPERSON RIG-BODY
rigAssert "with a client: addressee, who is mentioned and reported as the addressee" "$rigRc $( rigText ) $( rigSent ADDRESSEES )" '0 🐭 *_Magic Vane_* @dispatchr → <@UNDMPERSON>.\nRIG-BODY UNDMPERSON'
rigRun --member-comms-slack-send-message client-ndm magic-team --address-to client:UNDMPERSON RIG-BODY
rigAssert "a client: addressee in a send that stays on our own side is refused, and nothing is posted" "$rigRc $( rigLines "$rigTmp/bodies" ) $( rigN "$rigTmp/err" "--address-to 'client:UNDMPERSON': a client: addressee is of the other organisation, and this send is on our own organisation's side" )" "1 0 1"
rigRun --member-comms-slack-read client-ndm client:CNDM00001:1700000001.000101 --thread
rigAssert "a --member- read of a client: thread is the client's token reading" "$rigRc $( rigTokens conversations.replies )$( rigOurs )" "0 rig-user-token-NDM 0"
rigRun --member-comms-slack-read client-ndm client:CNDM00001
rigAssert "and of a client: conversation" "$rigRc $( rigTokens conversations.history )$( rigOurs )" "0 rig-user-token-NDM 0"
rigRun --member-comms-slack-react client-ndm client:CNDM00001:1700000001.000101 eyes
rigAssert "a --member- reaction to a client: message is the client's own, on the id alone" "$rigRc $( cat "$rigTmp/reactions" ) $( rigOurs )" "0 rig-user-token-NDM CNDM00001 1700000001.000101 eyes 0"
rigRun --client-comms-slack-send-message client-ndm client:CNDM00001 RIG-BODY
rigAssert "in a --client- operation the marker is accepted too, and changes nothing" "$rigRc $( rigTokens chat.postMessage )$( rigChannel )" "0 rig-user-token-NDM CNDM00001"
rigRun --member-comms-slack-send-message keeper-here client:CNDM00001 RIG-BODY
rigAssert "a member that is no client has no other organisation: its client: send is refused by name, and nothing is called" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigN "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --member-comms-slack-send-message: 'client:CNDM00001' is refused: a client: address connects to the other organisation of a client-* member, and keeper-here is not one" )" "1 0 1"
rigRun --member-comms-slack-read keeper-here client:CNDM00001:1700000001.000101 --thread
rigAssert "and so is its client: read, with no call made" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigN "$rigTmp/err" 'a client: address connects to the other organisation of a client-* member, and keeper-here is not one' )" "1 0 1"
rigRun --member-comms-slack-react keeper-here client:CNDM00001:1700000001.000101 eyes
rigAssert "and its client: reaction" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigLines "$rigTmp/reactions" )" "1 0 0"

echo "-- 5. an address that works on one side only is refused with a hint that names the side --"
for rigAlias in magic-team human-owner event-track event-alert ; do
	rigRun --client-comms-slack-send-message client-ndm "$rigAlias" RIG-BODY
	rigAssert "$rigAlias in a --client- send: refused, naming the operation that was run and the --member- operation the alias works in, and nothing called" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigN "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --member-comms-slack-send-message: '$rigAlias' is refused in --client-comms-slack-send-message: for '$rigAlias', $rigHint --member-comms-slack-send-message operation $rigHintEnd." )" "1 0 1"
done
rigRun --client-comms-slack-send-message client-ndm magic-team:1700000001.000101 RIG-BODY
rigAssert "the same for a thread of one" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigHinted --client-comms-slack-send-message magic-team:1700000001.000101 magic-team )" "1 0 1"
rigRun --client-comms-slack-send-message client-ndm keeper-here RIG-BODY
rigAssert "a team member's name in a --client- send: the same hint, and that member's DM is not looked for" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigHinted --client-comms-slack-send-message keeper-here )" "1 0 1"
## the session thread of a coworking session, as the spawn gives it to every participant
rigPre=( MDAT_SESSION_THREAD=CHERE0001:1700000009.000100 )
rigRun --member-comms-slack-send-message client-ndm '' RIG-BODY
rigAssert "control: with no target a --member- send takes the session thread, which is our own team's" "$rigRc $( rigTokens chat.postMessage )$( rigN "$rigTmp/bodies" '"thread_ts":"1700000009.000100"' )" "0 rig-bot-token-HERE 1"
rigRun --client-comms-slack-send-message client-ndm '' RIG-BODY
rigAssert "with no target a --client- send takes no default: the session thread is our own organisation's, and the refusal says so" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigN "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --member-comms-slack-send-message: <target> missing in --client-comms-slack-send-message -- on the side of the other organisation a conversation or a person is named by its id. The session thread, the default of --member-comms-slack-send-message, is our own organisation's. Nothing was sent." )" "1 0 1"
rigPre=()
rigRun --client-comms-slack-read client-ndm magic-team
rigAssert "a named conversation in a --client- read: the hint names the --member- read" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigHinted --client-comms-slack-read magic-team )" "1 0 1"
rigRun --client-comms-slack-react client-ndm human-owner:1700000001.000101 eyes
rigAssert "in a --client- reaction: the hint names the --member- reaction" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigHinted --client-comms-slack-react human-owner:1700000001.000101 human-owner )" "1 0 1"
rigRun --member-comms-slack-send-message client-ndm client:magic-team RIG-BODY
rigAssert "a named conversation under the client: marker in a --member- send: the hint says the marker goes" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigN "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --member-comms-slack-send-message: 'client:magic-team' is refused: for 'magic-team', $rigHintMarked." )" "1 0 1"
rigRun --member-comms-slack-read client-ndm client:human-owner
rigAssert "and in a --member- read" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigN "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --member-comms-slack-read: 'client:human-owner' is refused: for 'human-owner', $rigHintMarked." )" "1 0 1"
rigRun --member-comms-slack-send-message client-ndm client:keeper-here RIG-BODY
rigAssert "a team member's name under the marker: the same hint" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigN "$rigTmp/err" "'client:keeper-here' is refused: for 'keeper-here', $rigHintMarked." )" "1 0 1"
rigRun --magic-comms-slack-send-message client-ndm magic-team RIG-BODY
rigAssert "a --magic-comms- send given a client, to one of our own named conversations, is our own side like the client's own --member- send: posted by our team's bot into our conversation, under the client's member name, and nothing the client holds is used" "$rigRc $( rigTokens chat.postMessage )$( rigChannel ) $( rigText ) $( rigTheirs )" '0 rig-bot-token-HERE CHERE0001 👥 *_client-ndm_* → @here.\nRIG-BODY 0'
rigRun --magic-client-operation-run magic-coordinator --client-comms-slack-send-message client-ndm magic-team RIG-BODY
rigAssert "through --magic-client-operation-run that name is refused as in the client's own --client- send: the hint that names the --member- twin, and no post" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigHinted --client-comms-slack-send-message magic-team )" "1 0 1"
rigRun --member-comms-slack-send-message keeper-here magic-team RIG-BODY
rigAssert "control: for a member that is no client those names work as they always have, with no hint" "$rigRc $( rigTokens chat.postMessage )$( rigN "$rigTmp/err" "$rigHint" )" "0 rig-user-token-KHERE 0"

echo "-- 5b. the two session addresses are our own organisation's: a client's --member- operation finds them here, its --client- operation and a client: address refuse them --"
## client-ndm's session as the spawn records it in the workspace it runs in: its own session thread, and the thread of
## the session that started it, recorded for that session, a native one with no record of its own.
mkdir -p "$rigWork/ws-here/.local/agents/spawned/rig-session-client" "$rigWork/ws-here/.local/agents/sessions/rig-session-parent"
printf '%s\n' CHERE0001:1700000007.000700 > "$rigWork/ws-here/.local/agents/sessions/rig-session-parent/session.thread"
printf -- '---\nspawn-id: rig-session-client\nowner: client-ndm\nparent-spawn-id: rig-session-parent\nparent-session-id: rig-session-parent\nparent-member: magic-coordinator\nparent-thread: CHERE0001:1700000007.000700\n---\n' > "$rigWork/ws-here/.local/agents/spawned/rig-session-client/rig-session-client.spawn.md"
rigPre=( MDAT_SPAWN_SESSION_ID=rig-session-client MDAT_SPAWN_AGENT=client-ndm MDAT_SESSION_THREAD=CHERE0001:1700000009.000100 )
rigRun --member-comms-slack-send-message client-ndm session-current RIG-BODY
rigAssert "session-current in a client's --member- send: its session thread in our own Slack, by our team's bot" "$rigRc $( rigTokens chat.postMessage )$( rigChannel ) $( rigN "$rigTmp/bodies" '"thread_ts":"1700000009.000100"' ) $( rigTheirs )" "0 rig-bot-token-HERE CHERE0001 1 0"
rigRun --member-comms-slack-send-message client-ndm session-parent RIG-BODY
rigAssert "session-parent there: the thread of the session that started it, read from its spawn record in the workspace it runs in" "$rigRc $( rigTokens chat.postMessage )$( rigChannel ) $( rigN "$rigTmp/bodies" '"thread_ts":"1700000007.000700"' ) $( rigTheirs )" "0 rig-bot-token-HERE CHERE0001 1 0"
rigRun --member-comms-slack-read client-ndm session-current --thread
rigAssert "session-current in a client's --member- read: our team's bot reading that thread" "$rigRc $( rigTokens conversations.replies )$( rigTheirs )" "0 rig-bot-token-HERE 0"
rigRun --member-comms-slack-react client-ndm session-parent eyes
rigAssert "session-parent in a client's --member- reaction: our team's bot, on the root of that thread" "$rigRc $( cat "$rigTmp/reactions" )" "0 rig-bot-token-HERE CHERE0001 1700000007.000700 eyes"
for rigAlias in session-current session-parent ; do
	rigRun --client-comms-slack-send-message client-ndm "$rigAlias" RIG-BODY
	rigAssert "$rigAlias in a --client- send: refused with the plain line, nothing called" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigHinted --client-comms-slack-send-message "$rigAlias" )" "1 0 1"
	rigRun --client-comms-slack-read client-ndm "$rigAlias" --thread
	rigAssert "$rigAlias in a --client- read: the same" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigHinted --client-comms-slack-read "$rigAlias" )" "1 0 1"
	rigRun --client-comms-slack-react client-ndm "$rigAlias" eyes
	rigAssert "$rigAlias in a --client- reaction: the same" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigHinted --client-comms-slack-react "$rigAlias" )" "1 0 1"
	rigRun --member-comms-slack-send-message client-ndm "client:$rigAlias" RIG-BODY
	rigAssert "$rigAlias under the client: marker in a --member- send: refused with the plain line, nothing called" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigN "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --member-comms-slack-send-message: 'client:$rigAlias' is refused: for '$rigAlias', $rigHintMarked." )" "1 0 1"
	rigRun --member-comms-slack-read client-ndm "client:$rigAlias" --thread
	rigAssert "and in a --member- read" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigN "$rigTmp/err" "'client:$rigAlias' is refused: for '$rigAlias', $rigHintMarked." )" "1 0 1"
done
rigToolAs client-ndm SendMessage '{"to":"session-current","message":"RIG-BODY"}'
rigAssert "SendMessage as a client to session-current: its session thread in our own Slack, by our team's bot" "$( rigTokens chat.postMessage )$( rigChannel ) $( rigN "$rigTmp/bodies" '"thread_ts":"1700000009.000100"' ) $( rigTheirs )" "rig-bot-token-HERE CHERE0001 1 0"
rigToolAs client-ndm SendMessage '{"to":"session-parent","message":"RIG-BODY"}'
rigAssert "SendMessage as a client to session-parent: the parent's thread in our own Slack, by our team's bot" "$( rigTokens chat.postMessage )$( rigChannel ) $( rigN "$rigTmp/bodies" '"thread_ts":"1700000007.000700"' ) $( rigTheirs )" "rig-bot-token-HERE CHERE0001 1 0"
rigToolAs client-ndm SendMessage '{"to":"client:session-parent","message":"RIG-BODY"}'
rigAssert "SendMessage to a session address under the marker: not sent, and the plain line reaches the tool's result" "$( rigLines "$rigTmp/bodies" ) $( rigN "$rigTmp/out" "'client:session-parent' is refused: for 'session-parent', $rigHintMarked." )" "0 1"
rigPre=()

echo "-- 6. the tools with no marker reach our own team, a client: address the other organisation --"
rigToolAs client-ndm SendMessage '{"to":"magic-team","message":"RIG-BODY"}'
rigAssert "SendMessage as a client to magic-team: our team's bot, our team's conversation, its member name" "$( rigTokens chat.postMessage )$( rigChannel ) $( rigText ) $( rigTheirs )" 'rig-bot-token-HERE CHERE0001 👥 *_client-ndm_* → @here.\nRIG-BODY 0'
rigToolAs client-ndm SendMessage '{"to":"client:CNDM00001","message":"RIG-BODY"}'
rigAssert "SendMessage as a client to a client: address: the client's token, that conversation, its presentation there" "$( rigTokens chat.postMessage )$( rigChannel ) $( rigText ) $( rigOurs )" 'rig-user-token-NDM CNDM00001 🐭 *_Magic Vane_* @dispatchr → @here.\nRIG-BODY 0'
rigAssert "and the post is recorded on the same side, for the plain Wait that follows" "$( LC_ALL=C sed -n '1p' "$rigWork/ws-here/.local/agents/sessions/rig-session-client/last-own-post" 2> /dev/null | LC_ALL=C cut -d' ' -f1 ):$( rigN "$rigTmp/out" 'NEXT: call Wait' )" "client:CNDM00001:1700000001.000101:1"
rigToolAs client-ndm SendMessage '{"to":"client:magic-team","message":"RIG-BODY"}'
rigAssert "SendMessage to one of our own names under the marker: not sent, and the hint reaches the tool's result" "$( rigLines "$rigTmp/bodies" ) $( rigN "$rigTmp/out" "'client:magic-team' is refused: for 'magic-team', $rigHintMarked." )" "0 1"
rigToolAs keeper-here SendMessage '{"to":"client:CNDM00001","message":"RIG-BODY"}'
rigAssert "SendMessage to a client: address as a member that is no client: not sent, the refusal names why" "$( rigLines "$rigTmp/bodies" ) $( rigN "$rigTmp/out" 'a client: address connects to the other organisation of a client-* member, and keeper-here is not one' )" "0 1"
## The floor of a Wait reads the posts of the rows above; these rows are about the source they name alone.
rm -f "$rigWork/ws-here/.local/agents/sessions/rig-session-client/last-own-post"
rigToolAs client-ndm Wait '{"sources":"slack:client:CNDM00001","timeout":0}'
rigAssert "Wait as a client on a conversation of the other organisation: read under the client's token, as a whole conversation" "$( LC_ALL=C sed -n '1p' "$rigTmp/out" | LC_ALL=C cut -c1-20 ) $( rigTokens conversations.history )$( rigOurs )" "WAIT-RESULT: TIMEOUT rig-user-token-NDM 0"
rigToolAs client-ndm Wait '{"sources":"slack:magic-team","timeout":0}'
rigAssert "Wait as a client on magic-team: our team's bot reading our team's conversation" "$( rigTokens conversations.history )$( rigTheirs )" "rig-bot-token-HERE 0"

echo "-- 7. the tools that ask reach addressees in both organisations, and the answer is read where the question was asked --"
rigPendingDrop
rigToolAs client-ndm AskQuestion '{"to":"client:UNDMPERSON","question":"May the rig go on?","wait":false}'
rigAsked="$( rigPendingId )"
rigAssert "AskQuestion as a client to a person of the other organisation: posted under the client's token to that person, addressed to that person" "$( LC_ALL=C sed -n '1p' "$rigTmp/out" ) $( rigTokens chat.postMessage )$( rigChannel ) $( rigOurs )" "ASK-RESULT: POSTED rig-user-token-NDM UNDMPERSON 0"
rigAssert "its record keeps the side: the conversation it landed in under the client: marker, the address as given, the person as the addressee" "$( rigPendingField "$rigAsked" channel ) $( rigPendingField "$rigAsked" communication-channel-id ) $( rigPendingField "$rigAsked" address-to ) $( rigPendingField "$rigAsked" addressees ) $( rigPendingField "$rigAsked" owner )" "client:DNDMPERSON slack:client:UNDMPERSON client:UNDMPERSON UNDMPERSON client-ndm"
rigToolAs client-ndm Wait "{\"sources\":\"ask:$rigAsked\",\"timeout\":0}"
rigAssert "with nothing in its thread yet, the wait on it reads that thread under the client's token and never under our team's" "$( rigTokens conversations.replies )$( rigOurs )" "rig-user-token-NDM 0"
## the answer exists in the other organisation's Slack only: the thread as the client's token reads it
printf '{"ok":true,"messages":[{"ts":"1700000001.000101","user":"URIGNDM","text":"question"},{"ts":"1700000002.000200","user":"UNDMPERSON","text":"yes, go on"}],"has_more":false}\n' > "$rigTmp/thread.rig-user-token-NDM.json"
rigToolAs client-ndm Wait "{\"sources\":\"ask:$rigAsked\",\"timeout\":0}"
rigAssert "once the person answers there, the wait returns that answer, read under the client's token" "$( LC_ALL=C sed -n '1p' "$rigTmp/out" ) $( rigN "$rigTmp/out" 'yes, go on' | LC_ALL=C awk '{ print ( $1 > 0 ) ? "answer" : "none" }' ) $( rigTokens conversations.replies )" "WAIT-RESULT: RECEIVED answer rig-user-token-NDM "
rigAssert "and its record is closed as answered, by that person" "$( rigPendingField "$rigAsked" status ) $( rigPendingField "$rigAsked" answered-by )" "reply-received UNDMPERSON"
rm -f "$rigTmp/thread.rig-user-token-NDM.json"
rigPendingDrop
rigToolAs client-ndm AskQuestion '{"to":"human-owner","question":"May the rig go on here?","wait":false}'
rigAsked="$( rigPendingId )"
rigAssert "AskQuestion as a client to the human-owner: posted in our own Slack, to our own owner, with no token the client holds" "$( LC_ALL=C sed -n '1p' "$rigTmp/out" ) $( rigChannel ) $( rigTheirs ) $( rigPendingField "$rigAsked" channel )" "ASK-RESULT: POSTED UHEREOWNER 0 DHEREOWNER"
printf '{"ok":true,"messages":[{"ts":"1700000001.000101","user":"URIGCOORD","text":"question"},{"ts":"1700000002.000200","user":"UHEREOWNER","text":"yes, here too"}],"has_more":false}\n' > "$rigTmp/thread.rig-bot-token-HERE.json"
cp "$rigTmp/thread.rig-bot-token-HERE.json" "$rigTmp/thread.rig-user-token-COORD.json"
rigToolAs client-ndm Wait "{\"sources\":\"ask:$rigAsked\",\"timeout\":0}"
rigAssert "its answer is read in our own Slack, and no token the client holds is used" "$( LC_ALL=C sed -n '1p' "$rigTmp/out" ) $( rigN "$rigTmp/out" 'yes, here too' | LC_ALL=C awk '{ print ( $1 > 0 ) ? "answer" : "none" }' ) $( rigTheirs )" "WAIT-RESULT: RECEIVED answer 0"
rm -f "$rigTmp"/thread.*.json
## RequestPermission asks through the same one send and the same record. It needs a refused call on record, and who
## may grant one is the permission store's own rule, held by its own checks, so it is not asked here.
for rigAskTool in ConfirmReadback EscalateDecision ; do
	rigPendingDrop
	case "$rigAskTool" in
		ConfirmReadback) rigAskArgs='{"to":"client:UNDMPERSON","question":"Does the rig go on?","understood":"The rig goes on.","source":"your note","will_do":"Go on."}' ;;
		EscalateDecision) rigAskArgs='{"to":"client:UNDMPERSON","question":"Which way does the rig go?","options":"left\nright","context":"The rig stands at a fork."}' ;;
	esac
	rigToolAs client-ndm "$rigAskTool" "$rigAskArgs"
	rigAsked="$( rigPendingId )"
	rigAssert "$rigAskTool as a client to a person of the other organisation: posted under the client's token, recorded on that side, and its thread read there, never in our own Slack" "$( rigTokens chat.postMessage )$( rigChannel ) $( rigPendingField "$rigAsked" channel ) $( rigTokens conversations.replies )$( rigOurs )" "rig-user-token-NDM UNDMPERSON client:DNDMPERSON rig-user-token-NDM 0"
done
rigPendingDrop
rigToolAs client-ndm AskQuestion '{"to":"client:magic-team","question":"May the rig go on there?","wait":false}'
rigAssert "a question to one of our own names under the marker is not posted, nothing is recorded, and the hint reaches the tool's result" "$( LC_ALL=C sed -n '1p' "$rigTmp/out" | LC_ALL=C cut -c1-6 ) $( rigLines "$rigTmp/bodies" ) [$( rigPendingId )] $( rigN "$rigTmp/out" "'client:magic-team' is refused: for 'magic-team', $rigHintMarked." )" "ERROR: 0 [] 1"

echo "-- 8. a client's session is started here, like any invited member's --"
rigClean
rigRc=0
( cd "$rigWork/ws-here" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/ws-here" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" \
	bash "$rigTool" --intern-op-agent-spawn-proxy client-ndm --dispatch-doc:none --wait --context rig-client-sides ) > "$rigTmp/out" 2> "$rigTmp/err" <<< "RIG-TASK-TEXT" || rigRc=$?
rigAssert "its session is launched by the console of the workspace it was called from, on the view of the workspace it is set up in" "$rigRc $( cat "$rigTmp/launched.HERE" 2> /dev/null | LC_ALL=C sed "s|$rigWork/||" ) $( cat "$rigTmp/roots.HERE" 2> /dev/null | LC_ALL=C sed "s|$rigWork/||" ) [$( cat "$rigTmp/launched.THERE" 2> /dev/null )]" "0 ws-here client-ndm=ws-there/.local/agents/members []"
rigAssert "its session thread is opened in our own Slack by our team's bot, though the client holds a token of its own" "$( rigTokens chat.postMessage )$( rigChannel ) $( rigTheirs ) $( rigElsewhere )" "rig-bot-token-HERE CHERE0001 0 0"
rigClientRecord="$( LC_ALL=C grep -l -x 'owner: client-ndm' "$rigWork/ws-here"/.local/agents/spawned/*/*.spawn.md 2> /dev/null | LC_ALL=C grep -v '/rig-session-client/' | LC_ALL=C sed -n 1p )"
rigAssert "its record is kept here and says the three workspaces of the run as any invited member's does: executed and paid here, its member's the one it is set up in" "$( LC_ALL=C awk -F': ' '$1 == "executing-workspace" { e = $2 } $1 == "paying-workspace" { p = $2 } $1 == "member-workspace" { m = $2 } END { printf "%s/%s/%s", e, p, m }' "$rigClientRecord" 2> /dev/null ) $( ls "$rigWork/ws-there/.local/agents/spawned" 2> /dev/null | LC_ALL=C awk 'END { print NR + 0 }' )" "ws-here/ws-here/ws-there 0"

echo "-- 9. static: the side is said in one place, and the settings are read by it --"
rigAssert "the side is set where a --client-* operation is dispatched, once" "$( LC_ALL=C grep -c -F -e '--client-*) local -x MDAT_COMMS_SIDE=client MDAT_COMMS_OP="$1" ;;' "$rigTool" || : )" 1
rigAssert "a --member- Slack operation says our own side itself, once, whatever it was called under" "$( LC_ALL=C grep -c -F -e 'local -x MDAT_COMMS_SIDE=own MDAT_COMMS_OP=""' "$rigHere/comms/AgentsTools.MemberCommsSlack.include" || : )" 1
rigAssert "the two questions every reader of a member's own Slack settings asks are defined once, in the Slack include" "$( LC_ALL=C grep -c -E '^AgentsToolsSlack(OwnSettingsApply|ClientSide)\(\)\{' "$rigSlackInclude" || : ) $( cat "$rigHere"/*/*.include "$rigHere"/*/*.sh | LC_ALL=C grep -c -E '^AgentsToolsSlack(OwnSettingsApply|ClientSide)\(\)\{' || : )" "2 2"
rigAssert "every file of the package that reads a member's own Slack user token by the member's name asks the first of them" "$( for rigFile in "$rigHere"/*/*.include ; do LC_ALL=C grep -q -E -e '--agents-config-option "\$[A-Za-z]*" --select SLACK_USER_TOKEN' "$rigFile" || continue ; LC_ALL=C grep -q 'AgentsToolsSlackOwnSettingsApply' "$rigFile" || printf '%s ' "${rigFile##*/}" ; done )" ""
rigAssert "control: the same search does find files that read it" "$( for rigFile in "$rigHere"/*/*.include ; do LC_ALL=C grep -q -E -e '--agents-config-option "\$[A-Za-z]*" --select SLACK_USER_TOKEN' "$rigFile" && printf 'x' ; done | LC_ALL=C awk '{ print ( length( $0 ) >= 5 ) ? "found" : "blind" }' )" found
rigAssert "the spawn proxy has no arm of its own for a client-* member" "$( LC_ALL=C grep -v '^[[:space:]]*#' "$rigSpawnInclude" | LC_ALL=C grep -c -F -e 'client-*)' || : )" 0
if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ CLIENT SIDES CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'CLIENT_SIDES: OK (%d assertions, offline)\n' "$rigPasses"
