#!/usr/bin/env bash
## Behavioural check on the ONE operation that makes every index of the tooling, --make-harness-indices [<name>...],
## run rather than read, against a rig workspace built here: its own member registry and skillset, its own spawn
## sandboxes, its own asks and its own board. Held: with no name it builds everything, in its own order -- the four
## registries (team-members, team-members-names, spawned-sessions, pending-replies), each whole, from its store, by
## the one rebuild function every other rebuild of that registry calls; then members, permissions, grants, and the
## harness's own mcp.servers, harness.roots, harness.hooks. With names it builds only those, in that same order
## whatever the order given, and every file not named is left as it is, inode and bytes. A name that is none of
## them refuses the call in one line that lists the names, before anything is built; so does a name the machine's
## members index knows as a member of another workspace, which the dispatcher takes for no member in a --make-*
## operation. --make-agents-indices is the earlier name of the same operation: the same files, the same bytes, the
## same lines but for the name it was called by, and the same names. A file behind its store is brought up to date.
## An occasion with no session store, a workspace as an install first meets it, ends 0: each registry is written
## with no rows, with no error and no warning, and no store is made. No caller inside the package names a list
## where it means the build: --make-workspace-integrations and the source-prepare build each call the operation
## once, with no name. The integrations run is run whole in a rig: the install's part that writes the member
## registry, the member homes, the one build, then the install's part that reads the indices; a first install and
## a later update each leave every one of the ten files current, and the install run by itself is still both of
## its parts. The other builder builds nothing and says where the build is. The registry writer's temp file is its own for every writer:
## two rebuilds from subshells of one shell leave a whole file and no false failure, and so do a build and a
## session's own rebuilds as processes; no writer of a registry or an index that holds no lock names its temp by the
## shell's process id. And the help pair. A fake `curl` first on PATH would log a request: none is made. Offline;
## only the rig's own tree is read or written.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRegInclude="$rigHere/AgentsTools.Registries.include"
rigMakeInclude="$rigHere/AgentsTools.Make.include"
rigBuilders="$rigPackage/builders/source-prepare"
rigOne="--make-harness-indices"
rigEarlier="--make-agents-indices"
rigRegistries="team-members team-members-names spawned-sessions pending-replies"
rigNames="$rigRegistries members permissions grants mcp.servers harness.roots harness.hooks"
## the names that leave a file in this rig: a workspace with no source folder declares no grant, so no permissions registry
rigFiled="$rigRegistries members grants mcp.servers harness.roots harness.hooks"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigRegInclude" ] || rigRefuse "the registries include is not at: $rigRegInclude"
[ -f "$rigMakeInclude" ] || rigRefuse "the make include is not at: $rigMakeInclude"
[ -d "$rigBuilders" ] || rigRefuse "the source-prepare builders are not at: $rigBuilders"
rigTmp="$( mktemp -d -t AgentsMakeIndicesRegistriesCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigSkills="$rigTmp/skills" ; rigHome="$rigTmp/home"
rigAgents="$rigWs/.local/agents"
## The team data store where the dispatcher finds it for a workspace that names none: this check hands the build no
## data root, so a board item among the pending replies was read through the one the operation resolved itself.
rigData="$rigAgents/team-data-root"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigSkills" "$rigHome"
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "%s/curl.calls"\nexit 7\n' "$rigTmp" > "$rigTmp/bin/curl"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so a request of this check would be a real one"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

## The rig's stores. Every record of one round carries that round's word, so a file that holds it was built after it.
rigMember(){ ## member, Name as written, alias, mark -- its skillset folder and its row of this workspace's member registry
	mkdir -p "$rigSkills/$1" "$rigAgents"
	printf -- '---\nmaintainers: rig\n---\n# %s\n- **Name**: %s\n- **Alias**: `%s`.\n- **Unicode character**: %s\n' "$1" "$2" "$3" "$4" > "$rigSkills/$1/$1.basic.md"
	printf -- '---\nname: %s\nstatus: active\ndescription: rig\n---\n\n# %s\n' "$1" "$1" > "$rigSkills/$1/SKILL.md"
	printf '%s\t%s\tsource-symlink\t%s\t%s\n' "$1" "$rigWs" "myx/pkg/skillset/$1" "$rigWs/source/myx/pkg/skillset/$1" >> "$rigAgents/members.registry"
}
rigSpawn(){ ## sandbox, spawn id -- one spawn record in a sandbox of its own
	mkdir -p "$rigAgents/spawned/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nhost: righost\nowner: keeper-rig\nstatus: spawn-started\n---\nbody\n' "$2" "$2" > "$rigAgents/spawned/$1/$2.md"
}
rigAsk(){ ## record name -- one open ask
	mkdir -p "$rigAgents/pending"
	printf -- '---\nstatus: reply-pending\nsession-id: sess-of-%s\nowner: keeper-rig\ncommunication-channel-id: CRIG00001\n---\nq\n' "$1" > "$rigAgents/pending/$1.md"
}
rigBoard(){ ## item name -- one board item that waits on a reply
	mkdir -p "$rigData/board/running"
	printf -- '---\nblocked-on: human\nstatus: waiting\nsession-id: sess-of-%s\nowner: keeper-rig\n---\n' "$1" > "$rigData/board/running/$1.md"
}
rigRound(){ ## round word -- one more record in every store
	rigMember "keeper-$1" "Rig ${1}keeper." "alias$1" 🔧
	rigSpawn "s-$1" "spawn-$1"
	rigAsk "ask-$1"
	rigBoard "task-$1"
}
rigFile(){ ## name -- the file that name builds
	case "$1" in
		members|grants|mcp.servers|harness.roots|harness.hooks) printf '%s\n' "$rigAgents/$1.index" ;;
		*) printf '%s\n' "$rigAgents/$1.registry" ;;
	esac
}
rigLines(){ ## file -- its lines; no-file where there is none
	[ -f "$1" ] || { printf 'no-file\n' ; return 0 ; }
	LC_ALL=C awk 'END { print NR + 0 }' "$1"
}
rigRows(){ ## registry name, first column -- how many rows of that registry's file carry it; no-file where there is none
	[ -f "$( rigFile "$1" )" ] || { printf 'no-file\n' ; return 0 ; }
	LC_ALL=C awk -v want="$2" '$1 == want { n++ } END { print n + 0 }' "$( rigFile "$1" )"
}
rigHolds(){ ## round word -- for each of the four registries, in their order, how many of that round's records it holds: the board item last
	printf '%s %s %s %s %s\n' "$( rigRows team-members "keeper-$1" )" "$( rigRows team-members-names "keeper-$1" )" "$( rigRows spawned-sessions "s-$1" )" "$( rigRows pending-replies "ask-$1.md" )" "$( rigRows pending-replies "task-$1.md" )"
}
rigSizes(){ ## -- the lines of the four registries, in their order
	local sizesName sizesOut=""
	for sizesName in $rigRegistries ; do sizesOut="$sizesOut${sizesOut:+ }$( rigLines "$( rigFile "$sizesName" )" )" ; done
	printf '%s\n' "$sizesOut"
}
## What tells a file left as it is from one written again: a build puts a new file in its place, so its inode
## changes even where its bytes do not.
rigPrint(){ ## name
	[ -f "$( rigFile "$1" )" ] || { printf 'no-file\n' ; return 0 ; }
	printf '%s:%s\n' "$( ls -i "$( rigFile "$1" )" | LC_ALL=C awk '{ print $1 ; exit }' )" "$( cksum < "$( rigFile "$1" )" | LC_ALL=C tr -s ' \t' '-' )"
}
rigPrints(){ ## -- the prints of every file a name builds here, in the build's order
	local printsOut="" printsName
	for printsName in $rigFiled ; do printsOut="$printsOut${printsOut:+ }$( rigPrint "$printsName" )" ; done
	printf '%s\n' "$printsOut"
}
rigChanged(){ ## prints taken before -- which names have another print now, in the build's order; none where none has
	local changedOut="" changedName changedNo=0 changedWas
	for changedName in $rigFiled ; do
		changedNo=$(( changedNo + 1 ))
		changedWas="$( printf '%s\n' "$1" | LC_ALL=C awk -v no="$changedNo" '{ print $no }' )"
		[ "$( rigPrint "$changedName" )" = "$changedWas" ] || changedOut="$changedOut${changedOut:+ }$changedName"
	done
	printf '%s\n' "${changedOut:-none}"
}
rigBytes(){ ## -- the bytes of every file a name builds here, as one sum
	local bytesName
	for bytesName in $rigFiled ; do cksum < "$( rigFile "$bytesName" )" ; done | cksum
}
rigRun(){ ## tool arguments... -- in the rig workspace; rc in rigRc, stdout in $rigTmp/out, stderr in $rigTmp/err
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigMake(){ ## names... -- the one operation
	rigRun "$rigOne" "$@"
}
rigNote(){ ## the operation as called, name -- the line that build step says on stderr here, for its file as it stands now; none for mcp.servers
	case "$2" in
		members|grants) printf '# DistroAgentsTools %s: wrote %s\n' "$1" "$( rigFile "$2" )" ;;
		permissions) printf '# DistroAgentsTools %s: workspace %s has no source folder, so none declares a grant -- nothing is removed\n' "$1" "$rigWs" ;;
		mcp.servers) ;;
		harness.roots) printf '🧭 harness roots index written: .local/agents/harness.roots.index\n' ;;
		harness.hooks) printf '🧭 harness hooks index written: .local/agents/harness.hooks.index\n' ;;
		*) printf '# DistroAgentsTools %s: wrote %s (%s rows)\n' "$1" "$( rigFile "$2" )" "$( rigLines "$( rigFile "$2" )" )" ;;
	esac
}
rigNotes(){ ## the operation as called, names... -- those lines, in that order
	local notesOp="$1" notesName
	shift
	for notesName in "$@" ; do rigNote "$notesOp" "$notesName" ; done
}
rigSaid(){ ## -- every line of the last run's stderr that a build step says, whole, in order
	LC_ALL=C grep -E -- '^# DistroAgentsTools |^🧭 ' "$rigTmp/err" || :
}
rigErrN(){ ## fixed text -- how many lines of the last run's stderr hold it
	LC_ALL=C grep -c -F -- "$1" "$rigTmp/err" || :
}
## Errors and warnings, but for one. A rig workspace is no distro workspace, which the context says in a line of its
## own before the operation starts (SystemContext.SetInputSpec), in every rig of this package.
rigTroubles(){ ## files... (the last run's stderr where none is given) -- how many of their lines are an error or a warning
	[ $# -gt 0 ] || set -- "$rigTmp/err"
	cat "$@" | LC_ALL=C grep -E -- 'ERROR|WARNING' | LC_ALL=C grep -c -v -F -- 'SystemContext.SetInputSpec' || :
}
rigOutBytes(){ ## -- the bytes of the last run's stdout
	wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' '
}
rigRowsOf(){ ## rows function, output file -- what that function prints for the rig's stores now, called by this check itself
	( MMDAPP="$rigWs" ; MDAT_DATA_ROOT="$rigData" ; MDAT_SKILLSET_ROOT="$rigSkills" ; export MMDAPP MDAT_DATA_ROOT MDAT_SKILLSET_ROOT
		. "$rigRegInclude" ; "$1" ) > "$2" 2> /dev/null
}
rigSame(){ ## rows function, registry name -- whether that registry's file is, byte for byte, what its rows function prints now
	rigRowsOf "$1" "$rigTmp/want.rows"
	if cmp -s "$rigTmp/want.rows" "$( rigFile "$2" )" ; then printf 'same\n' ; else printf 'differs\n' ; fi
}
rigRefusal(){ ## the operation as called, name -- the one line a name that is none of them is refused with
	printf "⛔ ERROR: DistroAgentsTools %s: '%s' is none of what it builds -- nothing was built. Its names: %s\n" "$1" "$2" "$( printf '%s' "$rigNames" | LC_ALL=C sed 's/ /, /g' )"
}

echo "-- 1. no name, and an occasion with no store: a workspace as an install first meets it --"
rigAssert "control: the workspace holds no member registry, no sandbox, no ask and no team data, and no file of the build" "$( ls "$rigWs/.local" | LC_ALL=C tr '\n' ' ' )$( [ -e "$rigAgents" ] && echo there || echo none )" "none"
rigMake
rigAssert "the one operation, with no name, ends 0 and prints nothing on stdout" "$rigRc $( rigOutBytes )" "0 0"
rigAssert "all four registries are written, each with no rows" "$( rigSizes )" "0 0 0 0"
rigAssert "every step says its line, in the build's own order: the registries, members, permissions, grants, then the harness's own" "$( rigSaid )" "$( rigNotes "$rigOne" $rigNames )"
rigAssert "with no error and no warning" "$( rigTroubles )" "0"
rigAssert "the folder holds what the build makes here, and nothing else" "$( ls "$rigAgents" | LC_ALL=C tr '\n' ' ' )" "grants.index harness.hooks.index harness.roots.index mcp.servers.index members members.index pending-replies.registry spawned-sessions.registry team-members-names.registry team-members.registry "
rigAssert "and it made no store of its own: no sandbox root, no ask folder, no team data root" "$( [ -e "$rigAgents/spawned" ] && echo spawned ) $( [ -e "$rigAgents/pending" ] && echo pending ) $( [ -e "$rigData" ] && echo data )" "  "

echo "-- 2. the earlier name is the same operation --"
rigOneSaid="$( rigSaid | LC_ALL=C sed "s/^# DistroAgentsTools $rigOne: /# DistroAgentsTools <as called>: /" )" ; rigOneBytes="$( rigBytes )" ; rigBefore="$( rigPrints )"
rigRun "$rigEarlier"
rigAssert "$rigEarlier, with no name, ends 0, nothing on stdout, no error and no warning" "$rigRc $( rigOutBytes ) $( rigTroubles )" "0 0 0"
rigAssert "it builds every file the one operation builds: each is a new file" "$( rigChanged "$rigBefore" )" "$rigFiled"
rigAssert "of the same bytes" "$( rigBytes )" "$rigOneBytes"
rigAssert "and says the same lines, but for the name it was called by" "$( rigSaid | LC_ALL=C sed "s/^# DistroAgentsTools $rigEarlier: /# DistroAgentsTools <as called>: /" )" "$rigOneSaid"
rigAssert "control: its own lines do carry its own name" "$( rigErrN "# DistroAgentsTools $rigEarlier: " ) $( rigErrN "# DistroAgentsTools $rigOne: " )" "7 0"

echo "-- 3. stores that hold records the files do not: every registry is brought up to date --"
rigRound one
rigAssert "control: the stores hold records the four registries do not" "$( rigHolds one )" "0 0 0 0 0"
rigMake
rigAssert "the build ends 0, nothing on stdout, no error and no warning" "$rigRc $( rigOutBytes ) $( rigTroubles )" "0 0 0"
rigAssert "each registry holds the record of its store, the board item among the pending replies: read through the dispatcher's own data root" "$( rigHolds one )" "1 1 1 1 1"
rigAssert "each is noted with its file and the rows that file has" "$( rigSaid )" "$( rigNotes "$rigOne" $rigNames )"
rigAssert "the names row is the member's basic.md, as the names registry writes it" "$( LC_ALL=C grep '^keeper-one ' "$( rigFile team-members-names )" )" "keeper-one 🔧 Rig onekeeper aliasone"
rigAssert "three of the registries are, byte for byte, what the registry's own rows function prints" "$( rigSame AgentsToolsRegistryTeamMembersRows team-members ) $( rigSame AgentsToolsRegistrySpawnedSessionsRows spawned-sessions ) $( rigSame AgentsToolsRegistryPendingRepliesRows pending-replies )" "same same same"
rigAssert "control: the rows this check asked for are rows, and those of another store differ" "$( rigRowsOf AgentsToolsRegistryPendingRepliesRows "$rigTmp/want.rows" ; rigLines "$rigTmp/want.rows" ) $( rigSame AgentsToolsRegistrySpawnedSessionsRows pending-replies )" "2 differs"
rigRound two
rigAssert "control: a second round of records, and the registries, now with rows, are behind again" "$( rigHolds two ) $( rigSizes )" "0 0 0 0 0 1 1 1 2"
rigRun "$rigEarlier"
rigAssert "the earlier name brings them level as well: both rounds in every registry" "$rigRc $( rigHolds two ) $( rigHolds one ) $( rigSizes )" "0 1 1 1 1 1 1 1 1 1 1 2 2 2 4"
rm -f "$rigAgents/pending/ask-one.md" "$rigData/board/running/task-one.md" ; rm -rf "$rigAgents/spawned/s-one"
rigMake
rigAssert "a rebuild is whole: a record gone from its store has no row left, the others stay" "$rigRc $( rigRows spawned-sessions s-one ) $( rigRows pending-replies ask-one.md ) $( rigRows pending-replies task-one.md ) $( rigSizes )" "0 0 0 0 2 2 1 2"

echo "-- 4. with names: only those, in the build's own order --"
rigRound three
rigBefore="$( rigPrints )"
rigMake spawned-sessions
rigAssert "one name: it ends 0, nothing on stdout, and says that one step's line and no other" "$rigRc $( rigOutBytes ) $( rigSaid )" "0 0 $( rigNote "$rigOne" spawned-sessions )"
rigAssert "that registry is level with its store, and every other file is the file it was, inode and bytes, the other registries still behind" "$( rigChanged "$rigBefore" ) $( rigHolds three )" "spawned-sessions 0 0 1 0 0"
rigEachBad=""
for rigName in $rigFiled ; do
	rigBefore="$( rigPrints )"
	rigMake "$rigName"
	[ "$rigRc $( rigChanged "$rigBefore" ) $( rigSaid )" = "0 $rigName $( rigNote "$rigOne" "$rigName" )" ] || rigEachBad="$rigEachBad [$rigName: rc $rigRc, changed $( rigChanged "$rigBefore" ), said $( rigSaid )]"
done
rigAssert "each of the nine names that leave a file here, alone: it ends 0, builds its own file and no other, and says its own line and no other" "${rigEachBad:-each its own}" "each its own"
rigBefore="$( rigPrints )"
rigMake permissions
rigAssert "permissions alone: the grants' own step runs and says its line; with no source folder here it writes no file, and no other is written" "$rigRc $( rigChanged "$rigBefore" ) $( rigSaid )" "0 none $( rigNote "$rigOne" permissions )"
rigAssert "after the names, every registry is level with its store" "$( rigHolds three )" "1 1 1 1 1"
rigRound four
rigBefore="$( rigPrints )"
rigMake harness.hooks pending-replies grants team-members
rigAssert "several names, in any order: it ends 0 and builds those, in the build's own order" "$rigRc $( rigSaid )" "0 $( rigNotes "$rigOne" team-members pending-replies grants harness.hooks )"
rigAssert "those four files are written, the others left as they were, the two registries not named still behind" "$( rigChanged "$rigBefore" ) $( rigHolds four )" "team-members pending-replies grants harness.hooks 1 0 0 1 1"
rigBefore="$( rigPrints )"
rigMake spawned-sessions spawned-sessions
rigAssert "a name given twice is built once" "$rigRc $( rigChanged "$rigBefore" ) $( rigSaid )" "0 spawned-sessions $( rigNote "$rigOne" spawned-sessions )"
rigBefore="$( rigPrints )"
rigRun "$rigEarlier" team-members-names
rigAssert "the earlier name takes the same names: that one registry, and its line carries the name it was called by" "$rigRc $( rigChanged "$rigBefore" ) $( rigSaid ) $( rigHolds four )" "0 team-members-names $( rigNote "$rigEarlier" team-members-names ) 1 1 1 1 1"

echo "-- 5. a name that is none of them is refused before anything is built --"
rigRound five
rigBefore="$( rigPrints )" ; rigStoreBefore="$( cksum < "$rigAgents/members.registry" )"
rigMake spawned-sessions no-such-index grants
rigAssert "between two real names: it ends 1, in one line that lists the names, nothing on stdout" "$rigRc $( rigOutBytes ) $( LC_ALL=C grep -F -- "DistroAgentsTools $rigOne" "$rigTmp/err" )" "1 0 $( rigRefusal "$rigOne" no-such-index )"
rigAssert "and nothing was built, the real name ahead of it neither: every file is the file it was, and the registries are behind" "$( rigChanged "$rigBefore" ) $( rigHolds five )" "none 0 0 0 0 0"
rigRefusedBad=""
for rigName in members.registry spawned-sessions.registry harness.roots.index "team-members grants" "" --quiet ; do
	rigMake "$rigName"
	[ "$rigRc $( LC_ALL=C grep -F -- "DistroAgentsTools $rigOne" "$rigTmp/err" )" = "1 $( rigRefusal "$rigOne" "$rigName" )" ] || rigRefusedBad="$rigRefusedBad [$rigName: rc $rigRc, $( LC_ALL=C grep -F -- "DistroAgentsTools $rigOne" "$rigTmp/err" )]"
done
rigAssert "a file name, the member registry's own, two names in one word, an empty name and an option are no names: each refused in that line" "${rigRefusedBad:-each refused}" "each refused"
rigRun "$rigEarlier" no-such-index
rigAssert "the earlier name refuses in the same line, under the name it was called by" "$rigRc $( LC_ALL=C grep -F -- "DistroAgentsTools $rigEarlier" "$rigTmp/err" )" "1 $( rigRefusal "$rigEarlier" no-such-index )"
rigAssert "after the refusals every file is the file it was, the member registry it reads among them" "$( rigChanged "$rigBefore" ) $( cksum < "$rigAgents/members.registry" )" "none $rigStoreBefore"
mkdir -p "$rigHome/.agents/magic-team"
{
	printf '%s\t%s\tsource-symlink\t%s\t%s\n' keeper-one "$rigWs" myx/pkg/skillset/keeper-one "$rigWs/source/myx/pkg/skillset/keeper-one"
	printf '%s\t%s\tsource-symlink\t%s\t%s\n' keeper-far "$rigTmp/ws-far" myx/pkg/skillset/keeper-far "$rigTmp/ws-far/source/myx/pkg/skillset/keeper-far"
} > "$rigHome/.agents/magic-team/members.registry"
rigMake keeper-far
rigAssert "a name the machine's members index knows as another workspace's member is no member to this operation: refused in the operation's own line" "$rigRc $( rigChanged "$rigBefore" ) $( LC_ALL=C grep -F -- "DistroAgentsTools" "$rigTmp/err" )" "1 none $( rigRefusal "$rigOne" keeper-far )"
rigRun --member-help keeper-far
rigAssert "control: the same index does make the dispatcher take that word for a member of another workspace, in an operation that names one" "$rigRc $( rigErrN "member 'keeper-far' is in the team members index but is present in no tracked workspace" )" "1 1"
rigMake spawned-sessions
rigAssert "and a real name is built with that index in place" "$rigRc $( rigChanged "$rigBefore" )" "0 spawned-sessions"
rm -rf "$rigHome/.agents"
rigMake
rigAssert "control: with no name the same stores are built" "$rigRc $( rigHolds five )" "0 1 1 1 1 1"

echo "-- 6. the callers inside the package: the build once, with no name --"
rigWsArm="$( LC_ALL=C awk '/^\t--make-workspace-integrations\)/ { on = 1 } on { print } on && /^\t;;/ { exit }' "$rigMakeInclude" )"
rigAssert "control: the arm of --make-workspace-integrations was cut out of the make include" "$( printf '%s\n' "$rigWsArm" | LC_ALL=C grep -c -F -- 'DistroAgentsTools --intern-member-home-register' || : )" "1"
rigAssert "it calls the build once, as a whole line with no name, and the earlier name not at all" "$( printf '%s\n' "$rigWsArm" | LC_ALL=C grep -c -x -F -- "$( printf '\t\t' )DistroAgentsTools $rigOne || { set +e ; return 1 ; }" || : ) $( printf '%s\n' "$rigWsArm" | LC_ALL=C grep -v '^[[:space:]]*#' | LC_ALL=C grep -c -E -- '--make-(harness|agents)-indices' || : )" "1 1"
rigAssert "in this order: the places, the console command, the install's first part, the member homes, the build, the install's second part, the restrictions" \
	"$( printf '%s\n' "$rigWsArm" | LC_ALL=C grep -v '^[[:space:]]*#' | LC_ALL=C sed -n 's/^.*DistroAgentsTools \(--[a-z-]*\).*$/\1/p' | LC_ALL=C tr '\n' ' ' )" \
	"--intern-directory-register --make-console-command --install-workspace-integrations --intern-member-home-register $rigOne --install-workspace-integrations --install-workspace-restrictions "
rigAssert "no caller inside the package names a list where it means the build: no call of either name is followed by two names" \
	"$( cat "$rigHere"/*.include "$rigHere"/*.sh "$rigPackage"/sh-scripts/*.sh "$rigBuilders"/*.sh | LC_ALL=C grep -v '^[[:space:]]*#' | LC_ALL=C grep -c -E -- 'DistroAgentsTools(\.fn\.sh)? --make-(harness|agents)-indices[[:space:]]+[^|&;[:space:]]+[[:space:]]+[^|&;[:space:]]' || : )" "0"
rigAssert "the install step that makes the roots asks for the one index that holds them, by its one name: in the copilot access step of the install include, once, after it has made a root" "$( LC_ALL=C awk '/^\t--install-copilot-access-fragment\)/ { on = 1 } on { print } on && /^\t;;/ { exit }' "$rigHere/AgentsTools.Install.include" | LC_ALL=C grep -c -F -- 'DistroAgentsTools --make-harness-indices harness.roots' || : ) $( LC_ALL=C grep -c -F -- 'DistroAgentsTools --make-harness-indices harness.roots' "$rigHere/AgentsTools.Install.include" || : ) $( LC_ALL=C grep -c -F -- 'if [ "$createdCount" -gt 0 ] && [ "$workspace" = "$( cd "$MMDAPP" && pwd )" ] ; then' "$rigHere/AgentsTools.Install.include" || : )" "1 1 1"
rigAssert "control: the same reader does find a call that names a list, and takes one name for no list" "$( printf '\t\tDistroAgentsTools --make-harness-indices grants members || x\nDistroAgentsTools.fn.sh --make-agents-indices team-members\n\t\tDistroAgentsTools --make-harness-indices harness.roots || x\n\t\tDistroAgentsTools --make-harness-indices || x\n' | LC_ALL=C grep -c -E -- 'DistroAgentsTools(\.fn\.sh)? --make-(harness|agents)-indices[[:space:]]+[^|&;[:space:]]+[[:space:]]+[^|&;[:space:]]' || : )" "1"
rigAssert "the source-prepare build has one builder that makes the indices: its call is the bare script name and the operation, with no name" \
	"$( ls "$rigBuilders" | LC_ALL=C tr '\n' ' ' )$( LC_ALL=C grep -c -x -F -- "DistroAgentsTools.fn.sh $rigOne" "$rigBuilders/1201-agents-indices.sh" || : ) $( cat "$rigBuilders"/*.sh | LC_ALL=C grep -v '^[[:space:]]*#' | LC_ALL=C grep -c -F -- 'DistroAgentsTools' || : )" "1201-agents-indices.sh 1202-harness-indices.sh 1 1"
rigBuilder(){ ## builder file name -- run as the source-prepare build runs it; rc in rigRc
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$rigPackage/sh-scripts:$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		sh "$rigBuilders/$1" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigRound six
rigBefore="$( rigPrints )"
rigBuilder 1201-agents-indices.sh
rigAssert "that builder ends 0, builds every file of the build, and leaves the four registries level with their stores" "$rigRc $( rigTroubles ) $( rigHolds six ) $( rigChanged "$rigBefore" )" "0 0 1 1 1 1 1 $rigFiled"
rigAssert "and says every step's line, as the operation with no name does" "$( rigSaid )" "$( rigNotes "$rigOne" $rigNames )"
rigBefore="$( rigPrints )"
rigBuilder 1202-harness-indices.sh
rigAssert "the other builder builds nothing: it ends 0, writes no file, and says in one line where the build is" "$rigRc $( rigChanged "$rigBefore" ) $( rigOutBytes ) $( LC_ALL=C grep -c . "$rigTmp/err" || : ) $( rigErrN '1201-agents-indices.sh' )" "0 none 0 1 1"

echo "-- 6a. the integrations run, whole, in a rig: one build step, and every index current at its end --"
## A workspace as an installed one is: its own tooling tree, every package of the origin by link, and an empty source
## tree, so the bundled members are the ones linked. Its own HOME; every call refuses to run outside this rig's tree.
command -v myx.common > /dev/null 2>&1 || rigRefuse "myx.common is not on PATH, and the install's source scan runs it"
rigIntWs="$rigTmp/int/ws" ; rigIntHome="$rigTmp/int/home" ; rigIntAgents="$rigIntWs/.local/agents"
mkdir -p "$rigIntHome" "$rigIntWs/.local/myx" "$rigIntWs/source"
for rigIntPackage in "$MDLT_ORIGIN/myx"/myx.* ; do ln -s "$rigIntPackage" "$rigIntWs/.local/myx/${rigIntPackage##*/}" ; done
rigIntPath="$rigTmp/bin:$( dirname "$( command -v myx.common )" ):/usr/bin:/bin:/usr/sbin:/sbin"
rigInt(){ ## tool arguments... -- in that workspace; rc in rigRc, stderr in $rigTmp/int.err
	rigRc=0
	env -i HOME="$rigIntHome" PATH="$rigIntPath" MMDAPP="$rigIntWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$HOME" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$rigTmp/int.out" 2> "$rigTmp/int.err" < /dev/null || rigRc=$?
}
rigIntBytes(){ ## -- the bytes of every file of the build in that workspace, a line a file; `absent` for one that is not there
	local bytesFile
	for bytesFile in team-members.registry team-members-names.registry spawned-sessions.registry pending-replies.registry members.index permissions.registry grants.index mcp.servers.index harness.roots.index harness.hooks.index ; do
		if [ -f "$rigIntAgents/$bytesFile" ] ; then printf '%s %s\n' "$bytesFile" "$( cksum < "$rigIntAgents/$bytesFile" | LC_ALL=C tr -s ' \t' '-' )" ; else printf '%s absent\n' "$bytesFile" ; fi
	done
}
rigIntLine(){ ## fixed text -- the number of the last line of the run's stderr that holds it; 0 where none does
	LC_ALL=C awk -v want="$1" 'index( $0, want ) { at = NR } END { print at + 0 }' "$rigTmp/int.err"
}
rigIntCount(){ ## fixed text -- how many lines of the run's stderr hold it
	LC_ALL=C grep -c -F -- "$1" "$rigTmp/int.err" || :
}
rigIntMembers(){ ## -- the members this workspace's member registry holds, rules rows left out
	LC_ALL=C awk -F'\t' -v ws="$rigIntWs" '$2 == ws && $3 != "rules-symlink" && !( $1 in seen ) { seen[$1] = 1 ; n++ } END { print n + 0 }' "$rigIntAgents/members.registry" 2> /dev/null
}
rigIntCurrent(){ ## -- whether a build run right now changes a byte of any of the ten files: current where it changes none
	local currentBefore
	currentBefore="$( rigIntBytes )"
	rigInt "$rigOne"
	if [ "$rigRc" = 0 ] && [ "$( rigIntBytes )" = "$currentBefore" ] ; then printf 'current\n' ; else printf 'not current: rc %s, changed: %s\n' "$rigRc" "$( rigIntBytes | LC_ALL=C grep -v -x -F -- "$currentBefore" | LC_ALL=C awk '{ print $1 }' | LC_ALL=C tr '\n' ' ' )" ; fi
}
rigIntOrder(){ ## -- whether the run went: member links, then the one build, then the readers of the indices
	local orderLinks orderBuildFirst orderBuildLast orderPermissions orderCopilot
	orderLinks="$( rigIntLine 'member index written: .local/agents/members.index' )"
	orderBuildFirst="$( rigIntLine "wrote $rigIntAgents/team-members.registry (" )" ; orderBuildLast="$( rigIntLine 'harness hooks index written: .local/agents/harness.hooks.index' )"
	orderPermissions="$( rigIntLine 'claude permissions ' )" ; orderCopilot="$( rigIntLine '✅ copilot access ' )"
	if [ "$orderLinks" -gt 0 ] && [ "$orderLinks" -lt "$orderBuildFirst" ] && [ "$orderBuildFirst" -lt "$orderBuildLast" ] && [ "$orderBuildLast" -lt "$orderPermissions" ] && [ "$orderPermissions" -lt "$orderCopilot" ] ; then
		printf 'ordered\n'
	else
		printf 'not ordered: links %s, build %s to %s, permissions %s, copilot %s\n' "$orderLinks" "$orderBuildFirst" "$orderBuildLast" "$orderPermissions" "$orderCopilot"
	fi
}
rigAssert "control: the workspace holds no file of the build, no member registry and no session store before the first install" "$( [ -e "$rigIntAgents" ] && echo there || echo none )" "none"
rigInt --make-workspace-integrations --quiet
rigAssert "a first install ends 0, with no error" "$rigRc $( rigIntCount '⛔ ERROR' )" "0 0"
rigAssert "it makes the indices in one step: each registry is noted once, by the one operation, and the install ends once" "$( for rigName in $rigRegistries ; do rigIntCount "# DistroAgentsTools $rigOne: wrote $rigIntAgents/$rigName.registry (" ; done | LC_ALL=C tr '\n' ' ' )$( rigIntCount "$rigEarlier" ) $( rigIntCount '✅ workspace integrations installed' )" "1 1 1 1 0 1"
rigAssert "the member links come first, then the build, then what reads the indices: the permissions and the copilot access" "$( rigIntOrder )" "ordered"
rigAssert "the copilot access step made the team's own root, which did not exist when the build ran, and wrote the roots index again after it: twice in this run, and resolved in the file" \
	"$( [ -f "$rigIntWs/.local/temp/team/MAGIC.md" ] && echo made ) $( rigIntCount 'harness roots index written: .local/agents/harness.roots.index' ) $( LC_ALL=C awk -F'\t' -v root="$rigIntWs/.local/temp/team" '$2 == root && $3 == "" { n++ } END { print n + 0 }' "$rigIntAgents/harness.roots.index" )" "made 2 0"
rigIntInstalled="$( rigIntMembers )"
rigAssert "control: the install linked members, and wrote the member registry the member registries are made from" "$( [ "$rigIntInstalled" -gt 0 ] && echo members || echo "none: $rigIntInstalled" )" "members"
rigAssert "at the end of the first install the two member registries hold every member just installed, and the two session registries are there with no rows" "$( rigLines "$rigIntAgents/team-members.registry" ) $( rigLines "$rigIntAgents/team-members-names.registry" ) $( rigLines "$rigIntAgents/spawned-sessions.registry" ) $( rigLines "$rigIntAgents/pending-replies.registry" )" "$rigIntInstalled $rigIntInstalled 0 0"
rigAssert "every one of the ten files is current at the end of the first install: a build run right after changes no byte of any" "$( rigIntCurrent )" "current"
rigAssert "control: the files compared are the files of the build, nine of them there (no project of this workspace declares a grant, so no permissions registry)" "$( rigIntBytes | LC_ALL=C grep -c -v ' absent$' || : ) $( rigIntBytes | LC_ALL=C grep ' absent$' )" "9 permissions.registry absent"
## Between the install and the update a session ran and asked: the stores hold records the files do not.
mkdir -p "$rigIntAgents/spawned/s-int" "$rigIntAgents/pending"
printf -- '---\nsession-id: spawn-int\nspawn-id: spawn-int\nhost: righost\nowner: magic-coordinator\nstatus: spawn-started\n---\nbody\n' > "$rigIntAgents/spawned/s-int/spawn-int.md"
printf -- '---\nstatus: reply-pending\nsession-id: spawn-int\nowner: magic-coordinator\ncommunication-channel-id: CRIG00001\n---\nq\n' > "$rigIntAgents/pending/ask-int.md"
rigInt --make-workspace-integrations --quiet
rigAssert "a later update ends 0, with no error, makes the indices in one step, in the same order, and with no root to make writes the roots index once" "$rigRc $( rigIntCount '⛔ ERROR' ) $( rigIntCount "# DistroAgentsTools $rigOne: wrote $rigIntAgents/team-members.registry (" ) $( rigIntCount '✅ workspace integrations installed' ) $( rigIntOrder ) $( rigIntCount 'harness roots index written: .local/agents/harness.roots.index' )" "0 0 1 1 ordered 1"
rigAssert "at its end the member registries hold the members and the session registries the records of their stores" "$( rigLines "$rigIntAgents/team-members.registry" ) $( rigLines "$rigIntAgents/team-members-names.registry" ) $( rigLines "$rigIntAgents/spawned-sessions.registry" ) $( rigLines "$rigIntAgents/pending-replies.registry" )" "$rigIntInstalled $rigIntInstalled 1 1"
rigAssert "every one of the ten files is current at the end of the update" "$( rigIntCurrent )" "current"
rigIntBefore="$( rigIntBytes )"
rigInt --install-workspace-integrations
rigAssert "the install run by itself is still both of its parts, in its own order, and builds no index" "$rigRc $( rigIntCount '⛔ ERROR' ) $( rigIntCount '✅ vscode integrations installed' ) $( rigIntCount 'member index written' | LC_ALL=C sed 's/^[1-9][0-9]*$/links/' ) $( rigIntCount 'claude permissions ' ) $( rigIntCount '✅ copilot access ' ) $( rigIntCount '✅ workspace integrations installed' ) $( rigIntCount "DistroAgentsTools $rigOne" ) $( [ "$( rigIntLine '✅ vscode integrations installed' )" -lt "$( rigIntLine 'claude permissions ' )" ] && echo ordered )" "0 0 1 links 1 1 1 0 ordered"
rigAssert "and leaves the files of the build as the update left them, but the two the install writes itself, of the same bytes" "$( rigIntBytes )" "$rigIntBefore"

echo "-- 7. the build and a session's own rebuilds at once, each a process of its own --"
## Stores of some size, so that the runs overlap in their reading and their writing.
rigNo=0
while [ "$rigNo" -lt 150 ] ; do
	rigNo=$(( rigNo + 1 ))
	rigSpawn "s-many-$rigNo" "spawn-many-$rigNo"
	rigAsk "ask-many-$rigNo"
done
rigRowsOf AgentsToolsRegistrySpawnedSessionsRows "$rigTmp/want.spawned" ; rigRowsOf AgentsToolsRegistryPendingRepliesRows "$rigTmp/want.pending"
rigAtOnceFailed=0 ; rigAtOnceBroken=0 ; rigAtOnceRound=0
while [ "$rigAtOnceRound" -lt 3 ] ; do
	rigAtOnceRound=$(( rigAtOnceRound + 1 ))
	rigAtOncePids=""
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" \
		bash "$rigTool" "$rigOne" ) > "$rigTmp/at-once.$rigAtOnceRound.build.out" 2> "$rigTmp/at-once.$rigAtOnceRound.build.err" < /dev/null &
	rigAtOncePids="$rigAtOncePids $!"
	for rigAtOnceNo in 1 2 ; do
		( cd "$rigWs" && env -i HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigSkills" \
			bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.Registries.include" && AgentsToolsRegistrySpawnedSessionsRebuild && AgentsToolsRegistryPendingRepliesRebuild && AgentsToolsRegistrySpawnedSessionsRebuild && AgentsToolsRegistryPendingRepliesRebuild' ) \
			> "$rigTmp/at-once.$rigAtOnceRound.$rigAtOnceNo.out" 2> "$rigTmp/at-once.$rigAtOnceRound.$rigAtOnceNo.err" < /dev/null &
		rigAtOncePids="$rigAtOncePids $!"
	done
	for rigAtOncePid in $rigAtOncePids ; do
		wait "$rigAtOncePid" || rigAtOnceFailed=$(( rigAtOnceFailed + 1 ))
	done
	cmp -s "$rigTmp/want.spawned" "$( rigFile spawned-sessions )" && cmp -s "$rigTmp/want.pending" "$( rigFile pending-replies )" || rigAtOnceBroken=$(( rigAtOnceBroken + 1 ))
done
rigAssert "control: the stores the runs read are of some size" "$( LC_ALL=C awk 'END { print ( NR > 150 ) ? "over 150" : NR }' "$rigTmp/want.spawned" ) $( LC_ALL=C awk 'END { print ( NR > 150 ) ? "over 150" : NR }' "$rigTmp/want.pending" )" "over 150 over 150"
rigAssert "three rounds, a build and two rebuilding processes at once: every one ends 0, with no error and no warning, the rebuilding processes silent" "$rigAtOnceFailed $( rigTroubles "$rigTmp"/at-once.*.err ) $( cat "$rigTmp"/at-once.*.[12].err | LC_ALL=C awk 'END { print NR + 0 }' )" "0 0 0"
rigAssert "each build noted both session registries" "$( cat "$rigTmp"/at-once.*.build.err | LC_ALL=C grep -c -F -- "wrote $( rigFile spawned-sessions ) (" || : ) $( cat "$rigTmp"/at-once.*.build.err | LC_ALL=C grep -c -F -- "wrote $( rigFile pending-replies ) (" || : )" "3 3"
rigAssert "after every round both files are whole: byte for byte what the rows functions print for the stores" "$rigAtOnceBroken" "0"
rigAssert "and no temp name is left beside the files" "$( ls "$rigAgents" | LC_ALL=C grep -c -E -- '\.(registry|index)\.' || : )" "0"

echo "-- 8. two rebuilds of one registry from subshells of one shell: a temp file of its own for each --"
## The package's own writer, with rows of this check: the first rebuild has opened its temp file and waits; the second
## writes 2000 rows and puts its file in place; then the first writes its 3 rows. Each waits on a file the other
## makes, never on a clock. Both run in subshells of this one shell, so its process id is the same in both.
rigWriter="$rigTmp/writer" ; mkdir -p "$rigWriter/ws/.local/agents"
rigWriterFile="$rigWriter/ws/.local/agents/probe.registry"
(
	MMDAPP="$rigWriter/ws" ; export MMDAPP
	. "$rigRegInclude"
	rigWait(){ ## file -- until it is there, for half a minute at most
		local waitNo=0
		while [ ! -e "$1" ] && [ "$waitNo" -lt 150 ] ; do waitNo=$(( waitNo + 1 )) ; sleep 0.2 ; done
		[ -e "$1" ]
	}
	rigRowsSlowShort(){ : > "$rigWriter/slow.started" ; rigWait "$rigWriter/fast.done" ; LC_ALL=C awk 'BEGIN { for ( i = 1 ; i <= 3 ; i++ ) { print "short-row-" i " a b c d e f" ; } }' ; }
	rigRowsFastLong(){ LC_ALL=C awk 'BEGIN { for ( i = 1 ; i <= 2000 ; i++ ) { print "long-row-" i " a b c d e f" ; } }' ; }
	( printf '%s\n' "$$" > "$rigWriter/slow.shell" ; AgentsToolsRegistryWrite probe rigRowsSlowShort 2> "$rigWriter/slow.err" ; printf '%s\n' "$?" > "$rigWriter/slow.rc" ) &
	rigWait "$rigWriter/slow.started"
	( printf '%s\n' "$$" > "$rigWriter/fast.shell" ; AgentsToolsRegistryWrite probe rigRowsFastLong 2> "$rigWriter/fast.err" ; printf '%s\n' "$?" > "$rigWriter/fast.rc" ) &
	wait "$!"
	cp "$rigWriterFile" "$rigWriter/after-fast.copy" 2> /dev/null
	: > "$rigWriter/fast.done"
	wait
) > /dev/null 2>&1
rigAssert "control: both rebuilds ran, in subshells of one shell, and the second put its 2000 rows in place while the first waited" "$( cat "$rigWriter/slow.shell" "$rigWriter/fast.shell" 2> /dev/null | LC_ALL=C sort -u | LC_ALL=C awk 'END { print NR + 0 }' ) $( [ -e "$rigWriter/slow.started" ] && echo started ) $( rigLines "$rigWriter/after-fast.copy" )" "1 started 2000"
rigAssert "neither is a false failure: both end 0" "$( cat "$rigWriter/slow.rc" 2> /dev/null ) $( cat "$rigWriter/fast.rc" 2> /dev/null )" "0 0"
rigAssert "the file in place is whole: the rows of the rebuild that renamed last, and no line of any other shape" "$( rigLines "$rigWriterFile" ) $( LC_ALL=C grep -c -E -- '^short-row-[0-9]+ a b c d e f$' "$rigWriterFile" || : ) $( LC_ALL=C grep -c -v -E -- '^short-row-[0-9]+ a b c d e f$' "$rigWriterFile" || : )" "3 3 0"
rigAssert "and no temp file is left beside it" "$( ls "$rigWriter/ws/.local/agents" | LC_ALL=C tr '\n' ' ' )" "probe.registry "
rigWriterBody(){ ## include file, function -- that function's lines
	LC_ALL=C awk -v head="$2(){" 'index( $0, head ) == 1 { on = 1 } on { print } on && /^}/ { exit }' "$rigHere/$1"
}
rigWriterBad=""
for rigWriterAt in "AgentsTools.Registries.include AgentsToolsRegistryWrite" "AgentsTools.TeamRegistry.include AgentsToolsTeamMemberIndexWrite" "AgentsTools.Grants.include AgentsToolsGrantsIndexWrite" "AgentsTools.Grants.include AgentsToolsGrantsSessionEnsure" "AgentsHarnessHooksLoad.include AgentsHarnessHooksIndexWrite" "AgentsHarnessMcpConfig.include AgentsHarnessMcpIndexWrite" ; do
	rigWriterText="$( rigWriterBody ${rigWriterAt% *} ${rigWriterAt#* } )"
	[ "$( printf '%s\n' "$rigWriterText" | LC_ALL=C grep -c -F -- 'mktemp "' || : ) $( printf '%s\n' "$rigWriterText" | LC_ALL=C grep -v '^[[:space:]]*#' | LC_ALL=C grep -c -F -- '$$' || : )" = "1 0" ] || rigWriterBad="$rigWriterBad [$rigWriterAt]"
done
rigAssert "every writer of a registry or an index that holds no lock makes its temp name by mktemp, once, and none by the shell's process id" "${rigWriterBad:-each by mktemp}" "each by mktemp"
rigMakeArm="$( LC_ALL=C awk '/^\t--make-agents-indices\|--make-harness-indices\)/ { on = 1 } on { print } on && /^\t;;/ { exit }' "$rigMakeInclude" )"
rigAssert "and so does the one operation's own arm, for the harness's two indexes it writes itself" "$( printf '%s\n' "$rigMakeArm" | LC_ALL=C grep -c -F -- 'mktemp "' || : ) $( printf '%s\n' "$rigMakeArm" | LC_ALL=C grep -v '^[[:space:]]*#' | LC_ALL=C grep -c -F -- '$$' || : )" "1 0"
rigAssert "control: a writer that does hold a lock is found by the same reader, with its temp name as it was" "$( rigWriterBody AgentsTools.Places.include AgentsToolsPlacesSharedUpdate | LC_ALL=C grep -c -F -- 'AgentsToolsPlacesLockTake' || : ) $( rigWriterBody AgentsTools.Places.include AgentsToolsPlacesSharedUpdate | LC_ALL=C grep -c -F -- '.tmp.$$' || : )" "1 2"

echo "-- 9. one list of what to build --"
rigAssert "the registries are one list, a line each with the rebuild function of its name, in the order they are built" \
	"$( rigWriterBody AgentsTools.Registries.include AgentsToolsRegistryList | LC_ALL=C grep -E -- '^([[:space:]]*printf .* ")?[a-z-]+ AgentsToolsRegistry[A-Za-z]+Rebuild"?$' | LC_ALL=C sed -e 's/^.* "//' -e 's/"$//' | LC_ALL=C tr '\n' ' ' )" \
	"team-members AgentsToolsRegistryTeamMembersRebuild team-members-names AgentsToolsRegistryTeamMembersNamesRebuild spawned-sessions AgentsToolsRegistrySpawnedSessionsRebuild pending-replies AgentsToolsRegistryPendingRepliesRebuild "
rigAssert "the include has one writer call a registry, four in all, each from the rebuild function of that registry" \
	"$( LC_ALL=C grep -c -E -- '^[[:space:]]+AgentsToolsRegistryWrite [a-z-]+ AgentsToolsRegistry[A-Za-z]+Rows$' "$rigRegInclude" || : ) $( LC_ALL=C grep -c -F -- 'AgentsToolsRegistryWrite ' "$rigRegInclude" || : ) $( LC_ALL=C grep -c -E -- '^AgentsToolsRegistry(TeamMembers|TeamMembersNames|SpawnedSessions|PendingReplies)Rebuild\(\)\{$' "$rigRegInclude" || : )" "4 4 4"
rigAssert "both names of the operation are one arm of the make include, and no registry's name stands in that file outside the two calls of the integrations run" \
	"$( LC_ALL=C grep -c -E -- '^[[:space:]]--make-agents-indices\|--make-harness-indices\)$' "$rigMakeInclude" || : ) $( LC_ALL=C grep -c -E -- '^[[:space:]]--make-(agents|harness)-indices\)$' "$rigMakeInclude" || : ) $( LC_ALL=C grep -v -F -- "DistroAgentsTools $rigOne " "$rigMakeInclude" | LC_ALL=C grep -c -E -- 'team-members|spawned-sessions|pending-replies' || : )" "1 0 0"

echo "-- 10. the help pair --"
rigHelpInclude="$rigHere/help/Help.DistroAgentsTools.include"
rigHelpMd="$rigHere/help/Help.DistroAgentsTools.help.md"
rigEntry(){ ## operation -- its entry in the help.md, from under its heading to the next operation's
	LC_ALL=C awk -v head="$( printf '\t\t%s [<name>...]' "$1" )" '$0 == head { on = 1 ; next } on && /^\t\t--/ { exit } on { print }' "$rigHelpMd"
}
rigHelpBad=""
for rigName in "$rigOne" "$rigEarlier" ; do
	rigSyntax="📘 syntax: DistroAgentsTools.fn.sh $rigName [<name>...]"
	[ "$( LC_ALL=C grep -c -x -F -- "echo \"$rigSyntax\" >&2" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -x -F -- "$rigSyntax" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -x -F -- "$( printf '\t\t%s [<name>...]' "$rigName" )" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -F -- "syntax: DistroAgentsTools.fn.sh $rigName" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -F -- "syntax: DistroAgentsTools.fn.sh $rigName" "$rigHelpMd" || : )" = "1 1 1 1 1" ] || rigHelpBad="$rigHelpBad [$rigName]"
done
rigAssert "each of the two names has its syntax echo, its syntax line and its entry, once each, with the names it takes, and in no other form" "${rigHelpBad:-both}" "both"
rigAssert "the earlier name's entry is one line: the earlier name of the same operation" "$( rigEntry "$rigEarlier" | LC_ALL=C grep -c . || : ) $( rigEntry "$rigEarlier" | LC_ALL=C sed -e 's/^[[:space:]]*//' | LC_ALL=C grep . )" "1 The earlier name of $rigOne: the same operation."
rigAssert "the one operation's entry names every name it takes, and each of the four registry files" "$( for rigName in $rigNames ; do rigEntry "$rigOne" | LC_ALL=C grep -c -F -- "\`$rigName\`" || : ; done | LC_ALL=C tr '\n' ' ' )$( for rigName in $rigRegistries ; do rigEntry "$rigOne" | LC_ALL=C grep -c -F -- "\`$rigName.registry\`" || : ; done | LC_ALL=C tr '\n' ' ' )" "1 1 1 1 1 1 1 1 1 1 1 1 1 1 "
rigAssert "control: the entry was cut up to the next operation's heading" "$( rigEntry "$rigOne" | LC_ALL=C grep -c -F -- 'grants.index' || : ) $( rigEntry "$rigOne" | LC_ALL=C grep -c -F -- 'DistroAgentsConsole.sh' || : )" "1 0"
rigRun --help-syntax
rigAssert "--help-syntax prints both lines, once each" "$rigRc $( rigErrN "📘 syntax: DistroAgentsTools.fn.sh $rigOne [<name>...]" ) $( rigErrN "📘 syntax: DistroAgentsTools.fn.sh $rigEarlier [<name>...]" )" "0 1 1"

echo "-- 11. nothing was posted --"
rigAssert "no run of this check issued a request" "$( [ -e "$rigTmp/curl.calls" ] && wc -l < "$rigTmp/curl.calls" | LC_ALL=C tr -d ' ' || echo 0 )" "0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MAKE INDICES REGISTRIES CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MAKE_INDICES_REGISTRIES: OK (%d assertions, offline)\n' "$rigPasses"
