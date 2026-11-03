#!/usr/bin/env bash
## Behavioural check on a plain Wait of a session that started others, and on the stored wait once an ask closes (S21.6).
##
## Held:
##   1. CHILDREN ARE WATCHED. A plain Wait's default sources hold the session thread and, after it, the session thread of every
##      child that still runs, one `slack:<thread>:conversation` each; a child its parent's index lists twice is given once.
##   2. ONLY A RUNNING CHILD IS WATCHED. A record that says its run started, with no process behind it on this host, is watched by
##      no call, and neither is a record that says its run ended.
##   3. A CALLER WITH NO CHILD KEEPS WHAT IT HAD. A session that started nobody gets its session thread alone, and a session on the
##      chat-file kind (`none`, `track`) keeps `chat:<session>` and no child beside it.
##   4. AN OPEN ASK IS WATCHED. `ask:<pending-id>` stays in the stored wait and is carried by a plain call.
##   5. A CLOSED ASK LEAVES THE STORED WAIT. A question withdrawn with no verdict leaves it at the close; one closed with a verdict
##      is carried by the one call that shows its closed note, and the call after carries it no more.
##   6. A NAMED SET REPLACES THE STORED WAIT. The sources a --wait-default call names become the stored set, a source stored earlier
##      and not named leaves it, and an open ask stays, its answer having no other watcher.
##   7. A ROUND READS EVERY SOURCE IT HOLDS. A round that has an arrival in hand and has passed its bound reads the rest of its
##      sources too, and WAIT-NEVER-READ names none of them.
##   8. A SOURCE INSIDE ITS SLOW GAP IS NOT ONE NEVER READ. A slack source the wait's own backoff skips was read within its gap,
##      so it is not reported as a source the round could not see.
##   9. A CLOSED ASK'S LATER REPLY REACHES THE ASKER BY THE SESSION FLOOR. With the ask gone from the stored wait, a new message in
##      its thread arrives from `replies:<session>`.
## Offline: a Slack-shaped fake curl answers every read from the scenario folder, every workspace is a folder of this rig's own, and
## no model CLI is started.
## Red recipe: take `$( AgentsToolsWaitChildThreadSources )` out of the loop in AgentsToolsWaitDefaultSources, in
## AgentsTools.SpawnSandbox.include, and 1 and 2 fail with 3 standing; take the `.closed-delivered` guard out of the carry-forward of
## AgentsTools.MemberWait.include, or the no-verdict drop out of --intern-op-pending-reply-close, and 5 fails with 4 standing.
## Take the closed-ask filter out of AgentsWaitStateStore (AgentsTools.MemberWait.include), and 5 fails on the stored wait; carry every stored
## source past a named set in the carry-forward, and 6 fails; put the between-sources bound break back in, and 7 fails; take the read mark off
## the slow-gap skip, and 8 fails; drop `replies:` from the session floor, and 9 fails.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigSpawn="$rigHere/session/AgentsTools.SpawnSandbox.include"
rigFixtures="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="rig-member"
rigBash="${BASH:-bash}"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigSpawn" ] || rigRefuse "the spawn include is not at the origin this workspace resolves: $rigSpawn"
[ -x "$rigTool" ] || rigRefuse "the team tooling is not at the origin this workspace resolves: $rigTool"
. "$rigFixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package"
. "$rigFixtures/rig-blocking-stand-in.include.sh" || rigRefuse "the rig's blocking stand-in is missing from the package"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWaitChildSourcesCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigChildPids=""
rigEnd(){
	## every child of this check, and what it started, ended at once, and only while it is still that same process
	rigProcSignalWithChildren KILL $rigChildPids
	rm -rf -- "$rigTmp"
}
trap 'rigEnd' EXIT
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
rigOf(){ ## text, source -- how many of the text's words are exactly that source
	printf '%s\n' "$1" | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c -x -F "$2"
}
rigThisHost="$( hostname -s 2>/dev/null )" || rigThisHost="rig-host"

## ---- 1 to 3: what a plain Wait of a session that started others defaults to ----
rigKidsAt="$rigTmp/kids"
rigKidsWs="$rigKidsAt/ws"
rigKidsData="$rigKidsAt/data"
rigParent="rig-parent-0001"
rigParentThread="CRIGPAR01:100.000001"
mkdir -p "$rigKidsWs/.local/agents/children" "$rigKidsWs/.local/agents/spawned" "$rigKidsWs/.local/agents/sessions" "$rigKidsData"
rigChildRun(){ ## spawn id -- a process that runs as that spawn, by the one rule a run is recognised by; it blocks on a
	## pipe this check holds, so it costs no wake-up a second and ends by itself when the check does
	rigBlockingStandIn "$1" || rigRefuse "the child run stand-in for $1 could not be started"
	printf '%s\n' "$rigStandPid" > "$rigKidsAt/$1.pid"
	rigChildPids="$rigChildPids $rigStandPid"
}
rigChildStop(){ ## spawn id
	[ -f "$rigKidsAt/$1.pid" ] || return 0
	rigProcSignal KILL "$( cat "$rigKidsAt/$1.pid" )" 2>/dev/null || :
	wait "$( cat "$rigKidsAt/$1.pid" )" 2>/dev/null || :
}
rigChildRecord(){ ## spawn id, session id, thread, status
	local recDir="$rigKidsWs/.local/agents/spawned/$1"
	mkdir -p "$recDir" "$rigKidsWs/.local/agents/sessions/$2/seats"
	printf '%s\n' '---' "spawn-id: $1" "session-id: $2" "parent-spawn-id: $rigParent" "tracking-name: $2" "host: $rigThisHost" \
		"owner: $rigMember" "status: $4" "session-thread: $3" '---' > "$recDir/$1.spawn.md"
	printf '%s\n' "$1" > "$rigKidsWs/.local/agents/sessions/$2/seats/$rigMember"
}
rigDefaults(){ ## the default sources of a plain Wait in the children workspace
	env -i HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigKidsWs" MDAT_DATA_ROOT="$rigKidsData" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		MDLT_ORIGIN="$MDLT_ORIGIN" RIG_TMP="$rigTmp" MDAT_SESSION_THREAD="$rigParentThread" MDAT_SPAWN_SESSION_ID="$rigParent" \
		"$rigBash" -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SpawnSandbox.include"
			AgentsToolsWaitDefaultSources
		' 2>/dev/null
}

echo "-- 1 to 3: the children a plain Wait watches --"
rigChildRecord rigchild0001 rig-kid-session-1 CRIGKID01:200.000001 spawn-started
rigChildRecord rigchild0001b rig-kid-session-1 CRIGKID01:200.000001 spawn-started
rigChildRecord rigchild0002 rig-kid-session-2 CRIGKID02:200.000002 spawn-started
rigChildRecord rigchild0003 rig-kid-session-3 CRIGKID03:200.000003 spawn-finished
rigChildRecord rigchild0004 rig-kid-session-4 CRIGKID04:200.000004 spawn-started
rigChildRun rigchild0001
rigChildRun rigchild0001b
rigChildRun rigchild0002
( . "$rigHere/session/AgentsTools.ChildrenIndex.include" ; . "$rigSpawn" ; AgentsToolsChildrenIndexRepair "$rigKidsWs" ) > /dev/null 2>&1 \
	|| rigRefuse "the rig could not list the children it made"
rigAssert "the parent's index lists one record a line"  "$( wc -l < "$rigKidsWs/.local/agents/children/$rigParent" | tr -d ' ' )" 5
rigAssert "a plain Wait watches the session and each running child once" "$( rigDefaults )" \
	"slack:$rigParentThread:conversation slack:CRIGKID01:200.000001:conversation slack:CRIGKID02:200.000002:conversation"
rigChildStop rigchild0002
rigAssert "a child whose process is gone is no longer watched" "$( rigDefaults )" \
	"slack:$rigParentThread:conversation slack:CRIGKID01:200.000001:conversation"
: > "$rigKidsWs/.local/agents/children/$rigParent"
rigAssert "a session that started nobody keeps its session thread alone" "$( rigDefaults )" "slack:$rigParentThread:conversation"
mkdir -p "$rigKidsWs/.local/agents/sessions/$rigParent"
printf 'none\n' > "$rigKidsWs/.local/agents/sessions/$rigParent/root-session.kind"
rigAssert "a session on the chat-file kind keeps chat: alone, child or none" "$( rigDefaults )" "chat:$rigParent"
rm -f "$rigKidsWs/.local/agents/sessions/$rigParent/root-session.kind"

## ---- 4 and 5: the stored wait, once a question it watches closes ----
rigAskAt="$rigTmp/asks"
rigAws="$rigAskAt/ws"
rigData="$rigAskAt/data"
rigSess="rig-wait-session"
rigChannel="DRIGASK01"
rigAskTs="500.000001"
rigNow="$( date +%s )"
mkdir -p "$rigAws/.local/.agents" "$rigAws/.local/agents/sessions/$rigSess" "$rigAws/.local/agents/pending/closed" \
	"$rigData/inboxes/$rigMember/incoming" "$rigData/board/pending" "$rigAskAt"
printf 'SLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_USER_TOKEN=rig-user-token-RIG\n' > "$rigAws/.local/.agents/$rigMember.agent.env"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=DRIGOWN01\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigAws/.local/.agents/magic-team.agent.env"
printf '%s\n' "$rigParentThread" > "$rigAws/.local/agents/sessions/$rigSess/session.thread"
: > "$rigAskAt/launch.marker"
touch -t "$( date -r "$(( rigNow - 300 ))" +%Y%m%d%H%M.%S 2>/dev/null || date -d "@$(( rigNow - 300 ))" +%Y%m%d%H%M.%S )" "$rigAskAt/launch.marker"
printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGASKED","text":"rig question"}],"has_more":false}\n' "$rigAskTs" \
	> "$rigAskAt/replies.$rigChannel.$rigAskTs.json"
: > "$rigAskAt/api.log"
rigAskRecord(){ ## pending id
	printf '%s\n' '---' 'status: reply-pending' "owner: $rigMember" "host: $rigThisHost" "session-id: $rigSess" 'kind: question' \
		'address-to: human-owner' "channel: $rigChannel" "question-ts: $rigAskTs" "thread-ts: $rigAskTs" \
		'addressees: URIGHUMAN1' 'asked-at: 2026-01-01 00:00 +0000' '---' '' '# Question asked' '' "rig question $1" \
		> "$rigAws/.local/agents/pending/$1.md"
}
rigAskEnv(){ ## the operation's arguments after the member
	env -i "PATH=$rigWaitPath" "RIG_SCENARIO=$rigAskAt" "HOME=$rigTmp" "MMDAPP=$rigAws" "MDAT_DATA_ROOT=$rigData" \
		"MDAT_SKILLSET_ROOT=$rigTmp/skills" "MDLT_ORIGIN=$MDLT_ORIGIN" "MDAT_SESSION_ID=$rigSess" "RIG_TMP=$rigTmp" \
		"MDAT_SPAWN_LAUNCH_MARKER=$rigAskAt/launch.marker" "MDAT_WAIT_POLL_SECONDS=${rigPollSeconds-1}" MDAT_WAIT_SETTLE_SECONDS=1 MDAT_WAIT_REMIND=off \
		"$rigTool" --wait-for-input --team-member "$rigMember" "$@"
}
rigWaitEcho(){ ## output basename, then the operation's arguments after the member
	local waitName="$1" waitPid waitWatch
	shift
	rigOut="$rigAskAt/$waitName.out"
	rigAskEnv "$@" > "$rigOut" 2> "$rigAskAt/$waitName.err" &
	waitPid=$!
	( waitLeft=60 ; while [ "$waitLeft" -gt 0 ] ; do kill -0 "$waitPid" 2>/dev/null || exit 0 ; sleep 1 ; waitLeft=$(( waitLeft - 1 )) ; done
	  printf 'rig: the wait did not return within 60s, and was killed\n' >> "$rigAskAt/$waitName.err" ; kill -TERM "$waitPid" 2>/dev/null ; sleep 2 ; kill -KILL "$waitPid" 2>/dev/null ) &
	waitWatch=$!
	wait "$waitPid" 2>/dev/null
	kill -TERM "$waitWatch" 2>/dev/null
	wait "$waitWatch" 2>/dev/null || :
}
rigPlain(){ ## output basename -- a plain call over the stored wait: every source read once, then it returns
	rigWaitEcho "$1" --wait-default --wait-session-id "$rigSess" --wait-timeout 0 --wait-source "file:$rigAskAt/none"
}
rigWatch(){ ## the sources the last call resolved
	[ -f "$rigOut" ] || { printf 'no-output' ; return 0 ; }
	LC_ALL=C sed -n 's/^# sources: //p' "$rigOut"
}
rigHolds(){ ## text -- yes or no, in the last output
	[ -f "$rigOut" ] || { printf 'no-output' ; return 0 ; }
	case "$( cat "$rigOut" )" in *"$1"*) printf yes ;; *) printf no ;; esac
}
rigStored(){ ## the sources the stored wait holds
	[ -f "$rigAws/.local/agents/sessions/$rigSess/wait/state" ] || { printf 'no-state' ; return 0 ; }
	LC_ALL=C sed -n 's/^sources: //p' "$rigAws/.local/agents/sessions/$rigSess/wait/state"
}
rigNeverRead(){ ## none|named -- the sources the last call could not read
	[ -f "$rigOut" ] || { printf "no-output" ; return 0 ; }
	case "$( LC_ALL=C sed -n 's/^WAIT-NEVER-READ: //p' "$rigOut" )" in '') printf none ;; *) printf named ;; esac
}
rigSettle(){ ## pending id, reason, extra flag -- closes the record the way its asker does
	env -i "PATH=$rigWaitPath" "RIG_SCENARIO=$rigAskAt" "HOME=$rigTmp" "MMDAPP=$rigAws" "MDAT_DATA_ROOT=$rigData" \
		"MDAT_SKILLSET_ROOT=$rigTmp/skills" "MDLT_ORIGIN=$MDLT_ORIGIN" "MDAT_SESSION_ID=$rigSess" "MDAT_SPAWN_AGENT=$rigMember" \
		"$rigTool" --settle-pending-reply --team-member "$rigMember" "$1" --reason "$2" $3 2>&1
}

echo "-- 4: a question in the stored wait, while it is open --"
rigAskRecord rig-ask-open
rigWaitEcho add-open --wait-add --wait-session-id "$rigSess" --wait-source "ask:rig-ask-open" > /dev/null 2>&1
rigAssert "an added source is in the stored wait"        "$( rigOf "$( rigStored )" ask:rig-ask-open )" 1

echo "-- 5: a question its asker withdraws, with no verdict --"
rigAskRecord rig-ask-withdrawn
rigWaitEcho add-withdrawn --wait-add --wait-session-id "$rigSess" --wait-source "ask:rig-ask-withdrawn" > /dev/null 2>&1
rigAssert "the question is in the stored wait"           "$( rigOf "$( rigStored )" ask:rig-ask-withdrawn )" 1
rigAssert "its asker withdraws it"                       "$( rigSettle rig-ask-withdrawn 'the rig no longer needs it' --withdraw | LC_ALL=C grep -c '^WITHDRAWN ' )" 1
rigAssert "the record is closed"                         "$( LC_ALL=C sed -n 's/^status: //p' "$rigAws/.local/agents/pending/closed/rig-ask-withdrawn.md" )" withdrawn
rigAssert "the closed question has left the stored wait" "$( rigOf "$( rigStored )" ask:rig-ask-withdrawn )" 0
rigPlain after-withdraw
rigAssert "and no plain call carries it"                 "$( rigOf "$( rigWatch )" ask:rig-ask-withdrawn )" 0
rigAssert "an open question is carried by the same call"  "$( rigOf "$( rigWatch )" ask:rig-ask-open )" 1
rigAssert "and stays in the stored wait"                 "$( rigOf "$( rigStored )" ask:rig-ask-open )" 1

echo "-- 5: a question closed with a verdict, by a readback --"
rigAskRecord rig-ask-readback
rigWaitEcho add-readback --wait-add --wait-session-id "$rigSess" --wait-source "ask:rig-ask-readback" > /dev/null 2>&1
rigAssert "its asker settles it by readback"             "$( rigSettle rig-ask-readback 'the rig read back its understanding' '' | LC_ALL=C grep -c '^SETTLED ' )" 1
rigAssert "the record is closed"                         "$( LC_ALL=C sed -n 's/^status: //p' "$rigAws/.local/agents/pending/closed/rig-ask-readback.md" )" reply-received
rigPlain after-readback
rigAssert "the call that shows the closed note holds it" "$( rigOf "$( rigWatch )" ask:rig-ask-readback )" 1
rigAssert "and the closed note is shown there"           "$( rigHolds 'is closed: reply-received' )" yes
rigAssert "the note shown once is marked"                "$( [ -f "$rigAws/.local/agents/pending/closed/rig-ask-readback.closed-delivered" ] && printf yes || printf no )" yes
rigPlain after-readback-again
rigAssert "the call after carries it no more"            "$( rigOf "$( rigWatch )" ask:rig-ask-readback )" 0
rigAssert "and the stored wait no longer lists it"       "$( rigOf "$( rigStored )" ask:rig-ask-readback )" 0
echo "-- 6: a named set replaces the stored wait --"
: > "$rigAskAt/two.txt"
rigThreadTs="$(( rigNow - 1200 )).000003"
rigWaitEcho named-thread --wait-default --wait-session-id "$rigSess" --wait-timeout 0 \
	--wait-source "file:$rigAskAt/none" --wait-source "slack:$rigChannel:$rigThreadTs:conversation" > /dev/null 2>&1
rigAssert "a named source is in the stored wait"         "$( rigOf "$( rigStored )" "file:$rigAskAt/none" )" 1
rigWaitEcho named-other --wait-default --wait-session-id "$rigSess" --wait-timeout 0 --wait-source "file:$rigAskAt/two.txt" > /dev/null 2>&1
rigAssert "a named call replaces the stored set"          "$( rigOf "$( rigStored )" "file:$rigAskAt/none" )" 0
rigAssert "and the thread it did not name leaves it"      "$( rigOf "$( rigStored )" "slack:$rigChannel:$rigThreadTs:conversation" )" 0
rigAssert "the source it named is what the set holds"     "$( rigOf "$( rigStored )" "file:$rigAskAt/two.txt" )" 1
rigAssert "an open ask stays through a named call"        "$( rigOf "$( rigStored )" ask:rig-ask-open )" 1
rigSettle rig-ask-open "the rig closed its open question by readback" "" > /dev/null 2>&1
echo "-- 7: a round reads every source it holds --"
rigManyCount=20
rigManySources="--wait-source file:$rigAskAt/arrive.txt"
rigManyI=1
while [ "$rigManyI" -le "$rigManyCount" ] ; do
	printf 'rig quiet %s\n' "$rigManyI" > "$rigAskAt/many.$rigManyI.txt"
	rigManySources="$rigManySources --wait-source file:$rigAskAt/many.$rigManyI.txt"
	rigManyI=$(( rigManyI + 1 ))
done
printf 'rig before\n' > "$rigAskAt/arrive.txt"
## shellcheck disable=SC2086 -- the sources are the one argument list the call takes
rigWaitEcho many-first --wait-default --wait-session-id "$rigSess" --wait-timeout 0 $rigManySources > /dev/null 2>&1
rigAssert "a closed ask is not stored by a named call"   "$( rigOf "$( rigStored )" ask:rig-ask-open )" 0
printf 'rig arrived now\n' > "$rigAskAt/arrive.txt"
rigAssert "the call returned on the arrival"                 "$( LC_ALL=C sed -n 's/^WAIT-RESULT: //p' "$rigOut" )" RECEIVED
rigAssert "a round with an arrival in hand reads every source it holds" "$( rigNeverRead )" none

echo "-- 8: a source inside its slow gap is not one never read --"
rigQuietSource="slack:$rigChannel:$(( rigNow - 600 )).000002:conversation"
printf '%s\t%s\n' "$rigQuietSource" "$(( rigNow - 3 ))" >> "$rigAws/.local/agents/sessions/$rigSess/wait/probed"
rigPollSeconds="" rigWaitEcho gap-skipped --wait-default --wait-session-id "$rigSess" --wait-timeout 5 --wait-source-ttl 2 \
	--wait-source "$rigQuietSource" > /dev/null 2>&1
rigAssert "a source the slow gap skipped was read within its gap" "$( rigNeverRead )" none

echo "-- 9: a closed ask's later reply reaches the asker by the session floor --"
rigFloorPostTs="$(( rigNow - 120 )).000001"
rigFloorReplyTs="$(( rigNow - 60 )).000002"
printf '%s\n' "$rigChannel:$rigAskTs $rigFloorPostTs URIGHUMAN1 $rigFloorPostTs - 0 - 0" \
	> "$rigAws/.local/agents/sessions/$rigSess/last-own-post"
printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGHUMAN1","text":"rig later reply in the closed thread"}],"has_more":false}\n' "$rigFloorReplyTs" \
	> "$rigAskAt/replies.$rigChannel.$rigAskTs.json"
rigPlain after-closed-reply
rigAssert "the closed ask is gone from the stored wait"   "$( rigOf "$( rigStored )" ask:rig-ask-readback )" 0
rigAssert "the session floor carries the replies source"   "$( rigOf "$( rigWatch )" "replies:$rigSess" )" 1
rigAssert "and the later reply reaches the asker by it"    "$( rigHolds 'rig later reply in the closed thread' )" yes
if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WAIT CHILD SOURCES CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WAIT_CHILD_SOURCES: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
