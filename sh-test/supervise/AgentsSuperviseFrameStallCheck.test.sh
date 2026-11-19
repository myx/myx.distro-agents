#!/usr/bin/env bash
## Behavioural check on S6.27 stage 6, the supervisor's read of a run's frame in force, through `--supervise-scan`:
##   1. a frame with a live frame below it, unmoved past the bound, reads `frame-stall` with `open=1`
##   2. a base frame, with no live frame below it, is never `frame-stall`, however old: nothing can move it while its
##      session lives, and the run's own `stall` line covers a stuck duty
##   3. a frame moved inside the bound reads no `frame-stall`, so a move clears the line
##   4. a frame held on an awaited contribution, an `awaited:` item pending on its own CheckList, is held and never stalled
##   5. every live run with a stack reads one `frame` line, with its open count
## Red before the base-frame ruling: 2 fails, since the scan printed `frame-stall` for every old base frame.
## Offline: a rig workspace, its spawn records and its team data are this rig's own temp tree; a run's process is a
## stand-in of this check, and every one of them is ended on the way out.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigFn="$rigPkg/sh-scripts/AgentDispatcherTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigFn" ] || rigRefuse "the dispatcher is not at the origin: $rigFn"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSuperviseFrameStallCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigPids=""
rigReap(){
	local reapOne
	for reapOne in $rigPids ; do kill -TERM "$reapOne" 2> /dev/null ; done
	sleep 0.3
	for reapOne in $rigPids ; do kill -KILL "$reapOne" 2> /dev/null ; done
	rm -rf -- "$rigTmp"
}
trap 'rigReap' EXIT
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
rigAgents="$rigWs/.local/agents"
mkdir -p "$rigAgents/spawned" "$rigAgents/sessions" "$rigWs/.local/.agents" "$rigData/audit/2026-11" "$rigTmp/home" \
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
## A date-time as the record writes one, from an epoch: no portable date(1) prints one, so both spellings are tried.
rigStamp(){ date -r "$1" '+%Y-%m-%d %H:%M %z' 2> /dev/null || date -d "@$1" '+%Y-%m-%d %H:%M %z' 2> /dev/null ; }
## A live run whose record holds a stack: started two hours ago, its frames, and its move lines.
rigRun(){ ## run id (eight characters, as a scan line names it), the routine-stack lines, the move lines (may be empty)
	local runId="$1" runDir="$rigAgents/spawned/$1"
	mkdir -p "$runDir" "$rigAgents/sessions/$1" || rigRefuse "the run could not be made: $runId"
	{
		printf -- '---\nsession-id: %s\nspawn-id: %s\ntracking-name: %s\nhost: %s\nworkspace: ws-frame-stall-rig\nowner: magic-developer\nstatus: spawn-started\nstarted-at: %s\n' \
			"$runId" "$runId" "$runId" "$( hostname -s 2> /dev/null )" "$( rigStamp $(( rigNow - 7200 )) )"
		printf 'routine-stack: %s\n' $2
		[ -z "$3" ] || printf '%s\n' "$3"
		printf -- '---\n'
	} > "$runDir/$runId.spawn.md" || rigRefuse "the record could not be written: $runId"
	printf '%s/audit/2026-11/%s.log\n' "$rigData" "$runId" > "$rigAgents/sessions/$1/transcript"
	: > "$rigData/audit/2026-11/$runId.log"
	python3 -I -B -c 'import time; time.sleep(300)' -- --session-id "$runId" > /dev/null 2>&1 &
	rigPids="$rigPids $!"
	disown "$!" 2> /dev/null || :
}
rigPush(){ ## routine, seconds ago -- the push line that put it on top
	printf 'routine-stack-push: %s at: %s by: chair reason: rig' "$1" "$( rigStamp $(( rigNow - $2 )) )"
}
rigScan(){
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		bash "$rigFn" --supervise-scan --workspace "$rigWs" 2>&1
}
rigKindOf(){ printf '%s\n' "$rigOut" | LC_ALL=C awk -v want="$1" -v run="$2" '$1 == want && $3 == run' ; } ## kind, run id -- its lines

## The rig's runs: a pushed frame unmoved for two hours above an open one; a base frame alone for two hours; a pushed
## frame moved a minute ago; and the same unmoved push whose own list holds a pending awaited contribution.
rigRun rigupper "rig-base.routine.md:open rig-top.routine.md:current" "$( rigPush rig-top.routine.md 7200 )"
rigRun rigbase0 "rig-base.routine.md:current" ""
rigRun rigmoved "rig-base.routine.md:open rig-top.routine.md:current" "$( rigPush rig-top.routine.md 60 )"
rigRun righeld0 "rig-base.routine.md:open rig-top.routine.md:current" "$( rigPush rig-top.routine.md 7200 )"
printf -- '- [ ] awaited: apply the corrections from magic-tester\n' > "$rigAgents/spawned/righeld0/magic-developer.checklist.md"
sleep 2
rigOut="$( rigScan )"

echo "-- 1. a frame above a live frame, unmoved past the bound, is frame-stall with open=1 --"
rigAssert "the unmoved upper frame reads frame-stall" "$( rigKindOf frame-stall rigupper | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 1
rigAssert "naming its routine and open=1" "$( rigKindOf frame-stall rigupper | LC_ALL=C awk '{ print $5, $NF }' )" "rig-top.routine.md open=1"

echo "-- 2. a base frame is never frame-stall --"
rigAssert "the two-hour base frame reads no frame-stall" "$( rigKindOf frame-stall rigbase0 | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 0

echo "-- 3. a move clears it --"
rigAssert "the frame moved a minute ago reads no frame-stall" "$( rigKindOf frame-stall rigmoved | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 0

echo "-- 4. a frame held on an awaited contribution is held --"
rigAssert "the unmoved frame with an awaited item pending reads no frame-stall" "$( rigKindOf frame-stall righeld0 | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 0

echo "-- 5. every live run with a stack reads one frame line --"
rigAssert "the four runs each read one frame line" \
	"$( for rigOne in rigupper rigbase0 rigmoved righeld0 ; do rigKindOf frame "$rigOne" | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ; done | LC_ALL=C tr '\n' ' ' )" "1 1 1 1 "
rigAssert "the base frame's line reads open=0, the upper frame's open=1" \
	"$( rigKindOf frame rigbase0 | LC_ALL=C grep -o 'open=[0-9]*' ):$( rigKindOf frame rigupper | LC_ALL=C grep -o 'open=[0-9]*' )" "open=0:open=1"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SUPERVISE FRAME STALL CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'SUPERVISE_FRAME_STALL: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
