#!/usr/bin/env bash
## Behavioural check on a died start with no record of its own, closed by its session id (S5.2, board task 20261106T1031Z;
## `AgentsToolsRegistryRunClosed` and `AgentsToolsRegistryDeriveState` in AgentsTools.Registries.include). A start that died
## before it wrote a record has no id but its session's, so the console's close names the session: a run carrying no spawn-id
## goes by its session id, and reads finished only then. Held, run rather than read, against a store of this check's own:
##   1. A RUN WITH NO RECORD OF ITS OWN READS FINISHED once control/closed names its session id.
##   2. IT DOES NOT BEFORE: the same store without that line reads failed, so row 1 is about the close and not about the status.
##   3. THE CLOSE OF ANOTHER RUN IS NOT ITS OWN: control/closed naming a different row leaves it failed.
##   4. A LIVE RUN IS NEVER FINISHED BY IT: the close stands, and the state is the activity word, because liveness comes first.
## RED RECIPE: delete the fallback at `sh-lib/team-data/AgentsTools.Registries.include:452` (`case "$closedWant" in ''|-) ...`)
## on a copy, so a run with no spawn-id is looked for under an empty run id: row 1 fails, and rows 2 to 4 keep their answers.
## Offline: the include, and a rig store of its own. No process, no git, no network.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="${RIG_PACKAGE:-$MDLT_ORIGIN/myx/myx.distro-agents}"
rigInclude="$rigPackage/sh-lib/team-data/AgentsTools.Registries.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigInclude" ] || rigRefuse "the registries include is not at $rigInclude"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRegistryRunClosedCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM
rigWs="$rigTmp/ws"
rigCtl="$rigWs/.local/agents/sessions/sess-one/control"
mkdir -p "$rigCtl" || exit 1
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
## The state the registry derives, for one run, in a shell of its own with only the include loaded: status, live, session id, run id.
rigState(){ ## status, live, session id, run id
	MMDAPP="$rigWs" bash -c '. "$1" ; shift ; AgentsToolsRegistryDeriveState "$@"' rig-state "$rigInclude" "$@" 2>&1 | tail -n 1
}
rigClose(){ ## what control/closed holds: a row, or a bare id
	printf '%s\n' "$1" > "$rigCtl/closed"
}
rigNoClose(){ rm -f "$rigCtl/closed" ; }

## A START THAT DIED BEFORE IT WROTE ITS RECORD: spawn-failed, nothing alive, and no spawn-id but its session's.
rigBare(){ rigState spawn-failed gone sess-one "" ; }

echo "-- 1. the close names its session, and the run reads finished --"
rigNoClose
rigAssert "control: with no close at all the run does not read finished, so the row below is about the close" \
	"$( rigBare )" "failed"
rigClose "sess-one rig 2026-11-09T01:30:00Z"
rigAssert "a died start with no record of its own reads finished once control/closed names its session id" \
	"$( rigBare )" "finished"
rigClose "sess-one"
rigAssert "a bare session id in that line closes it too, the line being read by its first word" \
	"$( rigBare )" "finished"

echo "-- 2. another run's close is not its own --"
rigClose "run-other rig 2026-11-09T01:30:00Z"
rigAssert "control/closed naming another row leaves it failed, so the answer is the identity and not the file" \
	"$( rigBare )" "failed"

echo "-- 3. a live run is never finished by a close --"
## The activity word of a live run is read from marks this rig does not write, and an empty answer is that word's own. So the row
## asserts the one thing the close must not do to a live run: answer finished.
rigClose "sess-one rig 2026-11-09T01:30:00Z"
rigAssert "control: with no marks the activity of a live run is none of the two words this row is about" \
	"$( rigState spawn-started running sess-one "" )" ""
rigAssert "a run that is live is never finished by a close: liveness is read before the close" \
	"$( rigState spawn-started running sess-one "" | LC_ALL=C grep -c -x -F finished || : )" "0"

echo "-- 4. a run that carries its own id is closed by that id, and by no other --"
rigClose "run-other rig 2026-11-09T01:30:00Z"
rigAssert "control: control/closed naming another run leaves a run with its own id failed" \
	"$( rigState spawn-failed gone sess-one run-mine )" "failed"
rigClose "run-mine rig 2026-11-09T01:30:00Z"
rigAssert "and it reads finished once that line names its own id" \
	"$( rigState spawn-failed gone sess-one run-mine )" "finished"

echo
if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ REGISTRY RUN CLOSED CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount ))" >&2 ; exit 1
fi
echo "REGISTRY_RUN_CLOSED: OK ($rigPassCount assertions, offline, rig store only)"
