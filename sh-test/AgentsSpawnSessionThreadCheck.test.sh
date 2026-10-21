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
## starts one as it always did. The line that says a member joined is addressed to the
## member whose session brought it in, and to nobody where there is none or it is the member
## itself: never to the member that joined. THE SPAWN RECORD NAMES THE MEMBER THAT MADE THE
## SPAWN CALL (`parent-member:`): the calling session's own, where its environment names one,
## else the one its caller says the call is made as (--calling-member, the harness Agent
## tool). A helper a native session with no record of its own brings in with the Agent tool
## hands back to that member. A fake console records the brief; the fake curl is the Slack
## send identity check's own. Offline by construction.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$rigHere/harness/AgentsUniversalHarness.sh"
## The name of the address field, read where it is held, so a rename is one line there.
rigReportsTo="$( LC_ALL=C sed -n 's/^agentsRunRouteField="\(.*\)"$/\1/p' "$rigHere/session/AgentsTools.SpawnSandbox.include" )"

## Refusing to report is this function's whole job: a rig that could not reach its
## subject must never reach its PASS lines, which read exactly like a result.
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}

[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"

## A spawn of this rig that is not waited for starts the control thread of its session, a detached process that
## outlives this check: the rig ends it, before its tree is removed (the guard is in AgentsSessionControlStartCheck).
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSpawnSessionThreadCheck )" || exit 1
## A filled sandbox input/ loses its write bits by contract.
trap 'chmod -R u+w -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin"

cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh"
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
## A member as the send shows it here, where no names registry holds a row for it: its member
## name, said once, with the default icon of its prefix group.
rigShown(){ ## member
	case "$1" in
		keeper-*) printf '🔏 *_%s_*' "$1" ;;
		*)        printf '🤖 *_%s_*' "$1" ;;
	esac
}
## The joined line of the last spawn, whole: who it is from, who it is for, and what it says.
rigJoined(){ ## member that joined, who the line is for as the header says it, what it was brought in for
	rigReplies "\"text\":\"$( rigShown "$1" ) → $2.\\n$1 joined: $3\""
}
## The spawn records of one coworking session, and one header of the newest spawn record.
rigRecordsOf(){ ## session id
	LC_ALL=C grep -l -x -F -- "session-id: $1" "$rigWs/.local/agents/spawned"/*/*.spawn.md 2> /dev/null | LC_ALL=C awk 'END { print NR + 0 ; }'
}
rigNewest(){ ## header
	local newestFile
	newestFile="$( ls -t "$rigWs/.local/agents/spawned"/*/*.spawn.md 2> /dev/null | head -1 )"
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
rigAssert "a bare command line: a run that starts its own session, and no parent session is recorded" "$( rigNewest start-context ):$( rigNewest parent-session-id )" "spawned:"
rigAssert "it reports to the person whose account started it at the console" "$( rigNewest "$rigReportsTo" )" "user-$( id -un )"
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
rigAssert "its record names the member that made the spawn call, the calling session's own" "$( rigNewest parent-member )" magic-coordinator
rigAssert "a member brought into its caller's own session is inline, and that session is its parent" "$( rigNewest start-context ):$( rigNewest parent-session-id )" "inline:rig-native-one"
rigAssert "it reports to that session, which needs no address written" "$( rigNewest "$rigReportsTo" ):$( rigNewest parent-spawn-id )" ":rig-native-one"
rigAssert "the line is addressed to the member whose session brought it in, not to itself" \
	"$( rigJoined keeper-myx "$( rigShown magic-coordinator )" 'change the loader code' ):$( rigJoined keeper-myx "$( rigShown keeper-myx )" 'change the loader code' )" "1:0"
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
rigAssert "it is inline too, with the same parent" "$( rigNewest start-context ):$( rigNewest parent-session-id )" "inline:rig-native-one"
rigSecondSpawn="$( rigNewest spawn-id )"
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
rigAssert "a caller that acts as no member, and none said: its record names none" "$( rigNewest parent-spawn-id ):$( rigNewest parent-member )" "rig-native-two:"
rigAssert "a caller that acts as no member: the line is addressed to nobody, and still posted" \
	"$( rigJoined keeper-myx '@here' 'look at the logs' ):$( rigJoined keeper-myx "$( rigShown keeper-myx )" 'look at the logs' )" "1:0"
## From inside a team session: the session it was handed, as before.
rigCaller=( MDAT_SPAWN_SESSION_ID=rig-run-inside MDAT_SESSION_ID=rig-team-session MDAT_SESSION_THREAD=CRIG00001:9.000009 MDAT_SPAWN_AGENT=keeper-myx )
rigOut="$( rigSpawn magic-tester --description "help with the samples" )"
rigAssert "a spawn made from inside a team session still joins that session, in its thread" \
	"$( rigRecordsOf rig-team-session ):$( rigNewest session-thread ):$( rigOpeners '🧵 Session ' ):$( rigReplies 'magic-tester joined: help with the samples' ):$( LC_ALL=C grep -c -F '"thread_ts":"9.000009"' "$rigTmp/bodies" )" "1:CRIG00001:9.000009:0:1:1"
rigAssert "it is joined, and its parent is the session it was spawned from, not the run that spawned it" "$( rigNewest start-context ):$( rigNewest parent-session-id ):$( rigNewest parent-spawn-id )" "joined:rig-team-session:rig-run-inside"
rigAssert "its line is addressed to the member of the session it was spawned from" \
	"$( rigJoined magic-tester "$( rigShown keeper-myx )" 'help with the samples' )" 1
rigOut="$( rigSpawn keeper-myx --description "a second run of its own" )"
rigAssert "a member that brings itself in: the line is addressed to nobody, never to itself" \
	"$( rigJoined keeper-myx '@here' 'a second run of its own' ):$( rigJoined keeper-myx "$( rigShown keeper-myx )" 'a second run of its own' )" "1:0"
rigCaller=( MDAT_SPAWN_SESSION_ID=rig-run-inside MDAT_SESSION_ID=rig-team-session MDAT_SESSION_THREAD=CRIG00001:9.000009 MDAT_SPAWN_AGENT=rig-no-such-member )
rigOut="$( rigSpawn magic-tester --description "one more check" )"
rigAssert "a caller the send cannot address: the line is addressed to nobody, and still posted" \
	"$( rigJoined magic-tester '@here' 'one more check' )" 1
## Asked for plainly: a session of its own, from a caller that has one.
rigCaller=( CLAUDE_CODE_SESSION_ID=rig-native-one MDAT_SPAWN_AGENT=magic-coordinator )
rigOut="$( rigSpawn keeper-myx --session-new --session-name-or-comment "a separate matter" )"
rigAssert "an explicit new session opens a thread of its own, the session's and no member's, under its own id" \
	"$( rigOpeners '"text":"🧵 Session *a separate matter*, started by magic-coordinator"' ):$( [ "$( rigNewest session-id )" = "$( rigNewest spawn-id )" ] && printf own || printf joined ):$( rigRecordsOf rig-native-one )" "1:own:2"
rigAssert "a session of its own is spawned, and the caller's session is its parent" "$( rigNewest start-context ):$( rigNewest parent-session-id )" "spawned:rig-native-one"
rigSubSession="$( rigNewest session-id )"
## A subsession of that one, made from inside it, and one more under that.
rigCaller=( MDAT_SPAWN_SESSION_ID="$rigSubSession" MDAT_SESSION_ID="$rigSubSession" MDAT_SPAWN_AGENT=keeper-myx )
rigOut="$( rigSpawn magic-tester --session-new )"
rigAssert "a subsession names the session it was made from as its parent" "$( rigNewest start-context ):$( rigNewest parent-session-id )" "spawned:$rigSubSession"
rigSubSubSession="$( rigNewest session-id )"
rigCaller=( MDAT_SPAWN_SESSION_ID="$rigSubSubSession" MDAT_SESSION_ID="$rigSubSubSession" MDAT_SPAWN_AGENT=magic-tester )
rigOut="$( rigSpawn keeper-myx --session-new )"
rigAssert "a subsession of a subsession carries its own parent the same way" "$( rigNewest start-context ):$( rigNewest parent-session-id )" "spawned:$rigSubSubSession"
## A caller whose environment names only its own run, which joined another session: its record names its session.
rigCaller=( MDAT_SPAWN_SESSION_ID="$rigSecondSpawn" MDAT_SPAWN_AGENT=magic-tester )
rigOut="$( rigSpawn keeper-myx --session-new )"
rigAssert "a caller that names only its own run: the session on its record is the parent, not its run id" "$( rigNewest start-context ):$( rigNewest parent-session-id ):$( rigNewest parent-spawn-id )" "spawned:rig-native-one:$rigSecondSpawn"
rigCaller=( CLAUDE_CODE_SESSION_ID=rig-native-one MDAT_SPAWN_AGENT=magic-coordinator )
rigOut="$( rigSpawn keeper-myx --session-new --session-id rig-native-one )"
rigAssert "a new session and a session to join, asked together, are refused and nothing is spawned" \
	"$( printf '%s\n' "$rigOut" | grep -c 'use only one of --session-id <session-id> | --session-new' ):$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=' )" "1:0"

echo "-- the spawn record says how the run was started, and which session started it --"
## Sent into another session by its id, from inside a team session.
rigCaller=( MDAT_SPAWN_SESSION_ID=rig-run-inside MDAT_SESSION_ID=rig-team-session MDAT_SESSION_THREAD=CRIG00001:9.000009 MDAT_SPAWN_AGENT=keeper-myx )
rigOut="$( rigSpawn magic-tester --session-id rig-native-one --description "sent into another session" )"
rigAssert "a member sent into another session by its id: joined, and the session that sent it is its parent" \
	"$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=true$' ):$( rigNewest session-id ):$( rigNewest start-context ):$( rigNewest parent-session-id )" "1:rig-native-one:joined:rig-team-session"
## A restart says both off the record of the run it replaces, and they stand as said.
rigCaller=()
rigOut="$( rigSpawn keeper-myx --session-id rig-native-one --start-context inline --parent-session rig-native-one )"
rigAssert "a restart's start context and parent session are recorded as its caller says them" \
	"$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=true$' ):$( rigNewest start-context ):$( rigNewest parent-session-id )" "1:inline:rig-native-one"
## A member with no session of its own makes the call: it is the one the run reports to.
rigCaller=( MDAT_SPAWN_AGENT=magic-tester )
rigOut="$( rigSpawn keeper-myx )"
rigAssert "a calling member with no session: no parent session, and the run reports to that member" "$( rigNewest parent-session-id ):$( rigNewest "$rigReportsTo" )" ":magic-tester"
rigCaller=()
rigOut="$( rigSpawn keeper-myx --session-id rig-native-one --start-context inline --parent-session rig-native-one --reports-to rig-native-one:magic-coordinator )"
rigAssert "a restart's address is recorded as its caller says it" "$( rigNewest "$rigReportsTo" )" "rig-native-one:magic-coordinator"
## A restart of a run that had no parent session and named no address: none, whoever restarts it.
rigCaller=( MDAT_SPAWN_SESSION_ID=rig-run-inside MDAT_SESSION_ID=rig-team-session MDAT_SESSION_THREAD=CRIG00001:9.000009 MDAT_SPAWN_AGENT=keeper-myx )
rigOut="$( rigSpawn magic-tester --parent-none )"
rigAssert "a restart said to have no parent: no parent session and no address, though its caller has both" \
	"$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=true$' ):$( rigNewest parent-session-id ):$( rigNewest "$rigReportsTo" )" "1::"
rigOut="$( rigSpawn magic-tester --parent-none --parent-session rig-team-session )"
rigAssert "no parent and a parent, said together, are refused, and nothing is spawned" \
	"$( printf '%s\n' "$rigOut" | grep -c 'ERROR: use only one of --parent-session <session-id> | --parent-none' ):$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=' )" "1:0"
rigCaller=()
## A run that reports to no one: recorded so, and told in its brief that it ends when its work is done.
rigOut="$( rigSpawn keeper-myx --reports-to none )"
rigAssert "reports to no one: recorded, and its brief says it ends on its report, not on a dismissal" \
	"$( rigNewest "$rigReportsTo" ):$( grep -c 'You report to no one' "$rigTmp/brief" ):$( grep -c 'You never end on your own' "$rigTmp/brief" )" "none:1:0"
rigOut="$( rigSpawn keeper-myx --review-by 'rig:one:two' )"
rigAssert "a reviewer that is none of its forms is refused, and nothing is spawned" \
	"$( printf '%s\n' "$rigOut" | grep -c 'ERROR: --review-by requires a reviewer' ):$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=' )" "1:0"
rigOut="$( rigSpawn keeper-myx --reports-to 'rig:one:two' )"
rigAssert "an address that is none of its forms is refused, and nothing is spawned" \
	"$( printf '%s\n' "$rigOut" | grep -c 'ERROR: --reports-to requires' ):$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=' )" "1:0"
rigRecordsBefore="$( ls "$rigWs/.local/agents/spawned"/*/*.spawn.md 2> /dev/null | LC_ALL=C awk 'END { print NR + 0 ; }' )"
rigOut="$( rigSpawn keeper-myx --start-context sideways )"
rigAssert "a start context that is none of the three is refused, and nothing is spawned" \
	"$( printf '%s\n' "$rigOut" | grep -c 'ERROR: --start-context requires spawned, inline or joined' ):$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=' )" "1:0"
rigOut="$( rigSpawn keeper-myx --parent-session '../rig-native-one' )"
rigAssert "a parent session that is no bare name is refused, and nothing is spawned" \
	"$( printf '%s\n' "$rigOut" | grep -c 'ASSERT: --parent-session must be a bare name' ):$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=' ):$(( $( ls "$rigWs/.local/agents/spawned"/*/*.spawn.md 2> /dev/null | LC_ALL=C awk 'END { print NR + 0 ; }' ) - rigRecordsBefore ))" "1:0:0"

echo "-- the spawn record names the member that made the spawn call --"
## Said by the caller of the proxy, for a calling session whose environment names no member.
rigCaller=( CLAUDE_CODE_SESSION_ID=rig-native-four )
rigOut="$( rigSpawn keeper-myx --calling-member magic-tester --description "said by its caller" )"
rigAssert "a native session that names no member, the calling member said: the record names it, and the joined line is addressed to it" \
	"$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=true$' ):$( rigNewest parent-spawn-id ):$( rigNewest parent-member ):$( rigJoined keeper-myx "$( rigShown magic-tester )" 'said by its caller' )" "1:rig-native-four:magic-tester:1"
rigCaller=( CLAUDE_CODE_SESSION_ID=rig-native-four MDAT_SPAWN_AGENT=magic-coordinator )
rigOut="$( rigSpawn keeper-myx --calling-member magic-tester --description "its own member stands" )"
rigAssert "a calling session whose environment names its member: that one stands, whatever is said" \
	"$( rigNewest parent-member ):$( rigJoined keeper-myx "$( rigShown magic-coordinator )" 'its own member stands' )" "magic-coordinator:1"
rigCaller=( CLAUDE_CODE_SESSION_ID=rig-native-four )
rigRecordsBefore="$( ls "$rigWs/.local/agents/spawned"/*/*.spawn.md 2> /dev/null | LC_ALL=C awk 'END { print NR + 0 ; }' )"
rigOut="$( rigSpawn keeper-myx --calling-member '../magic-tester' )"
rigAssert "a calling member that is no bare name is refused, and nothing is spawned" \
	"$( printf '%s\n' "$rigOut" | grep -c 'ASSERT: --calling-member must be a bare name' ):$( printf '%s\n' "$rigOut" | grep -c '^LAUNCHED=' ):$(( $( ls "$rigWs/.local/agents/spawned"/*/*.spawn.md 2> /dev/null | LC_ALL=C awk 'END { print NR + 0 ; }' ) - rigRecordsBefore ))" "1:0:0"

echo "-- a helper a native session brings in with the Agent tool hands back to the member that call was made as --"
## The native session: a session of its own, no record of its own, and no member in its
## environment. Each call it makes is served as a member, and the Agent tool says which.
mkdir -p "$rigTmp/data/board/running"
: > "$rigTmp/calls" ; : > "$rigTmp/bodies" ; : > "$rigTmp/brief"
## Nobody waits on this spawn, so its proxy runs on behind the call and asks a run that ended
## with no handback for one: the console keeps the first context it is given, never that retry.
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records the first context.' \
	'rigContext="$( cat )"' \
	'[ -s "$RIG_SCENARIO/brief" ] || printf "%s\n" "$rigContext" > "$RIG_SCENARIO/brief"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
rigServed(){ ## tool, arguments JSON, session words (NAME=value)...
	local servedTool="$1" servedArgs="$2" ; shift 2
	( cd "$rigWs" && printf '%s' "$servedArgs" | env -u MDAT_SPAWN_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u MDAT_SESSION_ID -u MDAT_SESSION_THREAD -u MDAT_SESSION_WORKSPACE -u MDAT_SPAWN_AGENT \
		"$@" RIG_SCENARIO="$rigTmp" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigTmp/data" \
		bash "$rigHarness" --intern-tool "$servedTool" --access-read-root "$rigTmp" 2>&1 ) || :
}
rigOut="$( rigServed Agent '{"agent":"keeper-myx","prompt":"RIG-AGENT-BRIEF","description":"hand it back"}' CLAUDE_CODE_SESSION_ID=rig-native-six )"
rigAgentPid="$( printf '%s\n' "$rigOut" | LC_ALL=C sed -n 's/^PID=\([0-9][0-9]*\)$/\1/p' | head -1 )"
rigWaited=0
while ! grep -q 'RIG-AGENT-BRIEF' "$rigTmp/brief" 2> /dev/null && [ "$rigWaited" -lt 90 ] ; do sleep 1 ; rigWaited=$(( rigWaited + 1 )) ; done
grep -q 'RIG-AGENT-BRIEF' "$rigTmp/brief" || rigRefuse "the Agent tool's spawn never reached the console, so nothing below would be measured: $( printf '%s\n' "$rigOut" | grep -m1 ERROR )"
rigAgentRecord="$( LC_ALL=C grep -l -x -F 'parent-spawn-id: rig-native-six' "$rigWs/.local/agents/spawned"/*/*.spawn.md 2> /dev/null | head -1 )"
[ -n "$rigAgentRecord" ] || rigRefuse "the spawn left no record that names the native session as its parent"
rigAgentField(){ ## header
	LC_ALL=C sed -n "s/^$1: //p" "$rigAgentRecord" | head -1
}
rigAssert "the parent session has no record of its own" "$( ls "$rigWs/.local/agents/spawned"/*/rig-native-six.spawn.md 2> /dev/null | LC_ALL=C awk 'END { print NR + 0 ; }' )" 0
rigAssert "the helper's record names the member the Agent call was made as" "$( rigAgentField owner ):$( rigAgentField parent-member )" "keeper-myx:magic-coordinator"
rigAssert "its joined line is addressed to that member" "$( rigJoined keeper-myx "$( rigShown magic-coordinator )" 'hand it back' )" 1
## The helper's own handback, with no addressee, into its session thread.
rigOut="$( rigServed SubagentHandback '{"to":"session-current","outcome":"RIG-HANDBACK-OUTCOME"}' MDAT_SPAWN_SESSION_ID="$( rigAgentField spawn-id )" MDAT_SPAWN_AGENT=keeper-myx MDAT_SESSION_ID=rig-native-six MDAT_SESSION_THREAD="$( rigAgentField session-thread )" )"
rigAssert "its handback is addressed to the member that spawned it" \
	"$( LC_ALL=C grep -F 'RIG-HANDBACK-OUTCOME' "$rigTmp/bodies" | LC_ALL=C grep -c -F "\"text\":\"$( rigShown keeper-myx ) → $( rigShown magic-coordinator ).\\n# 🏁 Handback" ):$( LC_ALL=C grep -c -F 'RIG-HANDBACK-OUTCOME' "$rigTmp/bodies" )" "1:1"
## The spawn runs on behind the Agent call: it is left to end, its close steps too, before
## the rig's tree goes.
rigWaited=0
while { [ "$( rigAgentField status )" = "spawn-started" ] || { [ -n "$rigAgentPid" ] && kill -0 "$rigAgentPid" 2> /dev/null ; } ; } && [ "$rigWaited" -lt 120 ] ; do sleep 1 ; rigWaited=$(( rigWaited + 1 )) ; done
rigCaller=()

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SPAWN SESSION THREAD CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_SESSION_THREAD: OK (%d assertions, offline)\n' "$rigPasses"