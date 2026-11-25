#!/usr/bin/env bash
## Behavioural check on the `doc-comments` input scan: `input-scan-def: doc-comments` gives a routine one
## line per page comment still open, in the pages the scan covers, and lists nothing else. No socket is
## opened: the Atlassian read and the workspace setting are faked, and the scan under test is the live one
## of this tree.
##
## Held, in this order:
##  1. the scan is a scan of the tooling: its name is on the list a routine's declaration is checked
##     against, the dispatcher routes its operation, and the wait knows it as a source
##  2. two pages carrying three open comments and one resolved comment print exactly three rows, each
##     with its page id and its comment id, and the resolved comment appears nowhere
##  3. a reply carries no resolution status, so it is no row of its own
##  4. a page set with nothing open prints its header and no row, and reads as empty input to the
##     spawner, so a pass with nothing to gather is never started
##  5. --page-id names the pages, and with none the workspace setting CONFLUENCE_PAGE_CHECK_PAGES does
##  6. a page set naming no page is refused, rc 6, naming the setting: no page and no comment must not
##     read the same
##  7. control: a page that cannot be read leaves its own NOTE and rc 2, and the other page's rows still
##     print
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigScan="$rigPkg/sh-lib/atlassian/AgentsTools.InternOpDocCommentsInputScan.include"
rigWait="$rigPkg/sh-lib/wait/AgentsTools.MemberWaitChat.include"
rigTool="$rigPkg/sh-scripts/DistroAgentsTools.fn.sh"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDocCommentsScanCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
MDSC_CMD='DistroAgentsTools'

rigPass=0 rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

## The read, as the two live pages print it: eight columns, the last the parent's id, empty where there is
## none. A reply carries no RESOLUTION_STATUS at all, exactly as the live read gives it.
DistroAgentsAtlassian(){ ## the read's own arguments
	case "$4" in
		4919689217)
			printf 'COMMENT_ID\tVERSION_AUTHOR_ID\tCREATED\tBODY\tPAGE_ID\tSTATUS\tRESOLUTION_STATUS\tPARENT_COMMENT_ID\n'
			printf '4922703874\ta\t2026-11-23T07:09:58.769Z\t<p>Fix date format</p>\t4919689217\tcurrent\topen\t\n'
			printf '4922376200\ta\t2026-11-23T07:10:08.255Z\t<p>Fix date format</p>\t4919689217\tcurrent\topen\t\n'
			printf '4918509717\ta\t2026-11-23T07:10:14.079Z\t<p>Fix date format</p>\t4919689217\tcurrent\tresolved\t\n'
		;;
		4919263234)
			printf 'COMMENT_ID\tVERSION_AUTHOR_ID\tCREATED\tBODY\tPAGE_ID\tSTATUS\tRESOLUTION_STATUS\tPARENT_COMMENT_ID\n'
			printf '4922671108\ta\t2026-11-23T07:25:44.083Z\t<p>Redundant. Remove</p>\t4919263234\tcurrent\topen\t\n'
			printf '4921294971\ta\t2026-11-23T07:26:42.014Z\t<p>Agreed, it can go.</p>\t4919263234\tcurrent\t\t4922671108\n'
		;;
		4920000001)
			printf 'COMMENT_ID\tVERSION_AUTHOR_ID\tCREATED\tBODY\tPAGE_ID\tSTATUS\tRESOLUTION_STATUS\tPARENT_COMMENT_ID\n'
			printf '4920000011\ta\t2026-11-24T09:00:00.000Z\t<p>Answered already</p>\t4920000001\tcurrent\tresolved\t\n'
		;;
		4920000002)
			printf 'COMMENT_ID\tVERSION_AUTHOR_ID\tCREATED\tBODY\tPAGE_ID\tSTATUS\tRESOLUTION_STATUS\tPARENT_COMMENT_ID\n'
		;;
		4920000009)
			printf '⛔ ERROR: page 4920000009 could not be read\n' >&2
			return 1
		;;
		*)
			printf '⛔ ERROR: the rig names no page %s\n' "$4" >&2
			return 1
		;;
	esac
	return 0
}
## The workspace's own page set, as its setting holds it: a comma-separated list of ids.
rigSetting=""
AgentsToolsConfigOption(){ printf '%s\n' "$rigSetting" ; return 0 ; }
AgentsToolsAssertBareName(){ return 0 ; }

## One run of the scan, its own arguments, output on stdout and status in rigRc. A scan file that is not
## there is the red this check starts from, and it says so rather than passing on nothing.
rigRc=0 rigOut="" rigErr=""
rigScanRun(){ ## the operation's own arguments
	rigRc=0 rigOut="" rigErr=""
	if [ ! -f "$rigScan" ] ; then rigRc=127 ; rigOut="no $rigScan" ; return 0 ; fi
	rigOut="$( ( set -- --intern-op-doc-comments-input-scan "$@" ; . "$rigScan" ) 2> "$rigTmp/err" )" || rigRc=$?
	rigErr="$( < "$rigTmp/err" )"
}
rigRows(){ printf '%s\n' "$1" | LC_ALL=C awk -F '\t' 'NF >= 4 { n++ ; } END { print n + 0 ; }' ; }
rigRowField(){ printf '%s\n' "$1" | LC_ALL=C awk -F '\t' -v row="$2" -v col="$3" 'NF >= 4 && ++n == row { print $col ; exit ; }' ; }

echo '-- 1. the scan is a scan of the tooling --'
rigNames="$( bash -c ". '$rigPkg/sh-lib/session/AgentsTools.InputScanDef.include' ; AgentsToolsInputScanNames" 2> /dev/null )" || rigNames=""
rigAssert 'doc-comments is a scan a routine may declare' "$( printf '%s\n' "$rigNames" | LC_ALL=C grep -c -x doc-comments )" 1
rigAssert 'and it is listed among its siblings' "$( printf '%s\n' "$rigNames" | LC_ALL=C awk 'NF { n++ ; } END { print n + 0 ; }' )" 9
rigRoute="$( "$rigTool" --intern-op-doc-comments-input-scan 2>&1 )" || :
case "$rigRoute" in
	*'syntax is <team-member>'*) rigAssert 'the dispatcher routes its operation' yes yes ; ;;
	*) rigAssert 'the dispatcher routes its operation' "$rigRoute" 'a line naming its syntax' ; ;;
esac
rigAssert 'and the wait carries it as a source' "$( LC_ALL=C awk '/^[[:space:]]*doc-comments\)/ { n++ ; } END { print n + 0 ; }' "$rigWait" 2> /dev/null )" 1

echo '-- 2. three open comments print three rows, and the resolved one nowhere --'
rigScanRun rig-member --page-id 4919689217 --page-id 4919263234
rigAssert 'the scan over the two pages succeeds' "$rigRc" 0
rigAssert 'exactly three rows print' "$( rigRows "$rigOut" )" 3
rigAssert 'the first row carries its page and its comment' "$( rigRowField "$rigOut" 1 1 ):$( rigRowField "$rigOut" 1 2 )" '4919689217:4922703874'
rigAssert 'the last row carries its page and its comment' "$( rigRowField "$rigOut" 3 1 ):$( rigRowField "$rigOut" 3 2 )" '4919263234:4922671108'
rigAssert 'a row carries its author and its created time' "$( rigRowField "$rigOut" 2 3 ):$( rigRowField "$rigOut" 2 4 )" 'a:2026-11-23T07:10:08.255Z'
rigAssert 'the resolved comment is nowhere in the scan' "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 4918509717 || : )" 0

echo '-- 3. a reply is no row of its own --'
rigAssert 'the reply under its parent appears nowhere' "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 4921294971 || : )" 0

echo '-- 4. nothing open prints the header and no row, and reads as empty input --'
rigScanRun rig-member --page-id 4920000001 --page-id 4920000002
rigAssert 'the scan over two quiet pages succeeds' "$rigRc" 0
rigAssert 'it prints its heading' "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c -F '## open page comments (doc-comments, rig-member): PAGE_ID COMMENT_ID AUTHOR CREATED' )" 1
rigAssert 'and no row' "$( rigRows "$rigOut" )" 0
bash -c ". '$rigPkg/sh-lib/session/AgentsTools.InputScanDef.include' ; printf '%s\n' \"\$1\" > '$rigTmp/quiet' ; AgentsToolsInputScanReportEmpty '$rigTmp/quiet'" _ "$rigOut" 2> /dev/null && rigQuiet=empty || rigQuiet=input
rigAssert 'and the spawner reads it as input of nothing' "$rigQuiet" empty

echo '-- 5. the pages are --page-id, else the workspace setting --'
rigAssert 'a named page set says where it came from' "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'from the definition line' )" 1
rigSetting='4920000001,4920000002'
rigScanRun rig-member
rigAssert 'with no --page-id the setting names the pages' "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'CONFLUENCE_PAGE_CHECK_PAGES' )" 1
rigAssert 'and the two pages of the setting are the scope' "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'scope: 2 page(s)' )" 1

echo '-- 6. a page set naming no page is refused, and says which setting --'
rigSetting=''
rigScanRun rig-member
rigAssert 'the scan refuses rather than reporting nothing' "$rigRc" 6
case "$rigErr" in
	*CONFLUENCE_PAGE_CHECK_PAGES*) rigAssert 'and it names the setting a workspace sets' yes yes ; ;;
	*) rigAssert 'and it names the setting a workspace sets' "$rigErr" 'a line naming CONFLUENCE_PAGE_CHECK_PAGES' ; ;;
esac

echo '-- 7. control: a page that cannot be read leaves its own note, and the other page still lists --'
rigScanRun rig-member --page-id 4920000009 --page-id 4919263234
rigAssert 'the scan reports partial rather than whole' "$rigRc" 2
rigAssert 'the page that failed is named' "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^\*\*NOTE:\*\* partial.*4920000009' )" 1
rigAssert 'and the page that read still lists its open comment' "$( rigRows "$rigOut" )" 1

if [ "$rigFail" = 0 ] ; then printf 'DOC_COMMENTS_SCAN: OK (%s assertions, offline)\n' "$rigPass" ; exit 0 ; fi
printf '⛔ DOC COMMENTS SCAN CHECK FAILED: %s of %s assertion(s)\n' "$rigFail" "$(( rigPass + rigFail ))" ; exit 1
