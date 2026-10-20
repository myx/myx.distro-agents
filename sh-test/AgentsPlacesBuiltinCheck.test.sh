#!/usr/bin/env bash
## The built-in places, run rather than read, against a rig HOME and rig workspaces under one
## mktemp tree (AgentsToolsPlacesBuiltinRows, AgentsTools.Places.include): `.skillset-shared`,
## the machine's skillset in HOME, and `.skillset-.local`, the member set of the workspace a
## run is in. Hardcoded, in every merged list, never a registry row; and no custom place has a
## name that starts with a dot.
##   1. both names resolve, wherever a place is taken: the resolver, a member's path by name;
##      on a machine whose HOME holds .agents/skills only, on one that holds neither, and
##      under MDAT_SKILLSET_ROOT;
##   2. both are shown, wherever a place is shown: the place of a path, the members' and the
##      owner's lists, a permission's shown target, the ceilings of the grants index;
##   3. a row cannot take such a name: a directive, an owner row, a row another workspace's
##      registry holds; a dot inside a name is anyone's;
##   4. a link and its target give the same answer: a permission entry asked through a link
##      under a built-in place is asked for the real file, as one asked by the file's own path.
## Offline: HOME, every workspace, every registry and the team data are under this rig's own
## mktemp tree; a fake curl is first on PATH.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigHere="$rigPackage/sh-lib"
rigFn="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigFn" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.Places.include" "$rigHere/common/AgentsTools.InternDirectory.include" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
rigMyxCommon="$( command -v myx.common 2>/dev/null )"
[ -n "$rigMyxCommon" ] || rigRefuse "myx.common is not on PATH, so no source project could be scanned for its declares"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsPlacesBuiltinCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
rigN(){ ## file, fixed text -- how many lines hold it
	LC_ALL=C grep -c -F -- "$2" "$1" 2>/dev/null || :
}
rigCut(){ ## -- stdin with the rig tree written T
	LC_ALL=C sed "s|$rigTmp|T|g"
}
mkdir -p "$rigTmp/bin"
printf '#!/bin/sh\necho "rig fake curl: no request leaves this box" >&2\nexit 7\n' > "$rigTmp/bin/curl"
chmod +x "$rigTmp/bin/curl"

## The machine: ws-main, whose one source project declares a plain place, three that would take
## a dot name and one with dots inside its name, and holds a member's skill; ws-two beside it.
rigHome="$rigTmp/home" rigData="$rigTmp/data" rigMain="$rigTmp/ws-main" rigTwo="$rigTmp/ws-two"
rigSkills="$rigHome/.claude/skills"
rigMembers="$rigMain/.local/agents/members"
rigSource="$rigMain/source/rig/rig-proj/skillset"
mkdir -p "$rigSkills/keeper-local" "$rigSource/keeper-linked/reference" "$rigMembers/keeper-real" "$rigData/board/running" \
	"$rigTmp/plain" "$rigTmp/elsewhere" "$rigTmp/mine" "$rigTmp/dots" "$rigTmp/ws-dot" "$rigTmp/.hidden" "$rigTwo/.local" "$rigTwo/source/rig/rig-proj"
printf 'Name: rig\n' > "$rigMain/source/rig/repository.inf"
printf 'Name: rig-proj\n\nDeclares: \\\n\t%s \\\n\t%s \\\n\t%s \\\n\t%s \\\n\t%s \\\n\n' \
	"magic-team:directory:plain:ceiling-write:$rigTmp/plain:*" \
	"magic-team:directory:.skillset-shared:ceiling-read:$rigTmp/elsewhere:*" \
	"magic-team:directory:.mine:ceiling-write:$rigTmp/mine:*" \
	"magic-team:workspace:.ws-dot:$rigTmp/ws-dot:*" \
	"magic-team:directory:dir.with.dots:ceiling-write:$rigTmp/dots:*" > "$rigMain/source/rig/rig-proj/project.inf"
printf 'Name: rig\n' > "$rigTwo/source/rig/repository.inf"
printf 'Name: rig-proj\n\n' > "$rigTwo/source/rig/rig-proj/project.inf"
: > "$rigMain/.local/agents/members.registry"
for rigName in magic-coordinator keeper-linked ; do
	mkdir -p "$rigSource/$rigName"
	printf 'rig\n' > "$rigSource/$rigName/$rigName.basic.md"
	ln -s "$rigSource/$rigName" "$rigMembers/$rigName"
	ln -s "$rigSource/$rigName" "$rigSkills/$rigName"
done
printf 'rig\n' > "$rigMembers/keeper-real/keeper-real.basic.md"
for rigOne in "$rigSkills/keeper-local/a.md" "$rigSource/keeper-linked/a.md" "$rigSource/keeper-linked/reference/n.md" "$rigMembers/keeper-real/b.md" ; do printf 'rig-seed\n' > "$rigOne" ; done
printf -- '---\nstatus: task\nowner: magic-coordinator\n---\n\n# Task\n' > "$rigData/board/running/task-rig.md"
mkdir -p "$rigMain/.local/agents/spawned/sb-c/output"
printf -- '---\nsession-id: s-coord\nspawn-id: s-coord\nowner: magic-coordinator\nstatus: spawn-started\n---\n\n# Spawn session\n' > "$rigMain/.local/agents/spawned/sb-c/s-coord.md"

RIG_WS="$rigMain" RIG_HOME="$rigHome" RIG_AGENT="" RIG_SESSION="" RIG_SKILLSET=""
rigRun(){ ## op and arguments... -- the tool in RIG_WS under RIG_HOME, clean env; out, err, rigRc
	rigRc=0
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$RIG_HOME" PATH="$rigTmp/bin:${rigMyxCommon%/*}:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$RIG_WS" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_DATA_ROOT="$rigData" RIG_TMP="$rigTmp" ${RIG_SKILLSET:+MDAT_SKILLSET_ROOT="$RIG_SKILLSET"} ${RIG_AGENT:+MDAT_SPAWN_AGENT="$RIG_AGENT"} ${RIG_SESSION:+MDAT_SPAWN_SESSION_ID="$RIG_SESSION"} bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$HOME" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "'"$rigFn"'" "$@"
		' rig "$@" > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigSays(){ ## op and arguments... -- its rc and its stdout, the rig tree written T, on one line
	rigRun "$@"
	printf '%s:%s' "$rigRc" "$( rigCut < "$rigTmp/out" | LC_ALL=C tr '\t\n' ' |' )"
}
rigRun --intern-directory-register
[ "$rigRc" = 0 ] || rigRefuse "the places of ws-main could not be registered: $( head -3 "$rigTmp/err" )"
cp "$rigTmp/err" "$rigTmp/register.err"
RIG_WS="$rigTwo" rigRun --intern-directory-register
[ "$rigRc" = 0 ] || rigRefuse "the places of ws-two could not be registered: $( head -3 "$rigTmp/err" )"

## ---------------------------------------------------------------- taken
echo "-- 1. both names resolve, wherever a place is taken --"
rigAssert "the machine's skillset in HOME, by its name"       "$( rigSays --intern-directory-resolve .skillset-shared )" "0:T/home/.claude/skills|"
rigAssert "the workspace's own member set, by its name"       "$( rigSays --intern-directory-resolve .skillset-.local )" "0:T/ws-main/.local/agents/members|"
rigAssert "a member's path under each, by name"               "$( rigSays --member-directory-path .skillset-shared/keeper-local/a.md )$( rigSays --member-directory-path .skillset-.local/keeper-real )" "0:T/home/.claude/skills/keeper-local/a.md|0:T/ws-main/.local/agents/members/keeper-real|"
rigAssert "the member set is the workspace's a run is in"     "$( RIG_WS="$rigTwo" rigSays --intern-directory-resolve .skillset-.local )" "0:T/ws-two/.local/agents/members|"
mkdir -p "$rigTmp/home-agents/.agents/skills" "$rigTmp/home-none" "$rigTmp/skills-env"
rigAssert "a HOME that holds .agents/skills only: the same name, that folder" "$( RIG_HOME="$rigTmp/home-agents" rigSays --intern-directory-resolve .skillset-shared )" "0:T/home-agents/.agents/skills|"
rigAssert "a HOME that holds neither: the folder the clients read, said absent" "$( RIG_HOME="$rigTmp/home-none" rigSays --intern-directory-resolve .skillset-shared ):$( rigN "$rigTmp/err" 'is absent on this host' )" "0:T/home-none/.claude/skills|:1"
rigAssert "under MDAT_SKILLSET_ROOT the member set is what it names" "$( RIG_SKILLSET="$rigTmp/skills-env" rigSays --intern-directory-resolve .skillset-.local )" "0:T/skills-env|"

## ---------------------------------------------------------------- shown
echo "-- 2. both are shown, wherever a place is shown --"
rigAssert "a path under the machine's skillset is shown by that name" "$( rigSays --intern-directory-of "$rigSkills/keeper-local/a.md" )$( rigSays --intern-directory-of "$rigSkills" )" "0:.skillset-shared:keeper-local/a.md|0:.skillset-shared:.|"
rigAssert "one under the member set by its name, not the workspace's" "$( rigSays --intern-directory-of "$rigMembers/keeper-real/b.md" )" "0:.skillset-.local:keeper-real/b.md|"
rigAssert "control: another path of the workspace keeps the workspace's name" "$( rigSays --intern-directory-of "$rigMain/source/rig/rig-proj/project.inf" )" "0:ws-main:source/rig/rig-proj/project.inf|"
rigRun --member-directory-list
rigAssert "the members' list holds both, first, with no path" "$rigRc:$( head -2 "$rigTmp/out" | LC_ALL=C tr '\t\n' ' |' ):$( LC_ALL=C grep -c / "$rigTmp/out" )" "0:.skillset-shared directory read-write|.skillset-.local directory read-write|:0"
rigRun --owner-workspace-list
rigAssert "the owner's list holds both, with their folders"   "$rigRc:$( head -2 "$rigTmp/out" | rigCut | LC_ALL=C tr '\t\n' ' |' )" "0:.skillset-shared directory read-write T/home/.claude/skills present|.skillset-.local directory read-write T/ws-main/.local/agents/members present|"
rigAssert "a permission shows its target by the name"         "$( rigSays --intern-op-permission-place magic-coordinator "$rigSkills/keeper-local/a.md" )" "0:.skillset-shared:keeper-local/a.md|"
rigRun --intern-op-permission-holds magic-coordinator Read "$rigSkills/keeper-local/a.md"
rigAssert "the grants index holds both as places, read-write" "$( LC_ALL=C awk -F'\t' '$1 == "*" && $2 == "ceiling" && index( $6, "." ) == 1 { print $6 " " $5 }' "$rigMain/.local/agents/grants.index" 2> /dev/null | LC_ALL=C sort | LC_ALL=C tr '\n' '|' )" ".skillset-.local read-write|.skillset-shared read-write|"

## ---------------------------------------------------------------- never a row
echo "-- 3. a row cannot take a name that starts with a dot --"
rigAssert "each directive that names one is refused with one line" "$( rigN "$rigTmp/register.err" 'is refused: a name that starts with a dot is a built-in place' ):$( rigN "$rigTmp/register.err" 'place .skillset-shared is refused' ):$( rigN "$rigTmp/register.err" 'place .mine is refused' ):$( rigN "$rigTmp/register.err" 'place .ws-dot is refused' )" "3:1:1:1"
rigAssert "the registry holds none of them, and a name with dots inside" "$( LC_ALL=C cut -f1 "$rigMain/.local/agents/directories.registry" | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "dir.with.dots plain ws-main "
rigAssert "the built-in name still names the machine's skillset, never the directive's folder" "$( rigSays --intern-directory-resolve .skillset-shared )" "0:T/home/.claude/skills|"
rigAssert "a custom dot name names no place"                  "$( rigSays --intern-directory-resolve .mine ):$( rigN "$rigTmp/err" 'unknown place: .mine' )" "1::1"
rigRun --owner-workspace-upsert "$rigTmp/mine" --name .mine --kind directory --ceiling read-write
rigAssert "the owner cannot register one: refused, one line" "$rigRc:$( LC_ALL=C grep -c '⛔' "$rigTmp/err" ):$( rigN "$rigTmp/err" 'the name .mine starts with a dot, which only a built-in place' )" "1:1:1"
rigRun --owner-workspace-upsert "$rigTmp/elsewhere" --name .skillset-shared --kind directory --ceiling read-only
rigAssert "nor a built-in place's own name"                   "$rigRc:$( rigN "$rigTmp/err" 'the name .skillset-shared starts with a dot' ):$( rigSays --intern-directory-resolve .skillset-shared )" "1:1:0:T/home/.claude/skills|"
rigRun --owner-workspace-upsert "$rigTmp/.hidden" --kind directory --ceiling read-write
rigAssert "nor a folder under its own dot name: another --name is asked for" "$rigRc:$( rigN "$rigTmp/err" 'give this path another --name' )" "1:1"
rigRun --owner-workspace-forget .skillset-.local
rigAssert "a built-in place is not forgotten: refused, one line" "$rigRc:$( LC_ALL=C grep -c '⛔' "$rigTmp/err" ):$( rigN "$rigTmp/err" 'the name .skillset-.local starts with a dot, which only a built-in place' ):$( rigSays --intern-directory-resolve .skillset-.local )" "1:1:1:0:T/ws-main/.local/agents/members|"
## Rows another workspace's registry holds, as a hand or an earlier release could have left them.
printf '%s\tdirectory\tread-only\t%s\towner\n' .skillset-.local "$rigTmp/elsewhere" .planted "$rigTmp/mine" >> "$rigTwo/.local/agents/directories.registry"
printf '%s\t%s\n' .skillset-.local "$rigTwo" .planted "$rigTwo" >> "$rigHome/.agents/magic-team/directories.registry"
rigAssert "a row of another workspace's registry does not take the name" "$( rigSays --intern-directory-resolve .skillset-.local )$( rigSays --intern-directory-resolve .planted )" "0:T/ws-main/.local/agents/members|1:"
rigRun --owner-workspace-list
rigAssert "the list holds no such row, and says each refused"   "$( LC_ALL=C grep -c -e '^\.planted' -e 'elsewhere' "$rigTmp/out" ):$( rigN "$rigTmp/err" 'place .planted is refused' ):$( rigN "$rigTmp/err" 'place .skillset-.local is refused' )" "0:1:1"
rigRun --member-directory-list
rigAssert "the members' list still holds two dot names, both read-write" "$( LC_ALL=C grep '^\.' "$rigTmp/out" | LC_ALL=C tr '\t\n' ' |' )" ".skillset-shared directory read-write|.skillset-.local directory read-write|"

## ---------------------------------------------------------------- a link and its target
echo "-- 4. a link and its target give the same answer --"
rigReal="$rigSource/keeper-linked"
RIG_AGENT=magic-coordinator RIG_SESSION=s-coord
rigRun --magic-permission-set-request magic-coordinator task-rig --entry "Read:@.skillset-shared:keeper-linked/a.md" --scope task --session-id s-coord
rigAssert "an entry asked through the HOME link is asked for the real file" "$( rigN "$rigTmp/out" "PLACE: Read:$rigReal/a.md is .skillset-shared:keeper-linked/a.md" ):$( rigN "$rigTmp/out" "EXTRA: Read:$rigReal/a.md" )" "1:1"
rigRun --magic-permission-set-request magic-coordinator task-rig --entry "Read:@.skillset-.local:keeper-linked/a.md" --scope task --session-id s-coord
rigAssert "through the workspace's member link: the same file" "$( rigN "$rigTmp/out" "PLACE: Read:$rigReal/a.md is .skillset-.local:keeper-linked/a.md" ):$( rigN "$rigTmp/out" "EXTRA: Read:$rigReal/a.md" )" "1:1"
rigRun --magic-permission-set-request magic-coordinator task-rig --entry "Read:@ws-main:source/rig/rig-proj/skillset/keeper-linked/a.md" --scope task --session-id s-coord
rigAssert "by the file's own path under source: the same file" "$( rigN "$rigTmp/out" "EXTRA: Read:$rigReal/a.md" )" 1
rigRun --magic-permission-set-request magic-coordinator task-rig --entry "Read:@.skillset-shared:keeper-linked/reference/**" --scope task --session-id s-coord
rigAssert "a folder under the link, with everything in it"    "$( rigN "$rigTmp/out" "PLACE: Read:$rigReal/reference/** is .skillset-shared:keeper-linked/reference/**" ):$( rigN "$rigTmp/out" "EXTRA: Read:$rigReal/reference/**" )" "1:1"
rigRun --magic-permission-set-request magic-coordinator task-rig --entry "Read:@.skillset-shared:keeper-local/a.md" --scope task --session-id s-coord
rigAssert "a machine-local skill's file is its own, under HOME" "$( rigN "$rigTmp/out" "PLACE: Read:$rigSkills/keeper-local/a.md is .skillset-shared:keeper-local/a.md" ):$( rigN "$rigTmp/out" "EXTRA: Read:$rigSkills/keeper-local/a.md" )" "1:1"
RIG_AGENT="" RIG_SESSION=""

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ PLACES BUILT-IN CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'PLACES_BUILTIN: OK (%d assertions, offline, rig HOME only)\n' "$rigPass"
