#!/usr/bin/env bash
## Behavioural check on the search-answer cache (epic S21.13, owner 2026-11-01, option one): the answer of one search kept by
## its query signature, with its own TTL, so a repeated search inside that TTL asks Slack nothing. Held:
##   1. the same question names the same signature, and any part of it changing names another
##   2. a signature never filed is a miss, with rc 1 and nothing printed
##   3. an answer filed is served whole, line for line
##   4. an answer past its TTL is a miss, and one inside it is served
##   5. a TTL of nought always misses
##   6. the entry sits in the one cache tree, `search/search-<signature>/`
## Offline: one mktemp tree, no network, nothing of the team's read.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigInclude="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.CommsCache.include"
[ -f "$rigInclude" ] || { echo "⛔ ERROR: the comms cache is not at the origin this workspace resolves: $rigInclude" >&2 ; exit 1 ; }

rigPasses=0
rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}
mkdir -p "$MMDAPP/.local/temp" || exit 1
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsCommsCacheSearchCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/ws/.local/temp" || exit 1
export MMDAPP="$rigTmp/ws"

. "$rigInclude"

echo "-- the three functions are there --"
rigAssert "the signature, the serve and the file" "$( for rigFn in AgentsToolsCommsCacheSearchSignature AgentsToolsCommsCacheSearchServe AgentsToolsCommsCacheSearchFile ; do type -t "$rigFn" > /dev/null 2>&1 && printf '%s ' "$rigFn" ; done )" "AgentsToolsCommsCacheSearchSignature AgentsToolsCommsCacheSearchServe AgentsToolsCommsCacheSearchFile "

echo "-- the same question names the same signature --"
rigSig="$( AgentsToolsCommsCacheSearchSignature magic-team 'deploy after:2026-10-30' 1793000000 5 true )"
rigAssert "one question, one name" "$rigSig" "$( AgentsToolsCommsCacheSearchSignature magic-team 'deploy after:2026-10-30' 1793000000 5 true )"
rigAssert "a different term names another" "$( [ "$rigSig" = "$( AgentsToolsCommsCacheSearchSignature magic-team 'release after:2026-10-30' 1793000000 5 true )" ] && echo same || echo other )" other
rigAssert "a different target names another" "$( [ "$rigSig" = "$( AgentsToolsCommsCacheSearchSignature human-owner 'deploy after:2026-10-30' 1793000000 5 true )" ] && echo same || echo other )" other
rigAssert "a different shape names another" "$( [ "$rigSig" = "$( AgentsToolsCommsCacheSearchSignature magic-team 'deploy after:2026-10-30' 1793000000 5 false )" ] && echo same || echo other )" other

echo "-- a signature never filed is a miss --"
rigAssert "nothing printed, and rc 1" "$( AgentsToolsCommsCacheSearchServe "$rigSig" 300 ; printf '|%s' $? )" "|1"

echo "-- an answer filed is served whole --"
AgentsToolsCommsCacheSearchFile "$rigSig" '## result=found
1793 | U1 | the deploy landed' 300
rigAssert "the head line comes back" "$( AgentsToolsCommsCacheSearchServe "$rigSig" 300 | LC_ALL=C grep -c '^## result=found' )" 1
rigAssert "and the match under it" "$( AgentsToolsCommsCacheSearchServe "$rigSig" 300 | LC_ALL=C grep -c 'the deploy landed' )" 1
rigAssert "the entry sits in the one cache tree" "$( [ -f "$MMDAPP/.local/cache/comms/search/search-$rigSig/answer.txt" ] && echo there || echo absent )" there

echo "-- its TTL decides, not the answer's presence --"
printf '%s %s\n' "$(( $( date +%s ) - 400 ))" 300 > "$MMDAPP/.local/cache/comms/search/search-$rigSig/.state.txt"
rigAssert "an answer 400 s old with a 300 s TTL is a miss" "$( AgentsToolsCommsCacheSearchServe "$rigSig" 300 ; printf '|%s' $? )" "|1"
rigAssert "with a 600 s TTL it is served" "$( AgentsToolsCommsCacheSearchServe "$rigSig" 600 | LC_ALL=C grep -c 'the deploy landed' )" 1
rigAssert "and a TTL of nought always misses" "$( AgentsToolsCommsCacheSearchServe "$rigSig" 0 ; printf '|%s' $? )" "|1"

printf '\n%d passed, %d failed\n' "$rigPasses" "$rigFails"
[ "$rigFails" = 0 ]
