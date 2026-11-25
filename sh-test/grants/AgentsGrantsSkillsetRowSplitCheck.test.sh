#!/usr/bin/env bash
## Behavioural check: the librarian's skillset grant is a property of a workspace of the machine,
## and never of the workspace the index is built for (AgentsTools.Grants.include, the second bullet
## of the item's ruling; AgentsToolsGrantsMemberSkills).
## The emitter asks AgentsToolsGrantsMemberSkills once per root of LocalToolsPlacesWorkspaceRoots,
## the list that drops every root holding /.local/agents/spawned/ or /.local/agents/scratch/. A
## skillset-linked member skill inside the given workspace's own source/ therefore reaches no row,
## and one inside a machine root still reaches its read and its approve row.
## Held, on the index the real operation writes (--make-agents-indices), never on a row read out of
## the source:
##   1. the given workspace, under .local/agents/scratch/, gains no skillset grant row over its own
##      source/, for any member;
##   2. control: a skill that is a plain folder of the rig HOME's skills folder yields one read row
##      and one approve row. It passes on the tree before the change and on the tree after it, so a
##      zero in 1 is a finding about the split, never the rig failing to emit any skillset row;
##   3. the machine root's own skill, linked into that root's source/, yields one read row and one
##      approve row: the positive half of the ruling, and red on the tree before the change;
##   4. the given workspace keeps its own `floor write <ws>/.local/temp/**` row, once per member:
##      the change that answers 1 must not break the split's first half.
## THE CONTROL OF 3 IS A NAME, NOT A FOLDER. The machine root is named by the rig HOME's places
## registry and by nothing else. Its source is made under the workspace's own .local/temp, because
## rigTempDir puts the rig under <MMDAPP>/.local/agents/scratch/sh-test/, which the root list
## filters on: a root made inside the rig would be dropped and the control would read zero.
## MDCI_HOME names the rig's home, which is what makes its skills folder the machine's skillset;
## LocalToolsPlacesHome otherwise takes the workspace owner's passwd home.
## Offline: HOME, MDCI_HOME, both workspaces, the member set, the team data and the places are this
## rig's own; a fake curl is first on PATH.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP names no workspace, so this rig has no place to live}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigFn="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigFn" ] || rigRefuse "not found at the origin this workspace resolves: $rigFn"
rigMyxCommon="$( command -v myx.common 2>/dev/null )"
[ -n "$rigMyxCommon" ] || rigRefuse "myx.common is not on PATH, so no source project could be scanned for its declares"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsGrantsSkillsetRowSplitCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigMachineRoot="${MMDAPP%/}/.local/temp/agents-grants-skillset-row-split-machine-ws"
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp" ; rm -rf -- "$rigMachineRoot"' EXIT
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
mkdir -p "$rigHome/.agents/magic-team" "$rigHome/.claude/skills" "$rigData"
for rigName in magic-tester magic-librarian keeper-w keeper-d ; do
	mkdir -p "$rigSkills/$rigName"
	printf '# %s\n' "$rigName" > "$rigSkills/$rigName/$rigName.basic.md"
done
rigWsMake(){ ## path
	local makeWs="${1%/}"
	mkdir -p "$makeWs/.local/agents" "$makeWs/source/rig/rig-proj/docs"
	printf 'Name: rig\n' > "$makeWs/source/rig/repository.inf"
	printf 'Name: rig-proj\n' > "$makeWs/source/rig/rig-proj/project.inf"
	printf 'rig-seed\n' > "$makeWs/source/rig/rig-proj/MAGIC.md"
	: > "$makeWs/.local/agents/members.registry"
}
## A member skill inside a workspace's own source/, linked into the rig HOME's skills folder, so
## it is a skill this machine holds and its real folder lies under that workspace's source/.
rigSkillLinked(){ ## workspace, skill name
	local skillWs="${1%/}" skillName="$2"
	mkdir -p "$skillWs/source/rig/rig-proj/$skillName"
	printf '# %s\n' "$skillName" > "$skillWs/source/rig/rig-proj/$skillName/$skillName.basic.md"
	printf -- '---\nstatus: active\n---\n# %s\n' "$skillName" > "$skillWs/source/rig/rig-proj/$skillName/SKILL.md"
	ln -s "$skillWs/source/rig/rig-proj/$skillName" "$rigHome/.claude/skills/$skillName"
}

## The given workspace, under one of the two segments the root list filters on, holding a skill of
## its own: assertions 1 and 4.
rigWsA="$rigTmp/outer-a/.local/agents/scratch/ws-a"
rigWsMake "$rigWsA"
rigSkillLinked "$rigWsA" rigskill
## The plain folder skill of assertion 2: no source of any workspace, so no root decides it.
mkdir -p "$rigHome/.claude/skills/plainskill"
printf '# plainskill\n' > "$rigHome/.claude/skills/plainskill/plainskill.basic.md"
## The machine root of assertion 3, named by the rig HOME's places registry alone.
rigWsMake "$rigMachineRoot"
rigSkillLinked "$rigMachineRoot" machineskill
printf 'machine-ws\t%s\n' "$rigMachineRoot" > "$rigHome/.agents/magic-team/directories.registry"

## The index is named after the member set root, so under a member set root of the rig's own it
## carries that root as its suffix, every other character as `_`
## (AgentsToolsGrantsIndexWrite, sh-lib/grants/AgentsTools.Grants.include).
rigIndexOf(){ ## workspace
	printf '%s/.local/agents/grants.index.%s' "${1%/}" "${rigSkills//[!A-Za-z0-9._-]/_}"
}
rigRun(){ ## workspace, operation and arguments... -- the tool there, rig HOME, clean env; rc in rigRc
	local runWs="${1%/}" ; shift
	rigRc=0
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" MDCI_HOME="$rigHome" PATH="$rigTmp/bin:${rigMyxCommon%/*}:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$runWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_DATA_ROOT="$rigData" RIG_TMP="$rigTmp" bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$HOME" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "'"$rigFn"'" "$@"
		' rig "$@" > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
## The skillset grant rows over a path: rows whose note is `<workspace>:skillset`, so a registry
## row of the same glob is never counted.
rigSkillRows(){ ## index, glob, verb
	LC_ALL=C awk -F'\t' -v want="$2" -v verb="$3" '$3 == want && $2 == verb && $6 ~ /:skillset$/ { n++ ; } END { print n + 0 ; }' "$1"
}
rigOwnSkillset(){ ## index, workspace
	LC_ALL=C awk -F'\t' -v ownPrefix="${2%/}/source/" 'index( $3, ownPrefix ) == 1 && $6 ~ /:skillset$/ { n++ ; } END { print n + 0 ; }' "$1"
}
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

rigRun "$rigWsA" --make-agents-indices
[ "$rigRc" = 0 ] || rigRefuse "--make-agents-indices failed in the workspace under .local/agents/scratch/: $( LC_ALL=C grep -m3 -e ERROR -e WARNING "$rigTmp/err" )"
rigIdxA="$( rigIndexOf "$rigWsA" )"
[ -f "$rigIdxA" ] || rigRefuse "no grants index was written for the workspace under .local/agents/scratch/: $rigIdxA"

rigAssert "the given workspace gains no skillset grant row over its own source/, for any member" \
	"$( rigOwnSkillset "$rigIdxA" "$rigWsA" )" "0"
rigAssert "control: a plain folder skill yields one read row and one approve row" \
	"$( rigSkillRows "$rigIdxA" "$rigHome/.claude/skills/plainskill/**.md" read ):$( rigSkillRows "$rigIdxA" "$rigHome/.claude/skills/plainskill/**.md" approve )" "1:1"
rigAssert "the machine root's own skill yields one read row and one approve row" \
	"$( rigSkillRows "$rigIdxA" "$rigMachineRoot/source/rig/rig-proj/machineskill/**.md" read ):$( rigSkillRows "$rigIdxA" "$rigMachineRoot/source/rig/rig-proj/machineskill/**.md" approve )" "1:1"
rigAssert "the given workspace keeps its own floor write <ws>/.local/temp/** row, once per member" \
	"$( rigSeat "$rigIdxA" write "$rigWsA/.local/temp/**" )" "all-one"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ GRANTS SKILLSET ROW SPLIT CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'GRANTS_SKILLSET_ROW_SPLIT: OK (%d assertions)\n' "$rigPass"
