#!/usr/bin/env bash
## Behavioural check on the session thread --intern-op-agent-spawn-proxy opens, run
## rather than read, against a scenario workspace built here. Holds: a spawn posts its
## opening to magic-team once and hands `session_thread_ts: <channel>:<ts>` to the
## session in its brief; a failed post still launches the spawn, says so on stderr,
## and hands over none. THE SESSION THAT SPAWNS IS THE COWORKING SESSION: two members a
## native caller brings in share that caller's one session thread and one tracking
## thread, the first opening it, each in a sandbox of its own; another caller has another
## session; a spawn made from inside a team session joins that session; --session-new
## opens one of the spawn's own; a caller with no session at all, a bare command line,
## starts one as it always did. A fake console records the brief; the fake curl is the
## Slack send identity check's own. Offline by construction.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

## Refusing to report is this function's whole job: a rig that could not reach its
## subject must never reach its PASS lines, which read exactly like a result.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"

rigTmp="$( mktemp -d -t "AgentsSpawnSessionThreadCheck-XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin"

cp "$rigTest/check-fixtures/slack-send-identity-check.curl.test.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigTest/check-fixtures/slack-send-identity-check.curl.test.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

## The console the proxy launches: it records the brief and the launch, and runs no
## model. It names --cli-configured and MDAT_SPAWN_LAUNCH_MARKER, which the proxy
## greps for before it launches anything.
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records the brief.' \
	'cat > "$RIG_SCENARIO/brief"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"

## One spawn; prints the proxy's own output, stdout and stderr together. The caller is a bare
## command line, with no session of any kind, unless rigCaller gives it one (NAME=value words).
rigCaller=()
rigSpawn(){ ## member (default keeper-myx), extra proxy arguments...
	local spawnMember="${1:-keeper-myx}"
	[ $# -eq 0 ] || shift
	: > "$rigTmp/calls"
	: > "$rigTmp/bodies"
	: > "$rigTmp/brief"
	( cd "$rigWs" && env -u MDAT_DATA_ROOT -u MDAT_SPAWN_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u MDAT_SESSION_ID -u MDAT_SESSION_THREAD -u MDAT_SESSION_WORKSPACE -u MDAT_SPAWN_AGENT \
		"${rigCaller[@]+"${rigCaller[@]}"}" RIG_SCENARIO="$rigTmp" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		bash "$rigTool" --intern-op-agent-spawn-proxy "$spawnMember" "$@" --dispatch-doc:none --wait --context rig-session-thread <<< "RIG-BRIEF-MARKER" 2>&1 ) || :
}
## Posts of the last spawn: those that open a thread, and those that are replies in one.
rigOpeners(){ ## fixed text
	LC_ALL=C grep -F -- "$1" "$rigTmp/bodies" | LC_ALL=C grep -c -v -F '"thread_ts"' || :
}
rigReplies(){ ## fixed text
	LC_ALL=C grep -F -- "$1" "$rigTmp/bodies" | LC_ALL=C grep -c -F '"thread_ts"' || :
}
## The spawn records of one coworking session, and one header of the newest spawn record.
rigRecordsOf(){ ## session id
	LC_ALL=C grep -l -x -F -- "session-id: $1" "$rigWs/.local/agents/spawned"/*/*.md 2> /dev/null | LC_ALL=C awk 'END { print NR + 0 ; }'
}
rigNewest(){ ## header
	local newestFile
	newestFile="$( ls -t "$rigWs/.local/agents/spawned"/*/*.md 2> /dev/null | head -1 )"
	[ -n "$newestFile" ] || return 0
	LC_ALL=C sed -n "s/^$1: //p" "$newestFile" | head -1
}

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1"
		rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
		rigFails=$(( rigFails + 1 ))
	fi
}

## The post succeeds.
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
rigOut="$( rigSpawn )"
## The subject has to be reachable before anything is asserted about it.
grep -q 'RIG-BRIEF-MARKER' "$rigTmp/brief" || rigRefuse "the fake console never received the brief, so nothing below would be measured: $( printf '%s\n' "$rigOut" | grep 'ERROR' | head -1 )"

rigAssert "the spawn launched" "$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=true$' )" 1
rigAssert "the opening is posted once, under the bot token" \
	"$( LC_ALL=C awk '$1 == "chat.postMessage" { print $2 }' "$rigTmp/calls" )" rig-bot-token-TEAM
rigAssert "the opening is the session's own post, seeded by the tooling: no author line, no addressee, the session by its id where it has no name" \
	"$( grep -c '→' "$rigTmp/bodies" ) $( rigOpeners "\"text\":\"🧵 Session *$( rigNewest session-id )*\"" ) $( LC_ALL=C grep -c -F '"sender":"magic-team","tracking":"session-root"' "$rigTmp/bodies" )" "0 1 1"
rigAssert "the brief hands over session_thread_ts as <channel>:<ts>" \
	"$( grep '^session_thread_ts: ' "$rigTmp/brief" )" "session_thread_ts: DRIG00001:1.000001"

## The post fails: magic-team names no channel.
printf 'SLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
rigOut="$( rigSpawn )"
rigAssert "a failed post still launches the spawn" "$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=true$' )" 1
rigAssert "a failed post posts nothing" "$( grep -c '^chat.postMessage ' "$rigTmp/calls" )" 0
rigAssert "a failed post is reported" "$( printf '%s\n' "$rigOut" | grep -c 'session thread not opened' )" 1
rigAssert "a failed post hands over no thread" \
	"$( grep -c '^session_thread_ts: none' "$rigTmp/brief" )" 1

echo "-- the session that spawns is the coworking session --"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_WORKSPACE_DOMAIN=rig.slack.com\n' > "$rigWs/.local/.agents/magic-team.agent.env"
## A native caller: a session of its own, never spawned through the proxy, acting as a member.
rigCaller=( CLAUDE_CODE_SESSION_ID=rig-native-one MDAT_SPAWN_AGENT=magic-coordinator )
rigOut="$( rigSpawn keeper-myx --description "change the loader code" --session-name-or-comment "rework the vars loader" )"
rigAssert "the first member a native caller brings in: launched, in the caller's own session" \
	"$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=true$' ):$( rigRecordsOf rig-native-one )" "1:1"
rigAssert "it opens the session thread, naming who started the session and the session's name" \
	"$( rigOpeners '"text":"🧵 Session *rework the vars loader*, started by magic-coordinator"' )" 1
rigAssert "and says in it that it joined, with what it was brought in for" \
	"$( rigReplies 'keeper-myx joined: change the loader code' )" 1
rigThreadOne="$( cat "$rigWs/.local/agents/sessions/rig-native-one/session.thread" 2> /dev/null )"
rigTrackOne="$( cat "$rigWs/.local/agents/sessions/rig-native-one/event-track.thread" 2> /dev/null )"
rigAssert "the session's thread and its tracking-thread are recorded under the caller's session id" \
	"$( [ -n "$rigThreadOne" ] && printf thread || printf none ):$( [ -n "$rigTrackOne" ] && printf track || printf none )" "thread:track"
rigAssert "the session's box in the tracking-thread links to the session thread's root in the team's conversation" \
	"$( LC_ALL=C grep -c -F "<https://rig.slack.com/archives/${rigThreadOne%%:*}/p$( printf '%s' "${rigThreadOne#*:}" | tr -d . )|session thread in magic-team>" "$rigTmp/bodies" )" 1
rigFirstSpawn="$( rigNewest spawn-id )"
rigOut="$( rigSpawn magic-tester --description "check it against the samples" --session-name-or-comment "a second name" )"
rigAssert "the second member the same caller brings in joins that session" \
	"$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=true$' ):$( rigRecordsOf rig-native-one )" "1:2"
rigAssert "it opens no thread: its entry is a reply in the one the first opened, with its own description" \
	"$( rigOpeners '🧵 Session ' ):$( rigReplies 'magic-tester joined: check it against the samples' )" "0:1"
rigAssert "both hold the same session thread, and the same tracking-thread" \
	"$( cat "$rigWs/.local/agents/sessions/rig-native-one/session.thread" 2> /dev/null ):$( cat "$rigWs/.local/agents/sessions/rig-native-one/event-track.thread" 2> /dev/null ):$( rigNewest session-thread ):$( rigNewest agent-log-thread )" \
	"$rigThreadOne:$rigTrackOne:$rigThreadOne:$rigTrackOne"
rigAssert "each keeps a sandbox of its own, named by its own spawn id: a run's input and output are not shared" \
	"$( ls -d "$rigWs/.local/agents/spawned"/*/ 2> /dev/null | LC_ALL=C grep -c -e "/$rigFirstSpawn/\$" -e "/$( rigNewest spawn-id )/\$" ):$( [ -e "$rigWs/.local/agents/spawned/rig-native-one" ] && printf shared || printf none )" "2:none"
rigAssert "and its own run id, never the session's, as its spawn id" \
	"$( [ "$( rigNewest spawn-id )" != "rig-native-one" ] && [ "$( rigNewest spawn-id )" != "$rigFirstSpawn" ] && printf own || printf shared )" own
## Another caller: another session.
rigCaller=( CLAUDE_CODE_SESSION_ID=rig-native-two )
rigOut="$( rigSpawn keeper-myx --description "look at the logs" )"
rigAssert "a member another caller brings in gets that caller's session, with a thread of its own, the session by its id where it has no name and no known starter" \
	"$( rigRecordsOf rig-native-two ):$( rigRecordsOf rig-native-one ):$( rigOpeners '"text":"🧵 Session *rig-native-two*"' ):$( rigReplies 'keeper-myx joined: look at the logs' )" "1:2:1:1"
## From inside a team session: the session it was handed, as before.
rigCaller=( MDAT_SPAWN_SESSION_ID=rig-run-inside MDAT_SESSION_ID=rig-team-session MDAT_SESSION_THREAD=CRIG00001:9.000009 MDAT_SPAWN_AGENT=keeper-myx )
rigOut="$( rigSpawn magic-tester --description "help with the samples" )"
rigAssert "a spawn made from inside a team session still joins that session, in its thread" \
	"$( rigRecordsOf rig-team-session ):$( rigNewest session-thread ):$( rigOpeners '🧵 Session ' ):$( rigReplies 'magic-tester joined: help with the samples' ):$( LC_ALL=C grep -c -F '"thread_ts":"9.000009"' "$rigTmp/bodies" )" "1:CRIG00001:9.000009:0:1:1"
## Asked for plainly: a session of its own, from a caller that has one.
rigCaller=( CLAUDE_CODE_SESSION_ID=rig-native-one MDAT_SPAWN_AGENT=magic-coordinator )
rigOut="$( rigSpawn keeper-myx --session-new --session-name-or-comment "a separate matter" )"
rigAssert "an explicit new session opens a thread of its own, the session's and no member's, under its own id" \
	"$( rigOpeners '"text":"🧵 Session *a separate matter*, started by magic-coordinator"' ):$( [ "$( rigNewest session-id )" = "$( rigNewest spawn-id )" ] && printf own || printf joined ):$( rigRecordsOf rig-native-one )" "1:own:2"
rigOut="$( rigSpawn keeper-myx --session-new --session-id rig-native-one )"
rigAssert "a new session and a session to join, asked together, are refused and nothing is spawned" \
	"$( printf '%s\n' "$rigOut" | grep -c 'use only one of --session-id <session-id> | --session-new' ):$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=' )" "1:0"
rigCaller=()

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SPAWN SESSION THREAD CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_SESSION_THREAD: OK (%d assertions, offline)\n' "$rigPasses"