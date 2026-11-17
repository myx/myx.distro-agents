#!/usr/bin/env bash
## Behavioural check on `--supervise-close-orphans` (S5.2; AgentsTools.SuperviseClose.include), run against a rig of this check's own:
## a test rig left running is a control thread alive inside a run's output folder after that run's record closed, and the tooling
## closes it only after checking that the pid still names the process the file recorded. Held:
##   1. THE READOUT NAMES WHAT IT WOULD CLOSE and signals nothing: a matching pid reads `would-close`, a pid whose began moment is
##      not the process's own reads `kept-mismatch`, and both processes still live after.
##   2. --execute CLOSES THE MATCHING ONE, which reads `closed` and is gone, and leaves the mismatched one alive.
##   3. A SECOND --execute finds the closed one no more, and the mismatched one still kept.
##   4. A WORKSPACE WITH NOTHING TO CLOSE says `none`.
##   5. A CONTROL THREAD THAT ANSWERS NO TERM reads `still-alive` and lives, and the pass leaves a note beside its pid file
##      naming that process.
##   6. THE READOUT THEN SAYS `would-kill` for it and signals nothing, and the note is what says so.
##   7. THE NEXT --execute ENDS IT WITH KILL: it reads `killed`, its process is gone, and the note has gone with it.
##   8. A NOTE NAMING ANOTHER PROCESS IS NOT OBEYED: it is removed, the row reads `would-close`, and nothing is signalled.
##   9. A NOTE WHOSE PROCESS HAS GONE IS CLEARED by the next pass, which reads no row and signals nothing.
## Red before the operation: each call is refused as an invalid option, so 1 to 4 fail. Red before the harder signal: no pass writes a
## note and no pass sends KILL, so 5 to 8 fail, and 8's first assertion fails because the owner's note call is not there to write one.
## Red before the note sweep: a note whose process ended on its own stands for ever, so 9 fails.
## Offline: the tool from the package under test, over a rig workspace; the control threads are sleepers, ended at the end.
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
rigTmp="$( rigTempDir AgentsSuperviseCloseOrphansCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rigProcSignal TERM "${rigPidA:-0}" || : ; rigProcSignal TERM "${rigPidB:-0}" || : ; rigProcSignal KILL "${rigPidC:-0}" || : ; rigProcSignal TERM "${rigPidD:-0}" || : ; rigProcSignal KILL "${rigPidE:-0}" || : ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
case "$rigPackage" in
	*/myx/myx.distro-agents) rigOrigin="${rigPackage%/myx/myx.distro-agents}" ;;
	*) rigRefuse "the package under test is not at <origin>/myx/myx.distro-agents: $rigPackage" ;;
esac
rigWs="$rigTmp/ws"
rigEmpty="$rigTmp/empty"
rigAgents="$rigWs/.local/agents"
rigSkills="$rigTmp/skills"
rigData="$rigTmp/data"
mkdir -p "$rigAgents/spawned" "$rigAgents/sessions" "$rigEmpty/.local/agents/spawned" "$rigSkills/magic-coordinator" "$rigData" || exit 1
printf 'rig\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"
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
. "$rigPackage/sh-lib/team-data/AgentsTools.Registries.include" ; . "$rigPackage/sh-lib/run/AgentsTools.RunProcesses.include" ; . "$rigPackage/sh-lib/run/AgentsTools.RunState.include" ; . "$rigPackage/sh-lib/run/AgentsTools.RunLeft.include" ; . "$rigPackage/sh-lib/run/AgentsTools.RunRecords.include" ; . "$rigPackage/sh-lib/session/AgentsTools.SessionStore.include" ; . "$rigPackage/sh-lib/spawn/AgentsTools.SpawnSandbox.include" > /dev/null 2>&1 || rigRefuse "the registries' functions could not be sourced"
type AgentsToolsRunProcessesBegan > /dev/null 2>&1 || rigRefuse "AgentsToolsRunProcessesBegan is not defined"
type AgentsSessionRigTermNoteInto > /dev/null 2>&1 || rigRefuse "AgentsSessionRigTermNoteInto is not defined"
## ONE SLEEPER and its pid file: `<pid> <began>` as the tooling writes it, or the rest the caller gives.
rigControlThread(){ ## the pid-file path, the rest of the line or `began` for the real one
	local rest="$2"
	python3 -I -B -c 'import time; time.sleep(300)' > /dev/null 2>&1 &
	rigLastPid="$!" ; rigProcNote "$rigLastPid"
	sleep 0.2
	[ "$rest" != began ] || { rest="$( printf '%s\n' "$rigLastPid" | AgentsToolsRunProcessesBegan )" ; rest="${rest#"$rigLastPid" }" ; }
	mkdir -p "${1%/*}" || exit 1
	printf '%s %s\n' "$rigLastPid" "$rest" > "$1"
}
## ONE CONTROL THREAD THAT ANSWERS NO TERM, the same pid file: the polite signal is one it was started to ignore.
rigDeafThread(){ ## the pid-file path
	sh -c 'trap "" TERM ; exec sleep 300' > /dev/null 2>&1 &
	rigLastPid="$!" ; rigProcNote "$rigLastPid"
	sleep 0.3
	local deafRest
	deafRest="$( printf '%s\n' "$rigLastPid" | AgentsToolsRunProcessesBegan )" ; deafRest="${deafRest#"$rigLastPid" }"
	mkdir -p "${1%/*}" || exit 1
	printf '%s %s\n' "$rigLastPid" "$deafRest" > "$1"
}
rigClosedRun(){ ## the spawn id -- its output folder, its closed record and its control pid file, no thread yet
	mkdir -p "$rigAgents/spawned/$1/sessions/run-a/output/control" || exit 1
	printf -- '---\nsession-id: %s\nspawn-id: %s\nowner: rig-keeper\nstatus: spawn-succeeded\nstarted-at: 2026-11-06 10:00 +0000\nresolved-at: 2026-11-06 10:30 +0000\n---\n' "$1" "$1" > "$rigAgents/spawned/$1/$1.spawn.md"
}
rigClose(){ ## the workspace, the options...
	local ws="$1" ; shift
	## A supervisor write runs as magic-coordinator's session, as the hands check calls one.
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" MDSC_CMD=AgentDispatcherTools \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_TEAM_DATA_COMMIT_THREAD=off MDAT_COMMS_READER=off MDAT_COLLECT_THREAD=off MDAT_SPAWN_AGENT=magic-coordinator \
		MDAT_SUPERVISE_RIG_WALK_SECONDS=0 \
		bash "$rigFn" --supervise-close-orphans --workspace "$ws" "$@" 2>&1
}
rigRow(){ ## the output, the spawn id -- that row's verdict, or `absent`
	local row
	row="$( printf '%s\n' "$1" | LC_ALL=C awk -v id="$2" '$1 == "rig-orphan" && $3 == id { print $NF ; exit }' )"
	printf '%s' "${row:-absent}"
}

echo "-- the rig: two closed runs, each with a control thread in its output folder --"
for rigSpid in rig-amat rig-bmis ; do
	rigClosedRun "$rigSpid"
done
rigControlThread "$rigAgents/spawned/rig-amat/sessions/run-a/output/control/pid" began ; rigPidA="$rigLastPid"
rigControlThread "$rigAgents/spawned/rig-bmis/sessions/run-a/output/control/pid" 'Mon_Jan_1_00:00:00_2001' ; rigPidB="$rigLastPid"

echo "-- 1. the readout names what it would close and signals nothing --"
rigOut="$( rigClose "$rigWs" )"
rigAssert "a matching pid reads would-close" "$( rigRow "$rigOut" rig-amat )" "would-close"
rigAssert "a pid whose began moment is not the process's own reads kept-mismatch" "$( rigRow "$rigOut" rig-bmis )" "kept-mismatch"
rigAssert "both still live after the readout" "$( kill -0 "$rigPidA" 2> /dev/null && kill -0 "$rigPidB" 2> /dev/null && echo alive || echo gone )" "alive"

echo "-- 2. --execute closes the matching one and keeps the mismatched one --"
rigOut="$( rigClose "$rigWs" --execute )"
rigAssert "the matching one reads closed" "$( rigRow "$rigOut" rig-amat )" "closed"
sleep 0.3
rigAssert "and its process is gone" "$( kill -0 "$rigPidA" 2> /dev/null && echo alive || echo gone )" "gone"
rigAssert "the mismatched one is kept" "$( rigRow "$rigOut" rig-bmis )" "kept-mismatch"
rigAssert "and its process lives" "$( kill -0 "$rigPidB" 2> /dev/null && echo alive || echo gone )" "alive"

echo "-- 3. a second --execute finds the closed one no more --"
rigOut="$( rigClose "$rigWs" --execute )"
rigAssert "the closed one has no row" "$( rigRow "$rigOut" rig-amat )" "absent"
rigAssert "the mismatched one is still kept" "$( rigRow "$rigOut" rig-bmis )" "kept-mismatch"

echo "-- 4. a workspace with nothing to close says none --"
rigOut="$( rigClose "$rigEmpty" --execute )"
rigAssert "none is said" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^none - - no rig-orphan' )" "1"

echo "-- 5. a control thread that answers no TERM is left alive, and the pass notes the process it left --"
rigClosedRun rig-cdef
rigDeafThread "$rigAgents/spawned/rig-cdef/sessions/run-a/output/control/pid" ; rigPidC="$rigLastPid"
rigNoteC="$rigAgents/spawned/rig-cdef/sessions/run-a/output/control/pid.term"
rigOut="$( rigClose "$rigWs" --execute )"
rigAssert "it reads still-alive" "$( rigRow "$rigOut" rig-cdef )" "still-alive"
rigAssert "and it is not ended: its process lives" "$( kill -0 "$rigPidC" 2> /dev/null && echo alive || echo gone )" "alive"
rigAssert "a note stands beside that rig's pid file" "$( [ -f "$rigNoteC" ] && echo kept || echo none )" "kept"
rigAssert "and it names the process the pid file names" "$( LC_ALL=C awk '{ print $1 }' "$rigNoteC" 2> /dev/null )" "$rigPidC"
rigAssert "and with the began moment the tooling reads for it" "$( LC_ALL=C awk '{ print $2 }' "$rigNoteC" 2> /dev/null )" "$( printf '%s\n' "$rigPidC" | AgentsToolsRunProcessesBegan | LC_ALL=C awk '{ print $2 }' )"

echo "-- 6. the readout says it would be killed, and signals nothing --"
rigOut="$( rigClose "$rigWs" )"
rigAssert "the noted one reads would-kill" "$( rigRow "$rigOut" rig-cdef )" "would-kill"
rigAssert "and it is not signalled: its process lives" "$( kill -0 "$rigPidC" 2> /dev/null && echo alive || echo gone )" "alive"

echo "-- 7. the next --execute ends it harder, and the note goes with it --"
rigOut="$( rigClose "$rigWs" --execute )"
rigAssert "the noted one reads killed" "$( rigRow "$rigOut" rig-cdef )" "killed"
rigAssert "its process is gone" "$( ps -o stat= -p "$rigPidC" 2> /dev/null | LC_ALL=C grep -c '[^Z ]' )" "0"
rigAssert "and its note is gone" "$( [ -f "$rigNoteC" ] && echo kept || echo none )" "none"

echo "-- 8. a note naming another process is removed and is not obeyed --"
rigClosedRun rig-efgh
rigControlThread "$rigAgents/spawned/rig-efgh/sessions/run-a/output/control/pid" began ; rigPidD="$rigLastPid"
rigNoteE="$rigAgents/spawned/rig-efgh/sessions/run-a/output/control/pid.term"
MMDAPP="$rigWs" AgentsSessionRigTermNoteSet rig-efgh sessions/run-a/output/control/pid "$$" 'Mon_Jan_1_00:00:00_2001' || rigRefuse "the note could not be written for the rig"
rigAssert "a note naming another process stood beside its pid file" "$( [ -f "$rigNoteE" ] && echo kept || echo none )" "kept"
rigOut="$( rigClose "$rigWs" )"
rigAssert "the row reads would-close, as for a rig no pass has signalled yet" "$( rigRow "$rigOut" rig-efgh )" "would-close"
rigAssert "and that note is removed" "$( [ -f "$rigNoteE" ] && echo kept || echo none )" "none"
rigAssert "and that one is not signalled either" "$( kill -0 "$rigPidD" 2> /dev/null && echo alive || echo gone )" "alive"

echo "-- 9. a note whose process has gone is cleared by the next pass --"
rigClosedRun rig-gijk
rigDeafThread "$rigAgents/spawned/rig-gijk/sessions/run-a/output/control/pid" ; rigPidE="$rigLastPid"
rigNoteG="$rigAgents/spawned/rig-gijk/sessions/run-a/output/control/pid.term"
rigClose "$rigWs" --execute > /dev/null
rigAssert "the noted one is left alive for this case" "$( [ -f "$rigNoteG" ] && echo kept || echo none )" "kept"
rigProcSignal KILL "$rigPidE" || :
rigWaitE=0
while [ "$rigWaitE" -lt 20 ] && [ "$( ps -o stat= -p "$rigPidE" 2> /dev/null | LC_ALL=C grep -c '[^Z ]' )" != 0 ] ; do sleep 0.1 ; rigWaitE=$(( rigWaitE + 1 )) ; done
rigAssert "its process has gone before the pass" "$( ps -o stat= -p "$rigPidE" 2> /dev/null | LC_ALL=C grep -c '[^Z ]' )" "0"
rigOut="$( rigClose "$rigWs" )"
rigAssert "a pass reads no row for it" "$( rigRow "$rigOut" rig-gijk )" "absent"
rigAssert "and its note is cleared" "$( [ -f "$rigNoteG" ] && echo kept || echo none )" "none"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SUPERVISE CLOSE ORPHANS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	exit 1
fi
echo "SUPERVISE_CLOSE_ORPHANS: OK ($rigPassCount assertions, offline)"
