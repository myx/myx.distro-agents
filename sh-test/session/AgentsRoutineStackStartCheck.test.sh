#!/usr/bin/env bash
## Behavioural check on the routine stack a spawn records at its start (S6.27 stage 1, build order step 1):
## the frames a session starts with, one `routine-stack:` line a frame, the routine in force first, and the
## same frames shown in the session's opening post. Run rather than read: through the real spawn proxy on a
## stand-in console and a fake Slack.
## Held:
##   1. a session given a chain of three routines records three frames, the first `current` and the rest `pending`
##   2. its opening post names those three frames, in the same order
##   3. control: a session with no chain records one frame, the routine in force, `current`
##   4. control: its opening post names that one frame
##   5. the routine's own `routine-chain:` is the starting path where the dispatch names none
##   6. `--routine-chain` overrides the routine's own
##   7. a chain entry that names no routine is refused, before anything is made
##   8. a chain whose first entry is not the routine in force is refused, before anything is made
##   9. a chain with an empty entry is refused, before anything is made -- a trailing comma alike
##  10. the frames of a session are read from any record that names it, not only from one named by its id
## Red before stage 1: 1 to 6 fail (the record carries no stack, and the opening post names none), 7 and 8
## hold: they are what a later stage must not undo.
## Offline: a fake console that records the brief, and a fake curl that answers Slack; every run an `env -i` child.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigTest="$rigPackage/sh-test"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRoutineStackStartCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM

rigWs="$rigTmp/ws"
rigSkills="$rigTmp/skills"
rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigSkills/magic-team" "$rigSkills/keeper-myx" "$rigData/board/backlog"

cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

## The console the proxy launches: it records the brief and signals a launch, and runs no model.
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: it writes MDAT_SPAWN_LAUNCH_MARKER, records the brief, and hands back.' \
	'## It hands back so the proxy never starts the handback retry (AgentsToolsSpawnProxyHandbackWarn),' \
	'## a process that would outlive this check.' \
	'cat > "$RIG_SCENARIO/brief"' \
	'printf "📦 SubagentHandback\n"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"

## The member the rig spawns, and the kind routine of a single-participant routine.
printf '# rig armed\n' > "$rigSkills/keeper-myx/keeper-myx.armed.md"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/keeper-myx/keeper-myx.basic.md"
printf -- '---\nexecutors: keeper-myx\nmaintainers: keeper-myx\ninvitees: none\nrequires-session-kind: standalone\n---\n# rig standalone kind\n' \
	> "$rigSkills/magic-team/magic-team.standalone.routine.md"
## Three routines of a chain. `rig-a` is the one in force; `rig-b` declares itself the next, so a dispatch
## that names no chain still has a starting path.
rigRoutine(){ ## file name, extra frontmatter line (may be empty)
	local routineName="$1" routineExtra="${2:-}"
	{
		printf -- '---\ntype: routine\nexecutors: keeper-myx\nmaintainers: keeper-myx\ninvitees: none\nrequires-session-kind: standalone\n'
		[ -z "$routineExtra" ] || printf '%s\n' "$routineExtra"
		printf -- '---\n# %s\n\n## Steps\n\n1. **only-step**: do the thing.\n' "$routineName"
	} > "$rigSkills/magic-team/$routineName"
}
rigRoutine rig-a.routine.md ""
rigRoutine rig-b.routine.md ""
rigRoutine rig-c.routine.md ""
## `rig-d` is a routine that declares its own starting path, so a dispatch that names no chain still
## records two frames.
rigRoutine rig-d.routine.md "routine-chain: rig-d.routine.md,rig-b.routine.md"

printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_WORKSPACE_DOMAIN=rig.slack.com\n' \
	> "$rigWs/.local/.agents/magic-team.agent.env"

## One spawn from a bare command line, in its own workspace tree; prints the proxy's own output, both streams.
rigSpawn(){ ## extra --intern-op-agent-spawn-proxy arguments...
	: > "$rigTmp/brief"
	: > "$rigTmp/bodies"
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$PATH" TMPDIR="${TMPDIR:-/tmp}" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" \
		bash -c '
			case "$MMDAPP" in "$RIG_SCENARIO"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$0" --intern-op-agent-spawn-proxy keeper-myx --dispatch-doc:none --wait --context rig-routine-stack "$@"
		' "$rigTool" "$@" <<< "RIG-TASK-TEXT" 2>&1 ) || :
}
## The newest spawn record.
rigNewestRecord(){
	ls -t "$rigWs/.local/agents/spawned"/*/*.spawn.md 2> /dev/null | head -1
}
## The frames that record names, one `<routine>:<state>` a line, in the order it writes them.
rigStack(){
	local recordFile
	recordFile="$( rigNewestRecord )"
	[ -n "$recordFile" ] || return 0
	LC_ALL=C awk '$0 == "---" { n++ ; if ( n > 1 ) exit ; next } n == 1 && index( $0, "routine-stack: " ) == 1 { print substr( $0, 16 ) }' "$recordFile"
}
## The stack line of the opening post the last spawn posted, as the body carries it, or none.
rigPostStack(){
	LC_ALL=C grep -o 'Routines: [^"\\]*' "$rigTmp/bodies" 2> /dev/null | head -1
}

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigJoined(){ ## text -- the lines of it, joined by |, for one assertion line
	printf '%s' "$1" | LC_ALL=C awk 'BEGIN { ORS = "" } { print ( NR > 1 ? "|" : "" ) $0 }'
}

echo "-- a chain of three: three frames, the first current --"
rigOut="$( rigSpawn --routine rig-a.routine.md --routine-chain "rig-a.routine.md,rig-b.routine.md,rig-c.routine.md" )"
grep -q 'RIG-TASK-TEXT' "$rigTmp/brief" 2> /dev/null || rigRefuse "the fake console never received the context, so nothing below would be measured: $( printf '%s\n' "$rigOut" | grep ERROR | head -1 )"
rigAssert "the spawn launched" "$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=true$' )" 1
rigAssert "three frames are recorded, the first current and the rest pending" \
	"$( rigJoined "$( rigStack )" )" "rig-a.routine.md:current|rig-b.routine.md:pending|rig-c.routine.md:pending"
rigAssert "the opening post names the same three frames" \
	"$( rigPostStack )" "Routines: rig-a.routine.md:current → rig-b.routine.md:pending → rig-c.routine.md:pending"

echo "-- control: no chain, one frame --"
rigOut="$( rigSpawn --routine rig-a.routine.md )"
rigAssert "the spawn launched" "$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=true$' )" 1
rigAssert "one frame is recorded: the routine in force, current" "$( rigJoined "$( rigStack )" )" "rig-a.routine.md:current"
rigAssert "the opening post names that one frame" "$( rigPostStack )" "Routines: rig-a.routine.md:current"

echo "-- the routine's own routine-chain is the starting path --"
rigOut="$( rigSpawn --routine rig-d.routine.md )"
rigAssert "the routine's own declared successor is the second frame" "$( rigJoined "$( rigStack )" )" "rig-d.routine.md:current|rig-b.routine.md:pending"
rigAssert "and the opening post names both frames" "$( rigPostStack )" "Routines: rig-d.routine.md:current → rig-b.routine.md:pending"

echo "-- a dispatched chain overrides the routine's own --"
rigOut="$( rigSpawn --routine rig-a.routine.md --routine-chain "rig-a.routine.md,rig-c.routine.md" )"
rigAssert "the dispatched chain wins over the routine's own" "$( rigJoined "$( rigStack )" )" "rig-a.routine.md:current|rig-c.routine.md:pending"

echo "-- a chain entry that names no routine: refused, nothing made --"
rigRecordsBefore="$( ls "$rigWs/.local/agents/spawned"/*/*.spawn.md 2> /dev/null | LC_ALL=C grep -c . || : )"
rigOut="$( rigSpawn --routine rig-a.routine.md --routine-chain "rig-a.routine.md,rig-nowhere.routine.md" )"
rigAssert "is refused, naming the entry" "$( printf '%s\n' "$rigOut" | grep -c 'rig-nowhere.routine.md is not one routine file of the skillset' )" 1
rigAssert "and nothing launched" "$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=' )" 0
rigAssert "and no record was made for it" "$( ls "$rigWs/.local/agents/spawned"/*/*.spawn.md 2> /dev/null | LC_ALL=C grep -c . || : )" "${rigRecordsBefore:-0}"

echo "-- a chain that begins elsewhere than the routine in force: refused --"
rigOut="$( rigSpawn --routine rig-a.routine.md --routine-chain "rig-c.routine.md,rig-b.routine.md" )"
rigAssert "is refused, naming both routines" "$( printf '%s\n' "$rigOut" | grep -c 'a chain begins with the routine in force' )" 1
rigAssert "and nothing launched" "$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=' )" 0

echo "-- a chain with an empty entry: refused, nothing made --"
## The help says an entry that names no routine refuses the spawn, and an empty entry is the one case a
## word-split would silently drop: the chain would lose a frame and no one would know.
rigRecordsBefore="$( ls "$rigWs/.local/agents/spawned"/*/*.spawn.md 2> /dev/null | LC_ALL=C grep -c . || : )"
rigOut="$( rigSpawn --routine rig-a.routine.md --routine-chain "rig-a.routine.md,,rig-b.routine.md" )"
rigAssert "is refused, naming the empty entry" "$( printf '%s\n' "$rigOut" | grep -c 'the chain holds an empty entry' )" 1
rigAssert "and nothing launched" "$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=' )" 0
rigAssert "and no record was made for it" "$( ls "$rigWs/.local/agents/spawned"/*/*.spawn.md 2> /dev/null | LC_ALL=C grep -c . || : )" "${rigRecordsBefore:-0}"
rigOut="$( rigSpawn --routine rig-a.routine.md --routine-chain "rig-a.routine.md," )"
rigAssert "and a trailing comma is the same empty entry, refused the same way" "$( printf '%s\n' "$rigOut" | grep -c 'the chain holds an empty entry' )" 1

echo "-- a session whose own record is absent keeps the frames its other records hold --"
## THE SESSION'S FRAMES ARE THE SESSION'S, not the record's named by its id (S6.27, gap 4): 11 sessions of the estate hold
## records whose `session-id:` names them while no `<session-id>.spawn.md` stands there. Read from the record named by the id
## alone, such a session comes back with nothing, and a run joining it writes its own frames over the session's silently.
## Read in a child of the rig's own workspace: the reader takes MMDAPP as the tree to look in, and this check's own shell
## runs against the live workspace.
rigStackSession="rig-session-gap4"
mkdir -p "$rigWs/.local/agents/spawned/rig-joining-run"
printf -- '---\nsession-id: %s\nspawn-id: rig-joining-run\nstatus: spawn-started\nroutine-stack: rig-a.routine.md:current\nroutine-stack: rig-b.routine.md:pending\n---\n\n# rig joining run\n' \
	"$rigStackSession" > "$rigWs/.local/agents/spawned/rig-joining-run/rig-joining-run.spawn.md"
rigAssert "the frames of a session are read from the record that names it, not only from one named by its id" \
	"$( env -i HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		bash -c '. "$1" ; AgentsToolsSessionRoutineStackLines "$2"' rig "$rigPackage/sh-lib/session/AgentsTools.RoutineStack.include" "$rigStackSession" 2> /dev/null \
		| LC_ALL=C tr '\n' '|' )" \
	"routine-stack: rig-a.routine.md:current|routine-stack: rig-b.routine.md:pending|"

## THE RIG'S OWN PROCESSES ARE BACK BEFORE THIS CHECK ENDS. A spawn's close, and the
## tracking post it sends, finish after the proxy's call has returned, so for a few seconds
## the rig's own proxy still runs. That is the tooling closing a run, not a leak of this
## check's, and a runner that watches for left processes cannot tell the two apart. So the
## check waits them out, bounded, and asserts that it did.
rigSettle(){ ## -- rc 0 once no process of this rig is left, rc 1 at the bound
	local settleLeft=60
	while [ "$settleLeft" -gt 0 ] ; do
		[ "$( ps -A -ww -o args= 2>/dev/null | LC_ALL=C awk '/rig-routine-stack/ && !/awk/ { n++ } END { print n + 0 }' )" != "0" ] || return 0
		sleep 1 ; settleLeft=$(( settleLeft - 1 ))
	done
	return 1
}
if rigSettle ; then rigSettled="clean" ; else rigSettled="left-running" ; fi
rigAssert "no process of this check is left running when it ends" "$rigSettled" clean

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROUTINE STACK START CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	printf 'ROUTINE_STACK_START: FAILED (%d compared, %d assertion(s))\n' "$(( rigPassCount + rigFailCount ))" "$rigFailCount"
	exit 1
fi
printf 'ROUTINE_STACK_START: OK (%d assertions, offline)\n' "$rigPassCount"
