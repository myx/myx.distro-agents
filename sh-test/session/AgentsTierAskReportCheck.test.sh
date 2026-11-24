#!/usr/bin/env bash
## Behavioural check on the reach of stage 4 (stage 4b): a session's unaddressed question and handback
## follow the tier, through the one function that already answers where a session's own message goes --
## `AgentsToolsCommsPrintbackSessionOwnTarget` -- and not through a second rule.
## Held, one case per statement:
##   0. control: both paths run here, and a session that records no tier keeps today's rule, so a change
##      beside it is the tier's and not the rig's
##   A1. a `private` session with no route of its own posts its unaddressed question to the private
##      conversation. The ladder decides first: a run that names a `reports-to` addresses it, and the
##      tier decides only the unaddressed case, which is the shape with no spawn record.
##   A2. control: the same question from a session that records no tier resolves as it always did
##   H1. a `public` session's unaddressed handback is refused, and nothing is posted to a team store
##   H2. control: a `shared` session's handback still reaches the coordinator
## Red before stage 4b: A1 fails, since the question resolves to the session thread, and H1 fails, since
## the handback resolves and posts. A2 and H2 hold as the controls they are.
## Offline: a Slack-shaped fake curl first on PATH; every workspace is a folder of the rig's own.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigAsk="$rigPackage/sh-lib/harness/AgentsHarnessAsk.include"
rigReports="$rigPackage/sh-lib/harness/AgentsHarnessReports.include"
rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigAsk" ] && [ -f "$rigReports" ] || rigRefuse "the ask and report paths are not at the origin this run resolves"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsTierAskReportCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSessions="$rigWs/.local/agents/sessions"
rigSpawned="$rigWs/.local/agents/spawned"
rigHome="$rigTmp/home"
rigScenario="$rigTmp/scenario"
mkdir -p "$rigWs/.local/.agents" "$rigSessions" "$rigSpawned" "$rigHome" "$rigTmp/bin" "$rigScenario/scratch" \
	"$rigWs/.local/agents/members/magic-tester" "$rigWs/.local/agents/members/magic-coordinator" || rigRefuse "cannot make the rig"
printf -- '---\nname: magic-tester\ndescription: rig member\n---\n' > "$rigWs/.local/agents/members/magic-tester/SKILL.md"
printf -- '---\nname: magic-coordinator\ndescription: rig member\n---\n' > "$rigWs/.local/agents/members/magic-coordinator/SKILL.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' \
	> "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-magic-tester\n' > "$rigWs/.local/.agents/magic-tester.agent.env"
cp "$rigPackage/sh-test/check-fixtures/slack-send-identity-check.curl.stub.sh" "$rigTmp/bin/curl" \
	|| rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
export PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so a case could reach a socket"
: > "$rigScenario/calls" ; : > "$rigScenario/bodies"

## One session, on the `full` kind with its own thread, recording the tier given (or none). With a route,
## it carries a spawn record naming `reports-to: magic-coordinator`, which is the shape whose question and
## handback the ladder decides. Without one, it is the shape whose target the tier decides.
rigSession(){ ## name, tier or - for none, route (yes|no)
	local rigName="$1"
	mkdir -p "$rigSessions/$rigName"
	printf 'full\n' > "$rigSessions/$rigName/root-session.kind"
	printf 'CRIG00001:1700000000.000001\n' > "$rigSessions/$rigName/session.thread"
	[ "$2" = - ] || printf '%s\n' "$2" > "$rigSessions/$rigName/security.tier"
	if [ "$3" = yes ] ; then
		mkdir -p "$rigSpawned/run-$rigName"
		printf -- '---\nsession-id: %s\nspawn-id: run-%s\nowner: magic-tester\nreports-to: magic-coordinator\nstatus: spawn-started\n---\n\n# rig\n' \
			"$rigName" "$rigName" > "$rigSpawned/run-$rigName/run-$rigName.spawn.md"
	fi
	printf '%s\n' "$rigName"
}

rigPass=0 ; rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
## Where an unaddressed question of one session goes: the output of the call, kept whole.
rigAskOut="" ; rigAskRc=0
rigAskTo(){ ## session
	: > "$rigScenario/calls" ; : > "$rigScenario/bodies"
	rigAskOut="$( env -i MMDAPP="$rigWs" HOME="$rigHome" PATH="$PATH" MDLT_ORIGIN="$MDLT_ORIGIN" RIG_SCENARIO="$rigScenario" \
		MDAT_SESSION_ID="$1" MDAT_SPAWN_SESSION_ID="run-$1" MDAT_SESSION_WORKSPACE="$rigWs" MDAT_SPAWN_AGENT=magic-tester \
		bash -c 'harnessScratch="$RIG_SCENARIO/scratch" ; mkdir -p "$harnessScratch" ; harnessAgent=magic-tester ;
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessAsk.include" ;
			AgentsHarnessAsk "" "a question of the rig" "" "" "false" "" "" magic-coordinator' 2>&1 )" ; rigAskRc=$?
}
## Where an unaddressed handback of one session resolves to: its one line of output.
rigRouteLine="" ; rigRouteRc=0
rigRoute(){ ## session
	: > "$rigScenario/calls" ; : > "$rigScenario/bodies"
	rigRouteLine="$( env -i MMDAPP="$rigWs" HOME="$rigHome" PATH="$PATH" MDLT_ORIGIN="$MDLT_ORIGIN" RIG_SCENARIO="$rigScenario" \
		MDAT_SESSION_ID="$1" MDAT_SPAWN_SESSION_ID="run-$1" MDAT_SESSION_WORKSPACE="$rigWs" MDAT_SPAWN_AGENT=magic-tester \
		bash -c 'harnessScratch="$RIG_SCENARIO/scratch" ; mkdir -p "$harnessScratch" ; harnessAgent=magic-tester ;
			harnessCurrentName=session-current ; harnessParentName=session-parent ;
			. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessReports.include" ;
			routeTo="" ; routeAddress="" ;
			AgentsHarnessReportRoute session-parent "" ; printf "rc=%s to=[%s] address=[%s]\n" "$?" "$routeTo" "$routeAddress"' 2>&1 )" ; rigRouteRc=$?
}
rigPosts(){ LC_ALL=C grep -c 'chat.postMessage' "$rigScenario/calls" 2> /dev/null || : ; }

echo "-- 0. control: both paths run here, and a session with no tier keeps today's rule --"
rigNone="$( rigSession rig-none - yes )"
rigAskTo "$rigNone"
rigAssert "an unaddressed question of a session with no tier still resolves, so the ask path runs here" \
	"[$( printf '%s\n' "$rigAskOut" | LC_ALL=C grep -q 'channel-id=' && printf resolved )]" "[resolved]"
rigRoute "$rigNone"
rigAssert "an unaddressed handback of a session with no tier still resolves" \
	"$( printf '%s\n' "$rigRouteLine" | LC_ALL=C grep -o 'rc=0' )" "rc=0"
if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ TIER ASK AND REPORT CHECK BROKEN: the control fails on the untouched tree, so no case beside it means anything" >&2
	exit 1
fi

echo "-- A1. a private session with no route of its own asks the private conversation --"
rigPrivate="$( rigSession rig-private private no )"
rigAskTo "$rigPrivate"
rigAssert "the question names the owner's direct conversation" \
	"$( printf '%s\n' "$rigAskOut" | LC_ALL=C grep -c -F 'channel-id=human-owner' )" "1"
rigAssert "and it is not refused for want of a target" \
	"$( printf '%s\n' "$rigAskOut" | LC_ALL=C grep -c -F 'nobody to ask' )" "0"

echo "-- A2. control: the same question from a session with no tier resolves as it always did --"
rigNoTier="$( rigSession rig-ask-plain - no )"
rigAskTo "$rigNoTier"
rigAssert "the no-tier question does not name the private conversation" \
	"$( printf '%s\n' "$rigAskOut" | LC_ALL=C grep -c -F 'channel-id=human-owner' )" "0"

echo "-- H1. a public session's unaddressed handback is refused, and nothing is posted --"
rigPublic="$( rigSession rig-public public yes )"
rigRoute "$rigPublic"
rigAssert "the handback is refused, and resolves to no target" \
	"$( printf '%s\n' "$rigRouteLine" | LC_ALL=C grep -c 'rc=[^0]' )" "1"
rigAssert "and no message of it reached a team store" "$( rigPosts )" 0

echo "-- H2. control: a shared session's handback still reaches the coordinator --"
rigShared="$( rigSession rig-shared shared yes )"
rigRoute "$rigShared"
rigAssert "the shared handback resolves and is addressed to the coordinator" \
	"$( printf '%s\n' "$rigRouteLine" | LC_ALL=C grep -c 'rc=0 .*address=\[magic-coordinator\]' )" "1"

echo "-- A3. a public session's unaddressed question is refused, and the refusal names the contacts route --"
## The tier's own refusal must reach the member here, as it does at the send and the handback. A member
## told only that no target was given cannot know where a public reply does go.
rigPublicAsk="$( rigSession rig-ask-public public no )"
rigAskTo "$rigPublicAsk"
rigAssert "nothing of the question was posted" "$( rigPosts )" 0
rigAssert "and the refusal names the contacts route" \
	"$( printf '%s\n' "$rigAskOut" | LC_ALL=C grep -c -i 'contact' )" "1"

if [ "$rigFail" -ne 0 ] ; then
	echo "⛔ TIER ASK AND REPORT CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2
	echo "  fix:  the ask and report paths' target rule -- never the assertion" >&2
	exit 1
fi
printf 'TIER_ASK_AND_REPORT: OK (%d assertions, offline)\n' "$rigPass"
