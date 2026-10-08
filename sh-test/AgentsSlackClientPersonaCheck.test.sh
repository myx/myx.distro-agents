#!/usr/bin/env bash
## Behavioural check on what a member presents in Slack and on the agents registries that hold it, run rather than read,
## against a scenario workspace and a fixture skillset built here. Held: --make-agents-indices writes, in
## $MMDAPP/.local/agents, exactly two registries for the members that have a path in THIS workspace: team-members
## (member workspace link-kind path) and team-members-names (member mark first family alias). A member's names are
## DEFAULTED from its own basic.md bullets (the marks function for mark and alias, the Name bullet split at its first
## space, a final period dropped, plain words only) and replaced by its scope keys FIRST_NAME, FAMILY_NAME, ALIAS at
## build time; a value that is missing, `not decided yet` or not storable is `-` and warned about, unless the member's
## SKILL.md says reference-only. EVERY client-* member has the row of the persona member (one constant), its own
## files, bullets and scope are not read, and an unreadable persona gives dashes, one warning per field and a refused
## external send. A send reads team-members-names and nothing else: an edit to a bullet, a scope or a SKILL.md is not
## followed until the next build, and unreadable files change nothing. A client's EXTERNAL presentation (own user token,
## or own bot token with no relay) is that row, with no client identifier in the payload and no metadata. A sender with
## no row, or no alias, shows its member name; an addressee whose directory is missing refuses, one whose directory
## exists but has no row is plain @<member>, and its mention id never depends on a row. Also held: the Name shapes, a
## localised name byte for byte, the in-body mention rules, no identity swap to the shared bot for an external send,
## the two call places of the build and its help pair. A fake `curl` first on PATH logs each method with its token and
## the posted bodies; every token is a literal. Offline by construction. What the stubs cannot show: how real Slack
## renders any of it, and the real skillset's own bullets and installer index.
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
rigDataRoot="$rigTmp/team-data"
rigNamesFile="$rigAgentsDir/$rigNamesName.registry"
rigMembersFile="$rigAgentsDir/$rigMembersName.registry"
rigLinkedFile="$rigWs/.local/agents/members.registry"
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

## The fixture skillset. The names live in a member's basic.md bullets; its SKILL.md carries the status and decoy
## frontmatter names that no output may show.
rigBasic(){ ## member, lines... -- that member's .basic.md
	local basicMember="$1" ; shift
	mkdir -p "$rigSkills/$basicMember"
	{ printf -- '---\nmaintainers: rig\n---\n' ; printf '%s\n' "$@" ; } > "$rigSkills/$basicMember/$basicMember.basic.md"
}
rigBullets(){ ## member, Name text as written (empty: no line), alias (empty: no line), mark (empty: no line)
	local bulletMember="$1" bulletLines=( "# $1" )
	[ -z "$2" ] || bulletLines+=( "- **Name**: $2" )
	[ -z "$3" ] || bulletLines+=( "- **Alias**: \`$3\`." )
	[ -z "$4" ] || bulletLines+=( "- **Unicode character**: $4" )
	rigBasic "$bulletMember" "${bulletLines[@]}"
}
rigSkill(){ ## member, status -- that member's SKILL.md: the status, and decoy names that no output may show
	mkdir -p "$rigSkills/$1"
	{
		printf -- '---\nname: %s\n' "$1"
		[ -z "$2" ] || printf 'status: %s\n' "$2"
		printf -- 'first-name: DecoyFirst\nfamily-name: DecoyFamily\nalias: decoyalias\ndescription: rig\n---\n\n# %s\n' "$1"
	} > "$rigSkills/$1/SKILL.md"
}
rigLinkAdd(){ ## member, workspace, path -- one row of the installer's member registry: member, workspace root, link kind, path, member directory
	mkdir -p "${rigLinkedFile%/*}"
	printf '%s\t%s\tsource-symlink\t%s\t%s\n' "$1" "$rigTmp/$2" "${3:-myx/pkg/skillset/$1}" "$rigTmp/$2/source/${3:-myx/pkg/skillset/$1}" >> "$rigLinkedFile"
}
rigLinkDrop(){ ## member -- every row of that member out of the member registry
	LC_ALL=C grep -v "^$1	" "$rigLinkedFile" > "$rigLinkedFile.next" ; mv "$rigLinkedFile.next" "$rigLinkedFile"
}
rigBuild(){ ## options... -- the registries build in the rig workspace; rc in rigBuildRc, stdout in $rigTmp/build.out, stderr in $rigTmp/build.err
	rigBuildRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash "$rigTool" "$rigOpName" "$@" ) > "$rigTmp/build.out" 2> "$rigTmp/build.err" < /dev/null || rigBuildRc=$?
}
rigWorld(){ ## -- a fresh workspace and skillset with the default tokens, members, linked-members index and registries built
	rm -rf "$rigWs" "$rigSkills"
	mkdir -p "$rigWs/.local/.agents" "$rigSkills"
	rigBullets "$rigPersona" 'Magic Vane.' dispatchr 🐭 ; rigSkill "$rigPersona" active
	rigBullets client-ndm 'Client Decoy.' clientdecoy 🦊 ; rigSkill client-ndm active
	rigBullets client-mel '' '' 🦊 ; rigSkill client-mel active
	rigBasic magic-team '# the team, no mark of its own'
	rigBullets keeper-myx 'Forge Keeper.' forge 🔧 ; rigSkill keeper-myx active
	mkdir -p "${rigLinkedFile%/*}" ; : > "$rigLinkedFile"
	rigLinkAdd "$rigPersona" "$rigWsName" ; rigLinkAdd client-ndm "$rigWsName" ; rigLinkAdd client-mel "$rigWsName" ; rigLinkAdd keeper-myx "$rigWsName"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-COORD\n' > "$rigWs/.local/.agents/$rigPersona.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-NDM\n' > "$rigWs/.local/.agents/client-ndm.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-MEL\nSLACK_BOT_TOKEN=rig-bot-token-MEL\n' > "$rigWs/.local/.agents/client-mel.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-KEEPER\n' > "$rigWs/.local/.agents/keeper-myx.agent.env"
	: > "$rigTmp/post-answers"
	## Each client's own contacts note: an external send passes the outbound contact gate
	## (--intern-op-contact-assert-known) only for a listed recipient, and these are the
	## rig's own channel, owner and DM. Under the data root every send here is given,
	## outside .local/agents so the registry folder holds only what the build wrote.
	local contactsMember
	rm -rf "$rigDataRoot"
	for contactsMember in client-ndm client-mel ; do
		mkdir -p "$rigDataRoot/inboxes/$contactsMember"
		printf '%s\n' \
			'| slack-id | contact | handle | email | organisation | permission level |' \
			'| --- | --- | --- | --- | --- | --- |' \
			'| CRIG00001 | rig-team | @rig-team | <unresolved> | rig | unset |' \
			'| URIGOWNER | rig-owner | @rig-owner | <unresolved> | rig | unset |' \
			'| DRIG00001 | rig-owner-dm | @rig-owner | <unresolved> | rig | unset |' \
			'| URIGKEEPER | rig-keeper | @rig-keeper | <unresolved> | rig | unset |' \
			'| URIGNDM | rig-client-ndm | @rig-client-ndm | <unresolved> | rig | unset |' \
			'| URIGACCT | rig-account | @rig-account | <unresolved> | rig | unset |' \
			> "$rigDataRoot/inboxes/$contactsMember/note-rig-contacts.md"
	done
	rigBuild
}
rigWorldPlain(){ ## -- the default world and one more member with no Slack token of its own
	rigWorld
	rigBullets keeper-plain 'Plain Keeper.' plainalias 🔨 ; rigSkill keeper-plain active
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
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" RIG_SCENARIO="$rigTmp" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" MDAT_DATA_ROOT="$rigDataRoot" \
		bash "$rigTool" --member-comms-slack-send-message "$1" "$2" "${@:3}" RIG-BODY ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigSendBody(){ ## member, target, body, send options... -- the same with a body of its own
	: > "$rigTmp/calls" ; rm -f "$rigTmp/bodies" ; touch "$rigTmp/bodies"
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" RIG_SCENARIO="$rigTmp" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" MDAT_DATA_ROOT="$rigDataRoot" \
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
rigWarnsOf(){ ## fixed text -- how many build warning lines hold it
	LC_ALL=C grep '^⚠️ WARNING: ' "$rigTmp/build.err" 2> /dev/null | LC_ALL=C grep -c -F -- "$1" || :
}

rigWorld
[ "$rigBuildRc" = 0 ] && [ -f "$rigNamesFile" ] || rigRefuse "the baseline build made no $rigNamesName registry at $rigNamesFile, so no row below would be measured: $( LC_ALL=C grep -m1 ERROR "$rigTmp/build.err" )"
rigSend keeper-myx magic-team
[ "$rigRc" = 0 ] && [ "$( rigPosts )" = 1 ] || rigRefuse "the baseline send reached no post, so no row below would be measured: $( LC_ALL=C grep -m1 ERROR "$rigTmp/err" )"

echo "-- 1. a client's own user token: the external presentation is the persona's row --"
rigSend client-ndm magic-team
rigAssert "the send is posted under the client's own user token"          "$rigRc $( rigPostToken )" "0 rig-user-token-NDM"
rigAssert "the text is the header from the persona's row: mark, name and alias" "$( rigText )" '🐭 *_Magic Vane_* @dispatchr → @here.\nRIG-BODY'
rigAssert "the blocks carry the mark, the name in bold italic, and the alias" "$( rigBodyHas '{"type":"text","text":"🐭 "},{"type":"text","text":"Magic Vane","style":{"bold":true,"italic":true}},{"type":"text","text":" @dispatchr "}' )" 1
rigAssert "no client identifier anywhere in the posted payload"            "$( rigBodyHas 'client-ndm' )" 0
rigAssert "and no metadata key at all"                                     "$( rigBodyHas '"metadata"' )" 0
rigAssert "and nothing of the client's own bullets or the decoy frontmatter" "$( rigBodyHas 'Decoy' ) $( rigBodyHas 'decoy' ) $( rigBodyHas 'clientdecoy' ) $( rigBodyHas '🦊' )" "0 0 0 0"
rigSend client-ndm human-owner
rigAssert "to the human-owner, with its own token: the same header, no relay" "$( rigText ) $( rigN "$rigTmp/err" 'has no SLACK_USER_TOKEN of its own' )" '🐭 *_Magic Vane_* @dispatchr → <@URIGOWNER>.\nRIG-BODY 0'
rigSend keeper-myx magic-team
rigAssert "control: a non-client member's header is its own row alias and mark, with its member name" "$( rigText )" '🔧 *_keeper-myx_* @forge → @here.\nRIG-BODY'
rigAssert "control: no decoy frontmatter value there either"               "$( rigBodyHas 'Decoy' ) $( rigBodyHas 'decoy' )" "0 0"

echo "-- 2. a client's own bot token with --identity-bot: external too --"
rigSend client-mel magic-team --identity-bot
rigAssert "posted under the client's own bot token"                        "$rigRc $( rigPostToken )" "0 rig-bot-token-MEL"
rigAssert "the text is the header from the persona's row, though the client has no bullets of its own" "$( rigText )" '🐭 *_Magic Vane_* @dispatchr → @here.\nRIG-BODY'
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

echo "-- 6. a persona that cannot be read: client rows are dashes, one warning per field, an external send refused --"
rigRefusal(){ ## label, how many fields the persona is missing
	rigAssert "$1: the persona warns once per missing field, naming the persona, the field and the bullets" "$( rigWarnsOf "persona member $rigPersona: required field" ) $( LC_ALL=C grep -c -E "persona member $rigPersona: required field .* is missing or not valid in its basic.md [(]a Name bullet of plain words, or its scope key[)]\$" "$rigTmp/build.err" || : )" "$2 $2"
	rigAssert "$1: every client row is dashes, though the clients have two clients' own files" "$( rigIndexRow client-ndm ) $( rigIndexRow client-mel )" 'client-ndm|-|-|-|- client-mel|-|-|-|-'
	rigSend client-ndm magic-team
	rigAssert "$1: the external send exits 1 naming the persona row, all three fields, ending nothing was sent" "$rigRc $( LC_ALL=C grep -c -F -- "⛔ ERROR: DistroAgentsTools --member-comms-slack-send-message: the external presentation needs the persona row in the team-members-names registry (--make-agents-indices): missing first-name, family-name, alias; nothing was sent" "$rigTmp/err" || : )" "1 1"
	rigAssert "$1: the curl stub was never called"                         "$( rigNoCalls )" 0
	rigAssert "$1: no body was posted, so nothing fell back to another name" "$( rigNoBodies )" 0
	rigSend client-ndm magic-team --identity-bot
	rigAssert "$1: sibling, the same client as the shared bot (internal) still sends, as its member name" "$rigRc $( rigPosts ) $( rigBodyHas '*_client-ndm_*' )" '0 1 1'
	rigSend keeper-myx magic-team
	rigAssert "$1: control, a non-client member is untouched"              "$rigRc $( rigText )" '0 🔧 *_keeper-myx_* @forge → @here.\nRIG-BODY'
}
rigWorld ; rm -f "$rigSkills/$rigPersona/$rigPersona.basic.md" ; rigBuild
rigRefusal "persona basic.md missing" 3
rigWorld ; rigBullets "$rigPersona" '' dispatchr 🐭 ; rigBuild
rigRefusal "persona has no Name line" 2
rigWorld ; rigBullets "$rigPersona" 'Magic.' dispatchr 🐭 ; rigBuild
rigRefusal "persona Name is one word" 1
rigWorld ; rigBullets "$rigPersona" 'Magic Vane.' '' 🐭 ; rigBuild
rigRefusal "persona has no Alias line" 1
rigWorld ; rigBullets "$rigPersona" 'Magic Vane.' 'bad!' 🐭 ; rigBuild
rigRefusal "persona Alias is no handle" 1
rigWorld ; rigBullets "$rigPersona" 'Magic Vane.' 'a"b' 🐭 ; rigBuild
rigRefusal "persona Alias holds a double quote" 1
rigWorld ; rigBullets "$rigPersona" 'Magic Vane, the dispatcher of the team.' dispatchr 🐭 ; rigBuild
rigRefusal "persona Name is a prose line" 2
rigWorld ; rigBullets "$rigPersona" 'Magic "Vane".' dispatchr 🐭 ; rigBuild
rigRefusal "persona Name holds double quotes" 2
rigWorld ; rigBullets "$rigPersona" 'Ma_gic Vane.' dispatchr 🐭 ; rigBuild
rigRefusal "persona Name holds an underscore" 2
rigWorld ; rigBullets "$rigPersona" "Magic Va$( printf '\302\205' )ne." dispatchr 🐭 ; rigBuild
rigRefusal "persona family name holds a C1 control (U+0085)" 1
rigWorld ; rigScope "$rigPersona" 'FIRST_NAME=a"b'
rigRefusal "persona scope FIRST_NAME holds a double quote" 1
rigWorld ; rigScope "$rigPersona" 'ALIAS=a b'
rigRefusal "persona scope ALIAS holds a space" 1
rigWorld ; rigScope "$rigPersona" 'FAMILY_NAME=not decided yet'
rigRefusal "persona scope FAMILY_NAME is not decided yet" 1
rigWorld ; rigSkill "$rigPersona" reference-only ; rigBullets "$rigPersona" '' '' 🐭 ; rigBuild
rigRefusal "persona that is reference-only is not exempt" 3
rigAssert "and its own ordinary row, being reference-only, does not warn as a member" "$( rigWarnsOf "indices: member $rigPersona: required field" )" 0
rigWorld ; rigBullets "$rigPersona" '' dispatchr 🐭 ; rigBuild
rigAssert "the persona's own ordinary row warns as a member too, once per field, besides the persona warning" "$( rigWarnsOf "indices: member $rigPersona: required field" ) $( rigIndexRow "$rigPersona" )" "2 $rigPersona|🐭|-|-|dispatchr"
rigAssert "and two clients make the persona warnings no more: two, not four"   "$( rigWarnsOf "persona member $rigPersona: required field" )" 2
rigWorld ; rigLinkDrop client-ndm ; rigBuild
rigSend client-ndm magic-team
rigAssert "a client with no path in this workspace has no row: an external send refuses, nothing sent" "$rigRc $( rigNoCalls ) $( rigN "$rigTmp/err" 'missing first-name, family-name, alias; nothing was sent' )" "1 0 1"
rigWorld ; rm -f "$rigNamesFile"
rigSend client-ndm magic-team
rigAssert "no registry file at all: refused, nothing sent"                 "$rigRc $( rigNoCalls ) $( rigN "$rigTmp/err" 'missing first-name, family-name, alias; nothing was sent' )" "1 0 1"
rigWorld ; rigLinkDrop "$rigPersona" ; rm -f "$rigSkills/$rigPersona/SKILL.md" ; rigBuild
rigSend client-ndm magic-team
rigAssert "control: a persona with no path and no SKILL.md in this workspace still serves its bullets to the clients" "$rigRc $( rigText ) $( rigIndexRow "$rigPersona" )" '0 🐭 *_Magic Vane_* @dispatchr → @here.\nRIG-BODY '
rigWorld

echo "-- 7. a localised or multi-word persona name passes byte for byte --"
for rigName in "Zauberer Müller" "Магия Вейн" "Magic D'Vane" "Magic © Vane" "Ünal Ø" "Mary Ann van der Berg" "Jean-Luc Picard" ; do
	rigWorld ; rigBullets "$rigPersona" "$rigName." dispatchr 🐭 ; rigBuild
	rigSend client-ndm magic-team
	rigAssert "$rigName: in the text, exactly"                             "$rigRc $( rigText )" "0 🐭 *_${rigName}_* @dispatchr → @here.\\nRIG-BODY"
	rigAssert "$rigName: in the blocks, exactly"                           "$( rigBodyHas "{\"type\":\"text\",\"text\":\"$rigName\",\"style\":{\"bold\":true,\"italic\":true}}" )" 1
done
rigWorld ; rigBullets "$rigPersona" 'Mary Ann van der Berg.' dispatchr 🐭 ; rigBuild
rigAssert "a name of several words is stored first, then the rest with underscores" "$( rigIndexRow client-ndm )" 'client-ndm|🐭|Mary|Ann_van_der_Berg|dispatchr'
rigWorld

echo "-- 8. the addressee of an external send --"
rigSend client-ndm magic-team --address-to client-ndm
rigAssert "to itself: the persona header and a real mention of the account that posts" "$( rigText )" '🐭 *_Magic Vane_* @dispatchr → 🐭 *_Magic Vane_* <@URIGNDM>.\nRIG-BODY'
rigAssert "and the blocks hold the user element for that id"               "$( rigBodyHas '{"type":"user","user_id":"URIGNDM"}' ) $( rigBodyHas 'client-ndm' )" "1 0"
rigSend client-ndm magic-team --address-to client-mel
rigAssert "to another client: its row, which is the persona's, the plain alias, no mention id" "$( rigText ) $( rigN "$rigTmp/bodies" '<@' ) $( rigBodyHas '"type":"user"' )" '🐭 *_Magic Vane_* @dispatchr → 🐭 *_Magic Vane_* @dispatchr.\nRIG-BODY 0 0'
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

echo "-- 11. a client row equals the persona row, whatever the client holds --"
rigWorld
rigAssert "the two clients' rows are the persona's row under their own member names" "$( rigIndexRow client-ndm ) $( rigIndexRow client-mel ) $( rigIndexRow "$rigPersona" )" "client-ndm|🐭|Magic|Vane|dispatchr client-mel|🐭|Magic|Vane|dispatchr $rigPersona|🐭|Magic|Vane|dispatchr"
rigAssert "the build warned of nothing"                                    "$( LC_ALL=C grep -c 'WARNING' "$rigTmp/build.err" || : )" 0
rigBullets client-ndm 'Own Name.' ownalias 🦉 ; rigSkill client-ndm reference-only
rigScopeRaw client-ndm FIRST_NAME=OwnFirst FAMILY_NAME=OwnFamily ALIAS=ownscope
rigBuild
rigAssert "a client with its own Name, Alias, mark, scope keys and SKILL.md still has the persona's row" "$( rigIndexRow client-ndm )" 'client-ndm|🐭|Magic|Vane|dispatchr'
rigSend client-ndm magic-team
rigAssert "and presents the persona's, with nothing of its own in the payload" "$( rigText ) $( rigBodyHas 'Own' ) $( rigBodyHas 'own' ) $( rigBodyHas '🦉' ) $( rigBodyHas 'Decoy' )" '🐭 *_Magic Vane_* @dispatchr → @here.\nRIG-BODY 0 0 0 0'
rigScopeRaw client-ndm 'FIRST_NAME=a"b' 'ALIAS=bad alias!'
rigBuild
rigAssert "bad values in a client's own scope are not read: the row is the persona's and nothing warns" "$( rigIndexRow client-ndm ) $( LC_ALL=C grep -c 'WARNING' "$rigTmp/build.err" || : )" 'client-ndm|🐭|Magic|Vane|dispatchr 0'
rm -f "$rigSkills/client-ndm/client-ndm.basic.md" "$rigSkills/client-ndm/SKILL.md"
rigBuild
rigAssert "a client with no basic.md and no SKILL.md at all has the persona's row too" "$( rigIndexRow client-ndm ) $( LC_ALL=C grep -c 'WARNING' "$rigTmp/build.err" || : )" 'client-ndm|🐭|Magic|Vane|dispatchr 0'
rigWorld
rigClientSum="$( cksum < "$rigSkills/client-ndm/client-ndm.basic.md" )"
rigBuild ; rigSend client-ndm magic-team ; rigSend client-ndm magic-team --identity-bot
rigAssert "no bullet is written into the client's basic.md by a build or a send" "$( cksum < "$rigSkills/client-ndm/client-ndm.basic.md" ) $( LC_ALL=C grep -c -E 'Name|Alias' "$rigSkills/client-ndm/client-ndm.basic.md" || : )" "$rigClientSum 2"
rigAssert "control: that file does hold a Name line of its own to begin with, the decoy" "$( LC_ALL=C grep -c 'Client Decoy' "$rigSkills/client-ndm/client-ndm.basic.md" || : )" 1
rigBullets client-mel '' '' 🦊
rigBuild
rigAssert "the persona's mark, not the client's own, is the client's mark"  "$( rigIndexRow client-mel | LC_ALL=C awk -F'|' '{ print $2 }' )" '🐭'
rigSend client-ndm magic-team --address-to client-mel
rigAssert "an addressee client reads under the persona's row, which is its own row"   "$( rigText )" '🐭 *_Magic Vane_* @dispatchr → 🐭 *_Magic Vane_* @dispatchr.\nRIG-BODY'
rigLinkDrop client-mel ; rigBuild
rigSend client-ndm magic-team --address-to client-mel
rigAssert "an addressee client with no row reads under the sender's external names, the same text" "$( rigText ) $( rigBodyHas 'client-mel' )" '🐭 *_Magic Vane_* @dispatchr → 🐭 *_Magic Vane_* @dispatchr.\nRIG-BODY 0'
rigWorld

echo "-- 11b. a persona's override reaches the client rows at the next build only --"
rigScopeRaw "$rigPersona" FIRST_NAME=Alexa FAMILY_NAME=Quill ALIAS=pr.manager
rigSend client-ndm magic-team
rigAssert "before the build: the client's external header is unchanged"    "$( rigText )" '🐭 *_Magic Vane_* @dispatchr → @here.\nRIG-BODY'
rigAssert "and both client rows and the persona's own row are unchanged"   "$( rigIndexRow client-ndm ) $( rigIndexRow client-mel ) $( rigIndexRow "$rigPersona" )" "client-ndm|🐭|Magic|Vane|dispatchr client-mel|🐭|Magic|Vane|dispatchr $rigPersona|🐭|Magic|Vane|dispatchr"
rigBuild
rigSend client-ndm magic-team
rigAssert "after the build: the client's external header is the override"  "$( rigText )" '🐭 *_Alexa Quill_* @pr.manager → @here.\nRIG-BODY'
rigAssert "both client rows and the persona's own row carry it"            "$( rigIndexRow client-ndm ) $( rigIndexRow client-mel ) $( rigIndexRow "$rigPersona" )" "client-ndm|🐭|Alexa|Quill|pr.manager client-mel|🐭|Alexa|Quill|pr.manager $rigPersona|🐭|Alexa|Quill|pr.manager"
rigSend client-ndm magic-team --identity-bot
rigAssert "control: the same client as the shared bot shows its member name with the overridden alias" "$( rigText )" '🐭 *_client-ndm_* @pr.manager → @here.\nRIG-BODY'
rigWorld ; rigScope "$rigPersona" FIRST_NAME=Alexa
rigAssert "FIRST_NAME alone: the family and alias stay from the bullets"   "$( rigIndexRow client-ndm )" 'client-ndm|🐭|Alexa|Vane|dispatchr'
rigWorld ; rigScope "$rigPersona" FAMILY_NAME=Quill
rigAssert "FAMILY_NAME alone: the first name and alias stay from the bullets" "$( rigIndexRow client-ndm )" 'client-ndm|🐭|Magic|Quill|dispatchr'
rigWorld ; rigScope "$rigPersona" ALIAS=pr.manager
rigAssert "ALIAS alone: the names stay from the bullets"                   "$( rigIndexRow client-ndm )" 'client-ndm|🐭|Magic|Vane|pr.manager'
rigWorld ; rigScope "$rigPersona" FIRST_NAME=Alexa
rigBullets "$rigPersona" 'Wren Skinner.' dispatchr 🐭
rigSend client-ndm magic-team
rigAssert "a persona bullet edited without a rebuild is not followed"      "$( rigText )" '🐭 *_Alexa Vane_* @dispatchr → @here.\nRIG-BODY'
rigBuild
rigAssert "after the build the bullet's family and the override's first name are both there" "$( rigIndexRow client-ndm )" 'client-ndm|🐭|Alexa|Skinner|dispatchr'
rigBullets "$rigPersona" 'Wren Skinner.' dispatchr 🦊
rigBuild
rigAssert "the persona's mark, edited and rebuilt, is every client's mark"  "$( rigIndexRow client-ndm ) $( rigIndexRow client-mel )" 'client-ndm|🦊|Alexa|Skinner|dispatchr client-mel|🦊|Alexa|Skinner|dispatchr'
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
rigWorldPlain ; rigBullets keeper-plain 'Plain Keeper.' '' 🔨 ; rigBullets keeper-myx 'Forge Keeper.' '' 🔧 ; rigBuild
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
rigBullets keeper-myx 'Forge Keeper.' changed 🔧
rigSend keeper-myx magic-team
rigAssert "a basic.md Alias edited without a rebuild is not followed"      "$( rigText )" '🔧 *_keeper-myx_* @forge → @here.\nRIG-BODY'
rigBuild
rigSend keeper-myx magic-team
rigAssert "control: after the build the same edit is followed"             "$( rigText )" '🔧 *_keeper-myx_* @changed → @here.\nRIG-BODY'
rigWorldPlain
rigScopeRaw keeper-myx ALIAS=scoped FIRST_NAME=Other
rigScopeRaw "$rigPersona" FIRST_NAME=Alexa FAMILY_NAME=Quill ALIAS=aquill
rigSend keeper-myx magic-team
rigAssert "a scope edited without a rebuild is not followed: internal"     "$( rigText )" '🔧 *_keeper-myx_* @forge → @here.\nRIG-BODY'
rigSend client-ndm magic-team
rigAssert "and external"                                                   "$( rigText )" '🐭 *_Magic Vane_* @dispatchr → @here.\nRIG-BODY'
rigBuild
rigSend keeper-myx magic-team
rigAssert "control: after the build the scope alias is followed"           "$( rigText )" '🔧 *_keeper-myx_* @scoped → @here.\nRIG-BODY'
rigSend client-ndm magic-team
rigAssert "control: and the persona's scope names are the client's"        "$( rigText )" '🐭 *_Alexa Quill_* @aquill → @here.\nRIG-BODY'
rigWorldPlain
rigBullets keeper-myx 'Forge Keeper.' forge 🪛
rigSend keeper-myx magic-team
rigAssert "a basic.md mark edited without a rebuild is not followed"       "$( rigText )" '🔧 *_keeper-myx_* @forge → @here.\nRIG-BODY'
rigBuild
rigSend keeper-myx magic-team
rigAssert "control: after the build it is"                                 "$( rigText )" '🪛 *_keeper-myx_* @forge → @here.\nRIG-BODY'
rigWorldPlain
rigSkill keeper-myx reference-only
rigSend keeper-myx magic-team
rigAssert "a SKILL.md status edited without a rebuild changes nothing, and a send never reads it" "$rigRc $( rigText )" '0 🔧 *_keeper-myx_* @forge → @here.\nRIG-BODY'
rigWorldPlain
rm -f "$rigSkills/client-ndm/SKILL.md" "$rigSkills/client-ndm/client-ndm.basic.md" "$rigSkills/keeper-myx/SKILL.md" "$rigSkills/keeper-myx/keeper-myx.basic.md" "$rigSkills/$rigPersona/$rigPersona.basic.md" "$rigLinkedFile"
rigSend client-ndm magic-team
rigAssert "the skill and basic files and the linked-members index deleted after the build change nothing: external" "$rigRc $( rigText )" '0 🐭 *_Magic Vane_* @dispatchr → @here.\nRIG-BODY'
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
rigBullets keeper-w2 'Wren Skinner.' wren 🔧 ; rigSkill keeper-w2 active
rigBullets keeper-w1 'Cher.' cher 🔧
rigBullets keeper-w3 'Mary Ann Smith.' mary 🔧
rigBullets keeper-w5 'Mary Ann van der Berg' mary5 🔧
rigBullets keeper-bt '`Wren Skinner`.' bt 🔧
rigBullets keeper-prose 'Wren Skinner, the forge keeper of the old tower.' prose 🔧
rigBullets keeper-quote 'Wren "Skin" ner.' quote 🔧
rigBullets keeper-noname '' noname 🔧
rigBullets keeper-aq 'Aq Name.' 'a"b' 🔧
rigBullets keeper-ab 'Ab Name.' 'bad!' 🔧
rigBullets keeper-sc 'Sc Name.' scopey 🔧
rigBullets keeper-sq 'Sq Name.' sqey 🔧
rigBullets keeper-ud 'Ud Name.' udey 🔧
rigBullets keeper-mix 'Mia.' '' 🔧
rigBullets keeper-ref '' '' '' ; rigSkill keeper-ref reference-only
rigSkill keeper-nb active
rigBullets keeper-notlinked 'Not Linked.' notlinked 🔧
rigBasic keeper-sh '- **Slack shortcode**: :hammer:' '- **Unicode character**: 🔨' '- **Name**: Hammer Hand.' '- **Alias**: `hh`.'
for rigMember in keeper-w2 keeper-w1 keeper-w3 keeper-w5 keeper-bt keeper-prose keeper-quote keeper-noname keeper-aq keeper-ab keeper-sc keeper-sq keeper-ud keeper-mix keeper-ref keeper-nb keeper-sh ; do rigLinkAdd "$rigMember" "$rigWsName" ; done
rigScopeRaw keeper-myx FIRST_NAME=Override
rigScopeRaw keeper-sc 'ALIAS=has space'
rigScopeRaw keeper-sq 'ALIAS=a"b'
rigScopeRaw keeper-ud 'FIRST_NAME=not decided yet'
mkdir -p "$rigAgentsDir"
printf 'seed-sessions\n' > "$rigAgentsDir/spawned-sessions.registry" ; printf 'seed-replies\n' > "$rigAgentsDir/pending-replies.registry" ; printf 'seed-log\n' > "$rigAgentsDir/comms-slack-send.log"
rigSeedSum="$( cat "$rigAgentsDir/spawned-sessions.registry" "$rigAgentsDir/pending-replies.registry" "$rigAgentsDir/comms-slack-send.log" | cksum )"
rigBuild
rigAssert "the build exits 0 and prints nothing on stdout"                 "$rigBuildRc $( rigLines "$rigTmp/build.out" )" "0 0"
rigAssert "the build makes exactly the two registries and the member index, and keeps the other files: the folder holds those, the three seeded and the member registry it reads" "$( ls "$rigAgentsDir" | LC_ALL=C tr '\n' ' ' )" "comms-slack-send.log members members.index members.registry pending-replies.registry spawned-sessions.registry team-members-names.registry team-members.registry "
rigAssert "and the seeded files are untouched"                             "$( cat "$rigAgentsDir/spawned-sessions.registry" "$rigAgentsDir/pending-replies.registry" "$rigAgentsDir/comms-slack-send.log" | cksum )" "$rigSeedSum"
rigAssert "the file naming rule: both new registries are <name>.registry, the earlier presentation file name is not written" "$( [ -f "$rigAgentsDir/team-members.registry" ] && printf yes || printf no ) $( [ -f "$rigAgentsDir/team-members-names.registry" ] && printf yes || printf no ) $( [ -e "$rigAgentsDir/member-presentation.index" ] && printf yes || printf no ) $( [ -e "$rigAgentsDir/member-presentation.index.registry" ] && printf yes || printf no )" "yes yes no no"
rigAssert "a plain row: member, mark, first, family, alias from the bullets" "$( rigIndexRow keeper-w2 )" 'keeper-w2|🔧|Wren|Skinner|wren'
rigAssert "the persona member's own row is an ordinary row"                "$( rigIndexRow "$rigPersona" )" "$rigPersona|🐭|Magic|Vane|dispatchr"
rigAssert "the clients' rows are the persona's"                            "$( rigIndexRow client-ndm ) $( rigIndexRow client-mel )" 'client-ndm|🐭|Magic|Vane|dispatchr client-mel|🐭|Magic|Vane|dispatchr'
rigAssert "a scope FIRST_NAME replaces the bullet's first name at build"   "$( rigIndexRow keeper-myx )" 'keeper-myx|🔧|Override|Keeper|forge'
rigAssert "a one-word Name: first name only, the family is -"              "$( rigIndexRow keeper-w1 )" 'keeper-w1|🔧|Cher|-|cher'
rigAssert "a three-word Name: first, then the rest with an underscore"     "$( rigIndexRow keeper-w3 )" 'keeper-w3|🔧|Mary|Ann_Smith|mary'
rigAssert "a Name with no final period is split the same"                  "$( rigIndexRow keeper-w5 )" 'keeper-w5|🔧|Mary|Ann_van_der_Berg|mary5'
rigAssert "a Name in backticks has them removed"                           "$( rigIndexRow keeper-bt )" 'keeper-bt|🔧|Wren|Skinner|bt'
rigAssert "a prose Name line is absent: first and family -"                "$( rigIndexRow keeper-prose )" 'keeper-prose|🔧|-|-|prose'
rigAssert "a Name holding double quotes is absent"                         "$( rigIndexRow keeper-quote )" 'keeper-quote|🔧|-|-|quote'
rigAssert "no Name line is absent"                                         "$( rigIndexRow keeper-noname )" 'keeper-noname|🔧|-|-|noname'
rigAssert "an Alias with a double quote is absent"                         "$( rigIndexRow keeper-aq )" 'keeper-aq|🔧|Aq|Name|-'
rigAssert "an Alias that is no handle is absent"                           "$( rigIndexRow keeper-ab )" 'keeper-ab|🔧|Ab|Name|-'
rigAssert "a scope ALIAS with a space is stored -, though the bullet was good" "$( rigIndexRow keeper-sc )" 'keeper-sc|🔧|Sc|Name|-'
rigAssert "a scope ALIAS with a double quote is stored -"                  "$( rigIndexRow keeper-sq )" 'keeper-sq|🔧|Sq|Name|-'
rigAssert "a scope first name of not decided yet is stored -, the bullet is not used instead" "$( rigIndexRow keeper-ud )" 'keeper-ud|🔧|-|Name|udey'
rigAssert "no Alias line and a one-word Name: the mark, and two dashes after the first name" "$( rigIndexRow keeper-mix )" 'keeper-mix|🔧|Mia|-|-'
rigAssert "a reference-only member with nothing: every field -"            "$( rigIndexRow keeper-ref )" 'keeper-ref|-|-|-|-'
rigAssert "a linked member with only a SKILL.md and no basic.md: all dashes" "$( rigIndexRow keeper-nb )" 'keeper-nb|-|-|-|-'
rigAssert "a member with a shortcode and a unicode character: the shortcode is the mark" "$( rigIndexRow keeper-sh )" 'keeper-sh|:hammer:|Hammer|Hand|hh'
rigAssert "a member with bullets but no path in this workspace has no row in either file" "$( LC_ALL=C grep -c 'keeper-notlinked' "$rigNamesFile" "$rigMembersFile" | LC_ALL=C tr '\n' ' ' )" "$rigNamesFile:0 $rigMembersFile:0 "
rigAssert "the row count: one per member linked in this workspace, in both files" "$( rigLines "$rigNamesFile" ) $( rigLines "$rigMembersFile" )" "21 21"
rigAssert "every names row has exactly five whitespace-separated fields, no header" "$( LC_ALL=C awk 'NF != 5 { bad++ } END { print bad + 0 }' "$rigNamesFile" )" 0
rigAssert "every team-members row has exactly four"                        "$( LC_ALL=C awk 'NF != 4 { bad++ } END { print bad + 0 }' "$rigMembersFile" )" 0
rigAssert "a team-members row is member, workspace, link kind, path"       "$( LC_ALL=C grep '^client-ndm ' "$rigMembersFile" )" "client-ndm $rigWsName source-symlink myx/pkg/skillset/client-ndm"
rigAssert "the decoy SKILL.md names are in no row"                         "$( LC_ALL=C grep -c -i 'decoy' "$rigNamesFile" || : )" 0
rigAssert "the warnings are in the package style on stderr, seventeen in all, and no error, no earlier style" "$( LC_ALL=C grep -c '^⚠️ WARNING: DistroAgentsTools --make-agents-indices: member ' "$rigTmp/build.err" || : ) $( LC_ALL=C grep -c 'ERROR: DistroAgentsTools' "$rigTmp/build.err" || : ) $( LC_ALL=C grep -c '🙋' "$rigTmp/build.err" || : )" "17 0 0"
rigAssert "every warning ends with the bullets hint, and none says SKILL.md"  "$( LC_ALL=C grep -c 'WARNING: .* is missing or not valid in its basic.md (a Name bullet of plain words, or its scope key)$' "$rigTmp/build.err" || : ) $( LC_ALL=C grep 'WARNING' "$rigTmp/build.err" | LC_ALL=C grep -c 'SKILL.md' || : )" "17 0"
rigAssert "a one-word Name warns for the family name only"                 "$( rigWarnsOf 'member keeper-w1: required field family-name' ) $( rigWarnsOf 'member keeper-w1: required field first-name' )" "1 0"
rigAssert "a prose Name warns for both names, and so does a quoted one and a missing one" "$( rigWarnsOf 'member keeper-prose: required field' ) $( rigWarnsOf 'member keeper-quote: required field' ) $( rigWarnsOf 'member keeper-noname: required field' )" "2 2 2"
rigAssert "a bad Alias bullet warns once, so does a bad scope alias, and the scope first name"  "$( rigWarnsOf 'member keeper-aq: required field alias' ) $( rigWarnsOf 'member keeper-ab: required field alias' ) $( rigWarnsOf 'member keeper-sc: required field alias' ) $( rigWarnsOf 'member keeper-sq: required field alias' ) $( rigWarnsOf 'member keeper-ud: required field first-name' )" "1 1 1 1 1"
rigAssert "a member lacking family-name and alias warns for each"          "$( rigWarnsOf 'member keeper-mix: required field family-name' ) $( rigWarnsOf 'member keeper-mix: required field alias' )" "1 1"
rigAssert "a linked member with no basic.md warns for all three"           "$( rigWarnsOf 'member keeper-nb: required field' )" 3
rigAssert "no warning for the reference-only member, the plain ones, the clients or the persona" "$( LC_ALL=C grep -c -E 'member (keeper-ref|keeper-w2|keeper-w3|keeper-w5|keeper-bt|keeper-sh|keeper-myx|client-ndm|client-mel|magic-coordinator):' "$rigTmp/build.err" || : ) $( rigWarnsOf 'persona member' )" "0 0"
rigAssert "a note per file on stderr: the path and the row count"          "$( rigN "$rigTmp/build.err" "# DistroAgentsTools $rigOpName: wrote $rigMembersFile (21 rows)" ) $( rigN "$rigTmp/build.err" "# DistroAgentsTools $rigOpName: wrote $rigNamesFile (21 rows)" )" "1 1"
rigSum="$( cat "$rigMembersFile" "$rigNamesFile" | cksum )"
rigBuild extra
rigAssert "an extra argument is refused: exit 1, named, nothing on stdout" "$rigBuildRc $( rigN "$rigTmp/build.err" "$rigOpName takes no arguments, got: extra" ) $( rigLines "$rigTmp/build.out" )" "1 1 0"
rigAssert "and both registries are as they were"                           "$( cat "$rigMembersFile" "$rigNamesFile" | cksum )" "$rigSum"
rigLinkDrop keeper-w1 ; rigLinkDrop keeper-w3
rigBuild
rigAssert "a rebuild is whole: a member that lost its path has no row in either file, the others stay" "$( rigIndexRow keeper-w1 )$( LC_ALL=C grep -c 'keeper-w3' "$rigMembersFile" || : ) $( rigLines "$rigNamesFile" ) $( rigLines "$rigMembersFile" )" "0 19 19"
rigAssert "control: the same build prints no error and no leftover temporary file" "$rigBuildRc $( LC_ALL=C grep -c 'ERROR: DistroAgentsTools' "$rigTmp/build.err" || : ) $( ls "$rigAgentsDir" | LC_ALL=C awk 'END { print NR }' )" "0 0 8"
cp "$rigLinkedFile" "$rigTmp/linked.keep"
rm -rf "$rigAgentsDir" ; printf 'not a directory\n' > "$rigAgentsDir"
rigBuild
rigAssert "registries that cannot be written (the folder is a file): exit 1, each path named, nothing on stdout" "$rigBuildRc $( rigN "$rigTmp/build.err" "ERROR: DistroAgentsTools $rigOpName: could not write $rigMembersFile" ) $( rigN "$rigTmp/build.err" "ERROR: DistroAgentsTools $rigOpName: could not write $rigNamesFile" ) $( rigLines "$rigTmp/build.out" )" "1 1 1 0"
rm -f "$rigAgentsDir" ; mkdir -p "$rigAgentsDir" ; chmod 555 "$rigAgentsDir"
rigBuild
rigAssert "a folder that cannot be written into: exit 1, each path named"  "$rigBuildRc $( rigN "$rigTmp/build.err" "could not write $rigMembersFile" ) $( rigN "$rigTmp/build.err" "could not write $rigNamesFile" )" "1 1 1"
rigAssert "and it left no file"                                            "$( ls "$rigAgentsDir" | LC_ALL=C awk 'END { print NR }' )" 0
chmod 755 "$rigAgentsDir"
cp "$rigTmp/linked.keep" "$rigLinkedFile"
rigBuild
rigAssert "control: once writable the same build exits 0 and writes both"  "$rigBuildRc $( [ -s "$rigNamesFile" ] && printf written || printf missing ) $( [ -s "$rigMembersFile" ] && printf written || printf missing )" "0 written written"
rigWorld

echo "-- 15. the team-members registry holds this workspace's members only --"
rigWorld
rigBullets keeper-both 'Both Member.' bothy 🔧 ; rigBullets keeper-away 'Away Member.' awayy 🔧
rigBullets keeper-prefix 'Pre Fix.' prefixy 🔧 ; rigBullets keeper-suffix 'Suf Fix.' suffixy 🔧
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
rigAssert "the names row of the shared member is there once"               "$( rigIndexRow keeper-both )" 'keeper-both|🔧|Both|Member|bothy'
rigAssert "the other members' rows are the four of the world and the one shared member, in both files" "$( rigLines "$rigMembersFile" ) $( rigLines "$rigNamesFile" )" "5 5"
rm -f "$rigLinkedFile"
rigBuild
rigAssert "with no linked-members index at all both registries are empty and the build succeeds" "$rigBuildRc $( rigLines "$rigMembersFile" ) $( rigLines "$rigNamesFile" ) $( [ -f "$rigMembersFile" ] && [ -f "$rigNamesFile" ] && printf files || printf missing )" "0 0 0 files"
rigWorld

echo "-- 16. a value in a scope that cannot be stored is -, warned about --"
rigScopeBad(){ ## label, member, KEY=value line, the field named in the warning
	rigWorldPlain ; rigScopeRaw "$2" "$3" ; rigBuild
	rigAssert "$1: the field is - in the row and the build warns once, exit 0" "$rigBuildRc $( rigDashes "$2" ) $( rigWarnsOf "indices: member $2: required field $4 is missing or not valid in its basic.md" )" "0 1 1"
}
rigBadValues=( 'a"b' 'a\b' "a$( printf '\001' )b" "a$( printf '\302\205' )b" 'a_b' '"Magic"' "'Magic'" )
rigBadNames=( 'a double quote' 'a backslash' 'a control byte' 'a C1 control byte (C2 85)' 'an underscore' 'double quotes around it' 'single quotes around it' )
rigAt=0
for rigValue in "${rigBadValues[@]}" ; do
	rigScopeBad "persona FIRST_NAME with ${rigBadNames[$rigAt]}" "$rigPersona" "FIRST_NAME=$rigValue" first-name
	rigAssert "persona FIRST_NAME with ${rigBadNames[$rigAt]}: the persona warns, and the clients' rows are dashes" "$( rigWarnsOf "persona member $rigPersona: required field first-name" ) $( rigIndexRow client-ndm )" "1 client-ndm|-|-|-|-"
	rigSend client-ndm magic-team
	rigAssert "persona FIRST_NAME with ${rigBadNames[$rigAt]}: the external send refuses, nothing sent" "$rigRc $( rigN "$rigTmp/err" "missing first-name, family-name, alias; nothing was sent" ) $( rigNoCalls ) $( rigNoBodies )" "1 1 0 0"
	rigAt=$(( rigAt + 1 ))
done
rigScopeBad "persona FAMILY_NAME with a quote" "$rigPersona" 'FAMILY_NAME=Q"u' family-name
rigScopeBad "persona ALIAS with a space" "$rigPersona" 'ALIAS=a b' alias
rigScopeBad "persona ALIAS starting with a dash" "$rigPersona" 'ALIAS=-dash' alias
rigScopeBad "persona ALIAS with a double quote" "$rigPersona" 'ALIAS=a"b' alias
rigScopeBad "persona ALIAS with a slash" "$rigPersona" 'ALIAS=a/b' alias
rigSend client-ndm magic-team
rigAssert "persona ALIAS with a slash: the external send refuses, no fallback to the bullet alias" "$rigRc $( rigNoCalls ) $( rigBodyHas 'dispatchr' )" "1 0 0"
rigScopeBad "an ordinary member's ALIAS with a space" keeper-myx 'ALIAS=a b' alias
rigAssert "and its own warning is the member one, the clients' rows are untouched" "$( rigWarnsOf 'persona member' ) $( rigIndexRow client-ndm )" '0 client-ndm|🐭|Magic|Vane|dispatchr'
rigSend keeper-myx magic-team
rigAssert "an ordinary sender with an alias stored -: its member name, its mark, sent" "$rigRc $( rigText )" '0 🔧 *_keeper-myx_* @keeper-myx → @here.\nRIG-BODY'
rigWorldPlain ; rigScope "$rigPersona" 'FIRST_NAME=' 'ALIAS='
rigAssert "sibling: an empty scope value is unset, the bullets apply, no warning" "$( rigIndexRow client-ndm ) $( LC_ALL=C grep -c 'WARNING' "$rigTmp/build.err" || : )" 'client-ndm|🐭|Magic|Vane|dispatchr 0'
rigSend client-ndm magic-team
rigAssert "sibling: and the external send goes out"                        "$rigRc $( rigText )" '0 🐭 *_Magic Vane_* @dispatchr → @here.\nRIG-BODY'
rigWorldPlain ; rigScope "$rigPersona" FIRST_NAME=Alexa ALIAS=pr.manager
rigAssert "sibling: valid values are stored, no warning"                   "$( rigIndexRow client-ndm ) $( LC_ALL=C grep -c 'WARNING' "$rigTmp/build.err" || : )" 'client-ndm|🐭|Alexa|Vane|pr.manager 0'
rigSend client-ndm magic-team
rigAssert "sibling: and they are what the external send shows"             "$rigRc $( rigText )" '0 🐭 *_Alexa Vane_* @pr.manager → @here.\nRIG-BODY'
rigWorldPlain ; rigScope "$rigPersona" 'FIRST_NAME=Mary Ann'
rigAssert "sibling: a scope first name with a space is valid, stored with an underscore" "$( rigIndexRow client-ndm ) $( LC_ALL=C grep -c 'WARNING' "$rigTmp/build.err" || : )" 'client-ndm|🐭|Mary_Ann|Vane|dispatchr 0'
rigSend client-ndm magic-team
rigAssert "sibling: and it reads back with the space"                      "$( rigText )" '🐭 *_Mary Ann Vane_* @dispatchr → @here.\nRIG-BODY'

echo "-- 17. non-client members are unchanged: their own bullets and their own scope --"
rigWorldPlain ; rigScope keeper-plain ALIAS=kplain ; rigScope keeper-myx ALIAS=kmyx
rigSend keeper-myx magic-team
rigAssert "an ordinary member's scope alias is its internal sender alias, the member name unchanged" "$( rigText )" '🔧 *_keeper-myx_* @kmyx → @here.\nRIG-BODY'
rigSend keeper-myx magic-team --address-to keeper-plain
rigAssert "an addressee with no Slack account shows its scope alias"       "$( rigText )" '🔧 *_keeper-myx_* @kmyx → 🔨 *_keeper-plain_* @kplain.\nRIG-BODY'
rigAssert "the persona's row and the clients' are not touched by them"     "$( rigIndexRow "$rigPersona" ) $( rigIndexRow client-ndm )" "$rigPersona|🐭|Magic|Vane|dispatchr client-ndm|🐭|Magic|Vane|dispatchr"
rigWorldPlain ; rigScope keeper-plain ALIAS=kplain
rigSend keeper-myx magic-team
rigAssert "control: another member's alias is untouched by it"             "$( rigText )" '🔧 *_keeper-myx_* @forge → @here.\nRIG-BODY'
rigWorldPlain ; rigScope keeper-myx FIRST_NAME=Alexa FAMILY_NAME=Quill
rigAssert "a non-client's own scope names replace its bullets'; the persona is not read for it" "$( rigIndexRow keeper-myx ) $( rigIndexRow "$rigPersona" )" "keeper-myx|🔧|Alexa|Quill|forge $rigPersona|🐭|Magic|Vane|dispatchr"
rigWorldPlain ; rigScope "$rigPersona" FIRST_NAME=Alexa FAMILY_NAME=Quill ALIAS=pr.manager
rigAssert "a persona override does not reach a non-client member"          "$( rigIndexRow keeper-myx ) $( rigIndexRow keeper-plain )" 'keeper-myx|🔧|Forge|Keeper|forge keeper-plain|🔨|Plain|Keeper|plainalias'
rigWorldPlain
for rigName in "Zoë" "Борис" "Ünal" ; do
	rigScope "$rigPersona" "FIRST_NAME=$rigName"
	rigSend client-ndm magic-team
	rigAssert "$rigName in the persona's FIRST_NAME: in the text, exactly" "$rigRc $( rigText )" "0 🐭 *_$rigName Vane_* @dispatchr → @here.\\nRIG-BODY"
	rigAssert "$rigName in the persona's FIRST_NAME: in the blocks, exactly" "$( rigBodyHas "\"text\":\"$rigName Vane\",\"style\":{\"bold\":true,\"italic\":true}" )" 1
	rigWorldPlain
done

echo "-- 17b. the Name shapes of the persona's bullet --"
rigShape(){ ## label, Name text as written (empty: no line), first, family, warnings (fields missing)
	rigWorld ; rigBullets "$rigPersona" "$2" dispatchr 🐭 ; rigBuild
	rigAssert "$1: the persona's own row"                                  "$( rigIndexRow "$rigPersona" )" "$rigPersona|🐭|$3|$4|dispatchr"
	rigAssert "$1: warnings, as the persona and as a member"               "$( rigWarnsOf "persona member $rigPersona: required field" ) $( rigWarnsOf "indices: member $rigPersona: required field" )" "$5 $5"
	rigSend client-ndm magic-team
	if [ "$5" = 0 ] ; then
		rigAssert "$1: the clients' rows are the persona's, and the external header is the name read back" "$( rigIndexRow client-ndm ) $rigRc $( rigText )" "client-ndm|🐭|$3|$4|dispatchr 0 🐭 *_$3 ${4//_/ }_* @dispatchr → @here.\\nRIG-BODY"
	else
		rigAssert "$1: the clients' rows are dashes, the external send refused with nothing posted" "$( rigIndexRow client-ndm ) $rigRc $( rigNoCalls )" "client-ndm|-|-|-|- 1 0"
	fi
}
rigShape "two words with a final period" 'Magic Vane.' Magic Vane 0
rigShape "two words, no period" 'Magic Vane' Magic Vane 0
rigShape "one word with a period" 'Magic.' Magic - 1
rigShape "one word" 'Magic' Magic - 1
rigShape "three words" 'Mary Ann Smith.' Mary Ann_Smith 0
rigShape "a hyphenated word and an apostrophe" "Jean-Luc D'Arc." Jean-Luc D\'Arc 0
rigShape "in backticks" '`Magic Vane`.' Magic Vane 0
rigShape "a prose line with a comma" 'Magic Vane, the dispatcher.' - - 2
rigShape "a prose line with a bracket" 'Magic Vane (the dispatcher).' - - 2
rigShape "a prose line with a second sentence" 'Magic Vane. The dispatcher.' - - 2
rigShape "a double space" 'Magic  Vane.' - - 2
rigShape "a colon" 'Magic: Vane' - - 2
rigShape "an at sign" 'Magic V@ne.' - - 2
rigShape "no Name line" '' - - 2
rigShape "a localised name" 'Zauberer Müller.' Zauberer Müller 0
rigWorld

echo "-- 17c. an Alias bullet with a space or a quote --"
rigWorld ; rigBullets keeper-as 'As Name.' 'bad alias' 🔧 ; rigLinkAdd keeper-as "$rigWsName" ; rigBuild
rigAssert "an Alias bullet with a space is cut at the space by the marks function, which stays as it was: the first word is the alias" "$( rigIndexRow keeper-as )" 'keeper-as|🔧|As|Name|bad'
rigAssert "and does not warn, because what the registry reads is the marks function's output" "$( rigWarnsOf 'member keeper-as:' )" 0
rigWorld ; rigBullets "$rigPersona" 'Magic Vane.' 'dis"patchr' 🐭 ; rigBuild
rigAssert "a persona Alias bullet with a double quote is absent, and the clients' rows are dashes" "$( rigIndexRow "$rigPersona" ) $( rigIndexRow client-ndm )" "$rigPersona|🐭|Magic|Vane|- client-ndm|-|-|-|-"
rigWorld

echo "-- 18. static: the send reads team-members-names, the persona is named in one place --"
rigNamers(){ ## file, pattern -- the functions holding a non-comment line that matches the pattern, one line, sorted
	LC_ALL=C awk -v pat="$2" '/^case "\$1" in/ { fn = "(send dispatcher arm)" } /^[A-Za-z0-9_]+\(\)[ \t]*\{/ { fn = $1 ; sub(/\(\).*/, "", fn) } $0 ~ pat && $0 !~ /^[ \t]*#/ && fn != "" { print fn }' "$1" | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' '
}
rigFnCut(){ ## file, function name -- that function's text, from its first line to its closing brace
	LC_ALL=C awk -v name="$2" 'index( $0, name "(){" ) == 1 { on = 1 } on { print } on && /^}/ { exit }' "$1"
}
rigAssert "the Slack include names no basic.md path in code"               "$( rigNamers "$rigInclude" '[.]basic[.]md' )" ""
rigAssert "the registries include names a basic.md path in the marks function and the Name bullet function only" "$( rigNamers "$rigRegInclude" '[.]basic[.]md' )" "AgentsToolsCommsSlackMemberMarks AgentsToolsRegistryMemberNameBullet "
rigAssert "the registries include reads a member's scope in one function only" "$( rigNamers "$rigRegInclude" '--member-config-option' )" "AgentsToolsRegistryMemberNamesRead "
rigAssert "the Slack include names no presentation scope key at all"       "$( LC_ALL=C grep -c -E 'FIRST_NAME|FAMILY_NAME|--select[ \"]*ALIAS' "$rigInclude" || : )" 0
printf 'F(){\n\tx="$d/.basic.md"\n}\nG(){\n\ty="$d/.basic.md"\n}\n# the .basic.md again in a comment\n' > "$rigTmp/sample.include"
rigAssert "control: a sample with two functions naming a basic.md is caught, a comment is not" "$( rigNamers "$rigTmp/sample.include" '[.]basic[.]md' )" "F G "
rigReadFn="$( rigFnCut "$rigInclude" AgentsToolsCommsSlackMemberPresentation )"
rigAssert "control: the presentation function was cut out of the include"  "$( printf '%s\n' "$rigReadFn" | LC_ALL=C grep -c '^AgentsToolsCommsSlackMemberPresentation(){' || : )" 1
rigAssert "the presentation function names the names registry, once"       "$( printf '%s\n' "$rigReadFn" | LC_ALL=C grep -c "$rigNamesName" || : )" 1
rigAssert "and no skill file, basic file, scope file, linked index or config read" "$( printf '%s\n' "$rigReadFn" | LC_ALL=C grep -v '^[[:space:]]*#' | LC_ALL=C grep -c -E 'SKILL[.]md|basic[.]md|agent[.]env|config-option|--select|linked|team-members[.]|AgentsToolsRegistryTeamMembersRows' || : )" 0
rigAssert "control: the same pattern does find those in the names read function" "$( [ "$( rigFnCut "$rigRegInclude" AgentsToolsRegistryMemberNamesRead | LC_ALL=C grep -v '^[[:space:]]*#' | LC_ALL=C grep -c -E 'config-option|--select' || : )" -gt 0 ] && printf found || printf blind )" found
rigAssert "the persona member is assigned once in the registries include, as a whole line" "$( LC_ALL=C grep -c -x "registryPersonaMember=\"$rigPersona\"" "$rigRegInclude" || : ) $( LC_ALL=C grep -c '^registryPersonaMember=' "$rigRegInclude" || : )" "1 1"
rigAssert "and its literal name is written nowhere else in the registries include code" "$( LC_ALL=C grep -v '^[[:space:]]*#' "$rigRegInclude" | LC_ALL=C grep -c -F -- "$rigPersona" || : )" 1
rigAssert "the client branch names the constant, not a member: no literal member name in the Rows function" "$( rigFnCut "$rigRegInclude" AgentsToolsRegistryTeamMembersNamesRows | LC_ALL=C grep -v '^[[:space:]]*#' | LC_ALL=C sed -e 's/"magic-team"//g' -e 's/"human-owner"//g' | LC_ALL=C grep -c -E '(magic|keeper|partner)-[a-z]' || : ) $( [ "$( rigFnCut "$rigRegInclude" AgentsToolsRegistryTeamMembersNamesRows | LC_ALL=C grep -c 'registryPersonaMember' || : )" -gt 0 ] && printf names-it || printf blind )" "0 names-it"
rigAssert "the Slack include holds no assignment of it"                    "$( LC_ALL=C grep -c -E 'registryPersonaMember=' "$rigInclude" || : )" 0
printf 'registryPersonaMember="a"\nregistryPersonaMember="b"\n' > "$rigTmp/sample.include"
rigAssert "control: a sample with two assignments counts two"              "$( LC_ALL=C grep -c '^registryPersonaMember=' "$rigTmp/sample.include" || : )" 2
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
rigMakeInclude="$rigHere/AgentsTools.Make.include"
rigAssert "the builder is in builders/source-prepare of the agents package" "$( [ -f "$rigBuilder" ] && printf present || printf absent ) $( ls "$rigPackage/builders" )" "present source-prepare"
rigAssert "and nothing of it is under sh-lib"                              "$( [ -e "$rigHere/builders" ] && printf present || printf absent ) $( ls "$rigHere" | LC_ALL=C grep -c -F -- "$rigBuilderName" || : )" "absent 0"
rigAssert "the builder runs the build once, as the bare agents script name"  "$( rigN "$rigBuilder" "$rigOpName" ) $( LC_ALL=C grep -c -x -F -- "DistroAgentsTools.fn.sh $rigOpName" "$rigBuilder" || : )" "1 1"
rigAssert "the Local Tools script holds no call of the build, in any spelling" "$( LC_ALL=C grep -c -E -- 'make-agents-indices|1201-agents-indices|agents-indices' "$rigLocalTools" || : )" 0
rigAssert "control: the same pattern does find the build's name in a sample"  "$( printf 'x --make-agents-indices\n' > "$rigTmp/sample.sh" ; LC_ALL=C grep -c -E -- 'make-agents-indices|agents-indices' "$rigTmp/sample.sh" || : )" 1
rigWsArm="$( LC_ALL=C awk '/^\t--make-workspace-integrations\)/ { on = 1 } on { print } on && /^\t;;/ { exit }' "$rigMakeInclude" )"
rigAssert "control: the make-workspace-integrations arm was cut out of the Make include" "$( printf '%s\n' "$rigWsArm" | LC_ALL=C grep -c -F -- '--install-workspace-integrations' || : )" 1
rigAssert "the arm calls the build once"                                   "$( printf '%s\n' "$rigWsArm" | LC_ALL=C grep -v '^[[:space:]]*#' | LC_ALL=C grep -c -F -- "$rigOpName" || : )" 1
rigAssert "the call is a whole line, with the failure return and no \"\$@\""  "$( printf '%s\n' "$rigWsArm" | LC_ALL=C grep -c -x -F -- "$( printf '\t\t' )DistroAgentsTools $rigOpName || { set +e ; return 1 ; }" || : )" 1
rigFirstCall="$( printf '%s\n' "$rigWsArm" | LC_ALL=C awk '/^\t\tDistroAgentsTools / { print $2 ; exit }' )"
rigAssert "it is the first DistroAgentsTools call of the arm"              "$rigFirstCall" "$rigOpName"
rigAssert "and it comes before --make-console-command and --install-workspace-integrations" "$( printf '%s\n' "$rigWsArm" | LC_ALL=C awk -v op="$rigOpName" '$0 ~ "DistroAgentsTools " op { a = NR } /DistroAgentsTools --make-console-command/ { b = NR } /DistroAgentsTools --install-workspace-integrations/ { c = NR } END { print ( a > 0 && a < b && b < c ) ? "ordered" : "not ordered" }' )" ordered
rigAssert "control: a sample with the call after the console command is not ordered" "$( printf '\t\tDistroAgentsTools --make-console-command\n\t\tDistroAgentsTools %s\n\t\tDistroAgentsTools --install-workspace-integrations\n' "$rigOpName" | LC_ALL=C awk -v op="$rigOpName" '$0 ~ "DistroAgentsTools " op { a = NR } /DistroAgentsTools --make-console-command/ { b = NR } /DistroAgentsTools --install-workspace-integrations/ { c = NR } END { print ( a > 0 && a < b && b < c ) ? "ordered" : "not ordered" }' )" "not ordered"
rigRunBuilder(){ ## agents scripts directory on the path or none -- the builder run as the source-prepare build runs it, the rig workspace as the workspace; rc in rigRc
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="${1:+$1:}$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" sh "$rigBuilder" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigWorld ; rm -f "$rigNamesFile" "$rigMembersFile"
rigRunBuilder "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts"
rigAssert "the builder, run with the agents scripts on the path, builds both registries" "$rigRc $( [ -s "$rigMembersFile" ] && printf written || printf missing ) $( [ -s "$rigNamesFile" ] && printf written || printf missing ) $( rigIndexRow client-ndm )" '0 written written client-ndm|🐭|Magic|Vane|dispatchr'
rigAssert "and says what it builds on stderr, nothing on stdout"            "$( rigN "$rigTmp/err" 'Build: make agents indices' ) $( rigLines "$rigTmp/out" )" "1 0"
rm -f "$rigNamesFile" "$rigMembersFile"
rigRunBuilder ""
rigAssert "control: with the agents scripts not on the path the builder fails 127 and builds nothing, so the rows above measure the path" "$rigRc $( [ -e "$rigNamesFile" ] && printf written || printf none )" "127 none"

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

echo "-- 18. a member with no person name by design is not warned about --"
rigWorld
rigBullets magic-team 'The Conclave is the name of the team, a prose line.' conclave ⚛️ ; rigSkill magic-team active
rigBullets human-owner '' '' '' ; rigSkill human-owner active
rigBullets keeper-w1 'Cher.' cher 🔧
for rigMember in magic-team human-owner keeper-w1 ; do rigLinkAdd "$rigMember" "$rigWsName" ; done
rigBuild
rigAssert "magic-team and human-owner have rows, with dashes for the names the bullets do not give" "$( rigIndexRow magic-team ) $( rigIndexRow human-owner )" 'magic-team|⚛️|-|-|conclave human-owner|-|-|-|-'
rigAssert "and no warning names either of them, active or not"             "$( rigWarnsOf 'member magic-team:' ) $( rigWarnsOf 'member human-owner:' )" "0 0"
rigAssert "a normal member is warned, in the build's own line: the member name exactly as the roster writes it" "$( LC_ALL=C grep -c -F -x '⚠️ WARNING: DistroAgentsTools --make-agents-indices: member keeper-w1: required field family-name is missing or not valid in its basic.md (a Name bullet of plain words, or its scope key)' "$rigTmp/build.err" || : )" 1
rigWorld

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SLACK CLIENT PERSONA CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SLACK_CLIENT_PERSONA: OK (%d assertions, offline)\n' "$rigPasses"
