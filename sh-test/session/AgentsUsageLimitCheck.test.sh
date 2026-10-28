#!/usr/bin/env bash
## Behavioural check on the usage-limit flag of a run (sh-lib/session/AgentsTools.UsageLimit.include): the real
## functions, sourced from the origin, called on the provider's own refusal wording (the fixture
## check-fixtures/provider-usage-limit.refused.txt) and on wordings that are no usage limit. Held:
##   1. the text: the provider's date and time and zone come out as the provider wrote them; a message with a time
##      and no zone keeps the time; a usage-limit message with no readable date is still flagged, saying the time
##      is not known; a rate limit that is no usage limit and an empty reason give nothing and rc 1
##   2. mark and read back: a mark writes the one line to the run's store, and the reader prints that line and
##      nothing else; a later mark of the same run replaces the line, it does not add a second
##   3. refusals write nothing: a reason that is no usage limit, an id with a slash or a dot name, an empty id and a
##      workspace-less call each return 1 and leave no store folder, no flag file and no temp file behind
##   4. a run with no flag reads rc 1 and prints nothing; an empty flag file reads rc 1
##   5. the flag is world-readable (a manager screen of another user reads it) and no `.tmp.` file is left
## Able to fail: the planted-positive of 1 and 2 is the fixture itself; a wrong date in the fixture's wording changes
## the printed date, and every assertion on the date compares with the date taken from the fixture's own text.
## Offline: the rig is a folder under this workspace's scratch; no endpoint, no credential.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigOrigin="${MDLT_ORIGIN:-$MMDAPP/.local}"
rigPkg="$rigOrigin/myx/myx.distro-agents"
rigInc="$rigPkg/sh-lib/session/AgentsTools.UsageLimit.include"
rigFixture="$rigPkg/sh-test/check-fixtures/provider-usage-limit.refused.txt"
[ -f "$rigInc" ] && [ -f "$rigFixture" ] || { echo "⛔ ERROR: include or fixture missing -- refusing to report a result" >&2 ; exit 1 ; }
. "$rigPkg/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsUsageLimitCheck )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
rigFail=0 ; rigCount=0
rigAssert(){ ## name, actual, expected
	rigCount=$(( rigCount + 1 ))
	if [ "$2" = "$3" ] ; then echo "  PASS  $1" ; else echo "  FAIL  $1" ; echo "        expected: $3" ; echo "        actual:   $2" ; rigFail=$(( rigFail + 1 )) ; fi
}

rigWs="$rigTmp/ws" ; mkdir -p "$rigWs/.local/agents/sessions"
rigSaved="$MMDAPP" ; MMDAPP="$rigWs"
. "$rigInc"

rigFixtureText="$( cat "$rigFixture" )"
rigFixtureDate="$( printf '%s' "$rigFixtureText" | sed -n 's/.*regain access on \([0-9-]*\) at \([0-9:]*\) \([A-Z]*\).*/\1 \2 \3/p' )"
rigAssert "control: the fixture carries a date to compare with" "${rigFixtureDate:+yes}" "yes"

echo "-- 1. the text --"
rigAssert "the provider's date, time and zone come out as written" "$( AgentsToolsUsageLimitText "$rigFixtureText" )" "stopped on the provider usage limit: reopens $rigFixtureDate"
rigAssert "no zone given: the time is kept" "$( AgentsToolsUsageLimitText 'You have reached your specified API usage limits. You will regain access on 2026-12-03 at 07:30.' )" "stopped on the provider usage limit: reopens 2026-12-03 07:30"
rigAssert "a usage limit with no date is flagged, saying the time is not known" "$( AgentsToolsUsageLimitText 'You have reached your specified API usage limits.' )" "stopped on the provider usage limit: reopens at a time the provider did not give"
## EVERY refusal that ends a run is flagged with its reason (sketch 3.6), not only the usage limit
rigAssert "a refusal that is no usage limit is flagged with its reason, as the provider wrote it" "$( AgentsToolsUsageLimitText 'rate_limit_error: slow down, too many requests' )" "stopped by a provider refusal: rate_limit_error: slow down, too many requests"
rigAssert "the host's wrapper words are left off, the reason stays" "$( AgentsToolsUsageLimitText 'openai refused the request -- invalid_request_error: your account is suspended' )" "stopped by a provider refusal: invalid_request_error: your account is suspended"
rigAssert "a refusal that gives the date access returns says it" "$( AgentsToolsUsageLimitText 'anthropic refused the request -- invalid_request_error: Credit exhausted. You will regain access on 2026-12-03 at 07:30 UTC.' )" "stopped by a provider refusal: invalid_request_error: Credit exhausted. You will regain access on 2026-12-03 at 07:30 UTC. -- access returns 2026-12-03 07:30 UTC"
rigAssert "a long reason is cut at 200 characters, saying so" "$( AgentsToolsUsageLimitText "$( printf 'x%.0s' $(seq 1 300) )" | wc -c | tr -d ' ' )" "$(( 31 + 200 + 3 ))"
AgentsToolsUsageLimitText '' > "$rigTmp/out" ; rigRc=$?
rigAssert "an empty reason gives rc 1 and nothing" "$rigRc $( wc -c < "$rigTmp/out" | tr -d ' ' )" "1 0"

echo "-- 2. mark and read back --"
AgentsToolsUsageLimitMark run-one "$rigFixtureText" ; rigRc=$?
rigAssert "a mark of the provider's refusal returns 0" "$rigRc" "0"
rigAssert "the reader prints the one line the store holds" "$( AgentsToolsUsageLimitRun run-one )" "stopped on the provider usage limit: reopens $rigFixtureDate"
rigAssert "the store file is one line" "$( wc -l < "$rigWs/.local/agents/sessions/run-one/usage-limit" | tr -d ' ' )" "1"
AgentsToolsUsageLimitMark run-one 'You have reached your specified API usage limits. You will regain access on 2027-01-02 at 03:04 UTC.'
rigAssert "a later mark replaces the line, it adds none" "$( cat "$rigWs/.local/agents/sessions/run-one/usage-limit" )" "stopped on the provider usage limit: reopens 2027-01-02 03:04 UTC"

AgentsToolsUsageLimitMark run-rate 'rate_limit_error: slow down' ; rigRc=$?
rigAssert "a refusal that is no usage limit is marked too, and read back as its reason" "$rigRc $( AgentsToolsUsageLimitRun run-rate )" "0 stopped by a provider refusal: rate_limit_error: slow down"

echo "-- 3. refusals write nothing --"
rigBefore="$( find "$rigWs/.local/agents/sessions" | LC_ALL=C sort | tr '\n' ' ' )"
rigRcs=""
AgentsToolsUsageLimitMark 'a/b' "$rigFixtureText" ; rigRcs="$rigRcs $?"
AgentsToolsUsageLimitMark '..' "$rigFixtureText" ; rigRcs="$rigRcs $?"
AgentsToolsUsageLimitMark '.' "$rigFixtureText" ; rigRcs="$rigRcs $?"
AgentsToolsUsageLimitMark '' "$rigFixtureText" ; rigRcs="$rigRcs $?"
AgentsToolsUsageLimitMark run-three '' ; rigRcs="$rigRcs $?"
rigAssert "each refused mark returns 1" "$rigRcs" " 1 1 1 1 1"
rigAssert "and the store is as it was: no folder, no flag, no temp file" "$( find "$rigWs/.local/agents/sessions" | LC_ALL=C sort | tr '\n' ' ' )" "$rigBefore"
rigAssert "nothing was written beside the workspace" "$( [ -e "$rigTmp/ws/.local/agents/sessions/run-two" ] || [ -e "$rigTmp/ws/.local/agents/sessions/a" ] && echo yes || echo no )" "no"
MMDAPP="" ; AgentsToolsUsageLimitMark run-four "$rigFixtureText" ; rigRc=$? ; MMDAPP="$rigWs"
rigAssert "with no workspace, a mark returns 1 and nothing is written" "$rigRc $( [ -e "$rigWs/.local/agents/sessions/run-four" ] && echo yes || echo no )" "1 no"

echo "-- 4. a run with no flag --"
AgentsToolsUsageLimitRun run-none > "$rigTmp/out" ; rigRc=$?
rigAssert "no store: rc 1 and nothing" "$rigRc $( wc -c < "$rigTmp/out" | tr -d ' ' )" "1 0"
mkdir -p "$rigWs/.local/agents/sessions/run-empty" ; : > "$rigWs/.local/agents/sessions/run-empty/usage-limit"
AgentsToolsUsageLimitRun run-empty > "$rigTmp/out" ; rigRc=$?
rigAssert "an empty flag file: rc 1 and nothing" "$rigRc $( wc -c < "$rigTmp/out" | tr -d ' ' )" "1 0"

echo "-- 5. mode and leftovers --"
rigMode="$( LC_ALL=C ls -l "$rigWs/.local/agents/sessions/run-one/usage-limit" | cut -c1-10 )"
rigAssert "the flag is world-readable" "$rigMode" "-rw-r--r--"
rigAssert "no temp file is left in the run's folder" "$( ls "$rigWs/.local/agents/sessions/run-one" | tr '\n' ' ' )" "usage-limit "

MMDAPP="$rigSaved"
if [ "$rigFail" = 0 ] ; then echo "USAGE_LIMIT: OK ($rigCount assertions, offline)" ; exit 0 ; fi
echo "USAGE_LIMIT: FAILED ($rigFail of $rigCount)" ; exit 1
