#!/usr/bin/env bash
## Behavioural check on the clock bound of the work-duty DM look (`AgentsToolsScheduleDmTags`, sh-lib/schedule/AgentsTools.DispatcherSchedule.include).
## A pass under load spent 35 minutes in the look before it reached its start (MEL, 2026-11-09): every roster and every read is a Slack call. Held:
##   1. UNDER THE BOUND every member is looked at, stamped, and given a floor; no line is printed.
##   2. OVER THE BOUND no read starts: the members whose reads did not start wait, unstamped, no floor, and one `dms:` line names them.
##   3. A MEMBER CUT MID-ROSTER keeps its floor and loses its stamp, so the next pass reads all of it again; the reads that started before the cut finished.
##   4. A FORCED LOOK (the per-member sync) has no bound: every conversation is read, however long.
##   5. BOUND 0 is no bound.
##   6. The team bot's DM is the coordinator's, and it is read once a pass for every member whose roster lists it.
##   7. THE READS RUN TOGETHER, never more than MDAT_SCHEDULE_DM_PARALLEL (4) at once, so the look takes the time of its slowest batch, not of every read.
##   8. THE ROSTER IS KEPT an hour: a second look calls none, a forced look reads it again.
##   9. A LOOK WITH NO MEMBER DUE reads nothing and prints nothing.
##  10. A ROSTER PAST ITS HOUR is used as it stands, so the look reads every conversation at once, and it is read again beside the look.
## Offline: the console is a stand-in whose roster is two conversations a member (RIG_CONVS) and whose read sleeps one second (RIG_SLEEP), so the clock
## is real and the Slack is none.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-lib/schedule/AgentsTools.DispatcherSchedule.include" ] || rigRefuse "the schedule's include is not in the package"
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
## With RIG_BOT=yes the roster is the team bot's one DM, whose read holds a message tagging rig-b and a later one tagging nobody; the tag
## note then prints `note:<member>=<ts>`.
rigLook(){ ## budget, force, members within flags...
	local lookBudget="$1" lookForce="$2" ; shift 2
	rm -rf "$rigTmp/reads" "$rigTmp/notes" "$rigTmp/rosters" "$rigTmp/inflight" "$rigTmp/most"
	[ "${RIG_KEEP_LOOKED:-}" = yes ] || rm -rf "$rigTmp/.local/agents/schedule/dms" "$rigTmp/.local/agents/schedule/dm-looked"
	[ "${RIG_KEEP_ROSTER:-}" = yes ] || rm -rf "$rigTmp/.local/agents/schedule/dm-roster"
	mkdir -p "$rigTmp/inflight"
	env -i PATH="/usr/bin:/bin:/usr/sbin:/sbin" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SCHEDULE_DM_BUDGET_SECONDS="$lookBudget" RIG_TMP="$rigTmp" RIG_FORCE="$lookForce" RIG_MEMBERS="$*" RIG_BOT="${RIG_BOT:-}" \
		RIG_CONVS="${RIG_CONVS:-2}" RIG_SLEEP="${RIG_SLEEP:-1}" bash -c '
		MMDAPP="$RIG_TMP" ; export MMDAPP
		set +e +u
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/schedule/AgentsTools.DispatcherSchedule.include" > /dev/null 2>&1
		## The include defines every helper the look calls, so the stand-ins go in AFTER it is sourced, never before.
		AgentsToolsTrackingDrop(){ cat ; }
		AgentsToolsScheduleTagNote(){ printf "note:%s=%s\n" "$1" "$2" >> "$RIG_TMP/notes" ; }
		AgentsToolsSessionChatMemberId(){ printf "URIG%s\n" "$1" ; }
		DistroAgentsTools(){
			if [ "$RIG_BOT" = yes ] ; then
				case "$1" in
					--slack-conversations-roster) printf "CONV|identity=bot|id=DBOT1|kind=im\n" ;;
					--intern-op-comms-slack-read) printf "%s\n" "1794237000.000100 | UOWNER | please look <@URIGrig-b>" "1794237000.000200 | UOWNER | for the coordinator" ; echo r >> "$RIG_TMP/reads" ;;
				esac
				return 0
			fi
			case "$1" in
				--slack-conversations-roster) echo r >> "$RIG_TMP/rosters" ; c=1 ; while [ "$c" -le "$RIG_CONVS" ] ; do printf "CONV|identity=user|id=D%s%s|kind=im\n" "$3" "$c" ; c=$(( c + 1 )) ; done ;;
				--intern-op-comms-slack-read)
					## Each read holds a token in inflight/ while it runs; the most held at once is kept in most.
					t="$( mktemp -d "$RIG_TMP/inflight/r.XXXXXX" )"
					n="$( ls "$RIG_TMP/inflight" | wc -l | tr -d " " )" ; m="$( cat "$RIG_TMP/most" 2> /dev/null || echo 0 )" ; [ "$n" -le "$m" ] || printf "%s\n" "$n" > "$RIG_TMP/most"
					sleep "$RIG_SLEEP" ; printf "%s\n" "1794237000.000100 | UPERSON | hello $2" ; echo r >> "$RIG_TMP/reads" ; rmdir "$t" ;;
			esac
			return 0
		}
		agentsSchedulePassNow=1794236000
		AgentsToolsScheduleDmTags "$RIG_MEMBERS" "" "$RIG_FORCE"
		printf "reads=%s\n" "$( wc -l < "$RIG_TMP/reads" 2> /dev/null | tr -d " " )"
		printf "rosters=%s most=%s\n" "$( wc -l < "$RIG_TMP/rosters" 2> /dev/null | tr -d " " )" "$( cat "$RIG_TMP/most" 2> /dev/null )"
		for m in $RIG_MEMBERS ; do
			if [ -f "$RIG_TMP/.local/agents/schedule/dm-looked/$m" ] ; then s=yes ; else s=no ; fi
			if [ -f "$RIG_TMP/.local/agents/schedule/dms/$m" ] ; then f="$( cat "$RIG_TMP/.local/agents/schedule/dms/$m" )" ; else f="-" ; fi
			printf "stamp:%s=%s floor:%s=%s\n" "$m" "$s" "$m" "$f"
		done
		cat "$RIG_TMP/notes" 2> /dev/null
	' 2>&1
}

## 1. Under the bound: three members, six reads of a second each, bound 60.
rigOut="$( rigLook 60 no rig-a rig-b rig-c )"
rigAssert "under the bound every conversation is read" "$( printf '%s\n' "$rigOut" | grep -c '^reads=6$' )" "1"
rigAssert "under the bound every member is stamped and has its floor" "$( printf '%s\n' "$rigOut" | grep -c 'stamp:rig-[abc]=yes floor:rig-[abc]=1794237000.000100' )" "3"
rigAssert "under the bound no dms: line is printed" "$( printf '%s\n' "$rigOut" | grep -c '^dms:' )" "0"

## 2. Over the bound: bound 2, reads of 3 s. The first four reads start together, and the bound has gone when a slot frees: rig-c's two never start.
rigOut="$( RIG_SLEEP=3 rigLook 2 no rig-a rig-b rig-c )"
rigAssert "over the bound no read starts: the four that started are served" "$( printf '%s\n' "$rigOut" | grep -c '^reads=4$' )" "1"
rigAssert "the members whose reads all started are stamped and have their floor" "$( printf '%s\n' "$rigOut" | grep -c 'stamp:rig-[ab]=yes floor:rig-[ab]=1794237000.000100' )" "2"
rigAssert "the member whose reads never started is unstamped with no floor" "$( printf '%s\n' "$rigOut" | grep -c 'stamp:rig-c=no floor:rig-c=-' )" "1"
rigAssert "one dms: line names the one that waits" "$( printf '%s\n' "$rigOut" | grep -c '^dms: the look took [0-9]*s, over its 2s bound: the DMs of rig-c wait for the next pass$' )" "1"

## 3. A member cut mid-roster: three conversations a member, so rig-b's first read starts with rig-a's three and its other two are cut.
rigOut="$( RIG_SLEEP=3 RIG_CONVS=3 rigLook 2 no rig-a rig-b rig-c )"
rigAssert "the reads that started before the cut finished: four" "$( printf '%s\n' "$rigOut" | grep -c '^reads=4$' )" "1"
rigAssert "the member cut mid-roster loses its stamp and keeps no floor" "$( printf '%s\n' "$rigOut" | grep -c 'stamp:rig-b=no floor:rig-b=-' )" "1"
rigAssert "the member read whole before it is stamped" "$( printf '%s\n' "$rigOut" | grep -c 'stamp:rig-a=yes floor:rig-a=1794237000.000100' )" "1"
rigAssert "one dms: line names the two that wait, in their order" "$( printf '%s\n' "$rigOut" | grep -c '^dms: the look took [0-9]*s, over its 2s bound: the DMs of rig-b rig-c wait for the next pass$' )" "1"

## 4. A forced look has no bound: bound 1, force yes, every read served.
rigOut="$( rigLook 1 yes rig-a rig-b )"
rigAssert "a forced look reads every conversation whatever the bound" "$( printf '%s\n' "$rigOut" | grep -c '^reads=4$' )" "1"
rigAssert "a forced look prints no dms: line" "$( printf '%s\n' "$rigOut" | grep -c '^dms:' )" "0"

## 5. Bound 0 is no bound.
rigOut="$( rigLook 0 no rig-a rig-b )"
rigAssert "bound 0 reads every conversation" "$( printf '%s\n' "$rigOut" | grep -c '^reads=4$' )" "1"

## 6. The team bot's DM is the coordinator's: another member is called there only by a message that tags it, and every floor moves past all.
rigOut="$( RIG_BOT=yes rigLook 60 no magic-coordinator rig-a rig-b )"
rigAssert "the coordinator is called by the bot's DM, at its newest message" "$( printf '%s\n' "$rigOut" | grep -c -x 'note:magic-coordinator=1794237000.000200' )" "1"
rigAssert "a member the DM does not tag is not called" "$( printf '%s\n' "$rigOut" | grep -c '^note:rig-a=' )" "0"
rigAssert "a member the DM tags is called, at the message that tags it" "$( printf '%s\n' "$rigOut" | grep -c -x 'note:rig-b=1794237000.000100' )" "1"
rigAssert "every member's floor moves past every message read, counted or not" "$( printf '%s\n' "$rigOut" | grep -c 'floor:[a-z-]*=1794237000.000200$' )" "3"
rigAssert "the team bot's DM is read once for the three members whose roster lists it" "$( printf '%s\n' "$rigOut" | grep -c '^reads=1$' )" "1"

## 7. The reads run together: six reads of a second each, four at once, take two batches, not six seconds.
rigBegan="$SECONDS"
rigOut="$( rigLook 60 no rig-a rig-b rig-c )"
rigTook=$(( SECONDS - rigBegan ))
rigAssert "the six reads are all served" "$( printf '%s\n' "$rigOut" | grep -c '^reads=6$' )" "1"
rigAssert "never more than four at once, and more than one" "$( printf '%s\n' "$rigOut" | sed -n 's/^rosters=[0-9]* most=//p' | awk '{ print ( $1 > 1 && $1 <= 4 ) ? "two to four" : "most " $1 }' )" "two to four"
rigAssert "the look takes under the six seconds of reads one after another" "$( [ "$rigTook" -lt 6 ] && echo under || echo "took $rigTook s" )" "under"

## 8. The roster is kept: a second look calls none, a forced look reads it again.
rigOut="$( rigLook 60 no rig-a rig-b )"
rigAssert "a first look reads each member's roster" "$( printf '%s\n' "$rigOut" | grep -c '^rosters=2 ' )" "1"
rigOut="$( RIG_KEEP_ROSTER=yes rigLook 60 no rig-a rig-b )"
rigAssert "a second look within the hour reads no roster, and every conversation still" "$( printf '%s\n' "$rigOut" | grep -c '^rosters= ' ):$( printf '%s\n' "$rigOut" | grep -c '^reads=4$' )" "1:1"
rigOut="$( RIG_KEEP_ROSTER=yes rigLook 60 yes rig-a rig-b )"
rigAssert "a forced look reads the roster again" "$( printf '%s\n' "$rigOut" | grep -c '^rosters=2 ' )" "1"

## 9. No member due: every member was looked at a moment ago, so the look reads nothing, and says nothing, not even an error.
rigOut="$( RIG_KEEP_LOOKED=yes rigLook 60 no rig-a rig-b )"
rigAssert "a look with no member due reads no conversation and prints no line but the rig's own" "$( printf '%s\n' "$rigOut" | grep -c '^reads=$' ):$( printf '%s\n' "$rigOut" | grep -v -e '^reads=' -e '^rosters=' -e '^stamp:' -e '^note:' | grep -c . )" "1:0"

## 10. Rosters past their hour: kept two hours ago. The look reads with them at once, and each is read again beside it.
rigOut="$( rigLook 60 no rig-a rig-b )"
for rigM in rig-a rig-b ; do { printf '%s\n' 1794228800 ; LC_ALL=C sed 1d "$rigTmp/.local/agents/schedule/dm-roster/$rigM" ; } > "$rigTmp/roster.old" && mv -f "$rigTmp/roster.old" "$rigTmp/.local/agents/schedule/dm-roster/$rigM" ; done
rigOut="$( RIG_KEEP_ROSTER=yes rigLook 60 no rig-a rig-b )"
rigAssert "with rosters past their hour every conversation is still read in the look" "$( printf '%s\n' "$rigOut" | grep -c '^reads=4$' )" "1"
rigWaited=0 ; while ls -d "$rigTmp/.local/agents/schedule/dm-roster"/.*.reading > /dev/null 2>&1 && [ "$rigWaited" -lt 20 ] ; do sleep 1 ; rigWaited=$(( rigWaited + 1 )) ; done
rigAssert "each roster is read again beside the look, and kept with a fresh first line" "$( for rigM in rig-a rig-b ; do head -1 "$rigTmp/.local/agents/schedule/dm-roster/$rigM" ; done | awk '$1 > 1794228800 { n++ } END { print n + 0 }' )" "2"

printf '%s: %s passed, %s failed\n' "${0##*/}" "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" = 0 ]
