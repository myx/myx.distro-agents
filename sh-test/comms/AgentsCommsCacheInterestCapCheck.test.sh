#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on the interest mark's rewrite cap (sketch "Comms/Cache/Wait summary": "Interest marks touched at
## most once an hour"). The mark is `.local/cache/comms/.interest/<service>-<id>`, holding `<epoch> <ttl>`: the read that
## marked it, and the TTL that read asks of the channel. Held:
##   1. a mark inside the hour is left alone by a read at the same TTL -- both its epoch inside and its write time
##   2. the control the row above needs: a mark past the hour IS rewritten, and carries the reading call's own moment
##   3. a mark inside the hour is rewritten at once for a reader that needs a SHORTER TTL, and that reader's TTL lands
##   4. a reader asking the same or a longer TTL inside the hour does not rewrite it
##   5. a mark past the hour is rewritten even where the reader's TTL is the longer one
##   6. the puller's own pass keeps no mark at all, so a channel of interest is one a reader marked
## Offline: one mktemp tree, no network, nothing of the team's read.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigInclude="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.CommsCache.include"
[ -f "$rigInclude" ] || { echo "⛔ ERROR: the comms cache is not at the origin this workspace resolves: $rigInclude" >&2 ; exit 1 ; }

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsCommsCacheInterestCapCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigMarks="$rigWs/.local/cache/comms/.interest"
rigEntry="$rigWs/.local/cache/comms/slack/slack-CRIGCAP-1793000000.000001"
mkdir -p "$rigMarks" "$rigEntry" || exit 1
rigNow=1793003600

## One mark as a read writes it: its epoch as the read's own moment, and the TTL it reads the channel at. Its write time
## is put back by the same age, so the file's own time and the epoch inside agree, as they do after a real read.
rigMark(){ ## epoch, ttl
	printf '%s %s\n' "$1" "$2" > "$rigMarks/slack-CRIGCAP-1793000000.000001"
}
## One read's marking of the channel, in a shell of its own so the once-an-hour memory of a previous read stands no more
## than it would in a fresh call.
rigInterest(){ ## clock, the reader's ttl
	( MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "$1" ; AgentsToolsCommsCacheInterest "$2" "$3" "$4"' \
		_ "$rigInclude" "$rigEntry" "$1" "$2" ) > /dev/null 2>&1 || :
}
rigMarkEpoch(){ LC_ALL=C awk '{ print $1 ; }' "$rigMarks/slack-CRIGCAP-1793000000.000001" 2> /dev/null ; }
rigMarkTtl(){ LC_ALL=C awk '{ print $2 ; }' "$rigMarks/slack-CRIGCAP-1793000000.000001" 2> /dev/null ; }

echo "-- 1. inside the hour, a read at the same TTL leaves the mark as it stands --"
rigMark "$(( rigNow - 300 ))" 15
rigInterest "$rigNow" 15
rigAssert "the mark still holds the read that made it, not this one" "$( rigMarkEpoch )" "$(( rigNow - 300 ))"
rigAssert "and the TTL the channel is read at" "$( rigMarkTtl )" 15

echo "-- 2. past the hour, the same read rewrites it, with its own moment --"
rigMark "$(( rigNow - 3660 ))" 15
rigInterest "$rigNow" 15
rigAssert "the mark carries the moment of the read that rewrote it" "$( rigMarkEpoch )" "$rigNow"
rigAssert "and the TTL of that read" "$( rigMarkTtl )" 15

echo "-- 3. inside the hour, a reader needing a shorter TTL is served at once --"
rigMark "$(( rigNow - 300 ))" 60
rigInterest "$rigNow" 5
rigAssert "the mark now carries the shorter TTL, so the puller reads it that often" "$( rigMarkTtl )" 5
rigAssert "and the moment of the read that asked for it" "$( rigMarkEpoch )" "$rigNow"

echo "-- 4. inside the hour, the same or a longer TTL does not rewrite it --"
rigMark "$(( rigNow - 300 ))" 5
rigInterest "$rigNow" 5
rigAssert "an equal TTL leaves the mark's moment alone" "$( rigMarkEpoch )" "$(( rigNow - 300 ))"
rigMark "$(( rigNow - 300 ))" 5
rigInterest "$rigNow" 60
rigAssert "a longer TTL leaves it alone too" "$( rigMarkTtl )" 5

echo "-- 5. past the hour, a longer TTL does rewrite it --"
rigMark "$(( rigNow - 7200 ))" 5
rigInterest "$rigNow" 60
rigAssert "the stale mark takes the reading call's own TTL" "$( rigMarkTtl )" 60
rigAssert "and its moment" "$( rigMarkEpoch )" "$rigNow"

echo "-- 6. the puller's own pass keeps no mark, so only a reader marks a channel --"
rigMark "$(( rigNow - 7200 ))" 5
( MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_COMMS_CACHE_PULLER=true bash -c '. "$1" ; AgentsToolsCommsCacheInterest "$2" "$3" 15' \
	_ "$rigInclude" "$rigEntry" "$rigNow" ) > /dev/null 2>&1 || :
rigAssert "a puller's pass leaves a reader's mark as the reader made it" "$( rigMarkEpoch )|$( rigMarkTtl )" "$(( rigNow - 7200 ))|5"
rm -f "$rigMarks/slack-CRIGCAP-1793000000.000001"
( MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_COMMS_CACHE_PULLER=true bash -c '. "$1" ; AgentsToolsCommsCacheInterest "$2" "$3" 15' \
	_ "$rigInclude" "$rigEntry" "$rigNow" ) > /dev/null 2>&1 || :
rigAssert "and a pass by the puller alone makes none" "$( [ -f "$rigMarks/slack-CRIGCAP-1793000000.000001" ] && echo made || echo none )" none

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ COMMS CACHE INTEREST CAP CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'COMMS_CACHE_INTEREST_CAP: OK (%d assertions, offline)\n' "$rigPassCount"
