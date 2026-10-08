#!/usr/bin/env bash
## Check on the harness's own setup indexes, written by --make-harness-indices:
##   harness.roots.index (AgentsHarnessRootsIndex.include) and harness.hooks.index
##   (AgentsHarnessHooksLoad.include) -- one index each, whichever origin reads it --
##   and the children lists the main loop repairs (AgentsTools.ChildrenIndex.include).
##   1. Unit: from a fixture workspace -- member links under a skillset root (a link under
##      $HOME/.claude/skills is never read), a `trash` entry, the workspace's own declared
##      grants, a root that does not exist
##      -- the index yields the read and write sets, and their resolutions, the producer
##      and `cd && pwd -P` yield, with no member and with one; and proves it is the index
##      answering by leaving the producer unable to run. A changed input never uses it;
##      another MDLT_ORIGIN does, with that origin's own skillset merged in; an index of
##      format version 1 never does.
##   2. Unit: the hook index yields the policy's own list and skipped count -- never
##      anything from .claude/settings.json -- and none for another policy, version or a
##      cut-short index.
##   3. Through the real harness: the request it builds (system text naming every root)
##      and its stderr report are the same with the indexes present and absent.
##   4. The install op writes the indexes and leaves the children lists alone; the main
##      loop's repair lists every record under its parent and marks the lists complete.
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
printf 'a:b:c:Edit(/%s/granted/deep/**)\na:b:c:Edit(/%s/not-there/*.md)\na:b:c:Read(/x)\n' "$rigTmp" "$rigTmp" > "$rigWs/.local/agents/permissions.registry"

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
	AgentsHarnessRootsIndexText "$rigWs" > "$rigWs/.local/agents/harness.roots.index"
}

echo "-- the roots index answers as the producer does --"
rigUnit rigWriteIndex
## Every root but the one MDLT_ORIGIN names, which each reader merges in for its own origin.
rigAssert "a roots index is written" "$( LC_ALL=C grep -c '^read	' "$rigWs/.local/agents/harness.roots.index" )" "$( rigUnit eval 'MDLT_ORIGIN="" ; AgentsToolsClientAccessRoots "$rigWs" ""' | LC_ALL=C grep -c . )"
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
rigAssert "a member linked only in \$HOME/.claude/skills is no root" "$( LC_ALL=C grep -c "src/gamma" "$rigWs/.local/agents/harness.roots.index" )" 0
for rigMember in "" alpha ; do
	rigWant="$( rigUnit eval 'MDLT_ORIGIN="$rigTmp/origin-b" ; rigComputed "$rigMember"' )"
	rigAssert "another origin [$rigMember]: the same index is used" "$( rigUnit eval 'MDLT_ORIGIN="$rigTmp/origin-b" ; rigIndexed "$rigMember"' | cut -c1-14 )" "$( printf '%s' "$rigWant" | cut -c1-14 )"
	rigAssert "another origin [$rigMember]: its own skillset, same roots" "$( rigUnit eval 'MDLT_ORIGIN="$rigTmp/origin-b" ; rigIndexed "$rigMember"' )" "$rigWant"
done
rigAssert "control: that origin's skillset is named" "$( rigUnit eval 'MDLT_ORIGIN="$rigTmp/origin-b" ; rigIndexed ""' | LC_ALL=C grep -c "$rigTmp/origin-b/myx/myx.distro-agents/skillset=" )" 1
rigAssert "no origin at all"                      "$( rigUnit eval 'MDLT_ORIGIN="" ; rigIndexed ""' )" "$( rigUnit eval 'MDLT_ORIGIN="" ; rigComputed ""' )"

echo "-- a changed input never uses it --"
ln -s "$rigTmp/src/gamma" "$rigSkills/delta"
rigAssert "a member added to the skillset root"   "$( rigUnit rigIndexed "" )" index-not-used
rm -f "$rigSkills/delta" ; sleep 1 ; rigUnit rigWriteIndex ; sleep 1 ; touch "$rigWs/.local/agents/harness.roots.index"
rigAssert "control: rewritten, it is used again"  "$( rigUnit rigIndexed "" | cut -c1-14 )" "$( rigUnit rigComputed "" | cut -c1-14 )"
printf 'a:b:c:Edit(/%s/src/**)\n' "$rigTmp" >> "$rigWs/.local/agents/permissions.registry"
rigAssert "a grant declared since"                "$( rigUnit rigIndexed "" )" index-not-used
sleep 1 ; rigUnit rigWriteIndex ; sleep 1 ; touch "$rigWs/.local/agents/harness.roots.index"
rigAssert "control: rewritten, it is used again"  "$( rigUnit rigIndexed "" | cut -c1-14 )" "$( rigUnit rigComputed "" | cut -c1-14 )"
rigAssert "another MDAT_SKILLSET_ROOT"            "$( rigUnit eval 'MDAT_SKILLSET_ROOT="$rigTmp/src" ; rigIndexed ""' )" index-not-used
rigAssert "another HOME"                           "$( rigUnit eval 'HOME="$rigTmp" ; rigIndexed ""' )" index-not-used
## A second on, as a re-pointed link in real use is: mtimes here count whole seconds.
sleep 1 ; touch "$rigSkills"
rigAssert "a skillset root touched after it"       "$( rigUnit rigIndexed "" )" index-not-used
sleep 1 ; rigUnit rigWriteIndex ; sleep 1 ; touch "$rigWs/.local/agents/harness.roots.index"
printf 'myx.distro harness.roots.index 3\nprint\tx\n' > "$rigTmp/cut"
rigAssert "an index cut short"                     "$( rigUnit eval 'cp "$rigTmp/cut" "$rigWs/.local/agents/harness.roots.index" ; rigIndexed ""' )" index-not-used
sleep 1 ; rigUnit rigWriteIndex ; sleep 1 ; touch "$rigWs/.local/agents/harness.roots.index"
sed '1s/ 3$/ 2/' "$rigWs/.local/agents/harness.roots.index" > "$rigTmp/v1" ; touch -r "$rigWs/.local/agents/harness.roots.index" "$rigTmp/v1"
rigAssert "an index of format version 2"          "$( rigUnit eval 'cp -p "$rigTmp/v1" "$rigWs/.local/agents/harness.roots.index" ; rigIndexed ""' )" index-not-used

echo "-- the hooks index answers as the policy does, and settings.json is never read --"
mkdir -p "$rigWs/.claude"
## A settings.json full of hooks of every kind: none of it may reach the harness's list.
printf '%s' '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"/x/deny.sh \"a b\""}]},{"hooks":[{"type":"command","command":"/y/other.sh"}]}]}}' > "$rigWs/.claude/settings.json"
rigHooks(){ ## prints: computed list, index-written, index list, then one verdict per stale case
	(
		MMDAPP="$rigWs" harnessHere="$rigHere"
		. "$rigHere/AgentsTools.ClientToolPolicy.include" && . "$rigHere/AgentsHarnessHooksLoad.include" || exit 1
		rigList(){ harnessHooksList="" harnessHooksFault="" harnessHooksSkipped=0 ; AgentsHarnessHooksRecords "$rigWs" && AgentsHarnessHooksFromRecords "$agentsHooksRecords" ; printf '[%s][%s][%s][%s]\n' "$agentsHooksFrom" "$harnessHooksFault" "$harnessHooksSkipped" "${harnessHooksList//$'\n'/\\n}" ; }
		rm -f "$rigWs/.local/agents/harness.hooks.index"
		rigList
		AgentsHarnessHooksIndexWrite "$rigWs" && printf 'written\n' || printf 'not-written\n'
		## Poisoned, so only the index can produce the answer below.
		AgentsHarnessHooksRecordsComputed(){ agentsHooksRecords=$'PreToolUse\tall\tpoison\t\t/poison\t\n' ; }
		rigList
		cp "$rigWs/.local/agents/harness.hooks.index" "$rigTmp/hooks.good"
		for rigStale in 's/^sum\t[0-9]*/sum\t1/' '1s/ 3$/ 2/' '$d' ; do
			sed "$rigStale" "$rigTmp/hooks.good" > "$rigWs/.local/agents/harness.hooks.index"
			harnessHooksList="" ; AgentsHarnessHooksRecords "$rigWs" ; printf '%s\n' "$agentsHooksFrom"
		done
		cp "$rigTmp/hooks.good" "$rigWs/.local/agents/harness.hooks.index"
	)
}
rigHookOut="$( rigHooks )"
rigPolicyList="$( printf '%s\n' "$rigHookOut" | sed -n 1p )"
rigAssert "hooks: computed from the policy, settings.json not read" "$rigPolicyList" "[the client tool policy][][10][Read	$rigHere/client-hooks/deny-memory-md-read.sh\\nGlob	$rigHere/client-hooks/deny-memory-md-read.sh Glob\\nGrep	$rigHere/client-hooks/deny-memory-md-read.sh Grep\\nEdit|Write	$rigHere/client-hooks/protect-memory-md.sh\\n]"
rigAssert "hooks: the index is written" "$( printf '%s\n' "$rigHookOut" | sed -n 2p )" written
rigAssert "hooks: the index gives the policy's answer" "$( printf '%s\n' "$rigHookOut" | sed -n 3p )" "${rigPolicyList/the client tool policy/harness.hooks.index}"
rigAssert "hooks: another policy's index is refused" "$( printf '%s\n' "$rigHookOut" | sed -n 4p )" "the client tool policy"
rigAssert "hooks: a version 2 index is refused" "$( printf '%s\n' "$rigHookOut" | sed -n 5p )" "the client tool policy"
rigAssert "hooks: an index cut short is refused" "$( printf '%s\n' "$rigHookOut" | sed -n 6p )" "the client tool policy"

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
	AgentsHarnessRootsIndexText "$rigWs" > "$rigWs/.local/agents/harness.roots.index"
	AgentsHarnessHooksIndexText > "$rigWs/.local/agents/harness.hooks.index"
)
sleep 1 ; touch "$rigWs/.local/agents/harness.roots.index"
rigHarnessRun indexed
rigAssert "both runs answered" "$( cat "$rigTmp/computed.out" ):$( cat "$rigTmp/indexed.out" )" "RIG-FINAL-MARKER:RIG-FINAL-MARKER"
rigAssert "the request names the same roots, byte for byte" "$( cat "$rigTmp/indexed.req" )" "$( cat "$rigTmp/computed.req" )"
rigAssert "the request did name the fixture's roots"        "$( LC_ALL=C grep -c "$rigTmp/src/alpha" "$rigTmp/indexed.req" )" 1
rigAssert "the stderr report is the same, but for where the hooks came from" "$( LC_ALL=C grep -v '^── round\|AgentsUniversalHarness\.\|PreToolUse hooks' "$rigTmp/indexed.err" )" "$( LC_ALL=C grep -v '^── round\|AgentsUniversalHarness\.\|PreToolUse hooks' "$rigTmp/computed.err" )"
rigAssert "the indexed run said the hooks came from the index" "$( LC_ALL=C grep -c 'PreToolUse hooks from.*harness.hooks.index' "$rigTmp/indexed.err" )" 1
rigAssert "the computed run said they were computed"          "$( LC_ALL=C grep -c 'PreToolUse hooks computed from.*the client tool policy' "$rigTmp/computed.err" )" 1
rigAssert "and it reported a skipped reroute"                 "$( LC_ALL=C grep -c 'skipped' "$rigTmp/indexed.err" )" 1

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
## The install's own op writes every harness index and leaves the children lists alone.
( set +u ; HOME="$rigHome" MDAT_SKILLSET_ROOT="$rigSkills" MMDAPP="$rigWs" "${rigHere%/sh-lib}/sh-scripts/DistroAgentsTools.fn.sh" --make-harness-indices ) > "$rigTmp/make.out" 2> "$rigTmp/make.err"
rigAssert "the install op wrote every harness index"             "$( ls "$rigWs/.local/agents" | LC_ALL=C grep -c 'harness.roots.index\|harness.hooks.index\|mcp.servers.index' )" 3
rigAssert "and left the children lists alone"                    "$( [ -e "$rigWs/.local/agents/children" ] && printf yes || printf no )" no
## The main loop's repair lists every record and marks the lists complete: a stale list
## goes, an id that could name another file is skipped.
mkdir -p "$rigWs/.local/agents/children" "$rigSpawned/bad"
printf 'gone/sp9.md\n' > "$rigWs/.local/agents/children/stale-parent"
printf -- '---\nparent-session-id: ../escape\n---\n' > "$rigSpawned/bad/sp4.md"
( set +u ; . "$rigHere/AgentsTools.ChildrenIndex.include" && AgentsToolsChildrenIndexRepair "$rigWs" ) 2> "$rigTmp/repair.err"
rigAssert "the repair marked the children lists complete"        "$( [ -f "$rigWs/.local/agents/children/.indexed" ] && printf yes || printf no )" yes
rigAssert "and listed rig-parent's two children"                "$( LC_ALL=C sort "$rigWs/.local/agents/children/rig-parent" 2>/dev/null | tr '\n' ' ' )" "a-linked/sp2.md b-child/sp1.md "
rigAssert "and every list there is, none other"                 "$( ls "$rigWs/.local/agents/children" | tr '\n' ' ' )" "rig-parent someone-else "
rm -rf "$rigSpawned/bad"
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
	echo "  fix:  AgentsHarnessRootsIndex.include, AgentsHarnessHooksLoad.include, AgentsTools.ChildrenIndex.include or their callers -- never the assertion" >&2
	exit 1
fi
printf 'HARNESS_SETUP_INDEX: OK (%d assertions: roots and hooks from the index == computed, stale inputs never use it, same request through the harness, offline)\n' "$rigPass"
