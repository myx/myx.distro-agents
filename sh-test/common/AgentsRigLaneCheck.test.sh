#!/usr/bin/env bash
## Behavioural check on the lane of rigCopyTree (check-fixtures/rig-copy.include.sh). A tree reaches a rig through a folder
## kept between runs and synced by rsync, so a run sends what changed and nothing else. Offline: every tree is this check's own rig.
## Each row reads the lane it finds under the rig's own workspace. A file counts as sent when its inode is new.
## Rsync writes a sent file beside the old one, then renames it over it. Held:
##   1. a second sync of a tree that did not change sends no file, and the lane is the one folder of both runs
##   2. a tree with one changed file sends that file and no other
##   3. a file removed from the source is removed from the lane and from the rig, so the lane follows the source
##   4. the rig is the source as it stands now, with no .git and no link
##   5. CONTROLS, so that rows 1 to 3 are able to fail. A lane made whole on every run is read as sending every file.
##      A lane synced without --delete is read as keeping the removed file.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
. "$rigHere/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRigLaneCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}

## The two lanes a row must tell from the real one. Each keeps its own folder under rig-lanes, as the real lane does.
rigLaneWhole(){ ## source, destination -- the lane made again whole on every run, the new one beside the old so that no inode is reused
	local wholeLane="$MMDAPP/.local/agents/scratch/rig-lanes/whole"
	mkdir -p "$wholeLane.new" && rsync -rtLO --exclude=.git "$1/" "$wholeLane.new/" && rm -rf -- "$wholeLane" && mv "$wholeLane.new" "$wholeLane" && rsync -rtLO "$wholeLane/" "$2/"
}
rigLaneKeep(){ ## source, destination -- the lane kept between runs and synced without --delete
	local keepLane="$MMDAPP/.local/agents/scratch/rig-lanes/keep"
	mkdir -p "$keepLane" && rsync -rtLO --exclude=.git "$1/" "$keepLane/" && rsync -rtLO "$keepLane/" "$2/"
}
rigLaneInodes(){ ## lane -- a line a file, `<inode> <path below the lane>`, in path order
	( cd "$1" && find . -type f -exec ls -i {} + | LC_ALL=C sort -k2 )
}
rigLaneMoved(){ ## inodes before, inodes after -- the files whose inode is new or not the one before, comma between, or `none`
	RIG_BEFORE="$1" LC_ALL=C awk '
		BEGIN { rowCount = split( ENVIRON["RIG_BEFORE"], beforeRows, "\n" ) ; for ( rowNo = 1 ; rowNo <= rowCount ; rowNo++ ) { split( beforeRows[rowNo], beforeWord, " " ) ; beforeInode[beforeWord[2]] = beforeWord[1] ; } ; }
		( ! ( $2 in beforeInode ) ) || beforeInode[$2] != $1 { movedList = movedList ( movedList != "" ? "," : "" ) $2 ; }
		END { print ( movedList != "" ? movedList : "none" ) ; }' <<< "$2"
}
rigLaneRun(){ ## name, sync function -- what that sync does to a tree left alone, then changed by a file, then cut by a file, on one line
	(
		MMDAPP="$rigTmp/ws-$1" ; export MMDAPP
		runSrc="$rigTmp/src-$1" ; runOut="$rigTmp/out-$1"
		mkdir -p "$MMDAPP" "$runSrc/lib/deep" "$runSrc/.git" "$runOut" || exit 1
		printf 'one\n' > "$runSrc/a.sh" ; printf 'two\n' > "$runSrc/lib/b.txt" ; printf 'three\n' > "$runSrc/lib/deep/c.txt" ; printf 'four\n' > "$runSrc/d.txt" ; printf 'head\n' > "$runSrc/.git/HEAD"
		"$2" "$runSrc" "$runOut/1" > /dev/null || exit 1
		runLane="$( set -- "$MMDAPP"/.local/agents/scratch/rig-lanes/*/ ; printf '%s' "${1%/}" )"
		[ -d "$runLane" ] || exit 1
		runFirst="$( rigLaneInodes "$runLane" )"
		"$2" "$runSrc" "$runOut/2" > /dev/null || exit 1
		runSecond="$( rigLaneInodes "$runLane" )"
		printf 'two changed\n' > "$runSrc/lib/b.txt"
		"$2" "$runSrc" "$runOut/3" > /dev/null || exit 1
		runThird="$( rigLaneInodes "$runLane" )"
		rm -f "$runSrc/d.txt"
		"$2" "$runSrc" "$runOut/4" > /dev/null || exit 1
		printf 'unchanged=%s changed=%s lane-removed=%s rig-removed=%s rig-same=%s git=%s links=%s lanes=%s\n' \
			"$( rigLaneMoved "$runFirst" "$runSecond" )" "$( rigLaneMoved "$runSecond" "$runThird" )" \
			"$( [ -e "$runLane/d.txt" ] && printf kept || printf gone )" "$( [ -e "$runOut/4/d.txt" ] && printf kept || printf gone )" \
			"$( diff -r --exclude=.git "$runSrc" "$runOut/4" > /dev/null 2>&1 && printf same || printf differs )" \
			"$( [ -e "$runLane/.git" ] || [ -e "$runOut/4/.git" ] && printf found || printf none )" \
			"$( find "$runLane" "$runOut" -type l | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" \
			"$( find "$MMDAPP/.local/agents/scratch/rig-lanes" -mindepth 1 -maxdepth 1 | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )"
	)
}
rigLaneField(){ ## line, key -- the value of that key in the line
	local fieldRest=" $1"
	fieldRest="${fieldRest#* $2=}"
	printf '%s' "${fieldRest%% *}"
}

rigRealLine="$( rigLaneRun real rigCopyTree )" || rigRefuse "the lane of rigCopyTree could not be run"
rigWholeLine="$( rigLaneRun whole rigLaneWhole )" || rigRefuse "the whole-copy stand-in could not be run"
rigKeepLine="$( rigLaneRun keep rigLaneKeep )" || rigRefuse "the no-delete stand-in could not be run"
rigAll="./a.sh,./d.txt,./lib/b.txt,./lib/deep/c.txt"

echo "-- 1. a second sync of an unchanged tree sends no file, into the one lane --"
rigAssert "the second sync sends no file" "$( rigLaneField "$rigRealLine" unchanged )" none
rigAssert "the lane is one folder across the runs, not one a run" "$( rigLaneField "$rigRealLine" lanes )" 1
echo "-- 2. a changed file is the only file the next sync sends --"
rigAssert "one file changed, one file sent" "$( rigLaneField "$rigRealLine" changed )" ./lib/b.txt
echo "-- 3. a file removed from the source is removed from the lane and the rig --"
rigAssert "the lane no longer holds the removed file" "$( rigLaneField "$rigRealLine" lane-removed )" gone
rigAssert "the rig no longer holds it" "$( rigLaneField "$rigRealLine" rig-removed )" gone
echo "-- 4. the rig is the source as it stands --"
rigAssert "the rig holds the same files and bytes as the source" "$( rigLaneField "$rigRealLine" rig-same )" same
rigAssert "neither the lane nor the rig holds a .git" "$( rigLaneField "$rigRealLine" git )" none
rigAssert "neither holds a link" "$( rigLaneField "$rigRealLine" links )" 0
echo "-- 5. controls: the rows above are able to fail --"
rigAssert "a lane made whole on every run sends every file of an unchanged tree (row 1 reads it)" "$( rigLaneField "$rigWholeLine" unchanged )" "$rigAll"
rigAssert "and every file of a changed one (row 2 reads it)" "$( rigLaneField "$rigWholeLine" changed )" "$rigAll"
rigAssert "a lane synced without --delete keeps the removed file in the lane (row 3 reads it)" "$( rigLaneField "$rigKeepLine" lane-removed )" kept
rigAssert "...and in the rig, which then differs from the source (row 4 reads it)" "$( rigLaneField "$rigKeepLine" rig-removed ) $( rigLaneField "$rigKeepLine" rig-same )" "kept differs"
rigAssert "that lane differs from the real one in row 3 alone: it sends the same files in rows 1 and 2" "$( rigLaneField "$rigKeepLine" unchanged ) $( rigLaneField "$rigKeepLine" changed )" "none ./lib/b.txt"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ RIG LANE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'RIG_LANE: OK (%d assertions, offline)\n' "$rigPasses"
