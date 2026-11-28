#!/usr/bin/env bash
## Check of the session chat key as the expansion it is (code-craft: a trivial function is inlined at every call site, in whatever
## file it stands). The key is one parameter expansion; a function and a global for it made every caller load the session chat
## include, 48 KB, to read four variables. Held:
##   1. no function and no global for the key remains in the library
##   2. a caller that needs nothing else of the chat include no longer loads it for the key
## Red before the change: the key was AgentsToolsSessionChatKeyInto, called from 15 files.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPkg="$MDLT_ORIGIN/myx/myx.distro-agents"
rigPass=0 ; rigFail=0
rigAssert(){ ## what, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}

echo "-- 1. no function and no global for the key --"
rigAssert "lines that name the key function or its global" \
	"$( LC_ALL=C grep -rhE 'AgentsToolsSessionChatKey(Into)?\b|agentsSessionChatKey' "$rigPkg/sh-lib" "$rigPkg/sh-scripts" | LC_ALL=C grep -cv '^[[:space:]]*##' )" 0

echo "-- 2. a caller that needs nothing else of the chat include does not load it --"
rigAssert "the default wait sources' loads of the chat include" \
	"$( LC_ALL=C grep -c 'AgentsTools\.SessionChat\.include' "$rigPkg/sh-lib/wait/AgentsTools.MemberWaitSourcesDefault.include" )" 0

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ SESSION CHAT KEY INLINE CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1
fi
printf 'SESSION_CHAT_KEY_INLINE: OK (%d assertions)\n' "$rigPass"
