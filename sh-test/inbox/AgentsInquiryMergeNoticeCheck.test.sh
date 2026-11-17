#!/usr/bin/env bash
## Behavioural check on the merge notice of --upsert-inbox-inquiry: a filing whose subject matches an open inquiry
## from the same sender is merged into it, and the merge notice is said only where the write is stored.
## Held, against a temp store only:
##   1. CONTROL: a filing on a new subject is stored, and the call says it wrote it -- so the rig can write.
##   2. A filing on the open inquiry's own subject is merged into it, and the write gate refuses that merged item.
##   3. The refused merge says no success notice: the output holds no "instead of a second item".
##   4. The refused merge names the filing as not stored.
##   5. The target item is unchanged: it holds the first filing's text and no "## Added" heading.
##   6. No second item of the merged filing's name is left in the inbox.
## Every call goes through one `env -i` whose child refuses to run outside this rig's mktemp tree; no Slack, no mail.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsItems.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsInquiryMergeNoticeCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigData="$rigTmp/data"
rigSkills="$rigTmp/skills"
## The inbox's folder is the write's own to make (AgentsToolsInboxReady): the control below makes it through the operation.
mkdir -p "$rigTmp/ws/.local" "$rigTmp/home" "$rigSkills/rig-member" "$rigSkills/magic-coordinator" "$rigData"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigSaid(){ ## fixed text -- how many lines of the last call's output hold it
	LC_ALL=C grep -c -F -- "$2" "$rigTmp/out" 2> /dev/null || :
}
rigHolds(){ ## file, fixed text
	[ -f "$1" ] && LC_ALL=C grep -q -F -- "$2" "$1" && printf yes || printf no
}
rigIn(){ ## item filename -- yes where it is in the target's incoming/, no otherwise
	[ -f "$rigData/inboxes/magic-coordinator/incoming/$1" ] && printf yes || printf no
}
rigTile(){ ## file -- the hash of the item's bytes, so an unchanged item is told from a rewritten one
	shasum -a 256 "$1" 2> /dev/null | LC_ALL=C cut -c 1-64
}
rigOp(){ ## args... -- stdout and stderr in out, rc in rigRc
	rigRc=0
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigTmp/ws" \
		MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SPAWN_AGENT=rig-member \
		MDAT_TEAM_DATA_COMMIT_THREAD=off MDAT_WAIT_REMIND=off \
		RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$HOME" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$rigTmp/out" 2>&1
	rigRc=$?
}
rigFile(){ ## title, body -- a whole inquiry document, as a caller files it
	printf -- '---\ntype: inquiry\nfrom: rig-member\n---\n\n# Inquiry: %s\n\n%s\n' "$1" "$2"
}

## 1. CONTROL: the rig's write path stores a filing and says so.
echo "-- 1. control: a filing on a new subject is stored --"
rigFile "rig unrelated subject" "The rig can write." > "$rigTmp/other.md"
rigOp --upsert-inbox-inquiry magic-coordinator inquiry-20261116T1000Z-rig-unrelated.md --from-file "$rigTmp/other.md"
rigAssert "the filing is stored and the call succeeds" "$rigRc:$( rigIn inquiry-20261116T1000Z-rig-unrelated.md )" "0:yes"
rigAssert "and it says it wrote the item" "$( rigSaid x 'member-inbox-upsert: wrote inquiry-20261116T1000Z-rig-unrelated.md' )" 1

## 2. The open inquiry on this subject, whose own filing is the merge target.
echo "-- 2. the open inquiry the next filing is merged into --"
rigFile "rig merge notice subject" "The first filing." > "$rigTmp/first.md"
rigOp --upsert-inbox-inquiry magic-coordinator inquiry-20261116T1001Z-rig-merge-subject.md --from-file "$rigTmp/first.md"
rigTarget="$rigData/inboxes/magic-coordinator/incoming/inquiry-20261116T1001Z-rig-merge-subject.md"
rigAssert "the target inquiry is stored" "$rigRc:$( [ -f "$rigTarget" ] && printf yes || printf no )" "0:yes"
rigBefore="$( rigTile "$rigTarget" )"

## 3. The second filing on that same subject: merged, and the write gate refuses the merged item.
echo "-- 3. a second filing on the same subject is merged, and the gate refuses the merge --"
rigFile "rig merge notice subject" "The second filing." > "$rigTmp/second.md"
rigOp --upsert-inbox-inquiry magic-coordinator inquiry-20261116T1002Z-rig-merge-subject.md --from-file "$rigTmp/second.md"
rigAssert "the refused merge exits non-zero" "$rigRc" 1
rigAssert "the gate refused the merged item's frontmatter" "$( rigSaid x 'contract-frontmatter' )" 1
rigAssert "NO SUCCESS NOTICE: the output holds no 'instead of a second item'" "$( rigSaid x 'instead of a second item' )" 0
rigAssert "the refusal names the filing as not stored" "$( rigSaid x 'inquiry-20261116T1002Z-rig-merge-subject.md is not stored' )" 1
rigAssert "the target is unchanged: not one byte of it" "$( rigTile "$rigTarget" )" "$rigBefore"
rigAssert "the target holds the first filing's text" "$( rigHolds "$rigTarget" 'The first filing.' )" yes
rigAssert "and no '## Added' heading was written into it" "$( rigHolds "$rigTarget" '## Added ' )" no
rigAssert "no second item of the merged filing's name is left in the inbox" "$( rigIn inquiry-20261116T1002Z-rig-merge-subject.md )" no

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ INQUIRY MERGE NOTICE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'INQUIRY_MERGE_NOTICE: OK (%d assertions, offline, temp store only)\n' "$rigPassCount"
