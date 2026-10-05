#!/usr/bin/env bash
## Behavioural check that moving an inbox item to processed/ creates processed/ when the
## inbox has none, and that a missing inbox is still refused rather than created.
## Offline: a scratch team data store, no git, no remote.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigTool="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"

rigTmp="$( mktemp -d -t AgentsInboxToProcessedCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws/.local/.agents" "$rigTmp/data/inboxes/magic-librarian" || rigRefuse "could not create the scratch team data store"
printf -- '---\ntype: note\n---\n\n# Rig note\n' > "$rigTmp/data/inboxes/magic-librarian/note-rig.md" || rigRefuse "could not seed the inbox item"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigRun(){ ## operation and arguments
	( cd "$rigTmp/ws" && MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigTmp/data" bash "$rigTool" "$@" )
}

echo "-- an inbox with no processed/ folder --"
rigAssert "the inbox starts with no processed/"   "$( [ -d "$rigTmp/data/inboxes/magic-librarian/processed" ] && printf yes || printf no )" no
rigStatus=0
rigRun --librarian-inbox-to-processed magic-librarian note-rig.md > /dev/null 2>&1 || rigStatus=$?
rigAssert "the move succeeds"                     "$rigStatus" 0
rigAssert "the item lands in processed/"          "$( [ -f "$rigTmp/data/inboxes/magic-librarian/processed/note-rig.md" ] && printf yes || printf no )" yes
rigAssert "and leaves the inbox root"             "$( [ -f "$rigTmp/data/inboxes/magic-librarian/note-rig.md" ] && printf yes || printf no )" no

echo "-- a missing inbox is refused, not created --"
rigStatus=0
rigRun --librarian-inbox-to-processed keeper-rig note-rig.md > /dev/null 2>&1 || rigStatus=$?
rigAssert "the move is refused"                   "$( [ "$rigStatus" -ne 0 ] && printf refused || printf accepted )" refused
rigAssert "and no inbox is created"               "$( [ -e "$rigTmp/data/inboxes/keeper-rig" ] && printf yes || printf no )" no

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ INBOX TO PROCESSED CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'INBOX_TO_PROCESSED: OK (%d assertions, offline)\n' "$rigPassCount"