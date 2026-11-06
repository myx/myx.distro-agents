#!/usr/bin/env bash
## Behavioural check that a console message is not starved by a backlog of queued posts: one pass over a workspace whose channel
## cache outbox holds a backlog takes the console's message FIRST, posts no more than its own share of the backlog, and returns, so
## the next pass drains more. Held, run and not read. Offline: the fake curl of the package's own fixtures, and every process this
## check starts is ended by it.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTest="$rigPackage/sh-test"
rigFixtures="$rigTest/check-fixtures"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "the team tooling is not at the origin: $rigTool"
. "$rigFixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionCommsStarveCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/skills/keeper-rig" "$rigTmp/skills/keeper-addr"
for rigMember in keeper-rig keeper-addr ; do printf '%s\n' "$rigMember" > "$rigTmp/skills/$rigMember/$rigMember.basic.md" ; done
cp "$rigFixtures/session-comms.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing"
chmod +x "$rigTmp/bin/curl"
rigPath="$rigTmp/bin:$PATH"

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

rigNow="$( date +%s )"
rigDir="$rigTmp/scene"
rigSession="rig-starve"
rigSessDir="$rigDir/ws/.local/agents/sessions/$rigSession"
rigRoot="$(( rigNow - 400 )).000001"
rigThread="CRIGSES01:$rigRoot"
rigCacheDir="$rigDir/ws/.local/cache/comms/slack/slack-CRIGSES01-$rigRoot"
mkdir -p "$rigDir/ws/.local/.agents" "$rigDir/ws/.local/temp" "$rigSessDir/chat.inbox" "$rigSessDir/chat.outbox" \
	"$rigDir/ws/.local/agents/spawned/trk" "$rigDir/data" "$rigCacheDir"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=DRIGOWN01\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigDir/ws/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-RIG\n' > "$rigDir/ws/.local/.agents/keeper-rig.agent.env"
printf '%s\n' "$rigThread" > "$rigSessDir/session.thread"
printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: rig\nworkspace: rigws\nowner: keeper-rig\nstatus: spawn-started\nstarted-at: 2026-11-05 09:00 +0200\n---\n\n# Spawn session: %s\n' "$rigSession" "$rigSession" "$rigSession" > "$rigDir/ws/.local/agents/spawned/trk/$rigSession.spawn.md"
mkdir -p "$rigSessDir/control"
sleep 600 > /dev/null 2>&1 < /dev/null &
rigStandPid=$!
rigProcNote "$rigStandPid"
rigStarted="$rigStandPid"
trap 'rigProcSignalWithChildren TERM $rigStarted ; rm -rf -- "$rigTmp"' EXIT
disown "$rigStandPid" 2> /dev/null || :
rigProcBegan "$rigStandPid" > "$rigSessDir/control/pid"
printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGOWNER","text":"RIG-ROOT","thread_ts":"%s"}],"has_more":false}\n' "$rigRoot" "$rigRoot" > "$rigDir/replies.CRIGSES01.$rigRoot.json"
: > "$rigDir/api.log"

## A backlog of queued posts to the channel, as the event-track feed and the async sends leave them: each one a record of the cache
## outbox, so the comms reader's push has work for many passes.
for rigRecord in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 ; do
	printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$rigSession" "17938800$rigRecord" keeper-rig bot chat.postMessage \
		"{\"channel\":\"CRIGSES01\",\"text\":\"RIG-BACKLOG-$rigRecord\",\"thread_ts\":\"$rigRoot\"}" >> "$rigCacheDir/outbox.messages.txt"
done
## And the console's message for the session, left by a person who is waiting for it.
printf 'user-myx -> magic-coordinator:\nRIG-CONSOLE-BODY\n' > "$rigSessDir/chat.inbox/20261105T130450Z.AAAA.msg"

## One pass: the reader over this workspace, forced, and no daemon left behind.
( cd "$rigDir/ws" && env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID -u MDAT_SESSION_THREAD \
	-u MDAT_COMMS_IDLE_SECONDS "PATH=$rigPath" "RIG_SCENARIO=$rigDir" "MMDAPP=$rigDir/ws" "MDAT_DATA_ROOT=$rigDir/data" \
	"MDLT_ORIGIN=$MDLT_ORIGIN" "MDAT_SKILLSET_ROOT=$rigTmp/skills" "MDAT_COMMS_READER=off" \
	bash "$rigTool" --intern-session-comms --one --session-id "$rigSession" ) > "$rigDir/pass-1.out" 2> "$rigDir/pass-1.err"
rigRc=$?
rigCalls(){ ## method -- how many calls of it the log holds
	LC_ALL=C awk -v want="$1" '$2 == want { count++ ; } END { print count + 0 ; }' "$rigDir/api.log"
}
rigFirstCall(){ ## the text of the first chat.postMessage the pass made
	LC_ALL=C sed -n 's/.*"text":"\([^"]*\)".*/\1/p' "$rigDir/post.1" 2> /dev/null | head -1
}
rigLeftInCache(){ ## records of the channel's cache outbox still waiting: those past the one the push has sent
	local leftSent=0 leftAll=0
	{ read -r leftSent _ _ < "$rigCacheDir/.push.txt" ; } 2> /dev/null || leftSent=0
	case "$leftSent" in ''|*[!0123456789]*) leftSent=0 ;; esac
	leftAll="$( cat "$rigCacheDir/outbox.messages.txt" "$rigCacheDir/outbox.pushing.txt" 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )"
	printf '%s' "$(( leftAll - leftSent ))"
}
rigChatPosted(){ ## whether the chat file records the console's block as slack
	LC_ALL=C grep -c -F -e RIG-CONSOLE-BODY "$rigSessDir/session.chat" 2> /dev/null
}

rigAssert "one pass ends well"                                   "$rigRc" 0
rigAssert "the console's message is posted in that one pass"     "$( rigChatPosted )" 1
rigAssert "and it is the first thing the pass posts, never behind the backlog" "$( rigFirstCall )" "RIG-CONSOLE-BODY"
rigAssert "the pass posts no more than its own share of the backlog" "$( rigCalls chat.postMessage )" "5"
rigAssert "and the rest of the backlog waits for the next pass"  "$( rigLeftInCache )" "36"

echo "-- 2. the next pass drains more, and takes no console message there is none of --"
( cd "$rigDir/ws" && env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID -u MDAT_SESSION_THREAD \
	-u MDAT_COMMS_IDLE_SECONDS "PATH=$rigPath" "RIG_SCENARIO=$rigDir" "MMDAPP=$rigDir/ws" "MDAT_DATA_ROOT=$rigDir/data" \
	"MDLT_ORIGIN=$MDLT_ORIGIN" "MDAT_SKILLSET_ROOT=$rigTmp/skills" "MDAT_COMMS_READER=off" \
	bash "$rigTool" --intern-session-comms --one --session-id "$rigSession" ) > "$rigDir/pass-2.out" 2> "$rigDir/pass-2.err"
rigRc=$?
rigAssert "the second pass ends well"                            "$rigRc" 0
rigAssert "and the backlog is shorter by that share again"       "$( rigLeftInCache )" "32"
rigAssert "so a backlog drains over passes, and no pass is the long one" "$( rigCalls chat.postMessage )" "9"

echo "-- 3. the session's own outbox is bounded the same way --"
printf 'RIG-QUEUED-ONE' > /dev/null
for rigBlock in 1 2 3 4 ; do
	printf 'keeper-rig\tuser\tchat.postMessage\n-\n{"channel":"CRIGSES01","text":"RIG-QUEUED-%s","thread_ts":"%s"}\n' "$rigBlock" "$rigRoot" > "$rigSessDir/chat.outbox/$rigBlock.retry"
done
printf 'user-myx -> magic-coordinator:\nRIG-SECOND-CONSOLE\n' > "$rigSessDir/chat.inbox/20261105T130550Z.BBBB.msg"
rigBefore="$( rigCalls chat.postMessage )"
( cd "$rigDir/ws" && env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID -u MDAT_SESSION_THREAD \
	-u MDAT_COMMS_IDLE_SECONDS "PATH=$rigPath" "RIG_SCENARIO=$rigDir" "MMDAPP=$rigDir/ws" "MDAT_DATA_ROOT=$rigDir/data" \
	"MDLT_ORIGIN=$MDLT_ORIGIN" "MDAT_SKILLSET_ROOT=$rigTmp/skills" "MDAT_COMMS_READER=off" \
	bash "$rigTool" --intern-session-comms --one --session-id "$rigSession" ) > "$rigDir/pass-3.out" 2> "$rigDir/pass-3.err"
rigRc=$?
rigAssert "a session's own outbox holds two posts back for the next pass" "$( ls "$rigSessDir/chat.outbox" 2> /dev/null | LC_ALL=C grep -c '\.retry$' )" 2
rigAssert "and the console's message of that pass is posted all the same" "$( LC_ALL=C grep -c -F RIG-SECOND-CONSOLE "$rigSessDir/session.chat" )" 1
rigAssert "the pass still ends well"                             "$rigRc" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ COMMS STARVE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'COMMS STARVE: OK (%d assertions, offline)\n' "$rigPassCount"
