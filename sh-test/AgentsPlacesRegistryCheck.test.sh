#!/usr/bin/env bash
## Places, member homes and workspace registration, run rather than read, against a rig HOME
## and rig workspaces under one mktemp tree:
##   1. place directives: both kinds, both ceilings, host globs, the three path forms; a
##      malformed line and a second path for one name are skipped with a warning, an absent
##      path is kept with one;
##   2. both registries: the local rows, the own row first, and the machine pointers; each
##      workspace rewrites only its own rows, under a lock a held lock refuses;
##   3. duplicates: the same name and path is one place; the local row wins; otherwise one
##      warning and name@workspace;
##   4. registration: --make-workspace-integrations runs it and the member install does not;
##      the earlier known-workspaces list is read until imported once and never written; the
##      member resolver, the `*` grant expansion and the coordinator's list read the new files;
##   5. the owner ops: upsert with --name, --kind, --ceiling and its refusals, forget by name,
##      the merged list marking absent paths; --owner-workspace-current is gone;
##   6. the tooling resolvers --intern-directory-resolve and --intern-directory-of;
##   7. member homes: agents installed first, then the most complete declaration, then a source
##      link; one warning naming the copies and the home; every row kept; the resolver and the
##      member directory follow the home;
##   8. a registered workspace without agents: its declared members registered under its own
##      root, nothing installed there, the resolver never switching to it;
##   9. help: the new syntax lines, and no --owner-workspace-current.
## Offline: HOME, every workspace and every registry are under this rig's own mktemp tree.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigFn="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigFn" "$rigHere/AgentsTools.Places.include" "$rigHere/AgentsTools.MemberHomes.include" "$rigHere/AgentsTools.MemberWorkspace.include" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
rigMyxCommon="$( command -v myx.common 2>/dev/null )"
[ -n "$rigMyxCommon" ] || rigRefuse "myx.common is not on PATH, so no source project could be scanned for its declares"
rigTmp="$( mktemp -d -t AgentsPlacesRegistryCheck )" || exit 1
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
rigHome="$rigTmp/home"
rigHost="$( hostname -s 2>/dev/null )"
[ -n "$rigHost" ] || rigRefuse "hostname -s printed nothing, so no host glob could be matched"
mkdir -p "$rigHome"

rigWsMake(){ ## workspace name, declare lines... -- a rig workspace with one source project declaring them
	local makeWs="$rigTmp/$1" makeLine ; shift
	mkdir -p "$makeWs/.local" "$makeWs/source/rig/rig-proj"
	printf 'Name: rig\n' > "$makeWs/source/rig/repository.inf"
	{
		printf 'Name: rig-proj\n\nDeclares: \\\n'
		for makeLine in "$@" ; do printf '\t%s \\\n' "$makeLine" ; done
		printf '\n'
	} > "$makeWs/source/rig/rig-proj/project.inf"
}
rigRunHome="$rigHome"
rigRun(){ ## workspace name, op and arguments... -- the tool there under rigRunHome, clean env; stdout in out, stderr in err, rc in rigRc
	local runWs="$rigTmp/$1" ; shift
	rigRc=0
	env -i HOME="$rigRunHome" PATH="${rigMyxCommon%/*}:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$runWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		RIG_TMP="$rigTmp" bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$HOME" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "'"$rigFn"'" "$@"
		' rig "$@" > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigCut(){ ## -- stdin with the rig tree written T
	LC_ALL=C sed "s|$rigTmp|T|g"
}
rigLocal(){ ## workspace name -- its local rows, name:kind:ceiling:path:declared-by, sorted, one line
	LC_ALL=C awk -F'\t' '{ print $1 ":" $2 ":" $3 ":" $4 ":" $5 }' "$rigTmp/$1/.local/agents/directories.registry" 2>/dev/null | rigCut | LC_ALL=C sort | LC_ALL=C tr '\n' ' '
}
rigShared(){ ## -- the machine pointers of rigRunHome, name:workspace basename, sorted, one line
	LC_ALL=C awk -F'\t' '{ w = $2 ; sub( /.*\//, "", w ) ; print $1 ":" w }' "$rigRunHome/.agents/magic-team/directories.registry" 2>/dev/null | LC_ALL=C sort | LC_ALL=C tr '\n' ' '
}
rigN(){ ## file, fixed text -- how many lines hold it
	LC_ALL=C grep -c -F -- "$2" "$1" 2>/dev/null || :
}
rigList(){ ## workspace name -- --owner-workspace-list from there, rows cut to one line
	rigRun "$1" --owner-workspace-list
	LC_ALL=C tr '\t' ':' < "$rigTmp/out" | rigCut | LC_ALL=C tr '\n' ' '
}

## The machine: ws-main the main workspace, ws-two and ws-three two more with agents, ws-side
## a workspace without agents that declares members.
mkdir -p "$rigTmp/dir-one/two" "$rigTmp/dir-a" "$rigTmp/dir-b" "$rigHome/hdir" "$rigTmp/ws-main/rel/sub"
rigWsMake ws-main \
	"magic-team:directory:dir-one:ceiling-read:$rigTmp/dir-one:*" \
	"magic-team:directory:rel-dir:ceiling-write:rel/sub:$rigHost" \
	"magic-team:directory:home-dir:ceiling-write:~/hdir:*" \
	"magic-team:directory:other-host:ceiling-write:/nowhere:no-such-rig-host-*" \
	"magic-team:workspace:ws-side:$rigTmp/ws-side:*" \
	"magic-team:directory:bad-ceiling:ceiling-wide:/x:*" \
	"magic-team:directory:dir-one:ceiling-read:/elsewhere:*" \
	"magic-team:directory:gone:ceiling-write:/no/such/rig/path:*"
mkdir -p "$rigTmp/ws-main/rel/sub"
rigWsMake ws-two \
	"magic-team:directory:dir-one:ceiling-read:$rigTmp/dir-one:*" \
	"magic-team:directory:two-only:ceiling-write:$rigTmp/dir-one/two:*" \
	"magic-team:directory:temp-only:ceiling-write:$rigTmp/dir-b:*" \
	"magic-team:directory:shared-name:ceiling-write:$rigTmp/dir-a:*" \
	"magic-team:team-member:skillset/keeper-home:*"
rigWsMake ws-three \
	"magic-team:directory:shared-name:ceiling-write:$rigTmp/dir-b:*" \
	"magic-team:team-member:skillset/keeper-home:*" \
	"magic-team:permissions:workspace:.:allow-write:keeper-home:docs/**" \
	"magic-team:permissions:workspace:.:allow-read:keeper-home:src/**"
rigWsMake ws-side \
	"magic-team:team-member:skillset/keeper-side:*" \
	"magic-team:team-member:skillset/keeper-inst:*" \
	"magic-team:permissions:workspace:.:allow-write:keeper-inst:a/**" \
	"magic-team:permissions:workspace:.:allow-read:keeper-inst:b/**"
mkdir -p "$rigTmp/ws-side/source/rig/rig-proj/skillset/keeper-side" "$rigTmp/ws-side/source/rig/rig-proj/skillset/keeper-inst"

echo "-- 1. place directives --"
rigRun ws-main --intern-directory-register
rigAssert "control: the registration ran, rc 0" "$rigRc $( rigN "$rigTmp/err" 'places registered' )" "0 1"
rigAssert "every kind, ceiling, host glob and path form, resolved for this host; another host's line skipped" "$( rigLocal ws-main )" \
	"dir-one:directory:read-only:T/dir-one:rig/rig-proj gone:directory:read-write:/no/such/rig/path:rig/rig-proj home-dir:directory:read-write:T/home/hdir:rig/rig-proj rel-dir:directory:read-write:T/ws-main/rel/sub:rig/rig-proj ws-main:workspace:read-write:T/ws-main:workspace ws-side:workspace:read-write:T/ws-side:rig/rig-proj "
rigAssert "a malformed line is skipped with one warning naming it" "$( rigN "$rigTmp/err" 'malformed place directive, skipped: magic-team:directory:bad-ceiling:ceiling-wide' )" 1
rigAssert "a second path for one name on this host is skipped with one warning" "$( rigN "$rigTmp/err" 'place dir-one is declared again for this host with another path' )" 1
rigAssert "an absent path is kept, with one warning" "$( rigN "$rigTmp/err" 'place gone (directory, declared by rig/rig-proj) is absent on this host, kept' ) $( rigN "$rigTmp/err" 'is absent on this host' )" "1 1"

echo "-- 2. both registries --"
rigAssert "the local registry starts with the workspace's own row" "$( head -n 1 "$rigTmp/ws-main/.local/agents/directories.registry" | rigCut )" "$( printf 'ws-main\tworkspace\tread-write\tT/ws-main\tworkspace' )"
rigAssert "the machine registry holds pointers only: each name and the declaring workspace" "$( rigShared )" "dir-one:ws-main gone:ws-main home-dir:ws-main rel-dir:ws-main ws-main:ws-main ws-side:ws-main "
rigAssert "and two columns on every line" "$( LC_ALL=C awk -F'\t' 'NF != 2' "$rigHome/.agents/magic-team/directories.registry" | LC_ALL=C grep -c . )" 0
rigRun ws-two --intern-directory-register
rigRun ws-three --intern-directory-register
rigAssert "another workspace's registration adds its own pointers and keeps ws-main's" \
	"$( rigShared | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c ':ws-main$' ) $( rigShared | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c ':ws-two$' ) $( rigShared | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c ':ws-three$' )" "6 5 2"
rigWsMake ws-two \
	"magic-team:directory:dir-one:ceiling-read:$rigTmp/dir-one:*" \
	"magic-team:directory:two-only:ceiling-write:$rigTmp/dir-one/two:*" \
	"magic-team:directory:shared-name:ceiling-write:$rigTmp/dir-a:*" \
	"magic-team:team-member:skillset/keeper-home:*"
rigRun ws-two --intern-directory-register
rigAssert "a rewrite drops a directive gone from its project, in both registries, and touches no other workspace's row" \
	"$( rigLocal ws-two | LC_ALL=C grep -c temp-only ) $( rigShared | LC_ALL=C grep -c temp-only ) $( rigShared | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c ':ws-main$' ) $( rigShared | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c ':ws-three$' )" "0 0 6 2"
rigAssert "no lock is left behind" "$( find "$rigTmp" "$rigHome" -name '*.lock' -type d 2>/dev/null | LC_ALL=C grep -c . )" 0
mkdir -p "$rigHome/.agents/magic-team/directories.registry.lock"
cp "$rigHome/.agents/magic-team/directories.registry" "$rigTmp/shared.before"
rigRun ws-three --intern-directory-register
rmdir "$rigHome/.agents/magic-team/directories.registry.lock"
rigAssert "a held lock on the machine registry: refused, rc 1, named, the file untouched" \
	"$rigRc $( rigN "$rigTmp/err" 'is busy, lock not acquired after 10 attempts' ) $( cmp -s "$rigTmp/shared.before" "$rigHome/.agents/magic-team/directories.registry" && printf untouched || printf changed )" "1 1 untouched"
rigRun ws-three --intern-directory-register
rigAssert "accepted sibling: with the lock released the same run passes" "$rigRc" 0

echo "-- 3. duplicates --"
rigMainList="$( rigList ws-main )"
rigAssert "the same name and path in two workspaces is one place" "$( printf '%s' "$rigMainList" | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c '^dir-one[:@]' )" 1
rigAssert "the same name with other paths and no local row: each written name@workspace" \
	"$( printf '%s' "$rigMainList" | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep '^shared-name' | LC_ALL=C cut -d: -f1,4 | LC_ALL=C tr '\n' ' ' )" "shared-name@ws-two:T/dir-a shared-name@ws-three:T/dir-b "
rigAssert "with one warning" "$( rigN "$rigTmp/err" 'place shared-name names 2 different paths in other workspaces, written shared-name@ws-two, shared-name@ws-three' ) $( rigN "$rigTmp/err" 'WARNING' )" "1 1"
rigTwoList="$( rigList ws-two )"
rigAssert "a local row wins the bare name, the other is name@workspace, and no warning" \
	"$( printf '%s' "$rigTwoList" | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep '^shared-name' | LC_ALL=C cut -d: -f1,4 | LC_ALL=C tr '\n' ' ' ) $( rigN "$rigTmp/err" 'WARNING' )" "shared-name:T/dir-a shared-name@ws-three:T/dir-b  0"

echo "-- 4. registration, the earlier list, and the readers --"
rigWsArm="$( LC_ALL=C awk '/^\t--make-workspace-integrations\)/ { on = 1 } on { print } on && /^\t;;/ { exit }' "$rigHere/AgentsTools.Make.include" )"
rigAssert "every update registers the workspace: --make-workspace-integrations runs the registration, then the member homes after the install" \
	"$( printf '%s\n' "$rigWsArm" | LC_ALL=C awk '/DistroAgentsTools --intern-directory-register / { a = NR } /DistroAgentsTools --install-workspace-integrations / { b = NR } /DistroAgentsTools --intern-member-home-register / { c = NR } END { print ( a > 0 && a < b && b < c ) ? "ordered" : "not ordered" }' )" ordered
rigAssert "the member install registers no workspace" "$( LC_ALL=C grep -c -e '--owner-workspace-upsert' -e 'directories.registry' "$rigHere/AgentsTools.Install.include" )" 0
rigAssert "the * grant expansion walks the known workspace roots, this workspace first" "$( LC_ALL=C grep -c 'agentsGrantsRoots="$( AgentsToolsPlacesWorkspaceRoots "$regWs" )"' "$rigHere/AgentsTools.Grants.include" )" 1
rigRoots(){ ## workspace name -- AgentsToolsPlacesWorkspaceRoots from there under rigRunHome
	env -i HOME="$rigRunHome" PATH=/usr/bin:/bin MMDAPP="$rigTmp/$1" bash -c '. "$1/AgentsTools.Places.include" ; AgentsToolsPlacesWorkspaceRoots "$MMDAPP"' rig "$rigHere" | rigCut | LC_ALL=C tr '\n' ' '
}
rigAssert "the known workspace roots: this one first, then the workspace rows, then the pointer roots" "$( rigRoots ws-main )" "T/ws-main T/ws-side T/ws-two T/ws-three "
## The earlier list, under a HOME of its own: a trailing slash, a comment, a relative line,
## the importing workspace itself, and a workspace no place names.
rigRunHome="$rigTmp/legacy-home" ; mkdir -p "$rigRunHome/.agents/magic-team"
rigLegacy="$rigRunHome/.agents/magic-team/known-workspaces.registry"
rigWsMake ws-imp
printf '%s\n' "$rigTmp/ws-legacy/" "# a comment" "relative-line" "$rigTmp/ws-imp" > "$rigLegacy"
rigLegacySum="$( cksum < "$rigLegacy" )"
rigAssert "before the import the earlier list is read: its absolute lines, as workspaces" "$( rigRoots ws-imp )" "T/ws-imp T/ws-legacy "
rigAssert "and the list shows them, the missing one absent" "$( rigList ws-imp )" "ws-legacy:workspace:read-write:T/ws-legacy:absent ws-imp:workspace:read-write:T/ws-imp:present "
rigRun ws-imp --intern-directory-register
rigAssert "the registration imports it once: the path no place has becomes an owner row" "$( rigLocal ws-imp )" "ws-imp:workspace:read-write:T/ws-imp:workspace ws-legacy:workspace:read-write:T/ws-legacy:owner "
rigAssert "the earlier list is never written, and its marker is" "$( [ "$( cksum < "$rigLegacy" )" = "$rigLegacySum" ] && printf unchanged || printf changed ) $( [ -f "$rigLegacy.imported" ] && printf marked || printf unmarked )" "unchanged marked"
rigRun ws-imp --owner-workspace-forget ws-legacy
rigRun ws-imp --intern-directory-register
rigAssert "after the import it is not read: a forgotten row stays forgotten" "$( rigLocal ws-imp ) $( rigRoots ws-imp )" "ws-imp:workspace:read-write:T/ws-imp:workspace  T/ws-imp "
rigRunHome="$rigHome"
## The member resolver: a member of ws-three, reached from ws-main through the pointers.
rigReg="$rigHome/.agents/magic-team/members.registry"
rigRow(){ ## member, workspace name, kind, directory -- one machine member row
	printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$rigTmp/$2" "$3" "rig/$1" "$4" >> "$rigReg"
}
rigResolve(){ ## workspace name, member -- the resolver from there: what it printed, then its rc
	local resolveOut resolveRc=0
	resolveOut="$( env -i HOME="$rigHome" PATH=/usr/bin:/bin MMDAPP="$rigTmp/$1" MDSC_CMD=RigCmd bash -c '. "$1/AgentsTools.MemberWorkspace.include" ; AgentsToolsMemberWorkspaceResolve "$2" --rig-op' rig "$rigHere" "$2" 2>&1 )" || resolveRc=$?
	printf '%s rc=%s' "$( printf '%s' "$resolveOut" | rigCut )" "$resolveRc"
}
mkdir -p "${rigReg%/*}" "$rigTmp/copies/main-rig" "$rigTmp/copies/far-rig"
rigRow main-rig ws-main source-symlink "$rigTmp/copies/main-rig"
rigRow far-rig ws-three source-symlink "$rigTmp/copies/far-rig"
rigRow lost-rig ws-nowhere source-symlink "$rigTmp/copies/far-rig"
rigAssert "the resolver gate reads the new registries: a member of a registered workspace is reached" "$( rigResolve ws-main far-rig )" "T/ws-three rc=0"
rigAssert "and a member of no known workspace is refused, named" "$( rigResolve ws-main lost-rig )" "⛔ ERROR: RigCmd --rig-op: member 'lost-rig' is in the team members index but is present in no tracked workspace -- nothing was done rc=1"
rigAssert "the coordinator's list: name, kind, ceiling, path, presence" \
	"$( printf '%s' "$rigMainList" | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -e '^ws-main:' -e '^gone:' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "gone:directory:read-write:/no/such/rig/path:absent ws-main:workspace:read-write:T/ws-main:present "

echo "-- 5. the owner ops --"
rigRun ws-main --owner-workspace-upsert "$rigTmp/plain-dir/" --kind directory --ceiling read-only
rigAssert "upsert a directory: an owner row, the trailing slash dropped, the basename its name" "$rigRc $( rigLocal ws-main | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep '^plain-dir:' )" "0 plain-dir:directory:read-only:T/plain-dir:owner"
rigAssert "and its pointer" "$( rigShared | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c '^plain-dir:ws-main$' )" 1
cp "$rigTmp/ws-main/.local/agents/directories.registry" "$rigTmp/local.before"
rigRun ws-main --owner-workspace-upsert "$rigTmp/plain-dir" --kind directory --ceiling ceiling-read
rigAssert "the same row again changes nothing" "$rigRc $( rigN "$rigTmp/err" 'already tracked: plain-dir' ) $( cmp -s "$rigTmp/local.before" "$rigTmp/ws-main/.local/agents/directories.registry" && printf same || printf changed )" "0 1 same"
rigRun ws-main --owner-workspace-upsert "$rigTmp/ws-far" --name far-ws
rigAssert "--name names it; a workspace by default, read-write" "$rigRc $( rigLocal ws-main | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep '^far-ws:' )" "0 far-ws:workspace:read-write:T/ws-far:owner"
rigUpsertRefusal(){ ## arguments... -- rc and the first error line, after the op
	rigRun ws-main --owner-workspace-upsert "$@"
	printf '%s %s' "$rigRc" "$( LC_ALL=C grep -m1 '⛔' "$rigTmp/err" | LC_ALL=C sed 's/^.*--owner-workspace-upsert: //' | rigCut )"
}
cp "$rigTmp/ws-main/.local/agents/directories.registry" "$rigTmp/local.before"
rigAssert "a relative path is refused" "$( rigUpsertRefusal rel/path )" "1 path must be absolute: rel/path"
rigAssert "a read-only workspace is refused" "$( rigUpsertRefusal "$rigTmp/x" --ceiling read-only )" "1 a workspace is always read-write"
rigAssert "an unknown kind is refused" "$( rigUpsertRefusal "$rigTmp/x" --kind folder )" "1 --kind must be workspace or directory"
rigAssert "a name with an @ is refused" "$( rigUpsertRefusal "$rigTmp/x" --name 'a@b' )" "1 a place name is letters, digits and . _ + - only: a@b"
rigAssert "a name a project declares for another path is refused" "$( rigUpsertRefusal "$rigTmp/x" --name dir-one )" "1 the name dir-one is declared by rig/rig-proj for T/dir-one -- give this path another --name"
rigAssert "a second path is refused" "$( rigUpsertRefusal "$rigTmp/x" "$rigTmp/y" )" "1 takes exactly one <path>, and more followed it: T/y"
rigAssert "and no refusal wrote anything" "$( cmp -s "$rigTmp/local.before" "$rigTmp/ws-main/.local/agents/directories.registry" && printf same || printf changed )" same
rigRun ws-main --owner-workspace-upsert "$rigTmp/ws-main"
rigAssert "this workspace's own path is already registered" "$rigRc $( rigN "$rigTmp/err" 'already registered as ws-main, declared by workspace' )" "0 1"
rigRun ws-main --owner-workspace-forget far-ws
rigAssert "forget removes the owner row and its pointer" "$rigRc $( rigLocal ws-main | LC_ALL=C grep -c far-ws ) $( rigShared | LC_ALL=C grep -c far-ws )" "0 0 0"
rigRun ws-main --owner-workspace-forget dir-one
rigAssert "forget refuses a name a project declares" "$rigRc $( rigN "$rigTmp/err" 'dir-one is declared by rig/rig-proj -- remove its directive there' )" "1 1"
rigRun ws-main --owner-workspace-forget ws-main
rigAssert "forget refuses the workspace's own row" "$rigRc $( rigN "$rigTmp/err" "ws-main is this workspace's own row" )" "1 1"
rigRun ws-main --owner-workspace-forget two-only
rigAssert "a name another workspace registers is a no-op naming it" "$rigRc $( rigN "$rigTmp/err" "two-only is registered by $rigTmp/ws-two -- forget it there" )" "0 1"
rigRun ws-main --owner-workspace-forget no-such-place
rigAssert "an unknown name is a no-op" "$rigRc $( rigN "$rigTmp/err" 'not registered, nothing to do: no-such-place' )" "0 1"
rigAssert "the merged list marks the absent and the present" \
	"$( rigList ws-main | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -e '^plain-dir:' -e '^dir-one:' | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "dir-one:directory:read-only:T/dir-one:present plain-dir:directory:read-only:T/plain-dir:absent "
rigRun ws-main --owner-workspace-current
rigAssert "--owner-workspace-current is gone" "$rigRc $( rigN "$rigTmp/err" 'invalid option: --owner-workspace-current' )" "1 1"
rigAssert "and no caller is left in the package" "$( LC_ALL=C grep -r -l -e '--owner-workspace-current' "$rigHere" "$rigPackage/sh-scripts" "$rigPackage/docs" "$rigPackage/MAGIC.md" 2>/dev/null | LC_ALL=C grep -c . )" 0

echo "-- 6. the tooling resolvers --"
rigTool(){ ## workspace name, op and arguments -- stdout, the first warning, rc
	rigRun "$@"
	printf '%s|%s|%s' "$( rigCut < "$rigTmp/out" )" "$( LC_ALL=C grep -m1 'WARNING' "$rigTmp/err" | rigCut )" "$rigRc"
}
rigAssert "resolve a name" "$( rigTool ws-main --intern-directory-resolve dir-one )" "T/dir-one||0"
rigAssert "resolve name@workspace" "$( rigTool ws-main --intern-directory-resolve shared-name@ws-three )" "T/dir-b||0"
rigAssert "a name naming places in several workspaces is refused, naming each" "$( rigTool ws-main --intern-directory-resolve shared-name )" "|🙋 WARNING: place shared-name names places in several workspaces, name one of: shared-name@ws-two, shared-name@ws-three|1"
rigAssert "from the workspace holding it, the local row answers" "$( rigTool ws-two --intern-directory-resolve shared-name )" "T/dir-a||0"
rigAssert "an absent place is printed, with a warning" "$( rigTool ws-main --intern-directory-resolve gone )" "/no/such/rig/path|🙋 WARNING: place gone is absent on this host: /no/such/rig/path|0"
rigAssert "an unknown name is refused" "$( rigTool ws-main --intern-directory-resolve no-such-place )" "|🙋 WARNING: unknown place: no-such-place|1"
rigAssert "a path inside a place is name:relative, the deepest place" "$( rigTool ws-main --intern-directory-of "$rigTmp/dir-one/two/f.md" ) $( rigTool ws-main --intern-directory-of "$rigTmp/dir-one/a/b" )" "two-only:f.md||0 dir-one:a/b||0"
rigAssert "the place itself is name:." "$( rigTool ws-main --intern-directory-of "$rigTmp/dir-one/" )" "dir-one:.||0"
rigAssert "a path in no place: nothing, rc 1" "$( rigTool ws-main --intern-directory-of /usr/rig-nowhere )" "||1"
rigAssert "each takes exactly one argument" "$( rigTool ws-main --intern-directory-resolve | LC_ALL=C sed 's/|.*|/|/' ) $( rigTool ws-main --intern-directory-of a b | LC_ALL=C sed 's/|.*|/|/' )" "|1 |1"

echo "-- 7. member homes --"
## ws-two and ws-three have agents installed; ws-three declares keeper-home most completely.
mkdir -p "$rigTmp/ws-two/.local/agents" "$rigTmp/ws-three/.local/agents" "$rigTmp/copies/home-two" "$rigTmp/copies/home-three" "$rigTmp/copies/same" "$rigTmp/copies/tie-two" "$rigTmp/copies/tie-three" "$rigTmp/copies/inst-two"
: > "$rigTmp/ws-two/.local/agents/members.registry" ; : > "$rigTmp/ws-three/.local/agents/members.registry"
rigRow keeper-home ws-two source-symlink "$rigTmp/copies/home-two"
rigRow keeper-home ws-three source-symlink "$rigTmp/copies/home-three"
rigRow keeper-tie ws-two origin-symlink "$rigTmp/copies/tie-two"
rigRow keeper-tie ws-three source-symlink "$rigTmp/copies/tie-three"
rigRow keeper-same ws-two source-symlink "$rigTmp/copies/same"
rigRow keeper-same ws-three origin-symlink "$rigTmp/copies/same"
rigRow keeper-inst ws-two .local-symlink "$rigTmp/copies/inst-two"
rigDirectory(){ ## member -- AgentsToolsTeamMemberDirectory from ws-main
	env -i HOME="$rigHome" PATH=/usr/bin:/bin MMDAPP="$rigTmp/ws-main" MDAT_SKILLSET_ROOT="$rigTmp/ws-main/.local/agents/members" bash -c '. "$1/AgentsTools.TeamRegistry.include" ; AgentsToolsTeamMemberDirectory "$2"' rig "$rigHere" "$1" | rigCut
}
rigAssert "control: before any home, the first source link answers" "$( rigResolve ws-main keeper-home ) $( rigDirectory keeper-home )" "T/ws-two rc=0 T/copies/home-two"
rigRowsBefore="$( LC_ALL=C grep -c . "$rigReg" )"
rigRun ws-main --intern-member-home-register
rigHomes="$rigHome/.agents/magic-team/member-homes.registry"
rigHomeOf(){ ## member -- its home's workspace basename
	LC_ALL=C awk -F'\t' -v m="$1" '$1 == m { w = $2 ; sub( /.*\//, "", w ) ; print w ; }' "$rigHomes" 2>/dev/null
}
rigAssert "control: the home registration ran, rc 0" "$rigRc" 0
rigAssert "the most complete declaration wins between two workspaces with agents" "$( rigHomeOf keeper-home )" ws-three
rigAssert "with no declaration, a source link wins" "$( rigHomeOf keeper-tie )" ws-three
rigAssert "agents installed wins over a fuller declaration in a workspace without agents" "$( rigHomeOf keeper-inst )" ws-two
rigAssert "one short warning for a member whose copies differ: the locations and the copy chosen" \
	"$( LC_ALL=C grep 'member keeper-home has copies' "$rigTmp/err" | rigCut )" "🙋 WARNING: member keeper-home has copies in T/ws-two, T/ws-three -- its home is the copy in T/ws-three: T/copies/home-three"
rigAssert "and none for one copy registered twice" "$( rigN "$rigTmp/err" 'member keeper-same has copies' )" 0
rigAssert "the machine registry keeps every row, the declared ones added" "$( LC_ALL=C grep -c . "$rigReg" )" "$(( rigRowsBefore + 2 ))"
rigAssert "the resolver follows the home" "$( rigResolve ws-main keeper-home )" "T/ws-three rc=0"
rigAssert "and so does the member directory" "$( rigDirectory keeper-home )" "T/copies/home-three"

echo "-- 8. a workspace without agents --"
rigAssert "its declared members are registered under its own root, as source-declared" \
	"$( LC_ALL=C awk -F'\t' '$3 == "source-declared" { print $1 ":" $2 ":" $4 ":" $5 }' "$rigReg" | rigCut | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" \
	"keeper-inst:T/ws-side:rig/rig-proj/skillset/keeper-inst:T/ws-side/source/rig/rig-proj/skillset/keeper-inst keeper-side:T/ws-side:rig/rig-proj/skillset/keeper-side:T/ws-side/source/rig/rig-proj/skillset/keeper-side "
rigAssert "said once for that workspace" "$( rigN "$rigTmp/err" "$rigTmp/ws-side has no agents installed: 2 declared member(s) registered" )" 1
rigAssert "nothing is installed there" "$( ls -A "$rigTmp/ws-side" "$rigTmp/ws-side/.local" 2>/dev/null | LC_ALL=C grep -c -x -e agents -e .claude -e .agents -e DistroAgentsConsole.sh )" 0
rigAssert "the resolver does not switch to it: the member runs where it is asked" "$( rigResolve ws-main keeper-side )" " rc=0"
rigAssert "the member directory still finds it" "$( rigDirectory keeper-side )" "T/ws-side/source/rig/rig-proj/skillset/keeper-side"
mkdir -p "$rigTmp/ws-side/.local/agents" ; : > "$rigTmp/ws-side/.local/agents/members.registry"
rigRun ws-main --intern-member-home-register
rigAssert "once it has agents installed its own install registers it, and the declared rows go" "$rigRc $( LC_ALL=C awk -F'\t' '$3 == "source-declared"' "$rigReg" | LC_ALL=C grep -c . )" "0 0"

echo "-- 9. help --"
rigRun ws-main --help-syntax
rigAssert "the syntax lines: upsert with its options, forget by name, list" \
	"$( rigN "$rigTmp/err" 'DistroAgentsTools.fn.sh --owner-workspace-upsert <path> [--name <name>] [--kind workspace|directory] [--ceiling read-only|read-write]' ) $( rigN "$rigTmp/err" 'DistroAgentsTools.fn.sh --owner-workspace-forget <name>' ) $( rigN "$rigTmp/err" 'DistroAgentsTools.fn.sh --owner-workspace-list' )" "1 1 1"
rigAssert "the manual carries the same three, and no --owner-workspace-current" \
	"$( LC_ALL=C grep -c -E "^$( printf '\t\t' )--owner-workspace-(upsert <path> \\[--name|forget <name>|list\$)" "$rigHere/help/Help.DistroAgentsTools.help.md" ) $( rigN "$rigHere/help/Help.DistroAgentsTools.help.md" 'owner-workspace-current' )" "3 0"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ PLACES REGISTRY CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'PLACES_REGISTRY: OK (%d assertions, offline, rig HOME only)\n' "$rigPass"
