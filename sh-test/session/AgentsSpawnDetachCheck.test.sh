#!/usr/bin/env bash
## Behavioural check on backlog :229's detach half, run rather than read: a spawn made from
## inside a session (MDAT_SPAWN_SESSION_ID set) runs in its own process group, so a kill
## sent to its caller's group -- what the main loop's pass bound sends -- leaves it running,
## and a detached background spawn still records its own close when it ends. A spawn that
## does not wait is detached the same whatever started it: one started with no session id,
## as a bare console starts one, leads a process group of its own, outlives its starter,
## ignores a hangup and records its own close, and so does every member a session is started
## with by --spawn-session, from a bare console and from inside a session. The start
## turns job control on in the shell that makes it, and leaves that shell's job control as it
## found it. The poster of a detached run's tracking feed takes a hangup as its run does: it
## goes on, a line the run writes later still reaches the thread, and it ends when its run
## ends; a poster started where the hangup is not ignored still ends on it, what is open
## posted first. Two members of one --spawn-session call that close in the same moment
## both close their records. The control: a spawn its caller waits on with no parent session
## (the main loop's own pass) stays in its caller's group and dies with it, so the pass bound
## still reaches it. A fake console and a fake curl, no model, offline by construction.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"

## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
## A spawn of this rig that is not waited for starts the control thread of its session, a detached process that
## outlives this check: the rig ends it, before its tree is removed (the guard is in AgentsSessionControlStartCheck).
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSpawnDetachCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigPassPid=""
trap '[ -z "$rigPassPid" ] || rigProcGroupSignal KILL "$rigPassPid" ; rigProcSignalKept KILL "$rigTmp"/*/console.began "$rigTmp"/*/*/console.began ; chmod -R u+w -- "$rigTmp" 2>/dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin"
cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"

## The member set and the board of the scenarios that start a whole session: two members and
## a routine of the rig's own, as AgentsMagicSpawnSessionCoordinatorCheck.test.sh makes them.
rigSkills="$rigTmp/skills"
rigData="$rigTmp/data"
mkdir -p "$rigSkills/magic-team" "$rigData/board"
for rigMember in rig-member-a rig-member-b magic-coordinator ; do
	mkdir -p "$rigSkills/$rigMember"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
	printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
done
printf -- '---\nexecutors: magic-team\nmaintainers: magic-coordinator\nrequires-session-kind: standalone\n---\n# rig plain routine fixture\n' \
	> "$rigSkills/magic-team/magic-team.rigplain.routine.md"

## The console: records its own pid and process group, runs for RIG_RUN seconds as the
## "agent", or until its scenario releases it (the file `release`, in the scenario's folder
## or in its own), then says so. RIG_BY_MEMBER keeps one folder a member, for a scenario
## that starts several. RIG_HANDBACK prints the line a handback leaves, so that the run's
## close follows its end with no handback retry between them. Once its scenario tells it to
## (the file `say`), it writes one line into its run's feed, as a tool call of the run does.
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER, records its pid, sleeps.' \
	'cat > /dev/null' \
	'rigOut="$RIG_SCENARIO${RIG_BY_MEMBER:+/$MDAT_SPAWN_AGENT}"' \
	'mkdir -p "$rigOut"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' \
	'[ -z "${RIG_HANDBACK:-}" ] || printf "📦 SubagentHandback\n"' \
	'ps -o pgid= -p $$ | tr -d " " > "$rigOut/console.pgid"' \
	'echo $$ > "$rigOut/console.pid"' \
	". '$rigTest/check-fixtures/rig-processes.include.sh' 2> /dev/null && rigProcNoteFile \"\$rigOut/console.began\" \$\$" \
	'rigLeft="$RIG_RUN"' \
	'while [ "$rigLeft" -gt 0 ] && [ ! -e "$RIG_SCENARIO/release" ] && [ ! -e "$rigOut/release" ] ; do' \
	'	[ ! -e "$RIG_SCENARIO/say" ] || [ -e "$rigOut/said" ] || { printf "2030-01-01T00:00:01Z TOOL Read path=/rig/after-the-hangup.md -> ok 10B/1L 1ms\n" >> "$MMDAPP/.local/agents/sessions/$MDAT_SPAWN_SESSION_ID/feed" ; : > "$rigOut/said" ; }' \
	'	sleep 1 ; rigLeft=$(( rigLeft - 1 ))' \
	'done' \
	'echo finished > "$rigOut/console.done"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"

## awk for the one scenario that has two closes meet: the header change of a spawn record's
## close (its temp file is named mdat-session-header-ops.*) is held for RIG_CLOSE_HOLD seconds
## between that file being written and being read. Two closes begun within that time of each
## other are then both between the two steps at once, for certain and not by luck. Every
## other awk call goes straight to the real one.
rigRealAwk="$( command -v awk )" || rigRefuse "no awk on PATH"
mkdir -p "$rigTmp/held"
printf '%s\n' '#!/usr/bin/env bash' \
	'case " $* " in *"opsFile="*"mdat-session-header-ops"*) sleep "$RIG_CLOSE_HOLD" ;; esac' \
	'exec "$RIG_REAL_AWK" "$@"' > "$rigTmp/held/awk"
chmod +x "$rigTmp/held/awk"

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigWaitFor(){ ## seconds, test command...
	local waitLeft="$1" ; shift
	while ! "$@" && [ "$waitLeft" -gt 0 ] ; do sleep 1 ; waitLeft=$(( waitLeft - 1 )) ; done
	"$@"
}
rigAlive(){ kill -0 "$( cat "$rigDir${1:+/$1}/console.pid" 2>/dev/null || echo 999999 )" 2>/dev/null && printf alive || printf gone ; } ## [member]
## The process group a run's console is in, and the group this check itself runs in: that one
## is never signalled, whatever a scenario recorded.
rigGroup(){ cat "$rigDir${1:+/$1}/console.pgid" 2>/dev/null || printf none ; } ## [member]
rigOwnGroup="$( ps -o pgid= -p $$ | tr -d ' ' )"
rigPassGroup=""
## Whether the run leads a process group of its own: its console is in the group of the
## subshell the proxy started (PID= of its receipt), and that is not its starter's group.
rigLeads(){
	local leadGroup leadPid
	leadGroup="$( rigGroup )"
	leadPid="$( LC_ALL=C sed -n 's/^PID=//p' "$rigDir/proxy.out" 2>/dev/null | head -1 )"
	[ "$leadGroup" != none ] && [ "$leadGroup" = "$leadPid" ] && [ "$leadGroup" != "$rigPassGroup" ] && printf yes \
		|| printf 'no: its console is in group %s, it was started as %s, its starter is group %s' "$leadGroup" "${leadPid:-none}" "$rigPassGroup"
}
## Whether the scenario's run recorded its own close: the spawn record of the run its receipt
## names (the folder of its session log is its spawn id) says it ended as succeeded.
rigClosed(){
	local closedId
	closedId="$( LC_ALL=C sed -n 's|^OUTPUT_FILE=.*/sessions/\([^/]*\)/session\.log$|\1|p' "$rigDir/proxy.out" 2>/dev/null | head -1 )"
	[ -n "$closedId" ] && LC_ALL=C grep -q -x 'status: spawn-succeeded' "$rigWs"/.local/agents/spawned/*/"$closedId.spawn.md" 2>/dev/null && printf yes || printf no
}
rigIsClosed(){ [ "$( rigClosed )" = yes ] ; }
## How many members of the scenario's session recorded their own close: the records of the
## session its starter named, which its members share a sandbox under.
rigSessionClosed(){
	local closedSession
	closedSession="$( LC_ALL=C sed -n 's/^SESSION_ID=//p' "$rigDir/session.out" 2>/dev/null | head -1 )"
	[ -n "$closedSession" ] || { printf 0 ; return 0 ; }
	## Every spawn keeps a folder of its own (spawned/<spawn-id>/<spawn-id>.spawn.md); a member's record names its session as parent-session-id, and the session's own record is no member.
	local closedFile closedCount=0
	for closedFile in "$rigWs/.local/agents/spawned"/*/*.spawn.md ; do
		[ -f "$closedFile" ] || continue
		LC_ALL=C grep -q -x "parent-session-id: $closedSession" "$closedFile" && LC_ALL=C grep -q -x 'status: spawn-succeeded' "$closedFile" && LC_ALL=C grep -q '^owner: rig-member-' "$closedFile" && closedCount=$(( closedCount + 1 ))
	done
	printf '%s' "$closedCount"
}
rigSessionClosedAre(){ [ "$( rigSessionClosed )" = "$1" ] ; }
## The tracking channel of the rig workspace: with it a session has its tracking thread, and
## each run its feed and the poster of that feed. Only the scenarios that look at a poster
## have it on.
rigTracking(){ ## on or off
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
	[ "$1" != on ] || printf 'SLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\n' >> "$rigWs/.local/.agents/magic-team.agent.env"
}
## The copies of the proxy under the subshell it started (PID= of its receipt): the poster
## of the run's feed, and beside it, until the launch is seen, the launch poller.
rigPosters(){
	local postersLead
	postersLead="$( LC_ALL=C sed -n 's/^PID=//p' "$rigDir/proxy.out" 2>/dev/null | head -1 )"
	[ -n "$postersLead" ] || return 0
	ps -axww -o pid=,ppid=,command= | LC_ALL=C awk -v lead="$postersLead" '$2 == lead && index( $0, "--intern-op-agent-spawn-proxy" ) { print $1 }'
}
rigOnePoster(){ [ "$( rigPosters | wc -l | tr -d ' ' )" = 1 ] ; }
## Whether the line the console wrote into its run's feed was posted.
rigSaid(){ LC_ALL=C grep -q -F 'after-the-hangup' "$rigDir/bodies" 2>/dev/null ; }

## One spawn, started as "the pass": its own process group, as the main loop starts one.
## Then that group is ended the way the pass bound ends it: TERM, then KILL.
rigSpawnAndEndPass(){ ## scenario, parent session id or empty, --wait or empty, console seconds
	rigDir="$rigTmp/$1"
	mkdir -p "$rigDir"
	set -m
	( cd "$rigWs" && env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID ${2:+MDAT_SPAWN_SESSION_ID="$2"} RIG_SCENARIO="$rigDir" RIG_RUN="$4" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		bash "$rigTool" --intern-op-agent-spawn-proxy keeper-myx --dispatch-doc:none $3 --context rig-spawn-detach <<< "RIG-BRIEF" > "$rigDir/proxy.out" 2>&1 ) &
	rigPassPid=$!
	rigPassGroup="$rigPassPid"
	set +m
	rigProcNote "$rigPassPid"
	rigWaitFor 30 test -s "$rigDir/console.pid" || rigRefuse "the fake console never started in scenario $1: $( grep -m1 ERROR "$rigDir/proxy.out" )"
	sleep 1
	{ rigProcNoteFrom "$rigDir"/console.began "$rigDir"/*/console.began ; rigProcGroupSignal TERM "$rigPassPid" ; sleep 2 ; rigProcGroupSignal KILL "$rigPassPid" ; wait "$rigPassPid" ; } 2>/dev/null
	rigPassPid=""
	sleep 1
}

## One spawn that does not wait, started by a starter that stays, as the shell of a console
## stays after the command it ran, and then a hangup to the starter's group: what the closing
## of its terminal sends. The starter begins with the hangup at its default, as a console
## has it, whatever this check itself inherited: a run started by a detached member ignores
## it already, and then no hangup would end anything here.
rigSpawnAndHangUp(){ ## scenario, parent session id or empty, console seconds
	rigDir="$rigTmp/$1"
	mkdir -p "$rigDir"
	set -m
	( cd "$rigWs" && exec env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID ${2:+MDAT_SPAWN_SESSION_ID="$2"} RIG_SCENARIO="$rigDir" RIG_RUN="$3" RIG_HANDBACK=yes MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --default-signals HUP -- bash -c 'bash "$1" --intern-op-agent-spawn-proxy keeper-myx --dispatch-doc:none --context rig-spawn-detach <<< "RIG-BRIEF" > "$2/proxy.out" 2>&1 ; exec sleep 120' rig-console "$rigTool" "$rigDir" ) &
	rigPassPid=$!
	rigPassGroup="$rigPassPid"
	set +m
	rigProcNote "$rigPassPid"
	rigWaitFor 30 test -s "$rigDir/console.pid" || rigRefuse "the fake console never started in scenario $1: $( grep -m1 ERROR "$rigDir/proxy.out" )"
	sleep 1
	{ rigProcNoteFrom "$rigDir"/console.began ; rigProcGroupSignal HUP "$rigPassPid" ; sleep 1 ; kill -0 "$rigPassPid" || wait "$rigPassPid" ; } 2>/dev/null
}
## The same assertions for a run and a hangup whoever started the run: the hangup to its
## starter's group, then one to its own, and what its feed's poster does about that one.
rigHangUpAsserts(){
	local hupGroup hupPoster=""
	rigAssert "the hangup ended its starter"                "$( kill -0 "$rigPassPid" 2>/dev/null && printf alive || printf gone )" gone
	rigAssert "and did not reach the run"                    "$( rigAlive )" alive
	hupGroup="$( rigGroup )"
	case "$hupGroup" in
		none|"$rigOwnGroup"|"$rigPassGroup") ;;
		*) rigProcGroupSignal HUP "$hupGroup" ; sleep 1 ;;
	esac
	rigAssert "a hangup sent to the run's own group is ignored by it" "$( rigLeads ):$( rigAlive )" yes:alive
	rigWaitFor 10 rigOnePoster
	! rigOnePoster || hupPoster="$( rigPosters )"
	rigAssert "and by the poster of its feed, which goes on with it" "$( [ -n "$hupPoster" ] && kill -0 "$hupPoster" 2>/dev/null && printf alive || printf 'not the one poster: %s' "$( rigPosters | tr '\n' ' ' )" )" alive
	: > "$rigDir/say"
	rigWaitFor 40 rigSaid
	rigAssert "a line the run writes after the hangup still reaches its tracking thread" "$( rigSaid && printf yes || printf no )" yes
	rigProcGroupSignal KILL "$rigPassPid" ; rigPassPid=""
	: > "$rigDir/release"
	rigWaitFor 15 test -f "$rigDir/console.done"
	rigAssert "and it runs to its own end"                   "$( cat "$rigDir/console.done" 2>/dev/null )" finished
	rigWaitFor 40 rigIsClosed
	rigAssert "and records its own close"                    "$( rigClosed )" yes
	rigAssert "and its poster has ended as its run ended"    "$( [ -n "$hupPoster" ] && ! kill -0 "$hupPoster" 2>/dev/null && printf gone || printf 'still there, or never seen: %s' "${hupPoster:-none}" )" gone
}

## One spawn that does not wait, made by a caller that runs the spawner as a function in a
## shell of its own, as an interactive console does and as a script handed to the tooling's
## MCP server does: with job control on in that shell (main-on), or from a subshell of such
## a shell, which carries the flag with job control off (sub-on). What that caller's job
## control is after the call is measured, not read from its flags: a job it starts next
## leads a group of its own only with job control on. The caller's stderr is a file, so its
## job control has no terminal to hand over.
rigSpawnAsFunction(){ ## scenario, parent session id or empty, main-on or sub-on
	rigDir="$rigTmp/$1"
	mkdir -p "$rigDir"
	rigPassGroup="$rigOwnGroup"
	( cd "$rigWs" && env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID ${2:+MDAT_SPAWN_SESSION_ID="$2"} RIG_SCENARIO="$rigDir" RIG_RUN=3 RIG_HANDBACK=yes MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		bash -c '
			. "$1"
			rigCall(){
				DistroAgentsTools --intern-op-agent-spawn-proxy keeper-myx --dispatch-doc:none --context rig-spawn-detach <<< "RIG-BRIEF" > "$2/proxy.out" 2>&1
				sleep 30 &
				[ "$( ps -o pgid= -p $! | tr -d " " )" = "$!" ] && echo on > "$2/job-control.after" || echo off > "$2/job-control.after"
				kill "$!"
			}
			set -m
			case "$3" in
				main-on) rigCall "$@" ;;
				sub-on) ( rigCall "$@" ) & wait ;;
			esac
		' rig-console "$rigTool" "$rigDir" "$3" > /dev/null 2> "$rigDir/caller.err" )
	rigWaitFor 30 test -s "$rigDir/console.pid" || rigRefuse "the fake console never started in scenario $1: $( grep -m1 ERROR "$rigDir/proxy.out" )"
}

## A whole session, started as "the pass" by --spawn-session: its first member inside a
## command substitution, its second on a pipe. Then that group is ended: TERM, then KILL.
rigSessionAndEndPass(){ ## scenario, parent session id or empty, console seconds, seconds a record's close is held (optional)
	rigDir="$rigTmp/$1"
	mkdir -p "$rigDir"
	set -m
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="${4:+$rigTmp/held:}$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		${2:+MDAT_SPAWN_SESSION_ID="$2" MDAT_SPAWN_AGENT=magic-coordinator} ${4:+RIG_CLOSE_HOLD="$4" RIG_REAL_AWK="$rigRealAwk"} RIG_SCENARIO="$rigDir" RIG_RUN="$3" RIG_BY_MEMBER=yes RIG_HANDBACK=yes \
		bash "$rigTool" --spawn-session --routine rigplain rig-member-a rig-member-b <<< "RIG-TASK-TEXT" > "$rigDir/session.out" 2>&1 ) &
	rigPassPid=$!
	rigPassGroup="$rigPassPid"
	set +m
	rigProcNote "$rigPassPid"
	rigWaitFor 60 test -s "$rigDir/rig-member-b/console.pid" || rigRefuse "the fake console of the second member never started in scenario $1: $( grep -m1 ERROR "$rigDir/session.out" )"
	sleep 1
	{ rigProcNoteFrom "$rigDir"/console.began "$rigDir"/*/console.began ; rigProcGroupSignal TERM "$rigPassPid" ; sleep 2 ; rigProcGroupSignal KILL "$rigPassPid" ; wait "$rigPassPid" ; } 2>/dev/null
	rigPassPid=""
	sleep 1
}
## The same assertions for a session whoever started it: each member is asked the same.
rigSessionAsserts(){
	local sessionGroupA sessionGroupB
	sessionGroupA="$( rigGroup rig-member-a )" ; sessionGroupB="$( rigGroup rig-member-b )"
	rigAssert "the session is started with both members"    "$( LC_ALL=C grep -c -x 'MEMBERS=rig-member-a rig-member-b' "$rigDir/session.out" )" 1
	rigAssert "its first member, started inside a command substitution, is not in its starter's group" \
		"$( [ "$sessionGroupA" != none ] && [ "$sessionGroupA" != "$rigPassGroup" ] && printf own || printf 'group %s, its starter is group %s' "$sessionGroupA" "$rigPassGroup" )" own
	rigAssert "nor is its second member"                     \
		"$( [ "$sessionGroupB" != none ] && [ "$sessionGroupB" != "$rigPassGroup" ] && printf own || printf 'group %s, its starter is group %s' "$sessionGroupB" "$rigPassGroup" )" own
	rigAssert "and each of the two leads a group of its own" "$( [ "$sessionGroupA" != "$sessionGroupB" ] && printf apart || printf 'both in group %s' "$sessionGroupA" )" apart
	rigAssert "its first member survives its starter being ended"  "$( rigAlive rig-member-a )" alive
	rigAssert "and so does its second"                       "$( rigAlive rig-member-b )" alive
	## Released one after the other, the second once the first has closed its record. Two
	## members of one --spawn-session call that close in the same moment write the
	## header changes of that close through one temp file (AgentsToolsSpawnProxyCloseSandbox
	## names it by `$$`, which is the starting call's pid in both), and one record can then
	## stay as started. That is not what this check asks.
	: > "$rigDir/rig-member-a/release"
	rigWaitFor 15 test -f "$rigDir/rig-member-a/console.done" ; rigWaitFor 40 rigSessionClosedAre 1
	: > "$rigDir/rig-member-b/release"
	rigWaitFor 15 test -f "$rigDir/rig-member-b/console.done"
	rigAssert "each member runs to its own end"              "$( cat "$rigDir/rig-member-a/console.done" "$rigDir/rig-member-b/console.done" 2>/dev/null | tr '\n' ' ' )" "finished finished "
	rigWaitFor 40 rigSessionClosedAre 2
	rigAssert "and each records its own close"               "$( rigSessionClosed )" 2
}

echo "-- a spawn from inside a session, --wait --"
rigSpawnAndEndPass nested-wait parent-rig-session --wait 6
rigAssert "it survives its caller's pass being ended"   "$( rigAlive )" alive
rigWaitFor 15 test -f "$rigDir/console.done"
rigAssert "and runs to its own end"                      "$( cat "$rigDir/console.done" 2>/dev/null )" finished

echo "-- a spawn from inside a session, background --"
rigSpawnAndEndPass nested-bg parent-rig-session "" 6
rigAssert "it leads a process group of its own"         "$( rigLeads )" yes
rigAssert "it survives its caller's pass being ended"   "$( rigAlive )" alive
rigPostsAtEnd="$( LC_ALL=C grep -c '^chat.postMessage ' "$rigDir/calls" 2>/dev/null || : )"
rigWaitFor 15 test -f "$rigDir/console.done"
rigAssert "and runs to its own end"                      "$( cat "$rigDir/console.done" 2>/dev/null )" finished
rigPostsNow(){ [ "$( LC_ALL=C grep -c '^chat.postMessage ' "$rigDir/calls" 2>/dev/null || : )" -gt "${rigPostsAtEnd:-0}" ] ; }
rigWaitFor 20 rigPostsNow
rigAssert "and records its own close after the pass ended" "$( rigPostsNow && printf yes || printf no )" yes

echo "-- a spawn from a bare console, no session id at all, background: detached the same --"
rigSpawnAndEndPass bare-bg "" "" 6
rigAssert "its starter is returned to at once"          "$( LC_ALL=C grep -c -x 'STATUS=started' "$rigDir/proxy.out" )" 1
rigAssert "it leads a process group of its own"         "$( rigLeads )" yes
rigAssert "it survives its starter being ended"         "$( rigAlive )" alive
rigWaitFor 15 test -f "$rigDir/console.done"
rigAssert "and runs to its own end"                      "$( cat "$rigDir/console.done" 2>/dev/null )" finished
rigWaitFor 40 rigIsClosed
rigAssert "and records its own close after its starter ended" "$( rigClosed )" yes

echo "-- a spawn from a bare console, background, and a hangup --"
rigTracking on
rigSpawnAndHangUp bare-hup "" 90
rigHangUpAsserts

echo "-- a spawn from inside a session, background, and a hangup --"
rigSpawnAndHangUp nested-hup parent-rig-hup 90
rigHangUpAsserts

echo "-- control: a poster started where the hangup is not ignored still ends on it, what is open posted first --"
rigDir="$rigTmp/poster-hup"
mkdir -p "$rigDir" "$rigWs/.local/agents/sessions/rig-poster-hup"
( cd "$rigWs" && env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID RIG_SCENARIO="$rigDir" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
	python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --default-signals HUP -- bash -c '
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.EventTrackFeed.include"
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || { echo "RIG-GUARD: the process helper of the rig is missing from the package" >&2 ; exit 99 ; }
		rigFeed="$MMDAPP/.local/agents/sessions/rig-poster-hup/feed"
		AgentsEventTrackFeedRun rig-poster-hup keeper-myx CRIGTRACK:9.9 &
		rigPoster=$!
		rigProcNote "$rigPoster"
		printf "2030-01-01T00:00:02Z TOOL Read path=/rig/open-at-the-hangup.md -> ok 10B/1L 1ms\n" >> "$rigFeed"
		## The hangup while the line is in the open post: read from the feed, not yet sent.
		rigLeft=20 ; while [ ! -e "$rigFeed.posting" ] && [ "$rigLeft" -gt 0 ] ; do sleep 1 ; rigLeft=$(( rigLeft - 1 )) ; done
		sleep 1
		rigProcSignal HUP "$rigPoster"
		rigLeft=20 ; while kill -0 "$rigPoster" 2>/dev/null && [ "$rigLeft" -gt 0 ] ; do sleep 1 ; rigLeft=$(( rigLeft - 1 )) ; done
		kill -0 "$rigPoster" 2>/dev/null && { echo alive ; rigProcSignal KILL "$rigPoster" ; } || echo gone
	' rig-console > "$rigDir/poster.after" 2> "$rigDir/caller.err" )
rigAssert "the hangup ends it"                          "$( cat "$rigDir/poster.after" 2>/dev/null )" gone
rigAssert "and the line it held open is posted"         "$( LC_ALL=C grep -c -F 'open-at-the-hangup' "$rigDir/bodies" 2>/dev/null | awk '{ print ( $1 > 0 ) ? "yes" : "no" }' )" yes
rigTracking off

echo "-- the spawner run as a function: the caller's own job control is left as it was found --"
rigSpawnAsFunction fn-main-on parent-rig-session main-on
rigAssert "a shell of its own that had job control on still has it" "$( cat "$rigDir/job-control.after" 2>/dev/null )" on
rigAssert "and the run leads a process group of its own"  "$( rigLeads )" yes
rigSpawnAsFunction fn-sub-on "" sub-on
rigAssert "a subshell of such a shell, where it was off, has it off again" "$( cat "$rigDir/job-control.after" 2>/dev/null )" off
rigAssert "and the run leads a process group of its own"  "$( rigLeads )" yes

echo "-- a session started by --spawn-session from a bare console --"
rigSessionAndEndPass session-bare "" 90
rigSessionAsserts

echo "-- a session started by --spawn-session from inside a session --"
rigSessionAndEndPass session-nested parent-rig-session 90
rigSessionAsserts

echo "-- two members of one --spawn-session call that close in the same moment --"
rigSessionAndEndPass session-close-at-once "" 90 5
rigAssert "the session is started with both members"    "$( LC_ALL=C grep -c -x 'MEMBERS=rig-member-a rig-member-b' "$rigDir/session.out" )" 1
: > "$rigDir/release"
rigWaitFor 15 test -f "$rigDir/rig-member-a/console.done" ; rigWaitFor 15 test -f "$rigDir/rig-member-b/console.done"
rigAssert "both end in the same moment"                  "$( cat "$rigDir/rig-member-a/console.done" "$rigDir/rig-member-b/console.done" 2>/dev/null | tr '\n' ' ' )" "finished finished "
rigWaitFor 60 rigSessionClosedAre 2
rigAssert "and each closes its own record"               "$( rigSessionClosed )" 2

echo "-- control: the main loop's own pass spawn, no parent session --"
rigSpawnAndEndPass top-wait "" --wait 30
rigAssert "it dies with the pass, so the bound reaches it" "$( rigAlive )" gone
rigAssert "and never reaches its own end"                "$( [ -f "$rigDir/console.done" ] && printf finished || printf no )" no

echo "-- a run's helpers end once the shell that started them is gone: the poster of its feed, the follow of its output and the poller of its launch --"
## A starter that starts each helper and is gone at once, as a spawn proxy ended by KILL leaves them. Each helper is
## noted with when it began, read from the pids the starter printed, and ended by the one helper of sh-test at the end.
rigOrphanWs="$rigTmp/orphan-ws"
mkdir -p "$rigOrphanWs/.local/agents/sessions/rig-orphan" && : > "$rigTmp/orphan.out"
## The starter lives three seconds after starting them, the time this check takes to see both running, and is then gone.
MMDAPP="$rigOrphanWs" bash -c '. "$1/session/AgentsTools.EventTrackFeed.include" && . "$1/session/AgentsTools.SpawnSandbox.include" || exit 1
	AgentsEventTrackFeedRun rig-orphan rig-member C0RIG00001:1700000000.000001 > /dev/null 2>&1 &
	starterPids="$!"
	AgentsToolsSpawnProxyFollow "$2/orphan.out" > /dev/null 2>&1 &
	starterPids="$starterPids $!"
	## The proxy file defines its functions first; sourced with no operation, it ends at its refusal of none.
	. "$1/session/AgentsTools.InternOpAgentSpawnProxy.include" rig-no-operation > /dev/null 2>&1
	AgentsToolsSpawnProxyEventTrackLaunched C0RIG00001:1700000000.000001 rig-member "$2/orphan.never-launched" rig-cli > /dev/null 2>&1 &
	printf "%s %s\n" "$starterPids" "$!" > "$2/orphan.pids.new" && mv "$2/orphan.pids.new" "$2/orphan.pids"
	sleep 3' rig-orphan-starter "$rigHere" "$rigTmp" > /dev/null 2>&1 &
rigOrphanStarter=$!
rigWaitFor 10 test -s "$rigTmp/orphan.pids"
rigOrphanPids="$( cat "$rigTmp/orphan.pids" 2> /dev/null )"
rigProcNoteFile "$rigTmp/orphan.notes" $rigOrphanPids
rigOrphansLive(){ ## -- how many of the helpers the starter left still run
	local liveNote liveCount=0
	for liveNote in $rigOrphanPids ; do kill -0 "$liveNote" 2> /dev/null && liveCount=$(( liveCount + 1 )) ; done
	printf '%s' "$liveCount"
}
rigOrphansGone(){ [ "$( rigOrphansLive )" = 0 ] ; }
rigAssert "control: while the starter lives, its three helpers run" "$( printf '%s' "$rigOrphanPids" | wc -w | LC_ALL=C tr -d ' ' ):$( rigOrphansLive )" "3:3"
wait "$rigOrphanStarter" 2> /dev/null
rigWaitFor 15 rigOrphansGone
rigAssert "within a few seconds none is left: each saw its starter gone, and ended" "$( rigOrphansLive )" 0
rigProcSignalKept KILL "$rigTmp/orphan.notes" || :

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SPAWN DETACH CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_DETACH: OK (%d assertions, offline)\n' "$rigPasses"
