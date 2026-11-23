#!/usr/bin/env bash
## Behavioural check on the comms cache's key (sketch "Comms/Cache/Wait summary": the cache is keyed by the real channel id,
## and macros resolve above it; epic S1: member-agnostic, keyed by the real channel id, bound to the reading account).
## Held:
##   1. one channel read by two members is ONE entry, so the key carries no member's name
##   2. and the entry carries the channel id itself
##   3. a channel and one of its threads are two entries, the thread's named by the channel's plus its ts
##   4. a direct conversation carries the reading account, so the team bot and a member's own account are two entries
##   5. control: two channels are two entries, so the key is not one fixed name
## The key is a pure function of its arguments, so these rows need no pull and no network.
## Offline: one mktemp tree, nothing of the team's read.
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
rigTmp="$( mktemp -d "$MMDAPP/.local/temp/AgentsCommsCacheKeyCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigTmp"' EXIT
. "$rigInclude"

rigChannel="CRIG00001"
rigThread="1793000000.000100"

## The entry's name below the cache's own tree, as the cache resolves it: the caller never builds this path itself.
rigKey(){ ## member, as bot, channel, thread ts (optional)
	agentsCommsCacheDir=""
	AgentsToolsCommsCacheSlackDir "$@" || return 1
	printf '%s\n' "${agentsCommsCacheDir#"$MMDAPP"/.local/cache/comms/}"
}
## A member's own account id, as a read among its reads would keep it: the cache reads this file before it asks Slack.
rigAccount(){ ## member, the user id its reads go under
	mkdir -p "$MMDAPP/.local/cache/comms/slack" || exit 1
	printf '%s %s\n' "$( date +%s )" "$2" > "$MMDAPP/.local/cache/comms/slack/.user-id-$1.txt"
}

echo "-- 1. one channel read by two members is ONE entry --"
rigKey rig-member-a true CRIG00001 > "$rigTmp/key-a.txt"
rigKey rig-member-b true CRIG00001 > "$rigTmp/key-b.txt"
rigAssert "each member's read resolves an entry" "$( LC_ALL=C grep -c . "$rigTmp/key-a.txt" ):$( LC_ALL=C grep -c . "$rigTmp/key-b.txt" )" "1:1"
rigAssert "and it is the same one" "$( cat "$rigTmp/key-a.txt" )" "$( cat "$rigTmp/key-b.txt" )"
rigAssert "and no member's name is in it" "$( LC_ALL=C grep -c -e 'rig-member-a' -e 'rig-member-b' "$rigTmp/key-a.txt" )" 0

echo "-- 2. and the entry carries the channel id itself --"
rigAssert "the channel id is the entry's name" "$( cat "$rigTmp/key-a.txt" )" "slack/slack-CRIG00001"

echo "-- 3. a channel and one of its threads are two entries --"
rigKey rig-member-a true CRIG00001 1793000000.000100 > "$rigTmp/key-thread.txt"
rigAssert "the thread has an entry of its own" "$( cat "$rigTmp/key-thread.txt" )" "slack/slack-CRIG00001-1793000000.000100"
rigAssert "so the channel's read and its thread's read do not share one" "$( [ "$( cat "$rigTmp/key-a.txt" )" != "$( cat "$rigTmp/key-thread.txt" )" ] && echo two || echo one )" two

echo "-- 4. a direct conversation carries the reading account --"
rigAccount rig-member-a U0RIGACCTA
rigKey rig-member-a false D0RIGDM001 > "$rigTmp/key-mine.txt"
rigKey rig-member-a true D0RIGDM001 > "$rigTmp/key-bot.txt"
rigAssert "the member's own account keys its own entry" "$( cat "$rigTmp/key-mine.txt" )" "slack/slack-U0RIGACCTA-D0RIGDM001"
rigAssert "and the team bot's is another entry for the same conversation" "$( cat "$rigTmp/key-bot.txt" )" "slack/slack-bot-D0RIGDM001"
rigAssert "so two accounts on one conversation are two entries" "$( [ "$( cat "$rigTmp/key-mine.txt" )" != "$( cat "$rigTmp/key-bot.txt" )" ] && echo two || echo one )" two

echo "-- 5. control: two channels are two entries --"
rigKey rig-member-a true CRIG00002 > "$rigTmp/key-other.txt"
rigAssert "another channel is another entry" "$( cat "$rigTmp/key-other.txt" )" "slack/slack-CRIG00002"
rigAssert "so the key is not one fixed name" "$( [ "$( cat "$rigTmp/key-a.txt" )" != "$( cat "$rigTmp/key-other.txt" )" ] && echo two || echo one )" two

echo "-- 6. a macro resolves above the cache, so the macro and the id it resolves to read ONE entry --"
## The macro is resolved first, as every read path resolves its target, and only the resolved channel id reaches the key.
## The rig's own session thread, so the macro has somewhere real to point and no workspace of the caller's is read.
rigWs="$rigTmp/ws"
mkdir -p "$rigWs/.local/agents/sessions/rig-sess" "$rigWs/.local/temp" || exit 1
printf '%s:%s\n' "$rigChannel" "$rigThread" > "$rigWs/.local/agents/sessions/rig-sess/session.thread"
rigMacroKey="$(
	env -i PATH="/usr/bin:/bin:/usr/sbin:/sbin" HOME="$rigTmp" MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SPAWN_SESSION_ID=rig-sess \
		bash -c '. "$1" ; . "$2" ; rigResolved="$( DistroAgentsToolsResolveTarget session-current rig-member-a )" || exit 1
			rigChannel="$( printf "%s\n" "$rigResolved" | sed -n "s/^CHANNEL=//p" )"
			AgentsToolsCommsCacheSlackDir rig-member-a true "$rigChannel"
			printf "%s\n" "${agentsCommsCacheDir#"$MMDAPP"/.local/cache/comms/}"' _ \
		"$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.CommsResolveTarget.include" "$rigInclude" 2> /dev/null
)"
rigAssert "the macro resolves to an entry of its own" "$( [ -n "$rigMacroKey" ] && echo resolved || echo none )" resolved
rigAssert "and that entry is the one the channel id names, not the macro's own name" "$rigMacroKey" "slack/slack-$rigChannel"
rigAssert "so the macro's name appears in no entry" "$( LC_ALL=C grep -c 'session-current' <<< "$rigMacroKey" )" 0

printf '\n%d passed, %d failed\n' "$rigPasses" "$rigFails"
[ "$rigFails" = 0 ]
