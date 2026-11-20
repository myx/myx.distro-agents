#!/usr/bin/env bash
## Behavioural check of the pace's reading of a batch (the owner's pace ruling): the pace counts each call inside a batch as one
## call, at its own tooling time -- its whole time less what it ran, as a Bash call's child run is left out -- and the batch itself
## counts nothing. Held:
##   1. a batch of three calls of 1, 2 and 3 s leaves one value a call, each near its own span, and the pace counts three calls.
##   1b. a call that runs 3 s of a 4 s span counts its span less that run, and the same span keeping nothing counts it whole.
##   2. the same values, recorded as calls made on their own, read exactly as the batch reads.
##   3. a batch record carrying only its whole span and no per-call values counts no call, so it cannot inflate the pace.
##   4. the MCP path: a batch of two calls leaves one store row a call, and no row for the batch.
## Offline: the batch engine, the context include and the pace reader of MDLT_ORIGIN, a rig workspace of this check's own, and a
## stand-in call that sleeps its span.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
rigBatchLib="$rigPkg/sh-lib/harness/AgentsTools.BatchTools.include"
rigContextLib="$rigPkg/sh-lib/harness/AgentsHarnessContext.include"
[ -f "$rigBatchLib" ] && [ -f "$rigContextLib" ] || rigRefuse "the batch engine or the context include is not at MDLT_ORIGIN: $MDLT_ORIGIN"
[ -f "$rigPkg/sh-lib/schedule/AgentsTools.DispatcherSchedule.include" ] || rigRefuse "the pace reader is not at MDLT_ORIGIN"
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsBatchToolsPaceCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+wX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/agents/spawned/rig-run" "$rigWs/.local/agents/schedule" || exit 1
export MMDAPP="$rigWs" MDAT_TOOL_PACE_CACHE_SECONDS=0 MDAT_TOOL_PACE_WINDOW_SECONDS=300
cd "$rigWs" || exit 1
set -- check
. "$rigPkg/sh-lib/schedule/AgentsTools.DispatcherSchedule.include" > /dev/null 2>&1 || rigRefuse "the pace reader would not load"
rigPace(){ AgentsToolsSchedulePaceText ; }

## The live shape of a run: a spawn record saying it started, and the run's one context file.
printf -- '---\nspawn-id: rig-run\nsession-id: rig-run\nowner: magic-developer\nstatus: spawn-started\n---\n' > "$rigWs/.local/agents/spawned/rig-run/rig-run.spawn.md"
rigNowMs="$(( $( date +%s ) * 1000 ))"
rigRecord(){ ## the meta of one tool record, after its own clock fields
	printf '{"type":"message","n":1,"leg":1,"kind":"tool","round":1,"ts":"2026-11-17T00:00:00Z","ms":%s,"tool":"%s"%s,"record":{"role":"tool"}}\n' "$rigNowMs" "$1" "$2"
}

## A batch of calls whose spans are the seconds given, by the real engine. A call that keeps nothing shows its whole span as its
## tooling time, as a Read's is; one that keeps a run has that taken from its span, as a Bash call's child run is.
rigBatch(){ ## seconds for each call -- the record meta the batch leaves
	rigCallArgs="" rigSeconds=""
	for rigSeconds in "$@" ; do
		rigCallArgs="$rigCallArgs${rigCallArgs:+,}{\"tool\":\"span-${rigSeconds}keep-0\",\"arguments\":{}}"
	done
	rigBatchCalls "$#" "$rigCallArgs"
}
rigBatchSpan(){ ## one call name, span and kept run in it, as `3keep-1`
	rigBatchCalls 1 "{\"tool\":\"span-$1\",\"arguments\":{}}"
}
rigBatchCalls(){ ## how many calls, the calls list -- the record meta the batch leaves
	(
		harnessHere="$rigPkg/sh-lib" ; harnessScratch="$rigTmp/scratch"
		harnessAgent=magic-developer ; harnessOff='' ; harnessBad='' ; harnessWarn='' ; harnessTool='' ; harnessValue='' ; harnessDim='' harnessTitleActive=''
		harnessPlaceOnly='' ; harnessToolOnly='' ; harnessToolRunMs=""
		mkdir -p "$harnessScratch" || exit 1
		. "$rigPkg/sh-lib/session/AgentsTools.SessionTranscript.include" || exit 1
		. "$rigContextLib" || exit 1
		. "$rigBatchLib" || exit 1
		rigSleepServes(){ return 0 ; }
		rigSleepCall(){ ## tool name, arguments file, call number -- runs for its span, and keeps what its name says it ran
			local sleepName sleepSeconds sleepKeep
			sleepName="${1#span-}"
			sleepSeconds="${sleepName%keep-*}"
			sleepKeep="${sleepName#*keep-}"
			sleep "$sleepSeconds"
			## What the call itself ran, kept exactly as the harness call body keeps it (AgentsHarnessBatchCallBody).
			printf '%s\n' "$(( sleepKeep * 1000 ))" > "${2%.args}.ran" 2> /dev/null || :
			printf 'rig call %s\n' "$3"
		}
		agentsTranscriptT0=$(( $( date +%s )000 - 6000 ))
		rigOut="$( AgentsToolsBatchRun rigSleepCall rigSleepServes "{\"mode\":\"sequence-all-through\",\"calls\":[$2]}" )"
		case "$rigOut" in *"BATCH-RESULT: sequence-all-through $1/$1"*) ;; *) printf 'RIG-BATCH-FAILED: %s\n' "$rigOut" ; exit 1 ;; esac
		AgentsHarnessContextToolMeta BatchTools call-1 "$rigOut" ""
	) || exit 1
}
## The numbers of a record's per-call field, one a line; nothing where the record carries none.
rigCalls(){ ## meta
	printf '%s' "$1" | LC_ALL=C awk '{ if ( ! match( $0, /"calls_mach_ms":\[[0-9,]*\]/ ) ) exit ; list = substr( $0, RSTART + 17, RLENGTH - 18 ) ; count = split( list, part, "," ) ; for ( at = 1 ; at <= count ; at++ ) if ( part[at] != "" ) print part[at] ; }'
}

echo "-- 1. a batch of three calls reads as three calls, each at its own tooling time --"
rigMeta="$( rigBatch 1 2 3 )"
case "$rigMeta" in *'"tool":"BatchTools"'*) ;; *) rigRefuse "the batch left no record meta: $rigMeta" ;; esac
rigValues="$( rigCalls "$rigMeta" )"
rigAssert "the batch's record carries one value for each of its three calls" "$( printf '%s\n' "$rigValues" | LC_ALL=C grep -c . )" 3
rigAssert "each value is that call's own span, 1 s, 2 s and 3 s, within the second the record keeps: $( printf '%s' "$rigValues" | LC_ALL=C tr '\n' ' ' )" \
	"$( printf '%s\n' "$rigValues" | LC_ALL=C awk -v spans="1 2 3" 'BEGIN { count = split( spans, span, " " ) ; } { at++ ; if ( at > count ) next ; if ( $1 < span[at] * 1000 || $1 > ( span[at] + 1 ) * 1000 ) bad = 1 ; } END { print ( bad || at != count ) ? "off" : "near" ; }' )" near
rigRecord BatchTools "$rigMeta" > "$rigWs/.local/agents/spawned/rig-run/context.jsonl"
rigBatchPace="$( rigPace )"
case "$rigBatchPace" in
	*' 3 calls in 5 minutes '*) rigBatchCount=three ;;
	*) rigBatchCount="$rigBatchPace" ;;
esac
rigAssert "the pace counts three calls, not the batch's one" "$rigBatchCount" three

echo "-- 1b. a call that runs 3 s of a 4 s span counts 1 s of tooling time, as a Bash child's run is left out --"
rigKeptMeta="$( rigBatchSpan "4keep-3" )"
rigKeptValues="$( rigCalls "$rigKeptMeta" )"
rigWholeMeta="$( rigBatchSpan "4keep-0" )"
rigWholeValues="$( rigCalls "$rigWholeMeta" )"
rigAssert "the call's tooling time is its 4 s span less the 3 s it ran, so under 2 s: $( printf '%s' "$rigKeptValues" )" \
	"$( printf '%s\n' "$rigKeptValues" | LC_ALL=C awk '{ print ( $1 >= 0 && $1 <= 2000 ) ? "under" : "off:" $1 ; }' )" under
rigAssert "control: the same 4 s span with nothing kept reads its whole span or more: $( printf '%s' "$rigWholeValues" )" \
	"$( printf '%s\n' "$rigWholeValues" | LC_ALL=C awk '{ print ( $1 >= 3000 ) ? "whole" : "off:" $1 ; }' )" whole
rigAssert "the harness call body keeps what its call ran where the engine reads it" \
	"$( LC_ALL=C grep -c -F '${2%.args}.ran' "$rigPkg/sh-lib/harness/AgentsHarnessBatch.include" 2> /dev/null || : )" 1

echo "-- 2. the same three values, made as calls on their own, read exactly as the batch does --"
: > "$rigWs/.local/agents/spawned/rig-run/context.jsonl"
for rigValue in $rigValues ; do
	rigRecord sleep "$( printf ',"dur_ms":%s,"mach_ms":%s,"outcome":"ok"' "$rigValue" "$rigValue" )" >> "$rigWs/.local/agents/spawned/rig-run/context.jsonl"
done
rigAlonePace="$( rigPace )"
rigAssert "one line says it: a batch reads as its calls made alone" "$rigBatchPace" "$rigAlonePace"

echo "-- 3. the control: the record live leaves today, one whole span and no per-call values, inflates nothing --"
rigRecord BatchTools "$( printf ',"dur_ms":%s,"mach_ms":%s,"outcome":"ok"' 6000 6000 )" > "$rigWs/.local/agents/spawned/rig-run/context.jsonl"
rigLiveShapePace="$( rigPace )"
case "$rigLiveShapePace" in *'0 calls'*|*'no live run made a call'*) rigLiveShape=inert ;; *) rigLiveShape="$rigLiveShapePace" ;; esac
rigAssert "a batch record carrying only its whole span counts no call, so it cannot inflate the pace: $rigLiveShapePace" "$rigLiveShape" inert

echo "-- 4. the MCP path: a batch of two calls leaves one row a call, and no row for the batch --"
mkdir -p "$rigWs/home" "$rigWs/fix"
printf 'RIG-A\n' > "$rigWs/fix/a.txt"
printf '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"BatchTools","arguments":{"mode":"sequence-all-through","calls":[{"tool":"Read","arguments":{"file_path":"%s"}},{"tool":"Read","arguments":{"file_path":"%s"}}]}}}\n' "$rigWs/fix/a.txt" "$rigWs/fix/a.txt" \
	| ( cd "$rigWs/fix" && env -u CLAUDE_CODE_SESSION_ID MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" HOME="$rigWs/home" CLAUDE_CODE_SESSION_ID=rig-batch-pace \
	bash "$rigPkg/sh-scripts/DistroAgentsTools.fn.sh" --intern-mcp-server --run ) > "$rigWs/mcp.wire" 2> /dev/null
rigAssert "the served batch ran both of its calls" "$( LC_ALL=C grep -o -F 'BATCH-ENTRY: ' "$rigWs/mcp.wire" | LC_ALL=C grep -c . )" 2
rigAssert "the store holds a row for each call, and none for the batch" \
	"$( LC_ALL=C awk '{ print $3 ; }' "$rigWs/.local/agents/schedule/pace.mcp" 2> /dev/null | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "Read Read "

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ BATCH TOOLS PACE CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'BATCH_TOOLS_PACE: OK (%d assertions, offline, rig workspace only)\n' "$rigPassCount"
