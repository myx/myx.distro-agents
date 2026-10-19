#!/usr/bin/env bash
## Behavioural check on a routine's own lock (F6.2 of the refactorings epic, with F4.2's per-member lock: open-names 9,
## 10 and 33): a routine names its lock in frontmatter, `routine-lock-document: inbox:<member>:<note>.md`, a note in the
## inbox of its executor or of a named member. The spawner locks while starting the routine, or fails; it adds the
## locking document to the dispatch; and it unlocks when the routine finishes. Two members lock two notes, so they never
## contend, as the advance's one fixed note made them do.
## Run through the spawn proxy, the start every routine goes through, with a stand-in console that holds its run until
## the rig releases it, and runs no model.
## Held:
##   1. a start of a locking routine runs, and its brief names the locking document
##   2. while that run holds the lock, a second start of the same routine fails, exit non-zero, before any step runs (no
##      brief is handed to a console), and the refusal names the locking document
##   3. a routine of another member, locking its own note, starts while the first lock is held
##   4. once the first run has finished, the routine starts again: the lock was given back by itself
##   5. a locking document that does not exist yet (the routine's own state before its first start) is made by that start, and locked
## Red before F6.2: no routine-lock-document: is read (1's brief and 2 fail).
## Offline: a fake curl first on PATH; the team data of the rig is a plain folder, with no git remote.
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
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsRoutineLockCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigRelease(){ : > "$rigTmp/release.all" ; wait 2> /dev/null ; }
trap 'rigRelease ; chmod -R u+w -- "$rigTmp" 2>/dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/bin" "$rigSkills/magic-team" "$rigData/board" "$rigData/inboxes/keeper-rig/incoming" "$rigData/inboxes/keeper-other/incoming"
cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"
## The console: records its brief under its own number, then holds until the rig releases it, a minute at most.
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records the context.' \
	'rigNo="$( ls "$RIG_SCENARIO"/brief.* 2> /dev/null | wc -l | tr -d " " )"' \
	'cat > "$RIG_SCENARIO/brief.$MDAT_SPAWN_AGENT.$rigNo"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' \
	'rigLeft=300 ; while [ ! -e "$RIG_SCENARIO/release.all" ] && [ ! -e "$RIG_SCENARIO/release.$MDAT_SPAWN_AGENT" ] && [ "$rigLeft" -gt 0 ] ; do sleep 0.2 ; rigLeft=$(( rigLeft - 1 )) ; done' \
	'printf "📦 SubagentHandback\n"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"
for rigMember in keeper-rig keeper-other magic-coordinator ; do
	mkdir -p "$rigSkills/$rigMember"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/$rigMember/$rigMember.basic.md"
	printf '# rig armed\n' > "$rigSkills/$rigMember/$rigMember.armed.md"
done
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
## Each member's lock note, as the advance's own is written, and a routine that names it.
rigLocking(){ ## member, short name
	local lockNote="note-20261019T0000Z-$2-state-and-lock.md"
	printf -- '---\ntype: note\nfrom: %s\nowner: %s\nstate: idle\n---\n\nThe state of %s.\n' "$1" "$1" "$2" > "$rigData/inboxes/$1/incoming/$lockNote"
	printf -- '---\ntype: routine\nexecutors: %s\nmaintainers: magic-coordinator\nrequires-session-kind: standalone\nroutine-lock-document: inbox:%s:%s\n---\n# magic-team.%s.routine — the actual procedure\n\n# Summary\n\nA rig routine that locks its note.\n\n# Opening steps\n\n1. **open**: open.\n\n# Steps\n\n1. **work**: work.\n\n# Closure steps\n\n1. **close**: close.\n\n' "$1" "$1" "$lockNote" "$2" > "$rigSkills/magic-team/magic-team.$2.routine.md"
	printf "# Routine's local procedures\n\nNone.\n\n# Routine's local rules\n\nNone.\n\n# Routine-specific tooling\n\nNone.\n\n# Maintainer Notes\n\nNone.\n" >> "$rigSkills/magic-team/magic-team.$2.routine.md"
}
rigLocking keeper-rig riglock
rigLocking keeper-other rigbetalock
## A routine whose locking document does not exist before its first start (its own state, a note of no standing name).
rigLocking keeper-rig rigfresh
rm -f "$rigData/inboxes/keeper-rig/incoming/note-20261019T0000Z-rigfresh-state-and-lock.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One start of a member's routine through the spawn proxy, waiting for its run; its output in $rigTmp/<name>.out and
## its exit in <name>.rc. With `&` after it, the start runs beside the rig until its console is released.
rigSpawn(){ ## result name, member, routine short name
	local spawnRc=0
	env -i HOME="$rigTmp" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy "$@"
		' rig-lock "$2" --routine "$3" --session-new --dispatch-doc:none --wait <<< "RIG-TASK-TEXT" > "$rigTmp/$1.out" 2>&1 || spawnRc=$?
	printf '%s' "$spawnRc" > "$rigTmp/$1.rc"
}
rigBriefs(){ ## member -- how many briefs its consoles were handed
	ls "$rigTmp"/brief."$1".* 2> /dev/null | LC_ALL=C grep -c . || :
}
rigWaitBriefs(){ ## member, how many -- waits up to fifteen seconds for that many briefs
	local briefsLeft=75
	while [ "$( rigBriefs "$1" )" -lt "$2" ] && [ "$briefsLeft" -gt 0 ] ; do sleep 0.2 ; briefsLeft=$(( briefsLeft - 1 )) ; done
}

echo "-- 1. a locking routine starts, and its brief names the locking document --"
rigSpawn first keeper-rig riglock &
rigFirstJob=$!
rigWaitBriefs keeper-rig 1
rigAssert "the first start runs: its console is handed a brief"   "$( rigBriefs keeper-rig )" "1"
rigAssert "the brief names the locking document"                  "$( LC_ALL=C grep -c -F 'note-20261019T0000Z-riglock-state-and-lock.md' "$rigTmp"/brief.keeper-rig.0 2> /dev/null | LC_ALL=C sed -e 's/^[1-9][0-9]*$/named/' )" "named"

echo "-- 2. while it holds the lock, a second start fails before any step runs --"
rigSpawn second keeper-rig riglock
rigAssert "the second start: exit non-zero, no brief handed, the locking document named" \
	"$( [ "$( cat "$rigTmp/second.rc" )" -ne 0 ] && echo refused || echo started ):$( rigBriefs keeper-rig ):$( LC_ALL=C grep -c -F 'riglock-state-and-lock.md' "$rigTmp/second.out" | LC_ALL=C sed -e 's/^[1-9][0-9]*$/named/' )" "refused:1:named"

echo "-- 3. another member's routine, locking its own note, starts meanwhile --"
rigSpawn other keeper-other rigbetalock &
rigOtherJob=$!
rigWaitBriefs keeper-other 1
rigAssert "the other member's start runs while the first lock is held" "$( rigBriefs keeper-other )" "1"

echo "-- 4. once the first run has finished, the routine starts again --"
: > "$rigTmp/release.keeper-rig"
wait "$rigFirstJob" 2> /dev/null
rm -f "$rigTmp/release.keeper-rig"
rigSpawn third keeper-rig riglock &
rigThirdJob=$!
rigWaitBriefs keeper-rig 2
rigAssert "a new start runs: the lock was given back when the run finished" "$( rigBriefs keeper-rig )" "2"

echo "-- 5. a locking document that does not exist yet is made by the first start, and locked --"
rigFreshNote="$rigData/inboxes/keeper-rig/incoming/note-20261019T0000Z-rigfresh-state-and-lock.md"
rigAssert "control: no document before the start" "$( [ -f "$rigFreshNote" ] && echo there || echo none )" "none"
rigSpawn fresh keeper-rig rigfresh &
rigFreshJob=$!
rigWaitBriefs keeper-rig 3
rigAssert "the start runs, and the document is there, locked by a session, in the state of its routine" \
	"$( rigBriefs keeper-rig ):$( LC_ALL=C grep -c '^state: rigfresh-running$' "$rigFreshNote" 2> /dev/null ):$( LC_ALL=C grep -c '^session-id: .' "$rigFreshNote" 2> /dev/null )" "3:1:1"
rigRelease

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROUTINE LOCK CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ROUTINE_LOCK: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
