#!/usr/bin/env bash
## Behavioural check on S13.3 of `20261102-refactorings.epic.md`: "Resume a run that ended without a handback, after the fixed
## sleep, honouring the runs the owner dismissed." Run rather than read, through `--supervise-resume` and the real spawn proxy,
## on a stand-in console. Held:
##   1. a run that ended with no handback, past the fixed sleep, is resumed: its item is returned, the member is started again
##      in its session, and one `resumed` line names the run, the item and how it was started
##   2. the controls, each of which starts nothing and says why in one `held` line: a run still open, a run the owner
##      dismissed, a run that ended inside the sleep, a work-duty run, an item waiting for its reviewer's verdict, and an item
##      not in review at all
##   3. the sleep is a setting, SUPERVISE_RESUME_SECONDS, and a run that ended a moment ago resumes under it once its own
##      sleep has passed
## Red before S13.3: `--supervise-resume` does not exist, so the operation is refused as an invalid option and every one of
## 1 and 3 fails.
## Offline: a rig workspace, its spawn records, its board and its team data are this rig's own tree; the console is a
## stand-in that keeps the brief and waits to be let go; every process this check starts is ended on the way out.
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
rigTmp="$( rigTempDir AgentsSuperviseResumeCheck )" || exit 1
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
mkdir -p "$rigSp" "$rigAgents/sessions" "$rigAgents/pending" "$rigAgents/schedule/dismissed" "$rigWs/.local/.agents" \
	"$rigData/board/running" "$rigData/board/review" "$rigData/board/processed" "$rigData/audit/2026-11" "$rigHome" \
	"$rigSkills/magic-coordinator" "$rigSkills/keeper-rig" || rigRefuse "the rig could not be made: $rigTmp"
printf 'rig\n' > "$rigSkills/magic-coordinator/magic-coordinator.basic.md"
printf 'rig\n' > "$rigSkills/keeper-rig/keeper-rig.basic.md"
rigHost="$( hostname -s 2> /dev/null )" ; [ -n "$rigHost" ] || rigHost=unknown

## THE STAND-IN CONSOLE: it keeps the brief it was given, says which run and which item it is, and waits until this check lets
## every run go, so a resumed run lives by the process its record names.
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

rigTimeoutHeader(){ LC_ALL=C sed -n 's/^timeout-seconds: //p' "$rigTmp/home/.local/agents/config/execution-receipts"/*.md 2> /dev/null | head -1 ; }
## A CREDENTIAL IN A READ-ONLY ENVIRONMENT WOULD POISON A LATER RUN: these calls carry none, and a run started under one is
## refused by the proxy rather than started. So the record names the CLI by name alone.
rigRecord(){ ## run id, member, status, extra frontmatter lines (may be empty)
	local recFile="$rigAgents/spawned/$1/$1.spawn.md"
	mkdir -p "$rigAgents/spawned/$1" "$rigAgents/sessions/$1" || rigRefuse "the run could not be made: $1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: %s\nworkspace: ws-supervise-resume-rig\nmember-workspace: ws-supervise-resume-rig\nowner: %s\nstatus: %s\nstarted-at: 2026-11-04 02:00 +0200\nsession-thread: -\n%s---\n\n# Spawn session: %s\n' \
		"$1" "$1" "$rigHost" "$2" "$3" "${4:+$4
}" "$1" > "$recFile" || rigRefuse "the record could not be written: $1"
}
rigEndedAgo(){ ## run id, seconds ago -- the record's own mtime, which is the close's. touch -t reads a local time.
	local agoStamp
	agoStamp="$( date -r "$(( $( date +%s ) - $2 ))" '+%Y%m%d%H%M.%S' 2> /dev/null )" \
		|| agoStamp="$( date -d "@$(( $( date +%s ) - $2 ))" '+%Y%m%d%H%M.%S' 2> /dev/null )"
	touch -t "$agoStamp" "$rigAgents/spawned/$1/$1.spawn.md" || rigRefuse "the record's date could not be set back: $1"
	[ "$(( $( date +%s ) - $( stat -f '%m' "$rigAgents/spawned/$1/$1.spawn.md" 2> /dev/null || stat -c '%Y' "$rigAgents/spawned/$1/$1.spawn.md" ) ))" -ge 5 ] \
		|| rigRefuse "the record of $1 did not end as long ago as asked"
}
rigItem(){ ## item stem, run id, state, review-reason (empty for none)
	printf -- '---\nstatus: dispatch-started\nspawn-id: %s\n%s---\n\n# the rig task of %s\n' "$2" "${4:+review-reason: $4
}" "$2" > "$rigData/board/$3/$1.md"
}
rigItemIn(){ ## item stem -- the state that holds it, or `nowhere`
	local inState
	for inState in running review processed pending blocked parked backlog ; do
		[ ! -f "$rigData/board/$inState/$1.md" ] || { printf '%s' "$inState" ; return 0 ; }
	done
	printf 'nowhere'
}
## The operation, as a console of the rig workspace calls it.
rigResume(){ ## extra NAME=value words...
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" \
		MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" \
		MDAT_SPAWN_AGENT=magic-coordinator "$@" bash "$rigFn" --supervise-resume --workspace "$rigWs" 2>&1
}

## THE RIG'S RUNS. One run that ended ten minutes ago with no handback, its item in review for that reason: the resume.
## Each control is one reason a run is left where it lies.
rigRecord rigdead keeper-rig spawn-succeeded "spawns: item-dead
cli: deepseek
cli-setting: mel-deepseek-flash+-"
rigEndedAgo rigdead 600
rigItem item-dead rigdead review ended-without-handback
rigRecord rigopen keeper-rig spawn-started "spawns: item-open
"
rigItem item-open rigopen running
rigRecord rigdism keeper-rig spawn-succeeded "spawns: item-dism
cli: deepseek
cli-setting: mel-deepseek-flash+-"
rigEndedAgo rigdism 600
: > "$rigAgents/sessions/rigdism/dismissed"
rigItem item-dism rigdism review ended-without-handback
rigRecord rigyoun keeper-rig spawn-succeeded "spawns: item-youn
cli: deepseek
cli-setting: mel-deepseek-flash+-"
rigEndedAgo rigyoun 10
rigItem item-youn rigyoun review ended-without-handback
rigRecord rigduty keeper-rig spawn-succeeded "routine: magic-team.work-duty.routine.md
spawns: item-duty
cli: deepseek
cli-setting: mel-deepseek-flash+-"
rigEndedAgo rigduty 600
rigItem item-duty rigduty review ended-without-handback
rigRecord rigrevd keeper-rig spawn-succeeded "spawns: item-revd
cli: deepseek
cli-setting: mel-deepseek-flash+-"
rigEndedAgo rigrevd 600
rigItem item-revd rigrevd review review-requested
rigRecord rigproc keeper-rig spawn-succeeded "spawns: item-proc
cli: deepseek
cli-setting: mel-deepseek-flash+-"
rigEndedAgo rigproc 600
rigItem item-proc rigproc processed ""
## A NEWER RUN THAT HOLDS THE ITEM (S13.3): the run went, the item is in review for that reason, and its own `spawn-id`
## names a run of the same task that is still going. That run is a process of this host, named by its record, so the guard's
## own reading of liveness has a real answer to read.
sleep 300 > /dev/null 2>&1 < /dev/null &
rigNewerPid=$!
rigPids="$rigPids $rigNewerPid"
sleep 1
rigNewerStart="$( { LC_ALL=C ps -o lstart= -p "$rigNewerPid" 2> /dev/null ; } | LC_ALL=C awk 'NF { $1 = $1 ; gsub( / /, "_" ) ; print ; exit }' )"
[ -n "$rigNewerStart" ] || rigRefuse "a process of this host could not be named with when it began"
rigRecord rigdead2 keeper-rig spawn-succeeded "spawns: item-held
cli: deepseek
cli-setting: mel-deepseek-flash+-"
rigEndedAgo rigdead2 600
rigItem item-held rigdead2 review ended-without-handback
rigRecord rignewer keeper-rig spawn-started "run-process: $rigNewerPid $rigNewerStart
cli: deepseek
cli-setting: mel-deepseek-flash+-"
## The item is the dead run's, and its own `spawn-id` now names the newer run: the case the guard is for.
LC_ALL=C awk '{ if ( $0 == "spawn-id: rigdead2" ) { print "spawn-id: rignewer" ; next ; } ; print }' "$rigData/board/review/item-held.md" > "$rigData/board/review/item-held.md.new" \
	&& mv -f "$rigData/board/review/item-held.md.new" "$rigData/board/review/item-held.md" || rigRefuse "the item of the newer run could not be written"
sleep 1

echo "-- 1. a run that ended with no handback, past the sleep, is resumed --"
rigOut="$( rigResume )"
rigAssert "the run is resumed" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^resumed .* rigdead ' )" "1"
rigAssert "and one launch starts it again" "$( rigLaunches )" "1"
rigAssert "and its item is out of review" "$( rigItemIn item-dead )" "running"
rigAssert "and the line names the item and how it was started" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c -e 'item-dead' -e 'new process' )" "1"

echo "-- 2. the control runs, each held where it lies --"
rigAssert "a run still open is held" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^resumed .* rigopen ' )" "0"
rigAssert "a dismissed run is held" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^resumed .* rigdism ' )" "0"
rigAssert "a run ended inside the sleep is held, and says so" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c -e '^held .* rigyoun .*inside the' -e '^resumed .* rigyoun ' )" "1"
rigAssert "a work-duty run is left to its scheduler" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^resumed .* rigduty ' )" "0"
rigAssert "an item waiting for its reviewer is held, naming the reason" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^held .* rigrevd .* review-requested' )" "1"
rigAssert "an item not in review is held, naming its state" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^held .* rigproc .* processed' )" "1"
rigAssert "a run whose item a newer live run holds is held, and it is never started again" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c -e '^held .* rigdead2 .* a newer run rignewer holds its item' -e '^resumed .* rigdead2 ' )" "1"
rigAssert "and no launch was made for it" "$( rigLaunches )" "1"

echo "-- 3. the sleep is a setting --"
rigOut="$( rigResume SUPERVISE_RESUME_SECONDS=1 )"
rigAssert "the run that ended a moment ago is resumed under a one-second sleep" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^resumed .* rigyoun ' )" "1"
rigAssert "and it is launched" "$( rigLaunches )" "2"

echo "-- 4. nothing stays running behind this check --"
: > "$rigTmp/release"
sleep 1
rigAssert "the stand-in runs end when the check lets them go" "$( sleep 1 ; rigLaunches )" "2"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SUPERVISE RESUME CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'SUPERVISE_RESUME: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
