#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on the two store classes' retention (sh-lib/session/AgentsTools.SessionStore.Write.include): one function owns the
## fallback of 30 and reads each class's own key, neither prune reads a setting or invents a number, and the keys never cross.
## Held here, on a rig store of its own:
##   1. the resolver answers 30 for each class with neither key set
##   2. it answers each class's own key, and one class's key never moves the other's answer
##   3. an empty, non-numeric, zero or negative value answers 30, and no other class word is accepted
##   4. a prune handed no days removes nothing, so no prune invents a cut-off
##   5. a prune handed the resolver's answer removes its own class's old folder and keeps a young one
##   6. no caller reads a setting, and the one resolver holds the only 30
## Offline: a temp store of this check alone, removed at its end; no store of this machine is read.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents"
rigWrite="$rigPackage/sh-lib/session/AgentsTools.SessionStore.Write.include"
rigHouse="$rigPackage/sh-lib/board/AgentsTools.BoardHousekeeping.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -d "$rigHere/session" ] || rigRefuse "the session includes are not at the origin this workspace resolves: $rigHere"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRetentionKeyPerClassCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigStore="$rigTmp/ws"
rigBoard="$rigTmp/data"
mkdir -p "$rigStore/.local/agents/spawned" "$rigStore/.local/agents/sessions" "$rigBoard/board/running" \
	|| rigRefuse "the probe store could not be made"

rigPass=0 rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

## The resolver's answer for one class, with each key set to what is given and every retention name cleared first. A key given as `-` is
## left unset. It runs with nothing of this shell's environment, so a key set here cannot reach it.
rigDays(){ ## class, run key, session key
	( cd "$rigTmp" && env -i PATH=/usr/bin:/bin MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_RIG_CLASS="$1" MDAT_RIG_RUN_KEY="$2" MDAT_RIG_SESSION_KEY="$3" \
		bash -c '
			unset MDAT_CLEANUP_RUN_STORE_DAYS MDAT_CLEANUP_SESSION_STORE_DAYS MDAT_CLEANUP_RETENTION_DAYS
			[ "$MDAT_RIG_RUN_KEY" = "-" ] || MDAT_CLEANUP_RUN_STORE_DAYS="$MDAT_RIG_RUN_KEY"
			[ "$MDAT_RIG_SESSION_KEY" = "-" ] || MDAT_CLEANUP_SESSION_STORE_DAYS="$MDAT_RIG_SESSION_KEY"
			export MDAT_CLEANUP_RUN_STORE_DAYS MDAT_CLEANUP_SESSION_STORE_DAYS
			. "$1" ; AgentsToolsStoreRetentionDays "$MDAT_RIG_CLASS"
		' rig "$rigWrite" 2> /dev/null )
}
## The resolver's own status for a class word.
rigDaysStatus(){ ## class
	( env -i PATH=/usr/bin:/bin MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "$1" ; AgentsToolsStoreRetentionDays "$2" > /dev/null 2>&1' rig "$rigWrite" "$1" 2> /dev/null ) || printf 'rc-%s' "$?"
}

## A touch stamp that many days back, to the minute.
rigStampDaysAgo(){ ## days
	LC_ALL=C date -v-"$1"d '+%Y%m%d%H%M' 2> /dev/null || LC_ALL=C date -d "$1 days ago" '+%Y%m%d%H%M'
}
## A settled run folder of the given age: its spawn record and its output aged with it, so the newest write at or beneath it is old.
rigRunFolder(){ ## folder, days
	mkdir -p "$rigStore/.local/agents/spawned/$1/output" || rigRefuse "a folder of the probe store could not be made"
	printf 'a deliverable of the run\n' > "$rigStore/.local/agents/spawned/$1/output/report.txt"
	{
		printf -- '---\n'
		printf 'type: spawn\n'
		printf 'status: spawn-succeeded\n'
		printf 'session-id: %s\n' "$1"
		printf -- '---\n\n# a run of the check\n'
	} > "$rigStore/.local/agents/spawned/$1/$1.spawn.md"
	find "$rigStore/.local/agents/spawned/$1" -depth -exec touch -t "$( rigStampDaysAgo "$2" )" {} + || rigRefuse "a folder of the probe store could not be aged"
}
## A session folder of the given age whose thread is gone: a state, and a pid file naming no process.
rigSessionFolder(){ ## id, days
	mkdir -p "$rigStore/.local/agents/sessions/$1/control" || rigRefuse "a session folder of the probe store could not be made"
	printf 'state: running\n' > "$rigStore/.local/agents/sessions/$1/control/state"
	printf '999999 Sat_Jan_01_00:00:00_2022\n' > "$rigStore/.local/agents/sessions/$1/control/pid"
	find "$rigStore/.local/agents/sessions/$1" -depth -exec touch -t "$( rigStampDaysAgo "$2" )" {} + || rigRefuse "a session folder of the probe store could not be aged"
}
## One row of the spawned-sessions agents view: the folder first and the state thirteenth, as the render prints them.
rigRow(){ ## folder, state
	printf '%s %s none macmyx14 magic-developer spawn-succeeded 0 %s - - ws-rig live %s\n' "$1" "$1" "$1" "$2"
}
rigRunThere(){ [ -e "$rigStore/.local/agents/spawned/$1" ] && printf here || printf gone ; }
rigSessionThere(){ [ -e "$rigStore/.local/agents/sessions/$1" ] && printf here || printf gone ; }
## One prune of one class, handed the day word given and no setting of its own. The word is always passed, quoted and possibly empty: an
## empty one is the no-cut-off case, which a dropped argument would turn into a cut-off of 20.
rigPrune(){ ## class, days, rows
	( cd "$rigTmp" && env -i PATH=/usr/bin:/bin MMDAPP="$rigStore" MDAT_DATA_ROOT="$rigBoard" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_RIG_CLASS="$1" MDAT_RIG_DAYS="$2" MDAT_RIG_ROWS="$3" \
		bash -c '
			unset MDAT_CLEANUP_RUN_STORE_DAYS MDAT_CLEANUP_SESSION_STORE_DAYS MDAT_CLEANUP_RETENTION_DAYS
			. "$1" ; . "$2"
			case "$MDAT_RIG_CLASS" in
				run) printf "%s\n" "$MDAT_RIG_ROWS" | AgentsSpawnedRetentionPrune "$MDAT_RIG_DAYS" 20 ;;
				session) AgentsToolsSessionStorePrune "$MDAT_RIG_DAYS" 20 ;;
			esac
		' rig "$rigWrite" "$rigHere/session/AgentsTools.SessionStore.Paths.include" 2> /dev/null )
}
## The source of one file, its comment lines left out, so a grep over it reads code and never prose.
rigCode(){ LC_ALL=C awk '!/^[[:space:]]*#/ { print }' "$1" 2> /dev/null ; }

echo "-- 1. the fallback: each class answers 30 with neither key set --"
rigAssert "the run class answers 30 with no key set" "$( rigDays run - - )" "30"
rigAssert "the session class answers 30 with no key set" "$( rigDays session - - )" "30"

echo "-- 2. each class answers its own key, and neither key moves the other's answer --"
rigAssert "the run class answers its own key at 7" "$( rigDays run 7 - )" "7"
rigAssert "the session class answers its own key at 60" "$( rigDays session - 60 )" "60"
rigAssert "both keys set low and high, the run class answers its own" "$( rigDays run 7 60 )" "7"
rigAssert "both keys set low and high, the session class answers its own" "$( rigDays session 7 60 )" "60"
rigAssert "the mirror: run key 60 leaves the session class its 7" "$( rigDays session 60 7 )" "7"

echo "-- 3. a value that is no age answers the fallback, and no other class word is taken --"
rigAssert "an empty value answers 30" "$( rigDays run '' - )" "30"
rigAssert "a word answers 30" "$( rigDays run abc - )" "30"
rigAssert "a zero answers 30" "$( rigDays run 0 - )" "30"
rigAssert "a negative answers 30" "$( rigDays run -5 - )" "30"
rigAssert "a half number answers 30" "$( rigDays session - 3x )" "30"
rigAssert "a word that is no class is refused" "$( rigDaysStatus nonsense )" "rc-1"
rigAssert "an empty class word is refused" "$( rigDaysStatus '' )" "rc-1"

echo "-- 4. a prune handed no days removes nothing --"
rigRunFolder no-days-run 400
rigSessionFolder no-days-session 400
rigSaid="$( rigPrune run "" "$( rigRow no-days-run finished )" )" || rigSaid=""
rigAssert "the run prune given no days removes nothing" "$( rigRunThere no-days-run )" "here"
rigAssert "it prints nothing" "$rigSaid" ""
rigSaid="$( rigPrune session "" "" )" || rigSaid=""
rigAssert "the session prune given no days removes nothing" "$( rigSessionThere no-days-session )" "here"
rigAssert "it prints nothing too" "$rigSaid" ""
## The fixtures leave here, so the next section counts only its own folders.
rm -rf -- "$rigStore/.local/agents/spawned/no-days-run" "$rigStore/.local/agents/sessions/no-days-session" || rigRefuse "the fixtures of the last section could not be cleared"

echo "-- 5. a prune handed the resolver's answer removes its own class's old folder, and keeps a young one --"
rigRunFolder old-run 40
rigRunFolder young-run 2
rigSessionFolder old-session 40
rigSessionFolder young-session 2
rigSaid="$( rigPrune run "$( rigDays run - - )" "$( printf '%s\n' "$( rigRow old-run finished )" "$( rigRow young-run finished )" )" )" || rigSaid=""
rigAssert "the run folder past the answer goes" "$( rigRunThere old-run )" "gone"
rigAssert "the run folder inside the answer stays" "$( rigRunThere young-run )" "here"
rigAssert "the run prune says how many it removed" "$rigSaid" "1"
rigSaid="$( rigPrune session "$( rigDays session - - )" "" )" || rigSaid=""
rigAssert "the session folder past the answer goes" "$( rigSessionThere old-session )" "gone"
rigAssert "the session folder inside the answer stays" "$( rigSessionThere young-session )" "here"
rigAssert "the session prune says how many it removed" "$rigSaid" "1"

echo "-- 6. no caller reads a setting, and the one resolver holds the only 30 --"
rigHouseBody="$( rigCode "$rigHouse" )"
rigCallerBody="$( LC_ALL=C awk '/^AgentsToolsSpawnedRetentionRun\(\)[[:space:]]*\{/ { inside = 1 } inside { print } inside && /^\}/ { exit }' "$rigWrite" 2> /dev/null )"
rigAssert "the housekeeping pass hands the run prune no literal day count" "$( printf '%s\n' "$rigHouseBody" | LC_ALL=C grep -cE 'AgentsSpawnedRetentionPrune[[:space:]]+"?[0-9]' )" "0"
rigAssert "the housekeeping pass hands the session prune no literal day count" "$( printf '%s\n' "$rigHouseBody" | LC_ALL=C grep -cE 'AgentsToolsSessionStorePrune[[:space:]]+"?[0-9]' )" "0"
rigAssert "the housekeeping pass reads no retention day setting of its own" "$( printf '%s\n' "$rigHouseBody" | LC_ALL=C grep -cE 'MDAT_CLEANUP_[A-Z_]*DAYS' )" "0"
rigAssert "the housekeeping pass asks the resolver twice" "$( printf '%s\n' "$rigHouseBody" | LC_ALL=C grep -c 'AgentsToolsStoreRetentionDays' )" "2"
rigAssert "the daily caller reads no retention day setting of its own" "$( printf '%s\n' "$rigCallerBody" | LC_ALL=C grep -cE 'MDAT_CLEANUP_[A-Z_]*DAYS' )" "0"
rigAssert "the daily caller asks the resolver twice" "$( printf '%s\n' "$rigCallerBody" | LC_ALL=C grep -c 'AgentsToolsStoreRetentionDays' )" "2"
rigAssert "neither prune invents a day count" "$( rigCode "$rigWrite" | LC_ALL=C grep -cE '^	local (storeDays|pruneDays)="\$\{1:-\}"' )" "2"
rigAssert "the fallback 30 is written once in the file that carries it" "$( rigCode "$rigWrite" | LC_ALL=C grep -c 'daysKept=30' )" "1"

echo "-- control: the same rig, the run prune handed a day count that admits nothing --"
rigRunFolder kept-by-days 40
rigSaid="$( rigPrune run 900 "$( rigRow kept-by-days finished )" )" || rigSaid=""
rigAssert "a large cut-off the caller chose keeps the old folder" "$( rigRunThere kept-by-days )" "here"
rigAssert "and it says nothing" "$rigSaid" ""

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ RETENTION KEY PER CLASS CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	exit 1
fi
printf 'RETENTION_KEY_PER_CLASS: OK (%d assertions, offline)\n' "$rigPass"
exit 0
