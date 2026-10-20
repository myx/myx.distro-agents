#!/usr/bin/env bash
## Behavioural check on the log of a spawned native session (F10.4 of the refactorings epic): the vendor client keeps its own log
## and names it in every hook payload (`transcript_path`); client-hooks/native-transcript-keep.sh keeps that log in the sandbox of
## the spawn, so the sandbox and the session hold the whole log of a native run. Held:
##   1. start (SessionStart) writes the pointers, the client's path in the sandbox and the kept copy's path in the session's store,
##      and copies nothing, so a run that never ends still says where its log is
##   2. keep (Stop) and end (SessionEnd) copy the log to <sandbox>/<id>.native.jsonl, byte for byte, mode 600, beside itself and
##      renamed over; a log that grew is copied again, one no longer than the copy is left alone, and a log that went is not
##      missed from the copy
##   3. nothing for a session the tooling did not spawn, for an id that is not the spawn's or not a bare name, and for a path that
##      is not absolute, not `<id>.jsonl`, or holds `..` or a backslash; nothing on stdout, and always exit 0
##   4. the client tool policy states the three hooks, as the native events they are, with the end's own timeout; the harness has
##      no counterpart for them
##   5. installed under <workspace>/.claude/hooks, it finds its workspace by its own place
## Offline: every path under one temp tree, no client, no network.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigHook="$rigHere/client-hooks/native-transcript-keep.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigHook" ] || rigRefuse "the hook is missing or not executable in the package: $rigHook"
[ -f "$rigHere/client/AgentsTools.ClientToolPolicy.include" ] || rigRefuse "the client tool policy is missing: $rigHere/client/AgentsTools.ClientToolPolicy.include"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsNativeTranscriptKeepCheck )" || exit 1
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

rigId="rig-native-1"
rigWs="$rigTmp/ws" ; rigSandbox="$rigWs/.local/agents/sandbox/rig" ; rigHome="$rigTmp/home"
rigLog="$rigHome/.claude/projects/-rig/$rigId.jsonl"
rigCopy="$rigSandbox/$rigId.native.jsonl"
rigStore="$rigWs/.local/agents/sessions/$rigId"
mkdir -p "$rigWs/.local/agents" "$rigSandbox" "$rigHome/.claude/projects/-rig"
printf '{"type":"user","message":"one"}\n' > "$rigLog"

rigPayload(){ ## session id, transcript path, event name
	printf '{"session_id":"%s","transcript_path":"%s","cwd":"%s","hook_event_name":"%s"}' "$1" "$2" "$rigWs" "$3"
}
rigRun(){ ## mode, payload, extra env assignments... -- the hook as the client runs it
	printf '%s' "$2" | env -i HOME="$rigHome" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDAT_SPAWN_SESSION_ID="$rigId" MDAT_SPAWN_SANDBOX_ROOT="$rigSandbox" "${@:3}" \
		bash "$rigHook" "$1" > "$rigTmp/hook.out" 2> "$rigTmp/hook.err"
	rigRc=$?
}
rigNothing(){ ## the files the hook leaves in the sandbox and the store, names, space-joined
	( cd "$rigSandbox" && ls -A ) | tr '\n' ' '
	[ -d "$rigStore" ] && ( cd "$rigStore" && ls -A ) | tr '\n' ' '
}
rigSame(){ ## two files -- same or differs
	cmp -s "$1" "$2" 2> /dev/null && printf same || printf differs
}
rigMode(){ ## file
	stat -f '%Lp' "$1" 2> /dev/null || stat -c '%a' "$1" 2> /dev/null
}

echo "-- 1. start: the pointers, no copy --"
rigRun start "$( rigPayload "$rigId" "$rigLog" SessionStart )"
rigAssert "the client's path is in the sandbox"                                        "$( cat "$rigSandbox/$rigId.native.path" 2> /dev/null )" "$rigLog"
rigAssert "the kept copy's path is in the session's store"                             "$( cat "$rigStore/native-log" 2> /dev/null )" "$rigCopy"
rigAssert "nothing is copied yet, nothing on stdout, exit 0"                          "$( [ -e "$rigCopy" ] && printf copied || printf none ):$( wc -c < "$rigTmp/hook.out" | tr -d ' ' ):$rigRc" none:0:0

echo "-- 2. keep and end: the copy --"
rigRun keep "$( rigPayload "$rigId" "$rigLog" Stop )"
rigAssert "keep copies the log, byte for byte"                                        "$( rigSame "$rigLog" "$rigCopy" )" same
rigAssert "mode 600"                                                                   "$( rigMode "$rigCopy" )" 600
rigAssert "no temp file is left beside it, nothing on stdout, exit 0"                  "$( ls "$rigSandbox" | LC_ALL=C grep -c 'native.jsonl\.' ):$( wc -c < "$rigTmp/hook.out" | tr -d ' ' ):$rigRc" 0:0:0
printf '{"type":"assistant","message":"two"}\n' >> "$rigLog"
rigRun end "$( rigPayload "$rigId" "$rigLog" SessionEnd )"
rigAssert "end copies the log that grew"                                              "$( rigSame "$rigLog" "$rigCopy" )" same
cp -p "$rigCopy" "$rigTmp/copy.before"
rigInodeBefore="$( ls -i "$rigCopy" | awk '{ print $1 }' )"
rigRun keep "$( rigPayload "$rigId" "$rigLog" Stop )"
rigAssert "a log no longer than the copy leaves the copy as it was, not written over"  "$( rigSame "$rigCopy" "$rigTmp/copy.before" ):$( [ "$( ls -i "$rigCopy" | awk '{ print $1 }' )" = "$rigInodeBefore" ] && printf same-file || printf rewritten )" same:same-file
rm -f "$rigLog"
rigRun end "$( rigPayload "$rigId" "$rigLog" SessionEnd )"
rigAssert "a log that went is not missed from the copy, and the hook is quiet"        "$( rigSame "$rigCopy" "$rigTmp/copy.before" ):$rigRc:$( wc -c < "$rigTmp/hook.out" | tr -d ' ' )" same:0:0
printf '{"type":"user","message":"one"}\n' > "$rigLog"

echo "-- 3. what it leaves alone --"
rm -rf "$rigSandbox" "$rigStore" ; mkdir -p "$rigSandbox"
rigRun keep "$( rigPayload "$rigId" "$rigLog" Stop )" MDAT_SPAWN_SESSION_ID=
rigAssert "no spawn session id: nothing"                                               "$( rigNothing ):$rigRc" ":0"
rigRun keep "$( rigPayload "$rigId" "$rigLog" Stop )" MDAT_SPAWN_SANDBOX_ROOT=
rigAssert "no sandbox: nothing"                                                        "$( rigNothing ):$rigRc" ":0"
rigRun keep "$( rigPayload "rig-other" "$rigHome/.claude/projects/-rig/rig-other.jsonl" Stop )"
rigAssert "a session that is not the spawn: nothing"                                   "$( rigNothing ):$rigRc" ":0"
rigRun keep "$( rigPayload "rig.native" "$rigHome/.claude/projects/-rig/rig.native.jsonl" Stop )" MDAT_SPAWN_SESSION_ID=rig.native
rigAssert "an id that is not a bare name: nothing"                                     "$( rigNothing ):$rigRc" ":0"
rigRun keep "$( rigPayload "$rigId" ".claude/projects/-rig/$rigId.jsonl" Stop )"
rigAssert "a relative path: nothing"                                                   "$( rigNothing ):$rigRc" ":0"
cp "$rigLog" "$rigHome/.claude/projects/-rig/$rigId.json"
rigRun keep "$( rigPayload "$rigId" "$rigHome/.claude/projects/-rig/$rigId.json" Stop )"
rigAssert "a path that is not a .jsonl: nothing"                                       "$( rigNothing ):$rigRc" ":0"
cp "$rigLog" "$rigHome/.claude/projects/-rig/other.jsonl"
rigRun keep "$( rigPayload "$rigId" "$rigHome/.claude/projects/-rig/other.jsonl" Stop )"
rigAssert "a file that is not <id>.jsonl: nothing"                                     "$( rigNothing ):$rigRc" ":0"
mkdir -p "$rigHome/.claude/projects/-rig/sub"
cp "$rigLog" "$rigHome/.claude/projects/-rig/sub/$rigId.jsonl"
rigRun keep "$( rigPayload "$rigId" "$rigHome/.claude/projects/-rig/sub/../sub/$rigId.jsonl" Stop )"
rigAssert "a path with .. in it: nothing"                                              "$( rigNothing ):$rigRc" ":0"
rigRun keep '{"session_id":"'"$rigId"'"}'
rigAssert "a payload with no transcript_path: nothing"                                 "$( rigNothing ):$rigRc" ":0"
rigRun keep 'this is not json'
rigAssert "a payload that is not JSON: nothing"                                        "$( rigNothing ):$rigRc" ":0"
rigRun keep "$( rigPayload "$rigId" "$rigLog" Stop )" MDAT_SPAWN_SANDBOX_ROOT="$rigTmp/no-such-folder"
rigAssert "a sandbox that is not a folder: nothing"                                    "$( rigNothing ):$rigRc" ":0"
rigRun nothing-else "$( rigPayload "$rigId" "$rigLog" Stop )"
rigAssert "a mode it does not know: nothing"                                           "$( rigNothing ):$rigRc" ":0"
rigRun keep "$( rigPayload "$rigId" "$rigLog" Stop )"
rigAssert "control: the same payload, as it should be, copies"                        "$( rigSame "$rigLog" "$rigCopy" ):$rigRc" same:0

echo "-- 4. the client tool policy --"
rigRecords="$( env -i PATH="/usr/bin:/bin" MDLT_ORIGIN="$MDLT_ORIGIN" MMDAPP="$MMDAPP" bash -c '. "$1/client/AgentsTools.ClientToolPolicy.include" && AgentsToolsClientToolPolicyHookRecords' rig "$rigHere" 2> /dev/null )"
rigRecordOf(){ ## arg -- the policy's record of the hook with that argument
	printf '%s\n' "$rigRecords" | LC_ALL=C awk -F '\t' -v arg="$1" '$5 == "native-transcript-keep.sh" && $6 == arg { print ; exit }'
}
rigAssert "SessionStart: the pointer, a native record, no matcher, no timeout"        "$( rigRecordOf start | LC_ALL=C tr '\t' '|' )" "SessionStart|native|.claude/hooks/native-transcript-keep.sh start||native-transcript-keep.sh|start"
rigAssert "Stop: the copy at the end of a turn"                                        "$( rigRecordOf keep | LC_ALL=C tr '\t' '|' )" "Stop|native|.claude/hooks/native-transcript-keep.sh keep||native-transcript-keep.sh|keep"
rigAssert "SessionEnd: the last copy, with its own 5 s"                                "$( rigRecordOf end | LC_ALL=C tr '\t' '|' )" "SessionEnd|native|.claude/hooks/native-transcript-keep.sh end||native-transcript-keep.sh|end|5"
rigAssert "the root session's own two hooks are as they were"                          "$( printf '%s\n' "$rigRecords" | LC_ALL=C grep -c 'root-session-end.sh' )" 2
rigAssert "the harness has no counterpart for them: its hook list holds none of them" \
	"$( env -i PATH="/usr/bin:/bin" MDLT_ORIGIN="$MDLT_ORIGIN" MMDAPP="$MMDAPP" BASH="$BASH" bash -c 'harnessHere="$1" ; harnessHooksList="" ; harnessHooksSkipped=0 ; harnessHooksFault="" ; . "$1/harness/AgentsHarnessHooksLoad.include" && . "$1/client/AgentsTools.ClientToolPolicy.include" && AgentsHarnessHooksFromRecords "$( AgentsToolsClientToolPolicyHookRecords )" && printf "%s" "$harnessHooksList"' rig "$rigHere" 2> /dev/null | LC_ALL=C grep -c 'native-transcript-keep' )" 0

echo "-- 5. installed under .claude/hooks, with no MMDAPP --"
mkdir -p "$rigWs/.claude/hooks"
cp "$rigHook" "$rigWs/.claude/hooks/native-transcript-keep.sh" && chmod 0755 "$rigWs/.claude/hooks/native-transcript-keep.sh"
rm -rf "$rigStore" ; mkdir -p "$rigWs/.local/agents"
rigPayload "$rigId" "$rigLog" SessionStart | env -i HOME="$rigHome" PATH="/usr/bin:/bin" MDAT_SPAWN_SESSION_ID="$rigId" MDAT_SPAWN_SANDBOX_ROOT="$rigSandbox" bash "$rigWs/.claude/hooks/native-transcript-keep.sh" start > /dev/null 2>&1
rigAssert "the session's store is found by the script's own place"                     "$( cat "$rigStore/native-log" 2> /dev/null )" "$rigCopy"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ NATIVE TRANSCRIPT KEEP CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'NATIVE_TRANSCRIPT_KEEP: OK (%d assertions, offline)\n' "$rigPassCount"
