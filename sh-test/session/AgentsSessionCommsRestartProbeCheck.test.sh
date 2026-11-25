#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on the restart a reader makes after its own code changed (task-20261120T1710Z-comms-reader-drops-queued-posts).
## Held:
##   1. A RESTART INSIDE THE START GAP STARTS A READER. `AgentsToolsSessionCommsStart` bounds ordinary callers to one start a minute, so a
##      reader that died cannot be replaced by every caller after it. The reader replacing its own ended process calls with `restart`, and
##      that purpose is let through. This is the state the fault is about: a reader that ends on a code change inside the gap used to get no
##      replacement, and the posts it was carrying waited for whatever asked next.
##   2. THE CONTROL: an ordinary caller on that same fresh marker is still held, and answers `recent` with no start.
##   3. THE SECOND CONTROL: a marker older than the gap does not hold an ordinary caller either, so the gap is what arm 1 passes, not the
##      absence of one.
## Red without the fix: arm 1 answers `recent` and the log holds no start.
## Offline: no Slack is asked, and no reader is left running. The start a `restart` makes is real, and it is ended by removing its folder,
## which is the end the reader itself watches.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
for rigDrop in ${!MDAT_SPAWN_@} MDAT_SESSION_ID MDAT_SESSION_THREAD MDAT_CONVERSATION_THREADS MDAT_WAIT_REMIND harnessSessionId harnessAgent CLAUDE_CODE_SESSION_ID ; do
	unset "$rigDrop" 2> /dev/null || :
done
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionCommsRestartProbeCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigInclude="$rigOrigin/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionComms.include"
[ -f "$rigInclude" ] || { echo "⛔ ERROR: the comms session include is not at the origin this workspace resolves: $rigInclude" >&2 ; exit 1 ; }
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One call of the start, in a workspace of its own, answering what it said. The reader's setting is `off` for the two calls that must not
## start one, so the measurement is the gap's answer and never a process.
## `off` is the default so no arm starts a process it did not ask for. An arm that must reach the gap sets it on, and the one arm that
## starts a reader ends it by removing its folder.
rigStart(){ ## the workspace name, then the call's argument (may be none)
	local rigName="$1" ; shift
	local rigWs="$rigTmp/$rigName" rigMode="${rigReaderMode:-off}"
	mkdir -p "$rigWs/.local/agents/comms" "$rigWs/.local/temp" || return 1
	( cd "$rigWs" && env -u MDAT_SESSION_ID "MMDAPP=$rigWs" "MDLT_ORIGIN=$rigOrigin" "MDAT_COMMS_READER=$rigMode" \
		bash -c '. "$1" || exit 9 ; shift ; AgentsToolsSessionCommsStart "$@"' _ "$rigInclude" "$@" ) 2> /dev/null
}
rigStarts(){ ## the workspace name -- how many start lines its log holds
	LC_ALL=C grep -c 'a start of the communications reader is made' "$rigTmp/$1/.local/agents/comms/log" 2> /dev/null || printf 0
}
rigMark(){ mkdir -p "$rigTmp/$1/.local/agents/comms/.starting" ; }

echo "-- 1. a restart inside the start gap starts a reader --"
rigMark restart-reader
rigReaderMode=on
rigSaid="$( rigStart restart-reader restart )"
rigReaderMode=""
rigAssert "the restart is answered with a started process" "$( printf '%s\n' "$rigSaid" | LC_ALL=C awk '{ print $1 ; }' )" "started"
rigAssert "and the log holds the start it made" "$( rigStarts restart-reader )" 1

echo "-- 2. control: an ordinary caller on the same fresh marker is still held --"
## The reader's setting must NOT be off here: `Start` answers `off` before it ever reaches the gap, so a control run that way would measure
## the setting and not the gap. The reader is on, and what this arm reads is the gap's own answer.
rigMark plain-caller
rigReaderMode=on
mkdir -p "$rigTmp/plain-caller/.local/agents/comms"
printf '%s rig
' "$$" > "$rigTmp/plain-caller/.local/agents/comms/lock"
rigSaid="$( rigStart plain-caller )"
rigReaderMode=""
rm -f "$rigTmp/plain-caller/.local/agents/comms/lock"
rigAssert "the ordinary caller inside the gap is held by it, and told so" "$( printf '%s\n' "$rigSaid" | LC_ALL=C awk '{ print $1 ; }' )" "recent"
rigAssert "and its log holds no start" "$( rigStarts plain-caller )" 0

echo "-- 3. control: a marker older than the gap does not hold an ordinary caller --"
## The only difference from arm 2 is the marker's age, so the pair shows the gap is what held arm 2: past it the same call starts one.
rigMark old-marker
rigReaderMode=on
mkdir -p "$rigTmp/old-marker/.local/agents/comms"
printf '%s rig
' "$$" > "$rigTmp/old-marker/.local/agents/comms/lock"
touch -t 202001010000 "$rigTmp/old-marker/.local/agents/comms/.starting"
rigSaid="$( rigStart old-marker )"
rigReaderMode=""
rm -f "$rigTmp/old-marker/.local/agents/comms/lock"
rigAssert "past the gap the same ordinary caller starts one, so the gap is what held arm 2" "$( printf '%s\n' "$rigSaid" | LC_ALL=C awk '{ print $1 ; }' )" "started"
rigAssert "the gap it must pass is the one this arm is about" \
	"$( MDLT_ORIGIN="$rigOrigin" bash -c '. "$1" || exit 9 ; printf "%s\n" "$agentsSessionCommsStartGap"' _ "$rigInclude" )" 60

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ COMMS RESTART PROBE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'COMMS_RESTART_PROBE: OK (%d assertions, offline)\n' "$rigPassCount"
