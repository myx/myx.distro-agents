#!/usr/bin/env bash
## Behavioural check on a change held for approval (AgentsTools.InternOpChange.include, the
## gate and the write tools of AgentsUniversalHarness.sh, AgentsTools.Grants.include and its
## two awk programs, AgentsEscalationVerdict.awk, the escalation read,
## sh-lib/templates/change-approve.post.format.md). A grant can say `approve` for a place: an
## Edit or a Write such a grant covers is neither refused nor applied, unless a grant given
## for the task, the session or the one call allows it. Its change is kept, shown to the
## human-owner by the team bot, and applied when he approves, exactly as it was shown. Covers:
##    0. the template: the two posts of the prompt, the prompt that takes no answer any more, its
##       emoji, and the one post a prompt was before its change moved to its thread;
##    1. held: the call returns at once, the file as it was, the change kept, the prompt posted
##       by the team bot in its conversation with the human-owner, its record in the session's
##       Wait; what the grant does not cover is refused as before, and a read is admitted;
##    2. shown, in two posts: the message that opens the thread, a few lines -- who asks, the
##       file by its place name, what for, how to answer -- and the first reply there, the
##       change as a diff, the task in words, the session, who asked;
##    3. approved by click: applied as shown, once, and said in the prompt's thread; with the
##       answered mark the tooling's own click answers leave the prompt, and its How to answer;
##    4. rejected: dropped, the prompt closed as the post of a discarded permission set is;
##    5. a reply with words: back to the member as RETURNED with his whole text, the change
##       still held; then approved by reply, his words with it;
##    6. the file changed meanwhile: elsewhere, and the kept edits still fit; where an edit no
##       longer fits, nothing is applied and the member is told to make the change again; and
##       an approve that cannot be applied this time stays, and is applied at the next read;
##    7. a long change: shown cut, the line that says how much is not shown and where the
##       whole diff is kept;
##    8. the session ended: at its own end, and found gone at a read;
##    9. two held changes to one file by one member: two prompts, each applied by its own
##       verdict, and one that no longer fits after the other;
##   10. taken back by its asker;
##   11. Write: a file rewritten, a file created, a rewrite over a file that changed;
##   12. only his own verdict, in his own words: another account, a member through the team
##       operation, a plain agreement;
##   13. the call of a native client's own tool, put by its permission hook;
##   14. a prompt that could not be posted, or not whole: nothing is held, and what was posted of
##       it is taken away again;
##   15. what the member holds, and what its grants list says;
##   16. the first use: the librarian's standing access to the skills of the team;
##   17. what comes ahead of an approval: a grant given for the task, and nothing the member
##       holds standing or by the floor, its own directory neither;
##   18. a prompt posted before its change moved to its thread, one post that holds the change:
##       read, answered, confirmed and closed as it was;
##   19. the asking session's Wait after an answer by click: the tooling's own emoji leaving the
##       prompt is no arrival, and only what he writes there after is.
## Red recipe: leave the `approve)` row out of AgentsToolsGrantsSessionCheckRows
## (AgentsTools.Grants.include), and section 1 fails on its first call, refused.
## Offline: a Slack-shaped fake curl is first on PATH, and a ps beside it lists the rig's own
## runs only; every scenario has its own workspace, HOME, board and Slack under this check's
## temp tree, guarded on every call. Never the live team data or .local/agents.
set -u
: "${MDLT_ORIGIN:?⛔ ERROR: MDLT_ORIGIN is not set}"
rigFn="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"
rigLib="$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib"
rigHarness="$rigLib/harness/AgentsUniversalHarness.sh"
rigFixture="$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/change-approval.curl.stub.sh"
rigTemplate="$rigLib/templates/change-approve.post.format.md"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigFn" ] || rigRefuse "dispatcher not found: $rigFn"
[ -f "$rigHarness" ] || rigRefuse "harness not found: $rigHarness"
[ -f "$rigFixture" ] || rigRefuse "the fake curl fixture is missing: $rigFixture"
## A process this rig starts and signals later is noted with when it began, and is signalled only while its pid is still that process.
. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-test/check-fixtures/rig-processes.include.sh" || rigRefuse "the rig's process helper is missing from the package: sh-test/check-fixtures/rig-processes.include.sh"
. "${MDLT_ORIGIN:-$MMDAPP/.local}/myx/myx.distro-agents/sh-test/check-fixtures/rig-temp.include.sh" || exit 1
rigTmp="$( rigTempDir AgentsChangeApprovalCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
rigLivePids=""
trap 'rigProcSignalWithChildren TERM $rigLivePids ; chmod -R u+w "$rigTmp" 2> /dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
cp "$rigFixture" "$rigTmp/bin/curl" && chmod +x "$rigTmp/bin/curl" || rigRefuse "could not install the fake curl"
## THE RIG'S OWN PROCESS LIST. Whether a session runs is read off a process list of the host
## (ps -A). A rig that read the real one would take whatever command line of this host holds
## one of its ids for a run of its own. So the ps first on PATH answers the whole-host listing
## from the rig's own list, one `<pid> <command line>` line a process, each a stand-in process
## of this rig listed only while it lives, and hands every other call to the real ps.
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
## Every byte of a file, so a newline shows as \n and nothing is trimmed.
rigBytes(){ ## file
	[ -f "$1" ] || { printf 'MISSING' ; return 0 ; }
	od -An -c "$1" | tr -d ' \n'
}

## One scenario: its own workspace, HOME, board and Slack. The member that makes the changes
## is keeper-myx. Three places are its to write BY APPROVAL, as a registry row says them: the
## folder held/; a folder under .local/temp, which the floor lets every member write; and its
## own member directory, which every acting member writes.
rigName="" ; rigDir="" ; rigWs="" ; rigData="" ; rigSpawn="" ; rigItem="" ; rigMember="keeper-myx" ; rigPid=""
rigStart(){ ## scenario name
	local startMember
	rigName="$1" ; rigDir="$rigTmp/$1" ; rigWs="$rigDir/ws" ; rigData="$rigDir/data" ; rigMember="keeper-myx"
	rigSpawn="rig-run-$1" ; rigItem="dispatch-20261012T0100Z-$1"
	mkdir -p "$rigData/board/running" "$rigData/board/processed" "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned" \
		"$rigWs/held" "$rigWs/other" "$rigWs/.local/temp/held"
	printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\n' > "$rigWs/.local/.agents/magic-team.agent.env"
	printf 'SLACK_USER_TOKEN=rig-user-token-KEEPER\n' > "$rigWs/.local/.agents/keeper-myx.agent.env"
	for startMember in magic-coordinator keeper-myx magic-tester human-owner ; do
		mkdir -p "$rigWs/.local/agents/members/$startMember"
		printf -- '---\nname: %s\ndescription: rig member\n---\n' "$startMember" > "$rigWs/.local/agents/members/$startMember/SKILL.md"
		printf 'rig\n' > "$rigWs/.local/agents/members/$startMember/$startMember.basic.md"
	done
	printf 'keeper-myx:ws:directory:approve:Edit(/%s/held/**)\nkeeper-myx:ws:directory:approve:Edit(/%s/.local/temp/held/**)\nkeeper-myx:ws:directory:approve:Edit(/%s/.local/agents/members/keeper-myx/**)\nkeeper-myx:ws:member:Edit(/%s/.local/agents/members/keeper-myx/**)\n' \
		"$rigWs" "$rigWs" "$rigWs" "$rigWs" > "$rigWs/.local/agents/permissions.registry"
	## The workspace is a registered place, so a path in it is shown by its place name.
	printf '%s\t%s\t%s\t%s\t%s\n' rig-ws workspace read-write "$rigWs" workspace > "$rigWs/.local/agents/directories.registry"
	printf 'alpha\nbeta\ngamma\ndelta\n' > "$rigWs/held/notes.md"
	printf 'alpha\nbeta\n' > "$rigWs/other/notes.md"
	printf 'alpha\nbeta\n' > "$rigWs/.local/temp/held/notes.md"
	: > "$rigDir/curl.log"
	## The work of the session: a task, the dispatch that tracks it, its spawn record, and a
	## stand-in process, so that session is live.
	printf -- '---\ntype: task\nowner: keeper-myx\n---\n\n# Rework the rig widget\n\nThe widget drops its last line. Make it keep it.\n' > "$rigData/board/running/task-20261012T0000Z-$rigName.md"
	printf -- '---\ntype: dispatch\nowner: keeper-myx\nstatus: dispatch-started\nspawn-id: %s\ntracks: task-20261012T0000Z-%s\n---\n\n# rig dispatch\n' \
		"$rigSpawn" "$rigName" > "$rigData/board/running/$rigItem.md"
	mkdir -p "$rigWs/.local/agents/spawned/$rigSpawn" "$rigWs/.local/agents/sessions/$rigSpawn"
	printf -- '---\nsession-id: 5e55104a-rig-%s\nspawn-id: %s\nparent-spawn-id: none\ntracking-name: %s\nhost: %s\nowner: keeper-myx\nstatus: spawn-started\nsession-thread: CSES00001:1700000000.000100\nspawns: %s\ndescription: rework the rig widget\n---\n' \
		"$rigName" "$rigSpawn" "$rigSpawn" "$rigHost" "$rigItem" > "$rigWs/.local/agents/spawned/$rigSpawn/$rigSpawn.md"
	bash -c 'sleep 600 ; :' "$rigSpawn" > /dev/null 2>&1 < /dev/null &
	rigPid="$!"
	rigLivePids="$rigLivePids $rigPid" ; rigProcNote "$rigPid"
	printf '%s rig-run --session-id %s\n' "$rigPid" "$rigSpawn" >> "$rigTmp/ps.list"
	disown "$rigPid" 2> /dev/null || :
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
## As the session that makes the changes: its member and its spawn id.
rigAsRun(){ ## result file, DistroAgentsTools.fn.sh args...
	rigEnv=( MDAT_SPAWN_AGENT="$rigMember" MDAT_SPAWN_SESSION_ID="$rigSpawn" )
	rigOp "$@"
	rigEnv=()
}
rigTool(){ ## result file, tool name, arguments JSON -- one served harness tool call of that session
	printf '%s\n' "$3" > "$rigDir/tool.args"
	rigEnv=( MDAT_SPAWN_AGENT="$rigMember" MDAT_SPAWN_SESSION_ID="$rigSpawn" )
	rigRun "$1" bash -c 'exec bash "$0" --intern-tool "$1" < "$2"' "$rigHarness" "$2" "$rigDir/tool.args"
	rigEnv=()
}
rigEdit(){ ## result name, file, old, new, [description] -- one Edit, its texts JSON strings as given
	rigTool "$rigDir/$1" Edit '{"file_path":"'"$2"'","old_string":"'"$3"'","new_string":"'"$4"'"'"${5:+,\"description\":\"$5\"}"'}'
}
rigFirst(){ ## result name -- the first line of the tool's own result
	LC_ALL=C grep -m1 -E '^(HELD|OK|ERROR|STALE|NOT-HELD): ' "$rigDir/$1" 2> /dev/null || printf 'no-result-line'
}
rigPosts(){ cat "$rigDir/posts" 2> /dev/null || printf '0' ; }
## The pending-reply records of the scenario, in the order their prompts were posted, and
## the n-th of them. Never by file time: a record that closes is written again.
rigRecords(){
	local recordFile
	for recordFile in "$rigWs/.local/agents/pending"/*.md ; do
		[ -f "$recordFile" ] || continue
		printf '%s\t%s\n' "$( LC_ALL=C sed -n 's/^question-ts: //p' "$recordFile" | head -1 )" "$recordFile"
	done | LC_ALL=C sort | LC_ALL=C cut -f2-
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
## The folder of the kept change a record's prompt shows.
rigKeptDir(){ ## record n (default: the newest)
	local keptMeta
	for keptMeta in "$rigWs/.local/agents/sessions/$rigSpawn/changes"/*/change ; do
		[ -f "$keptMeta" ] && LC_ALL=C grep -q -x -F "ask: $( rigId "${1:-}" )" "$keptMeta" && { printf '%s' "${keptMeta%/change}" ; return 0 ; }
	done
	printf 'no-kept-change'
}
## The prompt's own thread as Slack returns it: the prompt with the reactions a scenario puts
## on it, then the replies. The tooling's own two emoji, placed by the bot, are always there,
## and so is its own reply under the prompt, the change: the post right after the prompt, by
## the bot, its sender the member (rigThreadOwn, emptied for a prompt that has no such reply).
rigSeeded='{"name":"+1","count":1,"users":["URIGBOT01"]},{"name":"x","count":1,"users":["URIGBOT01"]}'
rigClick(){ ## emoji name, user
	printf ',{"name":"%s","count":1,"users":["%s"]}' "$1" "$2"
}
rigReply(){ ## ts suffix (after the prompt's), user, text as a JSON string body, record n
	printf ',{"ts":"1700000001.%s","user":"%s","text":"%s","thread_ts":"%s"}' "$1" "$2" "$3" "$( rigField question-ts "${4:-}" )"
}
rigThreadOwn=1
rigThread(){ ## clicks (rigClick words, may be empty), replies (rigReply words, may be empty), record n
	local threadTs threadOwn=""
	threadTs="$( rigField question-ts "${3:-}" )"
	[ -z "$rigThreadOwn" ] || threadOwn="$( printf ',{"ts":"1700000001.%06d","user":"URIGBOT01","text":"**📝 The change**\\n```\\n-beta\\n+BETA\\n```","thread_ts":"%s","metadata":{"event_type":"magic_sender","event_payload":{"sender":"%s"}}}' \
		"$(( 10#${threadTs#*.} + 100 ))" "$threadTs" "$rigMember" )"
	printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGBOT01","text":"the prompt","reactions":[%s%s]}%s%s],"has_more":false}\n' \
		"$threadTs" "$rigSeeded" "$1" "$threadOwn" "$2" > "$rigDir/replies.$threadTs.json"
}
## The read of the prompt's answer, as the Wait of the session that made the change makes it.
rigRead(){ ## record n (default: the newest)
	rigAsRun "$rigDir/read" --intern-op-escalation-read "$rigMember" "$( rigId "${1:-}" )"
}
rigReadLine(){ ## prefix -- the first line of the read with it
	LC_ALL=C grep -m1 "^$1" "$rigDir/read" 2> /dev/null || printf 'no-such-line'
}
## The emoji placed on, or taken off, a prompt: their names in the order asked for.
rigReacted(){ ## reactions|reactions.removed, record n
	LC_ALL=C awk -v want="$( rigField question-ts "${2:-}" )" '$1 == want { out = out ( out == "" ? "" : " " ) $2 ; } END { print out ; }' "$rigDir/$1" 2> /dev/null
}
## The lines of a record's `.fields`, as the operation packs them.
rigPack(){ ## slot, value, ...
	local packValue
	while [ $# -ge 2 ] ; do
		if [ -n "$2" ] ; then
			packValue="${2//\\/\\\\}"
			printf '%s\t%s\n' "$1" "${packValue//$'\n'/\\n}"
		fi
		shift 2
	done
}
## What a reminder of a prompt quotes of it (AgentsTools.PendingReplyRemind.include).
rigRemindQuote(){ ## record n (default: the newest)
	rigRun "$rigDir/remind-quote" bash -c '. "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/questions/AgentsTools.PendingReplyRemind.include" && AgentsToolsPendingReplyRemindQuestion "$1"' rig-remind "$( rigRecord "${1:-}" )"
	cat "$rigDir/remind-quote"
}
rigFill(){ ## want -- the template filled straight, the slots from the caller's environment
	ASKP_WANT="$1" ASKP_FORM=approve LC_ALL=C awk -f "$MDLT_ORIGIN/myx/myx.distro-agents/sh-lib/comms/AgentsToolingTemplateFill.awk" -f "$rigLib/questions/AgentsAskPostFill.awk" "$rigTemplate" 2>&1
}
rigWaitSet(){ ## record n -- 1 while that prompt is in the Wait set of the session
	LC_ALL=C sed -n 's/^sources: //p' "$rigWs/.local/agents/sessions/$rigSpawn/wait/state" 2> /dev/null | LC_ALL=C grep -c -F "ask:$( rigId "${1:-}" )"
}
rigHeldLine(){ ## file -- the first line of a held result for it
	printf 'HELD: this change to %s is held for the approval of the human-owner, and nothing is written yet. It is shown to him as a diff, and is applied exactly as shown when he approves.' "$1"
}

echo "-- 0. the template: the two posts of the prompt, the prompt that takes no answer any more, its emoji --"
rigHow=$'**✅ How to answer**\n- click 👍 to approve: the change is then applied exactly as shown. Or click ❌ to reject it\n- or reply `approve` or `reject`\n- the word first; a comment after a comma, or on the next lines\n- any other reply is a comment: it goes back to the member that asked, and the change stays held'
rigAssert "the message that opens the thread, whole: who asks, the file, what it is for, how to answer" \
	"$( ASKP_F_member=keeper-myx ASKP_F_act=change ASKP_F_file='ws:held/notes.md' ASKP_F_purpose='Raise a word' rigFill post )" \
	$'# ✏️ Change for approval\n\nkeeper-myx wants to change `ws:held/notes.md`.\n\n**💡 What it is for**\nRaise a word\n\n'"$rigHow"
rigAssert "with no purpose its heading is left out" \
	"$( ASKP_F_member=keeper-myx ASKP_F_act=change ASKP_F_file='ws:held/notes.md' rigFill post )" \
	$'# ✏️ Change for approval\n\nkeeper-myx wants to change `ws:held/notes.md`.\n\n'"$rigHow"
rigAssert "with no file nothing is filled" \
	"$( ASKP_F_member=keeper-myx ASKP_F_act=change rigFill post )" "AgentsAskPostFill.awk: the slot {{file}} is required and has no value"
rigAssert "the first reply in its thread, whole: the change, the task, the session, who asked" \
	"$( ASKP_BLOCK='Skeleton/detail' ASKP_F_task='The task' ASKP_F_session='`5e55104a`' ASKP_F_asked_by='keeper-myx · host / ws' ASKP_F_fence='```' ASKP_F_diff=$'@@ -1 +1 @@\n-a\n+b' rigFill block )" \
	$'**📝 The change**\n```\n@@ -1 +1 @@\n-a\n+b\n```\n\n**🗂 Task**\nThe task\n\n**🧵 Session**\n`5e55104a`\n\n**🙋 Asked by**\nkeeper-myx · host / ws'
rigAssert "there a field with no value leaves its heading out, and a cut says so under the diff" \
	"$( ASKP_BLOCK='Skeleton/detail' ASKP_F_asked_by='keeper-myx' ASKP_F_fence='```' ASKP_F_diff=$'@@ -1 +1 @@\n-a\n+b' ASKP_F_cut='CUT LINE' rigFill block )" \
	$'**📝 The change**\n```\n@@ -1 +1 @@\n-a\n+b\n```\nCUT LINE\n\n**🙋 Asked by**\nkeeper-myx'
rigAssert "a prompt that takes no answer any more: its first post's same text without How to answer" \
	"$( ASKP_F_member=keeper-myx ASKP_F_act=change ASKP_F_file='ws:held/notes.md' ASKP_F_purpose='Raise a word' rigFill closed )" \
	$'# ✏️ Change for approval\n\nkeeper-myx wants to change `ws:held/notes.md`.\n\n**💡 What it is for**\nRaise a word'
## A prompt posted before its change moved to its thread was one post: what its record keeps
## holds the diff, and filled from that it is the post it was.
rigWhole=$'# ✏️ Change for approval\n\nkeeper-myx wants to change `ws:held/notes.md`.\n\n**💡 What it is for**\nRaise a word\n\n**🗂 Task**\nThe task\n\n**🧵 Session**\n`5e55104a`\n\n**🙋 Asked by**\nkeeper-myx · host / ws\n\n**📝 The change**\n```\n@@ -1 +1 @@\n-a\n+b\n```'
rigAssert "a prompt posted before the two, filled with its diff: the one post it was, whole" \
	"$( ASKP_F_member=keeper-myx ASKP_F_act=change ASKP_F_file='ws:held/notes.md' ASKP_F_purpose='Raise a word' ASKP_F_task='The task' ASKP_F_session='`5e55104a`' ASKP_F_asked_by='keeper-myx · host / ws' ASKP_F_fence='```' ASKP_F_diff=$'@@ -1 +1 @@\n-a\n+b' rigFill post )" \
	"$rigWhole"$'\n\n'"$rigHow"
rigAssert "and once it takes no answer: that one post without How to answer, its change and its cut line still in it" \
	"$( ASKP_F_member=keeper-myx ASKP_F_act=change ASKP_F_file='ws:held/notes.md' ASKP_F_purpose='Raise a word' ASKP_F_task='The task' ASKP_F_session='`5e55104a`' ASKP_F_asked_by='keeper-myx · host / ws' ASKP_F_fence='```' ASKP_F_diff=$'@@ -1 +1 @@\n-a\n+b' ASKP_F_cut='CUT LINE' rigFill closed )" \
	"$rigWhole"$'\nCUT LINE'
rigAssert "its click answers, and neither the mark of an answered question" "$( rigFill reactions | LC_ALL=C tr '\n' ' ' )" "+1 x "
rigAssert "the cut line" "$( ASKP_BLOCK='Lines/cut' ASKP_F_hidden=124 ASKP_F_total=184 ASKP_F_diff_file='ws:.local/x/change.diff' rigFill block )" \
	'✂️ The diff is cut here: 124 more of its 184 lines are not shown. The whole diff is kept in `ws:.local/x/change.diff`.'

echo "-- 1. held: the call returns at once, nothing is written, the change is kept and shown --"
rigStart held
rigEdit edit "$rigWs/held/notes.md" beta BETA "Raise the second word"
rigAssert "the Edit is held, and says so in a plain line" "$( rigFirst edit )" "$( rigHeldLine "$rigWs/held/notes.md" )"
rigAssert "nothing is written: the file is byte for byte as it was" "$( rigBytes "$rigWs/held/notes.md" )" 'alpha\nbeta\ngamma\ndelta\n'
rigAssert "the result says a read sees the file as it is, how the verdict arrives, and how to take the change back" \
	"$( rigHas "$rigDir/edit" 'a Read of it shows the file as it is now, without this change.' ):$( rigHas "$rigDir/edit" "His verdict comes to you on Wait, as pending reply $( rigId )" ):$( rigHas "$rigDir/edit" "AskQuestion pending_id=$( rigId ) withdraw=<why>" ):$( LC_ALL=C grep -c -x -F "WAIT-ID: ask:$( rigId )" "$rigDir/edit" )" "yes:yes:yes:1"
rigAssert "it is no refusal and no error: the call ends well, nothing is recorded to ask for" "$( cat "$rigDir/edit.rc" ):$( LC_ALL=C grep -c 'REFUSAL-ID' "$rigDir/edit" )" "0:0"
rigAssert "two posts, by the team bot: the first a message of its own in its conversation with the human-owner, addressed to him" \
	"$( rigPosts ):$( cat "$rigDir/post.1.token" 2> /dev/null ):$( LC_ALL=C grep -c '"channel": *"URIGOWNER"' "$rigDir/post.1" 2> /dev/null ):$( rigHas "$rigDir/post.1" '<@URIGOWNER>' ):$( rigHas "$rigDir/post.1" '"thread_ts"' )" "2:rig-bot-token-TEAM:1:yes:no"
rigAssert "its record: a change, asked of the human-owner by the member that made it, for its session and item" \
	"$( rigRecordCount ):$( rigField kind ):$( rigField address-to ):$( rigField owner ):$( rigField session-id ):$( rigField item ):$( rigField ask-identity ):$( rigField status )" \
	"1:change:human-owner:keeper-myx:$rigSpawn:$rigItem:bot:reply-pending"
rigAssert "which names its thread, who may answer and who asked, so it is reminded and read as every ask is" \
	"$( rigField channel ):$( rigField question-ts ):$( rigField thread-ts ):$( rigField addressees ):$( rigField asking-accounts | LC_ALL=C tr -d ' ' )" \
	"CRIG00001:1700000001.000101:1700000001.000101:URIGOWNER:URIGBOT01"
rigAssert "the second is the first reply in the thread the first opens, addressed to him too" \
	"$( cat "$rigDir/post.2.token" 2> /dev/null ):$( rigHas "$rigDir/post.2" "\"thread_ts\":\"$( rigField question-ts )\"" ):$( rigHas "$rigDir/post.2" '<@URIGOWNER>' )" "rig-bot-token-TEAM:yes:yes"
rigAssert "its click answers are placed under the first, and none under the reply" \
	"$( rigReacted reactions ):$( LC_ALL=C awk -v want="$( rigField question-ts )" '$1 != want { other++ ; } END { print other + 0 ; }' "$rigDir/reactions" 2> /dev/null )" "+1 x:0"
rigAssert "what is kept of the first post beside its record is what it was filled with, and no diff" \
	"$( LC_ALL=C cut -f1 "$rigWs/.local/agents/pending/$( rigId ).fields" 2> /dev/null | LC_ALL=C tr '\n' ' ' )" "member act file purpose "
rigAssert "it is in the Wait of the session that made the change" "$( rigWaitSet )" 1
rigKept="$( rigKeptDir )"
rigAssert "the change is kept in the store of that session: the call, the file as it was, the file as the call leaves it, the diff" \
	"$( ls "$rigKept" 2> /dev/null | LC_ALL=C sort | LC_ALL=C tr '\n' ' ' ):$( rigBytes "$rigKept/base" ):$( rigBytes "$rigKept/result" )" 'base call.json change change.diff result :alpha\nbeta\ngamma\ndelta\n:alpha\nBETA\ngamma\ndelta\n'
rigAssert "with who, the tool, the file and what its edit matched" \
	"$( LC_ALL=C grep -c -x -e 'owner: keeper-myx' -e "session-id: $rigSpawn" -e 'tool: Edit' -e "file: $rigWs/held/notes.md" -e 'matched: 1' "$rigKept/change" 2> /dev/null )" 5
rigTool "$rigDir/readfile" Read '{"file_path":"'"$rigWs/held/notes.md"'"}'
rigAssert "a later Read of the file sees it as it is, not the held change" "$( rigHas "$rigDir/readfile" beta ):$( rigHas "$rigDir/readfile" BETA )" "yes:no"
rigEdit other "$rigWs/other/notes.md" beta BETA
rigAssert "a file no grant covers is refused as before, with its refusal id" "$( LC_ALL=C grep -c -e '^ERROR: path not in the allowed write-root set' -e '^REFUSAL-ID: refusal-' "$rigDir/other" ):$( rigRecordCount )" "2:1"
rigEdit missing "$rigWs/held/notes.md" nope NOPE
rigAssert "a call that cannot be applied is refused at once, in the tool's own words, and nothing is held" \
	"$( rigFirst missing ):$( rigRecordCount ):$( rigPosts )" "ERROR: old_string not found in $rigWs/held/notes.md -- nothing was written:1:2"
rigEdit same "$rigWs/held/notes.md" beta beta
rigAssert "a call that leaves the file as it is has nothing to hold" "$( rigFirst same ):$( rigRecordCount )" "OK: nothing is held or written: this call leaves $rigWs/held/notes.md exactly as it is:1"

echo "-- 2. shown: who asks, what for, the task in words, the session, the file by its place name, the diff --"
rigPlace="$( rigPromptBody | LC_ALL=C sed -n 's/^keeper-myx wants to change `\(.*\)`\.$/\1/p' )"
rigAssert "the file is shown by its place name, never by its absolute path" "$rigPlace:$( rigPromptBody | LC_ALL=C grep -c -F "$rigWs/held" )" "rig-ws:held/notes.md:0"
rigShownFirst=$'# ✏️ Change for approval\n\nkeeper-myx wants to change `rig-ws:held/notes.md`.\n\n**💡 What it is for**\nRaise the second word\n\n'"$rigHow"
rigShownReply=$'**📝 The change**\n```\n@@ -1,4 +1,4 @@\n alpha\n-beta\n+BETA\n gamma\n delta\n```\n\n**🗂 Task**\nRework the rig widget\n`task-20261012T0000Z-held` · `dispatch-20261012T0100Z-held`\nThe widget drops its last line. Make it keep it.\n\n**🧵 Session**\nrework the rig widget · `5e55104a` · `CSES00001:1700000000.000100`\n\n**🙋 Asked by**\nkeeper-myx · '"$rigHost"' / ws'
rigAssert "the record keeps the two posts as they were shown: the message that opens the thread, then the change" "$( rigPromptBody )" "$rigShownFirst"$'\n\n'"$rigShownReply"
rigAssert "the first post is the few lines: what it is for and how to answer, and no diff, task, session or asker block" \
	"$( rigHas "$rigDir/post.1" 'What it is for' ):$( rigHas "$rigDir/post.1" 'How to answer' ):$( rigHas "$rigDir/post.1" '@@ -1,4 +1,4 @@' ):$( rigHas "$rigDir/post.1" 'The change' ):$( rigHas "$rigDir/post.1" 'rig widget' ):$( rigHas "$rigDir/post.1" 'Session' ):$( rigHas "$rigDir/post.1" 'Asked by' )" "yes:yes:no:no:no:no:no"
rigAssert "the reply under it holds the change, the task, the session and who asked, and no How to answer" \
	"$( rigHas "$rigDir/post.2" '@@ -1,4 +1,4 @@' ):$( rigHas "$rigDir/post.2" '+BETA' ):$( rigHas "$rigDir/post.2" 'Rework the rig widget' ):$( rigHas "$rigDir/post.2" '5e55104a' ):$( rigHas "$rigDir/post.2" 'Asked by' ):$( rigHas "$rigDir/post.2" 'How to answer' )" "yes:yes:yes:yes:yes:no"
rigAssert "a reminder quotes the line it always did" "$( rigRemindQuote )" 'keeper-myx wants to change `rig-ws:held/notes.md`.'
rigAssert "the kept diff is the diff shown" "$( cat "$rigKept/change.diff" 2> /dev/null )" $'@@ -1,4 +1,4 @@\n alpha\n-beta\n+BETA\n gamma\n delta'

echo "-- 3. approved by click: applied as shown, once, and said in the prompt's thread --"
rigThread "" ""
rigRead
rigAssert "the emoji the tooling placed, and its own reply under the prompt, are no answer" "$( rigReadLine 'ESCALATION: ' ):$( rigField status ):$( rigBytes "$rigWs/held/notes.md" )" "ESCALATION: $( rigId ) open:reply-pending:alpha\\nbeta\\ngamma\\ndelta\\n"
rigThread "" "$( rigReply 000250 URIGBOT01 'approve' )"
rigRead
rigAssert "nor is any reply of the identity that posted, whatever it says" "$( rigReadLine 'ESCALATION: ' ):$( rigField status ):$( rigBytes "$rigWs/held/notes.md" )" "ESCALATION: $( rigId ) open:reply-pending:alpha\\nbeta\\ngamma\\ndelta\\n"
rigThread "$( rigClick +1 URIGOWNER )" ""
rigRead
rigAssert "his 👍 is read as approve, and the change is applied" "$( rigReadLine 'ESCALATION: ' ):$( rigReadLine 'VERDICT: ' ):$( rigReadLine 'ANSWERED-BY: ' ):$( rigReadLine 'CHANGE: ' )" \
	"ESCALATION: $( rigId ) answered:VERDICT: approve:ANSWERED-BY: URIGOWNER:CHANGE: applied -- OK: replaced one occurrence in $rigWs/held/notes.md"
rigAssert "the file is the file as it was shown" "$( rigBytes "$rigWs/held/notes.md" ):$( cmp -s "$rigWs/held/notes.md" "$rigKept/result" && printf same )" 'alpha\nBETA\ngamma\ndelta\n:same'
rigAssert "the record closes with the verdict, who gave it and what was done" "$( rigField status ):$( rigField verdict ):$( rigField answered-by ):$( rigField change-outcome )" \
	"reply-received:approve:URIGOWNER:applied -- OK: replaced one occurrence in $rigWs/held/notes.md"
rigAssert "one confirmation reply under the prompt, by the team bot: what was read and what was done" \
	"$( rigPosts ):$( cat "$rigDir/post.3.token" 2> /dev/null ):$( LC_ALL=C grep -c -F 'Read: `approve` by human-owner. The change is applied to `rig-ws:held/notes.md`, exactly as shown.' "$rigDir/post.3" 2> /dev/null ):$( rigHas "$rigDir/post.3" "\"thread_ts\":\"$( rigField question-ts )\"" )" "3:rig-bot-token-TEAM:1:yes"
rigAssert "with the answered mark the tooling takes its own click answers off the prompt, and puts no cancelled mark on it" \
	"$( rigReacted reactions.removed ):$( rigReacted reactions )" "+1 x:+1 x white_check_mark"
rigAssert "and the prompt is edited to its first post's text without How to answer, the reply under it left as it is" \
	"$( LC_ALL=C tr '\n' ' ' < "$rigDir/edited" ):$( rigHas "$rigDir/edit.$( rigField question-ts )" 'wants to change' ):$( rigHas "$rigDir/edit.$( rigField question-ts )" 'Raise the second word' ):$( rigHas "$rigDir/edit.$( rigField question-ts )" 'How to answer' ):$( rigHas "$rigDir/edit.$( rigField question-ts )" '@@ -1,4 +1,4 @@' )" "$( rigField question-ts ) :yes:yes:no:no"
rigAssert "the item's Decisions hold the verdict" "$( LC_ALL=C grep -c -F -- "-> approve" "$rigData/board/running/$rigItem.md" )" 1
rigRead
rigAssert "a second read reports the same, and applies, says, takes off and edits nothing again" "$( rigReadLine 'VERDICT: ' ):$( rigReadLine 'CHANGE: ' ):$( rigPosts ):$( rigBytes "$rigWs/held/notes.md" ):$( rigReacted reactions.removed ):$( LC_ALL=C awk 'END { print NR + 0 ; }' "$rigDir/edited" )" \
	"VERDICT: approve:CHANGE: applied -- OK: replaced one occurrence in $rigWs/held/notes.md:3:alpha\\nBETA\\ngamma\\ndelta\\n:+1 x:1"

echo "-- 4. rejected: dropped, nothing applied, the prompt closed as the post of a discarded permission set is --"
rigStart rejected
rigEdit edit "$rigWs/held/notes.md" beta BETA
rigThread "$( rigClick x URIGOWNER )" "$( rigReply 000250 URIGOWNER 'not this word' )"
rigRead
rigAssert "his ❌ is read as reject, and the change is dropped" "$( rigReadLine 'VERDICT: ' ):$( rigReadLine 'CHANGE: ' )" "VERDICT: reject:CHANGE: dropped -- rejected, so nothing is applied to rig-ws:held/notes.md"
rigAssert "what he wrote beside the click comes with it" "$( LC_ALL=C grep -c -F 'not this word' "$rigDir/read" )" 1
rigAssert "nothing is applied" "$( rigBytes "$rigWs/held/notes.md" ):$( rigField status ):$( rigField verdict )" 'alpha\nbeta\ngamma\ndelta\n:reply-received:reject'
rigAssert "its click answers are taken off, with the answered mark and as the prompt is closed, and it is marked" "$( rigReacted reactions.removed ):$( rigReacted reactions | LC_ALL=C awk '{ print $NF ; }' )" "+1 x +1 x:no_entry_sign"
rigAssert "its post is edited to the same text without How to answer" \
	"$( LC_ALL=C grep -c -F 'wants to change' "$rigDir/edit.$( rigField question-ts )" 2> /dev/null ):$( LC_ALL=C grep -c -F 'How to answer' "$rigDir/edit.$( rigField question-ts )" 2> /dev/null )" "1:0"
rigAssert "the reply under it, the change, is left as it is: the first post alone is edited, and nothing is deleted" \
	"$( LC_ALL=C sort -u "$rigDir/edited" | LC_ALL=C tr '\n' ' ' ):$( [ -f "$rigDir/deleted" ] && printf deleted || printf none )" "$( rigField question-ts ) :none"
rigAssert "and its thread is told what was read" "$( LC_ALL=C grep -l -F 'Read: `reject` by human-owner. The change is dropped: nothing is applied to `rig-ws:held/notes.md`.' "$rigDir"/post.[0-9] 2> /dev/null | LC_ALL=C awk 'END { print NR + 0 ; }' )" 1
rigThread "$( rigClick +1 URIGOWNER )" ""
rigRead
rigAssert "an approve under it afterwards applies nothing" "$( rigReadLine 'VERDICT: ' ):$( rigBytes "$rigWs/held/notes.md" )" 'VERDICT: reject:alpha\nbeta\ngamma\ndelta\n'

echo "-- 5. a reply with words: back to the member as RETURNED with his whole text; then approved by reply --"
rigStart words
rigEdit edit "$rigWs/held/notes.md" beta BETA
rigThread "" "$( rigReply 000250 URIGOWNER 'why BETA and not Beta? it shouts' )"
rigTool "$rigDir/wait1" Wait '{"timeout":30}'
rigAssert "his reply arrives on the member's Wait as RETURNED, with his whole text" \
	"$( LC_ALL=C grep -c -x -e 'ASK-RESULT: RECEIVED' -e 'VERDICT: RETURNED' "$rigDir/wait1" ):$( rigHas "$rigDir/wait1" 'why BETA and not Beta? it shouts' )" "2:yes"
rigAssert "with what it is and the ways on, each with its call" \
	"$( rigHas "$rigDir/wait1" 'This is the approval prompt of a change you made, which is held.' ):$( rigHas "$rigDir/wait1" "SendMessage to=CRIG00001:$( rigField question-ts )" ):$( rigHas "$rigDir/wait1" "AskQuestion pending_id=$( rigId ) withdraw=<why>" )" "yes:yes:yes"
rigAssert "the change stays held, nothing applied, and the prompt in its Wait" "$( rigField status ):$( rigBytes "$rigWs/held/notes.md" ):$( rigWaitSet )" 'reply-pending:alpha\nbeta\ngamma\ndelta\n:1'
rigThread "" "$( rigReply 000250 URIGOWNER 'why BETA and not Beta? it shouts' )$( rigReply 000260 URIGOWNER 'Approve: fine for now, soften it later' )"
rigTool "$rigDir/wait2" Wait '{"mode":"continue","timeout":30}'
rigAssert "his approve by reply arrives on the next Wait as the verdict, applied, his words with it" \
	"$( LC_ALL=C grep -c -x -e 'ASK-RESULT: RECEIVED' -e 'VERDICT: approve' -e 'VERDICT-TEXT: fine for now, soften it later' -e "CHANGE: applied -- OK: replaced one occurrence in $rigWs/held/notes.md" "$rigDir/wait2" )" 4
rigAssert "the file is changed, and the prompt has left the Wait of nothing more to hear but his later words" "$( rigBytes "$rigWs/held/notes.md" ):$( rigField status )" 'alpha\nBETA\ngamma\ndelta\n:reply-received'

echo "-- 6. the file changed meanwhile --"
rigStart moved
rigEdit edit "$rigWs/held/notes.md" beta BETA
printf 'alpha\nbeta\ngamma\ndelta\nepsilon\n' > "$rigWs/held/notes.md"
rigThread "$( rigClick +1 URIGOWNER )" ""
rigRead
rigAssert "changed elsewhere, the kept edit still fits exactly: applied, and the other change stays" "$( rigReadLine 'CHANGE: ' ):$( rigBytes "$rigWs/held/notes.md" )" \
	"CHANGE: applied -- OK: replaced one occurrence in $rigWs/held/notes.md:alpha\\nBETA\\ngamma\\ndelta\\nepsilon\\n"
rigStart stale
rigEdit edit "$rigWs/held/notes.md" beta BETA
printf 'alpha\nbeta two\ngamma\nbeta\n' > "$rigWs/held/notes.md"
rigThread "$( rigClick +1 URIGOWNER )" ""
rigRead
rigAssert "the kept edit no longer fits exactly: nothing is applied, and the member is told to make the change again" "$( rigReadLine 'VERDICT: ' ):$( rigReadLine 'CHANGE: ' )" \
	"VERDICT: approve:CHANGE: not-applied -- $rigWs/held/notes.md has changed since this change was shown: its old_string matched 1 place(s) then and matches 2 now, so nothing was written. Make the change again: it is held and shown to him anew."
rigAssert "the file is as the other change left it" "$( rigBytes "$rigWs/held/notes.md" )" 'alpha\nbetatwo\ngamma\nbeta\n'
rigAssert "the change is dropped: its record closed, its prompt closed and marked" "$( rigField status ):$( rigReacted reactions.removed ):$( rigReacted reactions | LC_ALL=C awk '{ print $NF ; }' )" "reply-received:+1 x +1 x:no_entry_sign"
rigAssert "and he is told his approve was not applied, why, and that the member makes the change again" "$( LC_ALL=C grep -l -F "Read: \`approve\` by human-owner, and the change is not applied to \`rig-ws:held/notes.md\`: $rigWs/held/notes.md has changed since this change was shown: its old_string matched 1 place(s) then and matches 2 now, so nothing was written. It is dropped, and keeper-myx is told to make it again: it is then shown to you anew." "$rigDir"/post.[0-9] 2> /dev/null | LC_ALL=C awk 'END { print NR + 0 ; }' )" 1
rigStart later
rigEdit edit "$rigWs/held/notes.md" beta BETA
chmod a-w "$rigWs/held"
rigThread "$( rigClick +1 URIGOWNER )" ""
rigRead
chmod u+w "$rigWs/held"
rigAssert "an approve that cannot be applied this time is not applied, and is not lost: the change stays held" "$( rigReadLine 'ESCALATION: ' ):$( rigReadLine 'VERDICT: ' ):$( rigField status ):$( rigBytes "$rigWs/held/notes.md" )" \
	"ESCALATION: $( rigId ) open:VERDICT: RETURNED:reply-pending:alpha\\nbeta\\ngamma\\ndelta\\n"
rigAssert "the member is told why, and so is he, once" "$( rigReadLine 'VERDICT-REASON: ' | LC_ALL=C sed 's/ time: ERROR: .*, so nothing/ time: ERROR, so nothing/' ):$( LC_ALL=C grep -l -F 'Read: `approve` by human-owner, and nothing is done with it yet: the approved change could not be applied this time: ERROR: ' "$rigDir"/post.[0-9] 2> /dev/null | LC_ALL=C awk 'END { print NR + 0 ; }' ):$( LC_ALL=C grep -h -c -F 'The change to `rig-ws:held/notes.md` stays held.' "$rigDir"/post.[0-9] 2> /dev/null | LC_ALL=C awk '{ total += $1 ; } END { print total + 0 ; }' )" \
	"VERDICT-REASON: the approved change could not be applied this time: ERROR, so nothing is done with that answer yet and the change stays held:1:1"
rigRead
rigAssert "the next read applies it: his approve still stands under the prompt" "$( rigReadLine 'CHANGE: ' ):$( rigBytes "$rigWs/held/notes.md" ):$( rigField status )" \
	"CHANGE: applied -- OK: replaced one occurrence in $rigWs/held/notes.md:alpha\\nBETA\\ngamma\\ndelta\\n:reply-received"
rigStart gone-edit
rigEdit edit "$rigWs/held/notes.md" beta BETA
printf 'alpha\ngamma\n' > "$rigWs/held/notes.md"
rigThread "$( rigClick +1 URIGOWNER )" ""
rigRead
rigAssert "the text it changes is gone: nothing is applied" "$( rigReadLine 'CHANGE: ' | LC_ALL=C cut -c1-21 ):$( rigBytes "$rigWs/held/notes.md" )" 'CHANGE: not-applied -:alpha\ngamma\n'

echo "-- 7. a long change: shown cut, with how much is not shown and where the whole diff is kept --"
rigStart long
LC_ALL=C awk 'BEGIN { for ( lineNo = 1 ; lineNo <= 200 ; lineNo++ ) { printf "line %d\n", lineNo ; } }' > "$rigWs/held/long.md"
rigLong="$( LC_ALL=C awk 'BEGIN { for ( lineNo = 1 ; lineNo <= 200 ; lineNo++ ) { printf "LINE %d\\n", lineNo ; } }' )"
rigTool "$rigDir/write" Write '{"file_path":"'"$rigWs/held/long.md"'","content":"'"$rigLong"'"}'
rigKept="$( rigKeptDir )"
rigAssert "the Write is held, and its result says how much of the diff is shown" "$( rigFirst write )" \
	"HELD: this change to $rigWs/held/long.md is held for the approval of the human-owner, and nothing is written yet. It is shown to him as a diff, the first 60 of its 401 lines, and is applied exactly as shown when he approves."
rigAssert "the prompt says it rewrites the file, and shows the first 60 lines of the diff" \
	"$( rigPromptBody | LC_ALL=C grep -c -x -F 'keeper-myx wants to rewrite the whole of `rig-ws:held/long.md`.' ):$( rigPromptBody | LC_ALL=C awk '$0 == "```" { inDiff = ! inDiff ; next ; } inDiff { lineCount++ ; } END { print lineCount + 0 ; }' )" "1:60"
rigAssert "then the plain line: how much is not shown, and where the whole diff is kept, by its place name" "$( rigPromptBody | LC_ALL=C grep -c -x -F "✂️ The diff is cut here: 341 more of its 401 lines are not shown. The whole diff is kept in \`rig-ws:.local/agents/sessions/$rigSpawn/changes/${rigKept##*/}/change.diff\`." )" 1
rigAssert "that line stands in the reply under the prompt, with the diff, and not in the first post" \
	"$( rigHas "$rigDir/post.2" 'The diff is cut here: 341 more of its 401 lines are not shown.' ):$( rigHas "$rigDir/post.1" 'The diff is cut here' )" "yes:no"
rigAssert "the whole diff is kept there" "$( LC_ALL=C awk 'END { print NR + 0 ; }' "$rigKept/change.diff" 2> /dev/null )" 401
rigThread "$( rigClick +1 URIGOWNER )" ""
rigRead
rigAssert "approved, the whole change is applied, not only what was shown" "$( rigReadLine 'CHANGE: ' ):$( LC_ALL=C grep -c '^LINE ' "$rigWs/held/long.md" )" "CHANGE: applied -- OK: wrote $rigWs/held/long.md:200"

echo "-- 8. the session ended: the held change is dropped --"
rigStart ended
rigEdit edit "$rigWs/held/notes.md" beta BETA
rigOp "$rigDir/collect" --intern-op-pending-reply-collect --session-id "$rigSpawn" --mark-ended --context rig
rigAssert "at the session's own end its held change is dropped, by the tooling, and said why" "$( LC_ALL=C grep -c "^DROPPED $( rigId ) " "$rigDir/collect" ):$( rigField status ):$( rigField withdrawn-by ):$( rigField withdraw-reason )" \
	"1:withdrawn:tooling:the session that made it has ended"
rigAssert "its prompt is closed and marked, and its thread told" \
	"$( rigReacted reactions.removed ):$( rigReacted reactions | LC_ALL=C awk '{ print $NF ; }' ):$( LC_ALL=C grep -c -F 'How to answer' "$rigDir/edit.$( rigField question-ts )" 2> /dev/null ):$( LC_ALL=C grep -l -F 'This change is dropped: the session that made it has ended. Nothing is applied, and the prompt above takes no answer any more.' "$rigDir"/post.[0-9] 2> /dev/null | LC_ALL=C awk 'END { print NR + 0 ; }' )" "+1 x:no_entry_sign:0:1"
rigThread "$( rigClick +1 URIGOWNER )" ""
rigRead
rigAssert "his approve afterwards applies nothing" "$( rigReadLine 'ESCALATION: ' ):$( rigBytes "$rigWs/held/notes.md" )" "ESCALATION: $( rigId ) closed withdrawn:alpha\\nbeta\\ngamma\\ndelta\\n"
rigStart died
rigEdit edit "$rigWs/held/notes.md" beta BETA
rigProcSignal TERM "$rigPid" ; wait "$rigPid" 2> /dev/null
rigThread "$( rigClick +1 URIGOWNER )" ""
rigRead
rigAssert "a session found gone when his approve is read: dropped, nothing applied" "$( rigReadLine 'ESCALATION: ' ):$( rigField status ):$( rigField withdraw-reason ):$( rigBytes "$rigWs/held/notes.md" )" \
	"ESCALATION: $( rigId ) closed withdrawn:withdrawn:the session that made it has ended:alpha\\nbeta\\ngamma\\ndelta\\n"

echo "-- 9. two held changes to one file by one member: two prompts, each by its own verdict --"
rigStart two
rigEdit edit1 "$rigWs/held/notes.md" beta BETA
rigEdit edit2 "$rigWs/held/notes.md" delta DELTA
rigAssert "each call is one change and one prompt, both held, the file as it was" "$( rigFirst edit1 | LC_ALL=C cut -c1-5 ):$( rigFirst edit2 | LC_ALL=C cut -c1-5 ):$( rigRecordCount ):$( rigPosts ):$( rigBytes "$rigWs/held/notes.md" )" 'HELD::HELD::2:4:alpha\nbeta\ngamma\ndelta\n'
rigAssert "the second is shown against the file as it is, without the first" "$( rigPromptBody 2 | LC_ALL=C grep -c -x -e ' beta' -e '-delta' -e '+DELTA' ):$( rigPromptBody 2 | LC_ALL=C grep -c -F BETA )" "3:0"
rigThread "$( rigClick +1 URIGOWNER )" "" 2
rigRead 2
rigAssert "the second approved first: applied, the first still held" "$( rigReadLine 'CHANGE: ' | LC_ALL=C cut -c1-17 ):$( rigBytes "$rigWs/held/notes.md" ):$( rigField status 1 )" 'CHANGE: applied -:alpha\nbeta\ngamma\nDELTA\n:reply-pending'
rigThread "$( rigClick +1 URIGOWNER )" "" 1
rigRead 1
rigAssert "then the first: its edit still fits exactly, so it is applied too" "$( rigReadLine 'CHANGE: ' | LC_ALL=C cut -c1-17 ):$( rigBytes "$rigWs/held/notes.md" ):$( rigField status 1 )" 'CHANGE: applied -:alpha\nBETA\ngamma\nDELTA\n:reply-received'
rigStart two-same
rigEdit edit1 "$rigWs/held/notes.md" beta BETA
rigEdit edit2 "$rigWs/held/notes.md" beta Beta
rigThread "$( rigClick +1 URIGOWNER )" "" 1
rigRead 1
rigThread "$( rigClick +1 URIGOWNER )" "" 2
rigRead 2
rigAssert "two changes of the same text: the first approved is applied, the other no longer fits and is not" "$( rigBytes "$rigWs/held/notes.md" ):$( rigField change-outcome 1 | LC_ALL=C cut -c1-7 ):$( rigField change-outcome 2 | LC_ALL=C cut -c1-11 )" 'alpha\nBETA\ngamma\ndelta\n:applied:not-applied'

echo "-- 10. taken back by its asker --"
rigStart withdrawn
rigEdit edit "$rigWs/held/notes.md" beta BETA
rigTool "$rigDir/withdraw" AskQuestion '{"pending_id":"'"$( rigId )"'","withdraw":"a better wording came up"}'
rigAssert "the asker takes its held change back with the call its result named" "$( LC_ALL=C grep -c -x 'ASK-RESULT: WITHDRAWN' "$rigDir/withdraw" ):$( rigField status ):$( rigField withdrawn-by )" "1:withdrawn:keeper-myx"
rigAssert "its prompt is closed and marked, and it has left the Wait" "$( rigReacted reactions.removed ):$( rigReacted reactions | LC_ALL=C awk '{ print $NF ; }' ):$( rigWaitSet )" "+1 x:no_entry_sign:0"
rigThread "$( rigClick +1 URIGOWNER )" ""
rigRead
rigAssert "his approve afterwards applies nothing" "$( rigReadLine 'ESCALATION: ' ):$( rigBytes "$rigWs/held/notes.md" )" "ESCALATION: $( rigId ) closed withdrawn:alpha\\nbeta\\ngamma\\ndelta\\n"

echo "-- 11. Write: a file rewritten, a file created, a rewrite over a file that changed --"
rigStart write
rigTool "$rigDir/create" Write '{"file_path":"'"$rigWs/held/deep/new.md"'","content":"one\ntwo\n","description":"A new note"}'
rigAssert "a Write of a file that is not there is held, and nothing is created, not its folder either" "$( rigFirst create ):$( [ -e "$rigWs/held/deep" ] && printf there || printf none )" "$( rigHeldLine "$rigWs/held/deep/new.md" ):none"
rigAssert "the prompt says it creates the file, and shows every line as added" "$( rigPromptBody | LC_ALL=C grep -c -x -e 'keeper-myx wants to create `rig-ws:held/deep/new.md`.' -e '@@ -0,0 +1,2 @@' -e '+one' -e '+two' )" 4
rigThread "" "$( rigReply 000250 URIGOWNER 'approved' )"
rigRead
rigAssert "approved, the file is created as shown" "$( rigReadLine 'CHANGE: ' ):$( rigBytes "$rigWs/held/deep/new.md" )" "CHANGE: applied -- OK: wrote $rigWs/held/deep/new.md:one\\ntwo\\n"
rigTool "$rigDir/rewrite" Write '{"file_path":"'"$rigWs/held/notes.md"'","content":"all new\n"}'
printf 'alpha\nbeta\ngamma\ndelta\nepsilon\n' > "$rigWs/held/notes.md"
rigThread "$( rigClick +1 URIGOWNER )" ""
rigRead
rigAssert "a rewrite over a file that changed since is not applied: it would undo a change he did not see" "$( rigReadLine 'CHANGE: ' ):$( rigBytes "$rigWs/held/notes.md" )" \
	"CHANGE: not-applied -- $rigWs/held/notes.md has changed since this change was shown, and a Write replaces the whole file, so nothing was written. Make the change again: it is held and shown to him anew.:alpha\\nbeta\\ngamma\\ndelta\\nepsilon\\n"

echo "-- 12. only his own verdict, in his own words --"
rigStart who
rigEdit edit "$rigWs/held/notes.md" beta BETA
rigThread "$( rigClick +1 URIGOTHER )" "$( rigReply 000250 URIGOTHER 'approve' )"
rigRead
rigAssert "a click and a reply by somebody else are no answer" "$( rigReadLine 'ESCALATION: ' ):$( rigField status ):$( rigBytes "$rigWs/held/notes.md" )" "ESCALATION: $( rigId ) open:reply-pending:alpha\\nbeta\\ngamma\\ndelta\\n"
rigEnv=( MDAT_SPAWN_AGENT=magic-coordinator MDAT_SPAWN_SESSION_ID=rig-other-session )
rigOp "$rigDir/answer" --magic-escalation-answer magic-coordinator "$( rigId )" approve
rigEnv=()
rigAssert "no member answers it through the team operation, the coordinator neither" "$( cat "$rigDir/answer.rc" ):$( LC_ALL=C grep -c -F 'approve is not a verdict of this change, so nothing is applied' "$rigDir/answer" ):$( rigField status ):$( rigBytes "$rigWs/held/notes.md" )" '1:1:reply-pending:alpha\nbeta\ngamma\ndelta\n'
rigThread "" "$( rigReply 000250 URIGOWNER 'ok, looks fine' )"
rigRead
rigAssert "a plain agreement approves nothing: it comes back as RETURNED" "$( rigReadLine 'VERDICT: ' ):$( rigField status ):$( rigBytes "$rigWs/held/notes.md" )" 'VERDICT: RETURNED:reply-pending:alpha\nbeta\ngamma\ndelta\n'
rigThread "" "$( rigReply 000250 URIGOWNER 'approve it if the tests pass' )"
rigRead
rigAssert "nor does the word with more words and no mark between: his line is a comment, whole" "$( rigReadLine 'VERDICT: ' ):$( rigField status ):$( rigBytes "$rigWs/held/notes.md" )" 'VERDICT: RETURNED:reply-pending:alpha\nbeta\ngamma\ndelta\n'
rigThread "$( rigClick +1 URIGOWNER )$( rigClick x URIGOWNER )" ""
rigRead
rigAssert "both clicked by him: reject first, never an approve" "$( rigReadLine 'VERDICT: ' ):$( rigBytes "$rigWs/held/notes.md" )" 'VERDICT: reject:alpha\nbeta\ngamma\ndelta\n'
rigStart word
rigEdit edit "$rigWs/held/notes.md" beta BETA
rigThread "" "$( rigReply 000250 URIGOWNER 'Rejected. Keep it lower case' )"
rigRead
rigAssert "reject by reply, in any case, his words with it" "$( rigReadLine 'VERDICT: ' ):$( rigReadLine 'VERDICT-TEXT: ' )" "VERDICT: reject:VERDICT-TEXT: Keep it lower case"
rigStart mark
rigEdit edit "$rigWs/held/notes.md" beta BETA
rigThread "$( rigClick white_check_mark URIGOWNER )" ""
rigRead
rigAssert "his own ✅ approves, as it does on a proposal" "$( rigReadLine 'VERDICT: ' ):$( rigBytes "$rigWs/held/notes.md" )" 'VERDICT: approve:alpha\nBETA\ngamma\ndelta\n'

echo "-- 13. the call of a native client's own tool, put by its permission hook --"
rigStart native
rigHook(){ ## result name, tool name, tool_input JSON
	printf '{"session_id":"%s","cwd":"%s","hook_event_name":"PermissionRequest","tool_name":"%s","tool_input":%s}' "$rigSpawn" "$rigWs" "$2" "$3" > "$rigDir/hook.in"
	rigEnv=( MDAT_SPAWN_AGENT="$rigMember" MDAT_SPAWN_SESSION_ID="$rigSpawn" )
	rigRun "$rigDir/$1" bash -c 'exec bash "$0" --intern-op-permission-hook "$1" < "$2"' "$rigFn" "$rigMember" "$rigDir/hook.in"
	rigEnv=()
}
rigHookSays(){ ## result name -- allow, or deny and the first words of its message
	LC_ALL=C sed -n -e 's/^.*"behavior":"allow".*$/allow/p' -e 's/^.*"behavior":"deny","message":"\([^ ]* [^ ]* [^ ]*\).*$/deny: \1/p' "$rigDir/$1" | head -1
}
rigHook hook1 Edit '{"file_path":"'"$rigWs/held/notes.md"'","old_string":"beta","new_string":"BETA"}'
rigAssert "the client's own Edit is denied, with the result that says its change is held" "$( rigHookSays hook1 ):$( rigRecordCount ):$( rigField kind ):$( rigBytes "$rigWs/held/notes.md" ):$( LC_ALL=C grep -c 'REFUSAL-ID' "$rigDir/hook1" )" 'deny: HELD: this change:1:change:alpha\nbeta\ngamma\ndelta\n:0'
rigAssert "and the prompt is in the Wait of that session" "$( rigWaitSet )" 1
rigHook hook2 MultiEdit '{"file_path":"'"$rigWs/held/notes.md"'","edits":[{"old_string":"alpha","new_string":"ALPHA"},{"old_string":"gamma","new_string":"GAMMA"}]}'
rigAssert "a MultiEdit is one change of several edits: one more prompt" "$( rigHookSays hook2 ):$( rigRecordCount ):$( LC_ALL=C grep -c -x 'matched: 1 1' "$( rigKeptDir )/change" 2> /dev/null )" "deny: HELD: this change:2:1"
rigThread "$( rigClick +1 URIGOWNER )" ""
rigRead
rigAssert "approved, it is applied whole" "$( rigReadLine 'CHANGE: ' ):$( rigBytes "$rigWs/held/notes.md" )" "CHANGE: applied -- OK: applied 2 edit(s) in $rigWs/held/notes.md:ALPHA\\nbeta\\nGAMMA\\ndelta\\n"
rigHook hook3 Write '{"file_path":"'"$rigWs/held/new.md"'","content":"one\n"}'
rigAssert "its own Write is held too" "$( rigHookSays hook3 ):$( rigRecordCount ):$( [ -e "$rigWs/held/new.md" ] && printf there || printf none )" "deny: HELD: this change:3:none"
rigHook hook4 Edit '{"file_path":"'"$rigWs/other/notes.md"'","old_string":"beta","new_string":"BETA"}'
rigAssert "a call no grant covers is refused as before, with its refusal id" "$( rigHookSays hook4 ):$( LC_ALL=C grep -c 'REFUSAL-ID: refusal-' "$rigDir/hook4" ):$( rigRecordCount )" "deny: Refused. REFUSAL-ID: refusal-$( LC_ALL=C sed -n 's/^.*REFUSAL-ID: refusal-\([0-9a-f-]*\)\..*$/\1/p' "$rigDir/hook4" | head -1 ).:1:3"
rigHook hook5 Edit '{"file_path":"'"$rigWs/held/notes.md"'","old_string":"nope","new_string":"NOPE"}'
rigAssert "a covered call that cannot be applied is denied in the tool's own words, and nothing is held" "$( rigHookSays hook5 ):$( rigRecordCount )" "deny: ERROR: old_string not:3"

echo "-- 14. a prompt that could not be posted, or not whole: nothing is held --"
rigStart unposted
: > "$rigDir/post.fail"
rigEdit edit "$rigWs/held/notes.md" beta BETA
rigAssert "the call says the change is NOT held, and nothing was written" "$( rigFirst edit ):$( rigBytes "$rigWs/held/notes.md" )" \
	"ERROR: Edit: a change to $rigWs/held/notes.md needs the approval of the human-owner, and it could not be shown to him, so it is NOT held and nothing was written. Make the call again once what stopped it is cleared. What the operation reported follows:"':alpha\nbeta\ngamma\ndelta\n'
rigAssert "no record, nothing kept, nothing in its Wait" "$( rigRecordCount ):$( ls "$rigWs/.local/agents/sessions/$rigSpawn/changes" 2> /dev/null | LC_ALL=C awk 'END { print NR + 0 ; }' )" "0:0"
rigStart unshown
: > "$rigDir/reply.fail"
rigEdit edit "$rigWs/held/notes.md" beta BETA
rigAssert "the first post is posted and the change under it is not: the call says the change is NOT held, and nothing was written" "$( rigFirst edit ):$( rigBytes "$rigWs/held/notes.md" )" \
	"ERROR: Edit: a change to $rigWs/held/notes.md needs the approval of the human-owner, and it could not be shown to him, so it is NOT held and nothing was written. Make the call again once what stopped it is cleared. What the operation reported follows:"':alpha\nbeta\ngamma\ndelta\n'
rigAssert "with what the operation reported: the prompt is taken away again, and why" \
	"$( rigHas "$rigDir/edit" "the prompt for the change to $rigWs/held/notes.md was posted, but the change itself could not be shown under it, so the prompt is taken away again and the change is not held" ):$( rigHas "$rigDir/edit" 'rig_reply_refused' )" "yes:yes"
rigAssert "the first post is deleted, and no click answer was placed under it" \
	"$( rigPosts ):$( LC_ALL=C tr '\n' ' ' < "$rigDir/deleted" ):$( [ -f "$rigDir/reactions" ] && printf placed || printf none )" "1:1700000001.000101 :none"
rigAssert "no record, nothing kept, nothing in its Wait: a prompt whose change is not shown is never left to be answered" \
	"$( rigRecordCount ):$( ls "$rigWs/.local/agents/sessions/$rigSpawn/changes" 2> /dev/null | LC_ALL=C awk 'END { print NR + 0 ; }' ):$( rigWaitSet )" "0:0:0"
rigStart unrecorded
: > "$rigWs/.local/agents/pending"
rigEdit edit "$rigWs/held/notes.md" beta BETA
rigAssert "both posted and the prompt not recorded: NOT held, nothing written, and both posts are taken away again, the reply first" \
	"$( rigFirst edit | LC_ALL=C cut -c1-12 ):$( rigHas "$rigDir/edit" 'was shown, but its prompt could not be recorded' ):$( rigBytes "$rigWs/held/notes.md" ):$( rigPosts ):$( LC_ALL=C tr '\n' ' ' < "$rigDir/deleted" ):$( ls "$rigWs/.local/agents/sessions/$rigSpawn/changes" 2> /dev/null | LC_ALL=C awk 'END { print NR + 0 ; }' )" \
	'ERROR: Edit::yes:alpha\nbeta\ngamma\ndelta\n:2:1700000001.000201 1700000001.000101 :0'

echo "-- 15. what the member holds, and what its grants list says --"
rigStart holds
rigOp "$rigDir/holds-edit" --intern-op-permission-holds keeper-myx Edit "$rigWs/held/notes.md" --session-id "$rigSpawn"
rigOp "$rigDir/holds-read" --intern-op-permission-holds keeper-myx Read "$rigWs/held/notes.md" --session-id "$rigSpawn"
rigAssert "a write by approval is not held, so it is never passed on or approved by the member; its read is" \
	"$( LC_ALL=C grep -m1 -E '^(HOLDS|NOT-HOLDS)' "$rigDir/holds-edit" | LC_ALL=C cut -d' ' -f1 ):$( LC_ALL=C grep -m1 -E '^(HOLDS|NOT-HOLDS)' "$rigDir/holds-read" )" "NOT-HOLDS:HOLDS standing"
rigOp "$rigDir/list" --intern-op-permission-list keeper-myx
rigAssert "the grants list names it: standing, approve, the place" "$( LC_ALL=C awk -F'\t' -v want="$rigWs/held/**" '$1 == "standing" && $2 == "approve" && $3 == want { print $1, $2, $4 ; }' "$rigDir/list" )" "standing approve rig-ws:held/**"
rigAssert "the grants index holds its read row and its approve row, and no write row" \
	"$( LC_ALL=C awk -F'\t' -v want="$rigWs/held/**" '$1 == "keeper-myx" && $3 == want { printf "%s ", $2 ; }' "$rigWs/.local/agents/grants.index" )" "read approve "
rigMember="magic-tester"
rigEdit tester "$rigWs/held/notes.md" beta BETA
rigAssert "another member on the same file is refused as before" "$( LC_ALL=C grep -c -e '^ERROR: path not in the allowed write-root set' -e '^REFUSAL-ID: refusal-' "$rigDir/tester" )" 2
rigMember="keeper-myx"

echo "-- 16. the first use: the librarian's standing access to the skills of the team is by approval --"
rigStart librarian
rigMember="magic-librarian"
mkdir -p "$rigDir/.claude/skills" "$rigWs/source/rig/rig-proj/skillset/keeper-here/reference" "$rigWs/.local/agents/members/magic-librarian"
printf -- '---\nname: magic-librarian\ndescription: rig member\n---\n' > "$rigWs/.local/agents/members/magic-librarian/SKILL.md"
printf 'rig\n' > "$rigWs/.local/agents/members/magic-librarian/magic-librarian.basic.md"
printf -- '---\nname: keeper-here\ndescription: rig member\n---\n' > "$rigWs/source/rig/rig-proj/skillset/keeper-here/SKILL.md"
printf 'rig\n' > "$rigWs/source/rig/rig-proj/skillset/keeper-here/keeper-here.basic.md"
printf 'rig-seed armed\n' > "$rigWs/source/rig/rig-proj/skillset/keeper-here/keeper-here.armed.md"
printf 'rig-seed mark\n' > "$rigWs/source/rig/rig-proj/skillset/keeper-here/mark.txt"
ln -s "$rigWs/source/rig/rig-proj/skillset/keeper-here" "$rigDir/.claude/skills/keeper-here"
LC_ALL=C sed -i.bak 's/^owner: keeper-myx$/owner: magic-librarian/' "$rigWs/.local/agents/spawned/$rigSpawn/$rigSpawn.md" "$rigData/board/running/$rigItem.md"
rigSkillFile="$rigWs/source/rig/rig-proj/skillset/keeper-here/keeper-here.armed.md"
rigEdit lib "$rigDir/.claude/skills/keeper-here/keeper-here.armed.md" rig-seed "rig-seed edited"
rigAssert "the librarian's Edit of a skill .md file, by the HOME link, is held on the real file, not asked for and not applied" "$( rigFirst lib ):$( rigBytes "$rigSkillFile" ):$( LC_ALL=C grep -c 'REFUSAL-ID' "$rigDir/lib" )" "$( rigHeldLine "$rigSkillFile" ):rig-seedarmed\\n:0"
rigAssert "its prompt is the librarian's, for the human-owner" "$( rigField kind ):$( rigField owner ):$( rigField address-to ):$( rigPromptBody | LC_ALL=C grep -c -F 'magic-librarian wants to change' )" "change:magic-librarian:human-owner:1"
rigTool "$rigDir/libread" Read '{"file_path":"'"$rigSkillFile"'"}'
rigAssert "it reads the file as before" "$( rigHas "$rigDir/libread" 'rig-seed armed' )" yes
rigThread "$( rigClick +1 URIGOWNER )" ""
rigRead
rigAssert "approved, the skill file is changed as shown" "$( rigReadLine 'CHANGE: ' ):$( rigBytes "$rigSkillFile" )" "CHANGE: applied -- OK: replaced one occurrence in $rigSkillFile:rig-seededitedarmed\\n"
rigEdit libtxt "$rigWs/source/rig/rig-proj/skillset/keeper-here/mark.txt" rig-seed "rig-seed edited"
rigAssert "which files it covers is unchanged: a file there that is no .md is refused as before" "$( LC_ALL=C grep -c -e '^ERROR: path not in the allowed write-root set' -e '^REFUSAL-ID: refusal-' "$rigDir/libtxt" )" 2
rigAssert "the grants index holds the skill as the librarian's to read, and to write by approval" \
	"$( LC_ALL=C awk -F'\t' -v want="$rigWs/source/rig/rig-proj/skillset/keeper-here/**.md" '$1 == "magic-librarian" && $3 == want { printf "%s ", $2 ; }' "$rigWs/.local/agents/grants.index" )" "read approve "

echo "-- 17. what comes ahead of an approval: a grant given for the task, nothing held standing or by the floor --"
rigStart ahead
rigEdit floor "$rigWs/.local/temp/held/notes.md" beta BETA
rigAssert "the floor does not: a covered file under .local/temp, which every member writes, is held" "$( rigFirst floor ):$( rigBytes "$rigWs/.local/temp/held/notes.md" )" "$( rigHeldLine "$rigWs/.local/temp/held/notes.md" ):alpha\\nbeta\\n"
rigEdit own "$rigWs/.local/agents/members/keeper-myx/keeper-myx.basic.md" rig RIG
rigAssert "nor does the member's own directory, by its standing row or by what its run knows" "$( rigFirst own ):$( rigBytes "$rigWs/.local/agents/members/keeper-myx/keeper-myx.basic.md" )" "$( rigHeldLine "$rigWs/.local/agents/members/keeper-myx/keeper-myx.basic.md" ):rig\\n"
rigOp "$rigDir/holds-own" --intern-op-permission-holds keeper-myx Edit "$rigWs/.local/agents/members/keeper-myx/keeper-myx.basic.md" --session-id "$rigSpawn"
rigAssert "though it holds that access: he approves the result, not the access" "$( LC_ALL=C grep -m1 -E '^(HOLDS|NOT-HOLDS)' "$rigDir/holds-own" )" "HOLDS standing"
## A grant given for the task, as an approved permission set writes it: the grant line, and its record.
printf -- '---\nstatus: set\nowner: keeper-myx\napproved-by: human-owner\nsession-id: %s\nkind: task\ntask: %s\n---\n\n# Permission set\n' "$rigSpawn" "$rigItem" > "$rigWs/.local/agents/sessions/$rigSpawn/set-rig1.md"
printf 'task:Edit:%s:human-owner:20261012T0900Z:set-rig1\n' "$rigWs/held/notes.md" >> "$rigWs/.local/agents/sessions/$rigSpawn/grants"
rigEdit task "$rigWs/held/notes.md" beta BETA
rigAssert "a grant given for the task does: the call is applied at once, with no prompt" "$( rigFirst task ):$( rigBytes "$rigWs/held/notes.md" ):$( rigRecordCount ):$( rigPosts )" "OK: replaced one occurrence in $rigWs/held/notes.md:alpha\\nBETA\\ngamma\\ndelta\\n:2:4"
rigHook hook-task Edit '{"file_path":"'"$rigWs/held/notes.md"'","old_string":"gamma","new_string":"GAMMA"}'
rigAssert "and a native client's own call under it is allowed, not held" "$( rigHookSays hook-task ):$( rigRecordCount )" "allow:2"
mv "$rigData/board/running/$rigItem.md" "$rigData/board/processed/$rigItem.md"
rigEdit closed "$rigWs/held/notes.md" delta DELTA
rigAssert "once that task is closed its grant is gone, and the call is held again" "$( rigFirst closed ):$( rigBytes "$rigWs/held/notes.md" )" "$( rigHeldLine "$rigWs/held/notes.md" ):alpha\\nBETA\\ngamma\\ndelta\\n"

echo "-- 18. a prompt posted before its change moved to its thread: read, answered, confirmed and closed as it was --"
## What the operation kept then, made here from a prompt of today: every slot of the one post
## beside its record, the diff among them; the record's text that one post; and in its thread
## no reply of the tooling under it.
rigBefore(){ ## that prompt, the newest, made the one post it was
	local beforeRecord beforeHead beforeTask beforeSession beforeBy beforeDiff
	beforeRecord="$( rigRecord )"
	beforeDiff="$( cat "$( rigKeptDir )/change.diff" )"
	beforeTask=$'Rework the rig widget\n`task-20261012T0000Z-'"$rigName"'` · `'"$rigItem"$'`\nThe widget drops its last line. Make it keep it.'
	beforeSession='rework the rig widget · `5e55104a` · `CSES00001:1700000000.000100`'
	beforeBy="keeper-myx · $rigHost / ws"
	rigPack member keeper-myx act change file rig-ws:held/notes.md purpose 'Raise the second word' task "$beforeTask" session "$beforeSession" asked-by "$beforeBy" fence '```' diff "$beforeDiff" > "${beforeRecord%.md}.fields"
	beforeHead="$( LC_ALL=C awk '{ print ; } $0 == "# Question asked" { exit ; }' "$beforeRecord" )"
	{
		printf '%s\n\n' "$beforeHead"
		ASKP_F_member=keeper-myx ASKP_F_act=change ASKP_F_file=rig-ws:held/notes.md ASKP_F_purpose='Raise the second word' ASKP_F_task="$beforeTask" ASKP_F_session="$beforeSession" \
			ASKP_F_asked_by="$beforeBy" ASKP_F_fence='```' ASKP_F_diff="$beforeDiff" rigFill post
	} > "$beforeRecord.rig" && mv -f "$beforeRecord.rig" "$beforeRecord"
}
rigThreadOwn=""
rigStart before
rigEdit edit "$rigWs/held/notes.md" beta BETA "Raise the second word"
rigBefore
rigAssert "its record keeps the one post whole, the diff among what it was filled with" \
	"$( rigPromptBody | LC_ALL=C grep -c -x -e '\*\*📝 The change\*\*' -e '+BETA' -e '\*\*✅ How to answer\*\*' ):$( LC_ALL=C cut -f1 "$rigWs/.local/agents/pending/$( rigId ).fields" | LC_ALL=C tr '\n' ' ' )" "3:member act file purpose task session asked-by fence diff "
rigAssert "a reminder quotes the line it always did" "$( rigRemindQuote )" 'keeper-myx wants to change `rig-ws:held/notes.md`.'
rigThread "" ""
rigRead
rigAssert "it is read as every prompt is: nothing of his there, it is open" "$( rigReadLine 'ESCALATION: ' ):$( rigField status )" "ESCALATION: $( rigId ) open:reply-pending"
rigThread "" "$( rigReply 000250 URIGOWNER 'why BETA and not Beta?' )"
rigRead
rigAssert "his words with no verdict come back as RETURNED, whole, and the change stays held" \
	"$( rigReadLine 'VERDICT: ' ):$( rigHas "$rigDir/read" 'why BETA and not Beta?' ):$( rigField status ):$( rigBytes "$rigWs/held/notes.md" )" 'VERDICT: RETURNED:yes:reply-pending:alpha\nbeta\ngamma\ndelta\n'
rigBeforePosts="$( rigPosts )"
rigThread "$( rigClick +1 URIGOWNER )" "$( rigReply 000250 URIGOWNER 'why BETA and not Beta?' )"
rigRead
rigAssert "his 👍 approves it: the kept change is applied as it was shown, and the record closes" "$( rigReadLine 'VERDICT: ' ):$( rigReadLine 'CHANGE: ' ):$( rigBytes "$rigWs/held/notes.md" ):$( rigField status )" \
	"VERDICT: approve:CHANGE: applied -- OK: replaced one occurrence in $rigWs/held/notes.md:alpha\\nBETA\\ngamma\\ndelta\\n:reply-received"
rigBeforeEdit="$rigDir/edit.$( rigField question-ts )"
rigAssert "with the answered mark its click answers leave it, and it is edited to the one post it was without How to answer, its change still in it" \
	"$( rigReacted reactions.removed ):$( rigReacted reactions ):$( rigHas "$rigBeforeEdit" 'wants to change' ):$( rigHas "$rigBeforeEdit" 'How to answer' ):$( rigHas "$rigBeforeEdit" '@@ -1,4 +1,4 @@' ):$( rigHas "$rigBeforeEdit" 'Rework the rig widget' )" "+1 x:+1 x white_check_mark:yes:no:yes:yes"
rigAssert "and it is confirmed with one reply in its thread" \
	"$(( $( rigPosts ) - rigBeforePosts )):$( LC_ALL=C grep -c -F 'Read: `approve` by human-owner. The change is applied to `rig-ws:held/notes.md`, exactly as shown.' "$rigDir/post.$( rigPosts )" 2> /dev/null ):$( rigHas "$rigDir/post.$( rigPosts )" "\"thread_ts\":\"$( rigField question-ts )\"" )" "1:1:yes"
rigStart before-rejected
rigEdit edit "$rigWs/held/notes.md" beta BETA "Raise the second word"
rigBefore
rigThread "$( rigClick x URIGOWNER )" ""
rigRead
rigAssert "rejected: dropped, nothing applied, its click answers taken off, and it is marked" \
	"$( rigReadLine 'VERDICT: ' ):$( rigReadLine 'CHANGE: ' ):$( rigBytes "$rigWs/held/notes.md" ):$( rigReacted reactions.removed ):$( rigReacted reactions | LC_ALL=C awk '{ print $NF ; }' )" \
	'VERDICT: reject:CHANGE: dropped -- rejected, so nothing is applied to rig-ws:held/notes.md:alpha\nbeta\ngamma\ndelta\n:+1 x +1 x:no_entry_sign'
rigBeforeEdit="$rigDir/edit.$( rigField question-ts )"
rigAssert "its post is edited to the one post it was, without How to answer: the change, the task, the session and who asked stay in it" \
	"$( rigHas "$rigBeforeEdit" 'wants to change' ):$( rigHas "$rigBeforeEdit" 'How to answer' ):$( rigHas "$rigBeforeEdit" '@@ -1,4 +1,4 @@' ):$( rigHas "$rigBeforeEdit" '+BETA' ):$( rigHas "$rigBeforeEdit" 'Rework the rig widget' ):$( rigHas "$rigBeforeEdit" '5e55104a' ):$( rigHas "$rigBeforeEdit" 'Asked by' )" "yes:no:yes:yes:yes:yes:yes"
rigAssert "and its thread is told what was read" "$( LC_ALL=C grep -l -F 'Read: `reject` by human-owner. The change is dropped: nothing is applied to `rig-ws:held/notes.md`.' "$rigDir"/post.[0-9] 2> /dev/null | LC_ALL=C awk 'END { print NR + 0 ; }' )" 1
rigStart before-withdrawn
rigEdit edit "$rigWs/held/notes.md" beta BETA "Raise the second word"
rigBefore
rigTool "$rigDir/withdraw" AskQuestion '{"pending_id":"'"$( rigId )"'","withdraw":"a better wording came up"}'
rigBeforeEdit="$rigDir/edit.$( rigField question-ts )"
rigAssert "taken back by its asker: closed and marked, its post the one post it was without How to answer" \
	"$( LC_ALL=C grep -c -x 'ASK-RESULT: WITHDRAWN' "$rigDir/withdraw" ):$( rigField status ):$( rigReacted reactions.removed ):$( rigReacted reactions | LC_ALL=C awk '{ print $NF ; }' ):$( rigHas "$rigBeforeEdit" '@@ -1,4 +1,4 @@' ):$( rigHas "$rigBeforeEdit" 'How to answer' )" "1:withdrawn:+1 x:no_entry_sign:yes:no"
rigStart before-ended
rigEdit edit "$rigWs/held/notes.md" beta BETA "Raise the second word"
rigBefore
rigOp "$rigDir/collect" --intern-op-pending-reply-collect --session-id "$rigSpawn" --mark-ended --context rig
rigBeforeEdit="$rigDir/edit.$( rigField question-ts )"
rigAssert "its session ended: dropped by the tooling, its thread told, its post the one post it was without How to answer" \
	"$( LC_ALL=C grep -c "^DROPPED $( rigId ) " "$rigDir/collect" ):$( rigField status ):$( LC_ALL=C grep -l -F 'This change is dropped: the session that made it has ended. Nothing is applied, and the prompt above takes no answer any more.' "$rigDir"/post.[0-9] 2> /dev/null | LC_ALL=C awk 'END { print NR + 0 ; }' ):$( rigHas "$rigBeforeEdit" '@@ -1,4 +1,4 @@' ):$( rigHas "$rigBeforeEdit" 'How to answer' )" "1:withdrawn:1:yes:no"
rigThreadOwn=1

echo "-- 19. the Wait after an answer by click: the tooling's own emoji leaving the prompt is no arrival --"
## The thread as Slack gives it, one entry an emoji with everyone who holds it: before the
## answer is read the tooling's own two and his click, after it his click and the answered mark.
rigThreadAs(){ ## reactions JSON, replies (rigReply words, may be empty)
	local asTs
	asTs="$( rigField question-ts )"
	printf '{"ok":true,"messages":[{"ts":"%s","user":"URIGBOT01","text":"the prompt","reactions":[%s]},{"ts":"1700000001.000201","user":"URIGBOT01","text":"the change","thread_ts":"%s"}%s],"has_more":false}\n' \
		"$asTs" "$1" "$asTs" "${2:-}" > "$rigDir/replies.$asTs.json"
}
rigStart after-click
rigEdit edit "$rigWs/held/notes.md" beta BETA
rigThreadAs '{"name":"+1","count":2,"users":["URIGBOT01","URIGOWNER"]},{"name":"x","count":1,"users":["URIGBOT01"]}'
rigTool "$rigDir/wait1" Wait '{"timeout":30}'
rigAssert "his click arrives on the Wait as the verdict, applied, and its thread stays watched" \
	"$( LC_ALL=C grep -c -x -e 'ASK-RESULT: RECEIVED' -e 'VERDICT: approve' "$rigDir/wait1" ):$( rigField status ):$( rigField follow-floor ):$( rigWaitSet )" "2:reply-received:$( rigField question-ts ):1"
rigThreadAs '{"name":"+1","count":1,"users":["URIGOWNER"]},{"name":"white_check_mark","count":1,"users":["URIGBOT01"]}'
rigTool "$rigDir/wait2" Wait '{"mode":"continue","timeout":6}'
rigAssert "the next Wait brings nothing: the tooling's own emoji gone from the prompt is no arrival, and the answer is not given twice" \
	"$( LC_ALL=C grep -c '^WAIT-RESULT: TIMEOUT' "$rigDir/wait2" ):$( LC_ALL=C grep -c -e '^ASK-RESULT: ' -e '^reaction on the question: ' "$rigDir/wait2" )" "1:0"
rigThreadAs '{"name":"+1","count":1,"users":["URIGOWNER"]},{"name":"white_check_mark","count":1,"users":["URIGBOT01"]}' "$( rigReply 000450 URIGOWNER 'soften it later, please' )"
rigTool "$rigDir/wait3" Wait '{"mode":"continue","timeout":30}'
rigAssert "what he writes there after still arrives, kept with the answer" \
	"$( LC_ALL=C grep -c -x 'ASK-RESULT: CLARIFIED' "$rigDir/wait3" ):$( rigHas "$rigDir/wait3" 'soften it later, please' )" "1:yes"

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ CHANGE APPROVAL CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2
	echo "  fix:  the gate and the write tools of sh-lib/harness/AgentsUniversalHarness.sh, sh-lib/grants/AgentsTools.InternOpChange.include," >&2
	echo "        the approve rows of sh-lib/grants/AgentsTools.Grants.include and its awk programs, or the template -- never the assertion" >&2
	exit 1
fi
printf 'CHANGE_APPROVAL: OK (%d assertions, offline, rig tree only)\n' "$rigPassCount"
