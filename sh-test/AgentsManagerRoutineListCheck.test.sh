#!/usr/bin/env bash
## Behavioural check on --manager-routine-list, the operation of the console's own family --manager-* that lists the
## routines the members carry, run rather than read, against a rig machine built here: a workspace with its own member
## folders, a second workspace whose one member the machine's members index names, and routine files of every kind
## among them. Held: the whole output, byte for byte -- one `routine` row a routine file of every member's folder, a
## member of another workspace of the machine among them, with its selector, its owner, whether it can be started,
## its executors, whether it is coworking-like, the place of its arguments, its title, the reason where it cannot
## be started, and last what a start of it needs where that is all it lacks; the rows by owner, then by selector. THE
## RULE IT PRINTS IS THE SESSION SPAWNER'S: a routine reads startable exactly where --magic-spawn-session, given its
## file name and no member, starts it -- asked of the spawner itself, row by row, with a stand-in console; and one
## whose row says that it needs members is started by that operation with two members named, in one session, while
## a wrong name among them starts nobody. A plain comma-separated list of existing members is startable, inner
## whitespace and a member of another workspace included; `magic-team`, `*`, prose, a name no workspace holds and a
## list with an empty place are not, each with its reason and the name in it; a file with no frontmatter block, or
## with no executors or no maintainers, is listed as broken and never left out; a file whose name is part of another
## routine file's name cannot be selected by it. The folder `trash`, a folder named like a routine file and a file
## that is no routine are no rows. The call reads only: no file of the machine changes. The caller rule of the family
## holds for it, its place in the family is one arm and one include, and its help pair gives the form the output is
## checked against. A fake `curl` first on PATH logs each request: the list makes none. Offline; only the rig's own
## tree is read or written, and no real CLI is started.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigPackage="${rigHere%/sh-lib}"
rigTest="$rigPackage/sh-test"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigOp="--manager-routine-list"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
## A spawn of this rig that is not waited for starts the control thread of its session, a detached process that
## outlives this check: the rig ends it, before its tree is removed (the guard is in AgentsSessionControlStartCheck).
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerRoutineListCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp" 2> /dev/null || { sleep 3 ; rm -rf -- "$rigTmp" 2> /dev/null ; }' EXIT
rigWs="$rigTmp/ws-here" ; rigFar="$rigTmp/ws-far" ; rigHome="$rigTmp/home" ; rigData="$rigTmp/data"
rigSkills="$rigWs/.local/agents/members"
rigFarMember="$rigFar/source/myx/pkg/skillset/keeper-far"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigSkills" "$rigFar/.local/.agents" "$rigFar/.local/agents/members/magic-team" "$rigFarMember" "$rigHome/.agents/magic-team" "$rigData/board"
cp "$rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package: $rigTest/check-fixtures/slack-send-identity-check.curl.stub.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"
rigTab="$( printf '\t' )"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

## THE RIG MACHINE. ws-here is the workspace the console is in: its member set view holds its own members as folders.
## ws-far holds keeper-far, which the machine's members index names, and which ws-here's view does not hold.
rigMember(){ ## folder -- the files a start of that member reads; the folder's name is the member's
	mkdir -p "$1"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$1/${1##*/}.basic.md"
	printf '# rig armed\n' > "$1/${1##*/}.armed.md"
}
rigRoutine(){ ## folder, file name, frontmatter lines ("" for no frontmatter block), title line ("" for none)
	{
		[ -z "$3" ] || printf -- '---\n%s\n---\n' "$3"
		[ -z "$4" ] || printf '%s\n' "$4"
		printf '\n# Summary\n\nrig routine fixture\n'
	} > "$1/$2"
}
rigTitled(){ ## folder, file name, frontmatter lines -- a routine with the title line the routine contract gives it
	rigRoutine "$1" "$2" "$3" "# ${2%.md} — the actual procedure"
}
for rigMemberName in keeper-rig magic-coordinator magic-team human-owner ; do rigMember "$rigSkills/$rigMemberName" ; done
## An identity record and no acting member: its SKILL.md says so.
printf -- '---\nname: human-owner\nstatus: reference-only\n---\n\n# human-owner\n' > "$rigSkills/human-owner/SKILL.md"
rigMember "$rigFarMember"
ln -s "$rigFarMember" "$rigFar/.local/agents/members/keeper-far"
rigTitled "$rigSkills/keeper-rig" keeper-rig.alpha.routine.md "$( printf 'executors: keeper-rig\nmaintainers: keeper-rig\nrequires-session-kind: standalone' )"
rigTitled "$rigSkills/keeper-rig" keeper-rig.pair.routine.md "$( printf 'executors: keeper-rig,  magic-coordinator\nmaintainers: keeper-rig\nrequires-session-kind: coworking' )"
rigTitled "$rigSkills/keeper-rig" keeper-rig.wild.routine.md "$( printf 'executors: magic-team\nmaintainers: magic-coordinator\nrequires-session-kind: standalone' )"
rigTitled "$rigSkills/keeper-rig" keeper-rig.ghost.routine.md "$( printf 'executors: keeper-rig, keeper-gone\nmaintainers: keeper-rig\nrequires-session-kind: standalone' )"
rigTitled "$rigSkills/keeper-rig" keeper-rig.far.routine.md "$( printf 'executors: keeper-far\nmaintainers: keeper-rig\nrequires-session-kind: standalone' )"
rigTitled "$rigSkills/keeper-rig" keeper-rig.owner.routine.md "$( printf 'executors: keeper-rig, human-owner\nmaintainers: keeper-rig\nrequires-session-kind: standalone' )"
rigTitled "$rigSkills/keeper-rig" x.routine.md ""
rigTitled "$rigSkills/magic-coordinator" magic-coordinator.daily.routine.md "$( printf 'executors: magic-coordinator\nmaintainers: magic-coordinator, human-owner\ninvitees: magic-team\nrequires-session-kind: coworking' )"
rigTitled "$rigSkills/magic-coordinator" magic-coordinator.star.routine.md "$( printf 'executors: *\nmaintainers: magic-coordinator\nrequires-session-kind: standalone' )"
rigTitled "$rigSkills/magic-coordinator" magic-coordinator.prose.routine.md "$( printf 'executors: the coordinator and friends\nmaintainers: magic-coordinator\nrequires-session-kind: standalone' )"
rigTitled "$rigSkills/magic-coordinator" magic-coordinator.nomaint.routine.md "$( printf 'executors: magic-coordinator\nrequires-session-kind: standalone' )"
rigTitled "$rigSkills/magic-coordinator" magic-coordinator.noexec.routine.md "$( printf 'maintainers: magic-coordinator\nrequires-session-kind: standalone' )"
rigTitled "$rigSkills/magic-coordinator" magic-coordinator.hole.routine.md "$( printf 'executors: magic-coordinator,,keeper-rig\nmaintainers: magic-coordinator\nrequires-session-kind: standalone' )"
rigTitled "$rigSkills/magic-team" magic-team.coworking.routine.md "$( printf 'executors: magic-coordinator\nmaintainers: magic-coordinator\ninvitees: magic-team\nrequires-session-kind: coworking' )"
## A file whose whole name is the end of another routine file's name, and which has no title line.
rigRoutine "$rigSkills/magic-team" alpha.routine.md "$( printf 'executors: magic-coordinator\nmaintainers: magic-coordinator\nrequires-session-kind: standalone' )" ""
rigTitled "$rigFarMember" keeper-far.remote.routine.md "$( printf 'executors: keeper-far\nmaintainers: keeper-far\nrequires-session-kind: standalone' )"
## What is no row: the folder `trash`, a folder named like a routine file, a file that is no routine.
mkdir -p "$rigSkills/trash" "$rigSkills/keeper-rig/folder.routine.md"
rigTitled "$rigSkills/trash" trash.old.routine.md "$( printf 'executors: keeper-rig\nmaintainers: keeper-rig\nrequires-session-kind: standalone' )"
printf -- '---\nexecutors: keeper-rig\nmaintainers: keeper-rig\n---\n# not a routine file\n' > "$rigSkills/keeper-rig/keeper-rig.routine.notes.md"
## The machine's members index, and the workspaces the machine knows.
{
	printf '%s\t%s\tsource-symlink\t%s\t%s\n' keeper-rig "$rigWs" myx/pkg/skillset/keeper-rig "$rigSkills/keeper-rig"
	printf '%s\t%s\tsource-symlink\t%s\t%s\n' keeper-far "$rigFar" myx/pkg/skillset/keeper-far "$rigFarMember"
} > "$rigHome/.agents/magic-team/members.registry"
printf 'ws-here\t%s\nws-far\t%s\n' "$rigWs" "$rigFar" > "$rigHome/.agents/magic-team/directories.registry"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
## The console a start runs: it records which member it was started as, and hands back.
printf '%s\n' '#!/usr/bin/env bash' \
	'## --cli-configured stand-in: writes MDAT_SPAWN_LAUNCH_MARKER and records who was started.' \
	'cat > /dev/null' \
	'printf "%s\n" "$MDAT_SPAWN_AGENT" >> "$RIG_SCENARIO/started"' \
	'printf "📦 SubagentHandback\n"' \
	'printf "rig-cli\n" > "$MDAT_SPAWN_LAUNCH_MARKER"' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"

rigPre=()
rigRun(){ ## tool arguments... -- one dispatcher call from the rig workspace, as a console makes it; rc in rigRc, stdout in out, stderr in err
	rigRc=0
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigStart(){ ## selector, then the members named, if any -- the session spawner asked to start that routine, a task text on stdin; rc in rigRc, stdout in start.out, stderr in start.err
	rigRc=0
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$PATH" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_SCENARIO="$rigTmp" \
		bash "$rigTool" --magic-spawn-session --routine "$@" ) > "$rigTmp/start.out" 2> "$rigTmp/start.err" <<< "RIG-TASK-TEXT" || rigRc=$?
}
rigRowOf(){ ## selector -- that routine's row in the last output, TAB written as a space
	LC_ALL=C awk -F'\t' -v wantName="$1" '$1 == "routine" && $2 == wantName { gsub( /\t/, " " ) ; print ; }' "$rigTmp/out"
}
rigTroubles(){ ## -- how many lines of the last stderr are an error or a warning, but for the one every rig of this package gets
	LC_ALL=C grep -E -- 'ERROR|WARNING' "$rigTmp/err" | LC_ALL=C grep -c -v -F -- 'SystemContext.SetInputSpec' || :
}
rigWhole(){ ## file, text -- how many lines of the file are that text, whole
	LC_ALL=C grep -c -x -F -- "$2" "$1" 2> /dev/null || :
}
rigMachine(){ ## -- every file of the rig machine, each with the sum of its bytes, as one sum
	( cd "$rigTmp" && find ws-here ws-far home data -type f | LC_ALL=C sort | while IFS= read -r machineFile ; do printf '%s %s\n' "$machineFile" "$( cksum < "$machineFile" )" ; done ) | cksum
}
rigWantRow(){ ## selector, owner, start, executors, session, title, reason, what a start of it needs where it needs anything -- a row as the operation prints it
	printf 'routine\t%s\t%s\t%s\t%s\t%s\t-\t%s\t%s\t%s\n' "$1" "$2" "$3" "$4" "$5" "$6" "$7" "${8:--}"
}
rigTitleOf(){ ## file name -- its title line as a row carries it
	printf '%s_—_the_actual_procedure' "${1%.md}"
}

echo "-- 1. the whole list: one row a routine file, by owner, then by selector --"
rigMachineBefore="$( rigMachine )"
rigRun "$rigOp"
rigAny="the session spawner starts it only with members named"
rigWant="$( {
	rigWantRow keeper-far.remote.routine.md keeper-far startable keeper-far - "$( rigTitleOf keeper-far.remote.routine.md )" -
	rigWantRow keeper-rig.alpha.routine.md keeper-rig startable keeper-rig - "$( rigTitleOf keeper-rig.alpha.routine.md )" -
	rigWantRow keeper-rig.far.routine.md keeper-rig startable keeper-far - "$( rigTitleOf keeper-rig.far.routine.md )" -
	rigWantRow keeper-rig.ghost.routine.md keeper-rig not-startable keeper-rig,_keeper-gone - "$( rigTitleOf keeper-rig.ghost.routine.md )" its_executor_keeper-gone_is_no_member_of_any_workspace_of_this_machine
	rigWantRow keeper-rig.owner.routine.md keeper-rig not-startable keeper-rig,_human-owner - "$( rigTitleOf keeper-rig.owner.routine.md )" its_executor_human-owner_is_an_identity_record,_which_is_never_started
	rigWantRow keeper-rig.pair.routine.md keeper-rig startable keeper-rig,_magic-coordinator coworking "$( rigTitleOf keeper-rig.pair.routine.md )" -
	rigWantRow keeper-rig.wild.routine.md keeper-rig not-startable magic-team - "$( rigTitleOf keeper-rig.wild.routine.md )" "its_executors,_magic-team,_is_any_member:_${rigAny// /_}" members
	rigWantRow x.routine.md keeper-rig broken - - "$( rigTitleOf x.routine.md )" does_not_open_with_a_frontmatter_block
	rigWantRow magic-coordinator.daily.routine.md magic-coordinator startable magic-coordinator coworking "$( rigTitleOf magic-coordinator.daily.routine.md )" -
	rigWantRow magic-coordinator.hole.routine.md magic-coordinator not-startable magic-coordinator,,keeper-rig - "$( rigTitleOf magic-coordinator.hole.routine.md )" its_executors_holds_an_empty_name
	rigWantRow magic-coordinator.noexec.routine.md magic-coordinator broken - - "$( rigTitleOf magic-coordinator.noexec.routine.md )" executors_and_maintainers_must_both_be_non-empty
	rigWantRow magic-coordinator.nomaint.routine.md magic-coordinator broken - - "$( rigTitleOf magic-coordinator.nomaint.routine.md )" executors_and_maintainers_must_both_be_non-empty
	rigWantRow magic-coordinator.prose.routine.md magic-coordinator not-startable the_coordinator_and_friends - "$( rigTitleOf magic-coordinator.prose.routine.md )" its_executor_the_coordinator_and_friends_is_no_member_of_any_workspace_of_this_machine
	rigWantRow magic-coordinator.star.routine.md magic-coordinator not-startable '*' - "$( rigTitleOf magic-coordinator.star.routine.md )" "its_executors,_*,_is_any_member:_${rigAny// /_}" members
	rigWantRow alpha.routine.md magic-team not-startable magic-coordinator - - more_than_one_routine_file_answers_to_its_name,_so_the_session_spawner_cannot_select_it
	rigWantRow magic-team.coworking.routine.md magic-team startable magic-coordinator coworking "$( rigTitleOf magic-team.coworking.routine.md )" -
} )"
rigAssert "the call ends 0, with no error and no warning" "$rigRc $( rigTroubles )" "0 0"
rigAssert "the whole output, byte for byte: one row a routine file of every member's folder, by owner, then by selector" "$( cat "$rigTmp/out" )" "$rigWant"
cp "$rigTmp/out" "$rigTmp/list.kept"
rigAssert "a routine with a plain list of executors reads startable, with no reason: one member, and a list of two with whitespace between them" \
	"$( rigRowOf keeper-rig.alpha.routine.md | LC_ALL=C awk '{ print $4, $5, $9 }' ) | $( rigRowOf keeper-rig.pair.routine.md | LC_ALL=C awk '{ print $4, $5, $9 }' )" "startable keeper-rig - | startable keeper-rig,_magic-coordinator -"
rigAssert "a routine whose executors is magic-team reads not startable, and its row says why: any member, so members must be named" \
	"$( rigRowOf keeper-rig.wild.routine.md | LC_ALL=C awk '{ print $4, $5, $9 }' )" "not-startable magic-team its_executors,_magic-team,_is_any_member:_the_session_spawner_starts_it_only_with_members_named"
rigAssert "so does one whose executors is *, and one whose executors is prose, which names no member" \
	"$( rigRowOf magic-coordinator.star.routine.md | LC_ALL=C awk '{ print $4 }' ) $( rigRowOf magic-coordinator.prose.routine.md | LC_ALL=C awk '{ print $4 }' )" "not-startable not-startable"
rigAssert "a routine whose executor no workspace of the machine holds reads not startable, and its row names that executor" \
	"$( rigRowOf keeper-rig.ghost.routine.md | LC_ALL=C awk '{ print $4, $9 }' )" "not-startable its_executor_keeper-gone_is_no_member_of_any_workspace_of_this_machine"
rigAssert "a routine whose executors name an identity record, a member whose SKILL.md says status: reference-only, reads not startable, and its row names that executor" \
	"$( LC_ALL=C grep -c -x 'status: reference-only' "$rigSkills/human-owner/SKILL.md" ) $( rigRowOf keeper-rig.owner.routine.md | LC_ALL=C awk '{ print $4, $5, $9 }' )" "1 not-startable keeper-rig,_human-owner its_executor_human-owner_is_an_identity_record,_which_is_never_started"
rigAssert "control: keeper-gone is a member of no workspace of the rig machine, and keeper-far is one of another workspace than this one" \
	"$( LC_ALL=C grep -c -e '^keeper-gone' "$rigHome/.agents/magic-team/members.registry" || : ) $( [ -e "$rigSkills/keeper-gone" ] && echo here ) $( LC_ALL=C grep -c -e '^keeper-far' "$rigHome/.agents/magic-team/members.registry" || : ) $( [ -e "$rigSkills/keeper-far" ] && echo here )" "0  1 "
rigAssert "an executor that is a member of another workspace of the machine is an existing member: its routine reads startable" \
	"$( rigRowOf keeper-rig.far.routine.md | LC_ALL=C awk '{ print $4, $5 }' )" "startable keeper-far"
rigAssert "and the routines that member carries in its own workspace are rows, under it as their owner" \
	"$( rigRowOf keeper-far.remote.routine.md | LC_ALL=C awk '{ print $3, $4 }' )" "keeper-far startable"
rigAssert "a routine file with no frontmatter block is not left out: it has a row, which reads broken and says so" \
	"$( head -1 "$rigSkills/keeper-rig/x.routine.md" | LC_ALL=C cut -c1-3 ) $( rigRowOf x.routine.md | LC_ALL=C awk '{ print $4, $9 }' )" "# x broken does_not_open_with_a_frontmatter_block"
rigAssert "a file that names no executors, and one that names no maintainers, read broken too, in the words of the routine contract check" \
	"$( rigRowOf magic-coordinator.noexec.routine.md | LC_ALL=C awk '{ print $4, $9 }' ) | $( rigRowOf magic-coordinator.nomaint.routine.md | LC_ALL=C awk '{ print $4, $9 }' )" "broken executors_and_maintainers_must_both_be_non-empty | broken executors_and_maintainers_must_both_be_non-empty"
rigAssert "a file whose name is part of another routine file's name cannot be selected by it, and the longer name can" \
	"$( rigRowOf alpha.routine.md | LC_ALL=C awk '{ print $4 }' ) $( rigRowOf keeper-rig.alpha.routine.md | LC_ALL=C awk '{ print $4 }' )" "not-startable startable"
rigAssert "the rows come by the name of the member, then by the name of the file: four owners, and the seven files of one in order" \
	"$( LC_ALL=C awk -F'\t' '$3 != last { printf "%s ", $3 ; last = $3 }' "$rigTmp/out" )/ $( LC_ALL=C awk -F'\t' '$3 == "keeper-rig" { printf "%s ", $2 }' "$rigTmp/out" )" \
	"keeper-far keeper-rig magic-coordinator magic-team / keeper-rig.alpha.routine.md keeper-rig.far.routine.md keeper-rig.ghost.routine.md keeper-rig.owner.routine.md keeper-rig.pair.routine.md keeper-rig.wild.routine.md x.routine.md "
rigAssert "the rows are sorted as sort(1) sorts them by owner, then by selector, and every row has ten fields" \
	"$( LC_ALL=C sort -c -t "$rigTab" -k3,3 -k2,2 "$rigTmp/out" 2> /dev/null && echo sorted || echo unsorted ) $( LC_ALL=C awk -F'\t' 'NF != 10 || $1 != "routine" { bad++ } END { print NR ":" bad + 0 }' "$rigTmp/out" )" "sorted 16:0"
rigAssert "the last field says what a start of the routine needs: members, for one whose executors is any member, and nothing for every other, one that is not startable for another reason too" \
	"$( LC_ALL=C awk -F'\t' '$10 == "members" { printf "%s ", $2 }' "$rigTmp/out" )/ $( LC_ALL=C awk -F'\t' '$10 != "members" && $10 != "-" { n++ } END { print n + 0 }' "$rigTmp/out" ) $( rigRowOf keeper-rig.ghost.routine.md | LC_ALL=C awk '{ print $4, $10 }' ) $( rigRowOf keeper-rig.alpha.routine.md | LC_ALL=C awk '{ print $4, $10 }' )" \
	"keeper-rig.wild.routine.md magic-coordinator.star.routine.md / 0 not-startable - startable -"
rigAssert "a coworking-like routine says so, and no other does" \
	"$( LC_ALL=C awk -F'\t' '$6 == "coworking" { printf "%s ", $2 }' "$rigTmp/out" )/ $( LC_ALL=C awk -F'\t' '$6 != "coworking" && $6 != "-" { n++ } END { print n + 0 }' "$rigTmp/out" )" \
	"keeper-rig.pair.routine.md magic-coordinator.daily.routine.md magic-team.coworking.routine.md / 0"
rigAssert "the title is the file's own title line, and a file with none shows -" "$( rigRowOf keeper-rig.alpha.routine.md | LC_ALL=C awk '{ print $8 }' ) $( rigRowOf alpha.routine.md | LC_ALL=C awk '{ print $8 }' )" "keeper-rig.alpha.routine_—_the_actual_procedure -"
rigAssert "the place of the arguments is there, and reads - for every routine: no file of the rig says it takes any" "$( LC_ALL=C awk -F'\t' '$7 != "-" { n++ } END { print n + 0 }' "$rigTmp/out" )" "0"
rigAssert "the folder trash, a folder named like a routine file and a file that is no routine are no rows" \
	"$( LC_ALL=C grep -c -e 'trash' -e 'folder\.routine' -e 'routine\.notes' "$rigTmp/out" || : ) $( [ -f "$rigSkills/trash/trash.old.routine.md" ] && [ -d "$rigSkills/keeper-rig/folder.routine.md" ] && echo there )" "0 there"

echo "-- 2. it only reads --"
rigRun "$rigOp"
rigAssert "a second call prints the same rows" "$( cmp -s "$rigTmp/out" "$rigTmp/list.kept" && echo same || echo other )" "same"
rigAssert "no file of the machine changed, and none was made: the workspace, the other workspace, the home and the team data" "$( rigMachine )" "$rigMachineBefore"
rigAssert "and no request was issued" "$( [ -e "$rigTmp/calls" ] && wc -l < "$rigTmp/calls" | LC_ALL=C tr -d ' ' || echo 0 )" "0"
rigBare="$rigTmp/ws-bare" ; mkdir -p "$rigBare/.local/.agents" "$rigTmp/home-bare"
rigRc=0
( cd "$rigBare" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home-bare" PATH="$PATH" MMDAPP="$rigBare" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" bash "$rigTool" "$rigOp" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
rigAssert "a workspace with no member's folder prints no row, ends 0 and says so in one note, with no error and no warning" \
	"$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "# DistroAgentsTools $rigOp: no member's folder holds a routine file" ) $( rigTroubles )" "0 0 1 0"

echo "-- 3. the rule it prints is the session spawner's: each row asked of --magic-spawn-session itself --"
rigParityBad="" ; rigStartedRows=0 ; rigRefusedRows=0
while IFS="$rigTab" read -r rigKind rigName rigOwner rigStartWord rigRest ; do
	[ "$rigKind" = routine ] || continue
	rigStart "$rigName"
	if [ "$rigRc" = 0 ] && [ "$( LC_ALL=C grep -c '^SESSION_ID=.' "$rigTmp/start.out" )" = 1 ] ; then
		rigSpawnerSays="startable" ; rigStartedRows=$(( rigStartedRows + 1 ))
	elif LC_ALL=C grep -q -F -e 'is not a plain comma-separated list of existing members' -e 'matches more than one routine file' -e 'does not open with a frontmatter block' -e 'executors and maintainers must both be non-empty' -e 'is an identity record, and an identity record is never started' "$rigTmp/start.err" ; then
		rigSpawnerSays="refused-by-its-file" ; rigRefusedRows=$(( rigRefusedRows + 1 ))
	else
		rigSpawnerSays="failed-otherwise: $( LC_ALL=C grep -m1 -e 'ERROR' "$rigTmp/start.err" )"
	fi
	case "$rigStartWord:$rigSpawnerSays" in
		startable:startable|not-startable:refused-by-its-file|broken:refused-by-its-file) ;;
		*) rigParityBad="$rigParityBad [$rigName reads $rigStartWord, the spawner: $rigSpawnerSays]" ;;
	esac
done < "$rigTmp/list.kept"
rigAssert "every row that reads startable is started by the spawner, given its selector and no member, and every other row is refused by it for its file" "${rigParityBad:-each as the spawner does}" "each as the spawner does"
rigAssert "six routines were started and ten refused, as the rows say" "$rigStartedRows $rigRefusedRows $( LC_ALL=C awk -F'\t' '$4 == "startable" { n++ } END { print n + 0 }' "$rigTmp/list.kept" )" "6 10 6"
## Each start runs its console apart from this check: waited for, so the members started can be counted.
rigLeft=60
while [ "$( LC_ALL=C grep -c . "$rigTmp/started" 2> /dev/null || : )" -lt 7 ] && [ "$rigLeft" -gt 0 ] ; do sleep 1 ; rigLeft=$(( rigLeft - 1 )) ; done
rigAssert "the members started are the executors the rows name: seven consoles, the member of the other workspace twice" \
	"$( LC_ALL=C sort "$rigTmp/started" 2> /dev/null | LC_ALL=C uniq -c | LC_ALL=C awk '{ printf "%s=%s ", $2, $1 }' )" "keeper-far=2 keeper-rig=2 magic-coordinator=3 "
## What the last field promises: a routine that needs members is started by the same operation once they are named,
## and every name is checked before anyone is started.
rigStartedBefore="$( LC_ALL=C grep -c . "$rigTmp/started" 2> /dev/null || : )"
rigNeedy="$( LC_ALL=C awk -F'\t' '$10 == "members" { print $2 ; exit }' "$rigTmp/list.kept" )"
rigStart "${rigNeedy:-no-row-says-members}" keeper-rig keeper-gone
rigAssert "a row that says members, asked of the spawner with a member and a name that is none: refused for that name, and nobody is started" \
	"$rigRc $( LC_ALL=C grep -c '^SESSION_ID=' "$rigTmp/start.out" || : ) $( LC_ALL=C grep -c -F -- 'no such team member: keeper-gone' "$rigTmp/start.err" || : ) $( LC_ALL=C grep -c . "$rigTmp/started" 2> /dev/null || : )" "1 0 1 $rigStartedBefore"
rigStart "${rigNeedy:-no-row-says-members}" keeper-rig keeper-far
rigAssert "asked with two members named, the spawner starts it: one session, that routine, and both members" \
	"$rigRc $( LC_ALL=C grep -c '^SESSION_ID=.' "$rigTmp/start.out" || : ) [$( LC_ALL=C grep -e '^ROUTINE=' -e '^MEMBERS=' "$rigTmp/start.out" | LC_ALL=C tr '\n' ' ' )]" "0 1 [ROUTINE=keeper-rig.wild.routine.md MEMBERS=keeper-rig keeper-far ]"
rigLeft=60
while [ "$( LC_ALL=C grep -c . "$rigTmp/started" 2> /dev/null || : )" -lt $(( rigStartedBefore + 2 )) ] && [ "$rigLeft" -gt 0 ] ; do sleep 1 ; rigLeft=$(( rigLeft - 1 )) ; done
rigAssert "and each of the two ran its console, and nobody else" \
	"$( LC_ALL=C sort "$rigTmp/started" 2> /dev/null | LC_ALL=C uniq -c | LC_ALL=C awk '{ printf "%s=%s ", $2, $1 }' )" "keeper-far=3 keeper-rig=3 magic-coordinator=3 "
rigAssert "the rule is one function, which the spawner starts by and the list prints: defined once, and called by both" \
	"$( cat "$rigHere"/*/*.include | LC_ALL=C grep -c -E '^AgentsToolsSpawnRoutineExecutorsRoster\(\)\{' || : ) $( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/magic/AgentsTools.MagicSpawnSession.include" | LC_ALL=C grep -c -e 'AgentsToolsSpawnRoutineExecutorsRoster "' || : ) $( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/manager/AgentsTools.ManagerRoutine.include" 2> /dev/null | LC_ALL=C grep -c -e 'AgentsToolsSpawnRoutineExecutorsRoster "' || : )" "1 1 1"

echo "-- 4. the caller rule, and the place in the family --"
rigPre=( "MDAT_SPAWN_AGENT=magic-coordinator" )
rigRun "$rigOp"
rigPre=()
rigAssert "from inside a member's session it is refused, rc 1, nothing on stdout, in the one line of the family's rule" \
	"$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "DistroAgentsTools: ${rigOp#--}: ⛔ ERROR: this session acts as magic-coordinator, and a --manager-* operation is the console's own, never run from inside a member's session -- nothing was done" )" "1 0 1"
rigRun "$rigOp" --startable
rigAssert "an argument is refused, rc 1, nothing on stdout, in one line with its syntax: the list takes none" \
	"$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigWhole "$rigTmp/err" "⛔ ERROR: DistroAgentsTools $rigOp: syntax is no argument, got: --startable" )" "1 0 1"
rigRun --manager-routine-no-such
rigAssert "an operation its subject does not have is refused by name, rc 1" "$rigRc $( rigWhole "$rigTmp/err" "DistroAgentsTools: ⛔ ERROR: invalid option: --manager-routine-no-such" )" "1 1"
rigAssert "the family has one arm for the routines, which sources their include, and that include asks nobody who calls" \
	"$( LC_ALL=C grep -c -x -e '	--manager-routine-\*)' "$rigHere/manager/AgentsTools.Manager.include" || : ) $( LC_ALL=C grep -c -F -e '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsTools.ManagerRoutine.include"' "$rigHere/manager/AgentsTools.Manager.include" || : ) $( LC_ALL=C grep -v '^[[:space:]]*#' "$rigHere/manager/AgentsTools.ManagerRoutine.include" 2> /dev/null | LC_ALL=C grep -c -e 'AgentsToolsManagerCallerCheck' -e 'AgentsToolsActingMember' || : )" "1 1 0"

echo "-- 5. the help pair --"
rigHelpInclude="$rigHere/help/Help.DistroAgentsTools.include"
rigHelpMd="$rigHere/help/Help.DistroAgentsTools.help.md"
rigSyntax="📘 syntax: DistroAgentsTools.fn.sh $rigOp"
rigEntry(){ ## -- the operation's entry in the help.md, from under its heading to the next operation's
	LC_ALL=C awk -v head="$( printf '\t\t%s' "$rigOp" )" '$0 == head { on = 1 ; next } on && /^\t\t--/ { exit } on { print }' "$rigHelpMd"
}
rigAssert "the operation has its syntax echo, its syntax line and its entry, once each, and in no other form" "$( LC_ALL=C grep -c -x -F -- "echo \"$rigSyntax\" >&2" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -x -F -- "$rigSyntax" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -x -F -- "$( printf '\t\t%s' "$rigOp" )" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -F -- "syntax: DistroAgentsTools.fn.sh $rigOp" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -F -- "syntax: DistroAgentsTools.fn.sh $rigOp" "$rigHelpMd" || : )" "1 1 1 1 1"
rigForm="$( rigEntry | LC_ALL=C sed -n -e 's/^[[:space:]]*`\(routine <.*>\)`$/\1/p' )"
rigAssert "its entry gives the form of a row" "$rigForm" "routine <selector> <owner> <start> <executors> <session> <arguments> <title> <reason> <needs>"
rigAssert "and every row printed has exactly the fields that form names" "$( LC_ALL=C awk -F'\t' -v wantFields="$( printf '%s\n' "$rigForm" | LC_ALL=C awk '{ print NF }' )" '{ rows++ ; if ( NF != wantFields ) bad++ ; } END { printf "%s:%s", ( rows > 0 ? "rows" : "none" ), bad + 0 }' "$rigTmp/list.kept" )" "rows:0"
rigAssert "the entry names the three words of <start>, the word of <session>, the operation that takes the selector, and the word of <needs>" "$( for rigWord in startable not-startable broken coworking '--magic-spawn-session --routine <selector>' members ; do rigEntry | LC_ALL=C grep -c -F -- "\`$rigWord\`" | LC_ALL=C awk '{ printf "%s", ( $1 > 0 ) ? "y" : "n" }' ; done )" "yyyyyy"
rigAssert "control: the entry was cut up to the next operation's heading, and holds its own text" "$( rigEntry | LC_ALL=C grep -c -F -- 'TAB-separated' || : ) $( rigEntry | LC_ALL=C awk 'END { print ( NR > 0 && NR < 60 ) ? "cut" : "not cut: " NR " lines" }' )" "1 cut"
rigRun --help-syntax
rigAssert "--help-syntax prints its line, once" "$rigRc $( LC_ALL=C grep -c -x -F -- "$rigSyntax" "$rigTmp/err" || : )" "0 1"

## The runs section 3 started close their records apart from this check: waited for, so none writes into a tree that is gone.
rigLeft=90
while LC_ALL=C grep -l -x 'status: spawn-started' "$rigWs"/.local/agents/spawned/*/*.md > /dev/null 2>&1 && [ "$rigLeft" -gt 0 ] ; do sleep 1 ; rigLeft=$(( rigLeft - 1 )) ; done

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MANAGER ROUTINE LIST CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_ROUTINE_LIST: OK (%d assertions, offline)\n' "$rigPasses"
