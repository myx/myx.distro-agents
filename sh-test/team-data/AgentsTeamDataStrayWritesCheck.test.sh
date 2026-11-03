#!/usr/bin/env bash
## Behavioural check on S12.10: a write into the team-data store that no run will ever commit
## reaches a commit anyway, without waiting for a person's --commit-pending.
## Offline: a temp git store in its own temp workspace; MDAT_DATA_ROOT and MMDAPP are both
## pointed there before anything runs, so the real store is never reached. The thread is off
## (MDAT_TEAM_DATA_COMMIT_THREAD=off), so each case reads its result at once rather than through
## a detached process. Red before the fix: cases 2, 3 and 4.
##   1. THE CONTROL, both directions: a path the one commit step is given reaches a commit, and a
##      path no entry names stays uncommitted. The instrument is shown able to see both.
##   2. THE POST-END TRANSCRIPT LINE: AgentsReviewRecord writes a verdict into the transcript of a
##      run that has already ended, so no milestone of that run will ever commit it.
##   3. THE REVIEW-UNSEEN MARK: AgentsToolsReviewUnseenEscalate writes a mark beside the review
##      item, and no commit follows.
##   4. A STALE index.lock IS NOT A FAILED WRITE: the add is refused by a lock no process holds, and
##      the commit is made once the repair has removed it. The repair's live-holder guard is
##      unchanged by this work and is not measured here.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPkg="$rigOrigin/myx/myx.distro-agents"
rigLib="$rigPkg/sh-lib"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -d "$rigLib/team-data" ] || rigRefuse "the tooling is not at the origin this workspace resolves: $rigLib"
command -v git > /dev/null || rigRefuse "git is not installed"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsTeamDataStrayWritesCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigData/board/review" "$rigData/audit/2026-11" "$rigTmp/home"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nNO_PROXY=*\n' > "$rigWs/.local/.agents/magic-team.agent.env"
git -C "$rigData" init -q || rigRefuse "could not init the rig store"
git -C "$rigData" config user.email rig@example.invalid
git -C "$rigData" config user.name rig
## A review item past its wait limit, and the transcript of the run it belongs to.
printf -- '---\ntype: dispatch\nowner: rig-member\nspawn-id: rigspawn1\nreview-by: magic-coordinator\nreview-since-epoch: 1000\n---\n\nrig item\n' \
	> "$rigData/board/review/dispatch-rig-unseen.md"
printf '2026-11-03T00:00:00Z START session rigspawn1\n' > "$rigData/audit/2026-11/session-rig-rigspawn1.log"
printf 'seed\n' > "$rigData/README.md"
git -C "$rigData" add -A && git -C "$rigData" commit -q -m seed || rigRefuse "could not seed the rig store"
mkdir -p "$rigWs/.local/agents/sessions/rigspawn1"
printf '%s\n' "$rigData/audit/2026-11/session-rig-rigspawn1.log" > "$rigWs/.local/agents/sessions/rigspawn1/transcript"
printf '%s\n' "$rigData" > "$rigWs/.local/agents/sessions/rigspawn1/data-root"

export MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDSC_CMD=rig MDAT_TEAM_DATA_COMMIT_THREAD=off MDAT_WORKSPACE_MODE=team-rig
unset MDAT_SPAWN_AGENT MDAT_SPAWN_SESSION_ID MDAT_SESSION_ID

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigClean(){ [ -z "$( git -C "$rigData" status --porcelain --untracked-files=all )" ] && printf clean || printf dirty ; }
rigSettle(){ git -C "$rigData" add -A && git -C "$rigData" commit -q -m "rig: settle" ; }
rigCommit(){ ## what it says, the path -- one commit through the one commit step, as the thread makes it
	( cd "$rigWs" || exit 1
	  . "$rigLib/team-data/AgentsTools.TeamDataCommit.include"
	  AgentsToolsTeamDataCommitPaths "$1" "$2" ) > "$rigTmp/commit.out" 2>&1
}

echo "-- 1. control, both directions --"
printf 'kept\n' > "$rigData/audit/stray-1.log"
rigCommit "rig: a path the entry names" "$rigData/audit/stray-1.log"
rigAssert "1. a path the entry names reaches a commit"  "$( rigClean )" clean
printf 'stray\n' > "$rigData/audit/stray-2.log"
rigAssert "1. a path no entry names stays uncommitted"  "$( rigClean )" dirty
rigSettle

echo "-- 2. the verdict of an ended run reaches a commit --"
( cd "$rigWs" || exit 1
  . "$rigLib/board/AgentsTools.ReviewFlow.include"
  AgentsReviewRecord rig-member dispatch-rig-unseen.md verdict "accepted: rig" VERDICT rigspawn1 ) > "$rigTmp/record.out" 2>&1
rigAssert "2. the verdict is written into the run's transcript" \
	"$( LC_ALL=C grep -c 'VERDICT item=dispatch-rig-unseen' "$rigData/audit/2026-11/session-rig-rigspawn1.log" )" 1
rigAssert "2. the transcript reaches a commit"          "$( rigClean )" clean
rigSettle

echo "-- 3. the review-unseen mark reaches a commit --"
( cd "$rigWs" || exit 1
  . "$rigLib/magic/AgentsTools.SpawnHousekeeping.include" < /dev/null > /dev/null 2>&1
  AgentsToolsReviewUnseenEscalate rig-member ) > "$rigTmp/unseen.out" 2>&1
rigAssert "3. the mark is written"                      "$( [ -f "$rigData/board/review/.unseen-dispatch-rig-unseen.md" ] && printf yes || printf no )" yes
rigAssert "3. the mark reaches a commit"                "$( rigClean )" clean
rigSettle

echo "-- 4. a stale index.lock is broken, and the write behind it commits --"
printf 'behind a stale lock\n' > "$rigData/audit/stray-3.log"
printf 'another git process, long gone, left this\n' > "$rigData/.git/index.lock"
rigCommit "rig: a write behind a stale lock" "$rigData/audit/stray-3.log"
rigAssert "4. the stale lock is removed"                "$( [ -e "$rigData/.git/index.lock" ] && printf present || printf gone )" gone
rigAssert "4. the write behind it reaches a commit"     "$( rigClean )" clean
rigAssert "4. the repair says what it did"              "$( LC_ALL=C grep -c 'stale index.lock was found with no git holding it' "$rigTmp/commit.out" )" 1

echo "-- 5. a live run's lines reach a commit on a bound, and not before it --"
## Two directions on one session: a bound far off leaves the line uncommitted, and a bound of zero
## carries it. The session is a live one, whose own milestone is what would carry it in a real run.
rigAppend(){ ## transcript commit bound in seconds
	( MDAT_TRANSCRIPT_COMMIT_SECONDS="$1"
	  . "$rigLib/session/AgentsTools.SessionTranscript.include"
	  AgentsTranscriptEvent rigspawn1 ROUND "" 0 n 1 ) > "$rigTmp/append.out" 2>&1
}
rigAppend 100000
rigAssert "5. a bound not yet reached leaves the line uncommitted" "$( rigClean )" dirty
rigAppend 0
rigAssert "5. a bound of zero carries the line to a commit"        "$( rigClean )" clean

echo "-- 6. a debt of several paths is carried whole by one retry --"
## A commit that failed with several paths owed the store all of them. One pass of the thread reads
## the whole debt, and the file of it is dropped only once a commit has carried it.
printf 'owed one\n' > "$rigData/audit/owed-1.log"
printf 'owed two\n' > "$rigData/audit/owed-2.log"
( cd "$rigWs" || exit 1
  . "$rigLib/team-data/AgentsTools.TeamDataCommit.include"
  AgentsToolsTeamDataCommitOwedAdd "$rigData/audit/owed-1.log" "$rigData/audit/owed-2.log" ) > "$rigTmp/owed.out" 2>&1
( cd "$rigWs" || exit 1
  MDAT_TEAM_DATA_COMMIT_THREAD=off bash "$rigPkg/sh-scripts/DistroAgentsTools.fn.sh" --intern-team-data-commit --one ) >> "$rigTmp/owed.out" 2>&1
rigAssert "6. one retry carries every owed path"  "$( rigClean )" clean
rigAssert "6. the debt is dropped once carried"   "$( [ -s "$rigWs/.local/agents/team-data-commit.owed" ] && printf kept || printf dropped )" dropped

echo "-- 7. a run's line reaches the store its transcript is in, not the store its process names --"
## A run may write a store other than its workspace's: its session's transcript names that store, and the
## process's own MDAT_DATA_ROOT names the workspace's. The bound follows the transcript, so the line lands.
rigAway="$rigTmp/away"
mkdir -p "$rigAway/audit/2026-11" "$rigWs/.local/agents/sessions/rigaway1"
git -C "$rigAway" init -q && git -C "$rigAway" config user.email rig@example.invalid && git -C "$rigAway" config user.name rig
printf 'away store\n' > "$rigAway/README.md"
printf '2026-11-03T00:00:00Z START session rigaway1\n' > "$rigAway/audit/2026-11/session-rig-rigaway1.log"
git -C "$rigAway" add -A && git -C "$rigAway" commit -q -m seed
printf '%s\n' "$rigAway/audit/2026-11/session-rig-rigaway1.log" > "$rigWs/.local/agents/sessions/rigaway1/transcript"
printf '%s\n' "$rigAway" > "$rigWs/.local/agents/sessions/rigaway1/data-root"
( MDAT_TRANSCRIPT_COMMIT_SECONDS=0
  . "$rigLib/session/AgentsTools.SessionTranscript.include"
  AgentsTranscriptEvent rigaway1 ROUND "" 0 n 1 ) > "$rigTmp/away.out" 2>&1
rigAssert "7. the line reaches a commit in the store its transcript is in" "$( [ -z "$( git -C "$rigAway" status --porcelain --untracked-files=all )" ] && printf clean || printf dirty )" clean

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ TEAM-DATA STRAY WRITES CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
echo "TEAM_DATA_STRAY_WRITES: OK ($rigPassCount assertions, offline, temp store)"
