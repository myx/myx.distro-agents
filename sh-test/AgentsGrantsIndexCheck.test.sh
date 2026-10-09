#!/usr/bin/env bash
## The grants (AgentsTools.Grants.include), run rather than read, against a rig HOME and rig
## workspaces under one mktemp tree:
##   1. --make-agents-indices writes the permissions registry from the declares: every selector
##      kind unrolled -- namespace in every tooling workspace, workspace `.` (the declaring one,
##      a workspace without agents included), `*`, a name and a name pattern (testbeds only;
##      one matching nothing gives no row and no warning), directory through the places,
##      project -- a write grant on a read-only place capped to read with one warning, an
##      unknown name kept as an unresolved row with one warning, and magic-librarian's read of
##      source/**;
##   2. grants.index: fully unrolled per member, the ceilings deepest first, the floor (temp in
##      every tooling workspace, the source docs where agents are installed), unresolved rows,
##      magic-tester's grants as myx.distro-agents/project.inf declares them;
##   3. the harness gate, read and write, decided by the session permission index: librarian
##      reads source/** and another member does not, the docs floor, namespace and directory
##      grants, a single * that stays in its segment, the ceiling refused first with its route;
##   4. the session permission index: built, reused with no rebuild, rebuilt after a session
##      grant opens or the grants index changes, an Allow once used up and lapsed, a task
##      grant ending with its item;
##   5. CLIENT_ACCESS_ROOTS_EXTRA is gone.
## Offline: HOME, every workspace, every registry and the team data are this rig's own; a fake
## curl is first on PATH.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigHere="$rigPackage/sh-lib"
rigFn="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigHarness="$rigHere/AgentsUniversalHarness.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigFn" "$rigHarness" "$rigHere/AgentsTools.Grants.include" "$rigHere/AgentsGrantsIndexBuild.awk" "$rigHere/AgentsGrantsSessionIndex.awk" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
rigMyxCommon="$( command -v myx.common 2>/dev/null )"
[ -n "$rigMyxCommon" ] || rigRefuse "myx.common is not on PATH, so no source project could be scanned for its declares"
rigTmp="$( mktemp -d -t AgentsGrantsIndexCheck )" || exit 1
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
rigN(){ ## file, fixed text -- how many lines hold it
	LC_ALL=C grep -c -F -- "$2" "$1" 2>/dev/null || :
}
mkdir -p "$rigTmp/bin"
printf '#!/bin/sh\necho "rig fake curl: no request leaves this box" >&2\nexit 7\n' > "$rigTmp/bin/curl"
chmod +x "$rigTmp/bin/curl"

rigHome="$rigTmp/home" rigSkills="$rigTmp/skills" rigData="$rigTmp/data"
mkdir -p "$rigHome" "$rigData/board/running" "$rigData/board/processed" "$rigTmp/ro-dir" "$rigTmp/rw-dir/sub"
for rigName in magic-tester magic-librarian keeper-w keeper-d keeper-two ; do
	mkdir -p "$rigSkills/$rigName"
	printf '# %s\n' "$rigName" > "$rigSkills/$rigName/$rigName.basic.md"
done
printf -- '---\nstatus: task\nowner: magic-tester\n---\n\n# Task\n' > "$rigData/board/running/task-rig.md"

rigWsMake(){ ## workspace name, declare lines... -- a rig workspace with one source project declaring them
	local makeWs="$rigTmp/$1" makeLine ; shift
	mkdir -p "$makeWs/.local" "$makeWs/source/rig/rig-proj/docs/deep"
	printf 'Name: rig\n' > "$makeWs/source/rig/repository.inf"
	{
		printf 'Name: rig-proj\n\nDeclares: \\\n'
		for makeLine in "$@" ; do printf '\t%s \\\n' "$makeLine" ; done
		printf '\n'
	} > "$makeWs/source/rig/rig-proj/project.inf"
	for makeLine in MAGIC.md README.md x.sh docs/deep/a.md ; do printf 'rig-seed %s\n' "$makeLine" > "$makeWs/source/rig/rig-proj/$makeLine" ; done
}
rigRun(){ ## workspace name, op and arguments... -- the tool there, rig HOME, clean env; stdout in out, stderr in err, rc in rigRc
	local runWs="$rigTmp/$1" ; shift
	rigRc=0
	env -i HOME="$rigHome" PATH="$rigTmp/bin:${rigMyxCommon%/*}:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$runWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" MDAT_DATA_ROOT="$rigData" RIG_TMP="$rigTmp" bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$HOME" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "'"$rigFn"'" "$@"
		' rig "$@" > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}

## magic-tester's grants as myx.distro-agents declares them, carried into the rig as they stand.
rigTesterLines=()
while IFS= read -r rigLine ; do
	[ -z "$rigLine" ] || rigTesterLines+=( "$rigLine" )
done <<< "$( LC_ALL=C sed -n 's/^[[:space:]]*\(magic-team:permissions:[^ ]*:magic-tester:[^ ]*\) \\$/\1/p' "$rigPackage/project.inf" 2>/dev/null )"
[ "${#rigTesterLines[@]}" -gt 0 ] || rigRefuse "no magic-tester grant is declared in $rigPackage/project.inf"

## ws-main has agents installed; ws-side is a registered tooling workspace without agents; the
## two testbeds and ws-testbed-old are registered workspaces with no source, for the patterns.
rigMain="$rigTmp/ws-main" rigSide="$rigTmp/ws-side"
rigTestbedA="$rigTmp/ws-a-testbed" rigTestbedB="$rigTmp/ws-b-testbed" rigDecoy="$rigTmp/ws-testbed-old"
mkdir -p "$rigTestbedA/.local" "$rigTestbedB/.local" "$rigDecoy/.local"
rigWsMake ws-main \
	"${rigTesterLines[@]}" \
	"magic-team:permissions:workspace:*-testbed:allow-write:keeper-two:tb/**" \
	"magic-team:permissions:workspace:nomatch-*:allow-read:keeper-two:nm/**" \
	"magic-team:directory:ro-dir:ceiling-read:$rigTmp/ro-dir:*" \
	"magic-team:directory:rw-dir:ceiling-write:$rigTmp/rw-dir:*" \
	"magic-team:permissions:namespace:.:allow-read:keeper-w" \
	"magic-team:permissions:workspace:.:allow-write:keeper-w:shared/**" \
	"magic-team:permissions:workspace:*:allow-read:*:any/**" \
	"magic-team:permissions:workspace:ws-side:allow-read:keeper-w:docs2/**" \
	"magic-team:permissions:directory:rw-dir:allow-write:keeper-d:*.md" \
	"magic-team:permissions:directory:ro-dir:allow-write:keeper-d" \
	"magic-team:permissions:directory:no-such-place:allow-read:keeper-d" \
	"magic-team:permissions:workspace:no-such-ws:allow-read:keeper-d:x/**" \
	"magic-team:permissions:project:.:allow-write:keeper-w:p/**"
rigWsMake ws-side "magic-team:permissions:workspace:.:allow-write:keeper-two:mine/**"
mkdir -p "$rigMain/.local/agents" "$rigMain/.local/temp" "$rigMain/shared"
: > "$rigMain/.local/agents/members.registry"
rigRun ws-main --owner-workspace-upsert "$rigSide"
for rigOne in "$rigTestbedA" "$rigTestbedB" "$rigDecoy" ; do
	rigRun ws-main --owner-workspace-upsert "$rigOne"
	[ "$rigRc" = 0 ] || rigRefuse "the workspace $rigOne could not be registered: $( head -3 "$rigTmp/err" )"
done
rigRun ws-main --intern-directory-register
[ "$rigRc" = 0 ] || rigRefuse "the places of ws-main could not be registered: $( head -3 "$rigTmp/err" )"
rigRun ws-main --make-agents-indices
[ "$rigRc" = 0 ] || rigRefuse "--make-agents-indices failed in the rig: $( LC_ALL=C grep -m3 -e ERROR -e WARNING "$rigTmp/err" )"
cp "$rigTmp/err" "$rigTmp/build.err"
rigReg="$rigMain/.local/agents/permissions.registry" rigIndex="$rigMain/.local/agents/grants.index"

echo "-- 1. the permissions registry: every selector kind unrolled --"
rigRow(){ ## fixed text -- how many registry rows hold it
	rigN "$rigReg" "$1"
}
rigAssert "namespace .: the declaring project's namespace, in this workspace" "$( rigRow "keeper-w:ws-main:namespace:Read(/$rigMain/source/rig/**)" )" 1
rigAssert "and in every other tooling workspace"                "$( rigRow "keeper-w:ws-main:namespace:Read(/$rigSide/source/rig/**)" )" 1
rigAssert "workspace .: the declaring workspace"                "$( rigRow "keeper-w:ws-main:workspace:Edit(/$rigMain/shared/**)" )" 1
rigAssert "workspace *: every tooling workspace"                "$( rigRow "*:ws-main:workspace:Read(/$rigMain/any/**)" ):$( rigRow "*:ws-main:workspace:Read(/$rigSide/any/**)" )" "1:1"
rigAssert "workspace <name>: the place of that name"            "$( rigRow "keeper-w:ws-main:workspace:Read(/$rigSide/docs2/**)" )" 1
rigAssert "directory <name>: through the places"                "$( rigRow "keeper-d:ws-main:directory:Edit(/$rigTmp/rw-dir/*.md)" )" 1
rigAssert "a write grant on a read-only place is capped to read" "$( rigRow "keeper-d:ws-main:directory:Read(/$rigTmp/ro-dir/**)" ):$( rigRow "keeper-d:ws-main:directory:Edit(/$rigTmp/ro-dir" )" "1:0"
rigAssert "with one warning"                                    "$( rigN "$rigTmp/build.err" 'is capped to read: ro-dir is a read-only place' )" 1
rigAssert "an unknown place is an unresolved row"               "$( rigRow "keeper-d:ws-main:unresolved:directory:" ):$( rigRow "keeper-d:ws-main:unresolved:workspace:" )" "1:1"
rigAssert "each with one warning"                               "$( rigN "$rigTmp/build.err" 'kept as an unresolved row that grants nothing' )" 2
rigAssert "project: through the project resolver"               "$( rigRow "keeper-w:ws-main:project:Edit(/$rigMain/source/rig/rig-proj/p/**)" )" 1
rigAssert "a workspace without agents: its own declares, . its own root" "$( rigRow "keeper-two:ws-side:workspace:Edit(/$rigSide/mine/**)" )" 1
rigAssert "magic-librarian's standing read of source/**"        "$( rigRow "magic-librarian:ws-main:builtin:Read(/$rigMain/source/**)" )" 1
rigAssert "and nobody else's"                                   "$( LC_ALL=C grep -F ":Read(/$rigMain/source/**)" "$rigReg" | LC_ALL=C grep -c -v '^magic-librarian:' )" 0
rigTags="$rigMain/.local/agents/permissions-tags.registry"
rigAssert "workspace <pattern>: every workspace place it matches" "$( rigRow "keeper-two:ws-main:workspace:Edit(/$rigTestbedA/tb/**)" ):$( rigRow "keeper-two:ws-main:workspace:Edit(/$rigTestbedB/tb/**)" )" "1:1"
rigAssert "and no other workspace"                              "$( rigRow "keeper-two:ws-main:workspace:" ):$( rigRow "$rigDecoy/tb/" )" "2:0"
rigAssert "tagged wildcard, as a * row is"                      "$( rigN "$rigTags" "keeper-two:ws-main:wildcard:$rigTestbedA/tb" ):$( rigN "$rigTags" "keeper-two:ws-main:wildcard:$rigTestbedB/tb" ):$( rigN "$rigTags" "keeper-two:ws-main:explicit:" )" "1:1:0"
rigAssert "a pattern matching nothing: no row, no warning"      "$( rigRow 'nm/**' ):$( rigRow "keeper-two:ws-main:unresolved:" ):$( rigN "$rigTmp/build.err" 'nomatch-' )" "0:0:0"
rigAssert "exact, . and * keep their tags"                      "$( rigN "$rigTags" "keeper-w:ws-main:explicit:$rigSide/docs2" ):$( rigN "$rigTags" "keeper-w:ws-main:own:$rigMain/shared" ):$( rigN "$rigTags" "*:ws-main:wildcard:$rigSide/any" ):$( rigN "$rigTags" "*:ws-main:own:$rigMain/any" )" "1:1:1:1"

echo "-- 2. grants.index: fully unrolled, ceilings, floor --"
rigIdx(){ ## member, verb, glob -- how many index rows
	LC_ALL=C awk -F'\t' -v m="$1" -v v="$2" -v g="$3" '$1 == m && $2 == v && $3 == g { n++ } END { print n + 0 }' "$rigIndex"
}
rigAssert "the index carries its header"                        "$( head -1 "$rigIndex" | cut -f1 )" "myx.distro grants.index 1"
rigAssert "a * row is one row per member"                       "$( LC_ALL=C awk -F'\t' -v g="$rigSide/any/**" '$2 == "read" && $3 == g { print $1 }' "$rigIndex" | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "keeper-d keeper-two keeper-w magic-librarian magic-tester "
rigAssert "no * member row is left"                             "$( LC_ALL=C awk -F'\t' '$1 == "*" && $2 != "ceiling"' "$rigIndex" | LC_ALL=C grep -c . )" 0
rigAssert "the ceilings: the read-only place"                   "$( LC_ALL=C awk -F'\t' -v p="$rigTmp/ro-dir/**" '$1 == "*" && $2 == "ceiling" && $3 == p { print $5 ":" $6 }' "$rigIndex" )" "read-only:ro-dir"
rigAssert "the capped row is a read row"                        "$( rigIdx keeper-d read "$rigTmp/ro-dir/**" ):$( rigIdx keeper-d write "$rigTmp/ro-dir/**" )" "1:0"
rigAssert "an unresolved row admits nothing"                    "$( LC_ALL=C awk -F'\t' '$1 == "keeper-d" && $2 == "unresolved" { print $4 }' "$rigIndex" | LC_ALL=C sort -u )" "-"
rigAssert "the floor: temp in every tooling workspace"          "$( rigIdx magic-tester write "$rigMain/.local/temp/**" ):$( rigIdx magic-tester write "$rigSide/.local/temp/**" )" "1:1"
rigAssert "the docs floor where agents are installed"           "$( rigIdx magic-tester read "$rigMain/source/**/MAGIC.md" ):$( rigIdx magic-tester read "$rigMain/source/**/README.md" ):$( rigIdx magic-tester read "$rigMain/source/**/docs/**.md" ):$( rigIdx magic-tester write "$rigMain/source/**/MAGIC.md" )" "1:1:1:1"
rigAssert "and not where they are not"                          "$( rigIdx magic-tester read "$rigSide/source/**/MAGIC.md" )" 0
rigAssert "no member's floor reads all of source/**"            "$( LC_ALL=C awk -F'\t' -v g="$rigMain/source/**" '$3 == g && $5 == "floor"' "$rigIndex" | LC_ALL=C grep -c . )" 0
rigAssert "the librarian's read is standing"                    "$( LC_ALL=C awk -F'\t' -v g="$rigMain/source/**" '$1 == "magic-librarian" && $2 == "read" && $3 == g { print $5 }' "$rigIndex" )" standing
rigTesterRows=""
for rigOne in "$rigMain" "$rigSide" "$rigTestbedA" "$rigTestbedB" "$rigDecoy" ; do
	rigTesterRows="$rigTesterRows$( rigIdx magic-tester read "$rigOne/source/**/sh-test/**" )$( rigIdx magic-tester read "$rigOne/source/**/test/**" )$( rigIdx magic-tester read "$rigOne/source/**/tests/**" )$( rigIdx magic-tester read "$rigOne/.local/myx/**" ) "
done
rigAssert "magic-tester reads sh-test, test, tests and .local/myx in every workspace" "$rigTesterRows" "1111 1111 1111 1111 1111 "
rigAssert "and no other member does"                            "$( LC_ALL=C awk -F'\t' '$1 != "magic-tester" && $2 == "read" && ( $3 ~ /\/source\/\*\*\/(sh-test|test|tests)\/\*\*$/ || $3 ~ /\/\.local\/myx\/\*\*$/ )' "$rigIndex" | LC_ALL=C grep -c . )" 0
rigAssert "magic-tester writes ** in the testbeds only"         "$( rigIdx magic-tester write "$rigTestbedA/**" ):$( rigIdx magic-tester write "$rigTestbedB/**" ):$( rigIdx magic-tester write "$rigDecoy/**" ):$( rigIdx magic-tester write "$rigMain/**" ):$( rigIdx magic-tester write "$rigSide/**" )" "1:1:0:0:0"

echo "-- 3. the harness gate, read and write --"
## One served call, as the MCP server makes it; output in call.out.
rigCall(){ ## member, session, tool, argument object, [extra env]...
	local callMember="$1" callSession="$2" callTool="$3" callArgs="$4" ; shift 4
	( cd "$rigMain" && printf '%s' "$callArgs" | env -i HOME="$rigHome" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigMain" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" MDAT_DATA_ROOT="$rigData" MDAT_SPAWN_AGENT="$callMember" MDAT_SPAWN_SESSION_ID="$callSession" "$@" \
		bash "$rigHarness" --intern-tool "$callTool" ) > "$rigTmp/call.out" 2> "$rigTmp/call.err"
}
rigRead(){ ## member, session, path -- read or refused
	rigCall "$1" "$2" Read "{\"path\":\"$3\"}"
	case "$( cat "$rigTmp/call.out" )" in
		*'not in the allowed access-root set'*) printf refused ;;
		*rig-seed*) printf read ;;
		*) printf 'other:%s' "$( head -1 "$rigTmp/call.out" )" ;;
	esac
}
rigWrite(){ ## member, session, path, [extra env]... -- wrote, refused or ceiling
	local writeMember="$1" writeSession="$2" writePath="$3" ; shift 3
	rigCall "$writeMember" "$writeSession" Write "{\"file_path\":\"$writePath\",\"content\":\"rig-seed written\\n\"}" "$@"
	case "$( cat "$rigTmp/call.out" )" in
		OK:*) printf wrote ;;
		*'not in the allowed write-root set'*) printf refused ;;
		*'is a read-only place'*) printf ceiling ;;
		*) printf 'other:%s' "$( head -1 "$rigTmp/call.out" )" ;;
	esac
}
rigProj="$rigMain/source/rig/rig-proj"
rigAssert "magic-librarian reads source/**"                     "$( rigRead magic-librarian s-lib "$rigProj/x.sh" )" read
rigAssert "another member does not"                             "$( rigRead magic-tester s-tester "$rigProj/x.sh" )" refused
rigAssert "every member reads MAGIC.md, README.md and docs/**.md" "$( rigRead magic-tester s-tester "$rigProj/MAGIC.md" ):$( rigRead magic-tester s-tester "$rigProj/README.md" ):$( rigRead magic-tester s-tester "$rigProj/docs/deep/a.md" )" "read:read:read"
rigAssert "a namespace grant reads its namespace"               "$( rigRead keeper-w s-w "$rigProj/x.sh" )" read
rigAssert "every member writes MAGIC.md under source"           "$( rigWrite magic-tester s-tester "$rigProj/MAGIC.md" )" wrote
rigAssert "and not README.md"                                   "$( rigWrite magic-tester s-tester "$rigProj/README.md" )" refused
rigAssert "every member writes .local/temp/**"                  "$( rigWrite magic-tester s-tester "$rigMain/.local/temp/member/keeper-w/x.txt" )" wrote
rigAssert "a directory grant writes its glob"                   "$( rigWrite keeper-d s-d "$rigTmp/rw-dir/a.md" )" wrote
rigAssert "a single * stays in its segment"                     "$( rigWrite keeper-d s-d "$rigTmp/rw-dir/sub/a.md" ):$( rigWrite keeper-d s-d "$rigTmp/rw-dir/a.txt" )" "refused:refused"
printf 'rig-seed ro\n' > "$rigTmp/ro-dir/x.txt"
rigAssert "a read-only place: the capped grant reads"           "$( rigRead keeper-d s-d "$rigTmp/ro-dir/x.txt" )" read
rigAssert "and a write is refused by its ceiling first"         "$( rigWrite keeper-d s-d "$rigTmp/ro-dir/x.txt" )" ceiling
rigAssert "naming another route, unrecorded"                    "$( rigN "$rigTmp/call.out" 'find another suitable location' ):$( rigN "$rigTmp/call.out" 'REFUSAL-ID' )" "1:0"
mkdir -p "$rigMain/.local/agents/spawned/sb/input" "$rigMain/.local/agents/spawned/sb/output"
rigAssert "with a sandbox, the route is its output/"            "$( rigWrite keeper-d s-d "$rigTmp/ro-dir/x.txt" MDAT_SPAWN_SANDBOX_ROOT="$rigMain/.local/agents/spawned/sb" ):$( rigN "$rigTmp/call.out" "write to your session sandbox output/ instead, or a folder under it: $rigMain/.local/agents/spawned/sb/output/" )" "ceiling:1"
rigAssert "the human-owner's own session keeps the roots"       "$( ( cd "$rigMain" && printf '{"path":"%s"}' "$rigProj/x.sh" | env -i HOME="$rigHome" PATH="$rigTmp/bin:/usr/bin:/bin" MMDAPP="$rigMain" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" bash "$rigHarness" --intern-tool Read 2>/dev/null ) | LC_ALL=C grep -c 'rig-seed x.sh' )" 1

echo "-- 4. the session permission index --"
rigSessionIndex="$rigMain/.local/agents/sessions/s-life/permissions.magic-tester.index"
rigRead magic-tester s-life "$rigProj/MAGIC.md" > /dev/null
rigAssert "built in the session's own directory"                "$( [ -f "$rigSessionIndex" ] && head -1 "$rigSessionIndex" | cut -f1-2 | LC_ALL=C tr '\t' ' ' )" "myx.distro session.permissions.index 1 magic-tester"
sleep 1 ; rigRead magic-tester s-life "$rigProj/MAGIC.md" > /dev/null
sleep 1 ; : > "$rigTmp/marker" ; sleep 1
rigAssert "reused, with no rebuild"                             "$( rigRead magic-tester s-life "$rigProj/README.md" ):$( [ "$rigSessionIndex" -nt "$rigTmp/marker" ] && printf rebuilt || printf reused )" "read:reused"
rigTarget="$rigProj/x.sh"
rigRead magic-tester s-life "$rigTarget" > /dev/null
rigId="$( LC_ALL=C sed -n 's/^REFUSAL-ID: \(refusal-[0-9a-f-]*\)$/\1/p' "$rigTmp/call.out" | head -1 )"
[ -n "$rigId" ] || { cat "$rigTmp/call.out" "$rigTmp/call.err" | tail -20 ; rigRefuse "the refused read recorded no refusal, so no grant could be opened" ; }
sleep 1 ; : > "$rigTmp/marker" ; sleep 1
rigRun ws-main --intern-op-permission-grant-open human-owner --session-id s-life --refusal-id "$rigId" --kind session
rigAssert "a session grant opened"                              "$( LC_ALL=C sed -n 's/^GRANT: \([a-z]*\) .*/\1/p' "$rigTmp/out" )" session
rigAssert "rebuilds it, and the retry is admitted"              "$( rigRead magic-tester s-life "$rigTarget" ):$( [ "$rigSessionIndex" -nt "$rigTmp/marker" ] && printf rebuilt || printf reused )" "read:rebuilt"
rigAssert "the grant is the session's row"                      "$( LC_ALL=C awk -F'\t' -v r="$rigId" '$1 == "session" && $4 == r { print $2 }' "$rigSessionIndex" )" Read
rigAssert "it opens no other tool"                              "$( rigCall magic-tester s-life Grep "{\"pattern\":\"rig\",\"path\":\"$rigTarget\"}" ; LC_ALL=C grep -c 'not in the allowed access-root set' "$rigTmp/call.out" )" 1
mkdir -p "$rigMain/later"
printf 'rig-seed later\n' > "$rigMain/later/a.txt"
rigAssert "control: a path no row names is refused"            "$( rigRead magic-tester s-life "$rigMain/later/a.txt" )" refused
sleep 1 ; : > "$rigTmp/marker" ; sleep 1
printf 'magic-tester:ws-main:workspace:Read(/%s/later/**)\n' "$rigMain" >> "$rigReg"
rigAssert "a grants index change rebuilds both, and admits it"  "$( rigRead magic-tester s-life "$rigMain/later/a.txt" ):$( [ "$rigIndex" -nt "$rigTmp/marker" ] && printf rebuilt || printf kept ):$( [ "$rigSessionIndex" -nt "$rigTmp/marker" ] && printf rebuilt || printf reused )" "read:rebuilt:rebuilt"
rigOnceTarget="$rigMain/later2/once.txt"
mkdir -p "${rigOnceTarget%/*}"
rigWrite magic-tester s-life "$rigOnceTarget" > /dev/null
rigId="$( LC_ALL=C sed -n 's/^REFUSAL-ID: \(refusal-[0-9a-f-]*\)$/\1/p' "$rigTmp/call.out" | head -1 )"
rigRun ws-main --intern-op-permission-grant-open human-owner --session-id s-life --refusal-id "$rigId" --kind once
rigAssert "an Allow once admits the retry once"                 "$( rigWrite magic-tester s-life "$rigOnceTarget" ):$( rigWrite magic-tester s-life "$rigOnceTarget" )" "wrote:refused"
rigAssert "used up through its store's marker"                  "$( [ -d "$rigMain/.local/agents/sessions/s-life/consumed/$rigId" ] && printf used || printf unused )" used
rigWrite magic-tester s-life "$rigOnceTarget.2" > /dev/null
rigId="$( LC_ALL=C sed -n 's/^REFUSAL-ID: \(refusal-[0-9a-f-]*\)$/\1/p' "$rigTmp/call.out" | head -1 )"
rigRun ws-main --intern-op-permission-grant-open human-owner --session-id s-life --refusal-id "$rigId" --kind once
sleep 2
rigAssert "an Allow once lapses past its TTL"                   "$( rigWrite magic-tester s-life "$rigOnceTarget.2" MDAT_PERMISSION_ONCE_TTL=1 )" refused
rigTaskTarget="$rigMain/later2/task.txt"
rigWrite magic-tester s-life "$rigTaskTarget" > /dev/null
rigId="$( LC_ALL=C sed -n 's/^REFUSAL-ID: \(refusal-[0-9a-f-]*\)$/\1/p' "$rigTmp/call.out" | head -1 )"
rigRun ws-main --intern-op-permission-grant-open human-owner --session-id s-life --refusal-id "$rigId" --kind task --task task-rig
rigAssert "a task grant admits while its item is open"          "$( rigWrite magic-tester s-life "$rigTaskTarget" )" wrote
mv "$rigData/board/running/task-rig.md" "$rigData/board/processed/task-rig.md"
rigAssert "and not once the item is closed"                     "$( rigWrite magic-tester s-life "$rigTaskTarget" )" refused
rigAssert "the holders read the same index"                     "$( rigRun ws-main --intern-op-permission-holders Read "$rigProj/x.sh" ; LC_ALL=C tr '\n' '|' < "$rigTmp/out" )" "HOLDER: human-owner human-owner|"

echo "-- 5. CLIENT_ACCESS_ROOTS_EXTRA is gone --"
rigAssert "no code, help or doc names it"                       "$( LC_ALL=C grep -r -l 'CLIENT_ACCESS_ROOTS_EXTRA' "$rigHere" "$rigPackage/sh-scripts" "$rigPackage/docs" "$rigPackage/MAGIC.md" 2>/dev/null | LC_ALL=C grep -c . )" 0
mkdir -p "$rigMain/.local/.agents"
printf 'CLIENT_ACCESS_ROOTS_EXTRA=%s\n' "$rigTmp/extra" > "$rigMain/.local/.agents/magic-team.agent.env"
mkdir -p "$rigTmp/extra" ; printf 'rig-seed extra\n' > "$rigTmp/extra/a.txt"
rigAssert "a stored value opens nothing"                        "$( rigRead magic-tester s-tester "$rigTmp/extra/a.txt" ):$( env -i HOME="$rigHome" PATH=/usr/bin:/bin MMDAPP="$rigMain" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "'"$rigHere"'/AgentsTools.ClientAccessRoots.include" ; AgentsToolsClientAccessReferenceRoots read "$MMDAPP"' | LC_ALL=C grep -c -F "$rigTmp/extra" )" "refused:0"
rigRun ws-main --owner-setup-claude --access-root "$rigTmp/extra" --apply
rigAssert "its owner-setup option is refused as unknown"        "$( [ "$rigRc" != 0 ] && printf refused || printf taken )" refused

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ GRANTS INDEX CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'GRANTS_INDEX: OK (%d assertions, offline, rig HOME only)\n' "$rigPass"
