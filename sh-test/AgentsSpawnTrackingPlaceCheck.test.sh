#!/usr/bin/env bash
## Behavioural check on WHICH THREAD a spawn's posts go to, run rather than read, against a
## scenario workspace built here. Holds: A TRACKING THREAD IS NEVER A SESSION THREAD -- a
## session that starts alone (--session-thread:event-track, the main loop's pass) has its
## tracking thread and no session thread; the first member it brings in opens the session
## thread in magic-team, which is recorded as the session's, and later ones join it; a
## session started before that rule, which still hands its tracking thread down as its
## session thread, has its members put in a session thread in magic-team too. A member's
## handback (session-parent) goes to that session thread, never to event-track. And A TRACKING
## BOX GOES TO THE TRACKING THREAD ONLY: the box of a run that ended with no handback, and
## the box of one that left a question open, are replies in the session's tracking thread,
## and what the member that brought the run in must know is a message addressed to it in the
## session thread, its text from sh-lib/templates/tooling-note.post.format.md (`# Session`).
## A fake console records the brief and its environment; the fake curl answers in the
## conversation a post names. Offline by construction.
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
for rigNeed in magic-coordinator magic-tester magic-developer ; do
	[ -r "${MDAT_SKILLSET_ROOT:-}/$rigNeed/$rigNeed.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigNeed, so no spawn of it would start"
done

## A spawn of this rig that is not waited for starts the control thread of its session, a detached process that
## outlives this check: the rig ends it, before its tree is removed (the guard is in AgentsSessionControlStartCheck).
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsSpawnTrackingPlaceCheck-XXXXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## The stand-ins it keeps are ended through the one way a check signals what it kept.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
rigLivePids=""
trap 'rigProcSignalWithChildren TERM $rigLivePids ; chmod -R u+w -- "$rigTmp" 2>/dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigTmp/data"
cp "$rigTest/check-fixtures/spawn-tracking-place.curl.stub.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigTest/check-fixtures/spawn-tracking-place.curl.stub.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

rigTeam="CRIGTEAM1"
rigTrackChannel="CRIGTRACK"
printf 'SLACK_CHANNEL_MAGIC_TEAM=%s\nSLACK_CHANNEL_EVENT_TRACK=%s\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' "$rigTeam" "$rigTrackChannel" \
	> "$rigWs/.local/.agents/magic-team.agent.env"

## The console the proxy launches: it records the brief, its own spawn id and the session it
## was handed, and runs no model. It names --cli-configured and MDAT_SPAWN_LAUNCH_MARKER,
## which the proxy greps for before it launches anything. What a run does is the scenario's:
## with console.handback it says it handed back, as a harness run does; with console.question
## it leaves one question of its own open. A run resumed for its handback (MDAT_SPAWN_RESUME)
## says only that it was.
cat > "$rigWs/DistroAgentsConsole.sh" <<'RIGCONSOLE'
#!/usr/bin/env bash
## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records the brief.
if [ -n "${MDAT_SPAWN_RESUME:-}" ] ; then
	cat > /dev/null
	echo resumed >> "$RIG_SCENARIO/console.log"
	exit 0
fi
cat > "$RIG_SCENARIO/brief"
printf 'rig-cli\n' > "$MDAT_SPAWN_LAUNCH_MARKER"
printf '%s\n' "$MDAT_SPAWN_SESSION_ID" > "$RIG_SCENARIO/last-spawn"
printf 'MDAT_SESSION_ID=%s\nMDAT_SESSION_THREAD=%s\n' "${MDAT_SESSION_ID:-}" "${MDAT_SESSION_THREAD:-}" > "$RIG_SCENARIO/console.env"
echo started >> "$RIG_SCENARIO/console.log"
[ ! -f "$RIG_SCENARIO/console.handback" ] || printf '   📦 SubagentHandback rig-outcome\n'
if [ -f "$RIG_SCENARIO/console.question" ] ; then
	mkdir -p "$MMDAPP/.local/agents/pending"
	printf -- '---\nstatus: reply-pending\nkind: question\nowner: %s\nsession-id: %s\naddress-to: magic-coordinator\n---\n\n# Pending reply\n\nWhich sample goes first?\n' \
		"$MDAT_SPAWN_AGENT" "$MDAT_SPAWN_SESSION_ID" > "$MMDAPP/.local/agents/pending/rig-open-$MDAT_SPAWN_SESSION_ID.md"
fi
RIGCONSOLE
chmod +x "$rigWs/DistroAgentsConsole.sh"

## One spawn, waited for, with a dispatch document, so its output is kept and its close runs
## whole; leaves the proxy's own output, stdout and stderr together, in rigOut. Into a file,
## never a capture: the retry that asks a run for its handback leaves a timer behind it, and a
## capture would wait for that timer. The caller is a bare command line, with no session of
## any kind, unless rigCaller gives it one (NAME=value words).
rigCaller=()
rigOut=""
rigSpawn(){ ## member, extra proxy arguments...
	local spawnMember="$1"
	shift
	rm -f "$rigTmp/calls" "$rigTmp/posts" "$rigTmp/posts.log" "$rigTmp"/post.* "$rigTmp/brief" "$rigTmp/console.env" "$rigTmp/console.log" "$rigTmp/last-spawn"
	: > "$rigTmp/posts.log"
	( cd "$rigWs" && env -u MDAT_SPAWN_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u MDAT_SESSION_ID -u MDAT_SESSION_THREAD -u MDAT_SESSION_WORKSPACE -u MDAT_SPAWN_AGENT -u MDAT_SPAWN_SANDBOX_ROOT \
		"${rigCaller[@]+"${rigCaller[@]}"}" RIG_SCENARIO="$rigTmp" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigTmp/data" MDLT_ORIGIN="$MDLT_ORIGIN" \
		bash "$rigTool" --intern-op-agent-spawn-proxy "$spawnMember" "$@" --dispatch-doc:create --wait --context rig-tracking-place <<< "RIG-BRIEF-MARKER" > "$rigTmp/spawn.out" 2>&1 ) || :
	rigOut="$( cat "$rigTmp/spawn.out" )"
}
## The posts of the last spawn, by where they went and what they are: how many. With a text,
## only those whose body holds it.
rigPosts(){ ## conversation, thread ts or `top` or `any`, what (a tracking kind, session-root, message) or `any`, optional fixed text
	local postsNo postsCount=0
	for postsNo in $( LC_ALL=C awk -v wantChannel="$1" -v wantThread="$2" -v wantWhat="$3" '
		$2 == wantChannel && ( wantThread == "any" || $3 == wantThread ) && ( wantWhat == "any" || $4 == wantWhat ) { print $1 ; }' "$rigTmp/posts.log" ) ; do
		[ -z "${4:-}" ] || LC_ALL=C grep -q -F -- "$4" "$rigTmp/post.$postsNo" 2> /dev/null || continue
		postsCount=$(( postsCount + 1 ))
	done
	printf '%s' "$postsCount"
}
rigPostNo(){ ## conversation, what -- the number of the first such post
	LC_ALL=C awk -v wantChannel="$1" -v wantWhat="$2" '$2 == wantChannel && $4 == wantWhat { print $1 ; exit ; }' "$rigTmp/posts.log"
}
rigPostHolds(){ ## post number, text
	[ -n "$1" ] && [ -f "$rigTmp/post.$1" ] || { printf 'no-such-post' ; return 0 ; }
	LC_ALL=C grep -q -F -- "$2" "$rigTmp/post.$1" && printf yes || printf no
}
## One header of the record of the last spawn.
rigRecord(){ ## header
	local recordFile
	for recordFile in "$rigWs/.local/agents/spawned"/*/"$( cat "$rigTmp/last-spawn" 2> /dev/null || printf none ).spawn.md" ; do
		[ -f "$recordFile" ] || continue
		LC_ALL=C awk -v wantHeader="$1" '$0 == "---" { if ( ++dashes == 2 ) { exit ; } next ; } dashes == 1 && index( $0, wantHeader ": " ) == 1 { print substr( $0, length( wantHeader ) + 3 ) ; found = 1 ; exit ; } END { if ( ! found ) { print "none" ; } }' "$recordFile"
		return 0
	done
	printf 'no-record'
}
rigN(){ ## text, fixed text to count the lines of
	printf '%s\n' "$1" | LC_ALL=C grep -c -F -- "$2" || :
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

echo "-- a session that starts alone: its tracking thread, and no session thread --"
rigSpawn magic-coordinator --session-thread:event-track
## The subject has to be reachable before anything is asserted about it.
grep -q 'RIG-BRIEF-MARKER' "$rigTmp/brief" 2> /dev/null || rigRefuse "the fake console never received the brief, so nothing below would be measured: $( printf '%s\n' "$rigOut" | grep 'ERROR' | head -1 )"
rigPass="$( cat "$rigTmp/last-spawn" )"
rigPassTrack="$( cat "$rigWs/.local/agents/sessions/$rigPass/event-track.thread" 2> /dev/null )"
rigAssert "it launched, and its tracking thread is opened in event-track by its start post and recorded as the session's" \
	"$( rigN "$rigOut" 'LAUNCHED=true' ):${rigPassTrack%%:*}:$( rigPosts "$rigTrackChannel" top start ):$( rigRecord agent-log-thread )" "1:$rigTrackChannel:1:$rigPassTrack"
rigAssert "it has no session thread: none on its record, none reported, none handed to its run, and nothing is posted in magic-team" \
	"$( rigRecord session-thread ):$( rigN "$rigOut" 'SESSION_THREAD=none' ):$( LC_ALL=C grep -c -x 'MDAT_SESSION_THREAD=' "$rigTmp/console.env" ):$( rigPosts "$rigTeam" any any )" "none:1:1:0"
rigAssert "its brief says so, how it gets one, and that its tracking thread takes no message of its own" \
	"$( LC_ALL=C grep -c -x -F 'session_thread_ts: none -- this session starts alone, so it has no session thread yet: one is opened in magic-team when it brings a member in, and session-current names it from then on. Its tracking thread in event-track is the tooling'"'"'s own record of this run, and takes no message of yours' "$rigTmp/brief" )" 1
rigAssert "its run ended with no handback: it was asked for one once, and the box that says so is a reply in its tracking thread" \
	"$( LC_ALL=C grep -c -x resumed "$rigTmp/console.log" ):$( rigPosts "$rigTrackChannel" "${rigPassTrack#*:}" handback )" "1:1"

## A session's own run still runs while the members it brings in work, as a coordinator's does:
## its record says it started, and a stand-in whose own --session-id is its id is alive by the
## one rule a run is alive by, until the rig ends. What is meant for that session goes to a
## member that runs there (AgentsToolsRunRouteAvailable).
rigLive(){ ## spawn id
	local liveRecord liveTemp
	for liveRecord in "$rigWs/.local/agents/spawned"/*/"$1.spawn.md" ; do
		[ -f "$liveRecord" ] || continue
		liveTemp="$( mktemp "$liveRecord.XXXXXX" )" || rigRefuse "no temp beside the record of $1"
		LC_ALL=C awk '$0 == "---" { dashes++ } dashes == 1 && index( $0, "status: " ) == 1 { $0 = "status: spawn-started" } { print }' "$liveRecord" > "$liveTemp" && mv -f "$liveTemp" "$liveRecord"
	done
	bash -c 'sleep 1800 ; :' rig-run --session-id "$1" > /dev/null 2>&1 < /dev/null &
	rigLivePids="$rigLivePids $!" ; rigProcNote "$!"
	disown "$!" 2> /dev/null || :
}

echo "-- the first member it brings in opens the session thread in magic-team --"
rigLive "$rigPass"
touch "$rigTmp/console.question"
rigCaller=( MDAT_SPAWN_SESSION_ID="$rigPass" MDAT_SESSION_ID="$rigPass" MDAT_SPAWN_AGENT=magic-coordinator )
rigSpawn magic-tester --description "check it against the samples"
rigFirst="$( cat "$rigTmp/last-spawn" )"
rigThread="$( cat "$rigWs/.local/agents/sessions/$rigPass/session.thread" 2> /dev/null )"
rigAssert "it joins that session, and opens its session thread: a root post at the top of magic-team, recorded as the session's" \
	"$( rigN "$rigOut" 'LAUNCHED=true' ):$( rigRecord session-id ):$( rigPosts "$rigTeam" top session-root ):${rigThread%%:*}" "1:$rigPass:1:$rigTeam"
rigAssert "that thread is its own session thread: on its record, reported, handed to its run and named in its brief" \
	"$( rigRecord session-thread ):$( rigN "$rigOut" "SESSION_THREAD=$rigThread" ):$( LC_ALL=C grep -c -x "MDAT_SESSION_THREAD=$rigThread" "$rigTmp/console.env" ):$( LC_ALL=C grep -c -x "session_thread_ts: $rigThread" "$rigTmp/brief" )" "$rigThread:1:1:1"
rigAssert "its handback goes there too: the thread settled for session-parent is that session thread" "$( rigRecord parent-thread )" "$rigThread"
## The session that brought it in, which was handed no thread at its own start, finds that
## thread as its own from now on: what a bare Wait of it watches, and what session-current names.
rigAssert "the session that brought it in now has that thread as its own: a bare Wait of it watches it, and nothing else" \
	"$( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u MDAT_SESSION_THREAD -u MDAT_CONVERSATION_THREADS -u MDAT_SPAWN_SANDBOX_ROOT MDAT_SPAWN_SESSION_ID="$rigPass" MDAT_SESSION_ID="$rigPass" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SpawnSandbox.include" ; AgentsToolsWaitDefaultSources ; printf ":" ; AgentsToolsSessionCurrentThreadFind' 2> /dev/null | LC_ALL=C tr -d '\n' )" \
	"slack:$rigThread:conversation:$rigThread"
rigAssert "it says in that thread that it joined, and its own start post is a reply in the session's tracking thread" \
	"$( rigPostHolds "$( rigPostNo "$rigTeam" message )" 'magic-tester joined: check it against the samples' ):$( rigPosts "$rigTrackChannel" "${rigPassTrack#*:}" start ):$( rigPosts "$rigTrackChannel" top any )" "yes:1:0"
echo "-- a tracking box goes to the tracking thread only, and the session thread gets a message --"
rigAssert "no tracking box is posted in the session thread, or anywhere in magic-team" \
	"$( rigPosts "$rigTeam" any handback ):$( rigPosts "$rigTeam" any notice ):$( rigPosts "$rigTeam" any start ):$( rigPosts "$rigTeam" any end )" "0:0:0:0"
rigAssert "the box of a run that ended with no handback, and the box of its open question, are replies in the tracking thread" \
	"$( rigPosts "$rigTrackChannel" "${rigPassTrack#*:}" handback 'none posted' ):$( rigPosts "$rigTrackChannel" "${rigPassTrack#*:}" notice 'ended with its own question still open' )" "1:1"
rigNoticeAt(){ ## fixed text -- the number of the first message in the session thread that holds it
	local noticeNo
	for noticeNo in $( LC_ALL=C awk -v wantChannel="$rigTeam" -v wantThread="${rigThread#*:}" '$2 == wantChannel && $3 == wantThread && $4 == "message" { print $1 ; }' "$rigTmp/posts.log" ) ; do
		[ "$( rigPostHolds "$noticeNo" "$1" )" != yes ] || { printf '%s' "$noticeNo" ; return 0 ; }
	done
}
rigAssert "the member that brought it in is told of the missing handback in the session thread: a message, addressed to it, its text the template's" \
	"$( rigPostHolds "$( rigNoticeAt 'posted no handback' )" "→ 🤖 *_magic-coordinator_*.\\n📦 magic-tester ended its run \`${rigFirst:0:8}\` and posted no handback. What it did is not reported in this thread." )" yes
rigAssert "and of the question left open, the same way" \
	"$( rigPostHolds "$( rigNoticeAt 'left questions of its own open' )" "→ 🤖 *_magic-coordinator_*.\\n❓ magic-tester ended its run \`${rigFirst:0:8}\` and left questions of its own open: 1. Each one stays open and can still be answered." )" yes
rm -f "$rigTmp/console.question"

echo "-- the next member joins that thread, and one that hands back is told of nothing --"
touch "$rigTmp/console.handback"
rigSpawn magic-developer --description "change the loader"
rigAssert "it opens no thread: the session's own is its session thread, and where its handback goes" \
	"$( rigPosts "$rigTeam" top any ):$( rigRecord session-thread ):$( rigRecord parent-thread ):$( cat "$rigWs/.local/agents/sessions/$rigPass/session.thread" 2> /dev/null )" "0:$rigThread:$rigThread:$rigThread"
rigAssert "a run that handed back gets no box and no message about a handback" \
	"$( rigPosts "$rigTrackChannel" any handback ):$( rigPosts "$rigTrackChannel" any notice 'question still open' ):$( rigPosts "$rigTeam" "${rigThread#*:}" message )" "0:0:1"
rigSecond="$( cat "$rigTmp/last-spawn" )"
## The handback itself, as SubagentHandback sends it: to session-parent, as that member.
rm -f "$rigTmp/posts" "$rigTmp"/post.* ; : > "$rigTmp/posts.log"
( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u MDAT_SESSION_ID -u MDAT_SESSION_THREAD -u MDAT_SPAWN_SANDBOX_ROOT \
	MDAT_SPAWN_SESSION_ID="$rigSecond" MDAT_SPAWN_AGENT=magic-developer RIG_SCENARIO="$rigTmp" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigTmp/data" MDLT_ORIGIN="$MDLT_ORIGIN" \
	bash "$rigTool" --member-comms-slack-send-message magic-developer session-parent RIG-HANDBACK > "$rigTmp/handback.out" 2>&1 ) || :
rigAssert "a handback sent to session-parent is a reply in the session thread in magic-team, and nothing goes to event-track" \
	"$( rigPosts "$rigTeam" "${rigThread#*:}" message ):$( rigPosts "$rigTrackChannel" any any )" "1:0"
rm -f "$rigTmp/console.handback"

echo "-- a session started before the rule, which hands its tracking thread down as its session thread --"
rigOldTrack="$rigTrackChannel:1600000000.000100"
mkdir -p "$rigWs/.local/agents/spawned/rig-old-pass" "$rigWs/.local/agents/sessions/rig-old-pass"
printf -- '---\nsession-id: rig-old-pass\nspawn-id: rig-old-pass\nparent-spawn-id: none\nhost: %s\nowner: magic-coordinator\nstatus: spawn-started\nagent-log-thread: %s\nsession-thread: %s\n---\n\n# Spawn session: rig-old-pass\n' \
	"$( hostname -s 2> /dev/null || echo unknown )" "$rigOldTrack" "$rigOldTrack" > "$rigWs/.local/agents/spawned/rig-old-pass/rig-old-pass.spawn.md"
printf '%s\n' "$rigOldTrack" > "$rigWs/.local/agents/sessions/rig-old-pass/event-track.thread"
rigCaller=( MDAT_SPAWN_SESSION_ID=rig-old-pass MDAT_SESSION_ID=rig-old-pass MDAT_SESSION_THREAD="$rigOldTrack" MDAT_SPAWN_AGENT=magic-coordinator )
rigLive rig-old-pass
rigSpawn magic-tester --description "look at the logs"
rigOldThread="$( cat "$rigWs/.local/agents/sessions/rig-old-pass/session.thread" 2> /dev/null )"
rigAssert "a member it brings in is given a session thread in magic-team, opened and recorded as that session's, never the tracking thread" \
	"$( rigRecord session-id ):${rigOldThread%%:*}:$( rigPosts "$rigTeam" top session-root ):$( rigRecord session-thread ):$( LC_ALL=C grep -c -x "MDAT_SESSION_THREAD=$rigOldThread" "$rigTmp/console.env" )" "rig-old-pass:$rigTeam:1:$rigOldThread:1"
rigAssert "its handback goes to that session thread, never to the tracking thread its parent's record names" "$( rigRecord parent-thread )" "$rigOldThread"
rigAssert "no message of a member is posted in event-track: only the tooling's boxes, in the session's tracking thread" \
	"$( rigPosts "$rigTrackChannel" any message ):$( rigPosts "$rigTrackChannel" top any ):$( rigPosts "$rigTrackChannel" "${rigOldTrack#*:}" start ):$( rigPosts "$rigTrackChannel" "${rigOldTrack#*:}" handback )" "0:0:1:1"
rigAssert "and the session thread is told of the missing handback" \
	"$( rigThread="$rigOldThread" ; rigPostHolds "$( rigNoticeAt 'posted no handback' )" '→ 🤖 *_magic-coordinator_*.' )" yes

echo "-- control: a spawn of a bare command line, in a session of its own --"
rigCaller=()
touch "$rigTmp/console.handback"
rigSpawn magic-tester --session-name-or-comment "a matter of its own"
rigAssert "it opens its session thread in magic-team and its tracking thread in event-track, each its own" \
	"$( rigPosts "$rigTeam" top session-root ):$( rigPosts "$rigTrackChannel" top start ):$( rigRecord session-thread | cut -d: -f1 ):$( rigRecord agent-log-thread | cut -d: -f1 )" "1:1:$rigTeam:$rigTrackChannel"
rm -f "$rigTmp/console.handback"

rigAssert "no request went anywhere but a Slack method" "$( LC_ALL=C awk '$1 ~ /^url:/ || $1 == "no-method" { hitCount++ ; } END { print hitCount + 0 ; }' "$rigTmp/calls" 2> /dev/null )" 0

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ SPAWN TRACKING PLACE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_TRACKING_PLACE: OK (%d assertions, offline)\n' "$rigPasses"
