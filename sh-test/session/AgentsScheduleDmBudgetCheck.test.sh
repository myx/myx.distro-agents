#!/usr/bin/env bash
## Behavioural check on the clock bound of the work-duty DM look (`AgentsToolsScheduleDmTags`, sh-lib/session/AgentsTools.DispatcherSchedule.include).
## A pass under load spent 35 minutes in the look before it reached its start (MEL, 2026-11-09): every roster and every read is a Slack call. Held:
##   1. UNDER THE BOUND every member is looked at, stamped, and given a floor; no line is printed.
##   2. OVER THE BOUND the members not reached wait: unstamped, no floor, and one `dms:` line names them.
##   3. A MEMBER CUT MID-ROSTER keeps its floor and loses its stamp, so the next pass reads all of it again; the conversations before the cut were read.
##   4. A FORCED LOOK (the per-member sync) has no bound: every conversation is read, however long.
##   5. BOUND 0 is no bound.
## Offline: the console is a stand-in whose roster is two conversations a member and whose read sleeps one second, so the clock is real and the Slack is none.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-lib/session/AgentsTools.DispatcherSchedule.include" ] || rigRefuse "the schedule's include is not in the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsScheduleDmBudgetCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
mkdir -p "$rigTmp/.local/agents/schedule" || exit 1

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 )) ; printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}

## One look, in a child shell: the include is sourced with the console, the tracking drop and the tag note as stand-ins. Prints the look's
## own output, then `reads=<n>` (the reads the stand-in served), then for each member `stamp:<member>=<yes|no> floor:<member>=<value|->`.
rigLook(){ ## budget, force, members within flags...
	local lookBudget="$1" lookForce="$2" ; shift 2
	rm -rf "$rigTmp/.local/agents/schedule/dms" "$rigTmp/.local/agents/schedule/dm-looked" "$rigTmp/reads"
	env -i PATH="/usr/bin:/bin:/usr/sbin:/sbin" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SCHEDULE_DM_BUDGET_SECONDS="$lookBudget" RIG_TMP="$rigTmp" RIG_FORCE="$lookForce" RIG_MEMBERS="$*" bash -c '
		MMDAPP="$RIG_TMP" ; export MMDAPP
		set +e +u
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.DispatcherSchedule.include" > /dev/null 2>&1
		## The include defines every helper the look calls, so the stand-ins go in AFTER it is sourced, never before.
		AgentsToolsTrackingDrop(){ cat ; }
		AgentsToolsScheduleTagNote(){ : ; }
		AgentsToolsSessionChatMemberId(){ printf "URIG%s\n" "$1" ; }
		DistroAgentsTools(){
			case "$1" in
				--slack-conversations-roster) printf "CONV|identity=user|id=D%s1|kind=im\nCONV|identity=user|id=D%s2|kind=im\n" "$3" "$3" ;;
				--intern-op-comms-slack-read) sleep 1 ; printf "%s\n" "1794237000.000100 | UPERSON | hello $2" ; echo r >> "$RIG_TMP/reads" ;;
			esac
			return 0
		}
		agentsSchedulePassNow=1794236000
		AgentsToolsScheduleDmTags "$RIG_MEMBERS" "" "$RIG_FORCE"
		printf "reads=%s\n" "$( wc -l < "$RIG_TMP/reads" 2> /dev/null | tr -d " " )"
		for m in $RIG_MEMBERS ; do
			if [ -f "$RIG_TMP/.local/agents/schedule/dm-looked/$m" ] ; then s=yes ; else s=no ; fi
			if [ -f "$RIG_TMP/.local/agents/schedule/dms/$m" ] ; then f="$( cat "$RIG_TMP/.local/agents/schedule/dms/$m" )" ; else f="-" ; fi
			printf "stamp:%s=%s floor:%s=%s\n" "$m" "$s" "$m" "$f"
		done
	' 2>&1
}

## 1. Under the bound: three members, six reads of a second each, bound 60.
rigOut="$( rigLook 60 no rig-a rig-b rig-c )"
rigAssert "under the bound every conversation is read" "$( printf '%s\n' "$rigOut" | grep -c '^reads=6$' )" "1"
rigAssert "under the bound every member is stamped and has its floor" "$( printf '%s\n' "$rigOut" | grep -c 'stamp:rig-[abc]=yes floor:rig-[abc]=1794237000.000100' )" "3"
rigAssert "under the bound no dms: line is printed" "$( printf '%s\n' "$rigOut" | grep -c '^dms:' )" "0"

## 2 and 3. Over the bound: bound 1, the first member's first read spends it; its second conversation is cut, the two members after it wait.
rigOut="$( rigLook 1 no rig-a rig-b rig-c )"
rigAssert "over the bound the reads stop at the cut: one read served" "$( printf '%s\n' "$rigOut" | grep -c '^reads=1$' )" "1"
rigAssert "the member cut mid-roster loses its stamp and keeps no floor" "$( printf '%s\n' "$rigOut" | grep -c 'stamp:rig-a=no floor:rig-a=-' )" "1"
rigAssert "the members not reached are unstamped with no floor" "$( printf '%s\n' "$rigOut" | grep -c 'stamp:rig-[bc]=no floor:rig-[bc]=-' )" "2"
rigAssert "one dms: line names the three that wait" "$( printf '%s\n' "$rigOut" | grep -c '^dms: the look took [0-9]*s, over its 1s bound: the DMs of rig-a rig-b rig-c wait for the next pass$' )" "1"

## 4. A forced look has no bound: bound 1, force yes, every read served.
rigOut="$( rigLook 1 yes rig-a rig-b )"
rigAssert "a forced look reads every conversation whatever the bound" "$( printf '%s\n' "$rigOut" | grep -c '^reads=4$' )" "1"
rigAssert "a forced look prints no dms: line" "$( printf '%s\n' "$rigOut" | grep -c '^dms:' )" "0"

## 5. Bound 0 is no bound.
rigOut="$( rigLook 0 no rig-a rig-b )"
rigAssert "bound 0 reads every conversation" "$( printf '%s\n' "$rigOut" | grep -c '^reads=4$' )" "1"

printf '%s: %s passed, %s failed\n' "${0##*/}" "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" = 0 ]
