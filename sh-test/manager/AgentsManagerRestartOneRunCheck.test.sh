#!/usr/bin/env bash
## Behavioural check on the restart's one-live-run guard (sh-lib/manager/AgentsTools.OpManagerSessionRestart.include): a restart
## over a session that already has another live run refuses and names it, because a second worker on one session writes the same
## context. Held, run rather than read:
##   1. A LIVE PEER REFUSES THE RESTART: the row says live, names the peer, and no new record is written.
##   2. THE CONTROL: with the peer's process gone, the guard passes and the restart goes on to the item lookup.
## Measured 2026-11-25: six live harnesses on session 00569208, one per restart.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
[ -f "$rigTool" ] || { echo "⛔ ERROR: no $rigTool" >&2 ; exit 1 ; }
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerRestartOneRunCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSid="rg-session"
rigSpawn="$rigWs/.local/agents/spawned"
mkdir -p "$rigSpawn/$rigSid" "$rigWs/.local/agents/sessions/$rigSid" || exit 1
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
rigRecord(){ ## id, session, status, pid (may be empty)
	local recPid="$4" recBegin=""
	[ -z "$recPid" ] || recBegin="$( ps -o lstart= -p "$recPid" 2> /dev/null | LC_ALL=C awk '{ $1 = $1 ; print }' | LC_ALL=C tr ' ' '_' )"
	printf -- '---\nspawn-id: %s\nsession-id: %s\nowner: rig-member\nstatus: %s\nrun-process: %s\n---\n' \
		"$1" "$2" "$3" "${recPid:+$recPid $recBegin}" > "$rigSpawn/$2/$1.spawn.md"
}
rigRestart(){ ## -- one manager restart call in the rig
	MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigWs/.local/agents/team-data-root" \
		bash "$rigTool" --manager-session-restart --session-id "$rigSid" 2> /dev/null
}
rigRecord "$rigSid" "$rigSid" spawn-failed ""
sleep 60 & rigPeer=$!
rigRecord "rg-peer" "$rigSid" spawn-started "$rigPeer"
echo "-- 1. a live peer refuses the restart --"
rigBefore="$( ls "$rigSpawn/$rigSid" 2> /dev/null | wc -l | tr -d ' ' )"
rigOut="$( rigRestart )"
rigAssert "the row says live and names the peer" "$( printf '%s\n' "$rigOut" | LC_ALL=C awk -F'\t' '$1 == "restart" && $5 == "live" && index( $6, "rg-peer" ) > 0 { n++ } END { print n + 0 }' )" "1"
rigAssert "and no new record is written" "$( ls "$rigSpawn/$rigSid" 2> /dev/null | wc -l | tr -d ' ' )" "$rigBefore"
kill -TERM "$rigPeer" 2> /dev/null || :
wait "$rigPeer" 2> /dev/null || :
echo "-- 3. the control: peer gone, the guard passes --"
sleep 60 & rigPeer=$!
rigRecord "rg-peer" "$rigSid" spawn-started "$rigPeer"
kill -TERM "$rigPeer" 2> /dev/null || :
wait "$rigPeer" 2> /dev/null || :
rigAssert "with the peer gone the restart reaches the item lookup" "$( rigRestart | LC_ALL=C awk -F'\t' '$5 == "no-item" { n++ } END { print n + 0 }' )" "1"
if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ MANAGER RESTART ONE RUN CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'MANAGER_RESTART_ONE_RUN: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
