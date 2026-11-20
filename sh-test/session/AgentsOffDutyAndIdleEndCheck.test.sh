#!/usr/bin/env bash
## Behavioural check on the two rules by which the schedule ends a run that should no longer stand (owner's ruling, 2026-11-20),
## in AgentsTools.DispatcherSchedule.include, run rather than read. Both rules are driven here with the dismissal stubbed, so what
## is measured is the decision and never a post:
##   1. AN OFF-DUTY RUN ENDS once the flags allow a work-duty (AgentsToolsScheduleOffDutyEnd): a record naming
##      `<member>.off-duty.routine.md` is told to go. THE CONTROL is the same record while the flags allow no work-duty: it stays,
##      and a rule that ended every duty would pass row 1 and fail that one.
##   2. THE OTHER CONTROL: a record naming `<member>.work-duty.routine.md` is left alone with the flags allowing a work-duty, so a
##      rule that read the flags alone and not the routine would pass row 1 and fail this.
##   3. A RUN THAT IS NO DUTY, idle with nothing pending on its own CheckList, is told to go (AgentsToolsScheduleIdleNoWorkEnd).
##      This is the reported session: it sat with its list reading done and nothing ended it.
##   4. AND THE CONTROL FOR IT: the same run with one item still pending stays, and a duty with the same empty list is left to its
##      own lifetime rules. A rule that read only the list would pass row 3 and fail both.
##   5. AN OPEN ASK OF ITS OWN IS WORK: the same run with an unanswered question of its own and an empty list stays, and with that
##      question gone it is told to go again.
## Offline: the dismissal is a counter, the CheckList is a real file placed by the session store's own locator, and no tool is called.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigInclude="$rigPackage/sh-lib/schedule/AgentsTools.DispatcherSchedule.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the schedule include is not in this tree: sh-lib/schedule/AgentsTools.DispatcherSchedule.include"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsOffDutyAndIdleEndCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/agents/spawned" "$rigWs/.local/agents/sessions" "$rigTmp/home" "$rigData"
export MDAT_STARTED_RECORDS_SECONDS=0 MDAT_DUTY_RECORDS_SECONDS=0 MDAT_ROUTINE_RECORDS_SECONDS=0

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}

## THE DECISION, ASKED OF THE REAL FUNCTIONS. The dismissal is a counter: the rule is what is measured, never the post. Every
## other helper the two rules call is the package's own, so a rule that reached a different reader would show here.
rigAsk(){ ## rule, record, allowed -- SET or STAYS, from the rule's own rc, and the reason the dismissal carried
	env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_WORKSPACE_MODE=team-rig MDSC_CMD=check bash -c '
			set +e
			. "$1" > /dev/null 2>&1
			## The dismissal is the rig’s own: it records the reason and ends the ask.
			AgentsToolsScheduleDismiss(){ printf "DISMISSED %s\n" "$2" >> "$RIG_SAID" ; return 0 ; }
			: > "$RIG_SAID"
			case "$2" in
				off-duty) AgentsToolsScheduleOffDutyEnd "$3" "$4" ; printf "%s %s\n" "$?" "$( cat "$RIG_SAID" )" ;;
				idle) AgentsToolsScheduleIdleNoWorkEnd "$3" ; printf "%s %s\n" "$?" "$( cat "$RIG_SAID" )" ;;
			esac
		' rig "$rigInclude" "$1" "$2" "$3" 2> /dev/null
}

rigRecord(){ ## run, routine -- the run's own record, placed where the session store keeps it
	mkdir -p "$rigWs/.local/agents/spawned/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nowner: member-rig-idle\nroutine: %s\nstatus: spawn-started\nsession-thread: CRIG00001:1760000000.000001\n---\n\n# Spawn session\n' \
		"$1" "$1" "$2" > "$rigWs/.local/agents/spawned/$1/$1.spawn.md"
	printf '%s\n' "$rigWs/.local/agents/spawned/$1/$1.spawn.md"
}
rigList(){ ## run, item lines... -- the run's own CheckList, placed by the session store's own locator
	local listFile=""
	env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_WORKSPACE_MODE=team-rig bash -c '
			set +e
			. "$1" > /dev/null 2>&1
			AgentsSessionChecklistFileInto listFile "$2" member-rig-idle && printf "%s\n" "$listFile"
		' rig "$rigPackage/sh-lib/session/AgentsTools.CheckListSeed.include" "$1" 2> /dev/null
}
export RIG_SAID="$rigTmp/said"

echo "-- 1. an off-duty run ends once the flags allow a work-duty --"
rigOff="$( rigRecord rig-run-off magic-coordinator.off-duty.routine.md )"
rigWork="$( rigRecord rig-run-work magic-coordinator.work-duty.routine.md )"
rigAssert "off-duty, the flags allow a work-duty: told to go" \
	"$( rigAsk off-duty "$rigOff" yes | LC_ALL=C cut -d' ' -f1 )" "0"
rigAssert "and the reason says why" \
	"$( rigAsk off-duty "$rigOff" yes | LC_ALL=C grep -c -F 'the flags allow a work-duty now' )" "1"

echo "-- 2. the two controls --"
rigAssert "CONTROL: off-duty, the flags allow no work-duty: it stays" \
	"$( rigAsk off-duty "$rigOff" no | LC_ALL=C cut -d' ' -f1 )" "1"
rigAssert "CONTROL: a work-duty, the flags allow a work-duty: it stays" \
	"$( rigAsk off-duty "$rigWork" yes | LC_ALL=C cut -d' ' -f1 )" "1"

echo "-- 3. a run that is no duty, idle with nothing pending, ends --"
rigIdle="$( rigRecord rig-run-idle magic-team.coworking.routine.md )"
rigIdleList="$( rigList rig-run-idle )"
[ -n "$rigIdleList" ] || rigRefuse "the session store placed no CheckList for the idle run, so nothing below would be measured"
printf -- '- [x] the work it was given\n- [x] the report it gave\n' > "$rigIdleList"
rigAssert "its list holds nothing pending: told to go" \
	"$( rigAsk idle "$rigIdle" | LC_ALL=C cut -d' ' -f1 )" "0"
rigAssert "and the reason names the empty list" \
	"$( rigAsk idle "$rigIdle" | LC_ALL=C grep -c -F 'its list holds nothing pending' )" "1"

echo "-- 4. the controls for it --"
printf -- '- [x] the work it was given\n- [ ] the question it still owes\n' > "$rigIdleList"
rigAssert "CONTROL: one item still pending: it stays" \
	"$( rigAsk idle "$rigIdle" | LC_ALL=C cut -d' ' -f1 )" "1"
printf -- '- [x] the work it was given\n' > "$rigIdleList"
rigAssert "CONTROL: a duty with the same empty list is left to its own rules" \
	"$( rigAsk idle "$rigWork" | LC_ALL=C cut -d' ' -f1 )" "1"

echo "-- 5. an open ask of its own is work --"
mkdir -p "$rigWs/.local/agents/pending"
printf -- '---\ntype: ask\nsession-id: rig-run-idle\n---\n\n# Question\n' > "$rigWs/.local/agents/pending/ask-20261120T000000Z-rig.md"
rigAssert "the same run with an open ask of its own, its list empty: it stays, its question ends that wait" \
	"$( rigAsk idle "$rigIdle" | LC_ALL=C cut -d' ' -f1 )" "1"
rm -f "$rigWs/.local/agents/pending/ask-20261120T000000Z-rig.md"
rigAssert "and with the ask answered and the list still empty: it is told to go again" \
	"$( rigAsk idle "$rigIdle" | LC_ALL=C cut -d' ' -f1 )" "0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ OFF-DUTY AND IDLE END CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'OFF_DUTY_AND_IDLE_END: OK (%d assertions, offline)\n' "$rigPassCount"
