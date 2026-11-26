#!/usr/bin/env bash
## Behavioural check on the ending a killed run reads (S12.15's failed-session part): a run the console ended on
## purpose is an ordered end, never a death. The console marks the record before it signals (`killed-by`,
## `killed-at`, AgentsToolsManagerKillMark), and the run's supervising shell then closes that record with a
## non-zero exit -- the very word, `spawn-failed`, a start that died on its own carries. So the status word cannot
## tell the two apart, and a killed run read `failed`: the console's list showed it as work that broke, and
## `--close-failed-sessions` took its session again as a failure to close.
## Held here, run rather than read, against a store of this check's own:
##   1. A KILLED RUN READS FINISHED, in both derivations the tooling asks.
##   2. AND THE ROW THE CONSOLE'S LIST PRINTS FOR IT READS FINISHED.
##   3. A RUN THAT FAILED ON ITS OWN STILL READS FAILED, so the mark is what decides and not the status word.
##   4. A KILLED RUN THAT IS STILL RUNNING IS NEVER FINISHED: liveness is read before any mark.
## RED RECIPE: drop the mark's own answer from either derivation, and rows 1 and 2 fail while rows 3 and 4 keep theirs.
## Offline: the includes and a store of this rig's own. No process of the host is signalled, no socket opened.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigState="$rigPackage/sh-lib/run/AgentsTools.RunState.include"
rigRegistries="$rigPackage/sh-lib/session/AgentsTools.RegistrySpawnedSessions.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigNeeded in "$rigState" "$rigRegistries" ; do
	[ -f "$rigNeeded" ] || rigRefuse "the package is not at the origin this workspace resolves: $rigNeeded"
done
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsKilledRunReadsFinishedCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigWs="$rigTmp/ws"
rigHome="$rigTmp/home"
rigData="$rigTmp/data"
rigAgents="$rigWs/.local/agents"
rigSpawned="$rigAgents/spawned"
rigStores="$rigAgents/sessions"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigSpawned" "$rigStores" "$rigAgents/pending" "$rigData/board/running" "$rigHome"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
: > "$rigAgents/pending-replies.registry"

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
	return 0
}
rigInRig(){ ## the include, the program, then its arguments -- run in the rig's own workspace
	local rigInclude="$1" rigProgram="$2"
	shift 2
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SPAWN_AGENT=keeper-rig MDAT_SEND_FLOOR=none MDAT_SCHEDULE_THREAD=off AGENTS_REGISTRY_HOUSEKEEPING=off \
		RIG_INCLUDE="$rigInclude" RIG_STATE="$rigState" RIG_REGISTRIES="$rigRegistries" \
		bash "$rigProgram" "$@" 2>&1 )
}

## A RECORD, as the proxy writes one: its folder, its spawn id, its session id, its status, further frontmatter lines.
## The family's own form (AgentsSettledRunReadsFinishedCheck's rigRecord): a spawn record, not a board item.
rigRecord(){ ## folder, spawn id, session id, status, further frontmatter lines (may be empty)
	mkdir -p "$rigSpawned/$1" "$rigStores/$3"
	{
		printf -- '---\nsession-id: %s\nspawn-id: %s\ntracking-name: %s\nhost: rig\nworkspace: rigws\nowner: keeper-rig\nstatus: %s\n' \
			"$3" "$2" "$1" "$4"
		[ -z "${5:-}" ] || printf '%s\n' "$5"
		printf -- '---\n\n# Spawn session: %s\n' "$3"
	} > "$rigSpawned/$1/$2.spawn.md"
}
## What the console leaves behind: the mark written before the signal, and the word its shell then closes with.
rigKillMark='killed-by: rig
killed-at: 2026-11-25 09:00 +0200
resolved-at: 2026-11-25 09:05 +0200'
rigRecord kill-sess kill-run kill-sess spawn-failed "$rigKillMark"
rigRecord fail-sess fail-run fail-sess spawn-failed 'resolved-at: 2026-11-25 09:05 +0200'

## ONE DERIVATION, in a shell of its own with only the state include loaded: status, live, session id, run id.
cat > "$rigTmp/state.sh" <<'RIGSTATE'
rigForm="$1" rigStatus="$2" rigLive="$3" rigSession="$4" rigRun="$5" ; set --
. "$RIG_STATE" || exit 1
if [ "$rigForm" = forking ] ; then
	AgentsToolsRunDeriveState "$rigStatus" "$rigLive" "$rigSession" "$rigRun"
else
	AgentsToolsRunDeriveStateFromSet "$rigStatus" "$rigLive" "$rigSession" "" "$rigRun"
	printf '%s\n' "$derivedState"
fi
RIGSTATE
rigDerive(){ ## form, status, live, session id, run id
	rigInRig "$rigState" "$rigTmp/state.sh" "$@" | tail -n 1
}
## THE STATE THE CONSOLE'S LIST PRINTS, off the registry rebuilt from the records as they stand.
cat > "$rigTmp/row.sh" <<'RIGROW'
rigSession="$1" ; set --
. "$RIG_REGISTRIES" || exit 1
AgentsToolsRegistrySpawnedSessionsRebuild || exit 1
AgentsToolsRegistryMeasureRows "$MMDAPP/.local/agents/spawned-sessions.registry" rig "$rigSession" 16 fresh > /dev/null || exit 1
printf '%s\n' "$measuredRows" | LC_ALL=C awk -v want="$rigSession" '$2 == want { printf "%s", ( said++ ? "/" : "" ) $13 ; }'
RIGROW
rigRowOf(){ ## session id -- the state its run's row reads; a reader that cannot run stops the check
	local rowSaid
	rowSaid="$( rigInRig "$rigRegistries" "$rigTmp/row.sh" "$1" | tail -n 1 )"
	case "$rowSaid" in *'>'*|*ERROR*|*'No such file'*) rigRefuse "the rig's own row reader did not run, so this row would report on nothing: $rowSaid" ;; esac
	printf '%s\n' "$rowSaid"
}

echo "-- 1. a killed run reads finished, and not failed --"
rigAssert "control: a start that died on its own, closed as failed with no mark, reads failed" \
	"$( rigDerive forking spawn-failed gone fail-sess fail-run )" "failed"
rigAssert "the same record carrying the console's mark reads finished: an ordered end is no death" \
	"$( rigDerive forking spawn-failed gone kill-sess kill-run )" "finished"
rigAssert "and the derivation without a fork gives the same two answers" \
	"$( rigDerive set spawn-failed gone fail-sess fail-run ) $( rigDerive set spawn-failed gone kill-sess kill-run )" "failed finished"

echo "-- 2. the session row the console's list prints says the same --"
rigAssert "the killed run's row reads finished"  "$( rigRowOf kill-sess )" "finished"
rigAssert "control: the failed run's row reads failed" "$( rigRowOf fail-sess )" "failed"

echo "-- 3. a killed run that is still alive is never finished --"
## The activity word of a live run comes from a mark this rig does not write, so an empty answer is that
## word's own. Held here is the one thing the mark must not do to a live run: answer finished or failed.
## The row is not asserted here: a row reads live only for a process this rig would have to start, and the
## liveness order is the derivation's own, which is what this row holds.
rigAssert "a live run carrying the mark answers neither finished nor failed" \
	"$( rigDerive forking spawn-failed running kill-sess kill-run | LC_ALL=C grep -c -x -e finished -e failed || : )" "0"
rigAssert "and the same in the derivation without a fork" \
	"$( rigDerive set spawn-failed running kill-sess kill-run | LC_ALL=C grep -c -x -e finished -e failed || : )" "0"

echo
if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ KILLED RUN READS FINISHED CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
echo "KILLED_RUN_READS_FINISHED: OK ($rigPass assertions, offline, rig store only)"
