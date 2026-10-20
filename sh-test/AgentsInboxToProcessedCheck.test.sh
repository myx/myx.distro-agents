#!/usr/bin/env bash
## Behavioural check of the inbox processed marker over the split inbox (F4.3: `incoming/` and
## `processed/`, the item's processed stamp deciding its folder): --librarian-inbox-to-processed
## and --member-inbox-to-processed stamp `processed-at` into the item and move it from incoming/
## to processed/, create frontmatter when the item has none, keep a caller's processed-at, treat
## a re-mark (with --include-processed) as a no-op, and keep the original stamp through an edit;
## an operation sees only incoming/ unless it takes --include-processed, a named read included;
## the member's active scan lists incoming/ alone; and the final GC collects processed items by
## their stamp's age, never an unmarked one, and drains an unstamped processed/ item by its age
## as before. Once more over a git-tracked root for the two commits.
## Reconciled for F4.3 from the flat form this check held before ("never a processed/ folder"). Offline: scratch stores under one mktemp
## tree, every call through one `env -i` whose child refuses to run outside it; no remote.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsInboxToProcessedCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data"
rigSkills="$rigTmp/skills"
rigInbox="$rigData/inboxes/rig-member"
mkdir -p "$rigTmp/ws/.local" "$rigTmp/home" "$rigSkills/rig-member" "$rigSkills/magic-librarian" "$rigInbox/incoming" "$rigData/inboxes/magic-librarian/incoming" \
	|| rigRefuse "could not create the scratch team data store"

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
rigIs(){ ## path -- file or none
	[ -f "$1" ] && printf file || printf none
}
## The value of one frontmatter field, bounded to the first --- block.
rigField(){ ## file, field
	LC_ALL=C awk -v f="$2" '$0 == "---" { d++ ; if (d >= 2) exit ; next ; } d == 1 && index($0, f ": ") == 1 { print substr($0, length(f) + 3) ; exit ; }' "$1"
}
rigFieldCount(){ ## file, field
	LC_ALL=C awk -v f="$2" '$0 == "---" { d++ ; if (d >= 2) exit ; next ; } d == 1 && index($0, f ": ") == 1 { n++ ; } END { print n + 0 ; }' "$1"
}
## One team op, guarded, against the given data root (default the rig's); rc into <result>.rc.
rigOp(){ ## result file, op and arguments...
	local opOut="$1" ; shift
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="${RIG_DATA:-$rigData}" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$HOME" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$opOut" 2>&1
	printf '%s' "$?" > "$opOut.rc"
}
## A bare UTC date some whole days ago, through the package's own portable converter.
rigDaysAgo(){ ## days
	printf '%s\n' "$(( $( date +%s ) - $1 * 86400 ))" | LC_ALL=C awk -f "$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/output/LocalEpochToIsoDate.awk"
}

echo "-- mark: stamped, and moved from incoming/ to processed/ --"
rigLib1="$rigData/inboxes/magic-librarian"
printf -- '---\ntype: note\n---\n\n# Rig note\n' > "$rigLib1/incoming/note-rig.md"
rigOp "$rigTmp/m1" --librarian-inbox-to-processed magic-librarian note-rig.md
rigAssert "the mark succeeds"                          "$( cat "$rigTmp/m1.rc" )" 0
rigAssert "the item is in processed/, and no longer in incoming/" "$( rigIs "$rigLib1/processed/note-rig.md" ):$( rigIs "$rigLib1/incoming/note-rig.md" )" "file:none"
rigAssert "nothing of it stands at the inbox root"     "$( rigIs "$rigLib1/note-rig.md" )" none
rigAssert "processed-at is stamped once"               "$( rigFieldCount "$rigLib1/processed/note-rig.md" processed-at )" 1
rigAssert "the rest of the item is unchanged"          "$( rigField "$rigLib1/processed/note-rig.md" type ):$( rigHolds "$rigLib1/processed/note-rig.md" '# Rig note' )" "note:yes"
rigAssert "no temp file is left behind"                "$( ls -A "$rigLib1" | LC_ALL=C grep -c -v -x -e incoming -e processed ):$( ls -A "$rigLib1/incoming" | LC_ALL=C grep -c . ):$( ls -A "$rigLib1/processed" | LC_ALL=C grep -c -v '^note-rig\.md$' )" "0:0:0"

echo "-- re-mark is a no-op --"
cp "$rigLib1/processed/note-rig.md" "$rigTmp/note-rig.before"
rigOp "$rigTmp/m2" --librarian-inbox-to-processed magic-librarian note-rig.md --include-processed
rigAssert "a re-mark succeeds"                         "$( cat "$rigTmp/m2.rc" )" 0
rigAssert "and changes nothing, nor moves it"          "$( cmp -s "$rigTmp/note-rig.before" "$rigLib1/processed/note-rig.md" && printf same || printf changed ):$( rigIs "$rigLib1/incoming/note-rig.md" )" "same:none"
rigAssert "and says so"                                "$( rigHolds "$rigTmp/m2" 'already processed' )" yes

echo "-- an item with no frontmatter --"
printf 'plain body line\n' > "$rigInbox/incoming/note-20261006T0930Z-plain.md"
rigOp "$rigTmp/m3" --member-inbox-to-processed rig-member note-20261006T0930Z-plain.md
rigAssert "the mark succeeds"                          "$( cat "$rigTmp/m3.rc" )" 0
rigAssert "a frontmatter block is created, in processed/" "$( head -n 1 "$rigInbox/processed/note-20261006T0930Z-plain.md" ):$( rigFieldCount "$rigInbox/processed/note-20261006T0930Z-plain.md" processed-at )" "---:1"
rigAssert "the body follows it"                        "$( rigHolds "$rigInbox/processed/note-20261006T0930Z-plain.md" 'plain body line' )" yes

echo "-- a caller's processed-at wins --"
printf -- '---\ntype: note\n---\nbody\n' > "$rigInbox/incoming/note-20261006T0930Z-given.md"
rigOp "$rigTmp/m4" --member-inbox-to-processed rig-member note-20261006T0930Z-given.md "--header:upsert:processed-at:2020-02-02 02:02 +0000"
rigAssert "the given value is the one written"         "$( cat "$rigTmp/m4.rc" ):$( rigField "$rigInbox/processed/note-20261006T0930Z-given.md" processed-at ):$( rigFieldCount "$rigInbox/processed/note-20261006T0930Z-given.md" processed-at )" "0:2020-02-02 02:02 +0000:1"

echo "-- an edit of an already-marked item keeps the original stamp --"
printf -- '---\ntype: note\n---\nrewritten body\n' | rigOp "$rigTmp/m5" --member-inbox-to-processed rig-member note-20261006T0930Z-given.md --include-processed --upsert-from-stdin
rigAssert "the edit is applied, where the item is"     "$( cat "$rigTmp/m5.rc" ):$( rigHolds "$rigInbox/processed/note-20261006T0930Z-given.md" 'rewritten body' ):$( rigIs "$rigInbox/incoming/note-20261006T0930Z-given.md" )" "0:yes:none"
rigAssert "processed-at keeps its original time"       "$( rigField "$rigInbox/processed/note-20261006T0930Z-given.md" processed-at )" "2020-02-02 02:02 +0000"

echo "-- without --include-processed an operation sees only incoming/ --"
rigOp "$rigTmp/m6" --member-inbox-to-processed rig-member note-20261006T0930Z-given.md --header:upsert:x:y
rigAssert "an edit of a processed item without the option finds no item, and changes nothing" "$( [ "$( cat "$rigTmp/m6.rc" )" -ne 0 ] && printf refused || printf accepted ):$( rigFieldCount "$rigInbox/processed/note-20261006T0930Z-given.md" x )" "refused:0"

echo "-- refusals --"
rigOp "$rigTmp/m8" --librarian-inbox-to-processed keeper-rig note-rig.md
rigAssert "a missing inbox is refused"                 "$( [ "$( cat "$rigTmp/m8.rc" )" -ne 0 ] && printf refused || printf accepted )" refused
rigAssert "and no inbox is created, nor its folders"  "$( [ -e "$rigData/inboxes/keeper-rig" ] && printf yes || printf no )" no
rigOp "$rigTmp/m9" --member-inbox-to-processed rig-member note-20261006T0930Z-absent.md
rigAssert "a missing item is refused"                  "$( [ "$( cat "$rigTmp/m9.rc" )" -ne 0 ] && printf refused || printf accepted )" refused

echo "-- readers: active scans drop marked items, named reads still find them --"
printf -- '---\ntype: note\n---\nstill open\n' > "$rigInbox/incoming/note-20261006T0931Z-open.md"
printf -- '---\ntype: note\nprocessed-at: 2026-01-01 00:00 +0000\n---\nlegacy\n' > "$rigInbox/processed/note-20260101T0000Z-legacy.md"
rigOp "$rigTmp/r1" --intern-op-member-work-session-input-scan rig-member
rigAssert "the scan runs"                              "$( cat "$rigTmp/r1.rc" )" 0
rigAssert "an unmarked note is listed"                 "$( rigHolds "$rigTmp/r1" 'note-20261006T0931Z-open.md' )" yes
rigAssert "a marked note is not"                       "$( rigHolds "$rigTmp/r1" 'note-20261006T0930Z-plain.md' )" no
rigAssert "nor another processed/ one"                "$( rigHolds "$rigTmp/r1" 'note-20260101T0000Z-legacy.md' )" no
printf -- '---\ntype: inquiry\nprocessed-at: 2026-10-01 00:00 +0000\n---\nmarked q\n' > "$rigInbox/processed/inquiry-20261001T0000Z-marked.md"
printf -- '---\ntype: inquiry\n---\nopen q\n' > "$rigInbox/incoming/inquiry-20261001T0000Z-open.md"
printf -- '---\ntype: inquiry\n---\nlegacy q\n' > "$rigInbox/processed/inquiry-20261001T0000Z-legacy.md"
for rigScope in active all ; do
	rigOp "$rigTmp/r-$rigScope" --intern-op-session-context-scan rig-member --all-types "--do-inbox-inquiry-$rigScope" \
		--no-slack --no-email --no-trello --no-board-related --no-inbox-reflections --no-inbox-notes --no-inbox-other --context rig
done
rigAssert "inquiry -active: the open one only"         "$( cat "$rigTmp/r-active.rc" ):$( rigHolds "$rigTmp/r-active" 'open q' ):$( rigHolds "$rigTmp/r-active" 'marked q' ):$( rigHolds "$rigTmp/r-active" 'legacy q' )" "0:yes:no:no"
rigAssert "inquiry -all: the processed ones included"   "$( cat "$rigTmp/r-all.rc" ):$( rigHolds "$rigTmp/r-all" 'open q' ):$( rigHolds "$rigTmp/r-all" 'marked q' ):$( rigHolds "$rigTmp/r-all" 'legacy q' )" "0:yes:yes:yes"
rigOp "$rigTmp/r2" --member-inbox-item-read rig-member note-20261006T0930Z-plain.md --include-processed
rigAssert "a marked item is read by name, with --include-processed" "$( cat "$rigTmp/r2.rc" ):$( rigHolds "$rigTmp/r2" 'plain body line' )" "0:yes"
rigOp "$rigTmp/r3" --member-inbox-item-read rig-member note-20261006T0930Z-plain.md
rigAssert "without it, a named read sees only incoming/: not found" "$( [ "$( cat "$rigTmp/r3.rc" )" -ne 0 ] && printf non-zero || printf 0 ):$( rigHolds "$rigTmp/r3" 'plain body line' )" "non-zero:no"
rigOp "$rigTmp/r4" --member-inbox-item-read rig-member note-20261006T0931Z-open.md
rigAssert "an incoming item is read by name"           "$( cat "$rigTmp/r4.rc" ):$( rigHolds "$rigTmp/r4" 'still open' )" "0:yes"

echo "-- GC: marked items by their stamp's age, never an unmarked one --"
rigG="$rigTmp/gc"
mkdir -p "$rigG/inboxes/rig-member/processed" "$rigG/inboxes/rig-member/incoming" "$rigG/board"
rigGi="$rigG/inboxes/rig-member"
printf -- '---\ntype: note\nprocessed-at: 2020-01-01 00:00 +0000\n---\nold marked\n' > "$rigGi/processed/note-20200101T0000Z-old.md"
printf -- '---\ntype: note\n---\nold standing note\n' > "$rigGi/incoming/note-20200101T0000Z-standing.md"
touch -t 202001010000 "$rigGi/incoming/note-20200101T0000Z-standing.md"
printf 'old body with no frontmatter\n' > "$rigGi/incoming/inquiry-20200101T0000Z-unhandled.md"
touch -t 202001010000 "$rigGi/incoming/inquiry-20200101T0000Z-unhandled.md"
printf -- '---\ntype: note\nprocessed-at: %s\n---\nfresh marked\n' "$( date +"%Y-%m-%d %H:%M %z" )" > "$rigGi/processed/note-20261006T0000Z-fresh.md"
printf -- '---\ntype: note\nprocessed-at: %s\n---\nthree days\n' "$( rigDaysAgo 3 )" > "$rigGi/processed/note-20261003T0000Z-three.md"
printf -- '---\ntype: reflection\nprocessed-at: %s\n---\ntwo days\n' "$( rigDaysAgo 2 )" > "$rigGi/processed/reflection-20261004T0000Z-two.md"
printf -- '---\ntype: note\nprocessed-at: someday\n---\nunreadable\n' > "$rigGi/processed/note-20200101T0000Z-unreadable.md"
printf -- '---\ntype: note\n---\nbody line\nprocessed-at: 2020-01-01 00:00 +0000\n' > "$rigGi/incoming/note-20200101T0000Z-bodyline.md"
printf -- '---\ntype: note\n---\nlegacy old\n' > "$rigGi/processed/note-20200101T0000Z-legacy-old.md"
touch -t 202001010000 "$rigGi/processed/note-20200101T0000Z-legacy-old.md"
printf -- '---\ntype: note\n---\nlegacy young\n' > "$rigGi/processed/note-20261006T0000Z-legacy-young.md"
RIG_DATA="$rigG" rigOp "$rigTmp/g1" --intern-team-data-final-gc-deletion rig-member
rigAssert "the pass deletes"                           "$( cat "$rigTmp/g1.rc" )" 0
rigAssert "the summary counts three inbox items"       "$( rigHolds "$rigTmp/g1" 'team-data-final-gc: 3 inbox-items' )" yes
rigAssert "an old marked item is deleted"              "$( rigIs "$rigGi/processed/note-20200101T0000Z-old.md" )" none
rigAssert "a marked reflection past one day is deleted" "$( rigIs "$rigGi/processed/reflection-20261004T0000Z-two.md" )" none
rigAssert "an old unmarked note is kept"               "$( rigIs "$rigGi/incoming/note-20200101T0000Z-standing.md" )" file
rigAssert "an old item with no frontmatter is kept"    "$( rigIs "$rigGi/incoming/inquiry-20200101T0000Z-unhandled.md" )" file
rigAssert "a freshly marked item is kept"              "$( rigIs "$rigGi/processed/note-20261006T0000Z-fresh.md" )" file
rigAssert "a note marked three days ago is kept"       "$( rigIs "$rigGi/processed/note-20261003T0000Z-three.md" )" file
rigAssert "an unreadable stamp is kept, with a warning" "$( rigIs "$rigGi/processed/note-20200101T0000Z-unreadable.md" ):$( rigHolds "$rigTmp/g1" 'note-20200101T0000Z-unreadable.md' )" "file:yes"
rigAssert "a body line is not a stamp"                 "$( rigIs "$rigGi/incoming/note-20200101T0000Z-bodyline.md" )" file
rigAssert "an old processed/ item with no stamp is drained by its age, as before"   "$( rigIs "$rigGi/processed/note-20200101T0000Z-legacy-old.md" )" none
rigAssert "a young one is kept"     "$( rigIs "$rigGi/processed/note-20261006T0000Z-legacy-young.md" )" file
RIG_DATA="$rigG" rigOp "$rigTmp/g2" --intern-team-data-final-gc-deletion rig-member
rigAssert "a second pass deletes nothing (rc 2)"       "$( cat "$rigTmp/g2.rc" )" 2

echo "-- git-tracked root: the mark and the collection are committed --"
if command -v git > /dev/null 2>&1 ; then
	rigT="$rigTmp/tracked"
	mkdir -p "$rigT/inboxes/rig-member/incoming" "$rigT/inboxes/rig-member/processed"
	printf -- '---\ntype: note\n---\ntracked\n' > "$rigT/inboxes/rig-member/incoming/note-20261006T0930Z-tracked.md"
	printf -- '---\ntype: note\nprocessed-at: 2020-01-01 00:00 +0000\n---\ntracked old\n' > "$rigT/inboxes/rig-member/processed/note-20200101T0000Z-tracked-old.md"
	rigGit(){ env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="/usr/bin:/bin" git -C "$rigT" "$@" ; }
	rigGit init -q && rigGit config user.email rig@example.invalid && rigGit config user.name rig \
		&& rigGit add -A && rigGit commit -q -m seed || rigRefuse "could not seed the tracked root"
	RIG_DATA="$rigT" rigOp "$rigTmp/t1" --member-inbox-to-processed rig-member note-20261006T0930Z-tracked.md
	rigAssert "the mark succeeds"                      "$( cat "$rigTmp/t1.rc" )" 0
	rigAssert "and is committed as processed"          "$( rigGit log -1 --format=%s ):$( rigGit status --porcelain | LC_ALL=C awk 'END { print NR }' )" "* processed: --member-inbox-to-processed:0"
	rigAssert "the committed item carries the stamp, in processed/" "$( rigGit show HEAD:inboxes/rig-member/processed/note-20261006T0930Z-tracked.md | LC_ALL=C grep -c '^processed-at: ' )" 1
	rigAssert "and incoming/ holds it no more, committed"  "$( rigGit ls-tree -r --name-only HEAD | LC_ALL=C grep -c -x 'inboxes/rig-member/incoming/note-20261006T0930Z-tracked.md' )" 0
	rigCommits="$( rigGit rev-list --count HEAD )"
	RIG_DATA="$rigT" rigOp "$rigTmp/t1b" --member-inbox-to-processed rig-member note-20261006T0930Z-tracked.md --include-processed --header:upsert:type:note
	rigAssert "an edit that changes no byte succeeds, no commit" "$( cat "$rigTmp/t1b.rc" ):$(( $( rigGit rev-list --count HEAD ) - rigCommits ))" "0:0"
	RIG_DATA="$rigT" rigOp "$rigTmp/t2" --intern-team-data-final-gc-deletion rig-member
	rigAssert "the GC deletes the old marked item"     "$( cat "$rigTmp/t2.rc" ):$( rigIs "$rigT/inboxes/rig-member/processed/note-20200101T0000Z-tracked-old.md" )" "0:none"
	rigAssert "and commits the deletion"               "$( rigGit log -1 --format=%s ):$( rigGit status --porcelain | LC_ALL=C awk 'END { print NR }' )" "- team-data-final-gc-deletion:0"
else
	echo "  SKIP  git not on PATH"
fi

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ INBOX TO PROCESSED CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'INBOX_TO_PROCESSED: OK (%d assertions, offline)\n' "$rigPassCount"
