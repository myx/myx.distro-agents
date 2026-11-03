#!/usr/bin/env bash
## Behavioural check on S6.5 of `20261102-refactorings.epic.md`: "An executor brings the participants
## its session names into the session. Whether it may invite anyone else follows its floor and its
## routine's permissions. Otherwise it escalates to the coordinator to invite a non-participant."
##
## Held end to end, run through the REAL spawn and the REAL console template on a stand-in `claude`
## (never a real session): the workspace's console IS the template, and the stand-in records the argv
## the template builds. What a member's own tool is told it may bring in is that argv, so it is read
## there and nowhere else -- no internal variable name of the fix is asserted, and no reading of code.
##   1. the session itself is as it was: the executor starts, and the participants are named in what
##      the spawn reports and on the session's own record;
##   2. the console the executor's session runs offers EACH LISTED PARTICIPANT as an agent type the
##      member's tool may bring in -- `--agents` carries an entry for every one of them;
##   3. and it still offers the executor itself, so the member can always reach its own tool;
##   4. the bound: a member the session does not list is not offered, so section 2's entries are the
##      session's own participants and not every member on the machine;
##   5. the control: a session that lists no participant offers the executor alone -- the machinery of
##      this check offers the executor on any session, today and after the fix.
##
## WHY THIS IS RED ON THE TREE BEFORE THE FIX: the console template writes `--agents` from one name,
## its own member (`AgentsConsoleShellScript.template.sh:887`), and never reads the session's
## participants. A listed participant then reaches the member's `Agent` tool as an unknown type and is
## refused before any hook runs, so the executor cannot bring in the member its own session names.
##
## Offline: a stand-in `claude` first on PATH logs its argv and starts no session; a fake curl answers
## Slack; the workspace, the store and every record are this rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigTemplate="$rigPackage/sh-lib/manager/AgentsConsoleShellScript.template.sh"
rigFixtures="$rigPackage/sh-test/check-fixtures"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigTool" "$rigTemplate" "$rigFixtures/slack-send-identity-check.curl.stub.sh" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

. "$rigFixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSpawnParticipantsOfferedCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## A filled sandbox input/ loses its write bits (AgentsToolsSpawnSandboxFillInput's own read-only-by-mode
## contract): restored before the tree is removed.
trap 'rigControlThreadsEnd "$rigTmp" ; chmod -R u+w -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSkills="$rigTmp/skills"
rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigTmp/bin" "$rigData/board" \
	"$rigSkills/magic-team" "$rigSkills/rig-member-a" "$rigSkills/rig-member-b" "$rigSkills/rig-member-c" "$rigTmp/home"
cp "$rigFixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing"
chmod +x "$rigTmp/bin/curl"
## The stand-in `claude`: it answers what the console asks before a launch, logs the argv of the
## launch, and starts nothing. It never opens a session, so no real CLI is involved.
printf '%s\n' '#!/bin/sh' \
	'case "$1" in --version) echo "9.9.9 (rig claude)" ; exit 0 ;; auth) echo "{\"loggedIn\":true}" ; exit 0 ;; esac' \
	'printf "%s\n" "$*" >> "$RIG_TMP/claude-args"' \
	'printf "📦 SubagentHandback\n" >&2' \
	'exit 0' > "$rigTmp/bin/claude"
chmod +x "$rigTmp/bin/claude"
[ "$( PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" command -v claude )" = "$rigTmp/bin/claude" ] || rigRefuse "the stand-in claude is not first on the rig PATH"
## The workspace's console is the template itself: what a workspace runs after --make-console-command,
## without an install into a live workspace.
printf 'MDLT_CONSOLE_ORIGIN=%s\n' "$rigOrigin" > "$rigWs/.local/MDLT.settings.env"
printf '%s\n' '#!/bin/sh' \
	'## cli-configured MDAT_SPAWN_LAUNCH_MARKER MDAT_SPAWN_PARTICIPANTS --cli) -- the real console template, on the stand-in claude' \
	'exec bash "$RIG_TEMPLATE" "$@"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSPAWN_TIER_NORMAL=claude-native\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'PRESET_CLI_SERVICE=claude-native\n' > "$rigWs/.local/.agents/preset-claude-native.agent.env"
for rigMember in rig-member-a rig-member-b rig-member-c ; do
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
	printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
done
printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator, magic-librarian\ninvitees: magic-team\nrequires-session-kind: coworking\n---\n# rig coworking routine fixture\n' \
	> "$rigSkills/magic-team/magic-team.coworking.routine.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
		printf '  PASS  %s\n' "$1"
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigRun(){ ## stdin content, then --spawn-session args... -- one spawn, made as the session's coordinator, who owns the operation
	env -i MDAT_SPAWN_AGENT=magic-coordinator MDAT_SESSION_ID=rig-caller-session MDAT_WORKSPACE_MODE=team-rig \
		HOME="$rigTmp/home" PATH="$rigTmp/bin:$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" \
		MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" \
		RIG_TEMPLATE="$rigTemplate" RIG_FN="$rigTool" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --spawn-session "$@"
		' rig-run-wrapper "$@" 2>&1
}
rigWaitFor(){ ## seconds, test command...
	local rigLeft="$1" ; shift
	while ! "$@" && [ "$rigLeft" -gt 0 ] ; do sleep 1 ; rigLeft=$(( rigLeft - 1 )) ; done
}
rigArgs(){ ## -- the argv lines the stand-in claude recorded
	cat "$rigTmp/claude-args" 2> /dev/null || :
}
rigOffered(){ ## from an argv line -- the agent type names its --agents JSON carries, one a line
	printf '%s\n' "$1" | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -o '"[a-z][a-z0-9-]*":{' | LC_ALL=C sed -n 's/^"\([a-z][a-z0-9-]*\)":{$/\1/p'
}
rigHasAgentArg(){ ## from an argv line, a name -- yes when `--agent <name>` stands there
	case " $1 " in *" --agent $2 "*) printf yes ;; *) printf no ;; esac
}
rigRecordOf(){ ## session id -- its record file
	printf '%s' "$rigWs/.local/agents/spawned/$1/$1.spawn.md"
}

## ---- 1. the session and its recorded participants ----
echo "-- 1. the executor starts, and the participants are named in the report and on the record --"
rigOut="$( printf 'RIG-TASK-TEXT\n' | rigRun --routine-default --participants 'rig-member-b,rig-member-c' rig-member-a )"
rigSessionId="$( printf '%s\n' "$rigOut" | LC_ALL=C awk -F= '$1 == "SESSION_ID" { print $2 ; exit }' )"
rigAssert "a session id is reported"                     "$( [ -n "$rigSessionId" ] && printf yes || printf no )" yes
rigAssert "the report names the participants it was given" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c -x -F 'PARTICIPANTS=rig-member-b rig-member-c' )" 1
rigRecord="$( rigRecordOf "$rigSessionId" )"
rigWaitFor 20 test -s "$rigRecord"
rigAssert "the session's record names them"              "$( [ -s "$rigRecord" ] && LC_ALL=C grep -c -x -F 'participants: rig-member-b rig-member-c' "$rigRecord" || : )" 1
rigWaitFor 40 test -s "$rigTmp/claude-args"
rigAssert "the executor's console reached its CLI"       "$( [ -s "$rigTmp/claude-args" ] && printf yes || printf no )" yes

## ---- 2. each listed participant is offered to the member's tool ----
echo "-- 2. the console offers every listed participant as an agent type --"
rigFirst="$( rigArgs | head -n 1 )"
rigListed="$( rigOffered "$rigFirst" )"
rigAssert "the member's own tool offers the first listed participant"   "$( printf '%s\n' "$rigListed" | LC_ALL=C grep -c -x -F 'rig-member-b' )" 1
rigAssert "and the second"                                              "$( printf '%s\n' "$rigListed" | LC_ALL=C grep -c -x -F 'rig-member-c' )" 1
rigAssert "the agent types are asked by name, the tool then finding the first" "$( rigHasAgentArg "$rigFirst" rig-member-a )" yes

## ---- 3. the executor itself is always offered ----
echo "-- 3. the executor is offered too, on every session --"
rigAssert "the executor is among the agent types"        "$( printf '%s\n' "$rigListed" | LC_ALL=C grep -c -x -F 'rig-member-a' )" 1

## ---- 4. a member the session does not list is not offered ----
echo "-- 4. the bound: a member the session does not name is not offered --"
rigAssert "a member outside the list is not offered"     "$( printf '%s\n' "$rigListed" | LC_ALL=C grep -c -x -F 'rig-member-c-absent' )" 0
rigAssert "nor is one that exists on this machine but is not listed" \
	"$( printf '%s\n' "$rigListed" | LC_ALL=C grep -c -x -e 'magic-coordinator' -e 'magic-librarian' )" 0

## ---- 5. the control: a session with no participant offers the executor alone ----
echo "-- 5. control: a session that lists no participant still offers the executor --"
: > "$rigTmp/claude-args"
rigOut2="$( printf 'RIG-TASK-TEXT\n' | rigRun --routine-default --participants none rig-member-a )"
rigWaitFor 40 test -s "$rigTmp/claude-args"
rigSolo="$( rigOffered "$( rigArgs | head -n 1 )" )"
rigAssert "the executor is still offered"                "$( printf '%s\n' "$rigSolo" | LC_ALL=C grep -c -x -F 'rig-member-a' )" 1
rigAssert "and no participant of the earlier session leaks into it" "$( printf '%s\n' "$rigSolo" | LC_ALL=C grep -c -x -e 'rig-member-b' -e 'rig-member-c' )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SPAWN PARTICIPANTS OFFERED CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_PARTICIPANTS_OFFERED: OK (%d assertions, offline, real console template on a stand-in CLI)\n' "$rigPassCount"
