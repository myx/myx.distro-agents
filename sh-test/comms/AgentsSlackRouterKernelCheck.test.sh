#!/usr/bin/env bash
## Behavioural check on the router of the Slack comms operations (epic 20261026-refactorings, S28.6): the scopes answer every Slack Wait asks for
## parses the router alone, never AgentsTools.CommsSlack.include (the Slack kernel, 1746 lines). The router sources the kernel only in the arms
## that use it. Held, run and not read (every file a call sources is logged by a line put at the head of each .include of a copy of the package):
##   1. THE ANSWER. A process that sources the router with --intern-op-comms-slack-read --print-required-scopes, as every Wait does: it prints the
##      scopes the operation has always printed, ends 0, and the files it sourced are the router and nothing else.
##   2. THE CALL. The same pair through the dispatcher, as the tools run it: the kernel is not among the files it sourced.
##   3. THE ARMS THAT NEED THE KERNEL. A react and a send of the member, over a Slack-shaped fake curl, still reach their Slack method: the
##      kernel is loaded where the arm uses it, so taking it out of the router's head breaks no operation.
##   4. THE INSTRUMENT. The log's reader is run on logs made by hand: one that names the kernel, one that does not, and a real source of the
##      kernel by hand in the copy, which the log must show. A reader that cannot fail is no check.
## Red recipe: on the router as it stands before S28.6 (line 10 sources the kernel before the case), sections 1 and 2 fail on "the kernel was sourced";
## sections 3 and 4 pass on it.
## Offline: a Slack-shaped fake curl is first on PATH, and every workspace is a folder of the rig's own under $MMDAPP/.local/agents/scratch/sh-test.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:=$MMDAPP/.local}"

rigPackageRel="myx/myx.distro-agents"
rigKernel="AgentsTools.CommsSlack.include"
rigRouter="AgentsTools.MemberCommsSlack.include"
rigMember="magic-tester"
rigScopesRead='channels:read channels:history groups:read groups:history im:read im:history mpim:read mpim:history im:write'

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
rigPackage="$MDLT_ORIGIN/$rigPackageRel"
[ -f "$rigPackage/sh-scripts/DistroAgentsTools.fn.sh" ] || rigRefuse "no dispatcher at the origin this workspace resolves: $rigPackage"
[ -f "$rigPackage/sh-lib/comms/$rigRouter" ] || rigRefuse "no router at the origin: $rigPackage/sh-lib/comms/$rigRouter"
[ -f "$rigPackage/sh-lib/comms/$rigKernel" ] || rigRefuse "no kernel at the origin: $rigPackage/sh-lib/comms/$rigKernel"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so a stub would have no member to act as"

. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSlackRouterKernelCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap '[ -n "${RIG_KEEP:-}" ] && echo "kept: $rigTmp" || { chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp" ; }' EXIT

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

## THE READER. A log is the files one call sourced, a path a line.
rigNamed(){ ## log, a file name -- `named` where the log holds a path ending in that name, else `absent`
	LC_ALL=C awk -v want="$2" '{ n = split( $0, part, "/" ) ; if ( part[ n ] == want ) found = 1 ; } END { print found ? "named" : "absent" ; }' "$1"
}
rigFiles(){ ## log -- the include files it names, once each, a basename a line, in a line
	LC_ALL=C awk '{ n = split( $0, part, "/" ) ; if ( part[ n ] ~ /\.include$/ ) print part[ n ] ; }' "$1" | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//'
}

echo "-- 4. the instrument: the reader on logs made by hand --"
printf '/x/sh-lib/comms/%s\n/x/sh-lib/comms/%s\n' "$rigRouter" "$rigKernel" > "$rigTmp/log.kernel"
printf '/x/sh-lib/comms/%s\n' "$rigRouter" > "$rigTmp/log.routeronly"
: > "$rigTmp/log.empty"
rigAssert "reader: a log naming the kernel says named" "$( rigNamed "$rigTmp/log.kernel" "$rigKernel" )" named
rigAssert "reader: a log of the router alone says absent" "$( rigNamed "$rigTmp/log.routeronly" "$rigKernel" )" absent
rigAssert "reader: a log of nothing says absent" "$( rigNamed "$rigTmp/log.empty" "$rigKernel" )" absent
rigAssert "reader: the files of the router alone are the router" "$( rigFiles "$rigTmp/log.routeronly" )" "$rigRouter"
rigAssert "reader: the files of a log naming both are both" "$( rigFiles "$rigTmp/log.kernel" )" "$rigKernel $rigRouter"
rigAssert "reader: the files of a log of nothing are none" "$( rigFiles "$rigTmp/log.empty" )" ""

echo "-- the rig: a copy of the package under check, a log line at the head of each include, a fake curl --"
rigOrigin="$rigTmp/origin"
mkdir -p "$rigOrigin/myx" "$rigTmp/bin" "$rigTmp/ws/.local/.agents" "$rigTmp/ws/.local/agents" "$rigTmp/data" || exit 1
for rigPkg in "$MDLT_ORIGIN"/myx/myx.distro-* "$MDLT_ORIGIN"/myx/myx.common ; do
	[ -d "$rigPkg" ] || continue
	rigCopyTree "$rigPkg" "$rigOrigin/myx/${rigPkg##*/}" || rigRefuse "the copy of ${rigPkg##*/} failed"
done
[ "$( find "$rigOrigin" -type l | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" = "0" ] || rigRefuse "the copy holds a link, so a rig could reach the real tree"
find "$rigOrigin" -name .git -prune -exec rm -rf {} +
rigLogLine='[ -z "${RIG_SOURCED_LOG:-}" ] || printf '"'"'%s\n'"'"' "${BASH_SOURCE[0]}" >> "$RIG_SOURCED_LOG"'
find "$rigOrigin/$rigPackageRel/sh-lib" -name '*.include' -type f | while IFS= read -r rigFile ; do
	LC_ALL=C awk -v logLine="$rigLogLine" 'NR == 1 && $0 !~ /^#!/ { print logLine ; } { print ; } NR == 1 && $0 ~ /^#!/ { print logLine ; }' "$rigFile" > "$rigFile.rigtmp" \
		&& cat "$rigFile.rigtmp" > "$rigFile" && rm -f "$rigFile.rigtmp" || exit 1
done || rigRefuse "the log line could not be put at the head of the includes"
rigTools="$rigOrigin/$rigPackageRel/sh-scripts/DistroAgentsTools.fn.sh"
rigRouterCopy="$rigOrigin/$rigPackageRel/sh-lib/comms/$rigRouter"
rigKernelCopy="$rigOrigin/$rigPackageRel/sh-lib/comms/$rigKernel"
[ "$( LC_ALL=C sed -n 2p "$rigRouterCopy" | LC_ALL=C cut -c1-40 )" = '[ -z "${RIG_SOURCED_LOG:-}" ] || printf ' ] || rigRefuse "the router of the copy carries no log line"
[ "$( LC_ALL=C sed -n 2p "$rigKernelCopy" | LC_ALL=C cut -c1-40 )" = '[ -z "${RIG_SOURCED_LOG:-}" ] || printf ' ] || rigRefuse "the kernel of the copy carries no log line"

cat > "$rigTmp/bin/curl" <<'RIG_CURL'
#!/usr/bin/env bash
## Slack-shaped fake curl: logs each method and answers it from a table. Opens no socket.
cat > /dev/null
rigMethod="no-method"
for rigArg in "$@" ; do
	case "$rigArg" in
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ; rigMethod="${rigMethod%%\?*}" ;;
		http://*|https://*) rigMethod="url:$rigArg" ;;
	esac
done
printf '%s\n' "$rigMethod" >> "$RIG_CURL_LOG"
case "$rigMethod" in
	auth.test) printf '{"ok":true,"user_id":"URIGSELF1"}\n' ;;
	conversations.info) printf '{"ok":true,"channel":{"id":"CRIG00001","is_channel":true,"is_member":true,"name":"rig"}}\n' ;;
	chat.postMessage) printf '{"ok":true,"channel":"CRIG00001","ts":"1700000001.000100","message":{"user":"URIGSELF1","text":"RIG-BODY","ts":"1700000001.000100"}}\n' ;;
	*) printf '{"ok":true}\n' ;;
esac
RIG_CURL
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check could issue real requests"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigTmp/ws/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigTmp/ws/.local/.agents/$rigMember.agent.env"
RIG_CURL_LOG="$rigTmp/curl.log"
RIG_SOURCED_LOG="$rigTmp/sourced.log"
export RIG_CURL_LOG RIG_SOURCED_LOG

rigEnv(){ ## the command's own environment: a workspace of the rig, the copy as the origin, the rig acting as the member
	( cd "$rigTmp/ws" && env -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_ID \
		MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$rigOrigin" MDAT_DATA_ROOT="$rigTmp/data" MDAT_SPAWN_AGENT="$rigMember" "$@" ) \
		> "$rigTmp/call.out" 2> "$rigTmp/call.err" < /dev/null ; rigRc=$?
}
rigScopes(){ ## -- the scopes the last call printed, on one line
	LC_ALL=C tr '\n' ' ' < "$rigTmp/call.out" | LC_ALL=C sed 's/ $//'
}

echo "-- 1. the answer, as every Wait asks for it: the router sourced with the pair --"
: > "$RIG_SOURCED_LOG"
rigEnv bash -c '. "$1" --intern-op-comms-slack-read --print-required-scopes' rig "$rigRouterCopy"
rigAssert "the router answers with the scopes it has always printed, and ends 0" "$rigRc:$( rigScopes )" "0:$rigScopesRead"
rigAssert "the router was sourced (the log can see it)" "$( rigNamed "$RIG_SOURCED_LOG" "$rigRouter" )" named
rigAssert "the kernel was not sourced" "$( rigNamed "$RIG_SOURCED_LOG" "$rigKernel" )" absent
rigAssert "the files it sourced are the router and nothing else" "$( rigFiles "$RIG_SOURCED_LOG" )" "$rigRouter"

echo "-- 2. the same pair through the dispatcher, as the tools run it --"
: > "$RIG_SOURCED_LOG"
rigEnv bash "$rigTools" --intern-op-comms-slack-read --print-required-scopes
rigAssert "the dispatcher prints the same scopes and ends 0" "$rigRc:$( rigScopes )" "0:$rigScopesRead"
rigAssert "the kernel was not sourced" "$( rigNamed "$RIG_SOURCED_LOG" "$rigKernel" )" absent

echo "-- 3. the arms that need the kernel still reach their Slack method --"
: > "$RIG_CURL_LOG" ; : > "$RIG_SOURCED_LOG"
rigEnv bash "$rigTools" --slack-react "$rigMember" CRIG00001:1700000000.000100 eyes
rigAssert "react: ended 0 and asked reactions.add" "$rigRc:$( LC_ALL=C grep -c -x -F reactions.add "$RIG_CURL_LOG" | LC_ALL=C tr -d ' ' )" "0:1"
: > "$RIG_CURL_LOG" ; : > "$RIG_SOURCED_LOG"
rigEnv bash "$rigTools" --slack-send-message "$rigMember" CRIG00001 RIG-BODY
rigAssert "send: ended 0 and asked chat.postMessage" "$rigRc:$( LC_ALL=C grep -c -x -F chat.postMessage "$RIG_CURL_LOG" | LC_ALL=C tr -d ' ' )" "0:1"

## A Wait over a Slack source loads the router with the pair and then needs the kernel's resolver and readers: the kernel must be loaded where the Wait uses it.
for rigSource in slack:CRIG00001 slack:magic-team ; do
	: > "$RIG_CURL_LOG"
	rigEnv bash "$rigTools" --wait-for-input --team-member "$rigMember" --wait-source "$rigSource" --wait-timeout 2 --wait-poll-interval 1
	rigAssert "a Wait over $rigSource: ended 0, ran its rounds, read the conversation, and no command was missing" \
		"$rigRc:$( LC_ALL=C grep -c 'poll round' "$rigTmp/call.out" | LC_ALL=C awk '{ print ( $1 > 0 ) ? "ran" : "did-not-run" ; }' ):$( LC_ALL=C grep -c -x -F conversations.history "$RIG_CURL_LOG" | LC_ALL=C awk '{ print ( $1 > 0 ) ? "read" : "not-read" ; }' ):$( LC_ALL=C grep -c 'command not found' "$rigTmp/call.err" | LC_ALL=C tr -d ' ' )" "0:ran:read:0"
done

echo "-- 4b. the instrument sees the kernel when it is sourced --"
: > "$RIG_SOURCED_LOG"
rigEnv bash -c '. "$1"' rig "$rigKernelCopy"
rigAssert "control: a source of the kernel by hand is named in the log" "$( rigNamed "$RIG_SOURCED_LOG" "$rigKernel" )" named

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SLACK ROUTER KERNEL CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SLACK_ROUTER_KERNEL: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
