#!/usr/bin/env bash
## Behavioural check on the important-and-emergency step of the schedule loop (T3 of the 20261021 refactorings epic; sh-lib/session/
## AgentsTools.DispatcherSchedule.include, AgentsToolsScheduleImportantEmergency, taken at each iteration of --intern-main-loop). The real loop
## (--one) and the real spawner run, as in AgentsScheduleLoopCheck; the console, curl, date and every setting are this rig's own. GUARD: every
## tooling call goes through one `env -i` whose child refuses to start unless MMDAPP and MDAT_DATA_ROOT sit under this rig's tree and PATH
## holds no agent CLI. Held:
##   1. OUT OF WORKTIME, an item of magic-coordinator's incoming whose frontmatter carries `mark: important` starts the advance routine,
##      the one-shot handling block, and not the work-duty.
##   2. An item whose frontmatter carries `mark: emergency` is confirmed with the owner (one post, once per item) and sets the emergency
##      flag, and the advance routine is started for it too.
##   3. A marked item that has been handled (moved out of incoming/) starts nothing again.
##   4. TWO EMERGENCY ITEMS IN ONE PASS ARE BOTH CONFIRMED, each under its own name; the control is one item in one pass.
##   5. AN EMERGENCY STILL PASSES `holding`: its confirmation and its advance start both happen under a hold, and the control
##      is a pass with no hold, where an important item still starts the advance.
## `RIG_PACKAGE` names the package the pass runs from, as AgentsScheduleHoldFloorCheck takes it. A package named inside a copy
## of the source root runs that copy whole, its fixtures and its includes with it.
## Offline, rig tree only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
## A STAGED ORIGIN: RIG_PACKAGE may name a package inside a copy of the source root, and then the copy's own origin is what
## every fixture, every include and the pass read, so a staged tree is what runs. With no RIG_PACKAGE the origin stands.
case "$rigPackage" in
	*/myx/myx.distro-agents) MDLT_ORIGIN="${rigPackage%/myx/myx.distro-agents}" ;;
esac
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" ] || rigRefuse "dispatcher not found"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsImportantEmergencyCheck )" || exit 1
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
rigScheduleSetup 2
## Monday 2026-10-19 in Etc/GMT-3: 13:00 (worktime), 18:00 (after it).
rigMon13=1792404000 ; rigMon18=1792422000
## The advance routine of the rig: a one-shot handling block, the same shape the work-duty routines of the rig take.
mkdir -p "$rigSkills/magic-team"
printf -- '---\ntype: routine\nexecutors: magic-team\nmaintainers: magic-coordinator\nrequires-session-kind: standalone\ninput-scan-def: none\nruns-at: none\n---\n# magic-team.advance.routine\n\n# Summary\n\nRig advance fixture: the one-shot handling block.\n\n# Steps\n\n1. **work**: work.\n\n# Closure steps\n\nNone.\n' > "$rigSkills/magic-team/magic-team.advance.routine.md"
rigEmergencySetting(){ ## -- the stored emergency override, `-` where none
	[ -f "$rigWs/.local/.agents/magic-team.agent.env" ] || { printf -- '-\n' ; return 0 ; }
	LC_ALL=C sed -n 's/^MDAT_SCHEDULE_EMERGENCY=//p' "$rigWs/.local/.agents/magic-team.agent.env"
	LC_ALL=C grep -q '^MDAT_SCHEDULE_EMERGENCY=' "$rigWs/.local/.agents/magic-team.agent.env" || printf -- '-\n'
}
rigConfirmPosts(){ ## -- how many posted bodies hold the emergency-confirmation words
	LC_ALL=C grep -l -F 'Confirm the emergency to set the emergency flag' "$rigScn"/post.* 2> /dev/null | wc -l | LC_ALL=C tr -d ' '
}
rigMarkedItem(){ ## file name, mark -- one inbox item of magic-coordinator, marked
	printf -- '---\ntype: note\nfrom: rig\nowner: magic-coordinator\nmark: %s\n---\n# Note: %s work\n\nwork\n' "$2" "$2" | rigStoreItem "$rigData" inbox magic-coordinator $1
}
rigConfirmPostsFor(){ ## item file name -- how many posted bodies name it as the confirmed item
	LC_ALL=C grep -l -F "incoming ($1). Confirm the emergency" "$rigScn"/post.* 2> /dev/null | wc -l | LC_ALL=C tr -d ' '
}
rigHoldSetting(){ ## -- the stored holding override, `-` where none
	[ -f "$rigWs/.local/.agents/magic-team.agent.env" ] || { printf -- '-\n' ; return 0 ; }
	LC_ALL=C sed -n 's/^MDAT_SCHEDULE_HOLDING=//p' "$rigWs/.local/.agents/magic-team.agent.env"
	LC_ALL=C grep -q '^MDAT_SCHEDULE_HOLDING=' "$rigWs/.local/.agents/magic-team.agent.env" || printf -- '-\n'
}
rigHeldSaid(){ ## name of a run -- how many lines of what it wrote say the pass is holding
	cat "$rigDir/$1.out" "$rigDir/$1.err" 2> /dev/null | LC_ALL=C grep -c -F 'holding: no new work is started' || :
}

echo "-- 1. out of worktime, an important item starts the advance one-shot --"
rigAt "$rigMon18"
rigMarkedItem note-20261019T1800Z-important.md important
rigOneRun imp1 ; rigWaitStarts
rigAssert "out of worktime, an important item starts the advance routine, and not the work-duty" "$( rigSaid imp1 'important-emergency: started the advance routine of magic-coordinator' ):$( rigRecordsOf magic-team.advance.routine.md ):$( rigDutyCount magic-coordinator )" "1:1:0"
rigAssert "nothing is posted for an important item: no confirmation to the owner, and no flag" "$( rigConfirmPosts ):$( rigEmergencySetting )" "0:-"

echo "-- 2. an emergency item is confirmed with the owner and sets the flag --"
rm -f "$rigData/inboxes/magic-coordinator/incoming/note-20261019T1800Z-important.md"
rigAt $(( rigMon18 + 601 ))
rigMarkedItem note-20261019T1810Z-emergency.md emergency
rigOneRun emg1 ; rigWaitStarts
rigAssert "the emergency is confirmed: one confirmation post to the owner, and the flag set" "$( rigConfirmPosts ):$( rigEmergencySetting )" "1:until $(( rigMon18 + 601 + 3600 ))"
rigAssert "the advance routine is started for it too" "$( rigSaid emg1 'important-emergency: started the advance routine of magic-coordinator' )" "1"

echo "-- 3. a handled marked item starts nothing again --"
rm -f "$rigData/inboxes/magic-coordinator/incoming/note-20261019T1810Z-emergency.md"
rigAt $(( rigMon18 + 1202 ))
rigOneRun after ; rigWaitStarts
rigAssert "with the marked item gone, nothing new is started or said" "$( rigSaid after 'important-emergency:' ):$( rigRecordsOf magic-team.advance.routine.md )" "0:2"
## THE EMERGENCY FLAG IS CLEARED before the two rows below, so what they see is the marked items alone.
rigDispatch --override-flag --no emergency
rigAssert "the emergency flag of row 2 is cleared, so the rows below see no emergency flag of their own" "$( rigEmergencySetting )" "-"

echo "-- 4. two emergency items in one pass are both confirmed --"
rigAt $(( rigMon18 + 1803 ))
rigMarkedItem note-20261019T1830Z-emergency-a.md emergency
rigMarkedItem note-20261019T1831Z-emergency-b.md emergency
rigOneRun emg2 ; rigWaitStarts
rigAssert "two emergency items in one pass are both confirmed, each under its own name" \
	"$( rigConfirmPostsFor note-20261019T1830Z-emergency-a.md ):$( rigConfirmPostsFor note-20261019T1831Z-emergency-b.md )" "1:1"
rm -f "$rigData/inboxes/magic-coordinator/incoming/note-20261019T1830Z-emergency-a.md" "$rigData/inboxes/magic-coordinator/incoming/note-20261019T1831Z-emergency-b.md"
rigAt $(( rigMon18 + 2404 ))
rigMarkedItem note-20261019T1840Z-emergency-one.md emergency
rigOneRun emg3 ; rigWaitStarts
rigAssert "control: one emergency item in a pass is confirmed once" \
	"$( rigConfirmPostsFor note-20261019T1840Z-emergency-one.md )" "1"

echo "-- 5. an emergency still passes holding --"
rm -f "$rigData/inboxes/magic-coordinator/incoming/note-20261019T1840Z-emergency-one.md"
rigDispatch --override-flag holding
rigAssert "the rig is holding, on its own flag route, before the pass below runs" "$( rigHoldSetting )" "on"
rigAt $(( rigMon18 + 3005 ))
rigMarkedItem note-20261019T1850Z-emergency-held.md emergency
rigOneRun held1 ; rigWaitStarts
rigAssert "under a hold the pass says it holds, and the emergency is still confirmed and its advance still started" \
	"$( rigHeldSaid held1 ):$( rigConfirmPostsFor note-20261019T1850Z-emergency-held.md ):$( rigSaid held1 'important-emergency: started the advance routine of magic-coordinator' )" "1:1:1"
rigDispatch --override-flag --no holding
rigAssert "the hold is cleared again, so the control is a pass with no hold at all" "$( rigHoldSetting )" "-"
rm -f "$rigData/inboxes/magic-coordinator/incoming/note-20261019T1850Z-emergency-held.md"
rigAt $(( rigMon18 + 3606 ))
rigMarkedItem note-20261019T1900Z-important-control.md important
rigOneRun free1 ; rigWaitStarts
rigAssert "control: with no hold an important item still starts the advance, and confirms nothing" \
	"$( rigSaid free1 'important-emergency: started the advance routine of magic-coordinator' ):$( rigConfirmPostsFor note-20261019T1900Z-important-control.md )" "1:0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ IMPORTANT EMERGENCY CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'IMPORTANT_EMERGENCY: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
