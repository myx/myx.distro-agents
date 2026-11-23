#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on the interest mark's DELETE age (sketch 20261102-refactorings line 55: `separate cleanup in
## comms-service-thread, 36h for interest's`, and line 72: `cleaned after 36 h`; epic `## Decisions` line 94: `The
## interest-mark cleanup age is 36 hours, as the sketch states. The code and its check assert 36.`). The hourly clean in
## `AgentsToolsCommsCachePullWatched` deletes a mark past that age and the entry with it. The mark is
## `$MMDAPP/.local/cache/comms/.interest/<service>-<id>`, and the entry it names is
## `$MMDAPP/.local/cache/comms/<service>/<service>-<id>`.
## Held:
##   1. a mark 35 hours old SURVIVES the hourly clean, and its entry with it -- the inside edge of the age
##   2. a mark 37 hours old is DELETED with its entry -- the outside edge, and the positive control that the clean ran
##   3. control: an entry with no mark is removed by the same clean, so a kept entry is a judgement and not a clean that never ran
##   4. control: an entry whose mark is fresh survives, so the clean is not removing everything it is shown
## Offline: one mktemp tree, no network, nothing of the team's read. The 48-hour refresh stop is a different age and is the cleanup
## check's; this check reads the delete age alone.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigInclude="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.CommsCache.include"
[ -f "$rigInclude" ] || { echo "⛔ ERROR: the comms cache is not at the origin this workspace resolves: $rigInclude" >&2 ; exit 1 ; }
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
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsCommsInterestAgeCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigCache="$rigTmp/ws/.local/cache/comms"
rigMarks="$rigCache/.interest"
mkdir -p "$rigMarks" || exit 1
rigNow="$( date +%s )"

## One entry as the cache lays it out, with its mark: the folder and the mark named the same. The mark's time carries the age, which
## is what the clean reads.
rigEntry(){ ## name, mark age in minutes or "none"
	mkdir -p "$rigCache/slack/$1/month" || exit 1
	printf '202610/messages.txt\n' > "$rigCache/slack/$1/.state.txt"
	case "$2" in
		none) rm -f "$rigMarks/$1" ;;
		*)
			printf '%s 15\n' "$(( rigNow - $2 * 60 ))" > "$rigMarks/$1"
			[ "$2" = 0 ] || touch -t "$( date -v-"$2"M '+%Y%m%d%H%M' 2>/dev/null || date -d "-$2 minutes" '+%Y%m%d%H%M' )" "$rigMarks/$1"
		;;
	esac
}
## One clean, in its own shell so the once-an-hour memory starts empty each time.
rigClean(){ ## clock
	( MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "$1" ; AgentsToolsCommsCachePullWatched "$2"' _ "$rigInclude" "$1" ) > /dev/null 2>&1 || :
}
rigKept(){ ## entry name -- kept or gone
	[ -d "$rigCache/slack/$1" ] && printf 'kept\n' || printf 'gone\n'
}

echo "-- 1. a mark 35 hours old survives the hourly clean, and its entry with it --"
## Inside the 36-hour age: 2100 minutes.
rigEntry 'slack-C0RIGCHAN-1793000000.000001' 2100
rigClean "$rigNow"
rigAssert "the page's own clean ran over the mark" "$( [ -f "$rigMarks/slack-C0RIGCHAN-1793000000.000001" ] && printf present || printf absent )" present
rigAssert "a mark 35 hours old survives the clean" "$( rigKept 'slack-C0RIGCHAN-1793000000.000001' )" kept

echo "-- 2. a mark 37 hours old is deleted with its entry --"
## Outside the 36-hour age: 2220 minutes. This row is also the positive control that the clean ran at all.
rigEntry 'slack-C0RIGCHAN-1793000000.000002' 2220
rigClean "$rigNow"
rigAssert "a mark 37 hours old is deleted" "$( [ -f "$rigMarks/slack-C0RIGCHAN-1793000000.000002" ] && printf present || printf absent )" absent
rigAssert "and its entry goes with it" "$( rigKept 'slack-C0RIGCHAN-1793000000.000002' )" gone

echo "-- 3. control: an entry with no mark is removed by the same clean --"
## The clean is proven by something it must do whatever the age is: a folder nobody marked is not of interest.
rigEntry 'slack-C0RIGCHAN-1793000000.000003' none
rigClean "$(( rigNow + 3600 ))"
rigAssert "an entry with no mark is removed" "$( rigKept 'slack-C0RIGCHAN-1793000000.000003' )" gone

echo "-- 4. control: an entry whose mark is fresh survives --"
rigEntry 'slack-C0RIGCHAN-1793000000.000004' 0
rigClean "$(( rigNow + 7200 ))"
rigAssert "a fresh mark keeps its entry" "$( rigKept 'slack-C0RIGCHAN-1793000000.000004' )" kept

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ COMMS INTEREST AGE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'COMMS_INTEREST_AGE: OK (%d assertions, offline)\n' "$rigPasses"
