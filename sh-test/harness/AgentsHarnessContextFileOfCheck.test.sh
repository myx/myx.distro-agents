#!/usr/bin/env bash
## Behavioural check of where a run keeps its model context (AgentsHarnessContextFileOf): a sandbox folder is its session's,
## shared by every run that joined the session, so two runs never keep one file. A run takes context.jsonl where it is free
## or its header names the run; where another run's header holds it, the run keeps context.<spawn id>.jsonl, and goes on
## keeping that one. The folder's own name decides nothing (a folder is named for its session, or for a tracking name). The
## resume reads the run's own file by the same rule (AgentsTools.HarnessResume.include). Offline: a temp folder only.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessContext.include"
rigResume="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsTools.HarnessResume.include"
[ -f "$rigLib" ] && [ -f "$rigResume" ] || { echo "⛔ ERROR: a library is not at the origin -- refusing to report a result" >&2 ; exit 1 ; }
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsHarnessContextFileOfCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigOf(){ ## sandbox folder, spawn id
	( harnessHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib" ; . "$rigLib" 2> /dev/null ; AgentsHarnessContextFileOf "$1" "$2" )
}
rigRoot="$rigTmp/spawned/sess-folder"
mkdir -p "$rigRoot"

echo "-- the first run of a folder takes context.jsonl, whatever the folder is named --"
rigAssert "a free context.jsonl is taken"                       "$( rigOf "$rigRoot" run-exec )" "$rigRoot/context.jsonl"
printf '{"type":"context","version":1,"session":"run-exec","member":"rig-coordinator"}\n' > "$rigRoot/context.jsonl"
rigAssert "and kept: its header names the run"                  "$( rigOf "$rigRoot" run-exec )" "$rigRoot/context.jsonl"

echo "-- a run that joined the session never takes the file another run holds --"
rigAssert "a joined run: context.<its spawn id>.jsonl"           "$( rigOf "$rigRoot" run-joined )" "$rigRoot/context.run-joined.jsonl"
rigAssert "a trailing slash on the folder changes nothing"       "$( rigOf "$rigRoot/" run-joined )" "$rigRoot/context.run-joined.jsonl"
printf '{"type":"context","version":1,"session":"run-joined","member":"rig-developer"}\n' > "$rigRoot/context.run-joined.jsonl"
rigAssert "it goes on keeping its own"                          "$( rigOf "$rigRoot" run-joined )" "$rigRoot/context.run-joined.jsonl"
rigAssert "and the first run keeps context.jsonl"               "$( rigOf "$rigRoot" run-exec )" "$rigRoot/context.jsonl"
rigAssert "the first run's file is untouched by the lookups"    "$( head -1 "$rigRoot/context.jsonl" )" '{"type":"context","version":1,"session":"run-exec","member":"rig-coordinator"}'

echo "-- the context is placed by that rule, and the resume reads the run's own file --"
rigAssert "the harness places its context by AgentsHarnessContextFileOf" "$( LC_ALL=C grep -c -F 'harnessContextFile="$( AgentsHarnessContextFileOf "$MDAT_SPAWN_SANDBOX_ROOT" "$MDAT_SPAWN_SESSION_ID" )"' "$rigLib" )" 1
rigAssert "the resume prefers context.<spawn id>.jsonl, else context.jsonl" \
	"$( LC_ALL=C grep -c -F 'if [ -f "${ctxRecord%/*}/context.$ctxSpawn.jsonl" ] ; then ctxFile="${ctxRecord%/*}/context.$ctxSpawn.jsonl" ; else ctxFile="${ctxRecord%/*}/context.jsonl" ; fi' "$rigResume" )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ HARNESS CONTEXT FILE OF CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'HARNESS_CONTEXT_FILE_OF: OK (%d assertions, offline, temp folder only)\n' "$rigPassCount"
