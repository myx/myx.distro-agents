#!/usr/bin/env bash
## Behavioural check on the read of the help of the console's own family --manager-*, run rather than read, from a
## rig workspace built here: --manager-help-read, which the root `Manuals (Help)` of the manager screen shows.
## Held: it prints on stdout first what a user calls: the syntax lines of the help, each once in its order, but those
## of the families the one line of the read leaves out, the internal ones and those of the agents (the owner: "not
## --intern and not --member, not --librarian"), tried also in a rig origin whose help has an operation of four
## families more; the bare call is as it was. Then one empty line, then the syntax lines of every operation and the
## entry of every operation of the manual, as --member-help prints those of a member's operations (the same two awk
## files, every operation on their list): no help of its own. Last the chapters of the help file but its options, a
## row a line, `chapter`, `head` or `foot`, the line as it is written: the lines after its syntax lines to the heading
## of its options, and the lines after its options, which a member's `Member Help` shows around its syntax lines.
## With one argument, a tooling command as --manager-command-list lists it (the owner: "Tooling Commands can show
## their `--help`"), it prints the help that command's own `--help` prints, from where it prints it, and runs
## nothing: the syntax lines its help include echoes that its help file does not hold, then that help file as it is
## written, both from the help folder of the package its file lies in; a command with no help file beside it prints
## nothing; a command of the family has its own. Refused in one line, rc 1, nothing on stdout: an argument that
## names no tooling command, and a second argument. THE CALLER RULE of the family holds. And its help pair.
## Offline; only the help files of the origin and of the rig are read.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTool="${rigHere%/sh-lib}/sh-scripts/DistroAgentsTools.fn.sh"
rigRead="--manager-help-read"
rigHelpInclude="$rigHere/help/Help.DistroAgentsTools.include"
rigHelpMd="$rigHere/help/Help.DistroAgentsTools.help.md"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -f "$rigHelpMd" ] || rigRefuse "the manual is not at the origin this workspace resolves: $rigHelpMd"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsManagerHelpReadCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home"
mkdir -p "$rigWs/.local/.agents" "$rigHome"

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
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" ${rigPre[@]+"${rigPre[@]}"} \
		bash "$rigTool" "$@" ) > "$rigTmp/out" 2> "$rigTmp/err" < /dev/null || rigRc=$?
}
rigErrors(){ ## -- how many lines of the last stderr say ERROR or ASSERT, but for the one every rig of this package gets
	LC_ALL=C grep -E 'ERROR|ASSERT' "$rigTmp/err" | LC_ALL=C grep -c -v -F -- 'SystemContext.SetInputSpec' || :
}
rigNames(){ ## file -- the names of the operations its entries head, the manual's own form: a tab, a tab, the name; each once, sorted
	LC_ALL=C awk '/^## / { inOptions = ($0 ~ /^##  Options:/) } inOptions && /^\t\t--/ { split(substr($0, 3), parts, " ") ; print parts[1] }' "$1" | LC_ALL=C sort -u
}

echo "-- 1. first what a user calls: every syntax line of the help, but those of the families the read leaves out --"
rigRun
rigBareRc="$rigRc"
LC_ALL=C grep '^📘' "$rigTmp/err" > "$rigTmp/bare"
rigRun "$rigRead"
LC_ALL=C awk 'NF == 0 { exit } { print }' "$rigTmp/out" > "$rigTmp/first"
LC_ALL=C awk 'seen { print } NF == 0 { seen = 1 }' "$rigTmp/out" > "$rigTmp/rest"
LC_ALL=C sed -n 's/^echo "\(📘 syntax: DistroAgentsTools\.fn\.sh .*\)" >&2$/\1/p' "$rigHelpInclude" | LC_ALL=C awk '!seen[$0]++' > "$rigTmp/syntax"
rigAssert "rc 0, no error, and each of its first lines a syntax line of the help, once, in the help's order" "$rigRc $( rigErrors ) $( LC_ALL=C grep -c '' "$rigTmp/first" | LC_ALL=C awk '{ print ( $1 > 20 ) }' ) $( LC_ALL=C grep -x -F -f "$rigTmp/first" "$rigTmp/syntax" | cmp -s - "$rigTmp/first" && echo same || echo differs )" "0 0 1 same"
rigAssert "the bare call is as it was: rc 1, its default syntax, a member's entry point among it" "$rigBareRc $( LC_ALL=C grep -c -F -e 'fn.sh --member-help <team-member>' -e 'fn.sh --agents-config-option' "$rigTmp/bare" )" "1 2"
rigAssert "in: an --owner-* operation, and every entry point of the bare call but a member's" "$( LC_ALL=C grep -c -F -e 'fn.sh --owner-workspace-list' "$rigTmp/first" ) $( LC_ALL=C grep -v -F -e 'fn.sh --member-' "$rigTmp/bare" | LC_ALL=C grep -c -v -x -F -f "$rigTmp/first" )" "1 0"
rigAssert "out: a member's operation and a librarian's, as the owner said, and an internal one" "$( LC_ALL=C grep -c -F -e 'fn.sh --member-' -e 'fn.sh [--member-' "$rigTmp/first" ) $( LC_ALL=C grep -c -F -e 'fn.sh --librarian-' "$rigTmp/first" ) $( LC_ALL=C grep -c -F -e 'fn.sh --intern-' -e 'fn.sh [--intern-' "$rigTmp/first" )" "0 0 0"
rigLeftOut="$( LC_ALL=C sed -n "s/^[[:space:]]*local helpReadOut='\(.*\)'$/\1/p" "$rigHere/manager/AgentsTools.ManagerHelp.include" )"
rigAssert "the families it leaves out are named in one line of the read, the owner's three among them, and none of them shows" "$( printf '%s\n' $rigLeftOut | LC_ALL=C grep -c -x -e '--intern-' -e '--member-' -e '--librarian-' ) $( for rigFamily in $rigLeftOut ; do LC_ALL=C grep -F -e "fn.sh $rigFamily" -e "fn.sh [$rigFamily" "$rigTmp/first" ; done | LC_ALL=C grep -c '' )" "3 0"

echo "-- 2. the rule in a help that has every kind: a rig origin, its help with an operation of four families more --"
## The rig origin: every package of the real tree by symlink, and the agents package by symlink too except the
## include of its help, a copy with four syntax lines more in the arm of --help-syntax.
rigOrigin="$rigTmp/origin"
mkdir -p "$rigOrigin/myx/myx.distro-agents/sh-lib/help"
for rigPkg in "$MDLT_ORIGIN"/* ; do
	[ "${rigPkg##*/}" != "myx" ] || continue
	ln -s "$rigPkg" "$rigOrigin/${rigPkg##*/}"
done
for rigPkg in "$MDLT_ORIGIN"/myx/* ; do
	[ "${rigPkg##*/}" != "myx.distro-agents" ] || continue
	ln -s "$rigPkg" "$rigOrigin/myx/${rigPkg##*/}"
done
for rigPkg in "$MDLT_ORIGIN"/myx/myx.distro-agents/* ; do
	[ "${rigPkg##*/}" != "sh-lib" ] || continue
	ln -s "$rigPkg" "$rigOrigin/myx/myx.distro-agents/${rigPkg##*/}"
done
for rigPkg in "$rigHere"/* ; do
	[ "${rigPkg##*/}" != "help" ] || continue
	ln -s "$rigPkg" "$rigOrigin/myx/myx.distro-agents/sh-lib/${rigPkg##*/}"
done
for rigPkg in "$rigHere"/help/* ; do
	[ "${rigPkg##*/}" != "Help.DistroAgentsTools.include" ] || continue
	ln -s "$rigPkg" "$rigOrigin/myx/myx.distro-agents/sh-lib/help/${rigPkg##*/}"
done
LC_ALL=C awk '{ print } $0 == "\t--help-syntax)" { count = split("owner intern member librarian", rigFamilies, " ") ; for (i = 1; i <= count; i++) printf "echo \"📘 syntax: DistroAgentsTools.fn.sh --%s-rig-probe\" >&2\n", rigFamilies[i] }' \
	"$rigHelpInclude" > "$rigOrigin/myx/myx.distro-agents/sh-lib/help/Help.DistroAgentsTools.include"
rigPre=( "MDLT_ORIGIN=$rigOrigin" "MDLT_OPTION=--run-from-path $rigOrigin" )
rigRun "$rigRead"
rigPre=()
LC_ALL=C awk 'NF == 0 { exit } { print }' "$rigTmp/out" > "$rigTmp/first.rig"
LC_ALL=C awk 'seen { print } NF == 0 { seen = 1 }' "$rigTmp/out" > "$rigTmp/rest.rig"
rigAssert "an --owner-* operation in; an --intern-*, a --member-* and a --librarian-* one out; all four among every operation after" "$rigRc $( rigErrors ) $( LC_ALL=C grep -c -F -- '-rig-probe' "$rigHelpInclude" ) $( for rigFamily in owner intern member librarian ; do LC_ALL=C grep -c -x -F -- "📘 syntax: DistroAgentsTools.fn.sh --$rigFamily-rig-probe" "$rigTmp/first.rig" ; done | LC_ALL=C tr '\n' ' ' )$( LC_ALL=C grep -c -F -- '-rig-probe' "$rigTmp/rest.rig" )" "0 0 0 1 0 0 0 4"

echo "-- 3. then every operation, its syntax lines and its entry, as --member-help gives those of a member --"
rigWant="$( LC_ALL=C grep -c -E '^echo "📘 syntax: DistroAgentsTools\.fn\.sh --' "$rigHelpInclude" )"
rigGot="$( LC_ALL=C sort -u "$rigTmp/rest" | LC_ALL=C grep -c '^📘 syntax: DistroAgentsTools\.fn\.sh --' )"
rigAssert "every syntax line of the include that names an operation, once" "$( [ "$rigWant" -gt 100 ] && echo many ) $rigGot" "many $( LC_ALL=C grep -E '^echo "📘 syntax: DistroAgentsTools\.fn\.sh --' "$rigHelpInclude" | LC_ALL=C sort -u | LC_ALL=C grep -c '' )"
rigNames "$rigHelpMd" > "$rigTmp/names.md"
{ printf '##  Options:\n' ; cat "$rigTmp/rest" ; } > "$rigTmp/rest.md"
rigNames "$rigTmp/rest.md" > "$rigTmp/names.read"
rigAssert "an entry for every operation the manual has one for, and for no other" "$( LC_ALL=C grep -c '' "$rigTmp/names.md" | LC_ALL=C awk '{ print ( $1 > 100 ) }' ) $( cmp -s "$rigTmp/names.md" "$rigTmp/names.read" && echo same || echo differs )" "1 same"
rigAssert "each entry with its text as the manual gives it: its own and that of --member-help" "$( LC_ALL=C grep -c -x -F -e "$( printf '\t\t--manager-help-read' )" -e "$( printf '\t\t--member-help <team-member>' )" "$rigTmp/rest" ) $( LC_ALL=C grep -c -F -e 'every operation of the manual' "$rigTmp/rest" | LC_ALL=C awk '{ print ( $1 > 0 ) }' )" "2 1"

echo "-- 3b. last the chapters of the help file but its options, a row a line --"
LC_ALL=C awk -F'\t' '$1 == "chapter" && $2 == "head"' "$rigTmp/rest" | LC_ALL=C cut -f3- > "$rigTmp/head.read"
LC_ALL=C awk -F'\t' '$1 == "chapter" && $2 == "foot"' "$rigTmp/rest" | LC_ALL=C cut -f3- > "$rigTmp/foot.read"
rigOptionsAt="$( LC_ALL=C grep -n -x -F '##  Options:' "$rigHelpMd" | LC_ALL=C cut -d: -f1 )"
rigAfterAt="$( LC_ALL=C awk -v at="$rigOptionsAt" 'NR > at && /^## / { print NR ; exit }' "$rigHelpMd" )"
rigSyntaxTo="$( LC_ALL=C awk '!/^📘 syntax:/ { print NR - 1 ; exit }' "$rigHelpMd" )"
LC_ALL=C sed -n "$(( rigSyntaxTo + 1 )),${rigOptionsAt}p" "$rigHelpMd" > "$rigTmp/head.md"
LC_ALL=C sed -n "${rigAfterAt},\$p" "$rigHelpMd" > "$rigTmp/foot.md"
rigAssert "the chapter rows stand last, each a row of three fields, head or foot" \
	"$( LC_ALL=C awk -F'\t' 'seen && $1 != "chapter" { bad++ } $1 == "chapter" { seen = 1 ; rows++ ; if ( $2 != "head" && $2 != "foot" ) bad++ } END { print ( rows > 0 ) ? "rows" : "none", bad + 0 }' "$rigTmp/rest" )" "rows 0"
rigAssert "head: the lines of the file after its syntax lines to the heading of its options, the last of them, as written" \
	"$( [ "$rigOptionsAt" -gt "$rigSyntaxTo" ] && [ "$rigSyntaxTo" -gt 100 ] && echo found ) $( cmp -s "$rigTmp/head.md" "$rigTmp/head.read" && echo same || echo differs ) $( tail -1 "$rigTmp/head.read" )" "found same ##  Options:"
rigAssert "foot: the lines after its options, from the heading of the next chapter to the end, as written" \
	"$( [ -n "$rigAfterAt" ] && echo found ) $( cmp -s "$rigTmp/foot.md" "$rigTmp/foot.read" && echo same || echo differs ) $( LC_ALL=C grep -c -x -F '##  Notes:' "$rigTmp/foot.read" )" "found same 1"
rigAssert "no syntax line and no option of the manual among the chapters" "$( cat "$rigTmp/head.read" "$rigTmp/foot.read" | LC_ALL=C grep -c -e '^📘 syntax:' -e "$( printf '^\t\t--manager-help-read$' )" )" "0"

echo "-- 4. what it refuses, the caller rule of the family, and its help pair --"
rigRun "$rigRead" extra
rigAssert "an argument that names no tooling command: rc 1, nothing on stdout, one error line" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigErrors )" "1 0 1"
rigPre=( "MDAT_SPAWN_AGENT=keeper-rig" )
rigRun "$rigRead"
rigPre=()
rigAssert "from inside a member's session it is refused, rc 1, nothing on stdout, in the one line of the family" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( LC_ALL=C grep -c -F -- "a --manager-* operation is the console's own, never run from inside a member's session" "$rigTmp/err" )" "1 0 1"
rigLine="📘 syntax: DistroAgentsTools.fn.sh $rigRead"
rigAssert "it has its syntax echo, its syntax line and its entry, once each" "$( LC_ALL=C grep -c -x -F -- "echo \"$rigLine\" >&2" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -x -F -- "$rigLine" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -x -F -- "$( printf '\t\t%s' "$rigRead" )" "$rigHelpMd" || : )" "1 1 1"
rigAssert "and so has its form with a command: its syntax echo, its syntax line, and the line that heads the same entry" "$( LC_ALL=C grep -c -x -F -- "echo \"$rigLine <Name>.fn.sh\" >&2" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -x -F -- "$rigLine <Name>.fn.sh" "$rigHelpMd" || : ) $( LC_ALL=C grep -A1 -x -F -- "$( printf '\t\t%s' "$rigRead" )" "$rigHelpMd" | LC_ALL=C grep -c -x -F -- "$( printf '\t\t%s <Name>.fn.sh' "$rigRead" )" || : )" "1 1 1"
rigAssert "the family's include has one arm for the help, which sources its include" "$( LC_ALL=C grep -c -x -e '	--manager-help-\*)' "$rigHere/manager/AgentsTools.Manager.include" || : ) $( LC_ALL=C grep -c -F -e '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/manager/AgentsTools.ManagerHelp.include"' "$rigHere/manager/AgentsTools.Manager.include" || : )" "1 1"

echo "-- 5. one tooling command's help: what its own --help prints it from, read, and the command never run --"
## A rig project with a command whose help stands beside it, as the family's commands have theirs: its help include
## echoes three syntax lines, one of them its help file does not hold; the command itself, were it run, would leave a
## marker. A second command with no help file. Both declared in the index of the rig workspace.
rigProject="$rigWs/source/rig/farm-a"
mkdir -p "$rigProject/sh-scripts" "$rigProject/sh-lib/help"
for rigName in RigHelp RigBare ; do
	printf '#!/bin/sh\ntouch "%s/ran.%s"\n' "$rigTmp" "$rigName" > "$rigProject/sh-scripts/$rigName.fn.sh"
	chmod +x "$rigProject/sh-scripts/$rigName.fn.sh"
	printf '%s %s %s\n' rig/farm-a "$rigName" "$rigProject/sh-scripts" >> "$rigWs/.local/distro-commands.txt"
done
printf 'echo "📘 syntax: RigHelp.fn.sh --only-in-the-include" >&2\necho "📘 syntax: RigHelp.fn.sh <arg>" >&2\nif [ "$1" = "--help" ] ; then\n\techo "📘 syntax: RigHelp.fn.sh [--help]" >&2\n\tmyx.common lib/catMarkdown "$MDLT_ORIGIN/rig/Help.RigHelp.help.md" >&2\nfi\n' > "$rigProject/sh-lib/help/Help.RigHelp.include"
printf '📘 syntax: RigHelp.fn.sh <arg>\n📘 syntax: RigHelp.fn.sh [--help]\n\n##  Summary:\n\n\t\tDoes the rig thing, `with_code`.\n\n##  Options:\n\n\t\t--rig-option <value>\n\t\t\tWhat it does.\n' > "$rigProject/sh-lib/help/Help.RigHelp.help.md"
{ printf '📘 syntax: RigHelp.fn.sh --only-in-the-include\n' ; cat "$rigProject/sh-lib/help/Help.RigHelp.help.md" ; } > "$rigTmp/want.help"
rigRun "$rigRead" RigHelp.fn.sh
rigAssert "rc 0, no error: first the syntax lines its help include echoes that its help file does not hold, once each, then its help file as it is written" "$rigRc $( rigErrors ) $( cmp -s "$rigTmp/want.help" "$rigTmp/out" && echo same || echo differs )" "0 0 same"
rigAssert "the command itself is not run" "$( ls "$rigTmp" | LC_ALL=C grep -c '^ran\.' || : )" "0"
rigRun "$rigRead" RigBare.fn.sh
rigAssert "a command with no help file beside it: rc 0, nothing printed, and it is not run either" "$rigRc $( rigErrors ) $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( ls "$rigTmp" | LC_ALL=C grep -c '^ran\.' || : )" "0 0 0 0"
rigRun "$rigRead" DistroAgentsTools.fn.sh
rigAssert "a command of the family: its own help file, from the package its file lies in, as it is written, last" "$rigRc $( rigErrors ) $( tail -n "$( LC_ALL=C grep -c '' "$rigHelpMd" )" "$rigTmp/out" | cmp -s - "$rigHelpMd" && echo same || echo differs )" "0 0 same"
rigRun "$rigRead" NoSuchRig.fn.sh
rigAssert "a name the list of the tooling commands does not hold: rc 1, nothing on stdout, one error line" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigErrors )" "1 0 1"
rigRun "$rigRead" RigHelp.fn.sh extra
rigAssert "a second argument: rc 1, nothing on stdout, one error line, and nothing run" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigErrors ) $( ls "$rigTmp" | LC_ALL=C grep -c '^ran\.' || : )" "1 0 1 0"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MANAGER HELP READ CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_HELP_READ: OK (%d assertions, offline)\n' "$rigPasses"
