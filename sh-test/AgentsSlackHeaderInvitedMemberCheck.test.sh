#!/usr/bin/env bash
## Behavioural check on how a member is shown in the author line of a message, as its sender
## and as one it is addressed to, run rather than read.
## A member invited from another workspace: its mark and alias come from the workspace it is
## set up in, since the names registry of the workspace a send runs from holds that
## workspace's own members only. The seen fault: an invited keeper posting as
## `*keeper* @keeper`, with no mark and its identifier as its alias, silently.
## A member's own mark is the one shown, always. Only a member with no mark of its own, no row
## or a row without one, has the default icon of its prefix group, from the one list the
## installer's member table takes it from. The rule is the prefix: each group is measured
## here with a made-up member that has no mark and one that has its own.
## A client-* member has two presentations, chosen by the side and never mixed: to the other
## organisation it is its persona, the mark, names and alias of its row; inside our own team
## it is a team member, shown by its own member name as its alias, so the persona's alias
## never names two members here. Its mark is its row's on both sides.
## An invited member whose alias a member here already goes by is shown by its member name,
## and one line on stderr says so. A member with no row anywhere is shown by its member name,
## and one line on stderr says so.
## A name is said once: where a member's alias is its own member name, the line shows the
## name alone, with no `@<name>` beside it; where the alias is another word, name and alias
## both stand, as they did. One rule, for a sender and for a member a message is addressed
## to, and every reader of the line takes the line that says the name once: the dismissal
## reader, the reader that takes a header off a reply, and the verdict reader.
## Reading takes what posting writes: a message addressed to a client in its in-team form
## dismisses that client, and one addressed to the persona's own member does not.
## Offline: two workspaces in one rig tree, a rig HOME with the machine's members index, and a
## Slack-shaped fake curl first on PATH.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents"
rigHere="$rigPackage/sh-lib"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigTest="$rigPackage/sh-test"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsSlackHeaderInvitedMemberCheck-XXXXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWork="$rigTmp/work" ; rigHome="$rigTmp/home"
rigIndexFile="$rigHome/.agents/magic-team/members.registry"
rigListFile="$rigHome/.agents/magic-team/known-workspaces.registry"
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/member-workspace-check.curl.stub.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigTest/check-fixtures/member-workspace-check.curl.stub.sh"
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
## ws-here, the workspace every send below runs from unless it says otherwise, and ws-there.
## A member is set up in a workspace by its own directory in that workspace's source, linked
## into that workspace's member set view, and by its row in the machine's members index.
rigMemberHome(){ ## workspace, member
	printf '%s\n' "$rigWork/$1/source/myx/pkg/skillset/$2"
}
rigView(){ ## workspace
	printf '%s\n' "$rigWork/$1/.local/agents/members"
}
rigNames(){ ## workspace -- its names registry
	printf '%s\n' "$rigWork/$1/.local/agents/team-members-names.registry"
}
rigMemberAt(){ ## workspace, member, link kind
	local atDir
	atDir="$( rigMemberHome "$1" "$2" )"
	mkdir -p "$atDir" "$( rigView "$1" )"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$atDir/$2.basic.md"
	printf '# rig armed\n' > "$atDir/$2.armed.md"
	printf -- '---\nname: %s\n---\n\n# %s, set up in %s\n' "$2" "$2" "$1" > "$atDir/SKILL.md"
	[ "$2" != magic-team ] || printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator\ninvitees: magic-team\ndefault-for-session-kind: coworking\n---\n# rig coworking routine fixture\n' > "$atDir/magic-team.coworking.routine.md"
	ln -sfn "$atDir" "$( rigView "$1" )/$2"
	printf '%s\t%s\t%s\tmyx/pkg/skillset/%s\t%s\n' "$2" "$rigWork/$1" "$3" "$2" "$atDir" >> "$rigIndexFile"
}
rigWorld(){ ## -- a fresh machine
	rm -rf "$rigWork" "$rigHome"
	local wsName memberName
	for wsName in ws-here ws-there ; do mkdir -p "$rigWork/$wsName/.local/.agents" "$rigWork/$wsName/.local/agents/members" ; done
	mkdir -p "${rigIndexFile%/*}" ; : > "$rigIndexFile"
	for memberName in keeper-here keeper-nomark magic-coordinator magic-plain partner-plain partner-marked warden-plain warden-marked ; do rigMemberAt ws-here "$memberName" source-symlink ; done
	rigMemberAt ws-here magic-team source-symlink ; rigMemberAt ws-there magic-team origin-symlink
	rigMemberAt ws-here human-owner source-symlink ; rigMemberAt ws-there human-owner origin-symlink
	for memberName in keeper-there keeper-norow keeper-clash client-rig client-plain client-nomark ; do rigMemberAt ws-there "$memberName" source-symlink ; done
	printf '%s\n' "$rigWork/ws-here" "$rigWork/ws-there" > "$rigListFile"
	printf '%s\n' 'SLACK_CHANNEL_MAGIC_TEAM=CHERE0001' 'SLACK_CHANNEL_HUMAN_OWNER=UHEREOWNER' 'SLACK_BOT_TOKEN=rig-bot-token-HERE' > "$rigWork/ws-here/.local/.agents/magic-team.agent.env"
	printf '%s\n' 'SLACK_CHANNEL_MAGIC_TEAM=CTHERE0001' 'SLACK_CHANNEL_HUMAN_OWNER=UTHEREOWNER' 'SLACK_BOT_TOKEN=rig-bot-token-THERE' > "$rigWork/ws-there/.local/.agents/magic-team.agent.env"
	## Each workspace's own names registry: its own members only. Of each prefix group one
	## member has a mark of its own and one has none: magic-plain, partner-plain, warden-plain,
	## keeper-norow and client-plain have no row, keeper-nomark and client-nomark a row with no
	## mark. A client's row is its persona's, which the build takes from the persona member:
	## here the same mark, names and alias as magic-coordinator's own. keeper-clash's alias
	## there is the one keeper-here goes by here.
	printf '%s\n' 'human-owner :rig-owner: - - -' 'keeper-here 🔧 Hera Keeper herakeep' 'keeper-nomark - Nomark Keeper nomarkkeep' 'magic-coordinator 🐭 Magic Vane dispatchr' 'magic-team :rig-team: - - -' 'partner-marked 🧷 Mara Partner marapart' 'warden-marked 🔔 Wanda Warden wandaward' > "$( rigNames ws-here )"
	printf '%s\n' 'client-nomark - Magic Vane dispatchr' 'client-rig 🐭 Magic Vane dispatchr' 'human-owner :rig-owner: - - -' 'keeper-clash 🧭 Clash Keeper herakeep' 'keeper-there 🌾 Thea Vance farmhand' 'magic-team :rig-team: - - -' > "$( rigNames ws-there )"
	: > "$rigTmp/calls" ; : > "$rigTmp/envs" ; : > "$rigTmp/bodies"
}
rigRunIn(){ ## workspace, args... -- one dispatcher call from that workspace; stdout in out, stderr in err, rc in rigRc
	: > "$rigTmp/calls" ; : > "$rigTmp/envs" ; : > "$rigTmp/bodies"
	rigRc=0
	( cd "$rigWork/$1" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/$1" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" \
		bash "$rigTool" "${@:2}" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigSend(){ ## member, further arguments of the send... -- a --member- send to the team's conversation, from ws-here
	local sendMember="$1" ; shift
	rigRunIn ws-here --member-comms-slack-send-message "$sendMember" magic-team "$@"
}
rigText(){ ## -- the text field of the first posted body, escapes as sent
	LC_ALL=C sed -n '1s/^{"channel":"[^"]*","text":"//; 1s/","blocks":.*//; 1s/"}$//; 1p' "$rigTmp/bodies"
}
rigHeader(){ ## -- its author line: the text up to its first line break
	rigText | LC_ALL=C sed 's/\\n.*$//'
}
rigPosts(){ ## -- how many posts were made
	LC_ALL=C grep -c '^chat.postMessage ' "$rigTmp/calls" 2> /dev/null || :
}
rigSaid(){ ## fixed text -- how many lines of the last call's stderr hold it
	LC_ALL=C grep -c -F -- "$1" "$rigTmp/err" 2> /dev/null || :
}
rigNoRowLines(){ ## member -- how many lines of the last call's stderr say that member has no row
	rigSaid "member '$1' has no row in the team-members-names registry"
}
rigSum(){ ## file
	cksum < "$1" 2> /dev/null
}

rigWorld
[ -d "$( rigView ws-there )/keeper-there" ] && [ ! -e "$( rigView ws-here )/keeper-there" ] || rigRefuse "the fixture does not hold the invited member in its own workspace's view only"
LC_ALL=C grep -q '^keeper-there ' "$( rigNames ws-here )" && rigRefuse "the fixture's calling workspace has a row for the invited member, so no row below would show where a row is read from"
rigSend keeper-here RIG-BODY
[ "$rigRc" = 0 ] && [ "$( rigPosts )" = 1 ] || rigRefuse "the baseline send of a member set up here did not post, so no row below would be measured: rc=$rigRc $( LC_ALL=C grep -m1 -E 'ERROR|WARNING' "$rigTmp/err" )"

echo "-- control: a member set up here posts under its own row of this workspace's registry --"
rigAssert "its mark and alias are its row's"                "$( rigText )" '🔧 *_keeper-here_* @herakeep → @here.\nRIG-BODY'
rigAssert "and nothing is said about a row"                 "$( rigNoRowLines keeper-here )" 0

echo "-- a member invited from another workspace: its mark and alias come from the workspace it is set up in --"
rigThereSum="$( rigSum "$( rigNames ws-there )" )"
rigSend keeper-there RIG-BODY
rigAssert "its send is made from here, once"                "$rigRc $( rigPosts )" "0 1"
rigAssert "its author line carries the mark and alias of its row there, never its identifier as its alias" "$( rigText )" '🌾 *_keeper-there_* @farmhand → @here.\nRIG-BODY'
rigAssert "and nothing is said about a row: it has one"     "$( rigNoRowLines keeper-there )" 0
rigSend keeper-here --address-to keeper-there RIG-BODY
rigAssert "addressed by a member set up here, it is named by the same row" "$rigRc $( rigText )" '0 🔧 *_keeper-here_* @herakeep → 🌾 *_keeper-there_* @farmhand.\nRIG-BODY'
rigAssert "the registry of the workspace it is set up in is only read" "$( rigSum "$( rigNames ws-there )" )" "$rigThereSum"
rigAssert "and this workspace's registry gets no row for it" "$( LC_ALL=C grep -c '^keeper-there ' "$( rigNames ws-here )" )" 0

echo "-- a member with no mark of its own has the default icon of its prefix group, and one with its own keeps it --"
## The one list of them, asked directly: what the installer's member table shows.
rigKindIcon(){ ## member
	( env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/ws-here" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "$1" ; AgentsToolsTeamMemberKindIcon "$2"' rig-icon "$rigHere/AgentsTools.TeamRegistry.include" "$1" ) 2> /dev/null
}
rigAssert "control: the list gives each prefix group its icon, whatever member of it is asked" \
	"$( rigKindIcon client-x ) $( rigKindIcon client-y ) $( rigKindIcon partner-x ) $( rigKindIcon keeper-x ) $( rigKindIcon keeper-y ) $( rigKindIcon warden-x ) $( rigKindIcon human-owner ) $( rigKindIcon magic-x ) $( rigKindIcon magic-y )" "👥 👥 👫 🔏 🔏 🔏 👤 🤖 🤖"
rigSend keeper-norow RIG-BODY
rigAssert "a keeper with no row anywhere: its group's icon, its member name as alias" "$rigRc $( rigText )" "0 $( rigKindIcon keeper-norow ) *_keeper-norow_* → @here.\\nRIG-BODY"
rigAssert "and one line on stderr says it has no row, here or where it is set up" "$( rigNoRowLines keeper-norow )" 1
rigAssert "that line names the workspace the send ran from and what builds the registry" \
	"$( LC_ALL=C grep -F -- "member 'keeper-norow' has no row" "$rigTmp/err" | LC_ALL=C grep -c -F -- "$rigWork/ws-here" ):$( LC_ALL=C grep -F -- "member 'keeper-norow' has no row" "$rigTmp/err" | LC_ALL=C grep -c -F -- '--make-agents-indices' )" "1:1"
rigSend magic-plain RIG-BODY
rigAssert "magic-*, no mark: its group's icon"              "$( rigHeader )" '🤖 *_magic-plain_* → @here.'
rigSend magic-coordinator --identity-bot RIG-BODY
rigAssert "magic-*, its own mark: kept"                     "$( rigHeader )" '🐭 *_magic-coordinator_* @dispatchr → @here.'
rigSend partner-plain RIG-BODY
rigAssert "partner-*, no mark: its group's icon"            "$( rigHeader )" '👫 *_partner-plain_* → @here.'
rigSend partner-marked RIG-BODY
rigAssert "partner-*, its own mark: kept"                   "$( rigHeader )" '🧷 *_partner-marked_* @marapart → @here.'
rigSend warden-plain RIG-BODY
rigAssert "warden-*, no mark: its group's icon"             "$( rigHeader )" '🔏 *_warden-plain_* → @here.'
rigSend warden-marked RIG-BODY
rigAssert "warden-*, its own mark: kept"                    "$( rigHeader )" '🔔 *_warden-marked_* @wandaward → @here.'
rigSend keeper-nomark RIG-BODY
rigAssert "keeper-*, a row with an alias and no mark: its group's icon, and the alias of its row, with nothing said" "$( rigHeader ) $( rigNoRowLines keeper-nomark )" '🔏 *_keeper-nomark_* @nomarkkeep → @here. 0'
rigSend keeper-here RIG-BODY
rigAssert "keeper-*, its own mark: kept"                    "$( rigHeader )" '🔧 *_keeper-here_* @herakeep → @here.'
rigSend client-plain RIG-BODY
rigAssert "client-*, no row: its group's icon, its member name, and the one line" "$rigRc $( rigHeader ) $( rigNoRowLines client-plain )" '0 👥 *_client-plain_* → @here. 1'
rigSend client-nomark RIG-BODY
rigAssert "client-*, a row with no mark: its group's icon, its member name and not the alias of its row, with nothing said" "$rigRc $( rigHeader ) $( rigNoRowLines client-nomark )" '0 👥 *_client-nomark_* → @here. 0'
rigSend client-rig RIG-BODY
rigAssert "client-*, a mark in its row: kept"               "$( rigHeader )" '🐭 *_client-rig_* → @here.'
rigSend keeper-here --address-to keeper-norow --address-to magic-plain --address-to client-plain --address-to partner-marked RIG-BODY
rigAssert "addressed: a member with no mark by its group's icon and its member name, one with its own by that, and the send is not held over it" \
	"$rigRc $( rigHeader )" '0 🔧 *_keeper-here_* @herakeep → 🔏 *_keeper-norow_*; 🤖 *_magic-plain_*; 👥 *_client-plain_*; 🧷 *_partner-marked_* @marapart.'
rigSend keeper-here --address-to human-owner RIG-BODY
rigAssert "the human-owner's own mark is kept" "$( rigHeader | LC_ALL=C sed 's/ <@[A-Z0-9]*>\.$/ <@ID>./' )" '🔧 *_keeper-here_* @herakeep → :rig-owner: *_human-owner_* <@ID>.'
rigAssert "no member is named by the rule: the list holds prefixes, and of single names only the human-owner the member table already had" \
	"$( LC_ALL=C sed -n '/^AgentsToolsTeamMemberKindIcon()/,/^}/p' "$rigHere/AgentsTools.TeamRegistry.include" | LC_ALL=C grep -c ') *printf' ):$( LC_ALL=C sed -n '/^AgentsToolsTeamMemberKindIcon()/,/^}/p' "$rigHere/AgentsTools.TeamRegistry.include" | LC_ALL=C grep ') *printf' | LC_ALL=C grep -v -e '^[[:space:]]*[a-z|*-]*-\*)' -e '^[[:space:]]*\*)' -e '^[[:space:]]*human-owner)' | wc -l | tr -d ' ' ):$( LC_ALL=C sed -n '/^AgentsToolsCommsSlackMemberTeamPresentation()/,/^}/p' "$rigHere/AgentsTools.MemberCommsSlack.include" | LC_ALL=C grep -c -e 'client-[a-z]' -e 'keeper-[a-z]' -e 'magic-[a-z]' -e 'partner-[a-z]' )" "6:0:0"
rigAssert "the installer's table and the author line take the icon from the one list: neither file holds an icon of a kind" \
	"$( LC_ALL=C grep -c -e '👥' -e '👫' -e '🔏' -e '👤' "$rigHere/AgentsTools.Install.include" ):$( LC_ALL=C grep -c -e '👥' -e '👫' -e '🔏' -e '👤' "$rigHere/AgentsTools.MemberCommsSlack.include" ):$( LC_ALL=C grep -c 'AgentsToolsTeamMemberKindIcon "' "$rigHere/AgentsTools.Install.include" ):$( LC_ALL=C grep -c 'AgentsToolsTeamMemberKindIcon "' "$rigHere/AgentsTools.MemberCommsSlack.include" )" "0:0:1:1"
rm -f "$( rigNames ws-there )"
rigSend keeper-there RIG-BODY
rigAssert "with no registry at all in the workspace it is set up in: its group's icon, its member name, and the one line" "$rigRc $( rigText ) $( rigNoRowLines keeper-there )" '0 🔏 *_keeper-there_* → @here.\nRIG-BODY 1'
LC_ALL=C grep -v '^human-owner ' "$( rigNames ws-here )" > "$rigTmp/names.cut" && cat "$rigTmp/names.cut" > "$( rigNames ws-here )"
rigSend keeper-here --address-to human-owner RIG-BODY
rigAssert "the human-owner with no mark where the tooling looks: the icon the member table has for it" "$rigRc $( rigHeader | LC_ALL=C sed 's/ <@[A-Z0-9]*>\.$/ <@ID>./' )" '0 🔧 *_keeper-here_* @herakeep → 👤 *_human-owner_* <@ID>.'

echo "-- a client inside our own team: a team member, by its own member name, with the mark of its row --"
rigWorld
rigSend client-rig RIG-BODY
rigAssert "an invited client's --member- send: the mark of its row and its member name, never the alias of its persona" \
	"$rigRc $( rigText )" '0 🐭 *_client-rig_* → @here.\nRIG-BODY'
rigAssert "the persona's alias and names are not in the post, nor the default icon: it has a mark" "$( LC_ALL=C grep -c -e 'dispatchr' -e 'Magic Vane' -e '👥' "$rigTmp/bodies" )" 0
rigAssert "and nothing is said on stderr about its row or its alias" "$( rigNoRowLines client-rig ):$( rigSaid 'is invited from another workspace' )" "0:0"
rigSend magic-coordinator --identity-bot --address-to client-rig RIG-BODY
rigAssert "addressed by the member whose persona it shares: two members, two aliases" \
	"$rigRc $( rigHeader )" '0 🐭 *_magic-coordinator_* @dispatchr → 🐭 *_client-rig_*.'
rigRunIn ws-there --member-comms-slack-send-message client-rig magic-team RIG-BODY
rigAssert "the same in the workspace it is set up in, where the registry holds its persona row" "$rigRc $( rigText )" '0 🐭 *_client-rig_* → @here.\nRIG-BODY'
rigAssert "no registry row is written, added or removed by a send: both registries stand as they were" \
	"$( LC_ALL=C grep -c '' "$( rigNames ws-here )" ):$( LC_ALL=C grep -c '' "$( rigNames ws-there )" ):$( LC_ALL=C grep -c '^client-rig 🐭 Magic Vane dispatchr$' "$( rigNames ws-there )" )" "7:6:1"

echo "-- the same client to the other organisation: its persona, and nothing of its in-team form --"
## What a send into the other organisation needs, in the workspace it is called from: the
## client's own token there and its contact for the conversation.
printf '%s\n' 'SLACK_USER_TOKEN=rig-user-token-CLIENTHERE' > "$rigWork/ws-here/.local/.agents/client-rig.agent.env"
mkdir -p "$rigWork/ws-here/.local/agents/team-data-root/inboxes/client-rig/incoming"
printf '%s\n' \
	'| slack-id | contact | handle | email | organisation | permission level |' \
	'| --- | --- | --- | --- | --- | --- |' \
	'| CCLIENT001 | rig-client-team | @rig-client-team | <unresolved> | rig | unset |' \
	> "$rigWork/ws-here/.local/agents/team-data-root/inboxes/client-rig/incoming/note-rig-contacts.md"
rigRunIn ws-here --client-comms-slack-send-message client-rig CCLIENT001 RIG-BODY
rigAssert "a --client- send: the mark, names and alias of its persona row, and no member name of ours" \
	"$rigRc $( rigText ) $( LC_ALL=C grep -c -e 'client-rig' -e '👥' "$rigTmp/bodies" )" '0 🐭 *_Magic Vane_* @dispatchr → @here.\nRIG-BODY 0'
rigSend client-rig RIG-BODY
rigAssert "and its --member- send, with that token in its scope, is still the team member's" "$rigRc $( rigHeader )" '0 🐭 *_client-rig_* → @here.'

echo "-- an invited member whose alias a member here already goes by: its member name, and one line --"
rigSend keeper-clash RIG-BODY
rigAssert "as sender: its own mark, its member name as alias, never the alias a member here has" "$rigRc $( rigText )" '0 🧭 *_keeper-clash_* → @here.\nRIG-BODY'
rigAssert "and one line on stderr says so, naming the alias" "$( rigSaid "member 'keeper-clash' is invited from another workspace, where its alias is 'herakeep', which a member of $rigWork/ws-here already goes by" )" 1
rigSend keeper-here --address-to keeper-clash RIG-BODY
rigAssert "as addressee, beside the member that has the alias here: two members, two aliases, and the same line" \
	"$rigRc $( rigHeader ) $( rigSaid "member 'keeper-clash' is invited from another workspace" )" '0 🔧 *_keeper-here_* @herakeep → 🧭 *_keeper-clash_*. 1'
rigRunIn ws-there --member-comms-slack-send-message keeper-clash magic-team RIG-BODY
rigAssert "control: in the workspace it is set up in, where no other member has it, its alias is its own" "$rigRc $( rigHeader ) $( rigSaid 'is invited from another workspace' )" '0 🧭 *_keeper-clash_* @herakeep → @here. 0'
rigSend keeper-there RIG-BODY
rigAssert "control: an invited member whose alias nobody here has keeps it, with nothing said" "$( rigHeader ) $( rigSaid 'is invited from another workspace' )" '🌾 *_keeper-there_* @farmhand → @here. 0'

echo "-- reading takes what posting writes: a message addressed to the client in its in-team form --"
## One message as a wait renders it: its head line, then its text as it was sent, a line break
## for each one sent. The dismissal reader is the one a Wait asks (AgentsHarnessWaitDismissed.awk).
rigDismisses(){ ## member, the text of a message as sent -- yes when that message dismisses that member
	printf '1700000001.000100 | URIGBOT01 | %s\n' "$2" | LC_ALL=C awk '{ gsub( /\\n/, "\n" ) ; print ; }' \
		| dismissalMember="$1" LC_ALL=C awk -f "$rigHere/AgentsDismissalMatch.awk" -f "$rigHere/AgentsHarnessWaitDismissed.awk" > /dev/null 2>&1 && printf yes || printf no
}
rigSend keeper-here --address-to client-rig DISMISSED
rigToClient="$( rigText )"
rigAssert "control: the message as posted, addressed to the client by its in-team form" "$rigToClient" '🔧 *_keeper-here_* @herakeep → 🐭 *_client-rig_*.\nDISMISSED'
rigAssert "it dismisses the client, and not the member whose persona the client shares" "$( rigDismisses client-rig "$rigToClient" ):$( rigDismisses magic-coordinator "$rigToClient" ):$( rigDismisses keeper-here "$rigToClient" )" "yes:no:no"
rigSend keeper-here --address-to magic-coordinator DISMISSED
rigToPersona="$( rigText )"
rigAssert "one addressed to that member, by the alias the persona carries, dismisses that member and not the client" \
	"$( rigHeader | LC_ALL=C sed 's/ → .*$//' ):$( LC_ALL=C grep -c -F -- '*_magic-coordinator_* @dispatchr' "$rigTmp/bodies" ):$( rigDismisses magic-coordinator "$rigToPersona" ):$( rigDismisses client-rig "$rigToPersona" )" '🔧 *_keeper-here_* @herakeep:1:yes:no'
rigAssert "typed with its in-team alias, which is its member name, a dismissal reaches the client" "$( rigDismisses client-rig 'DISMISSED client-rig' ):$( rigDismisses client-rig 'DISMISSED dispatchr' )" "yes:no"
rigSend client-rig --address-to keeper-here RIG-BODY
## memberSendHeaderLength is what every reader of a reply takes a send header off by.
printf '%s\n' '{ gsub( /\\n/, "\n" ) ; split( $0, lineOf, "\n" ) ; print ( memberSendHeaderLength( lineOf[1] ) == length( lineOf[1] ) ? "header" : "no-header" ) ; }' > "$rigTmp/header.awk"
rigAssert "the client's own in-team author line is a send header to every reader: its length is its whole first line" \
	"$( rigText ):$( rigText | LC_ALL=C awk -f "$rigHere/AgentsDismissalMatch.awk" -f "$rigTmp/header.awk" 2> /dev/null )" '🐭 *_client-rig_* → 🔧 *_keeper-here_* @herakeep.\nRIG-BODY:header'

echo "-- a name is said once: a member whose alias is its own name, as sender and as addressee --"
rigSend magic-plain --address-to keeper-here --address-to partner-plain RIG-BODY
rigAssert "its name stands once, with no @name beside it, and a member whose alias is another word keeps name and alias" \
	"$rigRc $( rigText )" '0 🤖 *_magic-plain_* → 🔧 *_keeper-here_* @herakeep; 👫 *_partner-plain_*.\nRIG-BODY'
rigAssert "nowhere in the post does the name follow itself" "$( LC_ALL=C grep -c -e '@magic-plain' -e '@partner-plain' "$rigTmp/bodies" )" 0
rigAssert "the line the reader takes off a reply is the whole first line: a header" \
	"$( rigText | LC_ALL=C awk -f "$rigHere/AgentsDismissalMatch.awk" -f "$rigTmp/header.awk" 2> /dev/null )" header
rigAssert "the one rule is asked in two places of the send, the sender and the addressee, and the send writes no alias of its own" \
	"$( LC_ALL=C grep -c 'AgentsToolsCommsSlackAliasShown "' "$rigHere/AgentsTools.MemberCommsSlack.include" ):$( LC_ALL=C grep -c -e '@\$fromAlias' -e '@\$addrAlias' "$rigHere/AgentsTools.MemberCommsSlack.include" )" "2:0"
rigSend keeper-here --address-to magic-plain DISMISSED
rigToPlain="$( rigText )"
rigAssert "addressed to it, a dismissal reaches it by its name said once, and nobody else" \
	"$rigToPlain:$( rigDismisses magic-plain "$rigToPlain" ):$( rigDismisses keeper-here "$rigToPlain" ):$( rigDismisses partner-plain "$rigToPlain" )" '🔧 *_keeper-here_* @herakeep → 🤖 *_magic-plain_*.\nDISMISSED:yes:no:no'
rigSend magic-plain --address-to keeper-here DISMISSED
rigFromPlain="$( rigText )"
rigAssert "sent by it, a dismissal reaches the member it names and never its own sender" \
	"$rigFromPlain:$( rigDismisses keeper-here "$rigFromPlain" ):$( rigDismisses magic-plain "$rigFromPlain" )" '🤖 *_magic-plain_* → 🔧 *_keeper-here_* @herakeep.\nDISMISSED:yes:no'
rigAssert "what a person types to name such a member is its member name" "$( rigDismisses magic-plain 'DISMISSED magic-plain' ):$( rigDismisses magic-plain 'DISMISSED @magic-plain' )" "yes:no"
## The verdict reader takes a member's reply by its first word after the header (AgentsEscalationVerdict.awk).
rigVerdictOf(){ ## reply text -- the verdict the reader takes from it
	printf '1700000001.000200 | URIGOWNER | %s\n' "$1" | MDAT_VERDICT_KIND=permission MDAT_VERDICT_AUTHORS=URIGOWNER LC_ALL=C awk -f "$rigHere/AgentsEscalationVerdict.awk" 2> /dev/null | LC_ALL=C cut -f1
}
rigAssert "the verdict reader takes the answer after a header that says the name once: with a sign, with a shortcode, with no mark" \
	"$( rigVerdictOf '🤖 *_magic-plain_* → 👤 *_human-owner_* <@URIGOWNER>. allow-once' ):$( rigVerdictOf ':robot_face: *_magic-plain_* → @here. deny' ):$( rigVerdictOf '*_magic-plain_* → @here. deny' )" "allow-once:deny:deny"
rigAssert "control: and after a header with name and alias, as before" "$( rigVerdictOf '🔧 *_keeper-here_* @herakeep → @here. deny' )" deny
rigAssert "a person's own words with an arrow in them are no header, a marked word ahead of a name included" \
	"$( rigVerdictOf 'see *_this_* → b. allow-once' ):$( rigVerdictOf 'see a → b. allow-once' )" "RETURNED:RETURNED"

rigAssert "no request left this box: every call went to the fake curl" "$( LC_ALL=C awk '$1 == "http" { hitCount++ ; } END { print hitCount + 0 ; }' "$rigTmp/calls" )" 0

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SLACK HEADER INVITED MEMBER CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2
	echo "  warn: a member is shown with no icon or not with its own mark, an invited member under another member's alias, a client inside our team under its persona's alias, or a name said twice or not read where it is said once" >&2
	echo "  fix:  repair AgentsToolsCommsSlackMemberTeamPresentation, AgentsToolsCommsSlackMemberPresentation and AgentsToolsCommsSlackAliasShown in sh-lib/AgentsTools.MemberCommsSlack.include, or the readers of the line (AgentsDismissalMatch.awk, AgentsEscalationVerdict.awk) -- never the assertion" >&2
	exit 1
fi
printf 'SLACK_HEADER_INVITED_MEMBER: OK (%d assertions, offline)\n' "$rigPasses"
