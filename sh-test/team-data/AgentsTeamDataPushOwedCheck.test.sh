#!/usr/bin/env bash
## Behavioural check on the team-data push's debt: a push that cannot take the
## team-data-push lock is OWED, never skipped. The case is shaped like the report of the
## owner -- local commits of the team data sitting unmerged while a lock was supposed to
## make that impossible. One writer holds the lock for the whole of the first close, so
## the close cannot push; the commit stays local, and the close must say it is owed and
## record the debt rather than return as though it had published. The remote then moves
## from elsewhere, as it does over weeks. With the holder gone, the next close must not
## skip: it merges origin in, publishes every local commit, and clears the debt. The
## invariant checked is the one that failed: no local commit survives a sync cycle.
## Offline: bare remotes and stores of this rig's own mktemp tree only, no ssh.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigMyx="$MDLT_ORIGIN/myx/myx.common/os-myx.common/host/tarball/share/myx.common"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
[ -f "$rigMyx/bin/git/cloneSync.Common" ] || rigRefuse "myx.common git/cloneSync is missing: $rigMyx"
command -v git > /dev/null || rigRefuse "git is not installed"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsTeamDataPushOwedCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
export GIT_AUTHOR_NAME=rig GIT_AUTHOR_EMAIL=rig@example.invalid GIT_COMMITTER_NAME=rig GIT_COMMITTER_EMAIL=rig@example.invalid
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

rigWs="$rigTmp/ws"
rigStore="$rigTmp/store"
rigRemoteGit="$rigTmp/owed.git"
rigLock="$rigWs/.local/agents/locks/team-data-push"
rigOwed="$rigWs/.local/agents/team-data-push.owed"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigCount(){ ## file, fixed text
	LC_ALL=C grep -c -F -- "$2" "$1" 2> /dev/null || :
}

mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigTmp/bin"
printf 'TEAM_DATA_GIT_REMOTE=%s\n' "$rigRemoteGit" > "$rigWs/.local/.agents/magic-team.agent.env"

## One bare remote with one seed commit on main, then the store it is cloned into.
git init -q --bare "$rigRemoteGit" || rigRefuse "could not init the bare remote"
git -C "$rigRemoteGit" symbolic-ref HEAD refs/heads/main
rm -rf "$rigTmp/seed" ; git init -q "$rigTmp/seed" && git -C "$rigTmp/seed" symbolic-ref HEAD refs/heads/main
printf 'seed\n' > "$rigTmp/seed/README.md"
git -C "$rigTmp/seed" add -A && git -C "$rigTmp/seed" commit -q -m seed || rigRefuse "could not seed the remote"
git -C "$rigTmp/seed" push -q "$rigRemoteGit" main 2> /dev/null || rigRefuse "could not push the seed"
git clone -q "$rigRemoteGit" "$rigStore" 2> /dev/null || rigRefuse "could not clone the store"

## Runs a piece of shell with the team-data functions at hand, as the tooling has them,
## under the rig's own workspace, store and myx.common. The dispatcher is the rig's own.
rigRun(){ ## result file, shell text
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigStore" MDLT_ORIGIN="$MDLT_ORIGIN" MYXROOT="$rigMyx" \
		GIT_AUTHOR_NAME=rig GIT_AUTHOR_EMAIL=rig@example.invalid GIT_COMMITTER_NAME=rig GIT_COMMITTER_EMAIL=rig@example.invalid \
		GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
		RIG_TMP="$rigTmp" RIG_FN="$rigFn" RIG_TEXT="$2" \
		bash -c '
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/store) ;; *) echo "RIG-GUARD: store outside the rig tree" >&2 ; exit 99 ;; esac
			MDSC_CMD=DistroAgentsTools
			DistroAgentsTools(){ bash "$RIG_FN" "$@" ; }
			cd "$MMDAPP" || exit 98
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.TeamDataCommit.include"
			eval "$RIG_TEXT"
		' > "$1" 2> "$1.err"
	printf '%s' "$?" > "$1.rc"
}
rigRemoteHead(){ git -C "$rigRemoteGit" rev-parse -q --verify refs/heads/main 2> /dev/null || printf none ; }
rigAhead(){ git -C "$rigStore" rev-list --count "refs/remotes/origin/main..HEAD" 2> /dev/null || printf '?' ; }
rigBehind(){ git -C "$rigStore" rev-list --count "HEAD..refs/remotes/origin/main" 2> /dev/null || printf '?' ; }

echo "-- a local commit, made while another writer holds the push lock --"
## The four board moves of the report are exactly this: a commit by a writer that never
## pushes, with the close push to follow.
printf 'board move\n' > "$rigStore/board-move.md"
## Another writer's push holds the lock for the whole of this process's first close.
## It names this process, which is alive, so the lock is a live holder and is not broken.
mkdir -p "${rigLock%/*}"
ln -s "$$" "$rigLock"
rigRun "$rigTmp/p1" 'AgentsToolsTeamDataCommitPaths "board move" "$MDAT_DATA_ROOT/board-move.md" ; AgentsToolsTeamDataPushIfAhead "the check close one"'
rigHeadOne="$( git -C "$rigStore" rev-parse HEAD )"
rigAssert "the commit landed locally"                            "$( git -C "$rigStore" log -1 --format=%s )" "* board move"
rigAssert "the close reports success and says the push is owed"  "$( cat "$rigTmp/p1.rc" ):$( rigCount "$rigTmp/p1.err" "the push is OWED" )" "0:1"
rigAssert "the debt is recorded, not left to a hoped-for close"  "$( [ -e "$rigOwed" ] && printf owed || printf none )" "owed"
rigAssert "nothing reached the remote, as it cannot"             "$( rigRemoteHead ):$( rigAhead )" "$( git -C "$rigTmp/seed" rev-parse HEAD ):1"

echo "-- the holder holds through a second close, the remote moves, and the debt is paid rather than skipped again --"
## The same report over again: the lock is held for the whole of the next close too, so a
## close that is content to skip would skip for ever. The holder lets go at 34s, past the
## 30 tries a first close spends but inside the wait a close that owes a push will make;
## the owed store must then merge the moved remote in and publish, not skip a second time.
rm -f "$rigLock"
rm -rf "$rigTmp/adv" ; git clone -q "$rigRemoteGit" "$rigTmp/adv" 2> /dev/null || rigRefuse "could not clone to advance the remote"
printf 'from elsewhere\n' > "$rigTmp/adv/elsewhere.md"
git -C "$rigTmp/adv" add -A && git -C "$rigTmp/adv" commit -q -m "elsewhere" || rigRefuse "could not advance the remote"
git -C "$rigTmp/adv" push -q origin main 2> /dev/null || rigRefuse "could not push the advance"
ln -s "$$" "$rigLock"
( sleep 34 ; rm -f "$rigLock" ) &
rigNudge=$!
rigRun "$rigTmp/p2" 'AgentsToolsTeamDataPushIfAhead "the check close two"'
wait "$rigNudge" 2> /dev/null || :
rm -f "$rigLock"
rigAssert "the next close no longer skips: it waits and pays"    "$( cat "$rigTmp/p2.rc" ):$( rigCount "$rigTmp/p2.err" "OWED" )" "0:0"
rigAssert "the remote's branch is the store's head, read back"   "$( rigRemoteHead )" "$( git -C "$rigStore" rev-parse HEAD )"
rigAssert "the local commit survived and is on the remote"       "$( git -C "$rigStore" merge-base --is-ancestor "$rigHeadOne" HEAD && printf kept || printf lost )" "kept"
rigAssert "the remote's own commit was merged in, no rebase"     "$( git -C "$rigStore" rev-list --merges -n 1 --parents HEAD | wc -w | LC_ALL=C tr -d ' ' )" "3"
rigAssert "the store is in step: nothing ahead, nothing behind"  "$( rigAhead ):$( rigBehind )" "0:0"
rigAssert "and the debt is cleared, being verified paid"         "$( [ -e "$rigOwed" ] && printf owed || printf paid )" "paid"

echo "-- control: an in-step store with no debt says nothing and pushes nothing --"
rigRun "$rigTmp/p3" 'AgentsToolsTeamDataPushIfAhead "the check close three"'
rigAssert "no word on a store in step with no debt owed"         "$( cat "$rigTmp/p3" "$rigTmp/p3.err" | wc -c | LC_ALL=C tr -d ' ' )" "0"
rigAssert "and no debt is invented"                              "$( [ -e "$rigOwed" ] && printf owed || printf none )" "none"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ TEAM DATA PUSH OWED CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'TEAM_DATA_PUSH_OWED: OK (%d assertions, offline, temp stores only)\n' "$rigPassCount"
