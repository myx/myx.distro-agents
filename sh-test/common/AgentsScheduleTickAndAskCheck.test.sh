#!/usr/bin/env bash
## Behavioural check on two rules of the schedule the coordinator's note of 2026-11-06 names, neither of which any check covers today:
##   the on-demand thread TICK that answers 2 keeps the thread past its idle bound, and a tick that answers 0 does not;
##   and `--override-flag` on the dispatcher asks the schedule thread ONCE, so a flag set by hand starts duties with no session live.
## Held:
##   1. A TICK THAT ANSWERS 0 still ends the thread at its idle bound.
##   2. A TICK THAT ANSWERS 2 keeps it past that bound, and the thread is still there afterwards.
##   3. `--override-flag` makes exactly one ask of the thread.
##   4. A DISPATCHER ARM THAT IS NOT THE OVERRIDE makes none, so the ask in row 3 is that arm's own and not a call every arm makes.
## Offline: a rig folder of its own, no workspace read, no agent CLI on PATH.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-lib/common/AgentsTools.OnDemandThread.include" ] || rigRefuse "the on-demand thread's include is not in the package"
[ -f "$rigPackage/sh-scripts/DistroAgentsDispatcher.fn.sh" ] || rigRefuse "the dispatcher is not in the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsScheduleTickAndAskCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
rigThreadsEnd(){
	[ -z "$rigStarted" ] || rigProcSignalWithChildren KILL $rigStarted 2> /dev/null || :
	rigStarted=""
}
rigStop(){
	rigThreadsEnd
	chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp" 2> /dev/null || :
}
trap 'rigStop' EXIT
trap 'exit 1' INT TERM
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 )) ; printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}
rigLocks(){ ## folder -- 1 while a thread holds its lock, 0 once it has given it back
	[ -s "$1/thread.lock" ] && printf '1' || printf '0'
}
rigWaitedFor(){ ## folder, seconds -- rc 0 once the lock is gone, 1 at the bound
	local waitedFor=0
	while [ "$waitedFor" -lt "$2" ] && [ "$( rigLocks "$1" )" != 0 ] ; do sleep 1 ; waitedFor=$(( waitedFor + 1 )) ; done
	[ "$( rigLocks "$1" )" = 0 ]
}
## THE TICK: answers what RIG_TICK_RC holds, and counts itself. The handler answers any request with one line.
cat > "$rigTmp/tick.sh" <<'RIGTICK'
#!/usr/bin/env bash
printf 'tick\n' >> "$RIG_TICK_FILE"
exit "$RIG_TICK_RC"
RIGTICK
chmod +x "$rigTmp/tick.sh"
rigServe(){ ## folder, idle seconds, tick-rc -- a serving thread in the background
	RIG_TICK_FILE="$rigTmp/ticks.$2.$3" RIG_TICK_RC="$3" \
	RIG_FOLDER="$1" RIG_IDLE="$2" RIG_TICK="$rigTmp/tick.sh" RIG_INC="$rigPackage/sh-lib/common/AgentsTools.OnDemandThread.include" \
	bash -c '
		set +u
		. "$RIG_INC" || exit 1
		rigAnswerHandler(){ printf "handled %s\n" "$2" ; }
		AgentsToolsOnDemandThreadServe "$RIG_FOLDER" "$RIG_IDLE" rigAnswerHandler "$RIG_TICK" no
	' >> "$rigTmp/serve.$2.$3.log" 2>&1 &
	rigStarted="$rigStarted $!"
	: > "$rigTmp/ticks.$2.$3"
}

echo "-- 1. a tick that answers 0 still ends the thread at its bound --"
rigDir1="$rigTmp/thread1" ; mkdir -p "$rigDir1"
rigServe "$rigDir1" 3 0
sleep 1
rigAssert "1. the thread took its lock" "$( rigLocks "$rigDir1" )" 1
rigWaitedFor "$rigDir1" 20 && rigEnded=yes || rigEnded=no
rigAssert "1. a tick that answers 0 lets the thread end at its idle bound" "$rigEnded" yes

echo "-- 2. a tick that answers 2 keeps the thread past that bound --"
rigDir2="$rigTmp/thread2" ; mkdir -p "$rigDir2"
rigServe "$rigDir2" 3 2
sleep 1
rigAssert "2. the thread took its lock" "$( rigLocks "$rigDir2" )" 1
sleep 12
rigAssert "2. twelve seconds on, three times its idle bound, it is still there" "$( rigLocks "$rigDir2" )" 1
rigAssert "2. and its tick was asked more than once" "$( [ "$( LC_ALL=C grep -c '^tick$' "$rigTmp/ticks.3.2" 2> /dev/null | LC_ALL=C head -1 )" -gt 1 ] && printf many || printf few )" many
rigThreadsEnd

echo "-- 3. --override-flag asks the thread once --"
rigData="$rigTmp/data" rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/agents" "$rigData" "$rigTmp/home" "$rigTmp/bin"
## The ask is counted, not made: a stand-in on the include's own name, so no real thread is started by this row.
cat > "$rigTmp/bin/dispatch" <<'RIGDISPATCH'
#!/usr/bin/env bash
## Runs the real dispatcher with the ask stand-in in place. The counting file is the only thing this wrapper adds.
exec bash "$RIG_REAL_DISPATCHER" "$@"
RIGDISPATCH
chmod +x "$rigTmp/bin/dispatch"
rigDispatch(){ ## -- the number of thread asks the arm made, from RIG_ASKS
	: > "$rigTmp/asks"
	env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		MDAT_SCHEDULE_THREAD=off MDAT_WORKSPACE_MODE=team-rig \
		RIG_ASKS="$rigTmp/asks" RIG_REAL_DISPATCHER="$rigPackage/sh-scripts/DistroAgentsDispatcher.fn.sh" \
		bash -c '
			## The include defines the ask; the stand-in goes in after it is sourced, as the arm sources it lazily.
			AgentsToolsScheduleThreadAsk(){ printf "ask\n" >> "$RIG_ASKS" ; return 0 ; }
			export -f AgentsToolsScheduleThreadAsk
			bash "$RIG_REAL_DISPATCHER" "$@" > /dev/null 2>&1
		' rig "$@"
	printf '%s' "$( LC_ALL=C grep -c '^ask$' "$rigTmp/asks" 2> /dev/null | LC_ALL=C head -1 )"
}
mkdir -p "$rigTmp/skills/rig-member"
printf 'status: active\n' > "$rigTmp/skills/rig-member/SKILL.md"
rigAssert "3. --override-flag emergency makes exactly one ask of the thread" "$( rigDispatch --override-flag emergency 3600 )" "1"
rigAssert "4. --current-flags makes none, so the ask above is the override's own" "$( rigDispatch --current-flags )" "0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SCHEDULE TICK AND ASK CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'SCHEDULE_TICK_AND_ASK: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
