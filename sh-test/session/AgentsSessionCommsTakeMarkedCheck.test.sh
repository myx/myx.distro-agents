#!/usr/bin/env bash
## Behavioural check of the console take at the top of the comms reader's pass (code-craft: a kept index, never a walk on a pass). The
## console's one writer marks the session it leaves a message for (AgentsToolsSessionCommsMark), and the mark stays while one is there.
## AgentsToolsSessionCommsTakeAll in a rig of three thousand session folders, the take itself recorded:
##   1. a pass takes the message of a marked session
##   2. and leaves an unmarked session's inbox to the walk: a pass reads no folder the writer did not mark
##   3. the walk (`all`, the reader's once-a-minute check) still takes a message no mark names
##   4. control: a marked session with nothing in its inbox is taken nothing
## Red before the change: every pass walked every session's inbox, three thousand folders a second, and took the unmarked one too.
## Offline: a rig workspace of this check's own; nothing is sent.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionCommsTakeMarkedCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigSessions="$rigTmp/ws/.local/agents/sessions"
rigWork="$rigTmp/ws/.local/agents/comms/work"
mkdir -p "$rigSessions" "$rigWork" || exit 1
bash -c 'i=0 ; while [ $i -lt 3000 ] ; do mkdir "$1/rig$( printf %05d $i )-0000" ; i=$(( i + 1 )) ; done' rig "$rigSessions"
rigMarked="rig00007-0000" ; rigUnmarked="rig02999-0000" ; rigEmpty="rig00100-0000"
mkdir -p "$rigSessions/$rigMarked/chat.inbox" "$rigSessions/$rigUnmarked/chat.inbox" "$rigSessions/$rigEmpty/chat.inbox"
printf 'magic-rig -> all:\nhello\n' > "$rigSessions/$rigMarked/chat.inbox/20261127T000000Z.a.msg"
printf 'magic-rig -> all:\nhello\n' > "$rigSessions/$rigUnmarked/chat.inbox/20261127T000000Z.b.msg"
printf '1\n' > "$rigWork/$rigMarked" ; printf '1\n' > "$rigWork/$rigEmpty"
rigTake(){ ## argument for the take: run it in the rig, the take recorded instead of sent
	MMDAPP="$rigTmp/ws" rigPkg="$rigPkg" bash -c '
		. "$rigPkg/sh-lib/session/AgentsTools.SessionComms.include" || exit 1
		AgentsToolsSessionCommsTake(){ printf "%s\n" "$1" ; rm -f "$2" ; }
		AgentsToolsSessionCommsTakeAll '"$1" 2> /dev/null
}

echo "-- 1. and 2. a pass takes the marked session alone --"
rigAssert "the sessions taken by a pass" "$( rigTake '' | tr '\n' ' ' )" "$rigMarked "
echo "-- 3. the walk takes a message no mark names --"
rigAssert "the sessions taken by the walk" "$( rigTake all | tr '\n' ' ' )" "$rigUnmarked "
echo "-- 4. control: nothing is left to take --"
rigAssert "a pass after both" "$( rigTake '' | tr '\n' ' ' )" ""

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SESSION COMMS TAKE MARKED CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_COMMS_TAKE_MARKED: OK (%d assertions, offline, rig workspace only)\n' "$rigPass"
