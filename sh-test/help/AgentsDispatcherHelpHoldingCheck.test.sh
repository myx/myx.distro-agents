#!/usr/bin/env bash
## Behavioural check on the dispatcher's aggregated help naming the two words a person needs to stop a rig (board task 20261106T0933Z,
## S12.15; `sh-lib/help/Help.DistroAgentsDispatcher.help.md`). The stop action and its flag landed on 2026-11-06, and a word nobody can
## find in the manual is a word that does not exist for its user. Held, read rather than run, with a control that proves the reader can
## fail:
##   1. THE SYNTAX LINE FOR --stop-sessions STANDS in the manual.
##   2. THE SYNTAX LINE FOR --override-flag STANDS, which is how `holding` is set and cleared.
##   3. THE BODY NAMES `holding` AS `--stop-sessions` REQUIRES IT, and says the schedule starts nothing while it holds.
##   4. THE READER CAN FAIL: run against a copy with those three passages removed, every row above reports the passage absent.
## Offline: the manual this check reads, and a rig of its own.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigHelp="$rigPackage/sh-lib/help/Help.DistroAgentsDispatcher.help.md"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigHelp" ] || rigRefuse "the dispatcher manual is not at $rigHelp"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsDispatcherHelpHoldingCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPassCount=$(( rigPassCount + 1 ))
	else
		rigFailCount=$(( rigFailCount + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
	return 0
}
## One passage, counted in a given file: a syntax line, or a sentence of the body.
rigHas(){ ## the file, the text
	LC_ALL=C grep -c -F -- "$2" "$1" 2> /dev/null || :
}

echo "-- 1 to 3. the manual names the flag, the stop action and the hold --"
rigAssert "the manual carries the --stop-sessions syntax line" "$( rigHas "$rigHelp" '📘 syntax: DistroAgentsDispatcher.fn.sh --stop-sessions' )" 1
rigAssert "it carries the --override-flag syntax line, which sets and clears holding" "$( rigHas "$rigHelp" '📘 syntax: DistroAgentsDispatcher.fn.sh --override-flag' )" 1
rigAssert "and its body names holding as what --stop-sessions requires" "$( rigHas "$rigHelp" 'It refuses unless `holding` holds' )" 1
rigAssert "the syntax line count is what the tool prints, so the manual is not short of one" \
	"$( rigHas "$rigHelp" '📘 syntax: DistroAgentsDispatcher.fn.sh' )" "$( LC_ALL=C grep -c '^📘 syntax: DistroAgentsDispatcher.fn.sh' "$rigHelp" )"

echo "-- 4. the reader can fail --"
rigCopy="$rigTmp/manual-without-the-passages.md"
LC_ALL=C awk '!/^📘 syntax: DistroAgentsDispatcher.fn.sh (--stop-sessions|--override-flag)/ && !/It refuses unless `holding` holds/' "$rigHelp" > "$rigCopy" || exit 1
rigAssert "with the three passages removed, the flag's syntax line is absent" "$( rigHas "$rigCopy" '📘 syntax: DistroAgentsDispatcher.fn.sh --stop-sessions' )" 0
rigAssert "with them removed, the hold's own wording is absent" "$( rigHas "$rigCopy" 'It refuses unless `holding` holds' )" 0
rigAssert "and the copy still carries the other syntax lines, so the removal was surgical" \
	"$( rigHas "$rigCopy" '📘 syntax: DistroAgentsDispatcher.fn.sh --current-flags' )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ DISPATCHER HELP HOLDING CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
printf 'DISPATCHER_HELP_HOLDING: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
