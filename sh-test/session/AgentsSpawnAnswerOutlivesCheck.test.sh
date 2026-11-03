#!/usr/bin/env bash
## Behavioural check on S6.33: an answer outlives the run that asked. A run that ends with a
## question of its own open used to have that question withdrawn without looking, so an answer
## already standing in its thread was lost and the person was told no answer was needed.
## Held, run rather than read, against a scenario workspace built here:
##   1. AN ANSWER ALREADY GIVEN IS NOT WITHDRAWN. The close of the run looks in the thread
##      first: the record closes as answered, with the answer it found, and never as withdrawn.
##   2. THE PERSON IS NOT TOLD AN ANSWER IS NOT NEEDED. No post of the close carries the
##      withdraw reason of the template.
##   3. THE ANSWER REACHES THE DUTY. It is written into the asker's own inbox as the note the
##      tooling writes for an answer that arrived after its session ended, holding the answer.
##   4. CONTROL: WITH NO REPLY THE QUESTION IS WITHDRAWN AS BEFORE, with the template's reason.
## Offline: a Slack-shaped fake curl answers the thread from a file here and logs each post;
## the workspace, the board and the inboxes are this rig's own temp tree.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigNote="tooling-note.post.format.md"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigPackage/sh-lib/session/AgentsTools.SpawnSandbox.include" ] || rigRefuse "the spawn sandbox include is not at the origin: $rigPackage"
[ -f "$rigPackage/sh-test/check-fixtures/harness-ask-check.curl.stub.sh" ] || rigRefuse "the fake curl fixture is missing from the package"
. "$rigPackage/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSpawnAnswerOutlivesCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
trap 'exit 1' INT TERM

rigPasses=0 rigFails=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPasses=$(( rigPasses + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFails=$(( rigFails + 1 ))
	fi
}

rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigData="$rigTmp/data" ; rigPend="$rigWs/.local/agents/pending"
rigSkills="$rigTmp/skills"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigWs/.local/temp" "$rigTmp/home" "$rigData/board/running" "$rigPend" "$rigData/inboxes/rig-member/incoming" "$rigSkills/rig-member" "$rigSkills/human-owner"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/rig-member/rig-member.basic.md"
printf -- '---\nmaintainers: human-owner\n---\nthe owner of this rig\n' > "$rigSkills/human-owner/human-owner.basic.md"
cp "$rigPackage/sh-test/check-fixtures/harness-ask-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "could not install the fake curl"
printf '%s\n' '#!/bin/sh' 'cat "${0%/*}/../uptime.line" 2> /dev/null' > "$rigTmp/bin/uptime"
printf ' 2:54  up 4 days,  6:19, 12 users, load averages: 1.25 1.00 1.00\n' > "$rigTmp/uptime.line"
chmod +x "$rigTmp/bin/curl" "$rigTmp/bin/uptime"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'SLACK_USER_TOKEN=rig-user-token-MEMBER\nSLACK_BOT_TOKEN=rig-bot-token-MEMBER\n' > "$rigWs/.local/.agents/rig-member.agent.env"
: > "$rigTmp/curl.log"

## A question of the run's own, as the tooling records one: the run's id is its asking session,
## the member is the owner, and the thread it stands in is the one the close reads. A fourth word
## makes it a typed ask -- a decision, a readback or a permission -- which is asked with an
## answer form and read by the escalation ops.
rigAsk(){ ## id, question ts, session id, kind (empty for a plain question)
	{
		printf -- '---\nstatus: reply-pending\nowner: rig-member\nhost: rig\n'
		printf 'communication-channel-id: slack:CRIG00001\nblocked-on: reply from URIGOWNER\nsession-id: %s\n' "$3"
		[ -z "${4:-}" ] || printf 'kind: %s\nselect: one\n' "$4"
		printf 'address-to: human-owner\nchannel: CRIG00001\nquestion-ts: %s\nthread-ts: %s\n' "$2" "$2"
		printf 'addressees: URIGOWNER\nasking-accounts: URIGSELF1\nasked-at: 2026-11-03 12:00 +0200\n---\n\n'
		printf '# Question asked\n\n# ❓ May the rig keep the report?\n'
	} > "$rigPend/$1.md"
	[ -z "${4:-}" ] || printf 'yes: keep it\nno: drop it\n' > "$rigPend/$1.options"
}
## The run's own record, started, as the close finds it: the close acts on a record that says started.
rigRun(){ ## spawn id
	mkdir -p "$rigWs/.local/agents/spawned/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nparent-spawn-id: rig-parent\nowner: rig-member\nhost: rig\nstatus: spawn-started\nsession-thread: CRIG00001:1700000000.000001\nparent-session-id: rig-parent-session\nparent-member: magic-coordinator\n---\n' \
		"$1" "$1" > "$rigWs/.local/agents/spawned/$1/$1.spawn.md"
}
rigClose(){ ## spawn id -- the close the proxy makes when a run ends
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" \
		RIG_SCENARIO="$rigTmp" RIG_CURL_LOG="$rigTmp/curl.log" MDAT_SPAWN_AGENT=rig-member \
		MDAT_COLLECT_THREAD=off MDAT_COMMS_READER=off MDAT_WAIT_REMIND=off MDAT_TEAM_DATA_COMMIT_THREAD=off \
		bash -c '. "$1" ; AgentsToolsSpawnProxyCloseSandbox "$2" succeeded 0 "the rig ended it"' rig \
		"$rigPackage/sh-lib/session/AgentsTools.SpawnSandbox.include" "$rigWs/.local/agents/spawned/$1/$1.spawn.md" 2>&1
}
rigAsked(){ ## pending id, header -- its value, from the live store or the one a close moved it to
	if [ -f "$rigPend/$1.md" ] ; then rigHeader "$rigPend/$1.md" "$2" ; else rigHeader "$rigPend/closed/$1.md" "$2" ; fi
}
rigHeader(){ ## record file, header -- its value in the frontmatter, empty where absent
	[ -f "$1" ] || return 0
	LC_ALL=C awk -v want="$2" '$0 == "---" { if ( ++dashes > 1 ) exit ; next ; } dashes == 1 && index( $0, want ": " ) == 1 { print substr( $0, length( want ) + 3 ) ; exit ; }' "$1" 2> /dev/null
}
rigBlockLine(){ ## block heading under `# Reasons` -- the one line of its code fence in the note template
	LC_ALL=C awk -v head="## $1" '$0 == head { on = 1 ; next } on && /^```/ { fence = ! fence ; next } on && fence && NF { print ; exit }' "$rigPackage/sh-lib/templates/$rigNote" 2> /dev/null
}
rigPosts(){ ## the posts made so far
	LC_ALL=C grep -c 'chat.postMessage' "$rigTmp/curl.log" 2> /dev/null || printf '0'
}
rigSaid(){ ## text -- how many posts carry it, over the whole run of this check
	LC_ALL=C grep -l -F -- "$2" "$rigTmp"/post.* 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' '
}

echo "-- 1. an answer already standing in the thread is not withdrawn --"
rigRun rig-run-answer
rigAsk rig-asked-answer 1700000000.000101 rig-run-answer
## The thread the close reads: the run's question, and the owner's answer under it.
printf '{"ok":true,"messages":[{"ts":"1700000000.000101","user":"URIGSELF1","text":"Q"},{"ts":"1700000000.000200","user":"URIGOWNER","text":"yes, keep it","thread_ts":"1700000000.000101"}],"has_more":false}\n' > "$rigTmp/replies.json"
: > "$rigTmp/curl.log" ; rm -f "$rigTmp"/posts "$rigTmp"/post.*
rigOut="$( rigClose rig-run-answer )"
rigAssert "control: the run's record is closed" "$( rigHeader "$rigWs/.local/agents/spawned/rig-run-answer/rig-run-answer.spawn.md" status )" "spawn-succeeded"
rigAssert "the question is not withdrawn: it closed as answered, with the answer that stood in its thread" \
	"$( rigAsked rig-asked-answer status ) [$( rigAsked rig-asked-answer verdict )] [$( rigAsked rig-asked-answer withdraw-reason )]" \
	"reply-received [yes, keep it] []"
rigAssert "nobody is told an answer is not needed: no post carries the withdraw reason of the template" \
	"$( rigSaid -F "$( rigBlockLine asker-ended )" )" "0"
rigAssert "the answer reaches the duty: the note of an answer that arrived after the session ended, in the asker's inbox, holding the answer" \
	"$( LC_ALL=C grep -l -F 'an answer arrived after your session ended' "$rigData/inboxes/rig-member/incoming"/*.md 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ):$( LC_ALL=C grep -h -F 'yes, keep it' "$rigData/inboxes/rig-member/incoming"/*.md 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" \
	"1:1"

echo "-- 2. control: with no reply the question is withdrawn as it always was --"
rigRun rig-run-quiet
rigAsk rig-asked-quiet 1700000000.000301 rig-run-quiet
## Its own thread, so the answer kept for the first one is never read here: a read of a thread
## is served from the comms cache of that thread, and this one has none.
printf '{"ok":true,"messages":[{"ts":"1700000000.000301","user":"URIGSELF1","text":"Q"}],"has_more":false}\n' > "$rigTmp/replies.json"
: > "$rigTmp/curl.log" ; rm -f "$rigTmp"/posts "$rigTmp"/post.*
rigOut2="$( rigClose rig-run-quiet )"
rigAssert "the run's record is closed" "$( rigHeader "$rigWs/.local/agents/spawned/rig-run-quiet/rig-run-quiet.spawn.md" status )" "spawn-succeeded"
rigAssert "the unanswered question is withdrawn, with the reason of the note template" \
	"$( rigAsked rig-asked-quiet status ) [$( rigAsked rig-asked-quiet withdraw-reason )]" \
	"withdrawn [$( rigBlockLine asker-ended )]"
rigAssert "and the person is told once" "$( rigSaid -F "$( rigBlockLine asker-ended )" )" "1"

echo "-- 3. a typed question keeps its answer too: a decision, whose answer the escalation read applies --"
rigRun rig-run-typed
rigAsk rig-asked-typed 1700000000.000401 rig-run-typed decision
## Its own thread again, and the owner's answer under the question.
printf '{"ok":true,"messages":[{"ts":"1700000000.000401","user":"URIGSELF1","text":"Q"},{"ts":"1700000000.000500","user":"URIGOWNER","text":"yes","thread_ts":"1700000000.000401"}],"has_more":false}\n' > "$rigTmp/replies.json"
: > "$rigTmp/curl.log" ; rm -f "$rigTmp"/posts "$rigTmp"/post.*
rigOut3="$( rigClose rig-run-typed )"
rigAssert "the run's record is closed" "$( rigHeader "$rigWs/.local/agents/spawned/rig-run-typed/rig-run-typed.spawn.md" status )" "spawn-succeeded"
rigAssert "a typed question is not withdrawn either: it closed with the verdict its thread held" \
	"$( rigAsked rig-asked-typed status ) [$( rigAsked rig-asked-typed verdict )] [$( rigAsked rig-asked-typed withdraw-reason )]" \
	"reply-received [yes] []"
rigAssert "and its answer reaches the duty as the note of an answer that arrived after the session ended" \
	"$( LC_ALL=C grep -l -F 'rig-asked-typed' "$rigData/inboxes/rig-member/incoming"/*.md 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "1"

## One writer of that note, and nowhere else a second copy of its words: the collect arm of the
## pending-reply operations, and the close, both reach the one function.
rigAssert "the note has one writer: one file of the package holds its words" \
	"$( LC_ALL=C grep -l -F 'an answer arrived after your session ended' "$rigPackage"/sh-lib/*/*.include 2> /dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "1"

if [ "$rigFails" -gt 0 ] ; then
	echo "⛔ AGENT SPAWN ANSWER OUTLIVES CHECK FAILED: $rigFails of $(( rigPasses + rigFails )) assertion(s)" >&2
	exit 1
fi
echo "AGENT SPAWN ANSWER OUTLIVES: OK ($rigPasses assertions, offline)"
