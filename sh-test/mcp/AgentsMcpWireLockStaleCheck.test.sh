#!/usr/bin/env bash
## A wire lock left by a handler that was killed never keeps a served tool call from answering. The wire is one pipe held for one
## printf, so a lock whose recorded holder is gone was left behind. Before the take-over, every later response waited 30 s for it and
## was dropped, and the MCP client then waited out its own 1800 s: every call of that server hung until the server was restarted.
##
## Held here, on the server's own scratch root for one request each (a `ping`, whose response goes to a file standing for the wire):
##   1. A LOCK WHOSE HOLDER IS GONE: the response is written within 12 s.
##   2. A LOCK WITH NO HOLDER RECORD (killed between taking it and recording): the response is written within 12 s.
##   3. CONTROL, A LIVE HOLDER: the lock is still honoured. No response is written while the holder lives, and it is written after the release.
## Red on the handler before the take-over: cases 1 and 2 write no response in 12 s, since the request drops it at 30 s.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents"
rigTools="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
[ -f "$rigTools" ] || { echo "⛔ ERROR: no tool script at $rigTools" >&2 ; exit 1 ; }
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsMcpWireLockStaleCheck.XXXXXX" )" || exit 1
rigFail(){ echo "⛔ FAIL: $1" >&2 ; exit 1 ; }

## The server this request answers through is this very shell, so its scratch root is the one the request builds for that pid.
rigServerPid=$$
rigScratch="$MMDAPP/.local/temp/agent-mcp.$rigServerPid"
mkdir -p "$rigScratch/inflight" || exit 1
rigLive=""
trap 'kill $rigLive 2> /dev/null ; rm -rf -- "$rigTmp" "$rigScratch"' EXIT

rigSeq=900100
rigRequest(){ ## wire file -- starts one ping request on the scratch root, its response goes to the wire file; sets rigReqPid
	rigSeq=$(( rigSeq + 1 ))
	printf '{"jsonrpc":"2.0","id":1,"method":"ping"}\n' | \
		env -u MDAT_SPAWN_SANDBOX_ROOT MMDAPP="$MMDAPP" MDLT_ORIGIN="${MDLT_ORIGIN}" MDAT_SPAWN_SESSION_ID="" \
		"$rigTools" --intern-mcp-request "$rigServerPid" "$rigSeq" 3> "$1" > /dev/null 2> "$rigTmp/ping.err" &
	rigReqPid=$!
	rigLive="$rigLive $rigReqPid"
}
rigAnswered(){ ## wire file, seconds -- 0 when the response frame is in the file within the seconds
	local waitLeft="$2"
	while [ "$waitLeft" -gt 0 ] ; do
		LC_ALL=C grep -q '"id":1' "$1" 2> /dev/null && return 0
		sleep 1
		waitLeft=$(( waitLeft - 1 ))
	done
	LC_ALL=C grep -q '"id":1' "$1" 2> /dev/null
}

## A process id that is gone: a child that has ended and been waited for.
sh -c 'exit 0' & rigGone=$! ; wait "$rigGone" 2> /dev/null || :

## 1. A lock whose recorded holder is gone.
mkdir "$rigScratch/wire.lock" || exit 1
printf '%s\n' "$rigGone" > "$rigScratch/wire.holder"
: > "$rigTmp/wire.one"
rigRequest "$rigTmp/wire.one"
rigAnswered "$rigTmp/wire.one" 12 || rigFail "a lock left by a holder that is gone kept the response back for 12 s: the request waits for it and drops the response"
wait "$rigReqPid" 2> /dev/null || :
rmdir "$rigScratch/wire.lock" 2> /dev/null || :

## 2. A lock with no holder record.
rm -f "$rigScratch/wire.holder"
mkdir "$rigScratch/wire.lock" || exit 1
: > "$rigTmp/wire.two"
rigRequest "$rigTmp/wire.two"
rigAnswered "$rigTmp/wire.two" 12 || rigFail "a lock with no holder record kept the response back for 12 s"
wait "$rigReqPid" 2> /dev/null || :
rmdir "$rigScratch/wire.lock" 2> /dev/null || :

## 3. The control: a holder that lives keeps the wire. It is released after 7 s, and no response is written before that.
sleep 8 & rigHolder=$!
rigLive="$rigLive $rigHolder"
mkdir "$rigScratch/wire.lock" || exit 1
printf '%s\n' "$rigHolder" > "$rigScratch/wire.holder"
: > "$rigTmp/wire.three"
rigRequest "$rigTmp/wire.three"
if rigAnswered "$rigTmp/wire.three" 5 ; then rigFail "the request took the wire from a holder that lives: the response was written while the lock was held"; fi
rmdir "$rigScratch/wire.lock" 2> /dev/null || :
rigAnswered "$rigTmp/wire.three" 12 || rigFail "after the live holder released, the response was not written within 12 s"
wait "$rigReqPid" 2> /dev/null || :

echo "PASS: a dead holder's lock and a lock with no record are taken over, and a live holder's lock is honoured"
exit 0
