#!/usr/bin/env bash
## Behavioural check on S1.5 of the testing fix plan: every `## Done` bullet of an epic that names a check names one that
## exists. Read over rig epics, through the one document validator, so the reading is a real run rather than a grep of this
## file. The two facts are reported APART, because only one of them is a fault. Held:
##   1. CONTROL: a clean rig epic is validated and draws no row at all, so no assertion below rests on a run that stopped
##      early or on a validator that never reached the section.
##   2. A bullet naming a check that does exist draws no row, so the reading is not simply always red. The check named is a
##      real one in this tree, so a probe reporting it absent is also shown to be able to find it.
##   3. A bullet naming a check file that does not exist draws a row at its own line, the row names the file it could not
##      find, and the run refuses.
##   4. A bullet naming no check at all draws a `report-` row at its own line and refuses nothing: 57 of the live epic's 88
##      bullets hold no check name, and each is a line for the owner to read rather than a fault.
##   5. CONTROL, and the half that makes 2 to 4 mean anything: an epic holding both kinds draws one refusing row and two
##      report rows, each at its own line and none twice.
## Red recipe: the `epic` rule set reads `## Done` for its shape alone today, so sections 3 and 4 read no row where a row is
## wanted, and section 5 reads one refusing row where two report rows are wanted. Nothing in the package reports either fact.
## The distinction this check reads is the existing `report-` convention, which refuses nothing; it proposes no new rule name.
## Offline: rig epic files only, and the suite tree this origin resolves.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
## A check that exists in this tree, and a name that names no file, for the reading to tell apart.
rigCheckPresent='AgentsContactsTierWordCheck'
rigCheckAbsent='AgentsEpicDoneProofAbsentCheck'
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the dispatcher is not at the origin this workspace resolves: $rigTool"
[ -f "$rigPackage/sh-test/common/$rigCheckPresent.test.sh" ] || rigRefuse "the known-positive control check is not at the origin this workspace resolves: $rigPackage/sh-test/common/$rigCheckPresent.test.sh"
[ ! -e "$rigPackage/sh-test/common/$rigCheckAbsent.test.sh" ] || rigRefuse "the name this check treats as absent has a file after all, so its absent case would prove nothing: $rigPackage/sh-test/common/$rigCheckAbsent.test.sh"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsEpicDoneProofCheck )" || exit 1
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
rigRun(){ ## epic file -- rc in rigRc, the rows in $rigTmp/said.out, the other stream in $rigTmp/said.err
	rigRc=0
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp/home" USER=rigacct PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigSkills" bash "$rigTool" --intern-doc-validate epic "$1" ) > "$rigTmp/said.out" 2> "$rigTmp/said.err" || rigRc=$?
}
rigRowLines(){ ## -- the line of every row printed, comma-separated, in the order printed
	LC_ALL=C sed -n -E 's/^.*:([0-9]+): [A-Za-z-]+: .*$/\1/p' "$rigTmp/said.out" | LC_ALL=C tr '\n' ',' | LC_ALL=C sed 's/,$//'
}
rigReportLines(){ ## -- the line of every `report-` row printed, comma-separated
	LC_ALL=C sed -n -E 's/^.*:([0-9]+): report-[A-Za-z-]+: .*$/\1/p' "$rigTmp/said.out" | LC_ALL=C tr '\n' ',' | LC_ALL=C sed 's/,$//'
}
rigRefusingLines(){ ## -- the line of every row printed that is no `report-` row, comma-separated
	LC_ALL=C sed -n -E 's/^.*:([0-9]+): ([A-Za-z-]+): .*$/\1 \2/p' "$rigTmp/said.out" | LC_ALL=C awk '$2 !~ /^report-/ { printf "%s,", $1 ; }' | LC_ALL=C sed 's/,$//'
}
rigLineOfWord(){ ## epic file, a word -- the line number of the one bullet holding it
	LC_ALL=C grep -n -e "$2" "$1" | LC_ALL=C cut -d: -f1 | LC_ALL=C tr '\n' ',' | LC_ALL=C sed 's/,$//'
}
## An epic in the contract's own shape, the clean one unless a case gives it other Done bullets: $rigD/<name>.epic.md
## Its one feature holds item 1 open, so every Done bullet here names an id of feature S2, which this epic does not hold:
## a Done id that still stands as an open item is a fault of the contract, and that fault would mask the ones read here.
rigEpic(){ ## name, Done bullet lines... -- each argument is one whole bullet line, dash included; prints the file's path
	local epicName="$1" ; shift
	{
		printf '# 20261102 rig: the epic\n\n'
		printf 'Source: `rig.sketch.md`.\n'
		printf 'Builders: the rig members.\n\n'
		printf '## Decisions\n\n'
		printf -- '- One rule holds.\n\n'
		printf '## S1 - First feature\n\n'
		printf '1. One outcome a check can pass. Owner: magic-developer.\n\n'
		printf '## Done\n\n'
		[ "$#" -eq 0 ] || printf -- '%s\n' "$@"
	} > "$rigD/$epicName.epic.md"
	printf '%s\n' "$rigD/$epicName.epic.md"
}

echo "-- 1. control: a clean rig epic is validated, and it draws no row at all --"
rigRun "$( rigEpic clean "- S2.1: the closed item holds now, proved by \`$rigCheckPresent\`." )"
rigAssert "not one row is printed for it" "$( LC_ALL=C grep -c . "$rigTmp/said.out" || : )" 0
rigAssert "and its status is a clean one" "$rigRc" 0

echo "-- 2. a bullet naming a check that exists draws no row, and the probe can find that check --"
rigAssert "no row is drawn for the check that exists" "$( rigRowLines )" ""
rigAssert "the probe finds that check's file where it stands" \
	"$( [ -f "$rigPackage/sh-test/common/$rigCheckPresent.test.sh" ] && printf found )" found
rigAssert "and the name it treats as absent has no file" \
	"$( [ -e "$rigPackage/sh-test/common/$rigCheckAbsent.test.sh" ] && printf present || printf absent )" absent

echo "-- 3. a bullet naming a check file that does not exist is a fault at its own line --"
rigMissingEpic="$( rigEpic missing "- S2.1: the closed item holds now, proved by \`$rigCheckAbsent\`." )"
rigRun "$rigMissingEpic"
rigAssert "the bullet is reported, at its own line and nowhere else" "$( rigRefusingLines )" "$( rigLineOfWord "$rigMissingEpic" "$rigCheckAbsent" )"
rigAssert "and the row names the file it could not find" \
	"$( LC_ALL=C grep -c -- "$rigCheckAbsent" "$rigTmp/said.out" || : )" 1
rigAssert "the run refuses, because a cited proof that is not there is a fault" "$rigRc" 1

echo "-- 4. a bullet naming no check is listed for the owner, and is no fault --"
rigUnprovedEpic="$( rigEpic unproved "- S2.1: the closed item holds now, and a reader confirms it by hand." )"
rigRun "$rigUnprovedEpic"
rigAssert "the bullet is listed as a report row at its own line" "$( rigReportLines )" "$( rigLineOfWord "$rigUnprovedEpic" 'a reader confirms it by hand' )"
rigAssert "it carries the item's own id, so a reader knows which bullet to read" \
	"$( LC_ALL=C grep -c -e 'S2\\.1' "$rigTmp/said.out" || : )" 1
rigAssert "and it is reported as no fault" "$( rigRefusingLines )" ""
rigAssert "so the run refuses nothing: a listing is not a red" "$rigRc" 0

echo "-- 5. control: an epic holding both kinds is read line by line, and no line twice --"
rigBothEpic="$( rigEpic both "- S2.1: the closed item holds now, and a reader confirms it by hand." "- S2.2: the closed item holds now, proved by \`$rigCheckAbsent\`." "- S2.4: another reader confirms it by hand." )"
rigRun "$rigBothEpic"
rigAssert "the one fault stands alone on its own line" "$( rigRefusingLines )" "$( rigLineOfWord "$rigBothEpic" "$rigCheckAbsent" )"
rigAssert "and the two unproved bullets are listed, each at its own line" "$( rigReportLines )" \
	"$( LC_ALL=C grep -n -e 'a reader confirms it by hand' -e 'another reader confirms it by hand' "$rigBothEpic" | LC_ALL=C cut -d: -f1 | LC_ALL=C tr '\n' ',' | LC_ALL=C sed 's/,$//' )"
rigAssert "no line is reported twice, under either fact" \
	"$( printf '%s,%s' "$( rigRefusingLines )" "$( rigReportLines )" | LC_ALL=C tr ',' '\n' | LC_ALL=C grep -c . )/$( printf '%s,%s' "$( rigRefusingLines )" "$( rigReportLines )" | LC_ALL=C tr ',' '\n' | LC_ALL=C grep . | LC_ALL=C sort -u | LC_ALL=C grep -c . )" "3/3"
rigAssert "and it refuses, because one of its bullets cites a proof that is not there" "$rigRc" 1

if [ "$rigFailCount" -ne 0 ] ; then
	printf 'EPIC DONE PROOF: FAIL (%s passed, %s failed)\n' "$rigPassCount" "$rigFailCount" ; exit 1
fi
printf 'EPIC_DONE_PROOF: OK (%s assertions, offline, rig epics only)\n' "$rigPassCount"
