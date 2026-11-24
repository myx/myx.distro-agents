#!/usr/bin/env bash
## Behavioural check on the security tier's record in the session store (stage 1 of the security
## context tier set), run rather than read, against a rig workspace built here: one session folder
## per case, and the two functions the design gives the store -- `AgentsToolsSessionTierWrite` and
## `AgentsToolsSessionTierRead`.
## Held, one case per statement:
##   1. control: each of the four tiers is written and read back as itself, each in its own session,
##      so an empty answer is not an empty run
##   2. a word that is none of the four is refused, and nothing is recorded by the refusal
##   3. the word is the closed four, in one case: `Private` is no tier
##   4. an empty word is refused
##   5. a session with no folder is refused, and no folder is made for it
##   6. the write is whole or not at all: one line, one file, and no temporary left beside it
##   7. a session with nothing recorded reads as nothing, rc 1 -- absence is an answer, never a tier
##   8. the first record stands: a later write to the same session changes nothing (the design's
##      reading that a tier is written once and a restart never rewrites it)
## Red before stage 1: case 1 fails with the functions absent, and 2 to 8 fail with it.
## Offline: it writes only its own rig, and reads the package at the origin.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
## The design puts the write in a new include of the session store and the read in the store's own.
## Both are sourced, so a case holds whichever file the builder lands a function in.
rigStores="$rigPackage/sh-lib/session/AgentsTools.SessionStore.include $rigPackage/sh-lib/session/AgentsTools.SessionTier.include"
rigTierName="security.tier"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -d "$rigPackage" ] || rigRefuse "the package is not at the origin this run resolves: $rigPackage"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionTierStoreCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSessions="$rigWs/.local/agents/sessions"
mkdir -p "$rigWs/.local/.agents" "$rigSessions" || rigRefuse "cannot make the rig workspace"
export MMDAPP="$rigWs"

rigPass=0 ; rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

## One call of a store function, its standard output and its status kept apart: `rigOut` and `rigRc`.
## A function the package defines nowhere reads as `missing`, which no case accepts as a value.
rigOut="" ; rigRc=0
rigCall(){ ## function, arguments...
	rigOut="$( ( for rigSource in $rigStores ; do [ -f "$rigSource" ] || continue ; . "$rigSource" 2> /dev/null ; done ; "$@" ) 2> /dev/null )" ; rigRc=$?
	case "$rigRc" in 127) rigOut="missing" ;; esac
}
rigSession(){ ## name -- a session folder of its own
	mkdir -p "$rigSessions/$1"
}

echo "-- 1. control: each of the four tiers is written and read back --"
rigWritten=""
for rigTier in private system shared public ; do
	rigSession "rig-one-$rigTier"
	rigCall AgentsToolsSessionTierWrite "rig-one-$rigTier" "$rigTier"
	rigCall AgentsToolsSessionTierRead "rig-one-$rigTier"
	rigWritten="$rigWritten $rigOut"
done
rigAssert "each of the four tiers reads back as itself" "$rigWritten" " private system shared public"

echo "-- 2. a word that is none of the four is refused, and records nothing --"
rigSession rig-unknown
rigCall AgentsToolsSessionTierWrite rig-unknown shared
rigCall AgentsToolsSessionTierWrite rig-unknown secret
rigUnknownRc="$rigRc"
rigCall AgentsToolsSessionTierRead rig-unknown
rigAssert "a fifth word is refused, rc 1" "$rigUnknownRc" 1
rigAssert "and the tier before it stands: nothing was recorded by the refusal" "$rigOut" shared

echo "-- 3. the word is the closed four, in one case --"
rigSession rig-capital
rigCall AgentsToolsSessionTierWrite rig-capital Private
rigCapitalRc="$rigRc"
rigCall AgentsToolsSessionTierRead rig-capital
rigAssert "a capitalised Private is no tier: the write is refused and nothing is recorded" "$rigCapitalRc:$rigOut" "1:"

echo "-- 4. an empty word is refused --"
rigSession rig-empty
rigCall AgentsToolsSessionTierWrite rig-empty ""
rigAssert "an empty word is refused, rc 1" "$rigRc" 1

echo "-- 5. a session with no folder is refused --"
rigCall AgentsToolsSessionTierWrite rig-no-such-session private
rigAssert "a session the store holds no folder for is refused, rc 1" "$rigRc" 1
rigAssert "and no folder was made for it" "[$( [ -d "$rigSessions/rig-no-such-session" ] && printf made || printf none )]" "[none]"

echo "-- 6. one record, whole or not at all, and no temporary beside it --"
rigSession rig-whole
rigCall AgentsToolsSessionTierWrite rig-whole private
rigAssert "the session folder holds one record" "$( find "$rigSessions/rig-whole" -type f 2> /dev/null | LC_ALL=C grep -c . )" 1
rigAssert "it is one line" "$( [ -f "$rigSessions/rig-whole/$rigTierName" ] && LC_ALL=C wc -l < "$rigSessions/rig-whole/$rigTierName" | LC_ALL=C tr -d ' ' || printf none )" 1
rigAssert "and no temporary file stands beside it" "$( find "$rigSessions/rig-whole" -name "$rigTierName.??????" 2> /dev/null | LC_ALL=C grep -c . )" 0

echo "-- 7. nothing recorded reads as nothing, rc 1 --"
rigSession rig-no-tier
rigCall AgentsToolsSessionTierRead rig-no-tier
rigAssert "a session with no record prints nothing" "$rigOut" ""
rigAssert "and says so with rc 1, so no caller takes a silence for a tier" "$rigRc" 1

echo "-- 8. the first record stands --"
rigSession rig-once
rigCall AgentsToolsSessionTierWrite rig-once private
rigCall AgentsToolsSessionTierWrite rig-once public
rigCall AgentsToolsSessionTierRead rig-once
rigAssert "a later write to the same session leaves the tier it first recorded" "$rigOut" private

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SESSION TIER STORE CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	echo "  fix:  the tier record's own functions in sh-lib/session/ -- never the assertion" >&2
	exit 1
fi
printf 'SESSION_TIER_STORE: OK (%d assertions, offline)\n' "$rigPass"
