#!/usr/bin/env bash
## Behavioural check on a message one session sends into the thread of another (S12.15): the receiving session's chat file is
## its primary channel, and the Slack thread the copy. Held, through the real SendMessage and the real Wait of the harness, over a
## Slack-shaped fake curl whose thread reads fail unless a scenario holds the thread, as a run that cannot read its DM thread:
##   1. THE SEND RECORDS IT WHERE THE SESSION READS FIRST. A DISMISSED sent to another session's thread, addressed to its member,
##      is a block of that session's chat file, origin `delivered`, on that session's thread, with the ts Slack gave the post.
##      The sender's own record is as it was: one block, in its own session.
##   2. THE RUN'S WAIT RETURNS DISMISSED, from that file alone, while its read of the thread from Slack fails.
##   3. A DISMISSAL IS NOT HELD BEHIND THE CHECKLIST. A run that has handed back and holds an open item gets the dismissal from
##      a plain Wait; the control, the same run with no dismissal waiting, still gets its open items.
##   4. ONE RUN OF A MEMBER DISMISSING ANOTHER OF THE SAME MEMBER: the copy names both runs (S27.8), the floor gives it to that
##      member's run, and the dismissal reaches that run and no other (S6.40).
##   5. ANOTHER WORKSPACE OF THE MACHINE: a session of a workspace the machine's directories registry names gets the copy too.
##   6. THE CONTROLS. A thread no session keeps gets no copy anywhere. Where the session can read its thread from Slack as well,
##      the message is delivered once.
## Red on the tree of 2026-11-06 08:10Z: the send records the message in the sender's session only, so 1, 2, 4 and 5 fail, and 3
## fails with the open items returned in place of the dismissal.
## Offline: a Slack-shaped fake curl is first on PATH, every workspace and HOME are folders of the rig's own, no model CLI is started.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigFixtures="$rigPackage/sh-test/check-fixtures"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "the harness is not at the origin this workspace resolves: $rigHarness"
[ -f "$rigHere/session/AgentsTools.SessionChat.include" ] || rigRefuse "the chat include is not at the origin this workspace resolves"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDismissOtherSessionCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp" 2> /dev/null' EXIT
rigBin="$rigTmp/bin" rigWs="$rigTmp/ws" rigFar="$rigTmp/ws-far" rigHome="$rigTmp/home" rigScn="$rigTmp/scn" rigSkills="$rigTmp/skills"
rigLead="rig-lead" rigHelper="rig-helper" rigChannel="CRIGSES01"
mkdir -p "$rigBin" "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigFar/.local/agents/sessions" "$rigHome/.agents/magic-team" "$rigScn" \
	"$rigSkills/$rigLead" "$rigSkills/$rigHelper"
for rigName in "$rigLead" "$rigHelper" ; do printf '%s\n' "$rigName" > "$rigSkills/$rigName/$rigName.basic.md" ; done
printf 'SLACK_CHANNEL_MAGIC_TEAM=%s\nSLACK_CHANNEL_HUMAN_OWNER=DRIGOWN01\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' "$rigChannel" > "$rigWs/.local/.agents/magic-team.agent.env"
## The machine's registry of places, the rig's own: one other workspace.
printf 'rig-far\t%s\n' "$rigFar" > "$rigHome/.agents/magic-team/directories.registry"
cp "$rigFixtures/session-comms.curl.stub.sh" "$rigBin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigBin/curl"
for rigModel in claude codex ; do
	printf '#!/bin/sh\necho "%s $*" >> "%s/model-calls"\nexit 1\n' "$rigModel" "$rigTmp" > "$rigBin/$rigModel"
	chmod +x "$rigBin/$rigModel"
done
[ "$( PATH="$rigBin:$PATH" command -v curl )" = "$rigBin/curl" ] || rigRefuse "the fake curl is not first on its PATH"
rigPath="$rigBin:$PATH"
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
		printf '  PASS  %s\n' "$1"
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigNow="$( date +%s )"
## A session of a workspace: its folder and its thread.
rigSession(){ ## workspace, session, thread ts
	mkdir -p "$1/.local/agents/sessions/$2"
	printf '%s:%s\n' "$rigChannel" "$3" > "$1/.local/agents/sessions/$2/session.thread"
}
## A run of a member that has been reading its session: its pointer at the start of the file.
rigReading(){ ## workspace, session, member
	( cd "$1" && env -u MDAT_SESSION_THREAD -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_ID "MMDAPP=$1" "MDLT_ORIGIN=$MDLT_ORIGIN" \
		bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionChat.include" || exit 9 ; AgentsToolsSessionChatPointerSet "$1" "read:$2" 0' _ "$2" "$3" ) 2> /dev/null || :
}
## One served call of a harness tool, as a run of a member in a session of the rig's main workspace.
rigTool(){ ## output basename, tool, member, run id, session, thread ts, arguments json
	printf '%s' "$7" | ( cd "$rigWs" && env -u MDAT_SESSION_THREAD -u MDAT_CONVERSATION_THREADS -u MDAT_SESSION_ID -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT \
		"HOME=$rigHome" "PATH=$rigPath" "RIG_SCENARIO=$rigScn" "MMDAPP=$rigWs" "MDLT_ORIGIN=$MDLT_ORIGIN" "MDAT_SKILLSET_ROOT=$rigSkills" "MDAT_DATA_ROOT=$rigTmp/data" \
		MDAT_SPAWN_SESSION_ID="$4" MDAT_SPAWN_AGENT="$3" MDAT_SESSION_ID="$5" MDAT_SESSION_THREAD="$rigChannel:$6" \
		MDAT_WAIT_REMIND=off MDAT_COMMS_READER=off MDAT_SLACK_THREAD_CACHE_SECONDS=0 MDAT_HARNESS_WAIT_TIMEOUT=8 \
		bash "$rigHarness" --intern-tool "$2" ) > "$rigTmp/$1.out" 2> "$rigTmp/$1.err"
}
rigSend(){ ## output basename, thread ts, addressee, message -- rig-lead's run in its own session sends into that thread
	rigTool "$1" SendMessage "$rigLead" rig-root-run rig-root-sess "$rigRootTs" "{\"to\":\"$rigChannel:$2\",\"address_to\":\"$3\",\"message\":\"$4\"}"
}
rigFirstLine(){ ## output basename
	LC_ALL=C awk 'NR == 1 { print ; exit ; }' "$rigTmp/$1.out" 2> /dev/null
}
## The blocks of a chat file from <from> to <to> whose body is <body>: their count.
rigBlocks(){ ## chat file, from, to, body
	LC_ALL=C awk -v want=" $2 -> $3:" -v body="$4" '
		/^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9:]*Z .* -> .*:$/ { head = ( substr( $0, 21 ) == want ) ; next ; }
		head && $0 == body { count++ ; } { head = 0 ; }
		END { print count + 0 ; }' "$1" 2> /dev/null || printf 0
}
## The index line of a chat file's block <n>: ts, conversation, origin.
rigIndex(){ ## index file, block number
	LC_ALL=C awk -F'\t' -v want="$2" '$1 == want { print $2 " " $3 " " $4 ; exit ; }' "$1" 2> /dev/null
}
rigPosts(){
	cat "$rigScn/posts" 2> /dev/null || printf 0
}

rigRootTs="$(( rigNow - 900 )).000100"
rigDutyTs="$(( rigNow - 800 )).000200"
rigListTs="$(( rigNow - 700 )).000300"
rigLeadTs="$(( rigNow - 600 )).000400"
rigFarTs="$(( rigNow - 500 )).000500"
rigOnceTs="$(( rigNow - 400 )).000600"
rigSession "$rigWs" rig-root-sess "$rigRootTs"
rigSession "$rigWs" rig-duty-sess "$rigDutyTs"
rigSession "$rigWs" rig-list-sess "$rigListTs"
rigSession "$rigWs" rig-lead-sess "$rigLeadTs"
rigSession "$rigFar" rig-far-sess "$rigFarTs"
rigSession "$rigWs" rig-once-sess "$rigOnceTs"
rigDuty="$rigWs/.local/agents/sessions/rig-duty-sess"

echo "-- 1. the send records the message where the receiving session reads first --"
rigReading "$rigWs" rig-duty-sess "$rigHelper"
rigSend send-duty "$rigDutyTs" "$rigHelper" DISMISSED
rigAssert "the send posts once" "$( rigPosts )" "1"
rigAssert "the receiving session's chat file holds the DISMISSED, from the sender to its member" "$( rigBlocks "$rigDuty/session.chat" "$rigLead" "$rigHelper" DISMISSED )" "1"
rigAssert "as a delivered block on that session's thread, with the ts Slack gave the post" "$( rigIndex "$rigDuty/session.chat.index" 1 )" "1760000000.000101 $rigChannel:$rigDutyTs delivered"
rigAssert "the sender's own record is as it was: one block, in its own session" \
	"$( LC_ALL=C wc -l < "$rigWs/.local/agents/sessions/rig-root-sess/session.chat.index" 2> /dev/null | LC_ALL=C tr -d ' ' ):$( rigIndex "$rigWs/.local/agents/sessions/rig-root-sess/session.chat.index" 1 | LC_ALL=C awk '{ print $3 }' )" "1:own"

echo "-- 2. the run's Wait returns DISMISSED from that file, while its read of the thread from Slack fails --"
rigTool wait-duty Wait "$rigHelper" rig-duty-run rig-duty-sess "$rigDutyTs" "{\"timeout\":\"6\",\"poll_interval\":\"1\",\"mode\":\"default\",\"sources\":\"slack:$rigChannel:$rigDutyTs:conversation\"}"
rigAssert "the Wait returns DISMISSED" "$( rigFirstLine wait-duty )" "WAIT-RESULT: DISMISSED"
rigAssert "naming the sender" "$( LC_ALL=C grep -c "^WAIT-DISMISSED-BY: .*$rigLead" "$rigTmp/wait-duty.out" )" "1"
## The fake Slack answers a thread it holds no file for with thread_not_found, so no read of it from Slack can carry the message.
rigAssert "control: Slack holds that thread for no reader, so the file alone carried it" "$( [ -f "$rigScn/replies.$rigChannel.$rigDutyTs.json" ] && printf held || printf none )" "none"

echo "-- 3. a dismissal is not held behind the CheckList --"
rigList="$rigWs/.local/agents/sessions/rig-list-sess"
printf -- '- [ ] Run the suite\n' > "$rigList/$rigHelper.checklist.md"
printf '1\n' > "$rigList/handback.given"
rigReading "$rigWs" rig-list-sess "$rigHelper"
rigTool idle-control Wait "$rigHelper" rig-list-run rig-list-sess "$rigListTs" '{"timeout":"3"}'
rigAssert "control: with no dismissal waiting, a plain Wait gives the open items" "$( rigFirstLine idle-control | LC_ALL=C cut -c1-21 )" "CHECKLIST: 1 pending."
rigSend send-list "$rigListTs" "$rigHelper" DISMISSED
rigTool idle-dismissed Wait "$rigHelper" rig-list-run rig-list-sess "$rigListTs" '{"timeout":"6"}'
rigAssert "with one waiting, the plain Wait returns DISMISSED" "$( rigFirstLine idle-dismissed )" "WAIT-RESULT: DISMISSED"

echo "-- 4. one run of a member dismissing another of the same member --"
mkdir -p "$rigWs/.local/agents/spawned/rig-lead-sess"
printf -- '---\nsession-id: rig-lead-sess\nspawn-id: rig-lead-run\nowner: %s\nstatus: spawn-started\n---\n' "$rigLead" > "$rigWs/.local/agents/spawned/rig-lead-sess/rig-lead-run.spawn.md"
rigSend send-self "$rigLeadTs" "$rigLead" DISMISSED
rigLeadChat="$rigWs/.local/agents/sessions/rig-lead-sess/session.chat"
rigAssert "the copy names both runs" "$( rigBlocks "$rigLeadChat" "$rigLead [author-run=rig-root-run]" "$rigLead [addressee-run=rig-lead-run]" DISMISSED )" "1"
rigAssert "the floor of that member's run there gives it" \
	"$( ( cd "$rigWs" && env -u MDAT_SESSION_THREAD -u MDAT_SESSION_ID "MMDAPP=$rigWs" "MDLT_ORIGIN=$MDLT_ORIGIN" MDAT_SPAWN_SESSION_ID=rig-lead-run \
		bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionChat.include" || exit 9 ; AgentsToolsSessionChatPointerSet "$1" "read:$2" 0 ; AgentsToolsSessionChatFloor "$1" "$2"' _ rig-lead-sess "$rigLead" ) 2> /dev/null | LC_ALL=C grep -c -x DISMISSED )" "1"
rigAssert "the dismissal reaches that run" "$( dismissalMember="$rigLead" dismissalRun=rig-lead-run LC_ALL=C awk -f "$rigHere/questions/AgentsDismissalMatch.awk" -f "$rigHere/harness/AgentsHarnessWaitDismissed.awk" "$rigLeadChat" > /dev/null 2>&1 && printf yes || printf no )" "yes"
rigAssert "and no other run of the member" "$( dismissalMember="$rigLead" dismissalRun=rig-root-run LC_ALL=C awk -f "$rigHere/questions/AgentsDismissalMatch.awk" -f "$rigHere/harness/AgentsHarnessWaitDismissed.awk" "$rigLeadChat" > /dev/null 2>&1 && printf yes || printf no )" "no"

echo "-- 5. a session of another workspace of the machine --"
rigSend send-far "$rigFarTs" "$rigHelper" DISMISSED
rigAssert "its chat file holds the copy" "$( rigBlocks "$rigFar/.local/agents/sessions/rig-far-sess/session.chat" "$rigLead" "$rigHelper" DISMISSED )" "1"
rigAssert "on its own thread, origin delivered" "$( rigIndex "$rigFar/.local/agents/sessions/rig-far-sess/session.chat.index" 1 | LC_ALL=C awk '{ print $2 " " $3 }' )" "$rigChannel:$rigFarTs delivered"

echo "-- 6. the controls --"
rigDeliveredBefore="$( cat "$rigWs"/.local/agents/sessions/*/session.chat.index "$rigFar"/.local/agents/sessions/*/session.chat.index 2> /dev/null | LC_ALL=C awk -F'\t' '$4 == "delivered"' | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )"
rigSend send-nowhere "1700000009.000909" "$rigHelper" RIG-NOWHERE-BODY
rigAssert "a thread no session keeps gets no copy anywhere" \
	"$( cat "$rigWs"/.local/agents/sessions/*/session.chat.index "$rigFar"/.local/agents/sessions/*/session.chat.index 2> /dev/null | LC_ALL=C awk -F'\t' '$4 == "delivered"' | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "$rigDeliveredBefore"
rigReading "$rigWs" rig-once-sess "$rigHelper"
rigSend send-once "$rigOnceTs" "$rigHelper" RIG-ONCE-BODY
rigOncePost="$( rigPosts )"
## The thread as Slack answers it: its root, and the post as Slack keeps it, at the ts it gave.
printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGBOT01","text":"RIG-ROOT"},%s],"has_more":false}\n' "$rigOnceTs" \
	"$( LC_ALL=C sed -e "s/^{\"channel\":\"[A-Z0-9]*\",/{\"ts\":\"1760000000.00010$rigOncePost\",\"user\":\"URIGBOT01\",/" "$rigScn/post.$rigOncePost" )" > "$rigScn/replies.$rigChannel.$rigOnceTs.json"
rigTool wait-once Wait "$rigHelper" rig-once-run rig-once-sess "$rigOnceTs" "{\"timeout\":\"6\",\"poll_interval\":\"1\",\"mode\":\"default\",\"sources\":\"slack:$rigChannel:$rigOnceTs:conversation\",\"since_utime\":\"1700000000\"}"
rigAssert "where the session reads its thread from Slack too, the message is delivered once" "$( rigFirstLine wait-once ):$( LC_ALL=C grep -c -x 'RIG-ONCE-BODY' "$rigTmp/wait-once.out" )" "WAIT-RESULT: RECEIVED:1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ DISMISS OTHER SESSION CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'DISMISS_OTHER_SESSION: OK (%d assertions, offline)\n' "$rigPassCount"
