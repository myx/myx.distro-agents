#!/usr/bin/env bash
## A board, inbox-note, vault or audit write commits and returns: its push is owed to the one team-data thread, so one push carries several
## commits and no writer waits on another's push under the store lock (AgentsToolsItemUpsertLocked, AgentsToolsTeamDataThreadPassLocked).
## A lock op keeps its push and read-back inline, and so does a write with the thread turned off. Held:
##   1. a plain board write runs no `git push` of its own and leaves the owed marker;
##   2. the thread's next pass pushes once for two writes made under one hold of the store lock, then clears the marker;
##   3. a lock take and its close still push from their own process, and the origin holds them;
##   4. with MDAT_TEAM_DATA_COMMIT_THREAD=off a plain write pushes inline;
##   5. a write with --update-lock alone, a lock refresh, pushes inline from its own process and owes nothing.
## Offline: the store, its bare origin and the git that logs every call are this rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPkg="$rigOrigin/myx/myx.distro-agents"
rigFn="$rigPkg/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigFn" ] || rigRefuse "the tooling is not at the origin this workspace resolves: $rigFn"
command -v git > /dev/null || rigRefuse "git is not installed"
rigRealGit="$( command -v git )"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigPkg/sh-test/check-fixtures/rig-owner-writes.include.sh" || exit 1
. "$rigPkg/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends threads is missing from the package"
rigTmp="$( rigTempDir AgentsItemDeferPushCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigData="$rigTmp/data" ; rigBin="$rigTmp/bin" ; rigBare="$rigTmp/origin.git" ; rigSkills="$rigWs/.local/agents/members"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigBin" "$rigTmp/home" "$rigSkills/rig-member"
printf -- '---\nname: rig-member\nstatus: active\n---\nrig member\n' > "$rigSkills/rig-member/SKILL.md"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/rig-member/rig-member.basic.md"
## The one git on this rig's PATH records each call with its caller's own words, then runs the real one. A writer of this rig is a `bash -c`.
printf '#!/bin/sh\nprintf "%%s\\t%%s\\t%%s\\n" "$PPID" "$( ps -ww -o args= -p "$PPID" 2> /dev/null | tr "\\n" " " )" "$*" >> "$RIG_GIT_LOG"\nexec "$RIG_REAL_GIT" "$@"\n' > "$rigBin/git"
chmod +x "$rigBin/git"
git init -q --bare "$rigBare" || rigRefuse "could not init the bare origin"
git init -q "$rigTmp/seed" && printf 'seed\n' > "$rigTmp/seed/README.md" && git -C "$rigTmp/seed" add -A && git -C "$rigTmp/seed" -c user.email=r@e -c user.name=r commit -q -m seed \
	&& git -C "$rigTmp/seed" push -q "$rigBare" HEAD:main 2> /dev/null || rigRefuse "could not seed the bare origin"
git clone -q -b main "$rigBare" "$rigData" 2> /dev/null || rigRefuse "could not clone the bare origin"
git -C "$rigData" config user.email rig@example.invalid ; git -C "$rigData" config user.name rig
printf 'TEAM_DATA_GIT_REMOTE=%s\nSLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nNO_PROXY=*\n' "$rigBare" > "$rigWs/.local/.agents/magic-team.agent.env"
rigOwnerData="$rigData" rigOwnerWs="$rigWs" rigOwnerHome="$rigTmp/home" rigOwnerBoardReady || rigRefuse "could not make the board's state folders"
rigOwed="$rigWs/.local/agents/team-data-push.owed"
## Where myx.common is, read before env -i empties the environment: the read-back sync of a pushed write runs its git/cloneSync.
rigMyxRoot="$( myx.common which lib/catMarkdown 2> /dev/null )" ; rigMyxRoot="${rigMyxRoot%/bin/lib/catMarkdown*}"
[ -n "$rigMyxRoot" ] || rigRefuse "myx.common is not on this machine's PATH, so a read-back sync cannot run"
rigPassCount=0 ; rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 )) ; fi
}
rigPushes(){ ## fixed text in the caller's words -- how many `git push` calls such a caller made
	LC_ALL=C awk -F'\t' -v who="$1" '$3 ~ /(^| )push( |$)/ && index( $2, who ) { n++ } END { print n + 0 }' "$rigBin/git.log" 2> /dev/null
}
rigRun(){ ## result name, thread setting (on|off), shell text run with the item writer loaded -- in the rig, under one env -i
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigBin:/usr/bin:/bin:/usr/sbin:/sbin" GIT_CONFIG_NOSYSTEM=1 MYXROOT="$rigMyxRoot" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" MDAT_SKILLSET_ROOT="$rigSkills" \
		MDAT_SPAWN_AGENT=rig-member MDAT_SESSION_ID=rig-session MDSC_CMD=DistroAgentsTools RIG_GIT_LOG="$rigBin/git.log" RIG_REAL_GIT="$rigRealGit" \
		$( [ "$2" = off ] && printf 'MDAT_TEAM_DATA_COMMIT_THREAD=off' ) \
		bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsContext.UseAgentsTools.include" 2> /dev/null
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/items/AgentsTools.InternOpItem.include"
			rigWrite(){ printf -- "---\ntype: task\nfrom: rig-member\nowner: rig-member\n---\n\n# %s\n" "$1" | AgentsToolsItemUpsert rig-member --from-board backlog "$1" --upsert-from-stdin --context rigwrite ; }
			'"$3" rigdefer ) > "$rigTmp/$1.out" 2>&1 < /dev/null
	printf '%s' "$?" > "$rigTmp/$1.rc"
}
rigUntilGone(){ ## path, bound seconds -- gone|still there
	local goneWaited=0
	while [ -e "$1" ] && [ "$goneWaited" -lt "$2" ] ; do sleep 1 ; goneWaited=$(( goneWaited + 1 )) ; done
	[ -e "$1" ] && printf 'still there' || printf gone
}
rigOnOrigin(){ git --git-dir="$rigBare" log --format=%s main 2> /dev/null | LC_ALL=C grep -c -F "$1" ; }

echo "-- 1. a plain board write commits and returns: no push of its own, and the push owed --"
rigRun w1 on 'rigWrite task-20990101T0000Z-rig-defer-one.md'
rigAssert "rc 0, no push by the writer, the marker left, and said" \
	"$( cat "$rigTmp/w1.rc" ):$( rigPushes 'bash -c' ):$( [ -e "$rigOwed" ] && echo owed || echo none ):$( LC_ALL=C grep -c -F 'push deferred to the team-data thread' "$rigTmp/w1.out" )" "0:0:owed:1"

echo "-- 2. the thread pushes once for two writes, then the marker goes --"
rigAssert "the first owed push is made by the thread" "$( rigUntilGone "$rigOwed" 30 )" gone
rigThreadBefore="$( rigPushes 'intern-team-data-commit' )"
rigRun w2 on 'type AgentsToolsTeamDataStoreLockTake > /dev/null 2>&1 || . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.TeamDataStoreLock.include"
	AgentsToolsTeamDataStoreLockTake 30 rig && rigWrite task-20990101T0001Z-rig-defer-two.md && rigWrite task-20990101T0002Z-rig-defer-three.md ; AgentsToolsTeamDataStoreLockGive'
rigAssert "the two writes: rc 0, no push by the writer" "$( cat "$rigTmp/w2.rc" ):$( rigPushes 'bash -c' )" "0:0"
rigAssert "the marker goes once the thread has pushed" "$( rigUntilGone "$rigOwed" 30 )" gone
rigAssert "one push by the thread for the two, and both on the origin" \
	"$(( $( rigPushes 'intern-team-data-commit' ) - rigThreadBefore )):$( rigOnOrigin rig-defer-two ):$( rigOnOrigin rig-defer-three )" "1:1:1"

echo "-- 3. a lock take and its close push from their own process --"
rigOp(){ ( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="$rigBin:/usr/bin:/bin:/usr/sbin:/sbin" GIT_CONFIG_NOSYSTEM=1 MYXROOT="$rigMyxRoot" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" \
	MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" MDAT_SKILLSET_ROOT="$rigSkills" MDSC_CMD=DistroAgentsTools RIG_GIT_LOG="$rigBin/git.log" RIG_REAL_GIT="$rigRealGit" \
	bash "$rigFn" "$@" ) > "$rigTmp/op.out" 2>&1 < /dev/null ; }
rigOp --intern-op-routine-lock-take grooming magic-coordinator rig
rigAssert "the take pushed itself, and the origin holds the lock" "$( [ "$( rigPushes routine-lock-take )" -ge 1 ] && echo pushed || echo none ):$( git --git-dir="$rigBare" show main:inboxes/magic-coordinator/incoming/note-20260809T154332Z-grooming-state-and-lock.md 2> /dev/null | LC_ALL=C grep -c -x 'state: grooming-running' )" "pushed:1"
rigOp --intern-op-routine-lock-close grooming magic-coordinator
rigAssert "the close pushed itself and said RELEASED" "$( [ "$( rigPushes routine-lock-close )" -ge 1 ] && echo pushed || echo none ):$( LC_ALL=C grep -c -x RELEASED "$rigTmp/op.out" )" "pushed:1"

echo "-- 4. with the thread off, a plain write pushes inline --"
rigBefore="$( rigPushes 'bash -c' )"
## With the thread off a write keeps its read-back inline, and a board note is read back by its session-id: the note carries the rig's.
rigRun w4 off 'printf -- "---\ntype: task\nfrom: rig-member\nowner: rig-member\nsession-id: rig-session\n---\n\n# rig\n" | AgentsToolsItemUpsert rig-member --from-board backlog task-20990101T0003Z-rig-defer-four.md --upsert-from-stdin --context rigwrite'
rigAssert "rc 0, and the writer pushed" "$( cat "$rigTmp/w4.rc" ):$(( $( rigPushes 'bash -c' ) - rigBefore ))" "0:1"

echo "-- 5. a lock refresh, --update-lock alone, pushes from its own process --"
## The lock held again, so the refresh has a holder to read back.
rigOp --intern-op-routine-lock-take grooming magic-coordinator rig
## The take's own plain write owes its push to the thread: it is let go first, so what the row reads is the refresh's alone.
rigUntilGone "$rigOwed" 30 > /dev/null
rigBefore="$( rigPushes 'bash -c' )"
rigRun w5 on 'AgentsToolsItemUpsert magic-coordinator note-20260809T154332Z-grooming-state-and-lock.md --update-lock --header:upsert:recheck-date:2099-01-01 --context rig-refresh'
rigAssert "rc 0, REFRESHED, the writer pushed once, and no push owed" \
	"$( cat "$rigTmp/w5.rc" ):$( LC_ALL=C grep -c -x REFRESHED "$rigTmp/w5.out" ):$(( $( rigPushes 'bash -c' ) - rigBefore )):$( [ -e "$rigOwed" ] && echo owed || echo none )" "0:1:1:none"

if [ "$rigFailCount" -ne 0 ] ; then echo "⛔ ITEM DEFER PUSH CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1 ; fi
printf 'ITEM_DEFER_PUSH: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
