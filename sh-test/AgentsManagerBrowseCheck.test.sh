#!/usr/bin/env bash
## Behavioural check on the two read-only browse operations of the console's own family --manager-*, run rather
## than read, against a rig workspace built here: --manager-team-data-read <store> [<folder> [<item>]], the items
## of the team data's board, audit and vault, and --manager-team-member-files <team-member> [<file>], the files of
## one member's skillset folder.
## Held: a store prints its row, then its folders, the board's in the order of its states and the others after
## them, the audit's newest month first, each with how many items it holds, then the items that lie in the store
## itself; a folder prints its items, those whose name is dated the newest first, then the others by name, each
## with its size and the stamp of its name; an item prints its text as it lies; a store that is not there says so
## in its one row, and one that is empty says it holds nothing. A member's files are listed by their paths inside
## its folder, sorted, with their size and whether they are text, dot files and links aside; one of them prints
## whole where it is text. Refused in one line, rc 1, nothing on stdout: a word that is no store, a name that is
## not bare, a folder or an item that is not there, a path the list of a member's files does not give, and a file
## that is no text. BOTH ONLY READ: every file of the team data and of the member's folder is as it was. THE CALLER RULE of the family holds for
## both. And the help pair of each. Offline; only the rig's own tree is read.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTool="${rigHere%/sh-lib}/sh-scripts/DistroAgentsTools.fn.sh"
rigData="--manager-team-data-read"
rigFiles="--manager-team-member-files"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
rigTmp="$( mktemp -d -t AgentsManagerBrowseCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigBare="$rigTmp/ws-bare" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills"
rigRoot="$rigWs/.local/agents/team-data-root"
mkdir -p "$rigWs/.local/.agents" "$rigBare/.local/.agents" "$rigHome" "$rigRoot/board/running" "$rigRoot/board/review" "$rigRoot/board/odd-state" \
	"$rigRoot/board/backlog" "$rigRoot/audit/2026-09" "$rigRoot/audit/2026-10" "$rigRoot/audit/2026-10/deeper" "$rigRoot/vault" \
	"$rigSkills/keeper-rig/resources" "$rigSkills/keeper-rig/.hidden" "$rigTmp/outside"
printf 'running a\n' > "$rigRoot/board/running/task-alpha.md"
printf 'running b\n' > "$rigRoot/board/running/task-20261001T0900Z-beta.md"
printf 'running c, with no stamp and no suffix\n' > "$rigRoot/board/running/epic-gamma"
printf 'review\n' > "$rigRoot/board/review/proposal-delta.md"
printf 'odd\n' > "$rigRoot/board/odd-state/task-odd.md"
printf 'old\n' > "$rigRoot/audit/2026-09/session-20260930T2300Z-keeper-rig-1.log"
printf 'new one\nits second line\n' > "$rigRoot/audit/2026-10/session-20261013T0100Z-keeper-rig-2.log"
printf 'newer\n' > "$rigRoot/audit/2026-10/transcript-20261014T0200Z-a talk.md"
printf 'deep\n' > "$rigRoot/audit/2026-10/deeper/not-listed.md"
printf 'dot\n' > "$rigRoot/audit/2026-10/.dot-file"
printf 'root\n' > "$rigRoot/audit/declaration-20260928T0000Z-output-style.md"
printf -- '---\nname: keeper-rig\n---\n# keeper-rig\n' > "$rigSkills/keeper-rig/SKILL.md"
printf 'armed\n' > "$rigSkills/keeper-rig/keeper-rig.armed.md"
printf 'icon\000bytes\n' > "$rigSkills/keeper-rig/resources/keeper-rig.icon.png"
printf 'hidden\n' > "$rigSkills/keeper-rig/.hidden/secret.md"
printf 'dot\n' > "$rigSkills/keeper-rig/.DS_Store"
printf 'outside\n' > "$rigTmp/outside/far.md"
ln -s "$rigTmp/outside/far.md" "$rigSkills/keeper-rig/linked.md"

rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigPre=() ; rigRunWs="$rigWs"
rigRun(){ ## tool arguments... -- one dispatcher call from the rig workspace; rc in rigRc, stdout in out, stderr in err
	rigRc=0
	( cd "$rigRunWs" && env -i HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigRunWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigOut(){ ## -- the last stdout, TAB written as a space, a line a `|`
	LC_ALL=C tr '\t\n' ' |' < "$rigTmp/out"
}
rigErrors(){ ## -- how many lines of the last stderr say ERROR or ASSERT, but for the one every rig of this package gets
	LC_ALL=C grep -E 'ERROR|ASSERT' "$rigTmp/err" | LC_ALL=C grep -c -v -F -- 'SystemContext.SetInputSpec' || :
}
rigRefused(){ ## -- the status, the bytes on stdout and the count of error lines of the last call
	printf '%s %s %s' "$rigRc" "$( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' )" "$( rigErrors )"
}
rigSums(){ ## -- every file of the team data, of the member's folder and beside it, with the sum of its bytes, as one sum: the registries a call of the family rebuilds aside
	( cd "$rigTmp" && find ws/.local/agents/team-data-root skills outside -type f -exec cksum {} + | LC_ALL=C sort | cksum )
}
rigBefore="$( rigSums )"

echo "-- 1. a store: its row, its folders, the items in it itself --"
rigRun "$rigData" board
rigAssert "the board: present, its folders in the order of its states, the others after them, each with its items" "$rigRc $( rigOut )" \
	"0 store board present 4 0|folder board running 3|folder board review 1|folder board backlog 0|folder board odd-state 1|"
rigRun "$rigData" audit
rigAssert "the audit: the newest month first, then the items in the audit itself" "$rigRc $( rigOut )" \
	"0 store audit present 2 1|folder audit 2026-10 2|folder audit 2026-09 1|item audit - declaration-20260928T0000Z-output-style.md 5 20260928T0000|"
rigRun "$rigData" vault
rigAssert "an empty vault says it holds nothing, in its one row" "$rigRc $( rigOut )" "0 store vault present 0 0|"
rigRunWs="$rigBare"
rigRun "$rigData" vault
rigRunWs="$rigWs"
rigAssert "a store that is not there says so, in its one row" "$rigRc $( rigOut ) $( rigErrors )" "0 store vault absent 0 0| 0"

echo "-- 2. a folder: its items --"
rigRun "$rigData" board running
rigAssert "dated items first, the newest first, then the others by name, each with its size and its stamp" "$rigRc $( rigOut )" \
	"0 item board running task-20261001T0900Z-beta.md 10 20261001T0900|item board running epic-gamma 39 -|item board running task-alpha.md 10 -|"
rigRun "$rigData" audit 2026-10
rigAssert "a name's own blank reads _, and nothing deeper than the folder nor a dot file is listed" "$rigRc $( rigOut )" \
	"0 item audit 2026-10 transcript-20261014T0200Z-a_talk.md 6 20261014T0200|item audit 2026-10 session-20261013T0100Z-keeper-rig-2.log 24 20261013T0100|"
rigRun "$rigData" audit -
rigAssert "the store itself as a folder, by -" "$rigRc $( rigOut )" "0 item audit - declaration-20260928T0000Z-output-style.md 5 20260928T0000|"

echo "-- 3. an item: its text as it lies --"
rigRun "$rigData" audit 2026-10 session-20261013T0100Z-keeper-rig-2.log
rigAssert "the item of a folder, whole" "$rigRc $( rigOut )" "0 new one|its second line|"
rigRun "$rigData" board odd-state task-odd.md
rigAssert "the item of a folder that is no state of the board" "$rigRc $( rigOut )" "0 odd|"

echo "-- 4. what the read of the team data refuses --"
rigBad=""
for rigWords in "nope" "board ../running" "board running ../../x" "board no-such" "board running no-such.md" "" "board running task-alpha.md more" ; do
	# shellcheck disable=SC2086
	rigRun "$rigData" $rigWords
	[ "$( rigRefused )" = "1 0 1" ] || rigBad="$rigBad [$rigWords: $( rigRefused )]"
done
rigAssert "a word that is no store, a name that is not bare, a folder or an item that is not there, and a wrong count of words: rc 1, nothing on stdout, one error line" "${rigBad:-each refused}" "each refused"

echo "-- 5. a member's files --"
rigRun "$rigFiles" keeper-rig
rigAssert "a file a row, by its path in the folder, sorted, with its size and whether it is text; dot files and links aside" "$rigRc $( rigOut )" \
	"0 file SKILL.md 38 yes|file keeper-rig.armed.md 6 yes|file resources/keeper-rig.icon.png 11 no|"
rigRun "$rigFiles" keeper-rig SKILL.md
rigAssert "one file of the list, whole" "$rigRc $( rigOut )" "0 ---|name: keeper-rig|---|# keeper-rig|"
rigBad=""
for rigWords in "keeper-rig resources/keeper-rig.icon.png" "keeper-rig linked.md" "keeper-rig .hidden/secret.md" "keeper-rig ../keeper-rig/SKILL.md" "keeper-rig $rigTmp/outside/far.md" "no-such-member" "../keeper-rig" "" "keeper-rig SKILL.md more" ; do
	# shellcheck disable=SC2086
	rigRun "$rigFiles" $rigWords
	[ "$( rigRefused )" = "1 0 1" ] || rigBad="$rigBad [$rigWords: $( rigRefused )]"
done
rigAssert "a file that is no text, a link, a dot file, a path out of the folder, a member that is not set up, a name that is not bare, a wrong count of words: rc 1, nothing on stdout, one error line" "${rigBad:-each refused}" "each refused"
rigAssert "BOTH ONLY READ: every file of the team data and of the member's folder is as it was" "$( rigSums )" "$rigBefore"

echo "-- 6. the caller rule of the family, and the help pair of each --"
rigBad=""
for rigWords in "$rigData board" "$rigFiles keeper-rig" ; do
	rigPre=( "MDAT_SPAWN_AGENT=keeper-rig" )
	# shellcheck disable=SC2086
	rigRun $rigWords
	rigPre=()
	[ "$rigRc" = 1 ] && [ ! -s "$rigTmp/out" ] && LC_ALL=C grep -q -F -- "a --manager-* operation is the console's own, never run from inside a member's session" "$rigTmp/err" || rigBad="$rigBad [${rigWords%% *}]"
done
rigAssert "from inside a member's session both are refused, rc 1, nothing on stdout, in the one line of the family" "${rigBad:-each refused}" "each refused"
rigHelpInclude="$rigHere/help/Help.DistroAgentsTools.include"
rigHelpMd="$rigHere/help/Help.DistroAgentsTools.help.md"
rigBad=""
for rigSyntax in "$rigData <store> [<folder> [<item>]]" "$rigFiles <team-member> [<file>]" ; do
	rigLine="📘 syntax: DistroAgentsTools.fn.sh $rigSyntax"
	[ "$( LC_ALL=C grep -c -x -F -- "echo \"$rigLine\" >&2" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -x -F -- "$rigLine" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -x -F -- "$( printf '\t\t%s' "$rigSyntax" )" "$rigHelpMd" || : )" = "1 1 1" ] || rigBad="$rigBad [$rigSyntax]"
done
rigAssert "each has its syntax echo, its syntax line and its entry, once each" "${rigBad:-each paired}" "each paired"
rigAssert "the entry of the team data read gives the form of each of its rows" "$( LC_ALL=C grep -c -x -F -e '			`store <store> <state> <folders> <items>`' -e '			`folder <store> <folder> <items>`' -e '			`item <store> <folder> <name> <bytes> <stamp>`' -e '			`file <path> <bytes> <text>`' "$rigHelpMd" || : )" "4"
rigAssert "the family's include has one arm for the team data, which sources its include" "$( LC_ALL=C grep -c -x -e '	--manager-team-data-\*)' "$rigHere/AgentsTools.Manager.include" || : ) $( LC_ALL=C grep -c -F -e '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.ManagerTeamData.include"' "$rigHere/AgentsTools.Manager.include" || : )" "1 1"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MANAGER BROWSE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_BROWSE: OK (%d assertions, offline)\n' "$rigPasses"
