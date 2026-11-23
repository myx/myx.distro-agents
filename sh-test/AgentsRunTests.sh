#!/usr/bin/env bash
##
## AgentsRunTests.sh -- the test runner's router. A call parses the part of the operation it asks for, and nothing else:
##   --passed ...      reads the pass record and runs nothing            part: runner/AgentsRunPassed.sh
##   --sweep-rigs ...  lists the rigs a sweep would take, or takes them  part: runner/AgentsRunSweep.sh
##   anything else     runs the tests named, or the whole suite          part: runner/AgentsRunExecute.sh
## The parts sit beside this file, and a runner copied alone into a rig takes them from the origin's package
## ($MDLT_ORIGIN): a rig that holds this file alone still runs. The exit status is the part's own.
## What a run does, and what the line, the lanes and the slots are, is in the package's MAGIC.md.
##

set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"

testDir="$( cd "$( dirname "$0" )" && pwd )"
partDir="$testDir/runner"
[ -f "$partDir/AgentsRunExecute.sh" ] || partDir="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/runner"

partName=AgentsRunExecute.sh
for partArg in "$@" ; do
	case "$partArg" in
		--) break ;;
		--passed) partName=AgentsRunPassed.sh ; break ;;
		--sweep-rigs|--sweep-rigs-list) partName=AgentsRunSweep.sh ; break ;;
	esac
done
[ -f "$partDir/$partName" ] || {
	echo "⛔ ERROR: AgentsRunTests.sh: the part $partName is neither at $testDir/runner nor at $partDir" >&2
	exit 1
}
MDAT_SUITE_TESTDIR="$testDir" MDAT_SUITE_ENTRY="$testDir/${0##*/}" MDAT_SUITE_PARTS="$partDir" exec "${BASH:-bash}" "$partDir/$partName" "$@"
