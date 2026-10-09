#!/usr/bin/env bash
## The team's data lives in two places only (AgentsTools.TeamRegistry.include): a workspace's
## own .local/agents, and the machine-wide directory $HOME/.agents/magic-team. Checked, run
## rather than read, against a rig HOME and rig workspaces:
##   1. --install-skillset-symlinks writes the member registry there -- the workspace scope
##      into .local/agents/members.registry, the user-home scope into the machine-wide one,
##      each row the member, the workspace root, the link kind, the relative path and the
##      member directory -- and no registry file into any vendor link folder;
##   2. it writes the member index: this workspace's own members only, each name once, and
##      the members/ view the tools read, a stale link to another workspace's member removed
##      on a rewrite; MDAT_SKILLSET_ROOT defaults to that view; a member only another
##      workspace publishes is still found, through the shared registry (a source link
##      preferred);
##   3. nothing of ours reads a vendor link folder back: a member link re-pointed in
##      $HOME/.claude/skills changes no answer, and the old .linked.* files are not read;
##   4. the member-workspace resolver, the access-root producer, the grant union through
##      the shared pointers, the provenance tags and the tracked-workspace list all read
##      the new files;
##   5. --install-claude-permissions turns a declared allow-read into Read(...) rows, its
##      selector resolved exactly as allow-write's, tagged alike, projected into the
##      settings as Read only and into the read roots only; a malformed verb of either is
##      refused alike and leaves the registry as it stood.
## Offline: every path is under this rig's own mktemp tree, HOME included.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigLocalContext="$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/LocalContext.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigFn" "$rigLocalContext" "$rigHere/AgentsTools.TeamRegistry.include" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
rigTmp="$( mktemp -d -t AgentsTeamRegistryCheck )" || exit 1
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

rigHome="$rigTmp/home" rigWs="$rigTmp/ws-here" rigOther="$rigTmp/ws-other"
mkdir -p "$rigHome" "$rigWs/.local/myx/myx.distro-.local/sh-lib" "$rigWs/source" "$rigOther/source/ns/skillset/keeper-rig" "$rigTmp/copy/magic-coordinator"
ln -s "$rigLocalContext" "$rigWs/.local/myx/myx.distro-.local/sh-lib/LocalContext.include"
printf -- '---\nname: keeper-rig\n---\n' > "$rigOther/source/ns/skillset/keeper-rig/SKILL.md"
printf -- '---\nname: magic-coordinator\n---\n' > "$rigTmp/copy/magic-coordinator/SKILL.md"
rigBundle="$MDLT_ORIGIN/myx/myx.distro-agents/skillset/magic-team"
rigBundled="$( cd "$rigBundle" && for d in */ ; do [ "${d%/}" = trash ] || printf '%s\n' "${d%/}" ; done | LC_ALL=C sort -u )"
rigShared="$rigHome/.agents/magic-team/members.registry"

rigRun(){ ## op and arguments... -- the tool in the rig workspace, rig HOME, clean env
	env -i HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		RIG_TMP="$rigTmp" bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$HOME" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "'"$rigFn"'" "$@"
		' rig "$@"
}
## Another workspace already published two members: keeper-rig (its source) and its own
## magic-coordinator, which this workspace also bundles and so must win here.
mkdir -p "${rigShared%/*}"
printf '%s\t%s\t%s\t%s\t%s\n' \
	magic-coordinator "$rigOther" .local-symlink myx/x/magic-coordinator "$rigTmp/copy/magic-coordinator" \
	keeper-rig "$rigOther" origin-symlink ns/skillset/keeper-rig "$rigTmp/nowhere/keeper-rig" \
	keeper-rig "$rigOther" source-symlink ns/skillset/keeper-rig "$rigOther/source/ns/skillset/keeper-rig" > "$rigShared"

echo "-- the installer writes the registries and the index, never into a vendor folder --"
rigRun --install-skillset-symlinks > "$rigTmp/install.out" 2>&1
rigAssert "the install wrote the member index" "$( LC_ALL=C grep -c 'member index written' "$rigTmp/install.out" )" 1
rigAssert "no registry file in any vendor link folder" "$( ls -a "$rigWs/.claude/skills" "$rigWs/.agents/skills" 2>/dev/null | LC_ALL=C grep -c 'linked\.' )" 0
rigAssert "the workspace registry: one row per bundled member, rules row included" \
	"$( LC_ALL=C awk -F'\t' -v r="$rigWs" '$2 == r && NF == 5 && $3 != "rules-symlink" { print $1 }' "$rigWs/.local/agents/members.registry" | LC_ALL=C sort -u )" "$rigBundled"
rigAssert "its rows carry the member directory" \
	"$( LC_ALL=C awk -F'\t' '$1 == "magic-team" { print $5 }' "$rigWs/.local/agents/members.registry" )" "$rigBundle/magic-team"
rigRun --install-skillset-symlinks --scope user-home > "$rigTmp/install-home.out" 2>&1
rigAssert "no registry file in any home vendor folder" "$( ls -a "$rigHome/.claude/skills" "$rigHome/.agents/skills" "$rigHome/.copilot/skills" 2>/dev/null | LC_ALL=C grep -c 'linked\.' )" 0
rigAssert "the machine-wide registry: this workspace's rows added, the other's kept" \
	"$( LC_ALL=C awk -F'\t' -v r="$rigWs" '$2 == r { n++ } $2 != r { o++ } END { print n + 0, o + 0 }' "$rigShared" )" "$( printf '%s\n' "$rigBundled" | LC_ALL=C grep -c . ) 3"

echo "-- the member index: this workspace's own members only, each name once --"
rigIndex="$rigWs/.local/agents/members.index"
rigAssert "own members, in the index" \
	"$( LC_ALL=C awk -F'\t' '$3 == r' r="$rigWs" "$rigIndex" | cut -f1 | LC_ALL=C sort -u )" "$rigBundled"
rigAssert "the index holds only this workspace's own rows" \
	"$( LC_ALL=C awk -F'\t' '$3 != r' r="$rigWs" "$rigIndex" | LC_ALL=C grep -c . )" 0
rigAssert "the bundled magic-coordinator wins over the other workspace's copy" \
	"$( LC_ALL=C awk -F'\t' '$1 == "magic-coordinator" { print $2 }' "$rigIndex" )" "$rigBundle/magic-coordinator"
rigAssert "a member only another workspace publishes has no row in the index" \
	"$( LC_ALL=C awk -F'\t' '$1 == "keeper-rig"' "$rigIndex" | LC_ALL=C grep -c . )" 0
rigAssert "each name once" "$( cut -f1 "$rigIndex" | LC_ALL=C sort | uniq -d | LC_ALL=C grep -c . )" 0
rigAssert "the members/ view links each own member to its directory, and holds nothing else" \
	"$( readlink "$rigWs/.local/agents/members/magic-coordinator" ) $( ls -A "$rigWs/.local/agents/members" | LC_ALL=C sort -u )" \
	"$rigBundle/magic-coordinator $rigBundled"
rigAssert "the other workspace's member has no link and no folder in the view" \
	"$( [ -e "$rigWs/.local/agents/members/keeper-rig" ] || [ -L "$rigWs/.local/agents/members/keeper-rig" ] && printf present || printf absent )" absent
rigAssert "MDAT_SKILLSET_ROOT defaults to that view (a member op names it)" \
	"$( rigRun --member-audit-item-read no-such-rig-member rig-item 2>&1 | LC_ALL=C grep -c "$rigWs/.local/agents/members/no-such-rig-member" )" 1
rigDirectory(){ ## member -- AgentsToolsTeamMemberDirectory in the rig workspace, rig HOME
	env -i HOME="$rigHome" PATH=/usr/bin:/bin MMDAPP="$rigWs" MDAT_SKILLSET_ROOT="$rigWs/.local/agents/members" bash -c '. "'"$rigHere"'/AgentsTools.TeamRegistry.include" ; AgentsToolsTeamMemberDirectory "$1" ; printf "rc=%s" "$?"' rig "$1"
}
rigAssert "a member of another workspace is still found, through the shared registry, its source link preferred" \
	"$( rigDirectory keeper-rig | LC_ALL=C tr '\n' ' ' )" "$rigOther/source/ns/skillset/keeper-rig rc=0"
rigAssert "an own member is found in this workspace's own view" \
	"$( rigDirectory magic-coordinator | LC_ALL=C tr '\n' ' ' )" "$rigWs/.local/agents/members/magic-coordinator rc=0"
rigAssert "a name no workspace publishes is not found" "$( rigDirectory no-such-rig-member )" "rc=1"

echo "-- a rewrite removes a stale link to another workspace's member --"
ln -s "$rigOther/source/ns/skillset/keeper-rig" "$rigWs/.local/agents/members/keeper-rig"
rm -f "$rigWs/.local/agents/members/magic-coordinator"
ln -s "$rigTmp/copy/magic-coordinator" "$rigWs/.local/agents/members/magic-coordinator"
printf 'keeper-rig\t%s\t%s\tsource-symlink\n' "$rigOther/source/ns/skillset/keeper-rig" "$rigOther" >> "$rigIndex"
rigAssert "control: the planted foreign link and row are there before the rewrite" \
	"$( readlink "$rigWs/.local/agents/members/keeper-rig" ) $( LC_ALL=C grep -c '^keeper-rig' "$rigIndex" )" "$rigOther/source/ns/skillset/keeper-rig 1"
( . "$rigHere/AgentsTools.TeamRegistry.include" ; HOME="$rigHome" AgentsToolsTeamMemberIndexWrite "$rigWs" )
rigAssert "the rewrite removed the foreign link and the foreign row" \
	"$( [ -L "$rigWs/.local/agents/members/keeper-rig" ] && printf link || printf none ) $( LC_ALL=C grep -c '^keeper-rig' "$rigIndex" )" "none 0"
rigAssert "and re-pointed an own member's link from another workspace's copy to its own" \
	"$( readlink "$rigWs/.local/agents/members/magic-coordinator" )" "$rigBundle/magic-coordinator"

echo "-- nothing reads a vendor link folder back --"
rm -f "$rigHome/.claude/skills/magic-coordinator" "$rigWs/.claude/skills/magic-coordinator"
ln -s "$rigTmp/copy/magic-coordinator" "$rigHome/.claude/skills/magic-coordinator"
ln -s "$rigTmp/copy/magic-coordinator" "$rigWs/.claude/skills/magic-coordinator"
printf 'magic-coordinator:ws-here:source-symlink:poison\n' > "$rigHome/.claude/skills/.linked.magic-team.members.txt"
rigMembers(){ ## purpose
	env -i HOME="$rigHome" PATH=/usr/bin:/bin MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigWs/.local/agents/members" bash -c '. "'"$rigHere"'/AgentsTools.ClientAccessRoots.include" ; AgentsToolsClientAccessRootsMembers '"$1"
}
rigAssert "acting members: the index's directories, a re-pointed home link ignored" \
	"$( rigMembers acting | LC_ALL=C grep -c "$rigTmp/copy" )" 0
rigAssert "readable members are this workspace's own: the other workspace's member is granted by its own" \
	"$( rigMembers readable | LC_ALL=C grep -c "keeper-rig" )" 0
rigAssert "control: readable members hold this workspace's own" \
	"$( rigMembers readable | LC_ALL=C grep -c "$rigBundle/magic-coordinator" )" 1
( . "$rigHere/AgentsTools.TeamRegistry.include" ; HOME="$rigHome" AgentsToolsTeamMemberIndexWrite "$rigWs" )
rigAssert "a rebuilt index still ignores the vendor folders" \
	"$( LC_ALL=C awk -F'\t' '$1 == "magic-coordinator" { print $2 }' "$rigIndex" )" "$rigBundle/magic-coordinator"

echo "-- the resolver, the grants, the tags and the workspace list read the new files --"
rigRun --owner-workspace-upsert "$rigOther" >/dev/null 2>&1
rigAssert "an install into the machine registry tracks its own workspace" "$( LC_ALL=C grep -c -x -F "$( cd "$rigWs" && pwd )" "$rigHome/.agents/magic-team/known-workspaces.registry" 2>/dev/null )" 1
rigAssert "the tracked workspace list is the machine-wide one" "$( LC_ALL=C grep -c -x -F "$rigOther" "$rigHome/.agents/magic-team/known-workspaces.registry" 2>/dev/null )" 1
rigAssert "and no list is written beside the vendor links" "$( [ -e "$rigHome/.claude/skills/.human-owner.workspaces.md" ] && printf yes || printf no )" no
rigAssert "the resolver switches to the workspace publishing the member's source" \
	"$( env -i HOME="$rigHome" PATH=/usr/bin:/bin MMDAPP="$rigWs" bash -c '. "'"$rigHere"'/AgentsTools.MemberWorkspace.include" ; AgentsToolsMemberWorkspaceResolve keeper-rig --rig' 2>&1 )" "$rigOther"
rigAssert "and stays for a member present here" \
	"$( env -i HOME="$rigHome" PATH=/usr/bin:/bin MMDAPP="$rigWs" bash -c '. "'"$rigHere"'/AgentsTools.MemberWorkspace.include" ; AgentsToolsMemberWorkspaceResolve magic-coordinator --rig' 2>&1 )" ""
mkdir -p "$rigWs/.local/agents" "$rigOther/.local/agents" "$rigTmp/g1/deep" "$rigTmp/g2"
printf 'a:ws-here:workspace:Edit(/%s/g1/deep/**)\n' "$rigTmp" > "$rigWs/.local/agents/permissions.registry"
printf 'b:ws-other:workspace:Edit(/%s/g2/*.md)\n' "$rigTmp" > "$rigOther/.local/agents/permissions.registry"
printf '# header\nb:ws-other:wildcard:%s/g2\n' "$rigTmp" > "$rigOther/.local/agents/permissions-tags.registry"
printf 'a:ws-here:poison:Edit(/poison/**)\n' > "$rigHome/.claude/skills/.linked.magic-team.permissions.txt"
rigGrants(){
	env -i HOME="$rigHome" PATH=/usr/bin:/bin MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "'"$rigHere"'/AgentsTools.ClientAccessRoots.include" ; AgentsToolsClientAccessGrantRoots | tr "\n" " " ; AgentsToolsClientAccessRootTag "'"$rigTmp"'/g2"'
}
rigAssert "grants without a pointer: this workspace's own only" "$( rigGrants )" "$rigTmp/g1/deep "
( . "$rigHere/AgentsTools.TeamRegistry.include" ; HOME="$rigHome" AgentsToolsTeamGrantPointerUpsert "$rigOther" ; HOME="$rigHome" AgentsToolsTeamGrantPointerUpsert "$rigOther" )
rigAssert "the pointer is recorded once, and holds only the root" "$( cat "$rigHome/.agents/magic-team/permissions.registry" )" "$rigOther"
rigAssert "with it, the union of both workspaces' own grants, and the other's tag" "$( rigGrants )" "$rigTmp/g1/deep $rigTmp/g2 wildcard"

echo "-- a user-home slot: the workspace holding the member in its source takes it from an installed copy only --"
## Its own HOME. ws-src holds the bundle in its own source/ (a link to this origin, read
## only); ws-inst holds it as an installed copy under .local/myx, the tooling linked and the
## bundle copied, one file added so the two copies differ; ws-other-inst and ws-other-src
## are another workspace's installed and source copies the slots start at. The member scan
## is handed in, so no project tree is walked.
rigSlotHome="$rigTmp/slot-home" rigSlots="$rigTmp/slot-home/.claude/skills"
rigSrcWs="$rigTmp/ws-src" rigInstWs="$rigTmp/ws-inst"
rigOtherInst="$rigTmp/ws-other-inst/.local/myx/myx.distro-agents/skillset/magic-team"
rigOtherSrc="$rigTmp/ws-other-src/source/myx/myx.distro-agents/skillset/magic-team"
mkdir -p "$rigSlots" "$rigSrcWs/.local/myx/myx.distro-.local/sh-lib" "$rigInstWs/.local/myx/myx.distro-agents/skillset" "$rigOtherInst/magic-coordinator" "$rigOtherSrc/magic-architect"
ln -s "$MDLT_ORIGIN" "$rigSrcWs/source"
ln -s "$rigLocalContext" "$rigSrcWs/.local/myx/myx.distro-.local/sh-lib/LocalContext.include"
for rigEntry in "$MDLT_ORIGIN/myx"/* ; do [ "${rigEntry##*/}" = myx.distro-agents ] || ln -s "$rigEntry" "$rigInstWs/.local/myx/${rigEntry##*/}" ; done
for rigEntry in "$MDLT_ORIGIN/myx/myx.distro-agents"/* ; do [ "${rigEntry##*/}" = skillset ] || ln -s "$rigEntry" "$rigInstWs/.local/myx/myx.distro-agents/${rigEntry##*/}" ; done
cp -R "$rigBundle" "$rigInstWs/.local/myx/myx.distro-agents/skillset/" || rigRefuse "could not copy the bundle into the rig's installed copy"
printf 'rig installed copy\n' > "$rigInstWs/.local/myx/myx.distro-agents/skillset/magic-team/magic-coordinator/rig-installed.md"
printf -- '---\nname: magic-coordinator\n---\n' > "$rigOtherInst/magic-coordinator/SKILL.md"
printf -- '---\nname: magic-architect\n---\n' > "$rigOtherSrc/magic-architect/SKILL.md"
ln -s "$rigOtherInst/magic-coordinator" "$rigSlots/magic-coordinator"
ln -s "$rigOtherSrc/magic-architect" "$rigSlots/magic-architect"
rigSlotRun(){ ## workspace, origin -- one user-home pass into the rig slots; output in slot.out, rc in rigSlotRc
	rigSlotRc=0
	env -i HOME="$rigSlotHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$1" MDLT_ORIGIN="$2" MDLT_OPTION="--run-from-path $2" \
		MDSC_SKILLSET_PRESCAN=1 MDSC_SKILLSET_MEMBERNAMES="$rigBundled" MDSC_SKILLSET_MEMBERSOURCES="" MDSC_SKILLSET_DISCOVERY_TRUSTED=true MDSC_SKILLSET_DISCOVERY_ERROR=false \
		RIG_TMP="$rigTmp" bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$HOME" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --install-skillset-symlinks --scope user-home --workspace "$MMDAPP" --target-root "$HOME/.claude/skills"
		' > "$rigTmp/slot.out" 2>&1 || rigSlotRc=$?
}
rigSlotRows(){ ## member -- that member's rows in the slot HOME's registry: workspace basename and kind
	LC_ALL=C awk -F'\t' -v m="$1" '$1 == m { w = $2 ; sub( /.*\//, "", w ) ; print w ":" $3 }' "$rigSlotHome/.agents/magic-team/members.registry" 2>/dev/null | LC_ALL=C sort | LC_ALL=C tr '\n' ' '
}
rigSrcBundle="$rigSrcWs/source/myx/myx.distro-agents/skillset/magic-team"
rigSlotRun "$rigSrcWs" "$rigSrcWs/source"
rigAssert "control: the source workspace's pass ran clean, rc 0 and no error line of the install" "$rigSlotRc $( LC_ALL=C grep -c '⛔.*--install-skillset-symlinks' "$rigTmp/slot.out" )" "0 0"
rigAssert "a slot on another workspace's installed copy is taken by the workspace holding the member in its source" \
	"$( readlink "$rigSlots/magic-coordinator" )" "$rigSrcBundle/magic-coordinator"
rigAssert "and that workspace registers the slot, as its source" "$( rigSlotRows magic-coordinator )" "ws-src:source-symlink "
rigAssert "a slot on another workspace's source copy is kept" "$( readlink "$rigSlots/magic-architect" )" "$rigOtherSrc/magic-architect"
rigAssert "with one warning, naming both copies" \
	"$( LC_ALL=C grep -c 'two source copies' "$rigTmp/slot.out" ) $( LC_ALL=C grep 'two source copies' "$rigTmp/slot.out" | LC_ALL=C grep -c -F -e "$rigOtherSrc/magic-architect" | LC_ALL=C tr -d ' ' )$( LC_ALL=C grep 'two source copies' "$rigTmp/slot.out" | LC_ALL=C grep -c -F -e "$rigSrcBundle/magic-architect" )" "1 11"
rigAssert "and the source workspace's own copy is registered beside it" "$( rigSlotRows magic-architect )" "ws-src:source-symlink "
rigAssert "a free slot is linked to the source as before" "$( readlink "$rigSlots/magic-tester" )" "$rigSrcBundle/magic-tester"
rigSlotRun "$rigInstWs" "$rigInstWs/.local"
rigAssert "control: the installed-copy workspace's pass ran clean, rc 0 and no error line of the install" "$rigSlotRc $( LC_ALL=C grep -c '⛔.*--install-skillset-symlinks' "$rigTmp/slot.out" )" "0 0"
rigAssert "an installed-copy workspace never takes a slot from a source workspace" \
	"$( readlink "$rigSlots/magic-coordinator" ):$( readlink "$rigSlots/magic-tester" )" "$rigSrcBundle/magic-coordinator:$rigSrcBundle/magic-tester"
rigAssert "and says nothing of two source copies" "$( LC_ALL=C grep -c 'two source copies' "$rigTmp/slot.out" )" 0
rigAssert "every copy stays listed in the machine registry, one row per member and workspace" "$( rigSlotRows magic-coordinator )" "ws-inst:.local-symlink ws-src:source-symlink "
rm -f "$rigSlots/magic-tester" ; mkdir -p "$rigSlots/magic-tester" ; printf 'real\n' > "$rigSlots/magic-tester/rig-real.txt"
rigSlotRun "$rigSrcWs" "$rigSrcWs/source"
rigAssert "real content in a slot is never touched, by the source workspace either" \
	"$( [ -L "$rigSlots/magic-tester" ] && printf link || printf real ) $( cat "$rigSlots/magic-tester/rig-real.txt" 2>/dev/null )" "real real"

echo "-- declared grants: allow-read resolves as allow-write does, and grants Read only --"
## Its own HOME and two workspaces: gws-one holds the declaring project, gws-two is the
## other workspace its workspace selectors reach. The source scan needs myx.common on PATH.
rigMyxCommon="$( command -v myx.common 2>/dev/null )"
[ -n "$rigMyxCommon" ] || rigRefuse "myx.common is not on PATH, so no source project could be scanned for its declared grants"
rigGHome="$rigTmp/grants-home" rigG1="$rigTmp/gws-one" rigG2="$rigTmp/gws-two"
mkdir -p "$rigGHome" "$rigG1/.local" "$rigG1/source/rig/rig-proj" "$rigG2/.local" "$rigG2/source"
printf 'Name: rig\n' > "$rigG1/source/rig/repository.inf"
rigGReg="$rigG1/.local/agents/permissions.registry" rigGTags="$rigG1/.local/agents/permissions-tags.registry" rigGSettings="$rigGHome/.claude/settings.json"
rigGrantDeclares(){ ## extra declare lines... -- the declaring project: every selector once for each verb, keeper-w writing and keeper-r reading
	local declareVerb declareWho declareLine
	{
		printf 'Name: rig-proj\n\nDeclares: \\\n'
		for declareVerb in allow-write allow-read ; do
			declareWho=keeper-w ; [ "$declareVerb" = allow-write ] || declareWho=keeper-r
			for declareLine in "workspace:.:$declareVerb:$declareWho:shared/**" "workspace:gws-two:$declareVerb:$declareWho:docs/**" \
				"workspace:*:$declareVerb:$declareWho:any/**" "project:.:$declareVerb:$declareWho:p/**" \
				"namespace:.:$declareVerb:$declareWho" "namespace:*:$declareVerb:$declareWho" ; do
				printf '\tmagic-team:permissions:%s \\\n' "$declareLine"
			done
		done
		for declareLine in "$@" ; do printf '\t%s \\\n' "$declareLine" ; done
		printf '\n'
	} > "$rigG1/source/rig/rig-proj/project.inf"
}
rigGrantRun(){ ## op and arguments... -- the tool in gws-one under the grants HOME, clean env; output in grants.out, rc in rigGrantRc
	rigGrantRc=0
	env -i HOME="$rigGHome" PATH="${rigMyxCommon%/*}:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigG1" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		RIG_TMP="$rigTmp" bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$HOME" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "'"$rigFn"'" "$@"
		' rig "$@" > "$rigTmp/grants.out" 2>&1 || rigGrantRc=$?
}
rigGrantRows(){ ## file, member -- that member rows, the member cut and Edit or Read made neutral, sorted
	LC_ALL=C awk -F: -v wantMember="$2" '$1 == wantMember { sub( /^[^:]*:/, "" ) ; sub( /:(Read|Edit)\(/, ":GRANT(" ) ; print ; }' "$1" 2>/dev/null | LC_ALL=C sort
}
rigGrantRoots(){ ## producer and arguments -- one access-root producer in gws-one under the grants HOME
	env -i HOME="$rigGHome" PATH=/usr/bin:/bin MMDAPP="$rigG1" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "'"$rigHere"'/AgentsTools.ClientAccessRoots.include" ; "$@"' rig "$@"
}
rigCount(){ ## fixed text, file -- how many times it occurs
	LC_ALL=C grep -o -F -e "$1" "$2" 2>/dev/null | LC_ALL=C grep -c .
}
rigGrantRun --owner-workspace-upsert "$rigG1"
rigGrantRun --owner-workspace-upsert "$rigG2"
rigGrantDeclares "magic-team:permissions:workspace:.:allow-read:keeper-o:ronly/**"
rigGrantRun --install-claude-permissions
rigAssert "control: the install ran on a trusted scan, rc 0" "$rigGrantRc $( LC_ALL=C grep -c 'claude permissions installed' "$rigTmp/grants.out" )" "0 1"
rigAssert "control: allow-write rows for every scope, its selectors resolved" \
	"$( LC_ALL=C awk -F: '$1 == "keeper-w" { print $3 }' "$rigGReg" | LC_ALL=C sort | uniq -c | LC_ALL=C awk '{ printf "%s:%s ", $2, $1 }' )" "namespace:2 project:1 workspace:4 "
rigAssert "allow-read rows are the allow-write rows, scope by scope and root by root, the verb aside" \
	"$( rigGrantRows "$rigGReg" keeper-r )" "$( rigGrantRows "$rigGReg" keeper-w )"
rigAssert "every allow-read row is Read, none Edit or Write" \
	"$( LC_ALL=C awk -F: '$1 == "keeper-r" || $1 == "keeper-o"' "$rigGReg" | LC_ALL=C grep -c ':Read(' ) $( LC_ALL=C awk -F: '$1 == "keeper-r" || $1 == "keeper-o"' "$rigGReg" | LC_ALL=C grep -c -e ':Edit(' -e ':Write(' )" "8 0"
rigAssert "control: the provenance tags span own, explicit and wildcard" \
	"$( LC_ALL=C awk -F: '$1 == "keeper-w" { print $3 }' "$rigGTags" | LC_ALL=C sort -u | LC_ALL=C tr '\n' ' ' )" "explicit own wildcard "
rigAssert "allow-read roots are tagged as the allow-write roots are" \
	"$( rigGrantRows "$rigGTags" keeper-r )" "$( rigGrantRows "$rigGTags" keeper-w )"
rigAssert "a lone allow-read is one Read row, for its own member" \
	"$( LC_ALL=C awk -F: '$1 == "keeper-o"' "$rigGReg" )" "keeper-o:gws-one:workspace:Read(/$rigG1/ronly/**)"
rigAssert "the settings carry it as Read" "$( rigCount "\"Read(/$rigG1/ronly/**)\"" "$rigGSettings" )" 1
rigAssert "and never as Edit or Write" "$( rigCount "Edit(/$rigG1/ronly" "$rigGSettings" ) $( rigCount "Write(/$rigG1/ronly" "$rigGSettings" )" "0 0"
rigAssert "control: the settings carry the allow-write Edit and the allow-read Read side by side" \
	"$( rigCount "\"Edit(/$rigG1/shared/**)\"" "$rigGSettings" ) $( rigCount "\"Read(/$rigG1/shared/**)\"" "$rigGSettings" )" "1 1"
rigAssert "our read-grant roots name it for its member" "$( rigGrantRoots AgentsToolsClientAccessReadGrantRoots keeper-o )" "$rigG1/ronly"
rigAssert "it joins the read roots a client is granted" "$( rigGrantRoots AgentsToolsClientAccessRoots "$rigG1" "" | LC_ALL=C grep -c -x -F "$rigG1/ronly" )" 1
rigAssert "it is no write root of its member" "$( rigGrantRoots AgentsToolsClientAccessGrantRoots keeper-o )" ""
rigAssert "nor of the union a writer with no member gets" "$( rigGrantRoots AgentsToolsClientAccessGrantRoots | LC_ALL=C grep -c -F "/ronly" )" 0
rigAssert "control: the allow-write root is a write root" "$( rigGrantRoots AgentsToolsClientAccessGrantRoots keeper-w | LC_ALL=C grep -c -x -F "$rigG1/shared" )" 1
rigAssert "its root carries the provenance tag an allow-write root here would" "$( rigGrantRoots AgentsToolsClientAccessRootTag "$rigG1/ronly" )" own
## A malformed verb, beside the good ones: refused, the scan untrusted, nothing rewritten.
cp "$rigGReg" "$rigTmp/grants.reg.before"
rigGrantRefusal(){ ## malformed verb -- rc, its refusal count, the untrusted warning count, the registry kept or not | the refusal, its verb made neutral
	printf '%s %s %s %s|%s' "$rigGrantRc" \
		"$( LC_ALL=C grep -c "unsupported permissions verb in .*: $1 (" "$rigTmp/grants.out" )" \
		"$( LC_ALL=C grep -c 'declared allow-write was not determined' "$rigTmp/grants.out" )" \
		"$( cmp -s "$rigGReg" "$rigTmp/grants.reg.before" && printf kept || printf rewritten )" \
		"$( LC_ALL=C grep 'unsupported permissions verb' "$rigTmp/grants.out" | LC_ALL=C sed "s/$1/VERB/g" )"
}
rigGrantDeclares "magic-team:permissions:workspace:.:allow-read:keeper-o:ronly/**" "magic-team:permissions:workspace:.:allow-reads:keeper-x:bad/**"
rigGrantRun --install-claude-permissions
rigGrantBadRead="$( rigGrantRefusal allow-reads )"
rigGrantDeclares "magic-team:permissions:workspace:.:allow-read:keeper-o:ronly/**" "magic-team:permissions:workspace:.:allow-writes:keeper-x:bad/**"
rigGrantRun --install-claude-permissions
rigGrantBadWrite="$( rigGrantRefusal allow-writes )"
rigAssert "a malformed allow-read is refused: rc 0, one refusal, the scan untrusted, the registry kept" "${rigGrantBadRead%%|*}" "0 1 1 kept"
rigAssert "control: so is a malformed allow-write" "${rigGrantBadWrite%%|*}" "0 1 1 kept"
rigAssert "and both refusals say the same, the verb aside" "${rigGrantBadRead#*|}" "${rigGrantBadWrite#*|}"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ TEAM REGISTRY CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'TEAM_REGISTRY: OK (%d assertions, offline, rig HOME only)\n' "$rigPass"
