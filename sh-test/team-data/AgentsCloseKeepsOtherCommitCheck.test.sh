#!/usr/bin/env bash
## Behavioural check on S12.10: a close that cannot be recorded drops its OWN commit, never whatever commit
## HEAD has moved on to. Held, over a real git store under this rig's own tree, on the one function every
## failed close goes through (AgentsToolsItemUnlockKeep, sh-lib/team-data/AgentsTools.InternOpItem.include):
##   1. THE CONTROL, and the function's own positive: HEAD is this call's own commit, and the drop takes it
##      away. A function that dropped nothing would pass every other case here.
##   2. THE SUBJECT: another writer commits after this call's own commit, and the close still fails. HEAD is
##      that writer's commit, it stays on the branch, and its file is still committed.
##   3. The same, where this call has made no commit of its own at all: nothing is dropped.
##   4. The note itself is put back as the close found it, in both of the failing cases.
## Red before the fix: case 2 reported HEAD at the commit below the other writer's, and that file gone from
## the branch. Measured in the live store, 2026-11-04: `.unseen-dispatch-20261103T225226Z-spawn-proxy-68534-637d5076.md`
## was committed at 04:30:28 and dropped by such a reset one second later, and reached no commit for 50 minutes.
## NOT HELD, and stated so it is not read as done: in case 2 this call's own commit stays on the branch below the
## other writer's, so the history records a close whose note was put back. Dropping it would take two resets and
## a guess at how many commits between are this call's own, and that is a different piece of work.
## Offline: the store, the note and the commit are this rig's own; no remote is touched.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPkg="$rigOrigin/myx/myx.distro-agents"
rigItem="$rigPkg/sh-lib/team-data/AgentsTools.InternOpItem.include"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigItem" ] || rigRefuse "the item include is not at the origin this workspace resolves: $rigItem"
command -v git > /dev/null || rigRefuse "git is not installed"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsCloseKeepsOtherCommitCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigStore="$rigTmp/store"
rigHome="$rigTmp/home"
mkdir -p "$rigStore/board/running" "$rigHome" || rigRefuse "could not make the rig's own tree"
git -C "$rigStore" init -q || rigRefuse "could not init the rig store"
git -C "$rigStore" config user.email rig@example.invalid
git -C "$rigStore" config user.name rig
printf 'seed\n' > "$rigStore/README.md"
git -C "$rigStore" add -A && git -C "$rigStore" commit -q -m seed || rigRefuse "could not seed the rig store"
rigTarget="$rigStore/board/running/dispatch-rig-close.md"
printf -- '---\ntype: dispatch\nowner: rig-member\nsession-id: rig-session\n---\n\nrig item\n' > "$rigTarget"

rigPass=0 ; rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

## One failed close, run the way the upsert runs it: the function is reached through its own include, with the
## five values the caller holds. The message is the one the upsert builds for this note.
rigClose(){ ## result name, committed (true|false)
	(
		cd "$rigTmp" || exit 1
		env -i HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" GIT_CONFIG_NOSYSTEM=1 \
			MDLT_ORIGIN="$rigOrigin" MMDAPP="$rigTmp" MDAT_DATA_ROOT="$rigStore" MDSC_CMD=rig \
			bash -c '. "$1" ; target="$2" ; repoRoot="$3" ; priorExisted=true ; priorContent="$4" ;
				unlockCommitted="$5" ; commitMessage="DistroAgentsTools: item-upsert: dispatch-rig-close.md" ;
				AgentsToolsItemUnlockKeep restore "the push was refused"' rigclose "$rigItem" "$rigTarget" "$rigStore" "$rigPriorBody" "$2"
	) > "$rigTmp/close.$1.out" 2>&1 < /dev/null
	printf '%s' "$?" > "$rigTmp/close.$1.rc"
}

## This call's own commit, made as the upsert makes it: the note, then the commit that names it.
rigOwnCommit(){
	printf -- '---\ntype: dispatch\nowner: rig-member\nsession-id: rig-session\n---\n\nrig item, the close\n' > "$rigTarget"
	git -C "$rigStore" add -A -- "$rigTarget" && git -C "$rigStore" commit -q --allow-empty -m "DistroAgentsTools: item-upsert: dispatch-rig-close.md" -- "$rigTarget" \
		|| rigRefuse "could not make this call's own commit"
}
## Another writer's commit, arrived after it: a different file, a subject of its own.
rigOtherCommit(){
	printf 'the other writer\n' > "$rigStore/board/running/dispatch-rig-other.md"
	git -C "$rigStore" add -A -- "$rigStore/board/running/dispatch-rig-other.md" && git -C "$rigStore" commit -q -m "review-unseen mark, dispatch-rig-other" \
		|| rigRefuse "could not make the other writer's commit"
}
rigHead(){ git -C "$rigStore" log -1 --format=%s HEAD 2> /dev/null ; }
rigOnBranch(){ git -C "$rigStore" cat-file -e "HEAD:$1" 2> /dev/null && printf here || printf gone ; }

rigPriorBody="$( cat "$rigTarget" )"

echo "-- 1. control: HEAD is this call's own commit, and the drop takes it away --"
rigOwnCommit
rigOwn="$( rigHead )"
rigClose own true
rigAssert "1. the close reported itself as not recorded"                     "$( cat "$rigTmp/close.own.rc" )" 0
rigAssert "1. this call's own commit is gone from the branch, as the discarding intends" \
	"$( rigOnBranch board/running/dispatch-rig-close.md )" gone
rigAssert "1. control: the commit below it is what HEAD is now"              "$( rigHead )" seed

echo "-- 2. the subject: another writer's commit is not this call's to drop --"
printf -- '---\ntype: dispatch\nowner: rig-member\nsession-id: rig-session\n---\n\nrig item\n' > "$rigTarget"
git -C "$rigStore" add -A -- "$rigTarget" && git -C "$rigStore" commit -q -m "seed again" -- "$rigTarget" || rigRefuse "could not reset the note for case 2"
rigOwnCommit
rigOtherCommit
rigOther="$( rigHead )"
rigClose other true
rigAssert "2. the branch still ends at the other writer's commit"            "$( rigHead )" "$rigOther"
rigAssert "2. and the other writer's file is still on the branch"           "$( rigOnBranch board/running/dispatch-rig-other.md )" here
rigAssert "2. this call's own commit stays below it, undropped: the fix drops nothing it did not make at HEAD" \
	"$( rigOnBranch board/running/dispatch-rig-close.md )" here
rigAssert "2. the note is put back as the close found it"                   "$( cat "$rigTarget" )" "$rigPriorBody"

echo "-- 3. no commit of this call's own: nothing is dropped --"
printf 'third\n' > "$rigStore/board/running/dispatch-rig-third.md"
git -C "$rigStore" add -A -- "$rigStore/board/running/dispatch-rig-third.md" && git -C "$rigStore" commit -q -m "a third writer" \
	|| rigRefuse "could not make the third commit"
rigThird="$( rigHead )"
rigClose nocommit false
rigAssert "3. HEAD is where it was"                                         "$( rigHead )" "$rigThird"
rigAssert "3. the note is put back as the close found it"                   "$( cat "$rigTarget" )" "$rigPriorBody"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ CLOSE KEEPS OTHER COMMIT CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'CLOSE_KEEPS_OTHER_COMMIT: OK (%d assertions, offline)\n' "$rigPass"
