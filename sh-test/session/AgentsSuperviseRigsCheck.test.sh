#!/usr/bin/env bash
## Behavioural check on the rigs a supervisor reads (board task 20261117T2242Z, S13): `--supervise-scan` with no `--workspace` scans
## every rig the team runs, a rig being a workspace whose own settings make it a team rig and run the team duties, and a `--workspace`
## that is no rig is refused. Held, run rather than read:
##   1. THE NO-ARGUMENT SCAN COVERS BOTH RIGS of this fixture, naming both.
##   2. THE THIRD WORKSPACE IS NOT ONE OF THEM, and a scan of one rig alone names that one only.
##   3. A NON-RIG NAMED BY --workspace IS REFUSED, in one line naming it and the rule, with a failing status and no finding at all.
##   4. ONE OWNER FUNCTION STATES EACH RIG AND ITS OWN OWNER ACCOUNT, and lists no workspace that is no rig; and the read-only
##      operation `--supervise-rigs` prints the same list, since a routine cannot call a function.
##   5. THE CONTROL FOR 1 AND 2: the same third workspace, made a team rig and nothing else, is scanned and its finding named. So its
##      absence above is a fact about the rigs test, not about a folder with nothing in it.
## Red before this task: the no-argument scan read the caller's own workspace alone, so 1 named one rig, and 3 was accepted in silence.
## Offline: a places registry and three workspace trees of this check's own, under a home of its own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigFn="$rigPkg/sh-scripts/AgentDispatcherTools.fn.sh"
rigRefuse(){ ## what failed
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigFn" ] || rigRefuse "the dispatcher is not at the origin: $rigFn"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSuperviseRigsCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
## THE RIGS LIVE OUTSIDE THE CHECK RIG TREE: the places list leaves out every root inside a run's sandbox or a check's rig folder, so
## a workspace placed under rigTempDir could never be a rig of the fixture. These sit in the workspace's own temp folder, made by
## mktemp with a template, which is where a short-lived file of a check belongs.
mkdir -p "$MMDAPP/.local/temp" || rigRefuse "the workspace temp folder could not be made"
rigRoot="$( mktemp -d "$MMDAPP/.local/temp/AgentsSuperviseRigsCheck.XXXXXX" )" || rigRefuse "the rigs' folder could not be made"
trap 'chmod -R u+rwX -- "$rigTmp" "$rigRoot" 2> /dev/null ; rm -rf -- "$rigTmp" "$rigRoot"' EXIT

rigHome="$rigTmp/home"
mkdir -p "$rigHome/.agents/magic-team" || rigRefuse "the home could not be made: $rigHome"
## TWO RIGS AND ONE WORKSPACE THAT IS NO RIG, each a root of this check's own places list. A rig is a workspace whose own settings make
## it a team rig (MDAT_WORKSPACE_MODE=team-rig) and run the team duties; the third is just agents, which is every setting a workspace
## of the team carries otherwise. Each rig names its own owner account as well.
rigRigA="$rigRoot/rigs-a" ; rigRigB="$rigRoot/rigs-b" ; rigFlat="$rigRoot/rigs-flat"
rigOwnerA=URIGOWNRA ; rigOwnerB=URIGOWNRB
for rigOne in "$rigRigA" "$rigRigB" "$rigFlat" ; do
	mkdir -p "$rigOne/.local/agents/spawned" "$rigOne/.local/agents/sessions" "$rigOne/.local/agents/pending" "$rigOne/.local/.agents" \
		|| rigRefuse "the workspaces could not be made: $rigOne"
done
rigTeamSettings(){ ## workspace, mode or empty, owner account or empty
	if [ -n "$2" ] ; then
		printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIGTEAM\nSLACK_CHANNEL_HUMAN_OWNER=%s\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nMDAT_WORKSPACE_MODE=%s\n' "$3" "$2"
	else
		printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIGTEAM\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n'
	fi > "$1/.local/.agents/magic-team.agent.env"
}
rigTeamSettings "$rigRigA" team-rig "$rigOwnerA"
rigTeamSettings "$rigRigB" team-rig "$rigOwnerB"
rigTeamSettings "$rigFlat" "" ""
## Each workspace's own places row, and the machine-wide pointer list that names them, as a workspace's install writes both.
for rigOne in "$rigRigA" "$rigRigB" "$rigFlat" ; do
	printf '%s\tworkspace\tread-write\t%s\tworkspace\n' "${rigOne##*/}" "$rigOne" > "$rigOne/.local/agents/directories.registry"
	printf '%s\t%s\n' "${rigOne##*/}" "$rigOne" >> "$rigHome/.agents/magic-team/directories.registry"
done
## ONE FINDING IN EACH WORKSPACE, so a scan line names the workspace it reached: a record still started, past the five minutes a scan
## gives a start, with no process behind it.
rigDead(){ ## workspace, run id
	mkdir -p "$1/.local/agents/spawned/$2" "$1/.local/agents/sessions/$2" || rigRefuse "the record could not be made: $2"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nowner: keeper-rig\nstatus: spawn-started\nstarted-at: 2026-11-17 02:00 +0200\n---\n' \
		"$2" "$2" > "$1/.local/agents/spawned/$2/$2.spawn.md"
	touch -t 202611170200 "$1/.local/agents/spawned/$2/$2.spawn.md" || rigRefuse "the record's date could not be set back: $2"
}
rigDead "$rigRigA" rigdeada
rigDead "$rigRigB" rigdeadb
rigDead "$rigFlat" rigdeadf

rigPass=0 ; rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
## One call of the dispatcher, run from rig A: HOME is this check's own, so the places list is the fixture's.
rigOp(){ ## words...
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigRigA" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SPAWN_AGENT=magic-coordinator bash "$rigFn" "$@" 2>&1 < /dev/null
}
## The rigs owner function, in this fixture's places list.
rigRigs(){ ## none
	env -i HOME="$rigHome" MMDAPP="$rigRigA" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SPAWN_AGENT=magic-coordinator \
		bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/supervise/AgentsTools.SuperviseRigs.include" ; AgentsToolsSuperviseRigs "$1"' \
		rig "$rigRigA" 2>&1
}
rigReached(){ ## a scan's whole output -- the workspaces whose `dead` finding it printed, in its order, each once, space-separated
	printf '%s\n' "$1" | LC_ALL=C awk '$1 == "dead" && NF > 2 { print $2 }' | LC_ALL=C awk '!seen[$0]++ { printf "%s%s", ( n++ ? " " : "" ), $0 }'
}

echo "-- 1. the no-argument scan covers every rig of the fixture --"
rigOut="$( rigOp --supervise-scan )"
rigAssert "the no-argument scan reaches both rigs" "$( rigReached "$rigOut" | LC_ALL=C tr -d ' ' )" "rigs-arigs-b"

echo "-- 2. a workspace that is no rig is not one of them, and a named rig is read alone --"
rigAssert "the workspace naming no owner account is not in the no-argument pass" \
	"$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c ' rigs-flat ' )" "0"
rigOnly="$( rigOp --supervise-scan --workspace "$rigRigA" )"
rigAssert "the scan of one rig names that rig, and the other not at all" \
	"$( rigReached "$rigOnly" ):$( printf '%s\n' "$rigOnly" | LC_ALL=C grep -c ' rigs-b ' )" "rigs-a:0"

echo "-- 3. a --workspace that is no rig is refused, naming why --"
rigFlatOut="$( rigOp --supervise-scan --workspace "$rigFlat" )" ; rigFlatRc=$?
rigAssert "the refusal names the workspace" \
	"$( printf '%s\n' "$rigFlatOut" | LC_ALL=C grep -c -F "⛔ ERROR: --supervise-scan: $rigFlat is no rig" )" "1"
rigAssert "and it states the rule a rig is held to" \
	"$( printf '%s\n' "$rigFlatOut" | LC_ALL=C grep -c -F 'a rig is a workspace whose own settings make it a team rig and run the team duties' )" "1"
rigAssert "and the call fails, so no caller reads it as a clean scan" "$rigFlatRc" "1"
rigAssert "and no finding of the refused workspace was printed" \
	"$( printf '%s\n' "$rigFlatOut" | LC_ALL=C grep -c 'rigdeadf' )" "0"

echo "-- 4. one owner function states the rigs and each rig's own owner account --"
rigTable="$( rigRigs )"
rigAssert "both rigs are listed, each beside its own account" \
	"$( printf '%s\n' "$rigTable" | LC_ALL=C awk -F'\t' -v a="$rigRigA" -v b="$rigRigB" \
		'$1 == a { first = $2 } $1 == b { second = $2 } END { print first "/" second }' )" \
	"$rigOwnerA/$rigOwnerB"
rigAssert "and the workspace that is no rig is not one of them" \
	"$( printf '%s\n' "$rigTable" | LC_ALL=C grep -c -F "$rigFlat" )" "0"
## THE ROUTINE'S OWN READ: the same list through the operation a routine can call, which is what step 1 of the supervision
## routine reads. A routine holds no shell, so a function alone would leave it guessing the rigs.
rigToolTable="$( rigOp --supervise-rigs )"
rigAssert "--supervise-rigs prints the same two rigs, each beside its own account" \
	"$( printf '%s\n' "$rigToolTable" | LC_ALL=C awk -F'\t' -v a="$rigRigA" -v b="$rigRigB" \
		'$1 == a { first = $2 } $1 == b { second = $2 } END { print first "/" second }' )" \
	"$rigOwnerA/$rigOwnerB"

echo "-- 5. the control: the same third workspace, made a team rig, is scanned --"
rigTeamSettings "$rigFlat" team-rig URIGOWNRC
rigFlatNow="$( rigOp --supervise-scan --workspace "$rigFlat" )"
rigAssert "its finding is named once it is a rig, so it held one all along" \
	"$( printf '%s\n' "$rigFlatNow" | LC_ALL=C grep -c 'rigdeadf' )" "1"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SUPERVISE RIGS CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'SUPERVISE_RIGS: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
