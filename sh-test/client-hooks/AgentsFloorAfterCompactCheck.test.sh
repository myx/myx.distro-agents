#!/usr/bin/env bash
## Behavioural check on the floor of a spawned native session after its client compacted the conversation (owner's question of 2026-10-27:
## a compaction replaces the history with a summary, so what the member loaded on its way to armed may be gone). client-hooks/floor-after-compact.sh
## tells the member to load its floor again. Held:
##   1. Claude Code: the hook `serve` prints the pointer on stdout, naming the team's armed file and the member's own, and the client tool policy
##      states it as a native SessionStart hook with the matcher `compact`; the harness has no counterpart for it
##   2. nothing for a session the tooling did not spawn (no member), for a name that is no bare name, and the exit is always 0
##   3. Grok Build: PostCompact has no output, so `mark` keeps a marker; the next PreToolUse (`grok`) answers once with `additionalContext` as the
##      hook JSON says it, and the marker goes; without a mark it answers nothing
##   4. Copilot CLI: the same through preCompact (`mark`) and postToolUse (`copilot`), whose JSON is `additionalContext`
##   5. `config grok` and `config copilot` print valid hook files naming the events of the CLI and this script
## Offline: every path under one temp tree, no client, no network.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigHook="$rigHere/client-hooks/floor-after-compact.sh"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigHook" ] || rigRefuse "the hook is missing or not executable in the package: $rigHook"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsFloorAfterCompactCheck )" || exit 1
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
rigWs="$rigTmp/ws" ; rigId="rig-native-1"
mkdir -p "$rigWs/.local/agents"
rigRun(){ ## mode and arguments, then env assignments after `--` -- the hook as a client runs it, a payload on its stdin
	local runArgs=() runEnv=()
	while [ $# -gt 0 ] && [ "$1" != "--" ] ; do runArgs+=( "$1" ) ; shift ; done
	[ "${1:-}" != "--" ] || shift
	runEnv=( "$@" )
	printf '{"session_id":"%s","hook_event_name":"x"}' "$rigId" | env -i HOME="$rigTmp" PATH="/usr/bin:/bin" MMDAPP="$rigWs" "${runEnv[@]+"${runEnv[@]}"}" bash "$rigHook" "${runArgs[@]}" > "$rigTmp/hook.out" 2> "$rigTmp/hook.err"
	rigRc=$?
}
rigMarker="$rigWs/.local/agents/sessions/$rigId/floor-dropped"

echo "-- 1. Claude Code: SessionStart, matcher compact --"
rigRun serve -- MDAT_SPAWN_AGENT=rig-member MDAT_SPAWN_SESSION_ID="$rigId"
rigAssert "the pointer names the team's armed file and the member's own, and says it was compacted" \
	"$( LC_ALL=C grep -c -F 'magic-team.armed.md' "$rigTmp/hook.out" ):$( LC_ALL=C grep -c -F 'rig-member.armed.md' "$rigTmp/hook.out" ):$( LC_ALL=C grep -c -F 'was just compacted' "$rigTmp/hook.out" ):$rigRc" "1:1:1:0"
rigPolicy="$( . "$rigHere/client/AgentsTools.ClientToolPolicy.include" ; AgentsToolsClientToolPolicyHookRecords )"
rigAssert "the client tool policy wires it as a native SessionStart hook with the matcher compact" \
	"$( printf '%s\n' "$rigPolicy" | LC_ALL=C awk -F '\t' '$1 == "SessionStart" && $2 == "native" && $4 == "compact" && $5 == "floor-after-compact.sh" && $6 == "serve"' | wc -l | tr -d ' ' )" "1"

echo "-- 2. nothing for a session the tooling did not spawn, and always exit 0 --"
rigRun serve -- MDAT_SPAWN_SESSION_ID="$rigId"
rigAssert "no member: nothing on stdout, exit 0" "$( wc -c < "$rigTmp/hook.out" | tr -d ' ' ):$rigRc" "0:0"
rigRun serve -- MDAT_SPAWN_AGENT='../evil;x' MDAT_SPAWN_SESSION_ID="$rigId"
rigAssert "a name that is no bare name: nothing on stdout, exit 0" "$( wc -c < "$rigTmp/hook.out" | tr -d ' ' ):$rigRc" "0:0"

echo "-- 3. Grok Build: PostCompact marks, the next PreToolUse answers once --"
rigRun grok -- MDAT_SPAWN_AGENT=rig-member MDAT_SPAWN_SESSION_ID="$rigId"
rigAssert "without a mark the PreToolUse hook answers nothing" "$( wc -c < "$rigTmp/hook.out" | tr -d ' ' ):$rigRc" "0:0"
rigRun mark -- MDAT_SPAWN_AGENT=rig-member MDAT_SPAWN_SESSION_ID="$rigId"
rigAssert "the compaction hook prints nothing and keeps the marker" "$( wc -c < "$rigTmp/hook.out" | tr -d ' ' ):$( [ -f "$rigMarker" ] && echo marked )" "0:marked"
rigRun grok -- MDAT_SPAWN_AGENT=rig-member MDAT_SPAWN_SESSION_ID="$rigId"
rigAssert "the next tool hook answers with additionalContext in Grok's hook JSON, and the marker goes" \
	"$( python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); o=d["hookSpecificOutput"]; print(o["hookEventName"], "rig-member.armed.md" in o["additionalContext"])' "$rigTmp/hook.out" 2> /dev/null ):$( [ -f "$rigMarker" ] && echo marked || echo clear )" "PreToolUse True:clear"
rigRun grok -- MDAT_SPAWN_AGENT=rig-member MDAT_SPAWN_SESSION_ID="$rigId"
rigAssert "and it answers once: the next call says nothing" "$( wc -c < "$rigTmp/hook.out" | tr -d ' ' )" "0"

echo "-- 4. Copilot CLI: preCompact marks, the next postToolUse answers once --"
rigRun mark -- MDAT_SPAWN_AGENT=rig-member MDAT_SPAWN_SESSION_ID="$rigId"
rigRun copilot -- MDAT_SPAWN_AGENT=rig-member MDAT_SPAWN_SESSION_ID="$rigId"
rigAssert "the postToolUse hook answers with additionalContext as Copilot's JSON says it" \
	"$( python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); print("magic-team.armed.md" in d["additionalContext"])' "$rigTmp/hook.out" 2> /dev/null ):$( [ -f "$rigMarker" ] && echo marked || echo clear )" "True:clear"

echo "-- 5. the hook files the owner puts in place --"
rigRun config grok
rigAssert "config grok: valid JSON, PostCompact marks and PreToolUse serves, both this script" \
	"$( python3 -I -c 'import json,sys; h=json.load(open(sys.argv[1]))["hooks"]; print(h["PostCompact"][0]["hooks"][0]["command"].endswith("floor-after-compact.sh mark"), h["PreToolUse"][0]["hooks"][0]["command"].endswith("floor-after-compact.sh grok"))' "$rigTmp/hook.out" 2> /dev/null )" "True True"
rigRun config copilot
rigAssert "config copilot: valid JSON, preCompact marks and postToolUse serves, both this script" \
	"$( python3 -I -c 'import json,sys; h=json.load(open(sys.argv[1])); x=h["hooks"]; print(h["version"], x["preCompact"][0]["bash"].endswith("floor-after-compact.sh mark"), x["postToolUse"][0]["bash"].endswith("floor-after-compact.sh copilot"))' "$rigTmp/hook.out" 2> /dev/null )" "1 True True"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ FLOOR AFTER COMPACT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'FLOOR_AFTER_COMPACT: OK (%d assertions, offline)\n' "$rigPassCount"
