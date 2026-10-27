#!/usr/bin/env bash
## Behavioural check on the mechanical dependency recompute (F7.12, sh-lib/board/AgentsTools.BoardDependencies.include), which the main loop runs by script
## and which replaced the agent's once-a-day recompute. Held, against a rig board with its own git repository:
##   1. a gate recorded at one end gets its other end: `blocks` on one item gives the other `blocked-by`, and the reverse; a name already there is not
##      added twice; the list is kept, the new name after it
##   2. an item of processed, archived or retained is history and is never written, whichever end of the edge it is
##   3. a cycle of `blocks` is found and reported; what must happen first, what waits and on what, what is blocked with no blocker on the board, and
##      the number of independent items are reported (.local/agents/board-dependencies.last)
##   4. nothing is done while the board has not changed: a second call prints nothing and leaves the report as it was; an item written, one that
##      came or moved makes the next call recompute
##   5. the scan section is the report, or one line that there is none yet
## Offline: a temp data root with a local git repository, no remote; every call through one `env -i` whose child refuses to run outside this rig's tree.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigInclude="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.BoardDependencies.include"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] && [ -f "$rigInclude" ] || rigRefuse "dispatcher or include not found"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsBoardDependenciesCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data"
mkdir -p "$rigTmp/ws/.local/agents"
for rigState in backlog pending running review blocked parked processed archived retained ; do
	mkdir -p "$rigData/board/$rigState"
done
rigGit(){ env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="/usr/bin:/bin" GIT_CONFIG_NOSYSTEM=1 git -C "$rigData" "$@" ; }
rigGit init -q || rigRefuse "git init failed"
rigGit config user.email rig@example.invalid
rigGit config user.name rig
rigGit config commit.gpgsign false

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigItem(){ ## state, bare name, extra frontmatter lines -- written and committed
	printf -- '---\ntype: task\nowner: rig\n%s---\n\nrig item\n' "$3" > "$rigData/board/$1/$2.md"
	rigGit add -- "board/$1/$2.md" && rigGit commit -q -m "rig: $2" -- "board/$1/$2.md"
}
rigField(){ ## bare name, field -- its value, wherever the item lies
	local fieldState
	for fieldState in "$rigData"/board/*/ ; do
		[ -f "${fieldState}$1.md" ] || continue
		LC_ALL=C sed -n "s/^$2: //p" "${fieldState}$1.md" | head -1
		return 0
	done
}
## The one way this rig runs the function: a clean environment, the real dispatcher behind DistroAgentsTools.
rigRun(){ ## result file, function and arguments...
	local runOut="$1" ; shift
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="/usr/bin:/bin" GIT_CONFIG_NOSYSTEM=1 MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_FN="$rigFn" RIG_INCLUDE="$rigInclude" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			DistroAgentsTools(){ ( cd "$MMDAPP" && bash "$RIG_FN" "$@" ) ; }
			. "$RIG_INCLUDE"
			"$@"
		' rig "$@" > "$runOut" 2>&1
	printf '%s' "$?" > "$runOut.rc"
}
rigReport="$rigTmp/ws/.local/agents/board-dependencies.last"

echo "-- 5. before any recompute the section says so --"
rigRun "$rigTmp/s0" AgentsToolsBoardDependenciesSection
rigAssert "one line that there is none yet" "$( LC_ALL=C grep -c -F '(none recomputed yet)' "$rigTmp/s0" )" 1

echo "-- 1. the other end of a gate --"
rigItem running task-rig-a $'blocks: task-rig-b\n'
rigItem pending task-rig-b ''
rigItem backlog task-rig-d $'blocked-by: task-rig-c\n'
rigItem running task-rig-c ''
rigItem blocked task-rig-e $'blocked-by: task-rig-f\n'
rigItem running task-rig-f $'blocks: task-rig-e\n'
rigItem pending task-rig-g $'blocked-by: task-rig-h\n'
rigItem running task-rig-h $'blocks: task-rig-g, task-rig-i\n'
rigItem pending task-rig-i $'blocked-by: task-rig-h\n'
rigRun "$rigTmp/r1" AgentsToolsBoardDependencies
rigAssert "the call succeeds" "$( cat "$rigTmp/r1.rc" )" 0
rigAssert "a blocks at one end gives the other end its blocked-by" "$( rigField task-rig-b blocked-by )" "task-rig-a"
rigAssert "a blocked-by at one end gives the other end its blocks" "$( rigField task-rig-c blocks )" "task-rig-d"
rigAssert "an edge recorded at both ends is left as it is: no line of it, nothing added twice" "$( rigField task-rig-e blocked-by ):$( rigField task-rig-f blocks ):$( LC_ALL=C grep -c -e 'task-rig-e' -e 'task-rig-f' "$rigTmp/r1" || : )" "task-rig-f:task-rig-e:0"
rigAssert "the new name is added after the list that stood there" "$( rigField task-rig-g blocked-by ):$( rigField task-rig-h blocks )" "task-rig-h:task-rig-g, task-rig-i"
rigAssert "each fix is said in one line" "$( LC_ALL=C grep -c '^dependencies: ' "$rigTmp/r1" )" 2
rigAssert "the item is written in its own state, and the store is committed" "$( rigGit status --porcelain | wc -l | tr -d ' ' ):$( [ -f "$rigData/board/pending/task-rig-b.md" ] && printf pending )" "0:pending"

echo "-- 2. history is never written --"
rigItem processed task-rig-p $'blocked-by: task-rig-q\n'
rigItem running task-rig-q $'blocks: task-rig-p, task-rig-r\n'
rigItem archived task-rig-r ''
rigRun "$rigTmp/r2" AgentsToolsBoardDependencies
rigAssert "an item of processed or archived is not touched, whichever end it is" "$( rigField task-rig-p blocked-by ):$( rigField task-rig-r blocked-by ):$( rigField task-rig-q blocks )" "task-rig-q::task-rig-p, task-rig-r"
rigItem processed task-rig-s $'blocks: task-rig-t\n'
rigItem pending task-rig-t ''
rigRun "$rigTmp/r2b" AgentsToolsBoardDependencies
rigAssert "an active item whose other end is history is not written either" "$( rigField task-rig-t blocked-by ):$( LC_ALL=C grep -c '^dependencies: ' "$rigTmp/r2b" || : )" ":0"

echo "-- 3. the report --"
rigItem running task-rig-x $'blocks: task-rig-y\n'
rigItem running task-rig-y $'blocks: task-rig-x\n'
rigItem blocked task-rig-z $'blocked-by: task-rig-gone\n'
rigItem backlog task-rig-solo ''
rigRun "$rigTmp/r3" AgentsToolsBoardDependencies
rigAssert "a cycle of blocks is reported" "$( LC_ALL=C grep -c -E '^cycles: .*(task-rig-x -> task-rig-y -> task-rig-x|task-rig-y -> task-rig-x -> task-rig-y)' "$rigReport" )" 1
rigAssert "what must happen first: an item that gates others and waits for none" "$( LC_ALL=C sed -n 's/^must happen first: //p' "$rigReport" | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c -x -e task-rig-a -e task-rig-c -e task-rig-f -e task-rig-h -e task-rig-q )" 5
rigAssert "what waits, and on what" "$( LC_ALL=C grep -c -x -e '- task-rig-b <- task-rig-a' -e '- task-rig-d <- task-rig-c' -e '- task-rig-i <- task-rig-h' "$rigReport" )" 3
rigAssert "a blocked item naming no blocker on the board" "$( LC_ALL=C sed -n 's/^blocked with no blocker on the board: //p' "$rigReport" )" "task-rig-z"
rigAssert "the independent items are counted" "$( LC_ALL=C sed -n 's/^independent: //p' "$rigReport" )" 2
rigAssert "the fixes of the first recompute stay in the report that made them" "$( LC_ALL=C grep -c -x -F -e '- task-rig-b blocked-by now task-rig-a' "$rigReport" || : )" 0
rigRun "$rigTmp/s1" AgentsToolsBoardDependenciesSection
rigAssert "the section is the report" "$( LC_ALL=C grep -c -F '## board dependencies (recomputed ' "$rigTmp/s1" )" 1

echo "-- 4. nothing while the board has not changed --"
rigSumBefore="$( cksum < "$rigReport" )"
rigRun "$rigTmp/r4" AgentsToolsBoardDependencies
rigAssert "a call with no change prints nothing and leaves the report as it was" "$( wc -c < "$rigTmp/r4" | tr -d ' ' ):$( [ "$( cksum < "$rigReport" )" = "$rigSumBefore" ] && printf same )" "0:same"
sleep 1
printf -- '---\ntype: task\nowner: rig\nblocks: task-rig-solo\n---\n\nrig item\n' > "$rigData/board/running/task-rig-new.md"
rigGit add -- board/running/task-rig-new.md && rigGit commit -q -m "rig: new"
rigRun "$rigTmp/r5" AgentsToolsBoardDependencies
rigAssert "an item that came makes the next call recompute" "$( rigField task-rig-solo blocked-by ):$( LC_ALL=C grep -c '^dependencies: task-rig-solo' "$rigTmp/r5" )" "task-rig-new:1"
rigAssert "and the report names what it wrote this time" "$( LC_ALL=C grep -c -x -F -e '- task-rig-solo blocked-by now task-rig-new' "$rigReport" )" 1
sleep 1
rigGit mv board/running/task-rig-new.md board/review/task-rig-new.md && rigGit commit -q -m "rig: moved"
rigRun "$rigTmp/r6" AgentsToolsBoardDependencies
rigAssert "an item that moved makes it recompute too, and nothing is left to write" "$( wc -c < "$rigTmp/r6" | tr -d ' ' ):$( LC_ALL=C grep -c 'task-rig-new' "$rigReport" | LC_ALL=C awk '{ print ( $1 > 0 ) ? "named" : "none" }' )" "0:named"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ BOARD DEPENDENCIES CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'BOARD_DEPENDENCIES: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
