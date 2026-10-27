#!/usr/bin/env bash
## Behavioural check on --manager-place-list and --manager-place-read <place>, the places of this machine as the
## console's own family --manager-* shows them, run rather than read, against a rig machine built here: a HOME
## with its own pointers to the places and its own member homes, a workspace with its own registry of places, its
## consoles, its team data and its registry of sessions, a second workspace with a registry of its own, and a
## third the pointers name whose registry is not there.
## Held: the list is the merged list of the places' own reader (LocalToolsPlacesMergedText, what
## --owner-workspace-list prints), a `place` row each, in its order: the workspaces first, then the
## directories, alphabetical within each; a name two workspaces give two paths is written <name>@<workspace> for the other.
## Each row has the key, a label of the words of the key, capitalised, the kind, the ceiling, the path with its
## blanks written _, and three things measured at the call: whether the path is there and can be entered from
## here (present, unreadable, absent, unknown where no path is known), whether it is the workspace the call runs
## in, and for a workspace how many sessions of this workspace's registry of sessions, as it lies, name it. The
## read of one place prints its row as the list has it, what the registry holds of it beyond the row (who declared
## it, the workspace that declares it, the file that holds its row), and, for a place that is there, what stands
## there that the tooling knows: the consoles at its root, the members whose home it is, the team data root of
## this workspace. A name that is no place, and a wrong count of words, are refused with nothing printed. BOTH
## ONLY READ: every file of the rig is as it was, the registry of sessions is not rebuilt, and nothing is started
## that could reach another host. THE CALLER RULE of the family holds for both. And the help pair, with the row
## forms the output is checked against. Offline; only the rig's own tree is read.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigList="--manager-place-list"
rigRead="--manager-place-read"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerPlaceCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws-here" ; rigFar="$rigTmp/ws-far" ; rigLost="$rigTmp/ws-lost" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills"
rigShared="$rigHome/.agents/magic-team"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigWs/.local/agents/team-data-root" "$rigFar/.local/agents" "$rigShared" "$rigSkills" \
	"$rigTmp/docs" "$rigTmp/far-docs" "$rigTmp/closed" "$rigTmp/my notes"
rigTab="$( printf '\t' )"

## THE PLACES. This workspace's own registry: its own row, a directory a project declares, one that is not there,
## one that cannot be entered, one whose path holds a blank. The second workspace's: its own row, and a directory
## of a name this workspace has too, at another path. The pointers of the machine name them all, and a third
## workspace whose own registry is not there, with a place of its own.
{
	printf 'ws-here\tworkspace\tread-write\t%s\tworkspace\n' "$rigWs"
	printf 'docs\tdirectory\tread-only\t%s\trig/project-docs\n' "$rigTmp/docs"
	printf 'gone\tdirectory\tread-write\t%s\towner\n' "$rigTmp/gone"
	printf 'closed\tdirectory\tread-only\t%s\towner\n' "$rigTmp/closed"
	printf 'my.notes_2\tdirectory\tread-write\t%s\towner\n' "$rigTmp/my notes"
} > "$rigWs/.local/agents/directories.registry"
{
	printf 'ws-far\tworkspace\tread-write\t%s\tworkspace\n' "$rigFar"
	printf 'docs\tdirectory\tread-write\t%s\towner\n' "$rigTmp/far-docs"
} > "$rigFar/.local/agents/directories.registry"
{
	for rigOne in ws-here docs gone closed my.notes_2 ; do printf '%s\t%s\n' "$rigOne" "$rigWs" ; done
	printf 'ws-far\t%s\ndocs\t%s\n' "$rigFar" "$rigFar"
	printf 'ws-lost\t%s\nlost\t%s\n' "$rigLost" "$rigLost"
} > "$rigShared/directories.registry"
chmod 000 "$rigTmp/closed"
## Whoever runs this check as a user no mode stops enters the closed folder all the same: it then reads present.
rigClosed="unreadable" ; [ ! -r "$rigTmp/closed" ] || rigClosed="present"
## What stands at the root of this workspace: two consoles, and a file that is none. The machine's member homes.
: > "$rigWs/DistroAgentsConsole.sh" ; : > "$rigWs/DistroSourceConsole.sh" ; : > "$rigWs/NotAConsole.sh"
printf 'keeper-rig\t%s\nkeeper-far\t%s\nkeeper-two\t%s\n' "$rigWs" "$rigFar" "$rigFar" > "$rigShared/member-homes.registry"
## THE MEMBERS, as the machine's registry of members has them: who belongs to which workspace, how each is set up
## there and where its folder lies. Two belong to this workspace: one whose home the machine keeps here, one whose
## home it keeps in the second workspace. Two belong to the second: one with its home there, one the machine keeps
## no home of at all, linked from source. And in this workspace's own member set stands a folder of a member the
## registry does not know.
{
	printf 'keeper-rig\t%s\tsource-symlink\trig/skills/keeper-rig\t%s\n' "$rigWs" "$rigTmp/skill-source/keeper-rig"
	printf 'keeper-two\t%s\tlocal-copy\t-\t%s\n' "$rigWs" "$rigWs/.local/agents/members/keeper-two"
	printf 'keeper-far\t%s\tsource-declared\trig/skills/keeper-far\t%s\n' "$rigFar" "$rigTmp/skill-source/keeper-far"
	printf 'keeper-lone\t%s\tsource-symlink\trig/skills/keeper-lone\t%s\n' "$rigFar" "$rigTmp/skill-source/keeper-lone"
} > "$rigShared/members.registry"
mkdir -p "$rigWs/.local/agents/members/keeper-two" "$rigWs/.local/agents/members/odd-one"
## The registry of the sessions of this workspace, as an earlier call left it: two sessions name this workspace,
## one of them by two runs, one names the second workspace, and one names none.
{
	printf 's-one s-one - righost keeper-rig spawn-succeeded 0 sp-1 - - ws-here 2026-10-01_10:00_+0000 2026-10-01_10:30_+0000 - - -\n'
	printf 's-one s-one - righost magic-rig spawn-succeeded 0 sp-2 - - ws-here 2026-10-01_10:05_+0000 2026-10-01_10:20_+0000 - - -\n'
	printf 's-two s-two - righost keeper-rig spawn-succeeded 0 sp-3 - - ws-here 2026-10-02_10:00_+0000 2026-10-02_10:30_+0000 - - -\n'
	printf 's-three s-three - righost keeper-far spawn-succeeded 0 sp-4 - - ws-far 2026-10-03_10:00_+0000 2026-10-03_10:30_+0000 - - -\n'
	printf 's-four s-four - righost keeper-rig spawn-succeeded 0 sp-5 - - - 2026-10-04_10:00_+0000 2026-10-04_10:30_+0000 - - -\n'
} > "$rigWs/.local/agents/spawned-sessions.registry"
: > "$rigWs/.local/.agents/keeper-rig.agent.env" ; : > "$rigWs/.local/.agents/magic-team.agent.env"
chmod 770 "$rigWs/.local/.agents" ; chmod 660 "$rigWs/.local/.agents"/*.agent.env

## THE RIG'S OWN PATH: its bin, then the system's own folders. A curl and an ssh that would log a call.
for rigOne in curl ssh scp ; do
	printf '#!/bin/sh\nprintf "%%s %%s\\n" "%s" "$*" >> "%s/remote.calls"\nexit 7\n' "$rigOne" "$rigTmp" > "$rigTmp/bin/$rigOne"
	chmod +x "$rigTmp/bin/$rigOne"
done
rigPath="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigPre=()
rigRun(){ ## tool arguments... -- one dispatcher call from the rig workspace; rc in rigRc, stdout in out, stderr in err
	rigRc=0
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigPath" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigTroubles(){ ## -- how many lines of the last stderr are an error or a warning, but for the one every rig of this package gets
	LC_ALL=C grep -E -- 'ERROR|WARNING' "$rigTmp/err" | LC_ALL=C grep -c -v -F -- 'SystemContext.SetInputSpec' || :
}
rigWhole(){ ## file, text -- how many lines of the file are that text, whole
	LC_ALL=C grep -c -x -F -- "$2" "$1" 2> /dev/null || :
}
rigRefused(){ ## the one line of the refusal -- the last call: its rc, the bytes of its stdout, how many lines of its stderr are that line, and how many are an error at all
	printf '%s %s %s %s' "$rigRc" "$( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" "$( rigWhole "$rigTmp/err" "$1" )" "$( rigTroubles )"
}
rigTree(){ ## -- every file of the rig's workspaces and home, each with the sum of its bytes, and every folder, as one sum
	( cd "$rigTmp" && { find ws-here ws-far home skills docs far-docs "my notes" -type f 2> /dev/null | LC_ALL=C sort | while IFS= read -r treeFile ; do printf '%s %s\n' "$treeFile" "$( cksum < "$treeFile" )" ; done ; find ws-here ws-far home skills -type d 2> /dev/null | LC_ALL=C sort ; ls -d ws-lost gone 2>&1 ; } ) | cksum
}
rigPlace(){ ## key -- the row of that place in the last output, its TABs written as blanks
	LC_ALL=C awk -F'\t' -v wantKey="$1" '$1 == "place" && $2 == wantKey { gsub( /\t/, " " ) ; print ; }' "$rigTmp/out"
}
rigTreeBefore="$( rigTree )"

echo "-- 1. the list: one row a place, in the order of the merged list --"
rigRun "$rigList"
cp "$rigTmp/out" "$rigTmp/list"
rigAssert "the call ends 0, with no error and no warning" "$rigRc $( rigTroubles )" "0 0"
rigAssert "every row is a place row of nine fields, none empty and none with a blank" "$( LC_ALL=C awk -F'\t' '{ rows++ ; if ( $1 != "place" || NF != 9 ) bad++ ; for ( at = 1 ; at <= NF ; at++ ) if ( $at == "" || $at ~ / / ) bad++ ; } END { print rows + 0 ":" bad + 0 }' "$rigTmp/out" )" "11:0"
rigAssert "the keys come in the order of the merged list: the workspaces first, then the directories, each alphabetical; a name with another path there is written with its workspace" "$( LC_ALL=C awk -F'\t' '{ printf "%s ", $2 }' "$rigTmp/out" )" "ws-far ws-here ws-lost .skillset-.local .skillset-shared closed docs docs@ws-far gone lost my.notes_2 "
rigAssert "they are the keys --owner-workspace-list prints, in its order: the one reader of the places" "$( LC_ALL=C awk -F'\t' '{ printf "%s ", $2 }' "$rigTmp/out" )" "$( rigRun --owner-workspace-list ; LC_ALL=C awk -F'\t' '{ printf "%s ", $1 }' "$rigTmp/out" )"
cp "$rigTmp/list" "$rigTmp/out"
rigAssert "the workspace the call runs in: its label, its kind and ceiling, its path, there, the one that is here, and the two sessions of the registry that name it, one of them by two runs" "$( rigPlace ws-here )" "place ws-here Ws_Here workspace read-write $rigWs present yes 2"
rigAssert "a directory a project declares: read-only, there, not here, and no count of sessions, which name workspaces alone" "$( rigPlace docs )" "place docs Docs directory read-only $rigTmp/docs present no -"
rigAssert "a place whose path is not there reads absent, and one that cannot be entered from here reads unreadable" "$( rigPlace gone ) / $( rigPlace closed )" "place gone Gone directory read-write $rigTmp/gone absent no - / place closed Closed directory read-only $rigTmp/closed $rigClosed no -"
rigAssert "a label is the words of the key, capitalised, as many as the name allows, and a blank in a path reads _" "$( rigPlace my.notes_2 )" "place my.notes_2 My_Notes_2 directory read-write $rigTmp/my_notes present no -"
rigAssert "another workspace of this machine: there, not here, with the one session that names it; its place of a name taken here is written with its workspace" "$( rigPlace ws-far ) / $( rigPlace docs@ws-far )" "place ws-far Ws_Far workspace read-write $rigFar present no 1 / place docs@ws-far Docs_Ws_Far directory read-write $rigTmp/far-docs present no -"
rigAssert "a workspace whose own registry cannot be read is known by the pointers alone: itself as a workspace at its root, absent, with no session; its place with nothing known, unknown" "$( rigPlace ws-lost ) / $( rigPlace lost )" "place ws-lost Ws_Lost workspace read-write $rigLost absent no 0 / place lost Lost - - - unknown no -"
rigAssert "the two built-in places: the machine's skillset in HOME, not there in this rig, and the member set of this workspace" "$( rigPlace .skillset-shared ) / $( rigPlace .skillset-.local )" "place .skillset-shared Skillset_Shared directory read-write $rigHome/.claude/skills absent no - / place .skillset-.local Skillset_Local directory read-write $rigSkills present no -"
rigAssert "exactly one place is the one the call runs in" "$( LC_ALL=C awk -F'\t' '$8 == "yes" { here++ } $8 != "yes" && $8 != "no" { bad++ } END { print here + 0 ":" bad + 0 }' "$rigTmp/out" )" "1:0"
mv "$rigWs/.local/agents/spawned-sessions.registry" "$rigTmp/sessions.kept"
rigRun "$rigList"
rigAssert "where the registry of sessions is not there no count is given, and it is not built: every workspace reads -" "$rigRc $( LC_ALL=C awk -F'\t' '$4 == "workspace" { printf "%s=%s ", $2, $9 }' "$rigTmp/out" ) $( [ -e "$rigWs/.local/agents/spawned-sessions.registry" ] && echo built || echo not-built )" "0 ws-far=- ws-here=- ws-lost=-  not-built"
mv "$rigTmp/sessions.kept" "$rigWs/.local/agents/spawned-sessions.registry"
rigAssert "control: the registry of sessions names the session second and the workspace eleventh of its columns, as the tooling's own render of it says" "$( LC_ALL=C sed -n 's/^.*columns: \(tracking-name session-id .* workspace\) live state.$/\1/p' "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/team-data/AgentsTools.Registries.include" | LC_ALL=C awk '{ print $2, $11, NF }' )" "session-id workspace 11"

echo "-- 2. the read of one place --"
rigRun "$rigRead" ws-here
rigAssert "the workspace the call runs in, byte for byte: its row as the list has it, what the registry holds of it, what stands there, its consoles, the member whose home it is, the team data root, and then EVERY MEMBER THAT BELONGS TO IT by the registry of members: its kind, its home here where the machine keeps it here, how it is set up and its folder; one whose home is kept in another workspace says elsewhere; a folder of its member set that no row of the registry knows is shown, marked so" "$rigRc $( rigTroubles ) $( cat "$rigTmp/out" )" "0 0 $( {
	LC_ALL=C awk -F'\t' '$2 == "ws-here"' "$rigTmp/list"
	printf 'info\tdeclared-by\tworkspace\n'
	printf 'info\tworkspace\t%s\n' "$rigWs"
	printf 'info\tregistry\t%s\n' "$rigWs/.local/agents/directories.registry"
	printf 'stands\tconsole\tDistroAgentsConsole.sh\t%s\n' "$rigWs/DistroAgentsConsole.sh"
	printf 'stands\tconsole\tDistroSourceConsole.sh\t%s\n' "$rigWs/DistroSourceConsole.sh"
	printf 'stands\tmember-home\tkeeper-rig\t%s\n' "$rigWs"
	printf 'stands\tteam-data-root\t-\t%s\n' "$rigWs/.local/agents/team-data-root"
	printf 'member\tkeeper-rig\tkeeper\t%s\tsource-symlink\t%s\n' "$rigWs" "$rigTmp/skill-source/keeper-rig"
	printf 'member\tkeeper-two\tkeeper\telsewhere\tlocal-copy\t%s\n' "$rigWs/.local/agents/members/keeper-two"
	printf 'member\todd-one\todd\t-\tnot-in-registry\t%s\n' "$rigWs/.local/agents/members/odd-one"
} )"
rigRun "$rigRead" docs
rigAssert "a directory: its row, the project that declares it, the workspace and the file that hold its row, and nothing the tooling knows of stands there" "$rigRc $( cat "$rigTmp/out" )" "0 $( {
	LC_ALL=C awk -F'\t' '$2 == "docs"' "$rigTmp/list"
	printf 'info\tdeclared-by\trig/project-docs\n'
	printf 'info\tworkspace\t%s\n' "$rigWs"
	printf 'info\tregistry\t%s\n' "$rigWs/.local/agents/directories.registry"
} )"
rigRun "$rigRead" docs@ws-far
rigAssert "a place of another workspace by its key: declared by the owner there, and its row stands in that workspace's file" "$rigRc $( cat "$rigTmp/out" )" "0 $( {
	LC_ALL=C awk -F'\t' '$2 == "docs@ws-far"' "$rigTmp/list"
	printf 'info\tdeclared-by\towner\n'
	printf 'info\tworkspace\t%s\n' "$rigFar"
	printf 'info\tregistry\t%s\n' "$rigFar/.local/agents/directories.registry"
} )"
rigRun "$rigRead" ws-far
rigAssert "another workspace: the members whose home the machine keeps there stand there, one of them a member that belongs to this workspace, and no console, since none is at its root" "$rigRc $( LC_ALL=C awk -F'\t' '$1 == "stands" { gsub( /\t/, " " ) ; printf "%s/", $0 }' "$rigTmp/out" )" "0 stands member-home keeper-far $rigFar/stands member-home keeper-two $rigFar/"
rigRun "$rigRead" ws-far
rigAssert "a workspace shows a member that belongs to it though the machine has no row for its home and it has no folder there: it is linked from source there, so that workspace is its home, as it is of the one the machine has a row for" "$rigRc $( LC_ALL=C awk -F'\t' '$1 == "member" { gsub( /\t/, " " ) ; printf "%s/", $0 }' "$rigTmp/out" )" "0 member keeper-far keeper $rigFar source-declared $rigTmp/skill-source/keeper-far/member keeper-lone keeper $rigFar source-symlink $rigTmp/skill-source/keeper-lone/"
rigRun "$rigRead" docs
rigAssert "a place that is no workspace has no member" "$rigRc $( LC_ALL=C grep -c -e '^member' "$rigTmp/out" || : )" "0 0"
rigRun "$rigRead" .skillset-.local
rigAssert "a built-in place is no row of a registry: declared by none, for this workspace, in no file" "$rigRc $( LC_ALL=C awk -F'\t' '$1 != "place" { gsub( /\t/, " " ) ; printf "%s/", $0 }' "$rigTmp/out" )" "0 info declared-by built-in/info workspace $rigWs/info registry -/"
rigRun "$rigRead" gone
rigAssert "of a place that is not there only what the registry holds is shown: nothing is looked for at its path" "$rigRc $( LC_ALL=C awk -F'\t' '{ printf "%s ", $1 }' "$rigTmp/out" )" "0 place info info info "
rigRun "$rigRead" lost
rigAssert "of a place known by the pointers alone: its row, and the workspace that would declare it" "$rigRc $( LC_ALL=C awk -F'\t' '$1 != "place" { gsub( /\t/, " " ) ; printf "%s/", $0 }' "$rigTmp/out" )" "0 info declared-by -/info workspace $rigLost/info registry $rigLost/.local/agents/directories.registry/"
rigRun "$rigRead" my.notes_2
rigAssert "every row of a read has the fields of its kind, none empty and none with a blank" "$( for rigOne in ws-here my.notes_2 lost ; do rigRun "$rigRead" "$rigOne" ; LC_ALL=C awk -F'\t' '{ want = ( $1 == "place" ) ? 9 : ( $1 == "info" ) ? 3 : ( $1 == "stands" ) ? 4 : ( $1 == "member" ) ? 6 : -1 ; if ( NF != want ) bad++ ; for ( at = 1 ; at <= NF ; at++ ) if ( $at == "" || $at ~ / / ) bad++ ; } END { printf "%s:%s ", ( NR > 3 ? "rows" : "few" ), bad + 0 }' "$rigTmp/out" ; done )" "rows:0 rows:0 rows:0 "

echo "-- 3. what is refused --"
rigRun "$rigRead" nonesuch
rigAssert "a name that is no place: rc 1, nothing on stdout, one line that says where the places are listed" "$( rigRefused "⛔ ERROR: DistroAgentsTools $rigRead: no place is named 'nonesuch' -- nothing is shown. The places are those $rigList prints" )" "1 0 1 1"
rigRun "$rigRead" docs@nonesuch
rigAssert "and a name with a workspace that has no such place" "$( rigRefused "⛔ ERROR: DistroAgentsTools $rigRead: no place is named 'docs@nonesuch' -- nothing is shown. The places are those $rigList prints" )" "1 0 1 1"
rigRun "$rigRead" "../etc/passwd"
rigAssert "a word that is no name of a place is refused without being repeated" "$( rigRefused "⛔ ERROR: DistroAgentsTools $rigRead: syntax is $rigRead <place>, and the word given is no name of a place -- nothing is shown" ) $( LC_ALL=C grep -c -F -e 'passwd' "$rigTmp/err" || : )" "1 0 1 1 0"
rigRun "$rigRead"
rigAssert "no word, and a second word, are refused with the syntax" "$( rigRefused "⛔ ERROR: DistroAgentsTools $rigRead: syntax is $rigRead <place>, got 0 argument(s) -- nothing is shown" ) / $( rigRun "$rigRead" docs gone ; rigRefused "⛔ ERROR: DistroAgentsTools $rigRead: syntax is $rigRead <place>, got 2 argument(s) -- nothing is shown" )" "1 0 1 1 / 1 0 1 1"
rigRun "$rigList" docs
rigAssert "the list takes no word" "$( rigRefused "⛔ ERROR: DistroAgentsTools $rigList: syntax is $rigList, got 1 argument(s) -- nothing is shown" )" "1 0 1 1"

echo "-- 4. both only read, and reach no other host --"
rigAssert "no call so far wrote, made or removed a file or a folder of the rig: its workspaces, their registries, the registry of sessions, the home" "$( rigTree )" "$rigTreeBefore"
rigAssert "no call started anything that reaches another host" "$( [ -e "$rigTmp/remote.calls" ] && wc -l < "$rigTmp/remote.calls" | LC_ALL=C tr -d ' ' || echo 0 )" "0"
rigInclude="$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/manager/LocalTools.ManagerPlace.include"
rigAssert "the places are read by their own reader, the merged list, and the include opens no registry of places itself and names no writer of one" "$( LC_ALL=C grep -v '^[[:space:]]*#' "$rigInclude" | LC_ALL=C grep -c -e 'LocalToolsPlacesMergedText "' || : ) $( LC_ALL=C grep -v '^[[:space:]]*#' "$rigInclude" | LC_ALL=C grep -c -e 'directories\.registry' -e 'LocalToolsPlacesLocalUpdate' -e 'LocalToolsPlacesSharedUpdate' -e 'LocalToolsPlacesOwner' || : )" "1 0"

echo "-- 5. the caller rule of the family, and its place in it --"
rigCallerBad=""
for rigOne in "$rigList" "$rigRead docs" ; do
	rigPre=( "MDAT_SPAWN_AGENT=keeper-rig" )
	# shellcheck disable=SC2086
	rigRun $rigOne
	rigPre=()
	[ "$rigRc" = 1 ] && [ ! -s "$rigTmp/out" ] && [ "$( rigWhole "$rigTmp/err" "DistroAgentsTools: $( printf '%s' "${rigOne%% *}" | LC_ALL=C sed -e 's/^--//' ): ⛔ ERROR: this session acts as keeper-rig, and a --manager-* operation is the console's own, never run from inside a member's session -- nothing was done" )" = 1 ] || rigCallerBad="$rigCallerBad [${rigOne%% *}]"
done
rigAssert "from inside a member's session both are refused, rc 1, nothing on stdout, in the one line of the family" "${rigCallerBad:-each refused}" "each refused"
rigAssert "the family's include has one arm for the places, which sources their include" "$( LC_ALL=C grep -c -x -e '	--manager-place-\*)' "$rigHere/manager/AgentsTools.Manager.include" || : ) $( LC_ALL=C grep -c -F -e '. "$MDLT_ORIGIN/myx/myx.distro-.local/sh-lib/manager/LocalTools.ManagerPlace.include"' "$rigHere/manager/AgentsTools.Manager.include" || : )" "1 1"
rigRun --manager-place-no-such
rigAssert "an operation its subject does not have is refused by name, rc 1" "$rigRc $( rigWhole "$rigTmp/err" "DistroAgentsTools: ⛔ ERROR: invalid option: --manager-place-no-such" )" "1 1"

echo "-- 6. the help pair --"
rigHelpInclude="$rigHere/help/Help.DistroAgentsTools.include"
rigHelpMd="$rigHere/help/Help.DistroAgentsTools.help.md"
rigEntry(){ ## heading -- that operation's entry in the help.md, from under its heading to the next operation's
	LC_ALL=C awk -v head="$( printf '\t\t%s' "$1" )" '$0 == head { on = 1 ; next } on && /^\t\t--/ { exit } on { print }' "$rigHelpMd"
}
rigForm(){ ## heading, row kind -- the form line of that row in that entry, its back quotes and its indent taken off
	rigEntry "$1" | LC_ALL=C sed -n -e 's/^[[:space:]]*`\('"$2"' <.*>\)`$/\1/p'
}
rigPairBad=""
for rigOne in "$rigList" "$rigRead <place>" ; do
	rigSyntax="📘 syntax: DistroAgentsTools.fn.sh $rigOne"
	[ "$( LC_ALL=C grep -c -x -F -- "echo \"$rigSyntax\" >&2" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -x -F -- "$rigSyntax" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -x -F -- "$( printf '\t\t%s' "$rigOne" )" "$rigHelpMd" || : )" = "1 1 1" ] || rigPairBad="$rigPairBad [$rigOne]"
done
rigAssert "each of the two has its syntax echo, its syntax line and its entry, once each" "${rigPairBad:-each once}" "each once"
rigAssert "the entry of the list gives the form of its row, and the entry of the read those of its two own rows" "$( rigForm "$rigList" place ) | $( rigForm "$rigRead <place>" info ) | $( rigForm "$rigRead <place>" stands )" "place <place> <label> <kind> <ceiling> <path> <state> <here> <sessions> | info <name> <value> | stands <what> <name> <path>"
rigAssert "the entry of the read gives the form of a member's row" "$( rigForm "$rigRead <place>" member )" "member <member> <kind> <home> <setup> <folder>"
rigAssert "and every row the two print has exactly the fields its form names" "$( LC_ALL=C awk -F'\t' -v wantFields="$( rigForm "$rigList" place | LC_ALL=C awk '{ print NF }' )" '{ rows++ ; if ( NF != wantFields ) bad++ ; } END { printf "%s:%s ", ( rows > 0 ? "rows" : "none" ), bad + 0 }' "$rigTmp/list" ; rigRun "$rigRead" ws-here ; for rigOne in info stands ; do LC_ALL=C awk -F'\t' -v wantKind="$rigOne" -v wantFields="$( rigForm "$rigRead <place>" "$rigOne" | LC_ALL=C awk '{ print NF }' )" '$1 == wantKind { rows++ ; if ( NF != wantFields ) bad++ ; } END { printf "%s:%s ", ( rows > 0 ? "rows" : "none" ), bad + 0 }' "$rigTmp/out" ; done )" "rows:0 rows:0 rows:0 "
rigAssert "the entry of the list names the four states, says that the registry holds no host, and that the call only reads" "$( for rigWord in present unreadable absent unknown ; do rigEntry "$rigList" | LC_ALL=C grep -c -F -- "\`$rigWord\`" | LC_ALL=C awk '{ printf "%s", ( $1 > 0 ) ? "y" : "n" }' ; done ) $( rigEntry "$rigList" | LC_ALL=C tr -s ' \t\n' ' ' | LC_ALL=C grep -c -F -e 'holds no host' || : ) $( rigEntry "$rigList" | LC_ALL=C tr -s ' \t\n' ' ' | LC_ALL=C grep -c -F -e 'It only reads' || : )" "yyyy 1 1"
rigRun --help-syntax
rigAssert "--help-syntax prints both lines, once each" "$rigRc $( LC_ALL=C grep -c -x -F -- "📘 syntax: DistroAgentsTools.fn.sh $rigList" "$rigTmp/err" || : ) $( LC_ALL=C grep -c -x -F -- "📘 syntax: DistroAgentsTools.fn.sh $rigRead <place>" "$rigTmp/err" || : )" "0 1 1"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MANAGER PLACE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_PLACE: OK (%d assertions, offline)\n' "$rigPasses"
