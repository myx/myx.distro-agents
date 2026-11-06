#!/usr/bin/env bash
## Behavioural check on the recent window of the active session list (S7.29, board task 20261106T1012Z;
## `recentlyEnded` and the active filter in AgentsManagerSessionRows.awk). A run that dies between two refreshes of the console is
## seen only if the list keeps the session it belonged to for a moment after it ended. The fault it guards: an ended session left the
## active list at once, so the console drew nothing and the death was invisible. Held, run rather than read:
##   1. A SESSION THAT ENDED WITHIN THE LAST MINUTE IS KEPT IN THE ACTIVE LIST, and reads `finished`.
##   2. ONE THAT ENDED LONGER AGO IS LEFT OUT of it.
##   3. THE BOUND IS THE VARIABLE'S: moved by MDAT_MANAGER_NOW_MINUTES, the same session leaves the list, so the row measures the
##      window and not a list that keeps everything.
##   4. THE FULL LIST CARRIES BOTH EITHER WAY, so what the active list leaves out is the filter's doing alone.
## The rows reader is the package's real one, over spawn records and stores this rig writes; the clock is the variable.
## RED RECIPE, measured on a copy under this check's own scratch on 2026-11-06: make `recentlyEnded` answer 0 always, and rows 1 and 3 fail.
## Offline: the reader and a rig of its own; no console, session or network is reached.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigInclude="$rigPackage/sh-lib/manager/AgentsTools.ManagerSession.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the manager session include is not at $rigInclude"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerSessionRecentCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
rigSpawned="$rigWs/.local/agents/spawned"
rigStores="$rigWs/.local/agents/sessions"
mkdir -p "$rigWs/.local/.agents" "$rigData/board/running" "$rigSpawned" "$rigStores" || exit 1
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
rigHost="$( hostname -s 2> /dev/null )" || rigHost="unknown"
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
## ONE ENDED SESSION, as the registry leaves it: a record that succeeded, and the date it closed. Both minute figures are the rig's own,
## so nothing depends on when this check runs.
rigEnded(){ ## session id, the minute it closed, counted from the rig's base
	local endId="$1" endMinute="$2"
	mkdir -p "$rigSpawned/$endId" "$rigStores/$endId" || exit 1
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\ntracking-name: %s\nhost: %s\nowner: keeper-myx\nstatus: spawn-succeeded\nstarted-at: 2026-11-06 10:00 +0000\nresolved-at: %s\n---\n' \
		"$endId" "$endId" "$endId" "$rigHost" "$( rigStamp "$endMinute" )" > "$rigSpawned/$endId/$endId.spawn.md"
}
## A date the registry reads back as the minute asked for: 2026-11-06, plus that many minutes.
rigStamp(){ printf '2026-11-06 %02d:%02d +0000' "$(( 10 + $1 / 60 ))" "$(( $1 % 60 ))" ; }
## The reader, in an environment of the rig's own, with the clock the check stands at: 2026-11-06 11:00 UTC, minutes since the epoch.
## Its second word is what narrows the list, and any non-empty word narrows it: the full list passes none.
## The rows function loads its awk readers through MDLT_ORIGIN, so the origin here is the package under test's own: a mutated copy
## checked against the live tree would read green whatever it held.
case "$rigPackage" in
	*/myx/myx.distro-agents) rigOrigin="${rigPackage%/myx/myx.distro-agents}" ;;
	*) rigRefuse "the package under test is not at <origin>/myx/myx.distro-agents: $rigPackage" ;;
esac
[ -d "$rigOrigin/myx/myx.distro-agents/sh-lib" ] || rigRefuse "no package tree under $rigOrigin"
rigBaseMinutes="$(( $( date -u -j -f '%Y-%m-%d %H:%M' '2026-11-06 11:00' '+%s' 2> /dev/null || date -u -d '2026-11-06 11:00' '+%s' ) / 60 ))"
[ -n "$rigBaseMinutes" ] || rigRefuse "this host's date cannot give the epoch of the rig's hour"
rigRows(){ ## the clock in minutes, then `active` or nothing
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_SPAWN_AGENT=magic-coordinator MDSC_CMD=DistroAgentsTools MDAT_MANAGER_NOW_MINUTES="$1" \
		bash -c '. "$1" --definitions-only > /dev/null 2>&1 ; shift ; AgentsToolsManagerSessionRows --manager-session-list "$@"' rig "$rigInclude" "${2:-}" 2>&1
}
## Whether one session's row stands in a list, by its id.
rigHas(){ ## the rows, the session id
	printf '%s\n' "$1" | LC_ALL=C awk -F'\t' -v want="$2" '$1 == "session" && $2 == want { print "listed" ; exit }'
}
rigStateOf(){ ## the rows, the session id
	printf '%s\n' "$1" | LC_ALL=C awk -F'\t' -v want="$2" '$1 == "session" && $2 == want { print $4 ; exit }'
}

echo "-- the rig: one session that ended one minute ago, one that ended ten minutes ago --"
rigEnded rig-just-now 59
rigEnded rig-long-ago 50
rigActiveRows="$( rigRows "$rigBaseMinutes" active )"
rigFullRows="$( rigRows "$rigBaseMinutes" )"

echo "-- 1. a session that ended within the last minute is kept, as finished --"
rigAssert "the session that ended a minute ago stands in the active list" "$( rigHas "$rigActiveRows" rig-just-now )" listed
rigAssert "and it reads finished there" "$( rigStateOf "$rigActiveRows" rig-just-now )" finished

echo "-- 2. one that ended longer ago is left out --"
rigAssert "the session that ended ten minutes ago does not" "$( rigHas "$rigActiveRows" rig-long-ago )" ''

echo "-- 3. the bound is the clock's, not a list that keeps everything --"
rigLaterRows="$( rigRows "$(( rigBaseMinutes + 5 ))" active )"
rigAssert "five minutes later, the same session leaves the active list" "$( rigHas "$rigLaterRows" rig-just-now )" ''

echo "-- 4. the full list carries both either way --"
rigAssert "both sessions stand in the full list at the first clock" "$( rigHas "$rigFullRows" rig-just-now ):$( rigHas "$rigFullRows" rig-long-ago )" 'listed:listed'
rigAssert "and both still stand in it at the later clock" "$( rigHas "$( rigRows "$(( rigBaseMinutes + 5 ))" )" rig-just-now )" listed

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER SESSION RECENT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'MANAGER_SESSION_RECENT: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
