#!/usr/bin/env bash
## The apply tool (W2, DistroAgentsTesting.fn.sh --apply-tool) against a throwaway rig: the four beats mark, level, plan and
## apply, and the faults the tool refuses. Each scenario runs the operation in its own bash, on a rig whose repository is
## OUTSIDE the workspace it runs in, one repository per call. Nothing touches a real tree; the lock lives under the rig.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTesting.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigFn" ] || rigRefuse "the tool file is not there: $rigFn"
command -v diff3 > /dev/null 2>&1 || rigRefuse "diff3 is not on PATH"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsApplyToolCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigSum(){ ## file -- the checksum the level keeps, as levelled.sums holds it
	LC_ALL=C cksum < "$1" | LC_ALL=C awk '{ print $1 "-" $2 }'
}

## The rig: a builder workspace (the lock lives under its .local/temp), a repository OUTSIDE it, and this work's scratch.
rigWs="$rigTmp/ws"
rigRepo="$rigTmp/repo"
rigScratch="$rigTmp/scratch"
rigLiveD="$rigRepo/source/myx/p/d"
rigMineD="$rigScratch/source/myx/p/d"
rigBaseD="$rigScratch/base/p/d"

## One run of the operation, in its own bash, with the workspace and the repository it applies to. Output and rc captured.
rigOp(){ ## result file, the operation's verb and arguments...
	local res="$1" ; shift
	env MMDAPP="$rigWs" MDAT_APPLY_BEFORE_PUT="${MDAT_APPLY_BEFORE_PUT:-}" MDAT_APPLY_BEFORE_CHECK="${MDAT_APPLY_BEFORE_CHECK:-}" "$BASH" -c '
		. "$1" ; shift
		DistroAgentsTesting --apply-tool "$@"
	' _ "$rigFn" "$@" > "$res" 2>&1
	printf '%s' "$?" > "$res.rc"
}
rigOut(){ cat "$1" ; }

## The base scenario: live holds a.sh (shell) and b.txt; this work adds MINE to each; both marked, apply-order the same.
rigFresh(){
	rm -rf "$rigWs" "$rigRepo" "$rigScratch"
	mkdir -p "$rigWs/.local/temp" "$rigLiveD" "$rigBaseD" "$rigMineD"
	printf 'one\ntwo\nthree\nfour\nfive\nsix\nseven\neight\n' > "$rigLiveD/a.sh"
	cp -p "$rigLiveD/a.sh" "$rigBaseD/a.sh"
	printf 'alpha\nbeta\n' > "$rigLiveD/b.txt"
	cp -p "$rigLiveD/b.txt" "$rigBaseD/b.txt"
	sed 's/^two$/two MINE/' "$rigLiveD/a.sh" > "$rigMineD/a.sh"
	printf 'alpha\nbeta MINE\n' > "$rigMineD/b.txt"
	printf 'p/d/a.sh\np/d/b.txt\n' > "$rigScratch/changed-files.txt"
	cp -p "$rigScratch/changed-files.txt" "$rigScratch/apply-order.txt"
	printf 'p\n' > "$rigScratch/packages.txt"
}

## The rename and removal scenario: on top of the base one, live holds c.txt too; this work removes b.txt and renames
## d/c.txt to e/c.txt. Both sources are marked with their base, the new path is listed with none.
rigRename(){
	rigFresh
	printf 'gamma\n' > "$rigLiveD/c.txt" ; cp -p "$rigLiveD/c.txt" "$rigBaseD/c.txt"
	rm -f "$rigMineD/b.txt"
	mkdir -p "$rigScratch/source/myx/p/e" ; cp -p "$rigLiveD/c.txt" "$rigScratch/source/myx/p/e/c.txt"
	printf 'p/d/b.txt\np/d/c.txt\np/e/c.txt\n' > "$rigScratch/changed-files.txt"
	cp -p "$rigScratch/changed-files.txt" "$rigScratch/apply-order.txt"
	printf 'p/d/b.txt\n' > "$rigScratch/removals.txt"
	printf 'p/d/c.txt\tp/e/c.txt\n' > "$rigScratch/renames.txt"
}
rigLiveE="$rigRepo/source/myx/p/e"

echo "-- live at its base --"
rigFresh ; rigOp "$rigTmp/base.out" apply --repository "$rigRepo" --scratch "$rigScratch"
rigAssert "both files put in place"              "$( LC_ALL=C grep -c 'two MINE' "$rigLiveD/a.sh" )$( LC_ALL=C grep -c 'beta MINE' "$rigLiveD/b.txt" )" 11
rigAssert "the lock is given back, no temp left" "$( ls "$rigWs/.local/temp" | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ):$( ls "$rigLiveD" | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 0:2
rigAssert "the apply ends well"                  "$( cat "$rigTmp/base.out.rc" )" 0

echo "-- live moved on a line far from this work's: the merge is made now, the other's hunk stays --"
rigFresh ; sed 's/^seven$/seven THEIRS/' "$rigLiveD/a.sh" > "$rigTmp/x" && mv "$rigTmp/x" "$rigLiveD/a.sh"
rigOp "$rigTmp/clean.out" apply --repository "$rigRepo" --scratch "$rigScratch"
rigAssert "this work's line and the other's both stand" "$( LC_ALL=C grep -c -e 'two MINE' -e 'seven THEIRS' "$rigLiveD/a.sh" )" 2
rigAssert "reported as merged"                          "$( LC_ALL=C grep -c 'put in place (merged): p/d/a.sh' "$rigTmp/clean.out" )" 1
rigAssert "the apply ends well"                         "$( cat "$rigTmp/clean.out.rc" )" 0

echo "-- live moved on the very line this work changes: nothing is put in place --"
rigFresh ; sed 's/^two$/two THEIRS/' "$rigLiveD/a.sh" > "$rigTmp/x" && mv "$rigTmp/x" "$rigLiveD/a.sh"
rigOp "$rigTmp/unclean.out" apply --repository "$rigRepo" --scratch "$rigScratch"
rigAssert "refused, and the second file is untouched" "$( LC_ALL=C grep -c 'not mergeable cleanly and exactly now: p/d/a.sh' "$rigTmp/unclean.out" ):$( LC_ALL=C grep -c MINE "$rigLiveD/b.txt" )" 1:0
rigAssert "no temp left and the lock is given back"   "$( ls "$rigWs/.local/temp" | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ):$( ls "$rigLiveD" | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 0:2
rigAssert "the apply ends not-ready"                   "$( cat "$rigTmp/unclean.out.rc" )" 4

echo "-- live moves between the staging and the rename of a file --"
rigFresh ; MDAT_APPLY_BEFORE_PUT="printf 'alpha\nbeta\ngamma THEIRS\n' > \"$rigLiveD/b.txt\""
rigOp "$rigTmp/moved.out" apply --repository "$rigRepo" --scratch "$rigScratch"
unset MDAT_APPLY_BEFORE_PUT
rigAssert "the first is in place, the second is not: it moved, and the apply says so" \
	"$( LC_ALL=C grep -c 'two MINE' "$rigLiveD/a.sh" ):$( LC_ALL=C grep -c 'gamma THEIRS' "$rigLiveD/b.txt" ):$( LC_ALL=C grep -c MINE "$rigLiveD/b.txt" ):$( LC_ALL=C grep -c 'p/d/b.txt moved on live after it was staged' "$rigTmp/moved.out" )" 1:1:0:1
rigAssert "no temp left and the lock is given back" "$( ls "$rigWs/.local/temp" | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ):$( ls "$rigLiveD" | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 0:2
rigAssert "the apply ends stopped"                  "$( cat "$rigTmp/moved.out.rc" )" 5

echo "-- a new file --"
rigFresh ; printf 'new line\n' > "$rigMineD/new.sh"
printf 'p/d/new.sh\np/d/a.sh\np/d/b.txt\n' > "$rigScratch/changed-files.txt"
cp -p "$rigScratch/changed-files.txt" "$rigScratch/apply-order.txt"
rigOp "$rigTmp/new.out" apply --repository "$rigRepo" --scratch "$rigScratch"
rigAssert "the new file stands on live"          "$( [ -f "$rigLiveD/new.sh" ] && LC_ALL=C grep -c 'new line' "$rigLiveD/new.sh" || printf '-' )" 1
rigAssert "reported as new"                       "$( LC_ALL=C grep -c 'put in place (new): p/d/new.sh' "$rigTmp/new.out" )" 1
rigAssert "the apply ends well"                   "$( cat "$rigTmp/new.out.rc" )" 0

echo "-- plan: the dry run, read-only, with the removed and added lines --"
rigFresh ; rigOp "$rigTmp/plan.out" plan --repository "$rigRepo" --scratch "$rigScratch"
rigAssert "names each at its base with what this work removes and adds" "$( LC_ALL=C grep -c 'at base:' "$rigTmp/plan.out" ):$( LC_ALL=C grep -c '1 removed, 1 added' "$rigTmp/plan.out" ):$( LC_ALL=C grep -c MINE "$rigLiveD/a.sh" )" 2:2:0
rigAssert "the plan ends well and read-only"      "$( cat "$rigTmp/plan.out.rc" )" 0

echo "-- plan whose removed lines differ: live moved on the very line --"
rigFresh ; sed 's/^two$/two THEIRS/' "$rigLiveD/a.sh" > "$rigTmp/x" && mv "$rigTmp/x" "$rigLiveD/a.sh"
rigOp "$rigTmp/planbad.out" plan --repository "$rigRepo" --scratch "$rigScratch"
rigAssert "refused, and read-only" "$( LC_ALL=C grep -c 'MOVED, DOES NOT MERGE: p/d/a.sh' "$rigTmp/planbad.out" ):$( LC_ALL=C grep -c MINE "$rigLiveD/a.sh" )" 1:0
rigAssert "the plan ends not-ready" "$( cat "$rigTmp/planbad.out.rc" )" 4

echo "-- mark: a base taken after the edit is refused --"
rigFresh ; sed 's/^two$/two EDITED/' "$rigLiveD/a.sh" > "$rigMineD/a.sh" ; : > "$rigScratch/changed-files.txt"
rigOp "$rigTmp/markbad.out" mark --repository "$rigRepo" --scratch "$rigScratch" p/d/a.sh
rigAssert "refused: the scratch copy is not live's text now" "$( LC_ALL=C grep -c 'REFUSED: p/d/a.sh' "$rigTmp/markbad.out" ):$( LC_ALL=C grep -c 'not live.s text now' "$rigTmp/markbad.out" )" 1:1
rigAssert "and not listed"                                    "$( LC_ALL=C grep -c '^p/d/a.sh$' "$rigScratch/changed-files.txt" || : )" 0

echo "-- mark: a file that is still live's text is marked, with its base --"
rigFresh ; : > "$rigScratch/changed-files.txt" ; cp -p "$rigLiveD/a.sh" "$rigMineD/a.sh"
rigOp "$rigTmp/mark.out" mark --repository "$rigRepo" --scratch "$rigScratch" p/d/a.sh
rigAssert "marked and listed"           "$( LC_ALL=C grep -c 'marked: p/d/a.sh' "$rigTmp/mark.out" ):$( LC_ALL=C grep -c '^p/d/a.sh$' "$rigScratch/changed-files.txt" )" 1:1
rigAssert "its base is live's text now" "$( cmp -s "$rigLiveD/a.sh" "$rigBaseD/a.sh" && printf yes || printf no )" yes

echo "-- level: an unmarked file already edited is not overwritten --"
rm -rf "$rigRepo" "$rigScratch" ; mkdir -p "$rigLiveD" "$rigMineD"
printf 'one\ntwo\nthree\n' > "$rigLiveD/a.sh"
printf 'one\ntwo EDITED\nthree\n' > "$rigMineD/a.sh"
printf 'p\n' > "$rigScratch/packages.txt" ; : > "$rigScratch/changed-files.txt"
printf '%s %s\n' 'p/d/a.sh' "$( rigSum "$rigLiveD/a.sh" )" > "$rigScratch/levelled.sums"
rigOp "$rigTmp/levelbad.out" level --repository "$rigRepo" --scratch "$rigScratch"
rigAssert "refused, and left alone" "$( LC_ALL=C grep -c 'EDITED UNMARKED: p/d/a.sh' "$rigTmp/levelbad.out" ):$( LC_ALL=C grep -c 'two EDITED' "$rigMineD/a.sh" )" 1:1
rigAssert "the level ends in conflict" "$( cat "$rigTmp/levelbad.out.rc" )" 1

echo "-- level: a file a level brought from live and live no longer holds is removed from the scratch --"
rm -rf "$rigRepo" "$rigScratch" ; mkdir -p "$rigLiveD" "$rigMineD"
printf 'one\ntwo\nthree\n' > "$rigLiveD/a.sh"
cp -p "$rigLiveD/a.sh" "$rigMineD/a.sh"
printf 'gone\n' > "$rigMineD/c.txt"
printf 'p\n' > "$rigScratch/packages.txt" ; : > "$rigScratch/changed-files.txt"
printf '%s %s\n' 'p/d/c.txt' "$( rigSum "$rigMineD/c.txt" )" > "$rigScratch/levelled.sums"
rigOp "$rigTmp/leveldel.out" level --repository "$rigRepo" --scratch "$rigScratch"
rigAssert "removed, and said so" "$( LC_ALL=C grep -c 'gone from live, removed from the scratch (not mine): p/d/c.txt' "$rigTmp/leveldel.out" ):$( [ -f "$rigMineD/c.txt" ] && printf kept || printf gone )" 1:gone
rigAssert "the level ends well" "$( cat "$rigTmp/leveldel.out.rc" )" 0

echo "-- level: a new file the builder made and has not marked yet is kept --"
rm -rf "$rigRepo" "$rigScratch" ; mkdir -p "$rigLiveD" "$rigMineD"
printf 'one\ntwo\nthree\n' > "$rigLiveD/a.sh"
cp -p "$rigLiveD/a.sh" "$rigMineD/a.sh"
printf 'a draft\n' > "$rigMineD/draft.md"
printf 'level brought it, the builder edited it\n' > "$rigMineD/edited.txt"
printf 'p\n' > "$rigScratch/packages.txt" ; : > "$rigScratch/changed-files.txt"
printf '%s %s\n' 'p/d/edited.txt' "$( printf 'as level left it\n' | LC_ALL=C cksum | LC_ALL=C awk '{ print $1 "-" $2 ; }' )" > "$rigScratch/levelled.sums"
rigOp "$rigTmp/levelnew.out" level --repository "$rigRepo" --scratch "$rigScratch"
rigAssert "the draft and the edited file are kept, and said to be new and unmarked" \
	"$( LC_ALL=C grep -c -e 'new, unmarked: p/d/draft.md' -e 'new, unmarked: p/d/edited.txt' "$rigTmp/levelnew.out" ):$( [ -f "$rigMineD/draft.md" ] && [ -f "$rigMineD/edited.txt" ] && printf kept || printf gone )" 2:kept
rigAssert "the level ends well" "$( cat "$rigTmp/levelnew.out.rc" )" 0

rigTempLeft(){ ls "$rigWs/.local/temp" | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ; }

echo "-- a rename and a removal at their base: written first, removed last, each step recorded --"
rigRename ; rigOp "$rigTmp/ren.out" apply --repository "$rigRepo" --scratch "$rigScratch"
rigAssert "the new path stands, both sources are gone" \
	"$( [ -f "$rigLiveE/c.txt" ] && printf new )$( [ -e "$rigLiveD/c.txt" ] || printf '%s' -old )$( [ -e "$rigLiveD/b.txt" ] || printf '%s' -removed )" "new-old-removed"
rigAssert "the removals come after every write" \
	"$( LC_ALL=C awk '/^put in place/ { p = NR } /^removed:/ && !r { r = NR } END { print ( p && r && p < r ) ? "after" : "before" }' "$rigTmp/ren.out" )" after
rigAssert "each step is in the record" \
	"$( LC_ALL=C awk -F'\t' 'NF == 3 && ( $1 " " $2 == "put p/e/c.txt" || $1 " " $2 == "removed p/d/b.txt" || $1 " " $2 == "removed p/d/c.txt" ) { n++ ; } END { print n + 0 ; }' "$rigScratch/applied-steps.txt" 2> /dev/null )" 3

echo "-- a record line of another work is no step of this one --"
rigRename ; printf 'put\tp/e/c.txt\tsome-other-work\n' > "$rigScratch/applied-steps.txt" ; mkdir -p "$rigLiveE" ; cp -p "$rigScratch/source/myx/p/e/c.txt" "$rigLiveE/c.txt"
rigOp "$rigTmp/stale.out" apply --repository "$rigRepo" --scratch "$rigScratch"
rigAssert "not taken as done: the new path is already on live, and the apply refuses" \
	"$( LC_ALL=C grep -c 'done already' "$rigTmp/stale.out" ):$( LC_ALL=C grep -c 'EXISTS on live, though new in this work: p/e/c.txt' "$rigTmp/stale.out" ):$( cat "$rigTmp/stale.out.rc" )" 0:1:4

echo "-- a removed file back on live by the check: STILL ON LIVE, and not ended well --"
rigRename ; MDAT_APPLY_BEFORE_CHECK="printf 'back\n' > \"$rigLiveD/b.txt\""
rigOp "$rigTmp/still.out" apply --repository "$rigRepo" --scratch "$rigScratch"
unset MDAT_APPLY_BEFORE_CHECK
rigAssert "said, and the apply ends 6 with the lock given back" "$( LC_ALL=C grep -c 'STILL ON LIVE: p/d/b.txt' "$rigTmp/still.out" ):$( cat "$rigTmp/still.out.rc" ):$( rigTempLeft )" 1:6:0

echo "-- a shell file that no longer parses on live by the check: SYNTAX AFTER APPLY, and not ended well --"
rigFresh ; MDAT_APPLY_BEFORE_CHECK="printf 'if then\n' > \"$rigLiveD/a.sh\""
rigOp "$rigTmp/syntax.out" apply --repository "$rigRepo" --scratch "$rigScratch"
unset MDAT_APPLY_BEFORE_CHECK
rigAssert "said, and the apply ends 7 with the lock given back" "$( LC_ALL=C grep -c 'SYNTAX AFTER APPLY: p/d/a.sh' "$rigTmp/syntax.out" ):$( cat "$rigTmp/syntax.out.rc" ):$( rigTempLeft )" 1:7:0

echo "-- plan and apply with no packages.txt: an error, rc 1 --"
rigRename ; rm -f "$rigScratch/packages.txt"
rigOp "$rigTmp/nopkg.plan" plan --repository "$rigRepo" --scratch "$rigScratch"
rigOp "$rigTmp/nopkg.out" apply --repository "$rigRepo" --scratch "$rigScratch"
rigAssert "both refuse, naming packages.txt" "$( LC_ALL=C grep -c 'packages.txt is not there' "$rigTmp/nopkg.plan" "$rigTmp/nopkg.out" | LC_ALL=C awk -F: '{ n += $NF ; } END { print n + 0 ; }' ):$( cat "$rigTmp/nopkg.plan.rc" ):$( cat "$rigTmp/nopkg.out.rc" )" 2:1:1
rigAssert "the lock is given back, the unmarked a.sh untouched" "$( rigTempLeft ):$( LC_ALL=C grep -c MINE "$rigLiveD/a.sh" )" 0:0
rigAssert "the apply ends well" "$( cat "$rigTmp/ren.out.rc" )" 0

echo "-- plan of a rename and a removal: named, read-only --"
rigRename ; rigOp "$rigTmp/renplan.out" plan --repository "$rigRepo" --scratch "$rigScratch"
rigAssert "the rename and the removal are named, nothing changed" \
	"$( LC_ALL=C grep -c -x -e 'rename: p/d/c.txt -> p/e/c.txt (this work: 0 removed, 0 added)' -e 'remove: p/d/b.txt' "$rigTmp/renplan.out" ):$( [ -f "$rigLiveD/b.txt" ] && [ ! -e "$rigLiveE/c.txt" ] && printf same )" 2:same
rigAssert "the plan ends well" "$( cat "$rigTmp/renplan.out.rc" )" 0

echo "-- a removal source live changed since its base: never merged, refused --"
rigRename ; printf 'alpha\nbeta\ngamma THEIRS\n' > "$rigLiveD/b.txt"
rigOp "$rigTmp/remmoved.plan" plan --repository "$rigRepo" --scratch "$rigScratch"
rigOp "$rigTmp/remmoved.out" apply --repository "$rigRepo" --scratch "$rigScratch"
rigAssert "the plan and the apply refuse it, and nothing is put or removed" \
	"$( LC_ALL=C grep -c 'never merged: p/d/b.txt' "$rigTmp/remmoved.plan" ):$( LC_ALL=C grep -c 'never merged: p/d/b.txt' "$rigTmp/remmoved.out" ):$( [ -f "$rigLiveD/c.txt" ] && [ ! -e "$rigLiveE/c.txt" ] && printf untouched )" 1:1:untouched
rigAssert "both end not-ready, the lock given back" "$( cat "$rigTmp/remmoved.plan.rc" ):$( cat "$rigTmp/remmoved.out.rc" ):$( rigTempLeft )" 4:4:0

echo "-- a marked file gone on live: level, plan and apply say so --"
rigRename ; rm -f "$rigLiveD/b.txt" "$rigLiveD/a.sh"
printf 'p/d/a.sh\np/d/b.txt\np/d/c.txt\np/e/c.txt\n' > "$rigScratch/changed-files.txt" ; cp -p "$rigScratch/changed-files.txt" "$rigScratch/apply-order.txt"
rigOp "$rigTmp/gone.level" level --repository "$rigRepo" --scratch "$rigScratch"
rigOp "$rigTmp/gone.plan" plan --repository "$rigRepo" --scratch "$rigScratch"
rigOp "$rigTmp/gone.out" apply --repository "$rigRepo" --scratch "$rigScratch"
rigAssert "level: a conflict naming each" "$( LC_ALL=C grep -c -e 'GONE on live: p/d/a.sh' -e 'GONE on live: p/d/b.txt' "$rigTmp/gone.level" ):$( cat "$rigTmp/gone.level.rc" )" 2:1
rigAssert "plan: gone on live, naming each" "$( LC_ALL=C grep -c -e 'GONE on live: p/d/a.sh' -e 'GONE on live: p/d/b.txt' "$rigTmp/gone.plan" ):$( cat "$rigTmp/gone.plan.rc" )" 2:4
rigAssert "apply: gone on live, nothing done" "$( LC_ALL=C grep -c 'GONE on live: p/d/' "$rigTmp/gone.out" ):$( cat "$rigTmp/gone.out.rc" ):$( [ -f "$rigLiveD/c.txt" ] && printf kept )" 1:4:kept

echo "-- a removal source moves between the staging and its removal --"
rigRename ; MDAT_APPLY_BEFORE_PUT="printf 'alpha\nbeta\ngamma THEIRS\n' > \"$rigLiveD/b.txt\""
rigOp "$rigTmp/remlate.out" apply --repository "$rigRepo" --scratch "$rigScratch"
unset MDAT_APPLY_BEFORE_PUT
rigAssert "the write is done, the moved file is not removed, and the apply says so" \
	"$( [ -f "$rigLiveE/c.txt" ] && printf put ):$( LC_ALL=C grep -c 'gamma THEIRS' "$rigLiveD/b.txt" ):$( LC_ALL=C grep -c 'p/d/b.txt moved on live after it was staged' "$rigTmp/remlate.out" )" put:1:1
rigAssert "the apply ends stopped, the lock given back" "$( cat "$rigTmp/remlate.out.rc" ):$( rigTempLeft )" 5:0

echo "-- resume: the same apply again, once live is back at the base, finishes from the record --"
printf 'alpha\nbeta\n' > "$rigLiveD/b.txt"
rigOp "$rigTmp/resume.out" apply --repository "$rigRepo" --scratch "$rigScratch"
rigAssert "the recorded write is taken as done, the removals are made" \
	"$( LC_ALL=C grep -c 'done already (record): p/e/c.txt' "$rigTmp/resume.out" ):$( [ -e "$rigLiveD/b.txt" ] || printf gone )$( [ -e "$rigLiveD/c.txt" ] || printf '%s' -gone ):$( cat "$rigTmp/resume.out.rc" )" "1:gone-gone:0"

echo "-- the path rules --"
rigRename ; printf 'p/d/c.txt p/e/c.txt\n' > "$rigScratch/renames.txt"
rigOp "$rigTmp/path.tab" apply --repository "$rigRepo" --scratch "$rigScratch"
rigAssert "a renames line not parted by one tab is refused" "$( LC_ALL=C grep -c 'renames.txt: not <old><TAB><new>' "$rigTmp/path.tab" ):$( cat "$rigTmp/path.tab.rc" ):$( [ -f "$rigLiveD/b.txt" ] && printf kept )" 1:4:kept
rigRename ; printf 'p/d/../d/b.txt\n' > "$rigScratch/removals.txt"
printf 'p/d/../d/b.txt\np/d/c.txt\np/e/c.txt\n' > "$rigScratch/changed-files.txt" ; cp -p "$rigScratch/changed-files.txt" "$rigScratch/apply-order.txt"
rigOp "$rigTmp/path.dots" apply --repository "$rigRepo" --scratch "$rigScratch"
rigAssert "a path with .. is refused" "$( LC_ALL=C grep -c 'PATH REFUSED: p/d/../d/b.txt' "$rigTmp/path.dots" ):$( cat "$rigTmp/path.dots.rc" ):$( [ -f "$rigLiveD/b.txt" ] && printf kept )" 1:4:kept
rigRename ; printf 'q\n' > "$rigScratch/packages.txt"
rigOp "$rigTmp/path.pkg" apply --repository "$rigRepo" --scratch "$rigScratch"
rigAssert "a path outside the listed packages is refused" "$( LC_ALL=C grep -c 'PATH REFUSED: p/' "$rigTmp/path.pkg" ):$( cat "$rigTmp/path.pkg.rc" ):$( [ -f "$rigLiveD/b.txt" ] && printf kept )" 1:4:kept
rigRename ; mv "$rigLiveD/b.txt" "$rigTmp/b.real" ; ln -s "$rigTmp/b.real" "$rigLiveD/b.txt"
rigOp "$rigTmp/path.link" apply --repository "$rigRepo" --scratch "$rigScratch"
rigAssert "a symlink on live is refused and left" "$( LC_ALL=C grep -c 'PATH REFUSED: p/d/b.txt' "$rigTmp/path.link" ):$( cat "$rigTmp/path.link.rc" ):$( [ -L "$rigLiveD/b.txt" ] && printf kept )" 1:4:kept
if [ "$( uname -s )" = Darwin ] ; then
	rigRename ; printf 'p/d/c.txt\tp/d/C.txt\n' > "$rigScratch/renames.txt" ; mv "$rigScratch/source/myx/p/e/c.txt" "$rigMineD/C.txt"
	printf 'p/d/b.txt\np/d/c.txt\np/d/C.txt\n' > "$rigScratch/changed-files.txt" ; cp -p "$rigScratch/changed-files.txt" "$rigScratch/apply-order.txt"
	rigOp "$rigTmp/path.case" apply --repository "$rigRepo" --scratch "$rigScratch"
	rigAssert "a case-only rename is refused on macOS" "$( LC_ALL=C grep -c 'case-only rename' "$rigTmp/path.case" ):$( cat "$rigTmp/path.case.rc" )" 1:4
fi

echo "-- the lock: an owner file inside it, and given back on any exit --"
rigRename ; MDAT_APPLY_BEFORE_PUT="cat \"$rigWs/.local/temp/live-apply.lock/owner\" > \"$rigTmp/owner.seen\" ; exit 7"
rigOp "$rigTmp/lockexit.out" apply --repository "$rigRepo" --scratch "$rigScratch"
unset MDAT_APPLY_BEFORE_PUT
rigAssert "the owner file names the process and the time" "$( LC_ALL=C grep -c -E '^pid [0-9]+ at [0-9T:Z-]+' "$rigTmp/owner.seen" 2> /dev/null )" 1
rigAssert "an abrupt exit gives the lock back and leaves no staged temp beside live" \
	"$( rigTempLeft ):$( ls "$rigLiveD" | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ):$( ls "$rigLiveE" 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 0:3:0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ APPLY TOOL CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'APPLY_TOOL: OK (%d assertions, offline, throwaway rig)\n' "$rigPassCount"
