#!/usr/bin/env bash
## Behavioural check on how long a work-duty lives (F7.12, the owner's rulings of 2026-10-20; AgentsToolsScheduleDutyLifetime, sh-lib/session/
## AgentsTools.DispatcherLoop.include, taken at each iteration of --intern-main-loop). The real loop (--one) and the real spawner run, as in
## AgentsScheduleLoopCheck; the console, curl, date and every setting are this rig's own, the runs are stand-in processes with milestones and a log
## of their own. GUARD: every tooling call goes through one `env -i` whose child refuses to start unless MMDAPP and MDAT_DATA_ROOT sit under this
## rig's tree and PATH holds no agent CLI. Held, each case on its own:
##   0. LAZY. A standing member with nothing to work on holds no duty, however many iterations pass in worktime; the first item starts it.
##   1. FLAGS ON, CACHE READ OR NOT KNOWN. While worktime holds, a duty in its Wait stays, however long it has been idle -- with the cache read at its
##      last wake and with no cache figure at all (a native CLI prints none).
##   2. THE CACHE READ NOTHING. A duty whose last wake read nothing from the cache -- the last round-1 line of its log says it wrote, or cached
##      nothing, whatever lines came before -- is told to go (DISMISSED) at its idle point after 20 minutes idle, whatever the flags; before them, not.
##   3. HOLIDAYS. While the holidays flag (`--override-flag holidays`) holds, worktime is off: a duty idle for more than an hour with no input is told
##      to go, one idle for less is not; cleared, worktime keeps them again.
##   4. FLAGS OFF. Out of them a duty stays while it has input in its inbox, and while its member takes part in another live run; with neither it
##      ends after one hour idle -- 59 minutes no, 61 yes -- and no longer at once when the worktime flag ends; the input worked off, or the other
##      run ended, it is told to go at the next iteration.
## Offline, rig tree only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRealTemplate="$rigPackage/sh-lib/templates/spawn-brief.document.format.md"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" ] || rigRefuse "dispatcher not found"
[ -f "$rigRealTemplate" ] || rigRefuse "the brief template is not in the package: $rigRealTemplate"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDutyLifetimeCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
rigRemoveTree(){
	local removeLeft=10
	while [ "$removeLeft" -gt 0 ] ; do
		chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp" 2> /dev/null
		[ ! -e "$rigTmp" ] && return 0
		sleep 1 ; removeLeft=$(( removeLeft - 1 ))
	done
	rm -rf -- "$rigTmp"
}
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rigProcSignalWithChildren KILL $rigStarted ; rigRemoveTree' EXIT
trap 'exit 1' INT TERM
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 )) ; printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
. "$rigPackage/sh-test/check-fixtures/rig-schedule-loop.include.sh" || rigRefuse "the schedule rig fixture is missing from the package"
## keeper-rig-01 holds the rig's autoruns; the cases use 02 to 10, and 11 is the member with nothing to work on.
rigScheduleSetup 11
## Monday 2026-10-19 in Etc/GMT-3: 13:00 (worktime) and 18:00 (after it).
rigMon13=1792404000 ; rigMon18=1792422000
rigIso(){ ## epoch -- the stamp of a milestone
	date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ 2> /dev/null || date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ
}
rigNo(){ ## member -- its number, 02 to 10
	printf '%s' "${1##*-}"
}
rigIdle(){ ## member, seconds idle at the clock of the rig -- the milestones of its run: it began, then waited, and a quiet round came back and waited again
	local idleNow idleSpawn
	idleNow="$( cat "$rigDir/now.epoch" )"
	eval "idleSpawn=\"\$rigSpawnOf$( rigNo "$1" )\""
	printf '%s start\n%s wait going idle\n%s wait going idle\n' "$( rigIso $(( idleNow - $2 - 300 )) )" "$( rigIso $(( idleNow - $2 )) )" "$( rigIso $(( idleNow - $2 + 200 )) )" > "$rigStores/$idleSpawn/milestones"
}
rigCache(){ ## member, read|wrote|nothing|none -- the log of its run: an older line of the other kind first, then the last round-1 line (none: a log with no such line)
	local cacheSpawn cacheRecord cacheLog
	eval "cacheSpawn=\"\$rigSpawnOf$( rigNo "$1" )\""
	cacheRecord="$rigSp/$cacheSpawn/$cacheSpawn.spawn.md" ; cacheLog="$rigStores/$cacheSpawn/rig-output.log"
	case "$2" in
		read) printf '%s\n' '   shared prefix -- round 1 cached nothing: the prefix is under the model minimum' '   some work' '   shared prefix -- round 1 read 4100 tokens from the cache' '   more work' > "$cacheLog" ;;
		wrote) printf '%s\n' '   shared prefix -- round 1 read 4100 tokens from the cache' '   some work' '   shared prefix -- round 1 wrote 4100 tokens to the cache for the next session' '   more work' > "$cacheLog" ;;
		nothing) printf '%s\n' '   shared prefix -- round 1 read 4100 tokens from the cache' '   some work' '   shared prefix -- round 1 cached nothing: the prefix is under the model minimum, or its markers were not honoured' '   more work' > "$cacheLog" ;;
		none) printf '%s\n' '   some work' '   more work' > "$cacheLog" ;;
	esac
	LC_ALL=C grep -v '^output-file: ' "$cacheRecord" | LC_ALL=C awk -v outlog="$cacheLog" '{ print } /^status: / { print "output-file: " outlog }' > "$cacheRecord.next" && mv -f "$cacheRecord.next" "$cacheRecord"
}
rigTold(){ ## run name, member -- how many lines of that iteration say the member's duty is told to go
	local toldSpawn
	eval "toldSpawn=\"\$rigSpawnOf$( rigNo "$2" )\""
	rigSaid "$1" "work-duty: $toldSpawn of $2 is told to go"
}

echo "-- 0. a duty is lazy: it starts when something arrives --"
rigAt "$rigMon13"
rigOneRun idle0 ; rigWaitStarts
rigAssert "worktime, a standing member with nothing to work on: no duty is started for it, however many iterations pass" "$( rigDutyCount keeper-rig-11 ):$( rigSaid idle0 'the duty of keeper-rig-11' )" "0:0"
rigDutyMembers="02 03 04 05 06 07 08 09 10"
for rigM in $rigDutyMembers ; do rigItem keeper-rig-$rigM ; done
rigAt $(( rigMon13 + 20 ))
rigOneRun start0 ; rigWaitStarts
## The loop says it started each duty as the call returns, and the record of a start is written as the start goes on, so a busy machine can have the loop's pass
## ended before the last records stand: they are waited for (at most a minute) and then counted, so a duty that was not started is still found.
rigDutyWait=60
while [ "$rigDutyWait" -gt 0 ] && [ "$( for rigM in $rigDutyMembers ; do rigDutyCount keeper-rig-$rigM ; done | tr -d '\n' )" != 111111111 ] ; do sleep 1 ; rigDutyWait=$(( rigDutyWait - 1 )) ; done
rigAssert "the items arrive: the duty of each member that has one is started, and keeper-rig-11, with none, still has none" "$( for rigM in $rigDutyMembers ; do rigDutyCount keeper-rig-$rigM ; done | tr -d '\n' ):$( rigDutyCount keeper-rig-11 )" "111111111:0"
## Each duty becomes a live run in its Wait; their inbox items are worked off but for keeper-rig-08's, which stays (the input of the case it is for).
for rigM in $rigDutyMembers ; do
	rigLive keeper-rig-$rigM idle ; eval "rigSpawnOf$rigM=\"\$rigLiveSpawn\""
	[ "$rigM" = 08 ] || rm -f "$rigData/inboxes/keeper-rig-$rigM/incoming/note-20261019T0900Z-rig-work.md"
done

echo "-- 1. flags on: the duty stays --"
rigAt $(( rigMon13 + 60 ))
rigIdle keeper-rig-02 10800 ; rigCache keeper-rig-02 read
rigIdle keeper-rig-03 10800 ; rigCache keeper-rig-03 none
rigIdle keeper-rig-04 1140 ; rigCache keeper-rig-04 nothing
rigIdle keeper-rig-05 1260 ; rigCache keeper-rig-05 wrote
for rigM in 06 07 08 09 10 ; do rigIdle keeper-rig-$rigM 60 ; rigCache keeper-rig-$rigM read ; done
rigOneRun on1
rigAssert "worktime, the cache read at the last wake: idle for three hours, it stays (an older line that cached nothing does not count)" "$( rigTold on1 keeper-rig-02 )" "0"
rigAssert "worktime, no cache figure known: idle for three hours, it stays" "$( rigTold on1 keeper-rig-03 )" "0"
rigAssert "the cache read nothing, idle 19 minutes: it stays" "$( rigTold on1 keeper-rig-04 )" "0"

echo "-- 2. the cache read nothing: 20 minutes idle, whatever the flags --"
rigAssert "the cache wrote at the last wake and read nothing, idle 21 minutes, worktime on: it is told to go (an older line that read does not count)" "$( rigTold on1 keeper-rig-05 ):$( LC_ALL=C grep -l -F DISMISSED "$rigScn"/post.* 2> /dev/null | wc -l | tr -d ' ' )" "1:1"
rigOneRun on2
rigAssert "...once" "$( rigTold on2 keeper-rig-05 )" "0"
rigAt $(( rigMon13 + 180 ))
rigOneRun on3
rigAssert "the one that was at 19 minutes is at 21 now: told to go" "$( rigTold on3 keeper-rig-04 )" "1"
rigAssert "the others, with the cache read or unknown, are not told" "$( rigTold on3 keeper-rig-02 ):$( rigTold on3 keeper-rig-03 )" "0:0"

echo "-- 3. holidays --"
rigDispatch --override-flag holidays
rigAssert "the holidays flag is on today, and worktime off" "$( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigDir/home" PATH="$rigDir/bin:/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" bash "$rigPackage/sh-scripts/DistroAgentsDispatcher.fn.sh" --current-flags 2> /dev/null | LC_ALL=C grep -e '^holidays: ' -e '^worktime: ' | tr '\n' '|' )" "worktime: no (holiday)|holidays: yes|"
rigIdle keeper-rig-06 3500 ; rigIdle keeper-rig-07 3700
rigAt $(( rigMon13 + 240 ))
rigOneRun hol1
rigAssert "holidays end what worktime kept: the duty idle for hours with the cache read (case 1 kept it) and the one with no cache figure are told to go" "$( rigTold hol1 keeper-rig-02 ):$( rigTold hol1 keeper-rig-03 )" "1:1"
rigAssert "holidays set, inside the hours, idle for less than an hour, no input: the duty stays" "$( rigTold hol1 keeper-rig-06 )" "0"
rigAssert "holidays set, idle for more than an hour, cache read, no input: it is told to go (worktime is off)" "$( rigTold hol1 keeper-rig-07 )" "1"
rigDispatch --override-flag --no holidays

echo "-- 4. flags off: input, a session, one hour --"
rigAt "$rigMon18"
rigIdle keeper-rig-06 3540 ; rigIdle keeper-rig-08 20000 ; rigIdle keeper-rig-09 20000 ; rigIdle keeper-rig-10 3540
rigCache keeper-rig-10 nothing
## keeper-rig-09 takes part in another run: a live run of a routine of its own, besides the duty.
rigOtherSpawn="rig-other-$rigTag"
mkdir -p "$rigSp/$rigOtherSpawn" "$rigStores/$rigOtherSpawn"
printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\nstart-context: spawned\nhost: %s\nworkspace: rigws\nowner: keeper-rig-09\nstatus: spawn-started\nstarted-at: 2026-10-19 17:00 +0300\nroutine: magic-team.discuss.routine.md\n---\n\n# Spawn session: %s\n' "$rigOtherSpawn" "$rigOtherSpawn" "$rigHost" "$rigOtherSpawn" > "$rigSp/$rigOtherSpawn/$rigOtherSpawn.spawn.md"
sleep 600 > /dev/null 2>&1 < /dev/null &
rigOtherPid="$!" ; rigProcNote "$rigOtherPid" ; rigStarted="$rigStarted $rigOtherPid"
printf '%s claude --verbose --session-id %s --agent keeper-rig-09 the brief\n' "$rigOtherPid" "$rigOtherSpawn" >> "$rigDir/ps.list"
disown "$rigOtherPid" 2> /dev/null || :
rigOneRun off1
rigAssert "worktime is over: idle 59 minutes, no input, no session, cache read: the duty is not told to go at once, and not yet" "$( rigTold off1 keeper-rig-06 )" "0"
rigAssert "idle for hours, but with input in its inbox: it stays" "$( rigTold off1 keeper-rig-08 )" "0"
rigAssert "idle for hours, but its member takes part in another live run: it stays" "$( rigTold off1 keeper-rig-09 )" "0"
rigAssert "out of the flags, the cache read nothing, idle 59 minutes: the 20 minutes decide, it is told to go" "$( rigTold off1 keeper-rig-10 )" "1"
rigAt $(( rigMon18 + 180 ))
rm -f "$rigData/inboxes/keeper-rig-08/incoming/note-20261019T0900Z-rig-work.md"
rigProcSignal TERM "$rigOtherPid" ; sleep 1
rigOneRun off2
rigAssert "two minutes on, idle for 62 minutes, no input, no session: told to go (the hour)" "$( rigTold off2 keeper-rig-06 )" "1"
rigAssert "the input worked off, idle for hours: told to go" "$( rigTold off2 keeper-rig-08 )" "1"
rigAssert "the other run ended, idle for hours: told to go" "$( rigTold off2 keeper-rig-09 )" "1"
rigAssert "...and nothing is told twice" "$( LC_ALL=C grep -l -F DISMISSED "$rigScn"/post.* 2> /dev/null | wc -l | tr -d ' ' )" "9"


if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ DUTY LIFETIME CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'DUTY_LIFETIME: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
