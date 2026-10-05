#!/usr/bin/env bash
## Behavioural check that every tooling writer outside the board, inbox and item ops
## commits what it writes into the team-data store: after each one the store is clean
## and holds one more commit. Also checks the dirty-store warning speaks when it should
## and stays silent when it should.
## Offline: a temp git store in its own temp workspace; MDAT_DATA_ROOT and MMDAPP are
## both pointed there before anything runs, so the real store is never reached.
## The spawn proxy's close commit is covered at the helper it calls, with a log path
## of the same shape; the proxy's own exit paths need a fake console and are not run here.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
command -v git > /dev/null || rigRefuse "git is not installed"

rigTmp="$( mktemp -d -t AgentsTeamDataWritersCommitCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigStore="$rigTmp/store"
mkdir -p "$rigWs/.local" "$rigStore/audit" "$rigStore/inboxes/magic-coordinator" "$rigStore/inboxes/magic-tester"
git -C "$rigStore" init -q || rigRefuse "could not init the temp store"
git -C "$rigStore" config user.email rig@example.invalid
git -C "$rigStore" config user.name rig
printf 'seed\n' > "$rigStore/README.md"
git -C "$rigStore" add -A && git -C "$rigStore" commit -q -m seed || rigRefuse "could not seed the temp store"

export MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigStore" MDLT_ORIGIN
[ "$MDAT_DATA_ROOT" = "$rigStore" ] || rigRefuse "MDAT_DATA_ROOT is not the temp store"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 )) ; printf '  PASS  %s\n' "$1"
	else
		rigFailCount=$(( rigFailCount + 1 )) ; printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigCommits(){ git -C "$rigStore" rev-list --count HEAD ; }
rigClean(){ [ -z "$( git -C "$rigStore" status --porcelain --untracked-files=all )" ] && printf clean || printf dirty ; }
rigBefore=0
rigStep(){ rigBefore="$( rigCommits )" ; }
rigAfter(){ ## writer name
	rigAssert "$1: the store is clean afterwards"     "$( rigClean )" clean
	rigAssert "$1: exactly one new commit"             "$(( $( rigCommits ) - rigBefore ))" 1
}

echo "-- writer: --magic-sweep-state-upsert --"
rigStep
printf 'last_swept_ts: 1700000000.000100\n' | "$rigFn" --magic-sweep-state-upsert magic-tester > "$rigTmp/out" 2>&1
rigAfter "sweep-state"

echo "-- writer: --magic-team-roster-upsert --"
rigStep
printf '# Roster\n\nmember one\n' | "$rigFn" --magic-team-roster-upsert magic-coordinator > "$rigTmp/out" 2>&1
rigAfter "team-roster"

echo "-- writer: --member-append-session-transcript --"
rigStep
"$rigFn" --member-append-session-transcript magic-tester --speaker rig --timestamp 2026-09-29T00:00:00Z \
	--message "one line" --transcript-name transcript-2026-09-29-rig.md --workspace-root "$rigWs" --create > "$rigTmp/out" 2>&1
rigAfter "session-transcript"

echo "-- writer: output-style refusal log --"
rigStep
( MDSC_CMD=rig ; . "$rigHere/AgentsTools.OutputStyle.include" ; printf 'One clause; another clause.\n' | AgentsToolsOutputStyleRefusal magic-tester "" rig-destination "" semicolon ) > "$rigTmp/out" 2>&1
rigAssert "output-style: a refusal row was written" "$( ls "$rigStore"/audit/refusal-*-output-style.md > /dev/null 2>&1 && printf yes || printf no )" yes
rigAfter "output-style refusal"

echo "-- writer: spawn-proxy output log, at the helper its close calls --"
rigStep
mkdir -p "$rigStore/audit/2026-09"
printf 'console output\n' > "$rigStore/audit/2026-09/spawn-proxy-rig.output.log"
( MDSC_CMD=rig ; . "$rigHere/AgentsTools.TeamDataCommit.include" ; AgentsToolsTeamDataCommitPaths "agent-spawn-proxy output, rig" "$rigStore/audit/2026-09/spawn-proxy-rig.output.log" ) > "$rigTmp/out" 2>&1
rigAfter "spawn-proxy output log"

echo "-- the helper refuses a path outside the store --"
rigStep
printf 'outside\n' > "$rigTmp/outside.txt"
( MDSC_CMD=rig ; . "$rigHere/AgentsTools.TeamDataCommit.include" ; AgentsToolsTeamDataCommitPaths "rig" "$rigTmp/outside.txt" ) > "$rigTmp/out" 2>&1
rigAssert "outside path: no commit"                  "$(( $( rigCommits ) - rigBefore ))" 0
rigAssert "outside path: a warning names it"          "$( grep -q 'not under the team-data store' "$rigTmp/out" && printf yes || printf no )" yes

echo "-- the dirty-store warning --"
( MDSC_CMD=rig ; . "$rigHere/AgentsTools.TeamDataCommit.include" ; AgentsToolsTeamDataDirtyWarning "rig clean" ) > "$rigTmp/out" 2>&1
rigAssert "clean store: the warning stays silent"     "$( [ -s "$rigTmp/out" ] && printf spoke || printf silent )" silent
printf 'stray\n' > "$rigStore/audit/stray.md"
( MDSC_CMD=rig ; . "$rigHere/AgentsTools.TeamDataCommit.include" ; AgentsToolsTeamDataDirtyWarning "rig dirty" ) > "$rigTmp/out" 2>&1
rigAssert "dirty store: the warning names the count"  "$( grep -q 'holds 1 uncommitted path' "$rigTmp/out" && printf yes || printf no )" yes
rigAssert "dirty store: the warning names the path"   "$( grep -q 'audit/stray.md' "$rigTmp/out" && printf yes || printf no )" yes

rm -f "$rigStore/audit/stray.md"

echo "-- board-rename: the old name's removal is committed too --"
mkdir -p "$rigStore/board/backlog"
printf -- '---\nowner: rig\n---\nbody\n' > "$rigStore/board/backlog/rig-old.md"
git -C "$rigStore" add -A && git -C "$rigStore" commit -q -m "seed rig-old"
"$rigFn" --intern-op-board-rename rig-old.md rig-new.md --do-not-track > "$rigTmp/out" 2>&1
rigAssert "board-rename: the item moved"              "$( [ -f "$rigStore/board/backlog/rig-new.md" ] && [ ! -e "$rigStore/board/backlog/rig-old.md" ] && printf yes || printf no )" yes
rigAssert "board-rename: the store is clean afterwards" "$( rigClean )" clean
rigAssert "board-rename: git no longer holds the old name" "$( [ -z "$( git -C "$rigStore" ls-files -- board/backlog/rig-old.md )" ] && printf yes || printf no )" yes

echo "-- board-trash: an item git never knew is deleted without an error --"
printf -- '---\nowner: rig\n---\nuntracked\n' > "$rigStore/board/backlog/rig-untracked.md"
"$rigFn" --magic-heartbeat-board-item-trash magic-coordinator backlog rig-untracked.md > "$rigTmp/out" 2>&1
rigTrashRc=$?
rigAssert "board-trash untracked: exit 0"             "$rigTrashRc" 0
rigAssert "board-trash untracked: the item is gone"   "$( [ -e "$rigStore/board/backlog/rig-untracked.md" ] && printf present || printf gone )" gone
rigAssert "board-trash untracked: the store is clean" "$( rigClean )" clean
rigAssert "board-trash untracked: history keeps the item" "$( git -C "$rigStore" log --all --format=%H -- board/backlog/rig-untracked.md | LC_ALL=C awk 'END { print NR ; }' )" 2
## The keep-commit fails after its add succeeds: the item must stay, with no deletion.
printf -- '---\nowner: rig\n---\nkeep me\n' > "$rigStore/board/backlog/rig-keep.md"
printf '#!/bin/sh\nexit 1\n' > "$rigStore/.git/hooks/pre-commit" && chmod +x "$rigStore/.git/hooks/pre-commit"
rigKeepBefore="$( rigCommits )"
"$rigFn" --magic-heartbeat-board-item-trash magic-coordinator backlog rig-keep.md > "$rigTmp/out" 2>&1
rigKeepRc=$?
rm -f "$rigStore/.git/hooks/pre-commit"
rigAssert "board-trash, keep-commit fails: rc 1, item kept, no new commit" "$rigKeepRc:$( [ -f "$rigStore/board/backlog/rig-keep.md" ] && printf kept || printf lost ):$(( $( rigCommits ) - rigKeepBefore ))" "1:kept:0"
git -C "$rigStore" add -A && git -C "$rigStore" commit -q -m "rig: settle rig-keep"
printf -- '---\nowner: rig\n---\ntracked\n' > "$rigStore/board/backlog/rig-tracked.md"
git -C "$rigStore" add -A && git -C "$rigStore" commit -q -m "seed rig-tracked"
"$rigFn" --magic-heartbeat-board-item-trash magic-coordinator backlog rig-tracked.md > "$rigTmp/out" 2>&1
rigAssert "board-trash tracked (control): exit 0, gone, clean" "$?:$( [ -e "$rigStore/board/backlog/rig-tracked.md" ] && printf present || printf gone ):$( rigClean )" "0:gone:clean"
rigAssert "board-trash tracked (control): add plus delete in history" "$( git -C "$rigStore" log --all --format=%H -- board/backlog/rig-tracked.md | LC_ALL=C awk 'END { print NR ; }' )" 2

echo "-- push at a close point: a temp bare origin named by TEAM_DATA_GIT_REMOTE --"
rigBare="$rigTmp/origin.git"
git init -q --bare "$rigBare" || rigRefuse "could not init the temp bare origin"
mkdir -p "$rigWs/.local/.agents"
printf 'TEAM_DATA_GIT_REMOTE=%s\n' "$rigBare" > "$rigWs/.local/.agents/magic-team.agent.env"
git -C "$rigStore" remote add origin "$rigBare"
rigBranch="$( git -C "$rigStore" rev-parse --abbrev-ref HEAD )"
git -C "$rigStore" push -q -u origin "$rigBranch" 2>/dev/null || rigRefuse "could not seed the temp bare origin"
rigPush(){ ( MDSC_CMD=rig ; . "$rigFn" ; . "$rigHere/AgentsTools.TeamDataCommit.include" ; AgentsToolsTeamDataPushIfAhead "rig close" ) > "$rigTmp/out" 2>&1 ; }
rigOriginHead(){ git --git-dir="$rigBare" rev-parse "refs/heads/$rigBranch" 2>/dev/null ; }

rigPush
rigAssert "nothing ahead: no push is attempted"       "$( grep -q 'pushed\|push failed\|rejected' "$rigTmp/out" && printf attempted || printf none )" none

printf 'more\n' | "$rigFn" --magic-team-roster-upsert magic-coordinator > /dev/null 2>&1
printf 'more again\n' | "$rigFn" --magic-team-roster-upsert magic-coordinator > /dev/null 2>&1
rigAssert "two writer commits sit local before the close" "$( git -C "$rigStore" rev-list --count "origin/$rigBranch..HEAD" )" 2
rigPush
rigAssert "close: origin equals local head"           "$( rigOriginHead )" "$( git -C "$rigStore" rev-parse HEAD )"
rigAssert "close: the push and its read-back are stated" "$( grep -q "team-data pushed, origin/$rigBranch = " "$rigTmp/out" && printf yes || printf no )" yes

echo "-- a rejected push: origin moved; integrated, pushed, nothing lost --"
rigOther="$rigTmp/other"
git clone -q "$rigBare" "$rigOther" 2>/dev/null && git -C "$rigOther" config user.email rig@example.invalid && git -C "$rigOther" config user.name rig
printf 'from another host\n' > "$rigOther/other-host.md"
git -C "$rigOther" add -A && git -C "$rigOther" commit -q -m other && git -C "$rigOther" push -q origin HEAD 2>/dev/null
printf 'local after\n' | "$rigFn" --magic-team-roster-upsert magic-coordinator > /dev/null 2>&1
rigLocalBefore="$( git -C "$rigStore" rev-parse HEAD )"
rigPush
rigAssert "rejected: origin now holds the local commit" "$( git --git-dir="$rigBare" merge-base --is-ancestor "$rigLocalBefore" "refs/heads/$rigBranch" && printf yes || printf no )" yes
rigAssert "rejected: the other host's file is kept"    "$( [ -f "$rigStore/other-host.md" ] && printf yes || printf no )" yes
rigAssert "rejected: origin equals local head"         "$( rigOriginHead )" "$( git -C "$rigStore" rev-parse HEAD )"
## The main loop's next pull is clonePull, fast-forward only: after the integration it must succeed.
printf 'later on the other host\n' > "$rigOther/other-host-2.md"
git -C "$rigOther" pull -q --no-rebase origin "$rigBranch" 2>/dev/null ; git -C "$rigOther" add -A && git -C "$rigOther" commit -q -m other2 && git -C "$rigOther" push -q origin HEAD 2>/dev/null
rigAssert "rejected: the main loop's next clonePull fast-forwards" "$( "$MYXROOT/bin/git/clonePull.Common" "$rigStore" "$rigBare" "$rigBranch" > /dev/null 2>&1 && [ -f "$rigStore/other-host-2.md" ] && printf ok || printf stale )" ok

echo "-- an unreachable origin: warned, commits kept, a later close succeeds --"
git -C "$rigStore" remote set-url origin "$rigTmp/missing.git"
printf 'TEAM_DATA_GIT_REMOTE=%s\n' "$rigTmp/missing.git" > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'while offline\n' | "$rigFn" --magic-team-roster-upsert magic-coordinator > /dev/null 2>&1
rigOffline="$( git -C "$rigStore" rev-parse HEAD )"
rigPush
rigAssert "unreachable: a stated warning"              "$( grep -q 'team-data push failed' "$rigTmp/out" && printf yes || printf no )" yes
rigAssert "unreachable: the local commit is kept"      "$( git -C "$rigStore" rev-parse HEAD )" "$rigOffline"
git -C "$rigStore" remote set-url origin "$rigBare"
printf 'TEAM_DATA_GIT_REMOTE=%s\n' "$rigBare" > "$rigWs/.local/.agents/magic-team.agent.env"
rigPush
rigAssert "unreachable, then back: the next close pushes it" "$( rigOriginHead )" "$rigOffline"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ TEAM-DATA WRITERS COMMIT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
echo "TEAM_DATA_WRITERS_COMMIT: OK ($rigPassCount assertions, offline, temp store)"
