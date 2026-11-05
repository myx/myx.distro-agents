#!/usr/bin/env bash
## Behavioural check on S6.14: a settled run shows finished, and an accept is no provider refusal.
## The owner's case, end to end: a run handed back and parked, and the accept of its item then settled it, so
## its store kept a mark whose verdict had already arrived. The mark alone held the session in
## `awaiting-review` for good -- session d3206c74 on MEL read so from 2 November, its item in `processed`.
## Three things are held here, each measured on a rig workspace of this check's own:
##   - a close takes its run's mark away, even where the record has already settled, so no new one is left;
##   - the pass over dead spawns clears a mark an accept left, so a store kept from before that fix is freed;
##   - an accept's own words in a run's store are no provider refusal, on its session row and in its end notice.
## Controls, both directions: an open record with a mark still reads parked and its session still waits, a
## settled record with no mark still reads finished, a record that failed on its start still reads failed, a
## waiting run's mark survives the pass, and a refusal the harness kept is still flagged. A fix that ignores
## every mark, sweeps every mark, or hides every flag fails here.
## Offline: the workspace, its records, its stores and its board are this rig's own temp tree. No socket.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPkg="${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}/myx/myx.distro-agents"
rigRegistries="$rigPkg/sh-lib/team-data/AgentsTools.Registries.include"
rigSandbox="$rigPkg/sh-lib/session/AgentsTools.SpawnSandbox.include"
rigControl="$rigPkg/sh-lib/session/AgentsTools.InternSessionControl.include"
rigHousekeeping="$rigPkg/sh-lib/session/AgentsTools.SpawnSandbox.include"
rigRowsAwk="$rigPkg/sh-lib/manager/AgentsManagerSessionRows.awk"
rigTokensAwk="$rigPkg/sh-lib/manager/AgentsManagerSessionTokens.awk"
rigMinutesAwk="$rigPkg/sh-lib/manager/AgentsManagerDateMinutes.awk"
rigTools="$rigPkg/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigNeeded in "$rigRegistries" "$rigSandbox" "$rigControl" "$rigRowsAwk" "$rigTokensAwk" "$rigMinutesAwk" "$rigTools" ; do
	[ -f "$rigNeeded" ] || rigRefuse "the package is not at the origin this workspace resolves: $rigNeeded"
done
mkdir -p "$MMDAPP/.local/temp"
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsSettledRunReadsFinishedCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
rigAgents="$rigWs/.local/agents"
rigSpawned="$rigAgents/spawned"
rigStores="$rigAgents/sessions"
mkdir -p "$rigWs/.local/.agents" "$rigData/board/processed" "$rigSpawned" "$rigStores" "$rigAgents/pending"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
: > "$rigAgents/pending-replies.registry"
rigHost="$( hostname -s 2> /dev/null )" || rigHost="unknown"

## The readings this check makes, each a program of the rig's own: one call asked of the package's own reader.
## Each takes its arguments out of the positional list before sourcing, since an include keeps a dispatch of its
## own at its top level, read from that same list.
cat > "$rigTmp/state.sh" <<'RIGSTATE'
## spawn id, status, live -- the state the registry derives for one run
rigA1="$1" rigA2="$2" rigA3="$3" ; set --
. "$RIG_INCLUDE" || exit 1
AgentsToolsRegistryDeriveState "$rigA2" "$rigA3" "$rigA1" "$rigA1"
RIGSTATE
cat > "$rigTmp/control.sh" <<'RIGCONTROL'
## session id -- one tick of the session's own control thread, and the state word it left in control/state
rigA1="$1" ; set --
"$RIG_BASH" "$RIG_TOOLS" --intern-session-control --one --session-id "$rigA1" > /dev/null 2>&1
LC_ALL=C sed -n 's/^state: //p' "$MMDAPP/.local/agents/sessions/$rigA1/control/state" 2> /dev/null | LC_ALL=C sed -n '1p'
RIGCONTROL
cat > "$rigTmp/row.sh" <<'RIGROW'
## session id -- the state and the usage-limit flag of its session row, as the console's list prints them
rigA1="$1" ; set --
. "$RIG_INCLUDE" || exit 1
AgentsToolsRegistrySpawnedSessionsRows > "$RIG_ROWS" || exit 1
AgentsToolsRegistryMeasureRows "$RIG_ROWS" '' '' 17 '' > /dev/null || exit 1
printf '%s\n' "$measuredDated" \
	| MDAT_MANAGER_CONTROL='' MDAT_MANAGER_AGENTS="$RIG_AGENTS" LC_ALL=C awk -v loadAverage=- \
		-f "$RIG_TOKENS" -f "$RIG_MINUTES" -f "$RIG_ROWSAWK" "$RIG_AGENTS/pending-replies.registry" - \
	| LC_ALL=C cut -f6- \
	| LC_ALL=C awk -F'\t' -v want="$rigA1" '$1 == "session" && $2 == want { print $4 "|" $13 }'
RIGROW
cat > "$rigTmp/notice.sh" <<'RIGNOTICE'
## record path -- the end notice of one run, as it was posted
rigA1="$1" ; set --
. "$RIG_INCLUDE" || exit 1
AgentsToolsSpawnProxyEndNotice "$rigA1"
printf '%s' "${agentsSpawnProxyEndNoticeSaid:-}"
RIGNOTICE
cat > "$rigTmp/sweep.sh" <<'RIGSWEEP'
## the pass over dead spawns, as far as the stale park mark goes
set --
. "$RIG_INCLUDE" || exit 1
AgentsToolsSpawnProxyStaleParkClear > /dev/null
RIGSWEEP
cat > "$rigTmp/close.sh" <<'RIGCLOSE'
## record path, then the close's own words -- one close through the proxy
rigRecord="$1" ; shift
. "$RIG_INCLUDE" || exit 1
AgentsToolsSpawnProxyCloseSandbox "$rigRecord" "$@"
RIGCLOSE

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
rigInRig(){ ## the include, the program, then its arguments -- run in the rig's own workspace
	local rigInclude="$1" rigProgram="$2"
	shift 2
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SPAWN_AGENT=magic-coordinator MDAT_SEND_FLOOR=none \
		RIG_INCLUDE="$rigInclude" RIG_ROWS="$rigTmp/rows.txt" RIG_AGENTS="$rigAgents" \
		RIG_ROWSAWK="$rigRowsAwk" RIG_TOKENS="$rigTokensAwk" RIG_MINUTES="$rigMinutesAwk" \
		RIG_BASH="$BASH" RIG_TOOLS="$rigTools" RIG_POST_LOG="$rigTmp/post.log" \
		bash "$rigProgram" "$@" 2>&1 )
}
rigRecord(){ ## sandbox, session id, spawn id, status, further frontmatter lines (may be empty)
	mkdir -p "$rigSpawned/$1" "$rigStores/$3"
	{
		printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\ntracking-name: %s\nhost: %s\nowner: keeper-myx\nstatus: %s\n' \
			"$2" "$3" "$1" "$rigHost" "$4"
		[ -z "${5:-}" ] || printf '%s\n' "$5"
		printf -- '---\n\n# Spawn session: %s\n' "$3"
	} > "$rigSpawned/$1/$3.spawn.md"
}
rigMark(){ ## spawn id -- whether its park mark stands
	[ -f "$rigStores/$1/parked" ] && printf present || printf gone
}
rigStateOf(){ ## spawn id, status, live
	rigInRig "$rigRegistries" "$rigTmp/state.sh" "$1" "$2" "$3"
}
rigSessionRow(){ ## session id
	rigInRig "$rigRegistries" "$rigTmp/row.sh" "$1"
}
rigSweep(){
	rigInRig "$rigHousekeeping" "$rigTmp/sweep.sh" > /dev/null
}
rigNoticeRefusals(){ ## record path -- how many provider-refusal lines its end notice carries
	LC_ALL=C rm -f "$rigTmp"/post.* 2> /dev/null || :
	rigInRig "$rigSandbox" "$rigTmp/notice.sh" "$1" > /dev/null
	LC_ALL=C cat "$rigTmp"/post.* 2> /dev/null | LC_ALL=C grep -c 'provider refusal' || :
}

echo "-- 1. the owner's case: a handback's mark outlives the accept that settled the run, and the pass frees it --"
## The run handed back and parked; the accept of its item then settled the record, and the mark stayed. The mark
## is read first as it stood, then the pass over dead spawns runs, and the session reads finished from there on.
rigRecord rig-accepted rig-accepted-$$ rig-accepted-$$ spawn-succeeded 'end-reason: the accept of dispatch-rig by magic-coordinator'
: > "$rigStores/rig-accepted-$$/parked"
rigAssert "with its mark the settled session reads awaiting review" "$( rigSessionRow rig-accepted-$$ )" "awaiting-review|-"
rigSweep
rigAssert "the pass clears the mark of an accepted run"        "$( rigMark rig-accepted-$$ )" "gone"
rigAssert "so the settled session reads finished"              "$( rigSessionRow rig-accepted-$$ )" "finished|-"
rigAssert "and its control thread has nothing left to watch"   "$( rigInRig "$rigControl" "$rigTmp/control.sh" "rig-accepted-$$" )" "finished"

echo "-- 2. the controls of that reading --"
rigRecord rig-open rig-open-$$ rig-open-$$ spawn-started
: > "$rigStores/rig-open-$$/parked"
rigSweep
rigAssert "a waiting run's mark survives the pass"             "$( rigMark rig-open-$$ )" "present"
rigAssert "an open record with a mark reads parked"            "$( rigStateOf rig-open-$$ spawn-started gone )" "parked"
rigAssert "and its session waits for the verdict"              "$( rigSessionRow rig-open-$$ )" "awaiting-review|-"
rigRecord rig-plain rig-plain-$$ rig-plain-$$ spawn-succeeded
rigAssert "a settled record with no mark reads finished"       "$( rigStateOf rig-plain-$$ spawn-succeeded gone )" "finished"
rigRecord rig-failed rig-failed-$$ rig-failed-$$ spawn-failed
rigAssert "a record that failed on its start reads failed"     "$( rigStateOf rig-failed-$$ spawn-failed gone )" "failed"

echo "-- 3. a close takes its run's mark away, even where the record has already settled --"
## The record settles by the verdict, and the run's own supervising shell closes it a moment later. That second
## close finds it settled, and it must still take the mark away, so no close leaves one behind for good.
mkdir -p "$rigSpawned/rig-closing-$$" "$rigStores/rig-closing-$$"
printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: none\ntracking-name: %s\nhost: %s\nowner: keeper-myx\nstatus: spawn-succeeded\nresolved-at: 2026-11-02 05:54 +0200\n---\n' \
	"rig-closing-$$" "rig-closing-$$" "rig-closing-$$" "$rigHost" > "$rigSpawned/rig-closing-$$/rig-closing-$$.spawn.md"
: > "$rigStores/rig-closing-$$/parked"
rigInRig "$rigSandbox" "$rigTmp/close.sh" "$rigSpawned/rig-closing-$$/rig-closing-$$.spawn.md" succeeded unknown "the accept of rig-item by magic-coordinator" > /dev/null
rigAssert "the settled record is left as it was"               "$( LC_ALL=C sed -n 's/^status: //p' "$rigSpawned/rig-closing-$$/rig-closing-$$.spawn.md" | head -1 )" "spawn-succeeded"
rigAssert "and its mark is gone"                               "$( rigMark rig-closing-$$ )" "gone"

echo "-- 4. an accept is never shown as a provider refusal --"
## A run settled by a review verdict carries the accept's own words in its store, left there while a close wrote
## an accept as a refusal. A settled run stopped on nothing: its row shows no refusal.
printf 'stopped by a provider refusal: the accept of dispatch-rig by magic-coordinator\n' > "$rigStores/rig-accepted-$$/usage-limit"
rigAssert "the settled session shows no provider refusal"      "$( rigSessionRow rig-accepted-$$ )" "finished|-"
rigAssert "and its end notice says nothing of a refusal"       "$( rigNoticeRefusals "$rigSpawned/rig-accepted-$$/rig-accepted-$$.spawn.md" )" "0"

echo "-- 5. the control: a refusal the harness kept is still flagged, and still told --"
rigRecord rig-refused rig-refused-$$ rig-refused-$$ spawn-failed 'end-reason: rate_limit_error: slow down, too many requests'
printf 'stopped by a provider refusal: rate_limit_error: slow down, too many requests\n' > "$rigStores/rig-refused-$$/usage-limit"
rigAssert "a refused run's flag still shows on its session"    "$( rigSessionRow rig-refused-$$ )" "failed|stopped by a provider refusal: rate_limit_error: slow down, too many requests"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SETTLED RUN READS FINISHED CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'SETTLED_RUN_READS_FINISHED: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
