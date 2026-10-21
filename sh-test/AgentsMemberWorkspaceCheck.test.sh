#!/usr/bin/env bash
## Behavioural check on the rule a team-member operation runs by, run rather than read, against a fixture machine built
## here: a HOME holding the machine-wide member directory (member, workspace root, link kind, path, member directory) and
## the tracked workspaces list (absolute paths), both in $HOME/.agents/magic-team, and several workspace directories under
## one rig tree, each with its own member set view, settings scopes, names registry and console. The rule held: WE RUN
## FROM HERE. An operation naming a team member runs in the workspace it was called from, for everything: that
## workspace's settings for the member, its team data, its records and its Slack. A member set up only in another
## workspace on this machine is invited: its skillset is read from the workspace it is set up in, the call is re-run
## exactly once under that member set root, and it is stopped only when that part cannot be brought, by a message
## naming what is missing and where it was looked for. One more thing follows it, its own settings of a system (Slack,
## mail, Jira, Confluence, Trello, Google) that the calling workspace holds none of: read from the workspace it is set
## up in, system by system and each whole, and said in one line; a team-wide setting, a key that is no system's and
## any setting of a member set up here are never read from elsewhere. A spawn of an invited member is launched by
## the console of the workspace it was called from, with MMDAPP that workspace and the member set root the member's own
## workspace view, its record, items and thread where it was asked; it retries and closes as any spawn. Its record and
## its dispatch item name the three workspaces of the run, which executes it, which pays for it and which is its
## member's, and its start post those that are not the calling one. The CLI service and credentials a spawn is started
## with are the calling workspace's, unless another workspace this machine knows is named to pay: for every spawn, for
## one member or for one task. A client-* member
## is invited like any other: its operation and its session run in the workspace they were called from, on the settings
## that workspace holds for it, its own of a system that workspace holds none of read from the workspace it is set up
## in as any invited member's are, and which organisation an operation reaches is said by its prefix and its address
## (AgentsClientSidesCheck holds that rule). Where a member is set up is the resolver's answer, unchanged: the current workspace when the member is
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
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigResolveInclude="$rigHere/member/AgentsTools.MemberWorkspace.include"
rigSpawnInclude="$rigHere/session/AgentsTools.InternOpAgentSpawnProxy.include"
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
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
## A scan or an iteration of the main loop starts the control thread of a session of its rig that is not finished: what was started is ended before the tree is removed.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsMemberWorkspaceCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## A loop in the code under test must end the check rather than hang it: nothing here legitimately runs long.
rigProcNote $$
( sleep 900 ; rigProcSignal TERM $$ ) > /dev/null 2>&1 &
rigDog=$! ; rigProcNote "$rigDog"
## The watchdog itself is stopped before its sleep: a sleep ended first would let it signal a check that finished.
trap 'rigProcSignalWithChildren TERM "$rigDog" ; wait "$rigDog" 2> /dev/null ; chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWork="$rigTmp/work" ; rigHome="$rigTmp/home" ; rigElsewhere="$rigHome/elsewhere/members"
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
	printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator\ninvitees: magic-team\nrequires-session-kind: coworking\n---\n# rig coworking routine fixture\n' > "$1/magic-team.coworking.routine.md"
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
	## client-ndm's own contacts in each workspace that holds it: a send presenting into
	## a client workspace passes the outbound contact gate (AgentsToolsContactAssertKnown)
	## only for a recipient that is a coordinate of a contact it holds, and these are the
	## rig's own channels and owners there.
	. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-contacts.include.sh" || exit 1
	for wsName in ws-there ws-rig ; do
		rigContactSeed "$rigWork/$wsName/.local/agents/team-data-root" client-ndm rig-team-there CTHERE0001 -
		rigContactSeed "$rigWork/$wsName/.local/agents/team-data-root" client-ndm rig-owner-there UTHEREOWNER -
		rigContactSeed "$rigWork/$wsName/.local/agents/team-data-root" client-ndm rig-team-rig CRIG000001 -
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
	( cd "$rigWork/$1" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/$1" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "${@:2}" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigTraceIn(){ ## workspace, args... -- the same under bash -x; the trace in $rigTmp/trace
	: > "$rigTmp/calls" ; : > "$rigTmp/envs" ; : > "$rigTmp/bodies"
	rigRc=0
	( cd "$rigWork/$1" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/$1" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" ${rigPre[@]+"${rigPre[@]}"} \
		bash -x "$rigTool" "${@:2}" ) > "$rigTmp/out" 2> "$rigTmp/trace" < /dev/null || rigRc=$?
}
rigResolve(){ ## workspace, member, operation -- the resolver on its own; stdout in resOut, stderr in resErr, rc in resRc
	resRc=0
	( env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/$1" MDSC_CMD=RigCmd bash -c '. "$1" ; '"$rigResolveFn"' "$2" "$3"' rig-resolve "$rigResolveInclude" "$2" "${3:-RigOp}" ) > "$rigTmp/resOut" 2> "$rigTmp/resErr" || resRc=$?
	resOut="$( cat "$rigTmp/resOut" )" ; resErr="$( cat "$rigTmp/resErr" )"
}
rigBring(){ ## workspace, member, operation -- the bring on its own, under the member set root rigPre carries, if any; stdout in brOut, stderr in brErr, rc in brRc
	brRc=0
	( env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/$1" MDSC_CMD=RigCmd ${rigPre[@]+"${rigPre[@]}"} bash -c '. "$1" ; '"$rigBringFn"' "$2" "$3"' rig-bring "$rigResolveInclude" "$2" "${3:-RigOp}" ) > "$rigTmp/brOut" 2> "$rigTmp/brErr" || brRc=$?
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
rigRunIn ws-here --slack-send-message keeper-here magic-team RIG-BODY
rigAssert "its send: its own token, channel and header"                      "$( rigTokens )$( rigChannel ) $( rigText )" 'rig-user-token-KHERE CHERE0001 🔧 *_keeper-here_* @herakeep → @here.\nRIG-BODY'
rm -f "$( rigView ws-here )/magic-team"
rigRunIn ws-here --member-help keeper-here
rigAssert "a file its help needs that this view cannot give stops the help: rc 1, the file and the view it looked in named, no help printed, never an empty floor with rc 0" "$rigRc $( rigN "$rigTmp/err" "⛔ ERROR: DistroAgentsKnowledge --member-help: the team's own operations cannot be read for keeper-here: $( rigView ws-here )/magic-team/magic-team.armed.md not found in the member set view $( rigView ws-here ) -- the help was not completed" ) $( rigN "$rigTmp/err" '# Tooling help output' ) $( rigN "$rigTmp/err" "can't open file" )" "1 1 0 0"
rigMemberAt ws-here magic-team
rigRunIn ws-here --member-help keeper-here
rigAssert "accepted sibling: with the team's folder in the view again, the same help is printed" "$rigRc $( rigN "$rigTmp/err" '# Tooling help output' ) $( rigHelpNames "$( rigView ws-here )/keeper-here/keeper-here.armed.md" )" "0 1 1"

echo "-- 5. the dispatcher: an operation naming an invited member runs in the workspace it was called from --"
rigWorld
rigRunIn ws-here --agents-config-option keeper-there --select WHERE
rigAssert "it reads the settings of the workspace it was called from, which holds none for it: for a key that is no system's nothing is answered, its own workspace's is not read, and stderr has no note about a workspace being changed" "$rigRc [$( cat "$rigTmp/out" )] $( rigQuiet )" "0 [] 0"
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
rigRunIn ws-here --slack-send-message keeper-there magic-team RIG-BODY
rigInvitedEnv="$( rigEnvLine chat.postMessage )"
rigAssert "it is not carried: when curl was called MMDAPP was the workspace it was called from, and the tooling origin was kept" "$rigRc $( rigEnvOf chat.postMessage MMDAPP ) $( rigEnvOf chat.postMessage ORIGIN )" "0 $rigWork/ws-here $MDLT_ORIGIN"
rigAssert "its team data is that workspace's own"                          "$( rigEnvOf chat.postMessage DATAROOT )" "$rigWork/ws-here/.local/agents/team-data-root"
rigAssert "the member's own workspace is left as it was: nothing written under its .local" "$( rigTreeSum ws-there )" "$rigSumThere"
rigRunIn ws-here --slack-send-message keeper-here magic-team RIG-BODY
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
rigAssert "(d) the view of its workspace lacks the team's own folder: stopped at the bring, by name, rc 1, so no reader meets a half view: no help is begun and no file is reported as one that could not be opened" "$rigRc $( rigN "$rigTmp/err" "⛔ ERROR: DistroAgentsKnowledge --member-help: member 'keeper-there' cannot be brought into the workspace this operation runs from, $rigWork/ws-here: the team's own folder cannot be read where its skillset is -- nothing was done. Looked for the team's directory at $( rigView ws-there )/magic-team, in $rigWork/ws-there, the workspace" ) $( rigN "$rigTmp/err" '# Duty instructions' ) $( rigN "$rigTmp/err" "can't open file" )" "1 1 0 0"
rigMemberAt ws-there magic-team
rigRunIn ws-here --member-help keeper-there
rigAssert "(d) accepted sibling: with the team's folder there again, the help is printed, read from that view" "$rigRc $( rigN "$rigTmp/err" '# Tooling help output' ) $( rigHelpNames "$( rigView ws-there )/keeper-there/keeper-there.armed.md" )" "0 1 1"
rigMemberAt gone/ws-gone magic-team ; rigMemberAt gone/ws-gone keeper-gone ; mkdir -p "$rigWork/gone/ws-gone/.local/.agents" ; printf 'WHERE=ws-gone\n' > "$rigWork/gone/ws-gone/.local/.agents/keeper-gone.agent.env"
mkdir -p "$rigWork/ws-nolist/.local/.agents" ; rigListAdd "$rigWork/ws-nolist" ; rigMemberAt ws-nolist magic-team ; rigMemberAt ws-nolist keeper-nowhere ; printf 'WHERE=ws-nolist\n' > "$rigWork/ws-nolist/.local/.agents/keeper-nowhere.agent.env"
rigRunIn ws-here --agents-config-option keeper-gone --select WHERE
rigAssert "(b) accepted sibling: with its workspace there and the member set up in it, the operation runs, here, and that workspace's setting for it is still not read" "$rigRc [$( cat "$rigTmp/out" )]" "0 []"
rigRunIn ws-here --agents-config-option keeper-nowhere --select WHERE
rigAssert "(a) accepted sibling: once its workspace is tracked and it is set up there, the same"     "$rigRc [$( cat "$rigTmp/out" )]" "0 []"

echo "-- 5b. an invited member's own settings of a system the calling workspace holds none of are read from the workspace it is set up in --"
rigWorld
## SETTINGS FALLBACK. keeper-there is set up only in ws-there, where it holds settings of three systems; ws-here holds
## none for it. A system is the keys that begin with its name: SLACK_, EMAIL_, JIRA_, CONFLUENCE_, TRELLO_, GOOGLE_.
rigFallbackSaid(){ ## -- how many lines of the last call's stderr say a member's own settings are read from elsewhere
	rigN "$rigTmp/err" "holds no settings of its own in"
}
rigScopeOf ws-there keeper-there 'WHERE=ws-there' 'SLACK_USER_TOKEN=rig-user-token-KTHERE' 'SLACK_WORKSPACE_DOMAIN=kthere.slack.invalid' 'JIRA_SITE=jira-kthere.invalid' 'JIRA_USER=kthere@rig.invalid' 'EMAIL_USER=kthere@rig.invalid'
rigSumThere="$( rigTreeSum ws-there )"
rigRunIn ws-here --agents-config-option keeper-there --select SLACK_USER_TOKEN
rigAssert "its own setting of a system the workspace it was called from holds none of is read from the workspace it is set up in" "$rigRc [$( cat "$rigTmp/out" )]" "0 [rig-user-token-KTHERE]"
rigAssert "and the tooling says so in one line: the member, each such system by its key prefix, the workspace that holds none and the one they are read from" "$( rigFallbackSaid ) $( rigN "$rigTmp/err" "# DistroAgentsTools --agents-config-option: member 'keeper-there' holds no settings of its own in $rigWork/ws-here for SLACK_*, EMAIL_*, JIRA_* -- each is read from $rigWork/ws-there, the workspace it is set up in" )" "1 1"
rigRunIn ws-here --agents-config-option keeper-there --select JIRA_USER
rigAssert "another system's the same" "$rigRc [$( cat "$rigTmp/out" )]" "0 [kthere@rig.invalid]"
rigRunIn ws-here --agents-config-option keeper-there --select-default EMAIL_USER rig-default
rigAssert "a read with a default answers that workspace's value" "$rigRc [$( cat "$rigTmp/out" )]" "0 [kthere@rig.invalid]"
rigRunIn ws-here --agents-config-option keeper-there --select-default EMAIL_SMTP_HOST rig-default
rigAssert "and the default where that workspace holds the system but not the key" "$rigRc [$( cat "$rigTmp/out" )]" "0 [rig-default]"
rigRunIn ws-here --agents-config-option keeper-there --select SLACK_BOT_TOKEN
rigAssert "a key its own workspace lacks is none: the system is read there, whole, and nothing of this workspace's team is put in its place" "$rigRc [$( cat "$rigTmp/out" )]" "0 []"
rigRunIn ws-here --agents-config-option keeper-there --select CONFLUENCE_SITE
rigAssert "a system neither workspace holds for it is none, and is not in the line" "$rigRc [$( cat "$rigTmp/out" )] $( rigN "$rigTmp/err" 'CONFLUENCE_' )" "0 [] 0"
rigRunIn ws-here --agents-config-option keeper-there --select WHERE
rigAssert "a key that is no system's is never read from there, though that workspace holds it" "$rigRc [$( cat "$rigTmp/out" )]" "0 []"
rigRunIn ws-here --agents-config-option keeper-there --select-all
rigAssert "the listing of a scope is the calling workspace's own, which holds none" "$rigRc [$( cat "$rigTmp/out" )]" "0 []"
rigAssert "the member's own workspace is only read: nothing written under its .local" "$( rigTreeSum ws-there )" "$rigSumThere"
rigScopeOf ws-here keeper-there 'JIRA_SITE=jira-khere.invalid'
rigRunIn ws-here --agents-config-option keeper-there --select JIRA_SITE
rigAssert "system by system: one setting of a system held here, and that system is read here" "$rigRc [$( cat "$rigTmp/out" )]" "0 [jira-khere.invalid]"
rigRunIn ws-here --agents-config-option keeper-there --select JIRA_USER
rigAssert "alone, what it lacks here too: no credential is put together from two workspaces" "$rigRc [$( cat "$rigTmp/out" )]" "0 []"
rigRunIn ws-here --agents-config-option keeper-there --select SLACK_USER_TOKEN
rigAssert "while a system this workspace still holds none of is read from its own workspace as before, and the line names those systems only" "$rigRc [$( cat "$rigTmp/out" )] $( rigN "$rigTmp/err" "for SLACK_*, EMAIL_* -- each is read from $rigWork/ws-there" )" "0 [rig-user-token-KTHERE] 1"
rigRunIn ws-here --agents-config-option keeper-there --upsert SLACK_CONVERSATIONS CHERE0001
rigRunIn ws-here --agents-config-option keeper-there --select SLACK_USER_TOKEN
rigAssert "a setting written for it is written here, never there, and from then on its system is this workspace's" "$rigRc [$( cat "$rigTmp/out" )] $( rigN "$rigWork/ws-here/.local/.agents/keeper-there.agent.env" 'SLACK_CONVERSATIONS=CHERE0001' ) $( rigN "$rigWork/ws-there/.local/.agents/keeper-there.agent.env" 'SLACK_CONVERSATIONS' )" "0 [] 1 0"
rm -f "$rigWork/ws-here/.local/.agents/keeper-there.agent.env"
rigScopeOf ws-there keeper-multi 'WHERE=ws-there' 'SLACK_USER_TOKEN=rig-user-token-MULTITHERE'
rigScopeOf ws-third keeper-multi 'WHERE=ws-third' 'SLACK_USER_TOKEN=rig-user-token-MULTITHIRD'
rigRunIn ws-here --agents-config-option keeper-multi --select SLACK_USER_TOKEN
rigAssert "set up in two others: from the workspace it is set up in by the resolver's answer, its source link" "$rigRc [$( cat "$rigTmp/out" )] $( rigN "$rigTmp/err" "each is read from $rigWork/ws-third, the workspace it is set up in" )" "0 [rig-user-token-MULTITHIRD] 1"
rigRunIn ws-there --agents-config-option keeper-here --select SLACK_USER_TOKEN
rigAssert "and the other way: called from ws-there, a member set up only in ws-here" "$rigRc [$( cat "$rigTmp/out" )]" "0 [rig-user-token-KHERE]"
rigScopeOf ws-there keeper-both 'WHERE=ws-there' 'SLACK_USER_TOKEN=rig-user-token-KBOTHTHERE' 'JIRA_SITE=jira-kboth-there.invalid'
rigRunIn ws-here --agents-config-option keeper-both --select JIRA_SITE
rigAssert "never for a member set up here: a system this workspace holds none of for it is none, though another workspace it is set up in holds it, and nothing is said" "$rigRc [$( cat "$rigTmp/out" )] $( rigFallbackSaid )" "0 [] 0"
rigRunIn ws-third --agents-config-option magic-team --select SLACK_WORKSPACE_DOMAIN
rigAssert "never for the team's own settings: a workspace whose magic-team scope lacks one answers none, whatever the others hold" "$rigRc [$( cat "$rigTmp/out" )] $( rigFallbackSaid )" "0 [] 0"
rigRunIn ws-here --agents-config-option keeper-unknown --select SLACK_USER_TOKEN
rigAssert "never for a name the index does not know" "$rigRc [$( cat "$rigTmp/out" )] $( rigFallbackSaid )" "0 [] 0"
rigRunIn ws-here --slack-send-message keeper-there magic-team RIG-BODY
rigAssert "a whole operation says it once, however many settings it reads on the way" "$rigRc $( rigFallbackSaid ) $( rigN "$rigTmp/err" "# DistroAgentsSlack --slack-send-message: member 'keeper-there' holds no settings of its own in $rigWork/ws-here for SLACK_*, EMAIL_*, JIRA_*" )" "0 1 1"
rigPre=( "MDAT_SKILLSET_ROOT=$( rigView ws-there )" )
rigRunIn ws-here --slack-send-message keeper-there magic-team RIG-BODY
rigAssert "and inside its own session, which already reads its member set root, a call does not say it again, and reads the same" "$rigRc $( rigFallbackSaid ) $( rigTokens )" "0 0 rig-user-token-KTHERE "
rigPre=()
rigRunIn ws-here --slack-send-message keeper-here magic-team RIG-BODY
rigAssert "control: nothing is said for a member set up here" "$rigRc $( rigFallbackSaid ) $( rigTokens )" "0 0 rig-user-token-KHERE "
rigWorld

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
rigTraceIn ws-here --slack-send-message keeper-there magic-team RIG-BODY
rigAssert "a send, whose stub reaches its implementation and the Slack call under it by the same door: one re-run still, one post" "$rigRc $( rigN "$rigTmp/trace" "export MDAT_SKILLSET_ROOT=/" ) $( rigN "$rigTmp/trace" "$rigReRun" ) $( rigN "$rigTmp/calls" "chat.postMessage " )" "0 1 1 1"

echo "-- 7. an invited member talks in the Slack of the workspace it was called from, under its own identity --"
## Two workspaces, each with its own team settings. keeper-there is set up only in ws-there, where it has an identity of
## its own and a row in the names registry; ws-here holds no setting and no row for it. The conversation and the
## team's bot are the calling workspace's; its own identity, a Slack setting ws-here holds none of for it, is read
## from the workspace it is set up in, and so are its mark and alias, its row of that workspace's names registry.
rigWorld
rigRunIn ws-here --slack-send-message keeper-there magic-team RIG-BODY
rigAssert "its send goes to the team's channel of the workspace it was called from, under its own identity, which that workspace holds none of and its own does" "$rigRc $( rigTokens )$( rigChannel )" "0 rig-user-token-KTHERE CHERE0001"
rigAssert "under its own name, with the mark and alias of its row in the names registry of the workspace it is set up in: the calling workspace's registry holds no row for it" "$( rigText )" '🔧 *_keeper-there_* @therekeep → @here.\nRIG-BODY'
rigAssert "nothing of the team of the workspace it is set up in is used: not its bot, not its channel" "$( rigN "$rigTmp/calls" 'bot-token-THERE' ) $( rigN "$rigTmp/bodies" 'CTHERE0001' )" "0 0"
rigRunIn ws-here --slack-read keeper-there magic-team
rigAssert "its read is made under the same identity"                       "$rigRc $( rigHistoryToken )" "0 rig-user-token-KTHERE "
rigRunIn ws-here --slack-send-message keeper-multi magic-team RIG-BODY
rigAssert "a member with no identity of its own in either workspace posts as the team bot of the workspace it was called from, in that team's channel" "$rigRc $( rigTokens )$( rigChannel )" "0 rig-bot-token-HERE CHERE0001"
rigRunIn ws-here --slack-react keeper-there CHERE0001:1.000001 eyes
rigAssert "an error says which Slack the call used and that it is the one of the workspace the operation runs in" "$( rigN "$rigTmp/err" "THIS CALL USED the Slack here.slack.invalid, by the settings of the workspace $rigWork/ws-here (the workspace this operation runs in)" )" 1
rigAssert "and that a conversation of another Slack is not a missing bot"  "$( rigN "$rigTmp/err" 'check which Slack the target belongs to before reading this as a bot that is not in the channel' )" 1
rigAssert "and where the member's own Slack settings were read from, being another workspace's" "$( rigN "$rigTmp/err" "(the workspace this operation runs in), the member's own Slack settings read from $rigWork/ws-there, the workspace it is set up in" )" 1
rigRunIn ws-here --slack-react keeper-here CHERE0001:1.000001 eyes
rigAssert "control: for a member set up here the same error names this workspace's settings and no other workspace" "$( rigN "$rigTmp/err" "by the settings of the workspace $rigWork/ws-here (the workspace this operation runs in)" ) $( rigN "$rigTmp/err" "the member's own Slack settings read from" )" "1 0"
rigRunIn ws-here --slack-react client-ndm CHERE0001:1.000001 eyes
rigAssert "nor for a client on our own organisation's side, where its own Slack settings are not read at all, wherever it is set up" "$( rigN "$rigTmp/err" "by the settings of the workspace $rigWork/ws-here (the workspace this operation runs in)" ) $( rigN "$rigTmp/err" "the member's own Slack settings read from" )" "1 0"
printf '%s\n' 'keeper-there 🔧 There Keeper therekeep' >> "$rigWork/ws-here/.local/agents/team-members-names.registry"
rigRunIn ws-here --slack-send-message keeper-there magic-team RIG-BODY
rigAssert "accepted sibling: with a row for it in the names registry of the workspace it was called from, its header is that row's" "$( rigTokens )$( rigText )" 'rig-user-token-KTHERE 🔧 *_keeper-there_* @therekeep → @here.\nRIG-BODY'
rigScopeOf ws-here keeper-there 'SLACK_USER_TOKEN=rig-user-token-KTHEREINHERE'
rigRunIn ws-here --slack-send-message keeper-there magic-team RIG-BODY
rigAssert "accepted sibling: with an identity for it in the settings of the workspace it was called from, it posts under that one, and its own workspace's is not read" "$rigRc $( rigTokens )$( rigChannel ) $( rigN "$rigTmp/calls" 'KTHERE ' )" "0 rig-user-token-KTHEREINHERE CHERE0001 0"
rigRunIn ws-there --slack-send-message keeper-here magic-team RIG-BODY
rigAssert "and the other way: called from ws-there, a member set up only in ws-here posts under its own identity in ws-there's channel" "$rigRc $( rigTokens )$( rigChannel )" "0 rig-user-token-KHERE CTHERE0001"
rigRunIn ws-there --slack-send-message keeper-there magic-team RIG-BODY
rigAssert "control: called from the workspace it is set up in, its own identity, channel and header there" "$( rigTokens )$( rigChannel ) $( rigText )" 'rig-user-token-KTHERE CTHERE0001 🔧 *_keeper-there_* @therekeep → @here.\nRIG-BODY'

echo "-- 8. a client-* member is invited like any other: its operation runs in the workspace it was called from --"
rigWorld
rigRunIn ws-here --agents-config-option client-ndm --select WHERE
rigAssert "a client set up only in another workspace reads the settings of the workspace it was called from, which holds none for it: for a key that is no system's nothing is answered, the settings of the workspace it is set up in are not read, and stderr has no note about a workspace being changed" "$rigRc [$( cat "$rigTmp/out" )] $( rigQuiet )" "0 [] 0"
## The client's own settings for the other organisation, held in the workspace it is called from, with the persona
## member's row in that workspace's names registry and the client's contacts there: what a send into the other
## organisation needs. The registry holds that workspace's own members, so it has no row for the invited client.
rigClientHere(){
	rigScopeOf ws-here client-ndm 'WHERE=ws-here' 'SLACK_USER_TOKEN=rig-user-token-NDMHERE' 'JIRA_SITE=jira-here.invalid' 'JIRA_USER=ndm-here@rig.invalid' 'JIRA_API_TOKEN=rig-jira-token-HERE'
	printf '%s\n' 'magic-coordinator 🐭 Magic Vane dispatchr' >> "$rigWork/ws-here/.local/agents/team-members-names.registry"
	. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-contacts.include.sh" || exit 1
	rigContactSeed "$rigWork/ws-here/.local/agents/team-data-root" client-ndm rig-ndm-team CNDM00001 -
}
rigClientHere
rigRunIn ws-here --agents-config-option client-ndm --select WHERE
rigAssert "accepted sibling: a setting the workspace it was called from holds for the client is the one read" "$rigRc [$( cat "$rigTmp/out" )]" "0 [ws-here]"
rigAssert "the caller's own shell keeps its MMDAPP after the call"          "$( MMDAPP="$rigWork/ws-here" ; ( cd "$rigWork/ws-here" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$MMDAPP" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" bash -c 'bash "$1" --agents-config-option client-ndm --select WHERE > /dev/null 2>&1 ; printf "%s" "$MMDAPP"' rig-shell "$rigTool" ) )" "$rigWork/ws-here"
rigTraceIn ws-here --agents-config-option client-ndm --select WHERE
rigAssert "its call is re-run once under its own member set root, as any invited member's is, and is switched to no workspace" "$rigRc $( cat "$rigTmp/out" ) $( rigN "$rigTmp/trace" "export MDAT_SKILLSET_ROOT=$( rigView ws-there )" ) $( rigN "$rigTmp/trace" "export MDAT_SKILLSET_ROOT=/" ) $( LC_ALL=C grep -c "+ $rigSwitchFn " "$rigTmp/trace" || : )" "0 ws-here 1 1 0"
rigRunIn ws-here --member-help client-ndm
rigAssert "its skillset is read from the view of the workspace it is set up in"  "$rigRc $( rigHelpNames "$( rigView ws-there )/client-ndm/client-ndm.armed.md" )" "0 1"
rigSumThere="$( rigTreeSum ws-there )"
rigPre=( MDSC_CACHED=/stale/cache MDSC_ID_RIGSTALE=stale "MDAT_DATA_ROOT=$rigWork/ws-here/.local/agents/team-data-root" )
rigRunIn ws-here --slack-send-message client-ndm magic-team RIG-BODY
rigClientEnv="$( rigEnvLine chat.postMessage )"
rigAssert "its send is not carried: when curl was called MMDAPP was the workspace it was called from, the tooling origin was kept, and so was the data root the caller carried" "$rigRc $( rigEnvOf chat.postMessage MMDAPP ) $( rigEnvOf chat.postMessage ORIGIN ) $( rigEnvOf chat.postMessage DATAROOT )" "0 $rigWork/ws-here $MDLT_ORIGIN $rigWork/ws-here/.local/agents/team-data-root"
rigRunIn ws-here --slack-send-message keeper-here magic-team RIG-BODY
rigAssert "the environment its call ran in is, field for field, the one a member set up here gets" "$rigClientEnv" "$( rigEnvLine chat.postMessage )"
rigPre=()
rigRunIn ws-here --slack-send-message client-ndm magic-team RIG-BODY
rigAssert "a --member- send of a client reaches our own team: the bot and the channel of the workspace it was called from" "$rigRc $( rigTokens )$( rigChannel )" "0 rig-bot-token-HERE CHERE0001"
rigAssert "under its own name, with the mark of its row in the names registry of the workspace it is set up in, its member name as its alias and never its persona's, and its metadata" "$( rigText ) $( rigN "$rigTmp/bodies" '"metadata"' )" '🐭 *_client-ndm_* → @here.\nRIG-BODY 1'
rigAssert "no token the client holds was used, in either workspace, and nothing of the workspace it is set up in" "$( rigN "$rigTmp/calls" 'NDMHERE' ) $( rigN "$rigTmp/calls" 'NDMTHERE' ) $( rigN "$rigTmp/calls" 'token-THERE' ) $( rigN "$rigTmp/bodies" 'CTHERE0001' )" "0 0 0 0"
rigRunIn ws-here --client-comms-slack-send-message client-ndm CNDM00001 RIG-BODY
rigAssert "a --client- send of the same client reaches the other organisation: the token this workspace holds for the client, the conversation named by its id" "$rigRc $( rigTokens )$( rigChannel )" "0 rig-user-token-NDMHERE CNDM00001"
rigAssert "under the names of the persona member's row in this workspace's registry, which is an invited client's row, with no client identifier and no metadata in the payload" "$( rigText ) $( rigN "$rigTmp/bodies" 'client-ndm' ) $( rigN "$rigTmp/bodies" '"metadata"' )" '🐭 *_Magic Vane_* @dispatchr → @here.\nRIG-BODY 0 0'
rigAssert "it ran in the workspace it was called from, and the team's bot and the other workspace's token for the client were not used" "$( rigEnvOf chat.postMessage MMDAPP ) $( rigN "$rigTmp/calls" 'rig-bot-token' ) $( rigN "$rigTmp/calls" 'NDMTHERE' )" "$rigWork/ws-here 0 0"
rigAssert "the workspace the client is set up in is left as it was: nothing written under its .local" "$( rigTreeSum ws-there )" "$rigSumThere"
rigRunIn ws-here --client-comms-jira-board-list client-ndm
rigAssert "a --client-* Jira operation runs here too: the call goes to the site this workspace's scope holds for the client, as that scope's user"  "$rigRc $( LC_ALL=C awk '$1 == "http" { print $2, $3 }' "$rigTmp/calls" ) $( rigEnvOf http MMDAPP )" "0 jira-here.invalid ndm-here@rig.invalid $rigWork/ws-here"
rigRunIn ws-rig --client-comms-jira-board-list client-ndm
rigAssert "from a workspace the index has no row for: its own scope's site" "$( LC_ALL=C awk '$1 == "http" { print $2, $3 }' "$rigTmp/calls" )" "jira-rig.invalid rig@rig.invalid"
rigRunIn ws-rig --client-comms-slack-send-message client-ndm CRIG000001 RIG-BODY
rigAssert "and there its own token and row for the client" "$( rigTokens )$( rigChannel ) $( rigText )" 'rig-user-token-NDMRIG CRIG000001 🐭 *_Rig Persona_* @rigalias → @here.\nRIG-BODY'
rigIndexOff
rigRunIn ws-here --client-comms-jira-board-list client-ndm
rigAssert "control: with no index the client is not invited, and is not set up here: refused, naming this workspace's view, no call made" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigN "$rigTmp/err" "no such member skill directory: $( rigView ws-here )/client-ndm" )" "1 0 1"
rigIndexOn
rigRunIn ws-here --intern-op-client-sweep-input-scan keeper-nowhere
rigAssert "a --client-* operation names the same refusal for a known member in no tracked workspace" "$rigRc $( rigN "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --intern-op-client-sweep-input-scan: member 'keeper-nowhere' is in the team members index but is present in no tracked workspace -- nothing was done" )" "1 1"
rigRunIn ws-here --intern-op-client-sweep-input-scan client-ndm
rigAssert "accepted sibling: a client set up in another workspace is not refused there, its own operation answers" "$( rigN "$rigTmp/err" "present in no tracked workspace" ) $( rigN "$rigTmp/err" "is not present on this machine" )" "0 0"
rm -f "$( rigView ws-there )/client-ndm"
rigRunIn ws-here --client-comms-slack-send-message client-ndm CNDM00001 RIG-BODY
rigAssert "(c) a client whose skillset cannot be brought is stopped as any invited member is, by name, and nothing is called" "$rigRc $( rigLines "$rigTmp/calls" ) $( rigN "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --client-comms-slack-send-message: member 'client-ndm' cannot be brought into the workspace this operation runs from, $rigWork/ws-here: its skillset cannot be read -- nothing was done." )" "1 0 1"
rigMemberAt ws-there client-ndm

## ---- spawning ----
rigSpawnIn(){ ## workspace, member, extra args... -- the spawn proxy asked for that member from that workspace, task text on stdin; output in out
	: > "$rigTmp/calls" ; : > "$rigTmp/envs" ; : > "$rigTmp/bodies" ; rm -f "$rigTmp"/launched.* "$rigTmp"/roots.* "$rigTmp"/brief.*
	rigRc=0
	( cd "$rigWork/$1" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/$1" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" \
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
rigAssert "a client-* member is invited like any other: launched by the console of the workspace it was called from, on the view of the workspace it is set up in" "$rigRc $( rigLaunched ) $( rigRoots HERE )" "0 HERE=ws-here client-ndm=ws-there/.local/agents/members"
rigAssert "its session thread is opened in the Slack of the workspace it was called from, by that team's bot" "$( rigTokens )$( rigChannel ) $( rigN "$rigTmp/calls" 'token-THERE' )" "rig-bot-token-HERE CHERE0001 0"
rigAssert "and its record is in the workspace it was called from, none in the workspace it is set up in" "$(( $( rigSpawnedCount ws-here ) - rigSpawnedBefore )) $(( $( rigSpawnedCount ws-there ) - rigSpawnedBeforeThere ))" "1 0"

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
( cd "$rigWork/ws-here" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/ws-here" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" \
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
rigRecord="$MDAT_SPAWN_SANDBOX_ROOT/$MDAT_SPAWN_SESSION_ID.spawn.md"
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
rigRetrySpawn(){ ## close mode -- one async spawn of keeper-there, invited into ws-here, then up to 30 s for its own close to stamp the record, and as long again for the rest of that close
	rm -f "$rigTmp"/start.* "$rigTmp/record.path" "$rigTmp/transcript.seen" ; : > "$rigTmp/calls" ; : > "$rigTmp/bodies"
	rigRc=0
	( cd "$rigWork/ws-here" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/ws-here" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_CLOSE="$1" \
		bash "$rigTool" --intern-op-agent-spawn-proxy keeper-there --spawn-cli-service rig-service --dispatch-doc:none --context rig-ws-invited ) > "$rigTmp/out" 2> "$rigTmp/err" <<< "RIG-TASK-TEXT" || rigRc=$?
	rigRetryLeft=30
	while [ "$rigRetryLeft" -gt 0 ] && ! { [ -s "$rigTmp/record.path" ] && LC_ALL=C grep -q '^resolved-at: ' "$( cat "$rigTmp/record.path" )" 2> /dev/null ; } ; do sleep 1 ; rigRetryLeft=$(( rigRetryLeft - 1 )) ; done
	## The record is closed first, and what is said of the end follows it: so the rest of the close is waited for too, until the shell that makes it (PID= of the receipt) has ended.
	rigRetryShell="$( LC_ALL=C sed -n 's/^PID=//p' "$rigTmp/out" | head -1 )"
	rigRetryLeft=30
	while [ "$rigRetryLeft" -gt 0 ] && [ -n "$rigRetryShell" ] && kill -0 "$rigRetryShell" 2> /dev/null ; do sleep 1 ; rigRetryLeft=$(( rigRetryLeft - 1 )) ; done
	rigRecordStatus="$( [ ! -s "$rigTmp/record.path" ] || LC_ALL=C sed -n 's/^status: //p' "$( cat "$rigTmp/record.path" )" 2> /dev/null | head -1 )"
	rigSessionLog="$( LC_ALL=C sed -n 's/^OUTPUT_FILE=//p' "$rigTmp/out" | head -1 )"
}
rigStarts(){ ## -- each start seen, with the record status at that start: launch=<status> true=<status>
	printf 'launch=%s true=%s' "$( cat "$rigTmp/start.launch" 2> /dev/null || printf none )" "$( cat "$rigTmp/start.true" 2> /dev/null || printf none )"
}
rigRetrySpawn open
rigAssert "control: an open session with no handback is retried once, and the retry runs while its record still says started" "$rigRc $( rigStarts )" "0 launch=spawn-started true=spawn-started"
rigAssert "control: the close comes after the retry, which handed back, so nothing says a handback is missing: no box, and no message in the session thread" "$rigRecordStatus $( rigN "$rigTmp/bodies" 'none posted' ) $( rigN "$rigTmp/bodies" 'posted no handback' )" "spawn-succeeded 0 0"
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
	## This workspace has no event-track conversation, so no tracking box is made: the session thread is told, in a message.
	rigAssert "instead ($rigCloseMode): the session thread is told the handback is missing, the reason is logged, and the close still runs" "$( [ "$( rigN "$rigTmp/bodies" 'posted no handback' )" -gt 0 ] && printf told || printf silent ) $( rigN "$rigTmp/bodies" 'none posted' ) $( rigN "$rigSessionLog" 'no handback retry for spawn' ) $rigRecordStatus" "told 0 1 spawn-succeeded"
done
rm -f "$rigTmp"/start.* "$rigTmp/record.path" "$rigTmp/transcript.seen"
rigConsole ws-here HERE

echo "-- 9d. the three workspaces of a run are on its record, its dispatch item and its start post --"
## Which workspace executes a run, which pays for it and which is its member's: on its spawn record and on its dispatch
## item always, each by its basename, and in its start post only where one is not the workspace it was called from.
rigWorld
## A start post goes out only where the workspace has a tracking conversation: set for this section alone.
printf 'SLACK_CHANNEL_EVENT_TRACK=CTRACK0001\n' >> "$rigWork/ws-here/.local/.agents/magic-team.agent.env"
rigSpawnDocIn(){ ## workspace, member, source and dispatch document args... -- rigSpawnIn with a dispatch document of the caller's choosing
	: > "$rigTmp/calls" ; : > "$rigTmp/envs" ; : > "$rigTmp/bodies" ; rm -f "$rigTmp"/launched.* "$rigTmp"/roots.* "$rigTmp"/brief.*
	rigRc=0
	( cd "$rigWork/$1" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/$1" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" \
		bash "$rigTool" --intern-op-agent-spawn-proxy "$2" "${@:3}" --wait --context rig-ws-invited ) > "$rigTmp/out" 2> "$rigTmp/err" <<< "RIG-TASK-TEXT" || rigRc=$?
}
rigThree(){ ## record or board item -- its executing, paying and member's workspace, and how many lines hold each: e/p/m n/n/n
	LC_ALL=C awk -F': ' '
		$1 == "executing-workspace" { e = $2 ; en++ }
		$1 == "paying-workspace" { p = $2 ; pn++ }
		$1 == "member-workspace" { m = $2 ; mn++ }
		END { printf "%s/%s/%s %d/%d/%d", e, p, m, en, pn, mn }' "$1" 2> /dev/null
}
rigRecordOf(){ ## workspace, member -- the newest spawn record of that member kept in that workspace
	local recordFiles
	recordFiles="$( LC_ALL=C grep -l -x "owner: $2" "$rigWork/$1"/.local/agents/spawned/*/*.spawn.md 2> /dev/null )"
	[ -z "$recordFiles" ] || ls -t $recordFiles | LC_ALL=C sed -n 1p
}
rigStartContext(){ ## -- the small grey text of the run box of the start post among the posted bodies, its host and its date masked
	LC_ALL=C grep -F '"tracking":"start"' "$rigTmp/bodies" | LC_ALL=C sed -n 's/.*"text":"\(where: [^"]*\)".*/\1/p' | LC_ALL=C sed -e 's/<!date[^>]*>/<date>/g' -e 's/^where: [^ ]* /where: <host> /'
}
rigSpawnIn ws-here keeper-there
rigAssert "an invited member's record: executed and paid by the workspace it was called from, its member's the one it is set up in, each line once" "$rigRc $( rigThree "$( rigRecordOf ws-here keeper-there )" )" "0 ws-here/ws-here/ws-there 1/1/1"
rigAssert "and the record's own workspace is still the one it is kept in" "$( LC_ALL=C sed -n 's/^workspace: //p' "$( rigRecordOf ws-here keeper-there )" )" "ws-here"
rigAssert "its start post says the member's workspace, after where it runs, and no paying workspace, which is the one it runs from" "$( rigStartContext )" "where: <host> / ws-here · started: <date> · member's workspace: ws-there"
rigSpawnIn ws-here keeper-here
rigAssert "control: a member set up here has all three one workspace, and they are written all the same" "$rigRc $( rigThree "$( rigRecordOf ws-here keeper-here )" )" "0 ws-here/ws-here/ws-here 1/1/1"
rigAssert "and its start post says its workspace once: neither the member's nor a paying one" "$( rigStartContext )" "where: <host> / ws-here · started: <date>"
rigSpawnIn ws-here keeper-multi
rigAssert "a member set up in two others: its member's workspace is the one its skillset is read from" "$rigRc $( rigThree "$( rigRecordOf ws-here keeper-multi )" )" "0 ws-here/ws-here/ws-third 1/1/1"
rigSpawnIn ws-there keeper-here
rigAssert "and the other way: called from ws-there, a member set up only in ws-here" "$rigRc $( rigThree "$( rigRecordOf ws-there keeper-here )" )" "0 ws-there/ws-there/ws-here 1/1/1"
rigSpawnDocIn ws-here keeper-there --dispatch-doc:create
rigDispatchItem="$( find "$rigWork/ws-here/.local/agents/team-data-root/board" -name 'dispatch-*.md' 2> /dev/null | LC_ALL=C tail -n 1 )"
rigAssert "the dispatch item a spawn creates carries the same three" "$rigRc $( rigThree "$rigDispatchItem" )" "0 ws-here/ws-here/ws-there 1/1/1"
mkdir -p "$rigWork/ws-here/.local/agents/team-data-root/board/backlog"
printf -- '---\ntype: task\n---\n\nRIG-BOARD-ITEM-TEXT\n' > "$rigWork/ws-here/.local/agents/team-data-root/board/backlog/task-rig-three.md"
rigSpawnDocIn ws-here keeper-there --from-board task-rig-three.md --dispatch-doc:reuse
rigAssert "a tracking item a spawn reuses is given them at its start mark, its own text kept" "$rigRc $( rigThree "$rigWork/ws-here/.local/agents/team-data-root/board/backlog/task-rig-three.md" ) $( rigN "$rigWork/ws-here/.local/agents/team-data-root/board/backlog/task-rig-three.md" 'RIG-BOARD-ITEM-TEXT' )" "0 ws-here/ws-here/ws-there 1/1/1 1"
rigSpawnDocIn ws-here keeper-there --from-board task-rig-three.md --dispatch-doc:reuse
rigAssert "and a second spawn on the same item writes each once more over the first, never a second line" "$rigRc $( rigThree "$rigWork/ws-here/.local/agents/team-data-root/board/backlog/task-rig-three.md" )" "0 ws-here/ws-here/ws-there 1/1/1"
rigAssert "control: a record with none of the three is told apart" "$( printf 'owner: rig\n' > "$rigTmp/three.none" ; rigThree "$rigTmp/three.none" )" "// 0/0/0"

echo "-- 9e. the workspace that pays: spawn settings are the calling workspace's, unless another known one is named for every spawn, for one member, or for one task --"
## The CLI service, the harness tier and the credentials of a harness leg are the spawn settings. Each workspace here
## holds its own, and one setting that is no spawn setting; the console records what its own reads answer, made as the
## real console makes them, so the row shows what a session would be started with.
rigPayConsole(){ ## workspace, label -- rigConsole, also recording what it was started with and what its own reads of the magic-team scope answer
	printf '%s\n' '#!/usr/bin/env bash' \
		'## --cli-configured --cli) stand-in: writes MDAT_SPAWN_LAUNCH_MARKER, records where it was started and what the settings it reads answer; hands back, unless RIG_HANDBACK=resume-only and this is the launch.' \
		"printf '%s\\n' \"\$MMDAPP\" > \"\$RIG_SCENARIO/launched.$2\"" \
		"printf '%s=%s\\n' \"\${MDAT_SPAWN_AGENT:-none}\" \"\${MDAT_SKILLSET_ROOT:-unset}\" >> \"\$RIG_SCENARIO/roots.$2\"" \
		'printf "%s\n" "$*" > "$RIG_SCENARIO/args.'"$2"'.${MDAT_SPAWN_RESUME:-launch}"' \
		'rigPaidLine="" ; for rigKey in SPAWN_CLI_SERVICE SPAWN_HARNESS_TIER XAI_API_KEY WEB_ALLOW_PREFIXES ; do rigPaidLine="$rigPaidLine$rigKey=$( "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --agents-config-option magic-team --select "$rigKey" 2> /dev/null ) " ; done' \
		'printf "%s\n" "${rigPaidLine% }" > "$RIG_SCENARIO/paid.'"$2"'.${MDAT_SPAWN_RESUME:-launch}"' \
		'cat > "$RIG_SCENARIO/brief.'"$2"'"' \
		'[ "${RIG_HANDBACK:-}" = resume-only ] && [ "${MDAT_SPAWN_RESUME:-}" != true ] || printf "📦 SubagentHandback\n"' \
		'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWork/$1/DistroAgentsConsole.sh"
	chmod +x "$rigWork/$1/DistroAgentsConsole.sh"
}
rigPayWorld(){ ## -- a fresh machine whose workspaces each hold spawn settings of their own, and ws-here the recording console
	rigWorld
	local payWs
	for payWs in here there third ; do
		printf 'SPAWN_CLI_SERVICE=rig-cli-%s\nSPAWN_HARNESS_TIER=tier-%s\nXAI_API_KEY=rig-xai-%s\nWEB_ALLOW_PREFIXES=https://%s.invalid/\n' "$payWs" "$payWs" "$payWs" "$payWs" >> "$rigWork/ws-$payWs/.local/.agents/magic-team.agent.env"
	done
	printf 'SLACK_CHANNEL_EVENT_TRACK=CTRACK0001\n' >> "$rigWork/ws-here/.local/.agents/magic-team.agent.env"
	rigPayConsole ws-here HERE
	rm -f "$rigTmp"/paid.*
}
rigPaid(){ ## [start] -- what the console's own reads answered at that start (launch, or true for the handback retry), the workspace each came from: cli/tier/credential/not-a-spawn-setting
	LC_ALL=C sed -e 's/SPAWN_CLI_SERVICE=rig-cli-//' -e 's/ SPAWN_HARNESS_TIER=tier-/\//' -e 's/ XAI_API_KEY=rig-xai-/\//' -e 's/ WEB_ALLOW_PREFIXES=https:\/\//\//' -e 's/\.invalid\/$//' "$rigTmp/paid.HERE.${1:-launch}" 2> /dev/null
}
rigPayTeam(){ ## workspace, name -- that name set to pay for every spawn of that workspace
	printf 'SPAWN_SETTINGS_WORKSPACE=%s\n' "$2" >> "$rigWork/$1/.local/.agents/magic-team.agent.env"
}
rigPayTeamOff(){ ## workspace -- and taken out again
	LC_ALL=C grep -v '^SPAWN_SETTINGS_WORKSPACE=' "$rigWork/$1/.local/.agents/magic-team.agent.env" > "$rigTmp/pay.off" ; cat "$rigTmp/pay.off" > "$rigWork/$1/.local/.agents/magic-team.agent.env"
}
rigPayRefused(){ ## -- how the last spawn was refused: its rc, what was launched, the records it added since rigSpawnedBefore
	printf '%s [%s] %s' "$rigRc" "$( rigLaunched )" "$(( $( rigSpawnedCount ws-here ) - rigSpawnedBefore ))"
}
rigPayWorld
rigSpawnIn ws-here keeper-here
rigAssert "nothing named: the console's own reads answer from the workspace we run from, and the record says it pays" "$rigRc $( rigPaid ) $( rigThree "$( rigRecordOf ws-here keeper-here )" )" "0 here/here/here/here ws-here/ws-here/ws-here 1/1/1"
rigAssert "and its start post names no paying workspace" "$( rigStartContext )" "where: <host> / ws-here · started: <date>"
rigPayWorld
rigSumThere="$( rigTreeSum ws-there )"
rigSpawnIn ws-here keeper-here --spawn-settings-workspace ws-there
rigAssert "one task (--spawn-settings-workspace): its CLI service, tier and credential are read from the workspace named, and a setting that is no spawn setting still from the one we run from" "$rigRc $( rigPaid )" "0 there/there/there/here"
rigAssert "the session is still started here, on this workspace's view, by this workspace's console" "$( rigLaunched ) $( LC_ALL=C sed -n 's/^owner: //p' "$( rigRecordOf ws-here keeper-here )" )" "HERE=ws-here keeper-here"
rigAssert "its record is kept here and says which workspace pays, and the CLI resolved there" "$( rigSpawnedCount ws-here ) $( rigSpawnedCount ws-there ) $( rigThree "$( rigRecordOf ws-here keeper-here )" ) $( LC_ALL=C sed -n 's/^cli: //p' "$( rigRecordOf ws-here keeper-here )" )" "1 0 ws-here/ws-there/ws-here 1/1/1 rig-cli-there"
rigAssert "its session thread and its tracking posts are this workspace's own Slack, by this team's bot" "$( LC_ALL=C awk '$1 == "chat.postMessage" { print $2 }' "$rigTmp/calls" | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' ' )$( rigChannel ) $( rigN "$rigTmp/calls" 'token-THERE' )" "rig-bot-token-HERE CHERE0001 0"
rigAssert "its start post says the paying workspace, after where it runs" "$( rigStartContext )" "where: <host> / ws-here · started: <date> · paying workspace: ws-there"
rigAssert "the workspace that pays is only read: nothing is written under its .local" "$( rigTreeSum ws-there )" "$rigSumThere"
rigSpawnIn ws-here keeper-there --spawn-settings-workspace ws-third
rigAssert "an invited member paid from a third workspace: three workspaces, three names" "$rigRc $( rigPaid ) $( rigThree "$( rigRecordOf ws-here keeper-there )" )" "0 third/third/third/here ws-here/ws-third/ws-there 1/1/1"
rigAssert "and its start post says both" "$( rigStartContext )" "where: <host> / ws-here · started: <date> · member's workspace: ws-there · paying workspace: ws-third"
rigPayWorld
rigScopeOf ws-here keeper-here 'WHERE=ws-here' 'SLACK_USER_TOKEN=rig-user-token-KHERE' 'SPAWN_SETTINGS_WORKSPACE=ws-third'
rigSpawnIn ws-here keeper-here
rigAssert "one member (SPAWN_SETTINGS_WORKSPACE in its own scope here): its spawns are paid from the workspace named" "$rigRc $( rigPaid ) $( rigThree "$( rigRecordOf ws-here keeper-here )" )" "0 third/third/third/here ws-here/ws-third/ws-here 1/1/1"
rigSpawnIn ws-here keeper-both
rigAssert "control: another member's spawn is not" "$rigRc $( rigPaid ) $( rigThree "$( rigRecordOf ws-here keeper-both )" )" "0 here/here/here/here ws-here/ws-here/ws-here 1/1/1"
rigSpawnIn ws-here keeper-here --spawn-settings-workspace ws-there
rigAssert "the task's own naming goes before the member's" "$rigRc $( rigPaid )" "0 there/there/there/here"
rigPayTeam ws-here ws-there
rigSpawnIn ws-here keeper-both
rigAssert "every spawn (SPAWN_SETTINGS_WORKSPACE in the magic-team scope here): a member with no naming of its own is paid from the workspace named" "$rigRc $( rigPaid ) $( rigThree "$( rigRecordOf ws-here keeper-both )" )" "0 there/there/there/here ws-here/ws-there/ws-here 1/1/1"
rigSpawnIn ws-here keeper-here
rigAssert "the member's own naming goes before the workspace's" "$rigRc $( rigPaid )" "0 third/third/third/here"
rigSpawnIn ws-here keeper-both --spawn-settings-workspace ws-here
rigAssert "and a task naming the workspace we run from is paid by it, whatever is named for every spawn" "$rigRc $( rigPaid ) $( rigStartContext )" "0 here/here/here/here where: <host> / ws-here · started: <date>"
rigRunIn ws-here --agents-config-option magic-team --select SPAWN_CLI_SERVICE
rigAssert "named for every spawn, any read of a spawn setting here follows, not a spawn's alone: the CLI service" "$rigRc $( cat "$rigTmp/out" )" "0 rig-cli-there"
rigRunIn ws-here --agents-config-option magic-team --select-default SPAWN_HARNESS_TIER rig-default
rigAssert "a read with a default follows too" "$rigRc $( cat "$rigTmp/out" )" "0 tier-there"
rigRunIn ws-here --agents-config-option magic-team --select SPAWN_SETTINGS_WORKSPACE
rigAssert "the naming itself is this workspace's own, and so is every setting that is no spawn setting: the team's bot token, a web prefix" "$( cat "$rigTmp/out" ) $( rigRunIn ws-here --agents-config-option magic-team --select SLACK_BOT_TOKEN ; cat "$rigTmp/out" ) $( rigRunIn ws-here --agents-config-option magic-team --select WEB_ALLOW_PREFIXES ; cat "$rigTmp/out" )" "ws-there rig-bot-token-HERE https://here.invalid/"
rigRunIn ws-here --agents-config-option keeper-here --select SPAWN_CLI_SERVICE
rigAssert "and a member's scope is never read from the workspace that pays" "$rigRc [$( cat "$rigTmp/out" )]" "0 []"
rigPayTeam ws-there ws-third
rigSpawnIn ws-here keeper-both
rigAssert "the workspace named is read itself, never the one it names in turn" "$rigRc $( rigPaid )" "0 there/there/there/here"
rigPayWorld
rigSpawnedBefore="$( rigSpawnedCount ws-here )"
rigSpawnIn ws-here keeper-here --spawn-settings-workspace ws-nowhere
rigAssert "a task naming a workspace this machine does not know: rc 1, nothing launched, no record, the name and where it was given said" "$( rigPayRefused ) $( rigN "$rigTmp/err" "⛔ ERROR: 'ws-nowhere' is named to pay for this spawn of keeper-here (--spawn-settings-workspace), and no workspace this machine knows has that name ($rigHome/.agents/magic-team) -- nothing was started." )" "1 [] 0 1"
rigSpawnIn ws-here keeper-here --spawn-settings-workspace "$rigWork/ws-there"
rigAssert "a path is no name: refused the same way" "$( rigPayRefused ) $( rigN "$rigTmp/err" "that is no workspace name, which is the last segment of its path -- nothing was started." )" "1 [] 0 1"
rigSpawnIn ws-here keeper-here --spawn-settings-workspace ws-gone
rigAssert "a known workspace that is not on this machine: refused, its path said" "$( rigPayRefused ) $( rigN "$rigTmp/err" "the workspace of that name is not present on this machine ($rigWork/gone/ws-gone) -- nothing was started." )" "1 [] 0 1"
mkdir -p "$rigWork/decoy/ws-third" ; rigListAdd "$rigWork/decoy/ws-third"
rigSpawnIn ws-here keeper-here --spawn-settings-workspace ws-third
rigAssert "a name two known workspaces have: refused, both said" "$( rigPayRefused ) $( rigN "$rigTmp/err" "several workspaces this machine knows have that name ($rigWork/ws-third, $rigWork/decoy/ws-third) -- nothing was started." )" "1 [] 0 1"
rigSpawnIn ws-here keeper-here --spawn-settings-workspace ws-there
rigAssert "accepted sibling: a name one known workspace has, on this machine, is paid from" "$rigRc $( rigPaid )" "0 there/there/there/here"
rigScopeOf ws-here keeper-both 'WHERE=ws-here' 'SPAWN_SETTINGS_WORKSPACE=ws-nowhere'
rigSpawnedBefore="$( rigSpawnedCount ws-here )"
rigSpawnIn ws-here keeper-both
rigAssert "a member's own naming of an unknown workspace: refused, the member's scope said" "$( rigPayRefused ) $( rigN "$rigTmp/err" "'ws-nowhere' is named to pay for this spawn of keeper-both (SPAWN_SETTINGS_WORKSPACE in the keeper-both scope), and no workspace this machine knows has that name" )" "1 [] 0 1"
rigPayTeam ws-here ws-nowhere
rigSpawnIn ws-here keeper-multi
rigAssert "the workspace's own naming of an unknown workspace: refused, the magic-team scope said, and never paid here in silence" "$( rigPayRefused ) $( rigN "$rigTmp/err" "⛔ ERROR: DistroAgentsTools: 'ws-nowhere' is named to pay for every spawn of $rigWork/ws-here (SPAWN_SETTINGS_WORKSPACE in its magic-team scope), and no workspace this machine knows has that name" ) $( rigN "$rigTmp/err" "the workspace that pays for this spawn of keeper-multi could not be settled -- nothing was started" )" "1 [] 0 1 1"
rigRunIn ws-here --agents-config-option magic-team --select SPAWN_CLI_SERVICE
rigAssert "and a plain read of a spawn setting fails by the same message rather than answer this workspace's" "$rigRc [$( cat "$rigTmp/out" )] $( rigN "$rigTmp/err" "'ws-nowhere' is named to pay for every spawn of $rigWork/ws-here" )" "1 [] 1"
rigSpawnIn ws-here keeper-multi --spawn-settings-workspace ws-there
rigAssert "accepted sibling: a task that names a known workspace is paid from it, the workspace's own naming not looked at" "$rigRc $( rigPaid )" "0 there/there/there/here"
rigPayTeamOff ws-here
## A spawn made from inside a session that is itself paid from elsewhere: what that session's spawn settled is in its
## environment, and is never taken over.
rigRc=0
( cd "$rigWork/ws-here" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/ws-here" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" MDAT_SPAWN_SETTINGS_WORKSPACE="$rigWork/ws-third" \
	bash "$rigTool" --intern-op-agent-spawn-proxy keeper-multi --dispatch-doc:none --wait --context rig-ws-invited ) > "$rigTmp/out" 2> "$rigTmp/err" <<< "RIG-TASK-TEXT" || rigRc=$?
rigAssert "a spawn made from a session paid from elsewhere settles its own: nothing named for it, so this workspace pays" "$rigRc $( rigPaid )" "0 here/here/here/here"
## The handback retry: resumed with what the launch was started with, the workspace that pays included.
rigPayWorld
rm -f "$rigTmp"/paid.*
rigRc=0
( cd "$rigWork/ws-here" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/ws-here" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_HANDBACK=resume-only \
	bash "$rigTool" --intern-op-agent-spawn-proxy keeper-here --spawn-settings-workspace ws-there --dispatch-doc:none --context rig-ws-invited ) > "$rigTmp/out" 2> "$rigTmp/err" <<< "RIG-TASK-TEXT" || rigRc=$?
rigRetryLeft=30
while [ ! -s "$rigTmp/paid.HERE.true" ] && [ "$rigRetryLeft" -gt 0 ] ; do sleep 1 ; rigRetryLeft=$(( rigRetryLeft - 1 )) ; done
rigAssert "a launch with no handback is retried once, paid from the same workspace as the launch" "$rigRc $( rigPaid launch ) $( rigPaid true )" "0 there/there/there/here there/there/there/here"
sleep 3
rm -f "$rigTmp"/paid.*
rigConsole ws-here HERE

echo "-- 10. --spawn-session, a read of the team data and the root harness --"
rigSessionIn(){ ## workspace, args... -- --spawn-session from that workspace
	: > "$rigTmp/calls" ; : > "$rigTmp/envs" ; : > "$rigTmp/bodies" ; rm -f "$rigTmp"/launched.* "$rigTmp"/roots.* "$rigTmp"/brief.*
	rigRc=0
	( cd "$rigWork/$1" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/$1" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" \
		bash "$rigTool" --spawn-session "${@:2}" ) > "$rigTmp/out" 2> "$rigTmp/err" <<< "RIG-TASK-TEXT" || rigRc=$?
}
rigWorld
rigSessionIn ws-here --routine-default keeper-there ; rigSettle HERE
rigAssert "a session for an invited member is launched in the workspace it was called from, on the member's own workspace view" "$rigRc $( rigLaunched ) $( rigRoots HERE )" "0 HERE=ws-here keeper-there=ws-there/.local/agents/members"
rigSpawnedBefore="$( rigSpawnedCount ws-here )"
rigSessionIn ws-here --routine-default keeper-there keeper-here ; rigSettle HERE ; rigSettleCount HERE 2
rigAssert "two members, one invited and one set up here: both launched here, each on the view of the workspace it is set up in" "$rigRc $( rigLaunched ) $( rigRoots HERE )" "0 HERE=ws-here keeper-here=ws-here/.local/agents/members keeper-there=ws-there/.local/agents/members"
rigAssert "and the records of both are the calling workspace's, none in the other"          "$(( $( rigSpawnedCount ws-here ) - rigSpawnedBefore )) $( rigSpawnedCount ws-there )" "2 0"
rigSessionIn ws-here --routine-default keeper-nowhere
rigAssert "a member whose directory is nowhere on this machine is no team member here: refused by name, nothing launched"  "$rigRc [$( rigLaunched )] $( rigN "$rigTmp/err" "spawn-session: ⛔ ERROR: no such team member: keeper-nowhere" )" "1 [] 1"
mkdir -p "$rigWork/ws-nolist" ; rigMemberAt ws-nolist magic-team ; rigMemberAt ws-nolist keeper-nowhere
rigSessionIn ws-here --routine-default keeper-nowhere
rigAssert "(a) set up in a workspace that is not tracked: refused by the resolver's message, nothing launched"  "$rigRc [$( rigLaunched )] $(( $( rigN "$rigTmp/out" "present in no tracked workspace -- nothing was done" ) + $( rigN "$rigTmp/err" "present in no tracked workspace -- nothing was done" ) ))" "1 [] 1"
rigListAdd "$rigWork/ws-nolist"
rigSessionIn ws-here --routine-default keeper-nowhere ; rigSettle HERE
rigAssert "(a) accepted sibling: once that workspace is tracked, the same member is launched here, on that workspace's view" "$rigRc $( rigLaunched ) $( rigRoots HERE )" "0 HERE=ws-here keeper-nowhere=ws-nolist/.local/agents/members"
rigSessionIn ws-here --routine-default keeper-here ; rigSettle HERE
rigAssert "control: a member set up here is launched here"                 "$rigRc $( rigLaunched ) $( rigRoots HERE )" "0 HERE=ws-here keeper-here=ws-here/.local/agents/members"
## A note of the team data of each workspace, in the inbox of each member that is read from it, saying whose workspace it is.
for rigW in there here ; do
	for rigM in keeper-there keeper-here keeper-pre ; do
		mkdir -p "$rigWork/ws-$rigW/.local/agents/team-data-root/inboxes/$rigM/incoming"
		printf -- '---\nstate: working\nsession-id: RIG-%s-SESSION\n---\nbody\n' "$rigW" > "$rigWork/ws-$rigW/.local/agents/team-data-root/inboxes/$rigM/incoming/note-20260809T155000Z-rig-read.md"
	done
done
rigNoteOwner(){ ## -- whose workspace the note read last is: the RIG-<w>-SESSION it holds
	LC_ALL=C grep -o -m1 'RIG-[a-z]*-SESSION' "$rigTmp/out" "$rigTmp/err" | LC_ALL=C sed 's/^.*://'
}
rigRunIn ws-here --get-inbox-item keeper-there note-20260809T155000Z-rig-read.md
rigAssert "a read of the team data naming an invited member reads the team data of the workspace it was called from, not the member's" "$( rigNoteOwner )" "RIG-here-SESSION"
rigRunIn ws-here --get-inbox-item keeper-here note-20260809T155000Z-rig-read.md
rigAssert "control: for a member set up here it reads the same, this workspace's own"     "$( rigNoteOwner )" "RIG-here-SESSION"
rigRunIn ws-there --get-inbox-item keeper-there note-20260809T155000Z-rig-read.md
rigAssert "control: called from the member's own workspace it reads that one's"     "$( rigNoteOwner )" "RIG-there-SESSION"
rigRunIn ws-here --get-inbox-item keeper-pre note-20260809T155000Z-rig-read.md
rigAssert "(a) a read of the team data names the same refusal"     "$rigRc $( rigN "$rigTmp/err" "member 'keeper-pre' is in the team members index but is present in no tracked workspace -- nothing was done" )" "1 1"
rigRootIn(){ ## workspace, args... -- --intern-root-harness from that workspace
	: > "$rigTmp/calls" ; : > "$rigTmp/envs" ; : > "$rigTmp/bodies" ; rm -f "$rigTmp"/launched.* "$rigTmp"/roots.* "$rigTmp"/brief.*
	rigRc=0
	( cd "$rigWork/$1" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/$1" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" \
		bash "$rigTool" --intern-root-harness "${@:2}" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator\nrequires-session-kind: standalone\n---\n# rig advance routine fixture\n' > "$( rigMemberHome ws-here magic-coordinator )/magic-coordinator.advance.routine.md"
rigRootIn ws-here --routine advance --non-interactive --wait ; rigSettle HERE
rigAssert "the root harness, whose caller is the coordinator set up in the current workspace: launched there" "$rigRc $( rigLaunched ) $( rigRoots HERE )" "0 HERE=ws-here magic-coordinator=ws-here/.local/agents/members"
rigSpawnedBefore="$( rigSpawnedCount ws-there )" ; rigBoardBeforeThere="$( rigBoardItems ws-there )" ; rigBoardBeforeHere="$( rigBoardItems ws-here )"
rigRootIn ws-there --routine advance --non-interactive --wait ; rigSettle THERE
rigAssert "the same from a workspace the coordinator is not set up in: it is invited, its session launched in the workspace it was asked from, on the coordinator's own workspace view" "$rigRc $( rigLaunched ) $( rigRoots THERE )" "0 THERE=ws-there magic-coordinator=ws-here/.local/agents/members"
rigAssert "and the record stays in the workspace it was asked from"        "$(( $( rigSpawnedCount ws-there ) - rigSpawnedBefore ))" "1"
rigAssert "and the dispatch item and board stay in the workspace it was asked from" "$(( $( rigBoardItems ws-there ) - rigBoardBeforeThere )) $(( $( rigBoardItems ws-here ) - rigBoardBeforeHere ))" "1 0"
rigLoopIn(){ ## workspace -- --intern-main-loop --one from that workspace
	: > "$rigTmp/calls" ; : > "$rigTmp/envs" ; : > "$rigTmp/bodies" ; rm -f "$rigTmp"/launched.* "$rigTmp"/roots.* "$rigTmp"/brief.*
	rigRc=0
	( cd "$rigWork/$1" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/$1" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" \
		bash "$rigTool" --intern-main-loop --one ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigWorld
printf 'SPAWN_CLI_SERVICE=rig-cli\n' >> "$rigWork/ws-there/.local/.agents/magic-team.agent.env" ; printf 'SPAWN_CLI_SERVICE=rig-cli\n' >> "$rigWork/ws-here/.local/.agents/magic-team.agent.env"
rigLoopIn ws-here ; rigSettle HERE
rigAssert "the main loop in the coordinator's own workspace: the iteration passes and launches no session of its own (the schedule starts what is declared)"  "$rigRc [$( rigLaunched )]" "0 []"
rigLoopIn ws-there ; rigSettle THERE
rigAssert "the main loop in a workspace the coordinator is not set up in: the same, the iteration passes and launches no session of its own" "$rigRc [$( rigLaunched )]" "0 []"

echo "-- 11. the harness tools that name a member --"
rigToolIn(){ ## workspace the session runs in, the member set root the session was given, agent, tool, json -- one harness tool call as that agent; output in out
	: > "$rigTmp/calls" ; : > "$rigTmp/envs" ; : > "$rigTmp/bodies" ; rm -f "$rigTmp"/launched.* "$rigTmp"/roots.* "$rigTmp"/brief.*
	rigRc=0
	( cd "$rigWork/$1" && printf '%s' "$5" | env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/$1" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$2" RIG_SCENARIO="$rigTmp" \
		MDAT_SPAWN_SESSION_ID=rig-session-a MDAT_SPAWN_AGENT="$3" MDAT_HARNESS_WAIT_TIMEOUT=1 bash "$rigHarness" --intern-tool "$4" ) > "$rigTmp/out" 2> "$rigTmp/err" || rigRc=$?
}
rigSettle
rigWorld
## An invited member's session, as the spawn starts it: it runs in the workspace it was called from, on the member
## set root of the workspace the member is set up in. Its own identity, a Slack setting the workspace it runs in
## holds none of for it, is read from the workspace it is set up in; the conversations are the calling workspace's.
rigToolIn ws-here "$( rigView ws-there )" keeper-there SendMessage '{"to":"magic-team","message":"RIG-BODY"}'
rigAssert "SendMessage as an invited member: its own identity, in the team's channel of the workspace its session runs in, and run there" "$( rigTokens )$( rigChannel ) $( rigEnvOf chat.postMessage MMDAPP | LC_ALL=C sed "s|$rigWork/||" )" 'rig-user-token-KTHERE CHERE0001 ws-here'
rigToolIn ws-here "$( rigView ws-third )" keeper-multi SendMessage '{"to":"magic-team","message":"RIG-BODY"}'
rigAssert "SendMessage as an invited member with no identity of its own in either workspace: the team bot and channel of the workspace its session runs in" "$( rigTokens )$( rigChannel ) $( rigEnvOf chat.postMessage MMDAPP | LC_ALL=C sed "s|$rigWork/||" )" 'rig-bot-token-HERE CHERE0001 ws-here'
rigToolIn ws-here "$( rigView ws-here )" keeper-here SendMessage '{"to":"magic-team","message":"RIG-BODY"}'
rigAssert "control: SendMessage as a member set up in the current workspace: its own token and channel" "$( rigTokens )$( rigChannel )" 'rig-user-token-KHERE CHERE0001'
rigToolIn ws-here "$( rigView ws-there )" keeper-there Wait '{"sources":"slack:magic-team","timeout":0}'
rigAssert "Wait as an invited member: the long poll ran under its own identity, and under the root of the workspace its session runs in" "$( LC_ALL=C awk '$1 ~ /^conversations/ { print $2 ; exit }' "$rigTmp/calls" ) $( rigEnvOf conversations.history MMDAPP | LC_ALL=C sed "s|$rigWork/||" )" 'rig-user-token-KTHERE ws-here'
rigToolIn ws-here "$( rigView ws-here )" keeper-here Wait '{"sources":"slack:magic-team","timeout":0}'
rigAssert "control: Wait as a member set up in the current workspace"     "$( LC_ALL=C awk '$1 ~ /^conversations/ { print $2 ; exit }' "$rigTmp/calls" ) $( rigEnvOf conversations.history MMDAPP | LC_ALL=C sed "s|$rigWork/||" )" 'rig-user-token-KHERE ws-here'
## Every ask to the human-owner is the team bot's post in the bot's conversation with him, whoever asks: an invited
## member's own account, read from the workspace it is set up in, posts none of it. The bot is that of the workspace
## its session runs in, and so is the human-owner; nothing of the team of the workspace it is set up in is used.
rigToolIn ws-here "$( rigView ws-there )" keeper-there AskUserQuestion '{"to":"human-owner","question":"May the rig keep its file?","wait":false}'
rigAssert "AskUserQuestion as an invited member that has an account of its own: every post goes to the human-owner of the workspace its session runs in, under the team bot of that workspace and none under its own account, and nothing of its own workspace's team is used" "$( rigTokens | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -v '^$' | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' ' )$( rigChannel ) $( rigN "$rigTmp/calls" 'bot-token-THERE' )" 'rig-bot-token-HERE UHEREOWNER 0'
rigToolIn ws-here "$( rigView ws-third )" keeper-multi AskUserQuestion '{"to":"human-owner","question":"May the rig keep its other file?","wait":false}'
rigAssert "AskUserQuestion as an invited member with no account of its own in either workspace: the same, every post goes to that human-owner under the team bot of the workspace its session runs in" "$( rigTokens | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -v '^$' | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' ' )$( rigChannel ) $( rigN "$rigTmp/calls" 'THERE' )" 'rig-bot-token-HERE UHEREOWNER 0'
rigToolIn ws-here "$( rigView ws-there )" keeper-there AskQuestion '{"to":"magic-team","address_to":"UHEREOWNER","question":"May the rig go on?","wait":false}'
rigAssert "AskQuestion as an invited member is posted in that workspace's own conversation, under its own identity"  "$( LC_ALL=C sed -n '1p' "$rigTmp/out" ) $( rigTokens )$( rigChannel )" "ASK-RESULT: POSTED rig-user-token-KTHERE CHERE0001"
rigToolIn ws-here "$( rigView ws-there )" client-ndm SendMessage '{"to":"magic-team","message":"RIG-BODY"}'
rigAssert "SendMessage as a client set up in another workspace: a tool with no marker reaches our own team, the bot and channel of the workspace its session runs in"  "$( rigTokens )$( rigChannel ) $( rigN "$rigTmp/calls" 'NDM' )" 'rig-bot-token-HERE CHERE0001 0'
rigToolIn ws-here "$( rigView ws-there )" client-ndm Wait '{"sources":"slack:magic-team","timeout":0}'
rigAssert "Wait as a client set up in another workspace: the long poll ran under the token and the root of the workspace its session runs in" "$( LC_ALL=C awk '$1 ~ /^conversations/ { print $2 ; exit }' "$rigTmp/calls" ) $( rigEnvOf conversations.history MMDAPP | LC_ALL=C sed "s|$rigWork/||" )" 'rig-bot-token-HERE ws-here'
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
rigAssert "(a) accepted sibling: tracked, present and set up there, the same call posts, in the team's channel of the workspace its session runs in, run there, under its own identity as the workspace it is set up in holds it, and nothing of that workspace's team is used" "$( rigTokens )$( rigChannel ) $( rigEnvOf chat.postMessage MMDAPP | LC_ALL=C sed "s|$rigWork/||" ) $( rigN "$rigTmp/calls" 'NOLIST' )" 'rig-user-token-KNOWHERE CHERE0001 ws-here 0'
rigWorld

echo "-- 11b. a task's own spawn settings reach every way a task is spawned: the Agent tool, --spawn-session, a review return's restart --"
## The workspace named to pay for one task, and the CLI service named for it, are given where the task is spawned,
## whichever way that is, and a restart reads both off the record of the run it replaces. ws-third's configured
## service is a native client here, so a brief built for a spawn it pays for reads differently from one built for ours.
rigArgs(){ ## [start] -- what the console was started with at that start (launch, or true for the handback retry)
	cat "$rigTmp/args.HERE.${1:-launch}" 2> /dev/null
}
rigAsked(){ ## record -- the workspace that paid for it and the service it was started on by name: paying/asked, - for none
	LC_ALL=C awk -F': ' '$1 == "paying-workspace" { p = $2 } $1 == "cli-asked" { a = $2 } END { printf "%s/%s", ( p == "" ? "-" : p ), ( a == "" ? "-" : a ) }' "$1" 2> /dev/null
}
rigBriefReader(){ ## file -- which harness a brief in it was built for, by its skillset-reader line: own, native, both or none
	local readerOwn readerNative
	readerOwn="$( LC_ALL=C grep -c '^skillset-reader: Skill ' "$1" 2> /dev/null || : )" ; readerNative="$( LC_ALL=C grep -c '^skillset-reader: mcp__myx_distro__Skill ' "$1" 2> /dev/null || : )"
	case "${readerOwn:-0}:${readerNative:-0}" in 1:0) printf own ;; 0:1) printf native ;; 0:0) printf none ;; *) printf both ;; esac
}
rigPayClear(){ ## -- what the console left of its last starts
	rm -f "$rigTmp"/paid.* "$rigTmp"/args.* "$rigTmp"/launched.* "$rigTmp"/roots.* "$rigTmp"/brief.*
}
rigPayWorld
printf 'SPAWN_CLI_SERVICE=rig-cli-third-native\n' >> "$rigWork/ws-third/.local/.agents/magic-team.agent.env"
rigAssert "the Agent tool declares the field beside cli_service, once, on the wire, and so in its MCP mirror, which is made from that declaration" "$( LC_ALL=C grep -o '"cli_service":{[^}]*},"settings_workspace":{"type":"string"' "$rigHere/harness/AgentsOpenAiChatWire.sh" | LC_ALL=C grep -c . || : ) $( MDLT_ORIGIN="$MDLT_ORIGIN" bash "$rigHere/harness/AgentsHarnessMcpMirror.sh" 2> /dev/null | LC_ALL=C grep -o '"settings_workspace":{"type":"string"' | LC_ALL=C grep -c . || : )" "1 1"
rigPayClear
rigToolIn ws-here "$( rigView ws-here )" keeper-here Agent '{"agent":"keeper-both","prompt":"RIG-TASK-TEXT","settings_workspace":"ws-there","cli_service":"rig-service"}' ; rigSettle HERE
rigAssert "the Agent tool, settings_workspace and cli_service: the helper is started with the spawn settings of the workspace named, on the service named" "$( rigPaid ) [$( rigArgs )]" "there/there/there/here [--cli rig-service --non-interactive]"
rigAssert "and its record says which workspace pays and which service it was started on by name" "$( rigAsked "$( rigRecordOf ws-here keeper-both )" ) $( rigThree "$( rigRecordOf ws-here keeper-both )" )" "ws-there/rig-service ws-here/ws-there/ws-here 1/1/1"
rigPayClear
rigToolIn ws-here "$( rigView ws-here )" keeper-here Agent '{"agent":"keeper-both","prompt":"RIG-TASK-TEXT","settings_workspace":"ws-third"}' ; rigSettle HERE
rigAssert "settings_workspace alone: the service is the one configured in the workspace named, and the brief the tool puts ahead of the prompt is built for that service, a native client" "$( rigPaid ) [$( rigArgs )] $( rigBriefReader "$rigTmp/brief.HERE" ) $( rigAsked "$( rigRecordOf ws-here keeper-both )" )" "third-native/third/third/here [--cli-configured --non-interactive] native ws-third/-"
rigPayClear
rigToolIn ws-here "$( rigView ws-here )" keeper-here Agent '{"agent":"keeper-both","prompt":"RIG-TASK-TEXT"}' ; rigSettle HERE
rigAssert "control: with neither, the helper is started with this workspace's own, and its brief is built for ours" "$( rigPaid ) [$( rigArgs )] $( rigBriefReader "$rigTmp/brief.HERE" ) $( rigAsked "$( rigRecordOf ws-here keeper-both )" )" "here/here/here/here [--cli-configured --non-interactive] own ws-here/-"
rigPayClear ; rigSpawnedBefore="$( rigSpawnedCount ws-here )"
rigToolIn ws-here "$( rigView ws-here )" keeper-here Agent '{"agent":"keeper-both","prompt":"RIG-TASK-TEXT","settings_workspace":"../ws-there"}'
rigAssert "a settings_workspace that is no bare name is refused by the tool: nothing spawned, the field named" "$( rigN "$rigTmp/out" 'ERROR: settings_workspace must be the bare name of a workspace, the last segment of its path, got: ../ws-there. Nothing was spawned.' ) [$( rigLaunched )] $(( $( rigSpawnedCount ws-here ) - rigSpawnedBefore ))" "1 [] 0"
rigToolIn ws-here "$( rigView ws-here )" keeper-here Agent '{"agent":"keeper-both","prompt":"RIG-TASK-TEXT","settings_workspace":"ws-nowhere"}'
rigAssert "one this machine does not know is refused by the spawn, and the tool says no helper is running and why" "$( rigN "$rigTmp/out" 'ERROR: the spawn failed (rc=1) and NO helper session is running.' ) $( rigN "$rigTmp/out" "'ws-nowhere' is named to pay for this spawn of keeper-both (--spawn-settings-workspace), and no workspace this machine knows has that name" ) [$( rigLaunched )]" "1 1 []"
rigRunIn ws-here --intern-op-spawn-prepare-brief keeper-here --routine-default --settings-workspace ws-third --context rig-ws-invited
rigAssert "the brief on its own: built for the service of the workspace named for the one spawn it is for" "$rigRc $( rigBriefReader "$rigTmp/out" )" "0 native"
rigRunIn ws-here --intern-op-spawn-prepare-brief keeper-here --routine-default --context rig-ws-invited
rigAssert "control: with none named, for this workspace's own" "$rigRc $( rigBriefReader "$rigTmp/out" )" "0 own"
rigPre=( "MDAT_SPAWN_SETTINGS_WORKSPACE=$rigWork/ws-third" )
rigRunIn ws-here --intern-op-spawn-prepare-brief keeper-here --routine-default --context rig-ws-invited
rigAssert "and never for what the calling session's own spawn settled: a brief asked for from a session paid from elsewhere is built for the spawn it is for" "$rigRc $( rigBriefReader "$rigTmp/out" )" "0 own"
rigPre=()
rigScopeOf ws-here keeper-multi 'WHERE=ws-here' 'SPAWN_SETTINGS_WORKSPACE=ws-third'
rigRunIn ws-here --intern-op-spawn-prepare-brief keeper-multi --routine-default --context rig-ws-invited
rigAssert "the member's own naming is followed by its brief as by its spawn" "$rigRc $( rigBriefReader "$rigTmp/out" )" "0 native"
rigRunIn ws-here --intern-op-spawn-prepare-brief keeper-here --routine-default --settings-workspace ws-nowhere --context rig-ws-invited
rigAssert "a name this machine does not know refuses the brief, by the spawn's own message" "$rigRc $( rigLines "$rigTmp/out" ) $( rigN "$rigTmp/err" "spawn-prepare-brief: ⛔ ERROR: 'ws-nowhere' is named to pay for this spawn of keeper-here (--spawn-settings-workspace), and no workspace this machine knows has that name" )" "1 0 1"
rm -f "$rigWork/ws-here/.local/.agents/keeper-multi.agent.env"
rigPayClear
rigSessionIn ws-here --routine-default --spawn-settings-workspace ws-there --spawn-cli-service rig-service keeper-both keeper-here ; rigSettle HERE ; rigSettleCount HERE 2
sleep 3
rigAssert "--spawn-session gives both to every spawn of its call: each of its two members is started with the settings of the workspace named, on the service named" "$rigRc $( rigPaid ) [$( rigArgs )] $( rigRoots HERE | LC_ALL=C tr ' ' '\n' | LC_ALL=C sed 's/=.*//' | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' )" "0 there/there/there/here [--cli rig-service --non-interactive] keeper-both keeper-here"
rigAssert "and both records say so" "$( rigAsked "$( rigRecordOf ws-here keeper-both )" ) $( rigAsked "$( rigRecordOf ws-here keeper-here )" )" "ws-there/rig-service ws-there/rig-service"
rigPayClear ; rigSpawnedBefore="$( rigSpawnedCount ws-here )"
rigSessionIn ws-here --routine-default --spawn-settings-workspace ws-nowhere keeper-both
rigAssert "a workspace this machine does not know stops the call at its first spawn: rc 1, nothing launched, no record" "$rigRc [$( rigLaunched )] $(( $( rigSpawnedCount ws-here ) - rigSpawnedBefore )) $(( $( rigN "$rigTmp/out" "'ws-nowhere' is named to pay for this spawn of keeper-both (--spawn-settings-workspace)" ) + $( rigN "$rigTmp/err" "'ws-nowhere' is named to pay for this spawn of keeper-both (--spawn-settings-workspace)" ) ))" "1 [] 0 1"
rigSessionIn ws-here --routine-default --spawn-cli-service
rigAssert "an option given no value is refused by name, before any spawn" "$rigRc [$( rigLaunched )] $( rigN "$rigTmp/err" 'spawn-session: ⛔ ERROR: --spawn-cli-service requires <cli-name>' )" "1 [] 1"
## A review return to an ended session: the run that replaces it is given nothing; it reads what the first was started with.
rigPayWorld
rigReturnItem(){ ## item stem -- that task on ws-here's board, running
	mkdir -p "$rigWork/ws-here/.local/agents/team-data-root/board/running"
	printf -- '---\ntype: task\n---\n\nRIG-RETURN-ITEM-TEXT\n' > "$rigWork/ws-here/.local/agents/team-data-root/board/running/$1.md"
}
rigReturn(){ ## item stem -- the coordinator returns that item for corrections; the restart it makes is waited for
	rigPayClear
	rigRunIn ws-here --return-review magic-coordinator "$1" --message "RIG-CORRECTIONS"
	rigSettle HERE
}
rigReturnItem task-rig-paid
rigSpawnDocIn ws-here keeper-here --from-board task-rig-paid.md --board-state running --dispatch-doc:reuse --spawn-settings-workspace ws-there --spawn-cli-service rig-service
rigFirstRecord="$( rigRecordOf ws-here keeper-here )"
rigAssert "control: a task spawned with both of its own ends in review, its record saying which workspace paid and which service it was started on by name" "$rigRc $( rigAsked "$rigFirstRecord" ) $( [ -f "$rigWork/ws-here/.local/agents/team-data-root/board/review/task-rig-paid.md" ] && printf in-review || printf elsewhere )" "0 ws-there/rig-service in-review"
rigReturn task-rig-paid
rigAssert "returned, its ended session is started again, and the return is given neither" "$rigRc $( LC_ALL=C grep -c '^RETURN: restarted keeper-here on task-rig-paid, ' "$rigTmp/out" || : )" "0 1"
rigAssert "the run that replaces it is paid from the same workspace and started on the same service, both read off the record of the run it replaces" "$( rigPaid ) [$( rigArgs )]" "there/there/there/here [--cli rig-service --non-interactive]"
rigSecondRecord="$( rigRecordOf ws-here keeper-here )"
rigAssert "and its own record says the same, so a second return reads them again" "$( [ "$rigSecondRecord" != "$rigFirstRecord" ] && printf a-new-record || printf the-same-record ) $( rigAsked "$rigSecondRecord" )" "a-new-record ws-there/rig-service"
rigReturnItem task-rig-here
rigSpawnDocIn ws-here keeper-both --from-board task-rig-here.md --board-state running --dispatch-doc:reuse
rigAssert "control: a task spawned with neither is paid by this workspace, on its configured service, and its record names no service" "$rigRc $( rigAsked "$( rigRecordOf ws-here keeper-both )" )" "0 ws-here/-"
rigPayTeam ws-here ws-third
rigReturn task-rig-here
rigAssert "its restart is paid from the workspace that paid for it, this one, whatever has been named to pay for every spawn since, and on the service configured there now" "$rigRc $( rigPaid ) [$( rigArgs )] $( rigAsked "$( rigRecordOf ws-here keeper-both )" )" "0 here/here/here/here [--cli-configured --non-interactive] ws-here/-"
rigPayTeamOff ws-here
rigReturnItem task-rig-gone
rigSpawnDocIn ws-here keeper-multi --from-board task-rig-gone.md --board-state running --dispatch-doc:reuse --spawn-settings-workspace ws-there
LC_ALL=C sed 's/^paying-workspace: ws-there$/paying-workspace: ws-nowhere/' "$( rigRecordOf ws-here keeper-multi )" > "$rigTmp/record.gone" && cat "$rigTmp/record.gone" > "$( rigRecordOf ws-here keeper-multi )"
rigSpawnedBefore="$( rigSpawnedCount ws-here )"
rigPayClear
rigRunIn ws-here --return-review magic-coordinator task-rig-gone --message "RIG-CORRECTIONS"
rigAssert "a record naming a workspace this machine no longer knows: the session is not restarted, said with the spawn's own reason, and nothing is started on another workspace's settings in its place" "$rigRc [$( rigLaunched )] $(( $( rigSpawnedCount ws-here ) - rigSpawnedBefore )) $( LC_ALL=C grep -c "^RETURN: not restarted: the spawn of keeper-multi for task-rig-gone failed (rc 1): .*'ws-nowhere' is named to pay for this spawn of keeper-multi (--spawn-settings-workspace), and no workspace this machine knows has that name" "$rigTmp/out" || : )" "1 [] 0 1"
sleep 3
rigPayClear
rigConsole ws-here HERE

echo "-- 12. static: where a member's workspace is looked up, and not --"
rigDispatchEntry="$( LC_ALL=C awk '/^DistroAgentsTools\(\)\{/ { on = 1 } on { print } on && /^\t\. "\$MDLT_ORIGIN\/myx\/myx.distro-agents\/sh-lib\/harness\/AgentsContext.UseAgentsTools.include"/ { exit }' "$rigTool" )"
rigAssert "control: the dispatcher's entry was cut out, up to the context include"  "$( printf '%s\n' "$rigDispatchEntry" | LC_ALL=C grep -c 'AgentsContext.UseAgentsTools.include' || : )" 1
rigAssert "the entry brings once, before the context include, for every member alike: it resolves no workspace itself and has no arm of its own for a client-* member" "$( printf '%s\n' "$rigDispatchEntry" | LC_ALL=C grep -c "$rigBringFn \"\$2\" \"\$1\"" || : ) $( printf '%s\n' "$rigDispatchEntry" | LC_ALL=C grep -c "$rigResolveFn \"" || : ) $( printf '%s\n' "$rigDispatchEntry" | LC_ALL=C grep -c -F -e 'client-*)' || : )" "1 0 0"
rigExclusion="$( printf '%s\n' "$rigDispatchEntry" | LC_ALL=C grep -F -e '|*:|*:-*) ;;' | LC_ALL=C sed -e 's/^[[:space:]]*//' -e 's/) ;;$//' )"
## The Decisions append and the review implementations are the tooling's own: their <who> is the name recorded, not
## the member whose workspace the item lives in, and they run where their caller's records are. The place ops' second
## word is a place name or a path, and the namespace listing's a namespace, never a member.
rigAssert "the entry's one exclusion line: the spawn proxy, the routine lock operations, the markdown merge, the MCP execute, the Decisions append, the review implementations, the directory and workspace ops, the make operations, the manager's own operations, an empty second word, an option" "$rigExclusion" '--intern-op-agent-spawn-proxy:*|--intern-op-routine-lock-*:*|--intern-merge-md-files:*|--intern-mcp-execute:*|--intern-op-decisions-append:*|--intern-op-review-*:*|--intern-directory-*:*|--owner-workspace-*:*|--make-*:*|--manager-*:*|*:|*:-*'
rigAssert "control: a sample entry without the wrapping operations is told apart" "$( printf -- '--intern-op-agent-spawn-proxy:*|--intern-mcp-execute:*|*:|*:-*\n' )" "$( printf '%s' "$rigExclusion" | LC_ALL=C sed 's/--intern-op-routine-lock-[*]:[*]|//; s/--intern-merge-md-files:[*]|//; s/--intern-op-decisions-append:[*]|//; s/--intern-op-review-[*]:[*]|//; s/--intern-directory-[*]:[*]|--owner-workspace-[*]:[*]|--make-[*]:[*]|--manager-[*]:[*]|//' )"
rigAssert "an invited member's call is re-run whole in a subshell under its member set root, and only where that is not the root it already reads" "$( printf '%s\n' "$rigDispatchEntry" | LC_ALL=C grep -c -F -e '( export MDAT_SKILLSET_ROOT="$memberBrought" ; DistroAgentsTools "$@" )' || : ) $( printf '%s\n' "$rigDispatchEntry" | LC_ALL=C grep -c -F -e '[ "$memberBrought" != "${MDAT_SKILLSET_ROOT:-}" ]' || : )" "1 1"
rigAssert "no call is carried to another workspace: the entry switches to none"  "$( printf '%s\n' "$rigDispatchEntry" | LC_ALL=C grep -c "$rigSwitchFn " || : )" 0
rigAssert "the resolver is called in its own file and nowhere else: by the bring, and beside it by what answers whether a member is invited, which workspace it is set up in, and where its own settings are read from" "$( LC_ALL=C grep -l "$rigResolveFn \"" "$rigHere"/*/*.include "$rigHere"/*/*.sh "$rigPackage/sh-scripts"/*.sh 2> /dev/null | LC_ALL=C sed 's|.*/||' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "AgentsTools.MemberWorkspace.include "
rigAssert "the bring is called from the dispatcher entry, the door of the tool files and the spawn proxy, and nowhere else" "$( LC_ALL=C grep -l "$rigBringFn \"" "$rigHere"/*/*.include "$rigHere"/*/*.sh "$rigPackage/sh-scripts"/*.sh 2> /dev/null | LC_ALL=C sed 's|.*/||' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "AgentsContext.FrontDoor.include AgentsTools.InternOpAgentSpawnProxy.include DistroAgentsTools.fn.sh "
rigAssert "the spawn proxy launches the console of the workspace it runs in, with MMDAPP set to it, and names no other workspace to start a spawn in" "$( [ "$( LC_ALL=C grep -c 'MMDAPP="\$MMDAPP".*"\$MMDAPP/DistroAgentsConsole.sh"' "$rigSpawnInclude" || : )" -gt 0 ] && printf launches-here || printf blind ) $( LC_ALL=C grep -c 'spawnWorkspace' "$rigSpawnInclude" || : )" "launches-here 0"
rigAssert "which is the workspace it was called from for every member, a client-* member too: MMDAPP is never set in the file, only handed to what it starts" "$( LC_ALL=C grep -v '^[[:space:]]*#' "$rigSpawnInclude" | LC_ALL=C grep -v 'env MMDAPP=' | LC_ALL=C grep -c -E '(^|[^A-Za-z_"$])MMDAPP=' || : ) $( LC_ALL=C grep -v '^[[:space:]]*#' "$rigSpawnInclude" | LC_ALL=C grep -c -F -e 'client-*)' || : )" "0 0"
rigAssert "the --intern-mcp-execute workspace arm uses the shared switch function, and the include defines it once" "$( LC_ALL=C grep -c "$rigSwitchFn \"\$2\"" "$rigTool" || : ) $( LC_ALL=C grep -c "^$rigSwitchFn(){" "$rigResolveInclude" || : )" "1 1"
rigAssert "the switch unsets the distro index variables, MDSC_ID by prefix"  "$( rigFnText="$( LC_ALL=C awk -v n="$rigSwitchFn" 'index( $0, n "(){" ) == 1 { on = 1 } on { print } on && /^}/ { exit }' "$rigResolveInclude" )" ; printf '%s\n' "$rigFnText" | LC_ALL=C grep -c -E 'unset MDSC_OPTION MDSC_INMODE MDSC_SOURCE MDSC_CACHED MDSC_OUTPUT MDSC_MEMORY|\$\{!MDSC_ID\*\}' || : )" 2
rigAssert "the switch never touches the tooling origin"                   "$( LC_ALL=C awk -v n="$rigSwitchFn" 'index( $0, n "(){" ) == 1 { on = 1 } on { print } on && /^}/ { exit }' "$rigResolveInclude" | LC_ALL=C grep -c 'MDLT_ORIGIN' || : )" 0
rigAssert "control: the same pattern finds an origin line in a sample"      "$( printf 'unset MDLT_ORIGIN\n' | LC_ALL=C grep -c 'MDLT_ORIGIN' || : )" 1

echo "-- 13. the member set root after a switch: a workspace's own index view holds its own members only --"
rigSwitchRoot(){ ## skillset root carried -- the root after a switch from ws-here to ws-there
	env -i MDAT_WORKSPACE_MODE=team-rig PATH="$PATH" MMDAPP="$rigWork/ws-here" MDAT_SKILLSET_ROOT="$1" bash -c '. "$1" ; '"$rigSwitchFn"' "$2" ; printf "%s" "${MDAT_SKILLSET_ROOT:-}"' rig-switch "$rigResolveInclude" "$rigWork/ws-there"
}
rigAssert "a root that was the old workspace's own index view becomes the new workspace's own" "$( rigSwitchRoot "$rigWork/ws-here/.local/agents/members" )" "$rigWork/ws-there/.local/agents/members"
rigAssert "accepted sibling: a root set anywhere else is kept across the switch" "$( rigSwitchRoot "$rigElsewhere" )" "$rigElsewhere"
rigAssert "the spawn proxy gives every session it starts a member set root along with its workspace, never the workspace alone" "$( [ "$( LC_ALL=C grep -c 'env MMDAPP="\$MMDAPP" MDAT_SKILLSET_ROOT="\$spawnSkillsetRoot"' "$rigSpawnInclude" || : )" -gt 0 ] && printf given || printf none ) $( LC_ALL=C grep 'env MMDAPP=' "$rigSpawnInclude" | LC_ALL=C grep -vc 'MDAT_SKILLSET_ROOT=' || : )" "given 0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MEMBER WORKSPACE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MEMBER_WORKSPACE: OK (%d assertions, offline)\n' "$rigPasses"
