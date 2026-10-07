#!/usr/bin/env bash
## Behavioural check on `--recheck-in <minutes>[±<jitter-minutes>]` on the board move/create
## ops: recheck-date is written as `YYYY-MM-DD HH:MM +0000`, now + minutes, within the jitter
## bounds; a --header:* naming recheck-date in the same call wins; a call without the option
## leaves recheck-date as it was; a malformed value is refused and moves nothing. Offline:
## plain board-file moves in a temp data root.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigIsoToEpoch="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsIsoToEpoch.awk"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
[ -f "$rigIsoToEpoch" ] || rigRefuse "awk not found: $rigIsoToEpoch"
rigTmp="$( mktemp -d -t AgentsBoardRecheckInCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data"
mkdir -p "$rigTmp/ws" "$rigData/board/backlog" "$rigData/board/pending" "$rigData/board/running" "$rigData/board/blocked" "$rigData/board/parked"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigOp(){ ## result file, extra DistroAgentsTools.fn.sh arguments... (stdin passes through)
	local opOut="$1" ; shift
	env -i HOME="$rigTmp" PATH="/usr/bin:/bin" MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$opOut" 2>&1
	printf '%s' "$?" > "$opOut.rc"
}
rigItem(){ ## state, item filename, extra frontmatter lines
	printf -- '---\ntype: task\nowner: rig\n%s---\n\nrig item\n' "$3" > "$rigData/board/$1/$2"
}
rigField(){ ## state, item filename, field -- every value of that frontmatter field, one per line
	LC_ALL=C sed -n "s/^$3: //p" "$rigData/board/$1/$2" 2>/dev/null
}
rigShape(){ ## value -- "ok" when it is YYYY-MM-DD HH:MM +0000
	printf '%s\n' "$1" | LC_ALL=C grep -Eqx '[0-9]{4}-[0-9]{2}-[0-9]{2} [0-2][0-9]:[0-5][0-9] \+0000' && echo ok || echo "bad: $1"
}
rigWithin(){ ## value, before-call epoch, after-call epoch, min minutes, max minutes -- "ok" when inside
	local e
	e="$( printf '%s\n' "$1" | LC_ALL=C awk -f "$rigIsoToEpoch" )" || { echo "unparsed: $1" ; return ; }
	## The stamp is truncated to the minute, hence the 60 s allowance below.
	if [ "$e" -ge $(( $2 + $4 * 60 - 60 )) ] && [ "$e" -le $(( $3 + $5 * 60 )) ] ; then echo ok ; else echo "out of bounds: $1" ; fi
}

echo "-- AgentsToolsRecheckDate: the lock ops' former inline calculation, unchanged --"
rigHelper(){ ## spec -- the helper's output, or its rc
	MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.RecheckDate.include" && AgentsToolsRecheckDate "$1" || echo "rc=$?"' rig "$1"
}
rigInline(){ ## minutes -- the calculation the lock ops carried inline before the helper
	local targetEpoch recheckDay recheckRem
	targetEpoch=$(( $( date +%s ) + $1 * 60 ))
	recheckDay="$( printf '%s\n' "$targetEpoch" | LC_ALL=C awk -f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsEpochToIsoDate.awk" )"
	recheckRem=$(( targetEpoch % 86400 ))
	printf '%s %02d:%02d +0000' "$recheckDay" "$(( recheckRem / 3600 ))" "$(( recheckRem % 3600 / 60 ))"
}
for m in 10 15 30 ; do
	a="$( rigInline "$m" )" ; h="$( rigHelper "$m" )" ; b="$( rigInline "$m" )"
	rigAssert "helper $m equals the inline value"  "$( [ "$h" = "$a" ] || [ "$h" = "$b" ] && echo same || echo "$h vs $a" )" same
done
rigAssert "helper refuses a malformed value"    "$( rigHelper 'x±1' )" "rc=2"

echo "-- --recheck-in 17 on a move: format and offset --"
rigItem blocked task-rig-plain.md ''
t0="$( date +%s )"
rigOp "$rigTmp/o1" --magic-board-to-parked magic-coordinator task-rig-plain.md --from-state:blocked --recheck-in 17
t1="$( date +%s )"
rigAssert "the move succeeds"                   "$( cat "$rigTmp/o1.rc" )" 0
v="$( rigField parked task-rig-plain.md recheck-date )"
rigAssert "one recheck-date is written"         "$( printf '%s\n' "$v" | grep -c . )" 1
rigAssert "it is YYYY-MM-DD HH:MM +0000"        "$( rigShape "$v" )" ok
rigAssert "it is now + 17 min"                  "$( rigWithin "$v" "$t0" "$t1" 17 17 )" ok

echo "-- --recheck-in 7±2: every value within now + 5..9 min --"
rigItem parked task-rig-jitter.md ''
t0="$( date +%s )"
rigBad="" rigSeen=""
for n in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 ; do
	rigOp "$rigTmp/o2" --magic-board-to-parked magic-coordinator task-rig-jitter.md --from-state:parked --recheck-in '7±2'
	[ "$( cat "$rigTmp/o2.rc" )" = 0 ] || rigBad="$rigBad rc=$( cat "$rigTmp/o2.rc" )"
	v="$( rigField parked task-rig-jitter.md recheck-date )"
	[ "$( rigShape "$v" )" = ok ] || rigBad="$rigBad shape:$v"
	[ "$( rigWithin "$v" "$t0" "$( date +%s )" 5 9 )" = ok ] || rigBad="$rigBad bounds:$v"
	case " $rigSeen " in *" ${v// /_} "*) ;; *) rigSeen="$rigSeen ${v// /_}" ;; esac
done
rigAssert "20 jittered moves all in bounds"     "${rigBad:-none}" none
rigAssert "jitter spreads the values"           "$( [ "$( printf '%s\n' $rigSeen | grep -c . )" -gt 1 ] && echo yes || echo no )" yes

echo "-- an explicit recheck-date header in the same call wins, in either order --"
rigItem blocked task-rig-explicit-a.md ''
rigOp "$rigTmp/o3" --magic-board-to-parked magic-coordinator task-rig-explicit-a.md --from-state:blocked \
	--recheck-in 17 '--header:upsert:recheck-date:2030-01-01 00:00 +0000'
rigAssert "the move succeeds"                   "$( cat "$rigTmp/o3.rc" )" 0
rigAssert "header after: the header's value"    "$( rigField parked task-rig-explicit-a.md recheck-date )" "2030-01-01 00:00 +0000"
rigItem blocked task-rig-explicit-b.md ''
rigOp "$rigTmp/o4" --magic-board-to-parked magic-coordinator task-rig-explicit-b.md --from-state:blocked \
	'--header:upsert:recheck-date:2030-01-01 00:00 +0000' --recheck-in 17
rigAssert "header before: the header's value"   "$( rigField parked task-rig-explicit-b.md recheck-date )" "2030-01-01 00:00 +0000"
rigItem blocked task-rig-explicit-c.md $'recheck-date: 2001-01-01 00:00 +0000\n'
rigOp "$rigTmp/o5" --magic-board-to-parked magic-coordinator task-rig-explicit-c.md --from-state:blocked \
	--recheck-in 17 --header:remove:recheck-date
rigAssert "a remove header wins too"            "$( rigField parked task-rig-explicit-c.md recheck-date | grep -c . )" 0

echo "-- without --recheck-in, recheck-date is untouched --"
rigItem blocked task-rig-kept.md $'recheck-date: 2001-01-01 00:00 +0000\n'
rigOp "$rigTmp/o6" --magic-board-to-parked magic-coordinator task-rig-kept.md --from-state:blocked
rigAssert "the move succeeds"                   "$( cat "$rigTmp/o6.rc" )" 0
rigAssert "the old value stays"                 "$( rigField parked task-rig-kept.md recheck-date )" "2001-01-01 00:00 +0000"
rigItem blocked task-rig-none.md ''
rigOp "$rigTmp/o7" --magic-board-to-parked magic-coordinator task-rig-none.md --from-state:blocked
rigAssert "none is added"                       "$( rigField parked task-rig-none.md recheck-date | grep -c . )" 0

echo "-- a malformed value is refused and moves nothing --"
for bad in abc '17±' '±2' '17±2±1' '-5' '' ; do
	rigItem blocked task-rig-bad.md ''
	rigOp "$rigTmp/o8" --magic-board-to-parked magic-coordinator task-rig-bad.md --from-state:blocked --recheck-in "$bad"
	rigAssert "'$bad' is refused, item stays"   "$( cat "$rigTmp/o8.rc" ):$( [ -f "$rigData/board/blocked/task-rig-bad.md" ] && echo stays || echo moved )" 1:stays
	rm -f "$rigData/board/parked/task-rig-bad.md"
done
rigItem blocked task-rig-missing.md ''
rigOp "$rigTmp/o9" --magic-board-to-parked magic-coordinator task-rig-missing.md --from-state:blocked --recheck-in
rigAssert "a missing value is refused"          "$( cat "$rigTmp/o9.rc" ):$( [ -f "$rigData/board/blocked/task-rig-missing.md" ] && echo stays || echo moved )" 1:stays

echo "-- the grooming, advance and create families take it too --"
rigItem pending task-rig-groom.md ''
t0="$( date +%s )"
rigOp "$rigTmp/g1" --magic-grooming-to-blocked magic-coordinator task-rig-groom.md --from-state:pending --owner-header-value rig --recheck-in 17
rigAssert "--magic-grooming-to-blocked"         "$( cat "$rigTmp/g1.rc" ):$( rigWithin "$( rigField blocked task-rig-groom.md recheck-date )" "$t0" "$( date +%s )" 17 17 )" 0:ok
rigItem pending task-rig-adv.md ''
t0="$( date +%s )"
rigOp "$rigTmp/g2" --magic-advance-to-running magic-coordinator task-rig-adv.md --from-state:pending --recheck-in '7±2'
rigAssert "--magic-advance-to-running"          "$( cat "$rigTmp/g2.rc" ):$( rigWithin "$( rigField running task-rig-adv.md recheck-date )" "$t0" "$( date +%s )" 5 9 )" 0:ok
t0="$( date +%s )"
printf -- '---\nowner: rig\n---\n\nrig item\n' | rigOp "$rigTmp/g3" --magic-grooming-create-backlog magic-coordinator task-20261007T1200Z-rig-create.md --owner-header-value rig --upsert-from-stdin --recheck-in 17
rigAssert "--magic-grooming-create-backlog"     "$( cat "$rigTmp/g3.rc" ):$( rigWithin "$( rigField backlog task-20261007T1200Z-rig-create.md recheck-date )" "$t0" "$( date +%s )" 17 17 )" 0:ok

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ BOARD RECHECK-IN CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'BOARD_RECHECK_IN: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
