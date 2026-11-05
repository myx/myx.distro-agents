#!/usr/bin/env bash
## Behavioural check on what the routine mix-in keeps (F5.6, F7.2; the owner's S6.43: the Markdown mixer "is checked that it works, tested where
## needed, and used wherever dispatches are mixed"): a routine read through `--get-routine-text` is the merged document of every `# ` section its
## own file holds, in the order they stand, with the sections `AgentsToolsSpawnRoutineMixSections` names taking the kind routine's share in the F5.6
## order. So a `# ` section a routine holds outside the eight slots -- `magic-team.advance.routine`'s `# Next iteration by document type` among them --
## is in the merged document too: the routine's reader, which is the run of that routine, sees it.
## Held, against the real routine files of the package, run and not read:
##   0. control: a routine whose sections are all of the eight shows no loss, so a reported loss is not the instrument's own noise
##   1. the detector can see a loss: a mixed text with a section's lines taken out is reported with that section's caption; and a real routine's
##      ninth section, with its table, is in its mixed text
##   2. the package's own routines: none loses a section
## Offline: a rig skillset root of this rig, the package's member folders copied into it, every call through `env -i`.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigTeamDir="$rigPackage/skillset/magic-team"
rigSession="$rigPackage/sh-scripts/DistroAgentsSession.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigSession" ] && [ -d "$rigTeamDir" ] || rigRefuse "the package is not at the origin this workspace resolves: $rigOrigin"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRoutineSectionCoverageCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigSkills="$rigTmp/skills" rigHome="$rigTmp/home"
mkdir -p "$rigWs/.local/.agents" "$rigSkills" "$rigHome"
for rigMember in magic-architect magic-coordinator magic-librarian magic-team ; do
	rigCopyTree "$rigTeamDir/$rigMember" "$rigSkills/$rigMember" || rigRefuse "the member folder could not be copied: $rigMember"
done

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## The eight sections the mixin list names, one a line. A routine file's other `# ` sections are the ones at risk.
rigMixinSections="Summary
Opening steps
Steps
Closure steps
Routine's local procedures
Routine's local rules
Routine-specific tooling
Maintainer Notes"
## A routine's mixed text, through --get-routine-text, for a skillset root and a routine selector: in $rigTmp/<selector>.text
rigText(){ ## skillset root, routine selector, out name
	( cd "$rigWs" && env -i HOME="$rigHome" PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" \
		MDLT_OPTION="--run-from-path $rigOrigin" MDAT_SKILLSET_ROOT="$1" \
		bash "$rigSession" --get-routine-text "$2" ) > "$rigTmp/$3.text" 2> "$rigTmp/$3.err" < /dev/null
}
## The `# ` sections of a routine file that the mixin list does not name, one a line: the title line, a source index and a title's own
## sub-title are no section of the procedure.
rigUnnamedSections(){ ## routine file
	LC_ALL=C awk 'NR == 1 && $0 == "---" { fm = 1 ; next } fm { if ( $0 == "---" ) { fm = 0 } ; next } /^# / { print substr( $0, 3 ) }' "$1" \
		| while IFS= read -r rigHead ; do
			case "$rigHead" in
				Contents|*"— the actual procedure") continue ;;
			esac
			printf '%s\n' "$rigMixinSections" | LC_ALL=C grep -qxF -- "$rigHead" || printf '%s\n' "$rigHead"
		done
}
## What a routine loses: one line for each of its unnamed sections that its mixed text does not carry as a heading at any level.
rigLosses(){ ## routine file, mixed text
	rigUnnamedSections "$1" | while IFS= read -r rigHead ; do
		LC_ALL=C grep -qE "^#+ $( printf '%s' "$rigHead" | LC_ALL=C sed 's/[][\\.*^$/]/\\&/g' )\$" "$2" || printf '%s\n' "$rigHead"
	done
}
## A count of a routine file's `# ` sections named in the mixin list, so the control can name a routine that is all eight.
rigNamedCount(){ ## routine file
	LC_ALL=C awk 'NR == 1 && $0 == "---" { fm = 1 ; next } fm { if ( $0 == "---" ) { fm = 0 } ; next } /^# / { print substr( $0, 3 ) }' "$1" \
		| while IFS= read -r rigHead ; do printf '%s\n' "$rigMixinSections" | LC_ALL=C grep -qxF -- "$rigHead" && printf 'one\n' ; done | LC_ALL=C grep -c . || :
}

echo "-- 0. control: a routine of the eight named sections, and only those, loses nothing --"
rigLeaf="$rigSkills/magic-team/magic-team.verify.routine.md"
rigNamed="$( rigNamedCount "$rigLeaf" )"
rigText "$rigSkills" magic-team.verify.routine verify
rigAssert "the control routine is in the rig skillset, holds named sections only, and has a mixed text" \
	"$( [ -f "$rigLeaf" ] && printf present || printf missing ):$( [ "${rigNamed:-0}" -gt 0 ] && printf named || printf unnamed ):$( [ -s "$rigTmp/verify.text" ] && printf mixed || printf empty )" \
	"present:named:mixed"
rigAssert "it loses no section, so a loss reported below is a loss and not the instrument" \
	"$( rigLosses "$rigLeaf" "$rigTmp/verify.text" )" ""

echo "-- 1. the instrument can see a loss, and a routine's own ninth section is not one --"
rigOwn="$rigSkills/magic-team/magic-team.rigspare.routine.md"
{
	printf -- '---\ntype: routine\nexecutors: magic-coordinator\nmaintainers: magic-coordinator\nrequires-session-kind: coworking\n---\n'
	printf '# magic-team.rigspare.routine — the actual procedure\n\n'
	printf '# Summary\n\nA rig routine.\n\n# Opening steps\n\nNone.\n\n# Steps\n\n1. **rig-step**: use the table below.\n\n'
	printf '# RIG-SPARE-TABLE\n\n| key | value |\n|---|---|\n| RIG-SPARE-ROW | one |\n\n'
	printf "# Routine's local procedures\n\nNone.\n\n# Routine's local rules\n\nNone.\n\n# Routine-specific tooling\n\nNone.\n\n# Maintainer Notes\n\nNone.\n"
} > "$rigOwn"
rigText "$rigSkills" magic-team.rigspare rigspare
## The detector itself, shown able to fail on a mixed text that lost the section: the reading of a real one is only worth what this shows.
LC_ALL=C grep -v -e 'RIG-SPARE-TABLE' -e 'RIG-SPARE-ROW' "$rigTmp/rigspare.text" > "$rigTmp/rigspare.lost"
rigAssert "the detector reports a section the mixed text does not hold, by its caption" \
	"$( rigLosses "$rigOwn" "$rigTmp/rigspare.lost" )" "RIG-SPARE-TABLE"
rigAssert "and a routine's own ninth section is in its mixed text, with its content" \
	"$( rigLosses "$rigOwn" "$rigTmp/rigspare.text" ):$( LC_ALL=C grep -c -F 'RIG-SPARE-ROW' "$rigTmp/rigspare.text" || : )" ":1"

echo "-- 2. the package's own routines: none loses a section --"
rigLostReport="" rigRoutineCount=0
for rigFile in "$rigTeamDir"/*/*.routine.md ; do
	[ -f "$rigFile" ] || continue
	rigRoutineCount=$(( rigRoutineCount + 1 ))
	rigName="${rigFile##*/}" ; rigName="${rigName%.md}"
	[ "$rigName" != magic-team.rigspare ] || continue
	rigText "$rigSkills" "$rigName" "$rigName" || rigLostReport="$rigLostReport$rigName: the mixed text could not be read\n"
	rigLost="$( rigLosses "$rigFile" "$rigTmp/$rigName.text" )"
	[ -z "$rigLost" ] || rigLostReport="$rigLostReport$rigName: ${rigLost//$'\n'/, }\n"
done
rigAssert "every routine's own sections are in its mixed text" "$( printf '%b' "$rigLostReport" )" ""
rigAssert "and the sweep looked at the package's routines, not at none" \
	"$( [ "$rigRoutineCount" -ge 30 ] && printf swept || printf "swept only $rigRoutineCount" )" "swept"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ ROUTINE SECTION COVERAGE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'ROUTINE_SECTION_COVERAGE: OK (%d assertions, offline)\n' "$rigPassCount"
