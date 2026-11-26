#!/usr/bin/env bash
## A run that waits its turn in the machine's line looks at the line on a long tick, and is woken the
## moment the line moves. The line's waiters used to fork a `sleep` at every pass, one process a pass a
## waiter, and the pass was short enough that a machine with a full line kept every core busy sleeping.
##
## Held here, on a rig machine of its own (a HOME whose suite-queue is the line and suite-lanes holds
## one lane, and a workspace holding one copy of this package with one held test in it):
##   1. THE POLLING BOUND. One run stands in the line behind a held run, and the beats of its ticket
##      are read for a window that spans at least two passes. Consecutive beats are at least 15 s
##      apart: the tick of a waiter, and no shortcut back to the 5 s pass it replaced. The passes are
##      counted from the beats, so a run that never waited fails here rather than passing on an empty
##      window.
##   2. THE WAKE. The held run is let go, and the waiting run starts within 5 s: the tick is only the
##      fallback, and the line itself wakes its waiters. A tick that is long and a wake that is missing
##      would be a slower suite, not a lighter machine.
## Red on the runner before the cut: beats 8 s apart with one run ahead, and the waiting run began on
## its own timer, so the wake of section 2 had nothing to measure.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents"
rigRunner="$rigPackage/sh-test/AgentsRunTests.sh"
[ -f "$rigRunner" ] || { echo "⛔ ERROR: no runner at $rigRunner" >&2 ; exit 1 ; }
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsRunQueuePollCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigFail(){ echo "⛔ FAIL: $1" >&2 ; exit 1 ; }

rigHome="$rigTmp/home" ; rigWs="$rigTmp/ws"
rigQueue="$rigHome/.agents/magic-team/suite-queue"
rigLanes="$rigHome/.agents/magic-team/suite-lanes"
mkdir -p "$rigHome" "$rigWs/.local/temp" "$rigQueue" "$rigLanes" || exit 1
printf '1\n' > "$rigLanes/count" || exit 1
printf '1\n' > "$rigLanes/max" || exit 1

## One copy of the package with one test that is held until the rig lets it go, and one plain test
## the waiting run is named for.
rigCopy="$rigWs/.local/temp/rig-copy/source"
mkdir -p "$rigCopy/myx/myx.distro-agents/sh-test/runner" "$rigCopy/myx/myx.distro-agents/sh-test/check-fixtures" || exit 1
cp "$rigRunner" "$rigCopy/myx/myx.distro-agents/sh-test/AgentsRunTests.sh" || exit 1
cp "$rigPackage/sh-test/runner"/*.sh "$rigCopy/myx/myx.distro-agents/sh-test/runner/" || exit 1
cp "$rigPackage/sh-test/check-fixtures"/runner-*.py "$rigCopy/myx/myx.distro-agents/sh-test/check-fixtures/" || exit 1
cat > "$rigCopy/myx/myx.distro-agents/sh-test/RigHeld.test.sh" <<'RIGHELD'
#!/usr/bin/env bash
printf 'BEGIN held\n' >> "$RIG_SHARED/log"
rigLeft=600
while [ ! -e "$RIG_SHARED/let.held" ] && [ "$rigLeft" -gt 0 ] ; do sleep 0.2 ; rigLeft=$(( rigLeft - 1 )) ; done
printf 'END held\n' >> "$RIG_SHARED/log"
echo "RIG_HELD: OK"
RIGHELD
cat > "$rigCopy/myx/myx.distro-agents/sh-test/RigPlain.test.sh" <<'RIGPLAIN'
#!/usr/bin/env bash
printf 'BEGIN plain\n' >> "$RIG_SHARED/log"
echo "RIG_PLAIN: OK"
RIGPLAIN
chmod +x "$rigCopy/myx/myx.distro-agents/sh-test/RigHeld.test.sh" "$rigCopy/myx/myx.distro-agents/sh-test/RigPlain.test.sh" || exit 1

: > "$rigTmp/log" || exit 1
rigRun(){ ## session, test name -- that run in the background, its output in <session>.out
	( cd "$rigWs" && exec env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$rigCopy" MYXROOT="${MYXROOT:-}" \
		RIG_SHARED="$rigTmp" MDAT_SPAWN_SESSION_ID="rig-session-$1" MDAT_SUITE_QUEUE_LIMIT=300 \
		bash "$rigCopy/myx/myx.distro-agents/sh-test/AgentsRunTests.sh" --wait "$2" ) > "$rigTmp/$1.out" 2>&1 &
	rigLast=$!
}
rigUntil(){ ## fixed text, file, seconds -- rc 1 when the text never appears
	local untilLeft=$(( ${3:-60} * 5 ))
	while ! LC_ALL=C grep -q -F -- "$1" "$2" 2> /dev/null ; do
		[ "$untilLeft" -gt 0 ] || return 1
		sleep 0.2 ; untilLeft=$(( untilLeft - 1 ))
	done
}
rigTicket(){ ## session -- that session's ticket file in the line
	LC_ALL=C grep -l -x "session=rig-session-$1" "$rigQueue"/*.ticket 2> /dev/null | LC_ALL=C sed -n 1p
}

## The held run takes the one lane, and the plain run stands behind it.
rigRun a RigHeld
rigUntil 'BEGIN held' "$rigTmp/log" 90 || rigFail "the held run never began, so no run would wait and nothing below would be measured"
rigRun b RigPlain
rigUntil 'waits its turn behind' "$rigTmp/a.out" 60 || :
rigUntil 'waits its turn behind' "$rigTmp/b.out" 90 || rigFail "the second run never said it waits its turn: $( tail -3 "$rigTmp/b.out" )"
rigB="$( rigTicket b )"
[ -n "$rigB" ] || rigFail "the waiting run wrote no ticket, so its own beats could not be read"

## SECTION 1: the beats of the waiting run over 34 s. Each pass writes the pass's second over the one
## before, so the passes are the distinct values in that window.
rigSeen=""
rigLeft=170
while [ "$rigLeft" -gt 0 ] ; do
	rigBeat="$( LC_ALL=C sed -n 1p "$rigB.beat" 2> /dev/null || : )"
	case " $rigSeen " in
		*" ${rigBeat:-none} "*) ;;
		*) rigSeen="$rigSeen ${rigBeat:-none}" ;;
	esac
	sleep 0.2 ; rigLeft=$(( rigLeft - 1 ))
done
rigPasses=0 ; rigGapMin="" ; rigPrev=""
for rigBeat in $rigSeen ; do
	case "$rigBeat" in ''|*[!0123456789]*) continue ;; esac
	rigPasses=$(( rigPasses + 1 ))
	if [ -n "$rigPrev" ] ; then
		rigGap=$(( rigBeat - rigPrev ))
		if [ -z "$rigGapMin" ] || [ "$rigGap" -lt "$rigGapMin" ] ; then rigGapMin="$rigGap" ; fi
	fi
	rigPrev="$rigBeat"
done
[ "$rigPasses" -ge 2 ] || rigFail "the waiting run wrote $rigPasses pass(es) in 34 s, so the tick was never measured: $( tail -3 "$rigTmp/b.out" )"
[ "$rigGapMin" -ge 15 ] || rigFail "two passes of a waiting run came $rigGapMin s apart over $rigPasses passes in 34 s, and a waiter's tick is at least 15 s: it is still passing as fast as the 5 s pass this replaced"

## SECTION 2: the wake. The held run is let go, and the one behind it must start on the poke, not on
## its own tick, which may be up to 60 s off.
rigLetAt="$( date +%s )"
: > "$rigTmp/let.held"
rigUntil 'BEGIN plain' "$rigTmp/log" 5 || rigFail "the waiting run did not begin within 5 s of the line moving: its tick is the only thing that wakes it, and the wake the line should give it is gone"
rigWake=$(( $( date +%s ) - rigLetAt ))
wait "$rigLast" 2> /dev/null || :

echo "PASS: a waiting run's passes came ${rigGapMin}s apart over ${rigPasses} pass(es) in 34 s, and it began ${rigWake}s after the line moved"
exit 0
