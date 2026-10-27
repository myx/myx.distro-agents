#!/usr/bin/env bash
## Behavioural check on --repair-team-data-checkout, whose code lives in sh-lib/team-data (the include) below
## sh-scripts/DistroAgentsTools.fn.sh (its arm), against temp git stores and temp bare remotes only -- never the
## real team data. The case is shaped like the real one: a checkout cloned from a bare remote, three local
## commits never pushed, and the remote moved from another clone; the op shows the local-only commits and the
## remote's, trial-merges in a throwaway copy, and, with a mode, repairs: --take-remote sets the local commits
## aside and takes the remote, --keep-merged merges the remote keeping the local commits, and both end with the
## F4.3 move of the flat inbox items, then push. It is one implementation, sh-lib/magic/AgentsTools.MagicTeamDataCheckoutRepair.include,
## reached by the one arm of DistroAgentsItems.fn.sh; the older function of TeamDataCommit.include is gone, and the check says so below.
## Setup uses git on this rig's own mktemp trees only.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents"
rigFn="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
command -v git > /dev/null || rigRefuse "git is not installed"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsTeamDataCheckoutRepairCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigTmp="$( cd "$rigTmp" && pwd -P )"
mkdir -p "$rigTmp/ws/.local/.agents" "$rigTmp/ws/.local/temp"
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
rigHolds(){ ## file, fixed text
	LC_ALL=C grep -q -F -- "$2" "$1" 2> /dev/null && printf yes || printf no
}
rigCount(){ ## file, text
	LC_ALL=C grep -c -F -- "$2" "$1" 2> /dev/null || :
}

## A bare remote holding one seed commit on main: README.md, a board item, an audit file,
## and five flat inbox items lying at the root of a member's inbox, two stamped processed
## and three not, as the pre-F4.3 flat form had them.
rigRemote(){ ## name
	git init -q --bare "$rigTmp/$1.git" || rigRefuse "could not init the bare remote $1"
	rm -rf "$rigTmp/seed" ; git init -q "$rigTmp/seed" && git -C "$rigTmp/seed" symbolic-ref HEAD refs/heads/main
	mkdir -p "$rigTmp/seed/board/processed" "$rigTmp/seed/audit/2026-10" "$rigTmp/seed/inboxes/magic-coordinator"
	printf 'seed\n' > "$rigTmp/seed/README.md"
	printf 'board item\n' > "$rigTmp/seed/board/processed/note-20261014T0100Z-board.md"
	printf 'audit line\n' > "$rigTmp/seed/audit/2026-10/audit-20261014.md"
	printf -- '---\ntype: note\n---\n\nflat open one\n' > "$rigTmp/seed/inboxes/magic-coordinator/note-20261014T0101Z-flat-a.md"
	printf -- '---\ntype: note\n---\n\nflat open two\n' > "$rigTmp/seed/inboxes/magic-coordinator/note-20261014T0102Z-flat-b.md"
	printf -- '---\ntype: note\n---\n\nflat open three\n' > "$rigTmp/seed/inboxes/magic-coordinator/note-20261014T0103Z-flat-c.md"
	printf -- '---\ntype: note\nprocessed-at: 2026-10-14 01:04 +0000\n---\n\nflat done four\n' > "$rigTmp/seed/inboxes/magic-coordinator/note-20261014T0104Z-flat-d.md"
	printf -- '---\ntype: note\nprocessed-at: 2026-10-14 01:05 +0000\n---\n\nflat done five\n' > "$rigTmp/seed/inboxes/magic-coordinator/note-20261014T0105Z-flat-e.md"
	git -C "$rigTmp/seed" add -A && git -C "$rigTmp/seed" commit -q -m seed && git -C "$rigTmp/seed" push -q "$rigTmp/$1.git" main 2> /dev/null \
		|| rigRefuse "could not seed the bare remote $1"
}
## One more commit on a remote's main, made from a clone of the rig's own, on a file the
## local side does not touch, so that a merge of the two stays clean.
rigRemoteAdvance(){ ## remote name
	rm -rf "$rigTmp/adv" ; git clone -q "$rigTmp/$1.git" "$rigTmp/adv" 2> /dev/null || rigRefuse "could not clone $1 to advance it"
	printf 'from elsewhere\n' > "$rigTmp/adv/elsewhere.md"
	git -C "$rigTmp/adv" add -A && git -C "$rigTmp/adv" commit -q -m "elsewhere" && git -C "$rigTmp/adv" push -q origin main 2> /dev/null || rigRefuse "could not advance $1"
}
## One more commit that edits the same file the local side edited in its first commit, so a
## merge of the two conflicts.
rigRemoteAdvanceConflict(){ ## remote name
	rm -rf "$rigTmp/adv" ; git clone -q "$rigTmp/$1.git" "$rigTmp/adv" 2> /dev/null || rigRefuse "could not clone $1 to advance it"
	printf 'from elsewhere, conflicting\n' > "$rigTmp/adv/local-one.md"
	git -C "$rigTmp/adv" add -A && git -C "$rigTmp/adv" commit -q -m "elsewhere conflict" && git -C "$rigTmp/adv" push -q origin main 2> /dev/null || rigRefuse "could not advance $1"
}
## The checkout of the rig: a clone of the remote, three local commits on top of the seed,
## never pushed, each on its own file.
rigCheckout(){ ## remote name, checkout name
	rm -rf "$rigTmp/$2"
	git clone -q "$rigTmp/$1.git" "$rigTmp/$2" 2> /dev/null || rigRefuse "could not clone $1 into $2"
	printf 'local one\n' > "$rigTmp/$2/local-one.md" && git -C "$rigTmp/$2" add -A && git -C "$rigTmp/$2" commit -q -m "local one"
	printf 'local two\n' > "$rigTmp/$2/local-two.md" && git -C "$rigTmp/$2" add -A && git -C "$rigTmp/$2" commit -q -m "local two"
	printf 'local three\n' > "$rigTmp/$2/local-three.md" && git -C "$rigTmp/$2" add -A && git -C "$rigTmp/$2" commit -q -m "local three" \
		|| rigRefuse "could not make the local commits in $2"
}
rigRemoteSetting(){ ## TEAM_DATA_GIT_REMOTE value
	printf 'TEAM_DATA_GIT_REMOTE=%s\n' "$1" > "$rigTmp/ws/.local/.agents/magic-team.agent.env"
}
rigOp(){ ## store path, result file, member, extra args...
	local opStore="$1" opOut="$2" ; shift 2
	( cd "$rigTmp/ws" && env -u CLAUDE_CODE_ENTRYPOINT MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$opStore" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_WORKSPACE_MODE=team-rig \
		bash "$rigFn" --repair-team-data-checkout "$@" ) > "$opOut" 2> "$opOut.err"
	printf '%s' "$?" > "$opOut.rc"
}
rigBranchOf(){ ## store path
	git -C "$1" rev-parse --abbrev-ref HEAD
}
## How many `.md` items lie flat at the root of a member's inbox, and how many in each folder.
rigFlatWhere(){ ## store path -- "<flat> <incoming> <processed>"
	local rigWhereStore="$1" rigWhereFlat=0 rigWhereIn=0 rigWhereProc=0
	set -- "$rigWhereStore/inboxes/magic-coordinator"/*.md
	[ -f "$1" ] && rigWhereFlat=$# || rigWhereFlat=0
	set -- "$rigWhereStore/inboxes/magic-coordinator/incoming"/*.md
	[ -f "$1" ] && rigWhereIn=$# || rigWhereIn=0
	set -- "$rigWhereStore/inboxes/magic-coordinator/processed"/*.md
	[ -f "$1" ] && rigWhereProc=$# || rigWhereProc=0
	printf '%s %s %s\n' "$rigWhereFlat" "$rigWhereIn" "$rigWhereProc"
}

echo "-- the diagnosis, offered with no mode: shows and trial-merges, changes nothing --"
rigRemote base
rigCheckout base rig
rigRemoteAdvance base
rigRemoteSetting "$rigTmp/base.git"
rigBranch="$( rigBranchOf "$rigTmp/rig" )"
rigHeadBefore="$( git -C "$rigTmp/rig" rev-parse HEAD )"
rigOp "$rigTmp/rig" "$rigTmp/d" magic-coordinator
rigAssert "it exits 0"                                 "$( cat "$rigTmp/d.rc" )" 0
rigAssert "it says the checkout is 3 local ahead and 1 behind" "$( LC_ALL=C grep -c "^TEAM-DATA-CHECKOUT: $rigTmp/rig branch $rigBranch is 3 local commit(s) ahead of origin/$rigBranch and 1 behind it$" "$rigTmp/d" )" 1
rigAssert "it lists the three local-only commits"       "$( LC_ALL=C grep -c '^TEAM-DATA-LOCAL-COMMIT: ' "$rigTmp/d" )" 3
rigAssert "it lists the one remote-only commit"         "$( LC_ALL=C grep -c '^TEAM-DATA-REMOTE-COMMIT: ' "$rigTmp/d" )" 1
rigAssert "it trial-merges clean in a throwaway copy"   "$( LC_ALL=C grep -c '^TEAM-DATA-TRIAL-MERGE: clean$' "$rigTmp/d" )" 1
rigAssert "it offers the two modes by their commands"   "$( LC_ALL=C grep -c '^TEAM-DATA-REPAIR-OFFER: ' "$rigTmp/d" )" 2
rigAssert "and changes nothing"                         "$( git -C "$rigTmp/rig" rev-parse HEAD )" "$rigHeadBefore"
rigAssert "with no throwaway copy left behind"          "$( find "$rigTmp/ws/.local/temp" -maxdepth 1 -name 'mdat-team-data-checkout-repair.*' 2> /dev/null | wc -l | tr -d '[:space:]' )" 0

echo "-- in step: nothing to repair --"
rigOp "$rigTmp/adv" "$rigTmp/s" magic-coordinator
rigAssert "the advanced clone is in step and says so"   "$( cat "$rigTmp/s.rc" ):$( LC_ALL=C grep -c "^TEAM-DATA-NOTHING-TO-REPAIR: $rigTmp/adv is in step with origin/$rigBranch$" "$rigTmp/s" )" "0:1"

echo "-- take-remote: the local commits set aside, the remote taken, flat items moved, pushed --"
rigRemote take
rigCheckout take rig
rigRemoteAdvance take
rigRemoteSetting "$rigTmp/take.git"
rigBranch="$( rigBranchOf "$rigTmp/rig" )"
rigHeadBefore="$( git -C "$rigTmp/rig" rev-parse HEAD )"
rigOp "$rigTmp/rig" "$rigTmp/t" magic-coordinator --take-remote
rigAsideRef="$( LC_ALL=C sed -n 's/^TEAM-DATA-SET-ASIDE: the local commits stay reachable at \(refs\/heads\/[^ ]*\) (.*$/\1/p' "$rigTmp/t" | head -1 )"
rigAssert "it exits 0"                                 "$( cat "$rigTmp/t.rc" )" 0
rigAssert "it set the local commits aside at a ref"     "$( [ -n "$rigAsideRef" ] && git -C "$rigTmp/rig" rev-parse "$rigAsideRef" 2> /dev/null )" "$rigHeadBefore"
rigAssert "the branch took the remote"                  "$( git -C "$rigTmp/rig" rev-parse HEAD )" "$( git -C "$rigTmp/rig" rev-parse "origin/$rigBranch" )"
rigAssert "the flat items moved by processed: none flat, three incoming, two processed" "$( rigFlatWhere "$rigTmp/rig" )" "0 3 2"
rigAssert "it repaired and pushed, read back"           "$( LC_ALL=C grep -c "^TEAM-DATA-REPAIRED: $rigBranch is repaired and pushed, read back as origin/$rigBranch = $( git -C "$rigTmp/rig" rev-parse HEAD )$" "$rigTmp/t" )" 1
rigAssert "the remote's branch is the repaired head"    "$( git --git-dir="$rigTmp/take.git" rev-parse refs/heads/main )" "$( git -C "$rigTmp/rig" rev-parse HEAD )"
rigAssert "the store is clean afterwards"               "$( [ -z "$( git -C "$rigTmp/rig" status --porcelain --untracked-files=all )" ] && printf clean || printf dirty )" clean

echo "-- keep-merged: the local commits kept, the remote merged, flat items moved, pushed --"
rigRemote keep
rigCheckout keep rig
rigRemoteAdvance keep
rigRemoteSetting "$rigTmp/keep.git"
rigBranch="$( rigBranchOf "$rigTmp/rig" )"
rigHeadBefore="$( git -C "$rigTmp/rig" rev-parse HEAD )"
rigOp "$rigTmp/rig" "$rigTmp/k" magic-coordinator --keep-merged
rigAssert "it exits 0"                                 "$( cat "$rigTmp/k.rc" )" 0
rigAssert "it says the remote was merged, local commits kept" "$( LC_ALL=C grep -c "^TEAM-DATA-KEPT-MERGED: origin/$rigBranch merged into $rigBranch, local commits kept$" "$rigTmp/k" )" 1
rigAssert "the local commits are kept, an ancestor of the head" "$( git -C "$rigTmp/rig" merge-base --is-ancestor "$rigHeadBefore" HEAD && printf yes || printf no )" yes
rigAssert "the remote's commit is merged in too"        "$( git -C "$rigTmp/rig" merge-base --is-ancestor "origin/$rigBranch" HEAD && printf yes || printf no )" yes
rigAssert "the head is a merge, two parents"            "$( git -C "$rigTmp/rig" rev-list --merges -n 1 --parents HEAD | wc -w | tr -d '[:space:]' )" 3
rigAssert "the flat items moved by processed: none flat, three incoming, two processed" "$( rigFlatWhere "$rigTmp/rig" )" "0 3 2"
rigAssert "it repaired and pushed, read back"           "$( LC_ALL=C grep -c "^TEAM-DATA-REPAIRED: $rigBranch is repaired and pushed, read back as origin/$rigBranch = $( git -C "$rigTmp/rig" rev-parse HEAD )$" "$rigTmp/k" )" 1
rigAssert "the store is clean afterwards"               "$( [ -z "$( git -C "$rigTmp/rig" status --porcelain --untracked-files=all )" ] && printf clean || printf dirty )" clean

echo "-- a conflicting merge: the trial shows it, keep-merged aborts, take-remote still works --"
rigRemote conflict
rigCheckout conflict rig
rigRemoteAdvanceConflict conflict
rigRemoteSetting "$rigTmp/conflict.git"
rigBranch="$( rigBranchOf "$rigTmp/rig" )"
rigHeadBefore="$( git -C "$rigTmp/rig" rev-parse HEAD )"
rigOp "$rigTmp/rig" "$rigTmp/c" magic-coordinator
rigAssert "the trial says the merge conflicts"          "$( LC_ALL=C grep -c '^TEAM-DATA-TRIAL-MERGE: conflicts:' "$rigTmp/c" )" 1
rigAssert "and the diagnosis changes nothing"           "$( git -C "$rigTmp/rig" rev-parse HEAD )" "$rigHeadBefore"
rigOp "$rigTmp/rig" "$rigTmp/cm" magic-coordinator --keep-merged
rigAssert "keep-merged aborts on the conflict, exits 1" "$( cat "$rigTmp/cm.rc" ):$( rigHolds "$rigTmp/cm" 'TEAM-DATA-NOT-MERGED: the merge failed; the trial above showed it, and nothing was changed' )" "1:yes"
rigAssert "and the checkout is left as it was, no merge in progress" "$( git -C "$rigTmp/rig" rev-parse HEAD ):$( [ -e "$rigTmp/rig/.git/MERGE_HEAD" ] && printf merge || printf none ):$( git -C "$rigTmp/rig" rev-list --count "origin/$rigBranch..HEAD" )" "$rigHeadBefore:none:3"
rigOp "$rigTmp/rig" "$rigTmp/ct" magic-coordinator --take-remote
rigAssert "take-remote still repairs a conflicting checkout" "$( cat "$rigTmp/ct.rc" ):$( git -C "$rigTmp/rig" rev-parse HEAD ):$( git -C "$rigTmp/rig" rev-parse "origin/$rigBranch" )" "0:$( git -C "$rigTmp/rig" rev-parse "origin/$rigBranch" ):$( git -C "$rigTmp/rig" rev-parse "origin/$rigBranch" )"

echo "-- refusals --"
rigRemote refuse
rigCheckout refuse rig
rigRemoteSetting "$rigTmp/refuse.git"
rigBranch="$( rigBranchOf "$rigTmp/rig" )"
rigCountBefore="$( git -C "$rigTmp/rig" rev-list --count HEAD )"
rigOp "$rigTmp/rig" "$rigTmp/r1" magic-tester --take-remote
rigAssert "a member other than the coordinator is refused" "$( cat "$rigTmp/r1.rc" )" 1
rigAssert "and nothing is changed"                     "$( git -C "$rigTmp/rig" rev-list --count HEAD )" "$rigCountBefore"
rigOp "$rigTmp/rig" "$rigTmp/r2" magic-coordinator --keep-merged --take-remote
rigAssert "the two modes together are refused"          "$( cat "$rigTmp/r2.rc" ):$( rigHolds "$rigTmp/r2.err" 'mutually exclusive' )" "1:yes"
rigRemoteSetting ""
rigOp "$rigTmp/rig" "$rigTmp/r3" magic-coordinator --take-remote
rigAssert "no remote configured is refused"             "$( cat "$rigTmp/r3.rc" ):$( rigHolds "$rigTmp/r3.err" 'no TEAM_DATA_GIT_REMOTE is configured' )" "1:yes"
rigRemoteSetting "$rigTmp/refuse.git"
printf 'dirty\n' > "$rigTmp/rig/dirty.md"
rigOp "$rigTmp/rig" "$rigTmp/r4" magic-coordinator --take-remote
rigAssert "uncommitted paths are refused"               "$( cat "$rigTmp/r4.rc" ):$( rigHolds "$rigTmp/r4" 'TEAM-DATA-REFUSED: the checkout holds uncommitted paths' )" "1:yes"

echo "-- one implementation --"
rigAssert "the older function is gone from TeamDataCommit.include, and the one arm of the tool file sources the one include" \
	"$( LC_ALL=C grep -c 'AgentsToolsTeamDataCheckoutRepair' "$rigPackage/sh-lib/team-data/AgentsTools.TeamDataCommit.include" || : ):$( LC_ALL=C grep -c -e '--repair-team-data-checkout)' "$rigPackage/sh-scripts/DistroAgentsItems.fn.sh" || : ):$( LC_ALL=C grep -c 'AgentsTools.MagicTeamDataCheckoutRepair.include' "$rigPackage/sh-scripts/DistroAgentsItems.fn.sh" || : )" "0:1:1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ TEAM DATA CHECKOUT REPAIR CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'TEAM_DATA_CHECKOUT_REPAIR: OK (%d assertions, offline, temp stores only)\n' "$rigPassCount"
