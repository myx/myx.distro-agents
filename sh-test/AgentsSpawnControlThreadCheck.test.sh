#!/usr/bin/env bash
## Behavioural check on how the spawner starts the control thread of a session (--intern-session-control), run
## rather than read: through the real spawn proxy and the real start of a session on a stand-in console, with the
## real thread. The supervising shell of a start that is not waited for starts the thread of its session, by the
## one function every starter of a thread calls (AgentsToolsSessionControlStart,
## sh-lib/AgentsTools.SessionControlStart.include), once the folder of the session and the record of the run exist.
## Held:
##   1. A LONE RUN, started from a bare console, opens a session and has a control thread: one process, shown by
##      the tooling script, its operation and its session, in a process group of its own, the pid file of the
##      session naming it, and one start in the log of the thread. WHAT THE SPAWN PRINTS IS AS BEFORE: its eight
##      lines and no line more, and nothing of the thread on its stderr. THE THREAD IS NO RUN: the record of the
##      member names it nowhere, and the list of sessions counts one run and shows the thread alive. That its
##      environment holds no name of a member's session is held where the one function is
##      (AgentsSessionControlStartCheck): no process of this host shows its environment to this check.
##   2. A MEMBER THAT JOINS a session whose thread lives starts nothing: the pid file is as it was, one thread, one
##      start in its log, and no warning in the run's log.
##   3. A MEMBER THAT JOINS A SESSION WHOSE THREAD IS GONE starts it again, by the same call: another process holds
##      the session, and the log holds the second start.
##   4. A THREAD THAT CANNOT BE STARTED is one warning line in the run's log, and the member starts all the same:
##      its console runs and the spawn printed `STATUS=started`. Once the thread can be started, the next member
##      that joins starts it.
##   5. A START ITS CALLER WAITS ON GETS NONE: no control folder and no thread for the session it opens; nor for a
##      member that joins that session without a wait.
##   6. THE START OF A SESSION WITH THREE MEMBERS, --magic-spawn-session: one thread, started once.
##   7. THE THREAD OUTLIVES ITS STARTER: the process group of the caller is ended with TERM and KILL, and the
##      thread and the run go on.
##   8. THE THREAD OF A LONE RUN ENDS WHEN THAT RUN ENDS IN ORDER: the run hands back and ends, its supervising
##      shell closes the record, the session reads finished, and no thread, pid file or lock is left.
##   9. THE SPAWN DOES NOT WAIT FOR THE THREAD, by where the start stands: in the shell that supervises the run,
##      after the call has been handed off, and nowhere in the branch of a start its caller waits on.
## Red before the spawner started a thread: every assertion but the controls and the starts that get none.
## Offline: a fake `curl` first on PATH answers as Slack and opens no socket. A ps beside it answers the whole-host
## listing from the rig's own list, which holds no line, so a run of this rig is the process its record names, and
## hands every other call to the real ps. The console is a stand-in, never a real CLI. Every thread this check
## starts is ended by it, through the rig's fixture, and every signal goes through the rig's process helper.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigLib="$rigPackage/sh-lib"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$rigLib/AgentsUniversalHarness.sh"
rigFixture="$rigPackage/sh-test/check-fixtures/slack-send-identity-check.curl.stub.sh"
rigHelper="$rigPackage/sh-test/check-fixtures/rig-processes.include.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigFixture" ] || rigRefuse "the fake curl fixture is missing: $rigFixture"
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is
## still that process; the control threads the spawns of this rig start are ended the same way, at the end.
. "$rigHelper" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
rigTmp="$( mktemp -d -t AgentsSpawnControlThreadCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigTag="${rigTmp##*.}" ; rigTag="$( printf '%s' "$rigTag" | LC_ALL=C tr -c -d 'A-Za-z0-9' )"
[ -n "$rigTag" ] || rigRefuse "the rig has no name of its own to tell its sessions by"
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data"
rigSp="$rigWs/.local/agents/spawned" ; rigStores="$rigWs/.local/agents/sessions"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigSp" "$rigStores" "$rigHome" "$rigSkills" "$rigData/board/running" "$rigData/board/review"
rigHost="$( hostname -s 2> /dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"
rigKept="" ; rigCallerPid="" ; rigSessions=""
## At the end every stand-in console still waiting is let go, so that no supervising shell of this rig waits on
## it; then what is left of this rig's own processes is ended, and the control threads its spawns started.
rigLetAllGo(){
	local cleanDir
	for cleanDir in "$rigTmp"/*/ ; do
		[ -e "${cleanDir}launches" ] || continue
		: > "${cleanDir}release"
	done 2> /dev/null
	[ -z "$rigCallerPid" ] || rigProcGroupSignal KILL "$rigCallerPid"
	rigProcSignalKept KILL "$rigTmp"/*/*.began
	rigProcSignal KILL $rigKept
}
trap 'rigLetAllGo ; chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT

## THE RIG'S OWN PROCESS LIST, as AgentsSpawnEndNoticeCheck keeps it: the ps first on PATH answers the whole-host
## listing from the rig's own list, which holds the one stand-in of the session that requests runs; the listing of
## pid and ppid, and every other call, is handed to the real ps.
ln -s "$( command -v ps )" "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
: > "$rigTmp/ps.list"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*)
		case "$*" in *ppid=*|*pgid=*) exec "${0%/*}/ps.real" "$@" ;; esac
		case "$*" in
			*pid=*) cat "${0%/*}/../ps.list" 2> /dev/null ;;
			*) sed 's/^[^ ]* //' "${0%/*}/../ps.list" 2> /dev/null ;;
		esac
		exit 0
	;;
esac
exec "${0%/*}/ps.real" "$@"
RIGPS
cp "$rigFixture" "$rigTmp/bin/curl.fixture" || rigRefuse "could not install the fake curl"
cat > "$rigTmp/bin/curl" <<'RIGCURL'
#!/bin/sh
"${0%/*}/curl.fixture" "$@" | sed "s/1\\.000001/$( date +%s ).$( printf '%06d' "$$" )/g"
RIGCURL
chmod +x "$rigTmp/bin/ps" "$rigTmp/bin/curl" "$rigTmp/bin/curl.fixture"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v ps )" = "$rigTmp/bin/ps" ] && [ "$( command -v curl )" = "$rigTmp/bin/curl" ] \
	|| rigRefuse "the rig's own ps and curl are not first on PATH, so this check would read the host's process list or issue a real request"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSESSION_CONTROL_TICK_SECONDS=1\n' > "$rigWs/.local/.agents/magic-team.agent.env"
for rigMember in rig-member-a rig-member-b rig-member-c magic-coordinator human-owner magic-team ; do
	mkdir -p "$rigSkills/$rigMember"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
	printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
done
## The routine a coworking session names by default, and one whose executors are the three members of scene 6.
printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator, magic-librarian\ninvitees: magic-team\ndefault-for-session-kind: coworking\n---\n# rig coworking routine fixture\n' \
	> "$rigSkills/magic-team/magic-team.coworking.routine.md"
printf -- '---\nexecutors: rig-member-a, rig-member-b, rig-member-c\nmaintainers: rig-member-a\n---\n# rig routine fixture of three executors\n' \
	> "$rigSkills/rig-member-a/rig-member-a.trio.routine.md"

## The stand-in console of the proxy's own runs. A launch notes which run it is, with the record of that run, and
## itself, its pid and when it began. It runs until its scenario lets it go (the file release). Where its scenario
## says so (the file handback, which holds the argument object of the call) its first launch hands back before
## it ends, as a member does: the call itself, served by the tooling as the run's own member. Else it leaves the
## harness's line of that call in its output, so that the close does not resume it.
printf '%s\n' '#!/usr/bin/env bash' \
	'## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli) -- the stand-in of a console and its CLI' \
	'cat > /dev/null' \
	'rigLaunch=first ; [ -z "${MDAT_SPAWN_RESUME:-}" ] || rigLaunch=retry' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' \
	'printf "%s %s %s\n" "$rigLaunch" "$MDAT_SPAWN_SESSION_ID" "$MDAT_SPAWN_SANDBOX_ROOT/$MDAT_SPAWN_SESSION_ID.md" >> "$RIG_SCENARIO/launches"' \
	". '$rigHelper' 2> /dev/null && rigProcNoteFile \"\$RIG_SCENARIO/\$rigLaunch.\$MDAT_SPAWN_SESSION_ID.began\" \$\$" \
	'rigLeft=150' \
	'while [ "$rigLeft" -gt 0 ] && [ ! -e "$RIG_SCENARIO/release" ] ; do sleep 1 ; rigLeft=$(( rigLeft - 1 )) ; done' \
	'printf "📦 SubagentHandback\n"' \
	'if [ -s "$RIG_SCENARIO/handback" ] && [ "$rigLaunch" = first ] ; then' \
	"	MDAT_SPAWN_AGENT=rig-member-a bash '$rigHarness' --intern-tool SubagentHandback < \"\$RIG_SCENARIO/handback\" > \"\$RIG_SCENARIO/handback.out\" 2>&1" \
	'fi' \
	'exit 0' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigWaitFor(){ ## seconds, test command...
	local waitLeft=$(( $1 * 5 )) ; shift
	while ! "$@" && [ "$waitLeft" -gt 0 ] ; do sleep 0.2 ; waitLeft=$(( waitLeft - 1 )) ; done
	"$@"
}
rigHeader(){ ## record file, header name -- its value in the record's own frontmatter
	LC_ALL=C awk -v wantName="$2: " '
		$0 == "---" { if ( ++fenceCount > 1 ) { exit ; } next ; }
		fenceCount == 1 && index( $0, wantName ) == 1 { print substr( $0, length( wantName ) + 1 ) ; exit ; }
	' "$1" 2> /dev/null
}
## One call of the tooling in the rig workspace: as a bare console makes it, or, with NAME=value words ahead of the
## command, as the session those words name. The hangup, the interrupt and the quit at their defaults, as a
## console has them, whatever this check itself was started with.
rigEnv(){ ## scenario folder, NAME=value words, then the command...
	local envDir="$1" envWords=()
	shift
	while [ $# -gt 0 ] ; do
		case "$1" in *=*) envWords[${#envWords[@]}]="$1" ; shift ;; *) break ;; esac
	done
	env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" RIG_SCENARIO="$envDir" \
		${envWords[@]+"${envWords[@]}"} \
		perl -e '$SIG{HUP} = "DEFAULT" ; $SIG{INT} = "DEFAULT" ; $SIG{QUIT} = "DEFAULT" ; exec { $ARGV[0] } @ARGV or exit 127' "$@"
}
## THE THREAD OF A SESSION, read as the list of sessions reads it and as the host shows it.
rigHolder(){ ## session id -- the pid its pid file names, where that is a process that began when the file says
	local holderLine=""
	{ IFS= read -r holderLine < "$rigStores/$1/control/pid" ; } 2> /dev/null
	[ -n "$holderLine" ] && [ "$( rigProcBegan "${holderLine%% *}" )" = "$holderLine" ] || return 0
	printf '%s' "${holderLine%% *}"
}
rigHeld(){ [ -n "$( rigHolder "$1" )" ] ; } ## session id -- a live thread holds it
## A thread is the first process of a group of its own. What it starts while it reads, a shell for a pipe, shows by
## the same command line for a moment and is no thread: only the first process of a group is counted.
rigThreads(){ ## session id -- how many processes of this host show as the thread of that session
	"$rigTmp/bin/ps.real" -A -ww -o pid=,pgid=,args= 2> /dev/null | LC_ALL=C awk '$1 == $2' | LC_ALL=C grep -c -E -- "DistroAgentsTools\\.fn\\.sh --intern-session-control --run --session-id $1\$" || :
}
rigArgs(){ "$rigTmp/bin/ps.real" -ww -o args= -p "$1" 2> /dev/null ; } ## pid -- its command line
rigGroup(){ "$rigTmp/bin/ps.real" -o pgid= -p "$1" 2> /dev/null | LC_ALL=C tr -d ' ' ; } ## pid -- the process group it is in
rigMade(){ ## session id -- how many starts the log of its thread holds
	[ -f "$rigStores/$1/control/log" ] || { printf '0\n' ; return 0 ; }
	LC_ALL=C grep -c -E -- "^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z a start of the control thread of session $1 is made: pid [0-9]+, begun [^ ]+\$" "$rigStores/$1/control/log" 2> /dev/null || :
}
rigState(){ LC_ALL=C sed -n 's/^state: //p' "$rigStores/$1/control/state" 2> /dev/null | LC_ALL=C sed -n '1p' ; } ## session id
rigStateIs(){ [ "$( rigState "$1" )" = "$2" ] ; } ## session id, word
rigEnded(){ ## pid -- it is no process any more, collected by its starter or not
	case "$( "$rigTmp/bin/ps.real" -o stat= -p "$1" 2> /dev/null )" in ''|*Z*) return 0 ;; esac
	return 1
}
rigNoThread(){ [ "$( rigThreads "$1" )" = "0" ] ; } ## session id
rigListed(){ ## session id -- how the list of sessions shows it: its number of runs, their count by state, and its thread
	( cd "$rigWs" && rigEnv "$rigTmp" bash "$rigTool" --manager-session-list ) 2> /dev/null \
		| LC_ALL=C awk -F'\t' -v wantId="$1" '$1 == "session" && $2 == wantId { print $7 ":" $8 ":" $11 }'
}
rigWarned(){ ## log file -- how many of its lines warn of a control thread
	LC_ALL=C grep -c -F 'WARNING: the control thread of session ' "$1" 2> /dev/null || :
}

## Waits for the console of the run the last call started; sets rigRun, the run's own id, rigSession, the session
## the call printed, rigLog, the run's log, rigRecord, its record, and rigConsole, the note of its console.
rigRunStarted(){ ## scenario
	rigLog="$( LC_ALL=C sed -n 's/^OUTPUT_FILE=//p' "$rigDir/proxy.out" 2> /dev/null | LC_ALL=C sed -n '1p' )"
	rigSession="$( LC_ALL=C sed -n 's/^SESSION_ID=//p' "$rigDir/proxy.out" 2> /dev/null | LC_ALL=C sed -n '1p' )"
	[ -n "$rigLog" ] && [ -n "$rigSession" ] || rigRefuse "the spawn of scenario $1 printed no session or no log: $( LC_ALL=C grep -h -m1 ERROR "$rigDir/proxy.out" "$rigDir/proxy.err" 2> /dev/null | LC_ALL=C grep -v -F 'SystemContext.SetInputSpec' | head -1 )"
	rigRun="$( basename "$( dirname "$rigLog" )" )"
	rigWaitFor 60 test -s "$rigDir/first.$rigRun.began" || rigRefuse "the stand-in console never started in scenario $1: $( LC_ALL=C grep -h -m1 ERROR "$rigDir/proxy.out" "$rigDir/proxy.err" "$rigLog" 2> /dev/null | LC_ALL=C grep -v -F 'SystemContext.SetInputSpec' | head -1 )"
	rigRecord="$( LC_ALL=C awk -v wantRun="$rigRun" '$2 == wantRun { print $3 ; exit }' "$rigDir/launches" )"
	rigConsole="$( LC_ALL=C sed -n '1p' "$rigDir/first.$rigRun.began" )"
	rigWaitFor 20 rigRunKept || rigRefuse "the proxy kept no process on the record of its run in scenario $1"
	rigSessions="$rigSessions $rigSession"
}
rigRunKept(){ [ -n "$( rigHeader "$rigRecord" run-process )" ] ; }
## One run that is not waited for, on a dispatch item of its own: as the session the words name, or as a bare
## console where none is given. Its stdout and its stderr are kept apart.
rigStart(){ ## scenario, NAME=value words and options of the proxy...
	local startName="$1" startWords=() startOptions=()
	shift
	while [ $# -gt 0 ] ; do
		case "$1" in MDAT_*=*) startWords[${#startWords[@]}]="$1" ;; *) startOptions[${#startOptions[@]}]="$1" ;; esac
		shift
	done
	rigDir="$rigTmp/$startName"
	mkdir -p "$rigDir"
	( cd "$rigWs" && rigEnv "$rigDir" ${startWords[@]+"${startWords[@]}"} bash "$rigTool" --intern-op-agent-spawn-proxy rig-member-a --dispatch-doc:create \
		${startOptions[@]+"${startOptions[@]}"} --context rig-control-thread <<< "RIG-BRIEF" > "$rigDir/proxy.out" 2> "$rigDir/proxy.err" )
	rigRunStarted "$startName"
}
rigRecordClosed(){ case "$( rigHeader "$rigRecord" status )" in spawn-started|'') return 1 ;; esac ; }

echo "-- 1. a lone run from a bare console has a control thread, and the spawn prints what it printed --"
rigStart lone
rigLone="$rigSession" ; rigLoneRecord="$rigRecord" ; rigLoneDir="$rigDir"
rigAssert "control: a run started from a bare console opens a session of its own, whose id is the run's" "$( [ "$rigLone" = "$rigRun" ] && echo own-session ):$( rigHeader "$rigRecord" session-id )" "own-session:$rigRun"
rigAssert "what the spawn prints is as before: its eight lines in their order, STATUS=started among them, and no line more" \
	"$( LC_ALL=C sed 's/=.*$//' "$rigDir/proxy.out" | LC_ALL=C tr '\n' ' ' ):$( LC_ALL=C grep -c -x -F 'STATUS=started' "$rigDir/proxy.out" )" "RECEIPT_ID SESSION_ID SESSION_THREAD DISPATCH_DOC DISPATCH_ITEM STATUS PID OUTPUT_FILE :1"
rigAssert "and its stderr says nothing of a control thread" "$( LC_ALL=C grep -c -i -F 'control thread' "$rigDir/proxy.err" )" "0"
rigWaitFor 20 rigHeld "$rigLone"
rigLoneThread="$( rigHolder "$rigLone" )"
rigAssert "a control thread runs for the session of that run: the pid file of the session names a live process, and one process shows as its thread" \
	"$( [ -n "$rigLoneThread" ] && echo held ):$( rigThreads "$rigLone" )" "held:1"
rigAssert "it shows in the process list by the tooling script, its operation and its session" \
	"$( rigArgs "${rigLoneThread:-0}" | LC_ALL=C grep -c -F -- "$rigTool --intern-session-control --run --session-id $rigLone" )" "1"
rigShellPid="$( rigHeader "$rigRecord" supervisor-process | LC_ALL=C awk '{ print $1 }' )"
rigAssert "it is in a process group of its own: not that of the shell that supervises the run, which started it, nor the one this check runs in" \
	"$( [ -n "$rigLoneThread" ] && [ "$( rigGroup "$rigLoneThread" )" = "$rigLoneThread" ] && echo own ):$( [ -n "$rigShellPid" ] && [ "$( rigGroup "${rigLoneThread:-0}" )" != "$( rigGroup "$rigShellPid" )" ] && echo apart-from-the-shell ):$( [ "$( rigGroup "${rigLoneThread:-0}" )" != "$( rigGroup "$$" )" ] && echo apart-from-the-check )" "own:apart-from-the-shell:apart-from-the-check"
rigAssert "the log of the thread holds the one start that was made, with that process" "$( rigMade "$rigLone" ):$( LC_ALL=C grep -c -F -- "is made: pid ${rigLoneThread:-none}, begun " "$rigStores/$rigLone/control/log" 2> /dev/null )" "1:1"
rigAssert "the thread is no run: the record of the member names it nowhere, and keeps its run and its supervising shell as before" \
	"$( LC_ALL=C grep -c -i -E '^(control|thread)' "$rigRecord" ):$( [ "$( rigHeader "$rigRecord" run-process )" = "$rigConsole" ] && echo console ):$( [ -n "$rigShellPid" ] && [ "$rigShellPid" != "$rigLoneThread" ] && echo shell ):$( rigHeader "$rigRecord" status )" "0:console:shell:spawn-started"
rigAssert "the list of sessions counts one run for that session, running, and shows its thread alive" "$( rigListed "$rigLone" )" "1:running=1:alive"
rigAssert "and the log of the run holds no warning of it" "$( rigWarned "$rigLog" )" "0"

echo "-- 2. a member that joins a session whose thread lives starts nothing --"
rigAsLone=( "MDAT_SPAWN_SESSION_ID=$rigLone" "MDAT_SPAWN_AGENT=rig-member-a" "MDAT_SESSION_ID=$rigLone" )
rigPidPrint="$( ls -i "$rigStores/$rigLone/control/pid" | LC_ALL=C awk '{ print $1 }' ):$( cat "$rigStores/$rigLone/control/pid" )"
rigStart join-live "${rigAsLone[@]}"
rigAssert "control: the member joined that session, as a run of its own" "$( rigHeader "$rigRecord" session-id ):$( [ "$rigRun" != "$rigLone" ] && echo another-run )" "$rigLone:another-run"
rigAssert "nothing was started: the pid file is as it was, one thread shows, and the log holds its one start" \
	"$( ls -i "$rigStores/$rigLone/control/pid" | LC_ALL=C awk '{ print $1 }' ):$( cat "$rigStores/$rigLone/control/pid" ) $( rigThreads "$rigLone" ) $( rigMade "$rigLone" )" "$rigPidPrint 1 1"
rigAssert "a thread that lives is no error: the log of the run that joined holds no warning, and the list counts two runs and one thread" "$( rigWarned "$rigLog" ):$( rigListed "$rigLone" )" "0:2:running=2:alive"

echo "-- 3. a member that joins a session whose thread is gone starts it again --"
rigProcNoteFrom "$rigStores/$rigLone/control/pid"
rigProcSignalWithChildren KILL "$rigLoneThread" ; rigWaitFor 10 rigEnded "$rigLoneThread"
rigAssert "control: the thread was ended the hard way: no process shows as it, and its pid file and its lock stand, naming a process that is gone" \
	"$( rigThreads "$rigLone" ):$( rigHolder "$rigLone" ):$( [ -f "$rigStores/$rigLone/control/pid" ] && echo pid ):$( [ -L "$rigStores/$rigLone/control/lock" ] && echo lock )" "0::pid:lock"
rigStart join-gone "${rigAsLone[@]}"
rigWaitFor 20 rigHeld "$rigLone"
rigAgain="$( rigHolder "$rigLone" )"
rigAssert "the member starts, and the thread of its session with it: another process holds the session, one thread shows, and the log holds the second start" \
	"$( [ -n "$rigAgain" ] && [ "$rigAgain" != "$rigLoneThread" ] && echo another-process ):$( rigThreads "$rigLone" ):$( rigMade "$rigLone" ):$( rigWarned "$rigLog" )" "another-process:1:2:0"

echo "-- 4. a thread that cannot be started is one warning in the run's log, and the member starts --"
## A session that requests runs, with a record and a stand-in in the rig's process list as its run: a file stands
## where the folder of its thread would be made, so the log of the thread cannot be written.
rigParent="rig-parent-$rigTag"
mkdir -p "$rigSp/$rigParent" "$rigStores/$rigParent"
printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\ntracking-name: %s\nhost: %s\nworkspace: ws\nowner: rig-member-b\nstatus: spawn-started\nstarted-at: 2026-10-13 09:00 +0300\nsession-thread: CRIGPARENT:1700000000.000100\n---\n\n# Spawn session: %s\n' \
	"$rigParent" "$rigParent" "$rigParent" "$rigHost" "$rigParent" > "$rigSp/$rigParent/$rigParent.md"
sleep 900 > /dev/null 2>&1 < /dev/null &
rigProcNote "$!" ; rigKept="$rigKept $!"
printf '%s rig-cli --session-id %s the brief\n' "$!" "$rigParent" >> "$rigTmp/ps.list"
disown "$!" 2> /dev/null || :
rigAsParent=( "MDAT_SPAWN_SESSION_ID=$rigParent" "MDAT_SPAWN_AGENT=rig-member-b" "MDAT_SESSION_ID=$rigParent" "MDAT_SESSION_THREAD=CRIGPARENT:1700000000.000100" )
: > "$rigStores/$rigParent/control"
rigStart unwritable "${rigAsParent[@]}"
rigAssert "the member starts all the same: the spawn printed STATUS=started, its console runs, and its record is open in that session" \
	"$( LC_ALL=C grep -c -x -F 'STATUS=started' "$rigDir/proxy.out" ):$( [ -n "$( rigProcBegan "${rigConsole%% *}" )" ] && echo console ):$( rigHeader "$rigRecord" session-id ):$( rigHeader "$rigRecord" status )" "1:console:$rigParent:spawn-started"
rigAssert "one line of the run's log warns that the thread of that session could not be started, and says why; no process was started for it" \
	"$( rigWarned "$rigLog" ):$( LC_ALL=C grep -c -F -- "⚠️ WARNING: the control thread of session $rigParent could not be started: the log of the thread could not be written: $rigStores/$rigParent/control/log" "$rigLog" ):$( rigThreads "$rigParent" )" "1:1:0"
rigAssert "and neither the stdout nor the stderr of the spawn says anything of it" "$( LC_ALL=C grep -c -i -F 'control thread' "$rigDir/proxy.out" "$rigDir/proxy.err" | LC_ALL=C awk -F: '{ total += $NF } END { print total + 0 }' )" "0"
rm -f "$rigStores/$rigParent/control"
rigStart writable "${rigAsParent[@]}"
rigWaitFor 20 rigHeld "$rigParent"
rigAssert "once it can be started, the next member that joins starts it: one thread holds that session, by one start, and no warning" \
	"$( [ -n "$( rigHolder "$rigParent" )" ] && echo held ):$( rigThreads "$rigParent" ):$( rigMade "$rigParent" ):$( rigWarned "$rigLog" )" "held:1:1:0"

echo "-- 5. a start its caller waits on gets none, nor does a member that joins its session --"
rigDir="$rigTmp/waited" ; mkdir -p "$rigDir"
( cd "$rigWs" && rigEnv "$rigDir" bash "$rigTool" --intern-op-agent-spawn-proxy rig-member-a --dispatch-doc:create --wait --session-new --context rig-control-thread <<< "RIG-BRIEF" > "$rigDir/proxy.out" 2> "$rigDir/proxy.err" ) &
rigWaitedCall=$!
rigWaitFor 60 test -s "$rigDir/launches" || rigRefuse "the stand-in console of the waited start never started: $( LC_ALL=C grep -h -m1 ERROR "$rigDir/proxy.err" 2> /dev/null | LC_ALL=C grep -v -F 'SystemContext.SetInputSpec' | head -1 )"
rigWaited="$( LC_ALL=C awk '{ print $2 ; exit }' "$rigDir/launches" )"
rigSessions="$rigSessions $rigWaited"
rigWaitedRecord="$( LC_ALL=C awk '{ print $3 ; exit }' "$rigDir/launches" )"
sleep 2
rigAssert "control: the start its caller waits on opened a session of its own, and its run is under way" "$( rigHeader "$rigWaitedRecord" session-id ):$( rigHeader "$rigWaitedRecord" status )" "$rigWaited:spawn-started"
rigAssert "no control thread is started for it: no process, and no control folder in the folder of its session" \
	"$( rigThreads "$rigWaited" ):$( [ -e "$rigStores/$rigWaited/control" ] && echo folder || echo none )" "0:none"
rigStart waited-join "MDAT_SPAWN_SESSION_ID=$rigWaited" "MDAT_SPAWN_AGENT=rig-member-a" "MDAT_SESSION_ID=$rigWaited"
sleep 2
rigAssert "nor by a member that joins that session without a wait: it starts, with no thread, no control folder and no warning" \
	"$( rigHeader "$rigRecord" session-id ):$( rigThreads "$rigWaited" ):$( [ -e "$rigStores/$rigWaited/control" ] && echo folder || echo none ):$( rigWarned "$rigLog" )" "$rigWaited:0:none:0"
: > "$rigTmp/waited/release" ; : > "$rigTmp/waited-join/release"
wait "$rigWaitedCall" 2> /dev/null
rigAssert "control: the waited start came back once its run ended, and closed its record" "$( LC_ALL=C grep -c -x -F 'STATUS=succeeded' "$rigTmp/waited/proxy.out" ):$( rigHeader "$rigWaitedRecord" status )" "1:spawn-succeeded"

echo "-- 6. the start of a session with three members: one thread, started once --"
rigDir="$rigTmp/trio" ; mkdir -p "$rigDir"
( cd "$rigWs" && rigEnv "$rigDir" bash "$rigTool" --magic-spawn-session --routine trio <<< "RIG-TASK-TEXT" > "$rigDir/proxy.out" 2> "$rigDir/proxy.err" )
rigTrio="$( LC_ALL=C sed -n 's/^SESSION_ID=//p' "$rigDir/proxy.out" | LC_ALL=C sed -n '1p' )"
[ -n "$rigTrio" ] || rigRefuse "the start of a session printed no session: $( LC_ALL=C grep -h -m1 ERROR "$rigDir/proxy.out" "$rigDir/proxy.err" 2> /dev/null | LC_ALL=C grep -v -F 'SystemContext.SetInputSpec' | head -1 )"
rigTrioUp(){ [ "$( ls "$rigTmp/trio"/first.*.began 2> /dev/null | LC_ALL=C grep -c . )" = "3" ] ; }
rigWaitFor 60 rigTrioUp
rigSessions="$rigSessions $rigTrio"
rigWaitFor 20 rigHeld "$rigTrio"
rigAssert "control: three members were started, each a run of that one session" \
	"$( LC_ALL=C grep -c -x -F 'MEMBERS=rig-member-a rig-member-b rig-member-c' "$rigDir/proxy.out" ):$( LC_ALL=C awk '$1 == "first" { print $3 }' "$rigDir/launches" | while IFS= read -r rigEach ; do rigHeader "$rigEach" session-id ; done | LC_ALL=C grep -c -x -F -- "$rigTrio" )" "1:3"
rigAssert "one control thread runs for the session, and its pid file stands in the folder of the session" \
	"$( rigThreads "$rigTrio" ):$( [ -n "$( rigHolder "$rigTrio" )" ] && echo held ):$( [ -f "$rigStores/$rigTrio/control/pid" ] && echo pid )" "1:held:pid"
rigAssert "it was started once: the log of the thread holds one start, and no line of a start the lock refused" \
	"$( rigMade "$rigTrio" ):$( LC_ALL=C grep -F 'ERROR' "$rigStores/$rigTrio/control/log" 2> /dev/null | LC_ALL=C grep -c -v -F 'SystemContext.SetInputSpec' )" "1:0"
rigAssert "and the list of sessions counts three runs for it, and shows its thread alive" "$( rigListed "$rigTrio" )" "3:running=3:alive"

echo "-- 7. the control thread outlives its starter --"
rigDir="$rigTmp/starter" ; mkdir -p "$rigDir"
set -m
( cd "$rigWs" && rigEnv "$rigDir" bash -c 'bash "$0" --intern-op-agent-spawn-proxy rig-member-a --dispatch-doc:create --context rig-control-thread <<< "RIG-BRIEF" ; sleep 300' "$rigTool" > "$rigDir/proxy.out" 2> "$rigDir/proxy.err" ) &
rigCallerPid=$!
set +m
rigProcNote "$rigCallerPid"
rigWaitFor 60 test -s "$rigDir/launches" || rigRefuse "the stand-in console never started in scenario starter: $( LC_ALL=C grep -h -m1 ERROR "$rigDir/proxy.out" "$rigDir/proxy.err" 2> /dev/null | LC_ALL=C grep -v -F 'SystemContext.SetInputSpec' | head -1 )"
rigRunStarted starter
rigWaitFor 20 rigHeld "$rigSession"
rigStayed="$( rigHolder "$rigSession" )"
rigAssert "control: a bare console that stays started a run, in a process group of its own, and the thread of its session runs in another" \
	"$( [ "$( rigGroup "$rigCallerPid" )" = "$rigCallerPid" ] && echo own-group ):$( [ -n "$rigStayed" ] && [ "$( rigGroup "$rigStayed" )" != "$rigCallerPid" ] && echo apart )" "own-group:apart"
{ rigProcGroupSignal TERM "$rigCallerPid" ; sleep 1 ; rigProcGroupSignal KILL "$rigCallerPid" ; wait "$rigCallerPid" ; } 2> /dev/null
rigCallerWas="$rigCallerPid" ; rigCallerPid=""
sleep 2
rigAssert "the process group of the caller is ended with TERM and KILL: the caller is gone, and the thread goes on, the same process, with the run" \
	"$( rigEnded "$rigCallerWas" && echo gone ):$( [ "$( rigHolder "$rigSession" )" = "$rigStayed" ] && echo same-thread ):$( rigThreads "$rigSession" ):$( [ -n "$( rigProcBegan "${rigConsole%% *}" )" ] && echo console )" "gone:same-thread:1:console"

echo "-- 8. the thread of a lone run ends when that run ends in order --"
rigStart ends
rigEnds="$rigSession"
rigWaitFor 20 rigHeld "$rigEnds"
rigEndsThread="$( rigHolder "$rigEnds" )"
rigAssert "control: a lone run with its thread, and the session reads running" "$( [ -n "$rigEndsThread" ] && echo held ):$( rigWaitFor 15 rigStateIs "$rigEnds" running ; rigState "$rigEnds" )" "held:running"
printf '%s\n' '{"to":"session-current","outcome":"the rig step is done"}' > "$rigDir/handback"
: > "$rigDir/release"
rigWaitFor 90 rigRecordClosed
rigAssert "the run hands back and ends, and its supervising shell closes the record" "$( rigHeader "$rigRecord" status ):$( LC_ALL=C awk '{ printf "%s ", $1 }' "$rigDir/launches" )" "spawn-succeeded:first "
rigWaitFor 30 rigStateIs "$rigEnds" finished
rigWaitFor 20 rigNoThread "$rigEnds"
rigAssert "the session reads finished, and no control thread is left: no process, no pid file and no lock" \
	"$( rigState "$rigEnds" ):$( rigThreads "$rigEnds" ):$( [ -e "$rigStores/$rigEnds/control/pid" ] && echo pid || echo no-pid ):$( [ -L "$rigStores/$rigEnds/control/lock" ] && echo lock || echo no-lock )" "finished:0:no-pid:no-lock"
rigAssert "and the list of sessions shows it finished, with no thread" "$( rigListed "$rigEnds" | LC_ALL=C sed 's/^[^:]*:[^:]*://' )" "none"

echo "-- 9. the spawn does not wait for the thread: where the start stands --"
rigCode(){ LC_ALL=C grep -n -v '^[[:space:]]*#' "$1" ; } ## file -- its lines that are no comment, numbered
rigProxy="$rigLib/AgentsTools.InternOpAgentSpawnProxy.include"
rigAt(){ rigCode "$rigProxy" | LC_ALL=C grep -F -- "$1" | LC_ALL=C sed -n "${2:-1}p" | LC_ALL=C cut -d: -f1 ; } ## fixed text, which of its lines -- the number of that line
rigCallAt="$( rigAt 'AgentsToolsSessionControlStart "$sessionId"' )"
rigAssert "the spawner calls the one function once, with the id of the session" "$( rigCode "$rigProxy" | LC_ALL=C grep -c -F 'AgentsToolsSessionControlStart "' )" "1"
rigAssert "that call stands in the shell that supervises a run that is not waited for: after the caller's job control is set for the hand-off, before the console of the run is started, and so after the whole branch of a start its caller waits on" \
	"$( [ -n "$rigCallAt" ] && [ "$rigCallAt" -gt "$( rigAt 'local spawnMonitor="$BASH_SUBSHELL:$-"' )" ] && echo after-the-hand-off ):$( [ -n "$rigCallAt" ] && [ "$rigCallAt" -lt "$( rigAt 'AgentsToolsSpawnProxyConsoleRun "$sessionId"' )" ] && echo before-the-console ):$( [ -n "$rigCallAt" ] && [ "$rigCallAt" -gt "$( rigAt 'if [ "$waitMode" = "true" ] ; then' 2 )" ] && echo not-in-the-waited-branch )" "after-the-hand-off:before-the-console:not-in-the-waited-branch"

echo "-- 10. nothing is left running, and nothing was asked of the network but the rig's own stand-in --"
rigControlThreadNotes "$rigTmp" > "$rigTmp/threads.notes" 2> /dev/null
rigLetAllGo
rigControlThreadsEnd "$rigTmp"
sleep 1
rigAssert "every thread this check started is ended: no process of this host shows as a thread of one of its sessions" \
	"$( for rigEach in $rigSessions ; do rigThreads "$rigEach" ; done | LC_ALL=C awk '{ total += $1 } END { print total + 0 }' ):$( printf '%s\n' $rigSessions | LC_ALL=C sort -u | LC_ALL=C awk 'END { print ( NR >= 6 ) ? "six-or-more-sessions" : NR }' )" "0:six-or-more-sessions"
rigAssert "control: the rig knew the threads it ended, by the starts their logs hold and by their pid files" "$( LC_ALL=C awk 'NF == 2 && ! said[$1]++ { count++ } END { print ( count >= 5 ) ? "five-or-more" : count + 0 }' "$rigTmp/threads.notes" 2> /dev/null )" "five-or-more"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SPAWN CONTROL THREAD CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_CONTROL_THREAD: OK (%d assertions, offline)\n' "$rigPasses"
