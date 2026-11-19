#!/usr/bin/env bash
## Behavioural check on a suffixless inbox item -- the stray the writer used to make, and the repair the
## two removal operations now carry (task-20261109T2150Z, its Goal and its four halves).
## Held, against a scratch team data store:
##   1. the writer refuses a name that does not end .md, and writes nothing
##   2. no twin: the stray is renamed to its .md name, any existing suffix stripped first, so a .txt stray
##      reaches its own twin name
##   3. a twin in either folder whose body differs: refused, the differing lines named, nothing moved
##   4. a twin whose body matches: the trash drops the stray and leaves the twin byte-identical
##   5. --mark-inbox-processed takes the stray: renamed, stamped, and moved to processed/
##   6. --trash-inbox-item takes the stray, and trashes the incoming copy rather than the processed twin
##   7. a name that already ends .md is untouched by either operation
## Red before this feature: both removal operations refuse a suffixless name at their own .md gate, so
## nothing repairs or removes a stray, and nothing reads it.
## Offline: scratch stores under one mktemp tree, every call through one `env -i` whose child refuses to
## run outside it; no remote.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsInboxStrayRepairCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data"
rigSkills="$rigTmp/skills"
rigInbox="$rigData/inboxes/rig-member"
mkdir -p "$rigTmp/ws/.local" "$rigTmp/home" "$rigSkills/rig-member" "$rigSkills/magic-coordinator" "$rigInbox/incoming" "$rigInbox/processed" || rigRefuse "could not create the scratch team data store"
printf 'rig\n' > "$rigSkills/rig-member/rig-member.basic.md"
printf 'rig\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"

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
	LC_ALL=C grep -q -F -- "$2" "$1" 2> /dev/null && printf yes || printf no
}
## Where an item is: incoming, processed, none.
rigWhere(){ ## item filename
	if [ -f "$rigInbox/incoming/$1" ] ; then printf incoming
	elif [ -f "$rigInbox/processed/$1" ] ; then printf processed
	else printf none
	fi
}
rigOp(){ ## result file, op and arguments... -- one team op, guarded; rc into <result>.rc
	local opOut="$1" ; shift
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_WAIT_REMIND=off RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$opOut" 2>&1 < /dev/null
	printf '%s' "$?" > "$opOut.rc"
}
rigStray(){ ## path, body marker -- a stray in the shape the old writer made, with no suffix
	printf -- '---\ntype: note\nfrom: rig-member\ndate: 2026-11-18 09:00 +0200\nowner: rig-member\ndocument-contract: inbox-item.note\n---\n\n%s\n' "$2" > "$1"
}
rigTwin(){ ## path, body marker -- the same item with its .md suffix
	rigStray "$1" "$2"
}

echo "-- 1. the writer refuses a suffixless name, and writes nothing --"
printf -- '---\ntype: note\n---\n\nRIG-FRESH\n' > "$rigTmp/fresh.md"
rigOp "$rigTmp/w1" --upsert-inbox-note --team-member rig-member note-20261118T0900Z-fresh --from-member rig-member --from-file "$rigTmp/fresh.md"
rigAssert "the suffixless write is refused, naming the .md rule" \
	"$( [ "$( cat "$rigTmp/w1.rc" )" -ne 0 ] && printf refused || printf accepted ):$( rigHolds "$rigTmp/w1" 'must end in .md' )" "refused:yes"
rigAssert "and nothing was written" "$( rigWhere note-20261118T0900Z-fresh )" none
rigOp "$rigTmp/w2" --upsert-inbox-note --team-member rig-member note-20261118T0901Z-fresh.md --from-member rig-member --from-file "$rigTmp/fresh.md"
rigAssert "the control, the same call with .md: written, in incoming/" "$( cat "$rigTmp/w2.rc" ):$( rigWhere note-20261118T0901Z-fresh.md )" "0:incoming"

echo "-- 2. no twin: the stray is renamed to its .md name, any suffix stripped first --"
rigStray "$rigInbox/incoming/note-20261118T0910Z-plain" RIG-PLAIN
rigOp "$rigTmp/m1" --mark-inbox-processed --team-member rig-member note-20261118T0910Z-plain
rigAssert "a suffixless stray is marked, not refused" "$( cat "$rigTmp/m1.rc" )" 0
rigAssert "marking renames it and moves it to processed/" \
	"$( rigWhere note-20261118T0910Z-plain.md ):$( rigWhere note-20261118T0910Z-plain )" "processed:none"
rigStray "$rigInbox/incoming/note-20261118T0911Z-suffixed.txt" RIG-TXT
rigOp "$rigTmp/t1" --trash-inbox-item --team-member rig-member note-20261118T0911Z-suffixed.txt
rigAssert "a .txt stray reaches its own twin name: renamed, then trashed" \
	"$( cat "$rigTmp/t1.rc" ):$( rigWhere note-20261118T0911Z-suffixed.txt ):$( rigWhere note-20261118T0911Z-suffixed.md )" "0:none:none"

echo "-- 3. a twin whose body differs: refused, the lines named, nothing moved --"
rigStray "$rigInbox/incoming/note-20261118T0920Z-differs" RIG-OLDER-COPY
rigTwin  "$rigInbox/processed/note-20261118T0920Z-differs.md" RIG-NEWER-COPY
rigOp "$rigTmp/r1" --trash-inbox-item --team-member rig-member note-20261118T0920Z-differs
rigAssert "the repair refuses, and names the line that differs" \
	"$( [ "$( cat "$rigTmp/r1.rc" )" -ne 0 ] && printf refused || printf accepted ):$( rigHolds "$rigTmp/r1" 'differs' )" "refused:yes"
rigAssert "the stray stays, and the twin is untouched" \
	"$( rigWhere note-20261118T0920Z-differs ):$( rigHolds "$rigInbox/processed/note-20261118T0920Z-differs.md" RIG-NEWER-COPY )" "incoming:yes"

echo "-- 4. a twin whose body matches: the stray is dropped, the twin byte-identical --"
rigStray "$rigInbox/incoming/note-20261118T0930Z-identical" RIG-SAME-COPY
rigTwin  "$rigInbox/processed/note-20261118T0930Z-identical.md" RIG-SAME-COPY
rigTwinSumBefore="$( cksum "$rigInbox/processed/note-20261118T0930Z-identical.md" )"
rigOp "$rigTmp/r2" --trash-inbox-item --team-member rig-member note-20261118T0930Z-identical
rigAssert "the stray is gone" "$( cat "$rigTmp/r2.rc" ):$( rigWhere note-20261118T0930Z-identical )" "0:none"
rigAssert "the twin is byte-identical, untouched" \
	"$( rigWhere note-20261118T0930Z-identical.md ):$( cksum "$rigInbox/processed/note-20261118T0930Z-identical.md" )" "processed:$rigTwinSumBefore"

echo "-- 5. --mark-inbox-processed takes the stray: renamed, stamped, moved --"
rigStray "$rigInbox/incoming/note-20261118T0940Z-mark-me" RIG-MARK-ME
rigOp "$rigTmp/m2" --mark-inbox-processed --team-member rig-member note-20261118T0940Z-mark-me
rigAssert "renamed and moved to processed/" \
	"$( cat "$rigTmp/m2.rc" ):$( rigWhere note-20261118T0940Z-mark-me ):$( rigWhere note-20261118T0940Z-mark-me.md )" "0:none:processed"
rigAssert "the body survives the rename" \
	"$( rigHolds "$rigInbox/processed/note-20261118T0940Z-mark-me.md" RIG-MARK-ME )" yes

echo "-- 6. --trash-inbox-item takes the stray, and trashes the incoming copy, not the processed twin --"
rigStray "$rigInbox/incoming/note-20261118T0950Z-trash-stray" RIG-STRAY-BODY
rigTwin  "$rigInbox/processed/note-20261118T0950Z-trash-stray.md" RIG-TWIN-BODY
rigOp "$rigTmp/t2" --trash-inbox-item --team-member rig-member note-20261118T0950Z-trash-stray
rigAssert "the call is refused, because the bodies differ, and the twin is untouched" \
	"$( [ "$( cat "$rigTmp/t2.rc" )" -ne 0 ] && printf refused || printf accepted ):$( rigHolds "$rigInbox/processed/note-20261118T0950Z-trash-stray.md" RIG-TWIN-BODY )" "refused:yes"
rigStray "$rigInbox/incoming/note-20261118T0951Z-no-twin-stray" RIG-ONLY-COPY
rigOp "$rigTmp/t3" --trash-inbox-item --team-member rig-member note-20261118T0951Z-no-twin-stray
rigAssert "a stray with no twin is removed" \
	"$( cat "$rigTmp/t3.rc" ):$( rigWhere note-20261118T0951Z-no-twin-stray ):$( rigWhere note-20261118T0951Z-no-twin-stray.md )" "0:none:none"

echo "-- 7. a name that already ends .md is untouched by either operation --"
rigTwin "$rigInbox/incoming/note-20261118T0960Z-plain-md.md" RIG-PLAIN-MD
rigOp "$rigTmp/p1" --mark-inbox-processed --team-member rig-member note-20261118T0960Z-plain-md.md
rigAssert "a .md item is marked as before, with no rename" \
	"$( cat "$rigTmp/p1.rc" ):$( rigWhere note-20261118T0960Z-plain-md.md )" "0:processed"
rigTwin "$rigInbox/incoming/note-20261118T0961Z-trash-md.md" RIG-TRASH-MD
rigOp "$rigTmp/p2" --trash-inbox-item --team-member rig-member note-20261118T0961Z-trash-md.md
rigAssert "a .md item is trashed as before" "$( cat "$rigTmp/p2.rc" ):$( rigWhere note-20261118T0961Z-trash-md.md )" "0:none"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ INBOX STRAY REPAIR CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'INBOX_STRAY_REPAIR: OK (%d assertions, offline)\n' "$rigPassCount"
