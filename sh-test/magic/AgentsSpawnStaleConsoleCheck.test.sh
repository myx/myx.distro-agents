#!/usr/bin/env bash
## Behavioural check on the console vintage a session with participants needs (S6.5 of
## `20261102-refactorings.epic.md`, ruled by magic-coordinator: "A stale console must fail loud,
## because a silent miss is the S6.5 defect again").
##
## A console made before the participants change ignores `MDAT_SPAWN_PARTICIPANTS` and starts its
## executor offering no participant at all. Nothing reports it: the member's `Agent` tool then refuses
## a listed colleague as an unknown type, and the session looks like a working one. So a spawn that
## CARRIES participants must refuse a console that cannot read them, and one that carries none must
## still start on that same console.
##
## Held through the real `--spawn-session`, run rather than read, against a stand-in console of this
## rig's own:
##   1. a session that names participants, and a console without the variable: REFUSED, with
##      `SETUP_STATUS=console-stale` and the regenerate hint, and nothing started;
##   2. the same session on a console that carries the variable: started;
##   3. the control: a session that names NO participant starts on the console without the variable,
##      so the guard is bounded to the case it exists for.
##
## WHY IT IS RED ON THE TREE BEFORE THE CHANGE: `AgentsTools.InternOpAgentSpawnProxy.include` checks
## the console's vintage for `cli-configured` and `MDAT_SPAWN_LAUNCH_MARKER` alone. A console without
## `MDAT_SPAWN_PARTICIPANTS` passes both, so case 1's spawn is started and no participant is offered.
##
## Offline: a fake curl answers Slack; the workspace, the store and every record are this rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigFixtures="$rigPackage/sh-test/check-fixtures"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigTool" "$rigFixtures/slack-send-identity-check.curl.stub.sh" "$rigFixtures/rig-control-threads.include.sh" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
. "$rigFixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package"
. "$rigFixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSpawnStaleConsoleCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; chmod -R u+w -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSkills="$rigTmp/skills"
rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigTmp/bin" "$rigData/board" \
	"$rigSkills/magic-team" "$rigSkills/rig-member-a" "$rigSkills/rig-member-b" "$rigTmp/home"
cp "$rigFixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing"
chmod +x "$rigTmp/bin/curl"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
for rigMember in rig-member-a rig-member-b ; do
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
	printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
done
printf -- '---\nexecutors: magic-coordinator\nmaintainers: magic-coordinator, magic-librarian\ninvitees: magic-team\nrequires-session-kind: coworking\n---\n# rig coworking routine fixture\n' \
	> "$rigSkills/magic-team/magic-team.coworking.routine.md"

## THE STALE CONSOLE: both marks the proxy checks today, and no knowledge of the participants. It records
## every start, so a start that should not have happened is seen rather than inferred.
printf '%s\n' '#!/bin/sh' \
	'## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli)' \
	'printf "started\\n" >> "$RIG_TMP/console-stale.log"' \
	'printf "claude-native\\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' \
	'exit 0' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"
## THE CURRENT CONSOLE: the same, and it knows the variable.
printf '%s\n' '#!/bin/sh' \
	'## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli) MDAT_SPAWN_PARTICIPANTS' \
	'printf "started\\n" >> "$RIG_TMP/console-current.log"' \
	'printf "claude-native\\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' \
	'exit 0' > "$rigTmp/console-current.sh"
chmod +x "$rigTmp/console-current.sh"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
		printf '  PASS  %s\n' "$1"
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}
rigConsole(){ ## stale|current -- put that console in place, and forget what was started
	case "$1" in
		current) cp "$rigTmp/console-current.sh" "$rigWs/DistroAgentsConsole.sh" ;;
		*)       cp "$rigTmp/console-stale.sh" "$rigWs/DistroAgentsConsole.sh" 2> /dev/null || :
	esac
	chmod +x "$rigWs/DistroAgentsConsole.sh"
	rm -f "$rigTmp/console-stale.log" "$rigTmp/console-current.log"
}
## The stale console's own text, kept once so it can be put back after a current one is in place.
cp "$rigWs/DistroAgentsConsole.sh" "$rigTmp/console-stale.sh"
rigRun(){ ## stdin content, then --spawn-session args... -- one spawn, made as the session's coordinator
	env -i MDAT_SPAWN_AGENT=magic-coordinator MDAT_SESSION_ID=rig-caller-session MDAT_WORKSPACE_MODE=team-rig \
		HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --spawn-session "$@"
		' rig-run-wrapper "$@" > "$rigTmp/spawn.out" 2>&1 &
	local runPid=$!
	( sleep 120 ; kill -TERM "$runPid" 2> /dev/null ) > /dev/null 2>&1 &
	local runDog=$!
	wait "$runPid"
	rigSpawnRc=$?
	kill -TERM "$runDog" 2> /dev/null
	wait "$runDog" 2> /dev/null || :
	printf '%s' "$rigSpawnRc" > "$rigTmp/spawn.rc"
	## The status is the function's own, so the caller reads it off the pipe: a `printf` last would make
	## every call look successful.
	return "$rigSpawnRc"
}
rigSpawnOut=""
rigSpawnRun(){ ## -- one call, its output in rigSpawnOut and its status in rigSpawnRc
	## The status is taken from PIPESTATUS: the call runs on the right of a pipe, in a subshell, so a
	## variable it set would never reach this check, but the pipe's own status list does.
	printf 'RIG-TASK-TEXT\n' | rigRun "$@"
	rigSpawnRc="${PIPESTATUS[1]}"
	rigSpawnOut="$( cat "$rigTmp/spawn.out" 2> /dev/null )"
}
rigRc(){ ## -- `zero` or `non-zero`, the status of the last --spawn-session call
	[ "${rigSpawnRc:-0}" = 0 ] && printf zero || printf non-zero
}
rigWaitFor(){ ## seconds, test command...
	local rigLeft="$1" ; shift
	while ! "$@" && [ "$rigLeft" -gt 0 ] ; do sleep 1 ; rigLeft=$(( rigLeft - 1 )) ; done
}

## ---- 1. participants on a console that cannot read them ----
echo "-- 1. a session with participants, on a console that never heard of them: refused, and nothing started --"
rigConsole stale
rigSpawnRun --routine-default --participants 'rig-member-b' rig-member-a
rigOut="$rigSpawnOut"
## THE REFUSAL IS READ FROM THE CALLER'S OWN SIDE: the status of the `--spawn-session` call. Its stdout
## is not read for `SETUP_STATUS=console-stale`, because `--spawn-session` captures the proxy's stdout and
## returns 1 without printing it on a failed first start (AgentsTools.MagicSpawnSession.include), so no
## caller of that operation ever sees that line. Exit status and stderr are what a caller has.
rigAssert "the spawn is refused: the call returned non-zero"      "$( rigRc )" non-zero
rigAssert "and no session was started: no SESSION_ID is reported" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^SESSION_ID=' )" 0
rigAssert "the refusal names the console regeneration"          "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c -- '--make-console-command' )" 1
## Scoped to a refusal LINE: a started session also prints `PARTICIPANTS=`, and counting that would
## make this row pass on a tree where no refusal exists at all.
rigAssert "the refusal itself says the console cannot carry the participants" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -i 'ERROR' | LC_ALL=C grep -c -i 'participant' )" 1
rigWaitFor 15 test -s "$rigTmp/console-stale.log"
rigAssert "the stale console was never started"                 "$( [ -s "$rigTmp/console-stale.log" ] && printf yes || printf no )" no

## ---- 2. the same participants on a console that carries them ----
echo "-- 2. the same session on a console that reads the variable: started --"
rigConsole current
rigSpawnRun --routine-default --participants 'rig-member-b' rig-member-a
rigOut="$rigSpawnOut"
rigAssert "a session id is reported"                            "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^SESSION_ID=' )" 1
rigAssert "and the participants are named in it"                "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c -x -F 'PARTICIPANTS=rig-member-b' )" 1
rigWaitFor 20 test -s "$rigTmp/console-current.log"
rigAssert "the console that knows them was started"             "$( [ -s "$rigTmp/console-current.log" ] && printf yes || printf no )" yes

## ---- 3. the control: no participants, so the vintage does not matter ----
echo "-- 3. control: a session with no participant still starts on the older console --"
rigConsole stale
rigSpawnRun --routine-default --participants none rig-member-a
rigOut="$rigSpawnOut"
rigAssert "a session id is reported"                            "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^SESSION_ID=' )" 1
rigWaitFor 20 test -s "$rigTmp/console-stale.log"
rigAssert "and the console was started"                         "$( [ -s "$rigTmp/console-stale.log" ] && printf yes || printf no )" yes

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SPAWN STALE CONSOLE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_STALE_CONSOLE: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
