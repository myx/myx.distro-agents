#!/usr/bin/env bash
## Behavioural check on WHERE the answer to a handback's review prompt is read: the thread of
## the post, and -- where the post stands as one top-level message of a direct conversation of
## two people -- the conversation itself, because a person answering there types in the
## conversation and never opens the thread (AgentsToolsEscalationThreadVerdict,
## AgentsToolsEscalationAskDirect, both in AgentsTools.MemberEscalation.include).
## Covers: an `accept` typed in a direct conversation read as the verdict, applied through the
## review flow and signed human-owner, with no reminder after it; a reply there that names none
## of the words kept as a comment, the review left open and nothing decided; a reject by his
## click under the post, with what to change written beside it; and a conversation that is not
## direct -- a channel several questions share -- never read that way, so an unnumbered reply
## there is nobody's answer.
## Offline: a Slack-shaped fake curl is first on PATH, and a ps beside it lists the rig's own
## runs only, the stand-in children under their own pids; a fake DistroAgentsConsole.sh stands
## in for the CLI; every scenario has its own board, sandboxes and workspace under this
## check's temp tree, guarded on every call. Never the live team data or .local/agents.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigHarness="$rigLib/harness/AgentsUniversalHarness.sh"
## The name of the address field, read where it is held, so a rename is one line there.
rigReportsTo="$( LC_ALL=C sed -n 's/^agentsRunRouteField="\(.*\)"$/\1/p' "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/session/AgentsTools.SpawnSandbox.include" )"
rigFixture="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/review-prompt.curl.stub.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
[ -f "$rigHarness" ] || rigRefuse "harness not found: $rigHarness"
[ -f "$rigFixture" ] || rigRefuse "the fake curl fixture is missing: $rigFixture"
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
## A return of a review starts an ended run again, with the session's control thread, which outlives this check: the rig ends it.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-control-threads.include.sh" || rigRefuse "the rig's fixture that ends control threads is missing from the package: sh-test/check-fixtures/rig-control-threads.include.sh"
rigTmp="$( rigTempDir AgentsReviewAnswerPlaceCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigLivePids=""
trap 'rigProcSignalWithChildren TERM $rigLivePids ; chmod -R u+w "$rigTmp" 2> /dev/null ; rigControlThreadsEnd "$rigTmp" ; rm -rf -- "$rigTmp"' EXIT
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
rigName="" ; rigDir="" ; rigWs="" ; rigData="" ; rigSpawn="" ; rigItem="" ; rigPromptId=""
rigStart(){ ## scenario name
	local startMember
	rigName="$1" ; rigDir="$rigTmp/$1" ; rigWs="$rigDir/ws" ; rigData="$rigDir/data"
	rigSpawn="rig-child-$1" ; rigItem="dispatch-20261012T0100Z-$1" ; rigPromptId=""
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
	env -i MDAT_WORKSPACE_MODE=team-rig HOME="$rigDir" PATH="$rigTmp/bin:/usr/bin:/bin:/usr/sbin:/sbin" MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" MDLT_ORIGIN="$MDLT_ORIGIN" \
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
## The scenario's work: a task, the dispatch that tracks it in running with its reviewer, the
## spawn record of the session that works it, and a stand-in process, so that session is live.
rigWork(){ ## review-by value (empty: none), the address its run reports to (empty: none recorded)
	printf -- '---\ntype: task\nowner: keeper-myx\n---\n\n# Rework the rig widget\n\nThe widget drops its last line. Make it keep it.\n' > "$rigData/board/running/task-20261012T0000Z-$rigName.md"
	printf -- '---\ntype: dispatch\nowner: keeper-myx\nstatus: dispatch-started\nspawn-id: %s\ntracks: task-20261012T0000Z-%s\n%s---\n\n# rig dispatch\n' \
		"$rigSpawn" "$rigName" "${1:+review-by: $1
}" > "$rigData/board/running/$rigItem.md"
	mkdir -p "$rigWs/.local/agents/spawned/$rigSpawn" "$rigWs/.local/agents/sessions/$rigSpawn"
	printf -- '---\nsession-id: 5e55104a-rig-%s\nspawn-id: %s\nparent-spawn-id: none\ntracking-name: %s\nhost: %s\nowner: keeper-myx\nstatus: spawn-started\nsession-thread: CSES00001:1700000000.000100\nspawns: %s\ndescription: rework the rig widget\n%s---\n' \
		"$rigName" "$rigSpawn" "$rigSpawn" "$rigHost" "$rigItem" "${2:+$rigReportsTo: $2
}" > "$rigWs/.local/agents/spawned/$rigSpawn/$rigSpawn.spawn.md"
	: > "$rigDir/transcript.log"
	printf '%s\n' "$rigDir/transcript.log" > "$rigWs/.local/agents/sessions/$rigSpawn/transcript"
	bash -c 'sleep 600 ; :' "$rigSpawn" > /dev/null 2>&1 < /dev/null &
	rigLivePids="$rigLivePids $!" ; rigProcNote "$!"
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
rigRecord(){ ## n (default: the newest)
	if [ -n "${1:-}" ] ; then rigRecords | LC_ALL=C sed -n "${1}p" ; else rigRecords | tail -1 ; fi
}
rigId(){ local idFile ; idFile="$( rigRecord "${1:-}" )" ; idFile="${idFile##*/}" ; printf '%s' "${idFile%.md}" ; }
## A closed record is retained beside the open ones (retention, T9): both stores are read, so
## a check of a record that was answered does not depend on which one it lies in now.
rigField(){ ## field, pending id (default: the newest open record's)
	local fieldFile
	if [ -n "${2:-}" ] ; then
		fieldFile="$rigWs/.local/agents/pending/$2.md"
		[ -f "$fieldFile" ] || fieldFile="$rigWs/.local/agents/pending/closed/$2.md"
	else
		fieldFile="$( rigRecord )"
	fi
	LC_ALL=C awk -v key="$1" '$0 == "---" { if ( ++dashes == 2 ) { exit ; } next ; } dashes == 1 && index( $0, key ": " ) == 1 { print substr( $0, length( key ) + 3 ) ; found = 1 ; exit ; } END { if ( ! found ) { print "none" ; } }' "$fieldFile" 2> /dev/null || printf 'no-record'
}
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
		"$threadTs" "$rigSeeded" "${1:-}" "${2:-}" > "$rigDir/replies.$threadTs.json"
}
## The conversation the prompt stands in, as Slack describes it: a direct one where the
## scenario says so, a channel several questions share where it does not.
rigDirect(){ printf '{"ok":true,"channel":{"id":"CRIG00001","is_im":true,"is_mpim":false}}\n' > "$rigDir/channel.info" ; }
rigConversation(){ ## messages typed at the top of the conversation, as JSON bodies
	local convTs
	convTs="$( rigField question-ts "${rigPromptId:-}" )"
	printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGBOT01","text":"the prompt"}%s],"has_more":false}\n' "$convTs" "$1" > "$rigDir/history.json"
}
rigTyped(){ ## ts suffix, user, text -- one message typed in the conversation, no thread_ts
	printf ',{"ts":"1700000001.%s","user":"%s","text":"%s"}' "$1" "$2" "$3"
}
## The read of the prompt's answer, as the Wait of the session that handed back makes it.
rigRead(){ ## record n (default: the newest)
	rigAsChild "$rigDir/read" --intern-op-escalation-read keeper-myx "$( rigId "${1:-}" )"
}
rigReadLine(){ ## prefix -- the first line of the read with it
	LC_ALL=C grep -m1 "^$1" "$rigDir/read" 2> /dev/null || printf 'no-such-line'
}
## One run of the reminders, as the main loop makes it: the same two files, the tool's own
## set-up context, a zero deadline. Its summary line is read, never the clock.
rigRemind(){ ## output name
	printf '%s\n' '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/questions/AgentsTools.PendingReplyCollect.include"' \
		'. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/questions/AgentsTools.PendingReplyRemind.include"' \
		'AgentsToolsPendingReplyRemindRun || exit 1' | rigRun "$rigDir/$1" bash "$rigFn" --intern-mcp-execute
}
rigRemindLine(){ LC_ALL=C grep -m1 '^REMIND: ' "$rigDir/$1" 2> /dev/null || printf 'no-such-line' ; }

echo "-- 1. an accept typed in the direct conversation is the verdict, and no reminder follows --"
rigStart accept-conversation
rigWork human-owner
rigHandback "rig work done"
rigDirect
## The reminder he was sent, and then his answer: typed in the conversation, which is where he
## types, never a reply in the thread under the post.
rigThread "$( rigReply 000250 URIGBOT01 '⏰ Still waiting for your answer (asked 18:10, reminder 1):' )"
rigConversation "$( rigTyped 000300 URIGOWNER 'accept' )"
rigPromptId="$( rigId )"
rigRead
rigAssert "the answer typed in the conversation is taken"  "$( rigReadLine 'ESCALATION: ' ):$( rigReadLine 'VERDICT: ' ):$( rigReadLine 'ANSWERED-BY: ' )" "ESCALATION: $rigPromptId answered:VERDICT: accept:ANSWERED-BY: URIGOWNER"
rigAssert "the review is accepted, the item processed"     "$( rigLoc )" processed
rigAssert "Decisions: accepted, signed human-owner"        "$( rigDecisions 'human-owner verdict: accepted' )" 1
rigAssert "the record closes with the verdict"             "$( rigField status "$rigPromptId" ):$( rigField verdict "$rigPromptId" )" "reply-received:accept"
rigRemind remind
rigAssert "no reminder follows the verdict"                "$( rigRemindLine remind )" "REMIND: reminded=0 threads=0 digests=0 skipped=0 failed=0 held=0"
rigAssert "and nothing was posted"                         "$( rigPosts )" 3

echo "-- 2. a reply in the conversation that names none of the words is not a verdict --"
rigStart comment-conversation
rigWork human-owner
rigHandback "rig work done"
rigDirect
rigThread ""
rigConversation "$( rigTyped 000300 URIGOWNER 'ok looks fine' )"
rigRead
rigAssert "nothing is decided: it comes back as a comment" "$( rigReadLine 'ESCALATION: ' ):$( rigReadLine 'VERDICT: ' )" "ESCALATION: $( rigId ) open:VERDICT: RETURNED"
rigAssert "the review stays open"                          "$( rigLoc ):$( rigField status )" "review:reply-pending"
rigAssert "no verdict line is on the item"                 "$( rigDecisions '[a-z-]+ verdict: ' )" 0
rigAssert "what he wrote is kept with the answer"          "$( LC_ALL=C grep -c 'ok looks fine' "$( rigRecord )" )" 1

echo "-- 3. a reject by his click under the post, with what to change beside it --"
rigStart reject-click
rigWork human-owner
rigHandback "rig work done"
rigDirect
rigThread "$( rigClick x URIGOWNER )" "$( rigReply 000250 URIGOWNER 'wrong approach' )"
rigRead
rigAssert "the click beside his words is a reject"         "$( rigReadLine 'VERDICT: ' )" "VERDICT: reject"
rigAssert "the item is pending, marked rejected"           "$( rigLoc ):$( LC_ALL=C grep -c -x 'status: review-rejected' "$( rigItemFile )" )" "pending:1"
rigAssert "Decisions: rejected, signed human-owner"        "$( rigDecisions 'human-owner verdict: rejected: wrong approach' )" 1

echo "-- 4. a conversation that is not direct is never read that way --"
rigStart shared-conversation
rigWork human-owner
rigHandback "rig work done"
rigThread ""
## The same words, typed in a channel several questions share, where an unnumbered reply
## answers nobody: the record's own thread is all that answers it.
rigConversation "$( rigTyped 000300 URIGOWNER 'accept' )"
rigRead
rigAssert "the same answer in a shared conversation decides nothing" "$( rigReadLine 'ESCALATION: ' ):$( rigLoc )" "ESCALATION: $( rigId ) open:review"
rigAssert "and no verdict line is on the item"             "$( rigDecisions '[a-z-]+ verdict: ' )" 0

echo
if [ "$rigFailCount" -eq 0 ] ; then
	printf 'REVIEW_ANSWER_PLACE: OK (%s assertions, offline, rig tree only)\n' "$rigPassCount"
	exit 0
fi
printf '⛔ REVIEW ANSWER PLACE CHECK FAILED: %s of %s assertion(s)\n' "$rigFailCount" "$(( rigPassCount + rigFailCount ))"
exit 1
