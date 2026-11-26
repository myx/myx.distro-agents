#!/usr/bin/env bash
## Behavioural check on sketch 3.4 of `20261102-refactorings.sketch.md`: "adding an item to the CheckList of a
## session whose agents stopped resumes its executor automatically". Run rather than read, through
## `--supervise-checklist-add` and the real spawn proxy, on a stand-in console. Held:
##   1. the add to a run whose record is settled (its agents stopped) resumes the executor: one launch starts the
##      member again, and one `resumed` line names the run
##   2. control: the add to a run still open leaves it running: no launch is made and no `resumed` line is said
## Red before the fix: the add appends its items and wakes nobody live, so row 1 fails on live.
## Offline: a rig workspace, its spawn records, its board and its team data are this rig's own tree; the console is
## a stand-in that keeps the brief and waits to be let go; every process this check starts is ended on the way out.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigFn="$rigPkg/sh-scripts/AgentDispatcherTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigFn" ] || rigRefuse "the dispatcher is not at the origin: $rigFn"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSuperviseChecklistAddResumeCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigPids=""
rigCleanup(){
	local cleanOne cleanLeft=30
	: > "$rigTmp/release"
	while [ "$cleanLeft" -gt 0 ] ; do
		cleanOne="$( LC_ALL=C grep -c -x -F -- 'status: spawn-started' "$rigSp"/*/*.spawn.md 2> /dev/null | LC_ALL=C awk -F: '$2 > 0' | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )"
		[ "$cleanOne" = 0 ] || [ "$cleanLeft" -lt 15 ] || { sleep 1 ; cleanLeft=$(( cleanLeft - 1 )) ; continue ; }
		break
	done
	for cleanOne in $rigPids ; do kill -TERM "$cleanOne" 2> /dev/null ; done
	sleep 0.5
	for cleanOne in $rigPids ; do kill -KILL "$cleanOne" 2> /dev/null ; done
	rm -rf -- "$rigTmp"
}
trap 'rigCleanup' EXIT
rigWs="$rigTmp/ws"
rigData="$rigTmp/data"
rigSkills="$rigTmp/skills"
rigHome="$rigTmp/home"
rigAgents="$rigWs/.local/agents"
rigSp="$rigAgents/spawned"
mkdir -p "$rigSp" "$rigAgents/sessions" "$rigAgents/pending" "$rigAgents/schedule/dismissed" "$rigWs/.local/.agents" "$rigData/audit/2026-11" "$rigHome" "$rigSkills/magic-coordinator" "$rigSkills/keeper-rig" || rigRefuse "the rig could not be made: $rigTmp"
rigBoardStates "$rigData" running review processed || rigRefuse "the rig could not be made: $rigTmp"
printf 'rig\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"
printf 'rig\n' > "$rigSkills/keeper-rig/keeper-rig.basic.md"
rigHost="$( hostname -s 2> /dev/null )" ; [ -n "$rigHost" ] || rigHost=unknown

## THE STAND-IN CONSOLE: it keeps the brief it was given, says which run and which item it is, and waits until this check
## lets every run go, so a resumed run lives by the process its record names.
printf '%s\n' '#!/bin/sh' '## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli) -- the stand-in of a console and its CLI' \
	'cat > "$RIG_TMP/brief.$MDAT_SPAWN_SESSION_ID"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' \
	'printf "%s %s\n" "$MDAT_SPAWN_SESSION_ID" "${MDAT_SESSION_ID:-none}" >> "$RIG_TMP/launches"' \
	'rigLeft=300' \
	'while [ "$rigLeft" -gt 0 ] && [ ! -e "$RIG_TMP/release" ] ; do sleep 1 ; rigLeft=$(( rigLeft - 1 )) ; done' \
	'exit 0' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"
: > "$rigTmp/launches"
rigLaunches(){ LC_ALL=C wc -l < "$rigTmp/launches" | LC_ALL=C tr -d ' ' ; }

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

rigRecord(){ ## run id, member, status, extra frontmatter lines (may be empty)
	local recFile="$rigAgents/spawned/$1/$1.spawn.md"
	mkdir -p "$rigAgents/spawned/$1" "$rigAgents/sessions/$1" || rigRefuse "the run could not be made: $1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nworkspace: ws-check-add-resume-rig\nmember-workspace: ws-check-add-resume-rig\nowner: %s\nstatus: %s\nstarted-at: 2026-11-04 02:00 +0200\nsession-thread: -\n%s---\n\n# Spawn session: %s\n' \
		"$1" "$1" "$rigHost" "$2" "$3" "${4:+$4
}" "$1" > "$recFile" || rigRefuse "the record could not be written: $1"
}
rigEndedAgo(){ ## run id, seconds ago -- the record's own mtime, which is the close's. touch -t reads a local time.
	local agoStamp
	agoStamp="$( date -r "$(( $( date +%s ) - $2 ))" '+%Y%m%d%H%M.%S' 2> /dev/null )" \
		|| agoStamp="$( date -d "@$(( $( date +%s ) - $2 ))" '+%Y%m%d%H%M.%S' 2> /dev/null )"
	touch -t "$agoStamp" "$rigAgents/spawned/$1/$1.spawn.md" || rigRefuse "the record's date could not be set back: $1"
}
rigItem(){ ## item stem, run id, state, review-reason (empty for none)
	printf -- '---\nstatus: dispatch-started\nspawn-id: %s\n%s---\n\n# the rig task of %s\n' "$2" "${4:+review-reason: $4
}" "$2" | rigStoreItem "$rigData" board $3 $1.md
}
rigItemIn(){ ## item stem -- the state that holds it, or `nowhere`
	local inState
	for inState in running review processed pending blocked parked backlog ; do
		[ ! -f "$rigData/board/$inState/$1.md" ] || { printf '%s' "$inState" ; return 0 ; }
	done
	printf 'nowhere'
}
## The add, as a console of the rig workspace calls it.
rigAdd(){ ## run id, item text
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" \
		MDAT_SPAWN_AGENT=magic-coordinator bash "$rigFn" --supervise-checklist-add "$1" --item "$2" 2>&1
}
## The resume, as the same console calls it: the rig's own proof that its resume path starts a run.
rigResume(){
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" \
		MDAT_SPAWN_AGENT=magic-coordinator bash "$rigFn" --supervise-resume --workspace "$rigWs" 2>&1
}

## THE RIG'S RUNS. One run that ended ten minutes ago with no handback, its item in review for that reason: the add resumes it.
## One run still open: the control, which the add leaves running.
rigRecord rigdead keeper-rig spawn-succeeded "spawns: item-dead
cli: deepseek
cli-setting: mel-deepseek-flash+-"
rigEndedAgo rigdead 600
rigItem item-dead rigdead review ended-without-handback
rigRecord rigopen keeper-rig spawn-started "spawns: item-open
"
rigItem item-open rigopen running

echo "-- 1. the add to a run whose agents stopped resumes its executor --"
rigOut="$( rigAdd rigdead RIG-CHECK-TASK )"
rigAssert "the add reaches the run's list" "$( LC_ALL=C grep -c -F -- 'RIG-CHECK-TASK' "$rigAgents/spawned/rigdead/keeper-rig.checklist.md" 2> /dev/null || : )" "1"
rigAssert "and one launch starts the executor again" "$( rigLaunches )" "1"
rigAssert "and a resumed line names the run" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^resumed .* rigdead ' )" "1"
rigAssert "and its item is out of review" "$( rigItemIn item-dead )" "running"

echo "-- 2. control: the add to a run still open leaves it running --"
rigOut="$( rigAdd rigopen RIG-OPEN-TASK )"
rigAssert "the item lands on the open run's list" "$( LC_ALL=C grep -c -F -- 'RIG-OPEN-TASK' "$rigAgents/spawned/rigopen/keeper-rig.checklist.md" 2> /dev/null || : )" "1"
rigAssert "and no launch is made for it" "$( rigLaunches )" "1"
rigAssert "and no resumed line is said" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^resumed ' )" "0"

echo "-- 3. nothing stays running behind this check --"
: > "$rigTmp/release"
sleep 1
rigAssert "the stand-in runs end when the check lets them go" "$( sleep 1 ; rigLaunches )" "1"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ CHECKLIST ADD RESUME CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'CHECKLIST_ADD_RESUME: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
