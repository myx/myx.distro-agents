#!/usr/bin/env bash
## A Wait over a directory costs no process a poll round. A directory source is read once a tick, and the
## inbox and board sources are directories too, so a process a tick there is paid by every idle member on
## every tick. The probe read the listing through `ls`, which forked once a round.
##
## Held here, over one directory source on a quiet wait:
##   1. THE CONTROL. Five `ls` calls through the same counter record five lines, so a counter that could
##      not see a call would fail here rather than report a clean result below.
##   2. THE TICK. A wait of 6 s and one of 24 s start as many `ls` calls. The rounds are counted from
##      the wait's own report, so a rig that never waited fails here instead of passing on no rounds.
##      A listing read through a process would grow with the rounds, eight or more apart.
##   3. THE ARRIVAL. A file written into the directory while the wait runs wakes it: the listing is
##      still read, and a listing that never changed would not be.
## Red on the probe before the cut: 1 `ls` a round, 15 over 15 further rounds.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents"
rigTools="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
[ -f "$rigTools" ] || { echo "⛔ ERROR: no tool script at $rigTools" >&2 ; exit 1 ; }
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsWaitDirProbeCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigFail(){ echo "⛔ FAIL: $1" >&2 ; exit 1 ; }

## The counter: `ls`, as a shell function exported to the wait, so the count costs no fork of its own.
rigCount="$rigTmp/ls.log"
: > "$rigCount" || exit 1
ls(){ printf 'ls\n' >> "$RIG_COUNT" ; command ls "$@" ; }
export -f ls
export RIG_COUNT="$rigCount"

mkdir -p "$rigTmp/quiet" || exit 1
printf 'settled\n' > "$rigTmp/quiet/item-one" || exit 1

## 1. The control.
( ls "$rigTmp/quiet" > /dev/null ; ls "$rigTmp/quiet" > /dev/null ; ls "$rigTmp/quiet" > /dev/null ; ls "$rigTmp/quiet" > /dev/null ; ls "$rigTmp/quiet" > /dev/null )
rigCtl="$( LC_ALL=C grep -c '^ls$' "$rigCount" || : )"
[ "$rigCtl" = "5" ] || rigFail "the counter recorded $rigCtl of the 5 ls calls a rig made: a count below would be short the same way"

## 2. The tick: a short wait and a longer one, and what the longer one adds.
rigWait(){ ## seconds, output file
	: > "$rigCount"
	"$rigTools" --wait-for-input --team-member magic-developer \
		--wait-source "file:$rigTmp/quiet" --wait-timeout "$1" --wait-poll-interval 1 > "$2" 2> /dev/null
}
rigWait 6 "$rigTmp/short.out"
rigLsShort="$( LC_ALL=C grep -c '^ls$' "$rigCount" || : )"
rigWait 24 "$rigTmp/long.out"
rigLsLong="$( LC_ALL=C grep -c '^ls$' "$rigCount" || : )"
rigRounds1="$( LC_ALL=C sed -n 's/.*, \([0-9][0-9]*\) poll round(s).*/\1/p' "$rigTmp/short.out" | tail -1 )"
rigRounds2="$( LC_ALL=C sed -n 's/.*, \([0-9][0-9]*\) poll round(s).*/\1/p' "$rigTmp/long.out" | tail -1 )"
case "${rigRounds1:-x}${rigRounds2:-x}" in ''|*[!0-9]*) rigFail "a wait reported no poll rounds, so nothing was measured: $( tail -1 "$rigTmp/long.out" )" ;; esac
rigMore=$(( rigRounds2 - rigRounds1 ))
[ "$rigMore" -ge 8 ] || rigFail "the two waits polled $rigRounds1 and $rigRounds2 rounds: too near each other to tell a tick from a start"
rigGrew=$(( rigLsLong - rigLsShort ))
[ "$rigGrew" -le 1 ] \
	|| rigFail "a directory source started $rigGrew ls call(s) over $rigMore further rounds: the listing is read through a process again"

## 3. The arrival: a file written while the wait runs wakes it.
: > "$rigTmp/arrival.out"
"$rigTools" --wait-for-input --team-member magic-developer \
	--wait-source "file:$rigTmp/quiet" --wait-timeout 30 --wait-poll-interval 1 > "$rigTmp/arrival.out" 2> /dev/null &
rigWaitPid=$!
rigLeft=100
while [ "$rigLeft" -gt 0 ] && ! LC_ALL=C grep -q 'poll round' "$rigTmp/arrival.out" ; do sleep 0.1 ; rigLeft=$(( rigLeft - 1 )) ; done
sleep 1
printf 'arrived\n' > "$rigTmp/quiet/item-two" || exit 1
rigLeft=300
while [ "$rigLeft" -gt 0 ] && kill -0 "$rigWaitPid" 2> /dev/null ; do sleep 0.1 ; rigLeft=$(( rigLeft - 1 )) ; done
kill -TERM "$rigWaitPid" 2> /dev/null || :
wait "$rigWaitPid" 2> /dev/null || :
LC_ALL=C grep -q '^WAIT-RESULT: RECEIVED' "$rigTmp/arrival.out" \
	|| rigFail "a file written into the directory did not wake the wait, so its listing is no longer read: $( tail -2 "$rigTmp/arrival.out" )"

echo "PASS: a directory source started $rigGrew ls call(s) over $rigMore further rounds, and an arrival still woke the wait"
exit 0
