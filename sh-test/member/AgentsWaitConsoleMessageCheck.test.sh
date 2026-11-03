#!/usr/bin/env bash
## Behavioural check on a message a person leaves for a session from the console (F11.6, F9.1, F9.3): the console's `M` sends it with
## --manager-session-message, the writer takes it into the session thread, and the run it is addressed to acts on it. Held, through the
## real send, the real writer pass and the real Wait, over a Slack-shaped fake curl:
##   1. THE POST IS A PERSON'S. It reaches chat.postMessage with a metadata object naming the person at the console and carrying no
##      `tracking` key. A reader leaves out what the tooling posted itself by reading that key, never a post's words
##      (AgentsTrackingDrop.awk), so a person's message carrying it is dropped by every reader it is not addressed to.
##   2. THE CHAT FLOOR LEAVES THE THREAD TO THE SOURCE THAT READS IT. Read with the session's thread covered, the floor of the same
##      session delivers nothing of that thread; read with nothing covered it delivers the console's block. That is the floor's own
##      rule, held here so a red in section 3 is not read as a block the floor lost.
##   3. THE WAIT RETURNS IT, ONCE, IN THE SHAPE THAT FAILED. A wait holding `chat:<session>` and the session's thread as
##      `slack:<channel>:<ts>:conversation` together -- the shape a Wait of session c0802dfe held -- returns the console's body once,
##      and names that thread source as where it arrived.
##   4. THE HARNESS TOOL RETURNS IT TOO. The body reaches the result of the `Wait` tool through the real harness. The thread source is
##      named for this one call: the tool's own default set is built from the harness's session identity, which AgentsRunTests.sh
##      strips from every test it runs, so a default wait inside a rig reads no session at all and would be a test of that stripping.
##   5. THE CONTROLS. A member's own post in the same thread is returned by the same wait, and a `tracking: tooling` post it is not
##      addressed to is not. Both directions of the drop are shown to differ, so it can tell a kept post from a dropped one.
## Red on the tree of 2026-11-03 02:15Z: the console's post carries `"tracking":"tooling"`, so section 1 fails on the key and sections
## 3 and 4 fail with WAIT-RESULT: TIMEOUT and no body in the result. Green: the console's send passes the sender alone, and those runs
## return the body once.
## Offline: a Slack-shaped fake curl is first on PATH, every workspace is a folder of the rig's own, and no model CLI is started.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigFixtures="$rigPackage/sh-test/check-fixtures"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigHarness" ] || rigRefuse "the harness is not at the origin this workspace resolves: $rigHarness"
[ -f "$rigHere/session/AgentsTools.SessionChat.include" ] || rigRefuse "the chat include is not at the origin this workspace resolves"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWaitConsoleMessageCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp" 2> /dev/null' EXIT
rigBin="$rigTmp/bin" rigWs="$rigTmp/ws" rigScn="$rigTmp/scn" rigSkills="$rigTmp/skills"
rigSess="rig-console-sess" rigMember="keeper-rig" rigChannel="CRIGSES01"
rigSessDir="$rigWs/.local/agents/sessions/$rigSess"
mkdir -p "$rigBin" "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigScn" "$rigSkills/$rigMember" \
	"$rigSessDir" "$rigWs/.local/agents/spawned/$rigSess"
printf '%s\n' "$rigMember" > "$rigSkills/$rigMember/$rigMember.basic.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=%s\nSLACK_CHANNEL_HUMAN_OWNER=DRIGOWN01\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' "$rigChannel" > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-MEM\n' > "$rigWs/.local/.agents/$rigMember.agent.env"
cp "$rigFixtures/session-comms.curl.stub.sh" "$rigBin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigBin/curl"
rigIdReal="$( command -v id 2> /dev/null )" || rigRefuse "no id on PATH to stand behind the rig's console account"
printf '#!/bin/sh\ncase "$*" in\n\t-un) echo Rig.Acct_7 ;;\n\t*) exec "%s" "$@" ;;\nesac\n' "$rigIdReal" > "$rigBin/id" || rigRefuse "cannot write the rig's own id"
chmod +x "$rigBin/id"
[ "$( PATH="$rigBin:$PATH" command -v curl )" = "$rigBin/curl" ] || rigRefuse "the fake curl is not first on its PATH"
[ "$( PATH="$rigBin:$PATH" id -un )" = "Rig.Acct_7" ] || rigRefuse "the rig's id stub is not first on its PATH"
rigPath="$rigBin:$PATH"
rigRoot="" rigConsoleTs="" rigRc=0
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
rigStamp(){ ## epoch -- a touch -t stamp of it, BSD or GNU date
	date -r "$1" +%Y%m%d%H%M.%S 2> /dev/null || date -d "@$1" +%Y%m%d%H%M.%S
}
rigThread(){ ## message json... -- the thread the rig's Slack answers for this session, its root first
	printf '{"ok":true,"messages":[%s],"has_more":false}\n' "$( printf '%s,' "$@" | LC_ALL=C sed 's/,$//' )" > "$rigScn/replies.$rigChannel.$rigRoot.json"
}
rigPostLine(){ ## ts, text, metadata -- one message of that thread, as the formatter reads one
	printf '{"ts":"%s","user":"URIGBOT01","text":"%s","thread_ts":"%s"%s}' "$1" "$2" "$rigRoot" "${3:+,$3}"
}
rigSent(){ ## n, ts -- the nth post's payload as Slack's own message object: its channel replaced by its ts and its sender, nothing else touched
	LC_ALL=C sed -e "s/^{\"channel\":\"[A-Z0-9]*\",/{\"ts\":\"$2\",\"user\":\"URIGBOT01\",/" "$rigScn/post.$1"
}
## The scene: this session's folder, its spawn record and its thread, the launch marker its floor reads, and a quiet Slack elsewhere.
rigNow="$( date +%s )"
rigRoot="$(( rigNow - 600 )).000001"
rigConsoleTs="$(( rigNow - 120 )).000002"
printf '%s:%s\n' "$rigChannel" "$rigRoot" > "$rigSessDir/session.thread"
printf '%s:%s\n' "$rigChannel" "$rigRoot" > "$rigWs/.local/agents/spawned/$rigSess/session.thread"
: > "$rigSessDir/launch"
touch -t "$( rigStamp $(( rigNow - 900 )) )" "$rigSessDir/launch"
printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: rig\nworkspace: rigws\nowner: %s\nstatus: spawn-succeeded\nstarted-at: 2026-11-02 20:37 +0300\n---\n\n# Spawn session: %s\n' \
	"$rigSess" "$rigSess" "$rigMember" "$rigSess" > "$rigWs/.local/agents/spawned/$rigSess/$rigSess.spawn.md"
printf '{"ok":true,"messages":[],"has_more":false}\n' > "$rigScn/history.$rigChannel.json"
printf '{"ok":true,"messages":[],"has_more":false}\n' > "$rigScn/history.DRIGOWN01.json"
rigThread "$( rigPostLine "$rigRoot" RIG-ROOT )"
rigOp(){ ## output basename, then the operation's arguments -- one call of the tooling in the rig workspace
	local opName="$1"
	shift
	rigRc=0
	( cd "$rigWs" && env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_THREAD -u MDAT_CONVERSATION_THREADS -u MDAT_SESSION_ID -u MDAT_SEND_FLOOR \
		"PATH=$rigPath" "RIG_SCENARIO=$rigScn" "MMDAPP=$rigWs" "MDLT_ORIGIN=$MDLT_ORIGIN" "MDAT_SKILLSET_ROOT=$rigSkills" MDAT_COMMS_READER=off MDAT_WAIT_REMIND=off \
		bash "$rigTool" "$@" ) > "$rigTmp/$opName.out" 2> "$rigTmp/$opName.err" || rigRc=$?
}
rigHolds(){ ## output basename, text
	case "$( cat "$rigTmp/$1.out" 2> /dev/null )" in *"$2"*) printf yes ;; *) printf no ;; esac
}
rigFirstLine(){ ## output basename
	LC_ALL=C awk 'NR == 1 { print ; exit ; }' "$rigTmp/$1.out" 2> /dev/null
}
rigFresh(){ ## the member's pointer at the start of the file, and no wait state: a run that has not read anything yet
	rm -rf "$rigSessDir/wait" 2> /dev/null
	( cd "$rigWs" && env -u MDAT_SESSION_THREAD -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT "MMDAPP=$rigWs" "MDLT_ORIGIN=$MDLT_ORIGIN" \
		bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionChat.include" || exit 9 ; AgentsToolsSessionChatPointerSet "$1" "read:$2" 0' _ "$rigSess" "$rigMember" ) 2> /dev/null || :
}
rigWait(){ ## output basename, sources... -- the operation's own wait, as the member, from the session's launch
	rigOp "$1" --wait-for-input --team-member "$rigMember" --wait-default --wait-session-id "$rigSess" --wait-timeout 8 --wait-poll-interval 1 --wait-since-utime "$rigRoot" "${@:2}"
}
rigConsole(){ ## body -- the console's message left for the session, then one writer pass taking it
	printf '%s' "$1" | rigOp console --manager-session-message --session-id "$rigSess"
	rigOp take --intern-session-comms --one --session-id "$rigSess"
}
rigPayload(){ ## n -- the payload of the nth post the fake curl kept
	LC_ALL=C cat "$rigScn/post.$1" 2> /dev/null
}
rigWaitTool(){ ## tool arguments json, output basename -- the Wait tool through the real harness
	rigRc=0
	printf '%s' "$1" | ( cd "$rigWs" && env -u MDAT_SESSION_THREAD -u MDAT_CONVERSATION_THREADS -u MDAT_SESSION_ID -u MDAT_DATA_ROOT \
		"PATH=$rigPath" "RIG_SCENARIO=$rigScn" "MMDAPP=$rigWs" "MDLT_ORIGIN=$MDLT_ORIGIN" "MDAT_SKILLSET_ROOT=$rigSkills" \
		MDAT_SPAWN_SESSION_ID="$rigSess" MDAT_SPAWN_AGENT="$rigMember" MDAT_WAIT_REMIND=off MDAT_SLACK_THREAD_CACHE_SECONDS=0 \
		bash "$rigHarness" --intern-tool Wait ) > "$rigTmp/$2.out" 2> "$rigTmp/$2.err" || rigRc=$?
}
rigFloorBlocks(){ ## covered ("" or channel:ts) -- how many blocks the chat floor delivers into $rigTmp/floor.out
	[ -z "${RIG_DBG:-}" ] || cp "$rigSessDir/session.chat.pointers" "$rigTmp/pointers.$RIG_DBG"
	( cd "$rigWs" && env -u MDAT_SESSION_THREAD -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT \
		"MMDAPP=$rigWs" "MDLT_ORIGIN=$MDLT_ORIGIN" bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionChat.include" || exit 9 ; AgentsToolsSessionChatFloor "$1" "$2" "$3" > "$4"' \
		_ "$rigSess" "$rigMember" "$1" "$rigTmp/floor.out" ) 2> "$rigTmp/floor.err" || return 1
	[ -z "${RIG_DBG:-}" ] || { cp "$rigTmp/floor.out" "$rigTmp/floor.$RIG_DBG.out" ; cp "$rigSessDir/session.chat.index" "$rigTmp/index.$RIG_DBG" ; }
	LC_ALL=C grep -c -E '^[0-9T:Z-]+ .* -> .*:$' "$rigTmp/floor.out" 2> /dev/null
}

echo "-- the console's message, sent into the session thread --"
rigConsole 'RIG-CONSOLE-BODY'
rigAssert "the console's message is left for the session and a writer pass sends it" "$rigRc:$( rigPayload 1 | LC_ALL=C grep -c -F 'RIG-CONSOLE-BODY' )" "0:1"
rigAssert "its post names the person at the console as its sender" "$( rigPayload 1 | LC_ALL=C grep -c -F '"sender":"user-rig-acct-7"' )" "1"

echo "-- 1. the post is a person's --"
rigAssert "and carries no tracking key of the tooling" "$( rigPayload 1 | LC_ALL=C grep -c -F '"tracking"' )" "0"

echo "-- the thread as Slack answers it, holding that post a person's --"
rigThread "$( rigPostLine "$rigRoot" RIG-ROOT )" "$( rigSent 1 "$rigConsoleTs" )"

echo "-- 2. the chat floor leaves the thread to the source that reads it --"
rigFresh
rigAssert "with the thread covered the floor delivers nothing of it" "$( rigFloorBlocks "$rigChannel:$rigRoot" ):$( LC_ALL=C grep -c -F 'RIG-CONSOLE-BODY' "$rigTmp/floor.out" )" "0:0"
rigFresh
rigAssert "with nothing covered it delivers the console's block" "$( rigFloorBlocks "" > /dev/null ; LC_ALL=C grep -c -F 'RIG-CONSOLE-BODY' "$rigTmp/floor.out" )" "1"

echo "-- 3. the wait returns it, once, in the shape that failed --"
rigFresh
rigWait console-wait --wait-source "chat:$rigSess" --wait-source "slack:$rigChannel:$rigRoot:conversation"
rigAssert "RECEIVED, with the console's body in it" "$( rigFirstLine console-wait ):$( rigHolds console-wait RIG-CONSOLE-BODY )" "WAIT-RESULT: RECEIVED:yes"
rigAssert "once, and named as the thread source's arrival" "$( LC_ALL=C grep -c -F 'RIG-CONSOLE-BODY' "$rigTmp/console-wait.out" ):$( LC_ALL=C grep -c -F "# arrived on: slack:$rigChannel:$rigRoot:conversation" "$rigTmp/console-wait.out" )" "1:1"

echo "-- 4. the harness tool returns it too --"
rigFresh
rigWaitTool "{\"timeout\":\"12\",\"poll_interval\":\"1\",\"mode\":\"default\",\"sources\":\"slack:$rigChannel:$rigRoot:conversation\",\"since_utime\":\"$rigRoot\"}" console-tool
rigAssert "the Wait tool's result carries the console's body" "$( LC_ALL=C grep -c -F 'RIG-CONSOLE-BODY' "$rigTmp/console-tool.out" )" "1"

echo "-- 5. the controls --"
rigThread "$( rigPostLine "$rigRoot" RIG-ROOT )" \
	"$( rigPostLine "$(( rigNow - 90 )).000003" RIG-MEMBER-BODY '{"metadata":{"event_type":"magic_sender","event_payload":{"sender":"magic-tester"}}}' )" \
	"$( rigPostLine "$(( rigNow - 60 )).000004" RIG-TOOLING-BODY '{"metadata":{"event_type":"magic_sender","event_payload":{"sender":"magic-team","tracking":"tooling"}}}' )"
rigFresh
rigWait control-wait --wait-source "slack:$rigChannel:$rigRoot:conversation" --wait-source "file:$rigScn/none"
rigAssert "a member's own post in the thread is returned" "$( rigHolds control-wait RIG-MEMBER-BODY )" "yes"
rigAssert "a tracking post the member is not addressed by is not" "$( rigHolds control-wait RIG-TOOLING-BODY )" "no"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WAIT CONSOLE MESSAGE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_CONSOLE_MESSAGE: OK (%d assertions, offline)\n' "$rigPassCount"
