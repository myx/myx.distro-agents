#!/usr/bin/env bash
## Behavioural check on AgentsToolsPendingReplyRemindRun, the main loop's reminders for
## asks still waiting: a stage is due at 30 minutes and at 2 hours, once each; the daily
## reminder only in the first run after 09:00 local, only for an ask 4+ hours old, and
## once a day; a repeat run sends nothing; 10 due asks to one person are 10 thread
## replies, and 11 are 11 thread replies too, never a top-level message; a record
## with no thread is skipped; a failed send stamps nothing; the identity the ask used is
## the one reminded under; no record is ever closed; and the main loop goes on when the
## reminders fail. Offline: a Slack-shaped fake curl is first on PATH, model CLIs on PATH
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
rigTmp="$( mkdir -p "$MMDAPP/.local/temp" && mktemp -d "$MMDAPP/.local/temp/AgentsPendingReplyRemindCheck.XXXXXX" )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+rwx -- "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin" "$rigTmp/tmp"
cp "$rigTest/check-fixtures/pending-reply-remind-check.curl.test.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
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
		TZ="${2:-$rigTz}" TMPDIR="$rigTmp/tmp" RIG_SCENARIO="$rigScenarioDir" MMDAPP="$rigScenarioDir/ws" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDAT_DATA_ROOT="$rigScenarioDir/data" bash "$rigTool" --intern-mcp-execute ) \
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
	env -i HOME="$rigDir/home" PATH="$rigDir/bin:/usr/bin:/bin:/usr/sbin:/sbin" TMPDIR="$rigDir" TZ="$rigTz" \
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

rigAssert "no model was called"                            "$( cat "$rigTmp/model-calls" 2>/dev/null | wc -l | tr -d ' ' )" 0
rigAssert "no request left for a real host"                "$( cat "$rigTmp"/*/curl.log 2>/dev/null | LC_ALL=C grep -c '^url:' || : )" 0

PATH="$rigSavedPath"
if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PENDING REPLY REMIND CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'PENDING_REPLY_REMIND: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
