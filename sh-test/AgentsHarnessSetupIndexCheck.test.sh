#!/usr/bin/env bash
## Check on the harness's own setup indexes, written by --make-harness-indices:
##   harness.roots.index (AgentsHarnessRootsIndex.include) and harness.hooks.index
##   (AgentsHarnessHooksLoad.include).
##   1. Unit: from a fixture workspace -- member links under a skillset root and under
##      $HOME/.claude/skills, a `trash` entry, declared grants, a root that does not exist
##      -- the index yields the read and write sets, and their resolutions, the producer
##      and `cd && pwd -P` yield, with no member and with one; and proves it is the index
##      answering by leaving the producer unable to run. A changed input never uses it.
##   2. Unit: the hook index yields the loader's list, fault and skipped count for every
##      settings.json shape the loader distinguishes, and none for changed inputs.
##   3. Through the real harness: the request it builds (system text naming every root)
##      and its stderr report are the same with the indexes present and absent.
## Offline: a fake curl, HOME and MMDAPP are this rig's own mktemp tree.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigHarness="$rigHere/AgentsUniversalHarness.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
for rigFile in "$rigHarness" "$rigHere/AgentsHarnessRootsIndex.include" "$rigHere/AgentsHarnessHooksLoad.include" "$rigHere/AgentsTools.ClientAccessRoots.include" ; do
	[ -f "$rigFile" ] || rigRefuse "not found at the origin this workspace resolves: $rigFile"
done

rigTmp="$( mktemp -d -t AgentsHarnessSetupIndexCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigTmp="$( cd "$rigTmp" && pwd -P )"

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		rigPass=$(( rigPass + 1 ))
	else
		rigFail=$(( rigFail + 1 ))
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3"
	fi
}

## The fixture: a workspace, a home, a skillset root of links into a source tree.
rigWs="$rigTmp/ws"
rigHome="$rigTmp/home"
rigSkills="$rigWs/.claude/skills"
mkdir -p "$rigWs/source" "$rigWs/.local/agents" "$rigWs/.local/temp/team" "$rigTmp/src/alpha" "$rigTmp/src/beta" "$rigTmp/src/gamma" "$rigSkills/trash" "$rigHome/.claude/skills" "$rigTmp/granted/deep"
ln -s "$rigTmp/src/alpha" "$rigSkills/alpha"
ln -s "$rigTmp/src/beta" "$rigSkills/beta"
mkdir -p "$rigSkills/plain"
ln -s "$rigTmp/src/gamma" "$rigHome/.claude/skills/gamma"
printf 'a:b:c:Edit(/%s/granted/deep/**)\na:b:c:Edit(/%s/not-there/*.md)\na:b:c:Read(/x)\n' "$rigTmp" "$rigTmp" > "$rigHome/.claude/skills/.linked.magic-team.permissions.txt"

## The unit side runs in a subshell with the fixture's environment.
rigUnit(){
	(
		## The producer is not written for `set -u`, and the harness never runs under it.
		set +u
		export HOME="$rigHome" MDAT_SKILLSET_ROOT="$rigSkills"
		harnessHere="$rigHere"
		. "$rigHere/AgentsTools.ClientAccessRoots.include"
		. "$rigHere/AgentsHarnessRootsIndex.include"
		"$@"
	)
}
## What the harness computes without an index, for one member: the two sets, resolved.
rigComputed(){ ## member
	local computedRoot computedOut=""
	while IFS= read -r computedRoot ; do
		case "$computedRoot" in /*) computedOut="$computedOut$computedRoot=$( cd "$computedRoot" 2>/dev/null && pwd -P || printf '%s' "$computedRoot" )|" ;; esac
	done <<< "$( AgentsToolsClientAccessRoots "$rigWs" "$1" )"
	computedOut="$computedOut W:"
	while IFS= read -r computedRoot ; do
		case "$computedRoot" in /*) computedOut="$computedOut$computedRoot=$( cd "$computedRoot" 2>/dev/null && pwd -P || printf '%s' "$computedRoot" )|" ;; esac
	done <<< "$( { AgentsToolsClientAccessReferenceRoots write "$rigWs" "$1" && AgentsToolsClientAccessGrantRoots ; } )"
	printf '%s' "$computedOut"
}
## What the index yields, with the producer made unable to run: resolved the way the
## harness resolves -- the stored resolution, or `cd && pwd -P` where none is stored.
rigIndexed(){ ## member
	AgentsToolsClientAccessRoots(){ return 1 ; }
	AgentsToolsClientAccessReferenceRoots(){ return 1 ; }
	AgentsToolsClientAccessGrantRoots(){ return 1 ; }
	harnessAccessRoots=() harnessWriteAccessRoots=()
	AgentsHarnessRootsIndexUse "$rigWs" "$1" 0 || { printf 'index-not-used' ; return 0 ; }
	local indexedIdx=0 indexedOut="" indexedReal
	while [ "$indexedIdx" -lt "${#harnessAccessRoots[@]}" ] ; do
		indexedReal="${harnessAccessRootsReal[$indexedIdx]}"
		[ -n "$indexedReal" ] || indexedReal="$( cd "${harnessAccessRoots[$indexedIdx]}" 2>/dev/null && pwd -P || printf '%s' "${harnessAccessRoots[$indexedIdx]}" )"
		indexedOut="$indexedOut${harnessAccessRoots[$indexedIdx]}=$indexedReal|"
		indexedIdx=$(( indexedIdx + 1 ))
	done
	indexedOut="$indexedOut W:"
	indexedIdx=0
	while [ "$indexedIdx" -lt "${#harnessWriteAccessRoots[@]}" ] ; do
		indexedReal="${harnessWriteAccessRootsReal[$indexedIdx]}"
		[ -n "$indexedReal" ] || indexedReal="$( cd "${harnessWriteAccessRoots[$indexedIdx]}" 2>/dev/null && pwd -P || printf '%s' "${harnessWriteAccessRoots[$indexedIdx]}" )"
		indexedOut="$indexedOut${harnessWriteAccessRoots[$indexedIdx]}=$indexedReal|"
		indexedIdx=$(( indexedIdx + 1 ))
	done
	printf '%s' "$indexedOut"
}
rigWriteIndex(){
	{ printf 'myx.distro harness.roots.index 1\n' ; AgentsHarnessRootsIndexSection "$rigWs" ; } > "$rigWs/.local/agents/harness.roots.index"
}

echo "-- the roots index answers as the producer does --"
rigUnit rigWriteIndex
rigAssert "a roots index is written" "$( LC_ALL=C grep -c '^read	' "$rigWs/.local/agents/harness.roots.index" )" "$( rigUnit AgentsToolsClientAccessRoots "$rigWs" "" | LC_ALL=C grep -c . )"
## Older than its sources by a second, so the newer-than checks are what they will be in use.
sleep 1 ; touch "$rigWs/.local/agents/harness.roots.index"
for rigMember in "" alpha "new member" ; do
	rigWant="$( rigUnit rigComputed "$rigMember" )"
	rigAssert "member [$rigMember]: the index is used"            "$( rigUnit rigIndexed "$rigMember" | cut -c1-14 )" "$( printf '%s' "$rigWant" | cut -c1-14 )"
	rigAssert "member [$rigMember]: same roots, same resolutions" "$( rigUnit rigIndexed "$rigMember" )" "$rigWant"
done
mkdir -p "$rigWs/.local/temp/member/alpha"
rigAssert "a root created since is resolved now, not as stored" "$( rigUnit rigIndexed alpha )" "$( rigUnit rigComputed alpha )"
rigAssert "control: the producer itself was never needed" "$( rigUnit rigIndexed "" | LC_ALL=C grep -c 'index-not-used' )" 0

echo "-- a changed input never uses it --"
ln -s "$rigTmp/src/gamma" "$rigSkills/delta"
rigAssert "a member added to the skillset root"   "$( rigUnit rigIndexed "" )" index-not-used
rm -f "$rigSkills/delta" ; sleep 1 ; rigUnit rigWriteIndex ; sleep 1 ; touch "$rigWs/.local/agents/harness.roots.index"
rigAssert "control: rewritten, it is used again"  "$( rigUnit rigIndexed "" | cut -c1-14 )" "$( rigUnit rigComputed "" | cut -c1-14 )"
printf 'a:b:c:Edit(/%s/src/**)\n' "$rigTmp" >> "$rigHome/.claude/skills/.linked.magic-team.permissions.txt"
rigAssert "a grant declared since"                "$( rigUnit rigIndexed "" )" index-not-used
sleep 1 ; rigUnit rigWriteIndex ; sleep 1 ; touch "$rigWs/.local/agents/harness.roots.index"
rigAssert "control: rewritten, it is used again"  "$( rigUnit rigIndexed "" | cut -c1-14 )" "$( rigUnit rigComputed "" | cut -c1-14 )"
rigAssert "another MDAT_SKILLSET_ROOT"            "$( rigUnit eval 'MDAT_SKILLSET_ROOT="$rigTmp/src" ; rigIndexed ""' )" index-not-used
rigAssert "another HOME"                           "$( rigUnit eval 'HOME="$rigTmp" ; rigIndexed ""' )" index-not-used
## A second on, as a re-pointed link in real use is: mtimes here count whole seconds.
sleep 1 ; touch "$rigSkills"
rigAssert "a skillset root touched after it"       "$( rigUnit rigIndexed "" )" index-not-used
sleep 1 ; rigUnit rigWriteIndex ; sleep 1 ; touch "$rigWs/.local/agents/harness.roots.index"
printf 'myx.distro harness.roots.index 1\nprint\tx\n' > "$rigTmp/cut"
rigAssert "an index cut short"                     "$( rigUnit eval 'cp "$rigTmp/cut" "$rigWs/.local/agents/harness.roots.index" ; rigIndexed ""' )" index-not-used

echo "-- the hooks index answers as the loader does --"
rigHooks(){ ## settings.json content -- prints loader result, index result
	(
		MMDAPP="$rigWs" harnessHere="$rigHere"
		. "$rigHere/AgentsHarnessHooksLoad.include"
		mkdir -p "$rigWs/.claude"
		printf '%s' "$1" > "$rigWs/.claude/settings.json"
		harnessHooksRerouteList=".claude/hooks/deny-native-tool-reroute.sh"$'\n'
		harnessHooksRerouteKeys=( ".claude/hooks/deny-native-tool-reroute.sh" )
		harnessHooksList="" harnessHooksFault="" harnessHooksSkipped=0
		AgentsHarnessHooksLoadSettings
		printf 'loader[%s][%s][%s]\n' "$harnessHooksFault" "$harnessHooksSkipped" "${harnessHooksList//$'\n'/\\n}"
		{ printf 'myx.distro harness.hooks.index 1\n' ; AgentsHarnessHooksIndexSection "$rigWs" "$harnessHooksRerouteList" ; } > "$rigWs/.local/agents/harness.hooks.index"
		## Poisoned, so only the index can produce the answer below.
		AgentsHarnessHooksLoadSettings(){ harnessHooksFault="the loader ran" ; }
		harnessHooksList="" harnessHooksFault="" harnessHooksSkipped=0
		AgentsHarnessHooksIndexUse "$rigWs/.claude/settings.json" "$rigWs/.local/agents/harness.hooks.index" || AgentsHarnessHooksLoadSettings
		printf 'loader[%s][%s][%s]\n' "$harnessHooksFault" "$harnessHooksSkipped" "${harnessHooksList//$'\n'/\\n}"
		## Any other reroute list is another policy, and the index must not answer for it.
		harnessHooksRerouteList="other"
		harnessHooksList="" harnessHooksFault="" harnessHooksSkipped=0
		AgentsHarnessHooksIndexUse "$rigWs/.claude/settings.json" "$rigWs/.local/agents/harness.hooks.index" && printf 'stale-used\n' || printf 'stale-refused\n'
	)
}
rigHookCase(){ ## what, settings.json content
	local hookOut
	hookOut="$( rigHooks "$2" )"
	rigAssert "hooks [$1]: the index gives the loader's answer" "$( printf '%s\n' "$hookOut" | sed -n 2p )" "$( printf '%s\n' "$hookOut" | sed -n 1p )"
	rigAssert "hooks [$1]: another reroute list is refused"     "$( printf '%s\n' "$hookOut" | sed -n 3p )" stale-refused
}
rigHookCase "a mixed set" '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"/x/deny.sh \"a b\""}]},{"hooks":[{"type":"command","command":"/w/.claude/hooks/deny-native-tool-reroute.sh Read"},{"type":"command","command":"/y/other.sh"}]}]}}'
rigHookCase "no PreToolUse at all" '{"permissions":{"allow":["Read"]}}'
rigHookCase "not JSON" '{"hooks":'
rigHookCase "a hook that is not a command" '{"hooks":{"PreToolUse":[{"matcher":"*","hooks":[{"type":"prompt","command":"x"}]}]}}'
rigHookCase "a tab in a matcher" '{"hooks":{"PreToolUse":[{"matcher":"a\tb","hooks":[{"type":"command","command":"/z"}]}]}}'
rigHookCase "no hooks array" '{"hooks":{"PreToolUse":[{"matcher":"*"}]}}'

echo "-- through the harness: the same request and report, indexes or not --"
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/harness-mcp-check.curl.test.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"
export HARNESS_PROVIDER_NAME="setup-index-check rig" HARNESS_SELF_NAME="AgentsHarnessSetupIndexCheck.test.sh"
export HARNESS_ENDPOINT="https://harness-setup-index-check.invalid/v1/chat/completions" HARNESS_HOST="harness-setup-index-check.invalid"
export HARNESS_WIRE="OpenAiChat" HARNESS_CREDENTIAL_NAMES="none -- this check never reads one"
export HARNESS_MODEL_LIGHT="rig-light" HARNESS_MODEL_MAIN="rig-main"
export HARNESS_TOKEN_LIGHT="rig-not-a-credential" HARNESS_TOKEN_MAIN="rig-not-a-credential"
printf '%s' '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"/x/deny.sh"}]},{"hooks":[{"type":"command","command":"/w/.claude/hooks/deny-native-tool-reroute.sh Read"}]}]}}' > "$rigWs/.claude/settings.json"
rigHarnessRun(){ ## label
	printf '0' > "$rigWs/round"
	printf 'data: {"choices":[{"index":0,"delta":{"content":"RIG-FINAL-MARKER"},"finish_reason":"stop"}],"usage":{"prompt_tokens":1,"completion_tokens":1,"total_tokens":20}}\ndata: [DONE]\n' > "$rigWs/res.1"
	HOME="$rigHome" MDAT_SKILLSET_ROOT="$rigSkills" RIG_SCENARIO="$rigWs" MMDAPP="$rigWs" MDAT_HARNESS_CONTEXT_TOKENS=0 \
		"$rigHarness" RIG-TASK-MARKER > "$rigTmp/$1.out" 2> "$rigTmp/$1.err" || :
	cp "$rigWs/req.1" "$rigTmp/$1.req" 2>/dev/null || : > "$rigTmp/$1.req"
}
rm -f "$rigWs/.local/agents/harness.roots.index" "$rigWs/.local/agents/harness.hooks.index"
rigHarnessRun computed
## The indexes as the installer writes them: --make-harness-indices' own section writers.
(
	set +u
	export HOME="$rigHome" MDAT_SKILLSET_ROOT="$rigSkills"
	harnessHere="$rigHere" MMDAPP="$rigWs"
	. "$rigHere/AgentsTools.ClientAccessRoots.include" && . "$rigHere/AgentsHarnessRootsIndex.include" && . "$rigHere/AgentsTools.ClientToolPolicy.include" && . "$rigHere/AgentsHarnessHooksLoad.include"
	{ printf 'myx.distro harness.roots.index 1\n' ; AgentsHarnessRootsIndexSection "$rigWs" ; } > "$rigWs/.local/agents/harness.roots.index"
	{ printf 'myx.distro harness.hooks.index 1\n' ; AgentsHarnessHooksIndexSection "$rigWs" "$( AgentsToolsClientToolPolicyRerouteHookKeys )" ; } > "$rigWs/.local/agents/harness.hooks.index"
)
sleep 1 ; touch "$rigWs/.local/agents/harness.roots.index"
rigHarnessRun indexed
rigAssert "both runs answered" "$( cat "$rigTmp/computed.out" ):$( cat "$rigTmp/indexed.out" )" "RIG-FINAL-MARKER:RIG-FINAL-MARKER"
rigAssert "the request names the same roots, byte for byte" "$( cat "$rigTmp/indexed.req" )" "$( cat "$rigTmp/computed.req" )"
rigAssert "the request did name the fixture's roots"        "$( LC_ALL=C grep -c "$rigTmp/src/alpha" "$rigTmp/indexed.req" )" 1
rigAssert "the stderr report is the same"                   "$( LC_ALL=C grep -v '^── round\|AgentsUniversalHarness\.' "$rigTmp/indexed.err" )" "$( LC_ALL=C grep -v '^── round\|AgentsUniversalHarness\.' "$rigTmp/computed.err" )"
rigAssert "and it reported the hooks and a skipped reroute"  "$( LC_ALL=C grep -c 'PreToolUse hooks from\|skipped' "$rigTmp/indexed.err" )" 2

echo "-- children and the sandbox: the same roots, listed or scanned, handed over or resolved --"
## Three spawn records: two children of rig-parent (one under a linked sandbox), one of another.
rigSpawned="$rigWs/.local/agents/spawned"
mkdir -p "$rigSpawned/b-child/input" "$rigSpawned/b-child/output" "$rigSpawned/other/input" "$rigSpawned/other/output" "$rigTmp/elsewhere/input" "$rigTmp/elsewhere/output"
ln -s "$rigTmp/elsewhere" "$rigSpawned/a-linked"
printf -- '---\nsession-id: s1\nparent-session-id: rig-parent\n---\n' > "$rigSpawned/b-child/sp1.md"
printf -- '---\nsession-id: s2\nparent-session-id: rig-parent\n---\n' > "$rigSpawned/a-linked/sp2.md"
printf -- '---\nsession-id: s3\nparent-session-id: someone-else\n---\n' > "$rigSpawned/other/sp3.md"
rm -rf "$rigWs/.local/agents/children"
CLAUDE_CODE_SESSION_ID=rig-parent rigHarnessRun children-scanned
## The install's own op lists every record and marks the lists complete.
( set +u ; HOME="$rigHome" MDAT_SKILLSET_ROOT="$rigSkills" MMDAPP="$rigWs" "${rigHere%/sh-lib}/sh-scripts/DistroAgentsTools.fn.sh" --make-harness-indices ) > "$rigTmp/make.out" 2> "$rigTmp/make.err"
rigAssert "the install op marked the children lists complete" "$( [ -f "$rigWs/.local/agents/children/.indexed" ] && printf yes || printf no )" yes
rigAssert "and listed rig-parent's two children"                "$( LC_ALL=C sort "$rigWs/.local/agents/children/rig-parent" 2>/dev/null | tr '\n' ' ' )" "a-linked/sp2.md b-child/sp1.md "
rigAssert "and wrote every harness index"                        "$( ls "$rigWs/.local/agents" | LC_ALL=C grep -c 'harness.roots.index\|harness.hooks.index' )" 2
## A listed child twice over, as two appends leave it, reads as one.
printf 'b-child/sp1.md\n' >> "$rigWs/.local/agents/children/rig-parent"
CLAUDE_CODE_SESSION_ID=rig-parent rigHarnessRun children-listed
rigAssert "listed or scanned, the same request"    "$( cat "$rigTmp/children-listed.req" )" "$( cat "$rigTmp/children-scanned.req" )"
rigAssert "the request names the linked child's resolved output" "$( LC_ALL=C grep -c "$rigTmp/elsewhere/output" "$rigTmp/children-listed.req" )" 1
rigAssert "and the plain child's own output, resolved under spawned/" "$( LC_ALL=C grep -c "$rigSpawned/b-child/output" "$rigTmp/children-listed.req" )" 1
rigAssert "and not the other session's child"      "$( LC_ALL=C grep -c "$rigSpawned/other" "$rigTmp/children-listed.req" )" 0
CLAUDE_CODE_SESSION_ID=no-children rigHarnessRun children-none-listed
rm -f "$rigWs/.local/agents/children/.indexed"
CLAUDE_CODE_SESSION_ID=no-children rigHarnessRun children-none-scanned
rigAssert "a parent with no children: the same request" "$( cat "$rigTmp/children-none-listed.req" )" "$( cat "$rigTmp/children-none-scanned.req" )"

MDAT_SPAWN_SANDBOX_ROOT="$rigSpawned/a-linked" rigHarnessRun sandbox-resolved
MDAT_SPAWN_SANDBOX_ROOT="$rigSpawned/a-linked" MDAT_SPAWN_SANDBOX_ROOT_REAL="$rigTmp/elsewhere" rigHarnessRun sandbox-handed
MDAT_SPAWN_SANDBOX_ROOT="$rigSpawned/a-linked" MDAT_SPAWN_SANDBOX_ROOT_REAL="$rigSpawned/b-child" rigHarnessRun sandbox-wrong
rigAssert "a sandbox handed over resolved: the same request" "$( cat "$rigTmp/sandbox-handed.req" )" "$( cat "$rigTmp/sandbox-resolved.req" )"
rigAssert "one naming another directory is not believed"     "$( cat "$rigTmp/sandbox-wrong.req" )" "$( cat "$rigTmp/sandbox-resolved.req" )"
rigAssert "the request names the sandbox's resolved input"   "$( LC_ALL=C grep -c "$rigTmp/elsewhere/input" "$rigTmp/sandbox-handed.req" )" 1

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SETUP INDEX CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	echo "  fix:  AgentsHarnessRootsIndex.include, AgentsHarnessHooksLoad.include or their callers -- never the assertion" >&2
	exit 1
fi
printf 'HARNESS_SETUP_INDEX: OK (%d assertions: roots and hooks from the index == computed, stale inputs never use it, same request through the harness, offline)\n' "$rigPass"
