#!/usr/bin/env bash
## Behavioural check on `--confluence-comment-read --inline --since`: the footer and inline comment legs
## of one page, the replies under them, and the lower bound on `version.createdAt`. No socket is opened:
## the Atlassian request is faked, and the operation under test is the live one of this tree.
##
## Held, in this order:
##  1. the footer leg alone, as it was, with no inline row in it
##  2. --inline adds the inline leg, and every row carries its page
##  3. a reply is read under its parent's own leg, and carries its parent's id
##  4. --since cuts on version.createdAt, on every leg alike, and a reply newer than the bound under an
##     older parent still reads
##  5. a stamp outside the allowed form is refused, and the refusal names the form
##  6. control: a page with no comment prints its header and no row, at rc 0
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigOp="$rigPkg/sh-lib/atlassian/AgentsTools.InternOpAtlassianConfluenceCommentRead.include"
rigHelper="$rigPkg/sh-lib/atlassian/AgentsTools.AtlassianRequest.include"
rigJson="$rigPkg/sh-lib/harness/AgentsHarnessJsonField.awk"
for rigNeed in "$rigOp" "$rigHelper" "$rigJson" ; do
	[ -f "$rigNeed" ] || { echo "⛔ ERROR: no $rigNeed" >&2 ; exit 1 ; }
done
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsConfluenceCommentRead )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
MDSC_CMD='DistroAgentsTools'

## The helper is the live one, so its argument checks and its URL encoder are the code under test. The
## request itself is faked below it, per path: one fixture per leg, shaped as the v2 API answers.
. "$rigHelper"
AgentsToolsAtlassianCall(){ ## member, product, method, path, context, body
	case "$4" in
		*/pages/7000000001/footer-comments*) printf '%s' '{"results":[{"id":"8000000001","pageId":"7000000001","status":"current","version":{"authorId":"author-1","createdAt":"2026-11-19T10:00:00.000Z"},"body":{"storage":{"value":"<p>the footer one</p>"}}}]}' ; ;;
		*/pages/7000000001/inline-comments*) printf '%s' '{"results":[{"id":"8000000011","pageId":"7000000001","status":"current","resolutionStatus":"open","version":{"authorId":"author-1","createdAt":"2026-11-21T09:00:00.000Z"},"body":{"storage":{"value":"<p>the first inline one</p>"}}},{"id":"8000000013","pageId":"7000000001","status":"current","resolutionStatus":"open","version":{"authorId":"author-1","createdAt":"2026-11-21T08:00:00.000Z"},"body":{"storage":{"value":"<p>the second inline one</p>"}}},{"id":"8000000014","pageId":"7000000001","status":"current","resolutionStatus":"resolved","version":{"authorId":"author-1","createdAt":"2026-11-18T08:00:00.000Z"},"body":{"storage":{"value":"<p>one resolved, before the bound</p>"}}}]}' ; ;;
		*/inline-comments/8000000011/children*) printf '%s' '{"results":[{"id":"8000000012","pageId":"7000000001","status":"current","resolutionStatus":"open","parentCommentId":"8000000011","version":{"authorId":"author-2","createdAt":"2026-11-22T10:00:00.000Z"},"body":{"storage":{"value":"<p>the reply</p>"}}}]}' ; ;;
		*/children*) printf '%s' '{"results":[]}' ; ;;
		*/pages/7000000002/footer-comments*) printf '%s' '{"results":[]}' ; ;;
		*/pages/7000000002/inline-comments*) printf '%s' '{"results":[]}' ; ;;
		*) printf '%s\n' "🙋 WARNING: fake request: no fixture for $4" >&2 ; return 8 ; ;;
	esac
}
## The operation is dot-sourced from inside a function, the way the dispatcher sources it: its body uses
## `local` and reads its own `$@`, and both need a function's scope.
rigDispatch(){ ## the operation's own arguments
	set -- --intern-op-atlassian-confluence-comment-read --member rig-member --context probe "$@"
	. "$rigOp"
}
## One run: rc in rigRc, rows in rigOut, notices in rigErr.
rigRead(){
	rigRc=0 rigOut="" rigErr=""
	rigErr="$( rigDispatch "$@" 2>&1 > "$rigTmp/out" )" || rigRc=$?
	rigOut="$( cat "$rigTmp/out" )"
}
## The run's data rows, its header excluded.
rigRows(){ printf '%s\n' "$rigOut" | LC_ALL=C awk 'NR > 1 && NF > 0 { n++ ; } END { print n + 0 ; }' ; }
## One column of every data row, space-separated, the column named by its number.
rigCol(){ printf '%s\n' "$rigOut" | LC_ALL=C awk -F'\t' -v c="$1" 'NR > 1 && NF > 0 { printf "%s ", $c ; }' ; }
## The ids of the rows in one resolution status, space-separated.
rigStatus(){ printf '%s\n' "$rigOut" | LC_ALL=C awk -F'\t' -v want="$1" 'NR > 1 && NF > 0 && $7 == want { printf "%s ", $1 ; }' ; }
rigPass=0 rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

echo '-- 1. the footer leg alone --'
rigRead --page-id 7000000001
rigAssert 'the footer leg runs' "$rigRc" 0
rigAssert 'and prints its one footer comment' "$( rigRows )" 1
rigAssert 'with that comment id in the first column' "$( rigCol 1 )" '8000000001 '
rigAssert 'and no inline row in it' "$( rigCol 5 | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c -x -F '7000000001' || : )" 1

echo '-- 2. --inline adds the inline leg --'
rigRead --page-id 7000000001 --inline
rigAssert 'the inline leg runs' "$rigRc" 0
rigAssert 'and prints one footer row, three inline rows and the reply' "$( rigRows )" 5
rigAssert 'and every row carries its page' "$( rigCol 5 | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c -x -F '7000000001' || : )" 5
rigAssert 'and every open row keeps its own status, the footer one excepted' "$( rigStatus open )" '8000000011 8000000013 8000000012 '
rigAssert 'and the resolved row reads resolved, not open' "$( rigStatus resolved )" '8000000014 '

echo '-- 3. a reply is read under its parent, and names it --'
rigAssert 'the reply names the comment it answers' "$( printf '%s\n' "$rigOut" | LC_ALL=C awk -F'\t' '$1 == "8000000012" { print $8 ; }' )" '8000000011'
rigAssert 'and a comment that answers nothing names none' "$( printf '%s\n' "$rigOut" | LC_ALL=C awk -F'\t' '$1 == "8000000011" { print "[" $8 "]" ; }' )" '[]'

echo '-- 4. --since cuts on version.createdAt, on every leg --'
rigRead --page-id 7000000001 --inline --since 2026-11-20
rigAssert 'the bound cuts the older rows out, and keeps the reply under a kept parent' "$( rigCol 1 )" '8000000011 8000000013 8000000012 '
rigRead --page-id 7000000001 --inline --since 2026-11-21T09:00:00.000Z
rigAssert 'the bound keeps the row stamped exactly at it' "$( rigCol 1 )" '8000000011 8000000012 '
rigRead --page-id 7000000001 --since 2026-11-20
rigAssert 'the bound cuts the footer leg too, and the run still succeeds' "$rigRc:$( rigRows )" '0:0'

echo '-- 5. a stamp outside the allowed form is refused --'
rigRead --page-id 7000000001 --inline --since 20-11-2026
rigAssert 'the run is refused' "$rigRc" 1
case "$rigErr" in
	*'ISO 8601 UTC date'*) rigAssert 'and the refusal names the form' yes yes ; ;;
	*) rigAssert 'and the refusal names the form' "$rigErr" 'a line naming the form' ; ;;
esac
rigAssert 'and no row was printed' "$( rigRows )" 0

echo '-- 6. control: a page with no comment --'
rigRead --page-id 7000000002 --inline
rigAssert 'an empty page runs at 0' "$rigRc" 0
rigAssert 'and prints its header and no row' "$( rigRows )" 0

if [ "$rigFail" = 0 ] ; then printf 'CONFLUENCE_COMMENT_READ: OK (%s assertions, offline)\n' "$rigPass" ; exit 0 ; fi
printf '⛔ CONFLUENCE COMMENT READ FAILED: %s of %s assertion(s)\n' "$rigFail" "$(( rigPass + rigFail ))" ; exit 1
