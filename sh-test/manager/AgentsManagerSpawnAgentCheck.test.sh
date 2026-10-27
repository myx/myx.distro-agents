#!/usr/bin/env bash
## Behavioural check on --manager-spawn-agent, the console's start of a bare agent (sketch 5.1: "simple ad-hoc spawn ...
## up to zero folders and documents, logged the fact only"), run rather than read, against a rig workspace whose console
## is a stand-in that writes down what it is given. Held: the prompt reaches the console on standard input and is no
## argument of it; the console is told the run is bare (MDAT_SPAWN_BARE) and is given an EMPTY member (MDAT_SPAWN_AGENT);
## the environment of a session the call may be inside (MDAT_SPAWN_SESSION_ID) is taken off; --cli-service selects the
## CLI by --cli and its absence by --cli-configured; one `spawn-agent` row is printed; the only thing made is one
## start line and one end line in the log of the tooling -- no sandbox, no spawn record, no dispatch item. Refused,
## each in one line with nothing started: an empty prompt, an option unknown, a CLI name that is no name, a console that
## is not executable. And the console's template holds the guard that makes a bare start name no member. Offline.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTool="${rigHere%/sh-lib}/sh-scripts/DistroAgentsTools.fn.sh"
rigOp="--manager-spawn-agent"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerSpawnAgentCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigHome" "$rigSkills"
: > "$rigWs/.local/.agents/keeper-rig.agent.env" ; chmod 770 "$rigWs/.local/.agents" ; chmod 660 "$rigWs/.local/.agents"/*.agent.env
rigLog="$rigWs/.local/agents/bare-spawn.log"
rigNote="$rigTmp/console.calls"
rigMakeConsole(){ ## a stand-in console: writes down its arguments, its relevant environment and its standard input
	cat > "$rigWs/DistroAgentsConsole.sh" <<'RIGCONSOLE'
#!/usr/bin/env bash
{
	printf 'args=%s\n' "$*"
	printf 'bare=%s\n' "${MDAT_SPAWN_BARE:-unset}"
	if [ "${MDAT_SPAWN_AGENT+set}" = "set" ] ; then printf 'agent=[%s]\n' "$MDAT_SPAWN_AGENT" ; else printf 'agent=unset\n' ; fi
	printf 'session=%s\n' "${MDAT_SPAWN_SESSION_ID:-unset}"
	printf 'scoped=%s\n' "${MDAT_CONVERSATION_THREADS:-unset}/${MDAT_SKILLSET_ROOT:-unset}/${MDAT_SPAWN_LAUNCH_MARKER:-unset}/${MDAT_SPAWN_RESUME_EVENT_MARKER:-unset}/${MDAT_HARNESS_RESUME_CONTEXT:-unset}/${MDAT_HARNESS_RESUME_MARKER:-unset}"
	printf 'stdin=%s\n' "$( cat )"
} > "$RIG_NOTE"
RIGCONSOLE
	chmod +x "$rigWs/DistroAgentsConsole.sh"
}
rigMakeConsole
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigPre=() rigStdin=/dev/null
rigRun(){ ## tool arguments... -- one dispatcher call from the rig workspace; rc in rigRc, stdout in out, stderr in err
	rigRc=0
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		RIG_NOTE="$rigNote" ${rigPre[@]+"${rigPre[@]}"} bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < "$rigStdin" || rigRc=$?
}
rigWaitFor(){ local waitLeft="$1" ; shift ; while ! "$@" && [ "$waitLeft" -gt 0 ] ; do sleep 1 ; waitLeft=$(( waitLeft - 1 )) ; done ; "$@" ; }
rigNoted(){ [ -s "$rigNote" ] && LC_ALL=C grep -q '^stdin=' "$rigNote" ; }
rigField(){ LC_ALL=C sed -n "s/^$1=//p" "$rigNote" | head -1 ; }
rigTroubles(){ LC_ALL=C grep -E -- 'ERROR|WARNING' "$rigTmp/err" | LC_ALL=C grep -c -v -F -- 'SystemContext.SetInputSpec' || : ; }
rigMade(){ ls "$rigWs/.local/agents" | LC_ALL=C tr '\n' ' ' ; }

echo "-- 1. a prompt on standard input: the console is started bare, the prompt on its standard input --"
printf 'say the word of the rig\n' > "$rigTmp/prompt"
rigStdin="$rigTmp/prompt" ; rigPre=( "MDAT_SPAWN_SESSION_ID=a-session-this-call-is-inside" "MDAT_CONVERSATION_THREADS=c:1" "MDAT_SKILLSET_ROOT=/x" "MDAT_SPAWN_LAUNCH_MARKER=/y" "MDAT_SPAWN_RESUME_EVENT_MARKER=/z" "MDAT_HARNESS_RESUME_CONTEXT=/c" "MDAT_HARNESS_RESUME_MARKER=/m" )
rigRun "$rigOp"
rigStdin=/dev/null ; rigPre=()
rigWaitFor 20 rigNoted
rigAssert "the call ends 0 with no error and no warning" "$rigRc $( rigTroubles )" "0 0"
rigAssert "one row: spawn-agent, a pid, and that the configured CLI is used" "$( LC_ALL=C awk -F'\t' '{ print $1, ($2 ~ /^[0-9]+$/ ? "pid" : "nopid"), $3 }' "$rigTmp/out" )" "spawn-agent pid configured"
rigAssert "the console got --cli-configured and --non-interactive, and no word of the prompt as an argument" "[$( rigField args )]" "[--cli-configured --non-interactive]"
rigAssert "the prompt reached its standard input" "[$( rigField stdin )]" "[say the word of the rig]"
rigAssert "the console was told the run is bare, and given an empty member, not none" "$( rigField bare ) $( rigField agent )" "true []"
rigAssert "the session this call is inside is not the run's: its id is off the environment" "$( rigField session )" "unset"
rigAssert "every variable of the calling session that the console or the harness below it reads is off the environment: threads, skillset root, launch marker, both resume markers, resume context" "$( rigField scoped )" "unset/unset/unset/unset/unset/unset"
rigWaitFor 20 test "$( LC_ALL=C grep -c 'bare-spawn ended' "$rigLog" 2> /dev/null || : )" -ge 1
rigAssert "the log of the tooling holds the start and the end of it, and the length of the prompt but not its words" "$( LC_ALL=C grep -c 'bare-spawn started configured pid [0-9]* prompt 23 bytes' "$rigLog" ) $( LC_ALL=C grep -c 'bare-spawn ended configured exit 0' "$rigLog" ) $( LC_ALL=C grep -c 'say the word' "$rigLog" || : )" "1 1 0"
rigAssert "nothing else was made: no sandbox, no record of a spawn, no item" "[$( rigMade )]" "[bare-spawn.log ]"

echo "-- 2. --cli-service, --goal and --from-file --"
rm -f "$rigNote"
rigRun "$rigOp" --cli-service rig-cli --goal 'a goal with a quote " and a %s'
rigWaitFor 20 rigNoted
rigAssert "a named CLI goes as --cli, and the goal is the prompt: on standard input, byte for byte" "[$( rigField args )] [$( rigField stdin )]" "[--cli rig-cli --non-interactive] [a goal with a quote \" and a %s]"
rm -f "$rigNote" ; printf 'from a file\n' > "$rigTmp/file.txt"
rigRun "$rigOp" --from-file "$rigTmp/file.txt"
rigWaitFor 20 rigNoted
rigAssert "a file is the prompt too" "[$( rigField stdin )]" "[from a file]"

echo "-- 3. what is refused, each in one line, with nothing started --"
sleep 1 ; rm -f "$rigNote" ; rigBefore="$( LC_ALL=C wc -l < "$rigLog" | LC_ALL=C tr -d ' ' )"
rigRun "$rigOp"
rigAssert "an empty prompt" "$rigRc $( LC_ALL=C grep -c 'the prompt is empty -- nothing was started' "$rigTmp/err" ) $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" "1 1 0"
rigRun "$rigOp" --nonsense
rigAssert "an option it does not know" "$rigRc $( LC_ALL=C grep -c 'syntax is' "$rigTmp/err" )" "1 1"
rigRun "$rigOp" --cli-service 'Bad Name' --goal x
rigAssert "a CLI name that is no name" "$rigRc $( LC_ALL=C grep -c 'nothing was started' "$rigTmp/err" )" "1 1"
rigRun "$rigOp" --goal x --from-stdin
rigAssert "a goal together with another way of giving the prompt" "$rigRc $( LC_ALL=C grep -c 'nothing was started' "$rigTmp/err" )" "1 1"
chmod -x "$rigWs/DistroAgentsConsole.sh"
rigRun "$rigOp" --goal x
rigAssert "a console that is not executable" "$rigRc $( LC_ALL=C grep -c 'is not executable' "$rigTmp/err" )" "1 1"
chmod +x "$rigWs/DistroAgentsConsole.sh"
rigAssert "none of the refusals started a console or wrote the log" "$( [ -e "$rigNote" ] && echo ran || echo none ) $( LC_ALL=C wc -l < "$rigLog" | LC_ALL=C tr -d ' ' )" "none $rigBefore"

echo "-- 4. the template of the console holds the guard of a bare start, and the help pair gives the form --"
rigTemplate="${rigHere}/manager/AgentsConsoleShellScript.template.sh"
rigAssert "a bare start names no member in the template, and any other start without one is still the coordinator's" \
	"$( LC_ALL=C grep -c -F 'if [ "${MDAT_SPAWN_BARE:-}" = "true" ] ; then' "$rigTemplate" ) $( LC_ALL=C grep -c -F ': "${MDAT_SPAWN_AGENT:=magic-coordinator}"' "$rigTemplate" )" "2 1"
rigAssert "ONE function starts the console for every spawn: no other line of the package launches it non-interactively (a member's spawn, its retry, both resumes), the proxy calls the function seven times (and loads it once), the harness resume twice, and this operation once" \
	"$( LC_ALL=C grep -r -h -v '^[[:space:]]*#' --include='*.include' "$rigHere" | LC_ALL=C grep -c 'DistroAgentsConsole.sh" .*--non-interactive' ) $( LC_ALL=C grep -c 'AgentsToolsSpawnConsoleLaunch ' "$rigHere/session/AgentsTools.InternOpAgentSpawnProxy.include" ) $( LC_ALL=C grep -c 'AgentsToolsSpawnConsoleLaunch ' "$rigHere/harness/AgentsTools.HarnessResume.include" ) $( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/manager/AgentsTools.ManagerSpawnAgent.include" | LC_ALL=C grep -c 'AgentsToolsSpawnConsoleLaunch --\?' )" "1 8 3 1"
rigSyntax="--manager-spawn-agent [--cli-service <cli-name>] [--goal <text>] [--from-stdin|--from-file <path>]"
rigAssert "the help pair holds the form, in the include and in the markdown, once each as a line and once as an entry" \
	"$( LC_ALL=C grep -c -F -- "$rigSyntax" "$rigHere/help/Help.DistroAgentsTools.include" ) $( LC_ALL=C grep -c -F -- "$rigSyntax" "$rigHere/help/Help.DistroAgentsTools.help.md" )" "1 2"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MANAGER SPAWN AGENT CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_SPAWN_AGENT: OK (%d assertions, offline, stand-in console)\n' "$rigPasses"
