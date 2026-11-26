#!/usr/bin/env bash
## Behavioural check that an ask to the human-owner records the thread its post really went to. A post to him may
## land in the thread of his newest open message, and the send then reports the message (SENT_MESSAGE_TS) and the
## thread root (SENT_MESSAGE_THREAD_TS) apart. The pending record of the ask holds thread-ts of the thread root and
## question-ts of the message, so his reply in that thread matches it. With no thread line the record holds the
## message ts for both. One row for each site that opens a record after a send:
##    1. the prompt of an undo (AgentsToolsUndoAskOpen);
##    2. the prompt of a change held for approval (AgentsTools.InternOpChange.include);
##    3. the review prompt of a handback (AgentsReviewPromptPost);
##    4. a member's permission set (AgentsTools.InternOpPermissionSetAsk.include);
##    5. a call added to that open permission set (AgentsTools.InternOpEscalationPermissionAdd.include).
## Each row runs twice: the send reports thread T1 for message T2, and the control reports no thread line.
## Red recipe: put the message ts back as --thread-ts in any one of sites 1 to 4, or as the printed thread of site 5.
## Offline: a Slack-shaped fake curl is first on PATH, and a ps beside it lists the rig's own runs only.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDAT_WORKSPACE_MODE:=team-rig}" ; export MDAT_WORKSPACE_MODE
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTools="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$rigPackage/sh-lib/harness/AgentsUniversalHarness.sh"
rigBase="$rigPackage/sh-test/check-fixtures/change-approval.curl.stub.sh"
rigThreadRoot="1700000000.000001"
rigMessageTs="1700000009.000002"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTools" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTools"
[ -f "$rigHarness" ] || rigRefuse "the harness is not at the origin this workspace resolves: $rigHarness"
[ -f "$rigBase" ] || rigRefuse "the fake curl fixture is missing: $rigBase"
. "$rigPackage/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-copy.include.sh" || rigRefuse "the rig's copy helper is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || rigRefuse "the rig's temp helper is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-owner-writes.include.sh" || rigRefuse "the rig's owner writes are missing from the package"
rigTmp="$( rigTempDir AgentsAskRecordsRealThreadCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigLivePids=""
trap 'rigProcSignalWithChildren TERM $rigLivePids ; chmod -R u+w "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
## Every post answers as message T2, and as a reply in thread T1 where the scenario holds thread.fixed.
cat > "$rigTmp/bin/curl" <<'RIGCURL'
#!/bin/bash
rigHeader="$( cat )"
rigOut="$( printf '%s\n' "$rigHeader" | bash "$RIG_BASE_CURL" "$@" )" || exit $?
case "$*" in
	*api/chat.postMessage*)
		rigOut="$( printf '%s\n' "$rigOut" | sed 's/"ts":"[0-9.]*"/"ts":"1700000009.000002"/g' )"
		rigThread="$( cat "$RIG_SCENARIO/thread.fixed" 2> /dev/null )"
		case "$rigOut" in *thread_ts*) ;; *) [ -z "$rigThread" ] || rigOut="$( printf '%s\n' "$rigOut" | sed "s/\"user\":\"\([A-Za-z0-9]*\)\"/\"user\":\"\1\",\"thread_ts\":\"$rigThread\"/" )" ;; esac
	;;
	*api/conversations.replies*)
		[ ! -f "$RIG_SCENARIO/replies.fixed" ] || rigOut="$( printf '%s\n' "$rigOut" | sed 's/"ts":"[0-9.]*"/"ts":"1700000009.000002"/g' )"
	;;
esac
printf '%s\n' "$rigOut"
RIGCURL
chmod +x "$rigTmp/bin/curl"
rigRealTool ps "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
: > "$rigTmp/ps.list"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*)
		while read -r rigPsPid rigPsLine ; do
			kill -0 "$rigPsPid" 2> /dev/null || continue
			case "$*" in
				*pid=*) printf '%s %s\n' "$rigPsPid" "$rigPsLine" ;;
				*) printf '%s\n' "$rigPsLine" ;;
			esac
		done < "${0%/*}/../ps.list"
		exit 0
	;;
esac
exec "${0%/*}/ps.real" "$@"
RIGPS
chmod +x "$rigTmp/bin/ps"
rigHost="$( hostname -s 2> /dev/null )" || rigHost="unknown"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## One scenario: its own workspace, data root and Slack. The mode names whether the send reports a thread.
rigDir="" ; rigWs="" ; rigData="" ; rigSpawn="" ; rigWant=""
rigStart(){ ## scenario name, mode (thread|plain)
	local startMember
	rigDir="$rigTmp/$1-$2" ; rigWs="$rigDir/ws" ; rigData="$rigDir/data" ; rigSpawn="rig-child-$1"
	rigOwnerWs="$rigWs" rigOwnerData="$rigData" rigOwnerHome="$rigDir" rigOwnerSkills="$rigDir/data/skills"
	rigOwnerBoardReady || rigRefuse "the board could not be made ready to be written"
	mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned" "$rigWs/.local/temp"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-KEEPER\n' > "$rigWs/.local/.agents/keeper-myx.agent.env"
	for startMember in magic-coordinator keeper-myx magic-tester human-owner ; do
		mkdir -p "$rigWs/.local/agents/members/$startMember"
		printf -- '---\nname: %s\ndescription: rig member\n---\n' "$startMember" > "$rigWs/.local/agents/members/$startMember/SKILL.md"
		printf 'rig\n' > "$rigWs/.local/agents/members/$startMember/$startMember.basic.md"
	done
	rigInboxReady "$rigData" magic-coordinator
	: > "$rigDir/curl.log"
	if [ "$2" = "thread" ] ; then printf '%s\n' "$rigThreadRoot" > "$rigDir/thread.fixed" ; rigWant="$rigThreadRoot:$rigMessageTs" ; else rigWant="$rigMessageTs:$rigMessageTs" ; fi
}
rigEnv=()
rigRun(){ ## result file, command...
	local runOut="$1" ; shift
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigDir" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_SCENARIO="$rigDir" RIG_CURL_LOG="$rigDir/curl.log" RIG_BASE_CURL="$rigBase" "${rigEnv[@]+"${rigEnv[@]}"}" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			[ "$( command -v curl )" = "$RIG_TMP/bin/curl" ] || exit 98
			cd "$MMDAPP" && exec "$@"
		' rig "$@" > "$runOut" 2>&1
	printf '%s' "$?" > "$runOut.rc"
}
rigAs(){ ## result file, member, session id, DistroAgentsTools.fn.sh args...
	local asOut="$1" asMember="$2" asSession="$3"
	shift 3
	rigEnv=( MDAT_SPAWN_AGENT="$asMember" MDAT_SPAWN_SESSION_ID="$asSession" MDAT_SPAWN_SANDBOX_ROOT="$rigWs/.local/agents/spawned/$asSession" )
	rigRun "$asOut" bash "$rigTools" "$@"
	rigEnv=()
}
rigTool(){ ## result file, tool name, arguments JSON -- one served harness tool call of the session of keeper-myx
	printf '%s\n' "$3" > "$rigDir/tool.args"
	rigEnv=( MDAT_SPAWN_AGENT=keeper-myx MDAT_SPAWN_SESSION_ID="$rigSpawn" )
	rigRun "$1" bash -c 'exec bash "$0" --intern-tool "$1" < "$2"' "$rigHarness" "$2" "$rigDir/tool.args"
	rigEnv=()
}
## The work of a session of keeper-myx: a task, the dispatch that tracks it, its spawn record, and a stand-in process, so the session is live.
rigWork(){ ## review-by value (empty: none)
	printf -- '---\ntype: task\nowner: keeper-myx\n---\n\n# Rework the rig widget\n\nThe widget drops its last line. Make it keep it.\n' | rigOwnerBoardPut running "task-20261012T0000Z-rig.md"
	printf -- '---\ntype: dispatch\nowner: keeper-myx\nstatus: dispatch-started\nspawn-id: %s\ntracks: task-20261012T0000Z-rig\n%s---\n\n# rig dispatch\n' \
		"$rigSpawn" "${1:+review-by: $1
}" | rigOwnerBoardPut running "dispatch-20261012T0100Z-rig.md"
	mkdir -p "$rigWs/.local/agents/spawned/$rigSpawn" "$rigWs/.local/agents/sessions/$rigSpawn"
	printf -- '---\nsession-id: 5e55104a-rig\nspawn-id: %s\nparent-spawn-id: none\ntracking-name: %s\nhost: %s\nowner: keeper-myx\nstatus: spawn-started\nsession-thread: CSES00001:1700000000.000100\nspawns: dispatch-20261012T0100Z-rig\ndescription: rework the rig widget\n---\n' \
		"$rigSpawn" "$rigSpawn" "$rigHost" > "$rigWs/.local/agents/spawned/$rigSpawn/$rigSpawn.spawn.md"
	printf '%s\n' "CSES00001:1700000000.000100" > "$rigWs/.local/agents/spawned/$rigSpawn/session.thread"
	: > "$rigDir/transcript.log"
	printf '%s\n' "$rigDir/transcript.log" > "$rigWs/.local/agents/sessions/$rigSpawn/transcript"
	bash -c 'sleep 600 ; :' "$rigSpawn" > /dev/null 2>&1 < /dev/null &
	rigLivePids="$rigLivePids $!" ; rigProcNote "$!"
	printf '%s rig-run --session-id %s\n' "$!" "$rigSpawn" >> "$rigTmp/ps.list"
	disown "$!" 2> /dev/null || :
}
## The thread-ts and question-ts the scenario's one pending record holds, then how many records there are.
rigPair(){
	local pairFile pairCount=0 pairOut="no-record"
	for pairFile in "$rigWs/.local/agents/pending"/*.md ; do
		[ -f "$pairFile" ] || continue
		pairCount=$(( pairCount + 1 ))
		pairOut="$( LC_ALL=C awk '$0 == "---" { if ( ++dashes == 2 ) { exit ; } next ; } index( $0, "thread-ts: " ) == 1 { threadTs = substr( $0, 12 ) ; } index( $0, "question-ts: " ) == 1 { questionTs = substr( $0, 14 ) ; } END { print threadTs ":" questionTs ; }' "$pairFile" )"
	done
	printf '%s:%s' "$pairOut" "$pairCount"
}

for rigModeNow in thread plain ; do
	echo "-- 1. the prompt of an undo, send mode $rigModeNow --"
	rigStart undo "$rigModeNow"
	mkdir -p "$rigWs/.local/agents/spawned/rigrun/input" "$rigWs/.local/agents/spawned/rigrun/output"
	printf -- '---\nsession-id: rigrun\nspawn-id: rigrun\nhost: %s\nstatus: spawn-succeeded\n---\n' "$rigHost" > "$rigWs/.local/agents/spawned/rigrun/rigrun.spawn.md"
	touch -t 202001010000 "$rigWs/.local/agents/spawned/rigrun/rigrun.spawn.md"
	printf 'one\n' > "$rigDir/base.txt" ; printf 'two\n' > "$rigDir/result.txt" ; printf 'two\n' > "$rigWs/.local/agents/spawned/rigrun/output/live.txt"
	rigAs "$rigDir/undo" keeper-myx rigrun --undo-record file-write "$rigWs/.local/agents/spawned/rigrun/output/live.txt" --base "$rigDir/base.txt" --result "$rigDir/result.txt" --session-id rigrun
	rigAssert "the undo prompt is recorded with the thread its post went to ($rigModeNow)" "$( rigPair )" "$rigWant:1"
done
for rigModeNow in thread plain ; do
	echo "-- 2. the prompt of a change held for approval, send mode $rigModeNow --"
	rigStart change "$rigModeNow"
	mkdir -p "$rigWs/held"
	printf 'keeper-myx:ws:directory:approve:Edit(/%s/held/**)\n' "$rigWs" > "$rigWs/.local/agents/permissions.registry"
	printf 'alpha\nbeta\ngamma\n' > "$rigWs/held/notes.md"
	rigWork ""
	rigTool "$rigDir/edit" Edit '{"file_path":"'"$rigWs"'/held/notes.md","old_string":"beta","new_string":"BETA","description":"Raise the second word"}'
	rigAssert "the change prompt is recorded with the thread its post went to ($rigModeNow)" "$( rigPair )" "$rigWant:1"
done
for rigModeNow in thread plain ; do
	echo "-- 3. the review prompt of a handback, send mode $rigModeNow --"
	rigStart review "$rigModeNow"
	rigWork human-owner
	rigTool "$rigDir/tool" SubagentHandback '{"outcome":"rig work done"}'
	rigAssert "the review prompt is recorded with the thread its post went to ($rigModeNow)" "$( rigPair )" "$rigWant:1"
done
for rigModeNow in thread plain ; do
	echo "-- 4 and 5. a member's permission set, then a call added to it, send mode $rigModeNow --"
	rigStart permission "$rigModeNow"
	mkdir -p "$rigWs/.local/agents/spawned/rig-set" "$rigWs/.local/agents/sessions/rig-set"
	: > "$rigWs/.local/agents/permissions.registry"
	rigAs "$rigDir/refusal-one" magic-tester rig-set --intern-op-permission-refusal-log magic-tester --session-id rig-set --tool Write --target "$rigWs/SETA/one.txt" --reason rig
	rigRefusalOne="$( LC_ALL=C sed -n 's/^\(refusal-[0-9a-f-]*\)$/\1/p' "$rigDir/refusal-one" | head -1 )"
	rigAs "$rigDir/refusal-two" magic-tester rig-set --intern-op-permission-refusal-log magic-tester --session-id rig-set --tool Write --target "$rigWs/SETB/two.txt" --reason rig
	rigRefusalTwo="$( LC_ALL=C sed -n 's/^\(refusal-[0-9a-f-]*\)$/\1/p' "$rigDir/refusal-two" | head -1 )"
	rigAs "$rigDir/set" magic-tester rig-set --intern-op-permission-set-ask magic-tester --session-id rig-set --refusal-id "$rigRefusalOne" --task-ref "the rig" --reason rig --entry "Write:$rigWs/SETA/**"
	rigAssert "the permission set is recorded with the thread its post went to ($rigModeNow)" "$( rigPair )" "$rigWant:1"
	: > "$rigDir/replies.fixed"
	rigAs "$rigDir/add" magic-tester rig-set --intern-op-escalation-permission-add magic-tester --session-id rig-set --refusal-id "$rigRefusalTwo" --reason rig
	rigAssert "the call added to it is told as that thread and message ($rigModeNow)" \
		"$( LC_ALL=C sed -n 's/^SENT_MESSAGE_THREAD_TS=//p' "$rigDir/add" ):$( LC_ALL=C sed -n 's/^SENT_MESSAGE_TS=//p' "$rigDir/add" )" "$rigWant"
done

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ASK RECORDS REAL THREAD CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ASK_RECORDS_REAL_THREAD: OK (%d assertions, offline)\n' "$rigPassCount"
