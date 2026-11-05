#!/usr/bin/env bash
## Behavioural check on S12.4, the race between the board resync and the writers it shares the store with:
## a duty start met a writer's uncommitted change and failed with LOCK_UNCHECKABLE, and a retry a minute
## later passed. Since the on-demand team-data thread landed, a writer writes its files and leaves an entry:
## the thread's commit of that entry can be a moment away, and git refuses to move a working tree that holds
## an uncommitted change to a file origin changed too.
## Held:
##   1. THE RACE: origin changed an item, a writer here changed the same item and left its entry, and the
##      resync must still succeed. The writers are settled first, so the tree the resync moves holds their
##      writes as commits.
##   2. CONTROL, BOTH DIRECTIONS: an in-step store resyncs leaving its history alone, and a store behind its
##      origin with nothing waiting is brought level. The instrument sees both.
##   3. A RIG'S OWN FILE IS NEVER COMMITTED INTO THE STORE: a data folder with no repository of its own,
##      sitting inside a store that is a repository, is not the store. The control is the real item beside
##      it, which does reach a commit.
##   4. A PATH GIT WOULD QUOTE IS SETTLED WHOLE: a store holding one changed tracked path whose name has a
##      space in it resyncs, and that path reaches a commit under its own name. The plain `git status
##      --porcelain` wraps such a path in quotes, and the settle then handed the pieces of it to a commit
##      that refused each as not under the store, so the resync never came level.
## Offline: a bare remote and a store of this rig's own folder; no ssh, no network.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigMyx="$MDLT_ORIGIN/myx/myx.common/os-myx.common/host/tarball/share/myx.common"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPkg/sh-scripts/DistroAgentsTools.fn.sh" ] || rigRefuse "the tooling is not at the origin this workspace resolves: $rigPkg"
[ -f "$rigMyx/bin/git/cloneSync.Common" ] || rigRefuse "myx.common git/cloneSync is missing: $rigMyx"
command -v git > /dev/null || rigRefuse "git is not installed"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsTeamDataResyncRaceCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
export GIT_AUTHOR_NAME=rig GIT_AUTHOR_EMAIL=rig@example.invalid
export GIT_COMMITTER_NAME=rig GIT_COMMITTER_EMAIL=rig@example.invalid
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
trap 'rm -rf -- "$rigTmp"' EXIT

rigWs="$rigTmp/ws"
rigRemoteGit="$rigTmp/team.git"
rigStore="$rigTmp/store"
rigShared="board/running/task-20260101T0005Z-shared.md"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/home" "$rigTmp/bin"
printf 'TEAM_DATA_GIT_REMOTE=%s\n' "$rigRemoteGit" > "$rigWs/.local/.agents/magic-team.agent.env"

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
## A piece of shell run as the tooling has it, against the rig's own workspace and store.
rigRun(){ ## result file, shell text
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigStore" MDLT_ORIGIN="$MDLT_ORIGIN" MYXROOT="$rigMyx" MDSC_CMD=DistroAgentsTools \
		GIT_AUTHOR_NAME=rig GIT_AUTHOR_EMAIL=rig@example.invalid GIT_COMMITTER_NAME=rig GIT_COMMITTER_EMAIL=rig@example.invalid \
		GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
		RIG_TMP="$rigTmp" RIG_TEXT="$2" \
		bash -c '
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/store) ;; *) echo "RIG-GUARD: store outside the rig tree" >&2 ; exit 99 ;; esac
			cd "$MMDAPP" || exit 98
			eval "$RIG_TEXT"
		' > "$1" 2> "$1.err"
	printf '%s' "$?" > "$1.rc"
}
## A bare remote with one item and a README, and the store cloned from it.
rigSeed(){
	rm -rf "$rigRemoteGit" "$rigTmp/seed" "$rigStore"
	git init -q --bare "$rigRemoteGit" || rigRefuse "could not init the bare remote"
	git -C "$rigRemoteGit" symbolic-ref HEAD refs/heads/main
	git init -q "$rigTmp/seed" && git -C "$rigTmp/seed" symbolic-ref HEAD refs/heads/main
	mkdir -p "$rigTmp/seed/board/running"
	printf 'item one\n' > "$rigTmp/seed/$rigShared"
	printf 'seed\n' > "$rigTmp/seed/README.md"
	git -C "$rigTmp/seed" add -A && git -C "$rigTmp/seed" commit -q -m seed || rigRefuse "could not seed the remote"
	git -C "$rigTmp/seed" push -q "$rigRemoteGit" main 2> /dev/null || rigRefuse "could not push the seed"
	git clone -q "$rigRemoteGit" "$rigStore" 2> /dev/null || rigRefuse "could not clone the store"
}
## Another host commits a change to a path, from a clone of the store's own remote.
rigElsewhere(){ ## path, the text it writes there
	rm -rf "$rigTmp/away"
	git clone -q "$rigRemoteGit" "$rigTmp/away" 2> /dev/null || rigRefuse "could not clone the remote"
	mkdir -p "$rigTmp/away/$( dirname "$1" )"
	printf '%s\n' "$2" > "$rigTmp/away/$1"
	git -C "$rigTmp/away" add -A && git -C "$rigTmp/away" commit -q -m "elsewhere: $1" || rigRefuse "could not commit elsewhere"
	git -C "$rigTmp/away" push -q origin main 2> /dev/null || rigRefuse "could not push elsewhere"
	git -C "$rigStore" fetch -q origin 2> /dev/null || :
}
## A writer's write that has happened and whose commit has not: the file, and the entry it leaves for the
## one thread. The entry's shape is the thread's own: a context line, then the paths.
rigWriterLeft(){ ## path, the text it wrote there
	local leftQueue leftEntry
	leftQueue="$( git -C "$rigStore" rev-parse --absolute-git-dir )/team-data-commit"
	mkdir -p "$leftQueue" "$rigStore/$( dirname "$1" )"
	printf '%s\n' "$2" > "$rigStore/$1"
	leftEntry="$( mktemp "$leftQueue/write.XXXXXX" )" || rigRefuse "could not make the writer's entry"
	printf '\n%s\n%s\n' "rig writer" "$rigStore/$1" > "$leftEntry"
	mv -f "$leftEntry" "$leftEntry.entry"
}
## The board resync a duty start runs, as AgentsToolsAdvanceCloneSync makes it.
rigResync(){ ## result name
	rigRun "$1" '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/magic/AgentsTools.RoutineLock.include" ;
		AgentsToolsAdvanceCloneSync "$MDAT_DATA_ROOT" "$( LC_ALL=C sed -n "s/^TEAM_DATA_GIT_REMOTE=//p" "$MMDAPP/.local/.agents/magic-team.agent.env" )" main ;
		printf "RESYNC-RC=%s\n" "$?"'
}
rigResyncRc(){ LC_ALL=C sed -n 's/^RESYNC-RC=//p' "$1" | LC_ALL=C sed -n 1p ; }
rigBehind(){ git -C "$rigStore" rev-list --count HEAD..origin/main 2> /dev/null || printf '?' ; }
rigDirty(){ git -C "$rigStore" status --porcelain | LC_ALL=C grep -c . ; }

echo "-- 1. the race: origin moved an item, and a writer here changed the same item and left its entry --"
rigSeed
rigElsewhere "$rigShared" 'item one, moved by another rig'
rigWriterLeft "$rigShared" 'item one, moved here and not yet committed'
rigAssert "control: the store is behind its origin, and the writer's change is waiting" "$( rigBehind ):$( rigDirty )" "1:1"
rigResync "$rigTmp/race"
rigAssert "1. the resync succeeds: the writers were settled, then the tree was moved" \
	"$( rigResyncRc "$rigTmp/race" ):$( rigCount "$rigTmp/race.err" 'LOCK_UNCHECKABLE' )" "0:0"
rigAssert "1. the writer's own change is a commit, and reached origin" \
	"$( git -C "$rigStore" log --format=%s | LC_ALL=C grep -c -F 'rig writer' ):$( git -C "$rigRemoteGit" show "main:$rigShared" | LC_ALL=C grep -c -F 'moved here' )" "1:1"
rigAssert "1. and the store is level with its origin, holding nothing uncommitted" "$( rigBehind ):$( rigDirty )" "0:0"

echo "-- 2. control: nothing waiting, both directions --"
rigSeed
rigBefore="$( git -C "$rigStore" rev-list --count HEAD )"
rigResync "$rigTmp/level"
rigAssert "2. an in-step store resyncs, its history untouched" \
	"$( rigResyncRc "$rigTmp/level" ):$( git -C "$rigStore" rev-list --count HEAD )" "0:$rigBefore"
rigElsewhere "board/running/task-20260101T0006Z-elsewhere.md" 'from elsewhere'
rigResync "$rigTmp/behind"
rigAssert "2. a store behind its origin and holding nothing is brought level" "$( rigResyncRc "$rigTmp/behind" ):$( rigBehind )" "0:0"

echo "-- 3. a rig's own file never reaches the store's history, and the real item beside it does --"
rigSeed
rigRigData="$rigStore/.local/agents/scratch/sh-test/rigcheck/data"
mkdir -p "$rigRigData/inboxes/rig-member/incoming"
printf 'a rig note\n' > "$rigRigData/inboxes/rig-member/incoming/note-rig.md"
printf 'a real item\n' > "$rigStore/board/running/note-20260101T0007Z-real.md"
rigRun "$rigTmp/stray" '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.TeamDataCommit.include" ;
	MDAT_TEAM_DATA_COMMIT_THREAD=off AgentsToolsTeamDataCommitPaths "rig stray" "$MDAT_DATA_ROOT/.local/agents/scratch/sh-test/rigcheck/data/inboxes/rig-member/incoming/note-rig.md" "$MDAT_DATA_ROOT/board/running/note-20260101T0007Z-real.md"'
rigAssert "3. no rig file is tracked in the store" "$( git -C "$rigStore" ls-files -- .local | LC_ALL=C grep -c . )" "0"
rigAssert "3. the refusal says what it was, and the call still succeeds" \
	"$( rigCount "$rigTmp/stray.err" 'local state is never committed into the store' ):$( cat "$rigTmp/stray.rc" )" "1:0"
rigAssert "3. the real item beside it is committed, so the refusal is a reading and not a broken step" \
	"$( git -C "$rigStore" ls-files -- board/running/note-20260101T0007Z-real.md | LC_ALL=C grep -c . )" "1"
## A stray already in the store's history is let through by the same step, and only so that its removal is committed: that is the one
## way it leaves, without a hand git on the live store.
git -C "$rigStore" add -A && git -C "$rigStore" commit -q -m "the stray, as it stands in the store's history" > /dev/null 2>&1
rm -f "$rigRigData/inboxes/rig-member/incoming/note-rig.md"
rigRun "$rigTmp/gone" '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.TeamDataCommit.include" ;
	MDAT_TEAM_DATA_COMMIT_THREAD=off AgentsToolsTeamDataCommitPaths "rig stray, removed" "$MDAT_DATA_ROOT/.local/agents/scratch/sh-test/rigcheck/data/inboxes/rig-member/incoming/note-rig.md"'
rigAssert "3. the tracked stray's removal is committed by the same step" \
	"$( cat "$rigTmp/gone.rc" ):$( git -C "$rigStore" ls-files -- .local | LC_ALL=C grep -c . )" "0:0"

echo "-- 4. a path git quotes is settled whole, and reaches a commit under its own name --"
rigSpaced="board/running/item with a space.md"
rigSeed
printf 'the spaced item\n' > "$rigStore/$rigSpaced"
git -C "$rigStore" add -A && git -C "$rigStore" commit -q -m "the spaced item, tracked" || rigRefuse "could not commit the spaced item"
printf 'the spaced item, changed and not yet committed\n' > "$rigStore/$rigSpaced"
rigAssert "4. control: the store is level, holding one changed tracked path, and git wraps its name in quotes" \
	"$( rigBehind ):$( rigDirty ):$( git -C "$rigStore" status --porcelain | LC_ALL=C grep -c -F '"' )" "0:1:1"
rigResync "$rigTmp/spaced"
rigAssert "4. the resync succeeds: the writer was settled, quotes and all" \
	"$( rigResyncRc "$rigTmp/spaced" ):$( rigCount "$rigTmp/spaced.err" 'LOCK_UNCHECKABLE' )" "0:0"
rigAssert "4. and the store comes out level, holding nothing uncommitted" "$( rigBehind ):$( rigDirty )" "0:0"
rigAssert "4. the commit is the settle's own, and it carries the spaced path under its real name" \
	"$( git -C "$rigStore" log -1 --format=%s ):$( git -C "$rigStore" show --name-only --format= HEAD | LC_ALL=C grep -c -x -F "$rigSpaced" )" \
	"* the store's writers, settled before the resync:1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ TEAM DATA RESYNC RACE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'TEAM_DATA_RESYNC_RACE: OK (%d assertions, offline, temp store only)\n' "$rigPassCount"
