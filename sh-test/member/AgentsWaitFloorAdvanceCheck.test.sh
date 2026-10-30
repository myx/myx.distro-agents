#!/usr/bin/env bash
## Behavioural check on DOUBLE DELIVERY (team-wide bug, reported 2026-10-28): the same Slack message in a session's own
## thread reaching a member twice -- once through the floor (AgentsToolsSessionChatFloor, a tool return's own local-cache
## read, F3.3) and once more through a LATER, separate Wait's own live slack:<channel>:<ts>:conversation probe
## (AgentsWaitProbeSlack). The floor's delivery moves only the session chat file's own per-member pointer
## (AgentsToolsSessionChatPointer); a stored wait keeps a FLOOR OF ITS OWN for that same source in the session's
## wait/state (AgentsWaitStateStore), on a different unit (a block number in the chat file's index, not a Slack ts) and
## never advanced by the floor's delivery -- so the next Wait, probing from its own older stored floor, re-shows what
## the floor already gave.
## A stored wait's own `floor <source> <value>` line is read verbatim into probeSince (AgentsTools.MemberWait.include,
## the --wait-continue/--wait-default floor-init block, `waitFloorOf[floorIndex]="$floorStored"`) and handed to
## AgentsWaitProbeSlack as its third argument, which is exactly what this check calls directly: the real function Wait
## itself calls, skipping only the outer --wait-for-input CLI dispatch (its own front-table routing is mid-migration to
## DistroAgentsSession.fn.sh in this tree as of 2026-10-28 and misparses a bare <team-member> positional -- a separate,
## already-owned defect, not this one; AgentsWaitProbeSlack itself is unaffected by it).
## Held, run and not read:
##   1. THE BUG, REPRODUCED on the unfixed code: with the stored floor at its pre-arrival value (as a real wait last
##      left it), the floor (a tool return) shows a newly-imported message once; Wait's own live probe, reading that
##      same still-stale stored floor, shows it again.
##   2. THE FIX: the floor advances that stored source's own floor to the ts it just delivered, so the live probe,
##      reading the now-advanced value, does not re-show it.
##   3. NORMAL CASE A: a message Wait's own live probe sees FIRST (before the floor ever ran) is still shown once, by
##      Wait itself -- the floor of the tool return right after is empty.
##   4. NORMAL CASE B: a floor that delivers nothing never touches wait/state at all.
##   5. THE FIX, DIRECTLY: the stored floor line itself is advanced to the delivered ts, and an unrelated source's own
##      floor line in the same file is untouched.
## Offline: a Slack-shaped fake curl is first on PATH, every workspace is a folder of the rig's own, and no model CLI
## or background process is started -- every call is a direct, synchronous call of the real function.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigFixtures="$rigTest/check-fixtures"
rigMember="rig-member"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHere/session/AgentsTools.SessionChat.include" ] || rigRefuse "the chat include is missing"
[ -f "$rigHere/member/AgentsTools.MemberWait.include" ] || rigRefuse "the wait include is missing"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWaitFloorAdvanceCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/skills/$rigMember"
printf '%s\n' "$rigMember" > "$rigTmp/skills/$rigMember/$rigMember.basic.md"
cp "$rigFixtures/wait-own-post-replies.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
rigWaitPath="$rigTmp/bin:$PATH"

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

rigNow="$( date +%s )"
rigDir="" rigSession="" rigThread=""
rigStamp(){ ## epoch -- a touch -t stamp of it, BSD or GNU date
	date -r "$1" +%Y%m%d%H%M.%S 2> /dev/null || date -d "@$1" +%Y%m%d%H%M.%S
}
rigScene(){ ## scenario name
	rigNow="$( date +%s )"
	rigDir="$rigTmp/$1"
	rigSession="rig-sess-$1"
	rm -rf "$rigDir"
	mkdir -p "$rigDir/ws/.local/agents/sessions/$rigSession/wait" "$rigDir/ws/.local/.agents"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=DRIGOWN01\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-RIG\n' > "$rigDir/ws/.local/.agents/$rigMember.agent.env"
	: > "$rigDir/api.log"
	rigThread="CRIGSES01:$(( rigNow - 400 )).000001"
	printf '%s\n' "$rigThread" > "$rigDir/ws/.local/agents/sessions/$rigSession/session.thread"
	: > "$rigDir/launch.marker"
	touch -t "$( rigStamp $(( rigNow - 300 )) )" "$rigDir/launch.marker"
}
rigMsg(){ ## ts user text [thread ts]
	printf '{"ts":"%s","user":"%s","text":"%s"%s}' "$1" "$2" "$3" "${4:+,\"thread_ts\":\"$4\"}"
}
rigJoin(){ ## messages... -- comma-joined
	local joinOut="" joinOne
	for joinOne in "$@" ; do joinOut="$joinOut${joinOut:+,}$joinOne" ; done
	printf '%s' "$joinOut"
}
rigThreadData(){ ## channel, thread ts, then its messages (root first)
	local threadChannel="$1" threadTs="$2"
	shift 2
	printf '{"ok":true,"messages":[%s],"has_more":false}\n' "$( rigJoin "$@" )" > "$rigDir/replies.$threadChannel.$threadTs.json"
}
## Every rig env, unset: a leaked MDAT_SESSION_THREAD (this very check's own real coworking session) would make the
## floor read ITS thread instead of the rig's fake one, and the rest leak the same way the house's own rigs guard for.
rigEnvClean="env -u MDAT_SESSION_THREAD -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u MDAT_CONVERSATION_THREADS -u MDAT_SPAWN_AGENT"
## The floor of a tool return, called directly as F3.3's own code calls it (AgentsTranscriptReplyFloor), outside any Wait.
rigFloor(){
	$rigEnvClean MMDAPP="$rigDir/ws" MDAT_SPAWN_LAUNCH_MARKER="$rigDir/launch.marker" bash -c \
		". '$rigHere/session/AgentsTools.SessionChat.include' ; AgentsToolsSessionChatFloor '$rigSession' '$rigMember' '' deliver"
}
## What a background reader already brought into the session's local chat file, before any floor or Wait touches it: the
## raw Slack JSON of the thread (conversations.replies' own shape) rendered (AgentsSlackMessagesFormat.awk) and imported
## (AgentsToolsSessionChatImport) with no member marked as having seen it -- the floor is the first to show it.
rigImportThread(){
	local importRender
	importRender="$( mktemp "$rigDir/import.XXXXXX" )"
	LC_ALL=C awk -f "$rigHere/comms/AgentsSlackMessagesFormat.awk" < "$rigDir/replies.CRIGSES01.$(( rigNow - 400 )).000001.json" > "$importRender" 2> /dev/null
	$rigEnvClean MMDAPP="$rigDir/ws" MDAT_SPAWN_LAUNCH_MARKER="$rigDir/launch.marker" bash -c \
		". '$rigHere/session/AgentsTools.SessionChat.include' ; AgentsToolsSessionChatImport '$rigSession' '$rigThread' '$importRender' slack -"
	rm -f "$importRender"
}
## AgentsWaitProbeSlack itself, called the same way a live Wait round calls it for a slack:<channel>:<ts>:conversation
## source (AgentsTools.MemberWait.include's own probe-round), with the floor (probeSince) the caller gives it. Prints
## what it wrote as new, empty for none.
rigProbeNew(){ ## probeSince
	local probeFile probeLog
	probeFile="$( mktemp "$rigDir/probe.XXXXXX" )"
	probeLog="$probeFile.log"
	rm -f "$probeFile"
	$rigEnvClean MMDAPP="$rigDir/ws" MDAT_SPAWN_LAUNCH_MARKER="$rigDir/launch.marker" MDAT_SESSION_ID="$rigSession" MDAT_SKILLSET_ROOT="$rigTmp/skills" PATH="$rigWaitPath" RIG_SCENARIO="$rigDir" MDAT_SLACK_THREAD_CACHE_SECONDS=0 \
		bash -c ". '$rigHere/member/AgentsTools.MemberWait.include' ; AgentsWaitProbeSlack '$rigMember' '${rigThread}:conversation' '$1' '$probeFile' '' false" > "$probeLog" 2>&1
	[ -f "$probeFile" ] && cat "$probeFile"
	rm -f "$probeFile" "$probeFile.rendered" "$probeFile.err" "$probeLog"
}
## A stored wait's own wait/state file, hand-written to the documented format (AgentsWaitStateStore, verified by
## reading it): this is what a real --wait-for-input call leaves behind, and the only part this fix reads or writes.
rigStateWrite(){ ## sources line, then floor lines as "<source> <value>" pairs...
	local stateFile="$rigDir/ws/.local/agents/sessions/$rigSession/wait/state" stateSources="$1" statePair
	shift
	{
		printf 'sources: %s\n' "$stateSources"
		printf 'addressee: \n'
		printf 'include-own: false\n'
		for statePair in "$@" ; do
			printf 'floor %s\n' "$statePair"
		done
	} > "$stateFile"
}
rigStateFile(){
	cat "$rigDir/ws/.local/agents/sessions/$rigSession/wait/state" 2> /dev/null
}
rigFloorState(){ ## source
	LC_ALL=C awk -v want="$1" '$1 == "floor" && $2 == want { print $3 ; exit ; }' "$rigDir/ws/.local/agents/sessions/$rigSession/wait/state" 2> /dev/null
}

echo "-- 1. the bug, reproduced: the floor shows it, then Wait's own probe -- reading the still-stale stored floor -- shows it again --"
rigScene double
rigThreadT0=$(( rigNow - 300 ))
rigStateWrite "slack:${rigThread}:conversation" "slack:${rigThread}:conversation $rigThreadT0"
## establishes rig-member's own chat-file pointer (its first contact) before the new message exists: what is already
## there at a member's first contact is not new to it (AgentsToolsSessionChatReaderInit), so a message imported before
## the member's pointer ever existed would be swallowed into that baseline instead of testing the bug.
rigThreadData CRIGSES01 "$(( rigNow - 400 )).000001" \
	"$( rigMsg "$(( rigNow - 400 )).000001" URIGHUM1 RIG-ROOT-BEFORE-LAUNCH )"
rigImportThread ; rigFloor > /dev/null
rigThreadData CRIGSES01 "$(( rigNow - 400 )).000001" \
	"$( rigMsg "$(( rigNow - 400 )).000001" URIGHUM1 RIG-ROOT-BEFORE-LAUNCH )" \
	"$( rigMsg "$(( rigNow - 100 )).000001" URIGHUM1 RIG-NEW-ONE "$(( rigNow - 400 )).000001" )"
rigImportThread
rigFloorOut="$( rigFloor )"
rigAssert "the floor (a tool return) shows the new message the first time" "$( rigTextHas "$rigFloorOut" RIG-NEW-ONE )" yes
rigProbeOut="$( rigProbeNew "$( rigFloorState "slack:${rigThread}:conversation" )" )"
rigAssert "THE FIX: Wait's own live probe, right after, must NOT show the same message again" "$( rigTextHas "$rigProbeOut" RIG-NEW-ONE )" no

echo "-- 2. normal case A: a message Wait's own live probe sees first is still shown once --"
rigScene first
rigThreadData CRIGSES01 "$(( rigNow - 400 )).000001" \
	"$( rigMsg "$(( rigNow - 400 )).000001" URIGHUM1 RIG-ROOT-BEFORE-LAUNCH )" \
	"$( rigMsg "$(( rigNow - 100 )).000001" URIGHUM1 RIG-FIRST-BY-WAIT "$(( rigNow - 400 )).000001" )"
rigProbeOut="$( rigProbeNew $(( rigNow - 300 )) )"
rigAssert "Wait's own live probe sees the message first" "$( rigTextHas "$rigProbeOut" RIG-FIRST-BY-WAIT )" yes
rigFloorOut="$( rigFloor )"
rigAssert "the floor of a tool return right after: empty, it is already delivered" "${#rigFloorOut}" 0

echo "-- 3. normal case B: a floor with nothing new never touches wait/state --"
rigScene quiet
rigStateWrite "slack:${rigThread}:conversation" "slack:${rigThread}:conversation $(( rigNow - 300 ))"
rigThreadData CRIGSES01 "$(( rigNow - 400 )).000001" \
	"$( rigMsg "$(( rigNow - 400 )).000001" URIGHUM1 RIG-ROOT-BEFORE-LAUNCH )"
rigImportThread
rigStateBefore="$( rigStateFile )"
rigFloorOut="$( rigFloor )"
rigAssert "a floor with nothing to deliver (only history, before launch): empty" "${#rigFloorOut}" 0
rigAssert "and wait/state is byte-for-byte untouched" "$( rigStateFile )" "$rigStateBefore"

echo "-- 4. the fix, directly: the stored floor line is advanced, and an unrelated source's own line stands --"
rigScene unrelated
rigUnrelatedFloor=$(( rigNow - 150 ))
rigStateWrite "slack:${rigThread}:conversation slack:CRIGXXX01" "slack:${rigThread}:conversation $(( rigNow - 300 ))" "slack:CRIGXXX01 $rigUnrelatedFloor"
rigThreadData CRIGSES01 "$(( rigNow - 400 )).000001" \
	"$( rigMsg "$(( rigNow - 400 )).000001" URIGHUM1 RIG-ROOT-BEFORE-LAUNCH )"
rigImportThread ; rigFloor > /dev/null
rigThreadData CRIGSES01 "$(( rigNow - 400 )).000001" \
	"$( rigMsg "$(( rigNow - 400 )).000001" URIGHUM1 RIG-ROOT-BEFORE-LAUNCH )" \
	"$( rigMsg "$(( rigNow - 100 )).000001" URIGHUM1 RIG-NEW-TWO "$(( rigNow - 400 )).000001" )"
rigImportThread
rigFloorOut="$( rigFloor )"
rigAssert "the floor shows the new message" "$( rigTextHas "$rigFloorOut" RIG-NEW-TWO )" yes
rigAssert "the stored floor for the thread's own source is advanced to the delivered ts" "$( rigFloorState "slack:${rigThread}:conversation" )" "$(( rigNow - 100 )).000001"
rigAssert "the unrelated source's own floor line is untouched" "$( rigFloorState slack:CRIGXXX01 )" "$rigUnrelatedFloor"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WAIT FLOOR ADVANCE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_FLOOR_ADVANCE: OK (%d assertions, offline)\n' "$rigPassCount"
