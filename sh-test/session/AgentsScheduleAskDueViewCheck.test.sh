#!/usr/bin/env bash
## Behavioural check on the ask a VIEW of the sessions makes of the schedule thread: a list of the sessions starts a dead
## thread whether or not the flags want duties, keeps its own once-a-minute stamp, and a second call inside the minute starts
## nothing. Before this behaviour the only ask was the reader's, which stays silent when no flag wants duties.
##
## Held, and not read:
##   1. A call that is no view, with no flag wanting duties, starts nothing. The thread stays dead.
##   2. The same rig, the same dead thread, the same instant: a call with `view` starts one. Nothing but that word differs.
##   3. A second `view` call inside the minute starts no second thread.
##   4. The view's stamp is its own file: a view call leaves the reader's stamp untouched.
## Red recipe: with the view bypass removed from AgentsToolsScheduleThreadAskDue, so that a view call goes on to ask
## whether duties are wanted, section 1 passes and sections 2 and 3 fail. Section 4 fails with the stamp line removed.
## Offline: a rig folder of its own, a clock of its own, no workspace read, no agent CLI on PATH.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-lib/schedule/AgentsTools.ScheduleThread.include" ] || rigRefuse "the schedule thread's include is not in the package"
[ -f "$rigPackage/sh-lib/common/AgentsTools.OnDemandThread.include" ] || rigRefuse "the on-demand thread's include is not in the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsScheduleAskDueViewCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp" 2> /dev/null || :' EXIT

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

## THE RIG. A workspace whose flags want no duties: no flag file at all, and a clock 2026-11-24 02:00 UTC, a Tuesday, four
## hours before a 09:00 worktime start and far outside it. Every workspace setting the ask reads is this rig's own.
rigWs="$rigTmp/ws" rigHome="$rigTmp/home" rigData="$rigTmp/data" rigBin="$rigTmp/bin"
mkdir -p "$rigWs/.local/agents/schedule-thread" "$rigWs/.local/temp" "$rigWs/.local/.agents" "$rigHome" "$rigData" "$rigBin" "$rigTmp/skills"
printf 'MDAT_SCHEDULE_TIMEZONE=UTC\nMDAT_SCHEDULE_WEEKEND=sat,sun\nMDAT_SCHEDULE_WORKTIME=09:00 18:00 workdays\n' > "$rigWs/.local/.agents/magic-team.agent.env"
## The clock: +%s answers the fixed instant, every other call goes to the real date.
rigRealDate="$( command -v date )" || rigRefuse "no date on PATH"
cat > "$rigBin/date" <<RIGDATE
#!/bin/sh
case "\$*" in
	+%s) printf '%s\n' "\$( cat "$rigTmp/now.epoch" )" ; exit 0 ;;
esac
exec "$rigRealDate" "\$@"
RIGDATE
chmod +x "$rigBin/date"
printf '1795492800\n' > "$rigTmp/now.epoch"

## THE ASK IS COUNTED, NOT MADE. The stand-in is defined after the include is sourced, as the arms source it lazily.
rigCall(){ ## a word or nothing -- the ask count the call left, and the two stamps as they stand after it
	: > "$rigTmp/asks"
	env -i HOME="$rigHome" PATH="$rigBin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		MDAT_WORKSPACE_MODE=team-rig RIG_ASKS="$rigTmp/asks" \
		bash -c '
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/schedule/AgentsTools.ScheduleThread.include" || exit 90
			AgentsToolsScheduleThreadAsk(){ printf "ask\n" >> "$RIG_ASKS" ; return 0 ; }
			AgentsToolsScheduleThreadAskDue "$@"
		' rig "$@" > /dev/null 2>&1
	printf '%s' "$( LC_ALL=C grep -c '^ask$' "$rigTmp/asks" 2> /dev/null | LC_ALL=C head -1 )"
}
rigStamps(){ ## -- the two stamp files, as 1 or 0 each, reader's first
	printf '%s:%s' \
		"$( [ -s "$rigWs/.local/agents/schedule-thread/ask-due.stamp" ] && printf 1 || printf 0 )" \
		"$( [ -s "$rigWs/.local/agents/schedule-thread/ask-view.stamp" ] && printf 1 || printf 0 )"
}

echo "-- 1. no view, no flag wanting duties: nothing is started --"
rigAsks="$( rigCall )"
rigAssert "a call that is no view starts no thread while no flag wants duties" "$rigAsks" 0

echo "-- 2. the same rig, the same instant, the same dead thread: a view starts one --"
rm -f "$rigWs/.local/agents/schedule-thread"/ask-*.stamp
rigAsks="$( rigCall view )"
rigAssert "a view call starts a thread while no flag wants duties" "$rigAsks" 1

echo "-- 3. a second view call inside the minute starts no second thread --"
rigAsks="$( rigCall view )"
rigAssert "a second view call inside the minute starts no second thread" "$rigAsks" 0

echo "-- 4. the view keeps a stamp of its own --"
## Both stamps cleared, then one view call: the view's stamp exists, and the reader's does not.
rm -f "$rigWs/.local/agents/schedule-thread"/ask-*.stamp
rigCall view > /dev/null
rigAssert "a view call leaves the view's own stamp and not the reader's" "$( rigStamps )" "0:1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SCHEDULE ASK-DUE VIEW CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SCHEDULE_ASK_DUE_VIEW: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
