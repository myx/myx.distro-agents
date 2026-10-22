#!/usr/bin/env bash
#!/usr/bin/env bash
## Behavioural check on the 35-day reflection sweep (T4, --intern-team-data-reflection-sweep). Held, against temp stores only:
##   1. WHAT IS SWEPT: a reflection in incoming/ whose date (the `date:` header's, else the NAME's, in the new name form and the old one) is
##      before the cutoff goes to processed/ of its own inbox with `processed-at` (the same all day), `disposition: discarded` and `discarded-by`
##   2. THE HEAL: a file with no `date:` header is given one, the date of its name, or the day of the sweep where the name has none and
##      it stays; one warning for each, never again; a present header is never rewritten
##   3. WHAT IS KEPT AND COUNTED: a recent name, a recent header, every other item type, an item already in processed/; one line for each
##      inbox, one for the run; a second run moves nothing and answers 2
##   3b. ONE WRITER: the sweep's file equals the mark op's file for the same input
##   4. THE COST: 200 old reflections in one inbox are swept in one awk pass, in about a second
##   5. GIT: in a repo data root the moves are ONE commit for the run, and the tree is clean after
## Every call goes through one `env -i` whose child refuses to run outside this rig's mktemp tree; no Slack, no mail.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsReflectionSweepCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data"
rigSkills="$rigTmp/skills"
mkdir -p "$rigTmp/ws/.local" "$rigTmp/home" "$rigSkills/rig-member" "$rigSkills/rig-other" "$rigSkills/magic-coordinator" "$rigData/board/running" "$rigData/board/pending" "$rigData/board/backlog"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHolds(){ ## file, fixed text
	LC_ALL=C grep -q -F -- "$2" "$1" && printf yes || printf no
}
## The value of one frontmatter field, bounded to the first --- block.
rigField(){ ## file, field
	LC_ALL=C awk -v f="$2" '$0 == "---" { d++ ; if (d >= 2) exit ; next ; } d == 1 && index($0, f ": ") == 1 { print substr($0, length(f) + 3) ; exit ; }' "$1"
}
rigFieldCount(){ ## file, field
	LC_ALL=C awk -v f="$2" '$0 == "---" { d++ ; if (d >= 2) exit ; next ; } d == 1 && index($0, f ": ") == 1 { n++ ; } END { print n + 0 ; }' "$1"
}
## One team op, guarded, against the rig's own stores; rc into <result>.rc. RIG_AGENT, when
## set, becomes MDAT_SPAWN_AGENT -- the spawned session's own member.
rigOp(){ ## result file, op and arguments...
	local opOut="$1" ; shift
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" ${RIG_AGENT:+MDAT_SPAWN_AGENT="$RIG_AGENT"} \
		RIG_TMP="$rigTmp" RIG_FN="$rigFn" GIT_CEILING_DIRECTORIES="$rigTmp" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$HOME" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$opOut" 2>&1
	printf '%s' "$?" > "$opOut.rc"
}


rigInc(){ printf '%s/inboxes/%s/incoming/%s' "$rigData" "$1" "$2" ; }
rigProc(){ printf '%s/inboxes/%s/processed/%s' "$rigData" "$1" "$2" ; }
rigNow="$( date -u +%Y%m%dT%H%MZ )"
rigPut(){ ## member, file name, text -- an item of that inbox's incoming/
	mkdir -p "$rigData/inboxes/$1/incoming" && printf '%s' "$3" > "$rigData/inboxes/$1/incoming/$2"
}
rigSweep(){ ## result file, extra options
	local rigOut="$1" ; shift
	rigOp "$rigOut" --intern-team-data-reflection-sweep magic-coordinator --context rig "$@"
}

rigToday="$( date -u +%Y-%m-%d )"
rigStampToday="$rigToday 00:00 +0000"
rigOld1=reflection-20260101T0900Z-rig-old.md
rigOld2=reflection-2026-01-02-rig-legacy.md
rigOld3=reflection-20260103T1000Z-rig-bare.md
rigNew1="reflection-${rigNow}-rig-recent.md"
rigNoDate=reflection-rig-undated-recent.md
rigNoDateOld=reflection-rig-undated-old.md
rigNoDateNoHdr=reflection-rig-undated-nohdr.md
rigOldNewHdr=reflection-20260104T1100Z-rig-renamed.md
rigNote=note-20260101T0900Z-rig-oldnote.md
rigPut rig-member "$rigOld1" "$( printf -- '---\ntype: reflection\nfrom: rig-member\ndate: 2026-01-01 09:00 +0000\n---\nbody one\nsecond line\n' )"$'\n'
rigPut rig-member "$rigOld2" "$( printf -- '---\ntype: reflection\nfrom: rig-member\n---\nlegacy body\n' )"$'\n'
rigPut rig-other "$rigOld3" "bare text, no frontmatter"$'\n'
rigPut rig-member "$rigNew1" "$( printf -- '---\ntype: reflection\ndate: 2026-10-06 09:30 +0000\n---\nrecent\n' )"$'\n'
rigPut rig-member "$rigNoDate" "$( printf -- '---\ntype: reflection\ndate: %s 09:30 +0000\n---\nundated name, recent header\n' "$rigToday" )"$'\n'
rigPut rig-member "$rigNoDateOld" "$( printf -- '---\ntype: reflection\ndate: 2025-01-01 09:00 +0000\n---\nundated name, old header\n' )"$'\n'
rigPut rig-member "$rigNoDateNoHdr" "$( printf -- '---\ntype: reflection\nfrom: rig-member\n---\nundated name, no header\n' )"$'\n'
rigPut rig-other "$rigOldNewHdr" "$( printf -- '---\ntype: reflection\ndate: %s 08:00 +0000\n---\nname old, header new\n' "$rigToday" )"$'\n'
rigPut rig-member "$rigNote" "$( printf -- '---\ntype: note\n---\nan old note\n' )"$'\n'
mkdir -p "$rigData/inboxes/rig-member/processed" && printf -- '---\nprocessed-at: 2026-01-01 00:00 +0000\n---\nalready\n' > "$rigData/inboxes/rig-member/processed/reflection-20260101T0100Z-rig-done.md"

echo "-- 1. what is swept --"
rigSweep "$rigTmp/s1"
rigAssert "the sweep returns 0" "$( cat "$rigTmp/s1.rc" )" "0"
rigAssert "swept: old name (both forms), no name date with an old header, and the bare one" "$( for rigF in "rig-member $rigOld1" "rig-member $rigOld2" "rig-member $rigNoDateOld" "rig-other $rigOld3" ; do set -- $rigF ; [ ! -f "$( rigInc "$1" "$2" )" ] && [ -f "$( rigProc "$1" "$2" )" ] && printf Y || printf n ; done )" "YYYY"
rigAssert "stamped: processed-at, disposition, discarded-by, each once" "$( rigFieldCount "$( rigProc rig-member "$rigOld1" )" processed-at )$( rigFieldCount "$( rigProc rig-member "$rigOld1" )" disposition )$( rigFieldCount "$( rigProc rig-member "$rigOld1" )" discarded-by )" "111"
rigAssert "with the values; processed-at is the same all day: 00:00 UTC of today" "$( rigField "$( rigProc rig-member "$rigOld1" )" disposition ):$( rigField "$( rigProc rig-member "$rigOld1" )" discarded-by ):$( rigField "$( rigProc rig-member "$rigOld1" )" processed-at )" "discarded:reflection-sweep-35d:$rigStampToday"
rigAssert "the rest of the file is as it was" "$( rigField "$( rigProc rig-member "$rigOld1" )" date ):$( LC_ALL=C grep -c -E '^(body one|second line)$' "$( rigProc rig-member "$rigOld1" )" )" "2026-01-01 09:00 +0000:2"

echo "-- 2. a date is healed, lazily and logged --"
rigAssert "an old name with no date: header: swept, given the date of its name once (both name forms)" "$( rigField "$( rigProc rig-member "$rigOld2" )" date ):$( rigFieldCount "$( rigProc rig-member "$rigOld2" )" date )" "2026-01-02 00:00 +0000:1"
rigAssert "a file with no frontmatter is given a block with that date, its text kept" "$( rigField "$( rigProc rig-other "$rigOld3" )" date ):$( rigField "$( rigProc rig-other "$rigOld3" )" disposition ):$( rigHolds "$( rigProc rig-other "$rigOld3" )" 'bare text, no frontmatter' )" "2026-01-03 10:00 +0000:discarded:yes"
rigAssert "no name date and no header: kept in incoming/, given the day of the sweep once" "$( [ -f "$( rigInc rig-member "$rigNoDateNoHdr" )" ] && echo kept ):$( rigFieldCount "$( rigInc rig-member "$rigNoDateNoHdr" )" date ):$( rigField "$( rigInc rig-member "$rigNoDateNoHdr" )" date )" "kept:1:$rigStampToday"
rigAssert "one warning for each of the three given a date, and no other" "$( LC_ALL=C grep -c 'WARNING' "$rigTmp/s1" ):$( LC_ALL=C grep -c 'rig-undated-nohdr' "$rigTmp/s1" )" "3:1"
rigAssert "a present header is never rewritten" "$( rigField "$( rigProc rig-member "$rigNoDateOld" )" date ):$( rigFieldCount "$( rigProc rig-member "$rigNoDateOld" )" date )" "2025-01-01 09:00 +0000:1"

echo "-- 3. what is kept, and the counts --"
rigAssert "recent name, undated name with a recent header, old name with a recent header: still in incoming/, not in processed/" "$( for rigF in "rig-member $rigNew1" "rig-member $rigNoDate" "rig-other $rigOldNewHdr" ; do set -- $rigF ; [ -f "$( rigInc "$1" "$2" )" ] && [ ! -f "$( rigProc "$1" "$2" )" ] && printf Y || printf n ; done )" "YYY"
rigAssert "an old note of another type is not touched, and gets no date" "$( [ -f "$( rigInc rig-member "$rigNote" )" ] && echo kept ):$( rigFieldCount "$( rigInc rig-member "$rigNote" )" date )" "kept:0"
rigAssert "an item already in processed/ is not touched" "$( rigFieldCount "$rigData/inboxes/rig-member/processed/reflection-20260101T0100Z-rig-done.md" disposition )" "0"
rigAssert "a line for each inbox" "$( LC_ALL=C grep -c -E '^reflection-sweep: (rig-member: swept 3, kept 2|rig-other: swept 1, kept 1)$' "$rigTmp/s1" )" "2"
rigAssert "a line for the run" "$( LC_ALL=C grep -c -E '^reflection-sweep: swept 4 of 8 reflection\(s\) older than 35 days \(cutoff [0-9]{8}\), by rig$' "$rigTmp/s1" )" "1"
rigSum1="$( cksum < "$( rigInc rig-member "$rigNoDateNoHdr" )" )"
rigSweep "$rigTmp/s2"
rigAssert "a second run moves nothing, answers 2, warns of nothing, leaves the healed file as it is" "$( cat "$rigTmp/s2.rc" ):$( LC_ALL=C grep -c 'WARNING' "$rigTmp/s2" ):$( [ "$rigSum1" = "$( cksum < "$( rigInc rig-member "$rigNoDateNoHdr" )" )" ] && echo same )" "2:0:same"
rigSweep "$rigTmp/s4" --days x
rigAssert "a bad --days is refused" "$( cat "$rigTmp/s4.rc" )" "1"

echo "-- 3b. one writer: the sweep's file is the mark op's file for the same input --"
## The same three inputs in an inbox the mark op marks (the headers the sweep appends, in its order) and in an inbox the sweep sweeps.
rm -rf "$rigData/inboxes"
rigC1=reflection-20260101T0900Z-rig-conf1.md
rigC2=reflection-20260102T0900Z-rig-conf2.md
rigC3=reflection-20260103T0900Z-rig-conf3.md
rigConfPut(){ ## member
	rigPut "$1" "$rigC1" "$( printf -- '---\ntype: reflection\nfrom: x\ndate: 2026-01-01 09:00 +0000\n---\nconf one\nsecond\n' )"$'\n'
	rigPut "$1" "$rigC2" "$( printf -- '---\ntype: reflection\nfrom: x\n---\nconf two\n' )"$'\n'
	rigPut "$1" "$rigC3" "conf three, bare"$'\n'
}
rigConfPut rig-mark
rigOp "$rigTmp/c1" --intern-op-inbox-to-processed rig-mark "$rigC1" --context rig "--header:upsert:processed-at:$rigStampToday" --header:upsert:disposition:discarded --header:upsert:discarded-by:reflection-sweep-35d
rigOp "$rigTmp/c2" --intern-op-inbox-to-processed rig-mark "$rigC2" --context rig "--header:upsert:processed-at:$rigStampToday" --header:upsert:disposition:discarded --header:upsert:discarded-by:reflection-sweep-35d "--header:upsert:date:2026-01-02 09:00 +0000"
rigOp "$rigTmp/c3" --intern-op-inbox-to-processed rig-mark "$rigC3" --context rig "--header:upsert:processed-at:$rigStampToday" --header:upsert:disposition:discarded --header:upsert:discarded-by:reflection-sweep-35d "--header:upsert:date:2026-01-03 09:00 +0000"
rigMarkSums="$( for rigF in "$rigC1" "$rigC2" "$rigC3" ; do cksum < "$( rigProc rig-mark "$rigF" )" ; done )"
rm -rf "$rigData/inboxes/rig-mark"
rigConfPut rig-sweep
rigSweep "$rigTmp/c4"
rigSweepSums="$( for rigF in "$rigC1" "$rigC2" "$rigC3" ; do cksum < "$( rigProc rig-sweep "$rigF" )" ; done )"
rigAssert "byte for byte the same, three inputs: dated, no date header, no frontmatter" "$( [ "$rigMarkSums" = "$rigSweepSums" ] && echo same || printf '%s | %s' "$( printf '%s' "$rigMarkSums" | tr '\n' ' ' )" "$( printf '%s' "$rigSweepSums" | tr '\n' ' ' )" )" "same"

echo "-- 4. the cost --"
rm -rf "$rigData/inboxes/rig-member/incoming" "$rigData/inboxes/rig-member/processed" "$rigData/inboxes/rig-other"
for rigI in $( seq 1 200 ) ; do
	rigPut rig-member "$( printf 'reflection-202601%02dT0900Z-rig-bulk-%03d.md' $(( 1 + rigI % 28 )) "$rigI" )" "$( printf -- '---\ntype: reflection\ndate: 2026-01-01 09:00 +0000\n---\nbulk %s\n' "$rigI" )"$'\n'
done
rigT0="$( date +%s )"
rigSweep "$rigTmp/s5"
rigT1="$( date +%s )"
rigAssert "200 swept, none left in incoming/, 200 in processed/" "$( cat "$rigTmp/s5.rc" ):$( ls "$rigData/inboxes/rig-member/incoming" | wc -l | tr -d ' ' ):$( ls "$rigData/inboxes/rig-member/processed" | wc -l | tr -d ' ' ):$( rigHolds "$rigTmp/s5" 'rig-member: swept 200, kept 0' )" "0:0:200:yes"
rigAssert "in about a second (whole seconds, so 2 at most)" "$(( rigT1 - rigT0 <= 2 ? 1 : 0 ))" "1"

echo "-- 5. git --"
rm -rf "$rigData/inboxes"
rigPut rig-member "$rigOld1" "$( printf -- '---\ntype: reflection\ndate: 2026-01-01 09:00 +0000\n---\nbody one\n' )"$'\n'
rigPut rig-member "$rigOld2" "$( printf -- '---\ntype: reflection\n---\nlegacy\n' )"$'\n'
rigPut rig-member "$rigNew1" "$( printf -- '---\ntype: reflection\ndate: 2026-10-06 09:30 +0000\n---\nrecent\n' )"$'\n'
git -C "$rigData" init -q 2> /dev/null && git -C "$rigData" config user.name rig && git -C "$rigData" config user.email rig@rig.invalid \
	&& git -C "$rigData" add -A && git -C "$rigData" commit -q -m rig-base
rigC0="$( git -C "$rigData" rev-list --count HEAD 2> /dev/null )"
rigSweep "$rigTmp/g1"
rigAssert "swept 2" "$( cat "$rigTmp/g1.rc" ):$( rigHolds "$rigTmp/g1" 'swept 2 of 3' )" "0:yes"
rigAssert "one commit for the run, the tree clean after" "$(( $( git -C "$rigData" rev-list --count HEAD 2> /dev/null ) - rigC0 )):$( git -C "$rigData" status --porcelain 2> /dev/null | wc -l | tr -d ' ' ):$( git -C "$rigData" log -1 --format=%s 2> /dev/null )" "1:0:* reflection-sweep: 2 discarded after 35 days"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ REFLECTION SWEEP CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'REFLECTION_SWEEP: OK (%d assertions, offline, temp store only)\n' "$rigPassCount"
