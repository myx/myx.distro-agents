#!/usr/bin/env bash
## Behavioural check on S13.2 of `20261102-refactorings.epic.md`: "Stall detection: a run waiting with pending items,
## a run silent past a bound, an ask nobody can answer, an ask sent to the human-owner that its parent can settle."
## Held here, through `--supervise-scan`:
##   1. a live run silent in its Wait past the bound, with items still pending on its own CheckList, reads `stall`,
##      naming its age, its pending count and the item it is on; the run's own line is unchanged
##   2. the controls that make that a finding and no reading of every waiting run: the same silence with nothing
##      pending, and the same pending work inside the bound, read no `stall`
##   3. the bound is a setting, `MDAT_SUPERVISE_STALL_SECONDS`, and it is the one both readings use: a run working
##      rather than waiting reads `active` at two hours and `stuck` at ten minutes, and the stall follows it
##   4. an open question to the human-owner whose asking run's parent session is a live magic-coordinator's reads
##      `parent-ask`, naming the parent and its member; the control is the same question whose parent has ended, which
##      gets no `parent-ask`, and both keep their plain `ask` line
##   5. an ask nobody can answer, the `orphan-ask` line the scan has always printed, is asserted too, so a change to the
##      ask loop cannot lose it unnoticed
## Red before S13.2: no `stall` line and no `parent-ask` line exist at all, and 600 is written into the scan, so the
## whole of 1, 3 and 4 fails: 9 of the 18 assertions.
## Offline: a rig workspace, its spawn records and its team data are this rig's own temp tree; a run's process and a
## parent session's are stand-ins of this check, and every one of them is ended on the way out.
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
rigTmp="$( rigTempDir AgentsSuperviseStallCheck )" || exit 1
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
mkdir -p "$rigAgents/spawned" "$rigAgents/sessions" "$rigAgents/pending" "$rigWs/.local/.agents" "$rigData/audit/2026-11" "$rigTmp/home" \
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

## A time the tooling reads, from an epoch: no portable date(1) prints one, so both spellings are tried.
rigIso(){ date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ 2> /dev/null || date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ 2> /dev/null ; }
rigTranscriptPath(){ printf '%s/audit/2026-11/%s.log' "$rigData" "$1" ; }
rigRun(){ ## run id (eight characters, as a scan line names it), member, extra frontmatter lines (may be empty)
	local runId="$1" runDir="$rigAgents/spawned/$1"
	mkdir -p "$runDir" "$rigAgents/sessions/$1" || rigRefuse "the run could not be made: $runId"
	printf -- '---\nsession-id: %s\nspawn-id: %s\ntracking-name: %s\nhost: %s\nworkspace: ws-supervise-stall-rig\nowner: %s\nstatus: spawn-started\nstarted-at: %s\n%s---\n' \
		"$runId" "$runId" "$runId" "$( hostname -s 2> /dev/null )" "$2" "$( date '+%Y-%m-%d %H:%M %z' )" \
		"${3:+$3
}" > "$runDir/$runId.spawn.md" || rigRefuse "the record could not be written: $runId"
	printf '%s\n' "$( rigTranscriptPath "$runId" )" > "$rigAgents/sessions/$1/transcript"
	: > "$( rigTranscriptPath "$runId" )"
}
rigTool(){ ## run id, seconds ago, tool name -- one tool line of the run's transcript
	printf '%s TOOL %s cmd="rig" -> ok 1B/1L <1s\n' "$( rigIso $(( rigNow - $2 )) )" "$3" >> "$( rigTranscriptPath "$1" )"
}
rigMark(){ ## run id, seconds ago, activity word -- the run's own log of what it is doing
	printf '1 %s %s\n' "$(( rigNow - $2 ))" "$3" > "$rigAgents/sessions/$1/activity"
}
rigStand(){ ## run id -- a process carrying the id, so the run reads live
	python3 -I -B -c 'import time; time.sleep(300)' -- --session-id "$1" > /dev/null 2>&1 &
	rigPids="$rigPids $!"
	disown "$!" 2> /dev/null || :
}
rigPlan(){ ## run id, member, the item in progress, then the pending items, one argument each
	local planFile="$rigAgents/spawned/$1/$2.checklist.md" planItem
	shift 2
	{ printf -- '- [~] %s (in progress: %s)\n' "$1" "$1" ; shift ; for planItem in "$@" ; do printf -- '- [ ] %s\n' "$planItem" ; done ; } > "$planFile"
}
rigAsk(){ ## asking run id, address -- its open question, posted
	printf -- '---\nstatus: reply-pending\nowner: magic-developer\nkind: question\naddress-to: %s\nsession-id: %s\nquestion-ts: %s.000000\nasked-at: %s\n---\n' \
		"$2" "$1" "$rigNow" "$( date '+%Y-%m-%d %H:%M %z' )" > "$rigAgents/pending/$1.md"
}
## The scan, run by the dispatcher of the origin under test, on this rig's workspace alone.
rigScan(){ ## extra NAME=value words...
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" "$@" \
		bash "$rigFn" --supervise-scan --workspace "$rigWs" 2>&1
}
rigKind(){ printf '%s\n' "$rigOut" | LC_ALL=C awk -v want="$1" '$1 == want' ; }   ## kind -- its lines
rigKindHas(){ rigKind "$1" | LC_ALL=C grep -c -F -- "$2" ; }                    ## kind, text -- lines holding it
rigStallLine(){ printf '%s\n' "$rigOut" | LC_ALL=C awk -v want="$1" '$1 == "stall" && $3 == want { print ; exit }' ; } ## run id -- its stall line
rigRunWord(){ printf '%s\n' "$rigOut" | LC_ALL=C awk -v want="$1" -v at="$2" '$1 == "run" && $3 == want { print $at ; exit }' ; }

## THE RIG'S RUNS. A run silent in its Wait for an hour with two items still pending is the stall. Its controls are that
## silence with nothing pending, and that pending work inside the bound. One run is working rather than waiting, so the
## bound is seen to read both verdicts.
rigRun rigstall magic-developer
rigMark rigstall 3600 "tool Wait"
rigTool rigstall 3600 Wait
rigPlan rigstall magic-developer "Run the checks you touch" "Write" "the handback"
rigStand rigstall
rigRun rigidle magic-developer
rigMark rigidle 3600 "tool Wait"
rigTool rigidle 3600 Wait
rigPlan rigidle magic-developer "Nothing left"
rigStand rigidle
rigRun rigfresh magic-developer
rigMark rigfresh 300 "tool Wait"
rigTool rigfresh 300 Wait
rigPlan rigfresh magic-developer "Just taken" "Still to do"
rigStand rigfresh
rigRun rigbusy magic-developer
rigMark rigbusy 3600 thinking
rigTool rigbusy 3600 Bash
rigPlan rigbusy magic-developer "Something long" "Still to do"
rigStand rigbusy
## The question to the human-owner whose asking run has a live parent coordinator, and the one whose parent has ended.
rigRun rigchild magic-developer "parent-session-id: rigpar"
rigAsk rigchild human-owner
rigRun rigpar magic-coordinator
rigStand rigpar
rigRun rigorph magic-developer "parent-session-id: rigdeadp"
rigAsk rigorph human-owner
rigRun rigdeadp magic-coordinator "status: spawn-succeeded"
## An ask to a member with no live run at all, which is the third part of the item.
rigRun riglone magic-developer
rigAsk riglone keeper-rig
sleep 2

echo "-- 1. a run waiting past the bound with items pending reads stall --"
rigOut="$( rigScan )"
rigAssert "the waiting run with pending items is a stall" "$( rigKindHas stall 'rigstall' )" "1"
rigAssert "and the line carries its age, its pending count and its item" \
	"$( rigStallLine rigstall | LC_ALL=C grep -o -e 'age=60m' -e 'pending=2' -e 'plan: Run the checks you touch' | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "3"
rigAssert "and the run itself still reads as a run, waiting" "$( rigRunWord rigstall 5 )" "waiting"

echo "-- 2. the controls: nothing pending, and inside the bound --"
rigAssert "the same silence with nothing pending is no stall" "$( rigKindHas stall 'rigidle' )" "0"
rigAssert "the same pending work inside the bound is no stall" "$( rigKindHas stall 'rigfresh' )" "0"

echo "-- 3. the bound is a setting, and both readings use it --"
rigAssert "at the default ten minutes the working run is stuck" "$( rigRunWord rigbusy 5 )" "stuck"
rigAssert "and it is a stall too, its items being pending" "$( rigKindHas stall 'rigbusy' )" "1"
rigOut="$( rigScan MDAT_SUPERVISE_STALL_SECONDS=7200 )"
rigAssert "at two hours the same run is active" "$( rigRunWord rigbusy 5 )" "active"
rigAssert "and no run is stuck" "$( rigKind run | LC_ALL=C grep -c ' stuck ' )" "0"
rigAssert "and no run is a stall" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^stall ' )" "0"
rigOut="$( rigScan MDAT_SUPERVISE_STALL_SECONDS=120 )"
rigAssert "at two minutes the five-minute wait is a stall" "$( rigKindHas stall 'rigfresh' )" "1"
rigAssert "with its age on the line" "$( rigKindHas stall 'age=5m' )" "1"

echo "-- 4. an ask to the human-owner that its parent can settle --"
rigOut="$( rigScan )"
rigAssert "the question with a live parent coordinator is a parent-ask" "$( rigKindHas parent-ask 'rigchild' )" "1"
rigAssert "and the line names the owner, the parent and its member" \
	"$( rigKindHas parent-ask 'human-owner' ):$( rigKindHas parent-ask 'parent rigpar' ):$( rigKindHas parent-ask 'magic-coordinator' )" "1:1:1"
rigAssert "the question whose parent has ended gets no parent-ask" "$( rigKindHas parent-ask 'rigorph' )" "0"
rigAssert "and both questions to the owner keep their plain ask line" "$( rigKindHas ask 'rigchild' ):$( rigKindHas ask 'rigorph' )" "1:1"

echo "-- 5. an ask nobody can answer, the line the scan has always printed --"
rigAssert "the question to a member with no run reads orphan-ask" "$( rigKindHas orphan-ask 'riglone' )" "1"
rigAssert "and it is not counted as an ask of the coordinator or the owner" "$( rigKindHas ask 'riglone' )" "0"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SUPERVISE STALL CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'SUPERVISE_STALL: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
