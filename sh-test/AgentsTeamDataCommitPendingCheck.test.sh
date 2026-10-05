#!/usr/bin/env bash
## Behavioural check on --magic-team-data-commit-pending against temp git stores and
## temp bare remotes only -- never the real team data. The gating case is shaped like
## the real store: its own repository root, nested in plain folders, origin equal to
## TEAM_DATA_GIT_REMOTE, with added, changed and deleted paths pending and two commits
## already ahead of origin. Setup uses git on this rig's own mktemp trees only.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigFn="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
command -v git > /dev/null || rigRefuse "git is not installed"
rigTmp="$( mktemp -d -t AgentsTeamDataCommitPendingCheck )" || exit 1
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
rigStore(){ ## store path, bare remote path or empty
	mkdir -p "$1"
	git -C "$1" init -q || rigRefuse "could not init $1"
	printf 'keep\n' > "$1/keep.md"
	printf 'old\n' > "$1/change.md"
	printf 'bye\n' > "$1/gone.md"
	git -C "$1" add -A && git -C "$1" commit -q -m seed || rigRefuse "could not seed $1"
	[ -n "$2" ] || return 0
	git init -q --bare "$2" || rigRefuse "could not init the bare remote $2"
	git -C "$1" remote add origin "$2"
	git -C "$1" push -q origin HEAD 2>/dev/null || rigRefuse "could not seed the bare remote $2"
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
		bash "$rigFn" --magic-team-data-commit-pending "$@" ) > "$opOut" 2> "$opOut.err"
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

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ TEAM DATA COMMIT PENDING CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'TEAM_DATA_COMMIT_PENDING: OK (%d assertions, offline, temp stores only)\n' "$rigPassCount"
