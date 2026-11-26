#!/usr/bin/env bash
## Behavioural check on who may write the team's documents and tickets. The owner's rulings: the librarian owns the pages and holds the page
## operations and their access, and every member actualises the Jira state of the items it moves. So the page writes are magic-coordinator's and
## magic-librarian's, the Jira state writes (transition, update, comment) are any member's, and the rest of the coordinator's list stays the
## coordinator's. The checks the dispatcher asks, AgentsToolsMagicCallerCheck, run through a stand-in .fn.sh of this rig.
## Held:
##   1. magic-librarian passes for the page writes: page create, page update, page move, comment add and comment resolve, and for the Trello comment.
##   2. any member passes for the Jira writes of an item it moves: issue create, issue link-page, issue transition, issue update and comment add.
##   3. CONTROLS: another member is refused a page write. magic-librarian is refused a page delete, a space create, a Jira issue delete and a project delete.
##   4. the console and magic-coordinator pass for every one of them.
## Offline: a rig workspace and member set of this check's own; no operation of the tooling acts.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigInclude="$rigPackage/sh-lib/member/AgentsTools.CallerCheck.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the caller-check include is not at the origin: $rigInclude"
rigTmp="$( mkdir -p "${MMDAPP:?⛔ ERROR: MMDAPP is not set}/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsLibrarianPageWriteCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws/.local/.agents" "$rigTmp/home" "$rigTmp/data"
for rigName in magic-coordinator magic-librarian keeper-myx ; do
	mkdir -p "$rigTmp/skills/$rigName"
	printf 'rig\n' > "$rigTmp/skills/$rigName/$rigName.basic.md"
	printf 'rig\n' > "$rigTmp/skills/$rigName/$rigName.armed.md"
done
printf '#!/usr/bin/env bash\nMDSC_CMD=DistroAgentsTools\n. "%s" || exit 97\n"$@"\n' "$rigInclude" > "$rigTmp/RigStandIn.fn.sh"
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigAsRc(){ ## member or console, operation -- the check's rc
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigTmp/ws" MDAT_DATA_ROOT="$rigTmp/data" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		$( [ "$1" = console ] || printf 'MDAT_SPAWN_AGENT=%s MDAT_SPAWN_SESSION_ID=rig-caller-%s' "$1" "$1" ) \
		bash -c 'cd "$MMDAPP" && exec bash "$@"' rig "$rigTmp/RigStandIn.fn.sh" AgentsToolsMagicCallerCheck "$2" > /dev/null 2>&1 < /dev/null
	printf '%s' "$?"
}
rigRows(){ ## member, want rc, operations... -- one assert for the whole row
	local rowWho="$1" rowWant="$2" rowOp rowGot="" ; shift 2
	for rowOp in "$@" ; do rowGot="$rowGot$( rigAsRc "$rowWho" "$rowOp" )" ; done
	rigAssert "$rowWho is $( [ "$rowWant" = 0 ] && echo passed || echo refused ) for $*" "$rowGot" "$( printf '%*s' "$#" '' | tr ' ' "$rowWant" )"
}
rigRows magic-librarian 0 confluence-page-create confluence-page-update confluence-page-move confluence-comment-add confluence-comment-resolve trello-post-comment
rigRows keeper-myx 0 jira-issue-create jira-issue-transition jira-issue-update jira-comment-add jira-issue-link-page
rigRows magic-librarian 0 jira-issue-create jira-issue-transition jira-issue-update jira-comment-add jira-issue-link-page
rigRows keeper-myx 1 confluence-page-create confluence-page-update confluence-page-move confluence-comment-add confluence-comment-resolve trello-post-comment
rigRows magic-librarian 1 confluence-page-delete confluence-space-create jira-issue-delete jira-project-delete
rigRows magic-coordinator 0 confluence-page-create confluence-page-update confluence-page-delete jira-issue-create jira-issue-transition
rigRows console 0 confluence-page-update confluence-page-delete jira-issue-create jira-issue-transition
printf '%s: %s passed, %s failed\n' "${0##*/}" "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" = 0 ]
