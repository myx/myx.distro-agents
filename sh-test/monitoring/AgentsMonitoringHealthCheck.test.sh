#!/usr/bin/env bash
## AgentsMonitoringHealthCheck -- the health reading of a workspace (AgentsToolsMonitoringHealth, AgentsTools.Monitoring.include;
## epic S14): one line per asset, an alarm for a dead daemon or an outbox backlog, muted while planned maintenance holds.
## Guards: a workspace with no daemons reads none for both locks and no alarm; a lock whose holder is gone reads dead and raises an
## alarm; an outbox over the bound raises an alarm with its count; with the planned-maintenance flag set the same alarms print as
## muted with the seconds left, never dropped; the flags, machine, runs, Slack token and team-data lines are present; a path with no
## .local is refused.
## Red: a reading that drops an alarm under maintenance fails `muted, not dropped`.
## Offline: a temp workspace of this check alone, removed at its end; nothing is requested.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigTmp="$( mktemp -d "${MMDAPP:-${TMPDIR:-/tmp}}/.local/agents/scratch/sh-test/AgentsMonitoringHealthCheck.XXXXXXXX" 2> /dev/null || mktemp -d "${TMPDIR:-/tmp}/AgentsMonitoringHealthCheck.XXXXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents/schedule-thread" "$rigWs/.local/agents/comms" "$rigWs/.local/cache/comms/slack/slack-C1/" || exit 1
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigRead(){ ## -- the reading of the rig workspace
	( MDLT_ORIGIN="$MDLT_ORIGIN" MMDAPP="$rigWs" MDAT_MONITORING_OUTBOX_ALARM=2 ; export MDLT_ORIGIN MMDAPP MDAT_MONITORING_OUTBOX_ALARM ; . "$rigLib/monitoring/AgentsTools.Monitoring.include" ; AgentsToolsMonitoringHealth "$rigWs" ) 2> /dev/null
}
rigField(){ ## reading, asset -- the state column of its health line
	printf '%s\n' "$1" | LC_ALL=C awk -F'\t' -v a="$2" '$1 == "health" && $3 == a { print $4 ; exit }'
}

echo "-- 1. a quiet workspace: no daemons, no alarm, every asset line --"
rigOut="$( rigRead )"
rigAssert "schedule thread none"                       "$( rigField "$rigOut" schedule-thread )" none
rigAssert "comms reader none"                          "$( rigField "$rigOut" comms-reader )" none
rigAssert "no alarm line"                              "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^alarm' )" 0
rigAssert "the asset lines are all there"              "$( printf '%s\n' "$rigOut" | LC_ALL=C awk -F'\t' '$1 == "health" { print $3 }' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "comms-outbox comms-reader control-threads holding machine-disk machine-load planned-maintenance runs-started schedule-thread slack-bot-token team-data tool-pace workspace-mode "
rigAssert "planned maintenance reads no"               "$( rigField "$rigOut" planned-maintenance )" no
rigAssert "the Slack token reads absent, never printed" "$( rigField "$rigOut" slack-bot-token )" absent

echo "-- 2. a dead daemon and an outbox over the bound raise alarms --"
printf '999999999 0\n' > "$rigWs/.local/agents/schedule-thread/thread.lock"
printf 'a\nb\nc\n' > "$rigWs/.local/cache/comms/slack/slack-C1/outbox.messages.txt"
rigOut="$( rigRead )"
rigAssert "the schedule thread reads dead"             "$( rigField "$rigOut" schedule-thread )" dead
rigAssert "the outbox counts three"                    "$( rigField "$rigOut" comms-outbox )" 3
rigAssert "two alarms, naming both"                    "$( printf '%s\n' "$rigOut" | LC_ALL=C awk -F'\t' '$1 == "alarm" { print $3 }' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "comms-outbox schedule-thread "

echo "-- 3. planned maintenance mutes the alarms and says so --"
printf 'MDAT_SCHEDULE_PLANNED_MAINTENANCE=until %s\n' "$(( $( date +%s ) + 3600 ))" > "$rigWs/.local/.agents/magic-team.agent.env"
rigOut="$( rigRead )"
rigAssert "the flag reads yes"                         "$( rigField "$rigOut" planned-maintenance )" yes
rigAssert "muted, not dropped"                         "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^muted' ):$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^alarm' )" "2:0"
rigAssert "a muted line names the maintenance"         "$( printf '%s\n' "$rigOut" | LC_ALL=C awk -F'\t' '$1 == "muted" { print $4 ; exit }' | LC_ALL=C cut -d' ' -f1 )" planned-maintenance

echo "-- 4. no workspace, no reading --"
rigAssert "a path with no .local is refused"           "$( ( MDLT_ORIGIN="$MDLT_ORIGIN" ; export MDLT_ORIGIN ; . "$rigLib/monitoring/AgentsTools.Monitoring.include" ; AgentsToolsMonitoringHealth "$rigTmp/nowhere" 2> /dev/null && printf read || printf refused ) )" refused

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ MONITORING HEALTH CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	echo "  warn: the health reading hides a dead daemon or a backlog, or drops an alarm under maintenance" >&2
	echo "  fix:  AgentsToolsMonitoringHealth in sh-lib/monitoring/AgentsTools.Monitoring.include" >&2
	exit 1
fi
echo "MONITORING_HEALTH: OK ($rigPass assertions, offline)"
