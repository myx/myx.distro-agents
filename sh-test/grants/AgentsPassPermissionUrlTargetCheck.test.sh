#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on --pass-permission with a full-URL target (S26 item 7): a target that
## is a whole URL is read as a URL, not as an absolute path that escaped its place, and the
## call returns rather than hanging. (AgentsTools.InternOpPermission.include,
## AgentsToolsPermissionEntryPlace)
##   1. THE CONTROL: a path target is judged on its path, so the rig reads the same parser the
##      tool does. A path outside every place is accepted as the path it is.
##   2. A full URL target is not refused as an absolute entry glob.
##   3. A URL prefix, `https://host/**`, is not refused as an absolute entry glob either.
##   4. The call returns inside a wall-clock bound; a call still running is ended here.
## Offline: no network, no git, a rig of this check's own in the workspace's sh-test scratch.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigGrants="$rigOrigin/myx/myx.distro-agents/sh-scripts/DistroAgentsGrants.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigGrants" ] || rigRefuse "the grants tool is missing from the origin: $rigGrants"
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsPassPermissionUrlTargetCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/agents/sessions/rig-session" "$rigTmp/data" "$rigTmp/skills/keeper-rig" "$rigTmp/skills/keeper-owner"
printf 'rig\n' > "$rigTmp/skills/keeper-rig/keeper-rig.basic.md"
printf 'rig\n' > "$rigTmp/skills/keeper-owner/keeper-owner.basic.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One --pass-permission, its whole output kept. The passer and the receiver are two different
## members, so the call reaches the target's own reading; whether the pass is then allowed is
## another question this check does not ask.
rigPass(){ ## target -- the call's output
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="/usr/bin:/bin" MMDAPP="$rigWs" \
		MDAT_DATA_ROOT="$rigTmp/data" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDLT_ORIGIN="$rigOrigin" \
		MDLT_OPTION="--run-from-path $rigOrigin" MDAT_SPAWN_AGENT=keeper-rig MDAT_SPAWN_SESSION_ID=rig-session \
		bash "$rigGrants" --pass-permission keeper-rig --to keeper-owner --tool WebFetch --target "$1" --kind once ) 2>&1
}
## Whether the output says the target was read as an absolute entry glob, which is the defect.
rigGlobRefusal(){ ## output -- prints refused|accepted
	case "$1" in
		*'entry glob is relative to its place, never absolute'*) printf 'refused' ;;
		*) printf 'accepted' ;;
	esac
}
## A command under a wall-clock bound: the target backgrounded directly, watched with kill -0,
## TERM then KILL, and waited on its real pid (reference/shell.md).
rigBounded(){ ## seconds, command... -- prints returned|hung
	local boundSec="$1" boundPid="" boundEnd
	shift
	( "$@" ) > "$rigTmp/bounded.out" 2>&1 < /dev/null &
	boundPid=$!
	boundEnd=$(( $( date +%s ) + boundSec ))
	while kill -0 "$boundPid" 2> /dev/null ; do
		if [ "$( date +%s )" -ge "$boundEnd" ] ; then
			kill -TERM "$boundPid" 2> /dev/null ; sleep 1 ; kill -KILL "$boundPid" 2> /dev/null ; wait "$boundPid" 2> /dev/null
			printf 'hung' ; return 0
		fi
		sleep 1
	done
	wait "$boundPid" 2> /dev/null
	printf 'returned'
}

echo "-- 1. the control: a path target is judged as a path --"
rigAssert "a path target is not refused for its shape" "$( rigGlobRefusal "$( rigPass '/Users/myx/Workspaces/ws-myx-devops/source/myx/**' )" )" "accepted"

echo "-- 2. a full URL target --"
rigAssert "a URL target is not read as an absolute entry glob" "$( rigGlobRefusal "$( rigPass 'https://example.com/page' )" )" "accepted"

echo "-- 3. a URL prefix --"
rigAssert "a URL prefix is not read as an absolute entry glob" "$( rigGlobRefusal "$( rigPass 'https://example.com/**' )" )" "accepted"

echo "-- 4. the call returns inside the bound --"
rigUrlPass(){ rigPass 'https://example.com/**' > /dev/null ; }
rigAssert "the call returns inside 60s" "$( rigBounded 60 rigUrlPass )" "returned"

printf '\n  %s passed, %s failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" -eq 0 ] || exit 1
printf 'PASS_PERMISSION_URL_TARGET: OK\n'
