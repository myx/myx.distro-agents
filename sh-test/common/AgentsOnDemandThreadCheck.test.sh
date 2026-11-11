#!/usr/bin/env bash
## Behavioural check on S12.11, the shared on-demand thread, and on its first use, S12.4's team-data committer.
##   1. THE CONTROL, and the instrument's known positive: one thread serves a caller's request, and the answer the
##      caller reads is the handler's own words. A second case reads the same assertion against a handler that
##      answers other words, so a green here is a reading and not a blind instrument.
##   2. Two callers at once are served in order, each with its own answer: no answer crosses to the other caller.
##   3. A caller that wants no answer returns at once, rc 0, and its work is done.
##   4. A request naming a reply fifo that is gone does not end the thread, and the next caller is still answered.
##   5. A handler that ran and said nothing reads as served-and-empty, rc 0 with no output. A folder
##      holding no thread at all reads rc 1. The two outcomes separate.
##   6. The thread ends by itself once no request came for its idle bound, and gives its lock back.
##   7. TERM ends the thread, and it gives its lock back.
##   8. A start says alive for a thread that lives, and starts one where none lives.
##   9. The team data's first use: the thread the store's writers start holds the request fifo, the commit reaches the store,
##      and the thread is ended rather than left behind.
##  10. A request written in the moment a thread is started is answered: the start holds the fifo open across its fork.
## Offline: every thread, store and reply fifo is under this rig's own temp folder.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPkg="$rigOrigin/myx/myx.distro-agents"
rigFn="$rigPkg/sh-scripts/DistroAgentsTools.fn.sh"
rigInc="$rigPkg/sh-lib/common/AgentsTools.OnDemandThread.include"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigFn" ] || rigRefuse "the tooling is not at the origin this workspace resolves: $rigFn"
command -v git > /dev/null || rigRefuse "git is not installed"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigPkg/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsOnDemandThreadCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigThreadsStop ; rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## The owner the thread serves here: its handler answers the request's fields, its tick counts itself. A handler that
## answers other words stands beside it, so case 1 can read the same assertion twice and get two answers.
rigOwner="$rigTmp/owner.sh"
cat > "$rigOwner" <<'RIGOWNER'
rigAnswerHandler(){
	if [ "${1:-}" = "wrong" ] ; then
		printf 'the other words\n' >&3
	else
		printf 'handled %s\n' "${1:-nothing}" >&3
	fi
	return 0
}
rigSilentHandler(){ return 0 ; }
rigTickCount(){ printf 'tick\n' >> "$RIG_TICK_FILE" ; }
RIGOWNER

## One serving thread of its own, under its own folder: started the way an owner starts one, in the background, and
## stopped by its pid. Its folder is what the cases read.
rigThreadPid="" rigThreadDir=""
rigThreadsStop(){
	[ -z "${rigThreadPids:-}" ] || rigProcSignal TERM $rigThreadPids
	rigThreadPids=""
	return 0
}
rigThreadPids=""
rigServe(){ ## folder, idle seconds, handler, tick -- starts a serving thread there
	(
		cd "$rigTmp" || exit 1
		. "$rigInc" || exit 1
		. "$rigOwner" || exit 1
		AgentsToolsOnDemandThreadServe "$1" "$2" "$3" "$4" no
	) >> "$1.log" 2>&1 &
	rigThreadPids="$rigThreadPids $!" ; rigProcNote "${rigThreadPids##* }"
	set -- "$1"
	rigWaitForFifo "$1"
}
rigWaitForFifo(){ ## folder -- up to 20s, then says so loudly
	local waited=0
	while [ "$waited" -lt 20 ] && [ ! -p "$1/request.fifo" ] ; do sleep 1 ; waited=$(( waited + 1 )) ; done
	[ -p "$1/request.fifo" ] || { echo "⛔ ERROR: the thread never made its request fifo: $1" >&2 ; exit 1 ; }
	return 0
}
rigAsk(){ ## folder, bound, the request's fields... -- the answer, and the caller's own rc beside it
	(
		. "$rigInc" || exit 1
		AgentsToolsOnDemandThreadAsk "$@"
	) > "$rigTmp/ask.out" 2>&1
	printf '%s' "$?"
}
rigAskAnswer(){ cat "$rigTmp/ask.out" 2> /dev/null ; }
rigLocks(){ ## folder -- how many lock files stand there
	LC_ALL=C find "$1" -maxdepth 1 -name 'thread.lock' 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' '
}

echo "-- 1. control: a caller's answer is the handler's own words --"
rigDir1="$rigTmp/thread1"
mkdir -p "$rigDir1"
export RIG_TICK_FILE="$rigTmp/ticks1"
rigServe "$rigDir1" 20 rigAnswerHandler rigTickCount
rigAssert "1. the caller's ask exits 0" "$( rigAsk "$rigDir1" 8 hello )" 0
rigAssert "1. and its answer is the handler's own words" "$( rigAskAnswer )" "handled hello"
## The known positive for the assertion above: the same reading, against words the assertion does not claim.
rigDir1b="$rigTmp/thread1b"
mkdir -p "$rigDir1b"
rigServe "$rigDir1b" 20 rigAnswerHandler rigTickCount
rigAsk "$rigDir1b" 8 wrong > /dev/null
rigAssert "1. the instrument is not blind: other words read as other words" "$( rigAskAnswer )" "the other words"
rigThreadsStop

echo "-- 2. two callers at once are each answered with their own request --"
rigDir2="$rigTmp/thread2"
mkdir -p "$rigDir2"
export RIG_TICK_FILE="$rigTmp/ticks2"
rigServe "$rigDir2" 20 rigAnswerHandler rigTickCount
(
	. "$rigInc" || exit 1
	AgentsToolsOnDemandThreadAsk "$rigDir2" 10 first
) > "$rigTmp/ask2a.out" 2>&1 &
rigA=$!
(
	. "$rigInc" || exit 1
	AgentsToolsOnDemandThreadAsk "$rigDir2" 10 second
) > "$rigTmp/ask2b.out" 2>&1 &
rigB=$!
wait "$rigA" ; wait "$rigB"
rigAssert "2. the first caller holds its own answer" "$( cat "$rigTmp/ask2a.out" )" "handled first"
rigAssert "2. the second caller holds its own answer" "$( cat "$rigTmp/ask2b.out" )" "handled second"
rigThreadsStop

echo "-- 3. a caller that wants no answer returns at once, and its work is done --"
rigDir3="$rigTmp/thread3"
mkdir -p "$rigDir3"
export RIG_TICK_FILE="$rigTmp/ticks3"
rigServe "$rigDir3" 20 rigAnswerHandler rigTickCount
rigFrom="$SECONDS"
rigAsk "$rigDir3" - fire > /dev/null
rigTook=$(( SECONDS - rigFrom ))
rigAssert "3. and it returns in under 3s" "$([ "$rigTook" -lt 3 ] && printf at-once || printf "took ${rigTook}s" )" at-once
sleep 2
rigAssert "3. its request reached the handler" "$( [ -s "$rigTmp/ticks3" ] && printf ticked || printf quiet )" ticked
rigThreadsStop

echo "-- 4. a request naming a reply fifo that is gone does not end the thread --"
rigDir4="$rigTmp/thread4"
mkdir -p "$rigDir4"
export RIG_TICK_FILE="$rigTmp/ticks4"
rigServe "$rigDir4" 20 rigAnswerHandler rigTickCount
mkfifo "$rigDir4/reply.gone" 2> /dev/null
exec 7<> "$rigDir4/reply.gone"
printf 'gone\t%s\n' "$rigDir4/reply.gone" > "$rigDir4/request.fifo"
exec 7>&-
rm -f "$rigDir4/reply.gone"
sleep 2
rigAssert "4. the thread is still there" "$( rigLocks "$rigDir4" )" 1
rigAsk "$rigDir4" 8 after > /dev/null
rigAssert "4. and the next caller is still answered" "$( rigAskAnswer )" "handled after"
rigThreadsStop

echo "-- 5. a handler that ran and said nothing reads as served-and-empty; no thread at all is no answer --"
rigDir5="$rigTmp/thread5"
mkdir -p "$rigDir5"
export RIG_TICK_FILE="$rigTmp/ticks5"
rigServe "$rigDir5" 20 rigSilentHandler rigTickCount
rigAssert "5. a caller served by a silent handler reads rc 0, its answer empty" "$( rigAsk "$rigDir5" 5 quiet )" 0
rigAssert "5. and its answer is empty" "$( rigAskAnswer )" ""
rigAssert "5. and the caller left no reply fifo behind" \
	"$( LC_ALL=C find "$rigDir5" -maxdepth 1 -name 'reply.*' 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 0
rigThreadsStop
## The other direction: a folder with no thread at all is still no answer, and is rc 1.
rigDir5b="$rigTmp/thread5b"
mkdir -p "$rigDir5b"
rigAssert "5. a folder holding no thread reads rc 1, so the two outcomes separate" "$( rigAsk "$rigDir5b" 2 quiet )" 1

echo "-- 6. the thread ends by itself once no request came for its idle bound --"
rigDir6="$rigTmp/thread6"
mkdir -p "$rigDir6"
export RIG_TICK_FILE="$rigTmp/ticks6"
rigServe "$rigDir6" 3 rigAnswerHandler rigTickCount
rigAssert "6. the thread held its lock while it lived" "$( rigLocks "$rigDir6" )" 1
rigWaited=0
while [ "$rigWaited" -lt 25 ] && [ "$( rigLocks "$rigDir6" )" != 0 ] ; do sleep 1 ; rigWaited=$(( rigWaited + 1 )) ; done
rigAssert "6. and gave its lock back within 25s of its idle bound" "$( rigLocks "$rigDir6" )" 0
rigAssert "6. its log says why it left" "$( LC_ALL=C grep -c 'no request came for' "$rigDir6.log" )" 1
rigThreadsStop

echo "-- 7. TERM ends the thread, and it gives its lock back --"
rigDir7="$rigTmp/thread7"
mkdir -p "$rigDir7"
export RIG_TICK_FILE="$rigTmp/ticks7"
(
	cd "$rigTmp" || exit 1
	. "$rigInc" || exit 1
	. "$rigOwner" || exit 1
	AgentsToolsOnDemandThreadServe "$rigDir7" 300 rigAnswerHandler rigTickCount no
) >> "$rigDir7.log" 2>&1 &
rigSeven="$!" ; rigProcNote "$rigSeven"
rigWaitForFifo "$rigDir7"
rigProcSignal TERM "$rigSeven"
rigWaited=0
while [ "$rigWaited" -lt 10 ] && kill -0 "$rigSeven" 2> /dev/null ; do sleep 1 ; rigWaited=$(( rigWaited + 1 )) ; done
rigAssert "7. the thread ended on TERM within 10s" "$([ "$rigWaited" -lt 10 ] && printf ended || printf alive)" ended
rigAssert "7. and gave its lock back" "$( rigLocks "$rigDir7" )" 0
rigAssert "7. its log names the TERM" "$( LC_ALL=C grep -c 'ended by TERM' "$rigDir7.log" )" 1

echo "-- 8. a start says alive for a living thread, and starts one where none lives --"
rigDir8="$rigTmp/thread8"
mkdir -p "$rigDir8"
export RIG_TICK_FILE="$rigTmp/ticks8"
rigAssert "8. a start with no thread there starts one" \
	"$( . "$rigInc" ; . "$rigOwner" ; AgentsToolsOnDemandThreadStart "$rigDir8" --intern-team-data-commit --one | LC_ALL=C awk '{ print $1 }' )" started
rigWaitForFifo "$rigDir8"
(
	cd "$rigTmp" || exit 1
	. "$rigInc" || exit 1
	. "$rigOwner" || exit 1
	AgentsToolsOnDemandThreadServe "$rigDir8" 30 rigAnswerHandler rigTickCount no
) >> "$rigDir8.log" 2>&1 &
rigThreadPids="$rigThreadPids $!" ; rigProcNote "${rigThreadPids##* }"
rigWaited=0
while [ "$rigWaited" -lt 20 ] && [ "$( rigLocks "$rigDir8" )" != 1 ] ; do sleep 1 ; rigWaited=$(( rigWaited + 1 )) ; done
rigAssert "8. a start over a living thread says alive" \
	"$( . "$rigInc" ; AgentsToolsOnDemandThreadStart "$rigDir8" --intern-team-data-commit --one | LC_ALL=C awk '{ print $1 }' )" alive
rigThreadsStop

echo "-- 9. the team data's first use: a request fifo and the commit reaching the store --"
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
rigSkills="$rigWs/.local/agents/members"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents" "$rigData/board/running" "$rigTmp/home" "$rigSkills/rig-member"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nNO_PROXY=*\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf -- '---\nname: rig-member\nstatus: active\n---\nrig member\n' > "$rigSkills/rig-member/SKILL.md"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/rig-member/rig-member.basic.md"
git -C "$rigData" init -q || rigRefuse "could not init the rig store"
git -C "$rigData" config user.email rig@example.invalid
git -C "$rigData" config user.name rig
printf 'seed\n' > "$rigData/README.md"
git -C "$rigData" add -A && git -C "$rigData" commit -q -m seed || rigRefuse "could not seed the rig store"
rigThreadFolder="$rigData/.git/team-data-commit"
printf -- '---\ntype: note\nowner: rig-member\n---\n\nRIG-S12\n' > "$rigData/board/running/note-rig-s12.md"
(
	cd "$rigWs" || exit 1
	printf 'rig body\n' | env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SPAWN_AGENT=rig-member \
		MDAT_TEAM_DATA_COMMIT_WAIT=yes \
		bash "$rigFn" --intern-op-board-upsert-move-edit running note-rig-s12.md \
			--from-state:running --header:upsert:rig-word:s12 --context rig
) > "$rigTmp/s12.out" 2>&1 < /dev/null
rigAssert "9. the writer exits 0" "$( printf '%s' "$?" )" 0
rigAssert "9. its item holds the new word" "$( LC_ALL=C grep -c -x -F 'rig-word: s12' "$rigData/board/running/note-rig-s12.md" )" 1
rigAssert "9. the thread's request fifo is there" "$([ -p "$rigThreadFolder/request.fifo" ] && printf fifo || printf none)" fifo
rigAssert "9. and the thread is the one the store's writers start" \
	"$( LC_ALL=C grep -c 'the thread runs as pid' "$rigThreadFolder/thread.log" 2> /dev/null )" 1
rigWaited=0
while [ "$rigWaited" -lt 30 ] && [ -n "$( git -C "$rigData" status --porcelain --untracked-files=all )" ] ; do sleep 1 ; rigWaited=$(( rigWaited + 1 )) ; done
rigAssert "9. the store ends clean within 30s" \
	"$([ -z "$( git -C "$rigData" status --porcelain --untracked-files=all )" ] && printf clean || printf dirty)" clean
rigAssert "9. and the item's own path is committed" \
	"$( LC_ALL=C git -C "$rigData" log --format=%s -1 -- board/running/note-rig-s12.md 2> /dev/null | LC_ALL=C grep -c . )" 1
## The store's thread is this rig's, and it is ended here rather than left behind.
if [ -f "$rigThreadFolder/thread.lock" ] ; then
	rigStoreThread="$( cat "$rigThreadFolder/thread.lock" 2> /dev/null )"
	rigProcNoteFrom "$rigThreadFolder/thread.lock" ; rigProcSignal TERM "${rigStoreThread%% *}"
	rigWaited=0
	while [ "$rigWaited" -lt 15 ] && [ -f "$rigThreadFolder/thread.lock" ] ; do sleep 1 ; rigWaited=$(( rigWaited + 1 )) ; done
fi
rigAssert "9. the rig's own thread is ended, with no lock left" "$([ -f "$rigThreadFolder/thread.lock" ] && printf locked || printf clear)" clear

## A request written in the moment the thread is born is not lost: the start holds the fifo open across its fork, so the writer's
## line waits for the thread instead of going with the last descriptor. Three starts of the real team-data thread, each asked at once.
echo "-- 10. a request written the moment a thread is started is answered --"
rigData10="$rigTmp/store10"
mkdir -p "$rigData10/board/running" "$rigTmp/ws10/.local/agents"
git -C "$rigData10" init -q || rigRefuse "could not init the store for case 10"
git -C "$rigData10" config user.email rig@example.invalid
git -C "$rigData10" config user.name rig
printf 'seed\n' > "$rigData10/README.md"
git -C "$rigData10" add -A && git -C "$rigData10" commit -q -m seed || rigRefuse "could not seed the store for case 10"
rigAnswered=0
rigRound=1
while [ "$rigRound" -le 3 ] ; do
	(
		cd "$rigTmp" || exit 1
		MDAT_DATA_ROOT="$rigData10" MMDAPP="$rigTmp/ws10" MDLT_ORIGIN="$rigOrigin" MDAT_TEAM_DATA_COMMIT_IDLE_SECONDS=20 \
			bash -c '
				. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/common/AgentsTools.OnDemandThread.include" || exit 1
				folder="$( . "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.TeamDataCommit.include" ; AgentsToolsTeamDataThreadDir )" || exit 1
				AgentsToolsOnDemandThreadStart "$folder" --intern-team-data-commit --run > /dev/null
				AgentsToolsOnDemandThreadAsk "$folder" 40 commit
			' rigten > "$rigTmp/ask10.out" 2>&1 && printf 'answered\n' > "$rigTmp/ask10.ok"
	) > /dev/null 2>&1 &
	rigTen=$!
	rigWaited=0
	while [ "$rigWaited" -lt 60 ] && [ ! -f "$rigTmp/ask10.ok" ] ; do sleep 1 ; rigWaited=$(( rigWaited + 1 )) ; done
	[ ! -f "$rigTmp/ask10.ok" ] || rigAnswered=$(( rigAnswered + 1 ))
	printf 'round %s waited %ss: %s\n' "$rigRound" "$rigWaited" "$( cat "$rigTmp/ask10.out" 2> /dev/null | LC_ALL=C tr '\n' ' ' )" >> "$rigTmp/ask10.detail"
	rm -f "$rigTmp/ask10.ok"
	if [ -f "$rigData10/.git/team-data-commit/thread.lock" ] ; then
		rigProcNoteFrom "$rigData10/.git/team-data-commit/thread.lock"
		rigProcSignal TERM "$( LC_ALL=C cut -d' ' -f1 "$rigData10/.git/team-data-commit/thread.lock" )"
		rigWaited=0
		while [ "$rigWaited" -lt 10 ] && [ -f "$rigData10/.git/team-data-commit/thread.lock" ] ; do sleep 1 ; rigWaited=$(( rigWaited + 1 )) ; done
	fi
	wait "$rigTen" 2> /dev/null
	rigRound=$(( rigRound + 1 ))
done
rigAssert "10. all three requests written at the thread's birth are answered" "$rigAnswered" 3
[ "$rigAnswered" = 3 ] || { printf '  what each round read:\n' ; sed 's/^/    /' "$rigTmp/ask10.detail" 2> /dev/null ; }

echo "-- 11. a lock whose holder cannot be told is no living thread --"
## The lock names this shell's own pid, with a start that does not match, and `ps` answers nothing at all: the reader can prove
## neither that the process lives nor that it is gone, which is its rc 2. A start must then say so and start nothing, never claim
## a thread that it cannot see. That was the defect: rc 2 read as alive.
rigDir11="$rigTmp/thread11"
mkdir -p "$rigDir11" "$rigTmp/bin11"
printf '#!/bin/sh\nexit 1\n' > "$rigTmp/bin11/ps"
chmod +x "$rigTmp/bin11/ps"
printf '%s %s\n' "$$" "Sun_Nov__1_00:00:00_2026" > "$rigDir11/thread.lock"
rigAssert "11. a lock that cannot be told reads as a failed start, not an alive one" \
	"$( PATH="$rigTmp/bin11:$PATH" ; . "$rigInc" ; . "$rigOwner" ; AgentsToolsOnDemandThreadStart "$rigDir11" --intern-team-data-commit --one | LC_ALL=C awk '{ print $1 }' )" "failed"
rigAssert "11. and nothing was started there" "$([ -p "$rigDir11/request.fifo" ] && printf fifo || printf none)" none

echo "-- 12. a lock whose holder is gone is taken over, and the start says so (S12.14) --"
rigDir12="$rigTmp/t12" ; mkdir -p "$rigDir12"
## The holder: a process that ended, its pid and start kept as the lock names them.
rigGone12="$( sleep 0 & echo $! )" ; wait "$rigGone12" 2> /dev/null || :
printf '%s %s\n' "$rigGone12" "Sun_Nov__1_00:00:00_2026" > "$rigDir12/thread.lock"
rigSaid12="$( . "$rigInc" ; . "$rigOwner" ; AgentsToolsOnDemandThreadStart "$rigDir12" --intern-team-data-commit --one )"
rigAssert "12. the first line is the start, as its readers match it" "$( printf '%s\n' "$rigSaid12" | LC_ALL=C sed -n '1p' | LC_ALL=C sed -n 's/^started [0-9][0-9]*$/started/p' )" started
rigAssert "12. the second line names the lock that outlived its process" "$( printf '%s\n' "$rigSaid12" | LC_ALL=C sed -n '2p' )" "the lock of $rigGone12 outlived its process: taken over"
rigAssert "12. and the thread's log records the take-over" "$( LC_ALL=C grep -c -F "the lock of $rigGone12 Sun_Nov__1_00:00:00_2026 outlived its process: taken over by this start" "$rigDir12/thread.log" 2> /dev/null )" 1
rigPid12="$( printf '%s\n' "$rigSaid12" | LC_ALL=C sed -n '1s/^started //p' )"
[ -z "$rigPid12" ] || { rigThreadPids="$rigThreadPids $rigPid12" ; rigProcNoteFrom "$rigDir12/thread.lock" ; }

if [ "$rigFailCount" -ne 0 ] ; then
	printf '⛔ ON_DEMAND_THREAD CHECK FAILED: %s of %s assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))" >&2
	exit 1
fi
printf 'ON_DEMAND_THREAD: OK (%d assertions, offline, rig threads only)\n' "$rigPassCount"
