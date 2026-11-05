#!/usr/bin/env bash
## Behavioural check on S13.12 of `20261102-refactorings.epic.md`: the supervisor's operations work over several rigs, and
## a rig's board operation finds that rig's own items, never the caller's.
## Held:
##   1. `--supervise-scan --workspace <rig>` reports the rig's own records, named by the rig, and none of this workspace's
##   2. `--supervise-resume --workspace <rig>` resumes the rig's dead run from the rig's own board, where the rig's team data
##      is a directory of its own (TEAM_DATA_DIRECTORY set in its magic-coordinator scope)
##   3. the item of the same name in the caller's own board is left alone: the resume read the rig's store and no other
##   4. a rig whose dead run's item is not in its own board is held, naming the state, and the caller's item of that name is
##      never the one it would have used
## Red before S13.12: the resume read `MDAT_DATA_ROOT`, the caller's store, so 2 held the rig's run as `not in review` and 4
## resumed the caller's item.
## Offline: two workspace trees of this rig's own, and a stand-in console; every process it starts is ended on the way out.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPkg/sh-scripts/AgentDispatcherTools.fn.sh"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigTool" ] || rigRefuse "the dispatcher is not at the origin: $rigTool"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSuperviseRigCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigPids=""
rigCleanup(){
	: > "$rigTmp/release"
	sleep 1
	for rigOne in $rigPids ; do kill -TERM "$rigOne" 2> /dev/null ; done
	sleep 0.5
	for rigOne in $rigPids ; do kill -KILL "$rigOne" 2> /dev/null ; done
	chmod -R u+rwX -- "$rigTmp" 2> /dev/null
	rm -rf -- "$rigTmp" 2> /dev/null
}
trap 'rigCleanup' EXIT

rigHome="$rigTmp/home" ; mkdir -p "$rigHome"
rigHere="$rigTmp/here" ; rigRig="$rigTmp/rig"
rigHereStore="$rigHere/.local/agents/team-data-root"
rigRigStore="$rigRig/store"
rigSkills="$rigTmp/skills"
for rigWs in "$rigHere" "$rigRig" ; do
	mkdir -p "$rigWs/.local/agents/spawned" "$rigWs/.local/agents/sessions" "$rigWs/.local/agents/pending" "$rigWs/.local/.agents" \
		|| rigRefuse "the tree could not be made: $rigWs"
done
mkdir -p "$rigHereStore/board/running" "$rigHereStore/board/review" "$rigHereStore/inboxes/magic-coordinator/incoming" \
	"$rigRigStore/board/running" "$rigRigStore/board/review" "$rigRigStore/board/processed" "$rigRigStore/inboxes/magic-coordinator/incoming" \
	"$rigSkills/magic-coordinator" "$rigSkills/keeper-rig" || rigRefuse "the stores could not be made"
printf 'rig\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"
printf 'rig\n' > "$rigSkills/keeper-rig/keeper-rig.basic.md"
## The rig's own store, named as the owner names one: an absolute path in its magic-coordinator scope.
printf 'TEAM_DATA_DIRECTORY=%s\n' "$rigRigStore" > "$rigRig/.local/.agents/magic-coordinator.agent.env"
for rigWs in "$rigHere" "$rigRig" ; do
	printf 'SLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSPAWN_TIER_NORMAL=rig-cli\n' > "$rigWs/.local/.agents/magic-team.agent.env"
	printf 'PRESET_CLI_SERVICE=rig-cli\n' > "$rigWs/.local/.agents/preset-rig-cli.agent.env"
done
rigHost="$( hostname -s 2> /dev/null )" ; [ -n "$rigHost" ] || rigHost=unknown

## The stand-in console: it keeps the brief and waits until this check lets every run go.
printf '%s\n' '#!/bin/sh' '## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli) -- the stand-in of a console and its CLI' \
	'cat > "$RIG_TMP/brief.$MDAT_SPAWN_SESSION_ID"' 'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' \
	'printf "%s\n" "$MDAT_SPAWN_SESSION_ID" >> "$RIG_TMP/launches"' \
	'rigLeft=300' 'while [ "$rigLeft" -gt 0 ] && [ ! -e "$RIG_TMP/release" ] ; do sleep 1 ; rigLeft=$(( rigLeft - 1 )) ; done' 'exit 0' \
	> "$rigRig/DistroAgentsConsole.sh"
cp "$rigRig/DistroAgentsConsole.sh" "$rigHere/DistroAgentsConsole.sh"
chmod +x "$rigRig/DistroAgentsConsole.sh" "$rigHere/DistroAgentsConsole.sh"
: > "$rigTmp/launches"
rigLaunches(){ LC_ALL=C awk 'END { print NR + 0 }' "$rigTmp/launches" ; }

rigPass=0 ; rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
rigRecord(){ ## workspace, run id, member, status
	local recWs="$1" recId="$2"
	mkdir -p "$recWs/.local/agents/spawned/$recId" "$recWs/.local/agents/sessions/$recId"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nworkspace: %s\nmember-workspace: %s\nowner: %s\nstatus: %s\nstarted-at: 2026-11-04 02:00 +0200\nsession-thread: -\nspawns: %s\ncli: deepseek\ncli-setting: mel-deepseek-flash+-\n---\n\n# Spawn session: %s\n' \
		"$recId" "$recId" "$rigHost" "${recWs##*/}" "${recWs##*/}" "$3" "$4" "$5" "$recId" > "$recWs/.local/agents/spawned/$recId/$recId.spawn.md"
}
rigAged(){ ## workspace, run id, seconds back
	local agoStamp
	agoStamp="$( date -r "$(( $( date +%s ) - $3 ))" '+%Y%m%d%H%M.%S' 2> /dev/null )" || agoStamp="$( date -d "@$(( $( date +%s ) - $3 ))" '+%Y%m%d%H%M.%S' 2> /dev/null )"
	touch -t "$agoStamp" "$1/.local/agents/spawned/$2/$2.spawn.md" || rigRefuse "the record's date could not be set back: $2"
}
rigItem(){ ## store, stem, run id, state
	printf -- '---\nstatus: dispatch-started\nspawn-id: %s\nreview-reason: ended-without-handback\n---\n\n# the task of %s\n' "$3" "$3" > "$1/board/$4/$2.md"
}
## THE RIG'S TWO RECORDS: a dead run whose item waits in the rig's own review, and one with no process at all.
rigRecord "$rigRig" rigdead keeper-rig spawn-succeeded item-rig
rigAged "$rigRig" rigdead 600
rigItem "$rigRigStore" item-rig rigdead review
rigRecord "$rigRig" rigstale keeper-rig spawn-started item-stale
rigAged "$rigRig" rigstale 600
## THIS WORKSPACE'S OWN: the same item names, never the ones the rig's reads use, and one dead record of its own.
rigRecord "$rigHere" herestale keeper-rig spawn-started item-herestale
rigAged "$rigHere" herestale 600
rigItem "$rigHereStore" item-rig rigdead running
rigRecord "$rigHere" riglost keeper-rig spawn-succeeded item-lost
rigAged "$rigHere" riglost 600
rigItem "$rigHereStore" item-lost riglost review
## THE RIG'S OWN LOST RUN: its item is in the caller's board and not in the rig's.
rigRecord "$rigRig" riglost keeper-rig spawn-succeeded item-lost
rigAged "$rigRig" riglost 600

rigOp(){ ## workspace, words... -- one call of the dispatcher, made from that workspace
	local opWs="$1"
	shift
	( cd "$opWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$opWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		RIG_TMP="$rigTmp" MDAT_SPAWN_AGENT=magic-coordinator bash "$rigTool" "$@" ) 2>&1 < /dev/null
}
rigIn(){ ## store, item stem -- the state that holds it, or nowhere
	local rigState
	for rigState in running review processed pending blocked parked backlog ; do
		[ ! -f "$1/board/$rigState/$2.md" ] || { printf '%s' "$rigState" ; return 0 ; }
	done
	printf 'nowhere'
}

echo "-- 1. the scan of a named rig --"
rigScan="$( rigOp "$rigHere" --supervise-scan --workspace "$rigRig" )"
rigAssert "the rig's own open record is reported, under the rig's name" \
	"$( printf '%s\n' "$rigScan" | LC_ALL=C grep -c '^dead rig rigsta' )" "1"
rigAssert "and this workspace's record is not in that read at all" "$( printf '%s\n' "$rigScan" | LC_ALL=C grep -c 'herestal' )" "0"
rigScanHere="$( rigOp "$rigHere" --supervise-scan --workspace "$rigHere" )"
rigAssert "the same read of this workspace names this one, and the rig not at all" \
	"$( printf '%s\n' "$rigScanHere" | LC_ALL=C grep -c '^dead here herestal' ):$( printf '%s\n' "$rigScanHere" | LC_ALL=C grep -c 'rigsta' )" "1:0"

echo "-- 2. the resume of the rig's dead run, from the rig's own board --"
rigOut="$( rigOp "$rigHere" --supervise-resume --workspace "$rigRig" )"
rigAssert "the run is resumed, under the rig's name" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^resumed rig rigdead ' )" "1"
rigAssert "it was started again once" "$( rigLaunches )" "1"
rigAssert "and its item left the rig's review, in the rig's store" "$( rigIn "$rigRigStore" item-rig )" "running"

echo "-- 3. this workspace's items of the same names are untouched --"
rigAssert "the decoy in this workspace's board is where it was" "$( rigIn "$rigHereStore" item-rig )" "running"
rigAssert "and the rig's other run, whose item is only in this workspace's board, is held naming the rig's state" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^held rig riglost .*no board state' )" "1"
rigAssert "so this workspace's item of that name was not taken up" "$( rigIn "$rigHereStore" item-lost )" "review"
rigAssert "and no second launch was made" "$( rigLaunches )" "1"

echo "-- 4. this workspace's own run is resumed from this workspace's board --"
rigOut2="$( rigOp "$rigHere" --supervise-resume --workspace "$rigHere" )"
rigAssert "its own dead run is resumed" "$( printf '%s\n' "$rigOut2" | LC_ALL=C grep -c '^resumed here riglost ' )" "1"
rigAssert "and its item left its review" "$( rigIn "$rigHereStore" item-lost )" "running"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SUPERVISE RIG CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'SUPERVISE_RIG: OK (%d assertions, offline, rig trees only)\n' "$rigPass"
