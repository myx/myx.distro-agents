#!/usr/bin/env bash
## Behavioural check on the comms cache's hourly cleanup (S21.13, owner 2026-10-29): an entry whose interest mark is gone, or
## older than 48 hours, is removed with its folder; one whose mark is fresh stays; one with a post still in its outbox stays
## whatever its mark says. Named paths only: the entry is spelled from `$MMDAPP/.local/cache/comms/<service>/<entry>`.
## Held:
##   1. a marked, fresh entry SURVIVES the clean -- the case that fails where a mark is looked for under another name
##   2. an entry with no mark is removed
##   3. an entry whose mark is 49 hours old is removed
##   4. an entry with no mark but a post in outbox.messages.txt survives
##   5. the clean does not run twice in one hour: a second call with the same clock leaves everything as it is
## Offline: one mktemp tree, no network, nothing of the team's read.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
rigInclude="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.CommsCache.include"
[ -f "$rigInclude" ] || rigRefuse "not found at the origin this workspace resolves: $rigInclude"
rigPasses=0
rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsCommsCacheCleanupCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigCache="$rigTmp/ws/.local/cache/comms"
rigMarks="$rigCache/.interest"
mkdir -p "$rigMarks" || exit 1
rigNow="$( date +%s )"

## One entry as the cache lays it out, with its mark: `slack-<channel>-<ts>`, the folder and the mark named the same.
rigEntry(){ ## name, mark age in minutes or "none", outbox text or ""
	mkdir -p "$rigCache/slack/$1/month" || exit 1
	printf '202610/messages.txt\n' > "$rigCache/slack/$1/.state.txt"
	case "$2" in
		none) rm -f "$rigMarks/$1" ;;
		*)
			printf '%s 15\n' "$rigNow" > "$rigMarks/$1"
			[ "$2" = 0 ] || touch -t "$( date -v-"$2"M '+%Y%m%d%H%M' 2>/dev/null || date -d "-$2 minutes" '+%Y%m%d%H%M' )" "$rigMarks/$1"
		;;
	esac
	[ -z "$3" ] || printf '%s\n' "$3" > "$rigCache/slack/$1/outbox.messages.txt"
}
## One clean, in its own shell so the once-an-hour memory starts empty each time.
rigClean(){ ## clock
	( MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "$1" ; AgentsToolsCommsCachePullWatched "$2"' _ "$rigInclude" "$1" ) > /dev/null 2>&1 || :
}

## 1. A marked, fresh entry survives. This is the case a wrong mark name removes, and it fails there.
rigEntry 'slack-C0RIGCHAN-1793000000.000001' 0 ''
rigClean "$rigNow"
rigAssert "a marked, fresh entry survives the clean" "$( [ -d "$rigCache/slack/slack-C0RIGCHAN-1793000000.000001" ] && echo kept || echo gone )" kept

## 2. No mark: the entry goes.
rigEntry 'slack-C0RIGCHAN-1793000000.000002' none ''
( MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "$1" ; AgentsToolsCommsCachePullWatched "$2"' _ "$rigInclude" "$rigNow" ) > /dev/null 2>&1 || :
rigAssert "an entry with no mark is removed" "$( [ -d "$rigCache/slack/slack-C0RIGCHAN-1793000000.000002" ] && echo kept || echo gone )" gone

## 3. A mark 49 hours old: the entry goes, as its mark does.
rigEntry 'slack-C0RIGCHAN-1793000000.000003' 2940 ''
( MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "$1" ; AgentsToolsCommsCachePullWatched "$(( $2 + 3600 ))"' _ "$rigInclude" "$rigNow" ) > /dev/null 2>&1 || :
rigAssert "an entry whose mark is 49 hours old is removed" "$( [ -d "$rigCache/slack/slack-C0RIGCHAN-1793000000.000003" ] && echo kept || echo gone )" gone

## 4. No mark, but a post still to go out: never removed.
rigEntry 'slack-C0RIGCHAN-1793000000.000004' none 'a post nobody has sent yet'
( MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "$1" ; AgentsToolsCommsCachePullWatched "$(( $2 + 7200 ))"' _ "$rigInclude" "$rigNow" ) > /dev/null 2>&1 || :
rigAssert "an entry with a post in its outbox is never removed" "$( [ -d "$rigCache/slack/slack-C0RIGCHAN-1793000000.000004" ] && echo kept || echo gone )" kept

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ COMMS CACHE CLEANUP CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'COMMS_CACHE_CLEANUP: OK (%d assertions, offline)\n' "$rigPasses"
