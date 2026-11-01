#!/usr/bin/env bash
## Behavioural check on the reply address a Wait puts on every message it shows (owner 2026-11-01: the communication id of
## any message is its full pointer, `<conversation>:<ts>`, and a message shown without one is answered at the top of the
## conversation instead of in the thread it belongs to). Held, run and not read:
##   1. A thread source: every message answers in that thread, so the address is the channel and the thread's own ts.
##   2. A person's direct conversations, rendered behind `# in <conversation>`: each message answers at its own ts there.
##   3. A reply to one of the session's own posts (`# replies to your post <conversation>:<ts>`): the address is that thread.
##   4. A reply that names its thread (`[thread-reply of <ts>]`) answers there, and a top-level message at its own ts.
##   5. A source whose conversation is unknown: no address is invented, and the line is printed as it stands.
## Offline: the renderings are made here, and only the addressing awk is run.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigAwk="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib/member/AgentsWaitReplyAddress.awk"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigAwk" ] || rigRefuse "the reply-address awk is not at the origin this workspace resolves: $rigAwk"
rigFails=0 rigPasses=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 )) ; fi
}
rigAddressed(){ ## kind, source -- the addressed rendering of stdin
	LC_ALL=C awk -v kind="$1" -v source="$2" -f "$rigAwk"
}

echo "-- 1. a thread source: the thread's own ts is the address of every message in it --"
rigOut="$( printf '%s\n' '1793000003.000100 | U1 | [reactions: eyes x1 (U2)] a reply' '1793000009.000100 | U2 | another reply' \
	| rigAddressed slack "slack:C0BJ49W7ZCM:1793000000.000100:conversation" )"
rigAssert "each message answers in the thread, not at its own ts" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'reply-to: C0BJ49W7ZCM:1793000000.000100' )" "2"
rigAssert "and nothing of the source's own annotations is lost" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '\[reactions: eyes x1 (U2)\]' )" "1"

echo "-- 2. a person's direct conversations: each message answers at its own ts there --"
rigOut="$( printf '%s\n' '# in DC0BJ49XYZ' '1793000011.000100 | U3 | hello' '1793000012.000100 | U3 | again' \
	| rigAddressed dms "dms:magic-developer" )"
rigAssert "the conversation of the rendering is the address's, a line each" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'reply-to: DC0BJ49XYZ:17930000' )" "2"
rigAssert "and the marker line stands as it was" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c '^# in DC0BJ49XYZ$' )" "1"

echo "-- 3. a reply to one of the session's own posts: that thread is the address --"
rigOut="$( printf '%s\n' '# replies to your post C0BJ49W7ZCM:1793000000.000100' '1793000021.000100 | U4 | a reply to my post' \
	| rigAddressed replies "replies:9c75835b" )"
rigAssert "the address is the post's thread" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'reply-to: C0BJ49W7ZCM:1793000000.000100' )" "1"

echo "-- 4. a reply that names its thread answers in that thread, not at its own ts --"
rigOut="$( printf '%s\n' '# in C0BJ49W7ZCM' '1793494250.398389 | U6 | [thread-reply of 1793394716.507419] a reply' '1793494251.398389 | U6 | a top-level one' \
	| rigAddressed mentions "mentions:magic-developer" )"
rigAssert "the thread reply answers where the thread is" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'reply-to: C0BJ49W7ZCM:1793394716.507419' )" "1"
rigAssert "and a top-level message answers at its own ts" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'reply-to: C0BJ49W7ZCM:1793494251.398389' )" "1"

echo "-- 5. control: a source whose conversation is unknown invents no address --"
rigOut="$( printf '%s\n' '1793000031.000100 | U5 | a line with no conversation' | rigAddressed file "file:/tmp/rig-drop" )"
rigAssert "the line is printed as it stands" "$( printf '%s\n' "$rigOut" | LC_ALL=C grep -c 'reply-to' )" "0"

printf '\n%d passed, %d failed\n' "$rigPasses" "$rigFails"
[ "$rigFails" = 0 ]
