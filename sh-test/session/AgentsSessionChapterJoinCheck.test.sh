#!/usr/bin/env bash
## Behavioural check on the session chapter a joining run writes (S21.20): a run that joins a session with a
## description writes sessions/<session-id>/chapter as one line, "<joining member>: <description>"; a join with
## none writes nothing; the run that opens a session writes nothing; a join adds no thread post for it. A chapter
## set explicitly is kept by a join, a join's chapter is replaced by the next join, and an explicit set after a
## join is kept. Behaviour only: the chapter file and the thread, never a marker beside them. Offline.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigTest="$rigPackage/sh-test"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "$rigTest/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the fixture that ends control threads is missing from the package"
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionChapterJoinCheck )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin"

cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check could issue real requests"

## The console the proxy launches: it records the brief and the launch, and runs no model.
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records the brief.' \
	'cat > "$RIG_SCENARIO/brief"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
		rigFails=$(( rigFails + 1 ))
	fi
}

## One spawn through the proxy, its stdout and stderr together. The caller is a bare command line,
## which starts the session when it names none: every spawn here is waited for.
rigSpawn(){ ## member, proxy arguments...
	local spawnMember="$1" ; shift
	: > "$rigTmp/calls" ; : > "$rigTmp/bodies" ; : > "$rigTmp/brief"
	( cd "$rigWs" && env -u MDAT_DATA_ROOT -u MDAT_SPAWN_SESSION_ID -u CLAUDE_CODE_SESSION_ID -u MDAT_SESSION_ID \
		-u MDAT_SESSION_THREAD -u MDAT_SESSION_WORKSPACE -u MDAT_SPAWN_AGENT \
		RIG_SCENARIO="$rigTmp" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		bash "$rigTool" --intern-op-agent-spawn-proxy "$spawnMember" "$@" --dispatch-doc:none --wait --context rig-chapter <<< "RIG-BRIEF-MARKER" 2>&1 ) || :
}
## One header of the newest spawn record, and the id of the session it names.
rigNewest(){ ## header
	local newestFile
	newestFile="$( ls -t "$rigWs/.local/agents/spawned"/*/*.spawn.md 2> /dev/null | head -1 )"
	[ -n "$newestFile" ] || return 0
	LC_ALL=C sed -n "s/^$1: //p" "$newestFile" | head -1
}
## The chapter the session's own store holds, or nothing where there is none.
rigChapter(){ ## session id
	[ -f "$rigWs/.local/agents/sessions/$1/chapter" ] || return 0
	cat "$rigWs/.local/agents/sessions/$1/chapter"
}
rigReplies(){ ## fixed text -- posts that are replies in a thread
	LC_ALL=C grep -F -- "$1" "$rigTmp/bodies" | LC_ALL=C grep -c -F '"thread_ts"' || :
}
## One session opened by a bare command line, its id printed. Refuses rather than report on a spawn that never
## reached its console.
rigOpenSession(){ ## the name the session carries
	local openOut
	openOut="$( rigSpawn keeper-myx --session-name-or-comment "$1" )"
	grep -q 'RIG-BRIEF-MARKER' "$rigTmp/brief" || rigRefuse "the console never received the brief of the opening spawn, so nothing below would be measured: $( printf '%s\n' "$openOut" | LC_ALL=C grep -m1 'ERROR' )"
	[ "$( rigNewest start-context )" = spawned ] || rigRefuse "the opening spawn did not start a session of its own, so the chapter has no subject"
	rigNewest session-id
}
rigSetChapter(){ ## session id, the words -- the executor's own set, as a call from the session's opening run
	local setRc=0
	( cd "$rigWs" && env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u MDAT_SESSION_THREAD -u MDAT_SESSION_WORKSPACE \
		MDAT_SESSION_ID="$1" MDAT_SPAWN_SESSION_ID="$1" MDAT_SPAWN_AGENT=keeper-myx \
		RIG_SCENARIO="$rigTmp" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		bash "$rigTool" --intern-op-set-session-chapter "$2" ) > "$rigTmp/set.out" 2>&1 || setRc=$?
	[ "$setRc" = 0 ] || rigRefuse "the explicit chapter was not set, so the assertions over it would measure nothing: $( head -2 "$rigTmp/set.out" )"
}

echo "-- 1. the run that opens a session writes no chapter --"
rigOne="$( rigOpenSession 'the first rig session' )"
[ -n "$rigOne" ] || rigRefuse "the opening spawn named no session"
rigAssert "the opening run starts the session it names, on its own record" \
	"$( [ "$( rigNewest spawn-id )" = "$rigOne" ] && printf own || printf joined )" own
rigAssert "the run that opens a session writes no chapter" "$( rigChapter "$rigOne" )" ""

echo "-- 2. a join carrying a description writes the chapter --"
rigSpawn magic-tester --session-id "$rigOne" --description 'check the samples' > /dev/null
rigAssert "the run joined that session" "$( rigNewest start-context ):$( rigNewest session-id )" "joined:$rigOne"
rigAssert "the join writes the chapter as one line: the joining member and its description" \
	"$( rigChapter "$rigOne" )" "magic-tester: check the samples"
rigAssert "the join adds no thread post for the chapter: the one joined line stands" \
	"$( LC_ALL=C grep -c -F 'Session chapter' "$rigTmp/bodies" ):$( rigReplies 'magic-tester joined: check the samples' )" "0:1"

echo "-- 3. a join with no description writes nothing --"
rigTwo="$( rigOpenSession 'the second rig session' )"
[ -n "$rigTwo" ] || rigRefuse "the second opening spawn named no session"
rigSpawn magic-tester --session-id "$rigTwo" > /dev/null
rigAssert "a join with no description leaves the session with no chapter" "$( rigChapter "$rigTwo" )" ""

echo "-- 4. a chapter set explicitly before any join is kept --"
rigThree="$( rigOpenSession 'the third rig session' )"
[ -n "$rigThree" ] || rigRefuse "the third opening spawn named no session"
rigSetChapter "$rigThree" 'the first stage'
rigSpawn magic-tester --session-id "$rigThree" --description 'the second stage' > /dev/null
rigAssert "a chapter set explicitly before any join is kept by that join" \
	"$( rigChapter "$rigThree" )" "the first stage"

echo "-- 5. a join's chapter is replaced by the next join --"
rigFour="$( rigOpenSession 'the fourth rig session' )"
[ -n "$rigFour" ] || rigRefuse "the fourth opening spawn named no session"
rigSpawn magic-tester --session-id "$rigFour" --description 'the first stage' > /dev/null
rigSpawn magic-developer --session-id "$rigFour" --description 'the second stage' > /dev/null
rigAssert "a chapter a join wrote is replaced by the next join carrying a description" \
	"$( rigChapter "$rigFour" )" "magic-developer: the second stage"

echo "-- 6. an explicit set after a join is kept by the next join --"
rigFive="$( rigOpenSession 'the fifth rig session' )"
[ -n "$rigFive" ] || rigRefuse "the fifth opening spawn named no session"
rigSpawn magic-tester --session-id "$rigFive" --description 'the first stage' > /dev/null
rigSetChapter "$rigFive" 'the stage the executor chose'
rigSpawn magic-developer --session-id "$rigFive" --description 'the second stage' > /dev/null
rigAssert "a chapter set explicitly after a join is kept by the next join" \
	"$( rigChapter "$rigFive" )" "the stage the executor chose"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ THIS SESSION CHAPTER JOIN CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_CHAPTER_JOIN: OK (%d assertions, offline)\n' "$rigPasses"
