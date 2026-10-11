#!/usr/bin/env bash
## Behavioural check on the rule a team-member operation runs by, run rather than read, against a fixture machine built
## here: a HOME holding the machine-wide member directory (member, workspace root, link kind, path, member directory) and
## the tracked workspaces list (absolute paths), both in $HOME/.agents/magic-team, and several workspace directories under
## one rig tree, each with its own member set view, settings scopes, names registry and console. The rule held: WE RUN
## FROM HERE. An operation naming a team member runs in the workspace it was called from, for everything: that
## workspace's settings for the member (none there means none), its team data, its records and its Slack. A member set
## up only in another workspace on this machine is invited: its skillset alone is read from the workspace it is set up
## in, the call is re-run exactly once under that member set root, and it is stopped only when that part cannot be
## brought, by a message naming what is missing and where it was looked for. A spawn of an invited member is launched by
## the console of the workspace it was called from, with MMDAPP that workspace and the member set root the member's own
## workspace view, its record, items and thread where it was asked; it retries and closes as any spawn. A client-* member
## is the one exception, kept as it was until it is ruled on: its whole operation, and its session, run in the workspace
## that holds it. Where a member is set up is the resolver's answer, unchanged: the current workspace when the member is
## there, else the workspace where it is a source link, else the first tracked one that has it; a member the index does
## not know is not refused, and a current workspace the index has no row for resolves nothing. A known member in no
## tracked workspace, a chosen path not on this machine, a member directory missing from its workspace, and the team's
## own folder missing from the view an invited member would work from, are named refusals, each with an accepted
## sibling; and a file an operation needs that its view cannot give stops it by name, never an empty result. Offline: a fake `curl` first on PATH logs each call with the environment it
## ran in, a fake console records where it was started and the member set root it was given. What the stubs cannot show:
## a real second machine's index, real Slack and Atlassian answers, and a real agent session of an invited member.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigPackage="${rigHere%/sh-lib}"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigResolveInclude="$rigHere/AgentsTools.MemberWorkspace.include"
rigSpawnInclude="$rigHere/AgentsTools.InternOpAgentSpawnProxy.include"
rigRealTemplate="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/templates/spawn-brief.document.format.md"
rigResolveFn="AgentsToolsMemberWorkspaceResolve"
rigSwitchFn="AgentsToolsWorkspaceSwitch"
rigBringFn="AgentsToolsMemberSkillsetBring"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigResolveInclude" ] || rigRefuse "the member workspace include is not at: $rigResolveInclude"
[ -f "$rigRealTemplate" ] || rigRefuse "the brief template is not in the package: $rigRealTemplate"
rigTmp="$( mktemp -d -t AgentsMemberWorkspaceCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## A loop in the code under test must end the check rather than hang it: nothing here legitimately runs long.
( sleep 900 ; kill -TERM $$ 2> /dev/null ) > /dev/null 2>&1 &
rigDog=$!
## The watchdog itself is stopped before its sleep: a sleep ended first would let it signal a check that finished.
trap 'rigDogSleep="$( pgrep -P "$rigDog" 2> /dev/null )" ; kill "$rigDog" 2> /dev/null ; [ -z "$rigDogSleep" ] || kill $rigDogSleep 2> /dev/null ; wait "$rigDog" 2> /dev/null ; chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWork="$rigTmp/work" ; rigHome="$rigTmp/home" ; rigElsewhere="$rigHome/elsewhere/members"
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
## Workspaces: ws-here (the current one), ws-there (holds keeper-there and client-ndm, source links), ws-third, ws-rig (a
## rig workspace the index has no row for), ws-gone (listed, no directory). A member is set up in a workspace by its own
## directory in that workspace's source, linked into that workspace's member set view; its skill file says where it is.
## A member's scope file in a workspace says which workspace's settings were read. rigElsewhere is a member set root
## that is no workspace's view, as a caller may carry one.
rigMemberFiles(){ ## directory, member, where -- a member directory with the files a help, a send or a spawn reads; its skill file says where it is
	mkdir -p "$1"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$1/$2.basic.md"
	printf '# rig armed\n' > "$1/$2.armed.md"
	printf -- '---\nname: %s\n---\n\n# %s, set up in %s\n' "$2" "$2" "$3" > "$1/SKILL.md"
}
rigMemberHome(){ ## workspace, member -- that member's own directory in that workspace's source
	printf '%s\n' "$rigWork/$1/source/myx/pkg/skillset/$2"
}
rigView(){ ## workspace -- its member set view, which holds its own members only
	printf '%s\n' "$rigWork/$1/.local/agents/members"
}
rigTeamRoutine(){ ## the team's own directory -- the one coworking routine in it, which a session names by default
	printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator\ninvitees: magic-team\ndefault-for-session-kind: coworking\n---\n# rig coworking routine fixture\n' > "$1/magic-team.coworking.routine.md"
}
rigMemberAt(){ ## workspace, member -- that member set up in that workspace: its directory there, linked into the view; the team's own folder with its routine, since an invited member's session reads the team's files from its own workspace's view
	rigMemberFiles "$( rigMemberHome "$1" "$2" )" "$2" "$1"
	[ "$2" != magic-team ] || rigTeamRoutine "$( rigMemberHome "$1" "$2" )"
	mkdir -p "$( rigView "$1" )"
	ln -sfn "$( rigMemberHome "$1" "$2" )" "$( rigView "$1" )/$2"
}
rigIdx(){ ## member, workspace, link kind -- one row of the members index, and the member set up there when that workspace is on the machine
	## The row carries the workspace root; ws-gone's is where the list says it was.
	local idxWs="$2"
	[ "$2" != ws-gone ] || idxWs="gone/ws-gone"
	mkdir -p "${rigIndexFile%/*}"
	printf '%s\t%s\t%s\tmyx/pkg/skillset/%s\t%s\n' "$1" "$rigWork/$idxWs" "$3" "$1" "$( rigMemberHome "$idxWs" "$1" )" >> "$rigIndexFile"
	[ ! -d "$rigWork/$idxWs" ] || rigMemberAt "$idxWs" "$1"
}
rigScopeOf(){ ## workspace, member, lines... -- that member's scope file in that workspace
	local scopeWs="$1" scopeMember="$2" ; shift 2
	mkdir -p "$rigWork/$scopeWs/.local/.agents"
	printf '%s\n' "$@" > "$rigWork/$scopeWs/.local/.agents/$scopeMember.agent.env"
}
rigConsole(){ ## workspace, label -- a console that records where it was started, the member set root it was given and what it was given
	printf '%s\n' '#!/usr/bin/env bash' \
		'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records where it was started.' \
		"printf '%s\\n' \"\$MMDAPP\" > \"\$RIG_SCENARIO/launched.$2\"" \
		"printf '%s=%s\\n' \"\${MDAT_SPAWN_AGENT:-none}\" \"\${MDAT_SKILLSET_ROOT:-unset}\" >> \"\$RIG_SCENARIO/roots.$2\"" \
		'cat > "$RIG_SCENARIO/brief.'"$2"'"' \
		'printf "📦 SubagentHandback\n"' \
		'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWork/$1/DistroAgentsConsole.sh"
	chmod +x "$rigWork/$1/DistroAgentsConsole.sh"
}
rigWorld(){ ## -- a fresh machine: workspaces, members, scopes, registries, the members index and the tracked list
	rm -rf "$rigWork" "$rigHome"
	mkdir -p "$rigElsewhere" "$rigWork/decoy"
	local wsName memberName
	for wsName in ws-here ws-there ws-third ws-rig ; do mkdir -p "$rigWork/$wsName/.local/.agents" "$rigWork/$wsName/.local/agents/members" ; done
	## a member set root set somewhere else, as a caller may carry one: every member it holds in one folder
	for memberName in keeper-here keeper-there keeper-nowhere client-ndm magic-team human-owner magic-coordinator ; do rigMemberFiles "$rigElsewhere/$memberName" "$memberName" elsewhere ; done
	## the members index: who is set up where, and how
	mkdir -p "${rigIndexFile%/*}" ; : > "$rigIndexFile"
	rigIdx keeper-here ws-here source-symlink
	rigIdx keeper-both ws-here origin-symlink ; rigIdx keeper-both ws-there source-symlink
	rigIdx client-ndm ws-there source-symlink
	rigIdx keeper-multi ws-there origin-symlink ; rigIdx keeper-multi ws-third source-symlink
	rigIdx keeper-nosrc ws-there origin-symlink ; rigIdx keeper-nosrc ws-third .local-symlink
	rigIdx keeper-nowhere ws-nolist source-symlink
	rigIdx keeper-gone ws-gone source-symlink
	rigIdx keeper-gonemix ws-gone source-symlink ; rigIdx keeper-gonemix ws-there origin-symlink
	rigIdx keeper-pre ws-the source-symlink
	rigIdx keeper-rel ws-rel source-symlink
	rigIdx keeper-there ws-there source-symlink
	rigIdx human-owner ws-here source-symlink ; rigIdx human-owner ws-there origin-symlink
	rigIdx magic-team ws-here source-symlink ; rigIdx magic-team ws-there origin-symlink
	rigIdx magic-coordinator ws-here source-symlink
	## set up, and on no index: a member the machine's index was never told of, the team's own folder in ws-third's view, and a rig workspace's own copies of whoever is run in it
	rigMemberAt ws-here keeper-unknown
	rigMemberAt ws-third magic-team
	for memberName in client-ndm keeper-there magic-team ; do rigMemberAt ws-rig "$memberName" ; done
	rigTeamRoutine "$rigElsewhere/magic-team"
	## the tracked workspaces: a trailing slash, a longer decoy name, a relative line, a comment, a blank line, a missing directory
	printf '%s\n' "$rigWork/ws-here" "$rigWork/ws-there/" "$rigWork/decoy/ws-there-old" "# a comment" "" "ws-rel" "$rigWork/ws-third" "$rigWork/gone/ws-gone" > "$rigListFile"
	## each workspace's own scope: where a member is, its tokens, its channels, and the Slack its team is in
	rigScopeOf ws-here magic-team 'SLACK_CHANNEL_MAGIC_TEAM=CHERE0001' 'SLACK_CHANNEL_HUMAN_OWNER=UHEREOWNER' 'SLACK_BOT_TOKEN=rig-bot-token-HERE' 'SLACK_WORKSPACE_DOMAIN=here.slack.invalid'
	rigScopeOf ws-here keeper-here 'WHERE=ws-here' 'SLACK_USER_TOKEN=rig-user-token-KHERE'
	rigScopeOf ws-here keeper-both 'WHERE=ws-here' 'SLACK_USER_TOKEN=rig-user-token-KBOTHHERE'
	rigScopeOf ws-here magic-coordinator 'WHERE=ws-here' 'SLACK_USER_TOKEN=rig-user-token-COORDHERE'
	rigScopeOf ws-there magic-team 'SLACK_CHANNEL_MAGIC_TEAM=CTHERE0001' 'SLACK_CHANNEL_HUMAN_OWNER=UTHEREOWNER' 'SLACK_BOT_TOKEN=rig-bot-token-THERE' 'SLACK_WORKSPACE_DOMAIN=there.slack.invalid'
	rigScopeOf ws-there client-ndm 'WHERE=ws-there' 'SLACK_USER_TOKEN=rig-user-token-NDMTHERE' 'JIRA_SITE=jira-there.invalid' 'JIRA_USER=ndm@rig.invalid' 'JIRA_API_TOKEN=rig-jira-token-THERE'
	rigScopeOf ws-there keeper-both 'WHERE=ws-there' 'SLACK_USER_TOKEN=rig-user-token-KBOTHTHERE'
	rigScopeOf ws-there keeper-multi 'WHERE=ws-there'
	rigScopeOf ws-there keeper-nosrc 'WHERE=ws-there'
	rigScopeOf ws-there keeper-there 'WHERE=ws-there' 'SLACK_USER_TOKEN=rig-user-token-KTHERE'
	rigScopeOf ws-there magic-coordinator 'WHERE=ws-there' 'SLACK_USER_TOKEN=rig-user-token-COORDTHERE'
	rigScopeOf ws-third keeper-multi 'WHERE=ws-third'
	rigScopeOf ws-third keeper-nosrc 'WHERE=ws-third'
	rigScopeOf ws-third magic-team 'SLACK_CHANNEL_MAGIC_TEAM=CTHIRD0001' 'SLACK_BOT_TOKEN=rig-bot-token-THIRD'
	rigScopeOf ws-rig magic-team 'SLACK_CHANNEL_MAGIC_TEAM=CRIG000001' 'SLACK_BOT_TOKEN=rig-bot-token-RIG'
	rigScopeOf ws-rig client-ndm 'WHERE=ws-rig' 'SLACK_USER_TOKEN=rig-user-token-NDMRIG' 'JIRA_SITE=jira-rig.invalid' 'JIRA_USER=rig@rig.invalid' 'JIRA_API_TOKEN=rig-jira-token-RIG'
	## each workspace's own names registry: what a send there reads
	printf '%s\n' 'keeper-here 🔧 Hera Keeper herakeep' 'keeper-both 🔧 Both Keeper bothkeep' > "$rigWork/ws-here/.local/agents/team-members-names.registry"
	printf '%s\n' 'client-ndm 🐭 Magic Vane dispatchr' 'keeper-both 🔧 Both Keeper bothkeep' 'keeper-there 🔧 There Keeper therekeep' > "$rigWork/ws-there/.local/agents/team-members-names.registry"
	printf '%s\n' 'client-ndm 🐭 Rig Persona rigalias' > "$rigWork/ws-rig/.local/agents/team-members-names.registry"
	rigConsole ws-here HERE ; rigConsole ws-there THERE ; rigConsole ws-third THIRD ; rigConsole ws-rig RIG
	## client-ndm's own contacts note in each workspace that holds it: a send presenting into
	## a client workspace passes the outbound contact gate (AgentsToolsContactAssertKnown)
	## only for a listed recipient, and these are the rig's own channels and owners there.
	for wsName in ws-there ws-rig ; do
		mkdir -p "$rigWork/$wsName/.local/agents/team-data-root/inboxes/client-ndm"
		printf '%s\n' \
			'| slack-id | contact | handle | email | organisation | permission level |' \
			'| --- | --- | --- | --- | --- | --- |' \
			'| CTHERE0001 | rig-team-there | @rig-team-there | <unresolved> | rig | unset |' \
			'| UTHEREOWNER | rig-owner-there | @rig-owner-there | <unresolved> | rig | unset |' \
			'| CRIG000001 | rig-team-rig | @rig-team-rig | <unresolved> | rig | unset |' \
			> "$rigWork/$wsName/.local/agents/team-data-root/inboxes/client-ndm/note-rig-contacts.md"
	done
	: > "$rigTmp/calls" ; : > "$rigTmp/envs" ; : > "$rigTmp/bodies"
}
rigIndexOff(){ ## -- the members index and the tracked list set aside, as on a machine that has none
	mv "$rigIndexFile" "$rigIndexFile.off" ; mv "$rigListFile" "$rigListFile.off"
}
rigIndexOn(){ ## -- and back
	mv "$rigIndexFile.off" "$rigIndexFile" ; mv "$rigListFile.off" "$rigListFile"
}
rigListAdd(){ ## path -- one more tracked workspace
	printf '%s\n' "$1" >> "$rigListFile"
}

## ---- running ----
## No member set root is given to a call: each reads its own workspace's view, as a session started there does. rigPre
## adds to a call's environment, a member set root a caller carries among them.
rigPre=()
rigRunIn(){ ## workspace, args... -- one dispatcher call from that workspace; stdout in out, stderr in err, rc in rigRc
	: > "$rigTmp/calls" ; : > "$rigTmp/envs" ; : > "$rigTmp/bodies"
	rigRc=0
	( cd "$rigWork/$1" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/$1" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "${@:2}" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigTraceIn(){ ## workspace, args... -- the same under bash -x; the trace in $rigTmp/trace
	: > "$rigTmp/calls" ; : > "$rigTmp/envs" ; : > "$rigTmp/bodies"
	rigRc=0
	( cd "$rigWork/$1" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/$1" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" ${rigPre[@]+"${rigPre[@]}"} \
		bash -x "$rigTool" "${@:2}" ) > "$rigTmp/out" 2> "$rigTmp/trace" < /dev/null || rigRc=$?
}
rigResolve(){ ## workspace, member, operation -- the resolver on its own; stdout in resOut, stderr in resErr, rc in resRc
	resRc=0
	( env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/$1" MDSC_CMD=RigCmd bash -c '. "$1" ; '"$rigResolveFn"' "$2" "$3"' rig-resolve "$rigResolveInclude" "$2" "${3:-RigOp}" ) > "$rigTmp/resOut" 2> "$rigTmp/resErr" || resRc=$?
	resOut="$( cat "$rigTmp/resOut" )" ; resErr="$( cat "$rigTmp/resErr" )"
}
rigBring(){ ## workspace, member, operation -- the bring on its own, under the member set root rigPre carries, if any; stdout in brOut, stderr in brErr, rc in brRc
	brRc=0
	( env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/$1" MDSC_CMD=RigCmd ${rigPre[@]+"${rigPre[@]}"} bash -c '. "$1" ; '"$rigBringFn"' "$2" "$3"' rig-bring "$rigResolveInclude" "$2" "${3:-RigOp}" ) > "$rigTmp/brOut" 2> "$rigTmp/brErr" || brRc=$?
	brOut="$( cat "$rigTmp/brOut" )" ; brErr="$( cat "$rigTmp/brErr" )"
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
rigTokens(){ ## -- the token of every chat.postMessage, space separated
	LC_ALL=C awk '$1 == "chat.postMessage" { printf "%s ", $2 }' "$rigTmp/calls"
}
rigHistoryToken(){ ## -- the token of every conversations.history or conversations.replies call, space separated
	LC_ALL=C awk '$1 == "conversations.history" || $1 == "conversations.replies" { printf "%s ", $2 }' "$rigTmp/calls"
}
rigEnvOf(){ ## method, field -- that field of the first logged call of that method
	LC_ALL=C awk -v m="$1" -v f="$2" '$1 == m { for ( i = 2 ; i <= NF ; i++ ) { if ( index( $i, f "=" ) == 1 ) { print substr( $i, length( f ) + 2 ) ; exit } } }' "$rigTmp/envs"
}
rigEnvLine(){ ## method -- the whole environment line of the first logged call of that method
	LC_ALL=C awk -v m="$1" '$1 == m { print ; exit }' "$rigTmp/envs"
}
rigHelpNames(){ ## armed file -- how many lines of the last call's stderr name that file as the one a help read
	rigN "$rigTmp/err" "($1)"
}
rigQuiet(){ ## -- how many lines of the last call's stderr say anything about a workspace being changed or a member brought
	LC_ALL=C grep -c -i -E 'switch|tracked|moved to|brought' "$rigTmp/err" || :
}
rigTreeSum(){ ## workspace -- a checksum of the file list and contents under that workspace's own .local, so a write there shows
	( cd "$rigWork/$1/.local" 2> /dev/null && find . -type f 2> /dev/null | LC_ALL=C sort | LC_ALL=C xargs cat 2> /dev/null ; find . -type f 2> /dev/null | LC_ALL=C sort ) | cksum
}

rigWorld
rigRunIn ws-here --agents-config-option keeper-here --select WHERE
[ "$rigRc" = 0 ] && [ "$( cat "$rigTmp/out" )" = "ws-here" ] || rigRefuse "the baseline config select did not answer from the current workspace, so no row below would be measured: rc=$rigRc $( LC_ALL=C grep -m1 -E 'ERROR|WARNING' "$rigTmp/err" )"
rigResolve ws-here client-ndm RigOp
[ "$resRc" = 0 ] && [ -n "$resOut" ] || rigRefuse "the resolver is not callable on its own or does not resolve the baseline member: rc=$resRc $resErr"
rigBring ws-here keeper-there RigOp
[ "$brRc" = 0 ] && [ -n "$brOut" ] || rigRefuse "the bring is not callable on its own or does not bring the baseline member: rc=$brRc $brErr"
[ -d "$( rigView ws-there )/keeper-there" ] && [ ! -e "$( rigView ws-here )/keeper-there" ] || rigRefuse "the fixture does not hold the invited member in its own workspace's view only, so no row below would tell the two views apart"

echo "-- 1. the resolver: the current workspace first, then a source link, then the first tracked --"
rigResolve ws-here keeper-here
rigAssert "a member in the current workspace: nothing printed, no refusal"   "$resRc [$resOut] [$resErr]" "0 [] []"
rigResolve ws-here keeper-both
rigAssert "present here and a source link elsewhere: the current workspace still wins" "$resRc [$resOut] [$resErr]" "0 [] []"
rigResolve ws-here client-ndm
rigAssert "a member only elsewhere, a source link: that workspace's absolute path" "$resRc [$resOut] [$resErr]" "0 [$rigWork/ws-there] []"
rigResolve ws-here keeper-multi
rigAssert "in two other workspaces, the source link listed second wins over the first listed" "$resRc [$resOut]" "0 [$rigWork/ws-third]"
rigResolve ws-here keeper-nosrc
rigAssert "in two other workspaces and no source link: the first tracked one"  "$resRc [$resOut]" "0 [$rigWork/ws-there]"
rigResolve ws-third keeper-both
rigAssert "from another workspace the same member resolves to its source link, not to where the caller is" "$resRc [$resOut]" "0 [$rigWork/ws-there]"
rigResolve ws-there keeper-here
rigAssert "and the other way: a member present only in ws-here resolves there from ws-there" "$resRc [$resOut]" "0 [$rigWork/ws-here]"
rigResolve ws-there keeper-both
rigAssert "a member present in the current workspace of a second pair: no switch" "$resRc [$resOut]" "0 []"
rigAssert "a name is mapped to the tracked line whose last segment equals it, trailing slash dropped, a longer decoy name unused" "$( rigResolve ws-here client-ndm ; printf '%s' "$resOut" )" "$rigWork/ws-there"
rigResolve ws-here keeper-pre
rigAssert "a workspace name that is only a prefix of a tracked one matches nothing: a named refusal" "$resRc [$resOut] $( rigN "$rigTmp/resErr" "member 'keeper-pre' is in the team members index but is present in no tracked workspace" )" "1 [] 1"
rigResolve ws-here keeper-rel
rigAssert "a relative tracked line is not a workspace path: a named refusal"   "$resRc [$resOut]" "1 []"
rigListAdd "$rigWork/ws-rel" ; mkdir -p "$rigWork/ws-rel"
rigResolve ws-here keeper-rel
rigAssert "accepted sibling: with an absolute line for it the same member resolves to it" "$resRc [$resOut]" "0 [$rigWork/ws-rel]"
rigResolve ws-here keeper-unknown
rigAssert "a name the index does not know: not refused, nothing printed"    "$resRc [$resOut] [$resErr]" "0 [] []"
rigResolve ws-third magic-team
rigAssert "magic-team is never resolved, though the index holds rows for it and none where it is asked for" "$resRc [$resOut] [$resErr]" "0 [] []"
rigResolve ws-third human-owner
rigAssert "human-owner is never resolved either"                           "$resRc [$resOut] [$resErr]" "0 [] []"
rigResolve ws-here ''
rigAssert "an empty name is not resolved"                                  "$resRc [$resOut] [$resErr]" "0 [] []"
rigResolve ws-rig client-ndm
rigAssert "a current workspace the index has no row for never switches, whatever the member"  "$resRc [$resOut] [$resErr]" "0 [] []"
rigResolve ws-rig keeper-nowhere
rigAssert "and not even a known member of no tracked workspace is refused there" "$resRc [$resOut] [$resErr]" "0 [] []"
rigIndexOff
rigResolve ws-here client-ndm
rigAssert "no members index at all: nothing printed, no refusal"           "$resRc [$resOut] [$resErr]" "0 [] []"
rigIndexOn
rigResolve ws-here client-ndm RigOpName
rigAssert "control: with the index back the same call resolves"            "$resRc [$resOut]" "0 [$rigWork/ws-there]"
rigWorld

echo "-- 2. the resolver's failure rules, each with an accepted sibling, and what each message names --"
rigResolve ws-here keeper-nowhere --some-op
rigAssert "(a) a known member present in no tracked workspace: rc 1, nothing on stdout" "$resRc [$resOut]" "1 []"
rigAssert "(a) the error names the command, the operation and the member, says nothing was done, then where it was asked for from, where its workspace was looked for and the workspaces the index gives it" "$resErr" "⛔ ERROR: RigCmd --some-op: member 'keeper-nowhere' is in the team members index but is present in no tracked workspace -- nothing was done. It was asked for from $rigWork/ws-here, where it is not set up, and its own workspace was looked for among the tracked workspaces of this machine ($rigHome/.agents/magic-team), which hold none of: $rigWork/ws-nolist"
mkdir -p "$rigWork/ws-nolist" ; rigListAdd "$rigWork/ws-nolist"
rigResolve ws-here keeper-nowhere
rigAssert "(a) accepted sibling: tracked and present on the machine, the same member resolves" "$resRc [$resOut] [$resErr]" "0 [$rigWork/ws-nolist] []"
rigResolve ws-here keeper-gone
rigAssert "(b) a chosen path missing on the machine: rc 1, nothing on stdout"  "$resRc [$resOut]" "1 []"
rigAssert "(b) the error names the member and the path, says nothing was done, then where it was asked for from and what the index says is in the missing workspace" "$resErr" "⛔ ERROR: RigCmd RigOp: the workspace of member 'keeper-gone' is not present on this machine: $rigWork/gone/ws-gone -- nothing was done. It was asked for from $rigWork/ws-here, where it is not set up, and the machine's members index says its skillset and its own access are in that workspace, which is missing."
rigResolve ws-here keeper-gonemix
rigAssert "(b) the source link is chosen and is missing, so it is a refusal rather than a quiet fall back to the other workspace" "$resRc [$resOut] $( rigN "$rigTmp/resErr" "not present on this machine: $rigWork/gone/ws-gone" )" "1 [] 1"
mkdir -p "$rigWork/gone/ws-gone"
rigResolve ws-here keeper-gone
rigAssert "(b) accepted sibling: with the directory there the same member resolves" "$resRc [$resOut] [$resErr]" "0 [$rigWork/gone/ws-gone] []"
rigResolve ws-here keeper-gonemix
rigAssert "(b) and the mixed member too, to its source link"                "$resRc [$resOut]" "0 [$rigWork/gone/ws-gone]"
rigResolve ws-here keeper-unknown
rigAssert "(c) a name not in the index is not refused by the resolver, with the same lists that refuse the others" "$resRc [$resOut] [$resErr]" "0 [] []"
rigWorld ; rm -f "$rigListFile"
rigResolve ws-here client-ndm
rigAssert "(a) no tracked list at all: a member elsewhere is in no tracked workspace"  "$resRc [$resOut] $( rigN "$rigTmp/resErr" "present in no tracked workspace" )" "1 [] 1"
rigResolve ws-here keeper-here
rigAssert "(a) accepted sibling: a member present in the current workspace needs no list"  "$resRc [$resOut] [$resErr]" "0 [] []"
rigWorld

echo "-- 3. the member's part: an invited member's skillset is brought from the workspace it is set up in, and nothing else --"
rigWorld
rigBring ws-here keeper-here
rigAssert "a member set up here brings nothing: nothing printed, no refusal" "$brRc [$brOut] [$brErr]" "0 [] []"
rigBring ws-here keeper-both
rigAssert "set up here and elsewhere too: nothing either, this workspace's own is read" "$brRc [$brOut] [$brErr]" "0 [] []"
rigBring ws-here keeper-there
rigAssert "an invited member, set up only elsewhere: that workspace's member set view, a tab, that workspace" "$brRc [$brOut] [$brErr]" "0 [$( rigView ws-there )"$'\t'"$rigWork/ws-there] []"
rigPre=( "MDAT_SKILLSET_ROOT=$( rigView ws-here )" )
rigBring ws-here keeper-there
rigAssert "the same where the caller's root is this workspace's own view, by name" "$brRc [$brOut]" "0 [$( rigView ws-there )"$'\t'"$rigWork/ws-there]"
rigPre=( "MDAT_SKILLSET_ROOT=$( rigView ws-there )" )
rigBring ws-here keeper-there
rigAssert "a caller that already reads the member's root is given that same root back, so nothing is left to change" "$brRc [${brOut%%$'\t'*}]" "0 [$( rigView ws-there )]"
rigPre=( "MDAT_SKILLSET_ROOT=$rigElsewhere" )
rigBring ws-here keeper-there
rigAssert "accepted sibling: a root set anywhere else is kept as it is, and the member is looked for under it" "$brRc [$brOut] [$brErr]" "0 [$rigElsewhere"$'\t'"$rigWork/ws-there] []"
rigBring ws-here keeper-multi
rigAssert "and a root set elsewhere that does not hold the member is the refusal below, naming that root" "$brRc [$brOut] $( rigN "$rigTmp/brErr" "Looked for its member directory at $rigElsewhere/keeper-multi, in $rigWork/ws-third" )" "1 [] 1"
rigPre=()
rigBring ws-here keeper-multi
rigAssert "set up in two others: the view of the workspace the resolver names, its source link" "$brRc [$brOut]" "0 [$( rigView ws-third )"$'\t'"$rigWork/ws-third]"
rigBring ws-there keeper-here
rigAssert "and the other way: in ws-there a member set up only in ws-here brings ws-here's view" "$brRc [$brOut]" "0 [$( rigView ws-here )"$'\t'"$rigWork/ws-here]"
rigBring ws-here keeper-unknown
rigAssert "a name the index does not know brings nothing and is not refused" "$brRc [$brOut] [$brErr]" "0 [] []"
rigBring ws-here magic-team
rigAssert "magic-team brings nothing"                                      "$brRc [$brOut] [$brErr]" "0 [] []"
rigBring ws-rig keeper-here
rigAssert "in a workspace the index has no row for, nobody is invited: nothing brought, whoever the member" "$brRc [$brOut] [$brErr]" "0 [] []"
rm -f "$( rigView ws-there )/keeper-there"
rigBring ws-here keeper-there --some-op
rigAssert "(c) the member's directory is not in its own workspace's view: rc 1, nothing on stdout" "$brRc [$brOut]" "1 []"
rigAssert "(c) the error names the command, the operation, the member, the workspace we run from, what is missing, and where it was looked for and why there" "$brErr" "⛔ ERROR: RigCmd --some-op: member 'keeper-there' cannot be brought into the workspace this operation runs from, $rigWork/ws-here: its skillset cannot be read -- nothing was done. Looked for its member directory at $( rigView ws-there )/keeper-there, in $rigWork/ws-there, the workspace the machine's members index ($rigIndexFile) says it is set up in."
rigMemberAt ws-there keeper-there
rigBring ws-here keeper-there
rigAssert "(c) accepted sibling: set up there again, the same member is brought" "$brRc [${brOut%%$'\t'*}] [$brErr]" "0 [$( rigView ws-there )] []"
rm -f "$( rigView ws-there )/magic-team"
rigBring ws-here keeper-there --some-op
rigAssert "(d) the view of the member's workspace holds the member but not the team's own folder: rc 1, nothing on stdout" "$brRc [$brOut]" "1 []"
rigAssert "(d) the error names the command, the operation, the member, the workspace we run from, what is missing, and where it was looked for and why there" "$brErr" "⛔ ERROR: RigCmd --some-op: member 'keeper-there' cannot be brought into the workspace this operation runs from, $rigWork/ws-here: the team's own folder cannot be read where its skillset is -- nothing was done. Looked for the team's directory at $( rigView ws-there )/magic-team, in $rigWork/ws-there, the workspace the machine's members index ($rigIndexFile) says the member is set up in."
rigBring ws-there keeper-there
rigAssert "(d) called from that same workspace the member is set up here and nothing is brought, so the bring does not stop it" "$brRc [$brOut] [$brErr]" "0 [] []"
rigMemberAt ws-there magic-team
rigBring ws-here keeper-there
rigAssert "(d) accepted sibling: with the team's folder in that view again, the same member is brought" "$brRc [${brOut%%$'\t'*}] [$brErr]" "0 [$( rigView ws-there )] []"
rigBring ws-here keeper-nowhere --some-op
rigAssert "(a) a known member in no tracked workspace is stopped by the resolver's own message, once" "$brRc [$brOut] $( rigN "$rigTmp/brErr" "⛔ ERROR: RigCmd --some-op: member 'keeper-nowhere' is in the team members index but is present in no tracked workspace -- nothing was done." ) $( rigLines "$rigTmp/brErr" )" "1 [] 1 1"
mkdir -p "$rigWork/ws-nolist" ; rigListAdd "$rigWork/ws-nolist"
rigBring ws-here keeper-nowhere
rigAssert "(a) tracked and on the machine, but the member is not set up there: stopped as (c), naming that workspace's view" "$brRc [$brOut] $( rigN "$rigTmp/brErr" "Looked for its member directory at $( rigView ws-nolist )/keeper-nowhere, in $rigWork/ws-nolist, the workspace" )" "1 [] 1"
rigMemberAt ws-nolist magic-team ; rigMemberAt ws-nolist keeper-nowhere
rigBring ws-here keeper-nowhere
rigAssert "(a) accepted sibling: tracked, on the machine and set up there, the same member is brought" "$brRc [$brOut] [$brErr]" "0 [$( rigView ws-nolist )"$'\t'"$rigWork/ws-nolist] []"
rigBring ws-here keeper-gone
rigAssert "(b) a workspace missing on the machine is stopped by the resolver's own message, once" "$brRc [$brOut] $( rigN "$rigTmp/brErr" "⛔ ERROR: RigCmd RigOp: the workspace of member 'keeper-gone' is not present on this machine: $rigWork/gone/ws-gone -- nothing was done." ) $( rigLines "$rigTmp/brErr" )" "1 [] 1 1"
rigMemberAt gone/ws-gone magic-team ; rigMemberAt gone/ws-gone keeper-gone
rigBring ws-here keeper-gone
rigAssert "(b) accepted sibling: with the workspace there and the member set up in it, the same member is brought" "$brRc [$brOut] [$brErr]" "0 [$( rigView gone/ws-gone )"$'\t'"$rigWork/gone/ws-gone] []"

echo "-- 4. the dispatcher: an operation naming a member set up here is unchanged --"
rigWorld
rigRunIn ws-here --agents-config-option keeper-here --select WHERE
rigAssert "a member in the current workspace: its own scope, no note about a workspace on stderr" "$rigRc $( cat "$rigTmp/out" ) $( rigQuiet )" "0 ws-here 0"
rigRunIn ws-here --agents-config-option keeper-both --select WHERE
rigAssert "present in both: the current workspace's scope"                 "$rigRc $( cat "$rigTmp/out" )" "0 ws-here"
rigRunIn ws-rig --agents-config-option client-ndm --select WHERE
rigAssert "from a rig workspace the index has no row for: its own scope, whoever the member" "$rigRc $( cat "$rigTmp/out" )" "0 ws-rig"
rigRunIn ws-here --member-help keeper-here
rigAssert "its skillset is read from this workspace's own view: the help names its armed file there" "$rigRc $( rigHelpNames "$( rigView ws-here )/keeper-here/keeper-here.armed.md" )" "0 1"
rigRunIn ws-here --agents-config-option keeper-unknown --select WHERE
rigUnknownWith="$rigRc $( cat "$rigTmp/out" ) $( cat "$rigTmp/err" )"
rigIndexOff
rigRunIn ws-here --agents-config-option keeper-unknown --select WHERE
rigUnknownWithout="$rigRc $( cat "$rigTmp/out" ) $( cat "$rigTmp/err" )"
rigIndexOn
rigAssert "a name not in the index: the operation answers exactly as with no index at all" "$rigUnknownWith" "$rigUnknownWithout"
rigRunIn ws-here --agents-config-option keeper-here --select WHERE
rigWith="$rigRc $( cat "$rigTmp/out" ) $( cat "$rigTmp/err" )"
rigIndexOff
rigRunIn ws-here --agents-config-option keeper-here --select WHERE
rigWithout="$rigRc $( cat "$rigTmp/out" ) $( cat "$rigTmp/err" )"
rigIndexOn
rigAssert "unchanged: a member in the current workspace answers byte for byte as with no index at all, stderr included" "$rigWith" "$rigWithout"
rigRunIn ws-here --agents-config-option magic-team --select SLACK_CHANNEL_MAGIC_TEAM
rigAssert "magic-team as the member argument: the current workspace's channel" "$rigRc $( cat "$rigTmp/out" )" "0 CHERE0001"
rigRunIn ws-here --member-comms-slack-send-message keeper-here magic-team RIG-BODY
rigAssert "its send: its own token, channel and header"                      "$( rigTokens )$( rigChannel ) $( rigText )" 'rig-user-token-KHERE CHERE0001 🔧 *_keeper-here_* @herakeep → @here.\nRIG-BODY'
rm -f "$( rigView ws-here )/magic-team"
rigRunIn ws-here --member-help keeper-here
rigAssert "a file its help needs that this view cannot give stops the help: rc 1, the file and the view it looked in named, no help printed, never an empty floor with rc 0" "$rigRc $( rigN "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --member-help: the team's own operations cannot be read for keeper-here: $( rigView ws-here )/magic-team/magic-team.armed.md not found in the member set view $( rigView ws-here ) -- the help was not completed" ) $( rigN "$rigTmp/err" '# Tooling help output' ) $( rigN "$rigTmp/err" "can't open file" )" "1 1 0 0"
rigMemberAt ws-here magic-team
rigRunIn ws-here --member-help keeper-here
rigAssert "accepted sibling: with the team's folder in the view again, the same help is printed" "$rigRc $( rigN "$rigTmp/err" '# Tooling help output' ) $( rigHelpNames "$( rigView ws-here )/keeper-here/keeper-here.armed.md" )" "0 1 1"

echo "-- 5. the dispatcher: an operation naming an invited member runs in the workspace it was called from --"
rigWorld
rigRunIn ws-here --agents-config-option keeper-there --select WHERE
rigAssert "it reads the settings of the workspace it was called from, which holds none for it: nothing is answered, its own workspace's are not read, and stderr has no note about a workspace" "$rigRc [$( cat "$rigTmp/out" )] $( rigQuiet )" "0 [] 0"
rigScopeOf ws-here keeper-there 'WHERE=ws-here-for-keeper-there'
rigRunIn ws-here --agents-config-option keeper-there --select WHERE
rigAssert "accepted sibling: a setting the workspace it was called from holds for it is the one read" "$rigRc [$( cat "$rigTmp/out" )]" "0 [ws-here-for-keeper-there]"
rm -f "$rigWork/ws-here/.local/.agents/keeper-there.agent.env"
rigRunIn ws-here --agents-config-option keeper-multi --select WHERE
rigAssert "set up in two others, each holding a setting for it: neither is read"   "$rigRc [$( cat "$rigTmp/out" )]" "0 []"
rigRunIn ws-there --agents-config-option keeper-here --select WHERE
rigAssert "and the other way: called from ws-there, a member set up only in ws-here reads ws-there's, which holds none" "$rigRc [$( cat "$rigTmp/out" )]" "0 []"
rigRunIn ws-here --member-help keeper-there
rigAssert "its skillset is read from the workspace it is set up in: the help names its armed file in that workspace's view, and nothing of it under the caller's" "$rigRc $( rigHelpNames "$( rigView ws-there )/keeper-there/keeper-there.armed.md" ) $( rigN "$rigTmp/err" "$( rigView ws-here )/keeper-there" )" "0 1 0"
rigRunIn ws-here --member-help keeper-multi
rigAssert "set up in two others: read from the view of its source link's workspace" "$rigRc $( rigHelpNames "$( rigView ws-third )/keeper-multi/keeper-multi.armed.md" )" "0 1"
rigPre=( "MDAT_SKILLSET_ROOT=$rigElsewhere" )
rigRunIn ws-here --member-help keeper-there
rigAssert "accepted sibling: a member set root the caller set somewhere else is kept, and read"   "$rigRc $( rigHelpNames "$rigElsewhere/keeper-there/keeper-there.armed.md" )" "0 1"
rigPre=()
rigSumThere="$( rigTreeSum ws-there )"
rigPre=( MDSC_CACHED=/stale/cache MDSC_ID_RIGSTALE=stale )
rigRunIn ws-here --member-comms-slack-send-message keeper-there magic-team RIG-BODY
rigInvitedEnv="$( rigEnvLine chat.postMessage )"
rigAssert "it is not carried: when curl was called MMDAPP was the workspace it was called from, and the tooling origin was kept" "$rigRc $( rigEnvOf chat.postMessage MMDAPP ) $( rigEnvOf chat.postMessage ORIGIN )" "0 $rigWork/ws-here $MDLT_ORIGIN"
rigAssert "its team data is that workspace's own"                          "$( rigEnvOf chat.postMessage DATAROOT )" "$rigWork/ws-here/.local/agents/team-data-root"
rigAssert "the member's own workspace is left as it was: nothing written under its .local" "$( rigTreeSum ws-there )" "$rigSumThere"
rigRunIn ws-here --member-comms-slack-send-message keeper-here magic-team RIG-BODY
rigAssert "the environment its call ran in is, field for field, the one a member set up here gets" "$rigInvitedEnv" "$( rigEnvLine chat.postMessage )"
rigPre=()
rigRunIn ws-here --agents-config-option keeper-nowhere --select WHERE
rigAssert "(a) a known member in no tracked workspace: named error from the dispatcher, rc 1, nothing on stdout" "$rigRc $( rigLines "$rigTmp/out" ) $( rigN "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --agents-config-option: member 'keeper-nowhere' is in the team members index but is present in no tracked workspace -- nothing was done." )" "1 0 1"
rigRunIn ws-here --agents-config-option keeper-gone --select WHERE
rigAssert "(b) its workspace missing on the machine: named error, rc 1, nothing on stdout" "$rigRc $( rigLines "$rigTmp/out" ) $( rigN "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --agents-config-option: the workspace of member 'keeper-gone' is not present on this machine: $rigWork/gone/ws-gone -- nothing was done." )" "1 0 1"
rm -f "$( rigView ws-there )/keeper-there"
rigRunIn ws-here --agents-config-option keeper-there --select WHERE
rigAssert "(c) its skillset cannot be brought: named error saying what is missing and where it was looked for, rc 1, nothing on stdout" "$rigRc $( rigLines "$rigTmp/out" ) $( rigN "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --agents-config-option: member 'keeper-there' cannot be brought into the workspace this operation runs from, $rigWork/ws-here: its skillset cannot be read -- nothing was done. Looked for its member directory at $( rigView ws-there )/keeper-there, in $rigWork/ws-there, the workspace" )" "1 0 1"
rigMemberAt ws-there keeper-there
rigRunIn ws-here --agents-config-option keeper-there --select WHERE
rigAssert "(c) accepted sibling: set up there again, the operation runs, here"     "$rigRc [$( cat "$rigTmp/out" )]" "0 []"
rm -f "$( rigView ws-there )/magic-team"
rigRunIn ws-here --member-help keeper-there
rigAssert "(d) the view of its workspace lacks the team's own folder: stopped at the bring, by name, rc 1, so no reader meets a half view: no help is begun and no file is reported as one that could not be opened" "$rigRc $( rigN "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --member-help: member 'keeper-there' cannot be brought into the workspace this operation runs from, $rigWork/ws-here: the team's own folder cannot be read where its skillset is -- nothing was done. Looked for the team's directory at $( rigView ws-there )/magic-team, in $rigWork/ws-there, the workspace" ) $( rigN "$rigTmp/err" '# Duty instructions' ) $( rigN "$rigTmp/err" "can't open file" )" "1 1 0 0"
rigMemberAt ws-there magic-team
rigRunIn ws-here --member-help keeper-there
rigAssert "(d) accepted sibling: with the team's folder there again, the help is printed, read from that view" "$rigRc $( rigN "$rigTmp/err" '# Tooling help output' ) $( rigHelpNames "$( rigView ws-there )/keeper-there/keeper-there.armed.md" )" "0 1 1"
rigMemberAt gone/ws-gone magic-team ; rigMemberAt gone/ws-gone keeper-gone ; mkdir -p "$rigWork/gone/ws-gone/.local/.agents" ; printf 'WHERE=ws-gone\n' > "$rigWork/gone/ws-gone/.local/.agents/keeper-gone.agent.env"
mkdir -p "$rigWork/ws-nolist/.local/.agents" ; rigListAdd "$rigWork/ws-nolist" ; rigMemberAt ws-nolist magic-team ; rigMemberAt ws-nolist keeper-nowhere ; printf 'WHERE=ws-nolist\n' > "$rigWork/ws-nolist/.local/.agents/keeper-nowhere.agent.env"
rigRunIn ws-here --agents-config-option keeper-gone --select WHERE
rigAssert "(b) accepted sibling: with its workspace there and the member set up in it, the operation runs, here, and that workspace's setting for it is still not read" "$rigRc [$( cat "$rigTmp/out" )]" "0 []"
rigRunIn ws-here --agents-config-option keeper-nowhere --select WHERE
rigAssert "(a) accepted sibling: once its workspace is tracked and it is set up there, the same"     "$rigRc [$( cat "$rigTmp/out" )]" "0 []"

echo "-- 6. no second call into itself: an invited member's operation re-runs exactly once --"
rigWorld
rigReRun="export MDAT_SKILLSET_ROOT=$( rigView ws-there )"
rigTraceIn ws-here --agents-config-option keeper-there --select WHERE
rigAssert "an invited member's call is re-run once, under its own member set root, and finishes; it is looked up twice, once before the re-run and once inside it, where nothing is left to change" "$rigRc [$( cat "$rigTmp/out" )] $( rigN "$rigTmp/trace" "$rigReRun" ) $( rigN "$rigTmp/trace" "$rigBringFn keeper-there --agents-config-option" )" "0 [] 1 2"
rigTraceIn ws-here --agents-config-option keeper-here --select WHERE
rigAssert "control: a member set up here is looked up once and never re-run"      "$rigRc $( cat "$rigTmp/out" ) $( rigN "$rigTmp/trace" "export MDAT_SKILLSET_ROOT=/" ) $( rigN "$rigTmp/trace" "$rigBringFn keeper-here --agents-config-option" )" "0 ws-here 0 1"
rigPre=( "MDAT_SKILLSET_ROOT=$( rigView ws-there )" )
rigTraceIn ws-here --agents-config-option keeper-there --select WHERE
rigAssert "accepted sibling: a call that already reads the member's root goes on as it is, with no re-run" "$rigRc [$( cat "$rigTmp/out" )] $( rigN "$rigTmp/trace" "export MDAT_SKILLSET_ROOT=/" ) $( rigN "$rigTmp/trace" "$rigBringFn keeper-there --agents-config-option" )" "0 [] 0 1"
rigPre=()
rigTraceIn ws-here --agents-config-option keeper-multi --select WHERE
rigAssert "a member whose workspace is not the first row: once too, under that workspace's view and no other" "$rigRc $( rigN "$rigTmp/trace" "export MDAT_SKILLSET_ROOT=$( rigView ws-third )" ) $( rigN "$rigTmp/trace" "export MDAT_SKILLSET_ROOT=/" )" "0 1 1"
rigTraceIn ws-here --member-comms-slack-send-message keeper-there magic-team RIG-BODY
rigAssert "a send, whose stub reaches its implementation and the Slack call under it by the same door: one re-run still, one post" "$rigRc $( rigN "$rigTmp/trace" "export MDAT_SKILLSET_ROOT=/" ) $( rigN "$rigTmp/trace" "$rigReRun" ) $( rigN "$rigTmp/calls" "chat.postMessage " )" "0 1 1 1"

echo "-- 7. an invited member talks in the Slack of the workspace it was called from --"
## Two workspaces on two different Slacks. keeper-there is set up only in ws-there, where it has an identity of its
## own and a row in the names registry; ws-here holds no setting and no row for it.
rigWorld
rigRunIn ws-here --member-comms-slack-send-message keeper-there magic-team RIG-BODY
rigAssert "its send uses the workspace it was called from: no setting for it there, so that team's bot, in that team's channel" "$rigRc $( rigTokens )$( rigChannel )" "0 rig-bot-token-HERE CHERE0001"
rigAssert "under its own name, as that workspace's names registry has it: no row there, so the plain name" "$( rigText )" '*_keeper-there_* @keeper-there → @here.\nRIG-BODY'
rigAssert "the token, the channel and the identity of the workspace it is set up in were not used" "$( rigN "$rigTmp/calls" 'token-THERE' ) $( rigN "$rigTmp/calls" 'KTHERE' ) $( rigN "$rigTmp/bodies" 'CTHERE0001' )" "0 0 0"
rigRunIn ws-here --member-comms-slack-read keeper-there magic-team
rigAssert "its read uses the same Slack"                                   "$rigRc $( rigHistoryToken )" "0 rig-bot-token-HERE "
rigRunIn ws-here --member-comms-slack-react keeper-there CHERE0001:1.000001 eyes
rigAssert "an error says which Slack the call used and that it is the one of the workspace the operation runs in" "$( rigN "$rigTmp/err" "THIS CALL USED the Slack here.slack.invalid, by the settings of the workspace $rigWork/ws-here (the workspace this operation runs in)" )" 1
rigAssert "and that a conversation of another Slack is not a missing bot"  "$( rigN "$rigTmp/err" 'check which Slack the target belongs to before reading this as a bot that is not in the channel' )" 1
printf '%s\n' 'keeper-there 🔧 There Keeper therekeep' >> "$rigWork/ws-here/.local/agents/team-members-names.registry"
rigRunIn ws-here --member-comms-slack-send-message keeper-there magic-team RIG-BODY
rigAssert "accepted sibling: with a row for it in the names registry of the workspace it was called from, its header is that row's" "$( rigTokens )$( rigText )" 'rig-bot-token-HERE 🔧 *_keeper-there_* @therekeep → @here.\nRIG-BODY'
rigScopeOf ws-here keeper-there 'SLACK_USER_TOKEN=rig-user-token-KTHEREINHERE'
rigRunIn ws-here --member-comms-slack-send-message keeper-there magic-team RIG-BODY
rigAssert "accepted sibling: with an identity for it in the settings of the workspace it was called from, it posts under that one" "$rigRc $( rigTokens )$( rigChannel )" "0 rig-user-token-KTHEREINHERE CHERE0001"
rigRunIn ws-there --member-comms-slack-send-message keeper-here magic-team RIG-BODY
rigAssert "and the other way: called from ws-there, a member set up only in ws-here posts as ws-there's team bot in ws-there's channel" "$rigRc $( rigTokens )$( rigChannel )" "0 rig-bot-token-THERE CTHERE0001"
rigRunIn ws-there --member-comms-slack-send-message keeper-there magic-team RIG-BODY
rigAssert "control: called from the workspace it is set up in, its own identity, channel and header there" "$( rigTokens )$( rigChannel ) $( rigText )" 'rig-user-token-KTHERE CTHERE0001 🔧 *_keeper-there_* @therekeep → @here.\nRIG-BODY'

echo "-- 8. a client-* member, until it is ruled on: its whole operation runs in the workspace that holds it --"
rigWorld
rigRunIn ws-here --agents-config-option client-ndm --select WHERE
rigAssert "a client held by another workspace: that workspace's scope answers, and no note about a workspace on stderr" "$rigRc $( cat "$rigTmp/out" ) $( rigQuiet )" "0 ws-there 0"
rigAssert "the caller's own shell keeps its MMDAPP after a carried call"   "$( MMDAPP="$rigWork/ws-here" ; ( cd "$rigWork/ws-here" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$MMDAPP" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" bash -c 'bash "$1" --agents-config-option client-ndm --select WHERE > /dev/null 2>&1 ; printf "%s" "$MMDAPP"' rig-shell "$rigTool" ) )" "$rigWork/ws-here"
rigTraceIn ws-here --agents-config-option client-ndm --select WHERE
rigAssert "a carried call resolves twice, once before and once after it is carried, and finishes" "$rigRc $( cat "$rigTmp/out" ) $( LC_ALL=C grep -c "$rigResolveFn client-ndm --agents-config-option" "$rigTmp/trace" || : )" "0 ws-there 2"
rigRunIn ws-here --member-help client-ndm
rigAssert "its skillset is read from the view of the workspace that holds it"  "$rigRc $( rigHelpNames "$( rigView ws-there )/client-ndm/client-ndm.armed.md" )" "0 1"
rigPre=( MDSC_CACHED=/stale/cache MDSC_ID_RIGSTALE=stale )
rigRunIn ws-here --member-comms-slack-send-message client-ndm magic-team RIG-BODY
rigAssert "its send ran under the workspace that holds it: MMDAPP is ws-there when curl was called"  "$( rigEnvOf chat.postMessage MMDAPP )" "$rigWork/ws-there"
rigAssert "the tooling origin is kept, not re-derived from that workspace"  "$( rigEnvOf chat.postMessage ORIGIN )" "$MDLT_ORIGIN"
rigCached="$( rigEnvOf chat.postMessage CACHED )"
case "$rigCached" in unset|"$rigWork/ws-there/"*) rigCached="not-the-planted-one" ;; esac
rigAssert "the planted distro index variables of the workspace it was called from are gone: the cache unset or derived again under the workspace that holds it, the planted id unset"  "$rigCached $( rigEnvOf chat.postMessage STALEID )" "not-the-planted-one unset"
rigPre=( "MDAT_DATA_ROOT=$rigWork/ws-here/.local/agents/team-data-root" )
rigRunIn ws-here --member-comms-slack-send-message client-ndm magic-team RIG-BODY
rigAssert "a data root the caller carried is not carried into the workspace that holds it" "$( rigEnvOf chat.postMessage DATAROOT )" "$rigWork/ws-there/.local/agents/team-data-root"
rigRunIn ws-here --member-comms-slack-send-message keeper-here magic-team RIG-BODY
rigAssert "control: for a member that is not carried a data root the caller carried is kept"  "$( rigEnvOf chat.postMessage DATAROOT )" "$rigWork/ws-here/.local/agents/team-data-root"
rigPre=()
rigRunIn ws-here --member-comms-slack-send-message client-ndm magic-team RIG-BODY
rigAssert "it works: rc 0, one post, under the client's own token of the other workspace" "$rigRc $( rigTokens )" "0 rig-user-token-NDMTHERE "
rigAssert "to the other workspace's channel scope"                         "$( rigChannel )" "CTHERE0001"
rigAssert "the header is the persona's, from the other workspace's registry: mark, name, alias" "$( rigText )" '🐭 *_Magic Vane_* @dispatchr → @here.\nRIG-BODY'
rigAssert "no client identifier and no metadata in the payload"            "$( rigN "$rigTmp/bodies" 'client-ndm' ) $( rigN "$rigTmp/bodies" '"metadata"' )" "0 0"
rigAssert "the current workspace's channel and token were not used"        "$( rigN "$rigTmp/bodies" 'CHERE0001' ) $( rigN "$rigTmp/calls" 'token-HERE' ) $( rigN "$rigTmp/calls" 'KHERE' )" "0 0 0"
rigRunIn ws-here --member-comms-slack-send-message client-ndm magic-team --address-to client-ndm RIG-BODY
rigAssert "addressing itself: the persona header and the mention of the account that posted" "$( rigText )" '🐭 *_Magic Vane_* @dispatchr → 🐭 *_Magic Vane_* <@URIGNDMTHERE>.\nRIG-BODY'
rigRunIn ws-here --member-comms-slack-send-message client-ndm magic-team --identity-bot RIG-BODY
rigAssert "the same client as the team bot: the other workspace's bot token and member name header" "$( rigTokens ) $( rigText )" 'rig-bot-token-THERE  🐭 *_client-ndm_* @dispatchr → @here.\nRIG-BODY'
rigRunIn ws-rig --member-comms-slack-send-message client-ndm magic-team RIG-BODY
rigAssert "from a rig workspace the index does not know: not carried, its own token and channel" "$( rigTokens )$( rigChannel ) $( rigText )" 'rig-user-token-NDMRIG CRIG000001 🐭 *_Rig Persona_* @rigalias → @here.\nRIG-BODY'
rigIndexOff
rigRunIn ws-here --member-comms-slack-send-message client-ndm magic-team RIG-BODY
rigAssert "control: with no index the other workspace's token is never used"  "$( rigN "$rigTmp/calls" 'NDMTHERE' )" 0
rigIndexOn
rigRunIn ws-here --client-comms-jira-board-list client-ndm
rigAssert "a --client-* operation is carried too: the Jira call goes to the site of the other workspace's scope, as that scope's user"  "$rigRc $( LC_ALL=C awk '$1 == "http" { print $2, $3 }' "$rigTmp/calls" )" "0 jira-there.invalid ndm@rig.invalid"
rigAssert "and ran under that workspace"                                   "$( rigEnvOf http MMDAPP )" "$rigWork/ws-there"
rigRunIn ws-rig --client-comms-jira-board-list client-ndm
rigAssert "from a workspace the index has no row for: its own scope's site, not carried" "$( LC_ALL=C awk '$1 == "http" { print $2, $3 }' "$rigTmp/calls" )" "jira-rig.invalid rig@rig.invalid"
rigIndexOff
rigRunIn ws-here --client-comms-jira-board-list client-ndm
rigAssert "control: with no index the client is not carried, and is not set up here: refused, naming this workspace's view, no call made" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigN "$rigTmp/err" "no such member skill directory: $( rigView ws-here )/client-ndm" )" "1 0 1"
rigIndexOn
rigRunIn ws-here --client-sweep-input-scan keeper-nowhere
rigAssert "a --client-* operation names the same refusal for a known member in no tracked workspace" "$rigRc $( rigN "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --client-sweep-input-scan: member 'keeper-nowhere' is in the team members index but is present in no tracked workspace -- nothing was done" )" "1 1"
rigRunIn ws-here --client-sweep-input-scan client-ndm
rigAssert "accepted sibling: a client held by another workspace is not refused by the resolver, its own operation answers" "$( rigN "$rigTmp/err" "present in no tracked workspace" ) $( rigN "$rigTmp/err" "is not present on this machine" )" "0 0"

## ---- spawning ----
rigSpawnIn(){ ## workspace, member, extra args... -- the spawn proxy asked for that member from that workspace, task text on stdin; output in out
	: > "$rigTmp/calls" ; : > "$rigTmp/envs" ; : > "$rigTmp/bodies" ; rm -f "$rigTmp"/launched.* "$rigTmp"/roots.* "$rigTmp"/brief.*
	rigRc=0
	( cd "$rigWork/$1" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/$1" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" \
		bash "$rigTool" --intern-op-agent-spawn-proxy "$2" "${@:3}" --dispatch-doc:none --wait --context rig-ws-invited ) > "$rigTmp/out" 2> "$rigTmp/err" <<< "RIG-TASK-TEXT" || rigRc=$?
}
rigLaunched(){ ## -- where each console was started: HERE THERE THIRD RIG, nothing for none
	local launchLabel launchOut=""
	for launchLabel in HERE THERE THIRD RIG ; do
		if [ -f "$rigTmp/launched.$launchLabel" ] ; then launchOut="$launchOut $launchLabel=$( cat "$rigTmp/launched.$launchLabel" )" ; fi
	done
	printf '%s\n' "${launchOut# }" | LC_ALL=C sed "s|$rigWork/||g"
}
rigRoots(){ ## label -- the member set root that console was given at each start, as member=root under the rig tree, sorted, space separated
	[ -f "$rigTmp/roots.$1" ] || return 0
	LC_ALL=C sort "$rigTmp/roots.$1" | LC_ALL=C sed "s|$rigWork/||g" | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//'
}
rigSettle(){ ## label... -- wait up to 20 seconds for those consoles to have been started, then let detached work finish
	local settleLabel settleLeft=20
	for settleLabel in "$@" ; do
		while [ ! -f "$rigTmp/launched.$settleLabel" ] && [ "$settleLeft" -gt 0 ] ; do sleep 1 ; settleLeft=$(( settleLeft - 1 )) ; done
	done
	sleep 3
}
rigSettleCount(){ ## label, count -- wait up to 20 seconds for that console to have been started that many times
	local countLeft=20 countSeen
	while countSeen="$( LC_ALL=C grep -c . "$rigTmp/roots.$1" 2> /dev/null )" ; [ "${countSeen:-0}" -lt "$2" ] && [ "$countLeft" -gt 0 ] ; do sleep 1 ; countLeft=$(( countLeft - 1 )) ; done
}
rigBoardItems(){ ## workspace -- how many dispatch items that workspace's board holds
	find "$rigWork/$1/.local/agents/team-data-root/board" -name 'dispatch-*.md' 2> /dev/null | LC_ALL=C awk 'END { print NR + 0 }'
}
rigSpawnedCount(){ ## workspace -- how many spawn records that workspace holds
	( cd "$rigWork/$1/.local/agents/spawned" 2> /dev/null && ls */*.md 2> /dev/null | LC_ALL=C awk 'END { print NR + 0 }' ) || printf 0
}

echo "-- 9. the spawn proxy starts an invited member's session in the workspace it was called from --"
rigWorld
rigSumThere="$( rigTreeSum ws-there )"
rigSpawnIn ws-here keeper-there
rigAssert "the session is launched by the console of the workspace it was called from, with MMDAPP that workspace" "$rigRc $( rigLaunched )" "0 HERE=ws-here"
rigAssert "and is given the member set root of the workspace the member is set up in" "$( rigRoots HERE )" "keeper-there=ws-there/.local/agents/members"
rigAssert "the task text reaches that console"                              "$( LC_ALL=C grep -c -x 'RIG-TASK-TEXT' "$rigTmp/brief.HERE" 2> /dev/null || : )" 1
rigAssert "the spawn record is in the workspace it was called from, none in the member's" "$( rigSpawnedCount ws-here ) $( rigSpawnedCount ws-there )" "1 0"
rigAssert "its session thread is opened in the Slack of the workspace it was called from, by that team's bot" "$( rigTokens )$( rigChannel ) $( rigN "$rigTmp/calls" 'token-THERE' )" "rig-bot-token-HERE CHERE0001 0"
rigAssert "the member's own workspace is left as it was: no record, no sandbox, no registry, no send log, no temp" "$( rigTreeSum ws-there )" "$rigSumThere"
rigSpawnIn ws-here keeper-here
rigAssert "control: a member set up here is launched here, on this workspace's own view, as before" "$rigRc $( rigLaunched ) $( rigRoots HERE )" "0 HERE=ws-here keeper-here=ws-here/.local/agents/members"
rigSpawnIn ws-here keeper-unknown
rigAssert "a member the index does not know is launched here, on this workspace's own view, as before" "$rigRc $( rigLaunched ) $( rigRoots HERE )" "0 HERE=ws-here keeper-unknown=ws-here/.local/agents/members"
rigSpawnIn ws-rig keeper-there
rigAssert "from a workspace the index has no row for: launched there, on its own view" "$rigRc $( rigLaunched ) $( rigRoots RIG )" "0 RIG=ws-rig keeper-there=ws-rig/.local/agents/members"
rigSpawnIn ws-here keeper-multi
rigAssert "a member set up in two others: launched here, on the view of its source link's workspace" "$rigRc $( rigLaunched ) $( rigRoots HERE )" "0 HERE=ws-here keeper-multi=ws-third/.local/agents/members"
rigSpawnIn ws-there keeper-here
rigAssert "and the other way: called from ws-there, a member set up only in ws-here is launched in ws-there, on ws-here's view" "$rigRc $( rigLaunched ) $( rigRoots THERE )" "0 THERE=ws-there keeper-here=ws-here/.local/agents/members"
rigSpawnedBefore="$( rigSpawnedCount ws-here )"
rigSpawnIn ws-here keeper-nowhere
rigAssert "(a) a known member in no tracked workspace: rc 1, nothing launched, no record, named error" "$rigRc [$( rigLaunched )] $(( $( rigSpawnedCount ws-here ) - rigSpawnedBefore )) $( rigN "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --intern-op-agent-spawn-proxy: member 'keeper-nowhere' is in the team members index but is present in no tracked workspace -- nothing was done." )" "1 [] 0 1"
mkdir -p "$rigWork/ws-nolist" ; rigListAdd "$rigWork/ws-nolist"
rigSpawnIn ws-here keeper-nowhere
rigAssert "(c) its workspace tracked and on the machine, but the member not set up in it: rc 1, nothing launched, no record, the error names what is missing and where it was looked for" "$rigRc [$( rigLaunched )] $(( $( rigSpawnedCount ws-here ) - rigSpawnedBefore )) $( rigN "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --intern-op-agent-spawn-proxy: member 'keeper-nowhere' cannot be brought into the workspace this operation runs from, $rigWork/ws-here: its skillset cannot be read -- nothing was done. Looked for its member directory at $( rigView ws-nolist )/keeper-nowhere, in $rigWork/ws-nolist, the workspace" )" "1 [] 0 1"
rigMemberAt ws-nolist magic-team ; rigMemberAt ws-nolist keeper-nowhere
rigSpawnIn ws-here keeper-nowhere
rigAssert "(a) (c) accepted sibling: tracked, on the machine and set up there, the same member is launched here on that workspace's view, which needs no console of its own" "$rigRc $( rigLaunched ) $( rigRoots HERE )" "0 HERE=ws-here keeper-nowhere=ws-nolist/.local/agents/members"
rigSpawnIn ws-here keeper-gone
rigAssert "(b) its workspace missing on the machine: rc 1, nothing launched, named error" "$rigRc [$( rigLaunched )] $( rigN "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --intern-op-agent-spawn-proxy: the workspace of member 'keeper-gone' is not present on this machine: $rigWork/gone/ws-gone -- nothing was done." )" "1 [] 1"
rigMemberAt gone/ws-gone magic-team ; rigMemberAt gone/ws-gone keeper-gone
rigSpawnIn ws-here keeper-gone
rigAssert "(b) accepted sibling: with its workspace there and the member set up in it, the same member is launched here" "$rigRc $( rigLaunched ) $( rigRoots HERE )" "0 HERE=ws-here keeper-gone=gone/ws-gone/.local/agents/members"
rm -f "$( rigView ws-there )/magic-team"
rigSpawnedBefore="$( rigSpawnedCount ws-here )"
rigSpawnIn ws-here keeper-there
rigAssert "(d) the view of its workspace lacks the team's own folder: rc 1, nothing launched, no record, the error names what is missing and where it was looked for" "$rigRc [$( rigLaunched )] $(( $( rigSpawnedCount ws-here ) - rigSpawnedBefore )) $( rigN "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --intern-op-agent-spawn-proxy: member 'keeper-there' cannot be brought into the workspace this operation runs from, $rigWork/ws-here: the team's own folder cannot be read where its skillset is -- nothing was done. Looked for the team's directory at $( rigView ws-there )/magic-team, in $rigWork/ws-there, the workspace" )" "1 [] 0 1"
rigMemberAt ws-there magic-team
rigSpawnIn ws-here keeper-there
rigAssert "(d) accepted sibling: with the team's folder there again, the same spawn is launched" "$rigRc $( rigLaunched )" "0 HERE=ws-here"
chmod -x "$rigWork/ws-here/DistroAgentsConsole.sh"
rigSpawnIn ws-here keeper-there
rigAssert "the console check is made at the workspace it was called from: not executable there is refused, naming that path" "$rigRc [$( rigLaunched )] $( rigN "$rigTmp/err" "DistroAgentsConsole.sh is not executable at $rigWork/ws-here" )" "1 [] 1"
chmod +x "$rigWork/ws-here/DistroAgentsConsole.sh"
rigSpawnIn ws-here keeper-there
rigAssert "accepted sibling: executable again, the same spawn is launched"  "$rigRc $( rigLaunched )" "0 HERE=ws-here"
rm -f "$rigWork/ws-there/DistroAgentsConsole.sh"
rigSpawnIn ws-here keeper-there
rigAssert "the console of the workspace the member is set up in is not needed: nothing is started there" "$rigRc $( rigLaunched )" "0 HERE=ws-here"
rigConsole ws-there THERE
rigSpawnedBefore="$( rigSpawnedCount ws-here )" ; rigSpawnedBeforeThere="$( rigSpawnedCount ws-there )"
rigSpawnIn ws-here client-ndm
rigAssert "a client-* member, until it is ruled on: launched by the console of the workspace that holds it, on that workspace's own view" "$rigRc $( rigLaunched ) $( rigRoots THERE )" "0 THERE=ws-there client-ndm=ws-there/.local/agents/members"
rigAssert "its session thread is opened in the Slack of the workspace that holds it, by that team's bot" "$( rigTokens )$( rigChannel ) $( rigN "$rigTmp/calls" 'token-HERE' )" "rig-bot-token-THERE CTHERE0001 0"
rigAssert "and its record stays in the workspace it was asked from"        "$(( $( rigSpawnedCount ws-here ) - rigSpawnedBefore )) $(( $( rigSpawnedCount ws-there ) - rigSpawnedBeforeThere ))" "1 0"

echo "-- 9b. a handback retry is resumed exactly as the launch was: the workspace it was called from, its session, its CLI, its member set root --"
rigWorld
## A console that hands back only when resumed, recording each start: the launch, then
## the proxy's one handback retry (MDAT_SPAWN_RESUME=true). It carries a --cli) arm
## mention, so the proxy accepts --spawn-cli-service against it.
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured and --cli) stand-in: writes MDAT_SPAWN_LAUNCH_MARKER, hands back only when resumed.' \
	'printf "%s|%s|%s|%s|%s\n" "$MMDAPP" "$MDAT_SESSION_ID" "$MDAT_SESSION_THREAD" "$*" "${MDAT_SKILLSET_ROOT:-unset}" > "$RIG_SCENARIO/start.${MDAT_SPAWN_RESUME:-launch}"' \
	'cat > /dev/null' \
	'[ "${MDAT_SPAWN_RESUME:-}" != true ] || printf "📦 SubagentHandback\n"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWork/ws-here/DistroAgentsConsole.sh"
rm -f "$rigTmp"/start.*
## Without --wait: a --wait spawn under --dispatch-doc:none keeps no output file, and the
## retry reads the output file for the handback, so only this form reaches it.
rigRc=0
( cd "$rigWork/ws-here" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/ws-here" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" \
	bash "$rigTool" --intern-op-agent-spawn-proxy keeper-there --spawn-cli-service rig-service --dispatch-doc:none --context rig-ws-invited ) > "$rigTmp/out" 2> "$rigTmp/err" <<< "RIG-TASK-TEXT" || rigRc=$?
rigRetryLeft=30
while [ ! -s "$rigTmp/start.true" ] && [ "$rigRetryLeft" -gt 0 ] ; do sleep 1 ; rigRetryLeft=$(( rigRetryLeft - 1 )) ; done
rigAssert "a launch with no handback is retried once"                     "$rigRc $( ls "$rigTmp" | LC_ALL=C grep -c '^start\.' || : )" "0 2"
rigAssert "the retry gets the launch's own workspace, session id, session thread, CLI args and member set root" "$( cat "$rigTmp/start.true" 2> /dev/null )" "$( cat "$rigTmp/start.launch" 2> /dev/null )"
rigAssert "which are the workspace it was called from, the asked-for CLI and the member's own workspace view" "$( LC_ALL=C cut -d'|' -f1,4,5 "$rigTmp/start.true" 2> /dev/null | LC_ALL=C sed "s|$rigWork/||g" )" "ws-here|--cli rig-service --non-interactive|ws-there/.local/agents/members"
rigAssert "with a session id and a session thread carried, not empty"   "$( LC_ALL=C awk -F'|' '{ print ( $2 != "" && $3 != "" ) ? "carried" : "empty" }' "$rigTmp/start.true" 2> /dev/null )" carried
rm -f "$rigTmp"/start.*
rigConsole ws-here HERE

echo "-- 9c. the handback retry never resumes a closed session: it runs before the close, and not at all once the session is closed --"
rigWorld
## A console that records, at each start, the status its own spawn record had then, and hands back only when
## resumed. RIG_CLOSE closes the session on its launch the ways the tooling does: the record closed by another
## closer (as the advance pass closes a dead spawn), a Wait that returned DISMISSED, an ordered ENDING (TaskStop).
cat > "$rigWork/ws-here/DistroAgentsConsole.sh" <<'RIGCONSOLE'
#!/usr/bin/env bash
## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli) stand-in: records each start with its record status, hands back only when resumed.
rigRecord="$MDAT_SPAWN_SANDBOX_ROOT/$MDAT_SPAWN_SESSION_ID.md"
rigStatus="$( sed -n 's/^status: //p' "$rigRecord" 2> /dev/null | head -1 )"
printf '%s\n' "${rigStatus:-none}" > "$RIG_SCENARIO/start.${MDAT_SPAWN_RESUME:-launch}"
cat > /dev/null
printf 'rig-cli\n' > "$MDAT_SPAWN_LAUNCH_MARKER"
if [ "${MDAT_SPAWN_RESUME:-}" = true ] ; then printf '📦 SubagentHandback\n' ; exit 0 ; fi
printf '%s\n' "$rigRecord" > "$RIG_SCENARIO/record.path"
rigTranscript=""
[ ! -s "${MDAT_SPAWN_LAUNCH_MARKER%/launch}/transcript" ] || IFS= read -r rigTranscript < "${MDAT_SPAWN_LAUNCH_MARKER%/launch}/transcript"
[ -n "$rigTranscript" ] && [ -f "$rigTranscript" ] && printf 'yes\n' > "$RIG_SCENARIO/transcript.seen"
case "${RIG_CLOSE:-open}" in
	record) sed 's/^status: spawn-started$/status: spawn-ended-without-close/' "$rigRecord" > "$rigRecord.rig" && mv -f "$rigRecord.rig" "$rigRecord" ;;
	dismissed) printf '%s DISMISSED\n> WAIT-RESULT: DISMISSED\n' "$( date -u +%Y-%m-%dT%H:%M:%SZ )" >> "$rigTranscript" ;;
	ending) printf '%s ENDING item=rig-item kind=dismissed by=rig text=taskstop\n' "$( date -u +%Y-%m-%dT%H:%M:%SZ )" >> "$rigTranscript" ;;
esac
exit 0
RIGCONSOLE
chmod +x "$rigWork/ws-here/DistroAgentsConsole.sh"
rigRetrySpawn(){ ## close mode -- one async spawn of keeper-there, invited into ws-here, then up to 30 s for its own close to stamp the record
	rm -f "$rigTmp"/start.* "$rigTmp/record.path" "$rigTmp/transcript.seen" ; : > "$rigTmp/calls" ; : > "$rigTmp/bodies"
	rigRc=0
	( cd "$rigWork/ws-here" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/ws-here" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_CLOSE="$1" \
		bash "$rigTool" --intern-op-agent-spawn-proxy keeper-there --spawn-cli-service rig-service --dispatch-doc:none --context rig-ws-invited ) > "$rigTmp/out" 2> "$rigTmp/err" <<< "RIG-TASK-TEXT" || rigRc=$?
	rigRetryLeft=30
	while [ "$rigRetryLeft" -gt 0 ] && ! { [ -s "$rigTmp/record.path" ] && LC_ALL=C grep -q '^resolved-at: ' "$( cat "$rigTmp/record.path" )" 2> /dev/null ; } ; do sleep 1 ; rigRetryLeft=$(( rigRetryLeft - 1 )) ; done
	rigRecordStatus="$( [ ! -s "$rigTmp/record.path" ] || LC_ALL=C sed -n 's/^status: //p' "$( cat "$rigTmp/record.path" )" 2> /dev/null | head -1 )"
	rigSessionLog="$( LC_ALL=C sed -n 's/^OUTPUT_FILE=//p' "$rigTmp/out" | head -1 )"
}
rigStarts(){ ## -- each start seen, with the record status at that start: launch=<status> true=<status>
	printf 'launch=%s true=%s' "$( cat "$rigTmp/start.launch" 2> /dev/null || printf none )" "$( cat "$rigTmp/start.true" 2> /dev/null || printf none )"
}
rigRetrySpawn open
rigAssert "control: an open session with no handback is retried once, and the retry runs while its record still says started" "$rigRc $( rigStarts )" "0 launch=spawn-started true=spawn-started"
rigAssert "control: the close comes after the retry, which handed back, so no handback-missing notice is posted" "$rigRecordStatus $( rigN "$rigTmp/bodies" 'none posted' )" "spawn-succeeded 0"
rigAssert "the record it closes is the calling workspace's own"           "$( LC_ALL=C sed "s|$rigWork/||" "$rigTmp/record.path" 2> /dev/null | LC_ALL=C cut -d/ -f1-4 )" "ws-here/.local/agents/spawned"
for rigCloseMode in record dismissed ending ; do
	rigRetrySpawn "$rigCloseMode"
	case "$rigCloseMode" in
		record) rigCloseWhat="its record closed by another closer" ;;
		dismissed) rigCloseWhat="its Wait returned DISMISSED" ;;
		ending) rigCloseWhat="an ordered ENDING recorded" ;;
	esac
	[ "$rigCloseMode" = record ] || rigAssert "control ($rigCloseMode): the session had a transcript to record its ending in" "$( cat "$rigTmp/transcript.seen" 2> /dev/null || printf no )" yes
	rigAssert "a closed session ($rigCloseWhat) is not resumed: launched once, never retried" "$rigRc $( rigStarts )" "0 launch=spawn-started true=none"
	rigAssert "instead ($rigCloseMode): the handback-missing notice is posted, the reason is logged, and the close still runs" "$( [ "$( rigN "$rigTmp/bodies" 'none posted' )" -gt 0 ] && printf notice || printf silent ) $( rigN "$rigSessionLog" 'no handback retry for spawn' ) $rigRecordStatus" "notice 1 spawn-succeeded"
done
rm -f "$rigTmp"/start.* "$rigTmp/record.path" "$rigTmp/transcript.seen"
rigConsole ws-here HERE

echo "-- 10. --magic-spawn-session, --magic-heartbeat-* and the root harness --"
rigSessionIn(){ ## workspace, args... -- --magic-spawn-session from that workspace
	: > "$rigTmp/calls" ; : > "$rigTmp/envs" ; : > "$rigTmp/bodies" ; rm -f "$rigTmp"/launched.* "$rigTmp"/roots.* "$rigTmp"/brief.*
	rigRc=0
	( cd "$rigWork/$1" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/$1" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" \
		bash "$rigTool" --magic-spawn-session "${@:2}" ) > "$rigTmp/out" 2> "$rigTmp/err" <<< "RIG-TASK-TEXT" || rigRc=$?
}
rigWorld
rigSessionIn ws-here --routine-default keeper-there ; rigSettle HERE
rigAssert "a session for an invited member is launched in the workspace it was called from, on the member's own workspace view" "$rigRc $( rigLaunched ) $( rigRoots HERE )" "0 HERE=ws-here keeper-there=ws-there/.local/agents/members"
rigSpawnedBefore="$( rigSpawnedCount ws-here )"
rigSessionIn ws-here --routine-default keeper-there keeper-here ; rigSettle HERE ; rigSettleCount HERE 2
rigAssert "two members, one invited and one set up here: both launched here, each on the view of the workspace it is set up in" "$rigRc $( rigLaunched ) $( rigRoots HERE )" "0 HERE=ws-here keeper-here=ws-here/.local/agents/members keeper-there=ws-there/.local/agents/members"
rigAssert "and the records of both are the calling workspace's, none in the other"          "$(( $( rigSpawnedCount ws-here ) - rigSpawnedBefore )) $( rigSpawnedCount ws-there )" "2 0"
rigSessionIn ws-here --routine-default keeper-nowhere
rigAssert "a member whose directory is nowhere on this machine is no team member here: refused by name, nothing launched"  "$rigRc [$( rigLaunched )] $( rigN "$rigTmp/err" "magic-spawn-session: ⛔ ERROR: no such team member: keeper-nowhere" )" "1 [] 1"
mkdir -p "$rigWork/ws-nolist" ; rigMemberAt ws-nolist magic-team ; rigMemberAt ws-nolist keeper-nowhere
rigSessionIn ws-here --routine-default keeper-nowhere
rigAssert "(a) set up in a workspace that is not tracked: refused by the resolver's message, nothing launched"  "$rigRc [$( rigLaunched )] $(( $( rigN "$rigTmp/out" "present in no tracked workspace -- nothing was done" ) + $( rigN "$rigTmp/err" "present in no tracked workspace -- nothing was done" ) ))" "1 [] 1"
rigListAdd "$rigWork/ws-nolist"
rigSessionIn ws-here --routine-default keeper-nowhere ; rigSettle HERE
rigAssert "(a) accepted sibling: once that workspace is tracked, the same member is launched here, on that workspace's view" "$rigRc $( rigLaunched ) $( rigRoots HERE )" "0 HERE=ws-here keeper-nowhere=ws-nolist/.local/agents/members"
rigSessionIn ws-here --routine-default keeper-here ; rigSettle HERE
rigAssert "control: a member set up here is launched here"                 "$rigRc $( rigLaunched ) $( rigRoots HERE )" "0 HERE=ws-here keeper-here=ws-here/.local/agents/members"
for rigW in there here ; do
	mkdir -p "$rigWork/ws-$rigW/.local/agents/team-data-root/inboxes/magic-coordinator"
	printf -- '---\nstate: working\nsession-id: RIG-%s-SESSION\nrecheck-date: %s\n---\nbody\n' "$rigW" "$( date -u +%Y-%m-%dT%H:%M:%SZ )" > "$rigWork/ws-$rigW/.local/agents/team-data-root/inboxes/magic-coordinator/note-20260809T155000Z-heartbeat-state-and-lock.md"
done
rigRunIn ws-here --magic-heartbeat-lock-status keeper-there
rigAssert "a --magic-heartbeat-* operation naming an invited member reads the team data of the workspace it was called from, not the member's" "$( cat "$rigTmp/out" | LC_ALL=C sed 's/:recheck_date=.*//' )" "ACTIVE:owner=RIG-here-SESSION:state=working"
rigRunIn ws-here --magic-heartbeat-lock-status keeper-here
rigAssert "control: for a member set up here it reads the same, this workspace's own"     "$( cat "$rigTmp/out" | LC_ALL=C sed 's/:recheck_date=.*//' )" "ACTIVE:owner=RIG-here-SESSION:state=working"
rigRunIn ws-there --magic-heartbeat-lock-status keeper-there
rigAssert "control: called from the member's own workspace it reads that one's"     "$( cat "$rigTmp/out" | LC_ALL=C sed 's/:recheck_date=.*//' )" "ACTIVE:owner=RIG-there-SESSION:state=working"
rigRunIn ws-here --magic-heartbeat-lock-status keeper-pre
rigAssert "(a) a --magic-heartbeat-* operation names the same refusal"     "$rigRc $( rigN "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --magic-heartbeat-lock-status: member 'keeper-pre' is in the team members index but is present in no tracked workspace -- nothing was done" )" "1 1"
rigRootIn(){ ## workspace, args... -- --intern-root-harness from that workspace
	: > "$rigTmp/calls" ; : > "$rigTmp/envs" ; : > "$rigTmp/bodies" ; rm -f "$rigTmp"/launched.* "$rigTmp"/roots.* "$rigTmp"/brief.*
	rigRc=0
	( cd "$rigWork/$1" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/$1" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" \
		bash "$rigTool" --intern-root-harness "${@:2}" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator\n---\n# rig heartbeat routine fixture\n' > "$( rigMemberHome ws-here magic-coordinator )/magic-coordinator.heartbeat.routine.md"
rigRootIn ws-here --routine heartbeat --non-interactive --wait ; rigSettle HERE
rigAssert "the root harness, whose caller is the coordinator set up in the current workspace: launched there" "$rigRc $( rigLaunched ) $( rigRoots HERE )" "0 HERE=ws-here magic-coordinator=ws-here/.local/agents/members"
rigSpawnedBefore="$( rigSpawnedCount ws-there )" ; rigBoardBeforeThere="$( rigBoardItems ws-there )" ; rigBoardBeforeHere="$( rigBoardItems ws-here )"
rigRootIn ws-there --routine heartbeat --non-interactive --wait ; rigSettle THERE
rigAssert "the same from a workspace the coordinator is not set up in: it is invited, its session launched in the workspace it was asked from, on the coordinator's own workspace view" "$rigRc $( rigLaunched ) $( rigRoots THERE )" "0 THERE=ws-there magic-coordinator=ws-here/.local/agents/members"
rigAssert "and the record stays in the workspace it was asked from"        "$(( $( rigSpawnedCount ws-there ) - rigSpawnedBefore ))" "1"
rigAssert "and the dispatch item and board stay in the workspace it was asked from" "$(( $( rigBoardItems ws-there ) - rigBoardBeforeThere )) $(( $( rigBoardItems ws-here ) - rigBoardBeforeHere ))" "1 0"
rigLoopIn(){ ## workspace -- --intern-main-loop --one from that workspace
	: > "$rigTmp/calls" ; : > "$rigTmp/envs" ; : > "$rigTmp/bodies" ; rm -f "$rigTmp"/launched.* "$rigTmp"/roots.* "$rigTmp"/brief.*
	rigRc=0
	( cd "$rigWork/$1" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/$1" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" \
		bash "$rigTool" --intern-main-loop --one ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigWorld
printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator\n---\n# rig heartbeat routine fixture\n' > "$( rigMemberHome ws-here magic-coordinator )/magic-coordinator.heartbeat.routine.md"
printf 'SPAWN_CLI_SERVICE=rig-cli\n' >> "$rigWork/ws-there/.local/.agents/magic-team.agent.env" ; printf 'SPAWN_CLI_SERVICE=rig-cli\n' >> "$rigWork/ws-here/.local/.agents/magic-team.agent.env"
rigLoopIn ws-here ; rigSettle HERE
rigAssert "the main loop in the coordinator's own workspace: one pass, launched there, as before"  "$rigRc $( rigLaunched ) $( rigN "$rigTmp/err" 'pass succeeded, exit 0, launched true' )" "0 HERE=ws-here 1"
rigLoopIn ws-there ; rigSettle THERE
rigAssert "the main loop in a workspace the coordinator is not set up in: its pass launches the coordinator's session in that workspace, on the coordinator's own workspace view" "$rigRc $( rigLaunched ) $( rigRoots THERE ) $( rigN "$rigTmp/err" 'pass succeeded, exit 0, launched true' )" "0 THERE=ws-there magic-coordinator=ws-here/.local/agents/members 1"

echo "-- 11. the harness tools that name a member --"
rigToolIn(){ ## workspace the session runs in, the member set root the session was given, agent, tool, json -- one harness tool call as that agent; output in out
	: > "$rigTmp/calls" ; : > "$rigTmp/envs" ; : > "$rigTmp/bodies" ; rm -f "$rigTmp"/launched.* "$rigTmp"/roots.* "$rigTmp"/brief.*
	rigRc=0
	( cd "$rigWork/$1" && printf '%s' "$5" | env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/$1" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$2" RIG_SCENARIO="$rigTmp" \
		MDAT_SPAWN_SESSION_ID=rig-session-a MDAT_SPAWN_AGENT="$3" MDAT_HARNESS_WAIT_TIMEOUT=1 bash "$rigHarness" --intern-tool "$4" ) > "$rigTmp/out" 2> "$rigTmp/err" || rigRc=$?
}
rigSettle
rigWorld
## An invited member's session, as the spawn starts it: it runs in the workspace it was called from, on the member
## set root of the workspace the member is set up in.
rigToolIn ws-here "$( rigView ws-there )" keeper-there SendMessage '{"to":"magic-team","message":"RIG-BODY"}'
rigAssert "SendMessage as an invited member: the team bot and channel of the workspace its session runs in, and run there" "$( rigTokens )$( rigChannel ) $( rigEnvOf chat.postMessage MMDAPP | LC_ALL=C sed "s|$rigWork/||" )" 'rig-bot-token-HERE CHERE0001 ws-here'
rigToolIn ws-here "$( rigView ws-here )" keeper-here SendMessage '{"to":"magic-team","message":"RIG-BODY"}'
rigAssert "control: SendMessage as a member set up in the current workspace: its own token and channel" "$( rigTokens )$( rigChannel )" 'rig-user-token-KHERE CHERE0001'
rigToolIn ws-here "$( rigView ws-there )" keeper-there Wait '{"sources":"slack:magic-team","timeout":0}'
rigAssert "Wait as an invited member: the long poll ran under the token and the root of the workspace its session runs in" "$( LC_ALL=C awk '$1 ~ /^conversations/ { print $2 ; exit }' "$rigTmp/calls" ) $( rigEnvOf conversations.history MMDAPP | LC_ALL=C sed "s|$rigWork/||" )" 'rig-bot-token-HERE ws-here'
rigToolIn ws-here "$( rigView ws-here )" keeper-here Wait '{"sources":"slack:magic-team","timeout":0}'
rigAssert "control: Wait as a member set up in the current workspace"     "$( LC_ALL=C awk '$1 ~ /^conversations/ { print $2 ; exit }' "$rigTmp/calls" ) $( rigEnvOf conversations.history MMDAPP | LC_ALL=C sed "s|$rigWork/||" )" 'rig-user-token-KHERE ws-here'
rigToolIn ws-here "$( rigView ws-there )" keeper-there AskUserQuestion '{"to":"human-owner","question":"May the rig keep its file?","wait":false}'
rigAssert "AskUserQuestion as an invited member, which has no account of its own in the workspace its session runs in: every post goes to that workspace's human-owner under that workspace's coordinator account, as for any member without one, and nothing of its own workspace is used" "$( rigTokens | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -v '^$' | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' ' )$( rigChannel ) $( rigN "$rigTmp/calls" 'THERE' )" 'rig-user-token-COORDHERE UHEREOWNER 0'
rigToolIn ws-here "$( rigView ws-there )" keeper-there AskQuestion '{"to":"magic-team","address_to":"UHEREOWNER","question":"May the rig go on?","wait":false}'
rigAssert "AskQuestion as an invited member is posted in that same Slack"  "$( LC_ALL=C sed -n '1p' "$rigTmp/out" ) $( rigTokens )$( rigChannel )" "ASK-RESULT: POSTED rig-bot-token-HERE CHERE0001"
rigToolIn ws-here "$( rigView ws-there )" client-ndm SendMessage '{"to":"magic-team","message":"RIG-BODY"}'
rigAssert "SendMessage as a client held by another workspace, until it is ruled on: its token, that workspace's channel"  "$( rigTokens )$( rigChannel )" 'rig-user-token-NDMTHERE CTHERE0001'
rigToolIn ws-here "$( rigView ws-there )" client-ndm Wait '{"sources":"slack:magic-team","timeout":0}'
rigAssert "Wait as a client held by another workspace: the long poll ran under that workspace's token and root" "$( LC_ALL=C awk '$1 ~ /^conversations/ { print $2 ; exit }' "$rigTmp/calls" ) $( rigEnvOf conversations.history MMDAPP | LC_ALL=C sed "s|$rigWork/||" )" 'rig-user-token-NDMTHERE ws-there'
rigSpawnedBefore="$( rigSpawnedCount ws-here )" ; rigBoardBeforeHere="$( rigBoardItems ws-here )"
rigToolIn ws-here "$( rigView ws-here )" keeper-here Agent '{"agent":"keeper-there","prompt":"RIG-TASK-TEXT"}' ; rigSettle HERE
rigAssert "Agent naming an invited member: its session is launched in the calling workspace, on the member's own workspace view"  "$( rigLaunched ) $( rigRoots HERE )" "HERE=ws-here keeper-there=ws-there/.local/agents/members"
rigAssert "and the spawn record is the calling workspace's"               "$(( $( rigSpawnedCount ws-here ) - rigSpawnedBefore )) $( rigSpawnedCount ws-there )" "1 0"
rigAssert "and so are its dispatch item and board, none in the member's workspace" "$(( $( rigBoardItems ws-here ) - rigBoardBeforeHere )) $( rigBoardItems ws-there )" "1 0"
rigToolIn ws-here "$( rigView ws-here )" keeper-here ListAgents '{"view":"sessions"}'
rigAssert "ListAgents lists the calling workspace's sessions, the spawn above included, and does not look elsewhere" "$( LC_ALL=C grep -c -E 'keeper-there|rig-' "$rigTmp/out" || : ) $( rigN "$rigTmp/calls" 'http' )" "1 0"
rigToolIn ws-there "$( rigView ws-here )" keeper-here ListAgents '{"view":"sessions"}'
rigAssert "from the other workspace the same call lists that workspace's own, none of the first's" "$( LC_ALL=C grep -c -E 'keeper-there|rig-' "$rigTmp/out" || : )" 0
rigToolIn ws-here "$( rigView ws-here )" keeper-here Skill '{"name":"keeper-multi"}'
rigAssert "Skill for a member set up only in other workspaces reads that member's own folder where its source is, found through the machine's index, and makes no call"  "$( rigN "$rigTmp/out" '# keeper-multi, set up in ws-third' ) $( rigLines "$rigTmp/calls" )" "1 0"
rigToolIn ws-here "$rigElsewhere" keeper-nowhere SendMessage '{"to":"magic-team","message":"RIG-BODY"}'
rigAssert "(a) SendMessage as a known member in no tracked workspace: refused with the named error, nothing posted" "$( rigN "$rigTmp/out" "present in no tracked workspace -- nothing was done" ) [$( rigTokens )]" "1 []"
rigListAdd "$rigWork/ws-nolist" ; mkdir -p "$rigWork/ws-nolist/.local/.agents" ; rigMemberAt ws-nolist magic-team ; rigMemberAt ws-nolist keeper-nowhere ; rigScopeOf ws-nolist magic-team 'SLACK_CHANNEL_MAGIC_TEAM=CNOLIST01' 'SLACK_BOT_TOKEN=rig-bot-token-NOLIST' ; rigScopeOf ws-nolist keeper-nowhere 'SLACK_USER_TOKEN=rig-user-token-KNOWHERE'
rigToolIn ws-here "$( rigView ws-nolist )" keeper-nowhere SendMessage '{"to":"magic-team","message":"RIG-BODY"}'
rigAssert "(a) accepted sibling: tracked, present and set up there, the same call posts, in the Slack of the workspace its session runs in, run there, and its own workspace's identity is not used" "$( rigTokens )$( rigChannel ) $( rigEnvOf chat.postMessage MMDAPP | LC_ALL=C sed "s|$rigWork/||" ) $( rigN "$rigTmp/calls" 'NOLIST' ) $( rigN "$rigTmp/calls" 'KNOWHERE' )" 'rig-bot-token-HERE CHERE0001 ws-here 0 0'
rigWorld

echo "-- 12. static: where a member's workspace is looked up, and not --"
rigDispatchEntry="$( LC_ALL=C awk '/^DistroAgentsTools\(\)\{/ { on = 1 } on { print } on && /^\t\. "\$MDLT_ORIGIN\/myx\/myx.distro-agents\/sh-lib\/AgentsContext.UseAgentsTools.include"/ { exit }' "$rigTool" )"
rigAssert "control: the dispatcher's entry was cut out, up to the context include"  "$( printf '%s\n' "$rigDispatchEntry" | LC_ALL=C grep -c 'AgentsContext.UseAgentsTools.include' || : )" 1
rigAssert "the entry brings once, before the context include, and resolves once, for a client-* member alone" "$( printf '%s\n' "$rigDispatchEntry" | LC_ALL=C grep -c "$rigBringFn \"\$2\" \"\$1\"" || : ) $( printf '%s\n' "$rigDispatchEntry" | LC_ALL=C grep -c "$rigResolveFn \"\$2\" \"\$1\"" || : ) $( printf '%s\n' "$rigDispatchEntry" | LC_ALL=C grep -B2 "$rigResolveFn \"\$2\" \"\$1\"" | LC_ALL=C grep -c -F -e '--*:client-*)' || : )" "1 1 1"
rigExclusion="$( printf '%s\n' "$rigDispatchEntry" | LC_ALL=C grep -F -e '|*:|*:-*) ;;' | LC_ALL=C sed -e 's/^[[:space:]]*//' -e 's/) ;;$//' )"
## The Decisions append and the review implementations are the tooling's own: their <who> is the name recorded, not
## the member whose workspace the item lives in, and they run where their caller's records are. The place ops' second
## word is a place name or a path, and the namespace listing's a namespace, never a member.
rigAssert "the entry's one exclusion line: the spawn proxy, the two operations that wrap it, the MCP execute, the Decisions append, the review implementations, the place ops, an empty second word, an option" "$rigExclusion" '--intern-op-agent-spawn-proxy:*|--magic-heartbeat-spawn-proxy:*|--magic-spawn-session:*|--intern-mcp-execute:*|--intern-op-decisions-append:*|--intern-op-review-*:*|--intern-directory-*:*|--member-directory-*:*|--member-namespace-list:*|--owner-workspace-*:*|*:|*:-*'
rigAssert "control: a sample entry without the wrapping operations is told apart" "$( printf -- '--intern-op-agent-spawn-proxy:*|--intern-mcp-execute:*|*:|*:-*\n' )" "$( printf '%s' "$rigExclusion" | LC_ALL=C sed 's/--magic-heartbeat-spawn-proxy:[*]|--magic-spawn-session:[*]|//; s/--intern-op-decisions-append:[*]|//; s/--intern-op-review-[*]:[*]|//; s/--intern-directory-[*]:[*]|--member-directory-[*]:[*]|--member-namespace-list:[*]|--owner-workspace-[*]:[*]|//' )"
rigAssert "an invited member's call is re-run whole in a subshell under its member set root, and only where that is not the root it already reads" "$( printf '%s\n' "$rigDispatchEntry" | LC_ALL=C grep -c -F -e '( export MDAT_SKILLSET_ROOT="$memberBrought" ; DistroAgentsTools "$@" )' || : ) $( printf '%s\n' "$rigDispatchEntry" | LC_ALL=C grep -c -F -e '[ "$memberBrought" != "${MDAT_SKILLSET_ROOT:-}" ]' || : )" "1 1"
rigAssert "a client's carried call is re-run whole in a subshell under the other workspace's root"  "$( printf '%s\n' "$rigDispatchEntry" | LC_ALL=C grep -c "( $rigSwitchFn \"\$memberWorkspace\" ; DistroAgentsTools \"\$@\" )" || : )" 1
rigAssert "the resolver is called from the dispatcher entry, the spawn proxy and the bring, and nowhere else" "$( LC_ALL=C grep -l "$rigResolveFn \"" "$rigHere"/*.include "$rigHere"/*.sh "$rigPackage/sh-scripts"/*.sh 2> /dev/null | LC_ALL=C sed 's|.*/||' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "AgentsTools.InternOpAgentSpawnProxy.include AgentsTools.MemberWorkspace.include DistroAgentsTools.fn.sh "
rigAssert "the bring is called from the dispatcher entry and the spawn proxy, and nowhere else" "$( LC_ALL=C grep -l "$rigBringFn \"" "$rigHere"/*.include "$rigHere"/*.sh "$rigPackage/sh-scripts"/*.sh 2> /dev/null | LC_ALL=C sed 's|.*/||' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "AgentsTools.InternOpAgentSpawnProxy.include DistroAgentsTools.fn.sh "
rigAssert "the spawn proxy launches the console of the spawn's workspace, with MMDAPP set to it, never by another name" "$( [ "$( LC_ALL=C grep -c 'MMDAPP="\$spawnWorkspace".*"\$spawnWorkspace/DistroAgentsConsole.sh"' "$rigSpawnInclude" || : )" -gt 0 ] && printf launches-there || printf blind ) $( LC_ALL=C grep -v '^[[:space:]]*#' "$rigSpawnInclude" | LC_ALL=C grep -c 'MMDAPP="\$MMDAPP".*DistroAgentsConsole.sh' || : )" "launches-there 0"
rigAssert "which is the workspace it was called from for every member, and the resolver's answer for a client-* alone" "$( LC_ALL=C grep -c -F -e 'local spawnWorkspace="$MMDAPP"' "$rigSpawnInclude" || : ) $( LC_ALL=C grep -c -F -e "spawnWorkspace=\"\$( $rigResolveFn \"\$callerName\"" "$rigSpawnInclude" || : ) $( LC_ALL=C grep -B1 -F -e "spawnWorkspace=\"\$( $rigResolveFn \"\$callerName\"" "$rigSpawnInclude" | LC_ALL=C grep -c -F -e 'client-*)' || : )" "1 1 1"
rigAssert "the --intern-mcp-execute workspace arm uses the shared switch function, and the include defines it once" "$( LC_ALL=C grep -c "$rigSwitchFn \"\$2\"" "$rigTool" || : ) $( LC_ALL=C grep -c "^$rigSwitchFn(){" "$rigResolveInclude" || : )" "1 1"
rigAssert "the switch unsets the distro index variables, MDSC_ID by prefix"  "$( rigFnText="$( LC_ALL=C awk -v n="$rigSwitchFn" 'index( $0, n "(){" ) == 1 { on = 1 } on { print } on && /^}/ { exit }' "$rigResolveInclude" )" ; printf '%s\n' "$rigFnText" | LC_ALL=C grep -c -E 'unset MDSC_OPTION MDSC_INMODE MDSC_SOURCE MDSC_CACHED MDSC_OUTPUT MDSC_MEMORY|\$\{!MDSC_ID\*\}' || : )" 2
rigAssert "the switch never touches the tooling origin"                   "$( LC_ALL=C awk -v n="$rigSwitchFn" 'index( $0, n "(){" ) == 1 { on = 1 } on { print } on && /^}/ { exit }' "$rigResolveInclude" | LC_ALL=C grep -c 'MDLT_ORIGIN' || : )" 0
rigAssert "control: the same pattern finds an origin line in a sample"      "$( printf 'unset MDLT_ORIGIN\n' | LC_ALL=C grep -c 'MDLT_ORIGIN' || : )" 1

echo "-- 13. the member set root after a switch: a workspace's own index view holds its own members only --"
rigSwitchRoot(){ ## skillset root carried -- the root after a switch from ws-here to ws-there
	env -i PATH="$PATH" MMDAPP="$rigWork/ws-here" MDAT_SKILLSET_ROOT="$1" bash -c '. "$1" ; '"$rigSwitchFn"' "$2" ; printf "%s" "${MDAT_SKILLSET_ROOT:-}"' rig-switch "$rigResolveInclude" "$rigWork/ws-there"
}
rigAssert "a root that was the old workspace's own index view becomes the new workspace's own" "$( rigSwitchRoot "$rigWork/ws-here/.local/agents/members" )" "$rigWork/ws-there/.local/agents/members"
rigAssert "accepted sibling: a root set anywhere else is kept across the switch" "$( rigSwitchRoot "$rigElsewhere" )" "$rigElsewhere"
rigAssert "the spawn proxy gives every session it starts a member set root along with its workspace, never the workspace alone" "$( [ "$( LC_ALL=C grep -c 'env MMDAPP="\$spawnWorkspace" MDAT_SKILLSET_ROOT="\$spawnSkillsetRoot"' "$rigSpawnInclude" || : )" -gt 0 ] && printf given || printf none ) $( LC_ALL=C grep 'env MMDAPP="\$spawnWorkspace"' "$rigSpawnInclude" | LC_ALL=C grep -vc 'MDAT_SKILLSET_ROOT=' || : )" "given 0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MEMBER WORKSPACE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MEMBER_WORKSPACE: OK (%d assertions, offline)\n' "$rigPasses"
