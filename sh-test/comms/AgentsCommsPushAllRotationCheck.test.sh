#!/usr/bin/env bash
## AgentsCommsPushAllRotationCheck -- the pass that pushes every channel's outbox serves every folder over the passes, whatever its
## bound (AgentsToolsCommsCachePushAll, sh-lib/comms/AgentsTools.CommsCache.include). The bound of a pass is a count of posts: with
## more folders than the bound, a walk that starts at the first folder on every pass spends the bound on the same few folders, and the
## others never post. The walk goes on from the folder after the last one served, kept beside the comms pause file.
##   1. fourteen folders and a bound of four: over four passes every folder is served
##   2. each pass serves four folders, none twice in a pass, so the bound still holds
##   3. a folder with nothing to send is passed over and costs no place of the pass
##   4. with no bound (0) every folder is served in one pass: the control that the rotation touches nothing else
##   5. nothing is lost by the order: the stand-in sends nothing, so every folder still holds its queued message after the passes
## Red before the fix: the four passes serve the same four folders. Offline: the push of one folder is a stand-in that notes the
## folder and says it posted one message, so no service is asked, and the rig workspace is the check's own.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
[ -f "$rigPackage/sh-lib/comms/AgentsTools.CommsCache.include" ] || { echo "⛔ ERROR: the comms cache include is not at the origin -- refusing to report a result" >&2 ; exit 1 ; }
mkdir -p "$MMDAPP/.local/agents/scratch/sh-test" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/agents/scratch/sh-test/AgentsCommsPushAllRotationCheck.XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
export MMDAPP="$rigTmp/ws"
export MDAT_WORKSPACE_MODE=team-rig
mkdir -p "$MMDAPP/.local/agents/comms" || exit 1
## FOURTEEN FOLDERS, each with one queued message.
for rigAt in 01 02 03 04 05 06 07 08 09 10 11 12 13 14 ; do
	mkdir -p "$MMDAPP/.local/cache/comms/slack/slack-C0RIG$rigAt"
	printf 'queued\n' > "$MMDAPP/.local/cache/comms/slack/slack-C0RIG$rigAt/outbox.messages.txt"
done

rigLog="$rigTmp/served.log"
. "$rigPackage/sh-lib/comms/AgentsTools.CommsCache.include" || { echo "⛔ ERROR: the comms cache include did not load -- refusing to report a result" >&2 ; exit 1 ; }
## THE PUSH OF ONE FOLDER is a stand-in: it notes the folder, and says it posted one message while the bound lasts.
AgentsToolsCommsCachePush(){ ## folder, now, bound
	printf '%s\n' "${1##*/}" >> "$rigLog"
	agentsCommsCachePushMade=1
	return 0
}
rigPassOnce(){ ## the bound -- one pass, its served folders in $rigLog after a marker line
	printf '%s\n' "--" >> "$rigLog"
	AgentsToolsCommsCachePushAll 1700001000 "$1"
}

echo "-- 1. fourteen folders, a bound of four, four passes --"
: > "$rigLog"
for rigRun in 1 2 3 4 ; do rigPassOnce 4 ; done
rigAssert "every one of the fourteen folders was served" "$( LC_ALL=C grep -v -x -- '--' "$rigLog" | LC_ALL=C sort -u | LC_ALL=C grep -c . )" 14
rigAssert "nothing is lost: every folder still holds its one queued message" \
	"$( LC_ALL=C cat "$MMDAPP/.local/cache/comms/slack"/slack-C0RIG*/outbox.messages.txt | LC_ALL=C grep -c -x queued )" 14
echo "-- 2. the bound of a pass holds --"
rigAssert "each pass served four folders" "$( LC_ALL=C awk '$0 == "--" { if (n > 0) print n ; n = 0 ; next ; } { n++ ; } END { print n ; }' "$rigLog" | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' ' )" "4 "

echo "-- 3. a folder with nothing to send --"
: > "$rigLog"
rm -f "$MMDAPP/.local/cache/comms/slack/slack-C0RIG05/outbox.messages.txt"
for rigRun in 1 2 3 4 ; do rigPassOnce 4 ; done
rigAssert "the folder with no outbox is never asked" "$( LC_ALL=C grep -c -x -- 'slack-C0RIG05' "$rigLog" )" 0
rigAssert "the other thirteen are all served" "$( LC_ALL=C grep -v -x -- '--' "$rigLog" | LC_ALL=C sort -u | LC_ALL=C grep -c . )" 13

echo "-- 4. no bound --"
: > "$rigLog"
rigPassOnce 0
rigAssert "control: with no bound one pass serves every folder that has a post" "$( LC_ALL=C grep -v -x -- '--' "$rigLog" | LC_ALL=C sort -u | LC_ALL=C grep -c . )" 13

printf 'COMMS_PUSH_ALL_ROTATION: %s (%d assertions, offline, rig tree only)\n' "$( [ "$rigFail" = 0 ] && echo OK || echo FAIL )" "$(( rigPass + rigFail ))"
[ "$rigFail" = 0 ] || exit 1
