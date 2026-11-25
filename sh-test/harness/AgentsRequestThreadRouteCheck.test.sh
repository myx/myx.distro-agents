#!/usr/bin/env bash
## Behavioural check on where a run answers the person whose message it started for. It runs the real functions.
## They are the report route, ReportFindings, AgentsHarnessAsk and the no-target send (AgentsHarnessToolSendMessageRun). Held:
##   1. A HANDBACK goes into the request thread where the run's own thread is that thread. Its person must be the human-owner or hold tier-client or above.
##      A direct conversation's thread counts only as the request itself. Any other person keeps the coordinator duty thread.
##   2. REPORTFINDINGS, the real report function, posts exactly once, to the route the same rule gives.
##   3. A QUESTION with no target is asked in the request thread, addressed to that person, under the same rule. Any other keeps the owner route.
##   4. A SEND WITH NO TARGET goes where the member was last asked, if that is younger than three owed periods, else into the request thread.
##      The send rig holds copies of three includes only. The Messages include defines the seat and dismiss refusals itself.
##      Two helpers it calls from other includes are stubbed in the rig: the seat take and the own post record. No other function may be missing.
## Every case asserts its own outcome. Each posting case asserts that exactly one post was made, so a path that posts nothing never passes.
## Offline: a fake curl answers the one Slack read, who wrote the root of the request thread, and a stub dispatcher takes the sends.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigRefuse(){ echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1 ; }
[ -f "$rigPackage/sh-lib/harness/AgentsHarnessReports.include" ] && [ -f "$rigPackage/sh-lib/harness/AgentsHarnessMessages.include" ] && [ -f "$rigPackage/sh-lib/harness/AgentsHarnessAsk.include" ] || rigRefuse "the harness includes are not at the origin this run resolves"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsRequestThreadRouteCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
rigWs="$rigTmp/ws"
rigSessions="$rigWs/.local/agents/sessions"
rigSpawned="$rigWs/.local/agents/spawned"
rigData="$rigTmp/data"
rigScenario="$rigTmp/scenario"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigWs/.local/agents/cache" "$rigSessions" "$rigSpawned" "$rigTmp/home" "$rigTmp/bin" "$rigTmp/skills" "$rigScenario/scratch" \
	"$rigWs/.local/agents/schedule/duty-session" "$rigWs/.local/agents/members/magic-tester" "$rigWs/.local/agents/members/magic-coordinator" "$rigData/contacts/persons" || rigRefuse "cannot make the rig"
printf -- '---\nname: magic-tester\ndescription: rig member\n---\n' > "$rigWs/.local/agents/members/magic-tester/SKILL.md"
printf -- '---\nname: magic-coordinator\ndescription: rig member\n---\n' > "$rigWs/.local/agents/members/magic-coordinator/SKILL.md"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-magic-tester\n' > "$rigWs/.local/.agents/magic-tester.agent.env"
## The identity cache: a generation line, then one row a member. The human-owner's account is the one the check reads it from.
printf '1\nhuman-owner=URIGOWNER=owner=Rig Owner=Rig Owner=rig\n' > "$rigWs/.local/agents/cache/slack-identities.cache"
cat > "$rigTmp/bin/curl" <<'STUB'
#!/bin/sh
## The fake curl of this check: logs each Slack method. A read of a thread answers with one message, written by the account in the scenario's
## `author` file (the human-owner's by default), or with the error a `replies-error` file names. Every other method answers ok.
for a in "$@" ; do case "$a" in https://slack.com/api/*) m="${a#https://slack.com/api/}" ;; esac ; done
[ -t 0 ] || cat > /dev/null
printf '%s\n' "$m" >> "$RIG_SCENARIO/calls"
case "$m" in
	conversations.replies)
		if [ -s "$RIG_SCENARIO/replies-error" ] ; then printf '{"ok":false,"error":"%s"}\n' "$( head -1 "$RIG_SCENARIO/replies-error" )"
		else printf '{"ok":true,"messages":[{"ts":"1700000000.000100","user":"%s","text":"a request"}],"has_more":false}\n' "$( head -1 "$RIG_SCENARIO/author" 2> /dev/null || echo URIGOWNER )"
		fi
	;;
	auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"URIGBOT01"}\n' ;;
	*) printf '{"ok":true}\n' ;;
esac
STUB
chmod +x "$rigTmp/bin/curl"
export PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin"
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so a case could reach a socket"

## The four drivers: each is one small script, run in a clean environment with the rig's own variables.
cat > "$rigTmp/drive-prefix.sh" <<'DRIVER'
harnessScratch="$RIG_SCENARIO/scratch" ; mkdir -p "$harnessScratch" ; harnessAgent=magic-tester
harnessCurrentName=session-current ; harnessParentName=session-parent
DRIVER
cat > "$rigTmp/drive-route.sh" <<'DRIVER'
. "$RIG_PREFIX"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessReports.include"
routeTo="" ; routeAddress=""
AgentsHarnessReportRoute session-parent "" ; printf 'rc=%s to=[%s] address=[%s]\n' "$?" "$routeTo" "$routeAddress"
DRIVER
cat > "$rigTmp/drive-report.sh" <<'DRIVER'
. "$RIG_PREFIX"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessMessages.include"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessReports.include"
AgentsHarnessToolSendMessage(){ printf '%s|%s\n' "$1" "$4" >> "$RIG_SCENARIO/sends" ; printf 'Sent to %s.\n' "$1" ; }
AgentsHarnessToolReportFindings "" "a subject of the rig" "the findings of the rig" "the evidence of the rig" "high" "" ""
DRIVER
cat > "$rigTmp/drive-ask.sh" <<'DRIVER'
. "$RIG_PREFIX"
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessMessages.include"
AgentsHarnessToolSendMessage(){ printf '%s|%s\n' "$1" "$4" >> "$RIG_SCENARIO/sends" ; printf 'CORRECTION: the rig stops the question here.\n' ; }
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/harness/AgentsHarnessAsk.include"
AgentsHarnessAsk "" "a question of the rig" "" "" "false" "" "" magic-coordinator
DRIVER
cat > "$rigTmp/drive-send.sh" <<'DRIVER'
harnessAgent=keeper-rig harnessScratch="$RIG_SCRATCH" harnessCurrentName="" harnessParentName=""
. "$RIG_SRC" 2> /dev/null
AgentsHarnessSeatTake(){ return 1 ; }
AgentsHarnessOwnPostRecord(){ : ; }
AgentsHarnessToolSendMessageRun "" "a note" "" "" "" "" reply
DRIVER
mkdir -p "$rigTmp/origin/myx/myx.distro-agents/sh-scripts" "$rigTmp/origin/myx/myx.distro-agents/sh-lib/session" "$rigTmp/origin/myx/myx.distro-agents/sh-lib/member" "$rigTmp/origin/myx/myx.distro-agents/sh-lib/comms" "$rigTmp/send/.local/agents/schedule/owed" "$rigTmp/scratch" || rigRefuse "cannot make the send rig"
cat > "$rigTmp/origin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$RIG_CALLS"
cat > /dev/null
exit 0
STUB
chmod +x "$rigTmp/origin/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
for rigCopy in session/AgentsTools.SessionPause.include member/AgentsTools.OwedReplies.include comms/AgentsTools.SessionThreads.include ; do
	cp "$rigPackage/sh-lib/$rigCopy" "$rigTmp/origin/myx/myx.distro-agents/sh-lib/$rigCopy" || rigRefuse "the include $rigCopy is not at the origin this run resolves"
done

rigPass=0 ; rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 )) ; fi
}
## A session of the rig: its own thread, and a spawn record of a run that reports to a person.
rigSession(){ ## name, session thread
	mkdir -p "$rigSessions/$1" "$rigSpawned/run-$1"
	printf 'full\n' > "$rigSessions/$1/root-session.kind"
	printf '%s\n' "$2" > "$rigSessions/$1/session.thread"
	printf -- '---\nsession-id: %s\nspawn-id: run-%s\nowner: magic-tester\nreports-to: human-owner\nstatus: spawn-started\n---\n\n# rig\n' "$1" "$1" > "$rigSpawned/run-$1/run-$1.spawn.md"
}
## The coordinator's duty session, whose thread is the place of a report that may not go into a person's thread.
rigSession rig-duty CRIGDUTY01:1700000000.000300
printf 'rig-duty\n' > "$rigWs/.local/agents/schedule/duty-session/magic-coordinator"
## Who wrote the root of the request thread, and what the contact store holds of them.
rigAuthor(){ ## the account that wrote the root, or `error:<slack error>` for a read that fails
	rm -f "$rigScenario/replies-error" "$rigScenario/author"
	case "$1" in error:*) printf '%s\n' "${1#error:}" > "$rigScenario/replies-error" ;; *) printf '%s\n' "$1" > "$rigScenario/author" ;; esac
}
rigContact(){ ## id, account, tier line (may be empty), is-owner line (may be empty)
	{ printf -- '---\ntype: contact\ncontact-id: %s\ndisplay-name: rig %s\nreached-by: magic-tester\nslack-id: magic-tester:%s\n' "$1" "$1" "$2" ; [ -z "$3" ] || printf '%s\n' "$3" ; [ -z "$4" ] || printf '%s\n' "$4" ; printf -- '---\n# Contact: rig %s\n\n## Log\n\n' "$1" ; } > "$rigData/contacts/persons/$1.md"
}
rigEnv(){ ## session, request threads (may be empty): the clean environment of one call
	env -i MMDAPP="$rigWs" HOME="$rigTmp/home" PATH="$PATH" MDLT_ORIGIN="$MDLT_ORIGIN" RIG_SCENARIO="$rigScenario" RIG_PREFIX="$rigTmp/drive-prefix.sh" MDAT_DATA_ROOT="$rigData" MDAT_SKILLSET_ROOT="$rigTmp/skills" \
		MDAT_SESSION_ID="$1" MDAT_SPAWN_SESSION_ID="run-$1" MDAT_SESSION_WORKSPACE="$rigWs" MDAT_SPAWN_AGENT=magic-tester MDAT_SESSION_THREAD="$( head -1 "$rigSessions/$1/session.thread" )" ${2:+"MDAT_CONVERSATION_THREADS=$2"} \
		bash "$3" 2>&1
}
rigRouteLine=""
rigRoute(){ ## session, request threads
	: > "$rigScenario/calls"
	rigRouteLine="$( rigEnv "$1" "$2" "$rigTmp/drive-route.sh" )"
}
rigTo(){ printf '%s\n' "$rigRouteLine" | LC_ALL=C sed -n 's/^rc=[0-9]* to=\[\([^]]*\)\] address=\[\([^]]*\)\]$/\1|\2/p' | head -1 ; }
rigSentLines(){ LC_ALL=C grep -c . "$rigScenario/sends" 2> /dev/null || : ; }
rigSentFirst(){ head -1 "$rigScenario/sends" 2> /dev/null || : ; }
rigGateReads(){ LC_ALL=C grep -c '^conversations.replies$' "$rigScenario/calls" 2> /dev/null || : ; }

rigOwnerThread=CRIGREQ01:1700000000.000100
rigDirectThread=DRIGDIR01:1700000000.000100
rigSession rig-chan "$rigOwnerThread"
rigSession rig-direct "$rigDirectThread"
rigContact rig-client UCLIENT0001 "tier: tier-client" ""
rigContact rig-plain UPLAIN00001 "tier: tier-contact" ""
rigContact rig-boss UBOSS000001 "" "is-owner: yes"
rigContact rig-admin UADMIN00001 "tier: tier-admin" ""
rigContact rig-owner UOWNER00001 "tier: tier-owner" ""

echo "-- 1. a handback goes into the request thread, for a person who may read it --"
rigAuthor URIGOWNER
rigRoute rig-chan "$rigOwnerThread"
rigAssert "control: the owner wrote the root of the run's own channel thread: the report goes there, addressed to the coordinator, after one read" \
	"$( rigTo ):$( rigGateReads )" "session-current|magic-coordinator:1"
rigRoute rig-direct "$rigDirectThread"
rigAssert "the owner's direct thread that is the request: the report goes there too" "$( rigTo )" "session-current|magic-coordinator"
rigRoute rig-direct "DRIGDIR01:1700000000.000999"
rigAssert "a direct thread that is not the request is still refused: the report keeps the coordinator duty thread" "$( rigTo )" "CRIGDUTY01:1700000000.000300|magic-coordinator"
rigRoute rig-direct ""
rigAssert "a run with no request thread keeps the old route for a direct thread" "$( rigTo )" "CRIGDUTY01:1700000000.000300|magic-coordinator"
rigRoute rig-chan "$rigOwnerThread $rigDirectThread"
rigAssert "two conversation threads are no request: the report keeps the coordinator duty thread, and no root is read" "$( rigTo ):$( rigGateReads )" "CRIGDUTY01:1700000000.000300|magic-coordinator:0"
rigAuthor UCLIENT0001
rigRoute rig-chan "$rigOwnerThread"
rigAssert "a contact at tier-client wrote the root: the report goes into that thread" "$( rigTo )" "session-current|magic-coordinator"
rigAuthor UBOSS000001
rigRoute rig-chan "$rigOwnerThread"
rigAssert "a contact the record marks as an owner wrote the root: the report goes into that thread" "$( rigTo )" "session-current|magic-coordinator"
rigAuthor UADMIN00001
rigRoute rig-chan "$rigOwnerThread"
rigAssert "a contact at tier-admin wrote the root: the report goes into that thread" "$( rigTo )" "session-current|magic-coordinator"
rigAuthor UOWNER00001
rigRoute rig-chan "$rigOwnerThread"
rigAssert "a contact at tier-owner wrote the root: the report goes into that thread" "$( rigTo )" "session-current|magic-coordinator"
rigAuthor UPLAIN00001
rigRoute rig-chan "$rigOwnerThread"
rigAssert "a contact at tier-contact wrote the root: the report keeps the coordinator duty thread, and the route says so" \
	"$( rigTo ):$( printf '%s\n' "$rigRouteLine" | LC_ALL=C grep -c 'keep their usual place' )" "CRIGDUTY01:1700000000.000300|magic-coordinator:1"
rigAuthor USTRANGER01
rigRoute rig-chan "$rigOwnerThread"
rigAssert "an account no record holds wrote the root: the report keeps the coordinator duty thread" "$( rigTo )" "CRIGDUTY01:1700000000.000300|magic-coordinator"
rigRoute rig-direct "$rigDirectThread"
rigAssert "the same stranger in a direct thread: the report keeps the coordinator duty thread" "$( rigTo )" "CRIGDUTY01:1700000000.000300|magic-coordinator"
rigAuthor error:channel_not_found
rigRoute rig-chan "$rigOwnerThread"
rigAssert "a root that cannot be read: the report keeps the coordinator duty thread, and the route says why" \
	"$( rigTo ):$( printf '%s\n' "$rigRouteLine" | LC_ALL=C grep -c 'could not be read' )" "CRIGDUTY01:1700000000.000300|magic-coordinator:1"

echo "-- 2. ReportFindings, the real report function, posts once, to the same route --"
rigReport(){ ## session, request threads
	: > "$rigScenario/calls" ; : > "$rigScenario/sends"
	rigEnv "$1" "$2" "$rigTmp/drive-report.sh" > "$rigScenario/report.out"
}
rigAuthor URIGOWNER
rigReport rig-chan "$rigOwnerThread"
rigAssert "control: the owner's request thread: exactly one post, to the run's own thread, addressed to the coordinator" "$( rigSentLines ):$( rigSentFirst )" "1:session-current|magic-coordinator"
rigAuthor USTRANGER01
rigReport rig-chan "$rigOwnerThread"
rigAssert "a stranger's request thread: exactly one post, to the coordinator duty thread" "$( rigSentLines ):$( rigSentFirst )" "1:CRIGDUTY01:1700000000.000300|magic-coordinator"

echo "-- 3. a question with no target is asked in the request thread, of the person who wrote it --"
rigAsk(){ ## session, request threads
	: > "$rigScenario/calls" ; : > "$rigScenario/sends"
	rigEnv "$1" "$2" "$rigTmp/drive-ask.sh" > "$rigScenario/ask.out"
}
rigAuthor URIGOWNER
rigAsk rig-chan ""
rigAssert "control: no request thread: exactly one question, to the owner, as it always went" "$( rigSentLines ):$( rigSentFirst )" "1:human-owner|human-owner"
rigAsk rig-chan "$rigOwnerThread"
rigAssert "the owner's request thread: exactly one question, in that thread, addressed to him" "$( rigSentLines ):$( rigSentFirst )" "1:$rigOwnerThread|human-owner"
rigAsk rig-direct "$rigDirectThread"
rigAssert "the owner's direct request thread: exactly one question, in that thread" "$( rigSentLines ):$( rigSentFirst )" "1:$rigDirectThread|human-owner"
rigAuthor UCLIENT0001
rigAsk rig-chan "$rigOwnerThread"
rigAssert "a contact at tier-client wrote the root: exactly one question, in that thread, addressed to that person" "$( rigSentLines ):$( rigSentFirst )" "1:$rigOwnerThread|UCLIENT0001"
rigAuthor UPLAIN00001
rigAsk rig-chan "$rigOwnerThread"
rigAssert "a contact at tier-contact wrote the root: exactly one question, to the owner, not in that thread" "$( rigSentLines ):$( rigSentFirst )" "1:human-owner|human-owner"
rigAuthor USTRANGER01
rigAsk rig-chan "$rigOwnerThread"
rigAssert "an account no record holds wrote the root: exactly one question, to the owner" "$( rigSentLines ):$( rigSentFirst )" "1:human-owner|human-owner"

echo "-- 4. a send with no target: the newest reply owed, else the request thread --"
rigCalls="$rigTmp/calls"
rigOwedFile="$rigTmp/send/.local/agents/schedule/owed/keeper-rig"
rigSend(){ ## request threads (may be empty)
	: > "$rigCalls"
	env -i HOME="$rigTmp/home" PATH="/usr/bin:/bin" MMDAPP="$rigTmp/send" MDLT_ORIGIN="$rigTmp/origin" RIG_CALLS="$rigCalls" RIG_SRC="$rigPackage/sh-lib/harness/AgentsHarnessMessages.include" RIG_SCRATCH="$rigTmp/scratch" ${1:+"MDAT_CONVERSATION_THREADS=$1" "MDAT_SESSION_THREAD=$1"} \
		bash "$rigTmp/drive-send.sh" > "$rigTmp/send.out" 2>&1
}
rigSendTarget(){ LC_ALL=C sed -n 's/.*--slack-send-message --team-member keeper-rig \([^ ]*\).*/\1/p' "$rigCalls" | head -1 ; }
rigSendCount(){ LC_ALL=C grep -c -- '--slack-send-message' "$rigCalls" 2> /dev/null || : ; }
rm -f "$rigOwedFile"
rigSend CRIGREQ01:1700000000.000100
rigAssert "nothing owed: exactly one post, in the thread the run was started for" "$( rigSendCount ):$( rigSendTarget )" "1:CRIGREQ01:1700000000.000100"
printf '%s\tslack:DRIGOWED02:1700000000.000500\tUPERSON1\ta question\n' "$( date +%s )" > "$rigOwedFile"
rigSend CRIGREQ01:1700000000.000100
rigAssert "a reply owed beats the request thread: exactly one post, in the thread the member was last asked in" "$( rigSendCount ):$( rigSendTarget )" "1:DRIGOWED02:1700000000.000500"
printf '%s\tslack:DRIGOWED02:1700000000.000500\tUPERSON1\ta question\n' "$(( $( date +%s ) - 86400 ))" > "$rigOwedFile"
rigSend CRIGREQ01:1700000000.000100
rigAssert "a reply owed for a day is stale: exactly one post, in the thread the run was started for" "$( rigSendCount ):$( rigSendTarget )" "1:CRIGREQ01:1700000000.000100"
rigAssert "no function was missing from the send rig beyond the two stubbed helpers" "$( LC_ALL=C grep 'not found' "$rigTmp/send.out" | LC_ALL=C head -3 | LC_ALL=C cut -c1-200 | LC_ALL=C tr '\n' '|' || : )" ""

if [ "$rigFail" -ne 0 ] ; then echo "⛔ REQUEST THREAD ROUTE CHECK FAILED: $rigFail of $(( rigPass + rigFail )) assertion(s)" >&2 ; exit 1 ; fi
printf 'REQUEST_THREAD_ROUTE: OK (%d assertions, offline, rig tree only)\n' "$rigPass"
