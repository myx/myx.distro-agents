#!/usr/bin/env bash
## Behavioural check: a dismissal ends the run, whatever its model then tries. A spawned
## session whose Wait returned DISMISSED keeps that in its own store. From then on its Wait
## does not wait: it returns DISMISSED at once, each time, with the line that says to hand
## back and end, and reads nothing. Its handback no longer says to wait: it says to end. And
## once that handback is given the harness ends the session itself: its own model loop stops
## at the end of the round, and the run of another CLI, which a served call cannot stop from
## inside, is given a grace to end by itself and none where it waits again, and is then sent
## TERM. Only the run is signalled, known by its own word on its own command line: a process
## that only quotes the id lives on. A session that was not dismissed waits, hands back and
## lives exactly as before, and so does one that was never spawned.
## Offline: a Slack-shaped fake curl answers the served calls, another replays canned model
## rounds for the loop, the skillset is a fixture, and the runs are stand-in processes of
## this rig, named by an id no other process on the machine carries.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigMember="rig-helper"
rigLead="rig-lead"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "the harness is not at the origin this workspace resolves: $rigHarness"
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsHarnessDismissedEndCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigRunPids=""
trap 'rigProcSignal KILL $rigRunPids ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/served" "$rigTmp/loop" "$rigTmp/tmp" "$rigTmp/home" "$rigTmp/skills"
for rigName in "$rigMember" "$rigLead" magic-coordinator ; do
	mkdir -p "$rigTmp/skills/$rigName"
	printf -- '---\nmaintainers: rig\n---\n%s\n' "$rigName" > "$rigTmp/skills/$rigName/$rigName.basic.md"
done
cp "$rigTest/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTmp/served/curl" || rigRefuse "the fake curl fixture of the served calls is missing from the package"
cp "$rigTest/check-fixtures/harness-arm-gate.curl.stub.sh" "$rigTmp/loop/curl" || rigRefuse "the fake curl fixture of the model loop is missing from the package"
## A model call from a served tool would reach one of these first, and it only logs.
for rigModel in claude codex ; do
	printf '#!/bin/sh\necho "%s $*" >> "%s/model-calls"\nexit 1\n' "$rigModel" "$rigTmp" > "$rigTmp/served/$rigModel"
done
chmod +x "$rigTmp/served/"* "$rigTmp/loop/"*
rigPathBase="/usr/bin:/bin"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigYes(){ "$@" > /dev/null 2>&1 && printf yes || printf no ; }

## ---------------------------------------------------------------- the served calls
## A session of another CLI: each tool call is one served call of this harness, and its run
## is a stand-in process that carries the session's id as its own --session-id word.
rigThread="CSESS001:1700000002.000202"
rigDismissal="1700000200.000001"
rigNo=0
rigDir="" rigSpawn="" rigRunPid="" rigQuotePid=""
rigScene(){ ## scenario name, who the DISMISSED in the thread is addressed to (empty: the thread holds none)
	rigNo=$(( rigNo + 1 ))
	rigDir="$rigTmp/$1"
	rigSpawn="rig-dismissed-$$-$rigNo-$RANDOM"
	mkdir -p "$rigDir/ws/.local/.agents" "$rigDir/ws/.local/agents/pending" "$rigDir/ws/.local/agents/spawned/rig-folder" "$rigDir/data"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigDir/ws/.local/.agents/magic-team.agent.env"
	printf -- '---\nspawn-id: %s\nparent-spawn-id: none\nowner: %s\nstatus: spawn-started\n---\n' "$rigSpawn" "$rigMember" > "$rigDir/ws/.local/agents/spawned/rig-folder/$rigSpawn.md"
	: > "$rigDir/curl.log"
	printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGSELF1","text":"RIG-OPENER"}%s],"has_more":false}\n' "${rigThread#*:}" \
		"${2:+,{\"ts\":\"$rigDismissal\",\"user\":\"URIGBOT01\",\"text\":\"*_${rigLead}_* @$rigLead → *_${2}_* @$2.\\nDISMISSED\",\"metadata\":{\"event_type\":\"magic_sender\",\"event_payload\":{\"sender\":\"$rigLead\"}}}}" \
		> "$rigDir/replies.${rigThread#*:}.json"
	## The run, and beside it a process that only quotes the id: the first is the session, the second is not.
	## Neither is a job of this shell, so the shell says nothing when one is ended.
	perl -e 'sleep 600' -- --session-id "$rigSpawn" > /dev/null 2>&1 &
	rigRunPid=$! ; rigRunPids="$rigRunPids $rigRunPid" ; rigProcNote "$rigRunPid" ; disown "$rigRunPid" 2> /dev/null || :
	perl -e 'sleep 600' -- --note "$rigSpawn" > /dev/null 2>&1 &
	rigQuotePid=$! ; rigRunPids="$rigRunPids $rigQuotePid" ; rigProcNote "$rigQuotePid" ; disown "$rigQuotePid" 2> /dev/null || :
}
rigAlive(){ ## pid
	kill -0 "$1" 2> /dev/null && printf alive || printf gone
}
rigGoneWithin(){ ## pid, seconds -- waits for the process to end
	local goneLeft="$2"
	while kill -0 "$1" 2> /dev/null && [ "$goneLeft" -gt 0 ] ; do sleep 1 ; goneLeft=$(( goneLeft - 1 )) ; done
	rigAlive "$1"
}
rigSeconds=0
rigCall(){ ## tool, arguments JSON, further environment words (NAME=value)... -- the spawned session's own served call
	local callTool="$1" callArgs="$2" callStart ; shift 2
	callStart="$( date +%s )"
	( cd "$rigDir/ws" && printf '%s' "$callArgs" | env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u ANTHROPIC_API_KEY -u OPENAI_API_KEY -u MDAT_SESSION_ID -u MDAT_SPAWN_CALLER_WAITS \
		PATH="$rigTmp/served:$rigPathBase" TMPDIR="$rigTmp/tmp" RIG_SCENARIO="$rigDir" RIG_CURL_LOG="$rigDir/curl.log" MMDAPP="$rigDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigDir/data" \
		MDAT_SESSION_THREAD="$rigThread" MDAT_SPAWN_SESSION_ID="$rigSpawn" MDAT_SPAWN_AGENT="$rigMember" MDAT_SKILLSET_ROOT="$rigTmp/skills" "$@" \
		bash "$rigHarness" --intern-tool "$callTool" > "$rigDir/tool.out" 2> "$rigDir/tool.err" )
	rigSeconds=$(( $( date +%s ) - callStart ))
}
rigFirst(){ LC_ALL=C sed -n '1p' "$rigDir/tool.out" ; }
rigLast(){ LC_ALL=C grep . "$rigDir/tool.out" | LC_ALL=C tail -n 1 ; }
rigHas(){ ## fixed text -- how many lines of the result hold it
	LC_ALL=C grep -c -F -- "$1" "$rigDir/tool.out"
}
rigReads(){ ## how many times the thread was read from Slack
	LC_ALL=C grep -c -x 'conversations.replies' "$rigDir/curl.log"
}
rigSaid(){ ## file, fixed text -- how many of its lines hold it, 0 where there is no such file
	local saidCount
	saidCount="$( LC_ALL=C grep -c -F -- "$2" "$1" 2> /dev/null )" || :
	printf '%s' "${saidCount:-0}"
}
rigEndedLine='the tooling ends this run: it was dismissed, its handback is given, and it did not end by itself'
rigMark(){ ## what the session's store keeps of its dismissal
	local markDir="$rigDir/ws/.local/agents/sessions/$rigSpawn"
	printf '%s|%s' "$( cat "$markDir/dismissed" 2> /dev/null )" "$( [ -e "$markDir/dismissed.handback" ] && printf handback || printf none )"
}
rigWait='{"sources":"slack:session-current","since_utime":"1700000100","timeout":3}'
rigNextBack='NEXT: you are dismissed -- give your handback if you have not, then end your run'
rigNextEnd='NEXT: you are dismissed and your handback is given -- end your run now, and call nothing more'
rigNextWait='NEXT: you are not done -- call Wait with no sources (your session thread) and obey what arrives, until it returns DISMISSED'

echo "-- a session that is dismissed: its Wait says so, and the session keeps it --"
rigScene dismissed "$rigMember"
[ "$( PATH="$rigTmp/served:$rigPathBase" command -v curl )" = "$rigTmp/served/curl" ] || rigRefuse "the fake curl is not first on the rig's PATH"
[ "$( rigAlive "$rigRunPid" )$( rigAlive "$rigQuotePid" )" = "alivealive" ] || rigRefuse "the rig's stand-in processes did not start, so no ending could be measured"
rigCall Wait "$rigWait"
[ "$( rigFirst )" = "WAIT-RESULT: DISMISSED" ] || rigRefuse "the Wait never returned the dismissal, so nothing below would be measured: $( rigFirst ) $( head -2 "$rigDir/tool.err" | LC_ALL=C tr '\n' ' ' )"
rigAssert "the Wait that reads the dismissal: DISMISSED, who sent it, and to hand back and end" "$( rigHas "WAIT-DISMISSED-BY: $rigDismissal | URIGBOT01" ):$( rigLast )" "1:$rigNextBack"
rigAssert "the session keeps who dismissed it, and no handback yet" "$( rigMark )" "$rigDismissal | URIGBOT01|none"
rigReadsBefore="$( rigReads )"

echo "-- once dismissed, its next Wait does not wait: DISMISSED at once, each time --"
rigCall Wait '{"timeout":60}'
rigAssert "a bare Wait of a minute returns at once"              "$( [ "$rigSeconds" -lt 15 ] && printf at-once || printf "after ${rigSeconds}s" ):$( rigFirst )" "at-once:WAIT-RESULT: DISMISSED"
rigAssert "naming the same dismissal, and saying to hand back and end" "$( rigHas "WAIT-DISMISSED-BY: $rigDismissal | URIGBOT01" ):$( rigLast )" "1:$rigNextBack"
rigCall Wait '{"sources":"slack:session-current","since_utime":"1700000300","timeout":60,"mode":"continue"}'
rigAssert "and again, whatever sources and mode it names"        "$( [ "$rigSeconds" -lt 15 ] && printf at-once || printf "after ${rigSeconds}s" ):$( rigFirst ):$( rigLast )" "at-once:WAIT-RESULT: DISMISSED:$rigNextBack"
rigAssert "nothing was read from Slack for either"               "$(( $( rigReads ) - rigReadsBefore ))" 0
rigAssert "with no handback given, the run is left alone"        "$( rigAlive "$rigRunPid" )" alive

echo "-- the handback that follows a dismissal says to end, never to wait --"
rigCall SubagentHandback '{"to":"session-current","outcome":"RIG-OUTCOME"}' MDAT_DISMISSED_END_GRACE=600
rigAssert "it is posted"                                         "$( rigFirst | LC_ALL=C cut -c1-8 ):$( ls "$rigDir"/post.* 2> /dev/null | LC_ALL=C awk 'END { print NR + 0 ; }' )" "Sent to :1"
rigAssert "its last line says to end the run and call nothing more" "$( rigLast ):$( rigHas 'call Wait' )" "$rigNextEnd:0"
rigAssert "the session keeps that its handback is given"         "$( rigMark )" "$rigDismissal | URIGBOT01|handback"
sleep 3
rigAssert "the run is given its grace to end by itself"          "$( rigAlive "$rigRunPid" )" alive

echo "-- then a Wait call: it returns at once, and the session ends --"
rigCall Wait '{"timeout":60}' MDAT_DISMISSED_END_GRACE=600
rigAssert "the Wait returns at once: DISMISSED, the handback given, end now" "$( [ "$rigSeconds" -lt 15 ] && printf at-once || printf "after ${rigSeconds}s" ):$( rigFirst ):$( rigLast )" "at-once:WAIT-RESULT: DISMISSED:$rigNextEnd"
rigAssert "and the run is ended by the tooling"                  "$( rigGoneWithin "$rigRunPid" 20 )" gone
rigAssert "a process that only quotes the session's id is not the run, and lives" "$( rigAlive "$rigQuotePid" )" alive
rigAssert "the session's log says who ended the run, and why"    "$( rigSaid "$rigDir/ws/.local/agents/sessions/$rigSpawn/session.log" "$rigEndedLine" )" 1

echo "-- the handback alone ends the session, with no call after it --"
rigScene handbackEnds "$rigMember"
rigCall Wait "$rigWait"
rigCall SubagentHandback '{"to":"session-current","outcome":"RIG-OUTCOME"}' MDAT_DISMISSED_END_GRACE=2
rigAssert "dismissed, then the handback: its last line says to end" "$( rigLast )" "$rigNextEnd"
rigAssert "the grace over, the run is ended by the tooling"      "$( rigGoneWithin "$rigRunPid" 20 ):$( rigAlive "$rigQuotePid" )" "gone:alive"

echo "-- a run that ends by itself within the grace is not signalled --"
rigScene endsItself "$rigMember"
rigCall Wait "$rigWait"
rigCall SubagentHandback '{"to":"session-current","outcome":"RIG-OUTCOME"}' MDAT_DISMISSED_END_GRACE=3
rigProcSignal TERM "$rigRunPid"
sleep 7
rigAssert "nothing is said of ending a run that is gone, and no other process is touched" \
	"$( rigSaid "$rigDir/ws/.local/agents/sessions/$rigSpawn/session.log" "$rigEndedLine" ):$( rigAlive "$rigQuotePid" )" "0:alive"

echo "-- a run with no session word is ended too, by the process its record names, while another process quotes its id --"
rigScene noWord "$rigMember"
## No process runs as this session by its own word: the stand-in that did is ended, and the run
## is a process that carries no id at all, which the spawn's record names as the one its launch
## started. The process that only quotes the id is still there, and is still no run.
rigProcSignal KILL "$rigRunPid"
rigGoneWithin "$rigRunPid" 5 > /dev/null
perl -e 'sleep 600' > /dev/null 2>&1 &
rigRecordedPid=$! ; rigRunPids="$rigRunPids $rigRecordedPid" ; rigProcNote "$rigRecordedPid" ; disown "$rigRecordedPid" 2> /dev/null || :
rigRecordedStart="$( LC_ALL=C ps -o lstart= -p "$rigRecordedPid" 2> /dev/null | LC_ALL=C awk 'NF { $1 = $1 ; gsub( / /, "_" ) ; print ; exit ; }' )"
[ -n "$rigRecordedStart" ] || rigRefuse "the stand-in of the run with no session word did not start, so its ending could not be measured"
printf -- '---\nspawn-id: %s\nparent-spawn-id: none\nowner: %s\nstatus: spawn-started\nrun-process: %s %s\n---\n' "$rigSpawn" "$rigMember" "$rigRecordedPid" "$rigRecordedStart" > "$rigDir/ws/.local/agents/spawned/rig-folder/$rigSpawn.md"
rigCall Wait "$rigWait"
rigCall SubagentHandback '{"to":"session-current","outcome":"RIG-OUTCOME"}' MDAT_DISMISSED_END_GRACE=2
rigAssert "dismissed, then the handback: its last line says to end" "$( rigLast )" "$rigNextEnd"
rigAssert "the grace over, the process its record names is ended by the tooling, and the one that only quotes the id lives" "$( rigGoneWithin "$rigRecordedPid" 20 ):$( rigAlive "$rigQuotePid" )" "gone:alive"
rigAssert "and the session's log says who ended the run, and why" "$( rigSaid "$rigDir/ws/.local/agents/sessions/$rigSpawn/session.log" "$rigEndedLine" )" 1

echo "-- a session that was not dismissed waits, hands back and lives exactly as before --"
rigScene notDismissed ""
rigCall Wait "$rigWait"
rigAssert "its Wait waits out its bound: TIMEOUT"                "$( [ "$rigSeconds" -ge 3 ] && printf waited || printf "after ${rigSeconds}s" ):$( rigFirst | LC_ALL=C cut -c1-20 )" "waited:WAIT-RESULT: TIMEOUT"
rigAssert "it keeps no mark"                                     "$( rigMark )" "|none"
rigCall SubagentHandback '{"to":"session-current","outcome":"RIG-OUTCOME"}' MDAT_DISMISSED_END_GRACE=1
rigAssert "its handback says to go on waiting"                   "$( rigFirst | LC_ALL=C cut -c1-8 ):$( rigLast )" "Sent to :$rigNextWait"
rigCall Wait "$rigWait" MDAT_DISMISSED_END_GRACE=1
rigAssert "and its next Wait waits again"                        "$( [ "$rigSeconds" -ge 3 ] && printf waited || printf "after ${rigSeconds}s" ):$( rigFirst | LC_ALL=C cut -c1-20 )" "waited:WAIT-RESULT: TIMEOUT"
sleep 4
rigAssert "its run lives on, and it still keeps no mark"         "$( rigAlive "$rigRunPid" ):$( rigMark )" "alive:|none"

echo "-- a DISMISSED addressed to another member dismisses no one here --"
rigScene otherMember "$rigLead"
rigCall Wait "$rigWait"
rigAssert "the Wait returns it as a message, not as this session's dismissal" "$( rigFirst ):$( rigMark )" "WAIT-RESULT: RECEIVED:|none"
rigCall Wait '{"sources":"slack:session-current","since_utime":"1700000300","timeout":3}'
rigAssert "and the next Wait waits"                              "$( [ "$rigSeconds" -ge 3 ] && printf waited || printf "after ${rigSeconds}s" ):$( rigFirst | LC_ALL=C cut -c1-20 )" "waited:WAIT-RESULT: TIMEOUT"

echo "-- a session that was never spawned keeps no mark: a DISMISSED by its member's name changes nothing in it --"
rigScene neverSpawned magic-coordinator
rigNative(){ ## arguments JSON -- a served Wait of a session with no spawn id: the root's, served as magic-coordinator
	local nativeStart ; nativeStart="$( date +%s )"
	( cd "$rigDir/ws" && printf '%s' "$1" | env -u MDAT_DATA_ROOT -u CLAUDE_CODE_ENTRYPOINT -u ANTHROPIC_API_KEY -u OPENAI_API_KEY -u MDAT_SESSION_ID -u MDAT_SESSION_THREAD -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_CALLER_WAITS \
		PATH="$rigTmp/served:$rigPathBase" TMPDIR="$rigTmp/tmp" RIG_SCENARIO="$rigDir" RIG_CURL_LOG="$rigDir/curl.log" MMDAPP="$rigDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigDir/data" \
		CLAUDE_CODE_SESSION_ID="rig-native-$$" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		bash "$rigHarness" --intern-tool Wait > "$rigDir/tool.out" 2> "$rigDir/tool.err" )
	rigSeconds=$(( $( date +%s ) - nativeStart ))
}
rigNative "{\"sources\":\"slack:$rigThread:conversation\",\"since_utime\":\"1700000100\",\"timeout\":3}"
rigAssert "its Wait returns the DISMISSED it read, as before"    "$( rigFirst )" "WAIT-RESULT: DISMISSED"
rigAssert "nothing is kept of it in any session's store"         "$( ls "$rigDir/ws/.local/agents/sessions"/*/dismissed 2> /dev/null | LC_ALL=C awk 'END { print NR + 0 ; }' )" 0
rigNative "{\"sources\":\"slack:$rigThread:conversation\",\"since_utime\":\"1700000300\",\"timeout\":3}"
rigAssert "and its next Wait waits"                              "$( [ "$rigSeconds" -ge 3 ] && printf waited || printf "after ${rigSeconds}s" ):$( rigFirst | LC_ALL=C cut -c1-20 )" "waited:WAIT-RESULT: TIMEOUT"
[ ! -s "$rigTmp/model-calls" ] || rigRefuse "a model CLI was called by a served tool: $( head -1 "$rigTmp/model-calls" )"

## ---------------------------------------------------------------- the harness's own model loop
## The harness is the CLI here: a fake curl replays canned model rounds, one tool call a round.
rigRounds=0
rigLoopScene(){ ## scenario name
	rigDir="$rigTmp/$1"
	rigSpawn="rig-dismissed-$$-loop-$RANDOM"
	mkdir -p "$rigDir/ws/.local/.agents" "$rigDir/ws/OUT" "$rigDir/sandbox/input" "$rigDir/sandbox/output"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-not-a-token\n' > "$rigDir/ws/.local/.agents/magic-team.agent.env"
	printf '0' > "$rigDir/round"
	: > "$rigDir/curl.log"
	rigRounds=0
}
rigRound(){ ## tool name, arguments JSON -- the next canned round: one tool call
	rigRounds=$(( rigRounds + 1 ))
	printf 'data: {"choices":[{"index":0,"delta":{"tool_calls":[{"index":0,"id":"rig-call-%s","type":"function","function":{"name":"%s","arguments":"%s"}}]},"finish_reason":null}]}\n' \
		"$rigRounds" "$1" "$( printf '%s' "$2" | sed 's/\\/\\\\/g; s/"/\\"/g' )" > "$rigDir/res.$rigRounds"
	printf 'data: {"choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\n' >> "$rigDir/res.$rigRounds"
	printf 'data: [DONE]\n' >> "$rigDir/res.$rigRounds"
}
rigRoundEnd(){ ## -- the next canned round: plain text, which ends the run
	rigRounds=$(( rigRounds + 1 ))
	printf 'data: {"choices":[{"index":0,"delta":{"content":"RIG-DONE"},"finish_reason":"stop"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\ndata: [DONE]\n' > "$rigDir/res.$rigRounds"
}
rigLoopRc=0
rigLoop(){ ## -- the model loop of the spawned session, guarded
	rigLoopRc=0
	env -i HOME="$rigTmp/home" PATH="$rigTmp/loop:$rigPathBase" MMDAPP="$rigDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SPAWN_SESSION_ID="$rigSpawn" MDAT_SPAWN_AGENT="$rigMember" MDAT_SPAWN_SANDBOX_ROOT="$rigDir/sandbox" \
		RIG_SCENARIO="$rigDir" RIG_CURL_LOG="$rigDir/curl.log" RIG_TMP="$rigTmp" RIG_HARNESS="$rigHarness" RIG_MEMBER="$rigMember" \
		HARNESS_PROVIDER_NAME="dismissed-end rig" HARNESS_SELF_NAME="AgentsHarnessDismissedEndCheck.test.sh" \
		HARNESS_ENDPOINT="https://harness-dismissed-end-check.invalid/v1/chat/completions" HARNESS_HOST="harness-dismissed-end-check.invalid" \
		HARNESS_WIRE="OpenAiChat" HARNESS_CREDENTIAL_NAMES="none" HARNESS_MODEL_LIGHT="rig-light" HARNESS_MODEL_MAIN="rig-main" \
		HARNESS_TOKEN_LIGHT="rig-not-a-credential" HARNESS_TOKEN_MAIN="rig-not-a-credential" MDAT_HARNESS_CONTEXT_TOKENS=0 MDAT_HARNESS_MAX_RESTARTS=1 \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac
			case "$( command -v curl )" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: curl is not the rig fake" >&2 ; exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_HARNESS" --access-read-root "$MMDAPP" --access-read-root "$MDAT_SKILLSET_ROOT" --access-write-root "$MMDAPP/OUT" --agent "$RIG_MEMBER" RIG-TASK
		' > "$rigDir/out" 2> "$rigDir/err" || rigLoopRc=$?
	[ "$( cat "$rigDir/round" )" != 0 ] || rigRefuse "the harness made no model request: $( tail -3 "$rigDir/err" | LC_ALL=C tr '\n' ' ' )"
}
## The tool result in the request for round N+1, which answers round N's call: its first 400 bytes.
rigResult(){ ## round whose call it answers
	LC_ALL=C awk '
		{
			restText = $0 ;
			while ( ( roleAt = index( restText, "\"role\":\"tool\"" ) ) > 0 ) {
				restText = substr( restText, roleAt + 13 ) ;
				contentAt = index( restText, "\"content\":\"" ) ;
				if ( contentAt > 0 ) { lastText = substr( restText, contentAt + 11, 400 ) ; }
			}
		}
		END { print lastText ; }
	' "$rigDir/req.$(( $1 + 1 ))" 2> /dev/null
}

echo "-- the harness's own loop: dismissed, then the handback, and the run ends there --"
rigLoopScene loopDismissed
mkdir -p "$rigDir/ws/.local/agents/sessions/$rigSpawn"
printf '%s | URIGBOT01\n' "$rigDismissal" > "$rigDir/ws/.local/agents/sessions/$rigSpawn/dismissed"
rigRound Wait '{"timeout":60}'
rigRound SubagentHandback '{"to":"CRIG00001","outcome":"RIG-OUTCOME"}'
rigRound Wait '{"timeout":60}'
rigRound Wait '{"timeout":60}'
rigLoop
rigAssert "its Wait returned the dismissal at once, to the model" "$( rigResult 1 | LC_ALL=C cut -c1-22 )" "WAIT-RESULT: DISMISSED"
rigAssert "after the handback no further round is asked of the model: the Wait it would call is never made" "$( cat "$rigDir/round" ):$( rigYes test -e "$rigDir/req.3" )" "2:no"
rigAssert "the run ends itself, cleanly, and says why"           "$rigLoopRc:$( rigSaid "$rigDir/err" 'dismissed, and the handback is given: the run ends here' )" "0:1"
rigAssert "the handback was posted"                              "$( rigSaid "$rigDir/slack.bodies" 'RIG-OUTCOME' )" 1

echo "-- control: a loop that was not dismissed goes on after its handback, as before --"
rigLoopScene loopNotDismissed
rigRound SubagentHandback '{"to":"CRIG00001","outcome":"RIG-OUTCOME"}'
rigRoundEnd
rigLoop
rigAssert "the model is asked again after the handback, and told to go on waiting" "$( cat "$rigDir/round" ):$( rigSaid "$rigDir/req.2" 'NEXT: you are not done -- call Wait with no sources' )" "2:1"
rigAssert "the run ends on the model's own last word"            "$rigLoopRc:$( rigSaid "$rigDir/err" 'the run ends here' ):$( rigSaid "$rigDir/out" 'RIG-DONE' )" "0:0:1"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ DISMISSED END CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  warn: a session that was dismissed can wait again or outlive its handback, or one that" >&2
	echo "        was not dismissed no longer waits and lives as before" >&2
	echo "  fix:  repair the harness -- never the assertion" >&2
	exit 1
fi
printf 'HARNESS_DISMISSED_END: OK (%d assertions, offline, no model)\n' "$rigPassCount"
