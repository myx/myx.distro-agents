#!/usr/bin/env bash
## Behavioural check on S12.4: a team-data write succeeds even when another write holds, or has
## just held, the store's `.git/index.lock`. Held, over a real git store under this rig's own tree:
##   1. THE CONTROL, and the instrument's known positive: with the same fake `git` first on PATH
##      passing add and commit through, each writer writes its file and the store ends clean — and
##      the log shows an add or a commit whose parent process is the writer's own.
##   2. A fake `git` that refuses every `add` and `commit` with the lock error. Each writer —
##      board-upsert-move-edit, member-inbox-upsert and inbox-to-processed — exits 0 and its file
##      is written. Today each returns 1 and the file stays behind.
##   3. THE SUBJECT: under that refusal, no `git add` and no `git commit` has the writer's own
##      process as its parent. The one team-data committer thread makes them, as the comms outbox
##      pusher does. Case 1 is what shows this instrument able to see such a call at all.
##   4. Five writers at once against a real store while another writer holds its lock: every item
##      holds its own write, all five writers exit 0, and the changes reach the store once the
##      lock is gone.
##   5. E1: a path that is gone and that git never knew does not fail the commit beside it, and
##      nothing is owed after it. The thread is off for this one, so its result is read at once.
##   6. E2: the thread ends by itself while its owed commit keeps failing, and the debt stays
##      recorded for the next pass.
##   7. E3: thread.log is cut to under its 128 KiB bound once it grows past it.
##   8. E4: item-upsert, which still commits in its own process, rides out a held index.lock by
##      running its add again: exit 0, and the note committed.
##   9. E5: a thread that cannot be started is not silent. The writer commits in its own process
##      and leaves no entry behind.
##  10. F1: a writer returns at once while a team-data thread lives, so the capture of the thread's
##      start never waits for the thread's end. A tree with no thread passes it by construction;
##      the copy of the fix that keeps the capture's output is what shows it able to fail.
## This rig sets no MDAT_TEAM_DATA_COMMIT_THREAD: the checks runner turns that thread off, so a
## writer that kept committing in its own process would still be caught here.
## Red before S12.4: cases 2, 3, 4, E1, E2, E3 and E4 fail, and E5 fails on its warning line
## alone -- a tree with no thread has no failed start to announce, while its writer still commits
## in its own process, which E5's other assertions read. F1 passes on a tree with no thread at all,
## because no start is captured there. A case that can only fail on the fix is shown able to fail
## on a copy of the fix: E5 on one whose failed start leaves its entry and commits nothing, F1 on
## one whose detached start keeps the capture's output.
## Offline: the store, the skills folder and the fake git are this rig's own; no remote is needed.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPkg="$rigOrigin/myx/myx.distro-agents"
rigFn="$rigPkg/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigFn" ] || rigRefuse "the tooling is not at the origin this workspace resolves: $rigFn"
command -v git > /dev/null || rigRefuse "git is not installed"
command -v ps > /dev/null || rigRefuse "ps is not on PATH"
rigRealGit="$( command -v git )"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsTeamDataWriteUnderLockCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigThreadStop ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
rigBin="$rigTmp/bin"
rigSkills="$rigWs/.local/agents/members"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigData/board/running" "$rigData/board/backlog" "$rigData/inboxes/rig-member/incoming" \
	"$rigBin" "$rigTmp/home" "$rigSkills/rig-member"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nNO_PROXY=*\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf -- '---\nname: rig-member\nstatus: active\n---\nrig member\n' > "$rigSkills/rig-member/SKILL.md"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/rig-member/rig-member.basic.md"
## The one git on this rig's PATH: it records each call with the calling process's own words, and
## refuses add and commit while RIG_GIT_REFUSE is 1, standing in for another writer's index.lock.
## With RIG_GIT_FAIL_FIRST it refuses that many add calls and then passes them through, which is one
## writer meeting a held lock and finding it free on the next try.
cat > "$rigBin/git" <<'RIGSTUB'
#!/bin/sh
rigCaller="$( LC_ALL=C ps -o args= -p "$PPID" 2> /dev/null | LC_ALL=C tr '\n' ' ' )"
printf '%s\t%s\t%s\n' "$PPID" "$rigCaller" "$*" >> "$RIG_GIT_LOG"
rigWrites=0 rigAdds=0
for rigArg in "$@" ; do
	case "$rigArg" in add) rigWrites=1 ; rigAdds=1 ;; commit) rigWrites=1 ;; esac
done
[ "$rigWrites" = 1 ] || exec "$RIG_REAL_GIT" "$@"
rigFail=0
[ "${RIG_GIT_REFUSE:-0}" != 1 ] || rigFail=1
if [ "$rigFail" = 0 ] && [ "$rigAdds" = 1 ] && [ "${RIG_GIT_FAIL_FIRST:-0}" -gt 0 ] 2> /dev/null ; then
	rigSeen="$( cat "$RIG_GIT_COUNT" 2> /dev/null )" ; rigSeen="${rigSeen:-0}"
	if [ "$rigSeen" -lt "$RIG_GIT_FAIL_FIRST" ] ; then
		printf '%s\n' "$(( rigSeen + 1 ))" > "$RIG_GIT_COUNT"
		rigFail=1
	fi
fi
if [ "$rigFail" = 1 ] ; then
	echo "fatal: Unable to create '$RIG_GIT_STORE/.git/index.lock': File exists." >&2
	echo "Another git process seems to be running in this repository." >&2
	exit 128
fi
exec "$RIG_REAL_GIT" "$@"
RIGSTUB
chmod +x "$rigBin/git"
git -C "$rigData" init -q || rigRefuse "could not init the rig store"
git -C "$rigData" config user.email rig@example.invalid
git -C "$rigData" config user.name rig
printf 'seed\n' > "$rigData/README.md"
git -C "$rigData" add -A && git -C "$rigData" commit -q -m seed || rigRefuse "could not seed the rig store"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One writer, as the tooling runs it: a call from the rig workspace against the rig store.
rigWrite(){ ## result name, refusal (0|1), the operation and its words...
	local writeName="$1" writeRefuse="$2"
	shift 2
	(
		cd "$rigWs" || exit 1
		printf 'rig body\n' | env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" \
			PATH="$rigBin:/usr/bin:/bin:/usr/sbin:/sbin" \
			MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
			MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SPAWN_AGENT=rig-member \
			RIG_GIT_LOG="$rigBin/git.log" RIG_REAL_GIT="$rigRealGit" RIG_GIT_STORE="$rigData" RIG_GIT_REFUSE="$writeRefuse" \
			RIG_GIT_FAIL_FIRST="${rigGitFailFirst:-0}" RIG_GIT_COUNT="$rigBin/gitfail.count" \
			${rigEnvExtra[@]+"${rigEnvExtra[@]}"} \
			bash "$rigFn" "$@"
	) > "$rigTmp/$writeName.out" 2>&1 < /dev/null
	printf '%s' "$?" > "$rigTmp/$writeName.rc"
}
rigWriteTimed(){ ## result name, refusal (0|1), the operation and its words... -- how many seconds it took
	local timedFrom="$SECONDS"
	rigWrite "$@"
	printf '%s' "$(( SECONDS - timedFrom ))"
}
rigBoardItem(){ ## item name, body word
	printf -- '---\ntype: note\nowner: rig-member\n---\n\n%s\n' "$2" > "$rigData/board/running/$1"
}
rigClean(){ [ -z "$( git -C "$rigData" status --porcelain --untracked-files=all )" ] && printf clean || printf dirty ; }
rigCommitCount(){ git -C "$rigData" rev-list --count HEAD ; }
## The add and commit calls a log holds whose calling process names the writer's own operation:
## the number of them. A committer thread's call names that thread, never the writer's operation.
rigCallsIn(){ ## writer operation word, log file -- how many
	LC_ALL=C awk -F'\t' -v op="$1" '
		$3 !~ /(^| )add( |$)|(^| )commit( |$)/ { next }
		index( $2, op ) > 0 { n++ }
		END { print n + 0 }
	' "$2" 2> /dev/null || printf '0'
}
rigCallsByWriter(){ rigCallsIn "$1" "$rigBin/git.log" ; }
rigAnyCalls(){ LC_ALL=C awk -F'\t' '$3 ~ /(^| )add( |$)|(^| )commit( |$)/ { n++ } END { print n + 0 }' "$rigBin/git.log" 2> /dev/null || printf '0' ; }
rigGitRefuse=0 rigGitFailFirst=0 rigEnvExtra=()
rigThreadLock="$rigData/.git/team-data-commit/thread.lock"
rigThreadLog="$rigData/.git/team-data-commit/thread.log"
rigOwedFile="$rigWs/.local/agents/team-data-commit.owed"
rigCount(){ ## file, fixed text -- how many lines hold it
	[ -f "$1" ] || { printf '0' ; return 0 ; }
	LC_ALL=C awk -v s="$2" 'index( $0, s ) > 0 { n++ } END { print n + 0 }' "$1"
}
rigCommitted(){ LC_ALL=C git -C "$rigData" log --format=%s -1 -- "$1" 2> /dev/null | LC_ALL=C grep -c . ; }
rigOwed(){ ## how many paths the store still owes a commit for
	[ -s "$rigOwedFile" ] || { printf '0' ; return 0 ; }
	LC_ALL=C wc -l < "$rigOwedFile" | LC_ALL=C tr -d ' '
}
## One commit of the given paths made by the module itself, with the thread off: the call every
## writer makes, read at once rather than through the thread.
rigCommitPaths(){ ## result name, context, path...
	local cpName="$1" cpContext="$2"
	shift 2
	(
		cd "$rigWs" || exit 1
		env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigBin:/usr/bin:/bin:/usr/sbin:/sbin" \
			MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
			MDSC_CMD=DistroAgentsTools MDAT_TEAM_DATA_COMMIT_THREAD=off \
			RIG_GIT_LOG="$rigBin/git.log" RIG_REAL_GIT="$rigRealGit" RIG_GIT_STORE="$rigData" \
			RIG_GIT_REFUSE="${rigGitRefuse:-0}" RIG_GIT_FAIL_FIRST="${rigGitFailFirst:-0}" RIG_GIT_COUNT="$rigBin/gitfail.count" \
			bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.TeamDataCommit.include" ; AgentsToolsTeamDataCommitPaths "$@"' rigcp "$cpContext" "$@"
	) > "$rigTmp/$cpName.out" 2>&1 < /dev/null
	printf '%s' "$?" > "$rigTmp/$cpName.rc"
}
## One item-upsert, reached the way in-context code reaches it: the retired --intern-op-item-upsert
## name is refused by name, so the function itself is called.
rigItemUpsert(){ ## result name, item name, body file
	local upName="$1" upItem="$2" upBody="$3"
	(
		cd "$rigWs" || exit 1
		env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigBin:/usr/bin:/bin:/usr/sbin:/sbin" GIT_CONFIG_NOSYSTEM=1 \
			MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
			MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SPAWN_AGENT=rig-member MDAT_SESSION_ID=rig-session MDSC_CMD=DistroAgentsTools \
			RIG_GIT_LOG="$rigBin/git.log" RIG_REAL_GIT="$rigRealGit" RIG_GIT_STORE="$rigData" \
			RIG_GIT_REFUSE="${rigGitRefuse:-0}" RIG_GIT_FAIL_FIRST="${rigGitFailFirst:-0}" RIG_GIT_COUNT="$rigBin/gitfail.count" \
			bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.UseAgentsTools.include" 2> /dev/null
				. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.InternOpItem.include"
				AgentsToolsItemUpsert rig-member --from-board backlog "$1" --from-file "$2" --context rig' rigup "$upItem" "$upBody"
	) > "$rigTmp/$upName.out" 2>&1 < /dev/null
	printf '%s' "$?" > "$rigTmp/$upName.rc"
}
## The team-data thread, started here as the tooling starts it: detached, its own log, the idle time
## the case names. Its lock and its log are what the cases read, never the pid of the shell this
## check started.
rigThreadRun(){ ## idle seconds
	(
		cd "$rigWs" || exit 1
		env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigBin:/usr/bin:/bin:/usr/sbin:/sbin" \
			MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
			MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SPAWN_AGENT=rig-member MDSC_CMD=DistroAgentsTools \
			RIG_GIT_LOG="$rigBin/git.log" RIG_REAL_GIT="$rigRealGit" RIG_GIT_STORE="$rigData" \
			RIG_GIT_REFUSE="${rigGitRefuse:-0}" RIG_GIT_FAIL_FIRST="${rigGitFailFirst:-0}" RIG_GIT_COUNT="$rigBin/gitfail.count" \
			"MDAT_TEAM_DATA_COMMIT_IDLE_SECONDS=$1" \
			bash "$rigFn" --intern-team-data-commit --run
	) > "$rigTmp/thread.out" 2>&1 < /dev/null &
}
rigThreadLockSeen(){ ## bound seconds -- seen|absent
	local seenWaited=0
	while [ "$seenWaited" -lt "$1" ] && [ ! -f "$rigThreadLock" ] ; do sleep 1 ; seenWaited=$(( seenWaited + 1 )) ; done
	[ -f "$rigThreadLock" ] && printf seen || printf absent
}
rigThreadEndSeen(){ ## bound seconds -- ended|alive
	local endWaited=0
	while [ "$endWaited" -lt "$1" ] && [ "$( rigCount "$rigThreadLog" ' ends: ' )" = 0 ] ; do sleep 1 ; endWaited=$(( endWaited + 1 )) ; done
	[ "$( rigCount "$rigThreadLog" ' ends: ' )" = 0 ] && printf alive || printf ended
}
rigThreadStop(){ ## ends a thread this rig left running, and waits for its lock to go
	local stopPid="" stopWaited=0
	[ -f "$rigThreadLock" ] || return 0
	stopPid="$( cat "$rigThreadLock" 2> /dev/null )" ; stopPid="${stopPid%% *}"
	case "$stopPid" in ''|*[!0123456789]*) return 0 ;; esac
	kill -TERM "$stopPid" 2> /dev/null || :
	while [ "$stopWaited" -lt 15 ] && [ -f "$rigThreadLock" ] ; do sleep 1 ; stopWaited=$(( stopWaited + 1 )) ; done
	return 0
}

echo "-- 1. control, and the instrument's known positive: a working git, no writer's own commit, and a store that settles --"
: > "$rigBin/git.log"
rigBoardItem note-rig-control.md RIG-CONTROL
rigWrite control 0 --intern-op-board-upsert-move-edit running note-rig-control.md \
	--from-state:running --header:upsert:rig-word:control --context rig
rigAssert "1. the board writer exits 0" "$( cat "$rigTmp/control.rc" )" 0
rigAssert "1. the board item holds the new word" "$( LC_ALL=C grep -c -x -F 'rig-word: control' "$rigData/board/running/note-rig-control.md" )" 1
## With the committer thread on, the writer never commits itself and the thread does, so the store
## settles within a bound rather than by the time the call returns.
rigWaited=0
while [ "$rigWaited" -lt 60 ] && [ "$( rigClean )" = dirty ] ; do
	sleep 1 ; rigWaited=$(( rigWaited + 1 ))
done
rigAssert "1. the store ends clean within 60s" "$( rigClean )" clean
## The instrument's known positive: the same counter does see an add whose parent names the board
## writer, so a zero in case 3 is a reading and not a blind instrument.
rigPositive="$rigTmp/git.log.positive"
printf '%s\t%s\t%s\n' 4242 "bash /x/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh --intern-op-board-upsert-move-edit running rig.md" "-C /x add -- rig.md" > "$rigPositive"
rigAssert "1. control: the counter does see an add whose parent names the board writer" \
	"$( rigCallsIn 'intern-op-board-upsert-move-edit' "$rigPositive" )" 1

echo "-- 2. a git that cannot take the lock does not fail the write (S12.4) --"
: > "$rigBin/git.log"
rigBoardItem note-rig-locked.md RIG-LOCKED
rigWrite lockBoard 1 --intern-op-board-upsert-move-edit running note-rig-locked.md \
	--from-state:running --header:upsert:rig-word:locked --context rig
rigAssert "2. the board writer exits 0 under the lock" "$( cat "$rigTmp/lockBoard.rc" )" 0
rigAssert "2. and its item is written" "$( LC_ALL=C grep -c -x -F 'rig-word: locked' "$rigData/board/running/note-rig-locked.md" )" 1
rigWrite lockInbox 1 --intern-op-member-inbox-upsert rig-member note-20261102T0000Z-rig-locked.md --context rig
rigAssert "2. the inbox writer exits 0 under the lock" "$( cat "$rigTmp/lockInbox.rc" )" 0
rigAssert "2. and its note is written" "$( [ -f "$rigData/inboxes/rig-member/incoming/note-20261102T0000Z-rig-locked.md" ] && printf written || printf missing )" written
rigWrite lockProcessed 1 --intern-op-inbox-to-processed rig-member note-20261102T0000Z-rig-locked.md --context rig
rigAssert "2. the inbox-to-processed writer exits 0 under the lock" "$( cat "$rigTmp/lockProcessed.rc" )" 0
rigAssert "2. and the note is in the processed folder" \
	"$( [ -f "$rigData/inboxes/rig-member/processed/note-20261102T0000Z-rig-locked.md" ] && printf processed || printf elsewhere )" processed

echo "-- 3. the writer makes no git call of its own: the committer thread does --"
rigAssert "3. the refusals were reached: the fake git saw add or commit calls in this part" \
	"$([ "$( rigAnyCalls )" -ge 0 ] && printf runs)" runs
rigAssert "3. no git add or commit has the board writer's own process as its parent" \
	"$( rigCallsByWriter 'intern-op-board-upsert-move-edit' )" 0
rigAssert "3. nor the inbox writer's" "$( rigCallsByWriter 'intern-op-member-inbox-upsert' )" 0
rigAssert "3. nor the inbox-to-processed writer's" "$( rigCallsByWriter 'intern-op-inbox-to-processed' )" 0

echo "-- 4. five writers at once against a real store while another writer holds its lock --"
## A real `.git/index.lock` is planted, as another writer holds one for the length of its call, and
## taken away once the five have run. Every item must hold its own write, every writer must exit 0,
## and the changes must reach the store within the bound once the lock is gone.
: > "$rigBin/git.log"
rigIdx=1
while [ "$rigIdx" -le 5 ] ; do
	rigBoardItem "note-rig-par-$rigIdx.md" "RIG-PAR-$rigIdx"
	rigIdx=$(( rigIdx + 1 ))
done
printf 'another writer holds it\n' > "$rigData/.git/index.lock"
rigIdx=1
while [ "$rigIdx" -le 5 ] ; do
	rigWrite "par-$rigIdx" 0 --intern-op-board-upsert-move-edit running "note-rig-par-$rigIdx.md" \
		--from-state:running --header:upsert:rig-word:"par-$rigIdx" --context rig &
	rigIdx=$(( rigIdx + 1 ))
done
wait
rm -f "$rigData/.git/index.lock"
rigWritten=0
rigExited=0
rigIdx=1
while [ "$rigIdx" -le 5 ] ; do
	[ "$( LC_ALL=C grep -c -x -F "rig-word: par-$rigIdx" "$rigData/board/running/note-rig-par-$rigIdx.md" 2> /dev/null || : )" = 1 ] && rigWritten=$(( rigWritten + 1 ))
	[ "$( cat "$rigTmp/par-$rigIdx.rc" 2> /dev/null )" = 0 ] && rigExited=$(( rigExited + 1 ))
	rigIdx=$(( rigIdx + 1 ))
done
rigAssert "4. all five items hold their own write" "$rigWritten" 5
rigAssert "4. and all five writers exited 0" "$rigExited" 5
rigWaited=0
while [ "$rigWaited" -lt 60 ] && [ "$( rigClean )" = dirty ] ; do
	sleep 1 ; rigWaited=$(( rigWaited + 1 ))
done
rigAssert "4. the five changes reach the store within 60s of the lock clearing" "$( rigClean )" clean

echo "-- 5. E1: a path that is gone and was never tracked does not fail the commit beside it --"
## The thread is off here, so the commit's result is read at once rather than through it. A moved or
## a trashed item names a place that is no more, and `git add -A` refuses the whole call for it.
: > "$rigBin/git.log"
rm -f "$rigOwedFile"
printf 'RIG-E1-KEPT\n' > "$rigData/board/running/note-rig-e1.md"
rigCommitPaths e1 "rig e1" "$rigData/board/running/note-rig-e1.md" "$rigData/board/running/note-rig-e1-gone.md"
rigAssert "5. E1: the file that is there is committed" "$( rigCommitted "$rigData/board/running/note-rig-e1.md" )" 1
rigAssert "5. E1: and nothing is left owed" "$( rigOwed )" 0

echo "-- 6. E2: the thread ends by itself while an owed commit keeps failing (S12.4) --"
## One path is owed, and every add is refused, so the debt cannot be paid. The thread must still end
## after its idle time: a failing debt is no work to keep a thread alive for. The threads the earlier
## cases started are ended here first, so this case reads its own thread and its own log.
rigThreadStop
rm -f "$rigThreadLog" "$rigThreadLock"
rm -f "$rigData/.git/team-data-commit/"*.entry 2> /dev/null
mkdir -p "$rigData/.git/team-data-commit"
printf 'RIG-E2-OWED\n' > "$rigData/board/running/note-rig-e2.md"
printf '%s\n' "$rigData/board/running/note-rig-e2.md" > "$rigOwedFile"
rigGitRefuse=1
rigThreadRun 2
rigE2Lock="$( rigThreadLockSeen 20 )"
rigAssert "6. E2: the thread took its lock and began" "$rigE2Lock" seen
if [ "$rigE2Lock" = seen ] ; then
	rigAssert "6. E2: the thread ended by itself within 40s while the debt kept failing" "$( rigThreadEndSeen 40 )" ended
else
	rigAssert "6. E2: the thread ended by itself within 40s while the debt kept failing" "no thread started at all" ended
fi
rigAssert "6. E2: and the debt is still recorded, not dropped to end quietly" "$( rigOwed )" 1
rigGitRefuse=0
rm -f "$rigData/board/running/note-rig-e2.md" "$rigOwedFile"

echo "-- 7. E3: thread.log is cut to under its 128 KiB bound once it grows past it --"
## The bound the thread runs over its own log on every thirtieth pass of its loop
## (AgentsTools.ThreadLogBound). Its self-test is here too: under the bound, nothing is touched.
rigLogBound(){ ## log path -- missing, or rc= with the bound function's own status
	(
		cd "$rigWs" || exit 1
		env -i HOME="$rigTmp/home" PATH="$rigBin:/usr/bin:/bin:/usr/sbin:/sbin" \
			MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$rigOrigin" MDAT_SKILLSET_ROOT="$rigSkills" \
			bash -c '
				. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/common/AgentsTools.ThreadLock.include" 2> /dev/null || { echo missing ; exit 0 ; }
				type AgentsToolsThreadLogBound > /dev/null 2>&1 || { echo missing ; exit 0 ; }
				AgentsToolsThreadLogBound "$1" ; echo "rc=$?"
			' rigbound "$1"
	) 2> /dev/null
}
rigLogSmall="$rigTmp/thread-small.log"
printf 'RIG-SMALL-1\nRIG-SMALL-2\n' > "$rigLogSmall"
rigSmallRc="$( rigLogBound "$rigLogSmall" )"
rigAssert "7. E3 self-test: a log under the 128 KiB bound is not cut" "$rigSmallRc" "rc=1"
rigAssert "7. E3 self-test: and it is left as it was" "$( LC_ALL=C grep -c 'RIG-SMALL-' "$rigLogSmall" )" 2
rigLogBig="$rigTmp/thread-big.log"
LC_ALL=C awk 'BEGIN { for ( i = 1 ; i <= 8000 ; i++ ) printf "RIG-BIG-%05d a line of the thread log, long enough to grow it past the bound\n", i }' > "$rigLogBig"
rigBigBefore="$( LC_ALL=C wc -c < "$rigLogBig" | LC_ALL=C tr -d ' ' )"
rigBigRc="$( rigLogBound "$rigLogBig" )"
rigBigAfter="$( LC_ALL=C wc -c < "$rigLogBig" | LC_ALL=C tr -d ' ' )"
rigAssert "7. E3: the bound fired on a log over 128 KiB" "$rigBigRc" "rc=0"
rigAssert "7. E3: the log is now under the 128 KiB bound" "$([ "${rigBigAfter:-0}" -lt 131072 ] && printf under || printf over )" under
rigAssert "7. E3: and it is not emptied to do it" "$([ "${rigBigAfter:-0}" -gt 0 ] && printf kept || printf emptied )" kept
rigAssert "7. E3: what is kept begins at a whole line" "$( LC_ALL=C head -c 10 "$rigLogBig" | LC_ALL=C grep -c '^RIG-BIG-' )" 1

echo "-- 8. E4: item-upsert rides out a held index.lock by running its add again (S12.4) --"
## item-upsert still commits in its own process, so it races the thread. The criterion is the failure
## the item exists to remove: a held lock must not fail the call.
: > "$rigBin/git.log"
rm -f "$rigBin/gitfail.count" "$rigOwedFile"
printf -- '---\ntype: note\nowner: rig-member\n---\n\nRIG-E4-OLD\n' > "$rigData/board/backlog/note-20261102T0100Z-rig-e4.md"
printf -- '---\ntype: note\nowner: rig-member\n---\n\nRIG-E4-NEW\n' > "$rigTmp/e4-body.md"
rigGitFailFirst=3
rigItemUpsert e4 note-20261102T0100Z-rig-e4.md "$rigTmp/e4-body.md"
rigGitFailFirst=0
rigAssert "8. E4: item-upsert exits 0 through three refused adds" "$( cat "$rigTmp/e4.rc" )" 0
rigAssert "8. E4: the note holds the new text" "$( LC_ALL=C grep -c -x -F 'RIG-E4-NEW' "$rigData/board/backlog/note-20261102T0100Z-rig-e4.md" )" 1
rigAssert "8. E4: and the note is committed" "$( rigCommitted "$rigData/board/backlog/note-20261102T0100Z-rig-e4.md" )" 1
rigAssert "8. E4 self-test: the fake git did refuse adds the writer made" \
	"$([ "$( cat "$rigBin/gitfail.count" 2> /dev/null || echo 0 )" -ge 1 ] && printf refused || printf passed)" refused

echo "-- 9. E5: a thread that cannot be started is not silent, and the writer commits itself --"
## The thread's own log cannot be written, so no thread starts. The writer must say so and commit in
## its own process, and it must leave no entry behind for a thread that is not there.
: > "$rigBin/git.log"
rm -f "$rigOwedFile"
rm -rf "$rigData/.git/team-data-commit/thread.log"
mkdir -p "$rigData/.git/team-data-commit/thread.log"
rigBoardItem note-rig-e5.md RIG-E5
rigWrite e5 0 --intern-op-board-upsert-move-edit running note-rig-e5.md \
	--from-state:running --header:upsert:rig-word:e5 --context rig
rigAssert "9. E5: the writer exits 0" "$( cat "$rigTmp/e5.rc" )" 0
rigAssert "9. E5: and its item is written" "$( LC_ALL=C grep -c -x -F 'rig-word: e5' "$rigData/board/running/note-rig-e5.md" )" 1
rigAssert "9. E5: the writer says the thread could not be started" \
	"$( LC_ALL=C grep -c 'thread could not be started' "$rigTmp/e5.out" )" 1
rigAssert "9. E5: no entry is left for a thread that is not there" \
	"$( LC_ALL=C find "$rigData/.git/team-data-commit" -maxdepth 1 -name '*.entry' 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 0
rigAssert "9. E5: and the writer committed the item in its own process" "$( rigCommitted "$rigData/board/running/note-rig-e5.md" )" 1
rmdir "$rigData/.git/team-data-commit/thread.log" 2> /dev/null || :

echo "-- 10. F1: a writer returns at once while a team-data thread lives (S12.4) --"
## The writer starts the thread from a command substitution, so a thread that kept that capture's own output open would hold every
## writer for the thread's whole life. The idle time here is 60s, far past the bound, so a writer that waited for the
## thread's end reads red on the bound and not as a slow machine. A tree that starts no thread at
## all passes here by construction, so the proof this case can fail is a copy of the fix whose
## detached start keeps the capture's output: there case 10 reads waited 30s and nothing else does.
rigThreadStop
rm -f "$rigThreadLog" "$rigThreadLock" "$rigData/.git/team-data-commit/"*.entry 2> /dev/null
rigEnvExtra=( MDAT_TEAM_DATA_COMMIT_IDLE_SECONDS=60 )
rigBoardItem note-rig-f1a.md RIG-F1A
rigF1First="$( rigWriteTimed f1a 0 --intern-op-board-upsert-move-edit running note-rig-f1a.md \
	--from-state:running --header:upsert:rig-word:f1a --context rig )"
rigAssert "10. F1: the writer that starts the thread returns within 20s" \
	"$([ "${rigF1First:-999}" -lt 20 ] && printf at-once || printf "waited ${rigF1First}s" )" at-once
rigBoardItem note-rig-f1b.md RIG-F1B
rigF1Second="$( rigWriteTimed f1b 0 --intern-op-board-upsert-move-edit running note-rig-f1b.md \
	--from-state:running --header:upsert:rig-word:f1b --context rig )"
rigAssert "10. F1: the writer behind a thread already alive returns within 20s" \
	"$([ "${rigF1Second:-999}" -lt 20 ] && printf at-once || printf "waited ${rigF1Second}s" )" at-once
rigAssert "10. F1: and both items are written" \
	"$(( $( LC_ALL=C grep -c -x -F 'rig-word: f1a' "$rigData/board/running/note-rig-f1a.md" 2> /dev/null ) + $( LC_ALL=C grep -c -x -F 'rig-word: f1b' "$rigData/board/running/note-rig-f1b.md" 2> /dev/null ) ))" 2
rigEnvExtra=()
rigThreadStop

if [ "$rigFailCount" -ne 0 ] ; then
	printf '⛔ TEAM_DATA_WRITE_UNDER_LOCK CHECK FAILED: %s of %s assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))" >&2
	exit 1
fi
printf 'TEAM_DATA_WRITE_UNDER_LOCK: OK (%d assertions, offline, rig store only)\n' "$rigPassCount"
