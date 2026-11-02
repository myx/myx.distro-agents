#!/usr/bin/env bash
## ^^^ for syntax checking in the editor only
##
## Behavioural check on the spawn sandbox's input scan being PER MEMBER (S26 item 6): two members
## brought into one session share that session's sandbox, and the second one's scan must never
## overwrite the first one's `input/input-scan.md`. (AgentsTools.SpawnSandbox.include,
## AgentsToolsSpawnSandboxFillInput)
##   1. THE CONTROL: the first fill writes the scan, and it is that member's text.
##   2. A second member's fill leaves the first member's input/input-scan.md exactly as it was.
##   3. The second member's own scan is there, under its own name, so it still reaches it.
##   4. A second fill by the SAME member replaces its own scan: the same member is not a clash.
## Offline: no network, no git, a rig of this check's own.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigOrigin="$( cd "$MDLT_ORIGIN" && pwd -P )" || exit 1
rigSandbox="$rigOrigin/myx/myx.distro-agents/sh-lib/session/AgentsTools.SpawnSandbox.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigSandbox" ] || rigRefuse "the sandbox include is missing from the origin: $rigSandbox"
. "$rigOrigin/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSpawnInputScanPerMemberCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws" rigBox="$rigTmp/box"
mkdir -p "$rigWs/.local/temp" "$rigBox/input" "$rigTmp/skills/keeper-rig" "$rigTmp/skills/keeper-two"
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
## One fill of the sandbox's input/, as the spawner makes it: the brief, the member, and the
## scan report this start's routine produced.
rigFill(){ ## member, scan text
	printf 'dispatch for %s\n' "$1" > "$rigTmp/brief.$1"
	printf '%s\n' "$2" > "$rigTmp/scan.$1"
	( cd "$rigWs" && env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigTmp" PATH="/usr/bin:/bin" MMDAPP="$rigWs" \
		MDAT_DATA_ROOT="$rigTmp/data" MDAT_SKILLSET_ROOT="$rigTmp/skills" MDLT_ORIGIN="$rigOrigin" \
		MDLT_OPTION="--run-from-path $rigOrigin" bash -c '
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SpawnSandbox.include"
			AgentsToolsSpawnSandboxFillInput "$1" "$( cat "$2" )" "" "$3" "" "$4"
		' rig "$rigBox" "$rigTmp/brief.$1" "$1" "$rigTmp/scan.$1" ) > "$rigTmp/fill.$1.out" 2>&1 \
		|| rigRefuse "the fill of $1 failed: $( tail -3 "$rigTmp/fill.$1.out" )"
	chmod -R u+w "$rigBox/input" 2> /dev/null || :
}

echo "-- 1. the control: the first member's scan lands --"
rigFill keeper-rig "scan of keeper-rig, first"
rigAssert "input/input-scan.md holds the first member's scan" "$( LC_ALL=C grep -c -x -F 'scan of keeper-rig, first' "$rigBox/input/input-scan.md" 2> /dev/null || : )" "1"

echo "-- 2. a second member's fill does not overwrite it --"
rigFill keeper-two "scan of keeper-two, second"
rigAssert "input/input-scan.md still holds the first member's scan" "$( LC_ALL=C grep -c -x -F 'scan of keeper-rig, first' "$rigBox/input/input-scan.md" 2> /dev/null || : )" "1"
rigAssert "and it does not hold the second member's" "$( LC_ALL=C grep -c -x -F 'scan of keeper-two, second' "$rigBox/input/input-scan.md" 2> /dev/null || : )" "0"

echo "-- 3. the second member's own scan is there, under its own name --"
rigAssert "input/input-scan.keeper-two.md holds its scan" "$( LC_ALL=C grep -c -x -F 'scan of keeper-two, second' "$rigBox/input/input-scan.keeper-two.md" 2> /dev/null || : )" "1"

echo "-- 4. a second start of the first member does not replace the session's scan either --"
rigFill keeper-rig "scan of keeper-rig, second start"
rigAssert "input/input-scan.keeper-rig.md holds its newest scan" "$( LC_ALL=C grep -c -x -F 'scan of keeper-rig, second start' "$rigBox/input/input-scan.keeper-rig.md" 2> /dev/null || : )" "1"
rigAssert "and the session's own scan is still the one its first start made" "$( LC_ALL=C grep -c -x -F 'scan of keeper-rig, first' "$rigBox/input/input-scan.md" 2> /dev/null || : )" "1"

printf '\n  %s passed, %s failed\n' "$rigPassCount" "$rigFailCount"
[ "$rigFailCount" -eq 0 ] || exit 1
printf 'SPAWN_INPUT_SCAN_PER_MEMBER: OK\n'
