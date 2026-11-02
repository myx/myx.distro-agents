#!/usr/bin/env bash
## Behavioural check of the `epic` kind of the one validator (S24 item 19): `--intern-doc-validate epic <file|--from-stdin>` reads an epic
## against its contract (skillset contracts/epic.contract.format.md) in one pass and prints one row for each fault,
## `<file>:<line>: <rule>: <text>`. The structural rules refuse (exit 1). A moved item whose epic or section is not found beside the
## document is said as a `report-` row and refuses nothing. Held:
##   1. the kind is built: the refusal of an unknown kind names `epic`, and a clean epic gives no row, by a file and by stdin
##   2. each rule has a case that plants its one fault and expects exactly its row, with the line, and the clean epic as its control:
##      epic-title, epic-preface, epic-decisions, epic-section (unknown, out of order), epic-feature (heading, repeated id),
##      epic-owner, epic-empty, epic-done (absent, not last, a line off its form, an id twice, an id still open as an item)
##   3. what is no fault: a feature owner line instead of an owner in each item, a feature of moved items only (both closing forms),
##      a heading inside a code fence
##   4. the moved item: a target beside the document that holds the section is silent, one that does not is a report- row, exit 0
## Offline: rig files only. Red before S24 item 19: the kind `epic` is not built (every case fails).
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the dispatcher is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDocEpicValidateCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigSkills="$rigTmp/skills" rigD="$rigTmp/docs"
mkdir -p "$rigWs/.local/agents" "$rigTmp/home" "$rigSkills/magic-team" "$rigD"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigRun(){ ## kind, file|--from-stdin -- rc in rigRc, the rows in $rigTmp/said.out, the other stream in $rigTmp/said.err
	rigRc=0
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" USER=rigacct PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigSkills" bash "$rigTool" --intern-doc-validate "$1" "$2" ) > "$rigTmp/said.out" 2> "$rigTmp/said.err" < "${rigStdin:-/dev/null}" || rigRc=$?
}
rigRows(){ ## the rows of the last run as rule@line, comma-separated, in the order printed
	LC_ALL=C sed -n -E 's/^.*:([0-9]+): ([a-z-]+): .*$/\2@\1/p' "$rigTmp/said.out" | LC_ALL=C tr '\n' ',' | LC_ALL=C sed 's/,$//'
}
## An epic of the given lines, the clean one unless a case changes it: $rigD/<name>.epic.md
rigCleanLines=(
	'# 20261102 rig: the epic'
	''
	'Source: `rig.sketch.md`.'
	'Builders: the rig members.'
	''
	'## Decisions'
	''
	'- One rule holds.'
	''
	'## S1 - First feature'
	''
	'1. One outcome a check can pass. Owner: magic-developer.'
	''
	'## Done'
	''
	'- S0.1: a closed item holds now.'
)
rigEpic(){ ## name, lines... -- one line each argument
	local epicName="$1" ; shift
	printf '%s\n' "$@" > "$rigD/$epicName.epic.md"
}
rigCheck(){ ## name -- one run on that epic
	rigRun epic "$rigD/$1.epic.md"
}

echo "-- the kind is built, and the clean epic has no row --"
rigEpic clean "${rigCleanLines[@]}"
rigCheck clean
rigAssert "the clean epic: exit 0 and no row"                        "$rigRc:$( rigRows )" "0:"
rigRun nonesuch "$rigD/clean.epic.md"
rigAssert "an unknown kind names epic among the kinds built"         "$( LC_ALL=C grep -c -w 'epic' "$rigTmp/said.err" )" 1
rigStdin="$rigD/clean.epic.md" rigRun epic --from-stdin
rigAssert "the clean epic by stdin: exit 0 and no row"               "$rigRc:$( rigRows )" "0:"

echo "-- the title and the preface --"
rigEpic notitle 'a first line that is no title' "${rigCleanLines[@]:1}"
rigCheck notitle
rigAssert "a first line that is no title is a row at line 1"         "$rigRc:$( rigRows )" "1:epic-title@1"
rigEpic twotitles "${rigCleanLines[@]:0:8}" '# A second title' "${rigCleanLines[@]:8}"
rigCheck twotitles
rigAssert "a second level-1 heading is a row at its line"            "$rigRc:$( rigRows )" "1:epic-title@9"
rigEpic nosource "${rigCleanLines[@]:0:2}" "${rigCleanLines[@]:3}"
rigCheck nosource
rigAssert "no Source line is a row at the first section"             "$rigRc:$( rigRows )" "1:epic-preface@5"
rigEpic nobuilders "${rigCleanLines[@]:0:3}" "${rigCleanLines[@]:4}"
rigCheck nobuilders
rigAssert "no Builders line is a row at the first section"           "$rigRc:$( rigRows )" "1:epic-preface@5"
rigEpic nodecisions "${rigCleanLines[@]:0:5}" "${rigCleanLines[@]:8}"
rigCheck nodecisions
rigAssert "no Decisions section is a row at the first section"       "$rigRc:$( rigRows )" "1:epic-decisions@7"

echo "-- the sections --"
rigEpic unknown "${rigCleanLines[@]:0:13}" '## Notes' '' 'text' '' "${rigCleanLines[@]:13}"
rigCheck unknown
rigAssert "a heading that is no section is a row at its line"        "$rigRc:$( rigRows )" "1:epic-section@14"
rigEpic order "${rigCleanLines[@]:0:13}" '## Ground rules' '' '- A rule.' '' "${rigCleanLines[@]:13}"
rigCheck order
rigAssert "a section out of its order is a row at its line"          "$rigRc:$( rigRows )" "1:epic-section@14"
rigEpic badfeature "${rigCleanLines[@]:0:9}" '## S2: not the form' '' '1. An outcome. Owner: magic-developer.' '' "${rigCleanLines[@]:9}"
rigCheck badfeature
rigAssert "a feature heading off its form is a row"                  "$rigRc:$( rigRows )" "1:epic-feature@10"
rigEpic twice "${rigCleanLines[@]:0:13}" '## S1 - The same id again' '' '1. An outcome. Owner: magic-developer.' '' "${rigCleanLines[@]:13}"
rigCheck twice
rigAssert "a feature id that stands twice is a row at the second"    "$rigRc:$( rigRows )" "1:epic-feature@14"
rigEpic fenced "${rigCleanLines[@]:0:13}" '```' '## Not a section' '```' '' "${rigCleanLines[@]:13}"
rigCheck fenced
rigAssert "a heading inside a code fence is no heading"              "$rigRc:$( rigRows )" "0:"

echo "-- the features --"
rigEpic noowner "${rigCleanLines[@]:0:11}" '1. An outcome with no owner named.' "${rigCleanLines[@]:12}"
rigCheck noowner
rigAssert "an open item with no owner and no owner line is a row"    "$rigRc:$( rigRows )" "1:epic-owner@10"
rigEpic ownerline "${rigCleanLines[@]:0:11}" 'Owner: magic-developer.' '1. An outcome with no owner in the item.' "${rigCleanLines[@]:12}"
rigCheck ownerline
rigAssert "an owner line stands for the items"                       "$rigRc:$( rigRows )" "0:"
rigEpic empty "${rigCleanLines[@]:0:11}" "${rigCleanLines[@]:12}"
rigCheck empty
rigAssert "a feature with no open item and no moved item is a row"   "$rigRc:$( rigRows )" "1:epic-empty@10"
rigEpic moved "${rigCleanLines[@]:0:11}" '1. Moved to 20261102-rig.epic.md, section S4.' '2. Moved to 20261102-rig.epic.md, section S5: what moved.' "${rigCleanLines[@]:12}"
rigCheck moved
rigAssert "a feature of moved items only has no row of its own"      "$( rigRows | LC_ALL=C tr ',' '\n' | LC_ALL=C grep -c -E '^epic-(empty|owner)' || : )" 0

echo "-- the Done section --"
rigEpic nodone "${rigCleanLines[@]:0:13}"
rigCheck nodone
rigAssert "no Done section is a row"                                 "$rigRc:$( rigRows )" "1:epic-done@10"
rigEpic donenotlast "${rigCleanLines[@]:0:13}" '## Done' '' '- S0.1: a closed item holds now.' '' '## S2 - After the done' '' '1. An outcome. Owner: magic-developer.'
rigCheck donenotlast
rigAssert "a section after Done is a row at that section"            "$rigRc:$( rigRows )" "1:epic-done@18"
rigEpic badline "${rigCleanLines[@]:0:15}" '- S0.1: a closed item holds now.' '- a Done line with no id' '- S0.2 (a parenthesis): not the form'
rigCheck badline
rigAssert "a Done line off its form is a row at its line"            "$rigRc:$( rigRows )" "1:epic-done@17,epic-done@18"
rigEpic donetwice "${rigCleanLines[@]:0:15}" '- S0.1: a closed item holds now.' '- S0.1: the same id again.'
rigCheck donetwice
rigAssert "a Done id that stands twice is a row at the second"         "$rigRc:$( rigRows )" "1:epic-done@17"
rigEpic doneopen "${rigCleanLines[@]:0:12}" '## Done' '' '- S1.1: a closed item, and the item still stands.'
rigCheck doneopen
rigAssert "a Done id that still stands as an open item is a row"      "$rigRc:$( rigRows )" "1:epic-done@15"
rigEpic donefeature "${rigCleanLines[@]:0:12}" '## Done' '' '- S1.2: a closed item.'
rigCheck donefeature
rigAssert "a Done id that names no open item and stands in no feature" "$rigRc:$( rigRows )" "0:"

echo "-- the moved item beside its document --"
rigEpic from "${rigCleanLines[@]:0:11}" '1. Moved to to-rig.epic.md, section S3: what moved.' "${rigCleanLines[@]:12}"
rigCheck from
rigAssert "a target that is not beside the document is said, and refuses nothing" "$rigRc:$( rigRows )" "0:report-epic-moved@12"
rigEpic to-rig '# 20261102 rig: the target' '' 'Source: `x`.' 'Builders: y.' '' '## Decisions' '' '- A rule.' '' '## S9 - Another' '' '1. An outcome. Owner: m.' '' '## Done'
rigCheck from
rigAssert "a target beside the document without the section is said" "$rigRc:$( rigRows )" "0:report-epic-moved@12"
rigEpic to-rig '# 20261102 rig: the target' '' 'Source: `x`.' 'Builders: y.' '' '## Decisions' '' '- A rule.' '' '## S3 - The section' '' '1. An outcome. Owner: m.' '' '## Done'
rigCheck from
rigAssert "a target that holds the section is silent"                "$rigRc:$( rigRows )" "0:"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ DOC EPIC VALIDATE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'DOC_EPIC_VALIDATE: OK (%d assertions, offline, rig files only)\n' "$rigPassCount"
