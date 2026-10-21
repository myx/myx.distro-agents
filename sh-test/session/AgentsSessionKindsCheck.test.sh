#!/usr/bin/env bash
## Behavioural check on the session kinds (F6.1 of the refactorings epic). A routine declares one of two kinds in
## `requires-session-kind:`, `standalone` or `coworking`, and nothing else; `ad-hoc` is a start, never a routine's
## kind. Each kind is defined by a bundled routine, `magic-team.coworking.routine.md` and the new
## `magic-team.standalone.routine.md`; neither has a ready task, so the dispatch given at the start is the task. A
## routine inherits its kind routine's rules, its steps, and the defaults for keys it does not set. The coordinator
## comes only from frontmatter: the coworking routine's `executors: magic-coordinator` is a default a coworking
## routine may override, and the spawner's hardcoded add of the coordinator goes. Both kinds are sessions with a
## session thread. The console starts any routine, and each kind with no routine.
## Run through --magic-spawn-session from the console, the call the console's Launch makes, over a rig skillset that
## carries a copy of the package's own kind routines.
## Held:
##   1. the package bundles both kind routines, each declaring its own kind
##   2. the validator (F7.6's --tester-skillset-validate-routine) takes standalone and coworking, and refuses ad-hoc,
##      root and standalone-coworking, naming requires-session-kind; the spawner refuses to start a routine of kind
##      ad-hoc, naming it, and starts nothing
##   3. inheritance: a coworking routine that sets no executors starts magic-coordinator, the default it inherits;
##      the brief of a coworking routine carries its kind routine, and so does a standalone routine's
##   4. the coordinator: a coworking routine with its own executors and no coordinator starts without one, with the
##      old `session: coworking` key beside the new one too, and with its member given on the command line; nothing
##      adds the coordinator, and no line says it was added
##   5. both kinds are sessions with a session thread: every spawn record of either start carries `session-thread:`
##   6. the console starts any routine, and each kind with no routine: coworking by --routine-default, standalone by
##      its kind routine's name; there the dispatch given is the task, in the brief
## Red before F6.1: no standalone routine, no requires-session-kind: read, the coordinator added (1, 2, 3, 4 and the
## standalone half of 6 fail; 5 and the coworking half of 6 hold today, and must stay).
## Not tested, for want of a name: the option that starts the standalone kind with no routine, if it is not the kind
## routine's own name (open-names, F6.1).
## Offline: a fake curl first on PATH, a stand-in console that records each brief and runs no model.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTest="$rigPackage/sh-test"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigTeam="$rigPackage/skillset/magic-team/magic-team"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigTeam/magic-team.coworking.routine.md" ] || rigRefuse "the coworking routine is not in the package: $rigTeam"
## A spawn that is not waited for starts its session's control thread, which outlives this check: the rig ends it.
. "$rigTest/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
rigTmp="$( mkdir -p "${MMDAPP:?⛔ ERROR: MMDAPP is not set}/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsSessionKindsCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigSkills/magic-team" "$rigSkills/rig-member-a" "$rigSkills/magic-coordinator" "$rigData/board" "$rigTmp/routines"
cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records the context.' \
	'cat > "$RIG_SCENARIO/brief.$MDAT_SPAWN_AGENT"' \
	'printf "📦 SubagentHandback\n"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"
for rigMember in rig-member-a magic-coordinator ; do
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
	printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
done
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
## The package's own kind routines, as the rig's skillset carries them.
for rigKind in coworking standalone ; do
	[ ! -f "$rigTeam/magic-team.$rigKind.routine.md" ] || cp "$rigTeam/magic-team.$rigKind.routine.md" "$rigSkills/magic-team/"
done
## A rig routine of the team: its name, then its frontmatter lines.
rigRoutine(){ ## short name, frontmatter lines...
	local routineName="$1" ; shift
	{
		printf -- '---\n'
		printf '%s\n' "$@"
		printf 'maintainers: magic-coordinator\n---\n# magic-team.%s.routine — the actual procedure\n\n# Summary\n\nA rig routine.\n\n# Opening steps\n\n1. **open**: open.\n\n# Steps\n\n1. **work**: work.\n\n# Closure steps\n\n1. **close**: close.\n\n' "$routineName"
		printf "# Routine's local procedures\n\nNone.\n\n# Routine's local rules\n\nNone.\n\n# Routine-specific tooling\n\nNone.\n\n# Maintainer Notes\n\nNone.\n"
	} > "$rigSkills/magic-team/magic-team.$routineName.routine.md"
}
rigRoutine rigcownoexec 'type: routine' 'requires-session-kind: coworking'
rigRoutine rigcowown 'type: routine' 'executors: rig-member-a' 'requires-session-kind: coworking'
rigRoutine rigcowlegacy 'type: routine' 'executors: rig-member-a' 'requires-session-kind: coworking' 'session: coworking'
rigRoutine rigstand 'type: routine' 'executors: rig-member-a' 'requires-session-kind: standalone'
rigRoutine rigadhoc 'type: routine' 'executors: rig-member-a' 'requires-session-kind: ad-hoc'

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigFront(){ ## file -- its first frontmatter block
	LC_ALL=C awk 'NR == 1 && $0 != "---" { exit } NR > 1 && $0 == "---" { exit } NR > 1 { print }' "$1" 2> /dev/null
}
rigReset(){
	rm -f "$rigTmp"/brief.*
	chmod -R u+w -- "$rigWs/.local/agents/spawned" 2> /dev/null ; rm -rf "$rigWs/.local/agents/spawned"
}
## One --magic-spawn-session from the console, the task on its standard input; what it printed in $rigTmp/start.
## It waits, up to fifteen seconds, for the brief of every member the start names, so no brief of one start
## arrives during the next.
rigStart(){ ## --magic-spawn-session arguments...
	local startMembers startLeft=15
	rigReset
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --magic-spawn-session "$@"
		' rig-kinds "$@" <<< "RIG-TASK-TEXT" > "$rigTmp/start" 2>&1
	startMembers="$( LC_ALL=C sed -n 's/^MEMBERS=//p' "$rigTmp/start" | head -1 | LC_ALL=C wc -w | LC_ALL=C tr -d ' ' )"
	while [ "$( ( cd "$rigTmp" && ls brief.* 2> /dev/null ) | LC_ALL=C grep -c . )" -lt "${startMembers:-0}" ] && [ "$startLeft" -gt 0 ] ; do
		sleep 1 ; startLeft=$(( startLeft - 1 ))
	done
}
rigSaid(){ ## field -- its value on the start's own `<field>=` line, `none` where none
	local saidValue
	saidValue="$( LC_ALL=C sed -n "s/^$1=//p" "$rigTmp/start" | head -1 )"
	printf '%s' "${saidValue:-none}"
}
rigBriefs(){ ## -- the members a brief was recorded for, sorted, waiting up to ten seconds for the first
	local briefsLeft=10
	while ! ls "$rigTmp"/brief.* > /dev/null 2>&1 && [ "$briefsLeft" -gt 0 ] ; do sleep 1 ; briefsLeft=$(( briefsLeft - 1 )) ; done
	sleep 1
	( cd "$rigTmp" && ls brief.* 2> /dev/null ) | LC_ALL=C sed -e 's/^brief\.//' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed -e 's/ $//'
}
rigBriefHolds(){ ## member, fixed text -- yes or no
	if LC_ALL=C grep -q -F -- "$2" "$rigTmp/brief.$1" 2> /dev/null ; then printf yes ; else printf no ; fi
}
rigThreads(){ ## -- `<records>:<records with a session-thread:>`
	local threadsAll threadsWith
	threadsAll="$( ls "$rigWs"/.local/agents/spawned/*/*.spawn.md 2> /dev/null | LC_ALL=C grep -c . )"
	threadsWith="$( LC_ALL=C grep -l -E '^session-thread: [^ ]+' "$rigWs"/.local/agents/spawned/*/*.spawn.md 2> /dev/null | LC_ALL=C grep -c . )"
	printf '%s:%s' "$threadsAll" "$threadsWith"
}

echo "-- 1. the package bundles both kind routines, each declaring its own kind --"
rigAssert "magic-team.coworking.routine.md declares requires-session-kind: coworking" "$( rigFront "$rigTeam/magic-team.coworking.routine.md" | LC_ALL=C grep -c -x 'requires-session-kind: coworking' )" 1
rigAssert "magic-team.standalone.routine.md stands, declaring requires-session-kind: standalone" "$( [ -f "$rigTeam/magic-team.standalone.routine.md" ] && echo stands || echo missing ) $( rigFront "$rigTeam/magic-team.standalone.routine.md" | LC_ALL=C grep -c -x 'requires-session-kind: standalone' )" "stands 1"

echo "-- 2. the two kinds, and nothing else --"
rigValidate(){ ## routine file -- `0`, or `refused` and whether requires-session-kind is named
	local validateRc=0
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" bash "$rigTool" --tester-skillset-validate-routine "$1" ) > "$rigTmp/validate" 2>&1 < /dev/null || validateRc=$?
	if [ "$validateRc" -eq 0 ] ; then printf 0 ; return ; fi
	if LC_ALL=C grep -q -F 'requires-session-kind' "$rigTmp/validate" ; then printf 'refused named' ; else printf 'refused unnamed' ; fi
}
for rigKind in standalone coworking ad-hoc root standalone-coworking ; do
	rigRoutine "rigkind-$rigKind" 'type: routine' 'executors: rig-member-a' "requires-session-kind: $rigKind"
	cp "$rigSkills/magic-team/magic-team.rigkind-$rigKind.routine.md" "$rigTmp/routines/"
	rm -f "$rigSkills/magic-team/magic-team.rigkind-$rigKind.routine.md"
done
rigAssert "the validator takes standalone and coworking"          "$( rigValidate "$rigTmp/routines/magic-team.rigkind-standalone.routine.md" ):$( rigValidate "$rigTmp/routines/magic-team.rigkind-coworking.routine.md" )" "0:0"
rigAssert "and refuses ad-hoc, root and standalone-coworking, naming the key" "$( rigValidate "$rigTmp/routines/magic-team.rigkind-ad-hoc.routine.md" ):$( rigValidate "$rigTmp/routines/magic-team.rigkind-root.routine.md" ):$( rigValidate "$rigTmp/routines/magic-team.rigkind-standalone-coworking.routine.md" )" "refused named:refused named:refused named"
rigStart --routine rigadhoc
rigAssert "the spawner refuses a routine of kind ad-hoc, naming the key, and starts nothing" "$( rigSaid SESSION_ID ):$( LC_ALL=C grep -c -F 'requires-session-kind' "$rigTmp/start" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/named/' ):$( ls "$rigWs/.local/agents/spawned" 2> /dev/null | LC_ALL=C grep -c . )" "none:named:0"

echo "-- 3. a routine inherits from its kind routine --"
rigStart --routine rigcownoexec
rigAssert "a coworking routine that sets no executors starts magic-coordinator, the inherited default" "$( rigSaid MEMBERS )" "magic-coordinator"
rigStart --routine rigcowown
rigAssert "the brief of a coworking routine carries its kind routine" "$( rigBriefs ) $( rigBriefHolds rig-member-a magic-team.coworking.routine )" "rig-member-a yes"
rigStart --routine rigstand
rigAssert "the brief of a standalone routine carries its kind routine" "$( rigBriefs ) $( rigBriefHolds rig-member-a magic-team.standalone.routine )" "rig-member-a yes"

echo "-- 4. the coordinator comes only from frontmatter --"
rigStart --routine rigcowown
rigAssert "a coworking routine with its own executors starts them alone"         "$( rigSaid MEMBERS ):$( LC_ALL=C grep -c 'added magic-coordinator' "$rigTmp/start" ):$( rigBriefs )" "rig-member-a:0:rig-member-a"
rigStart --routine rigcowlegacy
rigAssert "the same with the old session: coworking beside the new key: nothing adds it" "$( rigSaid MEMBERS ):$( LC_ALL=C grep -c 'added magic-coordinator' "$rigTmp/start" ):$( rigBriefs )" "rig-member-a:0:rig-member-a"
rigStart --routine rigcowown rig-member-a
rigAssert "and with its member given on the command line"         "$( rigSaid MEMBERS ):$( LC_ALL=C grep -c 'added magic-coordinator' "$rigTmp/start" ):$( rigBriefs )" "rig-member-a:0:rig-member-a"

echo "-- 5. both kinds are sessions with a session thread --"
rigStart --routine rigstand
rigBriefs > /dev/null
rigAssert "a standalone start: a session, its records each with a session-thread"   "$( [ "$( rigSaid SESSION_ID )" != none ] && echo session || echo none ):$( rigThreads )" "session:1:1"
rigStart --routine-default
rigBriefs > /dev/null
rigAssert "a coworking start: a session, its records each with a session-thread"    "$( [ "$( rigSaid SESSION_ID )" != none ] && echo session || echo none ):$( rigThreads )" "session:1:1"

echo "-- 6. the console starts any routine, and each kind with no routine --"
rigStart --routine rigstand
rigAssert "any routine: a standalone routine of the team lands"   "$( [ "$( rigSaid SESSION_ID )" != none ] && echo lands || echo refused ):$( rigSaid ROUTINE )" "lands:magic-team.rigstand.routine.md"
rigStart --routine-default
rigAssert "coworking with no routine: its kind routine runs, the dispatch given its task" "$( rigSaid ROUTINE ):$( rigBriefs ):$( rigBriefHolds magic-coordinator RIG-TASK-TEXT )" "magic-team.coworking.routine.md:magic-coordinator:yes"
rigStart --routine magic-team.standalone
rigAssert "standalone with no routine: its kind routine runs, the dispatch given its task" "$( rigSaid ROUTINE ):$( rigBriefHolds "$( rigBriefs | LC_ALL=C cut -d' ' -f1 )" RIG-TASK-TEXT )" "magic-team.standalone.routine.md:yes"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SESSION KINDS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_KINDS: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
