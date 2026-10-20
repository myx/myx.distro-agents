#!/usr/bin/env bash
## Behavioural check on the supervising shell of a run as its spawn record names it, run rather than read, through
## the real spawn proxy on a stand-in console. The shell that starts a run's console stays after the launch: it
## waits on the run, resumes it once for a missing handback, posts the end and closes the record. The record names
## that shell beside the run's own process, `supervisor-process: <pid> <start>` in the form of `run-process`,
## written by the one writer of both (AgentsToolsSpawnProxyRunRecord, AgentsTools.SpawnSandbox.include), and one
## function says whether it still lives (AgentsToolsRegistryRecordedSupervisor, AgentsTools.Registries.include):
## alive, gone or unknown, one word, rc 0 for each.
## Held:
##   1. A START THAT DOES NOT WAIT. The record names the process the proxy started for the run (PID= of its
##      receipt), which started the run's own process, began when the record says and lives while the run lives. It
##      is the process that closes the record. The header stands on the closed record, and the shell, once it has
##      ended, reads gone, which is no error.
##   2. A START ITS CALLER WAITS ON. The record names the process of the waiting call itself.
##   3. THE HANDBACK RETRY. `run-process` then names the resumed process, `supervisor-process` is as it was, still
##      that process, and it started the resumed one too.
##   4. A RESTART BY THE RETURN OF A REVIEW. The new record names the supervising shell of the new run, and the old
##      record keeps its own.
##   5. THE FUNCTION, on records of the rig's own. The same pid begun at another time is another process, and one
##      that has ended and is not yet collected is none. A record with no such header, written before it was kept,
##      reads unknown and never gone, and so does one of another host, one cut short, one that names the shell in
##      no form this reads, and no file at all.
##   5b. THE WRITE OF A LAUNCH KEEPS WHAT ANOTHER WRITER CHANGED WHILE IT WROTE. A close put in place between the
##      launch's read of the record and its rename stays: the record reads closed, with the launch's process named.
##   6. --manager-session-read prints the header among the headers of a closed run.
## Red before the header was kept: every assertion of 1 to 4 and of 6 that reads it, and all of 5. Red before the
## launch compared the record before its rename: 5b, the record put back to spawn-started.
## Offline: a fake `curl` first on PATH answers as Slack and opens no socket. A ps beside it answers the whole-host
## listing from the rig's own list, which holds no line, so a run of this rig is the process its record names, and
## hands every other call, when a process began and which process started which, to the real ps. The console is a
## stand-in, never a real CLI. The board, the sandboxes and the workspace are this rig's own temp tree.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigLib="$rigPackage/sh-lib"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigFixture="$rigPackage/sh-test/check-fixtures/slack-send-identity-check.curl.stub.sh"
rigHelper="$rigPackage/sh-test/check-fixtures/rig-processes.include.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigFixture" ] || rigRefuse "the fake curl fixture is missing: $rigFixture"
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$rigHelper" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
## A spawn of this rig that is not waited for starts the control thread of its session, a detached process that
## outlives this check: the rig ends it, before its tree is removed (the guard is in AgentsSessionControlStartCheck).
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSpawnSupervisorRecordCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data"
rigSp="$rigWs/.local/agents/spawned"
mkdir -p "$rigTmp/bin" "$rigTmp/held" "$rigTmp/unit" "$rigWs/.local/.agents" "$rigSp" "$rigHome" "$rigSkills" "$rigData/board/running" "$rigData/board/review"
rigHost="$( hostname -s 2> /dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"
rigKept=""
## At the end every stand-in console still waiting is let go, with a handback, so that no supervising shell of
## this rig resumes it once more; then what is left of this rig's own processes is ended.
rigCleanup(){
	local cleanDir
	for cleanDir in "$rigTmp"/*/ ; do
		[ -e "${cleanDir}record" ] || continue
		: > "${cleanDir}handback-first" ; : > "${cleanDir}handback-retry" ; : > "${cleanDir}release-first" ; : > "${cleanDir}release-retry"
	done 2> /dev/null
	rigProcSignalKept KILL "$rigTmp"/*/first.began "$rigTmp"/*/retry.began
	rigProcSignal KILL $rigKept
	chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"
}
trap 'rigControlThreadsEnd "$rigTmp" ; rigCleanup' EXIT

## THE RIG'S OWN PROCESS LIST. The ps first on PATH answers the whole-host listing from the rig's own list, beside
## it, which holds no line: no process of the host is ever read as a run, and a run of this rig lives by the
## process its record names. The listing of pid and ppid, and every other call, is handed to the real ps.
ln -s "$( command -v ps )" "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
: > "$rigTmp/ps.list"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*)
		case "$*" in *ppid=*) exec "${0%/*}/ps.real" "$@" ;; esac
		case "$*" in
			*pid=*) cat "${0%/*}/../ps.list" 2> /dev/null ;;
			*) sed 's/^[^ ]* //' "${0%/*}/../ps.list" 2> /dev/null ;;
		esac
		exit 0
	;;
esac
exec "${0%/*}/ps.real" "$@"
RIGPS
cp "$rigFixture" "$rigTmp/bin/curl" || rigRefuse "could not install the fake curl"
## WHO CLOSES A RECORD. The awk first on the PATH of a run of this rig goes straight to the real one, and for the
## header change of a record's close (its temp file is named mdat-session-header-ops.*) first leaves, in the
## scenario's folder, the process that called it and the one that started that: the closing shell itself, or a
## command substitution of its own.
rigRealAwk="$( command -v awk )" || rigRefuse "no awk on PATH"
cat > "$rigTmp/held/awk" <<'RIGAWK'
#!/bin/sh
case " $* " in
	*"opsFile="*"mdat-session-header-ops"*)
		rigByOuter="$( "$RIG_TMP/bin/ps.real" -o ppid= -p "$PPID" 2> /dev/null | tr -d ' ' )"
		printf '%s %s\n' "$PPID" "${rigByOuter:-none}" >> "$RIG_SCENARIO/closed.by" 2> /dev/null
	;;
esac
exec "$RIG_REAL_AWK" "$@"
RIGAWK
chmod +x "$rigTmp/bin/ps" "$rigTmp/bin/curl" "$rigTmp/held/awk"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v ps )" = "$rigTmp/bin/ps" ] && [ "$( command -v curl )" = "$rigTmp/bin/curl" ] \
	|| rigRefuse "the rig's own ps and curl are not first on PATH, so this check would read the host's process list or issue a real request"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
for rigMember in rig-member-a magic-coordinator ; do
	mkdir -p "$rigSkills/$rigMember"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
	printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
done

## The stand-in console of the proxy's own runs. A launch says which record it runs under and notes itself, its
## pid and when it began: the first launch of a run as `first`, one that resumes (the handback retry) as `retry`.
## It runs until its scenario lets that launch go (the file release-<launch>), and prints the line a handback
## leaves only where its scenario says so (the file handback-<launch>).
printf '%s\n' '#!/usr/bin/env bash' \
	'## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli) -- the stand-in of a console and its CLI' \
	'cat > /dev/null' \
	'rigLaunch=first ; [ -z "${MDAT_SPAWN_RESUME:-}" ] || rigLaunch=retry' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' \
	'printf "%s\n" "$MDAT_SPAWN_SANDBOX_ROOT/$MDAT_SPAWN_SESSION_ID.md" > "$RIG_SCENARIO/record"' \
	". '$rigHelper' 2> /dev/null && rigProcNoteFile \"\$RIG_SCENARIO/\$rigLaunch.began\" \$\$" \
	'rigLeft=120' \
	'while [ "$rigLeft" -gt 0 ] && [ ! -e "$RIG_SCENARIO/release-$rigLaunch" ] ; do sleep 1 ; rigLeft=$(( rigLeft - 1 )) ; done' \
	'[ ! -e "$RIG_SCENARIO/handback-$rigLaunch" ] || printf "📦 SubagentHandback\n"' \
	'echo finished > "$RIG_SCENARIO/$rigLaunch.done"' > "$rigWs/DistroAgentsConsole.sh"
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
	local waitLeft="$1" ; shift
	while ! "$@" && [ "$waitLeft" -gt 0 ] ; do sleep 1 ; waitLeft=$(( waitLeft - 1 )) ; done
	"$@"
}
rigBegan(){ ## pid -- when that process began, as one word, as a record keeps it; nothing when there is none
	LC_ALL=C "$rigTmp/bin/ps.real" -o lstart= -p "$1" 2> /dev/null | LC_ALL=C awk 'NF { $1 = $1 ; gsub( / /, "_" ) ; print ; exit ; }'
}
rigParent(){ ## pid -- the process that started it
	[ -n "$1" ] || return 0
	"$rigTmp/bin/ps.real" -o ppid= -p "$1" 2> /dev/null | LC_ALL=C tr -d ' '
}
rigIsStill(){ ## `<pid> <start>` -- whether that pid is still the process that began then
	case "$1" in *' '*) ;; *) return 1 ;; esac
	[ "$( rigBegan "${1%% *}" )" = "${1#* }" ]
}
rigHasEnded(){ ! rigIsStill "$1" ; } ## `<pid> <start>`
rigHeader(){ ## record file, header name -- its value in the record's own frontmatter
	LC_ALL=C awk -v wantName="$2: " '
		$0 == "---" { if ( ++fenceCount > 1 ) { exit ; } next ; }
		fenceCount == 1 && index( $0, wantName ) == 1 { print substr( $0, length( wantName ) + 1 ) ; exit ; }
	' "$1" 2> /dev/null
}
rigNames(){ ## record file, header name -- how many lines of the record name a process in the form `<pid> <start>` under it
	LC_ALL=C grep -c -E "^$2: [0-9]+ [^ ]+\$" "$1" 2> /dev/null || :
}
rigSame(){ ## what a header was, what it is -- as-it-was only for a value that was there and has not changed
	[ -n "$1" ] && [ "$1" = "$2" ] && printf 'as-it-was' || printf "was '%s', is '%s'" "$1" "$2"
}
## One call of the tooling in the rig workspace, as a bare console makes it: no session of its own.
rigEnv(){ ## scenario folder, command...
	local envDir="$1" ; shift
	env -i HOME="$rigHome" PATH="$rigTmp/held:$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" RIG_SCENARIO="$envDir" RIG_REAL_AWK="$rigRealAwk" "$@"
}
## What the tooling says of the supervising shell of a record, and how the asking ended: `<word> rc=<status>`.
## Whatever the asking wrote on stderr is kept, for the assertion that it wrote nothing.
: > "$rigTmp/ask.err"
rigAsk(){ ## record file
	( cd "$rigWs" && rigEnv "$rigTmp" bash -c '
		. "$1" 2> /dev/null
		askWord="$( AgentsToolsRegistryRecordedSupervisor "$2" )"
		printf "%s rc=%s" "$askWord" "$?"
	' rig-ask "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.Registries.include" "$1" 2>> "$rigTmp/ask.err" )
}
rigAskErrors(){ LC_ALL=C awk 'END { print NR + 0 }' "$rigTmp/ask.err" ; }
rigRunKept(){ [ -n "$( rigHeader "$rigRecord" run-process )" ] ; }
rigRunNames(){ [ "$( rigHeader "$rigRecord" run-process )" = "$1" ] ; } ## `<pid> <start>`
rigRecordClosed(){ case "$( rigHeader "$rigRecord" status )" in spawn-started|'') return 1 ;; esac ; }
## Waits for the scenario's console and for its launch to be kept on its record; sets rigRecord, rigShell (what the
## record names as its supervising shell), rigRunProc (as its run's process) and rigConsole (the console's own note).
rigRunStarted(){ ## scenario
	rigWaitFor 60 test -s "$rigDir/first.began" || rigRefuse "the stand-in console never started in scenario $1: $( LC_ALL=C grep -h -m1 ERROR "$rigDir"/*.out 2> /dev/null | head -1 )"
	rigRecord="$( head -1 "$rigDir/record" 2> /dev/null )"
	[ -n "$rigRecord" ] && [ -f "$rigRecord" ] || rigRefuse "the run of scenario $1 has no record"
	rigWaitFor 20 rigRunKept || rigRefuse "the proxy kept no process on the record of its run in scenario $1"
	rigShell="$( rigHeader "$rigRecord" supervisor-process )"
	rigRunProc="$( rigHeader "$rigRecord" run-process )"
	rigConsole="$( head -1 "$rigDir/first.began" )"
}
## One run that is not waited for, started as a bare console starts it.
rigStart(){ ## scenario, `handback` where its first launch leaves one (then no retry follows its end)
	rigDir="$rigTmp/$1"
	mkdir -p "$rigDir"
	[ -z "${2:-}" ] || : > "$rigDir/handback-first"
	( cd "$rigWs" && rigEnv "$rigDir" bash "$rigTool" --intern-op-agent-spawn-proxy rig-member-a --dispatch-doc:none --context rig-supervisor-record <<< "RIG-BRIEF" > "$rigDir/proxy.out" 2>&1 )
	rigRunStarted "$1"
}
## Whether a process is the shell that made the header change of the scenario's close.
rigClosedBy(){ ## pid
	[ -n "$1" ] && [ -s "$rigDir/closed.by" ] || { printf 'no: nothing says who closed it, or no process is named' ; return 0 ; }
	LC_ALL=C awk -v wantPid="$1" '$1 == wantPid || $2 == wantPid { closedHit = 1 } { closedSaid = closedSaid " [" $0 "]" } END { if ( closedHit ) { print "yes" } else { print "no: the close was made under" closedSaid } }' "$rigDir/closed.by"
}

echo "-- 1. a start that does not wait --"
rigStart nowait handback
rigAssert "the record names its supervising shell, a pid and when it began, as it names the run's own process" \
	"$( rigNames "$rigRecord" supervisor-process ):$( rigNames "$rigRecord" run-process )" "1:1"
rigAssert "it is the process the proxy started for the run, PID= of its receipt" "${rigShell%% *}" "$( LC_ALL=C sed -n 's/^PID=//p' "$rigDir/proxy.out" | head -1 )"
rigAssert "which started the process run-process names, the console itself" "$( rigParent "${rigRunProc%% *}" ):$rigRunProc" "${rigShell%% *}:$rigConsole"
rigAssert "it began when the record says, and lives while the run lives" \
	"$( rigIsStill "$rigShell" && printf itself || printf "not the process of '%s'" "$rigShell" ):$( rigIsStill "$rigConsole" && printf run-alive || printf run-gone )" "itself:run-alive"
rigAssert "the tooling says the supervising shell is alive" "$( rigAsk "$rigRecord" )" "alive rc=0"
: > "$rigDir/release-first"
rigWaitFor 60 rigRecordClosed || rigRefuse "the run of scenario nowait never closed its record"
rigAssert "the process that closes the record is the one it names" "$( rigHeader "$rigRecord" status ):$( rigClosedBy "${rigShell%% *}" )" "spawn-succeeded:yes"
rigAssert "the header stands on the closed record" "$( rigSame "$rigShell" "$( rigHeader "$rigRecord" supervisor-process )" )" "as-it-was"
rigWaitFor 60 rigHasEnded "$rigShell"
rigAssert "once that shell has ended the tooling says gone" "$( rigAsk "$rigRecord" )" "gone rc=0"
rigClosedRecord="$rigRecord" ; rigClosedShell="$rigShell"

echo "-- 2. a start its caller waits on --"
rigDir="$rigTmp/waited"
mkdir -p "$rigDir"
: > "$rigDir/handback-first"
( cd "$rigWs" && exec env -i HOME="$rigHome" PATH="$rigTmp/held:$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
	MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" RIG_SCENARIO="$rigDir" RIG_REAL_AWK="$rigRealAwk" \
	bash "$rigTool" --intern-op-agent-spawn-proxy rig-member-a --dispatch-doc:none --wait --context rig-supervisor-record <<< "RIG-BRIEF" > "$rigDir/proxy.out" 2>&1 ) &
rigCall=$!
rigProcNote "$rigCall" ; rigKept="$rigKept $rigCall"
rigRunStarted waited
rigAssert "the record of a waited run names its supervising shell too" "$( rigNames "$rigRecord" supervisor-process )" "1"
rigAssert "it is the process of the waiting call itself, which started the run's own process" "${rigShell%% *}:$( rigParent "${rigRunProc%% *}" )" "$rigCall:$rigCall"
rigAssert "and the tooling says it is alive while the run lives" "$( rigIsStill "$rigConsole" && printf run-alive || printf run-gone ):$( rigAsk "$rigRecord" )" "run-alive:alive rc=0"
: > "$rigDir/release-first"
rigCallRc=0
wait "$rigCall" 2> /dev/null || rigCallRc=$?
rigAssert "the waiting call returns as its run ends, the record closed by the process it names" \
	"$rigCallRc:$( rigHeader "$rigRecord" status ):$( rigClosedBy "${rigShell%% *}" )" "0:spawn-succeeded:yes"
rigAssert "the header stands on the closed record, and that process, ended, reads gone" \
	"$( rigSame "$rigShell" "$( rigHeader "$rigRecord" supervisor-process )" ):$( rigAsk "$rigRecord" )" "as-it-was:gone rc=0"

echo "-- 3. the handback retry --"
rigStart retry ""
[ -n "$( rigHeader "$rigRecord" session-thread )" ] || rigRefuse "the run of scenario retry has no session thread, so its end would start no handback retry"
: > "$rigDir/release-first"
rigWaitFor 90 test -s "$rigDir/retry.began" || rigRefuse "the handback retry never started its console: $( LC_ALL=C grep -h -m1 -e ERROR -e 'no handback retry' "$rigWs/.local/agents/sessions/$( basename "$rigRecord" .md )/session.log" 2> /dev/null | head -1 )"
rigRetry="$( head -1 "$rigDir/retry.began" )"
rigWaitFor 20 rigRunNames "$rigRetry"
rigAssert "the run ended with no handback and was resumed once: run-process names the resumed process, another than the first" \
	"$( rigHeader "$rigRecord" run-process ):$( [ "$rigRetry" != "$rigRunProc" ] && rigHasEnded "$rigRunProc" && printf first-gone || printf first-still )" "$rigRetry:first-gone"
rigAssert "supervisor-process is as it was" "$( rigSame "$rigShell" "$( rigHeader "$rigRecord" supervisor-process )" )" "as-it-was"
rigAssert "it is still that process, and it started the resumed one too" "$( rigIsStill "$rigShell" && printf itself || printf "not the process of '%s'" "$rigShell" ):$( rigParent "${rigRetry%% *}" )" "itself:${rigShell%% *}"
rigAssert "the record is still open while the retry runs, and the tooling says the supervising shell is alive" "$( rigHeader "$rigRecord" status ):$( rigAsk "$rigRecord" )" "spawn-started:alive rc=0"
: > "$rigDir/handback-retry" ; : > "$rigDir/release-retry"
rigWaitFor 60 rigRecordClosed || rigRefuse "the run of scenario retry never closed its record"
rigAssert "after the retry the same shell closes the record, the header still as it was" \
	"$( rigHeader "$rigRecord" status ):$( rigClosedBy "${rigShell%% *}" ):$( rigSame "$rigShell" "$( rigHeader "$rigRecord" supervisor-process )" )" "spawn-succeeded:yes:as-it-was"
rigWaitFor 60 rigHasEnded "$rigShell"
rigAssert "and, ended, it reads gone" "$( rigAsk "$rigRecord" )" "gone rc=0"

echo "-- 4. a restart by the return of a review --"
rigDir="$rigTmp/returned"
mkdir -p "$rigDir" "$rigSp/trk-rig-ret"
: > "$rigDir/handback-first"
rigOldShell="4000001 Mon_Jan_1_00:00:00_2001"
rigOldRecord="$rigSp/trk-rig-ret/rig-old-run.md"
rigItem="dispatch-20261013T0900Z-rigret"
printf -- '---\nsession-id: rig-old-run\nspawn-id: rig-old-run\nparent-spawn-id: none\ntracking-name: trk-rig-ret\nhost: %s\nowner: rig-member-a\nstatus: spawn-succeeded\nsession-thread: CEND00001:1700000000.000500\nspawns: %s\nsupervisor-process: %s\n---\n\n# Spawn session: rig-old-run\n' \
	"$rigHost" "$rigItem" "$rigOldShell" > "$rigOldRecord"
printf -- '---\ntype: dispatch\nowner: rig-member-a\nstatus: dispatch-started\nspawn-id: rig-old-run\n---\n\n# rig dispatch\n' > "$rigData/board/review/$rigItem.md"
( cd "$rigWs" && rigEnv "$rigDir" bash "$rigTool" --member-review-return magic-coordinator "$rigItem" --message "redo the rig step" > "$rigDir/return.out" 2>&1 )
LC_ALL=C grep -q "^RETURN: restarted rig-member-a on $rigItem" "$rigDir/return.out" || rigRefuse "the return of the review restarted nothing, so no new run would be measured: $( LC_ALL=C grep -m1 -e ERROR -e '^RETURN: ' "$rigDir/return.out" )"
rigRunStarted returned
rigAssert "the returned item starts its member again under a record of its own, in the same sandbox" "$( [ "$rigRecord" != "$rigOldRecord" ] && printf '%s' "${rigRecord%/*}" )" "$rigSp/trk-rig-ret"
rigAssert "the new record names the supervising shell of the new run, which started the new run's own process" \
	"$( rigNames "$rigRecord" supervisor-process ):$( rigParent "${rigRunProc%% *}" ):$( [ "$rigShell" != "$rigOldShell" ] && printf its-own || printf 'the old one' )" "1:${rigShell%% *}:its-own"
rigAssert "it lives while the new run lives, and the old record keeps its own" "$( rigAsk "$rigRecord" ):$( rigHeader "$rigOldRecord" supervisor-process )" "alive rc=0:$rigOldShell"
: > "$rigDir/release-first"
rigWaitFor 60 rigRecordClosed || rigRefuse "the run of scenario returned never closed its record"
rigAssert "the new record is closed by the shell it names, and the old record still keeps its own" \
	"$( rigClosedBy "${rigShell%% *}" ):$( rigSame "$rigShell" "$( rigHeader "$rigRecord" supervisor-process )" ):$( rigHeader "$rigOldRecord" supervisor-process )" "yes:as-it-was:$rigOldShell"

echo "-- 5. the function, on records of the rig's own --"
## A stand-in process of this rig, which only waits: the supervising shell a record of the rig names.
sleep 300 > /dev/null 2>&1 < /dev/null &
rigStandPid=$!
rigProcNote "$rigStandPid" ; rigKept="$rigKept $rigStandPid"
rigStandBegan="$( rigBegan "$rigStandPid" )"
[ -n "$rigStandBegan" ] || rigRefuse "the stand-in of section 5 never started"
rigUnit(){ ## name, the lines of its frontmatter after its ids -- a record of the rig's own, open; prints its path
	printf -- '---\nsession-id: rig-unit-%s\nspawn-id: rig-unit-%s\nowner: rig-member-a\nstatus: spawn-started\n%s\n---\n\n# Spawn session: rig-unit-%s\n' "$1" "$1" "$2" "$1" > "$rigTmp/unit/$1.md"
	printf '%s' "$rigTmp/unit/$1.md"
}
rigAssert "a record that names a process which is still that process: alive" \
	"$( rigAsk "$( rigUnit live "host: $rigHost
supervisor-process: $rigStandPid $rigStandBegan" )" )" "alive rc=0"
rigAssert "the same pid begun at another time is another process: gone" \
	"$( rigAsk "$( rigUnit taken "host: $rigHost
supervisor-process: $rigStandPid Mon_Jan_1_00:00:00_2001" )" )" "gone rc=0"
rigAssert "a record with no such header, written before it was kept, its run's process gone: unknown, never gone" \
	"$( rigAsk "$( rigUnit before "host: $rigHost
run-process: $rigStandPid Mon_Jan_1_00:00:00_2001" )" )" "unknown rc=0"
rigAssert "a record of another host, whatever process of this host has that number: unknown" \
	"$( rigAsk "$( rigUnit foreign "host: rig-other-host
supervisor-process: $rigStandPid $rigStandBegan" )" ):$( rigAsk "$( rigUnit foreign-gone "host: rig-other-host
supervisor-process: $rigStandPid Mon_Jan_1_00:00:00_2001" )" )" "unknown rc=0:unknown rc=0"
rigAssert "a record that names no host: unknown" \
	"$( rigAsk "$( rigUnit nohost "supervisor-process: $rigStandPid Mon_Jan_1_00:00:00_2001" )" )" "unknown rc=0"
rigUnit cut "host: $rigHost
supervisor-process: $rigStandPid Mon_Jan_1_00:00:00_2001" > /dev/null
LC_ALL=C sed -n '1,/^supervisor-process: /p' "$rigTmp/unit/cut.md" > "$rigTmp/unit/cut-short.md"
rigAssert "a record cut short, its frontmatter not yet whole: unknown" "$( LC_ALL=C grep -c -x -e '---' "$rigTmp/unit/cut-short.md" ):$( rigAsk "$rigTmp/unit/cut-short.md" )" "1:unknown rc=0"
rigAssert "a record that names the shell in no form this reads, a pid alone or no pid: unknown" \
	"$( rigAsk "$( rigUnit pid-alone "host: $rigHost
supervisor-process: $rigStandPid" )" ):$( rigAsk "$( rigUnit no-pid "host: $rigHost
supervisor-process: rig Mon_Jan_1_00:00:00_2001" )" ):$( rigAsk "$( rigUnit two-words "host: $rigHost
supervisor-process: $rigStandPid Mon Jan" )" )" "unknown rc=0:unknown rc=0:unknown rc=0"
rigUnit body "host: $rigHost" > /dev/null
printf 'supervisor-process: %s Mon_Jan_1_00:00:00_2001\n' "$rigStandPid" >> "$rigTmp/unit/body.md"
rigAssert "a line of that name in the text under the frontmatter is no header: unknown" "$( rigAsk "$rigTmp/unit/body.md" )" "unknown rc=0"
rigAssert "no file at all, and no name of one: unknown" "$( rigAsk "$rigTmp/unit/no-such-record.md" ):$( rigAsk "" )" "unknown rc=0:unknown rc=0"
## A process that has ended and that the process which started it has not collected yet is no process any more.
perl -e '$| = 1 ; my $kid = fork ; defined $kid or exit 1 ; if ( ! $kid ) { sleep 2 ; exit 0 } print "$kid\n" ; close STDOUT ; sleep 120' > "$rigTmp/unit/ended.pid" 2> /dev/null &
rigHolder=$!
rigProcNote "$rigHolder" ; rigKept="$rigKept $rigHolder"
rigWaitFor 10 test -s "$rigTmp/unit/ended.pid" || rigRefuse "the stand-in that ends uncollected never started"
rigEnded="$( head -1 "$rigTmp/unit/ended.pid" )"
rigEndedBegan="$( rigBegan "$rigEnded" )"
rigIsUncollected(){ case "$( "$rigTmp/bin/ps.real" -o stat= -p "$rigEnded" 2> /dev/null | LC_ALL=C tr -d ' ' )" in Z*) return 0 ;; esac ; return 1 ; }
rigWaitFor 15 rigIsUncollected
rigAssert "a process that has ended and is not yet collected by its starter is none: gone" \
	"$( rigIsUncollected && [ "$( rigBegan "$rigEnded" )" = "$rigEndedBegan" ] && printf ended-uncollected || printf not-so ):$( rigAsk "$( rigUnit uncollected "host: $rigHost
supervisor-process: $rigEnded $rigEndedBegan" )" )" "ended-uncollected:gone rc=0"
rigProcSignal KILL "$rigHolder" ; wait "$rigHolder" 2> /dev/null
rigProcSignal KILL "$rigStandPid" ; wait "$rigStandPid" 2> /dev/null
rigAssert "a process that is no more: gone" "$( rigAsk "$rigTmp/unit/live.md" )" "gone rc=0"
rigAssert "none of these answers is an error: nothing was written on stderr, in this section or in the four before it" "$( rigAskErrors )" "0"

echo "-- 5b. the write of a launch keeps what another writer changed while it wrote --"
## Another writer closes the record while the launch writes it: here, as the launch's header writer (an awk given
## its ops file) has just read the record, a stand-in that runs that awk and then puts a close in place, once, aside
## and by one rename, as every writer of a record does. The process the launch keeps is this call's own shell.
rigUnit raced "host: $rigHost" > /dev/null
( cd "$rigWs" && rigEnv "$rigTmp" bash -c '
	. "$1" 2> /dev/null ; . "$2" 2> /dev/null
	awk(){
		local awkRc=0 awkWriter=""
		case " $* " in *" opsFile="*) awkWriter="yes" ;; esac
		command awk "$@" || awkRc=$?
		if [ -n "$awkWriter" ] && [ ! -e "$RIG_TMP/unit/raced.once" ] ; then
			: > "$RIG_TMP/unit/raced.once"
			sed "s/^status: spawn-started\$/status: spawn-ended-without-close/" "$RIG_TMP/unit/raced.md" > "$RIG_TMP/unit/raced.md.rig" && mv -f "$RIG_TMP/unit/raced.md.rig" "$RIG_TMP/unit/raced.md"
		fi
		return "$awkRc"
	}
	MDAT_SPAWN_SANDBOX_ROOT="$RIG_TMP/unit" MDAT_SPAWN_SESSION_ID=raced AgentsToolsSpawnProxyRunRecord "$$"
' rig-raced "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.Registries.include" "$rigLib/session/AgentsTools.SpawnSandbox.include" 2>> "$rigTmp/ask.err" )
rigAssert "control: the close was put in place while the launch wrote, once" "$( [ -e "$rigTmp/unit/raced.once" ] && printf once || printf never )" "once"
rigAssert "the record keeps that close, and names the process the launch kept" "$( rigHeader "$rigTmp/unit/raced.md" status ) $( rigNames "$rigTmp/unit/raced.md" run-process )" "spawn-ended-without-close 1"

echo "-- 6. --manager-session-read prints the header among the headers of a closed run --"
rigClosedId="${rigClosedRecord##*/}" ; rigClosedId="${rigClosedId%.md}"
( cd "$rigWs" && rigEnv "$rigTmp" bash "$rigTool" --manager-session-read --session-id "$rigClosedId" --run > "$rigTmp/read.out" 2> "$rigTmp/read.err" < /dev/null )
[ "$( LC_ALL=C awk -F'\t' '$1 == "run" { readRuns++ } END { print readRuns + 0 }' "$rigTmp/read.out" )" = 1 ] || rigRefuse "--manager-session-read printed no run of $rigClosedId, so no header row would be measured: $( head -2 "$rigTmp/read.err" | LC_ALL=C tr '\n' ' ' )"
rigAssert "the read of that run prints its supervisor-process as the record holds it, beside its run-process" \
	"$( LC_ALL=C awk -F'\t' -v wantRun="$rigClosedId" '$1 == "header" && $2 == wantRun && ( $3 == "supervisor-process" || $3 == "run-process" ) { printf "%s=%s ", $3, ( $4 != "" ? "named" : "empty" ) ; if ( $3 == "supervisor-process" ) { shellSaid = $4 } } END { printf "/ %s", shellSaid }' "$rigTmp/read.out" )" \
	"run-process=named supervisor-process=named / $rigClosedShell"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SPAWN SUPERVISOR RECORD CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_SUPERVISOR_RECORD: OK (%d assertions, offline)\n' "$rigPasses"
