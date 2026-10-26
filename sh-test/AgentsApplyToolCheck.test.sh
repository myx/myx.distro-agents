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
	env MMDAPP="$rigWs" MDAT_APPLY_BEFORE_PUT="${MDAT_APPLY_BEFORE_PUT:-}" "$BASH" -c '
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
}

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

echo "-- level: a file gone from live is removed from the scratch --"
rm -rf "$rigRepo" "$rigScratch" ; mkdir -p "$rigLiveD" "$rigMineD"
printf 'one\ntwo\nthree\n' > "$rigLiveD/a.sh"
cp -p "$rigLiveD/a.sh" "$rigMineD/a.sh"
printf 'gone\n' > "$rigMineD/c.txt"
printf 'p\n' > "$rigScratch/packages.txt" ; : > "$rigScratch/changed-files.txt" ; : > "$rigScratch/levelled.sums"
rigOp "$rigTmp/leveldel.out" level --repository "$rigRepo" --scratch "$rigScratch"
rigAssert "removed, and said so" "$( LC_ALL=C grep -c 'gone from live, removed from the scratch (not mine): p/d/c.txt' "$rigTmp/leveldel.out" ):$( [ -f "$rigMineD/c.txt" ] && printf kept || printf gone )" 1:gone
rigAssert "the level ends well" "$( cat "$rigTmp/leveldel.out.rc" )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ APPLY TOOL CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'APPLY_TOOL: OK (%d assertions, offline, throwaway rig)\n' "$rigPassCount"
