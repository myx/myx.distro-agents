#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on the session-thread top-up's back-off (epic `## Decisions` line 96: the base is 3 seconds and the ceiling
## 60, twenty times the base). `AgentsWaitChatTopUp` weighs a read of the session thread against a TTL that grows with how quiet
## the thread is: `3 + quiet / 20`, and never past 60. The two numbers this check holds are that base and that ceiling.
## Held:
##   1. a quiet session is weighed again after 3 seconds, and not after 2 -- the base is 3, not the 5 it was
##   2. a session quiet for hours is weighed at the ceiling: after 60 seconds, not 59 -- the ceiling is 60, not 300
##   3. control: a top-up long overdue reads and moves its pointer, and a fresh one does not fire, so a row that reads nothing is
##      told from a top-up that never ran
## The top-up's neighbours -- the thread read, the chat import and the store -- are stubbed by this check, so nothing leaves the
## machine and the arithmetic is the whole subject. Where the read fires is told by the stub's own record.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigInclude="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/wait/AgentsTools.MemberWaitChat.include"
[ -f "$rigInclude" ] || { echo "⛔ ERROR: the session-chat wait is not at the origin this workspace resolves: $rigInclude" >&2 ; exit 1 ; }
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
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsWaitChatTopUpAgeCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/agents/sessions/rig-session" "$rigWs/.local/temp" || exit 1
rigClock=1000000

## One top-up, in a shell of its own so no previous row's hour and weighing memory stands: the pointer is the given seconds behind
## the clock, the thread's newest message the given seconds behind it. Prints `read` where the top-up read the thread, and
## `pointer <value>` where it moved the pointer.
rigTopUp(){ ## seconds since the last top-up, seconds since the thread's newest message
	local topElapsed="$1" topQuiet="$2" topRecord="$rigTmp/record.$$.$1.$2"
	: > "$topRecord"
	( MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" rigPointer=$(( rigClock - topElapsed )) rigNewest=$(( rigClock - topQuiet )) \
		rigRecord="$topRecord" rigTs="1793600000.000001" bash -c '
			. "$1" 2> /dev/null || exit 9
			roundNow="$2"
			AgentsToolsSessionChatPointer(){ printf "%s\n" "$rigPointer" ; }
			AgentsToolsSessionChatNewestInto(){ printf -v "$1" "%s" "$rigNewest" ; }
			AgentsToolsSessionChatReaderLooked(){ return 0 ; }
			AgentsToolsSessionChatPointerSet(){ printf "pointer %s\n" "$3" >> "$rigRecord" ; return 0 ; }
			AgentsToolsSessionChatImport(){ return 0 ; }
			AgentsWaitReadRendered(){ printf "read\n" >> "$rigRecord" ; return 0 ; }
			AgentsWaitChatTopUp rig-member rig-session "CRIG00001:$rigTs" "$rigRecord.out"
		' _ "$rigInclude" "$rigClock" > /dev/null 2>&1
	)
	LC_ALL=C grep -c '^read$' "$topRecord" 2> /dev/null | LC_ALL=C tr -d ' '
}
rigMoved(){ ## the same row's record: what the pointer was set to
	LC_ALL=C sed -n 's/^pointer //p' "$rigTmp/record.$$.$1.$2" 2> /dev/null
}

echo "-- 1. a quiet session is weighed again after 3 seconds, and not after 2 --"
rigAssert "a top-up is due 3 seconds after the last one, on a thread that has just spoken" "$( rigTopUp 3 0 )" 1
rigAssert "and one 2 seconds after it is not due, so the base is exactly 3" "$( rigTopUp 2 0 )" 0

echo "-- 2. a session quiet for hours is weighed at the ceiling: after 60 seconds, not 59 --"
rigAssert "a top-up is due 60 seconds after the last one, on a thread silent for a day" "$( rigTopUp 60 86400 )" 1
rigAssert "and one 59 seconds after it is not due, so the ceiling is exactly 60" "$( rigTopUp 59 86400 )" 0

echo "-- 3. control: a top-up long overdue reads, and moves its pointer, so a row that reads nothing is told from one that judged --"
rigAssert "a top-up nine hundred seconds overdue reads the thread" "$( rigTopUp 900 0 )" 1
rigAssert "and it moves the pointer to the clock it read at" "$( rigMoved 900 0 )" "$rigClock"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ WAIT CHAT TOP-UP AGE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_CHAT_TOP_UP_AGE: OK (%d assertions, offline)\n' "$rigPasses"
