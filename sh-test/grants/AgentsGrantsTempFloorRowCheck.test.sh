#!/usr/bin/env bash
## Behavioural check: the floor rows the grants index carries for the workspace it is built for,
## where that workspace lies under `.local/agents/scratch/` or `.local/agents/spawned/`
## (AgentsTools.Grants.include, its floor loop over `LocalToolsPlacesWorkspaceRoots`).
## That root list drops every root holding either segment (LocalTools.Places.include,
## `LocalToolsPlacesWorkspaceRoots`), so the workspace the index is built for is dropped from its
## own floor rows and carries no `floor write <ws>/.local/temp/**` row at all. The fix emits that
## one row from the given workspace itself, and leaves the source docs, the epic read, the MAGIC
## write and the librarian source grant coming from the machine's list alone.
## Held, on the index the real operation writes (`--make-agents-indices`), never on a row read out
## of the source:
##   1. a workspace under .local/agents/scratch/ carries its own
##      `floor write <ws>/.local/temp/**` row, once for every member the index carries;
##   2. a workspace under .local/agents/spawned/ carries its own such row too;
##   3. either such workspace gains no floor row that reads its own `source/`: the split gives it
##      its temp row, and nothing from its own source. The one row that does read it stands in
##      every workspace's registry, before the fix and after it, and the narrowing below says why
##      it is not counted;
##   4. control: a root named only by the machine's list, never the given workspace, still carries
##      its temp floor row, its four source reads, its MAGIC write and magic-librarian's source
##      read;
##   5. a declared `magic-team:permissions:workspace:*:allow-read:<member>:any/**` row still
##      unrolls over the machine's roots, once each, and reaches no root of its own.
##
## WHICH ASSERTION CARRIES THE CONTROL, AND WHY. Assertion 4 does. Its root is named by the rig
## HOME's own places registry and by nothing else, so it reaches the index through
## `LocalToolsPlacesWorkspaceRoots` alone, the list the fix splits. It must pass on the tree before
## the fix and on the tree after it: the fix adds one row out of the given workspace and must leave
## what the machine's list already gave untouched. Assertion 4 red on the current tree therefore
## says the machine's rows were lost somewhere other than the split, and the red of assertions 1
## and 2 cannot be laid at the fix. The one run shows both sides in one index: the given
## workspace's own rows (1, 2, 3) and the machine's rows (4, 5). A row present on one side only is
## then a finding about the split, never about the rig.
##
## ONE NARROWING, WITH ITS REASON. Assertion 3 counts the FLOOR rows reading a workspace's own
## `source/`, never every row. Each workspace's `.local/agents/permissions.registry` carries
## `magic-librarian:<ws>:builtin:Read(/<ws>/source/**)` (AgentsTools.Grants.include, the registry
## writer), and that row reaches the index as a standing row of every workspace, on the tree
## before the fix and on the tree after it. It is not what the split adds, so counting it would
## redden this assertion whatever the fix does. A floor row reading `<ws>/source/`, of any glob,
## is the split emitting source rows for the workspace it was told to drop: that is what statement
## 3 forbids, and it is what the assertion holds at none.
##
## THE RIG'S OWN PATHS CARRY THE SEGMENT THE CODE FILTERS ON: `rig-temp.include.sh` puts every rig
## under `<workspace>/.local/agents/scratch/sh-test/`, so every rig workspace is filtered out as a
## machine root. That is why the two given workspaces sit under the two segments on purpose, and
## why the machine's control root is a name in the rig HOME's places registry only, never created:
## the root list and the floor rows come from the name, and a workspace made outside the rig would
## be a footprint this check has no business leaving.
##
## Offline: HOME, both workspaces, the member set, the team data and the places are this rig's own;
## a fake curl is first on PATH.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP names no workspace, so this rig has no place to live}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigHere="$rigPackage/sh-lib"
rigFn="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigFn" "$rigHere/grants/AgentsTools.Grants.include" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
rigMyxCommon="$( command -v myx.common 2>/dev/null )"
[ -n "$rigMyxCommon" ] || rigRefuse "myx.common is not on PATH, so no source project could be scanned for its declares"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsGrantsTempFloorRowCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
rigPass=0 rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
mkdir -p "$rigTmp/bin"
printf '#!/bin/sh\necho "rig fake curl: no request leaves this box" >&2\nexit 7\n' > "$rigTmp/bin/curl"
chmod +x "$rigTmp/bin/curl"

rigHome="$rigTmp/home" rigSkills="$rigTmp/skills" rigData="$rigTmp/data"
mkdir -p "$rigHome/.agents/magic-team" "$rigData"
for rigName in magic-tester magic-librarian keeper-w keeper-d ; do
	mkdir -p "$rigSkills/$rigName"
	printf '# %s\n' "$rigName" > "$rigSkills/$rigName/$rigName.basic.md"
done
## THE MACHINE'S OWN ROOT, assertions 4 and 5: a name in the rig HOME's places registry, outside
## both segments the root list filters on, and never created (see the header).
rigMachineRoot="${MMDAPP%/}/.local/temp/agents-grants-temp-floor-row-check-machine-ws"
printf 'machine-ws\t%s\n' "$rigMachineRoot" > "$rigHome/.agents/magic-team/directories.registry"

rigWsMake(){ ## path, declare lines... -- a rig workspace with one source project declaring them
	local makeWs="${1%/}" makeLine ; shift
	mkdir -p "$makeWs/.local/agents" "$makeWs/source/rig/rig-proj/docs/deep"
	printf 'Name: rig\n' > "$makeWs/source/rig/repository.inf"
	{
		printf 'Name: rig-proj\n\nDeclares: \\\n'
		for makeLine in "$@" ; do printf '\t%s \\\n' "$makeLine" ; done
		printf '\n'
	} > "$makeWs/source/rig/rig-proj/project.inf"
	for makeLine in MAGIC.md README.md x.sh docs/deep/a.md ; do printf 'rig-seed %s\n' "$makeLine" > "$makeWs/source/rig/rig-proj/$makeLine" ; done
	: > "$makeWs/.local/agents/members.registry"
}
## The two workspaces of statements 1 to 3, one under each segment, each declaring the `*` workspace
## grant statement 5 watches.
rigWsA="$rigTmp/outer-a/.local/agents/scratch/ws-a"
rigWsB="$rigTmp/outer-b/.local/agents/spawned/ws-b"
rigWsMake "$rigWsA" 'magic-team:permissions:workspace:*:allow-read:keeper-w:any/**'
rigWsMake "$rigWsB" 'magic-team:permissions:workspace:*:allow-read:keeper-w:any/**'

## The index is named after the member set root, so under a member set root of the rig's own it
## carries that root as its suffix, every other character as `_`
## (AgentsToolsGrantsIndexWrite, sh-lib/grants/AgentsTools.Grants.include).
rigIndexOf(){ ## workspace -- the grants index the writer gives it under this rig's member set root
	printf '%s/.local/agents/grants.index.%s' "${1%/}" "${rigSkills//[!A-Za-z0-9._-]/_}"
}
rigRun(){ ## workspace, operation and arguments... -- the tool there, rig HOME, clean env; rc in rigRc
	local runWs="${1%/}" ; shift
	rigRc=0
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigTmp/bin:${rigMyxCommon%/*}:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$runWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_DATA_ROOT="$rigData" RIG_TMP="$rigTmp" bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$HOME" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "'"$rigFn"'" "$@"
		' rig "$@" > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
## One floor row's seat across the whole index: `all-one` when every member the index carries holds
## it exactly once, `no-member` when the index carries no member at all -- so a run over an empty
## member list is never read as a pass -- else how many members hold it of how many there are.
rigSeat(){ ## index, verb, glob
	LC_ALL=C awk -F'\t' -v seatVerb="$2" -v seatGlob="$3" '
		$2 ~ /^(read|write|approve|tool|deny-read|deny-write|unresolved)$/ { member[$1] = 1 ; }
		$2 == seatVerb && $3 == seatGlob { held[$1]++ ; }
		END {
			all = 0 ; for ( one in member ) all++
			if ( all == 0 ) { print "no-member" ; exit ; }
			seated = 0
			for ( one in member ) if ( ( one in held ) && held[one] == 1 ) seated++
			if ( seated == all ) { print "all-one" ; exit ; }
			printf "%d/%d\n", seated, all
		}' "$1"
}
rigRows(){ ## index, member, verb, glob -- how many rows of that member, verb and glob
	LC_ALL=C awk -F'\t' -v rowsMember="$2" -v rowsVerb="$3" -v rowsGlob="$4" '$1 == rowsMember && $2 == rowsVerb && $3 == rowsGlob { n++ ; } END { print n + 0 ; }' "$1"
}
## The floor rows the index holds for a workspace's own source/. The standing read every
## workspace's registry carries is no floor row and is not counted (see the header).
rigOwnSource(){ ## index, workspace
	LC_ALL=C awk -F'\t' -v ownPrefix="${2%/}/source/" 'index( $3, ownPrefix ) == 1 && $5 == "floor" { n++ ; } END { print n + 0 ; }' "$1"
}

rigRun "$rigWsA" --make-agents-indices
[ "$rigRc" = 0 ] || rigRefuse "--make-agents-indices failed in the workspace under .local/agents/scratch/: $( LC_ALL=C grep -m3 -e ERROR -e WARNING "$rigTmp/err" )"
rigRun "$rigWsB" --make-agents-indices
[ "$rigRc" = 0 ] || rigRefuse "--make-agents-indices failed in the workspace under .local/agents/spawned/: $( LC_ALL=C grep -m3 -e ERROR -e WARNING "$rigTmp/err" )"
rigIdxA="$( rigIndexOf "$rigWsA" )" rigIdxB="$( rigIndexOf "$rigWsB" )"
[ -f "$rigIdxA" ] || rigRefuse "no grants index was written for the workspace under .local/agents/scratch/: $rigIdxA"
[ -f "$rigIdxB" ] || rigRefuse "no grants index was written for the workspace under .local/agents/spawned/: $rigIdxB"

rigAssert "scratch: the workspace carries its own floor write <ws>/.local/temp/** row, once per member" \
	"$( rigSeat "$rigIdxA" write "$rigWsA/.local/temp/**" )" "all-one"
rigAssert "spawned: the workspace carries its own such row too" \
	"$( rigSeat "$rigIdxB" write "$rigWsB/.local/temp/**" )" "all-one"
rigAssert "either one: no floor row reads its own source/" \
	"$( rigOwnSource "$rigIdxA" "$rigWsA" ):$( rigOwnSource "$rigIdxB" "$rigWsB" )" "0:0"
## The control: the machine's root keeps its temp row, the source rows the floor loop emits for a
## root (MAGIC.md, README.md and docs/**.md read, source/**.epic.md read, source/**/MAGIC.md
## write), and magic-librarian's standing read of its source/**.
rigAssert "control: the machine's own root keeps its temp row, its source floor rows and the librarian's source read" \
	"$( rigSeat "$rigIdxA" write "$rigMachineRoot/.local/temp/**" ):$( rigSeat "$rigIdxA" read "$rigMachineRoot/source/**/MAGIC.md" ):$( rigSeat "$rigIdxA" read "$rigMachineRoot/source/**/README.md" ):$( rigSeat "$rigIdxA" read "$rigMachineRoot/source/**/docs/**.md" ):$( rigSeat "$rigIdxA" read "$rigMachineRoot/source/**.epic.md" ):$( rigSeat "$rigIdxA" write "$rigMachineRoot/source/**/MAGIC.md" ):$( rigRows "$rigIdxA" magic-librarian read "$rigMachineRoot/source/**" )" \
	"all-one:all-one:all-one:all-one:all-one:all-one:1"
rigAssert "a declared * row still unrolls over the machine's roots, once each, and never over a root of its own" \
	"$( rigRows "$rigIdxA" keeper-w read "$rigMachineRoot/any/**" ):$( rigRows "$rigIdxA" keeper-w read "$rigWsA/any/**" ):$( rigRows "$rigIdxB" keeper-w read "$rigMachineRoot/any/**" ):$( rigRows "$rigIdxB" keeper-w read "$rigWsB/any/**" )" \
	"1:0:1:0"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ GRANTS TEMP FLOOR ROW CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'GRANTS_TEMP_FLOOR_ROW: OK (%d assertions)\n' "$rigPass"
