#!/usr/bin/env bash
## Behavioural check on the free-space floor of a spawn: under the floor the spawn is refused, says why, and
## makes no sandbox; at the floor or above it, the same call runs and the sandbox is there. The claim is the
## design's: `AgentsToolsSpawnDiskFreeRefused` sits beside `AgentsToolsSpawnLimitReached`, reads the floor
## from `MDAT_MONITORING_DISK_FREE_GIB`, and refuses in the spawn proxy before the sandbox's own `mkdir`.
## One assertion, both ends of the same call: refused under the floor, which is a non-zero status, a line
## naming the floor or its setting, and no sandbox made; and the sandbox made at or above it.
## Red before the build: no gate stands anywhere on the spawn path, so the under-floor call makes its sandbox
## like any other, and the assertion reads `ran` where it wants `refused`.
## Offline: a `df` stub first on PATH reports the free space, a fake console stands in for the CLI, and the
## workspace, the sandbox store and the skillset are this check's own rig tree.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigFn="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "the team tooling is not at the origin this workspace resolves: $rigFn"
. "$rigPackage/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSpawnFreeFloorCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT

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
rigHome="$rigTmp/home"
rigData="$rigTmp/data"
rigSkills="$rigTmp/skills"
rigBin="$rigTmp/bin"
mkdir -p "$rigBin" "$rigHome" "$rigData" "$rigSkills/rig-member" \
	"$rigWs/.local/.agents" "$rigWs/source/rigrepo/rigpkg" || exit 1
printf '# rigpkg\n' > "$rigWs/source/rigrepo/rigpkg/MAGIC.md"
: > "$rigWs/source/rigrepo/rigpkg/file.sh"
printf '# workspace\n' > "$rigWs/MAGIC.md"
printf '# rig routine\n' > "$rigSkills/rig-member/magic-team.rig.routine.md"
printf '# rig armed\n' > "$rigSkills/rig-member/rig-member.armed.md"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/rig-member/rig-member.basic.md"
printf 'SLACK_BOT_TOKEN=rig-bot-token-TEAM\nSPAWN_TIER_NORMAL=rig-cli\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'PRESET_CLI_SERVICE=rig-cli\n' > "$rigWs/.local/.agents/preset-rig-cli.agent.env"

## THE READING: df -Pk as the tooling reads it, its fourth field the free blocks. The stub answers with the
## figure the scenario wrote, so the same call is made under the floor and above it and nothing else moves.
cat > "$rigBin/df" <<'RIG-DF'
#!/bin/sh
printf 'Filesystem 1024-blocks Used Available Capacity Mounted on\n'
printf '/dev/rig 100000000 1000 %s 1%% /\n' "$( cat "${0%/*}/../free-kib" 2> /dev/null || echo 0 )"
RIG-DF
chmod +x "$rigBin/df"
## 1 GiB free is under the default floor of 20; 95 GiB is well above it.
rigUnderKib=1048576
rigAboveKib=$(( 95 * 1024 * 1024 ))

## THE CONSOLE: a stand-in for the CLI, which leaves a deliverable so a spawn that ran is told from one
## refused. Its first line is the marker a configured console carries, without which the proxy refuses to
## start anything at all.
printf '#!/bin/sh\n## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli)\ncat > /dev/null\necho deliverable > "$MDAT_SPAWN_SANDBOX_ROOT/output/result.txt"\n' > "$rigWs/DistroAgentsConsole.sh"
chmod +x "$rigWs/DistroAgentsConsole.sh"

rigSpawn(){ ## free KiB -- the spawn's output on the rig's own streams, its status in $rigTmp/spawn.rc
	printf '%s\n' "$1" > "$rigTmp/free-kib"
	printf 'Work on rigrepo/rigpkg/file.sh following magic-team.rig.routine.md and rig-member.armed.md.\n' \
		| env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigBin:/usr/bin:/bin:/usr/sbin:/sbin" \
			MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
			MDLT_OPTION="--run-from-path $MDLT_ORIGIN" MDAT_SKILLSET_ROOT="$rigSkills" RIG_TMP="$rigTmp" RIG_FN="$rigFn" \
			bash -c '
				case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree" >&2 ; exit 99 ;; esac
				case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MDAT_DATA_ROOT outside the rig tree" >&2 ; exit 99 ;; esac
				cd "$MMDAPP" && exec bash "$RIG_FN" --intern-op-agent-spawn-proxy rig-member --dispatch-doc:create --wait
			' > "$rigTmp/spawn.out" 2> "$rigTmp/spawn.err"
	printf '%s' "$?" > "$rigTmp/spawn.rc"
}
rigSandboxCount(){ find "$rigWs/.local/agents/spawned" -mindepth 1 -maxdepth 1 -type d 2> /dev/null | LC_ALL=C grep -c . || : ; }
rigSaidFloor(){ ## -- the lines of the spawn that name the floor or the setting, on one line
	LC_ALL=C grep -h -e 'under the floor' -e 'MDAT_MONITORING_DISK_FREE_GIB' "$rigTmp/spawn.out" "$rigTmp/spawn.err" 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' '
}

echo "-- 1. under the floor --"
rigSpawn "$rigUnderKib"
rigUnderStatus="$( cat "$rigTmp/spawn.rc" )"
rigUnderSandboxes="$( rigSandboxCount )"
rigUnderSaid="$( rigSaidFloor )"
if [ "$rigUnderSaid" != 0 ] && [ "$rigUnderSandboxes" = 0 ] ; then
	rigUnderWord="refused"
else
	rigUnderWord="started"
fi

echo "-- 2. above the floor --"
rm -rf "$rigWs/.local/agents/spawned"
rigSpawn "$rigAboveKib"
rigAboveSandboxes="$( rigSandboxCount )"
if [ "$rigAboveSandboxes" = 1 ] ; then
	rigAboveWord="made"
else
	rigAboveWord="made-none"
fi

rigAssert "under the floor the spawn is refused and makes no sandbox; above it the same call makes the sandbox" "$rigUnderWord $rigAboveWord" "refused made"
printf '  # under the floor: status %s, sandboxes %s, %s line(s) naming the floor\n' "$rigUnderStatus" "$rigUnderSandboxes" "$rigUnderSaid"
printf '  # above the floor: status %s, sandboxes %s\n' "$( cat "$rigTmp/spawn.rc" )" "$rigAboveSandboxes"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ SPAWN FREE FLOOR CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'SPAWN_FREE_FLOOR: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
