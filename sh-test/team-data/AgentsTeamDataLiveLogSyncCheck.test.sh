#!/usr/bin/env bash
## Behavioural check on the two halves of task-20261113T1619Z: a team-data pull must not be refused by a file this store did not write, and
## the audit-log family a live session appends to must be out of the tracked set. Measured on the live store at 13:30, 14:51 and 16:03 +0200
## on 2026-11-13: `Your local changes to the following files would be overwritten by merge` on a tracked audit log, then `fatal: Cannot
## fast-forward your working tree`, after the member's own write had already landed.
## Held:
##   1. THE LIVE LOG: origin and this store both appended to one tracked session log. The pull runs, and the store comes out with no tracked
##      log and with every line of the log on disk.
##   2. THE FAMILY LEAVES THE INDEX: no `audit/*.log` is tracked afterwards, the store's own `.gitignore` names the family, and the rule
##      reaches origin.
##   3. A FOREIGN WRITER'S PATH: an item another member changed and did not commit does not refuse the pull, and its change survives.
##   4. A PATH NOBODY RECORDED IS NAMED, NOT REFUSED SILENTLY: the pull's own answer names the path that stopped it, and the store keeps
##      every file.
##   5. CONTROL, BOTH DIRECTIONS: an in-step store pulls leaving its history alone, and a store behind its origin with nothing waiting is
##      brought level. The instrument sees both.
## Offline: a bare remote and a store of this rig's own folder; no ssh, no network.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigMyx="$MDLT_ORIGIN/myx/myx.common/os-myx.common/host/tarball/share/myx.common"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPkg/sh-lib/team-data/AgentsTools.TeamDataCommit.include" ] || rigRefuse "the tooling is not at the origin this workspace resolves: $rigPkg"
[ -f "$rigMyx/bin/git/cloneSync.Common" ] || rigRefuse "myx.common git/cloneSync is missing: $rigMyx"
command -v git > /dev/null || rigRefuse "git is not installed"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsTeamDataLiveLogSyncCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
export GIT_AUTHOR_NAME=rig GIT_AUTHOR_EMAIL=rig@example.invalid
export GIT_COMMITTER_NAME=rig GIT_COMMITTER_EMAIL=rig@example.invalid
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
trap 'rm -rf -- "$rigTmp"' EXIT

rigWs="$rigTmp/ws"
rigRemoteGit="$rigTmp/team.git"
rigStore="$rigTmp/store"
rigLiveLog="audit/2026-01/session-20260101T000000Z-other-aaaaaaaa.log"
rigForeign="inboxes/keeper-myx/incoming/note-20260101T0001Z-foreign.md"
rigMoved="board/running/task-20260101T0002Z-moved.md"
rigState=".local/agents/local-state.md"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/home"
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
## A bare remote holding one item, one foreign inbox item and one tracked live log, and the store cloned from it.
rigSeed(){
	rm -rf "$rigRemoteGit" "$rigTmp/seed" "$rigStore"
	git init -q --bare "$rigRemoteGit" || rigRefuse "could not init the bare remote"
	git -C "$rigRemoteGit" symbolic-ref HEAD refs/heads/main
	git init -q "$rigTmp/seed" && git -C "$rigTmp/seed" symbolic-ref HEAD refs/heads/main
	mkdir -p "$rigTmp/seed/board/running" "$rigTmp/seed/inboxes/keeper-myx/incoming" "$rigTmp/seed/audit/2026-01"
	printf 'seed\n' > "$rigTmp/seed/README.md"
	printf 'the foreign item, as it stands\n' > "$rigTmp/seed/$rigForeign"
	printf '2026-01-01T00:00:00Z START the other host session\n' > "$rigTmp/seed/$rigLiveLog"
	git -C "$rigTmp/seed" add -A && git -C "$rigTmp/seed" commit -q -m seed || rigRefuse "could not seed the remote"
	git -C "$rigTmp/seed" push -q "$rigRemoteGit" main 2> /dev/null || rigRefuse "could not push the seed"
	git clone -q "$rigRemoteGit" "$rigStore" 2> /dev/null || rigRefuse "could not clone the store"
}
## Another host commits a change to a path, from a clone of the store's own remote.
rigElsewhere(){ ## path, the text it writes there, append (yes to add a line to what is there)
	rm -rf "$rigTmp/away"
	git clone -q "$rigRemoteGit" "$rigTmp/away" 2> /dev/null || rigRefuse "could not clone the remote"
	mkdir -p "$rigTmp/away/$( dirname "$1" )"
	if [ "${3:-no}" = "yes" ] ; then
		printf '%s\n' "$2" >> "$rigTmp/away/$1"
	else
		printf '%s\n' "$2" > "$rigTmp/away/$1"
	fi
	git -C "$rigTmp/away" add -A && git -C "$rigTmp/away" commit -q -m "elsewhere: $1" || rigRefuse "could not commit elsewhere"
	git -C "$rigTmp/away" push -q origin main 2> /dev/null || rigRefuse "could not push elsewhere"
	git -C "$rigStore" fetch -q origin 2> /dev/null || :
}
## A live session appending to the store's own copy of a tracked log, as AgentsTranscriptAppend does.
rigLiveAppend(){ ## path, the line it appends
	mkdir -p "$rigStore/$( dirname "$1" )"
	printf '%s\n' "$2" >> "$rigStore/$1"
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
## The pull a duty start and every other caller run, as AgentsToolsAdvanceCloneSync makes it. The call sits in a condition, as every
## caller's does, so the `set -e` the function restores is no abort of this rig.
rigPull(){ ## result name
	rigRun "$1" '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/routine/AgentsTools.RoutineLock.include"
		if AgentsToolsAdvanceCloneSync "$MDAT_DATA_ROOT" "$( LC_ALL=C sed -n "s/^TEAM_DATA_GIT_REMOTE=//p" "$MMDAPP/.local/.agents/magic-team.agent.env" )" main ; then rigRc=0 ; else rigRc=$? ; fi
		printf "PULL-RC=%s\n" "$rigRc"
		printf "PULL-OUT=%s\n" "$advanceSyncOut"
		exit 0'
}
rigPullRc(){ LC_ALL=C sed -n 's/^PULL-RC=//p' "$1" | LC_ALL=C sed -n 1p ; }
rigBehind(){ git -C "$rigStore" rev-list --count HEAD..origin/main 2> /dev/null || printf '?' ; }
rigDirty(){ git -C "$rigStore" status --porcelain | LC_ALL=C grep -c . || : ; }
rigTrackedLogs(){ git -C "$rigStore" ls-files -- audit | LC_ALL=C grep -c '\.log$' || : ; }

echo "-- 1. a live session's append does not refuse the pull, and the log keeps every line --"
rigSeed
rigElsewhere "$rigLiveLog" '2026-01-01T00:10:00Z START the other host session, line two' yes
rigLiveAppend "$rigLiveLog" '2026-01-01T00:11:00Z TOOL here, appended while the session ran'
rigAssert "control: the store is behind its origin, and one tracked log is dirty here" "$( rigBehind ):$( rigDirty )" "1:1"
rigPull "$rigTmp/live"
rigAssert "1. the pull runs to a clean end, and reports no uncheckable lock" \
	"$( rigPullRc "$rigTmp/live" ):$( rigCount "$rigTmp/live.err" 'LOCK_UNCHECKABLE' )" "0:0"
rigAssert "1. the store comes out level, holding nothing uncommitted" "$( rigBehind ):$( rigDirty )" "0:0"
rigAssert "1. the line this store appended is still on disk, and so is origin's" \
	"$( LC_ALL=C grep -c -F 'TOOL here' "$rigStore/$rigLiveLog" ):$( LC_ALL=C grep -c -F 'line two' "$rigStore/$rigLiveLog" )" "1:1"

echo "-- 2. the family left the tracked set, and the store's own ignore rule says so --"
rigAssert "2. no live log is tracked any more" "$( rigTrackedLogs )" "0"
rigAssert "2. the ignore rule is in the store's own file, and the file is tracked" \
	"$( LC_ALL=C grep -c -x -F 'audit/**/*.log' "$rigStore/.gitignore" ):$( git -C "$rigStore" ls-files -- .gitignore | LC_ALL=C grep -c . )" "1:1"
rigAssert "2. the rule reached origin" \
	"$( git -C "$rigRemoteGit" show "main:.gitignore" | LC_ALL=C grep -c -x -F 'audit/**/*.log' )" "1"
rigLiveAppend "$rigLiveLog" '2026-01-01T00:12:00Z TOOL here, after the family left the index'
rigAssert "2. a later append to a log leaves the store clean" "$( rigDirty )" "0"

echo "-- 3. a foreign writer's uncommitted path does not refuse the pull --"
rigSeed
rigElsewhere "$rigMoved" 'moved by another host'
printf 'the foreign item, changed here and not yet committed\n' > "$rigStore/$rigForeign"
rigAssert "control: the store is behind its origin, and the foreign path is waiting" "$( rigBehind ):$( rigDirty )" "1:1"
rigPull "$rigTmp/foreign"
rigAssert "3. the pull runs to a clean end, and reports no uncheckable lock" \
	"$( rigPullRc "$rigTmp/foreign" ):$( rigCount "$rigTmp/foreign.err" 'LOCK_UNCHECKABLE' )" "0:0"
rigAssert "3. the foreign change survives, and reached origin" \
	"$( LC_ALL=C grep -c -F 'changed here' "$rigStore/$rigForeign" ):$( git -C "$rigRemoteGit" show "main:$rigForeign" | LC_ALL=C grep -c -F 'changed here' )" "1:1"
rigAssert "3. and the store comes out level" "$( rigBehind ):$( rigDirty )" "0:0"

echo "-- 4. a path the store's own rules will not commit is named, and nothing of it is lost --"
rigSeed
rigElsewhere "$rigState" 'origin state, a path this store never commits'
mkdir -p "$rigStore/.local/agents"
printf 'the local state this store never commits\n' > "$rigStore/$rigState"
rigAssert "control: origin moves a path this store holds and will not commit" \
	"$( rigBehind ):$( rigDirty )" "1:1"
rigPull "$rigTmp/held"
rigAssert "4. the pull is not run, and one line names the path that stopped it" \
	"$( rigPullRc "$rigTmp/held" ):$( rigCount "$rigTmp/held.err" 'the team-data pull was not run: origin also moves these paths' )" "1:1"
rigAssert "4. and the file this store held is untouched" \
	"$( LC_ALL=C grep -c -F 'the local state this store' "$rigStore/$rigState" )" "1"

echo "-- 5. control: an in-step store, and a store behind its origin with nothing waiting --"
rigSeed
rigPull "$rigTmp/level1"
rigAssert "5. the first pull brings the store level and leaves no log tracked" \
	"$( rigPullRc "$rigTmp/level1" ):$( rigBehind ):$( rigTrackedLogs )" "0:0:0"
rigBefore="$( git -C "$rigStore" rev-list --count HEAD )"
rigPull "$rigTmp/level2"
rigAssert "5. a second pull on a store with nothing to do adds no commit" \
	"$( rigPullRc "$rigTmp/level2" ):$( git -C "$rigStore" rev-list --count HEAD )" "0:$rigBefore"
rigElsewhere "board/running/task-20260101T0006Z-elsewhere.md" 'from elsewhere'
rigPull "$rigTmp/behind"
rigAssert "5. a store behind its origin and holding nothing is brought level" \
	"$( rigPullRc "$rigTmp/behind" ):$( rigBehind )" "0:0"

echo "-- 6. one item both sides changed is settled, and the pull still comes level --"
rigSeed
rigElsewhere "$rigForeign" 'the foreign item, as origin wrote it'
printf 'the foreign item, as this store wrote it\n' > "$rigStore/$rigForeign"
rigLiveAppend "$rigLiveLog" '2026-01-01T00:20:00Z TOOL here, beside a conflicting item'
rigAssert "control: the store is behind its origin, one item is changed both sides, one log is dirty" \
	"$( rigBehind ):$( rigDirty )" "1:2"
rigPull "$rigTmp/settled"
rigAssert "6. the pull settles the item and comes level" \
	"$( rigPullRc "$rigTmp/settled" ):$( rigBehind ):$( rigDirty )" "0:0:0"
rigAssert "6. no line of either side of that item is lost" \
	"$( LC_ALL=C grep -c -F 'as origin wrote it' "$rigStore/$rigForeign" ):$( LC_ALL=C grep -c -F 'as this store wrote it' "$rigStore/$rigForeign" )" "1:1"
rigAssert "6. and the live log's own line is on disk" \
	"$( LC_ALL=C grep -c -F 'TOOL here, beside' "$rigStore/$rigLiveLog" )" "1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ TEAM DATA LIVE LOG SYNC CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'TEAM_DATA_LIVE_LOG_SYNC: OK (%d assertions, offline, temp store only)\n' "$rigPassCount"
