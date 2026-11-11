#!/usr/bin/env bash
## RED CHECK for S12.11's six rulings, all but ruling 1's call-site migration. Ruling 2 is the
## answer protocol: a handler that ran and had nothing to say must read as a served-and-empty
## answer, never as no answer. Ruling 3 is the framing: a field holding a tab or a newline is
## refused, not split. Ruling 4 is the idle bound: it belongs to the folder, and a start that
## answers `alive` reports the bound in force and says it discarded its own.
## Red today: section 1 fails, and sections 2 and 3 fail.
## Offline: every thread and fifo is under this rig's own temp folder.
set -u
: "${MMDAPP:?MMDAPP is not set}"
: "${MDLT_ORIGIN:?MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPkg="$rigOrigin/myx/myx.distro-agents"
rigInc="$rigPkg/sh-lib/common/AgentsTools.OnDemandThread.include"
rigFn="$rigPkg/sh-scripts/DistroAgentsTools.fn.sh"
[ -f "$rigInc" ] || { echo "ERROR: no thread include at $rigInc" >&2 ; exit 1 ; }
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
. "$rigPkg/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsOnDemandThreadAnswerCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigThreadsStop ; rm -rf -- "$rigTmp"' EXIT

rigPass=0 ; rigFail=0
rigAssert(){ if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 )) ; else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi ; }

rigOwner="$rigTmp/owner.sh"
cat > "$rigOwner" <<'RIGOWNER'
rigSilentHandler(){ return 0 ; }
rigWordHandler(){ printf 'handled %s\n' "${1:-nothing}" >&3 ; return 0 ; }
rigTick(){ return 0 ; }
RIGOWNER

rigThreadPids=""
rigThreadsStop(){ [ -z "$rigThreadPids" ] || rigProcSignal TERM $rigThreadPids ; rigThreadPids="" ; return 0 ; }
rigServe(){ ## folder, idle, handler
	(
		cd "$rigTmp" || exit 1
		. "$rigInc" || exit 1
		. "$rigOwner" || exit 1
		AgentsToolsOnDemandThreadServe "$1" "$2" "$3" rigTick no
	) >> "$1.log" 2>&1 &
	rigThreadPids="$rigThreadPids $!" ; rigProcNote "${rigThreadPids##* }"
	rigWaited=0
	while [ "$rigWaited" -lt 20 ] && [ ! -p "$1/request.fifo" ] ; do sleep 1 ; rigWaited=$(( rigWaited + 1 )) ; done
	[ -p "$1/request.fifo" ] || { echo "ERROR: no request fifo in $1" >&2 ; exit 1 ; }
}
## The caller's rc, and its answer beside it, in one call.
rigAsk(){ ## folder, bound, fields...
	( . "$rigInc" || exit 1 ; AgentsToolsOnDemandThreadAsk "$@" ) > "$rigTmp/ask.out" 2> "$rigTmp/ask.err"
	printf '%s' "$?"
}

echo "-- 1. ruling 2: a handler that ran and said nothing is served-and-empty, not no answer --"
mkdir -p "$rigTmp/silent"
rigServe "$rigTmp/silent" 20 rigSilentHandler
rigAssert "1. the caller reads a served answer, rc 0" "$( rigAsk "$rigTmp/silent" 5 ask )" 0
rigAssert "1. and its answer is empty" "$( cat "$rigTmp/ask.out" )" ""
rigThreadsStop

echo "-- 1b. the control, both directions: a word handler still reads its own words --"
mkdir -p "$rigTmp/word"
rigServe "$rigTmp/word" 20 rigWordHandler
rigAssert "1b. the caller reads rc 0" "$( rigAsk "$rigTmp/word" 5 ask )" 0
rigAssert "1b. and its answer is the handler's own words" "$( cat "$rigTmp/ask.out" )" "handled ask"
rigThreadsStop

echo "-- 1c. the control's other direction: no thread at all is still no answer --"
mkdir -p "$rigTmp/none"
rigAssert "1c. a caller with no thread reads rc 1" "$( rigAsk "$rigTmp/none" 2 ask )" 1

echo "-- 2. ruling 3: a field holding a tab or a newline is refused, not split --"
mkdir -p "$rigTmp/field"
rigServe "$rigTmp/field" 20 rigWordHandler
rigAssert "2. a field holding a tab is refused" "$( rigAsk "$rigTmp/field" 5 "$( printf 'a\tb' )" )" 1
rigAssert "2. and the refusal names the fault" \
	"$( LC_ALL=C grep -c 'tab or a newline' "$rigTmp/ask.err" || : )" 1
rigAssert "2. a field holding a newline is refused" "$( rigAsk "$rigTmp/field" 5 "$( printf 'a\nb' )" )" 1
rigAssert "2. and the thread is still there for the next caller" \
	"$( rigAsk "$rigTmp/field" 5 plain )" 0
rigThreadsStop

echo "-- 3. ruling 4: the bound is the folder's, and a start says what it discarded --"
mkdir -p "$rigTmp/bound"
rigServe "$rigTmp/bound" 17 rigWordHandler
rigAssert "3. the thread records the bound in force in its folder" \
	"$( cat "$rigTmp/bound/thread.idle" 2> /dev/null )" 17
rigStartOut="$( . "$rigInc" ; AgentsToolsOnDemandThreadStart "$rigTmp/bound" --intern-team-data-commit --run )"
rigAssert "3. a start over a living thread answers alive" \
	"$( printf '%s\n' "$rigStartOut" | LC_ALL=C head -1 | LC_ALL=C awk '{ print $1 }' )" alive
rigAssert "3. and names the bound in force, saying it discarded its own" \
	"$( printf '%s\n' "$rigStartOut" | LC_ALL=C grep -c -F 'bound 17s' || : )" 1
rigThreadsStop

if [ "$rigFail" -ne 0 ] ; then
	printf 'ON DEMAND THREAD ANSWER: FAILED, %d of %d assertions red\n' "$rigFail" "$(( rigPass + rigFail ))" >&2
	exit 1
fi
printf 'ON DEMAND THREAD ANSWER: OK (%d assertions)\n' "$rigPass"
