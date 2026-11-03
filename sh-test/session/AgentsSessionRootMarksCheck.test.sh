#!/usr/bin/env bash
## Behavioural check on S6.37: a session's root message shows the session's end, run rather than read, through the real
## close of a run and the real reaction operation, against a rig workspace of its own and a Slack of its own.
## Held:
##   1. NO END WHILE A RUN IS LEFT. One run of a session closed and another still open places nothing.
##   2. THE END, ALL WELL. The close of the last run puts `checkered_flag` and `white_check_mark` on the root message of
##      the session's own thread -- never on a tracking post -- under the bot identity, and keeps them in `root.end`.
##   3. THE END, ONE FAILED. The same close with a run that failed puts `octagonal_sign` in place of the tick.
##   4. A SECOND CLOSE ADDS NOTHING. The settled record closed again reacts nowhere, and its set is not placed twice.
##   5. A RATE LIMIT LOSES NOTHING. A reaction answered 429 with a Retry-After is waited out and placed by the same call.
##      A reaction Slack refuses leaves the set whole in `root.want`, and the pass over dead records places it after.
##   6. A START CLEARS THE END. A run of the session starting takes both marks off the root message and removes the file.
##   7. NO THREAD, NO MARKS. A session whose thread is a tracking thread, and one with no thread at all, are given none.
## Red before the change: no mark is ever placed, and every function this check calls but one does not exist.
## Offline: a curl first on PATH answers as Slack and opens no socket; every file is this rig's own temp tree.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigPackage="$MDLT_ORIGIN/myx/myx.distro-agents"
rigSandboxInclude="$rigPackage/sh-lib/session/AgentsTools.SpawnSandbox.include"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -f "$rigSandboxInclude" ] || rigRefuse "the include this check measures is not at the origin: $rigSandboxInclude"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsSessionRootMarksCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigWs="$rigTmp/ws" ; rigHome="$rigTmp/home" ; rigSkills="$rigTmp/skills" ; rigData="$rigTmp/data" ; rigSlack="$rigTmp/slack"
rigSp="$rigWs/.local/agents/spawned" ; rigStores="$rigWs/.local/agents/sessions"
mkdir -p "$rigTmp/bin" "$rigWs/.local/.agents" "$rigSp" "$rigStores" "$rigHome" "$rigData/board/running" "$rigData/board/review" "$rigSlack"
mkdir -p "$rigSkills/magic-team"
printf -- '---\nmaintainers: rig\n---\nrig identity\n' > "$rigSkills/magic-team/magic-team.basic.md"
rigHost="$( hostname -s 2> /dev/null )" ; [ -n "$rigHost" ] || rigHost="unknown"
trap 'chmod -R u+rwX -- "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT

## THE RIG'S SLACK: no socket, each call logged, each reaction kept as `<method> <ts> <name>`, and a step of
## slack/react-steps answering it -- `ok`, `rate:<n>` (HTTP 429 with a Retry-After of n), or `error:<name>`.
cat > "$rigTmp/bin/curl" <<'RIGCURL'
#!/bin/sh
rigDir="${0%/*}/../slack"
rigHeader="$( cat )"
rigMethod="" rigPrev="" rigTs="" rigName="" rigChannel="" rigHeaderFile=""
for rigArg in "$@" ; do
	case "$rigArg" in
		https://slack.com/api/*) rigMethod="${rigArg#https://slack.com/api/}" ;;
		channel@*) rigChannel="$( cat "${rigArg#channel@}" 2> /dev/null )" ;;
		timestamp@*) rigTs="$( cat "${rigArg#timestamp@}" 2> /dev/null )" ;;
		name@*) rigName="$( cat "${rigArg#name@}" 2> /dev/null )" ;;
	esac
	[ "$rigPrev" != "-D" ] || rigHeaderFile="$rigArg"
	rigPrev="$rigArg"
done
printf '%s\n' "$rigMethod" >> "$rigDir/calls"
case "$rigMethod" in
	auth.test) printf '{"ok":true,"url":"https://rig.invalid/","user_id":"URIGBOT01"}\n' ;;
	conversations.info) printf '{"ok":true,"channel":{"id":"CRIG00001","is_im":false,"is_mpim":false}}\n' ;;
	chat.postMessage) printf '{"ok":true,"channel":"CRIG00001","ts":"1760000000.000200","message":{"ts":"1760000000.000200","user":"URIGBOT01"}}\n' ;;
	reactions.add|reactions.remove)
		rigStep="ok"
		if [ -s "$rigDir/react-steps" ] ; then
			rigStep="$( head -1 "$rigDir/react-steps" )"
			tail -n +2 "$rigDir/react-steps" > "$rigDir/react-steps.next" && mv "$rigDir/react-steps.next" "$rigDir/react-steps"
		fi
		case "$rigStep" in
			rate:*)
				[ -z "$rigHeaderFile" ] || printf 'HTTP/1.1 429 Too Many Requests\r\nRetry-After: %s\r\n\r\n' "${rigStep#rate:}" > "$rigHeaderFile"
				printf '{"ok":false,"error":"ratelimited"}\n'
			;;
			error:*)
				printf '{"ok":false,"error":"%s"}\n' "${rigStep#error:}"
			;;
			*)
				printf '%s %s:%s %s\n' "$rigMethod" "$rigChannel" "$rigTs" "$rigName" >> "$rigDir/react"
				printf '{"ok":true}\n'
			;;
		esac
	;;
	*) printf '{"ok":false,"error":"channel_not_found"}\n' ;;
esac
RIGCURL
chmod +x "$rigTmp/bin/curl" || rigRefuse "could not install the rig's curl"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_CHANNEL_EVENT_TRACK=CRIGTRACK\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"

rigPass=0
rigFail=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPass=$(( rigPass + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFail=$(( rigFail + 1 ))
	fi
}
## One call of the include's own functions in the rig workspace: the function, then its arguments.
rigInRig(){ ## function, arguments...
	local rigFn="$1"
	shift
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigHome" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" MDLT_OPTION="--run-from-path $MDLT_ORIGIN" \
		MDAT_SKILLSET_ROOT="$rigSkills" SLACK_BOT_TOKEN=rig-bot-token-TEAM RIG_SCENARIO="$rigSlack" \
		bash -c '. "$1" ; shift ; "$@"' rig "$rigSandboxInclude" "$rigFn" "$@" 2>&1
}
## A session of this rig's own: its store, its root message, and one run of it that is still open.
rigSession(){ ## session id, its root message (may be empty: no thread)
	rigSess="$1"
	rm -rf "$rigStores/$1"
	mkdir -p "$rigStores/$1"
	[ -z "$2" ] || printf '%s\n' "$2" > "$rigStores/$1/session.thread"
}
rigRun(){ ## spawn id, status
	mkdir -p "$rigSp/$1"
	printf -- '---\nsession-id: %s\nspawn-id: %s\nstart-context: spawned\ntracking-name: %s\nhost: %s\nowner: magic-coordinator\nstatus: %s\n---\n' \
		"$rigSess" "$1" "$1" "$rigHost" "$2" > "$rigSp/$1/$1.spawn.md"
}
rigSection(){ : > "$rigSlack/react" ; : > "$rigSlack/react-steps" ; : > "$rigSlack/calls" ; }
rigReacted(){ LC_ALL=C tr '\n' ' ' < "$rigSlack/react" 2> /dev/null || : ; }
rigEnd(){ LC_ALL=C tr '\n' ' ' < "$rigStores/$rigSess/root.end" 2> /dev/null || : ; }
rigWant(){ LC_ALL=C tr '\n' ' ' < "$rigStores/$rigSess/root.want" 2> /dev/null || : ; }

echo "-- 1. no end while a run of the session is left --"
rigSession "rig-one-$$" "CHAIR001:1700000000.000100"
rigRun "rig-one-a-$$" spawn-started
rigRun "rig-one-b-$$" spawn-started
rigSection
rigInRig AgentsToolsSpawnProxyCloseSandbox "$rigSp/rig-one-a-$$/rig-one-a-$$.spawn.md" succeeded 0 "the rig ended it" > /dev/null
rigAssert "one run closed, another open: no reaction at all" "$( rigReacted )" ""
rigAssert "and nothing is owed either" "$( [ -f "$rigStores/$rigSess/root.want" ] && echo want || echo none )" "none"

echo "-- 2. the end of the last run, all well --"
rigSection
rigInRig AgentsToolsSpawnProxyCloseSandbox "$rigSp/rig-one-b-$$/rig-one-b-$$.spawn.md" succeeded 0 "the rig ended it" > /dev/null
rigAssert "the root message takes the flag, then the tick" "$( rigReacted )" "reactions.add CHAIR001:1700000000.000100 checkered_flag reactions.add CHAIR001:1700000000.000100 white_check_mark "
rigAssert "the set is kept as the session's end" "$( rigEnd )" "checkered_flag white_check_mark "
rigAssert "and nothing is left owed" "$( [ -f "$rigStores/$rigSess/root.want" ] && echo want || echo none )" "none"
rigAssert "the tracking conversation is never reacted to" "$( LC_ALL=C grep -c 'CRIGTRACK' "$rigSlack/react" || : )" "0"

echo "-- 3. the end of the last run, one failed --"
rigSession "rig-two-$$" "CHAIR002:1700000000.000200"
rigRun "rig-two-a-$$" spawn-started
rigRun "rig-two-b-$$" spawn-started
rigInRig AgentsToolsSpawnProxyCloseSandbox "$rigSp/rig-two-a-$$/rig-two-a-$$.spawn.md" failed 1 "the rig ended it" > /dev/null
rigSection
rigInRig AgentsToolsSpawnProxyCloseSandbox "$rigSp/rig-two-b-$$/rig-two-b-$$.spawn.md" succeeded 0 "the rig ended it" > /dev/null
rigAssert "a failed run of the session gives the stop sign" "$( rigReacted )" "reactions.add CHAIR002:1700000000.000200 checkered_flag reactions.add CHAIR002:1700000000.000200 octagonal_sign "

echo "-- 4. a second close adds nothing --"
rigSection
rigInRig AgentsToolsSpawnProxyCloseSandbox "$rigSp/rig-two-b-$$/rig-two-b-$$.spawn.md" succeeded 0 "the rig ended it" > /dev/null
rigAssert "the settled record closed again reacts nowhere" "$( rigReacted )" ""
rigAssert "and its end set is as it was" "$( rigEnd )" "checkered_flag octagonal_sign "

echo "-- 5. a rate limit and a refusal lose nothing --"
rigSession "rig-three-$$" "CHAIR003:1700000000.000300"
rigRun "rig-three-a-$$" spawn-started
rigSection
printf 'rate:1\n' > "$rigSlack/react-steps"
rigInRig AgentsToolsSpawnProxyCloseSandbox "$rigSp/rig-three-a-$$/rig-three-a-$$.spawn.md" succeeded 0 "the rig ended it" > /dev/null
rigAssert "a rate-limited reaction is waited out and placed by the same call" "$( rigReacted )" "reactions.add CHAIR003:1700000000.000300 checkered_flag reactions.add CHAIR003:1700000000.000300 white_check_mark "
rigAssert "and the whole set is on it" "$( rigEnd )" "checkered_flag white_check_mark "
rigSession "rig-four-$$" "CHAIR004:1700000000.000400"
rigRun "rig-four-a-$$" spawn-started
rigSection
printf 'error:missing_scope\n' > "$rigSlack/react-steps"
rigInRig AgentsToolsSpawnProxyCloseSandbox "$rigSp/rig-four-a-$$/rig-four-a-$$.spawn.md" succeeded 0 "the rig ended it" > /dev/null
rigAssert "a refused reaction leaves the set owed, whole" "$( rigWant )" "checkered_flag white_check_mark "
rigAssert "and nothing is called it an end" "$( [ -f "$rigStores/$rigSess/root.end" ] && echo end || echo none )" "none"
rigSection
rigInRig AgentsToolsSpawnProxyRootMarkRetry > /dev/null
rigAssert "the pass over dead records places it" "$( rigReacted )" "reactions.add CHAIR004:1700000000.000400 checkered_flag reactions.add CHAIR004:1700000000.000400 white_check_mark "
rigAssert "and the want becomes the session's end" "$( [ -f "$rigStores/$rigSess/root.want" ] && echo want || echo none )" "none"

echo "-- 6. a start clears the end --"
rigSection
rigInRig AgentsToolsSpawnProxyRootMarkClear "$rigSess" > /dev/null
rigAssert "both marks are taken off the root message" "$( rigReacted )" "reactions.remove CHAIR004:1700000000.000400 checkered_flag reactions.remove CHAIR004:1700000000.000400 white_check_mark "
rigAssert "and the session carries no end" "$( [ -f "$rigStores/$rigSess/root.end" ] && echo end || echo none )" "none"
rigSection
rigInRig AgentsToolsSpawnProxyRootMarkClear "$rigSess" > /dev/null
rigAssert "a second clear reacts nowhere, its work being done" "$( rigReacted )" ""

echo "-- 7. no session thread, no marks --"
rigSession "rig-five-$$" "CRIGTRACK:1700000000.000500"
rigRun "rig-five-a-$$" spawn-started
rigSection
rigInRig AgentsToolsSpawnProxyCloseSandbox "$rigSp/rig-five-a-$$/rig-five-a-$$.spawn.md" succeeded 0 "the rig ended it" > /dev/null
rigAssert "a session whose thread is a tracking thread is left alone" "$( rigReacted )" ""
rigSession "rig-six-$$" ""
rigRun "rig-six-a-$$" spawn-started
rigSection
rigInRig AgentsToolsSpawnProxyCloseSandbox "$rigSp/rig-six-a-$$/rig-six-a-$$.spawn.md" succeeded 0 "the rig ended it" > /dev/null
rigAssert "a session with no thread at all is left alone" "$( rigReacted )" ""

echo "-- 8. a paused session says so, and a resumed one stops --"
rigSession "rig-seven-$$" "CHAIR007:1700000000.000700"
rigSection
: > "$rigStores/$rigSess/paused"
rigInRig AgentsToolsSpawnProxyRootPauseMarks "$rigSess" > /dev/null
rigAssert "a paused session shows the pause on its root message" "$( rigReacted )" "reactions.add CHAIR007:1700000000.000700 double_vertical_bar "
rigSection
rigInRig AgentsToolsSpawnProxyRootPauseMarks "$rigSess" > /dev/null
rigAssert "and asks for it once, not at every tick" "$( rigReacted )" ""
rm -f "$rigStores/$rigSess/paused"
rigSection
rigInRig AgentsToolsSpawnProxyRootPauseMarks "$rigSess" > /dev/null
rigAssert "a resumed session takes the pause off" "$( rigReacted )" "reactions.remove CHAIR007:1700000000.000700 double_vertical_bar "
rigSection
rigInRig AgentsToolsSpawnProxyRootPauseMarks "$rigSess" > /dev/null
rigAssert "and asks for that once too" "$( rigReacted )" ""

echo "-- 9. the marks are the magic-team account's, never a member's --"
## WHO REACTS: the team account, under the bot identity. Every reaction this file makes is counted against that, so a call
## added later that names a member instead fails here.
rigCalls="$( LC_ALL=C grep -c 'intern-op-comms-slack-react' "$rigSandboxInclude" || : )"
rigTeam="$( LC_ALL=C grep 'intern-op-comms-slack-react' "$rigSandboxInclude" | LC_ALL=C grep -c '^[[:space:]]*DistroAgentsTools --intern-op-comms-slack-react magic-team ' || : )"
rigBot="$( LC_ALL=C grep 'intern-op-comms-slack-react' "$rigSandboxInclude" | LC_ALL=C grep -c -- '--identity-bot' || : )"
rigAssert "there is at least one reaction call to measure" "$( [ "$rigCalls" -gt 0 ] && echo yes || echo no )" "yes"
rigAssert "every reaction call names magic-team" "$rigTeam" "$rigCalls"
rigAssert "every reaction call runs under the bot identity" "$rigBot" "$rigCalls"

printf 'SESSION_ROOT_MARKS: %s (%d assertions, %d failed, offline, rig tree only)\n' \
	"$( [ "$rigFail" -eq 0 ] && echo OK || echo FAILED )" "$(( rigPass + rigFail ))" "$rigFail"
[ "$rigFail" -eq 0 ] || exit 1
exit 0
