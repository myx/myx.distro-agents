#!/usr/bin/env bash
## Behavioural check on the five routines that locked by hand before the spawner did (F6.2): advance, daily, grooming,
## heartbeat and retro keep their standing state-and-lock notes, and the spawner now takes and gives back their locks
## through their own acquire and close operations, so what those do still happens, and what they print reaches the run.
## A routine names several locks in `routine-lock-document:`, separated by commas, as a routine that runs another inline does.
## Held, with the daily routine (a rig copy with the real lock note names):
##   1. while its run is live, the note is `daily-running` with the session's id, and the run's brief carries a
##      `## Routine lock` section holding the acquire's `first-today: yes` (the note has no last-close-date today)
##   2. once the run has ended, the note is `daily-finished` and carries `last-close-date:` of today, as the daily's own
##      close stamps it
##   3. a second start of the same day, the note now holding today's last-close-date, is told `first-today: no`
##   4. a routine naming two locks (heartbeat and advance): both are running while it lives, both finished after
## Offline: a fake curl first on PATH; every tree is this rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTest="$rigPackage/sh-test"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
## A spawn of this rig starts its session's control thread, which outlives this check: the rig ends it.
. "$rigTest/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsRoutineLockOwnOpsCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data"
rigInbox="$rigData/inboxes/magic-coordinator/incoming"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigSkills/magic-team" "$rigData/board" "$rigInbox"
cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"
rigDaily="note-20260811T120000Z-daily-state-and-lock.md"
rigHeartbeat="note-20260809T155000Z-heartbeat-state-and-lock.md"
rigAdvance="note-20260809T154715Z-advance-state-and-lock.md"
## The console stand-in: while the run is live it copies the brief and the three notes.
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records the context.' \
	'cat > "$RIG_SCENARIO/brief.$MDAT_SPAWN_AGENT"' \
	'for n in note-20260811T120000Z-daily-state-and-lock.md note-20260809T155000Z-heartbeat-state-and-lock.md note-20260809T154715Z-advance-state-and-lock.md ; do cp "$RIG_INBOX/$n" "$RIG_SCENARIO/seen.$n" 2> /dev/null || : ; done' \
	'printf "📦 SubagentHandback\n"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"
mkdir -p "$rigSkills/magic-coordinator"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"
printf '# rig armed\n' > "$rigSkills/magic-coordinator/magic-coordinator.armed.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
rigNote(){ ## note name, state
	printf -- '---\ntype: note\nfrom: magic-coordinator\nowner: magic-coordinator\nstate: %s\n---\n\nThe state of %s.\n' "$2" "$1" > "$rigInbox/$1"
}
rigRoutine(){ ## short name, the lock documents (a list)
	{
		printf -- '---\ntype: routine\nexecutors: magic-coordinator\nmaintainers: magic-coordinator\nrequires-session-kind: standalone\nroutine-lock-document: %s\n---\n' "$2"
		printf '# magic-coordinator.%s.routine — the actual procedure\n\n# Summary\n\nA rig routine.\n\n# Opening steps\n\n1. **open**: open.\n\n# Steps\n\n1. **work**: work.\n\n# Closure steps\n\n1. **close**: close.\n\n' "$1"
		printf "# Routine's local procedures\n\nNone.\n\n# Routine's local rules\n\nNone.\n\n# Routine-specific tooling\n\nNone.\n\n# Maintainer Notes\n\nNone.\n"
	} > "$rigSkills/magic-coordinator/magic-coordinator.$1.routine.md"
}
rigRoutine daily "inbox:magic-coordinator:$rigDaily"
rigRoutine both "inbox:magic-coordinator:$rigHeartbeat,inbox:magic-coordinator:$rigAdvance"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigSpawn(){ ## routine short name
	rm -f "$rigTmp"/brief.* "$rigTmp"/seen.*
	rm -rf "$rigData/board" ; mkdir -p "$rigData/board"
	chmod -R u+w -- "$rigWs/.local/agents" 2> /dev/null ; rm -rf "$rigWs/.local/agents/spawned"
	rigRc=0
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" RIG_INBOX="$rigInbox" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy "$@"
		' rig-own-ops magic-coordinator --routine "$1" --session-new --dispatch-doc:none --wait <<< "RIG-TASK-TEXT" > "$rigTmp/spawn.out" 2>&1 || rigRc=$?
}
rigField(){ ## file, field
	LC_ALL=C awk -v want="$2: " 'NR == 1 { next ; } $0 == "---" { exit ; } index( $0, want ) == 1 { print substr( $0, length( want ) + 1 ) ; exit ; }' "$1" 2> /dev/null
}

echo "-- 1-2. the daily: locked while it lives, finished after, last-close-date stamped --"
rigNote "$rigDaily" "daily-finished"
rigSpawn daily
rigAssert "the start runs" "$rigRc:$( [ -e "$rigTmp/brief.magic-coordinator" ] && echo briefed || echo none )" "0:briefed"
rigAssert "live: the note is daily-running with a session id" "$( rigField "$rigTmp/seen.$rigDaily" state ):$( [ -n "$( rigField "$rigTmp/seen.$rigDaily" session-id )" ] && echo id || echo none )" "daily-running:id"
rigAssert "the brief's Routine lock section holds first-today: yes" "$( LC_ALL=C awk '/^## Routine lock/ { on = 1 ; next } on && /^first-today: / { print ; exit }' "$rigTmp/brief.magic-coordinator" )" "first-today: yes"
rigAssert "after: daily-finished with today's last-close-date" "$( rigField "$rigInbox/$rigDaily" state ):$( rigField "$rigInbox/$rigDaily" last-close-date )" "daily-finished:$( date +%Y-%m-%d )"
echo "-- 3. the next start of the day --"
rigSpawn daily
rigAssert "is told first-today: no" "$( LC_ALL=C awk '/^## Routine lock/ { on = 1 ; next } on && /^first-today: / { print ; exit }' "$rigTmp/brief.magic-coordinator" )" "first-today: no"
echo "-- 4. two locks --"
rigNote "$rigHeartbeat" "heartbeat-finished" ; rigNote "$rigAdvance" "advance-finished"
rigSpawn both
rigAssert "live: both notes are running" "$( rigField "$rigTmp/seen.$rigHeartbeat" state ):$( rigField "$rigTmp/seen.$rigAdvance" state )" "heartbeat-running:advance-running"
rigAssert "after: both finished" "$( rigField "$rigInbox/$rigHeartbeat" state ):$( rigField "$rigInbox/$rigAdvance" state )" "heartbeat-finished:advance-finished"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROUTINE LOCK OWN OPS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ROUTINE_LOCK_OWN_OPS: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
