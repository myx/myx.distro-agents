#!/usr/bin/env bash
## Behavioural check on the read of the help of the console's own family --manager-*, run rather than read, from a
## rig workspace built here: --manager-help-read, which the root `Manuals (Help)` of the manager screen shows.
## Held: it prints on stdout first what the bare call of the tool prints, as it prints it, then one empty line, then
## the syntax lines of every operation and the entry of every operation of the manual, as --member-help prints
## those of a member's operations (the same two awk files, every operation on their list): no help of its own.
## Refused in one line, rc 1, nothing on stdout: any argument. THE CALLER RULE of the family holds. And its help
## pair. Offline; only the help files of the origin are read.
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
rigTmp="$( mktemp -d -t AgentsManagerHelpReadCheck )" || exit 1
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

echo "-- 1. what the bare call prints, first, as it prints it --"
rigRun
rigBareRc="$rigRc"
LC_ALL=C grep '^📘' "$rigTmp/err" > "$rigTmp/bare"
rigRun "$rigRead"
LC_ALL=C awk 'NF == 0 { exit } { print }' "$rigTmp/out" > "$rigTmp/first"
LC_ALL=C awk 'seen { print } NF == 0 { seen = 1 }' "$rigTmp/out" > "$rigTmp/rest"
rigAssert "rc 0, and its first lines are what the bare call (rc 1) writes, each as it writes it, and nothing more" "$rigRc $rigBareRc $( LC_ALL=C grep -c '' "$rigTmp/bare" | LC_ALL=C awk '{ print ( $1 > 0 ) }' ) $( cmp -s "$rigTmp/bare" "$rigTmp/first" && echo same || echo differs ) $( rigErrors )" "0 1 1 same 0"
rigAssert "the bare call's lines are the default syntax of the help's own include, the operation list of --help-syntax not among them" "$( LC_ALL=C grep -c -F -e '--agents-config-option' -e '--owner-setup-<domain>' "$rigTmp/first" ) $( LC_ALL=C grep -c -F -e '--client-comms-' -e '--manager-session-list' "$rigTmp/first" )" "2 0"

echo "-- 2. then every operation, its syntax lines and its entry, as --member-help gives those of a member --"
rigWant="$( LC_ALL=C grep -c -E '^echo "📘 syntax: DistroAgentsTools\.fn\.sh --' "$rigHelpInclude" )"
rigGot="$( LC_ALL=C sort -u "$rigTmp/rest" | LC_ALL=C grep -c '^📘 syntax: DistroAgentsTools\.fn\.sh --' )"
rigAssert "every syntax line of the include that names an operation, once" "$( [ "$rigWant" -gt 100 ] && echo many ) $rigGot" "many $( LC_ALL=C grep -E '^echo "📘 syntax: DistroAgentsTools\.fn\.sh --' "$rigHelpInclude" | LC_ALL=C sort -u | LC_ALL=C grep -c '' )"
rigNames "$rigHelpMd" > "$rigTmp/names.md"
{ printf '##  Options:\n' ; cat "$rigTmp/rest" ; } > "$rigTmp/rest.md"
rigNames "$rigTmp/rest.md" > "$rigTmp/names.read"
rigAssert "an entry for every operation the manual has one for, and for no other" "$( LC_ALL=C grep -c '' "$rigTmp/names.md" | LC_ALL=C awk '{ print ( $1 > 100 ) }' ) $( cmp -s "$rigTmp/names.md" "$rigTmp/names.read" && echo same || echo differs )" "1 same"
rigAssert "each entry with its text as the manual gives it: its own and that of --member-help" "$( LC_ALL=C grep -c -x -F -e "$( printf '\t\t--manager-help-read' )" -e "$( printf '\t\t--member-help <team-member>' )" "$rigTmp/rest" ) $( LC_ALL=C grep -c -F -e 'every operation of the manual' "$rigTmp/rest" | LC_ALL=C awk '{ print ( $1 > 0 ) }' )" "2 1"

echo "-- 3. what it refuses, the caller rule of the family, and its help pair --"
rigRun "$rigRead" extra
rigAssert "any argument: rc 1, nothing on stdout, one error line" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( rigErrors )" "1 0 1"
rigPre=( "MDAT_SPAWN_AGENT=keeper-rig" )
rigRun "$rigRead"
rigPre=()
rigAssert "from inside a member's session it is refused, rc 1, nothing on stdout, in the one line of the family" "$rigRc $( wc -c < "$rigTmp/out" | LC_ALL=C tr -d ' ' ) $( LC_ALL=C grep -c -F -- "a --manager-* operation is the console's own, never run from inside a member's session" "$rigTmp/err" )" "1 0 1"
rigLine="📘 syntax: DistroAgentsTools.fn.sh $rigRead"
rigAssert "it has its syntax echo, its syntax line and its entry, once each" "$( LC_ALL=C grep -c -x -F -- "echo \"$rigLine\" >&2" "$rigHelpInclude" || : ) $( LC_ALL=C grep -c -x -F -- "$rigLine" "$rigHelpMd" || : ) $( LC_ALL=C grep -c -x -F -- "$( printf '\t\t%s' "$rigRead" )" "$rigHelpMd" || : )" "1 1 1"
rigAssert "the family's include has one arm for the help, which sources its include" "$( LC_ALL=C grep -c -x -e '	--manager-help-\*)' "$rigHere/AgentsTools.Manager.include" || : ) $( LC_ALL=C grep -c -F -e '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.ManagerHelp.include"' "$rigHere/AgentsTools.Manager.include" || : )" "1 1"

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ MANAGER HELP READ CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'MANAGER_HELP_READ: OK (%d assertions, offline)\n' "$rigPasses"
