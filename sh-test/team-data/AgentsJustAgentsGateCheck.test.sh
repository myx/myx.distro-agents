#!/usr/bin/env bash
## Behavioural check on the just-agents gate (F13.1, AgentsTools.TeamDataGate.include): a workspace whose mode is no team rig keeps no
## team data, and the writers refuse to create it. Held, run and not read:
##   1. THE MODE, and the one reader of it: the mode the settings of the team set stands ahead of MDAT_WORKSPACE_MODE (the default of a rig,
##      which the test runner exports), which stands ahead of `just-agents`; a value that is none of the three is no value, and `rig-client`
##      acts as just agents. A board create is the probe: refused, with nothing made in the data root, or written.
##   2. THE LIST, agentsTeamDataGateOps: every operation on it is refused in a just-agents workspace before it makes a folder or says a
##      word, with the mode and where it comes from named; a family of the list is not refused in a team rig; every name on the list is
##      a name the tooling has.
##   3. A READER IS NEVER REFUSED: the settings, a vault read and an audit read answer as they do, with a store that is not there.
##   4. THE WRITERS THAT PASS NO PRIMITIVE: the contacts store writes no contact; a team-data store that has a remote is not cloned; a session
##      the spawn proxy starts runs as `--dispatch-doc:none` (no tracking item, no transcript in the team data), a reuse of a tracking item is
##      refused. In a team rig each of them does what it did.
## Every call is an `env -i` child that refuses to run outside this rig's tree, so the mode comes from the rig alone. Offline: no Slack, no
## network, a fake console for the spawn; the only git is a bare remote of this rig.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigContacts="$rigPackage/sh-scripts/DistroAgentsContacts.fn.sh"
rigGate="$rigPackage/sh-lib/team-data/AgentsTools.TeamDataGate.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] && [ -f "$rigContacts" ] || rigRefuse "the tooling is not at the origin this workspace resolves: $rigTool"
command -v git > /dev/null || rigRefuse "git is not installed"
## A spawn of this rig that is not waited for starts the control thread of its session, a detached process that outlives this check.
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the fixture that ends control threads is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsJustAgentsGateCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
export GIT_AUTHOR_NAME=rig GIT_AUTHOR_EMAIL=rig@example.invalid GIT_COMMITTER_NAME=rig GIT_COMMITTER_EMAIL=rig@example.invalid
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigWs="$rigTmp/ws" rigData="$rigTmp/data" rigHome="$rigTmp/home"
mkdir -p "$rigWs/.local/.agents" "$rigHome" "$rigTmp/skills/rig-member"
printf 'rig\n' > "$rigTmp/skills/rig-member/rig-member.basic.md"
## The console the spawn proxy launches: it answers, and signals that it launched.
printf '#!/bin/sh\n## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli)\ncat > /dev/null\necho rig-child-output\n[ -z "$MDAT_SPAWN_LAUNCH_MARKER" ] || echo rig-cli > "$MDAT_SPAWN_LAUNCH_MARKER"\nexit 0\n' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"

rigMode="" rigModeEnv="" rigSettingsMore="" rigAs=""
rigFresh(){ ## the data root empty and made, as a workspace that has none yet
	rm -rf -- "$rigData" ; mkdir -p "$rigData"
}
rigUntouched(){ ## how many things the data root holds
	find "$rigData" -mindepth 1 2> /dev/null | wc -l | LC_ALL=C tr -d ' '
}
rigRun(){ ## tool, then its words; stdin /dev/null unless rigStdin names text -- stdout in $rigTmp/out, stderr in $rigTmp/err, rc in rigRc
	local runTool="$1" runSettings="" ; shift
	[ -z "$rigMode" ] || runSettings="MDAT_WORKSPACE_MODE=$rigMode"$'\n'
	runSettings="$runSettings$rigSettingsMore"
	if [ -n "$runSettings" ] ; then printf '%s' "$runSettings" > "$rigWs/.local/.agents/magic-team.agent.env" ; else rm -f "$rigWs/.local/.agents/magic-team.agent.env" ; fi
	printf '%s' "${rigStdin:-}" | ( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigTmp/skills" RIG_TMP="$rigTmp" ${rigAs:+MDAT_SPAWN_AGENT="$rigAs"} ${rigModeEnv:+MDAT_WORKSPACE_MODE="$rigModeEnv"} \
		bash -c 'case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; exec bash "$0" "$@"' "$runTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err"
	rigRc=$?
}
rigSaid(){ ## how many lines of stderr hold the refusal of the gate
	LC_ALL=C grep -c -F 'this workspace keeps no team data' "$rigTmp/err" || :
}
rigCreate(){ ## the board create that is the probe of the mode
	rigStdin=$'---\ntype: task\n---\n\nrig body\n'
	rigRun "$rigTool" --intern-op-board-upsert-move-edit backlog task-20261020T0100Z-rig-gate.md --create --acting-member:rig-member --upsert-from-stdin --context rig
	rigStdin=""
}

echo "-- 1. the mode, and what a board create does under it --"
rigMode="" rigModeEnv=""
rigRows=$'|||just-agents (default)\n|just-agents||just-agents (default)\n|nonesuch||just-agents (default)\njust-agents|team-rig||just-agents (workspace)\nrig-client|||rig-client (workspace)\nnonesuch|||just-agents (default)\nnonesuch|just-agents||just-agents (default)'
while IFS='|' read -r rigFile rigEnv rigUnused rigWant ; do
	rigMode="$rigFile" rigModeEnv="$rigEnv" ; rigFresh ; rigCreate
	rigAssert "settings [${rigFile:--}] env [${rigEnv:--}]: refused, rc 1" "$rigRc" 1
	rigAssert "settings [${rigFile:--}] env [${rigEnv:--}]: it says that no team data is kept, and the mode ($rigWant)" "$( rigSaid ):$( LC_ALL=C grep -c -F "its mode is $rigWant," "$rigTmp/err" || : )" 1:1
	rigAssert "settings [${rigFile:--}] env [${rigEnv:--}]: nothing is made in the data root" "$( rigUntouched )" 0
done <<< "$rigRows"
rigRows=$'|team-rig\nteam-rig|\nteam-rig|just-agents\nnonesuch|team-rig'
while IFS='|' read -r rigFile rigEnv ; do
	rigMode="$rigFile" rigModeEnv="$rigEnv" ; rigFresh ; rigCreate
	rigAssert "settings [${rigFile:--}] env [${rigEnv:--}]: a team rig, the item is written" "$rigRc:$( [ -f "$rigData/board/backlog/task-20261020T0100Z-rig-gate.md" ] && printf yes || printf no ):$( rigSaid )" 0:yes:0
done <<< "$rigRows"

echo "-- 2. the list --"
rigOps=""
[ ! -f "$rigGate" ] || rigOps="$( bash -c '. "$1" ; printf "%s\n" "$agentsTeamDataGateOps"' rig-list "$rigGate" 2> /dev/null )"
rigAssert "the list stands in AgentsTools.TeamDataGate.include, and holds the primitives every item passes" \
	"$( printf '%s\n' "$rigOps" | LC_ALL=C grep -c -x -e '--intern-op-board-upsert-move-edit' -e '--intern-op-member-inbox-upsert' -e '--intern-op-board-rename' -e '--intern-op-board-trash' -e '--intern-op-item-rename' -e '--intern-op-inbox-to-processed' -e '--intern-team-data-final-gc-deletion' || : )" 7
rigAssert "and the families of the board's own machinery" \
	"$( printf '%s\n' "$rigOps" | LC_ALL=C grep -c -x -e '--move-to-\*' -e '--create-running' -e '--grooming-\*' -e '--sweep-state-\*' -e '--config-check' -e '--spawn-prompt' -e '--send-report' -e '--state-note-\*' -e '--intern-op-state-note-upsert' -e '--advance-\*' -e '--daily-\*' -e '--retro-\*' -e '--commit-pending' -e '--intern-main-loop' || : )" 14
rigAssert "and the writers of a transcript and of the record of a published artifact" \
	"$( printf '%s\n' "$rigOps" | LC_ALL=C grep -c -x -e '--append-transcript' -e '--intern-op-append-session-transcript' -e '--intern-artifact-\*' || : )" 3
rigMode=just-agents rigModeEnv=""
while IFS= read -r rigPattern ; do
	[ -n "$rigPattern" ] || continue
	rigOp="${rigPattern//\*/rig-probe}" rigOpArg=""
	case "$rigOp" in --member-*) rigOpArg=rig-member ;; --magic-append-*) rigAs=magic-coordinator ;; --spawn-prompt|--send-report) rigOpArg=magic-coordinator ;; esac
	rigFresh ; rigRun "$rigTool" "$rigOp" ${rigOpArg:+"$rigOpArg"} ; rigAs=""
	rigAssert "$rigOp: refused in a just-agents workspace, before anything is made" "$rigRc:$( rigSaid ):$( rigUntouched )" 1:1:0
	rigAssert "$rigOp: the refusal is the first thing said, and names the operation" "$( LC_ALL=C grep -c -F -e "$rigOp: this workspace keeps no team data" "$rigTmp/err" || : )" 1
	case "$rigPattern" in
		*'*'*)
			rigMode=team-rig ; rigFresh ; rigRun "$rigTool" "$rigOp" ; rigMode=just-agents
			rigAssert "$rigOp: in a team rig the gate does not refuse it" "$( rigSaid )" 0
		;;
		*)
			rigAssert "$rigOp: is a name some file of the tooling other than the list holds" "$( [ "$( LC_ALL=C grep -r -l -F -e "$rigOp" "$rigPackage/sh-scripts" "$rigPackage/sh-lib" --exclude='Help.*' --exclude='AgentsTools.TeamDataGate.include' 2> /dev/null | LC_ALL=C grep -c . )" -gt 0 ] && printf yes || printf no )" yes
		;;
	esac
done <<< "$rigOps"
rigAssert "the list is not empty" "$( [ -n "$rigOps" ] && printf yes || printf no )" yes

echo "-- 3. a reader is never refused --"
rigMode=just-agents rigModeEnv="" ; rigFresh
rigRun "$rigTool" --agents-config-option magic-team --select MDAT_WORKSPACE_MODE
rigAssert "the settings answer: rc 0, the value" "$rigRc $( cat "$rigTmp/out" )" "0 just-agents"
rigRun "$rigTool" --intern-op-vault-item-read rig-none.md
rigAssert "a vault read is no refusal of the gate, and makes nothing" "$( rigSaid ):$( rigUntouched )" 0:0
rigRun "$rigTool" --intern-op-audit-item-read rig-none.md
rigAssert "an audit read is no refusal of the gate, and makes nothing" "$( rigSaid ):$( rigUntouched )" 0:0
rigRun "$rigTool" --help
rigAssert "the help is no refusal of the gate" "$( rigSaid )" 0

echo "-- 4a. the contacts store --"
rigAs=rig-member rigMode=just-agents rigModeEnv="" ; rigFresh
rigRun "$rigContacts" --collect-contact --id rig-person --name "Rig Person"
rigAssert "a just-agents workspace writes no contact: refused, rc 1, nothing made" "$rigRc:$( rigSaid ):$( rigUntouched )" 1:1:0
rigMode=team-rig ; rigFresh
rigRun "$rigContacts" --collect-contact --id rig-person --name "Rig Person"
rigAssert "a team rig writes it" "$rigRc:$( [ -f "$rigData/contacts/persons/rig-person.md" ] && printf yes || printf no ):$( rigSaid )" 0:yes:0
rigAs=""

echo "-- 4b. the clone of a team-data store --"
git init -q --bare "$rigTmp/remote.git" || rigRefuse "could not init the bare remote"
git -C "$rigTmp" init -q -b main seed 2> /dev/null || { git -C "$rigTmp" init -q seed && git -C "$rigTmp/seed" checkout -q -b main ; }
printf 'seed\n' > "$rigTmp/seed/README.md"
git -C "$rigTmp/seed" add -A && git -C "$rigTmp/seed" commit -q -m seed && git -C "$rigTmp/seed" push -q "$rigTmp/remote.git" main 2> /dev/null || rigRefuse "could not seed the bare remote"
rigSettingsMore=$'TEAM_DATA_GIT_REMOTE='"$rigTmp"$'/remote.git\nTEAM_DATA_BRANCH=main\n'
rigMode=just-agents rigModeEnv="" ; rm -rf -- "$rigData"
rigRun "$rigTool" --intern-op-vault-item-read rig-none.md
rigAssert "a just-agents workspace with a remote set clones nothing: no store is made" "$( [ -e "$rigData" ] && printf made || printf none )" none
rigMode=team-rig ; rm -rf -- "$rigData"
rigRun "$rigTool" --intern-op-vault-item-read rig-none.md
rigAssert "a team rig with the same remote clones it" "$( [ -d "$rigData/.git" ] && printf yes || printf no ):$( cat "$rigData/README.md" 2> /dev/null )" yes:seed
rigSettingsMore=""

echo "-- 4c. a session the spawn proxy starts --"
rigMode=just-agents rigModeEnv="" ; rigFresh
rigStdin="rig context"
rigRun "$rigTool" --intern-op-agent-spawn-proxy rig-member --dispatch-doc:create --wait --context rig-gate
rigAssert "just agents: the session starts and ends, rc 0" "$rigRc:$( LC_ALL=C grep -c '^LAUNCHED=true$' "$rigTmp/out" )" 0:1
rigAssert "it ran as --dispatch-doc:none: said so, and no tracking item named" "$( LC_ALL=C grep -c '^DISPATCH_DOC=none$' "$rigTmp/out" ):$( LC_ALL=C grep -c '^DISPATCH_ITEM=' "$rigTmp/out" || : )" 1:0
rigAssert "the team data holds nothing of it: no board, no audit transcript" "$( rigUntouched )" 0
rigAssert "its own session records stand where a session keeps them" "$( ls "$rigWs/.local/agents/sessions" 2> /dev/null | LC_ALL=C grep -c . )" 1
rigAssert "and the output of the child reached its caller" "$( cat "$rigTmp/out" "$rigTmp/err" | LC_ALL=C grep -c '^rig-child-output$' )" 1
rigRun "$rigTool" --intern-op-agent-spawn-proxy rig-member --dispatch-doc:reuse --from-board task-20261020T0100Z-rig-gate.md --wait --context rig-gate
rigAssert "a reuse of a tracking item is refused, and starts nothing" "$( [ "$rigRc" != 0 ] && printf refused || printf started ):$( LC_ALL=C grep -c '^LAUNCHED=true$' "$rigTmp/out" || : ):$( rigUntouched )" refused:0:0
rm -rf -- "$rigWs/.local/agents/sessions"
rigMode=team-rig ; rigFresh
rigStdin="rig context"
rigRun "$rigTool" --intern-op-agent-spawn-proxy rig-member --dispatch-doc:create --wait --context rig-gate
rigAssert "a team rig: the same start creates its tracking item, which closes into board/review" "$rigRc:$( LC_ALL=C grep -c '^DISPATCH_ITEM=' "$rigTmp/out" ):$( ls "$rigData/board/review" 2> /dev/null | LC_ALL=C grep -c '^dispatch-' )" 0:1:1
rigStdin=""

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ JUST AGENTS GATE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'JUST_AGENTS_GATE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
