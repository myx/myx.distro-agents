#!/usr/bin/env bash
## Behavioural check on the end of a root session -- one the team tooling did not spawn -- and on stopping the
## console's root harness:
##  1. client-hooks/root-session-end.sh end (SessionEnd) writes sessions/<id>/ended and touches the store, so
##     AgentsToolsGrantsSessionEnded reads the session as ended and a session grant in its store stops counting;
##     then, detached, its open ask is marked ended for the main loop and its transcript gets its END line.
##  2. It does nothing for a spawned session (a spawn record of its id, or MDAT_SPAWN_SESSION_ID set), nor for an id
##     that is not a bare name.
##  3. resume (SessionStart, source resume) removes the marker; another source leaves it.
##  4. Installed under <workspace>/.claude/hooks and run with no MMDAPP, it finds its workspace by its own place.
##  5. AgentsToolsPendingReplySessionsRunning lists a root session that asked until its store says it ended.
##  6. The console root harness (--intern-root-harness, interactive) stays the foreground job: Ctrl+C -- SIGINT to
##     its process group, as a terminal sends it -- stops the session, and the spawn proxy closes its record.
## Offline: a fake curl first on PATH, model CLIs that only log, every path under one temp tree.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigHook="$rigHere/client-hooks/root-session-end.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -x "$rigHook" ] || rigRefuse "the hook is missing or not executable in the package: $rigHook"
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsRootSessionEndCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/tmp" "$rigTmp/home"
cp "$rigTest/check-fixtures/slack-send-identity-check.curl.test.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
for rigModel in claude codex copilot ; do
	printf '#!/bin/sh\necho "%s $*" >> "%s/model-calls"\nexit 1\n' "$rigModel" "$rigTmp" > "$rigTmp/bin/$rigModel"
done
chmod +x "$rigTmp/bin/"*
rigPath="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin"
[ "$( PATH="$rigPath" command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}

## ---- one workspace, its team data and members ----
rigWs="$rigTmp/ws" ; rigData="$rigTmp/data" ; rigSkills="$rigTmp/skills"
rigSessions="$rigWs/.local/agents/sessions"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents/pending" "$rigSessions" "$rigWs/.local/agents/spawned" "$rigData/board/running" \
	"$rigSkills/magic-tester" "$rigSkills/magic-coordinator" "$rigSkills/magic-team"
for rigMember in magic-tester magic-coordinator ; do
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
	printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
done
printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator\ninvitees: magic-team\ndefault-for-session-kind: coworking\n---\n# rig coworking routine fixture\n' \
	> "$rigSkills/magic-team/magic-team.coworking.routine.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"

rigHookRun(){ ## mode, payload, extra env assignments... -- the hook as a client runs it, in the workspace
	printf '%s' "$2" | env -i HOME="$rigTmp/home" PATH="$rigPath" TMPDIR="$rigTmp/tmp" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$rigTmp" "${@:3}" bash "$rigHook" "$1" > "$rigTmp/hook.out" 2> "$rigTmp/hook.err"
	rigHookRc=$?
}
rigEnded(){ ## session id -- ended or open, by AgentsToolsGrantsSessionEnded
	env -i PATH="$rigPath" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "$1/AgentsTools.Grants.include" && AgentsToolsGrantsSessionEnded "$2"' rig "$rigHere" "$rigSessions/$1" \
		&& printf ended || printf open
}
rigScan(){ ## session id -- what a session grant scan of its store finds for keeper-rig, Read /rig/target
	env -i PATH="$rigPath" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '
		AgentsToolsPermissionEscape(){ printf "%s" "$1" ; }
		. "$1/AgentsTools.PermissionHolds.include" && AgentsToolsPermissionGrantScan "$2" keeper-rig Read /rig/target hold || printf none' rig "$rigHere" "$rigSessions/$1"
}
rigRunning(){ ## session id -- listed or absent among the sessions AgentsToolsPendingReplySessionsRunning lists
	local runningList
	runningList="$( env -i PATH="$rigPath" HOME="$rigTmp/home" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash -c '. "$1/AgentsTools.PendingReplyCollect.include" && AgentsToolsPendingReplySessionsRunning' rig "$rigHere" 2> /dev/null )"
	case "$runningList" in
		*" $1 "*) printf listed ;;
		*) printf absent ;;
	esac
}
rigWaitFor(){ ## file, fixed text, seconds -- yes once the file holds the text, else no
	local waitLeft="$3"
	while [ "$waitLeft" -gt 0 ] ; do
		LC_ALL=C grep -q -F -- "$2" "$1" 2> /dev/null && { printf yes ; return 0 ; }
		sleep 1 ; waitLeft=$(( waitLeft - 1 ))
	done
	printf no
}
rigPayload(){ ## event, session id, extra json fields
	printf '{"session_id":"%s","transcript_path":"/rig/none.jsonl","cwd":"%s","hook_event_name":"%s"%s}' "$2" "$rigWs" "$1" "$3"
}

## A root session: a session grant for keeper-rig in its store, an open plain question, a transcript.
rigRoot="rig-root-$$-aa"
mkdir -p "$rigSessions/$rigRoot" "$rigData/audit/2026-10"
printf 'session:Read:/rig/target:magic-coordinator:20261009T1200Z:pass-rig1\n' > "$rigSessions/$rigRoot/grants"
printf -- '---\nowner: keeper-rig\n---\n\n# rig pass\n' > "$rigSessions/$rigRoot/pass-rig1.md"
rigTranscript="$rigData/audit/2026-10/session-20261009T120000Z-magic-coordinator-rigroot.log"
printf '2026-10-09T12:00:00Z START session=%s member=magic-coordinator\n' "$rigRoot" > "$rigTranscript"
printf '%s\n' "$rigTranscript" > "$rigSessions/$rigRoot/transcript"
printf '%s\n' "$rigData" > "$rigSessions/$rigRoot/data-root"
printf -- '---\nstatus: reply-pending\nowner: magic-tester\nsession-id: %s\naddress-to: human-owner\nquestion-tag: Q1\nasked-at: 2026-10-09 12:00 +0300\n---\n\n# Question asked\n\nMay the rig keep its file?\n' \
	"$rigRoot" > "$rigWs/.local/agents/pending/rig-ask-1.md"

echo "-- 1. a root session ends: the marker, the store touched, its grants out, its ask marked, its transcript ended --"
rigAssert "control: before its end the session is open and its session grant counts" "$( rigEnded "$rigRoot" ) $( rigScan "$rigRoot" )" "open session pass-rig1"
rigAssert "control: before its end it is listed among the running sessions" "$( rigRunning "$rigRoot" )" listed
touch -t 202001010000 "$rigSessions/$rigRoot/grants" "$rigTmp/ref-2020"
touch -t 202001010001 "$rigTmp/ref-2020-later"
rigHookRun end "$( rigPayload SessionEnd "$rigRoot" ',"reason":"prompt_input_exit"' )"
rigAssert "the hook exits 0 and says nothing on stdout" "$rigHookRc $( LC_ALL=C awk 'END { print NR + 0 }' "$rigTmp/hook.out" )" "0 0"
rigAssert "the marker names the reason" "$( LC_ALL=C sed -n 's/^reason: //p' "$rigSessions/$rigRoot/ended" 2> /dev/null )" prompt_input_exit
rigAssert "the store was touched, so every index joining it rebuilds" "$( [ "$rigSessions/$rigRoot/grants" -nt "$rigTmp/ref-2020-later" ] && printf touched || printf stale )" touched
rigAssert "the session now reads as ended, and its session grant no longer counts" "$( rigEnded "$rigRoot" ) $( rigScan "$rigRoot" )" "ended none"
rigAssert "and it is no longer listed among the running sessions" "$( rigRunning "$rigRoot" )" absent
rigAssert "its open ask is marked ended for the main loop" "$( rigWaitFor "$rigWs/.local/agents/pending/rig-ask-1.md" 'collect: ended' 30 )" yes
rigAssert "its transcript gets its END line" "$( rigWaitFor "$rigTranscript" ' END outcome=session-end:prompt_input_exit' 30 )" yes
rigAssert "no model was called" "$( [ -s "$rigTmp/model-calls" ] && printf called || printf none )" none

echo "-- 2. nothing for a spawned session or a bad id --"
rigSpawn="rig-spawn-$$-bb"
mkdir -p "$rigWs/.local/agents/spawned/rig-sandbox"
printf -- '---\nspawn-id: %s\nstatus: spawn-started\n---\n' "$rigSpawn" > "$rigWs/.local/agents/spawned/rig-sandbox/$rigSpawn.md"
rigHookRun end "$( rigPayload SessionEnd "$rigSpawn" ',"reason":"other"' )"
rigAssert "a session with a spawn record: no marker, its proxy closes it" "$rigHookRc $( [ -e "$rigSessions/$rigSpawn/ended" ] && printf marked || printf none )" "0 none"
rigLone="rig-lone-$$-cc"
rigHookRun end "$( rigPayload SessionEnd "$rigLone" ',"reason":"other"' )" MDAT_SPAWN_SESSION_ID=rig-some-spawn
rigAssert "a client carrying MDAT_SPAWN_SESSION_ID: no marker" "$rigHookRc $( [ -e "$rigSessions/$rigLone/ended" ] && printf marked || printf none )" "0 none"
rigHookRun end "$( rigPayload SessionEnd "../rig-escape" ',"reason":"other"' )"
rigAssert "an id that is not a bare name: nothing written" "$rigHookRc $( [ -e "$rigWs/.local/agents/rig-escape/ended" ] || [ -e "$rigSessions/../rig-escape/ended" ] && printf written || printf none )" "0 none"
rigHookRun end "$( rigPayload SessionEnd "$rigLone" ',"reason":"other"' )"
rigAssert "control: the same id with no spawn marker is ended" "$( rigEnded "$rigLone" )" ended

echo "-- 3. a resume under the same id removes the marker; another source leaves it --"
rigHookRun resume "$( rigPayload SessionStart "$rigLone" ',"source":"startup"' )"
rigAssert "a startup source leaves the marker" "$( rigEnded "$rigLone" )" ended
rigHookRun resume "$( rigPayload SessionStart "$rigLone" ',"source":"fork"' )"
rigAssert "a fork source leaves it: a fork is a new id" "$( rigEnded "$rigLone" )" ended
rigHookRun resume "$( rigPayload SessionStart "rig-other-$$-ee" ',"source":"resume"' )"
rigAssert "a resume of another id leaves it: only the same id is reopened" "$( rigEnded "$rigLone" )" ended
rigHookRun resume "$( rigPayload SessionStart "$rigLone" ',"source":"resume"' )"
rigAssert "a resume removes it, and says nothing on stdout" "$( rigEnded "$rigLone" ) $rigHookRc $( LC_ALL=C awk 'END { print NR + 0 }' "$rigTmp/hook.out" )" "open 0 0"

echo "-- 4. installed under the workspace .claude/hooks with no MMDAPP: it finds its workspace by its own place --"
mkdir -p "$rigWs/.claude/hooks"
cp "$rigHook" "$rigWs/.claude/hooks/root-session-end.sh" && chmod +x "$rigWs/.claude/hooks/root-session-end.sh"
rigPlaced="rig-placed-$$-dd"
( cd / && rigPayload SessionEnd "$rigPlaced" ',"reason":"logout"' | env -i HOME="$rigTmp/home" PATH="$rigPath" TMPDIR="$rigTmp/tmp" MDLT_ORIGIN="$MDLT_ORIGIN" \
	CLAUDE_PROJECT_DIR="$rigWs" bash "$rigWs/.claude/hooks/root-session-end.sh" end ) > /dev/null 2>&1
rigAssert "the marker lands in that workspace" "$( LC_ALL=C sed -n 's/^reason: //p' "$rigSessions/$rigPlaced/ended" 2> /dev/null )" logout

echo "-- 5. the console root harness: Ctrl+C stops the session, and the spawn proxy closes its record --"
## The console the proxy launches: records its start, then works for 25 s; resumed (the handback retry), it hands back at once.
printf '%s\n' '#!/usr/bin/env bash' '## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli) stand-in: a session that works 25 s.' \
	'cat > /dev/null' 'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' \
	'[ "${MDAT_SPAWN_RESUME:-}" != true ] || { printf "📦 SubagentHandback\n" ; exit 0 ; }' \
	'echo started >> "$RIG_SCENARIO/session.events"' 'sleep 25' 'echo finished >> "$RIG_SCENARIO/session.events"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"
## A terminal foreground job: its own process group, SIGINT at its default, which a background start here would not have.
perl -e '$SIG{INT} = "DEFAULT" ; $SIG{QUIT} = "DEFAULT" ; setpgrp( 0, 0 ) ; exec @ARGV' \
	env -i HOME="$rigTmp/home" PATH="$rigPath" TMPDIR="$rigTmp/tmp" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
	MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" bash -c 'cd "$MMDAPP" && exec bash "$0" --intern-root-harness' "$rigTool" \
	> "$rigTmp/root.out" 2>&1 < /dev/null &
rigRootPid=$!
rigStarted="$( rigWaitFor "$rigTmp/session.events" started 60 )"
rigAssert "control: the session started, and the console command is still the foreground job" "$rigStarted $( kill -0 "$rigRootPid" 2> /dev/null && printf waiting || printf returned )" "yes waiting"
sleep 1
kill -INT -"$rigRootPid" 2> /dev/null
rigRootLeft=60
while kill -0 "$rigRootPid" 2> /dev/null && [ "$rigRootLeft" -gt 0 ] ; do sleep 1 ; rigRootLeft=$(( rigRootLeft - 1 )) ; done
kill -0 "$rigRootPid" 2> /dev/null && { kill -KILL -"$rigRootPid" 2> /dev/null ; rigRefuse "the root harness did not return within 60 s of Ctrl+C" ; }
rigRootRecord="$( ls "$rigWs/.local/agents/spawned"/*/*.md 2> /dev/null | LC_ALL=C grep -v "/rig-sandbox/" | head -1 )"
rigAssert "Ctrl+C stopped the session before its work finished" "$( LC_ALL=C tr '\n' ' ' < "$rigTmp/session.events" )" "started "
rigAssert "and the proxy closed its record: a closed status and its resolved-at" "$( LC_ALL=C sed -n 's/^status: //p' "$rigRootRecord" 2> /dev/null | head -1 ) $( LC_ALL=C grep -c '^resolved-at: ' "$rigRootRecord" 2> /dev/null )" "spawn-failed 1"
rigAssert "the command waited for its session and printed its end" "$( LC_ALL=C grep -c -E '^(EXIT_CODE|STATUS)=' "$rigTmp/root.out" ) $( LC_ALL=C grep -c '^STATUS=started$' "$rigTmp/root.out" )" "2 0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROOT SESSION END CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ROOT_SESSION_END: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
