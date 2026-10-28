#!/usr/bin/env bash
## Behavioural check on the board-item key `handler-routine: <routine>` (the routine that runs the item's next iteration, in place of its type's
## default), in the one validator (`--intern-doc-validate board-item.<type> <file>`, sh-lib/team-data/AgentsTools.DocValidate.include and
## AgentsDocTypeCheck.awk). The key is a row of a type's contract (magic-librarian's); what the tooling adds is its value form, `routine`.
## Held:
##   1. a routine of the skillset passes, by its file name or as the review-by key writes it (`<name>.routine`)
##   2. a routine no file of the skillset has refuses, naming the key; so does a value that is no routine name at all
##   3. a document without the key passes
##   4. where the contract does not name the key yet, it is said as an unknown key and refuses nothing
##   5. the key is on every board type that has `review-by`, in the contracts of the package, once they carry it (reported, not refused, until then)
## Offline: rig files only; the contract of the rig is the package's, with one row and one value form added.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigPackage="$rigOrigin/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigTemplates="$rigPackage/skillset/magic-team/magic-team/contracts"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the dispatcher is not at the origin this workspace resolves: $rigTool"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHandlerRoutineKeyCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigSkills="$rigTmp/skills" rigD="$rigTmp/docs"
mkdir -p "$rigWs/.local/agents" "$rigTmp/home" "$rigSkills/magic-team/contracts" "$rigD"
rigPassCount=0 rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigSkillsRoot="$rigSkills"
rigRun(){ ## kind, file
	rigRc=0
	( cd "$rigWs" && env -i HOME="$rigTmp/home" USER=rigacct PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$rigOrigin" MDLT_OPTION="--run-from-path $rigOrigin" \
		MDAT_SKILLSET_ROOT="$rigSkillsRoot" bash "$rigTool" --intern-doc-validate "$1" "$2" ) > "$rigTmp/said.out" 2> "$rigTmp/said.err" < /dev/null || rigRc=$?
}
rigRules(){ LC_ALL=C sed -n -E 's/^.*:[0-9]+: ((report-)?contract-[a-z-]+): .*$/\1/p' "$rigTmp/said.out" | LC_ALL=C tr '\n' ' ' | LC_ALL=C sed 's/ $//' ; }
rigHas(){ LC_ALL=C grep -c -F -- "$1" "$rigTmp/said.out" || : ; }
rigTask(){ ## file name, the lines after owner
	local taskName="$1" ; shift
	printf '%s\n' '---' 'document-contract: board-item.task' 'type: task' 'from: keeper-rig' 'date: 2026-10-01 10:00 +0300' 'owner: keeper-rig' "$@" '---' '# Task: a matter' '' 'The work.' > "$rigD/$taskName"
}
## The contract of the rig: the package's task contract with the key as a row beside review-by, and the form listed.
LC_ALL=C awk '{ print } /^\| `review-by` \|/ { print "| `handler-routine` | optional | member | `routine` | The routine that runs this item'"'"'s next iteration, in place of its type'"'"'s default. |" }' \
	"$rigTemplates/board-item.task.contract.format.md" > "$rigSkills/magic-team/contracts/board-item.task.contract.format.md"
printf -- '---\nexecutors: keeper-rig\nmaintainers: keeper-rig\nrequires-session-kind: standalone\n---\n# a rig routine\n' > "$rigSkills/magic-team/magic-team.rigchange.routine.md"
rigName=task-20261001T1000Z-a-matter.md

echo "-- 1. a routine of the skillset passes --"
rigTask "$rigName" 'handler-routine: magic-team.rigchange.routine.md'; rigRun board-item.task "$rigD/$rigName"
rigAssert "by its file name" "$rigRc:$( rigRules )" "0:"
rigTask "$rigName" 'handler-routine: rigchange.routine'; rigRun board-item.task "$rigD/$rigName"
rigAssert "as the review-by key writes it, <name>.routine" "$rigRc:$( rigRules )" "0:"

echo "-- 2. a routine no file has, and a value that is none, refuse --"
rigTask "$rigName" 'handler-routine: magic-team.nosuch.routine.md'; rigRun board-item.task "$rigD/$rigName"
rigAssert "an unknown routine refuses, naming the key and saying it is no routine of the skillset" "$rigRc:$( rigRules ):$( rigHas 'handler-routine' ):$( rigHas 'is not a routine of the skillset' )" "1:contract-form:1:1"
rigTask "$rigName" 'handler-routine: nosuch.routine'; rigRun board-item.task "$rigD/$rigName"
rigAssert "an unknown short name refuses" "$rigRc:$( rigRules )" "1:contract-form"
rigTask "$rigName" 'handler-routine: run the advance'; rigRun board-item.task "$rigD/$rigName"
rigAssert "a value that is no routine name refuses" "$rigRc:$( rigRules )" "1:contract-form"

echo "-- 3. no key, no fault --"
rigTask "$rigName"; rigRun board-item.task "$rigD/$rigName"
rigAssert "a task without it passes" "$rigRc:$( rigRules )" "0:"

echo "-- 4. a contract that does not name the key yet says so and refuses nothing --"
rigSkillsRoot="$rigTmp/none"
rigTask "$rigName" 'handler-routine: magic-team.nosuch.routine.md'; rigRun board-item.task "$rigD/$rigName"
rigSkillsRoot="$rigSkills"
rigAssert "an unknown key is reported, exit 0" "$rigRc:$( rigRules )" "0:report-contract-unknown-key"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ HANDLER ROUTINE KEY CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HANDLER_ROUTINE_KEY: OK (%d assertions, offline)\n' "$rigPassCount"
