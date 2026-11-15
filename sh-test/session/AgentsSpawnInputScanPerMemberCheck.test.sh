#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on a spawn's input scan being its own: two members brought into one session share
## that session's sandbox, and each one's scan goes to its own input folder, never the other's.
## (AgentsTools.SpawnSandbox.include, AgentsToolsSpawnSandboxFillInput)
##   1. THE CONTROL: the first member's fill writes its scan to its own folder, and it is that member's text.
##   2. The second member's fill writes to a different folder, and the first folder is untouched.
##   3. Neither folder holds the other member's scan.
##   4. A second fill of the SAME member's own folder replaces its own scan there.
## Offline: no network, no git, a rig of this check's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigSandbox="$rigOrigin/myx/myx.distro-agents/sh-lib/spawn/AgentsTools.SpawnSandbox.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigSandbox" ] || rigRefuse "the sandbox include is missing from the origin: $rigSandbox"
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSpawnInputScanPerMemberCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigBox="$rigTmp/box"
rigIdRig="11111111-1111-4111-8111-111111111111"
rigIdTwo="22222222-2222-4222-8222-222222222222"
mkdir -p "$rigWs/.local/temp" "$rigBox/input/$rigIdRig" "$rigBox/input/$rigIdTwo" "$rigTmp/skills/keeper-rig" "$rigTmp/skills/keeper-two"
printf 'rig\n' > "$rigTmp/skills/keeper-rig/keeper-rig.basic.md"
printf 'rig\n' > "$rigTmp/skills/keeper-two/keeper-two.basic.md"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
## One fill of the folder a spawn owns, as the spawner makes it: the brief, the member, and the scan
## report this start's routine produced.
rigFill(){ ## the spawn's own input folder, member, scan text
	printf 'dispatch for %s\n' "$2" > "$rigTmp/brief.$2"
	printf '%s\n' "$3" > "$rigTmp/scan.$2"
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="/usr/bin:/bin" MMDAPP="$rigWs" \
		MDAT_DATA_ROOT="$rigTmp/data" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDLT_ORIGIN="$rigOrigin" \
		MDLT_OPTION="--run-from-path $rigOrigin" bash -c '
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/spawn/AgentsTools.SpawnSandbox.include"
			AgentsToolsSpawnSandboxFillInput "$1" "$( cat "$2" )" "" "$3" "" "$4"
		' rig "$1" "$rigTmp/brief.$2" "$2" "$rigTmp/scan.$2" ) > "$rigTmp/fill.$2.out" 2>&1 \
		|| rigRefuse "the fill of $2 failed: $( tail -3 "$rigTmp/fill.$2.out" )"
	chmod -R u+w "$1" 2> /dev/null || :
}

echo "-- 1. the control: the first member's scan lands in its own folder --"
rigFill "$rigBox/input/$rigIdRig" keeper-rig "scan of keeper-rig, first"
rigAssert "its own folder holds its scan" "$( LC_ALL=C grep -c -x -F 'scan of keeper-rig, first' "$rigBox/input/$rigIdRig/input-scan.md" 2> /dev/null || : )" "1"

echo "-- 2. a second member's fill writes to its own folder, and leaves the first alone --"
rigFill "$rigBox/input/$rigIdTwo" keeper-two "scan of keeper-two, second"
rigAssert "the first member's scan is untouched" "$( LC_ALL=C grep -c -x -F 'scan of keeper-rig, first' "$rigBox/input/$rigIdRig/input-scan.md" 2> /dev/null || : )" "1"
rigAssert "the second member's folder holds its own scan" "$( LC_ALL=C grep -c -x -F 'scan of keeper-two, second' "$rigBox/input/$rigIdTwo/input-scan.md" 2> /dev/null || : )" "1"

echo "-- 3. neither folder holds the other member's scan --"
rigAssert "the first folder holds none of the second's" "$( LC_ALL=C grep -c -x -F 'scan of keeper-two, second' "$rigBox/input/$rigIdRig/input-scan.md" 2> /dev/null || : )" "0"
rigAssert "the second folder holds none of the first's" "$( LC_ALL=C grep -c -x -F 'scan of keeper-rig, first' "$rigBox/input/$rigIdTwo/input-scan.md" 2> /dev/null || : )" "0"

echo "-- 4. a second fill of the same member's own folder replaces its own scan --"
rigFill "$rigBox/input/$rigIdRig" keeper-rig "scan of keeper-rig, second start"
rigAssert "its own folder holds its newest scan" "$( LC_ALL=C grep -c -x -F 'scan of keeper-rig, second start' "$rigBox/input/$rigIdRig/input-scan.md" 2> /dev/null || : )" "1"
rigAssert "and the earlier scan is gone from it" "$( LC_ALL=C grep -c -x -F 'scan of keeper-rig, first' "$rigBox/input/$rigIdRig/input-scan.md" 2> /dev/null || : )" "0"
rigAssert "and the other member's folder is still untouched" "$( LC_ALL=C grep -c -x -F 'scan of keeper-two, second' "$rigBox/input/$rigIdTwo/input-scan.md" 2> /dev/null || : )" "1"

printf '\n  %s passed, %s failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" -eq 0 ] || exit 1
printf 'SPAWN_INPUT_SCAN_PER_MEMBER: OK\n'
