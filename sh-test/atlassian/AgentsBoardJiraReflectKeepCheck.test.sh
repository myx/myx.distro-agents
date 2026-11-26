#!/usr/bin/env bash
## Behavioural check on the board's Jira mirror keeping the key it resolved (sh-lib/atlassian/AgentsTools.BoardJiraReflect.include):
## the first write of an item searches the site and keeps the key, and every later write of the same item asks for the issue
## directly, so a board move no longer pays the label search. Held, against the real include with a recording site:
##   1. FIRST WRITE: one label search, a create, and the key kept in the index.
##   2. SECOND WRITE: no search at all, the issue read by the kept key, and the index unchanged.
##   3. CONTROL: another item's first write still searches, so row 2 is about the kept key and not about the recorder.
## RED RECIPE, measured 2026-11-25: before the change every write searched (two to four site calls a move). With the
## search left unguarded row 2 fails, one search seen where none is wanted.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
[ -d "$rigPackage" ] || { echo "⛔ ERROR: no $rigPackage" >&2 ; exit 1 ; }
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsBoardJiraReflectKeepCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigRoot="$rigTmp/root"
rigData="$rigTmp/data"
mkdir -p "$rigRoot/myx" "$rigData" || exit 1
rsync -rtLO --exclude=.git "$rigPackage/" "$rigRoot/myx/myx.distro-agents/" || exit 1
rigLog="$rigTmp/site.log"
cat > "$rigRoot/myx/myx.distro-agents/sh-scripts/DistroAgentsAtlassian.fn.sh" <<'RIGSITE'
#!/usr/bin/env bash
## The site a check answers for: every call is recorded, a search finds nothing first and a row for another item only,
## a create mints a key, and a read answers an empty label list.
printf '%s\n' "$*" >> "$RIG_JIRA_LOG"
case "$*" in
	*--jira-issue-search*)
		case "$*" in *"magic-item-task-rig-two"*) printf 'RIGPROJ-2\tTask\tBacklog\n' ;; esac
	;;
	*--jira-issue-create*) printf '{"key":"RIGPROJ-1"}\n' ;;
	*--jira-issue-read*) printf '{"fields":{"labels":["magic-type-task"],"status":{"name":"Backlog"}}}\n' ;;
esac
exit 0
RIGSITE
chmod +x "$rigRoot/myx/myx.distro-agents/sh-scripts/DistroAgentsAtlassian.fn.sh"
rigPassCount=0
rigFailCount=0
rigAssert(){
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}
rigReflect(){ ## item filename, board state, create (may be empty)
	: > "$rigLog"
	MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$rigRoot" MDAT_DATA_ROOT="$rigData" RIG_JIRA_LOG="$rigLog" bash -c '
		. "$1/myx/myx.distro-agents/sh-lib/atlassian/AgentsTools.BoardJiraReflect.include" || exit 9
		AgentsToolsReflectModelsParse(){ printf "jira none\n" ; }
		AgentsToolsReflectKeyValue(){ case "$1" in REFLECT_JIRA_PROJECT) printf "RIGPROJ\n" ;; *) printf "" ;; esac ; }
		AgentsToolsBoardJiraReflect rig-member "$2" "$3" "${4:-}"
	' rig-reflect "$rigRoot" "$1" "$2" "${3:-}" 2> /dev/null
}
rigCalls(){ ## what the site was asked, one a line
	LC_ALL=C grep -c -- "$1" "$rigLog" 2> /dev/null || :
}
echo "-- 1. first write: search, create, key kept --"
rigReflect task-rig.md running
rigAssert "one label search" "$( rigCalls --jira-issue-search )" "1"
rigAssert "and a create" "$( rigCalls --jira-issue-create )" "1"
rigAssert "and the key is kept" "$( LC_ALL=C awk -F'\t' '$1 == "task-rig.md" { print $2 }' "$rigData/atlassian/jira-mirror.index" 2> /dev/null )" "RIGPROJ-1"
echo "-- 2. second write: no search, the issue read by the kept key --"
rigReflect task-rig.md processed
rigAssert "no search on the kept key" "$( rigCalls --jira-issue-search )" "0"
rigAssert "and the issue is read" "$( rigCalls --jira-issue-read )" "1"
rigAssert "and nothing is created again" "$( rigCalls --jira-issue-create )" "0"
echo "-- 3. a new item's create goes straight to the create --"
rigReflect task-rig-three.md running create
rigAssert "no search on a new item" "$( rigCalls --jira-issue-search )" "0"
rigAssert "and one create" "$( rigCalls --jira-issue-create )" "1"
rigAssert "and its key is kept" "$( LC_ALL=C awk -F'\t' '$1 == "task-rig-three.md" { print $2 }' "$rigData/atlassian/jira-mirror.index" 2> /dev/null )" "RIGPROJ-1"
echo "-- 4. a move inside one status bucket sends no transition --"
rigReflect task-rig-two.md pending
rigAssert "no transition on the first Backlog state" "$( rigCalls --jira-issue-transition )" "0"
rigAssert "and its labels are sent" "$( rigCalls --jira-issue-update )" "1"
rigReflect task-rig-two.md blocked
rigAssert "no transition on the next Backlog state" "$( rigCalls --jira-issue-transition )" "0"
rigAssert "and its labels are sent" "$( rigCalls --jira-issue-update )" "1"
echo "-- 5. control: another item searches --"
rigReflect task-rig-four.md running
rigAssert "another item still searches" "$( rigCalls --jira-issue-search )" "1"
if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ BOARD JIRA REFLECT KEEP CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'BOARD_JIRA_REFLECT_KEEP: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
