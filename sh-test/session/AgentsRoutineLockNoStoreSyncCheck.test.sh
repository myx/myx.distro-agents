#!/usr/bin/env bash
## Behavioural check on sketch 5.4, "a spawn does not wait on a full team-data sync" (S5.5), at the guard a
## spawner's routine lock runs: `AgentsToolsAdvanceLockSync` in AgentsTools.RoutineLock.include brings the branch
## level with origin by a fetch and a fast-forward, and asks the store thread for its whole-store sync only where
## that fast-forward is refused.
## Run through the real acquire (`AgentsToolsRoutineLockAcquireOne`). Three things are the rig's own, each of them a
## part this check is not about: the item write, which is the writer every real start has; the store thread, which is
## counted and never started; and the member directory. The guard, the state checks and the store lock are real.
## Held:
##   1. A STORE BEHIND ORIGIN, CLEAN: the acquire takes the lock, the copy is level with origin, and the thread is
##      asked for NO sync at all. That count is what the sketch's rule is about, and it is 1 before the fix.
##   2. THE CHECKOUT IS LEFT CLEAN: nothing to report and nothing staged, so a later commit carries no path of this.
##   3. CONTROL, THE OTHER DIRECTION: a store holding its own commit on a path origin moved is refused the fast-forward,
##      the thread carries it, and the acquire still takes the lock. A refusal is never the answer to a working store.
##   4. A STORE AHEAD OF ORIGIN ON THE LOCK PATH, origin unmoved: `git merge --ff-only` answers nothing to do, so the
##      bring compares the tip with the fetched commit and falls back to the thread. The lock is taken and the store's
##      own commit reaches origin. Without that comparison the acquire refuses with LOCK_STALE.
##   5. A STORE BEHIND ORIGIN HOLDING WORK OF ITS OWN ELSEWHERE is no fallback: the fast-forward carries it, and the
##      thread is asked for nothing.
##   6. A BRANCH ORIGIN DOES NOT HAVE is refused with its own reason, and nothing is left staged.
##   7. THE WALL TIME of the acquire is printed on both paths, so the wait the item is about is stated, not claimed.
## Red before the fix: row 1's count reads 1, because the guard asks for the whole sync before it looks at the branch.
## Row 4 is red too, on a tree holding the guard without the tip comparison.
## Offline: a bare remote and a store of this rig's own folder; no network, no real team data.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigInclude="$rigPackage/sh-lib/routine/AgentsTools.RoutineLock.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the routine-lock include is not at $rigInclude"
command -v git > /dev/null || rigRefuse "git is not installed"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRoutineLockNoStoreSyncCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
export GIT_AUTHOR_NAME=rig GIT_AUTHOR_EMAIL=rig@example.invalid
export GIT_COMMITTER_NAME=rig GIT_COMMITTER_EMAIL=rig@example.invalid
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
trap 'chmod -R u+w -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
	return 0
}

## THE RIG: a bare remote, a store clone of it, and a second clone that publishes origin's commits. The lock note is
## a note of the store's own, in the inbox folder the acquire reads and writes it in.
rigWs="$rigTmp/ws"
rigRemote="$rigTmp/remote.git"
rigStore="$rigTmp/store"
rigPublish="$rigTmp/publish"
rigRequests="$rigTmp/requests"
rigNoteRel="inboxes/rig-keeper/processed/note-20261019T0000Z-riglock-state-and-lock.md"
mkdir -p "$rigWs/.local/agents" "$rigTmp/home" || exit 1
git init -q --bare "$rigRemote" || rigRefuse "the bare remote could not be made"
git init -q "$rigStore" || rigRefuse "the store could not be made"
git -C "$rigStore" symbolic-ref HEAD refs/heads/main || rigRefuse "the store's branch could not be named"
mkdir -p "${rigStore}/${rigNoteRel%/*}" || exit 1
printf -- '---\ntype: note\nfrom: rig-keeper\nowner: rig-keeper\nstate: riglock-finished\n---\n\nThe state of the riglock routine.\n' > "$rigStore/$rigNoteRel"
printf 'seed\n' > "$rigStore/README.md"
git -C "$rigStore" add -A && git -C "$rigStore" commit -q -m seed || rigRefuse "the store could not be seeded"
git -C "$rigStore" remote add origin "$rigRemote" || rigRefuse "the remote could not be named"
git -C "$rigStore" push -q origin main || rigRefuse "the seed could not be pushed"
git clone -q --branch main "$rigRemote" "$rigPublish" || rigRefuse "the publishing clone could not be made"

## The publishing side adds one commit: origin's newer copy of the lock note, and a second path the store never touched,
## so a fast-forward moves a file beside the one the lock names. It stands itself on origin's own tip first, since a
## start's lock write may have landed there since the last publish; this rig's clone is the only writer of origin.
rigPublishNote(){ ## the receipt origin's lock note carries
	git -C "$rigPublish" fetch -q origin main || rigRefuse "the publishing clone could not read origin"
	git -C "$rigPublish" reset -q --hard FETCH_HEAD || rigRefuse "the publishing clone could not stand on origin's tip"
	printf -- '---\ntype: note\nfrom: rig-keeper\nowner: rig-keeper\nstate: riglock-finished\nlast-receipt: %s\n---\n\nThe state of the riglock routine.\n' "$1" > "$rigPublish/$rigNoteRel"
	printf 'origin %s\n' "$1" > "$rigPublish/OTHER.md"
	git -C "$rigPublish" add -A && git -C "$rigPublish" commit -q -m "origin: $1" || rigRefuse "the publishing commit could not be made"
	git -C "$rigPublish" push -q origin main || rigRefuse "the publishing commit could not be pushed"
}

## ONE ACQUIRE of the rig's lock note, in a shell of its own. The item write is a real writer, as every start has one: it
## writes the note, commits it and pushes it, under its own message. The store thread is counted and never started; its
## sync does what the real one does for this store, which is to fetch and integrate origin.
rigAcquire(){ ## the store, a name for this run
	local acqStore="$1" acqName="$2"
	: > "$rigRequests"
	MMDAPP="$rigWs" MDAT_DATA_ROOT="$acqStore" MDAT_SKILLSET_ROOT="$rigTmp/skills" HOME="$rigTmp/home" \
		MDAT_TEAM_DATA_COMMIT_THREAD=off MDAT_TEAM_DATA_COMMIT_WAIT=no \
		bash -c '
			. "$1" || exit 1
			## THE WRITER: the note, committed and pushed, which is what the real item write leaves behind. Its headers
			## arrive as the acquire own words, so the state and session it reads are the ones it asked for.
			AgentsToolsItemUpsert(){
				local upWord upState="" upSession=""
				for upWord in "$@" ; do
					case "$upWord" in
						--header:upsert:state:*) upState="${upWord#--header:upsert:state:}" ;;
						--header:upsert:session-id:*) upSession="${upWord#--header:upsert:session-id:}" ;;
					esac
				done
				printf -- "---\ntype: note\nfrom: rig-keeper\nowner: rig-keeper\nstate: %s\nsession-id: %s\n---\n\nThe state of the riglock routine.\n" "${upState:-riglock-running}" "$upSession" > "$RIG_ITEM_NOTE" || return 1
				git -C "$MDAT_DATA_ROOT" add -A > /dev/null 2>&1 || return 1
				git -C "$MDAT_DATA_ROOT" commit -q -m "* riglock.routine: spawner lock" > /dev/null 2>&1 || return 1
				git -C "$MDAT_DATA_ROOT" push -q origin HEAD:main > /dev/null 2>&1 || return 1
				return 0
			}
			AgentsToolsItemStaleCheck(){ return 0 ; }
			AgentsToolsRecheckDate(){ printf "2026-12-01 00:00 +0000" ; }
			AgentsToolsConfigOption(){ printf "%s\n" "$RIG_REMOTE" ; }
			AgentsToolsTeamDataGate(){ return 0 ; }
			AgentsToolsTeamDataGateRefuse(){ return 0 ; }
			AgentsToolsInboxNotePath(){ printf "%s\n" "$RIG_ITEM_NOTE" ; }
			AgentsToolsInboxNoteProcessed(){ return 0 ; }
			AgentsToolsRoutineLockHolderHeaders(){ return 0 ; }
			AgentsToolsRoutineLockDiscard(){ return 0 ; }
			## THE STORE THREAD, COUNTED AND NEVER STARTED. Its sync does the one thing this store needs of it, which is
			## to integrate origin, and its head read answers origin as git shows it.
			AgentsToolsTeamDataRequestAsk(){
				printf "%s\n" "$1" >> "$RIG_REQUESTS"
				case "$1" in
					sync)
						git -C "$MDAT_DATA_ROOT" fetch -q origin "refs/heads/$4" > /dev/null 2>&1 || return 1
						## The real thread settles its writers before it moves the tree (S12.4), so a path this
						## store holds edited is committed by it and is no refusal. Its stand-in does the same.
						git -C "$MDAT_DATA_ROOT" add -A > /dev/null 2>&1 || :
						git -C "$MDAT_DATA_ROOT" commit -q -m "the store own work, carried by the sync" > /dev/null 2>&1 || :
						git -C "$MDAT_DATA_ROOT" merge -q --no-edit FETCH_HEAD > /dev/null 2>&1 || return 1
						## And it pushes what the store is left ahead by: the resync last step
						## (AgentsToolsTeamDataPushIfAhead), without which a store unpushed lock write stays
						## local and the head check still differs from origin.
						git -C "$MDAT_DATA_ROOT" push -q origin "HEAD:refs/heads/$4" > /dev/null 2>&1 || return 1
						return 0
					;;
					head)
						git -C "$MDAT_DATA_ROOT" fetch -q origin "$3" > /dev/null 2>&1 || return 1
						case "$4" in
							session) git -C "$MDAT_DATA_ROOT" show "FETCH_HEAD:$2" 2> /dev/null | LC_ALL=C awk "/^session-id: /{ print substr(\$0, 13) ; exit ; }" ;;
							*) printf "%s\t%s\n" "$( git -C "$MDAT_DATA_ROOT" rev-parse --verify --quiet "HEAD:$2" 2> /dev/null || printf - )" "$( git -C "$MDAT_DATA_ROOT" rev-parse --verify --quiet "FETCH_HEAD:$2" 2> /dev/null || printf - )" ;;
						esac
						return 0
					;;
					push) return 0 ;;
				esac
				return 0
			}
			AgentsToolsRoutineLockAcquireOne "$RIG_LOCK_VALUE" "$RIG_SESSION" riglock
		' rig-acquire "$rigInclude" \
		> "$rigTmp/$acqName.out" 2>&1
	printf '%s' "$?" > "$rigTmp/$acqName.rc"
	printf 'sync=%s\n' "$( LC_ALL=C grep -c -x 'sync' "$rigRequests" 2> /dev/null || : )" > "$rigTmp/$acqName.requests"
	## The count said beside every row it qualifies, so a reader takes the number off the run and never off a claim.
	printf '  SYNC  %-9s %s sync request(s), state %s\n' "$acqName" "$( LC_ALL=C sed -n 's/^sync=//p' "$rigTmp/$acqName.requests" )" "$( cat "$rigTmp/$acqName.rc" )"
	## A refusal says why, in the acquire's own words, so a red row is read and never guessed at.
	[ "$( cat "$rigTmp/$acqName.rc" )" = "0" ] || { printf '  SAYS  %s\n' "$acqName" ; LC_ALL=C sed -n '1,4p' "$rigTmp/$acqName.out" | LC_ALL=C sed 's/^/        /' ; }
}

export RIG_ITEM_NOTE RIG_REQUESTS RIG_REMOTE RIG_LOCK_VALUE RIG_SESSION
RIG_ITEM_NOTE="$rigStore/$rigNoteRel"
RIG_REQUESTS="$rigRequests"
RIG_REMOTE="$rigRemote"
RIG_LOCK_VALUE="inbox:rig-keeper:note-20261019T0000Z-riglock-state-and-lock.md"
RIG_SESSION="rig-session-under-test"

echo "-- 1. a store behind origin, clean: the lock is taken, and the thread is asked for no sync --"
rigPublishNote "the other session closed it"
rigStartAt="$( date +%s )"
rigAcquire "$rigStore" behind
rigBehindSeconds=$(( $( date +%s ) - rigStartAt ))
rigAssert "the acquire takes the lock" "$( cat "$rigTmp/behind.rc" )" "0"
rigAssert "and asks the store thread for no sync at all" "$( LC_ALL=C sed -n 's/^sync=\([0-9]*\)$/\1/p' "$rigTmp/behind.requests" )" "0"
rigAssert "a path origin added is in the store" "$( [ -f "$rigStore/OTHER.md" ] && printf present || printf absent )" "present"
rigAssert "the store's branch is level with origin" \
	"$( [ "$( git -C "$rigStore" rev-parse HEAD )" = "$( git -C "$rigStore" rev-parse FETCH_HEAD )" ] && printf level || printf behind )" "level"
printf '  WALL  the acquire took %ss on the level path\n' "$rigBehindSeconds"

echo "-- 2. the checkout is left clean, so no later commit carries a path of this --"
rigAssert "the checkout reports nothing" "$( git -C "$rigStore" status --porcelain --untracked-files=all | LC_ALL=C awk 'END { print NR + 0 }' )" "0"

echo "-- 3. control: a store with its own commit is refused the fast-forward, and the thread carries it --"
printf 'this store own work\n' > "$rigStore/OWN.md"
git -C "$rigStore" add -A && git -C "$rigStore" commit -q -m "this store own commit" || rigRefuse "the store own commit could not be made"
rigPublishNote "a later close"
rigStartAt="$( date +%s )"
rigAcquire "$rigStore" owncommit
rigOwnSeconds=$(( $( date +%s ) - rigStartAt ))
rigAssert "the lock is still taken: a fallback is never a refusal" "$( cat "$rigTmp/owncommit.rc" )" "0"
rigAssert "and the thread is asked for exactly one sync" "$( LC_ALL=C sed -n 's/^sync=\([0-9]*\)$/\1/p' "$rigTmp/owncommit.requests" )" "1"
rigAssert "this store's own file survives the fallback" "$( [ -f "$rigStore/OWN.md" ] && printf kept || printf lost )" "kept"
printf '  WALL  the acquire took %ss on the fallback path\n' "$rigOwnSeconds"

echo "-- 4. a store AHEAD of origin on the lock path, origin unmoved: the thread carries it, and the lock is taken --"
git -C "$rigStore" checkout -q main 2> /dev/null || rigRefuse "the store could not stand on main"
git -C "$rigStore" fetch -q origin main && git -C "$rigStore" reset -q --hard FETCH_HEAD || rigRefuse "the store could not be brought to origin"
## The store's own lock write, committed and not pushed: what a push that failed leaves behind. The lock note changes, so
## the head check's two blob ids differ, and a bring that answered `ok` without moving anything would leave it refusing.
printf -- '---\ntype: note\nfrom: rig-keeper\nowner: rig-keeper\nstate: riglock-finished\nsession-id: this-store-own\n---\n\nThe state of the riglock routine.\n' > "$rigStore/$rigNoteRel"
git -C "$rigStore" add -A && git -C "$rigStore" commit -q -m "the lock write, its push not landed" || rigRefuse "the store own lock commit could not be made"
rigAcquire "$rigStore" ahead
rigAssert "the lock is taken on a store ahead of origin" "$( cat "$rigTmp/ahead.rc" )" "0"
rigAssert "the thread is asked for exactly one sync" "$( LC_ALL=C sed -n 's/^sync=\([0-9]*\)$/\1/p' "$rigTmp/ahead.requests" )" "1"
rigAssert "this store's own lock commit is kept, not dropped by the fallback" "$( git -C "$rigStore" log --format=%s | LC_ALL=C grep -c -x 'the lock write, its push not landed' || : )" "1"
rigAssert "and it reached origin, as the whole sync pushes what it is ahead by" "$( git -C "$rigRemote" log --format=%s main | LC_ALL=C grep -c -x 'the lock write, its push not landed' || : )" "1"

echo "-- 5. a store behind origin holding work of its own elsewhere is no fallback: the fast-forward carries it --"
git -C "$rigStore" checkout -q main 2> /dev/null || rigRefuse "the store could not stand on main"
git -C "$rigStore" fetch -q origin main && git -C "$rigStore" reset -q --hard FETCH_HEAD || rigRefuse "the store could not be brought to origin"
rigPublishNote "a close after the store own commit"
printf 'this store own untracked work\n' > "$rigStore/UNCOMMITTED.md"
rigAcquire "$rigStore" localedit
rigAssert "the lock is taken on a tree holding work of its own" "$( cat "$rigTmp/localedit.rc" )" "0"
rigAssert "and no sync is asked for it" "$( LC_ALL=C sed -n 's/^sync=\([0-9]*\)$/\1/p' "$rigTmp/localedit.requests" )" "0"
rigAssert "that work is still on disk" "$( cat "$rigStore/UNCOMMITTED.md" )" "this store own untracked work"

echo "-- 6. a branch origin does not have is refused with its own reason, and leaves nothing staged --"
git -C "$rigStore" checkout -q -b rig-only 2> /dev/null || rigRefuse "the store own branch could not be made"
rigAcquire "$rigStore" nobranch
rigAssert "the acquire refuses on a branch origin has never seen" "$( cat "$rigTmp/nobranch.rc" )" "1"
rigAssert "and the refusal names the branch it could not bring level" "$( LC_ALL=C grep -c -F 'could not be brought level with origin' "$rigTmp/nobranch.out" || : )" "1"
rigAssert "nothing is left staged" "$( git -C "$rigStore" diff --cached --name-only | LC_ALL=C awk 'END { print NR + 0 }' )" "0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROUTINE LOCK NO STORE SYNC CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'ROUTINE_LOCK_NO_STORE_SYNC: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
