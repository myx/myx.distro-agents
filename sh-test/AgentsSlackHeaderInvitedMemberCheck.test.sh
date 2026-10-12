#!/usr/bin/env bash
## Behavioural check on the author line of a member message for a member invited from another
## workspace. Its mark and alias come from the workspace the member is set up in: the names
## registry of the workspace a send runs from holds that workspace's own members only, so an
## invited member is read from the registry of its own workspace, as sender and as addressee
## alike. A member with no row in either is posted under its identifier, with no mark, and one
## line on stderr says so. The seen fault: an invited keeper posting as `*keeper* @keeper`,
## with no mark and its identifier as its alias, silently. Controls: a member set up here
## keeps its own row, and the registry of the other workspace is only read.
## Offline: two workspaces in one rig tree, a rig HOME with the machine's members index, and a
## Slack-shaped fake curl first on PATH.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigTool="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigTest="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
rigTmp="$( mktemp -d -t AgentsSlackHeaderInvitedMemberCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWork="$rigTmp/work" ; rigHome="$rigTmp/home"
rigIndexFile="$rigHome/.agents/magic-team/members.registry"
rigListFile="$rigHome/.agents/magic-team/known-workspaces.registry"
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/member-workspace-check.curl.test.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigTest/check-fixtures/member-workspace-check.curl.test.sh"
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
## ws-here, the workspace every send below runs from, and ws-there. A member is set up in a
## workspace by its own directory in that workspace's source, linked into that workspace's
## member set view, and by its row in the machine's members index.
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
	local wsName
	for wsName in ws-here ws-there ; do mkdir -p "$rigWork/$wsName/.local/.agents" "$rigWork/$wsName/.local/agents/members" ; done
	mkdir -p "${rigIndexFile%/*}" ; : > "$rigIndexFile"
	rigMemberAt ws-here keeper-here source-symlink
	rigMemberAt ws-here magic-team source-symlink ; rigMemberAt ws-there magic-team origin-symlink
	rigMemberAt ws-here human-owner source-symlink ; rigMemberAt ws-there human-owner origin-symlink
	rigMemberAt ws-there keeper-there source-symlink
	rigMemberAt ws-there keeper-norow source-symlink
	printf '%s\n' "$rigWork/ws-here" "$rigWork/ws-there" > "$rigListFile"
	printf '%s\n' 'SLACK_CHANNEL_MAGIC_TEAM=CHERE0001' 'SLACK_CHANNEL_HUMAN_OWNER=UHEREOWNER' 'SLACK_BOT_TOKEN=rig-bot-token-HERE' > "$rigWork/ws-here/.local/.agents/magic-team.agent.env"
	printf '%s\n' 'SLACK_CHANNEL_MAGIC_TEAM=CTHERE0001' 'SLACK_CHANNEL_HUMAN_OWNER=UTHEREOWNER' 'SLACK_BOT_TOKEN=rig-bot-token-THERE' > "$rigWork/ws-there/.local/.agents/magic-team.agent.env"
	## Each workspace's own names registry: its own members only.
	printf '%s\n' 'human-owner :rig-owner: - - -' 'keeper-here 🔧 Hera Keeper herakeep' 'magic-team :rig-team: - - -' > "$( rigNames ws-here )"
	printf '%s\n' 'human-owner :rig-owner: - - -' 'keeper-there 🌾 Thea Vance farmhand' 'magic-team :rig-team: - - -' > "$( rigNames ws-there )"
	: > "$rigTmp/calls" ; : > "$rigTmp/envs" ; : > "$rigTmp/bodies"
}
rigRunIn(){ ## workspace, args... -- one dispatcher call from that workspace; stdout in out, stderr in err, rc in rigRc
	: > "$rigTmp/calls" ; : > "$rigTmp/envs" ; : > "$rigTmp/bodies"
	rigRc=0
	( cd "$rigWork/$1" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/$1" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" \
		bash "$rigTool" "${@:2}" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigText(){ ## -- the text field of the first posted body, escapes as sent
	LC_ALL=C sed -n '1s/^{"channel":"[^"]*","text":"//; 1s/","blocks":.*//; 1s/"}$//; 1p' "$rigTmp/bodies"
}
rigPosts(){ ## -- how many posts were made
	LC_ALL=C grep -c '^chat.postMessage ' "$rigTmp/calls" 2> /dev/null || :
}
rigNoRowLines(){ ## member -- how many lines of the last call's stderr say that member has no row
	LC_ALL=C grep -c -F -- "member '$1' has no row in the team-members-names registry" "$rigTmp/err" 2> /dev/null || :
}
rigSum(){ ## file
	cksum < "$1" 2> /dev/null
}

rigWorld
[ -d "$( rigView ws-there )/keeper-there" ] && [ ! -e "$( rigView ws-here )/keeper-there" ] || rigRefuse "the fixture does not hold the invited member in its own workspace's view only"
LC_ALL=C grep -q '^keeper-there ' "$( rigNames ws-here )" && rigRefuse "the fixture's calling workspace has a row for the invited member, so no row below would show where a row is read from"
rigRunIn ws-here --member-comms-slack-send-message keeper-here magic-team RIG-BODY
[ "$rigRc" = 0 ] && [ "$( rigPosts )" = 1 ] || rigRefuse "the baseline send of a member set up here did not post, so no row below would be measured: rc=$rigRc $( LC_ALL=C grep -m1 -E 'ERROR|WARNING' "$rigTmp/err" )"

echo "-- control: a member set up here posts under its own row of this workspace's registry --"
rigAssert "its mark and alias are its row's"                "$( rigText )" '🔧 *_keeper-here_* @herakeep → @here.\nRIG-BODY'
rigAssert "and nothing is said about a row"                 "$( rigNoRowLines keeper-here )" 0

echo "-- a member invited from another workspace: its mark and alias come from the workspace it is set up in --"
rigThereSum="$( rigSum "$( rigNames ws-there )" )"
rigRunIn ws-here --member-comms-slack-send-message keeper-there magic-team RIG-BODY
rigAssert "its send is made from here, once"                "$rigRc $( rigPosts )" "0 1"
rigAssert "its author line carries the mark and alias of its row there, never its identifier as its alias" "$( rigText )" '🌾 *_keeper-there_* @farmhand → @here.\nRIG-BODY'
rigAssert "and nothing is said about a row: it has one"     "$( rigNoRowLines keeper-there )" 0
rigRunIn ws-here --member-comms-slack-send-message keeper-here magic-team --address-to keeper-there RIG-BODY
rigAssert "addressed by a member set up here, it is named by the same row" "$rigRc $( rigText )" '0 🔧 *_keeper-here_* @herakeep → 🌾 *_keeper-there_* @farmhand.\nRIG-BODY'
rigAssert "the registry of the workspace it is set up in is only read" "$( rigSum "$( rigNames ws-there )" )" "$rigThereSum"
rigAssert "and this workspace's registry gets no row for it" "$( LC_ALL=C grep -c '^keeper-there ' "$( rigNames ws-here )" )" 0

echo "-- a member with no row anywhere: its identifier, and one line that says so --"
rigRunIn ws-here --member-comms-slack-send-message keeper-norow magic-team RIG-BODY
rigAssert "it is still posted, once"                        "$rigRc $( rigPosts )" "0 1"
rigAssert "under its identifier, with no mark"              "$( rigText )" '*_keeper-norow_* @keeper-norow → @here.\nRIG-BODY'
rigAssert "and one line on stderr says it has no row, here or where it is set up" "$( rigNoRowLines keeper-norow )" 1
rigAssert "that line names the workspace the send ran from and what builds the registry" \
	"$( LC_ALL=C grep -F -- "member 'keeper-norow' has no row" "$rigTmp/err" | LC_ALL=C grep -c -F -- "$rigWork/ws-here" ):$( LC_ALL=C grep -F -- "member 'keeper-norow' has no row" "$rigTmp/err" | LC_ALL=C grep -c -F -- '--make-agents-indices' )" "1:1"
rm -f "$( rigNames ws-there )"
rigRunIn ws-here --member-comms-slack-send-message keeper-there magic-team RIG-BODY
rigAssert "with no registry at all in the workspace it is set up in: its identifier, and the same one line" "$rigRc $( rigText ) $( rigNoRowLines keeper-there )" '0 *_keeper-there_* @keeper-there → @here.\nRIG-BODY 1'

rigAssert "no request left this box: every call went to the fake curl" "$( LC_ALL=C awk '$1 == "http" { hitCount++ ; } END { print hitCount + 0 ; }' "$rigTmp/calls" )" 0

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SLACK HEADER INVITED MEMBER CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2
	echo "  warn: a member invited from another workspace posts with no mark and its identifier as its alias, or a member with no row anywhere is posted so in silence" >&2
	echo "  fix:  repair AgentsToolsCommsSlackMemberPresentation in sh-lib/AgentsTools.MemberCommsSlack.include -- never the assertion" >&2
	exit 1
fi
printf 'SLACK_HEADER_INVITED_MEMBER: OK (%d assertions, offline)\n' "$rigPasses"
