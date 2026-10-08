#!/usr/bin/env bash
## The team's data lives in two places only (AgentsTools.TeamRegistry.include): a workspace's
## own .local/agents, and the machine-wide directory $HOME/.agents/magic-team. Checked, run
## rather than read, against a rig HOME and rig workspaces:
##   1. --install-skillset-symlinks writes the member registry there -- the workspace scope
##      into .local/agents/members.registry, the user-home scope into the machine-wide one,
##      each row the member, the workspace root, the link kind, the relative path and the
##      member directory -- and no registry file into any vendor link folder;
##   2. it writes the member index: this workspace's own members first, then the members
##      other workspaces publish (a source link preferred), each name once, and the
##      members/ view the tools read; MDAT_SKILLSET_ROOT defaults to that view;
##   3. nothing of ours reads a vendor link folder back: a member link re-pointed in
##      $HOME/.claude/skills changes no answer, and the old .linked.* files are not read;
##   4. the member-workspace resolver, the access-root producer, the grant union through
##      the shared pointers, the provenance tags and the tracked-workspace list all read
##      the new files.
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

echo "-- the member index: own first, then the others, each name once --"
rigIndex="$rigWs/.local/agents/members.index"
rigAssert "own members first, in the index" \
	"$( LC_ALL=C awk -F'\t' '$3 == r' r="$rigWs" "$rigIndex" | cut -f1 | LC_ALL=C sort -u )" "$rigBundled"
rigAssert "the bundled magic-coordinator wins over the other workspace's copy" \
	"$( LC_ALL=C awk -F'\t' '$1 == "magic-coordinator" { print $2 }' "$rigIndex" )" "$rigBundle/magic-coordinator"
rigAssert "a member only another workspace publishes is listed, its source link preferred" \
	"$( LC_ALL=C awk -F'\t' '$1 == "keeper-rig" { print $2, $4 }' "$rigIndex" )" "$rigOther/source/ns/skillset/keeper-rig source-symlink"
rigAssert "each name once" "$( cut -f1 "$rigIndex" | LC_ALL=C sort | uniq -d | LC_ALL=C grep -c . )" 0
rigAssert "own rows come before the others" "$( tail -1 "$rigIndex" | cut -f1 )" keeper-rig
rigAssert "the members/ view links each to its directory" \
	"$( readlink "$rigWs/.local/agents/members/keeper-rig" ):$( readlink "$rigWs/.local/agents/members/magic-coordinator" )" \
	"$rigOther/source/ns/skillset/keeper-rig:$rigBundle/magic-coordinator"
rigAssert "MDAT_SKILLSET_ROOT defaults to that view (a member op names it)" \
	"$( rigRun --member-audit-item-read no-such-rig-member rig-item 2>&1 | LC_ALL=C grep -c "$rigWs/.local/agents/members/no-such-rig-member" )" 1

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
rigAssert "readable members include the other workspace's member" \
	"$( rigMembers readable | LC_ALL=C grep -c "keeper-rig" )" 1
( . "$rigHere/AgentsTools.TeamRegistry.include" ; HOME="$rigHome" AgentsToolsTeamMemberIndexWrite "$rigWs" )
rigAssert "a rebuilt index still ignores the vendor folders" \
	"$( LC_ALL=C awk -F'\t' '$1 == "magic-coordinator" { print $2 }' "$rigIndex" )" "$rigBundle/magic-coordinator"

echo "-- the resolver, the grants, the tags and the workspace list read the new files --"
rigRun --owner-workspace-upsert "$rigOther" >/dev/null 2>&1
rigAssert "the tracked workspace list is the machine-wide one" "$( cat "$rigHome/.agents/magic-team/known-workspaces.registry" 2>/dev/null )" "$rigOther"
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

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ TEAM REGISTRY CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'TEAM_REGISTRY: OK (%d assertions, offline, rig HOME only)\n' "$rigPass"
