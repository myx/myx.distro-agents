#!/usr/bin/env bash
## Behavioural check on where a session's unaddressed message goes once the session carries a tier
## (stage 4 of the security context tier set), run rather than read, against a rig workspace built here.
## Held, one case per statement, through the one function that already decides this --
## `AgentsToolsCommsPrintbackSessionOwnTarget` -- and through `AgentsToolsCommsTierTarget`:
##   1. a session recording `private` resolves to the owner's direct conversation
##   2. a session recording `system` resolves to its own tooling thread, `<channel>:<ts>`
##   3. a session recording `shared` resolves to a team channel: `magic-team` or its own session thread
##   4. control: a session recording nothing keeps today's kind rule, unchanged -- `full` gives its
##      session thread, `none` gives its printback channel
##   5. the tier stands ahead of the kind: a `full`-kind session recording `private` resolves to the
##      owner's conversation, not to its session thread
##   6. `AgentsToolsCommsTierTarget` names each of the four, and `public` prints nothing at rc 2
##   7. a `private` session whose direct conversation cannot be reached resolves to nothing at rc 1,
##      which the send refuses -- it falls through nowhere
## Red before stage 4: cases 1, 2, 5, 6 and 7 fail; 3 passes only where the fall-through gives the
## session thread, and 4 holds as the guard it is.
## Offline: every Slack call is a fake curl; nothing leaves the rig.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigTool="$rigPackage/sh-scripts/DistroAgentsTools.fn.sh"
rigPrintback="$rigPackage/sh-lib/comms/AgentsTools.CommsPrintback.include"
rigTier="$rigPackage/sh-lib/comms/AgentsTools.CommsTier.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] && [ -f "$rigPrintback" ] || rigRefuse "the send path and the tool are not at the origin this run resolves"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsCommsTierTargetCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSessions="$rigWs/.local/agents/sessions"
rigHome="$rigTmp/home"
mkdir -p "$rigWs/.local/.agents" "$rigSessions" "$rigHome" "$rigTmp/bin" || rigRefuse "cannot make the rig"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' \
	> "$rigWs/.local/.agents/magic-team.agent.env"
printf '#!/bin/sh\nexit 7\n' > "$rigTmp/bin/curl"
chmod +x "$rigTmp/bin/curl"
export MMDAPP="$rigWs"
export HOME="$rigHome"
export PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin"

rigPass=0 ; rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}

## A session folder on one channel kind, with one thread on record, and the tier it records where given.
rigSession(){ ## name, kind|-, thread|-, tier|-
	mkdir -p "$rigSessions/$1"
	[ "$2" = - ] || printf '%s\n' "$2" > "$rigSessions/$1/root-session.kind"
	[ "$3" = - ] || printf '%s\n' "$3" > "$rigSessions/$1/session.thread"
	[ "$4" = - ] || printf '%s\n' "$4" > "$rigSessions/$1/security.tier"
}
## The tooling thread of a session on the `track` kind: the session's own record of it.
rigTrackThread(){ ## name, thread
	printf '%s\n' "$2" > "$rigSessions/$1/event-track.thread"
}

rigOut="" ; rigRc=0
rigOwnTarget(){ ## session
	rigOut="$( env -i MMDAPP="$rigWs" HOME="$rigHome" PATH="$PATH" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SESSION_ID="$1" MDAT_SPAWN_SESSION_ID="$1" MDAT_SESSION_WORKSPACE="$rigWs" \
		bash -c '. "$1" ; AgentsToolsCommsPrintbackSessionOwnTarget "$2"' rig "$rigPrintback" "$1" 2> /dev/null )" ; rigRc=$?
}
rigTierTarget(){ ## tier, session, member
	rigOut="$( env -i MMDAPP="$rigWs" HOME="$rigHome" PATH="$PATH" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_SESSION_ID="$2" MDAT_SPAWN_SESSION_ID="$2" MDAT_SESSION_WORKSPACE="$rigWs" \
		bash -c '. "$1" 2> /dev/null || exit 127 ; . "$2" 2> /dev/null || exit 127 ; AgentsToolsCommsTierTarget "$3" "$4" "$5"' \
		rig "$rigTier" "$rigPrintback" "$1" "$2" "${3:-magic-tester}" 2> /dev/null )" ; rigRc=$?
}

echo "-- 0. control: the rig itself works on the untouched tree --"
## The control proves the fixtures are read back by the package's own readers, so a case failing beside
## it is the tier's and not a broken rig.
rigSession rig-ctl full 'CRIG00001:1700000000.000007' -
rigTrackThread rig-ctl 'CRIGTRACK:1700000000.000008'
rigAssert "the session store resolves the rig's session folder" \
	"$( env -i MMDAPP="$rigWs" HOME="$rigHome" PATH="$PATH" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c \
		'. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SessionChat.include" ; AgentsToolsSessionChatDir rig-ctl' 2> /dev/null )" \
	"$rigSessions/rig-ctl"
rigAssert "the kind record reads back as the kind it was written with" \
	"$( env -i MMDAPP="$rigWs" HOME="$rigHome" PATH="$PATH" MDLT_ORIGIN="$MDLT_ORIGIN" bash -c \
		'. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/chat/AgentsTools.RootHarnessKind.include" ; AgentsToolsRootHarnessKindRead rig-ctl' 2> /dev/null )" \
	full
rigAssert "the session thread record reads back through the package's own reader" \
	"$( env -i MMDAPP="$rigWs" HOME="$rigHome" PATH="$PATH" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_SESSION_ID=rig-ctl \
		bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsTools.SessionThreads.include" ; AgentsToolsSessionCurrentThreadFind' 2> /dev/null )" \
	"CRIG00001:1700000000.000007"

if [ "$rigFail" -ne 0 ] && [ "$rigPass" -lt 3 ] ; then
	echo "⛔ COMMS TIER TARGET CHECK BROKEN: the control fails on the untouched tree, so no case beside it means anything" >&2
	exit 1
fi

echo "-- 1. a private session resolves to the owner's direct conversation --"
rigSession rig-priv full 'CRIG00001:1700000000.000001' private
rigOwnTarget rig-priv
rigAssert "the tier stands ahead of the kind: the owner's conversation, not the session thread" "$rigOut" human-owner

echo "-- 2. a system session resolves to its own tooling thread --"
## This case holds on the tree before stage 4 as well, by the kind rule: its proof is case 5, where the
## same tooling thread is named by a `full`-kind session, so only the tier can be what names it.
rigSession rig-sys track - system
rigTrackThread rig-sys 'CRIGTRACK:1700000000.000009'
rigOwnTarget rig-sys
rigAssert "the session's tooling thread, as the send path takes it" "$rigOut" "CRIGTRACK:1700000000.000009"

echo "-- 3. a shared session resolves to a team channel --"
rigSession rig-shared full 'CRIG00001:1700000000.000001' shared
rigOwnTarget rig-shared
case "$rigOut" in magic-team|CRIG00001:1700000000.000001) rigSharedVerdict=team-channel ;; *) rigSharedVerdict="$rigOut" ;; esac
rigAssert "magic-team or the session thread, and never the owner's conversation or a tooling thread" "$rigSharedVerdict" team-channel

echo "-- 4. control: a session recording nothing keeps today's kind rule --"
rigSession rig-plain-full full 'CRIG00001:1700000000.000001' -
rigOwnTarget rig-plain-full
rigAssert "a full-kind session with no tier keeps its session thread" "$rigOut" "CRIG00001:1700000000.000001"
rigSession rig-plain-none none - -
rigOwnTarget rig-plain-none
rigAssert "a none-kind session with no tier keeps its printback channel" "$rigOut" "printback:rig-plain-none"

echo "-- 5. the tier stands ahead of the kind, in the other direction too --"
rigSession rig-sys-full full 'CRIG00001:1700000000.000001' system
rigTrackThread rig-sys-full 'CRIGTRACK:1700000000.000010'
rigOwnTarget rig-sys-full
rigAssert "a full-kind session recording system gives its tooling thread, not its session thread" "$rigOut" "CRIGTRACK:1700000000.000010"

echo "-- 6. AgentsToolsCommsTierTarget names each tier, and public is no channel --"
rigTierTarget private rig-priv
rigAssert "private names the owner's direct conversation" "$rigOut" human-owner
rigTierTarget system rig-sys
rigAssert "system names the session's tooling thread" "$rigOut" "CRIGTRACK:1700000000.000009"
rigTierTarget shared rig-shared
case "$rigOut" in magic-team|CRIG00001:1700000000.000001) rigNamedVerdict=team-channel ;; *) rigNamedVerdict="$rigOut" ;; esac
rigAssert "shared names a team channel" "$rigNamedVerdict" team-channel
rigTierTarget public rig-shared
rigAssert "public prints nothing and answers rc 2, which is no channel a caller can post to" "$rigRc:$rigOut" "2:"

echo "-- 7. a tier whose channel is not there refuses, and falls through nowhere --"
rigSession rig-sys-nothread track - system
rigOwnTarget rig-sys-nothread
rigAssert "a system session with no tooling thread recorded resolves to nothing" "$rigOut" ""
rigAssert "and says so with rc 1, so the send refuses rather than falling back to the team channel" "$rigRc" 1

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ COMMS TIER TARGET CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	echo "  fix:  the tier's case in the send path's own target rule -- never the assertion" >&2
	exit 1
fi
printf 'COMMS_TIER_TARGET: OK (%d assertions, offline)\n' "$rigPass"
