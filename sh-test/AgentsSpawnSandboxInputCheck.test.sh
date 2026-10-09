#!/usr/bin/env bash
## Behavioural check on a spawn's sandbox input/: after a spawn it holds the brief, the
## board item, the MAGIC.md of the package the brief names, the named routine and
## pointers.md, and no secret; after close input/ is emptied and output/ kept; the sweep
## empties a stale sandbox and skips a fresh one, one with no record and another host's.
## A fake console stands in for the CLI; every tooling call goes through one `env -i`
## whose child refuses to run outside this rig's mktemp tree.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigSandboxLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.SpawnSandbox.include"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
[ -f "$rigSandboxLib" ] || rigRefuse "sandbox include not found: $rigSandboxLib"
rigTmp="$( mktemp -d -t AgentsSpawnSandboxInputCheck )" || exit 1
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
rigYes(){ "$@" && printf yes || printf no ; }

rigWs="$rigTmp/ws"
rigSecret="rig-SECRET-7f3a9c"
mkdir -p "$rigWs/.local/.agents" "$rigTmp/data" "$rigTmp/home" "$rigWs/source/rigrepo/rigpkg" "$rigTmp/skills/rig-member"
printf 'SLACK_BOT_TOKEN=%s\nSPAWN_CLI_SERVICE=rig-cli\n' "$rigSecret" > "$rigWs/.local/.agents/magic-team.agent.env"
printf '# rigpkg\n' > "$rigWs/source/rigrepo/rigpkg/MAGIC.md"
: > "$rigWs/source/rigrepo/rigpkg/file.sh"
printf '# workspace\n' > "$rigWs/MAGIC.md"
printf '# rig routine\n' > "$rigTmp/skills/rig-member/magic-team.rig.routine.md"
printf '# rig armed\n' > "$rigTmp/skills/rig-member/rig-member.armed.md"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigTmp/skills/rig-member/rig-member.basic.md"
## The fake console records what input/ held while it ran, and leaves a deliverable.
printf '#!/bin/sh\n## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli)\ncat > /dev/null\nls "$MDAT_SPAWN_SANDBOX_ROOT/input" > "%s/input-while-running"\ncat "$MDAT_SPAWN_SANDBOX_ROOT"/input/* > "%s/input-content" 2>/dev/null\necho deliverable > "$MDAT_SPAWN_SANDBOX_ROOT/output/result.txt"\n' \
	"$rigTmp" "$rigTmp" > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"

echo "-- a spawn fills input/, and its close empties it --"
printf 'Work on rigrepo/rigpkg/file.sh following magic-team.rig.routine.md and rig-member.armed.md.\n' \
	| env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigTmp/data" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigTmp/skills" RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MDAT_DATA_ROOT outside the rig tree" >&2 ; exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy rig-member --dispatch-doc:create --wait
		' > "$rigTmp/spawn.out" 2> "$rigTmp/spawn.err"
[ -f "$rigTmp/input-while-running" ] || rigRefuse "the console never ran, so input/ was never observed: $( tail -3 "$rigTmp/spawn.err" )"
rigHeld(){ LC_ALL=C grep -q -x -- "$1" "$rigTmp/input-while-running" ; }
rigAssert "the brief is there as dispatch.md"          "$( rigYes rigHeld dispatch.md )" yes
rigAssert "the board item is there"                    "$( rigYes env LC_ALL=C grep -q -E '^dispatch-.*\.md$' "$rigTmp/input-while-running" )" yes
rigAssert "the named package's MAGIC.md is copied"     "$( rigYes rigHeld 'MAGIC.rigrepo--rigpkg.md' )" yes
rigAssert "the named routine is a pointer, not a copy" "$( rigYes rigHeld magic-team.rig.routine.md )" no
rigAssert "pointers.md names the routine's reader"     "$( rigYes env LC_ALL=C grep -q -F 'magic-team.rig.routine.md`: read with Skill' "$rigTmp/input-content" )" yes
rigAssert "pointers.md is there"                       "$( rigYes rigHeld pointers.md )" yes
rigAssert "a skillset file is a pointer, not a copy"   "$( rigYes rigHeld rig-member.armed.md )" no
rigAssert "nothing secret is in input/"                "$( rigYes env LC_ALL=C grep -q -F "$rigSecret" "$rigTmp/input-content" )" no
rigSandbox="$( ls -d "$rigWs/.local/agents/spawned"/*/ 2>/dev/null | head -1 )"
rigSandbox="${rigSandbox%/}"
[ -n "$rigSandbox" ] || rigRefuse "no sandbox was created"
rigAssert "after close input/ is empty"                "$( find "$rigSandbox/input" -mindepth 1 | LC_ALL=C grep -c . || : )" 0
rigAssert "input/ itself is kept"                      "$( rigYes test -d "$rigSandbox/input" )" yes
rigAssert "and output/ keeps the deliverable"          "$( cat "$rigSandbox/output/result.txt" 2>/dev/null )" deliverable

echo "-- the sweep --"
rigSpawned="$rigWs/.local/agents/spawned"
rigThisHost="$( hostname -s 2>/dev/null || echo unknown )"
rigMake(){ ## name, record age (old|new|none), host
	mkdir -p "$rigSpawned/$1/input" "$rigSpawned/$1/output"
	: > "$rigSpawned/$1/input/brief.md"
	[ "$2" != none ] || return 0
	printf 'session-id: rig-dead-%s\nhost: %s\n' "$1" "$3" > "$rigSpawned/$1/rig-dead-$1.md"
	[ "$2" != old ] || touch -t 202001010000 "$rigSpawned/$1/rig-dead-$1.md"
}
rigMake stale old "$rigThisHost"
rigMake fresh new "$rigThisHost"
rigMake norecord none ""
rigMake otherhost old rig-elsewhere
## Harness scratch a killed run left behind: in a stale sandbox, in one whose input/ is already
## empty, and in a fresh one, which keeps it.
rigScratch(){ mkdir -p "$rigSpawned/$1/tmp/AgentsUniversalHarness.rig" && printf 'rig\n' > "$rigSpawned/$1/tmp/AgentsUniversalHarness.rig/wait.err" ; }
rigMake scratchonly old "$rigThisHost"
rm -f "$rigSpawned/scratchonly/input/brief.md"
rigScratch stale ; rigScratch scratchonly ; rigScratch fresh
env -i PATH="/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_LIB="$rigSandboxLib" \
	bash -c '
		case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
		MDSC_CMD=rig ; . "$RIG_LIB" ; AgentsToolsSpawnSandboxSweep rig-sweep
	' 2> "$rigTmp/sweep.err"
rigLeft(){ find "$rigSpawned/$1/input" -mindepth 1 | LC_ALL=C grep -c . || : ; }
rigAssert "a stale sandbox is emptied"                 "$( rigLeft stale )" 0
rigAssert "and said"                                   "$( rigYes env LC_ALL=C grep -q 'emptied input/ of stale' "$rigTmp/sweep.err" )" yes
rigAssert "a fresh one is skipped"                     "$( rigLeft fresh )" 1
rigAssert "one with no record is skipped"              "$( rigLeft norecord )" 1
rigAssert "another host's is skipped"                  "$( rigLeft otherhost )" 1
rigScratchLeft(){ find "$rigSpawned/$1/tmp" -mindepth 1 2>/dev/null | LC_ALL=C grep -c . || : ; }
rigAssert "a stale sandbox's leftover scratch in tmp/ is cleared, tmp/ kept" "$( rigScratchLeft stale ):$( rigYes test -d "$rigSpawned/stale/tmp" )" 0:yes
rigAssert "so is one whose input/ was already empty"   "$( rigScratchLeft scratchonly )" 0
rigAssert "and said"                                   "$( rigYes env LC_ALL=C grep -q 'cleared the scratch left in tmp/ of scratchonly' "$rigTmp/sweep.err" )" yes
rigAssert "a fresh one keeps its scratch"              "$( rigScratchLeft fresh )" 2

echo "-- a session-joining spawn uses the session's own sandbox, not a fresh uuid --"
rigSessionId="rig-session-$$"
printf '#!/bin/sh\n## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli)\ncat > "%s/join-dispatch.txt"\necho deliverable > "$MDAT_SPAWN_SANDBOX_ROOT/output/result.txt"\n' \
	"$rigTmp" > "$rigWs/DistroAgentsConsole.sh"
printf 'Work on rigrepo/rigpkg/file.sh following magic-team.rig.routine.md and rig-member.armed.md.\n' \
	| env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigTmp/data" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDAT_SESSION_ID="$rigSessionId" RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MDAT_DATA_ROOT outside the rig tree" >&2 ; exit 99 ;; esac
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy rig-member --dispatch-doc:create --wait
		' > "$rigTmp/join.out" 2> "$rigTmp/join.err"
rigJoinSandbox="$rigWs/.local/agents/spawned/$rigSessionId"
rigAssert "the session's own sandbox folder is used"      "$( rigYes test -d "$rigJoinSandbox" )" yes
rigAssert "output/<member> exists under it"                "$( rigYes test -d "$rigJoinSandbox/output/rig-member" )" yes
rigAssert "the dispatch text names the own-scratch line"   "$( rigYes env LC_ALL=C grep -q -F "Your own scratch inside it: $rigJoinSandbox/output/rig-member" "$rigTmp/join-dispatch.txt" )" yes

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SPAWN SANDBOX INPUT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_SANDBOX_INPUT: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
