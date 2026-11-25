#!/usr/bin/env bash
## Behavioural check on S10.31's reader lifetime: the comms reader is one long-lived process that runs a pass a
## second, and a pass whose source cannot be read must leave it alive for the next pass.
## Held:
##   1. a process with errexit off, as the reader's loop runs, reaches its own next line after one comms ingest
##      pass over a due source whose read cannot succeed
##   2. and errexit is still off there, so the pass left the process's shell as it found it
##   3. and a failing command after that pass does not end it
##   4. control: the same process over a store with no source due reaches its next line, so row 1 turns on the
##      pass that ran and not on the store being read
## Offline: no network, one mktemp workspace, and a source whose read cannot succeed in it (no Slack account).
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPass="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.CommsIngestPass.include"
[ -f "$rigPass" ] || { echo "⛔ ERROR: the ingest pass is not at the origin this workspace resolves: $rigPass" >&2 ; exit 1 ; }
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
[ -f "$rigTool" ] || { echo "⛔ ERROR: the entry script is not at the origin this workspace resolves: $rigTool" >&2 ; exit 1 ; }

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
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsCommsReaderLifetimeCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

## A store the pass reads: one channel folder, its recipe line naming the member and the target. A source is due
## while its `.state.txt` is newer than its `.ingest.txt` and its own TTL has passed since that ingest.
rigWorkspace(){ ## name, with-source yes|no
	local wsRoot="$rigTmp/$1" wsStore="$rigTmp/$1/.local/cache/comms/slack/slack-CRIGTGT"
	mkdir -p "$wsRoot/.local/temp" "$wsStore" || return 1
	printf 'pulled 0 0\n' > "$wsStore/.state.txt"
	if [ "$2" = yes ] ; then
		printf 'slack-conversation CRIGTGT magic-team false\n' >> "$wsStore/.state.txt"
		: > "$wsStore/.ingest.txt"
		touch -t 202001010000 "$wsStore/.ingest.txt"
		touch -t 203001010000 "$wsStore/.state.txt"
	fi
	printf '%s\n' "$wsRoot"
}

## One pass, in a child of its own shape: the reader's own command line is the entry script, so the child's $0 is
## that script, and its shell starts with errexit off as the reader's loop runs. It prints its own lines, so a
## process that ended inside the pass prints nothing.
rigPass1(){ ## workspace, entry-script as $0 (yes|no)
	local childName="$1"
	if [ "$2" = yes ] ; then
		MMDAPP="$childName" "$BASH" -c '
			set +e +u
			. "$1"
			AgentsCommsIngestPass 1 > /dev/null 2>&1
			printf "ALIVE errexit=%s\n" "$( set -o | LC_ALL=C awk '"'"'$1=="errexit"{print $2}'"'"' )"
			false
			printf "SURVIVED\n"
		' "$rigTool" "$rigPass" 2> /dev/null
	else
		MMDAPP="$childName" "$BASH" -c '
			set +e +u
			. "$2"
			AgentsCommsIngestPass 1 > /dev/null 2>&1
			printf "ALIVE errexit=%s\n" "$( set -o | LC_ALL=C awk '"'"'$1=="errexit"{print $2}'"'"' )"
			false
			printf "SURVIVED\n"
		' "$rigPass" "$rigPass" 2> /dev/null
	fi
}

echo "-- row 1: the reader's own shape, one pass over a due source whose read cannot succeed --"
rigBusy="$( rigPass1 "$( rigWorkspace busy yes )" yes )"
rigAssert "the process reaches its own next line after the pass" "$( printf '%s\n' "$rigBusy" | LC_ALL=C sed -n '1s/ .*//p' )" "ALIVE"
rigAssert "and errexit is still off there, as the pass found it" "$( printf '%s\n' "$rigBusy" | LC_ALL=C sed -n '1s/.*errexit=//p' )" "off"
rigAssert "and it survives a failing command after the pass" "$( printf '%s\n' "$rigBusy" | LC_ALL=C sed -n '2p' )" "SURVIVED"

echo "-- control: the same pass over a store with no source due --"
rigQuiet="$( rigPass1 "$( rigWorkspace quiet no )" yes )"
rigAssert "it reaches its own next line" "$( printf '%s\n' "$rigQuiet" | LC_ALL=C sed -n '1s/ .*//p' )" "ALIVE"

echo "-- control: the same pass in a process whose command line names no entry script --"
rigPlain="$( rigPass1 "$( rigWorkspace plain yes )" no )"
rigAssert "it reaches its own next line too, so row 1 turns on the reader's shape" "$( printf '%s\n' "$rigPlain" | LC_ALL=C sed -n '1s/ .*//p' )" "ALIVE"

printf '\n%d passed, %d failed\n' "$rigPasses" "$rigFails"
[ "$rigFails" = 0 ]
