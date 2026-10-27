#!/usr/bin/env bash
## Behavioural check: the session permission index takes its header, the session's sandbox
## folders and this origin's skillset byte for byte (AgentsToolsGrantsSessionText,
## AgentsTools.Grants.include). They are text, and go to AgentsGrantsSessionIndex.awk in the
## environment. Passed with -v, awk decoded every backslash in them: a path holding one gave a
## floor row for another path, and a header no check found current, so the index was rebuilt
## at every call.
##   1. a sandbox whose path holds backslashes, through the native client's hook: its output/
##      is written and its input/ read by the floor, the index's header is the session's own,
##      and the next check reuses the index;
##   2. an origin skillset whose path holds them, through AgentsToolsGrantsSessionEnsure: read
##      by the floor, the header the session's own, the index reused;
##   3. the awk reads each value from the environment, and from -v where the environment names
##      none, as a harness started before they moved there still passes them.
## Red recipe: hand the header and the sandbox folders to the awk with -v again in
## AgentsToolsGrantsSessionText, and section 1 fails on the Write into the sandbox.
## Offline: HOME, the workspace and its registries are this rig's own.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigHook="$rigLib/client-hooks/allow-granted-native-tool.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigHook" "$rigLib/grants/AgentsTools.Grants.include" "$rigLib/grants/AgentsGrantsPattern.awk" "$rigLib/grants/AgentsGrantsSessionIndex.awk" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionIndexExactValuesCheck )" || exit 1
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

## The rig workspace, and two folders whose names hold a backslash before a t and before an n:
## two characters each on disk, a tab and a newline once awk has decoded them.
rigWs="$rigTmp/ws"
rigSessions="$rigWs/.local/agents/sessions"
rigSandbox="$rigTmp/sand\tbox\name"
rigOrigin="$rigTmp/ori\tgin\name/skillset"
mkdir -p "$rigTmp/home" "$rigWs/.local/agents" "$rigSandbox/input" "$rigSandbox/output" "$rigOrigin" "$rigTmp/elsewhere"
printf '%s\t%s\t%s\t%s\t%s\n' "ws" workspace read-write "$rigWs" workspace > "$rigWs/.local/agents/directories.registry"
printf 'rig-other:ws:workspace:Edit(/%s/elsewhere/**)\n' "$rigTmp" > "$rigWs/.local/agents/permissions.registry"
printf 'rig-seed\n' > "$rigSandbox/input/i.txt"
printf 'rig-seed\n' > "$rigOrigin/x.md"
case "$rigSandbox" in *'\t'*'\n'*) ;; *) rigRefuse "the rig's sandbox path holds no backslash" ;; esac
[ -d "$rigSandbox/output" ] && [ -d "$rigOrigin" ] || rigRefuse "the rig's folders with a backslash in their names could not be made"
## A second on, so the grants index built at the first check is strictly newer than the
## registries it is made from, and is built once.
sleep 1
rigVersion="myx.distro session.permissions.index 1"

## The native client's PreToolUse hook asked about one call of rig-member, in the rig's sandbox.
## It decides by the session index alone: `allow <what admitted it>`, `none`, else `deny`.
rigHookSays(){ ## tool, path
	local hookOut hookPath="${2//\\/\\\\}"
	printf '{"session_id":"s-rig","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"%s","tool_input":{"file_path":"%s","content":"rig"}}' "$rigTmp" "$1" "$hookPath" > "$rigTmp/hook.in"
	hookOut="$( env -i HOME="$rigTmp/home" PATH=/usr/bin:/bin:/usr/sbin:/sbin MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SPAWN_AGENT=rig-member MDAT_SPAWN_SESSION_ID=s-rig MDAT_SPAWN_SANDBOX_ROOT="$rigSandbox" bash "$rigHook" < "$rigTmp/hook.in" 2> "$rigTmp/hook.err" )"
	case "$hookOut" in
		'') printf 'none' ;;
		*'"permissionDecision": "allow"'*) printf 'allow %s' "$( printf '%s\n' "$hookOut" | LC_ALL=C sed -n 's/.*"permissionDecisionReason": "granted to rig-member: \(.*\)"$/\1/p' )" ;;
		*) printf 'deny' ;;
	esac
}
## Whether a file was written since the rig's marker.
rigSince(){ ## file
	if [ "$1" -nt "$rigTmp/marker" ] ; then printf 'rebuilt' ; else printf 'reused' ; fi
}

## ---------------------------------------------------------------- the sandbox
echo "-- 1. a sandbox whose path holds backslashes: its floor rows and the header are exact --"
rigIndex="$rigSessions/s-rig/permissions.rig-member.index"
rigAssert "a Write into its output/ is admitted, by the floor" "$( rigHookSays Write "$rigSandbox/output/f.txt" )" "allow floor"
rigAssert "a Read in its input/ is admitted, by the floor"  "$( rigHookSays Read "$rigSandbox/input/i.txt" )" "allow floor"
rigAssert "control: a Write into its input/ is not, nor one elsewhere" "$( rigHookSays Write "$rigSandbox/input/i.txt" ):$( rigHookSays Write "$rigTmp/elsewhere/e.txt" )" none:none
rigAssert "the index's header is the session's own, byte for byte" "$( head -1 "$rigIndex" 2> /dev/null )" "$rigVersion"$'\t'"rig-member"$'\t'"$rigSandbox/input"$'\t'"$rigSandbox/output"$'\t'"$MDLT_ORIGIN/myx/myx.distro-agents/skillset"
rigAssert "and it is one whole index: a store row after the header, its end row last" "$( LC_ALL=C sed -n '2p' "$rigIndex" 2> /dev/null | LC_ALL=C cut -f1 ):$( tail -n 1 "$rigIndex" 2> /dev/null )" store:end
## A second on, so the index built next is strictly newer than everything it is made from.
sleep 1 ; rigHookSays Read "$rigSandbox/input/i.txt" > /dev/null
sleep 1 ; : > "$rigTmp/marker" ; sleep 1
rigAssert "the next check finds it current, and reuses it" "$( rigHookSays Write "$rigSandbox/output/f.txt" ):$( rigSince "$rigIndex" )" "allow floor:reused"

## ---------------------------------------------------------------- the origin
echo "-- 2. an origin skillset whose path holds backslashes: read by the floor, the header exact --"
rigFnIndex="$rigSessions/s-fn/permissions.rig-member.index"
## AgentsToolsGrantsSessionEnsure and the check, as the harness gate and the hook call them.
rigFnSays(){ ## tool, path -- rc of the check and what admitted it
	env -i HOME="$rigTmp/home" PATH=/usr/bin:/bin:/usr/sbin:/sbin MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" RIG_ORIGIN="$rigOrigin" RIG_TOOL="$1" RIG_PATH="$2" bash -c '
		. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/grants/AgentsTools.Grants.include" || exit 97
		AgentsToolsGrantsSessionEnsure "$MMDAPP" rig-member s-fn "" "" "$RIG_ORIGIN" || exit 96
		checkRc=0
		AgentsToolsGrantsSessionCheck "$RIG_TOOL" "$RIG_PATH" "$MMDAPP/.local/agents/sessions/s-fn" || checkRc=$?
		printf "%s %s" "$checkRc" "$agentsGrantsCheckLayer"
	' 2> "$rigTmp/fn.err"
}
rigAssert "a Read under it is admitted, by the floor"      "$( rigFnSays Read "$rigOrigin/x.md" )" "0 floor"
rigAssert "control: a Write under it is not"               "$( rigFnSays Write "$rigOrigin/x.md" )" "1 "
rigAssert "the index's header names it, byte for byte"     "$( head -1 "$rigFnIndex" 2> /dev/null )" "$rigVersion"$'\t'"rig-member"$'\t\t\t'"$rigOrigin"
sleep 1 ; rigFnSays Read "$rigOrigin/x.md" > /dev/null
sleep 1 ; : > "$rigTmp/marker" ; sleep 1
rigAssert "the next check finds it current, and reuses it" "$( rigFnSays Read "$rigOrigin/x.md" ):$( rigSince "$rigFnIndex" )" "0 floor:reused"

## ---------------------------------------------------------------- the awk's own inputs
echo "-- 3. the awk reads each value from the environment, and from -v where it names none --"
printf 'myx.distro grants.index 1\trig\n' > "$rigTmp/awk.index"
## The header line and the floor rows the awk prints: `<header>;` then `<tools>|<pattern>;` for each allow row.
rigAwkSays(){ ## awk arguments...
	LC_ALL=C awk -v member=rig-member "$@" -f "$rigLib/grants/AgentsGrantsPattern.awk" -f "$rigLib/grants/AgentsGrantsSessionIndex.awk" "$rigTmp/awk.index" 2> "$rigTmp/awk.err" \
		| LC_ALL=C awk -F'\t' 'NR == 1 { printf "%s;", $0 ; next ; } $1 == "store" { printf "store %s;", $2 ; } $1 == "allow" { printf "%s|%s;", $2, $3 ; }'
}
rigAssert "from the environment, a backslash kept as it is" \
	"$( agentsGrantsSessionHeader='rig\thead' agentsGrantsSandboxIn='/rig/i\n' agentsGrantsSandboxOut='/rig/o\t' agentsGrantsOrigin='/rig/s\n' agentsGrantsStores=/rig/store rigAwkSays )" \
	'rig\thead;store /rig/store; Read Grep Glob |/rig/i\\n@(|/*); Read Edit Write Execute Grep Glob |/rig/o\\t@(|/*); Read Grep Glob |/rig/s\\n@(|/*);'
rigAssert "from -v, where the environment names none"       "$( rigAwkSays -v header=rig-head -v sandboxIn=/rig/in -v sandboxOut=/rig/out -v origin=/rig/skillset -v stores=/rig/store )" \
	'rig-head;store /rig/store; Read Grep Glob |/rig/in@(|/*); Read Edit Write Execute Grep Glob |/rig/out@(|/*); Read Grep Glob |/rig/skillset@(|/*);'
rigAssert "neither names a sandbox or an origin: no floor row for one" "$( agentsGrantsSessionHeader=rig-head rigAwkSays )" 'rig-head;'

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SESSION INDEX EXACT VALUES CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_INDEX_EXACT_VALUES: OK (%d assertions, offline, rig HOME only)\n' "$rigPassCount"
