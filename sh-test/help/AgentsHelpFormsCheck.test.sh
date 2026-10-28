#!/usr/bin/env bash
## Behavioural check on the THREE HELP FORMS of every tool file of this package, run rather than read. The forms are the family's
## three levels (docs/commands.md, "Help levels"), and DistroAgentsTools.fn.sh is the file that has held all three from the beginning:
##   - a bare call prints the help: the default syntax, the entry points a reader starts from (or, where the bare call is a start of
##     something, as AgentsConsoleManager.fn.sh opens the manager screen, it starts it and is not asked for a help here);
##   - `--help-syntax` prints the syntax lines of its operations, rc 0;
##   - `--help` opens the file's help page: its manual `sh-lib/help/Help.<file>.help.md`, rendered through `myx.common lib/catMarkdown`,
##     or -- for a file whose help is its operation listing or a help text printed by its own include -- that help itself, rc 0.
## A help is never the answer "invalid option", on any of the three words: that is the refusal this check exists to keep out, and the
## one every tool file gave before it had the forms.
## Held:
##   1. every `sh-scripts/*.fn.sh` of the package is scanned, and the scan reports how many it read -- a scan that found none, or too
##      few, is a refusal, not a pass
##   2. `--help-syntax`: rc 0, not empty, every line a syntax line, and at least one of them this file's own
##   3. `--help`: rc 0, not empty, never "invalid option", and it names a help page -- exactly one page, that page the file's own
##      manual and there, or, where it renders none, the file's own help lines (its syntax line, its `<file>: ` head or its options)
##   4. no args: the help printed and not refused -- rc 0 or 1, for a bare call names no operation and the files that start something
##      end it 1 -- never "invalid option", and where it prints syntax lines, its own among them
##   5. the check is able to fail: a scratch package of one file that answers all three forms and one that answers none of them (the
##      "invalid option" itself) gives exactly the three rows of the one that answers none
## Offline: a rig workspace and data root of this check's own, and a `myx.common` that renders nothing but the page it was handed and
## writes on its own log which page that was. No network, no session, and no other workspace touched.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -d "$rigPackage/sh-scripts" ] || rigRefuse "the tool files are not at the origin this workspace resolves: $rigPackage/sh-scripts"
[ -d "$rigPackage/sh-lib/help" ] || rigRefuse "the help files are not at the origin this workspace resolves: $rigPackage/sh-lib/help"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || rigRefuse "the rig's fixture that makes its folder is missing from the package"
rigTmp="$( rigTempDir AgentsHelpFormsCheck )" || rigRefuse "the rig's own folder could not be made"
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/ws/.local" "$rigTmp/home" "$rigTmp/data" "$rigTmp/skills" || exit 1

## The one renderer there is: it takes one page, writes on its log which page that was, and prints the page. Anything else asked of it
## is a fault of the caller, said loudly, so a help page reached by another road cannot pass as this one.
cat > "$rigTmp/bin/myx.common" <<'RIGSHIM'
#!/bin/sh
[ "${1:-}" = "lib/catMarkdown" ] || { echo "myx.common shim: only lib/catMarkdown is run here, not: ${1:-<none>}" >&2 ; exit 99 ; }
shift
[ $# -eq 1 ] || { echo "myx.common shim: lib/catMarkdown takes one page, got $# argument(s)" >&2 ; exit 99 ; }
printf '%s\n' "$1" >> "${RIG_HELP_PAGES:?}"
cat "$1"
RIGSHIM
chmod +x "$rigTmp/bin/myx.common" || exit 1

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigRun(){ ## file, then the arguments -- the output in call.out, rc as rigRc, the pages asked of the renderer in pages
	local rigFile="$1" ; shift
	: > "$rigTmp/pages"
	env -i HOME="$rigTmp/home" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigTmp/ws" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_DATA_ROOT="$rigTmp/data" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_WORKSPACE_MODE=team-rig MDAT_WAIT_REMIND=off \
		RIG_HELP_PAGES="$rigTmp/pages" RIG_FN="$rigFile" RIG_TMP="$rigTmp" \
		python3 -I -B "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-exec.py" --alarm 60 -- bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" "$@"
		' rig "$@" > "$rigTmp/call.out" 2>&1 < /dev/null
	rigRc=$?
}
## The shape of one answer, read once into the rigS_* globals: the syntax lines it printed (its own and other files'), the refusal it
## gave, and its help lines (an option row, or the file's own head line). The context every tool file runs in reports itself on the way
## in -- `SystemContext: ...`, the tooling's own line and never the help -- and is the one line that is neither.
rigShape(){ ## file name
	rigS="$( LC_ALL=C awk -v name="$1.fn.sh" '
		index( $0, "📘 syntax: " ) == 1 { if ( index( $0, "📘 syntax: " name " " ) == 1 ) own++ ; else other++ ; next }
		index( $0, name ": ⛔ ERROR: invalid option" ) == 1 { refusal++ ; next }
		/^  --/ { helpLines++ ; next }
		index( $0, name ": " ) == 1 { helpLines++ ; next }
		index( $0, "SystemContext: " ) == 1 { next }
		/^[[:space:]]*$/ { next }
		{ rest++ }
		END { printf "%d %d %d %d %d %d\n", own, other, refusal, helpLines, rest, ( NR > 0 ? 1 : 0 ) }' "$rigTmp/call.out" )"
	rigOwn="$( printf '%s' "$rigS" | LC_ALL=C cut -d' ' -f1 )"
	rigOtherSyntax="$( printf '%s' "$rigS" | LC_ALL=C cut -d' ' -f2 )"
	rigRefusal="$( printf '%s' "$rigS" | LC_ALL=C cut -d' ' -f3 )"
	rigHelpLines="$( printf '%s' "$rigS" | LC_ALL=C cut -d' ' -f4 )"
}

## The scan of one package root: the three forms of every sh-scripts/*.fn.sh, the offenders in the rigNo* globals.
rigScan(){ ## package root
	local scanRoot="$1" scanFile scanName scanPages scanPage scanWant scanDup
	rigRuns=0 rigNoSyntax="" rigNoHelp="" rigNoBare="" rigDupSyntax=""
	for scanFile in "$scanRoot"/sh-scripts/*.fn.sh ; do
		[ -f "$scanFile" ] || continue
		scanName="$( basename "$scanFile" .fn.sh )"
		rigRuns=$(( rigRuns + 1 ))
		scanWant="$scanRoot/sh-lib/help/Help.$scanName.help.md"
		## no args: the help, never a refusal -- and where it prints syntax lines, its own among them
		rigRun "$scanFile"
		LC_ALL=C grep '^📘 syntax: ' "$rigTmp/call.out" > "$rigTmp/bare.syn" || :
		rigShape "$scanName"
		if [ ! -s "$rigTmp/call.out" ] || [ "$rigRefusal" != 0 ] || { [ "$rigOwn" = 0 ] && [ "$rigOtherSyntax" != 0 ] ; } || { [ "$rigRc" != 0 ] && [ "$rigRc" != 1 ] ; } ; then
			rigNoBare="$rigNoBare $scanName(rc$rigRc,$rigOwn own,$rigOtherSyntax other,$rigRefusal refusal)"
		fi
		## --help-syntax: the syntax lines of its operations, this file's among them
		rigRun "$scanFile" --help-syntax
		rigShape "$scanName"
		if [ ! -s "$rigTmp/call.out" ] || [ "$rigRc" != 0 ] || [ "$rigRefusal" != 0 ] || [ "$rigOwn" = 0 ] || [ "$rigHelpLines" != 0 ] ; then
			rigNoSyntax="$rigNoSyntax $scanName(rc$rigRc,$rigOwn own,$rigOtherSyntax other,$rigRefusal refusal)"
		fi
		## --help-syntax names no syntax line twice
		scanDup="$( LC_ALL=C grep '^📘 syntax: ' "$rigTmp/call.out" | LC_ALL=C sort | LC_ALL=C uniq -d | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )"
		[ "$scanDup" = 0 ] || rigDupSyntax="$rigDupSyntax $scanName($scanDup twice)"
		## --help: the manual named once and there, or the file's own help lines
		rigRun "$scanFile" --help
		rigShape "$scanName"
		scanPages="$( LC_ALL=C grep -c . "$rigTmp/pages" )"
		scanPage="$( LC_ALL=C sed -n 1p "$rigTmp/pages" )"
		if [ ! -s "$rigTmp/call.out" ] || [ "$rigRc" != 0 ] || [ "$rigRefusal" != 0 ] ; then
			rigNoHelp="$rigNoHelp $scanName(rc$rigRc,$rigRefusal refusal)"
		elif [ "$scanPages" != 0 ] ; then
			[ "$scanPages" = 1 ] && [ "$scanPage" = "$scanWant" ] && [ -f "$scanPage" ] || rigNoHelp="$rigNoHelp $scanName($scanPages pages:${scanPage:-none}, want $scanWant)"
		elif [ "$rigOwn" = 0 ] && [ "$rigHelpLines" = 0 ] ; then
			rigNoHelp="$rigNoHelp $scanName(rc$rigRc,no page and no help line: $( LC_ALL=C sed -n 1p "$rigTmp/call.out" | LC_ALL=C cut -c1-60 ))"
		fi
	done
}

echo "-- 1. every tool file of this package --"
rigScan "$rigPackage"
rigAsked="$( LC_ALL=C ls "$rigPackage"/sh-scripts/*.fn.sh | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )"
rigAssert "every sh-scripts/*.fn.sh was scanned -- $rigAsked of them, not an empty pass" "$rigRuns" "$rigAsked"
[ "$rigRuns" -ge 10 ] 2> /dev/null || rigRefuse "the scan found too few tool files to be reading the package right: $rigRuns"
rigAssert "no args: the help printed and not refused, rc 0 or 1" "[${rigNoBare# }]" "[]"
rigAssert "--help-syntax: rc 0, its own syntax lines and no help text" "[${rigNoSyntax# }]" "[]"
rigAssert "--help: rc 0, its own manual named once and there, or its own help lines" "[${rigNoHelp# }]" "[]"
rigAssert "--help-syntax names no syntax line twice" "[${rigDupSyntax# }]" "[]"

echo "-- 2. the check is able to fail --"
## A package of two files: one that answers all three forms, and one that answers none of them -- the "invalid option" every tool file
## gave before it had them.
rigCtl="$rigTmp/ctl"
mkdir -p "$rigCtl/sh-scripts" "$rigCtl/sh-lib/help" || exit 1
cat > "$rigCtl/sh-scripts/Good.fn.sh" <<'CTL'
#!/usr/bin/env bash
ctlRoot="$( cd "$( dirname "$0" )/.." && pwd )"
echo "📘 syntax: Good.fn.sh --good [<text>]" >&2
echo "📘 syntax: Good.fn.sh --good --second-form" >&2
case "${1:-}" in
	''|--help-syntax) exit 0 ;;
	--help) myx.common lib/catMarkdown "$ctlRoot/sh-lib/help/Help.Good.help.md" >&2 ; exit 0 ;;
	*) echo "Good.fn.sh: ⛔ ERROR: invalid option: $1" >&2 ; exit 1 ;;
esac
CTL
cat > "$rigCtl/sh-scripts/Bad.fn.sh" <<'CTL'
#!/usr/bin/env bash
echo "Bad.fn.sh: ⛔ ERROR: invalid option: ${1:-}" >&2
exit 1
CTL
printf '📘 syntax: Good.fn.sh [--help]\n' > "$rigCtl/sh-lib/help/Help.Good.help.md"
rigScan "$rigCtl"
rigAssert "the control package was read whole: two files" "$rigRuns" "2"
rigAssert "control, no args: the file that answers none is named, with its rc and its refusal" "[${rigNoBare# }]" "[Bad(rc1,0 own,0 other,1 refusal)]"
rigAssert "control, --help-syntax: the same file is named" "[${rigNoSyntax# }]" "[Bad(rc1,0 own,0 other,1 refusal)]"
rigAssert "control, --help: the same file is named" "[${rigNoHelp# }]" "[Bad(rc1,1 refusal)]"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ HELP FORMS CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HELP_FORMS: OK (%d assertions, %d tool files, offline, rig tree only)\n' "$rigPassCount" "$rigAsked"
