#!/usr/bin/env bash
## Behavioural check on S13.18: `--supervise-scan` says where every live run stands. One `run` line for each live run: its
## latest tool call and age, its latest message, the CheckList item in progress, a pause on the session, its open asks, and a
## verdict of active, waiting or stuck. A run in Wait, or paused, reads waiting. Stuck is no tool call for ten minutes and not
## in Wait. A parked or dismissed run is neither stuck nor dead. Every time comes from what the run wrote, never a file's date.
## Held:
##   1. the five verdicts: a paused run, a run in Wait, a working run, a stuck run, and a fresh control
##   2. a working run whose transcript lags: its age is the run's own mark, not the older transcript line
##   2b. a run that writes no mark, and a rolled transcript, are read from the transcript across its parts
##   3. the run's pause, its open-ask count, its latest message and its item in progress
##   3b. liveness is the process and the mark: a run whose record reads spawn-succeeded gets its line
##   4. a parked run, and a dismissed run, get no `run` line and no `dead` line
##   5. the existing kinds are unchanged: an open ask to the coordinator still reads `ask`
##   6. THE COST DOES NOT GROW WITH THE OWNER'S QUESTIONS either: the same fork count with an ask to the owner standing, which
##      the scan used to answer by walking every spawn record once for the asking run and once for its parent
## WHAT THE PAUSED CASE PROVES. The pause signal is the flag `sessions/<id>/paused`, which `--manager-session-pause` writes
## and `--manager-session-resume` removes (S19, AgentsTools.SessionPause.include). This case makes that file by hand, so it
## proves the scan reads the very flag the harness and the tooling obey, and that a paused run reads `waiting` and never
## `stuck`. A real pause reaching it is held by sh-test/session/AgentsSessionPauseReadersCheck.test.sh, which writes the flag
## through the operation and reads this scan's own line.
## Red before S13.18: no `run` line at all, and a parked run reads `dead`. Red before the owner-ask fix: the fork count of
## section 6 rises by the record count per standing ask.
## Offline: a rig workspace, its spawn records and its team data are this rig's own temp tree; a run's process is a stand-in.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigFn="$rigPkg/sh-scripts/AgentDispatcherTools.fn.sh"
rigIsoAwk="$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/output/LocalIsoToEpoch.awk"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigFn" ] || rigRefuse "the dispatcher is not at the origin: $rigFn"
[ -f "$rigIsoAwk" ] || rigRefuse "the ISO reader is not at the origin: $rigIsoAwk"
mkdir -p "$MMDAPP/.local/temp"
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsSuperviseScanCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigPids=""
trap 'for rigOne in $rigPids ; do kill -KILL "$rigOne" 2> /dev/null ; done ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
rigAgents="$rigWs/.local/agents"
mkdir -p "$rigAgents/spawned" "$rigAgents/sessions" "$rigAgents/pending" "$rigWs/.local/.agents" "$rigData/audit/2026-11" \
	|| rigRefuse "the rig could not be made: $rigTmp"
rigNow="$( date +%s )"

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

## A time the tooling can read, from an epoch: no portable date(1) prints one, so both spellings are tried.
rigIso(){ ## epoch
	date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ 2> /dev/null || date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ 2> /dev/null
}
rigTranscriptPath(){ ## run id -- where its transcript is, as the run's own pointer names it
	printf '%s/audit/2026-11/%s.log' "$rigData" "$1"
}
rigRun(){ ## run id, member, status (spawn-started where not given) -- its record, its folder, its transcript pointer
	local runId="$1" runDir="$rigAgents/spawned/$1"
	mkdir -p "$runDir" "$rigAgents/sessions/$1" || rigRefuse "the run could not be made: $runId"
	printf -- '---\nsession-id: %s\nspawn-id: %s\ntracking-name: %s\nhost: %s\nworkspace: ws-supervise-scan-rig\nowner: %s\nstatus: %s\nstarted-at: %s\ntranscript: audit/2026-11/%s.log\n---\n' \
		"$runId" "$runId" "$runId" "$( hostname -s 2> /dev/null )" "$2" "${3:-spawn-started}" \
		"$( date '+%Y-%m-%d %H:%M %z' )" "$runId" > "$runDir/$runId.spawn.md" || rigRefuse "the record could not be written: $runId"
	printf '%s\n' "$( rigTranscriptPath "$runId" )" > "$rigAgents/sessions/$1/transcript"
	: > "$( rigTranscriptPath "$runId" )"
}
## The record's own run-process line, as the launcher writes it: the pid and the moment it began.
rigLaunched(){ ## run id, pid
	local begun
	begun="$( LC_ALL=C ps -o lstart= -p "$2" 2> /dev/null | LC_ALL=C awk 'NF { $1 = $1 ; gsub( / /, "_" ) ; print ; exit }' )" || begun=""
	[ -n "$begun" ] || rigRefuse "the stand-in process named no start: $2"
	printf 'run-process: %s %s\n' "$2" "$begun" >> "$rigAgents/spawned/$1/$1.spawn.md"
}
## A record ten minutes old: an older record with no process is read as a run whose process should have started.
rigPast(){ ## file
	python3 -I -B -c 'import os,sys; t = os.path.getmtime(sys.argv[1]) - 600; os.utime(sys.argv[1], (t, t))' "$1" \
		|| rigRefuse "the record's date could not be set back: $1"
}
rigTool(){ ## run id, seconds ago, tool name -- one tool line of the run's transcript
	printf '%s TOOL %s cmd="rig" -> ok 1B/1L <1s\n' "$( rigIso $(( rigNow - $2 )) )" "$3" >> "$( rigTranscriptPath "$1" )"
}
rigMark(){ ## run id, seconds ago, activity word -- the run's own log of what it is doing
	printf '1 %s %s\n' "$(( rigNow - $2 ))" "$3" > "$rigAgents/sessions/$1/activity"
}
rigStand(){ ## run id -- a process carrying the id, so the run reads live
	python3 -I -B -c 'import time; time.sleep(240)' -- --session-id "$1" > /dev/null 2>&1 &
	rigPids="$rigPids $!"
	disown "$!" 2> /dev/null || :
}
rigChat(){ ## run id, seconds ago, who, text
	printf '%s %s -> all: %s\n' "$( rigIso $(( rigNow - $2 )) )" "$3" "$4" >> "$rigAgents/sessions/$1/session.chat"
}
rigPlan(){ ## run id, member, the item in progress
	printf -- '- [~] %s (in progress: %s)\n- [ ] another item\n' "$3" "$3" > "$rigAgents/spawned/$1/$2.checklist.md"
}
rigAsk(){ ## run id, owner, address-to (magic-coordinator where not given) -- its question, still unanswered
	printf -- '---\nstatus: reply-pending\nowner: %s\nkind: question\naddress-to: %s\nsession-id: %s\nquestion-ts: %s.000000\nasked-at: %s\n---\n' \
		"$2" "${3:-magic-coordinator}" "$1" "$rigNow" "$( date '+%Y-%m-%d %H:%M %z' )" > "$rigAgents/pending/rig-ask-$1.md"
}
rigAskOwner(){ ## run id -- a question of that run to the human-owner, its own file so it never shares a name
	printf -- '---\nstatus: reply-pending\nowner: magic-coordinator\nkind: question\naddress-to: human-owner\nsession-id: %s\nquestion-ts: %s.000000\nasked-at: %s\n---\n' \
		"$1" "$rigNow" "$( date '+%Y-%m-%d %H:%M %z' )" > "$rigAgents/pending/owner-ask-$1.md"
}
## The scan, run by the dispatcher of the origin under test, or from RIG_INCLUDE where one names an include to try first.
rigScan(){
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="${rigScanPath:-/usr/bin:/bin:/usr/sbin:/sbin}" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		RIG_INCLUDE="${RIG_INCLUDE:-}" \
		bash -c 'if [ -n "$RIG_INCLUDE" ] ; then . "$RIG_INCLUDE" ; AgentsToolsSuperviseScan --workspace "$1" ; else exec bash "$2" --supervise-scan --workspace "$1" ; fi' rig "$rigWs" "$rigFn" 2>&1
}
rigLine(){ ## run id -- its `run` line
	printf '%s\n' "$rigOut" | LC_ALL=C awk -v want="$1" '$1 == "run" && $3 == want { print }' | head -1
}
rigWord(){ ## run id, field number -- that word of its `run` line
	rigLine "$1" | LC_ALL=C awk -v want="$2" '{ print $want }'
}
rigKind(){ ## kind -- how many lines of that kind
	printf '%s\n' "$rigOut" | LC_ALL=C awk -v want="$1" '$1 == want' | wc -l | tr -d ' '
}
## The paused run: a pause holds its work, and an old tool call is no verdict of stuck on it.
rigRun rigpaus magic-developer
: > "$rigAgents/sessions/rigpaus/paused"
rigMark rigpaus 1200 "tool Bash"
rigTool rigpaus 1200 Bash
rigStand rigpaus
## The run in Wait: its mark says so, and it is not stuck however long it waits.
rigRun rigwait magic-developer
rigMark rigwait 1800 "tool Wait"
rigTool rigwait 1800 Wait
rigStand rigwait
## The working run whose transcript lags: the transcript's own tool line is forty minutes old, the run's mark thirty seconds.
rigRun rigwork magic-developer
rigTool rigwork 2400 Read
rigMark rigwork 30 "tool Bash"
rigChat rigwork 60 magic-developer "still on the scan"
rigPlan rigwork magic-developer "Run the checks you touch"
rigAsk rigwork magic-developer
rigStand rigwork
## The stuck run: live, not in Wait, and no tool call in twenty minutes.
rigRun rigstuk magic-developer
rigTool rigstuk 1200 Read
rigMark rigstuk 1200 thinking
rigStand rigstuk
## The control: the same shape with a tool call twenty seconds ago is not stuck.
rigRun rigfres magic-developer
rigTool rigfres 1200 Read
rigMark rigfres 20 "tool Read"
rigStand rigfres
## A native client's run: it writes no activity mark, so its transcript is its only word. One is inside a Wait, one long
## past a tool call, and the two must not read alike.
rigRun rignatwt magic-developer
rigTool rignatwt 3600 Wait
rigStand rignatwt
rigRun rignatwk magic-developer
rigTool rignatwk 1800 Bash
rigStand rignatwk
## A run whose transcript has rolled: its base part holds no tool line, and the last part does.
rigRun rigroll magic-developer
printf '%s TOOL Bash cmd="rig" -> ok 1B/1L <1s\n' "$( rigIso $(( rigNow - 2400 )) )" >> "$( rigTranscriptPath rigroll )"
printf '%s TOOL Read cmd="rig" -> ok 1B/1L <1s\n' "$( rigIso $(( rigNow - 1500 )) )" > "$( rigTranscriptPath rigroll | sed 's/\.log$/-part2.log/' )"
rigStand rigroll
## A run still working whose record reads spawn-succeeded: a duty's run, closed and restarted under the same id. Its process
## is there and so is its mark, so it is a live run and it gets a line. Its neighbour, closed with no process, gets none.
rigRun rigclose magic-developer spawn-succeeded
rigMark rigclose 60 "tool Wait"
rigTool rigclose 60 Wait
rigStand rigclose
rigLaunched rigclose "$( LC_ALL=C ps -A -ww -o pid=,args= | LC_ALL=C awk -v want="--session-id rigclose" 'index( $0, want ) { print $1 ; exit }' )"
rigRun riggone magic-developer spawn-succeeded
rigPast "$rigAgents/spawned/riggone/riggone.spawn.md"
## A parked run and a dismissed run: each handed back, no process, an old record.
rigRun rigpark magic-developer
: > "$rigAgents/sessions/rigpark/parked"
rigPast "$rigAgents/spawned/rigpark/rigpark.spawn.md"
rigRun rigdism magic-developer
: > "$rigAgents/sessions/rigdism/dismissed"
rigPast "$rigAgents/spawned/rigdism/rigdism.spawn.md"
sleep 2

echo "-- 1. one run line per live run, and the verdict each one carries --"
rigOut="$( rigScan )"
rigAssert "a live run gets a run line" "$( rigKind run )" "9"
rigAssert "a paused run waits, and is not stuck" "$( rigWord rigpaus 5 )" "waiting"
rigAssert "a run in Wait waits" "$( rigWord rigwait 5 )" "waiting"
rigAssert "a working run is active" "$( rigWord rigwork 5 )" "active"
rigAssert "a run with no tool call in twenty minutes is stuck" "$( rigWord rigstuk 5 )" "stuck"
rigAssert "the control, a tool call twenty seconds ago, is active" "$( rigWord rigfres 5 )" "active"

echo "-- 2. the age is the run's own, and the lagging transcript is not believed --"
rigAssert "the working run's tool is the one its mark names" "$( rigWord rigwork 6 )" "tool=Bash"
rigAssert "and its age is that mark's, thirty seconds" "$( rigWord rigwork 7 )" "age=0m"
rigAssert "the stuck run names the tool its transcript last saw" "$( rigWord rigstuk 6 )" "tool=Read"
rigAssert "and its age is that line's, twenty minutes" "$( rigWord rigstuk 7 )" "age=20m"

echo "-- 2b. a run that writes no mark is read from its transcript, and its Wait is not silence --"
rigAssert "a native run inside Wait waits" "$( rigWord rignatwt 5 )" "waiting"
rigAssert "and its age is its wait's, an hour" "$( rigWord rignatwt 7 )" "age=60m"
rigAssert "a native run past a tool call is stuck" "$( rigWord rignatwk 5 )" "stuck"

rigAssert "a rolled transcript's last part names the tool" "$( rigWord rigroll 6 )" "tool=Read"
rigAssert "and its age is that part's line" "$( rigWord rigroll 7 )" "age=25m"

echo "-- 3. the pause, the open asks, the latest message, the item in progress --"
rigAssert "the paused run carries its flag" "$( rigWord rigpaus 8 )" "paused=yes"
rigAssert "a run with no pause says so" "$( rigWord rigwork 8 )" "paused=no"
rigAssert "the working run's open ask is counted" "$( rigWord rigwork 9 )" "asks=1"
rigAssert "a run with no open ask carries none" "$( rigWord rigstuk 9 )" "asks=0"
rigAssert "the latest message is the run's own last post" "$( rigLine rigwork | LC_ALL=C grep -c 'magic-developer: still on the scan' )" "1"
rigAssert "the item in progress is the run's own" "$( printf '%s' "$( rigLine rigwork )" | LC_ALL=C grep -c 'plan: Run the checks you touch' )" "1"

echo "-- 3b. liveness comes from the process and the mark, never from the record's status --"
rigAssert "a run whose record reads spawn-succeeded gets its line" "$( rigWord rigclose 5 )" "waiting"
rigAssert "and it names the tool it is in" "$( rigWord rigclose 6 )" "tool=Wait"
rigAssert "a closed record with no process gets no line" "$( rigLine riggone )" ""
rigAssert "and reads no dead either" "$( rigKind dead )" "0"

echo "-- 4. a parked run and a dismissed run are neither stuck nor dead --"
rigAssert "a parked run gets no run line" "$( rigLine rigpark )" ""
rigAssert "a dismissed run gets no run line" "$( rigLine rigdism )" ""
rigAssert "neither of them reads dead" "$( rigKind dead )" "0"

echo "-- 4b. the scan costs the same however many closed records stand --"
## The forks of a scan, counted by a PATH stub of the tools it runs: a scan that runs a process per record is then seen,
## never reasoned about. Two scans, one on this rig and one with a hundred and twenty closed records added.
rigForkCount(){ ## none
	: > "$rigTmp/fork.log"
	rigScanPath="$rigTmp/forkbin:/usr/bin:/bin:/usr/sbin:/sbin"
	rigScan > /dev/null 2>&1
	rigScanPath=""
	LC_ALL=C wc -l < "$rigTmp/fork.log" | tr -d ' '
}
mkdir -p "$rigTmp/forkbin" || rigRefuse "the fork stub folder could not be made"
for rigForkTool in ps sed awk grep find cut basename head tail tr wc sort ls : ; do
	rigForkReal="$( command -v "$rigForkTool" 2> /dev/null )" || continue
	printf '#!/bin/bash\nprintf "%%s\\n" %s >> "%s"\nexec %s "$@"\n' "$rigForkTool" "$rigTmp/fork.log" "$rigForkReal" > "$rigTmp/forkbin/$rigForkTool"
	chmod +x "$rigTmp/forkbin/$rigForkTool"
done
rigFewForks="$( rigForkCount )"
rigIdleAt=0
while [ "$rigIdleAt" -lt 120 ] ; do
	rigIdleAt=$(( rigIdleAt + 1 ))
	rigRun "rigidle$rigIdleAt" magic-developer spawn-succeeded
	rigPast "$rigAgents/spawned/rigidle$rigIdleAt/rigidle$rigIdleAt.spawn.md"
done
rigOut="$( rigScan )"
rigManyForks="$( rigForkCount )"
rigAssert "the fork count of a scan, without then with 120 more closed records" "$rigFewForks $rigManyForks" "$rigFewForks $rigFewForks"
rigAssert "and every live run is still on its line" "$( rigKind run )" "9"

echo "-- 5. the kinds of before are unchanged --"
rigAssert "an open ask to the coordinator still reads ask" "$( rigKind ask )" "1"

echo "-- 6. a standing ask to the owner costs no walk over the records --"
## The owner holds open questions in every working rig, and most of them name a session no record carries. The scan answered
## each one by walking the whole record folder for the asking run and again for its parent, so its cost was the records times
## the asks. Both loops became one lookup in the record table read once, and this is the count that holds it: the same ask
## over a rig with twice the closed records costs the same.
rigAskOwner rigowner
rigOut="$( rigScan )"
rigAskFewForks="$( rigForkCount )"
rigAssert "the owner's standing ask is read beside the coordinator's own" "$( rigKind ask )" "2"
rigAssert "and it names no parent, naming a session no record carries" "$( rigKind parent-ask )" "0"
rigIdleAt=0
while [ "$rigIdleAt" -lt 120 ] ; do
	rigIdleAt=$(( rigIdleAt + 1 ))
	rigRun "rigmore$rigIdleAt" magic-developer spawn-succeeded
	rigPast "$rigAgents/spawned/rigmore$rigIdleAt/rigmore$rigIdleAt.spawn.md"
done
rigOut="$( rigScan )"
rigAskManyForks="$( rigForkCount )"
rigAssert "and still no parent is named, with 120 more closed records behind it" "$( rigKind parent-ask )" "0"
rigAssert "the fork count of a scan with an owner ask, without then with 120 more closed records" "$rigAskFewForks $rigAskManyForks" "$rigAskFewForks $rigAskFewForks"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SUPERVISE SCAN CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'SUPERVISE_SCAN: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
