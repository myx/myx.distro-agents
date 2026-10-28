#!/usr/bin/env bash
## One idle Wait costs one process a tick, and no more. An idle Wait reads its local sources
## once a second, and every read that starts a process of its own is load the machine pays
## with nothing arriving: on 2026-10-28 the owner's machine ran at a load average about 60
## with every team session idle.
## Held here:
##   1. THE TICK. One idle Wait over a file source, a short window and a longer one,
##      counted by a PATH shim that records every external command started under it: at most
##      2 processes to a poll round for the ticks the longer run adds. The rounds are counted
##      from the wait's own report, so a rig that never ran fails here instead of passing on
##      an empty count.
##   2. THE INSTRUMENT. The same shim counts the 5 date calls of a rig that makes exactly 5.
##      A counter that cannot see a fork it was put there to see is no counter at all.
##   3. A CALLER THAT IS GONE. A Wait started from a shell that then exits ends within 15
##      seconds with WAIT-RESULT: ERROR, instead of polling on for a result nobody reads.
## Red: on the code before the cut of 2026-10-28, section 1 counted 185 externals over 20
## rounds (8.8 a round); section 3's wait ran on past its caller, to its whole bound.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents"
rigTools="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigWaitInclude="$rigPackage/sh-lib/member/AgentsTools.MemberWait.include"
[ -f "$rigTools" ] || { echo "⛔ ERROR: no tool script at $rigTools" >&2 ; exit 1 ; }
[ -f "$rigWaitInclude" ] || { echo "⛔ ERROR: no Wait include at $rigWaitInclude" >&2 ; exit 1 ; }
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsIdleWaitForkCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigFail(){
	echo "⛔ FAIL: $1" >&2 ; exit 1
}

## The shim: every name the Wait include can start, which is an executable of this machine,
## answered by a wrapper that records the name and then runs the real one.
mkdir -p "$rigTmp/shim" || exit 1
LC_ALL=C awk '{ n = split( $0, w, /[^A-Za-z0-9_.-]+/ ) ; for ( i = 1 ; i <= n ; i++ ) if ( w[i] != "" ) print w[i] }' \
	"$rigWaitInclude" | sort -u > "$rigTmp/words.txt" || exit 1
rigShimmed=0
while read -r rigWord ; do
	case "$rigWord" in ''|-*|*[!a-z0-9_.-]*) continue ;; esac
	[ "$( type -t "$rigWord" )" = "file" ] || continue
	rigReal=""
	for rigDir in /bin /usr/bin /usr/sbin /sbin ; do
		[ -x "$rigDir/$rigWord" ] && { rigReal="$rigDir/$rigWord" ; break ; }
	done
	[ -n "$rigReal" ] || continue
	printf '#!/bin/bash\nprintf "%%s\\n" "${0##*/}" >> "$FORKLOG"\nexec %s "$@"\n' "$rigReal" > "$rigTmp/shim/$rigWord" || exit 1
	chmod +x "$rigTmp/shim/$rigWord" || exit 1
	rigShimmed=$(( rigShimmed + 1 ))
done < "$rigTmp/words.txt"
[ "$rigShimmed" -ge 5 ] || rigFail "the shim took only $rigShimmed commands: it would count almost nothing, so no count it gave could be trusted"

printf 'quiet\n' > "$rigTmp/quiet.txt" || exit 1

## SECTION 2 first: the counter is the instrument of section 1, and an instrument that cannot
## see a fork it was put there to see proves nothing. Five date calls, five lines.
: > "$rigTmp/ctl.forks"
(
	export FORKLOG="$rigTmp/ctl.forks" PATH="$rigTmp/shim:$PATH"
	rigN=0
	while [ "$rigN" -lt 5 ] ; do
		date +%s > /dev/null ; rigN=$(( rigN + 1 ))
	done
)
rigCtl="$( wc -l < "$rigTmp/ctl.forks" | tr -d ' ' )"
[ "$rigCtl" = "5" ] || rigFail "the shim counted $rigCtl of the 5 date calls a rig made: the count below would be short the same way"

## SECTION 1: one idle Wait, alone, over a file source. Twice, a short window and a long
## one: what the longer run costs beyond the shorter is the tick, with the processes a call
## pays for once at its start left out of it.
: > "$rigTmp/forks1"
FORKLOG="$rigTmp/forks1" PATH="$rigTmp/shim:$PATH" "$rigTools" --wait-for-input magic-developer \
	--wait-source "file:$rigTmp/quiet.txt" --wait-timeout 6 --wait-poll-interval 1 > "$rigTmp/wait1.out" 2> /dev/null
: > "$rigTmp/forks2"
FORKLOG="$rigTmp/forks2" PATH="$rigTmp/shim:$PATH" "$rigTools" --wait-for-input magic-developer \
	--wait-source "file:$rigTmp/quiet.txt" --wait-timeout 18 --wait-poll-interval 1 > "$rigTmp/wait2.out" 2> /dev/null
rigRounds1="$( sed -n 's/.*, \([0-9][0-9]*\) poll round(s).*/\1/p' "$rigTmp/wait1.out" | tail -1 )"
rigRounds2="$( sed -n 's/.*, \([0-9][0-9]*\) poll round(s).*/\1/p' "$rigTmp/wait2.out" | tail -1 )"
case "${rigRounds1:-x}${rigRounds2:-x}" in ''|*[!0-9]*) rigFail "a wait of section 1 reported no poll rounds, so nothing was measured: $( tail -1 "$rigTmp/wait2.out" )" ;; esac
rigTicks=$(( rigRounds2 - rigRounds1 ))
[ "$rigTicks" -ge 8 ] || rigFail "the two runs polled $rigRounds1 and $rigRounds2 rounds: too near each other to tell a tick from the start"
rigForks="$(( $( wc -l < "$rigTmp/forks2" ) - $( wc -l < "$rigTmp/forks1" ) ))"
[ "$rigForks" -le $(( rigTicks * 2 )) ] \
	|| rigFail "one idle Wait started $rigForks processes over $rigTicks further poll rounds (one a round is the nap alone, 2 is the bound): the tick is forking again"

## SECTION 3: a wait whose caller is gone ends, and says so.
: > "$rigTmp/orphan.out"
( "$rigTools" --wait-for-input magic-developer --wait-source "file:$rigTmp/quiet.txt" --wait-timeout 120 \
	> "$rigTmp/orphan.out" 2>&1 & echo $! > "$rigTmp/orphan.pid" )
rigOrphanPid="$( cat "$rigTmp/orphan.pid" 2> /dev/null || : )"
case "${rigOrphanPid:-x}" in ''|*[!0-9]*) rigFail "the wait of section 3 was not started, so its ending says nothing" ;; esac
rigWaited=0
while [ "$rigWaited" -lt 15 ] && kill -0 "$rigOrphanPid" 2> /dev/null ; do
	sleep 1 ; rigWaited=$(( rigWaited + 1 ))
done
if kill -0 "$rigOrphanPid" 2> /dev/null ; then
	kill -TERM "$rigOrphanPid" 2> /dev/null || :
	rigFail "a wait outlived the shell that started it by $rigWaited seconds and was still polling: nothing is waiting for its result"
fi
grep -q '^WAIT-RESULT: ERROR' "$rigTmp/orphan.out" \
	|| rigFail "the wait of section 3 ended without WAIT-RESULT: ERROR: $( tail -2 "$rigTmp/orphan.out" )"

echo "PASS: one idle Wait, $rigForks processes over $rigTicks further rounds, and a wait whose caller is gone ends in $rigWaited s"
exit 0
