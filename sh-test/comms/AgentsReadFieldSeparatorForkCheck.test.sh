#!/usr/bin/env bash
## Behavioural check of a read loop's field separator on the comms reader's sweep (code-craft: no subshell per call). An assignment
## before a command is expanded each time the command runs, so `while IFS="$( printf '\t' )" read` started a subshell for every line it
## read. AgentsCommsTransferSlack in a rig store of 285 sources, under xtrace, where a subshell shows one level deeper than its caller:
##   1. one reader's transfer pass over the list starts no subshell for its separator
##   2. and the pass still reads the list: a reader with no source of its own hands nothing over and writes no pointer
##   3. no read in the tooling takes its separator from a command substitution
## Red before the change: the pass started two subshells a line, 570 for the list's 285.
## Offline: a rig store of this check's own; nothing is written to any inbox.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsReadFieldSeparatorForkCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigStore="$rigTmp/ws/.local/cache/comms/slack"
bash -c 'i=0 ; while [ $i -lt 285 ] ; do d="$1/slack-bot-C0RIG$( printf %05d $i )" ; mkdir -p "$d" ; printf "1 0 0\n\nslack-conversation C0RIG%05d magic-other false\n" $i > "$d/.state.txt" ; i=$(( i + 1 )) ; done' rig "$rigStore"

echo "-- 1. a transfer pass starts no subshell for its separator --"
MMDAPP="$rigTmp/ws" rigPkg="$rigPkg" PS4='+:${FUNCNAME[0]:-main}: ' bash -c '
	. "$rigPkg/sh-lib/comms/AgentsTools.CommsTransfer.include" || exit 1
	AgentsCommsTransferSources "$MMDAPP/.local/cache/comms/.transfer/sources.txt" "$MMDAPP/.local/cache/comms/slack" || exit 1
	set -x ; AgentsCommsTransferSlack magic-rig' > /dev/null 2> "$rigTmp/trace"
rigAssert "subshells of the separator in one pass" "$( LC_ALL=C grep -cE "^\+\+[+]*:AgentsCommsTransferSlack: printf '\\\\t'" "$rigTmp/trace" )" 0

echo "-- 2. the pass reads the list and hands nothing over --"
rigAssert "the list it read" "$( LC_ALL=C grep -c . "$rigTmp/ws/.local/cache/comms/.transfer/sources.txt" )" 285
rigAssert "no pointer for a reader with no source" "$( [ -e "$rigTmp/ws/.local/cache/comms/.transfer/magic-rig.txt" ] && echo written || echo none )" none

echo "-- 3. no read takes its separator from a command substitution --"
rigAssert "such reads in the tooling" "$( LC_ALL=C grep -rnE 'IFS="\$\(' "$rigPkg/sh-lib" "$rigPkg/sh-scripts" | LC_ALL=C grep -vc ':[[:space:]]*##' )" 0

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ READ FIELD SEPARATOR FORK CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'READ_FIELD_SEPARATOR_FORK: OK (%d assertions, offline, rig store only)\n' "$rigPass"
