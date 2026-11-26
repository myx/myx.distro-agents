#!/usr/bin/env bash
## A served tool call that waits for the wire lock starts almost no process while it waits. The wire is
## one pipe held for the length of one response. A request that found it held retried `mkdir` as fast as
## the machine allowed and slept a second between storms: 140 `mkdir` calls in 4 s, measured on
## 2026-11-25, so a server under load spent its machine on waiting for a lock given back in milliseconds.
##
## Held here, on the server's own scratch root for one request:
##   1. THE CONTROL. Five `mkdir` calls through the same counters record five lines, so a counter that
##      could not see a call would fail here rather than report a clean result below.
##   2. THE WAIT. A `ping` request whose wire lock is held for 4 s calls `mkdir` at most 40 times. The
##      request waits on the server's fifo and the release wakes it, so the storm is gone.
##      Red on the handler before the cut: 140 `mkdir` calls for the same 4 s.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents"
rigTools="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
[ -f "$rigTools" ] || { echo "⛔ ERROR: no tool script at $rigTools" >&2 ; exit 1 ; }
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsMcpSpinForkCheck.XXXXXX" )" || exit 1
rigFail(){ echo "⛔ FAIL: $1" >&2 ; exit 1 ; }

## The server this request answers through is this very shell, so its scratch root is the one the
## request builds for that pid. The rig gives the request no session sandbox, so the root is under the
## workspace's own .local/temp.
rigServerPid=$$
rigScratch="$MMDAPP/.local/temp/agent-mcp.$rigServerPid"
mkdir -p "$rigScratch/inflight" || exit 1
trap 'rm -rf -- "$rigTmp" "$rigScratch"' EXIT

## The counters: the two calls a spin is made of, as shell functions exported to the request, so the
## count costs no fork and the request's own command path is unchanged.
rigCount="$rigTmp/count.log"
: > "$rigCount" || exit 1
mkdir(){ printf 'mkdir\n' >> "$RIG_COUNT" ; command mkdir "$@" ; }
sleep(){ printf 'sleep %s\n' "${1:-}" >> "$RIG_COUNT" ; command sleep "$@" ; }
export -f mkdir sleep
export RIG_COUNT="$rigCount"

## 1. The control, before the count below is believed.
( mkdir "$rigTmp/ctl-one" ; mkdir "$rigTmp/ctl-two" ; mkdir "$rigTmp/ctl-three" ; mkdir "$rigTmp/ctl-four" ; mkdir "$rigTmp/ctl-five" )
rigCtl="$( LC_ALL=C grep -c '^mkdir$' "$rigCount" || : )"
[ "$rigCtl" = "5" ] || rigFail "the counter recorded $rigCtl of the 5 mkdir calls a rig made: a count below would be short the same way"

## 2. The wait. The wire lock is held for 4 s, longer than a request's own start, and the request
## releases nothing of itself, so every call it records while it waits is one it pays to wait.
: > "$rigCount"
mkdir "$rigScratch/wire.lock" || exit 1
( sleep 4 ; rmdir "$rigScratch/wire.lock" 2> /dev/null || : ) &
rigReleasePid=$!
## The holder is the process that releases the lock, recorded as a live holder is, so the request waits on it and takes nothing over.
printf '%s\n' "$rigReleasePid" > "$rigScratch/wire.holder"
printf '{"jsonrpc":"2.0","id":1,"method":"ping"}\n' | \
	env -u MDAT_SPAWN_SANDBOX_ROOT MMDAPP="$MMDAPP" MDLT_ORIGIN="${MDLT_ORIGIN}" MDAT_SPAWN_SESSION_ID="" \
	"$rigTools" --intern-mcp-request "$rigServerPid" 900041 3> /dev/null > /dev/null 2> "$rigTmp/ping.err"
wait "$rigReleasePid" 2> /dev/null || :
rmdir "$rigScratch/wire.lock" 2> /dev/null || :
rigMkdirs="$( LC_ALL=C grep -c '^mkdir$' "$rigCount" || : )"
rigSleeps="$( LC_ALL=C grep -c '^sleep' "$rigCount" || : )"
[ "$rigMkdirs" -le 40 ] \
	|| rigFail "one request paid $rigMkdirs mkdir call(s) and $rigSleeps sleep call(s) to wait 4 s for the wire lock: the retry storm is still there, and the request waits on its fifo instead"

echo "PASS: one request waited 4 s for the wire lock with $rigMkdirs mkdir call(s) and $rigSleeps sleep call(s)"
exit 0
