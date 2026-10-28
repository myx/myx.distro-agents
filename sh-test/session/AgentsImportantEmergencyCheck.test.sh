#!/usr/bin/env bash
## Behavioural check on the important-and-emergency step of the schedule loop (T3 of the 20261021 refactorings epic; sh-lib/session/
## AgentsTools.DispatcherLoop.include, AgentsToolsScheduleImportantEmergency, taken at each iteration of --intern-main-loop). The real loop
## (--one) and the real spawner run, as in AgentsScheduleLoopCheck; the console, curl, date and every setting are this rig's own. GUARD: every
## tooling call goes through one `env -i` whose child refuses to start unless MMDAPP and MDAT_DATA_ROOT sit under this rig's tree and PATH
## holds no agent CLI. Held:
##   1. OUT OF WORKTIME, an item of magic-coordinator's incoming whose frontmatter carries `mark: important` starts the advance routine,
##      the one-shot handling block, and not the work-duty.
##   2. An item whose frontmatter carries `mark: emergency` is confirmed with the owner (one post, once per item) and sets the emergency
##      flag, and the advance routine is started for it too.
##   3. A marked item that has been handled (moved out of incoming/) starts nothing again.
## Offline, rig tree only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
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
	printf -- '---\ntype: note\nfrom: rig\nowner: magic-coordinator\nmark: %s\n---\n# Note: %s work\n\nwork\n' "$2" "$2" > "$rigData/inboxes/magic-coordinator/incoming/$1"
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

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ IMPORTANT EMERGENCY CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'IMPORTANT_EMERGENCY: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
