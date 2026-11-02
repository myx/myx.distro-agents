#!/usr/bin/env bash
## Behavioural check on the status of the router of the Slack comms operations (epic 20261026-refactorings, S28.8): the router passes the
## status of the operation on to whoever sourced it, and the dispatcher that sources it ends with that status. Held, run and not read:
##   1. THE SOURCER. A process that sources the router with a failing call sees the status of the failure on the `.` command: a client stub
##      named for a member that is no client, and an operation the router does not know. A call that succeeds is seen as 0.
##   2. THE DISPATCHER. The same calls through DistroAgentsTools.fn.sh end non-zero, and so does a real operation that fails at Slack
##      (a reaction Slack refuses with ok:false, over a Slack-shaped fake curl). A reaction Slack accepts, and the scopes answer, end 0.
##   3. THE INSTRUMENT. The probe that reads a sourced file's status is run on two files made by hand, one that returns 0 and one that
##      returns 3: it reads each. A probe that reads the same for both is no check.
## Red recipe: on the router as it stands before S28.8, which ends with `return 0` whatever the operation returned, every failing call of
## sections 1 and 2 reads 0 where non-zero is wanted; the controls that succeed and section 3 pass on it.
## Offline: a Slack-shaped fake curl is first on PATH, and the workspace is a folder of the rig's own under $MMDAPP/.local/agents/scratch/sh-test.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:=$MMDAPP/.local}"

rigPackageRel="myx/myx.distro-agents"
rigMember="magic-tester"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
rigPackage="$MDLT_ORIGIN/$rigPackageRel"
rigRouter="$rigPackage/sh-lib/comms/AgentsTools.MemberCommsSlack.include"
rigTools="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
[ -f "$rigTools" ] || rigRefuse "no dispatcher at the origin this workspace resolves: $rigPackage"
[ -f "$rigRouter" ] || rigRefuse "no router at the origin: $rigRouter"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so a stub would have no member to act as"

. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSlackRouterStatusCheck )" || exit 1
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
rigNonZero(){ ## a status -- `non-zero` or `zero`, and a word that is no number is no status
	case "$1" in ''|*[!0-9]*) printf 'not-a-status:%s' "$1" ;; 0) printf zero ;; *) printf non-zero ;; esac
}

mkdir -p "$rigTmp/bin" "$rigTmp/ws/.local/.agents" "$rigTmp/ws/.local/agents" "$rigTmp/data" || exit 1
cat > "$rigTmp/bin/curl" <<'RIG_CURL'
#!/usr/bin/env bash
## Slack-shaped fake curl: logs each method and answers it from a table; reactions.add answers ok:false while RIG_REACT_REFUSED is set. Opens no socket.
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
	reactions.add) [ -z "${RIG_REACT_REFUSED:-}" ] && printf '{"ok":true}\n' || printf '{"ok":false,"error":"channel_not_found"}\n' ;;
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
export RIG_CURL_LOG
: > "$RIG_CURL_LOG"

rigEnv(){ ## the command's own environment: a workspace of the rig, the origin under check, the rig acting as the member
	( cd "$rigTmp/ws" && env -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_ID \
		MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigTmp/data" MDAT_SPAWN_AGENT="$rigMember" "$@" ) \
		> "$rigTmp/call.out" 2> "$rigTmp/call.err" < /dev/null ; rigRc=$?
}
rigSourced(){ ## the file to source, its arguments -- the status the sourcer reads on the `.` command
	rigEnv bash -c '. "$1" "${@:2}" ; printf "SOURCED-STATUS=%s\n" "$?"' rig "$@"
	LC_ALL=C sed -n 's/^SOURCED-STATUS=//p' "$rigTmp/call.out" | LC_ALL=C tail -1
}
rigDispatched(){ ## the dispatcher's arguments -- the status the dispatcher ends with
	rigEnv bash "$rigTools" "$@"
	printf '%s' "$rigRc"
}

echo "-- 3. the instrument: the probe on two files made by hand --"
printf 'return 0\n' > "$rigTmp/ret0.include"
printf 'return 3\n' > "$rigTmp/ret3.include"
rigAssert "probe: a file that returns 0 reads 0" "$( rigSourced "$rigTmp/ret0.include" )" 0
rigAssert "probe: a file that returns 3 reads 3" "$( rigSourced "$rigTmp/ret3.include" )" 3
rigAssert "reader: 0 is zero, 3 is non-zero, and nothing is no status" "$( rigNonZero 0 ) $( rigNonZero 3 ) $( rigNonZero '' )" "zero non-zero not-a-status:"

echo "-- 1. the sourcer reads the status of the operation --"
rigAssert "a client stub named for a member that is no client: the source ends non-zero" "$( rigNonZero "$( rigSourced "$rigRouter" --client-comms-slack-read notaclient )" )" non-zero
rigAssert "an operation the router does not know: the source ends non-zero" "$( rigNonZero "$( rigSourced "$rigRouter" --intern-op-comms-slack-nonsense )" )" non-zero
rigAssert "control: the scopes answer, which succeeds: the source ends 0" "$( rigSourced "$rigRouter" --intern-op-comms-slack-read --print-required-scopes )" 0

echo "-- 2. the dispatcher ends with the status of the operation --"
rigAssert "a client stub named for a member that is no client: the dispatcher ends non-zero" "$( rigNonZero "$( rigDispatched --client-comms-slack-read notaclient )" )" non-zero
rigAssert "an operation the router does not know: the dispatcher ends non-zero" "$( rigNonZero "$( rigDispatched --intern-op-comms-slack-nonsense )" )" non-zero
: > "$RIG_CURL_LOG"
RIG_REACT_REFUSED=1 rigDispatched --slack-react "$rigMember" CRIG00001:1700000000.000100 eyes > "$rigTmp/refused.status"
rigAssert "a reaction Slack refuses: it asked reactions.add" "$( LC_ALL=C grep -c -x -F reactions.add "$RIG_CURL_LOG" | LC_ALL=C awk '{ print ( $1 > 0 ) ? "asked" : "not-asked" ; }' )" asked
rigAssert "a reaction Slack refuses: its own error says it was not added" "$( LC_ALL=C grep -c 'COULD NOT REACT' "$rigTmp/call.err" | LC_ALL=C awk '{ print ( $1 > 0 ) ? "said" : "silent" ; }' )" said
rigAssert "a reaction Slack refuses: the dispatcher ends non-zero" "$( rigNonZero "$( cat "$rigTmp/refused.status" )" )" non-zero
: > "$RIG_CURL_LOG"
rigAssert "control: a reaction Slack accepts: the dispatcher ends 0" "$( rigDispatched --slack-react "$rigMember" CRIG00001:1700000000.000100 eyes )" 0
rigAssert "control: that reaction was asked of Slack" "$( LC_ALL=C grep -c -x -F reactions.add "$RIG_CURL_LOG" | LC_ALL=C awk '{ print ( $1 > 0 ) ? "asked" : "not-asked" ; }' )" asked
rigAssert "control: the scopes answer through the dispatcher ends 0" "$( rigDispatched --intern-op-comms-slack-read --print-required-scopes )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SLACK ROUTER STATUS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SLACK_ROUTER_STATUS: OK (%d assertions, offline, rig workspace only)\n' "$rigPassCount"
