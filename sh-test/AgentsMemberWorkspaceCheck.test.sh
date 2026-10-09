#!/usr/bin/env bash
## Behavioural check on the member-workspace auto-switch, run rather than read, against a fixture machine built here: a
## HOME holding the machine-wide member directory (member, workspace root, link kind, path, member directory) and the
## tracked workspaces list (absolute paths), both in $HOME/.agents/magic-team, and
## several workspace directories under one rig tree. The rule held: an operation naming a team member runs in the
## current workspace when the member is present there, else in the workspace where the member is a source link, else in
## the first tracked workspace that has it; a member the index does not know is not refused by the resolver, and a
## current workspace the index has no row for never switches. A known member in no tracked workspace, and a chosen path
## not on this machine, are named refusals, each with an accepted sibling. After a switch MMDAPP, the data root, the
## config scope and the registries are the new workspace's, the tooling origin is kept, the distro index variables of the
## old workspace are gone, and the call is not switched again. A spawn is started in the member's workspace while its
## records stay where it was asked. Offline: a fake `curl` first on PATH logs each call with the environment it ran in,
## a fake console records where it was started. What the stubs cannot show: a real second machine's index, real Slack
## and Atlassian answers, and a real agent session in the other workspace.
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
trap 'pkill -P "$rigDog" 2> /dev/null ; kill "$rigDog" 2> /dev/null ; wait "$rigDog" 2> /dev/null ; chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWork="$rigTmp/work" ; rigHome="$rigTmp/home" ; rigSkills="$rigHome/.claude/skills"
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
## Workspaces: ws-here (the current one), ws-there (holds client-ndm, a source link), ws-third, ws-rig (a rig workspace
## the index has no row for), ws-gone (listed, no directory). A member's scope file in a workspace says where it is.
rigMemberDir(){ ## member -- its skill directory with the files a send or a spawn reads
	mkdir -p "$rigSkills/$1"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$1/$1.basic.md"
	printf '# rig armed\n' > "$rigSkills/$1/$1.armed.md"
	printf -- '---\nname: %s\n---\n\n# %s\n' "$1" "$1" > "$rigSkills/$1/SKILL.md"
}
rigIdx(){ ## member, workspace, link kind -- one row of the members index
	## The row carries the workspace root; ws-gone's is where the list says it was.
	local idxRoot="$rigWork/$2"
	[ "$2" != ws-gone ] || idxRoot="$rigWork/gone/ws-gone"
	mkdir -p "${rigIndexFile%/*}"
	printf '%s\t%s\t%s\tmyx/pkg/skillset/%s\t%s/source/myx/pkg/skillset/%s\n' "$1" "$idxRoot" "$3" "$1" "$idxRoot" "$1" >> "$rigIndexFile"
}
rigScopeOf(){ ## workspace, member, lines... -- that member's scope file in that workspace
	local scopeWs="$1" scopeMember="$2" ; shift 2
	mkdir -p "$rigWork/$scopeWs/.local/.agents"
	printf '%s\n' "$@" > "$rigWork/$scopeWs/.local/.agents/$scopeMember.agent.env"
}
rigConsole(){ ## workspace, label -- a console that records where it was started and what it was given
	printf '%s\n' '#!/usr/bin/env bash' \
		'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records where it was started.' \
		"printf '%s\\n' \"\$MMDAPP\" > \"\$RIG_SCENARIO/launched.$2\"" \
		'cat > "$RIG_SCENARIO/brief.'"$2"'"' \
		'printf "📦 SubagentHandback\n"' \
		'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWork/$1/DistroAgentsConsole.sh"
	chmod +x "$rigWork/$1/DistroAgentsConsole.sh"
}
rigWorld(){ ## -- a fresh machine: workspaces, members, scopes, registries, the members index and the tracked list
	rm -rf "$rigWork" "$rigHome"
	mkdir -p "$rigSkills" "$rigWork/decoy"
	local wsName memberName
	for wsName in ws-here ws-there ws-third ws-rig ; do mkdir -p "$rigWork/$wsName/.local/.agents" "$rigWork/$wsName/.local/agents" ; done
	for memberName in keeper-here keeper-both client-ndm keeper-multi keeper-nosrc keeper-nowhere keeper-gone keeper-gonemix keeper-pre keeper-rel keeper-there keeper-unknown magic-team human-owner magic-coordinator ; do rigMemberDir "$memberName" ; done
	printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator\ninvitees: magic-team\ndefault-for-session-kind: coworking\n---\n# rig coworking routine fixture\n' > "$rigSkills/magic-team/magic-team.coworking.routine.md"
	## the members index: who is present where, and how
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
	rigIdx human-owner ws-there origin-symlink ; rigIdx magic-team ws-there origin-symlink
	rigIdx magic-coordinator ws-here source-symlink
	## the tracked workspaces: a trailing slash, a longer decoy name, a relative line, a comment, a blank line, a missing directory
	printf '%s\n' "$rigWork/ws-here" "$rigWork/ws-there/" "$rigWork/decoy/ws-there-old" "# a comment" "" "ws-rel" "$rigWork/ws-third" "$rigWork/gone/ws-gone" > "$rigListFile"
	## each workspace's own scope: where a member is, its tokens, its channels
	rigScopeOf ws-here magic-team 'SLACK_CHANNEL_MAGIC_TEAM=CHERE0001' 'SLACK_CHANNEL_HUMAN_OWNER=UHEREOWNER' 'SLACK_BOT_TOKEN=rig-bot-token-HERE'
	rigScopeOf ws-here keeper-here 'WHERE=ws-here' 'SLACK_USER_TOKEN=rig-user-token-KHERE'
	rigScopeOf ws-here keeper-both 'WHERE=ws-here' 'SLACK_USER_TOKEN=rig-user-token-KBOTHHERE'
	rigScopeOf ws-here magic-coordinator 'WHERE=ws-here' 'SLACK_USER_TOKEN=rig-user-token-COORDHERE'
	rigScopeOf ws-there magic-team 'SLACK_CHANNEL_MAGIC_TEAM=CTHERE0001' 'SLACK_CHANNEL_HUMAN_OWNER=UTHEREOWNER' 'SLACK_BOT_TOKEN=rig-bot-token-THERE'
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
	## a client workspace passes the outbound contact gate (--intern-op-contact-assert-known)
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
rigPre=()
rigRunIn(){ ## workspace, args... -- one dispatcher call from that workspace; stdout in out, stderr in err, rc in rigRc
	: > "$rigTmp/calls" ; : > "$rigTmp/envs" ; : > "$rigTmp/bodies"
	rigRc=0
	( cd "$rigWork/$1" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/$1" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$rigTmp" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "${@:2}" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigTraceIn(){ ## workspace, args... -- the same under bash -x; the trace in $rigTmp/trace
	rigRc=0
	( cd "$rigWork/$1" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/$1" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$rigTmp" \
		bash -x "$rigTool" "${@:2}" ) > "$rigTmp/out" 2> "$rigTmp/trace" < /dev/null || rigRc=$?
}
rigResolve(){ ## workspace, member, operation -- the resolver on its own; stdout in resOut, stderr in resErr, rc in resRc
	resRc=0
	( env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/$1" MDSC_CMD=RigCmd bash -c '. "$1" ; '"$rigResolveFn"' "$2" "$3"' rig-resolve "$rigResolveInclude" "$2" "${3:-RigOp}" ) > "$rigTmp/resOut" 2> "$rigTmp/resErr" || resRc=$?
	resOut="$( cat "$rigTmp/resOut" )" ; resErr="$( cat "$rigTmp/resErr" )"
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
rigEnvOf(){ ## method, field -- that field of the first logged call of that method
	LC_ALL=C awk -v m="$1" -v f="$2" '$1 == m { for ( i = 2 ; i <= NF ; i++ ) { if ( index( $i, f "=" ) == 1 ) { print substr( $i, length( f ) + 2 ) ; exit } } }' "$rigTmp/envs"
}

rigWorld
rigRunIn ws-here --agents-config-option keeper-here --select WHERE
[ "$rigRc" = 0 ] && [ "$( cat "$rigTmp/out" )" = "ws-here" ] || rigRefuse "the baseline config select did not answer from the current workspace, so no row below would be measured: rc=$rigRc $( LC_ALL=C grep -m1 -E 'ERROR|WARNING' "$rigTmp/err" )"
rigResolve ws-here client-ndm RigOp
[ "$resRc" = 0 ] && [ -n "$resOut" ] || rigRefuse "the resolver is not callable on its own or does not resolve the baseline member: rc=$resRc $resErr"

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
rigResolve ws-here magic-team
rigAssert "magic-team never switches, though the index holds a row for it elsewhere" "$resRc [$resOut] [$resErr]" "0 [] []"
rigResolve ws-here human-owner
rigAssert "human-owner never switches either"                              "$resRc [$resOut] [$resErr]" "0 [] []"
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

echo "-- 2. the failure rules, each with an accepted sibling --"
rigResolve ws-here keeper-nowhere --some-op
rigAssert "(a) a known member present in no tracked workspace: rc 1, nothing on stdout" "$resRc [$resOut]" "1 []"
rigAssert "(a) the error is named, with the command, the operation and the member, ending nothing was done" "$resErr" "⛔ ERROR: RigCmd --some-op: member 'keeper-nowhere' is in the team members index but is present in no tracked workspace -- nothing was done"
mkdir -p "$rigWork/ws-nolist" ; rigListAdd "$rigWork/ws-nolist"
rigResolve ws-here keeper-nowhere
rigAssert "(a) accepted sibling: tracked and present on the machine, the same member resolves" "$resRc [$resOut] [$resErr]" "0 [$rigWork/ws-nolist] []"
rigResolve ws-here keeper-gone
rigAssert "(b) a chosen path missing on the machine: rc 1, nothing on stdout"  "$resRc [$resOut]" "1 []"
rigAssert "(b) the error names the member and the path, ending nothing was done" "$resErr" "⛔ ERROR: RigCmd RigOp: the workspace of member 'keeper-gone' is not present on this machine: $rigWork/gone/ws-gone -- nothing was done"
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

echo "-- 3. the dispatcher: a member operation runs under the member's workspace --"
rigRunIn ws-here --agents-config-option keeper-here --select WHERE
rigAssert "a member in the current workspace: its own scope, no note about a switch on stderr" "$rigRc $( cat "$rigTmp/out" ) $( LC_ALL=C grep -c -i -E 'switch|tracked|moved to' "$rigTmp/err" || : )" "0 ws-here 0"
rigRunIn ws-here --agents-config-option keeper-both --select WHERE
rigAssert "present in both: the current workspace's scope"                 "$rigRc $( cat "$rigTmp/out" )" "0 ws-here"
rigRunIn ws-here --agents-config-option client-ndm --select WHERE
rigAssert "a member only elsewhere: that workspace's scope answers, and no note about a switch on stderr" "$rigRc $( cat "$rigTmp/out" ) $( LC_ALL=C grep -c -i -E 'switch|tracked|moved to' "$rigTmp/err" || : )" "0 ws-there 0"
rigRunIn ws-here --agents-config-option keeper-multi --select WHERE
rigAssert "in two others: the source link's scope"                         "$rigRc $( cat "$rigTmp/out" )" "0 ws-third"
rigRunIn ws-here --agents-config-option keeper-nosrc --select WHERE
rigAssert "in two others, no source link: the first tracked workspace's scope"  "$rigRc $( cat "$rigTmp/out" )" "0 ws-there"
rigRunIn ws-rig --agents-config-option client-ndm --select WHERE
rigAssert "from a rig workspace the index has no row for: never switched, its own scope" "$rigRc $( cat "$rigTmp/out" )" "0 ws-rig"
rigRunIn ws-here --agents-config-option client-ndm --select WHERE
rigAssert "the config operation taking the scope name first switches as well" "$rigRc $( cat "$rigTmp/out" )" "0 ws-there"
rigRunIn ws-here --agents-config-option keeper-nowhere --select WHERE
rigAssert "(a) a known member in no tracked workspace: named error from the dispatcher, rc 1, nothing on stdout" "$rigRc $( rigLines "$rigTmp/out" ) $( rigN "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --agents-config-option: member 'keeper-nowhere' is in the team members index but is present in no tracked workspace -- nothing was done" )" "1 0 1"
rigRunIn ws-here --agents-config-option keeper-gone --select WHERE
rigAssert "(b) a chosen path missing: named error, rc 1, nothing on stdout" "$rigRc $( rigLines "$rigTmp/out" ) $( rigN "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --agents-config-option: the workspace of member 'keeper-gone' is not present on this machine: $rigWork/gone/ws-gone -- nothing was done" )" "1 0 1"
mkdir -p "$rigWork/gone/ws-gone/.local/.agents" "$rigWork/ws-nolist/.local/.agents" ; rigListAdd "$rigWork/ws-nolist"
printf 'WHERE=ws-gone\n' > "$rigWork/gone/ws-gone/.local/.agents/keeper-gone.agent.env"
printf 'WHERE=ws-nolist\n' > "$rigWork/ws-nolist/.local/.agents/keeper-nowhere.agent.env"
rigRunIn ws-here --agents-config-option keeper-gone --select WHERE
rigAssert "(b) accepted sibling: with the directory present the operation runs there" "$rigRc $( cat "$rigTmp/out" )" "0 ws-gone"
rigRunIn ws-here --agents-config-option keeper-nowhere --select WHERE
rigAssert "(a) accepted sibling: once tracked the operation runs there"     "$rigRc $( cat "$rigTmp/out" )" "0 ws-nolist"
rigWorld
rigRunIn ws-here --agents-config-option keeper-unknown --select WHERE
rigUnknownWith="$rigRc $( cat "$rigTmp/out" ) $( cat "$rigTmp/err" )"
rigIndexOff
rigRunIn ws-here --agents-config-option keeper-unknown --select WHERE
rigUnknownWithout="$rigRc $( cat "$rigTmp/out" ) $( cat "$rigTmp/err" )"
rigIndexOn
rigAssert "(c) a name not in the index: the operation answers exactly as with no index at all" "$rigUnknownWith" "$rigUnknownWithout"
rigRunIn ws-here --agents-config-option keeper-here --select WHERE
rigWith="$rigRc $( cat "$rigTmp/out" ) $( cat "$rigTmp/err" )"
rigIndexOff
rigRunIn ws-here --agents-config-option keeper-here --select WHERE
rigWithout="$rigRc $( cat "$rigTmp/out" ) $( cat "$rigTmp/err" )"
rigIndexOn
rigAssert "unchanged: a member in the current workspace answers byte for byte as with no index at all, stderr included" "$rigWith" "$rigWithout"
rigRunIn ws-here --agents-config-option magic-team --select SLACK_CHANNEL_MAGIC_TEAM
rigAssert "magic-team as the member argument: never switched, the current workspace's channel" "$rigRc $( cat "$rigTmp/out" )" "0 CHERE0001"
rigAssert "the caller's own shell keeps its MMDAPP after a switched call"  "$( MMDAPP="$rigWork/ws-here" ; ( cd "$rigWork/ws-here" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$MMDAPP" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" bash -c 'bash "$1" --agents-config-option client-ndm --select WHERE > /dev/null 2>&1 ; printf "%s" "$MMDAPP"' rig-shell "$rigTool" ) )" "$rigWork/ws-here"

echo "-- 4. no re-entry loop after a switch --"
rigTraceIn ws-here --agents-config-option client-ndm --select WHERE
rigAssert "a switched call resolves twice, once before and once after the switch, and finishes" "$rigRc $( cat "$rigTmp/out" ) $( LC_ALL=C grep -c "$rigResolveFn client-ndm --agents-config-option" "$rigTmp/trace" || : )" "0 ws-there 2"
rigTraceIn ws-here --agents-config-option keeper-here --select WHERE
rigAssert "control: a call that needs no switch resolves once"             "$rigRc $( cat "$rigTmp/out" ) $( LC_ALL=C grep -c "$rigResolveFn keeper-here --agents-config-option" "$rigTmp/trace" || : )" "0 ws-here 1"
rigTraceIn ws-here --agents-config-option keeper-multi --select WHERE
rigAssert "a member whose chosen workspace is not the first row: still two"  "$rigRc $( cat "$rigTmp/out" ) $( LC_ALL=C grep -c "$rigResolveFn keeper-multi --agents-config-option" "$rigTmp/trace" || : )" "0 ws-third 2"

echo "-- 5. after a switch: the workspace's state follows, the origin stays, the old index state is gone --"
rigPre=( MDSC_CACHED=/stale/cache MDSC_ID_RIGSTALE=stale )
rigRunIn ws-here --member-comms-slack-send-message client-ndm magic-team RIG-BODY
rigAssert "the send ran under the new workspace: MMDAPP is ws-there when curl was called"  "$( rigEnvOf chat.postMessage MMDAPP )" "$rigWork/ws-there"
rigAssert "the tooling origin is kept, not re-derived from the new workspace"  "$( rigEnvOf chat.postMessage ORIGIN )" "$MDLT_ORIGIN"
rigAssert "the planted distro index variables of the old workspace are gone"  "$( rigEnvOf chat.postMessage CACHED ) $( rigEnvOf chat.postMessage STALEID )" "unset unset"
rigRunIn ws-here --member-comms-slack-send-message keeper-here magic-team RIG-BODY
rigAssert "control: a send that needs no switch ran under the current workspace" "$( rigEnvOf chat.postMessage MMDAPP )" "$rigWork/ws-here"
rigPre=( "MDAT_DATA_ROOT=$rigWork/ws-here/.local/agents/team-data-root" )
rigRunIn ws-here --member-comms-slack-send-message client-ndm magic-team RIG-BODY
rigAssert "a data root the caller carried from the old workspace is not carried into the new one" "$( rigEnvOf chat.postMessage DATAROOT )" "$rigWork/ws-there/.local/agents/team-data-root"
rigRunIn ws-here --member-comms-slack-send-message keeper-here magic-team RIG-BODY
rigAssert "control: with no switch a data root the caller carried is kept"  "$( rigEnvOf chat.postMessage DATAROOT )" "$rigWork/ws-here/.local/agents/team-data-root"
rigPre=()
rigRunIn ws-here --member-comms-slack-send-message client-ndm magic-team RIG-BODY
rigAssert "with no data root carried the new workspace's own is derived"     "$( rigEnvOf chat.postMessage DATAROOT )" "$rigWork/ws-there/.local/agents/team-data-root"

echo "-- 6. a client send from a workspace that does not hold the client --"
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
rigRunIn ws-here --member-comms-slack-send-message keeper-here magic-team RIG-BODY
rigAssert "a member in the current workspace: its own token, channel and header" "$( rigTokens )$( rigChannel ) $( rigText )" 'rig-user-token-KHERE CHERE0001 🔧 *_keeper-here_* @herakeep → @here.\nRIG-BODY'
rigRunIn ws-there --member-comms-slack-send-message keeper-here magic-team RIG-BODY
rigAssert "the same member sent from ws-there: switched back to ws-here, its token and channel" "$( rigTokens )$( rigChannel )" 'rig-user-token-KHERE CHERE0001'
rigRunIn ws-rig --member-comms-slack-send-message client-ndm magic-team RIG-BODY
rigAssert "from a rig workspace the index does not know: no switch, its own token and channel" "$( rigTokens )$( rigChannel ) $( rigText )" 'rig-user-token-NDMRIG CRIG000001 🐭 *_Rig Persona_* @rigalias → @here.\nRIG-BODY'
rigIndexOff
rigRunIn ws-here --member-comms-slack-send-message client-ndm magic-team RIG-BODY
rigAssert "control: with no index the other workspace's token is never used"  "$( rigN "$rigTmp/calls" 'NDMTHERE' )" 0
rigIndexOn

echo "-- 7. a --client-* operation switches too --"
rigRunIn ws-here --client-comms-jira-board-list client-ndm
rigAssert "the Jira call goes to the site of the other workspace's scope, as that scope's user"  "$rigRc $( LC_ALL=C awk '$1 == "http" { print $2, $3 }' "$rigTmp/calls" )" "0 jira-there.invalid ndm@rig.invalid"
rigAssert "and ran under that workspace"                                   "$( rigEnvOf http MMDAPP )" "$rigWork/ws-there"
rigRunIn ws-rig --client-comms-jira-board-list client-ndm
rigAssert "from a workspace the index has no row for: its own scope's site, no switch" "$( LC_ALL=C awk '$1 == "http" { print $2, $3 }' "$rigTmp/calls" )" "jira-rig.invalid rig@rig.invalid"
rigIndexOff
rigRunIn ws-here --client-comms-jira-board-list client-ndm
rigAssert "control: with no index the client has no scope here and the call is refused for its missing keys, no call made" "$( rigLines "$rigTmp/calls" ) $( rigN "$rigTmp/err" 'JIRA_SITE/JIRA_USER/JIRA_API_TOKEN missing' )" "0 1"
rigIndexOn
rigRunIn ws-here --client-sweep-input-scan keeper-nowhere
rigAssert "a --client-* operation names the same refusal for a known member in no tracked workspace" "$rigRc $( rigN "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --client-sweep-input-scan: member 'keeper-nowhere' is in the team members index but is present in no tracked workspace -- nothing was done" )" "1 1"
rigRunIn ws-here --client-sweep-input-scan client-ndm
rigAssert "accepted sibling: a client held by another workspace is not refused by the switch, its own operation answers" "$( rigN "$rigTmp/err" "present in no tracked workspace" ) $( rigN "$rigTmp/err" "is not present on this machine" )" "0 0"

## ---- spawning ----
rigTreeSum(){ ## workspace -- a checksum of the file list and contents of that workspace's own .local/agents, so a write there shows
	( cd "$rigWork/$1/.local/agents" 2> /dev/null && find . -type f 2> /dev/null | LC_ALL=C sort | LC_ALL=C xargs cat 2> /dev/null ; find . -type f 2> /dev/null | LC_ALL=C sort ) | cksum
}
rigSpawnIn(){ ## workspace, member, extra args... -- the spawn proxy asked for that member from that workspace, task text on stdin; output in out
	: > "$rigTmp/calls" ; : > "$rigTmp/envs" ; : > "$rigTmp/bodies" ; rm -f "$rigTmp"/launched.* "$rigTmp"/brief.*
	rigRc=0
	( cd "$rigWork/$1" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/$1" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$rigTmp" \
		bash "$rigTool" --intern-op-agent-spawn-proxy "$2" "${@:3}" --dispatch-doc:none --wait --context rig-ws-switch ) > "$rigTmp/out" 2> "$rigTmp/err" <<< "RIG-TASK-TEXT" || rigRc=$?
}
rigLaunched(){ ## -- where each console was started: HERE THERE THIRD RIG, `-` for none
	local launchLabel launchOut=""
	for launchLabel in HERE THERE THIRD RIG ; do
		if [ -f "$rigTmp/launched.$launchLabel" ] ; then launchOut="$launchOut $launchLabel=$( cat "$rigTmp/launched.$launchLabel" )" ; fi
	done
	printf '%s\n' "${launchOut# }" | LC_ALL=C sed "s|$rigWork/||g"
}
rigSettle(){ ## label... -- wait up to 20 seconds for those consoles to have been started, then let detached work finish
	local settleLabel settleLeft=20
	for settleLabel in "$@" ; do
		while [ ! -f "$rigTmp/launched.$settleLabel" ] && [ "$settleLeft" -gt 0 ] ; do sleep 1 ; settleLeft=$(( settleLeft - 1 )) ; done
	done
	sleep 3
}
rigBoardItems(){ ## workspace -- how many dispatch items that workspace's board holds
	find "$rigWork/$1/.local/agents/team-data-root/board" -name 'dispatch-*.md' 2> /dev/null | LC_ALL=C awk 'END { print NR + 0 }'
}
rigSpawnedCount(){ ## workspace -- how many spawn records that workspace holds
	( cd "$rigWork/$1/.local/agents/spawned" 2> /dev/null && ls */*.md 2> /dev/null | LC_ALL=C awk 'END { print NR + 0 }' ) || printf 0
}

echo "-- 8. the spawn proxy starts the member's session in the member's workspace --"
rigWorld
rigFilesThere="$( cd "$rigWork/ws-there/.local/agents" && find . -type f | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )"
rigSpawnIn ws-here keeper-there
rigAssert "the session is launched by the console of the member's workspace, started there"  "$rigRc $( rigLaunched )" "0 THERE=ws-there"
rigAssert "the task text reaches that console"                              "$( LC_ALL=C grep -c -x 'RIG-TASK-TEXT' "$rigTmp/brief.THERE" 2> /dev/null || : )" 1
rigAssert "the spawn record stays in the spawning workspace, none in the member's" "$( rigSpawnedCount ws-here ) $( rigSpawnedCount ws-there )" "1 0"
rigAssert "the member's workspace gained only the send log of the session-thread post, no record, no sandbox, no registry" "$( cd "$rigWork/ws-there/.local/agents" && find . -type f | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed "s|./comms-slack-send\.[0-9][0-9][0-9][0-9]-[0-9][0-9]\.log ||" )" "$rigFilesThere"
rigSpawnIn ws-here keeper-here
rigAssert "control: a member in the spawning workspace is launched there, as before" "$rigRc $( rigLaunched )" "0 HERE=ws-here"
rigSpawnIn ws-here keeper-unknown
rigAssert "a member the index does not know is launched in the spawning workspace, as before" "$rigRc $( rigLaunched )" "0 HERE=ws-here"
rigSpawnIn ws-rig keeper-there
rigAssert "from a workspace the index has no row for: launched in that workspace" "$rigRc $( rigLaunched )" "0 RIG=ws-rig"
rigSpawnIn ws-here keeper-multi
rigAssert "a member in two others: launched in its source link's workspace"  "$rigRc $( rigLaunched )" "0 THIRD=ws-third"
rigSpawnedBefore="$( rigSpawnedCount ws-here )"
rigSpawnIn ws-here keeper-nowhere
rigAssert "(a) a known member in no tracked workspace: rc 1, nothing launched, no record, named error" "$rigRc $( rigLaunched ) $(( $( rigSpawnedCount ws-here ) - rigSpawnedBefore )) $( rigN "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --intern-op-agent-spawn-proxy: member 'keeper-nowhere' is in the team members index but is present in no tracked workspace -- nothing was done" )" "1  0 1"
mkdir -p "$rigWork/ws-nolist" ; rigConsole ws-nolist NOLIST ; rigListAdd "$rigWork/ws-nolist"
rigSpawnIn ws-here keeper-nowhere
rigAssert "(a) accepted sibling: tracked and present, the same member is launched there" "$rigRc $( ls "$rigTmp" | LC_ALL=C grep -c '^launched.NOLIST$' || : ) $( cat "$rigTmp/launched.NOLIST" 2> /dev/null )" "0 1 $rigWork/ws-nolist"
rigSpawnIn ws-here keeper-gone
rigAssert "(b) a chosen path missing on the machine: rc 1, nothing launched, named error" "$rigRc $( rigLaunched ) $( rigN "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --intern-op-agent-spawn-proxy: the workspace of member 'keeper-gone' is not present on this machine: $rigWork/gone/ws-gone -- nothing was done" )" "1  1"
mkdir -p "$rigWork/gone/ws-gone/.local/.agents" ; rigConsole "gone/ws-gone" GONE 2> /dev/null
rigSpawnIn ws-here keeper-gone
rigAssert "(b) accepted sibling: with the directory and a console there the same member is launched there" "$rigRc $( cat "$rigTmp/launched.GONE" 2> /dev/null | LC_ALL=C sed "s|$rigWork/||" )" "0 gone/ws-gone"
chmod -x "$rigWork/ws-there/DistroAgentsConsole.sh"
rigSpawnIn ws-here keeper-there
rigAssert "the console check is made at the member's workspace: not executable there is refused, naming that path" "$rigRc $( rigLaunched ) $( rigN "$rigTmp/err" "DistroAgentsConsole.sh is not executable at $rigWork/ws-there" )" "1  1"
chmod +x "$rigWork/ws-there/DistroAgentsConsole.sh"
rigSpawnIn ws-here keeper-there
rigAssert "accepted sibling: executable again, the same spawn is launched"  "$rigRc $( rigLaunched )" "0 THERE=ws-there"
rm -f "$rigWork/ws-here/DistroAgentsConsole.sh"
rigSpawnIn ws-here keeper-there
rigAssert "the spawning workspace's own console is not needed for a member elsewhere" "$rigRc $( rigLaunched )" "0 THERE=ws-there"
rigConsole ws-here HERE

echo "-- 8b. a handback retry is resumed exactly as the launch was: the member's workspace, its session, its CLI --"
## A console that hands back only when resumed, recording each start: the launch, then
## the proxy's one handback retry (MDAT_SPAWN_RESUME=true). It carries a --cli) arm
## mention, so the proxy accepts --spawn-cli-service against it.
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured and --cli) stand-in: writes MDAT_SPAWN_LAUNCH_MARKER, hands back only when resumed.' \
	'printf "%s|%s|%s|%s\n" "$MMDAPP" "$MDAT_SESSION_ID" "$MDAT_SESSION_THREAD" "$*" > "$RIG_SCENARIO/start.${MDAT_SPAWN_RESUME:-launch}"' \
	'cat > /dev/null' \
	'[ "${MDAT_SPAWN_RESUME:-}" != true ] || printf "📦 SubagentHandback\n"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWork/ws-there/DistroAgentsConsole.sh"
rm -f "$rigTmp"/start.*
## Without --wait: a --wait spawn under --dispatch-doc:none keeps no output file, and the
## retry reads the output file for the handback, so only this form reaches it.
rigRc=0
( cd "$rigWork/ws-here" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/ws-here" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$rigTmp" \
	bash "$rigTool" --intern-op-agent-spawn-proxy keeper-there --spawn-cli-service rig-service --dispatch-doc:none --context rig-ws-switch ) > "$rigTmp/out" 2> "$rigTmp/err" <<< "RIG-TASK-TEXT" || rigRc=$?
rigRetryLeft=30
while [ ! -s "$rigTmp/start.true" ] && [ "$rigRetryLeft" -gt 0 ] ; do sleep 1 ; rigRetryLeft=$(( rigRetryLeft - 1 )) ; done
rigAssert "a launch with no handback is retried once"                     "$rigRc $( ls "$rigTmp" | LC_ALL=C grep -c '^start\.' || : )" "0 2"
rigAssert "the retry gets the launch's own workspace, session id, session thread and CLI args" "$( cat "$rigTmp/start.true" 2> /dev/null )" "$( cat "$rigTmp/start.launch" 2> /dev/null )"
rigAssert "which are the member's workspace and the asked-for CLI, never the caller's" "$( LC_ALL=C cut -d'|' -f1,4 "$rigTmp/start.true" 2> /dev/null | LC_ALL=C sed "s|$rigWork/||" )" "ws-there|--cli rig-service --non-interactive"
rigAssert "with a session id and a session thread carried, not empty"   "$( LC_ALL=C awk -F'|' '{ print ( $2 != "" && $3 != "" ) ? "carried" : "empty" }' "$rigTmp/start.true" 2> /dev/null )" carried
rm -f "$rigTmp"/start.*
rigConsole ws-there THERE

echo "-- 9. --magic-spawn-session, --magic-heartbeat-* and the root harness --"
rigSessionIn(){ ## workspace, args... -- --magic-spawn-session from that workspace
	: > "$rigTmp/calls" ; : > "$rigTmp/envs" ; : > "$rigTmp/bodies" ; rm -f "$rigTmp"/launched.* "$rigTmp"/brief.*
	rigRc=0
	( cd "$rigWork/$1" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/$1" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$rigTmp" \
		bash "$rigTool" --magic-spawn-session "${@:2}" ) > "$rigTmp/out" 2> "$rigTmp/err" <<< "RIG-TASK-TEXT" || rigRc=$?
}
rigWorld
rigSessionIn ws-here --routine-default keeper-there ; rigSettle THERE
rigAssert "a session for a member in another workspace is launched in that workspace" "$rigRc $( rigLaunched )" "0 THERE=ws-there"
rigSpawnedBefore="$( rigSpawnedCount ws-here )"
rigSessionIn ws-here --routine-default keeper-there keeper-here ; rigSettle THERE HERE
rigAssert "two members in two workspaces: each launched in its own"        "$rigRc $( rigLaunched )" "0 HERE=ws-here THERE=ws-there"
rigAssert "and the records of both are the spawning workspace's, none in the other"          "$(( $( rigSpawnedCount ws-here ) - rigSpawnedBefore )) $( rigSpawnedCount ws-there )" "2 0"
rigSessionIn ws-here --routine-default keeper-nowhere
rigAssert "(a) a known member in no tracked workspace: refused, nothing launched"  "$rigRc $( rigLaunched ) $(( $( rigN "$rigTmp/out" "present in no tracked workspace -- nothing was done" ) + $( rigN "$rigTmp/err" "present in no tracked workspace -- nothing was done" ) ))" "1  1"
rigSessionIn ws-here --routine-default keeper-here ; rigSettle HERE
rigAssert "control: a member in the current workspace launched there"      "$rigRc $( rigLaunched )" "0 HERE=ws-here"
for rigW in there here ; do
	mkdir -p "$rigWork/ws-$rigW/.local/agents/team-data-root/inboxes/magic-coordinator"
	printf -- '---\nstate: working\nsession-id: RIG-%s-SESSION\nrecheck-date: %s\n---\nbody\n' "$rigW" "$( date -u +%Y-%m-%dT%H:%M:%SZ )" > "$rigWork/ws-$rigW/.local/agents/team-data-root/inboxes/magic-coordinator/note-20260809T155000Z-heartbeat-state-and-lock.md"
done
rigRunIn ws-here --magic-heartbeat-lock-status keeper-there
rigAssert "a --magic-heartbeat-* operation reads the member's workspace's team data, not the current one's" "$( cat "$rigTmp/out" )" "ACTIVE:owner=RIG-there-SESSION:state=working:recheck_date=$( LC_ALL=C sed -n 's/^recheck-date: //p' "$rigWork/ws-there/.local/agents/team-data-root/inboxes/magic-coordinator/note-20260809T155000Z-heartbeat-state-and-lock.md" )"
rigRunIn ws-here --magic-heartbeat-lock-status keeper-here
rigAssert "control: for a member of the current workspace it reads the current workspace's own"     "$( cat "$rigTmp/out" | LC_ALL=C sed 's/:recheck_date=.*//' )" "ACTIVE:owner=RIG-here-SESSION:state=working"
rigRunIn ws-there --magic-heartbeat-lock-status keeper-there
rigAssert "control: from the member's own workspace it reads its own"     "$( cat "$rigTmp/out" | LC_ALL=C sed 's/:recheck_date=.*//' )" "ACTIVE:owner=RIG-there-SESSION:state=working"
rigRunIn ws-here --magic-heartbeat-lock-status keeper-nowhere
rigAssert "(a) a --magic-heartbeat-* operation names the same refusal"     "$rigRc $( rigN "$rigTmp/err" "⛔ ERROR: DistroAgentsTools --magic-heartbeat-lock-status: member 'keeper-nowhere' is in the team members index but is present in no tracked workspace -- nothing was done" )" "1 1"
rigRootIn(){ ## workspace, args... -- --intern-root-harness from that workspace
	: > "$rigTmp/calls" ; : > "$rigTmp/envs" ; : > "$rigTmp/bodies" ; rm -f "$rigTmp"/launched.* "$rigTmp"/brief.*
	rigRc=0
	( cd "$rigWork/$1" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/$1" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$rigTmp" \
		bash "$rigTool" --intern-root-harness "${@:2}" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator\n---\n# rig heartbeat routine fixture\n' > "$rigSkills/magic-coordinator/magic-coordinator.heartbeat.routine.md"
rigRootIn ws-here --routine heartbeat --non-interactive --wait ; rigSettle HERE
rigAssert "the root harness, whose caller is the coordinator present in the current workspace: launched there" "$rigRc $( rigLaunched )" "0 HERE=ws-here"
rigSpawnedBefore="$( rigSpawnedCount ws-there )" ; rigBoardBeforeThere="$( rigBoardItems ws-there )" ; rigBoardBeforeHere="$( rigBoardItems ws-here )"
rigRootIn ws-there --routine heartbeat --non-interactive --wait ; rigSettle HERE
rigAssert "the same from a workspace the coordinator is not in: its session is launched in the coordinator's workspace" "$rigRc $( rigLaunched )" "0 HERE=ws-here"
rigAssert "and the record stays in the workspace it was asked from"        "$(( $( rigSpawnedCount ws-there ) - rigSpawnedBefore ))" "1"
rigAssert "and the dispatch item and board stay in the workspace it was asked from" "$(( $( rigBoardItems ws-there ) - rigBoardBeforeThere )) $(( $( rigBoardItems ws-here ) - rigBoardBeforeHere ))" "1 0"
rigLoopIn(){ ## workspace -- --intern-main-loop --one from that workspace
	: > "$rigTmp/calls" ; : > "$rigTmp/envs" ; : > "$rigTmp/bodies" ; rm -f "$rigTmp"/launched.* "$rigTmp"/brief.*
	rigRc=0
	( cd "$rigWork/$1" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/$1" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$rigTmp" \
		bash "$rigTool" --intern-main-loop --one ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigWorld
printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator\n---\n# rig heartbeat routine fixture\n' > "$rigSkills/magic-coordinator/magic-coordinator.heartbeat.routine.md"
printf 'SPAWN_CLI_SERVICE=rig-cli\n' >> "$rigWork/ws-there/.local/.agents/magic-team.agent.env" ; printf 'SPAWN_CLI_SERVICE=rig-cli\n' >> "$rigWork/ws-here/.local/.agents/magic-team.agent.env"
rigLoopIn ws-here ; rigSettle HERE
rigAssert "the main loop in the coordinator's own workspace: one pass, launched there, as before"  "$rigRc $( rigLaunched ) $( rigN "$rigTmp/err" 'pass succeeded, exit 0, launched true' )" "0 HERE=ws-here 1"
rigLoopIn ws-there ; rigSettle HERE
rigAssert "the main loop in a workspace the coordinator is not in: its pass launches the coordinator's session in the coordinator's workspace" "$rigRc $( rigLaunched ) $( rigN "$rigTmp/err" 'pass succeeded, exit 0, launched true' )" "0 HERE=ws-here 1"

echo "-- 10. the harness tools that name a member --"
rigToolIn(){ ## workspace, agent, tool, json -- one harness tool call as that agent from that workspace; output in out
	: > "$rigTmp/calls" ; : > "$rigTmp/envs" ; : > "$rigTmp/bodies" ; rm -f "$rigTmp"/launched.* "$rigTmp"/brief.*
	rigRc=0
	( cd "$rigWork/$1" && printf '%s' "$4" | env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWork/$1" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$rigTmp" \
		MDAT_SPAWN_SESSION_ID=rig-session-a MDAT_SPAWN_AGENT="$2" MDAT_HARNESS_WAIT_TIMEOUT=1 bash "$rigHarness" --intern-tool "$3" ) > "$rigTmp/out" 2> "$rigTmp/err" || rigRc=$?
}
rigSettle
rigWorld
rigToolIn ws-here client-ndm SendMessage '{"to":"magic-team","message":"RIG-BODY"}'
rigAssert "SendMessage as a client held by another workspace: its token, that workspace's channel"  "$( rigTokens )$( rigChannel )" 'rig-user-token-NDMTHERE CTHERE0001'
rigToolIn ws-here keeper-here SendMessage '{"to":"magic-team","message":"RIG-BODY"}'
rigAssert "control: SendMessage as a member of the current workspace: its own token and channel" "$( rigTokens )$( rigChannel )" 'rig-user-token-KHERE CHERE0001'
rigToolIn ws-here client-ndm Wait '{"sources":"slack:magic-team","timeout":0}'
rigAssert "Wait as a client held by another workspace: the long poll ran under that workspace's token and root" "$( LC_ALL=C awk '$1 ~ /^conversations/ { print $2 ; exit }' "$rigTmp/calls" ) $( rigEnvOf conversations.history MMDAPP | LC_ALL=C sed "s|$rigWork/||" )" 'rig-user-token-NDMTHERE ws-there'
rigToolIn ws-here keeper-here Wait '{"sources":"slack:magic-team","timeout":0}'
rigAssert "control: Wait as a member of the current workspace"            "$( LC_ALL=C awk '$1 ~ /^conversations/ { print $2 ; exit }' "$rigTmp/calls" ) $( rigEnvOf conversations.history MMDAPP | LC_ALL=C sed "s|$rigWork/||" )" 'rig-user-token-KHERE ws-here'
rigToolIn ws-here client-ndm AskUserQuestion '{"to":"human-owner","question":"May the rig keep its file?","wait":false}'
rigAssert "AskUserQuestion as a client held by another workspace: every post under that workspace's token" "$( rigTokens | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -v '^$' | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' ' )" 'rig-user-token-NDMTHERE '
rigSpawnedBefore="$( rigSpawnedCount ws-here )" ; rigBoardBeforeHere="$( rigBoardItems ws-here )"
rigToolIn ws-here keeper-here Agent '{"agent":"keeper-there","prompt":"RIG-TASK-TEXT"}' ; rigSettle THERE
rigAssert "Agent naming a member of another workspace: its session is launched there"  "$( rigLaunched )" "THERE=ws-there"
rigAssert "and the spawn record is the calling workspace's"               "$(( $( rigSpawnedCount ws-here ) - rigSpawnedBefore )) $( rigSpawnedCount ws-there )" "1 0"
rigAssert "and so are its dispatch item and board, none in the member's workspace" "$(( $( rigBoardItems ws-here ) - rigBoardBeforeHere )) $( rigBoardItems ws-there )" "1 0"
rigToolIn ws-here keeper-here ListAgents '{"view":"sessions"}'
rigAssert "ListAgents lists the calling workspace's sessions, the spawn above included, and does not look elsewhere" "$( LC_ALL=C grep -c -E 'keeper-there|rig-' "$rigTmp/out" || : ) $( rigN "$rigTmp/calls" 'http' )" "1 0"
rigToolIn ws-there keeper-here ListAgents '{"view":"sessions"}'
rigAssert "from the other workspace the same call lists that workspace's own, none of the first's" "$( LC_ALL=C grep -c -E 'keeper-there|rig-' "$rigTmp/out" || : )" 0
rigToolIn ws-here keeper-here Skill '{"name":"client-ndm"}'
rigAssert "Skill for a member held by another workspace reads the shared skillset, with no switch"  "$( [ "$( LC_ALL=C grep -c 'client-ndm' "$rigTmp/out" || : )" -gt 0 ] && printf read || printf empty ) $( rigLines "$rigTmp/calls" )" "read 0"
rigToolIn ws-here keeper-nowhere SendMessage '{"to":"magic-team","message":"RIG-BODY"}'
rigAssert "(a) SendMessage as a known member in no tracked workspace: refused with the named error, nothing posted" "$( rigN "$rigTmp/out" "present in no tracked workspace -- nothing was done" ) $( rigTokens )" "1 "
rigListAdd "$rigWork/ws-nolist" ; mkdir -p "$rigWork/ws-nolist/.local/.agents" ; rigScopeOf ws-nolist magic-team 'SLACK_CHANNEL_MAGIC_TEAM=CNOLIST01' 'SLACK_BOT_TOKEN=rig-bot-token-NOLIST' ; rigScopeOf ws-nolist keeper-nowhere 'SLACK_USER_TOKEN=rig-user-token-KNOWHERE'
rigToolIn ws-here keeper-nowhere SendMessage '{"to":"magic-team","message":"RIG-BODY"}'
rigAssert "(a) accepted sibling: tracked and present, the same call posts under that workspace" "$( rigTokens )$( rigChannel )" 'rig-user-token-KNOWHERE CNOLIST01'
rigWorld

echo "-- 11. static: where the resolver is called, and not called --"
rigDispatchEntry="$( LC_ALL=C awk '/^DistroAgentsTools\(\)\{/ { on = 1 } on { print } on && /^\t\. "\$MDLT_ORIGIN\/myx\/myx.distro-agents\/sh-lib\/AgentsContext.UseAgentsTools.include"/ { exit }' "$rigTool" )"
rigAssert "control: the dispatcher's entry was cut out, up to the context include"  "$( printf '%s\n' "$rigDispatchEntry" | LC_ALL=C grep -c 'AgentsContext.UseAgentsTools.include' || : )" 1
rigAssert "the entry resolves once, before the context include"           "$( printf '%s\n' "$rigDispatchEntry" | LC_ALL=C grep -c "$rigResolveFn \"\$2\" \"\$1\"" || : )" 1
rigExclusion="$( printf '%s\n' "$rigDispatchEntry" | LC_ALL=C grep -F -e '|*:|*:-*) ;;' | LC_ALL=C sed -e 's/^[[:space:]]*//' -e 's/) ;;$//' )"
## The Decisions append and the review implementations are the tooling's own: their <who> is the name recorded, not
## the member whose workspace the item lives in, and they run where their caller's records are.
rigAssert "the entry's one exclusion line: the spawn proxy, the two operations that wrap it, the MCP execute, the Decisions append, the review implementations, an empty second word, an option" "$rigExclusion" '--intern-op-agent-spawn-proxy:*|--magic-heartbeat-spawn-proxy:*|--magic-spawn-session:*|--intern-mcp-execute:*|--intern-op-decisions-append:*|--intern-op-review-*:*|*:|*:-*'
rigAssert "control: a sample entry without the wrapping operations is told apart" "$( printf -- '--intern-op-agent-spawn-proxy:*|--intern-mcp-execute:*|*:|*:-*\n' )" "$( printf '%s' "$rigExclusion" | LC_ALL=C sed 's/--magic-heartbeat-spawn-proxy:[*]|--magic-spawn-session:[*]|//; s/--intern-op-decisions-append:[*]|//; s/--intern-op-review-[*]:[*]|//' )"
rigAssert "a switch re-runs the whole call in a subshell under the new root"  "$( printf '%s\n' "$rigDispatchEntry" | LC_ALL=C grep -c "( $rigSwitchFn \"\$memberWorkspace\" ; DistroAgentsTools \"\$@\" )" || : )" 1
rigAssert "the resolver is called from the dispatcher entry and the spawn proxy, and nowhere else" "$( LC_ALL=C grep -l "$rigResolveFn \"" "$rigHere"/*.include "$rigHere"/*.sh "$rigPackage/sh-scripts"/*.sh 2> /dev/null | LC_ALL=C sed 's|.*/||' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "AgentsTools.InternOpAgentSpawnProxy.include DistroAgentsTools.fn.sh "
rigAssert "the spawn proxy launches the console of the resolved workspace, with MMDAPP set to it, never the spawning one" "$( [ "$( LC_ALL=C grep -c 'MMDAPP="\$spawnWorkspace".*"\$spawnWorkspace/DistroAgentsConsole.sh"' "$rigSpawnInclude" || : )" -gt 0 ] && printf launches-there || printf blind ) $( LC_ALL=C grep -v '^[[:space:]]*#' "$rigSpawnInclude" | LC_ALL=C grep -c 'MMDAPP="\$MMDAPP".*DistroAgentsConsole.sh' || : )" "launches-there 0"
rigAssert "the --intern-mcp-execute workspace arm uses the shared switch function, and the include defines it once" "$( LC_ALL=C grep -c "$rigSwitchFn \"\$2\"" "$rigTool" || : ) $( LC_ALL=C grep -c "^$rigSwitchFn(){" "$rigResolveInclude" || : )" "1 1"
rigAssert "the switch unsets the distro index variables, MDSC_ID by prefix"  "$( rigFnText="$( LC_ALL=C awk -v n="$rigSwitchFn" 'index( $0, n "(){" ) == 1 { on = 1 } on { print } on && /^}/ { exit }' "$rigResolveInclude" )" ; printf '%s\n' "$rigFnText" | LC_ALL=C grep -c -E 'unset MDSC_OPTION MDSC_INMODE MDSC_SOURCE MDSC_CACHED MDSC_OUTPUT MDSC_MEMORY|\$\{!MDSC_ID\*\}' || : )" 2
rigAssert "the switch never touches the tooling origin"                   "$( LC_ALL=C awk -v n="$rigSwitchFn" 'index( $0, n "(){" ) == 1 { on = 1 } on { print } on && /^}/ { exit }' "$rigResolveInclude" | LC_ALL=C grep -c 'MDLT_ORIGIN' || : )" 0
rigAssert "control: the same pattern finds an origin line in a sample"      "$( printf 'unset MDLT_ORIGIN\n' | LC_ALL=C grep -c 'MDLT_ORIGIN' || : )" 1

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MEMBER WORKSPACE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MEMBER_WORKSPACE: OK (%d assertions, offline)\n' "$rigPasses"
