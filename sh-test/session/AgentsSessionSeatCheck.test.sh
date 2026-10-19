#!/usr/bin/env bash
## Behavioural check on the seat (F6.9 of the refactorings epic, "The seat, in detail"): a member is never active
## twice at the same time in one session. The seat is taken atomically, by a file in the session's folder, at a run's
## first read of or post to the session; the first run to take it holds it, and start times play no part. It is
## released when its holder ends, and the next live run of that member takes it at its next read or post. A restart,
## known by `restarted-from: <spawn-id>` on its record, takes the seat over from the run it replaces. A second start of
## the same member by the spawn proxy is refused, naming the run that holds the seat; a run the proxy did not start
## carries no such field and waits without the seat. A run without the seat stays alive: its Wait delivers nothing from
## the session and returns TIMEOUT as usual, a DISMISSED addressed to it still arrives, and its SendMessage to the
## session is not posted and returns a plain refusal naming the run that holds the seat. Seen live on 2026-10-18: two
## runs each of magic-coordinator and magic-librarian answered in one session, while the others missed messages.
## Held, through the served calls each run makes (Wait, SendMessage), never through a function of the tooling:
##   1. two runs of magic-librarian: the first to read reads the post; the second's Wait delivers nothing and times out
##   2. a founding and a joined magic-coordinator: the founder, reading first, holds the seat; the joined one is silent
##   3. start times play no part: of two runs, the one started later but reading first holds the seat
##   4. a second run's send to the session is not posted, and is refused naming the holder; the holder's is posted
##   5. the run without the seat lives on, its record stays open, and no model is asked
##   6. once the holder has ended, the other run reads and posts
##   7. a restart (restarted-from) reads in place of the run it replaces, which lives on and reads nothing
##   8. a DISMISSED addressed to a run without the seat still arrives
##   9. control: the seat is per member, another member's run reads beside them
##   9b. a run's first post to the session takes the seat, as a read does
##   10. the spawn proxy refuses a second start of a member whose seat a live run holds, and starts a restart of it
## The record fields are F6.8's: session-id the team session, spawn-id the run, parent-spawn-id the run that started
## it, start-context, reports-to.
## Red before F6.9: there is no seat, so every run of a member reads and answers (1-4 and 7 fail).
## Offline: a Slack-shaped fake curl answers the served calls, a model call would reach a stand-in that only logs,
## and every run is a stand-in process of this rig carrying its own spawn id, which no other process carries.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/AgentsUniversalHarness.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHarness" ] || rigRefuse "the harness is not at the origin this workspace resolves: $rigHarness"
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$rigTest/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsSessionSeatCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigRunPids=""
## A spawn of this rig (section 10) that is not waited for starts the control thread of its session, a detached
## process that outlives this check: the rig ends it, before its tree is removed (AgentsSessionControlStartCheck).
. "$rigTest/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
trap 'rigProcSignal KILL $rigRunPids ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSpawned="$rigWs/.local/agents/spawned"
mkdir -p "$rigTmp/served" "$rigTmp/tmp" "$rigTmp/skills" "$rigTmp/data" "$rigWs/.local/.agents" "$rigWs/.local/agents/pending" "$rigSpawned"
for rigName in magic-coordinator magic-librarian keeper-myx magic-tester ; do
	mkdir -p "$rigTmp/skills/$rigName"
	printf -- '---\nmaintainers: rig\n---\n%s\n' "$rigName" > "$rigTmp/skills/$rigName/$rigName.basic.md"
done
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
cp "$rigTest/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTmp/served/curl" || rigRefuse "the fake curl fixture of the served calls is missing from the package"
## A model call from a served tool would reach one of these first, and it only logs.
for rigModel in claude codex ; do
	printf '#!/bin/sh\necho "%s $*" >> "%s/model-calls"\nexit 1\n' "$rigModel" "$rigTmp" > "$rigTmp/served/$rigModel"
done
chmod +x "$rigTmp/served/"*
rigHost="$( hostname -s 2> /dev/null )" || rigHost="unknown"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## ---------------------------------------------------------------- sessions and their runs
rigTag="${rigTmp##*.}"
rigPost="Could the librarian check the README of the board, please?"
## A session's thread: its opener, then one post of a person after every Wait's since, then what a scene adds.
rigThreadOf(){ ## session
	printf 'CSEAT0001:1700000002.0002%02d' "$( printf '%s' "$1" | LC_ALL=C cksum | LC_ALL=C awk '{ print $1 % 100 }' )"
}
rigSession(){ ## session, extra messages JSON (each led by a comma) or empty
	local sessionThread
	sessionThread="$( rigThreadOf "$1" )"
	mkdir -p "$rigSpawned/$1"
	printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGBOT01","text":"session opened"},{"ts":"1700000300.000001","user":"URIGOWNER","text":"%s"}%s],"has_more":false}\n' \
		"${sessionThread#*:}" "$rigPost" "${2:-}" > "$rigTmp/replies.${sessionThread#*:}.json"
}
rigRunNo=0
rigRun(){ ## variable to set, session, member, start-context, parent-spawn-id, extra record lines -- a run: its record and its live process
	local runId
	rigRunNo=$(( rigRunNo + 1 ))
	runId="rig-seat-run-$rigTag-$rigRunNo-$RANDOM"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: %s\nstart-context: %s\nreports-to: magic-coordinator\ntracking-name: %s\nhost: %s\nowner: %s\nstatus: spawn-started\nstarted-at: 2026-10-18 10:%02d +0000\nsession-thread: %s\n%s---\n' \
		"$2" "$runId" "$5" "$4" "$2" "$rigHost" "$3" "$rigRunNo" "$( rigThreadOf "$2" )" "${6:-}" > "$rigSpawned/$2/$runId.md"
	perl -e 'sleep 600' -- --session-id "$runId" > /dev/null 2>&1 &
	eval "${1}Pid=\$!"
	rigRunPids="$rigRunPids $!" ; rigProcNote "$!" ; disown "$!" 2> /dev/null || :
	eval "$1=\$runId"
	eval "${1}Session=\$2"
}
rigEnd(){ ## pid -- the run ends, as a run that ended by itself
	rigProcSignal KILL "$1"
	sleep 1
}
rigAlive(){ ## pid
	kill -0 "$1" 2> /dev/null && printf alive || printf gone
}

## One served call of a run, as its CLI makes it: its own spawn id, member, session and thread.
rigCall(){ ## run id, member, session, tool, arguments JSON -- output in $rigTmp/<run>.<tool>.out
	local callOut="$rigTmp/$1.$4.out"
	( cd "$rigWs" && printf '%s' "$5" | env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u ANTHROPIC_API_KEY -u OPENAI_API_KEY -u MDAT_SPAWN_CALLER_WAITS \
		PATH="$rigTmp/served:/usr/bin:/bin" TMPDIR="$rigTmp/tmp" RIG_SCENARIO="$rigTmp" RIG_CURL_LOG="$rigTmp/curl.log" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigTmp/data" \
		MDAT_SESSION_ID="$3" MDAT_SESSION_THREAD="$( rigThreadOf "$3" )" MDAT_SPAWN_SESSION_ID="$1" MDAT_SPAWN_AGENT="$2" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		bash "$rigHarness" --intern-tool "$4" > "$callOut" 2> "$callOut.err" )
}
rigWaitArgs='{"sources":"slack:session-current","since_utime":"1700000100","timeout":3}'
rigReads(){ ## run id, member, session -- whether its Wait delivered the post: read, or not-read
	rigCall "$1" "$2" "$3" Wait "$rigWaitArgs"
	LC_ALL=C grep -q -F -- "$rigPost" "$rigTmp/$1.Wait.out" && printf read || printf not-read
}
rigFirst(){ ## run id, tool -- the first line of that run's last call of that tool
	LC_ALL=C sed -n '1p' "$rigTmp/$1.$2.out" 2> /dev/null
}
rigSends(){ ## run id, member, session, words -- how many posts hold the words, once the run sent them to its session
	rm -f "$rigTmp"/post.* "$rigTmp/posts"
	rigCall "$1" "$2" "$3" SendMessage "{\"to\":\"session-current\",\"message\":\"$4\"}"
	cat "$rigTmp"/post.* 2> /dev/null | LC_ALL=C grep -c -F -- "$4" || :
}
rigSaid(){ ## run id, tool, fixed text -- how many lines of that run's last call of that tool hold it
	LC_ALL=C grep -c -F -- "$3" "$rigTmp/$1.$2.out" 2> /dev/null || :
}

## Reached, or nothing below means anything: a lone run of a member reads the post and posts its answer.
rigS="rig-seat-a-$rigTag"
rigSession "$rigS" ""
rigRun rigSolo "$rigS" keeper-myx spawned none ""
[ "$( rigReads "$rigSolo" keeper-myx "$rigS" )" = read ] || rigRefuse "a lone run's Wait never delivered the thread's post, so nothing below would be measured: $( rigFirst "$rigSolo" Wait ) $( head -2 "$rigTmp/$rigSolo.Wait.out.err" | LC_ALL=C tr '\n' ' ' )"
[ "$( rigSends "$rigSolo" keeper-myx "$rigS" 'The lone run answers here.' )" -ge 1 ] 2> /dev/null || rigRefuse "a lone run's send never reached the thread, so nothing below would be measured: $( head -3 "$rigTmp/$rigSolo.SendMessage.out" | LC_ALL=C tr '\n' ' ' )"
rigEnd "$rigSoloPid"

echo "-- 1. two runs of magic-librarian in one session: only the first to read reads the thread --"
rigRun rigCoord "$rigS" magic-coordinator spawned none ""
rigRun rigLib1 "$rigS" magic-librarian joined "$rigCoord" ""
rigRun rigLib2 "$rigS" magic-librarian joined "$rigCoord" ""
rigAssert "the first librarian run to read takes the seat, and reads the post" "$( rigReads "$rigLib1" magic-librarian "$rigS" )" read
rigAssert "the second librarian run does not read it"                     "$( rigReads "$rigLib2" magic-librarian "$rigS" )" not-read
rigAssert "its Wait times out as usual"                                   "$( rigFirst "$rigLib2" Wait | LC_ALL=C cut -c1-20 )" "WAIT-RESULT: TIMEOUT"

echo "-- 2. a founding and a joined coordinator: the founder holds the seat, the joined one is silent --"
rigRun rigCoord2 "$rigS" magic-coordinator joined "$rigCoord" ""
rigAssert "the founding coordinator, reading first, reads the post"       "$( rigReads "$rigCoord" magic-coordinator "$rigS" )" read
rigAssert "the joined coordinator does not"                               "$( rigReads "$rigCoord2" magic-coordinator "$rigS" )" not-read
rigAssert "its Wait times out as usual"                                   "$( rigFirst "$rigCoord2" Wait | LC_ALL=C cut -c1-20 )" "WAIT-RESULT: TIMEOUT"

echo "-- 3. start times play no part: the run started later, reading first, holds the seat --"
rigRun rigTesterEarly "$rigS" magic-tester joined "$rigCoord" ""
rigRun rigTesterLate "$rigS" magic-tester joined "$rigCoord" ""
rigAssert "the tester run started later reads first, and reads the post"  "$( rigReads "$rigTesterLate" magic-tester "$rigS" )" read
rigAssert "the one started earlier does not"                              "$( rigReads "$rigTesterEarly" magic-tester "$rigS" )" not-read

echo "-- 4. only the seat holder answers in the session --"
rigAssert "the second librarian run's send is not posted"                 "$( rigSends "$rigLib2" magic-librarian "$rigS" 'The second run would answer here.' )" 0
rigAssert "and is refused, naming the run that holds the seat"            "$( rigSaid "$rigLib2" SendMessage "$rigLib1" | LC_ALL=C awk '{ print ( $1 >= 1 ) ? "named" : "not-named" }' )" named
rigAssert "the joined coordinator's send is not posted either"            "$( rigSends "$rigCoord2" magic-coordinator "$rigS" 'The second coordinator would answer here.' )" 0
rigAssert "and is refused, naming the founder"                            "$( rigSaid "$rigCoord2" SendMessage "$rigCoord" | LC_ALL=C awk '{ print ( $1 >= 1 ) ? "named" : "not-named" }' )" named
rigAssert "control: the seat holder's send is posted"                     "$( rigSends "$rigLib1" magic-librarian "$rigS" 'The first run answers here.' )" 1

echo "-- 5. the run without the seat stays alive: nothing ends it --"
rigAssert "the second librarian run lives on"                             "$( rigAlive "$rigLib2Pid" )" alive
rigAssert "the joined coordinator lives on"                               "$( rigAlive "$rigCoord2Pid" )" alive
rigAssert "neither record is closed"                                      "$( LC_ALL=C grep -h '^status: ' "$rigSpawned/$rigS/$rigLib2.md" "$rigSpawned/$rigS/$rigCoord2.md" | LC_ALL=C tr '\n' '|' )" "status: spawn-started|status: spawn-started|"
rigAssert "and no model was asked anything by a served call"              "$( [ -s "$rigTmp/model-calls" ] && printf asked || printf none )" none

echo "-- 6. once the holder has ended, the other run reads and posts --"
rigEnd "$rigLib1Pid"
rigAssert "the second librarian run reads the post now"                   "$( rigReads "$rigLib2" magic-librarian "$rigS" )" read
rigAssert "and its send is posted"                                        "$( rigSends "$rigLib2" magic-librarian "$rigS" 'The second run answers now.' )" 1

echo "-- 7. a restart takes the seat over from the run it replaces, which lives on --"
rigRun rigKeep1 "$rigS" keeper-myx joined "$rigCoord" ""
rigAssert "the keeper run reads first, and holds the seat"                "$( rigReads "$rigKeep1" keeper-myx "$rigS" )" read
rigRun rigKeep2 "$rigS" keeper-myx joined "$rigCoord" "restarted-from: $rigKeep1
"
rigAssert "its restart reads the post"                                    "$( rigReads "$rigKeep2" keeper-myx "$rigS" )" read
rigAssert "the run it replaces reads nothing now"                         "$( rigReads "$rigKeep1" keeper-myx "$rigS" )" not-read
rigAssert "and lives on"                                                  "$( rigAlive "$rigKeep1Pid" )" alive

echo "-- 8. a DISMISSED addressed to a run without the seat still arrives --"
rigD="rig-seat-b-$rigTag"
rigSession "$rigD" ",{\"ts\":\"1700000400.000001\",\"user\":\"URIGBOT01\",\"text\":\"*_magic-coordinator_* @magic-coordinator → *_magic-librarian_* @magic-librarian.\\nDISMISSED\",\"metadata\":{\"event_type\":\"magic_sender\",\"event_payload\":{\"sender\":\"magic-coordinator\"}}}"
rigRun rigCoordD "$rigD" magic-coordinator spawned none ""
rigRun rigLibD1 "$rigD" magic-librarian joined "$rigCoordD" ""
rigRun rigLibD2 "$rigD" magic-librarian joined "$rigCoordD" ""
rigReads "$rigLibD1" magic-librarian "$rigD" > /dev/null
rigCall "$rigLibD2" magic-librarian "$rigD" Wait "$rigWaitArgs"
rigAssert "the run without the seat gets its DISMISSED"                   "$( rigFirst "$rigLibD2" Wait )" "WAIT-RESULT: DISMISSED"
rigAssert "and nothing of the session's other posts"                      "$( rigSaid "$rigLibD2" Wait "$rigPost" )" 0

echo "-- 9. control: the seat is per member --"
rigAssert "the founding coordinator reads the post beside the restarted keeper" "$( rigReads "$rigCoord" magic-coordinator "$rigS" )" read

## Added by the builder of F6.9: a post takes the seat as a read does, and a start by the spawn
## proxy refuses a second run of a member whose seat a live run holds, unless it restarts that run.
echo "-- 9b. a run's first post to the session takes the seat, as a read does --"
rigP="rig-seat-c-$rigTag"
rigSession "$rigP" ""
rigRun rigPostFirst "$rigP" magic-tester joined none ""
rigRun rigPostSecond "$rigP" magic-tester joined none ""
rigAssert "the run that posts first is posted"                          "$( rigSends "$rigPostFirst" magic-tester "$rigP" 'The first run posts first.' )" 1
rigAssert "the other run, reading after it, does not read"              "$( rigReads "$rigPostSecond" magic-tester "$rigP" )" not-read

echo "-- 10. the spawn proxy starts no second run of a member whose seat a live run holds --"
## The console the proxy launches: it takes the brief and says it launched, and runs no model.
printf '%s\n' '#!/usr/bin/env bash' '## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and runs no model.' 'cat > /dev/null' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"
rigProxy(){ ## output file, member, extra proxy arguments...
	local proxyOut="$1" proxyMember="$2"
	shift 2
	( cd "$rigWs" && printf 'RIG-BRIEF\n' | env -u MDAT_DATA_ROOT -u MDAT_SPAWN_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u MDAT_SESSION_ID -u MDAT_SESSION_THREAD -u MDAT_SPAWN_AGENT \
		PATH="$rigTmp/served:/usr/bin:/bin" TMPDIR="$rigTmp/tmp" RIG_SCENARIO="$rigTmp" RIG_CURL_LOG="$rigTmp/curl.log" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigTmp/data" \
		bash "${rigHere%/sh-lib}/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-agent-spawn-proxy "$proxyMember" --session-id "$rigS" "$@" --dispatch-doc:none --wait --context rig-seat ) > "$proxyOut" 2>&1
	printf '%s' "$?" > "$proxyOut.rc"
}
rigProxy "$rigTmp/proxy-second.out" keeper-myx
rigAssert "a second keeper run is refused, naming the run that holds the seat and where to ask it" \
	"$( cat "$rigTmp/proxy-second.out.rc" ):$( LC_ALL=C grep -c -F -e "run $rigKeep2 holds its seat" "$rigTmp/proxy-second.out" ):$( LC_ALL=C grep -c -F -e "$rigS:keeper-myx" "$rigTmp/proxy-second.out" ):$( LC_ALL=C grep -c '^LAUNCHED=true' "$rigTmp/proxy-second.out" )" "1:1:1:0"
rigProxy "$rigTmp/proxy-restart.out" keeper-myx --restarted-from "$rigKeep2"
rigAssert "a restart of the run that holds it is not refused on the seat" "$( LC_ALL=C grep -c -F 'holds its seat' "$rigTmp/proxy-restart.out" )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SESSION SEAT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_SEAT: OK (%d assertions, offline)\n' "$rigPassCount"
