#!/usr/bin/env bash
## Behavioural check on --commit-pending against temp git stores and
## temp bare remotes only -- never the real team data. The gating case is shaped like
## the real store: its own repository root, nested in plain folders, origin equal to
## TEAM_DATA_GIT_REMOTE, with added, changed and deleted paths pending and two commits
## already ahead of origin. The sync case is two clones of one bare remote, as two
## workspaces: the other one pushes, this one runs the op. Setup uses git on this rig's
## own mktemp trees only.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigFn="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
command -v git > /dev/null || rigRefuse "git is not installed"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsTeamDataCommitPendingCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigTmp="$( cd "$rigTmp" && pwd -P )"
mkdir -p "$rigTmp/ws/.local/.agents"
export GIT_AUTHOR_NAME=rig GIT_AUTHOR_EMAIL=rig@example.invalid GIT_COMMITTER_NAME=rig GIT_COMMITTER_EMAIL=rig@example.invalid

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## A store with one seed commit; with a remote named, a bare origin holding that seed.
## Shaped like a store myx.common git/cloneSync keeps: it holds a README.md, and its
## branch follows its namesake at origin.
rigStore(){ ## store path, bare remote path or empty
	mkdir -p "$1"
	git -C "$1" init -q || rigRefuse "could not init $1"
	printf 'keep\n' > "$1/keep.md"
	printf 'old\n' > "$1/change.md"
	printf 'bye\n' > "$1/gone.md"
	: > "$1/README.md"
	git -C "$1" add -A && git -C "$1" commit -q -m seed || rigRefuse "could not seed $1"
	[ -n "$2" ] || return 0
	git init -q --bare "$2" || rigRefuse "could not init the bare remote $2"
	git -C "$1" remote add origin "$2"
	git -C "$1" push -q -u origin HEAD 2>/dev/null || rigRefuse "could not seed the bare remote $2"
}
rigRemote(){ ## TEAM_DATA_GIT_REMOTE value, empty for none
	if [ -n "$1" ] ; then
		printf 'TEAM_DATA_GIT_REMOTE=%s\n' "$1" > "$rigTmp/ws/.local/.agents/magic-team.agent.env"
	else
		: > "$rigTmp/ws/.local/.agents/magic-team.agent.env"
	fi
}
## Always a fresh change: a second call on the same store must still leave something pending.
rigPendingRound=0
rigPending(){ ## store path
	rigPendingRound=$(( rigPendingRound + 1 ))
	[ ! -e "$1/added.md" ] || printf 'more %s\n' "$rigPendingRound" >> "$1/keep.md"
	printf 'new\n' > "$1/added.md"
	printf 'changed %s\n' "$rigPendingRound" > "$1/change.md"
	rm -f "$1/gone.md"
}
rigOp(){ ## store path, result file, member, extra args...
	local opStore="$1" opOut="$2" ; shift 2
	( cd "$rigTmp/ws" && env -u CLAUDE_CODE_ENTRYPOINT MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$opStore" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_WORKSPACE_MODE=team-rig \
		bash "$rigFn" --commit-pending "$@" ) > "$opOut" 2> "$opOut.err"
	printf '%s' "$?" > "$opOut.rc"
}
rigCount(){ git -C "$1" rev-list --count HEAD ; }
rigHolds(){ ## file, fixed text
	LC_ALL=C grep -q -F -- "$2" "$1" && printf yes || printf no
}

echo "-- gating: a store shaped like the real one --"
rigG="$rigTmp/plain/folders/store"
rigBare="$rigTmp/remote.git"
rigStore "$rigG" "$rigBare"
rigRemote "$rigBare"
rigBranch="$( git -C "$rigG" rev-parse --abbrev-ref HEAD )"
printf 'a1\n' > "$rigG/ahead1.md" && git -C "$rigG" add -A && git -C "$rigG" commit -q -m ahead1
printf 'a2\n' > "$rigG/ahead2.md" && git -C "$rigG" add -A && git -C "$rigG" commit -q -m ahead2
rigAssert "setup: two commits sit ahead of origin"     "$( git -C "$rigG" rev-list --count "origin/$rigBranch..HEAD" )" 2
rigPending "$rigG"
rigOp "$rigG" "$rigTmp/g" magic-coordinator
rigHead="$( git -C "$rigG" rev-parse HEAD )"
rigAssert "it exits 0"                                 "$( cat "$rigTmp/g.rc" )" 0
rigAssert "one commit of 3 paths"                      "$( LC_ALL=C grep -c "^TEAM-DATA-COMMITTED: [0-9a-f]* 3 path(s) under $rigG$" "$rigTmp/g" )" 1
rigAssert "the added path is listed as A"              "$( rigHolds "$rigTmp/g" "A	added.md" )" yes
rigAssert "the changed path as M"                      "$( rigHolds "$rigTmp/g" "M	change.md" )" yes
rigAssert "the deleted path as D"                      "$( rigHolds "$rigTmp/g" "D	gone.md" )" yes
rigAssert "the commit body lists the paths"            "$( git -C "$rigG" log -1 --format=%b | LC_ALL=C grep -c -E '^(A	added.md|M	change.md|D	gone.md)$' )" 3
rigAssert "pushed, read back as the local head"        "$( rigHolds "$rigTmp/g" "TEAM-DATA-PUSHED: $( git -C "$rigG" rev-parse --short HEAD ) to origin, read back as origin/$rigBranch = $rigHead" )" yes
rigAssert "the bare remote's branch is that head"      "$( git --git-dir="$rigBare" rev-parse "refs/heads/$rigBranch" )" "$rigHead"
rigAssert "carrying the two ahead commits and the new one" "$( git --git-dir="$rigBare" rev-list --count "refs/heads/$rigBranch" )" 4
rigAssert "the store is clean afterwards"              "$( [ -z "$( git -C "$rigG" status --porcelain --untracked-files=all )" ] && printf clean || printf dirty )" clean

echo "-- nothing pending --"
rigCountBefore="$( rigCount "$rigG" )"
rigOp "$rigG" "$rigTmp/n" magic-coordinator
rigAssert "it says nothing is pending"                 "$( LC_ALL=C grep -c "^TEAM-DATA-NOTHING-PENDING: $rigG$" "$rigTmp/n" )" 1
rigAssert "and makes no commit"                        "$( rigCount "$rigG" )" "$rigCountBefore"

echo "-- refusals --"
rigPending "$rigG"
rigCountBefore="$( rigCount "$rigG" )"
rigOp "$rigG" "$rigTmp/r1" magic-tester
rigAssert "a member other than the coordinator is refused" "$( cat "$rigTmp/r1.rc" )" 1
rigAssert "and nothing is committed"                   "$( rigCount "$rigG" )" "$rigCountBefore"
mkdir -p "$rigTmp/notrepo"
## With a remote configured the dispatcher clones a missing local board, so this store is outside any repository only with none.
rigRemote ""
rigOp "$rigTmp/notrepo" "$rigTmp/r2" magic-coordinator
rigRemote "$rigBare"
rigAssert "a store outside any repository is refused"  "$( cat "$rigTmp/r2.rc" ):$( rigHolds "$rigTmp/r2.err" 'is not in a git repository' )" "1:yes"
: > "$rigG/.git/index.lock"
rigOp "$rigG" "$rigTmp/r3" magic-coordinator
rm -f "$rigG/.git/index.lock"
rigAssert "a leftover index.lock is refused"           "$( cat "$rigTmp/r3.rc" ):$( rigHolds "$rigTmp/r3" 'TEAM-DATA-REFUSED: the repository shows an interrupted operation: index.lock' )" "1:yes"
rigAssert "and nothing is committed"                   "$( rigCount "$rigG" )" "$rigCountBefore"
rigAssert "control: with the lock gone the same store commits" "$( rigOp "$rigG" "$rigTmp/r4" magic-coordinator ; cat "$rigTmp/r4.rc" ; LC_ALL=C grep -c '^TEAM-DATA-PUSHED:' "$rigTmp/r4" )" "01"

echo "-- push guards --"
rigPending "$rigG"
rigOp "$rigG" "$rigTmp/p1" magic-coordinator --no-push
rigAssert "--no-push commits and says it did not push" "$( LC_ALL=C grep -c '^TEAM-DATA-COMMITTED:' "$rigTmp/p1" ):$( LC_ALL=C grep -c '^TEAM-DATA-NOT-PUSHED: --no-push$' "$rigTmp/p1" )" "1:1"
rigAssert "and the remote does not have it"            "$( [ "$( git --git-dir="$rigBare" rev-parse "refs/heads/$rigBranch" )" != "$( git -C "$rigG" rev-parse HEAD )" ] && printf behind || printf same )" behind
rigRemote ""
rigPending "$rigG"
rigOp "$rigG" "$rigTmp/p2" magic-coordinator
rigAssert "no remote configured: committed, not pushed, and said why" "$( LC_ALL=C grep -c '^TEAM-DATA-NOT-PUSHED: no TEAM_DATA_GIT_REMOTE is configured$' "$rigTmp/p2" )" 1
rigRemote "$rigTmp/other.git"
rigPending "$rigG"
rigOp "$rigG" "$rigTmp/p3" magic-coordinator
rigAssert "an origin that is not TEAM_DATA_GIT_REMOTE is not pushed" "$( rigHolds "$rigTmp/p3" "TEAM-DATA-NOT-PUSHED: origin of $rigG is '$rigBare', not TEAM_DATA_GIT_REMOTE '$rigTmp/other.git'" )" yes

echo "-- a store inside a larger repository --"
rigOuter="$rigTmp/outer"
rigStore "$rigOuter" ""
mkdir -p "$rigOuter/data"
printf 'd\n' > "$rigOuter/data/in.md"
printf 'staged outside\n' > "$rigOuter/outside.md"
git -C "$rigOuter" add outside.md
printf 'edited outside, not staged\n' > "$rigOuter/keep.md"
rigRemote "$rigBare"
rigOp "$rigOuter/data" "$rigTmp/o" magic-coordinator
rigAssert "an unstaged change outside the store is not staged" "$( git -C "$rigOuter" diff --cached --name-only | LC_ALL=C grep -c -x 'keep.md' )" 0
rigAssert "the path under the store is committed"      "$( git -C "$rigOuter" log -1 --name-only --format= | LC_ALL=C grep -c -x 'data/in.md' )" 1
rigAssert "the path staged outside it is not"          "$( git -C "$rigOuter" log -1 --name-only --format= | LC_ALL=C grep -c -x 'outside.md' )" 0
rigAssert "and it stays staged"                        "$( git -C "$rigOuter" diff --cached --name-only | LC_ALL=C grep -c -x 'outside.md' )" 1
rigAssert "the outer branch is not pushed, and it says why" "$( rigHolds "$rigTmp/o" "TEAM-DATA-NOT-PUSHED: the store is inside $rigOuter" )" yes

echo "-- a push that fails, and a push not confirmed by read-back --"
rigF="$rigTmp/fail/store"
rigStore "$rigF" "$rigTmp/fail.git"
rigRemote "$rigTmp/fail.git"
rm -rf "$rigTmp/fail.git"
rigPending "$rigF"
rigOp "$rigF" "$rigTmp/f" magic-coordinator
rigAssert "an unreachable remote exits 1"              "$( cat "$rigTmp/f.rc" )" 1
rigAssert "saying the commit is local only"            "$( LC_ALL=C grep -c '^TEAM-DATA-NOT-PUSHED: the push failed; commit [0-9a-f]* is local only$' "$rigTmp/f" )" 1
rigAssert "and the commit is kept"                     "$( git -C "$rigF" log -1 --name-status --format= | LC_ALL=C grep -c -x 'A	added.md' )" 1
rigR="$rigTmp/readback/store"
rigStore "$rigR" "$rigTmp/readback.git"
rigRemote "$rigTmp/readback.git"
## The remote accepts the push, then moves its branch back, so the read-back cannot match.
rigRBranch="$( git -C "$rigR" rev-parse --abbrev-ref HEAD )"
printf '#!/bin/sh\nwhile read rigOld rigNew rigRef ; do git update-ref "$rigRef" "$rigOld" ; done\n' > "$rigTmp/readback.git/hooks/post-receive"
chmod +x "$rigTmp/readback.git/hooks/post-receive"
rigPending "$rigR"
rigOp "$rigR" "$rigTmp/rb" magic-coordinator
rigAssert "a push not confirmed by read-back exits 1"  "$( cat "$rigTmp/rb.rc" )" 1
rigAssert "and says the read-back did not match"       "$( rigHolds "$rigTmp/rb" "TEAM-DATA-NOT-PUSHED: the push reported success but origin's $rigRBranch reads back" )" yes

echo "-- the sync: origin moved from another clone, no conflict --"
rigS="$rigTmp/sync.git"
rigStore "$rigTmp/sync-seed" "$rigS"
rigSBranch="$( git -C "$rigTmp/sync-seed" rev-parse --abbrev-ref HEAD )"
rigRemote "$rigS"
git clone -q -b "$rigSBranch" "$rigS" "$rigTmp/sync-other" 2>/dev/null || rigRefuse "could not make the other clone"
git clone -q -b "$rigSBranch" "$rigS" "$rigTmp/sync-here" 2>/dev/null || rigRefuse "could not make this clone"
rigOtherCommit(){ ## file name: one commit in the other clone, pushed
	git -C "$rigTmp/sync-other" pull -q --ff-only 2>/dev/null \
		&& printf '%s\n' "$1" > "$rigTmp/sync-other/$1" && git -C "$rigTmp/sync-other" add -A && git -C "$rigTmp/sync-other" commit -q -m "$1" \
		&& git -C "$rigTmp/sync-other" push -q 2>/dev/null || rigRefuse "the other clone could not push $1"
	git -C "$rigTmp/sync-other" rev-parse HEAD
}
rigOther1="$( rigOtherCommit other1.md )"
rigPending "$rigTmp/sync-here"
rigOp "$rigTmp/sync-here" "$rigTmp/s1" magic-coordinator
rigSLocal="$( LC_ALL=C sed -n 's/^TEAM-DATA-COMMITTED: \([0-9a-f]*\) .*/\1/p' "$rigTmp/s1" )"
rigSHead="$( git -C "$rigTmp/sync-here" rev-parse HEAD )"
rigAssert "a local commit while origin moved: it exits 0"  "$( cat "$rigTmp/s1.rc" )" 0
rigAssert "it committed the pending paths"              "$( LC_ALL=C grep -c "^TEAM-DATA-COMMITTED: [0-9a-f]* 3 path(s) under $rigTmp/sync-here$" "$rigTmp/s1" )" 1
rigAssert "origin's commit and the local one are merged, neither rewritten" "$( git -C "$rigTmp/sync-here" merge-base --is-ancestor "$rigOther1" HEAD && printf yes || printf no ):$( [ -n "$rigSLocal" ] && git -C "$rigTmp/sync-here" merge-base --is-ancestor "$rigSLocal" HEAD && printf yes || printf no ):$( git -C "$rigTmp/sync-here" rev-list --parents -n 1 HEAD | wc -w | tr -d '[:space:]' )" "yes:yes:3"
rigAssert "pushed, read back as the merged head"        "$( rigHolds "$rigTmp/s1" "TEAM-DATA-PUSHED: $rigSLocal to origin, read back as origin/$rigSBranch = $rigSHead" )" yes
rigAssert "the bare remote's branch is that head"      "$( git --git-dir="$rigS" rev-parse "refs/heads/$rigSBranch" )" "$rigSHead"
rigAssert "the store is clean afterwards"              "$( [ -z "$( git -C "$rigTmp/sync-here" status --porcelain --untracked-files=all )" ] && printf clean || printf dirty )" clean
rigOther2="$( rigOtherCommit other2.md )"
rigOp "$rigTmp/sync-here" "$rigTmp/s2" magic-coordinator
rigAssert "nothing pending, nothing ahead, origin moved: it exits 0" "$( cat "$rigTmp/s2.rc" ):$( LC_ALL=C grep -c "^TEAM-DATA-NOTHING-PENDING: $rigTmp/sync-here$" "$rigTmp/s2" )" "0:1"
rigAssert "origin's commit is brought in"               "$( git -C "$rigTmp/sync-here" rev-parse HEAD )" "$rigOther2"
rigAssert "and read back as origin's head"              "$( LC_ALL=C grep -c "^TEAM-DATA-PUSHED: [0-9a-f]* to origin, read back as origin/$rigSBranch = $rigOther2$" "$rigTmp/s2" )" 1

echo "-- the sync: origin and this store changed one file -- no conflict is committed, no line is lost, no side file is written, and it always pushes --"
rigOtherEdit(){ ## file, text: one commit in the other clone changing that file, pushed
	git -C "$rigTmp/sync-other" pull -q --ff-only 2>/dev/null \
		&& printf '%s\n' "$2" > "$rigTmp/sync-other/$1" && git -C "$rigTmp/sync-other" add -A && git -C "$rigTmp/sync-other" commit -q -m "other edit of $1" \
		&& git -C "$rigTmp/sync-other" push -q 2>/dev/null || rigRefuse "the other clone could not push its edit of $1"
}
rigOtherAppend(){ ## file, text: one commit in the other clone appending a line to that file, pushed
	git -C "$rigTmp/sync-other" pull -q --ff-only 2>/dev/null \
		&& printf '%s\n' "$2" >> "$rigTmp/sync-other/$1" && git -C "$rigTmp/sync-other" add -A && git -C "$rigTmp/sync-other" commit -q -m "other append to $1" \
		&& git -C "$rigTmp/sync-other" push -q 2>/dev/null || rigRefuse "the other clone could not push its append to $1"
}
rigMarkers(){ ## store -- how many committed files of HEAD hold a conflict marker line
	git -C "$1" grep -l -e '^<<<<<<< ' -e '^=======$' -e '^>>>>>>> ' HEAD -- 2>/dev/null | LC_ALL=C grep -c . || :
}
rigFilesIn(){ ## store -- the files of the working tree, no .git, one line
	( cd "$1" && find . -path ./.git -prune -o -type f -print | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )
}
rigLineCount(){ ## file, whole line -- how many times the file holds that line
	LC_ALL=C grep -c -x -F -- "$2" "$1" || :
}
rigFilesBefore="$( rigFilesIn "$rigTmp/sync-here" )"
rigOtherEdit change.md "origin's version of the file"
rigPending "$rigTmp/sync-here"
rigOp "$rigTmp/sync-here" "$rigTmp/c1" magic-coordinator
rigCHead="$( git -C "$rigTmp/sync-here" rev-parse HEAD )"
rigAssert "a conflict on the same file: it exits 0 and pushes, read back as the head" "$( cat "$rigTmp/c1.rc" ):$( LC_ALL=C grep -c "^TEAM-DATA-PUSHED: [0-9a-f]* to origin, read back as origin/$rigSBranch = $rigCHead$" "$rigTmp/c1" ):$( git --git-dir="$rigS" rev-parse "refs/heads/$rigSBranch" )" "0:1:$rigCHead"
rigAssert "no committed file holds a conflict marker, and no merge is left open" "$( rigMarkers "$rigTmp/sync-here" ):$( [ -e "$rigTmp/sync-here/.git/MERGE_HEAD" ] && printf open || printf closed )" "0:closed"
rigAssert "both versions stand in the one file, none lost: origin's line and the local line, each once" \
	"$( rigLineCount "$rigTmp/sync-here/change.md" "origin's version of the file" ):$( LC_ALL=C grep -c '^changed ' "$rigTmp/sync-here/change.md" )" "1:1"
rigAssert "no side file was written: the files of the store are those it had, and the new ones the writer made" \
	"$( rigFilesIn "$rigTmp/sync-here" | LC_ALL=C grep -c -e 'conflict' -e '\.orig' -e '\.rej' || : )" "0"
rigAssert "the store is clean afterwards" "$( [ -z "$( git -C "$rigTmp/sync-here" status --porcelain --untracked-files=all )" ] && printf clean || printf dirty )" clean
echo "-- line records: both sides' lines, each once, in time order --"
printf '2026-10-27T10:00:00Z\tbase\n' > "$rigTmp/sync-here/records.log"
git -C "$rigTmp/sync-here" add -A && git -C "$rigTmp/sync-here" commit -q -m "records base" && git -C "$rigTmp/sync-here" push -q origin HEAD 2>/dev/null || rigRefuse "could not push the records base"
git -C "$rigTmp/sync-other" pull -q --ff-only 2>/dev/null
rigOtherAppend records.log "$( printf '2026-10-27T10:05:00Z\tother-late' )"
rigOtherAppend records.log "$( printf '2026-10-27T10:02:00Z\tshared-line' )"
printf '2026-10-27T10:03:00Z\tlocal-mid\n2026-10-27T10:02:00Z\tshared-line\n' >> "$rigTmp/sync-here/records.log"
git -C "$rigTmp/sync-here" add -A && git -C "$rigTmp/sync-here" commit -q -m "local records"
rigPending "$rigTmp/sync-here"
rigOp "$rigTmp/sync-here" "$rigTmp/c3" magic-coordinator
rigAssert "line records conflict at the end of the file: it exits 0 and pushes" "$( cat "$rigTmp/c3.rc" ):$( git --git-dir="$rigS" rev-parse "refs/heads/$rigSBranch" ):$( git -C "$rigTmp/sync-here" rev-parse HEAD )" "0:$( git -C "$rigTmp/sync-here" rev-parse HEAD ):$( git -C "$rigTmp/sync-here" rev-parse HEAD )"
rigAssert "the file holds every line of both sides, each once, in time order, and no marker" \
	"$( LC_ALL=C tr '\t' ' ' < "$rigTmp/sync-here/records.log" | LC_ALL=C tr '\n' '|' ):$( rigMarkers "$rigTmp/sync-here" )" \
	"2026-10-27T10:00:00Z base|2026-10-27T10:02:00Z shared-line|2026-10-27T10:03:00Z local-mid|2026-10-27T10:05:00Z other-late|:0"
rigAssert "no side file was written for it" "$( rigFilesIn "$rigTmp/sync-here" | LC_ALL=C grep -c -e 'conflict' -e 'records\.[a-z0-9-]*\.log' || : )" "0"
echo "-- the header of a document: a key both sides changed ends with one line, the value of the side changed later --"
rigDoc(){ ## status, verdict, updated (empty for no updated key), owner, body line -- a document with a header
	printf -- '---\ntype: note\nstatus: %s\nverdict: %s\n' "$1" "$2"
	[ -z "$3" ] || printf 'updated: %s\n' "$3"
	printf 'owner: %s\n---\n# Note: rig\n\nbase body\n%s' "$4" "${5:+$5
}"
}
rigDocFiles="docA.md docB.md docC.md"
for rigDocName in $rigDocFiles ; do
	if [ "$rigDocName" = docC.md ] ; then rigDoc open pending "" rig-owner > "$rigTmp/sync-here/$rigDocName" ; else rigDoc open pending 2026-10-27T10:00:00Z rig-owner > "$rigTmp/sync-here/$rigDocName" ; fi
done
git -C "$rigTmp/sync-here" add -A && git -C "$rigTmp/sync-here" commit -q -m "docs base" && git -C "$rigTmp/sync-here" push -q origin HEAD 2>/dev/null || rigRefuse "could not push the documents"
git -C "$rigTmp/sync-other" pull -q --ff-only 2>/dev/null
## origin: A and B and C all changed after the base; A and C also grow a body line.
rigDoc closed yes 2026-10-27T10:10:00Z rig-owner "origin body A" > "$rigTmp/sync-other/docA.md"
rigDoc closed yes 2026-10-27T10:10:00Z rig-owner "origin body B" > "$rigTmp/sync-other/docB.md"
rigDoc closed yes "" rig-owner "origin body C" > "$rigTmp/sync-other/docC.md"
git -C "$rigTmp/sync-other" add -A && git -C "$rigTmp/sync-other" commit -q -m "origin docs" && git -C "$rigTmp/sync-other" push -q 2>/dev/null || rigRefuse "the other clone could not push its documents"
## local: A changed later than origin, B changed earlier, C has no stamp on either side.
rigDoc parked no 2026-10-27T10:20:00Z rig-owner "local body A" > "$rigTmp/sync-here/docA.md"
rigDoc parked no 2026-10-27T10:05:00Z rig-owner "local body B" > "$rigTmp/sync-here/docB.md"
rigDoc parked no "" rig-owner "local body C" > "$rigTmp/sync-here/docC.md"
git -C "$rigTmp/sync-here" add -A && git -C "$rigTmp/sync-here" commit -q -m "local docs"
rigPending "$rigTmp/sync-here"
rigOp "$rigTmp/sync-here" "$rigTmp/c4" magic-coordinator
rigHeaderKey(){ ## file, key -- the value lines of that key in the header
	LC_ALL=C awk -v want="$2" 'NR == 1 && $0 == "---" { fm = 1 ; next ; } fm && $0 == "---" { exit ; } fm && index( $0, want ":" ) == 1 { sub( /^[^:]*:[ ]*/, "" ) ; printf "%s;", $0 ; }' "$1"
}
rigHeaderDup(){ ## file -- how many keys of the header stand more than once
	LC_ALL=C awk 'NR == 1 && $0 == "---" { fm = 1 ; next ; } fm && $0 == "---" { exit ; } fm && /^[A-Za-z0-9_.-]+:/ { key = $0 ; sub( /:.*/, "", key ) ; seen[key]++ ; } END { for ( key in seen ) if ( seen[key] > 1 ) dup++ ; print dup + 0 ; }' "$1"
}
rigDocValid(){ ## file -- the rows the document validator reports for it, and its status
	local validRc=0 validRows
	validRows="$( cd "$rigTmp/ws" && env MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigTmp/sync-here" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_WORKSPACE_MODE=team-rig bash "$rigFn" --intern-doc-validate document --from-stdin --as "${1##*/}" < "$1" 2> /dev/null )" || validRc=$?
	printf '%s:%s' "$validRc" "$( printf '%s' "$validRows" | LC_ALL=C grep -c . || : )"
}
rigAssert "the sync with three conflicting headers exits 0 and pushes" "$( cat "$rigTmp/c4.rc" ):$( git --git-dir="$rigS" rev-parse "refs/heads/$rigSBranch" ):$( git -C "$rigTmp/sync-here" rev-parse HEAD )" "0:$( git -C "$rigTmp/sync-here" rev-parse HEAD ):$( git -C "$rigTmp/sync-here" rev-parse HEAD )"
rigAssert "the local side changed later (A): its status, verdict and stamp, one line each" \
	"$( rigHeaderKey "$rigTmp/sync-here/docA.md" status )$( rigHeaderKey "$rigTmp/sync-here/docA.md" verdict )$( rigHeaderKey "$rigTmp/sync-here/docA.md" updated )" "parked;no;2026-10-27T10:20:00Z;"
rigAssert "origin changed later (B): its status, verdict and stamp" \
	"$( rigHeaderKey "$rigTmp/sync-here/docB.md" status )$( rigHeaderKey "$rigTmp/sync-here/docB.md" verdict )$( rigHeaderKey "$rigTmp/sync-here/docB.md" updated )" "closed;yes;2026-10-27T10:10:00Z;"
rigAssert "neither side carries a stamp (C): origin's" "$( rigHeaderKey "$rigTmp/sync-here/docC.md" status )$( rigHeaderKey "$rigTmp/sync-here/docC.md" verdict )" "closed;yes;"
rigAssert "no document has a key twice in its header, and none holds a marker" "$( rigHeaderDup "$rigTmp/sync-here/docA.md" )$( rigHeaderDup "$rigTmp/sync-here/docB.md" )$( rigHeaderDup "$rigTmp/sync-here/docC.md" ):$( rigMarkers "$rigTmp/sync-here" )" "000:0"
rigAssert "the lines of the body of both sides stand in each document, once" \
	"$( rigLineCount "$rigTmp/sync-here/docA.md" "origin body A" )$( rigLineCount "$rigTmp/sync-here/docA.md" "local body A" )$( rigLineCount "$rigTmp/sync-here/docB.md" "origin body B" )$( rigLineCount "$rigTmp/sync-here/docB.md" "local body B" )$( rigLineCount "$rigTmp/sync-here/docC.md" "origin body C" )$( rigLineCount "$rigTmp/sync-here/docC.md" "local body C" )" "111111"
rigAssert "the document validator reports nothing on any of the three" "$( rigDocValid "$rigTmp/sync-here/docA.md" ) $( rigDocValid "$rigTmp/sync-here/docB.md" ) $( rigDocValid "$rigTmp/sync-here/docC.md" )" "0:0 0:0 0:0"
echo "-- a merge an earlier sync left unfinished is settled, not left for a person --"
rigOtherEdit keep.md "origin's keep"
printf 'local keep\n' > "$rigTmp/sync-here/keep.md"
git -C "$rigTmp/sync-here" add -A && git -C "$rigTmp/sync-here" commit -q -m "local keep edit"
git -C "$rigTmp/sync-here" fetch -q origin 2>/dev/null
git -C "$rigTmp/sync-here" merge -q "refs/remotes/origin/$rigSBranch" > /dev/null 2>&1 || :
rigAssert "control: the rig left a merge open with a conflict in it" "$( [ -e "$rigTmp/sync-here/.git/MERGE_HEAD" ] && printf open || printf closed ):$( LC_ALL=C grep -c '^<<<<<<< ' "$rigTmp/sync-here/keep.md" )" "open:1"
rigOp "$rigTmp/sync-here" "$rigTmp/c2" magic-coordinator
rigC2Head="$( git -C "$rigTmp/sync-here" rev-parse HEAD )"
rigAssert "it exits 0 and pushes the settled head" "$( cat "$rigTmp/c2.rc" ):$( git --git-dir="$rigS" rev-parse "refs/heads/$rigSBranch" )" "0:$rigC2Head"
rigAssert "no marker is committed, the merge is closed, both versions stand in the one file, and no side file exists" \
	"$( rigMarkers "$rigTmp/sync-here" ):$( [ -e "$rigTmp/sync-here/.git/MERGE_HEAD" ] && printf open || printf closed ):$( rigLineCount "$rigTmp/sync-here/keep.md" "origin's keep" ):$( rigLineCount "$rigTmp/sync-here/keep.md" "local keep" ):$( rigFilesIn "$rigTmp/sync-here" | LC_ALL=C grep -c 'conflict' || : )" "0:closed:1:1:0"
echo "-- the close push: origin moved and the files conflict -- settled in the file and pushed, never held back --"
rigOtherEdit added.md "origin's added"
printf 'local added\n' > "$rigTmp/sync-here/added.md"
git -C "$rigTmp/sync-here" add -A && git -C "$rigTmp/sync-here" commit -q -m "local added edit"
( cd "$rigTmp/ws" && MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigTmp/sync-here" MDLT_ORIGIN="$MDLT_ORIGIN" MDSC_CMD=rig-push MDAT_WORKSPACE_MODE=team-rig bash -c '
	DistroAgentsTools(){ bash "'"$rigFn"'" "$@" ; }
	. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.TeamDataCommit.include"
	AgentsToolsTeamDataPushIfAhead rig-close' ) > "$rigTmp/p1.out" 2> "$rigTmp/p1.err"
rigP1Head="$( git -C "$rigTmp/sync-here" rev-parse HEAD )"
rigAssert "the close push settles the conflict and origin's branch is the local head" "$( git --git-dir="$rigS" rev-parse "refs/heads/$rigSBranch" ):$( rigHolds "$rigTmp/p1.err" 'team-data pushed' )" "$rigP1Head:yes"
rigAssert "no marker is committed, no merge is open, both versions stand in the one file, and no side file exists" \
	"$( rigMarkers "$rigTmp/sync-here" ):$( [ -e "$rigTmp/sync-here/.git/MERGE_HEAD" ] && printf open || printf closed ):$( rigLineCount "$rigTmp/sync-here/added.md" "origin's added" ):$( rigLineCount "$rigTmp/sync-here/added.md" "local added" ):$( rigFilesIn "$rigTmp/sync-here" | LC_ALL=C grep -c 'conflict' || : )" "0:closed:1:1:0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ TEAM DATA COMMIT PENDING CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'TEAM_DATA_COMMIT_PENDING: OK (%d assertions, offline, temp stores only)\n' "$rigPassCount"
