#!/usr/bin/env bash
## Behavioural check on the review prompt: what a handback posts when its item's `review-by`
## names a person, and how his answer is read as the review verdict
## (AgentsTools.ReviewFlow.include, AgentsEscalationVerdict.awk, the escalation read,
## sh-lib/templates/review-prompt.post.format.md). Covers: the post, filled from its own
## template and sent as the team bot; its record, its click answers and its place in the Wait
## of the session that handed back; no prompt for a reviewer that is a session, a routine or
## a member; each verdict by click and by reply, applied through the review flow and signed
## human-owner; a return clicked with no text, taken once the text is written; a comment
## coming back as RETURNED with the review left open, and the answer after it taken; two
## verdicts clicked naming none; the prompt of a review settled another way closed and
## marked; an answer under the prompt of a review no longer open; and the whole of it through
## the served SubagentHandback and Wait of the member.
## Offline: a Slack-shaped fake curl is first on PATH, and a ps beside it lists the rig's own
## runs only, the stand-in children under their own pids; a fake DistroAgentsConsole.sh stands
## in for the CLI; every scenario has its own board, sandboxes and workspace under this
## check's temp tree, guarded on every call. Never the live team data or .local/agents.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigHarness="$rigLib/AgentsUniversalHarness.sh"
rigFixture="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/review-prompt.curl.test.sh"
rigTemplate="$rigLib/templates/review-prompt.post.format.md"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
[ -f "$rigHarness" ] || rigRefuse "harness not found: $rigHarness"
[ -f "$rigFixture" ] || rigRefuse "the fake curl fixture is missing: $rigFixture"
rigTmp="$( mktemp -d -t AgentsReviewPromptCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigLivePids=""
trap 'for rigPid in $rigLivePids ; do pkill -P "$rigPid" 2> /dev/null ; kill "$rigPid" 2> /dev/null ; done ; chmod -R u+w "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
cp "$rigFixture" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl" || rigRefuse "could not install the fake curl"
## THE RIG'S OWN PROCESS LIST. A spawn is found running by a process list read from the host
## (ps -A). A rig that read the real one would take whatever command line of this host holds
## one of its ids for a run of its own, and another copy of this check for its own. So the ps
## first on PATH answers the whole-host listing from the rig's own list, beside it, one
## `<pid> <command line>` line a process, and hands every other call to the real ps. Each line
## is a stand-in process of this rig under its own pid, and is listed only while that process
## lives: one that is stopped is gone from the list, as it would be from the host's.
ln -s "$( command -v ps )" "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
: > "$rigTmp/ps.list"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*)
		while read -r rigPsPid rigPsLine ; do
			kill -0 "$rigPsPid" 2> /dev/null || continue
			case "$*" in
				*pid=*) printf '%s %s\n' "$rigPsPid" "$rigPsLine" ;;
				*) printf '%s\n' "$rigPsLine" ;;
			esac
		done < "${0%/*}/../ps.list"
		exit 0
	;;
esac
exec "${0%/*}/ps.real" "$@"
RIGPS
chmod +x "$rigTmp/bin/ps"
rigHost="$( hostname -s 2> /dev/null )" || rigHost="unknown"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHas(){ ## file, text -> yes | no
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	case "$( cat "$1" )" in *"$2"*) printf 'yes' ;; *) printf 'no' ;; esac
}

## One scenario: its own workspace, board and Slack. The member that hands back is
## keeper-myx, with a Slack account of its own, so a post of the team bot can be told from one
## of the member.
rigName="" ; rigDir="" ; rigWs="" ; rigData="" ; rigSpawn="" ; rigItem=""
rigStart(){ ## scenario name
	local startMember
	rigName="$1" ; rigDir="$rigTmp/$1" ; rigWs="$rigDir/ws" ; rigData="$rigDir/data"
	rigSpawn="rig-child-$1" ; rigItem="dispatch-20261012T0100Z-$1"
	mkdir -p "$rigData/board/running" "$rigData/board/review" "$rigData/board/processed" "$rigData/board/pending" \
		"$rigWs/.local/.agents" "$rigWs/.local/agents/spawned"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-KEEPER\n' > "$rigWs/.local/.agents/keeper-myx.agent.env"
	for startMember in magic-coordinator keeper-myx magic-tester human-owner ; do
		mkdir -p "$rigWs/.local/agents/members/$startMember"
		printf -- '---\nname: %s\ndescription: rig member\n---\n' "$startMember" > "$rigWs/.local/agents/members/$startMember/SKILL.md"
		printf 'rig\n' > "$rigWs/.local/agents/members/$startMember/$startMember.basic.md"
	done
	printf '#!/bin/sh\n## cli-configured MDAT_SPAWN_LAUNCH_MARKER --cli)\ncat >> "$RIG_TMP/console-in.$MDAT_SPAWN_SESSION_ID"\necho rig-child-output\nexit 0\n' > "$rigWs/DistroAgentsConsole.sh"
	chmod +x "$rigWs/DistroAgentsConsole.sh"
	: > "$rigDir/curl.log"
}
## One command in the scenario, guarded to its own trees, the fake curl first on PATH. Extra
## environment as NAME=value words in rigEnv. Output into <result>, rc into <result>.rc.
rigEnv=()
rigRun(){ ## result file, command...
	local runOut="$1" ; shift
	env -i HOME="$rigDir" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
		MDLT_OPTION="--run-from-path $MDLT_ORIGIN" RIG_TMP="$rigTmp" RIG_SCENARIO="$rigDir" RIG_CURL_LOG="$rigDir/curl.log" "${rigEnv[@]+"${rigEnv[@]}"}" \
		bash -c '
			case "$MMDAPP" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			case "$MDAT_DATA_ROOT" in "$RIG_TMP"/*) ;; *) exit 99 ;; esac
			[ "$( command -v curl )" = "$RIG_TMP/bin/curl" ] || exit 98
			cd "$MMDAPP" && exec "$@"
		' rig "$@" > "$runOut" 2>&1
	printf '%s' "$?" > "$runOut.rc"
}
rigOp(){ ## result file, DistroAgentsTools.fn.sh args...
	local opOut="$1" ; shift
	rigRun "$opOut" bash "$rigFn" "$@"
}
## As the session that handed back: its member and its spawn id.
rigAsChild(){ ## result file, DistroAgentsTools.fn.sh args...
	rigEnv=( MDAT_SPAWN_AGENT=keeper-myx MDAT_SPAWN_SESSION_ID="$rigSpawn" )
	rigOp "$@"
	rigEnv=()
}
rigTool(){ ## result file, tool name, arguments JSON -- one served harness tool call of that session
	printf '%s\n' "$3" > "$rigDir/tool.args"
	rigEnv=( MDAT_SPAWN_AGENT=keeper-myx MDAT_SPAWN_SESSION_ID="$rigSpawn" )
	rigRun "$1" bash -c 'exec bash "$0" --intern-tool "$1" < "$2"' "$rigHarness" "$2" "$rigDir/tool.args"
	rigEnv=()
}
## The scenario's work: a task, the dispatch that tracks it in running with its reviewer, the
## spawn record of the session that works it, and a stand-in process, so that session is live.
rigWork(){ ## review-by value (empty: none)
	printf -- '---\ntype: task\nowner: keeper-myx\n---\n\n# Rework the rig widget\n\nThe widget drops its last line. Make it keep it.\n' > "$rigData/board/running/task-20261012T0000Z-$rigName.md"
	printf -- '---\ntype: dispatch\nowner: keeper-myx\nstatus: dispatch-started\nspawn-id: %s\ntracks: task-20261012T0000Z-%s\n%s---\n\n# rig dispatch\n' \
		"$rigSpawn" "$rigName" "${1:+review-by: $1
}" > "$rigData/board/running/$rigItem.md"
	mkdir -p "$rigWs/.local/agents/spawned/$rigSpawn" "$rigWs/.local/agents/sessions/$rigSpawn"
	printf -- '---\nsession-id: 5e55104a-rig-%s\nspawn-id: %s\nparent-session-id: none\ntracking-name: %s\nhost: %s\nowner: keeper-myx\nstatus: spawn-started\nsession-thread: CSES00001:1700000000.000100\nspawns: %s\ndescription: rework the rig widget\n---\n' \
		"$rigName" "$rigSpawn" "$rigSpawn" "$rigHost" "$rigItem" > "$rigWs/.local/agents/spawned/$rigSpawn/$rigSpawn.md"
	: > "$rigDir/transcript.log"
	printf '%s\n' "$rigDir/transcript.log" > "$rigWs/.local/agents/sessions/$rigSpawn/transcript"
	bash -c 'sleep 600 ; :' "$rigSpawn" > /dev/null 2>&1 < /dev/null &
	rigLivePids="$rigLivePids $!"
	printf '%s rig-run --session-id %s\n' "$!" "$rigSpawn" >> "$rigTmp/ps.list"
	disown "$!" 2> /dev/null || :
}
## The handback as the tooling takes it once it is delivered: the review flow's own entry.
rigHandback(){ ## outcome line
	rigAsChild "$rigDir/handback" --intern-op-review-handback keeper-myx --session-id "$rigSpawn" --message "$1"
}
rigLoc(){ ## -- the board state holding the scenario's item, or not-found
	local stateDir
	for stateDir in "$rigData"/board/*/ ; do
		[ -f "$stateDir$rigItem.md" ] && { basename "$stateDir" ; return 0 ; }
	done
	printf 'not-found'
}
rigItemFile(){ printf '%s' "$rigData/board/$( rigLoc )/$rigItem.md" ; }
rigDecisions(){ ## pattern -- matching Decisions lines of the item
	LC_ALL=C grep -c -E "^- [0-9TZ:-]+ $1" "$( rigItemFile )" 2> /dev/null || :
}
rigPosts(){ cat "$rigDir/posts" 2> /dev/null || printf '0' ; }
## The pending-reply records of the scenario, oldest first, and the n-th of them.
rigRecords(){
	local recordFile
	for recordFile in $( ls -tr "$rigWs/.local/agents/pending"/*.md 2> /dev/null ) ; do printf '%s\n' "$recordFile" ; done
}
rigRecordCount(){ rigRecords | LC_ALL=C awk 'END { print NR + 0 ; }' ; }
rigRecord(){ ## n (default: the newest)
	if [ -n "${1:-}" ] ; then rigRecords | LC_ALL=C sed -n "${1}p" ; else rigRecords | tail -1 ; fi
}
rigId(){ local idFile ; idFile="$( rigRecord "${1:-}" )" ; idFile="${idFile##*/}" ; printf '%s' "${idFile%.md}" ; }
rigField(){ ## field, record n (default: the newest)
	LC_ALL=C awk -v key="$1" '$0 == "---" { if ( ++dashes == 2 ) { exit ; } next ; } dashes == 1 && index( $0, key ": " ) == 1 { print substr( $0, length( key ) + 3 ) ; found = 1 ; exit ; } END { if ( ! found ) { print "none" ; } }' "$( rigRecord "${2:-}" )" 2> /dev/null || printf 'no-record'
}
## The prompt as it was posted: the body its record keeps.
rigPromptBody(){ LC_ALL=C awk 'seenBody { print ; next ; } $0 == "# Question asked" { seenBody = 1 ; getline ; }' "$( rigRecord "${1:-}" )" 2> /dev/null ; }
## The prompt's own thread as Slack returns it: the prompt with the reactions a scenario puts
## on it, then the replies. The tooling's own three emoji, placed by the bot, are always there.
rigSeeded='{"name":"+1","count":1,"users":["URIGBOT01"]},{"name":"leftwards_arrow_with_hook","count":1,"users":["URIGBOT01"]},{"name":"x","count":1,"users":["URIGBOT01"]}'
rigClick(){ ## emoji name, user
	printf ',{"name":"%s","count":1,"users":["%s"]}' "$1" "$2"
}
rigReply(){ ## ts suffix (after the prompt's), user, text as a JSON string body
	printf ',{"ts":"1700000001.%s","user":"%s","text":"%s","thread_ts":"%s"}' "$1" "$2" "$3" "$( rigField question-ts )"
}
rigThread(){ ## clicks (rigClick words, may be empty), replies (rigReply words, may be empty)
	local threadTs
	threadTs="$( rigField question-ts )"
	printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGBOT01","text":"the prompt","reactions":[%s%s]}%s],"has_more":false}\n' \
		"$threadTs" "$rigSeeded" "$1" "$2" > "$rigDir/replies.$threadTs.json"
}
## The read of the prompt's answer, as the Wait of the session that handed back makes it.
rigRead(){ ## record n (default: the newest)
	rigAsChild "$rigDir/read" --intern-op-escalation-read keeper-myx "$( rigId "${1:-}" )"
}
rigReadLine(){ ## prefix -- the first line of the read with it
	LC_ALL=C grep -m1 "^$1" "$rigDir/read" 2> /dev/null || printf 'no-such-line'
}
## The emoji placed on, or taken off, the prompt: their names in the order asked for.
rigReacted(){ ## reactions|reactions.removed
	LC_ALL=C awk -v want="$( rigField question-ts )" '$1 == want { out = out ( out == "" ? "" : " " ) $2 ; } END { print out ; }' "$rigDir/$1" 2> /dev/null
}
rigFill(){ ## want -- the template filled straight, the slots from the caller's environment
	ASKP_WANT="$1" ASKP_FORM=verdict LC_ALL=C awk -f "$rigLib/AgentsToolingTemplateFill.awk" -f "$rigLib/AgentsAskPostFill.awk" "$rigTemplate" 2>&1
}

echo "-- 0. the template: the post, the post that takes no answer any more, the emoji --"
rigHow=$'**✅ How to answer**\n- click 👍 to accept, ↩️ to return it for corrections, or ❌ to reject it\n- or reply with the first word: `accept`, `return` or `reject`\n- a return or a reject takes what to change from your reply: write it after the word, or in a reply beside your click'
rigAssert "the post, whole" \
	"$( ASKP_F_member=keeper-myx ASKP_F_task=$'The task\n`task-a` · `dispatch-b`' ASKP_F_outcome='rig work done' ASKP_F_session='`5e55104a` · `C1:1.2`' rigFill post )" \
	$'# 🔎 Review\n\nkeeper-myx handed back, and its work waits for your verdict.\n\n**🗂 Task**\nThe task\n`task-a` · `dispatch-b`\n\n**📦 Outcome**\nrig work done\n\n**🧵 Session**\n`5e55104a` · `C1:1.2`\n\n'"$rigHow"
rigAssert "a field with no value leaves its heading out" \
	"$( ASKP_F_member=keeper-myx ASKP_F_outcome='rig work done' rigFill post | LC_ALL=C grep -c -e 'Task' -e 'Session' )" 0
rigAssert "with no member nothing is filled" \
	"$( ASKP_F_outcome='rig work done' rigFill post )" "AgentsAskPostFill.awk: the slot {{member}} is required and has no value"
rigAssert "a post that takes no answer any more: the same text without How to answer" \
	"$( ASKP_F_member=keeper-myx ASKP_F_outcome='rig work done' rigFill closed )" \
	$'# 🔎 Review\n\nkeeper-myx handed back, and its work waits for your verdict.\n\n**📦 Outcome**\nrig work done'
rigAssert "its click answers, and none of them the mark of an answered question" \
	"$( rigFill reactions | LC_ALL=C tr '\n' ' ' )" "+1 leftwards_arrow_with_hook x "

echo "-- 1. a served SubagentHandback, its reviewer the human-owner: one review prompt, as the team bot --"
rigStart handback
rigWork human-owner
printf 'SLACK_WORKSPACE_DOMAIN=rig.slack.example\n' >> "$rigWs/.local/.agents/magic-team.agent.env"
rigTool "$rigDir/tool" SubagentHandback '{"outcome":"rig work done","to":"CSES00001:1700000000.000100"}'
rigAssert "the handback is posted, by the member"          "$( LC_ALL=C grep -c '^SENT_MESSAGE_TS=' "$rigDir/tool" ):$( cat "$rigDir/post.1.token" 2> /dev/null )" "1:rig-user-token-KEEPER"
rigAssert "the item moved running -> review"               "$( rigLoc )" review
rigAssert "one more post: the review prompt, by the team bot" "$( rigPosts ):$( cat "$rigDir/post.2.token" 2> /dev/null )" "2:rig-bot-token-TEAM"
rigAssert "to the human-owner, addressed to him"           "$( LC_ALL=C grep -c '"channel": *"URIGOWNER"' "$rigDir/post.2" 2> /dev/null ):$( rigHas "$rigDir/post.2" '<@URIGOWNER>' )" "1:yes"
rigAssert "the prompt, whole: who, the task in words, the outcome, the session and its thread, how to answer" "$( rigPromptBody )" \
	$'# 🔎 Review\n\nkeeper-myx handed back, and its work waits for your verdict.\n\n**🗂 Task**\nRework the rig widget\n`task-20261012T0000Z-handback` · `dispatch-20261012T0100Z-handback`\nThe widget drops its last line. Make it keep it.\n\n**📦 Outcome**\nrig work done\n\n**🧵 Session**\n`5e55104a` · [thread](https://rig.slack.example/archives/CSES00001/p1700000000000100) — rework the rig widget\n\n'"$rigHow"
rigAssert "its record: a review, asked of the human-owner by the member that handed back" \
	"$( rigRecordCount ):$( rigField kind ):$( rigField address-to ):$( rigField owner ):$( rigField session-id ):$( rigField item ):$( rigField ask-identity ):$( rigField status )" \
	"1:review:human-owner:keeper-myx:$rigSpawn:$rigItem:bot:reply-pending"
rigAssert "which names its thread, who may answer and who asked" \
	"$( rigField channel ):$( rigField question-ts ):$( rigField thread-ts ):$( rigField addressees ):$( rigField asking-accounts | LC_ALL=C tr -d ' ' )" \
	"CRIG00001:1700000001.000201:1700000001.000201:URIGOWNER:URIGBOT01"
rigAssert "its click answers are placed under it"          "$( rigReacted reactions )" "+1 leftwards_arrow_with_hook x"
rigAssert "it is in the Wait of the session that handed back" \
	"$( LC_ALL=C sed -n 's/^sources: //p' "$rigWs/.local/agents/sessions/$rigSpawn/wait/state" 2> /dev/null | LC_ALL=C grep -c -F "ask:$( rigId )" )" 1
rigAssert "the handback is on the item's Decisions as before" "$( rigDecisions 'keeper-myx handback: handback: rig work done' )" 1
rigHandback "handed back again"
rigAssert "a handback on an item already in review asks nothing more" "$( rigLoc ):$( rigPosts ):$( rigRecordCount )" "review:2:1"

echo "-- 2. a reviewer that is a session, a routine or a member, or none named: no prompt --"
for rigReviewer in rig-par-session grooming.routine magic-tester '' ; do
	rigStart "none-${rigReviewer:-empty}"
	rigWork "$rigReviewer"
	rigHandback "rig work done"
	rigAssert "review-by ${rigReviewer:-(none)}: into review, nothing posted, nothing recorded" "$( rigLoc ):$( rigPosts ):$( rigRecordCount )" "review:0:0"
done

echo "-- 3. accept by click: only his own click, and then the review flow's own accept --"
rigStart click-accept
rigWork human-owner
rigHandback "rig work done"
rigAssert "the prompt is posted and recorded"              "$( rigPosts ):$( rigField kind )" "1:review"
rigThread "" ""
rigRead
rigAssert "the emoji the tooling placed are no answer"     "$( rigLoc ):$( rigField status )" "review:reply-pending"
rigThread "$( rigClick +1 URIGOTHER )" ""
rigRead
rigAssert "nor is a click by somebody else"                "$( rigLoc ):$( rigField status )" "review:reply-pending"
rigThread "$( rigClick +1 URIGOWNER )" ""
rigRead
rigAssert "his 👍 is read as accept"                       "$( rigReadLine 'ESCALATION: ' ):$( rigReadLine 'VERDICT: ' ):$( rigReadLine 'ANSWERED-BY: ' )" "ESCALATION: $( rigId ) answered:VERDICT: accept:ANSWERED-BY: URIGOWNER"
rigAssert "the item is processed"                          "$( rigLoc )" processed
rigAssert "Decisions: accepted, signed human-owner"        "$( rigDecisions 'human-owner verdict: accepted' )" 1
rigAssert "the transcript has its VERDICT line"            "$( LC_ALL=C grep -c " VERDICT item=$rigItem kind=verdict by=human-owner " "$rigDir/transcript.log" )" 1
rigAssert "DISMISSED went to the session thread, to the member" "$( rigPosts ):$( LC_ALL=C grep -c '"channel": *"CSES00001"' "$rigDir/post.2" 2> /dev/null ):$( rigHas "$rigDir/post.2" 'DISMISSED' )" "3:1:yes"
rigAssert "and the third post is the one confirmation reply under the prompt: the verdict read, and who gave it" "$( LC_ALL=C grep -c -F 'Read: `accept` by human-owner. It is given as the verdict of this review.' "$rigDir/post.3" 2> /dev/null )" 1
rigAssert "the record closes with the verdict and who gave it" "$( rigField status ):$( rigField verdict ):$( rigField answered-by )" "reply-received:accept:URIGOWNER"
rigRead
rigAssert "a second read reports the same, and applies nothing again" "$( rigReadLine 'VERDICT: ' ):$( rigPosts ):$( rigDecisions 'human-owner verdict: accepted' )" "VERDICT: accept:3:1"

echo "-- 4. return by click: taken once he has written what to change; then the next handback asks again --"
rigStart click-return
rigWork human-owner
rigHandback "rig work done"
rigThread "$( rigClick leftwards_arrow_with_hook URIGOWNER )" ""
rigRead
rigAssert "a return clicked with no text is not applied"   "$( rigLoc ):$( rigField status ):$( rigReadLine 'VERDICT: ' )" "review:reply-pending:VERDICT: RETURNED"
rigAssert "and the member is told why"                     "$( rigReadLine 'VERDICT-REASON: ' )" \
	"VERDICT-REASON: human-owner clicked return under the review prompt of $rigItem and wrote nothing with it. A return takes what to change from a reply there, so nothing is applied yet. The click is taken once that reply is written"
rigThread "$( rigClick leftwards_arrow_with_hook URIGOWNER )" "$( rigReply 000250 URIGOWNER 'fix the rig widget' )"
rigRead
rigAssert "with his reply beside the click it is a return" "$( rigReadLine 'VERDICT: ' ):$( rigReadLine 'VERDICT-TEXT: ' )" "VERDICT: return:VERDICT-TEXT: fix the rig widget"
rigAssert "the item is running again"                      "$( rigLoc )" running
rigAssert "his text is in the item, under the returned heading signed human-owner" \
	"$( LC_ALL=C grep -c -E '^## Review: returned \([0-9TZ:-]+, human-owner\)$' "$( rigItemFile )" ):$( LC_ALL=C grep -c -x 'fix the rig widget' "$( rigItemFile )" )" "1:1"
rigAssert "Decisions: returned, signed human-owner"        "$( rigDecisions 'human-owner verdict: returned: fix the rig widget' )" 1
## Four posts: the prompt; the reply under it saying the bare click is not applied yet; the
## return delivered to the member; the confirmation reply of the return that was taken.
rigAssert "delivered in the session thread, to the member" "$( rigPosts ):$( LC_ALL=C grep -c '"channel": *"CSES00001"' "$rigDir/post.3" 2> /dev/null ):$( rigHas "$rigDir/post.3" 'RETURNED for corrections' ):$( rigHas "$rigDir/post.3" 'fix the rig widget' )" "4:1:yes:yes"
rigAssert "the bare click was answered under the prompt, once: not applied, and why" "$( LC_ALL=C grep -c -F 'Read: `return` by human-owner, and it is not applied.' "$rigDir/post.2" 2> /dev/null ):$( rigHas "$rigDir/post.2" 'The click is taken once that reply is written' )" "1:yes"
rigAssert "and the return that was taken is confirmed under the prompt" "$( LC_ALL=C grep -c -F 'Read: `return` by human-owner. It is given as the verdict of this review.' "$rigDir/post.4" 2> /dev/null )" 1
rigAssert "the record closes with return"                  "$( rigField status ):$( rigField verdict )" "reply-received:return"
rigHandback "fixed"
rigAssert "the next handback is in review again, with a prompt of its own" "$( rigLoc ):$( rigRecordCount ):$( rigField status 1 ):$( rigField status 2 ):$( rigHas "$( rigRecord 2 )" $'**📦 Outcome**\nfixed' )" "review:2:reply-received:reply-pending:yes"

echo "-- 5. reject by click, his text beside it --"
rigStart click-reject
rigWork human-owner
rigHandback "rig work done"
rigThread "$( rigClick x URIGOWNER )" "$( rigReply 000250 URIGOWNER 'wrong approach' )$( rigReply 000260 URIGOWNER 'start over' )"
rigRead
rigAssert "his ❌ with his replies is a reject"             "$( rigReadLine 'VERDICT: ' )" "VERDICT: reject"
rigAssert "the item is pending, marked rejected"           "$( rigLoc ):$( LC_ALL=C grep -c -x 'status: review-rejected' "$( rigItemFile )" )" "pending:1"
rigAssert "both replies are its text, as one line"         "$( LC_ALL=C grep -c -x 'wrong approach / start over' "$( rigItemFile )" )" 1
rigAssert "Decisions: rejected, signed human-owner"        "$( rigDecisions 'human-owner verdict: rejected: wrong approach / start over' )" 1
rigAssert "the session is dismissed"                       "$( rigHas "$rigDir/post.2" 'DISMISSED' )" yes

echo "-- 6. each verdict by reply: the first word, the text after it --"
rigStart reply-accept
rigWork human-owner
rigHandback "rig work done"
rigThread "" "$( rigReply 000250 URIGOWNER 'accept good work' )"
rigRead
rigAssert "accept, with a word on it"                      "$( rigReadLine 'VERDICT: ' ):$( rigLoc ):$( rigDecisions 'human-owner verdict: accepted: good work' )" "VERDICT: accept:processed:1"
rigStart reply-return
rigWork human-owner
rigHandback "rig work done"
rigThread "" "$( rigReply 000250 URIGOWNER 'Return: fix the widget\nand the gadget' )"
rigRead
rigAssert "return, in any case and with a colon"           "$( rigReadLine 'VERDICT: ' ):$( rigLoc )" "VERDICT: return:running"
rigAssert "its text is the rest of the reply, every line of it" "$( LC_ALL=C grep -c -x 'fix the widget / and the gadget' "$( rigItemFile )" ):$( rigReadLine 'VERDICT-TEXT: ' )" "1:VERDICT-TEXT: fix the widget / and the gadget"
rigStart reply-reject
rigWork human-owner
rigHandback "rig work done"
rigThread "" "$( rigReply 000250 URIGOWNER 'reject start over' )"
rigRead
rigAssert "reject"                                         "$( rigReadLine 'VERDICT: ' ):$( rigLoc ):$( rigDecisions 'human-owner verdict: rejected: start over' )" "VERDICT: reject:pending:1"
rigStart reply-return-bare
rigWork human-owner
rigHandback "rig work done"
rigThread "" "$( rigReply 000250 URIGOWNER 'return' )"
rigRead
rigAssert "a return with nothing after the word is not applied" "$( rigLoc ):$( rigField status ):$( rigReadLine 'VERDICT: ' )" "review:reply-pending:VERDICT: RETURNED"

echo "-- 7. a comment: back to the member as RETURNED, the review open; the answer after it is the verdict --"
rigStart comment
rigWork human-owner
rigHandback "rig work done"
rigThread "" "$( rigReply 000250 URIGOWNER 'what is this about?' )"
rigRead
rigAssert "a reply that names no verdict comes back as RETURNED" "$( rigReadLine 'ESCALATION: ' ):$( rigReadLine 'VERDICT: ' )" "ESCALATION: $( rigId ) open:VERDICT: RETURNED"
rigAssert "the review stays open, and nothing is decided"  "$( rigLoc ):$( rigField status ):$( rigDecisions '[a-z-]+ verdict: ' )" "review:reply-pending:0"
rigAssert "an affirmation in words is a comment too"       "$( rigThread "" "$( rigReply 000250 URIGOWNER 'ok, looks fine' )" ; rigRead ; rigLoc ):$( rigReadLine 'VERDICT: ' )" "review:VERDICT: RETURNED"
rigThread "$( rigClick +1 URIGOWNER )" "$( rigReply 000250 URIGOWNER 'what is this about?' )"
rigRead
rigAssert "his click after the comment is the verdict"     "$( rigReadLine 'VERDICT: ' ):$( rigLoc ):$( rigField status )" "VERDICT: accept:processed:reply-received"

echo "-- 8. two verdicts clicked by him name none --"
rigStart two-clicks
rigWork human-owner
rigHandback "rig work done"
rigThread "$( rigClick +1 URIGOWNER )$( rigClick x URIGOWNER )" "$( rigReply 000250 URIGOWNER 'hm' )"
rigRead
rigAssert "nothing is applied"                             "$( rigLoc ):$( rigField status ):$( rigReadLine 'VERDICT: ' )" "review:reply-pending:VERDICT: RETURNED"

echo "-- 9. a review settled another way: the prompt is closed, marked, and takes no answer --"
rigStart settled
rigWork human-owner
rigHandback "rig work done"
rigOp "$rigDir/typed" --magic-review-accept magic-coordinator "$rigItem" --summary "last resort"
rigAssert "the coordinator's typed verdict is applied"     "$( cat "$rigDir/typed.rc" ):$( rigLoc )" "0:processed"
rigAssert "the prompt's record is withdrawn, by whom and why" "$( rigField status ):$( rigField withdrawn-by ):$( rigField withdraw-reason )" "withdrawn:magic-coordinator:$rigItem was accepted by magic-coordinator"
rigAssert "its click answers are taken off, and it is marked" "$( rigReacted reactions.removed ):$( rigReacted reactions | LC_ALL=C awk '{ print $NF ; }' )" "+1 leftwards_arrow_with_hook x:no_entry_sign"
rigAssert "its post is edited to the same text without How to answer" \
	"$( LC_ALL=C grep -c -F 'handed back, and its work waits for your verdict' "$rigDir/edit.$( rigField question-ts )" 2> /dev/null ):$( LC_ALL=C grep -c -F 'How to answer' "$rigDir/edit.$( rigField question-ts )" 2> /dev/null )" "1:0"
rigAssert "its thread is told"                             "$( LC_ALL=C grep -l -F "This review is settled another way: $rigItem was accepted by magic-coordinator. The prompt above takes no answer any more." "$rigDir"/post.[0-9] 2> /dev/null | LC_ALL=C awk 'END { print NR + 0 ; }' )" 1
rigAssert "the item's Decisions hold the one verdict"      "$( rigDecisions '[a-z-]+ verdict: ' ):$( rigDecisions '[a-z-]+ dismissed: withdrawn' )" "1:0"
rigThread "$( rigClick x URIGOWNER )" "$( rigReply 000950 URIGOWNER 'too late' )"
rigRead
rigAssert "a click under it afterwards changes nothing"    "$( rigReadLine 'ESCALATION: ' ):$( rigLoc )" "ESCALATION: $( rigId ) closed withdrawn:processed"
rigStart settled-return
rigWork human-owner
rigHandback "rig work done"
rigOp "$rigDir/typed" --magic-review-return magic-coordinator "$rigItem" --message "one more pass"
rigAssert "a typed return closes the prompt too"           "$( rigLoc ):$( rigField status ):$( rigField withdraw-reason )" "running:withdrawn:$rigItem was returned by magic-coordinator"
rigStart settled-reject
rigWork human-owner
rigHandback "rig work done"
rigOp "$rigDir/typed" --member-review-reject human-owner "$rigItem" --message "not this way"
rigAssert "and so does his own typed reject, at the console" "$( rigLoc ):$( rigField status ):$( rigField withdraw-reason )" "pending:withdrawn:$rigItem was rejected by human-owner"
rigStart settled-archived
rigWork human-owner
rigHandback "rig work done"
rigOp "$rigDir/typed" --intern-op-review-end magic-coordinator "$rigItem" --reason archived --no-dismiss
rigAssert "an item archived closes its prompt"             "$( rigField status ):$( rigField withdraw-reason )" "withdrawn:$rigItem was archived by magic-coordinator"
rigStart settled-stopped
rigWork human-owner
rigHandback "rig work done"
rigOp "$rigDir/typed" --intern-op-review-end magic-coordinator "$rigItem" --reason taskstop --no-dismiss
rigAssert "a session only stopped leaves its review, and its prompt, open" "$( rigLoc ):$( rigField status )" "review:reply-pending"

echo "-- 10. an answer under the prompt of a review that is no longer open --"
rigStart stale
rigWork human-owner
rigHandback "rig work done"
mv "$rigData/board/review/$rigItem.md" "$rigData/board/processed/$rigItem.md"
rigThread "$( rigClick +1 URIGOWNER )" ""
rigRead
rigAssert "it is not applied, and the member is told why"  "$( rigReadLine 'VERDICT: ' ):$( rigReadLine 'VERDICT-REASON: ' )" \
	"VERDICT: RETURNED:VERDICT-REASON: human-owner answered accept under the review prompt of $rigItem, but that review is no longer open: the item is in processed. Nothing is applied, and the prompt is closed"
rigAssert "the prompt is closed"                           "$( rigField status ):$( rigDecisions '[a-z-]+ verdict: ' )" "withdrawn:0"

echo "-- 11. the whole of it by the member's own tools: SubagentHandback, then Wait --"
rigStart served
rigWork human-owner
rigTool "$rigDir/tool" SubagentHandback '{"outcome":"rig work done","to":"CSES00001:1700000000.000100"}'
rigAssert "the prompt is posted"                           "$( rigPosts ):$( rigField kind )" "2:review"
rigThread "" "$( rigReply 000250 URIGOWNER 'is the last line kept now?' )"
rigTool "$rigDir/wait1" Wait '{"timeout":30}'
rigAssert "his comment arrives on the member's Wait as RETURNED" "$( LC_ALL=C grep -c -x -e 'ASK-RESULT: RECEIVED' -e 'VERDICT: RETURNED' "$rigDir/wait1" ):$( rigHas "$rigDir/wait1" 'is the last line kept now?' )" "2:yes"
rigAssert "with what it is and the way on"                 "$( rigHas "$rigDir/wait1" 'This is the review prompt of your handback.' ):$( rigHas "$rigDir/wait1" "SendMessage to=CRIG00001:$( rigField question-ts )" )" "yes:yes"
rigAssert "the review stays open, and the prompt in its Wait" "$( rigLoc ):$( rigField status ):$( LC_ALL=C sed -n 's/^sources: //p' "$rigWs/.local/agents/sessions/$rigSpawn/wait/state" 2> /dev/null | LC_ALL=C grep -c -F "ask:$( rigId )" )" "review:reply-pending:1"
rigThread "$( rigClick +1 URIGOWNER )" "$( rigReply 000250 URIGOWNER 'is the last line kept now?' )"
rigTool "$rigDir/wait2" Wait '{"mode":"continue","timeout":30}'
rigAssert "his click arrives on the next Wait as the verdict" "$( LC_ALL=C grep -c -x -e 'ASK-RESULT: RECEIVED' -e 'VERDICT: accept' "$rigDir/wait2" )" 2
rigAssert "applied: the item is processed, signed human-owner" "$( rigLoc ):$( rigDecisions 'human-owner verdict: accepted' )" "processed:1"
rigAssert "and DISMISSED is in the session thread for its next Wait" "$( LC_ALL=C grep -l -F 'DISMISSED' "$rigDir"/post.[0-9] 2> /dev/null | LC_ALL=C awk 'END { print NR + 0 ; }' )" 1

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ REVIEW PROMPT CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'REVIEW_PROMPT: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
