#!/usr/bin/env bash
## Behavioural check on AgentsToolsPendingReplyRemindRun, the reminders for asks still
## waiting, as the main loop runs them and as a member's wait does: a stage is due at 30
## minutes and at 2 hours, once each; the daily
## reminder only in the first run after 09:00 local, only for an ask 4+ hours old, and
## once a day; a repeat run sends nothing; 10 due asks to one person are 10 thread
## replies, and 11 are 11 thread replies too, never a top-level message; a record
## with no thread is skipped; a failed send stamps nothing; the identity the ask used is
## the one reminded under; no record is ever closed; and the main loop goes on when the
## reminders fail. Where a reminder goes, by the conversation and the thread of the post
## that is sent: under a question that is a root post, into the thread a question was asked
## in, to a changed question as it stands now, under the forward of an ask that went on to
## the human-owner, under the root of a proposal, and on the client's side for an ask made
## there; each kind of ask under the identity it was asked with. Who drives it: a member's
## wait reminds the ask it waits on and every open ask of its coworking session, at most once
## a minute, never over an answer that has arrived; the wait of a tool that asks does too;
## and the main loop's step and a wait both running send one reminder for a stage.
## Offline: a Slack-shaped fake curl is first on PATH, model CLIs on PATH
## only log, and each scenario has its own workspace under the workspace's .local/temp.
## The local clock is moved with TZ, never by touching the machine.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTool="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigMember="magic-tester"
rigOther="magic-architect"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigTool" ] || rigRefuse "the tool is not at the origin this workspace resolves: $rigTool"
[ -r "${MDAT_SKILLSET_ROOT:-}/$rigMember/$rigMember.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigMember, so the tool would have no identity to read under"
[ -d "${MDAT_SKILLSET_ROOT:-}/$rigOther" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigOther, the second addressee"
## A scan or an iteration of the main loop starts the control thread of a session of its rig that is not finished: what was started is ended before the tree is removed.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsPendingReplyRemindCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwx -- "$rigTmp" 2>/dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/tmp"
cp "$rigTest/check-fixtures/pending-reply-remind-check.curl.stub.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
for rigModel in claude codex ; do
	printf '#!/bin/sh\necho "%s $*" >> "%s/model-calls"\nexit 1\n' "$rigModel" "$rigTmp" > "$rigTmp/bin/$rigModel"
done
chmod +x "$rigTmp/bin/"*
rigSavedPath="$PATH"
PATH="$rigTmp/bin:/usr/bin:/bin"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHolds(){ ## file, fixed string
	LC_ALL=C grep -q -F -- "$2" "$1" 2>/dev/null && printf yes || printf no
}

## A TZ whose local hour is the one asked for, right now: POSIX TZ names the offset west of UTC.
rigTzAt(){ ## local hour wanted
	local tzOff=$(( $1 - 10#$( date -u +%H ) ))
	[ "$tzOff" -le 12 ] || tzOff=$(( tzOff - 24 ))
	[ "$tzOff" -ge -12 ] || tzOff=$(( tzOff + 24 ))
	if [ "$tzOff" -ge 0 ] ; then printf 'RIG-%s\n' "$tzOff" ; else printf 'RIG+%s\n' "$(( - tzOff ))" ; fi
}
rigTz="$( rigTzAt 8 )"

rigScenarioDir=""
rigStart(){ ## scenario directory name
	rigScenarioDir="$rigTmp/$1"
	mkdir -p "$rigScenarioDir/ws/.local/.agents" "$rigScenarioDir/ws/.local/agents/pending" "$rigScenarioDir/data"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_WORKSPACE_DOMAIN=rigspace\n' > "$rigScenarioDir/ws/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-TESTER\n' > "$rigScenarioDir/ws/.local/.agents/$rigMember.agent.env"
	RIG_CURL_LOG="$rigScenarioDir/curl.log"
	export RIG_CURL_LOG
	: > "$RIG_CURL_LOG"
}
rigNow="$( date +%s )"
## One open ask, asked <age> seconds ago, in a thread of its own; extra header lines follow.
rigRecord(){ ## id, age seconds, address-to, extra header lines (each "key: value\n")
	local recordTs="$(( rigNow - $2 )).000100"
	{
		printf -- '---\nstatus: reply-pending\nowner: %s\nhost: rig\n' "$rigMember"
		printf 'communication-channel-id: slack:%s\nblocked-on: reply from %s\nsession-id: rig-sess\nkind: question\n' "$3" "$3"
		printf 'address-to: %s\nchannel: CRIG00001\nquestion-ts: %s\nthread-ts: %s\n' "$3" "$recordTs" "$(( rigNow - $2 - 1 )).000100"
		printf 'addressees: URIGOWNER\nasking-accounts: URIGSELF1\nquestion-tag: Q1\nasked-at: 2026-09-29 12:00 +0300\n'
		printf '%b' "${4:-}"
		printf -- '---\n\n# Question asked\n\n# ❓ Question Q1\n\nMay the rig keep report %s?\nIt is the second line.\n\n**✅ How to answer**\n- reply in this thread\n' "$1"
	} > "$rigScenarioDir/ws/.local/agents/pending/$1.md"
}
rigRemind(){ ## output name [TZ]
	## The reminders are an in-context helper with no operation: run inside the tool's own set-up context.
	printf '%s\n' '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.PendingReplyCollect.include"' \
		'. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/AgentsTools.PendingReplyRemind.include"' \
		'AgentsToolsPendingReplyRemindRun || exit 1' \
	| ( cd "$rigScenarioDir/ws" && env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u ANTHROPIC_API_KEY -u OPENAI_API_KEY \
		TZ="${2:-$rigTz}" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_DATA_ROOT="$rigScenarioDir/data" ${rigEnv[@]+"${rigEnv[@]}"} bash "$rigTool" --intern-mcp-execute ) \
		> "$rigScenarioDir/$1" 2> "$rigScenarioDir/$1.err"
	rigRc=$?
	rigHolds "$rigScenarioDir/$1" 'REMIND: ' | grep -q yes || rigRefuse "the reminder run never finished: $( grep -m1 ERROR "$rigScenarioDir/$1.err" )"
}
rigField(){ ## id, field
	LC_ALL=C awk -v key="$2" 'index($0, key ": ") == 1 { print substr($0, length(key) + 3) ; exit ; }' "$rigScenarioDir/ws/.local/agents/pending/$1.md"
}
rigPosts(){ cat "$rigScenarioDir/posts" 2>/dev/null || printf 0 ; }
rigOpen(){ LC_ALL=C grep -l -x -F 'status: reply-pending' "$rigScenarioDir/ws/.local/agents/pending/"*.md 2>/dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' ; }
rigToday(){ TZ="${1:-$rigTz}" date +%Y-%m-%d ; }

echo "-- stage timing: 29m nothing, 31m the 30-minute reminder, 2h1m the 2-hour one --"
rigStart timing
rigRecord ask-29m $(( 29 * 60 )) human-owner
rigRecord ask-31m $(( 31 * 60 )) human-owner
rigRecord ask-2h1m $(( 121 * 60 )) human-owner 'reminder-30m: 2026-10-07 10:00 +0000\nreminders: 1\nlast-reminder-at: 2026-01-01 10:00 +0000\n'
rigRemind out
rigAssert "the run succeeds"                               "$rigRc" 0
rigAssert "29 minutes: nothing"                            "$( rigHolds "$rigScenarioDir/out" 'REMINDED ask-29m ' )" no
rigAssert "29 minutes: no stamp"                           "$( rigField ask-29m reminders )" ""
rigAssert "31 minutes: reminded in its thread"             "$( rigHolds "$rigScenarioDir/out" 'REMINDED ask-31m human-owner thread reminder=1 stages=30m' )" yes
rigAssert "31 minutes: stamped reminder-30m"               "$( [ -n "$( rigField ask-31m reminder-30m )" ] && printf yes || printf no )" yes
rigAssert "31 minutes: reminders 1"                        "$( rigField ask-31m reminders )" 1
rigAssert "31 minutes: no 2-hour stamp yet"                "$( rigField ask-31m reminder-2h )" ""
rigAssert "2h1m: the 2-hour reminder, number 2"            "$( rigHolds "$rigScenarioDir/out" 'REMINDED ask-2h1m human-owner thread reminder=2 stages=2h' )" yes
rigAssert "2h1m: reminders 2"                              "$( rigField ask-2h1m reminders )" 2
rigAssert "two posts"                                      "$( rigPosts )" 2
rigPostOf31="$( LC_ALL=C grep -l -F "$(( rigNow - 31 * 60 - 1 )).000100" "$rigScenarioDir"/post.[0-9] | head -1 )"
rigAssert "the reminder is a reply in the ask's own thread" "$( [ -n "$rigPostOf31" ] && rigHolds "$rigPostOf31" "\"thread_ts\":\"$(( rigNow - 31 * 60 - 1 )).000100\"" )" yes
## When it was asked is a Slack date token, so each reader sees it in their own timezone: the
## record's `asked-at: 2026-09-29 12:00 +0300` is epoch 1790672400, 09:00 UTC.
rigAssert "it says when it was asked, as a Slack date token with its UTC fallback" \
	"$( rigHolds "$rigPostOf31" 'Still waiting for your answer (asked <!date^1790672400^{date_num} {time}|2026-09-29 09:00 UTC>, reminder 1):' )" yes
rigAssert "the token is unescaped and outside a code span" \
	"$( rigHolds "$rigPostOf31" '&lt;!date' ):$( rigHolds "$rigPostOf31" '`<!date' ):$( LC_ALL=C grep -c -F '"style":{"code":true}' "$rigPostOf31" )" no:no:0
rigAssert "the blocks carry the same moment as a date element" \
	"$( rigHolds "$rigPostOf31" '{"type":"text","text":"⏰ Still waiting for your answer (asked "},{"type":"date","timestamp":1790672400,"format":"{date_num} {time}","fallback":"2026-09-29 09:00 UTC"},{"type":"text","text":", reminder 1):"}' )" yes
rigAssert "no UTC label follows the token, and no local time is said beside it" \
	"$( rigHolds "$rigPostOf31" 'UTC> UTC' ):$( rigHolds "$rigPostOf31" '2026-09-29 12:00' )" no:no
rigAssert "it quotes the question"                         "$( rigHolds "$rigPostOf31" '> May the rig keep report ask-31m?' )" yes
rigAssert "every line of it"                               "$( rigHolds "$rigPostOf31" '> It is the second line.' )" yes
rigAssert "and none of the how-to-answer section"          "$( rigHolds "$rigPostOf31" 'How to answer' )" no
rigAssert "it tags the asked person"                       "$( rigHolds "$rigPostOf31" 'URIGOWNER' )" yes
rigAssert "posted as the ask's owner, member identity"     "$( cat "$rigScenarioDir/post.1.auth" )" rig-user-token-TESTER
echo "-- a repeat run sends nothing --"
rigRemind again
rigAssert "nothing reminded"                               "$( rigHolds "$rigScenarioDir/again" 'REMIND: reminded=0 ' )" yes
rigAssert "still two posts"                                "$( rigPosts )" 2
rigAssert "the counters are unchanged"                     "$( rigField ask-31m reminders ) $( rigField ask-2h1m reminders )" "1 2"
rigAssert "nothing closed"                                 "$( rigOpen )" 3

echo "-- an ask posted under the bot is reminded under the bot --"
rigStart identity
rigRecord ask-bot $(( 31 * 60 )) human-owner 'ask-identity: bot\n'
rigRemind out
rigAssert "reminded"                                       "$( rigHolds "$rigScenarioDir/out" 'REMINDED ask-bot ' )" yes
rigAssert "with the bot token"                             "$( cat "$rigScenarioDir/post.1.auth" 2>/dev/null )" rig-bot-token-TEAM

echo "-- daily: only after 09:00, only 4+ hours old, only once a day --"
rigStart daily
rigStamps='reminder-30m: 2000-01-01 10:00 +0000\nreminder-2h: 2000-01-01 10:00 +0000\nreminders: 2\nlast-reminder-at: 2000-01-01 10:00 +0000\n'
rigRecord ask-5h $(( 5 * 3600 )) human-owner "$rigStamps"
rigRecord ask-3h59m $(( 239 * 60 )) human-owner "$rigStamps"
rigRemind before "$( rigTzAt 8 )"
rigAssert "08:xx: no daily reminder"                       "$( rigHolds "$rigScenarioDir/before" 'REMIND: reminded=0 ' )" yes
rigAssert "08:xx: the day's window is not used up"         "$( [ -f "$rigScenarioDir/ws/.local/agents/pending-remind.daily" ] && printf yes || printf no )" no
rigTz10="$( rigTzAt 10 )"
rigRemind after "$rigTz10"
rigAssert "10:xx: the 5-hour ask gets its daily reminder"  "$( rigHolds "$rigScenarioDir/after" 'REMINDED ask-5h human-owner thread reminder=3 stages=daily' )" yes
rigAssert "stamped with today"                             "$( rigField ask-5h last-daily-reminder )" "$( rigToday "$rigTz10" )"
rigAssert "the 3h59m ask is under the 4-hour threshold"    "$( rigHolds "$rigScenarioDir/after" 'REMINDED ask-3h59m' )" no
rigAssert "the day's window is spent"                      "$( cat "$rigScenarioDir/ws/.local/agents/pending-remind.daily" )" "$( rigToday "$rigTz10" )"
rigRemind again "$rigTz10"
rigAssert "a second run that day sends nothing"            "$( rigHolds "$rigScenarioDir/again" 'REMIND: reminded=0 ' )" yes
## A later run the same day, once the 3h59m ask passes 4 hours: the window is already spent.
sed -i.bak 's/^question-ts: .*/question-ts: '"$(( rigNow - 5 * 3600 ))"'.000100/' "$rigScenarioDir/ws/.local/agents/pending/ask-3h59m.md"
rigRemind later "$rigTz10"
rigAssert "an ask turning 4h old after the window waits for tomorrow" "$( rigHolds "$rigScenarioDir/later" 'REMIND: reminded=0 ' )" yes
## The next day: the window and the ask's own stamps both read yesterday.
printf '2000-01-02\n' > "$rigScenarioDir/ws/.local/agents/pending-remind.daily"
sed -i.bak -e 's/^last-daily-reminder: .*/last-daily-reminder: 2000-01-02/' -e 's/^last-reminder-at: .*/last-reminder-at: 2000-01-02 10:00 +0000/' "$rigScenarioDir/ws/.local/agents/pending/ask-5h.md"
rm -f "$rigScenarioDir/ws/.local/agents/pending/"*.bak
rigRemind nextday "$rigTz10"
rigAssert "next day: the 5-hour ask again"                 "$( rigHolds "$rigScenarioDir/nextday" 'REMINDED ask-5h human-owner thread reminder=4 stages=daily' )" yes
rigAssert "next day: the other one too"                    "$( rigHolds "$rigScenarioDir/nextday" 'REMINDED ask-3h59m human-owner thread reminder=3 stages=daily' )" yes
rigAssert "three posts in all"                             "$( rigPosts )" 3
rigAssert "an ask reminded today by another stage is not reminded daily" "$(
	rigStart daily-same-day
	rigRecord ask-same $(( 5 * 3600 )) human-owner "reminder-30m: x\nreminder-2h: x\nreminders: 2\nlast-reminder-at: $( rigToday "$rigTz10" ) 08:00 +0000\n"
	rigRemind out "$rigTz10"
	rigHolds "$rigScenarioDir/out" 'REMIND: reminded=0 ' )" yes

echo "-- grouping: 10 asks to one person are 10 thread replies --"
rigStart ten
for rigI in 1 2 3 4 5 6 7 8 9 10 ; do rigRecord "ask-$rigI" $(( 31 * 60 + rigI )) human-owner ; done
rigRemind out
rigAssert "ten replies in their threads"                   "$( rigHolds "$rigScenarioDir/out" 'REMIND: reminded=10 threads=10 digests=0 ' )" yes
rigAssert "ten posts"                                      "$( rigPosts )" 10

echo "-- 11 to one person are 11 thread replies, never a top-level digest; another person's too --"
rigStart eleven
for rigI in 1 2 3 4 5 6 7 8 9 10 11 ; do rigRecord "ask-$rigI" $(( 31 * 60 + rigI )) human-owner ; done
rigRecord other-1 $(( 31 * 60 )) "$rigOther"
rigRecord other-2 $(( 31 * 60 )) "$rigOther"
rigRemind out
rigAssert "thirteen thread replies, no digest"             "$( rigHolds "$rigScenarioDir/out" 'REMIND: reminded=13 threads=13 digests=0 ' )" yes
rigAssert "no digest line"                                 "$( rigHolds "$rigScenarioDir/out" 'DIGEST ' )" no
rigAssert "thirteen posts"                                 "$( rigPosts )" 13
rigAssert "every one inside a thread"                      "$( LC_ALL=C grep -l -F '"thread_ts"' "$rigScenarioDir"/post.[0-9]* | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 13
rigAssert "every ask is stamped"                           "$( LC_ALL=C grep -l -x -F 'reminders: 1' "$rigScenarioDir/ws/.local/agents/pending/ask-"*.md | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 11
rigAssert "the other person's asks were replied in thread" "$( rigHolds "$rigScenarioDir/out" "REMINDED other-1 $rigOther thread" )$( rigHolds "$rigScenarioDir/out" "REMINDED other-2 $rigOther thread" )" yesyes
rigRemind again
rigAssert "a repeat sends nothing"                         "$( rigPosts )" 13

echo "-- unresolvable: skipped and logged, nothing sent, nothing changed --"
rigStart unresolvable
rigRecord ask-nothread $(( 31 * 60 )) human-owner
LC_ALL=C sed -i.bak '/^thread-ts: /d' "$rigScenarioDir/ws/.local/agents/pending/ask-nothread.md"
rm -f "$rigScenarioDir/ws/.local/agents/pending/"*.bak
rigBefore="$( cksum < "$rigScenarioDir/ws/.local/agents/pending/ask-nothread.md" )"
rigRemind out
rigAssert "skipped, and said why"                          "$( rigHolds "$rigScenarioDir/out" 'SKIPPED ask-nothread | ' )" yes
rigAssert "nothing posted"                                 "$( rigPosts )" 0
rigAssert "the record is unchanged"                        "$( cksum < "$rigScenarioDir/ws/.local/agents/pending/ask-nothread.md" )" "$rigBefore"

echo "-- a failed send stamps nothing and is due again --"
rigStart failed
rigRecord ask-fail $(( 31 * 60 )) human-owner
: > "$rigScenarioDir/post-refuse"
rigRemind out
rigAssert "the run itself succeeds"                        "$rigRc" 0
rigAssert "the ask is reported failed"                     "$( rigHolds "$rigScenarioDir/out" 'FAILED ask-fail human-owner | ' )" yes
rigAssert "no stamp"                                       "$( rigField ask-fail reminder-30m )" ""
rm -f "$rigScenarioDir/post-refuse"
rigRemind retry
rigAssert "the next run sends it"                          "$( rigHolds "$rigScenarioDir/retry" 'REMINDED ask-fail human-owner thread reminder=1 stages=30m' )" yes
rigAssert "still open"                                     "$( rigField ask-fail status )" reply-pending

echo "-- a closed record is never reminded, and nothing is ever closed or removed --"
rigStart closed
rigRecord ask-done $(( 5 * 3600 )) human-owner
LC_ALL=C sed -i.bak 's/^status: reply-pending$/status: reply-received/' "$rigScenarioDir/ws/.local/agents/pending/ask-done.md"
rm -f "$rigScenarioDir/ws/.local/agents/pending/"*.bak
rigRecord ask-old $(( 30 * 86400 )) human-owner
rigRemind out "$rigTz10"
rigAssert "the closed one is left alone"                   "$( rigHolds "$rigScenarioDir/out" 'ask-done' )" no
rigAssert "a 30-day-old ask is reminded, not expired"      "$( rigHolds "$rigScenarioDir/out" 'REMINDED ask-old human-owner thread reminder=1 stages=30m,2h' )" yes
rigAssert "one reminder for the stages due together"       "$( rigPosts )" 1
rigAssert "it stays open"                                  "$( rigField ask-old status )" reply-pending
rigAssert "both records still there"                       "$( ls "$rigScenarioDir/ws/.local/agents/pending/" | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 2

echo "-- the main loop runs the reminders, and goes on when they fail --"
rigRealTemplate="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/templates/spawn-brief.document.format.md"
[ -f "$rigRealTemplate" ] || rigRefuse "the brief template is not in the package: $rigRealTemplate"
rigLoopScenario(){ ## name
	rigDir="$rigTmp/loop-$1"
	mkdir -p "$rigDir/ws/.local/.agents" "$rigDir/ws/.local/agents/pending" "$rigDir/data" "$rigDir/bin" "$rigDir/home/.claude/skills/magic-coordinator" "$rigDir/home/.claude/skills/magic-team" \
		"$rigDir/home/.claude/skills/$rigMember" "$rigDir/home/.claude/skills/human-owner"
	printf '# magic-coordinator\n' > "$rigDir/home/.claude/skills/magic-coordinator/SKILL.md"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigDir/home/.claude/skills/magic-coordinator/magic-coordinator.basic.md"
	printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigDir/home/.claude/skills/$rigMember/$rigMember.basic.md"
	printf '# rig armed\n' > "$rigDir/home/.claude/skills/magic-coordinator/magic-coordinator.armed.md"
	printf -- '---\nexecutors: magic-coordinator (light)\nmaintainers: rig\n---\n# rig heartbeat routine fixture\n' \
		> "$rigDir/home/.claude/skills/magic-coordinator/magic-coordinator.heartbeat.routine.md"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_BOT_TOKEN=rig-not-a-token\nSPAWN_CLI_SERVICE=rig-cli\nSLACK_WORKSPACE_DOMAIN=rigspace\n' > "$rigDir/ws/.local/.agents/magic-team.agent.env"
	printf 'MAIN_LOOP_RESTART_DELAY_SECONDS=2\n' > "$rigDir/ws/.local/.agents/magic-coordinator.agent.env"
	printf '#!/bin/sh\n## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli)\ncat > /dev/null\necho "start $$" >> "%s/console.log"\n' "$rigDir" > "$rigDir/ws/DistroAgentsConsole.sh"
	printf '#!/bin/sh\ncat > /dev/null\nfor a in "$@" ; do case "$a" in @-) ;; *@/*) cat "/${a#*@/}" >> "%s/posted" ; echo >> "%s/posted" ;; esac ; done\necho "$*" >> "%s/curl.log"\nprintf %s\n' \
		"$rigDir" "$rigDir" "$rigDir" "'{\"ok\":true,\"channel\":\"CRIG00001\",\"ts\":\"1700000001.000100\",\"message\":{\"ts\":\"1700000001.000100\"}}\n'" > "$rigDir/bin/curl"
	chmod +x "$rigDir/ws/DistroAgentsConsole.sh" "$rigDir/bin/curl"
	rigScenarioDir="$rigDir"
}
rigOneRun(){
	env -i HOME="$rigDir/home" PATH="$rigDir/bin:/usr/bin:/bin:/usr/sbin:/sbin" TZ="$rigTz" \
		MMDAPP="$rigDir/ws" MDAT_DATA_ROOT="$rigDir/data" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigDir/home/.claude/skills" \
		RIG_TMP="$rigTmp" RIG_FN="$rigTool" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MMDAPP outside the rig tree: $MMDAPP" >&2 ; exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) echo "RIG-GUARD: MDAT_DATA_ROOT outside the rig tree: $MDAT_DATA_ROOT" >&2 ; exit 99 ;; esac
			! command -v claude > /dev/null 2>&1 || { echo "RIG-GUARD: an agent CLI is on PATH" >&2 ; exit 99 ; }
			cd "$MMDAPP" && exec bash "$RIG_FN" --intern-main-loop --one
		' > "$rigDir/one.out" 2> "$rigDir/one.err"
}
rigLoopScenario ok
rigRecord ask-loop $(( 31 * 60 )) human-owner
rigOneRun
rigAssert "the iteration reminds"                          "$( rigHolds "$rigDir/ws/.local/agents/pending-remind.last" 'REMINDED ask-loop human-owner thread reminder=1 stages=30m' )" yes
rigAssert "and says so in its log"                         "$( rigHolds "$rigDir/one.err" '--intern-main-loop: REMIND: reminded=1 ' )" yes
rigAssert "the reminder was posted"                        "$( rigHolds "$rigDir/posted" 'Still waiting for your answer' )" yes
rigAssert "the pass still runs"                            "$( [ "$( LC_ALL=C grep -c '^start ' "$rigDir/console.log" 2>/dev/null )" -ge 1 ] && printf yes || printf no )" yes
rigLoopScenario failing
rigRecord ask-loop $(( 31 * 60 )) human-owner
chmod 000 "$rigDir/ws/.local/agents/pending"
rigOneRun
chmod 755 "$rigDir/ws/.local/agents/pending"
rigAssert "a failed reminder run is logged"                "$( rigHolds "$rigDir/one.err" '--intern-main-loop: the pending-reply reminders could not run' )" yes
rigAssert "and the iteration goes on to its pass"          "$( [ "$( LC_ALL=C grep -c '^start ' "$rigDir/console.log" 2>/dev/null )" -ge 1 ] && printf yes || printf no )" yes
rigAssert "nothing was posted"                             "$( rigHolds "$rigDir/posted" 'Still waiting' )" no

## ---- where a reminder goes, and who drives it ----
rigHarness="$rigHere/AgentsUniversalHarness.sh"
[ -f "$rigHarness" ] || rigRefuse "the harness is not at: $rigHarness"
rigEnv=()
## The ts of a message posted <age> seconds ago, and of the thread it was posted into.
rigTsOf(){ printf '%s.000100' "$(( rigNow - $1 ))" ; }
## One open ask written whole: for the shapes rigRecord does not make.
rigRecordRaw(){ ## id, header lines (each "key: value\n"), body
	printf -- '---\nstatus: reply-pending\nhost: rig\n%b---\n\n# Question asked\n\n%b' "$2" "$3" > "$rigScenarioDir/ws/.local/agents/pending/$1.md"
}
rigPostChannel(){ ## post number -- the conversation that post went to
	LC_ALL=C sed -n 's/^{"channel":"\([^"]*\)".*/\1/p' "$rigScenarioDir/post.$1" 2>/dev/null | head -1
}
rigPostThread(){ ## post number -- the thread that post is a reply in, or nothing for a top-level message
	LC_ALL=C sed -n 's/.*"thread_ts":"\([0-9.]*\)".*/\1/p' "$rigScenarioDir/post.$1" 2>/dev/null | head -1
}
rigPostAuth(){ cat "$rigScenarioDir/post.$1.auth" 2>/dev/null ; }
rigTries(){ LC_ALL=C grep -c . "$rigScenarioDir/post-tries" 2>/dev/null || : ; }
rigReads(){ ## token (empty: any) -- how many thread reads were made, under that token
	LC_ALL=C grep -c -e "^conversations.replies ${1:-}" "$rigScenarioDir/calls" 2>/dev/null || :
}
## A member's wait, as the Wait tool and the tools that ask run it. It reminds, as a wait does
## anywhere but in a test: the runner's MDAT_WAIT_REMIND=off is taken out of its environment.
rigWait(){ ## output name, TZ (empty: the rig's), wait arguments...
	local waitOut="$1" waitTz="${2:-$rigTz}"
	shift 2
	( cd "$rigScenarioDir/ws" && env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u ANTHROPIC_API_KEY -u OPENAI_API_KEY -u MDAT_WAIT_REMIND \
		TZ="$waitTz" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_DATA_ROOT="$rigScenarioDir/data" ${rigEnv[@]+"${rigEnv[@]}"} bash "$rigTool" --member-wait-for-input "$rigMember" "$@" ) \
		> "$rigScenarioDir/$waitOut" 2> "$rigScenarioDir/$waitOut.err"
	rigRc=$?
}
## The thread of one ask as Slack returns it: its first message, then the question asked in it.
rigThreadOf(){ ## id
	local threadTs threadQts
	threadTs="$( rigField "$1" thread-ts )" ; threadQts="$( rigField "$1" question-ts )"
	[ "$threadTs" != "$threadQts" ] || return 0
	printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGSELF1","text":"root"},{"ts":"%s","user":"URIGSELF1","thread_ts":"%s","text":"question"}],"has_more":false}\n' \
		"$threadTs" "$threadQts" "$threadTs" > "$rigScenarioDir/replies.$threadTs.json"
}
## A spawn record: that session took part in that coworking session.
rigSpawn(){ ## coworking session id, spawn id, owner
	mkdir -p "$rigScenarioDir/ws/.local/agents/spawned/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nowner: %s\nstatus: spawn-succeeded\n---\n' "$1" "$2" "$3" > "$rigScenarioDir/ws/.local/agents/spawned/$1/$2.md"
}

echo "-- the thread: a question that is a root post is reminded under that post --"
rigStart thread-root
rigRootTs="$( rigTsOf $(( 31 * 60 )) )"
rigRecordRaw ask-root "owner: $rigMember\nkind: question\naddress-to: human-owner\nchannel: CRIGROOT1\nquestion-ts: $rigRootTs\nthread-ts: $rigRootTs\naddressees: URIGOWNER\nasked-at: 2026-09-29 12:00 +0300\n" \
	'# ❓ Question\n\nMay the rig keep the root?\n\n**✅ How to answer**\n- reply in this thread\n'
rigRemind out
rigAssert "reminded"                                       "$( rigHolds "$rigScenarioDir/out" 'REMINDED ask-root human-owner thread reminder=1 stages=30m' )" yes
rigAssert "in the conversation of the question"            "$( rigPostChannel 1 )" CRIGROOT1
rigAssert "as a reply under the question itself"           "$( rigPostThread 1 )" "$rigRootTs"

echo "-- the thread: a question asked inside a thread is reminded in that same thread --"
rigStart thread-inside
rigRecord ask-inside $(( 31 * 60 )) human-owner
rigRemind out
rigAssert "in the conversation of the question"            "$( rigPostChannel 1 )" CRIG00001
rigAssert "in the thread it was asked in, never under the question as a thread of its own" "$( rigPostThread 1 )" "$( rigTsOf $(( 31 * 60 + 1 )) )"

echo "-- the thread: a question asked again, changed, is reminded as it stands now --"
rigStart thread-revised
## Its own thread: the first post stays the root, the changed question is a reply under it.
rigRecordRaw ask-revised-own "owner: $rigMember\nkind: decision\naddress-to: human-owner\nchannel: CRIG00001\nquestion-ts: $rigRootTs\nthread-ts: $rigRootTs\nrevision-ts: $( rigTsOf 600 )\nrevisions: 2\naddressees: URIGOWNER\nasked-at: 2026-09-29 12:00 +0300\n" \
	'# 🧭 Decision\n\nWhich colour, as first asked?\n\n**✅ How to answer**\n- reply\n\n## Revision 1\n\n# 🧭 Decision ✏️ updated\n\nWhich colour, as asked the second time?\n\n**✅ How to answer**\n- reply\n\n## Revision 2\n\n# 🧭 Decision ✏️ updated\n\nWhich colour, as it stands now?\nIts second line.\n\n**✅ How to answer**\n- reply\n'
## Inside another thread: the version before it stays there, marked, and the changed one is a later reply.
rigInsideThread="$( rigTsOf $(( 2 * 3600 )) )"
rigRecordRaw ask-revised-inside "owner: $rigMember\nkind: question\naddress-to: human-owner\nchannel: CRIG00001\nquestion-ts: $( rigTsOf $(( 33 * 60 )) )\nthread-ts: $rigInsideThread\nrevision-ts: $( rigTsOf 300 )\nrevisions: 1\nsuperseded: $( rigTsOf $(( 33 * 60 )) )\naddressees: URIGOWNER\nquestion-tag: Q4\nasked-at: 2026-09-29 12:00 +0300\n" \
	'# ❓ Question Q4\n\nMay the rig go, as first asked?\n\n**✅ How to answer**\n- reply\n\n## Revision 1\n\n# ❓ Question Q4 ✏️ updated\n\nMay the rig go, as it stands now?\n\n**✅ How to answer**\n- reply\n'
rigRemind out
rigAssert "both are reminded"                              "$( rigHolds "$rigScenarioDir/out" 'REMIND: reminded=2 ' )" yes
rigPostOwn="$( LC_ALL=C grep -l -F 'Which colour' "$rigScenarioDir"/post.[0-9] | head -1 )"
rigPostInside="$( LC_ALL=C grep -l -F 'May the rig go' "$rigScenarioDir"/post.[0-9] | head -1 )"
rigAssert "its own thread: a reply under its root"         "$( rigPostThread "${rigPostOwn##*.}" )" "$rigRootTs"
rigAssert "its own thread: the question as it stands now"  "$( rigHolds "$rigPostOwn" '> Which colour, as it stands now?' )$( rigHolds "$rigPostOwn" '> Its second line.' )" yesyes
rigAssert "its own thread: no version before it"           "$( rigHolds "$rigPostOwn" 'as first asked' )$( rigHolds "$rigPostOwn" 'the second time' )" nono
rigAssert "inside a thread: in that thread"                "$( rigPostThread "${rigPostInside##*.}" )" "$rigInsideThread"
rigAssert "inside a thread: never under the version that was marked" "$( [ "$( rigPostThread "${rigPostInside##*.}" )" != "$( rigTsOf $(( 33 * 60 )) )" ] && printf yes || printf no )" yes
rigAssert "inside a thread: the question as it stands now" "$( rigHolds "$rigPostInside" '> May the rig go, as it stands now?' )$( rigHolds "$rigPostInside" 'as first asked' )" yesno

echo "-- the thread: a question returned and asked again is reminded once, as the one that is open --"
rigStart thread-again
rigRecord ask-before $(( 3 * 3600 )) human-owner
LC_ALL=C sed -i.bak 's/^status: reply-pending$/status: reply-received/' "$rigScenarioDir/ws/.local/agents/pending/ask-before.md"
rm -f "$rigScenarioDir/ws/.local/agents/pending/"*.bak
rigAgainThread="$( rigField ask-before thread-ts )"
rigRecordRaw ask-again "owner: $rigMember\nkind: question\naddress-to: human-owner\nchannel: CRIG00001\nquestion-ts: $( rigTsOf $(( 31 * 60 )) )\nthread-ts: $rigAgainThread\naddressees: URIGOWNER\nquestion-tag: Q1\nasked-at: 2026-09-29 12:00 +0300\n" \
	'# ❓ Question Q1\n\nMay the rig keep the report, asked again?\n\n**✅ How to answer**\n- reply\n'
rigRemind out
rigAssert "one reminder, for the open one"                 "$( rigPosts ):$( rigHolds "$rigScenarioDir/out" 'REMINDED ask-again ' ):$( rigHolds "$rigScenarioDir/out" 'ask-before' )" 1:yes:no
rigAssert "in the thread the question has had all along"   "$( rigPostThread 1 )" "$rigAgainThread"

echo "-- the thread: an ask that went on to the human-owner is reminded where he has it --"
rigStart thread-forward
printf 'SLACK_USER_TOKEN=rig-user-token-ARCH\n' > "$rigScenarioDir/ws/.local/.agents/$rigOther.agent.env"
rigFwdTs="$( rigTsOf $(( 40 * 60 )) )"
## Asked of a member in that member's conversation, then sent up: the forward is the team bot's post to the owner.
rigRecordRaw ask-sent-up "owner: $rigMember\nkind: permission\naddress-to: human-owner\nchannel: DRIGFIRST\nquestion-ts: $( rigTsOf $(( 50 * 60 )) )\nthread-ts: $( rigTsOf $(( 50 * 60 )) )\naddressees: URIGCOORD\nask-identity: member\nasked-at: 2026-09-29 12:00 +0300\nforward-channel: DRIGBOTDM\nforward-ts: $rigFwdTs\nforward-addressees: URIGOWNER\nforwarded-by: $rigOther\nrerouted-from: $rigOther\n" \
	'# 🔐 Permission\n\nMay the rig read the far tree?\n\n**✅ How to answer**\n- reply `deny`\n'
rigRemind out
rigAssert "reminded, addressed to the human-owner"         "$( rigHolds "$rigScenarioDir/out" 'REMINDED ask-sent-up human-owner thread reminder=1 stages=30m' )" yes
rigAssert "one post, and not in the first conversation"    "$( rigPosts ):$( LC_ALL=C grep -l -F '"channel":"DRIGFIRST"' "$rigScenarioDir"/post.[0-9] 2>/dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 1:0
rigAssert "in the conversation of the forward"             "$( rigPostChannel 1 )" DRIGBOTDM
rigAssert "as a reply under the forward"                   "$( rigPostThread 1 )" "$rigFwdTs"
rigAssert "as the team bot, the identity the forward was posted with" "$( rigPostAuth 1 )" rig-bot-token-TEAM
rigAssert "it tags the owner"                              "$( rigHolds "$rigScenarioDir/post.1" 'URIGOWNER' )" yes
rigAssert "it says when he was asked: the forward, not the first post" "$( rigHolds "$rigScenarioDir/post.1" "(asked <!date^$(( rigNow - 40 * 60 ))^" )" yes
rigAssert "the record is stamped"                          "$( rigField ask-sent-up reminders )" 1
## He was asked when it was forwarded: 30 minutes are counted from there.
rigStart thread-forward-young
rigRecordRaw ask-just-sent-up "owner: $rigMember\nkind: permission\naddress-to: human-owner\nchannel: DRIGFIRST\nquestion-ts: $( rigTsOf $(( 50 * 60 )) )\nthread-ts: $( rigTsOf $(( 50 * 60 )) )\naddressees: URIGCOORD\nask-identity: member\nasked-at: 2026-09-29 12:00 +0300\nforward-channel: DRIGBOTDM\nforward-ts: $( rigTsOf $(( 10 * 60 )) )\nforward-addressees: URIGOWNER\nforwarded-by: $rigOther\nrerouted-from: $rigOther\n" \
	'# 🔐 Permission\n\nMay the rig read the near tree?\n'
rigRemind out
rigAssert "asked 50 minutes ago, forwarded 10 minutes ago: not reminded yet" "$( rigHolds "$rigScenarioDir/out" 'REMIND: reminded=0 ' ):$( rigPosts )" yes:0
## Forwarded by the one it is addressed to, who stays its addressee on the record: the owner has the forward.
rigStart thread-forward-plain
printf 'SLACK_USER_TOKEN=rig-user-token-ARCH\n' > "$rigScenarioDir/ws/.local/.agents/$rigOther.agent.env"
rigRecordRaw ask-forwarded "owner: $rigMember\nkind: decision\naddress-to: $rigOther\nchannel: DRIGFIRST\nquestion-ts: $( rigTsOf $(( 50 * 60 )) )\nthread-ts: $( rigTsOf $(( 50 * 60 )) )\naddressees: URIGARCH\nasked-at: 2026-09-29 12:00 +0300\nforward-channel: DRIGBOTDM\nforward-ts: $rigFwdTs\nforward-addressees: URIGOWNER\nforwarded-by: $rigOther\n" \
	'# 🧭 Decision\n\nWhich way for the rig?\n\n**✅ How to answer**\n- reply\n'
## And one asked of a routine, which has no thread of its own: its forward is the only post there is.
rigRecordRaw ask-routine "owner: $rigMember\nkind: permission\naddress-to: rig.routine\nasked-at: 2026-09-29 12:00 +0300\nquestion-ts: $( rigTsOf $(( 50 * 60 )) )\nforward-channel: DRIGBOTDM\nforward-ts: $( rigTsOf $(( 41 * 60 )) )\nforward-addressees: URIGOWNER\nforwarded-by: $rigOther\n" \
	'# 🔐 Permission\n\nMay the routine rig go?\n'
rigRemind out
rigAssert "both reminded, each to the human-owner"         "$( rigHolds "$rigScenarioDir/out" 'REMINDED ask-forwarded human-owner thread ' )$( rigHolds "$rigScenarioDir/out" 'REMINDED ask-routine human-owner thread ' )" yesyes
rigAssert "each under its own forward"                     "$( printf '%s\n' "$( rigPostThread 1 )" "$( rigPostThread 2 )" | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" "$( printf '%s\n%s\n' "$rigFwdTs" "$( rigTsOf $(( 41 * 60 )) )" | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )"
rigAssert "each in the conversation of the forward, as the team bot" "$( rigPostChannel 1 ) $( rigPostChannel 2 ) $( rigPostAuth 1 ) $( rigPostAuth 2 )" "DRIGBOTDM DRIGBOTDM rig-bot-token-TEAM rig-bot-token-TEAM"

echo "-- never over an answer: a reply or a click nobody has taken yet sends no reminder --"
rigStart held
rigHeldTs(){ rigTsOf $(( 31 * 60 + $1 )) ; }
rigRecordRaw ask-replied "owner: $rigMember\nkind: question\naddress-to: human-owner\nchannel: CRIG00001\nquestion-ts: $( rigHeldTs 1 )\nthread-ts: $( rigHeldTs 1 )\naddressees: URIGOWNER\nasking-accounts: URIGSELF1\nasked-at: 2026-09-29 12:00 +0300\n" \
	'# ❓ Question\n\nMay the rig keep the one he answered?\n\n**✅ How to answer**\n- reply\n'
printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGSELF1","text":"question"},{"ts":"%s","user":"URIGOWNER","thread_ts":"%s","text":"yes, keep it"}],"has_more":false}\n' \
	"$( rigHeldTs 1 )" "$( rigTsOf 600 )" "$( rigHeldTs 1 )" > "$rigScenarioDir/replies.$( rigHeldTs 1 ).json"
## A click of his under the post, beside the answer emoji the tooling placed there itself.
rigRecordRaw ask-clicked "owner: $rigMember\nkind: permission\naddress-to: human-owner\nchannel: DRIGBOTDM\nquestion-ts: $( rigHeldTs 2 )\nthread-ts: $( rigHeldTs 2 )\naddressees: URIGOWNER\nasking-accounts: URIGSELF1\nask-identity: bot\nasked-at: 2026-09-29 12:00 +0300\n" \
	'# 🔐 Permission\n\nMay the rig read the one he clicked?\n\n**✅ How to answer**\n- click\n'
printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGSELF1","text":"question","reactions":[{"name":"x","count":1,"users":["URIGSELF1"]},{"name":"one","count":1,"users":["URIGSELF1"]},{"name":"repeat","count":2,"users":["URIGSELF1","URIGOWNER"]}]}],"has_more":false}\n' \
	"$( rigHeldTs 2 )" > "$rigScenarioDir/replies.$( rigHeldTs 2 ).json"
## Only the tooling's own emoji under it, and a reply of somebody who was not asked: nobody answered.
rigRecordRaw ask-quiet "owner: $rigMember\nkind: permission\naddress-to: human-owner\nchannel: DRIGBOTDM\nquestion-ts: $( rigHeldTs 3 )\nthread-ts: $( rigHeldTs 3 )\naddressees: URIGOWNER\nasking-accounts: URIGSELF1\nask-identity: bot\nasked-at: 2026-09-29 12:00 +0300\n" \
	'# 🔐 Permission\n\nMay the rig read the one nobody answered?\n\n**✅ How to answer**\n- click\n'
printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGSELF1","text":"question","reactions":[{"name":"x","count":1,"users":["URIGSELF1"]},{"name":"repeat","count":1,"users":["URIGSELF1"]}]},{"ts":"%s","user":"URIGELSE1","thread_ts":"%s","text":"not mine to answer"}],"has_more":false}\n' \
	"$( rigHeldTs 3 )" "$( rigTsOf 500 )" "$( rigHeldTs 3 )" > "$rigScenarioDir/replies.$( rigHeldTs 3 ).json"
## The owner answered in the forward's thread, and the question's first thread holds nothing: the case seen live.
rigRecordRaw ask-answered-up "owner: $rigMember\nkind: permission\naddress-to: human-owner\nchannel: DRIGFIRST\nquestion-ts: $( rigTsOf $(( 50 * 60 )) )\nthread-ts: $( rigTsOf $(( 50 * 60 )) )\naddressees: URIGCOORD\nask-identity: member\nasked-at: 2026-09-29 12:00 +0300\nforward-channel: DRIGBOTDM\nforward-ts: $( rigHeldTs 4 )\nforward-addressees: URIGOWNER\nforwarded-by: $rigOther\nrerouted-from: $rigOther\n" \
	'# 🔐 Permission\n\nMay the rig read the one he answered above?\n'
printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGBOT01","text":"forward"},{"ts":"%s","user":"URIGOWNER","thread_ts":"%s","text":"allow-session"}],"has_more":false}\n' \
	"$( rigHeldTs 4 )" "$( rigTsOf 400 )" "$( rigHeldTs 4 )" > "$rigScenarioDir/replies.$( rigHeldTs 4 ).json"
## One that went up to a member with no forward: the reply in its thread is the first addressee's, not applied.
rigRecordRaw ask-went-up "owner: $rigMember\nkind: permission\naddress-to: $rigOther\nchannel: CRIG00001\nquestion-ts: $( rigHeldTs 5 )\nthread-ts: $( rigHeldTs 5 )\naddressees: URIGCOORD\nasking-accounts: URIGSELF1\nasked-at: 2026-09-29 12:00 +0300\nrerouted-from: magic-coordinator\n" \
	'# 🔐 Permission\n\nMay the rig read the one that went up?\n'
printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGSELF1","text":"question"},{"ts":"%s","user":"URIGCOORD","thread_ts":"%s","text":"allow-session"}],"has_more":false}\n' \
	"$( rigHeldTs 5 )" "$( rigTsOf 450 )" "$( rigHeldTs 5 )" > "$rigScenarioDir/replies.$( rigHeldTs 5 ).json"
rigRemind out
rigAssert "one that went up to a member is reminded in its thread, to who has it now, whatever the first addressee wrote there" \
	"$( rigHolds "$rigScenarioDir/out" "REMINDED ask-went-up $rigOther thread reminder=1 stages=30m" ):$( LC_ALL=C grep -l -F "\"thread_ts\":\"$( rigHeldTs 5 )\"" "$rigScenarioDir"/post.[0-9] 2>/dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" yes:1
rigAssert "the reply holds its reminder back"              "$( rigHolds "$rigScenarioDir/out" "HELD ask-replied human-owner | a reply or a click of its addressee stands in CRIG00001:$( rigHeldTs 1 ) " )" yes
rigAssert "the click does"                                 "$( rigHolds "$rigScenarioDir/out" "HELD ask-clicked human-owner | a reply or a click of its addressee stands in DRIGBOTDM:$( rigHeldTs 2 ) " )" yes
rigAssert "the answer in the forward's thread does"        "$( rigHolds "$rigScenarioDir/out" "HELD ask-answered-up human-owner | a reply or a click of its addressee stands in DRIGBOTDM:$( rigHeldTs 4 ) " )" yes
rigAssert "the one nobody answered is reminded"            "$( rigHolds "$rigScenarioDir/out" 'REMINDED ask-quiet human-owner thread reminder=1 stages=30m' ):$( rigPosts ):$( LC_ALL=C grep -l -F "\"thread_ts\":\"$( rigHeldTs 3 )\"" "$rigScenarioDir"/post.[0-9] 2>/dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" "yes:2:1"
rigAssert "the summary counts them"                        "$( rigHolds "$rigScenarioDir/out" 'REMIND: reminded=2 threads=2 digests=0 skipped=0 failed=0 held=3' )" yes
rigAssert "a stage held back is passed, and counts as no reminder" \
	"$( [ -n "$( rigField ask-replied reminder-30m )" ] && printf passed ):$( rigField ask-replied reminders ):$( rigField ask-replied last-reminder-at ):$( [ -n "$( rigField ask-replied last-reminder-held )" ] && printf held )" "passed:::held"
rigAssert "the forward's thread was read as the team bot"  "$( [ "$( rigReads rig-bot-token-TEAM )" -ge 3 ] && printf yes || printf no )" yes
rigHeldReads="$( rigReads )"
rigRemind again
rigAssert "a repeat run sends nothing, and reads no thread again" "$( rigHolds "$rigScenarioDir/again" 'REMIND: reminded=0 threads=0 digests=0 skipped=0 failed=0 held=0' ):$( rigPosts ):$( rigReads )" "yes:2:$rigHeldReads"

echo "-- the kinds: a permission and a question of the bot's, a permission set, a review prompt, a proposal --"
rigStart kinds
rigKindTs(){ rigTsOf $(( 31 * 60 + $1 )) ; }
rigRecordRaw kind-permission "owner: $rigMember\nkind: permission\naddress-to: human-owner\nchannel: DRIGBOTDM\nquestion-ts: $( rigKindTs 1 )\nthread-ts: $( rigKindTs 1 )\naddressees: URIGOWNER\nask-identity: bot\nasked-at: 2026-09-29 12:00 +0300\n" \
	'# 🔐 Permission\n\nMay the rig read one file?\n\n**🚫 Refused call**\n- tool: Read\n'
rigRecordRaw kind-question "owner: $rigMember\nkind: question\naddress-to: human-owner\nchannel: DRIGBOTDM\nquestion-ts: $( rigKindTs 2 )\nthread-ts: $( rigKindTs 2 )\naddressees: URIGOWNER\nask-identity: bot\nasked-at: 2026-09-29 12:00 +0300\n" \
	'# ❓ Question\n\nIs the rig asked by the bot?\n\n**✅ How to answer**\n- reply\n'
rigRecordRaw kind-set "owner: $rigMember\nkind: permission-set\naddress-to: human-owner\nchannel: DRIGBOTDM\nquestion-ts: $( rigKindTs 3 )\nthread-ts: $( rigKindTs 3 )\naddressees: URIGOWNER\nask-identity: bot\nasked-at: 2026-09-29 12:00 +0300\n" \
	'# 🔐 Permission set\n\nMay the participants have these, for this session only?\n\n**🔑 Asked for**\n- `rig:tree` — Read\n'
rigRecordRaw kind-review "owner: $rigMember\nkind: review\naddress-to: human-owner\nchannel: DRIGBOTDM\nquestion-ts: $( rigKindTs 4 )\nthread-ts: $( rigKindTs 4 )\naddressees: URIGOWNER\nask-identity: bot\nitem: rig-item\nasked-at: 2026-09-29 12:00 +0300\n" \
	"# 🔎 Review\n\n$rigMember handed back, and its work waits for your verdict.\n\n**🗂 Task**\nrig task\n"
## A proposal: its root is the question, the proposal is the reply under it (its live version).
rigRecordRaw kind-proposal "owner: $rigMember\nkind: proposal\naddress-to: human-owner\nchannel: DRIGOWNER\nquestion-ts: $( rigKindTs 5 )\nthread-ts: $( rigKindTs 5 )\nrevision-ts: $( rigKindTs 0 )\naddressees: URIGOWNER\nask-identity: member\nasked-at: 2026-09-29 12:00 +0300\n" \
	'# 📜 Proposal\n\nShall the rig take the new form?\n\n# 📘 The proposal\n\nThe rig takes the new form.\n\n**🔗 Document**\nhttps://rig.invalid/doc\n'
rigRemind out
rigAssert "all five are reminded"                          "$( rigHolds "$rigScenarioDir/out" 'REMIND: reminded=5 threads=5 digests=0 skipped=0 failed=0' )" yes
for rigKind in permission question set review proposal ; do
	rigKindPost="$( LC_ALL=C grep -l -F "\"thread_ts\":\"$( LC_ALL=C sed -n 's/^thread-ts: //p' "$rigScenarioDir/ws/.local/agents/pending/kind-$rigKind.md" )\"" "$rigScenarioDir"/post.[0-9] 2>/dev/null | head -1 )"
	rigKindWant="DRIGBOTDM rig-bot-token-TEAM"
	[ "$rigKind" != proposal ] || rigKindWant="DRIGOWNER rig-user-token-TESTER"
	rigAssert "$rigKind: one reply under its own post, in its conversation, under the identity it was asked with" \
		"$( [ -n "$rigKindPost" ] && printf '%s %s' "$( rigPostChannel "${rigKindPost##*.}" )" "$( rigPostAuth "${rigKindPost##*.}" )" )" "$rigKindWant"
done
rigAssert "the review prompt is quoted by what it says"    "$( LC_ALL=C grep -l -F "> $rigMember handed back, and its work waits for your verdict." "$rigScenarioDir"/post.[0-9] | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 1
rigAssert "the permission set by its question"             "$( LC_ALL=C grep -l -F '> May the participants have these, for this session only?' "$rigScenarioDir"/post.[0-9] | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 1
rigAssert "the proposal by its question, under its root"   "$( LC_ALL=C grep -l -F '> Shall the rig take the new form?' "$rigScenarioDir"/post.[0-9] | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 1
rigAssert "nothing is reacted on: a proposal root takes no tooling emoji" "$( LC_ALL=C grep -c '^reactions\.' "$RIG_CURL_LOG" || : )" 0
rigAssert "and nothing is a top-level message"             "$( LC_ALL=C grep -L -F '"thread_ts"' "$rigScenarioDir"/post.[0-9] | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 0

echo "-- the other side: an ask on a client's side is reminded on that side, in its thread --"
rigStart client-side
mkdir -p "$rigScenarioDir/skills/magic-team" "$rigScenarioDir/skills/human-owner" "$rigScenarioDir/skills/client-rig" "$rigScenarioDir/data/inboxes/client-rig"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigScenarioDir/skills/client-rig/client-rig.basic.md"
printf '# rig armed\n' > "$rigScenarioDir/skills/client-rig/client-rig.armed.md"
printf -- '---\nname: client-rig\n---\n\n# client-rig\n' > "$rigScenarioDir/skills/client-rig/SKILL.md"
printf 'SLACK_USER_TOKEN=rig-user-token-CLIENT\nSLACK_WORKSPACE_DOMAIN=client.slack.invalid\nSLACK_CONVERSATIONS=CRIGCLNT1\n' > "$rigScenarioDir/ws/.local/.agents/client-rig.agent.env"
printf '%s\n' 'client-rig 🔧 Rig Client rigclient' > "$rigScenarioDir/ws/.local/agents/team-members-names.registry"
printf '%s\n' '| slack-id | contact | handle | email | organisation | permission level |' '| --- | --- | --- | --- | --- | --- |' \
	'| CRIGCLNT1 | rig-client-team | @rig-client-team | <unresolved> | rig | unset |' \
	'| URIGTHEIR | rig-client-person | @rig-client-person | <unresolved> | rig | unset |' \
	'| DRIGTHEIR | rig-client-person-dm | @rig-client-person | <unresolved> | rig | unset |' > "$rigScenarioDir/data/inboxes/client-rig/note-rig-contacts.md"
rigClientTs="$( rigTsOf $(( 31 * 60 )) )"
rigRecordRaw ask-client "owner: client-rig\nkind: question\naddress-to: client:URIGTHEIR\nchannel: client:DRIGTHEIR\nquestion-ts: $rigClientTs\nthread-ts: $rigClientTs\naddressees: URIGTHEIR\nask-identity: member\nasked-at: 2026-09-29 12:00 +0300\n" \
	'# ❓ Question\n\nMay the rig go on, on your side?\n\n**✅ How to answer**\n- reply\n'
rigEnv=( MDAT_SKILLSET_ROOT="$rigScenarioDir/skills" )
rigRemind out
rigEnv=()
rigAssert "reminded, addressed as it was asked"            "$( rigHolds "$rigScenarioDir/out" 'REMINDED ask-client client:URIGTHEIR thread reminder=1 stages=30m' )" yes
rigAssert "in the conversation on that side, under the client's own token" "$( rigPostChannel 1 ) $( rigPostAuth 1 )" "DRIGTHEIR rig-user-token-CLIENT"
rigAssert "as a reply in the thread of the question"       "$( rigPostThread 1 )" "$rigClientTs"
rigAssert "and nothing went out under a token of our own team" "$( cat "$rigScenarioDir"/post.*.auth 2>/dev/null | LC_ALL=C grep -c -e 'TEAM' -e 'TESTER' || : )" 0

echo "-- what stopped the run of 2026-10-08: a question that holds a semicolon is reminded all the same --"
rigStart semicolon
rigRecordRaw ask-semicolon "owner: $rigMember\nkind: question\naddress-to: human-owner\nchannel: CRIG00001\nquestion-ts: $rigRootTs\nthread-ts: $rigRootTs\naddressees: URIGOWNER\nasked-at: 2026-09-29 12:00 +0300\n" \
	'# ❓ Question\n\nMay the rig keep report one; and report two; and every other one it was given that day, however long the sentence that asks for them turns out to be in the end?\n\n**✅ How to answer**\n- reply\n'
rigRemind out
rigAssert "sent, never held back as a member's own words are" "$( rigHolds "$rigScenarioDir/out" 'REMINDED ask-semicolon human-owner thread reminder=1 stages=30m' ):$( rigPosts )" yes:1
rigAssert "the question is quoted whole"                   "$( rigHolds "$rigScenarioDir/post.1" 'report one; and report two;' )" yes

echo "-- a member's wait reminds the ask it waits on, with no main loop running --"
rigStart wait-own
rigRecord ask-wait $(( 31 * 60 )) human-owner
rigRecord ask-young $(( 5 * 60 )) human-owner
rigThreadOf ask-wait ; rigThreadOf ask-young
## The wait the tools that ask run: the ask's own wait item, no session named.
rigWait wait "" --wait-source ask:ask-wait --wait-timeout 1
rigAssert "the wait itself is as it was: nothing arrived"  "$rigRc:$( head -1 "$rigScenarioDir/wait" )" "0:WAIT-RESULT: TIMEOUT"
rigAssert "the ask is reminded"                            "$( rigPosts ):$( rigField ask-wait reminders ):$( [ -n "$( rigField ask-wait reminder-30m )" ] && printf stamped )" 1:1:stamped
rigAssert "in its own thread"                              "$( rigPostChannel 1 ) $( rigPostThread 1 )" "CRIG00001 $( rigTsOf $(( 31 * 60 + 1 )) )"
rigAssert "said in the log of the wait, never in its result" "$( rigHolds "$rigScenarioDir/wait.err" '# --member-wait-for-input: REMINDED ask-wait human-owner thread reminder=1 stages=30m' ):$( rigHolds "$rigScenarioDir/wait" 'REMIND' )" yes:no
rigWait again "" --wait-source ask:ask-wait --wait-timeout 1
rigAssert "a second wait sends nothing"                    "$( rigPosts ):$( rigField ask-wait reminders )" 1:1
rigWait young "" --wait-source ask:ask-young --wait-timeout 1
rigAssert "an ask not yet 30 minutes old is not reminded"  "$( rigPosts ):$( rigField ask-young reminders )" 1:
## Switched off for a call, as the test runner does for every test, a wait reminds nobody.
rigStart wait-off
rigRecord ask-off $(( 31 * 60 )) human-owner
rigThreadOf ask-off
rigEnv=( MDAT_WAIT_REMIND=off )
rigWait wait "" --wait-source ask:ask-off --wait-timeout 1
rigEnv=()
rigAssert "MDAT_WAIT_REMIND=off: the wait is as it was, and nothing is sent" "$( head -1 "$rigScenarioDir/wait" ):$( rigPosts ):$( rigField ask-off reminders )" "WAIT-RESULT: TIMEOUT:0:"
## One call reminds at most once a minute, however many rounds it polls.
rigStart wait-rounds
rigRecord ask-rounds $(( 31 * 60 )) human-owner
rigThreadOf ask-rounds
: > "$rigScenarioDir/post-refuse"
rigWait wait "" --wait-source ask:ask-rounds --wait-timeout 12 --wait-poll-interval 1
rigAssert "more than one round was polled"                 "$( LC_ALL=C sed -n 's/^# waited: .*, \([0-9]*\) poll round(s).*/\1/p' "$rigScenarioDir/wait" | LC_ALL=C awk '{ print ( $1 >= 2 ) ? "yes" : "no:" $1 }' )" yes
rigAssert "and the reminder was tried once"                "$( rigTries )" 1
rigAssert "a send that failed is said in the log, and stamps no stage" "$( rigHolds "$rigScenarioDir/wait.err" '# --member-wait-for-input: FAILED ask-rounds human-owner | ' ):$( rigField ask-rounds reminders ):$( rigField ask-rounds reminder-30m )" yes::
## A send that fails can take a minute to say so, so a wait does not try that ask again for half an hour.
rm -f "$rigScenarioDir/post-refuse"
rigWait again "" --wait-source ask:ask-rounds --wait-timeout 1
rigAssert "the next wait leaves it alone"                  "$( rigTries ):$( rigPosts )" 1:0
LC_ALL=C sed -i.bak "s/^last-reminder-failed: .*/last-reminder-failed: $(( rigNow - 1801 ))/" "$rigScenarioDir/ws/.local/agents/pending/ask-rounds.md"
rm -f "$rigScenarioDir/ws/.local/agents/pending/"*.bak
rigWait later "" --wait-source ask:ask-rounds --wait-timeout 1
rigAssert "a wait half an hour later sends it"             "$( rigTries ):$( rigPosts ):$( rigField ask-rounds reminders )" 2:1:1
## One call acts on 5 asks at most, so a wait is never held long: the rest are the next call's.
rigStart wait-bound
for rigI in 1 2 3 4 5 6 7 ; do rigRecord "ask-$rigI" $(( 31 * 60 + rigI )) human-owner ; done
rigWait wait "" --wait-source ask:ask-1 --wait-timeout 1
rigAssert "seven are due, and the first call reminds five" "$( rigPosts )" 5
rigWait again "" --wait-source ask:ask-1 --wait-timeout 1
rigAssert "the next call the other two, and none twice"    "$( rigPosts ):$( LC_ALL=C grep -l -x -F 'reminders: 1' "$rigScenarioDir/ws/.local/agents/pending/ask-"*.md | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 7:7
## An answer that is there is the arrival: the wait returns it, and reminds nobody.
rigStart wait-answered
rigRecord ask-answered $(( 31 * 60 )) human-owner
printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGSELF1","text":"root"},{"ts":"%s","user":"URIGSELF1","thread_ts":"%s","text":"question"},{"ts":"%s","user":"URIGOWNER","thread_ts":"%s","text":"yes, keep it"}],"has_more":false}\n' \
	"$( rigTsOf $(( 31 * 60 + 1 )) )" "$( rigTsOf $(( 31 * 60 )) )" "$( rigTsOf $(( 31 * 60 + 1 )) )" "$( rigTsOf 60 )" "$( rigTsOf $(( 31 * 60 + 1 )) )" > "$rigScenarioDir/replies.$( rigTsOf $(( 31 * 60 + 1 )) ).json"
rigWait wait "" --wait-source ask:ask-answered --wait-timeout 1
rigAssert "the answer arrives"                             "$( head -1 "$rigScenarioDir/wait" ):$( rigHolds "$rigScenarioDir/wait" 'yes, keep it' )" "WAIT-RESULT: RECEIVED:yes"
rigAssert "and no reminder is sent over it"                "$( rigPosts ):$( rigField ask-answered reminders )" 0:

echo "-- a wait reminds every open ask of its coworking session, whoever of it asked --"
rigStart wait-session
printf 'SLACK_USER_TOKEN=rig-user-token-ARCH\n' > "$rigScenarioDir/ws/.local/.agents/$rigOther.agent.env"
rigSpawn rig-cow rig-sess "$rigMember"
rigSpawn rig-cow rig-mate "$rigOther"
rigSpawn rig-cow-far rig-far "$rigOther"
rigRecord ask-own $(( 31 * 60 )) human-owner
rigRecord ask-mate $(( 32 * 60 )) human-owner
LC_ALL=C sed -i.bak -e "s/^owner: .*/owner: $rigOther/" -e 's/^session-id: .*/session-id: rig-mate/' "$rigScenarioDir/ws/.local/agents/pending/ask-mate.md"
## Asked from the session that leads the coworking session, which is no spawn of it and is in no wait.
rigRecordRaw ask-lead "owner: $rigMember\nsession-id: rig-cow\nkind: permission-set\naddress-to: human-owner\nchannel: DRIGBOTDM\nquestion-ts: $( rigTsOf $(( 33 * 60 )) )\nthread-ts: $( rigTsOf $(( 33 * 60 )) )\naddressees: URIGOWNER\nask-identity: bot\nasked-at: 2026-09-29 12:00 +0300\n" \
	'# 🔐 Permission set\n\nMay the participants have these, for this session only?\n\n**🔑 Asked for**\n- `rig:tree` — Read\n'
## And one of the mate's that the owner answered, which the mate has not taken.
rigRecordRaw ask-heard "owner: $rigOther\nsession-id: rig-mate\nkind: question\naddress-to: human-owner\nchannel: CRIG00001\nquestion-ts: $( rigTsOf $(( 36 * 60 )) )\nthread-ts: $( rigTsOf $(( 36 * 60 )) )\naddressees: URIGOWNER\nasking-accounts: URIGSELF1\nasked-at: 2026-09-29 12:00 +0300\n" \
	'# ❓ Question\n\nMay the rig keep what the mate asked?\n'
printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGSELF1","text":"question"},{"ts":"%s","user":"URIGOWNER","thread_ts":"%s","text":"yes"}],"has_more":false}\n' \
	"$( rigTsOf $(( 36 * 60 )) )" "$( rigTsOf 300 )" "$( rigTsOf $(( 36 * 60 )) )" > "$rigScenarioDir/replies.$( rigTsOf $(( 36 * 60 )) ).json"
rigRecord ask-far $(( 34 * 60 )) human-owner
LC_ALL=C sed -i.bak 's/^session-id: .*/session-id: rig-far/' "$rigScenarioDir/ws/.local/agents/pending/ask-far.md"
rigRecord ask-loose $(( 35 * 60 )) human-owner
LC_ALL=C sed -i.bak '/^session-id: /d' "$rigScenarioDir/ws/.local/agents/pending/ask-loose.md"
rm -f "$rigScenarioDir/ws/.local/agents/pending/"*.bak
## A wait with no session and no ask of its own stands for no ask.
rigWait none "" --wait-source "file:$rigScenarioDir/drop" --wait-timeout 1
rigAssert "a wait that stands for no ask reminds nobody"   "$( head -1 "$rigScenarioDir/none" ):$( rigPosts )" "WAIT-RESULT: TIMEOUT:0"
## The Wait tool's own call: the session's stored wait, here on a drop file alone.
rigWait wait "" --wait-default --wait-session-id rig-sess --wait-source "file:$rigScenarioDir/drop" --wait-timeout 1
rigAssert "the wait is as it was"                          "$rigRc:$( head -1 "$rigScenarioDir/wait" )" "0:WAIT-RESULT: TIMEOUT"
rigAssert "its own ask, its session mate's and the lead's are reminded" \
	"$( rigField ask-own reminders ):$( rigField ask-mate reminders ):$( rigField ask-lead reminders ):$( rigPosts )" 1:1:1:3
rigAssert "each as its own asker, under the identity it was asked with" \
	"$( for rigI in 1 2 3 ; do printf '%s=%s\n' "$( rigPostThread "$rigI" )" "$( rigPostAuth "$rigI" )" ; done | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )" \
	"$( printf '%s=%s\n' "$( rigField ask-own thread-ts )" rig-user-token-TESTER "$( rigField ask-mate thread-ts )" rig-user-token-ARCH "$( rigField ask-lead thread-ts )" rig-bot-token-TEAM | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' )"
rigAssert "an ask of another coworking session, and one of no session, are not this wait's" "$( rigField ask-far reminders ):$( rigField ask-loose reminders )" ":"
rigAssert "the mate's answered one is not reminded, and the log of the wait says so" "$( rigField ask-heard reminders ):$( rigHolds "$rigScenarioDir/wait.err" '# --member-wait-for-input: HELD ask-heard human-owner | ' )" ":yes"
## The main loop's step, run after it: what no wait stood for, and nothing a second time.
rigRemind step
rigAssert "the main loop's step then reminds the other two, and none again" \
	"$( rigHolds "$rigScenarioDir/step" 'REMIND: reminded=2 ' ):$( rigField ask-far reminders ):$( rigField ask-loose reminders ):$( rigField ask-own reminders ):$( rigPosts )" yes:1:1:1:5

echo "-- the main loop's step and a member's wait both run: one reminder for a stage --"
rigBoth(){ ## scenario, first (wait|step), second (wait|step), TZ, age seconds, extra header lines
	rigStart "$1"
	rigRecord ask-both "$5" human-owner "${6:-}"
	rigThreadOf ask-both
	local bothRun
	for bothRun in "$2" "$3" ; do
		case "$bothRun" in
			wait) rigWait "run.$bothRun" "$4" --wait-source ask:ask-both --wait-timeout 1 ;;
			step) rigRemind "run.$bothRun" "$4" ;;
		esac
	done
}
rigBoth both-wait-first wait step "" $(( 31 * 60 ))
rigAssert "the wait first: it reminds, and the step sends nothing" "$( rigPosts ):$( rigField ask-both reminders ):$( rigHolds "$rigScenarioDir/run.step" 'REMIND: reminded=0 ' )" 1:1:yes
rigBoth both-step-first step wait "" $(( 31 * 60 ))
rigAssert "the step first: it reminds, and the wait sends nothing" "$( rigPosts ):$( rigField ask-both reminders ):$( rigHolds "$rigScenarioDir/run.step" 'REMINDED ask-both ' )" 1:1:yes
rigBoth both-2h wait step "" $(( 121 * 60 )) 'reminder-30m: 2026-10-07 10:00 +0000\nreminders: 1\nlast-reminder-at: 2026-01-01 10:00 +0000\n'
rigAssert "the 2-hour stage: one reminder, number 2"       "$( rigPosts ):$( rigField ask-both reminders ):$( [ -n "$( rigField ask-both reminder-2h )" ] && printf stamped )" 1:2:stamped
## The daily stage: a wait takes it from the ask's own stamps after 09:00, and leaves the main loop's window alone.
rigBoth both-daily-wait-first wait step "$rigTz10" $(( 5 * 3600 )) "$rigStamps"
rigAssert "daily, the wait first: one reminder"            "$( rigPosts ):$( rigField ask-both reminders ):$( rigField ask-both last-daily-reminder )" "1:3:$( rigToday "$rigTz10" )"
rigAssert "the step that followed spent the day's window, and sent nothing" "$( cat "$rigScenarioDir/ws/.local/agents/pending-remind.daily" 2>/dev/null ):$( rigHolds "$rigScenarioDir/run.step" 'REMIND: reminded=0 ' )" "$( rigToday "$rigTz10" ):yes"
rigBoth both-daily-step-first step wait "$rigTz10" $(( 5 * 3600 )) "$rigStamps"
rigAssert "daily, the step first: one reminder"            "$( rigPosts ):$( rigField ask-both reminders )" 1:3
rigStart both-daily-early
rigRecord ask-both $(( 5 * 3600 )) human-owner "$rigStamps"
rigThreadOf ask-both
rigWait wait "$( rigTzAt 8 )" --wait-source ask:ask-both --wait-timeout 1
rigAssert "before 09:00 a wait sends no daily reminder, and opens no window" "$( rigPosts ):$( [ -f "$rigScenarioDir/ws/.local/agents/pending-remind.daily" ] && printf yes || printf no )" 0:no
rigWait wait "$rigTz10" --wait-source ask:ask-both --wait-timeout 1
rigAssert "after 09:00 it does, and the window is still the main loop's to open" "$( rigPosts ):$( [ -f "$rigScenarioDir/ws/.local/agents/pending-remind.daily" ] && printf yes || printf no )" 1:no
## At the same moment: the post is slow, so the two runs meet.
rigStart both-at-once
rigRecord ask-both $(( 31 * 60 )) human-owner
rigThreadOf ask-both
: > "$rigScenarioDir/post-slow"
rigWait run.wait "" --wait-source ask:ask-both --wait-timeout 1 &
rigBothPid=$!
rigRemind run.step
wait "$rigBothPid" 2>/dev/null || :
rigAssert "at once: one post was tried, and one reminder is on the record" "$( rigTries ):$( rigPosts ):$( rigField ask-both reminders )" 1:1:1
## And with the main loop itself: one iteration of it, and a wait, in either order.
rigLoopWait(){ ## -- a wait on the loop scenario's ask, in the loop's own environment
	env -i HOME="$rigDir/home" PATH="$rigDir/bin:/usr/bin:/bin:/usr/sbin:/sbin" TZ="$rigTz" \
		MMDAPP="$rigDir/ws" MDAT_DATA_ROOT="$rigDir/data" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigDir/home/.claude/skills" RIG_FN="$rigTool" RIG_MEMBER="$rigMember" \
		bash -c 'cd "$MMDAPP" && exec bash "$RIG_FN" --member-wait-for-input "$RIG_MEMBER" --wait-source ask:ask-loop --wait-timeout 1' > "$rigDir/wait.out" 2> "$rigDir/wait.err"
}
rigLoopReminders(){ LC_ALL=C grep -c -F 'Still waiting for your answer' "$rigDir/posted" 2>/dev/null || : ; }
rigLoopScenario both-loop-last
rigRecord ask-loop $(( 31 * 60 )) human-owner
rigLoopWait
rigAssert "a wait reminds in the main loop's own workspace" "$( rigLoopReminders ):$( rigField ask-loop reminders )" 1:1
rigOneRun
rigAssert "the iteration that follows sends nothing more"  "$( rigLoopReminders ):$( rigHolds "$rigDir/one.err" '--intern-main-loop: REMIND: reminded=0 ' )" 1:yes
rigLoopScenario both-loop-first
rigRecord ask-loop $(( 31 * 60 )) human-owner
rigOneRun
rigLoopWait
rigAssert "an iteration, then a wait: one reminder"        "$( rigLoopReminders ):$( rigField ask-loop reminders ):$( rigHolds "$rigDir/one.err" '--intern-main-loop: REMIND: reminded=1 ' )" 1:1:yes

echo "-- the tools that ask: the wait of an ask already asked reminds it --"
rigStart ask-tool
rigRecord ask-tool $(( 31 * 60 )) human-owner
rigThreadOf ask-tool
rigAskPid=""
set -m
( cd "$rigScenarioDir/ws" && printf '%s' '{"pending_id":"ask-tool"}' | env -u MDAT_DATA_ROOT -u CLAUDE_CODE_SESSION_ID -u CLAUDE_CODE_ENTRYPOINT -u ANTHROPIC_API_KEY -u OPENAI_API_KEY -u MDAT_WAIT_REMIND \
	TZ="$rigTz" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" MDAT_DATA_ROOT="$rigScenarioDir/data" \
	MDAT_SPAWN_SESSION_ID=rig-sess MDAT_SPAWN_AGENT="$rigMember" MDAT_HARNESS_WAIT_TIMEOUT=1 bash "$rigHarness" --intern-tool AskQuestion ) > "$rigScenarioDir/tool" 2> "$rigScenarioDir/tool.err" &
rigAskPid=$!
set +m
## A question nobody answers is waited on without end, so the check ends the tool itself, once it has reminded.
rigAskLeft=120
while kill -0 "$rigAskPid" 2>/dev/null && [ "$rigAskLeft" -gt 0 ] && [ "$( rigPosts )" = 0 ] ; do sleep 1 ; rigAskLeft=$(( rigAskLeft - 1 )) ; done
sleep 2
{ kill -TERM -- "-$rigAskPid" ; sleep 1 ; kill -KILL -- "-$rigAskPid" ; wait "$rigAskPid" ; } 2>/dev/null
rigAssert "the tool's own wait reminded the ask, once"     "$( rigPosts ):$( rigField ask-tool reminders )" 1:1
rigAssert "in the thread of the question"                  "$( rigPostChannel 1 ) $( rigPostThread 1 )" "CRIG00001 $( rigTsOf $(( 31 * 60 + 1 )) )"
rigAssert "nothing but that reminder was posted"           "$( LC_ALL=C grep -L -F 'Still waiting for your answer' "$rigScenarioDir"/post.[0-9] 2>/dev/null | LC_ALL=C wc -l | LC_ALL=C tr -d ' ' )" 0

rigAssert "no model was called"                            "$( cat "$rigTmp/model-calls" 2>/dev/null | wc -l | tr -d ' ' )" 0
rigAssert "no request left for a real host"                "$( cat "$rigTmp"/*/curl.log 2>/dev/null | LC_ALL=C grep -c '^url:' || : )" 0

PATH="$rigSavedPath"
if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PENDING REPLY REMIND CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'PENDING_REPLY_REMIND: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
