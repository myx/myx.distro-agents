#!/usr/bin/env bash
## Behavioural check on the declared id kind of a configured setting (F6.11 R1): a value whose id is
## not the kind its setting declares is refused where the setting is checked, naming the kind the
## setting declares and the kind the value actually is -- never a warning that exits 0 and leaves a
## caller reading the value as usable. Only a `--required` setting gates that way; an `--optional`
## one stays informational, which is that operator's own stated contract. Offline; reads the package.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
pass=0 fail=0
check(){ if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; pass=$(( pass + 1 )) ; else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; fail=$(( fail + 1 )) ; fi ; }
rigWs="$( mkdir -p "${MMDAPP:?⛔ ERROR: MMDAPP is not set}/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsOwnerChannelIdKindCheck.XXXXXX" )" || exit 1
trap 'rm -rf -- "$rigWs"' EXIT
mkdir -p "$rigWs/.local/.agents"

## Each call runs in a shell of its own, as the tool resolves its origin in one.
rigCheck(){ ## args -- this call's verdict lines, stdout only
	MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-check-configs magic-team "$@" --context check-id-kind 2> /dev/null
}
rigCheckRc(){ ## args -- the status that call returned
	MMDAPP="$rigWs" MDLT_ORIGIN="$MDLT_ORIGIN" "$BASH" "$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" --intern-op-check-configs magic-team "$@" --context check-id-kind > /dev/null 2>&1
	printf '%s' "$?"
}
rigSet(){ ## key=value lines -- rewritten whole into the magic-team scope
	printf '%s\n' "$@" > "$rigWs/.local/.agents/magic-team.agent.env"
}
rigTeamChannel(){ rigCheck --required 'SLACK_CHANNEL_MAGIC_TEAM:<channel-id>' --expect-id-kind SLACK_CHANNEL_MAGIC_TEAM:channel ; }
rigTeamChannelRc(){ rigCheckRc --required 'SLACK_CHANNEL_MAGIC_TEAM:<channel-id>' --expect-id-kind SLACK_CHANNEL_MAGIC_TEAM:channel ; }
rigOwnerAlias(){ rigCheck --required 'SLACK_CHANNEL_HUMAN_OWNER:<user-id>' --expect-id-kind SLACK_CHANNEL_HUMAN_OWNER:user ; }
rigOwnerAliasRc(){ rigCheckRc --required 'SLACK_CHANNEL_HUMAN_OWNER:<user-id>' --expect-id-kind SLACK_CHANNEL_HUMAN_OWNER:user ; }
rigOwnerAliasUndeclared(){ rigCheck --required 'SLACK_CHANNEL_HUMAN_OWNER:<user-id>' ; }
rigOwnerAliasUndeclaredRc(){ rigCheckRc --required 'SLACK_CHANNEL_HUMAN_OWNER:<user-id>' ; }
rigEventTrack(){ rigCheck --optional 'SLACK_CHANNEL_EVENT_TRACK:<channel-id>' --expect-id-kind SLACK_CHANNEL_EVENT_TRACK:channel ; }
rigEventTrackRc(){ rigCheckRc --optional 'SLACK_CHANNEL_EVENT_TRACK:<channel-id>' --expect-id-kind SLACK_CHANNEL_EVENT_TRACK:channel ; }

echo "-- 1. a required setting holding an id of another kind is refused --"
rigSet 'SLACK_CHANNEL_MAGIC_TEAM=U0NOTACHANNEL'
check "the setting says FAIL, and never WARN" "$( rigTeamChannel | LC_ALL=C grep -c '^SLACK_CHANNEL_MAGIC_TEAM: FAIL$' )" "1"
check "and the check-configs call fails" "$( rigTeamChannelRc )" "1"
check "naming the kind the setting declares" "$( rigTeamChannel | LC_ALL=C grep -cF 'a public channel id (C...)' )" "1"
check "naming the kind the value actually is" "$( rigTeamChannel | LC_ALL=C grep -cF 'a user id (U...)' )" "1"
check "and its own detail line is a fault, not a warning" "$( rigTeamChannel | LC_ALL=C grep -c '^  fail: ' )" "1"

echo "-- 2. R1: a conversation id given for the owner alias is refused --"
rigSet 'SLACK_CHANNEL_HUMAN_OWNER=C0GROUPDM01'
check "a public channel id: FAIL" "$( rigOwnerAlias | LC_ALL=C grep -c '^SLACK_CHANNEL_HUMAN_OWNER: FAIL$' )" "1"
check "and the call fails" "$( rigOwnerAliasRc )" "1"
check "and nothing in it reads as a warning" "$( rigOwnerAlias | LC_ALL=C grep -c 'WARN' )" "0"
check "naming the kind it found" "$( rigOwnerAlias | LC_ALL=C grep -cF 'a public channel id (C...)' )" "1"
rigSet 'SLACK_CHANNEL_HUMAN_OWNER=G0GROUPDM02'
check "a group/private channel id: FAIL" "$( rigOwnerAlias | LC_ALL=C grep -c '^SLACK_CHANNEL_HUMAN_OWNER: FAIL$' )" "1"
check "and the call fails" "$( rigOwnerAliasRc )" "1"
check "naming the kind it found" "$( rigOwnerAlias | LC_ALL=C grep -cF 'a group/private channel id (G...)' )" "1"

echo "-- 3. the declared kind, held: the setting is well formed --"
rigSet 'SLACK_CHANNEL_HUMAN_OWNER=U0OWNER'
check "OK, and no fault line" "$( rigOwnerAlias | LC_ALL=C grep -c '^SLACK_CHANNEL_HUMAN_OWNER: OK$' )" "1"
check "and the check-configs call succeeds" "$( rigOwnerAliasRc )" "0"

echo "-- 4. an optional setting keeps its informational shape --"
rigSet 'SLACK_CHANNEL_EVENT_TRACK=U0NOTACHANNEL'
check "WARN, as an optional setting's fault always was" "$( rigEventTrack | LC_ALL=C grep -c '^SLACK_CHANNEL_EVENT_TRACK: WARN$' )" "1"
check "and the check-configs call still succeeds" "$( rigEventTrackRc )" "0"

echo "-- 5. an unset required setting is unchanged --"
rigSet ''
check "FAIL, as a required setting's absence always was" "$( rigCheck --required 'SLACK_CHANNEL_MAGIC_TEAM:<channel-id>' | LC_ALL=C grep -c '^SLACK_CHANNEL_MAGIC_TEAM: FAIL$' )" "1"
check "and the check-configs call fails" "$( rigCheckRc --required 'SLACK_CHANNEL_MAGIC_TEAM:<channel-id>' )" "1"

echo "-- 6. a setting whose kind nobody declares is not judged at all --"
rigSet 'SLACK_CHANNEL_HUMAN_OWNER=C0GROUPDM01'
check "no declaration, no verdict on the id kind" "$( rigOwnerAliasUndeclared | LC_ALL=C grep -c '^SLACK_CHANNEL_HUMAN_OWNER: OK$' )" "1"
check "and the check-configs call succeeds" "$( rigOwnerAliasUndeclaredRc )" "0"

if [ "$fail" = 0 ] ; then printf 'OWNER_CHANNEL_ID_KIND: OK (%s assertions, offline)\n' "$pass" ; exit 0 ; fi
printf '⛔ OWNER_CHANNEL_ID_KIND CHECK FAILED: %s of %s assertion(s)\n' "$fail" "$(( pass + fail ))" ; exit 1
