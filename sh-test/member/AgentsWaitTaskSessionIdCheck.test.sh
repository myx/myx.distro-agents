#!/usr/bin/env bash
## AgentsWaitTaskSessionIdCheck -- epic S21.11, root cause #1: `AgentsToolsTaskCall` (AgentsTools.ToolTask.include)
## keeps its detached tasks under a SESSION it reads from harnessSessionId/MDAT_SPAWN_SESSION_ID/CLAUDE_CODE_SESSION_ID,
## none of which a plain `--wait-for-input` call sets -- so it silently skips detaching the probe at the wait's own
## bound (AgentsTools.MemberWait.include's round loop) and runs it straight through, however long it takes. This
## check asserts the plain, narrow signal: a costly probe taking longer than the wait's bound shows a detached task
## in WAIT-RESULT ("detached at the bound"). It does not assert a wall-clock duration -- a separate, second cause
## still affects that (tracked apart). Offline: a Slack-shaped fake curl, every process this check starts is ended
## by it, through the rig's process helper.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tooling script is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || exit 1
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWaitTaskSessionIdCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
trap 'rigProcSignalWithChildren KILL $rigStarted ; rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigTextHas(){ ## haystack, needle
	case "$1" in *"$2"*) printf yes ;; *) printf no ;; esac
}

rigDir="$rigTmp/scene"
rigSession="rig-sess-taskid"
mkdir -p "$rigDir/bin" "$rigDir/ws/.local/.agents" "$rigDir/ws/.local/agents/sessions/$rigSession" "$rigDir/ws/.local/temp" "$rigDir/skills/rig-member"
printf 'rig-member\n' > "$rigDir/skills/rig-member/rig-member.basic.md"
printf 'SLACK_USER_TOKEN=rig-user-token-MEMBER\n' > "$rigDir/ws/.local/.agents/rig-member.agent.env"
cat > "$rigDir/bin/curl" <<-'CURLEOF'
	#!/usr/bin/env bash
	set -u
	cat > /dev/null
	fixUrl=""
	for fixArg in "$@" ; do case "$fixArg" in https://*) fixUrl="$fixArg" ;; esac ; done
	fixMethod="${fixUrl#https://slack.com/api/}" ; fixMethod="${fixMethod%%\?*}"
	case "$fixMethod" in
		conversations.list)
			printf '{"ok":true,"channels":[{"id":"DFIX0000001","is_im":true,"user":"UFIX0000001"},{"id":"DFIX0000002","is_im":true,"user":"UFIX0000002"},{"id":"DFIX0000003","is_im":true,"user":"UFIX0000003"}],"response_metadata":{"next_cursor":""}}\n'
		;;
		conversations.history|conversations.replies) sleep 1 ; printf '{"ok":true,"messages":[],"has_more":false,"response_metadata":{"next_cursor":""}}\n' ;;
		conversations.info)
			fixChannel=""
			for fixArg in "$@" ; do case "$fixArg" in channel=*) fixChannel="${fixArg#channel=}" ;; esac ; done
			printf '{"ok":true,"channel":{"id":"%s","is_im":true,"is_mpim":false,"is_channel":false,"is_group":false,"user":"UFIX%s"}}\n' "$fixChannel" "${fixChannel#DFIX}"
		;;
		*) printf '{"ok":false,"error":"fixture_unknown_method"}\n' ;;
	esac
	exit 0
CURLEOF
chmod +x "$rigDir/bin/curl"

rigWaitOp(){
	( cd "$rigDir/ws" && env -u MDAT_SESSION_THREAD -u MDAT_SPAWN_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u MDAT_CONVERSATION_THREADS -u MDAT_SPAWN_AGENT -u MDAT_TEAM_MEMBER \
		"PATH=$rigDir/bin:$PATH" "MMDAPP=$rigDir/ws" "MDLT_ORIGIN=$MDLT_ORIGIN" "MDAT_SKILLSET_ROOT=$rigDir/skills" \
		python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 30 -- \
		bash "$rigTool" --wait-for-input --team-member rig-member --wait-default --wait-session-id "$rigSession" --wait-timeout 2 --wait-source "dms:rig-member" )
}

echo "-- a costly probe (3 DMs at 1s each) past a 2s bound detaches, instead of running straight through --"
rigOut="$( rigWaitOp )"
rigAssert "THE FIX: WAIT-RESULT names a detached task for the dms: probe" "$( rigTextHas "$rigOut" "detached at the bound" )" yes

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WAIT TASK SESSION ID CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_TASK_SESSION_ID: OK (%d assertions, offline)\n' "$rigPassCount"
