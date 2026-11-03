#!/usr/bin/env bash
## What an idle communications reader costs, and what it must not pay (S5.6, S12.8). Held:
##   1. THE INSTRUMENT. A PATH shim records every external command started under it: five date
##      calls are five records, so a counter that cannot see a fork proves nothing.
##   2. ONE IDLE PASS. Over one live session with nothing to do, a pass forks at most one
##      process, counted as what a longer run adds to a shorter one.
##   3. CLOSED SESSIONS COST NOTHING. Six hundred closed session folders beside the live one add
##      no fork, the reader's list names the live session alone, and no thread of a closed
##      session is read.
##   4. THE LIST IS KEPT BY THE SESSIONS. A control thread writes its line when it starts and
##      takes it away when it ends.
##   5. THE PUSHER'S LINE. A post queued for the reader while its send succeeded says nothing
##      about a failure; a post that really failed and is posted after says exactly that, once.
## Offline: a Slack-shaped fake curl first on PATH, every workspace a folder of the rig's own, and
## every process this check starts is ended by it (S12.8).
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}/myx/myx.distro-agents"
rigTool="$rigHere/sh-scripts/DistroAgentsTools.fn.sh"
rigFixtures="$rigHere/sh-test/check-fixtures"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tooling is not at the origin: $rigTool"
. "$rigFixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionCommsIdleCostCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigStarted=""
trap 'rigProcSignalWithChildren KILL $rigStarted ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPass=$(( rigPass + 1 ))
	else
		rigFail=$(( rigFail + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigHits(){ ## file, pattern -- how many lines of it match; 0 where it is not there
	[ -f "$1" ] || { printf '0' ; return 0 ; }
	LC_ALL=C grep -c -e "$2" "$1" 2> /dev/null
}
rigCount(){ ## file -- its lines, 0 where it is not there
	[ -f "$1" ] || { printf '0' ; return 0 ; }
	LC_ALL=C wc -l < "$1" | LC_ALL=C tr -d ' '
}

## THE SHIM: every external command the reader can start, wrapped so the count sees it. The rig's
## fake curl answers in place of the real one, so no socket is opened by any of it.
mkdir -p "$rigTmp/shim" "$rigTmp/bin" "$rigTmp/skills/keeper-rig" || exit 1
printf 'keeper-rig\n' > "$rigTmp/skills/keeper-rig/keeper-rig.basic.md"
cp "$rigFixtures/session-comms.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing"
chmod +x "$rigTmp/bin/curl"
LC_ALL=C awk '{ n = split( $0, w, /[^A-Za-z0-9_.-]+/ ) ; for ( i = 1 ; i <= n ; i++ ) if ( w[i] != "" ) print w[i] }' \
	"$rigHere"/sh-lib/session/AgentsTools.SessionComms.include "$rigHere"/sh-lib/session/AgentsTools.InternSessionComms.include \
	"$rigHere"/sh-lib/session/AgentsTools.SessionControlStart.include "$rigHere"/sh-lib/comms/AgentsTools.CommsCache.include 2> /dev/null \
	| LC_ALL=C sort -u > "$rigTmp/words.txt" || exit 1
rigShimmed=0
while read -r rigWord ; do
	## curl is never shimmed: the rig's fake stands in its place, so no call of it can reach a socket.
	case "$rigWord" in ''|.*|-*|*[!a-z0-9_.-]*|bash|sh|env|curl) continue ;; esac
	[ "$( type -t "$rigWord" 2> /dev/null )" = "file" ] || continue
	rigReal=""
	for rigDir in /bin /usr/bin /usr/sbin /sbin /usr/local/bin ; do
		[ -x "$rigDir/$rigWord" ] && { rigReal="$rigDir/$rigWord" ; break ; }
	done
	[ -n "$rigReal" ] || continue
	printf '#!/bin/sh\n[ -z "${FORKLOG:-}" ] || printf "%%s\\n" "${0##*/}" >> "$FORKLOG"\nexec %s "$@"\n' "$rigReal" > "$rigTmp/shim/$rigWord"
	chmod +x "$rigTmp/shim/$rigWord"
	rigShimmed=$(( rigShimmed + 1 ))
done < "$rigTmp/words.txt"
[ "$rigShimmed" -ge 8 ] || rigRefuse "the shim took only $rigShimmed commands: no count it gave could be trusted"
## curl first, so no shim of it can reach the network: the fake runs where curl is asked for.
rigPath="$rigTmp/shim:$rigTmp/bin:$PATH"

echo "-- 1. the instrument --"
: > "$rigTmp/ctl.forks"
( export FORKLOG="$rigTmp/ctl.forks" PATH="$rigPath" ; rigN=0 ; while [ "$rigN" -lt 5 ] ; do date +%s > /dev/null ; rigN=$(( rigN + 1 )) ; done )
rigAssert "the shim counts the five date calls a rig makes"          "$( rigCount "$rigTmp/ctl.forks" )" 5

## THE SCENE: `<name> <closed sessions beside it>`; one live session, its thread, its record, its settings.
rigScene(){
	rigDir="$rigTmp/$1"
	rm -rf "$rigDir"
	rigWs="$rigDir/ws"
	rigRoot="1760000000.000001"
	rigSess="$rigWs/.local/agents/sessions/rig-live-$1"
	mkdir -p "$rigSess/control" "$rigWs/.local/agents/spawned/trk" "$rigWs/.local/agents/comms" \
		"$rigWs/.local/temp" "$rigWs/.local/.agents" "$rigDir/data"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_USER_TOKEN=rig-user-token-RIG\nSESSION_CONTROL_TICK_SECONDS=1\n' > "$rigWs/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-RIG\n' > "$rigWs/.local/.agents/keeper-rig.agent.env"
	printf 'CRIGSES01:%s\n' "$rigRoot" > "$rigSess/session.thread"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nowner: keeper-rig\nstatus: spawn-started\n---\n\n# s\n' \
		"${rigSess##*/}" "${rigSess##*/}" "$( hostname -s 2> /dev/null )" > "$rigWs/.local/agents/spawned/trk/${rigSess##*/}.spawn.md"
	: > "$rigSess/launch"
	sleep 600 > /dev/null 2>&1 &
	rigStandPid=$!
	rigProcNote "$rigStandPid" ; rigStarted="$rigStarted $rigStandPid"
	disown "$rigStandPid" 2> /dev/null || :
	bash -c ". '$rigHere/sh-lib/team-data/AgentsTools.Registries.include' ; printf '%s\n' $rigStandPid | AgentsToolsRegistryProcessesBegan" > "$rigSess/control/pid"
	## The list the control thread keeps, written here as that thread writes it: its own line for the live session.
	mkdir -p "$rigWs/.local/agents/comms"
	printf '%s CRIGSES01:%s\n' "${rigSess##*/}" "$rigRoot" > "$rigWs/.local/agents/comms/sessions"
	printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGOWNER","text":"RIG-ROOT"}],"has_more":false}\n' "$rigRoot" > "$rigDir/replies.CRIGSES01.$rigRoot.json"
	printf '{"ok":true,"messages":[],"has_more":false}\n' > "$rigDir/replies.CRIGSES02.1760000000.000002.json"
	## THE SESSION IS NOT DUE: its last look is now, with a gap long past the window this check counts, so no read
	## falls in that window and it holds idle passes alone.
	mkdir -p "$rigWs/.local/agents/comms/looked"
	printf '%s 3000\n' "$( date +%s )" > "$rigWs/.local/agents/comms/looked/${rigSess##*/}"
	: > "$rigDir/api.log"
	rigClosed=0
	while [ "$rigClosed" -lt "$2" ] ; do
		rigClosed=$(( rigClosed + 1 ))
		mkdir -p "$rigWs/.local/agents/sessions/rig-gone-$rigClosed/control"
		printf 'state: finished\nstate-at: 2026-11-01 00:00 +0000\nreason: none\n' > "$rigWs/.local/agents/sessions/rig-gone-$rigClosed/control/state"
		printf '999999 Sat_Oct_31_03:34:20_2026\n' > "$rigWs/.local/agents/sessions/rig-gone-$rigClosed/control/pid"
		printf 'CRIGSES02:1760000000.000002\n' > "$rigWs/.local/agents/sessions/rig-gone-$rigClosed/session.thread"
	done
}
rigRun(){ ## forks file, seconds, output base -- one run of the reader, ended by TERM
	: > "$1"
	( cd "$rigWs" && exec env -u MDAT_DATA_ROOT -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID -u MDAT_SESSION_THREAD -u MDAT_CONVERSATION_THREADS \
		-u MDAT_TEAM_MEMBER -u MDAT_SPAWN_AGENT -u MDAT_COMMS_READER -u MDAT_COMMS_IDLE_SECONDS \
		"PATH=$rigPath" "FORKLOG=$1" "RIG_SCENARIO=$rigDir" "MMDAPP=$rigWs" "MDAT_DATA_ROOT=$rigDir/data" "MDLT_ORIGIN=$MDLT_ORIGIN" \
		"MDAT_SKILLSET_ROOT=$rigTmp/skills" MDAT_WAIT_REMIND=off MDAT_WORKSPACE_MODE=team-rig \
		bash "$rigTool" --intern-session-comms --run ) > "$rigDir/$3.out" 2>&1 &
	rigReaderPid=$!
	rigProcNote "$rigReaderPid" ; rigStarted="$rigStarted $rigReaderPid"
	sleep "$2"
	rigProcSignal TERM "$rigReaderPid" ; sleep 0.6
}
rigSend(){ ## body -- one send of keeper-rig into the session thread, with rigSendEnv's own settings
	local rigBody="$1"
	printf '%s' "$rigBody" | ( cd "$rigWs" && env -u MDAT_DATA_ROOT -u MDAT_SESSION_THREAD -u MDAT_SPAWN_SESSION_ID \
		-u MDAT_TEAM_MEMBER -u MDAT_SPAWN_AGENT \
		"PATH=$rigPath" "RIG_SCENARIO=$rigDir" "MMDAPP=$rigWs" "MDLT_ORIGIN=$MDLT_ORIGIN" "MDAT_SKILLSET_ROOT=$rigTmp/skills" \
		"MDAT_SESSION_ID=${rigSess##*/}" MDAT_WAIT_REMIND=off ${rigSendEnv:-} \
		bash "$rigTool" --slack-send-message --team-member keeper-rig "CRIGSES01:$rigRoot" --from-stdin ) > "$rigDir/send.out" 2> "$rigDir/send.err"
}
rigPush(){ ## one push of every channel's cache outbox, as the reader makes it
	( cd "$rigWs" && env -u MDAT_DATA_ROOT -u MDAT_SESSION_THREAD -u MDAT_SPAWN_SESSION_ID \
		"PATH=$rigPath" "RIG_SCENARIO=$rigDir" "MMDAPP=$rigWs" "MDLT_ORIGIN=$MDLT_ORIGIN" "MDAT_SKILLSET_ROOT=$rigTmp/skills" \
		bash -c ". '$rigHere/sh-lib/session/AgentsTools.SessionComms.include' || exit 9 ; . '$rigHere/sh-lib/comms/AgentsTools.CommsCache.include' || exit 9 ; AgentsToolsCommsCachePushAll \"\$( date +%s )\"" ) > "$rigDir/push.out" 2>&1
}

echo "-- 2. one idle pass --"
rigScene pass 0
rigRun "$rigDir/f1" 6 short
rigRun "$rigDir/f2" 26 long
rigForks1="$( rigCount "$rigDir/f1" )" ; rigForks2="$( rigCount "$rigDir/f2" )"
rigOver=$(( rigForks2 - rigForks1 ))
rigAssert "the shim saw the reader's own processes"                  "$( [ "$rigForks1" -ge 5 ] && printf yes )" yes
[ "$rigOver" -le 20 ] || printf '  the words the longer run forked, by count:\n%s\n' "$( LC_ALL=C sort "$rigDir/f2" | LC_ALL=C uniq -c | LC_ALL=C sort -rn | head -8 )"
rigAssert "one idle pass forks at most one process, over 20 passes"  "$( [ "$rigOver" -le 20 ] && printf yes || printf '%s forks' "$rigOver" )" yes

echo "-- 3. closed sessions cost nothing --"
rigScene closed 600
rigRun "$rigDir/f1" 6 short
rigRun "$rigDir/f2" 26 long
rigClosedOver=$(( $( rigCount "$rigDir/f2" ) - $( rigCount "$rigDir/f1" ) ))
[ "$rigClosedOver" -le 20 ] || printf '  the words a run forked with the closed ones beside it:\n%s\n' "$( LC_ALL=C sort "$rigDir/f2" | LC_ALL=C uniq -c | LC_ALL=C sort -rn | head -8 )"
rigAssert "six hundred closed sessions add no fork to an idle pass" "$( [ "$rigClosedOver" -le 20 ] && printf yes || printf '%s forks' "$rigClosedOver" )" yes
rigAssert "the reader's list names the live session"                 "$( LC_ALL=C awk '{ print $1 }' "$rigWs/.local/agents/comms/sessions" 2> /dev/null | LC_ALL=C tr '\n' ' ' )" "${rigSess##*/} "
rigAssert "and no closed one"                                       "$( rigHits "$rigWs/.local/agents/comms/sessions" 'rig-gone' )" 0
rigAssert "no thread of a closed session is read"                     "$( LC_ALL=C awk '$2 == "conversations.replies" && $3 == "CRIGSES02" { c++ } END { print c + 0 }' "$rigDir/api.log" )" 0

echo "-- 4. the list is kept by the sessions --"
rigScene list 0
( cd "$rigWs" && exec env -u MDAT_DATA_ROOT -u MDAT_SPAWN_SESSION_ID -u MDAT_SESSION_ID -u MDAT_SESSION_THREAD -u MDAT_CONVERSATION_THREADS \
	-u MDAT_TEAM_MEMBER -u MDAT_SPAWN_AGENT -u MDAT_COMMS_READER \
	"PATH=$rigPath" "MMDAPP=$rigWs" "MDAT_DATA_ROOT=$rigDir/data" "MDLT_ORIGIN=$MDLT_ORIGIN" "MDAT_SKILLSET_ROOT=$rigTmp/skills" \
	MDAT_WORKSPACE_MODE=team-rig \
	bash "$rigTool" --intern-session-control --run --session-id "${rigSess##*/}" ) > "$rigDir/control.out" 2>&1 &
rigCtlPid=$!
rigProcNote "$rigCtlPid" ; rigStarted="$rigStarted $rigCtlPid"
disown "$rigCtlPid" 2> /dev/null || :
rm -f "$rigWs/.local/agents/comms/sessions"
rigWaited=0
while [ "$rigWaited" -lt 40 ] && [ -z "$( LC_ALL=C grep -c "^${rigSess##*/} " "$rigWs/.local/agents/comms/sessions" 2> /dev/null )" ] ; do sleep 0.25 ; rigWaited=$(( rigWaited + 1 )) ; done
rigAssert "a control thread that starts writes its line, so no walk is needed" "$( rigHits "$rigWs/.local/agents/comms/sessions" "^${rigSess##*/} " )" 1
rigProcSignal TERM "$rigCtlPid"
rigWaited=0
while [ "$rigWaited" -lt 60 ] && [ -s "$rigWs/.local/agents/comms/sessions" ] ; do sleep 0.25 ; rigWaited=$(( rigWaited + 1 )) ; done
rigAssert "and takes it away when it ends, so a closed session costs nothing" "$( rigHits "$rigWs/.local/agents/comms/sessions" "^${rigSess##*/} " )" 0

echo "-- 5. the pusher's line --"
rigScene push 0
## A reader that lives, so a send queues into the cache outbox instead of posting itself.
bash -c ". '$rigHere/sh-lib/team-data/AgentsTools.Registries.include' ; printf '%s\n' $rigStandPid | AgentsToolsRegistryProcessesBegan" > "$rigWs/.local/agents/comms/lock"
rigSendEnv="MDAT_SEND_ASYNC=true"
rigSend "RIG-QUEUED-BODY"
rigSendEnv=""
rigAssert "a post to a live session's thread is queued for the reader" "$( rigHits "$rigDir/send.err" 'queued as block' )" 1
rigPush
rigAssert "the pusher posted it"                                     "$( LC_ALL=C awk '$2 == "chat.postMessage" { c++ } END { print c + 0 }' "$rigDir/api.log" )" 1
rigAssert "and said nothing about a failure that never happened"      "$( rigHits "$rigWs/.local/agents/comms/log" 'could not be posted when it was sent' )" 0
## A post that really failed, waiting in a channel's outbox with its own reason: posted by the pusher, it says exactly that, once.
## The record is written as a failed send leaves it (AgentsToolsCommsCacheOutboxAppend), so this needs no five attempts of a real one.
rigScene pushfail 0
bash -c ". '$rigHere/sh-lib/session/AgentsTools.SessionComms.include' || exit 9 ; . '$rigHere/sh-lib/comms/AgentsTools.CommsCache.include' || exit 9 ; AgentsToolsCommsCacheOutboxAppend '$rigWs/.local/cache/comms/slack/slack-CRIGSES01-$rigRoot' '${rigSess##*/}' 7 keeper-rig bot chat.postMessage '{\"channel\":\"CRIGSES01\",\"text\":\"RIG-REAL-FAIL\"}' 'no ok:true after 5 attempts'" \
	|| rigRefuse "the rig could not write a failed post into a channel's outbox"
rigAssert "a post that really failed waits with its own reason"      "$( rigHits "$rigWs/.local/cache/comms/slack/slack-CRIGSES01-$rigRoot/outbox.messages.txt" 'no ok:true after 5 attempts' )" 1
rigPush
rigAssert "the pusher posted it"                                     "$( LC_ALL=C awk '$2 == "chat.postMessage" { c++ } END { print c + 0 }' "$rigDir/api.log" )" 1
rigAssert "and said it had failed, once"                             "$( rigHits "$rigWs/.local/agents/comms/log" 'could not be posted when it was sent' )" 1

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SESSION COMMS IDLE COST CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_COMMS_IDLE_COST: OK (%d assertions, offline)\n' "$rigPass"
exit 0
