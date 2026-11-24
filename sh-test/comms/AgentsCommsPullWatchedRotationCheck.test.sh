#!/usr/bin/env bash
## AgentsCommsPullWatchedRotationCheck -- the rig's pull serves every channel of interest over the passes, whatever its bound
## (AgentsToolsCommsCachePullWatched, sh-lib/comms/AgentsTools.CommsCache.include). The bound of a pass is a count of channels pulled: a walk
## that starts at the first mark on every pass spends the bound on the first busy channels, and a direct conversation late in the order is never
## pulled, so a message of the owner sits unread. The walk goes on from the mark after the last one served, kept in `.pull-cursor`.
##   1. six marks and a bound of two: over three passes every channel is pulled
##   2. each pass pulls two channels, none twice in a pass, so the bound still holds
##   3. with no bound (0) every channel is pulled in one pass: the control that the rotation touches nothing else
##   4. a pull that failed is marked, and not tried again within the hour while the others are pulled as before
##   5. a failure past its hour is tried again
## Red before the fix: the three passes pull the same two channels.
## Offline: the ingest sweep, the state read and the pull itself are stand-ins that note the channel, so no service is asked, and the rig workspace is the check's own.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
[ -f "$rigPackage/sh-lib/comms/AgentsTools.CommsCache.include" ] || { echo "⛔ ERROR: the comms cache include is not at the origin -- refusing to report a result" >&2 ; exit 1 ; }
mkdir -p "$MMDAPP/.local/agents/scratch/sh-test" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/agents/scratch/sh-test/AgentsCommsPullWatchedRotationCheck.XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
export MMDAPP="$rigTmp/ws"
rigNow="$( date +%s )"
mkdir -p "$MMDAPP/.local/cache/comms/.interest" || exit 1
for rigAt in 01 02 03 04 05 06 ; do
	mkdir -p "$MMDAPP/.local/cache/comms/slack/slack-C0RIG$rigAt"
	printf '%s 15\n' "$rigNow" > "$MMDAPP/.local/cache/comms/.interest/slack-C0RIG$rigAt"
done
rigLog="$rigTmp/pulled.log"
set +u
. "$rigPackage/sh-lib/comms/AgentsTools.CommsCache.include" || { echo "⛔ ERROR: the comms cache include did not load -- refusing to report a result" >&2 ; exit 1 ; }
set -u
type AgentsToolsCommsCachePullWatched > /dev/null 2>&1 || { echo "⛔ ERROR: AgentsToolsCommsCachePullWatched is not defined by the include -- refusing to report a result" >&2 ; exit 1 ; }
## THE STAND-INS: the ingest sweep does nothing, a folder reads as pulled never and due at once, the pull notes its channel, and the ready word is no word.
AgentsCommsSweepPass(){ return 0 ; }
AgentsToolsCommsCacheState(){ ## cache folder
	agentsCommsCacheAt=0 agentsCommsCacheFrom="1.000000" agentsCommsCacheNewest="1.000000"
	agentsCommsCacheRecipe="slack-conversation ${1##*-} magic-rig false"
	return 0
}
AgentsToolsCommsCacheSayReady(){ return 0 ; }
rigFailTarget=""
DistroAgentsTools(){ printf '%s\n' "$3" >> "$rigLog" ; [ -z "$rigFailTarget" ] || [ "$3" != "$rigFailTarget" ] ; }
rigPass1(){ ## bound
	: > "$rigLog"
	AgentsToolsCommsCachePullWatched "$rigNow" "$1" > /dev/null 2>&1
	LC_ALL=C sort "$rigLog" | tr '\n' ' '
}
rm -f "$MMDAPP/.local/cache/comms/.pull-cursor"
rigServed=""
for rigRound in 1 2 3 ; do
	rigGot="$( rigPass1 2 )"
	rigAssert "pass $rigRound serves two channels, none twice" "$( printf '%s' "$rigGot" | wc -w | tr -d ' ' ):$( printf '%s' "$rigGot" | tr ' ' '\n' | LC_ALL=C sort -u | wc -l | tr -d ' ' )" "2:2"
	rigServed="$rigServed$rigGot"
done
rigAssert "over three passes every one of the six channels is pulled" "$( printf '%s' "$rigServed" | tr ' ' '\n' | LC_ALL=C sort -u | grep -c . )" 6
rm -f "$MMDAPP/.local/cache/comms/.pull-cursor"
rigAssert "with no bound every channel is pulled in one pass" "$( rigPass1 0 | wc -w | tr -d ' ' )" 6
rm -f "$MMDAPP/.local/cache/comms/.pull-cursor"
rigFailTarget=C0RIG01
rigPass1 0 > /dev/null
rigAssert "a pull that failed leaves its mark in the folder" "$( [ -f "$MMDAPP/.local/cache/comms/slack/slack-C0RIG01/.pull.failed" ] && printf marked || printf none )" marked
rigAssert "the next pass pulls the five others and not the one that failed" "$( rigPass1 0 )" "C0RIG02 C0RIG03 C0RIG04 C0RIG05 C0RIG06 "
touch -t 202001010000 "$MMDAPP/.local/cache/comms/slack/slack-C0RIG01/.pull.failed"
rigAssert "a failure past its hour is tried again" "$( rigPass1 0 | wc -w | tr -d ' ' )" 6
if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ COMMS PULL WATCHED ROTATION CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	echo "  fix:  AgentsToolsCommsCachePullWatched in sh-lib/comms/AgentsTools.CommsCache.include -- never the assertion" >&2
	exit 1
fi
printf 'COMMS_PULL_WATCHED_ROTATION: OK (%d assertions, offline)\n' "$rigPass"
