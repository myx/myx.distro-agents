#!/usr/bin/env bash
## Behavioural check on the exit of a reflection at the moment of filing (T1): `--upsert-inbox-inquiry ... --from-reflection <reflection-file>` files
## the lesson inquiry and marks the reflection of the filing member's own inbox processed in the same call. Held, against temp stores only:
##   1. THE EXIT: the inquiry is written to the other member's inbox, the reflection leaves incoming/ for processed/ with `processed-at`,
##      `disposition: filed-as-inquiry` and `filed-as: <inquiry>`
##   2. NOTHING IS HALF DONE: a reflection that is not there, a name that is no reflection, another member's reflection, a missing name -- the call
##      is refused before anything is written, the inquiry included
##   3. WITHOUT THE OPTION the inquiry is filed as before and no reflection is touched
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
rigTmp="$( rigTempDir AgentsInquiryFromReflectionCheck )" || exit 1
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
		RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
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
rigR1=reflection-20261006T0930Z-rig-lesson.md
rigQ1=inquiry-20261006T0931Z-rig-lesson-filed.md
printf 'A lesson learned.\n' | RIG_AGENT=rig-member rigOp "$rigTmp/r1" --upsert-inbox-reflection rig-member "$rigR1"
rigAssert "the reflection is in incoming/" "$( cat "$rigTmp/r1.rc" ):$( [ -f "$( rigInc rig-member "$rigR1" )" ] && echo yes || echo no )" "0:yes"

echo "-- 1. the exit --"
printf 'Please take this lesson.\n' | RIG_AGENT=rig-member rigOp "$rigTmp/f1" --upsert-inbox-inquiry rig-other "$rigQ1" --from-reflection "$rigR1"
rigAssert "the call succeeds, the inquiry is in the other inbox" "$( cat "$rigTmp/f1.rc" ):$( [ -f "$( rigInc rig-other "$rigQ1" )" ] && echo yes || echo no )" "0:yes"
rigAssert "the reflection left incoming/ and is in processed/" "$( [ -f "$( rigInc rig-member "$rigR1" )" ] && echo incoming || echo gone ):$( [ -f "$( rigProc rig-member "$rigR1" )" ] && echo processed || echo missing )" "gone:processed"
rigAssert "stamped: processed-at, the disposition and the inquiry's name" "$( rigFieldCount "$( rigProc rig-member "$rigR1" )" processed-at ):$( rigField "$( rigProc rig-member "$rigR1" )" disposition ):$( rigField "$( rigProc rig-member "$rigR1" )" filed-as )" "1:filed-as-inquiry:$rigQ1"
rigAssert "the inquiry carries no from-reflection option text" "$( rigHolds "$( rigInc rig-other "$rigQ1" )" 'from-reflection' )" "no"

echo "-- 2. nothing half done --"
rigQ2=inquiry-20261006T0932Z-rig-lesson-two.md
printf 'x\n' | RIG_AGENT=rig-member rigOp "$rigTmp/n1" --upsert-inbox-inquiry rig-other "$rigQ2" --from-reflection reflection-20261006T0999Z-rig-absent.md
rigAssert "a reflection not there: refused, no inquiry" "$( cat "$rigTmp/n1.rc" ):$( [ -f "$( rigInc rig-other "$rigQ2" )" ] && echo written || echo absent ):$( rigHolds "$rigTmp/n1" 'not an unprocessed reflection' )" "1:absent:yes"
printf 'x\n' | RIG_AGENT=rig-member rigOp "$rigTmp/n2" --upsert-inbox-inquiry rig-other "$rigQ2" --from-reflection "$rigR1"
rigAssert "a reflection already processed: refused, no inquiry" "$( cat "$rigTmp/n2.rc" ):$( [ -f "$( rigInc rig-other "$rigQ2" )" ] && echo written || echo absent )" "1:absent"
printf 'a note\n' | RIG_AGENT=rig-member rigOp "$rigTmp/n3a" --upsert-inbox-note rig-member note-20261006T0933Z-rig-notreflection.md
printf 'x\n' | RIG_AGENT=rig-member rigOp "$rigTmp/n3" --upsert-inbox-inquiry rig-other "$rigQ2" --from-reflection note-20261006T0933Z-rig-notreflection.md
rigAssert "a name that is no reflection: refused, no inquiry, the note stays" "$( cat "$rigTmp/n3.rc" ):$( [ -f "$( rigInc rig-other "$rigQ2" )" ] && echo written || echo absent ):$( [ -f "$( rigInc rig-member note-20261006T0933Z-rig-notreflection.md )" ] && echo stays )" "1:absent:stays"
rigR4=reflection-20261006T0934Z-rig-others.md
printf 'theirs\n' | RIG_AGENT=rig-other rigOp "$rigTmp/n4a" --upsert-inbox-reflection rig-other "$rigR4"
printf 'x\n' | RIG_AGENT=rig-member rigOp "$rigTmp/n4" --upsert-inbox-inquiry rig-other "$rigQ2" --from-reflection "$rigR4"
rigAssert "another member's reflection: refused, no inquiry, theirs untouched" "$( cat "$rigTmp/n4.rc" ):$( [ -f "$( rigInc rig-other "$rigQ2" )" ] && echo written || echo absent ):$( [ -f "$( rigInc rig-other "$rigR4" )" ] && echo untouched )" "1:absent:untouched"
printf 'x\n' | RIG_AGENT=rig-member rigOp "$rigTmp/n5" --upsert-inbox-inquiry rig-other "$rigQ2" --from-reflection
rigAssert "a missing value: refused, no inquiry" "$( cat "$rigTmp/n5.rc" ):$( [ -f "$( rigInc rig-other "$rigQ2" )" ] && echo written || echo absent )" "1:absent"

echo "-- 3. without the option --"
rigR6=reflection-20261006T0935Z-rig-kept.md
printf 'kept\n' | RIG_AGENT=rig-member rigOp "$rigTmp/k0" --upsert-inbox-reflection rig-member "$rigR6"
printf 'plain\n' | RIG_AGENT=rig-member rigOp "$rigTmp/k1" --upsert-inbox-inquiry rig-other "$rigQ2"
rigAssert "the inquiry is filed, the reflection is untouched in incoming/" "$( cat "$rigTmp/k1.rc" ):$( [ -f "$( rigInc rig-other "$rigQ2" )" ] && echo written || echo absent ):$( [ -f "$( rigInc rig-member "$rigR6" )" ] && echo untouched )" "0:written:untouched"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ INQUIRY FROM REFLECTION CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'INQUIRY_FROM_REFLECTION: OK (%d assertions, offline, temp store only)\n' "$rigPassCount"
