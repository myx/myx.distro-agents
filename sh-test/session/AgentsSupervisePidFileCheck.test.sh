#!/usr/bin/env bash
## Behavioural check on the two supervisor readings that name a process of a rig (board task 20261106T1031Z, S5.2 and S12.15;
## `AgentsToolsSuperviseScan` in AgentsTools.SuperviseScan.include). Both decide from a `control/pid` file, and the file's real shape
## is `<pid> <rest of the line>`: a reader that took the whole line for the number, or that read a file of another shape, would report
## nobody. Held, run rather than read, each row with the control that the same rig reports nothing while its process is gone:
##   1. `rig-orphan` NAMES A CONTROL THREAD STILL ALIVE inside a run's own output folder after that run's record closed.
##   2. IT IS QUIET WHILE NOTHING IS ALIVE, so the row is about a process and not about a file standing there.
##   3. `control-stuck` NAMES A SESSION'S CONTROL THREAD alive past the no-run limit with its log silent and no record of it open.
##   4. IT IS QUIET while a record of that session is still open, so a thread with something to watch is not called stuck.
## The real scan runs over a rig of this check's own. The control threads are sleepers, noted before their pid files are written, and
## ended through the shared helper.
## RED RECIPE, measured on a copy under this check's own scratch on 2026-11-06: read the pid file as a whole line instead of its first
## word (both `<pid> <rest>` reads, at :319 and :339) and rows 1 and 3 fail, while 2 and 4 stay quiet.
## Offline: the scan and a rig of its own.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigFn="$rigPackage/sh-scripts/AgentDispatcherTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigFn" ] || rigRefuse "the supervising tool is not at $rigFn"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSupervisePidFileCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rigProcSignal TERM "${rigCtlPidA:-0}" || : ; rigProcSignal TERM "${rigCtlPidB:-0}" || : ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigWs="$rigTmp/ws"
rigAgents="$rigWs/.local/agents"
mkdir -p "$rigAgents/spawned" "$rigAgents/sessions" || exit 1
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}
## ONE SLEEPER, and the pid file the tooling writes for it: the number first, then whatever the writer left on the line.
rigControlThread(){ ## the pid-file path, the rest of the line
	python3 -I -B -c 'import time; time.sleep(300)' > /dev/null 2>&1 &
	rigLastPid="$!" ; rigProcNote "$rigLastPid"
	mkdir -p "${1%/*}" || exit 1
	printf '%s %s\n' "$rigLastPid" "$2" > "$1"
}
## THE SCAN, over this rig's workspace, with the real tool from the package under test.
rigScan(){ ## the workspace
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" MDSC_CMD=AgentDispatcherTools \
		bash "$rigFn" --supervise-scan --workspace "$1" 2>&1
}
case "$rigPackage" in
	*/myx/myx.distro-agents) rigOrigin="${rigPackage%/myx/myx.distro-agents}" ;;
	*) rigRefuse "the package under test is not at <origin>/myx/myx.distro-agents: $rigPackage" ;;
esac

echo "-- the rig: a closed run with a control thread in its output folder, and one that was never started --"
## THE CONTROL THREAD OF A RUN'S OWN OUTPUT FOLDER, where the scan looks for one: six levels below the spawned root, which is the shape
## a run's own session folder makes (spawned/<spawn>/sessions/<run>/output/control/pid).
mkdir -p "$rigAgents/spawned/rig-closed/sessions/run-a/output/control" "$rigAgents/spawned/rig-open/output/control" || exit 1
printf -- '---\nsession-id: rig-closed\nspawn-id: rig-closed\nowner: rig-keeper\nstatus: spawn-succeeded\nstarted-at: 2026-11-06 10:00 +0000\nresolved-at: 2026-11-06 10:30 +0000\n---\n' > "$rigAgents/spawned/rig-closed/rig-closed.spawn.md"
printf -- '---\nsession-id: rig-open\nspawn-id: rig-open\nowner: rig-keeper\nstatus: spawn-started\nstarted-at: 2026-11-06 11:00 +0000\n---\n' > "$rigAgents/spawned/rig-open/rig-open.spawn.md"
rigControlThread "$rigAgents/spawned/rig-closed/sessions/run-a/output/control/pid" 'rig-control rig-closed'
rigCtlPidA="$rigLastPid"

echo "-- 1. rig-orphan names a control thread alive after its run closed --"
rigOut="$( rigScan "$rigWs" )"
rigAssert "the closed run's live control thread is reported as a rig orphan" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c "^rig-orphan ${rigWs##*/} rig-clos pid=$rigCtlPidA " )" 1
rigAssert "and the folder the run was left in is named, without the workspace prefix" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep '^rig-orphan ' | LC_ALL=C awk '{ print $NF }' )" 'sessions/run-a/output/control/pid'

echo "-- 2. and it is quiet while nothing is alive --"
rigProcSignal TERM "$rigCtlPidA" || :
sleep 1
rigAssert "no rig orphan is reported once its process is gone" "$( rigScan "$rigWs" | LC_ALL=C grep -c '^rig-orphan ' )" 0

echo "-- 3. control-stuck names a session's thread alive with nothing to watch --"
mkdir -p "$rigAgents/sessions/rig-session-x/control" || exit 1
rigControlThread "$rigAgents/sessions/rig-session-x/control/pid" 'rig-control rig-session-x'
rigCtlPidB="$rigLastPid"
touch -t "$( date -v-2H '+%Y%m%d%H%M' 2> /dev/null || date -d '2 hours ago' '+%Y%m%d%H%M' )" "$rigAgents/sessions/rig-session-x/control/log" 2> /dev/null || : > "$rigAgents/sessions/rig-session-x/control/log"
[ -e "$rigAgents/sessions/rig-session-x/control/log" ] || : > "$rigAgents/sessions/rig-session-x/control/log"
touch -t "$( date -v-2H '+%Y%m%d%H%M' 2> /dev/null || date -d '2 hours ago' '+%Y%m%d%H%M' )" "$rigAgents/sessions/rig-session-x/control/log" || exit 1
rigOut="$( rigScan "$rigWs" )"
rigAssert "the quiet control thread of a session with no record open is reported as stuck" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c "^control-stuck .* rig-session-x pid=$rigCtlPidB quiet-over=" )" 1

echo "-- 4. and it is quiet while a record of that session is open --"
printf -- '---\nsession-id: rig-session-x\nspawn-id: rig-session-x-run\nowner: rig-keeper\nstatus: spawn-started\nstarted-at: 2026-11-06 11:00 +0000\n---\n' > "$rigAgents/spawned/rig-session-x-run.spawn.md" 2> /dev/null || :
mkdir -p "$rigAgents/spawned/rig-session-x-run" || exit 1
printf -- '---\nsession-id: rig-session-x\nspawn-id: rig-session-x-run\nowner: rig-keeper\nstatus: spawn-started\nstarted-at: 2026-11-06 11:00 +0000\n---\n' > "$rigAgents/spawned/rig-session-x-run/rig-session-x-run.spawn.md"
rigAssert "a thread whose session still has an open record is not called stuck" \
	"$( rigScan "$rigWs" | LC_ALL=C grep -c '^control-stuck .* rig-session-x ' )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SUPERVISE PID FILE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'SUPERVISE_PID_FILE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
