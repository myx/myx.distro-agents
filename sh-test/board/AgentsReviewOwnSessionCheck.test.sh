#!/usr/bin/env bash
## Behavioural check on a run settling the review records of its own session: the session a run
## belongs to is the one it joined, whatever its own spawn id is.
## Held at the two places that read a session id against the running process:
##   sh-lib/board/AgentsTools.ItemReviewer.include, the rung below the duty;
##   sh-lib/board/AgentsTools.ItemDecisions.include, whether the caller is the reviewer.
## The fault: a joined run carries its own spawn id as its session id, so the session it joined reads
## as another session's. Its own live run then counts as a rung below it, and its own reviewer as
## another member's.
##   rows 1 and 2 are the fault, one at each place, both on a run that joined a session.
##   row 3 is the run that joined nothing, whose session is its own spawn id: its own live record must
##     not read as a rung below it either.
##   rows 4 and 5 are the controls: another session's live rung still comes first, and a rung whose
##     recorded run has ended is the duty's.
## Offline: the fake `curl` first on PATH logs a Slack call and opens no socket; the board, the
## sandbox records and the workspace are this rig's own temp tree; the live runs are stand-ins of
## this check alone, ended at its end. Never the live team data or .local/agents.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPkg="$rigOrigin/myx/myx.distro-agents"
rigFn="$rigPkg/sh-scripts/DistroAgentsTools.fn.sh"
rigFixture="$rigPkg/sh-test/check-fixtures/slack-send-identity-check.curl.stub.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigFn" ] || rigRefuse "the tooling is not at the origin this workspace resolves: $rigFn"
[ -f "$rigPkg/sh-lib/board/AgentsTools.ItemReviewer.include" ] || rigRefuse "the reviewer include is missing from the package"
[ -f "$rigPkg/sh-lib/board/AgentsTools.ItemDecisions.include" ] || rigRefuse "the item decisions include is missing from the package"
[ -f "$rigPkg/sh-lib/board/AgentsTools.InternOpReview.include" ] || rigRefuse "the review op include is missing from the package"
[ -f "$rigFixture" ] || rigRefuse "the fake curl fixture is missing: $rigFixture"
command -v ps > /dev/null || rigRefuse "ps is not on PATH"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigPkg/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsReviewOwnSessionCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigLivePids=""
trap 'rigProcSignalWithChildren TERM $rigLivePids ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigData="$rigTmp/data" rigHome="$rigTmp/home" rigSkills="$rigTmp/skills"
rigSpawned="$rigWs/.local/agents/spawned"
rigHost="$( hostname -s 2> /dev/null )" || rigHost="unknown"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigSpawned" "$rigTmp/bin" \
	"$rigData/inboxes/magic-coordinator/incoming" "$rigHome" "$rigSkills/magic-coordinator" || rigRefuse "could not create the rig"
printf 'rig\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"
printf 'rig\n' > "$rigSkills/magic-coordinator/magic-coordinator.armed.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nNO_PROXY=*\nWAIT_COLLECT_SECONDS=1\n' > "$rigWs/.local/.agents/magic-team.agent.env"
cp "$rigFixture" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl" || rigRefuse "could not install the fake curl"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## The board is written by its own writer, never a file by hand.
. "$rigPkg/sh-test/check-fixtures/rig-owner-writes.include.sh" || exit 1
rigOwnerWs="$rigWs" rigOwnerData="$rigData" rigOwnerHome="$rigHome" rigOwnerSkills="$rigSkills" rigOwnerOrigin="$rigOrigin" rigOwnerMember=magic-coordinator
rigOwnerBoardReady

## The spawn records of this rig. The fixture's own writer is not reachable: its `rigOwnerSpawnPut` loads
## AgentsTools.SessionStore.include, which does not define AgentsSpawnRecordWrite (that is in
## AgentsTools.SessionStore.Write.include), so it fails on live and in every copy of the tree. These write
## the records directly until that fixture loads the file that defines the writer. Every status here is one
## the tooling itself writes.
rigRecord(){ ## session the record names, its own spawn id, the member that owns it, extra header lines, body
	local recordDir="$rigSpawned/$2"
	mkdir -p "$recordDir" || rigRefuse "could not make the record folder of $2"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\ntracking-name: %s\nhost: %s\nowner: %s\n%s---\n\n%s\n' \
		"$1" "$2" "$1" "$rigHost" "$3" "${4:-}" "${5:-# rig record}" > "$recordDir/$2.spawn.md"
}
## One live run of this check's own: a process running as that run, recorded under its own spawn id. A record
## naming a session other than its own is a run that joined that session, which is the case here. Ended at the
## end of the check, and only while it is still the process this check started.
rigLiveRun(){ ## session the record names, the run's own spawn id, the member that runs there
	local livePid liveBegan
	bash -c 'sleep 240 ; :' rig-live-run --session-id "$2" > /dev/null 2>&1 < /dev/null &
	livePid=$!
	rigLivePids="$rigLivePids $livePid"
	rigProcNote "$livePid"
	disown "$livePid" 2> /dev/null || :
	liveBegan="$( PATH="$rigProcPath" ps -o lstart= -p "$livePid" 2> /dev/null | PATH="$rigProcPath" LC_ALL=C awk 'NF { $1 = $1 ; gsub( / /, "_" ) ; print ; exit ; }' )"
	[ -n "$liveBegan" ] || rigRefuse "the live run stand-in did not start, so nothing below would be measured"
	rigRecord "$1" "$2" "$3" "status: spawn-started
run-process: $livePid $liveBegan
"
}
## A run recorded and no longer living: its `run-process:` names a moment no process of that pid began at, so
## nothing answers for it as alive.
rigEndedRun(){ ## session the record names, its own spawn id, the member that owns it
	rigRecord "$1" "$2" "$3" "status: spawn-started
run-process: 1 Thu_Jan__1_00:00:00_1970
"
}
## An item's own run: its record names the reviewer it reports to, which is how the tooling reads it.
rigChildRun(){ ## spawn id, reports-to value
	rigRecord "$2" "$1" keeper-rig "status: spawn-started
reports-to: $2
"
}
## A review item: its name, its own run's spawn id, and its own header lines.
rigReview(){ ## item stem, its run's spawn id, extra header lines
	printf -- '---\ntype: dispatch\nowner: keeper-rig\nstatus: dispatch-started\nspawn-id: %s\n%s---\n\n# rig review item\n' \
		"$2" "${3:-}" | rigOwnerBoardPut review "$1.md"
}
## One verdict call of the tooling, from a run of the member given. Extra environment as NAME=value words in rigEnv.
rigEnv=()
rigVerdict(){ ## result file, the op's own words...
	local verdictOut="$1" ; shift
	: > "$rigTmp/calls"
	(
		cd "$rigWs" || exit 1
		env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" \
			MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" MDAT_DATA_ROOT="$rigData" \
			MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" RIG_SCENARIO="$rigTmp" MDAT_TEAM_DATA_COMMIT_THREAD=off \
			"${rigEnv[@]+"${rigEnv[@]}"}" bash "$rigFn" "$@"
	) > "$verdictOut" 2>&1
	printf '%s' "$?" > "$verdictOut.rc"
}
rigLoc(){ ## item stem -- the board state holding it, or not-found
	local stateDir
	for stateDir in "$rigData"/board/*/ ; do
		[ -f "$stateDir$1.md" ] && { basename "$stateDir" ; return 0 ; }
	done
	printf 'not-found'
}

## The subjects. A run that joined a session of another name is the case: `MDAT_SESSION_ID` is the session
## it belongs to, `MDAT_SPAWN_SESSION_ID` is its own id. Each row has an item of its own.
rigJoined=rig-joined-session
rigOwnRun=rig-own-run
rigSoloRun=rig-solo-run
rigRecord "$rigJoined" "$rigJoined" magic-coordinator "status: spawn-failed
"
rigLiveRun "$rigJoined" "$rigOwnRun" magic-coordinator
rigLiveRun "$rigSoloRun" "$rigSoloRun" magic-coordinator
rigLiveRun rig-other-session rig-other-run magic-coordinator
rigEndedRun rig-ended-session rig-ended-run magic-coordinator
rigChildRun rig-child-own-rung     "$rigJoined:magic-coordinator"
rigChildRun rig-child-reviewer     "$rigJoined:magic-coordinator"
rigChildRun rig-child-solo-rung    "$rigSoloRun:magic-coordinator"
rigChildRun rig-child-other-rung   "rig-other-session:magic-coordinator"
rigChildRun rig-child-ended-rung   "rig-ended-session:magic-coordinator"
rigReview task-rig-own-rung      rig-child-own-rung    ""
rigReview task-rig-reviewer      rig-child-reviewer    "review-by: $rigJoined
"
rigReview task-rig-solo-rung     rig-child-solo-rung   ""
rigReview task-rig-other-rung    rig-child-other-rung  ""
rigReview task-rig-ended-rung    rig-child-ended-rung  ""

echo "-- 1. the session a run joined is no rung below it --"
rigEnv=( MDAT_SPAWN_AGENT=magic-coordinator MDAT_SPAWN_SESSION_ID="$rigOwnRun" MDAT_SESSION_ID="$rigJoined" )
rigVerdict "$rigTmp/c1" --accept-review --team-member magic-coordinator task-rig-own-rung
rigAssert "the duty settles the item its own session's run reports to"  "$( cat "$rigTmp/c1.rc" ):$( rigLoc task-rig-own-rung )" 0:processed

echo "-- 2. the session a run joined is the session whose reviewer it is --"
rigEnv=( MDAT_SPAWN_AGENT=keeper-myx MDAT_SPAWN_SESSION_ID=rig-own-run-b MDAT_SESSION_ID="$rigJoined" )
rigVerdict "$rigTmp/c2" --accept-review --team-member keeper-myx task-rig-reviewer
rigAssert "the joining member reviews the item its own session reviews" "$( cat "$rigTmp/c2.rc" ):$( rigLoc task-rig-reviewer )" 0:processed

echo "-- 3. a run's own spawn id is its own session too --"
rigEnv=( MDAT_SPAWN_AGENT=magic-coordinator MDAT_SPAWN_SESSION_ID="$rigSoloRun" )
rigVerdict "$rigTmp/c3" --accept-review --team-member magic-coordinator task-rig-solo-rung
rigAssert "the run that joined nothing settles its own item"           "$( cat "$rigTmp/c3.rc" ):$( rigLoc task-rig-solo-rung )" 0:processed

echo "-- 4. the controls: every case the fix leaves as it was --"
rigEnv=( MDAT_SPAWN_AGENT=magic-coordinator MDAT_SPAWN_SESSION_ID="$rigOwnRun" MDAT_SESSION_ID="$rigJoined" )
rigVerdict "$rigTmp/c4" --accept-review --team-member magic-coordinator task-rig-other-rung
rigAssert "another session's live rung still comes first"              "$( cat "$rigTmp/c4.rc" ):$( rigLoc task-rig-other-rung )" 1:review
rigVerdict "$rigTmp/c5" --accept-review --team-member magic-coordinator task-rig-ended-rung
rigAssert "a rung whose recorded run has ended is the duty's"          "$( cat "$rigTmp/c5.rc" ):$( rigLoc task-rig-ended-rung )" 0:processed

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ REVIEW OWN SESSION CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'REVIEW_OWN_SESSION: OK (%d assertions, offline)\n' "$rigPassCount"
