#!/usr/bin/env bash
## Behavioural check on S6.25: a close ends only what it owns.
## An executor's close dismisses the runs it spawned, matched on `parent-spawn-id`; a participant's close
## ends that run alone. A dismissal is tooling-internal: the run's own mark is kept, the session's chat file
## records it, and nothing is posted to the run. A run that waits is reached from that chat file within its
## tick, and a run that asks again is told at once from its mark. The executor says what it ended in one line
## to @here, under its own name, and in no other post.
## Red before S6.25: `AgentsReviewChildrenDismiss` matched `parent-session-id`, so every peer of a chair read
## as a child, and each close posted a DISMISSED message into its peers' threads.
## Offline: a Slack-shaped fake curl logs each post and opens no socket; each run is a stand-in process
## carrying its own spawn id; the workspace, the board and the session stores are this rig's own temp tree.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPkg="${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}/myx/myx.distro-agents"
rigSandbox="$rigPkg/sh-lib/session/AgentsTools.SpawnSandbox.include"
rigHarnessWait="$rigPkg/sh-lib/harness/AgentsHarnessWait.include"
rigMatch="$rigPkg/sh-lib/questions/AgentsDismissalMatch.awk"
rigMatcher="$rigPkg/sh-lib/harness/AgentsHarnessWaitDismissed.awk"
rigFixture="$rigPkg/sh-test/check-fixtures/harness-ask-check.curl.stub.sh"
rigTool="$rigPkg/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigSandbox" "$rigHarnessWait" "$rigMatch" "$rigMatcher" "$rigFixture" ; do
	[ -f "$rigFile" ] || rigRefuse "a file this check measures is not at the origin: $rigFile"
done
[ -x "$rigTool" ] || rigRefuse "the team tooling is not at the origin: $rigTool"
mkdir -p "$MMDAPP/.local/temp"
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsCloseOwnsRunsCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigPids=""
trap 'for rigOne in $rigPids ; do kill -KILL "$rigOne" 2> /dev/null ; done ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSpawned="$rigWs/.local/agents/spawned"
rigSessions="$rigWs/.local/agents/sessions"
rigSkills="$rigTmp/skills"
mkdir -p "$rigWs/.local/.agents" "$rigSessions" "$rigSpawned" "$rigTmp/bin" "$rigTmp/data/board" "$rigSkills"
for rigName in magic-coordinator magic-tester magic-librarian rig-part-a rig-part-b rig-part-c ; do
	mkdir -p "$rigWs/.local/agents/members/$rigName" "$rigSkills/$rigName"
	printf -- '---\nname: %s\n---\nrig member\n' "$rigName" > "$rigWs/.local/agents/members/$rigName/SKILL.md"
	printf '%s\n' "$rigName" > "$rigSkills/$rigName/$rigName.basic.md"
done
cp "$rigFixture" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl" || rigRefuse "could not install the fake curl"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf '{"ok":true,"messages":[],"has_more":false}\n' > "$rigTmp/replies.json"
rigHost="$( hostname -s 2> /dev/null )" || rigHost="unknown"

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
rigInRig(){ ## the function, then its arguments
	local rigFn="$1"
	shift
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigTmp/data" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		RIG_SCENARIO="$rigTmp" RIG_CURL_LOG="$rigTmp/curl.log" \
		bash -c '. "$1" ; shift ; "$@"' rig "$rigSandbox" "$rigFn" "$@" 2>&1
}
rigClose(){ ## record path, the closing member
	rigInRig AgentsToolsSpawnProxyCloseSandbox "$1" succeeded 0 "the rig ended it"
}
rigMark(){ ## spawn id -- what its tooling dismissal mark holds, or `none`
	[ -f "$rigSessions/$1/dismissed" ] && LC_ALL=C head -1 "$rigSessions/$1/dismissed" || printf 'none'
}
rigPosts(){ ## how many posts the fake curl took
	if [ -f "$rigTmp/curl.log" ] ; then
		LC_ALL=C grep -c '^chat.postMessage' "$rigTmp/curl.log" || :
	else
		printf '0'
	fi
}
rigPostBodies(){ LC_ALL=C cat "$rigTmp"/post.* 2> /dev/null || : ; }
rigHeader(){ ## record path, header
	LC_ALL=C sed -n "s/^$2: //p" "$1" 2> /dev/null | head -1
}
rigLive(){ ## spawn id -- a stand-in process carrying the id, in the host process list
	python3 -I -B -c 'import time; time.sleep(600)' -- --session-id "$1" > /dev/null 2>&1 &
	rigPids="$rigPids $!" ; disown "$!" 2> /dev/null || :
}
## A run of one session: the founder, or a participant that names its parent run.
rigRecord(){ ## spawn id, session id, owner, parent spawn id, start context, session thread
	mkdir -p "$rigSpawned/$1" "$rigSessions/$1"
	printf '%s\n' "$6" > "$rigSessions/$1/session.thread"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: %s\nstart-context: %s\nparent-session-id: %s\ntracking-name: %s\nhost: %s\nowner: %s\nstatus: spawn-started\nsession-thread: %s\n---\n' \
		"$2" "$1" "$4" "$5" "$2" "$1" "$rigHost" "$3" "$6" > "$rigSpawned/$1/$1.spawn.md"
}
## A run already waiting: its floor's pointer is where it stood when it began waiting, so what comes after
## is what it is handed. Called before the close, as a real waiting run is.
rigWaits(){ ## session id, member
	mkdir -p "$rigSessions/$1"
	[ -f "$rigSessions/$1/session.chat.pointers" ] || : > "$rigSessions/$1/session.chat.pointers"
	LC_ALL=C grep -q "^read:$2	" "$rigSessions/$1/session.chat.pointers" 2> /dev/null \
		|| printf 'read:%s\t0\n' "$2" >> "$rigSessions/$1/session.chat.pointers"
}
## The harness's own first look at a run of the rig: who dismissed it, printed, rc 1 where none did.
rigHarnessDismissedBy(){ ## spawn id
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigTmp/data" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SPAWN_SESSION_ID="$1" RIG_SCENARIO="$rigTmp" RIG_CURL_LOG="$rigTmp/curl.log" \
		bash -c '. "$1" ; . "$2" ; AgentsHarnessDismissedBy' rig "$rigPkg/sh-lib/harness/AgentsHarnessSpawn.include" "$rigHarnessWait" 2> /dev/null || printf 'none'
}
## What a waiting run's own floor gives it: the chat file read from the pointer that run already holds, as its
## Wait renders it, through the one matcher a harness reads a DISMISSED with.
rigWaitSays(){ ## session id, spawn id, member -- DISMISSED where that run's floor hands it one, else `no`
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigTmp/data" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SESSION_ID="$1" MDAT_SPAWN_SESSION_ID="$2" MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$rigTmp" RIG_CURL_LOG="$rigTmp/curl.log" \
		bash -c '
			. "$1"
			{ printf "WAIT-RESULT: RECEIVED\n" ; AgentsToolsSessionChatFloor "$2" "$3" ; } > "$4"
			dismissalMember="$3" LC_ALL=C awk -f "$5" -f "$6" "$4" > /dev/null && printf "DISMISSED" || printf "no"
		' rig "$rigPkg/sh-lib/session/AgentsTools.SessionChat.include" "$1" "$3" "$rigTmp/floor.$$" "$rigMatch" "$rigMatcher" 2> /dev/null || printf 'error'
}

## The participant's own Wait, started as its CLI starts it: default mode, and its session thread named as a source of
## the same wait, which is what a real run has. Its floor is then the chat file with that thread covered, so only a
## block nobody posted can reach it.
rigRealWaitStart(){
	: > "$rigTmp/realwait.out" ; : > "$rigTmp/realwait.err"
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigTmp/data" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_SESSION_ID="$rigWaitSession" MDAT_SPAWN_SESSION_ID="$rigWaitPart" \
		MDAT_SESSION_THREAD="$rigWaitThread" MDAT_SPAWN_AGENT=rig-part-a MDAT_WAIT_POLL_SECONDS=1 MDAT_WAIT_REMIND=off \
		RIG_SCENARIO="$rigTmp" RIG_CURL_LOG="$rigTmp/curl.log" \
		bash "$rigTool" --wait-for-input --team-member rig-part-a --wait-default --wait-session-id "$rigWaitSession" \
		--wait-source "slack:$rigWaitThread:conversation" --wait-timeout 30 > "$rigTmp/realwait.out" 2> "$rigTmp/realwait.err" &
	rigRealWaitPid=$!
	rigPids="$rigPids $rigRealWaitPid" ; disown "$rigRealWaitPid" 2> /dev/null || :
}

echo "-- 1. a chair and three participants, each naming the chair's session and the chair's own run --"
rigChair="rig-chair-$$"
rigPartA="rig-part-a-$$"
rigPartB="rig-part-b-$$"
rigPartC="rig-part-c-$$"
rigSession="$rigChair"
rigRecord "$rigChair" "$rigSession" magic-coordinator none spawned CCHAIR001:1700000000.000100
rigRecord "$rigPartA" "$rigSession" rig-part-a "$rigChair" joined CCHAIR001:1700000000.000110
rigRecord "$rigPartB" "$rigSession" rig-part-b "$rigChair" joined CCHAIR001:1700000000.000120
rigRecord "$rigPartC" "$rigSession" rig-part-c "$rigChair" joined CCHAIR001:1700000000.000130
rigLive "$rigChair" ; rigLive "$rigPartA" ; rigLive "$rigPartB" ; rigLive "$rigPartC"
rigWaits "$rigSession" rig-part-a
rigWaits "$rigSession" rig-part-b
rigWaits "$rigSession" rig-part-c
sleep 2

echo "-- 2. the chair's close is the one that dismisses, and all three are its own runs --"
: > "$rigTmp/curl.log" ; rm -f "$rigTmp"/post.*
rigOut="$( rigClose "$rigSpawned/$rigChair/$rigChair.spawn.md" magic-coordinator )"
rigAssert "the chair's record closes"                   "$( rigHeader "$rigSpawned/$rigChair/$rigChair.spawn.md" status )" "spawn-succeeded"
rigAssert "all three runs are marked by the tooling"    "$( rigMark "$rigPartA" ):$( rigMark "$rigPartB" ):$( rigMark "$rigPartC" )" \
	"tooling (the close of $rigChair):tooling (the close of $rigChair):tooling (the close of $rigChair)"
rigAssert "the chair's close names all three"           "$( printf '%s' "$rigOut" | LC_ALL=C grep -c "CHILDREN-CLOSE: 3 of 3 waiting run(s) dismissed" )" "1"
rigAssert "the participants' own records are left to them" \
	"$( rigHeader "$rigSpawned/$rigPartA/$rigPartA.spawn.md" status ):$( rigHeader "$rigSpawned/$rigPartB/$rigPartB.spawn.md" status ):$( rigHeader "$rigSpawned/$rigPartC/$rigPartC.spawn.md" status )" \
	"spawn-started:spawn-started:spawn-started"
rigAssert "nothing was posted to any run"                "$( rigPosts )" "1"
rigAssert "and no post holds a DISMISSED"                "$( printf '%s' "$( rigPostBodies )" | LC_ALL=C grep -c 'DISMISSED' )" "0"

echo "-- 3. one line to @here, under the chair's own name --"
rigAssert "it is headed @here, naming nobody"            "$( printf '%s' "$( rigPostBodies )" | LC_ALL=C grep -c '→ @here' )" "1"
rigAssert "and it speaks as the chair"                   "$( printf '%s' "$( rigPostBodies )" | LC_ALL=C grep -c 'magic-coordinator' )" "1"

echo "-- 4. a waiting run is reached from the tooling's state, and nothing was posted to it --"
rigAssert "participant A's Wait reads a DISMISSED"       "$( rigWaitSays "$rigSession" "$rigPartA" rig-part-a )" "DISMISSED"
rigAssert "and so does participant C's"                  "$( rigWaitSays "$rigSession" "$rigPartC" rig-part-c )" "DISMISSED"
rigAssert "a member the close never names reads no dismissal" "$( rigWaitSays "$rigSession" "rig-stranger-$$" keeper-unaddressed )" "no"
rigAssert "the state keeps answering, asked again"       "$( rigHarnessDismissedBy "$rigPartA" )" "tooling (the close of $rigChair)"
rigAssert "and still nothing was posted"                 "$( rigPosts )" "1"

echo "-- 5. a participant's own close ends that run alone --"
rigOwn="rig-own-$$"
rigPeer="rig-peer-$$"
rigBoss="rig-boss-$$"
rigSession2="rig-sess2-$$"
rigRecord "$rigBoss" "$rigSession2" magic-coordinator none spawned C2CHAIR1:1700000000.000200
rigRecord "$rigOwn" "$rigSession2" magic-librarian "$rigBoss" joined C2CHAIR1:1700000000.000210
rigRecord "$rigPeer" "$rigSession2" magic-tester "$rigBoss" joined C2CHAIR1:1700000000.000220
rigLive "$rigOwn" ; rigLive "$rigPeer"
rigWaits "$rigSession2" magic-tester
sleep 2
: > "$rigTmp/curl.log" ; rm -f "$rigTmp"/post.*
rigOut="$( rigClose "$rigSpawned/$rigOwn/$rigOwn.spawn.md" magic-librarian )"
rigAssert "the closing participant's record closes"     "$( rigHeader "$rigSpawned/$rigOwn/$rigOwn.spawn.md" status )" "spawn-succeeded"
rigAssert "it marks no peer"                            "$( rigMark "$rigPeer" )" "none"
rigAssert "it marks no run of its own"                  "$( rigMark "$rigOwn" )" "none"
rigAssert "it posts nothing"                            "$( rigPosts )" "0"
rigAssert "and it says it ended no run"                 "$( printf '%s' "$rigOut" | LC_ALL=C grep -c 'CHILDREN-CLOSE: no run was spawned by this one' )" "1"
rigAssert "the peer's run is left alone"                "$( rigHeader "$rigSpawned/$rigPeer/$rigPeer.spawn.md" status )" "spawn-started"
rigAssert "the peer's Wait reads no dismissal"          "$( rigWaitSays "$rigSession2" "$rigPeer" magic-tester )" "no"

echo "-- 6. a real Wait, its session thread among its sources, is reached while it waits --"
## A participant's own `--wait-for-input`, in default mode, with its session thread named as a source of the same
## wait. Its floor is then the chat file with that thread covered, which is the shape a real run has. The close
## lands while it waits, and the block nobody posted must still be handed over.
rigWaitChair="rig-wchair-$$"
rigWaitPart="rig-wpart-$$"
rigWaitSession="$rigWaitChair"
rigWaitThread="C3CHAIR1:1700000000.000300"
rigRecord "$rigWaitChair" "$rigWaitSession" magic-coordinator none spawned "$rigWaitThread"
rigRecord "$rigWaitPart" "$rigWaitSession" rig-part-a "$rigWaitChair" joined C3CHAIR1:1700000000.000310
: > "$rigTmp/curl.log" ; rm -f "$rigTmp"/post.*
rigRealWaitStart
sleep 4
rigOut="$( rigClose "$rigSpawned/$rigWaitChair/$rigWaitChair.spawn.md" magic-coordinator )"
rigLeft=40
while [ "$rigLeft" -gt 0 ] && [ ! -s "$rigTmp/realwait.out" ] ; do
	sleep 1 ; rigLeft=$(( rigLeft - 1 ))
done
rigAssert "the session thread was a source of that wait"  "$( LC_ALL=C sed -n 's/^# sources: //p' "$rigTmp/realwait.out" | LC_ALL=C grep -c "slack:$rigWaitThread:conversation" )" "1"
rigAssert "the wait returned, carrying the dismissal"    "$( LC_ALL=C head -1 "$rigTmp/realwait.out" ):$( LC_ALL=C grep -c 'DISMISSED' "$rigTmp/realwait.out" )" "WAIT-RESULT: RECEIVED:1"
rigAssert "and the one matcher a harness uses reads it"  "$( dismissalMember=rig-part-a LC_ALL=C awk -f "$rigMatch" -f "$rigMatcher" "$rigTmp/realwait.out" > /dev/null && printf dismissed || printf no )" "dismissed"
rigWaited="$( LC_ALL=C sed -n 's/^# waited: \([0-9]*\)s of .*/\1/p' "$rigTmp/realwait.out" | head -1 )"
rigAssert "the wait ended well inside its bound"        "$( [ -n "$rigWaited" ] && [ "$rigWaited" -lt 20 ] && printf inside || printf at-bound )" "inside"

echo "-- 7. a second close of a settled record says nothing and ends nothing --"
: > "$rigTmp/curl.log" ; rm -f "$rigTmp"/post.*
rigOut2="$( rigClose "$rigSpawned/$rigWaitChair/$rigWaitChair.spawn.md" magic-coordinator )"
rigAssert "the settled record keeps its status"         "$( rigHeader "$rigSpawned/$rigWaitChair/$rigWaitChair.spawn.md" status )" "spawn-succeeded"
rigAssert "the second close posts nothing"              "$( rigPosts )" "0"
rigAssert "and it says the record had settled"          "$( printf '%s' "$rigOut2" | LC_ALL=C grep -c 'is already settled as spawn-succeeded' )" "1"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ CLOSE OWNS RUNS CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'CLOSE_OWNS_RUNS: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
