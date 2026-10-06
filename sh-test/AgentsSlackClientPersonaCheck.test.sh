#!/usr/bin/env bash
## Behavioural check on what a member presents in Slack and on the agents registries that hold it, run rather than read,
## against a scenario workspace and a fixture skillset built here. Held: --make-agents-indices writes, in
## $MMDAPP/.local/agents, exactly two registries for the members that have a path in THIS workspace: team-members
## (member workspace link-kind path) and team-members-names (member mark first family alias). The names are each
## member's SKILL.md frontmatter (first-name, family-name, alias), replaced by its scope key (FIRST_NAME, FAMILY_NAME,
## ALIAS) at build time, the mark is read from its basic.md; a value that is missing, `not decided yet`, quoted or not
## storable is `-` and warned about unless the member is reference-only. A send reads team-members-names and nothing
## else: an edit to the registry is followed, an edit to SKILL.md, scope or basic.md is not until the next build, and
## unreadable skill and config files change nothing. A client's EXTERNAL presentation, its own user token or its own
## bot token with no relay, is its OWN row (mark, first and family name, alias), with no client identifier in the payload
## and no metadata; a client without a complete row refuses with nothing posted. A sender with no row, or no alias,
## shows its member name; an addressee whose directory is missing refuses, one whose directory exists but has no row is
## plain @<member>. Also held: a localised name byte for byte, the in-body mention rules, no identity swap to the shared
## bot for an external send, the two call places of the build and its help pair. A fake `curl` first on PATH logs each
## method with its token and the posted bodies; every token is a literal. Offline by construction. What the stubs
## cannot show: how real Slack renders any of it, and the real skillset's own frontmatter and installer index.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigPackage="${rigHere%/sh-lib}"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigInclude="$rigHere/AgentsTools.MemberCommsSlack.include"
rigRegInclude="$rigHere/AgentsTools.Registries.include"
rigPersona="magic-coordinator"
rigOpName="--make-agents-indices"
rigBuilderName="1201-agents-indices.sh"
rigNamesName="team-members-names"
rigMembersName="team-members"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigInclude" ] || rigRefuse "the Slack include is not at: $rigInclude"
[ -f "$rigRegInclude" ] || rigRefuse "the registries include is not at: $rigRegInclude"
rigTmp="$( mktemp -d -t AgentsSlackClientPersonaCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigSkills="$rigTmp/skills" ; rigHome="$rigTmp/home"
rigWsName="${rigWs##*/}"
rigAgentsDir="$rigWs/.local/agents"
rigNamesFile="$rigAgentsDir/$rigNamesName.registry"
rigMembersFile="$rigAgentsDir/$rigMembersName.registry"
rigLinkedFile="$rigSkills/.linked.magic-team.members.txt"
mkdir -p "$rigTmp/bin" "$rigHome"
cp "$rigTest/check-fixtures/slack-client-persona-check.curl.test.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigTest/check-fixtures/slack-client-persona-check.curl.test.sh"
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

## The fixture skillset. A member's basic.md carries its mark, and a decoy Name and Alias that no output may show.
rigBasic(){ ## member, lines... -- that member's .basic.md
	local basicMember="$1" ; shift
	mkdir -p "$rigSkills/$basicMember"
	{ printf -- '---\nmaintainers: rig\n---\n' ; printf '%s\n' "$@" ; } > "$rigSkills/$basicMember/$basicMember.basic.md"
}
rigSkill(){ ## member, status, first-name, family-name, alias -- that member's SKILL.md frontmatter, a key left out when its value is empty
	mkdir -p "$rigSkills/$1"
	{
		printf -- '---\nname: %s\n' "$1"
		[ -z "$2" ] || printf 'status: %s\n' "$2"
		[ -z "$3" ] || printf 'first-name: %s\n' "$3"
		[ -z "$4" ] || printf 'family-name: %s\n' "$4"
		[ -z "$5" ] || printf 'alias: %s\n' "$5"
		printf -- 'description: rig\n---\n\n# %s\n' "$1"
	} > "$rigSkills/$1/SKILL.md"
}
rigLinkAdd(){ ## member, workspace, path -- one line of the installer's linked-members index: member:workspace:link-kind:path
	printf '%s:%s:source-symlink:%s\n' "$1" "$2" "${3:-myx/pkg/skillset/$1}" >> "$rigLinkedFile"
}
rigLinkDrop(){ ## member -- every line of that member out of the linked-members index
	LC_ALL=C grep -v "^$1:" "$rigLinkedFile" > "$rigLinkedFile.next" ; mv "$rigLinkedFile.next" "$rigLinkedFile"
}
rigBuild(){ ## options... -- the registries build in the rig workspace; rc in rigBuildRc, stdout in $rigTmp/build.out, stderr in $rigTmp/build.err
	rigBuildRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash "$rigTool" "$rigOpName" "$@" ) > "$rigTmp/build.out" 2> "$rigTmp/build.err" < /dev/null || rigBuildRc=$?
}
rigWorld(){ ## -- a fresh workspace and skillset with the default tokens, members, linked-members index and registries built
	rm -rf "$rigWs" "$rigSkills"
	mkdir -p "$rigWs/.local/.agents" "$rigSkills"
	rigBasic "$rigPersona" '- **Name**: Bullet Name.' '- **Alias**: `bulletalias`.' '- **Unicode character**: 🐭'
	rigSkill "$rigPersona" active Magic Vane dispatchr
	rigBasic client-ndm '- **Name**: Bullet Client.' '- **Alias**: `bulletclient`.' '- **Unicode character**: 🐭'
	rigSkill client-ndm active Magic Vane dispatchr
	rigBasic client-mel '- **Unicode character**: 🐭'
	rigSkill client-mel active Magic Vane dispatchr
	rigBasic magic-team '# the team, no mark of its own'
	rigBasic keeper-myx '- **Name**: Bullet Smith.' '- **Alias**: `bulletsmith`.' '- **Unicode character**: 🔧'
	rigSkill keeper-myx active Forge Keeper forge
	: > "$rigLinkedFile"
	rigLinkAdd "$rigPersona" "$rigWsName" ; rigLinkAdd client-ndm "$rigWsName" ; rigLinkAdd client-mel "$rigWsName" ; rigLinkAdd keeper-myx "$rigWsName"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-COORD\n' > "$rigWs/.local/.agents/$rigPersona.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-NDM\n' > "$rigWs/.local/.agents/client-ndm.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-MEL\nSLACK_BOT_TOKEN=rig-bot-token-MEL\n' > "$rigWs/.local/.agents/client-mel.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-KEEPER\n' > "$rigWs/.local/.agents/keeper-myx.agent.env"
	: > "$rigTmp/post-answers"
	rigBuild
}
rigWorldPlain(){ ## -- the default world and one more member with no Slack token of its own
	rigWorld
	rigBasic keeper-plain '- **Unicode character**: 🔨'
	rigSkill keeper-plain active Plain Keeper plainalias
	rigLinkAdd keeper-plain "$rigWsName"
	rigBuild
}
rigScopeRaw(){ ## member, KEY=value lines... -- appended to that member's scope file, no rebuild
	local scopeMember="$1" ; shift
	printf '%s\n' "$@" >> "$rigWs/.local/.agents/$scopeMember.agent.env"
}
rigScope(){ ## member, KEY=value lines... -- the same, then the registries are rebuilt
	rigScopeRaw "$@"
	rigBuild
}
rigIndexRow(){ ## member -- that member's row of team-members-names, fields joined by |
	LC_ALL=C awk -v OFS='|' -v who="$1" '$1 == who { $1 = $1 ; print }' "$rigNamesFile" 2> /dev/null
}
rigDashes(){ ## member -- how many of its first, family and alias fields are -
	LC_ALL=C awk -v who="$1" '$1 == who { for ( i = 3 ; i <= 5 ; i++ ) { if ( $i == "-" ) { n++ ; } } } END { print n + 0 }' "$rigNamesFile" 2> /dev/null
}
rigIndexSet(){ ## member, field number (2 mark, 3 first, 4 family, 5 alias), value -- one field of team-members-names edited by hand
	LC_ALL=C awk -v who="$1" -v col="$2" -v val="$3" '$1 == who { $col = val } { print }' "$rigNamesFile" > "$rigNamesFile.hand" && mv "$rigNamesFile.hand" "$rigNamesFile"
}
rigSend(){ ## member, target, send options... -- one send; rc in rigRc, stderr in $rigTmp/err, calls and bodies of this send alone
	: > "$rigTmp/calls" ; rm -f "$rigTmp/bodies" ; touch "$rigTmp/bodies"
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" RIG_SCENARIO="$rigTmp" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash "$rigTool" --member-comms-slack-send-message "$1" "$2" "${@:3}" RIG-BODY ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigSendBody(){ ## member, target, body, send options... -- the same with a body of its own
	: > "$rigTmp/calls" ; rm -f "$rigTmp/bodies" ; touch "$rigTmp/bodies"
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" RIG_SCENARIO="$rigTmp" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash "$rigTool" --member-comms-slack-send-message "$1" "$2" "${@:4}" "$3" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigN(){ ## file, fixed text -- how many lines hold it
	LC_ALL=C grep -c -F -- "$2" "$1" 2> /dev/null || :
}
rigBodyHas(){ ## fixed text -- how many posted bodies hold it
	rigN "$rigTmp/bodies" "$1"
}
rigText(){ ## -- the text field of the first posted body, escapes as sent
	LC_ALL=C sed -n '1s/^{"channel":"[^"]*","text":"//; 1s/","blocks":.*//; 1s/"}$//; 1p' "$rigTmp/bodies"
}
rigPosts(){ ## -- how many chat.postMessage calls this send made
	LC_ALL=C grep -c '^chat.postMessage ' "$rigTmp/calls" || :
}
rigPostToken(){ ## -- the token of the first chat.postMessage
	LC_ALL=C awk '$1 == "chat.postMessage" { print $2 ; exit }' "$rigTmp/calls"
}
rigNoCalls(){ ## -- how many Slack calls the last send made
	LC_ALL=C awk 'END { print NR }' "$rigTmp/calls"
}
rigNoBodies(){ ## -- how many bodies the last send posted
	LC_ALL=C awk 'END { print NR }' "$rigTmp/bodies"
}
rigLines(){ ## file -- how many lines it has
	LC_ALL=C awk 'END { print NR + 0 }' "$1" 2> /dev/null
}

rigWorld
[ "$rigBuildRc" = 0 ] && [ -f "$rigNamesFile" ] || rigRefuse "the baseline build made no $rigNamesName registry at $rigNamesFile, so no row below would be measured: $( LC_ALL=C grep -m1 ERROR "$rigTmp/build.err" )"
rigSend keeper-myx magic-team
[ "$rigRc" = 0 ] && [ "$( rigPosts )" = 1 ] || rigRefuse "the baseline send reached no post, so no row below would be measured: $( LC_ALL=C grep -m1 ERROR "$rigTmp/err" )"

echo "-- 1. a client's own user token: the external presentation is its own row --"
rigSend client-ndm magic-team
rigAssert "the send is posted under the client's own user token"          "$rigRc $( rigPostToken )" "0 rig-user-token-NDM"
rigAssert "the text is the header from the client's row: mark, name and alias" "$( rigText )" '🐭 *_Magic Vane_* @dispatchr → @here.\nRIG-BODY'
rigAssert "the blocks carry the mark, the name in bold italic, and the alias" "$( rigBodyHas '{"type":"text","text":"🐭 "},{"type":"text","text":"Magic Vane","style":{"bold":true,"italic":true}},{"type":"text","text":" @dispatchr "}' )" 1
rigAssert "no client identifier anywhere in the posted payload"            "$( rigBodyHas 'client-ndm' )" 0
rigAssert "and no metadata key at all"                                     "$( rigBodyHas '"metadata"' )" 0
rigAssert "and no decoy bullet value from its basic.md"                    "$( rigBodyHas 'Bullet' ) $( rigBodyHas 'bullet' )" "0 0"
rigSend client-ndm human-owner
rigAssert "to the human-owner, with its own token: the same header, no relay" "$( rigText ) $( rigN "$rigTmp/err" 'has no SLACK_USER_TOKEN of its own' )" '🐭 *_Magic Vane_* @dispatchr → <@URIGOWNER>.\nRIG-BODY 0'
rigSend keeper-myx magic-team
rigAssert "control: a non-client member's header is its own row alias and mark, with its member name" "$( rigText )" '🔧 *_keeper-myx_* @forge → @here.\nRIG-BODY'
rigAssert "control: no decoy bullet value there either"                    "$( rigBodyHas 'Bullet' ) $( rigBodyHas 'bullet' )" "0 0"

echo "-- 2. a client's own bot token with --identity-bot: external too --"
rigSend client-mel magic-team --identity-bot
rigAssert "posted under the client's own bot token"                        "$rigRc $( rigPostToken )" "0 rig-bot-token-MEL"
rigAssert "the text is the header from the client's row"                   "$( rigText )" '🐭 *_Magic Vane_* @dispatchr → @here.\nRIG-BODY'
rigAssert "no client identifier and no metadata in the payload"            "$( rigBodyHas 'client-mel' ) $( rigBodyHas '"metadata"' )" "0 0"

echo "-- 3. --identity-bot with only the shared team bot token: internal --"
rigSend client-ndm magic-team --identity-bot
rigAssert "posted under the shared bot token"                              "$rigRc $( rigPostToken )" "0 rig-bot-token-TEAM"
rigAssert "the header keeps the member name, with the alias and mark of its row" "$( rigText )" '🐭 *_client-ndm_* @dispatchr → @here.\nRIG-BODY'
rigAssert "the row's names are absent, and the default metadata is present" "$( rigBodyHas 'Magic Vane' ) $( rigBodyHas '"metadata"' )" "0 1"
rigAssert "control: the same payload check does find the client identifier here" "$( rigBodyHas 'client-ndm' )" 1

echo "-- 4. a client without a user token sending to the human-owner, relayed under another member's token: internal --"
rm -f "$rigWs/.local/.agents/client-mel.agent.env"
rigSend client-mel human-owner
rigAssert "posted under the relay target's user token"                     "$rigRc $( rigPostToken )" "0 rig-user-token-COORD"
rigAssert "the header names the client, not its row names"                 "$( rigText ) $( rigBodyHas 'Magic Vane' )" '🐭 *_client-mel_* @dispatchr → <@URIGOWNER>.\nRIG-BODY 0'
rigAssert "the existing relay warning is unchanged"                        "$( rigN "$rigTmp/err" "🙋 WARNING: DistroAgentsTools --member-comms-slack-send-message: 'client-mel' has no SLACK_USER_TOKEN of its own, so this human-owner send goes out under magic-coordinator's user account, with 'client-mel' named in the message header -- pass --identity-bot to send as the team bot instead" )" 1
rigWorld

echo "-- 5. other members: the header is its row alias and mark, or its member name --"
rigSend keeper-myx magic-team
rigAssert "a member with its own token and row"                            "$( rigText )" '🔧 *_keeper-myx_* @forge → @here.\nRIG-BODY'
rigSend keeper-myx magic-team --identity-bot
rigAssert "the same member as the shared bot"                              "$( rigText )" '🔧 *_keeper-myx_* @forge → @here.\nRIG-BODY'
rigSend magic-team magic-team --identity-bot
rigAssert "the team member with a directory and no row: its own name as mark-less alias" "$( rigText )" '*_magic-team_* @magic-team → @here.\nRIG-BODY'

echo "-- 6. a client without a complete row refuses an external send: nothing posted, no fallback --"
rigRefusal(){ ## label, the keys the message must name as missing
	rigSend client-ndm magic-team
	rigAssert "$1: exit 1, an error naming the client, the SKILL.md and the registry, missing $2, ending nothing was sent" "$rigRc $( LC_ALL=C grep -c -F -- "⛔ ERROR: DistroAgentsTools --member-comms-slack-send-message: the external presentation of 'client-ndm' needs first-name, family-name and alias in its SKILL.md and in the team-members-names registry: missing $2; nothing was sent" "$rigTmp/err" || : )" "1 1"
	rigAssert "$1: the curl stub was never called"                         "$( rigNoCalls )" 0
	rigAssert "$1: no body was posted, so nothing fell back to another name" "$( rigNoBodies )" 0
	rigSend client-ndm magic-team --identity-bot
	rigAssert "$1: sibling, the same client as the shared bot (internal) still sends" "$rigRc $( rigPosts ) $( rigBodyHas '*_client-ndm_*' )" '0 1 1'
}
rigWorld ; rm -f "$rigNamesFile"
rigRefusal "no registry file at all" "first-name, family-name, alias"
rigWorld ; rigLinkDrop client-ndm ; rigBuild
rigRefusal "the client has no path in this workspace, so no row" "first-name, family-name, alias"
rigWorld ; rm -f "$rigSkills/client-ndm/SKILL.md" ; rigBuild
rigAssert "a linked member with no SKILL.md gets a row of dashes and one warning per field" "$( rigIndexRow client-ndm ) $( rigN "$rigTmp/build.err" 'member client-ndm: required field' )" "client-ndm|🐭|-|-|- 3"
rigRefusal "no SKILL.md for the client" "first-name, family-name, alias"
rigWorld ; rigSkill client-ndm active '' '' '' ; rigBuild
rigRefusal "a SKILL.md with none of the three" "first-name, family-name, alias"
rigWorld ; rigSkill client-ndm active '' Vane dispatchr ; rigBuild
rigRefusal "first-name missing" "first-name"
rigWorld ; rigSkill client-ndm active Magic '' dispatchr ; rigBuild
rigRefusal "family-name missing" "family-name"
rigWorld ; rigSkill client-ndm active Magic Vane '' ; rigBuild
rigRefusal "alias missing" "alias"
rigWorld ; rigSkill client-ndm active 'not decided yet' Vane dispatchr ; rigBuild
rigRefusal "first-name is not decided yet" "first-name"
rigWorld ; rigSkill client-ndm active Magic 'not decided yet' dispatchr ; rigBuild
rigRefusal "family-name is not decided yet" "family-name"
rigWorld ; rigSkill client-ndm active Magic Vane 'not decided yet' ; rigBuild
rigRefusal "alias is not decided yet" "alias"
rigWorld ; rigSkill client-ndm active 'Ma"gic' Vane dispatchr ; rigBuild
rigRefusal "first-name with a double quote" "first-name"
rigWorld ; rigSkill client-ndm active Magic 'Va\ne' dispatchr ; rigBuild
rigRefusal "family-name with a backslash" "family-name"
rigWorld ; rigSkill client-ndm active "Ma$( printf '\001' )gic" Vane dispatchr ; rigBuild
rigRefusal "first-name with a control byte" "first-name"
rigWorld ; rigSkill client-ndm active Magic "Va$( printf '\302\205' )ne" dispatchr ; rigBuild
rigRefusal "family-name with a C1 control (U+0085)" "family-name"
rigWorld ; rigSkill client-ndm active '"Magic"' Vane dispatchr ; rigBuild
rigRefusal "first-name written in double quotes" "first-name"
rigWorld ; rigSkill client-ndm active Magic "'Vane'" dispatchr ; rigBuild
rigRefusal "family-name written in single quotes" "family-name"
rigWorld ; rigSkill client-ndm active 'Ma_gic' Vane dispatchr ; rigBuild
rigRefusal "first-name holding an underscore" "first-name"
rigWorld ; rigSkill client-ndm active Magic 'Va_ne' dispatchr ; rigBuild
rigRefusal "family-name holding an underscore" "family-name"
rigWorld ; rigSkill client-ndm active Magic Vane 'bad!' ; rigBuild
rigRefusal "alias that is no handle" "alias"
rigWorld ; rigSkill client-ndm active Magic Vane 'bad alias' ; rigBuild
rigRefusal "alias with a space" "alias"
rigWorld ; rigSkill client-ndm active Magic Vane '-dash' ; rigBuild
rigRefusal "alias starting with a dash" "alias"
rigWorld ; rigSkill client-ndm reference-only Magic Vane '' ; rigBuild
rigAssert "a reference-only client is exempt from the build warnings, not from the refusal" "$( LC_ALL=C grep -c 'WARNING' "$rigTmp/build.err" || : )" 0
rigRefusal "reference-only client with no alias" "alias"
rigWorld ; rm -f "$rigSkills/$rigPersona/SKILL.md" "$rigSkills/$rigPersona/$rigPersona.basic.md" ; rigBuild
rigSend client-ndm magic-team
rigAssert "control: the persona member's own files are not consulted: with none, the client's external send is unchanged" "$rigRc $( rigText )" '0 🐭 *_Magic Vane_* @dispatchr → @here.\nRIG-BODY'
rigWorld

echo "-- 7. a localised or multi-word name passes byte for byte --"
for rigPair in "Zauberer|Müller" "Магия|Вейн" "Magic|D'Vane" "Magic|© Vane" "Ünal|Ø" "Mary Ann|van der Berg" ; do
	rigFirst="${rigPair%%|*}" ; rigFamily="${rigPair#*|}"
	rigWorld ; rigSkill client-ndm active "$rigFirst" "$rigFamily" dispatchr ; rigBuild
	rigSend client-ndm magic-team
	rigAssert "$rigFirst $rigFamily: in the text, exactly"                 "$rigRc $( rigText )" "0 🐭 *_${rigFirst} ${rigFamily}_* @dispatchr → @here.\\nRIG-BODY"
	rigAssert "$rigFirst $rigFamily: in the blocks, exactly"               "$( rigBodyHas "{\"type\":\"text\",\"text\":\"$rigFirst $rigFamily\",\"style\":{\"bold\":true,\"italic\":true}}" )" 1
done
rigWorld ; rigSkill client-ndm active "Mary Ann" "van der Berg" dispatchr ; rigBuild
rigAssert "a name with spaces is stored with underscores, one column each" "$( rigIndexRow client-ndm )" 'client-ndm|🐭|Mary_Ann|van_der_Berg|dispatchr'
rigWorld

echo "-- 8. the addressee of an external send --"
rigSend client-ndm magic-team --address-to client-ndm
rigAssert "to itself: its own header and a real mention of the account that posts" "$( rigText )" '🐭 *_Magic Vane_* @dispatchr → 🐭 *_Magic Vane_* <@URIGNDM>.\nRIG-BODY'
rigAssert "and the blocks hold the user element for that id"               "$( rigBodyHas '{"type":"user","user_id":"URIGNDM"}' ) $( rigBodyHas 'client-ndm' )" "1 0"
rigSend client-ndm magic-team --address-to client-mel
rigAssert "to another client with a complete row: its row, the plain alias, no mention id" "$( rigText ) $( rigN "$rigTmp/bodies" '<@' ) $( rigBodyHas '"type":"user"' )" '🐭 *_Magic Vane_* @dispatchr → 🐭 *_Magic Vane_* @dispatchr.\nRIG-BODY 0 0'
rigAssert "and no client identifier"                                       "$( rigBodyHas 'client-mel' ) $( rigBodyHas 'client-ndm' )" "0 0"
rigSend client-ndm magic-team --address-to keeper-myx
rigAssert "to a non-client member: its own header and its mention"         "$( rigText )" '🐭 *_Magic Vane_* @dispatchr → 🔧 *_keeper-myx_* <@URIGKEEPER>.\nRIG-BODY'
rigSend keeper-myx magic-team --address-to client-ndm
rigAssert "in our workspace, addressing a client: its member name, its row alias, no mention" "$( rigText ) $( rigBodyHas '"type":"user"' )" '🔧 *_keeper-myx_* @forge → 🐭 *_client-ndm_* @dispatchr.\nRIG-BODY 0'

echo "-- 9. an @name in the body --"
rigSendBody client-ndm magic-team "ping @client-ndm and @client-mel"
rigAssert "external self-send: the sender's own name maps to its id, the other client stays literal" "$( rigBodyHas '{"type":"user","user_id":"URIGNDM"}' ) $( rigBodyHas '@client-mel' )" "1 1"
rigSendBody keeper-myx magic-team "ping @client-ndm and @client-mel"
rigAssert "internal send: neither client maps to a mention"                "$( rigBodyHas '"type":"user"' ) $( rigBodyHas '@client-ndm' )" "0 1"

echo "-- 10. the identity swap --"
printf 'channel_not_found\nok\n' > "$rigTmp/post-answers"
rigSend client-ndm magic-team
rigAssert "external send from a user token meeting channel_not_found: one post only, and the send fails" "$( rigPosts ) $( [ "$rigRc" -ne 0 ] && printf failed || printf sent )" "1 failed"
rigAssert "no post was made under the shared bot token"                    "$( LC_ALL=C grep -c 'chat.postMessage rig-bot-token-TEAM' "$rigTmp/calls" || : )" 0
printf 'channel_not_found\nok\n' > "$rigTmp/post-answers"
rigSend keeper-myx magic-team
rigAssert "control: an internal send retries once under the shared bot and succeeds" "$( rigPosts ) $rigRc $( LC_ALL=C awk '$1 == "chat.postMessage" { printf "%s ", $2 }' "$rigTmp/calls" )" "2 0 rig-user-token-KEEPER rig-bot-token-TEAM "
printf 'channel_not_found\nok\n' > "$rigTmp/post-answers"
rigSend client-mel magic-team
rigAssert "an external send whose client has its own bot token may swap to that one, with the same payload" "$( rigPosts ) $rigRc $( LC_ALL=C awk '$1 == "chat.postMessage" { printf "%s ", $2 }' "$rigTmp/calls" ) $( rigBodyHas 'Magic Vane' ) $( rigBodyHas 'client-mel' )" "2 0 rig-user-token-MEL rig-bot-token-MEL  2 0"
: > "$rigTmp/post-answers"

echo "-- 11. a client reads its own row, no other member's --"
rigWorld ; rigBasic client-mel '- **Unicode character**: 🦊' ; rigSkill client-ndm active Iris Marsh imarsh ; rigSkill client-mel active Mira Hale mhale ; rigBuild
rigSend client-ndm magic-team
rigAssert "the external header is the client's own row, not the persona member's" "$( rigText ) $( rigBodyHas 'Magic Vane' ) $( rigBodyHas 'dispatchr' )" '🐭 *_Iris Marsh_* @imarsh → @here.\nRIG-BODY 0 0'
rigSend client-mel magic-team
rigAssert "another client reads its own"                                   "$( rigText )" '🦊 *_Mira Hale_* @mhale → @here.\nRIG-BODY'
rigSend client-ndm magic-team --address-to client-mel
rigAssert "an addressee client with a complete row reads under its own mark, names and alias" "$( rigText )" '🐭 *_Iris Marsh_* @imarsh → 🦊 *_Mira Hale_* @mhale.\nRIG-BODY'
rigSend client-ndm magic-team --address-to client-ndm
rigAssert "itself: its own row and its real mention"                       "$( rigText )" '🐭 *_Iris Marsh_* @imarsh → 🐭 *_Iris Marsh_* <@URIGNDM>.\nRIG-BODY'
rigSkill client-mel active Mira Hale '' ; rigBuild
rigSend client-ndm magic-team --address-to client-mel
rigAssert "an addressee client whose row lacks the alias reads under the sender's external mark, names and alias" "$( rigText ) $( rigBodyHas 'Mira' ) $( rigBodyHas 'client-mel' )" '🐭 *_Iris Marsh_* @imarsh → 🐭 *_Iris Marsh_* @imarsh.\nRIG-BODY 0 0'
rigLinkDrop client-mel ; rigBuild
rigSend client-ndm magic-team --address-to client-mel
rigAssert "an addressee client with no row at all reads the same"          "$( rigText ) $( rigBodyHas 'client-mel' )" '🐭 *_Iris Marsh_* @imarsh → 🐭 *_Iris Marsh_* @imarsh.\nRIG-BODY 0'
rigSend client-ndm magic-team --identity-bot
rigAssert "control: the same sender as the shared bot (internal) is its member name with its row alias" "$( rigText )" '🐭 *_client-ndm_* @imarsh → @here.\nRIG-BODY'
rigWorld

echo "-- 12. the addressee: a missing directory refuses, a directory with no row is plain --"
rigWorldPlain
rigSend keeper-myx magic-team --address-to keeper-ghost
rigAssert "no skill directory: exit 1, no such team member, the path expected, nothing sent" "$rigRc $( LC_ALL=C grep -c -F -- "⛔ ERROR: DistroAgentsTools --member-comms-slack-send-message: --address-to 'keeper-ghost': no such team member -- expected $rigSkills/keeper-ghost" "$rigTmp/err" || : ) $( rigNoCalls ) $( rigNoBodies )" "1 1 0 0"
rigAssert "and the message names nothing registry-related"                 "$( LC_ALL=C grep -c -i 'registry' "$rigTmp/err" || : )" 0
rigSend client-ndm magic-team --address-to keeper-ghost
rigAssert "the same refusal in an external send"                           "$rigRc $( LC_ALL=C grep -c -F -- "'keeper-ghost': no such team member" "$rigTmp/err" || : ) $( rigNoCalls )" "1 1 0"
mkdir -p "$rigSkills/keeper-bare"
rigSend keeper-myx magic-team --address-to keeper-bare
rigAssert "a directory with no row: plain @member, no mark, sent"          "$rigRc $( rigPosts ) $( rigText )" '0 1 🔧 *_keeper-myx_* @forge → *_keeper-bare_* @keeper-bare.\nRIG-BODY'
rigAssert "and no mention id, in the text or the blocks"                   "$( rigN "$rigTmp/bodies" '<@' ) $( rigBodyHas '"type":"user"' )" "0 0"
mkdir -p "$rigSkills/keeper-acct" ; printf 'SLACK_USER_TOKEN=rig-user-token-ACCT\n' > "$rigWs/.local/.agents/keeper-acct.agent.env"
rigSend keeper-myx magic-team --address-to keeper-acct
rigAssert "a directory with no row but a Slack account of its own: no mark, its member name, and its mention id all the same" "$rigRc $( rigText ) $( rigBodyHas '{"type":"user","user_id":"URIGACCT"}' )" '0 🔧 *_keeper-myx_* @forge → *_keeper-acct_* <@URIGACCT>.\nRIG-BODY 1'
rigSend keeper-myx magic-team --address-to keeper-myx
rigAssert "control: the same send to a member with a row and an account does mention it" "$( rigText ) $( rigBodyHas '{"type":"user","user_id":"URIGKEEPER"}' )" '🔧 *_keeper-myx_* @forge → 🔧 *_keeper-myx_* <@URIGKEEPER>.\nRIG-BODY 1'
rigSend keeper-myx magic-team --address-to magic-team
rigAssert "a directory holding only a basic.md has no row either: plain"   "$rigRc $( rigText )" '0 🔧 *_keeper-myx_* @forge → *_magic-team_* @magic-team.\nRIG-BODY'
rigSend client-ndm magic-team --address-to keeper-bare
rigAssert "in an external send: plain as well"                             "$rigRc $( rigText )" '0 🐭 *_Magic Vane_* @dispatchr → *_keeper-bare_* @keeper-bare.\nRIG-BODY'
rigSend keeper-myx magic-team --address-to keeper-plain
rigAssert "control: an addressee with a row, no Slack account: its mark and alias" "$( rigText )" '🔧 *_keeper-myx_* @forge → 🔨 *_keeper-plain_* @plainalias.\nRIG-BODY'
rigSend client-ndm magic-team --address-to keeper-myx
rigAssert "control: an addressee with a row and an account: its mention"   "$( rigText )" '🐭 *_Magic Vane_* @dispatchr → 🔧 *_keeper-myx_* <@URIGKEEPER>.\nRIG-BODY'
rm -f "$rigNamesFile"
rigSend keeper-myx magic-team --address-to keeper-plain
rigAssert "no registry file at all: the sender shows its member name, the addressee is plain, sent" "$rigRc $( rigPosts ) $( rigText )" '0 1 *_keeper-myx_* @keeper-myx → *_keeper-plain_* @keeper-plain.\nRIG-BODY'
rigAssert "and no mention id for an addressee with no Slack account"       "$( rigN "$rigTmp/bodies" '<@' ) $( rigBodyHas '"type":"user"' )" "0 0"
rigSend keeper-myx magic-team --address-to keeper-acct
rigAssert "with no registry file an addressee with an account still gets its mention id, as before the registry" "$rigRc $( rigText ) $( rigBodyHas '{"type":"user","user_id":"URIGACCT"}' )" '0 *_keeper-myx_* @keeper-myx → *_keeper-acct_* <@URIGACCT>.\nRIG-BODY 1'
rigSend keeper-myx magic-team --address-to client-ndm
rigAssert "a client addressee in an internal send with no registry: plain" "$rigRc $( rigText )" '0 *_keeper-myx_* @keeper-myx → *_client-ndm_* @client-ndm.\nRIG-BODY'
rigSend client-ndm magic-team
rigAssert "control: the external client send with no registry still refuses" "$rigRc $( rigNoCalls )" "1 0"
rigWorldPlain ; rigSkill keeper-plain active Plain Keeper '' ; rigSkill keeper-myx active Forge Keeper '' ; rigBuild
rigSend keeper-myx magic-team --address-to keeper-plain
rigAssert "a row with no alias, sender and addressee: the mark is kept, the member name is the alias" "$( rigText )" '🔧 *_keeper-myx_* @keeper-myx → 🔨 *_keeper-plain_* @keeper-plain.\nRIG-BODY'
rigWorldPlain

echo "-- 13. an edit shows in a send only through team-members-names --"
rigIndexSet keeper-myx 5 handed
rigSend keeper-myx magic-team
rigAssert "the registry edited by hand is followed: the alias"             "$( rigText )" '🔧 *_keeper-myx_* @handed → @here.\nRIG-BODY'
rigIndexSet keeper-myx 2 ':wrench:'
rigSend keeper-myx magic-team
rigAssert "the mark by hand: a shortcode is an emoji element"              "$( rigText ) $( rigBodyHas '{"type":"emoji","name":"wrench"}' )" ':wrench: *_keeper-myx_* @handed → @here.\nRIG-BODY 1'
rigIndexSet client-ndm 3 Hand
rigSend client-ndm magic-team
rigAssert "a client's first name by hand: its external header follows"     "$( rigText )" '🐭 *_Hand Vane_* @dispatchr → @here.\nRIG-BODY'
rigIndexSet client-ndm 4 Two_Words
rigSend client-ndm magic-team
rigAssert "an underscore in a name by hand reads back as a space"          "$( rigText )" '🐭 *_Hand Two Words_* @dispatchr → @here.\nRIG-BODY'
rigWorldPlain
rm -f "$rigMembersFile"
rigSend client-ndm magic-team
rigAssert "the team-members registry is not read by a send: deleting it changes nothing" "$rigRc $( rigText )" '0 🐭 *_Magic Vane_* @dispatchr → @here.\nRIG-BODY'
rigWorldPlain
rigSkill keeper-myx active Forge Keeper changed
rigSend keeper-myx magic-team
rigAssert "a SKILL.md edited without a rebuild is not followed"            "$( rigText )" '🔧 *_keeper-myx_* @forge → @here.\nRIG-BODY'
rigBuild
rigSend keeper-myx magic-team
rigAssert "control: after the build the same edit is followed"             "$( rigText )" '🔧 *_keeper-myx_* @changed → @here.\nRIG-BODY'
rigWorldPlain
rigScopeRaw keeper-myx ALIAS=scoped FIRST_NAME=Other
rigScopeRaw client-ndm FIRST_NAME=Alexa FAMILY_NAME=Quill ALIAS=aquill
rigSend keeper-myx magic-team
rigAssert "a scope edited without a rebuild is not followed: internal"     "$( rigText )" '🔧 *_keeper-myx_* @forge → @here.\nRIG-BODY'
rigSend client-ndm magic-team
rigAssert "and external"                                                   "$( rigText )" '🐭 *_Magic Vane_* @dispatchr → @here.\nRIG-BODY'
rigBuild
rigSend keeper-myx magic-team
rigAssert "control: after the build the scope alias is followed"           "$( rigText )" '🔧 *_keeper-myx_* @scoped → @here.\nRIG-BODY'
rigSend client-ndm magic-team
rigAssert "control: and the client's scope first and family name and alias" "$( rigText )" '🐭 *_Alexa Quill_* @aquill → @here.\nRIG-BODY'
rigWorldPlain
rigBasic keeper-myx '- **Unicode character**: 🪛'
rigSend keeper-myx magic-team
rigAssert "a basic.md mark edited without a rebuild is not followed"       "$( rigText )" '🔧 *_keeper-myx_* @forge → @here.\nRIG-BODY'
rigBuild
rigSend keeper-myx magic-team
rigAssert "control: after the build it is"                                 "$( rigText )" '🪛 *_keeper-myx_* @forge → @here.\nRIG-BODY'
rigWorldPlain
rm -f "$rigSkills/client-ndm/SKILL.md" "$rigSkills/client-ndm/client-ndm.basic.md" "$rigSkills/keeper-myx/SKILL.md" "$rigSkills/keeper-myx/keeper-myx.basic.md" "$rigLinkedFile"
rigSend client-ndm magic-team
rigAssert "the skill files and the linked-members index deleted after the build change nothing: external" "$rigRc $( rigText )" '0 🐭 *_Magic Vane_* @dispatchr → @here.\nRIG-BODY'
rigSend keeper-myx magic-team --address-to client-ndm
rigAssert "and internal"                                                   "$( rigText )" '🔧 *_keeper-myx_* @forge → 🐭 *_client-ndm_* @dispatchr.\nRIG-BODY'
rigWorldPlain ; rigScopeRaw keeper-plain ALIAS=scopedplain ; rigBuild
chmod 000 "$rigSkills"/*/SKILL.md "$rigSkills"/*/*.basic.md "$rigWs/.local/.agents/$rigPersona.agent.env" "$rigWs/.local/.agents/client-mel.agent.env" "$rigWs/.local/.agents/keeper-plain.agent.env" "$rigLinkedFile"
rigAssert "control: those files really are unreadable to this check"       "$( cat "$rigSkills/client-ndm/SKILL.md" 2> /dev/null | wc -c | tr -d ' ' ) $( cat "$rigSkills/client-ndm/client-ndm.basic.md" 2> /dev/null | wc -c | tr -d ' ' ) $( cat "$rigWs/.local/.agents/keeper-plain.agent.env" 2> /dev/null | wc -c | tr -d ' ' ) $( cat "$rigLinkedFile" 2> /dev/null | wc -c | tr -d ' ' )" "0 0 0 0"
rigSend client-ndm magic-team --address-to keeper-plain
rigAssert "unreadable skill, basic, scope and linked-index files change nothing: external" "$rigRc $( rigText )" '0 🐭 *_Magic Vane_* @dispatchr → 🔨 *_keeper-plain_* @scopedplain.\nRIG-BODY'
rigSend keeper-myx magic-team --address-to keeper-plain
rigAssert "and internal"                                                   "$rigRc $( rigText )" '0 🔧 *_keeper-myx_* @forge → 🔨 *_keeper-plain_* @scopedplain.\nRIG-BODY'
rigAssert "and no message names a skill file or a basic file as unreadable" "$( LC_ALL=C grep -c -E 'SKILL[.]md|[.]basic[.]md' "$rigTmp/err" || : )" 0
chmod 644 "$rigSkills"/*/SKILL.md "$rigSkills"/*/*.basic.md "$rigWs/.local/.agents/$rigPersona.agent.env" "$rigWs/.local/.agents/client-mel.agent.env" "$rigWs/.local/.agents/keeper-plain.agent.env" "$rigLinkedFile"
rigWorldPlain
rm -f "$rigSkills/keeper-myx/keeper-myx.basic.md" "$rigSkills/keeper-myx/SKILL.md"
rigSend client-ndm keeper-myx
rigAssert "a member target is a directory test: with no skill files of its own it is still that member's DM" "$rigRc $( rigPosts ) $( rigPostToken )" "0 1 rig-user-token-NDM"
rigWorld

echo "-- 14. the build output --"
rigWorld
rigBasic keeper-quoted '- **Slack shortcode**: :hammer:' '- **Unicode character**: 🔨'
rigSkill keeper-quoted active '"Zoe"' "'Marsh'" 'q.h'
rigSkill keeper-spaced active 'Mary Ann' 'van der Berg' 'spaced'
rigSkill keeper-undund active 'A_b' 'Cee' 'undund'
rigSkill keeper-aliasspace active 'Ada' 'Lee' 'bad alias'
rigSkill keeper-scopespace active 'Bea' 'Fox' 'scopey'
rigSkill keeper-undecided active 'not decided yet' Voss vossy
rigSkill keeper-badalias active Ira Dale 'bad!'
rigSkill keeper-ref reference-only 'not decided yet' '' 'bad!'
rigSkill keeper-nobasic active No Basic nobasic
rigBasic keeper-nofile '- **Unicode character**: 🔨'
rigBasic keeper-mixed '- **Unicode character**: 🔨'
rigSkill keeper-mixed active Mia '' ''
rigBasic keeper-notlinked '- **Unicode character**: 🔨'
rigSkill keeper-notlinked active Not Linked notlinked
for rigMember in keeper-quoted keeper-spaced keeper-undund keeper-aliasspace keeper-scopespace keeper-undecided keeper-badalias keeper-ref keeper-nobasic keeper-nofile keeper-mixed ; do rigLinkAdd "$rigMember" "$rigWsName" ; done
rigScopeRaw keeper-myx FIRST_NAME=Override
rigScopeRaw keeper-scopespace 'ALIAS=has space'
mkdir -p "$rigAgentsDir"
printf 'seed-sessions\n' > "$rigAgentsDir/spawned-sessions.registry" ; printf 'seed-replies\n' > "$rigAgentsDir/pending-replies.registry" ; printf 'seed-log\n' > "$rigAgentsDir/comms-slack-send.log"
rigSeedSum="$( cat "$rigAgentsDir/spawned-sessions.registry" "$rigAgentsDir/pending-replies.registry" "$rigAgentsDir/comms-slack-send.log" | cksum )"
rigBuild
rigAssert "the build exits 0 and prints nothing on stdout"                 "$rigBuildRc $( rigLines "$rigTmp/build.out" )" "0 0"
rigAssert "the build makes exactly the two registries and keeps the other files: the folder holds the two and the three seeded" "$( ls "$rigAgentsDir" | LC_ALL=C tr '\n' ' ' )" "comms-slack-send.log pending-replies.registry spawned-sessions.registry team-members-names.registry team-members.registry "
rigAssert "and the seeded files are untouched"                             "$( cat "$rigAgentsDir/spawned-sessions.registry" "$rigAgentsDir/pending-replies.registry" "$rigAgentsDir/comms-slack-send.log" | cksum )" "$rigSeedSum"
rigAssert "the file naming rule: both new registries are <name>.registry, the earlier presentation file name is not written" "$( [ -f "$rigAgentsDir/team-members.registry" ] && printf yes || printf no ) $( [ -f "$rigAgentsDir/team-members-names.registry" ] && printf yes || printf no ) $( [ -e "$rigAgentsDir/member-presentation.index" ] && printf yes || printf no ) $( [ -e "$rigAgentsDir/member-presentation.index.registry" ] && printf yes || printf no )" "yes yes no no"
rigAssert "a normal row: member, mark, first, family, alias"               "$( rigIndexRow client-ndm )" 'client-ndm|🐭|Magic|Vane|dispatchr'
rigAssert "the persona member's row is an ordinary row"                    "$( rigIndexRow "$rigPersona" )" "$rigPersona|🐭|Magic|Vane|dispatchr"
rigAssert "a scope FIRST_NAME replaces the frontmatter first-name at build" "$( rigIndexRow keeper-myx )" 'keeper-myx|🔧|Override|Keeper|forge'
rigAssert "a name with spaces is stored with underscores, no warning"      "$( rigIndexRow keeper-spaced ) $( rigN "$rigTmp/build.err" 'member keeper-spaced:' )" 'keeper-spaced|-|Mary_Ann|van_der_Berg|spaced 0'
rigAssert "a quoted first-name and family-name are stored -, the valid alias is kept; the mark is the shortcode" "$( rigIndexRow keeper-quoted )" 'keeper-quoted|:hammer:|-|-|q.h'
rigAssert "a first-name holding an underscore is stored -"                 "$( rigIndexRow keeper-undund )" 'keeper-undund|-|-|Cee|undund'
rigAssert "an alias with a space is stored - (the registry would have kept it as bad_alias)" "$( rigIndexRow keeper-aliasspace )" 'keeper-aliasspace|-|Ada|Lee|-'
rigAssert "a scope ALIAS with a space is stored - as well"                 "$( rigIndexRow keeper-scopespace )" 'keeper-scopespace|-|Bea|Fox|-'
rigAssert "not decided yet is stored -"                                    "$( rigIndexRow keeper-undecided )" 'keeper-undecided|-|-|Voss|vossy'
rigAssert "an alias that is no handle is stored -"                         "$( rigIndexRow keeper-badalias )" 'keeper-badalias|-|Ira|Dale|-'
rigAssert "a member with no basic.md has no mark: -"                       "$( rigIndexRow keeper-nobasic )" 'keeper-nobasic|-|No|Basic|nobasic'
rigAssert "a reference-only member: every bad value is -"                  "$( rigIndexRow keeper-ref )" 'keeper-ref|-|-|-|-'
rigAssert "a linked member with no SKILL.md: its mark from basic.md, three dashes" "$( rigIndexRow keeper-nofile )" 'keeper-nofile|🔨|-|-|-'
rigAssert "a member with a SKILL.md but no path in this workspace has no row in either file" "$( LC_ALL=C grep -c 'keeper-notlinked' "$rigNamesFile" "$rigMembersFile" | LC_ALL=C tr '\n' ' ' )" "$rigNamesFile:0 $rigMembersFile:0 "
rigAssert "the row count: one per member linked in this workspace, in both files" "$( rigLines "$rigNamesFile" ) $( rigLines "$rigMembersFile" )" "15 15"
rigAssert "every names row has exactly five whitespace-separated fields, no header" "$( LC_ALL=C awk 'NF != 5 { bad++ } END { print bad + 0 }' "$rigNamesFile" )" 0
rigAssert "every team-members row has exactly four"                        "$( LC_ALL=C awk 'NF != 4 { bad++ } END { print bad + 0 }' "$rigMembersFile" )" 0
rigAssert "a team-members row is member, workspace, link kind, path"       "$( LC_ALL=C grep '^client-ndm ' "$rigMembersFile" )" "client-ndm $rigWsName source-symlink myx/pkg/skillset/client-ndm"
rigAssert "the decoy bullet Names and Aliases are in no row"               "$( LC_ALL=C grep -c -i 'bullet' "$rigNamesFile" || : )" 0
rigAssert "the warnings are on stderr in the package style, twelve in all, and no error" "$( LC_ALL=C grep -c '^⚠️ WARNING: DistroAgentsTools --make-agents-indices: member ' "$rigTmp/build.err" || : ) $( LC_ALL=C grep -c 'ERROR: DistroAgentsTools' "$rigTmp/build.err" || : ) $( LC_ALL=C grep -c '🙋' "$rigTmp/build.err" || : )" "12 0 0"
rigAssert "every warning ends with the plain-value hint"                   "$( LC_ALL=C grep -c 'WARNING: .* is missing or not valid in its SKILL.md (the value must be an unquoted plain value)$' "$rigTmp/build.err" || : )" 12
rigAssert "undecided first-name warns"                                     "$( rigN "$rigTmp/build.err" "$rigOpName: member keeper-undecided: required field first-name is missing or not valid in its SKILL.md" )" 1
rigAssert "the bad alias, the spaced alias and the scope alias with a space warn"  "$( rigN "$rigTmp/build.err" "member keeper-badalias: required field alias" ) $( rigN "$rigTmp/build.err" "member keeper-aliasspace: required field alias" ) $( rigN "$rigTmp/build.err" "member keeper-scopespace: required field alias" )" "1 1 1"
rigAssert "the quoted names warn once each, the underscore name once"      "$( rigN "$rigTmp/build.err" "member keeper-quoted: required field first-name" ) $( rigN "$rigTmp/build.err" "member keeper-quoted: required field family-name" ) $( rigN "$rigTmp/build.err" "member keeper-undund: required field first-name" )" "1 1 1"
rigAssert "a member lacking family-name and alias warns for each"          "$( rigN "$rigTmp/build.err" "member keeper-mixed: required field family-name" ) $( rigN "$rigTmp/build.err" "member keeper-mixed: required field alias" )" "1 1"
rigAssert "a linked member with no SKILL.md warns for all three"           "$( rigN "$rigTmp/build.err" "member keeper-nofile: required field" )" 3
rigAssert "no warning for the reference-only member, the one with no mark, the spaced one, or the valid ones" "$( LC_ALL=C grep -c -E 'member (keeper-ref|keeper-nobasic|keeper-spaced|keeper-myx|client-ndm|client-mel|magic-coordinator):' "$rigTmp/build.err" || : )" 0
rigAssert "a note per file on stderr: the path and the row count"          "$( rigN "$rigTmp/build.err" "# DistroAgentsTools $rigOpName: wrote $rigMembersFile (15 rows)" ) $( rigN "$rigTmp/build.err" "# DistroAgentsTools $rigOpName: wrote $rigNamesFile (15 rows)" )" "1 1"
rigSum="$( cat "$rigMembersFile" "$rigNamesFile" | cksum )"
rigBuild extra
rigAssert "an extra argument is refused: exit 1, named, nothing on stdout" "$rigBuildRc $( rigN "$rigTmp/build.err" "$rigOpName takes no arguments, got: extra" ) $( rigLines "$rigTmp/build.out" )" "1 1 0"
rigAssert "and both registries are as they were"                           "$( cat "$rigMembersFile" "$rigNamesFile" | cksum )" "$rigSum"
rigLinkDrop keeper-quoted ; rigLinkDrop keeper-spaced
rigBuild
rigAssert "a rebuild is whole: a member that lost its path has no row in either file, the others stay" "$( rigIndexRow keeper-quoted )$( LC_ALL=C grep -c 'keeper-spaced' "$rigMembersFile" || : ) $( rigLines "$rigNamesFile" ) $( rigLines "$rigMembersFile" )" "0 13 13"
rigAssert "control: the same build prints no error and no leftover temporary file" "$rigBuildRc $( LC_ALL=C grep -c 'ERROR: DistroAgentsTools' "$rigTmp/build.err" || : ) $( ls "$rigAgentsDir" | LC_ALL=C awk 'END { print NR }' )" "0 0 5"
rm -rf "$rigAgentsDir" ; printf 'not a directory\n' > "$rigAgentsDir"
rigBuild
rigAssert "registries that cannot be written (the folder is a file): exit 1, each path named, nothing on stdout" "$rigBuildRc $( rigN "$rigTmp/build.err" "ERROR: DistroAgentsTools $rigOpName: could not write $rigMembersFile" ) $( rigN "$rigTmp/build.err" "ERROR: DistroAgentsTools $rigOpName: could not write $rigNamesFile" ) $( rigLines "$rigTmp/build.out" )" "1 1 1 0"
rm -f "$rigAgentsDir" ; mkdir -p "$rigAgentsDir" ; chmod 555 "$rigAgentsDir"
rigBuild
rigAssert "a folder that cannot be written into: exit 1, each path named"  "$rigBuildRc $( rigN "$rigTmp/build.err" "could not write $rigMembersFile" ) $( rigN "$rigTmp/build.err" "could not write $rigNamesFile" )" "1 1 1"
rigAssert "and it left no file"                                            "$( ls "$rigAgentsDir" | LC_ALL=C awk 'END { print NR }' )" 0
chmod 755 "$rigAgentsDir"
rigBuild
rigAssert "control: once writable the same build exits 0 and writes both"  "$rigBuildRc $( [ -s "$rigNamesFile" ] && printf written || printf missing ) $( [ -s "$rigMembersFile" ] && printf written || printf missing )" "0 written written"
rigWorld

echo "-- 15. the team-members registry holds this workspace's members only --"
rigWorld
rigSkill keeper-both active Both Member bothy
rigSkill keeper-away active Away Member awayy
rigSkill keeper-prefix active Pre Fix prefixy
rigSkill keeper-suffix active Suf Fix suffixy
rigLinkAdd keeper-both "$rigWsName" 'myx/here/skillset/keeper-both'
rigLinkAdd keeper-both other-ws 'OTHERPATH/keeper-both'
rigLinkAdd keeper-away other-ws 'OTHERPATH/keeper-away'
rigLinkAdd keeper-prefix "$rigWsName-x" 'OTHERPATH/keeper-prefix'
rigLinkAdd keeper-suffix "x$rigWsName" 'OTHERPATH/keeper-suffix'
printf '# a comment line\n\n' >> "$rigLinkedFile"
rigBuild
rigAssert "a member in this and another workspace has one row, with this workspace's path" "$( LC_ALL=C grep '^keeper-both ' "$rigMembersFile" )" "keeper-both $rigWsName source-symlink myx/here/skillset/keeper-both"
rigAssert "a member in another workspace only has no row in either file"   "$( LC_ALL=C grep -c 'keeper-away' "$rigMembersFile" "$rigNamesFile" | LC_ALL=C tr '\n' ' ' )" "$rigMembersFile:0 $rigNamesFile:0 "
rigAssert "a workspace whose name only starts or ends with this one's gets no row" "$( LC_ALL=C grep -c -E 'keeper-(prefix|suffix)' "$rigMembersFile" "$rigNamesFile" | LC_ALL=C tr '\n' ' ' )" "$rigMembersFile:0 $rigNamesFile:0 "
rigAssert "nothing in either file names the other workspace or a path of it" "$( LC_ALL=C grep -c -E 'OTHERPATH|other-ws' "$rigMembersFile" "$rigNamesFile" | LC_ALL=C tr '\n' ' ' )" "$rigMembersFile:0 $rigNamesFile:0 "
rigAssert "the names row of the shared member is there once"               "$( rigIndexRow keeper-both )" 'keeper-both|-|Both|Member|bothy'
rigAssert "the other members' rows are the four of the world and the one shared member, in both files" "$( rigLines "$rigMembersFile" ) $( rigLines "$rigNamesFile" )" "5 5"
rm -f "$rigLinkedFile"
rigBuild
rigAssert "with no linked-members index at all both registries are empty and the build succeeds" "$rigBuildRc $( rigLines "$rigMembersFile" ) $( rigLines "$rigNamesFile" ) $( [ -f "$rigMembersFile" ] && [ -f "$rigNamesFile" ] && printf files || printf missing )" "0 0 0 files"
rigWorld

echo "-- 16. a value in a scope that cannot be stored is -, warned about, and refuses an external send --"
rigScopeBad(){ ## label, member, KEY=value line, the frontmatter key named in the warning
	rigWorldPlain ; rigScopeRaw "$2" "$3" ; rigBuild
	rigAssert "$1: the field is - in the row and the build warns once, exit 0" "$rigBuildRc $( rigDashes "$2" ) $( rigN "$rigTmp/build.err" "member $2: required field $4 is missing or not valid in its SKILL.md" )" "0 1 1"
}
rigBadValues=( 'a"b' 'a\b' "a$( printf '\001' )b" "a$( printf '\302\205' )b" 'a_b' )
rigBadNames=( 'a double quote' 'a backslash' 'a control byte' 'a C1 control byte (C2 85)' 'an underscore' )
rigAt=0
for rigValue in "${rigBadValues[@]}" ; do
	rigScopeBad "FIRST_NAME with ${rigBadNames[$rigAt]}" client-ndm "FIRST_NAME=$rigValue" first-name
	rigSend client-ndm magic-team
	rigAssert "FIRST_NAME with ${rigBadNames[$rigAt]}: the external send refuses naming first-name, nothing sent" "$rigRc $( rigN "$rigTmp/err" "in its SKILL.md and in the team-members-names registry: missing first-name; nothing was sent" ) $( rigNoCalls ) $( rigNoBodies )" "1 1 0 0"
	rigAt=$(( rigAt + 1 ))
done
rigScopeBad "FAMILY_NAME with a quote" client-ndm 'FAMILY_NAME=Q"u' family-name
rigSend client-ndm magic-team
rigAssert "FAMILY_NAME with a quote: refuses, no fallback to the frontmatter value" "$rigRc $( rigN "$rigTmp/err" "missing family-name; nothing was sent" ) $( rigBodyHas 'Vane' )" "1 1 0"
rigScopeBad "ALIAS with a space" client-ndm 'ALIAS=a b' alias
rigScopeBad "ALIAS starting with a dash" client-ndm 'ALIAS=-dash' alias
rigScopeBad "ALIAS with a double quote" client-ndm 'ALIAS=a"b' alias
rigScopeBad "ALIAS with a slash" client-ndm 'ALIAS=a/b' alias
rigSend client-ndm magic-team
rigAssert "ALIAS with a slash: the external send refuses naming alias"     "$rigRc $( rigN "$rigTmp/err" "missing alias; nothing was sent" )" "1 1"
rigScopeBad "an ordinary member's ALIAS with a space" keeper-myx 'ALIAS=a b' alias
rigSend keeper-myx magic-team
rigAssert "an ordinary sender with an alias stored -: its member name, its mark, sent" "$rigRc $( rigText )" '0 🔧 *_keeper-myx_* @keeper-myx → @here.\nRIG-BODY'
rigWorldPlain ; rigScope client-ndm 'FIRST_NAME=' 'ALIAS='
rigAssert "sibling: an empty scope value is unset, the frontmatter applies, no warning" "$( rigIndexRow client-ndm ) $( LC_ALL=C grep -c 'WARNING' "$rigTmp/build.err" || : )" 'client-ndm|🐭|Magic|Vane|dispatchr 0'
rigSend client-ndm magic-team
rigAssert "sibling: and the external send goes out"                        "$rigRc $( rigText )" '0 🐭 *_Magic Vane_* @dispatchr → @here.\nRIG-BODY'
rigWorldPlain ; rigScope client-ndm FIRST_NAME=Alexa ALIAS=pr.manager
rigAssert "sibling: valid values are stored, no warning"                   "$( rigIndexRow client-ndm ) $( LC_ALL=C grep -c 'WARNING' "$rigTmp/build.err" || : )" 'client-ndm|🐭|Alexa|Vane|pr.manager 0'
rigSend client-ndm magic-team
rigAssert "sibling: and they are what the external send shows"             "$rigRc $( rigText )" '0 🐭 *_Alexa Vane_* @pr.manager → @here.\nRIG-BODY'
rigWorldPlain ; rigScope client-ndm 'FIRST_NAME=Mary Ann'
rigAssert "sibling: a scope first name with a space is valid, stored with an underscore" "$( rigIndexRow client-ndm ) $( LC_ALL=C grep -c 'WARNING' "$rigTmp/build.err" || : )" 'client-ndm|🐭|Mary_Ann|Vane|dispatchr 0'
rigSend client-ndm magic-team
rigAssert "sibling: and it reads back with the space"                      "$( rigText )" '🐭 *_Mary Ann Vane_* @dispatchr → @here.\nRIG-BODY'

echo "-- 17. scope keys at build: each replaces its own field only --"
rigWorldPlain ; rigScope client-ndm FIRST_NAME=Alexa FAMILY_NAME=Quill ALIAS=pr.manager
rigSend client-ndm magic-team
rigAssert "all three: the external header shows Alexa Quill and @pr.manager" "$rigRc $( rigText )" '0 🐭 *_Alexa Quill_* @pr.manager → @here.\nRIG-BODY'
rigAssert "the blocks carry the same, and no frontmatter value"            "$( rigBodyHas '"text":"Alexa Quill","style":{"bold":true,"italic":true}' ) $( rigBodyHas '" @pr.manager "' ) $( rigBodyHas 'Magic' ) $( rigBodyHas 'dispatchr' )" "1 1 0 0"
rigWorldPlain ; rigScope client-ndm FIRST_NAME=Alexa
rigSend client-ndm magic-team
rigAssert "FIRST_NAME alone: the family and alias come from the frontmatter" "$( rigText )" '🐭 *_Alexa Vane_* @dispatchr → @here.\nRIG-BODY'
rigWorldPlain ; rigScope client-ndm FAMILY_NAME=Quill
rigSend client-ndm magic-team
rigAssert "FAMILY_NAME alone: the first name and alias come from the frontmatter" "$( rigText )" '🐭 *_Magic Quill_* @dispatchr → @here.\nRIG-BODY'
rigWorldPlain ; rigScope client-ndm ALIAS=pr.manager
rigSend client-ndm magic-team
rigAssert "ALIAS alone changes the handle and keeps the names"             "$( rigText )" '🐭 *_Magic Vane_* @pr.manager → @here.\nRIG-BODY'
rigWorldPlain ; rigScope "$rigPersona" FIRST_NAME=Alexa FAMILY_NAME=Quill ALIAS=pr.manager
rigSend client-ndm magic-team
rigAssert "control: the persona member's own scope is no client's presentation" "$( rigText )" '🐭 *_Magic Vane_* @dispatchr → @here.\nRIG-BODY'
rigWorldPlain ; rigScope keeper-plain ALIAS=kplain ; rigScope keeper-myx ALIAS=kmyx
rigSend keeper-myx magic-team
rigAssert "an ordinary member's scope alias is its internal sender alias, the member name unchanged" "$( rigText )" '🔧 *_keeper-myx_* @kmyx → @here.\nRIG-BODY'
rigSend keeper-myx magic-team --address-to keeper-plain
rigAssert "an addressee with no Slack account shows its scope alias"       "$( rigText )" '🔧 *_keeper-myx_* @kmyx → 🔨 *_keeper-plain_* @kplain.\nRIG-BODY'
rigWorldPlain ; rigScope keeper-plain ALIAS=kplain
rigSend keeper-myx magic-team
rigAssert "control: another member's alias is untouched by it"             "$( rigText )" '🔧 *_keeper-myx_* @forge → @here.\nRIG-BODY'
rigWorldPlain
for rigName in "Zoë" "Борис" "Ünal" ; do
	rigScope client-ndm "FIRST_NAME=$rigName"
	rigSend client-ndm magic-team
	rigAssert "$rigName in FIRST_NAME: in the text, exactly"              "$rigRc $( rigText )" "0 🐭 *_$rigName Vane_* @dispatchr → @here.\\nRIG-BODY"
	rigAssert "$rigName in FIRST_NAME: in the blocks, exactly"            "$( rigBodyHas "\"text\":\"$rigName Vane\",\"style\":{\"bold\":true,\"italic\":true}" )" 1
done

echo "-- 18. static: the send reads team-members-names, the registries include reads the rest --"
rigNamers(){ ## file, pattern -- the functions holding a non-comment line that matches the pattern, one line, sorted
	LC_ALL=C awk -v pat="$2" '/^case "\$1" in/ { fn = "(send dispatcher arm)" } /^[A-Za-z0-9_]+\(\)[ \t]*\{/ { fn = $1 ; sub(/\(\).*/, "", fn) } $0 ~ pat && $0 !~ /^[ \t]*#/ && fn != "" { print fn }' "$1" | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' '
}
rigFnCut(){ ## file, function name -- that function's text, from its first line to its closing brace
	LC_ALL=C awk -v name="$2" 'index( $0, name "(){" ) == 1 { on = 1 } on { print } on && /^}/ { exit }' "$1"
}
rigAssert "the Slack include names no basic.md path in code"               "$( rigNamers "$rigInclude" '[.]basic[.]md' )" ""
rigAssert "the registries include names a basic.md path in the marks function only" "$( rigNamers "$rigRegInclude" '[.]basic[.]md' )" "AgentsToolsCommsSlackMemberMarks "
rigAssert "the registries include reads a member's scope in the names rows function only" "$( rigNamers "$rigRegInclude" '--member-config-option' )" "AgentsToolsRegistryTeamMembersNamesRows "
rigAssert "the Slack include names no presentation scope key at all"       "$( LC_ALL=C grep -c -E 'FIRST_NAME|FAMILY_NAME|--select[ \"]*ALIAS' "$rigInclude" || : )" 0
printf 'F(){\n\tx="$d/.basic.md"\n}\nG(){\n\ty="$d/.basic.md"\n}\n# the .basic.md again in a comment\n' > "$rigTmp/sample.include"
rigAssert "control: a sample with two functions naming a basic.md is caught, a comment is not" "$( rigNamers "$rigTmp/sample.include" '[.]basic[.]md' )" "F G "
rigReadFn="$( rigFnCut "$rigInclude" AgentsToolsCommsSlackMemberPresentation )"
rigAssert "control: the presentation function was cut out of the include"  "$( printf '%s\n' "$rigReadFn" | LC_ALL=C grep -c '^AgentsToolsCommsSlackMemberPresentation(){' || : )" 1
rigAssert "the presentation function names the names registry, once"       "$( printf '%s\n' "$rigReadFn" | LC_ALL=C grep -c "$rigNamesName" || : )" 1
rigAssert "and no skill file, basic file, scope file, linked index or config read" "$( printf '%s\n' "$rigReadFn" | LC_ALL=C grep -v '^[[:space:]]*#' | LC_ALL=C grep -c -E 'SKILL[.]md|basic[.]md|agent[.]env|config-option|--select|linked|team-members[.]|AgentsToolsRegistryTeamMembersRows' || : )" 0
rigAssert "control: the same pattern does find those in the names rows function" "$( [ "$( rigFnCut "$rigRegInclude" AgentsToolsRegistryTeamMembersNamesRows | LC_ALL=C grep -v '^[[:space:]]*#' | LC_ALL=C grep -c -E 'SKILL[.]md|config-option|--select' || : )" -gt 0 ] && printf found || printf blind )" found
rigAssert "the earlier index include, its file name, its functions and its builder are gone" "$( cat "$rigHere"/*.include | LC_ALL=C grep -c -E 'member-presentation|AgentsToolsMemberIndex|AgentsTools[.]MemberIndex|slackPersonaMember|AgentsToolsCommsSlackPersonaMarks|AgentsToolsCommsSlackMemberDefaults|AgentsToolsCommsSlackPresentationInvalid|AgentsToolsCommsSlackMemberName' || : ) $( [ -e "$rigHere/AgentsTools.MemberIndex.include" ] && printf present || printf absent ) $( [ -e "$rigHere/AgentsToolsCommsSlackMemberName.awk" ] && printf present || printf absent ) $( [ -e "$rigPackage/builders/source-prepare/1000-make-member-index.sh" ] && printf present || printf absent )" "0 absent absent absent"
rigAssert "control: the same read of all includes does find a function that is there" "$( cat "$rigHere"/*.include | LC_ALL=C grep -c -E 'AgentsToolsCommsSlackMemberPresentation|AgentsToolsRegistryAgentsIndicesBuild' | LC_ALL=C awk '{ print ( $1 > 0 ) ? "found" : "blind" }' )" found
rigAssert "the marks function is defined in the registries include, not the Slack include" "$( LC_ALL=C grep -c '^AgentsToolsCommsSlackMemberMarks(){' "$rigRegInclude" || : ) $( LC_ALL=C grep -c '^AgentsToolsCommsSlackMemberMarks(){' "$rigInclude" || : )" "1 0"
rigMarksFn="$( rigFnCut "$rigRegInclude" AgentsToolsCommsSlackMemberMarks )"
rigAssert "the marks function is byte for byte as recorded (cksum, bytes)" "$( printf '%s\n' "$rigMarksFn" | cksum )" "3049307218 255"
rigAssert "its awk is byte for byte as recorded"                           "$( cksum < "$rigHere/AgentsToolsCommsSlackMemberMarks.awk" )" "175965626 570"
rigAssert "control: another function text gives another checksum"          "$( [ "$( printf 'x\n' | cksum )" = "3049307218 255" ] && printf blind || printf notices )" notices
rigRegistryName(){ ## registry name -- the file name AgentsToolsRegistryFile gives it in the rig workspace
	( MMDAPP="$rigWs" ; . "$rigRegInclude" && AgentsToolsRegistryFile "$1" )
}
rigAssert "every registry name, the earlier three and the new two, gives <name>.registry" "$( for rigReg in team-members team-members-names spawned-sessions pending-replies ; do rigRegistryName "$rigReg" ; done | LC_ALL=C tr '\n' ' ' )" "$rigAgentsDir/team-members.registry $rigAgentsDir/team-members-names.registry $rigAgentsDir/spawned-sessions.registry $rigAgentsDir/pending-replies.registry "
rigAssert "control: a name is not used as given, whatever it holds"        "$( rigRegistryName member-presentation.index )" "$rigAgentsDir/member-presentation.index.registry"

echo "-- 19. the two call places of the build --"
rigBuilder="$rigPackage/builders/source-prepare/$rigBuilderName"
rigLocalTools="$MDLT_ORIGIN/myx/myx.distro-.local/sh-scripts/DistroLocalTools.fn.sh"
rigGuard='[ ! -f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" ] ||'
rigAssert "the builder is in builders/source-prepare of the agents package" "$( [ -f "$rigBuilder" ] && printf present || printf absent ) $( ls "$rigPackage/builders" )" "present source-prepare"
rigAssert "and nothing of it is under sh-lib"                              "$( [ -e "$rigHere/builders" ] && printf present || printf absent ) $( ls "$rigHere" | LC_ALL=C grep -c -F -- "$rigBuilderName" || : )" "absent 0"
rigAssert "the builder runs the build once, behind the guard that the agents script exists" "$( rigN "$rigBuilder" "$rigOpName" ) $( rigN "$rigBuilder" "$rigGuard" )" "1 1"
rigAssert "the builder's one command line is that guard and the build"     "$( LC_ALL=C grep -F -- "$rigOpName" "$rigBuilder" | LC_ALL=C grep -c -F -- "$rigGuard \"\$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh\" $rigOpName" || : )" 1
rigAssert "the install block of Update Local Tools has the build line once" "$( rigN "$rigLocalTools" "$rigOpName" )" 1
rigAssert "and it is guarded by the agents script existing"                "$( LC_ALL=C grep -F -- "$rigOpName" "$rigLocalTools" | LC_ALL=C grep -c -F -- "$rigGuard" || : )" 1
rigAssert "and it comes straight after the make-workspace-integrations line" "$( LC_ALL=C grep -F -B1 -- "$rigOpName" "$rigLocalTools" | LC_ALL=C grep -c -F -- 'DistroLocalTools --make-workspace-integrations' || : )" 1
rigAssert "control: a sample with the build line twice counts two"          "$( printf '%s\n%s\n' "x $rigOpName" "y $rigOpName" > "$rigTmp/sample.sh" ; rigN "$rigTmp/sample.sh" "$rigOpName" )" 2
rigRunBuilder(){ ## origin -- the builder run under that origin, the rig workspace as the workspace; rc in rigRc
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$1" MDLT_OPTION="--run-from-path $1" MDAT_SKILLSET_ROOT="$rigSkills" sh "$rigBuilder" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigWorld ; rm -f "$rigNamesFile" "$rigMembersFile"
rigRunBuilder "$MDLT_ORIGIN"
rigAssert "the builder, run, builds both registries"                       "$rigRc $( [ -s "$rigMembersFile" ] && printf written || printf missing ) $( [ -s "$rigNamesFile" ] && printf written || printf missing ) $( rigIndexRow client-ndm )" '0 written written client-ndm|🐭|Magic|Vane|dispatchr'
rm -f "$rigNamesFile" "$rigMembersFile" ; mkdir -p "$rigTmp/noorigin"
rigRunBuilder "$rigTmp/noorigin"
rigAssert "the builder with no agents script at the origin does nothing and succeeds" "$rigRc $( [ -e "$rigNamesFile" ] && printf written || printf none ) $( LC_ALL=C grep -c 'ERROR' "$rigTmp/err" || : )" "0 none 0"
rigInstallLine="$( LC_ALL=C grep -F -- "$rigOpName" "$rigLocalTools" | LC_ALL=C sed -e "s/^[[:space:]]*echo '//" -e "s/'\$//" )"
rigRunInstallLine(){ ## origin -- the install block's own command line run under that origin; rc in rigRc
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$1" MDLT_OPTION="--run-from-path $1" MDAT_SKILLSET_ROOT="$rigSkills" sh -c "$rigInstallLine" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigRunInstallLine "$MDLT_ORIGIN"
rigAssert "the install block's line, run, builds both registries"          "$rigRc $( [ -s "$rigMembersFile" ] && printf written || printf missing ) $( [ -s "$rigNamesFile" ] && printf written || printf missing )" "0 written written"
rm -f "$rigNamesFile" "$rigMembersFile"
rigRunInstallLine "$rigTmp/noorigin"
rigAssert "and with no agents script at the origin it does nothing and succeeds" "$rigRc $( [ -e "$rigNamesFile" ] && printf written || printf none )" "0 none"
rigAssert "control: the extracted line is the command, not the echo around it" "$( printf '%s\n' "$rigInstallLine" | LC_ALL=C grep -c -E '^\[ ! -f ' || : )" 1

echo "-- 20. the help pair --"
rigHelpInclude="$rigHere/help/Help.DistroAgentsTools.include"
rigHelpMd="$rigHere/help/Help.DistroAgentsTools.help.md"
rigSyntax="📘 syntax: DistroAgentsTools.fn.sh $rigOpName"
rigAssert "the syntax echo is in the help include, once, as a whole line"   "$( LC_ALL=C grep -c -x -F -- "echo \"$rigSyntax\" >&2" "$rigHelpInclude" || : )" 1
rigAssert "the syntax line is in the help.md, once, as a whole line"        "$( LC_ALL=C grep -c -x -F -- "$rigSyntax" "$rigHelpMd" || : )" 1
rigAssert "the help.md has the operation's entry, once, under its own heading line" "$( LC_ALL=C grep -c -x -- "$( printf '\t\t%s' "$rigOpName" )" "$rigHelpMd" || : )" 1
rigAssert "control: a sample holding the syntax line twice counts two"      "$( printf '%s\n%s\n' "$rigSyntax" "$rigSyntax" > "$rigTmp/sample.md" ; LC_ALL=C grep -c -x -F -- "$rigSyntax" "$rigTmp/sample.md" || : )" 2

echo "-- 21. the keys are accepted by the config writer, in any locale --"
rigWorld
rigUpsert(){ ## locale, member, key, value -- one --upsert-from-stdin; rc in rigRc
	rigRc=0
	( cd "$rigWs" && printf '%s' "$4" | env -i HOME="$rigHome" PATH="$PATH" LC_ALL="$1" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash "$rigTool" --agents-config-option "$2" --upsert-from-stdin "$3" ) > "$rigTmp/up.out" 2> "$rigTmp/up.err" || rigRc=$?
}
rigSelect(){ ## locale, member, key
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" LC_ALL="$1" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash "$rigTool" --member-config-option "$2" --select "$3" 2> /dev/null )
}
for rigLocale in C en_US.UTF-8 ; do
	for rigKey in FIRST_NAME FAMILY_NAME ALIAS ; do
		rigUpsert "$rigLocale" "$rigPersona" "$rigKey" "Val$rigKey"
		rigAssert "[$rigLocale] $rigKey is accepted, the key is in the scope file, and --select returns it" "$rigRc $( LC_ALL=C grep -c "^$rigKey=Val$rigKey\$" "$rigWs/.local/.agents/$rigPersona.agent.env" || : ) $( rigSelect "$rigLocale" "$rigPersona" "$rigKey" )" "0 1 Val$rigKey"
	done
	rigUpsert "$rigLocale" "$rigPersona" FIRST_NAME ''
	rigAssert "[$rigLocale] control: an empty value is refused and the stored value is kept" "$( [ "$rigRc" -ne 0 ] && printf refused || printf accepted ) $( rigSelect "$rigLocale" "$rigPersona" FIRST_NAME )" "refused ValFIRST_NAME"
done

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SLACK CLIENT PERSONA CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SLACK_CLIENT_PERSONA: OK (%d assertions, offline)\n' "$rigPasses"
