#!/usr/bin/env bash
## The PreToolUse hook client-hooks/allow-granted-native-tool.sh, run as a *-native client
## runs it, with a payload on stdin, against a rig workspace whose grants index is built from
## hand-written registries:
##   1. a spawned member: a native Read, Edit, Write, MultiEdit, NotebookEdit, Grep or Glob call
##      its session permission index grants is answered allow;
##   2. a call it is not granted gets no answer at all, so the client and the PermissionRequest
##      hook decide it as before; so does a tool the hook does not decide, and a payload it
##      cannot read;
##   3. a write in a read-only place is denied first, naming where to write instead;
##   4. the human own session (no spawn identity) gets no answer, and the reroute hook still
##      denies it;
##   5. our own harness never runs it (class native).
## Offline: HOME, the workspace and every registry are this rig own.
## Every tool_input object is built by rigObj and passed in a variable: a literal {a,b} inside
## "$( )" is brace-expanded by bash 3.2 into several words.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigHere="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigHook="$rigHere/client-hooks/allow-granted-native-tool.sh"
rigReroute="$rigHere/client-hooks/deny-native-tool-reroute.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigHook" "$rigReroute" "$rigHere/AgentsTools.Grants.include" "$rigHere/AgentsHarnessHooksLoad.include" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
rigTmp="$( mktemp -d -t AgentsClientHookAllowGrantedCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigPass=0 rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$#" -ne 3 ] ; then
		printf '  FAIL  %s\n        the assertion took %s arguments, not 3\n' "$1" "$#" ; rigFail=$(( rigFail + 1 )) ; return 0
	fi
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

## rig-member: a write grant, and a read grant in a read-only place; rig-other: a grant of its own.
rigWs="$rigTmp/ws"
mkdir -p "$rigTmp/home" "$rigWs/.local/agents" "$rigTmp/granted" "$rigTmp/places/ro" "$rigTmp/others" "$rigTmp/sandbox/input" "$rigTmp/sandbox/output"
printf '%s\t%s\t%s\t%s\t%s\n' "ws" workspace read-write "$rigWs" workspace "ro" directory read-only "$rigTmp/places/ro" owner > "$rigWs/.local/agents/directories.registry"
printf 'rig-member:ws:workspace:Edit(/%s/granted/**)\nrig-member:ws:directory:Read(/%s/places/ro/**)\nrig-other:ws:workspace:Edit(/%s/others/**)\n' \
	"$rigTmp" "$rigTmp" "$rigTmp" > "$rigWs/.local/agents/permissions.registry"
for rigOne in granted/a.txt others/a.txt places/ro/a.txt ; do printf 'rig-seed\n' > "$rigTmp/$rigOne" ; done

rigObj(){ ## key, raw JSON string text, ... -- one object of string members, the text not escaped again
	local objOut="" objSep=""
	while [ "$#" -ge 2 ] ; do
		objOut="$objOut$objSep\"$1\":\"$2\"" ; objSep=","
		shift 2
	done
	printf '{%s}' "$objOut"
}
rigPayload(){ ## tool, tool_input object -- one PreToolUse payload
	printf '{"session_id":"s-rig","transcript_path":"%s/t.jsonl","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"%s","tool_input":%s}' "$rigTmp" "$rigTmp/granted" "$1" "$2"
}
rigHookRun(){ ## spawn agent (empty: none), tool, tool_input object, [extra env]... -- allow, deny:<reason>, none, or rc:<n>
	local runAgent="$1" runTool="$2" runInput="$3" runRc=0 runOut ; shift 3
	runOut="$( rigPayload "$runTool" "$runInput" | env -i HOME="$rigTmp/home" PATH=/usr/bin:/bin MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		${runAgent:+MDAT_SPAWN_AGENT="$runAgent"} ${runAgent:+MDAT_SPAWN_SESSION_ID=s-rig} "$@" bash "$rigHook" 2> "$rigTmp/hook.err" )" || runRc=$?
	[ "$runRc" = 0 ] || { printf 'rc:%s' "$runRc" ; return 0 ; }
	case "$runOut" in
		'') printf none ;;
		*'"permissionDecision": "allow"'*) printf allow ;;
		*'"permissionDecision": "deny"'*) printf 'deny:%s' "$( printf '%s' "$runOut" | LC_ALL=C sed -n 's/.*"permissionDecisionReason": "\(.*\)"$/\1/p' )" ;;
		*) printf 'other:%s' "$runOut" ;;
	esac
}

echo "-- 1. a spawned member: what its session index grants is allowed --"
rigIn="$( rigObj file_path "$rigTmp/granted/a.txt" old_string a new_string b )"
rigAssert "Edit of a granted file"            "$( rigHookRun rig-member Edit "$rigIn" )" allow
rigIn="$( rigObj content "\\\"file_path\\\":\\\"$rigTmp/others/a.txt\\\"" file_path "$rigTmp/granted/new.txt" )"
rigAssert "Write of a new file there, content naming another path first" "$( rigHookRun rig-member Write "$rigIn" )" allow
rigIn="$( rigObj content "\\\"file_path\\\":\\\"$rigTmp/granted/new.txt\\\"" file_path "$rigTmp/others/new.txt" )"
rigAssert "control: the same content, its own path not granted" "$( rigHookRun rig-member Write "$rigIn" )" none
rigIn="$( rigObj file_path "$rigTmp/granted/a.txt" )"
rigAssert "MultiEdit, decided as Edit"        "$( rigHookRun rig-member MultiEdit "$rigIn" )" allow
rigIn="$( rigObj notebook_path "$rigTmp/granted/n.ipynb" new_source x )"
rigAssert "NotebookEdit, by its notebook_path" "$( rigHookRun rig-member NotebookEdit "$rigIn" )" allow
rigIn="$( rigObj file_path "$rigTmp/granted/a.txt" )"
rigAssert "Read, a write grant reading too"   "$( rigHookRun rig-member Read "$rigIn" )" allow
rigIn="$( rigObj pattern rig path "$rigTmp/granted" )"
rigIn2="$( rigObj pattern '*.txt' )"
rigAssert "Grep by its path, Glob by the cwd" "$( rigHookRun rig-member Grep "$rigIn" ):$( rigHookRun rig-member Glob "$rigIn2" )" "allow:allow"
rigIn="$( rigObj file_path a.txt old_string a new_string b )"
rigAssert "a relative path, against the cwd"  "$( rigHookRun rig-member Edit "$rigIn" )" allow
rigIn="$( rigObj file_path "$rigTmp/places/ro/a.txt" )"
rigAssert "a read grant reads in a read-only place" "$( rigHookRun rig-member Read "$rigIn" )" allow
rigAssert "control: the session index was built in the session store" "$( [ -f "$rigWs/.local/agents/sessions/s-rig/permissions.rig-member.index" ] && printf built || printf absent )" built

echo "-- 2. not granted: no answer, the existing flow decides --"
rigIn="$( rigObj file_path "$rigTmp/others/a.txt" old_string a new_string b )"
rigAssert "Edit of the grant of another member" "$( rigHookRun rig-member Edit "$rigIn" )" none
rigAssert "control: rig-other is granted its own" "$( rigHookRun rig-other Edit "$rigIn" )" allow
rigIn="$( rigObj file_path "$rigTmp/others/a.txt" )"
rigAssert "Read of it"                        "$( rigHookRun rig-member Read "$rigIn" )" none
rigIn="$( rigObj pattern rig path "$rigTmp/others" )"
rigAssert "Grep with no grant on its root"    "$( rigHookRun rig-member Grep "$rigIn" )" none
rigIn="$( rigObj command "ls $rigTmp/granted" )"
rigAssert "a tool it does not decide"         "$( rigHookRun rig-member Bash "$rigIn" )" none
rigIn="$( rigObj file_path "$rigTmp/granted/\\u0061.txt" old_string a new_string b )"
rigAssert "a path it cannot decode"           "$( rigHookRun rig-member Edit "$rigIn" )" none
rigIn="$( rigObj file_path "$rigTmp/granted/../others/a.txt" old_string a new_string b )"
rigAssert "a path with a .. segment"          "$( rigHookRun rig-member Edit "$rigIn" )" none

echo "-- 3. a write in a read-only place: denied first --"
rigIn="$( rigObj file_path "$rigTmp/places/ro/a.txt" old_string a new_string b )"
rigAssert "Edit there, with no sandbox"       "$( rigHookRun rig-member Edit "$rigIn" )" \
	"deny:ro is a read-only place, so nothing is written there: $rigTmp/places/ro/a.txt -- find another suitable location"
rigIn="$( rigObj file_path "$rigTmp/places/ro/b.txt" content x )"
rigAssert "Write there, the sandbox output named" "$( rigHookRun rig-member Write "$rigIn" MDAT_SPAWN_SANDBOX_ROOT="$rigTmp/sandbox" )" \
	"deny:ro is a read-only place, so nothing is written there: $rigTmp/places/ro/b.txt -- write to your session sandbox output/ instead, or a folder under it: $rigTmp/sandbox/output/"

echo "-- 4. the human own session: unchanged --"
rigIn="$( rigObj file_path "$rigTmp/granted/a.txt" old_string a new_string b )"
rigAssert "no spawn identity: no answer"      "$( rigHookRun "" Edit "$rigIn" )" none
rigAssert "and the reroute hook still denies it" "$( rigPayload Edit "$rigIn" | env -i HOME="$rigTmp/home" PATH=/usr/bin:/bin bash "$rigReroute" Edit | LC_ALL=C grep -c '"permissionDecision": "deny"' )" 1

echo "-- 5. our own harness never runs it --"
rigAssert "the policy states it, class native" "$( env -i PATH=/usr/bin:/bin MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '. "'"$rigHere"'/AgentsTools.ClientToolPolicy.include" ; AgentsToolsClientToolPolicyHookRecords' | LC_ALL=C awk -F'\t' '$5 == "allow-granted-native-tool.sh" { print $1 ":" $2 ":" $4 }' )" "PreToolUse:native:Read|Edit|Write|MultiEdit|NotebookEdit|Grep|Glob"
rigAssert "and the harness hook list leaves it out, with no fault" "$( env -i PATH=/usr/bin:/bin MDLT_ORIGIN="$MDLT_ORIGIN" bash -c '
	. "'"$rigHere"'/AgentsTools.ClientToolPolicy.include" ; . "'"$rigHere"'/AgentsHarnessHooksLoad.include"
	harnessHooksList="" harnessHooksFault="" harnessHooksSkipped=0
	AgentsHarnessHooksFromRecords "$( AgentsToolsClientToolPolicyHookRecords )"
	printf "%s:%s" "[$harnessHooksFault]" "$( printf "%s" "$harnessHooksList" | LC_ALL=C grep -c allow-granted-native-tool )"
' )" "[]:0"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ CLIENT HOOK ALLOW GRANTED CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'CLIENT_HOOK_ALLOW_GRANTED: OK (%d assertions, offline, rig HOME only)\n' "$rigPass"
