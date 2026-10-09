#!/usr/bin/env bash
## Behavioural check that a credential never reaches argv or disk (2158 properties 3
## and 4), across one Slack send and one Atlassian call, each run once succeeding and
## once failing. Also checks the per-send Slack log (536): one line per send, holding
## neither the token nor the body.
## Offline and contained: a temp workspace with its own credential files holding a
## sentinel token, a temp skillset root, a temp HOME, a private $TMPDIR inside the
## workspace, and a fake `curl` first on PATH.
## No real roster member, no real token, and no real store is read.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"

rigTmp="$( mktemp -d -t "AgentsCredentialExposureCheck-XXXXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigScenario="$rigTmp/scenario"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigTmp/bin" "$rigTmp/home" "$rigWs/tmp" "$rigTmp/skills/client-rig" "$rigTmp/skills/magic-team" "$rigScenario"

cp "$rigTest/check-fixtures/credential-exposure-check.curl.test.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing: $rigTest/check-fixtures/credential-exposure-check.curl.test.sh"
chmod +x "$rigTmp/bin/curl"
PATH="$rigTmp/bin:$PATH"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check would issue real requests"

rigSentinel="rig-sentinel-$$-CREDENTIAL"
rigBodyMarker="RIG-BODY-MARKER-$$"
rigSentinelB64="$( printf '%s' "rig@example.invalid:$rigSentinel" | base64 | tr -d '\n' )"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=%s\n' "$rigSentinel" > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'JIRA_SITE=rig.atlassian.invalid\nJIRA_USER=rig@example.invalid\nJIRA_API_TOKEN=%s\n' "$rigSentinel" > "$rigWs/.local/.agents/client-rig.agent.env"

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
rigHas(){ ## file, fixed string -> yes|no
	if [ -f "$1" ] && grep -q -F -e "$2" "$1" ; then echo yes ; else echo no ; fi
}

## Runs one call with fresh scenario records; its rc is left in rigRc.
rigCall(){ ## mode, tool arguments...
	local rigMode="$1" ; shift
	rm -f "$rigScenario"/*.log
	rigRc=0
	( cd "$rigWs" && env -u MDAT_DATA_ROOT HOME="$rigTmp/home" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigTmp/skills" TMPDIR="$rigWs/tmp" RIG_SCENARIO="$rigScenario" RIG_WS="$rigWs" RIG_MODE="$rigMode" \
		RIG_SENTINEL="$rigSentinel" RIG_SENTINEL_B64="$rigSentinelB64" \
		bash "$rigTool" "$@" ) > "$rigScenario/out" 2>&1 || rigRc=$?
}

## The exposure assertions every call owes, after it ran.
rigExposure(){ ## label, body-carrying: yes|no
	rigAssert "$1: control, the fake saw the credential on stdin" "$( rigHas "$rigScenario/stdin.log" "$rigSentinel" )" yes
	rigAssert "$1: the credential is not in curl's argv" "$( rigHas "$rigScenario/argv.log" "$rigSentinel" )" no
	rigAssert "$1: the credential is not in ps for curl or its parent" "$( rigHas "$rigScenario/ps.log" "$rigSentinel" )" no
	if [ "$2" = "yes" ] ; then
		rigAssert "$1: control, the in-flight scan saw the body's temp file" "$( [ -s "$rigScenario/inflight.log" ] && echo yes || echo no )" yes
	fi
	rigAssert "$1: control, the in-flight scan saw a probe written to \$TMPDIR" "$( rigHas "$rigScenario/probe.log" RIG-TMPDIR-PROBE )" yes
	rigAssert "$1: no temp file held the credential while the call ran" "$( [ -s "$rigScenario/disk.log" ] && cat "$rigScenario/disk.log" || echo none )" none
	rigAssert "$1: every mdat-* temp file is gone after it" "$( ls -1 "$rigWs/.local/temp" | grep -c '^mdat-' )" 0
	rigAssert "$1: the credential is nowhere on disk outside the credential files" \
		"$( grep -rl -F -e "$rigSentinel" -e "$rigSentinelB64" "$rigWs" | grep -v '/\.local/\.agents/' | head -n 1 )" ""
}

rigSendLog="$rigWs/.local/agents/comms-slack-send.$( date -u +%Y-%m ).log"

echo "-- a Slack send that succeeds --"
rigCall ok --member-comms-slack-send-message magic-team magic-team --identity-bot "$rigBodyMarker"
grep -q 'chat.postMessage' "$rigScenario/argv.log" 2>/dev/null || rigRefuse "no Slack send reached the fake curl: $( grep -v SystemContext "$rigScenario/out" | grep -m1 -E "ERROR|WARNING" )"
rigAssert "slack ok: rc" "$rigRc" 0
rigExposure "slack ok" yes
rigAssert "slack ok: control, the body marker reached curl" "$( rigHas "$rigScenario/bodies.log" "$rigBodyMarker" )" yes
rigAssert "536 slack ok: the send log has one line" "$( LC_ALL=C awk 'END { print NR ; }' "$rigSendLog" 2>/dev/null )" 1
rigAssert "536 slack ok: that line reads ok" "$( LC_ALL=C awk -F '\t' 'END { print $6 ; }' "$rigSendLog" 2>/dev/null )" ok

echo "-- a Slack send that fails --"
rigCall fail --member-comms-slack-send-message magic-team magic-team --identity-bot "$rigBodyMarker"
rigAssert "slack fail: rc is non-zero" "$( [ "$rigRc" -ne 0 ] && echo non-zero || echo 0 )" non-zero
rigExposure "slack fail" yes
rigAssert "536 slack fail: the send log has a second line" "$( LC_ALL=C awk 'END { print NR ; }' "$rigSendLog" 2>/dev/null )" 2
rigAssert "536 slack fail: that line reads failed" "$( LC_ALL=C awk -F '\t' 'END { print $6 ; }' "$rigSendLog" 2>/dev/null )" failed
rigAssert "536 slack fail: its reason carries Slack's error code" "$( LC_ALL=C awk -F '\t' 'END { print ( index( $7, "error=channel_not_found" ) ? "yes" : "no" ) ; }' "$rigSendLog" 2>/dev/null )" yes
rigAssert "536: the send log holds no token" "$( rigHas "$rigSendLog" "$rigSentinel" )" no
rigAssert "536: the send log holds no body" "$( rigHas "$rigSendLog" "$rigBodyMarker" )" no

rigAdf="{\"type\":\"doc\",\"version\":1,\"content\":[{\"type\":\"paragraph\",\"content\":[{\"type\":\"text\",\"text\":\"$rigBodyMarker\"}]}]}"

echo "-- an Atlassian call that succeeds --"
rigCall ok --client-comms-jira-comment-add client-rig RIG-1 --body-adf "$rigAdf"
grep -q 'rig.atlassian.invalid' "$rigScenario/argv.log" 2>/dev/null || rigRefuse "no Atlassian call reached the fake curl: $( grep -v SystemContext "$rigScenario/out" | grep -m1 -E "ERROR|WARNING" )"
rigAssert "atlassian ok: rc" "$rigRc" 0
rigExposure "atlassian ok" yes

echo "-- an Atlassian call that fails --"
rigCall fail --client-comms-jira-comment-add client-rig RIG-1 --body-adf "$rigAdf"
rigAssert "atlassian fail: rc is non-zero" "$( [ "$rigRc" -ne 0 ] && echo non-zero || echo 0 )" non-zero
rigExposure "atlassian fail" yes

echo "-- the harness scratch is created under \$TMPDIR --"
## Its scratch is where a harness call stages what it handles, so it has to be where
## the scans above look. One text round through a fake model endpoint that lists
## $TMPDIR while the harness is in flight.
rigHarnessDir="$rigTmp/harness"
mkdir -p "$rigHarnessDir/.local/temp" "$rigHarnessDir/tmp" "$rigTmp/hbin"
cp "$rigTest/check-fixtures/harness-scratch-check.curl.test.sh" "$rigTmp/hbin/curl" \
	|| rigRefuse "the fake curl fixture is missing: $rigTest/check-fixtures/harness-scratch-check.curl.test.sh"
chmod +x "$rigTmp/hbin/curl"
( PATH="$rigTmp/hbin:$PATH" ; cd "$rigHarnessDir" && env -u MDAT_DATA_ROOT -u MDAT_SPAWN_SESSION_ID HOME="$rigTmp/home" \
	TMPDIR="$rigHarnessDir/tmp" RIG_SCENARIO="$rigHarnessDir" MMDAPP="$rigHarnessDir" MDLT_ORIGIN="$MDLT_ORIGIN" \
	HARNESS_PROVIDER_NAME="exposure rig" HARNESS_SELF_NAME="AgentsCredentialExposureCheck.test.sh" \
	HARNESS_ENDPOINT="https://credential-exposure-check.invalid/v1/chat/completions" HARNESS_HOST="credential-exposure-check.invalid" \
	HARNESS_WIRE="OpenAiChat" HARNESS_CREDENTIAL_NAMES="none -- this check never reads one" \
	HARNESS_MODEL_LIGHT="rig-light" HARNESS_MODEL_MAIN="rig-main" HARNESS_TOKEN_LIGHT="rig-not-a-credential" HARNESS_TOKEN_MAIN="rig-not-a-credential" \
	MDAT_HARNESS_CONTEXT_TOKENS=0 MDAT_HARNESS_MAX_RESTARTS=1 \
	bash "$rigHere/AgentsUniversalHarness.sh" --access-root "$rigHarnessDir" RIG-TASK-MARKER ) > "$rigHarnessDir/out" 2> "$rigHarnessDir/err" || :
[ -s "$rigHarnessDir/rounds.log" ] || rigRefuse "the harness made no model call, so its scratch was never observed: $( grep -m1 -E 'ERROR' "$rigHarnessDir/err" )"
rigAssert "the harness scratch was under \$TMPDIR while it ran" "$( LC_ALL=C grep -c '^AgentsUniversalHarness\.' "$rigHarnessDir/tmpdir.log" 2>/dev/null )" 1
rigAssert "and it was removed after" "$( ls -1 "$rigHarnessDir/tmp" | LC_ALL=C grep -c '^AgentsUniversalHarness\.' )" 0

## A mktemp with no path template ignores $TMPDIR on Darwin -- bare, and with -t alike --
## and writes to the shared per-user temp dir no rig can scan. Keeping every call on an
## explicit path template keeps the scans above complete by construction. Comment lines
## are not code and are skipped. Two limits, by design: a call split across a `\` line
## continuation is not seen, and *.test.sh rigs are not scanned -- they only need a
## unique temp tree, and this rig's own scratch still uses -t.
rigUntemplatedMktemp(){ ## directory holding sh-lib and sh-scripts -> file:line of each offending call
	find "$1/sh-lib" "$1/sh-scripts" -type f \( -name '*.include' -o -name '*.sh' \) ! -name '*.test.sh' 2>/dev/null \
	| while IFS= read -r rigScanFile ; do
		LC_ALL=C grep -n -E 'mktemp([[:space:]]+-[dqu]+)*[[:space:]]*($|[);|&`])|mktemp([[:space:]]+-[dqu]+)*[[:space:]]+-[dqu]*t' "$rigScanFile" \
			| LC_ALL=C grep -v -E '^[0-9]+:[[:space:]]*#' | sed "s|^|${rigScanFile##*/}:|"
	done
}
echo "-- every mktemp in package code takes an explicit path template --"
rigPackage="${rigHere%/sh-lib}"
mkdir -p "$rigTmp/plant/sh-lib" "$rigTmp/plant/sh-scripts"
printf '#!/usr/bin/env bash\nrigPlanted="$( mktemp )"\n' > "$rigTmp/plant/sh-lib/AgentsRigPlantedBare.include"
printf '#!/usr/bin/env bash\nrigPlanted="$( mktemp -d -t rig-planted-XXXXXX )"\n' > "$rigTmp/plant/sh-scripts/RigPlantedDashT.sh"
printf '#!/usr/bin/env bash\nrigPlanted="$( mktemp -d "${TMPDIR:-/tmp}/rig.XXXXXX" )"\n' > "$rigTmp/plant/sh-lib/AgentsRigPlantedGood.include"
rigAssert "control: a planted bare mktemp and a planted -t mktemp are both caught, a templated one is not" \
	"$( rigUntemplatedMktemp "$rigTmp/plant" | cut -d: -f1 | LC_ALL=C sort | tr '\n' ' ' )" "AgentsRigPlantedBare.include RigPlantedDashT.sh "
rigAssert "no untemplated mktemp in package code" "$( rigUntemplatedMktemp "$rigPackage" | head -n 3 | tr '\n' ' ' )" ""

if [ "$rigFails" -ne 0 ] ; then
	echo "⛔ CREDENTIAL EXPOSURE CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2 ; exit 1
fi
printf 'CREDENTIAL_EXPOSURE: OK (%d assertions, offline, temp workspace)\n' "$rigPasses"
