#!/usr/bin/env bash
## Behavioural check: withdrawing a Permission set closes its post, as it closes the post of
## every other question (AgentsToolsAskPostClose, AgentsTools.AskPost.include). The set post is
## filled again from its own record, the `<id>.set` beside the pending-reply record
## (AgentsToolsPermissionSetRecordFill, AgentsTools.InternOpPermission.include), by its own
## template (sh-lib/templates/permission-set.post.format.md) without the how-to-answer part;
## the tooling's own answer emoji come off it, and it gets the cancelled mark.
## Covers: the post as asked; the withdraw through `--member-pending-reply-settle --withdraw`;
## the edit, its text and its shape; the emoji taken off and the mark put on; a record written
## before the held entries were kept; an edit Slack refuses; and an allow-set still granting
## the asked entries only.
## Red recipe: drop the permission-set branch from AgentsToolsAskPostRecordFill, and the
## withdraw prints "was not edited: its text could not be filled again from its record".
## Offline: a Slack-shaped fake curl is first on PATH, a ps that lists the rig's own runs only
## is beside it, and everything runs in a workspace under this check's temp tree.
set -u
: "${MMDAPP:?⛔ ERROR: MMDAPP is not set}"
rigHere="${MDLT_ORIGIN:=$MMDAPP/.local}/myx/myx.distro-agents/sh-lib"
rigTest="${rigHere%/sh-lib}/sh-test"
rigTools="$MDLT_ORIGIN/myx/myx.distro-agents/sh-scripts/DistroAgentsTools.fn.sh"

rigRefuse(){
	echo "⛔ ERROR: $1 -- refusing to report a result" >&2 ; exit 1
}
[ -x "$rigTools" ] || rigRefuse "dispatcher not found at the origin this workspace resolves: $rigTools"
for rigNeed in magic-tester magic-developer magic-coordinator ; do
	[ -r "${MDAT_SKILLSET_ROOT:-}/$rigNeed/$rigNeed.basic.md" ] || rigRefuse "MDAT_SKILLSET_ROOT does not hold $rigNeed"
done

rigTmp="$( mktemp -d -t AgentsPermissionSetWithdrawCheck )" || exit 1
rigTmp="$( cd "$rigTmp" && pwd -P )" || exit 1
trap 'chmod -R u+w "$rigTmp" 2>/dev/null ; rm -rf -- "$rigTmp"' EXIT
mkdir -p "$rigTmp/bin"
cp "$rigTest/check-fixtures/harness-ask-forms.curl.test.sh" "$rigTmp/bin/curl" || rigRefuse "the fake curl fixture is missing from the package"
chmod +x "$rigTmp/bin/curl"
## THE RIG'S OWN PROCESS LIST. A spawn is found running by a process list read from the host
## (ps -A). A rig that read the real one would take whatever command line of this host holds
## one of its ids for a run of its own, and another copy of this check for its own. So the ps
## first on PATH answers the whole-host listing from the rig's own list, beside it, one
## `<pid> <command line>` line a process, and hands every other call to the real ps.
mkdir -p "$rigTmp/bin"
ln -s "$( command -v ps )" "$rigTmp/bin/ps.real" || rigRefuse "no ps on PATH to hand the other calls to"
: > "$rigTmp/ps.list"
cat > "$rigTmp/bin/ps" <<'RIGPS'
#!/bin/sh
case " $* " in
	*" -A "*)
		case "$*" in
			*pid=*) cat "${0%/*}/../ps.list" 2> /dev/null ;;
			*) sed 's/^[^ ]* //' "${0%/*}/../ps.list" 2> /dev/null ;;
		esac
		exit 0
	;;
esac
exec "${0%/*}/ps.real" "$@"
RIGPS
chmod +x "$rigTmp/bin/ps"
PATH="$rigTmp/bin:$PATH"
export PATH
[ "$( command -v curl )" = "$rigTmp/bin/curl" ] || rigRefuse "the fake curl is not first on PATH, so this check could issue real requests"
[ "$( command -v ps )" = "$rigTmp/bin/ps" ] || rigRefuse "the rig's own ps is not first on PATH, so this check would read the host's process list"

rigPassCount=0
rigFailCount=0
rigAssert(){ ## what is asserted, got, want
	if [ "$2" = "$3" ] ; then
		printf '  PASS  %s\n' "$1" ; rigPassCount=$(( rigPassCount + 1 ))
	else
		printf '  FAIL  %s\n        got:  %s\n        want: %s\n' "$1" "$2" "$3" ; rigFailCount=$(( rigFailCount + 1 ))
	fi
}
rigHas(){ ## file, text
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	case "$( cat "$1" )" in *"$2"*) printf yes ;; *) printf no ;; esac
}
rigField(){ ## file, field
	LC_ALL=C awk -F': ' -v wantField="$2" '$1 == wantField { print substr( $0, length( wantField ) + 3 ) ; exit ; }' "$1" 2>/dev/null
}
rigCalls(){ ## method
	LC_ALL=C awk -v wantMethod="$1" '$0 == wantMethod { hitCount++ ; } END { print hitCount + 0 ; }' "$RIG_CURL_LOG"
}

## The rig workspace: a session rig-set of three participants, each spawn on its own host; a
## dispatch that tracks a task; the workspace registered as the place rig-ws; one standing row,
## so one asked entry is held by a participant already.
rigWs="$rigTmp/ws"
rigData="$rigWs/DATA"
mkdir -p "$rigWs/.local/.agents" "$rigWs/.local/agents/spawned/rig-set" "$rigData/board/running" "$rigData/board/processed" "$rigWs/DEV"
printf 'SLACK_CHANNEL_MAGIC_TEAM=CRIG00001\nSLACK_BOT_TOKEN=rig-bot-token-TEAM\nSLACK_CHANNEL_HUMAN_OWNER=URIGOWNER\n' > "$rigWs/.local/.agents/magic-team.agent.env"
printf 'magic-developer:ws:workspace:Edit(/%s/DEV/**)\n' "$rigWs" > "$rigWs/.local/agents/permissions.registry"
printf '%s\t%s\t%s\t%s\t%s\n' rig-ws workspace read-write "$rigWs" workspace > "$rigWs/.local/agents/directories.registry"
rigSetRecord(){ ## spawn id, owner, host, description, further header lines (may be empty)
	printf -- '---\nsession-id: rig-set\nspawn-id: %s\nowner: %s\nhost: %s\ndescription: %s\n%sstatus: spawn-started\n---\n\n# Spawn session\n' \
		"$1" "$2" "$3" "$4" "${5:-}" > "$rigWs/.local/agents/spawned/rig-set/$1.md"
}
rigSetRecord rig-set magic-coordinator rig-host-a 'rework the vars loader' $'session-thread: CRIG00001:1700000000.000500\n'
## The developer's spawn runs on this host, live: an entry counts as held only by a participant
## with a live run in the session, a line of the rig's process list that runs as its spawn id.
rigSetRecord rig-set-dev magic-developer "$( hostname -s 2>/dev/null || echo unknown )" 'change the loader code'
printf '900001 rig-run --session-id rig-set-dev\n' >> "$rigTmp/ps.list"
## A task set is for the members it names: these three, in the task requests below.
rigSetThree=( --participant magic-coordinator --participant magic-developer --participant magic-tester )
rigSetRecord rig-set-tester magic-tester rig-host-c 'check it against the samples'
printf -- '---\nstatus: task\nowner: magic-developer\n---\n\n# Fix the vars loader\n\nThe loader drops a variable whose value holds an equals sign.\n' > "$rigData/board/running/task-rig-set.md"
printf -- '---\nstatus: dispatch-started\nowner: magic-developer\nsession-id: rig-set\ntracks: task-rig-set\n---\n\n# Spawn-proxy dispatch: magic-developer\n\n## Brief\n\nthe brief of the dispatch.\n' \
	> "$rigData/board/running/dispatch-rig-set.md"
RIG_CURL_LOG="$rigTmp/curl.log"
export RIG_CURL_LOG
: > "$RIG_CURL_LOG"

## One team operation as RIG_OP_AGENT in session RIG_OP_SESSION; out and err kept.
RIG_OP_AGENT=""
RIG_OP_SESSION=""
rigOp(){
	( cd "$rigWs" && env -u CLAUDE_CODE_SESSION_ID -u MDAT_SPAWN_SESSION_ID -u MDAT_SPAWN_AGENT -u MDAT_SESSION_ID \
		${RIG_OP_SESSION:+MDAT_SPAWN_SESSION_ID="$RIG_OP_SESSION"} ${RIG_OP_AGENT:+MDAT_SPAWN_AGENT="$RIG_OP_AGENT"} \
		MMDAPP="$rigWs" MDAT_DATA_ROOT="$rigData" RIG_SCENARIO="$rigTmp" bash "$rigTools" "$@" ) > "$rigTmp/op.out" 2> "$rigTmp/op.err"
}
rigSetAsk(){ ## item, request options... -> the pending id
	RIG_OP_AGENT=magic-coordinator RIG_OP_SESSION=rig-set
	rigOp --magic-permission-set-request magic-coordinator "$@"
	RIG_OP_AGENT="" RIG_OP_SESSION=""
	LC_ALL=C sed -n 's/^PERMISSION-SET: asked //p' "$rigTmp/op.out"
}
rigWithdraw(){ ## pending id, reason, [the member that withdraws; default the asker]
	RIG_OP_AGENT="${3:-magic-coordinator}" RIG_OP_SESSION=rig-set
	rigOp --member-pending-reply-settle "${3:-magic-coordinator}" "$1" --reason "$2" --withdraw
	RIG_OP_AGENT="" RIG_OP_SESSION=""
}
rigGrantRead(){ ## member, session, tool, target
	rigOp --intern-op-permission-grant-read "$1" --session-id "$2" --tool "$3" --target "$4"
	LC_ALL=C sed -n 's/^GRANT: \([a-z]*\) .*$/\1/p' "$rigTmp/op.out" | head -1
}
## The text a post, or an edit of one, carries: the JSON string of its body, as sent.
rigTextOf(){ ## body file
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	LC_ALL=C awk '{ at = index( $0, "\"text\":\"" ) ; if ( ! at ) { next ; } rest = substr( $0, at + 8 ) ; end = 0 ; marks[1] = "\",\"thread_ts\":" ; marks[2] = "\",\"ts\":" ; marks[3] = "\",\"blocks\":" ; for ( markNo = 1 ; markNo <= 3 ; markNo++ ) { markAt = index( rest, marks[markNo] ) ; if ( markAt > 0 && ( end == 0 || markAt < end ) ) { end = markAt ; } } if ( end > 0 ) { print substr( rest, 1, end - 1 ) ; } exit ; }' "$1"
}
## What an edit must carry: the text the post was sent with, less its how-to-answer part.
rigClosedOf(){ ## the body file of the post
	rigTextOf "$1" | LC_ALL=C sed 's/\\n\\n\*\*✅ How to answer\*\*.*$//'
}
## Whether an edit is a whole message as the send builds one: it names the post it edits, has
## blocks, and says nowhere how to answer -- "<names it>:<blocks>:<how to answer>".
rigEditShape(){ ## edit body file, ts of the post
	[ -f "$1" ] || { printf 'no-such-file' ; return 0 ; }
	printf '%s:%s:%s' "$( LC_ALL=C grep -c -F "\"ts\":\"$2\"" "$1" )" "$( LC_ALL=C grep -c -F '"blocks":[' "$1" )" "$( LC_ALL=C grep -c -e 'to allow the set' -e 'allow-set' "$1" )"
}
## The emoji placed on, or taken off, one post: its names in the order asked for.
rigReacted(){ ## reactions|reactions.removed, ts
	LC_ALL=C awk -v want="$2" '$1 == want { out = out ( out == "" ? "" : " " ) $2 ; } END { print out ; }' "$rigTmp/$1" 2>/dev/null
}
## The post of one request: the body file the fake curl kept for the message its record names.
rigPostOf(){ ## pending id
	local postTs postFile
	postTs="$( rigField "$rigWs/.local/agents/pending/$1.md" question-ts )"
	for postFile in "$rigTmp"/post.[0-9]* ; do
		[ -f "$postFile" ] || continue
		[ "1700000001.000${postFile##*.}01" != "$postTs" ] || { printf '%s' "$postFile" ; return 0 ; }
	done
	printf '%s' "$rigTmp/no-such-post"
}

echo "-- the set as asked: its post says how to answer, and carries the tooling's two answer emoji --"
rigSetId="$( rigSetAsk dispatch-rig-set --entry "Write:$rigWs/SETP/**" --entry "Read:$rigWs/SETP/**" --purpose 'need to read some files' \
	--entry 'Read:/nowhere/rig-set/**' --entry "Edit:$rigWs/DEV/held/**" --scope task --session-id rig-set "${rigSetThree[@]}" )"
[ -n "$rigSetId" ] || rigRefuse "the rig's permission set request asked nothing: $( head -2 "$rigTmp/op.err" )"
rigSetFile="$rigWs/.local/agents/pending/$rigSetId.md"
rigSetTs="$( rigField "$rigSetFile" question-ts )"
rigSetPost="$( rigPostOf "$rigSetId" )"
rigAssert "the request is open, as a permission set"       "$( rigField "$rigSetFile" status ):$( rigField "$rigSetFile" kind )" "reply-pending:permission-set"
rigAssert "its post says how to answer"                    "$( rigHas "$rigSetPost" '- click ❌ to deny, or 🔓 to allow the set: an allow gives these to every participant listed' ):$( rigHas "$rigSetPost" '- or reply `allow-set`, `deny`, or `edit:` followed by the change' )" "yes:yes"
rigAssert "and shows what is asked, what is held, and the task" "$( rigHas "$rigSetPost" 'rig-ws:SETP/**` — Read, Write' ):$( rigHas "$rigSetPost" 'rig-ws:DEV/held/**` — Edit (magic-developer)' ):$( rigHas "$rigSetPost" 'Fix the vars loader' )" "yes:yes:yes"
rigAssert "the two answer emoji are placed under it"       "$( rigReacted reactions "$rigSetTs" )" "x unlock"
rigAssert "the record keeps what was held, with its holder" "$( LC_ALL=C grep -c -x -F "held: Edit:$rigWs/DEV/held/**"$'\t''magic-developer' "${rigSetFile%.md}.set" ):$( LC_ALL=C grep -c '^entry: ' "${rigSetFile%.md}.set" )" "1:3"

echo "-- withdrawn: the post is edited to the same text without how to answer, loses the answer emoji, gets the cancelled mark --"
rigPostsBefore="$( rigCalls chat.postMessage )"
rigWithdraw "$rigSetId" "the task was dropped"
rigAssert "it is withdrawn"                                "$( head -1 "$rigTmp/op.out" ):$( rigField "$rigSetFile" status )" "WITHDRAWN $rigSetId:withdrawn"
rigAssert "nothing is said about a post that was not edited" "$( LC_ALL=C grep -c -e 'was not edited' -e 'could not be edited' -e 'could not be filled' "$rigTmp/op.err" )" 0
rigAssert "the post is edited, once, and it is that post"  "$( rigCalls chat.update ):$( cat "$rigTmp/edited" 2>/dev/null | LC_ALL=C tr '\n' ' ' )" "1:$rigSetTs "
rigAssert "as a whole message, saying nowhere how to answer" "$( rigEditShape "$rigTmp/edit.$rigSetTs" "$rigSetTs" )" "1:1:0"
rigAssert "to the text it was sent with, less how to answer" "$( rigTextOf "$rigTmp/edit.$rigSetTs" )" "$( rigClosedOf "$rigSetPost" )"
rigAssert "which still shows what was asked, its purpose, what was held, the task and who asked" \
	"$( rigHas "$rigTmp/edit.$rigSetTs" 'rig-ws:SETP/**` — Read, Write' ):$( rigHas "$rigTmp/edit.$rigSetTs" 'need to read some files' ):$( rigHas "$rigTmp/edit.$rigSetTs" 'rig-ws:DEV/held/**` — Edit (magic-developer)' ):$( rigHas "$rigTmp/edit.$rigSetTs" 'Fix the vars loader' ):$( rigHas "$rigTmp/edit.$rigSetTs" 'Asked by' )" "yes:yes:yes:yes:yes"
rigAssert "and ends with who asked, nothing after it"      "$( rigTextOf "$rigTmp/edit.$rigSetTs" | LC_ALL=C sed 's/^.*Asked by\*\*\\n//' | LC_ALL=C grep -c '\\n' )" 0
rigAssert "the tooling's two answer emoji are taken off"   "$( rigReacted reactions.removed "$rigSetTs" )" "x unlock"
rigAssert "and it gets the cancelled mark"                 "$( rigReacted reactions "$rigSetTs" | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c -x no_entry_sign )" 1
rigAssert "one note is posted in its thread, as before"    "$(( $( rigCalls chat.postMessage ) - rigPostsBefore ))" 1
rigAssert "a withdrawn set grants nothing"                 "$( rigGrantRead magic-tester rig-set-tester Read "$rigWs/SETP/a.txt" )" ""

echo "-- a request recorded before the held entries were kept: still closed, from what its record holds --"
rigOldId="$( rigSetAsk dispatch-rig-set --entry "Read:$rigWs/SETO/**" --entry "Edit:$rigWs/DEV/held/**" --scope session --session-id rig-set )"
[ -n "$rigOldId" ] || rigRefuse "the rig's second permission set request asked nothing: $( head -2 "$rigTmp/op.err" )"
rigOldFile="$rigWs/.local/agents/pending/$rigOldId.md"
rigOldTs="$( rigField "$rigOldFile" question-ts )"
LC_ALL=C grep -v '^held: ' "${rigOldFile%.md}.set" > "$rigTmp/old.set" && mv "$rigTmp/old.set" "${rigOldFile%.md}.set"
rigWithdraw "$rigOldId" "asked again another way"
rigAssert "it is withdrawn, and its post edited"           "$( head -1 "$rigTmp/op.out" ):$( rigEditShape "$rigTmp/edit.$rigOldTs" "$rigOldTs" )" "WITHDRAWN $rigOldId:1:1:0"
rigAssert "to what was asked, in its scope's own words, without the held part its record never kept" \
	"$( rigHas "$rigTmp/edit.$rigOldTs" 'rig-ws:SETO/**` — Read' ):$( rigHas "$rigTmp/edit.$rigOldTs" 'for this session only' ):$( rigHas "$rigTmp/edit.$rigOldTs" 'Already held' )" "yes:yes:no"
rigAssert "its emoji taken off, the mark put on"           "$( rigReacted reactions.removed "$rigOldTs" ):$( rigReacted reactions "$rigOldTs" | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c -x no_entry_sign )" "x unlock:1"

echo "-- an edit Slack refuses never fails the withdraw: the mark and the emoji still change, and it is logged --"
rigRefId="$( rigSetAsk dispatch-rig-set --entry "Read:$rigWs/SETF/**" --scope task --session-id rig-set "${rigSetThree[@]}" )"
[ -n "$rigRefId" ] || rigRefuse "the rig's third permission set request asked nothing: $( head -2 "$rigTmp/op.err" )"
rigRefFile="$rigWs/.local/agents/pending/$rigRefId.md"
rigRefTs="$( rigField "$rigRefFile" question-ts )"
: > "$rigTmp/edit-refuse"
rigWithdraw "$rigRefId" "not needed"
rm -f "$rigTmp/edit-refuse"
rigAssert "it is withdrawn all the same"                   "$( head -1 "$rigTmp/op.out" ):$( rigField "$rigRefFile" status )" "WITHDRAWN $rigRefId:withdrawn"
rigAssert "the edit was asked for once, and refused"       "$( LC_ALL=C grep -c -x "$rigRefTs" "$rigTmp/edit-refused" 2>/dev/null ):$( [ -e "$rigTmp/edit.$rigRefTs" ] && printf edited || printf none )" "1:none"
rigAssert "the post still loses the emoji and gets the mark" "$( rigReacted reactions.removed "$rigRefTs" ):$( rigReacted reactions "$rigRefTs" | LC_ALL=C tr ' ' '\n' | LC_ALL=C grep -c -x no_entry_sign )" "x unlock:1"
rigAssert "and the refused edit is logged, not dropped"    "$( LC_ALL=C grep -c -F "the post CRIG00001:$rigRefTs could not be edited to drop its How to answer part" "$rigTmp/op.err" )" 1

echo "-- only its asker withdraws it, and an allow-set still grants the asked entries, never a held one --"
rigKeepId="$( rigSetAsk dispatch-rig-set --entry "Read:$rigWs/SETK/**" --entry "Edit:$rigWs/DEV/held/**" --scope task --session-id rig-set "${rigSetThree[@]}" )"
[ -n "$rigKeepId" ] || rigRefuse "the rig's fourth permission set request asked nothing: $( head -2 "$rigTmp/op.err" )"
rigKeepFile="$rigWs/.local/agents/pending/$rigKeepId.md"
rigKeepTs="$( rigField "$rigKeepFile" question-ts )"
rigEditsBefore="$( rigCalls chat.update )"
rigWithdraw "$rigKeepId" "not mine to drop" magic-developer
rigAssert "another member cannot withdraw it: it stays open, its post as it was" \
	"$( rigField "$rigKeepFile" status ):$( rigHas "$rigTmp/op.err" "was asked by magic-coordinator, so magic-developer cannot withdraw it" ):$(( $( rigCalls chat.update ) - rigEditsBefore )):$( rigReacted reactions.removed "$rigKeepTs" )" "reply-pending:yes:0:"
RIG_OP_SESSION=rig-human rigOp --member-escalation-answer human-owner "$rigKeepId" allow-set
RIG_OP_SESSION=""
rigAssert "the allow-set grants the one asked entry to each participant" "$( rigHas "$rigTmp/op.out" 'GRANT: set 3 entries for ' )" yes
rigAssert "and not the entry that was held already"        "$( rigGrantRead magic-tester rig-set-tester Read "$rigWs/SETK/a.txt" ):$( rigGrantRead magic-tester rig-set-tester Edit "$rigWs/DEV/held/x" )" "task:"

rigAssert "no request left this box"                       "$( LC_ALL=C awk '/^url:/ { hitCount++ ; } END { print hitCount + 0 ; }' "$RIG_CURL_LOG" )" 0

if [ "$rigFailCount" -ne 0 ] ; then
	echo "⛔ PERMISSION SET WITHDRAW CHECK FAILED: $rigFailCount of $(( rigPassCount + rigFailCount )) assertion(s)" >&2 ; exit 1
fi
printf 'PERMISSION_SET_WITHDRAW: OK (%d assertions, offline)\n' "$rigPassCount"
