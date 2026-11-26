#!/usr/bin/env bash
## Behavioural check on the board's state groups: every group of board states names a subset of
## sh-lib/board/AgentsTools.BoardStates.include, so a state added to the one list is handled
## everywhere it belongs and no reader outside the board holds a state's name of its own.
##   1. THE ONE LIST names the nine states, and every named subset is made of those states alone.
##   2. EVERY STATE HAS ONE HOME: it is open or concluded, and in neither twice. A state added to the
##      one list and given no home fails here.
##   3. THE SCAN FINDS NO GROUP of two or more states named as its own set in sh-lib or sh-scripts.
##      Every remaining row is listed with the reason it stands, and the list must equal the scan, so
##      a new row is red and a vanished one is red too.
##   4. THE SCAN'S CONTROLS, both directions: it finds a planted `|`-group and a planted spaced run,
##      and passes a single state, a comment, and a foreign vocabulary.
##   5. RED ON A GROWN LIST: a state added to the one list and given no home is left homeless.
## Offline: reads the package source and a temp rig of this check's own; nothing is requested.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigInclude="$rigPackage/sh-lib/board/AgentsTools.BoardStates.include"
rigScan="$rigPackage/sh-test/board/AgentsBoardStateGroupScan.awk"
[ -f "$rigInclude" ] || { echo "⛔ ERROR: the states include is not there: $rigInclude" >&2 ; exit 1 ; }
[ -f "$rigScan" ] || { echo "⛔ ERROR: the group scan is not there: $rigScan" >&2 ; exit 1 ; }
mkdir -p "$MMDAPP/.local/agents/scratch/sh-test" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/agents/scratch/sh-test/AgentsBoardStateGroupsCheck.XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
## One named list of an include, as its words in one line.
rigSubset(){ ## include path, variable name
	LC_ALL=C sed -n "s/^$2=\"\{0,1\}\([^\"]*\)\"\{0,1\}\$/\\1/p" "$1" | head -1
}
## The names of every named list an include carries.
rigSubsetNames(){ ## include path
	LC_ALL=C sed -n 's/^\(agentsBoard[A-Za-z]*\)=.*$/\1/p' "$1"
}
## Whether a word stands in a space-separated list.
rigIn(){ ## word, list
	case " $2 " in *" $1 "*) return 0 ;; esac
	return 1
}
rigScanRun(){ ## root, its states include, the file the scan skips (the include): one row a group found
	LC_ALL=C awk -v states="$( rigSubset "$2" agentsBoardStates )" -v skipPath="$3" -f "$rigScan" \
		$( cd "$1" && find sh-lib sh-scripts -type f \( -name '*.include' -o -name '*.sh' -o -name '*.awk' \) | LC_ALL=C sort | sed "s|^|$1/|" ) \
		| sed "s|^$1/||"
}
## THE ROWS THAT STAND, one a line as `<file> <count> <the run>`, each with the reason it is no set
## to convert. A row is a move's from-state and to-state, passed as that one call's own two
## arguments: it names no group, and a subset would change which move the call makes. The line
## number is left out so an unrelated edit above a row does not turn this red, and the count is kept
## so a second such pair in one file is still a new row.
rigStanding(){
	cat <<'STANDING' | LC_ALL=C sort
sh-lib/board/AgentsTools.BoardHousekeeping.include 1 running review
sh-lib/board/AgentsTools.ReviewFlow.include 3 review running
sh-lib/manager/AgentsTools.OpManagerSessionRestart.include 1 review running
sh-lib/spawn/AgentsTools.InternOpAgentSpawnProxy.include 1 running review
sh-lib/spawn/AgentsTools.SpawnProxyWaitClose.include 1 running review
STANDING
}

echo "-- 1. the one list, and every subset of it --"
rigStates="$( rigSubset "$rigInclude" agentsBoardStates )"
rigAssert "the one list names the nine states" "$rigStates" "backlog pending running review blocked parked processed archived retained"
rigSubNames="$( rigSubsetNames "$rigInclude" | LC_ALL=C sort | tr '\n' ' ' )"
case " $rigSubNames " in
	*" agentsBoardStates "*) rigAssert "the one list is one of the names it carries" yes yes ;;
	*) rigAssert "the one list is one of the names it carries" no yes ;;
esac
rigSubCount=0
for rigSubName in $rigSubNames ; do
	rigSubValue="$( rigSubset "$rigInclude" "$rigSubName" )"
	rigStray="" ; rigStateWords=0
	for rigWord in $rigSubValue ; do
		if rigIn "$rigWord" "$rigStates" ; then rigStateWords=$(( rigStateWords + 1 )) ; else rigStray="$rigStray$rigWord " ; fi
	done
	[ "$rigStateWords" -gt 0 ] || continue
	rigAssert "$rigSubName is made of the one list's states alone" "$rigStray" ""
	rigSubCount=$(( rigSubCount + 1 ))
done
rigAssert "the include names a subset beyond its one list" "$( [ "$rigSubCount" -ge 2 ] && printf yes || printf no )" "yes"

echo "-- 2. every state of the one list has one home --"
rigOpen="$( rigSubset "$rigInclude" agentsBoardOpenStates )"
rigConcluded="$( rigSubset "$rigInclude" agentsBoardConcludedStates )"
rigUnhomed="" ; rigTwice=""
for rigWord in $rigStates ; do
	rigHomes=0
	rigIn "$rigWord" "$rigOpen" && rigHomes=$(( rigHomes + 1 ))
	rigIn "$rigWord" "$rigConcluded" && rigHomes=$(( rigHomes + 1 ))
	[ "$rigHomes" -ge 1 ] || rigUnhomed="$rigUnhomed$rigWord "
	[ "$rigHomes" -le 1 ] || rigTwice="$rigTwice$rigWord "
done
rigAssert "every state of the one list is open or concluded" "$rigUnhomed" ""
rigAssert "no state of the one list is both"                 "$rigTwice" ""

echo "-- 3. no group of board states is named outside the states include --"
## EVERY FILE THAT READS A NAMED SUBSET SOURCES THE INCLUDE ABOVE ITS FIRST READ, so a state is never
## read as an empty string. A name assigned by this include is no read of it, so the include's own file
## is the one such file and no other may assign one. The population is derived from the include's names.
## The guard is a function the include defines, so a load that breaks is loud at the call.
rigNamePattern="$( rigSubsetNames "$rigInclude" | LC_ALL=C awk 'BEGIN { ORS = "" ; } { print ( NR > 1 ? "|" : "" ) "\\$" $1 ; }' )"
rigReadBeforeLoad="" ; rigLoadFiles=0
for rigFile in $( cd "$rigPackage" && LC_ALL=C grep -rlE "$rigNamePattern" sh-lib sh-scripts ) ; do
	case "$rigFile" in sh-lib/board/AgentsTools.BoardStates.include) continue ;; esac
	rigLoadFiles=$(( rigLoadFiles + 1 ))
	rigReadAt="$( LC_ALL=C grep -nE "$rigNamePattern" "$rigPackage/$rigFile" | head -1 | cut -d: -f1 )"
	rigLoadAt="$( LC_ALL=C grep -n '\. "\$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.BoardStates.include"' "$rigPackage/$rigFile" | head -1 | cut -d: -f1 )"
	if [ -z "$rigLoadAt" ] || [ "$rigLoadAt" -ge "$rigReadAt" ] ; then rigReadBeforeLoad="$rigReadBeforeLoad$rigFile:$rigReadAt:$rigLoadAt " ; fi
done
rigAssert "every file that reads a subset sources the include above its first read" "$rigReadBeforeLoad" ""
rigAssert "the population is every such file, measured not listed" "$( [ "$rigLoadFiles" -gt 20 ] && printf yes || printf no )" "yes"
rigRows="$( rigScanRun "$rigPackage" "$rigInclude" "$rigInclude" | LC_ALL=C awk -F': ' '{ file = $1 ; sub( /:[0-9]+$/, "", file ) ; print file " " $2 ; }' | LC_ALL=C sort | LC_ALL=C uniq -c | LC_ALL=C awk '{ count = $1 ; file = $2 ; sub( /^[ \t]*[0-9]+ +[^ ]+ +/, "" ) ; print file, count, $0 ; }' | LC_ALL=C sort )"
rigWant="$( rigStanding | LC_ALL=C grep . | LC_ALL=C sort )"
printf '%s\n' "$rigWant" > "$rigTmp/want"
rigDiff="$( printf '%s\n' "$rigRows" | LC_ALL=C diff "$rigTmp/want" - || : )"
rigRowsCount="$( printf '%s' "$rigRows" | LC_ALL=C grep -c . )"
rigWantCount="$( printf '%s' "$rigWant" | LC_ALL=C grep -c . )"
rigAssert "the groups the scan finds are exactly the rows that stand, with their reasons" "$rigDiff" ""
[ -z "$rigDiff" ] || printf '%s\n' "$rigDiff" | LC_ALL=C sed 's/^/        /'
printf '        (%s rows found, %s rows standing)\n' "$rigRowsCount" "$rigWantCount"

echo "-- 4. the scan's own controls, both directions --"
## The control rig's own states include sits outside any board store, so no fixture writes into one.
rigFake="$rigTmp/fake"
mkdir -p "$rigFake/sh-lib/states" "$rigFake/sh-scripts"
rigFakeInclude="$rigFake/sh-lib/states/rig-states.include"
printf '#!/usr/bin/env bash\nagentsBoardStates="%s"\n' "$rigStates" > "$rigFakeInclude"
printf '#!/usr/bin/env bash\n## a comment naming running|review is no row\ncase "$s" in\n\trunning|review) : ;;\nesac\ncase "$s" in\n\trunning|parked|failed|finished) : ;;\nesac\n[ "$s" = running ] || :\n' > "$rigFake/sh-lib/states/AgentsTools.Planted.include"
rigAssert "the planted pipe-group is found, and the comment, the foreign vocabulary and the single state are not" \
	"$( rigScanRun "$rigFake" "$rigFakeInclude" "$rigFakeInclude" | sed 's|.*/||' | tr '\n' ' ' )" "AgentsTools.Planted.include:4: running|review "
printf '#!/usr/bin/env bash\nfor s in backlog pending running review ; do : ; done\n' > "$rigFake/sh-lib/states/AgentsTools.Planted.include"
rigAssert "the planted spaced run is found" "$( rigScanRun "$rigFake" "$rigFakeInclude" "$rigFakeInclude" | sed 's|.*/||' | tr '\n' ' ' )" "AgentsTools.Planted.include:2: backlog pending running review "
printf '#!/usr/bin/env bash\ncase "$s" in\n\trunning) : ;;\n\treview) : ;;\nesac\n' > "$rigFake/sh-lib/states/AgentsTools.Planted.include"
rigAssert "a file naming the states apart holds no group" "$( rigScanRun "$rigFake" "$rigFakeInclude" "$rigFakeInclude" )" ""

echo "-- 5. a state added to the one list and given no home is homeless --"
rigGrown="$rigTmp/grown.include"
LC_ALL=C sed 's/^agentsBoardStates="\(.*\)"$/agentsBoardStates="\1 rig-new-state"/' "$rigInclude" > "$rigGrown"
rigGrownUnhomed=""
for rigWord in $( rigSubset "$rigGrown" agentsBoardStates ) ; do
	rigHomes=0
	rigIn "$rigWord" "$( rigSubset "$rigGrown" agentsBoardOpenStates )" && rigHomes=$(( rigHomes + 1 ))
	rigIn "$rigWord" "$( rigSubset "$rigGrown" agentsBoardConcludedStates )" && rigHomes=$(( rigHomes + 1 ))
	[ "$rigHomes" -ge 1 ] || rigGrownUnhomed="$rigGrownUnhomed$rigWord "
done
rigAssert "the grown list leaves rig-new-state with no home" "$rigGrownUnhomed" "rig-new-state "

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ BOARD STATE GROUPS CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'BOARD_STATE_GROUPS: OK (%d assertions, offline)\n' "$rigPass"
