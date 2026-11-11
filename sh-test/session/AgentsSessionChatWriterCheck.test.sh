#!/usr/bin/env bash
## AgentsSessionChatWriterCheck -- an append to a session chat file goes through the workspace's one chat writer thread where
## it is on, and falls back to the locked direct append where no thread answers (AgentsTools.SessionChatWriter.include,
## AgentsToolsSessionChatAppend in AgentsTools.SessionChat.include; epic S5.8).
## Guards: with the thread serving, an append answers the block's number and the block stands in the file and its index, with
## no request file left; two appends from two processes at once both land, with the numbers 2 and 3 between them; a body of
## several lines arrives whole; with the switch off the thread is not asked; with the thread gone and its operation absent
## from the dispatch, the append still lands, directly, and the request file is removed; the thread appends nothing twice.
## Red: a writer that never answers fails `the number is answered`; a front that loses the body fails `the body is whole`.
## Offline: the thread is served by this check in the background, under a temp store of its own, ended at the end; nothing
## is requested.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigTmp="$( mktemp -d "${MMDAPP:-${TMPDIR:-/tmp}}/.local/agents/scratch/sh-test/AgentsSessionChatWriterCheck.XXXXXXXX" 2> /dev/null || mktemp -d "${TMPDIR:-/tmp}/AgentsSessionChatWriterCheck.XXXXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigWs="$rigTmp/ws"
## The thread this check serves is noted and signalled through the one helper of sh-test, so a reused pid is never signalled.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
rigPids=""
rigStop(){ [ -z "$rigPids" ] || rigProcSignal TERM $rigPids ; rigPids="" ; }
trap 'rigStop ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigWs/.local/agents/sessions" "$rigWs/.local/temp" || exit 1
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigDir="$rigWs/.local/agents/chat-writer"
rigChat="$rigWs/.local/agents/sessions/rig-s/session.chat"
## The thread, served here as its operation serves it, in the background.
rigServe(){
	(
		cd "$rigTmp" || exit 1
		MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" ; export MMDAPP MDLT_ORIGIN
		. "$rigLib/session/AgentsTools.SessionChat.include" || exit 1
		. "$rigLib/session/AgentsTools.SessionChatWriter.include" || exit 1
		AgentsToolsInternSessionChatWriter --run
	) > /dev/null 2>&1 &
	rigPids="$rigPids $!"
	rigProcNote $!
	local waited=0
	while [ "$waited" -lt 20 ] && { [ ! -p "$rigDir/request.fifo" ] || [ ! -s "$rigDir/thread.lock" ] ; } ; do sleep 1 ; waited=$(( waited + 1 )) ; done
	[ -p "$rigDir/request.fifo" ] || { echo "⛔ ERROR: the thread never made its request fifo" >&2 ; exit 1 ; }
}
## One append as a writer makes it: the switch as given, the body on stdin, the number on stdout.
rigAppend(){ ## switch (on|off), from, body
	(
		MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SESSION_CHAT_WRITER="$1" ; export MMDAPP MDLT_ORIGIN MDAT_SESSION_CHAT_WRITER
		. "$rigLib/session/AgentsTools.SessionChat.include" || exit 1
		printf '%s' "$3" | AgentsToolsSessionChatAppend rig-s "$2" rig-b - - own
	) 2> /dev/null
}

echo "-- 1. with the thread serving, an append answers its number and lands --"
rigServe
rigAssert "the number is answered"                             "$( rigAppend on rig-a 'hello' )" 1
rigAssert "the block stands in the file"                       "$( LC_ALL=C grep -c '^hello$' "$rigChat" 2> /dev/null )" 1
rigAssert "and in the index"                                   "$( LC_ALL=C cut -f 1 "$rigChat.index" 2> /dev/null | LC_ALL=C tr '\n' ' ' )" "1 "
rigAssert "no request file is left"                            "$( ls "$rigDir"/req.* 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 0
rigAssert "the lock is not held"                               "$( [ -e "$rigWs/.local/agents/locks/chat-rig-s" ] && printf held || printf free )" free

echo "-- 2. two writers at once both land --"
rigAppend on rig-a 'first' > "$rigTmp/n1" &
rigPidOne=$!
rigAppend on rig-c 'second' > "$rigTmp/n2" &
rigPidTwo=$!
## The two writers alone are waited for: the serving thread is a job of this shell too, and ends only on idle or TERM.
wait "$rigPidOne" "$rigPidTwo"
rigAssert "the numbers are 2 and 3"                            "$( cat "$rigTmp/n1" "$rigTmp/n2" | LC_ALL=C sort -n | LC_ALL=C tr '\n' ' ' )" "2 3 "
rigAssert "both blocks stand"                                  "$( LC_ALL=C grep -c -e '^first$' -e '^second$' "$rigChat" )" 2

echo "-- 3. a body of several lines arrives whole --"
rigAppend on rig-a $'line one\nline two\n\nline four' > /dev/null
rigAssert "the body is whole"                                  "$( LC_ALL=C grep -c -e '^line one$' -e '^line two$' -e '^line four$' "$rigChat" )" 3

echo "-- 4. with the switch off, the thread is not asked --"
rigBefore="$( LC_ALL=C wc -l < "$rigDir/thread.log" | LC_ALL=C tr -d ' ' )"
rigAssert "the direct append answers"                          "$( rigAppend off rig-a 'direct' )" 5
rigAssert "the thread saw no request"                          "$( [ "$( LC_ALL=C wc -l < "$rigDir/thread.log" | LC_ALL=C tr -d ' ' )" = "$rigBefore" ] && printf same || printf grew )" same

echo "-- 5. with the thread gone and its operation absent, the append falls back and lands --"
rigStop
sleep 2
rigAssert "the fallback answers the next number"               "$( rigAppend on rig-a 'fallback' )" 6
rigAssert "the block stands"                                   "$( LC_ALL=C grep -c '^fallback$' "$rigChat" )" 1
rigAssert "no request file is left"                            "$( ls "$rigDir"/req.* 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 0
rigAssert "nothing landed twice: six blocks"                   "$( LC_ALL=C wc -l < "$rigChat.index" | LC_ALL=C tr -d ' ' )" 6

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SESSION CHAT WRITER CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	echo "  warn: appends to a session chat file contend on its lock, a second lost a try, or an append through the thread is lost or doubled" >&2
	echo "  fix:  AgentsToolsSessionChatWriterAppend and its handler in sh-lib/session/AgentsTools.SessionChatWriter.include, the front in AgentsTools.SessionChat.include" >&2
	exit 1
fi
echo "SESSION_CHAT_WRITER: OK ($rigPass assertions, offline)"
