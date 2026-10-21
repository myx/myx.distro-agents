#!/usr/bin/env bash
## Behavioural check on the per-member lock of the work-duty routine (magic-team.work-duty.routine.md, F4.2's mechanism): one member can
## not run work-duty twice, on this host or on another that shares the team data. Held, run and not read, in a rig of this check's own with
## the real routine file:
##   1. THE ROUTINE declares `routine-lock-document: inbox:{{team-member}}:<note>.md`, and the routine validator takes it.
##   2. A START takes the lock of its member: the note is made at the first start, in the member's processed/ (stamped), never in incoming/,
##      which is the member's work: the schedule reads a non-empty incoming/ as demand, the scans list it and Wait wakes on it.
##   3. A SECOND START FOR THE SAME MEMBER while the first lives is refused at once, with the routine-is-already-running line, before the
##      scan, the brief or any console; another member's start is not; and after the first ends the lock is given back and a start goes through.
##   4. THE MAIN LOOP takes that refusal quietly: the report of its starts (AgentsToolsScheduleSpawnReport) says nothing of it, and still says
##      the first error of any other failed start.
##   5. A JUST AGENTS WORKSPACE keeps no board for the duty to work: a start of work-duty (or of any routine that locks a document) is refused at once
##      with the gate's own line, and makes nothing; a standalone routine that locks nothing starts there.
## Offline: a fake curl first on PATH; every tree is this rig's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTest="$rigPackage/sh-test"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRoutineFile="$rigPackage/skillset/magic-team/magic-team/magic-team.work-duty.routine.md"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] && [ -f "$rigRoutineFile" ] || rigRefuse "the tool or the work-duty routine is not at the origin this workspace resolves"
## A spawn of this rig starts its session's control thread, which outlives this check: the rig ends it.
. "$rigTest/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package"
. "$rigTest/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsWorkDutyLockCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap ': > "$rigTmp/release" ; chmod -R u+w -- "$rigTmp" 2>/dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigSkills="$rigTmp/skills" rigData="$rigTmp/data"
rigNoteName="note-20261020T000000Z-work-duty-state-and-lock.md"
rigKeeperIncoming="$rigData/inboxes/rig-keeper/incoming" rigKeeperProcessed="$rigData/inboxes/rig-keeper/processed"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigSkills/magic-team" "$rigSkills/rig-keeper" "$rigSkills/rig-other" "$rigData/board"
cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"
cp "$rigRoutineFile" "$rigSkills/magic-team/magic-team.work-duty.routine.md"
## The console stand-in: it records the brief and the run's lock note, says it is live, and holds until the rig releases it.
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records the context.' \
	'rigN="$( ls "$RIG_SCENARIO"/brief.* 2> /dev/null | wc -l | tr -d " " )"' \
	'cat > "$RIG_SCENARIO/brief.$MDAT_SPAWN_AGENT.$rigN"' \
	'cp "$RIG_DATA/inboxes/$MDAT_SPAWN_AGENT/processed/note-20261020T000000Z-work-duty-state-and-lock.md" "$RIG_SCENARIO/seen.$MDAT_SPAWN_AGENT.$rigN" 2> /dev/null || :' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' \
	': > "$RIG_SCENARIO/live.$MDAT_SPAWN_AGENT.$rigN"' \
	'rigWaited=0 ; while [ ! -e "$RIG_SCENARIO/release" ] && [ "$rigWaited" -lt 120 ] ; do sleep 1 ; rigWaited=$(( rigWaited + 1 )) ; done' \
	'printf "📦 SubagentHandback\n"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"
for rigMember in rig-keeper rig-other ; do
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
	printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
done
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nWAIT_COLLECT_SECONDS=1\nMDAT_WORKSPACE_MODE=team-rig\n' > "$rigWs/.local/.agents/magic-team.agent.env"
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigSpawn(){ ## the member to start, the result name -- the start of the work-duty routine, waited on; rc in <name>.rc
	local spawnMember="$1" spawnName="$2"
	env -i MDAT_WORKSPACE_MODE="${rigModeEnv:-team-rig}" HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" RIG_DATA="$rigData" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy "$@"
		' rig-work-duty "$spawnMember" --routine magic-team.work-duty --session-new --dispatch-doc:none --wait <<< "RIG-TASK-TEXT" > "$rigTmp/$spawnName.out" 2>&1
	printf '%s' "$?" > "$rigTmp/$spawnName.rc"
}
rigField(){ ## file, field
	LC_ALL=C awk -v want="$2: " 'NR == 1 { next ; } $0 == "---" { exit ; } index( $0, want ) == 1 { print substr( $0, length( want ) + 1 ) ; exit ; }' "$1" 2> /dev/null
}
rigWaitFor(){ ## file -- up to 90 seconds
	local waitLeft=90
	while [ ! -e "$1" ] && [ "$waitLeft" -gt 0 ] ; do sleep 1 ; waitLeft=$(( waitLeft - 1 )) ; done
}

echo "-- 1. the routine and the validator --"
rigAssert "the real work-duty routine declares the per-member lock" "$( LC_ALL=C grep -c -x "routine-lock-document: inbox:{{team-member}}:$rigNoteName" "$rigRoutineFile" || : )" 1
rigOut="$( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" bash "$rigTool" --intern-doc-validate routine "$rigRoutineFile" 2>&1 < /dev/null ; echo "rc=$?" )"
rigAssert "the routine validator takes it: no row, rc 0" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^rc=0$' ):$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'routine-lock-document' || : )" "1:0"

echo "-- 2 and 3. the first start, a second one, another member's, and the start after the end --"
rm -f "$rigTmp/release"
rigSpawn rig-keeper first &
rigFirstPid=$!
rigWaitFor "$rigTmp/live.rig-keeper.0"
rigAssert "the first start runs: briefed, live" "$( [ -e "$rigTmp/live.rig-keeper.0" ] && echo live || echo none )" live
rigAssert "its lock note was made in the keeper's processed/, with the stamp of that folder" "$( [ -f "$rigKeeperProcessed/$rigNoteName" ] && echo there || echo missing ):$( [ -n "$( rigField "$rigKeeperProcessed/$rigNoteName" processed-at )" ] && echo stamped || echo unstamped )" "there:stamped"
rigAssert "live: work-duty-running, with a session id" "$( rigField "$rigTmp/seen.rig-keeper.0" state ):$( [ -n "$( rigField "$rigTmp/seen.rig-keeper.0" session-id )" ] && echo id || echo none )" "work-duty-running:id"
rigAssert "the keeper's incoming/ holds nothing: the lock is no work, no demand" "$( ls -A "$rigKeeperIncoming" 2> /dev/null | LC_ALL=C grep -c . || : )" 0
## The wait of the run keeps the lock held: nothing while the last write is young, a fresh recheck-date once it is older than half the hold.
rigSpawnId="$( ls "$rigWs"/.local/agents/spawned/*/*.spawn.md 2> /dev/null | LC_ALL=C sed -n '1s#.*/##p' | LC_ALL=C sed 's#\.spawn\.md$##' )"
rigEpochOf(){ ## a recheck-date
	printf '%s\n' "$1" | LC_ALL=C awk -f "$rigPackage/../myx.distro-.local/sh-lib/output/LocalIsoToEpoch.awk" 2> /dev/null
}
rigWaitOnce(){ ## one wait of the live run, as its own process
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SPAWN_SESSION_ID="$rigSpawnId" MDAT_SPAWN_AGENT=rig-keeper perl -e 'alarm 60 ; exec @ARGV' bash "$rigTool" --wait-for-input rig-keeper --wait-timeout 1 < /dev/null > /dev/null 2>&1 )
}
rigLockNote="$rigKeeperProcessed/$rigNoteName"
rigBeforeSum="$( cksum < "$rigLockNote" )"
rigWaitOnce
rigAssert "a wait while the lock is young changes nothing" "$( cksum < "$rigLockNote" )" "$rigBeforeSum"
rigAhead="$( env -i MDLT_ORIGIN="$MDLT_ORIGIN" MMDAPP="$rigWs" bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/board/AgentsTools.RecheckDate.include" ; AgentsToolsRecheckDate 10' 2> /dev/null )"
sed -i.bak "s/^recheck-date: .*/recheck-date: $rigAhead/" "$rigLockNote" && rm -f "$rigLockNote.bak"
rigWaitOnce
rigAfterLeft=$(( $( rigEpochOf "$( rigField "$rigLockNote" recheck-date )" ) - $( date +%s ) ))
rigAssert "a wait once the last write is older than half the hold puts the recheck-date a hold ahead again (to more than 100 minutes)" "$( [ "$rigAfterLeft" -gt 6000 ] && echo refreshed || echo "left:$rigAfterLeft" ):$( rigField "$rigLockNote" state )" "refreshed:work-duty-running"
rigStart="$( date +%s )"
rigSpawn rig-keeper second
rigSecondSeconds=$(( $( date +%s ) - rigStart ))
rigAssert "a second start for the same member is refused, rc 1" "$( cat "$rigTmp/second.rc" )" 1
rigAssert "with the routine-is-already-running line, naming the keeper's document" "$( LC_ALL=C grep -c -F "the routine is already running: its locking document $rigNoteName (rig-keeper)" "$rigTmp/second.out" || : )" 1
rigAssert "at once: in seconds, with no brief and no console for it" "$( [ "$rigSecondSeconds" -le 20 ] && echo fast || echo "slow:$rigSecondSeconds" ):$( ls "$rigTmp"/brief.rig-keeper.* 2> /dev/null | LC_ALL=C grep -c . || : )" "fast:1"
rigSpawn rig-other third &
rigThirdPid=$!
rigWaitFor "$rigTmp/live.rig-other.1"
rigAssert "another member's start is not refused: its own note" "$( [ -e "$rigTmp/live.rig-other.1" ] && echo live || echo none ):$( [ -f "$rigData/inboxes/rig-other/processed/$rigNoteName" ] && echo there || echo missing )" "live:there"
: > "$rigTmp/release"
wait "$rigFirstPid" "$rigThirdPid"
rigAssert "the first start ended well, and gave the lock back: work-duty-finished" "$( cat "$rigTmp/first.rc" ):$( rigField "$rigKeeperProcessed/$rigNoteName" state )" "0:work-duty-finished"
rigSpawn rig-keeper fourth
rigAssert "after the end a start for the keeper goes through again" "$( cat "$rigTmp/fourth.rc" ):$( ls "$rigTmp"/brief.rig-keeper.* 2> /dev/null | LC_ALL=C grep -c . || : )" "0:2"
rigAssert "and still nothing of the lock in the keeper's incoming/" "$( ls -A "$rigKeeperIncoming" 2> /dev/null | LC_ALL=C grep -c . || : )" 0

echo "-- 4. the main loop takes the refusal quietly --"
rigStore="$rigWs/.local/agents/schedule/starting"
mkdir -p "$rigStore"
cp "$rigTmp/second.out" "$rigStore/work-duty.rig-keeper.out" ; printf '1\n' > "$rigStore/work-duty.rig-keeper.rc"
printf '%s\n' "⛔ ERROR: DistroAgentsTools: rig failure of another kind" > "$rigStore/work-duty.rig-other.out" ; printf '1\n' > "$rigStore/work-duty.rig-other.rc"
printf 'ok\n' > "$rigStore/work-duty.rig-fine.out" ; printf '0\n' > "$rigStore/work-duty.rig-fine.rc"
rigReport="$( env -i HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
	bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.DispatcherLoop.include" ; AgentsToolsScheduleSpawnReport' 2>&1 )"
rigAssert "a start the lock refused is not reported" "$( printf '%s\n' "$rigReport" | LC_ALL=C grep -c 'work-duty.rig-keeper' || : )" 0
rigAssert "a start that failed otherwise still is, with its first error" "$( printf '%s\n' "$rigReport" | LC_ALL=C grep -c -F 'schedule: the start of work-duty.rig-other failed: ⛔ ERROR: DistroAgentsTools: rig failure of another kind' || : )" 1
rigAssert "a start that went well is not" "$( printf '%s\n' "$rigReport" | LC_ALL=C grep -c 'rig-fine' || : )" 0
rigAssert "their files are gone" "$( ls "$rigStore" | LC_ALL=C grep -c . || : )" 0

echo "-- 5. a Just Agents workspace has no board for the duty to work: the start is refused --"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nWAIT_COLLECT_SECONDS=1\nMDAT_WORKSPACE_MODE=just-agents\n' > "$rigWs/.local/.agents/magic-team.agent.env"
rm -rf "$rigData" ; mkdir -p "$rigData" ; rm -f "$rigTmp"/live.* "$rigTmp"/brief.*
chmod -R u+w -- "$rigWs/.local/agents" 2> /dev/null ; rm -rf "$rigWs/.local/agents/spawned"
rigModeEnv=just-agents
rigStart="$( date +%s )"
rigSpawn rig-keeper justagents
rigJustSeconds=$(( $( date +%s ) - rigStart ))
rigAssert "work-duty is refused, rc 1, with the gate's own line naming the start" "$( cat "$rigTmp/justagents.rc" ):$( LC_ALL=C grep -c -F -e 'magic-team.work-duty.routine.md: this workspace keeps no team data' "$rigTmp/justagents.out" || : )" "1:1"
rigAssert "at once, with no brief, no console, no note, nothing in the team data" "$( [ "$rigJustSeconds" -le 20 ] && echo fast || echo "slow:$rigJustSeconds" ):$( ls "$rigTmp"/brief.* 2> /dev/null | LC_ALL=C grep -c . || : ):$( find "$rigData" -mindepth 1 2> /dev/null | LC_ALL=C grep -c . || : )" "fast:0:0"
## A standalone routine that locks nothing runs there.
{
	printf -- '---\ntype: routine\nexecutors: rig-keeper\nmaintainers: rig-keeper\nrequires-session-kind: standalone\n---\n'
	printf '# rig-keeper.plain.routine — the actual procedure\n\n# Summary\n\nA rig routine.\n\n# Opening steps\n\n1. **open**: open.\n\n# Steps\n\n1. **work**: work.\n\n# Closure steps\n\n1. **close**: close.\n\n'
	printf "# Routine's local procedures\n\nNone.\n\n# Routine's local rules\n\nNone.\n\n# Routine-specific tooling\n\nNone.\n\n# Maintainer Notes\n\nNone.\n"
} > "$rigSkills/rig-keeper/rig-keeper.plain.routine.md"
env -i MDAT_WORKSPACE_MODE=just-agents HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
	MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" RIG_DATA="$rigData" \
	bash -c 'case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac ; cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy "$@"' rig-plain rig-keeper --routine rig-keeper.plain --session-new --dispatch-doc:none --wait <<< "RIG-TASK-TEXT" > "$rigTmp/plain.out" 2>&1
rigAssert "a standalone routine with no lock starts there: rc 0, briefed, nothing in the team data" "$?:$( ls "$rigTmp"/brief.rig-keeper.* 2> /dev/null | LC_ALL=C grep -c . || : ):$( find "$rigData" -mindepth 1 2> /dev/null | LC_ALL=C grep -c . || : )" "0:1:0"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ WORK DUTY LOCK CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'WORK_DUTY_LOCK: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
