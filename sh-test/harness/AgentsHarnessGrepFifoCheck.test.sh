#!/usr/bin/env bash
## Behavioural check on this team's Grep over a folder holding a fifo (S10.26, board task 20261106T1012Z;
## `AgentsHarnessToolGrep` in AgentsHarnessToolsFile.include). A thread's `request.fifo` sits in a `.local` tree, and a recursive grep
## that opens one blocks for good: 47 such processes sat orphaned at 0% CPU for up to 38 hours before this was fixed. The tool passes
## `-D skip`, which BSD and GNU grep both take. Held, run rather than read:
##   1. A GREP OVER A FOLDER HOLDING A FIFO RETURNS, and finds the match in the file beside it.
##   2. IT FINDS ONE IN `files_with_matches` AND IN `count` TOO, the two other modes.
##   3. A FIFO IS NOT SEARCHED AND NOT REPORTED: it is skipped in the walk, never opened and never named as a match.
##   4. AND A FOLDER WITH NO MATCH ANSWERS `No matches found`, so the check separates an empty answer from a blocked one.
##   5. A SHELL `grep -r` THROUGH THE GUARD GREP RETURNS TOO (`AgentsToolsGrepGuardMake`, AgentsTools.SandboxLinks.include, the
##      `grep` the served Bash tool puts first on PATH): it finds the file beside the fifo, never names the fifo, and a grep of
##      stdin through it reads stdin as before.
## Every call is bounded here, so a fault reports as a call that stood still rather than standing still with it.
## The access gate is a stand-in that allows everything: whether a path may be read is AgentsHarnessAccessRootsCheck's question, and the
## fifo is this one. The pattern reader, and the tool's own scratch, are the package's real ones.
## RED RECIPE, measured on a copy under this check's own scratch on 2026-11-06: delete `-D skip` from the three mode lines at :592-594
## and rows 1 to 3 fail with a call that stood still.
## Offline: the include this check loads, a rig of its own, and no git or network.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigInclude="$rigPackage/sh-lib/harness/AgentsHarnessToolsFile.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the harness file tools are not at $rigInclude"
[ -f "$rigPackage/sh-lib/harness/AgentsHarnessGrepPatternToPosix.awk" ] || rigRefuse "the Grep pattern reader is not in the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessGrepFifoCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigFolder="$rigTmp/tree"
rigScratch="$rigTmp/scratch"
mkdir -p "$rigFolder" "$rigScratch" || exit 1
printf 'rig-alpha\nsecond line\n' > "$rigFolder/note.txt"
printf 'nothing here\n' > "$rigFolder/other.txt"
## THE FIFO, made as a thread makes one. Nothing ever writes to it, which is what a real request fifo looks like between requests.
mkfifo "$rigFolder/request.fifo" || rigRefuse "this host refused to make a fifo in the rig"
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
## THE TOOL'S OWN SHELL: the include sourced, its access gate a stand-in that allows every path, its scratch and its reader the real
## ones. The call is bounded at 30 seconds, and a call that overran says so in its own answer.
cat > "$rigTmp/prelude.sh" <<'PRELUDE'
. "$RIG_INCLUDE" || exit 1
AgentsHarnessReadGate(){ harnessResolvedPath="$2" ; return 0 ; }
AgentsHarnessRefusal(){ printf 'REFUSED: %s\n' "$3" ; return 1 ; }
harnessHere="$RIG_LIB"
harnessScratch="$RIG_SCRATCH"
harnessReadCap=100000
PRELUDE
rigGrep(){ ## the output mode, then the path and the pattern
	rigMode="$1" ; rigPath="$2" ; rigPattern="$3"
	RIG_INCLUDE="$rigInclude" RIG_LIB="$rigPackage/sh-lib" RIG_SCRATCH="$rigScratch" \
		bash -c '. "$1" ; shift ; AgentsHarnessToolGrep "$@"' rig-grep "$rigTmp/prelude.sh" "$rigPattern" "$rigPath" "" "" "" "" "$rigMode" \
		> "$rigTmp/out" 2>&1 &
	rigGrepPid="$!"
	rigProcNote "$rigGrepPid"
	left=60
	while [ "$left" -gt 0 ] ; do
		kill -0 "$rigGrepPid" 2> /dev/null || break
		sleep 1 ; left=$(( left - 1 ))
	done
	if kill -0 "$rigGrepPid" 2> /dev/null ; then
		rigProcSignal TERM "$rigGrepPid" || :
		sleep 1
		rigProcSignal KILL "$rigGrepPid" || :
		rigOut="<the call stood still for 60 seconds>"
	else
		wait "$rigGrepPid" 2> /dev/null
		rigOut="$( cat "$rigTmp/out" )"
	fi
}
rigVerdict(){ ## whether the last call returned at all
	case "$rigOut" in
		'<the call stood still'*) printf 'still-running' ;;
		*) printf 'returned' ;;
	esac
}

echo "-- 1. a grep over a folder holding a fifo returns --"
rigGrep content "$rigFolder" 'rig-alpha'
rigAssert "the call returned rather than blocking on the fifo" "$( rigVerdict )" returned
rigAssert "and it found the match in the file beside the fifo" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c -F 'note.txt:' )" 1

echo "-- 2. and in the other two modes --"
rigGrep files_with_matches "$rigFolder" 'rig-alpha'
rigAssert "files_with_matches returns the file that holds the match" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c -F 'note.txt' )" 1
rigGrep count "$rigFolder" 'rig-alpha'
rigAssert "count returns rather than blocking" "$( rigVerdict )" returned

echo "-- 3. a fifo is skipped, never searched and never named --"
rigGrep content "$rigFolder" 'rig-alpha'
rigAssert "the fifo is not named in the answer" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'request.fifo' )" 0
rigGrep content "$rigFolder/request.fifo" 'rig-alpha'
rigAssert "a search naming the fifo itself answers without blocking" "$( rigVerdict )" returned

echo "-- 4. a folder with no match says so --"
rigGrep content "$rigFolder" 'no-such-word-anywhere'
rigAssert "the empty answer is the tool's own words, not a blocked call" "$( printf '%s\n' "$rigOut" )" 'No matches found'

echo "-- 5. a shell grep -r through the guard grep returns --"
rigGuardBin="$rigTmp/ws/.local/agents/guard-bin"
( . "$rigPackage/sh-lib/session/AgentsTools.SandboxLinks.include" && AgentsToolsGrepGuardMake "$rigGuardBin" ) || rigRefuse "the guard grep could not be made in the rig"
rigAssert "the guard grep is first on the rig's PATH" "$( PATH="$rigGuardBin:$PATH" command -v grep )" "$rigGuardBin/grep"
PATH="$rigGuardBin:$PATH" grep -r 'rig-alpha' "$rigFolder" > "$rigTmp/out" 2>&1 &
rigGrepPid="$!"
rigProcNote "$rigGrepPid"
left=60
while [ "$left" -gt 0 ] ; do
	kill -0 "$rigGrepPid" 2> /dev/null || break
	sleep 1 ; left=$(( left - 1 ))
done
if kill -0 "$rigGrepPid" 2> /dev/null ; then
	rigProcSignal TERM "$rigGrepPid" || : ; sleep 1 ; rigProcSignal KILL "$rigGrepPid" || :
	rigOut="<the call stood still for 60 seconds>"
else
	wait "$rigGrepPid" 2> /dev/null ; rigOut="$( cat "$rigTmp/out" )"
fi
rigAssert "a shell grep -r over the folder returns rather than blocking on the fifo" "$( rigVerdict )" returned
rigAssert "and finds the match in the file beside the fifo, never naming the fifo" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c -F 'note.txt:' ):$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'request.fifo' )" "1:0"
rigAssert "a grep of stdin through the guard reads stdin as before" "$( printf 'rig-alpha\n' | PATH="$rigGuardBin:$PATH" grep -c 'rig-alpha' )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ HARNESS GREP FIFO CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'HARNESS_GREP_FIFO: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
